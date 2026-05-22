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
--           $RCSfile: ip_xxx_3515_hs_cmp_pkg.p.vhdl.rca $
--
--             Author: Bart Vertenten
--
--       Organisation: CentralR&D / Design Services
--
--              $Date: Wed May 29 12:25:34 2019 $
--
--            Project: Low gate count USB host IP
--
--        Description:
--
--          $Revision: 1.6 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: ip_xxx_3515_hs_cmp_pkg.p.vhdl.rca $
--   
--    Revision: 1.6 Wed May 29 12:25:34 2019 usb00219
--    Added chicken bit for CDC crossing fix made for artf663122. Updates from Soong.
--    
--
--    Revision: 1.11 Thu Dec 13 11:42:26 2012 beq03196
--    add USB_OTG register for the ip_3516_hs
--
--    Revision: 1.10 Wed Nov 21 17:03:57 2012 beq03196
--    copy from ip_xxx_3515_hs_mem_structure.m.vhdl v1.39
--
--    Revision: 1.9 Thu Nov  8 11:12:58 2012 beq03067
--    added usbreg_woo
--
--    Revision: 1.8 Tue May  8 08:33:24 2012 beq03067
--    fpga debug not for rc
--
--    Revision: 1.7 Thu Mar 29 16:14:22 2012 beq03196
--    FIX CR#9: Add a check on vbus valid (Bvalid) in the host_pie + Filtering option on vbus
--
--    Revision: 1.6 Fri Mar  9 07:15:29 2012 beq03099
--    removed usbram_word_enable signal
--
--    Revision: 1.5 Wed Mar  7 10:26:11 2012 beq03067
--    Added testmode
--
--    Revision: 1.4 Tue Mar  6 12:00:16 2012 beq03067
--    added power need indication
--
--    Revision: 1.3 Fri Feb 17 11:42:41 2012 beq03196
--    tx enable is 1 bit signal
--
--    Revision: 1.2 Thu Feb  2 10:22:53 2012 beq03099
--    fixed ahb slave address width
--
--    Revision: 1.1 Wed Feb  1 15:38:32 2012 beq03099
--    initial version
--
--
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package ip_xxx_3515_hs_cmp_pkg is
component ip_xxx_3515_hs
   generic(C_ULPI_SUPPORT             : boolean := TRUE;
             C_UTMI_SUPPORT             : boolean := TRUE;
             RAM_ADDRWIDTH              : integer := 9;
             C_PORTPOWER_CONTROL        : boolean := TRUE;
             C_PORTINDICATOR            : boolean := TRUE
            -- C_FILT_VBUS              : boolean := TRUE
             );
     port(
          -- AHB bus signals
          hclk                 : in  std_logic;
          hresetn              : in  std_logic;
          vbusvalid            : in std_logic;


          ahbs_haddr           : in  std_logic_vector(6 downto 2);
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

          -- Interrupt controller signals
          USB_Int_Req_Irq:      out   std_logic;                      -- Irq interrupt

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
          utmi_xcvrselect  	    : out std_logic_vector(1 downto 0);
          utmi_termselect  	    : out std_logic;
          utmi_opmode		    : out std_logic_vector(1 downto 0);
          utmi_linestate		    : in  std_logic_vector(1 downto 0);
          utmi_vcontrol                : out std_logic_vector(3 downto 0);
          utmi_vcontrolloadm           : out std_logic;
          utmi_vstatus                 : in  std_logic_vector(7 downto 0);
          utmi_hostdisconnect          : in  std_logic;
          utmi_id_enable      : out std_logic;
          utmi_id_value       : in  std_logic;
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
          usb_needclk         : out std_logic;
          sys_donotwakeup_n   : in  std_logic;
          sys_utmi_clkin_lock : in  std_logic;
          dev_enable          : out std_logic;
          usb_overcurrent_n            : in  std_logic;
          usb_portindicator            : out std_logic_vector(1 downto 0);
          usb_portpower                : out std_logic;
          sw_ctrl_pdcom      : out std_logic;
          sw_pdcom           : out std_logic;

     -- synthesis read_comments_as_HDL on
     --  ip_xxx_3515_hs_fpga : out std_logic_vector(255 downto 0);
     -- synthesis read_comments_as_HDL off

          usb_host_pie_INTER_PACKET_DELAY_LS_param   : in  std_logic_vector(7 downto 0);
          usb_host_pie_INTER_PACKET_DELAY_FS_param   : in  std_logic_vector(7 downto 0);
          usb_host_pie_INTER_PACKET_DELAY_HS_param   : in  std_logic_vector(7 downto 0);
          usb_host_pie_PACKET_TURNAROUND_TIMEOUT_LS_param : in  std_logic_vector(10 downto 0);
          usb_host_pie_PACKET_TURNAROUND_TIMEOUT_FS_param : in  std_logic_vector(7 downto 0);
          usb_host_pie_PACKET_TURNAROUND_TIMEOUT_HS_param : in  std_logic_vector(7 downto 0);
          usb_host_pie_PACKET_EVENT_TIMEOUT_LS_param : in  std_logic_vector(12 downto 0);
          usb_host_pie_PACKET_EVENT_TIMEOUT_FS_param : in  std_logic_vector(8 downto 0);
          usb_host_pie_PACKET_EVENT_TIMEOUT_HS_param : in  std_logic_vector(8 downto 0);

          usb_host_pie_portl1l2suspend_use_sync_n    : in  std_logic;



          -- core testability
          async_disable:        in    std_logic;
          testmode:        in    std_logic


      );
end component;
end ip_xxx_3515_hs_cmp_pkg;
