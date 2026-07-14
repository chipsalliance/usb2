// SPDX-License-Identifier: Apache-2.0
// ============================================================================
// usb_ocp_recovery_hwif_adapter.sv
//
// Hardware-interface endpoint for OCP Recovery USB commands. This module
// keeps USB register reads and writes out of the firmware cpuif path: reads
// are sourced directly from hardware-owned values or regblock hwif_out
// storage, and writes become explicit hwif next/we signals. Firmware/AXI
// continues to use the generated cpuif independently.
//
// OCP Recovery v1.1 Sec 9.1 requires unsupported commands and USB writes to
// read-only commands to set DEVICE_STATUS.PROTOCOL_ERROR. The corresponding
// pulse is generated here because this is the sole USB register endpoint.
// ============================================================================

module usb_ocp_recovery_hwif_adapter (
  input  logic [7:0]  cmd,
  input  logic [15:0] word_offset,
  input  logic        wr,
  input  logic        rd,
  input  logic [31:0] wdata,
  input  logic [3:0]  wstrb,

  input  logic [31:0] prot_cap_0,
  input  logic [31:0] prot_cap_1,
  input  logic [31:0] prot_cap_2,
  input  logic [31:0] prot_cap_3,
  input  logic [191:0] device_id,
  input  logic [7:0]  device_status,
  input  logic [7:0]  protocol_error,
  input  logic [15:0] recovery_reason,
  input  logic [7:0]  recovery_status,
  input  logic [7:0]  recovery_vendor_status,
  input  logic [7:0]  hw_status,
  input  logic [7:0]  hw_vendor_status,
  input  logic [7:0]  hw_ctemp,
  input  logic [7:0]  hw_vendor_status_len,
  input  logic [7:0]  fifo_ctrl_cms,
  input  logic        fifo_ctrl_reset,
  input  logic [31:0] fifo_ctrl_image_size,
  input  logic [7:0]  device_reset_ctrl_value,
  input  logic [7:0]  device_reset_forced_value,
  input  logic [7:0]  device_reset_iface_value,
  input  logic [7:0]  recovery_ctrl_cms_value,
  input  logic [7:0]  recovery_ctrl_img_sel_value,
  input  logic [7:0]  recovery_ctrl_activate_value,
  input  logic [7:0]  vendor_value,

  output logic [31:0] rdata,
  output logic        ack,
  output logic        err,
  output logic        is_fifo_cmd,
  output logic        protocol_error_set,

  output logic [7:0]  device_reset_ctrl_next,
  output logic        device_reset_ctrl_we,
  output logic [7:0]  device_reset_forced_next,
  output logic        device_reset_forced_we,
  output logic [7:0]  device_reset_iface_next,
  output logic        device_reset_iface_we,
  output logic [7:0]  recovery_ctrl_cms_next,
  output logic        recovery_ctrl_cms_we,
  output logic [7:0]  recovery_ctrl_img_sel_next,
  output logic        recovery_ctrl_img_sel_we,
  output logic [7:0]  recovery_ctrl_activate_next,
  output logic        recovery_ctrl_activate_we,
  output logic [7:0]  vendor_next,
  output logic        vendor_we,

  output logic        device_reset_wr,
  output logic [7:0]  device_reset_ctrl,
  output logic [7:0]  device_reset_forced,
  output logic [7:0]  device_reset_iface,
  output logic        recovery_ctrl_wr_cms,
  output logic        recovery_ctrl_wr_img_sel,
  output logic        recovery_ctrl_wr_activate,
  output logic [7:0]  recovery_ctrl_cms,
  output logic [7:0]  recovery_ctrl_img_sel,
  output logic [7:0]  recovery_ctrl_activate
);

  import usb_ocp_recovery_pkg::*;

  logic        access;
  logic        supported_cmd;
  logic        host_ro_cmd;
  logic [15:0] cmd_len;
  logic [15:0] byte_offset;

  always_comb begin
    access             = wr | rd;
    is_fifo_cmd        = ((cmd == OCP_CMD_INDIRECT_FIFO_CTRL) && wr)
                       || ((cmd == OCP_CMD_INDIRECT_FIFO_STATUS) && rd)
                       ||  (cmd == OCP_CMD_INDIRECT_FIFO_DATA);
    supported_cmd      = 1'b1;
    host_ro_cmd        = 1'b0;
    cmd_len            = '0;
    byte_offset        = {word_offset[13:0], 2'b00};
    rdata              = '0;
    ack                = access;
    err                = 1'b0;
    protocol_error_set = 1'b0;

    device_reset_ctrl_next       = wdata[7:0];
    device_reset_ctrl_we         = 1'b0;
    device_reset_forced_next     = wdata[15:8];
    device_reset_forced_we       = 1'b0;
    device_reset_iface_next      = wdata[23:16];
    device_reset_iface_we        = 1'b0;
    recovery_ctrl_cms_next       = wdata[7:0];
    recovery_ctrl_cms_we         = 1'b0;
    recovery_ctrl_img_sel_next   = wdata[15:8];
    recovery_ctrl_img_sel_we     = 1'b0;
    recovery_ctrl_activate_next  = wdata[23:16];
    recovery_ctrl_activate_we    = 1'b0;
    vendor_next                  = wdata[7:0];
    vendor_we                    = 1'b0;

    device_reset_wr              = 1'b0;
    device_reset_ctrl            = wdata[7:0];
    device_reset_forced          = wdata[15:8];
    device_reset_iface           = wdata[23:16];
    recovery_ctrl_wr_cms         = 1'b0;
    recovery_ctrl_wr_img_sel     = 1'b0;
    recovery_ctrl_wr_activate    = 1'b0;
    recovery_ctrl_cms            = wdata[7:0];
    recovery_ctrl_img_sel        = wdata[15:8];
    recovery_ctrl_activate       = wdata[23:16];

    unique case (cmd)
      OCP_CMD_PROT_CAP: begin
        cmd_len     = OCP_LEN_PROT_CAP;
        host_ro_cmd = 1'b1;
        unique case (word_offset)
          16'd0: rdata = prot_cap_0;
          16'd1: rdata = prot_cap_1;
          16'd2: rdata = prot_cap_2;
          16'd3: rdata = prot_cap_3;
          default: err = rd;
        endcase
      end
      OCP_CMD_DEVICE_ID: begin
        cmd_len     = OCP_LEN_DEVICE_ID;
        host_ro_cmd = 1'b1;
        if (word_offset < 16'd6) begin
          rdata = device_id[word_offset[2:0]*32 +: 32];
        end else begin
          err = rd;
        end
      end
      OCP_CMD_DEVICE_STATUS: begin
        cmd_len     = OCP_LEN_DEVICE_STATUS;
        host_ro_cmd = 1'b1;
        if (word_offset == 16'd0) begin
          rdata = {recovery_reason, protocol_error, device_status};
        end else if (word_offset < 16'd16) begin
          rdata = '0;
        end else begin
          err = rd;
        end
      end
      OCP_CMD_DEVICE_RESET: begin
        cmd_len = OCP_LEN_DEVICE_RESET;
        rdata   = {8'h00, device_reset_iface_value,
                   device_reset_forced_value, device_reset_ctrl_value};
        if (wr) begin
          device_reset_ctrl_we   = wstrb[0];
          device_reset_forced_we = wstrb[1];
          device_reset_iface_we  = wstrb[2];
          device_reset_wr        = |wstrb[2:0];
        end
      end
      OCP_CMD_RECOVERY_CTRL: begin
        cmd_len = OCP_LEN_RECOVERY_CTRL;
        rdata   = {8'h00, recovery_ctrl_activate_value,
                   recovery_ctrl_img_sel_value, recovery_ctrl_cms_value};
        if (wr) begin
          recovery_ctrl_cms_we       = wstrb[0];
          recovery_ctrl_img_sel_we   = wstrb[1];
          recovery_ctrl_activate_we  = wstrb[2];
          recovery_ctrl_wr_cms       = wstrb[0];
          recovery_ctrl_wr_img_sel   = wstrb[1];
          recovery_ctrl_wr_activate  = wstrb[2];
        end
      end
      OCP_CMD_RECOVERY_STATUS: begin
        cmd_len     = OCP_LEN_RECOVERY_STATUS;
        host_ro_cmd = 1'b1;
        rdata       = {16'h0, recovery_vendor_status, recovery_status};
      end
      OCP_CMD_HW_STATUS: begin
        cmd_len     = OCP_LEN_HW_STATUS;
        host_ro_cmd = 1'b1;
        rdata       = {hw_vendor_status_len, hw_ctemp,
                       hw_vendor_status, hw_status};
      end
      OCP_CMD_INDIRECT_FIFO_CTRL: begin
        cmd_len = OCP_LEN_INDIRECT_FIFO_CTRL;
        if (rd) begin
          unique case (word_offset)
            16'd0: rdata = {16'h0, {7'h0, fifo_ctrl_reset}, fifo_ctrl_cms};
            16'd1: rdata = fifo_ctrl_image_size;
            default: err = 1'b1;
          endcase
        end
      end
      OCP_CMD_INDIRECT_FIFO_STATUS: begin
        cmd_len = OCP_LEN_INDIRECT_FIFO_STATUS;
        if (wr) begin
          protocol_error_set = 1'b1;
        end
      end
      OCP_CMD_VENDOR: begin
        cmd_len = OCP_LEN_VENDOR;
        rdata   = {24'h0, vendor_value};
        if (wr) begin
          vendor_we = wstrb[0];
        end
      end
      default: begin
        supported_cmd      = 1'b0;
        protocol_error_set = access;
      end
    endcase

    if (wr && host_ro_cmd) begin
      protocol_error_set = 1'b1;
    end
    if (access && !supported_cmd) begin
      err = 1'b0;
    end
    if (access && !is_fifo_cmd && supported_cmd && (byte_offset >= cmd_len)) begin
      err = 1'b1;
    end
  end

endmodule : usb_ocp_recovery_hwif_adapter
