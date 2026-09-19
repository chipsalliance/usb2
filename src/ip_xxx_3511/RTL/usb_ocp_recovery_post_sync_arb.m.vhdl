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
  -- DWORD per hclk only after successful exact-length EOP validation, preventing
  -- failed USB packets from modifying recovery state. EP0 response metadata is
  -- snapped per transaction while TX payload remains streaming. Transaction
  -- identity keeps non-EP0 DMA traffic independent of retained EP0 ownership.
  -- FIFO writes reserve the exact requested DWORD capacity across PING/retry.
  -- ======================================================================

  constant BYTES_PER_BEAT   : integer := USB_DATAWIDTH / 8;   -- 8 for 64b
  constant RX_PACKET_BEATS  : integer := 8;
  constant TX_MAXBYTES      : integer := 64;
  constant REC_IFACE_SLV    : std_logic_vector(7 downto 0)
           := std_logic_vector(to_unsigned(C_REC_IFACE_NUM, 8));
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
  signal claim_q : std_logic;
  signal ocp_ep0_req_c : std_logic;
  signal ocp_ep0_txn_r : std_logic;
  signal non_ep0_txn_r : std_logic;
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
  signal dma_owner_r : std_logic_vector(1 downto 0);
  signal setup_dma_owner_r : std_logic_vector(1 downto 0);
  signal setup_dma_match_c : std_logic;

  signal xfer_dir_in_r       : std_logic;              -- SETUP dir (1=IN)
  signal nbytes_r            : unsigned(15 downto 0);  -- Full SETUP wLength
  signal tx_response_bytes_r : unsigned(6 downto 0);
  signal tx_response_known_r : std_logic;

  signal in_data_toggle_r : std_logic;
  signal zlp_phase_r      : std_logic;
  signal zlp_owed_c       : std_logic;

  -- Success-qualified end-of-stage pulse (hclk pulse; no edge detect needed).
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

  -- Control-IN cut-through queue (SV 32b words -> SIE 64b beats).
  signal tx_curr_data_r       : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal tx_curr_valid_r      : std_logic;
  signal tx_next_data_r       : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal tx_next_valid_r      : std_logic;
  signal tx_half_word_r       : std_logic_vector(31 downto 0);
  signal tx_half_word_valid_r : std_logic;
  signal tx_producer_done_r   : std_logic;
  signal tx_bytes_sent_r      : unsigned(6 downto 0);
  signal tx_packet_started_r  : std_logic;
  signal ctrl_in_rdy_c        : std_logic;
  signal tx_in_data_c         : std_logic;
  signal tx_launch_ready_c    : std_logic;
  signal tx_beat_valid_c      : std_logic;
  signal tx_shift_c           : std_logic;
  signal tx_slot_free_c       : std_logic;
  signal tx_remaining_bytes_c : unsigned(6 downto 0);

  signal setup_pkt_vld_c : std_logic;
  signal setup_complete_c : std_logic;
  signal setup_valid_c : std_logic;
  signal setup_claim_c : std_logic;

  -- A FIFO-space reservation survives PING and CRC retry. It prevents
  -- firmware FIFO mutators from invalidating an advertised OUT acceptance.
  signal fifo_reservation_r : std_logic;
  signal fifo_words_needed_c : unsigned(6 downto 0);
  signal fifo_capacity_ok_c : std_logic;
  signal fifo_admission_ok_c : std_logic;
  signal fifo_out_request_c : std_logic;
  signal fifo_batch_abort_c : std_logic;
  signal setup_received_c : std_logic;

  -- Non-streaming EP0 response ownership is transaction-scoped. Streaming
  -- TX data remains live so the SIE can fetch successive beats.
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

    claim_q <= ep0_ocp_owner_r;
    ocp_ep0_req_c <= '1' when (dev0_selected_c = '1')
                                   and (sync_sieint_epinfo_req_i = '1')
                                   and (sync_sieint_epinfo_epnr_i = "0000")
                              else '0';
    ocp_resp_sel_c <= '0' when (sync_sieint_epinfo_req_i = '1') and
                                   (sync_sieint_epinfo_setup_i = '1') else
                      '1' when ((wire_ocp_r = '1') or
                                       ((ocp_ep0_req_c = '1') and
                                        (sync_sieint_epinfo_setup_i = '0') and
                                        (claim_q = '1')))
                                else '0';

    -- OCP-recovery class match on the captured SETUP (little-endian, USB 2.0
    -- Sec 9.3 Tbl 9-2; OCP Recovery v1.1 Sec 8.5).
    is_ocp <= '1' when (cap_done = '1')
                   and (cap_rxdata( 6 downto  5) = "01")
                   and (cap_rxdata( 4 downto  0) = "00001")
                   and (cap_rxdata(15 downto  8) = OCP_RECOVERY_TRANSFER)
                   and (cap_rxdata(39 downto 32) = REC_IFACE_SLV)
                   and (cap_rxdata(47 downto 40) = x"00")
                   and (ocp_path_disable_i = '0')
               else '0';
    incoming_is_ocp_c <= '1' when
                    (sync_sieint_rxdata_i(6 downto 5) = "01")
                and (dev0_selected_c = '1')
                and (sync_sieint_rxdata_i(4 downto 0) = "00001")
                and (sync_sieint_rxdata_i(15 downto 8) = OCP_RECOVERY_TRANSFER)
                and (sync_sieint_rxdata_i(39 downto 32) = REC_IFACE_SLV)
                and (sync_sieint_rxdata_i(47 downto 40) = x"00")
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
                and ocp_ep0_txn_r;
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

    -- setup_pkt to the SV recovery stack: pulse once per claimed SETUP.
    setup_pkt_vld_c <= '1' when (st = T_MIRROR) and (cap_done = '1')
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
    setup_pkt <= sync_sieint_rxdata_i
      when sync_sieint_rxdatavalid_i = '1' else cap_rxdata;
    setup_pkt_vld <= setup_pkt_vld_c;

    -- ------------------------------------------------------------------
    -- Complete-packet Control-OUT staging (SIE 64b beats -> SV 32b words).
    -- ------------------------------------------------------------------
    rx_expected_beats_c <= resize(shift_right(nbytes_r +
                              to_unsigned(BYTES_PER_BEAT-1, nbytes_r'length), 3), 4);
    rx_expected_words_c <= resize(shift_right(nbytes_r +
                               to_unsigned(3, nbytes_r'length), 2), 5);
    rx_capture_c <= '1' when (st = T_DATA) and (xfer_dir_in_r = '0')
                            and (ocp_ep0_txn_r = '1')
                            and (sync_sieint_rxdatavalid_i = '1')
                            and (rx_validated_r = '0')
                       else '0';
    rx_drain_active_c <= rx_validated_r;

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
    ctrl_out_vld  <= ctrl_out_vld_c when (st = T_DATA) else '0';
    ctrl_out_last <= ctrl_out_last_c;

    -- ------------------------------------------------------------------
    -- Control-IN cut-through queue combinational (SV 32b words -> SIE beats).
    -- ------------------------------------------------------------------
    tx_in_data_c <= '1' when (claim_q = '1') and (st = T_DATA)
                             and (xfer_dir_in_r = '1') and (zlp_phase_r = '0')
                     else '0';
    tx_remaining_bytes_c <= tx_response_bytes_r - tx_bytes_sent_r
                            when tx_response_bytes_r >= tx_bytes_sent_r
                            else (others => '0');
    tx_shift_c <= '1' when (tx_in_data_c = '1') and (tx_launch_ready_c = '1')
                           and (ocp_ep0_txn_r = '1')
                           and (sync_sieint_txdatafetched_i = '1')
                           and (tx_remaining_bytes_c >
                                to_unsigned(BYTES_PER_BEAT, tx_remaining_bytes_c'length))
                           and (tx_next_valid_r = '1')
                  else '0';
    tx_slot_free_c <= '1' when (tx_shift_c = '1') or (tx_curr_valid_r = '0')
                               or (tx_next_valid_r = '0')
                      else '0';
    ctrl_in_rdy_c <= '1' when (claim_q = '1') and (tx_slot_free_c = '1') else '0';
    ctrl_in_rdy   <= ctrl_in_rdy_c;

    zlp_owed_c <= '1' when (xfer_dir_in_r = '1') and (tx_response_known_r = '1')
                            and (tx_response_bytes_r =
                                 to_unsigned(TX_MAXBYTES, tx_response_bytes_r'length))
                            and (nbytes_r >
                                 resize(tx_response_bytes_r, nbytes_r'length))
                     else '0';
    tx_launch_ready_c <=
        '1' when (tx_response_bytes_r = to_unsigned(0, tx_response_bytes_r'length))
                 and (tx_producer_done_r = '1') else
        '1' when (tx_response_bytes_r <= to_unsigned(BYTES_PER_BEAT, tx_response_bytes_r'length))
                 and (tx_curr_valid_r = '1') and (tx_producer_done_r = '1') else
        '1' when (tx_curr_valid_r = '1') and (tx_packet_started_r = '1') else
        '1' when (tx_curr_valid_r = '1') and (tx_next_valid_r = '1') else
        '0';
    tx_beat_valid_c <= '1' when (tx_launch_ready_c = '1') and (tx_curr_valid_r = '1')
                               and (tx_response_bytes_r /=
                                    to_unsigned(0, tx_response_bytes_r'length))
                       else '0';

    fifo_words_needed_c <= resize(shift_right(nbytes_r +
                                  to_unsigned(3, nbytes_r'length), 2), 7);
    fifo_capacity_ok_c <= '1' when
      unsigned(fifo_free_dwords_i) >= fifo_words_needed_c
      else '0';
    fifo_admission_ok_c <= fifo_capacity_ok_c and
                           not fifo_payload_available_i;
    fifo_out_request_c <= '1' when (st = T_DATA) and (xfer_dir_in_r = '0')
                                  and (cap_rxdata(23 downto 16) =
                                       OCP_INDIRECT_FIFO_DATA)
                                  and (ocp_ep0_req_c = '1')
                                  and (sync_sieint_epinfo_setup_i = '0')
                              else '0';
    fifo_reservation_active_o <= fifo_reservation_r or
                                 (fifo_out_request_c and fifo_admission_ok_c);
    -- OUT requests cannot be clamped because doing so would make a partial
    -- packet visible downstream. IN requests retain full wLength for the
    -- terminating-ZLP decision while advertising only the known response size.
    setup_length_error_c <= '1' when (st = T_META_WAIT) and
                                      (xfer_dir_in_r = '0') and
                                      (nbytes_r >
                                       to_unsigned(TX_MAXBYTES, nbytes_r'length))
                              else '0';

    -- These values are snapped on each claimed EP0 request. A write STATUS
    -- request remains inactive until post-EOP validation and commit complete.
    rsp_live_valid_c <= '1';
    rsp_live_stall_c <= '1' when ((st = T_PROT_STALL) or
                                  (ctrl_set_stall = '1') or
                                  (rx_length_error_r = '1'))
                               and (sync_sieint_epinfo_setup_i = '0') else '0';
    rsp_live_active_c <=
        '0' when (rsp_live_stall_c = '1') else
        '1' when (sync_sieint_epinfo_setup_i = '1') else
        '0' when (st = T_META_WAIT) else
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
                 and ((rx_captured_beats_r /= to_unsigned(0, rx_captured_beats_r'length))
                      or (rx_validated_r = '1')) else
        '1';
    rsp_live_disabled_c <= '0';
    rsp_live_toggle_c <= in_data_toggle_r when (st = T_DATA) else
                         '1' when (st = T_STATUS) else '0';
    rsp_live_nbytes_c <=
        NBYTES8 when (sync_sieint_epinfo_setup_i = '1') else
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
    ctrl_xfer_done <= rx_drain_done_r when (xfer_dir_in_r = '0') else
                       (st_end_c and tx_launch_ready_c)
                         when ((st = T_DATA) or (st = T_STATUS))
                              and (ocp_ep0_txn_r = '1') else '0';
    ctrl_xfer_abort <= '1' when (dev0_local_reset_c = '1')
                                 or (ocp_claim_abort_i = '1')
                                 or (rx_length_error_r = '1')
                                 or (setup_length_error_c = '1')
                                  or ((claim_q = '1') and (new_setup_c = '1'))
                                  or (((st = T_META_WAIT) or (st = T_DATA)
                                       or (st = T_STATUS)
                                       or (st = T_PROT_STALL))
                                     and (sync_busreset = '1'))
                        else '0';
    fifo_batch_abort_c <= '1' when (claim_q = '1')
                                     and (xfer_dir_in_r = '0')
                                     and (cap_rxdata(23 downto 16) =
                                          OCP_INDIRECT_FIFO_DATA)
                                     and ((st = T_META_WAIT) or (st = T_DATA)
                                          or (st = T_STATUS))
                                     and (rx_drain_done_r = '0')
                                     and ((sync_busreset = '1')
                                          or (dev0_local_reset_c = '1')
                                          or (ocp_claim_abort_i = '1')
                                          or (new_setup_c = '1'))
                            else '0';
    fifo_batch_abort <= fifo_batch_abort_c;

    ctrl_length_error <= rx_length_error_r or setup_length_error_c;

    -- ------------------------------------------------------------------
    -- Recovery transfer FSM.
    --
    -- Each state lists its own preemption priority so the transition behavior
    -- is visible from the origin state. Synchronous teardown is applied by the
    -- state register and therefore overrides every combinational transition.
    -- ------------------------------------------------------------------
    fsm_next_proc : process (st, new_setup_c, fw_protocol_error_req_i, claim_q,
                             setup_complete_c, setup_valid_c, setup_claim_c,
                             replacement_stall_r, ctrl_set_stall,
                             setup_length_error_c, nbytes_r,
                             rx_length_error_r, xfer_dir_in_r,
                             rx_drain_done_r, st_end_c, zlp_phase_r,
                             zlp_owed_c)
    begin
      st_next <= st;
      case st is
        when T_IDLE =>
          if new_setup_c = '1' then
            st_next <= T_MIRROR;
          elsif (fw_protocol_error_req_i = '1') and (claim_q = '1') then
            st_next <= T_PROT_STALL;
          end if;

        when T_MIRROR =>
          if new_setup_c = '1' then
            st_next <= T_MIRROR;
          elsif (fw_protocol_error_req_i = '1') and (claim_q = '1') then
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
          elsif (fw_protocol_error_req_i = '1') and (claim_q = '1') then
            st_next <= T_PROT_STALL;
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
          elsif (fw_protocol_error_req_i = '1') and (claim_q = '1') then
            st_next <= T_PROT_STALL;
          elsif (ctrl_set_stall = '1') or (rx_length_error_r = '1') then
            st_next <= T_PROT_STALL;
          elsif (xfer_dir_in_r = '0') and (rx_drain_done_r = '1') then
            st_next <= T_STATUS;
          elsif st_end_c = '1' then
            if xfer_dir_in_r = '0' then
              st_next <= T_DATA;
            elsif (zlp_phase_r = '0') and (zlp_owed_c = '1') then
              st_next <= T_DATA;
            else
              st_next <= T_STATUS;
            end if;
          end if;

        when T_STATUS =>
          if new_setup_c = '1' then
            st_next <= T_MIRROR;
          elsif (fw_protocol_error_req_i = '1') and (claim_q = '1') then
            st_next <= T_PROT_STALL;
          elsif ctrl_set_stall = '1' then
            st_next <= T_PROT_STALL;
          elsif st_end_c = '1' then
            st_next <= T_IDLE;
          end if;

        when T_PROT_STALL =>
          if new_setup_c = '1' then
            st_next <= T_MIRROR;
          elsif (fw_protocol_error_req_i = '1') and (claim_q = '1') then
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
        elsif not ((fw_protocol_error_req_i = '1') and (claim_q = '1')) and
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
        zlp_phase_r <= '0';
      elsif rising_edge(hclk) then
        if (sync_busreset = '1') or (dev0_local_reset_c = '1') or
           (ocp_claim_abort_i = '1') then
          in_data_toggle_r <= '1';
          zlp_phase_r <= '0';
        elsif claim_q = '0' then
          in_data_toggle_r <= '1';
          zlp_phase_r <= '0';
        elsif (st = T_DATA) and (st_end_c = '1') then
          if (zlp_phase_r = '0') and (zlp_owed_c = '1') then
            zlp_phase_r <= '1';
            in_data_toggle_r <= not in_data_toggle_r;
          else
            zlp_phase_r <= '0';
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
        else
          if (fifo_out_request_c = '1') and (fifo_reservation_r = '0') and
             (fifo_admission_ok_c = '1') and (rx_validated_r = '0') and
             (rx_captured_beats_r =
              to_unsigned(0, rx_captured_beats_r'length)) then
            fifo_reservation_r <= '1';
          end if;
          if (rx_drain_done_r = '1') or (rx_length_error_r = '1') or
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
             not ((fw_protocol_error_req_i = '1') and (claim_q = '1')) and
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
        elsif (fw_protocol_error_req_i = '1') and (claim_q = '1') then
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
    -- Per-transaction wire routing.
    -- ------------------------------------------------------------------
    route_owner_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        ocp_ep0_txn_r <= '0';
        non_ep0_txn_r <= '0';
        wire_ocp_r <= '0';
        wire_dma_r <= '0';
        dma_valid_seen_r <= '0';
      elsif rising_edge(hclk) then
        if sync_busreset = '1' then
          ocp_ep0_txn_r <= '0';
          non_ep0_txn_r <= '0';
          wire_ocp_r <= '0';
          wire_dma_r <= '0';
          dma_valid_seen_r <= '0';
        elsif (dev0_local_reset_c = '1') or
              (ocp_claim_abort_i = '1') then
          ocp_ep0_txn_r <= '0';
          wire_ocp_r <= '0';
        else
          if (sync_sieint_endtransfer_i = '1') and
             (ocp_ep0_txn_r = '1') then
            ocp_ep0_txn_r <= '0';
            wire_ocp_r <= '0';
          end if;
          if (wire_dma_r = '1') and (epinfo_sync_valid_dma = '1') then
            dma_valid_seen_r <= '1';
          end if;
          if (wire_dma_r = '1') and (dma_valid_seen_r = '1') and
             (epinfo_sync_valid_dma = '0') then
            non_ep0_txn_r <= '0';
            wire_dma_r <= '0';
            dma_valid_seen_r <= '0';
          end if;
          if sync_sieint_epinfo_req_i = '1' then
            if (ocp_ep0_req_c = '1') and
               (sync_sieint_epinfo_setup_i = '0') and
               (claim_q = '1') then
              ocp_ep0_txn_r <= '1';
              wire_ocp_r <= '1';
              wire_dma_r <= '0';
              dma_valid_seen_r <= '0';
              non_ep0_txn_r <= '0';
            else
              ocp_ep0_txn_r <= '0';
              wire_ocp_r <= '0';
              wire_dma_r <= '1';
              dma_valid_seen_r <= '0';
              if sync_sieint_epinfo_epnr_i /= "0000" then
                non_ep0_txn_r <= '1';
              else
                non_ep0_txn_r <= '0';
              end if;
            end if;
          end if;
        end if;
      end if;
    end process route_owner_clk_proc;

    dma_metadata_clk_proc : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        dma_epnr_r <= (others => '0');
        dma_epdir_r <= '0';
        dma_setup_r <= '0';
        dma_owner_r <= (others => '0');
      elsif rising_edge(hclk) then
        if (sync_busreset = '0') and (dev0_local_reset_c = '0') and
           (ocp_claim_abort_i = '0') and
           (sync_sieint_epinfo_req_i = '1') and
           not ((ocp_ep0_req_c = '1') and
                (sync_sieint_epinfo_setup_i = '0') and
                (claim_q = '1')) then
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
             (ocp_ep0_txn_r = '1') then
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
             (ocp_ep0_req_c = '1') and
             (sync_sieint_epinfo_setup_i = '0') and
             (claim_q = '1') then
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
      variable effective_beats_v : unsigned(3 downto 0);
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
        if (claim_q = '0') or (new_setup_c = '1')
           or (ocp_claim_abort_i = '1') or (sync_busreset = '1')
           or (dev0_local_reset_c = '1') then
          rx_captured_beats_r <= (others => '0');
          rx_word_index_r     <= (others => '0');
          rx_total_words_r    <= (others => '0');
          rx_total_bytes_r    <= (others => '0');
          rx_validated_r      <= '0';
        else
          effective_beats_v := rx_captured_beats_r;
          if (rx_capture_c = '1') and
             (rx_captured_beats_r < to_unsigned(RX_PACKET_BEATS,
                                                rx_captured_beats_r'length)) then
            rx_buf_r(to_integer(rx_captured_beats_r)) <= sync_sieint_rxdata_i;
            rx_captured_beats_r <= rx_captured_beats_r + 1;
            effective_beats_v := rx_captured_beats_r + 1;
          end if;
          if (rx_validated_r = '1') and (ctrl_out_rdy = '1') then
            if rx_last_word_c = '1' then
              rx_drain_done_r <= '1';
              rx_validated_r <= '0';
              rx_captured_beats_r <= (others => '0');
              rx_word_index_r <= (others => '0');
            else
              rx_word_index_r <= rx_word_index_r + 1;
            end if;
          end if;
          if (sync_sieint_endtransfer_i = '1') and (ocp_ep0_txn_r = '1')
             and (st = T_DATA) and (xfer_dir_in_r = '0') then
            if sync_sieint_success_i = '1' then
              if (resize(unsigned(sync_sieint_rx_nbytes_i), nbytes_r'length) =
                  nbytes_r)
                 and (effective_beats_v = rx_expected_beats_c) then
                rx_total_bytes_r <= resize(nbytes_r, rx_total_bytes_r'length);
                rx_total_words_r <= rx_expected_words_c;
                rx_word_index_r <= (others => '0');
                if nbytes_r = to_unsigned(0, nbytes_r'length) then
                  rx_drain_done_r <= '1';
                  rx_captured_beats_r <= (others => '0');
                else
                  rx_validated_r <= '1';
                end if;
              else
                rx_length_error_r <= '1';
                rx_captured_beats_r <= (others => '0');
                rx_validated_r <= '0';
              end if;
            else
              rx_captured_beats_r <= (others => '0');
              rx_validated_r <= '0';
            end if;
          end if;
        end if;
      end if;
    end process rxbuf_clk_proc;

    -- ------------------------------------------------------------------
    -- Control-IN cut-through buffer (clocked).
    -- ------------------------------------------------------------------
    txbuf_clk_proc : process (hclk, hresetn)
      variable curr_data_v  : std_logic_vector(USB_DATAWIDTH-1 downto 0);
      variable curr_valid_v : std_logic;
      variable next_data_v  : std_logic_vector(USB_DATAWIDTH-1 downto 0);
      variable next_valid_v : std_logic;
      variable half_word_v  : std_logic_vector(31 downto 0);
      variable half_valid_v : std_logic;
      variable producer_done_v : std_logic;
      variable bytes_sent_v : unsigned(6 downto 0);
      variable beat_v       : std_logic_vector(USB_DATAWIDTH-1 downto 0);
    begin
      if hresetn = '0' then
        tx_curr_data_r       <= (others => '0');
        tx_curr_valid_r      <= '0';
        tx_next_data_r       <= (others => '0');
        tx_next_valid_r      <= '0';
        tx_half_word_r       <= (others => '0');
        tx_half_word_valid_r <= '0';
        tx_producer_done_r   <= '0';
        tx_bytes_sent_r      <= (others => '0');
        tx_packet_started_r  <= '0';
      elsif rising_edge(hclk) then
        if (claim_q = '0') or (new_setup_c = '1')
           or (ocp_claim_abort_i = '1') or (sync_busreset = '1')
           or (dev0_local_reset_c = '1') then
          tx_curr_data_r       <= (others => '0');
          tx_curr_valid_r      <= '0';
          tx_next_data_r       <= (others => '0');
          tx_next_valid_r      <= '0';
          tx_half_word_r       <= (others => '0');
          tx_half_word_valid_r <= '0';
          tx_producer_done_r   <= '0';
          tx_bytes_sent_r      <= (others => '0');
          tx_packet_started_r  <= '0';
        else
          curr_data_v     := tx_curr_data_r;
          curr_valid_v    := tx_curr_valid_r;
          next_data_v     := tx_next_data_r;
          next_valid_v    := tx_next_valid_r;
          half_word_v     := tx_half_word_r;
          half_valid_v    := tx_half_word_valid_r;
          producer_done_v := tx_producer_done_r;
          bytes_sent_v    := tx_bytes_sent_r;
          if tx_shift_c = '1' then
            curr_data_v  := tx_next_data_r;
            curr_valid_v := '1';
            next_data_v  := (others => '0');
            next_valid_v := '0';
            bytes_sent_v := tx_bytes_sent_r +
                            to_unsigned(BYTES_PER_BEAT, tx_bytes_sent_r'length);
          end if;
          if (tx_in_data_c = '1') and (tx_launch_ready_c = '1') and
             (ocp_ep0_txn_r = '1') and
             (sync_sieint_txdatafetched_i = '1') then
            tx_packet_started_r <= '1';
          end if;
          if (ctrl_in_vld = '1') and (ctrl_in_rdy_c = '1') then
            if ctrl_in_last = '1' then
              beat_v := (others => '0');
              if half_valid_v = '1' then
                beat_v(31 downto 0)  := half_word_v;
                beat_v(63 downto 32) := mask_word32(ctrl_in_data, ctrl_in_be);
                half_word_v  := (others => '0');
                half_valid_v := '0';
              else
                beat_v(31 downto 0) := mask_word32(ctrl_in_data, ctrl_in_be);
              end if;
              if curr_valid_v = '0' then
                curr_data_v  := beat_v;
                curr_valid_v := '1';
              elsif next_valid_v = '0' then
                next_data_v  := beat_v;
                next_valid_v := '1';
              end if;
              producer_done_v := '1';
            else
              if half_valid_v = '1' then
                beat_v := (others => '0');
                beat_v(31 downto 0)  := half_word_v;
                beat_v(63 downto 32) := mask_word32(ctrl_in_data, ctrl_in_be);
                half_word_v  := (others => '0');
                half_valid_v := '0';
                if curr_valid_v = '0' then
                  curr_data_v  := beat_v;
                  curr_valid_v := '1';
                elsif next_valid_v = '0' then
                  next_data_v  := beat_v;
                  next_valid_v := '1';
                end if;
              else
                half_word_v  := mask_word32(ctrl_in_data, ctrl_in_be);
                half_valid_v := '1';
              end if;
            end if;
          end if;
          tx_curr_data_r       <= curr_data_v;
          tx_curr_valid_r      <= curr_valid_v;
          tx_next_data_r       <= next_data_v;
          tx_next_valid_r      <= next_valid_v;
          tx_half_word_r       <= half_word_v;
          tx_half_word_valid_r <= half_valid_v;
          tx_producer_done_r   <= producer_done_v;
          tx_bytes_sent_r      <= bytes_sent_v;
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
        or (claim_q = '0')
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
    setup_received_c <= sync_sieint_setup_received_i
      when (sync_busreset = '0') and
           not ((dev0_selected_c = '1') and
                (dev0_local_reset_c = '1')) else '0';
    sync_sieint_setup_received_o <= setup_received_c;

    sync_sieint_error_o     <= sync_sieint_error_i;
    sync_sieint_errortype_o <= sync_sieint_errortype_i;

    -- ------------------------------------------------------------------
    -- Response bundle toward the synchronizer / SIE.
    -- SETUP and all legacy requests use DMA response metadata. Only retained
    -- OCP EP0 DATA/STATUS/PING transactions select the local response.
    -- ------------------------------------------------------------------
    epinfo_sync_valid_o <=
        rsp_live_valid_c      when (ocp_resp_sel_c = '1')
                                   and (ocp_ep0_req_c = '1') else
        rsp_snap_valid_r      when (ocp_resp_sel_c = '1') else
        epinfo_sync_valid_dma;

    epinfo_sync_active_o <=
        rsp_live_active_c       when (ocp_resp_sel_c = '1')
                                      and (ocp_ep0_req_c = '1') else
        rsp_snap_active_r       when (ocp_resp_sel_c = '1') else
        epinfo_sync_active_dma;

    epinfo_sync_disabled_o <=
        rsp_live_disabled_c when (ocp_resp_sel_c = '1')
                                 and (ocp_ep0_req_c = '1') else
        rsp_snap_disabled_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_disabled_dma;

    epinfo_sync_toggle_o <=
        rsp_live_toggle_c when (ocp_resp_sel_c = '1')
                              and (ocp_ep0_req_c = '1') else
        rsp_snap_toggle_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_toggle_dma;

    epinfo_sync_stall_o <=
        rsp_live_stall_c when (ocp_resp_sel_c = '1')
                             and (ocp_ep0_req_c = '1') else
        rsp_snap_stall_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_stall_dma;

    epinfo_sync_iso_o <=
        rsp_live_iso_c when (ocp_resp_sel_c = '1')
                           and (ocp_ep0_req_c = '1') else
        rsp_snap_iso_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_iso_dma;

    epinfo_sync_ratefeedbackmode_o <=
        rsp_live_ratefeedback_c when (ocp_resp_sel_c = '1')
                                    and (ocp_ep0_req_c = '1') else
        rsp_snap_ratefeedback_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_ratefeedbackmode_dma;

    epinfo_sync_nbytes_o <=
        rsp_live_nbytes_c when (ocp_resp_sel_c = '1')
                              and (ocp_ep0_req_c = '1') else
        rsp_snap_nbytes_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_nbytes_dma;

    epinfo_sync_maxpacket_o <=
        rsp_live_maxpacket_c when (ocp_resp_sel_c = '1')
                                 and (ocp_ep0_req_c = '1') else
        rsp_snap_maxpacket_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_maxpacket_dma;

    epinfo_sync_txdata_o <=
        tx_curr_data_r when (ocp_resp_sel_c = '1') else
        epinfo_sync_txdata_dma;

    epinfo_sync_txdata_valid_o <=
        tx_beat_valid_c when (ocp_resp_sel_c = '1') else
        epinfo_sync_txdata_valid_dma;

    -- ------------------------------------------------------------------
    -- Safety properties (simulation-only).
    -- ------------------------------------------------------------------
    -- pragma translate_off
    assertions_proc : process (hclk)
      variable prev_st_v : t_trap_state := T_IDLE;
      variable prev_non_ep0_end_v : boolean := false;
      variable prev_snap_valid_v : std_logic := '0';
      variable prev_snap_active_v : std_logic := '0';
      variable prev_snap_stall_v : std_logic := '0';
      variable prev_snap_disabled_v : std_logic := '0';
      variable prev_snap_toggle_v : std_logic := '0';
      variable prev_snap_nbytes_v : std_logic_vector(TXNBYTES_BITS-1 downto 0)
                                    := (others => '0');
      variable prev_snap_maxpacket_v : std_logic_vector(1 downto 0)
                                       := (others => '0');
      variable prev_snap_iso_v : std_logic := '0';
      variable prev_snap_ratefeedback_v : std_logic := '0';
      variable prev_snap_hold_v : boolean := false;
      variable expect_drop_clear_v : boolean := false;
      variable expect_drop_hold_v : boolean := false;
      variable expect_pending_hold_v : boolean := false;
      variable expect_snapshot_clear_v : boolean := false;
      variable expect_replacement_stall_v : boolean := false;
      variable expect_fw_stall_v : boolean := false;
      variable prev_stall_release_v : boolean := false;
      variable expect_local_cleanup_v : boolean := false;
      variable expect_bus_reset_cleanup_v : boolean := false;
      variable expect_claim_hold_v : boolean := false;
      variable prev_drop_mask_v : std_logic := '0';
      variable prev_setup_dma_owner_v : std_logic_vector(1 downto 0) :=
                                        (others => '0');
    begin
      if rising_edge(hclk) and (hresetn = '1') then
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
                 (fifo_reservation_r = '0') and
                 (ocp_ep0_txn_r = '0') and (wire_ocp_r = '0')
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
          assert claim_q = '1'
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
        if (unsigned(pie_dev_selected_i) = to_unsigned(C_HUB_SEL, 2)) or
           (unsigned(pie_dev_selected_i) = to_unsigned(C_DEV1_SEL, 2)) then
          if sync_sieint_epinfo_req_i = '1' then
            assert (dma_req_forward_c = '1') and (ocp_resp_sel_c = '0') and
                   (setup_pkt_vld_c = '0')
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
        assert not ((rx_capture_c = '1') and
                    (rx_captured_beats_r =
                     to_unsigned(RX_PACKET_BEATS, rx_captured_beats_r'length)))
          report "post_sync_arb: RX packet staging write past final beat"
          severity failure;
        assert not ((ctrl_out_vld_c = '1') and (rx_validated_r = '0'))
          report "post_sync_arb: downstream write before successful validation"
          severity failure;
        if rx_validated_r = '1' then
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
        if (nbytes_r(15) = '1') and (xfer_dir_in_r = '0') then
          assert ctrl_out_vld_c = '0'
            report "post_sync_arb: oversized OUT request reached downstream"
            severity failure;
        end if;
        if (st = T_PROT_STALL) and (ocp_resp_sel_c = '1')
           and (sync_sieint_epinfo_setup_i = '0') then
          if ocp_ep0_req_c = '1' then
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
        if non_ep0_txn_r = '1' then
          assert (wire_dma_r = '1') and (ocp_resp_sel_c = '0')
            report "post_sync_arb: non-EP0 transaction left legacy DMA"
            severity failure;
        end if;
        if ocp_ep0_txn_r = '1' then
          assert wire_dma_r = '0'
            report "post_sync_arb: OCP EP0 stage reached DMA"
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
        if (claim_q = '1') and (xfer_dir_in_r = '0') and
           (cap_rxdata(23 downto 16) = OCP_INDIRECT_FIFO_DATA) and
           ((st = T_META_WAIT) or (st = T_DATA) or (st = T_STATUS)) and
           (rx_drain_done_r = '0') and
           ((sync_busreset = '1') or (dev0_local_reset_c = '1') or
            (ocp_claim_abort_i = '1') or (new_setup_c = '1')) then
          assert fifo_batch_abort_c = '1'
            report "post_sync_arb: incomplete FIFO command missed batch abort"
            severity failure;
        end if;
        if (sync_busreset = '1') or
           ((dev0_selected_c = '1') and (dev0_local_reset_c = '1')) then
          assert setup_received_c = '0'
            report "post_sync_arb: SETUP notification escaped reset/disconnect gate"
            severity failure;
        else
          assert setup_received_c = sync_sieint_setup_received_i
            report "post_sync_arb: valid connected SETUP notification was not forwarded"
            severity failure;
        end if;

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
                              and (non_ep0_txn_r = '1')
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
                            (ocp_ep0_txn_r = '1') and
                             (sync_sieint_epinfo_req_i = '0') and
                             (sync_sieint_endtransfer_i = '0');
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
        expect_claim_hold_v := (claim_q = '1') and
          (sync_sieint_epinfo_req_i = '1') and
          (dev0_selected_c = '0') and (sync_busreset = '0') and
          (dev0_local_reset_c = '0') and (ocp_claim_abort_i = '0');
        prev_drop_mask_v := drop_setup_success_r;
        prev_setup_dma_owner_v := setup_dma_owner_r;
      end if;
    end process assertions_proc;
    -- pragma translate_on

end architecture rtl;
