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
//                               and the push-side WRITE_INDEX (DWORD units)
//                               for the active FIFO region.
//   0x2E INDIRECT_FIFO_DATA   - streaming push and pop.
//
// The direct CMS-memory window (0x29 INDIRECT_CTRL / 0x2A INDIRECT_STATUS /
// 0x2B INDIRECT_DATA) is NOT implemented: PROT_CAP advertises FIFO-only and the
// A3 adapter drops/ACKs those commands as unrecognized.
//
// The reg-bus surface (fifo_rb_*) is native 32-bit word + 4-bit byte strobe,
// matching the word-wide rb_* path used by A2 (ctrl_decode) and the A3 adapter.
// All byte-level sequencing against the byte-wide external CMS SRAM lives here,
// inside the rb_state FSM, and exactly one word-level fifo_rb_ack is returned
// per word access.  Register-only records complete combinationally; SRAM-
// backed records walk the selected byte lanes one per cycle and acknowledge on
// the final lane.
//
// Accesses launch only from RB_IDLE and the access parameters are latched at
// launch, so a held upstream strobe cannot corrupt an in-flight word.  A full
// 64-byte (16-DWORD) INDIRECT_FIFO_DATA push therefore advances head to 64 and
// reports WRITE_INDEX = 16 in DWORD units.
//
// External CMS SRAM interface is unchanged (byte-wide cms_addr/cms_wr/cms_rd/
// cms_wdata[7:0]/cms_rdata[7:0]); it still propagates byte-wide to the SoC.
//
// Micro-architecture
// ------------------
// Data plane:
//   Single-ported external byte SRAM (cms_addr/cms_wr/cms_rd/cms_wdata/
//   cms_rdata).  Address = {cms_idx, offset_within_region}.
//
// Control plane:
//   - Per-region 32-bit-equivalent head (push / WRITE_INDEX) and tail (pop /
//     READ_INDEX) pointers, PTR_W bits each (byte-granular internally; emitted
//     in DWORD units per OCP v1.1 Sec 9.2 Tbl 9-11 / 9-15).
//   - image_size_q is the expected push byte count (programmed in DWORD units
//     by 0x2C, shifted to bytes internally).
//
// Word access engine (rb_state FSM)
//   - Register records (0x2C/0x2D) read/write purely-flopped state:
//     32-bit word assembled / strobed-write in the same cycle (combinational
//     fifo_rb_ack), FSM stays RB_IDLE.
//   - SRAM records (0x2E):
//       * WRITE: walk the set strobe lanes, one byte / cycle, writing
//         seq_data_q[lane] to the live pointer and advancing the pointer +
//         image accounting.  Word-level ack on the final lane.
//       * READ : walk the set strobe lanes, issue cms_rd at the live pointer
//         (RB_RD), capture cms_rdata into seq_data_q[lane] and advance the
//         pointer (RB_RDC).  When the last lane is captured, RB_RDONE presents
//         the assembled 32-bit word with the word-level ack.
//
// Reset: synchronous, active-high `rst` (SV integration convention).

module usb_ocp_recovery_cms_fifo #(
  parameter int CMS_ADDR_W = 16,
  parameter int NUM_CMS    = 2
)(
  input  logic clk,
  input  logic rst,

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
  output logic        image_push_done,    // pulse when image size reached
  output logic        fifo_overflow,
  output logic [31:0] image_size,         // from 0x2C (bytes)
  output logic [31:0] bytes_pushed,

  // External SRAM-like port (backing store for CMS regions) -- BYTE-WIDE,
  // UNCHANGED (propagates to the SoC top).
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

  // OCP Recovery v1.1 Section 9.2 command opcodes - centralized.
`include "usb_ocp_recovery_pkg.svh"
  // Direct CMS-memory window commands 0x29/0x2A/0x2B (INDIRECT_CTRL/STATUS/DATA)
  // are NOT implemented by this transport (FIFO-only per PROT_CAP); only the
  // INDIRECT_FIFO_* (0x2C/0x2D/0x2E) commands are serviced here.
  localparam logic [7:0] CMD_INDIRECT_FIFO_CTRL   = OCP_CMD_INDIRECT_FIFO_CTRL;
  localparam logic [7:0] CMD_INDIRECT_FIFO_STATUS = OCP_CMD_INDIRECT_FIFO_STATUS;
  localparam logic [7:0] CMD_INDIRECT_FIFO_DATA   = OCP_CMD_INDIRECT_FIFO_DATA;

  // ------------------------------------------------------------------
  // Flopped state
  // ------------------------------------------------------------------
  // INDIRECT_FIFO_CTRL (0x2C)
  logic [7:0]  fifo_cms_q;          // region index for streaming push/pop
  logic [31:0] image_size_q;        // expected image size (DWORD units)

  // Per-region FIFO pointers (byte-granular internally).  PTR_W has the extra
  // bit to distinguish full vs empty on wrap.
  localparam int PTR_W = REGION_OFFSET_W + 1;
  logic [PTR_W-1:0] head_q [NUM_CMS];    // write index (bytes pushed)
  logic [PTR_W-1:0] tail_q [NUM_CMS];    // read index  (bytes popped)

  // Status bits (0x2D)
  logic        overflow_q;          // sticky, cleared on FIFO reset / w1c
  logic        region_reset_q;      // sticky one-shot, cleared by SW write-1
  logic        image_done_q;        // sticky; pulses out as image_push_done
  logic        image_push_active_q; // set by first 0x2E push, cleared on
                                     // region reset / image complete.

  // ------------------------------------------------------------------
  // Word access engine (SRAM-backed accesses)
  // ------------------------------------------------------------------
  typedef enum logic [2:0] {
    RB_IDLE,
    RB_WR,         // writing the set strobe lanes, one byte / cycle
    RB_RD,         // issue cms_rd for the current lane
    RB_RDC,        // capture cms_rdata for the current lane
    RB_RDONE       // present assembled word + word-level ack
  } rb_state_e;
  rb_state_e   rb_state_q;
  logic [3:0]  seq_mask_q;          // remaining strobe lanes to service
  logic [31:0] seq_data_q;          // write word latched / read word assembled

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

  // Lowest set lane index in a 4-bit mask (priority encoder).
  function automatic logic [1:0] lowest_lane (input logic [3:0] m);
    if      (m[0]) lowest_lane = 2'd0;
    else if (m[1]) lowest_lane = 2'd1;
    else if (m[2]) lowest_lane = 2'd2;
    else           lowest_lane = 2'd3;
  endfunction

  // ------------------------------------------------------------------
  // Combinational command decode
  // ------------------------------------------------------------------
  logic is_fifo_ctrl, is_fifo_status, is_fifo_data;
  logic is_reg_cmd;     // purely-flopped register record (same-cycle ack)
  logic is_sram_cmd;    // SRAM-backed record (0x2E FIFO)
  logic rb_req;

  always_comb begin
    is_fifo_ctrl   = fifo_rb_sel && (fifo_rb_cmd == CMD_INDIRECT_FIFO_CTRL);
    is_fifo_status = fifo_rb_sel && (fifo_rb_cmd == CMD_INDIRECT_FIFO_STATUS);
    is_fifo_data   = fifo_rb_sel && (fifo_rb_cmd == CMD_INDIRECT_FIFO_DATA);
    is_reg_cmd     = is_fifo_ctrl || is_fifo_status;
    is_sram_cmd    = is_fifo_data;
    rb_req         = fifo_rb_sel && (fifo_rb_wr || fifo_rb_rd);
  end

  // Word index within a multi-word command record.
  logic [2:0] word_idx;
  always_comb word_idx = fifo_rb_offset[2:0];

  // ------------------------------------------------------------------
  // Per-region derived flags / constants
  // ------------------------------------------------------------------
  localparam logic [31:0] REGION_BYTES = 32'(1) << REGION_OFFSET_W;

  // OCP Recovery v1.1 Sec 9.2 Tbl 9-11: FIFO_SIZE / MAX_TRANSFER_SIZE in
  // 4-byte (DWORD) units.
  localparam logic [31:0] FIFO_SIZE_DWORDS     = REGION_BYTES >> OCP_IMG_UNIT_LOG2;
  localparam logic [31:0] MAX_XFER_SIZE_DWORDS = REGION_BYTES >> OCP_IMG_UNIT_LOG2;

  logic [CMS_IDX_W-1:0] push_idx;
  always_comb begin
    push_idx = fifo_cms_q[CMS_IDX_W-1:0];
  end

  // Zero-extended 32-bit pointer views + DWORD-unit emission (Tbl 9-11).
  logic [31:0] head_push_32;
  logic [31:0] tail_push_32;
  logic [31:0] head_push_dw;
  logic [31:0] tail_push_dw;
  always_comb begin
    head_push_32 = 32'(head_q[push_idx]);
    tail_push_32 = 32'(tail_q[push_idx]);
    head_push_dw = head_push_32 >> OCP_IMG_UNIT_LOG2;
    tail_push_dw = tail_push_32 >> OCP_IMG_UNIT_LOG2;
  end

  // OCP v1.1 Sec 9.2 Tbl 9-15: IMAGE_SIZE is on the wire in 4-byte (DWORD)
  // units; convert to bytes for SRAM addressing and pointer comparison.
  logic [31:0] image_size_bytes;
  always_comb begin
    image_size_bytes      = {image_size_q[29:0],      2'b00};
  end

  logic push_region_full;
  logic push_region_empty;
  always_comb begin
    push_region_full   = (head_push_32 >= REGION_BYTES) ||
                         ((image_size_q != '0) && (head_push_32 >= image_size_bytes));
    push_region_empty  = (head_q[push_idx] == tail_q[push_idx]);
  end

  // ------------------------------------------------------------------
  // Launch / completion decode for the word access engine
  // ------------------------------------------------------------------
  // Degenerate accesses (no strobe) complete immediately as a no-op ack.
  // Error launches (push full / pop empty) ack+err immediately with no SRAM
  // access.  Otherwise a multi-cycle SRAM sequence is launched from RB_IDLE.
  logic launch_err_wr;
  logic launch_err_rd;
  logic launch_err;
  logic sram_wr_launch;
  logic sram_rd_launch;
  logic sram_zero_strobe;
  logic rb_idle;
  always_comb begin
    rb_idle         = (rb_state_q == RB_IDLE);
    launch_err_wr   = rb_idle && is_fifo_data && fifo_rb_wr && push_region_full;
    launch_err_rd   = rb_idle && is_fifo_data && fifo_rb_rd && push_region_empty;
    launch_err      = launch_err_wr || launch_err_rd;
    // Degenerate (no-strobe) SRAM access: complete immediately as a no-op ack.
    sram_zero_strobe= rb_idle && is_sram_cmd && (fifo_rb_wr || fifo_rb_rd) &&
                      (fifo_rb_wstrb == 4'h0);
    sram_wr_launch  = rb_idle && is_sram_cmd && fifo_rb_wr &&
                      !launch_err && (fifo_rb_wstrb != 4'h0);
    sram_rd_launch  = rb_idle && is_sram_cmd && fifo_rb_rd &&
                      !launch_err && (fifo_rb_wstrb != 4'h0);
  end

  // mask_last: the remaining-lane mask has at most one bit set (current lane
  // is the final lane of the access).
  logic mask_last;
  always_comb mask_last = ((seq_mask_q & (seq_mask_q - 4'h1)) == 4'h0);

  // ------------------------------------------------------------------
  // Status byte (0x2D)
  // ------------------------------------------------------------------
  logic [7:0] status_byte_2d;
  always_comb begin
    status_byte_2d    = {3'b0,
                         image_done_q,
                         overflow_q,
                         region_reset_q,
                         push_region_full,
                         push_region_empty};
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
      //   word1 WRITE_INDEX (DWORD units)
      //   word2 READ_INDEX  (DWORD units)
      //   word3 FIFO_SIZE          (DWORD units)
      //   word4 MAX_TRANSFER_SIZE  (DWORD units)
      unique case (word_idx)
        3'd0:    reg_rdata = {24'h0, status_byte_2d};
        3'd1:    reg_rdata = head_push_dw;
        3'd2:    reg_rdata = tail_push_dw;
        3'd3:    reg_rdata = FIFO_SIZE_DWORDS;
        3'd4:    reg_rdata = MAX_XFER_SIZE_DWORDS;
        default: reg_rdata = 32'h0;
      endcase
    end
  end

  // Register-bus read data: register records combinationally; SRAM reads
  // present the assembled word in RB_RDONE.
  always_comb begin
    if (rb_state_q == RB_RDONE) fifo_rb_rdata = seq_data_q;
    else                        fifo_rb_rdata = reg_rdata;
  end

  // ------------------------------------------------------------------
  // SRAM port drive (combinational)
  // ------------------------------------------------------------------
  logic [1:0]  cur_lane;            // lane being serviced this cycle
  logic [31:0] wr_ptr_bytes;        // live byte offset for the write/read op
  logic [7:0]  wr_region;
  always_comb begin
    cur_lane = lowest_lane(seq_mask_q);
    // 0x2E FIFO: push pointer = head, pop pointer = tail.
    wr_region    = fifo_cms_q;
    wr_ptr_bytes = (rb_state_q == RB_WR) ? head_push_32 : tail_push_32;
  end

  always_comb begin
    cms_addr  = '0;
    cms_wr    = 1'b0;
    cms_rd    = 1'b0;
    cms_wdata = '0;

    unique case (rb_state_q)
      RB_WR: begin
        // Write the current lane's byte (skip if push region went full).
        if (|seq_mask_q && !push_region_full) begin
          cms_addr  = make_addr(wr_region, wr_ptr_bytes);
          cms_wdata = seq_data_q[cur_lane*8 +: 8];
          cms_wr    = 1'b1;
        end
      end
      RB_RD: begin
        if (|seq_mask_q) begin
          cms_addr = make_addr(wr_region, wr_ptr_bytes);
          cms_rd   = 1'b1;
        end
      end
      default: ; // RB_IDLE / RB_RDC / RB_RDONE: no SRAM drive
    endcase
  end

  // ------------------------------------------------------------------
  // Register-bus handshake (ack/err)
  // ------------------------------------------------------------------
  always_comb begin
    // Register records: same-cycle ack.
    // SRAM no-op (zero strobe write): same-cycle ack.
    // SRAM error launch (push full / pop empty): same-cycle ack+err.
    // SRAM write: ack on the final lane (RB_WR && mask_last).
    // SRAM read:  ack in RB_RDONE (assembled word valid).
    fifo_rb_ack = (rb_req && is_reg_cmd)
                | sram_zero_strobe
                | launch_err
                | ((rb_state_q == RB_WR) && mask_last)
                | (rb_state_q == RB_RDONE);

    // Errors: unsupported command while selected, push to a full FIFO, pop
    // from an empty FIFO.
    fifo_rb_err = 1'b0;
    if (fifo_rb_sel && !(is_reg_cmd || is_sram_cmd)) begin
      fifo_rb_err = rb_req;
    end
    if (launch_err) begin
      fifo_rb_err = 1'b1;
    end
  end

  // ------------------------------------------------------------------
  // Sequential logic
  // ------------------------------------------------------------------
  integer i;

  always_ff @(posedge clk) begin
    if (rst) begin
      fifo_cms_q          <= '0;
      image_size_q        <= '0;
      overflow_q          <= 1'b0;
      region_reset_q      <= 1'b0;
      image_done_q        <= 1'b0;
      image_push_active_q <= 1'b0;
      rb_state_q          <= RB_IDLE;
      seq_mask_q          <= 4'h0;
      seq_data_q          <= '0;
      for (i = 0; i < NUM_CMS; i++) begin
        head_q[i] <= '0;
        tail_q[i] <= '0;
      end
    end else begin

      // ============================================================
      // Register-record writes (same-cycle ack; only fire in RB_IDLE
      // since the upstream holds one command per access and SRAM ops use
      // the 0x2E command).
      // ============================================================

      // -- INDIRECT_FIFO_CTRL (0x2C) -------------------------------
      if (is_fifo_ctrl && fifo_rb_wr) begin
        unique case (word_idx)
          3'd0: begin
            if (fifo_rb_wstrb[0]) fifo_cms_q <= fifo_rb_wdata[7:0];
            // byte1 bit0 = region reset (self-clearing one-shot).
            if (fifo_rb_wstrb[1] && fifo_rb_wdata[8]) begin
              head_q[push_idx]    <= '0;
              tail_q[push_idx]    <= '0;
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

      // -- INDIRECT_FIFO_STATUS (0x2D) write-1-to-clear -----------
      // STATUS_FLAGS at word0 byte0 (Sec 8.2 sticky overflow/region-reset/
      // image-done bits cleared by writing 1).
      if (is_fifo_status && fifo_rb_wr && (word_idx == 3'd0) && fifo_rb_wstrb[0]) begin
        if (fifo_rb_wdata[2]) region_reset_q <= 1'b0;
        if (fifo_rb_wdata[3]) overflow_q     <= 1'b0;
        if (fifo_rb_wdata[4]) image_done_q   <= 1'b0;
      end

      // ============================================================
      // Word access engine for SRAM records (0x2E)
      // ============================================================
      unique case (rb_state_q)
        RB_IDLE: begin
          if (sram_wr_launch) begin
            rb_state_q    <= RB_WR;
            seq_mask_q    <= fifo_rb_wstrb;
            seq_data_q    <= fifo_rb_wdata;
          end else if (sram_rd_launch) begin
            rb_state_q    <= RB_RD;
            seq_mask_q    <= fifo_rb_wstrb;
            seq_data_q    <= '0;
          end
          // Reg-bus push to a full FIFO sets the sticky overflow flag.
          if (launch_err_wr) begin
            overflow_q <= 1'b1;
          end
        end

        // ---- SRAM write: one strobe lane per cycle ----------------
        RB_WR: begin
          if (|seq_mask_q) begin
            // 0x2E FIFO push.
            if (!push_region_full) begin
              head_q[push_idx]    <= head_q[push_idx] + PTR_W'(1);
              image_push_active_q <= 1'b1;
              if ((image_size_q != '0) &&
                  ((head_push_32 + 32'd1) >= image_size_bytes) &&
                  !image_done_q) begin
                image_done_q        <= 1'b1;
                image_push_active_q <= 1'b0;
              end
            end else begin
              overflow_q <= 1'b1;
            end
            seq_mask_q <= seq_mask_q & ~(4'(4'h1 << cur_lane));
          end
          if (mask_last) begin
            rb_state_q <= RB_IDLE;
          end
        end

        // ---- SRAM read: issue cms_rd for the current lane ---------
        RB_RD: begin
          rb_state_q <= RB_RDC;
        end

        // ---- SRAM read: capture cms_rdata, advance pointer --------
        RB_RDC: begin
          seq_data_q[cur_lane*8 +: 8] <= cms_rdata;
          tail_q[push_idx] <= tail_q[push_idx] + PTR_W'(1);
          seq_mask_q <= seq_mask_q & ~(4'(4'h1 << cur_lane));
          if (mask_last) begin
            rb_state_q <= RB_RDONE;   // present assembled word + ack
          end else begin
            rb_state_q <= RB_RD;      // next lane
          end
        end

        // ---- SRAM read complete: word + ack presented this cycle --
        RB_RDONE: begin
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
    image_push_active = image_push_active_q;
    // image_push_done feeds the A5 recovery FSM, which must transition
    // S_AWAIT_IMAGE -> S_PUSH_ACTIVE -> S_IMAGE_LOADED to consume it.  A
    // 1-cycle done pulse would race that multi-state walk (the word-width push
    // completes in a fast burst), so the FSM could miss it and hang in
    // S_PUSH_ACTIVE.  Drive it from the STICKY image_done_q (held until region
    // reset or INDIRECT_FIFO_STATUS write-1-to-clear) so the FSM catches the
    // image-complete event whenever it reaches S_PUSH_ACTIVE.
    image_push_done   = image_done_q;
    fifo_overflow     = overflow_q;
    image_size        = image_size_bytes; // bytes
    bytes_pushed      = head_push_32;      // 32b zero-extended view
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
    if (!rst) begin
      assert (!(cms_wr && cms_rd))
        else $error("SRAM port: simultaneous cms_wr and cms_rd");
    end
  end
`endif
  // synthesis translate_on

endmodule : usb_ocp_recovery_cms_fifo
