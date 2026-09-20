// SPDX-License-Identifier: Apache-2.0
//------------------------------------------------------------------------------
// usb_ocp_recovery_top.sv
//
// OCP Recovery v1.1 USB transport integration wrapper.  This module accepts
// the pre-filtered EP0 recovery stream from usb_ocp_recovery_post_sync_arb, decodes the
// class request, arbitrates USB-vs-external register access, and connects the
// regblock, CMS FIFO backing store, and protocol-error state.
//
// Instantiates:
//   A2 : usb_ocp_recovery_ctrl_decode (SV)
//   A3 : usb_ocp_recovery_rb_adapter + peakrdl-generated usb_ocp_recovery
//        (regblock from third_party/usb2/systemrdl/usb_ocp_recovery_reg.rdl)
//   A4 : usb_ocp_recovery_cms_fifo    (SV)
//
// Clock / Reset:
//   Single clock `clk`, synchronous active-low `rst_ni`.
//------------------------------------------------------------------------------

module usb_ocp_recovery_top
  import usb_ocp_recovery_pkg::*;
#(
  parameter int           FIFO_DEPTH_DWORDS = usb_ocp_recovery_pkg::OCP_FIFO_PHYSICAL_DEPTH_DWORDS,
  parameter int           RECOVERY_LOCAL_ADDR_WIDTH =
      usb_ocp_recovery_pkg::OCP_RECOVERY_APERTURE_ADDR_W
)(
  input  logic                    clk,
  input  logic                    rst_ni,

  //----------------------------------------------------------------------------
  // Upper-side 32-bit control-transfer surface driven by VHDL
  // usb_ocp_recovery_post_sync_arb.
  //----------------------------------------------------------------------------
  input  logic                    rec_setup_pkt_vld,
  input  logic [63:0]             rec_setup_pkt,

  input  logic [31:0]             rec_ctrl_out_data,
  input  logic                    rec_ctrl_out_vld,
  input  logic                    rec_ctrl_out_last,
  output logic                    rec_ctrl_out_rdy,

  output logic [31:0]             rec_ctrl_in_data,
  output logic [3:0]              rec_ctrl_in_be,
  output logic                    rec_ctrl_in_vld,
  output logic                    rec_ctrl_in_last,
  input  logic                    rec_ctrl_in_rdy,
  output logic [6:0]              rec_ctrl_in_resp_bytes,
  output logic                    rec_ctrl_in_resp_known,

  output logic                    rec_ctrl_set_stall,
  input  logic                    rec_ctrl_xfer_done,
  input  logic                    rec_ctrl_xfer_abort,
  input  logic                    rec_ctrl_fifo_batch_abort,
  input  logic                    rec_ctrl_length_error,

  // Emergency-fallback path-disable control: mirrors CALIPTRA_CTRL.OCP_PATH_DISABLE
  // (regblock field, EXT/firmware write-only via rb_is_ext/swwe gating -- see
  // rb_hwif_in assignment below) out to the VHDL arbiter
  // (usb_ocp_recovery_post_sync_arb ocp_path_disable_i), which forces legacy
  // SIE pass-through when set. Both this module and the arbiter live in
  // dev_axi_aclk, so no synchronizer is needed for this same-domain
  // registered signal.
  output logic                    rec_ocp_path_disable,
  output logic                    rec_ocp_claim_abort,
  output logic                    rec_fw_protocol_error_req,
  output logic [6:0]              rec_fifo_free_dwords,
  input  logic                    rec_fifo_reservation_active,

  //----------------------------------------------------------------------------
  // AHB slave for the aperture-local Recovery register window.
  //----------------------------------------------------------------------------
  input  logic [RECOVERY_LOCAL_ADDR_WIDTH-1:0] rec_ahb_haddr,
  input  logic [1:0]              rec_ahb_htrans,
  input  logic [2:0]              rec_ahb_hsize,
  input  logic                    rec_ahb_hwrite,
  input  logic [31:0]             rec_ahb_hwdata,
  input  logic                    rec_ahb_hsel,
  input  logic                    rec_ahb_hreadyin,
  output logic [31:0]             rec_ahb_hrdata,
  output logic                    rec_ahb_hreadyout,
  output logic [1:0]              rec_ahb_hresp,

  //----------------------------------------------------------------------------
  // Static capability inputs (tied by SoC integrator).
  //----------------------------------------------------------------------------
  input  logic [191:0]            device_id_in,

  //----------------------------------------------------------------------------
  // Recovery data-plane sideband.
  //----------------------------------------------------------------------------
  output logic                    payload_available,
  output logic                    recovery_image_activated
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
  logic                       usb_is_fifo_cmd;
  logic [31:0]                usb_hw_rdata;
  logic                       usb_hw_ack;
  logic                       usb_hw_err;
  logic                       usb_protocol_error_set;
  logic                       decode_protocol_error_vld;
  logic [7:0]                 decode_protocol_error_code;
  logic                       fw_protocol_error_req;
  logic                       fw_protocol_error_accept;
  logic                       device_reset_cmd_enabled;

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

  // --- EXT reg-bus into A3 (word-wide) ---
  logic                       rb_wr;
  logic                       rb_rd;
  logic [31:0]                rb_wdata;
  logic [3:0]                 rb_wstrb;
  logic [31:0]                rb_rdata;
  logic                       rb_ack;
  logic                       rb_err;

  // --- USB direct FIFO command path into A4 (32-bit word + byte strobe) ---
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
  logic                       usb_fifo_req;
  logic                       usb_fifo_packet_active_q;
  logic                       cpuif_req_block;
  logic [3:0]                 cpuif_wr_strb;
  logic                       ext_fifo_ctrl_0_access;
  logic                       ext_fifo_ctrl_1_access;
  logic                       ext_fifo_status_0_access;
  logic                       ext_fifo_status_1_access;
  logic                       ext_fifo_status_2_access;
  logic                       ext_fifo_status_3_access;
  logic                       ext_fifo_status_4_access;
  logic                       ext_fifo_data_read;
  logic                       ext_fifo_data_write;
  logic                       ext_fifo_aperture_access;
  logic                       ext_fifo_data_aperture_access;

  // --- AHB slave client and internal external-master request ---
  logic                       ahb_dv;
  logic                       ahb_hld;
  logic                       ahb_err;
  logic                       ahb_write;
  logic [31:0]                ahb_wdata;
  logic [RECOVERY_LOCAL_ADDR_WIDTH-1:0] ahb_addr;
  logic [31:0]                ahb_rdata;
  logic                       ahb_hresp;
  logic                       ahb_access_invalid_q;
  logic                       ext_rb_wr;
  logic                       ext_rb_rd;
  logic [31:0]                ext_rb_wdata;
  logic [31:0]                ext_rb_rdata;
  logic                       ext_rb_ack;
  logic                       ext_rb_err;
  logic [OCP_RECOVERY_APERTURE_ADDR_W-1:0] ext_aperture_offset;

  // OCP Recovery v1.1 Sec 9.2 defines PROTOCOL_ERROR clear-on-read for the
  // Recovery Agent USB command. The control decoder pulses this only after a
  // completed USB DEVICE_STATUS read; firmware cpuif reads are non-destructive.
  logic                       proto_err_rd_pulse;
  logic [7:0]                 protocol_error_q;
  logic                       ocp_claim_abort_clear;
  logic                       protocol_error_general_clear;

  // --- A4 status (image push not used in EP0-only mode but A4 still drives) ---
  logic                       image_push_done;
  logic                       fifo_overflow;
  logic                       batch_aborted;
  logic [$clog2(FIFO_DEPTH_DWORDS+1)-1:0] fifo_free_dwords;

  // --- INDIRECT_FIFO_* values from A4 (cms_fifo) into the A3 regblock.
  //     CTRL fields are stored read-back mirrors. STATUS and DATA are
  //     storage-less live hwif views of cms_fifo. ---
  logic [7:0]                 fifo_ctrl_cms;
  logic                       fifo_ctrl_reset;
  logic                       fifo_region_reset;
  logic [31:0]                fifo_ctrl_image_size;
  logic [31:0]                fifo_status_word_0;
  logic [31:0]                fifo_status_word_1;
  logic [31:0]                fifo_status_word_2;
  logic [31:0]                fifo_status_word_3;
  logic [31:0]                fifo_status_word_4;
  logic [31:0]                fifo_data_peek;

  //////////////////////////////////////////////////////////////////////////////
  // Firmware cpuif arbiter. USB register and FIFO commands bypass this
  // arbitration through their dedicated hardware paths.
  //
  // EXT in-flight gating: once EXT is granted, retain its command until its
  // ack lands. This protects multi-cycle cms_fifo accesses while the register
  // adapter suppresses repeated CPU-interface request pulses.
  // USB side already pulses rb_wr per word from ctrl_decode and is
  // intentionally not gated to preserve its 1-cycle ack semantics.
  //////////////////////////////////////////////////////////////////////////////

  logic       usb_req_now;
  logic       ext_req_now;
  logic       grant_ext;
  logic       ext_in_flight_q;
  logic       ext_write_q;
  logic       rb_is_ext;

  initial begin
    assert (RECOVERY_LOCAL_ADDR_WIDTH == OCP_RECOVERY_APERTURE_ADDR_W)
      else $fatal(1, "Recovery AHB address width must match the register aperture");
  end

  ahb_slv_sif #(
    .AHB_DATA_WIDTH   (32),
    .CLIENT_DATA_WIDTH(32),
    .AHB_ADDR_WIDTH   (RECOVERY_LOCAL_ADDR_WIDTH),
    .CLIENT_ADDR_WIDTH(RECOVERY_LOCAL_ADDR_WIDTH)
  ) u_rec_ahb_slv_sif (
    .hclk       (clk),
    .hreset_n   (rst_ni),
    .haddr_i    (rec_ahb_haddr),
    .hwdata_i   (rec_ahb_hwdata),
    .hsel_i     (rec_ahb_hsel),
    .hwrite_i   (rec_ahb_hwrite),
    .hready_i   (rec_ahb_hreadyin),
    .htrans_i   (rec_ahb_htrans),
    .hsize_i    (rec_ahb_hsize),
    .hresp_o    (ahb_hresp),
    .hreadyout_o(rec_ahb_hreadyout),
    .hrdata_o   (rec_ahb_hrdata),
    .dv         (ahb_dv),
    .hld        (ahb_hld),
    .err        (ahb_err),
    .write      (ahb_write),
    .wdata      (ahb_wdata),
    .addr       (ahb_addr),
    .rdata      (ahb_rdata)
  );

  assign rec_ahb_hresp = {1'b0, ahb_hresp};
  assign ext_aperture_offset = ahb_addr[OCP_RECOVERY_APERTURE_ADDR_W-1:0];
  assign ext_rb_wdata = ahb_wdata;
  // ext_rb_wr/ext_rb_rd are held level across the AHB dv window: the internal
  // cpuif arbiter uses ext_in_flight_q as the one-shot guard, granting the
  // register-block or FIFO request exactly once per transfer even when USB
  // priority momentarily blocks a grant. Held levels also keep the aperture
  // offset stable across multi-cycle cms_fifo accesses.
  assign ext_rb_wr = ahb_dv && !ahb_access_invalid_q && ahb_write;
  assign ext_rb_rd = ahb_dv && !ahb_access_invalid_q && !ahb_write;
  assign ahb_rdata = ext_rb_rdata;
  assign ahb_hld = ahb_dv && !ahb_access_invalid_q && !ext_rb_ack;
  assign ahb_err = ahb_dv &&
                   (ahb_access_invalid_q ||
                    (ext_rb_ack && ext_rb_err));

  // Aligned-word validation. Register on the address-phase acceptance so the
  // data-phase err/hld terms observe the qualified transfer. AHB address decode
  // and combo selection have already filtered non-recovery accesses; the local
  // check enforces the word-only policy of the shared AHB slave.
  always_ff @(posedge clk) begin
    if (!rst_ni) begin
      ahb_access_invalid_q <= 1'b0;
    end else if (rec_ahb_hreadyin && rec_ahb_hsel && rec_ahb_htrans[1]) begin
      ahb_access_invalid_q <= (rec_ahb_hsize != 3'b010) ||
                              (rec_ahb_haddr[1:0] != 2'b00);
    end
  end

  always_comb begin
    usb_req_now = usb_rb_wr | usb_rb_rd;
    ext_req_now = ext_rb_wr | ext_rb_rd;
    grant_ext   = ext_req_now & ~ext_in_flight_q & ~usb_req_now;
  end

  always_comb begin
    rb_wr     = 1'b0;
    rb_rd     = 1'b0;
    rb_wdata  = '0;
    rb_wstrb  = 4'h0;
    if (grant_ext | ext_in_flight_q) begin
      // The bus is held for the whole in-flight window so a multi-cycle
      // cms_fifo read keeps its aperture offset stable until it acks.
      rb_wr     = (grant_ext && ext_rb_wr) ||
                  (ext_in_flight_q && ext_write_q);
      rb_rd     = (grant_ext && ext_rb_rd) ||
                  (ext_in_flight_q && !ext_write_q);
      rb_wdata  = ext_rb_wdata;
      rb_wstrb  = 4'hF;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_ni) begin
      ext_in_flight_q  <= 1'b0;
      ext_write_q      <= 1'b0;
    end else begin
      if (grant_ext)      ext_write_q <= ext_rb_wr;

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

  // EXT is word-native: return the full 32-bit read word. The shared AHB slave
  // holds the aperture offset across the request handshake. The ack/err
  // are qualified with the active EXT request window so same-cycle reads,
  // registered writes, and multi-cycle FIFO reads all return to the SoC master.
  assign ext_rb_rdata = rb_rdata[31:0];
  assign ext_rb_ack   = rb_ack & rb_is_ext;
  assign ext_rb_err   = rb_err & rb_is_ext;

  // Request-cycle EXT qualifier for firmware-only side effects and FIFO
  // arbitration. Do not derive this from the registered response owner.
  assign rb_is_ext = grant_ext | ext_in_flight_q;

  //////////////////////////////////////////////////////////////////////////////
  // EP0 SETUP routing
  //
  // The VHDL arbiter (usb_ocp_recovery_post_sync_arb) performs OCP class decode inline
  // on the captured SETUP beat and pre-filters rec_setup_pkt_vld so that only
  // OCP-class SETUPs ever pulse into this SV stack.  All non-OCP SETUPs flow
  // through the arbiter to the legacy SIE unmodified, so standard USB
  // enumeration (GET_DESCRIPTOR / SET_ADDRESS / SET_CONFIGURATION /
  // GET_STATUS / ...) continues to be handled by the MCU EPCS.  See
  // usb_ocp_recovery_post_sync_arb.m.vhdl for the class-match definition
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
    .rst_ni          (rst_ni),

    .setup_pkt_vld   (rec_setup_pkt_vld),
    .setup_pkt       (rec_setup_pkt),
    .ctrl_out_data   (rec_ctrl_out_data),
    .ctrl_out_vld    (rec_ctrl_out_vld),
    .ctrl_out_last   (rec_ctrl_out_last),
    .ctrl_out_rdy    (rec_ctrl_out_rdy),
    .ctrl_in_data    (rec_ctrl_in_data),
    .ctrl_in_be      (rec_ctrl_in_be),
    .ctrl_in_vld     (rec_ctrl_in_vld),
    .ctrl_in_last    (rec_ctrl_in_last),
    .ctrl_in_rdy     (rec_ctrl_in_rdy),
    .ctrl_in_resp_bytes(rec_ctrl_in_resp_bytes),
    .ctrl_in_resp_known(rec_ctrl_in_resp_known),
    .ctrl_set_stall  (rec_ctrl_set_stall),
    .ctrl_xfer_done  (rec_ctrl_xfer_done),
    .ctrl_xfer_abort (rec_ctrl_xfer_abort),
    .device_reset_cmd_enabled(device_reset_cmd_enabled),
    .proto_err_rd_pulse (proto_err_rd_pulse),
    .protocol_error_vld (decode_protocol_error_vld),
    .protocol_error_code(decode_protocol_error_code),

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

  assign device_reset_cmd_enabled =
      rb_hwif_out.PROT_CAP_2.AGENT_CAPS_FORCED_RECOVERY.value |
      rb_hwif_out.PROT_CAP_2.AGENT_CAPS_MGMT_RESET.value |
      rb_hwif_out.PROT_CAP_2.AGENT_CAPS_DEVICE_RESET.value |
      rb_hwif_out.PROT_CAP_2.AGENT_CAPS_INTERFACE_ISOLATION.value |
      rb_hwif_out.PROT_CAP_2.AGENT_CAPS_FLASHLESS_BOOT.value;

  //////////////////////////////////////////////////////////////////////////////
  // A3 : EXT/AHB reg-bus adapter + peakrdl-generated regblock
  //
  // The adapter translates held EXT requests into one-shot accesses on the
  // regblock's 32-bit passthrough CPU interface. USB Recovery Agent commands
  // use the hardware-interface and FIFO paths above.
  // The regblock (usb_ocp_recovery_reg) is generated by peakrdl from
  // third_party/usb2/systemrdl/usb_ocp_recovery_reg.rdl and is the single
  // source of truth for field layout, reset values, and the SoC byte-flat
  // address window.
  //////////////////////////////////////////////////////////////////////////////

  // --- adapter <-> regblock cpuif passthrough ---
  logic        cpuif_req;
  logic        cpuif_req_is_wr;
  logic [OCP_RECOVERY_APERTURE_ADDR_W-1:0] cpuif_addr;
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

  // USB Recovery Agent hardware endpoint. This path consumes the ctrl_decode
  // command stream without touching the firmware CPUif. FIFO commands are
  // identified here but selected only by the response mux below.
  logic        usb_hw_access;
  logic        usb_hw_supported_cmd;
  logic        usb_hw_host_ro_cmd;
  logic [15:0] usb_hw_cmd_len;
  logic [15:0] usb_hw_byte_offset;

  always_comb begin
    usb_hw_access       = usb_rb_wr | usb_rb_rd;
    usb_is_fifo_cmd     = ((usb_rb_cmd == OCP_CMD_INDIRECT_FIFO_CTRL) && usb_rb_wr)
                        || ((usb_rb_cmd == OCP_CMD_INDIRECT_FIFO_STATUS) && usb_rb_rd)
                        ||  (usb_rb_cmd == OCP_CMD_INDIRECT_FIFO_DATA);
    usb_hw_supported_cmd = 1'b1;
    usb_hw_host_ro_cmd   = 1'b0;
    usb_hw_cmd_len       = '0;
    usb_hw_byte_offset   = {usb_rb_offset[13:0], 2'b00};
    usb_hw_rdata         = '0;
    usb_hw_ack           = usb_hw_access;
    usb_hw_err           = 1'b0;
    usb_protocol_error_set = 1'b0;

    usb_device_reset_ctrl_next      = usb_rb_wdata[7:0];
    usb_device_reset_ctrl_we        = 1'b0;
    usb_device_reset_forced_next    = usb_rb_wdata[15:8];
    usb_device_reset_forced_we      = 1'b0;
    usb_device_reset_iface_next     = usb_rb_wdata[23:16];
    usb_device_reset_iface_we       = 1'b0;
    usb_recovery_ctrl_cms_next      = usb_rb_wdata[7:0];
    usb_recovery_ctrl_cms_we        = 1'b0;
    usb_recovery_ctrl_img_sel_next  = usb_rb_wdata[15:8];
    usb_recovery_ctrl_img_sel_we    = 1'b0;
    usb_recovery_ctrl_activate_next = usb_rb_wdata[23:16];
    usb_recovery_ctrl_activate_we   = 1'b0;
    usb_vendor_next                 = usb_rb_wdata[7:0];
    usb_vendor_we                   = 1'b0;

    unique case (usb_rb_cmd)
      OCP_CMD_PROT_CAP: begin
        usb_hw_cmd_len     = OCP_LEN_PROT_CAP;
        usb_hw_host_ro_cmd = 1'b1;
        unique case (usb_rb_offset)
          16'd0: usb_hw_rdata = rb_hwif_out.PROT_CAP_0.REC_MAGIC_STRING_0.value;
          16'd1: usb_hw_rdata = rb_hwif_out.PROT_CAP_1.REC_MAGIC_STRING_1.value;
          16'd2: usb_hw_rdata = {
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
          };
          16'd3: usb_hw_rdata = {
            rb_hwif_out.PROT_CAP_3.RESERVED_31_24.value,
            rb_hwif_out.PROT_CAP_3.HEARTBEAT_PERIOD.value,
            rb_hwif_out.PROT_CAP_3.MAX_RESP_TIME.value,
            rb_hwif_out.PROT_CAP_3.NUM_OF_CMS_REGIONS.value
          };
          default: usb_hw_err = usb_rb_rd;
        endcase
      end
      OCP_CMD_DEVICE_ID: begin
        usb_hw_cmd_len     = OCP_LEN_DEVICE_ID;
        usb_hw_host_ro_cmd = 1'b1;
        if (usb_rb_offset < 16'd6) begin
          usb_hw_rdata = device_id_in[usb_rb_offset[2:0]*32 +: 32];
        end else begin
          usb_hw_err = usb_rb_rd;
        end
      end
      OCP_CMD_DEVICE_STATUS: begin
        usb_hw_cmd_len     = OCP_LEN_DEVICE_STATUS;
        usb_hw_host_ro_cmd = 1'b1;
        if (usb_rb_offset == 16'd0) begin
          usb_hw_rdata = {
            rb_hwif_out.DEVICE_STATUS_0.REC_REASON_CODE.value,
            protocol_error_q,
            rb_hwif_out.DEVICE_STATUS_0.DEV_STATUS.value
          };
        end else if (usb_rb_offset < 16'd16) begin
          usb_hw_rdata = '0;
        end else begin
          usb_hw_err = usb_rb_rd;
        end
      end
      OCP_CMD_DEVICE_RESET: begin
        usb_hw_cmd_len = OCP_LEN_DEVICE_RESET;
        usb_hw_rdata   = {8'h00, rb_hwif_out.DEVICE_RESET.IF_CTRL.value,
                          rb_hwif_out.DEVICE_RESET.FORCED_RECOVERY.value,
                          rb_hwif_out.DEVICE_RESET.RESET_CTRL.value};
        if (usb_rb_wr) begin
          usb_device_reset_ctrl_we   = usb_rb_wstrb[0];
          usb_device_reset_forced_we = usb_rb_wstrb[1];
          usb_device_reset_iface_we  = usb_rb_wstrb[2];
        end
      end
      OCP_CMD_RECOVERY_CTRL: begin
        usb_hw_cmd_len = OCP_LEN_RECOVERY_CTRL;
        usb_hw_rdata   = {8'h00, rb_hwif_out.RECOVERY_CTRL.ACTIVATE_REC_IMG.value,
                          rb_hwif_out.RECOVERY_CTRL.REC_IMG_SEL.value,
                          rb_hwif_out.RECOVERY_CTRL.CMS.value};
        if (usb_rb_wr) begin
          usb_recovery_ctrl_cms_we        = usb_rb_wstrb[0];
          usb_recovery_ctrl_img_sel_we    = usb_rb_wstrb[1];
          usb_recovery_ctrl_activate_we   = usb_rb_wstrb[2];
        end
      end
      OCP_CMD_RECOVERY_STATUS: begin
        usb_hw_cmd_len     = OCP_LEN_RECOVERY_STATUS;
        usb_hw_host_ro_cmd = 1'b1;
        usb_hw_rdata       = {
          16'h0,
          rb_hwif_out.RECOVERY_STATUS.VENDOR_SPECIFIC_STATUS.value,
          rb_hwif_out.RECOVERY_STATUS.REC_IMG_INDEX.value,
          rb_hwif_out.RECOVERY_STATUS.DEV_REC_STATUS.value
        };
      end
      OCP_CMD_HW_STATUS: begin
        usb_hw_cmd_len     = OCP_LEN_HW_STATUS;
        usb_hw_host_ro_cmd = 1'b1;
        usb_hw_rdata       = {
          rb_hwif_out.HW_STATUS.VENDOR_HW_STATUS_LEN.value,
          rb_hwif_out.HW_STATUS.CTEMP.value,
          rb_hwif_out.HW_STATUS.VENDOR_HW_STATUS.value,
          rb_hwif_out.HW_STATUS.RESERVED_7_3.value,
          rb_hwif_out.HW_STATUS.FATAL_ERR.value,
          rb_hwif_out.HW_STATUS.SOFT_ERR.value,
          rb_hwif_out.HW_STATUS.TEMP_CRITICAL.value
        };
      end
      OCP_CMD_INDIRECT_FIFO_CTRL: begin
        usb_hw_cmd_len = OCP_LEN_INDIRECT_FIFO_CTRL;
        if (usb_rb_rd) begin
          unique case (usb_rb_offset)
            16'd0: usb_hw_rdata = {fifo_ctrl_image_size[15:0],
                                    {7'h0, fifo_ctrl_reset}, fifo_ctrl_cms};
            16'd1: usb_hw_rdata = {16'h0, fifo_ctrl_image_size[31:16]};
            default: usb_hw_err = 1'b1;
          endcase
        end
      end
      OCP_CMD_INDIRECT_FIFO_STATUS: begin
        usb_hw_cmd_len = OCP_LEN_INDIRECT_FIFO_STATUS;
        if (usb_rb_wr) begin
          usb_protocol_error_set = 1'b1;
        end
      end
      OCP_CMD_VENDOR: begin
        usb_hw_cmd_len = OCP_LEN_VENDOR;
        usb_hw_rdata   = {24'h0, rb_hwif_out.VENDOR.VENDOR_DATA.value};
        if (usb_rb_wr) begin
          usb_vendor_we = usb_rb_wstrb[0];
        end
      end
      default: begin
        usb_hw_supported_cmd = 1'b0;
        usb_protocol_error_set = usb_hw_access;
      end
    endcase

    if (usb_rb_wr && usb_hw_host_ro_cmd) begin
      usb_protocol_error_set = 1'b1;
    end
    if (usb_hw_access && !usb_hw_supported_cmd) begin
      usb_hw_err = 1'b0;
    end
    if (usb_hw_access && !usb_is_fifo_cmd && usb_hw_supported_cmd
        && (usb_hw_byte_offset >= usb_hw_cmd_len)) begin
      usb_hw_err = 1'b1;
    end
  end

  usb_ocp_recovery_rb_adapter u_a3_adapter (
    .clk             (clk),
    .rst_ni          (rst_ni),

    .rb_wr           (rb_wr),
    .rb_rd           (rb_rd),
    .rb_wdata        (rb_wdata),
    .rb_wstrb        (rb_wstrb),
    .rb_rdata        (rb_rdata),
    .rb_ack          (rb_ack),
    .rb_err          (rb_err),
    .ext_aperture_offset(ext_aperture_offset),

     .cpuif_req       (cpuif_req),
     .cpuif_req_is_wr (cpuif_req_is_wr),
     .cpuif_addr      (cpuif_addr),
     .cpuif_wr_data   (cpuif_wr_data),
     .cpuif_wr_biten  (cpuif_wr_biten),
     .cpuif_req_block (cpuif_req_block),
     .cpuif_rd_ack    (cpuif_rd_ack),
     .cpuif_rd_err    (cpuif_rd_err),
     .cpuif_rd_data   (cpuif_rd_data),
     .cpuif_wr_ack    (cpuif_wr_ack),
     .cpuif_wr_err    (cpuif_wr_err)
    );

  // OCP Recovery v1.1 Sec 9.1 defines first-error reporting. A completed USB
  // DEVICE_STATUS read has clear priority; otherwise USB-detected errors win
  // over the firmware-originated general-error request.
  always_ff @(posedge clk) begin
    if (!rst_ni) begin
      protocol_error_q <= OCP_PROTOCOL_ERROR_NONE;
    end else begin
      if (proto_err_rd_pulse) begin
        protocol_error_q <= OCP_PROTOCOL_ERROR_NONE;
      end else if (decode_protocol_error_vld
          && (protocol_error_q == OCP_PROTOCOL_ERROR_NONE)) begin
        protocol_error_q <= decode_protocol_error_code;
      end else if (rec_ctrl_length_error
          && (protocol_error_q == OCP_PROTOCOL_ERROR_NONE)) begin
        protocol_error_q <= OCP_PROTOCOL_ERROR_LENGTH;
      end else if (usb_protocol_error_set
          && (protocol_error_q == OCP_PROTOCOL_ERROR_NONE)) begin
        protocol_error_q <= OCP_PROTOCOL_ERROR_UNSUPPORTED_COMMAND;
      end else if (fw_protocol_error_accept
          && (protocol_error_q == OCP_PROTOCOL_ERROR_NONE)) begin
        protocol_error_q <= OCP_PROTOCOL_ERROR_GENERAL;
      end
    end
  end

  // Emergency-fallback OCP path-disable control: drive out to the VHDL arbiter
  // (usb_ocp_recovery_post_sync_arb ocp_path_disable_i via the vendor IP wrapper
  // hierarchy) from the Caliptra-specific CALIPTRA_CTRL register (outside the
  // OCP command aperture). Same-domain (dev_axi_aclk) registered field value; no
  // synchronizer needed.
  assign rec_ocp_path_disable = rb_hwif_out.CALIPTRA_CTRL.OCP_PATH_DISABLE.value;
  assign rec_ocp_claim_abort = rb_hwif_out.CALIPTRA_CTRL.OCP_CLAIM_ABORT.swmod
                             && rb_is_ext
                             && cpuif_req_is_wr
                             && cpuif_wr_biten[1]
                             && cpuif_wr_data[1];
  assign ocp_claim_abort_clear =
      rb_hwif_out.CALIPTRA_CTRL.OCP_CLAIM_ABORT.value;
  assign fw_protocol_error_req =
      rb_hwif_out.CALIPTRA_CTRL.OCP_PROTOCOL_ERROR_GENERAL.swmod
      && rb_is_ext
      && cpuif_req_is_wr
      && cpuif_wr_biten[2]
      && cpuif_wr_data[2];
  assign protocol_error_general_clear =
      rb_hwif_out.CALIPTRA_CTRL.OCP_PROTOCOL_ERROR_GENERAL.value;
  assign fw_protocol_error_accept = fw_protocol_error_req && batch_aborted;
  assign rec_fw_protocol_error_req = fw_protocol_error_accept;
  assign rec_fifo_free_dwords = fifo_free_dwords;

  assign cpuif_wr_strb = { |cpuif_wr_biten[31:24],
                           |cpuif_wr_biten[23:16],
                           |cpuif_wr_biten[15:8],
                           |cpuif_wr_biten[7:0] };

  assign ext_fifo_ctrl_0_access = cpuif_req && rb_hwif_out.INDIRECT_FIFO_CTRL_0.CMS.swacc;
  assign ext_fifo_ctrl_1_access = cpuif_req && rb_hwif_out.INDIRECT_FIFO_CTRL_1.IMAGE_SIZE.swacc;
  assign ext_fifo_status_0_access = cpuif_req && rb_hwif_out.INDIRECT_FIFO_STATUS_0.EMPTY.swacc;
  assign ext_fifo_status_1_access = cpuif_req && rb_hwif_out.INDIRECT_FIFO_STATUS_1.WRITE_INDEX.swacc;
  assign ext_fifo_status_2_access = cpuif_req && rb_hwif_out.INDIRECT_FIFO_STATUS_2.READ_INDEX.swacc;
  assign ext_fifo_status_3_access = cpuif_req && rb_hwif_out.INDIRECT_FIFO_STATUS_3.FIFO_SIZE.swacc;
  assign ext_fifo_status_4_access = cpuif_req && rb_hwif_out.INDIRECT_FIFO_STATUS_4.MAX_TRANSFER_SIZE.swacc;
  assign ext_fifo_data_read = cpuif_req
                            && !cpuif_req_is_wr
                            && rb_hwif_out.INDIRECT_FIFO_DATA.DATA.swacc;
  assign ext_fifo_data_write = cpuif_req
                             && cpuif_req_is_wr
                             && rb_hwif_out.INDIRECT_FIFO_DATA.DATA.swacc;

  // A USB FIFO command owns the complete claimed control transfer. Defer every
  // EXT FIFO CPUif request until that transfer retires so a ctrl_decode skid
  // bubble cannot let firmware interleave FIFO control, status, or data access.
  // DATA reads remain blocking until a full or terminal batch is available.
  assign ext_fifo_aperture_access = rb_is_ext
                                  && (ext_aperture_offset >= OCP_ADDR_INDIRECT_FIFO_CTRL[OCP_RECOVERY_APERTURE_ADDR_W-1:0])
                                  && (ext_aperture_offset <  OCP_ADDR_VENDOR[OCP_RECOVERY_APERTURE_ADDR_W-1:0]);
  assign ext_fifo_data_aperture_access = rb_is_ext
                                       && (ext_aperture_offset >= OCP_ADDR_INDIRECT_FIFO_DATA[OCP_RECOVERY_APERTURE_ADDR_W-1:0])
                                       && (ext_aperture_offset <  OCP_ADDR_VENDOR[OCP_RECOVERY_APERTURE_ADDR_W-1:0]);
  assign cpuif_req_block = rb_is_ext
                           && ((ext_fifo_aperture_access
                                 && (usb_fifo_req || usb_fifo_packet_active_q
                                     || rec_fifo_reservation_active))
                               || (ext_fifo_data_aperture_access
                                   && rb_rd
                                   && !payload_available));

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
  // HW_STATUS is firmware-owned cpuif storage. The USB Recovery Agent direct
  // read path consumes the same regblock storage via rb_hwif_out above, keeping
  // host reads and EXT reads coherent.
  //
  // INDIRECT_FIFO_CTRL / INDIRECT_FIFO_STATUS / INDIRECT_FIFO_DATA are EXT-cpuif
  // visible through the generated regblock, but usb_ocp_recovery_cms_fifo.sv
  // remains the live owner of control, status, payload, and indices. CTRL uses
  // generated read-back storage; STATUS and DATA read hwif next directly.
  //
  // The adapter only forwards regblock cpuif errors for in-window accesses, so
  // a regblock-side decode miss cannot surface as an rb_err /
  // AXI error response.  Every regblock byte in the address window is backed by
  // a declared field per the generated package (usb_ocp_recovery_reg_pkg.sv).
  // --------------------------------------------------------------------------
  always_comb begin
    rb_hwif_in = '{default: '0};
    rb_hwif_in.rst_ni = rst_ni;

    // PROT_CAP is firmware-configurable through cpuif and exposed to the USB
    // endpoint through hwif_out. Its RDL hw=r properties make the stored values
    // visible without permitting a hardware write.

    // USB Recovery Agent writes use the hardware interface. Firmware owns
    // recovery progress through cpuif-visible field storage.
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

    // DEVICE_STATUS_0 byte 1 is hardware-owned. Device status and recovery
    // reason are firmware-owned cpuif storage.
    rb_hwif_in.DEVICE_STATUS_0.PROT_ERROR.next = protocol_error_q;

    // CALIPTRA_CTRL.OCP_PATH_DISABLE (emergency-fallback path-disable control):
    // software write-enable gated by rb_is_ext so only EXT/firmware writes
    // commit; a USB-host write is silently ignored (swwe=0), matching the
    // same source-qualification pattern used for PROT_CAP capability writes.
    // The register itself lives outside the OCP command aperture and is only
    // reachable via the firmware/AXI sub-decoder.
    rb_hwif_in.CALIPTRA_CTRL.OCP_PATH_DISABLE.swwe = rb_is_ext;
    rb_hwif_in.CALIPTRA_CTRL.OCP_CLAIM_ABORT.swwe = rb_is_ext;
    rb_hwif_in.CALIPTRA_CTRL.OCP_CLAIM_ABORT.next = 1'b0;
    rb_hwif_in.CALIPTRA_CTRL.OCP_CLAIM_ABORT.we = ocp_claim_abort_clear;
    rb_hwif_in.CALIPTRA_CTRL.OCP_PROTOCOL_ERROR_GENERAL.swwe = rb_is_ext;
    rb_hwif_in.CALIPTRA_CTRL.OCP_PROTOCOL_ERROR_GENERAL.next = 1'b0;
    rb_hwif_in.CALIPTRA_CTRL.OCP_PROTOCOL_ERROR_GENERAL.we =
        protocol_error_general_clear;

    // CALIPTRA_STATUS (read-only, hw=w): Caliptra-specific sticky FIFO status
    // relocated out of the non-spec INDIRECT_FIFO_STATUS byte-0 bits. Driven
    // from the live cms_fifo sticky signals (region_reset_q via fifo_ctrl_reset,
    // overflow_q via fifo_overflow, image_done_q via image_push_done).
    rb_hwif_in.CALIPTRA_STATUS.REGION_RESET.next = fifo_region_reset;
    rb_hwif_in.CALIPTRA_STATUS.OVERFLOW.next     = fifo_overflow;
    rb_hwif_in.CALIPTRA_STATUS.IMAGE_DONE.next   = image_push_done;
    rb_hwif_in.CALIPTRA_STATUS.BATCH_ABORTED.next = batch_aborted;

    // INDIRECT_FIFO_CTRL read-back: cms_fifo is the live owner and drives the
    // mirrored regblock copy. CTRL_0 byte0 = CMS, byte1 bit0 = region-reset
    // (sticky). CTRL_1 = IMAGE_SIZE in DWORD units. RESET is zero-extended into
    // byte 1 to match the field.
    rb_hwif_in.INDIRECT_FIFO_CTRL_0.CMS.next        = fifo_ctrl_cms;
    rb_hwif_in.INDIRECT_FIFO_CTRL_0.RESET.next      = {7'b0, fifo_ctrl_reset};
    rb_hwif_in.INDIRECT_FIFO_CTRL_1.IMAGE_SIZE.next = fifo_ctrl_image_size;

    // INDIRECT_FIFO_STATUS live words from cms_fifo. OCP Recovery v1.1 Sec 9.2
    // defines the five DWORD status record at 0x18C..0x19C.
    rb_hwif_in.INDIRECT_FIFO_STATUS_0.EMPTY.next             = fifo_status_word_0[0];
    rb_hwif_in.INDIRECT_FIFO_STATUS_0.FULL.next              = fifo_status_word_0[1];
    rb_hwif_in.INDIRECT_FIFO_STATUS_0.RESERVED_7_2.next      = fifo_status_word_0[7:2];
    rb_hwif_in.INDIRECT_FIFO_STATUS_0.REGION_TYPE.next       = fifo_status_word_0[15:8];
    rb_hwif_in.INDIRECT_FIFO_STATUS_0.RESERVED_31_16.next    = fifo_status_word_0[31:16];
    rb_hwif_in.INDIRECT_FIFO_STATUS_1.WRITE_INDEX.next       = fifo_status_word_1;
    rb_hwif_in.INDIRECT_FIFO_STATUS_2.READ_INDEX.next        = fifo_status_word_2;
    rb_hwif_in.INDIRECT_FIFO_STATUS_3.FIFO_SIZE.next         = fifo_status_word_3;
    rb_hwif_in.INDIRECT_FIFO_STATUS_4.MAX_TRANSFER_SIZE.next = fifo_status_word_4;

    // INDIRECT_FIFO_DATA is a storage-less live hardware read. The same
    // read-qualified swacc event that returns this value pops the FIFO at the
    // following clock edge, so software observes the pre-pop head exactly once.
    rb_hwif_in.INDIRECT_FIFO_DATA.DATA.next = fifo_data_peek;
  end

  usb_ocp_recovery_reg u_a3_regblock (
    .clk                  (clk),
    .rst                  (~rst_ni), // Legacy generated compatibility reset port.

    .s_cpuif_req          (cpuif_req),
    .s_cpuif_req_is_wr    (cpuif_req_is_wr),
    // The generated RDL addrmap spans the package-defined recovery aperture.
    .s_cpuif_addr         (cpuif_addr[OCP_RECOVERY_APERTURE_ADDR_W-1:0]),
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

  // USB FIFO traffic owns the direct cms_fifo command port. EXT fifo accesses
  // are mediated through the regblock cpuif and the cms_fifo hwif-event bridge
  // below, so they never share this direct port and therefore cannot inject
  // backpressure into the Recovery Agent data stream.
  always_ff @(posedge clk) begin
    if (!rst_ni) begin
      usb_fifo_packet_active_q <= 1'b0;
    end else begin
      if (rec_ctrl_xfer_done || rec_ctrl_xfer_abort) begin
        usb_fifo_packet_active_q <= 1'b0;
      end else if (usb_fifo_req) begin
        usb_fifo_packet_active_q <= 1'b1;
      end
    end
  end

  always_comb begin
    fifo_rb_sel    = usb_fifo_req;
    fifo_rb_cmd    = usb_rb_cmd;
    fifo_rb_offset = usb_rb_offset;
    fifo_rb_wr     = usb_rb_wr;
    fifo_rb_rd     = usb_rb_rd;
    fifo_rb_wdata  = usb_rb_wdata;
    fifo_rb_wstrb  = usb_rb_wstrb;
  end

  //////////////////////////////////////////////////////////////////////////////
  // A4 : CMS indirect-memory FIFO + window (EP0-only; bulk ports removed)
  //////////////////////////////////////////////////////////////////////////////

  usb_ocp_recovery_cms_fifo #(
    .FIFO_DEPTH (FIFO_DEPTH_DWORDS)
  ) u_a4_cms_fifo (
    .clk             (clk),
    .rst_ni          (rst_ni),

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

     .ext_fifo_ctrl_0_access (ext_fifo_ctrl_0_access),
     .ext_fifo_ctrl_1_access (ext_fifo_ctrl_1_access),
     .ext_fifo_status_0_access (ext_fifo_status_0_access),
     .ext_fifo_status_1_access (ext_fifo_status_1_access),
     .ext_fifo_status_2_access (ext_fifo_status_2_access),
     .ext_fifo_status_3_access (ext_fifo_status_3_access),
     .ext_fifo_status_4_access (ext_fifo_status_4_access),
     .ext_fifo_data_read (ext_fifo_data_read),
     .ext_fifo_data_write (ext_fifo_data_write),
     .ext_cpuif_req_is_wr (cpuif_req_is_wr),
     .ext_cpuif_wr_data   (cpuif_wr_data),
     .ext_cpuif_wr_strb   (cpuif_wr_strb),

      .image_push_done   (image_push_done),
      .fifo_overflow     (fifo_overflow),
      .payload_available (payload_available),
      .batch_aborted     (batch_aborted),
      .fifo_free_dwords  (fifo_free_dwords),
      .fifo_abort_i      (rec_ctrl_fifo_batch_abort),
      .fifo_ctrl_cms        (fifo_ctrl_cms),
      .fifo_ctrl_reset      (fifo_ctrl_reset),
      .fifo_region_reset    (fifo_region_reset),
     .fifo_ctrl_image_size (fifo_ctrl_image_size),
     .fifo_status_word_0   (fifo_status_word_0),
     .fifo_status_word_1   (fifo_status_word_1),
      .fifo_status_word_2   (fifo_status_word_2),
      .fifo_status_word_3   (fifo_status_word_3),
      .fifo_status_word_4   (fifo_status_word_4),
      .fifo_data_peek       (fifo_data_peek)
    );

  assign recovery_image_activated =
      (rb_hwif_out.RECOVERY_CTRL.ACTIVATE_REC_IMG.value == 8'h0F);

  //////////////////////////////////////////////////////////////////////////////
  // Assertions
  //////////////////////////////////////////////////////////////////////////////
  // synopsys translate_off
  always_ff @(posedge clk) begin
    if (rst_ni) begin
      assert (!(rb_wr && rb_rd))
        else $error("usb_ocp_recovery_top: rb_wr and rb_rd both asserted");
      assert (!(usb_rb_wr && usb_rb_rd))
        else $error("usb_ocp_recovery_top: usb master asserted wr+rd");
      assert (!(ext_rb_wr && ext_rb_rd))
        else $error("usb_ocp_recovery_top: ext master asserted wr+rd");
      if (rb_ack || rb_err) begin
        assert (rb_is_ext)
          else $error("usb_ocp_recovery_top: EXT response outside active request window");
      end
      if (ahb_dv && ahb_access_invalid_q) begin
        assert (!(ext_rb_wr || ext_rb_rd))
          else $error("usb_ocp_recovery_top: invalid AHB access reached the register bus");
      end
      if (ext_rb_wr || ext_rb_rd) begin
        assert (ahb_dv)
          else $error("usb_ocp_recovery_top: register request without AHB client dv");
      end
      assert (!(usb_rb_ack && ext_rb_ack))
        else $error("usb_ocp_recovery_top: ack routed to both masters");
      if (usb_fifo_req) begin
        assert (usb_rb_ack)
          else $error("usb_ocp_recovery_top: USB FIFO command stalled");
      end
      if (cpuif_req_block) begin
        assert (!cpuif_req)
          else $error("usb_ocp_recovery_top: blocked EXT fifo access still fired cpuif");
      end
      if ($past(rst_ni) && $past(proto_err_rd_pulse)) begin
        assert (protocol_error_q == OCP_PROTOCOL_ERROR_NONE)
          else $error("usb_ocp_recovery_top: protocol error did not clear on completed USB DEVICE_STATUS read");
      end
      if (fw_protocol_error_accept) begin
        assert (batch_aborted)
          else $error("usb_ocp_recovery_top: firmware general error accepted without an aborted FIFO batch");
      end
      if (fw_protocol_error_req && !batch_aborted) begin
        assert (!rec_fw_protocol_error_req)
          else $error("usb_ocp_recovery_top: invalid firmware general error request reached USB");
      end
      if (protocol_error_general_clear) begin
        assert (rb_hwif_in.CALIPTRA_CTRL.OCP_PROTOCOL_ERROR_GENERAL.we
                && !rb_hwif_in.CALIPTRA_CTRL.OCP_PROTOCOL_ERROR_GENERAL.next)
          else $error("usb_ocp_recovery_top: firmware general error field did not self-clear");
      end
      if (decode_protocol_error_vld) begin
        assert (decode_protocol_error_code != OCP_PROTOCOL_ERROR_NONE)
          else $error("usb_ocp_recovery_top: decoder raised an empty protocol error");
      end
      if ($past(rst_ni) && $past(fw_protocol_error_accept)
          && ($past(protocol_error_q) == OCP_PROTOCOL_ERROR_NONE)
          && !$past(proto_err_rd_pulse)
          && !$past(decode_protocol_error_vld)
          && !$past(rec_ctrl_length_error)
          && !$past(usb_protocol_error_set)) begin
        assert (protocol_error_q == OCP_PROTOCOL_ERROR_GENERAL)
          else $error("usb_ocp_recovery_top: firmware general error was not recorded");
      end
      if ($past(rst_ni)
          && ($past(protocol_error_q) == OCP_PROTOCOL_ERROR_NONE)
          && $past(decode_protocol_error_vld)
          && !$past(proto_err_rd_pulse)) begin
        assert (protocol_error_q == $past(decode_protocol_error_code))
          else $error("usb_ocp_recovery_top: USB error lost first-error priority");
      end
    end
  end
  // synopsys translate_on

endmodule
