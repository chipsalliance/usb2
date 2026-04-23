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
--               File: usb_fs_reg_if.m.vhdl
--
--             Author: Alexandre Esquenet
--
--       Organisation: Corporate I&T / IP & Architecture
--
--              $Date: Sun Apr 23 19:20:43 2017 $
--
--            Project: IP_3515 - Low gate count USB Host IP
--
--        Description:
--
--          $Revision: 1.8 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_host_reg_if.m.vhdl.rca $
--   
--    Revision: 1.8 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--
--    Revision: 1.35 Thu Dec 13 11:37:00 2012 beq03196
--    add USB_OTG register for the ip_3516_hs
--
--    Revision: 1.34 Tue May 22 15:11:16 2012 beq03099
--    fix for PR52
--    set suspend bit when ACK is received on LPM token
--
--    Revision: 1.33 Thu May 10 15:39:48 2012 beq03067
--    set back usbreg_woo
--
--    Revision: 1.32 Thu May 10 15:35:38 2012 beq03067
--    removed woo output
--
--    Revision: 1.31 Tue May  8 15:41:38 2012 beq03067
--    clear suspend bit in case in case the device is de-attached.
--
--    Revision: 1.30 Mon May  7 14:21:49 2012 beq03067
--    suspend bit not cleared immediately when resume bit is cleared,
--    depends on pie feedback for both l1/l2 suspend mode.
--
--    Revision: 1.29 Mon May  7 09:48:49 2012 beq03067
--    clear suspend indication on end of resume.
--
--    Revision: 1.28 Fri Apr 20 15:08:00 2012 beq03067
--    Fixed pll_on mistake.
--
--    Revision: 1.27 Fri Apr 20 09:00:35 2012 beq03067
--    fixed sensitivity list.
--
--    Revision: 1.26 Thu Apr 12 14:02:28 2012 beq03099
--    Finished LPM implementation
--
--    Revision: 1.25 Thu Apr 12 07:38:46 2012 beq03099
--    modified register interface according to v0.7.0 of the architecture spec
--
--    Revision: 1.24 Mon Mar 19 10:05:02 2012 beq03099
--    Fixed FLR interrupt generation
--
--    Revision: 1.23 Tue Mar 13 11:58:50 2012 beq03067
--    Moved frindex from register 0x20 to 0x0C as specified in hte architecture v0.6
--
--    Revision: 1.22 Mon Mar 12 09:52:46 2012 beq03196
--    width of test mode bus can be reduced to 3 bits
--
--    Revision: 1.21 Fri Mar  9 15:10:57 2012 beq03099
--    reset bit must be cleared if portconnect is zero
--
--    Revision: 1.20 Fri Mar  9 12:25:40 2012 beq03067
--    bring debug signals without comments
--
--    Revision: 1.19 Fri Mar  9 11:45:07 2012 beq03099
--    added pie_devicespeed to synchronizer
--
--    Revision: 1.18 Wed Mar  7 11:30:12 2012 beq03067
--    reset sof_irq_e on sw reset
--
--    Revision: 1.17 Tue Mar  6 11:43:41 2012 beq03067
--    Changes after first review.
--
--    Revision: 1.16 Mon Mar  5 11:41:41 2012 beq03067
--    usbreg_fladj_change changed from pulse to toogle
--
--    Revision: 1.15 Fri Mar  2 09:15:09 2012 beq03339
--    Corrected FLR interrupt and writing to FLS field
--
--    Revision: 1.14 Fri Mar  2 07:40:55 2012 beq03099
--    fixed problem with reg_phy_mode
--
--    Revision: 1.13 Tue Feb 28 13:54:54 2012 beq03099
--    fixed issue with Port Reset bit
--
--    Revision: 1.12 Fri Feb 24 10:07:49 2012 beq03099
--    Added SOF interrupt
--
--    Revision: 1.11 Tue Feb 21 14:18:46 2012 beq03099
--    fixed problem with LineStatus field
--    The bit order of this field is different from pie_linestate order
--
--    Revision: 1.10 Fri Feb 17 12:32:51 2012 beq03099
--    added/removed interface signals
--
--    Revision: 1.9 Tue Feb  7 11:20:59 2012 beq03067
--    fpga signal
--
--    Revision: 1.8 Thu Feb  2 15:30:49 2012 beq03099
--    fixed softreset values and interrupt generation
--
--    Revision: 1.7 Thu Feb  2 10:46:37 2012 beq03099
--    usbreg_phymode must be fixed to 1b if ULPI_SUPPORT is true and
--    UTMI_SUPPORT is false
--
--    Revision: 1.6 Wed Feb  1 15:36:35 2012 beq03099
--    fixed compilation errors reported by ncsim
--
--    Revision: 1.5 Wed Feb  1 14:47:18 2012 beq03099
--    added signal dma_atl_setptd
--
--    Revision: 1.4 Wed Feb  1 13:59:47 2012 beq03067
--    Added clear of reset bits.
--
--    Revision: 1.3 Wed Feb  1 12:13:41 2012 beq03067
--    added generic addr
--
--    Revision: 1.2 Tue Jan 31 15:13:39 2012 beq03067
--    Added port enable control
--
--    Revision: 1.1 Tue Jan 31 14:45:58 2012 beq03067
--    First check in.
--
--
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

--library rtl;
--use rtl.usb_configuration_subcmp_pkg.all;

entity usb_host_reg_if is
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
      reg_waddr : in  std_logic_vector(AHB_SLAVE_ADDR_WIDTH+1 downto 2);
      reg_wdata : in  std_logic_vector(31 downto 0);
      reg_raddr : in  std_logic_vector(AHB_SLAVE_ADDR_WIDTH+1 downto 2);
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
      usbreg_port_force_fullspeed : out std_logic;
      --------------------------------
      --To/From usb_host_synchronizer module
      --------------------------------
      usbreg_fladj                : out std_logic_vector(5 downto 0); -- FLADJ register field
      -- This signal toggles every time if the FLADJ register field is written
      usbreg_fladj_change         : out std_logic;
      usbreg_run                  : out std_logic; -- Run/stop register bit
      usbreg_reset                : out std_logic; -- hcreset register bit
      usbreg_light_reset          : out std_logic; -- lhcr register bit
      -- A pulse on this line will clear the hcreset and lhcr bit.
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
      -- A single cycle pulse that indicates to set the atl_irq bit
      dma_atl_setint       : in  std_logic;
      -- A single cycle pulse that indicates to set the iso_irq bit
      dma_iso_setint       : in  std_logic;
      -- A single cycle pulse that indicates to set the int_irq bit
      dma_int_setint       : in  std_logic;
      -- A single cycle pulse will set the atl_done bit indicated by dma_current_ptd
      dma_atl_setdone      : in  std_logic;
      -- A single cycle pulse will set the iso_done bit indicated by dma_current_ptd
      dma_iso_setdone      : in  std_logic;
      -- A single cycle pulse will set the int_done bit indicated by dma_current_ptd
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
      -- To toplevel   --
      -------------------
      usbreg_woo 	   : out std_logic

      );
end usb_host_reg_if;

architecture RTL of usb_host_reg_if is
  constant CAPLENGTH : std_logic_vector(7 downto 0) := "00010000"; --0x10
  constant CHIPID    : std_logic_vector(31 downto 16) := C_MAJOR_REV & C_MINOR_REV;
  constant N_PORTS   : std_logic_vector(3 downto 0) := "0001"; --0x1
  constant DPN       : std_logic_vector(23 downto 20) := "0000";
  constant PFLF      : std_logic := '1';
  constant ASPC      : std_logic := '1';
  constant LPMC      : std_logic := '1';

  signal ULPI_SUPPORT             : std_logic;
  signal UTMI_SUPPORT             : std_logic;
  signal PPC                      : std_logic;
  signal P_INDICATOR              : std_logic;
  signal usb_int_req_irq_int      : std_logic;
  signal usb_portindicator_int    : std_logic_vector(1 downto 0);
  signal reg_rdata_int            : std_logic_vector(31 downto 0);
  signal usbreg_phy_test_mode_int : std_logic_vector(3 downto 0);
  signal usbreg_fladj_int         : std_logic_vector(5 downto 0);
  signal usbreg_fladj_change_int  : std_logic;
  signal usbreg_run_int           : std_logic;
  signal usbreg_reset_int         : std_logic;
  signal usbreg_light_reset_int   : std_logic;
  signal usbreg_portresume_int    : std_logic;
  signal usbreg_portreset_int     : std_logic;
  signal usbreg_portsuspend_int   : std_logic;
  signal usbreg_portpower_int     : std_logic;
  signal usbreg_phy_addr_int      : std_logic_vector(7 downto 0);
  signal usbreg_phy_wdata_int     : std_logic_vector(7 downto 0);
  signal usbreg_phy_write_int     : std_logic;
  signal usbreg_phy_start_int     : std_logic;
  signal usbreg_phy_mode_int      : std_logic;
  signal usbreg_atl_base_int      : std_logic_vector(22 downto 0);
  signal usbreg_atl_cur_ptd_int   : std_logic_vector(4 downto 0);
  signal usbreg_iso_base_int      : std_logic_vector(21 downto 0);
  signal usbreg_iso_first_ptd_int : std_logic_vector(4 downto 0);
  signal usbreg_int_base_int      : std_logic_vector(21 downto 0);
  signal usbreg_int_first_ptd_int : std_logic_vector(4 downto 0);
  signal usbreg_payload_base_int  : std_logic_vector(15 downto 0);
  signal usbreg_frindex_int       : unsigned(13 downto 0);
  signal usbreg_atl_enable_int    : std_logic;
  signal usbreg_iso_enable_int    : std_logic;
  signal usbreg_int_enable_int    : std_logic;
  signal usbreg_atl_skip_int      : std_logic_vector(31 downto 0);
  signal usbreg_iso_skip_int      : std_logic_vector(31 downto 0);
  signal usbreg_int_skip_int      : std_logic_vector(31 downto 0);
  signal usbreg_atl_last_int      : std_logic_vector(4 downto 0);
  signal usbreg_iso_last_int      : std_logic_vector(4 downto 0);
  signal usbreg_int_last_int      : std_logic_vector(4 downto 0);
  signal usbreg_fls_int           : std_logic_vector(3 downto 2);
  signal usbreg_id_en_int         : std_logic;
  signal usbreg_sw_ctrl_pdcom_int : std_logic;
  signal usbreg_sw_pdcom_int      : std_logic;
  signal usbreg_dev_en_int        : std_logic;
  signal pcd                      : std_logic;
  signal flr                      : std_logic;
  signal atl_irq                  : std_logic;
  signal iso_irq                  : std_logic;
  signal int_irq                  : std_logic;
  signal sof_irq                  : std_logic;
  signal pcde                     : std_logic;
  signal flre                     : std_logic;
  signal atl_irq_e                : std_logic;
  signal iso_irq_e                : std_logic;
  signal int_irq_e                : std_logic;
  signal sof_irq_e                : std_logic;
  signal pie_portconnect_sync_z   : std_logic;
  signal csc                      : std_logic;
  signal csc_z                    : std_logic;
  signal pie_portenable_sync_z    : std_logic;
  signal pedc                     : std_logic;
  signal pedc_z                   : std_logic;
  signal usb_overcurrent_sync_z   : std_logic;
  signal occ                      : std_logic;
  signal occ_z                    : std_logic;
  signal id_value_sync_z          : std_logic;
  signal id_value_sync_zz         : std_logic;
  signal atl_done                 : std_logic_vector(31 downto 0);
  signal iso_done                 : std_logic_vector(31 downto 0);
  signal int_done                 : std_logic_vector(31 downto 0);
  signal phy_rdata_int            : std_logic_vector(23 downto 16);
  signal usbreg_portenable_clear_i: std_logic;
  signal reg_portreset            : std_logic;
  signal usbreg_woo_int           : std_logic;
  signal usbreg_lpm_hird_int      : std_logic_vector(3 downto 0);
  signal usbreg_lpm_bremotewakeup_int : std_logic;
  signal usbreg_lpm_addr_int      : std_logic_vector(6 downto 0);
  signal usbreg_lpm_susp_l1_on_int: std_logic;
  signal usbreg_pll_on_int        : std_logic;
  signal usbreg_port_force_fullspeed_int : std_logic;



begin

  PPC                          <= '1' when C_PORTPOWER_CONTROL = TRUE else '0';
  P_INDICATOR                  <= '1' when C_PORTINDICATOR = TRUE else '0';
  ULPI_SUPPORT                 <= '1' when C_ULPI_SUPPORT = TRUE else '0';
  UTMI_SUPPORT                 <= '1' when C_UTMI_SUPPORT = TRUE else '0';

  ------------------------
  -- Register read proc --
  ------------------------

  proc_reg_rdata : process (
                           reg_raddr, PPC, P_INDICATOR, usbreg_fladj_int, usbreg_atl_cur_ptd_int, usbreg_atl_base_int,
                           usbreg_iso_first_ptd_int, usbreg_iso_base_int, usbreg_int_first_ptd_int, usbreg_int_base_int,
                           usbreg_payload_base_int, usbreg_run_int, usbreg_reset_int, usbreg_fls_int, usbreg_light_reset_int,
                           usbreg_atl_enable_int, usbreg_iso_enable_int, usbreg_int_enable_int,
                           usbreg_frindex_int, pcd, flr, atl_irq, iso_irq, int_irq, sof_irq, pcde, flre, atl_irq_e, iso_irq_e, int_irq_e,
			   sof_irq_e, pie_portconnect_sync, csc, pie_portenable_sync, pedc, usb_overcurrent_sync, occ,
			   usbreg_portresume_int, usbreg_portsuspend_int, reg_portreset, pie_linestate_sync, usbreg_portpower_int,
                           usb_portindicator_int, usbreg_phy_test_mode_int, pie_devicespeed_sync, atl_done, usbreg_atl_skip_int, iso_done,
			   usbreg_iso_skip_int, int_done, usbreg_int_skip_int, usbreg_atl_last_int, usbreg_iso_last_int,
			   usbreg_int_last_int, usbreg_phy_addr_int, usbreg_phy_wdata_int, phy_rdata_int, usbreg_phy_write_int,
			   usbreg_phy_start_int, usbreg_phy_mode_int, usbreg_woo_int, usbreg_lpm_hird_int, usbreg_lpm_bremotewakeup_int,
			   usbreg_lpm_addr_int, usbreg_lpm_susp_l1_on_int, dma_lpm_stat,id_value_sync,usbreg_id_en_int,usbreg_dev_en_int,
			   usbreg_sw_ctrl_pdcom_int, usbreg_sw_pdcom_int, usbreg_port_force_fullspeed_int

                           )
  begin
    reg_rdata_int <= (others => '0');
    case reg_raddr(6 downto 2) is
      when "00000" => --CAPLENGTH/CHIPID register (Address Offset = 0x00)
        reg_rdata_int(7 downto 0)  <= CAPLENGTH;
        reg_rdata_int(15 downto 8) <= (others => '0');
        reg_rdata_int(31 downto 16) <= CHIPID;

      when "00001" => --HCSPARAMS register (Address Offset = 0x04)
        reg_rdata_int(3 downto 0)  <= N_PORTS;
        reg_rdata_int(4)  <= PPC;
        reg_rdata_int(15 downto 5) <= (others => '0');
        reg_rdata_int(16)  <= P_INDICATOR;
        reg_rdata_int(19 downto 17) <= (others => '0');
        reg_rdata_int(23 downto 20) <= DPN;
        reg_rdata_int(31 downto 24) <= (others => '0');

      when "00010" => --HCCPARAMS register (Address Offset = 0x08)
        reg_rdata_int(0) <= '0';
        reg_rdata_int(1) <= PFLF;
        reg_rdata_int(2) <= ASPC;
	reg_rdata_int(16 downto 3) <= (others => '0');
	reg_rdata_int(17)<= LPMC;
        reg_rdata_int(31 downto 18) <= (others => '0');

      when "00011" => --FLADJ register (Address Offset = 0x0C)
        reg_rdata_int(5 downto 0) <= usbreg_fladj_int; --FLADJ
        reg_rdata_int(15 downto 6) <= (others => '0');
        reg_rdata_int(29 downto 16) <= std_logic_vector(usbreg_frindex_int);
        reg_rdata_int(31 downto 30) <= (others => '0');

      when "00100" => --ATL PTD BaseAddress (Address Offset = 0x10)
        reg_rdata_int(3 downto 0) <= (others => '0');
        reg_rdata_int(8 downto 4) <= usbreg_atl_cur_ptd_int;
        reg_rdata_int(31 downto 9) <= usbreg_atl_base_int;

      when "00101" => --ISO PTD BaseAddress (Address Offset = 0x14)
        reg_rdata_int(4 downto 0) <= (others => '0');
        reg_rdata_int(9 downto 5) <= usbreg_iso_first_ptd_int;
        reg_rdata_int(31 downto 10) <= usbreg_iso_base_int;

      when "00110" => --INT PTD BaseAddress (Address Offset = 0x18)
        reg_rdata_int(4 downto 0) <= (others => '0');
        reg_rdata_int(9 downto 5) <= usbreg_int_first_ptd_int;
        reg_rdata_int(31 downto 10) <= usbreg_int_base_int;

      when "00111" => --Data Payload BaseAddress (Address Offset = 0x1C)
        reg_rdata_int(15 downto 0) <= (others => '0');
        reg_rdata_int(31 downto 16) <= usbreg_payload_base_int;

      when "01000" => --USBCMD register (Address Offset = 0x20)
        reg_rdata_int(0) <= usbreg_run_int;
        reg_rdata_int(1) <= usbreg_reset_int;
        --we need usbreg_fls to know when to generate a SOF interrupt. This indicates when a frame list rollover happens
        reg_rdata_int(3 downto 2) <= usbreg_fls_int;
        reg_rdata_int(6 downto 4) <= (others => '0');
        reg_rdata_int(7) <= usbreg_light_reset_int;
        reg_rdata_int(8) <= usbreg_atl_enable_int;
        reg_rdata_int(9) <= usbreg_iso_enable_int;
        reg_rdata_int(10) <= usbreg_int_enable_int;
        reg_rdata_int(23 downto 11) <= (others => '0');
	reg_rdata_int(27 downto 24) <= usbreg_lpm_hird_int;
	reg_rdata_int(28)           <= usbreg_lpm_bremotewakeup_int;
        reg_rdata_int(31 downto 29) <= (others => '0');

      when "01001" => --USBSTS register (Address Offset = 0x24) !!! RWC bits !!!
        reg_rdata_int(1 downto 0) <= (others => '0');
        --Port Change Detect : The host controller sets this bit to logic 1 when
	--any port has a change bit transition from a zero to a one or
	--a Force Port Resume bit transition from a zero to a one as a result of a J-K transition detected on a suspended port.
        reg_rdata_int(2) <= pcd;
        --Frame List Rollover : The host controller sets this bit to logic 1
	--when the frame list index rolls over its maximum value to zero
        reg_rdata_int(3) <= flr;
        reg_rdata_int(15 downto 4) <= (others => '0');
        reg_rdata_int(16) <= atl_irq;
        reg_rdata_int(17) <= iso_irq;
        reg_rdata_int(18) <= int_irq;
        reg_rdata_int(19) <= sof_irq;
        reg_rdata_int(31 downto 20) <= (others => '0');

      when "01010" => --USBINTR register (Address Offset = 0x28)
        reg_rdata_int(1 downto 0) <= (others => '0');
        --Port Change Detect Interrupt Enable : If this enable bit is set to one and the corresponding USBSTS bit is set to one,
	--a hardware interrupt is generated.
        reg_rdata_int(2) <= pcde;
        --Frame List Rollover Interrupt Enable: If this enable bit is set to one
	--and the corresponding USBSTS bit is set to one,
	--a hardware interrupt is generated.
        reg_rdata_int(3) <= flre;
        reg_rdata_int(15 downto 4) <= (others => '0');
        reg_rdata_int(16) <= atl_irq_e; -- ATL IRQ Enable bit
        reg_rdata_int(17) <= iso_irq_e; -- ISO IRQ Enable bit
        reg_rdata_int(18) <= int_irq_e; -- INT IRQ Enable bit
        reg_rdata_int(19) <= sof_irq_e; -- SOF IRQ Enable bit
        reg_rdata_int(31 downto 20) <= (others => '0');

      when "01011" => --PORTSC1 register (Address Offset = 0x2C)
        reg_rdata_int(0) <= pie_portconnect_sync; --RO
        reg_rdata_int(1) <= csc; --RWC
        reg_rdata_int(2) <= pie_portenable_sync; --RW
        reg_rdata_int(3) <= pedc; --RWC
        reg_rdata_int(4) <= usb_overcurrent_sync; --RO
        reg_rdata_int(5) <= occ; --RWC
        reg_rdata_int(6) <= usbreg_portresume_int; --RW
        reg_rdata_int(7) <= usbreg_portsuspend_int; --RW
        reg_rdata_int(8) <= reg_portreset; --RW
        reg_rdata_int(9) <= usbreg_lpm_susp_l1_on_int; --RO
        reg_rdata_int(11) <= pie_linestate_sync(0); --RO Linestatus(bit 11) = Linestate(0) = DP
        reg_rdata_int(10) <= pie_linestate_sync(1); --RO Linestatus(bit 10) = Linestate(1) = DM
        reg_rdata_int(12) <= usbreg_portpower_int; --RW (RO if PPC = '0')
        reg_rdata_int(13) <= usbreg_port_force_fullspeed_int; --RW
        reg_rdata_int(15 downto 14) <= usb_portindicator_int; --RW (RO if P_INDICATOR = '0')
        reg_rdata_int(19 downto 16) <= usbreg_phy_test_mode_int; --RW
        reg_rdata_int(21 downto 20) <= pie_devicespeed_sync; --RO
        reg_rdata_int(22) <= usbreg_woo_int; --RW
        reg_rdata_int(24 downto 23) <= dma_lpm_stat; --RO
        reg_rdata_int(31 downto 25) <= usbreg_lpm_addr_int; --RW

      when "01100" => -- ATL PTD Done Map register (Address Offset = 0x30)
        reg_rdata_int(31 downto 0) <= atl_done; --RWC

      when "01101" => -- ATL PTD Skip Map register (Address Offset = 0x34)
        reg_rdata_int(31 downto 0) <= usbreg_atl_skip_int; --RW

      when "01110" => -- ISO PTD Done Map register (Address Offset = 0x38)
        reg_rdata_int(31 downto 0) <= iso_done; --RWC

      when "01111" => -- ISO PTD Skip Map register (Address Offset = 0x3C)
        reg_rdata_int(31 downto 0) <= usbreg_iso_skip_int; --RW

      when "10000" => -- INT PTD Done Map register (Address Offset = 0x40)
        reg_rdata_int(31 downto 0) <= int_done; --RWC

      when "10001" => -- INT PTD Skip Map register (Address Offset = 0x44)
        reg_rdata_int(31 downto 0) <= usbreg_int_skip_int; --RW

      when "10010" => -- Last PTD in use register (Address Offset = 0x48)
        reg_rdata_int(4 downto 0) <= usbreg_atl_last_int; --RW
        reg_rdata_int(7 downto 5) <= (others => '0'); --RO
        reg_rdata_int(12 downto 8) <= usbreg_iso_last_int; --RW
        reg_rdata_int(15 downto 13) <= (others => '0'); --RO
        reg_rdata_int(20 downto 16) <= usbreg_int_last_int; --RW
        reg_rdata_int(31 downto 21) <= (others => '0'); --RO

      when "10011" => -- UTMI+/ULPI debug (Address Offset = 0x4C)
        reg_rdata_int(7 downto 0) <= usbreg_phy_addr_int; --RW
        reg_rdata_int(15 downto 8) <= usbreg_phy_wdata_int; --RW
        reg_rdata_int(23 downto 16) <= phy_rdata_int; --RW
        reg_rdata_int(24) <= usbreg_phy_write_int; --RW
        reg_rdata_int(25) <= usbreg_phy_start_int; --RW
        reg_rdata_int(30 downto 26) <= (others => '0'); --RO
	if C_ULPI_SUPPORT and C_UTMI_SUPPORT then
          reg_rdata_int(31) <= usbreg_phy_mode_int; --RW/RO
	elsif C_ULPI_SUPPORT then
	  reg_rdata_int(31) <= '1';
	else
	  reg_rdata_int(31) <= '0';
	end if;
      when "10100" => --  OTG Port Mode (Address Offset = 0x50)
      	reg_rdata_int (0)  <= id_value_sync; -- RO
        reg_rdata_int (8)  <= usbreg_id_en_int; -- RW
	reg_rdata_int (16) <= usbreg_dev_en_int;-- RW
	reg_rdata_int (18) <= usbreg_sw_ctrl_pdcom_int;-- RW
	reg_rdata_int (19) <= usbreg_sw_pdcom_int;-- RW

      when others => --above 0x4C (above "10011")
        reg_rdata_int(31 downto 0) <= (others => '0'); --ABOVE RANGE
    end case;
  end process proc_reg_rdata;



  -------------------------
  -- Register write proc --
  -------------------------
 proc_reg_write : process(hclk,hresetn)
  begin
  if hresetn = '0' then
    usbreg_fladj_int         <= "100000"; --0x20
    usbreg_fladj_change_int  <= '0';
    usbreg_atl_cur_ptd_int   <= (others => '0');
    usbreg_atl_base_int      <= (others => '0');
    usbreg_iso_first_ptd_int <= (others => '0');
    usbreg_iso_base_int      <= (others => '0');
    usbreg_int_first_ptd_int <= (others => '0');
    usbreg_int_base_int      <= (others => '0');
    usbreg_payload_base_int  <= (others => '0');
    usbreg_run_int           <= '0';
    usbreg_reset_int         <= '0';
    usbreg_fls_int           <= (others => '0');
    usbreg_light_reset_int   <= '0';
    usbreg_atl_enable_int    <= '0';
    usbreg_iso_enable_int    <= '0';
    usbreg_int_enable_int    <= '0';
    usbreg_frindex_int       <= (others => '0');
    pcd                      <= '0';
    flr                      <= '0';
    atl_irq                  <= '0';
    iso_irq                  <= '0';
    int_irq                  <= '0';
    sof_irq                  <= '0';
    pcde                     <= '0';
    flre                     <= '0';
    atl_irq_e                <= '0';
    iso_irq_e                <= '0';
    int_irq_e                <= '0';
    sof_irq_e                <= '0';
    pie_portconnect_sync_z   <= '0';
    pie_portenable_sync_z    <= '0';
    usb_overcurrent_sync_z   <= '0';
    usb_portindicator_int    <= (others => '0');
    usbreg_phy_test_mode_int <= (others => '0');
    usbreg_portpower_int     <= '0';
    csc                      <= '0';
    csc_z                    <= '0';
    pedc                     <= '0';
    pedc_z                   <= '0';
    occ                      <= '0';
    occ_z                    <= '0';
    id_value_sync_z          <= '0';
    id_value_sync_zz         <= '0';
    usbreg_portresume_int    <= '0';
    usbreg_portsuspend_int   <= '0';
    usbreg_portreset_int     <= '0';
    atl_done                 <= (others => '0');
    usbreg_atl_skip_int      <= (others => '0');
    iso_done                 <= (others => '0');
    usbreg_iso_skip_int      <= (others => '0');
    int_done                 <= (others => '0');
    usbreg_int_skip_int      <= (others => '0');
    usbreg_atl_last_int      <= (others => '0');
    usbreg_iso_last_int      <= (others => '0');
    usbreg_int_last_int      <= (others => '0');
    usbreg_phy_addr_int      <= (others => '0');
    usbreg_phy_wdata_int     <= (others => '0');
    usbreg_phy_write_int     <= '0';
    usbreg_phy_start_int     <= '0';
    if C_ULPI_SUPPORT and C_UTMI_SUPPORT then
      usbreg_phy_mode_int    <= '0';
    end if;
    phy_rdata_int            <= (others => '0');
    usb_int_req_irq_int      <= '0';
    usbreg_portenable_clear_i<= '0';
    reg_portreset            <= '0';
    usbreg_woo_int           <= '0';
    usbreg_lpm_hird_int      <= (others => '0');
    usbreg_lpm_bremotewakeup_int <= '0';
    usbreg_lpm_addr_int      <= (others => '0');
    usbreg_lpm_susp_l1_on_int<= '0';
    usbreg_susp_l1_on        <= '0';
    usbreg_id_en_int         <= '0';
    usbreg_dev_en_int        <= '0';
    usbreg_sw_ctrl_pdcom_int     <= '1';
    usbreg_sw_pdcom_int          <= '0';
    usbreg_port_force_fullspeed_int <= '0';
  elsif (hclk'event and hclk='1') then

    csc_z             <= csc;
    occ_z             <= occ;
    pedc_z            <= pedc;
    usbreg_susp_l1_on <= '0';
    if usbreg_id_en_int = '1' then
      id_value_sync_z    <= id_value_sync;
    end if;
    id_value_sync_zz   <= id_value_sync_z;

   if reg_write = '1' then
    case reg_waddr(6 downto 2) is
      when "00000" => --CAPLENGTH/CHIPID register (Address Offset = 0x00)
        null; --RO

      when "00001" => --HCSPARAMS register (Address Offset = 0x04)
        null; --RO

      when "00010" => --HCCPARAMS register (Address Offset = 0x08)
        null; --RO

      when "00011" => --FLADJ register (Address Offset = 0x0C)
        usbreg_fladj_int        <= reg_wdata(5 downto 0);
        usbreg_fladj_change_int <= not usbreg_fladj_change_int;
        usbreg_frindex_int <= unsigned(reg_wdata(29 downto 16));

      when "00100" => --ATL PTD BaseAddress (Address Offset = 0x10)
        usbreg_atl_cur_ptd_int <= reg_wdata(8 downto 4);
        usbreg_atl_base_int <= reg_wdata(31 downto 9);

      when "00101" => --ISO PTD BaseAddress (Address Offset = 0x14)
        usbreg_iso_first_ptd_int <= reg_wdata(9 downto 5);
        usbreg_iso_base_int <= reg_wdata(31 downto 10);

      when "00110" => --INT PTD BaseAddress (Address Offset = 0x18)
        usbreg_int_first_ptd_int <= reg_wdata(9 downto 5);
        usbreg_int_base_int <= reg_wdata(31 downto 10);

      when "00111" => --Data Payload BaseAddress (Address Offset = 0x1C)
        usbreg_payload_base_int <= reg_wdata(31 downto 16);

      when "01000" => --USBCMD/FRINDEX register (Address Offset = 0x20)
        usbreg_run_int <= reg_wdata(0);
        usbreg_reset_int <= reg_wdata(1);
        --we need usbreg_fls to know when to generate a SOF interrupt. This indicates when a frame list rollover happens
        usbreg_fls_int <= reg_wdata(3 downto 2);
        usbreg_light_reset_int <= reg_wdata(7);
        usbreg_atl_enable_int <= reg_wdata(8);
        usbreg_iso_enable_int <= reg_wdata(9);
        usbreg_int_enable_int <= reg_wdata(10);
	usbreg_lpm_hird_int         <= reg_wdata(27 downto 24);
	usbreg_lpm_bremotewakeup_int<= reg_wdata(28);

      when "01001" => --USBSTS register (Address Offset = 0x24) !!! RWC bits !!!
        --Port Change Detect : The host controller sets this bit to logic 1 when
        --any port has a change bit transition from a zero to a one or
        --a Force Port Resume bit transition from a zero to a one as a result of a J-K transition detected on a suspended port.
        if (reg_wdata(2) = '1') then
          pcd <= '0';
        end if;

        --Frame List Rollover : The host controller sets this bit to logic 1
        --when the frame list index rolls over its maximum value to zero
        if (reg_wdata(3) = '1') then
          flr <= '0';
        end if;

        if (reg_wdata(16) = '1') then
          atl_irq <= '0';
        end if;

        if (reg_wdata(17) = '1') then
          iso_irq <= '0';
        end if;

        if (reg_wdata(18) = '1') then
          int_irq <= '0';
        end if;

        if (reg_wdata(19) = '1') then
          sof_irq <= '0';
        end if;

      when "01010" => --USBINTR register (Address Offset = 0x28)
        --Port Change Detect Interrupt Enable : If this enable bit is set to one and the corresponding USBSTS bit is set to one,
        --a hardware interrupt is generated.
        pcde <= reg_wdata(2);
        --Frame List Rollover Interrupt Enable: If this enable bit is set to one
        --and the corresponding USBSTS bit is set to one,
        --a hardware interrupt is generated.
        flre <= reg_wdata(3);
        atl_irq_e <= reg_wdata(16); -- ATL IRQ Enable bit
        iso_irq_e <= reg_wdata(17); -- ISO IRQ Enable bit
        int_irq_e <= reg_wdata(18); -- INT IRQ Enable bit
        sof_irq_e <= reg_wdata(19); -- SOF IRQ Enable bit


      when "01011" => --PORTSC1 register (Address Offset = 0x2C)
        if (reg_wdata(1) = '1') then
          csc <= '0';
        end if;

        if (reg_wdata(2) = '0') then -- If SW writes a zero to the PED bit, this signal is toggled
          usbreg_portenable_clear_i <= not usbreg_portenable_clear_i;
        end if;

        if (reg_wdata(3) = '1') then
          pedc <= '0';
        end if;

        if (reg_wdata(5) = '1') then
          occ <= '0';
	end if;

        usbreg_portresume_int  <= reg_wdata(6); --RW

        if (reg_wdata(7) = '1') then
	  if usbreg_portsuspend_int = '0' and
	     (usbreg_lpm_susp_l1_on_int = '1' or reg_wdata(9) = '1') then
	    usbreg_susp_l1_on <= '1';
	  else
            usbreg_portsuspend_int <= '1'; --RW (cannot write a 0)
	  end if;
	end if;

	if (reg_wdata(8) = '1' and usbreg_portreset_int  = '0') then
	  usbreg_portsuspend_int <= '0';
	end if;

        usbreg_portreset_int   <= reg_wdata(8); --RW

	usbreg_lpm_susp_l1_on_int <= reg_wdata(9); --RW

        if (PPC = '1') then --RW (RO if PPC = '0')
          usbreg_portpower_int <= reg_wdata(12);
        else
          usbreg_portpower_int <= '1';
        end if;

        usbreg_port_force_fullspeed_int <= reg_wdata(13);

        if (P_INDICATOR = '1') then --RW (RO if P_INDICATOR = '0')
          usb_portindicator_int <= reg_wdata(15 downto 14);
        else
          usb_portindicator_int <= (others => '0');
        end if;

        usbreg_phy_test_mode_int <= reg_wdata(19 downto 16); --RW

        usbreg_woo_int <= reg_wdata(22); --RW

        usbreg_lpm_addr_int <= reg_wdata(31 downto 25); --RW


      when "01100" => -- ATL PTD Done Map register (Address Offset = 0x30)
        for i in 0 to 31 loop
          if (reg_wdata(i) = '1') then
            atl_done(i) <= '0'; --RWC
          end if;
        end loop;



      when "01101" => -- ATL PTD Skip Map register (Address Offset = 0x34)
         usbreg_atl_skip_int(31 downto 0) <= reg_wdata(31 downto 0); --RW


      when "01110" => -- ISO PTD Done Map register (Address Offset = 0x38)
        for i in 0 to 31 loop
          if (reg_wdata(i) = '1') then
            iso_done(i) <= '0'; --RWC
          end if;
        end loop;



      when "01111" => -- ISO PTD Skip Map register (Address Offset = 0x3C)
         usbreg_iso_skip_int(31 downto 0) <= reg_wdata(31 downto 0); --RW


      when "10000" => -- INT PTD Done Map register (Address Offset = 0x40)
        for i in 0 to 31 loop
          if (reg_wdata(i) = '1') then
            int_done(i) <= '0'; --RWC
          end if;
        end loop;


      when "10001" => -- INT PTD Skip Map register (Address Offset = 0x44)
         usbreg_int_skip_int(31 downto 0) <= reg_wdata(31 downto 0); --RW

      when "10010" => -- Last PTD in use register (Address Offset = 0x48)
        usbreg_atl_last_int <= reg_wdata(4 downto 0); --RW
        usbreg_iso_last_int <= reg_wdata(12 downto 8); --RW
        usbreg_int_last_int <= reg_wdata(20 downto 16); --RW


      when "10011" => -- UTMI+/ULPI debug (Address Offset = 0x4C)
        --altera translate_off
        if C_ULPI_SUPPORT and C_UTMI_SUPPORT then
          usbreg_phy_mode_int  	  <= reg_wdata(31);
        end if;
        --altera translate_on
        if ((ULPI_SUPPORT = '0') and (UTMI_SUPPORT = '1')) then
           usbreg_phy_addr_int(3 downto 0) <= reg_wdata(3 downto 0); --used to control VControl signal on Vendor Interface of UTMI+
           usbreg_phy_addr_int(7 downto 4) <= (others => '0');
           usbreg_phy_wdata_int <= (others => '0'); -- not used
           phy_rdata_int <= reg_wdata(23 downto 16); --RW, also updated with phy_endtoggle_sync (below, highest priority for HW)
           usbreg_phy_write_int <= '0'; -- not used
           if (reg_wdata(25) = '1') then --sw is not allowed to clear the bit
	     usbreg_phy_start_int <= '1';
           end if;
        elsif ((ULPI_SUPPORT = '1') and (UTMI_SUPPORT = '0')) then
           usbreg_phy_addr_int(7 downto 0) <= reg_wdata(7 downto 0); -- used as the address when doing a register access over the ULPI interface
           usbreg_phy_wdata_int <= reg_wdata(15 downto 8); -- used for the write data when writing a value to a ULPI PHY register
           phy_rdata_int <= reg_wdata(23 downto 16); --RW, also updated with phy_endtoggle_sync (below, highest priority for HW)
           usbreg_phy_write_int <= reg_wdata(24); -- '1' = write op
           if (reg_wdata(25) = '1') then --sw is not allowed to clear the bit
	     usbreg_phy_start_int <= '1';
           end if;
        else --((ULPI_SUPPORT = '1') and (UTMI_SUPPORT = '1'))
          if (usbreg_phy_mode_int = '1') then --current mode is ULPI (default is UTMI)
           usbreg_phy_addr_int(7 downto 0) <= reg_wdata(7 downto 0); -- used as the address when doing a register access over the ULPI interface
           usbreg_phy_wdata_int <= reg_wdata(15 downto 8); -- used for the write data when writing a value to a ULPI PHY register
           usbreg_phy_write_int <= reg_wdata(24); -- '1' = write op
	  else --current mode is UTMI
           usbreg_phy_addr_int(3 downto 0) <= reg_wdata(3 downto 0); --used to control VControl signal on Vendor Interface of UTMI+
           usbreg_phy_addr_int(7 downto 4) <= (others => '0');
           usbreg_phy_wdata_int <= (others => '0'); -- not used
           usbreg_phy_write_int <= '0'; -- not used
	  end if;
           phy_rdata_int <= reg_wdata(23 downto 16); --RW, also updated with phy_endtoggle_sync (below, highest priority for HW)
           if (reg_wdata(25) = '1') then --sw is not allowed to clear the bit
	     usbreg_phy_start_int <= '1';
           end if;
        end if;

      when "10100" => --  OTG Port Mode (Address Offset = 0x50)
         usbreg_id_en_int  <= reg_wdata(8);
	 usbreg_dev_en_int <= reg_wdata(16);
	 usbreg_sw_ctrl_pdcom_int <= reg_wdata(18);
         usbreg_sw_pdcom_int      <= reg_wdata(19);
      when others => --above 0x50 (above "10100")
        null;
    end case;
   end if; --reg_write = '1'


  ----------------------------
  --xxx_done set code below --
  ----------------------------
  if (dma_atl_setdone = '1') then
   atl_done(to_integer(unsigned(dma_current_ptd))) <= '1';
  end if;

  if (dma_iso_setdone = '1') then
   iso_done(to_integer(unsigned(dma_current_ptd))) <= '1';
  end if;

  if (dma_int_setdone = '1') then
   int_done(to_integer(unsigned(dma_current_ptd))) <= '1';
  end if;

  ------------------------------------------
  -- Connect Status Change set code below --
  ------------------------------------------
  pie_portconnect_sync_z <= pie_portconnect_sync;
  if (pie_portconnect_sync_z /= pie_portconnect_sync) then
    csc <= '1';
  end if;

  ----------------------------------------------
  -- Port enable Status Change set code below --
  ----------------------------------------------
  pie_portenable_sync_z <= pie_portenable_sync;
  if (pie_portenable_sync_z /= pie_portenable_sync) then
    pedc <= '1';
  end if;

  if usbreg_portreset_int = '1' then
    reg_portreset <= '1';
  elsif pie_portenable_sync = '1' or pie_portconnect_sync = '0' then
    reg_portreset <= '0';
  end if;
  ----------------------------------------------
  -- overcurrent status Change set code below --
  ----------------------------------------------
  usb_overcurrent_sync_z <= usb_overcurrent_sync;
  if (usb_overcurrent_sync_z /= usb_overcurrent_sync) then
    occ <= '1';
  end if;

  --------------------------------------------
  -- force port resume set/reset code below --
  --------------------------------------------
  if (pie_resume_detected_sync = '1') then
    usbreg_portresume_int  <= '1';
  end if;

  if ((pie_resume_done_sync = '1') or (pie_portconnect_sync = '0')) then
    usbreg_portresume_int  <= '0';
    usbreg_portsuspend_int <= '0';
  end if;

  if dma_lpm_success = '1' then
    usbreg_portsuspend_int  <= '1';
  end if;

  --------------------------------------------
  -- update phy rdata on phy_endtoggle_sync --
  --------------------------------------------
   if (phy_endtoggle_sync = '1') then
     phy_rdata_int <= phy_rdata_sync;
   end if;

  --------------------------------------------
  -- update phy start on phy_endtoggle_sync --
  --------------------------------------------
   if (phy_endtoggle_sync = '1') then
     usbreg_phy_start_int <= '0';
   end if;

  ----------------------------
  -- Port Change Detect set --
  ----------------------------
  --when any port has a change bit transition from a zero to a one
  --(bits being CSC, PEDC and OCC in the PORTSC register)

  if ((csc = '1') and (csc_z = '0')) then
    pcd <= '1';
  end if;

  if ((pedc = '1') and (pedc_z = '0')) then
    pcd <= '1';
  end if;

  if ((occ = '1') and (occ_z = '0')) then
    pcd <= '1';
  end if;

  -- Set PCD interrupt when ID pin value changes
  if (id_value_sync_z /= id_value_sync_zz) then
    pcd <= '1';
  end if;

 --a Force Port Resume bit transition from a zero to a one as a result of a J-K transition detected on a suspended port.
  if (pie_resume_detected_sync = '1') then
    pcd <= '1';
  end if;

 -- Generate a PCD interrupt when LPM token transmission has been completed.
 -- This allows firmware to check the status of the LPM transmission
  if dma_lpm_done = '1' then
    pcd <= '1';
  end if;
  
  -----------------------
  -- Frindex increment --
  -----------------------
  if (usb_inc_frindex_toggle_sync = '1') then
    if (usbreg_frindex_int = 16383) then
      usbreg_frindex_int <= (others => '0');
    else
      usbreg_frindex_int <= usbreg_frindex_int +1;
    end if;

    -----------------------------
    -- Frame List Rollover set --
    -----------------------------
    --The host controller sets this bit to logic 1 when the frame list index rolls over its maximum value to zero
    -- flr <= '1';

    case usbreg_fls_int is
      when "00" =>
        if (usbreg_frindex_int(12 downto 3) = 1023) and
	   (usbreg_frindex_int( 2 downto 0) =    7) then
          flr <= '1';
        end if;

      when "01" =>
        if (usbreg_frindex_int(11 downto 3) =  511) and
	   (usbreg_frindex_int( 2 downto 0) =    7) then
          flr <= '1';
        end if;

      when others => --"10" | "11" => --"11" is reserved
        if (usbreg_frindex_int(10 downto 3) =  255) and
	   (usbreg_frindex_int( 2 downto 0) =    7) then
          flr <= '1';
        end if;

    end case;
  end if;


  -------------------
  -- interrupt set --
  -------------------
  if (dma_atl_setint = '1') then
    atl_irq <= '1';
  end if;

  if (dma_iso_setint = '1') then
    iso_irq <= '1';
  end if;

  if (dma_int_setint = '1') then
    int_irq <= '1';
  end if;

  if (usb_inc_frindex_toggle_sync = '1' and
      pie_portenable_sync  = '1'        and
      usbreg_portsuspend_int = '0'      and
      (usbreg_frindex_int(2 downto 0) = "111" or pie_devicespeed_sync = "10")) then
    sof_irq <= '1';
  end if;

  if ((atl_irq = '1' and atl_irq_e = '1') or
      (iso_irq = '1' and iso_irq_e = '1') or
      (int_irq = '1' and int_irq_e = '1') or
      (sof_irq = '1' and sof_irq_e = '1') or
      (pcd     = '1' and pcde      = '1') or
      (flr     = '1' and flre      = '1')) then
     usb_int_req_irq_int <= '1';
   else
     usb_int_req_irq_int <= '0';
   end if;

  -------------------------
  -- set ATL_CUR         --
  -------------------------
  if dma_atl_setptd = '1' then
    usbreg_atl_cur_ptd_int <= dma_current_ptd;
  end if;

  -------------------------
  -- clear of resets bit --
  -------------------------
  if (sync_reset_done = '1') then
     usbreg_light_reset_int <= '0';
     usbreg_reset_int <= '0';
  end if;

  if usbreg_portpower_int = '0' then
    csc                   <= '0';
    pedc                  <= '0';
    usbreg_portresume_int <= '0';
    usbreg_portsuspend_int<= '0';
    reg_portreset         <= '0';
    usb_portindicator_int <= (others => '0');
    usbreg_woo_int        <= '0';
  end if;

  if ((usbreg_light_reset_int = '1') or (usbreg_reset_int = '1')) then
    usbreg_fladj_int         <= "100000"; --0x20
    usbreg_fladj_change_int  <= '0';
    usbreg_atl_cur_ptd_int   <= (others => '0');
    usbreg_atl_base_int      <= (others => '0');
    usbreg_iso_first_ptd_int <= (others => '0');
    usbreg_iso_base_int      <= (others => '0');
    usbreg_int_first_ptd_int <= (others => '0');
    usbreg_int_base_int      <= (others => '0');
    usbreg_payload_base_int  <= (others => '0');
    usbreg_run_int           <= '0';
    usbreg_fls_int           <= (others => '0');
    usbreg_atl_enable_int    <= '0';
    usbreg_iso_enable_int    <= '0';
    usbreg_int_enable_int    <= '0';
    usbreg_frindex_int       <= (others => '0');
    pcd                      <= '0';
    flr                      <= '0';
    atl_irq                  <= '0';
    iso_irq                  <= '0';
    int_irq                  <= '0';
    pcde                     <= '0';
    flre                     <= '0';
    atl_irq_e                <= '0';
    iso_irq_e                <= '0';
    int_irq_e                <= '0';
    sof_irq_e                <= '0';

    if (usbreg_reset_int = '1') then --only reset on hard reset, not on light reset
      pie_portconnect_sync_z   <= '0';
      pie_portenable_sync_z    <= '0';
      usb_overcurrent_sync_z   <= '0';
      usb_portindicator_int    <= (others => '0');
      usbreg_phy_test_mode_int <= (others => '0');
      usbreg_portpower_int     <= '0';
      csc		       <= '0';
      csc_z		       <= '0';
      pedc		       <= '0';
      pedc_z		       <= '0';
      occ		       <= '0';
      occ_z		       <= '0';
      usbreg_portresume_int    <= '0';
      usbreg_portsuspend_int   <= '0';
      usbreg_portreset_int     <= '0';
      usbreg_lpm_addr_int      <= (others => '0');
      usbreg_lpm_susp_l1_on_int<= '0';
      usbreg_id_en_int         <= '0';
      usbreg_dev_en_int        <= '0';
      usbreg_sw_ctrl_pdcom_int     <= '1';
      usbreg_sw_pdcom_int          <= '0';

    end if;

    atl_done                 <= (others => '0');
    usbreg_atl_skip_int      <= (others => '0');
    iso_done                 <= (others => '0');
    usbreg_iso_skip_int      <= (others => '0');
    int_done                 <= (others => '0');
    usbreg_int_skip_int      <= (others => '0');
    usbreg_atl_last_int      <= (others => '0');
    usbreg_iso_last_int      <= (others => '0');
    usbreg_int_last_int      <= (others => '0');
    usbreg_phy_addr_int      <= (others => '0');
    usbreg_phy_wdata_int     <= (others => '0');
    usbreg_phy_write_int     <= '0';
    usbreg_phy_start_int     <= '0';
    usbreg_woo_int           <= '0';
    usbreg_lpm_hird_int      <= (others => '0');
    usbreg_lpm_bremotewakeup_int <= '0';

    if C_ULPI_SUPPORT and C_UTMI_SUPPORT then
      usbreg_phy_mode_int    <= '0';
    end if;
    phy_rdata_int            <= (others => '0');
    usb_int_req_irq_int      <= '0';
    usbreg_portenable_clear_i<= '0';
    reg_portreset            <= '0';
  end if;



  end if; --hresetn = '0'
 end process proc_reg_write;




  --------------------------------
  -- internal signals to output --
  --------------------------------
  usb_int_req_irq         <= usb_int_req_irq_int;
  usb_portindicator       <= usb_portindicator_int;
  reg_rdata               <= reg_rdata_int;

  usbreg_pll_on_int       <= usbreg_run_int;
  usbreg_dev_en           <= usbreg_dev_en_int;
  usbreg_pll_on           <= usbreg_pll_on_int;
  usbreg_phy_test_mode    <= usbreg_phy_test_mode_int(2 downto 0);
  usbreg_fladj            <= usbreg_fladj_int;
  usbreg_fladj_change     <= usbreg_fladj_change_int;
  usbreg_run              <= usbreg_run_int;
  usbreg_reset            <= usbreg_reset_int;
  usbreg_light_reset      <= usbreg_light_reset_int;
  usbreg_portresume       <= usbreg_portresume_int;
  usbreg_portreset        <= usbreg_portreset_int;
  usbreg_port_force_fullspeed <= usbreg_port_force_fullspeed_int;
  -- IF L1 suspend is enabled, do not indicate suspend towards host_pie block
  usbreg_portsuspend      <= usbreg_portsuspend_int when usbreg_lpm_susp_l1_on_int = '0' else '0';
  usbreg_portl1l2suspend  <= usbreg_portsuspend_int;
  usbreg_portpower        <= usbreg_portpower_int;
  usbreg_phy_addr         <= usbreg_phy_addr_int;
  usbreg_phy_wdata        <= usbreg_phy_wdata_int;
  usbreg_phy_write        <= usbreg_phy_write_int;
  usbreg_phy_start        <= usbreg_phy_start_int;
  usbreg_phy_mode         <= usbreg_phy_mode_int when C_ULPI_SUPPORT and C_UTMI_SUPPORT else
                             '1'                 when C_ULPI_SUPPORT                    else
                             '0';
  usbreg_atl_base         <= usbreg_atl_base_int;
  usbreg_atl_cur_ptd      <= usbreg_atl_cur_ptd_int;
  usbreg_iso_base         <= usbreg_iso_base_int;
  usbreg_iso_first_ptd    <= usbreg_iso_first_ptd_int;
  usbreg_int_base         <= usbreg_int_base_int;
  usbreg_int_first_ptd    <= usbreg_int_first_ptd_int;
  usbreg_payload_base     <= usbreg_payload_base_int;
  usbreg_frindex          <= std_logic_vector(usbreg_frindex_int);
  usbreg_atl_enable       <= usbreg_atl_enable_int;
  usbreg_iso_enable       <= usbreg_iso_enable_int;
  usbreg_int_enable       <= usbreg_int_enable_int;
  usbreg_atl_skip         <= usbreg_atl_skip_int;
  usbreg_iso_skip         <= usbreg_iso_skip_int;
  usbreg_int_skip         <= usbreg_int_skip_int;
  usbreg_atl_last         <= usbreg_atl_last_int;
  usbreg_iso_last         <= usbreg_iso_last_int;
  usbreg_int_last         <= usbreg_int_last_int;
  usbreg_portenable_clear <= usbreg_portenable_clear_i;

  usbreg_woo	          <= usbreg_woo_int;
  usbreg_lpm_hird         <= usbreg_lpm_hird_int;
  usbreg_lpm_bremotewakeup<= usbreg_lpm_bremotewakeup_int;
  usbreg_lpm_addr         <= usbreg_lpm_addr_int;

  usbreg_id_en         <= usbreg_id_en_int;
 -- usbreg_dev_en        <= usbreg_dev_en_int;
  usbreg_sw_ctrl_pdcom  <= usbreg_sw_ctrl_pdcom_int;
  usbreg_sw_pdcom       <= usbreg_sw_pdcom_int;

  ------------------------
  -- FPGA debug signals --
  ------------------------

  usb_host_reg_if_fpga(63 downto 6) <= (others => '0');
  usb_host_reg_if_fpga(0) <= usbreg_portreset_int;
  usb_host_reg_if_fpga(1) <= csc;
  usb_host_reg_if_fpga(2) <= reg_portreset;
  usb_host_reg_if_fpga(3) <= pie_portenable_sync;
  usb_host_reg_if_fpga(4) <= pedc;
  usb_host_reg_if_fpga(5) <= pcd;


end RTL;
