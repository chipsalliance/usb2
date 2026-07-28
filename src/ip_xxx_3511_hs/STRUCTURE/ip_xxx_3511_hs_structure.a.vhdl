--  SPDX-License-Identifier: Apache-2.0
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--  http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
--
--  ----------------------------------------------------------------------------
--                     Copyright Message
--  ----------------------------------------------------------------------------
--
--   NXP B.V. confidential and proprietary.
--   COPYRIGHT (c) NXP B.V. 2007
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
--               File: ip_xxx_3511_hs_structure.a.vhdl
--
--             Author: Bart Vertenten
--
--       Organisation: Central R&D / Design Services / MSS - Connectivity
--
--              $Date: Tue Jan 30 23:49:09 2018 $
--
--            Project: Low gate count USB peripheral IP
--
--        Description:
--
--          $Revision: 1.8 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: ip_xxx_3511_hs_structure.a.vhdl.rca $
--   
--    Revision: 1.8 Tue Jan 30 23:49:09 2018 usb06610
--    pulled out the following hard-coded constants, from ip_xxx_3511/RTL/usb_host_pie.m.vhdl and ip_xxx_3511/RTL/usb_pie.m.vhdl, to the boundary of the ip_xxx_3516_hs_mem as inputs: INTER_PACKET_DELAY_LS INTER_PACKET_DELAY_FS INTER_PACKET_DELAY_HS PACKET_TURNAROUND_TIMEOUT_LS PACKET_TURNAROUND_TIMEOUT_FS PACKET_TURNAROUND_TIMEOUT_HS PACKET_EVENT_TIMEOUT_LS PACKET_EVENT_TIMEOUT_FS PACKET_EVENT_TIMEOUT_HS
--    
--
--    Revision: 1.61 Thu Nov  8 11:03:53 2012 beq03196
--    Fix CR#82: CR - add bits for new OTG features
--
--    Revision: 1.60 Tue May  8 08:27:07 2012 beq03067
--    no debug for fpga
--
--    Revision: 1.59 Mon May  7 17:02:40 2012 beq03339
--    Commented out usb_pie output pins pie_hub_selected and pie_hub_selected
--
--    Revision: 1.58 Mon May  7 16:41:46 2012 beq03339
--    ip_xxx_3511_hs_fpga is connected to '0's for synthesis
--
--    Revision: 1.57 Fri Feb 24 11:52:52 2012 beq03067
--    Added preserve on clock_on node name in the netlist to avoid issue with the sdc,
--
--    Revision: 1.56 Mon Feb 20 13:47:26 2012 beq03339
--    Added testmode input pin to control pie_clk mux for testmode
--
--    Revision: 1.55 Fri Jan  6 11:45:35 2012 beq03196
--    fixed PR#74: UTMI reset timer to run on AHB clock to support new USB PHY from SMS
--
--    Revision: 1.54 Thu Dec 15 10:42:26 2011 beq03196
--    remove ratefeedbackmode input pin for the pie
--
--    Revision: 1.53 Fri Dec  2 15:57:19 2011 beq03196
--    Fix PR#68: ip_3511 : ULPI Interface: disconnect device not always detected on FPGA
--    Fix PR#70:  ip_3511 : UTMI PHY exits low power mode by connecting it to a suspended host
--
--    Revision: 1.52 Tue Nov 22 15:30:55 2011 beq03099
--    reduced gate count on checker that looks if usb clock is still running
--
--    Revision: 1.51 Wed Nov  9 08:59:37 2011 beq03196
--    Fix PR#48 (metastability risk in the 3511, Could break the PHY )
--
--    Revision: 1.50 Thu Oct 20 16:52:09 2011 beq03067
--    removing attribute synthesis ogg as conformal is using it.
--
--    Revision: 1.49 Thu Oct 20 11:20:39 2011 beq03067
--    Added  synthesis synthesis_off for synplify_pro
--
--    Revision: 1.48 Tue Oct 18 15:50:26 2011 beq03099
--    clock_on must be one when there is a USB PHY register access
--
--    Revision: 1.47 Wed Oct 12 14:35:45 2011 beq03067
--    added Reset_N in sensitivity list.
--
--    Revision: 1.46 Wed Oct 12 14:20:11 2011 beq03067
--    added phy_interface for FPGA
--
--    Revision: 1.45 Tue Oct 11 11:09:26 2011 beq03196
--    Fix PR#56 (3511_hs ulpi : on connect, ulpi clock is stopped  ) + add robustness on wake-up/resume for UTMI
--
--    Revision: 1.44 Wed Oct  5 13:50:41 2011 beq03067
--    fixed fpga signals issue
--
--    Revision: 1.43 Wed Oct  5 13:30:14 2011 beq03067
--    PR 50.
--
--    Revision: 1.42 Wed Oct  5 11:36:15 2011 beq03196
--    ULPI Low Power implementation and disable fix PR#55(VBusDebounced : added a delay to assert VBusDebounced)
--
--    Revision: 1.41 Thu Sep 22 15:03:59 2011 beq03099
--    VBusDebounced : added a delay to assert VBusDebounced
--
--    Revision: 1.40 Wed Sep 21 12:31:38 2011 beq03099
--    attached signal sys_dev_wakeup_n
--
--    Revision: 1.39 Wed Sep 21 07:23:19 2011 beq03067
--    debug 256 bits
--
--    Revision: 1.37 Mon Sep 19 07:15:12 2011 beq03067
--    commented out un-assigned signals.
--
--    Revision: 1.36 Mon Sep 19 07:05:14 2011 beq03067
--    added usb_reg_if_fpga
--
--    Revision: 1.35 Fri Sep 16 12:21:29 2011 beq03196
--    Fix PR#46: Wrong usage of phy_mode bit in the pie.
--
--    Revision: 1.34 Fri Sep 16 11:40:22 2011 beq03196
--    fix PR#45: Fail on detection of a resume by the 3511_hs
--
--    Revision: 1.33 Thu Sep 15 09:52:13 2011 beq03196
--    Fix PR#41: Clocks do not restart when 3511_hs is attached to USB
--
--    Revision: 1.32 Tue Sep 13 13:57:08 2011 beq03196
--    Fix PR#40 (atx_reset does not behave as expected)
--
--    Revision: 1.31 Mon Sep 12 16:54:16 2011 beq03196
--    replace sys_ahb_needclk to usb_need_clk according to arch doc and update clock_off_counter
--
--    Revision: 1.30 Fri Sep  9 14:22:57 2011 beq03099
--    additional fix for clock_on signal
--
--    Revision: 1.29 Fri Sep  9 12:34:59 2011 beq03099
--    fixed problem with clock_on
--
--    Revision: 1.28 Thu Sep  8 13:53:21 2011 beq03196
--    ULPI implementation & Vbusvalid selection (PR#39)
--
--    Revision: 1.27 Mon Aug 29 11:07:43 2011 beq03196
--    ULPI + UTMI interfaces available at toplevel.
--
--    Revision: 1.26 Wed Aug 17 09:24:17 2011 beq03067
--    new system io's.
--
--    Revision: 1.25 Mon Aug  8 11:58:51 2011 beq03099
--    removed async_disable as it was a duplicate
--
--    Revision: 1.24 Mon Aug  8 10:48:40 2011 beq03099
--    added async_disable to reset_n generation
--
--    Revision: 1.23 Thu Jul 28 07:13:35 2011 beq03099
--    added suspend and clock control
--
--    Revision: 1.22 Thu Jul 14 16:23:29 2011 beq03099
--    added power down signals
--
--    Revision: 1.21 Fri Jul  8 08:40:51 2011 beq03099
--    added UTMI vendor specific signals
--
--    Revision: 1.20 Thu Jul  7 17:16:12 2011 beq03196
--    add UTMI vendor specific signals at pie interface.
--
--    Revision: 1.19 Thu Jul  7 16:04:16 2011 beq03196
--    mismatch between hw_hird and sw_hird for lpm
--
--    Revision: 1.18 Tue Jul  5 10:43:11 2011 beq03067
--    added usb_dma debug
--
--    Revision: 1.17 Mon Jul  4 11:46:34 2011 beq03196
--    signals for lpm are now connected to the pie.
--
--    Revision: 1.16 Tue Jun 21 13:50:52 2011 beq03196
--    epinfo_maxpacket connected to the pie.
--
--    Revision: 1.15 Tue Jun 21 09:47:45 2011 beq03099
--    added extra signal epinfo_maxpacket
--
--    Revision: 1.14 Thu Jun 16 14:23:34 2011 beq03099
--    added vendor specific PHY interface
--
--    Revision: 1.13 Mon Jun  6 13:52:07 2011 beq03099
--    Fixed issue with constants
--
--    Revision: 1.12 Wed Jun  1 14:02:35 2011 beq03067
--    fixed floating signals.
--
--    Revision: 1.11 Fri May 20 11:51:13 2011 beq03196
--    dev_enabled must be replaced by dev_connected in the bus_event FSM (to detect disconnect)
--
--    Revision: 1.10 Tue May 17 14:55:52 2011 beq03067
--    added fpga debug
--
--    Revision: 1.9 Tue May 17 11:55:39 2011 beq03099
--    assigned USB_FrameToggle to a temp value
--
--    Revision: 1.8 Mon May 16 16:39:01 2011 beq03099
--    connected to dual-port RAM model
--
--    Revision: 1.7 Fri May 13 11:54:19 2011 beq03099
--    modified interface to be a ram interface instead of AHB master
--
--    Revision: 1.6 Thu May 12 10:14:29 2011 beq03196
--    add USB_DATAWIDTH in the generic map of the usb_synchronizer
--
--    Revision: 1.5 Thu May  5 16:29:08 2011 beq03099
--    added C_NBPHYSEP as generic on usb_pie block
--
--    Revision: 1.4 Thu May  5 16:08:52 2011 beq03099
--    structure is compiling
--
--    Revision: 1.3 Thu May  5 15:43:44 2011 beq03099
--    replaced sie with pie module
--
--    Revision: 1.2 Thu Feb 24 10:02:06 2011 beq03099
--    removed usb_cfg package
--
--    Revision: 1.1 Thu Feb 10 12:25:11 2011 beq03099
--    first version - still contains SIE and not PIE
--
--
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY rtl;
USE rtl.usb_general_subcmp_pkg.all;
USE rtl.usb_configuration_subcmp_pkg.all;
USE rtl.usb_subcmp_pkg.all;

architecture structure of ip_xxx_3511_hs is

--++++++++++++++++++++++++++++++++++++++++++++++
-- Constants that are specific for this toplevel
constant C_MINOR_REV       : std_logic_vector(7 downto 0) := X"01";

-- C_MAJOR_REV indicates the capabilities of this IP
-- 0x01 : USB2.0 Full-speed device
-- 0x02 : USB2.0 High-speed device with UTMI interface
constant C_MAJOR_REV       : std_logic_vector(7 downto 0) := X"02";
constant USBPIE_DATAWIDTH : integer := 64;
constant USBRAM_DATAWIDTH : integer := 64;
constant RESET_CYCLE      : integer := 63;
constant C_NBDEV          : integer := 1;
--++++++++++++++++++++++++++++++++++++++++++++++

-- ----------------------------------------------------------------------------
-- Post-synchronizer OCP Recovery v1.1 EP0 arbiter (hclk / dev_axi_aclk domain).
-- Interposes on the synchronized SIE interface between usb_synchronizer and the
-- downstream consumers usb_dma and usb_reg_if.
-- See usb_ocp_recovery_post_sync_arb.{e,m}.vhdl.
-- ----------------------------------------------------------------------------
component usb_ocp_recovery_post_sync_arb
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
    ctrl_out_be     : out std_logic_vector(3 downto 0);
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
    ocp_path_disable_i : in  std_logic;
    rec_claim_status : out std_logic
  );
end component;


component usb_pie
      generic (
      ULPI_SUPPORT          : boolean := TRUE;
      UTMI_SUPPORT          : boolean := TRUE;
      USB_DATAWIDTH         : integer := 64;
      C_NBDEV               : integer := 1; -- <<<< LAB to review 
      C_NBPHYSEP            : integer := 14;
      C_EXTEND_TX_DELAY       : boolean := FALSE;
      G_SIM_CHIRP_TIMERS      : boolean := FALSE
   );
    port (
          ----- To/From usb synchronizer ------------------------
	 pie_epinfo_req               : out std_logic;
	 pie_epinfo_epnr              : out std_logic_vector(3 downto 0);
	 pie_epinfo_epdir             : out std_logic;
	 pie_epinfo_setup             : out std_logic;
	 pie_epinfo_setup_received    : out std_logic;
	 pie_usbaddress               : out std_logic_vector(6 downto 0);

	 epinfo_valid                 : in  std_logic;
	 epinfo_active                : in  std_logic;
	 epinfo_disabled              : in  std_logic;
	 epinfo_toggle                : in  std_logic;
	 epinfo_stall                 : in  std_logic;
	 epinfo_iso                   : in  std_logic;
	 epinfo_nbytes                : in  std_logic_vector(14 downto 0);
         epinfo_maxpacket             : in std_logic_vector(1 downto 0);

	 pie_txdata_fetched           : out std_logic;
	 epinfo_txdata                : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
         epinfo_txdata_valid          : in  std_logic;

         pie_rx_nbytes                : out std_logic_vector(11 downto 0);
         pie_rxdata                   : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
         pie_rxdatavalid              : out std_logic;

         pie_endtransfer              : out std_logic;
	 pie_success                  : out std_logic;
	 pie_error                    : out std_logic;
	 pie_errortype                : out std_logic_vector(3 downto 0);
         pie_sentNAK                  : out std_logic;
         pie_isotoggle                : out std_logic;
	 pie_busreset                 : out std_logic;
	 pie_devicespeed              : out std_logic;
	 pie_suspend                  : out std_logic;
	 pie_lpm_suspend              : out std_logic;
         pie_lpm_remotewake_enable    : out std_logic;
         pie_lpm_hird_hw              : out std_logic_vector(3 downto 0);

         pie_vbusvalid                : out std_logic;
         pie_lowpower_n               : out std_logic;


         reset_n                      : in std_logic; -- AHB reset after resynchronization, active LOW
         pie_clk                      : in std_logic; -- UTMI/ULPI clock


         phy_address                  : in std_logic_vector(7 downto 0);
         phy_readdata                 : out std_logic_vector(7 downto 0);
         phy_writedata                : in std_logic_vector(7 downto 0);
	 phy_write                    : in std_logic;
	 phy_start                    : in std_logic;
	 phy_endtoggle                : out std_logic;
         phy_mode                     : in std_logic;

         sync_usbreg_phy_test_mode_change  : in std_logic;  -- phy_test_mode change, resynchronized with usb_pie clock
         sync_usbreg_remotewakeup     : in std_logic;  -- usbreg_remotewakeup from reg_if resynchronized with usb_pie clock
         sync_usbreg_lpmremotewakeup     : in std_logic;  -- usbreg_lpmremotewakeup from reg_if resynchronized with usb_pie clock

          -----  To/From usb_reg_if ------------------------
          ------ To/From ahb register module - pseudo-static signals
         usbreg_pll_on                : in  std_logic;
         usbreg_deviceenabled         : in  std_logic_vector(C_NBDEV-1 downto 0);
	 usbreg_dev_connect           : in  std_logic;
	 usbreg_remotewakeup          : in  std_logic;
	 usbreg_lpm_sup               : in  std_logic;
	 usbreg_lpmremotewakeup       : in  std_logic;
	 usbreg_lpm_hird_sw           : in std_logic_vector(3 downto 0);
         usbreg_lpm_nyet              : in std_logic;
	 usbreg_frame_number          : out std_logic_vector(10 downto 0);
         usbreg_usbaddress            : in  std_logic_vector(C_NBDEV*7-1 downto 0);
         usbreg_usbaddress_tmp        : in  std_logic_vector(C_NBDEV*7-1 downto 0);
         usbreg_phy_test_mode         : in  std_logic_vector(2 downto 0);
         usbreg_port_force_fullspeed  : in  std_logic;

	 token_length_counter         : in  std_logic_vector(6 downto 0);
	 usb_token_length             : out std_logic_vector(6 downto 0);

         utmi_vcontrol : out std_logic_vector(3 downto 0);
         utmi_vcontrolloadm : out std_logic;
         utmi_vstatus : in std_logic_vector(7 downto 0);


	 -- UTMI INTERFACE
	 -- These signals are only to be used when the generic
         -- UTMI_SUPPORT is set to TRUE
	-- utmi_clk                     : in  std_logic;
	 utmi_rxdata                  : in  std_logic_vector(7 downto 0);
	 utmi_rxvalid                 : in  std_logic;
	 utmi_rxactive                : in  std_logic;
	 utmi_rxerror                 : in  std_logic;
	 utmi_txdata                  : out std_logic_vector(7 downto 0);
	 utmi_txvalid                 : out std_logic;
	 utmi_txready                 : in  std_logic;
	 utmi_reset                   : out std_logic;
	 utmi_xcvrselect              : out std_logic;
	 utmi_termselect              : out std_logic;
	 utmi_opmode                  : out std_logic_vector(1 downto 0);
         utmi_linestate               : in  std_logic_vector(1 downto 0);
         utmi_vbusvalid               : in std_logic;
         -- ULPI INTERFACE
	 -- These signals are only to be used when the generic
	 -- ULPI_SUPPORT is set to TRUE
	-- ulpi_clk                     : in  std_logic;
	 ulpi_rxdata                  : in std_logic_vector(7 downto 0);
	 ulpi_txdata                  : out std_logic_vector(7 downto 0);
	 ulpi_txenable                : out std_logic;
	 ulpi_dir                     : in  std_logic;
	 ulpi_stp                     : out std_logic;
         ulpi_nxt                     : in  std_logic;
         ulpi_pwrctrl_wakeup          : in std_logic;

         VBusDebounced                : in std_logic;
         -- <<<< LAB to review
         pie_dev_selected             : out integer range 0 to C_NBDEV - 1;
	 usb_pie_fpga                 : out std_logic_vector(63 downto 0);
         INTER_PACKET_DELAY_FS_param   : in  std_logic_vector(4 downto 0);
         INTER_PACKET_DELAY_HS_param   : in  std_logic_vector(4 downto 0);
         PACKET_TURNAROUND_TIMEOUT_FS_param : in  std_logic_vector(7 downto 0);
         PACKET_TURNAROUND_TIMEOUT_HS_param : in  std_logic_vector(7 downto 0);
         PACKET_EVENT_TIMEOUT_FS_param : in  std_logic_vector(8 downto 0);
         PACKET_EVENT_TIMEOUT_HS_param : in  std_logic_vector(8 downto 0)
	  );
end component;

component usb_synchronizer
  generic(C_ULPI_SUPPORT   : boolean := FALSE;
	  C_UTMI_SUPPORT   : boolean := TRUE;
          USB_DATAWIDTH    : integer := 8;
          TXNBYTES_BITS    : integer := 10;
          RXNBYTES_BITS    : integer := 11;
          C_NBDEV          : integer := 1);
  port  (
  	 ----- To/From usb clock domain ------------------------
  	 sieint_epinfo_req:     in  std_logic;                    --sync signal
  	 sieint_epinfo_epnr:    in  std_logic_vector(3 downto 0);
  	 sieint_epinfo_epdir:   in  std_logic;
  	 sieint_epinfo_setup:   in  std_logic;
  	 epinfo_valid:          out std_logic;                    --sync signal
     sieint_epinfo_setup_received    : in  std_logic;

  	 epinfo_active:         out std_logic;
  	 epinfo_disabled:       out std_logic;
  	 epinfo_toggle:         out std_logic;
  	 epinfo_stall:          out std_logic;
  	 epinfo_iso:            out std_logic;
  	 epinfo_ratefeedbackmode:out std_logic;
  	 epinfo_nbytes:         out std_logic_vector(TXNBYTES_BITS-1 downto 0);
         epinfo_maxpacket:      out std_logic_vector(1 downto 0);

  	 sieint_txdatafetched:  in  std_logic;                    --sync signal
  	 epinfo_txdata:         out std_logic_vector(USB_DATAWIDTH-1 downto 0);
  	 epinfo_txdata_valid:   out std_logic;                    --sync signal

  	 sieint_rx_nbytes:      in  std_logic_vector(RXNBYTES_BITS-1 downto 0);
           sieint_rxdata:         in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
           sieint_rxdatavalid:    in  std_logic;                    --sync signal

           sieint_endtransfer:    in  std_logic;                    --sync signal
           sieint_success:        in  std_logic; -- can this be combined with error ?
           sieint_error:          in  std_logic;
           sieint_errortype:      in  std_logic_vector(3 downto 0);
           sieint_sentNAK:        in  std_logic;
           --sieint_vbusvalid :      in  std_logic;
           VBusDebounced:         in std_logic;
           pie_lowpower_n:        in std_logic;
           vbuscomp_on:          out   std_logic;                      -- Enable Analog Vbus comparators
           chrg_vbus :          out   std_logic;
           dischrg_vbus:          out   std_logic;
	   avalid:               in    std_logic;                      -- ADPPROBE
           sessend:              in    std_logic;                      -- ADPSENSE

           TM_IsoToggle:          in  integer range 0 to 1;
           RG_BUSReset:           in  boolean;
           TM_Suspend:            in boolean;
           LPM_TM_Suspend:        in boolean;
           LPM_RW:                in boolean;

           phy_addr	      : out std_logic_vector(7 downto 0);
           phy_wdata	      : out std_logic_vector(7 downto 0);
           phy_rdata	      : in  std_logic_vector(7 downto 0);
           phy_write	      : out std_logic;
           phy_start	      : out std_logic;
           phy_mode	      : out std_logic;
           phy_endtoggle        : in  std_logic;

           sync_usbreg_phy_test_mode_change  : out std_logic;
           sync_usbreg_dev_connect      : out std_logic;
           sync_usbreg_remotewakeup     : out std_logic;
           sync_usbreg_lpmremotewakeup     : out std_logic;

          --
          sync_usbreg_pll_on         : out std_logic; 
          sync_usbreg_lpm_sup        : out std_logic; 
          sync_usbreg_lpm_hird_sw    : out std_logic_vector(3 downto 0);
          sync_usbreg_lpm_nyet       : out std_logic;

          pie_speed                  : in std_logic_vector(1 downto 0);
          sieint_lpm_hird_hw         : in  std_logic_vector( 3 downto 0);
          usbreg_frame_number        : in std_logic_vector(10 downto 0);
          pie_dev_selected           : in integer range 0 to C_NBDEV - 1;


  	 ----- To/From ahb clock domain ------------------------
  	 sync_sieint_epinfo_req:     out std_logic;                    --sync signal
  	 sync_sieint_epinfo_epnr:    out std_logic_vector(3 downto 0);
  	 sync_sieint_epinfo_epdir:   out std_logic;
  	 sync_sieint_epinfo_setup:   out std_logic;
           sync_sieint_setup_received: out std_logic; -- single pulse
  	 epinfo_sync_valid:          in  std_logic;                    --sync signal
  	 sync_VBusDebounced:         out std_logic;   -- sync signal
  	 usbreg_vbuscomp_on:         in   std_logic;                      -- Enable Analog Vbus comparators
  	 usbreg_chrg_vbus         : in std_logic;
         usbreg_dischrg_vbus      : in  std_logic;
         sync_avalid:                out    std_logic;                      -- ADPPROBE
         sync_sessend:               out    std_logic;                      -- ADPSENSE

  	 epinfo_sync_active:         in  std_logic;
  	 epinfo_sync_disabled:       in  std_logic;
  	 epinfo_sync_toggle:         in  std_logic;
  	 epinfo_sync_stall:          in  std_logic;
  	 epinfo_sync_iso:            in  std_logic;
  	 epinfo_sync_ratefeedbackmode:in std_logic;
  	 epinfo_sync_nbytes:         in  std_logic_vector(TXNBYTES_BITS-1 downto 0);
           epinfo_sync_maxpacket:      in  std_logic_vector(1 downto 0);

  	 sync_sieint_txdatafetched:  out std_logic;                    --sync signal
  	 epinfo_sync_txdata:         in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
  	 epinfo_sync_txdata_valid:   in  std_logic;                    --sync signal

  	 sync_sieint_rx_nbytes:      out std_logic_vector(RXNBYTES_BITS-1 downto 0);
           sync_sieint_rxdata:         out std_logic_vector(USB_DATAWIDTH-1 downto 0);
           sync_sieint_rxdatavalid:    out std_logic;                    --sync signal

           sync_sieint_endtransfer:    out std_logic;                    --sync signal
           sync_sieint_success:        out std_logic; -- can this be combined with error ?
           sync_sieint_error:          out std_logic;
           sync_sieint_errortype:      out std_logic_vector(3 downto 0);
           sync_sieint_sentNAK:        out std_logic;
           --sync_sieint_vbusvalid:      out std_logic;

           sync_set_frameint:          out std_logic;
           sync_busreset:              out std_logic;
           sync_suspend:               out std_logic;
           sync_lpm_suspend:           out std_logic;
           sync_lpm_rw:                out std_logic;

           usbreg_phy_addr	   : in  std_logic_vector(7 downto 0);
           usbreg_phy_wdata	   : in  std_logic_vector(7 downto 0);
           sync_phy_rdata	           : out std_logic_vector(7 downto 0);
           usbreg_phy_write	   : in  std_logic;
           usbreg_phy_start	   : in  std_logic;
           usbreg_phy_mode	   : in  std_logic;
           sync_phy_endtoggle        : out std_logic;

           usbreg_phy_test_mode : in  std_logic_vector(2 downto 0);
           usbreg_dev_connect   : in  std_logic;
           usbreg_remotewakeup  : in  std_logic;
           usbreg_lpmremotewakeup  : in  std_logic;

          --
          usbreg_pll_on              : in std_logic; 
          usbreg_lpm_sup             : in std_logic; 
          usbreg_lpm_hird_sw         : in std_logic_vector(3 downto 0);
          usbreg_lpm_nyet            : in std_logic;

          sync_pie_speed             : out std_logic_vector(1 downto 0);
          sync_sieint_lpm_hird_hw    : out std_logic_vector( 3 downto 0);
          sync_usbreg_frame_number   : out std_logic_vector(10 downto 0);
          sync_pie_dev_selected      : out integer range 0 to C_NBDEV - 1;


 	 ------ System ---------------------
  	 FsClk:                 in  std_logic;          -- Recovered Clock
  	 Reset_N:               in  std_logic;          -- Global Reset
  	 hclk:                  in  std_logic;
  	 hrstn:                 in  std_logic

	);
end component;

component usb_reg_if
  generic(C_ULPI_SUPPORT           : boolean := FALSE;
	  C_UTMI_SUPPORT           : boolean := TRUE;
          C_NBPHYSEP               : integer := 14;
	  C_EPUB                   : integer := 32;
	  C_DAUB                   : integer := 32;
	  C_DALB                   : integer := 22;
          C_EPFIFO_PAGE            : std_logic_vector(31 downto 0) := X"00080000";
          C_DATAFIFO_PAGE          : std_logic_vector(31 downto 0) := X"00080000";
          C_SINGLE_BUFFER_SUPPORTED: boolean := TRUE;
          C_DOUBLE_BUFFER_SUPPORTED: boolean := TRUE;
          C_TOGGLE_REG_READABLE	   : boolean := TRUE;
          C_PLL_ENABLE             : boolean := FALSE;
          C_PLL_DIVIDER            : std_logic_vector(6 downto 0) := "0010100";
	  C_MINOR_REV              : std_logic_vector(7 downto 0) := X"00";
          C_MAJOR_REV              : std_logic_vector(7 downto 0) := X"00");
  port (
        hclk		         : in  std_logic;
        hresetn		         : in  std_logic;
        USB_Int_Req_Irq          : out std_logic;
        USB_Int_Req_Fiq          : out std_logic;

        -- interface to AHB slave module
        reg_waddr		       : in  std_logic_vector(3 downto 0);
        reg_wdata                : in  std_logic_vector(31 downto 0);
        reg_raddr		       : in  std_logic_vector(3 downto 0);
        reg_rdata		       : out std_logic_vector(31 downto 0);
        reg_write                : in  std_logic;

        -- interface to other USB modules
        sieint_usbaddress        : in  std_logic_vector(6 downto 0);
        usbreg_usbaddress        : out std_logic_vector(6 downto 0);
        usbreg_usbaddress_tmp    : out std_logic_vector(6 downto 0);
        usbreg_deviceenabled     : out std_logic;
        usbreg_setup             : out std_logic;
        sieint_setup_received    : in  std_logic;
        usbreg_pll_on            : out std_logic;
        usbreg_lpm_sup           : out std_logic;
        usbreg_remotewakeup      : out std_logic;
        usbreg_lpmremotewakeup   : out std_logic;
        usbreg_dev_connect       : out std_logic;
        usbreg_frame_number      : in  std_logic_vector(10 downto 0);
        usbreg_ep_list_start     : out std_logic_vector(31 downto 0);
        usbreg_data_buffer_start : out std_logic_vector(31 downto 0);
        usbreg_lpm_hird_sw       : out std_logic_vector( 3 downto 0);
        sieint_lpm_hird_hw       : in  std_logic_vector( 3 downto 0);
        usbreg_lpm_nyet          : out std_logic;
        usbreg_ep_skip           : out std_logic_vector(C_NBPHYSEP+1 downto 0);
        usbreg_ep_bufinuse       : out std_logic_vector(C_NBPHYSEP+1 downto 0);
        usbreg_select_ext_clk    : out std_logic;
        --dma_epinfo_toggle        : in  std_logic_vector(C_NBPHYSEP+1 downto 0);
        usbreg_epinfo_toggle     : out std_logic_vector(C_NBPHYSEP+1 downto 0);
        usbreg_port_force_fullspeed  : out std_logic;
        dma_clear_toggle         : in  std_logic;
        dma_set_toggle           : in  std_logic;
        dma_sent_NAK             : in  std_logic;
        dma_set_int              : in  std_logic;
        dma_physepnr             : in  integer range 0 to C_NBPHYSEP+1;
        dma_clear_skip           : in  std_logic;
        dma_skip_ep              : in  integer range 0 to C_NBPHYSEP+1;
       -- VBusAvailable            : in  std_logic;
        sync_busreset            : in  std_logic;
        sync_suspend             : in  std_logic;
        sync_lpm_Suspend         : in  std_logic;
        sync_lpm_rw              : in  std_logic;
        sync_sieint_error        : in  std_logic;
        sync_sieint_errortype    : in  std_logic_vector(3 downto 0);
        sync_set_frameint        : in  std_logic;
        usbreg_phy_test_mode     : out std_logic_vector(2 downto 0);
        pie_speed                : in  std_logic_vector(1 downto 0);
        sync_VBusDebounced       : in  std_logic;
        usbreg_vbuscomp_on       : out   std_logic;                      -- Enable Analog Vbus comparators
        usbreg_chrg_vbus         : out std_logic;
        usbreg_dischrg_vbus      : out std_logic;
	sync_avalid              : in    std_logic;                      -- ADPPROBE
        sync_sessend             : in    std_logic;                      -- ADPSENSE
        usbreg_phy_addr	       : out std_logic_vector(7 downto 0);
        usbreg_phy_wdata	       : out std_logic_vector(7 downto 0);
        sync_phy_rdata	       : in  std_logic_vector(7 downto 0);
        usbreg_phy_write	       : out std_logic;
        usbreg_phy_start	       : out std_logic;
        usbreg_phy_mode	       : out std_logic;
        sync_phy_endtoggle       : in  std_logic;
	usb_reg_if_fpga : out std_logic_vector(63 downto 0)
      );
end component;

component usb_dma
  generic(USB_DATAWIDTH      : integer := 8;
	  RAM_DATAWIDTH      : integer := 32;
          C_NBPHYSEP         : integer := 14;
	  C_DALB             : integer := 22);
  port (
      hclk		: in	std_logic;
      hresetn		: in	std_logic;
      dma_addr		: out   std_logic_vector(31 downto 0);
      dma_req           : out   std_logic;
      dma_gnt           : in    std_logic;
      dma_write         : out   std_logic;
      dma_wdata         : out   std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      dma_rdata		: in 	std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      dma_word_enable   : out   std_logic_vector(RAM_DATAWIDTH/32-1 downto 0);
      sync_sieint_epinfo_req:     in  std_logic;
      sync_sieint_epinfo_epnr:    in  std_logic_vector(3 downto 0);
      sync_sieint_epinfo_epdir:   in  std_logic;
      sync_sieint_epinfo_setup:   in  std_logic;
      epinfo_sync_valid:          out std_logic;
      epinfo_sync_active:         out std_logic;
      epinfo_sync_disabled:       out std_logic;
      epinfo_sync_toggle:         out std_logic;
      epinfo_sync_stall:          out std_logic;
      epinfo_sync_iso:            out std_logic;
      epinfo_sync_ratefeedbackmode:out std_logic;
      epinfo_sync_nbytes:         out std_logic_vector(14 downto 0);
      epinfo_sync_maxpacket:      out std_logic_vector(1 downto 0);
      sync_sieint_txdatafetched:  in  std_logic;
      epinfo_sync_txdata:         out std_logic_vector(USB_DATAWIDTH-1 downto 0);
      epinfo_sync_txdata_valid:   out std_logic;
      sync_sieint_rx_nbytes:      in  std_logic_vector(11 downto 0);
      sync_sieint_rxdata:         in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
      sync_sieint_rxdatavalid:    in  std_logic;
      sync_sieint_endtransfer:    in  std_logic;
      sync_sieint_success:        in  std_logic;
      sync_sieint_sentNAK:        in  std_logic;
      sync_busreset:              in  std_logic;
      dma_ahb_selected:           out std_logic;
      usbreg_setup:               in  std_logic;
      pie_speed:                  in  std_logic_vector( 1 downto      0);
      usbreg_ep_list_start:       in  std_logic_vector(31 downto      8);
      usbreg_ep_skip_list_start:  in  std_logic_vector(31 downto 8);
      usbreg_data_buffer_start:   in  std_logic_vector(31 downto C_DALB);
      usbreg_ep_bufinuse:         in  std_logic_vector(C_NBPHYSEP+1 downto 0);
      usbreg_ep_skip:             in  std_logic_vector(C_NBPHYSEP+1 downto 0);
      --dma_epinfo_toggle:          out std_logic_vector(C_NBPHYSEP+1 downto 0);
      usbreg_epinfo_toggle:       in  std_logic_vector(C_NBPHYSEP+1 downto 0);
      dma_clear_toggle:           out std_logic;
      dma_set_toggle:             out std_logic;
      dma_sent_NAK:               out std_logic;
      dma_set_int:                out std_logic;
      dma_physepnr:               out integer range 0 to C_NBPHYSEP+1;
      dma_clear_skip:             out std_logic;
      dma_skip_ep:                out integer range 0 to C_NBPHYSEP+1;
      usb_dma_fpga              : out std_logic_vector(63 downto 0)
     );
  end component;

component usb_ahb_slave
  port    (
    	  hclk  	    : in    std_logic;
    	  hresetn	    : in    std_logic;
    	  haddr 	    : in    std_logic_vector(5 downto 2);
    	  hwrite	    : in    std_logic;
    	  hsel  	    : in    std_logic;
    	  htrans1	    : in    std_logic;
    	  hwdata	    : in    std_logic_vector(31 downto 0);
    	  hrdata	    : out   std_logic_vector(31 downto 0);
    	  hresp 	    : out   std_logic_vector(1 downto 0);
    	  hready	    : out   std_logic;
    	  hready_glb	    : in    std_logic;
    	  reg_waddr	    : out   std_logic_vector(3 downto 0);
    	  reg_wdata	    : out   std_logic_vector(31 downto 0);
    	  reg_raddr	    : out   std_logic_vector(3 downto 0);
    	  reg_rdata	    : in    std_logic_vector(31 downto 0);
    	  reg_write	    : out   std_logic
          );
end component;

--component usb_tx_sf_dpdm
--  port    (
--	  SIE_TxLogValue: in T_UsbLog_enum;
--	  UP_DP:          out one_bit;
--	  UP_DM:          out one_bit;
--	  UP_FSE0:        out one_bit
--	  );
--end component;


--signal CR_UsbLineBits: two_bits;
--signal MM_Accepted: boolean;
--signal MM_EndpSearchReady: boolean;
--signal MM_EndpSearchSelected: boolean;
--signal MM_ISO: boolean;
--signal MM_NeedClock: boolean;
--signal MM_Resume: boolean;
--signal MM_Stalled: boolean;
--signal MM_TxData: S_UsbWord_bits;
--signal MM_TxData1Pid: boolean;
--signal MM_TxDataRdy: boolean;
--signal PUReset_N: one_bit;
--signal RG_BusActive: boolean;
--signal RG_SetSE0Int: boolean;
signal RG_BUSReset : boolean;
--signal Reset48MHz_N: one_bit;
signal Reset_N: one_bit;
--signal SH_Configured: boolean;
--signal SH_Succes: boolean;
--signal SIE_CREnable: boolean;
--signal SIE_RxData: S_UsbWord_bits;
--signal SIE_RxDataRdy: boolean;
--signal SIE_RxEOP: boolean;
--signal SIE_RxError: boolean;
--signal SIE_RxErrorType: T_PACKET_ERROR_enum;
--signal SIE_RxPid: T_Pid_enum;
--signal SIE_RxPidRdy: boolean;
--signal SIE_RxSOF: boolean;
--signal SIE_SOFByte1: boolean;
--signal SIE_SOFByte2: boolean;
--signal SIE_StartEndpSearch: boolean;
--signal SIE_TxDataAck: boolean;
--signal TM_1kHzPulse: one_bit;
--signal TM_SendResume: boolean;
signal TM_Suspend: boolean;
signal TM_IsoToggle: integer range 0 to 1;

signal reg_waddr : std_logic_vector( 3 downto 0);
signal reg_wdata : std_logic_vector(31 downto 0);
signal reg_raddr : std_logic_vector( 3 downto 0);
signal reg_rdata : std_logic_vector(31 downto 0);
signal reg_write : std_logic;

--signal HB_UsbLineBits  : two_bits;
--signal PU_Reset_N      : std_logic;
--signal SIE_TxLogValue  : T_UsbLog_enum;
--signal SIE_RxSubPid    : T_SubPid_enum;
--signal SIE_LPM_HIRDRdy : boolean;
--signal SIE_LPM_RWRdy   : boolean;
--signal MM_LPMSupported : boolean;
--signal MM_LPMNYET      : boolean;
--signal LPM_MM_Resume    : boolean;
signal LPM_RW           : boolean;
--signal LPM_NYET         : boolean;
--signal LPM_HIRD_HW      : four_bits;
--signal LPM_HIRD_Rdy     : boolean;
--signal LPM_LINK_STATE_EN: boolean;
--signal LPM_HostRetry_Reset: boolean;
signal sieint_epinfo_req:      std_logic;
signal sieint_epinfo_epnr:     std_logic_vector(3 downto 0);
signal sieint_epinfo_epdir:    std_logic;
signal sieint_epinfo_setup:    std_logic;
signal sieint_epinfo_setup_received:    std_logic;
signal epinfo_valid:	       std_logic;
signal epinfo_active:	       std_logic;
signal epinfo_disabled:        std_logic;
signal epinfo_toggle:	       std_logic;
signal epinfo_stall:	       std_logic;
signal epinfo_iso:	       std_logic;
--signal epinfo_ratefeedbackmode: std_logic;
signal epinfo_nbytes:	       std_logic_vector(14 downto 0);
signal epinfo_maxpacket:       std_logic_vector(1 downto 0);
signal sieint_txdatafetched:   std_logic;
signal epinfo_txdata:	       std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
signal epinfo_txdata_valid:    std_logic;
signal sieint_rx_nbytes:       std_logic_vector(11 downto 0);
signal sieint_rxdata:	       std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
signal sieint_rxdatavalid:     std_logic;
signal sieint_endtransfer:     std_logic;
signal sieint_success:         std_logic;
signal sieint_error:	       std_logic;
signal sieint_errortype:       std_logic_vector(3 downto 0);
signal sieint_sentNAK:         std_logic;
--signal sieint_vbusvalid:       std_logic;
signal sync_sieint_epinfo_req:   std_logic;
signal sync_sieint_epinfo_epnr:  std_logic_vector(3 downto 0);
signal sync_sieint_epinfo_epdir: std_logic;
signal sync_sieint_epinfo_setup: std_logic;
signal epinfo_sync_valid:	    std_logic;
signal epinfo_sync_active:	    std_logic;
signal epinfo_sync_disabled:	    std_logic;
signal epinfo_sync_toggle:	    std_logic;
signal epinfo_sync_stall:	    std_logic;
signal epinfo_sync_iso: 	    std_logic;
signal epinfo_sync_ratefeedbackmode:std_logic;
signal epinfo_sync_nbytes:	    std_logic_vector(14 downto 0);
signal epinfo_sync_maxpacket:       std_logic_vector(1 downto 0);
signal sync_sieint_txdatafetched:   std_logic;
signal epinfo_sync_txdata:	    std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
signal epinfo_sync_txdata_valid:    std_logic;
signal sync_sieint_rx_nbytes:	    std_logic_vector(11 downto 0);
signal sync_sieint_rxdata:	    std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
signal sync_sieint_rxdatavalid:     std_logic;
signal sync_sieint_endtransfer:     std_logic;
signal sync_sieint_success:	    std_logic;
signal sync_sieint_error:	    std_logic;
signal sync_sieint_errortype:	    std_logic_vector(3 downto 0);
signal sync_sieint_sentNAK:	    std_logic;
--signal sync_sieint_vbusvalid    : std_logic;
signal sync_busreset            : std_logic;
signal sync_suspend             : std_logic;
signal sync_lpm_suspend         : std_logic;
signal sync_lpm_rw              : std_logic;
signal usbreg_lpm_sup		: std_logic;
signal usbreg_dev_connect	: std_logic;
signal usbreg_ep_list_start	: std_logic_vector(31 downto 0);
signal usbreg_data_buffer_start : std_logic_vector(31 downto 0);
signal usbreg_lpm_hird_sw	: std_logic_vector( 3 downto 0);
signal sieint_lpm_hird_hw	: std_logic_vector( 3 downto 0);
signal usbreg_lpm_nyet          : std_logic;
signal usbreg_ep_skip		: std_logic_vector(C_NBPHYSEP+1 downto 0);
signal usbreg_ep_bufinuse       : std_logic_vector(C_NBPHYSEP+1 downto 0);
signal usbreg_pll_on:	       std_logic;
--signal usbreg_deviceenabled:   std_logic;
signal usbreg_deviceenabled:   std_logic_vector(C_NBDEV-1 downto 0);
signal usbreg_remotewakeup:    std_logic;
signal usbreg_lpmremotewakeup: std_logic;
signal usbreg_frame_number:    std_logic_vector(10 downto 0);
signal sieint_usbaddress     : std_logic_vector(6 downto 0);
signal usbreg_usbaddress:      std_logic_vector(6 downto 0);
signal usbreg_usbaddress_tmp:  std_logic_vector(6 downto 0);
signal usbreg_setup :          std_logic;
signal pie_speed :             std_logic_vector(1 downto 0);
signal usbreg_phy_test_mode   : std_logic_vector(2 downto 0);
--signal usbreg_select_ext_clk : std_logic;
signal sync_sieint_setup_received:  std_logic;
--signal dma_epinfo_toggle:      std_logic_vector(C_NBPHYSEP+1 downto 0);
signal usbreg_epinfo_toggle  : std_logic_vector(C_NBPHYSEP+1 downto 0);

-- ----------------------------------------------------------------------------
-- OCP Recovery v1.1 (Section 8.5) arbiter internal nets.
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- Post-synchronizer arbiter interposition nets (hclk domain).
--   *_s : synchronizer hclk-side outputs feeding the arbiter (_i inputs).
--   *_d : usb_dma epinfo_sync_* outputs feeding the arbiter (_dma inputs).
-- The arbiter drives the existing downstream sync_sieint_*/epinfo_sync_*
-- signals so the usb_dma / usb_reg_if / synchronizer-input port maps are
-- unchanged.
-- ----------------------------------------------------------------------------
signal sync_sieint_epinfo_req_s    : std_logic;
signal sync_sieint_epinfo_epnr_s   : std_logic_vector(3 downto 0);
signal sync_sieint_epinfo_epdir_s  : std_logic;
signal sync_sieint_epinfo_setup_s  : std_logic;
signal sync_sieint_setup_received_s: std_logic;
signal sync_sieint_rx_nbytes_s     : std_logic_vector(11 downto 0);
signal sync_sieint_rxdata_s        : std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
signal sync_sieint_rxdatavalid_s   : std_logic;
signal sync_sieint_endtransfer_s   : std_logic;
signal sync_sieint_success_s       : std_logic;
signal sync_sieint_error_s         : std_logic;
signal sync_sieint_errortype_s     : std_logic_vector(3 downto 0);
signal sync_sieint_sentNAK_s       : std_logic;
signal sync_sieint_txdatafetched_s : std_logic;

signal epinfo_sync_valid_d            : std_logic;
signal epinfo_sync_active_d           : std_logic;
signal epinfo_sync_disabled_d         : std_logic;
signal epinfo_sync_toggle_d           : std_logic;
signal epinfo_sync_stall_d            : std_logic;
signal epinfo_sync_iso_d              : std_logic;
signal epinfo_sync_ratefeedbackmode_d : std_logic;
signal epinfo_sync_nbytes_d           : std_logic_vector(14 downto 0);
signal epinfo_sync_maxpacket_d        : std_logic_vector(1 downto 0);
signal epinfo_sync_txdata_d           : std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
signal epinfo_sync_txdata_valid_d     : std_logic;

signal usbreg_port_force_fullspeed : std_logic;
signal dma_clear_toggle      : std_logic;
signal dma_set_toggle        : std_logic;
signal dma_sent_NAK          : std_logic;
signal dma_set_int           : std_logic;
signal dma_physepnr          : integer range 0 to C_NBPHYSEP+1;
--signal Configured_LED:         one_bit;
--signal lowpurenable:           boolean;
--signal VBusAvailable:          boolean;
--signal TM_ClockOn:             one_bit;
signal LPM_TM_Suspend:         boolean;
signal sync_set_frameint:       std_logic;
signal dma_clear_skip:          std_logic;
signal dma_skip_ep:             integer range 0 to C_NBPHYSEP+1;
signal sync_s_reset_n:         std_logic;
signal sync_ss_reset_n:        std_logic;

signal pie_isotoggle:          std_logic;
signal pie_suspend:            std_logic;
signal pie_lpm_suspend:        std_logic;
signal pie_lpm_remotewake_enable: std_logic;
signal pie_devicespeed:        std_logic;
signal pie_busreset:        std_logic;
signal usb_pie_fpga : std_logic_vector(63 downto 0);
signal zero : one_bit;

signal usbreg_phy_addr  	: std_logic_vector(7 downto 0);
signal usbreg_phy_wdata 	: std_logic_vector(7 downto 0);
signal sync_phy_rdata		: std_logic_vector(7 downto 0);
signal usbreg_phy_write 	: std_logic;
signal usbreg_phy_start 	: std_logic;
signal usbreg_phy_mode  	: std_logic;
signal sync_phy_endtoggle	: std_logic;
signal phy_addr  	        : std_logic_vector(7 downto 0);
signal phy_wdata 	        : std_logic_vector(7 downto 0);
signal phy_rdata		: std_logic_vector(7 downto 0);
signal phy_write 	        : std_logic;
signal phy_start 	        : std_logic;
signal phy_mode  	        : std_logic;
signal phy_endtoggle	        : std_logic;

signal reset_needed             : std_logic;
signal reset_needed_z           : std_logic;
signal reset_needed_zz          : std_logic;
signal reset_done               : std_logic;
signal reset_done_z             : std_logic;
signal reset_done_zz            : std_logic;
signal atx_reset_core           : std_logic;
signal clk_counter_atx_core     : integer range 0 to RESET_CYCLE;
signal utmi_clk_ok              : std_logic;
signal pie_lowpower_n            : std_logic;
signal clock_on                 : std_logic;
--below required for the clock_on multi cycle path on clock_on when it is connected to  ip_xxx_3511_hs_mem_fpga
-- synthesis read_comments_as_HDL on
-- attribute keep: boolean;
-- attribute keep of clock_on: signal is true;
-- synthesis read_comments_as_HDL off

signal VBusDebounced            : std_logic;
signal dp_s                     : std_logic;
signal dm_s                     : std_logic;
constant CLOCKOFF_CYCLE         : integer := 255;
signal clk_off_counter          : integer range 0 to CLOCKOFF_CYCLE;

--signal one  : one_bit;
signal zero7 : std_logic_vector(6 downto 0);
--signal zero8 : std_logic_vector(7 downto 0);

signal usb_dma_fpga : std_logic_vector(63 downto 0);
signal usb_reg_if_fpga : std_logic_vector(63 downto 0);

signal pie_clk                  : std_logic; -- UTMI/ULPI clock
subtype S_DebounceTimer is integer range 0 to VBUS_DEBOUNCE_TIME;
signal DebounceTimer: S_DebounceTimer;
signal pie_isotoggle_r : std_logic;
signal sync_VBusDebounced : std_logic;
signal pie_vbusvalid: std_logic;
signal pie_vbusvalid_r: std_logic;
--signal VBusDebounced_int         : boolean;
--signal vbusontimer : integer range 0 to 2;
signal usb_needclk_int : std_logic;
signal dp, dm: std_logic;
signal ulpi_pwrctrl_wakeup: std_logic;
signal ulpi_dir_s: std_logic;
signal ulpi_dir_ss: std_logic;
signal ulpi_dir_sss: std_logic;
signal ulpi_nxt_s: std_logic;
signal ulpi_nxt_ss: std_logic;
signal ulpi_nxt_sss: std_logic;
signal ulpi_linestate_lp: std_logic_vector (1 downto 0);
signal ulpi_int_lp : std_logic;
signal dataline_low_power_en : std_logic;
constant CLOCK_COUNTER_AHB_MAX         : integer := 63; -- This allows an AHB clock frequency of maximum 480MHz
signal clock_counter_ahb: integer range 0 to CLOCK_COUNTER_AHB_MAX;
constant CLOCK_COUNTER_USB_MAX         : integer := 15;
signal clock_counter_usb : integer range 0 to CLOCK_COUNTER_USB_MAX;
signal clock_counter_usb_msb,clock_counter_usb_msb_z,clock_counter_usb_msb_zz : std_logic;

signal init_phy_reset : std_logic;
signal pwrctrl_wakeup_int : std_logic;
signal awake: std_logic;

signal sync_usbreg_phy_test_mode_change: std_logic;
signal sync_usbreg_dev_connect : std_logic;
signal sync_usbreg_remotewakeup: std_logic;
signal sync_usbreg_lpmremotewakeup: std_logic;

signal sync_avalid : std_logic;
signal sync_sessend : std_logic;
signal usbreg_vbuscomp_on : std_logic;
signal usbreg_chrg_vbus   : std_logic;
signal usbreg_dischrg_vbus:  std_logic;
signal vbuscomp_on_int : std_logic;

signal utmi_clk_ok_clr_n            : std_logic;
signal utmi_clk_ok_clr_n_q          : std_logic;
signal utmi_clk_ok_clr_n_dft        : std_logic;

signal pwrctrl_wakeup_int_set_n     : std_logic;
signal pwrctrl_wakeup_int_set_n_q   : std_logic;
signal pwrctrl_wakeup_int_set_n_dft : std_logic;

begin

--PU_Reset_N           <= hresetn;

--VBusAvailable        <= (USB_VBus = '1');

vbuscomp_on <= vbuscomp_on_int;

zero  <= '0';
zero7 <= (others => '0');
--zero8 <= (others => '0');

--one   <= '1';

pie_speed <= "01" when pie_devicespeed = '0' else "10";

-- TODO : make sure USB_FrameToggle is 1kHz clock.
USB_FrameToggle <= pie_isotoggle;

TM_IsoToggle   <= 1 when pie_isotoggle = '1' else 0;
TM_suspend     <= (pie_suspend = '1');
LPM_TM_suspend <= (pie_lpm_suspend = '1');
LPM_RW         <= (pie_lpm_remotewake_enable = '1');
RG_busreset    <= (pie_busreset = '1');

usb_pie_1 : usb_pie
    generic map(ULPI_SUPPORT      => C_ULPI_SUPPORT,
                UTMI_SUPPORT      => C_UTMI_SUPPORT,
		USB_DATAWIDTH     => USBPIE_DATAWIDTH,
                C_NBDEV           => 1,
		C_NBPHYSEP        => C_NBPHYSEP,
		C_EXTEND_TX_DELAY   => C_EXTEND_TX_DELAY,
		G_SIM_CHIRP_TIMERS  => G_SIM_CHIRP_TIMERS
		)
    port map   (
	       pie_epinfo_req		    => sieint_epinfo_req	   ,
	       pie_epinfo_epnr  	    => sieint_epinfo_epnr	   ,
	       pie_epinfo_epdir 	    => sieint_epinfo_epdir	   ,
	       pie_epinfo_setup 	    => sieint_epinfo_setup	   ,
	       pie_epinfo_setup_received    => sieint_epinfo_setup_received,
	       pie_usbaddress		    => sieint_usbaddress	   ,
	       epinfo_valid		    => epinfo_valid		   ,
	       epinfo_active		    => epinfo_active		   ,
	       epinfo_disabled  	    => epinfo_disabled  	   ,
	       epinfo_toggle		    => epinfo_toggle		   ,
	       epinfo_stall		    => epinfo_stall		   ,
	       epinfo_iso		    => epinfo_iso		   ,
	       epinfo_nbytes		    => epinfo_nbytes		   ,
	       epinfo_maxpacket             => epinfo_maxpacket            ,
	       pie_txdata_fetched	    => sieint_txdatafetched	   ,
	       epinfo_txdata		    => epinfo_txdata		   ,
               epinfo_txdata_valid	    => epinfo_txdata_valid	   ,
               pie_rx_nbytes		    => sieint_rx_nbytes 	   ,
               pie_rxdata		    => sieint_rxdata		   ,
               pie_rxdatavalid  	    => sieint_rxdatavalid	   ,
               pie_endtransfer  	    => sieint_endtransfer	   ,
	       pie_success		    => sieint_success		   ,
	       pie_error		    => sieint_error		   ,
	       pie_errortype		    => sieint_errortype 	   ,
               pie_sentNAK		    => sieint_sentNAK		   ,
               pie_isotoggle		    => pie_isotoggle 	           ,
	       pie_busreset		    => pie_busreset       	   ,
	       pie_devicespeed  	    => pie_devicespeed	           ,
	       pie_suspend		    => pie_suspend		   ,
	       pie_lpm_suspend  	    => pie_lpm_suspend	           ,
               pie_lpm_remotewake_enable    => pie_lpm_remotewake_enable   ,
               pie_lpm_hird_hw              => sieint_lpm_hird_hw          ,
               pie_vbusvalid                => pie_vbusvalid               ,
               pie_lowpower_n		    => pie_lowpower_n               ,
               reset_n  		    => Reset_N  		   ,
               pie_clk                      => pie_clk                     ,

               phy_address                  => phy_addr                    ,
	       phy_readdata                 => phy_rdata                   ,
	       phy_writedata                => phy_wdata                   ,
	       phy_write                    => phy_write                   ,
	       phy_start                    => phy_start                   ,
	       phy_endtoggle                => phy_endtoggle               ,
               phy_mode                     => phy_mode                    ,
               sync_usbreg_phy_test_mode_change  => sync_usbreg_phy_test_mode_change ,
               sync_usbreg_remotewakeup     => sync_usbreg_remotewakeup ,
               sync_usbreg_lpmremotewakeup     => sync_usbreg_lpmremotewakeup ,

               usbreg_pll_on		    => usbreg_pll_on		   ,
	       usbreg_deviceenabled	    => usbreg_deviceenabled	   ,
	       usbreg_dev_connect           => sync_usbreg_dev_connect          ,
	       usbreg_remotewakeup	    => usbreg_remotewakeup	   ,
	       usbreg_lpm_sup		    => usbreg_lpm_sup		   ,
	       usbreg_lpmremotewakeup	    => usbreg_lpmremotewakeup	   ,
	       usbreg_lpm_hird_sw           => usbreg_lpm_hird_sw          ,
               usbreg_lpm_nyet              => usbreg_lpm_nyet             ,
	       usbreg_frame_number	    => usbreg_frame_number	   ,
	       usbreg_usbaddress	    => usbreg_usbaddress	   ,
	       usbreg_usbaddress_tmp	    => usbreg_usbaddress_tmp	   ,
               usbreg_phy_test_mode	    => usbreg_phy_test_mode	   ,
               usbreg_port_force_fullspeed  => usbreg_port_force_fullspeed ,
	       token_length_counter         => token_length_counter        ,
	       usb_token_length             => usb_token_length            ,
               utmi_vcontrol                => utmi_vcontrol               ,
	       utmi_vcontrolloadm           => utmi_vcontrolloadm          ,
               utmi_vstatus                 => utmi_vstatus                ,
               --utmi_clk                   => utmi_clk,
	       utmi_rxdata		    => utmi_rxdata		   ,
	       utmi_rxvalid		    => utmi_rxvalid		   ,
	       utmi_rxactive		    => utmi_rxactive		   ,
	       utmi_rxerror		    => utmi_rxerror		   ,
	       utmi_txdata		    => utmi_txdata		   ,
	       utmi_txvalid		    => utmi_txvalid		   ,
	       utmi_txready		    => utmi_txready		   ,
	       utmi_reset		    => open      		   ,
	       utmi_xcvrselect  	    => utmi_xcvrselect  	   ,
	       utmi_termselect  	    => utmi_termselect  	   ,
	       utmi_opmode		    => utmi_opmode		   ,
               utmi_linestate		    => utmi_linestate		   ,
               utmi_vbusvalid               => USB_VBus                    ,

               --ulpi_clk                     => ulpi_clk                    ,
	       ulpi_rxdata                  => ulpi_rxdata                 ,
	       ulpi_txdata                  => ulpi_txdata                 ,
	       ulpi_txenable                => ulpi_txenable               ,
	       ulpi_dir                     => ulpi_dir                    ,
	       ulpi_stp                     => ulpi_stp                ,
               ulpi_nxt                     => ulpi_nxt                    ,
               ulpi_pwrctrl_wakeup          => ulpi_pwrctrl_wakeup         ,

               VBusDebounced                => VBusDebounced,
               pie_dev_selected             => open,

	       usb_pie_fpga                 => usb_pie_fpga,
               INTER_PACKET_DELAY_FS_param  => usb_pie_INTER_PACKET_DELAY_FS_param,
               INTER_PACKET_DELAY_HS_param  => usb_pie_INTER_PACKET_DELAY_HS_param,
               PACKET_TURNAROUND_TIMEOUT_FS_param => usb_pie_PACKET_TURNAROUND_TIMEOUT_FS_param,
               PACKET_TURNAROUND_TIMEOUT_HS_param => usb_pie_PACKET_TURNAROUND_TIMEOUT_HS_param,
               PACKET_EVENT_TIMEOUT_FS_param => usb_pie_PACKET_EVENT_TIMEOUT_FS_param,
               PACKET_EVENT_TIMEOUT_HS_param => usb_pie_PACKET_EVENT_TIMEOUT_HS_param

	       );


usb_synchronizer_1: usb_synchronizer
  generic map (C_UTMI_SUPPORT   => C_UTMI_SUPPORT,
	       C_ULPI_SUPPORT   => C_ULPI_SUPPORT,
               USB_DATAWIDTH    => USBPIE_DATAWIDTH,
               TXNBYTES_BITS    => 15,
               RXNBYTES_BITS    => 12,
               C_NBDEV          => 1)
  port map    (
	      sieint_epinfo_req	  	   => sieint_epinfo_req 	  ,
	      sieint_epinfo_epnr	   => sieint_epinfo_epnr	  ,
	      sieint_epinfo_epdir	   => sieint_epinfo_epdir	  ,
	      sieint_epinfo_setup	   => sieint_epinfo_setup	  ,
	      sieint_epinfo_setup_received => sieint_epinfo_setup_received,
	      epinfo_valid		   => epinfo_valid		  ,
	      epinfo_active		   => epinfo_active		  ,
	      epinfo_disabled  	  	   => epinfo_disabled		  ,
	      epinfo_toggle		   => epinfo_toggle		  ,
	      epinfo_stall		   => epinfo_stall		  ,
	      epinfo_iso		   => epinfo_iso		  ,
	      epinfo_ratefeedbackmode      => open               	  ,
	      epinfo_nbytes		   => epinfo_nbytes		  ,
	      epinfo_maxpacket             => epinfo_maxpacket            ,
	      sieint_txdatafetched	   => sieint_txdatafetched	  ,
	      epinfo_txdata		   => epinfo_txdata		  ,
	      epinfo_txdata_valid	   => epinfo_txdata_valid	  ,
	      sieint_rx_nbytes 	  	   => sieint_rx_nbytes  	  ,
              sieint_rxdata		   => sieint_rxdata		  ,
              sieint_rxdatavalid	   => sieint_rxdatavalid	  ,
              sieint_endtransfer	   => sieint_endtransfer	  ,
              sieint_success		   => sieint_success		  ,
              sieint_error		   => sieint_error		  ,
              sieint_errortype	  	   => sieint_errortype  	  ,
              sieint_sentNAK		   => sieint_sentNAK		  ,
              VBusDebounced                => VBusDebounced            ,
              pie_lowpower_n               => pie_lowpower_n,
              vbuscomp_on                  => vbuscomp_on_int,
              chrg_vbus                    => chrg_vbus,
              dischrg_vbus                 => dischrg_vbus,
	      avalid                       => avalid,
              sessend                      => sessend,
              TM_IsoToggle                 => TM_IsoToggle                ,
              RG_BUSReset                  => RG_BUSReset                 ,
              TM_Suspend                   => TM_Suspend                  ,
              LPM_TM_Suspend               => LPM_TM_Suspend              ,
              LPM_RW                       => LPM_RW                      ,
	      phy_addr			   => phy_addr  		  ,
              phy_wdata 		   => phy_wdata 		  ,
              phy_rdata 		   => phy_rdata 		  ,
              phy_write 		   => phy_write 		  ,
              phy_start 		   => phy_start 		  ,
              phy_mode			   => phy_mode  		  ,
              phy_endtoggle		   => phy_endtoggle		  ,
              sync_usbreg_phy_test_mode_change  => sync_usbreg_phy_test_mode_change ,
              sync_usbreg_dev_connect      => sync_usbreg_dev_connect ,
              sync_usbreg_remotewakeup     => sync_usbreg_remotewakeup ,
              sync_usbreg_lpmremotewakeup     => sync_usbreg_lpmremotewakeup ,

              -- connected directly in top level 
              sync_usbreg_pll_on      => open,
              sync_usbreg_lpm_sup     => open,
              sync_usbreg_lpm_hird_sw => open,
              sync_usbreg_lpm_nyet    => open,
              pie_speed               => (others => '0'),
              sieint_lpm_hird_hw      => (others => '0'),
              usbreg_frame_number     => (others => '0'),
              pie_dev_selected        => 0,
              usbreg_pll_on           => '0',
              usbreg_lpm_sup          => '0',
              usbreg_lpm_hird_sw      => (others => '0'),
              usbreg_lpm_nyet         => '0',
              sync_pie_speed          => open,
              sync_sieint_lpm_hird_hw => open,
              sync_usbreg_frame_number=> open,
              sync_pie_dev_selected   => open,

	      sync_sieint_epinfo_req	   => sync_sieint_epinfo_req_s    ,
	      sync_sieint_epinfo_epnr      => sync_sieint_epinfo_epnr_s	  ,
	      sync_sieint_epinfo_epdir     => sync_sieint_epinfo_epdir_s  ,
	      sync_sieint_epinfo_setup     => sync_sieint_epinfo_setup_s  ,
              sync_sieint_setup_received   => sync_sieint_setup_received_s,
              sync_VBusDebounced           => sync_VBusDebounced          ,
              usbreg_vbuscomp_on           => usbreg_vbuscomp_on,
              usbreg_chrg_vbus             => usbreg_chrg_vbus            ,
              usbreg_dischrg_vbus          => usbreg_dischrg_vbus         ,
	      sync_avalid                  => sync_avalid,
              sync_sessend                 => sync_sessend,
	      epinfo_sync_valid	  	   => epinfo_sync_valid 	  ,
	      epinfo_sync_active	   => epinfo_sync_active	  ,
	      epinfo_sync_disabled	   => epinfo_sync_disabled	  ,
	      epinfo_sync_toggle	   => epinfo_sync_toggle	  ,
	      epinfo_sync_stall	  	   => epinfo_sync_stall 	  ,
	      epinfo_sync_iso  	  	   => epinfo_sync_iso		  ,
	      epinfo_sync_ratefeedbackmode => epinfo_sync_ratefeedbackmode,
	      epinfo_sync_nbytes	   => epinfo_sync_nbytes	  ,
	      epinfo_sync_maxpacket        => epinfo_sync_maxpacket       ,
	      sync_sieint_txdatafetched    => sync_sieint_txdatafetched_s ,
	      epinfo_sync_txdata	   => epinfo_sync_txdata	  ,
	      epinfo_sync_txdata_valid     => epinfo_sync_txdata_valid    ,
	      sync_sieint_rx_nbytes	   => sync_sieint_rx_nbytes_s	  ,
              sync_sieint_rxdata	   => sync_sieint_rxdata_s	  ,
              sync_sieint_rxdatavalid      => sync_sieint_rxdatavalid_s	  ,
              sync_sieint_endtransfer      => sync_sieint_endtransfer_s	  ,
              sync_sieint_success	   => sync_sieint_success_s	  ,
              sync_sieint_error	  	   => sync_sieint_error_s 	  ,
              sync_sieint_errortype	   => sync_sieint_errortype_s	  ,
              sync_sieint_sentNAK	   => sync_sieint_sentNAK_s	  ,
              --sync_sieint_vbusvalid	   => sync_sieint_vbusvalid	  ,
              sync_set_frameint            => sync_set_frameint           ,
              sync_busreset                => sync_busreset               ,
              sync_suspend                 => sync_suspend	          ,
              sync_lpm_suspend             => sync_lpm_suspend	          ,
              sync_lpm_rw                  => sync_lpm_rw                 ,
	      usbreg_phy_addr		   => usbreg_phy_addr	  	  ,
              usbreg_phy_wdata		   => usbreg_phy_wdata    	  ,
              sync_phy_rdata    	   => sync_phy_rdata	  	  ,
              usbreg_phy_write		   => usbreg_phy_write    	  ,
              usbreg_phy_start		   => usbreg_phy_start    	  ,
              usbreg_phy_mode		   => usbreg_phy_mode	  	  ,
              sync_phy_endtoggle	   => sync_phy_endtoggle          ,
              usbreg_phy_test_mode         => usbreg_phy_test_mode        ,
              usbreg_dev_connect           => usbreg_dev_connect          ,
              usbreg_remotewakeup          => usbreg_remotewakeup         ,
              usbreg_lpmremotewakeup          => usbreg_lpmremotewakeup         ,
	      FsClk			   => pie_clk   	          ,
	      Reset_N 		  	   => Reset_N			  ,
	      hclk			   => hclk			  ,
	      hrstn			   => hresetn
	      );

usb_reg_if_1 : usb_reg_if
  generic map (C_UTMI_SUPPORT            => C_UTMI_SUPPORT           ,
               C_ULPI_SUPPORT            => C_ULPI_SUPPORT           ,
               C_NBPHYSEP                => C_NBPHYSEP               ,
               C_EPUB			 => C_EPUB		     ,
               C_DAUB			 => C_DAUB		     ,
               C_DALB			 => C_DALB		     ,
               C_EPFIFO_PAGE  		 => C_EPFIFO_PAGE	     ,
               C_DATAFIFO_PAGE		 => C_DATAFIFO_PAGE	     ,
               C_SINGLE_BUFFER_SUPPORTED => C_SINGLE_BUFFER_SUPPORTED,
               C_DOUBLE_BUFFER_SUPPORTED => C_DOUBLE_BUFFER_SUPPORTED,
               C_TOGGLE_REG_READABLE	 => C_TOGGLE_REG_READABLE    ,
               C_PLL_ENABLE              => C_PLL_ENABLE	     ,
               C_PLL_DIVIDER             => C_PLL_DIVIDER	     ,
	       C_MINOR_REV               => C_MINOR_REV 	     ,
               C_MAJOR_REV               => C_MAJOR_REV 	     )
  port map    (
              hclk		         => hclk		    ,
              hresetn		         => hresetn		    ,
              USB_Int_Req_Irq            => USB_Int_Req_Irq         ,
              USB_Int_Req_Fiq            => USB_Int_Req_Fiq         ,
              reg_waddr 	         => reg_waddr		    ,
              reg_wdata 	         => reg_wdata		    ,
              reg_raddr 	         => reg_raddr		    ,
              reg_rdata 	         => reg_rdata		    ,
              reg_write 	         => reg_write		    ,
              sieint_usbaddress          => sieint_usbaddress	    ,
              usbreg_usbaddress          => usbreg_usbaddress	    ,
              usbreg_usbaddress_tmp      => usbreg_usbaddress_tmp   ,
              usbreg_deviceenabled       => usbreg_deviceenabled(0) ,
              usbreg_setup	         => usbreg_setup	    ,
              sieint_setup_received      => sync_sieint_setup_received   ,
              usbreg_pll_on	         => usbreg_pll_on	    ,
              usbreg_lpm_sup	         => usbreg_lpm_sup	    ,
              usbreg_remotewakeup        => usbreg_remotewakeup     ,
              usbreg_lpmremotewakeup     => usbreg_lpmremotewakeup  ,
              usbreg_dev_connect         => usbreg_dev_connect      ,
              usbreg_frame_number        => usbreg_frame_number     ,
              usbreg_ep_list_start       => usbreg_ep_list_start    ,
              usbreg_data_buffer_start   => usbreg_data_buffer_start,
              usbreg_lpm_hird_sw         => usbreg_lpm_hird_sw      ,
              sieint_lpm_hird_hw         => sieint_lpm_hird_hw      ,
              usbreg_lpm_nyet            => usbreg_lpm_nyet         ,
              usbreg_ep_skip	         => usbreg_ep_skip	    ,
              usbreg_ep_bufinuse         => usbreg_ep_bufinuse      ,
              usbreg_select_ext_clk      => open   ,--usbreg_select_ext_clk
              --dma_epinfo_toggle          => dma_epinfo_toggle,
              usbreg_port_force_fullspeed => usbreg_port_force_fullspeed,
              usbreg_epinfo_toggle       => usbreg_epinfo_toggle,
              dma_clear_toggle           => dma_clear_toggle,
              dma_set_toggle             => dma_set_toggle,
              dma_sent_NAK	         => dma_sent_NAK	    ,
              dma_set_int	         => dma_set_int 	    ,
              dma_physepnr	         => dma_physepnr	    ,
              dma_clear_skip             => dma_clear_skip          ,
              dma_skip_ep                => dma_skip_ep             ,
             -- VBusAvailable              => sync_sieint_vbusvalid   ,
              sync_busreset              => sync_busreset           ,
              sync_suspend               => sync_suspend            ,
              sync_lpm_suspend           => sync_lpm_suspend        ,
              sync_lpm_rw                => sync_lpm_rw             ,
              sync_sieint_error	  	 => sync_sieint_error	    ,
              sync_sieint_errortype	 => sync_sieint_errortype   ,
              sync_set_frameint          => sync_set_frameint       ,
	      usbreg_phy_test_mode       => usbreg_phy_test_mode    ,
              pie_speed	                 => pie_speed               ,
	      sync_VBusDebounced         => sync_VBusDebounced      ,
	      usbreg_vbuscomp_on         => usbreg_vbuscomp_on,
	      usbreg_chrg_vbus           => usbreg_chrg_vbus            ,
	      usbreg_dischrg_vbus        => usbreg_dischrg_vbus         ,
	      sync_avalid                => sync_avalid,
              sync_sessend               => sync_sessend,
              usbreg_phy_addr 	         => usbreg_phy_addr	    ,
              usbreg_phy_wdata	 	 => usbreg_phy_wdata	    ,
              sync_phy_rdata  	 	 => sync_phy_rdata	    ,
              usbreg_phy_write	 	 => usbreg_phy_write	    ,
              usbreg_phy_start	 	 => usbreg_phy_start	    ,
              usbreg_phy_mode 	 	 => usbreg_phy_mode	    ,
              sync_phy_endtoggle	 => sync_phy_endtoggle,
	      usb_reg_if_fpga => usb_reg_if_fpga
             );

--LPM_NYET <= (usbreg_lpm_nyet = '1');

usb_dma_1 : usb_dma
  generic map (USB_DATAWIDTH         => USBPIE_DATAWIDTH,
	       RAM_DATAWIDTH         => USBRAM_DATAWIDTH,
               C_NBPHYSEP            => C_NBPHYSEP	,
	       C_DALB                => C_DALB		)
  port map (
      hclk			    => hclk   ,
      hresetn			    => hresetn,
      dma_addr		 	    => usbram_addr ,
      dma_req            	    => usbram_req  ,
      dma_gnt            	    => usbram_gnt  ,
      dma_write          	    => usbram_write,
      dma_wdata          	    => usbram_wdata,
      dma_rdata		 	    => usbram_rdata,
      dma_word_enable    	    => usbram_word_enable,
      sync_sieint_epinfo_req        => sync_sieint_epinfo_req  ,
      sync_sieint_epinfo_epnr	    => sync_sieint_epinfo_epnr ,
      sync_sieint_epinfo_epdir      => sync_sieint_epinfo_epdir,
      sync_sieint_epinfo_setup      => sync_sieint_epinfo_setup,
      epinfo_sync_valid             => epinfo_sync_valid_d	   ,
      epinfo_sync_active            => epinfo_sync_active_d	   ,
      epinfo_sync_disabled          => epinfo_sync_disabled_d	   ,
      epinfo_sync_toggle            => epinfo_sync_toggle_d	   ,
      epinfo_sync_stall             => epinfo_sync_stall_d	   ,
      epinfo_sync_iso               => epinfo_sync_iso_d  	   ,
      epinfo_sync_ratefeedbackmode  => epinfo_sync_ratefeedbackmode_d,
      epinfo_sync_nbytes            => epinfo_sync_nbytes_d	   ,
      epinfo_sync_maxpacket         => epinfo_sync_maxpacket_d       ,
      sync_sieint_txdatafetched     => sync_sieint_txdatafetched,
      epinfo_sync_txdata   	    => epinfo_sync_txdata_d	,
      epinfo_sync_txdata_valid	    => epinfo_sync_txdata_valid_d ,
      sync_sieint_rx_nbytes         => sync_sieint_rx_nbytes	,
      sync_sieint_rxdata            => sync_sieint_rxdata	,
      sync_sieint_rxdatavalid	    => sync_sieint_rxdatavalid	,
      sync_sieint_endtransfer       => sync_sieint_endtransfer	,
      sync_sieint_success           => sync_sieint_success	,
      sync_sieint_sentNAK           => sync_sieint_sentNAK	,
      sync_busreset                 => sync_busreset            ,
      dma_ahb_selected              => open                     ,
      usbreg_setup                  => usbreg_setup             ,
      pie_speed                     => pie_speed                ,
      usbreg_ep_list_start	    => usbreg_ep_list_start(31 downto 8),
      usbreg_ep_skip_list_start	    => usbreg_ep_list_start(31 downto 8),
      usbreg_data_buffer_start	    => usbreg_data_buffer_start(31 downto C_DALB),
      usbreg_ep_bufinuse            => usbreg_ep_bufinuse       ,
      usbreg_ep_skip                => usbreg_ep_skip           ,
      --dma_epinfo_toggle             => dma_epinfo_toggle,
      usbreg_epinfo_toggle          => usbreg_epinfo_toggle,
      dma_clear_toggle              => dma_clear_toggle,
      dma_set_toggle                => dma_set_toggle,
      dma_sent_NAK	            => dma_sent_NAK	        ,
      dma_set_int	            => dma_set_int	        ,
      dma_physepnr	            => dma_physepnr	        ,
      dma_clear_skip                => dma_clear_skip           ,
      dma_skip_ep                   => dma_skip_ep              ,
      usb_dma_fpga                  => usb_dma_fpga
     );

-- ----------------------------------------------------------------------------
-- OCP Recovery v1.1 Section 8.5 - post-synchronizer EP0 arbiter (hclk domain).
-- Interposes on the synchronized SIE interface between usb_synchronizer and the
-- downstream consumers usb_dma and usb_reg_if.  Traps every EP0 SETUP; replays
-- non-OCP SETUPs to legacy usb_dma and routes OCP-recovery-class transfers to
-- the SV recovery stack.
-- ----------------------------------------------------------------------------
usb_ocp_recovery_post_sync_arb_1 : usb_ocp_recovery_post_sync_arb
  generic map (
    USB_DATAWIDTH   => USBPIE_DATAWIDTH,
    RXNBYTES_BITS   => 12,
    TXNBYTES_BITS   => 15,
    C_REC_IFACE_NUM => 0
  )
  port map (
    hclk          => hclk,
    hresetn       => hresetn,
    sync_busreset => sync_busreset,

    -- Synchronizer hclk-side outputs (arbiter inputs).
    sync_sieint_epinfo_req_i    => sync_sieint_epinfo_req_s,
    sync_sieint_epinfo_epnr_i   => sync_sieint_epinfo_epnr_s,
    sync_sieint_epinfo_epdir_i  => sync_sieint_epinfo_epdir_s,
    sync_sieint_epinfo_setup_i  => sync_sieint_epinfo_setup_s,
    sync_sieint_setup_received_i=> sync_sieint_setup_received_s,
    sync_sieint_rx_nbytes_i     => sync_sieint_rx_nbytes_s,
    sync_sieint_rxdata_i        => sync_sieint_rxdata_s,
    sync_sieint_rxdatavalid_i   => sync_sieint_rxdatavalid_s,
    sync_sieint_endtransfer_i   => sync_sieint_endtransfer_s,
    sync_sieint_success_i       => sync_sieint_success_s,
    sync_sieint_error_i         => sync_sieint_error_s,
    sync_sieint_errortype_i     => sync_sieint_errortype_s,
    sync_sieint_sentNAK_i       => sync_sieint_sentNAK_s,
    sync_sieint_txdatafetched_i => sync_sieint_txdatafetched_s,

    -- usb_dma response outputs (arbiter inputs).
    epinfo_sync_valid_dma            => epinfo_sync_valid_d,
    epinfo_sync_active_dma           => epinfo_sync_active_d,
    epinfo_sync_disabled_dma         => epinfo_sync_disabled_d,
    epinfo_sync_toggle_dma           => epinfo_sync_toggle_d,
    epinfo_sync_stall_dma            => epinfo_sync_stall_d,
    epinfo_sync_iso_dma              => epinfo_sync_iso_d,
    epinfo_sync_ratefeedbackmode_dma => epinfo_sync_ratefeedbackmode_d,
    epinfo_sync_nbytes_dma           => epinfo_sync_nbytes_d,
    epinfo_sync_maxpacket_dma        => epinfo_sync_maxpacket_d,
    epinfo_sync_txdata_dma           => epinfo_sync_txdata_d,
    epinfo_sync_txdata_valid_dma     => epinfo_sync_txdata_valid_d,

    -- Arbiter outputs toward usb_dma.
    sync_sieint_epinfo_req_o    => sync_sieint_epinfo_req,
    sync_sieint_epinfo_epnr_o   => sync_sieint_epinfo_epnr,
    sync_sieint_epinfo_epdir_o  => sync_sieint_epinfo_epdir,
    sync_sieint_epinfo_setup_o  => sync_sieint_epinfo_setup,
    sync_sieint_rx_nbytes_o     => sync_sieint_rx_nbytes,
    sync_sieint_rxdata_o        => sync_sieint_rxdata,
    sync_sieint_rxdatavalid_o   => sync_sieint_rxdatavalid,
    sync_sieint_endtransfer_o   => sync_sieint_endtransfer,
    sync_sieint_success_o       => sync_sieint_success,
    sync_sieint_sentNAK_o       => sync_sieint_sentNAK,
    sync_sieint_txdatafetched_o => sync_sieint_txdatafetched,

    -- Arbiter outputs toward usb_reg_if.
    sync_sieint_setup_received_o=> sync_sieint_setup_received,
    sync_sieint_error_o         => sync_sieint_error,
    sync_sieint_errortype_o     => sync_sieint_errortype,

    -- Arbiter response outputs toward usb_synchronizer.
    epinfo_sync_valid_o            => epinfo_sync_valid,
    epinfo_sync_active_o           => epinfo_sync_active,
    epinfo_sync_disabled_o         => epinfo_sync_disabled,
    epinfo_sync_toggle_o           => epinfo_sync_toggle,
    epinfo_sync_stall_o            => epinfo_sync_stall,
    epinfo_sync_iso_o              => epinfo_sync_iso,
    epinfo_sync_ratefeedbackmode_o => epinfo_sync_ratefeedbackmode,
    epinfo_sync_nbytes_o           => epinfo_sync_nbytes,
    epinfo_sync_maxpacket_o        => epinfo_sync_maxpacket,
    epinfo_sync_txdata_o           => epinfo_sync_txdata,
    epinfo_sync_txdata_valid_o     => epinfo_sync_txdata_valid,

    -- SV recovery-stack byte-stream surface (unchanged interface).
    setup_pkt_vld   => rec_setup_pkt_vld,
    setup_pkt       => rec_setup_pkt,
    ctrl_out_data   => rec_ctrl_out_data,
    ctrl_out_be     => rec_ctrl_out_be,
    ctrl_out_vld    => rec_ctrl_out_vld,
    ctrl_out_last   => rec_ctrl_out_last,
    ctrl_out_rdy    => rec_ctrl_out_rdy,
    ctrl_in_data    => rec_ctrl_in_data,
    ctrl_in_be      => rec_ctrl_in_be,
    ctrl_in_vld     => rec_ctrl_in_vld,
    ctrl_in_last    => rec_ctrl_in_last,
    ctrl_in_rdy     => rec_ctrl_in_rdy,
    ctrl_in_resp_bytes => rec_ctrl_in_resp_bytes,
    ctrl_in_resp_known => rec_ctrl_in_resp_known,
    ctrl_set_stall  => rec_ctrl_set_stall,
    ctrl_xfer_done  => rec_ctrl_xfer_done,
    ocp_path_disable_i => rec_ocp_path_disable,
    rec_claim_status   => rec_ctrl_claim
  );


usb_ahb_slave_1 : usb_ahb_slave
  port map   (
    	     hclk	        	 => hclk	         ,
    	     hresetn	        	 => hresetn	         ,
    	     haddr	        	 => ahbs_haddr  	 ,
    	     hwrite	        	 => ahbs_hwrite 	 ,
    	     hsel	        	 => ahbs_hsel		 ,
    	     htrans1	        	 => ahbs_htrans(1)	 ,
    	     hwdata	          	 => ahbs_hwdata 	 ,
    	     hrdata	          	 => ahbs_hrdata 	 ,
    	     hresp	        	 => ahbs_hresp  	 ,
    	     hready	        	 => ahbs_hreadyout 	 ,
    	     hready_glb         	 => ahbs_hreadyin	 ,
    	     reg_waddr          	 => reg_waddr	         ,
    	     reg_wdata            	 => reg_wdata		 ,
    	     reg_raddr          	 => reg_raddr	         ,
    	     reg_rdata            	 => reg_rdata		 ,
    	     reg_write          	 => reg_write
             );

--UTMI/ULPI clock selection:
pie_clk <= utmi_clk when (testmode = '1' and C_UTMI_SUPPORT) else
           ulpi_clk when (testmode = '1' and C_ULPI_SUPPORT) else
           utmi_clk when phy_mode = '0'                      else
           ulpi_clk;



-- Reset resynchronization (ahb --> USB clock domain):
  proc_pie_reset_gen : process(hresetn,pie_clk)
  begin
    if hresetn = '0' then
      sync_s_reset_n  <= '0';
      sync_ss_reset_n <= '0';
    elsif pie_clk'event and pie_clk = '1' then
      sync_s_reset_n  <= '1';
      sync_ss_reset_n <= sync_s_reset_n;
    end if;
  end process proc_pie_reset_gen;

  Reset_N <= sync_ss_reset_n or async_disable;


-- DOC_BEGIN: Vbus Debouncing
-- This circuit masks small low spikes on Vbus. This allows
-- to share the Vbus pin with an other input pin, provided
-- that it goes low only for a short time during normal
-- operation.

-- GMA: BYPASS fix PR#55


vbus_debounc_proc : process (pie_clk,Reset_N)
begin
if Reset_N = '0' then
   VBusDebounced             <= '0';
--   vbusontimer               <= 2;
   DebounceTimer             <= 0;
   pie_isotoggle_r           <= '0';
   pie_vbusvalid_r             <= '0';
elsif pie_clk'event and pie_clk = '1' then
   if vbuscomp_on_int = '1' then
      pie_vbusvalid_r <= pie_vbusvalid;
   else
      pie_vbusvalid_r <= '0';
   end if;
   pie_isotoggle_r           <= pie_isotoggle;
   if pie_vbusvalid_r = '1' or (DebounceTimer > 0) then
--   if (vbusontimer = 0) and (DebounceTimer > 0) then
      VBusDebounced <= '1';
   else
      VBusDebounced <= '0';
   end if;
--   if DebounceTimer = 0 then
--     vbusontimer <= 2;
--   elsif pie_isotoggle = '1' xor pie_isotoggle_r = '1'  then -- every toggling of isotoggle signal
--      if (vbusontimer > 0) then
--         vbusontimer <= vbusontimer -1;
--      end if;
--   end if;
   if pie_vbusvalid_r = '1' then
      DebounceTimer <= VBUS_DEBOUNCE_TIME;
   elsif pie_isotoggle = '1' xor pie_isotoggle_r = '1'  then -- every toggling of isotoggle signal
      if (DebounceTimer > 0) then
         DebounceTimer <= DebounceTimer -1;
      end if;
   end if;
end if;
end process vbus_debounc_proc;


  utmi_reset_detect_proc : process(hclk,hresetn)
  begin
    if hresetn = '0' then
   --   reset_needed <= '1';
      atx_reset_core <= '0';
      clk_counter_atx_core <= RESET_CYCLE;
   --   reset_done_z <= '0';
   --   reset_done_zz<= '0';
    elsif hclk'event and hclk = '1' then
      if (clk_counter_atx_core > 0) then
         clk_counter_atx_core <= clk_counter_atx_core -1;
         atx_reset_core <= '1';
      else
         atx_reset_core <= '0';
      end if;
   --   reset_done_z <= reset_done;
   --   reset_done_zz<= reset_done_z;
   ---   if (reset_done_zz = '1') then
   --     reset_needed <= '0';
   --   end if;
   end if;
  end process utmi_reset_detect_proc;

   reset_needed <= atx_reset_core;

-- UTMI only:
  atx_reset_core_proc : process (sys_utmi_clkin_lock, pie_clk, Reset_N)
  begin
   -- if (hresetn = '0' and async_disable = '0') then
     if Reset_N = '0' then
      reset_needed_z  <= '1';
      reset_needed_zz <= '1';
  --    reset_done      <= '0';
  --    atx_reset_core  <= '0';
  --    clk_counter_atx_core <= RESET_CYCLE;
      clk_off_counter      <= 0;
  --    init_phy_reset <= '0';
    elsif pie_clk'event and pie_clk = '1' then
      if phy_mode = '0' then -- UTMI only
        if clock_on = '1' or  pwrctrl_wakeup_int = '1' then
          clk_off_counter <= CLOCKOFF_CYCLE;
        elsif clk_off_counter > 0 then
          clk_off_counter <= clk_off_counter -1;
        end if;
        reset_needed_z  <= reset_needed;
        reset_needed_zz <= reset_needed_z;
  --    if ((utmi_clk_ok = '0' ) and (init_phy_reset = '0')) then
  --      clk_counter_atx_core <= RESET_CYCLE;
--	init_phy_reset <= '1';
 --     else
 --       if (clk_counter_atx_core > 0) then
--	  if (sys_utmi_clkin_lock = '1') then
 --           clk_counter_atx_core <= clk_counter_atx_core -1;
 --  	  end if;
--	  end if;
 --         if (reset_needed_zz = '1') then
 --           if (clk_counter_atx_core > 0) then
 --             atx_reset_core <= '1';
 --           else
 --             reset_done  <= '1';
 --           end if;
 --         else
 --           reset_done     <= '0';
 --           atx_reset_core <= '0';
 --         end if;
 --       end if;
      end if;
    end if;
  end process atx_reset_core_proc;

--  pie_clk_ok_proc : process(clock_on, async_disable, sys_utmi_clkin_lock, pie_clk,clk_off_counter)
--    begin
--      if (((clock_on = '0' and clk_off_counter = 0 )or sys_utmi_clkin_lock = '0') and async_disable = '0') then
--        utmi_clk_ok <= '0';
--      elsif( pie_clk'event and pie_clk = '1') then
--        if phy_mode = '0' then
--          utmi_clk_ok <= '1';
--        end if;
--      end if;
--    end process pie_clk_ok_proc;

  utmi_clk_ok_clr_n <= '0' when ((clock_on = '0' and clk_off_counter = 0 ) or sys_utmi_clkin_lock = '0') else '1';

  utmi_clk_ok_clr_n_q_proc : process (testmode, pie_clk)
  begin
    if (testmode = '0') then
      utmi_clk_ok_clr_n_q <= '0';
    elsif (pie_clk'event and pie_clk = '1') then
      utmi_clk_ok_clr_n_q <= utmi_clk_ok_clr_n;
    end if;
  end process utmi_clk_ok_clr_n_q_proc;

  utmi_clk_ok_clr_n_dft <= utmi_clk_ok_clr_n_q when (testmode = '1') else utmi_clk_ok_clr_n;

  pie_clk_ok_proc : process(utmi_clk_ok_clr_n_dft, async_disable, pie_clk)
    begin
      if (utmi_clk_ok_clr_n_dft = '0' and async_disable = '0') then
        utmi_clk_ok <= '0';
      elsif( pie_clk'event and pie_clk = '1') then
        if phy_mode = '0' then
          utmi_clk_ok <= '1';
        end if;
      end if;
    end process pie_clk_ok_proc;

  utmi_reset <= '1' when  (atx_reset_core = '1') else '0';

-- UTMI or ULPI:
dp <= utmi_linestate(0) when phy_mode = '0' else
      ulpi_linestate_lp(0) when phy_mode = '1' and ulpi_dir = '1' and ulpi_dir_s = '1' and ulpi_dir_ss = '1' else
      '0';

dm <= utmi_linestate(1) when phy_mode = '0' else
      ulpi_linestate_lp(1) when phy_mode = '1' and ulpi_dir = '1' and ulpi_dir_s = '1'and ulpi_dir_ss = '1'else
      '0';

-- ULPI Only:
ulpi_linestate_lp <= ulpi_rxdata( 1 downto 0) when ulpi_ddr_sel = '0' or dataline_low_power_en = '0' else -- ulpi linestate in Low Power Mode
                     ulpi_rxdata( 5 downto 4);

ulpi_int_lp <= ulpi_rxdata(3) when ulpi_ddr_sel = '0' and dataline_low_power_en = '1' and ulpi_dir = '1' and ulpi_dir_s = '1' and ulpi_dir_ss = '1' else -- ulpi active high interrupt in Low Power Mode
               ulpi_rxdata(7) when ulpi_ddr_sel = '1' and dataline_low_power_en = '1' and ulpi_dir = '1' and ulpi_dir_s = '1' and ulpi_dir_ss = '1' else
               '0';

awake <= pie_lowpower_n when phy_mode = '1' -- In ULPI mode, pie_low_power_n is de-asserted when device is detached from USB
          else pie_lowpower_n or utmi_clk_ok; -- In UTMI mode,signal is needed to detect when device is detached from USB (awake de-asserted)


-- ------------------------------------
-- BVE : modified control of dataline_low_power_en signal.
--       This is based on the ULPI PHY entering low-power state (indicated by ulpi_dir and ulpi_nxt signal)
--       and not by looking at ULPI clock
--       The main reason to do this is that this new behaviour makes it independent from the AHB clock.

dataline_low_power_en <= '1' when pie_lowpower_n = '0' and ulpi_dir_sss = '1' and ulpi_nxt_sss = '0' else '0';


---- ULPI only DATA LOW POWER ENABLE
---- Once the PHY is placed in Low Power Mode( Via a TX Command sent by the 3511_hs), Linestate and active high interrupt indication
---- are driven asynchronously via ULPI data bus. Actually, linestate can still toggle as long as the USB clock (pie_clock) is running (minimum 5 clock cycles after ulpi_dir is asserted).
---- Since, its is phy dependant, it is safer to use a counter (running on USB clock) sampled with another counter running on AHB clock.
---- If 2 consecutive samples of AHB counter are different, it means USB clock is still running and  clock counter AHB is re-initialised
---- If there are equal, AHB counter counts down. Asynchronous datalines can be interpreted if clock_counter_ahb = 0 (data_line_low_power_en = '1')
---- USB need clock (that allows to switch off AHB clock) can only be de-asserted when data_line_low_power_en = '1'
-- dataline_low_power_en <= '1' when clock_counter_ahb = 0 else '0';
--
-- dataline_low_power_pie_clk_proc : process(pie_clk, Reset_N,awake,async_disable)
--  begin
--  if ((Reset_N='0' or awake ='1' ) and async_disable = '0') then
--     clock_counter_usb <= 0 ;
--  elsif  (pie_clk'event and pie_clk='1') then
--     if clock_counter_usb = 0 then
--        clock_counter_usb <= CLOCK_COUNTER_USB_MAX;
--     else
--        clock_counter_usb <= clock_counter_usb - 1;
--     end if;
--  end if;
--end process dataline_low_power_pie_clk_proc;
--
--  dataline_low_power_ahb_clk_proc: process (hclk,hresetn,awake,async_disable)
--  begin
--     if ((hresetn = '0' or awake = '1') and async_disable = '0') then
--        clock_counter_ahb <= CLOCK_COUNTER_AHB_MAX;
--        clock_counter_usb_msb    <= '0';
--        clock_counter_usb_msb_z  <= '0';
--        clock_counter_usb_msb_zz <= '0';
--     elsif hclk'event and hclk = '1' then
--        clock_counter_usb_msb    <= to_unsigned(clock_counter_usb,4)(3);
--        clock_counter_usb_msb_z  <= clock_counter_usb_msb;
--        clock_counter_usb_msb_zz <= clock_counter_usb_msb_z;
--        if clock_counter_ahb > 0 then
--           if (clock_counter_usb_msb_z = clock_counter_usb_msb_zz ) then
--              clock_counter_ahb <= clock_counter_ahb -1;
--           else
--              clock_counter_ahb <= CLOCK_COUNTER_AHB_MAX;
--           end if;
--        end if;
--     end if;
--  end process dataline_low_power_ahb_clk_proc;

-- UTMI or ULPI:
  WAKEUP_DETECTION : process (pie_clk, Reset_N)
  begin
    if Reset_N = '0' then
      dp_s         <= '0';
      dm_s         <= '0';
      ulpi_dir_s   <= '0';
      ulpi_dir_ss  <= '0';
      ulpi_dir_sss <= '0';
      ulpi_nxt_s   <= '0';
      ulpi_nxt_ss  <= '0';
      ulpi_nxt_sss <= '0';
    elsif pie_clk'event and pie_clk ='1' then
      dp_s         <= dp;
      dm_s         <= dm;
      ulpi_dir_s   <= ulpi_dir;
      ulpi_dir_ss  <= ulpi_dir_s;
      ulpi_dir_sss <= ulpi_dir_ss;
      ulpi_nxt_s   <= ulpi_nxt;
      ulpi_nxt_ss  <= ulpi_nxt_s;
      ulpi_nxt_sss <= ulpi_nxt_ss;
    end if;
  end process WAKEUP_DETECTION;


  usb_needclk_int      <= '0' when sys_donotwakeup_n = '0' else
-- -------------------------------------
-- BVE : dataline_low_power_en is only applicable in ULPI mode 
--                          '1' when  ((clock_on = '1' or clk_off_counter /= 0 or dataline_low_power_en = '0' or pwrctrl_wakeup_int = '1') and phy_mode = '0') else
                          '1' when  ((clock_on = '1' or clk_off_counter /= 0 or pwrctrl_wakeup_int = '1') and phy_mode = '0') else
-- -------------------------------------
                          '1' when  ((clock_on = '1'or dataline_low_power_en = '0' or pwrctrl_wakeup_int = '1') and phy_mode = '1') else
                          '0';

  usb_needclk <= usb_needclk_int;


-- --ULPI OR UTMI
--  WAKEUP_STAGE : Process (Reset_N,async_disable,clock_on,clk_off_counter,phy_mode,dataline_low_power_en,ulpi_dir_sss,pie_lowpower_n,pie_clk,awake)
--  -- wake up is set asynchronously, can be reset asynchronously and synchronously if suspend_set is cleared
--  begin
--  --altera translate_off
--     if async_disable = '0' then
--  --altera translate_on
--        if Reset_N = '0' then
--           pwrctrl_wakeup_int <= '0';
---- -------------------------------------
---- BVE : dataline_low_power_en is only applicable in ULPI mode 
----        elsif (clock_on = '1'  and clk_off_counter = 0 and dataline_low_power_en = '1' and phy_mode = '0') or
--        elsif (clock_on = '1'  and clk_off_counter = 0 and phy_mode = '0') or
---- -------------------------------------
--              (clock_on = '1' and dataline_low_power_en = '1' and ulpi_dir_sss = '1' and phy_mode = '1') then
--           pwrctrl_wakeup_int <= '1'; -- asynch wake up is only allowed when a wake up event occurs once usb clock is OFF
--        elsif pie_clk'event and pie_clk ='1' then
--        -- wake up must be hold asserted until clock is running again and lowpower is de-asserted
--              pwrctrl_wakeup_int <= pwrctrl_wakeup_int and not awake;
--        end if;
--  --altera translate_off
--     else -- bypass asynchronous set/reset in test mode
--        if pie_clk'event and pie_clk ='1' then
--	   pwrctrl_wakeup_int <= async_disable;
--        end if;
--     end if;
--  --altera translate_on
--
--  end process  WAKEUP_STAGE;

  -- BVE : dataline_low_power_en is only applicable in ULPI mode 
  pwrctrl_wakeup_int_set_n <= '0' when (clock_on = '1' and clk_off_counter = 0 and phy_mode = '0') or
                                       (clock_on = '1' and dataline_low_power_en = '1' and ulpi_dir_sss = '1' and phy_mode = '1') else '1';

  pwrctrl_wakeup_int_set_n_q_proc : process (testmode, pie_clk)
  begin
    if (testmode = '0') then
      pwrctrl_wakeup_int_set_n_q <= '0';
    elsif (pie_clk'event and pie_clk = '1') then
      pwrctrl_wakeup_int_set_n_q <= pwrctrl_wakeup_int_set_n;
    end if;
  end process pwrctrl_wakeup_int_set_n_q_proc;

  pwrctrl_wakeup_int_set_n_dft <= pwrctrl_wakeup_int_set_n_q when (testmode = '1') else pwrctrl_wakeup_int_set_n;

  --ULPI OR UTMI
  WAKEUP_STAGE : Process (Reset_N, pwrctrl_wakeup_int_set_n_dft, async_disable, pie_clk)
  -- wake up is set asynchronously, can be reset asynchronously and synchronously if suspend_set is cleared
  begin
    if Reset_N = '0' then
      pwrctrl_wakeup_int <= '0';
    elsif (pwrctrl_wakeup_int_set_n_dft = '0' and async_disable = '0') then
      pwrctrl_wakeup_int <= '1'; -- asynch wake up is only allowed when a wake up event occurs once usb clock is OFF
    elsif pie_clk'event and pie_clk ='1' then
    -- wake up must be hold asserted until clock is running again and lowpower is de-asserted
      pwrctrl_wakeup_int <= pwrctrl_wakeup_int and not awake;
    end if;
  end process  WAKEUP_STAGE;


-- Only relevant for ULPI:
ulpi_pwrctrl_wakeup <= pwrctrl_wakeup_int when sys_donotwakeup_n = '1' else '0';


  -- Only relevant for UTMI:
utmi_suspendm     <= '1' when ((clock_on = '1') or (clk_off_counter /= 0) or pwrctrl_wakeup_int = '1') and sys_donotwakeup_n = '1'
                           else '0';

  --ULPI OR UTMI
  clock_on <= '1' when (reset_needed_zz  = '1' and phy_mode = '0')      or
                       usbreg_pll_on = '1'                           or
		       ((VBusDebounced = '1' xor pie_vbusvalid = '1') and phy_mode = '0') or
                       (dp_s         /= dp and sync_usbreg_dev_connect = '1') or
                       (dm_s         /= dm and sync_usbreg_dev_connect = '1') or
                       (sync_usbreg_dev_connect /= usbreg_dev_connect)        or
		       pie_lowpower_n = '1'                                   or
		       sys_dev_wakeup_n = '0'                                 or
		       (ulpi_int_lp = '1' and phy_mode = '1')                 or
		       usbreg_phy_start = '1'
		  else '0';


--fpga debug
  --altera translate_off
  --ip_xxx_3511_hs_fpga(255 downto 0) <= (others => '0');
  --altera translate_on

   -- synthesis read_comments_as_HDL on
   -- ip_xxx_3511_hs_fpga(255 downto 71) <= (others => '0');
   -- ip_xxx_3511_hs_fpga(63 downto 0) <= usb_pie_fpga;
   -- ip_xxx_3511_hs_fpga(64) <= usb_needclk_int;
   -- ip_xxx_3511_hs_fpga(65) <= hresetn;
   -- ip_xxx_3511_hs_fpga(66) <= Reset_N;
   -- ip_xxx_3511_hs_fpga(67) <= reset_needed;
   -- ip_xxx_3511_hs_fpga(68) <= clock_on;
   -- ip_xxx_3511_hs_fpga(69) <= pie_lowpower_n;
  --  ip_xxx_3511_hs_fpga(70) <= '1' when (clk_off_counter /= 0) else '0';
  -- synthesis read_comments_as_HDL off



end structure;

----------------------------------------------------------------------
LIBRARY rtl;

configuration ip_xxx_3511_hs_structure_cfg of ip_xxx_3511_hs is
  for structure
    for usb_pie_1: usb_pie
      use entity rtl.usb_pie(rtl);
    end for;
    for usb_synchronizer_1: usb_synchronizer
      use entity rtl.usb_synchronizer(rtl);
    end for;
    for usb_reg_if_1 : usb_reg_if
      use entity rtl.usb_reg_if(rtl);
    end for;
    for usb_dma_1 : usb_dma
      use entity rtl.usb_dma(rtl);
    end for;
    for usb_ocp_recovery_post_sync_arb_1 : usb_ocp_recovery_post_sync_arb
      use entity rtl.usb_ocp_recovery_post_sync_arb(rtl);
    end for;
    for usb_ahb_slave_1 : usb_ahb_slave
      use entity rtl.usb_ahb_slave(rtl);
    end for;
  end for;
end ip_xxx_3511_hs_structure_cfg;
