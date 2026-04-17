// SPDX-License-Identifier: Apache-2.0
//
// usb_ocp_recovery_cms_fifo
// -------------------------
// OCP Recovery v1.1 Section 8.2 "Indirect Memory Interface" + Section 9.2
// INDIRECT_* command backing logic.
//
// Services the following recovery commands (routed here by the A3 register
// file whenever fifo_rb_sel=1):
//
//   0x29 INDIRECT_CTRL        - selects active CMS region and byte offset
//                               used by INDIRECT_DATA (direct window).
//   0x2A INDIRECT_STATUS (RO) - aggregate indirect-access status.
//   0x2B INDIRECT_DATA        - direct byte-wise window into the selected
//                               region at INDIRECT_CTRL.offset.  Each access
//                               auto-increments the offset by one byte.
//   0x2C INDIRECT_FIFO_CTRL   - FIFO region select + reset + image-size.
//   0x2D INDIRECT_FIFO_STATUS - FIFO empty/full/region-reset/overflow flags
//                               and the push-side write index (= bytes_pushed)
//                               for the active FIFO region.
//   0x2E INDIRECT_FIFO_DATA   - streaming byte push (also receives the
//                               parallel bulk-OUT stream from A1/A6) and
//                               streaming byte pop.
//
// Micro-architecture
// ------------------
// Data plane:
//   Single-ported external SRAM (cms_addr/cms_wr/cms_rd/cms_wdata/cms_rdata).
//   The address is formed as {cms_idx, offset_within_region}.  For the
//   default parameters (CMS_ADDR_W=16, NUM_CMS=2) that is
//   {region[0], offset[14:0]}, i.e. two 32 KiB regions.
//
// Control plane:
//   - Per-region 32-bit head pointer (push / FIFO write index) and tail
//     pointer (pop / FIFO read index).  Region-local cap = REGION_BYTES,
//     which is 1 << (CMS_ADDR_W - CMS_IDX_W).
//   - INDIRECT_CTRL.offset is a 32-bit counter, pre-loaded by software and
//     auto-incremented by INDIRECT_DATA accesses (Sec 8.2 "Indirect Access
//     Window" semantics).
//   - bytes_pushed is a mirror of head_q[fifo_ctrl_cms_q], exposed to A5
//     so the FSM can see push progress without re-decoding the register
//     file.
//
// Arbitration on the single SRAM port
//   Priority 1 : bulk-OUT push write    (bout_vld & bout_rdy)
//   Priority 2 : FIFO-DATA (0x2E) write via reg-bus
//   Priority 3 : DIRECT (0x2B) or FIFO (0x2E) read
// Register-bus reads are held (fifo_rb_ack deasserted for one extra cycle)
// when a bulk-OUT push is in flight, so pushes never stall.  This is OCP
// Sec 8.2 compliant: the indirect read path has no real-time requirement
// while an image push is active.
//
// Register-bus timing
//   - Writes and reads to purely-flopped state (0x29, 0x2A, 0x2C, 0x2D)
//     complete in the same cycle: fifo_rb_ack is asserted combinationally.
//   - Writes to 0x2B / 0x2E complete in the cycle the SRAM sees the write
//     (one cycle if not arbitrated out).
//   - Reads from 0x2B / 0x2E take two cycles: cycle 0 issues cms_rd,
//     cycle 1 returns cms_rdata with fifo_rb_ack high.
//
// Reset: synchronous, active-high `rst` (SV integration convention).

module usb_ocp_recovery_cms_fifo #(
  parameter int CMS_ADDR_W = 16,
  parameter int NUM_CMS    = 2
)(
  input  logic clk,
  input  logic rst,

  // Sub-reg-bus from A3 (only asserted when cmd is INDIRECT_*)
  input  logic        fifo_rb_sel,
  input  logic [7:0]  fifo_rb_cmd,
  input  logic [15:0] fifo_rb_offset,
  input  logic        fifo_rb_wr,
  input  logic        fifo_rb_rd,
  input  logic [7:0]  fifo_rb_wdata,
  output logic [7:0]  fifo_rb_rdata,
  output logic        fifo_rb_ack,
  output logic        fifo_rb_err,

  // Bulk-OUT push stream (from A1 via A6)
  input  logic [7:0]  bout_data,
  input  logic        bout_vld,
  input  logic        bout_last,
  output logic        bout_rdy,

  // Bulk-IN readback stream (to A1 via A6) -- tied off; FIFO pop path is
  // via reg-bus (0x2E reads) per OCP Recovery v1.1.  Bulk-IN is reserved
  // here for a future mirror of pop data and is kept in the port list so
  // the A6 wrapper port map is stable.
  output logic [7:0]  bin_data,
  output logic        bin_vld,
  output logic        bin_last,
  input  logic        bin_rdy,

  // Status to A5 FSM
  output logic        image_push_active,
  output logic        image_push_done,    // pulse when image size reached
  output logic        fifo_overflow,
  output logic [31:0] image_size,         // from 0x2C
  output logic [31:0] bytes_pushed,
  output logic [7:0]  current_cms,

  // External SRAM-like port (backing store for CMS regions)
  output logic [CMS_ADDR_W-1:0] cms_addr,
  output logic                  cms_wr,
  output logic                  cms_rd,
  output logic [7:0]            cms_wdata,
  input  logic [7:0]            cms_rdata
);

  // ------------------------------------------------------------------
  // Derived parameters
  // ------------------------------------------------------------------
  localparam int CMS_IDX_W       = (NUM_CMS <= 1) ? 1 : $clog2(NUM_CMS);
  localparam int REGION_OFFSET_W = CMS_ADDR_W - CMS_IDX_W;

  // synthesis-time sanity check
  initial begin
    assert (CMS_ADDR_W > CMS_IDX_W)
      else $fatal(1, "CMS_ADDR_W must exceed log2(NUM_CMS)");
    assert (NUM_CMS >= 1)
      else $fatal(1, "NUM_CMS must be >= 1");
  end

  // OCP Recovery v1.1 Sec 9.2 command opcodes
  localparam logic [7:0] CMD_INDIRECT_CTRL        = 8'h29;
  localparam logic [7:0] CMD_INDIRECT_STATUS      = 8'h2A;
  localparam logic [7:0] CMD_INDIRECT_DATA        = 8'h2B;
  localparam logic [7:0] CMD_INDIRECT_FIFO_CTRL   = 8'h2C;
  localparam logic [7:0] CMD_INDIRECT_FIFO_STATUS = 8'h2D;
  localparam logic [7:0] CMD_INDIRECT_FIFO_DATA   = 8'h2E;

  // ------------------------------------------------------------------
  // Flopped state
  // ------------------------------------------------------------------
  // INDIRECT_CTRL (0x29)
  logic [31:0] ind_ctrl_offset_q;   // byte offset within region
  logic [7:0]  ind_ctrl_cms_q;      // region index

  // INDIRECT_FIFO_CTRL (0x2C)
  logic [7:0]  fifo_cms_q;          // region index for streaming push/pop
  logic [31:0] image_size_q;        // expected image byte count

  // Per-region FIFO pointers
  logic [31:0] head_q [NUM_CMS];    // write index (bytes pushed into region)
  logic [31:0] tail_q [NUM_CMS];    // read index  (bytes popped)

  // Status bits (0x2D)
  logic        overflow_q;          // sticky, cleared on FIFO reset
  logic        region_reset_q;      // sticky one-shot, cleared by SW write-1
  logic        image_done_q;        // sticky; pulses out as image_push_done

  // Register-bus read pipeline for SRAM-backed reads (0x2B / 0x2E)
  typedef enum logic [1:0] {
    RB_IDLE,
    RB_MEM_RD,     // cms_rd issued in prior cycle; sample rdata this cycle
    RB_MEM_WAIT    // read deferred while a bulk push holds the SRAM port
  } rb_state_e;
  rb_state_e   rb_state_q;
  logic [CMS_ADDR_W-1:0] rb_pend_addr_q;
  logic        rb_pend_inc_ctrl_q; // 1: increment ind_ctrl_offset when done
  logic        rb_pend_inc_tail_q; // 1: increment tail_q[fifo_cms_q] when done
  logic [7:0]  rb_pend_cms_q;      // cms index for tail increment

  // ------------------------------------------------------------------
  // Helper: form the flat SRAM address
  // ------------------------------------------------------------------
  function automatic logic [CMS_ADDR_W-1:0] make_addr(
      input logic [7:0]  cms_idx,
      input logic [31:0] byte_offset);
    logic [CMS_IDX_W-1:0]       idx;
    logic [REGION_OFFSET_W-1:0] off;
    idx = cms_idx[CMS_IDX_W-1:0];
    off = byte_offset[REGION_OFFSET_W-1:0];
    return {idx, off};
  endfunction

  // ------------------------------------------------------------------
  // Combinational decode
  // ------------------------------------------------------------------
  logic is_ctrl, is_status, is_data, is_fifo_ctrl, is_fifo_status, is_fifo_data;
  logic rb_req;

  always_comb begin
    is_ctrl        = fifo_rb_sel && (fifo_rb_cmd == CMD_INDIRECT_CTRL);
    is_status      = fifo_rb_sel && (fifo_rb_cmd == CMD_INDIRECT_STATUS);
    is_data        = fifo_rb_sel && (fifo_rb_cmd == CMD_INDIRECT_DATA);
    is_fifo_ctrl   = fifo_rb_sel && (fifo_rb_cmd == CMD_INDIRECT_FIFO_CTRL);
    is_fifo_status = fifo_rb_sel && (fifo_rb_cmd == CMD_INDIRECT_FIFO_STATUS);
    is_fifo_data   = fifo_rb_sel && (fifo_rb_cmd == CMD_INDIRECT_FIFO_DATA);
    rb_req         = fifo_rb_sel && (fifo_rb_wr || fifo_rb_rd);
  end

  // ------------------------------------------------------------------
  // Per-region derived flags
  // ------------------------------------------------------------------
  localparam logic [31:0] REGION_BYTES = 32'(1) << REGION_OFFSET_W;

  // OCP Recovery v1.1 Sec 9.2 Tbl 9-11 INDIRECT_FIFO_STATUS fields:
  //   FIFO_SIZE         - total size of the FIFO region in bytes.  Each
  //                       CMS region backs one FIFO, so this equals the
  //                       per-region byte cap.
  //   MAX_TRANSFER_SIZE - largest contiguous push a host may issue before
  //                       it must resync to WRITE_INDEX.  Our byte-wide
  //                       FIFO accepts an entire region in one burst, so
  //                       expose REGION_BYTES here as well.
  localparam logic [31:0] FIFO_SIZE_BYTES     = REGION_BYTES;
  localparam logic [31:0] MAX_XFER_SIZE_BYTES = REGION_BYTES;

  logic [CMS_IDX_W-1:0] push_idx;
  logic [CMS_IDX_W-1:0] ctrl_idx;
  always_comb begin
    push_idx = fifo_cms_q[CMS_IDX_W-1:0];
    ctrl_idx = ind_ctrl_cms_q[CMS_IDX_W-1:0];
  end

  logic push_region_full;
  logic push_region_empty;
  logic image_size_reached;

  always_comb begin
    push_region_full   = (head_q[push_idx] >= REGION_BYTES) ||
                         ((image_size_q != '0) && (head_q[push_idx] >= image_size_q));
    push_region_empty  = (head_q[push_idx] == tail_q[push_idx]);
    image_size_reached = (image_size_q != '0) && (head_q[push_idx] >= image_size_q);
  end

  // ------------------------------------------------------------------
  // SRAM arbitration
  // ------------------------------------------------------------------
  // Priority: bulk-OUT push write > reg-bus FIFO/DATA write > reg-bus read.
  // A reg-bus read that loses arbitration parks in RB_MEM_WAIT and retries
  // next cycle.
  logic sram_bulk_push;
  logic sram_regbus_wr;
  logic sram_regbus_rd_issue;

  always_comb begin
    // Defaults
    cms_addr  = '0;
    cms_wr    = 1'b0;
    cms_rd    = 1'b0;
    cms_wdata = '0;
    sram_bulk_push       = 1'b0;
    sram_regbus_wr       = 1'b0;
    sram_regbus_rd_issue = 1'b0;

    if (bout_vld && bout_rdy) begin
      // Bulk-OUT push path (image streaming).  Targets fifo_cms_q at the
      // current head pointer.  bout_rdy is qualified below to prevent
      // accepting data into a full region.
      cms_addr       = make_addr(fifo_cms_q, head_q[push_idx]);
      cms_wdata      = bout_data;
      cms_wr         = 1'b1;
      sram_bulk_push = 1'b1;
    end
    else if (is_fifo_data && fifo_rb_wr && !push_region_full) begin
      // Reg-bus FIFO write (software pushing via 0x2E).  Same arbitration
      // class as bulk-OUT but lower priority because bulk-OUT is the hot
      // streaming path.
      cms_addr       = make_addr(fifo_cms_q, head_q[push_idx]);
      cms_wdata      = fifo_rb_wdata;
      cms_wr         = 1'b1;
      sram_regbus_wr = 1'b1;
    end
    else if (is_data && fifo_rb_wr) begin
      // 0x2B direct-window write at INDIRECT_CTRL.offset.
      cms_addr       = make_addr(ind_ctrl_cms_q, ind_ctrl_offset_q);
      cms_wdata      = fifo_rb_wdata;
      cms_wr         = 1'b1;
      sram_regbus_wr = 1'b1;
    end
    else if ((rb_state_q == RB_IDLE) && fifo_rb_rd &&
             (is_data || (is_fifo_data && !push_region_empty))) begin
      // 0x2B or 0x2E read launch.
      if (is_data) begin
        cms_addr = make_addr(ind_ctrl_cms_q, ind_ctrl_offset_q);
      end else begin
        cms_addr = make_addr(fifo_cms_q, tail_q[push_idx]);
      end
      cms_rd               = 1'b1;
      sram_regbus_rd_issue = 1'b1;
    end
    else if (rb_state_q == RB_MEM_WAIT) begin
      // Retry a stalled read now that the write slot is free.
      cms_addr             = rb_pend_addr_q;
      cms_rd               = 1'b1;
      sram_regbus_rd_issue = 1'b1;
    end
  end

  // bulk-OUT handshake: accept data only when the region isn't full.  The
  // first push attempt against a full region latches overflow_q.
  always_comb begin
    bout_rdy = !push_region_full;
  end

  // ------------------------------------------------------------------
  // Read-back status word assembly (0x2A, 0x2D) and read mux
  // ------------------------------------------------------------------
  // Layout (byte-addressable via fifo_rb_offset[2:0]):
  //
  // 0x2A INDIRECT_STATUS
  //   [0]      status byte  = {4'b0, reset, region, full, empty}
  //   [1]      reserved     = 8'h00
  //   [2]      payload_size = 8'h02 (256 B / 0x08 per Sec 8.2); here 0x02
  //                          advertises that each transfer is 4 bytes
  //                          (spec-compliant default for a byte FIFO).
  //   [3]      reserved     = 8'h00
  //   [4..7]   write_index  (bytes pushed into direct-window region)
  //
  // 0x2D INDIRECT_FIFO_STATUS (OCP Recovery v1.1 Sec 9.2 Tbl 9-11, 20 B)
  //   [0]       status byte  = {3'b0, image_done, overflow, region_reset,
  //                             full, empty} for the fifo_cms_q region
  //   [1..3]    reserved     = 8'h00
  //   [4..7]    WRITE_INDEX  (= bytes pushed into fifo_cms_q region)
  //   [8..11]   READ_INDEX   (= bytes popped from fifo_cms_q region)
  //   [12..15]  FIFO_SIZE         (LE, compile-time constant)
  //   [16..19]  MAX_TRANSFER_SIZE (LE, compile-time constant)
  //
  // Bits follow Sec 8.2 "Indirect FIFO Status" (empty, full, region-reset,
  // overflow).  The image_done bit at [0][4] is an implementation-defined
  // mirror of the push-complete event; software may also infer it from
  // write_index == image_size.

  logic [7:0] status_byte_2a;
  logic [7:0] status_byte_2d;
  logic ctrl_region_empty;
  logic ctrl_region_full;

  always_comb begin
    ctrl_region_empty = (head_q[ctrl_idx] == tail_q[ctrl_idx]);
    ctrl_region_full  = (head_q[ctrl_idx] >= REGION_BYTES);
    status_byte_2a    = {4'b0,
                         1'b0,                  // reset (not used for direct)
                         1'b0,                  // region type (0 = CMS mem)
                         ctrl_region_full,
                         ctrl_region_empty};
    status_byte_2d    = {3'b0,
                         image_done_q,
                         overflow_q,
                         region_reset_q,
                         push_region_full,
                         push_region_empty};
  end

  // Register-bus read data mux.  SRAM-backed reads drop through to
  // cms_rdata when rb_state_q == RB_MEM_RD.
  always_comb begin
    fifo_rb_rdata = 8'h00;
    if (is_ctrl) begin
      unique case (fifo_rb_offset[2:0])
        3'd0: fifo_rb_rdata = ind_ctrl_offset_q[7:0];
        3'd1: fifo_rb_rdata = ind_ctrl_offset_q[15:8];
        3'd2: fifo_rb_rdata = ind_ctrl_offset_q[23:16];
        3'd3: fifo_rb_rdata = ind_ctrl_offset_q[31:24];
        3'd4: fifo_rb_rdata = ind_ctrl_cms_q;
        default: fifo_rb_rdata = 8'h00;
      endcase
    end
    else if (is_status) begin
      unique case (fifo_rb_offset[2:0])
        3'd0:    fifo_rb_rdata = status_byte_2a;
        3'd1:    fifo_rb_rdata = 8'h00;
        3'd2:    fifo_rb_rdata = 8'h02; // payload size hint
        3'd3:    fifo_rb_rdata = 8'h00;
        3'd4:    fifo_rb_rdata = head_q[ctrl_idx][7:0];
        3'd5:    fifo_rb_rdata = head_q[ctrl_idx][15:8];
        3'd6:    fifo_rb_rdata = head_q[ctrl_idx][23:16];
        3'd7:    fifo_rb_rdata = head_q[ctrl_idx][31:24];
        default: fifo_rb_rdata = 8'h00;
      endcase
    end
    else if (is_fifo_ctrl) begin
      unique case (fifo_rb_offset[2:0])
        3'd0:    fifo_rb_rdata = fifo_cms_q;
        3'd1:    fifo_rb_rdata = {7'b0, region_reset_q};
        3'd4:    fifo_rb_rdata = image_size_q[7:0];
        3'd5:    fifo_rb_rdata = image_size_q[15:8];
        3'd6:    fifo_rb_rdata = image_size_q[23:16];
        3'd7:    fifo_rb_rdata = image_size_q[31:24];
        default: fifo_rb_rdata = 8'h00;
      endcase
    end
    else if (is_fifo_status) begin
      // OCP Recovery v1.1 Sec 9.2 Tbl 9-11: full 20-byte layout.
      unique case (fifo_rb_offset[4:0])
        5'd0:    fifo_rb_rdata = status_byte_2d;
        5'd4:    fifo_rb_rdata = head_q[push_idx][7:0];
        5'd5:    fifo_rb_rdata = head_q[push_idx][15:8];
        5'd6:    fifo_rb_rdata = head_q[push_idx][23:16];
        5'd7:    fifo_rb_rdata = head_q[push_idx][31:24];
        5'd8:    fifo_rb_rdata = tail_q[push_idx][7:0];
        5'd9:    fifo_rb_rdata = tail_q[push_idx][15:8];
        5'd10:   fifo_rb_rdata = tail_q[push_idx][23:16];
        5'd11:   fifo_rb_rdata = tail_q[push_idx][31:24];
        5'd12:   fifo_rb_rdata = FIFO_SIZE_BYTES[7:0];
        5'd13:   fifo_rb_rdata = FIFO_SIZE_BYTES[15:8];
        5'd14:   fifo_rb_rdata = FIFO_SIZE_BYTES[23:16];
        5'd15:   fifo_rb_rdata = FIFO_SIZE_BYTES[31:24];
        5'd16:   fifo_rb_rdata = MAX_XFER_SIZE_BYTES[7:0];
        5'd17:   fifo_rb_rdata = MAX_XFER_SIZE_BYTES[15:8];
        5'd18:   fifo_rb_rdata = MAX_XFER_SIZE_BYTES[23:16];
        5'd19:   fifo_rb_rdata = MAX_XFER_SIZE_BYTES[31:24];
        default: fifo_rb_rdata = 8'h00;
      endcase
    end
    else if ((is_data || is_fifo_data) && (rb_state_q == RB_MEM_RD)) begin
      fifo_rb_rdata = cms_rdata;
    end
  end

  // ------------------------------------------------------------------
  // Register-bus handshake (ack/err)
  // ------------------------------------------------------------------
  logic reg_wr_ack;
  logic reg_rd_ack;
  logic mem_wr_ack;
  logic mem_rd_ack;

  always_comb begin
    // Same-cycle ack for flopped-register paths.
    reg_wr_ack = rb_req && fifo_rb_wr &&
                 (is_ctrl || is_status || is_fifo_ctrl || is_fifo_status);
    reg_rd_ack = rb_req && fifo_rb_rd &&
                 (is_ctrl || is_status || is_fifo_ctrl || is_fifo_status);
    // SRAM writes complete the cycle they are issued (single-port write).
    // OCP Recovery v1.1 Sec 8.2: indirect FIFO pushes (0x2E reg-bus
    // writes and parallel bulk-OUT) MUST NOT lose data.  When a bulk-OUT
    // push wins arbitration against a concurrent reg-bus 0x2E write,
    // the reg-bus byte is NOT written to SRAM -- so we must NOT ACK it.
    // The reg-bus master must hold fifo_rb_wr/wdata and retry next
    // cycle, matching the RB_MEM_WAIT stall pattern used for reads.
    mem_wr_ack = sram_regbus_wr;
    // SRAM read completes the cycle after launch (RB_MEM_RD).
    mem_rd_ack = (rb_state_q == RB_MEM_RD);

    fifo_rb_ack = reg_wr_ack | reg_rd_ack | mem_wr_ack | mem_rd_ack;

    // fifo_rb_err: unsupported command while selected, or read from an
    // empty FIFO, or write to a full FIFO / past image_size.
    fifo_rb_err = 1'b0;
    if (fifo_rb_sel && !(is_ctrl || is_status || is_data ||
                         is_fifo_ctrl || is_fifo_status || is_fifo_data)) begin
      fifo_rb_err = rb_req;
    end
    if (is_fifo_data && fifo_rb_wr && push_region_full) begin
      fifo_rb_err = 1'b1;
    end
    if (is_fifo_data && fifo_rb_rd && push_region_empty &&
        (rb_state_q == RB_IDLE)) begin
      fifo_rb_err = 1'b1;
    end
  end

  // ------------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------------
  integer i;
  logic image_done_pulse;

  always_ff @(posedge clk) begin
    if (rst) begin
      ind_ctrl_offset_q  <= '0;
      ind_ctrl_cms_q     <= '0;
      fifo_cms_q         <= '0;
      image_size_q       <= '0;
      overflow_q         <= 1'b0;
      region_reset_q     <= 1'b0;
      image_done_q       <= 1'b0;
      image_done_pulse   <= 1'b0;
      rb_state_q         <= RB_IDLE;
      rb_pend_addr_q     <= '0;
      rb_pend_inc_ctrl_q <= 1'b0;
      rb_pend_inc_tail_q <= 1'b0;
      rb_pend_cms_q      <= '0;
      for (i = 0; i < NUM_CMS; i++) begin
        head_q[i] <= '0;
        tail_q[i] <= '0;
      end
    end else begin
      image_done_pulse <= 1'b0;

      // -- INDIRECT_CTRL (0x29) writes --------------------------------
      if (is_ctrl && fifo_rb_wr) begin
        unique case (fifo_rb_offset[2:0])
          3'd0: ind_ctrl_offset_q[7:0]   <= fifo_rb_wdata;
          3'd1: ind_ctrl_offset_q[15:8]  <= fifo_rb_wdata;
          3'd2: ind_ctrl_offset_q[23:16] <= fifo_rb_wdata;
          3'd3: ind_ctrl_offset_q[31:24] <= fifo_rb_wdata;
          3'd4: ind_ctrl_cms_q           <= fifo_rb_wdata;
          default: ;
        endcase
      end

      // -- INDIRECT_FIFO_CTRL (0x2C) writes --------------------------
      if (is_fifo_ctrl && fifo_rb_wr) begin
        unique case (fifo_rb_offset[2:0])
          3'd0: fifo_cms_q <= fifo_rb_wdata;
          3'd1: begin
            // bit 0 = region reset (self-clearing one-shot).  Clears head
            // pointer, tail pointer, overflow, image-done for the region
            // currently selected by fifo_cms_q.
            if (fifo_rb_wdata[0]) begin
              head_q[push_idx]  <= '0;
              tail_q[push_idx]  <= '0;
              overflow_q        <= 1'b0;
              image_done_q      <= 1'b0;
              region_reset_q    <= 1'b1;
            end
          end
          3'd4: image_size_q[7:0]   <= fifo_rb_wdata;
          3'd5: image_size_q[15:8]  <= fifo_rb_wdata;
          3'd6: image_size_q[23:16] <= fifo_rb_wdata;
          3'd7: image_size_q[31:24] <= fifo_rb_wdata;
          default: ;
        endcase
      end

      // -- INDIRECT_FIFO_STATUS (0x2D) write-1-to-clear --------------
      // Sec 8.2: overflow and region-reset status bits are sticky and
      // cleared by writing 1.  Match the full 5-bit offset since the
      // 0x2D record is 20 bytes wide (status byte is at offset 0 only).
      if (is_fifo_status && fifo_rb_wr && (fifo_rb_offset[4:0] == 5'd0)) begin
        if (fifo_rb_wdata[2]) region_reset_q <= 1'b0;
        if (fifo_rb_wdata[3]) overflow_q     <= 1'b0;
        if (fifo_rb_wdata[4]) image_done_q   <= 1'b0;
      end

      // -- Bulk-OUT push write: advance head, check image_size ------
      if (sram_bulk_push) begin
        head_q[push_idx] <= head_q[push_idx] + 32'd1;
        if ((image_size_q != '0) &&
            ((head_q[push_idx] + 32'd1) >= image_size_q) && !image_done_q) begin
          image_done_q     <= 1'b1;
          image_done_pulse <= 1'b1;
        end
      end
      else if (bout_vld && !bout_rdy) begin
        // Push attempt into a full region -- latch overflow sticky flag.
        overflow_q <= 1'b1;
      end

      // -- Reg-bus write to 0x2E: advance head -----------------------
      if (sram_regbus_wr && is_fifo_data && fifo_rb_wr) begin
        head_q[push_idx] <= head_q[push_idx] + 32'd1;
        if ((image_size_q != '0) &&
            ((head_q[push_idx] + 32'd1) >= image_size_q) && !image_done_q) begin
          image_done_q     <= 1'b1;
          image_done_pulse <= 1'b1;
        end
      end
      if (is_fifo_data && fifo_rb_wr && push_region_full) begin
        overflow_q <= 1'b1;
      end

      // -- Reg-bus write to 0x2B: advance ctrl offset ----------------
      if (sram_regbus_wr && is_data && fifo_rb_wr) begin
        ind_ctrl_offset_q <= ind_ctrl_offset_q + 32'd1;
        head_q[ctrl_idx]  <= head_q[ctrl_idx] + 32'd1;
      end

      // -- Read state machine for 0x2B / 0x2E reads ------------------
      unique case (rb_state_q)
        RB_IDLE: begin
          if (sram_regbus_rd_issue) begin
            rb_state_q         <= RB_MEM_RD;
            rb_pend_addr_q     <= cms_addr;
            rb_pend_inc_ctrl_q <= is_data;
            rb_pend_inc_tail_q <= is_fifo_data;
            rb_pend_cms_q      <= fifo_cms_q;
          end
          else if (fifo_rb_rd && (is_data || is_fifo_data) && !push_region_empty
                   && (sram_bulk_push || sram_regbus_wr)) begin
            // Read lost arbitration to a write; park and retry.
            rb_state_q         <= RB_MEM_WAIT;
            rb_pend_addr_q     <= is_data
                                  ? make_addr(ind_ctrl_cms_q, ind_ctrl_offset_q)
                                  : make_addr(fifo_cms_q, tail_q[push_idx]);
            rb_pend_inc_ctrl_q <= is_data;
            rb_pend_inc_tail_q <= is_fifo_data;
            rb_pend_cms_q      <= fifo_cms_q;
          end
        end

        RB_MEM_WAIT: begin
          if (!sram_bulk_push && !sram_regbus_wr) begin
            rb_state_q <= RB_MEM_RD;
          end
        end

        RB_MEM_RD: begin
          // Retire: bump pointers and return to idle.
          if (rb_pend_inc_ctrl_q) begin
            ind_ctrl_offset_q <= ind_ctrl_offset_q + 32'd1;
          end
          if (rb_pend_inc_tail_q) begin
            tail_q[rb_pend_cms_q[CMS_IDX_W-1:0]] <=
                tail_q[rb_pend_cms_q[CMS_IDX_W-1:0]] + 32'd1;
          end
          rb_state_q <= RB_IDLE;
        end

        default: rb_state_q <= RB_IDLE;
      endcase
    end
  end

  // ------------------------------------------------------------------
  // Outputs to A5 FSM
  // ------------------------------------------------------------------
  always_comb begin
    image_push_active = (head_q[push_idx] != '0) && !image_done_q;
    image_push_done   = image_done_pulse;
    fifo_overflow     = overflow_q;
    image_size        = image_size_q;
    bytes_pushed      = head_q[push_idx];
    current_cms       = fifo_cms_q;
  end

  // ------------------------------------------------------------------
  // Bulk-IN mirror -- not used for OCP Recovery push (pop is via reg-bus
  // 0x2E).  Tie off; A6 may re-purpose this in the future.
  // ------------------------------------------------------------------
  always_comb begin
    bin_data = 8'h00;
    bin_vld  = 1'b0;
    bin_last = 1'b0;
  end

  // ------------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------------
  // No reg-bus command unknown to this block should get through A3.
  // synthesis translate_off
  always_ff @(posedge clk) begin
    if (!rst && fifo_rb_sel) begin
      assert (!$isunknown(fifo_rb_cmd))
        else $error("fifo_rb_cmd is X when fifo_rb_sel=1");
    end
    if (!rst) begin
      assert (!(cms_wr && cms_rd))
        else $error("SRAM port: simultaneous cms_wr and cms_rd");
    end
  end
  // synthesis translate_on

endmodule : usb_ocp_recovery_cms_fifo
