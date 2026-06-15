// SPDX-License-Identifier: Apache-2.0
//------------------------------------------------------------------------------
// usb_ocp_recovery_top.sv  (Phase 1c)
//
// OCP Recovery v1.1 USB-transported function - integration wrapper.
//
// Phase 1c changes (vs Phase 1b):
//   - DELETED: A1 (usb_ocp_recovery_ep_adapter) - PIE byte-stream conversion
//     now lives in VHDL (usb_pie_recovery_arb.{e,m}.vhdl) so the SV top no
//     longer needs to bind the VHDL adapter.  Upper-side byte streams are
//     now driven by parent SV ports (rec_setup_pkt_*, rec_ctrl_*).
//   - DELETED: AXI4-Lite subordinate adapter + s_axil_* port group.  An AHB
//     sub-decoder now lives in the parent SV wrapper and drives the reg-bus
//     slave port group (rb_*) directly.
//   - DELETED: Bulk endpoint streams (bout_*/bin_*/bulk_*).  Per the EP0-only
//     architecture decision (Phase 1b spec correction C11), all OCP records
//     including INDIRECT_FIFO_DATA cross EP0.
//   - KEPT: Internal USB-vs-external reg-bus arbiter.  External master is
//     now the AHB sub-decoder (renamed ext_rb_*).  USB-priority semantics
//     are preserved.
//
// Instantiates:
//   A2 : usb_ocp_recovery_ctrl_decode (SV)
//   A3 : usb_ocp_recovery_rb_adapter + peakrdl-generated usb_ocp_recovery
//        (regblock from third_party/usb2/systemrdl/usb_ocp_recovery.rdl)
//   A4 : usb_ocp_recovery_cms_fifo    (SV)
//   A5 : usb_ocp_recovery_fsm         (SV)
//
// Clock / Reset:
//   Single clock `clk`, synchronous active-high `rst` (SV convention).
//------------------------------------------------------------------------------

module usb_ocp_recovery_top #(
  parameter int unsigned  CTRL_EP_NR     = 0,
  parameter int           CMS_ADDR_W     = 16,
  parameter int           NUM_CMS        = 2,
  // OCP Recovery v1.1 Section 8.5.2 RECOMMENDS interface number 0 for the
  // recovery interface.  Make it a parameter so a future SoC integrator can
  // relocate the OCP recovery interface without re-spinning RTL.  Used by
  // the SETUP class-match filter (see rec_claim assertion below).
  parameter logic [7:0]   REC_IFACE_NUM     = 8'h00,
  parameter logic [127:0] PROT_CAP_DEFAULT  = '0,
  parameter logic [191:0] DEVICE_ID_DEFAULT = '0
)(
  input  logic                    clk,
  input  logic                    rst,

  //----------------------------------------------------------------------------
  // Upper-side byte-stream surface (driven by VHDL usb_pie_recovery_arb).
  // Matches the legacy A1 adapter's upper-side contract.
  //----------------------------------------------------------------------------
  input  logic                    rec_setup_pkt_vld,
  input  logic [63:0]             rec_setup_pkt,

  input  logic [7:0]              rec_ctrl_out_data,
  input  logic                    rec_ctrl_out_vld,
  input  logic                    rec_ctrl_out_last,
  output logic                    rec_ctrl_out_rdy,

  output logic [7:0]              rec_ctrl_in_data,
  output logic                    rec_ctrl_in_vld,
  output logic                    rec_ctrl_in_last,
  input  logic                    rec_ctrl_in_rdy,

  output logic                    rec_ctrl_set_stall,
  input  logic                    rec_ctrl_xfer_done,

  // Arbiter claim flag back to VHDL: '1' while recovery owns EP0.
  output logic                    rec_ctrl_claim,

  //----------------------------------------------------------------------------
  // External register-bus slave (driven by AHB sub-decoder upstream).
  // Same byte-wide protocol as the internal A2->A3 reg-bus.
  //----------------------------------------------------------------------------
  input  logic [7:0]              ext_rb_cmd,
  input  logic [15:0]             ext_rb_offset,
  input  logic                    ext_rb_wr,
  input  logic                    ext_rb_rd,
  input  logic [7:0]              ext_rb_wdata,
  input  logic                    ext_rb_be,
  output logic [7:0]              ext_rb_rdata,
  output logic                    ext_rb_ack,
  output logic                    ext_rb_err,

  //----------------------------------------------------------------------------
  // CMS external SRAM (single-ported, byte-wide).
  //----------------------------------------------------------------------------
  output logic [CMS_ADDR_W-1:0]   cms_addr,
  output logic                    cms_wr,
  output logic                    cms_rd,
  output logic [7:0]              cms_wdata,
  input  logic [7:0]              cms_rdata,

  //----------------------------------------------------------------------------
  // Static capability inputs (tied by SoC integrator).
  //----------------------------------------------------------------------------
  input  logic [127:0]            prot_cap_in,
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

  // --- A2 (USB master) reg-bus ---
  logic [7:0]                 usb_rb_cmd;
  logic [15:0]                usb_rb_offset;
  logic                       usb_rb_wr;
  logic                       usb_rb_rd;
  logic [7:0]                 usb_rb_wdata;
  logic                       usb_rb_be;
  logic [7:0]                 usb_rb_rdata;
  logic                       usb_rb_ack;
  logic                       usb_rb_err;

  // --- Arbitrated reg-bus into A3 ---
  logic [7:0]                 rb_cmd;
  logic [15:0]                rb_offset;
  logic                       rb_wr;
  logic                       rb_rd;
  logic [7:0]                 rb_wdata;
  logic                       rb_be;
  logic [7:0]                 rb_rdata;
  logic                       rb_ack;
  logic                       rb_err;

  // --- A3 <-> A4 FIFO-routed reg-bus ---
  logic                       fifo_rb_sel;
  logic [7:0]                 fifo_rb_cmd;
  logic [15:0]                fifo_rb_offset;
  logic                       fifo_rb_wr;
  logic                       fifo_rb_rd;
  logic [7:0]                 fifo_rb_wdata;
  logic [7:0]                 fifo_rb_rdata;
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
  logic [7:0]                 current_cms;

  //////////////////////////////////////////////////////////////////////////////
  // Reg-bus arbiter: USB priority, external (AHB) preempts when USB idle.
  // 1-cycle ack window owner tracking captured in owner_q.
  //   owner_q = 2'b01 -> USB, 2'b10 -> EXT.
  //
  // EXT in-flight gating (C2/C3 robustness): once EXT is granted, hold
  // off subsequent EXT grants until its ack lands.  This makes the
  // arbiter safe against an EXT master that legitimately holds wr/rd
  // high for multiple cycles, which the new dev_axi_aclk -> pie_clk
  // CDC bridge does while it waits for the request to round-trip across
  // the clock domain.  Without this gate, a held-high wr/rd would be
  // re-issued to A3/A4 each cycle, re-firing pulse strobes
  // (recovery_ctrl_wr_q, device_reset_wr_q, ...) -- the C2/C7 class of
  // bug observed when the AHB sub-decoder held wr for two cycles.
  // USB side already pulses rb_wr per byte from ctrl_decode and is
  // intentionally NOT gated to preserve its 1-cycle ack semantics.
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
    grant_usb   = usb_req_now;
    grant_ext   = ext_req_now & ~usb_req_now & (owner_q != 2'b01)
                              & ~ext_in_flight_q;
  end

  always_comb begin
    rb_cmd    = '0;
    rb_offset = '0;
    rb_wr     = 1'b0;
    rb_rd     = 1'b0;
    rb_wdata  = '0;
    rb_be     = 1'b0;
    if (grant_usb) begin
      rb_cmd    = usb_rb_cmd;
      rb_offset = usb_rb_offset;
      rb_wr     = usb_rb_wr;
      rb_rd     = usb_rb_rd;
      rb_wdata  = usb_rb_wdata;
      rb_be     = usb_rb_be;
    end else if (grant_ext) begin
      rb_cmd    = ext_rb_cmd;
      rb_offset = ext_rb_offset;
      rb_wr     = ext_rb_wr;
      rb_rd     = ext_rb_rd;
      rb_wdata  = ext_rb_wdata;
      rb_be     = ext_rb_be;
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

  // Response demux.  USB uses 1-cycle-late ack via owner_q.  EXT uses
  // (grant_ext | owner_q==EXT) to also cover the cms_fifo same-cycle
  // combinational ack path.
  assign usb_rb_rdata = rb_rdata;
  assign usb_rb_ack   = rb_ack & (owner_q == 2'b01);
  assign usb_rb_err   = rb_err & (owner_q == 2'b01);

  assign ext_rb_rdata = rb_rdata;
  assign ext_rb_ack   = rb_ack & (grant_ext | (owner_q == 2'b10));
  assign ext_rb_err   = rb_err & (grant_ext | (owner_q == 2'b10));

  //////////////////////////////////////////////////////////////////////////////
  // EP0 claim flag for the VHDL PIE arbiter.
  //
  // OCP Recovery v1.1 Section 8.5.1 "Class-specific control transfer" defines
  // the SETUP-packet encoding the host uses to address the OCP recovery
  // interface:
  //   bmRequestType[6:5] == 2'b01     (Class)
  //   bmRequestType[4:0] == 5'b00001  (Interface recipient)
  //   bRequest           == 8'h00     (OCP_RECOVERY_TRANSFER)
  //   wIndex[7:0]        == REC_IFACE_NUM (this build's recovery iface)
  // bmRequestType[7] (direction), wValue (cmd code / byte index), and wLength
  // are downstream-parser fields and do NOT participate in the claim filter.
  //
  // Filtering at claim assertion ensures non-OCP EP0 SETUPs (standard USB
  // enumeration: GET_DESCRIPTOR, SET_ADDRESS, SET_CONFIGURATION, ...) keep
  // flowing through the VHDL arbiter to the legacy usb_pie unmodified
  // (arb_owns_c stays low; pass-through mux is bit-identical to un-arbitered).
  //
  // setup_pkt[ 7: 0] = byte0 = bmRequestType
  // setup_pkt[15: 8] = byte1 = bRequest
  // setup_pkt[31:16] = bytes 2..3 = wValue (LE)
  // setup_pkt[47:32] = bytes 4..5 = wIndex (LE)
  // setup_pkt[63:48] = bytes 6..7 = wLength (LE)
  //////////////////////////////////////////////////////////////////////////////
  logic       setup_is_ocp_c;
  logic [7:0] setup_bmrt_c;
  logic [7:0] setup_brq_c;
  logic [7:0] setup_widx_lo_c;
  logic [7:0] setup_widx_hi_c;

  // OCP Recovery v1.1 Section 8.5.1 / USB 2.0 Section 9.3: wIndex[15:8] is
  // reserved (host MUST drive 0).  Reject non-conformant SETUPs at the
  // claim filter (C5: prevents yanking EP0 away from the legacy stack on
  // the basis of a partial match).
  always_comb begin
    setup_bmrt_c    = rec_setup_pkt[7:0];
    setup_brq_c     = rec_setup_pkt[15:8];
    setup_widx_lo_c = rec_setup_pkt[39:32];
    setup_widx_hi_c = rec_setup_pkt[47:40];
    setup_is_ocp_c  = (setup_bmrt_c[6:5] == 2'b01) &&
                      (setup_bmrt_c[4:0] == 5'b00001) &&
                      (setup_brq_c       == 8'h00)   &&
                      (setup_widx_lo_c   == REC_IFACE_NUM) &&
                      (setup_widx_hi_c   == 8'h00);
  end

  logic rec_claim_q;
  logic setup_pkt_vld_filtered;

  // Only the SETUPs that match the OCP class filter are surfaced into the
  // recovery decoder.  Non-matching SETUPs still reach the VHDL arbiter
  // (and thus the legacy stack) untouched because the arbiter's SETUP
  // capture is independent of rec_claim.
  assign setup_pkt_vld_filtered = rec_setup_pkt_vld & setup_is_ocp_c;

  always_ff @(posedge clk) begin
    if (rst) begin
      rec_claim_q <= 1'b0;
    end else if (setup_pkt_vld_filtered) begin
      rec_claim_q <= 1'b1;
    end else if (rec_ctrl_xfer_done | rec_ctrl_set_stall) begin
      rec_claim_q <= 1'b0;
    end
  end
  // C6: rec_ctrl_claim must be purely registered to avoid a same-cycle
  // combinational path from rec_setup_pkt[*] through the SETUP-class
  // filter back into the VHDL arbiter mux.  The 1-cycle claim latency
  // is absorbed by USB tFRH between SETUP and the first data-phase
  // packet (USB 2.0 Section 7.1.18.1 / 8.7.2).
  assign rec_ctrl_claim = rec_claim_q;

  //////////////////////////////////////////////////////////////////////////////
  // A2 : USB control-endpoint request decoder -> reg-bus master
  //////////////////////////////////////////////////////////////////////////////

  usb_ocp_recovery_ctrl_decode u_a2_ctrl_decode (
    .clk             (clk),
    .rst             (rst),

    .setup_pkt_vld   (setup_pkt_vld_filtered),
    .setup_pkt       (rec_setup_pkt),
    .ctrl_out_data   (rec_ctrl_out_data),
    .ctrl_out_vld    (rec_ctrl_out_vld),
    .ctrl_out_last   (rec_ctrl_out_last),
    .ctrl_out_rdy    (rec_ctrl_out_rdy),
    .ctrl_in_data    (rec_ctrl_in_data),
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
    .rb_be           (usb_rb_be),
    .rb_rdata        (usb_rb_rdata),
    .rb_ack          (usb_rb_ack),
    .rb_err          (usb_rb_err)
  );

  //////////////////////////////////////////////////////////////////////////////
  // A3 : byte-wide reg-bus adapter + peakrdl-generated regblock
  //
  // The adapter (usb_ocp_recovery_rb_adapter) translates the byte-granular
  // rb_* protocol into the regblock's 32-bit passthrough CPU interface and
  // owns the FSM-facing sideband contract (DEVICE_RESET / RECOVERY_CTRL
  // latches, HW_STATUS write pulse, PROTOCOL_ERROR rclr pulse, FIFO branch
  // routing).  The regblock (usb_ocp_recovery) is generated by peakrdl
  // from third_party/usb2/systemrdl/usb_ocp_recovery.rdl and is the single
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
  usb_ocp_recovery_pkg::usb_ocp_recovery__in_t  rb_hwif_in;
  usb_ocp_recovery_pkg::usb_ocp_recovery__out_t rb_hwif_out;

  usb_ocp_recovery_rb_adapter u_a3_adapter (
    .clk             (clk),
    .rst             (rst),

    .rb_cmd          (rb_cmd),
    .rb_offset       (rb_offset),
    .rb_wr           (rb_wr),
    .rb_rd           (rb_rd),
    .rb_wdata        (rb_wdata),
    .rb_be           (rb_be),
    .rb_rdata        (rb_rdata),
    .rb_ack          (rb_ack),
    .rb_err          (rb_err),

    .fifo_rb_sel     (fifo_rb_sel),
    .fifo_rb_cmd     (fifo_rb_cmd),
    .fifo_rb_offset  (fifo_rb_offset),
    .fifo_rb_wr      (fifo_rb_wr),
    .fifo_rb_rd      (fifo_rb_rd),
    .fifo_rb_wdata   (fifo_rb_wdata),
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
    .hw_status_wr                     (hw_status_wr),
    .hw_status_wdata                  (hw_status_wdata),
    .proto_err_rd_pulse               (proto_err_rd_pulse)
  );

  // --------------------------------------------------------------------------
  // hwif_in wiring.
  //
  // PROT_CAP (16 B) and DEVICE_ID (24 B) are fed from the SoC integrator
  // ties (prot_cap_in / device_id_in).  The .next inputs are sampled
  // continuously by hw=w / we=false fields, so they appear in the host
  // read window with no extra storage cycle.
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
  // package (usb_ocp_recovery_pkg.sv).
  // --------------------------------------------------------------------------
  always_comb begin
    rb_hwif_in = '{default: '0};

    // PROT_CAP: 4 DWORDs from prot_cap_in[127:0].
    rb_hwif_in.PROT_CAP_0.REC_MAGIC_STRING_0.next = prot_cap_in[31:0];
    rb_hwif_in.PROT_CAP_1.REC_MAGIC_STRING_1.next = prot_cap_in[63:32];
    rb_hwif_in.PROT_CAP_2.REC_PROT_VERSION.next   = prot_cap_in[79:64];
    rb_hwif_in.PROT_CAP_2.AGENT_CAPS.next         = prot_cap_in[95:80];
    rb_hwif_in.PROT_CAP_3.NUM_OF_CMS_REGIONS.next = prot_cap_in[103:96];
    rb_hwif_in.PROT_CAP_3.MAX_RESP_TIME.next      = prot_cap_in[111:104];
    rb_hwif_in.PROT_CAP_3.HEARTBEAT_PERIOD.next   = prot_cap_in[119:112];
    rb_hwif_in.PROT_CAP_3.RESERVED_31_24.next     = prot_cap_in[127:120];

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
  end

  usb_ocp_recovery u_a3_regblock (
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
    .NUM_CMS    (NUM_CMS)
  ) u_a4_cms_fifo (
    .clk             (clk),
    .rst             (rst),

    .fifo_rb_sel     (fifo_rb_sel),
    .fifo_rb_cmd     (fifo_rb_cmd),
    .fifo_rb_offset  (fifo_rb_offset),
    .fifo_rb_wr      (fifo_rb_wr),
    .fifo_rb_rd      (fifo_rb_rd),
    .fifo_rb_wdata   (fifo_rb_wdata),
    .fifo_rb_rdata   (fifo_rb_rdata),
    .fifo_rb_ack     (fifo_rb_ack),
    .fifo_rb_err     (fifo_rb_err),

    .image_push_active (image_push_active),
    .image_push_done   (image_push_done),
    .fifo_overflow     (fifo_overflow),
    .image_size        (image_size),
    .bytes_pushed      (bytes_pushed),
    .current_cms       (current_cms),

    .cms_addr        (cms_addr),
    .cms_wr          (cms_wr),
    .cms_rd          (cms_rd),
    .cms_wdata       (cms_wdata),
    .cms_rdata       (cms_rdata)
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
