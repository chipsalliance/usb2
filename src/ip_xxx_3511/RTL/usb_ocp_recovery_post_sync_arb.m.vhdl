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

    type t_trap_state is (T_IDLE, T_TRAP,
                          T_REPLAY_REQ, T_REPLAY_ALIGN, T_REPLAY_DATA,
                          T_REPLAY_END, T_PASS);
    signal st : t_trap_state;

    signal cap_rxdata    : std_logic_vector(USB_DATAWIDTH-1 downto 0);
    signal cap_rx_nbytes : std_logic_vector(RXNBYTES_BITS-1 downto 0);
    signal cap_epnr      : std_logic_vector(3 downto 0);
    signal cap_epdir     : std_logic;
    signal end_seen      : std_logic;
    signal succ_seen     : std_logic;
    signal sr_sent       : std_logic;

    signal pend_valid : std_logic;
    signal pend_setup : std_logic;
    signal pend_epnr  : std_logic_vector(3 downto 0);
    signal pend_epdir : std_logic;

    signal trig : std_logic;   -- EP0 SETUP detected in T_IDLE
    signal fwd  : std_logic;   -- forward usb_dma response to the SIE
    signal fab  : std_logic;   -- drive fabricated SETUP response to the SIE

    constant NBYTES8 : std_logic_vector(TXNBYTES_BITS-1 downto 0)
                       := std_logic_vector(to_unsigned(8, TXNBYTES_BITS));

  begin

    -- ------------------------------------------------------------------
    -- Control decodes.
    -- ------------------------------------------------------------------
    trig <= '1' when (st = T_IDLE)
                 and (sync_sieint_epinfo_req_i = '1')
                 and (sync_sieint_epinfo_setup_i = '1')
                 and (sync_sieint_epinfo_epnr_i = "0000")
             else '0';

    fwd  <= '1' when (st = T_IDLE) or (st = T_PASS) else '0';
    fab  <= '1' when (st = T_TRAP) and (end_seen = '0') else '0';

    -- ------------------------------------------------------------------
    -- Sequential FSM + capture/pending registers.
    -- ------------------------------------------------------------------
    p_seq : process (hclk, hresetn)
    begin
      if hresetn = '0' then
        st            <= T_IDLE;
        cap_rxdata    <= (others => '0');
        cap_rx_nbytes <= (others => '0');
        cap_epnr      <= (others => '0');
        cap_epdir     <= '0';
        end_seen      <= '0';
        succ_seen     <= '0';
        sr_sent       <= '0';
        pend_valid    <= '0';
        pend_setup    <= '0';
        pend_epnr     <= (others => '0');
        pend_epdir    <= '0';
      elsif rising_edge(hclk) then
        if sync_busreset = '1' then
          st         <= T_IDLE;
          end_seen   <= '0';
          succ_seen  <= '0';
          sr_sent    <= '0';
          pend_valid <= '0';
        else
          -- Latch a genuinely new SIE request that arrives mid trap/replay so
          -- its one-cycle pulse is not lost (serviced after completion).
          if (st /= T_IDLE) and (st /= T_PASS)
             and (sync_sieint_epinfo_req_i = '1') and (pend_valid = '0') then
            pend_valid <= '1';
            pend_setup <= sync_sieint_epinfo_setup_i;
            pend_epnr  <= sync_sieint_epinfo_epnr_i;
            pend_epdir <= sync_sieint_epinfo_epdir_i;
          end if;

          case st is
            when T_IDLE =>
              if trig = '1' then
                st        <= T_TRAP;
                cap_epnr  <= sync_sieint_epinfo_epnr_i;
                cap_epdir <= sync_sieint_epinfo_epdir_i;
                end_seen  <= '0';
                succ_seen <= '0';
                sr_sent   <= '0';
              elsif pend_valid = '1' then
                if (pend_setup = '1') and (pend_epnr = "0000") then
                  st         <= T_TRAP;
                  cap_epnr   <= pend_epnr;
                  cap_epdir  <= pend_epdir;
                  end_seen   <= '0';
                  succ_seen  <= '0';
                  sr_sent    <= '0';
                  pend_valid <= '0';
                else
                  st <= T_PASS;
                end if;
              end if;

            when T_TRAP =>
              if sync_sieint_rxdatavalid_i = '1' then
                cap_rxdata    <= sync_sieint_rxdata_i;
                cap_rx_nbytes <= sync_sieint_rx_nbytes_i;
              end if;
              if sync_sieint_endtransfer_i = '1' then end_seen  <= '1'; end if;
              if sync_sieint_success_i     = '1' then succ_seen <= '1'; end if;
              if (end_seen = '1') or (sync_sieint_endtransfer_i = '1') then
                st <= T_REPLAY_REQ;
              end if;

            when T_REPLAY_REQ =>
              if epinfo_sync_valid_dma = '1' then
                st <= T_REPLAY_ALIGN;
              end if;

            when T_REPLAY_ALIGN =>
              st <= T_REPLAY_DATA;

            when T_REPLAY_DATA =>
              st <= T_REPLAY_END;

            when T_REPLAY_END =>
              if sr_sent = '0' then sr_sent <= '1'; end if;
              if epinfo_sync_valid_dma = '0' then
                if pend_valid = '1' then
                  if (pend_setup = '1') and (pend_epnr = "0000") then
                    st         <= T_TRAP;
                    cap_epnr   <= pend_epnr;
                    cap_epdir  <= pend_epdir;
                    end_seen   <= '0';
                    succ_seen  <= '0';
                    sr_sent    <= '0';
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

            when others =>
              st <= T_IDLE;
          end case;
        end if;
      end if;
    end process p_seq;

    -- ------------------------------------------------------------------
    -- Outputs toward usb_dma.
    -- ------------------------------------------------------------------
    sync_sieint_epinfo_req_o <=
        '1' when (st = T_REPLAY_REQ) or (st = T_PASS) else
        '0' when (st = T_IDLE) and (trig = '1')       else
        sync_sieint_epinfo_req_i when (st = T_IDLE)   else
        '0';

    sync_sieint_epinfo_setup_o <=
        '1'        when (st = T_REPLAY_REQ) or (st = T_REPLAY_ALIGN)
                     or (st = T_REPLAY_DATA) or (st = T_REPLAY_END) else
        pend_setup when (st = T_PASS)                               else
        '0'        when (st = T_TRAP)                               else
        '0'        when (st = T_IDLE) and (trig = '1')              else
        sync_sieint_epinfo_setup_i;

    sync_sieint_epinfo_epnr_o <=
        "0000"    when (st = T_REPLAY_REQ) or (st = T_REPLAY_ALIGN)
                    or (st = T_REPLAY_DATA) or (st = T_REPLAY_END) else
        pend_epnr when (st = T_PASS)                               else
        sync_sieint_epinfo_epnr_i;

    sync_sieint_epinfo_epdir_o <=
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
        '1' when (st = T_REPLAY_DATA)                                    else
        '0' when (st = T_TRAP) or (st = T_REPLAY_REQ)
              or (st = T_REPLAY_ALIGN) or (st = T_REPLAY_END)            else
        '0' when (st = T_IDLE) and (trig = '1')                          else
        sync_sieint_rxdatavalid_i;

    sync_sieint_endtransfer_o <=
        '1' when (st = T_REPLAY_END)                                     else
        '0' when (st = T_TRAP) or (st = T_REPLAY_REQ)
              or (st = T_REPLAY_ALIGN) or (st = T_REPLAY_DATA)           else
        '0' when (st = T_IDLE) and (trig = '1')                          else
        sync_sieint_endtransfer_i;

    sync_sieint_success_o <=
        '1' when (st = T_REPLAY_END)                                     else
        '0' when (st = T_TRAP) or (st = T_REPLAY_REQ)
              or (st = T_REPLAY_ALIGN) or (st = T_REPLAY_DATA)           else
        '0' when (st = T_IDLE) and (trig = '1')                          else
        sync_sieint_success_i;

    sync_sieint_sentNAK_o       <= sync_sieint_sentNAK_i;
    sync_sieint_txdatafetched_o <= sync_sieint_txdatafetched_i;

    -- Toward usb_reg_if: gate setup_received during trap/replay and re-emit one
    -- pulse at replay completion to preserve the usbreg_setup ordering.
    sync_sieint_setup_received_o <=
        '1' when (st = T_REPLAY_END) and (sr_sent = '0')  else
        '0' when (st /= T_IDLE) and (st /= T_PASS)        else
        '0' when (st = T_IDLE) and (trig = '1')           else
        sync_sieint_setup_received_i;

    sync_sieint_error_o     <= sync_sieint_error_i;
    sync_sieint_errortype_o <= sync_sieint_errortype_i;

    -- ------------------------------------------------------------------
    -- Response bundle toward usb_synchronizer / SIE.
    --   fwd : forward usb_dma's live response (T_IDLE / T_PASS).
    --   fab : drive the fabricated EP0-SETUP response (trapped SETUP).
    --   else: benign idle (arbiter owns the mux during replay).
    -- ------------------------------------------------------------------
    epinfo_sync_valid_o <=
        epinfo_sync_valid_dma when (fwd = '1') else
        '1'                   when (fab = '1') else '0';

    epinfo_sync_active_o <=
        epinfo_sync_active_dma when (fwd = '1') else
        '1'                    when (fab = '1') else '0';

    epinfo_sync_disabled_o <=
        epinfo_sync_disabled_dma when (fwd = '1') else '0';

    epinfo_sync_toggle_o <=
        epinfo_sync_toggle_dma when (fwd = '1') else '0';

    epinfo_sync_stall_o <=
        epinfo_sync_stall_dma when (fwd = '1') else '0';

    epinfo_sync_iso_o <=
        epinfo_sync_iso_dma when (fwd = '1') else '0';

    epinfo_sync_ratefeedbackmode_o <=
        epinfo_sync_ratefeedbackmode_dma when (fwd = '1') else '0';

    epinfo_sync_nbytes_o <=
        epinfo_sync_nbytes_dma when (fwd = '1') else
        NBYTES8                when (fab = '1') else (others => '0');

    epinfo_sync_maxpacket_o <=
        epinfo_sync_maxpacket_dma when (fwd = '1') else "00";

    epinfo_sync_txdata_o <=
        epinfo_sync_txdata_dma when (fwd = '1') else (others => '0');

    epinfo_sync_txdata_valid_o <=
        epinfo_sync_txdata_valid_dma when (fwd = '1') else '0';

    -- ------------------------------------------------------------------
    -- SV recovery-stack surface: nothing is claimed in MODE_B..MODE_C, so the
    -- upper interface is held inactive.  Claimed routing is added in MODE_D.
    -- ------------------------------------------------------------------
    setup_pkt_vld    <= '0';
    setup_pkt        <= (others => '0');
    ctrl_out_data    <= (others => '0');
    ctrl_out_be      <= (others => '0');
    ctrl_out_vld     <= '0';
    ctrl_out_last    <= '0';
    ctrl_in_rdy      <= '0';
    ctrl_xfer_done   <= '0';
    rec_claim_status <= '0';

  end generate gen_trap;

end architecture rtl;
