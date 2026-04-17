// SPDX-License-Identifier: Apache-2.0
//------------------------------------------------------------------------------
// usb_ocp_recovery_top.sv
//
// OCP Recovery v1.1 USB-transported function - integration wrapper.
//
// Instantiates:
//   A1 : usb_ocp_recovery_ep_adapter  (VHDL, src/ip_xxx_3516_hs_mem/RTL)
//   A2 : usb_ocp_recovery_ctrl_decode (SV)
//   A3 : usb_ocp_recovery_regs        (SV)
//   A4 : usb_ocp_recovery_cms_fifo    (SV)
//   A5 : usb_ocp_recovery_fsm         (SV)
//
// Responsibilities (per plan.md, A6 brief):
//   1. Expose PIE-side ports of A1 straight through to the integration level
//      (A7) - no reformatting here.
//   2. Multiplex the internal byte-wide reg-bus between the USB control
//      decoder (A2) and an AXI4-Lite management subordinate.
//        - USB is the default / high-priority master.
//        - AXI4-Lite preempts only when USB has no request in flight.
//   3. Provide a standard AXI4-Lite subordinate suitable for SoC host debug
//      / override (flat signal convention).
//   4. Route static PROT_CAP and DEVICE_ID inputs into the register block.
//      Parameters provide spec-sensible defaults; a higher-level wrapper
//      (A7) is expected to tie `prot_cap_in` / `device_id_in` to the SoC
//      straps, optionally using these parameters.
//   5. Expose the CMS external single-ported SRAM port from A4 and the
//      recovery sideband (`recovery_active`, `image_ready`, `boot_req`,
//      `device_reset_req`, `fatal_err`) plus `rec_trigger` / `soc_boot_ack`.
//
// Clock / Reset convention:
//   - Single clock `clk`.
//   - Top-level reset is synchronous, active-high `rst` (SV convention).
//   - The VHDL A1 adapter uses asynchronous, active-low `reset_n` (VHDL
//     project convention). This file converts by `reset_n = ~rst` and
//     documents the boundary at the A1 instantiation site.
//------------------------------------------------------------------------------

module usb_ocp_recovery_top #(
  //----------------------------------------------------------------------------
  // Endpoint numbers for the adapter (passed to the VHDL A1 entity).
  //----------------------------------------------------------------------------
  parameter int unsigned  CTRL_EP_NR     = 0,
  parameter int unsigned  BULK_OUT_EP_NR = 1,
  parameter int unsigned  BULK_IN_EP_NR  = 1,

  //----------------------------------------------------------------------------
  // CMS backing RAM sizing.
  //----------------------------------------------------------------------------
  parameter int           CMS_ADDR_W     = 16,
  parameter int           NUM_CMS        = 2,

  //----------------------------------------------------------------------------
  // Static capability defaults (OCP Recovery v1.1, Sec 9.2 Tbl 9-3 / 9-4).
  //
  // PROT_CAP (0x22, 16 bytes) - recommended minimum identification:
  //   byte[0..2]    = ASCII 'O','C','P'  (Magic ID per Sec 9.2 Tbl 9-3)
  //   byte[3]       = 0x04  (Protocol Major.Minor nibble = 1.1 encoded as 0x11
  //                          -> we use 0x11 here; any SoC override is welcome)
  //   byte[4]       = 0x01  (PROT_CAP.agent_capability bit0 = Identification)
  //   byte[5..13]   = 0x00  (capability bits reserved/agent-specific)
  //   byte[14..15]  = max request/response size = 0x00 (use default 256)
  //
  // DEVICE_ID (0x23, 24 bytes) - mostly zeros; SoC drives real values.
  //
  // These are *defaults*; A7 wires `prot_cap_in` / `device_id_in` to the
  // real SoC source and MAY use these parameter values directly.
  //
  // Cited values are the minimum to identify as an OCP Recovery device on
  // the bus; they are not security-relevant and must be replaced at SoC
  // integration time.
  //----------------------------------------------------------------------------
  parameter logic [127:0] PROT_CAP_DEFAULT  =
      { 16'h0000,   // byte[15:14] max request size  (default 0 => 256)
        8'h00,      // byte[13]    reserved
        8'h00,      // byte[12]    reserved
        8'h00,      // byte[11]    reserved
        8'h00,      // byte[10]    reserved
        8'h00,      // byte[9]     reserved
        8'h00,      // byte[8]     reserved
        8'h00,      // byte[7]     reserved
        8'h00,      // byte[6]     reserved
        8'h00,      // byte[5]     reserved
        8'h01,      // byte[4]     agent_capability = Identification
        8'h11,      // byte[3]     protocol version (major.minor nibbles 1.1)
        8'h50,      // byte[2]     'P'
        8'h43,      // byte[1]     'C'
        8'h4F },    // byte[0]     'O'
  parameter logic [191:0] DEVICE_ID_DEFAULT = 192'h0,

  //----------------------------------------------------------------------------
  // AXI4-Lite subordinate geometry.
  //----------------------------------------------------------------------------
  parameter int unsigned  AXIL_AW = 32,
  parameter int unsigned  AXIL_DW = 32
)(
  //----------------------------------------------------------------------------
  // Clock and synchronous active-high reset (SV convention).
  //----------------------------------------------------------------------------
  input  logic                    clk,
  input  logic                    rst,

  //----------------------------------------------------------------------------
  // PIE-facing ports. These map 1:1 to A1's lower-side (pie_*) ports and are
  // connected straight through at A7 to `usb_pie` / `usb_dma` selection logic.
  //----------------------------------------------------------------------------
  input  logic                    pie_setup_received,
  input  logic [63:0]             pie_setup_data,

  input  logic                    pie_ctrl_out_req,
  input  logic [7:0]              pie_ctrl_out_byte,
  input  logic                    pie_ctrl_out_last,
  output logic                    pie_ctrl_out_ack,
  output logic                    pie_ctrl_out_nak,

  output logic                    pie_ctrl_in_req,
  output logic [7:0]              pie_ctrl_in_byte,
  output logic                    pie_ctrl_in_last,
  input  logic                    pie_ctrl_in_ack,

  output logic                    pie_ctrl_stall,
  input  logic                    pie_ctrl_xfer_done,

  input  logic                    pie_bout_req,
  input  logic [7:0]              pie_bout_byte,
  input  logic                    pie_bout_last,
  output logic                    pie_bout_ack,
  output logic                    pie_bout_nak,

  output logic                    pie_bin_req,
  output logic [7:0]              pie_bin_byte,
  output logic                    pie_bin_last,
  input  logic                    pie_bin_ack,

  output logic                    pie_bulk_stall,
  input  logic                    pie_bulk_xfer_done,

  //----------------------------------------------------------------------------
  // AXI4-Lite subordinate (flat signal convention; 32-bit data / 32-bit addr
  // by default). See the Address Map section of interface_report_A6.md for
  // the register layout within the recovery region.
  //----------------------------------------------------------------------------
  input  logic [AXIL_AW-1:0]      s_axil_awaddr,
  input  logic [2:0]              s_axil_awprot,
  input  logic                    s_axil_awvalid,
  output logic                    s_axil_awready,

  input  logic [AXIL_DW-1:0]      s_axil_wdata,
  input  logic [AXIL_DW/8-1:0]    s_axil_wstrb,
  input  logic                    s_axil_wvalid,
  output logic                    s_axil_wready,

  output logic [1:0]              s_axil_bresp,
  output logic                    s_axil_bvalid,
  input  logic                    s_axil_bready,

  input  logic [AXIL_AW-1:0]      s_axil_araddr,
  input  logic [2:0]              s_axil_arprot,
  input  logic                    s_axil_arvalid,
  output logic                    s_axil_arready,

  output logic [AXIL_DW-1:0]      s_axil_rdata,
  output logic [1:0]              s_axil_rresp,
  output logic                    s_axil_rvalid,
  input  logic                    s_axil_rready,

  //----------------------------------------------------------------------------
  // CMS external SRAM (single-ported, byte-wide). Routed straight from A4.
  //----------------------------------------------------------------------------
  output logic [CMS_ADDR_W-1:0]   cms_addr,
  output logic                    cms_wr,
  output logic                    cms_rd,
  output logic [7:0]              cms_wdata,
  input  logic [7:0]              cms_rdata,

  //----------------------------------------------------------------------------
  // Static capability inputs (tied by A7 / SoC). Hook through to A3.
  //----------------------------------------------------------------------------
  input  logic [127:0]            prot_cap_in,
  input  logic [191:0]            device_id_in,

  //----------------------------------------------------------------------------
  // SoC trigger / ack and recovery sideband (observability).
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
  // Parameter sanity
  //////////////////////////////////////////////////////////////////////////////

  // synopsys translate_off
  initial begin
    if (AXIL_DW != 32) begin
      $error("usb_ocp_recovery_top: AXIL_DW must be 32 (got %0d)", AXIL_DW);
    end
    if (AXIL_AW < 24) begin
      $error("usb_ocp_recovery_top: AXIL_AW must be >= 24 for reg map");
    end
  end
  // synopsys translate_on

  //////////////////////////////////////////////////////////////////////////////
  // VHDL<->SV boundary: generate async-active-low reset for A1 from the
  // sync-active-high `rst` used by the SV layer. This is a pure combinational
  // inversion; the asynchronous deassertion edge comes from whatever drives
  // `rst` at the SoC level (A7 is expected to gate `rst` off the SoC reset
  // synchroniser that already feeds the USB IP).
  //////////////////////////////////////////////////////////////////////////////

  logic                       a1_reset_n;
  assign a1_reset_n = ~rst;

  //////////////////////////////////////////////////////////////////////////////
  // Internal wiring
  //////////////////////////////////////////////////////////////////////////////

  // --- A1 upper-side (byte streams) -> A2 / A4 ---
  logic                       setup_pkt_vld;
  logic [63:0]                setup_pkt;

  logic [7:0]                 ctrl_out_data;
  logic                       ctrl_out_vld;
  logic                       ctrl_out_last;
  logic                       ctrl_out_rdy;

  logic [7:0]                 ctrl_in_data;
  logic                       ctrl_in_vld;
  logic                       ctrl_in_last;
  logic                       ctrl_in_rdy;

  logic                       ctrl_set_stall;
  logic                       ctrl_xfer_done;

  logic [7:0]                 bout_data;
  logic                       bout_vld;
  logic                       bout_last;
  logic                       bout_rdy;

  logic [7:0]                 bin_data;
  logic                       bin_vld;
  logic                       bin_last;
  logic                       bin_rdy;

  logic                       bulk_set_stall;
  logic                       bulk_xfer_done;

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

  // --- AXI4-Lite (AXIL master) reg-bus ---
  logic [7:0]                 axil_rb_cmd;
  logic [15:0]                axil_rb_offset;
  logic                       axil_rb_wr;
  logic                       axil_rb_rd;
  logic [7:0]                 axil_rb_wdata;
  logic                       axil_rb_be;
  logic [7:0]                 axil_rb_rdata;
  logic                       axil_rb_ack;
  logic                       axil_rb_err;

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
  logic [7:0]                 recovery_ctrl_cms;
  logic [7:0]                 recovery_ctrl_img_sel;
  logic [7:0]                 recovery_ctrl_activate;
  logic                       hw_status_wr;
  logic [7:0]                 hw_status_wdata;

  logic [7:0]                 device_status_out;
  logic [7:0]                 device_status_protocol_err_out;
  logic [7:0]                 device_status_reason_out;
  logic [7:0]                 recovery_status_out;
  logic [7:0]                 recovery_vendor_status_out;
  logic [7:0]                 hw_status_out;

  // --- A4 <-> A5 ---
  logic                       image_push_active;
  logic                       image_push_done;
  logic                       fifo_overflow;
  logic [31:0]                image_size;
  logic [31:0]                bytes_pushed;
  logic [7:0]                 current_cms;

  //////////////////////////////////////////////////////////////////////////////
  // Reg-bus arbiter: USB-priority, AXI preempts only when USB is idle.
  //
  // Request-phase grant is combinational. Because the reg-bus ACK is defined
  // to arrive exactly one cycle after the request (A2/A3 contract), the
  // owner of the in-flight response is captured into `owner_q` so `rb_ack`
  // / `rb_rdata` / `rb_err` are routed back to the correct master on the
  // next cycle. Owner 2'b01 = USB, 2'b10 = AXIL, 2'b00 = none.
  //////////////////////////////////////////////////////////////////////////////

  logic [1:0] owner_q;
  logic       usb_req_now;
  logic       axil_req_now;
  logic       grant_usb;
  logic       grant_axil;

  always_comb begin
    usb_req_now  = usb_rb_wr  | usb_rb_rd;
    axil_req_now = axil_rb_wr | axil_rb_rd;

    // USB is always granted when it asks. AXIL is granted only when USB is
    // idle AND no response is outstanding for USB (ensures the reg-bus isn't
    // double-booked within the fixed 1-cycle ack window).
    grant_usb  = usb_req_now;
    grant_axil = axil_req_now & ~usb_req_now & (owner_q != 2'b01);
  end

  always_comb begin
    // Default: no request.
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
    end else if (grant_axil) begin
      rb_cmd    = axil_rb_cmd;
      rb_offset = axil_rb_offset;
      rb_wr     = axil_rb_wr;
      rb_rd     = axil_rb_rd;
      rb_wdata  = axil_rb_wdata;
      rb_be     = axil_rb_be;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      owner_q <= 2'b00;
    end else begin
      if (grant_usb) begin
        owner_q <= 2'b01;
      end else if (grant_axil) begin
        owner_q <= 2'b10;
      end else begin
        owner_q <= 2'b00;
      end
    end
  end

  // Response-phase demux: ack/rdata/err routed to the owner captured on
  // the cycle the request was granted.
  assign usb_rb_rdata  = rb_rdata;
  assign usb_rb_ack    = rb_ack & (owner_q == 2'b01);
  assign usb_rb_err    = rb_err & (owner_q == 2'b01);

  assign axil_rb_rdata = rb_rdata;
  assign axil_rb_ack   = rb_ack & (owner_q == 2'b10);
  assign axil_rb_err   = rb_err & (owner_q == 2'b10);

  //////////////////////////////////////////////////////////////////////////////
  // AXI4-Lite subordinate adapter to reg-bus.
  //
  // Address layout (see interface_report_A6):
  //   axil_addr[23:16] = OCP command code (rb_cmd; 0x22..0x2F valid)
  //   axil_addr[15: 0] = byte offset within command payload (rb_offset)
  //   axil_addr[AW-1:24] = ignored at this level; A7 / SoC interconnect
  //                        handles base-address decoding.
  // Data layout:
  //   axil_wdata[7:0]  carries the reg-bus write byte.
  //   Upper bytes of wdata are ignored (reg-bus is byte-wide).
  //   wstrb[0] must be 1 for a write to commit.
  //   rdata returns {24'h0, rb_rdata} (byte in LSB; upper bytes zeroed).
  // Error mapping:
  //   rb_err -> BRESP/RRESP = SLVERR (2'b10); else OKAY (2'b00).
  //////////////////////////////////////////////////////////////////////////////

  typedef enum logic [1:0] {
    AXIL_IDLE,
    AXIL_REQ,
    AXIL_RESP
  } axil_state_e;

  axil_state_e               wr_state_q;
  axil_state_e               rd_state_q;

  logic [AXIL_AW-1:0]        aw_addr_q;
  logic [7:0]                wdata_byte_q;
  logic                      wstrb0_q;
  logic                      bresp_err_q;

  logic [AXIL_AW-1:0]        ar_addr_q;
  logic [7:0]                rdata_byte_q;
  logic                      rresp_err_q;

  // ---- Write path ----
  always_ff @(posedge clk) begin
    if (rst) begin
      wr_state_q    <= AXIL_IDLE;
      aw_addr_q     <= '0;
      wdata_byte_q  <= '0;
      wstrb0_q      <= 1'b0;
      bresp_err_q   <= 1'b0;
    end else begin
      unique case (wr_state_q)
        AXIL_IDLE: begin
          if (s_axil_awvalid && s_axil_awready &&
              s_axil_wvalid  && s_axil_wready) begin
            aw_addr_q    <= s_axil_awaddr;
            wdata_byte_q <= s_axil_wdata[7:0];
            wstrb0_q     <= s_axil_wstrb[0];
            wr_state_q   <= AXIL_REQ;
          end
        end
        AXIL_REQ: begin
          // Request held until arbiter ack; see combinational driver below.
          if (axil_rb_ack || axil_rb_err) begin
            bresp_err_q <= axil_rb_err | ~wstrb0_q;
            wr_state_q  <= AXIL_RESP;
          end
        end
        AXIL_RESP: begin
          if (s_axil_bvalid && s_axil_bready) begin
            wr_state_q <= AXIL_IDLE;
          end
        end
        default: wr_state_q <= AXIL_IDLE;
      endcase
    end
  end

  // AW/W handshake: accept both together so WDATA is captured with address.
  assign s_axil_awready = (wr_state_q == AXIL_IDLE) &&
                          s_axil_awvalid && s_axil_wvalid;
  assign s_axil_wready  = s_axil_awready;

  assign s_axil_bvalid  = (wr_state_q == AXIL_RESP);
  assign s_axil_bresp   = bresp_err_q ? 2'b10 : 2'b00;

  // ---- Read path ----
  always_ff @(posedge clk) begin
    if (rst) begin
      rd_state_q   <= AXIL_IDLE;
      ar_addr_q    <= '0;
      rdata_byte_q <= '0;
      rresp_err_q  <= 1'b0;
    end else begin
      unique case (rd_state_q)
        AXIL_IDLE: begin
          if (s_axil_arvalid && s_axil_arready) begin
            ar_addr_q  <= s_axil_araddr;
            rd_state_q <= AXIL_REQ;
          end
        end
        AXIL_REQ: begin
          if (axil_rb_ack || axil_rb_err) begin
            rdata_byte_q <= axil_rb_rdata;
            rresp_err_q  <= axil_rb_err;
            rd_state_q   <= AXIL_RESP;
          end
        end
        AXIL_RESP: begin
          if (s_axil_rvalid && s_axil_rready) begin
            rd_state_q <= AXIL_IDLE;
          end
        end
        default: rd_state_q <= AXIL_IDLE;
      endcase
    end
  end

  assign s_axil_arready = (rd_state_q == AXIL_IDLE);
  assign s_axil_rvalid  = (rd_state_q == AXIL_RESP);
  assign s_axil_rdata   = {{(AXIL_DW-8){1'b0}}, rdata_byte_q};
  assign s_axil_rresp   = rresp_err_q ? 2'b10 : 2'b00;

  // ---- AXIL -> reg-bus request wires ----
  // Hold the request until the arbiter grants and ACKs (owner demux gates
  // axil_rb_ack). This cleanly interoperates with USB priority.
  always_comb begin
    axil_rb_cmd    = '0;
    axil_rb_offset = '0;
    axil_rb_wr     = 1'b0;
    axil_rb_rd     = 1'b0;
    axil_rb_wdata  = '0;
    axil_rb_be     = 1'b0;

    if (wr_state_q == AXIL_REQ) begin
      axil_rb_cmd    = aw_addr_q[23:16];
      axil_rb_offset = aw_addr_q[15:0];
      axil_rb_wr     = wstrb0_q;           // drop commit if byte-strobe is 0
      axil_rb_wdata  = wdata_byte_q;
      axil_rb_be     = wstrb0_q;
    end else if (rd_state_q == AXIL_REQ) begin
      axil_rb_cmd    = ar_addr_q[23:16];
      axil_rb_offset = ar_addr_q[15:0];
      axil_rb_rd     = 1'b1;
      axil_rb_be     = 1'b1;
    end
  end

  //////////////////////////////////////////////////////////////////////////////
  // A1 : VHDL endpoint adapter
  //
  // Language boundary notice:
  //   `usb_ocp_recovery_ep_adapter` is implemented in VHDL (see
  //   src/ip_xxx_3516_hs_mem/RTL/usb_ocp_recovery_ep_adapter.{e,m}.vhdl).
  //   Mixed-language elaboration maps VHDL std_logic <-> SV logic and
  //   std_logic_vector(N downto 0) <-> SV logic [N:0]. The port map below
  //   must match the entity declaration byte-for-byte and name-for-name.
  //
  //   Reset polarity / timing: the entity uses an ASYNCHRONOUS ACTIVE-LOW
  //   reset (`reset_n`). This wrapper uses SYNCHRONOUS ACTIVE-HIGH (`rst`).
  //   The inversion is `a1_reset_n = ~rst`; the synchronous deassertion
  //   happens at the SoC reset synchroniser upstream.
  //////////////////////////////////////////////////////////////////////////////

  usb_ocp_recovery_ep_adapter #(
    .C_CTRL_EP_NR     (CTRL_EP_NR),
    .C_BULK_OUT_EP_NR (BULK_OUT_EP_NR),
    .C_BULK_IN_EP_NR  (BULK_IN_EP_NR)
  ) u_a1_ep_adapter (
    .clk                 (clk),
    .reset_n             (a1_reset_n),

    // PIE side (straight through to this wrapper's ports)
    .pie_setup_received  (pie_setup_received),
    .pie_setup_data      (pie_setup_data),
    .pie_ctrl_out_req    (pie_ctrl_out_req),
    .pie_ctrl_out_byte   (pie_ctrl_out_byte),
    .pie_ctrl_out_last   (pie_ctrl_out_last),
    .pie_ctrl_out_ack    (pie_ctrl_out_ack),
    .pie_ctrl_out_nak    (pie_ctrl_out_nak),
    .pie_ctrl_in_req     (pie_ctrl_in_req),
    .pie_ctrl_in_byte    (pie_ctrl_in_byte),
    .pie_ctrl_in_last    (pie_ctrl_in_last),
    .pie_ctrl_in_ack     (pie_ctrl_in_ack),
    .pie_ctrl_stall      (pie_ctrl_stall),
    .pie_ctrl_xfer_done  (pie_ctrl_xfer_done),
    .pie_bout_req        (pie_bout_req),
    .pie_bout_byte       (pie_bout_byte),
    .pie_bout_last       (pie_bout_last),
    .pie_bout_ack        (pie_bout_ack),
    .pie_bout_nak        (pie_bout_nak),
    .pie_bin_req         (pie_bin_req),
    .pie_bin_byte        (pie_bin_byte),
    .pie_bin_last        (pie_bin_last),
    .pie_bin_ack         (pie_bin_ack),
    .pie_bulk_stall      (pie_bulk_stall),
    .pie_bulk_xfer_done  (pie_bulk_xfer_done),

    // Upper side -> SV modules
    .setup_pkt_vld       (setup_pkt_vld),
    .setup_pkt           (setup_pkt),
    .ctrl_out_data       (ctrl_out_data),
    .ctrl_out_vld        (ctrl_out_vld),
    .ctrl_out_last       (ctrl_out_last),
    .ctrl_out_rdy        (ctrl_out_rdy),
    .ctrl_in_data        (ctrl_in_data),
    .ctrl_in_vld         (ctrl_in_vld),
    .ctrl_in_last        (ctrl_in_last),
    .ctrl_in_rdy         (ctrl_in_rdy),
    .ctrl_set_stall      (ctrl_set_stall),
    .ctrl_xfer_done      (ctrl_xfer_done),
    .bout_data           (bout_data),
    .bout_vld            (bout_vld),
    .bout_last           (bout_last),
    .bout_rdy            (bout_rdy),
    .bin_data            (bin_data),
    .bin_vld             (bin_vld),
    .bin_last            (bin_last),
    .bin_rdy             (bin_rdy),
    .bulk_set_stall      (bulk_set_stall),
    .bulk_xfer_done      (bulk_xfer_done)
  );

  // Bulk STALL request: unused for OCP Recovery bulk OUT/IN today.
  // (FIFO errors are reported via reg-bus reads of INDIRECT_FIFO_STATUS
  // per Sec 8.2 / 9.2, not via bulk endpoint halt.)
  assign bulk_set_stall = 1'b0;

  //////////////////////////////////////////////////////////////////////////////
  // A2 : USB control-endpoint request decoder -> reg-bus master
  //////////////////////////////////////////////////////////////////////////////

  usb_ocp_recovery_ctrl_decode u_a2_ctrl_decode (
    .clk             (clk),
    .rst             (rst),

    // A1 control EP streams
    .setup_pkt_vld   (setup_pkt_vld),
    .setup_pkt       (setup_pkt),
    .ctrl_out_data   (ctrl_out_data),
    .ctrl_out_vld    (ctrl_out_vld),
    .ctrl_out_last   (ctrl_out_last),
    .ctrl_out_rdy    (ctrl_out_rdy),
    .ctrl_in_data    (ctrl_in_data),
    .ctrl_in_vld     (ctrl_in_vld),
    .ctrl_in_last    (ctrl_in_last),
    .ctrl_in_rdy     (ctrl_in_rdy),
    .ctrl_set_stall  (ctrl_set_stall),
    .ctrl_xfer_done  (ctrl_xfer_done),

    // Reg-bus master (USB side of the arbiter)
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
  // A3 : register block
  //////////////////////////////////////////////////////////////////////////////

  usb_ocp_recovery_regs u_a3_regs (
    .clk             (clk),
    .rst             (rst),

    // Arbitrated reg-bus
    .rb_cmd          (rb_cmd),
    .rb_offset       (rb_offset),
    .rb_wr           (rb_wr),
    .rb_rd           (rb_rd),
    .rb_wdata        (rb_wdata),
    .rb_be           (rb_be),
    .rb_rdata        (rb_rdata),
    .rb_ack          (rb_ack),
    .rb_err          (rb_err),

    // FIFO sub-reg-bus to A4
    .fifo_rb_sel     (fifo_rb_sel),
    .fifo_rb_cmd     (fifo_rb_cmd),
    .fifo_rb_offset  (fifo_rb_offset),
    .fifo_rb_wr      (fifo_rb_wr),
    .fifo_rb_rd      (fifo_rb_rd),
    .fifo_rb_wdata   (fifo_rb_wdata),
    .fifo_rb_rdata   (fifo_rb_rdata),
    .fifo_rb_ack     (fifo_rb_ack),
    .fifo_rb_err     (fifo_rb_err),

    // Sideband to A5 (writes)
    .device_reset_wr         (device_reset_wr),
    .device_reset_ctrl       (device_reset_ctrl),
    .device_reset_forced     (device_reset_forced),
    .device_reset_iface      (device_reset_iface),
    .recovery_ctrl_wr        (recovery_ctrl_wr),
    .recovery_ctrl_cms       (recovery_ctrl_cms),
    .recovery_ctrl_img_sel   (recovery_ctrl_img_sel),
    .recovery_ctrl_activate  (recovery_ctrl_activate),
    .hw_status_wr            (hw_status_wr),
    .hw_status_wdata         (hw_status_wdata),

    // Sideband from A5 (read-back)
    .device_status_in               (device_status_out),
    .device_status_protocol_err_in  (device_status_protocol_err_out),
    .device_status_reason_in        (device_status_reason_out),
    .recovery_status_in             (recovery_status_out),
    .recovery_vendor_status_in      (recovery_vendor_status_out),
    .hw_status_in                   (hw_status_out),

    // Static capability inputs
    .prot_cap_in     (prot_cap_in),
    .device_id_in    (device_id_in)
  );

  //////////////////////////////////////////////////////////////////////////////
  // A4 : CMS indirect-memory FIFO + window
  //////////////////////////////////////////////////////////////////////////////

  usb_ocp_recovery_cms_fifo #(
    .CMS_ADDR_W (CMS_ADDR_W),
    .NUM_CMS    (NUM_CMS)
  ) u_a4_cms_fifo (
    .clk             (clk),
    .rst             (rst),

    // FIFO sub-reg-bus from A3
    .fifo_rb_sel     (fifo_rb_sel),
    .fifo_rb_cmd     (fifo_rb_cmd),
    .fifo_rb_offset  (fifo_rb_offset),
    .fifo_rb_wr      (fifo_rb_wr),
    .fifo_rb_rd      (fifo_rb_rd),
    .fifo_rb_wdata   (fifo_rb_wdata),
    .fifo_rb_rdata   (fifo_rb_rdata),
    .fifo_rb_ack     (fifo_rb_ack),
    .fifo_rb_err     (fifo_rb_err),

    // Bulk OUT stream from A1
    .bout_data       (bout_data),
    .bout_vld        (bout_vld),
    .bout_last       (bout_last),
    .bout_rdy        (bout_rdy),

    // Bulk IN stream to A1 (reserved pop mirror; A4 holds vld low)
    .bin_data        (bin_data),
    .bin_vld         (bin_vld),
    .bin_last        (bin_last),
    .bin_rdy         (bin_rdy),

    // Status to A5
    .image_push_active (image_push_active),
    .image_push_done   (image_push_done),
    .fifo_overflow     (fifo_overflow),
    .image_size        (image_size),
    .bytes_pushed      (bytes_pushed),
    .current_cms       (current_cms),

    // External backing SRAM port (exposed at this wrapper)
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

    // Platform triggers
    .rec_trigger     (rec_trigger),
    .soc_boot_ack    (soc_boot_ack),

    // From A3 control-field strobes
    .device_reset_wr         (device_reset_wr),
    .device_reset_ctrl       (device_reset_ctrl),
    .device_reset_forced     (device_reset_forced),
    .device_reset_iface      (device_reset_iface),
    .recovery_ctrl_wr        (recovery_ctrl_wr),
    .recovery_ctrl_cms       (recovery_ctrl_cms),
    .recovery_ctrl_img_sel   (recovery_ctrl_img_sel),
    .recovery_ctrl_activate  (recovery_ctrl_activate),

    // From A4
    .image_push_active (image_push_active),
    .image_push_done   (image_push_done),
    .fifo_overflow     (fifo_overflow),
    .image_size        (image_size),
    .bytes_pushed      (bytes_pushed),

    // To A3 (status read-back)
    .device_status_out              (device_status_out),
    .device_status_protocol_err_out (device_status_protocol_err_out),
    .device_status_reason_out       (device_status_reason_out),
    .recovery_status_out            (recovery_status_out),
    .recovery_vendor_status_out     (recovery_vendor_status_out),
    .hw_status_out                  (hw_status_out),

    // SoC sideband (exposed)
    .recovery_active  (recovery_active),
    .image_ready      (image_ready),
    .boot_req         (boot_req),
    .device_reset_req (device_reset_req),
    .fatal_err        (fatal_err)
  );

  //////////////////////////////////////////////////////////////////////////////
  // RTL assertions
  //////////////////////////////////////////////////////////////////////////////

  // synopsys translate_off
  // Reg-bus: write and read must be mutually exclusive at the arbiter output.
  always_ff @(posedge clk) begin
    if (!rst) begin
      assert (!(rb_wr && rb_rd))
        else $error("usb_ocp_recovery_top: rb_wr and rb_rd both asserted");
      assert (!(usb_rb_wr && usb_rb_rd))
        else $error("usb_ocp_recovery_top: usb master asserted wr+rd");
      assert (!(axil_rb_wr && axil_rb_rd))
        else $error("usb_ocp_recovery_top: axil master asserted wr+rd");
      // Owner demux sanity: at most one ack routed back per cycle.
      assert (!(usb_rb_ack && axil_rb_ack))
        else $error("usb_ocp_recovery_top: ack routed to both masters");
    end
  end
  // synopsys translate_on

endmodule
