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
--           $RCSfile: ip_xxx_3511_cmp_pkg.p.vhdl.rca $
--
--             Author: Sonia Mehri
--
--       Organisation: Corporate I&T / IP & Architecture
--
--              $Date: Sun Apr 23 19:20:43 2017 $
--
--            Project: Low gate count USB peripheral IP 
--
--        Description: 
--
--          $Revision: 1.3 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: ip_xxx_3511_cmp_pkg.p.vhdl.rca $
--   
--    Revision: 1.3 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.4 Tue Jan  3 14:57:20 2012 beq03067
--    Added commented code (to match mem)
--   
--    Revision: 1.3 Thu Feb 24 09:35:28 2011 beq03099
--    removed usb_cfg package
--   
--    Revision: 1.2 Mon Jul 26 12:28:38 2010 beq03099
--    removed FPGA debug signals
--   
--    Revision: 1.1 Fri May 21 08:54:59 2010 aes
--    First check in.
--   
--    Revision: 1.3 Mon Apr 19 14:29:37 2010 bve
--    *** empty comment string ***
--   
--    Revision: 1.2 Fri Apr 16 11:59:33 2010 bve
--    added logic for an internal PLL and RC circuit
--   
--    Revision: 1.1 Thu Apr  1 09:47:55 2010 bve
--    Initial version
--   
--   
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package ip_xxx_3511_cmp_pkg is
component ip_xxx_3511
  generic(--AHB_DATAWIDTH  : integer := 32;
          --RAM_DATAWIDTH  : integer := 64;
	  --RAM_ADDRWIDTH  : integer := 9;
	  
          C_NBPHYSEP     : integer := 14;
          C_EPUB         : integer := 32;
          C_DAUB         : integer := 32; --Requirement : C_DAUB > C_DALB
          C_DALB         : integer := 22; --maximum allowed value is 22
                                          --minimum allowed value is 7
          C_EPFIFO_PAGE  : std_logic_vector(31 downto 0) := X"00080000";
          C_DATAFIFO_PAGE: std_logic_vector(31 downto 0) := X"00080000";
          C_SINGLE_BUFFER_SUPPORTED: boolean := TRUE;
          C_DOUBLE_BUFFER_SUPPORTED: boolean := TRUE;
          C_TOGGLE_REG_READABLE    : boolean := TRUE;
          C_PLL_ENABLE             : boolean := FALSE;
          C_PLL_DIVIDER            : std_logic_vector(6 downto 0) := "0010100");
  port(
       -- Clocks 
       USB_MainClk:          in    std_logic;                      -- Main clock = 48 Mhz
       USB_NeedClk:          out   std_logic;                      -- USB needs clock; signal to control USB_Mainclk
       USB_BitClk:           in    std_logic;                      -- Bit clock in ; Loop back USB_Bitclk_Out
       USB_BitClk_Out:       out   std_logic;                      -- Bit clock out ; 12 Mhz from USB Core

       -- Connect
       USB_Connect_N:        out   std_logic;                      -- Controls switch for softconnect
       USB_VBus:             in    std_logic;                      -- Bus power is present

       USB_lowpurenable:     out   std_logic;
              	 
       -- Suspend
       USB_Suspend_N:        out   std_logic;                      -- USB Suspend; Goes low when suspend

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
              
       ahbm_haddr	    : out std_logic_vector(31 downto 0); 
       ahbm_hwrite	    : out std_logic;			 
       ahbm_htrans	    : out std_logic_vector(1 downto 0);  
       ahbm_hwdata	    : out std_logic_vector(31 downto 0); 
       ahbm_hrdata	    : in  std_logic_vector(31 downto 0); 
       ahbm_hready	    : in  std_logic;			 
       ahbm_hsize	    : out std_logic_vector(2 downto 0);  
       ahbm_hburst	    : out std_logic_vector(2 downto 0);  
       ahbm_hprot	    : out std_logic_vector(3 downto 0);

       -- Interrupt controller signals
       USB_Int_Req_Irq:      out   std_logic;                      -- Irq interrupt   
       USB_Int_Req_Fiq:      out   std_logic;                      -- Fiq interrupt
       USB_FrameToggle:      out   std_logic;

       --Configuration status indicator
       USB_UP_LED_N:         out   std_logic;                      -- LED   
 
       -- Upstream port connection to ATX      
       USB_UP_RxDM:          in    std_logic;                      -- Rx D-  
       USB_UP_RxDP:          in    std_logic;                      -- Rx D+  
       USB_UP_RxRCV:         in    std_logic;                      -- Rx RCV 
       USB_UP_TxDM:          out   std_logic;                      -- Tx D- 
       USB_UP_TxDP:          out   std_logic;                      -- Tx D+
       USB_UP_TxFSE0:        out   std_logic;                      -- Tx FSE0
       USB_UP_TxEnable_N:    out   std_logic;                      -- Tx Enable
       
       -- Dedicated signals for internal PLL that is synchronized on USB frame time
       USB_select_ext_clk:   out std_logic;
       USB_48MHzReset_N       : out std_logic; -- reset for frequency control block
                                               -- synchronous with USB_MainClk
       USB_FrameTimer         : out std_logic_vector(15 downto 0);
       USB_SOFDetect          : out std_logic;
       USB_Token_Length       : out std_logic_vector(6 downto 0);
       USB_fro_adjust_req     :	out std_logic;
       USB_fro_adjust_eof     :	out std_logic;
       USB_fro_adjust_bias    :	out std_logic_vector(2 downto 0);
       USB_fro_adjust_enable  :	in  std_logic;

       --core testability
       async_disable:        in    std_logic;
       scan_test:            in    std_logic
       --debug_fpga_3511      : out std_logic_vector(63 downto 0)
      
      );
end component;
end ip_xxx_3511_cmp_pkg;
