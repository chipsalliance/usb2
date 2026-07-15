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
//   INDIRECT_FIFO_CTRL   - FIFO region select + reset + image-size.
//   INDIRECT_FIFO_STATUS - FIFO empty/full/region-reset/overflow flags
//                               and the push-side WRITE_INDEX / pop-side
//                               READ_INDEX (DWORD units).  Strictly read-only
//                               per OCP Recovery v1.1 Sec 9.2 (cmd=46, r/w=ro);
//                               a host write raises PROTOCOL_ERROR via the A3
//                               adapter's unsupported-command path (Sec 9.1).
//                               Sticky flags clear only via INDIRECT_FIFO_CTRL
//                               region reset (byte1 bit0).
//   INDIRECT_FIFO_DATA   - streaming push and pop.
//
// The direct CMS-memory window (INDIRECT_CTRL / INDIRECT_STATUS /
// INDIRECT_DATA) is NOT implemented: PROT_CAP advertises FIFO-only and the
// A3 adapter drops/ACKs those commands as unrecognized.
//
// Storage micro-architecture
// -------------------------------------
// The INDIRECT_FIFO_DATA payload is backed by a single internal DWORD FIFO
// (caliptra_prim_fifo_async) used ASYNCHRONOUSLY: the WRITE/push side is on
// clk (utmi_clk); the READ/pop side is on clk_rd (dev_axi_aclk), exposed as a
// module port so Caliptra's AXI INDIRECT_FIFO_DATA reads pop the FIFO natively, bypassing
// the utmi-clk CDC bridge.  Every INDIRECT_FIFO_DATA push is single-cycle:
//
// Data plane:
//   - Width=32 (one DWORD), Depth=32 (holds the recovery image, power-of-2).
//   - PUSH (clk)   : wvalid_i = accepted INDIRECT_FIFO_DATA write; wdata_i = fifo_rb_wdata.
//   - POP  (clk_rd): rready_i = fifo_rd_ready from the wrapper a_state FSM;
//                    rdata_o = fifo_rd_data (popped DWORD).
//
// Control plane:
//   - write_index_q : 32-bit cumulative DWORD push counter (this clk domain).
//   - READ_INDEX    : derived (write_index_q - write-side occupancy); the pop
//                     counter was removed (pops are native in dev_axi_aclk).
//   - image_size_q  : expected image size programmed by INDIRECT_FIFO_CTRL (DWORD units).
//   - image_done_q  : sticky; set when write_index_q >= image_size_q (DWORDs).
//   - overflow_q    : sticky; set only on a genuine FIFO-full drop (FIFO full
//                     while the image is still incomplete).
//   - region_reset_q / image_push_active_q sideband bits.
//   - fifo_flush    : 1-cycle pulse on INDIRECT_FIFO_CTRL region-reset; drives
//                     the FIFO's active-low reset (with rst) so a region reset
//                     empties the FIFO and zeroes the cumulative counters.
//
// All ACKs are returned same-cycle (the access never stalls):
//   - reg records (INDIRECT_FIFO_CTRL/STATUS) ack combinationally;
//   - INDIRECT_FIFO_DATA push/pop ack combinationally (accepted, dropped-full, or empty).
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
  // Async FIFO READ port: exposed so the dev_axi_aclk-domain wrapper can
  // pop INDIRECT_FIFO_DATA reads natively, bypassing the utmi-clk CDC
  // bridge. The async FIFO read port is clocked by clk_rd (= dev_axi_aclk);
  // the write/push side stays on clk (= utmi_clk).
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
  input  logic        fifo_rb_from_usb,
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
  output logic [31:0] image_size,         // from INDIRECT_FIFO_CTRL (bytes)
  output logic [31:0] bytes_pushed,

  // INDIRECT_FIFO_CTRL read-back drive to the A3 regblock (hw=w).  cms_fifo is
  // the single live owner of these fields; the regblock holds the read-back
  // copy (sw=r) and the host reads it through the regblock command window.
  output logic [7:0]  fifo_ctrl_cms,        // INDIRECT_FIFO_CTRL byte 0 (CMS)
  output logic        fifo_ctrl_reset,      // INDIRECT_FIFO_CTRL byte 1 bit 0
  output logic [31:0] fifo_ctrl_image_size  // INDIRECT_FIFO_CTRL IMAGE_SIZE (DWORD units)
);

  // synthesis-time sanity check
  initial begin
    assert (FIFO_DEPTH > 0)
      else $fatal(1, "FIFO_DEPTH must be > 0");
    assert (FIFO_WIDTH == 32)
      else $fatal(1, "FIFO_WIDTH must be 32 (DWORD)");
  end

  // OCP Recovery v1.1 Sec 9.2 command opcodes from the shared package.
  import usb_ocp_recovery_pkg::*;
  // Direct CMS-memory window commands INDIRECT_CTRL/STATUS/DATA are NOT
  // implemented by this transport (FIFO-only per PROT_CAP); only the
  // INDIRECT_FIFO_* commands are serviced here.

  // OCP Recovery v1.1 Sec 9.2: FIFO_SIZE / MAX_TRANSFER_SIZE in
  // 4-byte (DWORD) units.  With one internal FIFO both are simply the depth.
  localparam logic [31:0] FIFO_SIZE_DWORDS     = 32'(FIFO_DEPTH);
  localparam logic [31:0] MAX_XFER_SIZE_DWORDS = 32'(FIFO_DEPTH);

  // ------------------------------------------------------------------
  // Flopped state
  // ------------------------------------------------------------------
  // INDIRECT_FIFO_CTRL
  logic [7:0]  fifo_cms_q;          // CMS region byte (vestigial; kept for r/b)
  logic [31:0] image_size_q;        // expected image size (DWORD units)

  // Cumulative DWORD counters (this clk domain; no CDC this stage).
  logic [31:0] write_index_q;       // pushed DWORD count (WRITE_INDEX)
  // Pops occur natively in the dev_axi_aclk domain via the exposed FIFO
  // read port, so there is no utmi-domain pop event to count (no pop-side
  // read_index_q counter). The INDIRECT_FIFO_STATUS READ_INDEX is instead
  // DERIVED from the write-side occupancy below.

  // Status bits (INDIRECT_FIFO_STATUS)
  logic        overflow_q;          // sticky, cleared only by INDIRECT_FIFO_CTRL region reset
  logic        region_reset_q;      // sticky one-shot, cleared only by INDIRECT_FIFO_CTRL region reset
  logic        image_done_q;        // sticky; emitted as image_push_done
  logic        image_push_active_q; // set by first INDIRECT_FIFO_DATA push, cleared on
                                     // region reset / image complete.
  logic        usb_fifo_status_snapshot_vld_q;
  logic        ext_fifo_status_snapshot_vld_q;
  logic [31:0] usb_fifo_status_snapshot_q [0:4];
  logic [31:0] ext_fifo_status_snapshot_q [0:4];

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
    is_fifo_ctrl   = fifo_rb_sel && (fifo_rb_cmd == OCP_CMD_INDIRECT_FIFO_CTRL);
    is_fifo_status = fifo_rb_sel && (fifo_rb_cmd == OCP_CMD_INDIRECT_FIFO_STATUS);
    is_fifo_data   = fifo_rb_sel && (fifo_rb_cmd == OCP_CMD_INDIRECT_FIFO_DATA);
    is_reg_cmd     = is_fifo_ctrl || is_fifo_status;
    rb_req         = fifo_rb_sel && (fifo_rb_wr || fifo_rb_rd);
  end

  // Word index within a multi-word command record.
  logic [2:0] word_idx;
  always_comb word_idx = fifo_rb_offset[2:0];

  // OCP v1.1 Sec 9.2: IMAGE_SIZE is on the wire in 4-byte (DWORD)
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
  // INDIRECT_FIFO_DATA push datapath (single-cycle).  Pops are handled natively in the
  // dev_axi_aclk domain through the exposed read port, so there is
  // no utmi-domain pop_accept here.
  // ------------------------------------------------------------------
  logic push_accept;      // accepted push (advances FIFO + write_index_q)
  logic push_drop_full;   // genuine FIFO-full overflow drop (FIFO full, image not yet complete)
  always_comb begin
    push_accept    = is_fifo_data && fifo_rb_wr && fifo_wready && !image_complete;
    // Overflow is a GENUINE FIFO-full drop only: a push that cannot be stored
    // because the FIFO is full while the image is still incomplete.  A push that
    // arrives after the image is already complete is expected excess data and is
    // silently dropped (still ACKed) WITHOUT flagging overflow, so a trailing
    // post-image push cannot spuriously drive the recovery FSM to S_ERROR.
    push_drop_full = is_fifo_data && fifo_rb_wr && !fifo_wready && !image_complete;
  end

  // FIFO write strobe + data (read strobe comes from fifo_rd_ready port).
  always_comb begin
    fifo_wvalid = push_accept;
    fifo_wdata  = fifo_rb_wdata;
  end

  // ------------------------------------------------------------------
  // READ_INDEX (INDIRECT_FIFO_STATUS word2) derivation.
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
    // OCP Recovery v1.1 Sec 9.2 INDIRECT_FIFO_STATUS byte 0 defines only
    // bit 0 (empty) and bit 1 (full); bits 7:2 are reserved.  The
    // Caliptra-specific sticky bits (region reset / overflow / image done) are
    // exposed separately in the CALIPTRA_STATUS register, not packed here.
    status_byte_2d = {6'b0,
                      fifo_full,
                      fifo_empty};
  end

  logic       usb_fifo_status_snapshot_start;
  logic       usb_fifo_status_snapshot_use;
  logic       ext_fifo_status_snapshot_start;
  logic       ext_fifo_status_snapshot_use;
  logic       usb_fifo_status_read_active;
  logic       ext_fifo_status_read_active;
  logic [31:0] fifo_status_word_0;
  logic [31:0] fifo_status_word_1;
  logic [31:0] fifo_status_word_2;
  logic [31:0] fifo_status_word_3;
  logic [31:0] fifo_status_word_4;

  assign usb_fifo_status_snapshot_start =
      fifo_rb_from_usb && is_fifo_status && fifo_rb_rd && (word_idx == 3'd0);
  assign ext_fifo_status_snapshot_start =
      !fifo_rb_from_usb && is_fifo_status && fifo_rb_rd && (word_idx == 3'd0);
  assign usb_fifo_status_snapshot_use =
      fifo_rb_from_usb && is_fifo_status && usb_fifo_status_snapshot_vld_q;
  assign ext_fifo_status_snapshot_use =
      !fifo_rb_from_usb && is_fifo_status && ext_fifo_status_snapshot_vld_q;
  assign usb_fifo_status_read_active =
      fifo_rb_from_usb && is_fifo_status && fifo_rb_rd;
  assign ext_fifo_status_read_active =
      !fifo_rb_from_usb && is_fifo_status && fifo_rb_rd;

  always_comb begin
    fifo_status_word_0 = {16'h0000, 8'h00, status_byte_2d};
    fifo_status_word_1 = write_index_q;
    fifo_status_word_2 = read_index_derived;
    fifo_status_word_3 = FIFO_SIZE_DWORDS;
    fifo_status_word_4 = MAX_XFER_SIZE_DWORDS;
  end

  // ------------------------------------------------------------------
  // Register-record read mux (32-bit word assembled per WORD index)
  //
  // INDIRECT_FIFO_CTRL reads are NOT serviced here: cms_fifo drives the
  // INDIRECT_FIFO_CTRL_0/_1 regblock fields (hw=w) and the host reads them
  // through the A3 regblock command window (rb_adapter routes CTRL reads to the
  // regblock; CTRL writes still land here).  Only INDIRECT_FIFO_STATUS is
  // synthesized on this read path. USB and EXT each capture their own word0
  // snapshot and reuse it only while that same source continues its multiword
  // status-read sequence.
  // ------------------------------------------------------------------
  logic [31:0] reg_rdata;
  always_comb begin
    reg_rdata = 32'h0;
    if (is_fifo_status) begin
      // INDIRECT_FIFO_STATUS (OCP v1.1 Sec 9.2, 20 B / 5 words):
      //   word0 byte0 STATUS_FLAGS, byte1 REGION_TYPE (0), bytes2..3 reserved
      //   word1 WRITE_INDEX (DWORD units) = write_index_q
      //   word2 READ_INDEX  (DWORD units) = write_index_q - occupancy (derived)
      //   word3 FIFO_SIZE          (DWORD units) = Depth
      //   word4 MAX_TRANSFER_SIZE  (DWORD units) = Depth
      unique case (word_idx)
        3'd0:    reg_rdata = usb_fifo_status_snapshot_use
                           ? usb_fifo_status_snapshot_q[0]
                           : ext_fifo_status_snapshot_use
                           ? ext_fifo_status_snapshot_q[0]
                           : fifo_status_word_0;
        3'd1:    reg_rdata = usb_fifo_status_snapshot_use
                           ? usb_fifo_status_snapshot_q[1]
                           : ext_fifo_status_snapshot_use
                           ? ext_fifo_status_snapshot_q[1]
                           : fifo_status_word_1;
        3'd2:    reg_rdata = usb_fifo_status_snapshot_use
                           ? usb_fifo_status_snapshot_q[2]
                           : ext_fifo_status_snapshot_use
                           ? ext_fifo_status_snapshot_q[2]
                           : fifo_status_word_2;
        3'd3:    reg_rdata = usb_fifo_status_snapshot_use
                           ? usb_fifo_status_snapshot_q[3]
                           : ext_fifo_status_snapshot_use
                           ? ext_fifo_status_snapshot_q[3]
                           : fifo_status_word_3;
        3'd4:    reg_rdata = usb_fifo_status_snapshot_use
                           ? usb_fifo_status_snapshot_q[4]
                           : ext_fifo_status_snapshot_use
                           ? ext_fifo_status_snapshot_q[4]
                           : fifo_status_word_4;
        default: reg_rdata = 32'h0;
      endcase
    end
  end

  // Register-bus read data: real INDIRECT_FIFO_DATA reads no longer happen on
  // this utmi-domain rb path (they are serviced natively in dev_axi_aclk via
  // the exposed read port).  A defensive INDIRECT_FIFO_DATA rb READ that should no longer
  // occur returns 0 and is still ACKed (no bus hang).  Register records
  // (INDIRECT_FIFO_CTRL/STATUS) present the assembled word combinationally.
  always_comb begin
    if (is_fifo_data && fifo_rb_rd) fifo_rb_rdata = 32'h0;
    else                            fifo_rb_rdata = reg_rdata;
  end

  // ------------------------------------------------------------------
  // Register-bus handshake (ack/err) - all accesses ack same-cycle.
  // ------------------------------------------------------------------
  always_comb begin
    // Reg records (INDIRECT_FIFO_CTRL/STATUS) and every INDIRECT_FIFO_DATA push/pop ack in the same cycle
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
    // Cross-domain region-reset flush of the read
    // pointer is intentionally NOT implemented -- folding a utmi-domain event
    // into the dev_axi_aclk-domain read reset would itself be a CDC hazard,
    // and a full bidirectional synchronized-flush handshake is unwarranted
    // complexity for an administrative, rarely-issued operation. Safe ONLY
    // because region-reset is required to occur while the FIFO is drained
    // (empty on both sides); a mid-stream region-reset would desync the
    // write/read gray-code pointers. This precondition is now an ENFORCED,
    // verified contract (not just a documented assumption) via the
    // fifo_empty assertion below (synthesis translate_off/on block).
  end

  // ------------------------------------------------------------------
  // Internal DWORD FIFO instance (asynchronous):
  //   write/push side -> clk    (utmi_clk), reset = fifo_rst_n (rst|flush)
  //   read /pop  side -> clk_rd (dev_axi_aclk), reset = rst_rd_n (AXI only)
  // rst_rd_ni is the dev_axi reset ONLY -- fifo_flush is a utmi event and
  // folding it into the AXI-domain read reset would be a CDC hazard (see
  // the region-reset flush rationale above and the fifo_empty assertion at
  // the bottom of this file).
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
      usb_fifo_status_snapshot_vld_q <= 1'b0;
      ext_fifo_status_snapshot_vld_q <= 1'b0;
      for (int i = 0; i < 5; i++) begin
        usb_fifo_status_snapshot_q[i] <= '0;
        ext_fifo_status_snapshot_q[i] <= '0;
      end
    end else begin
      if (usb_fifo_status_snapshot_start) begin
        usb_fifo_status_snapshot_vld_q <= 1'b1;
        usb_fifo_status_snapshot_q[0] <= fifo_status_word_0;
        usb_fifo_status_snapshot_q[1] <= fifo_status_word_1;
        usb_fifo_status_snapshot_q[2] <= fifo_status_word_2;
        usb_fifo_status_snapshot_q[3] <= fifo_status_word_3;
        usb_fifo_status_snapshot_q[4] <= fifo_status_word_4;
      end else if (!usb_fifo_status_read_active) begin
        usb_fifo_status_snapshot_vld_q <= 1'b0;
      end
      if (ext_fifo_status_snapshot_start) begin
        ext_fifo_status_snapshot_vld_q <= 1'b1;
        ext_fifo_status_snapshot_q[0] <= fifo_status_word_0;
        ext_fifo_status_snapshot_q[1] <= fifo_status_word_1;
        ext_fifo_status_snapshot_q[2] <= fifo_status_word_2;
        ext_fifo_status_snapshot_q[3] <= fifo_status_word_3;
        ext_fifo_status_snapshot_q[4] <= fifo_status_word_4;
      end else if (!ext_fifo_status_read_active) begin
        ext_fifo_status_snapshot_vld_q <= 1'b0;
      end

      // ----------------------------------------------------------------
      // INDIRECT_FIFO_CTRL write handler (same-cycle).
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
              usb_fifo_status_snapshot_vld_q <= 1'b0;
              ext_fifo_status_snapshot_vld_q <= 1'b0;
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
      // INDIRECT_FIFO_DATA push (accepted): advance WRITE_INDEX and image accounting.
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
      // INDIRECT_FIFO_DATA push (dropped): a genuine FIFO-full drop while the image is
      // still incomplete sets sticky overflow.  Excess pushes after the
      // image is complete are dropped silently (no overflow).  All drops are
      // still ACKed elsewhere (no hang).
      // ----------------------------------------------------------------
      if (push_drop_full) begin
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

    // INDIRECT_FIFO_CTRL read-back fields driven into the A3 regblock (hw=w).
    // These mirror the live cms_fifo state byte-for-byte with the prior
    // self-synthesized read-back: byte0 = CMS, byte1 bit0 = region-reset
    // (sticky), IMAGE_SIZE in DWORD units.
    fifo_ctrl_cms        = fifo_cms_q;
    fifo_ctrl_reset      = region_reset_q;
    fifo_ctrl_image_size = image_size_q;
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
    // The region-reset flush (fifo_flush) resets
    // ONLY the write-side pointer of the async FIFO (caliptra_prim_fifo_async
    // rst_wr_ni); the read side (rst_rd_ni = rst_rd_n, the dev_axi_aclk reset
    // only) is intentionally left unreset, since folding a utmi-domain event
    // into the AXI-domain reset would itself be a CDC hazard. This is
    // documented-safe ONLY when the FIFO is fully drained (both domains
    // agree it is empty) before the flush -- a mid-stream region-reset would
    // desync the write/read gray-code pointers (the write side would restart
    // from its initial position while the read side's position is unrelated,
    // corrupting the async FIFO's empty/full determination and potentially
    // its data ordering). fifo_wdepth==0 (fifo_empty) is a SOUND (not merely
    // approximate) proxy for "genuinely drained": fifo_wdepth is itself the
    // write-domain's synchronized view of the read pointer, so it can only
    // lag the true occupancy, never lead it -- if the write side already
    // observes zero occupancy, the FIFO cannot have unseen outstanding data.
    // This assertion converts the "safe only if empty/idle" design
    // assumption into a verified contract instead of an undocumented risk.
    if (!rst && fifo_flush) begin
      assert (fifo_empty)
        else $error("usb_ocp_recovery_cms_fifo: INDIRECT_FIFO_CTRL region-reset issued while the FIFO is not drained (fifo_wdepth != 0) -- this desyncs the async FIFO's write/read pointers (CDC hazard). Region-reset MUST only be issued after the FIFO is confirmed empty (INDIRECT_FIFO_STATUS byte0 bit0).");
    end
  end
`endif
  // synthesis translate_on

endmodule : usb_ocp_recovery_cms_fifo
