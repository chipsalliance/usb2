--  SPDX-License-Identifier: Apache-2.0
--  ----------------------------------------------------------------------------
--  File: usb_ocp_recovery_post_sync_arb.m.vhdl
--
--  Entity and architecture: rtl
--
--  Post-synchronizer OCP Recovery v1.1 EP0 arbiter.
--
--  Every EP0 SETUP is forwarded to usb_dma at its original timing and mirrored
--  into an eight-byte monitor. The monitor selects the retained EP0 owner after
--  link-valid completion while non-EP0 traffic remains on the DMA data plane.
--  ----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity usb_ocp_recovery_post_sync_arb is
  generic (
    USB_DATAWIDTH    : integer := 64;
    RXNBYTES_BITS    : integer := 12;
    TXNBYTES_BITS    : integer := 15;
    C_REC_IFACE_NUM  : integer range 0 to 255 := 0
  );
  port (
    hclk     : in  std_logic;
    hresetn  : in  std_logic;

    sync_busreset : in std_logic;
    pie_dev_selected_i : in std_logic_vector(1 downto 0);
    dev0_port_reset_i : in std_logic;
    dev0_usbreg_dev_connect_i : in std_logic;
    usbreg_setup_i : in std_logic;
    usbreg_setup_dma_o : out std_logic;

    sync_sieint_epinfo_req_i    : in  std_logic;
    sync_sieint_epinfo_epnr_i   : in  std_logic_vector(3 downto 0);
    sync_sieint_epinfo_epdir_i  : in  std_logic;
    sync_sieint_epinfo_setup_i  : in  std_logic;
    sync_sieint_setup_received_i: in  std_logic;
    sync_sieint_rx_nbytes_i     : in  std_logic_vector(RXNBYTES_BITS-1 downto 0);
    sync_sieint_rxdata_i        : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
    sync_sieint_rxdatavalid_i   : in  std_logic;
    sync_sieint_endtransfer_i   : in  std_logic;
    sync_sieint_success_i       : in  std_logic;
    sync_sieint_error_i         : in  std_logic;
    sync_sieint_errortype_i     : in  std_logic_vector(3 downto 0);
    sync_sieint_sentNAK_i       : in  std_logic;
    sync_sieint_txdatafetched_i : in  std_logic;

    epinfo_sync_valid_dma           : in  std_logic;
    epinfo_sync_active_dma          : in  std_logic;
    epinfo_sync_disabled_dma        : in  std_logic;
    epinfo_sync_toggle_dma          : in  std_logic;
    epinfo_sync_stall_dma           : in  std_logic;
    epinfo_sync_iso_dma             : in  std_logic;
    epinfo_sync_ratefeedbackmode_dma: in  std_logic;
    epinfo_sync_nbytes_dma          : in  std_logic_vector(TXNBYTES_BITS-1 downto 0);
    epinfo_sync_maxpacket_dma       : in  std_logic_vector(1 downto 0);
    epinfo_sync_txdata_dma          : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
    epinfo_sync_txdata_valid_dma    : in  std_logic;

    sync_sieint_epinfo_req_o    : out std_logic;
    sync_sieint_epinfo_epnr_o   : out std_logic_vector(3 downto 0);
    sync_sieint_epinfo_epdir_o  : out std_logic;
    sync_sieint_epinfo_setup_o  : out std_logic;
    sync_sieint_rx_nbytes_o     : out std_logic_vector(RXNBYTES_BITS-1 downto 0);
    sync_sieint_rxdata_o        : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
    sync_sieint_rxdatavalid_o   : out std_logic;
    sync_sieint_endtransfer_o   : out std_logic;
    sync_sieint_success_o       : out std_logic;
    sync_sieint_sentNAK_o       : out std_logic;
    sync_sieint_txdatafetched_o : out std_logic;

    sync_sieint_setup_received_o: out std_logic;
    sync_sieint_error_o         : out std_logic;
    sync_sieint_errortype_o     : out std_logic_vector(3 downto 0);

    epinfo_sync_valid_o           : out std_logic;
    epinfo_sync_active_o          : out std_logic;
    epinfo_sync_disabled_o        : out std_logic;
    epinfo_sync_toggle_o          : out std_logic;
    epinfo_sync_stall_o           : out std_logic;
    epinfo_sync_iso_o             : out std_logic;
    epinfo_sync_ratefeedbackmode_o: out std_logic;
    epinfo_sync_nbytes_o          : out std_logic_vector(TXNBYTES_BITS-1 downto 0);
    epinfo_sync_maxpacket_o       : out std_logic_vector(1 downto 0);
    epinfo_sync_txdata_o          : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
    epinfo_sync_txdata_valid_o    : out std_logic;

    setup_pkt_vld   : out std_logic;
    setup_pkt       : out std_logic_vector(63 downto 0);
    setup_generation_o : out std_logic_vector(11 downto 0);
    setup_owner_ocp_o : out std_logic;
    post_sync_arb_state_o : out std_logic_vector(2 downto 0);

    ctrl_out_data   : out std_logic_vector(31 downto 0);
    ctrl_out_vld    : out std_logic;
    ctrl_out_last   : out std_logic;
    ctrl_out_rdy    : in  std_logic;

    ctrl_in_data    : in  std_logic_vector(31 downto 0);
    ctrl_in_be      : in  std_logic_vector(3 downto 0);
    ctrl_in_vld     : in  std_logic;
    ctrl_in_last    : in  std_logic;
    ctrl_in_rdy     : out std_logic;
    ctrl_in_resp_bytes : in  std_logic_vector(6 downto 0);
    ctrl_in_resp_known : in  std_logic;

    ctrl_set_stall  : in  std_logic;
    ctrl_xfer_done  : out std_logic;
    ctrl_xfer_abort : out std_logic;
    fifo_batch_abort : out std_logic;
    fifo_batch_reset : out std_logic;
    ctrl_length_error : out std_logic;

    ocp_path_disable_i : in  std_logic;
    ocp_claim_abort_i : in std_logic;
    fw_protocol_error_req_i : in std_logic;
    fifo_payload_available_i : in std_logic;
    fifo_free_dwords_i : in std_logic_vector(6 downto 0);
    fifo_reservation_active_o : out std_logic
  );
end entity usb_ocp_recovery_post_sync_arb;

architecture rtl of usb_ocp_recovery_post_sync_arb is

  constant C_HUB_SEL  : integer := 0;
  constant C_DEV0_SEL : integer := 1;
  constant C_DEV1_SEL : integer := 2;

  -- ======================================================================
  -- Mirrored SETUP monitor + claimed OCP transfer engine.
  --
  -- USB 2.0 Section 8.5.3 requires every SETUP to supersede the prior control
  -- transfer. The request, payload, completion, and notification therefore stay
  -- on the physical DMA path. Classification only suppresses successful-SETUP
  -- completion and selects OCP ownership for later EP0 stages.
  --
  -- Claimed OUT data uses an eight-beat packet store. The store commits one
  -- DWORD per handshake after successful exact-length accepted OUT DATA,
  -- including HS NYET (USB 2.0 Sec 8.5.1; OCP Recovery v1.1 Sec 8.5.1).
  -- All OUT drains own the store and decoder independently of ordinary SETUP
  -- supersession. Firmware claim-abort is an emergency cancellation of unread
  -- RX, not a CMS flush; bus/device reset retains its separate reset policy.
  -- Complete SETUP publication needs no gate: at the supported >=60 MHz hclk
  -- and 60 MHz PHY, its conservative bound is 28 PHY periods - 1 hclk,
  -- beyond the maximum 16 drain edges plus decoder completion (safe at +18).
  -- Early SETUP tokens can still overlap drain and cannot reset the decoder.
  -- This reuses the packet store and decoder command/offset; no rollback RAM
  -- or duplicate command/cursor registers are needed. EP0 response metadata is
  -- snapped per transaction while TX payload is retained for replay. Transaction
  -- identity keeps non-EP0 DMA traffic independent of retained EP0 ownership.
  -- FIFO writes reserve the exact requested DWORD capacity across PING/retry.
  --
  -- Control-IN captures the complete single-packet response before launch.
  -- An eight-beat store retains the decoder's snapshot through DATA retries
  -- and STATUS; only the per-attempt byte cursor advances on PIE fetches.
  -- Failed owned IN DATA rewinds that cursor, never the producer, as required
  -- by USB 2.0 Sec 8.5.3.3 and Sec 8.6.4 (retry without an ACK).
  -- The fill count doubles as write position; existing half-word assembly,
  -- response metadata and producer-done flag avoid another FSM/ready register.
  --
  -- Independent IN/OUT sequence bits start at DATA1 after SETUP. OUT advances
  -- at packet acceptance, IN only at ACK-qualified completion (Sec 8.6.1-4).
  -- In this single-packet profile the advanced OUT bit also marks accepted
  -- DATA through drain/STATUS, so no additional duplicate/commit state is
  -- needed. Physical request direction selects both live and snapped PID.
  -- The unused direction stays DATA1 for STATUS (Sec 8.5.3). Duplicate OUT
  -- requests remain active for PIE PID discard, never restart the RX store,
  -- and cannot complete the opposite-direction STATUS.
  -- ======================================================================

  constant BYTES_PER_BEAT   : integer := USB_DATAWIDTH / 8;   -- 8 for 64b
  constant RX_PACKET_BEATS  : integer := 8;
  constant TX_MAXBYTES      : integer := 64;
  constant TX_PACKET_BEATS  : integer := TX_MAXBYTES / BYTES_PER_BEAT;
  constant REC_IFACE_SLV    : std_logic_vector(7 downto 0)
           := std_logic_vector(to_unsigned(C_REC_IFACE_NUM, 8));
  constant OCP_BMRT_TYPE_CLASS : std_logic_vector(1 downto 0) := "01";
  constant OCP_BMRT_RECIPIENT_IFACE : std_logic_vector(4 downto 0)
           := "00001";
  constant OCP_SETUP_RESERVED_BYTE : std_logic_vector(7 downto 0)
           := x"00";
  -- OCP Recovery v1.1 Sec 8.5: class-specific control transfer bRequest.
  constant OCP_RECOVERY_TRANSFER : std_logic_vector(7 downto 0) := x"00";
  constant OCP_INDIRECT_FIFO_DATA : std_logic_vector(7 downto 0) := x"2F";

  type t_trap_state is (T_IDLE, T_MIRROR, T_META_WAIT,
                        T_DATA, T_STATUS, T_PROT_STALL);
  signal st : t_trap_state;
  signal st_next : t_trap_state;

  signal cap_rxdata    : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal cap_rx_nbytes : std_logic_vector(RXNBYTES_BITS-1 downto 0);
  signal cap_done      : std_logic;
  signal end_seen      : std_logic;
  signal succ_seen     : std_logic;
  signal sp_sent       : std_logic;

  signal new_setup_c : std_logic;
  signal dma_req_forward_c : std_logic;
  signal is_ocp  : std_logic;
  signal incoming_is_ocp_c : std_logic;
  signal ep0_ocp_owner_r : std_logic;
  signal dev0_ep0_req_c : std_logic;
  signal ocp_resp_sel_c : std_logic;
  signal replacement_stall_r : std_logic;
  signal wire_ocp_r : std_logic;
  signal wire_dma_r : std_logic;
  signal dma_valid_seen_r : std_logic;
  signal dma_epnr_r : std_logic_vector(3 downto 0);
  signal dma_epdir_r : std_logic;
  signal dma_setup_r : std_logic;
  signal setup_pending_r : std_logic;
  signal setup_pending_low_seen_r : std_logic;
  signal drop_setup_success_r : std_logic;
  signal drop_dma_valid_seen_r : std_logic;
  signal usbreg_setup_dma_c : std_logic;
  signal dma_success_c : std_logic;
  signal dev0_selected_c : std_logic;
  signal dev0_local_reset_c : std_logic;
  signal ocp_teardown_c : std_logic;
  signal ocp_stage_accept_c : std_logic;
  signal dma_txn_done_c : std_logic;
  signal dma_owner_r : std_logic_vector(1 downto 0);
  signal setup_dma_owner_r : std_logic_vector(1 downto 0);
  signal setup_dma_match_c : std_logic;

  signal xfer_dir_in_r       : std_logic;              -- SETUP dir (1=IN)
  signal nbytes_r            : unsigned(15 downto 0);  -- Full SETUP wLength
  signal tx_response_bytes_r : unsigned(6 downto 0);
  signal tx_response_known_r : std_logic;

  signal in_data_toggle_r : std_logic;
  signal out_data_toggle_r : std_logic;
  signal zlp_phase_r      : std_logic;
  signal zlp_owed_c       : std_logic;

  -- Successful owned transaction pulse; stage consumers also check direction.
  signal st_end_c : std_logic;

  -- Control-OUT packet store. A packet is invisible downstream until the
  -- link reports a successful EOP with the exact expected byte count.
  type t_rx_buf is array (0 to RX_PACKET_BEATS-1)
                     of std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal rx_buf_r            : t_rx_buf;
  signal rx_captured_beats_r : unsigned(3 downto 0);
  signal rx_word_index_r     : unsigned(4 downto 0);
  signal rx_total_words_r    : unsigned(4 downto 0);
  signal rx_total_bytes_r    : unsigned(6 downto 0);
  signal rx_validated_r      : std_logic;
  signal rx_backend_busy_c   : std_logic;
  signal rx_data_good_c      : std_logic;
  signal rx_duplicate_window_c : std_logic;
  signal rx_drain_done_r     : std_logic;
  signal rx_expected_beats_c : unsigned(3 downto 0);
  signal rx_expected_words_c : unsigned(4 downto 0);
  signal rx_capture_c        : std_logic;
  signal rx_drain_active_c   : std_logic;
  signal rx_last_word_c      : std_logic;
  signal rx_length_error_r   : std_logic;
  signal setup_length_error_c : std_logic;
  signal ctrl_out_data_c     : std_logic_vector(31 downto 0);
  signal ctrl_out_vld_c      : std_logic;
  signal ctrl_out_last_c     : std_logic;
  signal ctrl_xfer_abort_c   : std_logic;

  -- Retained Control-IN packet (SV 32b words -> SIE 64b beats).
  type t_tx_buf is array (0 to TX_PACKET_BEATS-1)
                     of std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal tx_buf_r             : t_tx_buf;
  signal tx_fill_beats_r      : natural range 0 to TX_PACKET_BEATS;
  signal tx_half_word_r       : std_logic_vector(31 downto 0);
  signal tx_half_word_valid_r : std_logic;
  signal tx_producer_done_r   : std_logic;
  signal tx_bytes_sent_r      : unsigned(6 downto 0);
  signal ctrl_in_rdy_c        : std_logic;
  signal tx_in_data_c         : std_logic;
  signal tx_launch_ready_c    : std_logic;
  signal tx_beat_valid_c      : std_logic;
  signal tx_advance_c         : std_logic;
  signal tx_remaining_bytes_c : unsigned(6 downto 0);

  signal setup_pkt_vld_c : std_logic;
  signal setup_pkt_ready_c : std_logic;
  signal setup_complete_c : std_logic;
  signal setup_valid_c : std_logic;
  signal setup_claim_c : std_logic;
  signal dev0_dbg_setup_generation_r : unsigned(11 downto 0);
  signal dev0_dbg_setup_owner_ocp_r : std_logic;

  -- A FIFO-space reservation survives PING and CRC retry. It also tags the
  -- packet store's FIFO owner through RX capture and accepted drain, avoiding
  -- a duplicate command tag. Firmware cannot mutate reserved FIFO capacity.
  signal fifo_reservation_r : std_logic;
  signal fifo_words_needed_c : unsigned(6 downto 0);
  signal fifo_capacity_ok_c : std_logic;
  signal fifo_admission_ok_c : std_logic;
  signal fifo_out_request_c : std_logic;
  signal fifo_out_context_c : std_logic;
  signal fifo_rx_pending_c : std_logic;
  signal fifo_batch_abort_c : std_logic;
  signal fifo_batch_reset_c : std_logic;
  signal setup_received_c : std_logic;

  -- EP0 response ownership/metadata is transaction-scoped. The retained TX
  -- store is indexed independently so the SIE can fetch successive beats.
  signal rsp_snap_valid_r : std_logic;
  signal rsp_snap_active_r : std_logic;
  signal rsp_snap_stall_r : std_logic;
  signal rsp_snap_disabled_r : std_logic;
  signal rsp_snap_toggle_r : std_logic;
  signal rsp_snap_nbytes_r : std_logic_vector(TXNBYTES_BITS-1 downto 0);
  signal rsp_snap_maxpacket_r : std_logic_vector(1 downto 0);
  signal rsp_snap_iso_r : std_logic;
  signal rsp_snap_ratefeedback_r : std_logic;
  signal rsp_live_valid_c : std_logic;
  signal rsp_live_active_c : std_logic;
  signal rsp_live_stall_c : std_logic;
  signal rsp_live_disabled_c : std_logic;
  signal rsp_live_toggle_c : std_logic;
  signal rsp_live_nbytes_c : std_logic_vector(TXNBYTES_BITS-1 downto 0);
  signal rsp_live_maxpacket_c : std_logic_vector(1 downto 0);
  signal rsp_live_iso_c : std_logic;
  signal rsp_live_ratefeedback_c : std_logic;

  constant NBYTES8 : std_logic_vector(TXNBYTES_BITS-1 downto 0)
                     := std_logic_vector(to_unsigned(8, TXNBYTES_BITS));

  function mask_word32(data : std_logic_vector(31 downto 0);
                       be   : std_logic_vector(3 downto 0))
    return std_logic_vector is
    variable masked_v : std_logic_vector(31 downto 0);
  begin
    masked_v := (others => '0');
    for idx in 0 to 3 loop
      if be(idx) = '1' then
        masked_v(idx*8+7 downto idx*8) := data(idx*8+7 downto idx*8);
      end if;
    end loop;
    return masked_v;
  end function;

  begin
    assert USB_DATAWIDTH = 64
      report "post_sync_arb: packet assembly requires USB_DATAWIDTH = 64"
      severity failure;

    -- ------------------------------------------------------------------
    -- Control decodes.
    -- ------------------------------------------------------------------
    dev0_selected_c <= '1' when
      unsigned(pie_dev_selected_i) = to_unsigned(C_DEV0_SEL, 2) else '0';
    dev0_local_reset_c <= dev0_port_reset_i or
                          not dev0_usbreg_dev_connect_i;

    new_setup_c <= '1' when (dev0_selected_c = '1')
                            and (sync_sieint_epinfo_req_i = '1')
                            and (sync_sieint_epinfo_setup_i = '1')
                            and (sync_sieint_epinfo_epnr_i = "0000")
                    else '0';

    dev0_ep0_req_c <= '1' when (dev0_selected_c = '1')
                                   and (sync_sieint_epinfo_req_i = '1')
                                   and (sync_sieint_epinfo_epnr_i = "0000")
                              else '0';
    ocp_teardown_c <= dev0_local_reset_c or ocp_claim_abort_i;
    -- Claimed Device 0 EP0 DATA/STATUS request accepted by the local OCP
    -- responder. During teardown the stale claim must not answer the request;
    -- it is also not forwarded to DMA, so the PIE times out on it.
    ocp_stage_accept_c <= '1' when (dev0_ep0_req_c = '1') and
                                   (sync_sieint_epinfo_setup_i = '0') and
                                   (ep0_ocp_owner_r = '1') and
                                   (ocp_teardown_c = '0') else '0';
    ocp_resp_sel_c <= '0' when (sync_sieint_epinfo_req_i = '1') and
                                   (sync_sieint_epinfo_setup_i = '1') else
                      '1' when (wire_ocp_r = '1') or
                               (ocp_stage_accept_c = '1')
                                else '0';

    -- OCP-recovery class match on the captured SETUP (little-endian, USB 2.0
    -- Sec 9.3 Tbl 9-2; OCP Recovery v1.1 Sec 8.5).
    is_ocp <= '1' when (cap_done = '1')
                   and (cap_rxdata( 6 downto  5) = OCP_BMRT_TYPE_CLASS)
                   and (cap_rxdata( 4 downto  0) = OCP_BMRT_RECIPIENT_IFACE)
                   and (cap_rxdata(15 downto  8) = OCP_RECOVERY_TRANSFER)
                   and (cap_rxdata(39 downto 32) = REC_IFACE_SLV)
                   and (cap_rxdata(47 downto 40) = OCP_SETUP_RESERVED_BYTE)
                   and (ocp_path_disable_i = '0')
               else '0';
    incoming_is_ocp_c <= '1' when
                    (sync_sieint_rxdata_i(6 downto 5) = OCP_BMRT_TYPE_CLASS)
                and (dev0_selected_c = '1')
                and (sync_sieint_rxdata_i(4 downto 0) = OCP_BMRT_RECIPIENT_IFACE)
                and (sync_sieint_rxdata_i(15 downto 8) = OCP_RECOVERY_TRANSFER)
                and (sync_sieint_rxdata_i(39 downto 32) = REC_IFACE_SLV)
                and (sync_sieint_rxdata_i(47 downto 40) = OCP_SETUP_RESERVED_BYTE)
                and (ocp_path_disable_i = '0')
              else '0';
    setup_dma_match_c <= '1' when
      (wire_dma_r = '1') and
      (dma_setup_r = '1') and
      (dma_epnr_r = "0000") and
      (dma_owner_r = setup_dma_owner_r) and
      (setup_dma_owner_r =
       std_logic_vector(to_unsigned(C_DEV0_SEL, 2))) else '0';

    -- usb_dma samples usbreg_setup in IDLE and READ_EPINFO_SKIP. The immediate
    -- term covers the request edge and the held term covers skip scanning until
    -- the matched DMA response-valid interval begins.
    usbreg_setup_dma_c <= usbreg_setup_i and
      not ((new_setup_c or setup_pending_r) and dev0_selected_c);
    usbreg_setup_dma_o <= usbreg_setup_dma_c;

    -- Stage-end pulse (hclk endtransfer is already single-cycle; qualify with
    -- success so a NAK/error edge does not advance the claim FSM).
    st_end_c <= sync_sieint_endtransfer_i and sync_sieint_success_i
                and wire_ocp_r;
    setup_complete_c <= end_seen or sync_sieint_endtransfer_i;
    setup_valid_c <= '1' when
        ((cap_done = '1') or (sync_sieint_rxdatavalid_i = '1')) and
        ((succ_seen = '1') or (sync_sieint_success_i = '1')) and
        ((unsigned(cap_rx_nbytes) =
          to_unsigned(8, cap_rx_nbytes'length)) or
         (((sync_sieint_success_i = '1') or
           (sync_sieint_endtransfer_i = '1')) and
          (unsigned(sync_sieint_rx_nbytes_i) =
           to_unsigned(8, sync_sieint_rx_nbytes_i'length))))
      else '0';
    setup_claim_c <= '1' when
        ((cap_done = '1') and (is_ocp = '1')) or
        ((sync_sieint_rxdatavalid_i = '1') and
         (incoming_is_ocp_c = '1'))
      else '0';

    setup_generation_o <= std_logic_vector(dev0_dbg_setup_generation_r);
    setup_owner_ocp_o <= dev0_dbg_setup_owner_ocp_r;
    with st select post_sync_arb_state_o <=
      "000" when T_IDLE,
      "001" when T_MIRROR,
      "010" when T_META_WAIT,
      "011" when T_DATA,
      "100" when T_STATUS,
      "101" when T_PROT_STALL;

    setup_debug_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        dev0_dbg_setup_generation_r <= (others => '0');
        dev0_dbg_setup_owner_ocp_r <= '0';
      elsif rising_edge(hclk) then
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') then
          dev0_dbg_setup_generation_r <= (others => '0');
          dev0_dbg_setup_owner_ocp_r <= '0';
        elsif (new_setup_c /= '0') or (ocp_claim_abort_i /= '0') or
              ((fw_protocol_error_req_i = '1') and (ep0_ocp_owner_r = '1')) then
          dev0_dbg_setup_generation_r <= dev0_dbg_setup_generation_r;
          dev0_dbg_setup_owner_ocp_r <= dev0_dbg_setup_owner_ocp_r;
        else
          -- Leaving MIRROR counts the completed current SETUP only once.
          if (st = T_MIRROR) and (setup_complete_c = '1') and
             (setup_valid_c = '1') then
            dev0_dbg_setup_generation_r <= dev0_dbg_setup_generation_r + 1;
            dev0_dbg_setup_owner_ocp_r <= setup_claim_c;
          end if;
        end if;
      end if;
    end process setup_debug_clk_proc;

    -- setup_pkt to the SV recovery stack: pulse once per claimed SETUP.
    setup_pkt_ready_c <= '1' when ((st = T_MIRROR) or (st = T_META_WAIT))
                             and (cap_done = '1')
                             and (is_ocp = '1') and (sp_sent = '0')
                             and ((end_seen = '1') or
                                  (sync_sieint_endtransfer_i = '1'))
                             and ((succ_seen = '1') or
                                  (sync_sieint_success_i = '1'))
                             and ((unsigned(cap_rx_nbytes) =
                                   to_unsigned(8, cap_rx_nbytes'length)) or
                                  (((sync_sieint_success_i = '1') or
                                    (sync_sieint_endtransfer_i = '1')) and
                                   (unsigned(sync_sieint_rx_nbytes_i) =
                                    to_unsigned(8,
                                      sync_sieint_rx_nbytes_i'length))))
                         else '1' when (st = T_MIRROR) and (sp_sent = '0')
                             and (sync_sieint_rxdatavalid_i = '1')
                             and (incoming_is_ocp_c = '1')
                             and ((end_seen = '1') or
                                  (sync_sieint_endtransfer_i = '1'))
                             and ((succ_seen = '1') or
                                  (sync_sieint_success_i = '1'))
                             and (unsigned(sync_sieint_rx_nbytes_i) =
                                  to_unsigned(8, sync_sieint_rx_nbytes_i'length))
                         else '0';
    setup_pkt_vld_c <= setup_pkt_ready_c and not new_setup_c and not ocp_teardown_c
                       and not sync_busreset;
    setup_pkt <= sync_sieint_rxdata_i
      when (st = T_MIRROR) and (sync_sieint_rxdatavalid_i = '1')
      else cap_rxdata;
    setup_pkt_vld <= setup_pkt_vld_c;

    -- ------------------------------------------------------------------
    -- Complete-packet Control-OUT staging (SIE 64b beats -> SV 32b words).
    -- ------------------------------------------------------------------
    rx_expected_beats_c <= resize(shift_right(nbytes_r +
                              to_unsigned(BYTES_PER_BEAT-1, nbytes_r'length), 3), 4);
    rx_expected_words_c <= resize(shift_right(nbytes_r +
                               to_unsigned(3, nbytes_r'length), 2), 5);
    rx_capture_c <= '1' when (st = T_DATA) and (xfer_dir_in_r = '0')
                            and (out_data_toggle_r = '1')
                            and (wire_ocp_r = '1')
                            and (sync_sieint_epinfo_epdir_i = '0')
                            and (sync_sieint_epinfo_setup_i = '0')
                            and (sync_sieint_rxdatavalid_i = '1')
                            and (rx_backend_busy_c = '0')
                       else '0';
    rx_backend_busy_c <= rx_validated_r or rx_drain_done_r;
    rx_drain_active_c <= rx_validated_r and not sync_busreset
                         and not dev0_local_reset_c and not ocp_claim_abort_i;

    rxstream_comb_proc : process (rx_drain_active_c, rx_word_index_r,
                                  rx_total_bytes_r, rx_total_words_r, rx_buf_r)
      variable beat_v : integer range 0 to RX_PACKET_BEATS-1;
      variable word_v : std_logic_vector(31 downto 0);
    begin
      ctrl_out_data_c <= (others => '0');
      ctrl_out_vld_c  <= '0';
      ctrl_out_last_c <= '0';
      rx_last_word_c  <= '0';
      if rx_drain_active_c = '1' then
        beat_v := to_integer(rx_word_index_r(4 downto 1));
        if rx_word_index_r(0) = '0' then
          word_v := rx_buf_r(beat_v)(31 downto 0);
        else
          word_v := rx_buf_r(beat_v)(63 downto 32);
        end if;
        ctrl_out_data_c <= word_v;
        ctrl_out_vld_c  <= '1';
        if rx_word_index_r = (rx_total_words_r - 1) then
          ctrl_out_last_c <= '1';
          rx_last_word_c  <= '1';
        end if;
      end if;
    end process rxstream_comb_proc;

    ctrl_out_data <= ctrl_out_data_c;
    ctrl_out_vld  <= ctrl_out_vld_c;
    ctrl_out_last <= ctrl_out_last_c;

    -- ------------------------------------------------------------------
    -- Complete Control-IN capture and non-destructive per-attempt readout.
    -- ------------------------------------------------------------------
    tx_in_data_c <= '1' when (ep0_ocp_owner_r = '1') and (st = T_DATA)
                             and (xfer_dir_in_r = '1') and (zlp_phase_r = '0')
                     else '0';
    tx_remaining_bytes_c <= tx_response_bytes_r - tx_bytes_sent_r
                            when tx_response_bytes_r >= tx_bytes_sent_r
                            else (others => '0');
    tx_advance_c <= '1' when (tx_beat_valid_c = '1')
                             and (sync_sieint_txdatafetched_i = '1')
                             and (sync_sieint_epinfo_epdir_i = '1')
                             and (sync_sieint_epinfo_setup_i = '0')
                             and (tx_remaining_bytes_c >
                                  to_unsigned(BYTES_PER_BEAT, tx_remaining_bytes_c'length))
                    else '0';
    -- A zero-byte final terminator needs no storage, even after 64 bytes.
    -- Cleanup suppresses handshakes so discarded data cannot reach the decoder.
    ctrl_in_rdy_c <= '1' when (ep0_ocp_owner_r = '1')
                              and (xfer_dir_in_r = '1')
                              and ((st = T_META_WAIT) or (st = T_DATA))
                              and (sp_sent = '1')
                              and (tx_producer_done_r = '0')
                              and ((tx_fill_beats_r < TX_PACKET_BEATS) or
                                   ((ctrl_in_last = '1') and (ctrl_in_be = "0000")
                                    and (tx_half_word_valid_r = '0')))
                              and (new_setup_c = '0') and (sync_busreset = '0')
                              and (ocp_teardown_c = '0') else '0';
    ctrl_in_rdy   <= ctrl_in_rdy_c;

    zlp_owed_c <= '1' when (xfer_dir_in_r = '1') and (tx_response_known_r = '1')
                            and (tx_response_bytes_r =
                                 to_unsigned(TX_MAXBYTES, tx_response_bytes_r'length))
                            and (nbytes_r >
                                 resize(tx_response_bytes_r, nbytes_r'length))
                     else '0';
    tx_launch_ready_c <= '1' when (tx_producer_done_r = '1')
                                  and (tx_response_known_r = '1')
                                  and (tx_half_word_valid_r = '0')
                                  and (tx_response_bytes_r <=
                                       to_unsigned(TX_MAXBYTES, tx_response_bytes_r'length))
                                  and (resize(tx_response_bytes_r, nbytes_r'length) <= nbytes_r)
                                  and (to_unsigned(tx_fill_beats_r, tx_response_bytes_r'length) =
                                       to_unsigned((to_integer(tx_response_bytes_r) +
                                                    BYTES_PER_BEAT-1) / BYTES_PER_BEAT,
                                                   tx_response_bytes_r'length)) else '0';
    -- Use the request snapshot, not live readiness: finishing capture after
    -- an early IN was NAKed must not turn that transaction into DATA.
    tx_beat_valid_c <= '1' when (tx_launch_ready_c = '1') and (tx_in_data_c = '1')
                               and (wire_ocp_r = '1')
                               and (sync_sieint_epinfo_req_i = '0')
                               and (rsp_snap_valid_r = '1')
                               and (rsp_snap_active_r = '1')
                               and (rsp_snap_stall_r = '0')
                               and (rsp_snap_disabled_r = '0')
                               and (tx_remaining_bytes_c /=
                                    to_unsigned(0, tx_remaining_bytes_c'length))
                       else '0';

    fifo_words_needed_c <= resize(shift_right(nbytes_r +
                                  to_unsigned(3, nbytes_r'length), 2), 7);
    fifo_capacity_ok_c <= '1' when
      unsigned(fifo_free_dwords_i) >= fifo_words_needed_c
      else '0';
    fifo_admission_ok_c <= fifo_capacity_ok_c and
                           not fifo_payload_available_i;
    fifo_out_request_c <= '1' when (st = T_DATA) and (xfer_dir_in_r = '0')
                                  and (out_data_toggle_r = '1')
                                  and (cap_rxdata(23 downto 16) =
                                       OCP_INDIRECT_FIFO_DATA)
                                  and (dev0_ep0_req_c = '1')
                                  and (sync_sieint_epinfo_epdir_i = '0')
                                  and (sync_sieint_epinfo_setup_i = '0')
                              else '0';
    fifo_reservation_active_o <= (fifo_reservation_r or
                                 (fifo_out_request_c and fifo_admission_ok_c))
                                 and not ocp_claim_abort_i;
    -- Reject oversized OUT requests rather than forwarding a truncated payload.
    -- IN responses may be shorter than wLength. Preserve the requested length
    -- and actual response size to determine whether a terminating ZLP is needed.
    setup_length_error_c <= '1' when (st = T_META_WAIT) and
                                      (sp_sent = '1') and
                                      (rx_backend_busy_c = '0') and
                                      (xfer_dir_in_r = '0') and
                                      (nbytes_r >
                                       to_unsigned(TX_MAXBYTES, nbytes_r'length))
                              else '0';

    -- These values are snapped on each claimed EP0 request. IN STATUS waits
    -- for a write drain, but duplicate OUT must reach PIE's PID-discard path.
    -- PIE checks active before ignore_data at EOP, so busy cannot NAK these
    -- requests (USB 2.0 Sec 8.6.4). The OUT sequence bit is the accepted marker
    -- only within the supported single-packet write DATA/STATUS lifetime.
    rx_duplicate_window_c <= '1' when
        ((st = T_DATA) or (st = T_STATUS)) and
        (xfer_dir_in_r = '0') and (out_data_toggle_r = '0') and
        (sync_sieint_epinfo_epdir_i = '0') and
        (sync_sieint_epinfo_setup_i = '0') else '0';
    rsp_live_valid_c <= '1';
    rsp_live_stall_c <= '1' when ((st = T_PROT_STALL) or
                                  (ctrl_set_stall = '1') or
                                  (rx_length_error_r = '1'))
                               and (sync_sieint_epinfo_setup_i = '0') else '0';
    rsp_live_active_c <=
        '0' when (rsp_live_stall_c = '1') else
        '1' when (sync_sieint_epinfo_setup_i = '1') else
        '1' when (rx_duplicate_window_c = '1') else
        '0' when (st = T_META_WAIT) else
        '0' when (rx_backend_busy_c = '1') else
        '0' when (st = T_DATA) and (xfer_dir_in_r = '1')
                 and (tx_launch_ready_c = '0') else
        '0' when (st = T_DATA) and (xfer_dir_in_r = '0')
                 and (cap_rxdata(23 downto 16) = OCP_INDIRECT_FIFO_DATA)
                 and (fifo_reservation_r = '0') and
                     (fifo_admission_ok_c = '0') else
        '0' when (st = T_DATA) and (xfer_dir_in_r = '0')
                 and ((rx_captured_beats_r /= to_unsigned(0, rx_captured_beats_r'length))
                      or (rx_validated_r = '1')) else
        '0' when (st = T_STATUS) and (xfer_dir_in_r = '0')
                 and (fifo_reservation_r = '0')
                 and ((rx_captured_beats_r /= to_unsigned(0, rx_captured_beats_r'length))
                      or (rx_validated_r = '1')) else
        '1';
    rsp_live_disabled_c <= '0';
    rsp_live_toggle_c <= in_data_toggle_r
                          when sync_sieint_epinfo_epdir_i = '1' else
                         out_data_toggle_r;
    -- Preserve the original nonzero DATA length for duplicate OUT, not the
    -- opposite-direction STATUS ZLP. PIE handles ACK/discard by PID mismatch
    -- (USB 2.0 Sec 8.6.4); this metadata does not advertise extra RX capacity.
    rsp_live_nbytes_c <=
        NBYTES8 when (sync_sieint_epinfo_setup_i = '1') else
        std_logic_vector(resize(nbytes_r, TXNBYTES_BITS))
          when (rx_duplicate_window_c = '1') else
        (others => '0') when (st = T_META_WAIT) or (st = T_PROT_STALL)
                              or (st = T_STATUS)
                              or (rx_drain_done_r = '1')
                              or (zlp_phase_r = '1') else
        std_logic_vector(resize(tx_response_bytes_r, TXNBYTES_BITS))
          when (st = T_DATA) and (xfer_dir_in_r = '1') else
        std_logic_vector(resize(nbytes_r, TXNBYTES_BITS));
    rsp_live_maxpacket_c <= "00";
    rsp_live_iso_c <= '0';
    rsp_live_ratefeedback_c <= '0';

    -- End-of-stage pulse to the SV decoder (OUT: after RX drain; IN: on the
    -- endtransfer once the launch contract is met so an early-IN NAK edge does
    -- not trip the decoder's early-termination escape).
    ctrl_xfer_done <= rx_drain_done_r when (rx_backend_busy_c = '1') or
                                           (xfer_dir_in_r = '0') else
                       (st_end_c and tx_launch_ready_c)
                         when ((st = T_DATA) or (st = T_STATUS))
                              and (wire_ocp_r = '1') else '0';
    ctrl_xfer_abort_c <= '1' when (dev0_local_reset_c = '1')
                                 or (sync_busreset = '1')
                                 or (ocp_claim_abort_i = '1')
                                 or (rx_length_error_r = '1')
                                 or (setup_length_error_c = '1')
                                 or ((ep0_ocp_owner_r = '1') and
                                     (new_setup_c = '1') and
                                     (rx_backend_busy_c = '0'))
                        else '0';
    ctrl_xfer_abort <= ctrl_xfer_abort_c;
    -- Physical reset clears CMS independently of the current RX lifecycle.
    fifo_batch_reset_c <= sync_busreset or dev0_local_reset_c;
    fifo_out_context_c <= '1' when (ep0_ocp_owner_r = '1') and
                                  (xfer_dir_in_r = '0') and
                                  (cap_rxdata(23 downto 16) =
                                   OCP_INDIRECT_FIFO_DATA) else '0';
    fifo_rx_pending_c <= '1' when (fifo_out_context_c = '1') and
                                 ((st = T_META_WAIT) or (st = T_DATA)) and
                                 (rx_backend_busy_c = '0') else '0';
    -- BATCH_ABORTED diagnoses pending FIFO cancellation, including zero DATA
    -- without a reservation. STATUS cannot cancel an already completed drain.
    -- A reservation identifies an older FIFO drain even while SETUP is mirrored.
    fifo_batch_abort_c <= '0' when fifo_batch_reset_c = '1' else
                         '1' when
                          ((new_setup_c = '1') and (fifo_rx_pending_c = '1')) or
                          ((ocp_claim_abort_i = '1') and
                           ((fifo_rx_pending_c = '1') or
                            ((fifo_reservation_r = '1') and (rx_validated_r = '1'))))
                          else '0';
    fifo_batch_abort <= fifo_batch_abort_c;
    fifo_batch_reset <= fifo_batch_reset_c;

    -- rx_data_good_c indicates that a complete, accepted OCP Control-OUT
    -- payload is eligible to drain from RX storage, without waiting for STATUS.
    -- This signal qualifies RX validation/drain startup and FIFO reservation
    -- retention; consumer reset/abort branches take priority over eligibility.
    -- rx_data_good_c is driven based on:
    -- - st_end_c: successful EOP for the OCP-owned transaction. PIE success
    --   means DATA accepted and ACK/NYET selected, not handshake completion
    --   (USB 2.0 Sec 8.5.1); PING does not report success.
    -- - st and xfer_dir_in_r: require the original request's OUT DATA stage.
    -- - sync_sieint_epinfo_epdir_i and sync_sieint_epinfo_setup_i: require
    --   physical OUT, not SETUP. At supported hclk >= PHY, accepted EOP
    --   crosses within 1 PHY + 3 hclk; ACK/NYET plus turnaround take at least
    --   7 PHY periods, so these bundled pins still identify that EOP
    --   (USB 2.0 Sec 7.1.18.2).
    -- - rx_backend_busy_c and out_data_toggle_r: reject another acceptance
    --   both during drain and after it finishes; failed attempts retain DATA1.
    -- - nbytes_r: require a nonzero request that fits the packet store.
    -- - sync_sieint_rx_nbytes_i: require the received byte count to match
    --   the original request exactly.
    -- - rx_captured_beats_r, rx_capture_c and rx_expected_beats_c: require
    --   exactly the expected beats, including a final beat arriving at EOP.
    --   Missing/excess beats fail; fresh capture also excludes stale IN
    --   completion, since IN captures no beats and failed OUT clears the count.
    rx_data_good_comb_proc : process (st_end_c, st, xfer_dir_in_r,
                                      sync_sieint_epinfo_epdir_i,
                                      sync_sieint_epinfo_setup_i,
                                      rx_backend_busy_c, out_data_toggle_r, nbytes_r,
                                      sync_sieint_rx_nbytes_i, rx_capture_c,
                                      rx_captured_beats_r, rx_expected_beats_c)
      variable effective_beats_v : unsigned(rx_captured_beats_r'length downto 0);
    begin
      rx_data_good_c <= '0';
      effective_beats_v := resize(rx_captured_beats_r, effective_beats_v'length);
      if rx_capture_c = '1' then
        effective_beats_v := effective_beats_v + 1;
      end if;
      if (st_end_c = '1') and
         (st = T_DATA) and (xfer_dir_in_r = '0') and
         (sync_sieint_epinfo_epdir_i = '0') and
         (sync_sieint_epinfo_setup_i = '0') and
         (rx_backend_busy_c = '0') and (out_data_toggle_r = '1') and
         (nbytes_r > to_unsigned(0, nbytes_r'length)) and
         (nbytes_r <= to_unsigned(TX_MAXBYTES, nbytes_r'length)) and
         (resize(unsigned(sync_sieint_rx_nbytes_i), nbytes_r'length) = nbytes_r) and
         (effective_beats_v = resize(rx_expected_beats_c, effective_beats_v'length)) then
        rx_data_good_c <= '1';
      end if;
    end process rx_data_good_comb_proc;

    ctrl_length_error <= rx_length_error_r or setup_length_error_c;

    -- ------------------------------------------------------------------
    -- Recovery transfer FSM.
    --
    -- Each state lists its own preemption priority so the transition behavior
    -- is visible from the origin state. Synchronous teardown is applied by the
    -- state register and therefore overrides every combinational transition.
    -- ------------------------------------------------------------------
    fsm_next_proc : process (st, new_setup_c, fw_protocol_error_req_i, ep0_ocp_owner_r,
                             setup_complete_c, setup_valid_c, setup_claim_c,
                             replacement_stall_r, ctrl_set_stall,
                             setup_length_error_c, nbytes_r,
                             rx_length_error_r, xfer_dir_in_r,
                             rx_drain_done_r, st_end_c, zlp_phase_r,
                             zlp_owed_c, sp_sent, sync_sieint_epinfo_epdir_i,
                             sync_sieint_epinfo_setup_i)
    begin
      st_next <= st;
      case st is
        when T_IDLE =>
          if new_setup_c = '1' then
            st_next <= T_MIRROR;
          elsif (fw_protocol_error_req_i = '1') and (ep0_ocp_owner_r = '1') then
            st_next <= T_PROT_STALL;
          end if;

        when T_MIRROR =>
          if new_setup_c = '1' then
            st_next <= T_MIRROR;
          elsif (fw_protocol_error_req_i = '1') and (ep0_ocp_owner_r = '1') then
            st_next <= T_PROT_STALL;
          elsif setup_complete_c = '1' then
            if (setup_valid_c = '1') and (setup_claim_c = '1') then
              st_next <= T_META_WAIT;
            elsif setup_valid_c = '1' then
              st_next <= T_IDLE;
            elsif replacement_stall_r = '1' then
              st_next <= T_PROT_STALL;
            else
              st_next <= T_IDLE;
            end if;
          end if;

        when T_META_WAIT =>
          if new_setup_c = '1' then
            st_next <= T_MIRROR;
          elsif (fw_protocol_error_req_i = '1') and (ep0_ocp_owner_r = '1') then
            st_next <= T_PROT_STALL;
          elsif sp_sent = '0' then
            st_next <= T_META_WAIT;
          elsif (ctrl_set_stall = '1') or
                (setup_length_error_c = '1') then
            st_next <= T_PROT_STALL;
          elsif nbytes_r = to_unsigned(0, nbytes_r'length) then
            st_next <= T_STATUS;
          else
            st_next <= T_DATA;
          end if;

        when T_DATA =>
          if new_setup_c = '1' then
            st_next <= T_MIRROR;
          elsif (fw_protocol_error_req_i = '1') and (ep0_ocp_owner_r = '1') then
            st_next <= T_PROT_STALL;
          elsif (ctrl_set_stall = '1') or (rx_length_error_r = '1') then
            st_next <= T_PROT_STALL;
          elsif (xfer_dir_in_r = '0') and (rx_drain_done_r = '1') then
            st_next <= T_STATUS;
          elsif (st_end_c = '1') and (xfer_dir_in_r = '1') and
                (sync_sieint_epinfo_epdir_i = '1') and
                (sync_sieint_epinfo_setup_i = '0') then
            if (zlp_phase_r = '0') and (zlp_owed_c = '1') then
              st_next <= T_DATA;
            else
              st_next <= T_STATUS;
            end if;
          end if;

        when T_STATUS =>
          if new_setup_c = '1' then
            st_next <= T_MIRROR;
          elsif (fw_protocol_error_req_i = '1') and (ep0_ocp_owner_r = '1') then
            st_next <= T_PROT_STALL;
          elsif ctrl_set_stall = '1' then
            st_next <= T_PROT_STALL;
          -- STATUS is opposite the DATA direction; without DATA it is IN.
          -- In particular, even a successful repeated OUT completion cannot
          -- retire a write's IN STATUS (USB 2.0 Sec 8.5.3/8.6.4).
          elsif (st_end_c = '1') and (sync_sieint_epinfo_setup_i = '0') and
                (((sync_sieint_epinfo_epdir_i = '1') and
                  ((xfer_dir_in_r = '0') or
                   (nbytes_r = to_unsigned(0, nbytes_r'length)))) or
                 ((sync_sieint_epinfo_epdir_i = '0') and
                  (xfer_dir_in_r = '1') and
                  (nbytes_r /= to_unsigned(0, nbytes_r'length)))) then
            st_next <= T_IDLE;
          end if;

        when T_PROT_STALL =>
          if new_setup_c = '1' then
            st_next <= T_MIRROR;
          elsif (fw_protocol_error_req_i = '1') and (ep0_ocp_owner_r = '1') then
            st_next <= T_PROT_STALL;
          end if;

        when others =>
          st_next <= T_IDLE;
      end case;
    end process fsm_next_proc;

    state_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        st <= T_IDLE;
      elsif rising_edge(hclk) then
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') or
           (ocp_claim_abort_i = '1') then
          st <= T_IDLE;
        else
          st <= st_next;
        end if;
      end if;
    end process state_clk_proc;

    setup_capture_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        cap_rxdata <= (others => '0');
        cap_rx_nbytes <= (others => '0');
        cap_done <= '0';
        end_seen <= '0';
        succ_seen <= '0';
        xfer_dir_in_r <= '0';
        nbytes_r <= (others => '0');
      elsif rising_edge(hclk) then
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') or
           (ocp_claim_abort_i = '1') then
          cap_done <= '0';
          end_seen <= '0';
          succ_seen <= '0';
        elsif new_setup_c = '1' then
          cap_rx_nbytes <= (others => '0');
          cap_done <= '0';
          end_seen <= '0';
          succ_seen <= '0';
        elsif not ((fw_protocol_error_req_i = '1') and (ep0_ocp_owner_r = '1')) and
              (st = T_MIRROR) then
          if sync_sieint_rxdatavalid_i = '1' then
            cap_rxdata <= sync_sieint_rxdata_i;
            cap_done <= '1';
            xfer_dir_in_r <= sync_sieint_rxdata_i(7);
            nbytes_r <= unsigned(sync_sieint_rxdata_i(63 downto 48));
          end if;
          if (sync_sieint_success_i = '1') or
             (sync_sieint_endtransfer_i = '1') then
            cap_rx_nbytes <= sync_sieint_rx_nbytes_i;
          end if;
          if sync_sieint_endtransfer_i = '1' then
            end_seen <= '1';
          end if;
          if sync_sieint_success_i = '1' then
            succ_seen <= '1';
          end if;
        end if;
      end if;
    end process setup_capture_clk_proc;

    setup_publish_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        sp_sent <= '0';
      elsif rising_edge(hclk) then
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') or
           (ocp_claim_abort_i = '1') then
          sp_sent <= '0';
        else
          if setup_pkt_vld_c = '1' then
            sp_sent <= '1';
          end if;
          if new_setup_c = '1' then
            sp_sent <= '0';
          end if;
        end if;
      end if;
    end process setup_publish_clk_proc;

    response_meta_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        tx_response_bytes_r <= (others => '0');
        tx_response_known_r <= '0';
      elsif rising_edge(hclk) then
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') or
           (ocp_claim_abort_i = '1') then
          tx_response_bytes_r <= (others => '0');
          tx_response_known_r <= '0';
        else
          if st = T_META_WAIT then
            tx_response_bytes_r <= unsigned(ctrl_in_resp_bytes);
            tx_response_known_r <= ctrl_in_resp_known;
          end if;
          if new_setup_c = '1' then
            tx_response_bytes_r <= (others => '0');
            tx_response_known_r <= '0';
          end if;
        end if;
      end if;
    end process response_meta_clk_proc;

    data_toggle_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        in_data_toggle_r <= '1';
        out_data_toggle_r <= '1';
        zlp_phase_r <= '0';
      elsif rising_edge(hclk) then
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') or
           (ocp_claim_abort_i = '1') then
          in_data_toggle_r <= '1';
          out_data_toggle_r <= '1';
          zlp_phase_r <= '0';
        elsif (new_setup_c = '1') or (ep0_ocp_owner_r = '0') then
          in_data_toggle_r <= '1';
          out_data_toggle_r <= '1';
          zlp_phase_r <= '0';
        else
          if rx_data_good_c = '1' then
            out_data_toggle_r <= not out_data_toggle_r;
          end if;
          -- Non-iso PIE IN success is asserted only on a received valid ACK.
          -- Neither a duplicate OUT nor an IN STATUS advances this DATA bit.
          if (st = T_DATA) and (xfer_dir_in_r = '1') and
             (sync_sieint_epinfo_epdir_i = '1') and
             (sync_sieint_epinfo_setup_i = '0') and
             (rsp_snap_active_r = '1') and (st_end_c = '1') then
            in_data_toggle_r <= not in_data_toggle_r;
            if (zlp_phase_r = '0') and (zlp_owed_c = '1') then
              zlp_phase_r <= '1';
            else
              zlp_phase_r <= '0';
            end if;
          end if;
        end if;
      end if;
    end process data_toggle_clk_proc;

    fifo_reservation_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        fifo_reservation_r <= '0';
      elsif rising_edge(hclk) then
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') or
           (ocp_claim_abort_i = '1') then
          fifo_reservation_r <= '0';
        elsif (rx_backend_busy_c = '1') or (rx_data_good_c = '1') then
          if rx_drain_done_r = '1' then
            fifo_reservation_r <= '0';
          end if;
        else
          if (fifo_out_request_c = '1') and (fifo_reservation_r = '0') and
             (fifo_admission_ok_c = '1') and
             (rx_captured_beats_r =
              to_unsigned(0, rx_captured_beats_r'length)) then
            fifo_reservation_r <= '1';
          end if;
          if (rx_length_error_r = '1') or
             (new_setup_c = '1') then
            fifo_reservation_r <= '0';
          end if;
        end if;
      end if;
    end process fifo_reservation_clk_proc;

    setup_pending_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        setup_pending_r <= '0';
        setup_pending_low_seen_r <= '0';
        setup_dma_owner_r <= (others => '0');
      elsif rising_edge(hclk) then
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') then
          setup_pending_r <= '0';
          setup_pending_low_seen_r <= '0';
          setup_dma_owner_r <= (others => '0');
        elsif ocp_claim_abort_i = '1' then
          null;
        elsif new_setup_c = '1' then
          setup_pending_r <= '1';
          setup_pending_low_seen_r <= '0';
          setup_dma_owner_r <= pie_dev_selected_i;
        elsif setup_pending_r = '1' then
          if (setup_dma_match_c = '1') and
             (epinfo_sync_valid_dma = '0') then
            setup_pending_low_seen_r <= '1';
          elsif (setup_dma_match_c = '1') and
                (setup_pending_low_seen_r = '1') then
            setup_pending_r <= '0';
            setup_pending_low_seen_r <= '0';
          end if;
        end if;
      end if;
    end process setup_pending_clk_proc;

    setup_success_mask_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        drop_setup_success_r <= '0';
        drop_dma_valid_seen_r <= '0';
      elsif rising_edge(hclk) then
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') then
          drop_setup_success_r <= '0';
          drop_dma_valid_seen_r <= '0';
        elsif ocp_claim_abort_i = '1' then
          null;
        else
          if (drop_setup_success_r = '1') and
             (setup_dma_match_c = '1') and
             (epinfo_sync_valid_dma = '1') then
            drop_dma_valid_seen_r <= '1';
          end if;
          if (drop_setup_success_r = '1') and
             (drop_dma_valid_seen_r = '1') and
             (epinfo_sync_valid_dma = '0') then
            drop_setup_success_r <= '0';
            drop_dma_valid_seen_r <= '0';
          end if;
          if (new_setup_c = '0') and
             not ((fw_protocol_error_req_i = '1') and (ep0_ocp_owner_r = '1')) and
             (st = T_MIRROR) and
             (sync_sieint_rxdatavalid_i = '1') and
             (incoming_is_ocp_c = '1') then
            drop_setup_success_r <= '1';
            drop_dma_valid_seen_r <=
              epinfo_sync_valid_dma and setup_dma_match_c;
          end if;
        end if;
      end if;
    end process setup_success_mask_clk_proc;

    claim_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        ep0_ocp_owner_r <= '0';
        replacement_stall_r <= '0';
      elsif rising_edge(hclk) then
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') or
           (ocp_claim_abort_i = '1') then
          ep0_ocp_owner_r <= '0';
          replacement_stall_r <= '0';
        elsif new_setup_c = '1' then
          if (st = T_PROT_STALL) or (replacement_stall_r = '1') then
            replacement_stall_r <= '1';
          else
            replacement_stall_r <= '0';
          end if;
        elsif (fw_protocol_error_req_i = '1') and (ep0_ocp_owner_r = '1') then
          ep0_ocp_owner_r <= '1';
        elsif (st = T_MIRROR) and (setup_complete_c = '1') then
          if (setup_valid_c = '1') and (setup_claim_c = '1') then
            ep0_ocp_owner_r <= '1';
            replacement_stall_r <= '0';
          elsif setup_valid_c = '1' then
            ep0_ocp_owner_r <= '0';
            replacement_stall_r <= '0';
          end if;
        end if;
      end if;
    end process claim_clk_proc;

    -- ------------------------------------------------------------------
    -- Per-transaction wire routing. wire_ocp_r and wire_dma_r select the
    -- response source; if both low, no response routed.
    -- ------------------------------------------------------------------
    -- A DMA transaction completes when the DMA response-valid interval for
    -- the forwarded request has risen and then fallen.
    dma_txn_done_c <= '1' when (wire_dma_r = '1') and
                               (dma_valid_seen_r = '1') and
                               (epinfo_sync_valid_dma = '0') else '0';

    -- OCP owner. Device 0 teardown clears only this owner.
    ocp_owner_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        wire_ocp_r <= '0';
      elsif rising_edge(hclk) then
        if (sync_busreset = '1') or (ocp_teardown_c = '1') then
          wire_ocp_r <= '0';
        elsif ocp_stage_accept_c = '1' then
          wire_ocp_r <= '1';
        elsif (sync_sieint_epinfo_req_i = '1') or
              ((sync_sieint_endtransfer_i = '1') and
               (wire_ocp_r = '1')) then
          wire_ocp_r <= '0';
        end if;
      end if;
    end process ocp_owner_clk_proc;

    -- DMA owner. Independent of Device 0 teardown so hub and Device 1
    -- traffic is unaffected. A new request takes priority over completion of
    -- the previous one in the same cycle.
    dma_owner_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        wire_dma_r <= '0';
        dma_valid_seen_r <= '0';
      elsif rising_edge(hclk) then
        if sync_busreset = '1' then
          wire_dma_r <= '0';
          dma_valid_seen_r <= '0';
        elsif dma_req_forward_c = '1' then
          wire_dma_r <= '1';
          dma_valid_seen_r <= '0';
        elsif (ocp_stage_accept_c = '1') or (dma_txn_done_c = '1') then
          wire_dma_r <= '0';
          dma_valid_seen_r <= '0';
        elsif (wire_dma_r = '1') and (epinfo_sync_valid_dma = '1') then
          dma_valid_seen_r <= '1';
        end if;
      end if;
    end process dma_owner_clk_proc;

    dma_metadata_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        dma_epnr_r <= (others => '0');
        dma_epdir_r <= '0';
        dma_setup_r <= '0';
        dma_owner_r <= (others => '0');
      elsif rising_edge(hclk) then
        if (sync_busreset = '0') and (dma_req_forward_c = '1') then
          dma_epnr_r <= sync_sieint_epinfo_epnr_i;
          dma_epdir_r <= sync_sieint_epinfo_epdir_i;
          dma_setup_r <= sync_sieint_epinfo_setup_i;
          dma_owner_r <= pie_dev_selected_i;
        end if;
      end if;
    end process dma_metadata_clk_proc;

    response_snapshot_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        rsp_snap_valid_r <= '0';
        rsp_snap_active_r <= '0';
        rsp_snap_stall_r <= '0';
        rsp_snap_disabled_r <= '0';
        rsp_snap_toggle_r <= '0';
        rsp_snap_nbytes_r <= (others => '0');
        rsp_snap_maxpacket_r <= (others => '0');
        rsp_snap_iso_r <= '0';
        rsp_snap_ratefeedback_r <= '0';
      elsif rising_edge(hclk) then
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') or
           (ocp_claim_abort_i = '1') then
          rsp_snap_valid_r <= '0';
          rsp_snap_active_r <= '0';
          rsp_snap_stall_r <= '0';
          rsp_snap_disabled_r <= '0';
          rsp_snap_toggle_r <= '0';
          rsp_snap_nbytes_r <= (others => '0');
          rsp_snap_maxpacket_r <= (others => '0');
          rsp_snap_iso_r <= '0';
          rsp_snap_ratefeedback_r <= '0';
        else
          if (sync_sieint_endtransfer_i = '1') and
             (wire_ocp_r = '1') then
            rsp_snap_valid_r <= '0';
            rsp_snap_active_r <= '0';
            rsp_snap_stall_r <= '0';
            rsp_snap_disabled_r <= '0';
            rsp_snap_toggle_r <= '0';
            rsp_snap_nbytes_r <= (others => '0');
            rsp_snap_maxpacket_r <= (others => '0');
            rsp_snap_iso_r <= '0';
            rsp_snap_ratefeedback_r <= '0';
          end if;
          if (sync_sieint_epinfo_req_i = '1') and
             (dev0_ep0_req_c = '1') and
             (sync_sieint_epinfo_setup_i = '0') and
             (ep0_ocp_owner_r = '1') then
            rsp_snap_valid_r <= rsp_live_valid_c;
            rsp_snap_active_r <= rsp_live_active_c;
            rsp_snap_stall_r <= rsp_live_stall_c;
            rsp_snap_disabled_r <= rsp_live_disabled_c;
            rsp_snap_toggle_r <= rsp_live_toggle_c;
            rsp_snap_nbytes_r <= rsp_live_nbytes_c;
            rsp_snap_maxpacket_r <= rsp_live_maxpacket_c;
            rsp_snap_iso_r <= rsp_live_iso_c;
            rsp_snap_ratefeedback_r <= rsp_live_ratefeedback_c;
          end if;
        end if;
      end if;
    end process response_snapshot_clk_proc;

    -- ------------------------------------------------------------------
    -- Complete Control-OUT packet store (clocked).
    -- ------------------------------------------------------------------
    rxbuf_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        for i in 0 to RX_PACKET_BEATS-1 loop
          rx_buf_r(i) <= (others => '0');
        end loop;
        rx_captured_beats_r <= (others => '0');
        rx_word_index_r     <= (others => '0');
        rx_total_words_r    <= (others => '0');
        rx_total_bytes_r    <= (others => '0');
        rx_validated_r      <= '0';
        rx_drain_done_r     <= '0';
        rx_length_error_r   <= '0';
      elsif rising_edge(hclk) then
        rx_drain_done_r <= '0';
        rx_length_error_r <= '0';
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') or
           (ocp_claim_abort_i = '1') then
          rx_captured_beats_r <= (others => '0');
          rx_word_index_r     <= (others => '0');
          rx_total_words_r    <= (others => '0');
          rx_total_bytes_r    <= (others => '0');
          rx_validated_r      <= '0';
        elsif rx_validated_r = '1' then
          -- Ordinary wire supersession cannot alter accepted payload/cursor.
          -- Emergency abort above suppresses valid and wins even on last word.
          if ctrl_out_rdy = '1' then
            if rx_last_word_c = '1' then
              rx_drain_done_r <= '1';
              -- Retain the completed packet totals until teardown/publication.
              rx_validated_r <= '0';
              rx_captured_beats_r <= (others => '0');
              rx_word_index_r <= (others => '0');
            else
              rx_word_index_r <= rx_word_index_r + 1;
            end if;
          end if;
        elsif (ep0_ocp_owner_r = '0') or (new_setup_c = '1') or
              (setup_pkt_vld_c = '1') then
          rx_captured_beats_r <= (others => '0');
          rx_word_index_r     <= (others => '0');
          rx_total_words_r    <= (others => '0');
          rx_total_bytes_r    <= (others => '0');
          rx_validated_r      <= '0';
        else
          -- One capture/accept path for every OUT destination, including a
          -- final partial beat delivered on the successful EOP edge.
          if (rx_capture_c = '1') and
             (rx_captured_beats_r < to_unsigned(RX_PACKET_BEATS,
                                                rx_captured_beats_r'length)) then
            rx_buf_r(to_integer(rx_captured_beats_r)) <= sync_sieint_rxdata_i;
            rx_captured_beats_r <= rx_captured_beats_r + 1;
          end if;
          if (sync_sieint_endtransfer_i = '1') and (wire_ocp_r = '1')
             and (st = T_DATA) and (xfer_dir_in_r = '0')
             and (out_data_toggle_r = '1')
             and (sync_sieint_epinfo_epdir_i = '0')
             and (sync_sieint_epinfo_setup_i = '0') then
            if rx_data_good_c = '1' then
              rx_total_bytes_r <= resize(nbytes_r, rx_total_bytes_r'length);
              rx_total_words_r <= rx_expected_words_c;
              rx_word_index_r <= (others => '0');
              rx_validated_r <= '1';
            else
              if sync_sieint_success_i = '1' then
                rx_length_error_r <= '1';
              end if;
              rx_captured_beats_r <= (others => '0');
              rx_validated_r <= '0';
            end if;
          end if;
        end if;
      end if;
    end process rxbuf_clk_proc;

    -- ------------------------------------------------------------------
    -- Retained Control-IN packet store and replay cursor (clocked).
    -- ------------------------------------------------------------------
    txbuf_clk_proc : process (hclk, hresetn)
      variable beat_v       : std_logic_vector(USB_DATAWIDTH-1 downto 0);
    begin
      if hresetn = '0' then
        tx_buf_r            <= (others => (others => '0'));
        tx_fill_beats_r      <= 0;
        tx_half_word_r       <= (others => '0');
        tx_half_word_valid_r <= '0';
        tx_producer_done_r   <= '0';
        tx_bytes_sent_r      <= (others => '0');
      elsif rising_edge(hclk) then
        if (ep0_ocp_owner_r = '0') or (new_setup_c = '1')
           or (ocp_claim_abort_i = '1') or (sync_busreset = '1')
           or (dev0_local_reset_c = '1') then
          tx_buf_r            <= (others => (others => '0'));
          tx_fill_beats_r      <= 0;
          tx_half_word_r       <= (others => '0');
          tx_half_word_valid_r <= '0';
          tx_producer_done_r   <= '0';
          tx_bytes_sent_r      <= (others => '0');
        else
          -- USB 2.0 Sec 8.5.3.3/8.6.4: no ACK retries the same DATA packet.
          -- Never rewind on OUT/STATUS completion or alter the saved payload.
          if (tx_in_data_c = '1') and (wire_ocp_r = '1') and
             (sync_sieint_epinfo_epdir_i = '1') and
             (sync_sieint_epinfo_setup_i = '0') and
             (sync_sieint_endtransfer_i = '1') and
             (sync_sieint_success_i = '0') then
            tx_bytes_sent_r <= (others => '0');
          elsif tx_advance_c = '1' then
            tx_bytes_sent_r <= tx_bytes_sent_r +
                               to_unsigned(BYTES_PER_BEAT, tx_bytes_sent_r'length);
          end if;
          if (ctrl_in_vld = '1') and (ctrl_in_rdy_c = '1') then
            if ctrl_in_be /= "0000" then
              beat_v := (others => '0');
              if tx_half_word_valid_r = '1' then
                beat_v(31 downto 0)  := tx_half_word_r;
                beat_v(63 downto 32) := mask_word32(ctrl_in_data, ctrl_in_be);
                tx_buf_r(tx_fill_beats_r) <= beat_v;
                tx_fill_beats_r <= tx_fill_beats_r + 1;
                tx_half_word_r <= (others => '0');
                tx_half_word_valid_r <= '0';
              elsif ctrl_in_last = '1' then
                beat_v(31 downto 0) := mask_word32(ctrl_in_data, ctrl_in_be);
                tx_buf_r(tx_fill_beats_r) <= beat_v;
                tx_fill_beats_r <= tx_fill_beats_r + 1;
              else
                tx_half_word_r <= mask_word32(ctrl_in_data, ctrl_in_be);
                tx_half_word_valid_r <= '1';
              end if;
            elsif (ctrl_in_last = '1') and (tx_half_word_valid_r = '1') then
              -- The producer can terminate after an odd number of DWORDs.
              -- Flush that half beat; an aligned terminator writes no entry.
              beat_v := (others => '0');
              beat_v(31 downto 0) := tx_half_word_r;
              tx_buf_r(tx_fill_beats_r) <= beat_v;
              tx_fill_beats_r <= tx_fill_beats_r + 1;
              tx_half_word_r <= (others => '0');
              tx_half_word_valid_r <= '0';
            end if;
            if ctrl_in_last = '1' then
              tx_producer_done_r <= '1';
            end if;
          end if;
        end if;
      end if;
    end process txbuf_clk_proc;

    -- ------------------------------------------------------------------
    -- The request-cycle decode and retained wire owner qualify the complete
    -- transaction bundle. SETUP is always a physical DMA transaction.
    -- ------------------------------------------------------------------
    dma_req_forward_c <= sync_sieint_epinfo_req_i
      when (dev0_selected_c = '0')
        or (sync_sieint_epinfo_epnr_i /= "0000")
        or (sync_sieint_epinfo_setup_i = '1')
        or (ep0_ocp_owner_r = '0')
      else '0';
    sync_sieint_epinfo_req_o <= dma_req_forward_c;
    sync_sieint_epinfo_setup_o <= sync_sieint_epinfo_setup_i
      when dma_req_forward_c = '1' else dma_setup_r;
    sync_sieint_epinfo_epnr_o <= sync_sieint_epinfo_epnr_i
      when dma_req_forward_c = '1' else dma_epnr_r;
    sync_sieint_epinfo_epdir_o <= sync_sieint_epinfo_epdir_i
      when dma_req_forward_c = '1' else dma_epdir_r;
    sync_sieint_rx_nbytes_o <= sync_sieint_rx_nbytes_i;
    sync_sieint_rxdata_o <= sync_sieint_rxdata_i;
    sync_sieint_rxdatavalid_o <= sync_sieint_rxdatavalid_i
      when (wire_dma_r = '1') else '0';
    sync_sieint_endtransfer_o <= sync_sieint_endtransfer_i
      when (wire_dma_r = '1') else '0';
    dma_success_c <= sync_sieint_success_i
      when (wire_dma_r = '1')
        and ((drop_setup_success_r = '0') or
             (setup_dma_match_c = '0'))
        and not ((sync_sieint_rxdatavalid_i = '1') and
                 (dev0_selected_c = '1') and
                 (incoming_is_ocp_c = '1'))
      else '0';
    sync_sieint_success_o <= dma_success_c;
    sync_sieint_sentNAK_o <= sync_sieint_sentNAK_i
      when (wire_dma_r = '1') else '0';
    sync_sieint_txdatafetched_o <= sync_sieint_txdatafetched_i
      when (wire_dma_r = '1') else '0';

    -- A link-valid SETUP retains all firmware-visible USB side effects for both
    -- owner classes. Only the claimed DMA success is suppressed.
    setup_received_c <= sync_sieint_setup_received_i;
    sync_sieint_setup_received_o <= setup_received_c;

    sync_sieint_error_o     <= sync_sieint_error_i;
    sync_sieint_errortype_o <= sync_sieint_errortype_i;

    -- ------------------------------------------------------------------
    -- Response bundle toward the synchronizer / SIE.
    -- SETUP and all legacy requests use DMA response metadata. Only retained
    -- OCP EP0 DATA/STATUS/PING transactions select the local response.
    -- ------------------------------------------------------------------
    epinfo_valid_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        epinfo_sync_valid_o <= '0';
      elsif rising_edge(hclk) then
        if (ocp_resp_sel_c = '1') and (dev0_ep0_req_c = '1') then
          epinfo_sync_valid_o <= rsp_live_valid_c;
        elsif ocp_resp_sel_c = '1' then
          epinfo_sync_valid_o <= rsp_snap_valid_r;
        else
          epinfo_sync_valid_o <= epinfo_sync_valid_dma;
        end if;
      end if;
    end process epinfo_valid_clk_proc;

    epinfo_sync_active_o <=
        rsp_live_active_c       when (ocp_resp_sel_c = '1')
                                      and (dev0_ep0_req_c = '1') else
        rsp_snap_active_r       when (ocp_resp_sel_c = '1') else
        epinfo_sync_active_dma;

    epinfo_sync_disabled_o <=
        rsp_live_disabled_c when (ocp_resp_sel_c = '1')
                                 and (dev0_ep0_req_c = '1') else
        rsp_snap_disabled_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_disabled_dma;

    epinfo_sync_toggle_o <=
        rsp_live_toggle_c when (ocp_resp_sel_c = '1')
                              and (dev0_ep0_req_c = '1') else
        rsp_snap_toggle_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_toggle_dma;

    epinfo_sync_stall_o <=
        rsp_live_stall_c when (ocp_resp_sel_c = '1')
                             and (dev0_ep0_req_c = '1') else
        rsp_snap_stall_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_stall_dma;

    epinfo_sync_iso_o <=
        rsp_live_iso_c when (ocp_resp_sel_c = '1')
                           and (dev0_ep0_req_c = '1') else
        rsp_snap_iso_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_iso_dma;

    epinfo_sync_ratefeedbackmode_o <=
        rsp_live_ratefeedback_c when (ocp_resp_sel_c = '1')
                                    and (dev0_ep0_req_c = '1') else
        rsp_snap_ratefeedback_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_ratefeedbackmode_dma;

    epinfo_sync_nbytes_o <=
        rsp_live_nbytes_c when (ocp_resp_sel_c = '1')
                              and (dev0_ep0_req_c = '1') else
        rsp_snap_nbytes_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_nbytes_dma;

    epinfo_sync_maxpacket_o <=
        rsp_live_maxpacket_c when (ocp_resp_sel_c = '1')
                                 and (dev0_ep0_req_c = '1') else
        rsp_snap_maxpacket_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_maxpacket_dma;

    epinfo_sync_txdata_o <=
        tx_buf_r(to_integer(tx_bytes_sent_r) / BYTES_PER_BEAT)
          when (ocp_resp_sel_c = '1') and (tx_beat_valid_c = '1') else
        (others => '0') when (ocp_resp_sel_c = '1') else
        epinfo_sync_txdata_dma;

    tx_valid_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        epinfo_sync_txdata_valid_o <= '0';
      elsif rising_edge(hclk) then
        if ocp_resp_sel_c = '1' then
          epinfo_sync_txdata_valid_o <= tx_beat_valid_c;
        else
          epinfo_sync_txdata_valid_o <= epinfo_sync_txdata_valid_dma;
        end if;
      end if;
    end process tx_valid_clk_proc;

    -- ------------------------------------------------------------------
    -- Safety properties (simulation-only).
    -- ------------------------------------------------------------------
    -- pragma translate_off
    signal expected_in_r : std_logic;
    signal expected_out_r : std_logic;
    data_sequence_assertions_proc : process (hclk, hresetn)
      variable cleanup_v : boolean;
    begin
      if hresetn = '0' then
        expected_in_r <= '1';
        expected_out_r <= '1';
      elsif rising_edge(hclk) then
        assert (in_data_toggle_r = expected_in_r) and
               (out_data_toggle_r = expected_out_r)
          report "post_sync_arb: DATA sequence changed without acceptance/ACK or cleanup"
          severity failure;
        cleanup_v := (sync_busreset = '1') or (ocp_teardown_c = '1') or
                     (new_setup_c = '1') or (ep0_ocp_owner_r = '0');
        if cleanup_v then
          expected_in_r <= '1';
          expected_out_r <= '1';
        else
          if rx_data_good_c = '1' then
            assert (out_data_toggle_r = '1') and
                   (sync_sieint_epinfo_epdir_i = '0') and
                   (sync_sieint_epinfo_setup_i = '0') and
                   (rx_backend_busy_c = '0')
              report "post_sync_arb: repeated or wrong-direction OUT acceptance"
              severity failure;
            expected_out_r <= not expected_out_r;
          end if;
          if (st = T_DATA) and (xfer_dir_in_r = '1') and
             (st_end_c = '1') and (sync_sieint_epinfo_epdir_i = '1') and
             (sync_sieint_epinfo_setup_i = '0') and (rsp_snap_active_r = '1') then
            expected_in_r <= not expected_in_r;
          end if;
          if ocp_stage_accept_c = '1' then
            if sync_sieint_epinfo_epdir_i = '1' then
              assert rsp_live_toggle_c = in_data_toggle_r
                report "post_sync_arb: IN request selected OUT sequence"
                severity failure;
            else
              assert rsp_live_toggle_c = out_data_toggle_r
                report "post_sync_arb: OUT request selected IN sequence"
                severity failure;
            end if;
            if (st = T_STATUS) and
               (((sync_sieint_epinfo_epdir_i = '1') and
                 ((xfer_dir_in_r = '0') or (nbytes_r = 0))) or
                ((sync_sieint_epinfo_epdir_i = '0') and
                 (xfer_dir_in_r = '1') and (nbytes_r /= 0))) then
              assert (rsp_live_toggle_c = '1') and
                     (unsigned(rsp_live_nbytes_c) = 0)
                report "post_sync_arb: STATUS did not retain DATA1 ZLP metadata"
                severity failure;
            end if;
          end if;
          if rx_duplicate_window_c = '1' then
            assert (rx_capture_c = '0') and (rx_data_good_c = '0') and
                   (fifo_out_request_c = '0')
              report "post_sync_arb: duplicate OUT reopened capture/commit/reservation"
              severity failure;
            if rsp_live_stall_c = '0' then
              assert (rsp_live_active_c = '1') and (rsp_live_toggle_c = '0') and
                     (rsp_live_nbytes_c =
                      std_logic_vector(resize(nbytes_r, TXNBYTES_BITS))) and
                     (nbytes_r /= 0) and (rsp_live_maxpacket_c = "00")
                report "post_sync_arb: duplicate OUT cannot reach PIE ACK/NYET discard"
                severity failure;
            end if;
            if (st = T_STATUS) and (ctrl_set_stall = '0') and
               (fw_protocol_error_req_i = '0') then
              assert st_next = T_STATUS
                report "post_sync_arb: repeated OUT completion retired IN STATUS"
                severity failure;
            end if;
          end if;
        end if;
      end if;
    end process data_sequence_assertions_proc;

    in_replay_assertions_proc : process (hclk, hresetn)
      variable captured_bytes_v : natural range 0 to TX_MAXBYTES+4;
      variable expect_store_hold_v : boolean;
      variable expect_cursor_v : boolean;
      variable saved_buf_v : t_tx_buf;
      variable saved_fill_v : natural range 0 to TX_PACKET_BEATS;
      variable saved_done_v : std_logic;
      variable saved_bytes_v : unsigned(6 downto 0);
      variable saved_known_v : std_logic;
      variable expected_cursor_v : unsigned(6 downto 0);
      variable cleanup_v : boolean;
    begin
      if hresetn = '0' then
        captured_bytes_v := 0;
        expect_store_hold_v := false;
        expect_cursor_v := false;
        saved_buf_v := (others => (others => '0'));
        saved_fill_v := 0;
        saved_done_v := '0';
        saved_bytes_v := (others => '0');
        saved_known_v := '0';
        expected_cursor_v := (others => '0');
      elsif rising_edge(hclk) then
        if expect_store_hold_v then
          assert (tx_buf_r = saved_buf_v) and (tx_fill_beats_r = saved_fill_v)
                 and (tx_producer_done_r = saved_done_v)
                 and (tx_response_bytes_r = saved_bytes_v)
                 and (tx_response_known_r = saved_known_v)
            report "post_sync_arb: completed IN snapshot changed before cleanup"
            severity failure;
        end if;
        if expect_cursor_v then
          assert tx_bytes_sent_r = expected_cursor_v
            report "post_sync_arb: IN cursor fetch/rewind/hold mismatch"
            severity failure;
        end if;
        cleanup_v := (ep0_ocp_owner_r = '0') or (new_setup_c = '1') or
                     (ocp_claim_abort_i = '1') or (sync_busreset = '1') or
                     (dev0_local_reset_c = '1');
        if not cleanup_v then
          if tx_producer_done_r = '1' then
            assert (captured_bytes_v = to_integer(tx_response_bytes_r)) and
                   (tx_half_word_valid_r = '0')
              report "post_sync_arb: captured IN byte count disagrees with metadata"
              severity failure;
            assert ctrl_in_rdy_c = '0'
              report "post_sync_arb: completed IN producer was restarted"
              severity failure;
          end if;
          if tx_beat_valid_c = '1' then
            assert (tx_producer_done_r = '1') and (tx_response_known_r = '1')
                   and (tx_launch_ready_c = '1')
                   and (to_unsigned(to_integer(tx_bytes_sent_r) / BYTES_PER_BEAT,
                                    tx_bytes_sent_r'length) <
                        to_unsigned(tx_fill_beats_r, tx_bytes_sent_r'length))
              report "post_sync_arb: IN read before complete capture or past payload"
              severity failure;
          end if;
          if (wire_ocp_r = '1') and (rsp_snap_active_r = '0') then
            assert (tx_beat_valid_c = '0') and (tx_advance_c = '0')
              report "post_sync_arb: inactive IN snapshot became active mid-request"
              severity failure;
          end if;
          if (ctrl_in_vld = '1') and (ctrl_in_rdy_c = '1') then
            assert ((ctrl_in_last = '0') and (ctrl_in_be = "1111")) or
                   ((ctrl_in_last = '1') and
                    ((ctrl_in_be = "0000") or (ctrl_in_be = "0001") or
                     (ctrl_in_be = "0011") or (ctrl_in_be = "0111") or
                     (ctrl_in_be = "1111")))
              report "post_sync_arb: IN producer supplied a noncontiguous/early partial word"
              severity failure;
            for idx in 0 to 3 loop
              if ctrl_in_be(idx) = '1' then
                captured_bytes_v := captured_bytes_v + 1;
              end if;
            end loop;
            assert captured_bytes_v <= TX_MAXBYTES
              report "post_sync_arb: IN capture exceeds packet capacity"
              severity failure;
          end if;
        else
          captured_bytes_v := 0;
        end if;
        expect_store_hold_v := not cleanup_v and (tx_producer_done_r = '1')
                               and (st /= T_META_WAIT);
        saved_buf_v := tx_buf_r;
        saved_fill_v := tx_fill_beats_r;
        saved_done_v := tx_producer_done_r;
        saved_bytes_v := tx_response_bytes_r;
        saved_known_v := tx_response_known_r;
        expect_cursor_v := true;
        expected_cursor_v := tx_bytes_sent_r;
        if cleanup_v or
           ((tx_in_data_c = '1') and (wire_ocp_r = '1') and
            (sync_sieint_epinfo_epdir_i = '1') and
            (sync_sieint_epinfo_setup_i = '0') and
            (sync_sieint_endtransfer_i = '1') and (sync_sieint_success_i = '0')) then
          expected_cursor_v := (others => '0');
        elsif tx_advance_c = '1' then
          expected_cursor_v := tx_bytes_sent_r +
                               to_unsigned(BYTES_PER_BEAT, tx_bytes_sent_r'length);
        end if;
      end if;
    end process in_replay_assertions_proc;

    setup_debug_assertions_proc : process (hclk, hresetn)
      variable expected_generation_v : unsigned(11 downto 0);
      variable expected_owner_v : std_logic;
    begin
      if hresetn = '0' then
        expected_generation_v := (others => '0');
        expected_owner_v := '0';
      elsif rising_edge(hclk) then
        assert (dev0_dbg_setup_generation_r = expected_generation_v) and
               (dev0_dbg_setup_owner_ocp_r = expected_owner_v)
          report "post_sync_arb: accepted SETUP debug update/reset/retention mismatch"
          severity failure;
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') then
          expected_generation_v := (others => '0');
          expected_owner_v := '0';
        elsif (st = T_MIRROR) and (new_setup_c = '0') and
              (setup_complete_c = '1') and (setup_valid_c = '1') and
              (ocp_claim_abort_i = '0') and
              not ((fw_protocol_error_req_i = '1') and
                   (ep0_ocp_owner_r = '1')) then
          assert st_next /= T_MIRROR
            report "post_sync_arb: accepted SETUP did not retire MIRROR"
            severity failure;
          expected_generation_v := expected_generation_v + 1;
          expected_owner_v := setup_claim_c;
        end if;
      end if;
    end process setup_debug_assertions_proc;

    assertions_proc : process (hclk, hresetn)
      variable prev_st_v : t_trap_state;
      variable prev_non_ep0_end_v : boolean;
      variable prev_snap_valid_v : std_logic;
      variable prev_snap_active_v : std_logic;
      variable prev_snap_stall_v : std_logic;
      variable prev_snap_disabled_v : std_logic;
      variable prev_snap_toggle_v : std_logic;
      variable prev_snap_nbytes_v : std_logic_vector(TXNBYTES_BITS-1 downto 0);
      variable prev_snap_maxpacket_v : std_logic_vector(1 downto 0);
      variable prev_snap_iso_v : std_logic;
      variable prev_snap_ratefeedback_v : std_logic;
      variable prev_snap_hold_v : boolean;
      variable expect_drop_clear_v : boolean;
      variable expect_drop_hold_v : boolean;
      variable expect_pending_hold_v : boolean;
      variable expect_snapshot_clear_v : boolean;
      variable expect_replacement_stall_v : boolean;
      variable expect_fw_stall_v : boolean;
      variable prev_stall_release_v : boolean;
      variable expect_local_cleanup_v : boolean;
      variable expect_bus_reset_cleanup_v : boolean;
      variable expect_claim_hold_v : boolean;
      variable prev_drop_mask_v : std_logic;
      variable prev_setup_dma_owner_v : std_logic_vector(1 downto 0);
      variable expect_dma_owner_v : boolean;
    begin
      if hresetn = '0' then
        prev_st_v                    := T_IDLE;
        prev_non_ep0_end_v           := false;
        prev_snap_valid_v            := '0';
        prev_snap_active_v           := '0';
        prev_snap_stall_v            := '0';
        prev_snap_disabled_v         := '0';
        prev_snap_toggle_v           := '0';
        prev_snap_nbytes_v           := (others => '0');
        prev_snap_maxpacket_v        := (others => '0');
        prev_snap_iso_v              := '0';
        prev_snap_ratefeedback_v     := '0';
        prev_snap_hold_v             := false;
        expect_drop_clear_v          := false;
        expect_drop_hold_v           := false;
        expect_pending_hold_v        := false;
        expect_snapshot_clear_v      := false;
        expect_replacement_stall_v   := false;
        expect_fw_stall_v            := false;
        prev_stall_release_v         := false;
        expect_local_cleanup_v       := false;
        expect_bus_reset_cleanup_v   := false;
        expect_claim_hold_v          := false;
        prev_drop_mask_v             := '0';
        prev_setup_dma_owner_v       := (others => '0');
        expect_dma_owner_v           := false;
      elsif rising_edge(hclk) then
          if (st = T_META_WAIT) or (st = T_DATA) or (st = T_STATUS) then
            assert ep0_ocp_owner_r = '1'
              report "post_sync_arb: claimed stage without OCP owner"
              severity failure;
          end if;
          if st = T_DATA then
            assert sp_sent = '1'
              report "post_sync_arb: DATA before SETUP publication"
              severity failure;
          end if;
          if (st = T_STATUS) and (xfer_dir_in_r = '0') and
             (cap_rxdata(23 downto 16) = OCP_INDIRECT_FIFO_DATA) then
            assert nbytes_r /= to_unsigned(0, nbytes_r'length)
              report "post_sync_arb: zero-length FIFO request escaped decoder STALL"
              severity failure;
          end if;
          if expect_drop_clear_v then
            assert drop_setup_success_r = '0'
              report "post_sync_arb: claimed SETUP mask survived first valid fall after valid_seen"
              severity failure;
          end if;
          if expect_drop_hold_v and (sync_busreset = '0') and
             (dev0_local_reset_c = '0') then
            assert drop_setup_success_r = '1'
              report "post_sync_arb: claimed SETUP mask retired before valid_seen fall"
              severity failure;
          end if;
          if expect_pending_hold_v and (sync_busreset = '0') and
             (dev0_local_reset_c = '0') then
            assert setup_pending_r = '1'
              report "post_sync_arb: SETUP pending retired before matched low-high"
              severity failure;
          end if;
          if expect_snapshot_clear_v then
            assert (rsp_snap_valid_r = '0') and
                   (rsp_snap_active_r = '0') and
                   (rsp_snap_stall_r = '0') and
                   (rsp_snap_disabled_r = '0') and
                   (rsp_snap_toggle_r = '0') and
                   (rsp_snap_nbytes_r = (rsp_snap_nbytes_r'range => '0')) and
                   (rsp_snap_maxpacket_r =
                    (rsp_snap_maxpacket_r'range => '0')) and
                   (rsp_snap_iso_r = '0') and
                   (rsp_snap_ratefeedback_r = '0')
              report "post_sync_arb: response snapshot bundle was not cleared atomically"
              severity failure;
          end if;
          if expect_replacement_stall_v then
            assert replacement_stall_r = '1'
              report "post_sync_arb: corrupt replacement lost persistent protocol STALL"
              severity failure;
          end if;
          if expect_fw_stall_v then
            assert st = T_PROT_STALL
              report "post_sync_arb: accepted firmware error did not enter protocol STALL"
              severity failure;
          end if;
          if (prev_st_v = T_PROT_STALL) and (st /= T_PROT_STALL) then
            assert prev_stall_release_v
              report "post_sync_arb: persistent protocol STALL released illegally"
              severity failure;
          end if;
          if expect_local_cleanup_v then
            assert (st = T_IDLE) and (ep0_ocp_owner_r = '0') and
                   (wire_ocp_r = '0')
              report "post_sync_arb: local abort cleanup was incomplete"
              severity failure;
          end if;
          if expect_bus_reset_cleanup_v then
            assert (setup_pending_r = '0') and
                   (drop_setup_success_r = '0') and
                   (wire_dma_r = '0')
              report "post_sync_arb: bus reset did not clear DMA tracking"
              severity failure;
          end if;
          if expect_claim_hold_v then
            assert ep0_ocp_owner_r = '1'
              report "post_sync_arb: unrelated device traffic cleared Device 0 claim"
              severity failure;
          end if;
          if (prev_drop_mask_v = '1') and (drop_setup_success_r = '0') then
            assert prev_setup_dma_owner_v =
                   std_logic_vector(to_unsigned(C_DEV0_SEL, 2))
              report "post_sync_arb: SETUP mask retired for a non-Device 0 DMA owner"
              severity failure;
          end if;
          if (drop_setup_success_r = '1') and
             (wire_dma_r = '1') and
             (setup_dma_match_c = '0') then
            assert dma_success_c = sync_sieint_success_i
              report "post_sync_arb: Device 0 SETUP mask suppressed unrelated DMA success"
              severity failure;
          end if;
          if (drop_setup_success_r = '1') and
             (setup_dma_match_c = '1') and
             (sync_sieint_success_i = '1') then
            assert dma_success_c = '0'
              report "post_sync_arb: claimed Device 0 SETUP success was not suppressed"
              severity failure;
          end if;
          assert not ((wire_dma_r = '1') and (wire_ocp_r = '1'))
            report "post_sync_arb: DMA and OCP wire owners overlap"
            severity failure;
          if new_setup_c = '1' then
            assert unsigned(pie_dev_selected_i) =
                   to_unsigned(C_DEV0_SEL, pie_dev_selected_i'length)
              report "post_sync_arb: accepted recovery SETUP was not owned by Device 0"
              severity failure;
            assert sync_sieint_epinfo_setup_i = '1'
                   and sync_sieint_epinfo_epnr_i = "0000"
              report "post_sync_arb: invalid mirrored SETUP classification"
              severity failure;
            assert (epinfo_sync_valid_dma = '0') and
                   ((wire_dma_r = '0') or (dma_valid_seen_r = '1'))
              report "post_sync_arb: mirrored SETUP overlapped an active DMA operation"
              severity failure;
            assert dma_req_forward_c = '1'
              report "post_sync_arb: real SETUP request was not forwarded to DMA"
              severity failure;
          end if;
          if expect_dma_owner_v then
            assert wire_dma_r = '1'
              report "post_sync_arb: hub/Device 1 request did not arm DMA owner"
              severity failure;
          end if;
          if (unsigned(pie_dev_selected_i) = to_unsigned(C_HUB_SEL, 2)) or
             (unsigned(pie_dev_selected_i) = to_unsigned(C_DEV1_SEL, 2)) then
            if sync_sieint_epinfo_req_i = '1' then
              assert (dma_req_forward_c = '1') and (ocp_resp_sel_c = '0') and
                     ((setup_pkt_vld_c = '0') or (st = T_META_WAIT))
                report "post_sync_arb: unrelated device traffic entered recovery"
                severity failure;
            end if;
          end if;
          if (new_setup_c = '1') or (setup_pending_r = '1') then
            assert usbreg_setup_dma_c = '0'
              report "post_sync_arb: SETUP busy exception was not held"
              severity failure;
          end if;
          if sync_sieint_epinfo_setup_i = '1' then
            assert ocp_resp_sel_c = '0'
              report "post_sync_arb: SETUP selected a stalled OCP response"
              severity failure;
          end if;
          if fw_protocol_error_req_i = '1' then
            assert st /= T_MIRROR
              report "post_sync_arb: firmware protocol error preempted a SETUP"
              severity failure;
          end if;
          if (drop_setup_success_r = '1') and
             (setup_dma_match_c = '1') then
            assert dma_success_c = '0'
              report "post_sync_arb: claimed SETUP success reached DMA"
              severity failure;
          end if;
          if (incoming_is_ocp_c = '1') and
             (sync_sieint_rxdatavalid_i = '1') then
            assert dma_success_c = '0'
              report "post_sync_arb: mask was not active at claimed SETUP sample"
              severity failure;
          end if;

          -- A claim is never owned before the full 8-byte SETUP has been captured.
          assert not (((st = T_META_WAIT) or (st = T_DATA) or (st = T_STATUS)
                       or (st = T_PROT_STALL))
                      and (cap_done = '0'))
            report "post_sync_arb: claim asserted before SETUP capture complete"
            severity error;

          assert rx_captured_beats_r <=
                 to_unsigned(RX_PACKET_BEATS, rx_captured_beats_r'length)
            report "post_sync_arb: RX packet staging overflow"
            severity failure;
          if (rx_capture_c = '1') and
             (rx_captured_beats_r =
              to_unsigned(RX_PACKET_BEATS, rx_captured_beats_r'length)) then
            assert rx_data_good_c = '0'
              report "post_sync_arb: excess RX beat accepted as a complete payload"
              severity failure;
          end if;
          assert not ((ctrl_out_vld_c = '1') and (rx_validated_r = '0'))
            report "post_sync_arb: downstream write before successful validation"
            severity failure;
          if rx_drain_active_c = '1' then
            assert ctrl_out_vld_c = '1'
              report "post_sync_arb: internal bubble while draining packet"
              severity failure;
            assert (ctrl_out_last_c = '1') =
                   (rx_word_index_r = (rx_total_words_r - 1))
              report "post_sync_arb: incorrect staged packet drain word count"
              severity failure;
          end if;
          if (rx_length_error_r = '1') or (setup_length_error_c = '1') then
            assert ctrl_out_vld_c = '0'
              report "post_sync_arb: length mismatch produced downstream write"
              severity failure;
          end if;
          if (xfer_dir_in_r = '1') and (tx_response_known_r = '1')
             and (tx_response_bytes_r =
                  to_unsigned(TX_MAXBYTES, tx_response_bytes_r'length))
             and (nbytes_r = resize(tx_response_bytes_r, nbytes_r'length)) then
            assert zlp_owed_c = '0'
              report "post_sync_arb: exact-length 64-byte IN incorrectly owes ZLP"
              severity failure;
          end if;
          if (nbytes_r(15) = '1') and (xfer_dir_in_r = '0') and
             (rx_backend_busy_c = '0') then
            assert ctrl_out_vld_c = '0'
              report "post_sync_arb: oversized OUT request reached downstream"
              severity failure;
          end if;
          if (st = T_PROT_STALL) and (ocp_resp_sel_c = '1')
             and (sync_sieint_epinfo_setup_i = '0') then
            if dev0_ep0_req_c = '1' then
              assert (rsp_live_valid_c = '1') and
                     (rsp_live_active_c = '0') and
                     (rsp_live_stall_c = '1')
                report "post_sync_arb: persistent protocol STALL live response invalid"
                severity failure;
            else
              assert (rsp_snap_valid_r = '1') and
                     (rsp_snap_active_r = '0') and
                     (rsp_snap_stall_r = '1')
                report "post_sync_arb: persistent protocol STALL snapshot invalid"
                severity failure;
            end if;
          end if;
          if prev_non_ep0_end_v then
            assert st = prev_st_v
              report "post_sync_arb: non-EP0 completion advanced EP0 FSM"
              severity failure;
          end if;
          if prev_snap_hold_v then
            assert (rsp_snap_valid_r = prev_snap_valid_v)
                   and (rsp_snap_active_r = prev_snap_active_v)
                   and (rsp_snap_stall_r = prev_snap_stall_v)
                   and (rsp_snap_nbytes_r = prev_snap_nbytes_v)
                   and (rsp_snap_disabled_r = prev_snap_disabled_v)
                   and (rsp_snap_toggle_r = prev_snap_toggle_v)
                   and (rsp_snap_maxpacket_r = prev_snap_maxpacket_v)
                   and (rsp_snap_iso_r = prev_snap_iso_v)
                   and (rsp_snap_ratefeedback_r = prev_snap_ratefeedback_v)
              report "post_sync_arb: response snapshot changed during transaction"
              severity failure;
          end if;
          if (fifo_out_request_c = '1') and (fifo_reservation_r = '0')
             and (fifo_capacity_ok_c = '1') then
            assert unsigned(fifo_free_dwords_i) >= fifo_words_needed_c
              report "post_sync_arb: FIFO reservation exceeds free capacity"
              severity failure;
          end if;
          if (fifo_payload_available_i = '1') and
             (fifo_out_request_c = '1') and (fifo_reservation_r = '0') then
            assert (fifo_admission_ok_c = '0') and
                   (rsp_live_active_c = '0')
              report "post_sync_arb: published FIFO batch admitted a new OUT request"
              severity failure;
          end if;
          if (ep0_ocp_owner_r = '1') and (xfer_dir_in_r = '0') and
             (cap_rxdata(23 downto 16) = OCP_INDIRECT_FIFO_DATA) and
             ((st = T_META_WAIT) or (st = T_DATA)) and
             ((rx_total_words_r = to_unsigned(0, rx_total_words_r'length)) or
              ((st = T_META_WAIT) and (sp_sent = '0'))) and
             (rx_validated_r = '0') and (rx_drain_done_r = '0') and
             ((ocp_claim_abort_i = '1') or (new_setup_c = '1')) and
             (fifo_batch_reset_c = '0') then
            assert fifo_batch_abort_c = '1'
              report "post_sync_arb: incomplete FIFO cancellation missed notification"
              severity failure;
          end if;
          assert setup_received_c = sync_sieint_setup_received_i
            report "post_sync_arb: SETUP notification was not forwarded"
            severity failure;

          -- Single-MaxPacket scope (advertised wMaxRd/WrTransferSize = 64, OCP
          -- Recovery v1.1 Sec 8.5): the captured IN response length and the OUT
          -- byte total never exceed one EP0 HS MaxPacket (64 bytes).
          assert tx_response_bytes_r <=
                 to_unsigned(TX_MAXBYTES, tx_response_bytes_r'length)
            report "post_sync_arb: IN response exceeds single MaxPacket (64B)"
            severity failure;
          assert not ((rx_validated_r = '1')
                      and (rx_total_bytes_r > to_unsigned(64, rx_total_bytes_r'length)))
            report "post_sync_arb: OUT byte count exceeds single MaxPacket (64B)"
            severity failure;

          prev_non_ep0_end_v := (sync_sieint_endtransfer_i = '1')
                                and (wire_dma_r = '1')
                                and (dma_epnr_r /= "0000")
                                and (new_setup_c = '0')
                                and (ctrl_set_stall = '0')
                                and (rx_length_error_r = '0');
          prev_st_v := st;
          prev_snap_valid_v := rsp_snap_valid_r;
          prev_snap_active_v := rsp_snap_active_r;
          prev_snap_stall_v := rsp_snap_stall_r;
          prev_snap_disabled_v := rsp_snap_disabled_r;
          prev_snap_toggle_v := rsp_snap_toggle_r;
          prev_snap_nbytes_v := rsp_snap_nbytes_r;
          prev_snap_maxpacket_v := rsp_snap_maxpacket_r;
          prev_snap_iso_v := rsp_snap_iso_r;
          prev_snap_ratefeedback_v := rsp_snap_ratefeedback_r;
          prev_snap_hold_v := (rsp_snap_valid_r = '1') and
                              (wire_ocp_r = '1') and
                              (sync_sieint_epinfo_req_i = '0') and
                              (sync_sieint_endtransfer_i = '0') and
                              (sync_busreset = '0') and
                              (dev0_local_reset_c = '0') and
                              (ocp_claim_abort_i = '0');
          expect_drop_clear_v := (drop_setup_success_r = '1') and
                                 (drop_dma_valid_seen_r = '1') and
                                 (epinfo_sync_valid_dma = '0') and
                                 (sync_busreset = '0') and
                                 (dev0_local_reset_c = '0') and
                                 (ocp_claim_abort_i = '0');
          expect_drop_hold_v := (drop_setup_success_r = '1') and
                                not ((drop_dma_valid_seen_r = '1') and
                                     (epinfo_sync_valid_dma = '0')) and
                                (sync_busreset = '0') and
                                (dev0_local_reset_c = '0');
          expect_pending_hold_v := (setup_pending_r = '1') and
                                   not ((setup_pending_low_seen_r = '1') and
                                        (epinfo_sync_valid_dma = '1')) and
                                   (new_setup_c = '0') and
                                   (sync_busreset = '0') and
                                   (dev0_local_reset_c = '0');
          expect_snapshot_clear_v := (sync_busreset = '1') or
                                     (dev0_local_reset_c = '1') or
                                     (ocp_claim_abort_i = '1');
          expect_replacement_stall_v :=
              (new_setup_c = '1') and (replacement_stall_r = '1') and
              (sync_busreset = '0') and (dev0_local_reset_c = '0') and
              (ocp_claim_abort_i = '0');
          expect_fw_stall_v := (fw_protocol_error_req_i = '1') and
                               (ep0_ocp_owner_r = '1') and
                               (new_setup_c = '0') and
                               (sync_busreset = '0') and
                               (dev0_local_reset_c = '0') and
                               (ocp_claim_abort_i = '0');
          prev_stall_release_v := (new_setup_c = '1') or
                                  (sync_busreset = '1') or
                                  (dev0_local_reset_c = '1') or
                                  (ocp_claim_abort_i = '1');
          expect_local_cleanup_v := (sync_busreset = '1') or
                                    (dev0_local_reset_c = '1') or
                                    (ocp_claim_abort_i = '1');
          expect_bus_reset_cleanup_v := (sync_busreset = '1');
          expect_claim_hold_v := (ep0_ocp_owner_r = '1') and
            (sync_sieint_epinfo_req_i = '1') and
            (dev0_selected_c = '0') and (sync_busreset = '0') and
            (dev0_local_reset_c = '0') and (ocp_claim_abort_i = '0');
          prev_drop_mask_v := drop_setup_success_r;
          prev_setup_dma_owner_v := setup_dma_owner_r;
          -- Independent of Device 0 reset/disconnect and OCP abort.
          expect_dma_owner_v := (sync_sieint_epinfo_req_i = '1') and
            (sync_busreset = '0') and (dev0_selected_c = '0');
      end if;
    end process assertions_proc;

    out_lifecycle_assertions_proc : process (hclk, hresetn)
      variable expect_hold_v : boolean;
      variable expect_advance_v : boolean;
      variable expect_done_v : boolean;
      variable expect_accept_v : boolean;
      variable expect_discard_v : boolean;
      variable expect_reset_v : boolean;
      variable expect_excess_beat_v : boolean;
      variable saved_buf_v : t_rx_buf;
      variable saved_index_v : unsigned(4 downto 0);
      variable saved_words_v : unsigned(4 downto 0);
      variable saved_bytes_v : unsigned(6 downto 0);
      variable saved_fifo_v : boolean;
      variable words_left_v : natural range 0 to 16;
      variable outstanding_v : boolean;
    begin
      if hresetn = '0' then
        expect_hold_v := false;
        expect_advance_v := false;
        expect_done_v := false;
        expect_accept_v := false;
        expect_discard_v := false;
        expect_reset_v := false;
        expect_excess_beat_v := false;
        saved_buf_v := (others => (others => '0'));
        saved_index_v := (others => '0');
        saved_words_v := (others => '0');
        saved_bytes_v := (others => '0');
        saved_fifo_v := false;
        words_left_v := 0;
        outstanding_v := false;
      elsif rising_edge(hclk) then
        if expect_excess_beat_v then
          assert (rx_buf_r = saved_buf_v) and (rx_validated_r = '0')
            report "post_sync_arb: excess RX beat changed staging or began a drain"
            severity failure;
        end if;
        if expect_hold_v or expect_advance_v or expect_accept_v then
          assert (rx_validated_r = '1') and
                 (rx_buf_r = saved_buf_v) and
                 (rx_total_words_r = saved_words_v) and
                 (rx_total_bytes_r = saved_bytes_v)
            report "post_sync_arb: committed payload/length/reservation changed"
            severity failure;
          if saved_fifo_v then
            assert fifo_reservation_r = '1'
              report "post_sync_arb: accepted FIFO packet lost reservation"
              severity failure;
          end if;
        end if;
        if expect_hold_v then
          assert rx_word_index_r = saved_index_v
            report "post_sync_arb: committed cursor advanced without handshake"
            severity failure;
        end if;
        if expect_advance_v then
          assert rx_word_index_r = saved_index_v + 1
            report "post_sync_arb: committed cursor did not advance exactly once"
            severity failure;
        end if;
        if expect_accept_v then
          assert rx_word_index_r = to_unsigned(0, rx_word_index_r'length)
            report "post_sync_arb: accepted DATA started at nonzero cursor"
            severity failure;
          if (sync_busreset = '0') and (dev0_local_reset_c = '0') and
             (ocp_claim_abort_i = '0') then
            assert ctrl_out_vld_c = '1'
              report "post_sync_arb: accepted DATA drain waited for wire STATUS"
              severity failure;
          end if;
        end if;
        if expect_done_v then
          assert (rx_validated_r = '0') and (rx_drain_done_r = '1') and
                 (rx_total_words_r = saved_words_v)
            report "post_sync_arb: final committed handshake did not retire once"
            severity failure;
          if saved_fifo_v then
            assert fifo_reservation_r = '1'
              report "post_sync_arb: FIFO reservation released before completion"
              severity failure;
            if (sync_busreset = '0') and (dev0_local_reset_c = '0') then
              assert fifo_batch_abort_c = '0'
                report "post_sync_arb: retired FIFO DATA reported canceled"
                severity failure;
            end if;
          end if;
        end if;
        if expect_discard_v or expect_reset_v then
          assert (rx_validated_r = '0') and
                 (rx_total_words_r = to_unsigned(0, rx_total_words_r'length)) and
                 (fifo_reservation_r = '0')
            report "post_sync_arb: pending discard/reset did not release ownership"
            severity failure;
        end if;
        if (ctrl_out_vld_c = '1') and (fifo_reservation_r = '1') then
          assert rx_validated_r = '1'
            report "post_sync_arb: FIFO word published without accepted DATA"
            severity failure;
        end if;
        if (rx_backend_busy_c = '1') or (rx_data_good_c = '1') then
          assert (rx_capture_c = '0') or (rx_data_good_c = '1')
            report "post_sync_arb: committed decoder/store ownership overlapped"
            severity failure;
          if (sync_busreset = '0') and (dev0_local_reset_c = '0') and
             (ocp_claim_abort_i = '0') then
            -- Check the ungated classification event, not a gate-derived valid.
            assert (setup_pkt_ready_c = '0') and (setup_pkt_vld_c = '0')
              report "post_sync_arb: SETUP violated drain/completion timing bound"
              severity failure;
            assert ctrl_xfer_abort_c = '0'
              report "post_sync_arb: wire teardown reset committed decoder"
              severity failure;
          end if;
        end if;
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') then
          assert (fifo_batch_reset_c = '1') and (fifo_batch_abort_c = '0')
            report "post_sync_arb: physical reset missed clear or reported batch abort"
            severity failure;
        else
          assert fifo_batch_reset_c = '0'
            report "post_sync_arb: pending cancellation destructively reset FIFO"
            severity failure;
          if (st = T_STATUS) and (xfer_dir_in_r = '0') and
             (cap_rxdata(23 downto 16) = OCP_INDIRECT_FIFO_DATA) and
             (rx_validated_r = '0') then
            assert fifo_batch_abort_c = '0'
              report "post_sync_arb: missing STATUS canceled completed FIFO DATA"
              severity failure;
          end if;
          if (ocp_claim_abort_i = '0') and
             (((rx_total_words_r /= to_unsigned(0, rx_total_words_r'length)) and
               (sp_sent = '1')) or (rx_data_good_c = '1')) then
            assert fifo_batch_abort_c = '0'
              report "post_sync_arb: committed batch reported canceled"
              severity failure;
          end if;
        end if;
        if (ocp_claim_abort_i = '1') or (sync_busreset = '1') or
           (dev0_local_reset_c = '1') then
          assert (ctrl_out_vld_c = '0') and (ctrl_xfer_abort_c = '1')
            report "post_sync_arb: emergency/reset did not stop RX on its edge"
            severity failure;
          if (ocp_claim_abort_i = '1') and (fifo_batch_reset_c = '0') and
             (fifo_reservation_r = '1') and
             (rx_validated_r = '1') then
            assert fifo_batch_abort_c = '1'
              report "post_sync_arb: emergency FIFO discard missed notification"
              severity failure;
          end if;
        end if;

        -- Count only decoder ready/valid handshakes, never wire retries. This
        -- scoreboard has one credit per accepted full DATA and no replay path.
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') or
           (ocp_claim_abort_i = '1') then
          outstanding_v := false;
          words_left_v := 0;
        else
          if rx_data_good_c = '1' then
            assert not outstanding_v
              report "post_sync_arb: duplicate accepted DATA credit"
              severity failure;
            outstanding_v := true;
            words_left_v := to_integer(rx_expected_words_c);
          end if;
          if rx_validated_r = '1' then
            assert outstanding_v and (words_left_v > 0)
              report "post_sync_arb: OUT drain without accepted DATA credit"
              severity failure;
            assert to_integer(rx_word_index_r) + words_left_v =
                   to_integer(rx_total_words_r)
              report "post_sync_arb: OUT committed words duplicated/skipped"
              severity failure;
            -- Integrated writes ACK every cycle: direct registers or reserved
            -- synchronous CMS capacity (OCP Recovery v1.1 Sec 9.2). A backend
            -- error still enters decoder STALL; it must not be hidden here.
            assert (ctrl_out_vld_c = '1') and (ctrl_out_rdy = '1')
              report "post_sync_arb: integrated OUT backend broke consecutive drain"
              severity failure;
            if ctrl_out_rdy = '1' then
              assert (rx_last_word_c = '1') = (words_left_v = 1)
                report "post_sync_arb: committed last word mismatch"
                severity failure;
              if words_left_v > 0 then
                words_left_v := words_left_v - 1;
              end if;
              if rx_last_word_c = '1' then
                outstanding_v := false;
              end if;
            end if;
          end if;
        end if;
        expect_reset_v := (sync_busreset = '1') or (dev0_local_reset_c = '1') or
                          (ocp_claim_abort_i = '1');
        expect_hold_v := (rx_validated_r = '1') and
                         (ctrl_out_rdy = '0')
                         and not expect_reset_v;
        expect_advance_v := (rx_validated_r = '1') and
                            (ctrl_out_rdy = '1')
                            and (rx_last_word_c = '0') and not expect_reset_v;
        expect_done_v := (rx_validated_r = '1') and
                         (ctrl_out_rdy = '1')
                         and (rx_last_word_c = '1') and not expect_reset_v;
        expect_accept_v := (rx_data_good_c = '1') and not expect_reset_v;
        expect_discard_v := (new_setup_c = '1')
                            and (rx_backend_busy_c = '0') and
                            (rx_data_good_c = '0') and not expect_reset_v;
        expect_excess_beat_v := (rx_capture_c = '1') and
                               (rx_captured_beats_r =
                                to_unsigned(RX_PACKET_BEATS, rx_captured_beats_r'length));
        saved_buf_v := rx_buf_r;
        saved_index_v := rx_word_index_r;
        saved_words_v := rx_total_words_r;
        saved_bytes_v := rx_total_bytes_r;
        saved_fifo_v := fifo_reservation_r = '1';
        if expect_accept_v then
          if rx_capture_c = '1' then
            saved_buf_v(to_integer(rx_captured_beats_r)) := sync_sieint_rxdata_i;
          end if;
          saved_index_v := (others => '0');
          saved_words_v := rx_expected_words_c;
          saved_bytes_v := resize(nbytes_r, saved_bytes_v'length);
        end if;
      end if;
    end process out_lifecycle_assertions_proc;
    -- pragma translate_on

end architecture rtl;
