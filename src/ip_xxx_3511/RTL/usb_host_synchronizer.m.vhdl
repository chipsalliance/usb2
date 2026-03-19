--  ----------------------------------------------------------------------------
--                     Copyright Message
--  ----------------------------------------------------------------------------
--
--   NXP B.V. confidential and proprietary.
--   COPYRIGHT (c) NXP B.V. 2012
--
--   All rights are reserved. Reproduction in whole or in part is
--   prohibited without the written consent of the copywright owner
--
--   CoReUse 4.4 information header
--
--  ----------------------------------------------------------------------------
--                     Design Information
--  ----------------------------------------------------------------------------
--
--               File: usb_host_synchronizer.m.vhdl
--
--             Author: Bart Vertenten
--
--       Organisation: CentralR&D / Design Services / MSS
--
--              $Date: Tue May 28 15:20:43 2019 $
--
--            Project: IP_3515 - Low gate count USB host IP
--
--        Description:
--
--          $Revision: 1.4 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_host_synchronizer.m.vhdl.rca $
--   
--    Revision: 1.4 Tue May 28 15:20:43 2019 usb00219
--    Fix for artf663122: CDC crossing causing pie_resume_done pulse to be lost Route ahb-synchronized version of usbreg_portl1l2suspend to the usb_host_pie for use in  the pie_resume_done handshake.
--    
--   
--    Revision: 1.14 Thu Dec 13 11:39:31 2012 beq03196
--    add USB_OTG register for the ip_3516_hs
--
--    Revision: 1.13 Thu Apr 12 14:02:05 2012 beq03099
--    Finished LPM implementation
--
--    Revision: 1.12 Tue Mar 13 13:45:34 2012 beq03099
--    fix for PR#10 - full-speed interrupt must be sent immediate after SOF
--
--    Revision: 1.11 Mon Mar 12 09:52:39 2012 beq03196
--    width of test mode bus can be reduced to 3 bits
--
--    Revision: 1.10 Mon Mar 12 09:27:13 2012 beq03099
--    fixed problem with pie_devicespeed_sync signal
--
--    Revision: 1.9 Fri Mar  9 14:30:17 2012 beq03099
--    added signal usb_decrement_bytes
--
--    Revision: 1.8 Fri Mar  9 11:45:07 2012 beq03099
--    added pie_devicespeed to synchronizer
--
--    Revision: 1.7 Wed Mar  7 15:37:47 2012 beq03099
--    Rework after module review :
--    - added usbreg_reset and usbreg_light_reset logic
--
--    Revision: 1.6 Fri Feb 17 12:33:03 2012 beq03099
--    added/removed interface signals
--
--    Revision: 1.5 Fri Feb  3 13:57:13 2012 beq03099
--    fixed sof generation issue
--
--    Revision: 1.4 Wed Feb  1 13:15:28 2012 beq03099
--    fixed synplify warnings
--
--    Revision: 1.3 Tue Jan 31 08:13:39 2012 beq03099
--    added usbreg_portenable_set and usbreg_portenable_clear
--
--    Revision: 1.2 Fri Jan 27 12:10:51 2012 beq03099
--    added following input ports epinfo_maxpacket and epinfo_mult
--
--    Revision: 1.1 Wed Jan 18 08:58:36 2012 beq03099
--    initial version
--
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- This block contains all the signals that go between the usb clock domain and
-- the AHB clock domain. The following paths can be set as false paths
--
--  usbreg_fladj_change_s         <= usbreg_fladj_change;
--  usbreg_run_s                  <= usbreg_run;
--  usbreg_portresume_s           <= usbreg_portresume;
--  usbreg_portreset_s            <= usbreg_portreset;
--  usbreg_portsuspend_s          <= usbreg_portsuspend;
--  usbreg_portl1l2suspend_s          <= usbreg_portl1l2suspend;
--  usbreg_portpower_s            <= usbreg_portpower;
--  epinfo_starttransfer_s        <= epinfo_starttransfer;
--  epinfo_txdata_valid_s         <= epinfo_txdata_valid;
--  phy_start_s                   <= usbreg_phy_start;
--  usbreg_portenable_clear_s     <= usbreg_portenable_clear;
--  usbreg_reset_s	          <= usbreg_reset;
--  usbreg_light_reset_s          <= usbreg_light_reset;
--  usbreg_phy_test_mode_toggle_s <= usbreg_phy_test_mode_toggle;
--  usb_overcurrent_n_s           <= usb_overcurrent_n;
--  usb_inc_frindex_toggle_s      <= usb_inc_frindex_toggle;
--  pie_portconnect_s             <= pie_portconnect;
--  pie_portenable_s              <= pie_portenable;
--  pie_resume_detected_s         <= pie_resume_detected;
--  pie_resume_done_s             <= pie_resume_done;
--  pie_linestate_s               <= pie_linestate;
--  pie_txdatafetched_s	          <= pie_txdatafetched;
--  pie_rxdatavalid_s      	  <= pie_rxdatavalid;
--  pie_endtransfer_toggle_s 	  <= pie_endtransfer_toggle;
--  phy_endtoggle_s               <= pie_phy_endtoggle;
--  sync_reset_done_s             <= usbreg_reset_ss or usbreg_light_reset_ss;
--  usbreg_phy_test_mode_s        <= usbreg_phy_test_mode;
--  usbreg_fladj_sync             <= usbreg_fladj;
--  pie_rx_nbytes_sync            <= pie_rx_nbytes;
--  pie_rxdata_sync               <= pie_rxdata;
--  pie_response_sync             <= pie_response;
--  epinfo_token_sync		  <= epinfo_token;
--  epinfo_devaddr_sync		  <= epinfo_devaddr;
--  epinfo_epnr_sync		  <= epinfo_epnr;
--  epinfo_toggle_sync		  <= epinfo_toggle;
--  epinfo_eptype_sync		  <= epinfo_eptype;
--  epinfo_mult_sync              <= epinfo_mult;
--  epinfo_maxpacket_sync         <= epinfo_maxpacket;
--  epinfo_nbytes_sync		  <= epinfo_nbytes;
--  epinfo_lowspeed_sync	  <= epinfo_lowspeed;
--  epinfo_sofnr_sync		  <= epinfo_sofnr;
--  epinfo_subpid_sync		  <= epinfo_subpid;
--  epinfo_lpm_linkstate_sync	  <= epinfo_lpm_linkstate;
--  epinfo_lpm_hird_sync	  <= epinfo_lpm_hird;
--  epinfo_lpm_bremotewakeup_sync <= epinfo_lpm_bremotewakeup;
--  epinfo_split_hubaddr_sync	  <= epinfo_split_hubaddr;
--  epinfo_split_port_sync	  <= epinfo_split_port;
--  epinfo_split_se_sync	  <= epinfo_split_se;
--  epinfo_txdata_sync		  <= epinfo_txdata;
--  usbreg_phy_addr_sync          <= usbreg_phy_addr;
--  usbreg_phy_wdata_sync	  <= usbreg_phy_wdata;
--  pie_phy_rdata_sync            <= pie_phy_rdata;
--  usbreg_phy_write_sync	  <= usbreg_phy_write;
--  usbreg_phy_mode_sync	  <= usbreg_phy_mode;
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;

entity usb_host_synchronizer is
  generic(
            C_ULPI_SUPPORT      : boolean := FALSE;
            C_UTMI_SUPPORT      : boolean := TRUE;
            USB_DATAWIDTH       : integer := 8;
            C_PORTPOWER_CONTROL : boolean := TRUE);
  port (
        --To/from external
        usb_clk                  : in  std_logic;
        usb_rst_n                : in  std_logic;
        hclk                     : in  std_logic;
        hrstn                    : in  std_logic;
        usb_overcurrent_n        : in  std_logic;
        id_value                 : in  std_logic;
        --To/from USB_HOST_REG_IF
        usbreg_fladj             : in  std_logic_vector(5 downto 0);
        usbreg_fladj_change      : in  std_logic;
        usbreg_run               : in  std_logic;
        usbreg_reset             : in  std_logic;
        usbreg_light_reset       : in  std_logic;
        usbreg_portresume        : in  std_logic;
        usbreg_portreset         : in  std_logic;
        usbreg_portsuspend       : in  std_logic;
        usbreg_portl1l2suspend   : in  std_logic;
        usbreg_portpower         : in  std_logic;
        usbreg_portenable_clear  : in  std_logic;
        usbreg_phy_addr          : in  std_logic_vector(7 downto 0);
        usbreg_phy_wdata         : in  std_logic_vector(7 downto 0);
        usbreg_phy_write         : in  std_logic;
        usbreg_phy_start         : in  std_logic;
        usbreg_phy_mode          : in  std_logic;
        usb_inc_frindex_toggle_sync: out std_logic;
        usbreg_phy_test_mode     : in  std_logic_vector(2 downto 0);
        pie_portconnect_sync     : out std_logic;
        pie_portenable_sync      : out std_logic;
        usb_overcurrent_sync     : out std_logic;
        pie_resume_detected_sync : out std_logic;
        pie_resume_done_sync     : out std_logic;
        pie_linestate_sync       : out std_logic_vector(1 downto 0);
        pie_phy_rdata_sync       : out std_logic_vector(7 downto 0);
        pie_phy_endtoggle_sync   : out std_logic;
        pie_devicespeed_sync     : out std_logic_vector(1 downto 0);
        id_value_sync            : out std_logic;
        --To/from USB_HOST_DMA
        pie_txdatafetched_sync   : out std_logic;
        pie_rx_nbytes_sync       : out std_logic_vector(11 downto 0);
        pie_rxdata_sync          : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
        pie_rxdatavalid_sync     : out std_logic;
        pie_endtransfer_sync     : out std_logic;
        pie_response_sync        : out std_logic_vector(2 downto 0);
        usb_decrement_bytes_sync : out std_logic;
        epinfo_starttransfer     : in  std_logic;
        epinfo_token             : in  std_logic_vector(2 downto 0);
        epinfo_devaddr           : in  std_logic_vector(6 downto 0);
        epinfo_epnr              : in  std_logic_vector(3 downto 0);
        epinfo_toggle            : in  std_logic;
        epinfo_eptype            : in  std_logic_vector(1 downto 0);
        epinfo_mult              : in  std_logic_vector(1 downto 0);
        epinfo_maxpacket         : in  std_logic_vector(10 downto 0);
        epinfo_nbytes            : in  std_logic_vector(11 downto 0);
        epinfo_lowspeed          : in  std_logic;
        epinfo_sofnr             : in  std_logic_vector(10 downto 0);
        epinfo_subpid            : in  std_logic_vector(1 downto 0);
        epinfo_lpm_linkstate     : in  std_logic_vector(3 downto 0);
        epinfo_lpm_hird          : in  std_logic_vector(3 downto 0);
        epinfo_lpm_bremotewakeup : in  std_logic;
        epinfo_split_hubaddr     : in  std_logic_vector(6 downto 0);
        epinfo_split_port        : in  std_logic_vector(6 downto 0);
        epinfo_split_se          : in  std_logic_vector(1 downto 0);
        epinfo_txdata            : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
        epinfo_txdata_valid      : in  std_logic;
        --To/from USB_HOST_PIE
        pie_txdatafetched        : in  std_logic;
        pie_rx_nbytes            : in  std_logic_vector(11 downto 0);
        pie_rxdata               : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
        pie_rxdatavalid          : in  std_logic;
        pie_endtransfer          : in  std_logic;
        pie_response             : in  std_logic_vector(2 downto 0);
        pie_phy_rdata            : in  std_logic_vector(7 downto 0);
        pie_phy_endtoggle        : in  std_logic;
        pie_resume_detected      : in  std_logic;
        pie_resume_done          : in  std_logic;
        pie_portconnect          : in  std_logic;
        pie_portenable           : in  std_logic;
        pie_linestate            : in  std_logic_vector(1 downto 0);
        pie_devicespeed          : in  std_logic_vector(1 downto 0);
        epinfo_starttransfer_sync: out std_logic;
        epinfo_token_sync        : out std_logic_vector(2 downto 0);
        epinfo_devaddr_sync      : out std_logic_vector(6 downto 0);
        epinfo_epnr_sync         : out std_logic_vector(3 downto 0);
        epinfo_toggle_sync       : out std_logic;
        epinfo_eptype_sync       : out std_logic_vector(1 downto 0);
        epinfo_mult_sync         : out std_logic_vector(1 downto 0);
        epinfo_maxpacket_sync    : out std_logic_vector(10 downto 0);
        epinfo_nbytes_sync       : out std_logic_vector(11 downto 0);
        epinfo_lowspeed_sync     : out std_logic;
        epinfo_sofnr_sync        : out std_logic_vector(10 downto 0);
        epinfo_subpid_sync       : out std_logic_vector(1 downto 0);
        epinfo_lpm_linkstate_sync: out std_logic_vector(3 downto 0);
        epinfo_lpm_hird_sync     : out std_logic_vector(3 downto 0);
        epinfo_lpm_bremotewakeup_sync : out std_logic;
        epinfo_split_hubaddr_sync: out std_logic_vector(6 downto 0);
        epinfo_split_port_sync   : out std_logic_vector(6 downto 0);
        epinfo_split_se_sync     : out std_logic_vector(1 downto 0);
        epinfo_txdata_sync       : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
        epinfo_txdata_valid_sync : out std_logic;
        usbreg_phy_addr_sync     : out std_logic_vector(7 downto 0);
        usbreg_phy_wdata_sync    : out std_logic_vector(7 downto 0);
        usbreg_phy_write_sync    : out std_logic;
        usbreg_phy_start_sync    : out std_logic;
        usbreg_phy_mode_sync     : out std_logic;
        usbreg_reset_sync        : out std_logic;
        usbreg_light_reset_sync  : out std_logic;
        sync_reset_done          : out std_logic;
        usbreg_portpower_sync    : out std_logic;
        usbreg_portreset_sync    : out std_logic;
        usbreg_portsuspend_sync  : out std_logic;
        usbreg_portl1l2suspend_sync : out std_logic;
        usbreg_portresume_sync   : out std_logic;
        usbreg_portenable_clear_sync : out std_logic;
        usbreg_phy_test_mode_change_sync : out std_logic;
        usb_uframe_count_sync    : out std_logic_vector(2 downto 0);
        --To/from USB_HOST_SOF_TIMER
        usb_inc_frindex_toggle   : in  std_logic;
        usb_decrement_bytes      : in  std_logic;
        usb_uframe_count         : in  std_logic_vector(2 downto 0);
        usbreg_run_sync          : out std_logic;
        usbreg_fladj_sync        : out std_logic_vector(5 downto 0);
        usbreg_fladj_change_sync : out std_logic
	);
end usb_host_synchronizer;

architecture RTL of usb_host_synchronizer is

signal usbreg_fladj_change_s	 : std_logic;
signal usbreg_fladj_change_ss	 : std_logic;
signal usbreg_fladj_change_sss	 : std_logic;
signal usbreg_run_s		 : std_logic;
signal usbreg_run_ss		 : std_logic;
signal usbreg_portresume_s	 : std_logic;
signal usbreg_portresume_ss	 : std_logic;
signal usbreg_portreset_s	 : std_logic;
signal usbreg_portreset_ss	 : std_logic;
signal usbreg_portsuspend_s	 : std_logic;
signal usbreg_portsuspend_ss	 : std_logic;
signal usbreg_portl1l2suspend_s	 : std_logic;
signal usbreg_portl1l2suspend_ss : std_logic;
signal usbreg_portpower_s	 : std_logic;
signal usbreg_portpower_ss	 : std_logic;
signal epinfo_starttransfer_s	 : std_logic;
signal epinfo_starttransfer_ss   : std_logic;
signal epinfo_starttransfer_sss  : std_logic;
signal epinfo_txdata_valid_s	 : std_logic;
signal epinfo_txdata_valid_ss	 : std_logic;
signal phy_start_s 	 : std_logic;
signal phy_start_ss	 : std_logic;
signal phy_start_sss	 : std_logic;
signal pie_endtransfer_toggle	 : std_logic;
signal usb_overcurrent_n_s	 : std_logic;
signal usb_overcurrent_n_ss	 : std_logic;
signal usb_inc_frindex_toggle_s  : std_logic;
signal usb_inc_frindex_toggle_ss : std_logic;
signal usb_inc_frindex_toggle_sss: std_logic;
signal pie_portconnect_s	 : std_logic;
signal pie_portconnect_ss	 : std_logic;
signal pie_portenable_s 	 : std_logic;
signal pie_portenable_ss	 : std_logic;
signal pie_resume_detected_s	 : std_logic;
signal pie_resume_detected_ss	 : std_logic;
signal pie_resume_done_s	 : std_logic;
signal pie_resume_done_ss	 : std_logic;
signal pie_linestate_s  	 : std_logic_vector(1 downto 0);
signal pie_linestate_ss 	 : std_logic_vector(1 downto 0);
signal pie_txdatafetched_s	 : std_logic;
signal pie_txdatafetched_ss	 : std_logic;
signal pie_txdatafetched_sss	 : std_logic;
signal pie_rxdatavalid_s	 : std_logic;
signal pie_rxdatavalid_ss	 : std_logic;
signal pie_rxdatavalid_sss	 : std_logic;
signal pie_endtransfer_toggle_s  : std_logic;
signal pie_endtransfer_toggle_ss : std_logic;
signal pie_endtransfer_toggle_sss: std_logic;
signal phy_endtoggle_s	 : std_logic;
signal phy_endtoggle_ss	 : std_logic;
signal phy_endtoggle_sss	 : std_logic;
signal usbreg_portenable_clear_s   : std_logic;
signal usbreg_portenable_clear_ss  : std_logic;
signal usbreg_portenable_clear_sss : std_logic;
signal usbreg_reset_s	         : std_logic;
signal usbreg_reset_ss	         : std_logic;
signal usbreg_light_reset_s      : std_logic;
signal usbreg_light_reset_ss     : std_logic;
signal sync_reset_done_s	 : std_logic;
signal sync_reset_done_ss	 : std_logic;
signal sync_reset_done_sss  	 : std_logic;
signal usbreg_phy_test_mode_s    : std_logic_vector(2 downto 0);
signal usbreg_phy_test_mode_toggle_s   : std_logic;
signal usbreg_phy_test_mode_toggle_ss  : std_logic;
signal usbreg_phy_test_mode_toggle_sss : std_logic;
signal usbreg_phy_test_mode_toggle     : std_logic;
signal usb_decrement_bytes_s     : std_logic;
signal usb_decrement_bytes_ss    : std_logic;
signal usb_decrement_bytes_sss   : std_logic;
signal pie_devicespeed_s         : std_logic_vector(1 downto 0);
signal pie_devicespeed_ss        : std_logic_vector(1 downto 0);
signal id_value_ss,id_value_s    : std_logic;

begin

  proc_sync_usb : process (usb_clk, usb_rst_n)
  begin
    if usb_rst_n = '0' then
      usbreg_fladj_change_s    <= '0';
      usbreg_fladj_change_ss   <= '0';
      usbreg_fladj_change_sss  <= '0';

      usbreg_run_s             <= '0';
      usbreg_run_ss            <= '0';

      usbreg_portresume_s      <= '0';
      usbreg_portresume_ss     <= '0';
      usbreg_portreset_s       <= '0';
      usbreg_portreset_ss      <= '0';
      usbreg_portsuspend_s     <= '0';
      usbreg_portsuspend_ss    <= '0';
      usbreg_portl1l2suspend_s <= '0';
      usbreg_portl1l2suspend_ss <= '0';
      if C_PORTPOWER_CONTROL then
        usbreg_portpower_s     <= '0';
        usbreg_portpower_ss    <= '0';
      end if;

      epinfo_starttransfer_s   <= '0';
      epinfo_starttransfer_ss  <= '0';
      epinfo_starttransfer_sss <= '0';

      epinfo_txdata_valid_s    <= '0';
      epinfo_txdata_valid_ss   <= '0';

      phy_start_s       <= '0';
      phy_start_ss      <= '0';
      phy_start_sss     <= '0';

      pie_endtransfer_toggle   <= '0';

      usbreg_portenable_clear_s   <= '0';
      usbreg_portenable_clear_ss  <= '0';
      usbreg_portenable_clear_sss <= '0';

      usbreg_reset_s	       <= '0';
      usbreg_reset_ss  	       <= '0';
      usbreg_light_reset_s     <= '0';
      usbreg_light_reset_ss    <= '0';

      usbreg_phy_test_mode_toggle_s <= '0';
      usbreg_phy_test_mode_toggle_ss <= '0';
      usbreg_phy_test_mode_toggle_sss <= '0';

    elsif usb_clk'event and usb_clk = '1' then
      usbreg_fladj_change_s    <= usbreg_fladj_change;
      usbreg_fladj_change_ss   <= usbreg_fladj_change_s;
      usbreg_fladj_change_sss  <= usbreg_fladj_change_ss;

      usbreg_run_s             <= usbreg_run;
      usbreg_run_ss            <= usbreg_run_s;

      usbreg_portresume_s      <= usbreg_portresume;
      usbreg_portresume_ss     <= usbreg_portresume_s;
      usbreg_portreset_s       <= usbreg_portreset;
      usbreg_portreset_ss      <= usbreg_portreset_s;
      usbreg_portsuspend_s     <= usbreg_portsuspend;
      usbreg_portsuspend_ss    <= usbreg_portsuspend_s;
      usbreg_portl1l2suspend_s <= usbreg_portl1l2suspend;
      usbreg_portl1l2suspend_ss <= usbreg_portl1l2suspend_s;
      if C_PORTPOWER_CONTROL then
        usbreg_portpower_s     <= usbreg_portpower;
        usbreg_portpower_ss    <= usbreg_portpower_s;
      end if;

      epinfo_starttransfer_s   <= epinfo_starttransfer;
      epinfo_starttransfer_ss  <= epinfo_starttransfer_s;
      epinfo_starttransfer_sss <= epinfo_starttransfer_ss;

      epinfo_txdata_valid_s    <= epinfo_txdata_valid;
      epinfo_txdata_valid_ss   <= epinfo_txdata_valid_s;

      phy_start_s       <= usbreg_phy_start;
      phy_start_ss      <= phy_start_s;
      phy_start_sss     <= phy_start_ss;

      if pie_endtransfer = '1' then
        pie_endtransfer_toggle <= not(pie_endtransfer_toggle);
      end if;

      usbreg_portenable_clear_s   <= usbreg_portenable_clear;
      usbreg_portenable_clear_ss  <= usbreg_portenable_clear_s;
      usbreg_portenable_clear_sss <= usbreg_portenable_clear_ss;

      usbreg_reset_s	       <= usbreg_reset;
      usbreg_reset_ss  	       <= usbreg_reset_s;
      usbreg_light_reset_s     <= usbreg_light_reset;
      usbreg_light_reset_ss    <= usbreg_light_reset_s;

      usbreg_phy_test_mode_toggle_s   <= usbreg_phy_test_mode_toggle;
      usbreg_phy_test_mode_toggle_ss  <= usbreg_phy_test_mode_toggle_s;
      usbreg_phy_test_mode_toggle_sss <= usbreg_phy_test_mode_toggle_ss;

      if usbreg_reset_ss = '1' or usbreg_light_reset_ss = '1' then
        if usbreg_reset_ss = '1' then -- only reset this on a HcReset; not when there is a HcLightReset
          usbreg_portresume_s      <= '0';
          usbreg_portresume_ss     <= '0';
          usbreg_portreset_s       <= '0';
          usbreg_portreset_ss      <= '0';
          usbreg_portsuspend_s     <= '0';
          usbreg_portsuspend_ss    <= '0';
          usbreg_portl1l2suspend_s <= '0';
          usbreg_portl1l2suspend_ss <= '0';
          if C_PORTPOWER_CONTROL then
            usbreg_portpower_s     <= '0';
            usbreg_portpower_ss    <= '0';
          end if;
          usbreg_portenable_clear_s   <= '0';
          usbreg_portenable_clear_ss  <= '0';
          usbreg_portenable_clear_sss <= '0';
          usbreg_phy_test_mode_toggle_s <= '0';
          usbreg_phy_test_mode_toggle_ss <= '0';
          usbreg_phy_test_mode_toggle_sss <= '0';
	end if;
        usbreg_fladj_change_s    <= '0';
        usbreg_fladj_change_ss   <= '0';
        usbreg_run_s             <= '0';
        usbreg_run_ss            <= '0';
        epinfo_starttransfer_s   <= '0';
        epinfo_starttransfer_ss  <= '0';
        epinfo_starttransfer_sss <= '0';
        epinfo_txdata_valid_s    <= '0';
        epinfo_txdata_valid_ss   <= '0';
        phy_start_s       <= '0';
        phy_start_ss      <= '0';
        phy_start_sss     <= '0';
        pie_endtransfer_toggle   <= '0';
      end if;

    end if;
  end process proc_sync_usb;

  proc_sync_ahb : process (hclk, hrstn)
  begin
    if hrstn = '0' then
      usb_overcurrent_n_s       <= '1';
      usb_overcurrent_n_ss      <= '1';

      usb_inc_frindex_toggle_s  <= '0';
      usb_inc_frindex_toggle_ss <= '0';
      usb_inc_frindex_toggle_sss<= '0';

      pie_portconnect_s         <= '0';
      pie_portconnect_ss        <= '0';
      pie_portenable_s          <= '0';
      pie_portenable_ss         <= '0';
      pie_resume_detected_s     <= '0';
      pie_resume_detected_ss    <= '0';
      pie_resume_done_s         <= '0';
      pie_resume_done_ss        <= '0';
      pie_linestate_s           <= "00";
      pie_linestate_ss          <= "00";

      pie_txdatafetched_s	<= '0';
      pie_txdatafetched_ss	<= '0';
      pie_txdatafetched_sss	<= '0';

      pie_rxdatavalid_s      	<= '0';
      pie_rxdatavalid_ss      	<= '0';
      pie_rxdatavalid_sss       <= '0';
      pie_endtransfer_toggle_s 	<= '0';
      pie_endtransfer_toggle_ss	<= '0';
      pie_endtransfer_toggle_sss<= '0';

      phy_endtoggle_s            <= '0';
      phy_endtoggle_ss           <= '0';
      phy_endtoggle_sss          <= '0';

      sync_reset_done_s          <= '0';
      sync_reset_done_ss         <= '0';
      sync_reset_done_sss        <= '0';

      usbreg_phy_test_mode_s     <= (others => '0');
      usbreg_phy_test_mode_toggle<= '0';
      pie_devicespeed_s          <= (others => '0');
      pie_devicespeed_ss         <= (others => '0');

      usb_decrement_bytes_s      <= '0';
      usb_decrement_bytes_ss     <= '0';
      usb_decrement_bytes_sss    <= '0';

      id_value_s                 <= '0';
      id_value_ss                 <= '0';

    elsif hclk'event and hclk = '1' then
      usb_overcurrent_n_s       <= usb_overcurrent_n;
      usb_overcurrent_n_ss      <= usb_overcurrent_n_s;

      usb_inc_frindex_toggle_s  <= usb_inc_frindex_toggle;
      usb_inc_frindex_toggle_ss <= usb_inc_frindex_toggle_s;
      usb_inc_frindex_toggle_sss<= usb_inc_frindex_toggle_ss;

      pie_portconnect_s         <= pie_portconnect;
      pie_portconnect_ss        <= pie_portconnect_s;
      pie_portenable_s          <= pie_portenable;
      pie_portenable_ss         <= pie_portenable_s;
      pie_resume_detected_s     <= pie_resume_detected;
      pie_resume_detected_ss    <= pie_resume_detected_s;
      pie_resume_done_s         <= pie_resume_done;
      pie_resume_done_ss        <= pie_resume_done_s;
      pie_linestate_s           <= pie_linestate;
      pie_linestate_ss          <= pie_linestate_s;

      pie_txdatafetched_s	<= pie_txdatafetched;
      pie_txdatafetched_ss	<= pie_txdatafetched_s;
      pie_txdatafetched_sss	<= pie_txdatafetched_ss;

      pie_rxdatavalid_s      	<= pie_rxdatavalid;
      pie_rxdatavalid_ss      	<= pie_rxdatavalid_s;
      pie_rxdatavalid_sss       <= pie_rxdatavalid_ss;

      pie_endtransfer_toggle_s 	<= pie_endtransfer_toggle;
      pie_endtransfer_toggle_ss	<= pie_endtransfer_toggle_s;
      pie_endtransfer_toggle_sss<= pie_endtransfer_toggle_ss;

      phy_endtoggle_s           <= pie_phy_endtoggle;
      phy_endtoggle_ss          <= phy_endtoggle_s;
      phy_endtoggle_sss         <= phy_endtoggle_ss;

      sync_reset_done_s         <= usbreg_reset_ss or usbreg_light_reset_ss;
      sync_reset_done_ss        <= sync_reset_done_s;
      sync_reset_done_sss       <= sync_reset_done_ss;

      usbreg_phy_test_mode_s    <= usbreg_phy_test_mode;
      if usbreg_phy_test_mode_s /= usbreg_phy_test_mode then -- phy_test_mode has changed
         usbreg_phy_test_mode_toggle <= not usbreg_phy_test_mode_toggle;
      end if;

      pie_devicespeed_s         <= pie_devicespeed;
      pie_devicespeed_ss        <= pie_devicespeed_s;

      usb_decrement_bytes_s     <= usb_decrement_bytes;
      usb_decrement_bytes_ss    <= usb_decrement_bytes_s;
      usb_decrement_bytes_sss   <= usb_decrement_bytes_ss;

      id_value_s                 <= id_value;
      id_value_ss                 <= id_value_s;

      if usbreg_reset = '1' or usbreg_light_reset = '1' then
        if usbreg_reset = '1' then -- only reset this on a HcReset; not when there is a HcLightReset
          usb_overcurrent_n_s         <= '1';
          usb_overcurrent_n_ss        <= '1';
          pie_portconnect_s           <= '0';
          pie_portconnect_ss          <= '0';
          pie_portenable_s            <= '0';
          pie_portenable_ss           <= '0';
          pie_resume_detected_s       <= '0';
          pie_resume_detected_ss      <= '0';
          pie_resume_done_s           <= '0';
          pie_resume_done_ss          <= '0';
          pie_linestate_s             <= "00";
          pie_linestate_ss            <= "00";
          usbreg_phy_test_mode_s      <= (others => '0');
          usbreg_phy_test_mode_toggle <= '0';
          pie_devicespeed_s           <= (others => '0');
          pie_devicespeed_ss          <= (others => '0');
          id_value_s                 <= '0';
          id_value_ss                 <= '0';
	end if;
        usb_inc_frindex_toggle_s  <= '0';
        usb_inc_frindex_toggle_ss <= '0';
        usb_inc_frindex_toggle_sss<= '0';
        pie_txdatafetched_s	  <= '0';
        pie_txdatafetched_ss	  <= '0';
        pie_txdatafetched_sss 	  <= '0';
        pie_rxdatavalid_s      	  <= '0';
        pie_rxdatavalid_ss        <= '0';
        pie_rxdatavalid_sss       <= '0';
        pie_endtransfer_toggle_s  <= '0';
        pie_endtransfer_toggle_ss <= '0';
        pie_endtransfer_toggle_sss<= '0';
        phy_endtoggle_s           <= '0';
        phy_endtoggle_ss          <= '0';
        phy_endtoggle_sss         <= '0';
        usb_decrement_bytes_s      <= '0';
        usb_decrement_bytes_ss     <= '0';
        usb_decrement_bytes_sss    <= '0';
      end if;
    end if;
  end process proc_sync_ahb;

  usb_overcurrent_sync     <= not(usb_overcurrent_n_ss);

  usbreg_fladj_sync        <= usbreg_fladj;
  usbreg_fladj_change_sync <= '1' when (usbreg_fladj_change_ss /=
                                        usbreg_fladj_change_sss  )
				  else '0';

  usbreg_run_sync          <= usbreg_run_ss;

  usbreg_portresume_sync   <= usbreg_portresume_ss;
  usbreg_portreset_sync    <= usbreg_portreset_ss;
  usbreg_portsuspend_sync  <= usbreg_portsuspend_ss;
  usbreg_portl1l2suspend_sync  <= usbreg_portl1l2suspend_ss;
  usbreg_portpower_sync    <= usbreg_portpower_ss when C_PORTPOWER_CONTROL
                                                  else '1';

  usb_inc_frindex_toggle_sync <= '1' when (usb_inc_frindex_toggle_ss /=
                                           usb_inc_frindex_toggle_sss  ) else
				 '0';

  pie_portconnect_sync	   <= pie_portconnect_ss;
  pie_portenable_sync	   <= pie_portenable_ss;
  pie_resume_detected_sync <= pie_resume_detected_ss;
  pie_resume_done_sync     <= pie_resume_done_ss;
  pie_linestate_sync       <= pie_linestate_ss;

  pie_txdatafetched_sync   <= '1' when (pie_txdatafetched_ss /=
                                        pie_txdatafetched_sss   ) else
                              '0';
  pie_rx_nbytes_sync       <= pie_rx_nbytes;
  pie_rxdata_sync          <= pie_rxdata;
  pie_rxdatavalid_sync     <= '1' when (pie_rxdatavalid_ss  /=
                                        pie_rxdatavalid_sss    ) else
		              '0';
  pie_endtransfer_sync     <= '1' when (pie_endtransfer_toggle_ss /=
                                        pie_endtransfer_toggle_sss   ) else
			      '0';

  pie_response_sync        <= pie_response;

  epinfo_starttransfer_sync     <= '1' when (epinfo_starttransfer_ss  = '1') and
                                            (epinfo_starttransfer_sss = '0') else
			           '0';

  epinfo_token_sync		<= epinfo_token;
  epinfo_devaddr_sync		<= epinfo_devaddr;
  epinfo_epnr_sync		<= epinfo_epnr;
  epinfo_toggle_sync		<= epinfo_toggle;
  epinfo_eptype_sync		<= epinfo_eptype;
  epinfo_mult_sync              <= epinfo_mult;
  epinfo_maxpacket_sync         <= epinfo_maxpacket;
  epinfo_nbytes_sync		<= epinfo_nbytes;
  epinfo_lowspeed_sync		<= epinfo_lowspeed;
  epinfo_sofnr_sync		<= epinfo_sofnr;
  epinfo_subpid_sync		<= epinfo_subpid;
  epinfo_lpm_linkstate_sync	<= epinfo_lpm_linkstate;
  epinfo_lpm_hird_sync		<= epinfo_lpm_hird;
  epinfo_lpm_bremotewakeup_sync <= epinfo_lpm_bremotewakeup;
  epinfo_split_hubaddr_sync	<= epinfo_split_hubaddr;
  epinfo_split_port_sync	<= epinfo_split_port;
  epinfo_split_se_sync		<= epinfo_split_se;
  epinfo_txdata_sync		<= epinfo_txdata;

  epinfo_txdata_valid_sync      <= epinfo_txdata_valid_ss;

  usbreg_phy_addr_sync     <= usbreg_phy_addr;
  usbreg_phy_wdata_sync	   <= usbreg_phy_wdata;
  pie_phy_rdata_sync       <= pie_phy_rdata;
  usbreg_phy_write_sync	   <= usbreg_phy_write;
  usbreg_phy_start_sync	   <= '1' when (phy_start_ss  = '1')              and
                                       (phy_start_sss = '0') else
			      '0';
  usbreg_phy_mode_sync	   <= usbreg_phy_mode;
  pie_phy_endtoggle_sync   <= '1' when (phy_endtoggle_ss  /=
                                        phy_endtoggle_sss) else
			      '0';
  usbreg_portenable_clear_sync <= '1' when (usbreg_portenable_clear_ss  /=
                                            usbreg_portenable_clear_sss    ) else
			          '0';

  usbreg_reset_sync        <= usbreg_reset_ss;
  usbreg_light_reset_sync  <= usbreg_light_reset_ss;
  sync_reset_done          <= '1' when sync_reset_done_ss  = '1' and
                                       sync_reset_done_sss = '0'
				  else '0';

  usbreg_phy_test_mode_change_sync <= '1' when (usbreg_phy_test_mode_toggle_ss /=
                                                usbreg_phy_test_mode_toggle_sss  ) else
				      '0';

  usb_decrement_bytes_sync <= '1' when (usb_decrement_bytes_ss /=
                                        usb_decrement_bytes_sss  ) else
			      '0';

  pie_devicespeed_sync     <= pie_devicespeed_ss;

  usb_uframe_count_sync    <= usb_uframe_count;

  id_value_sync <= id_value_ss;

end RTL; --usb_host_synchronizer
