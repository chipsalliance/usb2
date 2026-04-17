// SPDX-License-Identifier: Apache-2.0
//-----------------------------------------------------------------------------
// usb_ocp_recovery_fsm
//-----------------------------------------------------------------------------
// OCP Secure Firmware Recovery v1.1 top-level recovery state machine.
//
// Spec references (OCP Recovery v1.1):
//   Sec 6   - Recovery process state machine (flowchart).
//   Sec 7   - Interface functions (reset, push, activation).
//   Sec 9.2 - DEVICE_STATUS  (command 0x23) encoding.
//   Sec 9.2 - RECOVERY_STATUS (command 0x2A) encoding.
//   Sec 9.2 - RECOVERY_CTRL  (command 0x26) activation byte.
//   Sec 9.2 - DEVICE_RESET   (command 0x25) reset control byte.
//
// Responsibility:
//   - Consume control-field strobes from the register block (A3).
//   - Observe FIFO push progress from the CMS FIFO block (A4).
//   - Drive DEVICE_STATUS / RECOVERY_STATUS write-back bytes back to A3.
//   - Drive SoC sideband: recovery_active, image_ready, boot_req,
//     device_reset_req, fatal_err.
//
// State diagram (Sec 6 flow, minimized):
//
//   rst                    rec_trigger
//    |                          |
//    v                          v
//   S_IDLE ---rec_trigger---> S_DETECTED
//    ^                          |
//    |                          v (entered recovery, ready for image)
//    |                       S_AWAIT_IMAGE <----+
//    |                          |               |
//    |                          | image_push_active
//    |                          v               |
//    |                       S_PUSH_ACTIVE -----+
//    |                          |
//    |                          | image_push_done
//    |                          v
//    |                       S_IMAGE_LOADED
//    |                          |
//    |                          | recovery_ctrl_wr & activate=0x0F
//    |                          v
//    |                       S_ACTIVATE
//    |                          |
//    |                          v
//    |                       S_BOOT_REQ ---soc_boot_ack---> S_DONE --+
//    |                                                               |
//    +-------------------device_reset_wr------------------S_RESETTING|
//    |                                                               |
//    +-----------fifo_overflow | auth/fatal err---------> S_ERROR ---+
//
// Error exits converge on S_ERROR which latches fatal_err and posts the
// appropriate RECOVERY_STATUS code (0xC recovery failed).
// Reset exits converge on S_RESETTING which pulses device_reset_req.
//
// Encoding: enum logic [3:0] - 10 states, 4 bits (minimum 4). Unique case.
//-----------------------------------------------------------------------------

module usb_ocp_recovery_fsm (
  input  logic        clk,
  input  logic        rst,

  // Trigger inputs from SoC / platform
  input  logic        rec_trigger,
  input  logic        soc_boot_ack,

  // From A3 (register block control-field strobes)
  input  logic        device_reset_wr,
  input  logic [7:0]  device_reset_ctrl,
  input  logic [7:0]  device_reset_forced,
  input  logic [7:0]  device_reset_iface,
  input  logic        recovery_ctrl_wr,
  input  logic [7:0]  recovery_ctrl_cms,
  input  logic [7:0]  recovery_ctrl_img_sel,
  input  logic [7:0]  recovery_ctrl_activate,

  // From A4 (FIFO/image push observation)
  input  logic        image_push_active,
  input  logic        image_push_done,
  input  logic        fifo_overflow,
  input  logic [31:0] image_size,
  input  logic [31:0] bytes_pushed,

  // To A3 (status write-back)
  output logic [7:0]  device_status_out,
  output logic [7:0]  device_status_protocol_err_out,
  output logic [7:0]  device_status_reason_out,
  output logic [7:0]  recovery_status_out,
  output logic [7:0]  recovery_vendor_status_out,
  output logic [7:0]  hw_status_out,

  // SoC sideband
  output logic        recovery_active,
  output logic        image_ready,
  output logic        boot_req,
  output logic        device_reset_req,
  output logic        fatal_err
);

  // ---------------------------------------------------------------------------
  // Spec-defined constants
  // ---------------------------------------------------------------------------
  // DEVICE_STATUS dev_status byte (Sec 9.2 DEVICE_STATUS)
  localparam logic [7:0] DS_STATUS_PENDING   = 8'h00;
  localparam logic [7:0] DS_DEVICE_HEALTHY   = 8'h01;
  localparam logic [7:0] DS_DEVICE_ERROR     = 8'h02;
  localparam logic [7:0] DS_RECOVERY_MODE    = 8'h03;
  localparam logic [7:0] DS_RECOVERY_PENDING = 8'h04;
  localparam logic [7:0] DS_RUNNING_RECOVERY = 8'h05;
  localparam logic [7:0] DS_BOOT_FAILURE     = 8'h0E;
  localparam logic [7:0] DS_FATAL_ERROR      = 8'h0F;

  // RECOVERY_STATUS dev_recovery_status nibble (Sec 9.2 RECOVERY_STATUS)
  // Byte[0][3:0] = status code; Byte[0][7:4] = recovery image index
  localparam logic [3:0] RS_NOT_IN_RECOVERY    = 4'h0;
  localparam logic [3:0] RS_AWAITING_IMAGE     = 4'h1;
  localparam logic [3:0] RS_BOOTING_IMAGE      = 4'h2;
  localparam logic [3:0] RS_RECOVERY_SUCCESS   = 4'h3;
  localparam logic [3:0] RS_RECOVERY_FAILED    = 4'hC;
  localparam logic [3:0] RS_AUTH_FAILURE       = 4'hD;
  localparam logic [3:0] RS_ENTRY_ERROR        = 4'hE;
  localparam logic [3:0] RS_INVALID_CAS        = 4'hF;

  // RECOVERY_CTRL byte[2] activate code (Sec 9.2)
  localparam logic [7:0] RC_ACTIVATE_IMAGE = 8'h0F;

  // DEVICE_RESET byte[0] (Sec 9.2)
  localparam logic [7:0] DR_NO_RESET      = 8'h00;
  localparam logic [7:0] DR_RESET_DEVICE  = 8'h01;
  localparam logic [7:0] DR_RESET_MGMT    = 8'h02;

  // ---------------------------------------------------------------------------
  // State encoding
  // ---------------------------------------------------------------------------
  typedef enum logic [3:0] {
    S_IDLE          = 4'd0,
    S_DETECTED      = 4'd1,
    S_AWAIT_IMAGE   = 4'd2,
    S_PUSH_ACTIVE   = 4'd3,
    S_IMAGE_LOADED  = 4'd4,
    S_ACTIVATE      = 4'd5,
    S_BOOT_REQ      = 4'd6,
    S_DONE          = 4'd7,
    S_ERROR         = 4'd8,
    S_RESETTING     = 4'd9
  } rec_state_e;

  rec_state_e state_q, state_d;

  // ---------------------------------------------------------------------------
  // Internal registered housekeeping
  // ---------------------------------------------------------------------------
  logic [3:0] img_idx_q, img_idx_d;  // RECOVERY_STATUS high nibble
  logic       size_err_q, size_err_d;
  logic       auth_err_q, auth_err_d;   // placeholder; latched by rec_trigger-time semantics
  logic       reset_pulse_q, reset_pulse_d; // 1-cycle device_reset_req pulse

  // Detection of device-reset request: Sec 7 - any non-zero DEVICE_RESET ctrl
  // write triggers a reset path. DR_NO_RESET is benign.
  logic       device_reset_cmd;
  assign device_reset_cmd = device_reset_wr &&
                            (device_reset_ctrl != DR_NO_RESET);

  // Activation command: Sec 7.3 / Sec 9.2 RECOVERY_CTRL.activate = 0x0F
  logic       activate_cmd;
  assign activate_cmd = recovery_ctrl_wr &&
                        (recovery_ctrl_activate == RC_ACTIVATE_IMAGE);

  // Size mismatch check: if image_push_done asserted with bytes_pushed !=
  // image_size, flag as error (Sec 8.2 indirect memory semantics).
  logic       size_mismatch;
  assign size_mismatch = image_push_done &&
                         (image_size != 32'd0) &&
                         (bytes_pushed != image_size);

  // ---------------------------------------------------------------------------
  // Next-state logic
  // ---------------------------------------------------------------------------
  always_comb begin
    // Defaults
    state_d       = state_q;
    img_idx_d     = img_idx_q;
    size_err_d    = size_err_q;
    auth_err_d    = auth_err_q;
    reset_pulse_d = 1'b0;

    unique case (state_q)
      S_IDLE: begin
        size_err_d = 1'b0;
        auth_err_d = 1'b0;
        if (device_reset_cmd) begin
          state_d       = S_RESETTING;
          reset_pulse_d = 1'b1;
        end else if (rec_trigger) begin
          state_d = S_DETECTED;
        end
      end

      S_DETECTED: begin
        // Transient entry state: advance to awaiting image next cycle.
        // Not a passthrough in the bad sense - allows DEVICE_STATUS to be
        // observed as Recovery Pending for one cycle and lets downstream
        // status clients sample a clean edge.
        if (device_reset_cmd) begin
          state_d       = S_RESETTING;
          reset_pulse_d = 1'b1;
        end else begin
          // latch selected recovery image index for RECOVERY_STATUS
          if (recovery_ctrl_wr) begin
            img_idx_d = recovery_ctrl_img_sel[3:0];
          end
          state_d = S_AWAIT_IMAGE;
        end
      end

      S_AWAIT_IMAGE: begin
        if (device_reset_cmd) begin
          state_d       = S_RESETTING;
          reset_pulse_d = 1'b1;
        end else if (fifo_overflow) begin
          state_d = S_ERROR;
        end else if (image_push_active) begin
          state_d = S_PUSH_ACTIVE;
        end else if (recovery_ctrl_wr) begin
          // software can update image index selection while waiting
          img_idx_d = recovery_ctrl_img_sel[3:0];
        end
      end

      S_PUSH_ACTIVE: begin
        if (device_reset_cmd) begin
          state_d       = S_RESETTING;
          reset_pulse_d = 1'b1;
        end else if (fifo_overflow) begin
          state_d = S_ERROR;
        end else if (image_push_done) begin
          if (size_mismatch) begin
            size_err_d = 1'b1;
            state_d    = S_ERROR;
          end else begin
            state_d = S_IMAGE_LOADED;
          end
        end
      end

      S_IMAGE_LOADED: begin
        if (device_reset_cmd) begin
          state_d       = S_RESETTING;
          reset_pulse_d = 1'b1;
        end else if (activate_cmd) begin
          state_d = S_ACTIVATE;
        end else if (image_push_active) begin
          // New image push replaces previously loaded image
          state_d = S_PUSH_ACTIVE;
        end
      end

      S_ACTIVATE: begin
        // Drive boot request in next state
        if (device_reset_cmd) begin
          state_d       = S_RESETTING;
          reset_pulse_d = 1'b1;
        end else begin
          state_d = S_BOOT_REQ;
        end
      end

      S_BOOT_REQ: begin
        if (device_reset_cmd) begin
          state_d       = S_RESETTING;
          reset_pulse_d = 1'b1;
        end else if (soc_boot_ack) begin
          state_d = S_DONE;
        end
      end

      S_DONE: begin
        if (device_reset_cmd) begin
          state_d       = S_RESETTING;
          reset_pulse_d = 1'b1;
        end else if (rec_trigger) begin
          // Re-enter recovery on new trigger
          state_d = S_DETECTED;
        end
      end

      S_ERROR: begin
        if (device_reset_cmd) begin
          state_d       = S_RESETTING;
          reset_pulse_d = 1'b1;
        end
        // Otherwise stick in ERROR until SoC resets us.
      end

      S_RESETTING: begin
        // device_reset_req pulsed one cycle on entry. Return to IDLE so SoC
        // re-triggers recovery if desired.
        state_d = S_IDLE;
      end

      default: begin
        state_d = S_IDLE;
      end
    endcase
  end

  // ---------------------------------------------------------------------------
  // Output (status) encoding - Sec 9.2
  // ---------------------------------------------------------------------------
  logic [3:0] rec_status_code;

  always_comb begin
    // Defaults (healthy/idle)
    device_status_out              = DS_DEVICE_HEALTHY;
    device_status_protocol_err_out = 8'h00;
    device_status_reason_out       = 8'h00;
    rec_status_code                = RS_NOT_IN_RECOVERY;
    recovery_vendor_status_out     = 8'h00;
    hw_status_out                  = 8'h00;

    recovery_active  = 1'b0;
    image_ready      = 1'b0;
    boot_req         = 1'b0;
    fatal_err        = 1'b0;

    unique case (state_q)
      S_IDLE: begin
        device_status_out = DS_DEVICE_HEALTHY;
        rec_status_code   = RS_NOT_IN_RECOVERY;
      end

      S_DETECTED: begin
        device_status_out = DS_RECOVERY_MODE;
        rec_status_code   = RS_AWAITING_IMAGE;
        recovery_active   = 1'b1;
      end

      S_AWAIT_IMAGE: begin
        device_status_out = DS_RECOVERY_MODE;
        rec_status_code   = RS_AWAITING_IMAGE;
        recovery_active   = 1'b1;
      end

      S_PUSH_ACTIVE: begin
        device_status_out = DS_RECOVERY_MODE;
        rec_status_code   = RS_AWAITING_IMAGE;
        recovery_active   = 1'b1;
      end

      S_IMAGE_LOADED: begin
        device_status_out = DS_RECOVERY_PENDING;
        rec_status_code   = RS_AWAITING_IMAGE;
        recovery_active   = 1'b1;
        image_ready       = 1'b1;
      end

      S_ACTIVATE: begin
        device_status_out = DS_RECOVERY_PENDING;
        rec_status_code   = RS_BOOTING_IMAGE;
        recovery_active   = 1'b1;
        image_ready       = 1'b1;
      end

      S_BOOT_REQ: begin
        device_status_out = DS_RUNNING_RECOVERY;
        rec_status_code   = RS_BOOTING_IMAGE;
        recovery_active   = 1'b1;
        image_ready       = 1'b1;
        boot_req          = 1'b1;
      end

      S_DONE: begin
        device_status_out = DS_RUNNING_RECOVERY;
        rec_status_code   = RS_RECOVERY_SUCCESS;
        recovery_active   = 1'b1;
      end

      S_ERROR: begin
        device_status_out = DS_FATAL_ERROR;
        // Choose reason code by latched error flavor
        if (auth_err_q) begin
          rec_status_code          = RS_AUTH_FAILURE;
          device_status_reason_out = 8'h02; // vendor-defined reason
        end else if (size_err_q) begin
          rec_status_code          = RS_RECOVERY_FAILED;
          device_status_reason_out = 8'h01;
        end else begin
          rec_status_code          = RS_RECOVERY_FAILED;
          device_status_reason_out = 8'h03;
        end
        recovery_active = 1'b1;
        fatal_err       = 1'b1;
      end

      S_RESETTING: begin
        device_status_out = DS_STATUS_PENDING;
        rec_status_code   = RS_NOT_IN_RECOVERY;
      end

      default: begin
        device_status_out = DS_DEVICE_HEALTHY;
        rec_status_code   = RS_NOT_IN_RECOVERY;
      end
    endcase
  end

  // Pack RECOVERY_STATUS byte 0: [7:4] image index, [3:0] status code.
  assign recovery_status_out = {img_idx_q, rec_status_code};

  // device_reset_req is a one-shot pulse on entry to S_RESETTING.
  assign device_reset_req = reset_pulse_q;

  // ---------------------------------------------------------------------------
  // Sequential
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
      state_q       <= S_IDLE;
      img_idx_q     <= 4'h0;
      size_err_q    <= 1'b0;
      auth_err_q    <= 1'b0;
      reset_pulse_q <= 1'b0;
    end else begin
      state_q       <= state_d;
      img_idx_q     <= img_idx_d;
      size_err_q    <= size_err_d;
      auth_err_q    <= auth_err_d;
      reset_pulse_q <= reset_pulse_d;
    end
  end

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------
`ifndef SYNTHESIS
  // X-check on critical controls
  always_ff @(posedge clk) begin
    if (!rst) begin
      assert (!$isunknown({rec_trigger, soc_boot_ack,
                           device_reset_wr, recovery_ctrl_wr,
                           image_push_active, image_push_done,
                           fifo_overflow}))
        else $error("usb_ocp_recovery_fsm: X on control input");
    end
  end

  // boot_req must only assert once image_ready has been asserted
  property p_boot_req_implies_image_ready;
    @(posedge clk) disable iff (rst)
      boot_req |-> image_ready;
  endproperty
  assert property (p_boot_req_implies_image_ready)
    else $error("usb_ocp_recovery_fsm: boot_req without image_ready");

  // fatal_err must only assert in S_ERROR
  property p_fatal_err_state;
    @(posedge clk) disable iff (rst)
      fatal_err |-> (state_q == S_ERROR);
  endproperty
  assert property (p_fatal_err_state)
    else $error("usb_ocp_recovery_fsm: fatal_err outside S_ERROR");

  // device_reset_req is a single-cycle pulse
  property p_reset_req_pulse;
    @(posedge clk) disable iff (rst)
      device_reset_req |=> !device_reset_req;
  endproperty
  assert property (p_reset_req_pulse)
    else $error("usb_ocp_recovery_fsm: device_reset_req not a pulse");

  // suppress unused-signal warnings for reserved inputs
  logic _unused_ok;
  assign _unused_ok = &{1'b0,
                        device_reset_forced,
                        device_reset_iface,
                        recovery_ctrl_cms,
                        1'b0};
`endif

endmodule
