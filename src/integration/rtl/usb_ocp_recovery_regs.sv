// ============================================================================
// usb_ocp_recovery_regs.sv
//
// OCP Recovery v1.1 (Sec 9.2) register file for the USB recovery function.
// Services the reg-bus from A2 (ctrl_decode) or the mgmt AXI-Lite path muxed
// at A6. Routes INDIRECT_* commands that touch the CMS FIFO (0x2A, 0x2B,
// 0x2C, 0x2D, 0x2E) down to A4. Everything else is handled locally:
//   0x22 PROT_CAP            RO   static tie from A6           (16 B)
//   0x23 DEVICE_ID           RO   static tie from A6           (24 B)
//   0x24 DEVICE_STATUS       RO   live from A5 (fsm)           (>=7 B)
//   0x25 DEVICE_RESET        WO   pulse + latched payload to A5 (3 B)
//   0x26 RECOVERY_CTRL       RW   registered here, strobed to A5 (3 B)
//   0x27 RECOVERY_STATUS     RO   live from A5                 (2 B)
//   0x28 HW_STATUS           RO   live from A5; write strobe to A5 (>=4 B)
//   0x29 INDIRECT_CTRL       RW   registered here (6 B)
//   0x2F VENDOR              RW   stub (writes dropped, reads zero)
//
// Handshake: one-cycle rb_ack one clock after rb_rd/rb_wr for local regs.
// For FIFO-routed commands rb_ack/rb_rdata/rb_err are the pass-through from
// A4. Unknown command code or offset past the command's defined length
// raises rb_err for one cycle.
//
// Reset: synchronous, active-high (SV integration convention).
// ============================================================================

module usb_ocp_recovery_regs (
  input  logic        clk,
  input  logic        rst,

  // reg-bus from A2 / A6 mux
  input  logic [7:0]  rb_cmd,
  input  logic [15:0] rb_offset,
  input  logic        rb_wr,
  input  logic        rb_rd,
  input  logic [7:0]  rb_wdata,
  input  logic        rb_be,
  output logic [7:0]  rb_rdata,
  output logic        rb_ack,
  output logic        rb_err,

  // FIFO path to A4 (cms_fifo)
  output logic        fifo_rb_sel,
  output logic [7:0]  fifo_rb_cmd,
  output logic [15:0] fifo_rb_offset,
  output logic        fifo_rb_wr,
  output logic        fifo_rb_rd,
  output logic [7:0]  fifo_rb_wdata,
  input  logic [7:0]  fifo_rb_rdata,
  input  logic        fifo_rb_ack,
  input  logic        fifo_rb_err,

  // Sideband to A5 (fsm) - writes
  output logic        device_reset_wr,
  output logic [7:0]  device_reset_ctrl,
  output logic [7:0]  device_reset_forced,
  output logic [7:0]  device_reset_iface,
  output logic        recovery_ctrl_wr,
  output logic [7:0]  recovery_ctrl_cms,
  output logic [7:0]  recovery_ctrl_img_sel,
  output logic [7:0]  recovery_ctrl_activate,
  output logic        hw_status_wr,
  output logic [7:0]  hw_status_wdata,

  // Sideband from A5 (fsm) - read data
  input  logic [7:0]  device_status_in,
  input  logic [7:0]  device_status_protocol_err_in,
  input  logic [7:0]  device_status_reason_in,
  input  logic [7:0]  recovery_status_in,
  input  logic [7:0]  recovery_vendor_status_in,
  input  logic [7:0]  hw_status_in,

  // Static capability inputs (tied by A6)
  input  logic [127:0] prot_cap_in,
  input  logic [191:0] device_id_in
);

  // --------------------------------------------------------------------------
  // Command code localparams (OCP Recovery v1.1 Sec 9.2 Table 9-1)
  // --------------------------------------------------------------------------
  localparam logic [7:0] CMD_PROT_CAP            = 8'h22;
  localparam logic [7:0] CMD_DEVICE_ID           = 8'h23;
  localparam logic [7:0] CMD_DEVICE_STATUS       = 8'h24;
  localparam logic [7:0] CMD_DEVICE_RESET        = 8'h25;
  localparam logic [7:0] CMD_RECOVERY_CTRL       = 8'h26;
  localparam logic [7:0] CMD_RECOVERY_STATUS     = 8'h27;
  localparam logic [7:0] CMD_HW_STATUS           = 8'h28;
  localparam logic [7:0] CMD_INDIRECT_CTRL       = 8'h29;
  localparam logic [7:0] CMD_INDIRECT_STATUS     = 8'h2A;
  localparam logic [7:0] CMD_INDIRECT_DATA       = 8'h2B;
  localparam logic [7:0] CMD_INDIRECT_FIFO_CTRL  = 8'h2C;
  localparam logic [7:0] CMD_INDIRECT_FIFO_STATUS= 8'h2D;
  localparam logic [7:0] CMD_INDIRECT_FIFO_DATA  = 8'h2E;
  localparam logic [7:0] CMD_VENDOR              = 8'h2F;

  // Max byte offset (exclusive) per locally-handled command.
  localparam int LEN_PROT_CAP        = 16;
  localparam int LEN_DEVICE_ID       = 24;
  localparam int LEN_DEVICE_STATUS   = 64; // >=7, allow vendor status span
  localparam int LEN_DEVICE_RESET    = 3;
  localparam int LEN_RECOVERY_CTRL   = 3;
  localparam int LEN_RECOVERY_STATUS = 2;
  localparam int LEN_HW_STATUS       = 4;
  localparam int LEN_INDIRECT_CTRL   = 6;
  localparam int LEN_VENDOR          = 256;

  // --------------------------------------------------------------------------
  // Locally-stored RW / WO registers
  // --------------------------------------------------------------------------
  // DEVICE_RESET (0x25) - WO, 3 bytes; captured so fsm can use them on the
  // cycle after the command writes its last byte. Reset default = all zero.
  logic [7:0] device_reset_ctrl_q;
  logic [7:0] device_reset_forced_q;
  logic [7:0] device_reset_iface_q;

  // RECOVERY_CTRL (0x26) - RW, 3 bytes.
  logic [7:0] recovery_ctrl_cms_q;
  logic [7:0] recovery_ctrl_img_sel_q;
  logic [7:0] recovery_ctrl_activate_q;

  // INDIRECT_CTRL (0x29) - RW, 6 bytes.
  //   byte 0 : CMS region index
  //   byte 1 : Reserved
  //   bytes 2..5 : Image Offset [31:0], little-endian
  logic [7:0]  indirect_ctrl_cms_q;
  logic [7:0]  indirect_ctrl_rsvd_q;
  logic [31:0] indirect_ctrl_img_offset_q;

  // --------------------------------------------------------------------------
  // Decode: is this command routed to A4?
  // --------------------------------------------------------------------------
  logic is_fifo_cmd;
  always_comb begin
    unique case (rb_cmd)
      CMD_INDIRECT_STATUS,
      CMD_INDIRECT_DATA,
      CMD_INDIRECT_FIFO_CTRL,
      CMD_INDIRECT_FIFO_STATUS,
      CMD_INDIRECT_FIFO_DATA: is_fifo_cmd = 1'b1;
      default:                is_fifo_cmd = 1'b0;
    endcase
  end

  // A local access is anything that isn't fifo-routed and isn't reserved.
  logic is_local_cmd;
  always_comb begin
    unique case (rb_cmd)
      CMD_PROT_CAP,
      CMD_DEVICE_ID,
      CMD_DEVICE_STATUS,
      CMD_DEVICE_RESET,
      CMD_RECOVERY_CTRL,
      CMD_RECOVERY_STATUS,
      CMD_HW_STATUS,
      CMD_INDIRECT_CTRL,
      CMD_VENDOR:    is_local_cmd = 1'b1;
      default:       is_local_cmd = 1'b0;
    endcase
  end

  // Max offset (exclusive) for the current command.
  logic [15:0] cmd_len;
  always_comb begin
    unique case (rb_cmd)
      CMD_PROT_CAP:        cmd_len = 16'(LEN_PROT_CAP);
      CMD_DEVICE_ID:       cmd_len = 16'(LEN_DEVICE_ID);
      CMD_DEVICE_STATUS:   cmd_len = 16'(LEN_DEVICE_STATUS);
      CMD_DEVICE_RESET:    cmd_len = 16'(LEN_DEVICE_RESET);
      CMD_RECOVERY_CTRL:   cmd_len = 16'(LEN_RECOVERY_CTRL);
      CMD_RECOVERY_STATUS: cmd_len = 16'(LEN_RECOVERY_STATUS);
      CMD_HW_STATUS:       cmd_len = 16'(LEN_HW_STATUS);
      CMD_INDIRECT_CTRL:   cmd_len = 16'(LEN_INDIRECT_CTRL);
      CMD_VENDOR:          cmd_len = 16'(LEN_VENDOR);
      default:             cmd_len = 16'd0;
    endcase
  end

  logic access;
  logic off_ok;
  logic local_access;
  assign access       = rb_wr | rb_rd;
  assign off_ok       = (rb_offset < cmd_len);
  assign local_access = access & is_local_cmd & ~is_fifo_cmd;

  // --------------------------------------------------------------------------
  // FIFO pass-through combinational wiring
  // --------------------------------------------------------------------------
  assign fifo_rb_sel    = is_fifo_cmd;
  assign fifo_rb_cmd    = rb_cmd;
  assign fifo_rb_offset = rb_offset;
  assign fifo_rb_wr     = rb_wr & is_fifo_cmd;
  assign fifo_rb_rd     = rb_rd & is_fifo_cmd;
  assign fifo_rb_wdata  = rb_wdata;

  // --------------------------------------------------------------------------
  // Local read data mux (combinational)
  // --------------------------------------------------------------------------
  logic [7:0] local_rdata;
  logic [7:0] prot_cap_byte;
  logic [7:0] device_id_byte;
  logic [7:0] dev_status_byte;
  logic [7:0] rec_status_byte;
  logic [7:0] hw_status_byte;
  logic [7:0] rec_ctrl_byte;
  logic [7:0] ind_ctrl_byte;

  // PROT_CAP (0x22): 16 bytes from packed input (bytes 0..15 = bits 7:0..127:120)
  always_comb begin
    prot_cap_byte = 8'h00;
    if (rb_offset < 16) begin
      prot_cap_byte = prot_cap_in[rb_offset[3:0]*8 +: 8];
    end
  end

  // DEVICE_ID (0x23): 24 bytes
  always_comb begin
    device_id_byte = 8'h00;
    if (rb_offset < 24) begin
      device_id_byte = device_id_in[rb_offset[4:0]*8 +: 8];
    end
  end

  // DEVICE_STATUS (0x24)
  // Byte 0 : Device Status                (from fsm)
  // Byte 1 : Reserved                     (0)
  // Byte 2 : Protocol Error               (from fsm)
  // Byte 3 : Recovery Reason Code         (from fsm)
  // Byte 4 : Heartbeat / Vendor Status Length (tied 0)
  // Bytes 5..: Vendor Status (tied 0)
  always_comb begin
    unique case (rb_offset[5:0])
      6'd0:    dev_status_byte = device_status_in;
      6'd2:    dev_status_byte = device_status_protocol_err_in;
      6'd3:    dev_status_byte = device_status_reason_in;
      default: dev_status_byte = 8'h00;
    endcase
  end

  // RECOVERY_CTRL (0x26) read-back
  always_comb begin
    unique case (rb_offset[1:0])
      2'd0:    rec_ctrl_byte = recovery_ctrl_cms_q;
      2'd1:    rec_ctrl_byte = recovery_ctrl_img_sel_q;
      2'd2:    rec_ctrl_byte = recovery_ctrl_activate_q;
      default: rec_ctrl_byte = 8'h00;
    endcase
  end

  // RECOVERY_STATUS (0x27)
  //   Byte 0 : Device Recovery Status  (from fsm)
  //   Byte 1 : Vendor Recovery Status  (from fsm)
  always_comb begin
    unique case (rb_offset[0])
      1'b0:    rec_status_byte = recovery_status_in;
      1'b1:    rec_status_byte = recovery_vendor_status_in;
      default: rec_status_byte = 8'h00;
    endcase
  end

  // HW_STATUS (0x28)
  //   Byte 0 : Device HW Status (from fsm)
  //   Byte 1 : Vendor HW Status Length (tied 0)
  //   Byte 2 : CTemp (tied 0)
  //   Byte 3 : Reserved (tied 0)
  always_comb begin
    unique case (rb_offset[1:0])
      2'd0:    hw_status_byte = hw_status_in;
      default: hw_status_byte = 8'h00;
    endcase
  end

  // INDIRECT_CTRL (0x29) read-back
  always_comb begin
    unique case (rb_offset[2:0])
      3'd0:    ind_ctrl_byte = indirect_ctrl_cms_q;
      3'd1:    ind_ctrl_byte = indirect_ctrl_rsvd_q;
      3'd2:    ind_ctrl_byte = indirect_ctrl_img_offset_q[7:0];
      3'd3:    ind_ctrl_byte = indirect_ctrl_img_offset_q[15:8];
      3'd4:    ind_ctrl_byte = indirect_ctrl_img_offset_q[23:16];
      3'd5:    ind_ctrl_byte = indirect_ctrl_img_offset_q[31:24];
      default: ind_ctrl_byte = 8'h00;
    endcase
  end

  // Top-level local read mux
  always_comb begin
    unique case (rb_cmd)
      CMD_PROT_CAP:        local_rdata = prot_cap_byte;
      CMD_DEVICE_ID:       local_rdata = device_id_byte;
      CMD_DEVICE_STATUS:   local_rdata = dev_status_byte;
      CMD_DEVICE_RESET:    local_rdata = 8'h00; // WO
      CMD_RECOVERY_CTRL:   local_rdata = rec_ctrl_byte;
      CMD_RECOVERY_STATUS: local_rdata = rec_status_byte;
      CMD_HW_STATUS:       local_rdata = hw_status_byte;
      CMD_INDIRECT_CTRL:   local_rdata = ind_ctrl_byte;
      CMD_VENDOR:          local_rdata = 8'h00;
      default:             local_rdata = 8'h00;
    endcase
  end

  // --------------------------------------------------------------------------
  // Local write decode + sideband strobes (combinational pulses; registered
  // into _q storage below so FSM sees a clean 1-cycle pulse too).
  // --------------------------------------------------------------------------
  logic wr_device_reset;
  logic wr_recovery_ctrl;
  logic wr_hw_status;
  logic wr_indirect_ctrl;
  logic local_wr_ok;

  assign local_wr_ok      = rb_wr & is_local_cmd & off_ok & rb_be;
  assign wr_device_reset  = local_wr_ok & (rb_cmd == CMD_DEVICE_RESET);
  assign wr_recovery_ctrl = local_wr_ok & (rb_cmd == CMD_RECOVERY_CTRL);
  assign wr_hw_status     = local_wr_ok & (rb_cmd == CMD_HW_STATUS);
  assign wr_indirect_ctrl = local_wr_ok & (rb_cmd == CMD_INDIRECT_CTRL);

  // --------------------------------------------------------------------------
  // Sequential: storage + handshake registers
  // --------------------------------------------------------------------------
  logic        rb_ack_q;
  logic        rb_err_q;
  logic [7:0]  rb_rdata_q;

  logic        device_reset_wr_q;
  logic        recovery_ctrl_wr_q;
  logic        hw_status_wr_q;
  logic [7:0]  hw_status_wdata_q;

  always_ff @(posedge clk) begin
    if (rst) begin
      // handshake
      rb_ack_q                 <= 1'b0;
      rb_err_q                 <= 1'b0;
      rb_rdata_q               <= '0;
      // DEVICE_RESET latched payload (Sec 9.2: all zero = no reset)
      device_reset_ctrl_q      <= 8'h00;
      device_reset_forced_q    <= 8'h00;
      device_reset_iface_q     <= 8'h00;
      device_reset_wr_q        <= 1'b0;
      // RECOVERY_CTRL (Sec 9.2: default 0 = no image selected, not activated)
      recovery_ctrl_cms_q      <= 8'h00;
      recovery_ctrl_img_sel_q  <= 8'h00;
      recovery_ctrl_activate_q <= 8'h00;
      recovery_ctrl_wr_q       <= 1'b0;
      // HW_STATUS write strobe
      hw_status_wr_q           <= 1'b0;
      hw_status_wdata_q        <= 8'h00;
      // INDIRECT_CTRL (Sec 9.2: default region 0, offset 0)
      indirect_ctrl_cms_q        <= 8'h00;
      indirect_ctrl_rsvd_q       <= 8'h00;
      indirect_ctrl_img_offset_q <= 32'h0000_0000;
    end else begin
      // ----- handshake defaults -----
      rb_ack_q   <= 1'b0;
      rb_err_q   <= 1'b0;
      rb_rdata_q <= '0;

      // ----- sideband pulse defaults -----
      device_reset_wr_q  <= 1'b0;
      recovery_ctrl_wr_q <= 1'b0;
      hw_status_wr_q     <= 1'b0;

      // ----- local accesses: single-cycle ack one clock after request -----
      if (access & ~is_fifo_cmd) begin
        if (~is_local_cmd) begin
          // unknown / reserved command code
          rb_err_q   <= 1'b1;
          rb_rdata_q <= '0;
        end else if (~off_ok) begin
          // offset past defined register length
          rb_err_q   <= 1'b1;
          rb_rdata_q <= '0;
        end else begin
          rb_ack_q   <= 1'b1;
          rb_rdata_q <= local_rdata;
        end
      end

      // ----- writable register update -----
      if (wr_device_reset) begin
        unique case (rb_offset[1:0])
          2'd0: device_reset_ctrl_q   <= rb_wdata;
          2'd1: device_reset_forced_q <= rb_wdata;
          2'd2: device_reset_iface_q  <= rb_wdata;
          default: ;
        endcase
        // Pulse to fsm when control byte (offset 0) is written - that is the
        // byte that actually triggers a reset per Sec 9.2 Table 9-7.
        if (rb_offset[1:0] == 2'd0) device_reset_wr_q <= 1'b1;
      end

      if (wr_recovery_ctrl) begin
        unique case (rb_offset[1:0])
          2'd0: recovery_ctrl_cms_q      <= rb_wdata;
          2'd1: recovery_ctrl_img_sel_q  <= rb_wdata;
          2'd2: recovery_ctrl_activate_q <= rb_wdata;
          default: ;
        endcase
        // Pulse the fsm when Activate Recovery Image byte (offset 2) is
        // written - per Sec 9.2 Table 9-9 that byte starts activation.
        if (rb_offset[1:0] == 2'd2) recovery_ctrl_wr_q <= 1'b1;
      end

      if (wr_hw_status) begin
        hw_status_wr_q    <= 1'b1;
        hw_status_wdata_q <= rb_wdata;
      end

      if (wr_indirect_ctrl) begin
        unique case (rb_offset[2:0])
          3'd0: indirect_ctrl_cms_q                 <= rb_wdata;
          3'd1: indirect_ctrl_rsvd_q                <= rb_wdata;
          3'd2: indirect_ctrl_img_offset_q[7:0]     <= rb_wdata;
          3'd3: indirect_ctrl_img_offset_q[15:8]    <= rb_wdata;
          3'd4: indirect_ctrl_img_offset_q[23:16]   <= rb_wdata;
          3'd5: indirect_ctrl_img_offset_q[31:24]   <= rb_wdata;
          default: ;
        endcase
      end
    end
  end

  // --------------------------------------------------------------------------
  // Output driver: mux local handshake with fifo pass-through.
  //   Local path: 1 cycle latency (_q registers above).
  //   FIFO path : handshake comes straight from A4 the same cycle A4 asserts.
  //
  // The two paths are mutually exclusive because is_fifo_cmd gates the
  // direction of the pending access.
  // --------------------------------------------------------------------------
  assign rb_ack   = rb_ack_q   | fifo_rb_ack;
  assign rb_err   = rb_err_q   | fifo_rb_err;
  assign rb_rdata = fifo_rb_ack ? fifo_rb_rdata : rb_rdata_q;

  // --------------------------------------------------------------------------
  // Sideband outputs to A5
  // --------------------------------------------------------------------------
  assign device_reset_wr        = device_reset_wr_q;
  assign device_reset_ctrl      = device_reset_ctrl_q;
  assign device_reset_forced    = device_reset_forced_q;
  assign device_reset_iface     = device_reset_iface_q;
  assign recovery_ctrl_wr       = recovery_ctrl_wr_q;
  assign recovery_ctrl_cms      = recovery_ctrl_cms_q;
  assign recovery_ctrl_img_sel  = recovery_ctrl_img_sel_q;
  assign recovery_ctrl_activate = recovery_ctrl_activate_q;
  assign hw_status_wr           = hw_status_wr_q;
  assign hw_status_wdata        = hw_status_wdata_q;

  // --------------------------------------------------------------------------
  // Assertions
  // --------------------------------------------------------------------------
`ifndef SYNTHESIS
  // rb_wr and rb_rd should not be asserted simultaneously
  assert property (@(posedge clk) disable iff (rst) !(rb_wr & rb_rd))
    else $error("usb_ocp_recovery_regs: rb_wr and rb_rd both asserted");

  // When fifo cmd is selected, local ack must be zero
  assert property (@(posedge clk) disable iff (rst)
                   !(rb_ack_q & fifo_rb_ack))
    else $error("usb_ocp_recovery_regs: local and fifo ack collision");

  // X-check on key inputs during access
  assert property (@(posedge clk) disable iff (rst)
                   (rb_wr | rb_rd) |-> !$isunknown({rb_cmd, rb_offset}))
    else $error("usb_ocp_recovery_regs: X on rb_cmd/rb_offset during access");
`endif

endmodule
