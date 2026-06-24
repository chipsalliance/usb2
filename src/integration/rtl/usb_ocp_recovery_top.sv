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
  // Async FIFO READ port (P9-0.1-C).  Plumbed straight through to the A4
  // cms_fifo so the dev_axi_aclk-domain wrapper can pop INDIRECT_FIFO_DATA
  // (0x2E) reads natively, bypassing the utmi-clk CDC bridge.  clk_rd is
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
  //----------------------------------------------------------------------------
  input  logic                    rec_trigger,
  input  logic                    soc_boot_ack,
  output logic                    recovery_active,
  output logic                    image_ready,
  output logic                    boot_req,
  output logic                    device_reset_req,
  output logic                    fatal_err
);

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

  // --- A3 <-> A5 sideband ---
  logic                       device_reset_wr;
  logic [7:0]                 device_reset_ctrl;
  logic [7:0]                 device_reset_forced;
  logic [7:0]                 device_reset_iface;
  logic                       recovery_ctrl_wr;
  logic                       recovery_ctrl_wr_cms;
  logic                       recovery_ctrl_wr_img_sel;
  logic [7:0]                 recovery_ctrl_cms;
  logic [7:0]                 recovery_ctrl_img_sel;
  logic [7:0]                 recovery_ctrl_activate;
  logic                       recovery_ctrl_activate_consume;
  logic                       hw_status_wr;
  logic [7:0]                 hw_status_wdata;
  // OCP Recovery v1.1 Section 9.2 Tbl 9-5 / i3c-rdl line 274:
  // PROTOCOL_ERROR has onread = rclr.  regs pulses this when host reads
  // DEVICE_STATUS byte 1; FSM clears its sticky proto-err latch on the pulse.
  logic                       proto_err_rd_pulse;

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

  //////////////////////////////////////////////////////////////////////////////
  // Reg-bus arbiter: USB priority, external (AHB) preempts when USB idle.
  // 1-cycle ack window owner tracking captured in owner_q.
  //   owner_q = 2'b01 -> USB, 2'b10 -> EXT.
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
    usb_req_now = usb_rb_wr | usb_rb_rd;
    ext_req_now = ext_rb_wr | ext_rb_rd;
    // USB has priority for NEW accesses, but an EXT access that is already
    // in flight must not be preempted: INDIRECT_FIFO_DATA / INDIRECT_DATA are
    // SRAM-backed in cms_fifo and ack several cycles after the one-cycle
    // grant_ext, so the EXT request must be held (and USB held off) until the
    // multi-cycle ack returns, otherwise the read deadlocks.
    grant_usb   = usb_req_now & ~ext_in_flight_q;
    grant_ext   = ext_req_now & ~usb_req_now & (owner_q != 2'b01)
                              & ~ext_in_flight_q;
  end

  always_comb begin
    rb_cmd    = '0;
    rb_offset = '0;
    rb_wr     = 1'b0;
    rb_rd     = 1'b0;
    rb_wdata  = '0;
    rb_wstrb  = 4'h0;
    if (grant_usb) begin
      // USB master is word-native (ctrl_decode already supplies a word
      // offset, 32-bit data and a byte-lane strobe).
      rb_cmd    = usb_rb_cmd;
      rb_offset = usb_rb_offset;
      rb_wr     = usb_rb_wr;
      rb_rd     = usb_rb_rd;
      rb_wdata  = usb_rb_wdata;
      rb_wstrb  = usb_rb_wstrb;
    end else if (grant_ext | ext_in_flight_q) begin
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
      if (grant_usb)      owner_q <= 2'b01;
      else if (grant_ext) owner_q <= 2'b10;
      else                owner_q <= 2'b00;

      // EXT in-flight: set when grant_ext fires, cleared when its ack
      // returns.  Same-cycle ack (cms_fifo register combinational
      // paths) is naturally handled because the clear term dominates
      // the set term -- if grant and ack co-occur in cycle K, the
      // flop stays low and the bridge advances next cycle.
      ext_in_flight_q <= (ext_in_flight_q | grant_ext) & ~ext_rb_ack;
    end
  end

  // Response demux.  The USB master's forward push path is combinational
  // (grant_usb -> rb_wr -> cms_fifo push commits in the grant cycle), so its
  // ack returned to the producer MUST also be combinational and qualified by
  // the same combinational grant_usb -- NOT the registered owner_q.  Gating on
  // owner_q (which only asserts the cycle AFTER grant_usb) delayed ctrl_out_rdy
  // by one cycle while the push already committed, so the VHDL arbiter held its
  // read index and the SV consumer pushed the first OUT DWORD twice (and the
  // last DWORD was dropped at image_complete).  Using grant_usb lands the ack
  // in the same cycle as the push so producer index and consumer push advance
  // one-to-one from the first word.  This mirrors the EXT ack qualifier below.
  // For register reads rb_ack is itself registered one cycle late inside the
  // rb_adapter and grant_usb stays asserted until the ack is consumed, so their
  // timing is unchanged.  No combinational loop: usb_rb_wr/usb_rb_rd do not
  // depend on usb_rb_ack.
  assign usb_rb_rdata = rb_rdata;
  assign usb_rb_ack   = rb_ack & grant_usb;
  assign usb_rb_err   = rb_err & grant_usb;

  // EXT is word-native: return the full 32-bit read word.  ext_rb_offset is
  // held stable by the AHB sub-decoder across the CDC handshake.  The ack/err
  // are qualified with ext_in_flight_q so a multi-cycle cms_fifo SRAM read,
  // which acks several cycles after the one-cycle grant_ext (owner_q==EXT only
  // lasts that one cycle), is still forwarded back to the SoC AXI master.
  assign ext_rb_rdata = rb_rdata[31:0];
  assign ext_rb_ack   = rb_ack & (grant_ext | (owner_q == 2'b10) | ext_in_flight_q);
  assign ext_rb_err   = rb_err & (grant_ext | (owner_q == 2'b10) | ext_in_flight_q);

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
  // HW_STATUS write pulse, PROTOCOL_ERROR rclr pulse, FIFO branch routing).
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
    .proto_err_rd_pulse               (proto_err_rd_pulse)
  );

  // --------------------------------------------------------------------------
  // swmod input-conditioning block.
  //
  // PeakRDL swmod is combinational in the write-accept cycle while the field
  // .value is registered one cycle later, so swmod leads the value by exactly
  // one cycle.  The recovery FSM (A5) expects a coincident {strobe,value}
  // pair, so each swmod pulse is delayed by one cycle to align with the
  // registered .value at T+1.  The .value lines are passed combinationally
  // because they are already registered inside the regblock and present the new
  // data at T+1, coincident with the delayed strobe.  Raw combinational swmod
  // is never wired directly to the FSM because it would sample the old value on
  // the strobe cycle.
  // --------------------------------------------------------------------------
  logic swmod_dr_reset_q;
  logic swmod_dr_forced_q;
  logic swmod_dr_iface_q;
  logic swmod_rc_cms_q;
  logic swmod_rc_img_sel_q;
  logic swmod_rc_activate_q;

  always_ff @(posedge clk) begin
    if (rst) begin
      swmod_dr_reset_q    <= 1'b0;
      swmod_dr_forced_q   <= 1'b0;
      swmod_dr_iface_q    <= 1'b0;
      swmod_rc_cms_q      <= 1'b0;
      swmod_rc_img_sel_q  <= 1'b0;
      swmod_rc_activate_q <= 1'b0;
    end else begin
      swmod_dr_reset_q    <= rb_hwif_out.DEVICE_RESET.RESET_CTRL.swmod;
      swmod_dr_forced_q   <= rb_hwif_out.DEVICE_RESET.FORCED_RECOVERY.swmod;
      swmod_dr_iface_q    <= rb_hwif_out.DEVICE_RESET.IF_CTRL.swmod;
      swmod_rc_cms_q      <= rb_hwif_out.RECOVERY_CTRL.CMS.swmod;
      swmod_rc_img_sel_q  <= rb_hwif_out.RECOVERY_CTRL.REC_IMG_SEL.swmod;
      swmod_rc_activate_q <= rb_hwif_out.RECOVERY_CTRL.ACTIVATE_REC_IMG.swmod;
    end
  end

  // DEVICE_RESET strobe = any of the three writable bytes written this word.
  assign device_reset_wr     = swmod_dr_reset_q | swmod_dr_forced_q |
                               swmod_dr_iface_q;
  assign device_reset_ctrl   = rb_hwif_out.DEVICE_RESET.RESET_CTRL.value;
  assign device_reset_forced = rb_hwif_out.DEVICE_RESET.FORCED_RECOVERY.value;
  assign device_reset_iface  = rb_hwif_out.DEVICE_RESET.IF_CTRL.value;

  // RECOVERY_CTRL per-byte + activate strobes.
  assign recovery_ctrl_wr_cms     = swmod_rc_cms_q;
  assign recovery_ctrl_wr_img_sel = swmod_rc_img_sel_q;
  assign recovery_ctrl_wr         = swmod_rc_cms_q | swmod_rc_img_sel_q |
                                    swmod_rc_activate_q;
  assign recovery_ctrl_cms        = rb_hwif_out.RECOVERY_CTRL.CMS.value;
  assign recovery_ctrl_img_sel    = rb_hwif_out.RECOVERY_CTRL.REC_IMG_SEL.value;
  assign recovery_ctrl_activate   = rb_hwif_out.RECOVERY_CTRL.ACTIVATE_REC_IMG.value;

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
  // come from the FSM (Sec 9.2 Tbl 9-5).  DEVICE_STATUS_1..15 carry the
  // optional heartbeat / vendor-status bytes (Sec 9.2 Tbl 9-5 bytes 4..63);
  // those are vendor-specific and remain tied to 0 until a vendor extension
  // populates them.
  //
  // RECOVERY_STATUS (Sec 9.2 Tbl 9-11) byte 0 splits low nibble =
  // DEV_REC_STATUS, high nibble = REC_IMG_INDEX; byte 1 = vendor.
  // HW_STATUS byte 0 (Sec 9.2 Tbl 9-12) splits bit 0 = TEMP_CRITICAL,
  // bit 1 = SOFT_ERR, bit 2 = FATAL_ERR, bits 7:3 = reserved.
  //
  // INDIRECT_STATUS / INDIRECT_DATA / INDIRECT_FIFO_* (Sec 9.2 Tbl 9-13..9-15)
  // are routed by usb_ocp_recovery_rb_adapter.sv (is_fifo_cmd, line 159)
  // to the cms_fifo A4 block.  The regblock copies of those registers are
  // never read out on the host control bus, so their .next ports are
  // intentionally left at 0; A4 owns the live values.  Driving them here
  // would be dead silicon and risk diverging from the FIFO-owned state.
  //
  // The adapter also intercepts cpuif_rd_err (rb_adapter.sv:466 only ORs
  // fifo_rb_err into rb_err), so a regblock-side decode miss cannot
  // surface as an rb_err / AXI error response.  Every regblock byte in
  // the address window is backed by a declared field per the generated
  // package (usb_ocp_recovery_reg_pkg.sv).
  // --------------------------------------------------------------------------
  always_comb begin
    rb_hwif_in = '{default: '0};

    // PROT_CAP fields are static read-only constants in the RDL (sw=r;
    // hw=na). Their read-back values come directly from the regblock reset,
    // so no hwif .next mirroring is required (RDL reset is the single source
    // of truth). See usb_ocp_recovery_reg.rdl PROT_CAP_0..3.

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

    // RECOVERY_CTRL.ACTIVATE_REC_IMG hardware-clear (OCP Recovery v1.1
    // Sec 9.2 Tbl 9-9): the recovery FSM pulses recovery_ctrl_activate_consume
    // when it consumes the activation request; hwclr zeroes the byte so a
    // subsequent host read returns 0.
    rb_hwif_in.RECOVERY_CTRL.ACTIVATE_REC_IMG.hwclr = recovery_ctrl_activate_consume;
  end

  usb_ocp_recovery_reg u_a3_regblock (
    .clk                  (clk),
    .rst                  (rst),

    .s_cpuif_req          (cpuif_req),
    .s_cpuif_req_is_wr    (cpuif_req_is_wr),
    .s_cpuif_addr         (cpuif_addr),
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

    // Async FIFO read port (dev_axi_aclk domain) -- P9-0.1-C native pop.
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
    .bytes_pushed      (bytes_pushed)
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
    .recovery_ctrl_activate_consume   (recovery_ctrl_activate_consume),
    .proto_err_rd_pulse               (proto_err_rd_pulse),

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
    end
  end
  // synopsys translate_on

endmodule
