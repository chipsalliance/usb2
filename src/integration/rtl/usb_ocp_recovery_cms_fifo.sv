// SPDX-License-Identifier: Apache-2.0
//
// usb_ocp_recovery_cms_fifo
// -------------------------------------------------------------------------
// OCP Recovery v1.1 Section 8.2 "Indirect Memory Interface" + Section 9.2
// INDIRECT_FIFO_* command backing logic.
//
// Services the following recovery commands (routed here by the A3 adapter
// whenever fifo_rb_sel=1):
//
//   0x2C INDIRECT_FIFO_CTRL   - FIFO region select + reset + image-size.
//   0x2D INDIRECT_FIFO_STATUS - FIFO empty/full/region-reset/overflow flags
//                               and the push-side WRITE_INDEX / pop-side
//                               READ_INDEX (DWORD units).
//   0x2E INDIRECT_FIFO_DATA   - streaming push and pop.
//
// The direct CMS-memory window (0x29 INDIRECT_CTRL / 0x2A INDIRECT_STATUS /
// 0x2B INDIRECT_DATA) is NOT implemented: PROT_CAP advertises FIFO-only and the
// A3 adapter drops/ACKs those commands as unrecognized.
//
// Storage micro-architecture (P9-0.1-C)
// -------------------------------------
// The INDIRECT_FIFO_DATA payload is backed by a single internal DWORD FIFO
// (caliptra_prim_fifo_async) used ASYNCHRONOUSLY: the WRITE/push side is on
// clk (utmi_clk); the READ/pop side is on clk_rd (dev_axi_aclk), exposed as a
// module port so Caliptra's AXI 0x2E reads pop the FIFO natively, bypassing
// the utmi-clk CDC bridge.  Every 0x2E push is single-cycle:
//
// Data plane:
//   - Width=32 (one DWORD), Depth=32 (holds the recovery image, power-of-2).
//   - PUSH (clk)   : wvalid_i = accepted 0x2E write; wdata_i = fifo_rb_wdata.
//   - POP  (clk_rd): rready_i = fifo_rd_ready from the wrapper a_state FSM;
//                    rdata_o = fifo_rd_data (popped DWORD).
//
// Control plane:
//   - write_index_q : 32-bit cumulative DWORD push counter (this clk domain).
//   - READ_INDEX    : derived (write_index_q - write-side occupancy); the pop
//                     counter was removed (pops are native in dev_axi_aclk).
//   - image_size_q  : expected image size programmed by 0x2C (DWORD units).
//   - image_done_q  : sticky; set when write_index_q >= image_size_q (DWORDs).
//   - overflow_q    : sticky; set on a dropped push (FIFO full or image done).
//   - region_reset_q / image_push_active_q sideband bits.
//   - fifo_flush    : 1-cycle pulse on INDIRECT_FIFO_CTRL region-reset; drives
//                     the FIFO's active-low reset (with rst) so a region reset
//                     empties the FIFO and zeroes the cumulative counters.
//
// All ACKs are returned same-cycle (the access never stalls):
//   - reg records (0x2C/0x2D) ack combinationally;
//   - 0x2E push/pop ack combinationally (accepted, dropped-full, or empty).
//
// Reset: synchronous, active-high `rst` (SV integration convention).  The
// internal FIFO uses an active-LOW reset derived by inverting (rst | flush).

module usb_ocp_recovery_cms_fifo #(
  // CMS_ADDR_W / NUM_CMS are retained for instantiation compatibility with the
  // wrapper/top parameter overrides; they are otherwise vestigial now that the
  // single internal FIFO backs the INDIRECT_FIFO_DATA payload.
  parameter int CMS_ADDR_W = 16,
  parameter int NUM_CMS    = 2,
  // Internal DWORD FIFO geometry.
  parameter int FIFO_WIDTH = 32,
  parameter int FIFO_DEPTH = 32
)(
  input  logic clk,
  input  logic rst,

  // ----------------------------------------------------------------------
  // Async FIFO READ port (P9-0.1-C): exposed so the dev_axi_aclk-domain
  // wrapper can pop INDIRECT_FIFO_DATA (0x2E) reads natively, bypassing the
  // utmi-clk CDC bridge.  The async FIFO read port is now clocked by clk_rd
  // (= dev_axi_aclk); the write/push side stays on clk (= utmi_clk).
  // ----------------------------------------------------------------------
  input  logic clk_rd,                                  // dev_axi_aclk
  input  logic rst_rd_n,                                // dev_axi_aresetn (active-low)
  output logic        fifo_rd_valid,
  input  logic        fifo_rd_ready,
  output logic [31:0] fifo_rd_data,
  output logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_rd_depth,

  // Sub-reg-bus from A3 (only asserted when cmd is INDIRECT_*).  Native
  // 32-bit word + 4-bit byte strobe.  fifo_rb_offset is a WORD index into the
  // command record (low bits select the DWORD within a multi-word record).
  input  logic        fifo_rb_sel,
  input  logic [7:0]  fifo_rb_cmd,
  input  logic [15:0] fifo_rb_offset,
  input  logic        fifo_rb_wr,
  input  logic        fifo_rb_rd,
  input  logic [31:0] fifo_rb_wdata,
  input  logic [3:0]  fifo_rb_wstrb,
  output logic [31:0] fifo_rb_rdata,
  output logic        fifo_rb_ack,
  output logic        fifo_rb_err,

  // Status to A5 FSM
  output logic        image_push_active,
  output logic        image_push_done,    // sticky image-complete (DWORD count)
  output logic        fifo_overflow,
  output logic [31:0] image_size,         // from 0x2C (bytes)
  output logic [31:0] bytes_pushed
);

  // synthesis-time sanity check
  initial begin
    assert (FIFO_DEPTH > 0)
      else $fatal(1, "FIFO_DEPTH must be > 0");
    assert (FIFO_WIDTH == 32)
      else $fatal(1, "FIFO_WIDTH must be 32 (DWORD)");
  end

  // OCP Recovery v1.1 Section 9.2 command opcodes - centralized.
`include "usb_ocp_recovery_pkg.svh"
  // Direct CMS-memory window commands 0x29/0x2A/0x2B (INDIRECT_CTRL/STATUS/DATA)
  // are NOT implemented by this transport (FIFO-only per PROT_CAP); only the
  // INDIRECT_FIFO_* (0x2C/0x2D/0x2E) commands are serviced here.
  localparam logic [7:0] CMD_INDIRECT_FIFO_CTRL   = OCP_CMD_INDIRECT_FIFO_CTRL;
  localparam logic [7:0] CMD_INDIRECT_FIFO_STATUS = OCP_CMD_INDIRECT_FIFO_STATUS;
  localparam logic [7:0] CMD_INDIRECT_FIFO_DATA   = OCP_CMD_INDIRECT_FIFO_DATA;

  // OCP Recovery v1.1 Sec 9.2 Tbl 9-11: FIFO_SIZE / MAX_TRANSFER_SIZE in
  // 4-byte (DWORD) units.  With one internal FIFO both are simply the depth.
  localparam logic [31:0] FIFO_SIZE_DWORDS     = 32'(FIFO_DEPTH);
  localparam logic [31:0] MAX_XFER_SIZE_DWORDS = 32'(FIFO_DEPTH);

  // ------------------------------------------------------------------
  // Flopped state
  // ------------------------------------------------------------------
  // INDIRECT_FIFO_CTRL (0x2C)
  logic [7:0]  fifo_cms_q;          // CMS region byte (vestigial; kept for r/b)
  logic [31:0] image_size_q;        // expected image size (DWORD units)

  // Cumulative DWORD counters (this clk domain; no CDC this stage).
  logic [31:0] write_index_q;       // pushed DWORD count (WRITE_INDEX)
  // NOTE (P9-0.1-C): the pop-side read_index_q counter has been REMOVED.
  // Pops now occur natively in the dev_axi_aclk domain via the exposed FIFO
  // read port, so there is no utmi-domain pop event to count here.  The 0x2D
  // READ_INDEX is instead DERIVED from the write-side occupancy below.

  // Status bits (0x2D)
  logic        overflow_q;          // sticky, cleared on FIFO reset / w1c
  logic        region_reset_q;      // sticky one-shot, cleared by SW write-1
  logic        image_done_q;        // sticky; emitted as image_push_done
  logic        image_push_active_q; // set by first 0x2E push, cleared on
                                     // region reset / image complete.

  // ------------------------------------------------------------------
  // Internal DWORD FIFO (caliptra_prim_fifo_async, used synchronously)
  // ------------------------------------------------------------------
  logic                       fifo_flush;     // 1-cycle region-reset pulse
  logic                       fifo_rst_n;     // active-low reset to the FIFO
  logic                       fifo_wvalid;
  logic                       fifo_wready;
  logic [FIFO_WIDTH-1:0]      fifo_wdata;
  logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_wdepth;
  // Read-port nets (fifo_rd_valid / fifo_rd_ready / fifo_rd_data /
  // fifo_rd_depth) are now module ports in the dev_axi_aclk domain; the async
  // FIFO read port connects to them directly (see instance below).

  // ------------------------------------------------------------------
  // Combinational command decode
  // ------------------------------------------------------------------
  logic is_fifo_ctrl, is_fifo_status, is_fifo_data;
  logic is_reg_cmd;     // purely-flopped register record (same-cycle ack)
  logic rb_req;

  always_comb begin
    is_fifo_ctrl   = fifo_rb_sel && (fifo_rb_cmd == CMD_INDIRECT_FIFO_CTRL);
    is_fifo_status = fifo_rb_sel && (fifo_rb_cmd == CMD_INDIRECT_FIFO_STATUS);
    is_fifo_data   = fifo_rb_sel && (fifo_rb_cmd == CMD_INDIRECT_FIFO_DATA);
    is_reg_cmd     = is_fifo_ctrl || is_fifo_status;
    rb_req         = fifo_rb_sel && (fifo_rb_wr || fifo_rb_rd);
  end

  // Word index within a multi-word command record.
  logic [2:0] word_idx;
  always_comb word_idx = fifo_rb_offset[2:0];

  // OCP v1.1 Sec 9.2 Tbl 9-15: IMAGE_SIZE is on the wire in 4-byte (DWORD)
  // units; convert to bytes for the sideband image_size output.
  logic [31:0] image_size_bytes;
  always_comb image_size_bytes = {image_size_q[29:0], 2'b00};

  // Image fully pushed when the programmed (non-zero) DWORD size is reached.
  logic image_complete;
  always_comb begin
    image_complete = (image_size_q != '0) && (write_index_q >= image_size_q);
  end

  // ------------------------------------------------------------------
  // EMPTY / FULL flags (from FIFO occupancy)
  // ------------------------------------------------------------------
  logic fifo_empty;
  logic fifo_full;
  always_comb begin
    fifo_empty = (fifo_wdepth == '0);   // write-side occupancy zero
    fifo_full  = ~fifo_wready;          // equivalently wdepth == Depth
  end

  // ------------------------------------------------------------------
  // 0x2E push datapath (single-cycle).  Pops are handled natively in the
  // dev_axi_aclk domain through the exposed read port (P9-0.1-C), so there is
  // no utmi-domain pop_accept here.
  // ------------------------------------------------------------------
  logic push_accept;   // accepted push (advances FIFO + write_index_q)
  logic push_drop;     // dropped push (FIFO full or image already complete)
  always_comb begin
    push_accept = is_fifo_data && fifo_rb_wr && fifo_wready && !image_complete;
    push_drop   = is_fifo_data && fifo_rb_wr && (!fifo_wready || image_complete);
  end

  // FIFO write strobe + data (read strobe comes from fifo_rd_ready port).
  always_comb begin
    fifo_wvalid = push_accept;
    fifo_wdata  = fifo_rb_wdata;
  end

  // ------------------------------------------------------------------
  // READ_INDEX (0x2D word2) derivation (P9-0.1-C).
  // READ_INDEX is derived from the write-side occupancy (gray-synced inside
  // the async FIFO), so it needs no separate read-counter CDC; it
  // conservatively lags actual reads.  read_index = write_index - occupancy
  // (DWORD units).  Underflow-safe: occupancy (fifo_wdepth) can never exceed
  // the cumulative push count, but the subtraction is guarded explicitly.
  // ------------------------------------------------------------------
  logic [31:0] fifo_wdepth_ext;
  logic [31:0] read_index_derived;
  always_comb begin
    fifo_wdepth_ext    = {{(32-$clog2(FIFO_DEPTH+1)){1'b0}}, fifo_wdepth};
    read_index_derived = (write_index_q >= fifo_wdepth_ext)
                       ? (write_index_q - fifo_wdepth_ext)
                       : 32'h0;
  end
  //   bit4 image_done, bit3 overflow, bit2 region_reset, bit1 full, bit0 empty.
  // ------------------------------------------------------------------
  logic [7:0] status_byte_2d;
  always_comb begin
    status_byte_2d = {3'b0,
                      image_done_q,
                      overflow_q,
                      region_reset_q,
                      fifo_full,
                      fifo_empty};
  end

  // ------------------------------------------------------------------
  // Register-record read mux (32-bit word assembled per WORD index)
  // ------------------------------------------------------------------
  logic [31:0] reg_rdata;
  always_comb begin
    reg_rdata = 32'h0;
    if (is_fifo_ctrl) begin
      // 0x2C INDIRECT_FIFO_CTRL (OCP v1.1 Sec 9.2 Tbl 9-15):
      //   byte0 CMS, byte1 RESET, bytes2..5 IMAGE_SIZE (DWORD units).
      unique case (word_idx)
        3'd0:    reg_rdata = {image_size_q[15:0],
                              {7'b0, region_reset_q},
                              fifo_cms_q};
        3'd1:    reg_rdata = {16'h0, image_size_q[31:16]};
        default: reg_rdata = 32'h0;
      endcase
    end
    else if (is_fifo_status) begin
      // 0x2D INDIRECT_FIFO_STATUS (OCP v1.1 Sec 9.2 Tbl 9-11, 20 B / 5 words):
      //   word0 byte0 STATUS_FLAGS, byte1 REGION_TYPE (0), bytes2..3 reserved
      //   word1 WRITE_INDEX (DWORD units) = write_index_q
      //   word2 READ_INDEX  (DWORD units) = write_index_q - occupancy (derived)
      //   word3 FIFO_SIZE          (DWORD units) = Depth
      //   word4 MAX_TRANSFER_SIZE  (DWORD units) = Depth
      unique case (word_idx)
        3'd0:    reg_rdata = {24'h0, status_byte_2d};
        3'd1:    reg_rdata = write_index_q;
        3'd2:    reg_rdata = read_index_derived;
        3'd3:    reg_rdata = FIFO_SIZE_DWORDS;
        3'd4:    reg_rdata = MAX_XFER_SIZE_DWORDS;
        default: reg_rdata = 32'h0;
      endcase
    end
  end

  // Register-bus read data (P9-0.1-C): real 0x2E DATA reads no longer happen on
  // this utmi-domain rb path (they are serviced natively in dev_axi_aclk via
  // the exposed read port).  A defensive 0x2E rb READ that should no longer
  // occur returns 0 and is still ACKed (no bus hang).  Register records
  // (0x2C/0x2D) present the assembled word combinationally.
  always_comb begin
    if (is_fifo_data && fifo_rb_rd) fifo_rb_rdata = 32'h0;
    else                            fifo_rb_rdata = reg_rdata;
  end

  // ------------------------------------------------------------------
  // Register-bus handshake (ack/err) - all accesses ack same-cycle.
  // ------------------------------------------------------------------
  always_comb begin
    // Reg records (0x2C/0x2D) and every 0x2E push/pop ack in the same cycle
    // (accepted push, dropped-full push, real pop, or empty pop).
    fifo_rb_ack = rb_req && (is_reg_cmd || is_fifo_data);

    // Errors: only unsupported commands while selected.  Dropped pushes set
    // overflow_q (sticky) but do NOT err, and empty pops return 0 without err;
    // this keeps the bus from ever hanging.
    fifo_rb_err = 1'b0;
    if (fifo_rb_sel && !(is_reg_cmd || is_fifo_data)) begin
      fifo_rb_err = rb_req;
    end
  end

  // ------------------------------------------------------------------
  // Region-reset flush pulse (INDIRECT_FIFO_CTRL byte1 bit0)
  // ------------------------------------------------------------------
  always_comb begin
    fifo_flush = is_fifo_ctrl && fifo_rb_wr && (word_idx == 3'd0) &&
                 fifo_rb_wstrb[1] && fifo_rb_wdata[8];
    // Active-low reset to the internal FIFO WRITE side: module rst (high) or a
    // region reset flushes the FIFO contents on the utmi (write/push) domain.
    fifo_rst_n = ~(rst | fifo_flush);
    // TODO (P9-0.1-C CDC): cross-domain region-reset flush of the read pointer
    // is not handled; safe only because region-reset occurs while the FIFO is
    // empty/idle.  A mid-stream region-reset would desync wptr/rptr -- handle
    // via a synced flush before enabling streamed (Depth-exceeding) images.
  end

  // ------------------------------------------------------------------
  // Internal DWORD FIFO instance (asynchronous P9-0.1-C):
  //   write/push side -> clk    (utmi_clk), reset = fifo_rst_n (rst|flush)
  //   read /pop  side -> clk_rd (dev_axi_aclk), reset = rst_rd_n (AXI only)
  // rst_rd_ni is the dev_axi reset ONLY -- fifo_flush is a utmi event and
  // folding it into the AXI-domain read reset would be a CDC hazard (see the
  // TODO above).
  // ------------------------------------------------------------------
  caliptra_prim_fifo_async #(
    .Width (FIFO_WIDTH),
    .Depth (FIFO_DEPTH)
  ) u_indirect_fifo (
    .clk_wr_i  (clk),
    .rst_wr_ni (fifo_rst_n),
    .wvalid_i  (fifo_wvalid),
    .wready_o  (fifo_wready),
    .wdata_i   (fifo_wdata),
    .wdepth_o  (fifo_wdepth),

    .clk_rd_i  (clk_rd),
    .rst_rd_ni (rst_rd_n),
    .rvalid_o  (fifo_rd_valid),
    .rready_i  (fifo_rd_ready),
    .rdata_o   (fifo_rd_data),
    .rdepth_o  (fifo_rd_depth)
  );

  // ------------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
      fifo_cms_q          <= '0;
      image_size_q        <= '0;
      write_index_q       <= '0;
      overflow_q          <= 1'b0;
      region_reset_q      <= 1'b0;
      image_done_q        <= 1'b0;
      image_push_active_q <= 1'b0;
    end else begin

      // ----------------------------------------------------------------
      // INDIRECT_FIFO_CTRL (0x2C) write handler (same-cycle).
      // ----------------------------------------------------------------
      if (is_fifo_ctrl && fifo_rb_wr) begin
        unique case (word_idx)
          3'd0: begin
            if (fifo_rb_wstrb[0]) fifo_cms_q <= fifo_rb_wdata[7:0];
            // byte1 bit0 = region reset (self-clearing one-shot).  Flushes the
            // FIFO (via fifo_flush -> fifo_rst_n) and zeroes the counters.
            if (fifo_rb_wstrb[1] && fifo_rb_wdata[8]) begin
              write_index_q       <= '0;
              overflow_q          <= 1'b0;
              image_done_q        <= 1'b0;
              region_reset_q      <= 1'b1;
              image_push_active_q <= 1'b0;
            end
            if (fifo_rb_wstrb[2]) image_size_q[7:0]   <= fifo_rb_wdata[23:16];
            if (fifo_rb_wstrb[3]) image_size_q[15:8]  <= fifo_rb_wdata[31:24];
          end
          3'd1: begin
            if (fifo_rb_wstrb[0]) image_size_q[23:16] <= fifo_rb_wdata[7:0];
            if (fifo_rb_wstrb[1]) image_size_q[31:24] <= fifo_rb_wdata[15:8];
          end
          default: ;
        endcase
      end

      // ----------------------------------------------------------------
      // INDIRECT_FIFO_STATUS (0x2D) write-1-to-clear of sticky flags.
      // STATUS_FLAGS at word0 byte0 (bit2 region_reset, bit3 overflow,
      // bit4 image_done).
      // ----------------------------------------------------------------
      if (is_fifo_status && fifo_rb_wr && (word_idx == 3'd0) && fifo_rb_wstrb[0]) begin
        if (fifo_rb_wdata[2]) region_reset_q <= 1'b0;
        if (fifo_rb_wdata[3]) overflow_q     <= 1'b0;
        if (fifo_rb_wdata[4]) image_done_q   <= 1'b0;
      end

      // ----------------------------------------------------------------
      // 0x2E push (accepted): advance WRITE_INDEX and image accounting.
      // ----------------------------------------------------------------
      if (push_accept) begin
        write_index_q       <= write_index_q + 32'd1;
        image_push_active_q <= 1'b1;
        // Image fully received once the push count reaches the programmed size.
        if ((image_size_q != '0) &&
            ((write_index_q + 32'd1) >= image_size_q)) begin
          image_done_q        <= 1'b1;
          image_push_active_q <= 1'b0;
        end
      end

      // ----------------------------------------------------------------
      // 0x2E push (dropped): FIFO full or image already complete -> sticky
      // overflow, still ACKed (no hang).
      // ----------------------------------------------------------------
      if (push_drop) begin
        overflow_q <= 1'b1;
      end
    end
  end

  // ------------------------------------------------------------------
  // Outputs to A5 FSM
  // ------------------------------------------------------------------
  always_comb begin
    image_push_active = image_push_active_q;
    // image_push_done is driven from the STICKY image_done_q (held until region
    // reset or INDIRECT_FIFO_STATUS write-1-to-clear) so the A5 recovery FSM
    // catches the image-complete event whenever it reaches S_PUSH_ACTIVE.
    image_push_done   = image_done_q;
    fifo_overflow     = overflow_q;
    image_size        = image_size_bytes;        // bytes
    bytes_pushed      = {write_index_q[29:0], 2'b00}; // write_index_q << 2 (bytes)
  end

  // ------------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------------
  // synthesis translate_off
`ifndef SYNTHESIS
  always_ff @(posedge clk) begin
    if (!rst && fifo_rb_sel) begin
      assert (!$isunknown(fifo_rb_cmd))
        else $error("fifo_rb_cmd is X when fifo_rb_sel=1");
    end
  end
`endif
  // synthesis translate_on

endmodule : usb_ocp_recovery_cms_fifo
