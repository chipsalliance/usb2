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
--               File: usb_synchronizer.m.vhdl
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
--          $Revision: 1.3 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_synchronizer.m.vhdl.rca $
--   
--    Revision: 1.3 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.18 Thu Nov  8 11:01:38 2012 beq03196
--    Fix CR#82: CR - add bits for new OTG features
--
--    Revision: 1.17 Fri Dec  2 15:55:46 2011 beq03196
--    Fix PR#68: ip_3511 : ULPI Interface: disconnect device not always detected on FPGA
--
--    Revision: 1.16 Wed Nov  9 08:58:49 2011 beq03196
--    Fix PR#48 (metastability risk in the 3511, Could break the PHY )
--
--    Revision: 1.15 Tue Oct 25 09:35:36 2011 beq03099
--    fixed problem with synchronization of sentNAK signal
--
--    Revision: 1.14 Mon Oct 24 16:58:45 2011 beq03099
--    modified endtransfer clock domain crossing to a toggle signal
--
--    Revision: 1.13 Thu Sep 15 09:51:41 2011 beq03196
--    Fix PR#41: Clocks do not restart when 3511_hs is attached to USB
--
--    Revision: 1.12 Thu Sep  8 13:51:11 2011 beq03196
--    ULPI implementation(2) + vbus valid selection (PR#39)
--
--    Revision: 1.11 Fri Aug 26 11:56:46 2011 beq03099
--    modified rxdatavalid and txdatafetched signals
--    do not extend but use toggle signals
--    This should allow the design to work at even lower AHB clock frequencies
--
--    Revision: 1.10 Tue Jun 21 09:44:57 2011 beq03099
--    added extra signal epinfo_maxpacket
--
--    Revision: 1.9 Thu Jun 16 13:56:27 2011 beq03099
--    added phy register interface
--
--    Revision: 1.8 Wed Jun 15 15:36:38 2011 beq03099
--    fixed possible synchronization problem with sentNAK signal
--
--    Revision: 1.7 Tue May 10 12:33:24 2011 beq03099
--    Added USB_DATAWIDTH generic
--
--    Revision: 1.6 Wed Feb  9 13:47:46 2011 beq03099
--    made size of rxnbytes and txnbytes configurable to support hs device
--
--    Revision: 1.5 Thu Aug  5 08:05:06 2010 beq03099
--    modified blocks to support ip_xxx_3511_compound
--
--    Revision: 1.4 Tue Jun 15 13:37:27 2010 beq03099
--    fixed typo
--
--    Revision: 1.3 Tue Jun 15 09:24:35 2010 beq03099
--    added one more synchronization stage for certain path
--
--    Revision: 1.2 Fri Jun 11 14:07:14 2010 bve
--    fixed clock domain crsosing on suspend signals
--
--    Revision: 1.1 Fri May 21 08:55:00 2010 aes
--    First check in.
--
--    Revision: 1.2 Fri Apr 23 09:21:11 2010 bve
--    fixed problem with sync_set_frameint
--
--    Revision: 1.1 Thu Apr  1 09:49:29 2010 bve
--    Initial version
--
--
--
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity  usb_synchronizer is
  generic(C_ULPI_SUPPORT   : boolean := FALSE;
          C_UTMI_SUPPORT   : boolean := TRUE;
          USB_DATAWIDTH    : integer := 8;
          TXNBYTES_BITS    : integer := 10;
          RXNBYTES_BITS    : integer := 11;
          C_NBDEV          : integer := 1);
  port  (
          ----- To/From usb clock domain ------------------------
          sieint_epinfo_req      : in  std_logic; --sync signal
          sieint_epinfo_epnr     : in  std_logic_vector(3 downto 0);
          sieint_epinfo_epdir    : in  std_logic;
          sieint_epinfo_setup    : in  std_logic;
          epinfo_valid           : out std_logic; --sync signal
          sieint_epinfo_setup_received    : in  std_logic;

          epinfo_active          : out std_logic;
          epinfo_disabled        : out std_logic;
          epinfo_toggle          : out std_logic;
          epinfo_stall           : out std_logic;
          epinfo_iso             : out std_logic;
          epinfo_ratefeedbackmode: out std_logic;
          epinfo_nbytes          : out std_logic_vector(TXNBYTES_BITS-1 downto 0);
          epinfo_maxpacket       : out std_logic_vector(1 downto 0);

          sieint_txdatafetched   : in  std_logic; --sync signal
          epinfo_txdata          : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
          epinfo_txdata_valid    : out std_logic; --sync signal

          sieint_rx_nbytes       : in  std_logic_vector(RXNBYTES_BITS-1 downto 0);
          sieint_rxdata          : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
          sieint_rxdatavalid     : in  std_logic; --sync signal

          sieint_endtransfer     : in  std_logic; --sync signal
          sieint_success         : in  std_logic; -- can this be combined with error ?
          sieint_error           : in  std_logic;
          sieint_errortype       : in  std_logic_vector(3 downto 0);
          sieint_sentNAK         : in  std_logic;
          VBusDebounced          : in  std_logic;
          pie_lowpower_n         : in  std_logic;
          vbuscomp_on            : out std_logic; -- Enable Analog Vbus comparators
          chrg_vbus              : out std_logic;
          dischrg_vbus           : out std_logic;
          avalid                 : in  std_logic; -- ADPPROBE
          sessend                : in  std_logic; -- ADPSENSE

          TM_IsoToggle           : in  integer range 0 to 1;
          RG_BUSReset            : in  boolean;
          TM_Suspend             : in  boolean;
          LPM_TM_Suspend         : in  boolean;
          LPM_RW                 : in  boolean;

          phy_addr               : out std_logic_vector(7 downto 0);
          phy_wdata              : out std_logic_vector(7 downto 0);
          phy_rdata              : in  std_logic_vector(7 downto 0);
          phy_write              : out std_logic;
          phy_start              : out std_logic;
          phy_mode               : out std_logic;
          phy_endtoggle          : in  std_logic;

          sync_usbreg_phy_test_mode_change  : out std_logic;
          sync_usbreg_dev_connect     : out std_logic;
          sync_usbreg_remotewakeup    : out std_logic;
          sync_usbreg_lpmremotewakeup : out std_logic;

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
          sync_sieint_epinfo_req     : out std_logic; --sync signal
          sync_sieint_epinfo_epnr    : out std_logic_vector(3 downto 0);
          sync_sieint_epinfo_epdir   : out std_logic;
          sync_sieint_epinfo_setup   : out std_logic;
          sync_sieint_setup_received : out std_logic; -- single pulse
          sync_VBusDebounced         : out std_logic; -- sync signal
          usbreg_vbuscomp_on         : in  std_logic; -- Enable Analog Vbus comparators
          usbreg_chrg_vbus           : in  std_logic;
          usbreg_dischrg_vbus        : in  std_logic;
          sync_avalid                : out std_logic; -- ADPPROBE
          sync_sessend               : out std_logic; -- ADPSENSE

          epinfo_sync_valid          : in  std_logic; --sync signal
          epinfo_sync_active         : in  std_logic;
          epinfo_sync_disabled       : in  std_logic;
          epinfo_sync_toggle         : in  std_logic;
          epinfo_sync_stall          : in  std_logic;
          epinfo_sync_iso            : in  std_logic;
          epinfo_sync_ratefeedbackmode:in  std_logic;
          epinfo_sync_nbytes         : in  std_logic_vector(TXNBYTES_BITS-1 downto 0);
          epinfo_sync_maxpacket      : in  std_logic_vector(1 downto 0);

          sync_sieint_txdatafetched  : out std_logic; --sync signal
          epinfo_sync_txdata         : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
          epinfo_sync_txdata_valid   : in  std_logic; --sync signal

          sync_sieint_rx_nbytes      : out std_logic_vector(RXNBYTES_BITS-1 downto 0);
          sync_sieint_rxdata         : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
          sync_sieint_rxdatavalid    : out std_logic; --sync signal

          sync_sieint_endtransfer    : out std_logic; --sync signal
          sync_sieint_success        : out std_logic; --can this be combined with error ?
          sync_sieint_error          : out std_logic;
          sync_sieint_errortype      : out std_logic_vector(3 downto 0);
          sync_sieint_sentNAK        : out std_logic;

          sync_set_frameint          : out std_logic;
          sync_busreset              : out std_logic;
          sync_suspend               : out std_logic;
          sync_lpm_suspend           : out std_logic;
          sync_lpm_rw                : out std_logic;

          usbreg_phy_addr            : in  std_logic_vector(7 downto 0);
          usbreg_phy_wdata           : in  std_logic_vector(7 downto 0);
          sync_phy_rdata             : out std_logic_vector(7 downto 0);
          usbreg_phy_write           : in  std_logic;
          usbreg_phy_start           : in  std_logic;
          usbreg_phy_mode            : in  std_logic;
          sync_phy_endtoggle         : out std_logic;

          usbreg_phy_test_mode       : in  std_logic_vector(2 downto 0);
          usbreg_dev_connect         : in  std_logic;
          usbreg_remotewakeup        : in  std_logic;
          usbreg_lpmremotewakeup     : in  std_logic;

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
          FsClk                      : in  std_logic; -- Recovered Clock
          Reset_N                    : in  std_logic; -- Global Reset
          hclk                       : in  std_logic;
          hrstn                      : in  std_logic

        );
end usb_synchronizer;

architecture RTL of usb_synchronizer is

signal sieint_rxdatavalid_toggle                                   : std_logic;
signal sieint_txdatafetched_toggle                                 : std_logic;
signal epinfo_valid_s, epinfo_valid_ss                             : std_logic;
signal sync_sieint_epinfo_req_s, sync_sieint_epinfo_req_ss         : std_logic;
signal sync_sieint_epinfo_req_sss                                  : std_logic;
signal epinfo_txdata_valid_s, epinfo_txdata_valid_ss               : std_logic;
signal sync_sieint_txdatafetched_s, sync_sieint_txdatafetched_ss   : std_logic;
signal sync_sieint_txdatafetched_sss                               : std_logic;
signal sync_sieint_rxdatavalid_s, sync_sieint_rxdatavalid_ss       : std_logic;
signal sync_sieint_rxdatavalid_sss                                 : std_logic;
signal sync_sieint_endtransfer_s, sync_sieint_endtransfer_ss       : std_logic;
signal sync_sieint_endtransfer_sss                                 : std_logic;
signal sieint_endtransfer_s,sieint_endtransfer_toggle              : std_logic;
signal sync_sieint_setup_received_s, sync_sieint_setup_received_ss : std_logic;
signal sync_sieint_setup_received_sss                              : std_logic;
signal sync_sieint_error_s, sync_sieint_error_ss                   : std_logic;
signal sync_isotoggle_s,sync_isotoggle_ss                          : std_logic;
signal sync_isotoggle_sss                                          : std_logic;
signal sync_busreset_s,sync_busreset_ss                            : std_logic;
signal sync_busreset_sss                                           : std_logic;
signal sync_suspend_s,sync_suspend_ss                              : std_logic;
signal sync_lpm_suspend_s,sync_lpm_suspend_ss                      : std_logic;
signal sync_lpm_rw_s,sync_lpm_rw_ss                                : std_logic;
signal sync_phy_start_s, sync_phy_start_ss, sync_phy_start_sss     : std_logic;
signal sync_phy_endtoggle_s, sync_phy_endtoggle_ss, sync_phy_endtoggle_sss : std_logic;
signal sync_VBusDebounced_s, sync_VBusDebounced_ss      : std_logic;
signal sync_avalid_s, sync_avalid_ss      : std_logic;
signal sync_sessend_s, sync_sessend_ss      : std_logic;
signal usbreg_dev_connect_s,usbreg_dev_connect_ss : std_logic;
signal usbreg_remotewakeup_s, usbreg_remotewakeup_ss : std_logic;
signal usbreg_lpmremotewakeup_s, usbreg_lpmremotewakeup_ss : std_logic;
signal usbreg_phy_test_mode_s : std_logic_vector(2 downto 0);
signal usbreg_phy_test_mode_toggle_s,usbreg_phy_test_mode_toggle_ss,usbreg_phy_test_mode_toggle_sss : std_logic;
signal usbreg_phy_test_mode_toggle : std_logic;
signal sync_pie_lowpower_n_s  : std_logic;
signal sync_pie_lowpower_n_ss : std_logic;
signal sync_vbuscomp_on_s,sync_vbuscomp_on_ss : std_logic;

signal LPM_TM_Suspend_s  : boolean;
signal TM_Suspend_s      : boolean;
signal pie_lowpower_n_s  : std_logic;


begin

  proc_sync_usb : process (FsClk, Reset_N)
  begin
    if Reset_N = '0' then

      epinfo_valid_s         <= '0';
      epinfo_valid_ss        <= '0';

      epinfo_txdata_valid_s  <= '0';
      epinfo_txdata_valid_ss <= '0';

      sieint_rxdatavalid_toggle   <= '0';
      sieint_txdatafetched_toggle <= '0';
      sieint_endtransfer_s        <= '0';
      sieint_endtransfer_toggle   <= '0';

      if (C_ULPI_SUPPORT or C_UTMI_SUPPORT) then
        sync_phy_start_s     <= '0';
        sync_phy_start_ss    <= '0';
        sync_phy_start_sss   <= '0';
      end if;

      usbreg_dev_connect_s <= '0';
      usbreg_dev_connect_ss <= '0';

      usbreg_remotewakeup_s <= '0';
      usbreg_remotewakeup_ss <= '0';

      usbreg_lpmremotewakeup_s <= '0';
      usbreg_lpmremotewakeup_ss <= '0';

      usbreg_phy_test_mode_toggle_s <= '0';
      usbreg_phy_test_mode_toggle_ss <= '0';
      usbreg_phy_test_mode_toggle_sss <= '0';
      
      sync_vbuscomp_on_s   <= '1';
      sync_vbuscomp_on_ss  <= '1';
      LPM_TM_Suspend_s     <= false;
      TM_Suspend_s         <= false;
      pie_lowpower_n_s     <= '1';


    elsif FsClk'event and FsClk = '1' then
      epinfo_valid_s         <= epinfo_sync_valid;
      epinfo_valid_ss        <= epinfo_valid_s;

      epinfo_txdata_valid_s  <= epinfo_sync_txdata_valid;
      epinfo_txdata_valid_ss <= epinfo_txdata_valid_s;

      if sieint_rxdatavalid = '1' then
        sieint_rxdatavalid_toggle  <= not(sieint_rxdatavalid_toggle);
      end if;
      if sieint_txdatafetched = '1' then
        sieint_txdatafetched_toggle <= not(sieint_txdatafetched_toggle);
      end if;

      sieint_endtransfer_s <= sieint_endtransfer;
      if sieint_endtransfer = '1' and sieint_endtransfer_s = '0' then
        sieint_endtransfer_toggle  <= not(sieint_endtransfer_toggle);
      end if;

      if (C_ULPI_SUPPORT or C_UTMI_SUPPORT) then
        sync_phy_start_s     <= usbreg_phy_start;
        sync_phy_start_ss    <= sync_phy_start_s;
        sync_phy_start_sss   <= sync_phy_start_ss;
      end if;

      usbreg_dev_connect_s <= usbreg_dev_connect;
      usbreg_dev_connect_ss <= usbreg_dev_connect_s;

      usbreg_remotewakeup_s <= usbreg_remotewakeup;
      usbreg_remotewakeup_ss <= usbreg_remotewakeup_s;

      usbreg_lpmremotewakeup_s <= usbreg_lpmremotewakeup;
      usbreg_lpmremotewakeup_ss <= usbreg_lpmremotewakeup_s;

      usbreg_phy_test_mode_toggle_s <= usbreg_phy_test_mode_toggle;
      usbreg_phy_test_mode_toggle_ss <= usbreg_phy_test_mode_toggle_s;
      usbreg_phy_test_mode_toggle_sss <= usbreg_phy_test_mode_toggle_ss;
      
      sync_vbuscomp_on_s   <= usbreg_vbuscomp_on;
      sync_vbuscomp_on_ss  <= sync_vbuscomp_on_s;
      LPM_TM_Suspend_s     <= LPM_TM_Suspend;
      TM_Suspend_s         <= TM_Suspend;
      pie_lowpower_n_s     <= pie_lowpower_n;

    end if;
  end process proc_sync_usb;

-- extend sieint_rxdatavalid and sieint_txdatafetched by one FsClk
-- to be sure that rising edge can be detected in hclk clock domain
--  sieint_rxdatavalid_extended   <= sieint_rxdatavalid   or sieint_rxdatavalid_s;
--  sieint_txdatafetched_extended <= sieint_txdatafetched or sieint_txdatafetched_s;

  proc_sync_ahb : process (hclk, hrstn)
  begin
    if hrstn = '0' then
      sync_sieint_epinfo_req_s      <= '0';
      sync_sieint_epinfo_req_ss     <= '0';
      sync_sieint_epinfo_req_sss    <= '0';

      sync_sieint_txdatafetched_s   <= '0';
      sync_sieint_txdatafetched_ss  <= '0';
      sync_sieint_txdatafetched_sss <= '0';

      sync_sieint_rxdatavalid_s     <= '0';
      sync_sieint_rxdatavalid_ss    <= '0';
      sync_sieint_rxdatavalid_sss   <= '0';

      sync_sieint_endtransfer_s     <= '0';
      sync_sieint_endtransfer_ss    <= '0';
      sync_sieint_endtransfer_sss   <= '0';

      sync_sieint_setup_received_s  <= '0';
      sync_sieint_setup_received_ss <= '0';
      sync_sieint_setup_received_sss<= '0';

      sync_sieint_error_s           <= '0';
      sync_sieint_error_ss          <= '0';

      sync_isotoggle_s              <= '0';
      sync_isotoggle_ss             <= '0';
      sync_isotoggle_sss            <= '0';

      sync_busreset_s               <= '0';
      sync_busreset_ss              <= '0';
      sync_busreset_sss             <= '0';

      sync_suspend_s                <= '0';
      sync_suspend_ss               <= '0';

      sync_lpm_suspend_s            <= '0';
      sync_lpm_suspend_ss           <= '0';

      sync_lpm_rw_s                 <= '0';
      sync_lpm_rw_ss                <= '0';

      sync_VBusDebounced_s           <= '0';
      sync_VBusDebounced_ss          <= '0';
      sync_avalid_s          <= '0';
      sync_avalid_ss         <= '0';
      sync_sessend_s         <= '0';
      sync_sessend_ss        <= '0';
      sync_pie_lowpower_n_s  <= '0';
      sync_pie_lowpower_n_ss <= '0';

      if (C_ULPI_SUPPORT or C_UTMI_SUPPORT) then
        sync_phy_endtoggle_s   <= '0';
        sync_phy_endtoggle_ss  <= '0';
        sync_phy_endtoggle_sss <= '0';
      end if;

      usbreg_phy_test_mode_s <= (others => '0');
      usbreg_phy_test_mode_toggle <= '0';

    elsif hclk'event and hclk = '1' then

      sync_VBusDebounced_s          <= VBusDebounced;
      sync_VBusDebounced_ss         <= sync_VBusDebounced_s;

      -- this will delay the info to usb_reg_if of one pie_clk 60 MHz (which should not be critical)
      sync_pie_lowpower_n_s  <= pie_lowpower_n_s;
      sync_pie_lowpower_n_ss <= sync_pie_lowpower_n_s;
      if sync_pie_lowpower_n_ss = '1' then
      -- vbus comparator signals are not available while phy is put into suspend. These signals need to be masked
         sync_avalid_s   <= avalid;
         sync_avalid_ss  <= sync_avalid_s;
         sync_sessend_s  <= sessend;
         sync_sessend_ss <= sync_sessend_s;
      end if;

      sync_sieint_epinfo_req_s      <= sieint_epinfo_req;
      sync_sieint_epinfo_req_ss     <= sync_sieint_epinfo_req_s;
      sync_sieint_epinfo_req_sss    <= sync_sieint_epinfo_req_ss;

      sync_sieint_txdatafetched_s   <= sieint_txdatafetched_toggle;
      sync_sieint_txdatafetched_ss  <= sync_sieint_txdatafetched_s;
      sync_sieint_txdatafetched_sss <= sync_sieint_txdatafetched_ss;

      sync_sieint_rxdatavalid_s     <= sieint_rxdatavalid_toggle;
      sync_sieint_rxdatavalid_ss    <= sync_sieint_rxdatavalid_s;
      sync_sieint_rxdatavalid_sss   <= sync_sieint_rxdatavalid_ss;

      sync_sieint_endtransfer_s     <= sieint_endtransfer_toggle;
      sync_sieint_endtransfer_ss    <= sync_sieint_endtransfer_s;
      sync_sieint_endtransfer_sss   <= sync_sieint_endtransfer_ss;

      sync_sieint_setup_received_s  <= sieint_epinfo_setup_received;
      sync_sieint_setup_received_ss <= sync_sieint_setup_received_s;
      sync_sieint_setup_received_sss<= sync_sieint_setup_received_ss;

      sync_sieint_error_s           <= sieint_error;
      sync_sieint_error_ss          <= sync_sieint_error_s;

      if TM_ISOToggle = 0 then
        sync_isotoggle_s            <= '0';
      else
        sync_isotoggle_s            <= '1';
      end if;
      sync_isotoggle_ss             <= sync_isotoggle_s;
      sync_isotoggle_sss            <= sync_isotoggle_ss;

      if RG_BUSReset then
        sync_busreset_s             <= '1';
      else
        sync_busreset_s             <= '0';
      end if;
      sync_busreset_ss              <= sync_busreset_s;
      sync_busreset_sss             <= sync_busreset_ss;

      if TM_Suspend_s then
        sync_suspend_s             <= '1';
      else
        sync_suspend_s             <= '0';
      end if;
      sync_suspend_ss              <= sync_suspend_s;

      if LPM_TM_Suspend_s then
        sync_lpm_suspend_s         <= '1';
      else
        sync_lpm_suspend_s         <= '0';
      end if;
      sync_lpm_suspend_ss          <= sync_lpm_suspend_s;

      if LPM_RW then
        sync_lpm_rw_s         <= '1';
      else
        sync_lpm_rw_s         <= '0';
      end if;
      sync_lpm_rw_ss          <= sync_lpm_rw_s;

      if (C_ULPI_SUPPORT or C_UTMI_SUPPORT) then
        sync_phy_endtoggle_s        <= phy_endtoggle;
        sync_phy_endtoggle_ss       <= sync_phy_endtoggle_s;
        sync_phy_endtoggle_sss      <= sync_phy_endtoggle_ss;
      end if;

      usbreg_phy_test_mode_s <= usbreg_phy_test_mode;
      if usbreg_phy_test_mode_s /= usbreg_phy_test_mode then -- phy_test_mode has changed
         usbreg_phy_test_mode_toggle <= not usbreg_phy_test_mode_toggle;
      end if;

    end if;
  end process proc_sync_ahb;

  epinfo_valid             <= epinfo_valid_ss;


  sync_sieint_epinfo_req   <= '1' when (sync_sieint_epinfo_req_ss   = '1') and
                                       (sync_sieint_epinfo_req_sss  = '0') else
                              '0';

  epinfo_txdata_valid      <= epinfo_txdata_valid_ss;
  sync_sieint_txdatafetched<= '1' when (sync_sieint_txdatafetched_ss /=
                                        sync_sieint_txdatafetched_sss     ) else
                              '0';

  sync_sieint_rxdatavalid  <= '1' when (sync_sieint_rxdatavalid_ss   /=
                                        sync_sieint_rxdatavalid_sss       ) else
                              '0';

  sync_sieint_endtransfer  <= '1' when (sync_sieint_endtransfer_ss   /=
                                        sync_sieint_endtransfer_sss       ) else
                              '0';

  sync_sieint_epinfo_epnr  <= sieint_epinfo_epnr;
  sync_sieint_epinfo_epdir <= sieint_epinfo_epdir;
  sync_sieint_epinfo_setup <= sieint_epinfo_setup;

  sync_sieint_setup_received <= '1' when (sync_sieint_setup_received_ss  = '1') and
                                         (sync_sieint_setup_received_sss = '0') else
                                '0';

  epinfo_active            <= epinfo_sync_active;
  epinfo_disabled          <= epinfo_sync_disabled;
  epinfo_toggle            <= epinfo_sync_toggle;
  epinfo_stall             <= epinfo_sync_stall;
  epinfo_iso               <= epinfo_sync_iso;
  epinfo_ratefeedbackmode  <= epinfo_sync_ratefeedbackmode;
  epinfo_nbytes            <= epinfo_sync_nbytes;
  epinfo_maxpacket         <= epinfo_sync_maxpacket;

  epinfo_txdata            <= epinfo_sync_txdata;

  sync_sieint_rx_nbytes    <= sieint_rx_nbytes;
  sync_sieint_rxdata       <= sieint_rxdata;

  sync_VBusDebounced       <= sync_VBusDebounced_ss;
  sync_avalid              <= sync_avalid_ss;
  sync_sessend             <= sync_sessend_ss;
  vbuscomp_on              <= sync_vbuscomp_on_ss; 
  chrg_vbus                <= usbreg_chrg_vbus; -- no needed resynchronization as almost static signal.
  dischrg_vbus             <= usbreg_dischrg_vbus; -- no needed resynchronization as almost static signal.

  sync_sieint_success   <= sieint_success;
  sync_sieint_error     <= sync_sieint_error_ss;
  sync_sieint_errortype <= sieint_errortype;
  sync_sieint_sentNAK   <= '1' when (sieint_sentNAK = '1')           and
                                    (sync_sieint_endtransfer_ss /=
                                     sync_sieint_endtransfer_sss   ) else
                           '0';

  sync_set_frameint     <= '1' when sync_isotoggle_ss  /=
                                    sync_isotoggle_sss else
                           '0';
  sync_busreset         <= '1' when (sync_busreset_ss  = '1') and
                                    (sync_busreset_sss = '0') else
                           '0';
  sync_suspend          <= sync_suspend_ss;
  sync_lpm_suspend      <= sync_lpm_suspend_ss;
  sync_lpm_rw           <= sync_lpm_rw_ss;

  phy_addr              <= usbreg_phy_addr;
  phy_wdata             <= usbreg_phy_wdata;
  sync_phy_rdata        <= phy_rdata;
  phy_write             <= usbreg_phy_write;
  phy_start             <= '1' when (C_ULPI_SUPPORT or C_UTMI_SUPPORT) and
                                    (sync_phy_start_ss  = '1')         and
                                       (sync_phy_start_sss = '0') else
                           '0';
  phy_mode              <= usbreg_phy_mode;
  sync_phy_endtoggle    <= '1' when (C_ULPI_SUPPORT or C_UTMI_SUPPORT) and
                                       (sync_phy_endtoggle_ss  /=
                                        sync_phy_endtoggle_sss) else
                              '0';
  sync_usbreg_dev_connect  <= usbreg_dev_connect_ss;
  sync_usbreg_remotewakeup <= usbreg_remotewakeup_ss;
  sync_usbreg_lpmremotewakeup <= usbreg_lpmremotewakeup_ss;

  sync_usbreg_phy_test_mode_change <= '1' when usbreg_phy_test_mode_toggle_ss /= usbreg_phy_test_mode_toggle_sss else '0';

  -- <<< LAB to review those ones!!!

  sync_usbreg_pll_on      <= usbreg_pll_on;
  sync_usbreg_lpm_sup     <= usbreg_lpm_sup;
  sync_usbreg_lpm_hird_sw <= usbreg_lpm_hird_sw;
  sync_usbreg_lpm_nyet    <= usbreg_lpm_nyet; 

  sync_pie_speed          <= pie_speed;
  sync_sieint_lpm_hird_hw <= sieint_lpm_hird_hw;
  sync_usbreg_frame_number<= usbreg_frame_number;
  sync_pie_dev_selected   <= pie_dev_selected;

end RTL;
