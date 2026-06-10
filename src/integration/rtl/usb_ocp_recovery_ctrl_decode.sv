// SPDX-License-Identifier: Apache-2.0
//=============================================================================
// usb_ocp_recovery_ctrl_decode
//-----------------------------------------------------------------------------
// OCP Secure Firmware Recovery v1.1 - USB EP0 class-request decoder.
//
// Spec refs:
//   - OCP Recovery v1.1 Sec 8.5 (USB transport mapping to class-specific
//     control requests on EP0)
//   - OCP Recovery v1.1 Sec 9.1 (command framing), Sec 9.2 (register/command
//     list: PROT_CAP 0x22 .. VENDOR 0x2F)
//   - USB 2.0 Sec 9.3/9.4 (SETUP packet format and standard requests)
//
// Role:
//   Sit above the EP adapter (A1). A1 forwards class-filtered EP0 SETUP
//   transactions for the OCP recovery interface (top-level class-match filter
//   guarantees only OCP class requests reach this module). Per OCP Recovery
//   v1.1 Section 8.5.1 the class request encoding is fixed:
//     bmRequestType[6:5] = 2'b01 (Class)
//     bmRequestType[4:0] = 5'b00001 (Interface)
//     bRequest           = 8'h00  (OCP_RECOVERY_TRANSFER)
//     wValue[7:0]        = OCP command code (0x22..0x2F per OCP v1.1 Section 9.2 Tbl 9-1)
//     wValue[15:8]       = 8'h00  (reserved)
//     wIndex[7:0]        = REC_IFACE_NUM (interface filtering done at top)
//     wIndex[15:8]       = 8'h00  (reserved)
//     wLength            = byte count for the data stage
//   This module rejects (STALLs) any class request that does not match
//   bRequest==0x00 / wValue[15:8]==0 / wValue[7:0] in 0x22..0x2F.

// SETUP packet layout (little-endian, per USB 2.0 Table 9-2):
//   byte0    : bmRequestType
//   byte1    : bRequest
//   byte2..3 : wValue (LSB first - wValue[7:0] is byte2, wValue[15:8] is byte3)
//   byte4..5 : wIndex (LSB first)
//   byte6..7 : wLength (LSB first)
// setup_pkt[63:0] is byte0 in [7:0], byte7 in [63:56].
//
// Data plane:
//   OUT (SET_*) : ctrl_out_* stream -> rb_wr, rb_wdata; rb_ack paces ctrl_out_rdy.
//   IN  (GET_*) : rb_rd -> rb_rdata -> ctrl_in_* stream; ctrl_in_rdy paces offset.
//
// Control plane (FSM - 4 states, 2 bits):
//   S_IDLE   - wait for SETUP; classify.
//   S_WRITE  - stream OUT bytes to reg bus.
//   S_READ   - fetch bytes from reg bus and drive IN stream.
//   S_STALL  - pulse ctrl_set_stall for one cycle, wait ctrl_xfer_done.
//   S_WAIT   - wait for ctrl_xfer_done after clean completion.
//
// Reuse/area:
//   - Single 16-bit offset counter doubles as write-offset, read-offset and
//     remaining-length compare source (compared against wLength_q).
//   - wLength/wValue/wIndex are latched once from setup_pkt; byte offset
//     to reg bus starts at 0 (OCP Recovery v1.1 Section 8.5.1: the USB
//     class request transports the entire register payload contiguously
//     with no in-payload offset; wValue carries the command code, not an
//     offset).
//=============================================================================

module usb_ocp_recovery_ctrl_decode (
  input  logic        clk,
  input  logic        rst,                 // sync active-high

  // from A1 control EP
  input  logic        setup_pkt_vld,
  input  logic [63:0] setup_pkt,
  input  logic [7:0]  ctrl_out_data,
  input  logic        ctrl_out_vld,
  input  logic        ctrl_out_last,
  output logic        ctrl_out_rdy,
  output logic [7:0]  ctrl_in_data,
  output logic        ctrl_in_vld,
  output logic        ctrl_in_last,
  input  logic        ctrl_in_rdy,
  output logic        ctrl_set_stall,
  input  logic        ctrl_xfer_done,

  // to/from regs (A3)
  output logic [7:0]  rb_cmd,
  output logic [15:0] rb_offset,
  output logic        rb_wr,
  output logic        rb_rd,
  output logic [7:0]  rb_wdata,
  output logic        rb_be,
  input  logic [7:0]  rb_rdata,
  input  logic        rb_ack,
  input  logic        rb_err
);

  //---------------------------------------------------------------------------
  // Decoded SETUP fields (combinational view of setup_pkt)
  //---------------------------------------------------------------------------
  logic [7:0]  bmrt_s;
  logic [7:0]  brq_s;
  logic [15:0] wvalue_s;
  logic [15:0] wlength_s;
  logic        is_class_s;
  logic        is_in_s;
  logic [7:0]  cmd_code_s;       // OCP cmd code from wValue[7:0]
  logic        cmd_code_valid_s; // wValue[7:0] in 0x22..0x2F
  logic        ocp_req_valid_s;  // full OCP request encoding match

  always_comb begin
    bmrt_s      = setup_pkt[7:0];
    brq_s       = setup_pkt[15:8];
    wvalue_s    = {setup_pkt[31:24], setup_pkt[23:16]};
    // wIndex currently unused by the OCP mapping beyond interface select;
    // interface filtering is enforced upstream in usb_ocp_recovery_top.
    wlength_s   = {setup_pkt[63:56], setup_pkt[55:48]};

    is_class_s       = (bmrt_s[6:5] == 2'b01);
    is_in_s          = bmrt_s[7];
    cmd_code_s       = wvalue_s[7:0];
    // OCP Recovery v1.1 Section 9.2 Tbl 9-1: defined commands span PROT_CAP
    // (0x22) through VENDOR (0x2F).
    cmd_code_valid_s = (cmd_code_s >= 8'h22) && (cmd_code_s <= 8'h2F);
    // OCP Recovery v1.1 Section 8.5.1: bRequest MUST be OCP_RECOVERY_TRANSFER
    // (0x00) and wValue[15:8] MUST be 0 for a recovery class request.
    ocp_req_valid_s  = (brq_s == 8'h00) && (wvalue_s[15:8] == 8'h00)
                       && cmd_code_valid_s;
  end

  //---------------------------------------------------------------------------
  // FSM
  //---------------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE  = 3'd0,
    S_WRITE = 3'd1,
    S_READ  = 3'd2,
    S_RLAT  = 3'd3,  // read-latency: rb_rd asserted, waiting for rb_ack
    S_STALL = 3'd4,
    S_WAIT  = 3'd5
  } state_t;

  state_t state_q, state_d;

  //---------------------------------------------------------------------------
  // Latched SETUP fields
  //---------------------------------------------------------------------------
  logic [7:0]  cmd_q,     cmd_d;
  logic [15:0] length_q,  length_d;
  logic [15:0] offset_q,  offset_d;
  logic [7:0]  rdata_q,   rdata_d;  // holds rb_rdata across IN-stream wait

  //---------------------------------------------------------------------------
  // Sequential
  //---------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
      state_q  <= S_IDLE;
      cmd_q    <= '0;
      length_q <= '0;
      offset_q <= '0;
      rdata_q  <= '0;
    end else begin
      state_q  <= state_d;
      cmd_q    <= cmd_d;
      length_q <= length_d;
      offset_q <= offset_d;
      rdata_q  <= rdata_d;
    end
  end

  //---------------------------------------------------------------------------
  // Next-state / outputs
  //---------------------------------------------------------------------------
  always_comb begin
    // Defaults
    state_d        = state_q;
    cmd_d          = cmd_q;
    length_d       = length_q;
    offset_d       = offset_q;
    rdata_d        = rdata_q;

    ctrl_out_rdy   = 1'b0;
    ctrl_in_data   = 8'h00;
    ctrl_in_vld    = 1'b0;
    ctrl_in_last   = 1'b0;
    ctrl_set_stall = 1'b0;

    rb_cmd         = cmd_q;
    rb_offset      = offset_q;
    rb_wr          = 1'b0;
    rb_rd          = 1'b0;
    rb_wdata       = ctrl_out_data;
    rb_be          = 1'b1;

    unique case (state_q)
      //-----------------------------------------------------------------------
      S_IDLE: begin
        // C12: the upstream usb_ocp_recovery_top class-match filter has
        // already guaranteed bmRequestType[6:5]=01, bmRequestType[4:0]=00001,
        // bRequest=0x00, wIndex[7:0]=REC_IFACE_NUM, wIndex[15:8]=0 before
        // setup_pkt_vld asserts.  The legacy `if (is_class_s)` guard is
        // therefore unreachable; an assertion below ensures any future
        // filter loosening is caught at sim time.
        if (setup_pkt_vld) begin
          // Per OCP Recovery v1.1 Section 8.5.1: the wire-format command
          // code lives in wValue[7:0], NOT in bRequest. bRequest is the
          // fixed transport opcode OCP_RECOVERY_TRANSFER (0x00).
          cmd_d    = cmd_code_s;
          // Section 8.5.1: payload is transported contiguously with no
          // in-payload offset; the running offset counter starts at 0.
          offset_d = 16'h0000;
          length_d = wlength_s;
          if (!ocp_req_valid_s) begin
            // Malformed OCP class request (bad bRequest, reserved
            // wValue[15:8], or unsupported cmd code) -> STALL per
            // Section 8.5.
            state_d = S_STALL;
          end else if (wlength_s == 16'd0) begin
            // Zero-length data stage is illegal for these register
            // commands (every 0x22..0x2F carries at least 1 byte).
            state_d = S_STALL;
          end else if (is_in_s) begin
            state_d = S_RLAT;   // start first read fetch
          end else begin
            state_d = S_WRITE;
          end
        end
      end

      //-----------------------------------------------------------------------
      // OUT data stage: byte-stream from host -> reg bus.
      // Assert rb_wr while ctrl_out_vld; ctrl_out_rdy gated by rb_ack.
      //-----------------------------------------------------------------------
      S_WRITE: begin
        rb_wr        = ctrl_out_vld;
        rb_wdata     = ctrl_out_data;
        ctrl_out_rdy = rb_ack;

        if (ctrl_out_vld && rb_ack) begin
          if (rb_err) begin
            state_d = S_STALL;
          end else begin
            offset_d = offset_q + 16'd1;
            if (ctrl_out_last || (offset_q + 16'd1 >= length_q)) begin
              state_d = S_WAIT;
            end
          end
        end
      end

      //-----------------------------------------------------------------------
      // IN data stage step 1: issue rb_rd, wait for rb_ack.
      //-----------------------------------------------------------------------
      S_RLAT: begin
        rb_rd = 1'b1;
        if (rb_ack) begin
          if (rb_err) begin
            state_d = S_STALL;
          end else begin
            rdata_d = rb_rdata;
            state_d = S_READ;
          end
        end
      end

      //-----------------------------------------------------------------------
      // IN data stage step 2: drive byte on ctrl_in; advance on rdy.
      //-----------------------------------------------------------------------
      S_READ: begin
        ctrl_in_data = rdata_q;
        ctrl_in_vld  = 1'b1;
        ctrl_in_last = (offset_q + 16'd1 >= length_q);

        if (ctrl_in_rdy) begin
          offset_d = offset_q + 16'd1;
          if (offset_q + 16'd1 >= length_q) begin
            state_d = S_WAIT;
          end else begin
            state_d = S_RLAT;
          end
        end
      end

      //-----------------------------------------------------------------------
      S_STALL: begin
        ctrl_set_stall = 1'b1;
        state_d        = S_WAIT;
      end

      //-----------------------------------------------------------------------
      S_WAIT: begin
        if (ctrl_xfer_done) begin
          state_d  = S_IDLE;
          offset_d = '0;
        end
      end

      default: state_d = S_IDLE;
    endcase
  end

  //---------------------------------------------------------------------------
  // Assertions (synthesis-ignored)
  //---------------------------------------------------------------------------
`ifndef SYNTHESIS
  // Inputs must not be X during active operation.
  always_ff @(posedge clk) begin
    if (!rst) begin
      if (setup_pkt_vld) begin
        assert (!$isunknown(setup_pkt))
          else $error("ctrl_decode: setup_pkt has X with vld high");
      end
      if (ctrl_out_vld) begin
        assert (!$isunknown(ctrl_out_data))
          else $error("ctrl_decode: ctrl_out_data X with vld high");
      end
      if (rb_ack) begin
        assert (!$isunknown(rb_rdata))
          else $error("ctrl_decode: rb_rdata X with ack high");
      end
      // C12: the upstream filter in usb_ocp_recovery_top.sv asserts
      // setup_pkt_vld only for already-class-matched SETUPs.  Catch any
      // future divergence (e.g. someone loosens the filter) here so the
      // ctrl_decode's S_IDLE arm does not silently fire on non-class.
      if (setup_pkt_vld) begin
        assert (is_class_s)
          else $error("ctrl_decode: setup_pkt_vld asserted on non-class SETUP (bmRequestType[6:5] != 01)");
      end
      // rb_wr and rb_rd are mutually exclusive.
      assert (!(rb_wr && rb_rd))
        else $error("ctrl_decode: rb_wr and rb_rd asserted simultaneously");
    end
  end
`endif

endmodule : usb_ocp_recovery_ctrl_decode
