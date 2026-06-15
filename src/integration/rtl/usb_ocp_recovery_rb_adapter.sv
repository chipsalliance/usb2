// SPDX-License-Identifier: Apache-2.0
// ============================================================================
// usb_ocp_recovery_rb_adapter.sv
//
// Byte-granular OCP Recovery v1.1 reg-bus adapter.  Bridges the byte-wide
// rb_* protocol (cmd[7:0] + offset[15:0]) used by A2 (ctrl_decode) / the
// AHB sub-decoder to the DWORD-aligned, passthrough CPU interface emitted
// by the peakrdl-generated usb_ocp_recovery regblock (see
// third_party/usb2/src/integration/rtl/generated/usb_ocp_recovery_reg.sv).
//
// Address layout (OCP cmd -> byte offset in the regblock window) is the
// single source of truth in third_party/usb2/systemrdl/usb_ocp_recovery_reg.rdl
// and is reproduced here as a small LUT.  No other field-layout constant
// is duplicated; per-byte field placement is handled by the regblock
// itself.
//
// FIFO branch:  Commands 0x2A/0x2B/0x2C/0x2D/0x2E (INDIRECT_STATUS,
// INDIRECT_DATA, INDIRECT_FIFO_*) are routed to A4 (usb_ocp_recovery_cms_fifo)
// instead of the regblock.  This adapter is responsible for the steering
// and pass-through ack/err/rdata.
//
// Sideband strobes:
//   DEVICE_RESET (0x25) and RECOVERY_CTRL (0x26) are written to / read from
//   the adapter's own latches rather than the regblock.  Rationale:
//     - RDL line 507 declares ACTIVATE_REC_IMG onwrite=woclr, and RDL
//       line 460 reset for RESET_CTRL is 0.  Both fields use the FSM's
//       consume-clear pattern (latch byte on SW write; HW clears on
//       FSM acknowledge), which is not equivalent to RDL onwrite=woclr
//       (which would clear bits the host wrote 1 to).  Owning the
//       storage in the adapter preserves the FSM contract documented
//       in usb_ocp_recovery_regs.sv (lines 71-75, 454-463, 486-493).
//     - This makes the adapter the writable hand-off boundary for the
//       OCP "write payload then activate" handshake.
//   HW_STATUS (0x28) writes are sideband-only (pulse + wdata to FSM);
//   no cpuif write is issued because the regblock HW_STATUS fields are
//   hw=w with we=false (host writes would be ignored).  This matches
//   the legacy usb_ocp_recovery_regs.sv behavior (lines 495-498).
//   PROTOCOL_ERROR rclr (OCP v1.1 Sec 9.2 Tbl 9-5) pulses on the ack
//   cycle of a host read of DEVICE_STATUS byte 1, matching the legacy
//   module's behavior (lines 429-435).
//
// Latency: matches the legacy module:
//   - Local cmd ack: 1 cycle after rb_wr/rb_rd (registered).
//   - FIFO cmd ack/err/rdata: combinational pass-through from A4
//     (which itself ack's same-cycle).
//
// Reset: synchronous, active-high (SV integration convention).
// ============================================================================

module usb_ocp_recovery_rb_adapter (
  input  logic        clk,
  input  logic        rst,

  // --------------------------------------------------------------------------
  // Byte-wide reg-bus (producer: A2 ctrl_decode or AHB sub-decoder).
  // --------------------------------------------------------------------------
  input  logic [7:0]  rb_cmd,
  input  logic [15:0] rb_offset,
  input  logic        rb_wr,
  input  logic        rb_rd,
  input  logic [7:0]  rb_wdata,
  input  logic        rb_be,
  output logic [7:0]  rb_rdata,
  output logic        rb_ack,
  output logic        rb_err,

  // --------------------------------------------------------------------------
  // FIFO branch to A4 (cms_fifo).  Unchanged from the legacy interface.
  // --------------------------------------------------------------------------
  output logic        fifo_rb_sel,
  output logic [7:0]  fifo_rb_cmd,
  output logic [15:0] fifo_rb_offset,
  output logic        fifo_rb_wr,
  output logic        fifo_rb_rd,
  output logic [7:0]  fifo_rb_wdata,
  input  logic [7:0]  fifo_rb_rdata,
  input  logic        fifo_rb_ack,
  input  logic        fifo_rb_err,

  // --------------------------------------------------------------------------
  // peakrdl-regblock passthrough CPU interface.  Same-cycle (0-cycle)
  // ack/err for both reads and writes per the regblock's "balanced
  // latency" passthrough.
  // --------------------------------------------------------------------------
  output logic        cpuif_req,
  output logic        cpuif_req_is_wr,
  output logic [11:0] cpuif_addr,
  output logic [31:0] cpuif_wr_data,
  output logic [31:0] cpuif_wr_biten,
  input  logic        cpuif_rd_ack,
  input  logic        cpuif_rd_err,
  input  logic [31:0] cpuif_rd_data,
  input  logic        cpuif_wr_ack,
  input  logic        cpuif_wr_err,

  // --------------------------------------------------------------------------
  // Sideband to/from A5 FSM.  Semantics match usb_ocp_recovery_regs.sv.
  // --------------------------------------------------------------------------
  output logic        device_reset_wr,
  output logic [7:0]  device_reset_ctrl,
  output logic [7:0]  device_reset_forced,
  output logic [7:0]  device_reset_iface,

  output logic        recovery_ctrl_wr,
  output logic        recovery_ctrl_wr_cms,
  output logic        recovery_ctrl_wr_img_sel,
  output logic [7:0]  recovery_ctrl_cms,
  output logic [7:0]  recovery_ctrl_img_sel,
  output logic [7:0]  recovery_ctrl_activate,
  input  logic        recovery_ctrl_activate_consume,

  output logic        hw_status_wr,
  output logic [7:0]  hw_status_wdata,
  output logic        proto_err_rd_pulse
);

  // --------------------------------------------------------------------------
  // OCP command code -> byte-offset base in the regblock window.
  // Source of truth: third_party/usb2/systemrdl/usb_ocp_recovery_reg.rdl
  //   PROT_CAP_0       @ 0x000  (cmd 0x22, 16 B)
  //   DEVICE_ID_0      @ 0x010  (cmd 0x23, 24 B)
  //   DEVICE_STATUS_0  @ 0x028  (cmd 0x24, 64 B)
  //   DEVICE_RESET     @ 0x068  (cmd 0x25,  3 B, adapter-owned)
  //   RECOVERY_CTRL    @ 0x06C  (cmd 0x26,  3 B, adapter-owned)
  //   RECOVERY_STATUS  @ 0x070  (cmd 0x27,  2 B)
  //   HW_STATUS        @ 0x074  (cmd 0x28,  4 B, write is sideband-only)
  //   INDIRECT_CTRL_0  @ 0x078  (cmd 0x29,  6 B)
  //   INDIRECT_STATUS  @ 0x080  (cmd 0x2A, FIFO-routed)
  //   INDIRECT_DATA    @ 0x088  (cmd 0x2B, FIFO-routed)
  //   INDIRECT_FIFO_*  @ 0x184  (cmds 0x2C..0x2E, FIFO-routed)
  //   VENDOR           @ 0x1A4  (cmd 0x2F,  1 B stub)
  // --------------------------------------------------------------------------
  localparam logic [7:0] CMD_PROT_CAP             = 8'h22;
  localparam logic [7:0] CMD_DEVICE_ID            = 8'h23;
  localparam logic [7:0] CMD_DEVICE_STATUS        = 8'h24;
  localparam logic [7:0] CMD_DEVICE_RESET         = 8'h25;
  localparam logic [7:0] CMD_RECOVERY_CTRL        = 8'h26;
  localparam logic [7:0] CMD_RECOVERY_STATUS      = 8'h27;
  localparam logic [7:0] CMD_HW_STATUS            = 8'h28;
  localparam logic [7:0] CMD_INDIRECT_CTRL        = 8'h29;
  localparam logic [7:0] CMD_INDIRECT_STATUS      = 8'h2A;
  localparam logic [7:0] CMD_INDIRECT_DATA        = 8'h2B;
  localparam logic [7:0] CMD_INDIRECT_FIFO_CTRL   = 8'h2C;
  localparam logic [7:0] CMD_INDIRECT_FIFO_STATUS = 8'h2D;
  localparam logic [7:0] CMD_INDIRECT_FIFO_DATA   = 8'h2E;
  localparam logic [7:0] CMD_VENDOR               = 8'h2F;

  // Byte offsets within DEVICE_RESET / RECOVERY_CTRL / DEVICE_STATUS used
  // for sideband decoding (OCP Recovery v1.1 Sec 9.2 Tbls 9-5, 9-7, 9-9).
  localparam logic [1:0] OFF_DR_RESET_CONTROL = 2'd0;
  localparam logic [1:0] OFF_RC_CMS           = 2'd0;
  localparam logic [1:0] OFF_RC_IMG_SEL       = 2'd1;
  localparam logic [1:0] OFF_RC_ACTIVATE      = 2'd2;
  localparam logic [5:0] OFF_DS_PROT_ERROR    = 6'd1;

  // --------------------------------------------------------------------------
  // FIFO-routing decode
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

  // --------------------------------------------------------------------------
  // Local command base address + payload length
  // --------------------------------------------------------------------------
  logic        is_local_cmd;
  logic [11:0] cmd_base;
  logic [15:0] cmd_len;
  always_comb begin
    is_local_cmd = 1'b1;
    cmd_base     = 12'h000;
    cmd_len      = 16'd0;
    unique case (rb_cmd)
      CMD_PROT_CAP:        begin cmd_base = 12'h000; cmd_len = 16'd16; end
      CMD_DEVICE_ID:       begin cmd_base = 12'h010; cmd_len = 16'd24; end
      CMD_DEVICE_STATUS:   begin cmd_base = 12'h028; cmd_len = 16'd64; end
      CMD_DEVICE_RESET:    begin cmd_base = 12'h068; cmd_len = 16'd3;  end
      CMD_RECOVERY_CTRL:   begin cmd_base = 12'h06C; cmd_len = 16'd3;  end
      CMD_RECOVERY_STATUS: begin cmd_base = 12'h070; cmd_len = 16'd2;  end
      CMD_HW_STATUS:       begin cmd_base = 12'h074; cmd_len = 16'd4;  end
      CMD_INDIRECT_CTRL:   begin cmd_base = 12'h078; cmd_len = 16'd6;  end
      CMD_VENDOR:          begin cmd_base = 12'h1A4; cmd_len = 16'd1;  end
      default:             is_local_cmd = 1'b0;
    endcase
  end

  logic access;
  logic off_ok;
  logic local_access;
  logic local_write_ok;
  logic local_read_ok;
  assign access         = rb_wr | rb_rd;
  assign off_ok         = (rb_offset < cmd_len);
  assign local_access   = access  & is_local_cmd & ~is_fifo_cmd;
  assign local_write_ok = rb_wr   & is_local_cmd & ~is_fifo_cmd & off_ok & rb_be;
  assign local_read_ok  = rb_rd   & is_local_cmd & ~is_fifo_cmd & off_ok;

  // --------------------------------------------------------------------------
  // FIFO branch pass-through (unchanged from legacy regs.sv:222-227).
  // --------------------------------------------------------------------------
  assign fifo_rb_sel    = is_fifo_cmd;
  assign fifo_rb_cmd    = rb_cmd;
  assign fifo_rb_offset = rb_offset;
  assign fifo_rb_wr     = rb_wr & is_fifo_cmd;
  assign fifo_rb_rd     = rb_rd & is_fifo_cmd;
  assign fifo_rb_wdata  = rb_wdata;

  // --------------------------------------------------------------------------
  // Adapter-owned DEVICE_RESET / RECOVERY_CTRL latches and pulses.
  //
  // These mirror usb_ocp_recovery_regs.sv (lines 146-153, 440-498) so the
  // FSM sees bit-identical sideband timing.
  // --------------------------------------------------------------------------
  logic [7:0] device_reset_ctrl_q;
  logic [7:0] device_reset_forced_q;
  logic [7:0] device_reset_iface_q;
  logic       device_reset_wr_q;

  logic [7:0] recovery_ctrl_cms_q;
  logic [7:0] recovery_ctrl_img_sel_q;
  logic [7:0] recovery_ctrl_activate_q;
  logic       recovery_ctrl_wr_q;
  logic       recovery_ctrl_wr_cms_q;
  logic       recovery_ctrl_wr_img_sel_q;

  logic       hw_status_wr_q;
  logic [7:0] hw_status_wdata_q;
  logic       proto_err_rd_pulse_q;

  logic       wr_device_reset;
  logic       wr_recovery_ctrl;
  logic       wr_hw_status;
  assign wr_device_reset  = local_write_ok & (rb_cmd == CMD_DEVICE_RESET);
  assign wr_recovery_ctrl = local_write_ok & (rb_cmd == CMD_RECOVERY_CTRL);
  assign wr_hw_status     = local_write_ok & (rb_cmd == CMD_HW_STATUS);

  // --------------------------------------------------------------------------
  // Adapter-owned read mux for DEVICE_RESET / RECOVERY_CTRL.  DEVICE_RESET
  // reads return 0 (WO per OCP Recovery v1.1 Sec 9.2 Tbl 9-7); RECOVERY_CTRL
  // returns the latched bytes.
  // --------------------------------------------------------------------------
  logic [7:0] adapter_rdata_c;
  always_comb begin
    adapter_rdata_c = 8'h00;
    if (rb_cmd == CMD_RECOVERY_CTRL) begin
      unique case (rb_offset[1:0])
        (OFF_RC_CMS):      adapter_rdata_c = recovery_ctrl_cms_q;
        (OFF_RC_IMG_SEL):  adapter_rdata_c = recovery_ctrl_img_sel_q;
        (OFF_RC_ACTIVATE): adapter_rdata_c = recovery_ctrl_activate_q;
        default:             adapter_rdata_c = 8'h00;
      endcase
    end
  end

  // --------------------------------------------------------------------------
  // Does this access go to the regblock cpuif?  The adapter handles
  // DEVICE_RESET / RECOVERY_CTRL itself, and HW_STATUS / VENDOR writes are
  // dropped (HW_STATUS: regblock fields are hw=w/we=false; VENDOR: legacy
  // "writes dropped, reads zero" stub matched here).
  // --------------------------------------------------------------------------
  logic adapter_owned_cmd;
  logic cpuif_req_c;
  logic [11:0] cpuif_addr_c;

  assign adapter_owned_cmd = (rb_cmd == CMD_DEVICE_RESET)
                           | (rb_cmd == CMD_RECOVERY_CTRL);

  always_comb begin
    cpuif_req_c = 1'b0;
    if (local_access & ~adapter_owned_cmd) begin
      if (rb_wr) begin
        // Drop HW_STATUS and VENDOR writes (sideband-only / stub).
        if ((rb_cmd != CMD_HW_STATUS) && (rb_cmd != CMD_VENDOR) && local_write_ok) begin
          cpuif_req_c = 1'b1;
        end
      end else if (local_read_ok) begin
        cpuif_req_c = 1'b1;
      end
    end
  end

  // cpuif_addr is the DWORD-aligned byte address into the regblock.
  // Low 2 bits of the byte address select the byte lane on the 32-bit bus.
  logic [11:0] byte_addr_c;
  assign byte_addr_c    = cmd_base + rb_offset[11:0];
  assign cpuif_addr_c   = {byte_addr_c[11:2], 2'b00};
  assign cpuif_req      = cpuif_req_c;
  assign cpuif_req_is_wr= rb_wr;
  assign cpuif_addr     = cpuif_addr_c;
  // Replicate rb_wdata across all 4 byte lanes; biten gates the active lane.
  assign cpuif_wr_data  = {4{rb_wdata}};
  always_comb begin
    cpuif_wr_biten = 32'h0000_0000;
    unique case (rb_offset[1:0])
      2'd0: cpuif_wr_biten = 32'h0000_00FF;
      2'd1: cpuif_wr_biten = 32'h0000_FF00;
      2'd2: cpuif_wr_biten = 32'h00FF_0000;
      2'd3: cpuif_wr_biten = 32'hFF00_0000;
      default: cpuif_wr_biten = 32'h0000_0000;
    endcase
  end

  // Combinational byte-lane select on the regblock read response.
  logic [7:0] cpuif_rdata_byte_c;
  always_comb begin
    unique case (rb_offset[1:0])
      2'd0:    cpuif_rdata_byte_c = cpuif_rd_data[7:0];
      2'd1:    cpuif_rdata_byte_c = cpuif_rd_data[15:8];
      2'd2:    cpuif_rdata_byte_c = cpuif_rd_data[23:16];
      2'd3:    cpuif_rdata_byte_c = cpuif_rd_data[31:24];
      default: cpuif_rdata_byte_c = 8'h00;
    endcase
  end

  // --------------------------------------------------------------------------
  // Sequential: handshake registers + adapter-owned storage.
  // --------------------------------------------------------------------------
  logic       rb_ack_q;
  logic       rb_err_q;
  logic [7:0] rb_rdata_q;

  always_ff @(posedge clk) begin
    if (rst) begin
      rb_ack_q                   <= 1'b0;
      rb_err_q                   <= 1'b0;
      rb_rdata_q                 <= '0;

      device_reset_ctrl_q        <= 8'h00;
      device_reset_forced_q      <= 8'h00;
      device_reset_iface_q       <= 8'h00;
      device_reset_wr_q          <= 1'b0;

      recovery_ctrl_cms_q        <= 8'h00;
      recovery_ctrl_img_sel_q    <= 8'h00;
      recovery_ctrl_activate_q   <= 8'h00;
      recovery_ctrl_wr_q         <= 1'b0;
      recovery_ctrl_wr_cms_q     <= 1'b0;
      recovery_ctrl_wr_img_sel_q <= 1'b0;

      hw_status_wr_q             <= 1'b0;
      hw_status_wdata_q          <= 8'h00;
      proto_err_rd_pulse_q       <= 1'b0;
    end else begin
      // Defaults: handshake low, pulses low.
      rb_ack_q                   <= 1'b0;
      rb_err_q                   <= 1'b0;
      rb_rdata_q                 <= '0;
      device_reset_wr_q          <= 1'b0;
      recovery_ctrl_wr_q         <= 1'b0;
      recovery_ctrl_wr_cms_q     <= 1'b0;
      recovery_ctrl_wr_img_sel_q <= 1'b0;
      hw_status_wr_q             <= 1'b0;
      proto_err_rd_pulse_q       <= 1'b0;

      // ----- Local cmd handshake (1-cycle late) -----
      if (access & ~is_fifo_cmd) begin
        if (~is_local_cmd) begin
          // Always ack alongside err so the upstream ext_rb/AHB bridge does
          // not deadlock on invalid OCP command codes (USB 2.0 control
          // transfer cleanup or stray SoC DMA reads must not hang the bus).
          rb_ack_q   <= 1'b1;
          rb_err_q   <= 1'b1;
        end else if (~off_ok) begin
          rb_ack_q   <= 1'b1;
          rb_err_q   <= 1'b1;
        end else if (rb_wr & ~rb_be) begin
          // Honored by writes only when rb_be is set (legacy behavior); a
          // bare wr with no be lands here as a silent no-op ack to keep
          // the producer's handshake balanced.
          rb_ack_q   <= 1'b1;
        end else begin
          rb_ack_q   <= 1'b1;
          if (rb_rd) begin
            if (adapter_owned_cmd) begin
              rb_rdata_q <= adapter_rdata_c;
            end else begin
              rb_rdata_q <= cpuif_rdata_byte_c;
            end
            // OCP Recovery v1.1 Sec 9.2 Tbl 9-5 / i3c-rdl line 274:
            // PROTOCOL_ERROR onread=rclr.  Pulse on the ack cycle of a
            // successful read of DEVICE_STATUS byte 1.  Matches legacy
            // usb_ocp_recovery_regs.sv lines 429-435.
            if ((rb_cmd == CMD_DEVICE_STATUS) &&
                (rb_offset[5:0] == OFF_DS_PROT_ERROR)) begin
              proto_err_rd_pulse_q <= 1'b1;
            end
          end
        end
      end

      // ----- DEVICE_RESET writable bytes + pulse -----
      // OCP Recovery v1.1 Sec 9.2 Tbl 9-7: 3-byte payload (control,
      // forced_recovery, iface_control).  Pulse on byte-0 (control) write,
      // matching legacy usb_ocp_recovery_regs.sv lines 440-452.
      if (wr_device_reset) begin
        unique case (rb_offset[1:0])
          2'd0: device_reset_ctrl_q   <= rb_wdata;
          2'd1: device_reset_forced_q <= rb_wdata;
          2'd2: device_reset_iface_q  <= rb_wdata;
          default: ;
        endcase
        if (rb_offset[1:0] == (OFF_DR_RESET_CONTROL)) begin
          device_reset_wr_q <= 1'b1;
        end
      end

      // RESET_CONTROL woclr: clear the latched byte one cycle after the
      // FSM samples the pulse (legacy regs.sv lines 454-463; OCP Recovery
      // v1.1 Sec 9.2 Tbl 9-7 / i3c-rdl line 367 onwrite=woclr).  Guarded
      // against a concurrent host re-write so the new value is not lost.
      if (device_reset_wr_q && !wr_device_reset) begin
        device_reset_ctrl_q <= 8'h00;
      end

      // ----- RECOVERY_CTRL per-byte latch + strobes -----
      // OCP Recovery v1.1 Sec 9.2 Tbl 9-9: per-byte strobes so the FSM
      // never misses a CMS / IMG_SEL update (legacy regs.sv lines 465-484).
      if (wr_recovery_ctrl) begin
        unique case (rb_offset[1:0])
          (OFF_RC_CMS): begin
            recovery_ctrl_cms_q    <= rb_wdata;
            recovery_ctrl_wr_cms_q <= 1'b1;
          end
          (OFF_RC_IMG_SEL): begin
            recovery_ctrl_img_sel_q    <= rb_wdata;
            recovery_ctrl_wr_img_sel_q <= 1'b1;
          end
          (OFF_RC_ACTIVATE): begin
            recovery_ctrl_activate_q <= rb_wdata;
            recovery_ctrl_wr_q       <= 1'b1;
          end
          default: ;
        endcase
      end

      // ACTIVATE woclr feedback: when FSM consumes the latched ACTIVATE
      // byte, clear it so subsequent host reads return 0 (legacy regs.sv
      // lines 486-493; OCP Recovery v1.1 Sec 9.2 Tbl 9-9 / i3c-rdl line
      // 434 onwrite=woclr).
      if (recovery_ctrl_activate_consume) begin
        recovery_ctrl_activate_q <= 8'h00;
      end

      // ----- HW_STATUS sideband pulse (no cpuif write; regblock fields
      //       are hw=w / we=false). -----
      if (wr_hw_status) begin
        hw_status_wr_q    <= 1'b1;
        hw_status_wdata_q <= rb_wdata;
      end
    end
  end

  // --------------------------------------------------------------------------
  // Output mux: local registered path vs FIFO combinational pass-through.
  // Mutually exclusive by is_fifo_cmd / adapter_owned_cmd.
  // --------------------------------------------------------------------------
  assign rb_ack   = rb_ack_q | fifo_rb_ack;
  assign rb_err   = rb_err_q | fifo_rb_err;
  assign rb_rdata = fifo_rb_ack ? fifo_rb_rdata : rb_rdata_q;

  assign device_reset_wr        = device_reset_wr_q;
  assign device_reset_ctrl      = device_reset_ctrl_q;
  assign device_reset_forced    = device_reset_forced_q;
  assign device_reset_iface     = device_reset_iface_q;

  assign recovery_ctrl_wr         = recovery_ctrl_wr_q;
  assign recovery_ctrl_wr_cms     = recovery_ctrl_wr_cms_q;
  assign recovery_ctrl_wr_img_sel = recovery_ctrl_wr_img_sel_q;
  assign recovery_ctrl_cms        = recovery_ctrl_cms_q;
  assign recovery_ctrl_img_sel    = recovery_ctrl_img_sel_q;
  assign recovery_ctrl_activate   = recovery_ctrl_activate_q;

  assign hw_status_wr           = hw_status_wr_q;
  assign hw_status_wdata        = hw_status_wdata_q;
  assign proto_err_rd_pulse     = proto_err_rd_pulse_q;

  // --------------------------------------------------------------------------
  // Assertions
  // --------------------------------------------------------------------------
`ifndef SYNTHESIS
  // synopsys translate_off
  always_ff @(posedge clk) begin
    if (!rst) begin
      assert (!(rb_wr && rb_rd))
        else $error("usb_ocp_recovery_rb_adapter: rb_wr and rb_rd both asserted");
      assert (!(rb_ack_q && fifo_rb_ack))
        else $error("usb_ocp_recovery_rb_adapter: local and fifo ack collision");
      if (rb_wr | rb_rd) begin
        assert (!$isunknown({rb_cmd, rb_offset}))
          else $error("usb_ocp_recovery_rb_adapter: X on rb_cmd/rb_offset during access");
      end
    end
  end
  // synopsys translate_on
`endif

endmodule
