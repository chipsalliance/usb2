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
--               File: ip_xxx_3515_hs_structure.a.vhdl
--
--             Author: Bart Vertenten
--
--       Organisation: Central R&D / Design Services / MSS - Connectivity
--
--              $Date: Wed May 29 12:25:34 2019 $
--
--            Project: Low gate count USB host IP
--
--        Description:
--
--          $Revision: 1.11 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: ip_xxx_3515_hs_structure.a.vhdl.rca $
--   
--    Revision: 1.11 Wed May 29 12:25:34 2019 usb00219
--    Added chicken bit for CDC crossing fix made for artf663122. Updates from Soong.
--    
--
--    Revision: 1.23 Thu Dec 13 11:43:04 2012 beq03196
--    add USB_OTG register for the ip_3516_hs
--
--    Revision: 1.22 Fri May 11 07:47:26 2012 beq03067
--    reg_woo
--
--    Revision: 1.21 Thu May 10 15:33:58 2012 beq03067
--    added overcurrent from sync to host pie, removed 3 unused outputs from host reg if
--
--    Revision: 1.20 Tue May  8 08:32:14 2012 beq03067
--    fpga debug not for rc
--
--    Revision: 1.19 Thu Mar 29 16:15:29 2012 beq03196
--    FIX CR#9: Add a check on vbus valid (Bvalid) in the host_pie + Filtering option on vbus
--
--    Revision: 1.18 Tue Mar 13 13:46:01 2012 beq03099
--    fix for PR#10 - full-speed interrupt must be sent immediate after SOF
--
--    Revision: 1.17 Mon Mar 12 09:50:46 2012 beq03196
--    width of test mode bus can be reduced to 3 bits
--
--    Revision: 1.16 Fri Mar  9 12:39:05 2012 beq03067
--    host_regif_fpga not commented out anymore
--
--    Revision: 1.15 Fri Mar  9 11:50:48 2012 beq03099
--    added pie_devicespeed to synchronizer
--
--    Revision: 1.14 Fri Mar  9 07:15:36 2012 beq03099
--    removed usbram_word_enable signal
--
--    Revision: 1.13 Thu Mar  8 16:05:30 2012 beq03099
--    added usbreg_reset and light_reset to DMA interface
--
--    Revision: 1.12 Wed Mar  7 10:26:05 2012 beq03067
--    Added testmode
--
--    Revision: 1.11 Tue Mar  6 18:16:21 2012 beq03099
--    fixed usb_rst_n behaviour
--
--    Revision: 1.10 Tue Mar  6 11:58:54 2012 beq03067
--    added power output
--
--    Revision: 1.9 Tue Mar  6 11:30:41 2012 beq03067
--    added 3 new io on host_reg_if
--
--    Revision: 1.8 Tue Mar  6 10:52:06 2012 beq03099
--    added usbreg_reset_sync and usbreg_light_reset_sync to entity of usb_host_sof_timer
--
--    Revision: 1.7 Thu Feb 23 12:13:50 2012 beq03196
--    add ulpi_pwrctrl_wakeup input pin for the host_pie
--
--    Revision: 1.6 Fri Feb 17 13:18:10 2012 beq03099
--    fixed configuration
--
--    Revision: 1.5 Fri Feb 17 12:33:32 2012 beq03099
--    added/removed interface signals
--
--    Revision: 1.4 Fri Feb 17 11:43:19 2012 beq03196
--    adapted after host_pie revision
--
--    Revision: 1.3 Thu Feb 16 14:49:28 2012 beq03099
--    added signals on synchronizer and host_pie
--
--    Revision: 1.2 Fri Feb  3 14:07:39 2012 beq03099
--    fixed frindex toggle for FS
--
--    Revision: 1.1 Wed Feb  1 15:40:07 2012 beq03099
--    initial version
--
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY rtl;
USE rtl.usb_general_subcmp_pkg.all;

architecture structure of ip_xxx_3515_hs is

--++++++++++++++++++++++++++++++++++++++++++++++
-- Constants that are specific for this toplevel
constant C_MINOR_REV      : std_logic_vector(7 downto 0) := X"00";
constant C_MAJOR_REV      : std_logic_vector(7 downto 0) := X"01";
 constant COMPOUND_SUPPORT     : boolean := FALSE;
constant USBPIE_DATAWIDTH : integer := 64;
constant USBRAM_DATAWIDTH : integer := 64; -- This IP only works with USBRAM_DATAWIDTH set to 64
constant RESET_CYCLE      : integer := 63;
constant AHB_SLAVE_ADDR_WIDTH : integer := 5;
--++++++++++++++++++++++++++++++++++++++++++++++

component usb_host_pie
generic(
        ULPI_SUPPORT  : boolean := FALSE;
        UTMI_SUPPORT  : boolean := TRUE;
        USB_DATAWIDTH : integer := 64
        --FILT_VBUS     : boolean := TRUE
	);
port (
      reset_n                       : in std_logic; -- AHB reset after resynchronization, active LOW
      pie_clk                       : in std_logic; -- UTMI/ULPI clock
      dbc_vbus_en                   : in std_logic;
      epinfo_starttransfer_sync     : in  std_logic;
      epinfo_token_sync             : in  std_logic_vector(2 downto 0);
      epinfo_devaddr_sync           : in  std_logic_vector(6 downto 0);
      epinfo_epnr_sync              : in  std_logic_vector(3 downto 0);
      epinfo_toggle_sync            : in  std_logic;
      epinfo_eptype_sync            : in  std_logic_vector(1 downto 0);
      epinfo_mult_sync              : in  std_logic_vector(1 downto 0);
      epinfo_maxpacket_sync         : in  std_logic_vector(10 downto 0);
      epinfo_nbytes_sync            : in  std_logic_vector(11 downto 0);
      epinfo_lowspeed_sync          : in  std_logic;
      epinfo_sofnr_sync             : in  std_logic_vector(10 downto 0);
      epinfo_subpid_sync            : in  std_logic_vector(1 downto 0);
      epinfo_lpm_linkstate_sync     : in  std_logic_vector(3 downto 0);
      epinfo_lpm_hird_sync          : in  std_logic_vector(3 downto 0);
      epinfo_lpm_bremotewakeup_sync : in  std_logic;
      epinfo_split_hubaddr_sync     : in  std_logic_vector(6 downto 0);
      epinfo_split_port_sync        : in  std_logic_vector(6 downto 0);
      epinfo_split_se_sync          : in  std_logic_vector(1 downto 0);
      pie_txdatafetched             : out std_logic;
      epinfo_txdata_sync            : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
      epinfo_txdata_valid_sync      : in  std_logic;
      pie_rx_nbytes                 : out std_logic_vector(11 downto 0);
      pie_rxdata                    : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
      pie_rxdatavalid               : out std_logic;
      pie_endtransfer               : out std_logic;
      pie_response                  : out std_logic_vector(2 downto 0);
      usbreg_phy_addr_sync          : in  std_logic_vector(7 downto 0);
      pie_phy_rdata                 : out std_logic_vector(7 downto 0);
      usbreg_phy_wdata_sync         : in  std_logic_vector(7 downto 0);
      usbreg_phy_write_sync         : in  std_logic;
      usbreg_phy_start_sync         : in  std_logic;
      pie_phy_endtoggle             : out std_logic;
      usbreg_phy_mode_sync          : in  std_logic;
      usbreg_reset_sync             : in  std_logic;
      usbreg_light_reset_sync       : in  std_logic;
      usbreg_portpower_sync         : in std_logic;
      usbreg_portreset_sync         : in std_logic;
      usbreg_portsuspend_sync       : in  std_logic;
      usbreg_portl1l2suspend_sync   : in  std_logic;
      usbreg_portresume_sync        : in  std_logic;
      usbreg_portenable_clear_sync  : in  std_logic;
      usbreg_port_force_fullspeed   : in  std_logic;
      pie_resume_detected           : out std_logic;
      pie_resume_done               : out std_logic;
      pie_portconnect               : out std_logic;
      pie_portenable                : out std_logic;
      pie_linestate                 : out std_logic_vector(1 downto 0);
      usbreg_pll_on                 : in  std_logic;
      usbreg_phy_test_mode_change_sync : in std_logic;
      usbreg_phy_test_mode          : in  std_logic_vector(2 downto 0);
      pie_devicespeed               : out std_logic_vector(1 downto 0);
      usb_send_sof                  : in  std_logic;
      usb_endofframe                : in  std_logic;
      usb_overcurrent_sync          : in std_logic;
      utmi_vbusvalid                : in  std_logic;
      utmi_rxdata                   : in  std_logic_vector(7 downto 0);
      utmi_rxvalid                  : in  std_logic;
      utmi_rxactive                 : in  std_logic;
      utmi_rxerror                  : in  std_logic;
      utmi_txdata                   : out std_logic_vector(7 downto 0);
      utmi_txvalid                  : out std_logic;
      utmi_txready                  : in  std_logic;
      utmi_reset                    : out std_logic;
      pie_lowpower_n                : out std_logic;
      utmi_xcvrselect               : out std_logic_vector(1 downto 0);
      utmi_termselect               : out std_logic;
      utmi_opmode                   : out std_logic_vector(1 downto 0);
      utmi_linestate                : in  std_logic_vector(1 downto 0);
      utmi_hostdisconnect           : in  std_logic;
      utmi_vcontrol                 : out std_logic_vector(3 downto 0);
      utmi_vcontrolloadm            : out std_logic;
      utmi_vstatus                  : in  std_logic_vector(7 downto 0);
      ulpi_pwrctrl_wakeup           : in  std_logic;
      ulpi_rxdata                   : in   std_logic_vector(7 downto 0);
      ulpi_txdata                   : out  std_logic_vector(7 downto 0);
      ulpi_txenable                 : out  std_logic;
      ulpi_dir                      : in   std_logic;
      ulpi_stp                      : out  std_logic;
      ulpi_nxt                      : in   std_logic;
      usb_host_pie_fpga             : out std_logic_vector(63 downto 0);
      INTER_PACKET_DELAY_LS_param   : in  std_logic_vector(7 downto 0);
      INTER_PACKET_DELAY_FS_param   : in  std_logic_vector(7 downto 0);
      INTER_PACKET_DELAY_HS_param   : in  std_logic_vector(7 downto 0);
      PACKET_TURNAROUND_TIMEOUT_LS_param : in  std_logic_vector(10 downto 0);
      PACKET_TURNAROUND_TIMEOUT_FS_param : in  std_logic_vector(7 downto 0);
      PACKET_TURNAROUND_TIMEOUT_HS_param : in  std_logic_vector(7 downto 0);
      PACKET_EVENT_TIMEOUT_LS_param : in  std_logic_vector(12 downto 0);
      PACKET_EVENT_TIMEOUT_FS_param : in  std_logic_vector(8 downto 0);
      PACKET_EVENT_TIMEOUT_HS_param : in  std_logic_vector(8 downto 0);
      usb_host_pie_portl1l2suspend_use_sync_n : in  std_logic
      );
end component;

component usb_host_synchronizer
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
      usbreg_portl1l2suspend_sync  : out std_logic;
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
end component;

component usb_host_reg_if
generic(
        AHB_SLAVE_ADDR_WIDTH : integer := 5;
        C_ULPI_SUPPORT      : boolean := TRUE; --FALSE
        C_UTMI_SUPPORT      : boolean := TRUE;
        C_MINOR_REV         : std_logic_vector(7 downto 0) := X"00";
        C_MAJOR_REV         : std_logic_vector(7 downto 0) := X"01"; --00
        C_PORTPOWER_CONTROL : boolean := TRUE;
        C_PORTINDICATOR     : boolean := TRUE --FALSE
	);
port (
      ------------------
      -- FPGA related --
      ------------------
      usb_host_reg_if_fpga : out std_logic_vector(63 downto 0);
      ----------------------
      -- To/From external --
      ----------------------
      hclk              : in  std_logic;
      hresetn           : in  std_logic;
      usb_int_req_irq   : out std_logic;
      usb_portindicator : out std_logic_vector(1 downto 0); -- PIC register field
      usbreg_id_en      : out std_logic;
      usbreg_dev_en     : out std_logic;
      usbreg_sw_ctrl_pdcom  : out std_logic;
      usbreg_sw_pdcom       : out std_logic;
      ---------------------------------
      --To/From usb_ahb_slave module --
      ---------------------------------
      reg_waddr : in  std_logic_vector(6 downto 2);
      reg_wdata : in  std_logic_vector(31 downto 0);
      reg_raddr : in  std_logic_vector(6 downto 2);
      reg_rdata : out std_logic_vector(31 downto 0);
      reg_write : in  std_logic;
      --------------------------------
      --To/From usb_host_pie module --
      --------------------------------
      usbreg_pll_on        : out std_logic; -- usb_pll register bit
      usbreg_phy_test_mode : out std_logic_vector(2 downto 0); -- PTC register field
      --PSPD field 00b : Low-speed, 01b : Full-speed, 10b : High-speed, 11b : Reserved
      pie_devicespeed_sync : in std_logic_vector(1 downto 0);
      usbreg_lpm_hird          : out std_logic_vector(3 downto 0);
      usbreg_lpm_bremotewakeup : out std_logic;
      usbreg_lpm_addr          : out std_logic_vector(6 downto 0);
      usbreg_susp_l1_on        : out std_logic;
      dma_lpm_success          : in  std_logic;
      dma_lpm_done             : in  std_logic;
      dma_lpm_stat             : in  std_logic_vector(1 downto 0);
      usbreg_port_force_fullspeed   : out std_logic;
      --------------------------------
      --To/From usb_host_synchronizer module
      --------------------------------
      usbreg_fladj                : out std_logic_vector(5 downto 0); -- FLADJ register field
      -- This signal toggles every time if the FLADJ register field is written
      usbreg_fladj_change         : out std_logic;
      usbreg_run                  : out std_logic; -- Run/stop register bit
      usbreg_reset                : out std_logic; -- hcreset register bit
      usbreg_light_reset          : out std_logic; -- lhcr register bit
      sync_reset_done             : in  std_logic;
      -- Every time when this signal changes value, the FRINDEX field is incremented by one.
      usb_inc_frindex_toggle_sync : in  std_logic;
      pie_portconnect_sync        : in  std_logic; -- CCS register bit
      pie_portenable_sync         : in  std_logic; -- PED register bit when read by SW
      usb_overcurrent_sync        : in  std_logic; -- OCA register bit
      usbreg_portresume           : out std_logic; -- FPR register bit
      pie_resume_detected_sync    : in  std_logic; -- If this signal is one, the FPR bit is set to one
      pie_resume_done_sync        : in  std_logic; -- Clear Force Port Resume bit when there is a pulse on this bit
      usbreg_portreset            : out std_logic; -- PR register bit
      usbreg_portsuspend          : out std_logic; -- L2 suspend only
      usbreg_portl1l2suspend      : out std_logic; -- SUSP register bit
      pie_linestate_sync          : in  std_logic_vector(1 downto 0); -- LS register field
      usbreg_portpower            : out std_logic; -- PP register bit
      usbreg_portenable_clear     : out std_logic; -- If SW writes a zero to the PED bit, this signal is toggled
      usbreg_phy_addr             : out std_logic_vector(7 downto 0);
      usbreg_phy_wdata            : out std_logic_vector(7 downto 0);
      phy_rdata_sync              : in  std_logic_vector(7 downto 0);
      usbreg_phy_write            : out std_logic;
      usbreg_phy_start            : out std_logic;
      usbreg_phy_mode             : out std_logic;
      phy_endtoggle_sync          : in  std_logic;
      id_value_sync               : in  std_logic;

      ---------------------------------
      -- To/From usb_host_dma module --
      ---------------------------------
      usbreg_atl_base      : out std_logic_vector(22 downto 0);
      usbreg_atl_cur_ptd   : out std_logic_vector(4 downto 0);
      usbreg_iso_base      : out std_logic_vector(21 downto 0);
      usbreg_iso_first_ptd : out std_logic_vector(4 downto 0);
      usbreg_int_base      : out std_logic_vector(21 downto 0);
      usbreg_int_first_ptd : out std_logic_vector(4 downto 0);
      usbreg_payload_base  : out std_logic_vector(15 downto 0);
      usbreg_frindex       : out std_logic_vector(13 downto 0); -- frindex register field
      usbreg_atl_enable    : out std_logic; -- atl_en register bit
      usbreg_iso_enable    : out std_logic; -- iso_en register bit
      usbreg_int_enable    : out std_logic; -- irq_en register bit
      dma_atl_setint       : in  std_logic;
      dma_iso_setint       : in  std_logic;
      dma_int_setint       : in  std_logic;
      dma_atl_setdone      : in  std_logic;
      dma_iso_setdone      : in  std_logic;
      dma_int_setdone      : in  std_logic;
      dma_atl_setptd       : in  std_logic;
      dma_current_ptd      : in  std_logic_vector(4 downto 0);
      usbreg_atl_skip      : out std_logic_vector(31 downto 0); -- ATL_SKIP register field
      usbreg_iso_skip      : out std_logic_vector(31 downto 0); -- ISO_SKIP register field
      usbreg_int_skip      : out std_logic_vector(31 downto 0); -- INT_SKIP register field
      usbreg_atl_last      : out std_logic_vector(4 downto 0); -- ATL_LAST register field
      usbreg_iso_last      : out std_logic_vector(4 downto 0); -- ISO_LAST register field
      usbreg_int_last      : out std_logic_vector(4 downto 0); -- INT_LAST register field
      -------------------
      -- To toplevel module --
      -------------------
      usbreg_woo 	   : out std_logic

      );
end component;

component usb_host_sof_timer
port (
      --To/From external
      usb_rst_n                  : in  std_logic;
      usb_clk                    : in  std_logic;
      --To/From usb_host_synchronizer module
      usbreg_reset_sync          : in  std_logic;
      usbreg_light_reset_sync    : in  std_logic;
      usbreg_run_sync            : in  std_logic;
      usbreg_fladj_sync          : in  std_logic_vector(5 downto 0);
      usbreg_fladj_change_sync   : in  std_logic;
      usb_inc_frindex_toggle     : out std_logic;
      usb_decrement_bytes        : out std_logic;
      usb_uframe_count           : out std_logic_vector(2 downto 0);
      --To/From usb_host_pie module
      pie_devicespeed            : in  std_logic_vector(1 downto 0);
      usb_send_sof               : out std_logic;
      usb_endofframe             : out std_logic
     );
end component;

component usb_host_dma
generic(
        USB_DATAWIDTH   : integer := 8;
        RAM_DATAWIDTH   : integer := 32;
        RAM_ADDR_WIDTH  : integer := 15);
port (
      --To/From external
      hclk              : in  std_logic;
      hresetn           : in  std_logic;
      dma_addr          : out std_logic_vector(31 downto 0);
      dma_req           : out std_logic;
      dma_gnt           : in  std_logic;
      dma_write         : out std_logic;
      dma_wdata         : out std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      dma_rdata         : in  std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      --To/From usb_host_reg_if module
      usbreg_atl_base      : in  std_logic_vector(22 downto 0);
      usbreg_atl_cur_ptd   : in  std_logic_vector( 4 downto 0);
      usbreg_iso_base      : in  std_logic_vector(21 downto 0);
      usbreg_iso_first_ptd : in  std_logic_vector( 4 downto 0);
      usbreg_int_base      : in  std_logic_vector(21 downto 0);
      usbreg_int_first_ptd : in  std_logic_vector( 4 downto 0);
      usbreg_payload_base  : in  std_logic_vector(15 downto 0);
      usbreg_frindex       : in  std_logic_vector(13 downto 0);
      usbreg_run           : in  std_logic;
      usbreg_atl_enable    : in  std_logic;
      usbreg_iso_enable    : in  std_logic;
      usbreg_int_enable    : in  std_logic;
      dma_atl_setint       : out std_logic;
      dma_iso_setint       : out std_logic;
      dma_int_setint       : out std_logic;
      dma_atl_setdone      : out std_logic;
      dma_iso_setdone      : out std_logic;
      dma_int_setdone      : out std_logic;
      dma_atl_setptd       : out std_logic;
      dma_current_ptd      : out std_logic_vector(4 downto 0);
      usbreg_atl_skip      : in  std_logic_vector(31 downto 0);
      usbreg_iso_skip      : in  std_logic_vector(31 downto 0);
      usbreg_int_skip      : in  std_logic_vector(31 downto 0);
      usbreg_atl_last      : in  std_logic_vector(4 downto 0);
      usbreg_iso_last      : in  std_logic_vector(4 downto 0);
      usbreg_int_last      : in  std_logic_vector(4 downto 0);
      usbreg_reset         : in  std_logic;
      usbreg_light_reset   : in  std_logic;
      usbreg_susp_l1_on        : in  std_logic;
      usbreg_portsuspend       : in  std_logic;
      usbreg_lpm_addr          : in  std_logic_vector(6 downto 0);
      dma_lpm_success          : out std_logic;
      dma_lpm_done             : out std_logic;
      dma_lpm_stat             : out std_logic_vector(1 downto 0);
      --To/From usb_host_synchronizer module
      pie_txdatafetched_sync   : in  std_logic;
      pie_rx_nbytes_sync       : in  std_logic_vector(11 downto 0);
      pie_rxdata_sync          : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
      pie_rxdatavalid_sync     : in  std_logic;
      pie_endtransfer_sync     : in  std_logic;
      pie_response_sync        : in  std_logic_vector(2 downto 0);
      usb_decrement_bytes_sync : in  std_logic;
      epinfo_starttransfer     : out std_logic;
      epinfo_token             : out std_logic_vector(2 downto 0);
      epinfo_devaddr           : out std_logic_vector(6 downto 0);
      epinfo_epnr              : out std_logic_vector(3 downto 0);
      epinfo_toggle            : out std_logic;
      epinfo_eptype            : out std_logic_vector(1 downto 0);
      epinfo_mult              : out std_logic_vector(1 downto 0);
      epinfo_maxpacket         : out std_logic_vector(10 downto 0);
      epinfo_nbytes            : out std_logic_vector(11 downto 0);
      epinfo_lowspeed          : out std_logic;
      epinfo_sofnr             : out std_logic_vector(10 downto 0);
      epinfo_subpid            : out std_logic_vector(1 downto 0);
      epinfo_split_hubaddr     : out std_logic_vector(6 downto 0);
      epinfo_split_port        : out std_logic_vector(6 downto 0);
      epinfo_split_se          : out std_logic_vector(1 downto 0);
      epinfo_txdata            : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
      epinfo_txdata_valid      : out std_logic;
      usb_inc_frindex_toggle_sync: in  std_logic;
      pie_devicespeed_sync     : in std_logic_vector(1 downto 0);
      usb_dma_fpga             : out std_logic_vector(63 downto 0)
     );
  end component;

component usb_ahb_slave
  generic (
           AHB_SLAVE_ADDR_WIDTH : integer := 4
          );
  port    (
      hclk       : in  std_logic;
      hresetn    : in  std_logic;
      haddr      : in  std_logic_vector(AHB_SLAVE_ADDR_WIDTH+1 downto 2);
      hwrite     : in  std_logic;
      hsel       : in  std_logic;
      htrans1    : in  std_logic; -- bit 1 of the htrans signal
      hwdata     : in  std_logic_vector(31 downto 0);
      hrdata     : out std_logic_vector(31 downto 0);
      hresp      : out std_logic_vector(1 downto 0);
      hready     : out std_logic;
      hready_glb : in  std_logic;
      reg_waddr  : out std_logic_vector(AHB_SLAVE_ADDR_WIDTH-1 downto 0);
      reg_wdata  : out std_logic_vector(31 downto 0);
      reg_raddr  : out std_logic_vector(AHB_SLAVE_ADDR_WIDTH-1 downto 0);
      reg_rdata  : in  std_logic_vector(31 downto 0);
      reg_write  : out std_logic
          );
end component;

 signal clk_counter_atx_core          : integer range 0 to RESET_CYCLE;
 signal reg_waddr                     : std_logic_vector( AHB_SLAVE_ADDR_WIDTH-1 downto 0);
 signal reg_wdata                     : std_logic_vector(31 downto 0);
 signal reg_raddr                     : std_logic_vector( AHB_SLAVE_ADDR_WIDTH-1 downto 0);
 signal reg_rdata                     : std_logic_vector(31 downto 0);
 signal reg_write                     : std_logic;
 signal epinfo_toggle                 : std_logic;
 signal epinfo_nbytes                 : std_logic_vector(11 downto 0);
 signal epinfo_maxpacket              : std_logic_vector(10 downto 0);
 signal epinfo_txdata                 : std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
 signal epinfo_txdata_valid           : std_logic;
 signal usbreg_pll_on                 : std_logic;
 signal usbreg_phy_test_mode          : std_logic_vector(2 downto 0);
 signal usbreg_phy_test_mode_change_sync : std_logic;
 signal usbreg_phy_addr               : std_logic_vector(7 downto 0);
 signal usbreg_phy_wdata              : std_logic_vector(7 downto 0);
 signal usbreg_phy_write              : std_logic;
 signal usbreg_phy_start              : std_logic;
 signal usbreg_phy_mode               : std_logic;
 signal atx_reset_core                : std_logic;
 signal usb_dma_fpga                  : std_logic_vector(63 downto 0);
 signal usb_clk                       : std_logic; -- UTMI/ULPI clock
 signal usb_rst_n                     : std_logic;
 signal usb_inc_frindex_toggle        : std_logic;
 signal usbreg_run_sync               : std_logic;
 signal usbreg_fladj_sync             : std_logic_vector(5 downto 0);
 signal usbreg_fladj_change_sync      : std_logic;
 signal pie_devicespeed               : std_logic_vector(1 downto 0);
 signal pie_devicespeed_sync          : std_logic_vector(1 downto 0);
 signal usb_send_sof                  : std_logic;
 signal usb_endofframe                : std_logic;
 signal epinfo_starttransfer_sync     : std_logic;
 signal epinfo_token_sync             : std_logic_vector(2 downto 0);
 signal epinfo_devaddr_sync           : std_logic_vector(6 downto 0);
 signal epinfo_epnr_sync              : std_logic_vector(3 downto 0);
 signal epinfo_toggle_sync            : std_logic;
 signal epinfo_eptype_sync            : std_logic_vector(1 downto 0);
 signal epinfo_mult_sync              : std_logic_vector(1 downto 0);
 signal epinfo_maxpacket_sync         : std_logic_vector(10 downto 0);
 signal epinfo_nbytes_sync            : std_logic_vector(11 downto 0);
 signal epinfo_lowspeed_sync          : std_logic;
 signal epinfo_sofnr_sync             : std_logic_vector(10 downto 0);
 signal epinfo_subpid_sync            : std_logic_vector(1 downto 0);
 signal epinfo_lpm_linkstate_sync     : std_logic_vector(3 downto 0);
 signal epinfo_lpm_hird_sync          : std_logic_vector(3 downto 0);
 signal epinfo_lpm_bremotewakeup_sync : std_logic;
 signal epinfo_split_hubaddr_sync     : std_logic_vector(6 downto 0);
 signal epinfo_split_port_sync        : std_logic_vector(6 downto 0);
 signal epinfo_split_se_sync          : std_logic_vector(1 downto 0);
 signal pie_txdatafetched             : std_logic;
 signal epinfo_txdata_sync            : std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
 signal epinfo_txdata_valid_sync      : std_logic;
 signal pie_rx_nbytes                 : std_logic_vector(11 downto 0);
 signal pie_rxdata                    : std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
 signal pie_rxdatavalid               : std_logic;
 signal pie_endtransfer               : std_logic;
 signal pie_response                  : std_logic_vector(2 downto 0);
 signal pie_phy_rdata                 : std_logic_vector(7 downto 0);
 signal pie_phy_endtoggle             : std_logic;
 signal pie_resume_detected           : std_logic;
 signal pie_resume_done               : std_logic;
 signal pie_portconnect               : std_logic;
 signal pie_portenable                : std_logic;
 signal pie_linestate                 : std_logic_vector(1 downto 0);
 signal usbreg_phy_addr_sync          : std_logic_vector(7 downto 0);
 signal usbreg_phy_wdata_sync         : std_logic_vector(7 downto 0);
 signal usbreg_phy_write_sync         : std_logic;
 signal usbreg_phy_start_sync         : std_logic;
 signal usbreg_phy_mode_sync          : std_logic;
 signal usbreg_reset_sync             : std_logic;
 signal usbreg_light_reset_sync       : std_logic;
 signal usbreg_reset                  : std_logic;
 signal usbreg_light_reset            : std_logic;
 signal usbreg_portpower_sync         : std_logic;
 signal usbreg_portreset_sync         : std_logic;
 signal usbreg_portsuspend_sync       : std_logic;
 signal usbreg_portl1l2suspend_sync   : std_logic;
 signal usbreg_portresume_sync        : std_logic;
 signal usbreg_fladj                  : std_logic_vector(5 downto 0);
 signal usbreg_fladj_change           : std_logic;
 signal usbreg_run                    : std_logic;
-- signal usbreg_light_reset            : std_logic;
 signal usbreg_portresume             : std_logic;
 signal usbreg_portreset              : std_logic;
 signal usbreg_portsuspend            : std_logic;
 signal usbreg_portl1l2suspend        : std_logic;
 signal usbreg_portpower              : std_logic;
 signal usbreg_portenable_clear       : std_logic;
 signal usbreg_portenable_clear_sync  : std_logic;
 signal usbreg_port_force_fullspeed   : std_logic;
 signal usb_inc_frindex_toggle_sync   : std_logic;
 signal pie_portconnect_sync          : std_logic;
 signal pie_portenable_sync           : std_logic;
 signal usb_overcurrent_sync          : std_logic;
 signal pie_resume_detected_sync      : std_logic;
 signal pie_resume_done_sync          : std_logic;
 signal pie_linestate_sync            : std_logic_vector(1 downto 0);
 signal pie_phy_rdata_sync            : std_logic_vector(7 downto 0);
 signal pie_phy_endtoggle_sync        : std_logic;
 signal pie_txdatafetched_sync        : std_logic;
 signal pie_rx_nbytes_sync            : std_logic_vector(11 downto 0);
 signal pie_rxdata_sync               : std_logic_vector(USBPIE_DATAWIDTH-1 downto 0);
 signal pie_rxdatavalid_sync          : std_logic;
 signal pie_endtransfer_sync          : std_logic;
 signal pie_response_sync             : std_logic_vector(2 downto 0);
 signal usb_host_reg_if_fpga          : std_logic_vector(63 downto 0);
 signal usbreg_atl_base               : std_logic_vector(22 downto 0);
 signal usbreg_atl_cur_ptd            : std_logic_vector(4 downto 0);
 signal usbreg_iso_base               : std_logic_vector(21 downto 0);
 signal usbreg_iso_first_ptd          : std_logic_vector(4 downto 0);
 signal usbreg_int_base               : std_logic_vector(21 downto 0);
 signal usbreg_int_first_ptd          : std_logic_vector(4 downto 0);
 signal usbreg_payload_base           : std_logic_vector(15 downto 0);
 signal usbreg_frindex                : std_logic_vector(13 downto 0);
 signal usbreg_atl_enable             : std_logic;
 signal usbreg_iso_enable             : std_logic;
 signal usbreg_int_enable             : std_logic;
 signal dma_atl_setint                : std_logic;
 signal dma_iso_setint                : std_logic;
 signal dma_int_setint                : std_logic;
 signal dma_atl_setdone               : std_logic;
 signal dma_iso_setdone               : std_logic;
 signal dma_int_setdone               : std_logic;
 signal dma_atl_setptd                : std_logic;
 signal dma_current_ptd               : std_logic_vector(4 downto 0);
 signal usbreg_atl_skip               : std_logic_vector(31 downto 0);
 signal usbreg_iso_skip               : std_logic_vector(31 downto 0);
 signal usbreg_int_skip               : std_logic_vector(31 downto 0);
 signal usbreg_atl_last               : std_logic_vector(4 downto 0);
 signal usbreg_iso_last               : std_logic_vector(4 downto 0);
 signal usbreg_int_last               : std_logic_vector(4 downto 0);
 signal usb_host_pie_fpga             : std_logic_vector(63 downto 0);
 signal epinfo_starttransfer          : std_logic;
 signal epinfo_token                  : std_logic_vector(2 downto 0);
 signal epinfo_devaddr                : std_logic_vector(6 downto 0);
 signal epinfo_epnr                   : std_logic_vector(3 downto 0);
 signal epinfo_eptype                 : std_logic_vector(1 downto 0);
 signal epinfo_mult                   : std_logic_vector(1 downto 0);
 signal epinfo_lowspeed               : std_logic;
 signal epinfo_sofnr                  : std_logic_vector(10 downto 0);
 signal epinfo_subpid                 : std_logic_vector(1 downto 0);
 signal epinfo_lpm_hird               : std_logic_vector(3 downto 0);
 signal epinfo_lpm_bremotewakeup      : std_logic;
 signal epinfo_split_hubaddr          : std_logic_vector(6 downto 0);
 signal epinfo_split_port             : std_logic_vector(6 downto 0);
 signal epinfo_split_se               : std_logic_vector(1 downto 0);
 signal sync_reset_done               : std_logic;
 signal usb_inc_frindex_toggle_dma    : std_logic;
 signal ulpi_pwrctrl_wakeup           : std_logic;
 signal atx_reset_core_s              : std_logic;
 signal atx_reset_core_ss             : std_logic;
 signal usb_decrement_bytes           : std_logic;
 signal usb_decrement_bytes_sync      : std_logic;
 signal usb_uframe_count              : std_logic_vector(2 downto 0);
 signal usb_uframe_count_sync         : std_logic_vector(2 downto 0);
 signal usbreg_lpm_addr               : std_logic_vector(6 downto 0);
 signal usbreg_susp_l1_on             : std_logic;
 signal dma_lpm_stat                  : std_logic_vector(1 downto 0);
 signal dma_lpm_success               : std_logic;
 signal dma_lpm_done                  : std_logic;

 constant CLOCKOFF_CYCLE              : integer := 255;
 signal clk_off_counter               : integer range 0 to CLOCKOFF_CYCLE;
 signal reset_needed                  : std_logic;
 signal reset_needed_z                : std_logic;
 signal reset_needed_zz               : std_logic;
 signal reset_done                    : std_logic;
 signal reset_done_z                  : std_logic;
 signal reset_done_zz                 : std_logic;
 signal pie_lowpower_n                : std_logic;
 signal clock_on                      : std_logic;
-- synthesis read_comments_as_HDL on
-- attribute keep: boolean;
-- attribute keep of clock_on: signal is true;
-- synthesis read_comments_as_HDL off
 signal pwrctrl_wakeup_int            : std_logic;
 signal utmi_clk_ok                   : std_logic;
 signal dp                            : std_logic;
 signal dm                            : std_logic;
 signal dp_s                          : std_logic;
 signal dm_s                          : std_logic;
 signal ulpi_dir_s                    : std_logic;
 signal ulpi_dir_ss                   : std_logic;
 signal ulpi_dir_sss                  : std_logic;
 signal ulpi_nxt_s                    : std_logic;
 signal ulpi_nxt_ss                   : std_logic;
 signal ulpi_nxt_sss                  : std_logic;
 signal ulpi_linestate_lp             : std_logic_vector (1 downto 0);
 signal ulpi_int_lp                   : std_logic;
 signal dataline_low_power_en         : std_logic;
 constant CLOCK_COUNTER_AHB_MAX       : integer := 63; -- This allows an AHB clock frequency of maximum 480MHz
 signal clock_counter_ahb             : integer range 0 to CLOCK_COUNTER_AHB_MAX;
 constant CLOCK_COUNTER_USB_MAX       : integer := 15;
 signal clock_counter_usb             : integer range 0 to CLOCK_COUNTER_USB_MAX;
 signal clock_counter_usb_msb         : std_logic;
 signal clock_counter_usb_msb_z       : std_logic;
 signal clock_counter_usb_msb_zz      : std_logic;
 signal awake                         : std_logic;
 signal usb_needclk_int               : std_logic;
 signal usbreg_woo                    : std_logic;
 signal dbc_vbus_en                   : std_logic;
 signal id_value_sync                 : std_logic;

 signal utmi_clk_ok_clr_n             : std_logic;
 signal utmi_clk_ok_clr_n_q           : std_logic;
 signal utmi_clk_ok_clr_n_dft         : std_logic;

 signal pwrctrl_wakeup_int_set_n      : std_logic;
 signal pwrctrl_wakeup_int_set_n_q    : std_logic;
 signal pwrctrl_wakeup_int_set_n_dft  : std_logic;

begin

 PROC_DBC_VBUS: process(usb_clk)
 begin
 -- debouncing on vbus is disabled for simulations only
   dbc_vbus_en <= '1';
 -- cadence translate_off
   dbc_vbus_en <= '0';
 -- cadence translate_on
 -- synthesis read_comments_as_HDL on
 --dbc_vbus_en  <= '1';
 -- synthesis read_comments_as_HDL off

  end process PROC_DBC_VBUS;

 PROC_USB_RESET : process(hresetn,usb_clk)
 begin
   if hresetn = '0' then
     atx_reset_core_s  <= '1';
     atx_reset_core_ss <= '1';
   elsif usb_clk = '1' and usb_clk'event then
     atx_reset_core_s  <= atx_reset_core;
     atx_reset_core_ss <= atx_reset_core_s;
   end if;
 end process PROC_USB_RESET;
 usb_rst_n <= (not atx_reset_core_ss) or async_disable;

 usb_host_sof_timer_1 : usb_host_sof_timer
    port map   (
      --To/From external
      usb_rst_n                  => usb_rst_n,--: in  std_logic;
      usb_clk                    => usb_clk,--: in  std_logic;
      --To/From usb_host_synchronizer module
      usbreg_reset_sync          => usbreg_reset_sync,
      usbreg_light_reset_sync    => usbreg_light_reset_sync,
      usbreg_run_sync            => usbreg_run_sync,--: in  std_logic;
      usbreg_fladj_sync          => usbreg_fladj_sync,--: in  std_logic_vector(5 downto 0);
      usbreg_fladj_change_sync   => usbreg_fladj_change_sync,--: in  std_logic;
      usb_inc_frindex_toggle     => usb_inc_frindex_toggle,--: out std_logic;
      usb_decrement_bytes        => usb_decrement_bytes,
      usb_uframe_count           => usb_uframe_count,
      --To/From usb_host_pie module
      pie_devicespeed            => pie_devicespeed,--: in  std_logic_vector(1 downto 0);
      usb_send_sof               => usb_send_sof,--: out std_logic;
      usb_endofframe             => usb_endofframe --: out std_logic
      );


usb_host_pie_1 : usb_host_pie
    generic map(
                ULPI_SUPPORT  => C_ULPI_SUPPORT,
                UTMI_SUPPORT  => C_UTMI_SUPPORT,
		USB_DATAWIDTH => USBPIE_DATAWIDTH
		)
    port map   (
      reset_n                       => usb_rst_n,
      pie_clk                       => usb_clk,
      dbc_vbus_en                   => dbc_vbus_en,
      epinfo_starttransfer_sync     => epinfo_starttransfer_sync,-- : in  std_logic;
      epinfo_token_sync             => epinfo_token_sync,-- : in  std_logic_vector(2 downto 0);
      epinfo_devaddr_sync           => epinfo_devaddr_sync,-- : in  std_logic_vector(6 downto 0);
      epinfo_epnr_sync              => epinfo_epnr_sync,-- : in  std_logic_vector(3 downto 0);
      epinfo_toggle_sync            => epinfo_toggle_sync,-- : in  std_logic;
      epinfo_eptype_sync            => epinfo_eptype_sync,-- : in  std_logic_vector(1 downto 0);
      epinfo_mult_sync              => epinfo_mult_sync,-- : in  std_logic_vector(1 downto 0);
      epinfo_maxpacket_sync         => epinfo_maxpacket_sync,-- : in  std_logic_vector(10 downto 0);
      epinfo_nbytes_sync            => epinfo_nbytes_sync,-- : in  std_logic_vector(11 downto 0);
      epinfo_lowspeed_sync          => epinfo_lowspeed_sync,-- : in  std_logic;
      epinfo_sofnr_sync             => epinfo_sofnr_sync,-- : in  std_logic_vector(10 downto 0);
      epinfo_subpid_sync            => epinfo_subpid_sync,-- : in  std_logic_vector(1 downto 0);
      epinfo_lpm_linkstate_sync     => epinfo_lpm_linkstate_sync,-- : in  std_logic_vector(3 downto 0);
      epinfo_lpm_hird_sync          => epinfo_lpm_hird_sync,-- : in  std_logic_vector(3 downto 0);
      epinfo_lpm_bremotewakeup_sync => epinfo_lpm_bremotewakeup_sync,-- : in  std_logic;
      epinfo_split_hubaddr_sync     => epinfo_split_hubaddr_sync,-- : in  std_logic_vector(6 downto 0);
      epinfo_split_port_sync        => epinfo_split_port_sync,-- : in  std_logic_vector(6 downto 0);
      epinfo_split_se_sync          => epinfo_split_se_sync,-- : in  std_logic_vector(1 downto 0);
      pie_txdatafetched             => pie_txdatafetched,--: std_logic;
      epinfo_txdata_sync            => epinfo_txdata_sync,--: std_logic_vector(USB_DATAWIDTH-1 downto 0);
      epinfo_txdata_valid_sync      => epinfo_txdata_valid_sync,--: std_logic;
      pie_rx_nbytes                 => pie_rx_nbytes,--: out std_logic_vector(11 downto 0);
      pie_rxdata                    => pie_rxdata,--: out std_logic_vector(USB_DATAWIDTH-1 downto 0);
      pie_rxdatavalid               => pie_rxdatavalid,--: out std_logic;
      pie_endtransfer               => pie_endtransfer,--: out std_logic;
      pie_response                  => pie_response,--: out std_logic_vector(2 downto 0);
      usbreg_phy_addr_sync          => usbreg_phy_addr_sync,--: in  std_logic_vector(7 downto 0);
      pie_phy_rdata                 => pie_phy_rdata,--: out std_logic_vector(7 downto 0);
      usbreg_phy_wdata_sync         => usbreg_phy_wdata_sync,--: in  std_logic_vector(7 downto 0);
      usbreg_phy_write_sync         => usbreg_phy_write_sync,--: in  std_logic;
      usbreg_phy_start_sync         => usbreg_phy_start_sync,--: in  std_logic;
      pie_phy_endtoggle             => pie_phy_endtoggle,--: out std_logic;
      usbreg_phy_mode_sync          => usbreg_phy_mode_sync,--: in  std_logic;
      usbreg_reset_sync             => usbreg_reset_sync,--: in  std_logic;
      usbreg_light_reset_sync       => usbreg_light_reset_sync,--: in  std_logic;
      usbreg_portpower_sync         => usbreg_portpower_sync,--: in std_logic;
      usbreg_portreset_sync         => usbreg_portreset_sync,--: in std_logic;
      usbreg_portsuspend_sync       => usbreg_portsuspend_sync,--: in  std_logic;
      usbreg_portl1l2suspend_sync   => usbreg_portl1l2suspend_sync,--: in  std_logic;
      usbreg_portresume_sync        => usbreg_portresume_sync,--: in  std_logic;
      usbreg_portenable_clear_sync  => usbreg_portenable_clear_sync,--: in  std_logic;
      usbreg_port_force_fullspeed   => usbreg_port_force_fullspeed, --: in  std_logic
      pie_resume_detected           => pie_resume_detected,--: out std_logic;
      pie_resume_done               => pie_resume_done,--: out std_logic;
      pie_portconnect               => pie_portconnect,--: out std_logic;
      pie_portenable                => pie_portenable,--: out std_logic;
      pie_linestate                 => pie_linestate,--: out std_logic_vector(1 downto 0);
      usbreg_pll_on                 => usbreg_pll_on,--: in  std_logic;
      usbreg_phy_test_mode_change_sync  => usbreg_phy_test_mode_change_sync,--: in  std_logic;
      usbreg_phy_test_mode          => usbreg_phy_test_mode,--: in  std_logic_vector(2 downto 0);
      pie_devicespeed               => pie_devicespeed,--: out std_logic_vector(1 downto 0);
      usb_send_sof                  => usb_send_sof,--: in  std_logic;
      usb_endofframe                => usb_endofframe,--: in  std_logic;
      usb_overcurrent_sync          => usb_overcurrent_sync,--: out std_logic;
      utmi_vbusvalid                => vbusvalid,
      utmi_rxdata                   => utmi_rxdata,
      utmi_rxvalid                  => utmi_rxvalid,
      utmi_rxactive                 => utmi_rxactive,
      utmi_rxerror                  => utmi_rxerror,
      utmi_txdata                   => utmi_txdata,
      utmi_txvalid                  => utmi_txvalid,
      utmi_txready                  => utmi_txready,
      utmi_reset                    => open,
      pie_lowpower_n                => pie_lowpower_n,
      utmi_xcvrselect               => utmi_xcvrselect,
      utmi_termselect               => utmi_termselect,
      utmi_opmode                   => utmi_opmode,
      utmi_linestate                => utmi_linestate,
      utmi_hostdisconnect           =>  utmi_hostdisconnect,--: in  std_logic;
      utmi_vcontrol                 => utmi_vcontrol,-- : out std_logic_vector(3 downto 0);
      utmi_vcontrolloadm            => utmi_vcontrolloadm,--   : out std_logic;
      utmi_vstatus                  => utmi_vstatus,--   : in  std_logic_vector(7 downto 0);
      ulpi_pwrctrl_wakeup           => ulpi_pwrctrl_wakeup,
      ulpi_rxdata                   => ulpi_rxdata,
      ulpi_txdata                   => ulpi_txdata,
      ulpi_txenable                 => ulpi_txenable,
      ulpi_dir                      => ulpi_dir,
      ulpi_stp                      => ulpi_stp,
      ulpi_nxt                      => ulpi_nxt,
      usb_host_pie_fpga             => usb_host_pie_fpga,-- : out std_logic_vector(63 downto 0)
      INTER_PACKET_DELAY_LS_param   => usb_host_pie_INTER_PACKET_DELAY_LS_param,
      INTER_PACKET_DELAY_FS_param   => usb_host_pie_INTER_PACKET_DELAY_FS_param,
      INTER_PACKET_DELAY_HS_param   => usb_host_pie_INTER_PACKET_DELAY_HS_param,
      PACKET_TURNAROUND_TIMEOUT_LS_param => usb_host_pie_PACKET_TURNAROUND_TIMEOUT_LS_param,
      PACKET_TURNAROUND_TIMEOUT_FS_param => usb_host_pie_PACKET_TURNAROUND_TIMEOUT_FS_param,
      PACKET_TURNAROUND_TIMEOUT_HS_param => usb_host_pie_PACKET_TURNAROUND_TIMEOUT_HS_param,
      PACKET_EVENT_TIMEOUT_LS_param => usb_host_pie_PACKET_EVENT_TIMEOUT_LS_param,
      PACKET_EVENT_TIMEOUT_FS_param => usb_host_pie_PACKET_EVENT_TIMEOUT_FS_param,
      PACKET_EVENT_TIMEOUT_HS_param => usb_host_pie_PACKET_EVENT_TIMEOUT_HS_param,
      usb_host_pie_portl1l2suspend_use_sync_n => usb_host_pie_portl1l2suspend_use_sync_n

      );

usb_host_synchronizer_1: usb_host_synchronizer
  generic map (
               C_ULPI_SUPPORT       => C_ULPI_SUPPORT,
               C_UTMI_SUPPORT       => C_UTMI_SUPPORT,
               USB_DATAWIDTH        => USBPIE_DATAWIDTH,
               C_PORTPOWER_CONTROL  => C_PORTPOWER_CONTROL
               )
  port map    (

      --To/from external
      usb_clk                  => usb_clk,--: in  std_logic;
      usb_rst_n                => usb_rst_n,--: in  std_logic;
      hclk                     => hclk,--: in  std_logic;
      hrstn                    => hresetn,--: in  std_logic;
      usb_overcurrent_n        => usb_overcurrent_n,--: in  std_logic;
      id_value                 => utmi_id_value,--: in  std_logic;
      --To/from USB_HOST_REG_IF
      usbreg_fladj                => usbreg_fladj,--: in  std_logic_vector(5 downto 0);
      usbreg_fladj_change         => usbreg_fladj_change,--: in  std_logic;
      usbreg_run                  => usbreg_run,--: in  std_logic;
      usbreg_reset                => usbreg_reset,--: in  std_logic;
      usbreg_light_reset          => usbreg_light_reset,--: in  std_logic;
      sync_reset_done             => sync_reset_done,--: out  std_logic;
      usbreg_portresume           => usbreg_portresume,--: in  std_logic;
      usbreg_portreset            => usbreg_portreset,--: in  std_logic;
      usbreg_portsuspend          => usbreg_portsuspend,--: in  std_logic;
      usbreg_portl1l2suspend      => usbreg_portl1l2suspend,-- : in std_logic;
      usbreg_portpower            => usbreg_portpower,--: in  std_logic;
      usbreg_portenable_clear     => usbreg_portenable_clear,--: in  std_logic;
      usbreg_phy_addr             => usbreg_phy_addr,--: in  std_logic_vector(7 downto 0);
      usbreg_phy_wdata            => usbreg_phy_wdata,--: in  std_logic_vector(7 downto 0);
      usbreg_phy_write            => usbreg_phy_write,--: in  std_logic;
      usbreg_phy_start            => usbreg_phy_start,--: in  std_logic;
      usbreg_phy_mode             => usbreg_phy_mode,--: in  std_logic;
      usb_inc_frindex_toggle_sync => usb_inc_frindex_toggle_sync,--: out std_logic;
      usbreg_phy_test_mode        => usbreg_phy_test_mode,--: in std_logic_vector (2 downto 0);
      pie_portconnect_sync        => pie_portconnect_sync,--: out std_logic;
      pie_portenable_sync         => pie_portenable_sync,--: out std_logic;
      usb_overcurrent_sync        => usb_overcurrent_sync,--: out std_logic;
      pie_resume_detected_sync    => pie_resume_detected_sync,--: out std_logic;
      pie_resume_done_sync        => pie_resume_done_sync,--: out std_logic;
      pie_linestate_sync          => pie_linestate_sync,--: out std_logic_vector(1 downto 0);
      pie_phy_rdata_sync          => pie_phy_rdata_sync,--: out std_logic_vector(7 downto 0);
      pie_phy_endtoggle_sync      => pie_phy_endtoggle_sync,--: out std_logic;
      pie_devicespeed_sync        => pie_devicespeed_sync,--: out std_logic_vector(1 downto 0);
      id_value_sync               => id_value_sync, --out std_logic;
      --To/from USB_HOST_DMA
      pie_txdatafetched_sync   => pie_txdatafetched_sync,--: out std_logic;
      pie_rx_nbytes_sync       => pie_rx_nbytes_sync,--: out std_logic_vector(11 downto 0);
      pie_rxdata_sync          => pie_rxdata_sync,--: out std_logic_vector(USB_DATAWIDTH-1 downto 0);
      pie_rxdatavalid_sync     => pie_rxdatavalid_sync,--: out std_logic;
      pie_endtransfer_sync     => pie_endtransfer_sync,--: out std_logic;
      pie_response_sync        => pie_response_sync,--: out std_logic_vector(2 downto 0);
      usb_decrement_bytes_sync => usb_decrement_bytes_sync,--: out std_logic;
      epinfo_starttransfer     => epinfo_starttransfer,--: in  std_logic;
      epinfo_token             => epinfo_token,--: in  std_logic_vector(2 downto 0);
      epinfo_devaddr           => epinfo_devaddr,--: in  std_logic_vector(6 downto 0);
      epinfo_epnr              => epinfo_epnr,--: in  std_logic_vector(3 downto 0);
      epinfo_toggle            => epinfo_toggle,--: in  std_logic;
      epinfo_eptype            => epinfo_eptype,--: in  std_logic_vector(1 downto 0);
      epinfo_mult              => epinfo_mult,--: in  std_logic_vector(1 downto 0);
      epinfo_maxpacket         => epinfo_maxpacket,--: in  std_logic_vector(10 downto 0);
      epinfo_nbytes            => epinfo_nbytes,--: in  std_logic_vector(11 downto 0);
      epinfo_lowspeed          => epinfo_lowspeed,--: in  std_logic;
      epinfo_sofnr             => epinfo_sofnr,--: in  std_logic_vector(10 downto 0);
      epinfo_subpid            => epinfo_subpid,--: in  std_logic_vector(1 downto 0);
      epinfo_lpm_linkstate     => "0001",--: in  std_logic_vector(3 downto 0);
      epinfo_lpm_hird          => epinfo_lpm_hird,--: in  std_logic_vector(3 downto 0);
      epinfo_lpm_bremotewakeup => epinfo_lpm_bremotewakeup,--: in  std_logic;
      epinfo_split_hubaddr     => epinfo_split_hubaddr,--: in  std_logic_vector(6 downto 0);
      epinfo_split_port        => epinfo_split_port,--: in  std_logic_vector(6 downto 0);
      epinfo_split_se          => epinfo_split_se,--: in  std_logic_vector(1 downto 0);
      epinfo_txdata            => epinfo_txdata,--: in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
      epinfo_txdata_valid      => epinfo_txdata_valid,--: in  std_logic;
      --To/from USB_HOST_PIE
      pie_txdatafetched         => pie_txdatafetched,--: in  std_logic;
      pie_rx_nbytes             => pie_rx_nbytes,--: in  std_logic_vector(11 downto 0);
      pie_rxdata                => pie_rxdata,--: in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
      pie_rxdatavalid           => pie_rxdatavalid,--: in  std_logic;
      pie_endtransfer           => pie_endtransfer,--: in  std_logic;
      pie_response              => pie_response,--: in  std_logic_vector(2 downto 0);
      pie_phy_rdata             => pie_phy_rdata,--: in  std_logic_vector(7 downto 0);
      pie_phy_endtoggle         => pie_phy_endtoggle,--: in  std_logic;
      pie_resume_detected       => pie_resume_detected,--: in  std_logic;
      pie_resume_done           => pie_resume_done,--: in  std_logic;
      pie_portconnect           => pie_portconnect,--: in  std_logic;
      pie_portenable            => pie_portenable,--: in  std_logic;
      pie_linestate             => pie_linestate,--: in  std_logic_vector(1 downto 0);
      pie_devicespeed           => pie_devicespeed,--: in  std_logic_vector(1 downto 0);
      epinfo_starttransfer_sync => epinfo_starttransfer_sync,--: out std_logic;
      epinfo_token_sync         => epinfo_token_sync,--: out std_logic_vector(2 downto 0);
      epinfo_devaddr_sync       => epinfo_devaddr_sync,--: out std_logic_vector(6 downto 0);
      epinfo_epnr_sync          => epinfo_epnr_sync,--: out std_logic_vector(3 downto 0);
      epinfo_toggle_sync        => epinfo_toggle_sync,--: out std_logic;
      epinfo_eptype_sync        => epinfo_eptype_sync,--: out std_logic_vector(1 downto 0);
      epinfo_mult_sync          => epinfo_mult_sync,--: out std_logic_vector(1 downto 0);
      epinfo_maxpacket_sync     => epinfo_maxpacket_sync,--: out std_logic_vector(10 downto 0);
      epinfo_nbytes_sync        => epinfo_nbytes_sync,--: out std_logic_vector(11 downto 0);
      epinfo_lowspeed_sync      => epinfo_lowspeed_sync,--: out std_logic;
      epinfo_sofnr_sync         => epinfo_sofnr_sync,--: out std_logic_vector(10 downto 0);
      epinfo_subpid_sync        => epinfo_subpid_sync,--: out std_logic_vector(1 downto 0);
      epinfo_lpm_linkstate_sync => epinfo_lpm_linkstate_sync,--: out std_logic_vector(3 downto 0);
      epinfo_lpm_hird_sync      => epinfo_lpm_hird_sync,--: out std_logic_vector(3 downto 0);
      epinfo_lpm_bremotewakeup_sync => epinfo_lpm_bremotewakeup_sync,-- : out std_logic;
      epinfo_split_hubaddr_sync => epinfo_split_hubaddr_sync,--: out std_logic_vector(6 downto 0);
      epinfo_split_port_sync    => epinfo_split_port_sync,--: out std_logic_vector(6 downto 0);
      epinfo_split_se_sync      => epinfo_split_se_sync,--: out std_logic_vector(1 downto 0);
      epinfo_txdata_sync        => epinfo_txdata_sync,--: out std_logic_vector(USB_DATAWIDTH-1 downto 0);
      epinfo_txdata_valid_sync  => epinfo_txdata_valid_sync,--: out std_logic;
      usbreg_phy_addr_sync      => usbreg_phy_addr_sync,--: out std_logic_vector(7 downto 0);
      usbreg_phy_wdata_sync     => usbreg_phy_wdata_sync,--: out std_logic_vector(7 downto 0);
      usbreg_phy_write_sync     => usbreg_phy_write_sync,--: out std_logic;
      usbreg_phy_start_sync     => usbreg_phy_start_sync,--: out std_logic;
      usbreg_phy_mode_sync      => usbreg_phy_mode_sync,--: out std_logic;
      usbreg_reset_sync         => usbreg_reset_sync,--: out std_logic;
      usbreg_light_reset_sync   => usbreg_light_reset_sync,--: out std_logic;
      usbreg_portpower_sync     => usbreg_portpower_sync,--: out std_logic;
      usbreg_portreset_sync     => usbreg_portreset_sync,--: out std_logic;
      usbreg_portsuspend_sync   => usbreg_portsuspend_sync,--: out std_logic;
      usbreg_portl1l2suspend_sync => usbreg_portl1l2suspend_sync,--: out std_logic;
      usbreg_portresume_sync    => usbreg_portresume_sync,--: out std_logic;
      usbreg_portenable_clear_sync=> usbreg_portenable_clear_sync,-- : out std_logic;
      usbreg_phy_test_mode_change_sync => usbreg_phy_test_mode_change_sync,-- : out std_logic;
      usb_uframe_count_sync     => usb_uframe_count_sync,--: out std_logic_vector(2 downto 0);
      --To/from USB_HOST_SOF_TIMER
      usb_inc_frindex_toggle   => usb_inc_frindex_toggle,--: in  std_logic;
      usb_decrement_bytes      => usb_decrement_bytes,--: in  std_logic;
      usb_uframe_count         => usb_uframe_count,--: in  std_logic_vector(2 downto 0);
      usbreg_run_sync          => usbreg_run_sync,--: out std_logic;
      usbreg_fladj_sync        => usbreg_fladj_sync,--: out std_logic_vector(5 downto 0);
      usbreg_fladj_change_sync => usbreg_fladj_change_sync--: out std_logic
      );

 usb_host_reg_if_1 : usb_host_reg_if
  generic map (
               AHB_SLAVE_ADDR_WIDTH => AHB_SLAVE_ADDR_WIDTH,
               C_ULPI_SUPPORT       => C_ULPI_SUPPORT,
               C_UTMI_SUPPORT       => C_UTMI_SUPPORT,
               C_MINOR_REV          => C_MINOR_REV,
               C_MAJOR_REV          => C_MAJOR_REV,
               C_PORTPOWER_CONTROL  => C_PORTPOWER_CONTROL,
               C_PORTINDICATOR      => C_PORTINDICATOR
               )
  port map (
      ------------------
      -- FPGA related --
      ------------------
      usb_host_reg_if_fpga => usb_host_reg_if_fpga,
      ----------------------
      -- To/From external --
      ----------------------
      hclk              => hclk, --: in  std_logic;
      hresetn           => hresetn, --: in  std_logic;
      usb_int_req_irq   => usb_int_req_irq, --: out std_logic;
      usb_portindicator => usb_portindicator, --: out std_logic_vector(1 downto 0); -- PIC register field
      usbreg_id_en      => utmi_id_enable,
      usbreg_dev_en     => dev_enable,
      usbreg_sw_ctrl_pdcom  => sw_ctrl_pdcom,
      usbreg_sw_pdcom       => sw_pdcom,
      ---------------------------------
      --To/From usb_ahb_slave module --
      ---------------------------------
      reg_waddr => reg_waddr, --: in  std_logic_vector(6 downto 2);
      reg_wdata => reg_wdata, --: in  std_logic_vector(31 downto 0);
      reg_raddr => reg_raddr, --: in  std_logic_vector(6 downto 2);
      reg_rdata => reg_rdata, --: out std_logic_vector(31 downto 0);
      reg_write => reg_write, --: in  std_logic;
      --------------------------------
      --To/From usb_host_pie module --
      --------------------------------
      usbreg_pll_on             => usbreg_pll_on, --: out std_logic; -- usb_pll register bit
      usbreg_phy_test_mode      => usbreg_phy_test_mode, --: out std_logic_vector(2 downto 0); -- PTC register field
      pie_devicespeed_sync      => pie_devicespeed_sync, --: in std_logic_vector(1 downto 0);
      usbreg_lpm_hird           => epinfo_lpm_hird,--: out std_logic_vector(3 downto 0);
      usbreg_lpm_bremotewakeup  => epinfo_lpm_bremotewakeup,--: out std_logic;
      usbreg_lpm_addr           => usbreg_lpm_addr,
      usbreg_susp_l1_on         => usbreg_susp_l1_on,
      dma_lpm_success           => dma_lpm_success,
      dma_lpm_done              => dma_lpm_done,
      dma_lpm_stat              => dma_lpm_stat,
      usbreg_port_force_fullspeed => usbreg_port_force_fullspeed,
      --------------------------------
      --To/From usb_host_synchronizer module
      --------------------------------
      usbreg_fladj                => usbreg_fladj, --: out std_logic_vector(5 downto 0); -- FLADJ register field
      usbreg_fladj_change         => usbreg_fladj_change, --: out std_logic;
      usbreg_run                  => usbreg_run, --: out std_logic; -- Run/stop register bit
      usbreg_reset                => usbreg_reset, --: out std_logic; -- hcreset register bit
      usbreg_light_reset          => usbreg_light_reset, --: out std_logic; -- lhcr register bit
      sync_reset_done             => sync_reset_done,--: in  std_logic;
      usb_inc_frindex_toggle_sync => usb_inc_frindex_toggle_sync, --: in  std_logic;
      pie_portconnect_sync        => pie_portconnect_sync, --: in  std_logic; -- CCS register bit
      pie_portenable_sync         => pie_portenable_sync, --: in  std_logic; -- PED register bit when read by SW
      usb_overcurrent_sync        => usb_overcurrent_sync, --: in  std_logic; -- OCA register bit
      usbreg_portresume           => usbreg_portresume, --: out std_logic; -- FPR register bit
      pie_resume_detected_sync    => pie_resume_detected_sync, --: in  std_logic; -- If this signal is one, the FPR bit is set to one
      pie_resume_done_sync        => pie_resume_done_sync, --: in  std_logic; -- If this signal is one, the FPR bit is set to zero
      usbreg_portreset            => usbreg_portreset, --: out std_logic; -- PR register bit
      usbreg_portsuspend          => usbreg_portsuspend, --: out std_logic; -- SUSP register bit
      usbreg_portl1l2suspend      => usbreg_portl1l2suspend,-- : out std_logic;
      pie_linestate_sync          => pie_linestate_sync, --: in  std_logic_vector(1 downto 0); -- LS register field
      usbreg_portpower            => usbreg_portpower, --: out std_logic; -- PP register bit
      usbreg_portenable_clear     => usbreg_portenable_clear, --: out std_logic; -- If SW writes a zero to the PED bit, this signal is toggled
      usbreg_phy_addr             => usbreg_phy_addr, --: out std_logic_vector(7 downto 0);
      usbreg_phy_wdata            => usbreg_phy_wdata, --: out std_logic_vector(7 downto 0);
      phy_rdata_sync              => pie_phy_rdata_sync, --: in  std_logic_vector(7 downto 0);
      usbreg_phy_write            => usbreg_phy_write, --: out std_logic;
      usbreg_phy_start            => usbreg_phy_start, --: out std_logic;
      usbreg_phy_mode             => usbreg_phy_mode, --: out std_logic;
      phy_endtoggle_sync          => pie_phy_endtoggle_sync, --: in  std_logic;
      id_value_sync               => id_value_sync,
      ---------------------------------
      -- To/From usb_host_dma module --
      ---------------------------------
      usbreg_atl_base       => usbreg_atl_base, --: out std_logic_vector(22 downto 0);
      usbreg_atl_cur_ptd    => usbreg_atl_cur_ptd, --: out std_logic_vector(4 downto 0);
      usbreg_iso_base       => usbreg_iso_base, --: out std_logic_vector(21 downto 0);
      usbreg_iso_first_ptd  => usbreg_iso_first_ptd, --: out std_logic_vector(4 downto 0);
      usbreg_int_base       => usbreg_int_base, --: out std_logic_vector(21 downto 0);
      usbreg_int_first_ptd  => usbreg_int_first_ptd, --: out std_logic_vector(4 downto 0);
      usbreg_payload_base   => usbreg_payload_base, --: out std_logic_vector(15 downto 0);
      usbreg_frindex        => usbreg_frindex, --: out std_logic_vector(13 downto 0); -- frindex register field
      usbreg_atl_enable     => usbreg_atl_enable, --: out std_logic; -- atl_en register bit
      usbreg_iso_enable     => usbreg_iso_enable, --: out std_logic; -- iso_en register bit
      usbreg_int_enable     => usbreg_int_enable, --: out std_logic; -- irq_en register bit
      dma_atl_setint        => dma_atl_setint, --: in  std_logic;
      dma_iso_setint        => dma_iso_setint, --: in  std_logic;
      dma_int_setint        => dma_int_setint, --: in  std_logic;
      dma_atl_setdone       => dma_atl_setdone, --: in  std_logic;
      dma_iso_setdone       => dma_iso_setdone, --: in  std_logic;
      dma_int_setdone       => dma_int_setdone, --: in  std_logic;
      dma_atl_setptd        => dma_atl_setptd,--: in std_logic;
      dma_current_ptd       => dma_current_ptd, --: in  std_logic_vector(4 downto 0);
      usbreg_atl_skip       => usbreg_atl_skip, --: out std_logic_vector(31 downto 0); -- ATL_SKIP register field
      usbreg_iso_skip       => usbreg_iso_skip, --: out std_logic_vector(31 downto 0); -- ISO_SKIP register field
      usbreg_int_skip       => usbreg_int_skip, --: out std_logic_vector(31 downto 0); -- INT_SKIP register field
      usbreg_atl_last       => usbreg_atl_last, --: out std_logic_vector(4 downto 0); -- ATL_LAST register field
      usbreg_iso_last       => usbreg_iso_last, --: out std_logic_vector(4 downto 0); -- ISO_LAST register field
      usbreg_int_last       => usbreg_int_last, --: out std_logic_vector(4 downto 0) -- INT_LAST register field
      -------------------
      -- To toplevel module --
      -------------------
      usbreg_woo 	   => usbreg_woo --: out std_logic

      );


usb_ahb_slave_1 : usb_ahb_slave
  generic map (
           AHB_SLAVE_ADDR_WIDTH => AHB_SLAVE_ADDR_WIDTH
              )
  port map   (
             hclk       => hclk,
             hresetn    => hresetn,
             haddr      => ahbs_haddr,
             hwrite     => ahbs_hwrite,
             hsel       => ahbs_hsel,
             htrans1    => ahbs_htrans(1),
             hwdata     => ahbs_hwdata,
             hrdata     => ahbs_hrdata,
             hresp      => ahbs_hresp,
             hready     => ahbs_hreadyout,
             hready_glb => ahbs_hreadyin,
             reg_waddr  => reg_waddr,
             reg_wdata  => reg_wdata,
             reg_raddr  => reg_raddr,
             reg_rdata  => reg_rdata,
             reg_write  => reg_write
             );

usb_host_dma_1 : usb_host_dma
  generic map (
               USB_DATAWIDTH  => USBPIE_DATAWIDTH,
               RAM_DATAWIDTH  => USBRAM_DATAWIDTH,
               RAM_ADDR_WIDTH => RAM_ADDRWIDTH
               )
  port map (
      --To/From external
      hclk              => hclk,--: in    std_logic;
      hresetn           => hresetn,--: in    std_logic;
      dma_addr          => usbram_addr,--: out   std_logic_vector(31 downto 0);
      dma_req           => usbram_req,--: out   std_logic;
      dma_gnt           => usbram_gnt,--: in    std_logic;
      dma_write         => usbram_write,--: out   std_logic;
      dma_wdata         => usbram_wdata,--: out   std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      dma_rdata         => usbram_rdata,--: in    std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      --To/From usb_host_reg_if module
      usbreg_atl_base          => usbreg_atl_base,--: in  std_logic_vector(22 downto 0);
      usbreg_atl_cur_ptd       => usbreg_atl_cur_ptd,--: in  std_logic_vector( 4 downto 0);
      usbreg_iso_base          => usbreg_iso_base,--: in  std_logic_vector(21 downto 0);
      usbreg_iso_first_ptd     => usbreg_iso_first_ptd,--: in  std_logic_vector( 4 downto 0);
      usbreg_int_base          => usbreg_int_base,--: in  std_logic_vector(21 downto 0);
      usbreg_int_first_ptd     => usbreg_int_first_ptd,--: in  std_logic_vector( 4 downto 0);
      usbreg_payload_base      => usbreg_payload_base,--: in  std_logic_vector(15 downto 0);
      usbreg_frindex           => usbreg_frindex,--: in  std_logic_vector(13 downto 0);
      usbreg_run               => usbreg_run,--: in  std_logic;
      usbreg_atl_enable        => usbreg_atl_enable,--: in  std_logic;
      usbreg_iso_enable        => usbreg_iso_enable,--: in  std_logic;
      usbreg_int_enable        => usbreg_int_enable,--: in  std_logic;
      dma_atl_setint           => dma_atl_setint,--: out std_logic;
      dma_iso_setint           => dma_iso_setint,--: out std_logic;
      dma_int_setint           => dma_int_setint,--: out std_logic;
      dma_atl_setdone          => dma_atl_setdone,--: out std_logic;
      dma_iso_setdone          => dma_iso_setdone,--: out std_logic;
      dma_int_setdone          => dma_int_setdone,--: out std_logic;
      dma_atl_setptd           => dma_atl_setptd,--: out std_logic;
      dma_current_ptd          => dma_current_ptd,--: out std_logic_vector(4 downto 0);
      usbreg_atl_skip          => usbreg_atl_skip,--: in  std_logic_vector(31 downto 0);
      usbreg_iso_skip          => usbreg_iso_skip,--: in  std_logic_vector(31 downto 0);
      usbreg_int_skip          => usbreg_int_skip,--: in  std_logic_vector(31 downto 0);
      usbreg_atl_last          => usbreg_atl_last,--: in  std_logic_vector(4 downto 0);
      usbreg_iso_last          => usbreg_iso_last,--: in  std_logic_vector(4 downto 0);
      usbreg_int_last          => usbreg_int_last,--: in  std_logic_vector(4 downto 0);
      usbreg_reset             => usbreg_reset,--: in  std_logic;
      usbreg_light_reset       => usbreg_light_reset,--: in  std_logic;
      usbreg_susp_l1_on        => usbreg_susp_l1_on,
      usbreg_portsuspend       => usbreg_portl1l2suspend,
      usbreg_lpm_addr          => usbreg_lpm_addr,
      dma_lpm_success          => dma_lpm_success,
      dma_lpm_done             => dma_lpm_done,
      dma_lpm_stat             => dma_lpm_stat,
      --To/From usb_host_synchronizer module
      pie_txdatafetched_sync    => pie_txdatafetched_sync,--: in  std_logic;
      pie_rx_nbytes_sync        => pie_rx_nbytes_sync,--: in  std_logic_vector(11 downto 0);
      pie_rxdata_sync           => pie_rxdata_sync,--: in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
      pie_rxdatavalid_sync      => pie_rxdatavalid_sync,--: in  std_logic;
      pie_endtransfer_sync      => pie_endtransfer_sync,--: in  std_logic;
      pie_response_sync         => pie_response_sync,--: in  std_logic_vector(2 downto 0);
      pie_devicespeed_sync      => pie_devicespeed_sync,--: in  std_logic_vector(1 downto 0);
      usb_decrement_bytes_sync  => usb_decrement_bytes_sync,--: in  std_logic;
      epinfo_starttransfer      => epinfo_starttransfer,--: out std_logic;
      epinfo_token              => epinfo_token,--: out std_logic_vector(2 downto 0);
      epinfo_devaddr            => epinfo_devaddr,--: out std_logic_vector(6 downto 0);
      epinfo_epnr               => epinfo_epnr,--: out std_logic_vector(3 downto 0);
      epinfo_toggle             => epinfo_toggle,--: out std_logic;
      epinfo_eptype             => epinfo_eptype,--: out std_logic_vector(1 downto 0);
      epinfo_mult               => epinfo_mult,--: out std_logic_vector(1 downto 0);
      epinfo_maxpacket          => epinfo_maxpacket,--: out std_logic_vector(10 downto 0);
      epinfo_nbytes             => epinfo_nbytes,--: out std_logic_vector(11 downto 0);
      epinfo_lowspeed           => epinfo_lowspeed,--: out std_logic;
      epinfo_sofnr              => epinfo_sofnr,--: out std_logic_vector(10 downto 0);
      epinfo_subpid             => epinfo_subpid,--: out std_logic_vector(1 downto 0);
      epinfo_split_hubaddr      => epinfo_split_hubaddr,--: out std_logic_vector(6 downto 0);
      epinfo_split_port         => epinfo_split_port,--: out std_logic_vector(6 downto 0);
      epinfo_split_se           => epinfo_split_se,--: out std_logic_vector(1 downto 0);
      epinfo_txdata             => epinfo_txdata,--: out std_logic_vector(USB_DATAWIDTH-1 downto 0);
      epinfo_txdata_valid       => epinfo_txdata_valid,--: out std_logic;
      usb_inc_frindex_toggle_sync => usb_inc_frindex_toggle_dma,--: in  std_logic;
      usb_dma_fpga               => usb_dma_fpga--: out std_logic_vector(63 downto 0)
     );

  usb_inc_frindex_toggle_dma <= '1' when usb_inc_frindex_toggle_sync = '1' and
                                         (usb_uframe_count_sync      = "000" or
	  			          pie_devicespeed_sync       = "10")
			            else '0';
  --UTMI/ULPI clock selection
  usb_clk <= utmi_clk when (testmode = '1' and C_UTMI_SUPPORT) else
             ulpi_clk when (testmode = '1' and C_ULPI_SUPPORT) else
             utmi_clk when usbreg_phy_mode_sync = '0'          else
             ulpi_clk;



  utmi_reset_detect_proc : process(hclk,hresetn)
  begin
    if hresetn = '0' then
      atx_reset_core <= '1';
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

  utmi_reset <= '1' when  (atx_reset_core = '1') else '0';

  reset_needed <= atx_reset_core;

-- UTMI only:
  atx_reset_core_proc : process (usb_clk, usb_rst_n)
  begin
     if usb_rst_n = '0' then
      reset_needed_z  <= '1';
      reset_needed_zz <= '1';
      clk_off_counter      <= 0;
    elsif usb_clk'event and usb_clk = '1' then
      if usbreg_phy_mode_sync = '0' then -- UTMI only
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

--  usb_clk_ok_proc : process(clock_on, async_disable, sys_utmi_clkin_lock, usb_clk, clk_off_counter)
--    begin
--      if (((clock_on = '0' and clk_off_counter = 0 ) or sys_utmi_clkin_lock = '0') and async_disable = '0') then
--        utmi_clk_ok <= '0';
--      elsif(usb_clk'event and usb_clk = '1') then
--        if usbreg_phy_mode_sync = '0' then
--          utmi_clk_ok <= '1';
--        end if;
--      end if;
--    end process usb_clk_ok_proc;

  utmi_clk_ok_clr_n <= '0' when ((clock_on = '0' and clk_off_counter = 0 ) or sys_utmi_clkin_lock = '0') else '1';

  utmi_clk_ok_clr_n_q_proc : process (testmode, usb_clk)
  begin
    if (testmode = '0') then
      utmi_clk_ok_clr_n_q <= '0';
    elsif (usb_clk'event and usb_clk = '1') then
      utmi_clk_ok_clr_n_q <= utmi_clk_ok_clr_n;
    end if;
  end process utmi_clk_ok_clr_n_q_proc;

  utmi_clk_ok_clr_n_dft <= utmi_clk_ok_clr_n_q when (testmode = '1') else utmi_clk_ok_clr_n;

  usb_clk_ok_proc : process(utmi_clk_ok_clr_n_dft, async_disable, usb_clk)
    begin
      if (utmi_clk_ok_clr_n_dft = '0' and async_disable = '0') then
        utmi_clk_ok <= '0';
      elsif(usb_clk'event and usb_clk = '1') then
        if usbreg_phy_mode_sync = '0' then
          utmi_clk_ok <= '1';
        end if;
      end if;
    end process usb_clk_ok_proc;

-- UTMI or ULPI:
dp <= utmi_linestate(0) when usbreg_phy_mode_sync = '0' else
      ulpi_linestate_lp(0) when usbreg_phy_mode_sync = '1' and ulpi_dir = '1' and ulpi_dir_s = '1' and ulpi_dir_ss = '1' else
      '0';

dm <= utmi_linestate(1) when usbreg_phy_mode_sync = '0' else
      ulpi_linestate_lp(1) when usbreg_phy_mode_sync = '1' and ulpi_dir = '1' and ulpi_dir_s = '1'and ulpi_dir_ss = '1'else
      '0';

-- ULPI Only:
ulpi_linestate_lp <= ulpi_rxdata( 1 downto 0) when ulpi_ddr_sel = '0' or dataline_low_power_en = '0' else -- ulpi linestate in Low Power Mode
                     ulpi_rxdata( 5 downto 4);

ulpi_int_lp <= ulpi_rxdata(3) when ulpi_ddr_sel = '0' and dataline_low_power_en = '1' and ulpi_dir = '1' and ulpi_dir_s = '1' and ulpi_dir_ss = '1' else -- ulpi active high interrupt in Low Power Mode
               ulpi_rxdata(7) when ulpi_ddr_sel = '1' and dataline_low_power_en = '1' and ulpi_dir = '1' and ulpi_dir_s = '1' and ulpi_dir_ss = '1' else
               '0';

awake <= pie_lowpower_n when usbreg_phy_mode_sync = '1' -- In ULPI mode, pie_low_power_n is de-asserted when device is detached from USB
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
  WAKEUP_DETECTION : process (usb_clk, usb_rst_n)
  begin
    if usb_rst_n = '0' then
      dp_s        <= '0';
      dm_s        <= '0';
      ulpi_dir_s  <= '0';
      ulpi_dir_ss <= '0';
      ulpi_dir_sss <= '0';
      ulpi_nxt_s  <= '0';
      ulpi_nxt_ss <= '0';
      ulpi_nxt_sss <= '0';
    elsif usb_clk'event and usb_clk ='1' then
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
--                          '1' when  ((clock_on = '1' or clk_off_counter /= 0 or dataline_low_power_en = '0' or pwrctrl_wakeup_int = '1') and usbreg_phy_mode_sync = '0') else
                          '1' when  ((clock_on = '1' or clk_off_counter /= 0        or pwrctrl_wakeup_int = '1') and usbreg_phy_mode_sync = '0') else
-- -------------------------------------
                          '1' when  ((clock_on = '1' or dataline_low_power_en = '0' or pwrctrl_wakeup_int = '1') and usbreg_phy_mode_sync = '1') else
                          '0';

  usb_needclk <= usb_needclk_int;

-- --ULPI OR UTMI
--  WAKEUP_STAGE : Process
--  (usb_rst_n,async_disable,clock_on,clk_off_counter,usbreg_phy_mode_sync,
--   dataline_low_power_en,ulpi_dir_sss,pie_lowpower_n,usb_clk,awake)
--  -- wake up is set asynchronously, can be reset asynchronously and synchronously if suspend_set is cleared
--  begin
--  --altera translate_off
--     if async_disable = '0' then
--  --altera translate_on
--        if usb_rst_n = '0' then
--           pwrctrl_wakeup_int <= '0';
---- -------------------------------------
---- BVE : dataline_low_power_en is only applicable in ULPI mode 
----        elsif (clock_on = '1'  and clk_off_counter = 0 and dataline_low_power_en = '1' and usbreg_phy_mode_sync = '0') or
--        elsif (clock_on = '1'  and clk_off_counter = 0 and usbreg_phy_mode_sync = '0') or
---- -------------------------------------
--              (clock_on = '1' and dataline_low_power_en = '1' and ulpi_dir_sss = '1' and usbreg_phy_mode_sync = '1') then
--           pwrctrl_wakeup_int <= '1'; -- asynch wake up is only allowed when a wake up event occurs once usb clock is OFF
--        elsif usb_clk'event and usb_clk ='1' then
--        -- wake up must be hold asserted until clock is running again and lowpower is de-asserted
--           pwrctrl_wakeup_int <= pwrctrl_wakeup_int and not awake;
--        end if;
--  --altera translate_off
--     else -- bypass asynchronous set/reset in test mode
--        if usb_clk'event and usb_clk ='1' then
--	   pwrctrl_wakeup_int <= async_disable;
--        end if;
--     end if;
--  --altera translate_on
--
--  end process  WAKEUP_STAGE;

  -- BVE : dataline_low_power_en is only applicable in ULPI mode 
  pwrctrl_wakeup_int_set_n <= '0' when (clock_on = '1' and clk_off_counter = 0 and usbreg_phy_mode_sync = '0') or
                                       (clock_on = '1' and dataline_low_power_en = '1' and ulpi_dir_sss = '1' and usbreg_phy_mode_sync = '1')  else '1';

  pwrctrl_wakeup_int_set_n_q_proc : process (testmode, usb_clk)
  begin
    if (testmode = '0') then
      pwrctrl_wakeup_int_set_n_q <= '0';
    elsif (usb_clk'event and usb_clk = '1') then
      pwrctrl_wakeup_int_set_n_q <= pwrctrl_wakeup_int_set_n;
    end if;
  end process pwrctrl_wakeup_int_set_n_q_proc;

  pwrctrl_wakeup_int_set_n_dft <= pwrctrl_wakeup_int_set_n_q when (testmode = '1') else pwrctrl_wakeup_int_set_n;

 --ULPI OR UTMI
  WAKEUP_STAGE : Process (usb_rst_n, pwrctrl_wakeup_int_set_n_dft, async_disable, usb_clk)
  -- wake up is set asynchronously, can be reset asynchronously and synchronously if suspend_set is cleared
  begin
    if usb_rst_n = '0' then
       pwrctrl_wakeup_int <= '0';
    elsif (pwrctrl_wakeup_int_set_n_dft = '0' and async_disable = '0') then
       pwrctrl_wakeup_int <= '1'; -- asynch wake up is only allowed when a wake up event occurs once usb clock is OFF
    elsif usb_clk'event and usb_clk ='1' then
    -- wake up must be hold asserted until clock is running again and lowpower is de-asserted
       pwrctrl_wakeup_int <= pwrctrl_wakeup_int and not awake;
    end if;
  end process  WAKEUP_STAGE;


  -- Only relevant for UTMI:
  utmi_suspendm     <= '1' when ((clock_on = '1') or (clk_off_counter /= 0) or pwrctrl_wakeup_int = '1') and sys_donotwakeup_n = '1'
                           else '0';

-- Only relevant for ULPI:
  ulpi_pwrctrl_wakeup <= pwrctrl_wakeup_int when sys_donotwakeup_n = '1' else '0';

  --ULPI OR UTMI



  clock_on <= '1' when (reset_needed_zz = '1' and usbreg_phy_mode_sync = '0') or
                       (usbreg_reset = '1'                                  ) or
		       (usbreg_light_reset = '1'                            ) or
		       (ulpi_int_lp = '1' and usbreg_phy_mode_sync = '1'    ) or
                       (usbreg_pll_on = '1'                                 ) or
		       (pie_lowpower_n = '1'                                ) or
                       (dp_s /= dp                                          ) or
                       (dm_s /= dm                                          ) or
		       (usbreg_woo = '1' and usb_overcurrent_n = '0'        ) or
		       (usbreg_phy_start = '1'                              )
		  else '0';

  usb_portpower <= usbreg_portpower_sync;

--fpga debug

--fpga debug
--  ip_xxx_3515_hs_fpga(255 downto 0) <=  (others => '0');
   -- synthesis read_comments_as_HDL on


  --  ip_xxx_3515_hs_fpga(63 downto 0) <=  usb_host_pie_fpga;
  --  ip_xxx_3515_hs_fpga(255 downto 64) <= (others => '0');

   -- synthesis read_comments_as_HDL off



end structure;

----------------------------------------------------------------------
LIBRARY rtl;

configuration ip_xxx_3515_hs_structure_cfg of ip_xxx_3515_hs is
  for structure
    for usb_host_pie_1: usb_host_pie
      use entity rtl.usb_host_pie(rtl);
    end for;
    for usb_host_synchronizer_1: usb_host_synchronizer
      use entity rtl.usb_host_synchronizer(rtl);
    end for;
    for usb_host_reg_if_1 : usb_host_reg_if
      use entity rtl.usb_host_reg_if(rtl);
    end for;
    for usb_host_dma_1 : usb_host_dma
      use entity rtl.usb_host_dma(rtl);
    end for;
    for usb_ahb_slave_1 : usb_ahb_slave
      use entity rtl.usb_ahb_slave(rtl);
    end for;
    for usb_host_sof_timer_1 : usb_host_sof_timer
      use entity rtl.usb_host_sof_timer(rtl);
    end for;
  end for;
end ip_xxx_3515_hs_structure_cfg;
