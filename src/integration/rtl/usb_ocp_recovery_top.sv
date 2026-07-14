// SPDX-License-Identifier: Apache-2.0
//------------------------------------------------------------------------------
// usb_ocp_recovery_top.sv
//
// OCP Recovery v1.1 USB transport integration wrapper.  This module accepts
// the pre-filtered EP0 recovery stream from usb_pie_recovery_arb, decodes the
// class request, arbitrates USB-vs-external register access, and connects the
// regblock, CMS FIFO backing store, and recovery FSM.
//
// Instantiates:
//   A2 : usb_ocp_recovery_ctrl_decode (SV)
//   A3 : usb_ocp_recovery_rb_adapter + peakrdl-generated usb_ocp_recovery
//        (regblock from third_party/usb2/systemrdl/usb_ocp_recovery_reg.rdl)
//   A4 : usb_ocp_recovery_cms_fifo    (SV)
//   A5 : usb_ocp_recovery_fsm         (SV)
//
// Clock / Reset:
//   Single clock `clk`, synchronous active-high `rst` (SV convention).
//------------------------------------------------------------------------------

module usb_ocp_recovery_top #(
  parameter int           CMS_ADDR_W     = 16,
  parameter int           NUM_CMS        = 2,
  parameter int           FIFO_DEPTH_DWORDS = 32
)(
  input  logic                    clk,
  input  logic                    rst,

  //----------------------------------------------------------------------------
  // Async FIFO READ port.  Plumbed straight through to the A4
  // cms_fifo so the dev_axi_aclk-domain wrapper can pop INDIRECT_FIFO_DATA
  // reads natively, bypassing the utmi-clk CDC bridge.  clk_rd is
  // dev_axi_aclk; rst_rd_n is dev_axi_aresetn (active-low).
  //----------------------------------------------------------------------------
  input  logic                    clk_rd,
  input  logic                    rst_rd_n,
  output logic                    fifo_rd_valid,
  input  logic                    fifo_rd_ready,
  output logic [31:0]             fifo_rd_data,
  output logic [$clog2(FIFO_DEPTH_DWORDS+1)-1:0] fifo_rd_depth,

  //----------------------------------------------------------------------------
  // Upper-side 32-bit control-transfer surface driven by VHDL
  // usb_pie_recovery_arb.
  //----------------------------------------------------------------------------
  input  logic                    rec_setup_pkt_vld,
  input  logic [63:0]             rec_setup_pkt,

  input  logic [31:0]             rec_ctrl_out_data,
  input  logic [3:0]              rec_ctrl_out_be,
  input  logic                    rec_ctrl_out_vld,
  input  logic                    rec_ctrl_out_last,
  output logic                    rec_ctrl_out_rdy,

  output logic [31:0]             rec_ctrl_in_data,
  output logic [3:0]              rec_ctrl_in_be,
  output logic                    rec_ctrl_in_vld,
  output logic                    rec_ctrl_in_last,
  input  logic                    rec_ctrl_in_rdy,

  output logic                    rec_ctrl_set_stall,
  input  logic                    rec_ctrl_xfer_done,

  // Emergency-fallback path-disable control: mirrors CALIPTRA_CTRL.OCP_PATH_DISABLE
  // (regblock field, EXT/firmware write-only via rb_is_ext/swwe gating -- see
  // rb_hwif_in assignment below) out to the VHDL arbiter (usb_pie_recovery_arb
  // ocp_path_disable_i), which forces legacy SIE pass-through when set. Both
  // this module and the arbiter live in utmi_clk, so no synchronizer is
  // needed for this same-domain registered signal.
  output logic                    rec_ocp_path_disable,

  //----------------------------------------------------------------------------
  // External register-bus slave (driven by AHB sub-decoder upstream).
  // Word-wide (32-bit) management path: the SoC AXI master issues word-
  // aligned accesses, so a full 32-bit data word maps directly onto the
  // word-native A2->A3 reg-bus.  ext_rb_offset remains a BYTE offset for
  // compatibility with the wrapper's byte-address capture.
  //----------------------------------------------------------------------------
  input  logic [7:0]              ext_rb_cmd,
  input  logic [15:0]             ext_rb_offset,
  input  logic                    ext_rb_wr,
  input  logic                    ext_rb_rd,
  input  logic [31:0]             ext_rb_wdata,
  output logic [31:0]             ext_rb_rdata,
  output logic                    ext_rb_ack,
  output logic                    ext_rb_err,

  //----------------------------------------------------------------------------
  // Static capability inputs (tied by SoC integrator).
  //----------------------------------------------------------------------------
  input  logic [191:0]            device_id_in,

  //----------------------------------------------------------------------------
  // SoC trigger / ack and recovery sideband.
  //
  // CDC guardrail: this module (usb_ocp_recovery_top) lives entirely in
  // utmi_clk. All of the sidebands below cross into the SoC-clock domain at
  // the top-level integration point (caliptra_ss_top or equivalent) OUTSIDE
  // this module -- verify at integration time that any NEWLY wired consumer
  // of these signals is either synchronized (e.g. caliptra_prim_flop_2sync
  // for level signals) or handshake-based (for pulses), not sampled
  // combinationally/directly in a different clock domain. Do not add a new
  // sideband here without documenting its consumer's clock domain and
  // synchronization method.
  //----------------------------------------------------------------------------
  input  logic                    rec_trigger,
  input  logic                    soc_boot_ack,
  output logic                    recovery_active,
  output logic                    image_ready,
  output logic                    boot_req,
  output logic                    device_reset_req,
  output logic                    fatal_err
);

  import usb_ocp_recovery_pkg::*;

  //////////////////////////////////////////////////////////////////////////////
  // Internal wiring
  //////////////////////////////////////////////////////////////////////////////

  // --- A2 (USB master) reg-bus (word-wide; offset is a WORD index) ---
  logic [7:0]                 usb_rb_cmd;
  logic [15:0]                usb_rb_offset;
  logic                       usb_rb_wr;
  logic                       usb_rb_rd;
  logic [31:0]                usb_rb_wdata;
  logic [3:0]                 usb_rb_wstrb;
  logic [31:0]                usb_rb_rdata;
  logic                       usb_rb_ack;
  logic                       usb_rb_err;
  logic                       usb_is_fifo_cmd;
  logic [31:0]                usb_hw_rdata;
  logic                       usb_hw_ack;
  logic                       usb_hw_err;
  logic                       usb_protocol_error_set;

  logic [7:0]                 usb_device_reset_ctrl_next;
  logic                       usb_device_reset_ctrl_we;
  logic [7:0]                 usb_device_reset_forced_next;
  logic                       usb_device_reset_forced_we;
  logic [7:0]                 usb_device_reset_iface_next;
  logic                       usb_device_reset_iface_we;
  logic [7:0]                 usb_recovery_ctrl_cms_next;
  logic                       usb_recovery_ctrl_cms_we;
  logic [7:0]                 usb_recovery_ctrl_img_sel_next;
  logic                       usb_recovery_ctrl_img_sel_we;
  logic [7:0]                 usb_recovery_ctrl_activate_next;
  logic                       usb_recovery_ctrl_activate_we;
  logic [7:0]                 usb_vendor_next;
  logic                       usb_vendor_we;

  // --- Arbitrated reg-bus into A3 (word-wide) ---
  logic [7:0]                 rb_cmd;
  logic [15:0]                rb_offset;
  logic                       rb_wr;
  logic                       rb_rd;
  logic [31:0]                rb_wdata;
  logic [3:0]                 rb_wstrb;
  logic [31:0]                rb_rdata;
  logic                       rb_ack;
  logic                       rb_err;

  // --- A3 <-> A4 FIFO-routed reg-bus (32-bit word + byte strobe) ---
  logic                       fifo_rb_sel;
  logic [7:0]                 fifo_rb_cmd;
  logic [15:0]                fifo_rb_offset;
  logic                       fifo_rb_wr;
  logic                       fifo_rb_rd;
  logic [31:0]                fifo_rb_wdata;
  logic [3:0]                 fifo_rb_wstrb;
  logic [31:0]                fifo_rb_rdata;
  logic                       fifo_rb_ack;
  logic                       fifo_rb_err;

  // EXT/Firmware producer side of the cms_fifo command port. The cms_fifo
  // inputs above are a USB-priority mux of this side and the direct USB FIFO
  // command side below.
  logic                       ext_fifo_rb_sel;
  logic [7:0]                 ext_fifo_rb_cmd;
  logic [15:0]                ext_fifo_rb_offset;
  logic                       ext_fifo_rb_wr;
  logic                       ext_fifo_rb_rd;
  logic [31:0]                ext_fifo_rb_wdata;
  logic [3:0]                 ext_fifo_rb_wstrb;
  logic [31:0]                ext_fifo_rb_rdata;
  logic                       ext_fifo_rb_ack;
  logic                       ext_fifo_rb_err;
  logic                       usb_fifo_req;
  logic                       usb_fifo_packet_active_q;
  logic                       ext_fifo_config_blocked;
  logic                       ext_fifo_data_write_reject;

  // --- A3 <-> A5 sideband ---
  logic                       device_reset_wr;
  logic [7:0]                 device_reset_ctrl;
  logic [7:0]                 device_reset_forced;
  logic [7:0]                 device_reset_iface;
  logic                       recovery_ctrl_wr;
  logic                       recovery_ctrl_wr_cms;
  logic                       recovery_ctrl_wr_img_sel;
  logic                       recovery_ctrl_wr_activate;
  logic [7:0]                 recovery_ctrl_cms;
  logic [7:0]                 recovery_ctrl_img_sel;
  logic [7:0]                 recovery_ctrl_activate;
  logic                       firmware_activate_clear_q;
  logic                       hw_status_wr;
  logic [7:0]                 hw_status_wdata;
  // OCP Recovery v1.1 Sec 9.2 defines PROTOCOL_ERROR clear-on-read for the
  // Recovery Agent USB command. The control decoder pulses this only after a
  // completed USB DEVICE_STATUS read; firmware cpuif reads are non-destructive.
  logic                       proto_err_rd_pulse;
  // OCP Recovery v1.1 Sec 9.1: an access to an unsupported OCP command code
  // pulses this so the FSM sets DEVICE_STATUS.PROTOCOL_ERROR = 0x01.
  logic                       unsupported_cmd_pulse;

  logic [7:0]                 device_status_out;
  logic [7:0]                 device_status_protocol_err_out;
  logic [15:0]                device_status_reason_out;
  logic [7:0]                 recovery_status_out;
  logic [7:0]                 recovery_vendor_status_out;
  logic [7:0]                 hw_status_out;
  logic [7:0]                 hw_status_vendor_out;
  logic [7:0]                 hw_status_ctemp_out;
  logic [7:0]                 hw_status_vendor_len_out;

  // --- A4 status (image push not used in EP0-only mode but A4 still drives) ---
  logic                       image_push_active;
  logic                       image_push_done;
  logic                       fifo_overflow;
  logic [31:0]                image_size;
  logic [31:0]                bytes_pushed;

  // --- INDIRECT_FIFO_CTRL read-back drive from A4 (cms_fifo) into the A3
  //     regblock (hw=w).  cms_fifo is the single live owner; the regblock holds
  //     the read-back copy (sw=r) read through the INDIRECT_FIFO_CTRL window. ---
  logic [7:0]                 fifo_ctrl_cms;
  logic                       fifo_ctrl_reset;
  logic [31:0]                fifo_ctrl_image_size;

  //////////////////////////////////////////////////////////////////////////////
  // Firmware cpuif arbiter. USB register and FIFO commands bypass this
  // arbitration through their dedicated hardware paths.
  //
  // EXT in-flight gating: once EXT is granted, hold off subsequent EXT
  // grants until its ack lands.  This protects multi-cycle cms_fifo accesses
  // when the upstream bridge legitimately holds wr/rd high while the request
  // round-trips across the clock domain.  Without the gate, a held-high EXT
  // request would be re-issued to A3/A4 each cycle and side-effecting pulses
  // such as recovery_ctrl_wr and device_reset_wr would fire repeatedly.
  // USB side already pulses rb_wr per word from ctrl_decode and is
  // intentionally not gated to preserve its 1-cycle ack semantics.
  //////////////////////////////////////////////////////////////////////////////

  logic [1:0] owner_q;
  logic       usb_req_now;
  logic       ext_req_now;
  logic       grant_usb;
  logic       grant_ext;
  logic       ext_in_flight_q;

  always_comb begin
    usb_req_now = 1'b0;
    ext_req_now = ext_rb_wr | ext_rb_rd;
    grant_usb   = 1'b0;
    grant_ext   = ext_req_now & ~ext_in_flight_q;
  end

  always_comb begin
    rb_cmd    = '0;
    rb_offset = '0;
    rb_wr     = 1'b0;
    rb_rd     = 1'b0;
    rb_wdata  = '0;
    rb_wstrb  = 4'h0;
    if (grant_ext | ext_in_flight_q) begin
      // EXT (SoC AXI/AHB sub-decoder) is word-native: the SoC master issues
      // word-aligned 32-bit accesses, so the full data word maps directly
      // onto the word-wide A3 reg-bus.  ext_rb_offset is a BYTE offset; the
      // low 2 bits are zero on word-aligned accesses, so the word index is
      // ext_rb_offset[15:2].  Writes drive all four lanes (rb_wstrb=4'hF);
      // reads also mark all four lanes so the adapter / FIFO path returns the
      // complete word.  The bus is held for the whole in-flight window so a
      // multi-cycle cms_fifo SRAM read keeps its command/address stable until
      // it acks.
      rb_cmd    = ext_rb_cmd;
      rb_offset = {2'b00, ext_rb_offset[15:2]};
      rb_wr     = ext_rb_wr;
      rb_rd     = ext_rb_rd;
      rb_wdata  = ext_rb_wdata;
      rb_wstrb  = 4'hF;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      owner_q          <= 2'b00;
      ext_in_flight_q  <= 1'b0;
    end else begin
      if (grant_ext)      owner_q <= 2'b10;
      else                owner_q <= 2'b00;

      // EXT in-flight: set when grant_ext fires, cleared when its ack
      // returns.  Same-cycle ack (cms_fifo register combinational
      // paths) is naturally handled because the clear term dominates
      // the set term -- if grant and ack co-occur in cycle K, the
      // flop stays low and the bridge advances next cycle.
      ext_in_flight_q <= (ext_in_flight_q | grant_ext) & ~ext_rb_ack;
    end
  end

  // USB FIFO commands connect directly to cms_fifo. Non-FIFO USB accesses are
  // served directly by the hardware-interface endpoint. Neither response path
  // depends on ext_in_flight_q.
  assign usb_fifo_req = usb_is_fifo_cmd & (usb_rb_wr | usb_rb_rd);
  assign usb_rb_rdata = usb_is_fifo_cmd ? fifo_rb_rdata : usb_hw_rdata;
  assign usb_rb_ack   = usb_is_fifo_cmd ? fifo_rb_ack   : usb_hw_ack;
  assign usb_rb_err   = usb_is_fifo_cmd ? fifo_rb_err   : usb_hw_err;

  // EXT is word-native: return the full 32-bit read word.  ext_rb_offset is
  // held stable by the AHB sub-decoder across the CDC handshake.  The ack/err
  // are qualified with ext_in_flight_q so a multi-cycle cms_fifo SRAM read,
  // which acks several cycles after the one-cycle grant_ext (owner_q==EXT only
  // lasts that one cycle), is still forwarded back to the SoC AXI master.
  assign ext_rb_rdata = rb_rdata[31:0];
  assign ext_rb_ack   = rb_ack & (grant_ext | (owner_q == 2'b10) | ext_in_flight_q);
  assign ext_rb_err   = rb_err & (grant_ext | (owner_q == 2'b10) | ext_in_flight_q);

  // Source qualifier for A3 (rb_adapter): '1' when the CURRENT rb_cmd/rb_wr/
  // rb_rd mux selection (above) is driven from the EXT branch, '0' for USB.
  // MUST be derived from the same combinational mux-select condition used to
  // drive rb_cmd/rb_wr/rb_rd (grant_ext | ext_in_flight_q, qualified by
  // ~grant_usb since USB has priority for new accesses), NOT from the
  // registered owner_q: a FIFO-routed EXT access (INDIRECT_FIFO_CTRL/STATUS)
  // acks combinationally in cms_fifo the same cycle as grant_ext, so
  // ext_in_flight_q never sets, but owner_q still registers to EXT for one
  // cycle afterward -- using owner_q here would misclassify a USB access
  // issued the very next cycle as EXT.
  logic rb_is_ext;
  assign rb_is_ext = grant_ext | ext_in_flight_q;

  //////////////////////////////////////////////////////////////////////////////
  // EP0 SETUP routing
  //
  // The VHDL arbiter (usb_pie_recovery_arb) performs OCP class decode inline
  // on the captured SETUP beat and pre-filters rec_setup_pkt_vld so that only
  // OCP-class SETUPs ever pulse into this SV stack.  All non-OCP SETUPs flow
  // through the arbiter to the legacy SIE unmodified, so standard USB
  // enumeration (GET_DESCRIPTOR / SET_ADDRESS / SET_CONFIGURATION /
  // GET_STATUS / ...) continues to be handled by the MCU EPCS.  See
  // usb_pie_recovery_arb.{e,m}.vhdl for the class-match definition
  // (OCP Recovery v1.1 Sec 8.5.1; USB 2.0 Sec 9.3 Tbl 9-2 SETUP byte layout).
  //
  // Because the arbiter delivers only claimed SETUPs, this module treats every
  // rec_setup_pkt_vld pulse as a recovery request and does not need a second
  // SETUP classifier or a local claim flop.
  //////////////////////////////////////////////////////////////////////////////


  //////////////////////////////////////////////////////////////////////////////
  // A2 : USB control-endpoint request decoder -> reg-bus master
  //////////////////////////////////////////////////////////////////////////////

  usb_ocp_recovery_ctrl_decode u_a2_ctrl_decode (
    .clk             (clk),
    .rst             (rst),

    .setup_pkt_vld   (rec_setup_pkt_vld),
    .setup_pkt       (rec_setup_pkt),
    .ctrl_out_data   (rec_ctrl_out_data),
    .ctrl_out_be     (rec_ctrl_out_be),
    .ctrl_out_vld    (rec_ctrl_out_vld),
    .ctrl_out_last   (rec_ctrl_out_last),
    .ctrl_out_rdy    (rec_ctrl_out_rdy),
    .ctrl_in_data    (rec_ctrl_in_data),
    .ctrl_in_be      (rec_ctrl_in_be),
    .ctrl_in_vld     (rec_ctrl_in_vld),
    .ctrl_in_last    (rec_ctrl_in_last),
    .ctrl_in_rdy     (rec_ctrl_in_rdy),
    .ctrl_set_stall  (rec_ctrl_set_stall),
    .ctrl_xfer_done  (rec_ctrl_xfer_done),
    .proto_err_rd_pulse (proto_err_rd_pulse),

    .rb_cmd          (usb_rb_cmd),
    .rb_offset       (usb_rb_offset),
    .rb_wr           (usb_rb_wr),
    .rb_rd           (usb_rb_rd),
    .rb_wdata        (usb_rb_wdata),
    .rb_wstrb        (usb_rb_wstrb),
    .rb_rdata        (usb_rb_rdata),
    .rb_ack          (usb_rb_ack),
    .rb_err          (usb_rb_err)
  );

  //////////////////////////////////////////////////////////////////////////////
  // A3 : word-wide reg-bus adapter + peakrdl-generated regblock
  //
  // The adapter (usb_ocp_recovery_rb_adapter) translates the word-wide rb_*
  // protocol into the regblock's 32-bit passthrough CPU interface and owns the
  // FSM-facing sideband contract (DEVICE_RESET / RECOVERY_CTRL strobes,
  // HW_STATUS write pulse, FIFO branch routing). The decoder owns the
  // PROTOCOL_ERROR Recovery Agent read-clear pulse because only it observes
  // USB transfer completion.
  // The regblock (usb_ocp_recovery_reg) is generated by peakrdl from
  // third_party/usb2/systemrdl/usb_ocp_recovery_reg.rdl and is the single
  // source of truth for field layout, reset values, and the SoC byte-flat
  // address window.
  //////////////////////////////////////////////////////////////////////////////

  // --- adapter <-> regblock cpuif passthrough ---
  logic        cpuif_req;
  logic        cpuif_req_is_wr;
  logic [11:0] cpuif_addr;
  logic [31:0] cpuif_wr_data;
  logic [31:0] cpuif_wr_biten;
  logic        cpuif_rd_ack;
  logic        cpuif_rd_err;
  logic [31:0] cpuif_rd_data;
  logic        cpuif_wr_ack;
  logic        cpuif_wr_err;

  // --- regblock hwif structs ---
  usb_ocp_recovery_reg_pkg::usb_ocp_recovery_reg__in_t  rb_hwif_in;
  usb_ocp_recovery_reg_pkg::usb_ocp_recovery_reg__out_t rb_hwif_out;

  // USB Recovery Agent register endpoint. It consumes the ctrl_decode rb_*
  // command stream for non-FIFO commands without touching the firmware cpuif.
  // FIFO commands are identified on usb_is_fifo_cmd and continue through A3/A4.
  usb_ocp_recovery_hwif_adapter u_usb_hwif_adapter (
    .cmd                         (usb_rb_cmd),
    .word_offset                 (usb_rb_offset),
    .wr                          (usb_rb_wr),
    .rd                          (usb_rb_rd),
    .wdata                       (usb_rb_wdata),
    .wstrb                       (usb_rb_wstrb),
    .prot_cap_0                  (rb_hwif_out.PROT_CAP_0.REC_MAGIC_STRING_0.value),
    .prot_cap_1                  (rb_hwif_out.PROT_CAP_1.REC_MAGIC_STRING_1.value),
    .prot_cap_2                  ({
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_RESERVED.value,
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_FIFO_CMS_SUPPORT.value,
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_FLASHLESS_BOOT.value,
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_VENDOR_COMMAND.value,
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_HARDWARE_STATUS.value,
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_INTERFACE_ISOLATION.value,
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_PUSH_C_IMAGE.value,
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_LOCAL_C_IMAGE.value,
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_RECOVERY_MEM_ACCESS.value,
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_DEVICE_STATUS.value,
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_DEVICE_RESET.value,
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_MGMT_RESET.value,
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_FORCED_RECOVERY.value,
                                    rb_hwif_out.PROT_CAP_2.AGENT_CAPS_IDENTIFICATION.value,
                                    rb_hwif_out.PROT_CAP_2.REC_PROT_VERSION.value
                                  }),
    .prot_cap_3                  ({
                                    rb_hwif_out.PROT_CAP_3.RESERVED_31_24.value,
                                    rb_hwif_out.PROT_CAP_3.HEARTBEAT_PERIOD.value,
                                    rb_hwif_out.PROT_CAP_3.MAX_RESP_TIME.value,
                                    rb_hwif_out.PROT_CAP_3.NUM_OF_CMS_REGIONS.value
                                  }),
    .device_id                   (device_id_in),
    .device_status               (device_status_out),
    .protocol_error              (device_status_protocol_err_out),
    .recovery_reason             (device_status_reason_out),
    .recovery_status             (recovery_status_out),
    .recovery_vendor_status      (recovery_vendor_status_out),
    .hw_status                   (hw_status_out),
    .hw_vendor_status            (hw_status_vendor_out),
    .hw_ctemp                    (hw_status_ctemp_out),
    .hw_vendor_status_len        (hw_status_vendor_len_out),
    .fifo_ctrl_cms               (fifo_ctrl_cms),
    .fifo_ctrl_reset             (fifo_ctrl_reset),
    .fifo_ctrl_image_size        (fifo_ctrl_image_size),
    .device_reset_ctrl_value     (rb_hwif_out.DEVICE_RESET.RESET_CTRL.value),
    .device_reset_forced_value   (rb_hwif_out.DEVICE_RESET.FORCED_RECOVERY.value),
    .device_reset_iface_value    (rb_hwif_out.DEVICE_RESET.IF_CTRL.value),
    .recovery_ctrl_cms_value     (rb_hwif_out.RECOVERY_CTRL.CMS.value),
    .recovery_ctrl_img_sel_value (rb_hwif_out.RECOVERY_CTRL.REC_IMG_SEL.value),
    .recovery_ctrl_activate_value(rb_hwif_out.RECOVERY_CTRL.ACTIVATE_REC_IMG.value),
    .vendor_value                (rb_hwif_out.VENDOR.VENDOR_DATA.value),
    .rdata                       (usb_hw_rdata),
    .ack                         (usb_hw_ack),
    .err                         (usb_hw_err),
    .is_fifo_cmd                 (usb_is_fifo_cmd),
    .protocol_error_set          (usb_protocol_error_set),
    .device_reset_ctrl_next      (usb_device_reset_ctrl_next),
    .device_reset_ctrl_we        (usb_device_reset_ctrl_we),
    .device_reset_forced_next    (usb_device_reset_forced_next),
    .device_reset_forced_we      (usb_device_reset_forced_we),
    .device_reset_iface_next     (usb_device_reset_iface_next),
    .device_reset_iface_we       (usb_device_reset_iface_we),
    .recovery_ctrl_cms_next      (usb_recovery_ctrl_cms_next),
    .recovery_ctrl_cms_we        (usb_recovery_ctrl_cms_we),
    .recovery_ctrl_img_sel_next  (usb_recovery_ctrl_img_sel_next),
    .recovery_ctrl_img_sel_we    (usb_recovery_ctrl_img_sel_we),
    .recovery_ctrl_activate_next (usb_recovery_ctrl_activate_next),
    .recovery_ctrl_activate_we   (usb_recovery_ctrl_activate_we),
    .vendor_next                 (usb_vendor_next),
    .vendor_we                   (usb_vendor_we),
    .device_reset_wr             (device_reset_wr),
    .device_reset_ctrl           (device_reset_ctrl),
    .device_reset_forced         (device_reset_forced),
    .device_reset_iface          (device_reset_iface),
    .recovery_ctrl_wr_cms        (recovery_ctrl_wr_cms),
    .recovery_ctrl_wr_img_sel    (recovery_ctrl_wr_img_sel),
    .recovery_ctrl_wr_activate   (recovery_ctrl_wr_activate),
    .recovery_ctrl_cms           (recovery_ctrl_cms),
    .recovery_ctrl_img_sel       (recovery_ctrl_img_sel),
    .recovery_ctrl_activate      (recovery_ctrl_activate)
  );

  usb_ocp_recovery_rb_adapter u_a3_adapter (
    .clk             (clk),
    .rst             (rst),

    .rb_cmd          (rb_cmd),
    .rb_offset       (rb_offset),
    .rb_wr           (rb_wr),
    .rb_rd           (rb_rd),
    .rb_wdata        (rb_wdata),
    .rb_wstrb        (rb_wstrb),
    .rb_rdata        (rb_rdata),
    .rb_ack          (rb_ack),
    .rb_err          (rb_err),
    .rb_is_ext       (rb_is_ext),

    .fifo_rb_sel     (ext_fifo_rb_sel),
    .fifo_rb_cmd     (ext_fifo_rb_cmd),
    .fifo_rb_offset  (ext_fifo_rb_offset),
    .fifo_rb_wr      (ext_fifo_rb_wr),
    .fifo_rb_rd      (ext_fifo_rb_rd),
    .fifo_rb_wdata   (ext_fifo_rb_wdata),
    .fifo_rb_wstrb   (ext_fifo_rb_wstrb),
    .fifo_rb_rdata   (ext_fifo_rb_rdata),
    .fifo_rb_ack     (ext_fifo_rb_ack),
    .fifo_rb_err     (ext_fifo_rb_err),

    .cpuif_req       (cpuif_req),
    .cpuif_req_is_wr (cpuif_req_is_wr),
    .cpuif_addr      (cpuif_addr),
    .cpuif_wr_data   (cpuif_wr_data),
    .cpuif_wr_biten  (cpuif_wr_biten),
    .cpuif_rd_ack    (cpuif_rd_ack),
    .cpuif_rd_err    (cpuif_rd_err),
    .cpuif_rd_data   (cpuif_rd_data),
    .cpuif_wr_ack    (cpuif_wr_ack),
    .cpuif_wr_err    (cpuif_wr_err),

    .hw_status_wr                     (hw_status_wr),
    .hw_status_wdata                  (hw_status_wdata),
    .unsupported_cmd_pulse            (unsupported_cmd_pulse)
  );

  // Firmware writes zero to the standard RECOVERY_CTRL activation field after
  // verifying the drained image. Delay cpuif swmod one cycle so the updated
  // field value is valid when the FSM recognizes that device-side clear.
  always_ff @(posedge clk) begin
    if (rst) begin
      firmware_activate_clear_q <= 1'b0;
    end else begin
      firmware_activate_clear_q <= rb_hwif_out.RECOVERY_CTRL.ACTIVATE_REC_IMG.swmod;
    end
  end

  // Emergency-fallback OCP path-disable control: drive out to the VHDL arbiter
  // (usb_pie_recovery_arb ocp_path_disable_i via the vendor IP wrapper
  // hierarchy) from the Caliptra-specific CALIPTRA_CTRL register (outside the
  // OCP command aperture). Same-domain (utmi_clk) registered field value; no
  // synchronizer needed.
  assign rec_ocp_path_disable = rb_hwif_out.CALIPTRA_CTRL.OCP_PATH_DISABLE.value;

  // Only USB hardware-interface writes produce OCP command FSM triggers.
  // Firmware cpuif writes update field storage but do not trigger the recovery
  // FSM. The explicit firmware activation path above is the sole exception.
  assign recovery_ctrl_wr = recovery_ctrl_wr_cms
                          | recovery_ctrl_wr_img_sel
                          | recovery_ctrl_wr_activate;

  // --------------------------------------------------------------------------
  // hwif_in wiring.
  //
  // PROT_CAP (16 B) fields are static read-only constants in the RDL
  // (sw=r; hw=na); the regblock returns their reset directly with no hwif
  // drive. DEVICE_ID (24 B) is fed from the SoC integrator tie
  // (device_id_in). Those .next inputs are sampled continuously by
  // hw=w / we=false fields, so they appear in the host read window with no
  // extra storage cycle.
  //
  // DEVICE_STATUS_0 fields (DEV_STATUS / PROT_ERROR / REC_REASON_CODE)
  // come from the FSM (Sec 9.2).  DEVICE_STATUS_1..15 carry the
  // optional heartbeat / vendor-status bytes (Sec 9.2 bytes 4..63);
  // those are vendor-specific and remain tied to 0 until a vendor extension
  // populates them.
  //
  // RECOVERY_STATUS (Sec 9.2) byte 0 splits low nibble =
  // DEV_REC_STATUS, high nibble = REC_IMG_INDEX; byte 1 = vendor.
  // HW_STATUS byte 0 (Sec 9.2) splits bit 0 = TEMP_CRITICAL,
  // bit 1 = SOFT_ERR, bit 2 = FATAL_ERR, bits 7:3 = reserved.
  //
  // INDIRECT_STATUS / INDIRECT_DATA / INDIRECT_FIFO_STATUS / INDIRECT_FIFO_DATA
  // (Sec 9.2) are routed by usb_ocp_recovery_rb_adapter.sv (is_fifo_cmd) to the
  // cms_fifo A4 block for both read and write; their regblock copies are not
  // read out on the host control bus and remain at 0 (A4 owns the live values).
  // INDIRECT_FIFO_CTRL is the exception: cms_fifo captures the WRITE but DRIVES
  // the regblock CTRL_0/_1 fields (hw=w) below, and the host READS them through
  // the regblock command window, so the regblock is the single read-back source
  // (no duplicated self-synthesized read-back in cms_fifo).
  //
  // The adapter also intercepts cpuif_rd_err (rb_adapter only ORs fifo_rb_err
  // into rb_err), so a regblock-side decode miss cannot surface as an rb_err /
  // AXI error response.  Every regblock byte in the address window is backed by
  // a declared field per the generated package (usb_ocp_recovery_reg_pkg.sv).
  // --------------------------------------------------------------------------
  always_comb begin
    rb_hwif_in = '{default: '0};

    // PROT_CAP is firmware-configurable through cpuif and exposed to the USB
    // endpoint through hwif_out. Its RDL hw=r properties make the stored values
    // visible without permitting a hardware write.

    // USB Recovery Agent writes use the hardware interface. The generated
    // field storage remains readable and writable by firmware through cpuif,
    // but only the USB endpoint emits recovery FSM trigger pulses.
    rb_hwif_in.DEVICE_RESET.RESET_CTRL.next       = usb_device_reset_ctrl_next;
    rb_hwif_in.DEVICE_RESET.RESET_CTRL.we         = usb_device_reset_ctrl_we;
    rb_hwif_in.DEVICE_RESET.FORCED_RECOVERY.next  = usb_device_reset_forced_next;
    rb_hwif_in.DEVICE_RESET.FORCED_RECOVERY.we    = usb_device_reset_forced_we;
    rb_hwif_in.DEVICE_RESET.IF_CTRL.next          = usb_device_reset_iface_next;
    rb_hwif_in.DEVICE_RESET.IF_CTRL.we            = usb_device_reset_iface_we;
    rb_hwif_in.RECOVERY_CTRL.CMS.next             = usb_recovery_ctrl_cms_next;
    rb_hwif_in.RECOVERY_CTRL.CMS.we               = usb_recovery_ctrl_cms_we;
    rb_hwif_in.RECOVERY_CTRL.REC_IMG_SEL.next     = usb_recovery_ctrl_img_sel_next;
    rb_hwif_in.RECOVERY_CTRL.REC_IMG_SEL.we       = usb_recovery_ctrl_img_sel_we;
    rb_hwif_in.RECOVERY_CTRL.ACTIVATE_REC_IMG.next = usb_recovery_ctrl_activate_next;
    rb_hwif_in.RECOVERY_CTRL.ACTIVATE_REC_IMG.we   = usb_recovery_ctrl_activate_we;
    rb_hwif_in.VENDOR.VENDOR_DATA.next            = usb_vendor_next;
    rb_hwif_in.VENDOR.VENDOR_DATA.we              = usb_vendor_we;

    // DEVICE_ID: 6 DWORDs from device_id_in[191:0].  DEVICE_ID_0 is split
    // into DESC_TYPE[7:0] / VENDOR_SPECIFIC_STR_LENGTH[15:8] / DATA_3_2[31:16];
    // the slice into the packed device_id_in[191:0] is the same byte
    // sequence.  DEVICE_ID_1..5 are flat 32-bit DATA fields.
    rb_hwif_in.DEVICE_ID_0.DESC_TYPE.next                  = device_id_in[7:0];
    rb_hwif_in.DEVICE_ID_0.VENDOR_SPECIFIC_STR_LENGTH.next = device_id_in[15:8];
    rb_hwif_in.DEVICE_ID_0.DATA_3_2.next                   = device_id_in[31:16];
    rb_hwif_in.DEVICE_ID_1.DATA_7_4.next                   = device_id_in[63:32];
    rb_hwif_in.DEVICE_ID_2.DATA_11_8.next                  = device_id_in[95:64];
    rb_hwif_in.DEVICE_ID_3.DATA_15_12.next                 = device_id_in[127:96];
    rb_hwif_in.DEVICE_ID_4.DATA_19_16.next                 = device_id_in[159:128];
    rb_hwif_in.DEVICE_ID_5.DATA_23_20.next                 = device_id_in[191:160];

    // DEVICE_STATUS_0: byte 0 = DEV_STATUS, byte 1 = PROT_ERROR, bytes 2-3
    // = REC_REASON_CODE (16b).  All other DEVICE_STATUS_x regs remain at 0.
    rb_hwif_in.DEVICE_STATUS_0.DEV_STATUS.next      = device_status_out;
    rb_hwif_in.DEVICE_STATUS_0.PROT_ERROR.next      = device_status_protocol_err_out;
    rb_hwif_in.DEVICE_STATUS_0.REC_REASON_CODE.next = device_status_reason_out;

    // CALIPTRA_CTRL.OCP_PATH_DISABLE (emergency-fallback path-disable control):
    // software write-enable gated by rb_is_ext so only EXT/firmware writes
    // commit; a USB-host write is silently ignored (swwe=0), matching the
    // same source-qualification pattern used for PROT_CAP capability writes.
    // The register itself lives outside the OCP command aperture and is only
    // reachable via the firmware/AXI sub-decoder.
    rb_hwif_in.CALIPTRA_CTRL.OCP_PATH_DISABLE.swwe = rb_is_ext;

    // CALIPTRA_STATUS (read-only, hw=w): Caliptra-specific sticky FIFO status
    // relocated out of the non-spec INDIRECT_FIFO_STATUS byte-0 bits. Driven
    // from the live cms_fifo sticky signals (region_reset_q via fifo_ctrl_reset,
    // overflow_q via fifo_overflow, image_done_q via image_push_done).
    rb_hwif_in.CALIPTRA_STATUS.REGION_RESET.next = fifo_ctrl_reset;
    rb_hwif_in.CALIPTRA_STATUS.OVERFLOW.next     = fifo_overflow;
    rb_hwif_in.CALIPTRA_STATUS.IMAGE_DONE.next   = image_push_done;

    // RECOVERY_STATUS byte 0 (low nibble = device status, high nibble =
    // image index) + byte 1 (vendor).
    rb_hwif_in.RECOVERY_STATUS.DEV_REC_STATUS.next         = recovery_status_out[3:0];
    rb_hwif_in.RECOVERY_STATUS.REC_IMG_INDEX.next          = recovery_status_out[7:4];
    rb_hwif_in.RECOVERY_STATUS.VENDOR_SPECIFIC_STATUS.next = recovery_vendor_status_out;

    // HW_STATUS byte 0 bits 0..2 + reserved 7:3.
    rb_hwif_in.HW_STATUS.TEMP_CRITICAL.next        = hw_status_out[0];
    rb_hwif_in.HW_STATUS.SOFT_ERR.next             = hw_status_out[1];
    rb_hwif_in.HW_STATUS.FATAL_ERR.next            = hw_status_out[2];
    rb_hwif_in.HW_STATUS.RESERVED_7_3.next         = hw_status_out[7:3];
    rb_hwif_in.HW_STATUS.VENDOR_HW_STATUS.next     = hw_status_vendor_out;
    rb_hwif_in.HW_STATUS.CTEMP.next                = hw_status_ctemp_out;
    rb_hwif_in.HW_STATUS.VENDOR_HW_STATUS_LEN.next = hw_status_vendor_len_out;

    // INDIRECT_FIFO_CTRL read-back (sw=r/hw=w): cms_fifo is the live owner and
    // drives the regblock copy.  CTRL_0 byte0 = CMS, byte1 bit0 = region-reset
    // (sticky until INDIRECT_FIFO_STATUS write-1-to-clear); CTRL_1 = IMAGE_SIZE
    // in DWORD units.  RESET is zero-extended into byte 1 to match the field.
    rb_hwif_in.INDIRECT_FIFO_CTRL_0.CMS.next        = fifo_ctrl_cms;
    rb_hwif_in.INDIRECT_FIFO_CTRL_0.RESET.next      = {7'b0, fifo_ctrl_reset};
    rb_hwif_in.INDIRECT_FIFO_CTRL_1.IMAGE_SIZE.next = fifo_ctrl_image_size;
  end

  usb_ocp_recovery_reg u_a3_regblock (
    .clk                  (clk),
    .rst                  (rst),

    .s_cpuif_req          (cpuif_req),
    .s_cpuif_req_is_wr    (cpuif_req_is_wr),
    // Regblock addrmap is 2 KiB (upper half of the merged USB device window),
    // so s_cpuif_addr is 11 bits.  cpuif_addr[11] is always 0 (every OCP /
    // Caliptra-specific register offset is < 0x800); slice it off explicitly.
    .s_cpuif_addr         (cpuif_addr[10:0]),
    .s_cpuif_wr_data      (cpuif_wr_data),
    .s_cpuif_wr_biten     (cpuif_wr_biten),
    .s_cpuif_req_stall_wr (/* unused */),
    .s_cpuif_req_stall_rd (/* unused */),
    .s_cpuif_rd_ack       (cpuif_rd_ack),
    .s_cpuif_rd_err       (cpuif_rd_err),
    .s_cpuif_rd_data      (cpuif_rd_data),
    .s_cpuif_wr_ack       (cpuif_wr_ack),
    .s_cpuif_wr_err       (cpuif_wr_err),

    .hwif_in              (rb_hwif_in),
    .hwif_out             (rb_hwif_out)
  );

  // USB FIFO traffic owns the cms_fifo command port whenever it presents a
  // command. Firmware DATA writes are unsupported by the use model and receive
  // an immediate error; firmware FIFO_CTRL writes that can reconfigure/reset
  // the FIFO wait until the current USB FIFO packet retires.
  always_ff @(posedge clk) begin
    if (rst) begin
      usb_fifo_packet_active_q <= 1'b0;
    end else begin
      if (rec_ctrl_xfer_done) begin
        usb_fifo_packet_active_q <= 1'b0;
      end else if (usb_fifo_req && usb_rb_wr
                   && (usb_rb_cmd == OCP_CMD_INDIRECT_FIFO_DATA)) begin
        usb_fifo_packet_active_q <= 1'b1;
      end
    end
  end

  assign ext_fifo_data_write_reject = ext_fifo_rb_sel && ext_fifo_rb_wr
                                    && (ext_fifo_rb_cmd == OCP_CMD_INDIRECT_FIFO_DATA);
  assign ext_fifo_config_blocked = usb_fifo_packet_active_q && ext_fifo_rb_sel
                                && ext_fifo_rb_wr
                                && (ext_fifo_rb_cmd == OCP_CMD_INDIRECT_FIFO_CTRL);

  always_comb begin
    fifo_rb_sel    = 1'b0;
    fifo_rb_cmd    = '0;
    fifo_rb_offset = '0;
    fifo_rb_wr     = 1'b0;
    fifo_rb_rd     = 1'b0;
    fifo_rb_wdata  = '0;
    fifo_rb_wstrb  = '0;

    if (usb_fifo_req) begin
      fifo_rb_sel    = 1'b1;
      fifo_rb_cmd    = usb_rb_cmd;
      fifo_rb_offset = usb_rb_offset;
      fifo_rb_wr     = usb_rb_wr;
      fifo_rb_rd     = usb_rb_rd;
      fifo_rb_wdata  = usb_rb_wdata;
      fifo_rb_wstrb  = usb_rb_wstrb;
    end else if (ext_fifo_rb_sel && !ext_fifo_data_write_reject
                 && !ext_fifo_config_blocked) begin
      fifo_rb_sel    = ext_fifo_rb_sel;
      fifo_rb_cmd    = ext_fifo_rb_cmd;
      fifo_rb_offset = ext_fifo_rb_offset;
      fifo_rb_wr     = ext_fifo_rb_wr;
      fifo_rb_rd     = ext_fifo_rb_rd;
      fifo_rb_wdata  = ext_fifo_rb_wdata;
      fifo_rb_wstrb  = ext_fifo_rb_wstrb;
    end
  end

  assign ext_fifo_rb_rdata = fifo_rb_rdata;
  assign ext_fifo_rb_ack   = ext_fifo_data_write_reject ? 1'b1
                           : (usb_fifo_req || ext_fifo_config_blocked) ? 1'b0
                           : fifo_rb_ack;
  assign ext_fifo_rb_err   = ext_fifo_data_write_reject ? 1'b1
                           : (usb_fifo_req || ext_fifo_config_blocked) ? 1'b0
                           : fifo_rb_err;

  //////////////////////////////////////////////////////////////////////////////
  // A4 : CMS indirect-memory FIFO + window (EP0-only; bulk ports removed)
  //////////////////////////////////////////////////////////////////////////////

  usb_ocp_recovery_cms_fifo #(
    .CMS_ADDR_W (CMS_ADDR_W),
    .NUM_CMS    (NUM_CMS),
    .FIFO_DEPTH (FIFO_DEPTH_DWORDS)
  ) u_a4_cms_fifo (
    .clk             (clk),
    .rst             (rst),

    // Async FIFO read port (dev_axi_aclk domain) -- native pop.
    .clk_rd          (clk_rd),
    .rst_rd_n        (rst_rd_n),
    .fifo_rd_valid   (fifo_rd_valid),
    .fifo_rd_ready   (fifo_rd_ready),
    .fifo_rd_data    (fifo_rd_data),
    .fifo_rd_depth   (fifo_rd_depth),

    .fifo_rb_sel     (fifo_rb_sel),
    .fifo_rb_cmd     (fifo_rb_cmd),
    .fifo_rb_offset  (fifo_rb_offset),
    .fifo_rb_wr      (fifo_rb_wr),
    .fifo_rb_rd      (fifo_rb_rd),
    .fifo_rb_wdata   (fifo_rb_wdata),
    .fifo_rb_wstrb   (fifo_rb_wstrb),
    .fifo_rb_rdata   (fifo_rb_rdata),
    .fifo_rb_ack     (fifo_rb_ack),
    .fifo_rb_err     (fifo_rb_err),

    .image_push_active (image_push_active),
    .image_push_done   (image_push_done),
    .fifo_overflow     (fifo_overflow),
    .image_size        (image_size),
    .bytes_pushed      (bytes_pushed),
    .fifo_ctrl_cms        (fifo_ctrl_cms),
    .fifo_ctrl_reset      (fifo_ctrl_reset),
    .fifo_ctrl_image_size (fifo_ctrl_image_size)
  );

  //////////////////////////////////////////////////////////////////////////////
  // A5 : recovery state machine
  //////////////////////////////////////////////////////////////////////////////

  usb_ocp_recovery_fsm u_a5_fsm (
    .clk             (clk),
    .rst             (rst),

    .rec_trigger     (rec_trigger),
    .soc_boot_ack    (soc_boot_ack),

    .device_reset_wr                  (device_reset_wr),
    .device_reset_ctrl                (device_reset_ctrl),
    .device_reset_forced              (device_reset_forced),
    .device_reset_iface               (device_reset_iface),
    .recovery_ctrl_wr                 (recovery_ctrl_wr),
    .recovery_ctrl_wr_cms             (recovery_ctrl_wr_cms),
    .recovery_ctrl_wr_img_sel         (recovery_ctrl_wr_img_sel),
    .recovery_ctrl_cms                (recovery_ctrl_cms),
    .recovery_ctrl_img_sel            (recovery_ctrl_img_sel),
    .recovery_ctrl_activate           (recovery_ctrl_activate),
    .firmware_activate_clear          (firmware_activate_clear_q
                                       && (rb_hwif_out.RECOVERY_CTRL.ACTIVATE_REC_IMG.value == 8'h00)),
    .proto_err_rd_pulse               (proto_err_rd_pulse),
    .unsupported_cmd_set              (unsupported_cmd_pulse | usb_protocol_error_set),

    .image_push_active (image_push_active),
    .image_push_done   (image_push_done),
    .fifo_overflow     (fifo_overflow),
    .image_size        (image_size),
    .bytes_pushed      (bytes_pushed),

    .device_status_out              (device_status_out),
    .device_status_protocol_err_out (device_status_protocol_err_out),
    .device_status_reason_out       (device_status_reason_out),
    .recovery_status_out            (recovery_status_out),
    .recovery_vendor_status_out     (recovery_vendor_status_out),
    .hw_status_out                  (hw_status_out),
    .hw_status_vendor_out           (hw_status_vendor_out),
    .hw_status_ctemp_out            (hw_status_ctemp_out),
    .hw_status_vendor_len_out       (hw_status_vendor_len_out),

    .recovery_active  (recovery_active),
    .image_ready      (image_ready),
    .boot_req         (boot_req),
    .device_reset_req (device_reset_req),
    .fatal_err        (fatal_err)
  );

  //////////////////////////////////////////////////////////////////////////////
  // Assertions
  //////////////////////////////////////////////////////////////////////////////
  // synopsys translate_off
  always_ff @(posedge clk) begin
    if (!rst) begin
      assert (!(rb_wr && rb_rd))
        else $error("usb_ocp_recovery_top: rb_wr and rb_rd both asserted");
      assert (!(usb_rb_wr && usb_rb_rd))
        else $error("usb_ocp_recovery_top: usb master asserted wr+rd");
      assert (!(ext_rb_wr && ext_rb_rd))
        else $error("usb_ocp_recovery_top: ext master asserted wr+rd");
      assert (!(usb_rb_ack && ext_rb_ack))
        else $error("usb_ocp_recovery_top: ack routed to both masters");
      if (usb_fifo_req) begin
        assert (usb_rb_ack)
          else $error("usb_ocp_recovery_top: USB FIFO command stalled");
      end
      if (ext_fifo_data_write_reject) begin
        assert (ext_fifo_rb_ack && ext_fifo_rb_err)
          else $error("usb_ocp_recovery_top: firmware FIFO DATA write was not rejected");
      end
      if (ext_fifo_config_blocked) begin
        assert (!fifo_rb_sel)
          else $error("usb_ocp_recovery_top: firmware FIFO config committed during USB packet");
      end
    end
  end
  // synopsys translate_on

endmodule
