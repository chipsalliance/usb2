--  SPDX-License-Identifier: Apache-2.0
--  ----------------------------------------------------------------------------
--  File: usb_ocp_recovery_post_sync_arb.e.vhdl
--
--  Purpose
--  -------
--  Post-synchronizer OCP Recovery v1.1 EP0 arbiter.  This entity splices into
--  the hclk (dev_axi_aclk) domain between usb_synchronizer and the two
--  downstream consumers of the synchronized SIE interface:
--    - usb_dma      : the legacy EP-table DMA engine (epinfo request/response
--                     boundary, RX data, completion status).
--    - usb_reg_if   : the register/interrupt block (setup_received, error).
--
--  It replaces the legacy PIE-domain usb_pie_recovery_arb.  Arbitrating on the
--  hclk side (after usb_synchronizer) removes the OCP-specific control CDC and
--  lets the SystemVerilog OCP recovery stack (usb_ocp_recovery_top) run in the
--  same dev_axi_aclk domain, so the rec_*/ctrl_* interface is single-domain.
--
--  Routing model
--  -------------
--  Every EP0 SETUP is trapped in hclk, its eight payload bytes are captured,
--  and the transfer is classified as OCP-recovery class or not:
--    - Recovery-class SETUP -> routed to the SV recovery stack; the SETUP and
--      its downstream side effects are withheld from usb_dma and usb_reg_if so
--      the legacy path produces no SRAM write, descriptor update, endpoint
--      interrupt, toggle, or NAK-status effect.
--    - Any other EP0 SETUP, any non-EP0 transaction, and every DATA/handshake
--      beat of an unclaimed transfer -> replayed bit-identically to usb_dma /
--      usb_reg_if (transparent legacy pass-through).
--
--  Spec references
--  ---------------
--  - OCP Recovery v1.1 Section 8.5   -- USB transport, class-specific control
--                                       transfer SETUP encoding (bmRequestType
--                                       [6:5]=01 Class, [4:0]=00001 Interface,
--                                       bRequest=OCP_RECOVERY_TRANSFER 00h,
--                                       wIndex[7:0]=REC_IFACE_NUM).
--  - USB 2.0 Section 5.5             -- Control transfer model.
--  - USB 2.0 Section 8.4.6.4         -- A function must ACK a SETUP; it may
--                                       not NAK or STALL the SETUP stage.
--  - USB 2.0 Section 8.5.3           -- Control transfer SETUP/DATA/STATUS
--                                       phasing and abandon-on-new-SETUP rule.
--  - USB 2.0 Section 9.3 Table 9-2   -- SETUP packet byte layout (little
--                                       endian on the wire).
--
--  Bring-up mode generic
--  ---------------------
--  G_BRINGUP_MODE selects how much of the datapath is active.  It exists ONLY
--  to stage functional bring-up along a single structural path (there is no
--  second compile path or second instance).  Modes are strictly additive:
--    MODE_A (0) : transparent pass-through (no trap).  Every legacy-visible
--                 output is a bit-for-bit copy of usb_dma's response and every
--                 synchronized input reaches usb_dma / usb_reg_if unmodified.
--    MODE_B (1) : trap every EP0 SETUP, fabricate the SETUP response, replay
--                 ALL SETUPs to the legacy path as unclaimed.
--    MODE_C (2) : additionally classify SETUPs (still force no claim).
--    MODE_D (3) : additionally enable the claimed OCP path (SETUP discard +
--                 routing to the SV recovery stack).
--    MODE_E (4) : additionally enable the full OCP transfer engine (TX
--                 cut-through, exact-MaxPacket ZLP, DATA toggle, STALL,
--                 early-IN NAK/retry, OUT elastic drain).  Default and shipped
--                 behaviour.
--  The generic is a bring-up scaffold and is removed at milestone completion;
--  the shipped RTL has no mode selection and always implements MODE_E.
--
--  Coding conventions
--  ------------------
--  - library IEEE; numeric_std; no std_logic_unsigned / std_logic_arith.
--  - _r suffix on registered signals, _nxt on next-state, _c on combinational.
--  - Asynchronous active-low reset (hresetn).
--  ----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity usb_ocp_recovery_post_sync_arb is
  generic (
    USB_DATAWIDTH    : integer := 64;
    -- Synchronized RX byte-count width (usb_dma sync_sieint_rx_nbytes port).
    RXNBYTES_BITS    : integer := 12;
    -- Synchronized TX byte-count width (usb_dma epinfo_sync_nbytes port).
    TXNBYTES_BITS    : integer := 15;
    -- USB Interface Number selecting the recovery interface for class-specific
    -- SETUPs (OCP Recovery v1.1 Sec 8.5; USB 2.0 Sec 9.3 Tbl 9-2 wIndex).
    C_REC_IFACE_NUM  : integer range 0 to 255 := 0;
    -- Bring-up staging mode (see header).  The default tracks the highest mode
    -- currently implemented and advances as later milestones add modes; each
    -- structural instantiation selects its mode explicitly.  At milestone
    -- completion (A1.10) the generic is removed and the datapath is
    -- unconditionally full-function (MODE_E).
    G_BRINGUP_MODE   : integer range 0 to 4 := 0
  );
  port (
    -- ------------------------------------------------------------------
    -- Clock / async active-low reset (hclk == dev_axi_aclk domain).
    -- ------------------------------------------------------------------
    hclk     : in  std_logic;
    hresetn  : in  std_logic;

    -- Bus-reset (synchronized into hclk by usb_synchronizer).  Clears all
    -- trap/claim state (USB 2.0 Sec 9.1 reset returns EP0 to Default state).
    sync_busreset : in std_logic;

    -- ==================================================================
    -- Upper side: synchronized SIE interface from usb_synchronizer.
    -- These are the signals usb_dma / usb_reg_if consume today; the arbiter
    -- interposes on them.  Suffix _i marks the synchronizer-sourced copy.
    -- ==================================================================
    -- Request/SETUP framing toward usb_dma.
    sync_sieint_epinfo_req_i    : in  std_logic;
    sync_sieint_epinfo_epnr_i   : in  std_logic_vector(3 downto 0);
    sync_sieint_epinfo_epdir_i  : in  std_logic;
    sync_sieint_epinfo_setup_i  : in  std_logic;
    -- Single-pulse SETUP-received toward usb_reg_if.
    sync_sieint_setup_received_i: in  std_logic;
    -- RX data phase (post-ACK) toward usb_dma.
    sync_sieint_rx_nbytes_i     : in  std_logic_vector(RXNBYTES_BITS-1 downto 0);
    sync_sieint_rxdata_i        : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
    sync_sieint_rxdatavalid_i   : in  std_logic;
    -- Completion / status toward usb_dma and usb_reg_if.
    sync_sieint_endtransfer_i   : in  std_logic;
    sync_sieint_success_i       : in  std_logic;
    sync_sieint_error_i         : in  std_logic;
    sync_sieint_errortype_i     : in  std_logic_vector(3 downto 0);
    sync_sieint_sentNAK_i       : in  std_logic;
    -- TX fetch strobe toward usb_dma.
    sync_sieint_txdatafetched_i : in  std_logic;

    -- Response bundle returned by usb_dma (epinfo_sync_*), to be muxed by the
    -- arbiter before it returns through usb_synchronizer.  Suffix _dma.
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

    -- ==================================================================
    -- Lower side toward usb_dma: gated/replayed synchronized SIE interface.
    -- Suffix _o marks the arbiter-driven copy delivered to usb_dma.
    -- ==================================================================
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

    -- Toward usb_reg_if: gated SETUP-received and error path.
    sync_sieint_setup_received_o: out std_logic;
    sync_sieint_error_o         : out std_logic;
    sync_sieint_errortype_o     : out std_logic_vector(3 downto 0);

    -- Muxed response bundle returned toward usb_synchronizer (epinfo_sync_*).
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

    -- ==================================================================
    -- Upper side: 32-bit control-transfer surface to the SV recovery stack.
    -- setup_pkt_vld is pre-filtered: only OCP-recovery class SETUPs reach the
    -- SV side, so ctrl_decode treats every SETUP pulse as a recovery request.
    -- This interface matches the legacy usb_pie_recovery_arb SV boundary so
    -- usb_ocp_recovery_top needs no interface change.
    -- ==================================================================
    setup_pkt_vld   : out std_logic;
    setup_pkt       : out std_logic_vector(63 downto 0);

    ctrl_out_data   : out std_logic_vector(31 downto 0);
    ctrl_out_be     : out std_logic_vector(3 downto 0);
    ctrl_out_vld    : out std_logic;
    ctrl_out_last   : out std_logic;
    ctrl_out_rdy    : in  std_logic;

    ctrl_in_data    : in  std_logic_vector(31 downto 0);
    ctrl_in_be      : in  std_logic_vector(3 downto 0);
    ctrl_in_vld     : in  std_logic;
    ctrl_in_last    : in  std_logic;
    ctrl_in_rdy     : out std_logic;
    -- Exact implementation response byte count for the current claimed IN
    -- transfer, clipped to wLength (USB 2.0 Sec 8.5.3 short-packet rules).
    ctrl_in_resp_bytes : in  std_logic_vector(6 downto 0);
    ctrl_in_resp_known : in  std_logic;

    -- STALL request from the SV recovery stack (OCP Recovery v1.1 Sec 8.5:
    -- malformed class requests SHALL be STALLed).
    ctrl_set_stall  : in  std_logic;

    -- End-of-stage pulse to SV for the DATA and STATUS stages of a claimed
    -- transfer (the SETUP-stage completion is consumed internally).
    ctrl_xfer_done  : out std_logic;

    -- Emergency-fallback firmware chicken bit (DEVICE_RESET.OCP_PATH_DISABLE).
    -- When '1', the OCP class match is forced false so no recovery-class SETUP
    -- is claimed and every EP0 transfer falls through to the legacy path.
    ocp_path_disable_i : in  std_logic;

    -- Claim status (visibility only): '1' while the arbiter owns an OCP
    -- recovery class transfer (SETUP / DATA / STATUS).
    rec_claim_status : out std_logic
  );
end entity usb_ocp_recovery_post_sync_arb;
