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
--           $RCSfile: ip_xxx_3511_hs_cmp_pkg.p.vhdl.rca $
--
--             Author: Sonia Mehri
--
--       Organisation: Corporate I&T / IP & Architecture
--
--              $Date: Tue Jan 30 23:49:09 2018 $
--
--            Project: Low gate count USB peripheral IP
--
--        Description:
--
--          $Revision: 1.5 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: ip_xxx_3511_hs_cmp_pkg.p.vhdl.rca $
--   
--    Revision: 1.5 Tue Jan 30 23:49:09 2018 usb06610
--    pulled out the following hard-coded constants, from ip_xxx_3511/RTL/usb_host_pie.m.vhdl and ip_xxx_3511/RTL/usb_pie.m.vhdl, to the boundary of the ip_xxx_3516_hs_mem as inputs: INTER_PACKET_DELAY_LS INTER_PACKET_DELAY_FS INTER_PACKET_DELAY_HS PACKET_TURNAROUND_TIMEOUT_LS PACKET_TURNAROUND_TIMEOUT_FS PACKET_TURNAROUND_TIMEOUT_HS PACKET_EVENT_TIMEOUT_LS PACKET_EVENT_TIMEOUT_FS PACKET_EVENT_TIMEOUT_HS
--    
--   
--    Revision: 1.18 Thu Nov  8 11:03:43 2012 beq03196
--    Fix CR#82: CR - add bits for new OTG features
--
--    Revision: 1.17 Thu May 24 09:31:38 2012 beq03067
--    removed duplicated fpga
--
--    Revision: 1.16 Tue May  8 08:26:25 2012 beq03067
--    debug fpga not for rc
--
--    Revision: 1.15 Mon Feb 20 13:46:47 2012 beq03339
--    Added testmode input pin
--
--    Revision: 1.14 Fri Dec  2 15:58:02 2011 beq03196
--    add pin for fpga purpose only
--
--    Revision: 1.13 Wed Oct 12 14:18:26 2011 beq03067
--    Add phy_interface for FPGA
--
--    Revision: 1.12 Wed Oct  5 11:43:36 2011 beq03196
--    add ulpi_ddr_sel as input of the 3511_hs
--
--    Revision: 1.11 Wed Sep 21 07:21:54 2011 beq03067
--    debug 256 bits
--
--    Revision: 1.10 Wed Sep 14 10:47:19 2011 beq03099
--    *** empty comment string ***
--
--    Revision: 1.9 Thu Jul 14 16:23:16 2011 beq03099
--    added power down signals
--
--    Revision: 1.8 Fri Jul  8 08:41:04 2011 beq03099
--    added UTMI+ vendor specific signals
--
--    Revision: 1.7 Tue May 17 14:55:42 2011 beq03067
--    added fpga debug
--
--    Revision: 1.6 Tue May 17 10:52:06 2011 beq03067
--    internal pll io removed
--
--    Revision: 1.5 Mon May 16 16:38:54 2011 beq03099
--    connected to dual-port RAM model
--
--    Revision: 1.4 Fri May 13 11:54:11 2011 beq03099
--    modified interface to be a ram interface instead of AHB master
--
--    Revision: 1.3 Thu May  5 15:42:51 2011 beq03099
--    replaced interface with UTMI
--
--    Revision: 1.2 Thu Feb 24 10:02:20 2011 beq03099
--    removed usb_cfg package
--
--    Revision: 1.1 Thu Feb 10 12:22:59 2011 beq03099
--    first version - still contains SIE and not PIE
--
--
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package ip_xxx_3511_hs_cmp_pkg is
component ip_xxx_3511_hs
  generic(C_NBPHYSEP     : integer := 14;
          C_EPUB         : integer := 32;
          C_DAUB         : integer := 32; --Requirement : C_DAUB > C_DALB
          C_DALB         : integer := 17; --maximum allowed value is 17
                                          --minimum allowed value is 7
          C_EPFIFO_PAGE  : std_logic_vector(31 downto 0) := X"00080000";
          C_DATAFIFO_PAGE: std_logic_vector(31 downto 0) := X"00080000";
          C_SINGLE_BUFFER_SUPPORTED: boolean := TRUE;
          C_DOUBLE_BUFFER_SUPPORTED: boolean := TRUE;
          C_TOGGLE_REG_READABLE    : boolean := TRUE;
          C_PLL_ENABLE             : boolean := FALSE;
          C_PLL_DIVIDER            : std_logic_vector(6 downto 0) := "0010100";
          C_ULPI_SUPPORT           : boolean := TRUE;
          C_UTMI_SUPPORT             : boolean := TRUE;
          C_EXTEND_TX_DELAY          : boolean := TRUE;
          G_SIM_CHIRP_TIMERS         : boolean := FALSE
	  );
  port(
       -- AHB bus signals
       hclk                 : in  std_logic;
       hresetn              : in  std_logic;

       ahbs_haddr           : in  std_logic_vector(5 downto 2);
       ahbs_htrans   	    : in  std_logic_vector(1 downto 0);
       ahbs_hwrite   	    : in  std_logic;
       ahbs_hwdata   	    : in  std_logic_vector(31 downto 0);
       ahbs_hsel     	    : in  std_logic;
       ahbs_hreadyin 	    : in  std_logic;
       ahbs_hrdata   	    : out std_logic_vector(31 downto 0);
       ahbs_hreadyout	    : out std_logic;
       ahbs_hresp    	    : out std_logic_vector(1 downto 0);

       usbram_addr	    : out std_logic_vector(31 downto 0);
       usbram_req	    : out std_logic;
       usbram_gnt	    : in  std_logic;
       usbram_write	    : out std_logic;
       usbram_wdata	    : out std_logic_vector(63 downto 0);
       usbram_rdata	    : in  std_logic_vector(63 downto 0);
       usbram_word_enable   : out std_logic_vector(1 downto 0);

       -- Interrupt controller signals
       USB_Int_Req_Irq:      out   std_logic;                      -- Irq interrupt
       USB_Int_Req_Fiq:      out   std_logic;                      -- Fiq interrupt
       USB_FrameToggle:      out   std_logic;

       --Configuration status indicator
       USB_VBus:             in    std_logic;                      -- Bus power is present
       vbuscomp_on:          out   std_logic;                      -- Enable Analog Vbus comparators
       chrg_vbus :           out   std_logic;
       dischrg_vbus:         out   std_logic;
       avalid:               in    std_logic;                      -- ADPPROBE
       sessend:              in    std_logic;                      -- ADPSENSE

       -- UTMI interface
       -- These signals are only to be used when the generic
       -- UTMI_SUPPORT is set to TRUE
       utmi_clk 		    : in  std_logic;
       utmi_rxdata		    : in  std_logic_vector(7 downto 0);
       utmi_rxvalid		    : in  std_logic;
       utmi_rxactive		    : in  std_logic;
       utmi_rxerror		    : in  std_logic;
       utmi_txdata		    : out std_logic_vector(7 downto 0);
       utmi_txvalid		    : out std_logic;
       utmi_txready		    : in  std_logic;
       utmi_reset		    : out std_logic;
       utmi_suspendm		    : out std_logic;
       utmi_xcvrselect  	    : out std_logic;
       utmi_termselect  	    : out std_logic;
       utmi_opmode		    : out std_logic_vector(1 downto 0);
       utmi_linestate		    : in  std_logic_vector(1 downto 0);
       utmi_vcontrol                : out std_logic_vector(3 downto 0);
       utmi_vcontrolloadm           : out std_logic;
       utmi_vstatus                 : in  std_logic_vector(7 downto 0);
       -- ULPI INTERFACE
       -- These signals are only to be used when the generic
       -- ULPI_SUPPORT is set to TRUE
       ulpi_clk                     : in  std_logic;
       ulpi_rxdata                  : in std_logic_vector(7 downto 0);
       ulpi_txdata                  : out std_logic_vector(7 downto 0);
       ulpi_txenable                : out std_logic;
       ulpi_dir                     : in  std_logic;
       ulpi_stp                     : out std_logic;
       ulpi_nxt                     : in  std_logic;
       ulpi_ddr_sel                 : in  std_logic;

       -- System interface
       usb_needclk                  : out std_logic;
       sys_donotwakeup_n            : in  std_logic;
       sys_dev_wakeup_n             : in  std_logic;
       sys_utmi_clkin_lock          : in  std_logic;
       token_length_counter         : in  std_logic_vector(6 downto 0);
       usb_token_length             : out std_logic_vector(6 downto 0);

       -- Dedicated signals for internal PLL that is synchronized on USB frame time
--       USB_select_ext_clk:   out std_logic;
--       USB_48MHzReset_N          : out std_logic; -- reset for frequency control block
                                                  -- synchronous with USB_MainClk
--       USB_FrameTimer         : out std_logic_vector(15 downto 0); -- counter at 48MHz
--       USB_SOFDetect          : out std_logic;

       -- synthesis read_comments_as_HDL on
       --ip_xxx_3511_hs_fpga : out std_logic_vector(255 downto 0);
       -- synthesis read_comments_as_HDL off

       usb_pie_INTER_PACKET_DELAY_FS_param   : in  std_logic_vector(4 downto 0);
       usb_pie_INTER_PACKET_DELAY_HS_param   : in  std_logic_vector(4 downto 0);
       usb_pie_PACKET_TURNAROUND_TIMEOUT_FS_param : in  std_logic_vector(7 downto 0);
       usb_pie_PACKET_TURNAROUND_TIMEOUT_HS_param : in  std_logic_vector(7 downto 0);
       usb_pie_PACKET_EVENT_TIMEOUT_FS_param : in  std_logic_vector(8 downto 0);
       usb_pie_PACKET_EVENT_TIMEOUT_HS_param : in  std_logic_vector(8 downto 0);

       -- OCP Recovery v1.1 Section 8.5 - PIE arbiter upper-side byte stream
       rec_setup_pkt_vld   : out std_logic;
       rec_setup_pkt       : out std_logic_vector(63 downto 0);
       rec_ctrl_out_data   : out std_logic_vector(31 downto 0);
       rec_ctrl_out_be   : out std_logic_vector(3 downto 0);
       rec_ctrl_out_vld    : out std_logic;
       rec_ctrl_out_last   : out std_logic;
       rec_ctrl_out_rdy    : in  std_logic;
       rec_ctrl_in_data    : in std_logic_vector(31 downto 0);
       rec_ctrl_in_be    : in std_logic_vector(3 downto 0);
       rec_ctrl_in_vld     : in  std_logic;
       rec_ctrl_in_last    : in  std_logic;
       rec_ctrl_in_rdy     : out std_logic;
       rec_ctrl_set_stall  : in  std_logic;
       rec_ctrl_xfer_done  : out std_logic;
       rec_ctrl_claim      : out std_logic;

       -- core testability
       async_disable:        in    std_logic;
       testmode            : in    std_logic -- To be connected by integrator to a tcb test mode pin.
      );
end component;
end ip_xxx_3511_hs_cmp_pkg;
