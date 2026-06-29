// SPDX-License-Identifier: Apache-2.0
//=============================================================================
// usb_ocp_recovery_ctrl_decode
//-----------------------------------------------------------------------------
// OCP Secure Firmware Recovery v1.1 USB EP0 class-request decoder.
//
// Spec refs:
//   - OCP Recovery v1.1 Sec 8.5 (USB transport mapping to class-specific
//     control requests on EP0)
//   - OCP Recovery v1.1 Sec 9.1 (command framing), Sec 9.2 (register/command
//     list: PROT_CAP .. INDIRECT_FIFO_DATA, codes OCP_CMD_MIN..OCP_CMD_MAX)
//   - USB 2.0 Sec 9.3/9.4 (SETUP packet format and standard requests)
//
// Role:
//   Sit above the reg-bus adapter (A3).  The VHDL arbiter forwards class-
//   filtered EP0 SETUP transactions; this module classifies the OCP command
//   and streams the data stage between the arbiter control-transfer surface
//   (32-bit word + byte-enable) and the word-wide rb_* reg bus.
//
// Data plane:
//   One 32-bit word is moved per rb_* beat; wLength remains byte-granular so
//   the final word can be partial.
//     end-of-transfer fires when (word_offset+1)*4 >= wLength.
//     final-word valid byte count = wLength - word_offset*4, clamped 1..4.
//     final-word byte-enable mask  = (1 << count) - 1; full words use 4'hF.
//   OUT (writes): drive rb_wdata = ctrl_out_data, rb_wstrb = word mask.
//   IN  (reads) : issue rb_rd with rb_wstrb = word mask, latch rb_rdata,
//                 drive ctrl_in_data + ctrl_in_be (be meaningful only on the
//                 final partial word).
//
// SETUP packet layout (little-endian, per USB 2.0 Table 9-2):
//   byte0    : bmRequestType
//   byte1    : bRequest
//   byte2..3 : wValue (LSB first)
//   byte4..5 : wIndex (LSB first)
//   byte6..7 : wLength (LSB first)
// setup_pkt[63:0] is byte0 in [7:0], byte7 in [63:56].
//
// Control plane (FSM):
//   S_IDLE  - wait for SETUP; classify.
//   S_WRITE - stream OUT words to the reg bus.
//   S_RLAT  - issue rb_rd, wait for rb_ack.
//   S_READ  - drive IN word; advance on ctrl_in_rdy.
//   S_RDONE - drive a zero-length ctrl_in_last terminating beat for a clean
//             short-packet end (rb_err past the command's valid length).
//   S_STALL - pulse ctrl_set_stall for one cycle.
//   S_WAIT  - wait for ctrl_xfer_done after completion.
//=============================================================================

module usb_ocp_recovery_ctrl_decode (
  input  logic        clk,
  input  logic        rst,                 // sync active-high

  // from the arbiter control EP surface (32-bit word + byte-enable)
  input  logic        setup_pkt_vld,
  input  logic [63:0] setup_pkt,
  input  logic [31:0] ctrl_out_data,
  input  logic [3:0]  ctrl_out_be,
  input  logic        ctrl_out_vld,
  input  logic        ctrl_out_last,
  output logic        ctrl_out_rdy,
  output logic [31:0] ctrl_in_data,
  output logic [3:0]  ctrl_in_be,
  output logic        ctrl_in_vld,
  output logic        ctrl_in_last,
  input  logic        ctrl_in_rdy,
  output logic        ctrl_set_stall,
  input  logic        ctrl_xfer_done,

  // to/from regs (A3) -- word-wide reg bus, rb_offset is a WORD index
  output logic [7:0]  rb_cmd,
  output logic [15:0] rb_offset,
  output logic        rb_wr,
  output logic        rb_rd,
  output logic [31:0] rb_wdata,
  output logic [3:0]  rb_wstrb,
  input  logic [31:0] rb_rdata,
  input  logic        rb_ack,
  input  logic        rb_err
);

  // OCP Recovery v1.1 Sec 9.2 command-code bounds from the shared package.
  import usb_ocp_recovery_pkg::*;

  //---------------------------------------------------------------------------
  // Decoded SETUP fields (combinational view of setup_pkt)
  //---------------------------------------------------------------------------
  logic [7:0]  bmrt_s;
  logic [7:0]  brq_s;
  logic [15:0] wvalue_s;
  logic [15:0] wlength_s;
  logic        is_class_s;
  logic        is_in_s;
  logic [7:0]  cmd_code_s;
  logic        cmd_code_valid_s;
  logic        ocp_req_valid_s;

  always_comb begin
    bmrt_s      = setup_pkt[7:0];
    brq_s       = setup_pkt[15:8];
    wvalue_s    = {setup_pkt[31:24], setup_pkt[23:16]};
    wlength_s   = {setup_pkt[63:56], setup_pkt[55:48]};

    is_class_s       = (bmrt_s[6:5] == 2'b01);
    is_in_s          = bmrt_s[7];
    cmd_code_s       = wvalue_s[7:0];
    cmd_code_valid_s = (cmd_code_s >= OCP_CMD_MIN) && (cmd_code_s <= OCP_CMD_MAX);
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
    S_RLAT  = 3'd3,
    S_STALL = 3'd4,
    S_WAIT  = 3'd5,
    S_RDONE = 3'd6
  } state_t;

  state_t state_q, state_d;

  //---------------------------------------------------------------------------
  // Latched SETUP fields.  offset_q is a WORD index; length_q is wLength bytes.
  //---------------------------------------------------------------------------
  logic [7:0]  cmd_q,     cmd_d;
  logic [15:0] length_q,  length_d;
  logic [15:0] offset_q,  offset_d;     // word index
  logic [31:0] rdata_q,   rdata_d;

  //---------------------------------------------------------------------------
  // Partial-final-word arithmetic (combinational, from offset_q / length_q).
  //   byte_base       = offset_q * 4
  //   remaining_bytes = length_q - byte_base
  //   is_last_word    = remaining_bytes <= 4
  //   word_mask       = byte-enable mask of the current word
  //---------------------------------------------------------------------------
  logic [15:0] byte_base;
  logic [16:0] remaining_bytes;
  logic        is_last_word;
  logic [3:0]  word_mask;
  always_comb begin
    byte_base       = {offset_q[13:0], 2'b00};
    remaining_bytes = {1'b0, length_q} - {1'b0, byte_base};
    is_last_word    = (remaining_bytes <= 17'd4);
    if (remaining_bytes >= 17'd4) begin
      word_mask = 4'hF;
    end else begin
      unique case (remaining_bytes[1:0])
        2'd1:    word_mask = 4'h1;
        2'd2:    word_mask = 4'h3;
        2'd3:    word_mask = 4'h7;
        default: word_mask = 4'hF; // remaining_bytes==0 cannot occur mid-xfer
      endcase
    end
  end

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
    ctrl_in_data   = 32'h0;
    ctrl_in_be     = 4'h0;
    ctrl_in_vld    = 1'b0;
    ctrl_in_last   = 1'b0;
    ctrl_set_stall = 1'b0;

    rb_cmd         = cmd_q;
    rb_offset      = offset_q;
    rb_wr          = 1'b0;
    rb_rd          = 1'b0;
    rb_wdata       = ctrl_out_data;
    rb_wstrb       = word_mask;

    // Global early-termination escape (USB 2.0 Sec 8.5.3.2 host abort).
    if (ctrl_xfer_done) begin
      state_d  = S_IDLE;
      offset_d = '0;
    end else begin
    unique case (state_q)
      //-----------------------------------------------------------------------
      S_IDLE: begin
        if (setup_pkt_vld) begin
          cmd_d    = cmd_code_s;
          offset_d = 16'h0000;
          length_d = wlength_s;
          if (!ocp_req_valid_s) begin
            state_d = S_STALL;
          end else if (wlength_s == 16'd0) begin
            state_d = S_STALL;
          end else if (is_in_s) begin
            state_d = S_RLAT;
          end else begin
            state_d = S_WRITE;
          end
        end
      end

      //-----------------------------------------------------------------------
      // OUT data stage: word-stream from host -> reg bus.
      //-----------------------------------------------------------------------
      S_WRITE: begin
        rb_wr        = ctrl_out_vld;
        rb_wdata     = ctrl_out_data;
        rb_wstrb     = word_mask;
        ctrl_out_rdy = rb_ack;

        if (ctrl_out_vld && rb_ack) begin
          if (rb_err) begin
            state_d = S_STALL;
          end else begin
            offset_d = offset_q + 16'd1;
            if (ctrl_out_last || is_last_word) begin
              state_d = S_WAIT;
            end
          end
        end
      end

      //-----------------------------------------------------------------------
      // IN data stage step 1: issue rb_rd, wait for rb_ack.
      //
      // rb_err semantics on the read path:
      //   - rb_err with offset_q == 0: the very first word of the command is
      //     unreadable (genuinely declined / bad command) -> STALL.
      //   - rb_err with offset_q != 0: the read ran one word PAST the command's
      //     valid length (rb_adapter "offset past command window", e.g. the
      //     5th word of PROT_CAP which is only 16 valid bytes).  This is a
      //     CLEAN short-packet end-of-data, NOT a protocol error.  We have
      //     already delivered offset_q valid words, so terminate the DATA
      //     stage gracefully via S_RDONE (USB 2.0 Sec 8.5.3.2 / 5.5.3: a data
      //     stage shorter than wLength terminates the transfer; the host
      //     accepts the short packet as end-of-data).
      //-----------------------------------------------------------------------
      S_RLAT: begin
        rb_rd    = 1'b1;
        rb_wstrb = word_mask;
        if (rb_ack) begin
          if (rb_err) begin
            if (offset_q == 16'd0) begin
              state_d = S_STALL;   // first-word unreadable -> genuine STALL
            end else begin
              state_d = S_RDONE;   // ran past valid length -> short-packet end
            end
          end else begin
            rdata_d = rb_rdata;
            state_d = S_READ;
          end
        end
      end

      //-----------------------------------------------------------------------
      // IN data stage step 2: drive word on ctrl_in; advance on rdy.
      //-----------------------------------------------------------------------
      S_READ: begin
        ctrl_in_data = rdata_q;
        ctrl_in_be   = word_mask;
        ctrl_in_vld  = 1'b1;
        ctrl_in_last = is_last_word;

        if (ctrl_in_rdy) begin
          offset_d = offset_q + 16'd1;
          if (is_last_word) begin
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
      // Short-packet terminating beat.  The valid words were already
      // delivered in prior S_READ cycles; drive one final zero-length beat
      // (ctrl_in_be = 0) with ctrl_in_last = 1 so the arbiter staging buffer
      // marks the response complete at exactly the bytes already accumulated
      // (no extra bytes are added).  This yields a correct short packet for a
      // command shorter than wLength (e.g. PROT_CAP: 16 bytes for wLength=64).
      //-----------------------------------------------------------------------
      S_RDONE: begin
        ctrl_in_data = 32'h0;
        ctrl_in_be   = 4'h0;
        ctrl_in_vld  = 1'b1;
        ctrl_in_last = 1'b1;
        if (ctrl_in_rdy) begin
          state_d = S_WAIT;
        end
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
    end // !ctrl_xfer_done
  end

  //---------------------------------------------------------------------------
  // Assertions (synthesis-ignored)
  //---------------------------------------------------------------------------
`ifndef SYNTHESIS
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
      if (setup_pkt_vld) begin
        assert (is_class_s)
          else $error("ctrl_decode: setup_pkt_vld asserted on non-class SETUP");
      end
      assert (!(rb_wr && rb_rd))
        else $error("ctrl_decode: rb_wr and rb_rd asserted simultaneously");
    end
  end
`endif

endmodule : usb_ocp_recovery_ctrl_decode
