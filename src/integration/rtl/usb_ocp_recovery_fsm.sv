// SPDX-License-Identifier: Apache-2.0
//-----------------------------------------------------------------------------
// usb_ocp_recovery_fsm
//-----------------------------------------------------------------------------
// OCP Secure Firmware Recovery v1.1 top-level recovery state machine.
//
// Spec references (OCP Recovery v1.1):
//   Sec 6   - Recovery process state machine (flowchart).
//   Sec 7   - Interface functions (reset, push, activation).
//   Sec 9.2 - DEVICE_STATUS  (command 0x24) encoding.
//   Sec 9.2 - RECOVERY_STATUS (command 0x27) encoding.
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
//   rst_ni                 rec_trigger
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
  input  logic        rst_ni,

  // Trigger inputs from SoC / platform
  input  logic        rec_trigger,
  input  logic        soc_boot_ack,

  // From A3 (register block control-field strobes)
  input  logic        device_reset_wr,
  input  logic [7:0]  device_reset_ctrl,
  input  logic [7:0]  device_reset_forced,
  input  logic [7:0]  device_reset_iface,
  // Per-byte strobes.  recovery_ctrl_wr pulses on ACTIVATE byte write;
  // _cms / _img_sel pulse on those byte writes so the FSM never misses an
  // update even if the host stops short of writing the ACTIVATE byte.
  input  logic        recovery_ctrl_wr,
  input  logic        recovery_ctrl_wr_cms,
  input  logic        recovery_ctrl_wr_img_sel,
  input  logic [7:0]  recovery_ctrl_cms,
  input  logic [7:0]  recovery_ctrl_img_sel,
  input  logic [7:0]  recovery_ctrl_activate,

  // Firmware writes zero to RECOVERY_CTRL.ACTIVATE_REC_IMG after it drains and
  // verifies the FIFO-backed image. This completes the device-side clear of a
  // pending Recovery Agent activation request.
  input  logic        firmware_activate_clear,

  // PROTOCOL_ERROR clear pulse from the control decoder. OCP Recovery v1.1
  // Sec 9.2 defines the clear-on-read behavior for the Recovery Agent USB
  // command; this pulses only after the Agent completes an IN DEVICE_STATUS
  // transfer that includes Byte 1, so firmware reads are non-destructive.
  input  logic        proto_err_rd_pulse,

  // Unsupported-command detect pulse from the reg-bus adapter (OCP Recovery
  // v1.1 Sec 9.1: "An unsupported command to a Device MUST set an unsupported
  // error condition in the DEVICE_STATUS").  High for one cycle when the host
  // accesses an unsupported OCP command code (e.g. the direct CMS-memory window
  // 0x29/0x2A/0x2B, which this FIFO-only transport does not implement).  Sets
  // the sticky PROTOCOL_ERROR latch to 0x01 (Unsupported/Write Command).
  input  logic        unsupported_cmd_set,

  // From A4 (FIFO/image push observation)
  input  logic        image_push_active,
  input  logic        image_push_done,
  input  logic        fifo_overflow,
  input  logic        fifo_abort_i,
  input  logic        fifo_reset_pulse_i,
  input  logic [31:0] image_size,
  input  logic [31:0] bytes_pushed,

  // To A3 (status write-back)
  output logic [7:0]  device_status_out,
  output logic [7:0]  device_status_protocol_err_out,
  // OCP v1.1 Section 9.2: REC_REASON_CODE is 16 bits at bytes 2..3.
  // The FSM uses only the low byte today but the wire is spec-width so the
  // regs block still sees a clean 2-byte field.
  output logic [15:0] device_status_reason_out,
  output logic [7:0]  recovery_status_out,
  output logic [7:0]  recovery_vendor_status_out,
  output logic [7:0]  hw_status_out,
  // OCP v1.1 Section 9.2: HW_STATUS layout requires distinct bytes
  // 1 (VENDOR_HW_STATUS), 2 (CTEMP), 3 (VENDOR_HW_STATUS_LENGTH).  These are
  // tied to 0 today; the ports exist so the byte layout stays spec-correct and
  // the FSM can extend without re-routing.
  output logic [7:0]  hw_status_vendor_out,
  output logic [7:0]  hw_status_ctemp_out,
  output logic [7:0]  hw_status_vendor_len_out,

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
  logic       activation_pending_q, activation_pending_d;
  // Sticky PROTOCOL_ERROR latch (OCP Recovery v1.1 Section 9.2).
  // Set when the FSM enters S_ERROR (rising edge of size_err/auth_err);
  // cleared on proto_err_rd_pulse (completed Recovery Agent read). Drives
  // device_status_protocol_err_out for the RDL hw=w status mirror.
  logic [7:0] proto_err_q, proto_err_d;

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
    activation_pending_d = activation_pending_q;
    // PROTOCOL_ERROR sticky latch defaults (final value set after case).
    proto_err_d = proto_err_q;

    if (fifo_abort_i || fifo_reset_pulse_i) begin
      state_d = (state_q == S_IDLE) ? S_IDLE : S_AWAIT_IMAGE;
      activation_pending_d = 1'b0;
      size_err_d = 1'b0;
      auth_err_d = 1'b0;
    end else begin
    unique case (state_q)
      S_IDLE: begin
        size_err_d = 1'b0;
        auth_err_d = 1'b0;
        activation_pending_d = 1'b0;
        if (device_reset_cmd) begin
          state_d       = S_RESETTING;
          reset_pulse_d = 1'b1;
        end else if (rec_trigger) begin
          state_d = S_DETECTED;
        end else if (recovery_ctrl_wr_cms) begin
          // Host-initiated recovery: any byte-0 write to RECOVERY_CTRL
          // signals that the host has selected a CMS for recovery and
          // intends to push an image (OCP Recovery v1.1 Sec 9.2).
          // img_idx_d is latched here as a convenience; a subsequent IMG_SEL
          // byte-1 write is still captured by S_DETECTED/S_AWAIT_IMAGE via the
          // recovery_ctrl_wr_img_sel strobe.
          img_idx_d = recovery_ctrl_img_sel[3:0];
          state_d   = S_DETECTED;
        end
      end

      S_DETECTED: begin
        if (device_reset_cmd) begin
          state_d       = S_RESETTING;
          reset_pulse_d = 1'b1;
        end else begin
          // Latch recovery-image index on IMG_SEL byte writes (per-byte
          // strobe so the FSM never misses an update).
          if (recovery_ctrl_wr_img_sel) begin
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
        end else if (image_push_done) begin
          if (size_mismatch) begin
            size_err_d = 1'b1;
            state_d    = S_ERROR;
          end else begin
            state_d = S_IMAGE_LOADED;
          end
        end else if (image_push_active) begin
          state_d = S_PUSH_ACTIVE;
        end else if (recovery_ctrl_wr_img_sel) begin
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
          activation_pending_d = 1'b0;
        end else if (activate_cmd) begin
          activation_pending_d = 1'b1;
        end else if (activation_pending_q && firmware_activate_clear) begin
          state_d = S_ACTIVATE;
          activation_pending_d = 1'b0;
        end else if (image_push_active) begin
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
        activation_pending_d = 1'b0;
      end

      default: begin
        state_d = S_IDLE;
      end
    endcase
    end

    // PROTOCOL_ERROR sticky set/clear is after the state case so _d reflects
    // this cycle's state transition. Clear on a completed Recovery Agent read
    // wins over a same-cycle set, implementing the OCP Recovery v1.1 Sec 9.2
    // clear-on-read behavior.
    if ((state_d == S_ERROR) && (state_q != S_ERROR)) begin
      if (auth_err_d) begin
        proto_err_d = 8'h02;  // auth failure
      end else if (size_err_d) begin
        proto_err_d = 8'h01;  // size mismatch
      end else begin
        proto_err_d = 8'h03;  // generic recovery failed
      end
    end
    // Unsupported/Write Command error (OCP Recovery v1.1 Sec 9.1 / Sec 9.2
    // DEVICE_STATUS byte 1 = 0x01).  Set when the host accesses an unsupported OCP
    // command code.  Guarded by proto_err_d == 0 so it does NOT overwrite an
    // existing sticky error (e.g. a recovery auth/size/generic failure or a
    // same-cycle S_ERROR set): the first error stays latched until the
    // Recovery Agent completes a DEVICE_STATUS read. Placed before the clear
    // so a same-cycle completed read still wins (clear-on-read).
    // unsupported_cmd_set is already USB-host source-qualified by the
    // reg-bus adapter (usb_ocp_recovery_rb_adapter.sv): an EXT/firmware
    // access to an unsupported command is dropped without asserting this
    // pulse, since that is an internal firmware issue, not a USB protocol
    // violation.
    if (unsupported_cmd_set && (proto_err_d == 8'h00)) begin
      proto_err_d = 8'h01;
    end
    if (proto_err_rd_pulse) begin
      proto_err_d = 8'h00;
    end
  end

  // ---------------------------------------------------------------------------
  // Output (status) encoding - Sec 9.2
  // ---------------------------------------------------------------------------
  logic [3:0] rec_status_code;

  always_comb begin
    // Defaults (healthy/idle)
    device_status_out              = DS_DEVICE_HEALTHY;
    // PROTOCOL_ERROR is sourced from the sticky latch.
    device_status_protocol_err_out = proto_err_q;
    device_status_reason_out       = 16'h0000;
    rec_status_code                = RS_NOT_IN_RECOVERY;
    recovery_vendor_status_out     = 8'h00;
    hw_status_out                  = 8'h00;
    // OCP v1.1 Section 9.2 - bytes 1..3 of HW_STATUS.  Tied to 0 today;
    // future hooks can replace these defaults without re-routing.
    hw_status_vendor_out           = 8'h00;
    hw_status_ctemp_out            = 8'h00;
    hw_status_vendor_len_out       = 8'h00;

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
          device_status_reason_out = 16'h0002; // vendor-defined reason
        end else if (size_err_q) begin
          rec_status_code          = RS_RECOVERY_FAILED;
          device_status_reason_out = 16'h0001;
        end else begin
          rec_status_code          = RS_RECOVERY_FAILED;
          device_status_reason_out = 16'h0003;
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
    if (!rst_ni) begin
      state_q       <= S_IDLE;
      img_idx_q     <= 4'h0;
      size_err_q    <= 1'b0;
      auth_err_q    <= 1'b0;
      reset_pulse_q <= 1'b0;
      activation_pending_q <= 1'b0;
      proto_err_q   <= 8'h00;
    end else begin
      state_q       <= state_d;
      img_idx_q     <= img_idx_d;
      size_err_q    <= size_err_d;
      auth_err_q    <= auth_err_d;
      reset_pulse_q <= reset_pulse_d;
      activation_pending_q <= activation_pending_d;
      proto_err_q   <= proto_err_d;
    end
  end

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------
`ifndef SYNTHESIS
  // X-check on critical controls
  always_ff @(posedge clk) begin
    if (rst_ni) begin
      assert (!$isunknown({rec_trigger, soc_boot_ack,
                           device_reset_wr, recovery_ctrl_wr,
                           image_push_active, image_push_done,
                           fifo_overflow}))
        else $error("usb_ocp_recovery_fsm: X on control input");
    end
  end

  // boot_req must only assert once image_ready has been asserted
  property p_boot_req_implies_image_ready;
    @(posedge clk) disable iff (!rst_ni)
      boot_req |-> image_ready;
  endproperty
  assert property (p_boot_req_implies_image_ready)
    else $error("usb_ocp_recovery_fsm: boot_req without image_ready");

  // fatal_err must only assert in S_ERROR
  property p_fatal_err_state;
    @(posedge clk) disable iff (!rst_ni)
      fatal_err |-> (state_q == S_ERROR);
  endproperty
  assert property (p_fatal_err_state)
    else $error("usb_ocp_recovery_fsm: fatal_err outside S_ERROR");

  // device_reset_req is a single-cycle pulse
  property p_reset_req_pulse;
    @(posedge clk) disable iff (!rst_ni)
      device_reset_req |=> !device_reset_req;
  endproperty
  assert property (p_reset_req_pulse)
    else $error("usb_ocp_recovery_fsm: device_reset_req not a pulse");

  // The Recovery Agent's 0x0F write records a pending activation request but
  // must not boot before firmware finishes drain/verification and clears the
  // standard field. Firmware nonzero writes are not presented as a clear.
  property p_ra_activate_waits_for_firmware_clear;
    @(posedge clk) disable iff (!rst_ni)
      (state_q == S_IMAGE_LOADED && activate_cmd && !firmware_activate_clear)
      |=> (state_q == S_IMAGE_LOADED);
  endproperty
  assert property (p_ra_activate_waits_for_firmware_clear)
    else $error("usb_ocp_recovery_fsm: RA activation booted before firmware clear");

  property p_firmware_clear_consumes_pending_activation;
    @(posedge clk) disable iff (!rst_ni)
      (state_q == S_IMAGE_LOADED && activation_pending_q && firmware_activate_clear)
      |=> (state_q == S_ACTIVATE);
  endproperty
  assert property (p_firmware_clear_consumes_pending_activation)
    else $error("usb_ocp_recovery_fsm: firmware activation clear did not enter S_ACTIVATE");

  // suppress unused-signal warnings for reserved inputs
  logic _unused_ok;
  assign _unused_ok = &{1'b0,
                        device_reset_forced,
                        device_reset_iface,
                        recovery_ctrl_cms,
                        1'b0};
`endif

endmodule
