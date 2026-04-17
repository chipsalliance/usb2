--  ----------------------------------------------------------------------------
--               File: usb_ocp_recovery_ep_adapter.e.vhdl
--            Project: ip_xxx_3516_hs_mem - OCP Secure Firmware Recovery v1.1
--               Role: Entity declaration for the EPCS/DMA <-> byte-stream
--                     adapter that bridges the USB device PIE surface
--                     (usb_pie + usb_dma request/grant, setup-received,
--                     endtransfer / success / errortype) to the simple
--                     vld/rdy/last byte streams consumed by the
--                     SystemVerilog OCP Recovery stack (ctrl_decode, regs,
--                     fifo, fsm).
--
--  Spec references:
--    - OCP Recovery v1.1 Sec 8.5 (USB transport):
--        * EP0 class-specific control requests
--        * one bulk OUT (INDIRECT_FIFO_DATA image push)
--        * one bulk IN  (INDIRECT_FIFO_DATA/other IN reads)
--    - USB 2.0 Ch 8 / Ch 9 (protocol + device framework) for SETUP packet
--      framing (8-byte payload) and EP stall/clear-halt handling.
--
--  Coding conventions: library IEEE; numeric_std; _r / _nxt registered
--  vs next; two-process FSMs; defaults at top of comb processes; async
--  active-low reset (project VHDL convention).
--  ----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity usb_ocp_recovery_ep_adapter is
  generic (
    -- Endpoint numbering (see master plan A1 contract).
    C_CTRL_EP_NR     : natural := 0;   -- EP0 control
    C_BULK_OUT_EP_NR : natural := 1;   -- bulk OUT for INDIRECT_FIFO_DATA
    C_BULK_IN_EP_NR  : natural := 1    -- bulk IN  for read-back
  );
  port (
    ------------------------------------------------------------------
    -- Clock / Reset (UTMI/PIE clock domain, async active-low reset)
    ------------------------------------------------------------------
    clk                    : in  std_logic;
    reset_n                : in  std_logic;

    ------------------------------------------------------------------
    -- Lower side: connection to usb_pie / usb_dma EPCS surface
    --
    -- Signal source/sink in the existing IP (see reuse inventory in
    -- Interface Report A1):
    --   * pie_epinfo_setup_received   - usb_pie.m.vhdl, SETUP token ack
    --   * pie_rxdata / pie_rxdatavalid - usb_pie, received OUT payload
    --   * pie_rx_nbytes               - usb_pie, OUT byte count
    --   * epinfo_txdata / _valid /
    --     pie_txdata_fetched          - usb_pie IN data-phase handshake
    --   * pie_endtransfer / pie_success / pie_errortype - usb_pie
    --     end-of-transaction pulses (used here as xfer_done / stall clear)
    --   * epinfo_stall (usb_dma)      - drives EP STALL state
    --
    -- The adapter exposes one setup-valid pulse plus per-endpoint byte
    -- streams (ep*_req / _byte / _last / _ack) to the outside world so
    -- the top-level glue (A7) can splice them into the matching usb_pie
    -- slots without needing to replicate the EPCS bookkeeping here.
    ------------------------------------------------------------------

    -- SETUP packet capture (EP0 data phase seed).
    pie_setup_received     : in  std_logic;                       -- 1-cycle pulse
    pie_setup_data         : in  std_logic_vector(63 downto 0);   -- 8-byte SETUP

    -- Control-EP byte streams (to/from usb_pie EP0 data phase).
    pie_ctrl_out_req       : in  std_logic;
    pie_ctrl_out_byte      : in  std_logic_vector(7 downto 0);
    pie_ctrl_out_last      : in  std_logic;
    pie_ctrl_out_ack       : out std_logic;
    pie_ctrl_out_nak       : out std_logic;   -- raise when sink not ready

    pie_ctrl_in_req        : out std_logic;
    pie_ctrl_in_byte       : out std_logic_vector(7 downto 0);
    pie_ctrl_in_last       : out std_logic;
    pie_ctrl_in_ack        : in  std_logic;

    pie_ctrl_stall         : out std_logic;   -- level: force STALL on EP0
    pie_ctrl_xfer_done     : in  std_logic;   -- pie_endtransfer for EP0

    -- Bulk-OUT byte stream (INDIRECT_FIFO_DATA image push).
    pie_bout_req           : in  std_logic;
    pie_bout_byte          : in  std_logic_vector(7 downto 0);
    pie_bout_last          : in  std_logic;
    pie_bout_ack           : out std_logic;
    pie_bout_nak           : out std_logic;

    -- Bulk-IN byte stream.
    pie_bin_req            : out std_logic;
    pie_bin_byte           : out std_logic_vector(7 downto 0);
    pie_bin_last           : out std_logic;
    pie_bin_ack            : in  std_logic;

    pie_bulk_stall         : out std_logic;   -- level: force STALL on bulk EPs
    pie_bulk_xfer_done     : in  std_logic;   -- pie_endtransfer for bulk EPs

    ------------------------------------------------------------------
    -- Upper side: simple vld/rdy/last byte streams to the SV stack
    -- (A2 ctrl_decode, A4 fifo, A6 top).  LOCKED contract.
    ------------------------------------------------------------------

    -- SETUP packet to ctrl_decode: 1-cycle valid pulse with 8 bytes.
    setup_pkt_vld          : out std_logic;
    setup_pkt              : out std_logic_vector(63 downto 0);

    -- Control-OUT byte stream (data phase of an EP0 class request).
    ctrl_out_data          : out std_logic_vector(7 downto 0);
    ctrl_out_vld           : out std_logic;
    ctrl_out_last          : out std_logic;
    ctrl_out_rdy           : in  std_logic;

    -- Control-IN byte stream (data phase response from ctrl_decode).
    ctrl_in_data           : in  std_logic_vector(7 downto 0);
    ctrl_in_vld            : in  std_logic;
    ctrl_in_last           : in  std_logic;
    ctrl_in_rdy            : out std_logic;

    -- STALL pulse in, xfer-done pulse out (status-stage completion).
    ctrl_set_stall         : in  std_logic;
    ctrl_xfer_done         : out std_logic;

    -- Bulk-OUT byte stream (INDIRECT_FIFO_DATA image push to A4).
    bout_data              : out std_logic_vector(7 downto 0);
    bout_vld               : out std_logic;
    bout_last              : out std_logic;
    bout_rdy               : in  std_logic;

    -- Bulk-IN byte stream.
    bin_data               : in  std_logic_vector(7 downto 0);
    bin_vld                : in  std_logic;
    bin_last               : in  std_logic;
    bin_rdy                : out std_logic;

    bulk_set_stall         : in  std_logic;
    bulk_xfer_done         : out std_logic
  );
end entity usb_ocp_recovery_ep_adapter;
