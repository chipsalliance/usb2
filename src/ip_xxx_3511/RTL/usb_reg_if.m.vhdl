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
--   COPYRIGHT (c) NXP B.V. 2009
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
--               File: usb_fs_reg_if.m.vhdl
--
--             Author: Bart Vertenten
--
--       Organisation: Corporate I&T / IP & Architecture
--
--              $Date: Sun Apr 23 19:20:43 2017 $
--
--            Project: IP_3511 - Low gate count USB peripheral IP
--
--        Description:
--
--          $Revision: 1.5 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_reg_if.m.vhdl.rca $
--   
--    Revision: 1.5 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.16 Thu Dec 13 11:40:35 2012 beq03196
--    uncomplete sensitivity list.
--
--    Revision: 1.15 Thu Nov  8 11:01:38 2012 beq03196
--    Fix CR#82: CR - add bits for new OTG features
--
--    Revision: 1.14 Tue Oct 23 17:05:09 2012 beq03196
--    CR# 84: CR - add bit such that SW can overwrite VBusValid indication from PHY
--
--    Revision: 1.13 Fri Dec  2 15:55:46 2011 beq03196
--    Fix PR#68: ip_3511 : ULPI Interface: disconnect device not always detected on FPGA
--
--    Revision: 1.12 Wed Oct 12 13:59:48 2011 beq03067
--    Added fpga controls.
--
--    Revision: 1.11 Mon Sep 19 06:59:36 2011 beq03067
--    added usb_reg_if_fpga
--
--    Revision: 1.10 Fri Sep 16 10:27:19 2011 beq03099
--    make sure that output usbreg_phy_mode always reflects the correct value.
--    Also if only one PHY interface is enabled
--
--    Revision: 1.9 Thu Sep 15 09:51:41 2011 beq03196
--    Fix PR#41: Clocks do not restart when 3511_hs is attached to USB
--
--    Revision: 1.8 Thu Jun 16 14:22:59 2011 beq03099
--    fixed array shape mismatch
--
--    Revision: 1.7 Thu Jun 16 14:14:36 2011 beq03099
--    fixed typo
--
--    Revision: 1.6 Thu Jun 16 13:56:27 2011 beq03099
--    added phy register interface
--
--    Revision: 1.5 Wed May  4 14:59:51 2011 beq03099
--    fixed problem with inrush current
--    only turn off PLL when VBusDebounced and VBusAvailable have the same value
--
--    Revision: 1.4 Thu Feb 24 09:33:22 2011 beq03099
--    removed usb_cfg package
--
--    Revision: 1.3 Fri Feb 18 11:01:40 2011 beq03099
--    fixed bit width problem
--
--    Revision: 1.2 Thu Feb 10 13:18:33 2011 beq03099
--    added new registers phy_test_mode and pie_speed
--
--    Revision: 1.1 Thu Feb 10 12:24:25 2011 beq03099
--    adapted for HS version
--
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

library rtl;
use rtl.usb_configuration_subcmp_pkg.all;

entity usb_reg_if is
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
        C_TOGGLE_REG_READABLE    : boolean := TRUE;
        C_PLL_ENABLE             : boolean := FALSE;
        C_PLL_DIVIDER            : std_logic_vector(6 downto 0) := "0010100";
        C_MINOR_REV              : std_logic_vector(7 downto 0) := X"00";
        C_MAJOR_REV              : std_logic_vector(7 downto 0) := X"00"
        );
port (
      hclk                     : in  std_logic;
      hresetn                  : in  std_logic;
      USB_Int_Req_Irq          : out std_logic;
      USB_Int_Req_Fiq          : out std_logic;

      -- interface to AHB slave module
      reg_waddr                : in  std_logic_vector(3 downto 0);
      reg_wdata                : in  std_logic_vector(31 downto 0);
      reg_raddr                : in  std_logic_vector(3 downto 0);
      reg_rdata                : out std_logic_vector(31 downto 0);
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
      usbreg_epinfo_toggle     : out std_logic_vector(C_NBPHYSEP+1 downto 0);
      usbreg_port_force_fullspeed : out std_logic;
      dma_clear_toggle         : in  std_logic;
      dma_set_toggle           : in  std_logic;
      dma_sent_NAK             : in  std_logic;
      dma_set_int              : in  std_logic;
      dma_physepnr             : in  integer range 0 to C_NBPHYSEP+1;
      dma_clear_skip           : in  std_logic;
      dma_skip_ep              : in  integer range 0 to C_NBPHYSEP+1;
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
      usbreg_vbuscomp_on       : out std_logic;                      -- Enable Analog Vbus comparators
      usbreg_chrg_vbus         : out std_logic;
      usbreg_dischrg_vbus      : out std_logic;
      sync_avalid              : in  std_logic;                      -- ADPPROBE
      sync_sessend             : in  std_logic;                      -- ADPSENSE
      usbreg_phy_addr          : out std_logic_vector(7 downto 0);
      usbreg_phy_wdata         : out std_logic_vector(7 downto 0);
      sync_phy_rdata           : in  std_logic_vector(7 downto 0);
      usbreg_phy_write         : out std_logic;
      usbreg_phy_start         : out std_logic;
      usbreg_phy_mode          : out std_logic;
      sync_phy_endtoggle       : in  std_logic;
      usb_reg_if_fpga          : out std_logic_vector(63 downto 0)
      );
end usb_reg_if;

architecture RTL of usb_reg_if is

signal reg_dev_addr              : std_logic_vector(6 downto 0);
signal reg_dev_addr_tmp          : std_logic_vector(6 downto 0);
signal reg_dev_enable            : std_logic;
signal reg_dev_setup             : std_logic;
signal reg_dev_pll_on            : std_logic;
signal reg_dev_force_vbus        : std_logic;
signal reg_dev_lpm_sup           : std_logic;
signal reg_dev_intnak_ao         : std_logic;
signal reg_dev_intnak_ai         : std_logic;
signal reg_dev_intnak_co         : std_logic;
signal reg_dev_intnak_ci         : std_logic;
signal reg_dev_connect           : std_logic;
signal reg_dev_suspend           : std_logic;
signal reg_dev_lpm_suspend       : std_logic;
signal reg_dev_lpm_remote_wake   : std_logic;
signal reg_dev_connect_change    : std_logic;
signal reg_dev_suspend_change    : std_logic;
signal reg_dev_reset_change      : std_logic;
signal reg_dev_phy_test_mode     : std_logic_vector(2 downto 0);
signal reg_info_frame_number     : std_logic_vector(10 downto 0);
signal reg_info_err_code         : std_logic_vector(3 downto 0);
signal reg_ep_fifo_addr_offset   : std_logic_vector(C_EPUB-9 downto 0);
signal reg_data_fifo_addr_offset : std_logic_vector(C_DAUB-C_DALB-1 downto 0);
signal reg_lpm_hird_hw           : std_logic_vector(3 downto 0);
signal reg_lpm_hird_sw           : std_logic_vector(3 downto 0);
signal reg_lpm_nyet              : std_logic;
signal reg_ep_skip               : std_logic_vector(C_NBPHYSEP+1 downto 0);
signal reg_ep_bufinuse           : std_logic_vector(C_NBPHYSEP+1 downto 0);
signal reg_ep_doublebuffer       : std_logic_vector(C_NBPHYSEP+1 downto 0);
signal reg_ep_int_status         : std_logic_vector(C_NBPHYSEP+1 downto 0);
signal reg_frame_int_status      : std_logic;
signal reg_dev_int_status        : std_logic;
signal reg_ep_int_enable         : std_logic_vector(C_NBPHYSEP+1 downto 0);
signal reg_frame_int_enable      : std_logic;
signal reg_dev_int_enable        : std_logic;
signal reg_ep_int_route          : std_logic_vector(C_NBPHYSEP+1 downto 0);
signal reg_frame_int_route       : std_logic;
signal reg_dev_int_route         : std_logic;
signal reg_ep_toggle_value       : std_logic_vector(C_NBPHYSEP+1 downto 0);
signal usbreg_dev_connect_int    : std_logic;
signal usbreg_dev_connect_int_z  : std_logic;
signal sync_suspend_z            : std_logic;
signal sync_lpm_suspend_z        : std_logic;
signal irq_int                   : std_logic;
signal fiq_int                   : std_logic;
signal sync_sieint_error_z       : std_logic;
signal reg_ext_clk_enable        : std_logic;
signal bufinuse                  : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal reg_phy_addr              : std_logic_vector(7 downto 0);
signal reg_phy_wdata             : std_logic_vector(7 downto 0);
signal reg_phy_rdata             : std_logic_vector(7 downto 0);
signal reg_phy_write             : std_logic;
signal reg_phy_start             : std_logic;
signal reg_phy_mode              : std_logic;
signal reg_phy_addr_lower_nib    : std_logic_vector(3 downto 0);
signal reg_phy_addr_higher_nib   : std_logic_vector(3 downto 0);
signal sync_avalid_z             : std_logic;
signal sync_sessend_z            : std_logic;
signal reg_vbuscomp_off          : std_logic;
signal reg_chrg_vbus             : std_logic;
signal reg_dischrg_vbus          : std_logic;
signal reg_dev_otg_change        : std_logic;
signal reg_dev_force_fullspeed   : std_logic;

begin

-- -----------------------------------------------------------------------
-- Output signal to other blocks
-- -----------------------------------------------------------------------


-- a token must be accepted if the received address is the same of one of the
-- two usbaddress signals. Only during a SetAddress command these two registers
-- will have a different value. All the other times it must have the same value.
usbreg_usbaddress     <= reg_dev_addr;
usbreg_usbaddress_tmp <= reg_dev_addr_tmp;
usbreg_deviceenabled  <= reg_dev_enable;
usbreg_setup          <= reg_dev_setup;
usbreg_pll_on         <= reg_dev_pll_on;
usbreg_lpm_sup        <= reg_dev_lpm_sup;
usbreg_port_force_fullspeed <= reg_dev_force_fullspeed;

usbreg_dev_connect      <= usbreg_dev_connect_int_z;
usbreg_dev_connect_int  <= '1' when reg_dev_connect = '1' and (sync_VBusDebounced = '1' or reg_dev_force_vbus = '1')
                               else '0';
reg_dev_suspend         <= sync_suspend;
reg_dev_lpm_suspend     <= sync_lpm_suspend;
reg_dev_lpm_remote_wake <= sync_lpm_rw;
usbreg_phy_test_mode    <= reg_dev_phy_test_mode;

reg_info_frame_number <= usbreg_frame_number;

proc_addr_gen : process(reg_ep_fifo_addr_offset, reg_data_fifo_addr_offset)
begin
  if C_EPUB < 32 then
    usbreg_ep_list_start  (      31 downto C_EPUB) <= C_EPFIFO_PAGE(31 downto C_EPUB);
  end if;
  if C_EPUB > 8 then
    usbreg_ep_list_start  (C_EPUB-1 downto      8) <= reg_ep_fifo_addr_offset;
  end if;
  usbreg_ep_list_start    (       7 downto      0) <= (others => '0');

  if C_DAUB < 32 then
    usbreg_data_buffer_start(31 downto C_DAUB)     <= C_DATAFIFO_PAGE(31 downto C_DAUB);
  end if;
  if C_DAUB > C_DALB then
    usbreg_data_buffer_start(C_DAUB-1 downto C_DALB) <= reg_data_fifo_addr_offset;
  end if;
  usbreg_data_buffer_start(C_DALB-1 downto      0) <= (others => '0');
end process proc_addr_gen;

usbreg_lpm_hird_sw <= reg_lpm_hird_sw;
reg_lpm_hird_hw    <= sieint_lpm_hird_hw;
usbreg_lpm_nyet    <= reg_lpm_nyet;
usbreg_chrg_vbus <= reg_chrg_vbus;
usbreg_dischrg_vbus <= reg_dischrg_vbus;

usbreg_ep_skip <= reg_ep_skip;

reg_ep_doublebuffer(1 downto 0) <= (others => '0');

proc_reg_ep_bufinuse : process(bufinuse)
begin
  reg_ep_bufinuse(1 downto 0)              <= (others => '0');
  if C_NBPHYSEP > 0 then
    reg_ep_bufinuse(C_NBPHYSEP+1 downto 2) <= bufinuse(C_NBPHYSEP-1 downto 0);
  end if;
end process proc_reg_ep_bufinuse;

usbreg_ep_bufinuse(C_NBPHYSEP+1 downto 0)
                          <= reg_ep_bufinuse when C_DOUBLE_BUFFER_SUPPORTED else
                                             (others => '0');

-- -----------------------------------------------------------------------
-- Toggle value FF for all endpoints
-- -----------------------------------------------------------------------
usbreg_epinfo_toggle <= reg_ep_toggle_value;

   proc_toggle : process(hclk,hresetn)
   begin
     if hresetn = '0' then
       reg_ep_toggle_value <= (others => '0');
     elsif hclk'event and hclk = '1' then
       if sync_busreset = '1' then
         reg_ep_toggle_value <= (others => '0');
       elsif sieint_setup_received = '1' then
         reg_ep_toggle_value(0) <= '1';
         reg_ep_toggle_value(1) <= '1';
       elsif dma_clear_toggle = '1' then
         reg_ep_toggle_value(dma_physepnr) <= '0';
       elsif dma_set_toggle = '1' then
         reg_ep_toggle_value(dma_physepnr) <= '1';
       end if;
     end if;
   end process proc_toggle;


usbreg_select_ext_clk <= reg_ext_clk_enable when C_PLL_ENABLE else '1';

reg_phy_addr(3 downto 0) <= reg_phy_addr_lower_nib;
reg_phy_addr(7 downto 4) <= reg_phy_addr_higher_nib when C_ULPI_SUPPORT else (others => '0');
usbreg_phy_addr  <= reg_phy_addr;
usbreg_phy_wdata <= reg_phy_wdata when C_ULPI_SUPPORT else (others => '0');
usbreg_phy_write <= reg_phy_write when C_ULPI_SUPPORT else '0';
usbreg_phy_start <= reg_phy_start;
usbreg_phy_mode  <= reg_phy_mode when C_ULPI_SUPPORT and C_UTMI_SUPPORT else
                    '1'          when C_ULPI_SUPPORT                    else
                    '0';

usbreg_vbuscomp_on <= not reg_vbuscomp_off;

-- -----------------------------------------------------------------------
-- Register read
-- -----------------------------------------------------------------------

   proc_reg_rdata : process (reg_raddr,
                             reg_dev_addr,
                             reg_dev_enable,
                             reg_dev_setup,
                             reg_dev_pll_on,
                             reg_dev_force_vbus,
                             reg_dev_lpm_sup,
                             reg_dev_intnak_ao,
                             reg_dev_intnak_ai,
                             reg_dev_intnak_co,
                             reg_dev_intnak_ci,
                             reg_dev_connect,
                             reg_dev_suspend,
                             reg_dev_lpm_suspend,
                             reg_dev_lpm_remote_wake,
                             reg_dev_connect_change,
                             reg_dev_suspend_change,
                             reg_dev_reset_change,
                             sync_VBusDebounced,
                             reg_dev_phy_test_mode,
                             pie_speed,
                             reg_info_frame_number,
                             reg_info_err_code,
                             reg_ep_fifo_addr_offset,
                             reg_data_fifo_addr_offset,
                             reg_lpm_hird_hw,
                             reg_lpm_hird_sw,
                             reg_lpm_nyet,
                             reg_ep_skip,
                             reg_ep_bufinuse,
                             reg_ep_doublebuffer,
                             reg_ep_int_status,
                             reg_frame_int_status,
                             reg_dev_int_status,
                             reg_ep_int_enable,
                             reg_frame_int_enable,
                             reg_dev_int_enable,
                             reg_ep_int_route,
                             reg_frame_int_route,
                             reg_dev_int_route,
                             reg_ep_toggle_value,
                             reg_ext_clk_enable,
                             reg_phy_addr,
                             reg_phy_wdata,
                             reg_phy_rdata,
                             reg_phy_write,
                             reg_phy_start,
                             reg_phy_mode,
                             reg_phy_addr_lower_nib,
                             reg_vbuscomp_off,
                             sync_avalid,
                             sync_sessend,
                             reg_chrg_vbus,
                             reg_dischrg_vbus,
                             reg_dev_otg_change,
                             reg_dev_force_fullspeed
                             )
   begin
     reg_rdata <= (others => '0');
     case reg_raddr is
       when "0000" =>
         reg_rdata( 6 downto  0) <= reg_dev_addr;
         reg_rdata( 7)           <= reg_dev_enable;
         reg_rdata( 8)           <= reg_dev_setup;
         reg_rdata( 9)           <= reg_dev_pll_on;
         reg_rdata(10)           <= reg_dev_force_vbus;
         reg_rdata(11)           <= reg_dev_lpm_sup;
         reg_rdata(12)           <= reg_dev_intnak_ao;
         reg_rdata(13)           <= reg_dev_intnak_ai;
         reg_rdata(14)           <= reg_dev_intnak_co;
         reg_rdata(15)           <= reg_dev_intnak_ci;
         reg_rdata(16)           <= reg_dev_connect;
         reg_rdata(17)           <= reg_dev_suspend;

         reg_rdata(19)           <= reg_dev_lpm_suspend;
         reg_rdata(20)           <= reg_dev_lpm_remote_wake;
         reg_rdata(21)           <= reg_dev_force_fullspeed;
         reg_rdata(23 downto 22) <= pie_speed;

         reg_rdata(24)           <= reg_dev_connect_change;
         reg_rdata(25)           <= reg_dev_suspend_change;
         reg_rdata(26)           <= reg_dev_reset_change;
         reg_rdata(27)           <= reg_dev_otg_change;

         if sync_VBusDebounced = '1' then
           reg_rdata(28)         <= '1';
         else
           reg_rdata(28)         <= '0';
         end if;

         reg_rdata(31 downto 29) <= reg_dev_phy_test_mode;

       when "0001" =>
         reg_rdata(10 downto  0) <= reg_info_frame_number;
         reg_rdata(14 downto 11) <= reg_info_err_code;
         reg_rdata(23 downto 16) <= C_MINOR_REV;
         reg_rdata(31 downto 24) <= C_MAJOR_REV;

       when "0010" =>
         if C_EPUB > 8 then
           reg_rdata(C_EPUB-1 downto 8)
                                 <= reg_ep_fifo_addr_offset;
         end if;
         if C_EPUB < 32 then
           reg_rdata(31 downto C_EPUB)
                                 <= C_EPFIFO_PAGE(31 downto C_EPUB);
         end if;

       when "0011" =>
         if C_DAUB > C_DALB then
           reg_rdata(C_DAUB-1 downto C_DALB)
                                 <= reg_data_fifo_addr_offset;
         end if;
         if C_DAUB < 32 then
           reg_rdata(31 downto C_DAUB)
                                 <= C_DATAFIFO_PAGE(31 downto C_DAUB);
         end if;

       when "0100" =>
         reg_rdata( 3 downto  0) <= reg_lpm_hird_hw;
         reg_rdata( 7 downto  4) <= reg_lpm_hird_sw;
         reg_rdata(           8) <= reg_lpm_nyet;
         reg_rdata(16) <= reg_vbuscomp_off;
         reg_rdata(17) <= reg_chrg_vbus;
         reg_rdata(18) <= reg_dischrg_vbus;
         reg_rdata(20) <= sync_avalid;-- ADPPROBE
         reg_rdata(21) <=  sync_sessend;-- ADPSENSE

       when "0101" =>
         reg_rdata(C_NBPHYSEP+1 downto 0)
                                 <= reg_ep_skip;

       when "0110" =>
         if C_DOUBLE_BUFFER_SUPPORTED then
           reg_rdata(C_NBPHYSEP+1 downto 0)
                                 <= reg_ep_bufinuse;
         end if;

       when "0111" =>
         if C_SINGLE_BUFFER_SUPPORTED and C_DOUBLE_BUFFER_SUPPORTED then
           reg_rdata(C_NBPHYSEP+1 downto 0)
                                 <= reg_ep_doublebuffer;
         elsif C_DOUBLE_BUFFER_SUPPORTED then
           reg_rdata(C_NBPHYSEP+1 downto 2)
                                 <= (others => '1');
         end if;

       when "1000" =>
         reg_rdata(C_NBPHYSEP+1 downto 0)
                                 <= reg_ep_int_status;
         reg_rdata(30)           <= reg_frame_int_status;
         reg_rdata(31)           <= reg_dev_int_status;

       when "1001" =>
         reg_rdata(C_NBPHYSEP+1 downto 0)
                                 <= reg_ep_int_enable;
         reg_rdata(30)           <= reg_frame_int_enable;
         reg_rdata(31)           <= reg_dev_int_enable;

       when "1010" =>
         reg_rdata(C_NBPHYSEP+1 downto 0)
                                 <= reg_ep_int_status;
         reg_rdata(30)           <= reg_frame_int_status;
         reg_rdata(31)           <= reg_dev_int_status;

       when "1011" =>
         reg_rdata(C_NBPHYSEP+1 downto 0)
                                 <= reg_ep_int_route;
         reg_rdata(30)           <= reg_frame_int_route;
         reg_rdata(31)           <= reg_dev_int_route;

       when "1100" =>
         reg_rdata( 4 downto  0) <= std_logic_vector(to_unsigned(C_NBPHYSEP,5));
         if C_SINGLE_BUFFER_SUPPORTED then
           reg_rdata( 5)         <= '1';
         end if;
         if C_DOUBLE_BUFFER_SUPPORTED then
           reg_rdata( 6)         <= '1';
         end if;
         if C_TOGGLE_REG_READABLE then
           reg_rdata( 7)         <= '1';
         end if;
         if C_PLL_ENABLE then
           reg_rdata( 8)         <= '1';
         end if;
         if C_UTMI_SUPPORT then
           reg_rdata( 9)         <= '1';
         end if;
         if C_ULPI_SUPPORT then
           reg_rdata(10)         <= '1';
         end if;

       when "1101" =>
         if C_TOGGLE_REG_READABLE then
           reg_rdata(C_NBPHYSEP+1 downto 0)
                                 <= reg_ep_toggle_value;
         end if;

       when "1110" =>
         if C_PLL_ENABLE then
           reg_rdata(0)          <= reg_ext_clk_enable;
         else
           reg_rdata(0)          <= '1';
         end if;

       when others => --"1111" =>
         if C_UTMI_SUPPORT and C_ULPI_SUPPORT then
           reg_rdata( 7 downto  0)<= reg_phy_addr;
           reg_rdata(15 downto  8)<= reg_phy_wdata;
           reg_rdata(23 downto 16)<= reg_phy_rdata;
           reg_rdata(24)          <= reg_phy_write;
           reg_rdata(25)          <= reg_phy_start;
           reg_rdata(31)          <= reg_phy_mode;
         elsif C_UTMI_SUPPORT then
           reg_rdata( 3 downto  0)<= reg_phy_addr_lower_nib;
           reg_rdata(23 downto 16)<= reg_phy_rdata;
           reg_rdata(25)          <= reg_phy_start;
           reg_rdata(31)          <= '0';
         elsif C_ULPI_SUPPORT then
           reg_rdata( 7 downto  0)<= reg_phy_addr;
           reg_rdata(15 downto  8)<= reg_phy_wdata;
           reg_rdata(23 downto 16)<= reg_phy_rdata;
           reg_rdata(24)          <= reg_phy_write;
           reg_rdata(25)          <= reg_phy_start;
           reg_rdata(31)          <= '1';

         end if;

     end case;
   end process;

-- -----------------------------------------------------------------------
-- Register write and updates of bits by other HW modules
-- -----------------------------------------------------------------------
   proc_reg_write : process(hclk,hresetn)
   begin
     if hresetn = '0' then
       reg_dev_addr              <= (others => '0');
       reg_dev_addr_tmp          <= (others => '0');
       reg_dev_enable            <= '0';
       reg_dev_setup             <= '0';
       reg_dev_pll_on            <= '0';
       reg_dev_force_vbus        <= '0';
       reg_dev_lpm_sup           <= '1';
       reg_dev_intnak_ao         <= '0';
       reg_dev_intnak_ai         <= '0';
       reg_dev_intnak_co         <= '0';
       reg_dev_intnak_ci         <= '0';
       reg_dev_connect           <= '0';
       reg_dev_connect_change    <= '0';
       reg_dev_suspend_change    <= '0';
       reg_dev_reset_change      <= '0';
       reg_dev_otg_change        <= '0';
       reg_dev_phy_test_mode     <= (others => '0');
       reg_info_err_code         <= (others => '0');
       reg_dev_force_fullspeed   <= '0';
       sync_avalid_z             <= '0';
       sync_sessend_z            <= '0';
       if C_EPUB > 8 then
         reg_ep_fifo_addr_offset <= (others => '0');
       end if;
       if C_DAUB > C_DALB then
         reg_data_fifo_addr_offset <= (others => '0');
       end if;
       reg_lpm_hird_sw           <= (others => '0');
       reg_lpm_nyet              <= '0';
       reg_ep_skip               <= (others => '0');
       if C_DOUBLE_BUFFER_SUPPORTED and C_NBPHYSEP > 0 then
         bufinuse                <= (others => '0');
       end if;
       if C_SINGLE_BUFFER_SUPPORTED and C_DOUBLE_BUFFER_SUPPORTED
                                    and C_NBPHYSEP > 0 then
         reg_ep_doublebuffer(C_NBPHYSEP+1 downto 2)
                                 <= (others => '0');
       end if;
       reg_ep_int_status         <= (others => '0');
       reg_ep_int_enable         <= (others => '0');
       reg_ep_int_route          <= (others => '0');
       reg_frame_int_status      <= '0';
       reg_frame_int_enable      <= '0';
       reg_frame_int_route       <= '0';
       reg_dev_int_status        <= '0';
       reg_dev_int_enable        <= '0';
       reg_dev_int_route         <= '0';
       reg_vbuscomp_off          <= '0';
       reg_chrg_vbus             <= '0';
       reg_dischrg_vbus          <= '0';

       sync_suspend_z            <= '0';
       sync_lpm_suspend_z        <= '0';
       usbreg_dev_connect_int_z  <= '0';
       sync_sieint_error_z       <= '0';

       USB_Int_Req_Irq           <= '0';
       USB_Int_Req_Fiq           <= '0';

       usbreg_remotewakeup       <= '0';
       usbreg_lpmremotewakeup    <= '0';

       if C_PLL_ENABLE then
         reg_ext_clk_enable      <= '0';
       end if;
       if C_ULPI_SUPPORT then
         reg_phy_wdata           <= (others => '0');
         reg_phy_addr_higher_nib <= (others => '0');
         reg_phy_write           <= '0';
       end if;
       reg_phy_rdata             <= (others => '0');
       reg_phy_start             <= '0';
       reg_phy_addr_lower_nib    <= (others => '0');
       if C_ULPI_SUPPORT and C_UTMI_SUPPORT then
         reg_phy_mode            <= '0';
       end if;

     elsif (hclk'event and hclk='1') then
       sync_sieint_error_z       <= sync_sieint_error;
       usbreg_dev_connect_int_z  <= usbreg_dev_connect_int;
       sync_avalid_z             <= sync_avalid;
       sync_sessend_z            <= sync_sessend;

       if reg_dev_suspend = '0' then
         usbreg_remotewakeup <= '0';
       end if;
       if reg_dev_lpm_suspend = '0' then
         usbreg_lpmremotewakeup <= '0';
       end if;

       if reg_write = '1' then
         case reg_waddr is
           when "0000" =>
             reg_dev_addr_tmp        <= reg_wdata(6 downto 0);
             reg_dev_enable          <= reg_wdata(7);
             if reg_wdata(8) = '1' then
               reg_dev_setup         <= '0';
             end if;
             reg_dev_pll_on          <= reg_wdata(9);
             reg_dev_force_vbus      <= reg_wdata(10);
             reg_dev_lpm_sup         <= reg_wdata(11);
             reg_dev_intnak_ao       <= reg_wdata(12);
             reg_dev_intnak_ai       <= reg_wdata(13);
             reg_dev_intnak_co       <= reg_wdata(14);
             reg_dev_intnak_ci       <= reg_wdata(15);
             reg_dev_connect         <= reg_wdata(16);
             if reg_wdata(17) = '0' and reg_dev_suspend = '1' then
               usbreg_remotewakeup <= '1';
             end if;
             if reg_wdata(19) = '0' and reg_dev_lpm_suspend = '1'
                                    and reg_dev_lpm_remote_wake = '1' then
               usbreg_lpmremotewakeup <= '1';
             end if;
             reg_dev_force_fullspeed  <= reg_wdata(21);
             if reg_wdata(24) = '1' then
               reg_dev_connect_change<= '0';
             end if;
             if reg_wdata(25) = '1' then
               reg_dev_suspend_change<= '0';
             end if;
             if reg_wdata(26) = '1' then
               reg_dev_reset_change  <= '0';
             end if;
             if reg_wdata(27) = '1' then
               reg_dev_otg_change  <= '0';
             end if;
             reg_dev_phy_test_mode   <= reg_wdata(31 downto 29);

           when "0001" =>
             reg_info_err_code        <= reg_wdata(14 downto 11);

           when "0010" =>
             if C_EPUB > 8 then
               reg_ep_fifo_addr_offset  <= reg_wdata(C_EPUB-1 downto 8);
             end if;

           when "0011" =>
             if C_DAUB > C_DALB then
               reg_data_fifo_addr_offset<= reg_wdata(C_DAUB-1 downto C_DALB);
             end if;

           when "0100" =>
             reg_lpm_hird_sw          <= reg_wdata(7 downto 4);
             reg_lpm_nyet             <= reg_wdata(8);
             reg_vbuscomp_off         <= reg_wdata(16);
             reg_chrg_vbus            <= reg_wdata(17);
             reg_dischrg_vbus         <= reg_wdata(18);

           when "0101" =>
             reg_ep_skip              <= reg_wdata(C_NBPHYSEP+1 downto 0);

           when "0110" =>
             if C_DOUBLE_BUFFER_SUPPORTED and C_NBPHYSEP > 0 then
               bufinuse(C_NBPHYSEP-1 downto 0)
                                      <= reg_wdata(C_NBPHYSEP+1 downto 2);
             end if;

           when "0111" =>
             if C_SINGLE_BUFFER_SUPPORTED and C_DOUBLE_BUFFER_SUPPORTED
                                          and C_NBPHYSEP > 0 then
               reg_ep_doublebuffer(C_NBPHYSEP+1 downto 2)
                                      <= reg_wdata(C_NBPHYSEP+1 downto 2);
             end if;

           when "1000" =>
             for i in 0 to C_NBPHYSEP+1 loop
               if reg_wdata(i) = '1' then
                 reg_ep_int_status(i) <= '0';
               end if;
             end loop;
             if reg_wdata(30) = '1' then
               reg_frame_int_status <= '0';
             end if;
             if reg_wdata(31) = '1' then
               reg_dev_int_status <= '0';
             end if;

           when "1001" =>
             reg_ep_int_enable    <= reg_wdata(C_NBPHYSEP+1 downto 0);
             reg_frame_int_enable <= reg_wdata(30);
             reg_dev_int_enable   <= reg_wdata(31);

           when "1010" =>
             for i in 0 to C_NBPHYSEP+1 loop
               if reg_wdata(i) = '1' then
                 reg_ep_int_status(i) <= '1';
               end if;
             end loop;
             if reg_wdata(30) = '1' then
               reg_frame_int_status <= '1';
             end if;
             if reg_wdata(31) = '1' then
               reg_dev_int_status <= '1';
             end if;

           when "1011" =>
             reg_ep_int_route    <= reg_wdata(C_NBPHYSEP+1 downto 0);
             reg_frame_int_route <= reg_wdata(30);
             reg_dev_int_route   <= reg_wdata(31);

           when "1110" =>
             if C_PLL_ENABLE then
               reg_ext_clk_enable  <= reg_wdata(0);
             end if;

           when "1111" =>
             if C_ULPI_SUPPORT then
               reg_phy_wdata           <= reg_wdata(15 downto 8);
               reg_phy_addr_higher_nib <= reg_wdata( 7 downto 4);
               reg_phy_write           <= reg_wdata(24);
             end if;
             reg_phy_rdata             <= reg_wdata(23 downto 16);
             reg_phy_start             <= reg_wdata(25);
             reg_phy_addr_lower_nib    <= reg_wdata(3 downto 0);
             --altera translate_off
             if C_ULPI_SUPPORT and C_UTMI_SUPPORT then
               reg_phy_mode            <= reg_wdata(31);
             end if;
             --altera translate_on
           when others => --"1100" | "1101" =>
             null;
         end case;
       end if;

       ------------------------------------------------------
       -- HW interrupt signals
       ------------------------------------------------------
       USB_Int_Req_Irq <= irq_int;
       USB_Int_Req_Fiq <= fiq_int;

       ------------------------------------------------------
       -- update by other HW modules
       ------------------------------------------------------
       if sieint_setup_received = '1' then
         reg_dev_setup     <= '1';
         reg_dev_addr      <= sieint_usbaddress;
         reg_dev_addr_tmp  <= sieint_usbaddress;
       end if;


       if dma_clear_skip = '1' then
         reg_ep_skip(dma_skip_ep) <= '0';
       end if;

       if C_SINGLE_BUFFER_SUPPORTED and C_DOUBLE_BUFFER_SUPPORTED then
         for i in 0 to C_NBPHYSEP-1 loop
           if dma_set_int = '1' and dma_clear_skip = '0'
                                and dma_physepnr = i+2
                                and reg_ep_doublebuffer(i+2) = '1' then
             bufinuse(i) <= not(bufinuse(i));
           end if;
         end loop;
       elsif C_DOUBLE_BUFFER_SUPPORTED then
         for i in 0 to C_NBPHYSEP-1 loop
           if dma_set_int = '1' and dma_clear_skip = '0'
                                and dma_physepnr = i+2 then
             bufinuse(i) <= not(bufinuse(i));
           end if;
         end loop;
       end if;

       if usbreg_dev_connect_int = '0' and usbreg_dev_connect_int_z = '1' then
         reg_dev_connect_change <= '1';
         reg_dev_int_status     <= '1';
       end if;

       if (sync_avalid /= sync_avalid_z) or (sync_sessend /= sync_sessend_z) then
          reg_dev_otg_change <= '1';
          reg_dev_int_status <= '1';
       end if;

       if sync_set_frameint = '1' and usbreg_dev_connect_int = '1' then
         reg_frame_int_status <= '1';
       end if;

       -- DOC_BEGIN: Vbus Debouncing
       -- moved to USB clock domain at the 3511 toplevel

       -- DOC_END

       -- DOC_BEGIN: Status Change bits generation
       -- On a bus reset, the bus reset change bit is set
       -- and an interrupt is generated.
       if sync_busreset = '1' and usbreg_dev_connect_int = '1' then
         reg_dev_reset_change <= '1';
         reg_dev_int_status   <= '1';
         reg_dev_addr         <= (others => '0');
         reg_dev_addr_tmp     <= (others => '0');
       end if;

       -- On a change in the devices suspend state, the suspend
       -- change bit is set and an interrupt is generated.
       sync_suspend_z         <= sync_suspend;
       sync_lpm_suspend_z     <= sync_lpm_suspend;
       if sync_suspend /= sync_suspend_z or sync_lpm_suspend /= sync_lpm_suspend_z then
         reg_dev_suspend_change <= '1';
         reg_dev_int_status     <= '1';
      end if;

       if dma_set_int = '1' then
         if dma_clear_skip = '1' then
           reg_ep_int_status(dma_skip_ep)  <= '1';
         else
           reg_ep_int_status(dma_physepnr) <= '1';
         end if;
       end if;
       if dma_sent_NAK = '1' then
         if dma_physepnr/2 = 0 then
           if dma_physepnr mod 2 = 0 then
             if reg_dev_intnak_co = '1' then
               reg_ep_int_status(dma_physepnr) <= '1';
             end if;
           else
             if reg_dev_intnak_ci = '1' then
               reg_ep_int_status(dma_physepnr) <= '1';
             end if;
           end if;
         else
           if (dma_physepnr mod 2) = 0 then
             if reg_dev_intnak_ao = '1' then
               reg_ep_int_status(dma_physepnr) <= '1';
             end if;
           else
             if reg_dev_intnak_ai = '1' then
               reg_ep_int_status(dma_physepnr) <= '1';
             end if;
           end if;
         end if;
       end if;

       if sync_sieint_error = '1' and sync_sieint_error_z = '0' then
         reg_info_err_code <= sync_sieint_errortype;
       end if;

       if sync_phy_endtoggle = '1' then
         reg_phy_rdata <= sync_phy_rdata;
         reg_phy_start <= '0';
       end if;
     end if;
   end process proc_reg_write;

   proc_hw_int_generation : process(reg_frame_int_status, reg_frame_int_enable,
                                    reg_frame_int_route,
                                    reg_dev_int_status,reg_dev_int_enable,
                                    reg_dev_int_route,
                                    reg_ep_int_status,reg_ep_int_enable,
                                    reg_ep_int_route)
   variable var_irq_int : boolean;
   variable var_fiq_int : boolean;
   begin
     var_irq_int := false;
     var_fiq_int := false;
     if reg_frame_int_route = '0' then
       var_irq_int := (reg_frame_int_status = '1') and
                      (reg_frame_int_enable = '1');
     else
       var_fiq_int := (reg_frame_int_status = '1') and
                      (reg_frame_int_enable = '1');
     end if;
     if reg_dev_int_route = '0' then
       var_irq_int := var_irq_int or ((reg_dev_int_status = '1') and
                                      (reg_dev_int_enable = '1'));
     else
       var_fiq_int := var_fiq_int or ((reg_dev_int_status = '1') and
                                      (reg_dev_int_enable = '1'));
     end if;
     for i in 0 to C_NBPHYSEP+1 loop
       if reg_ep_int_route(i) = '0' then
         var_irq_int := var_irq_int or ((reg_ep_int_status(i) = '1') and
                                        (reg_ep_int_enable(i) = '1'));
       else
         var_fiq_int := var_fiq_int or ((reg_ep_int_status(i) = '1') and
                                        (reg_ep_int_enable(i) = '1'));
       end if;
     end loop;
     if var_irq_int then
       irq_int <= '1';
     else
       irq_int <= '0';
     end if;
     if var_fiq_int then
       fiq_int <= '1';
     else
       fiq_int <= '0';
     end if;
   end process proc_hw_int_generation;


 --fpga

 usb_reg_if_fpga(63 downto 6) <= (others => '0');
 usb_reg_if_fpga(0) <= reg_ep_int_status(0);
 usb_reg_if_fpga(1) <= reg_ep_int_status(1);
 usb_reg_if_fpga(2) <= reg_ep_int_status(2);
 usb_reg_if_fpga(3) <= reg_ep_int_status(3);
 usb_reg_if_fpga(4) <= reg_frame_int_status;
 usb_reg_if_fpga(5) <= reg_dev_int_status;


end RTL; --usb_reg_if
