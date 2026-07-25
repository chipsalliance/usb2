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

end architecture rtl;
