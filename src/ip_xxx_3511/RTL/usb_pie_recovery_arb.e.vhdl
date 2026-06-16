--  SPDX-License-Identifier: Apache-2.0
--  ----------------------------------------------------------------------------
--  File: usb_pie_recovery_arb.e.vhdl
--
--  Purpose
--  -------
--  Arbitrate the shared, EP-multiplexed PIE bus surface (see usb_pie.m.vhdl
--  ports lines 335..395) between:
--    (a) the legacy USB EP table (driven by usb_dma via usb_synchronizer)
--    (b) an OCP Recovery v1.1 endpoint living in SystemVerilog above the
--        ip_xxx_3511_hs / ip_xxx_3516_hs_mem wrapper boundary.
--
--  Phase 8 architecture
--  --------------------
--  Class-decode is performed INLINE in this arbiter on the captured SETUP
--  beat.  The arbiter is the SOLE router that decides which side handles a
--  given EP0 control transfer:
--    - Recovery-class SETUP        -> SV recovery stack (autonomous HW resp).
--                                     Legacy SIE / MCU EPCS NEVER sees the
--                                     SETUP-received notification for the
--                                     duration of the transfer.
--    - Any other EP0 SETUP, any    -> legacy SIE / MCU EPCS (bit-identical
--      non-EP0 transaction, any      pass-through of the un-arbitered IP).
--      DATA / handshake beat
--
--  This eliminates the response-side-mux race conditions that motivated the
--  Phase 7 -> Phase 8 rewrite (see /home/ws/caliptra/cwhitehead/copilot/
--  research/usb_ocp_p7_{audit,claim_debug,gate_debug,datapath,prot_cap}.md).
--
--  Spec references
--  ---------------
--  - OCP Recovery v1.1 Section 8.5     -- USB transport overview.
--  - OCP Recovery v1.1 Section 8.5.1   -- Class-specific control transfer
--                                         SETUP encoding:
--                                           bmRequestType[6:5] = 01 (Class)
--                                           bmRequestType[4:0] = 00001 (Iface)
--                                           bRequest           = OCP_RECOVERY_
--                                                                TRANSFER (00h)
--                                           wIndex[7:0]        = REC_IFACE_NUM
--  - USB 2.0 Section 5.5               -- Control transfer model.
--  - USB 2.0 Section 8.5.3             -- Control transfer SETUP/DATA/STATUS
--                                         phasing (and the abandon-on-new-
--                                         SETUP rule).
--  - USB 2.0 Section 9.3 Table 9-2     -- SETUP packet byte layout
--                                         (little-endian on the wire).
--
--  Coding conventions
--  ------------------
--  - library IEEE; numeric_std; no std_logic_unsigned / std_logic_arith.
--  - _r suffix on registered signals, _nxt on next-state, _c on comb.
--  - Two-process FSM (combinational _comb_proc + clocked _clk_proc).
--  - Asynchronous active-low reset (reset_n).
--  ----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity usb_pie_recovery_arb is
  generic (
    USB_DATAWIDTH    : integer := 64;
    -- USB EP number that carries OCP recovery control requests.  Per OCP
    -- Recovery v1.1 Sec 8.5 the recovery interface uses the device default
    -- control pipe (EP0).  Kept as a generic for backward compatibility
    -- with the existing structure-file binding.
    C_REC_EPNR       : integer := 0;
    -- USB Interface Number whose wIndex[7:0] selects the recovery interface
    -- for class-specific SETUPs (OCP Recovery v1.1 Sec 8.5.1, also USB 2.0
    -- Sec 9.3 Tbl 9-2 wIndex semantics for Interface recipients).
    -- Default 0 matches the current SoC composite-device build.
    C_REC_IFACE_NUM  : integer range 0 to 255 := 0
  );
  port (
    -- ------------------------------------------------------------------
    -- Clock / async active-low reset (matches usb_pie.m.vhdl convention).
    -- ------------------------------------------------------------------
    clk      : in  std_logic;
    reset_n  : in  std_logic;

    -- ------------------------------------------------------------------
    -- Lower side - PIE snoop inputs.
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
    -- Lower side - legacy EP-table bundle (from usb_synchronizer).
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
    -- Lower side - muxed bundle delivered into usb_pie's epinfo input set.
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
    -- Same contract that the deleted (Phase 1c) usb_ocp_recovery_ep_adapter
    -- presented; the SV ctrl_decode + regs + cms_fifo + fsm connect
    -- unmodified.  Phase 8 change: setup_pkt_vld is PRE-FILTERED -- the SV
    -- side never sees a non-OCP-class SETUP and consequently no longer
    -- needs its own SETUP-classifier flop.
    -- ------------------------------------------------------------------
    setup_pkt_vld   : out std_logic;
    setup_pkt       : out std_logic_vector(63 downto 0);

    ctrl_out_data   : out std_logic_vector(7 downto 0);
    ctrl_out_vld    : out std_logic;
    ctrl_out_last   : out std_logic;
    ctrl_out_rdy    : in  std_logic;

    ctrl_in_data    : in  std_logic_vector(7 downto 0);
    ctrl_in_vld     : in  std_logic;
    ctrl_in_last    : in  std_logic;
    ctrl_in_rdy     : out std_logic;

    -- STALL request from SV recovery; OR'd into epinfo_to_pie_stall while
    -- the arbiter holds claim (OCP Recovery v1.1 Sec 8.5: malformed class
    -- requests SHALL be STALLed).
    ctrl_set_stall  : in  std_logic;

    -- End-of-stage pulse to SV: re-emit of pie_endtransfer ONLY for the
    -- DATA-stage and STATUS-stage of the claimed transfer (the SETUP-
    -- stage pie_endtransfer is consumed internally by the claim FSM and
    -- is NEVER forwarded; this was the iter-8 Phase 7 corruption root
    -- cause -- see research/usb_ocp_p7_datapath.md Q2).
    ctrl_xfer_done  : out std_logic;

    -- ------------------------------------------------------------------
    -- Claim status (output).  '1' while the arbiter has claimed an OCP
    -- recovery class transfer (any of SETUP / DATA / STATUS stages).
    -- The SV wrapper consumes this purely for visibility; it is NOT in
    -- any combinational feedback loop into the arbiter (the arbiter
    -- decides claim from its own state machine).
    -- ------------------------------------------------------------------
    rec_claim_status : out std_logic;

    -- ------------------------------------------------------------------
    -- Gated copy of pie_epinfo_setup_received for the legacy SIE / MCU
    -- EPCS notification path.  This signal MUST be routed to the legacy
    -- usb_synchronizer in place of the raw pie_epinfo_setup_received so
    -- that the MCU EPCS firmware NEVER sees a SETUP-received notification
    -- for an OCP recovery class transfer.  Otherwise both the SV
    -- recovery decoder and the MCU firmware would race to respond on the
    -- same EP0 transfer (Phase 7 failure mode, see
    -- research/usb_ocp_p7_claim_debug.md).
    -- ------------------------------------------------------------------
    legacy_setup_received_gated : out std_logic
  );
end entity usb_pie_recovery_arb;
