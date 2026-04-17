--  ----------------------------------------------------------------------------
--               File: usb_ocp_recovery_ep_adapter.m.vhdl
--            Project: ip_xxx_3516_hs_mem - OCP Secure Firmware Recovery v1.1
--        Description: Architecture RTL for the EPCS/DMA <-> byte-stream
--                     adapter.  Pure bridging logic:
--
--                       lower (PIE/EPCS)          upper (vld/rdy/last)
--                       --------------------      --------------------
--                       setup_received pulse  ->  setup_pkt_vld pulse
--                       setup_data (latched)  ->  setup_pkt
--                       ep*_req/byte/last/ack <-> *_vld / *_data /
--                                                 *_last / *_rdy
--                       set_stall (pulse)     ->  ep*_stall level
--                                                 (cleared on xfer_done)
--
--                     Handshake rules (upper side, LOCKED):
--                       - vld is asserted by producer until (vld and rdy)
--                       - last marks the last byte of a transfer
--                       - no assignments are made on a given cycle unless
--                         (vld and rdy) completes a beat
--
--                     Back-pressure:
--                       - when a consumer holds *_rdy low, the matching
--                         lower-side ack (pie_*_ack) stays low and the
--                         lower-side nak (pie_*_nak) asserts so usb_pie
--                         replies NAK on that OUT packet (Sec 8.5.4).
--                       - IN streams simply stall (pie_*_req low) until
--                         the producer presents vld.
--
--                     Stall handling:
--                       - set_stall captured into a latch; cleared on
--                         xfer_done (mirrors usb_ocp_ep0.ST_STALL handling).
--
--                     uArch notes:
--                       - All flow-through signals are purely combinational
--                         to minimize latency and area (no FIFO here).
--                       - Only two FFs per EP are introduced: the STALL
--                         latch and the setup-valid 1-cycle pulse register.
--                       - SETUP data is assumed already latched on the
--                         lower side by usb_pie; we simply forward it.
--                       - Generic endpoint numbers (C_CTRL_EP_NR etc.) are
--                         not consumed inside this adapter - they are a
--                         documentation contract for the top-level splice
--                         agent A7 that wires the matching usb_pie EP slot
--                         to these lower-side ports.
--  ----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

architecture rtl of usb_ocp_recovery_ep_adapter is

  ---------------------------------------------------------------------------
  -- Stall latches (one per stallable EP group: control + bulk)
  ---------------------------------------------------------------------------
  signal ctrl_stall_r  : std_logic;
  signal bulk_stall_r  : std_logic;

  ---------------------------------------------------------------------------
  -- SETUP pulse register: re-emit the usb_pie setup-received pulse at the
  -- adapter's upper port edge.  pie_setup_data is already stable on the
  -- lower side per usb_pie convention, but we capture it once to isolate
  -- the consumer from any PIE-internal timing changes.
  ---------------------------------------------------------------------------
  signal setup_vld_r   : std_logic;
  signal setup_data_r  : std_logic_vector(63 downto 0);

begin

  ---------------------------------------------------------------------------
  -- Parameter sanity
  ---------------------------------------------------------------------------
  assert C_CTRL_EP_NR < 16
    report "C_CTRL_EP_NR must fit in 4 bits" severity failure;
  assert C_BULK_OUT_EP_NR < 16
    report "C_BULK_OUT_EP_NR must fit in 4 bits" severity failure;
  assert C_BULK_IN_EP_NR < 16
    report "C_BULK_IN_EP_NR must fit in 4 bits" severity failure;

  ---------------------------------------------------------------------------
  -- SETUP capture / re-emission
  ---------------------------------------------------------------------------
  setup_capture_clk_proc : process (clk, reset_n)
  begin
    if reset_n = '0' then
      setup_vld_r  <= '0';
      setup_data_r <= (others => '0');
    elsif rising_edge(clk) then
      -- Default: single-cycle pulse.
      setup_vld_r <= '0';
      if pie_setup_received = '1' then
        setup_vld_r  <= '1';
        setup_data_r <= pie_setup_data;
      end if;
    end if;
  end process setup_capture_clk_proc;

  setup_pkt_vld <= setup_vld_r;
  setup_pkt     <= setup_data_r;

  ---------------------------------------------------------------------------
  -- Stall latches
  -- set_stall is a 1-cycle pulse from the upper layer; the PIE expects a
  -- level-held stall request until the transfer completes (xfer_done).
  ---------------------------------------------------------------------------
  stall_latch_clk_proc : process (clk, reset_n)
  begin
    if reset_n = '0' then
      ctrl_stall_r <= '0';
      bulk_stall_r <= '0';
    elsif rising_edge(clk) then
      -- Control EP stall latch
      if ctrl_set_stall = '1' then
        ctrl_stall_r <= '1';
      elsif pie_ctrl_xfer_done = '1' then
        ctrl_stall_r <= '0';
      end if;

      -- Bulk EP stall latch (CLEAR_FEATURE(ENDPOINT_HALT) is handled at
      -- the PIE level; xfer_done is only used to self-clear a one-shot).
      if bulk_set_stall = '1' then
        bulk_stall_r <= '1';
      elsif pie_bulk_xfer_done = '1' then
        bulk_stall_r <= '0';
      end if;
    end if;
  end process stall_latch_clk_proc;

  pie_ctrl_stall <= ctrl_stall_r;
  pie_bulk_stall <= bulk_stall_r;

  ---------------------------------------------------------------------------
  -- Control OUT: PIE request -> upper vld/rdy/last
  --   vld is driven directly by PIE req; the upper sink back-pressures
  --   with rdy; ack back to PIE only fires when (vld and rdy); nak
  --   drives the PIE EPCS to reply NAK when sink not ready.
  ---------------------------------------------------------------------------
  ctrl_out_data     <= pie_ctrl_out_byte;
  ctrl_out_vld      <= pie_ctrl_out_req;
  ctrl_out_last     <= pie_ctrl_out_last;
  pie_ctrl_out_ack  <= pie_ctrl_out_req and ctrl_out_rdy;
  pie_ctrl_out_nak  <= pie_ctrl_out_req and (not ctrl_out_rdy);

  ---------------------------------------------------------------------------
  -- Control IN: upper producer drives vld; PIE consumes on ack
  ---------------------------------------------------------------------------
  pie_ctrl_in_req   <= ctrl_in_vld;
  pie_ctrl_in_byte  <= ctrl_in_data;
  pie_ctrl_in_last  <= ctrl_in_last;
  ctrl_in_rdy       <= pie_ctrl_in_ack;

  ctrl_xfer_done    <= pie_ctrl_xfer_done;

  ---------------------------------------------------------------------------
  -- Bulk OUT / IN (mirrors control shape)
  ---------------------------------------------------------------------------
  bout_data         <= pie_bout_byte;
  bout_vld          <= pie_bout_req;
  bout_last         <= pie_bout_last;
  pie_bout_ack      <= pie_bout_req and bout_rdy;
  pie_bout_nak      <= pie_bout_req and (not bout_rdy);

  pie_bin_req       <= bin_vld;
  pie_bin_byte      <= bin_data;
  pie_bin_last      <= bin_last;
  bin_rdy           <= pie_bin_ack;

  bulk_xfer_done    <= pie_bulk_xfer_done;

end architecture rtl;
