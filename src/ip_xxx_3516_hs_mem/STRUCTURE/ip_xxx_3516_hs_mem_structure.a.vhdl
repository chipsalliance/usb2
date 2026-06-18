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
--                    Copyright Message
--  ----------------------------------------------------------------------------
--
--  Philips confidential and proprietary.
--  COPYRIGHT (c) 2012 by NXP N.V.
--
--  All rights are reserved. Reproduction in whole or in part is
--  prohibited without the written consent of the copyright owner.
--
--  CoReUse 3.1 information header for HDL source files.
--
--  ----------------------------------------------------------------------------
--                    Design Information
--  ----------------------------------------------------------------------------
--
--  File            : ip_xxx_3516_hs_mem_structure.a.vhdl
--
--  Author          : $Author: usb00219 $
--
--  Organisation    : NXP Semiconductors/Corporate I & T/IP & Architecture/Connectivity/Leuven
--
--  Date            : $Date: Wed May 29 12:25:34 2019 $
--
--  Revision        : $Revision: 1.8 $
--
--  Project         : 3511_HS
--
--  Description     : ip_xxx_3516_hs_mem architecture
--
--  ----------------------------------------------------------------------------
--                    Revision History
--  ----------------------------------------------------------------------------
--
-- $Log: ip_xxx_3516_hs_mem_structure.a.vhdl.rca $
-- 
--  Revision: 1.8 Wed May 29 12:25:34 2019 usb00219
--  Added chicken bit for CDC crossing fix made for artf663122. Updates from Soong.
--  
--
--  Revision: 1.3 Wed Jan 23 15:34:42 2013 beq03196
--  utm/ulpi_clk are removed from the port mux for timing constrainst reasons.
--
--  Revision: 1.2 Tue Jan  8 16:46:52 2013 beq03196
--  replace fixed parametsr by configurables ones + features for host control
--
--  Revision: 1.1 Thu Dec 13 11:27:45 2012 beq03196
--  1st version.
--

--
--  ----------------------------------------------------------------------------
--                    Design Notes
--  ----------------------------------------------------------------------------
--
--  Design Unit     : <top_entity_or_package_name>
--
--  Sub-Units       : <list_of_instantiated_sub-units>
--
--  Compliance      : CoReUse Compliance Level <nr> (according to CoReUse 3.1)
--
--  Waivers         : <CoReUse_compliance_waivers>
--
--  Design Issues   : <potential_problems_and_limitations>
--
--  Critical Timing : <timing_critical_to_operation>
--
--  Simulation      : <target_simulator>
--
--  Synthesis       : <target_synthesis_tool>
--
--  Technology      : <technology_dependencies_and_portability_issues>
--
--  Special Notes   : <optional_additional_notes>
--
--  Input files     : <testbench data input files> (in testbench HDL files)
--
--  Output files    : <testbench data output files> (in testbench HDL files)
--
--  ----------------------------------------------------------------------------
library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library rtl;


architecture structure of ip_xxx_3516_hs_mem is

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

-- IP_3511_HS Digital controller BLOCK
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
          C_ULPI_SUPPORT             : boolean := TRUE;
          C_UTMI_SUPPORT             : boolean := TRUE;
          C_EXTEND_TX_DELAY          : boolean := FALSE;
          G_SIM_CHIRP_TIMERS         : boolean := FALSE);
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
       -- synthesis read_comments_as_HDL on
       --ip_xxx_3511_hs_fpga : out std_logic_vector(255 downto 0);
       -- synthesis read_comments_as_HDL off
       -- core testability
       usb_pie_INTER_PACKET_DELAY_FS_param   : in  std_logic_vector(4 downto 0);
       usb_pie_INTER_PACKET_DELAY_HS_param   : in  std_logic_vector(4 downto 0);
       usb_pie_PACKET_TURNAROUND_TIMEOUT_FS_param : in  std_logic_vector(7 downto 0);
       usb_pie_PACKET_TURNAROUND_TIMEOUT_HS_param : in  std_logic_vector(7 downto 0);
       usb_pie_PACKET_EVENT_TIMEOUT_FS_param : in  std_logic_vector(8 downto 0);
       usb_pie_PACKET_EVENT_TIMEOUT_HS_param : in  std_logic_vector(8 downto 0);

       -- OCP Recovery v1.1 Section 8.5 PIE arbiter surface
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

       async_disable:        in    std_logic;
       testmode:        in    std_logic

      );
  end component;

component ahb_dma_slave
generic(
        AHB_DATAWIDTH  : integer := 32;--32, 64
        RAM_DATAWIDTH  : integer := 64;--32, 64, 128, 256 (and must not be smaller than RAM_DATAWIDTH)
        RAM_ADDR_WIDTH : integer := 15 --256 KBytes max = 2**16 (if RAM_DATAWIDTH = 32 bits)
                                      --               = 2**15 (if RAM_DATAWIDTH = 64 bits)
                                      --               = 2**14 (if RAM_DATAWIDTH = 128 bits)
       );
port (
      ahb_dma_slave_fpga : out std_logic_vector(63 downto 0);
      --system input
      ads_hclk          : in  std_logic;
      ads_hresetn       : in  std_logic;
      --"dma" internal ip_3511 interface
      ads_dma_addr      : in  std_logic_vector(31 downto 0);
      ads_dma_req       : in  std_logic;
      ads_dma_gnt       : out std_logic;
      ads_dma_write     : in  std_logic;
      ads_dma_wdata     : in  std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      ads_dma_rdata     : out std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      ads_dma_dword_en  : in  std_logic_vector(1 downto 0);
      --sdram interface
      ads_mem_q         : in  std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      ads_mem_d         : out std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      ads_mem_cs        : out std_logic; --active high mem select
      ads_mem_a         : out std_logic_vector(RAM_ADDR_WIDTH-1 downto 0);
      ads_mem_web_out   : out std_logic; --active low write enable
      ads_mem_bsel      : out std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      --ahb slave interface
      ads_hsel          : in  std_logic;
      ads_haddr         : in  std_logic_vector((RAM_ADDR_WIDTH-1+5) downto 0); --+5 biggest ahb address size in case ahb=32 bits/ sram = 256 bits
      ads_hwrite        : in  std_logic;
      ads_htrans        : in  std_logic_vector(1 downto 0);
      ads_hsize         : in  std_logic_vector(2 downto 0); --bit 2 is unused as max ahb size is 64 bits.
      ads_hburst        : in  std_logic_vector(2 downto 0);
      ads_hwdata        : in  std_logic_vector(AHB_DATAWIDTH-1 downto 0);
      ads_hrdata        : out std_logic_vector(AHB_DATAWIDTH-1 downto 0);
      ads_hresp         : out std_logic_vector(1 downto 0);
      ads_hready_out    : out std_logic;
      ads_hready_in     : in  std_logic
      );
end component;


signal utmi_suspendm_int: std_logic;
signal dev_enable: std_logic;

signal dev_dma_addr : std_logic_vector(31 downto 0);
signal dev_dma_req : std_logic;
signal dev_dma_gnt : std_logic;
signal dev_dma_write : std_logic;
signal dev_dma_wdata : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal dev_dma_rdata : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal dev_dma_word_enable_read_write : std_logic_vector(RAM_DATAWIDTH/32-1 downto 0);
signal dev_dma_word_enable : std_logic_vector(RAM_DATAWIDTH/32-1 downto 0);

signal dev_utmi_clk 		    :   std_logic;
signal dev_utmi_rxdata		    :   std_logic_vector(7 downto 0);
signal dev_utmi_rxvalid	    :   std_logic;
signal dev_utmi_rxactive           :   std_logic;
signal dev_utmi_rxerror	    :   std_logic;
signal dev_utmi_txdata 	    :   std_logic_vector(7 downto 0);
signal dev_utmi_txvalid	    :   std_logic;
signal dev_utmi_txready	    :   std_logic;
signal dev_utmi_reset  	    :   std_logic;
signal dev_utmi_suspendm           :   std_logic;
signal dev_utmi_xcvrselect	    :   std_logic_vector(1 downto 0);
signal dev_utmi_termselect	    :   std_logic;
signal dev_utmi_opmode 	    :   std_logic_vector(1 downto 0);
signal dev_utmi_linestate	    :   std_logic_vector(1 downto 0);
signal dev_utmi_vcontrol	    :   std_logic_vector(3 downto 0);
signal dev_utmi_vcontrolloadm      :   std_logic;
signal dev_utmi_vstatus            :   std_logic_vector(7 downto 0);
--signal dev_utmi_hostdisconnect     :   std_logic;
signal dev_ulpi_clk		    :   std_logic;
signal dev_ulpi_rxdata 	    :   std_logic_vector(7 downto 0);
signal dev_ulpi_txdata 	    :   std_logic_vector(7 downto 0);
signal dev_ulpi_txenable	    :   std_logic;
signal dev_ulpi_dir		    :   std_logic;
signal dev_ulpi_stp		    :   std_logic;
signal dev_ulpi_nxt		    :   std_logic;
signal dev_ulpi_ddr_sel	    :   std_logic;
signal dev_vbusvalid               :   std_logic;
signal dev_vbuscomp_on : std_logic;
signal dev_sessend : std_logic;
signal dev_avalid : std_logic;
signal dev_chrgvbus : std_logic;
signal dev_dischrgvbus : std_logic;



signal host_dma_addr : std_logic_vector(31 downto 0);
signal host_dma_req : std_logic;
signal host_dma_gnt : std_logic;
signal host_dma_write : std_logic;
signal host_dma_wdata : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal host_dma_rdata : std_logic_vector(RAM_DATAWIDTH-1 downto 0);

signal host_utmi_clk 		    :   std_logic;
signal host_utmi_rxdata		    :   std_logic_vector(7 downto 0);
signal host_utmi_rxvalid	    :   std_logic;
signal host_utmi_rxactive           :   std_logic;
signal host_utmi_rxerror	    :   std_logic;
signal host_utmi_txdata 	    :   std_logic_vector(7 downto 0);
signal host_utmi_txvalid	    :   std_logic;
signal host_utmi_txready	    :   std_logic;
signal host_utmi_reset  	    :   std_logic;
signal host_utmi_suspendm           :   std_logic;
signal host_utmi_xcvrselect	    :   std_logic_vector(1 downto 0);
signal host_utmi_termselect	    :   std_logic;
signal host_utmi_opmode 	    :   std_logic_vector(1 downto 0);
signal host_utmi_linestate	    :   std_logic_vector(1 downto 0);
signal host_utmi_vcontrol	    :   std_logic_vector(3 downto 0);
signal host_utmi_vcontrolloadm      :   std_logic;
signal host_utmi_vstatus            :   std_logic_vector(7 downto 0);
signal host_utmi_hostdisconnect     :   std_logic;
signal host_ulpi_clk		    :   std_logic;
signal host_ulpi_rxdata 	    :   std_logic_vector(7 downto 0);
signal host_ulpi_txdata 	    :   std_logic_vector(7 downto 0);
signal host_ulpi_txenable	    :   std_logic;
signal host_ulpi_dir		    :   std_logic;
signal host_ulpi_stp		    :   std_logic;
signal host_ulpi_nxt		    :   std_logic;
signal host_ulpi_ddr_sel	    :   std_logic;
signal host_vbusvalid               :   std_logic;
signal host_utmi_id_value           :   std_logic;
signal host_utmi_id_enable          :   std_logic;

signal host_sw_ctrl_pdcom           : std_logic;
signal host_sw_pdcom                : std_logic;

signal dma_addr_int  : std_logic_vector(31 downto 0);
signal dma_req_int : std_logic;
signal dma_gnt_int : std_logic;
signal dma_write_int : std_logic;
signal dma_wdata_int : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal dma_rdata_int : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal dma_addr_from_dev_host_dma: std_logic_vector(31 downto 0);

signal mem_d_int                     : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal mem_cs_int                    : std_logic; --active high mem select
signal mem_a_int                     : std_logic_vector(RAM_ADDRWIDTH-1 downto 0);
signal mem_web_out_int               : std_logic; --active low write enable
signal mem_bsel_int                  : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal mem_dword_en                  : std_logic_vector(1 downto 0);
signal ahbs_dma_hrdata_int           : std_logic_vector(AHB_DATAWIDTH-1 downto 0);
signal ahbs_dma_hresp_int            : std_logic_vector(1 downto 0);
signal ahbs_dma_hreadyout_int        : std_logic;

signal dma_addr_from_usb_dma  : std_logic_vector(31 downto 0);
signal ahb_dma_slave_fpga  : std_logic_vector(63 downto 0);

signal ip_xxx_3515_hs_fpga : std_logic_vector(255 downto 0);
signal ip_xxx_3511_hs_fpga : std_logic_vector(255 downto 0);

  begin

 ip_xxx_3515_hs_inst : ip_xxx_3515_hs
   generic map(
           C_ULPI_SUPPORT       => C_ULPI_SUPPORT,
           C_UTMI_SUPPORT       => C_UTMI_SUPPORT,
           RAM_ADDRWIDTH        => RAM_ADDRWIDTH,
           C_PORTPOWER_CONTROL  => C_PORTPOWER_CONTROL,
           C_PORTINDICATOR      => C_PORTINDICATOR
         --  C_FILT_VBUS         => FALSE  -- false for simulation only)
           )
   port map(
        -- AHB bus signals
        hclk              => host_ahbs_hclk,
        hresetn           => host_ahbs_hresetn,
        vbusvalid         => host_vbusvalid ,

        ahbs_haddr        => host_ahbs_haddr,
        ahbs_htrans   	  => host_ahbs_htrans,
        ahbs_hwrite   	  => host_ahbs_hwrite,
        ahbs_hwdata   	  => host_ahbs_hwdata,
        ahbs_hsel     	  => host_ahbs_hsel,
        ahbs_hreadyin 	  => host_ahbs_hreadyin,
        ahbs_hrdata   	  => host_ahbs_hrdata,
        ahbs_hreadyout	  => host_ahbs_hreadyout,
        ahbs_hresp    	  => host_ahbs_hresp,

        usbram_addr	     => host_dma_addr ,
	usbram_req	     => host_dma_req  ,
	usbram_gnt	     => host_dma_gnt  ,
	usbram_write	     => host_dma_write,
	usbram_wdata	     => host_dma_wdata,
	usbram_rdata	     => host_dma_rdata,
        --usbram_word_enable     => host_dma_word_enable,

        USB_Int_Req_Irq    => host_usb_int_req_irq,
        utmi_clk 	  =>  host_utmi_clk,
        utmi_rxdata	   => host_utmi_rxdata,
        utmi_rxvalid	   => host_utmi_rxvalid,
        utmi_rxactive	   => host_utmi_rxactive,
        utmi_rxerror	   => host_utmi_rxerror,
        utmi_txdata	   => host_utmi_txdata,
        utmi_txvalid	   => host_utmi_txvalid,
        utmi_txready	   => host_utmi_txready,
        utmi_reset	   => host_utmi_reset,
        utmi_suspendm	   => host_utmi_suspendm,
        utmi_xcvrselect    => host_utmi_xcvrselect,
        utmi_termselect    => host_utmi_termselect,
        utmi_opmode	   => host_utmi_opmode,
        utmi_linestate	   => host_utmi_linestate,
        utmi_vcontrol      => host_utmi_vcontrol,
        utmi_vcontrolloadm => host_utmi_vcontrolloadm,
        utmi_vstatus       => host_utmi_vstatus,
        utmi_hostdisconnect=> host_utmi_hostdisconnect,
        utmi_id_enable     => host_utmi_id_enable,
        utmi_id_value      => host_utmi_id_value,
        ulpi_clk           => host_ulpi_clk,
        ulpi_rxdata        => host_ulpi_rxdata,
        ulpi_txdata        => host_ulpi_txdata,
        ulpi_txenable      => host_ulpi_txenable,
        ulpi_dir           => host_ulpi_dir,
        ulpi_stp           => host_ulpi_stp,
        ulpi_nxt           => host_ulpi_nxt,
        ulpi_ddr_sel       => host_ulpi_ddr_sel,
        usb_needclk        => host_usb_needclk  ,
        sys_donotwakeup_n  => host_sys_donotwakeup_n,
        sys_utmi_clkin_lock => host_sys_utmi_clkin_lock,
        dev_enable          => dev_enable,
        usb_overcurrent_n  => host_usb_overcurrent_n,
        usb_portindicator  => host_usb_portindicator,
        usb_portpower      => host_usb_portpower,
        sw_ctrl_pdcom      => host_sw_ctrl_pdcom,
	sw_pdcom           => host_sw_pdcom,

        -- synthesis read_comments_as_HDL on
        --  ip_xxx_3515_hs_fpga => ip_xxx_3515_hs_fpga,
        -- synthesis read_comments_as_HDL off

        usb_host_pie_INTER_PACKET_DELAY_LS_param => usb_host_pie_INTER_PACKET_DELAY_LS_param,
        usb_host_pie_INTER_PACKET_DELAY_FS_param => usb_host_pie_INTER_PACKET_DELAY_FS_param,
        usb_host_pie_INTER_PACKET_DELAY_HS_param => usb_host_pie_INTER_PACKET_DELAY_HS_param,
        usb_host_pie_PACKET_TURNAROUND_TIMEOUT_LS_param => usb_host_pie_PACKET_TURNAROUND_TIMEOUT_LS_param,
        usb_host_pie_PACKET_TURNAROUND_TIMEOUT_FS_param => usb_host_pie_PACKET_TURNAROUND_TIMEOUT_FS_param,
        usb_host_pie_PACKET_TURNAROUND_TIMEOUT_HS_param => usb_host_pie_PACKET_TURNAROUND_TIMEOUT_HS_param,
        usb_host_pie_PACKET_EVENT_TIMEOUT_LS_param => usb_host_pie_PACKET_EVENT_TIMEOUT_LS_param,
        usb_host_pie_PACKET_EVENT_TIMEOUT_FS_param => usb_host_pie_PACKET_EVENT_TIMEOUT_FS_param,
        usb_host_pie_PACKET_EVENT_TIMEOUT_HS_param => usb_host_pie_PACKET_EVENT_TIMEOUT_HS_param,
        usb_host_pie_portl1l2suspend_use_sync_n    => usb_host_pie_portl1l2suspend_use_sync_n,

        async_disable      => async_disable,
        testmode           => testmode
      );


  ip_xxx_3511_hs_inst : ip_xxx_3511_hs
  generic map(C_NBPHYSEP     => C_NBPHYSEP,
          C_EPUB             => C_EPUB,
          C_DAUB             => C_DAUB, --Requirement : C_DAUB > C_DALB
          C_DALB             => C_DALB, --maximum allowed value is 17
                                          --minimum allowed value is 7
          C_EPFIFO_PAGE     => C_EPFIFO_PAGE     ,
          C_DATAFIFO_PAGE   => C_DATAFIFO_PAGE,
          C_SINGLE_BUFFER_SUPPORTED =>  C_SINGLE_BUFFER_SUPPORTED,
          C_DOUBLE_BUFFER_SUPPORTED =>  C_DOUBLE_BUFFER_SUPPORTED,
          C_TOGGLE_REG_READABLE    => C_TOGGLE_REG_READABLE,
          C_PLL_ENABLE             => C_PLL_ENABLE,
          C_PLL_DIVIDER            => C_PLL_DIVIDER,
          C_ULPI_SUPPORT           => C_ULPI_SUPPORT,
          C_UTMI_SUPPORT           => C_UTMI_SUPPORT,
          C_EXTEND_TX_DELAY        => C_EXTEND_TX_DELAY,
          G_SIM_CHIRP_TIMERS       => G_SIM_CHIRP_TIMERS)
          port map (

      hclk                   => dev_ahbs_hclk,
      hresetn                => dev_ahbs_hresetn,
      ahbs_haddr             => dev_ahbs_haddr,
      ahbs_htrans            => dev_ahbs_htrans,
      ahbs_hwdata            => dev_ahbs_hwdata,
      ahbs_hwrite            => dev_ahbs_hwrite,
      ahbs_hsel              => dev_ahbs_hsel,
      ahbs_hreadyin          => dev_ahbs_hreadyin,
      ahbs_hreadyout         => dev_ahbs_hreadyout,
      ahbs_hrdata            => dev_ahbs_hrdata,
      ahbs_hresp             => dev_ahbs_hresp,

      usbram_addr	     => dev_dma_addr ,
      usbram_req	     => dev_dma_req  ,
      usbram_gnt	     => dev_dma_gnt  ,
      usbram_write	     => dev_dma_write,
      usbram_wdata	     => dev_dma_wdata,
      usbram_rdata	     => dev_dma_rdata,
      usbram_word_enable     => dev_dma_word_enable_read_write,


      USB_Int_Req_Irq        => dev_usb_int_req_irq,
      USB_Int_Req_Fiq        => dev_usb_int_req_fiq,
      USB_FrameToggle        => dev_usbframetoggle,
      utmi_clk               => dev_utmi_clk,
      utmi_reset             => dev_utmi_reset,
      utmi_xcvrselect        => dev_utmi_xcvrselect(0),
      utmi_termselect        => dev_utmi_termselect,
      utmi_linestate         => dev_utmi_linestate,
      utmi_opmode            => dev_utmi_opmode,
      utmi_txdata            => dev_utmi_txdata,
      utmi_txvalid           => dev_utmi_txvalid,
      utmi_txready           => dev_utmi_txready,
      utmi_rxdata            => dev_utmi_rxdata,
      utmi_rxvalid           => dev_utmi_rxvalid, --utmi_rxvalid
      utmi_rxactive          => dev_utmi_rxactive,
      utmi_rxerror           => dev_utmi_rxerror,
      USB_VBus               => dev_vbusvalid, --usb_vbus
      vbuscomp_on            => dev_vbuscomp_on,
      chrg_vbus              => dev_chrgvbus,
      dischrg_vbus           => dev_dischrgvbus,
      avalid                 => dev_avalid,
      sessend                => dev_sessend,
      utmi_suspendm          => dev_utmi_suspendm,
      ulpi_clk  	     => dev_ulpi_clk,
      ulpi_rxdata	     => dev_ulpi_rxdata,
      ulpi_txdata	     => dev_ulpi_txdata,
      ulpi_txenable	     => dev_ulpi_txenable,
      ulpi_dir  	     => dev_ulpi_dir,
      ulpi_stp  	     => dev_ulpi_stp,
      ulpi_nxt  	     => dev_ulpi_nxt,
      ulpi_ddr_sel	     => dev_ulpi_ddr_sel,
      -- System interface
      usb_needclk	     => dev_usb_needclk  ,
      sys_donotwakeup_n      => dev_sys_donotwakeup_n,
      sys_dev_wakeup_n       => dev_sys_wakeup_n ,
      sys_utmi_clkin_lock    => dev_sys_utmi_clkin_lock,
      utmi_vcontrol	     => dev_utmi_vcontrol,
      utmi_vcontrolloadm     => dev_utmi_vcontrolloadm,
      utmi_vstatus	     => dev_utmi_vstatus,
      token_length_counter   => token_length_counter,
      usb_token_length       => usb_token_length,
       -- synthesis read_comments_as_HDL on
       --ip_xxx_3511_hs_fpga    => ip_xxx_3511_hs_fpga,
       -- synthesis read_comments_as_HDL off
      -- core testability
      usb_pie_INTER_PACKET_DELAY_FS_param   => usb_pie_INTER_PACKET_DELAY_FS_param, 
      usb_pie_INTER_PACKET_DELAY_HS_param   => usb_pie_INTER_PACKET_DELAY_HS_param,
      usb_pie_PACKET_TURNAROUND_TIMEOUT_FS_param => usb_pie_PACKET_TURNAROUND_TIMEOUT_FS_param,
      usb_pie_PACKET_TURNAROUND_TIMEOUT_HS_param => usb_pie_PACKET_TURNAROUND_TIMEOUT_HS_param,
      usb_pie_PACKET_EVENT_TIMEOUT_FS_param => usb_pie_PACKET_EVENT_TIMEOUT_FS_param,
      usb_pie_PACKET_EVENT_TIMEOUT_HS_param => usb_pie_PACKET_EVENT_TIMEOUT_HS_param,

      -- OCP Recovery v1.1 Section 8.5 PIE arbiter surface (passthrough)
      rec_setup_pkt_vld   => rec_setup_pkt_vld,
      rec_setup_pkt       => rec_setup_pkt,
      rec_ctrl_out_data   => rec_ctrl_out_data,
      rec_ctrl_out_be   => rec_ctrl_out_be,
      rec_ctrl_out_vld    => rec_ctrl_out_vld,
      rec_ctrl_out_last   => rec_ctrl_out_last,
      rec_ctrl_out_rdy    => rec_ctrl_out_rdy,
      rec_ctrl_in_data    => rec_ctrl_in_data,
      rec_ctrl_in_be    => rec_ctrl_in_be,
      rec_ctrl_in_vld     => rec_ctrl_in_vld,
      rec_ctrl_in_last    => rec_ctrl_in_last,
      rec_ctrl_in_rdy     => rec_ctrl_in_rdy,
      rec_ctrl_set_stall  => rec_ctrl_set_stall,
      rec_ctrl_xfer_done  => rec_ctrl_xfer_done,
      rec_ctrl_claim      => rec_ctrl_claim,

      async_disable	     => async_disable,
      testmode	             => testmode

      );

      dev_utmi_xcvrselect(1) <= '0'; --device only
--    pdcom assignment needs to be corrected
--    For the time being, to get SMS PHY NL testcases passing, pdcom will be fixed to 0.
--    See artifact SC42361 in USB_FS PRCR database
      pdcom <=  not(utmi_suspendm_int) when host_sw_ctrl_pdcom = '0' else host_sw_pdcom;
--      pdcom <= '0';
      utmi_suspendm <= utmi_suspendm_int;

mux_phy_ifce_proc: process (dev_enable,
utmi_clk,utmi_rxdata,utmi_rxvalid,utmi_rxactive,utmi_rxerror,utmi_txready,utmi_linestate,utmi_vstatus,
ulpi_clk,ulpi_rxdata,ulpi_dir,ulpi_nxt,ulpi_ddr_sel,
dev_utmi_txdata,dev_utmi_txvalid,dev_utmi_reset,dev_utmi_xcvrselect,dev_utmi_termselect,dev_utmi_opmode,
dev_utmi_vcontrol,dev_utmi_vcontrolloadm,
dev_ulpi_txdata,dev_ulpi_txenable,dev_ulpi_stp,
host_utmi_txdata,host_utmi_txvalid,host_utmi_reset,host_utmi_xcvrselect,host_utmi_termselect,host_utmi_opmode,
host_utmi_vcontrol,host_utmi_vcontrolloadm,
host_ulpi_txdata,host_ulpi_txenable,host_ulpi_stp,dev_vbuscomp_on,dev_chrgvbus,dev_dischrgvbus,avalid,sessend,USB_VBus,utmi_hostdisconnect,
utmi_id_value,host_utmi_id_enable)
 begin
 -- default values
    dev_utmi_clk <= utmi_clk;
    dev_utmi_rxdata <= (others => '0');
    dev_utmi_rxvalid <= '0';
    dev_utmi_rxactive <= '0';
    dev_utmi_rxerror <= '0';
    dev_utmi_txready <= '0';
    dev_utmi_linestate <= (others => '0');
    dev_utmi_vstatus <= (others => '0');
    dev_ulpi_clk <= ulpi_clk;
    dev_ulpi_rxdata <= (others => '0');
    dev_ulpi_dir <= '0';
    dev_ulpi_nxt <= '0';
    dev_ulpi_ddr_sel <= '0';
    dev_vbusvalid      <= '0';
    dev_avalid         <= avalid;
    dev_sessend        <= sessend;

    host_utmi_clk <= utmi_clk;
    host_utmi_rxdata <= (others => '0');
    host_utmi_rxvalid <= '0';
    host_utmi_rxactive <= '0';
    host_utmi_rxerror <= '0';
    host_utmi_txready <= '0';
    host_utmi_linestate <= (others => '0');
    host_utmi_vstatus <= (others => '0');
    host_ulpi_clk <= ulpi_clk;
    host_ulpi_rxdata <= (others => '0');
    host_ulpi_dir <= '0';
    host_ulpi_nxt <= '0';
    host_ulpi_ddr_sel <= '0';
    host_vbusvalid      <= '0';
    host_utmi_hostdisconnect <= '0';
    host_utmi_id_value <= utmi_id_value; -- handled by Host Register Interface Only
    utmi_id_enable  <= host_utmi_id_enable; -- handled by Host Register Interface Only

    if dev_enable = '1' then
    -- UTMI INTERFACE
     --  dev_utmi_clk       <= utmi_clk;
       dev_utmi_rxdata    <= utmi_rxdata;
       dev_utmi_rxvalid   <= utmi_rxvalid;
       dev_utmi_rxactive  <= utmi_rxactive;
       dev_utmi_rxerror	  <= utmi_rxerror;
       utmi_txdata        <= dev_utmi_txdata;
       utmi_txvalid       <= dev_utmi_txvalid;
       dev_utmi_txready	  <= utmi_txready;
       utmi_reset         <= dev_utmi_reset;
--       utmi_suspendm_int  <= dev_utmi_suspendm;
       utmi_xcvrselect    <= dev_utmi_xcvrselect;
       utmi_termselect    <= dev_utmi_termselect;
       utmi_opmode	  <= dev_utmi_opmode;
       dev_utmi_linestate <= utmi_linestate;
       utmi_vcontrol      <= dev_utmi_vcontrol;
       utmi_vcontrolloadm <= dev_utmi_vcontrolloadm;
       dev_utmi_vstatus   <= utmi_vstatus;
       dev_vbusvalid      <= USB_VBus;
       vbuscomp_on        <= dev_vbuscomp_on;
       chrgvbus           <= dev_chrgvbus;
       dischrgvbus        <= dev_dischrgvbus;
       utmi_dppulldown         <= '0';
       utmi_dmpulldown         <= '0';
    -- ULPI INTERFACE
   --    dev_ulpi_clk       <= ulpi_clk;
       dev_ulpi_rxdata    <= ulpi_rxdata;
       ulpi_txdata        <= dev_ulpi_txdata;
       ulpi_txenable      <= dev_ulpi_txenable;
       dev_ulpi_dir       <= ulpi_dir;
       ulpi_stp           <= dev_ulpi_stp;
       dev_ulpi_nxt       <= ulpi_nxt;
       dev_ulpi_ddr_sel   <= ulpi_ddr_sel;
    else
-- UTMI INTERFACE
      -- host_utmi_clk       <= utmi_clk;
       host_utmi_rxdata    <= utmi_rxdata;
       host_utmi_rxvalid   <= utmi_rxvalid;
       host_utmi_rxactive  <= utmi_rxactive;
       host_utmi_rxerror   <= utmi_rxerror;
       utmi_txdata         <= host_utmi_txdata;
       utmi_txvalid        <= host_utmi_txvalid;
       host_utmi_txready   <= utmi_txready;
       utmi_reset          <= host_utmi_reset;
--       utmi_suspendm_int   <= host_utmi_suspendm;
       utmi_xcvrselect     <= host_utmi_xcvrselect;
       utmi_termselect     <= host_utmi_termselect;
       utmi_opmode	   <= host_utmi_opmode;
       host_utmi_linestate <= utmi_linestate;
       utmi_vcontrol       <= host_utmi_vcontrol;
       utmi_vcontrolloadm  <= host_utmi_vcontrolloadm;
       host_utmi_vstatus   <= utmi_vstatus;
       host_vbusvalid      <= USB_VBus;
       vbuscomp_on         <= '1';
       chrgvbus            <= '0';
       dischrgvbus         <= '0';
       utmi_dppulldown          <= '1';
       utmi_dmpulldown          <= '1';
       host_utmi_hostdisconnect <= utmi_hostdisconnect;
    -- ULPI INTERFACE
     --  host_ulpi_clk       <= ulpi_clk;
       host_ulpi_rxdata    <= ulpi_rxdata;
       ulpi_txdata         <= host_ulpi_txdata;
       ulpi_txenable       <= host_ulpi_txenable;
       host_ulpi_dir       <= ulpi_dir;
       ulpi_stp            <= host_ulpi_stp;
       host_ulpi_nxt       <= ulpi_nxt;
       host_ulpi_ddr_sel   <= ulpi_ddr_sel;
    end if;

 end process mux_phy_ifce_proc;

-- BVE : update for Aruba metal change
-- drive utmi_suspendm_int low only when both host and device suspend lines are low
utmi_suspendm_int  <= dev_utmi_suspendm or host_utmi_suspendm;

ahb_dma_slave_1 : ahb_dma_slave
  generic map(
              AHB_DATAWIDTH  => AHB_DATAWIDTH,
              RAM_DATAWIDTH  => RAM_DATAWIDTH,
              RAM_ADDR_WIDTH => RAM_ADDRWIDTH
              )
  port map  (
            ahb_dma_slave_fpga  => ahb_dma_slave_fpga,
            ads_hclk            => ahbs_dma_hclk,
            ads_hresetn         => ahbs_dma_hresetn,
            ads_dma_addr        => dma_addr_int,
            ads_dma_req         => dma_req_int,
            ads_dma_gnt         => dma_gnt_int,
            ads_dma_write       => dma_write_int,
            ads_dma_wdata       => dma_wdata_int,
            ads_dma_rdata       => dma_rdata_int,
	    ads_dma_dword_en    => mem_dword_en,
            ads_mem_q           => mem_q,
            ads_mem_d           => mem_d_int,
            ads_mem_cs          => mem_cs_int,
            ads_mem_a           => mem_a_int,
            ads_mem_web_out     => mem_web_out_int,
	    ads_mem_bsel        => mem_bsel_int,
            ads_hsel            => ahbs_dma_hsel,
            ads_haddr           => ahbs_dma_haddr,
            ads_hwrite          => ahbs_dma_hwrite,
            ads_htrans          => ahbs_dma_htrans,
            ads_hsize           => ahbs_dma_hsize,
            ads_hburst          => ahbs_dma_hburst,
            ads_hwdata          => ahbs_dma_hwdata,
            ads_hrdata          => ahbs_dma_hrdata_int,
            ads_hresp           => ahbs_dma_hresp_int,
            ads_hready_out      => ahbs_dma_hreadyout_int,
            ads_hready_in       => ahbs_dma_hreadyin
            );

dma_addr_int(17 downto 0) <= dma_addr_from_dev_host_dma(17 downto 0);
dma_addr_int(31 downto 18) <= (others => '0');

dev_dma_word_enable <= dev_dma_word_enable_read_write when (dma_req_int = '1') and (dma_write_int = '1') else (others => '1');


  mem_d <= mem_d_int;
  mem_cs <= mem_cs_int;
  mem_a <= mem_a_int;
  mem_web_out <= mem_web_out_int;
  mem_bsel    <= mem_bsel_int;
  ahbs_dma_hrdata <= ahbs_dma_hrdata_int;
  ahbs_dma_hresp <= ahbs_dma_hresp_int;
  ahbs_dma_hreadyout <= ahbs_dma_hreadyout_int;

 mux_ahb_dma_slave_proc: process (dev_enable,dev_dma_addr,host_dma_addr,dev_dma_req,
 host_dma_req,dma_gnt_int,dma_rdata_int,host_dma_write,host_dma_wdata,dev_dma_write,dev_dma_wdata,dev_dma_word_enable )
 begin
 -- default values
    dev_dma_gnt <= '0';
    host_dma_gnt <= '0';
    dev_dma_rdata <= (others => '0');
    host_dma_rdata <= (others => '0');
    if dev_enable = '1' then
       dma_addr_from_dev_host_dma <= dev_dma_addr;
       dma_req_int <= dev_dma_req;
       dev_dma_gnt <= dma_gnt_int;
       dma_write_int <= dev_dma_write;
       dma_wdata_int <= dev_dma_wdata;
       dev_dma_rdata <= dma_rdata_int;
       mem_dword_en <= dev_dma_word_enable;
    else
       dma_addr_from_dev_host_dma <= host_dma_addr;
       dma_req_int <= host_dma_req;
       host_dma_gnt <= dma_gnt_int;
       dma_write_int <= host_dma_write;
       dma_wdata_int <= host_dma_wdata;
       host_dma_rdata <= dma_rdata_int;
       mem_dword_en <= (others => '1');
    end if;

 end process mux_ahb_dma_slave_proc;

-- synthesis read_comments_as_HDL on
--ip_xxx_3516_hs_mem_fpga(127 downto 0) <= ip_xxx_3511_hs_fpga(127 downto 0);
--ip_xxx_3516_hs_mem_fpga(254 downto 128) <= ip_xxx_3515_hs_fpga(126 downto 0);
--ip_xxx_3516_hs_mem_fpga(255) <=  dev_enable;
-- synthesis read_comments_as_HDL off

end structure;

----------------------------------------------------------------------
library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library rtl;

configuration ip_xxx_3516_hs_mem_structure_cfg of ip_xxx_3516_hs_mem is
  for structure
    for ip_xxx_3515_hs_inst: ip_xxx_3515_hs
       use configuration rtl.ip_xxx_3515_hs_structure_cfg;
    end for;
    for ip_xxx_3511_hs_inst: ip_xxx_3511_hs
       use configuration rtl.ip_xxx_3511_hs_structure_cfg;
    end for;
    for ahb_dma_slave_1 : ahb_dma_slave
       use entity rtl.ahb_dma_slave(rtl);
    end for;
  end for;
end ip_xxx_3516_hs_mem_structure_cfg;

