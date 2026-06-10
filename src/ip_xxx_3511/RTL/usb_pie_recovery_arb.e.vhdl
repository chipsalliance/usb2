--  SPDX-License-Identifier: Apache-2.0
--  ----------------------------------------------------------------------------
--  File: usb_pie_recovery_arb.e.vhdl
--
--  Purpose:
--    Arbitrate the shared, EP-multiplexed PIE bus surface (see
--    usb_pie.m.vhdl entity ports lines 335..395) between the legacy USB EP
--    table (driven by usb_dma via usb_synchronizer) and an OCP Recovery v1.1
--    endpoint living in SystemVerilog above the wrapper.
--
--    Architecture: EP0-only (per plan D0.A).  Only EP0 traffic is shared;
--    bulk endpoints belong exclusively to the legacy EP table.  Arbitration
--    on EP0 is controlled by the recovery side asserting rec_claim while it
--    owns an in-flight class request data/status stage.  When rec_claim is
--    not asserted the arbiter is a transparent pass-through: legacy_epinfo_*
--    => epinfo_to_pie_*.
--
--    Upper-side surface: byte-stream contract identical to the legacy
--    usb_ocp_recovery_ep_adapter (deleted in Phase 1c per plan D0.B) so
--    that the SV stack (ctrl_decode, regs, cms_fifo, fsm) connects
--    unmodified.
--
--  Spec references:
--    - OCP Recovery v1.1 Section 8.5 (USB transport): class-specific control
--      requests on EP0 (bmRequestType[6:5]=01 + recipient=interface).
--    - USB 2.0 Section 8.5.3 (Control transfers / SETUP packet framing): 8
--      bytes payload, ACK by device within 1.5 us @ HS (already met by
--      usb_pie; arbiter does not lie in this path).
--    - USB 2.0 Section 9.3-9.4 (standard request framework).
--
--  Coding conventions (project VHDL):
--    - library IEEE; numeric_std; no std_logic_unsigned / arith.
--    - _r suffix on registered signals, _nxt suffix on next-state.
--    - Two-process FSM, defaults at top of comb process.
--    - Async active-low reset (reset_n) clk_proc.
--  ----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity usb_pie_recovery_arb is
  generic (
    USB_DATAWIDTH : integer := 64;
    -- EP number that carries OCP recovery class-specific requests.
    -- Per OCP Recovery v1.1 Section 8.5 the recovery interface uses EP0
    -- for control-class requests.
    C_REC_EPNR    : integer := 0
  );
  port (
    -- ------------------------------------------------------------------
    -- Clock / async active-low reset (matches usb_pie.m.vhdl convention)
    -- ------------------------------------------------------------------
    clk      : in  std_logic;
    reset_n  : in  std_logic;

    -- ------------------------------------------------------------------
    -- Lower side - PIE snoop (PIE outputs - this arbiter only reads them)
    -- ------------------------------------------------------------------
    pie_epinfo_req            : in  std_logic;
    pie_epinfo_epnr           : in  std_logic_vector(3 downto 0);
    pie_epinfo_epdir          : in  std_logic;
    pie_epinfo_setup          : in  std_logic;
    pie_epinfo_setup_received : in  std_logic;
    pie_rxdata                : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
    pie_rxdatavalid           : in  std_logic;
    pie_rx_nbytes             : in  std_logic_vector(11 downto 0);
    pie_endtransfer           : in  std_logic;
    pie_success               : in  std_logic;
    pie_error                 : in  std_logic;
    pie_txdata_fetched        : in  std_logic;

    -- ------------------------------------------------------------------
    -- Lower side - legacy EP table (usb_dma via usb_synchronizer) inputs.
    -- These mirror exactly what would otherwise go into the PIE entity's
    -- epinfo_* input bundle.
    -- ------------------------------------------------------------------
    legacy_epinfo_valid       : in  std_logic;
    legacy_epinfo_active      : in  std_logic;
    legacy_epinfo_disabled    : in  std_logic;
    legacy_epinfo_toggle      : in  std_logic;
    legacy_epinfo_stall       : in  std_logic;
    legacy_epinfo_iso         : in  std_logic;
    legacy_epinfo_nbytes      : in  std_logic_vector(14 downto 0);
    legacy_epinfo_maxpacket   : in  std_logic_vector(1 downto 0);
    legacy_epinfo_txdata      : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
    legacy_epinfo_txdata_valid: in  std_logic;

    -- ------------------------------------------------------------------
    -- Lower side - muxed outputs to PIE entity's epinfo_* input bundle.
    -- ------------------------------------------------------------------
    epinfo_to_pie_valid       : out std_logic;
    epinfo_to_pie_active      : out std_logic;
    epinfo_to_pie_disabled    : out std_logic;
    epinfo_to_pie_toggle      : out std_logic;
    epinfo_to_pie_stall       : out std_logic;
    epinfo_to_pie_iso         : out std_logic;
    epinfo_to_pie_nbytes      : out std_logic_vector(14 downto 0);
    epinfo_to_pie_maxpacket   : out std_logic_vector(1 downto 0);
    epinfo_to_pie_txdata      : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
    epinfo_to_pie_txdata_valid: out std_logic;

    -- ------------------------------------------------------------------
    -- Upper side - byte-stream surface to the SV recovery stack.
    -- Matches the contract of the (now deleted, Phase 1c per plan D0.B)
    -- usb_ocp_recovery_ep_adapter upper side.
    -- ------------------------------------------------------------------

    -- SETUP packet (8 bytes captured from pie_rxdata, qualified by
    -- pie_epinfo_setup + pie_rxdatavalid).
    setup_pkt_vld   : out std_logic;
    setup_pkt       : out std_logic_vector(63 downto 0);

    -- Control-OUT byte stream (host -> device, data stage of EP0 class req).
    ctrl_out_data   : out std_logic_vector(7 downto 0);
    ctrl_out_vld    : out std_logic;
    ctrl_out_last   : out std_logic;
    ctrl_out_rdy    : in  std_logic;

    -- Control-IN byte stream (device -> host, response on EP0).
    ctrl_in_data    : in  std_logic_vector(7 downto 0);
    ctrl_in_vld     : in  std_logic;
    ctrl_in_last    : in  std_logic;
    ctrl_in_rdy     : out std_logic;

    -- Stall request from recovery; OR'd into epinfo_to_pie_stall.
    ctrl_set_stall  : in  std_logic;

    -- End-of-transaction pulse to SV (re-emit of pie_endtransfer while
    -- recovery owns EP0).
    ctrl_xfer_done  : out std_logic;

    -- Recovery claim: high while ctrl_decode owns the in-flight EP0
    -- transaction (asserted after SETUP classified as class-specific,
    -- deasserted on ctrl_xfer_done).  When low the arbiter passes the
    -- legacy bundle through unmodified.
    rec_claim       : in  std_logic
  );
end entity usb_pie_recovery_arb;
