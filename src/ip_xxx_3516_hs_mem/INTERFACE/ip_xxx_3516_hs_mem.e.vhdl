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
--               File: ip_xxx_3516_hs_mem.e.vhdl
--
--             Author: Gaetan Marsin
--
--       Organisation: CentralR&D / Design Services / MSS - Connectivity
--
--              $Date: Sun Jun  2 23:57:37 2019 $
--
--            Project: Low gate count USB peripheral IP
--
--        Description:
--
--          $Revision: 1.30 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: ip_xxx_3516_hs_mem.e.vhdl.rca $
--   
--    Revision: 1.30 Sun Jun  2 23:57:37 2019 nxp57756
--    ws tag: update of soft ip tag fields, version set to svn://apc5008/projects/next0/ip_xxx_3516_hs_mem_sms/trunk.
--    
--
--    Revision: 1.2 Tue Jan  8 16:47:12 2013 beq03196
--    add features for host control.
--
--    Revision: 1.1 Thu Dec 13 11:27:06 2012 beq03196
--    1st version.
--
--
--
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ip_xxx_3516_hs_mem is
  generic(AHB_DATAWIDTH  : integer := 32;
          RAM_DATAWIDTH  : integer := 64;
	  RAM_ADDRWIDTH  : integer := 9;

	   C_PORTPOWER_CONTROL        : boolean := TRUE;
          C_PORTINDICATOR            : boolean := TRUE;

          C_NBPHYSEP     : integer := 14;
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
          C_ULPI_SUPPORT             : boolean := TRUE;
          C_UTMI_SUPPORT             : boolean := TRUE;
          C_EXTEND_TX_DELAY         : boolean := TRUE;
          G_SIM_CHIRP_TIMERS        : boolean := FALSE
	  );

  port(
       -- AHB bus signals


       dev_ahbs_hresetn     : in  std_logic;
       dev_ahbs_hclk        : in  std_logic;
       dev_ahbs_haddr           : in  std_logic_vector(5 downto 2);
       dev_ahbs_htrans   	    : in  std_logic_vector(1 downto 0);
       dev_ahbs_hwrite   	    : in  std_logic;
       dev_ahbs_hwdata   	    : in  std_logic_vector(31 downto 0);
       dev_ahbs_hsel     	    : in  std_logic;
       dev_ahbs_hreadyin 	    : in  std_logic;
       dev_ahbs_hrdata   	    : out std_logic_vector(31 downto 0);
       dev_ahbs_hreadyout	    : out std_logic;
       dev_ahbs_hresp    	    : out std_logic_vector(1 downto 0);

       host_ahbs_hresetn            : in  std_logic;
       host_ahbs_hclk               : in  std_logic;
       host_ahbs_haddr              : in  std_logic_vector(6 downto 2);
       host_ahbs_htrans   	    : in  std_logic_vector(1 downto 0);
       host_ahbs_hwrite   	    : in  std_logic;
       host_ahbs_hwdata   	    : in  std_logic_vector(31 downto 0);
       host_ahbs_hsel     	    : in  std_logic;
       host_ahbs_hreadyin 	    : in  std_logic;
       host_ahbs_hrdata   	    : out std_logic_vector(31 downto 0);
       host_ahbs_hreadyout	    : out std_logic;
       host_ahbs_hresp    	    : out std_logic_vector(1 downto 0);

       ahbs_dma_hresetn     : in  std_logic;
       ahbs_dma_hclk        : in  std_logic;
       ahbs_dma_haddr	    : in  std_logic_vector(RAM_ADDRWIDTH-1+5 downto 0);
       ahbs_dma_htrans      : in  std_logic_vector(1 downto 0);
       ahbs_dma_hwrite      : in  std_logic;
       ahbs_dma_hwdata      : in  std_logic_vector(AHB_DATAWIDTH-1 downto 0);
       ahbs_dma_hsel  	    : in  std_logic;
       ahbs_dma_hreadyin    : in  std_logic;
       ahbs_dma_hrdata      : out std_logic_vector(AHB_DATAWIDTH-1 downto 0);
       ahbs_dma_hreadyout   : out std_logic;
       ahbs_dma_hresp 	    : out std_logic_vector(1 downto 0);
       ahbs_dma_hsize	    : in  std_logic_vector(2 downto 0);
       ahbs_dma_hburst      : in  std_logic_vector(2 downto 0);

       -- RAM interface signals
       mem_q		    : in  std_logic_vector(RAM_DATAWIDTH-1 downto 0);
       mem_d		    : out std_logic_vector(RAM_DATAWIDTH-1 downto 0);
       mem_cs		    : out std_logic;
       mem_a		    : out std_logic_vector(RAM_ADDRWIDTH-1 downto 0);
       mem_web_out	    : out std_logic;
       mem_bsel             : out std_logic_vector (RAM_DATAWIDTH-1 downto 0);

       -- Interrupt controller signals
       dev_usb_int_req_irq:      out   std_logic;                      -- Irq interrupt
       dev_usb_Int_req_fiq:      out   std_logic;                      -- Fiq interrupt
       dev_usbframetoggle:      out   std_logic;
       host_usb_int_req_irq:      out   std_logic;                      -- Irq interrupt

       --Configuration status indicator
       USB_VBus:             in    std_logic;                      -- Bus power is present
       vbuscomp_on:          out   std_logic;                      -- Enable Analog Vbus comparators
       chrgvbus :           out   std_logic;
       dischrgvbus:         out   std_logic;
       avalid:               in    std_logic;                      -- ADPPROBE
       sessend:              in    std_logic;                      -- ADPSENSE

       --

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
       utmi_hostdisconnect          : in std_logic;
       utmi_id_enable               : out std_logic;
       utmi_id_value                : in std_logic;
       utmi_dppulldown              : out std_logic;
       utmi_dmpulldown              : out std_logic;
       pdcom                        : out std_logic;
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
       dev_usb_needclk                  : out std_logic;
       host_usb_needclk                  : out std_logic;
       dev_sys_donotwakeup_n            : in  std_logic;
       host_sys_donotwakeup_n            : in  std_logic;
       dev_sys_wakeup_n             : in  std_logic;
       dev_sys_utmi_clkin_lock          : in  std_logic;
       host_sys_utmi_clkin_lock          : in  std_logic;
       host_usb_overcurrent_n          : in  std_logic;
       host_usb_portindicator       : out std_logic_vector(1 downto 0);
       host_usb_portpower           : out std_logic;
       token_length_counter         : in  std_logic_vector(6 downto 0);
       usb_token_length             : out std_logic_vector(6 downto 0);


       -- synthesis read_comments_as_HDL on
       --ip_xxx_3516_hs_mem_fpga : out std_logic_vector(255 downto 0);
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

       usb_pie_INTER_PACKET_DELAY_FS_param   : in  std_logic_vector(4 downto 0);
       usb_pie_INTER_PACKET_DELAY_HS_param   : in  std_logic_vector(4 downto 0);
       usb_pie_PACKET_TURNAROUND_TIMEOUT_FS_param : in  std_logic_vector(7 downto 0);
       usb_pie_PACKET_TURNAROUND_TIMEOUT_HS_param : in  std_logic_vector(7 downto 0);
       usb_pie_PACKET_EVENT_TIMEOUT_FS_param : in  std_logic_vector(8 downto 0);
       usb_pie_PACKET_EVENT_TIMEOUT_HS_param : in  std_logic_vector(8 downto 0);

       -- OCP Recovery v1.1 Section 8.5 PIE arbiter byte-stream surface
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
       rec_ocp_path_disable : in  std_logic;

       -- core testability
       async_disable:        in    std_logic;
       testmode            : in    std_logic -- To be connected by integrator to a tcb test mode pin.

      );
-- VSIA_Soft_IP_Tag % Vendor NXP B.V. % Product ip_xxx_3516_hs_mem % Version svn://apc5008/projects/next0/ip_xxx_3516_hs_mem_sms/trunk % Metric 0 % Date_Time 20190602 % IP_Owner MCU % Celltype IP % Cell_Id ip_xxx_3516_hs_mem % Signature 0 % Tag_Spec cru45
end ip_xxx_3516_hs_mem;

