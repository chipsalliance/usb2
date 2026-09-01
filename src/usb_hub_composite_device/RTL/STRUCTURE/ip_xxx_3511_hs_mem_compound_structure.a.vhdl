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

library usb_lib;
use usb_lib.usb_general_subcmp_pkg.all;
use usb_lib.usb_configuration_subcmp_pkg.all;
use usb_lib.usb_subcmp_pkg.all;
use usb_lib.usb_ep_config_pkg.all;

architecture structure of ip_xxx_3511_hs_mem_compound is

--++++++++++++++++++++++++++++++++++++++++++++++
-- Constants that are specific for this toplevel
constant C_MINOR_REV      : std_logic_vector(7 downto 0) := X"00";
constant C_MAJOR_REV      : std_logic_vector(7 downto 0) := X"02";
constant USBPIE_DATAWIDTH : integer := 64;
constant RESET_CYCLE      : integer := 63;
constant C_EPNBYTEWIDTH   : integer := 15;

--++++++++++++++++++++++++++++++++++++++++++++++

component usb_pie
   generic (
      ULPI_SUPPORT          : boolean := TRUE;
      UTMI_SUPPORT          : boolean := TRUE;
      USB_DATAWIDTH         : integer := 64;
      C_NBDEV               : integer := 1;
      C_NBPHYSEP            : integer := 14;
      C_EXTEND_TX_DELAY     : boolean := FALSE
   );
    port (
          ----- To/From usb synchronizer ------------------------
         pie_epinfo_req            : out std_logic;
         pie_epinfo_epnr           : out std_logic_vector(3 downto 0);
         pie_epinfo_epdir          : out std_logic;
         pie_epinfo_setup          : out std_logic;
         pie_epinfo_setup_received : out std_logic;
         pie_usbaddress            : out std_logic_vector(6 downto 0);

         epinfo_valid              : in  std_logic;
         epinfo_active             : in  std_logic;
         epinfo_disabled           : in  std_logic;
         epinfo_toggle             : in  std_logic;
         epinfo_stall              : in  std_logic;
         epinfo_iso                : in  std_logic;
         epinfo_nbytes             : in  std_logic_vector(14 downto 0);
         epinfo_maxpacket          : in std_logic_vector(1 downto 0);

         pie_txdata_fetched        : out std_logic;
         epinfo_txdata             : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
         epinfo_txdata_valid       : in  std_logic;

         pie_rx_nbytes             : out std_logic_vector(11 downto 0);
         pie_rxdata                : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
         pie_rxdatavalid           : out std_logic;

         pie_endtransfer           : out std_logic;
         pie_success               : out std_logic;
         pie_error                 : out std_logic;
         pie_errortype             : out std_logic_vector(3 downto 0);
         pie_sentNAK               : out std_logic;
         pie_isotoggle             : out std_logic;
         pie_busreset              : out std_logic;
         pie_devicespeed           : out std_logic;
         pie_suspend               : out std_logic;
         pie_lpm_suspend           : out std_logic;
         pie_lpm_remotewake_enable : out std_logic;
         pie_lpm_hird_hw           : out std_logic_vector(3 downto 0);

         pie_vbusvalid             : out std_logic;
         pie_lowpower_n            : out std_logic;

         reset_n                   : in std_logic; -- AHB reset after resynchronization, active LOW
         pie_clk                   : in std_logic; -- UTMI/ULPI clock

         phy_address               : in std_logic_vector(7 downto 0);
         phy_readdata              : out std_logic_vector(7 downto 0);
         phy_writedata             : in std_logic_vector(7 downto 0);
         phy_write                 : in std_logic;
         phy_start                 : in std_logic;
         phy_endtoggle             : out std_logic;
         phy_mode                  : in std_logic;

         sync_usbreg_phy_test_mode_change  : in std_logic;  -- phy_test_mode change, resynchronized with usb_pie clock
         sync_usbreg_remotewakeup          : in std_logic;  -- usbreg_remotewakeup from reg_if resynchronized with usb_pie clock
         sync_usbreg_lpmremotewakeup       : in std_logic;  -- usbreg_lpmremotewakeup from reg_if resynchronized with usb_pie clock

          -----  To/From usb_reg_if ------------------------
          ------ To/From ahb register module - pseudo-static signals
         usbreg_pll_on             : in  std_logic;
         usbreg_deviceenabled      : in  std_logic_vector(C_NBDEV-1 downto 0);
         usbreg_dev_connect        : in  std_logic;
         usbreg_remotewakeup       : in  std_logic;
         usbreg_lpm_sup            : in  std_logic;
         usbreg_lpmremotewakeup    : in  std_logic;
         usbreg_lpm_hird_sw        : in std_logic_vector(3 downto 0);
         usbreg_lpm_nyet           : in std_logic;
         usbreg_frame_number       : out std_logic_vector(10 downto 0);
         usbreg_usbaddress         : in  std_logic_vector(C_NBDEV*7-1 downto 0);
         usbreg_usbaddress_tmp     : in  std_logic_vector(C_NBDEV*7-1 downto 0);
         usbreg_phy_test_mode      : in  std_logic_vector(2 downto 0);
         usbreg_port_force_fullspeed : in std_logic;

	 token_length_counter      : in  std_logic_vector(6 downto 0);
	 usb_token_length          : out std_logic_vector(6 downto 0);

         utmi_vcontrol             : out std_logic_vector(3 downto 0);
         utmi_vcontrolloadm        : out std_logic;
         utmi_vstatus              : in std_logic_vector(7 downto 0);

         pie_dev_selected          : out integer range 0 to C_NBDEV - 1;

         -- UTMI INTERFACE
         -- These signals are only to be used when the generic UTMI_SUPPORT is set to TRUE
         utmi_rxdata               : in  std_logic_vector(7 downto 0);
         utmi_rxvalid              : in  std_logic;
         utmi_rxactive             : in  std_logic;
         utmi_rxerror              : in  std_logic;
         utmi_txdata               : out std_logic_vector(7 downto 0);
         utmi_txvalid              : out std_logic;
         utmi_txready              : in  std_logic;
         utmi_reset                : out std_logic;
         utmi_xcvrselect           : out std_logic;
         utmi_termselect           : out std_logic;
         utmi_opmode               : out std_logic_vector(1 downto 0);
         utmi_linestate            : in  std_logic_vector(1 downto 0);
         utmi_vbusvalid            : in std_logic;

         -- ULPI INTERFACE
         -- These signals are only to be used when the generic ULPI_SUPPORT is set to TRUE
         ulpi_rxdata               : in std_logic_vector(7 downto 0);
         ulpi_txdata               : out std_logic_vector(7 downto 0);
         ulpi_txenable             : out std_logic;
         ulpi_dir                  : in  std_logic;
         ulpi_stp                  : out std_logic;
         ulpi_nxt                  : in  std_logic;
         ulpi_pwrctrl_wakeup       : in std_logic;

         VBusDebounced             : in std_logic;
         usb_pie_fpga              : out std_logic_vector(63 downto 0)
          );
end component;

component usb_synchronizer
  generic(C_ULPI_SUPPORT   : boolean := TRUE;
          C_UTMI_SUPPORT   : boolean := TRUE;
          USB_DATAWIDTH    : integer := 8;
          TXNBYTES_BITS    : integer := 10;
          RXNBYTES_BITS    : integer := 11;
          C_NBDEV          : integer := 1);
  port  (
           ----- To/From usb clock domain ------------------------
           sieint_epinfo_req    : in  std_logic;                    --sync signal
           sieint_epinfo_epnr   : in  std_logic_vector(3 downto 0);
           sieint_epinfo_epdir  : in  std_logic;
           sieint_epinfo_setup  : in  std_logic;
           epinfo_valid         : out std_logic;                    --sync signal
           sieint_epinfo_setup_received  : in  std_logic;

           epinfo_active        : out std_logic;
           epinfo_disabled      : out std_logic;
           epinfo_toggle        : out std_logic;
           epinfo_stall         : out std_logic;
           epinfo_iso           : out std_logic;
           epinfo_ratefeedbackmode : out std_logic;
           epinfo_nbytes        : out std_logic_vector(TXNBYTES_BITS-1 downto 0);
           epinfo_maxpacket     : out std_logic_vector(1 downto 0);

           sieint_txdatafetched : in  std_logic;                    --sync signal
           epinfo_txdata        : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
           epinfo_txdata_valid  : out std_logic;                    --sync signal

           sieint_rx_nbytes     : in std_logic_vector(RXNBYTES_BITS-1 downto 0);
           sieint_rxdata        : in std_logic_vector(USB_DATAWIDTH-1 downto 0);
           sieint_rxdatavalid   : in std_logic;                    --sync signal

           sieint_endtransfer   : in std_logic;                    --sync signal
           sieint_success       : in std_logic; -- can this be combined with error ?
           sieint_error         : in std_logic;
           sieint_errortype     : in std_logic_vector(3 downto 0);
           sieint_sentNAK       : in std_logic;
           VBusDebounced        : in std_logic;
           pie_lowpower_n       : in std_logic;
           vbuscomp_on          : out std_logic;                      -- Enable Analog Vbus comparators
           chrg_vbus            : out std_logic;
           dischrg_vbus         : out std_logic;
           avalid               : in  std_logic;                      -- ADPPROBE
           sessend              : in  std_logic;                      -- ADPSENSE

           TM_IsoToggle         : in integer range 0 to 1;
           RG_BUSReset          : in boolean;
           TM_Suspend           : in boolean;
           LPM_TM_Suspend       : in boolean;
           LPM_RW               : in boolean;

           phy_addr             : out std_logic_vector(7 downto 0);
           phy_wdata            : out std_logic_vector(7 downto 0);
           phy_rdata            : in  std_logic_vector(7 downto 0);
           phy_write            : out std_logic;
           phy_start            : out std_logic;
           phy_mode             : out std_logic;
           phy_endtoggle        : in  std_logic;

           sync_usbreg_phy_test_mode_change  : out std_logic;
           sync_usbreg_dev_connect      : out std_logic;
           sync_usbreg_remotewakeup     : out std_logic;
           sync_usbreg_lpmremotewakeup  : out std_logic;

           sync_usbreg_pll_on      : out std_logic; 
           sync_usbreg_lpm_sup     : out std_logic; 
           sync_usbreg_lpm_hird_sw : out std_logic_vector(3 downto 0);
           sync_usbreg_lpm_nyet    : out std_logic;

           pie_speed               : in std_logic_vector(1 downto 0);
           sieint_lpm_hird_hw      : in  std_logic_vector( 3 downto 0);
           usbreg_frame_number     : in std_logic_vector(10 downto 0);
           pie_dev_selected        : in integer range 0 to C_NBDEV - 1;

           ----- To/From ahb clock domain ------------------------
           sync_sieint_epinfo_req    : out std_logic;                    --sync signal
           sync_sieint_epinfo_epnr   : out std_logic_vector(3 downto 0);
           sync_sieint_epinfo_epdir  : out std_logic;
           sync_sieint_epinfo_setup  : out std_logic;
           sync_sieint_setup_received: out std_logic; -- single pulse
           epinfo_sync_valid         : in  std_logic;                    --sync signal
           sync_VBusDebounced        : out std_logic;   -- sync signal
           usbreg_vbuscomp_on        : in   std_logic;                      -- Enable Analog Vbus comparators
           usbreg_chrg_vbus          : in std_logic;
           usbreg_dischrg_vbus       : in  std_logic;
           sync_avalid               : out    std_logic;                      -- ADPPROBE
           sync_sessend              : out    std_logic;                      -- ADPSENSE

           epinfo_sync_active        : in  std_logic;
           epinfo_sync_disabled      : in  std_logic;
           epinfo_sync_toggle        : in  std_logic;
           epinfo_sync_stall         : in  std_logic;
           epinfo_sync_iso           : in  std_logic;
           epinfo_sync_ratefeedbackmode: in std_logic;
           epinfo_sync_nbytes        : in  std_logic_vector(TXNBYTES_BITS-1 downto 0);
           epinfo_sync_maxpacket     : in  std_logic_vector(1 downto 0);

           sync_sieint_txdatafetched : out std_logic;                    --sync signal
           epinfo_sync_txdata        : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
           epinfo_sync_txdata_valid  : in  std_logic;                    --sync signal

           sync_sieint_rx_nbytes     : out std_logic_vector(RXNBYTES_BITS-1 downto 0);
           sync_sieint_rxdata        : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
           sync_sieint_rxdatavalid   : out std_logic;                    --sync signal

           sync_sieint_endtransfer   : out std_logic;                    --sync signal
           sync_sieint_success       : out std_logic; -- can this be combined with error ?
           sync_sieint_error         : out std_logic;
           sync_sieint_errortype     : out std_logic_vector(3 downto 0);
           sync_sieint_sentNAK       : out std_logic;

           sync_set_frameint         : out std_logic;
           sync_busreset             : out std_logic;
           sync_suspend              : out std_logic;
           sync_lpm_suspend          : out std_logic;
           sync_lpm_rw               : out std_logic;

           usbreg_phy_addr           : in  std_logic_vector(7 downto 0);
           usbreg_phy_wdata          : in  std_logic_vector(7 downto 0);
           sync_phy_rdata            : out std_logic_vector(7 downto 0);
           usbreg_phy_write          : in  std_logic;
           usbreg_phy_start          : in  std_logic;
           usbreg_phy_mode           : in  std_logic;
           sync_phy_endtoggle        : out std_logic;

           usbreg_phy_test_mode      : in  std_logic_vector(2 downto 0);
           usbreg_dev_connect        : in  std_logic;
           usbreg_remotewakeup       : in  std_logic;
           usbreg_lpmremotewakeup    : in  std_logic;

           usbreg_pll_on             : in std_logic; 
           usbreg_lpm_sup            : in std_logic; 
           usbreg_lpm_hird_sw        : in std_logic_vector(3 downto 0);
           usbreg_lpm_nyet           : in std_logic;

           sync_pie_speed            : out std_logic_vector(1 downto 0);
           sync_sieint_lpm_hird_hw   : out std_logic_vector( 3 downto 0);
           sync_usbreg_frame_number  : out std_logic_vector(10 downto 0);
           sync_pie_dev_selected     : out integer range 0 to C_NBDEV - 1;

           ------ System ---------------------
           FsClk                     : in  std_logic;          -- Recovered Clock
           reset_n                   : in  std_logic;          -- Global Reset
           hclk                      : in  std_logic;
           hrstn                     : in  std_logic

        );
end component;

component usb_reg_if
  generic(C_ULPI_SUPPORT           : boolean := TRUE;
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
          C_MAJOR_REV              : std_logic_vector(7 downto 0) := X"00");
  port (
        -- synthesis read_comments_as_HDL on
        --phy_interface            : in  std_logic;
        --fpga_pll_on              : in std_logic;
        -- synthesis read_comments_as_HDL off
        hclk                     : in  std_logic;
        hresetn                  : in  std_logic;
        USB_Int_Req_Irq       : out std_logic;
        USB_Int_Req_Fiq       : out std_logic;

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
        usbreg_epinfo_toggle     : out  std_logic_vector(C_NBPHYSEP+1 downto 0);
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
        usbreg_vbuscomp_on       : out   std_logic;                      -- Enable Analog Vbus comparators
        usbreg_chrg_vbus         : out std_logic;
        usbreg_dischrg_vbus      : out std_logic;
        sync_avalid              : in    std_logic;                      -- ADPPROBE
        sync_sessend             : in    std_logic;                      -- ADPSENSE
        usbreg_phy_addr          : out std_logic_vector(7 downto 0);
        usbreg_phy_wdata         : out std_logic_vector(7 downto 0);
        sync_phy_rdata           : in  std_logic_vector(7 downto 0);
        usbreg_phy_write         : out std_logic;
        usbreg_phy_start         : out std_logic;
        usbreg_phy_mode          : out std_logic;
        sync_phy_endtoggle       : in  std_logic;
        usb_reg_if_fpga          : out std_logic_vector(63 downto 0)
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
      ads_dma_dword_en  : in  std_logic_vector(RAM_DATAWIDTH/32-1 downto 0);
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

component usb_dma
  generic(USB_DATAWIDTH      : integer := 64;
          RAM_DATAWIDTH      : integer := 64;
          C_NBPHYSEP         : integer := 14;
          C_DALB             : integer := 22);
  port (
      hclk                         : in  std_logic;
      hresetn                      : in  std_logic;
      dma_addr                     : out std_logic_vector(31 downto 0);
      dma_req                      : out std_logic;
      dma_gnt                      : in  std_logic;
      dma_write                    : out std_logic;
      dma_wdata                    : out std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      dma_rdata                    : in  std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      dma_word_enable              : out std_logic_vector(RAM_DATAWIDTH/32-1 downto 0);
      sync_sieint_epinfo_req       : in  std_logic;
      sync_sieint_epinfo_epnr      : in  std_logic_vector(3 downto 0);
      sync_sieint_epinfo_epdir     : in  std_logic;
      sync_sieint_epinfo_setup     : in  std_logic;
      epinfo_sync_valid            : out std_logic;
      epinfo_sync_active           : out std_logic;
      epinfo_sync_disabled         : out std_logic;
      epinfo_sync_toggle           : out std_logic;
      epinfo_sync_stall            : out std_logic;
      epinfo_sync_iso              : out std_logic;
      epinfo_sync_ratefeedbackmode : out std_logic;
      epinfo_sync_nbytes           : out std_logic_vector(14 downto 0);
      epinfo_sync_maxpacket        : out std_logic_vector(1 downto 0);
      sync_sieint_txdatafetched    : in  std_logic;
      epinfo_sync_txdata           : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
      epinfo_sync_txdata_valid     : out std_logic;
      sync_sieint_rx_nbytes        : in  std_logic_vector(11 downto 0);
      sync_sieint_rxdata           : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
      sync_sieint_rxdatavalid      : in  std_logic;
      sync_sieint_endtransfer      : in  std_logic;
      sync_sieint_success          : in  std_logic;
      sync_sieint_sentNAK          : in  std_logic;
      sync_busreset                : in  std_logic;
      dma_ahb_selected             : out std_logic;
      usbreg_setup                 : in  std_logic;
      pie_speed                    : in  std_logic_vector( 1 downto      0);
      usbreg_ep_list_start         : in  std_logic_vector(31 downto      8);
      usbreg_ep_skip_list_start    : in  std_logic_vector(31 downto      8);
      usbreg_data_buffer_start     : in  std_logic_vector(31 downto C_DALB);
      usbreg_ep_bufinuse           : in  std_logic_vector(C_NBPHYSEP+1 downto 0);
      usbreg_ep_skip               : in  std_logic_vector(C_NBPHYSEP+1 downto 0);
      usbreg_epinfo_toggle         : in std_logic_vector(C_NBPHYSEP+1 downto 0);
      dma_clear_toggle             : out std_logic;
      dma_set_toggle               : out std_logic;
      dma_sent_NAK                 : out std_logic;
      dma_set_int                  : out std_logic;
      dma_physepnr                 : out integer range 0 to C_NBPHYSEP+1;
      dma_clear_skip               : out std_logic;
      dma_skip_ep                  : out integer range 0 to C_NBPHYSEP+1;
      usb_dma_fpga                 : out std_logic_vector(63 downto 0)
     );
end component;

component usb_ahb_slave
  port (
      hclk              : in    std_logic;
      hresetn           : in    std_logic;
      haddr             : in    std_logic_vector(5 downto 2);
      hwrite            : in    std_logic;
      hsel              : in    std_logic;
      htrans1           : in    std_logic;
      hwdata            : in    std_logic_vector(31 downto 0);
      hrdata            : out   std_logic_vector(31 downto 0);
      hresp             : out   std_logic_vector(1 downto 0);
      hready            : out   std_logic;
      hready_glb        : in    std_logic;
      reg_waddr         : out   std_logic_vector(3 downto 0);
      reg_wdata         : out   std_logic_vector(31 downto 0);
      reg_raddr         : out   std_logic_vector(3 downto 0);
      reg_rdata         : in    std_logic_vector(31 downto 0);
      reg_write         : out   std_logic
     );
end component;

component usb_fs_mux
  generic(C_DATAWIDTH        : integer := 32);
  port (
      dma_dma_addr      : in   std_logic_vector(31 downto 0);
      dma_dma_req       : in   std_logic;
      dma_dma_gnt       : out  std_logic;
      dma_dma_write     : in   std_logic;
      dma_dma_wdata     : in   std_logic_vector(C_DATAWIDTH-1 downto 0);
      dma_dma_rdata     : out  std_logic_vector(C_DATAWIDTH-1 downto 0);

      ahb_dma_addr      : out  std_logic_vector(31 downto 0);
      ahb_dma_req       : out  std_logic;
      ahb_dma_gnt       : in   std_logic;
      ahb_dma_write     : out  std_logic;
      ahb_dma_wdata     : out  std_logic_vector(C_DATAWIDTH-1 downto 0);
      ahb_dma_rdata     : in   std_logic_vector(C_DATAWIDTH-1 downto 0);

      upd_dma_addr      : out  std_logic_vector(31 downto 0);
      upd_dma_req       : out  std_logic;
      upd_dma_gnt       : in   std_logic;
      upd_dma_write     : out  std_logic;
      upd_dma_wdata     : out  std_logic_vector(C_DATAWIDTH-1 downto 0);
      upd_dma_rdata     : in   std_logic_vector(C_DATAWIDTH-1 downto 0);

      dma_ahb_selected  : in   std_logic
     );
end component;

component usb_ep0_handler
generic(C_NBPHYSEP     : integer := 2;
        C_NBDEV        : integer := 2;
        C_DATAWIDTH    : integer := 32;
        C_EPNBYTEWIDTH : integer := 15);
  port (
      clk               : in  std_logic;
      rst_n             : in  std_logic;

      upd_dma_addr      : in  std_logic_vector(14 downto 0);
      upd_dma_req       : in  std_logic;
      upd_dma_gnt       : out std_logic;
      upd_dma_write     : in  std_logic;
      upd_dma_wdata     : in  std_logic_vector(C_DATAWIDTH-1 downto 0);
      upd_dma_rdata     : out std_logic_vector(C_DATAWIDTH-1 downto 0);

      usbreg_setup_to_decode : in std_logic_vector(C_NBDEV-1 downto 0);

      ep0_setupdone     : out std_logic_vector(C_NBDEV-1 downto 0);
      ep0_new_address   : out std_logic;
      ep0_address       : out std_logic_vector(6 downto 0); --New address communicated by SET_ADDRESS command.
      ep0_device_config : out std_logic_vector(C_NBDEV-1 downto 0);

      ep0_remote_wake_enabled : out std_logic_vector(C_NBDEV-1 downto 0);
      ep_set_stall      : out std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_clear_stall    : out std_logic_vector(C_NBPHYSEP-1 downto 0);

      ep0_out_active    : out std_logic;
      ep0_in_active     : out std_logic;
      ep0_outin_nbytes  : out std_logic_vector( C_EPNBYTEWIDTH-1 downto 0);
      ep0_setup_dir     : out std_logic;
      ep0_data_buffer   : out std_logic_vector( 7 downto 0);

      ep0_request       : out std_logic_vector( 6 downto 0);
      ep0_wvalue        : out std_logic_vector(15 downto 0);
      ep0_windex        : out std_logic_vector(15 downto 0);
      ep0_class_rdata   : in  std_logic_vector(C_DATAWIDTH-1 downto 0);
      ep0_class_addr    : out std_logic_vector( 3 downto 0);

      ep0_mem_req       : out std_logic;
      ep0_mem_gnt       : in  std_logic;
      ep0_mem_addr      : out std_logic_vector(11 downto 0); --DWORD address - max is 4k 32bit words
      ep0_mem_rdata     : in  std_logic_vector(C_DATAWIDTH-1 downto 0);

      sync_busreset     : in  std_logic;
      usbreg_dev_connect: in  std_logic;

      usb_phy_test_mode : out std_logic_vector(2 downto 0);
      usb_self_powered  : in  std_logic;
      epconfig_stall    : in  std_logic_vector(C_NBPHYSEP-1 downto 0)

     );
end component;

component usb_ep_config_handler
generic(C_NBPHYSEP     : integer := 2;
        C_NBDEV        : integer := 2;
        C_EPADDRWIDTH  : integer := 11;
        C_EPNBYTEWIDTH : integer := 15; 
        C_DATAWIDTH    : integer := 32;
        HIGH_SPEED_SUPPORT : boolean := FALSE );
  port (
      clk                 : in  std_logic;
      rst_n               : in  std_logic;

      upd_dma_addr        : in  std_logic_vector(14 downto 0);
      upd_dma_req         : in  std_logic;
      upd_dma_gnt         : out std_logic;
      upd_dma_write       : in  std_logic;
      upd_dma_wdata       : in  std_logic_vector(C_DATAWIDTH-1 downto 0);
      upd_dma_rdata       : out std_logic_vector(C_DATAWIDTH-1 downto 0);

      ep0_setupdone       : in  std_logic_vector(C_NBDEV-1 downto 0);
      ep0_out_active      : in  std_logic;
      ep0_in_active       : in  std_logic;
      ep0_outin_nbytes    : in  std_logic_vector( C_EPNBYTEWIDTH-1 downto 0);
      ep0_setup_dir       : in  std_logic;
      ep0_data_buffer     : in  std_logic_vector( 7 downto 0);

      ep_clk              : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_rst_n            : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_stall            : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_clear_buffer     : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_enable_buffer    : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_buffer_size      : in  std_logic_vector(C_NBPHYSEP*7-1 downto 0); --Buffer_size is a 7 bit signal

      buf_nbytes          : out std_logic_vector(C_NBPHYSEP*11 -1 downto 0); --Range should be dependent if double buffer supported or not
      buf_reset_addr_ptr  : out std_logic_vector(C_NBPHYSEP-1 downto 0); --Range should be dependent if double buffer supported or not

      ep_bufinuse         : out std_logic_vector(C_NBPHYSEP+1 downto 0);

      ep_set_stall        : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_clear_stall      : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      epconfig_stall      : out std_logic_vector(C_NBPHYSEP-1 downto 0);

      ep0_device_config   : in  std_logic_vector(C_NBDEV-1 downto 0)

     );
end component;




component usb_app_hw_hub
generic(C_HUB_NB_PORTS     : integer := 2; --This can be maximum 255 according to USB spec
        C_DATAWIDTH        : integer := 32);
  port (
      sys_clk                : in  std_logic;
      sys_rst_n              : in  std_logic;
      sync_busreset          : in  std_logic;
      pie_speed              : in  std_logic_vector( 1 downto 0);

      -- HUB Status IN endpoint
      hub_epin_req           : in  std_logic;
      hub_epin_gnt           : out std_logic;
      hub_epin_addr          : in  std_logic_vector(2 downto 0); -- only needed when more than 31 downstream ports
      hub_epin_rdata         : out std_logic_vector(C_DATAWIDTH-1 downto 0);
      hub_epin_stall         : out std_logic;
      hub_epin_clear_buffer  : out std_logic;
      hub_epin_enable_buffer : out std_logic;
      hub_epin_buffer_size   : out std_logic_vector(6 downto 0);

      -- HUB Class-specific requests
      ep0_setupdone          : in  std_logic;
      ep0_request            : in  std_logic_vector( 6 downto 0);
      ep0_wvalue             : in  std_logic_vector(15 downto 0);
      ep0_windex             : in  std_logic_vector(15 downto 0);
      ep0_class_rdata        : out std_logic_vector(C_DATAWIDTH-1 downto 0);

      -- DOWNSTREAM PORTS
      hub_port_connect       : in  std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_port_enable        : out std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_port_reset         : out std_logic_vector(C_HUB_NB_PORTS-1 downto 0)
     );
end component;


component usb_clock_gate 
  port(
      ip_Clk            : in  std_logic;
      ip_Clk_en         : in  std_logic;
      op_Clk_g          : out  std_logic;
      ip_tcb_clkgate_se : in  std_logic
    );
end component;

-- resets
signal RG_BUSReset     : boolean;
signal reset_n         : std_logic;
signal reset_awake_n   : std_logic;
signal hreset_awake_n  : std_logic;
signal utmiclk_reset_n : std_logic;

signal TM_Suspend: boolean;
signal TM_IsoToggle: integer range 0 to 1;

signal reg_waddr : std_logic_vector( 3 downto 0);
signal reg_wdata : std_logic_vector(31 downto 0);
signal reg_raddr : std_logic_vector( 3 downto 0);
signal reg_rdata : std_logic_vector(31 downto 0);
signal reg_write : std_logic;

signal dev1_reg_waddr : std_logic_vector( 3 downto 0);
signal dev1_reg_wdata : std_logic_vector(31 downto 0);
signal dev1_reg_raddr : std_logic_vector( 3 downto 0);
signal dev1_reg_rdata : std_logic_vector(31 downto 0);
signal dev1_reg_write : std_logic;

signal hub_reg_waddr : std_logic_vector( 3 downto 0);
signal hub_reg_wdata : std_logic_vector(31 downto 0);
signal hub_reg_raddr : std_logic_vector( 3 downto 0);
signal hub_reg_rdata : std_logic_vector(31 downto 0);
signal hub_reg_write : std_logic;

signal hub_enable_q : std_logic;
signal hub_dcon_q   : std_logic;
signal hub_enable_eff : std_logic;

signal dev1_usbreg_usbaddress        : std_logic_vector(6 downto 0);
signal dev1_usbreg_usbaddress_tmp    : std_logic_vector(6 downto 0);
signal dev1_usbreg_deviceenabled     : std_logic;
signal dev1_usbreg_setup             : std_logic;
signal dev1_usbreg_dev_connect       : std_logic;
signal dev1_usbreg_ep_list_start     : std_logic_vector(31 downto 0);
signal dev1_usbreg_data_buffer_start : std_logic_vector(31 downto 0);
signal dev1_usbreg_ep_skip           : std_logic_vector(C_NBPHYSEP_ARM+1 downto 0);
signal dev1_usbreg_ep_bufinuse       : std_logic_vector(C_NBPHYSEP_ARM+1 downto 0);
signal dev1_usbreg_epinfo_toggle     : std_logic_vector(C_NBPHYSEP_ARM+1 downto 0);

signal LPM_RW           : boolean;
signal sieint_epinfo_req:      std_logic;
signal sieint_epinfo_epnr:     std_logic_vector(3 downto 0);
signal sieint_epinfo_epdir:    std_logic;
signal sieint_epinfo_setup:    std_logic;
signal sieint_epinfo_setup_received:    std_logic;
signal epinfo_valid:               std_logic;
signal epinfo_active:               std_logic;
signal epinfo_disabled:        std_logic;
signal epinfo_toggle:               std_logic;
signal epinfo_stall:               std_logic;
signal epinfo_iso:               std_logic;
signal epinfo_nbytes:               std_logic_vector(14 downto 0);
signal epinfo_maxpacket:       std_logic_vector(1 downto 0);
signal sieint_txdatafetched:   std_logic;
signal epinfo_txdata:               std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
signal epinfo_txdata_valid:    std_logic;
signal sieint_rx_nbytes:       std_logic_vector(11 downto 0);
signal sieint_rxdata:               std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
signal sieint_rxdatavalid:     std_logic;
signal sieint_endtransfer:     std_logic;
signal sieint_success:         std_logic;
signal sieint_error:               std_logic;
signal sieint_errortype:       std_logic_vector(3 downto 0);
signal sieint_sentNAK:         std_logic;
signal sync_sieint_epinfo_req:   std_logic;
signal sync_sieint_epinfo_epnr:  std_logic_vector(3 downto 0);
signal sync_sieint_epinfo_epdir: std_logic;
signal sync_sieint_epinfo_setup: std_logic;
signal epinfo_sync_valid:            std_logic;
signal epinfo_sync_active:            std_logic;
signal epinfo_sync_disabled:            std_logic;
signal epinfo_sync_toggle:            std_logic;
signal epinfo_sync_stall:            std_logic;
signal epinfo_sync_iso:             std_logic;
signal epinfo_sync_ratefeedbackmode:std_logic;
signal epinfo_sync_nbytes:            std_logic_vector(14 downto 0);
signal epinfo_sync_maxpacket:       std_logic_vector(1 downto 0);
signal sync_sieint_txdatafetched:   std_logic;
signal epinfo_sync_txdata:            std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
signal epinfo_sync_txdata_valid:    std_logic;
signal sync_sieint_rx_nbytes:            std_logic_vector(11 downto 0);
signal sync_sieint_rxdata:            std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
signal sync_sieint_rxdatavalid:     std_logic;
signal sync_sieint_endtransfer:     std_logic;
signal sync_sieint_success:            std_logic;
signal sync_sieint_error:            std_logic;
signal sync_sieint_errortype:            std_logic_vector(3 downto 0);
signal sync_sieint_sentNAK:            std_logic;
signal sync_busreset            : std_logic;
signal sync_suspend             : std_logic;
signal sync_lpm_suspend         : std_logic;
signal sync_lpm_rw              : std_logic;
signal usbreg_lpm_sup           : std_logic;
signal sync_usbreg_lpm_sup      : std_logic;
signal usbreg_dev_connect        : std_logic;
signal usbreg_ep_list_start        : std_logic_vector(31 downto 0);
signal usbreg_data_buffer_start : std_logic_vector(31 downto 0);
signal usbreg_lpm_hird_sw        : std_logic_vector( 3 downto 0);
signal sync_usbreg_lpm_hird_sw   : std_logic_vector( 3 downto 0);
signal sieint_lpm_hird_hw        : std_logic_vector( 3 downto 0);
signal sync_sieint_lpm_hird_hw   : std_logic_vector( 3 downto 0);
signal usbreg_lpm_nyet           : std_logic;
signal sync_usbreg_lpm_nyet      : std_logic;
signal usbreg_ep_skip            : std_logic_vector(C_NBPHYSEP_ARM+1 downto 0);
signal usbreg_ep_bufinuse        : std_logic_vector(C_NBPHYSEP_ARM+1 downto 0);
--signal dma_ep_bufinuse          : std_logic_vector(C_NBPHYSEP_ARM+1 downto 0);
signal usbreg_pll_on          : std_logic;
signal sync_usbreg_pll_on     : std_logic;
signal usbreg_deviceenabled   : std_logic_vector(C_NBDEV+1 downto 0);
--signal sync_usbreg_deviceenabled : std_logic_vector(C_NBDEV+1 downto 0);
signal usbreg_remotewakeup    : std_logic;
signal usbreg_lpmremotewakeup : std_logic;
signal usbreg_frame_number    : std_logic_vector(10 downto 0);
signal sync_usbreg_frame_number : std_logic_vector(10 downto 0);
signal sieint_usbaddress      : std_logic_vector(6 downto 0);
signal usbreg_usbaddress      : std_logic_vector(6 downto 0);
signal usbreg_usbaddress_tmp  : std_logic_vector(6 downto 0);
signal usbreg_setup           : std_logic;
signal pie_speed              : std_logic_vector(1 downto 0);
signal sync_pie_speed         : std_logic_vector(1 downto 0);
signal usbreg_phy_test_mode   : std_logic_vector(2 downto 0);
signal ep0_phy_test_mode      : std_logic_vector(2 downto 0);
signal usb_phy_test_mode      : std_logic_vector(2 downto 0);
signal sync_sieint_setup_received:  std_logic;
signal dma_epinfo_toggle:      std_logic_vector(C_NBPHYSEP_ARM+1 downto 0);
signal usbreg_epinfo_toggle  : std_logic_vector(C_NBPHYSEP_ARM+1 downto 0);
signal dma_clear_toggle      : std_logic;
signal dma_set_toggle        : std_logic;
signal dma_sent_NAK          : std_logic;
signal dma_set_int           : std_logic;
signal usbreg_dma_sent_NAK   : std_logic;
signal usbreg_dma_set_int    : std_logic;
signal dma_physepnr          : integer range 0 to C_NBPHYSEP_ARM+1;
signal LPM_TM_Suspend:         boolean;
signal sync_set_frameint:       std_logic;
signal dma_clear_skip:          std_logic;
signal dma_skip_ep:             integer range 0 to C_NBPHYSEP_ARM+1;
signal sync_s_reset_n:         std_logic;
signal sync_ss_reset_n:        std_logic;

signal pie_isotoggle:          std_logic;
signal pie_suspend:            std_logic;
signal pie_lpm_suspend:        std_logic;
signal pie_lpm_remotewake_enable: std_logic;
signal pie_devicespeed:        std_logic;
signal pie_busreset:        std_logic;

signal usbreg_phy_addr          : std_logic_vector(7 downto 0);
signal usbreg_phy_wdata         : std_logic_vector(7 downto 0);
signal sync_phy_rdata                : std_logic_vector(7 downto 0);
signal usbreg_phy_write         : std_logic;
signal usbreg_phy_start         : std_logic;
signal usbreg_phy_mode          : std_logic;
signal sync_phy_endtoggle       : std_logic;
signal phy_addr                 : std_logic_vector(7 downto 0);
signal phy_wdata                : std_logic_vector(7 downto 0);
signal phy_rdata                : std_logic_vector(7 downto 0);
signal phy_write                : std_logic;
signal phy_start                : std_logic;
signal phy_mode                 : std_logic;
signal phy_endtoggle            : std_logic;

signal reset_needed             : std_logic;
signal reset_needed_z           : std_logic;
signal reset_needed_zz          : std_logic;
signal atx_reset_core           : std_logic;
signal clk_counter_atx_core     : integer range 0 to RESET_CYCLE;
signal utmi_clk_ok              : std_logic;
signal pie_lowpower_n           : std_logic;
signal clock_on                 : std_logic;
--below required for the clock_on multi cycle path on clock_on when it is connected to  debug_fpga_3511
-- synthesis read_comments_as_HDL on
-- attribute keep: boolean;
-- attribute keep of clock_on: signal is true;
-- synthesis read_comments_as_HDL off

signal VBusDebounced            : std_logic;
signal dp_s                     : std_logic;
signal dm_s                     : std_logic;
constant CLOCKOFF_CYCLE         : integer := 255;
signal clk_off_counter          : integer range 0 to CLOCKOFF_CYCLE;

signal usbram_word_enable_int :
  std_logic_vector(RAM_DATAWIDTH/32-1 downto 0);
signal usb_dma_dword_selection_int :
  std_logic_vector(RAM_DATAWIDTH/32-1 downto 0);
signal usbreg_port_force_fullspeed : std_logic;

signal mem_d_int         : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal mem_cs_int         : std_logic; --active high mem select
signal mem_a_int         : std_logic_vector(RAM_ADDRWIDTH-1 downto 0);
signal mem_web_out_int   : std_logic; --active low write enable
signal mem_bsel_int      : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal ahbs_dma_hrdata_int          : std_logic_vector(AHB_DATAWIDTH-1 downto 0);
signal ahbs_dma_hresp_int          : std_logic_vector(1 downto 0);
signal ahbs_dma_hreadyout_int : std_logic;

signal ahb_dma_addr        : std_logic_vector(31 downto 0);
signal ahb_dma_addr_masked : std_logic_vector(31 downto 0);
signal ahb_dma_req         : std_logic;
signal ahb_dma_write       : std_logic;
signal ahb_dma_wdata       : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal ahb_dma_gnt         : std_logic;
signal ahb_dma_rdata       : std_logic_vector(RAM_DATAWIDTH-1 downto 0);

signal dev0_dma_req        : std_logic;
signal dev0_dma_gnt        : std_logic;
signal dev0_dma_rdata      : std_logic_vector(RAM_DATAWIDTH-1 downto 0);

signal dev1_dma_req        : std_logic;
signal dev1_dma_gnt        : std_logic;
signal dev1_dma_rdata      : std_logic_vector(RAM_DATAWIDTH-1 downto 0);

signal pie_clk : std_logic; -- UTMI/ULPI clock
subtype S_DebounceTimer is integer range 0 to VBUS_DEBOUNCE_TIME;
signal DebounceTimer: S_DebounceTimer;
signal pie_isotoggle_r : std_logic;
signal sync_VBusDebounced : std_logic;
signal pie_vbusvalid: std_logic;
signal pie_vbusvalid_r: std_logic;
signal usb_needclk_int : std_logic;
signal dp, dm: std_logic;
signal ulpi_pwrctrl_wakeup: std_logic;
signal ulpi_dir_s: std_logic;
signal ulpi_dir_ss: std_logic;
signal ulpi_dir_sss: std_logic;
signal ulpi_linestate_lp: std_logic_vector (1 downto 0);
signal ulpi_int_lp : std_logic;
signal dataline_low_power_en : std_logic;
constant CLOCK_COUNTER_AHB_MAX         : integer := 63; -- This allows an AHB clock frequency of maximum 480MHz
signal clock_counter_ahb: integer range 0 to CLOCK_COUNTER_AHB_MAX;
constant CLOCK_COUNTER_USB_MAX         : integer := 15;
signal clock_counter_usb : integer range 0 to CLOCK_COUNTER_USB_MAX;
signal clock_counter_usb_msb,clock_counter_usb_msb_z,clock_counter_usb_msb_zz : std_logic;

signal pwrctrl_wakeup_int : std_logic;
signal awake: std_logic;
signal set_pwrctrl_wakeup : std_logic;

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

signal dma_dma_addr  : std_logic_vector(31 downto 0); 
signal dma_dma_req   : std_logic;
signal dma_dma_gnt   : std_logic;
signal dma_dma_write : std_logic;
signal dma_dma_wdata : std_logic_vector(RAM_DATAWIDTH-1 downto 0); 
signal dma_dma_rdata : std_logic_vector(RAM_DATAWIDTH-1 downto 0);  
signal upd_dma_addr  : std_logic_vector(31 downto 0); 
signal upd_dma_req   : std_logic;
signal upd_dma_gnt   : std_logic;
signal upd_dma_write : std_logic;
signal upd_dma_wdata : std_logic_vector(RAM_DATAWIDTH-1 downto 0); 
signal upd_dma_rdata : std_logic_vector(RAM_DATAWIDTH-1 downto 0);  

-- reg interface
signal usbreg_arm_deviceenabled : std_logic;
signal usbreg_setup_to_dma_bus  : std_logic_vector(C_NBDEV+1 downto 0);
signal usbreg_setup_to_dma      : std_logic;
signal usbreg_setup_to_decode   : std_logic_vector(C_NBDEV-1 downto 0);
signal pie_dev_selected         : integer range 0 to C_NBDEV+1;
signal sync_pie_dev_selected    : integer range 0 to C_NBDEV+1;


signal dma_ep_list_start        : std_logic_vector(23 downto 0);
signal dma_data_buffer_start    : std_logic_vector(31 downto C_DALB);
signal dma_ep_skip_selected     : std_logic_vector(C_NBPHYSEP_ARM+1 downto 0);
signal dma_ep_bufinuse_selected : std_logic_vector(C_NBPHYSEP_ARM+1 downto 0);

signal dev0_setup_received      : std_logic;
signal dev1_setup_received      : std_logic;

signal dev0_dma_clear_toggle    : std_logic;
signal dev0_dma_set_toggle      : std_logic;
signal dev0_dma_sent_nak        : std_logic;
signal dev0_dma_set_int         : std_logic;
signal dev0_dma_clear_skip      : std_logic;

signal dev1_dma_clear_toggle    : std_logic;
signal dev1_dma_set_toggle      : std_logic;
signal dev1_dma_sent_nak        : std_logic;
signal dev1_dma_set_int         : std_logic;
signal dev1_dma_clear_skip      : std_logic;

signal usb_hubenable_s          : std_logic;
signal usb_hubenable_ss         : std_logic;
signal dma_ahb_selected         : std_logic;
signal arm_dev_setup_received   : std_logic;
signal upd_arm_dev_portreset    : std_logic;
signal arm_dev_portreset        : std_logic;
signal upd_dev1_portreset       : std_logic;
signal dev1_portreset           : std_logic;

signal reg_dev_addr     : std_logic_vector(C_NBDEV*7-1 downto 0);
signal reg_dev_addr_tmp : std_logic_vector(C_NBDEV*7-1 downto 0);

signal pie_dev_addr     : std_logic_vector((C_NBDEV+2)*7-1 downto 0);
signal pie_dev_addr_tmp : std_logic_vector((C_NBDEV+2)*7-1 downto 0);

signal usb_dev_connect  : std_logic;

signal epin_except_write         : std_logic;
signal epin_except_byte_addr     : std_logic_vector(10 downto 0);
signal epin_except_byte_value    : std_logic_vector(7  downto 0);

-- ep_ram_handler interfaces
signal epout_data                : std_logic_vector(C_NBPHYSEP_OUT*8-1 downto 0);
signal epout_data_valid          : std_logic_vector(C_NBPHYSEP_OUT-1 downto 0);
signal epout_data_last           : std_logic_vector(C_NBPHYSEP_OUT-1 downto 0);
signal epout_data_accept         : std_logic_vector(C_NBPHYSEP_OUT-1 downto 0);
signal bufout_nbytes             : std_logic_vector((C_NBPHYSEP_OUT*11)-1 downto 0);
signal bufout_reset_addr_ptr     : std_logic_vector(C_NBPHYSEP_OUT-1 downto 0);
signal epin_data                 : std_logic_vector((C_NBPHYSEP_IN-1)*8-1 downto 0);
signal epin_data_valid           : std_logic_vector(C_NBPHYSEP_IN-2 downto 0);
signal epin_data_last            : std_logic_vector(C_NBPHYSEP_IN-2 downto 0);
signal epin_data_accept          : std_logic_vector(C_NBPHYSEP_IN-2 downto 0);
signal bufin_nbytes              : std_logic_vector((C_NBPHYSEP_IN-1)*11-1 downto 0);
signal bufin_reset_addr_ptr      : std_logic_vector(C_NBPHYSEP_IN-2 downto 0);
signal epin_except_write_int     : std_logic_vector(C_NBPHYSEP_IN-2 downto 0);
signal epin_except_byte_addr_int  : std_logic_vector((C_NBPHYSEP_IN-1)*11-1 downto 0);
signal epin_except_byte_value_int : std_logic_vector((C_NBPHYSEP_IN-1)*8-1  downto 0);

-- hub interface
signal hub_epin_stall          : std_logic;
signal hub_epin_clear_buffer   : std_logic;
signal hub_epin_enable_buffer  : std_logic;
signal hub_epin_buffer_size    : std_logic_vector(6 downto 0); --Buffer_size is a 7 bit signal
signal hub_connect             : std_logic;
signal hub_port_connect        : std_logic_vector(1 downto 0);
signal hub_port_enable         : std_logic_vector(1 downto 0);
signal hub_port_reset          : std_logic_vector(1 downto 0);

-- ep config handler interface
signal ep_clear_buffer    : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal ep_enable_buffer   : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal ep_buffer_size     : std_logic_vector(C_NBPHYSEP*7-1 downto 0); --Buffer_size is a 7 bit signal
signal buf_nbytes         : std_logic_vector(C_NBPHYSEP*11 -1 downto 0); --Range should be dependent if double buffer supported or not
signal buf_reset_addr_ptr : std_logic_vector(C_NBPHYSEP-1 downto 0); --Range should be dependent if double buffer supported or not

-- upd interface (out of mux)
signal upd_dma_req_ep0        : std_logic;
signal upd_dma_req_config     : std_logic;
signal upd_dma_req_ep_hub     : std_logic;
signal upd_dma_gnt_ep0        : std_logic;
signal upd_dma_gnt_config     : std_logic;
signal upd_dma_gnt_ep_noram   : std_logic;
signal upd_dma_rdata_ep0      : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal upd_dma_rdata_config   : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal upd_dma_rdata_ep_noram : std_logic_vector(RAM_DATAWIDTH-1 downto 0);

--ep0 interfaces
signal ep0_setupdone   : std_logic_vector(C_NBDEV-1 downto 0);
signal ep0_new_address   : std_logic;
signal ep0_address   : std_logic_vector(6 downto 0); --New address communicated by SET_ADDRESS command.
signal ep0_device_config : std_logic_vector(C_NBDEV-1 downto 0);
--signal ep0_remote_wake_enabled : std_logic_vector(C_NBDEV-1 downto 0);
signal ep_set_stall   : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal ep_clear_stall   : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal ep0_out_active   : std_logic;
signal ep0_in_active   : std_logic;
signal ep0_outin_nbytes  : std_logic_vector(C_EPNBYTEWIDTH-1 downto 0);
signal ep0_setup_dir   : std_logic;
signal ep0_data_buffer   : std_logic_vector( 7 downto 0);
signal ep0_request   : std_logic_vector( 6 downto 0);
signal ep0_wvalue   : std_logic_vector(15 downto 0);
signal ep0_windex   : std_logic_vector(15 downto 0);
signal ep0_mem_req   : std_logic;
signal ep0_mem_gnt   : std_logic;
signal ep0_mem_addr   : std_logic_vector(11 downto 0); --DWORD address - max is 4k 32bit words
signal ep0_mem_rdata   : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal ep0_class_rdata  : std_logic_vector(RAM_DATAWIDTH-1 downto 0);

signal hub_desc_dma_addr     : std_logic_vector(31 downto 0);
signal hub_desc_dma_req      : std_logic;
signal hub_desc_dma_gnt      : std_logic;
signal hub_desc_dma_rdata    : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal hub_desc_dma_dword_en : std_logic_vector(RAM_DATAWIDTH/32-1 downto 0);

-- ep_ram_handler
signal epin_clk          : std_logic_vector(C_NBPHYSEP_IN-2 downto 0);
signal epin_rst_n        : std_logic_vector(C_NBPHYSEP_IN-2 downto 0);
signal epout_clk         : std_logic_vector(C_NBPHYSEP_OUT-1 downto 0);
signal epout_rst_n       : std_logic_vector(C_NBPHYSEP_OUT-1 downto 0);

-- ep_config handler
signal ep_clk            : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal ep_rst_n          : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal epconfig_stall    : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal ep_stall          : std_logic_vector(C_NBPHYSEP-1 downto 0);

signal emb_epinfo_toggle : std_logic_vector(C_NBPHYSEP_ARM+1 downto 0);
signal emb_ep_toggle     : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal emb_ep0_toggle    : std_logic_vector(C_NBDEV*2-1 downto 0);

-- fpga debug probes 
signal usb_dma_fpga      : std_logic_vector(63 downto 0);
signal usb_reg_if_fpga   : std_logic_vector(63 downto 0);
signal ahb_dma_slave_fpga : std_logic_vector(63 downto 0);
signal usb_pie_fpga       : std_logic_vector(63 downto 0);
signal zero7              : std_logic_vector(6 downto 0);

constant AHB_ADDR_INDEX : integer := RAM_ADDRWIDTH + log2(RAM_DATAWIDTH/8);


begin

zero7 <= (others => '0');

PROC_HUB_CTRL : process(hclk, ahbs_resetn)
begin
  if ahbs_resetn = '0' then
    hub_enable_q <= '0';
    hub_dcon_q   <= '0';
  elsif rising_edge(hclk) then
    if hub_reg_write = '1' and hub_reg_waddr = X"0" then
      hub_enable_q <= hub_reg_wdata(7);
      hub_dcon_q   <= hub_reg_wdata(16);
    end if;
  end if;
end process PROC_HUB_CTRL;

PROC_HUB_REG_READ : process(
  hub_reg_raddr,
  hub_enable_q,
  hub_dcon_q
)
begin
  hub_reg_rdata <= (others => '0');

  if hub_reg_raddr = X"0" then
    hub_reg_rdata(7)  <= hub_enable_q;
    hub_reg_rdata(16) <= hub_dcon_q;
  end if;
end process PROC_HUB_REG_READ;

hub_enable_eff <= usb_hubenable_ss or hub_enable_q;


  vbuscomp_on <= vbuscomp_on_int;
 
  pie_speed <= FULL_SPEED when pie_devicespeed = '0' else HIGH_SPEED;

  -- TODO : make sure USB_FrameToggle is 1kHz clock.
  USB_FrameToggle <= pie_isotoggle;
  
  TM_IsoToggle   <= 1 when pie_isotoggle = '1' else 0;
  TM_suspend     <= (pie_suspend = '1');
  LPM_TM_suspend <= (pie_lpm_suspend = '1');
  LPM_RW         <= (pie_lpm_remotewake_enable = '1');
  RG_busreset    <= (pie_busreset = '1');

  usb_phy_test_mode <= usbreg_phy_test_mode when usb_hubenable_ss = '0' else ep0_phy_test_mode;

usb_pie_1 : usb_pie
  generic map(ULPI_SUPPORT      => C_ULPI_SUPPORT,
              UTMI_SUPPORT      => C_UTMI_SUPPORT,
              USB_DATAWIDTH     => USBPIE_DATAWIDTH,
              C_NBDEV           => C_NBDEV+2,  -- C_NBDEV hardware devices + 2 software devices
              C_NBPHYSEP        => C_NBPHYSEP_ARM,
              C_EXTEND_TX_DELAY => C_EXTEND_TX_DELAY
              )
  port map   (
             pie_epinfo_req               => sieint_epinfo_req,
             pie_epinfo_epnr              => sieint_epinfo_epnr,
             pie_epinfo_epdir             => sieint_epinfo_epdir,
             pie_epinfo_setup             => sieint_epinfo_setup,
             pie_epinfo_setup_received    => sieint_epinfo_setup_received,
             pie_usbaddress               => sieint_usbaddress, --
             epinfo_valid                 => epinfo_valid,
             epinfo_active                => epinfo_active,
             epinfo_disabled              => epinfo_disabled,
             epinfo_toggle                => epinfo_toggle,
             epinfo_stall                 => epinfo_stall,
             epinfo_iso                   => epinfo_iso,
             epinfo_nbytes                => epinfo_nbytes,
             epinfo_maxpacket             => epinfo_maxpacket,
             pie_txdata_fetched           => sieint_txdatafetched,
             epinfo_txdata                => epinfo_txdata,
             epinfo_txdata_valid          => epinfo_txdata_valid,
             pie_rx_nbytes                => sieint_rx_nbytes,
             pie_rxdata                   => sieint_rxdata,
             pie_rxdatavalid              => sieint_rxdatavalid,
             pie_endtransfer              => sieint_endtransfer,
             pie_success                  => sieint_success,
             pie_error                    => sieint_error,
             pie_errortype                => sieint_errortype,
             pie_sentNAK                  => sieint_sentNAK,
             pie_isotoggle                => pie_isotoggle,
             pie_busreset                 => pie_busreset,
             pie_devicespeed              => pie_devicespeed, --|
             pie_suspend                  => pie_suspend,
             pie_lpm_suspend              => pie_lpm_suspend,
             pie_lpm_remotewake_enable    => pie_lpm_remotewake_enable,
             pie_lpm_hird_hw              => sieint_lpm_hird_hw, --|
             pie_vbusvalid                => pie_vbusvalid,
             pie_lowpower_n               => pie_lowpower_n,
             reset_n                      => reset_n,
             pie_clk                      => pie_clk,

             phy_address                  => phy_addr,
             phy_readdata                 => phy_rdata,
             phy_writedata                => phy_wdata,
             phy_write                    => phy_write,
             phy_start                    => phy_start,
             phy_endtoggle                => phy_endtoggle,
             phy_mode                     => phy_mode,
             sync_usbreg_phy_test_mode_change  => sync_usbreg_phy_test_mode_change,
             sync_usbreg_remotewakeup     => sync_usbreg_remotewakeup,
             sync_usbreg_lpmremotewakeup  => sync_usbreg_lpmremotewakeup,

             usbreg_pll_on                => sync_usbreg_pll_on, --|
             usbreg_deviceenabled         => usbreg_deviceenabled,  --<<<< LAB synchro problem!
             usbreg_dev_connect           => sync_usbreg_dev_connect,
             usbreg_remotewakeup          => usbreg_remotewakeup,
             usbreg_lpm_sup               => sync_usbreg_lpm_sup, --|
             usbreg_lpmremotewakeup       => usbreg_lpmremotewakeup,
             usbreg_lpm_hird_sw           => sync_usbreg_lpm_hird_sw, --|
             usbreg_lpm_nyet              => sync_usbreg_lpm_nyet, --|
             usbreg_frame_number          => usbreg_frame_number, --|
             usbreg_usbaddress            => pie_dev_addr, --
             usbreg_usbaddress_tmp        => pie_dev_addr_tmp, --
             usbreg_phy_test_mode         => usb_phy_test_mode,
             usbreg_port_force_fullspeed => usbreg_port_force_fullspeed,
	     token_length_counter         => zero7,
	     usb_token_length             => open,
             utmi_vcontrol                => utmi_vcontrol,
             utmi_vcontrolloadm           => utmi_vcontrolloadm,
             utmi_vstatus                 => utmi_vstatus,
             utmi_rxdata                  => utmi_rxdata,
             utmi_rxvalid                 => utmi_rxvalid,
             utmi_rxactive                => utmi_rxactive,
             utmi_rxerror                 => utmi_rxerror,
             utmi_txdata                  => utmi_txdata,
             utmi_txvalid                 => utmi_txvalid,
             utmi_txready                 => utmi_txready,
             utmi_reset                   => open,
             utmi_xcvrselect              => utmi_xcvrselect,
             utmi_termselect              => utmi_termselect,
             utmi_opmode                  => utmi_opmode,
             utmi_linestate               => utmi_linestate,
             utmi_vbusvalid               => USB_VBus,

             ulpi_rxdata                  => ulpi_rxdata,
             ulpi_txdata                  => ulpi_txdata,
             ulpi_txenable                => ulpi_txenable,
             ulpi_dir                     => ulpi_dir,
             ulpi_stp                     => ulpi_stp,
             ulpi_nxt                     => ulpi_nxt,
             ulpi_pwrctrl_wakeup          => ulpi_pwrctrl_wakeup,

             VBusDebounced                => VBusDebounced,

             pie_dev_selected             => pie_dev_selected, --|
             usb_pie_fpga                 => usb_pie_fpga
             );


usb_synchronizer_1: usb_synchronizer
  generic map (C_UTMI_SUPPORT   => C_UTMI_SUPPORT,
               C_ULPI_SUPPORT   => C_ULPI_SUPPORT,
               USB_DATAWIDTH    => USBPIE_DATAWIDTH,
               TXNBYTES_BITS    => 15,
               RXNBYTES_BITS    => 12,
               C_NBDEV          => C_NBDEV+2)
  port map    (
              usbreg_pll_on                => usbreg_pll_on,
              sync_usbreg_pll_on           => sync_usbreg_pll_on,
              usbreg_lpm_sup               => usbreg_lpm_sup,
              sync_usbreg_lpm_sup          => sync_usbreg_lpm_sup,
              usbreg_lpm_hird_sw           => usbreg_lpm_hird_sw,
              sync_usbreg_lpm_hird_sw      => sync_usbreg_lpm_hird_sw,
              usbreg_lpm_nyet              => usbreg_lpm_nyet,
              sync_usbreg_lpm_nyet         => sync_usbreg_lpm_nyet,
              pie_speed                    => pie_speed,
              sync_pie_speed               => sync_pie_speed,
              sieint_lpm_hird_hw           => sieint_lpm_hird_hw,
              sync_sieint_lpm_hird_hw      => sync_sieint_lpm_hird_hw,
              sync_usbreg_frame_number     => sync_usbreg_frame_number,
              usbreg_frame_number          => usbreg_frame_number,
              pie_dev_selected             => pie_dev_selected,
              sync_pie_dev_selected        => sync_pie_dev_selected,


              sieint_epinfo_req            => sieint_epinfo_req,
              sieint_epinfo_epnr           => sieint_epinfo_epnr,
              sieint_epinfo_epdir          => sieint_epinfo_epdir,
              sieint_epinfo_setup          => sieint_epinfo_setup,
              sieint_epinfo_setup_received => sieint_epinfo_setup_received,
              epinfo_valid                 => epinfo_valid,
              epinfo_active                => epinfo_active,
              epinfo_disabled              => epinfo_disabled,
              epinfo_toggle                => epinfo_toggle,
              epinfo_stall                 => epinfo_stall,
              epinfo_iso                   => epinfo_iso,
              epinfo_ratefeedbackmode      => open,
              epinfo_nbytes                => epinfo_nbytes,
              epinfo_maxpacket             => epinfo_maxpacket,
              sieint_txdatafetched         => sieint_txdatafetched,
              epinfo_txdata                => epinfo_txdata,
              epinfo_txdata_valid          => epinfo_txdata_valid,
              sieint_rx_nbytes             => sieint_rx_nbytes,
              sieint_rxdata                => sieint_rxdata,
              sieint_rxdatavalid           => sieint_rxdatavalid,
              sieint_endtransfer           => sieint_endtransfer,
              sieint_success               => sieint_success,
              sieint_error                 => sieint_error,
              sieint_errortype             => sieint_errortype,
              sieint_sentNAK               => sieint_sentNAK,
              VBusDebounced                => VBusDebounced,
              pie_lowpower_n               => pie_lowpower_n,
              vbuscomp_on                  => vbuscomp_on_int,
              chrg_vbus                    => chrg_vbus,
              dischrg_vbus                 => dischrg_vbus,
              avalid                       => avalid,
              sessend                      => sessend,
              TM_IsoToggle                 => TM_IsoToggle,
              RG_BUSReset                  => RG_BUSReset,
              TM_Suspend                   => TM_Suspend,
              LPM_TM_Suspend               => LPM_TM_Suspend,
              LPM_RW                       => LPM_RW,
              phy_addr                     => phy_addr,
              phy_wdata                    => phy_wdata,
              phy_rdata                    => phy_rdata,
              phy_write                    => phy_write,
              phy_start                    => phy_start,
              phy_mode                     => phy_mode,
              phy_endtoggle                => phy_endtoggle,
              sync_usbreg_phy_test_mode_change  => sync_usbreg_phy_test_mode_change,
              sync_usbreg_dev_connect      => sync_usbreg_dev_connect ,
              sync_usbreg_remotewakeup     => sync_usbreg_remotewakeup ,
              sync_usbreg_lpmremotewakeup  => sync_usbreg_lpmremotewakeup ,
              sync_sieint_epinfo_req       => sync_sieint_epinfo_req,
              sync_sieint_epinfo_epnr      => sync_sieint_epinfo_epnr,
              sync_sieint_epinfo_epdir     => sync_sieint_epinfo_epdir,
              sync_sieint_epinfo_setup     => sync_sieint_epinfo_setup,
              sync_sieint_setup_received   => sync_sieint_setup_received,
              sync_VBusDebounced           => sync_VBusDebounced,
              usbreg_vbuscomp_on           => usbreg_vbuscomp_on,
              usbreg_chrg_vbus             => usbreg_chrg_vbus,
              usbreg_dischrg_vbus          => usbreg_dischrg_vbus,
              sync_avalid                  => sync_avalid,
              sync_sessend                 => sync_sessend,
              epinfo_sync_valid            => epinfo_sync_valid,
              epinfo_sync_active           => epinfo_sync_active,
              epinfo_sync_disabled         => epinfo_sync_disabled,
              epinfo_sync_toggle           => epinfo_sync_toggle,
              epinfo_sync_stall            => epinfo_sync_stall,
              epinfo_sync_iso              => epinfo_sync_iso,
              epinfo_sync_ratefeedbackmode => epinfo_sync_ratefeedbackmode,
              epinfo_sync_nbytes           => epinfo_sync_nbytes,
              epinfo_sync_maxpacket        => epinfo_sync_maxpacket,
              sync_sieint_txdatafetched    => sync_sieint_txdatafetched,
              epinfo_sync_txdata           => epinfo_sync_txdata,
              epinfo_sync_txdata_valid     => epinfo_sync_txdata_valid,
              sync_sieint_rx_nbytes        => sync_sieint_rx_nbytes,
              sync_sieint_rxdata           => sync_sieint_rxdata,
              sync_sieint_rxdatavalid      => sync_sieint_rxdatavalid,
              sync_sieint_endtransfer      => sync_sieint_endtransfer,
              sync_sieint_success          => sync_sieint_success,
              sync_sieint_error            => sync_sieint_error,
              sync_sieint_errortype        => sync_sieint_errortype,
              sync_sieint_sentNAK          => sync_sieint_sentNAK,
              sync_set_frameint            => sync_set_frameint,
              sync_busreset                => sync_busreset,
              sync_suspend                 => sync_suspend,
              sync_lpm_suspend             => sync_lpm_suspend,
              sync_lpm_rw                  => sync_lpm_rw,
              usbreg_phy_addr              => usbreg_phy_addr,
              usbreg_phy_wdata             => usbreg_phy_wdata,
              sync_phy_rdata               => sync_phy_rdata,
              usbreg_phy_write             => usbreg_phy_write,
              usbreg_phy_start             => usbreg_phy_start,
              usbreg_phy_mode              => usbreg_phy_mode,
              sync_phy_endtoggle           => sync_phy_endtoggle,
              usbreg_phy_test_mode         => usb_phy_test_mode,
              usbreg_dev_connect           => usb_dev_connect,
              usbreg_remotewakeup          => usbreg_remotewakeup,
              usbreg_lpmremotewakeup       => usbreg_lpmremotewakeup,
              FsClk                        => pie_clk,
              reset_n                      => reset_n,
              hclk                         => hclk,
              hrstn                        => hresetn
              );

usb_reg_if_1 : usb_reg_if
  generic map (C_UTMI_SUPPORT            => C_UTMI_SUPPORT,
               C_ULPI_SUPPORT            => C_ULPI_SUPPORT,
               C_NBPHYSEP                => C_NBPHYSEP_ARM,
               C_EPUB                    => C_EPUB,
               C_DAUB                    => C_DAUB,
               C_DALB                    => C_DALB,
               C_EPFIFO_PAGE             => C_EPFIFO_PAGE,
               C_DATAFIFO_PAGE           => C_DATAFIFO_PAGE,
               C_SINGLE_BUFFER_SUPPORTED => C_SINGLE_BUFFER_SUPPORTED,
               C_DOUBLE_BUFFER_SUPPORTED => C_DOUBLE_BUFFER_SUPPORTED,
               C_TOGGLE_REG_READABLE     => C_TOGGLE_REG_READABLE,
               C_PLL_ENABLE              => C_PLL_ENABLE,
               C_PLL_DIVIDER             => C_PLL_DIVIDER,
               C_MINOR_REV               => C_MINOR_REV,
               C_MAJOR_REV               => C_MAJOR_REV)
  port map    (
              -- synthesis read_comments_as_HDL on
              --phy_interface           => phy_interface,
              --fpga_pll_on             => fpga_pll_on,
              -- synthesis read_comments_as_HDL off
              hclk                       => hclk,
              hresetn                    => hresetn,
              USB_Int_Req_Irq         => dev0_usb_irq,
              USB_Int_Req_Fiq         => dev0_usb_fiq,
              reg_waddr                  => reg_waddr,
              reg_wdata                  => reg_wdata,
              reg_raddr                  => reg_raddr,
              reg_rdata                  => reg_rdata,
              reg_write                  => reg_write,
              sieint_usbaddress          => sieint_usbaddress,
              usbreg_usbaddress          => usbreg_usbaddress,
              usbreg_usbaddress_tmp      => usbreg_usbaddress_tmp,
              usbreg_deviceenabled       => usbreg_arm_deviceenabled,--<<<< LAB to check  synchro issue @usbreg_deviceenabled level 
              usbreg_setup               => usbreg_setup,
              sieint_setup_received      => dev0_setup_received,
              usbreg_pll_on              => usbreg_pll_on,
              usbreg_lpm_sup             => usbreg_lpm_sup,
              usbreg_remotewakeup        => usbreg_remotewakeup,
              usbreg_lpmremotewakeup     => usbreg_lpmremotewakeup,
              usbreg_dev_connect         => usbreg_dev_connect,
              usbreg_frame_number        => sync_usbreg_frame_number,
              usbreg_ep_list_start       => usbreg_ep_list_start,
              usbreg_data_buffer_start   => usbreg_data_buffer_start,
              usbreg_lpm_hird_sw         => usbreg_lpm_hird_sw,
              sieint_lpm_hird_hw         => sync_sieint_lpm_hird_hw,
              usbreg_lpm_nyet            => usbreg_lpm_nyet,
              usbreg_ep_skip             => usbreg_ep_skip,
              usbreg_ep_bufinuse         => usbreg_ep_bufinuse,
              usbreg_select_ext_clk      => open,
              usbreg_epinfo_toggle       => usbreg_epinfo_toggle,
              dma_clear_toggle           => dev0_dma_clear_toggle,
              dma_set_toggle             => dev0_dma_set_toggle,
              dma_sent_NAK               => dev0_dma_sent_nak,
              dma_set_int                => dev0_dma_set_int,
              dma_physepnr               => dma_physepnr,
              dma_clear_skip             => dev0_dma_clear_skip,
              dma_skip_ep                => dma_skip_ep,
              sync_busreset              => upd_arm_dev_portreset,
              sync_suspend               => sync_suspend,
              sync_lpm_suspend           => sync_lpm_suspend,
              sync_lpm_rw                => sync_lpm_rw,
              sync_sieint_error          => sync_sieint_error,
              sync_sieint_errortype      => sync_sieint_errortype,
              sync_set_frameint          => sync_set_frameint,
              usbreg_phy_test_mode       => usbreg_phy_test_mode,
               usbreg_port_force_fullspeed => usbreg_port_force_fullspeed,
              pie_speed                  => sync_pie_speed,
              sync_VBusDebounced         => sync_VBusDebounced,
              usbreg_vbuscomp_on         => usbreg_vbuscomp_on,
              usbreg_chrg_vbus           => usbreg_chrg_vbus,
              usbreg_dischrg_vbus        => usbreg_dischrg_vbus,
              sync_avalid                => sync_avalid,
              sync_sessend               => sync_sessend,
              usbreg_phy_addr            => usbreg_phy_addr,
              usbreg_phy_wdata           => usbreg_phy_wdata,
              sync_phy_rdata             => sync_phy_rdata,
              usbreg_phy_write           => usbreg_phy_write,
              usbreg_phy_start           => usbreg_phy_start,
              usbreg_phy_mode            => usbreg_phy_mode,
              sync_phy_endtoggle         => sync_phy_endtoggle,
              usb_reg_if_fpga            => usb_reg_if_fpga
             );

usb_ahb_slave_1 : usb_ahb_slave
  port map   (
                 hclk                 => hclk,
                 hresetn              => ahbs_resetn,
                 haddr                => dev0_ahbs_haddr,
                 hwrite               => dev0_ahbs_hwrite,
                 hsel                 => dev0_ahbs_hsel,
                 htrans1              => dev0_ahbs_htrans(1),
                 hwdata               => dev0_ahbs_hwdata,
                 hrdata               => dev0_ahbs_hrdata,
                 hresp                => dev0_ahbs_hresp,
                 hready               => dev0_ahbs_hreadyout,
                 hready_glb           => dev0_ahbs_hreadyin,
                 reg_waddr            => reg_waddr,
                 reg_wdata            => reg_wdata,
                 reg_raddr            => reg_raddr,
                 reg_rdata            => reg_rdata,
                 reg_write            => reg_write
             );



usb_reg_if_2 : usb_reg_if
  generic map (
    C_UTMI_SUPPORT            => C_UTMI_SUPPORT,
    C_ULPI_SUPPORT            => C_ULPI_SUPPORT,
    C_NBPHYSEP                => C_NBPHYSEP_ARM,
    C_EPUB                    => C_EPUB,
    C_DAUB                    => C_DAUB,
    C_DALB                    => C_DALB,
    C_EPFIFO_PAGE             => C_EPFIFO_PAGE,
    C_DATAFIFO_PAGE           => C_DATAFIFO_PAGE,
    C_SINGLE_BUFFER_SUPPORTED => C_SINGLE_BUFFER_SUPPORTED,
    C_DOUBLE_BUFFER_SUPPORTED => C_DOUBLE_BUFFER_SUPPORTED,
    C_TOGGLE_REG_READABLE     => C_TOGGLE_REG_READABLE,
    C_PLL_ENABLE              => C_PLL_ENABLE,
    C_PLL_DIVIDER             => C_PLL_DIVIDER,
    C_MINOR_REV               => C_MINOR_REV,
    C_MAJOR_REV               => C_MAJOR_REV
  )
  port map (
    hclk                       => hclk,
    hresetn                    => hresetn,
    USB_Int_Req_Irq            => dev1_usb_irq,
    USB_Int_Req_Fiq            => dev1_usb_fiq,
    reg_waddr                  => dev1_reg_waddr,
    reg_wdata                  => dev1_reg_wdata,
    reg_raddr                  => dev1_reg_raddr,
    reg_rdata                  => dev1_reg_rdata,
    reg_write                  => dev1_reg_write,
    sieint_usbaddress          => sieint_usbaddress,
    usbreg_usbaddress          => dev1_usbreg_usbaddress,
    usbreg_usbaddress_tmp      => dev1_usbreg_usbaddress_tmp,
    usbreg_deviceenabled       => dev1_usbreg_deviceenabled,
    usbreg_setup               => dev1_usbreg_setup,
    sieint_setup_received      => dev1_setup_received,
    usbreg_pll_on              => open,
    usbreg_lpm_sup             => open,
    usbreg_remotewakeup        => open,
    usbreg_lpmremotewakeup     => open,
    usbreg_dev_connect         => dev1_usbreg_dev_connect,
    usbreg_frame_number        => sync_usbreg_frame_number,
    usbreg_ep_list_start       => dev1_usbreg_ep_list_start,
    usbreg_data_buffer_start   => dev1_usbreg_data_buffer_start,
    usbreg_lpm_hird_sw         => open,
    sieint_lpm_hird_hw         => sync_sieint_lpm_hird_hw,
    usbreg_lpm_nyet            => open,
    usbreg_ep_skip             => dev1_usbreg_ep_skip,
    usbreg_ep_bufinuse         => dev1_usbreg_ep_bufinuse,
    usbreg_select_ext_clk      => open,
    usbreg_epinfo_toggle       => dev1_usbreg_epinfo_toggle,
    dma_clear_toggle           => dev1_dma_clear_toggle,
    dma_set_toggle             => dev1_dma_set_toggle,
    dma_sent_NAK               => dev1_dma_sent_nak,
    dma_set_int                => dev1_dma_set_int,
    dma_physepnr               => dma_physepnr,
    dma_clear_skip             => dev1_dma_clear_skip,
    dma_skip_ep                => dma_skip_ep,
    sync_busreset              => upd_dev1_portreset,
    sync_suspend               => sync_suspend,
    sync_lpm_suspend           => sync_lpm_suspend,
    sync_lpm_rw                => sync_lpm_rw,
    sync_sieint_error          => sync_sieint_error,
    sync_sieint_errortype      => sync_sieint_errortype,
    sync_set_frameint          => sync_set_frameint,
    usbreg_phy_test_mode       => open,
    usbreg_port_force_fullspeed => open,
    pie_speed                  => sync_pie_speed,
    sync_VBusDebounced         => sync_VBusDebounced,
    usbreg_vbuscomp_on         => open,
    usbreg_chrg_vbus           => open,
    usbreg_dischrg_vbus        => open,
    sync_avalid                => sync_avalid,
    sync_sessend               => sync_sessend,
    usbreg_phy_addr            => open,
    usbreg_phy_wdata           => open,
    sync_phy_rdata             => sync_phy_rdata,
    usbreg_phy_write           => open,
    usbreg_phy_start           => open,
    usbreg_phy_mode            => open,
    sync_phy_endtoggle         => sync_phy_endtoggle,
    usb_reg_if_fpga            => open
  );

usb_ahb_slave_2 : usb_ahb_slave
  port map (
    hclk       => hclk,
    hresetn    => ahbs_resetn,
    haddr      => dev1_ahbs_haddr,
    hwrite     => dev1_ahbs_hwrite,
    hsel       => dev1_ahbs_hsel,
    htrans1    => dev1_ahbs_htrans(1),
    hwdata     => dev1_ahbs_hwdata,
    hrdata     => dev1_ahbs_hrdata,
    hresp      => dev1_ahbs_hresp,
    hready     => dev1_ahbs_hreadyout,
    hready_glb => dev1_ahbs_hreadyin,
    reg_waddr  => dev1_reg_waddr,
    reg_wdata  => dev1_reg_wdata,
    reg_raddr  => dev1_reg_raddr,
    reg_rdata  => dev1_reg_rdata,
    reg_write  => dev1_reg_write
  );

hub_usb_ahb_slave_1 : usb_ahb_slave
  port map (
    hclk       => hclk,
    hresetn    => ahbs_resetn,
    haddr      => hub_ahbs_haddr,
    hwrite     => hub_ahbs_hwrite,
    hsel       => hub_ahbs_hsel,
    htrans1    => hub_ahbs_htrans(1),
    hwdata     => hub_ahbs_hwdata,
    hrdata     => hub_ahbs_hrdata,
    hresp      => hub_ahbs_hresp,
    hready     => hub_ahbs_hreadyout,
    hready_glb => hub_ahbs_hreadyin,
    reg_waddr  => hub_reg_waddr,
    reg_wdata  => hub_reg_wdata,
    reg_raddr  => hub_reg_raddr,
    reg_rdata  => hub_reg_rdata,
    reg_write  => hub_reg_write
  );

usb_dma_1 : usb_dma
  generic map (USB_DATAWIDTH        => USBPIE_DATAWIDTH,
               RAM_DATAWIDTH        => RAM_DATAWIDTH,
               C_NBPHYSEP           => C_NBPHYSEP_ARM,
               C_DALB               => C_DALB)
  port map (
      hclk                          => hclk,
      hresetn                       => hresetn,
      dma_addr                      => dma_dma_addr,
      dma_req                       => dma_dma_req,
      dma_gnt                       => dma_dma_gnt,
      dma_write                     => dma_dma_write,
      dma_wdata                     => dma_dma_wdata,
      dma_rdata                     => dma_dma_rdata,
      dma_word_enable               => usbram_word_enable_int,
      sync_sieint_epinfo_req        => sync_sieint_epinfo_req,
      sync_sieint_epinfo_epnr       => sync_sieint_epinfo_epnr,
      sync_sieint_epinfo_epdir      => sync_sieint_epinfo_epdir,
      sync_sieint_epinfo_setup      => sync_sieint_epinfo_setup,
      epinfo_sync_valid             => epinfo_sync_valid,
      epinfo_sync_active            => epinfo_sync_active,
      epinfo_sync_disabled          => epinfo_sync_disabled,
      epinfo_sync_toggle            => epinfo_sync_toggle,
      epinfo_sync_stall             => epinfo_sync_stall,
      epinfo_sync_iso               => epinfo_sync_iso,
      epinfo_sync_ratefeedbackmode  => epinfo_sync_ratefeedbackmode,
      epinfo_sync_nbytes            => epinfo_sync_nbytes,
      epinfo_sync_maxpacket         => epinfo_sync_maxpacket,
      sync_sieint_txdatafetched     => sync_sieint_txdatafetched,
      epinfo_sync_txdata            => epinfo_sync_txdata,
      epinfo_sync_txdata_valid      => epinfo_sync_txdata_valid,
      sync_sieint_rx_nbytes         => sync_sieint_rx_nbytes,
      sync_sieint_rxdata            => sync_sieint_rxdata,
      sync_sieint_rxdatavalid       => sync_sieint_rxdatavalid,
      sync_sieint_endtransfer       => sync_sieint_endtransfer,
      sync_sieint_success           => sync_sieint_success,
      sync_sieint_sentNAK           => sync_sieint_sentNAK,
      sync_busreset                 => sync_busreset,
      dma_ahb_selected              => open,          --dma_ahb_selected is handled in the top level
      usbreg_setup                  => usbreg_setup_to_dma,
      pie_speed                     => sync_pie_speed,
      usbreg_ep_list_start          => dma_ep_list_start,
      usbreg_ep_skip_list_start     => dma_ep_list_start,
      usbreg_data_buffer_start      => dma_data_buffer_start,
      usbreg_ep_bufinuse            => dma_ep_bufinuse_selected,
      usbreg_ep_skip                => dma_ep_skip_selected,
      usbreg_epinfo_toggle          => dma_epinfo_toggle,
      dma_clear_toggle              => dma_clear_toggle,
      dma_set_toggle                => dma_set_toggle,
      dma_sent_NAK                  => dma_sent_NAK,
      dma_set_int                   => dma_set_int,
      dma_physepnr                  => dma_physepnr,
      dma_clear_skip                => dma_clear_skip,
      dma_skip_ep                   => dma_skip_ep,
      usb_dma_fpga                  => usb_dma_fpga
     );

  --------------------------------------------
  -- Mux for signals towards usb_dma
  -- this is based on which device is selected
  --------------------------------------------
  dma_ep_list_start <=
    usbreg_ep_list_start(31 downto 8)
      when sync_pie_dev_selected = C_NBDEV
    else dev1_usbreg_ep_list_start(31 downto 8)
      when sync_pie_dev_selected = C_NBDEV + 1
    else "00000000000000011" &
      std_logic_vector(to_unsigned(sync_pie_dev_selected, 7));

  dma_data_buffer_start <=
    usbreg_data_buffer_start(31 downto C_DALB)
      when sync_pie_dev_selected = C_NBDEV
    else dev1_usbreg_data_buffer_start(31 downto C_DALB)
      when sync_pie_dev_selected = C_NBDEV + 1
    else (others => '0');

  dma_ep_skip_selected <=
    usbreg_ep_skip
      when sync_pie_dev_selected = C_NBDEV
    else dev1_usbreg_ep_skip
      when sync_pie_dev_selected = C_NBDEV + 1
    else (others => '0');

  dma_ep_bufinuse_selected <=
    usbreg_ep_bufinuse
      when sync_pie_dev_selected = C_NBDEV
    else dev1_usbreg_ep_bufinuse
      when sync_pie_dev_selected = C_NBDEV + 1
    else (others => '0');

  dma_ahb_selected <= '1'
    when sync_pie_dev_selected >= C_NBDEV
    else '0';

  dev0_setup_received <= sync_sieint_setup_received
    when sync_pie_dev_selected = C_NBDEV
    else '0';

  dev1_setup_received <= sync_sieint_setup_received
    when sync_pie_dev_selected = C_NBDEV + 1
    else '0';

  arm_dev_setup_received <= dev0_setup_received;

  usbreg_setup_to_dma_bus(C_NBDEV-1 downto 0)
    <= usbreg_setup_to_decode;
  usbreg_setup_to_dma_bus(C_NBDEV)
    <= usbreg_setup;
  usbreg_setup_to_dma_bus(C_NBDEV+1)
    <= dev1_usbreg_setup;

  usbreg_setup_to_dma <=
    usbreg_setup_to_dma_bus(sync_pie_dev_selected);

  dma_epinfo_toggle <=
    usbreg_epinfo_toggle
      when sync_pie_dev_selected = C_NBDEV
    else dev1_usbreg_epinfo_toggle
      when sync_pie_dev_selected = C_NBDEV + 1
    else emb_epinfo_toggle;

--<<<<< LAB review this 
  proc_emb_toggle_mux : process(sync_pie_dev_selected,
                                emb_ep_toggle,
                                emb_ep0_toggle)
  variable var_start_bit : integer range 0 to C_NBPHYSEP;
  begin
    emb_epinfo_toggle    <= (others => '0');
    if sync_pie_dev_selected < C_NBDEV then
      emb_epinfo_toggle(0) <= emb_ep0_toggle(sync_pie_dev_selected*2);
      emb_epinfo_toggle(1) <= emb_ep0_toggle(sync_pie_dev_selected*2+1);
      var_start_bit := 0;
      for i in 0 to C_NBDEV-1 loop
        if i = sync_pie_dev_selected then
          if DEV_ARRAY(i).NBPHYSEP > 0 then
            for j in 0 to DEV_ARRAY(i).NBPHYSEP-1 loop
              if DEV_ARRAY(i).EP(j).EPDIR = '0' then
                emb_epinfo_toggle(DEV_ARRAY(i).EP(j).EPNB*2)
                  <= emb_ep_toggle(var_start_bit + j);
              else
                emb_epinfo_toggle(DEV_ARRAY(i).EP(j).EPNB*2+1)
                  <= emb_ep_toggle(var_start_bit + j);
              end if;
            end loop;
          end if;
        else
          var_start_bit := var_start_bit + DEV_ARRAY(i).NBPHYSEP;
        end if;
      end loop;
    end if;
  end process proc_emb_toggle_mux;

  proc_emb_toggle_ff : process(hclk,hresetn)
  variable var_ep_position  : integer range 0 to C_NBPHYSEP;
  variable var_epnr         : integer range 0 to 31;
  variable var_dma_physepnr : integer range 0 to 31;
  begin
    if hresetn = '0' then
      emb_ep0_toggle <= (others => '0');
      emb_ep_toggle  <= (others => '0');
    elsif hclk'event and hclk = '1' then
      if sync_busreset = '1' then
        emb_ep0_toggle <= (others => '0');
      elsif sync_pie_dev_selected < C_NBDEV then
        if sync_sieint_setup_received = '1' then
          emb_ep0_toggle(sync_pie_dev_selected*2)   <= '1';
          emb_ep0_toggle(sync_pie_dev_selected*2+1) <= '1';
        elsif dma_set_toggle = '1' and dma_physepnr < 2 then
          emb_ep0_toggle(sync_pie_dev_selected*2 +
                   dma_physepnr           ) <= '1';
        elsif dma_clear_toggle = '1' and dma_physepnr < 2  then
          emb_ep0_toggle(sync_pie_dev_selected*2 +
                   dma_physepnr           ) <= '0';
        end if;
      end if;
      if sync_busreset = '1' then
        emb_ep_toggle <= (others => '0');
      elsif sync_pie_dev_selected < C_NBDEV and
            dma_physepnr   >= 2           then
        var_ep_position := 0;
        for i in 0 to C_NBDEV-1 loop
          if i < sync_pie_dev_selected then
            var_ep_position := var_ep_position + DEV_ARRAY(i).NBPHYSEP;
          elsif i = sync_pie_dev_selected then
             for j in 0 to DEV_ARRAY(i).NBPHYSEP loop
               if DEV_ARRAY(i).EP(j).EPDIR = '0' then
                 var_epnr := DEV_ARRAY(i).EP(j).EPNB*2;
               else
                 var_epnr := DEV_ARRAY(i).EP(j).EPNB*2+1;
               end if;
               var_dma_physepnr := dma_physepnr;
               if var_dma_physepnr = var_epnr then
                 if dma_set_toggle = '1' then
                   emb_ep_toggle(var_ep_position+j) <= '1';
                 elsif dma_clear_toggle = '1' then
                   emb_ep_toggle(var_ep_position+j) <= '0';
                 end if;
               end if;
             end loop;
          end if;
        end loop;
      end if;
    end if;
  end process proc_emb_toggle_ff;

  dev0_dma_clear_toggle <= dma_clear_toggle
    when sync_pie_dev_selected = C_NBDEV
    else '0';

  dev0_dma_set_toggle <= dma_set_toggle
    when sync_pie_dev_selected = C_NBDEV
    else '0';

  dev0_dma_sent_nak <= dma_sent_NAK
    when sync_pie_dev_selected = C_NBDEV
    else '0';

  dev0_dma_set_int <= dma_set_int
    when sync_pie_dev_selected = C_NBDEV
    else '0';

  dev0_dma_clear_skip <= dma_clear_skip
    when sync_pie_dev_selected = C_NBDEV
    else '0';

  dev1_dma_clear_toggle <= dma_clear_toggle
    when sync_pie_dev_selected = C_NBDEV + 1
    else '0';

  dev1_dma_set_toggle <= dma_set_toggle
    when sync_pie_dev_selected = C_NBDEV + 1
    else '0';

  dev1_dma_sent_nak <= dma_sent_NAK
    when sync_pie_dev_selected = C_NBDEV + 1
    else '0';

  dev1_dma_set_int <= dma_set_int
    when sync_pie_dev_selected = C_NBDEV + 1
    else '0';

  dev1_dma_clear_skip <= dma_clear_skip
    when sync_pie_dev_selected = C_NBDEV + 1
    else '0';

  usbreg_dma_sent_NAK <= dev0_dma_sent_nak;
  usbreg_dma_set_int  <= dev0_dma_set_int;


ahb_dma_slave_1 : ahb_dma_slave
  generic map(AHB_DATAWIDTH  => AHB_DATAWIDTH,
              RAM_DATAWIDTH  => RAM_DATAWIDTH,
              RAM_ADDR_WIDTH => RAM_ADDRWIDTH
              )
  port map  (ahb_dma_slave_fpga     => ahb_dma_slave_fpga,
            ads_hclk                => hclk,
            ads_hresetn             => ahbs_resetn,
            ads_dma_addr            => ahb_dma_addr_masked,
            ads_dma_req             => dev0_dma_req,
            ads_dma_gnt             => dev0_dma_gnt,
            ads_dma_write           => ahb_dma_write,
            ads_dma_wdata           => ahb_dma_wdata,
            ads_dma_rdata           => dev0_dma_rdata,
            ads_dma_dword_en        => usb_dma_dword_selection_int,
            ads_mem_q               => dev0_mem_q,
            ads_mem_d               => mem_d_int,
            ads_mem_cs              => mem_cs_int,
            ads_mem_a               => mem_a_int,
            ads_mem_web_out         => mem_web_out_int,
            ads_mem_bsel            => mem_bsel_int,
            ads_hsel                => dev0_ahbs_dma_hsel,
            ads_haddr               => dev0_ahbs_dma_haddr,
            ads_hwrite              => dev0_ahbs_dma_hwrite,
            ads_htrans              => dev0_ahbs_dma_htrans,
            ads_hsize               => dev0_ahbs_dma_hsize,
            ads_hburst              => dev0_ahbs_dma_hburst,
            ads_hwdata              => dev0_ahbs_dma_hwdata,
            ads_hrdata              => ahbs_dma_hrdata_int,
            ads_hresp               => ahbs_dma_hresp_int,
            ads_hready_out          => ahbs_dma_hreadyout_int,
            ads_hready_in           => dev0_ahbs_dma_hreadyin
            );

ahb_dma_slave_2 : ahb_dma_slave
  generic map (
    AHB_DATAWIDTH  => AHB_DATAWIDTH,
    RAM_DATAWIDTH  => RAM_DATAWIDTH,
    RAM_ADDR_WIDTH => RAM_ADDRWIDTH
  )
  port map (
    ahb_dma_slave_fpga => open,
    ads_hclk            => hclk,
    ads_hresetn         => ahbs_resetn,
    ads_dma_addr        => ahb_dma_addr_masked,
    ads_dma_req         => dev1_dma_req,
    ads_dma_gnt         => dev1_dma_gnt,
    ads_dma_write       => ahb_dma_write,
    ads_dma_wdata       => ahb_dma_wdata,
    ads_dma_rdata       => dev1_dma_rdata,
    ads_dma_dword_en    => usb_dma_dword_selection_int,
    ads_mem_q           => dev1_mem_q,
    ads_mem_d           => dev1_mem_d,
    ads_mem_cs          => dev1_mem_cs,
    ads_mem_a           => dev1_mem_a,
    ads_mem_web_out     => dev1_mem_web_out,
    ads_mem_bsel        => dev1_mem_bsel,
    ads_hsel            => dev1_ahbs_dma_hsel,
    ads_haddr           => dev1_ahbs_dma_haddr,
    ads_hwrite          => dev1_ahbs_dma_hwrite,
    ads_htrans          => dev1_ahbs_dma_htrans,
    ads_hsize           => dev1_ahbs_dma_hsize,
    ads_hburst          => dev1_ahbs_dma_hburst,
    ads_hwdata          => dev1_ahbs_dma_hwdata,
    ads_hrdata          => dev1_ahbs_dma_hrdata,
    ads_hresp           => dev1_ahbs_dma_hresp,
    ads_hready_out      => dev1_ahbs_dma_hreadyout,
    ads_hready_in       => dev1_ahbs_dma_hreadyin
  );

hub_desc_dma_addr(31 downto 14) <= (others => '0');
hub_desc_dma_addr(13 downto 2)  <= ep0_mem_addr;
hub_desc_dma_addr(1 downto 0)   <= "00";
hub_desc_dma_req                 <= ep0_mem_req;
hub_desc_dma_dword_en            <= (others => '1');

ep0_mem_gnt   <= hub_desc_dma_gnt;
ep0_mem_rdata <= hub_desc_dma_rdata;

hub_desc_ahb_dma_slave : ahb_dma_slave
  generic map (
    AHB_DATAWIDTH  => AHB_DATAWIDTH,
    RAM_DATAWIDTH  => RAM_DATAWIDTH,
    RAM_ADDR_WIDTH => RAM_ADDRWIDTH
  )
  port map (
    ahb_dma_slave_fpga => open,
    ads_hclk            => hclk,
    ads_hresetn         => ahbs_resetn,
    ads_dma_addr        => hub_desc_dma_addr,
    ads_dma_req         => hub_desc_dma_req,
    ads_dma_gnt         => hub_desc_dma_gnt,
    ads_dma_write       => '0',
    ads_dma_wdata       => (others => '0'),
    ads_dma_rdata       => hub_desc_dma_rdata,
    ads_dma_dword_en    => hub_desc_dma_dword_en,
    ads_mem_q           => hub_desc_mem_q,
    ads_mem_d           => hub_desc_mem_d,
    ads_mem_cs          => hub_desc_mem_cs,
    ads_mem_a           => hub_desc_mem_a,
    ads_mem_web_out     => hub_desc_mem_web_out,
    ads_mem_bsel        => hub_desc_mem_bsel,
    ads_hsel            => hub_desc_ahbs_dma_hsel,
    ads_haddr           => hub_desc_ahbs_dma_haddr,
    ads_hwrite          => hub_desc_ahbs_dma_hwrite,
    ads_htrans          => hub_desc_ahbs_dma_htrans,
    ads_hsize           => hub_desc_ahbs_dma_hsize,
    ads_hburst          => hub_desc_ahbs_dma_hburst,
    ads_hwdata          => hub_desc_ahbs_dma_hwdata,
    ads_hrdata          => hub_desc_ahbs_dma_hrdata,
    ads_hresp           => hub_desc_ahbs_dma_hresp,
    ads_hready_out      => hub_desc_ahbs_dma_hreadyout,
    ads_hready_in       => hub_desc_ahbs_dma_hreadyin
  );

  dev0_dma_req <= ahb_dma_req
    when sync_pie_dev_selected = C_NBDEV
    else '0';

  dev1_dma_req <= ahb_dma_req
    when sync_pie_dev_selected = C_NBDEV + 1
    else '0';

  ahb_dma_gnt <= dev0_dma_gnt
    when sync_pie_dev_selected = C_NBDEV
    else dev1_dma_gnt
    when sync_pie_dev_selected = C_NBDEV + 1
    else '0';

  ahb_dma_rdata <= dev0_dma_rdata
    when sync_pie_dev_selected = C_NBDEV
    else dev1_dma_rdata
    when sync_pie_dev_selected = C_NBDEV + 1
    else (others => '0');

  -- The ahb memory map should allow full addressing of the RAM (256KB if RAM_ADDRWITH = 15 and RAM_DATAWIDTH = 64). 
  ahb_dma_addr_masked(AHB_ADDR_INDEX-1 downto 0) <= ahb_dma_addr(AHB_ADDR_INDEX-1 downto 0);
  ahb_dma_addr_masked(31 downto AHB_ADDR_INDEX)  <= (others => '0');

  usb_dma_dword_selection_int <=
    usbram_word_enable_int when dma_dma_req = '1'
    else (others => '1');

  gen_dma_dword_sel_ram32 : if RAM_DATAWIDTH = 32 generate
    usb_dma_dword_selection <=
      '0' & usb_dma_dword_selection_int(0);
  end generate;

  gen_dma_dword_sel_ram64 : if RAM_DATAWIDTH = 64 generate
    usb_dma_dword_selection <=
      usb_dma_dword_selection_int;
  end generate;
  usb_dma_write_access <= '1' when (dma_dma_req = '1' and (dma_dma_write = '1')) else '0';

  dev0_mem_d <= mem_d_int;
  dev0_mem_cs <= mem_cs_int;
  dev0_mem_a <= mem_a_int;
  dev0_mem_web_out <= mem_web_out_int;
  dev0_mem_bsel <= mem_bsel_int;
  dev0_ahbs_dma_hrdata <= ahbs_dma_hrdata_int;
  dev0_ahbs_dma_hresp <= ahbs_dma_hresp_int;
  dev0_ahbs_dma_hreadyout <= ahbs_dma_hreadyout_int;

  -- begin of insertion
  
usb_fs_mux_1 : usb_fs_mux
  generic map(C_DATAWIDTH    => RAM_DATAWIDTH)
  port map (
           dma_dma_addr      => dma_dma_addr,
           dma_dma_req       => dma_dma_req,
           dma_dma_gnt       => dma_dma_gnt,
           dma_dma_write     => dma_dma_write,
           dma_dma_wdata     => dma_dma_wdata,
           dma_dma_rdata     => dma_dma_rdata,
           ahb_dma_addr      => ahb_dma_addr,
           ahb_dma_req       => ahb_dma_req,
           ahb_dma_gnt       => ahb_dma_gnt,
           ahb_dma_write     => ahb_dma_write,
           ahb_dma_wdata     => ahb_dma_wdata,
           ahb_dma_rdata     => ahb_dma_rdata,
           upd_dma_addr      => upd_dma_addr,
           upd_dma_req       => upd_dma_req,
           upd_dma_gnt       => upd_dma_gnt,
           upd_dma_write     => upd_dma_write,
           upd_dma_wdata     => upd_dma_wdata,
           upd_dma_rdata     => upd_dma_rdata,
           dma_ahb_selected  => dma_ahb_selected
           );

usb_ep0_handler_1 : usb_ep0_handler
  generic map(C_NBPHYSEP => C_NBPHYSEP,
              C_NBDEV    => C_NBDEV,
              C_DATAWIDTH => RAM_DATAWIDTH,
              C_EPNBYTEWIDTH => C_EPNBYTEWIDTH)
  port map (
      clk                     => hclk,
      rst_n                   => hresetn,
      upd_dma_addr            => upd_dma_addr(14 downto 0),
      upd_dma_req             => upd_dma_req_ep0,
      upd_dma_gnt             => upd_dma_gnt_ep0,
      upd_dma_write           => upd_dma_write,
      upd_dma_wdata           => upd_dma_wdata,
      upd_dma_rdata           => upd_dma_rdata_ep0,
      usbreg_setup_to_decode  => usbreg_setup_to_decode,
      ep0_remote_wake_enabled => open,
      ep_set_stall            => ep_set_stall,
      ep_clear_stall          => ep_clear_stall,
      ep0_setupdone           => ep0_setupdone,
      ep0_new_address         => ep0_new_address,
      ep0_address             => ep0_address,
      ep0_device_config       => ep0_device_config,
      ep0_out_active          => ep0_out_active,
      ep0_in_active           => ep0_in_active,
      ep0_outin_nbytes        => ep0_outin_nbytes,
      ep0_setup_dir           => ep0_setup_dir,
      ep0_data_buffer         => ep0_data_buffer,
      ep0_request             => ep0_request,
      ep0_wvalue              => ep0_wvalue,
      ep0_windex              => ep0_windex,
      ep0_class_rdata         => ep0_class_rdata,
      ep0_class_addr          => open,
      ep0_mem_req             => ep0_mem_req,
      ep0_mem_gnt             => ep0_mem_gnt,
      ep0_mem_addr            => ep0_mem_addr,
      ep0_mem_rdata           => ep0_mem_rdata,
      sync_busreset           => sync_busreset,
      usbreg_dev_connect      => hub_connect,
      usb_self_powered        => usb_self_powered,
      usb_phy_test_mode       => ep0_phy_test_mode,
      epconfig_stall          => epconfig_stall
     );

usb_ep_config_handler_1 : usb_ep_config_handler
  generic map(C_NBPHYSEP  => C_NBPHYSEP,
              C_NBDEV     => C_NBDEV,
              C_EPADDRWIDTH  => 11,
              C_EPNBYTEWIDTH => C_EPNBYTEWIDTH, 
              C_DATAWIDTH => RAM_DATAWIDTH,
              HIGH_SPEED_SUPPORT => TRUE)
  port map   (
      clk                     => hclk,
      rst_n                   => hresetn,
      upd_dma_addr            => upd_dma_addr(14 downto 0),
      upd_dma_req             => upd_dma_req_config,
      upd_dma_gnt             => upd_dma_gnt_config,
      upd_dma_write           => upd_dma_write,
      upd_dma_wdata           => upd_dma_wdata,
      upd_dma_rdata           => upd_dma_rdata_config,
      ep0_setupdone           => ep0_setupdone,
      ep0_out_active          => ep0_out_active,
      ep0_in_active           => ep0_in_active,
      ep0_outin_nbytes        => ep0_outin_nbytes,
      ep0_setup_dir           => ep0_setup_dir,
      ep0_data_buffer         => ep0_data_buffer,
      ep_clk                  => ep_clk,
      ep_rst_n                => ep_rst_n,
      ep_stall                => ep_stall,
      ep_clear_buffer         => ep_clear_buffer,
      ep_enable_buffer        => ep_enable_buffer,
      ep_buffer_size          => ep_buffer_size,
      buf_nbytes              => buf_nbytes,
      buf_reset_addr_ptr      => buf_reset_addr_ptr,
      ep_bufinuse             => open,
      ep_set_stall            => ep_set_stall,
      ep_clear_stall          => ep_clear_stall,
      epconfig_stall          => epconfig_stall,
      ep0_device_config       => ep0_device_config
     );

  -- dma mux 
  upd_dma_req_ep0      <= upd_dma_req when upd_dma_addr(16 downto 15) = "00" else '0';
  upd_dma_req_config   <= upd_dma_req when upd_dma_addr(16 downto 15) = "11" else '0';
  upd_dma_req_ep_hub   <= upd_dma_req when upd_dma_addr(16 downto 15) = "01" else '0';
  
  upd_dma_gnt        <= upd_dma_gnt_config     when upd_dma_addr(16 downto 15) = "11" else
                        '0'                   when upd_dma_addr(16 downto 15) = "10" else
                        upd_dma_gnt_ep_noram   when upd_dma_addr(16 downto 15) = "01" else
                        upd_dma_gnt_ep0;
  
  upd_dma_rdata      <= upd_dma_rdata_config   when upd_dma_addr(16 downto 15) = "11" else
                        (others => '0')         when upd_dma_addr(16 downto 15) = "10" else
                        upd_dma_rdata_ep_noram when upd_dma_addr(16 downto 15) = "01" else
                        upd_dma_rdata_ep0;
  
usb_app_hw_hub_1 : usb_app_hw_hub
  generic map(C_HUB_NB_PORTS => 2,
              C_DATAWIDTH    => RAM_DATAWIDTH)
  port map(
      sys_clk                => hclk,
      sys_rst_n              => hresetn,
      sync_busreset          => sync_busreset,
      pie_speed              => sync_pie_speed,
      hub_epin_req           => upd_dma_req_ep_hub,
      hub_epin_gnt           => upd_dma_gnt_ep_noram,
      hub_epin_addr          => upd_dma_addr(4 downto 2),
      hub_epin_rdata         => upd_dma_rdata_ep_noram,
      hub_epin_stall         => hub_epin_stall,
      hub_epin_clear_buffer  => hub_epin_clear_buffer,
      hub_epin_enable_buffer => hub_epin_enable_buffer,
      hub_epin_buffer_size   => hub_epin_buffer_size,
      ep0_setupdone          => ep0_setupdone(0),
      ep0_request            => ep0_request,
      ep0_wvalue             => ep0_wvalue,
      ep0_windex             => ep0_windex,
      ep0_class_rdata        => ep0_class_rdata,
      hub_port_connect       => hub_port_connect,
      hub_port_enable        => hub_port_enable,
      hub_port_reset         => hub_port_reset
     );

  usb_dev_connect <= hub_connect when hub_enable_eff = '1'
                                  else usbreg_dev_connect;

  hub_connect <= sync_VBusDebounced
                   when usb_hubenable_ss = '1'
                   else hub_dcon_q and sync_VBusDebounced;
  hub_port_connect(0) <= usbreg_dev_connect;
  hub_port_connect(1) <= dev1_usbreg_dev_connect;
  
  arm_dev_portreset <= '1'
    when hub_port_reset(0) = '1' or sync_busreset = '1'
    else '0';

  dev1_portreset <= '1'
    when hub_port_reset(1) = '1' or sync_busreset = '1'
    else '0';
  
  PROC_SETUP_TO_DECODE : process(hclk,hresetn)
  begin
    if hresetn = '0' then
      usbreg_setup_to_decode <= (others => '0');
      reg_dev_addr           <= (others => '0');
      reg_dev_addr_tmp       <= (others => '0');
    elsif hclk = '1' and hclk'event then
      if sync_sieint_setup_received = '1' and sync_pie_dev_selected < C_NBDEV then
        usbreg_setup_to_decode(sync_pie_dev_selected) <= '1';
        for i in 0 to 6 loop
          reg_dev_addr(sync_pie_dev_selected*7+i)     <= sieint_usbaddress(i);
          reg_dev_addr_tmp(sync_pie_dev_selected*7+i) <= sieint_usbaddress(i);
        end loop;
      end if;
      for i in 0 to C_NBDEV-1 loop
        if ep0_setupdone(i) = '1' then
          usbreg_setup_to_decode(i)    <= '0';
          if ep0_new_address = '1' then
            for j in 0 to 6 loop
              reg_dev_addr_tmp(i*7+j) <= ep0_address(j);
            end loop;
          end if;
        end if;
        if sync_busreset = '1' then
          usbreg_setup_to_decode <= (others => '0');
          reg_dev_addr           <= (others => '0');
          reg_dev_addr_tmp       <= (others => '0');
        end if;
      end loop;
    end if;
  end process PROC_SETUP_TO_DECODE;
  
  pie_dev_addr(C_NBDEV*7-1 downto 0)
    <= reg_dev_addr;
  pie_dev_addr((C_NBDEV+1)*7-1 downto C_NBDEV*7)
    <= usbreg_usbaddress;
  pie_dev_addr((C_NBDEV+2)*7-1 downto (C_NBDEV+1)*7)
    <= dev1_usbreg_usbaddress;

  pie_dev_addr_tmp(C_NBDEV*7-1 downto 0)
    <= reg_dev_addr_tmp;
  pie_dev_addr_tmp((C_NBDEV+1)*7-1 downto C_NBDEV*7)
    <= usbreg_usbaddress_tmp;
  pie_dev_addr_tmp((C_NBDEV+2)*7-1 downto (C_NBDEV+1)*7)
    <= dev1_usbreg_usbaddress_tmp;
  
  --TODO : make assignments below automatic based on DEV_ARRAY table

  ep_clk(0)   <= hclk;
  ep_rst_n(0) <= hresetn;

  ep_enable_buffer(0)         <= hub_epin_enable_buffer;
  ep_clear_buffer(0)          <= hub_epin_clear_buffer;
  ep_buffer_size( 6 downto 0) <= hub_epin_buffer_size(6 downto 0);
  ep_stall(0)                 <= hub_epin_stall;
  
  
  usbreg_deviceenabled(0) <= hub_connect when hub_enable_eff = '1'
                                         else '0';

  usbreg_deviceenabled(1) <=
    hub_port_enable(0) and usbreg_arm_deviceenabled
      when hub_enable_eff = '1'
    else usbreg_arm_deviceenabled;

  usbreg_deviceenabled(2) <=
    hub_port_enable(1) and dev1_usbreg_deviceenabled
      when hub_enable_eff = '1'
    else dev1_usbreg_deviceenabled;
  
  upd_arm_dev_portreset <=
    arm_dev_portreset
      when hub_enable_eff = '1'
    else sync_busreset;

  upd_dev1_portreset <=
    dev1_portreset
      when hub_enable_eff = '1'
    else sync_busreset;

  PROC_SYNC_PIN : process(hclk,hresetn)
  begin
    if hresetn = '0' then
      usb_hubenable_s  <= '0';
      usb_hubenable_ss <= '0';
    elsif hclk = '1' and hclk'event then
      usb_hubenable_s  <= USB_EnableHub;
      usb_hubenable_ss <= usb_hubenable_s;
    end if;
  end process PROC_SYNC_PIN;

-- end of insertion

  --UTMI/ULPI clock selection
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

  reset_n <= sync_ss_reset_n or async_disable;

  hreset_awake_n <= (hresetn and not awake) or async_disable;
  reset_awake_n <= (sync_ss_reset_n and not awake) or async_disable;
  utmiclk_reset_n  <= (sys_utmi_clkin_lock and (clock_on or to_std_logic(clk_off_counter /= 0))) or async_disable;

-- DOC_BEGIN: Vbus Debouncing
-- This circuit masks small low spikes on Vbus. This allows
-- to share the Vbus pin with an other input pin, provided
-- that it goes low only for a short time during normal
-- operation.

-- GMA: BYPASS fix PR#55

  vbus_debounc_proc : process (pie_clk,reset_n)
  begin
    if reset_n = '0' then
       VBusDebounced             <= '0';
       DebounceTimer             <=  0;
       pie_isotoggle_r           <= '0';
       pie_vbusvalid_r           <= '0';
    elsif pie_clk'event and pie_clk = '1' then
       if vbuscomp_on_int = '1' then
          pie_vbusvalid_r <= pie_vbusvalid;
       else
          pie_vbusvalid_r <= '0';
       end if;   
       pie_isotoggle_r           <= pie_isotoggle;
       if pie_vbusvalid_r = '1' or (DebounceTimer > 0) then
          VBusDebounced <= '1';
       else
          VBusDebounced <= '0';
       end if;
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
      atx_reset_core <= '0';
      clk_counter_atx_core <= RESET_CYCLE;
    elsif hclk'event and hclk = '1' then
      if (clk_counter_atx_core > 0) then
         clk_counter_atx_core <= clk_counter_atx_core -1;
         atx_reset_core <= '1';
      else
         atx_reset_core <= '0';
      end if;
   end if;
  end process utmi_reset_detect_proc;

   reset_needed <= atx_reset_core;

  -- UTMI only:
  atx_reset_core_proc : process (pie_clk, reset_n)
  begin
     if reset_n = '0' then
      reset_needed_z  <= '1';
      reset_needed_zz <= '1';
      clk_off_counter <= 0;
    elsif pie_clk'event and pie_clk = '1' then
      if phy_mode = '0' then -- UTMI only
        if clock_on = '1' or  pwrctrl_wakeup_int = '1' then
          clk_off_counter <= CLOCKOFF_CYCLE;
        elsif clk_off_counter > 0 then
          clk_off_counter <= clk_off_counter -1;
        end if;
        reset_needed_z  <= reset_needed;
        reset_needed_zz <= reset_needed_z;
      end if;
    end if;
  end process atx_reset_core_proc;

  pie_clk_ok_proc : process(utmiclk_reset_n, pie_clk)
  begin
    if ( utmiclk_reset_n = '0') then
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

  -- ULPI only DATA LOW POWER ENABLE
  -- Once the PHY is placed in Low Power Mode( Via a TX Command sent by the 3511_hs), Linestate and active high interrupt indication
  -- are driven asynchronously via ULPI data bus. Actually, linestate can still toggle as long as the USB clock (pie_clock) is running (minimum 5 clock cycles after ulpi_dir is asserted).
  -- Since, its is phy dependant, it is safer to use a counter (running on USB clock) sampled with another counter running on AHB clock.
  -- If 2 consecutive samples of AHB counter are different, it means USB clock is still running and  clock counter AHB is re-initialised
  -- If there are equal, AHB counter counts down. Asynchronous datalines can be interpreted if clock_counter_ahb = 0 (data_line_low_power_en = '1')
  -- USB need clock (that allows to switch off AHB clock) can only be de-asserted when data_line_low_power_en = '1'
   dataline_low_power_en <= '1' when clock_counter_ahb = 0 else '0';

  dataline_low_power_pie_clk_proc : process(pie_clk, reset_awake_n)
  begin
    if (reset_awake_n = '0') then
      clock_counter_usb <= 0 ;
    elsif  (pie_clk'event and pie_clk='1') then
      if clock_counter_usb = 0 then
        clock_counter_usb <= CLOCK_COUNTER_USB_MAX;
      else
        clock_counter_usb <= clock_counter_usb - 1;
      end if;
    end if;
  end process dataline_low_power_pie_clk_proc;

  dataline_low_power_ahb_clk_proc: process (hclk, hreset_awake_n)
  begin
    if (hreset_awake_n = '0') then
      clock_counter_ahb <= CLOCK_COUNTER_AHB_MAX;
      clock_counter_usb_msb    <= '0';
      clock_counter_usb_msb_z  <= '0';
      clock_counter_usb_msb_zz <= '0';
    elsif hclk'event and hclk = '1' then
      clock_counter_usb_msb    <= to_unsigned(clock_counter_usb,4)(3);
      clock_counter_usb_msb_z  <= clock_counter_usb_msb;
      clock_counter_usb_msb_zz <= clock_counter_usb_msb_z;
      if clock_counter_ahb > 0 then
        if (clock_counter_usb_msb_z = clock_counter_usb_msb_zz ) then
          clock_counter_ahb <= clock_counter_ahb -1;
        else
          clock_counter_ahb <= CLOCK_COUNTER_AHB_MAX;
        end if;
      end if;
     end if;
  end process dataline_low_power_ahb_clk_proc;

  -- UTMI or ULPI:
  WAKEUP_DETECTION : process (pie_clk, reset_n)
  begin
    if reset_n = '0' then
      dp_s        <= '0';
      dm_s        <= '0';
      ulpi_dir_s  <= '0';
      ulpi_dir_ss <= '0';
      ulpi_dir_sss <= '0';
    elsif pie_clk'event and pie_clk ='1' then
      dp_s        <= dp;
      dm_s        <= dm;
      ulpi_dir_s <= ulpi_dir;
      ulpi_dir_ss <= ulpi_dir_s;
      ulpi_dir_sss <= ulpi_dir_ss;
    end if;
  end process WAKEUP_DETECTION;


  usb_needclk_int      <= '0' when sys_donotwakeup_n = '0' else
                          '1' when  ((clock_on = '1' or clk_off_counter /= 0 or dataline_low_power_en = '0' or pwrctrl_wakeup_int = '1') and phy_mode = '0') else
                          '1' when  ((clock_on = '1'or dataline_low_power_en = '0' or pwrctrl_wakeup_int = '1') and phy_mode = '1') else
                          '0';

  usb_needclk <= usb_needclk_int;


  -- LAB : this has been rewritten because the process commented below did not pass spyglass compliance test
  -- reset_n is gated with async_disable, the set condition is also gated with async_disable.
  -- What is not clear is why pwrctrl_wakeup_int needs to be connected to async_disable 
  -- This has to be checked during DFT especially ATPG simulation (see ticket Customer Ticket 111086 : incorrect async_disabling in usb_fs_ip_3528_susp_ctrl) . 
  --

  set_pwrctrl_wakeup <= ((clock_on and to_std_logic(clk_off_counter = 0) and dataline_low_power_en and not(phy_mode)) or
                          (clock_on and dataline_low_power_en and ulpi_dir_sss and phy_mode))
                          and not async_disable;
  
  --ULPI OR UTMI
  WAKEUP_STAGE : Process (reset_n,set_pwrctrl_wakeup,pie_clk)
  -- wake up is set asynchronously, can be reset asynchronously and synchronously if suspend_set is cleared
  begin
    if reset_n = '0' then
       pwrctrl_wakeup_int <= '0';
    elsif (set_pwrctrl_wakeup = '1') then
       pwrctrl_wakeup_int <= '1'; -- asynch wake up is only allowed when a wake up event occurs once usb clock is OFF
    elsif pie_clk'event and pie_clk ='1' then
    -- wake up must be hold asserted until clock is running again and lowpower is de-asserted
      if async_disable = '1' then 
        pwrctrl_wakeup_int <= async_disable;
      else
        pwrctrl_wakeup_int <= pwrctrl_wakeup_int and not awake;
      end if;
    end if;
  end process  WAKEUP_STAGE;
  
  
  -- this process does not pass spyglass compliancy  

---  --ULPI OR UTMI
---  WAKEUP_STAGE : Process (reset_n,async_disable,clock_on,clk_off_counter,phy_mode,dataline_low_power_en,ulpi_dir_sss,pie_clk,awake)
---  -- wake up is set asynchronously, can be reset asynchronously and synchronously if suspend_set is cleared
---  begin
---  --altera translate_off
---     if async_disable = '0' then
---  --altera translate_on
---        if reset_n = '0' then
---           pwrctrl_wakeup_int <= '0';
---        elsif (clock_on = '1'  and clk_off_counter = 0 and dataline_low_power_en = '1' and phy_mode = '0') or
---            (clock_on = '1' and dataline_low_power_en = '1' and ulpi_dir_sss = '1' and phy_mode = '1') then
---           pwrctrl_wakeup_int <= '1'; -- asynch wake up is only allowed when a wake up event occurs once usb clock is OFF
---        elsif pie_clk'event and pie_clk ='1' then
---        -- wake up must be hold asserted until clock is running again and lowpower is de-asserted
---           --if phy_mode = '1' then
---              pwrctrl_wakeup_int <= pwrctrl_wakeup_int and not awake;
---           --elsif (pwrctrl_wakeup_int = '1'and pie_lowpower_n = '0' and clk_off_counter = 0) then
---           --   pwrctrl_wakeup_int <= '1';
---           --else
---           --   pwrctrl_wakeup_int <= '0';
---           --end if;
---        end if;
---  --altera translate_off
---     else -- bypass asynchronous set/reset in test mode
---        if pie_clk'event and pie_clk ='1' then
---           pwrctrl_wakeup_int <= async_disable;
---        end if;
---     end if;
---  --altera translate_on
---
---  end process  WAKEUP_STAGE;

  -- Only relevant for ULPI:
  ulpi_pwrctrl_wakeup <= pwrctrl_wakeup_int when sys_donotwakeup_n = '1' else '0';


  -- Only relevant for UTMI:
  utmi_suspendm     <= '1' when ((clock_on = '1') or (clk_off_counter /= 0) or pwrctrl_wakeup_int = '1') and sys_donotwakeup_n = '1'
                           else '0';

  --ULPI OR UTMI
  clock_on <= '1' when (reset_needed_zz  = '1' and phy_mode = '0')   or
                       usbreg_pll_on = '1'                           or
                       ((VBusDebounced = '1' xor pie_vbusvalid = '1') and phy_mode = '0') or
                       (dp_s         /= dp and sync_usbreg_dev_connect = '1') or
                       (dm_s         /= dm and sync_usbreg_dev_connect = '1') or
                       pie_lowpower_n = '1'                              or
                       sys_dev_wakeup_n = '0'                            or
                       (ulpi_int_lp = '1' and phy_mode = '1')            or
                       usbreg_phy_start = '1'
                  else '0';


--fpga debug

  --  debug_fpga_3511(255 downto 192)<=  usb_reg_if_fpga (63 downto 0);

  -- synthesis read_comments_as_HDL on
  --
  --  debug_fpga_3511(63 downto 0)   <=  usb_pie_fpga(63 downto 0);
  --  debug_fpga_3511(127 downto 64) <=  usb_dma_fpga(63 downto 0);
  --  debug_fpga_3511(160)           <=  dma_ahb_selected;
  --  debug_fpga_3511(191 downto 161)<=  (others => '0');
  --  debug_fpga_3511(255 downto 192)<=  ahb_dma_slave_fpga(63 downto 0);
  --
  -- synthesis read_comments_as_HDL off

end structure;


--<<<<< LAB implement remote wake up : ep0_remote_wake_enabled(device); 
