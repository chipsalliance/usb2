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
-- ----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package ip_xxx_3511_hs_mem_compound_cmp_pkg is
component ip_xxx_3511_hs_mem_compound
  generic(
          AHB_DATAWIDTH  : integer := 32;
          RAM_DATAWIDTH  : integer := 64;
          RAM_ADDRWIDTH  : integer := 9;

          C_NBPHYSEP_ARM : integer := 14;
          C_EPUB         : integer := 32;
          C_DAUB         : integer := 32; --Requirement : C_DAUB > C_DALB
          C_DALB         : integer := 17; --maximum allowed value is 17
                                          --minimum allowed value is 7
          C_EPFIFO_PAGE             : std_logic_vector(31 downto 0) := X"00080000";
          C_DATAFIFO_PAGE           : std_logic_vector(31 downto 0) := X"00080000";
          C_SINGLE_BUFFER_SUPPORTED : boolean := TRUE;
          C_DOUBLE_BUFFER_SUPPORTED : boolean := TRUE;
          C_TOGGLE_REG_READABLE     : boolean := TRUE;
          C_PLL_ENABLE              : boolean := FALSE;
          C_PLL_DIVIDER             : std_logic_vector(6 downto 0) := "0010100";
          C_ULPI_SUPPORT            : boolean := TRUE;
          C_UTMI_SUPPORT            : boolean := TRUE;
          C_EXTEND_TX_DELAY         : boolean := TRUE;
          G_SIM_CHIRP_TIMERS        : boolean := FALSE
          );

  port(
       -- synthesis read_comments_as_HDL on
       --debug_fpga_3511   : out std_logic_vector(255 downto 0);
       --phy_interface     : in  std_logic;
       --fpga_pll_on       : in  std_logic;
       -- synthesis read_comments_as_HDL off
       -- AHB bus signals
       hclk                 : in  std_logic;
       hresetn              : in  std_logic;  -- IP resetn

       ahbs_resetn          : in  std_logic;  -- AHB resetn
       ahbs_haddr           : in  std_logic_vector(5 downto 2);
       ahbs_htrans          : in  std_logic_vector(1 downto 0);
       ahbs_hwrite          : in  std_logic;
       ahbs_hwdata          : in  std_logic_vector(31 downto 0);
       ahbs_hsel            : in  std_logic;
       ahbs_hreadyin        : in  std_logic;
       ahbs_hrdata          : out std_logic_vector(31 downto 0);
       ahbs_hreadyout       : out std_logic;
       ahbs_hresp           : out std_logic_vector(1 downto 0);
              
       ahbs_dma_haddr       : in  std_logic_vector(RAM_ADDRWIDTH-1+5 downto 0); 
       ahbs_dma_htrans      : in  std_logic_vector(1 downto 0);  
       ahbs_dma_hwrite      : in  std_logic; 
       ahbs_dma_hwdata      : in  std_logic_vector(AHB_DATAWIDTH-1 downto 0); 
       ahbs_dma_hsel        : in  std_logic;
       ahbs_dma_hreadyin    : in  std_logic; 
       ahbs_dma_hrdata      : out std_logic_vector(AHB_DATAWIDTH-1 downto 0); 
       ahbs_dma_hreadyout   : out std_logic; 
       ahbs_dma_hresp       : out std_logic_vector(1 downto 0);
       ahbs_dma_hsize       : in  std_logic_vector(2 downto 0);  
       ahbs_dma_hburst      : in  std_logic_vector(2 downto 0);  
       
       -- RAM interface signals
       mem_q                : in  std_logic_vector(RAM_DATAWIDTH-1 downto 0);
       mem_d                : out std_logic_vector(RAM_DATAWIDTH-1 downto 0);
       mem_cs               : out std_logic;
       mem_a                : out std_logic_vector(RAM_ADDRWIDTH-1 downto 0);
       mem_web_out          : out std_logic;

       -- Interrupt controller signals
       USB_Int_Req_Irq      : out   std_logic; -- Irq interrupt   
       USB_Int_Req_Fiq      : out   std_logic; -- Fiq interrupt
       USB_FrameToggle      : out   std_logic;

       --Configuration status indicator
       USB_VBus             : in    std_logic; -- Bus power is present
       vbuscomp_on          : out   std_logic; -- Enable Analog Vbus comparators
       chrg_vbus            : out   std_logic;
       dischrg_vbus         : out   std_logic;
       avalid               : in    std_logic; -- ADPPROBE
       sessend              : in    std_logic; -- ADPSENSE

       -- UTMI interface
       -- These signals are only to be used when the generic
       -- UTMI_SUPPORT is set to TRUE
       utmi_clk            : in  std_logic;
       utmi_rxdata         : in  std_logic_vector(7 downto 0);
       utmi_rxvalid        : in  std_logic;
       utmi_rxactive       : in  std_logic;
       utmi_rxerror        : in  std_logic;
       utmi_txdata         : out std_logic_vector(7 downto 0);
       utmi_txvalid        : out std_logic;
       utmi_txready        : in  std_logic;
       utmi_reset          : out std_logic;
       utmi_suspendm       : out std_logic;
       utmi_xcvrselect     : out std_logic;
       utmi_termselect     : out std_logic;
       utmi_opmode         : out std_logic_vector(1 downto 0);
       utmi_linestate      : in  std_logic_vector(1 downto 0);
       utmi_vcontrol       : out std_logic_vector(3 downto 0);
       utmi_vcontrolloadm  : out std_logic;
       utmi_vstatus        : in  std_logic_vector(7 downto 0);
       -- ULPI INTERFACE
       -- These signals are only to be used when the generic
       -- ULPI_SUPPORT is set to TRUE
       ulpi_clk            : in  std_logic;
       ulpi_rxdata         : in std_logic_vector(7 downto 0);
       ulpi_txdata         : out std_logic_vector(7 downto 0);
       ulpi_txenable       : out  std_logic;
       ulpi_dir            : in  std_logic;
       ulpi_stp            : out std_logic;
       ulpi_nxt            : in  std_logic;
       ulpi_ddr_sel        : in  std_logic;

       -- System interface
       usb_needclk         : out std_logic;
       sys_donotwakeup_n   : in  std_logic;
       sys_dev_wakeup_n    : in  std_logic;
       sys_utmi_clkin_lock : in  std_logic;

       -- Signals for controlling hub and embedded device
       USB_EnableHub       : in  std_logic;
       USB_self_powered    : in  std_logic;

      
       -- core testability
       async_disable          : in  std_logic;
       testmode               : in  std_logic; -- To be connected by integrator to a tcb test mode pin.
       tcb_clkgate_se         : in  std_logic; -- To be connected by integrator to test infrastructure.
       usb_dma_dword_selection: out std_logic_vector(1 downto 0);
       usb_dma_write_access   : out std_logic
      );
end component;
end ip_xxx_3511_hs_mem_compound_cmp_pkg;
