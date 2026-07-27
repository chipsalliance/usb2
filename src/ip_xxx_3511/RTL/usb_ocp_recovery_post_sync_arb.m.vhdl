--  SPDX-License-Identifier: Apache-2.0
--  ----------------------------------------------------------------------------
--  File: usb_ocp_recovery_post_sync_arb.m.vhdl
--
--  Architecture: rtl
--
--  Post-synchronizer OCP Recovery v1.1 EP0 arbiter (see the entity header in
--  usb_ocp_recovery_post_sync_arb.e.vhdl for the full routing model and the
--  G_BRINGUP_MODE staging description).
--
--  This file currently implements MODE_A (transparent pass-through) only.
--  Higher modes (trap/replay, classify, claim, full transfer engine) are added
--  in later milestones behind the G_BRINGUP_MODE selection.  In MODE_A every
--  synchronized SIE signal reaches usb_dma / usb_reg_if unmodified and the
--  response bundle is a bit-for-bit copy of usb_dma's, so legacy USB behaviour
--  is identical to the un-arbitered IP.  The SV recovery-stack outputs are held
--  at benign inactive values because no transfer is ever claimed in MODE_A.
--  ----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

architecture rtl of usb_ocp_recovery_post_sync_arb is

  -- Bring-up mode encodings (see entity header).
  constant MODE_A : integer := 0;
  constant MODE_B : integer := 1;
  constant MODE_C : integer := 2;
  constant MODE_D : integer := 3;
  constant MODE_E : integer := 4;

begin

  -- ======================================================================
  -- MODE_A: transparent pass-through.
  --
  -- Toward usb_dma: forward the synchronized request/RX/completion/fetch
  -- signals unchanged.
  -- Toward usb_reg_if: forward setup_received and the error path unchanged.
  -- Response bundle: return usb_dma's epinfo_sync_* response unchanged.
  -- The pass-through is unconditional in MODE_A; the mode guard is retained so
  -- higher modes can override these assignments with trap/mux logic.
  -- ======================================================================
  gen_mode_a : if G_BRINGUP_MODE = MODE_A generate

    -- Forward toward usb_dma.
    sync_sieint_epinfo_req_o    <= sync_sieint_epinfo_req_i;
    sync_sieint_epinfo_epnr_o   <= sync_sieint_epinfo_epnr_i;
    sync_sieint_epinfo_epdir_o  <= sync_sieint_epinfo_epdir_i;
    sync_sieint_epinfo_setup_o  <= sync_sieint_epinfo_setup_i;
    sync_sieint_rx_nbytes_o     <= sync_sieint_rx_nbytes_i;
    sync_sieint_rxdata_o        <= sync_sieint_rxdata_i;
    sync_sieint_rxdatavalid_o   <= sync_sieint_rxdatavalid_i;
    sync_sieint_endtransfer_o   <= sync_sieint_endtransfer_i;
    sync_sieint_success_o       <= sync_sieint_success_i;
    sync_sieint_sentNAK_o       <= sync_sieint_sentNAK_i;
    sync_sieint_txdatafetched_o <= sync_sieint_txdatafetched_i;

    -- Forward toward usb_reg_if.
    sync_sieint_setup_received_o <= sync_sieint_setup_received_i;
    sync_sieint_error_o          <= sync_sieint_error_i;
    sync_sieint_errortype_o      <= sync_sieint_errortype_i;

    -- Return usb_dma's response bundle unchanged.
    epinfo_sync_valid_o            <= epinfo_sync_valid_dma;
    epinfo_sync_active_o           <= epinfo_sync_active_dma;
    epinfo_sync_disabled_o         <= epinfo_sync_disabled_dma;
    epinfo_sync_toggle_o           <= epinfo_sync_toggle_dma;
    epinfo_sync_stall_o            <= epinfo_sync_stall_dma;
    epinfo_sync_iso_o              <= epinfo_sync_iso_dma;
    epinfo_sync_ratefeedbackmode_o <= epinfo_sync_ratefeedbackmode_dma;
    epinfo_sync_nbytes_o           <= epinfo_sync_nbytes_dma;
    epinfo_sync_maxpacket_o        <= epinfo_sync_maxpacket_dma;
    epinfo_sync_txdata_o           <= epinfo_sync_txdata_dma;
    epinfo_sync_txdata_valid_o     <= epinfo_sync_txdata_valid_dma;

    -- SV recovery stack: no transfer is claimed in MODE_A.  Hold the upper-side
    -- surface at benign inactive values so ctrl_decode sees no request.
    setup_pkt_vld   <= '0';
    setup_pkt       <= (others => '0');
    ctrl_out_data   <= (others => '0');
    ctrl_out_be     <= (others => '0');
    ctrl_out_vld    <= '0';
    ctrl_out_last   <= '0';
    ctrl_in_rdy     <= '0';
    ctrl_xfer_done  <= '0';
    rec_claim_status <= '0';

  end generate gen_mode_a;

  -- ======================================================================
  -- MODE_B and higher: SETUP trap + replay.
  --
  -- Every EP0 SETUP is withheld from usb_dma; the arbiter fabricates the
  -- bit-accurate EP0-SETUP epinfo response toward the SIE (so the SIE accepts
  -- the 8 payload bytes - USB 2.0 Sec 8.4.6.4 requires the SETUP stage to be
  -- ACKed), captures the payload, then (MODE_B: always; higher modes: only if
  -- unclaimed) replays the SETUP to usb_dma so the legacy SRAM write + EP0
  -- interrupt occur exactly as in the un-trapped flow.  usb_dma's own late
  -- response during replay is absorbed (never forwarded to the SIE) because the
  -- SIE-facing response bundle is 2-FF level-synchronized with no back-ack.
  --
  -- This block currently implements MODE_B behaviour (replay every SETUP as
  -- unclaimed; no classification/claim).  Classification (MODE_C), the claimed
  -- OCP path (MODE_D) and the full transfer engine (MODE_E) are added later.
  --
  -- Fabricated EP0-SETUP response (matches usb_dma.m.vhdl READ_EPINFO for
  -- epinfo_setup='1'): valid=1, active=1, disabled=0, toggle=0, stall=0, iso=0,
  -- ratefeedbackmode=0, nbytes=8, maxpacket="00", txdata=0, txdata_valid=0.
  --
  -- Replay data timing: usb_dma sets epinfo_sync_valid on entering CHECK_EPINFO
  -- (1 cycle before WAIT_ON_OUTEP_DATA, which is unconditional), so rxdatavalid
  -- is presented one align cycle after epinfo_sync_valid_dma rises and for
  -- exactly one cycle (usb_dma advances var_pointer on every in-state
  -- rxdatavalid).  epinfo_sync_valid_dma returning to 0 marks usb_dma back in
  -- IDLE (transfer complete).
  --
  -- Ordering: sync_sieint_setup_received (which sets usbreg_setup ->
  -- setup_not_cleared, gating EP0) is withheld during trap/replay and re-emitted
  -- once at replay completion, so the replayed SETUP is processed by usb_dma
  -- with setup_not_cleared=0 (otherwise CHECK_EPINFO diverts to a NAK path).
  --
  -- A new SIE epinfo_req pulse arriving during trap/replay is latched (pending)
  -- and serviced after completion so no request pulse is dropped.
  -- ======================================================================
  gen_trap : if G_BRINGUP_MODE >= MODE_B generate

    -- MODE_D and above route OCP-recovery-class SETUPs to the SV stack;
    -- MODE_B/MODE_C replay every SETUP as unclaimed (claimed path disabled).
    constant CLAIM_EN : boolean := (G_BRINGUP_MODE >= MODE_D);

    constant BYTES_PER_BEAT   : integer := USB_DATAWIDTH / 8;   -- 8 for 64b
    constant RX_ELASTIC_BEATS : integer := 3;
    constant TX_MAXBYTES      : integer := 64;
    constant REC_IFACE_SLV    : std_logic_vector(7 downto 0)
             := std_logic_vector(to_unsigned(C_REC_IFACE_NUM, 8));
    -- OCP Recovery v1.1 Sec 8.5: class-specific control transfer bRequest.
    constant OCP_RECOVERY_TRANSFER : std_logic_vector(7 downto 0) := x"00";

    type t_trap_state is (T_IDLE, T_TRAP,
                          T_REPLAY_REQ, T_REPLAY_ALIGN, T_REPLAY_DATA,
                          T_REPLAY_END, T_PASS,
                          C_DATA, C_STATUS);
    signal st : t_trap_state;

    signal cap_rxdata    : std_logic_vector(USB_DATAWIDTH-1 downto 0);
    signal cap_rx_nbytes : std_logic_vector(RXNBYTES_BITS-1 downto 0);
    signal cap_epnr      : std_logic_vector(3 downto 0);
    signal cap_epdir     : std_logic;
    signal cap_done      : std_logic;
    signal end_seen      : std_logic;
    signal succ_seen     : std_logic;
    signal sr_sent       : std_logic;
    signal sp_sent       : std_logic;

    signal pend_valid : std_logic;
    signal pend_setup : std_logic;
    signal pend_epnr  : std_logic_vector(3 downto 0);
    signal pend_epdir : std_logic;

    signal trig    : std_logic;   -- EP0 SETUP detected in T_IDLE
    signal fwd     : std_logic;   -- forward usb_dma response to the SIE
    signal fab     : std_logic;   -- fabricated SETUP response to the SIE
    signal is_ocp  : std_logic;   -- captured SETUP is OCP-recovery class
    signal claim_q : std_logic;   -- '1' while owning claimed DATA/STATUS

    signal xfer_dir_in_r       : std_logic;              -- SETUP dir (1=IN)
    signal nbytes_r            : unsigned(14 downto 0);  -- OUT wLength budget
    signal tx_response_bytes_r : unsigned(6 downto 0);
    signal tx_response_known_r : std_logic;

    signal in_data_toggle_r : std_logic;
    signal zlp_phase_r      : std_logic;
    signal zlp_owed_c       : std_logic;

    -- Success-qualified end-of-stage pulse (hclk pulse; no edge detect needed).
    signal st_end_c : std_logic;

    -- Control-OUT elastic queue (SIE 64b beats -> SV 32b words).
    type t_rx_buf is array (0 to RX_ELASTIC_BEATS-1)
                       of std_logic_vector(USB_DATAWIDTH-1 downto 0);
    signal rx_buf_r            : t_rx_buf;
    signal rx_wr_beat_r        : unsigned(1 downto 0);
    signal rx_rd_beat_r        : unsigned(1 downto 0);
    signal rx_count_r          : unsigned(1 downto 0);
    signal rx_captured_beats_r : unsigned(3 downto 0);
    signal rx_rd_word_r        : std_logic;
    signal rx_word_index_r     : unsigned(4 downto 0);
    signal rx_total_r          : unsigned(11 downto 0);
    signal rx_end_seen_r       : std_logic;
    signal rx_drain_done_r     : std_logic;
    signal rx_expected_beats_c : unsigned(3 downto 0);
    signal rx_drain_enable_c   : std_logic;
    signal rx_last_word_c      : std_logic;
    signal ctrl_out_data_c     : std_logic_vector(31 downto 0);
    signal ctrl_out_be_c       : std_logic_vector(3 downto 0);
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
    trig <= '1' when (st = T_IDLE)
                 and (sync_sieint_epinfo_req_i = '1')
                 and (sync_sieint_epinfo_setup_i = '1')
                 and (sync_sieint_epinfo_epnr_i = "0000")
             else '0';

    fwd     <= '1' when (st = T_IDLE) or (st = T_PASS) else '0';
    fab     <= '1' when (st = T_TRAP) and (end_seen = '0') else '0';
    claim_q <= '1' when (st = C_DATA) or (st = C_STATUS) else '0';

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

    -- Stage-end pulse (hclk endtransfer is already single-cycle; qualify with
    -- success so a NAK/error edge does not advance the claim FSM).
    st_end_c <= sync_sieint_endtransfer_i and sync_sieint_success_i;

    -- setup_pkt to the SV recovery stack: pulse once per claimed SETUP.
    setup_pkt_vld_c <= '1' when (st = T_TRAP) and (cap_done = '1')
                            and (is_ocp = '1') and CLAIM_EN and (sp_sent = '0')
                        else '0';
    setup_pkt     <= cap_rxdata;
    setup_pkt_vld <= setup_pkt_vld_c;

    -- ------------------------------------------------------------------
    -- Control-OUT elastic queue combinational (SIE 64b beats -> SV 32b words).
    -- ------------------------------------------------------------------
    rx_expected_beats_c <= resize(shift_right(nbytes_r +
                              to_unsigned(BYTES_PER_BEAT-1, nbytes_r'length), 3), 4);
    rx_drain_enable_c <= '1' when (rx_count_r /= to_unsigned(0, rx_count_r'length))
                              and ((rx_count_r > to_unsigned(1, rx_count_r'length))
                                   or (rx_end_seen_r = '1'))
                         else '0';

    rxstream_comb_proc : process (rx_drain_enable_c, rx_rd_beat_r, rx_rd_word_r,
                                  rx_word_index_r, rx_total_r, rx_end_seen_r,
                                  rx_buf_r)
      variable beat_v : integer range 0 to RX_ELASTIC_BEATS-1;
      variable word_v : std_logic_vector(31 downto 0);
      variable rem_v  : unsigned(11 downto 0);
    begin
      ctrl_out_data_c <= (others => '0');
      ctrl_out_be_c   <= (others => '0');
      ctrl_out_vld_c  <= '0';
      ctrl_out_last_c <= '0';
      rx_last_word_c  <= '0';
      if rx_drain_enable_c = '1' then
        beat_v := to_integer(rx_rd_beat_r);
        if rx_rd_word_r = '0' then
          word_v := rx_buf_r(beat_v)(31 downto 0);
        else
          word_v := rx_buf_r(beat_v)(63 downto 32);
        end if;
        ctrl_out_data_c <= word_v;
        ctrl_out_vld_c  <= '1';
        if rx_end_seen_r = '0' then
          ctrl_out_be_c <= "1111";
        else
          rem_v := rx_total_r -
                   to_unsigned(to_integer(rx_word_index_r) * 4, rem_v'length);
          if rem_v >= to_unsigned(4, rem_v'length) then
            ctrl_out_be_c <= "1111";
          else
            case to_integer(rem_v(1 downto 0)) is
              when 1      => ctrl_out_be_c <= "0001";
              when 2      => ctrl_out_be_c <= "0011";
              when 3      => ctrl_out_be_c <= "0111";
              when others => ctrl_out_be_c <= "1111";
            end case;
          end if;
          if rem_v <= to_unsigned(4, rem_v'length) then
            ctrl_out_last_c <= '1';
            rx_last_word_c  <= '1';
          end if;
        end if;
      end if;
    end process rxstream_comb_proc;

    ctrl_out_data <= ctrl_out_data_c;
    ctrl_out_be   <= ctrl_out_be_c;
    ctrl_out_vld  <= ctrl_out_vld_c when (claim_q = '1') else '0';
    ctrl_out_last <= ctrl_out_last_c;

    -- ------------------------------------------------------------------
    -- Control-IN cut-through queue combinational (SV 32b words -> SIE beats).
    -- ------------------------------------------------------------------
    tx_in_data_c <= '1' when (claim_q = '1') and (st = C_DATA)
                             and (xfer_dir_in_r = '1') and (zlp_phase_r = '0')
                     else '0';
    tx_remaining_bytes_c <= tx_response_bytes_r - tx_bytes_sent_r
                            when tx_response_bytes_r >= tx_bytes_sent_r
                            else (others => '0');
    tx_shift_c <= '1' when (tx_in_data_c = '1') and (tx_launch_ready_c = '1')
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

    -- End-of-stage pulse to the SV decoder (OUT: after RX drain; IN: on the
    -- endtransfer once the launch contract is met so an early-IN NAK edge does
    -- not trip the decoder's early-termination escape).
    ctrl_xfer_done <= rx_drain_done_r when (xfer_dir_in_r = '0') else
                      (sync_sieint_endtransfer_i and tx_launch_ready_c)
                        when (st = C_DATA) or (st = C_STATUS) else '0';

    rec_claim_status <= claim_q;

    -- ------------------------------------------------------------------
    -- Sequential FSM + capture / pending / claim registers.
    -- ------------------------------------------------------------------
    p_seq : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        st            <= T_IDLE;
        cap_rxdata    <= (others => '0');
        cap_rx_nbytes <= (others => '0');
        cap_epnr      <= (others => '0');
        cap_epdir     <= '0';
        cap_done      <= '0';
        end_seen      <= '0';
        succ_seen     <= '0';
        sr_sent       <= '0';
        sp_sent       <= '0';
        pend_valid    <= '0';
        pend_setup    <= '0';
        pend_epnr     <= (others => '0');
        pend_epdir    <= '0';
        xfer_dir_in_r <= '0';
        nbytes_r      <= (others => '0');
        tx_response_bytes_r <= (others => '0');
        tx_response_known_r <= '0';
        in_data_toggle_r    <= '1';
        zlp_phase_r         <= '0';
      elsif rising_edge(hclk) then
        if sync_busreset = '1' then
          st         <= T_IDLE;
          cap_done   <= '0';
          end_seen   <= '0';
          succ_seen  <= '0';
          sr_sent    <= '0';
          sp_sent    <= '0';
          pend_valid <= '0';
          in_data_toggle_r <= '1';
          zlp_phase_r      <= '0';
        else
          -- Latch a genuinely new SIE request arriving mid trap/replay/claim.
          if (st /= T_IDLE) and (st /= T_PASS)
             and (sync_sieint_epinfo_req_i = '1') and (pend_valid = '0')
             and not ((st = C_DATA or st = C_STATUS)
                      and (sync_sieint_epinfo_setup_i = '1')) then
            pend_valid <= '1';
            pend_setup <= sync_sieint_epinfo_setup_i;
            pend_epnr  <= sync_sieint_epinfo_epnr_i;
            pend_epdir <= sync_sieint_epinfo_epdir_i;
          end if;

          -- setup_pkt_vld one-shot bookkeeping.
          if setup_pkt_vld_c = '1' then sp_sent <= '1'; end if;

          -- Latch the SV response metadata during the SETUP stage.
          if (st = T_TRAP) and (cap_done = '1') then
            tx_response_bytes_r <= unsigned(ctrl_in_resp_bytes);
            tx_response_known_r <= ctrl_in_resp_known;
          end if;

          -- Data-stage toggle + terminating-ZLP phase (USB 2.0 Sec 5.5.3/8.6).
          if (claim_q = '0') then
            in_data_toggle_r <= '1';
            zlp_phase_r      <= '0';
          elsif (st = C_DATA) and (st_end_c = '1') then
            if (zlp_phase_r = '0') and (zlp_owed_c = '1') then
              zlp_phase_r      <= '1';
              in_data_toggle_r <= not in_data_toggle_r;
            else
              zlp_phase_r <= '0';
            end if;
          end if;

          case st is
            when T_IDLE =>
              if trig = '1' then
                st        <= T_TRAP;
                cap_epnr  <= sync_sieint_epinfo_epnr_i;
                cap_epdir <= sync_sieint_epinfo_epdir_i;
                cap_done  <= '0';
                end_seen  <= '0';
                succ_seen <= '0';
                sr_sent   <= '0';
                sp_sent   <= '0';
                tx_response_bytes_r <= (others => '0');
                tx_response_known_r <= '0';
              elsif pend_valid = '1' then
                if (pend_setup = '1') and (pend_epnr = "0000") then
                  st        <= T_TRAP;
                  cap_epnr  <= pend_epnr;
                  cap_epdir <= pend_epdir;
                  cap_done  <= '0';
                  end_seen  <= '0';
                  succ_seen <= '0';
                  sr_sent   <= '0';
                  sp_sent   <= '0';
                  tx_response_bytes_r <= (others => '0');
                  tx_response_known_r <= '0';
                  pend_valid <= '0';
                else
                  st <= T_PASS;
                end if;
              end if;

            when T_TRAP =>
              if sync_sieint_rxdatavalid_i = '1' then
                cap_rxdata    <= sync_sieint_rxdata_i;
                cap_rx_nbytes <= sync_sieint_rx_nbytes_i;
                cap_done      <= '1';
                xfer_dir_in_r <= sync_sieint_rxdata_i(7);
                nbytes_r      <= unsigned(sync_sieint_rxdata_i(62 downto 48));
              end if;
              if sync_sieint_endtransfer_i = '1' then end_seen  <= '1'; end if;
              if sync_sieint_success_i     = '1' then succ_seen <= '1'; end if;
              if (end_seen = '1') or (sync_sieint_endtransfer_i = '1') then
                if (is_ocp = '1') and CLAIM_EN then
                  if nbytes_r = to_unsigned(0, nbytes_r'length) then
                    st <= C_STATUS;
                  else
                    st <= C_DATA;
                  end if;
                else
                  st <= T_REPLAY_REQ;
                end if;
              end if;

            when T_REPLAY_REQ =>
              if epinfo_sync_valid_dma = '1' then st <= T_REPLAY_ALIGN; end if;

            when T_REPLAY_ALIGN =>
              st <= T_REPLAY_DATA;

            when T_REPLAY_DATA =>
              st <= T_REPLAY_END;

            when T_REPLAY_END =>
              if sr_sent = '0' then sr_sent <= '1'; end if;
              if epinfo_sync_valid_dma = '0' then
                if pend_valid = '1' then
                  if (pend_setup = '1') and (pend_epnr = "0000") then
                    st        <= T_TRAP;
                    cap_epnr  <= pend_epnr;
                    cap_epdir <= pend_epdir;
                    cap_done  <= '0';
                    end_seen  <= '0';
                    succ_seen <= '0';
                    sr_sent   <= '0';
                    sp_sent   <= '0';
                    tx_response_bytes_r <= (others => '0');
                    tx_response_known_r <= '0';
                    pend_valid <= '0';
                  else
                    st <= T_PASS;
                  end if;
                else
                  st <= T_IDLE;
                end if;
              end if;

            when T_PASS =>
              pend_valid <= '0';
              st <= T_IDLE;

            when C_DATA =>
              -- New SETUP mid-transfer: host abandoned (USB 2.0 Sec 8.5.3).
              if (sync_sieint_epinfo_req_i = '1')
                 and (sync_sieint_epinfo_setup_i = '1')
                 and (sync_sieint_epinfo_epnr_i = "0000") then
                st       <= T_TRAP;
                cap_done <= '0';
                end_seen <= '0';
                sr_sent  <= '0';
                sp_sent  <= '0';
              elsif st_end_c = '1' then
                if (zlp_phase_r = '0') and (zlp_owed_c = '1') then
                  st <= C_DATA;               -- emit terminating ZLP first
                else
                  st <= C_STATUS;
                end if;
              end if;

            when C_STATUS =>
              if (sync_sieint_epinfo_req_i = '1')
                 and (sync_sieint_epinfo_setup_i = '1')
                 and (sync_sieint_epinfo_epnr_i = "0000") then
                st       <= T_TRAP;
                cap_done <= '0';
                end_seen <= '0';
                sr_sent  <= '0';
                sp_sent  <= '0';
              elsif (st_end_c = '1')
                    and (rx_count_r = to_unsigned(0, rx_count_r'length)) then
                st <= T_IDLE;
              end if;

            when others =>
              st <= T_IDLE;
          end case;
        end if;
      end if;
    end process p_seq;

    -- ------------------------------------------------------------------
    -- Control-OUT elastic buffer (clocked).
    -- ------------------------------------------------------------------
    rxbuf_clk_proc : process (hclk, hresetn)
      variable capture_v : boolean;
      variable pop_v     : boolean;
    begin
      if hresetn = '0' then
        for i in 0 to RX_ELASTIC_BEATS-1 loop
          rx_buf_r(i) <= (others => '0');
        end loop;
        rx_wr_beat_r        <= (others => '0');
        rx_rd_beat_r        <= (others => '0');
        rx_count_r          <= (others => '0');
        rx_captured_beats_r <= (others => '0');
        rx_rd_word_r        <= '0';
        rx_word_index_r     <= (others => '0');
        rx_total_r          <= (others => '0');
        rx_end_seen_r       <= '0';
        rx_drain_done_r     <= '0';
      elsif rising_edge(hclk) then
        rx_drain_done_r <= '0';
        if claim_q = '0' then
          for i in 0 to RX_ELASTIC_BEATS-1 loop
            rx_buf_r(i) <= (others => '0');
          end loop;
          rx_wr_beat_r        <= (others => '0');
          rx_rd_beat_r        <= (others => '0');
          rx_count_r          <= (others => '0');
          rx_captured_beats_r <= (others => '0');
          rx_rd_word_r        <= '0';
          rx_word_index_r     <= (others => '0');
          rx_total_r          <= (others => '0');
          rx_end_seen_r       <= '0';
        else
          pop_v := (rx_drain_enable_c = '1') and (ctrl_out_rdy = '1') and
                   ((rx_rd_word_r = '1') or (ctrl_out_last_c = '1'));
          capture_v := (sync_sieint_rxdatavalid_i = '1') and
                       (sync_sieint_epinfo_setup_i = '0') and
                       (rx_captured_beats_r < rx_expected_beats_c) and
                       ((rx_count_r < to_unsigned(RX_ELASTIC_BEATS, rx_count_r'length))
                        or pop_v);
          if capture_v then
            rx_buf_r(to_integer(rx_wr_beat_r)) <= sync_sieint_rxdata_i;
            if rx_wr_beat_r = to_unsigned(RX_ELASTIC_BEATS-1, rx_wr_beat_r'length) then
              rx_wr_beat_r <= (others => '0');
            else
              rx_wr_beat_r <= rx_wr_beat_r + 1;
            end if;
            rx_captured_beats_r <= rx_captured_beats_r + 1;
          end if;
          if pop_v then
            if ctrl_out_last_c = '1' then rx_drain_done_r <= '1'; end if;
            if rx_rd_beat_r = to_unsigned(RX_ELASTIC_BEATS-1, rx_rd_beat_r'length) then
              rx_rd_beat_r <= (others => '0');
            else
              rx_rd_beat_r <= rx_rd_beat_r + 1;
            end if;
          end if;
          if capture_v and not pop_v then
            rx_count_r <= rx_count_r + 1;
          elsif pop_v and not capture_v then
            rx_count_r <= rx_count_r - 1;
          end if;
          if (rx_drain_enable_c = '1') and (ctrl_out_rdy = '1') then
            if rx_rd_word_r = '0' then
              rx_rd_word_r    <= '1';
              rx_word_index_r <= rx_word_index_r + 1;
            else
              rx_rd_word_r    <= '0';
              rx_word_index_r <= rx_word_index_r + 1;
            end if;
          end if;
          if (st_end_c = '1') and (st = C_DATA) and (xfer_dir_in_r = '0') then
            rx_total_r    <= unsigned(sync_sieint_rx_nbytes_i);
            rx_end_seen_r <= '1';
            if unsigned(sync_sieint_rx_nbytes_i) = 0 then
              rx_drain_done_r <= '1';
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
        if claim_q = '0' then
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
    -- Outputs toward usb_dma (withheld entirely while a claim is owned).
    -- ------------------------------------------------------------------
    sync_sieint_epinfo_req_o <=
        '0' when (claim_q = '1')                       else
        '1' when (st = T_REPLAY_REQ) or (st = T_PASS)  else
        '0' when (st = T_IDLE) and (trig = '1')        else
        sync_sieint_epinfo_req_i when (st = T_IDLE)    else
        '0';

    sync_sieint_epinfo_setup_o <=
        '0'        when (claim_q = '1')                             else
        '1'        when (st = T_REPLAY_REQ) or (st = T_REPLAY_ALIGN)
                     or (st = T_REPLAY_DATA) or (st = T_REPLAY_END) else
        pend_setup when (st = T_PASS)                               else
        '0'        when (st = T_TRAP)                               else
        '0'        when (st = T_IDLE) and (trig = '1')              else
        sync_sieint_epinfo_setup_i;

    sync_sieint_epinfo_epnr_o <=
        "0000"    when (claim_q = '1')                             else
        "0000"    when (st = T_REPLAY_REQ) or (st = T_REPLAY_ALIGN)
                    or (st = T_REPLAY_DATA) or (st = T_REPLAY_END) else
        pend_epnr when (st = T_PASS)                               else
        sync_sieint_epinfo_epnr_i;

    sync_sieint_epinfo_epdir_o <=
        '0'        when (claim_q = '1')                             else
        '0'        when (st = T_REPLAY_REQ) or (st = T_REPLAY_ALIGN)
                     or (st = T_REPLAY_DATA) or (st = T_REPLAY_END) else
        pend_epdir when (st = T_PASS)                               else
        sync_sieint_epinfo_epdir_i;

    sync_sieint_rx_nbytes_o <=
        cap_rx_nbytes when (st = T_REPLAY_REQ) or (st = T_REPLAY_ALIGN)
                        or (st = T_REPLAY_DATA) or (st = T_REPLAY_END) else
        sync_sieint_rx_nbytes_i;

    sync_sieint_rxdata_o <=
        cap_rxdata when (st = T_REPLAY_DATA) else
        sync_sieint_rxdata_i;

    sync_sieint_rxdatavalid_o <=
        '0' when (claim_q = '1')                                    else
        '1' when (st = T_REPLAY_DATA)                               else
        '0' when (st = T_TRAP) or (st = T_REPLAY_REQ)
              or (st = T_REPLAY_ALIGN) or (st = T_REPLAY_END)       else
        '0' when (st = T_IDLE) and (trig = '1')                     else
        sync_sieint_rxdatavalid_i;

    sync_sieint_endtransfer_o <=
        '0' when (claim_q = '1')                                    else
        '1' when (st = T_REPLAY_END)                                else
        '0' when (st = T_TRAP) or (st = T_REPLAY_REQ)
              or (st = T_REPLAY_ALIGN) or (st = T_REPLAY_DATA)      else
        '0' when (st = T_IDLE) and (trig = '1')                     else
        sync_sieint_endtransfer_i;

    sync_sieint_success_o <=
        '0' when (claim_q = '1')                                    else
        '1' when (st = T_REPLAY_END)                                else
        '0' when (st = T_TRAP) or (st = T_REPLAY_REQ)
              or (st = T_REPLAY_ALIGN) or (st = T_REPLAY_DATA)      else
        '0' when (st = T_IDLE) and (trig = '1')                     else
        sync_sieint_success_i;

    sync_sieint_sentNAK_o       <= sync_sieint_sentNAK_i;
    sync_sieint_txdatafetched_o <= sync_sieint_txdatafetched_i;

    -- Toward usb_reg_if: gate setup_received during trap/replay/claim; re-emit
    -- one pulse at unclaimed-replay completion.  Claimed SETUPs never notify
    -- the legacy register block (full isolation).
    sync_sieint_setup_received_o <=
        '0' when (claim_q = '1')                          else
        '1' when (st = T_REPLAY_END) and (sr_sent = '0')  else
        '0' when (st /= T_IDLE) and (st /= T_PASS)        else
        '0' when (st = T_IDLE) and (trig = '1')           else
        sync_sieint_setup_received_i;

    sync_sieint_error_o     <= sync_sieint_error_i;
    sync_sieint_errortype_o <= sync_sieint_errortype_i;

    -- ------------------------------------------------------------------
    -- Response bundle toward the synchronizer / SIE.
    --   claim_q : arbiter-fabricated claimed DATA/STATUS response.
    --   fab     : fabricated EP0-SETUP response (trapped SETUP stage).
    --   fwd     : usb_dma's live response (T_IDLE / T_PASS).
    --   else    : benign idle during unclaimed replay.
    -- ------------------------------------------------------------------
    epinfo_sync_valid_o <=
        '1'                   when (claim_q = '1') else
        epinfo_sync_valid_dma when (fwd = '1')     else
        '1'                   when (fab = '1')     else '0';

    epinfo_sync_active_o <=
        '0' when (claim_q = '1') and (tx_in_data_c = '1')
                                 and (tx_launch_ready_c = '0') else
        '1'                    when (claim_q = '1') else
        epinfo_sync_active_dma when (fwd = '1')     else
        '1'                    when (fab = '1')     else '0';

    epinfo_sync_disabled_o <=
        '0'                      when (claim_q = '1') else
        epinfo_sync_disabled_dma when (fwd = '1')     else '0';

    epinfo_sync_toggle_o <=
        in_data_toggle_r       when (claim_q = '1') and (st = C_DATA)   else
        '1'                    when (claim_q = '1') and (st = C_STATUS) else
        epinfo_sync_toggle_dma when (fwd = '1')                         else '0';

    epinfo_sync_stall_o <=
        ctrl_set_stall        when (claim_q = '1') else
        epinfo_sync_stall_dma when (fwd = '1')     else '0';

    epinfo_sync_iso_o <=
        '0'                 when (claim_q = '1') else
        epinfo_sync_iso_dma when (fwd = '1')     else '0';

    epinfo_sync_ratefeedbackmode_o <=
        '0'                              when (claim_q = '1') else
        epinfo_sync_ratefeedbackmode_dma when (fwd = '1')     else '0';

    epinfo_sync_nbytes_o <=
        (others => '0')
            when (claim_q = '1') and ((st = C_STATUS) or (zlp_phase_r = '1')) else
        std_logic_vector(resize(tx_response_bytes_r, TXNBYTES_BITS))
            when (claim_q = '1') and (tx_in_data_c = '1')                     else
        std_logic_vector(nbytes_r)   when (claim_q = '1') else
        epinfo_sync_nbytes_dma       when (fwd = '1')     else
        NBYTES8                      when (fab = '1')     else (others => '0');

    epinfo_sync_maxpacket_o <=
        "00"                      when (claim_q = '1') else
        epinfo_sync_maxpacket_dma when (fwd = '1')     else "00";

    epinfo_sync_txdata_o <=
        tx_curr_data_r         when (claim_q = '1') else
        epinfo_sync_txdata_dma when (fwd = '1')     else (others => '0');

    epinfo_sync_txdata_valid_o <=
        tx_beat_valid_c              when (claim_q = '1') else
        epinfo_sync_txdata_valid_dma when (fwd = '1')     else '0';

  end generate gen_trap;

end architecture rtl;
