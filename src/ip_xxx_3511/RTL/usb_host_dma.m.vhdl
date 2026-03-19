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
--               File: usb_host_dma.m.vhdl
--
--             Author: Bart Vertenten
--
--       Organisation: CentralR&D / Design Services / MSS
--
--              $Date: Sun Apr 23 19:20:43 2017 $
--
--            Project: IP_3515_HS - Low gate count USB host IP 
--
--        Description: 
--
--          $Revision: 1.6 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_host_dma.m.vhdl.rca $
--   
--    Revision: 1.6 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.47 Fri Jun 15 13:04:01 2012 beq03099
--    fix for PR61 - stop processing the lists when port is in suspend
--   
--    Revision: 1.46 Fri Jun 15 07:50:55 2012 beq03099
--    One more modification to fix the failing regression tests
--   
--    Revision: 1.45 Thu Jun 14 17:47:56 2012 beq03099
--    Added interrupt generation when ISO has not been processed
--   
--    Revision: 1.44 Thu Jun 14 17:40:51 2012 beq03099
--    Fix for PR60 : Clear valid bit when ISO structure must 
--    have been processed in previous frame
--   
--    Revision: 1.43 Mon Jun 11 16:27:37 2012 beq03099
--    fix for FPGA problems
--    - NAK on CSplit must not set X bit if it is not for a setup
--    - Check all bytes transferred on NYET only for HS Bulk and Control
--   
--    Revision: 1.42 Tue Jun  5 14:13:58 2012 beq03099
--    added extra delay in function to fix PR58
--   
--    Revision: 1.41 Mon Jun  4 16:34:59 2012 beq03099
--    fix for PR56 and modification to resolve quartus issue
--   
--    Revision: 1.40 Thu May 31 19:03:17 2012 beq03099
--    Implemented fix to not write outside buffer for IN packets
--   
--    Revision: 1.39 Fri May 25 13:56:01 2012 beq03099
--    fix for PR55, NYET only sent 16 times if RL field was set to 15.
--   
--    Revision: 1.38 Tue May 22 15:10:50 2012 beq03099
--    fix for PR43
--    When state is in IDLE and LPM must be sent, do not check endofframe bit
--   
--    Revision: 1.37 Thu May 10 11:23:26 2012 beq03196
--    Previous fix was not correct (PR#28 addendum)
--   
--    Revision: 1.36 Wed May  9 15:51:02 2012 beq03099
--    another fix in case there is a SW error on the jump bit
--   
--    Revision: 1.35 Mon May  7 11:51:56 2012 beq03099
--    fixed problem with low power implementation
--   
--    Revision: 1.34 Fri May  4 10:34:56 2012 beq03099
--    Problem fixed with interval of 32ms for interrupt endpoints
--   
--    Revision: 1.33 Wed Apr 25 08:53:33 2012 beq03099
--    fix for PR31 : CSPLIT MDATA data was written to wrong location
--   
--    Revision: 1.32 Fri Apr 20 08:18:02 2012 beq03099
--    fixed range constraint violation for test host_traffic_19
--    fixed PR 28 : Do not jump beyond lastptd
--   
--    Revision: 1.31 Thu Apr 12 14:02:04 2012 beq03099
--    Finished LPM implementation
--   
--    Revision: 1.30 Thu Apr 12 07:38:46 2012 beq03099
--    modified register interface according to v0.7.0 of the architecture spec
--   
--    Revision: 1.29 Wed Apr 11 13:12:02 2012 beq03099
--    Do not update ptd_token field in qATL when a PING must be sent.
--   
--    Revision: 1.28 Fri Apr  6 11:28:50 2012 beq03099
--    fixed immediate retry for Split ISO
--   
--    Revision: 1.27 Fri Apr  6 10:54:39 2012 beq03099
--    implemented 2 fixes :
--    - do not update ISO_IN field when there is a transaction error
--    - update NrBytesTransferred field if an MDATA is received on ISO CSplit IN
--   
--    Revision: 1.26 Thu Apr  5 08:00:16 2012 beq03099
--    Fixed problem with resetting Cerr
--    Cerr must not be reset on a successful start-split
--   
--    Revision: 1.25 Wed Apr  4 16:58:48 2012 beq03099
--    added more functionality to handle interrupt MDATA pid packets
--   
--    Revision: 1.24 Tue Apr  3 13:51:41 2012 beq03099
--    An additional fix on previous PR to get all simulations passing again
--   
--    Revision: 1.23 Tue Apr  3 12:31:14 2012 beq03099
--    Implemented fix in case multiple start splits must be sent for ISO OUT
--    Fixed ptd_se generation.
--   
--    Revision: 1.22 Tue Mar 20 14:06:34 2012 beq03099
--    fix for FS ISO IN. Update of structure was not correct
--   
--    Revision: 1.21 Mon Mar 19 13:27:35 2012 beq03099
--    fixed issue with check if packet still fits in frame
--   
--    Revision: 1.20 Mon Mar 19 09:48:30 2012 beq03099
--    Added support for MDATA
--   
--    Revision: 1.19 Thu Mar 15 13:50:18 2012 beq03099
--    fixed problem with SETUP token.
--    Active bit must be cleared when all data is transmitted and ACK is received
--   
--    Revision: 1.18 Wed Mar 14 10:41:11 2012 beq03099
--    DW2 must not be read when a FS or LS device is attached to the USB port
--   
--    Revision: 1.17 Tue Mar 13 15:57:14 2012 beq03099
--    fixed problem with polling rate for interrupt endpoints
--   
--    Revision: 1.16 Tue Mar 13 13:52:14 2012 beq03099
--    for interrupt transfer do not update separate status fields at DWORD 0x05
--   
--    Revision: 1.15 Tue Mar 13 11:26:20 2012 beq03099
--    fix for high-bandwidth interrupt.
--    Only send 3 packets per micro-frame (maximum)
--   
--    Revision: 1.14 Mon Mar 12 11:29:03 2012 beq03099
--    fixed bytesleftinframe calculation for full-speed and low-speed
--   
--    Revision: 1.13 Mon Mar 12 09:17:22 2012 beq03099
--    fixes range constraint violation on hc_bytesleftinframe
--   
--    Revision: 1.12 Fri Mar  9 14:30:17 2012 beq03099
--    added signal usb_decrement_bytes
--   
--    Revision: 1.11 Fri Mar  9 11:45:27 2012 beq03099
--    Fixed PING : this should not be sent on FS or LS port
--   
--    Revision: 1.10 Fri Mar  9 08:59:56 2012 beq03099
--    fixed interrupt generation
--   
--    Revision: 1.9 Fri Mar  9 07:58:48 2012 beq03099
--    V-bit must not be cleared when PING is ACKed
--   
--    Revision: 1.8 Fri Mar  9 07:26:23 2012 beq03099
--    removed usb_dma_word_selection
--   
--    Revision: 1.7 Thu Mar  8 16:05:59 2012 beq03099
--    added usbreg_reset and light_reset to DMA interface
--   
--    Revision: 1.6 Wed Mar  7 08:53:58 2012 beq03099
--    fixed problem with var_pointer
--    This must be cleared when packet is transmitted
--   
--    Revision: 1.5 Fri Feb 17 12:32:31 2012 beq03099
--    Fixed compile problems with generic
--   
--    Revision: 1.4 Wed Feb 15 14:17:45 2012 beq03099
--    fixed problems with OUT data packet transmission and
--    update of qATL
--   
--    Revision: 1.3 Wed Feb  1 14:47:33 2012 beq03099
--    added list switching
--   
--    Revision: 1.2 Wed Feb  1 13:15:47 2012 beq03099
--    fixed synplify warnings
--   
--    Revision: 1.1 Wed Feb  1 07:46:35 2012 beq03099
--    initial version
--   
--   
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

library usb_lib;
use usb_lib.usb_general_subcmp_pkg.all;

entity usb_host_dma is
generic(USB_DATAWIDTH   : integer := 8;
	RAM_DATAWIDTH   : integer := 64;
        RAM_ADDR_WIDTH  : integer := 15);
port (
      --To/From external
      hclk		: in	std_logic; 
      hresetn		: in	std_logic; 
            
      dma_addr		: out   std_logic_vector(31 downto 0); 
      dma_req           : out   std_logic;                     
      dma_gnt           : in    std_logic;                     
      dma_write         : out   std_logic;                     
      dma_wdata         : out   std_logic_vector(RAM_DATAWIDTH-1 downto 0); 
      dma_rdata		: in 	std_logic_vector(RAM_DATAWIDTH-1 downto 0);

      --To/From usb_host_reg_if module
      usbreg_atl_base          : in  std_logic_vector(22 downto 0);
      usbreg_atl_cur_ptd       : in  std_logic_vector( 4 downto 0);
      usbreg_iso_base          : in  std_logic_vector(21 downto 0);
      usbreg_iso_first_ptd     : in  std_logic_vector( 4 downto 0);
      usbreg_int_base          : in  std_logic_vector(21 downto 0);
      usbreg_int_first_ptd     : in  std_logic_vector( 4 downto 0);
      usbreg_payload_base      : in  std_logic_vector(15 downto 0);     
      usbreg_frindex           : in  std_logic_vector(13 downto 0);
      usbreg_run               : in  std_logic;
      usbreg_atl_enable        : in  std_logic;
      usbreg_iso_enable        : in  std_logic;
      usbreg_int_enable        : in  std_logic;
      dma_atl_setint           : out std_logic;
      dma_iso_setint           : out std_logic;
      dma_int_setint           : out std_logic;
      dma_atl_setdone          : out std_logic;
      dma_iso_setdone          : out std_logic;
      dma_int_setdone          : out std_logic;
      dma_atl_setptd           : out std_logic;
      dma_current_ptd          : out std_logic_vector(4 downto 0);
      usbreg_atl_skip          : in  std_logic_vector(31 downto 0);
      usbreg_iso_skip          : in  std_logic_vector(31 downto 0);
      usbreg_int_skip          : in  std_logic_vector(31 downto 0);
      usbreg_atl_last          : in  std_logic_vector(4 downto 0);
      usbreg_iso_last          : in  std_logic_vector(4 downto 0);
      usbreg_int_last          : in  std_logic_vector(4 downto 0);
      usbreg_reset             : in  std_logic;
      usbreg_light_reset       : in  std_logic;
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
      pie_devicespeed_sync     : in  std_logic_vector(1 downto 0);
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

      usb_dma_fpga              : out std_logic_vector(63 downto 0)

     );
end usb_host_dma; 
      
architecture RTL of usb_host_dma is

constant RAM_ADDR_BYTE_WIDTH : integer := RAM_ADDR_WIDTH + log2(RAM_DATAWIDTH/8);

constant FIFO_NBYTES : integer := (USB_DATAWIDTH + RAM_DATAWIDTH) / 8;

constant TOKEN_SOF    : std_logic_vector(2 downto 0) := "000";
constant TOKEN_EXT    : std_logic_vector(2 downto 0) := "001";
constant TOKEN_SETUP  : std_logic_vector(2 downto 0) := "010";
constant TOKEN_OUT    : std_logic_vector(2 downto 0) := "011";
constant TOKEN_IN     : std_logic_vector(2 downto 0) := "100";
constant TOKEN_PING   : std_logic_vector(2 downto 0) := "101";
constant TOKEN_SSPLIT : std_logic_vector(2 downto 0) := "110";
constant TOKEN_CSPLIT : std_logic_vector(2 downto 0) := "111";

constant XACT_ERROR           : std_logic_vector(2 downto 0) := "000";
constant MDATA_DATABUF_ERROR  : std_logic_vector(2 downto 0) := "001";
constant BABBLE_ERROR         : std_logic_vector(2 downto 0) := "010";
constant ERR_HANDSHAKE        : std_logic_vector(2 downto 0) := "011";
constant ACK_HANDSHAKE        : std_logic_vector(2 downto 0) := "100";
constant STALL_HANDSHAKE      : std_logic_vector(2 downto 0) := "101";
constant NAK_HANDSHAKE        : std_logic_vector(2 downto 0) := "110";
constant NYET_HANDSHAKE       : std_logic_vector(2 downto 0) := "111";

constant MAX_PTD : integer := 32;
type t_schedule_active_enum is (NONE,
                                ISOCHRONOUS,
				INTERRUPT,
				ASYNCHRONOUS);
signal schedule_active : t_schedule_active_enum;
signal current_ptd : integer range 0 to MAX_PTD-1;
signal skip        : std_logic;
signal first_ptd   : integer range 0 to MAX_PTD-1;
signal last_ptd    : integer range 0 to MAX_PTD-1;

type t_dma_host_state_enum is (IDLE,
                               CHECK_SKIP,
			       TX_LPM,
			       READ_PTD_DW0,
			       READ_PTD_DW1,
			       READ_PTD_DW2,
			       FETCH_FIRST_OUT_DATA,
			       WAIT_ON_FIRST_IN_DATA,			       
			       FETCH_OUT_DATA,
			       WAIT_ON_IN_DATA,
			       READ_DATA,
			       CALC_STATUS_READ_DW3,
			       CALC_STATUS_WRITE_DW3,
			       CALC_STATUS_READ_DW2,
			       CALC_STATUS_WRITE_DW2,
			       CALC_STATUS_READ_DW1,
			       CALC_STATUS_WRITE_DW1,			       
			       CALC_STATUS_READ_DW0,
			       CALC_STATUS_WRITE_DW0);			       
signal dma_host_state : t_dma_host_state_enum;
signal pointer        : integer range 0 to FIFO_NBYTES;
signal data           : std_logic_vector(FIFO_NBYTES*8-1 downto 0);
signal endtransfer    : std_logic;
signal ptd_nextptd           : integer range 0 to MAX_PTD-1;
signal ptd_j	             : std_logic;
signal ptd_mps               : std_logic_vector(10 downto 0);
signal ptd_mult              : std_logic_vector( 1 downto 0);
signal ptd_ep_nb             : std_logic_vector( 3 downto 0);
signal ptd_dev_addr          : std_logic_vector( 6 downto 0);
signal ptd_s	             : std_logic;
signal ptd_token             : std_logic_vector( 1 downto 0);
signal ptd_eptype            : std_logic_vector( 1 downto 0);
signal ptd_reload            : std_logic_vector( 3 downto 0);
signal ptd_se	             : std_logic_vector( 1 downto 0);
signal ptd_port_nb           : std_logic_vector( 6 downto 0);
signal ptd_hub_addr          : std_logic_vector( 6 downto 0);
signal ptd_dt		     : std_logic;
signal ptd_sc		     : std_logic;
signal ptd_last_cs           : std_logic;
signal ptd_s_bytes           : std_logic_vector( 6 downto 0);

signal ptd_addr              : std_logic_vector(31 downto 0);
signal databuffer_addr       : std_logic_vector(31 downto 0);
signal data_address_offset   : unsigned(RAM_ADDR_BYTE_WIDTH-1 downto 0);
signal data_address_base     : std_logic_vector(31 downto RAM_ADDR_BYTE_WIDTH);
signal data_address_base_tmp : std_logic_vector(15 - RAM_ADDR_BYTE_WIDTH downto 0);
signal dword_offset          : std_logic_vector(1 downto 0);

signal nbytes                : integer range 0 to 4095;
signal epinfo_nbytes_int     : std_logic_vector(11 downto 0);
signal end_of_frame          : std_logic;

signal ioc                   : std_logic;
signal hc_bytesleftinframe   : integer range 0 to 8191;
signal decrement_bytes_pulse : std_logic;
signal decrement_bytes       : integer range 0 to 39;

signal high_bandwidth_check  : std_logic;
signal send_lpm              : std_logic;
signal epinfo_lowspeed_int   : std_logic;

function packet_fits_in_window(port_speed       : std_logic_vector(1 downto 0);
                               lowspeed_packet  : std_logic;
                               nbytes           : std_logic_vector(11 downto 0);
			       bytesleftinframe : integer range 0 to 8191;
			       end_of_frame     : std_logic)
         return boolean is
variable var_result : boolean;
variable var_temp   : integer range 0 to 4095;
variable var_extra  : integer range 0 to 320;
begin
  case port_speed is
    when "00" => --low-speed
      var_extra := 12;
      var_temp   := to_integer(unsigned(nbytes)) + var_extra;
    when "01" => --full-speed
      var_extra := 24;
      if lowspeed_packet = '1' then
        var_temp := (to_integer(unsigned(nbytes)) + var_extra)*8;
      else
        var_temp := to_integer(unsigned(nbytes)) + var_extra;
      end if;
    when others => -- high-speed
      if to_integer(unsigned(nbytes)) >= 128 then
        var_extra := 320;
      else
        var_extra := 192;
      end if;
      var_temp   := to_integer(unsigned(nbytes)) + var_extra;
  end case;
  var_result := TRUE;
  if (var_temp > bytesleftinframe) or (end_of_frame = '1') then
    var_result := FALSE;
  end if;
  return var_result;
end packet_fits_in_window;

begin

  proc_skip_select : process(current_ptd,schedule_active,
                             usbreg_atl_skip,usbreg_iso_skip,usbreg_int_skip,
                             usbreg_atl_last,usbreg_iso_last,usbreg_int_last,
                             usbreg_iso_first_ptd,usbreg_int_first_ptd)
  begin
    case schedule_active is
      when ISOCHRONOUS =>
        skip     <= usbreg_iso_skip(current_ptd);
	first_ptd<= to_integer(unsigned(usbreg_iso_first_ptd));
	last_ptd <= to_integer(unsigned(usbreg_iso_last));
      when INTERRUPT   =>
        skip     <= usbreg_int_skip(current_ptd);
	first_ptd<= to_integer(unsigned(usbreg_int_first_ptd));
	last_ptd <= to_integer(unsigned(usbreg_int_last));
      when others      =>
        skip     <= usbreg_atl_skip(current_ptd);
	first_ptd<= 0;
	last_ptd <= to_integer(unsigned(usbreg_atl_last));
    end case;
  end process;

  decrement_bytes_pulse <= '1' when (decrement_bytes = 0)        and 
                                    (usb_decrement_bytes_sync = '1') else
                           '0';
  
  -----------------------------------------------
  -- MAIN state machine
  -----------------------------------------------
  MAIN : process (hclk,hresetn)
  variable var_pointer : integer range 0 to FIFO_NBYTES;
  variable var_data    : std_logic_vector(FIFO_NBYTES*8-1 downto 0);
  variable var_valid_timeslot : boolean;
  variable var_remaining_nbytes : unsigned(14 downto 0);
  variable var_nbytes    : unsigned(11 downto 0);
  variable var_nbytes_x2 : unsigned(11 downto 0);
  variable var_mps       : unsigned(11 downto 0);
  variable var_data_address : unsigned(31 downto 0);
  variable var_underrun : std_logic;
  variable var_babble   : std_logic;
  variable var_xacterr  : std_logic;
  variable var_bit_alloc : integer range 0 to 7;
  variable var_bit_alloc_min  : integer range 0 to 7;
  variable var_bit_alloc_plus : integer range 0 to 7;
  variable var_nbytes_in_first_word : integer range 1 to RAM_DATAWIDTH/8;
  variable var_data_address_offset : unsigned(RAM_ADDR_BYTE_WIDTH-1 downto 0);
  variable var_decrement : integer range 1 to 8;
  variable var_epinfo_nbytes_int : std_logic_vector(11 downto 0);
  variable var_s_bytes : unsigned(RAM_ADDR_BYTE_WIDTH-1 downto 0);
  variable var_lastptd : std_logic_vector(4 downto 0);
  variable var_usbreg_frindex_min_1 : std_logic_vector(4 downto 0);
  begin
    if hresetn = '0' then
      dma_host_state        <= IDLE;
      schedule_active       <= NONE;
      current_ptd           <= 0;
      endtransfer           <= '0';
      epinfo_starttransfer  <= '0';
      data                  <= (others => '0');
      pointer               <= 0;
      
      dma_req               <= '0';
      dma_write             <= '0';
          
      ptd_nextptd           <= 0;
      ptd_j                 <= '0';
      ptd_mps               <= (others => '0');
      ptd_mult              <= (others => '0');
      ptd_ep_nb             <= (others => '0');
      ptd_dev_addr          <= (others => '0');
      ptd_s                 <= '0';
      ptd_reload            <= (others => '0');
      ptd_token             <= (others => '0');
      ptd_eptype            <= (others => '0');
      ptd_se                <= (others => '0');
      ptd_port_nb           <= (others => '0');
      ptd_hub_addr          <= (others => '0');
      ptd_dt		    <= '0';
      ptd_sc		    <= '0';
      ptd_last_cs           <= '0';
      ptd_s_bytes           <= (others => '0');
      
      nbytes                <= 0;
      epinfo_nbytes_int     <= (others => '0');
      data_address_offset   <= (others => '0');
      
      if RAM_ADDR_BYTE_WIDTH < 16 then
        data_address_base_tmp(15 - RAM_ADDR_BYTE_WIDTH downto 0) <= (others => '0');
      end if;

      --------------------------------------------
      -- TODO combine the 6 FF below into max 2 FF
      dma_iso_setint  <= '0';
      dma_int_setint  <= '0';
      dma_atl_setint  <= '0';
      dma_iso_setdone <= '0';
      dma_int_setdone <= '0';
      dma_atl_setdone <= '0';
      --------------------------------------------
      dma_atl_setptd  <= '0';
      
      end_of_frame    <= '0';
      dword_offset    <= "00";
      
      ioc             <= '0';
      hc_bytesleftinframe  <= 0;
      
      high_bandwidth_check <= '0';
      decrement_bytes <= 0;
      
      send_lpm     <= '0';
      dma_lpm_stat <= (others => '0');
      
    elsif hclk'event and hclk = '1' then
      var_data    := data;
      var_pointer := pointer;

      dma_iso_setint  <= '0';
      dma_int_setint  <= '0';
      dma_atl_setint  <= '0';
      dma_iso_setdone <= '0';
      dma_int_setdone <= '0';
      dma_atl_setdone <= '0';
      dma_atl_setptd  <= '0';
      
      if usbreg_susp_l1_on = '1' then
        send_lpm <= '1';
      end if;

      if pie_endtransfer_sync = '1' then
        endtransfer          <= '1';
	epinfo_starttransfer <= '0';
      end if;
      
      if usb_inc_frindex_toggle_sync = '1' then
        end_of_frame        <= '1';
      end if;

      if usb_decrement_bytes_sync = '1' then
        case pie_devicespeed_sync is
	  when "00" =>
	    if decrement_bytes = 0 then
	      decrement_bytes <= 39;
	    else
	      decrement_bytes <= decrement_bytes - 1;
	    end if;
	  when "01" =>
	    if decrement_bytes = 0 then
	      decrement_bytes       <= 4;
	    else
	      decrement_bytes <= decrement_bytes - 1;
	    end if;
	  when others =>
            decrement_bytes <= 0;
	end case;   
      end if;

      if usb_inc_frindex_toggle_sync = '1' then
        case pie_devicespeed_sync is
	  when "00" => -- low-speed
	    hc_bytesleftinframe <= 187;
	    decrement_bytes     <= 39;
	  when "01" => -- full-speed
            hc_bytesleftinframe <= 1500; -- This is a multiple of 8 that is closest to 1500
	    decrement_bytes     <= 4;
	  when others => -- high-speed
            hc_bytesleftinframe <= 7496; -- This is a multiple of 8 that is closest to 7500
	    decrement_bytes     <= 0;
	end case;
      elsif decrement_bytes_pulse = '1' then
        case pie_devicespeed_sync is
	  when "00" => -- low-speed
	    var_decrement := 1;
	  when "01" => -- full-speed
	    var_decrement := 1;
          when others => -- high-speed
	    var_decrement := 8;
	end case;
	if hc_bytesleftinframe > var_decrement then
	  hc_bytesleftinframe <= hc_bytesleftinframe - var_decrement;
	else
	  hc_bytesleftinframe <= 0;
	end if;
      end if;
      
      case dma_host_state is 
        when IDLE =>
---------------------------------
--BVE fix : clear endtransfer bit
	  endtransfer     <= '0';
---------------------------------
	  dword_offset    <= "00";
	  schedule_active <= NONE;
---------------------------------
--BVE fix : changed the if statement below to make sure that at least one SOF is send before 
--          sending any other USB packet
          if usbreg_run = '1' then
	    if usbreg_portsuspend = '0' then
              if end_of_frame = '1' then
	        end_of_frame <= '0';
	        if usbreg_int_enable = '1' then
	          schedule_active <= INTERRUPT;
	          current_ptd     <= to_integer(unsigned(usbreg_int_first_ptd));
	          dma_host_state  <= CHECK_SKIP;
	        elsif usbreg_iso_enable = '1' then
	          schedule_active <= ISOCHRONOUS;
	          current_ptd     <= to_integer(unsigned(usbreg_iso_first_ptd));
	          dma_host_state  <= CHECK_SKIP;
	        elsif usbreg_atl_enable = '1' then
	          schedule_active <= ASYNCHRONOUS;
	          current_ptd     <= to_integer(unsigned(usbreg_atl_cur_ptd));
	          dma_host_state  <= CHECK_SKIP;
	        end if;
	      elsif send_lpm = '1' then
     	        if packet_fits_in_window(pie_devicespeed_sync,       --port_speed
	                                 epinfo_lowspeed_int ,       --lowspeed packet 
--BVE fix : add more margin when checking for end of frame
--                                         "000000000000"      ,       --nbytes                                                     
                                         "000000100000"      ,       --nbytes
                                         hc_bytesleftinframe ,       --bytesleftinframe
                                         end_of_frame        )  then --endofframe
	          epinfo_starttransfer <= '1'; --Add check to see that this fits in the frame window
	          dma_host_state <= TX_LPM;
	        end if;
              end if;
	    end if;
	  end if;
	  
	when CHECK_SKIP =>
---------------------------------
--BVE fix : clear endtransfer bit
	  endtransfer     <= '0';
---------------------------------
	  if usbreg_portsuspend = '1' then
	    dma_host_state <= IDLE;
	    high_bandwidth_check <= '0';
	  elsif send_lpm = '1' then
     	    if packet_fits_in_window(pie_devicespeed_sync,       --port speed
	                             epinfo_lowspeed_int,        --low speed packet
--BVE fix : add more margin when checking for end of frame
--                                     "000000000000"      ,       --nbytes                                                     
                                     "000000100000"      ,       --nbytes
                                     hc_bytesleftinframe ,       --bytesleftinframe
				     end_of_frame        )  then --endofframe
	      epinfo_starttransfer <= '1'; --Add check to see that this fits in the frame window
	      dma_host_state <= TX_LPM;
	    else
	      dma_host_state       <= IDLE;
	      high_bandwidth_check <= '0';
	    end if;
	  elsif end_of_frame = '1' then
	    dma_host_state       <= IDLE;
	    high_bandwidth_check <= '0';
	  elsif skip = '1' then
	    high_bandwidth_check <= '0';
	    if current_ptd >= last_ptd then
	      case schedule_active is
	        when INTERRUPT =>
		  if usbreg_iso_enable = '1' then
	            schedule_active <= ISOCHRONOUS;
	            current_ptd     <= to_integer(unsigned(usbreg_iso_first_ptd));
		  elsif usbreg_atl_enable = '1' then
	            schedule_active <= ASYNCHRONOUS;
	            current_ptd     <= to_integer(unsigned(usbreg_atl_cur_ptd));
		  else
	            dma_host_state  <= IDLE;
		  end if;
	        when ISOCHRONOUS =>
                  if usbreg_atl_enable = '1' then
	            schedule_active <= ASYNCHRONOUS;
	            current_ptd     <= to_integer(unsigned(usbreg_atl_cur_ptd));
		  else
	            dma_host_state  <= IDLE;
		  end if;
		when others => --ASYNCHRONOUS
            	  if usbreg_atl_enable = '1' then
	            current_ptd	   <= first_ptd;
	            dma_atl_setptd <= '1';
		  else
		    dma_host_state <= IDLE;
		  end if;
	      end case;
            else
	      current_ptd <= current_ptd + 1;
	      if schedule_active = ASYNCHRONOUS then
                dma_atl_setptd  <= '1';
	      end if;
	    end if;
	  elsif (schedule_active = INTERRUPT    and usbreg_int_enable = '1') or
            	(schedule_active = ISOCHRONOUS  and usbreg_iso_enable = '1') or	
            	(schedule_active = ASYNCHRONOUS and usbreg_atl_enable = '1') then	
	    dma_host_state <= READ_PTD_DW0;
	    dword_offset   <= "00";
	    dma_req        <= '1';
	    dma_write      <= '0';
	  else
	    case schedule_active is
	      when INTERRUPT =>
	        if usbreg_iso_enable = '1' then
	    	  schedule_active <= ISOCHRONOUS;
	    	  current_ptd	  <= to_integer(unsigned(usbreg_iso_first_ptd));
	        elsif usbreg_atl_enable = '1' then
	    	  schedule_active <= ASYNCHRONOUS;
	    	  current_ptd	  <= to_integer(unsigned(usbreg_atl_cur_ptd));
	        else
	    	  dma_host_state  <= IDLE;
	        end if;
	      when ISOCHRONOUS =>
            	if usbreg_atl_enable = '1' then
	    	  schedule_active <= ASYNCHRONOUS;
	    	  current_ptd	  <= to_integer(unsigned(usbreg_atl_cur_ptd));
	        else
	    	  dma_host_state  <= IDLE;
	        end if;
	      when others => --ASYNCHRONOUS
            	if usbreg_atl_enable = '1' then
	          current_ptd	 <= first_ptd;
	          dma_atl_setptd <= '1';
		else
		  dma_host_state <= IDLE;
		end if;
	    end case;
	  end if;
	  
	when TX_LPM =>
	  if endtransfer = '1' then
	    endtransfer    <= '0';
	    send_lpm       <= '0';
	    dma_host_state <= CHECK_SKIP;
	    case pie_response_sync is
	      when ACK_HANDSHAKE   => dma_lpm_stat <= "00";
	      when NYET_HANDSHAKE  => dma_lpm_stat <= "01";
	      when STALL_HANDSHAKE => dma_lpm_stat <= "10";
	      when others          => dma_lpm_stat <= "11";
	    end case;
	  end if;
	  
	when READ_PTD_DW0 =>
          endtransfer     <= '0';
	  if dma_gnt = '1' then
	    dma_req   <= '0';
	    dma_write <= '0';
	    var_valid_timeslot := FALSE;
	    case schedule_active is
	      when ISOCHRONOUS => -- Check if uFrame is equal to current FRINDEX value
	        if (dma_rdata(15 downto 11) = usbreg_frindex(7 downto 3)) then
	          var_valid_timeslot := TRUE;
	        end if;
              when INTERRUPT => -- Bits 2:0 determine polling rate
	        case dma_rdata(10 downto 8) is
		  when "000" =>
	            var_valid_timeslot := TRUE;
		  when "001" =>
	            if (dma_rdata(          11) = usbreg_frindex(         3)) then
	              var_valid_timeslot := TRUE;
	            end if;
		  when "010" =>
                    if (dma_rdata(12 downto 11) = usbreg_frindex(4 downto 3)) then
	              var_valid_timeslot := TRUE;
	            end if;
		  when "011" =>
                    if (dma_rdata(13 downto 11) = usbreg_frindex(5 downto 3)) then
	              var_valid_timeslot := TRUE;
	            end if;
		  when "100" =>
                    if (dma_rdata(14 downto 11) = usbreg_frindex(6 downto 3)) then
	              var_valid_timeslot := TRUE;
	            end if;
		  when others =>
                    if (dma_rdata(15 downto 11) = usbreg_frindex(7 downto 3)) then
	              var_valid_timeslot := TRUE;
	            end if;
		end case;
              when others => --ASYNCHRONOUS - timeslot is always valid
	        var_valid_timeslot := TRUE;
            end case;
	    case schedule_active is
	      when ISOCHRONOUS =>
	        var_lastptd := usbreg_iso_last;
	      when INTERRUPT   =>
	        var_lastptd := usbreg_int_last;
	      when others      =>
	        var_lastptd := usbreg_atl_last;
	    end case;
	    if to_integer(unsigned(usbreg_frindex(7 downto 3))) = 0 then
              var_usbreg_frindex_min_1 := (others => '1');
	    else
	      var_usbreg_frindex_min_1 := std_logic_vector(unsigned(usbreg_frindex(7 downto 3)) - to_unsigned(1,5));
	    end if;
	    if schedule_active = ISOCHRONOUS                      and
	       dma_rdata(15 downto 11) = var_usbreg_frindex_min_1 and  
	       dma_rdata(0) = '1'                                 then
	      -- clear V-bit when FRINDEX is one bigger than when the qPTD must be executed.
	      dma_host_state <= CALC_STATUS_WRITE_DW0;
	      dword_offset   <= "00";
	      dma_req   <= '1';
	      dma_write <= '1';
	      var_data(63 downto 1) := dma_rdata(63 downto 1);
	      var_data(0)           := '0';
	      dma_iso_setdone <= '1';
	      if ioc = '1' then --Interrupt on Complete set
	        dma_iso_setint <= '1';
	      end if;
	    elsif dma_rdata(0) = '1' and --valid bit set to one 
	          var_valid_timeslot then
	      if dma_rdata( 5 downto 1) > var_lastptd then
	        ptd_nextptd  <= 0;
              else
	        ptd_nextptd  <= to_integer(unsigned(dma_rdata( 5 downto 1)));
	      end if;
              ptd_j        <= dma_rdata( 7);
	      ptd_mps      <= dma_rdata(26 downto 16);
	      if high_bandwidth_check = '0' then -- only take mult from memory if it is the first time we get here.
	                                         -- If this process is reentered due to a mult > 1, keep the current value.
	        ptd_mult     <= dma_rdata(29 downto 28);
	      end if;
	      ptd_ep_nb    <= dma_rdata(35 downto 32);
	      ptd_dev_addr <= dma_rdata(42 downto 36);
	      ptd_s        <= dma_rdata(43);
	      ptd_reload   <= dma_rdata(47 downto 44);
	      ptd_se(1)    <= dma_rdata(49); -- only msb is used
	      ptd_port_nb  <= dma_rdata(56 downto 50);
	      ptd_hub_addr <= dma_rdata(63 downto 57);
	      ptd_s_bytes  <= (others => '0'); --clear this

	      var_nbytes(11)              := '0';
	      var_nbytes(10 downto 0)     := unsigned(dma_rdata(26 downto 16));
	      var_nbytes_x2(11 downto 1)  := unsigned(dma_rdata(26 downto 16));
	      var_nbytes_x2(0)            := '0';
	      if schedule_active = ISOCHRONOUS then
                case dma_rdata(29 downto 28) is -- ptd_mult
	          when "11" =>
	            epinfo_nbytes_int <= std_logic_vector(var_nbytes + var_nbytes_x2);
	          when "10" =>
	            epinfo_nbytes_int <= std_logic_vector(var_nbytes_x2);
	          when others =>
	            epinfo_nbytes_int <= std_logic_vector(var_nbytes);
	        end case;
	      else
	        epinfo_nbytes_int <= std_logic_vector(var_nbytes);
	      end if;

	      dma_host_state <= READ_PTD_DW1;
	      dword_offset   <= "01";
	      dma_req   <= '1';
	      dma_write <= '0';
	    else
	      dma_host_state  <= CHECK_SKIP;
	      if dma_rdata(7) = '1' then --jump bit set to one
	        if dma_rdata( 5 downto 1) <= var_lastptd then
	          current_ptd <= to_integer(unsigned(dma_rdata(5 downto 1)));
		else
		  current_ptd <= 0;
		end if;
	        if schedule_active = ASYNCHRONOUS then
                  dma_atl_setptd  <= '1';
	        end if;
	      else
	        if current_ptd >= last_ptd then
	          case schedule_active is
	            when INTERRUPT =>
		      if usbreg_iso_enable = '1' then
	                schedule_active <= ISOCHRONOUS;
	                current_ptd     <= to_integer(unsigned(usbreg_iso_first_ptd));
		      elsif usbreg_atl_enable = '1' then
	                schedule_active <= ASYNCHRONOUS;
	                current_ptd     <= to_integer(unsigned(usbreg_atl_cur_ptd));
		      else
	                dma_host_state  <= IDLE;
		      end if;
	            when ISOCHRONOUS =>
                      if usbreg_atl_enable = '1' then
	                schedule_active <= ASYNCHRONOUS;
	                current_ptd     <= to_integer(unsigned(usbreg_atl_cur_ptd));
		      else
	                dma_host_state  <= IDLE;
		      end if;
		    when others => --ASYNCHRONOUS
            	      if usbreg_atl_enable = '1' then
	                current_ptd    <= first_ptd;
	                dma_atl_setptd <= '1';
	 	      else
		        dma_host_state <= IDLE;
		      end if;
	          end case;
                else
	          current_ptd <= current_ptd + 1;
	          if schedule_active = ASYNCHRONOUS then
                    dma_atl_setptd  <= '1';
	          end if;
	        end if;
              end if;
	    end if;
	  end if;
	    
	when READ_PTD_DW1 =>
	  if dma_gnt = '1' then
	    dma_req               <= '0';
	    dma_write             <= '0';
            if RAM_ADDR_BYTE_WIDTH < 16 then
              data_address_base_tmp(15 - RAM_ADDR_BYTE_WIDTH downto 0) 
	                          <= dma_rdata(31 downto 16 + RAM_ADDR_BYTE_WIDTH);
            end if;
	    if dma_rdata(58) = '1' then
	      ptd_token           <= "11"; --PING token to be sent
	    else
	      ptd_token	          <= dma_rdata(48 downto 47);
	    end if;
	    ptd_eptype            <= dma_rdata(50 downto 49);
	    ptd_dt                <= dma_rdata(57);
	    ptd_sc                <= dma_rdata(59);
	    var_remaining_nbytes  := unsigned(dma_rdata(14 downto  0)) -  --ptd_nrbytestotransfer
	                             unsigned(dma_rdata(46 downto 32));   --ptd_nrbytestransferred
	    var_data_address(31 downto 16) := unsigned(usbreg_payload_base);
	    var_data_address(15 downto  0) := unsigned(dma_rdata(31 downto 16));
	    
	    var_data_address_offset(RAM_ADDR_BYTE_WIDTH-1 downto 0)
	      := to_unsigned(
	         (to_integer(var_data_address(RAM_ADDR_BYTE_WIDTH-1 downto 0)) +  --ptd_datastartaddress
	          to_integer(unsigned(dma_rdata(46 downto 32))))                  --ptd_nrbytestransferred
		 ,RAM_ADDR_BYTE_WIDTH);  
                                                     
            data_address_offset(RAM_ADDR_BYTE_WIDTH-1 downto 0) <= var_data_address_offset;
--BVE : bug fix for Aruba. If MPS is smaller than 188 bytes and BytesToTransfer is equal to MPS, ptd_se must be set to ALL and not to BEGIN
--            if to_integer(var_remaining_nbytes) < to_integer(unsigned(epinfo_nbytes_int)) then
            if to_integer(var_remaining_nbytes) <= to_integer(unsigned(epinfo_nbytes_int)) then
              nbytes                <= to_integer(var_remaining_nbytes);
              var_epinfo_nbytes_int := std_logic_vector(var_remaining_nbytes(11 downto 0));
	      if schedule_active = ISOCHRONOUS then
	        ptd_se(0) <= '1'; --Indicates that this is ALL the data. 
		                  --Later on this can still be changed in END if a previous token has been sent
	      else
	        ptd_se(0) <= '0';
	      end if;
            else
              nbytes                <= to_integer(unsigned(epinfo_nbytes_int));
              var_epinfo_nbytes_int := epinfo_nbytes_int;
	      ptd_se(0) <= '0'; --Indicates that this is either the beginning of middle of the data. 
		                --Later this will be changed into MID if a previous token has been sent or BEGIN when no token is sent.
            end if;
	    epinfo_nbytes_int <= var_epinfo_nbytes_int;

            ptd_last_cs <= '0'; -- clear the bit to make sure that it is only set for Periodic CSPLIT
            if dma_rdata(63) = '0' then -- Active bit not set, go to next ptd.
	      dma_host_state  <= CHECK_SKIP;
	      if ptd_j = '1' then --jump bit set to one
	        current_ptd <= ptd_nextptd;
	        if schedule_active = ASYNCHRONOUS then
                  dma_atl_setptd  <= '1';
	        end if;
	      else
	        if current_ptd >= last_ptd then
	          case schedule_active is
	            when INTERRUPT =>
		      if usbreg_iso_enable = '1' then
	                schedule_active <= ISOCHRONOUS;
	                current_ptd     <= to_integer(unsigned(usbreg_iso_first_ptd));
		      elsif usbreg_atl_enable = '1' then
	                schedule_active <= ASYNCHRONOUS;
	                current_ptd     <= to_integer(unsigned(usbreg_atl_cur_ptd));
		      else
	                dma_host_state  <= IDLE;
		      end if;
	            when ISOCHRONOUS =>
                      if usbreg_atl_enable = '1' then
	                schedule_active <= ASYNCHRONOUS;
	                current_ptd     <= to_integer(unsigned(usbreg_atl_cur_ptd));
		      else
	                dma_host_state  <= IDLE;
		      end if;
		    when others => --ASYNCHRONOUS
            	      if usbreg_atl_enable = '1' then
	                current_ptd	<= first_ptd;
	                dma_atl_setptd  <= '1';
		      else
		        dma_host_state  <= IDLE;
		      end if;
	          end case;
                else
	          current_ptd <= current_ptd + 1;
	          if schedule_active = ASYNCHRONOUS then
                    dma_atl_setptd  <= '1';
	          end if;
	        end if;
              end if;
	    elsif schedule_active /= ASYNCHRONOUS and pie_devicespeed_sync = "10" then
	      dma_host_state <= READ_PTD_DW2;
	      dword_offset   <= "10";
	      dma_req        <= '1';
	      dma_write      <= '0';	      
	    else
	      if dma_rdata(48 downto 47) = "01" then -- IN token
	        if ptd_s = '1' and dma_rdata(59) = '0' then -- start-split IN token
		  dma_host_state <= WAIT_ON_IN_DATA; -- no data expected to receive.
		elsif to_integer(var_data_address_offset(2 downto 0)) = 0 then
                  dma_host_state <= WAIT_ON_IN_DATA;
		else
                  dma_host_state <= WAIT_ON_FIRST_IN_DATA;
	          dma_req        <= '1';
	          dma_write      <= '0';	      
		end if;
	      else 
	        if (ptd_s = '1' and dma_rdata(59) = '1') or -- complete-split OUT token
		   (dma_rdata(14 downto 0) = dma_rdata(46 downto 32)) then --no data to be transmitted
		  dma_host_state <= FETCH_OUT_DATA;
		  nbytes         <= 0;               -- no data to be transmitted
		else
                  dma_host_state <= FETCH_FIRST_OUT_DATA;
	          dma_req        <= '1';
	          dma_write      <= '0';	      
		end if;
	      end if;
--BVE : Add a check on the portsuspend bit as well
     	      if usbreg_portsuspend = '0' and
                 packet_fits_in_window(pie_devicespeed_sync,     --port speed
	                               epinfo_lowspeed_int,      --low speed packet
                                       var_epinfo_nbytes_int,     --nbytes
                                       hc_bytesleftinframe ,     --bytesleftinframe
				       end_of_frame        )  then --endofframe
	        epinfo_starttransfer <= '1'; --Add check to see that this fits in the frame window
	      else
	        dma_host_state <= IDLE;
              end if;
	    end if;
	  end if;
	    
	when READ_PTD_DW2 =>
	  if dma_gnt = '1' then
	    dma_req                     <= '0';
	    dma_write                   <= '0';
	    var_data_address_offset     := unsigned(data_address_offset);
	    if schedule_active = INTERRUPT and ptd_s = '1' and ptd_sc = '1' then -- Complete split interrupt 
	      var_s_bytes(RAM_ADDR_BYTE_WIDTH-1 downto 8) := (others => '0');
	      var_s_bytes(7 downto 0)                     := unsigned(dma_rdata(47 downto 40));
              var_data_address_offset(RAM_ADDR_BYTE_WIDTH-1 downto 0) := var_data_address_offset + var_s_bytes;
	      nbytes            <= nbytes  - to_integer(var_s_bytes(7 downto 0));
	      epinfo_nbytes_int <= std_logic_vector(unsigned(epinfo_nbytes_int) 
	                                          - unsigned(var_s_bytes(11 downto 0)));
	      ptd_s_bytes       <= std_logic_vector(var_s_bytes(6 downto 0));
	    end if;
            data_address_offset <= var_data_address_offset;
	    
            var_bit_alloc := to_integer(unsigned(usbreg_frindex(2 downto 0)));
	    if var_bit_alloc = 0 then
	      var_bit_alloc_min := 7;
	    else
	      var_bit_alloc_min := var_bit_alloc - 1;
	    end if;
	    if var_bit_alloc = 7 then
	      var_bit_alloc_plus := 0;
	    else
	      var_bit_alloc_plus := var_bit_alloc + 1;
	    end if;
	    if ((dma_rdata(var_bit_alloc) = '1')      and (ptd_s = '0')) or --normal periodic operation
	       ((dma_rdata(var_bit_alloc) = '1')      and (ptd_s = '1') and (ptd_sc = '0')) or --start-split operation 
	       ((dma_rdata(var_bit_alloc + 32) = '1') and (ptd_s = '1') and (ptd_sc = '1')) then --complete split operation
	      if ptd_token = "01" then -- IN token
	        if ptd_s = '1' and ptd_sc = '0' then -- start-split IN token
		  dma_host_state <= WAIT_ON_IN_DATA; -- no data expected to receive.
		elsif to_integer(var_data_address_offset(2 downto 0)) = 0 then
                  dma_host_state <= WAIT_ON_IN_DATA; -- data is 64-bit aligned
		else
                  dma_host_state <= WAIT_ON_FIRST_IN_DATA;
	          dma_req        <= '1';
	          dma_write      <= '0';	      
		end if;
	      else 
	        if ptd_s = '1' and ptd_sc = '1' then -- complete-split OUT token
		  dma_host_state <= FETCH_OUT_DATA;
		  nbytes         <= 0;               -- no data to be transmitted
		else
                  dma_host_state <= FETCH_FIRST_OUT_DATA;
	          dma_req        <= '1';
	          dma_write      <= '0';	      
		end if;
	      end if;
--BVE : Add a check on the portsuspend bit as well
     	      if usbreg_portsuspend = '0' and
                 packet_fits_in_window(pie_devicespeed_sync,     --port speed
	                               epinfo_lowspeed_int,      --low speed packet
                                       epinfo_nbytes_int   ,     --nbytes
                                       hc_bytesleftinframe ,     --bytesleftinframe
				       end_of_frame        )  then --endofframe
	        epinfo_starttransfer <= '1'; --Add check to see that this fits in the frame window
	      else
	        dma_host_state <= IDLE;
              end if;

	    else
	      dma_host_state  <= CHECK_SKIP;
	      if ptd_j = '1' then --jump bit set to one
	        current_ptd <= ptd_nextptd;
		---- 3 lines below are removed because it never gets here when on the async list
	        --if schedule_active = ASYNCHRONOUS then 
                --  dma_atl_setptd  <= '1';
	        --end if;
	      else
	        if current_ptd >= last_ptd then
	          case schedule_active is
	            when INTERRUPT =>
		      if usbreg_iso_enable = '1' then
	                schedule_active <= ISOCHRONOUS;
	                current_ptd     <= to_integer(unsigned(usbreg_iso_first_ptd));
		      elsif usbreg_atl_enable = '1' then
	                schedule_active <= ASYNCHRONOUS;
	                current_ptd     <= to_integer(unsigned(usbreg_atl_cur_ptd));
		      else
	                dma_host_state  <= IDLE;
		      end if;
	            when ISOCHRONOUS =>
                      if usbreg_atl_enable = '1' then
	                schedule_active <= ASYNCHRONOUS;
	                current_ptd     <= to_integer(unsigned(usbreg_atl_cur_ptd));
		      else
	                dma_host_state  <= IDLE;
		      end if;
		    when others => --ASYNCHRONOUS
            	      if usbreg_atl_enable = '1' then
	                current_ptd	<= first_ptd;
	                dma_atl_setptd  <= '1';
		      else
		        dma_host_state  <= IDLE;
		      end if;
	          end case;
                else
	          current_ptd <= current_ptd + 1;
	          if schedule_active = ASYNCHRONOUS then
                    dma_atl_setptd  <= '1';
	          end if;
	        end if;
              end if;
	    end if;
	    
	    if schedule_active = ISOCHRONOUS then
	      if ptd_token = "00" then -- isochronous OUT
                if ptd_se(0) = '1' then -- Check if there was a previous SSplit sent
	          if dma_rdata(var_bit_alloc_min) = '0' then -- no SSplit in previous uFrame
		    ptd_se <= "11"; --SE field to be set to ALL
		  else
		    ptd_se <= "01"; --SE field to be set to END
		  end if;
		else
	          if dma_rdata(var_bit_alloc_min) = '0' then -- no SSplit in previous uFrame
		    ptd_se <= "10"; --SE field to be set to BEGIN
		  else
		    ptd_se <= "00"; --SE field to be set to MID
		  end if;
		end if;
	      else                  -- for all other endpoints this must be set to zero.
	        ptd_se <= "00";
	      end if; 
	    end if;
	    
	    if (dma_rdata(var_bit_alloc + 32) = '1') and (ptd_s = '1') and (ptd_sc = '1') then
	      if dma_rdata(var_bit_alloc_plus + 32) = '0' then
	        ptd_last_cs <= '1';
	      end if;
	    end if;
	  end if;
	      
        when FETCH_FIRST_OUT_DATA =>
	  if dma_gnt = '1' then
            dma_req   <= '0';
            dma_write <= '0';
	    data_address_offset(RAM_ADDR_BYTE_WIDTH-1 downto log2(RAM_DATAWIDTH/8)) 
	        <= data_address_offset(RAM_ADDR_BYTE_WIDTH-1 downto log2(RAM_DATAWIDTH/8)) + 1;
	    var_nbytes_in_first_word := RAM_DATAWIDTH/8 - to_integer(data_address_offset(2 downto 0)); --size of data_address must also be derived from the constants
            for i in 0 to RAM_DATAWIDTH-1 loop
	      if i < var_nbytes_in_first_word * 8 then
                var_data(i) := dma_rdata(i+(8*to_integer(data_address_offset(2 downto 0))));
              else
	        exit;
	      end if;
            end loop;
            if nbytes > var_nbytes_in_first_word then
              nbytes      <= nbytes - var_nbytes_in_first_word;
              var_pointer := var_pointer + var_nbytes_in_first_word;
              dma_req   <= '1';
              dma_write <= '0';
            else
              nbytes      <= 0;
              var_pointer := var_pointer + nbytes;
            end if;
	    dma_host_state <= FETCH_OUT_DATA;
          end if;

	when FETCH_OUT_DATA =>
          if pie_txdatafetched_sync = '1' then
            var_data(FIFO_NBYTES*8-1-USB_DATAWIDTH downto 0) 
                                          := var_data(FIFO_NBYTES*8-1 downto USB_DATAWIDTH);
            var_data(FIFO_NBYTES*8-1 downto FIFO_NBYTES*8-USB_DATAWIDTH) 
                                          := (others => '0');
	    if var_pointer > USB_DATAWIDTH/8 then
              var_pointer := var_pointer - USB_DATAWIDTH/8;
	    else
	      var_pointer := 0;
	    end if;
          end if;
          if dma_gnt = '1' then
            dma_req   <= '0';
            dma_write <= '0';
	    data_address_offset(RAM_ADDR_BYTE_WIDTH-1 downto log2(RAM_DATAWIDTH/8)) 
	        <= data_address_offset(RAM_ADDR_BYTE_WIDTH-1 downto log2(RAM_DATAWIDTH/8)) + 1;
            for i in 0 to RAM_DATAWIDTH-1 loop
              var_data(var_pointer*8+i) := dma_rdata(i);
            end loop;
            if nbytes > (RAM_DATAWIDTH/8)-1 then
              nbytes      <= nbytes - RAM_DATAWIDTH/8;
              var_pointer := var_pointer + RAM_DATAWIDTH/8;
            else
              nbytes      <= 0;
              var_pointer := var_pointer + nbytes;
            end if;
          end if;
          if var_pointer <= FIFO_NBYTES - (RAM_DATAWIDTH/8) and nbytes /= 0 then 
            dma_req   <= '1';
            dma_write <= '0';
          elsif endtransfer = '1' then 
	    dma_req        <= '1';
	    dma_write      <= '0';
	    if (schedule_active /= ISOCHRONOUS) or
	       (ptd_s = '1' and ptd_sc = '0')	then --start-split transaction
              dma_host_state <= CALC_STATUS_READ_DW1;
	      dword_offset   <= "01";
	    else
	      dma_host_state <= CALC_STATUS_READ_DW2;
	      dword_offset   <= "10";
	    end if;
	  end if;
  	  
	when WAIT_ON_FIRST_IN_DATA =>
	  if dma_gnt = '1' then
	    dma_req	   <= '0';
	    dma_write	   <= '0';		
	    var_nbytes_in_first_word := to_integer(data_address_offset(2 downto 0)); --size of data_address must also be derived from the constants
            var_data(RAM_DATAWIDTH-1 downto 0) := dma_rdata;
	    var_pointer    := to_integer(data_address_offset(2 downto 0));
--	    nbytes         <= nbytes + to_integer(data_address_offset(2 downto 0));
	    dma_host_state <= WAIT_ON_IN_DATA;
	  end if;
	  
	when WAIT_ON_IN_DATA =>
          dword_offset    <= "00";
          if dma_gnt = '1' then
	    data_address_offset(RAM_ADDR_BYTE_WIDTH-1 downto log2(RAM_DATAWIDTH/8)) 
	        <= data_address_offset(RAM_ADDR_BYTE_WIDTH-1 downto log2(RAM_DATAWIDTH/8)) + 1;
            var_data(FIFO_NBYTES*8-1-RAM_DATAWIDTH downto 0) 
                                         := var_data(FIFO_NBYTES*8-1 downto RAM_DATAWIDTH);
            var_data(FIFO_NBYTES*8-1 downto FIFO_NBYTES*8-RAM_DATAWIDTH) 
                                         := (others => '0');
            dma_req     <= '0';
            dma_write   <= '0';
            if var_pointer >= RAM_DATAWIDTH/8 then
              var_pointer := var_pointer - RAM_DATAWIDTH/8;
            else
              var_pointer := 0;
            end if;
          end if;
          if pie_rxdatavalid_sync = '1' then
            for i in 0 to USB_DATAWIDTH-1 loop
              var_data(var_pointer*8+i) := pie_rxdata_sync(i);
            end loop;
            if nbytes > (USB_DATAWIDTH/8)-1 then
              nbytes      <= nbytes - USB_DATAWIDTH/8;
              var_pointer := var_pointer + USB_DATAWIDTH/8;
            else
              nbytes      <= 0;
              var_pointer := var_pointer + nbytes;
            end if;
--            var_pointer := var_pointer + USB_DATAWIDTH/8;
--	    if var_pointer > nbytes then
--	      var_pointer := nbytes;
--	    end if;
          end if;       
          if var_pointer >= RAM_DATAWIDTH/8 then
            dma_req   <= '1';
            dma_write <= '1'; 
          elsif endtransfer = '1' then
            if var_pointer /= 0 then -- do a read/modify/write operation !!!
              dma_req        <= '1';
              dma_write      <= '0';
	      dma_host_state <= READ_DATA;
            elsif pointer = 0 then
	      dma_req        <= '1';
	      dma_write      <= '0';
	      if (schedule_active = ASYNCHRONOUS   ) or --async transaction
	         (schedule_active = INTERRUPT and       --normal interrupt transaction 
		  (ptd_s = '0' or ptd_token = "00")) or --split interrupt out transaction
	         (ptd_s = '1' and ptd_sc = '0')   then --start-split transaction
                dma_host_state <= CALC_STATUS_READ_DW1;
		dword_offset   <= "01";
              elsif (schedule_active = INTERRUPT) or   --complete-split interrupt IN transaction
	            (( pie_devicespeed_sync       /= "10" or --ISO IN token
		       usbreg_frindex(2 downto 0) = "000" or
	               usbreg_frindex(2 downto 0) = "001" or
	              (usbreg_frindex(2 downto 0) = "010" and ptd_s = '1' and ptd_sc = '1'))) then
	        dma_host_state <= CALC_STATUS_READ_DW2;
		dword_offset   <= "10";
	      else
	        dma_host_state <= CALC_STATUS_READ_DW3;
		dword_offset   <= "11";
	      end if;
            end if;
	  end if;

        when READ_DATA =>
	  if dma_gnt = '1' then
            dma_req        <= '1';
            dma_write      <= '1';
	    for i in RAM_DATAWIDTH-1 downto 0 loop
	      if i >= var_pointer*8 then
	        var_data(i) := dma_rdata(i);
              end if;
	    end loop;
	    dma_host_state <= WAIT_ON_IN_DATA;
	  end if;
	  
        when CALC_STATUS_READ_DW3  =>
	  if dma_gnt = '1' then
	    dma_host_state <= CALC_STATUS_WRITE_DW3;
            dword_offset   <= "11";
	    dma_req        <= '1';
            dma_write      <= '1';
	    var_data(63 downto 0) := dma_rdata;
	    if (pie_response_sync = MDATA_DATABUF_ERROR) or
	       (pie_response_sync = ACK_HANDSHAKE)       then
	      if ptd_s = '1' then
                case usbreg_frindex(2 downto 0) is
	          when "111" =>
	            var_data(39 downto 32) := pie_rx_nbytes_sync(7 downto 0);
	          when "110" =>
	            var_data(31 downto 24) := pie_rx_nbytes_sync(7 downto 0);
	          when "101" =>
	            var_data(23 downto 16) := pie_rx_nbytes_sync(7 downto 0);
	          when "100" =>
	            var_data(15 downto  8) := pie_rx_nbytes_sync(7 downto 0);
	          when others => --"011" - other values should never reach this point
	            var_data( 7 downto  0) := pie_rx_nbytes_sync(7 downto 0);
	        end case;
	      else
                case usbreg_frindex(2 downto 0) is
	          when "111" =>
	            var_data(63 downto 52) := pie_rx_nbytes_sync(11 downto 0);
	          when "110" =>
	            var_data(51 downto 40) := pie_rx_nbytes_sync(11 downto 0);
	          when "101" =>
	            var_data(39 downto 28) := pie_rx_nbytes_sync(11 downto 0);
	          when "100" =>
	            var_data(27 downto 16) := pie_rx_nbytes_sync(11 downto 0);
	          when "011" =>
	            var_data(15 downto  4) := pie_rx_nbytes_sync(11 downto 0);
	          when others => --"010" - other values should never reach this point
	            var_data( 3 downto  0) := pie_rx_nbytes_sync(11 downto 8);
	        end case;
	      end if;
	    end if;
	  end if;  
	  
        when CALC_STATUS_WRITE_DW3 =>
	  if dma_gnt = '1' then
	    dma_host_state <= CALC_STATUS_READ_DW2;
            dword_offset   <= "10";
	    dma_req        <= '1';
            dma_write      <= '0';
	  end if;
	  
        when CALC_STATUS_READ_DW2  =>
	  if dma_gnt = '1' then
	    dma_host_state <= CALC_STATUS_WRITE_DW2;
            dword_offset   <= "10";
	    dma_req        <= '1';
            dma_write      <= '1';
	    var_data(63 downto 0) := dma_rdata;
	    case usbreg_frindex(2 downto 0) is
	      when "111" =>
    	        var_underrun := dma_rdata(31);
	        var_babble   := dma_rdata(30);
	        var_xacterr  := dma_rdata(29);
	      when "110" =>
    	        var_underrun := dma_rdata(28);
	        var_babble   := dma_rdata(27);
	        var_xacterr  := dma_rdata(26);
	      when "101" =>
    	        var_underrun := dma_rdata(25);
	        var_babble   := dma_rdata(24);
	        var_xacterr  := dma_rdata(23);
	      when "100" =>
    	        var_underrun := dma_rdata(22);
	        var_babble   := dma_rdata(21);
	        var_xacterr  := dma_rdata(20);
	      when "011" =>
    	        var_underrun := dma_rdata(19);
	        var_babble   := dma_rdata(18);
	        var_xacterr  := dma_rdata(17);
	      when "010" =>
    	        var_underrun := dma_rdata(16);
	        var_babble   := dma_rdata(15);
	        var_xacterr  := dma_rdata(14);
	      when "001" =>
    	        var_underrun := dma_rdata(13);
	        var_babble   := dma_rdata(12);
	        var_xacterr  := dma_rdata(11);
	      when others =>
    	        var_underrun := dma_rdata(10);
	        var_babble   := dma_rdata( 9);
	        var_xacterr  := dma_rdata( 08);
	    end case;
	    case pie_response_sync is
	      when XACT_ERROR      =>
		var_xacterr := '1';
	      when MDATA_DATABUF_ERROR =>
	        if ptd_token = "00" then --only for OUT tokens
		  var_underrun := '1';
		end if;
	      when BABBLE_ERROR    =>
                var_babble   := '1';
	      when ERR_HANDSHAKE   =>
		var_xacterr := '1';
	      when ACK_HANDSHAKE   =>
                null; --succesfull transfer
	      when STALL_HANDSHAKE =>
                var_babble   := '1';
	      when NAK_HANDSHAKE   =>
                null;
	      when others => --NYET_HANDSHAKE  =>
	        null;
	    end case;
	    if pie_devicespeed_sync /= "10" then --if speed is not HS
	      if ptd_token   = "01" and --only for IN tokens
		 var_xacterr = '0'  and 
		 var_babble  = '0'  then
	        var_data(43 downto 32) := pie_rx_nbytes_sync(11 downto 0);
	      end if;
	      var_data(10) := var_underrun;
	      var_data( 9) := var_babble;
	      var_data( 8) := var_xacterr;
	    elsif ptd_s = '1' then
	      if schedule_active = ISOCHRONOUS then
                case usbreg_frindex(2 downto 0) is
	          when "111" =>
		    var_data(31) := var_underrun;
		    var_data(30) := var_babble;
		    var_data(29) := var_xacterr;
	          when "110" =>
		    var_data(28) := var_underrun;
		    var_data(27) := var_babble;
		    var_data(26) := var_xacterr;
	          when "101" =>
		    var_data(25) := var_underrun;
		    var_data(24) := var_babble;
		    var_data(23) := var_xacterr;
	          when "100" =>
	            var_data(22) := var_underrun;
	            var_data(21) := var_babble;
	            var_data(20) := var_xacterr;
	          when "011" =>
	            var_data(19) := var_underrun;
	            var_data(18) := var_babble;
	            var_data(17) := var_xacterr;
	          when "010" =>
	            if ptd_token = "01"  and --only for IN tokens
		       var_xacterr = '0' and 
		       var_babble  = '0' then
	              var_data(63 downto 56) := pie_rx_nbytes_sync(7 downto 0);
	            end if;
	            var_data(16) := var_underrun;
	            var_data(15) := var_babble;
	            var_data(14) := var_xacterr;
	          when "001" =>
	            if ptd_token = "01"  and --only for IN tokens
		       var_xacterr = '0' and 
		       var_babble  = '0' then
	              var_data(55 downto 48) := pie_rx_nbytes_sync(7 downto 0);
	            end if;
	            var_data(13) := var_underrun;
	            var_data(12) := var_babble;
	            var_data(11) := var_xacterr;
	          when others =>
	            if ptd_token = "01"  and --only for IN tokens
		       var_xacterr = '0' and 
		       var_babble  = '0' then
	              var_data(47 downto 40) := pie_rx_nbytes_sync(7 downto 0);
	            end if;
	            var_data(10) := var_underrun;
	            var_data( 9) := var_babble;
	            var_data( 8) := var_xacterr;
	        end case;
	      else
	        if pie_response_sync = MDATA_DATABUF_ERROR and ptd_last_cs = '0' then
	          var_data(47 downto 40) := pie_rx_nbytes_sync(7 downto 0);
		else
		  var_data(47 downto 40) := (others => '0');
		end if;
	      end if;
	    else
              case usbreg_frindex(2 downto 0) is
	        when "111" =>
		  var_data(31) := var_underrun;
		  var_data(30) := var_babble;
		  var_data(29) := var_xacterr;
	        when "110" =>
		  var_data(28) := var_underrun;
		  var_data(27) := var_babble;
		  var_data(26) := var_xacterr;
	        when "101" =>
		  var_data(25) := var_underrun;
		  var_data(24) := var_babble;
		  var_data(23) := var_xacterr;
	        when "100" =>
		  var_data(22) := var_underrun;
		  var_data(21) := var_babble;
		  var_data(20) := var_xacterr;
		when "011" =>
		  var_data(19) := var_underrun;
		  var_data(18) := var_babble;
		  var_data(17) := var_xacterr;
		when "010" =>
	          if ptd_token   = "01" and --only for IN tokens
		     var_xacterr = '0'  and 
		     var_babble  = '0'  then
		    var_data(63 downto 56) := pie_rx_nbytes_sync( 7 downto 0);
		  end if;
		  var_data(16) := var_underrun;
		  var_data(15) := var_babble;
		  var_data(14) := var_xacterr;
		when "001" =>
	          if ptd_token   = "01" and --only for IN tokens
		     var_xacterr = '0'  and 
		     var_babble  = '0'  then
		    var_data(55 downto 44) := pie_rx_nbytes_sync(11 downto 0);
		  end if;
		  var_data(13) := var_underrun;
		  var_data(12) := var_babble;
		  var_data(11) := var_xacterr;
	        when others =>
	          if ptd_token   = "01" and --only for IN tokens
		     var_xacterr = '0'  and 
		     var_babble  = '0'  then
		    var_data(43 downto 32) := pie_rx_nbytes_sync(11 downto 0);
		  end if;
		  var_data(10) := var_underrun;
		  var_data( 9) := var_babble;
		  var_data( 8) := var_xacterr;
	      end case;
	    end if;
	    
	  end if;  
	  
        when CALC_STATUS_WRITE_DW2 =>
	  if dma_gnt = '1' then
	    dma_host_state <= CALC_STATUS_READ_DW1;
	    dword_offset   <= "01";
	    dma_req        <= '1';
            dma_write      <= '0';
	  end if;
	  
        when CALC_STATUS_READ_DW1 =>
	  if dma_gnt = '1' then
	    dma_req        <= '1';
            dma_write      <= '1';
	    var_data(63 downto 0) := dma_rdata;
	    ioc            <= dma_rdata(15);
	    case pie_response_sync is
	      when XACT_ERROR      =>
	        dma_host_state <= CALC_STATUS_WRITE_DW0;
	        ----------------------------------------
	        -- Handling of Active and Halted bit
		----------------------------------------
	        if dma_rdata(56 downto 55) = "01" then --Cerr field decrements to zero
		  var_data(63) := '0';                 --Active bit is cleared
		  var_data(62) := '1';                 --Halted bit is set
	          dma_host_state <= CALC_STATUS_WRITE_DW1;
		elsif ptd_s = '1' and ptd_sc = '1' then                                -- Complete split with error
                  ptd_mult <= std_logic_vector(unsigned(ptd_mult) + to_unsigned(1,2)); -- Requires an immediate retry
		end if;

		----------------------------------------
	        -- Handling of Babble bit
		----------------------------------------
		-- nothing to change
		
		----------------------------------------
	        -- Handling of XactErr bit
		----------------------------------------
		var_data(60) := '1';                    --Xact bit is set

		----------------------------------------
	        -- Handling of SC bit
		----------------------------------------
		if schedule_active = ASYNCHRONOUS then -- A NAK on a bulk or control endpoint clears the SC bit
		  var_data(59) := '0';
		end if;
		
		----------------------------------------
	        -- Handling of PING bit (and Token field)
		----------------------------------------
		if schedule_active = ASYNCHRONOUS and 
		   pie_devicespeed_sync = "10"    and
		   ptd_token = "00"               and 
		   ptd_s = '0'                    then -- HS Bulk or Control OUT token
		  var_data(58)           := '1';
                end if;
		
	        ----------------------------------------
	        -- Handling of Data Toggle bit
		----------------------------------------
		-- nothing to change
		
	        ----------------------------------------
	        -- Handling of Cerr field
		----------------------------------------
	        if dma_rdata(56 downto 55) /= "00" then
		  var_data(56 downto 55) := std_logic_vector(unsigned(dma_rdata(56 downto 55))
		                            - to_unsigned(1,2)); -- decrement Cerr field
		end if;
		
		----------------------------------------
	        -- Handling of NakCnt field
		----------------------------------------
		-- nothing to change
		
	        ----------------------------------------
	        -- Handling of NrBytesTransferred field
		----------------------------------------
		-- nothing to change
		
	      when MDATA_DATABUF_ERROR   =>
	        --For IN direction, this indicates that an MDATA PID is received.
		--This will only be done for ISO and INT Complete Split transactions
		--For OUT direction, this indicates that the dma could not supply data fast enough.
		--No update required. Should another bit be set as a kind of indication during debugging ?
		--
	        dma_host_state <= CALC_STATUS_WRITE_DW0;
	        ----------------------------------------
	        -- Handling of Active and Halted bit
		----------------------------------------
		-- If MDATA received on last CS indicate XactErr
		if ptd_last_cs = '1' and
	           dma_rdata(56 downto 55) = "01" then --Cerr field decrements to zero
		  var_data(63) := '0';                 --Active bit is cleared
		  var_data(62) := '1';                 --Halted bit is set
	          dma_host_state <= CALC_STATUS_WRITE_DW1;
		end if;
		
		----------------------------------------
	        -- Handling of Babble bit
		----------------------------------------
		-- nothing to change

		----------------------------------------
	        -- Handling of XactErr bit
		----------------------------------------
		-- If MDATA received on last CS indicate XactErr
		if ptd_last_cs = '1' then
		  var_data(60) := '1';                    --Xact bit is set
		end if;  

		----------------------------------------
	        -- Handling of SC bit
		----------------------------------------
		-- nothing to change
		
		----------------------------------------
	        -- Handling of PING bit (and Token field)
		----------------------------------------
		-- nothing to change
		
	        ----------------------------------------
	        -- Handling of Data Toggle bit
		----------------------------------------
		-- nothing to change
		
	        ----------------------------------------
	        -- Handling of Cerr field
		----------------------------------------
		-- nothing to change
		
		----------------------------------------
	        -- Handling of NakCnt field
		----------------------------------------
		-- nothing to change
		
	        ----------------------------------------
	        -- Handling of NrBytesTransferred field
		----------------------------------------
		-- Update this only when it is an CSPLIT ISO IN
		if (schedule_active = ISOCHRONOUS) and
		   (ptd_token       = "01")        then
                  var_data(46 downto 32) := std_logic_vector(to_unsigned(
		                              to_integer(unsigned(dma_rdata(46 downto 32))) + 
			                      to_integer(unsigned(pie_rx_nbytes_sync)),15));
		end if;
		
	      when BABBLE_ERROR    =>
	        ----------------------------------------
	        -- Handling of Active and Halted bit
		----------------------------------------
	        var_data(63) := '0'; --Active bit is cleared
	        var_data(62) := '1'; --Halted bit is set
	        dma_host_state <= CALC_STATUS_WRITE_DW1;

		----------------------------------------
	        -- Handling of Babble bit
		----------------------------------------
	        var_data(61) := '1'; --Babble bit is set

		----------------------------------------
	        -- Handling of XactErr bit
		----------------------------------------
		-- nothing to change

		----------------------------------------
	        -- Handling of SC bit
		----------------------------------------
		-- nothing to change
		
		----------------------------------------
	        -- Handling of PING bit (and Token field)
		----------------------------------------
		-- nothing to change
		
	        ----------------------------------------
	        -- Handling of Data Toggle bit
		----------------------------------------
		-- nothing to change
		
	        ----------------------------------------
	        -- Handling of Cerr field
		----------------------------------------
		-- nothing to change
		
		----------------------------------------
	        -- Handling of NakCnt field
		----------------------------------------
		-- nothing to change
		
	        ----------------------------------------
	        -- Handling of NrBytesTransferred field
		----------------------------------------
		-- nothing to change
		
	      when ERR_HANDSHAKE   =>
		dma_host_state <= CALC_STATUS_WRITE_DW0;
	        ----------------------------------------
	        -- Handling of Active and Halted bit
		----------------------------------------
	        if schedule_active = ISOCHRONOUS or     --ERR handshake received on ISO (could only happen for CSPLIT)
		   dma_rdata(56 downto 55) = "01" then  --Cerr field decrements to zero
		  var_data(63) := '0';                  --Active bit is cleared
		  var_data(62) := '1';                  --Halted bit is set
	          dma_host_state <= CALC_STATUS_WRITE_DW1;
		end if;
		
		----------------------------------------
	        -- Handling of Babble bit
		----------------------------------------
		-- nothing to change

		----------------------------------------
	        -- Handling of XactErr bit
		----------------------------------------
		-- nothing to change

		----------------------------------------
	        -- Handling of SC bit
		----------------------------------------
                -- An ERR handshake puts SC bit back to zero
		var_data(59) := '0';
		
		----------------------------------------
	        -- Handling of PING bit (and Token field)
		----------------------------------------
		if schedule_active = ASYNCHRONOUS and 
		   pie_devicespeed_sync = "10"    and
		   ptd_token = "00"               and 
		   ptd_s = '0'                    then -- HS Bulk or Control OUT token
		  var_data(58)           := '1';
                end if;
		
	        ----------------------------------------
	        -- Handling of Data Toggle bit
		----------------------------------------
		-- nothing to change
		
	        ----------------------------------------
	        -- Handling of Cerr field
		----------------------------------------
	        if dma_rdata(56 downto 55) /= "00" then
		  var_data(56 downto 55) := std_logic_vector(unsigned(dma_rdata(56 downto 55))
		                            - to_unsigned(1,2)); -- decrement Cerr field
		end if;
		
		----------------------------------------
	        -- Handling of NakCnt field
		----------------------------------------
		-- nothing to change
		
	        ----------------------------------------
	        -- Handling of NrBytesTransferred field
		----------------------------------------
		-- nothing to change
		
	      when ACK_HANDSHAKE   =>
	        dma_host_state <= CALC_STATUS_WRITE_DW0;
	        ----------------------------------------
	        -- Handling of NrBytesTransferred field
		----------------------------------------
		if (ptd_s = '0') then   -- Normal transaction 
		  if ptd_token = "01" then -- IN TOKEN
                    var_data(46 downto 32) := std_logic_vector(to_unsigned(
		                                to_integer(unsigned(dma_rdata(46 downto 32))) + 
			                        to_integer(unsigned(pie_rx_nbytes_sync)),15));
	          end if;
		  if ptd_token = "00" or ptd_token = "10" then -- OUT
		    var_data(46 downto 32) := std_logic_vector(to_unsigned(
		                                to_integer(unsigned(dma_rdata(46 downto 32))) + 
			                        to_integer(unsigned(epinfo_nbytes_int)),15));
	          end if;
		elsif ptd_sc = '0' then -- Start split transaction
		  if ptd_token = "00" and schedule_active = ISOCHRONOUS then -- OUT token
		    var_data(46 downto 32) := std_logic_vector(to_unsigned(
		                                to_integer(unsigned(dma_rdata(46 downto 32))) + 
			                        to_integer(unsigned(epinfo_nbytes_int)),15));
	          end if;
		else                    -- Complete split transaction
		  if ptd_token = "01" then -- IN TOKEN
                    var_data(46 downto 32) := std_logic_vector(to_unsigned(
		                                to_integer(unsigned(dma_rdata(46 downto 32))) +
						to_integer(unsigned(ptd_s_bytes))             + 
			                        to_integer(unsigned(pie_rx_nbytes_sync)),15));
	          end if;
		  if ptd_token = "00" or ptd_token = "10" then -- OUT
                    var_data(46 downto 32) := std_logic_vector(to_unsigned(
                                                to_integer(unsigned(dma_rdata(46 downto 32))) + 
		                                to_integer(unsigned(epinfo_nbytes_int)),15));
		  end if;
		end if;

	        ----------------------------------------
	        -- Handling of Active and Halted bit
		----------------------------------------
		if (ptd_s = '0') then   -- HS transaction
		  if ptd_token = "01" and --IN token
		     to_integer(unsigned(pie_rx_nbytes_sync)) < to_integer(unsigned(ptd_mps)) then --Short packet received
	            var_data(63) := '0'; -- Active bit is cleared
	            dma_host_state <= CALC_STATUS_WRITE_DW1;
		  end if;
		  if (ptd_token /= "11")                               and  -- No PING token 
		     (var_data(46 downto 32) = dma_rdata(14 downto 0)) then -- All datatransferred
	            var_data(63) := '0'; -- Active bit is cleared
	            dma_host_state <= CALC_STATUS_WRITE_DW1;
		  end if;
		elsif ptd_sc = '0' then -- Start split transaction
		  if ptd_token = "00" and schedule_active = ISOCHRONOUS then -- OUT token
		    if var_data(46 downto 32) = dma_rdata(14 downto 0) then -- All datatransferred
	              var_data(63) := '0'; -- Active bit is cleared
	              dma_host_state <= CALC_STATUS_WRITE_DW1;
		    end if;
		  end if;
		else                    -- Complete split transaction
		  if (ptd_token = "01") and --IN token
		     (to_integer(unsigned(pie_rx_nbytes_sync)) + to_integer(unsigned(ptd_s_bytes))
		                        < to_integer(unsigned(ptd_mps))) then --Short packet received
	            var_data(63) := '0'; -- Active bit is cleared
	            dma_host_state <= CALC_STATUS_WRITE_DW1;
		  end if;
		  if var_data(46 downto 32) = dma_rdata(14 downto 0) then -- All datatransferred
	            var_data(63) := '0'; -- Active bit is cleared
	            dma_host_state <= CALC_STATUS_WRITE_DW1;
		  end if;
                end if;
			        
		----------------------------------------
	        -- Handling of Babble bit
		----------------------------------------
		-- nothing to change
		
		----------------------------------------
	        -- Handling of XactErr bit
		----------------------------------------
		-- nothing to change
		
		----------------------------------------
	        -- Handling of SC bit
		----------------------------------------
		if ptd_s = '1' then
		  if (ptd_sc = '0'                     ) and 
		     (schedule_active /= ISOCHRONOUS or
		      ptd_token = "01"                 ) then --Start-split
		    var_data(59) := '1';
		  else                 --Complete-split
		    var_data(59) := '0';
		  end if;
		end if;
		----------------------------------------
	        -- Handling of PING bit (and Token field)
		----------------------------------------
		-- switch to OUT when a PING has been ACKed
		if ptd_token = "11" then
		  var_data(58) := '0';
		end if;
		
	        ----------------------------------------
	        -- Handling of Data Toggle bit
		----------------------------------------
		if schedule_active /= ISOCHRONOUS and not(ptd_s = '1' and ptd_sc = '0')
		                                  and ptd_token /= "11" then --no PING token
		  var_data(57) := not(dma_rdata(57));
		end if;
		
	        ----------------------------------------
	        -- Handling of Cerr field
		----------------------------------------
	        if not(ptd_s = '1' and ptd_sc = '0') and --do not clear Cerr on successfull start-split
		   dma_rdata(56 downto 55) /= "00" then
		  var_data(56 downto 55) := "11";
		end if;
		
		----------------------------------------
	        -- Handling of NakCnt field
		----------------------------------------
	        var_data(54 downto 51) := ptd_reload; --Reload NAKCnt when transaction is ACKed
				
	      when STALL_HANDSHAKE =>
	        ----------------------------------------
	        -- Handling of Active and Halted bit
		----------------------------------------
	        var_data(63) := '0'; --Active bit is cleared
	        var_data(62) := '1'; --Halted bit is set
	        dma_host_state <= CALC_STATUS_WRITE_DW1;
		
		----------------------------------------
	        -- Handling of Babble bit
		----------------------------------------
		-- nothing to change

		----------------------------------------
	        -- Handling of XactErr bit
		----------------------------------------
		-- nothing to change

		----------------------------------------
	        -- Handling of SC bit
		----------------------------------------
		-- nothing to change
		
		----------------------------------------
	        -- Handling of PING bit (and Token field)
		----------------------------------------
		-- nothing to change
		
	        ----------------------------------------
	        -- Handling of Data Toggle bit
		----------------------------------------
		-- nothing to change
		
	        ----------------------------------------
	        -- Handling of Cerr field
		----------------------------------------
		-- nothing to change
		
		----------------------------------------
	        -- Handling of NakCnt field
		----------------------------------------
		-- nothing to change
		
	        ----------------------------------------
	        -- Handling of NrBytesTransferred field
		----------------------------------------
		-- nothing to change
		
	      when NAK_HANDSHAKE   =>
	        dma_host_state <= CALC_STATUS_WRITE_DW0;
	        ----------------------------------------
	        -- Handling of Active, Halted and XactErr bit
	        -- Handling of Cerr field
		----------------------------------------
	        if (ptd_s = '0' and ptd_token = "10") or  --NAK handshake on SETUP token.
		   (ptd_s = '1' and ptd_token = "10" and ptd_sc = '1') then --CSplit on SETUP receives a NAK.
		  var_data(60) := '1';                    --Xact bit is set
	          if dma_rdata(56 downto 55) = "01" then  --Cerr field decrements to zero
		    var_data(63) := '0';                  --Active bit is cleared
		    var_data(62) := '1';                  --Halted bit is set
	            dma_host_state <= CALC_STATUS_WRITE_DW1;
		  end if;
                  if dma_rdata(56 downto 55) /= "00" then
		    var_data(56 downto 55) := std_logic_vector(unsigned(dma_rdata(56 downto 55)) - to_unsigned(1,2)); -- decrement Cerr field
		  end if; 
		elsif dma_rdata(56 downto 55) /= "00" then
		  var_data(56 downto 55) := "11";          -- Set Cerr field back to 3
		end if;
		
		----------------------------------------
	        -- Handling of Babble bit
		----------------------------------------
		-- nothing to change

		----------------------------------------
	        -- Handling of SC bit
		----------------------------------------
		if (ptd_s = '1' and ptd_sc = '1') then
		  var_data(59) := '0'; --If NAK on CSplit, go back to SSplit
		end if;
		
		----------------------------------------
	        -- Handling of PING bit (and Token field)
		----------------------------------------
		if schedule_active = ASYNCHRONOUS and 
		   pie_devicespeed_sync = "10"    and
		   ptd_token = "00"               and 
		   ptd_s = '0'                    then -- HS Bulk or Control OUT token
		  var_data(58)           := '1';
                end if;
				
	        ----------------------------------------
	        -- Handling of Data Toggle bit
		----------------------------------------
		-- nothing to change
		
		----------------------------------------
	        -- Handling of NakCnt field
		----------------------------------------
 	        if ptd_reload /= "0000" then -- Reload is not zero
                  var_data(54 downto 51) := std_logic_vector(unsigned(dma_rdata(54 downto 51)) - to_unsigned(1,4));
		  if dma_rdata(54 downto 51) = "0001" then -- NAKCnt will transition to zero
	            dma_host_state <= CALC_STATUS_WRITE_DW1;
                  end if;
		end if;
		
	        ----------------------------------------
	        -- Handling of NrBytesTransferred field
		----------------------------------------
		-- nothing to change
		
	      when others => --NYET_HANDSHAKE  =>
	        dma_host_state <= CALC_STATUS_WRITE_DW0;
	        ----------------------------------------
	        -- Handling of NrBytesTransferred field
		----------------------------------------
		if schedule_active = ASYNCHRONOUS and 
		   ptd_token = "00"               and ptd_s = '0' then -- HS Bulk or Control OUT token
		  var_data(46 downto 32) := std_logic_vector(to_unsigned(
		                              to_integer(unsigned(dma_rdata(46 downto 32))) + 
			                      to_integer(unsigned(epinfo_nbytes_int)),15));
		end if;

	        ----------------------------------------
	        -- Handling of Active and Halted bit
	        -- Handling of Cerr field
		----------------------------------------
	        if ptd_s = '0' and ptd_token = "10" then  --NYET handshake on SETUP token.
		  var_data(60) := '1';                    --Xact bit is set
	          if dma_rdata(56 downto 55) = "01" then  --Cerr field decrements to zero
		    var_data(63) := '0';                  --Active bit is cleared
		    var_data(62) := '1';                  --Halted bit is set
	            dma_host_state <= CALC_STATUS_WRITE_DW1;
		  end if;
                  if dma_rdata(56 downto 55) /= "00" then
		    var_data(56 downto 55) := std_logic_vector(unsigned(dma_rdata(56 downto 55)) - to_unsigned(1,2)); -- decrement Cerr field
		  end if; 
		elsif ptd_last_cs = '1' then --This should only be set for PERIODIC CSPLIT
		  if schedule_active = ISOCHRONOUS then
		    var_data(63) := '0';                  --Active bit is cleared
	            dma_host_state <= CALC_STATUS_WRITE_DW1;
                  elsif schedule_active = INTERRUPT then
		    if dma_rdata(56 downto 55) = "01" then  --Cerr field decrements to zero
		      var_data(63) := '0';                  --Active bit is cleared
		      var_data(62) := '1';                  --Halted bit is set
	              dma_host_state <= CALC_STATUS_WRITE_DW1;
		    end if;
                    if dma_rdata(56 downto 55) /= "00" then
		      var_data(56 downto 55) := std_logic_vector(unsigned(dma_rdata(56 downto 55)) - to_unsigned(1,2)); -- decrement Cerr field
		    end if; 
		  end if;
		elsif dma_rdata(56 downto 55) /= "00" then
		  var_data(56 downto 55) := "11";          -- Set Cerr field back to 3
		end if;
		if schedule_active = ASYNCHRONOUS and 
		   ptd_token = "00"               and 
		   ptd_s = '0'                    and
		   var_data(46 downto 32) = dma_rdata(14 downto 0) then 
		                                              -- All datatransferred for HS Bulk or Control OUT
	          var_data(63) := '0'; -- Active bit is cleared
	          dma_host_state <= CALC_STATUS_WRITE_DW1;
		end if;
		
		----------------------------------------
	        -- Handling of Babble bit
		----------------------------------------
		-- nothing to change

		----------------------------------------
	        -- Handling of XactErr bit
		----------------------------------------
		-- nothing to change

		----------------------------------------
	        -- Handling of SC bit
		----------------------------------------
                if ptd_last_cs = '1' then
		  var_data(59) := '0';
		end if;
		-- For interrupt, put back to SSPLIT when a NYET is received on the last scheduled CSPLIT
		-- Decrement CERR by one in this case.
		-- For iso, clear active when a NYET is received on the last scheduled CSPLIT
		
		----------------------------------------
	        -- Handling of PING bit (and Token field)
		----------------------------------------
		if schedule_active = ASYNCHRONOUS and 
		   ptd_token = "00"               and ptd_s = '0' then -- HS Bulk or Control OUT token
		  var_data(58)           := '1';
		end if;
		
	        ----------------------------------------
	        -- Handling of Data Toggle bit
		----------------------------------------
		if schedule_active = ASYNCHRONOUS and 
		   ptd_token = "00"               and ptd_s = '0' then -- HS Bulk or Control OUT token
		  var_data(57) := not(dma_rdata(57));
		end if;
		
		----------------------------------------
	        -- Handling of NakCnt field
		----------------------------------------
	        if ptd_s = '1' and ptd_sc = '1' then -- Decrement NAKCnt when NYET received for CSplit
 	          if ptd_reload /= "0000" then -- Reload is not zero
                    var_data(54 downto 51) := std_logic_vector(unsigned(dma_rdata(54 downto 51)) - to_unsigned(1,4));
		    if dma_rdata(54 downto 51) = "0001" then -- NAKCnt will transition to zero
                      dma_host_state <= CALC_STATUS_WRITE_DW1;
                    end if;
		  end if;
		end if;
	    end case;
	  end if;			

        when CALC_STATUS_WRITE_DW1 =>
	  if dma_gnt = '1' then
	    dma_host_state <= CALC_STATUS_READ_DW0;
	    dword_offset   <= "00";
	    dma_req        <= '1';
	    dma_write      <= '0';
	  end if;
	  
        when CALC_STATUS_READ_DW0 =>
	  if dma_gnt = '1' then
	    dma_host_state <= CALC_STATUS_WRITE_DW0;
	    dma_req        <= '1';
	    dma_write      <= '1';
	    var_data(0)           := '0'; -- clear V-bit unless the update is due to an update of the token field.
	    var_data(63 downto 1) := dma_rdata(63 downto 1);
	    case schedule_active is 
	      when ISOCHRONOUS =>
	    	dma_iso_setdone <= '1';
	    	if ioc = '1' then --Interrupt on Complete set
	    	  dma_iso_setint <= '1';
	    	end if;
	      when INTERRUPT   =>
	    	dma_int_setdone <= '1';
	    	if ioc = '1' then --Interrupt on Complete set
	    	  dma_int_setint <= '1';
	    	end if;
	      when others      =>
	    	dma_atl_setdone <= '1';
	    	if ioc = '1' then --Interrupt on Complete set
	    	  dma_atl_setint <= '1';
	    	end if;
	    end case;
          end if;
	  		  
        when others => --CALC_STATUS_WRITE_DW0 =>
	  var_pointer      := 0;
	  if dma_gnt = '1' then
	    dma_req        <= '0';
	    dma_write      <= '0';
	    dma_host_state <= CHECK_SKIP;
	    if not(schedule_active = ISOCHRONOUS and ptd_s = '0') and (ptd_mult /= "01") then
	      ptd_mult <= std_logic_vector(unsigned(ptd_mult) - to_unsigned(1,2));
	      high_bandwidth_check <= '1';
	    else
	      high_bandwidth_check <= '0';
	      if ptd_j = '1' then
	        current_ptd <= ptd_nextptd;
	        if schedule_active = ASYNCHRONOUS then
                  dma_atl_setptd  <= '1';
	        end if;
	      elsif current_ptd >= last_ptd then
	        case schedule_active is
	          when INTERRUPT =>
		    if usbreg_iso_enable = '1' then
	              schedule_active <= ISOCHRONOUS;
	              current_ptd     <= to_integer(unsigned(usbreg_iso_first_ptd));
		    elsif usbreg_atl_enable = '1' then
	              schedule_active <= ASYNCHRONOUS;
	              current_ptd     <= to_integer(unsigned(usbreg_atl_cur_ptd));
		    else
	              dma_host_state  <= IDLE;
		    end if;
	          when ISOCHRONOUS =>
                    if usbreg_atl_enable = '1' then
	              schedule_active <= ASYNCHRONOUS;
	              current_ptd     <= to_integer(unsigned(usbreg_atl_cur_ptd));
		    else
	              dma_host_state  <= IDLE;
		    end if;
		  when others => --ASYNCHRONOUS
            	    if usbreg_atl_enable = '1' then
	              current_ptd     <= first_ptd;
	              dma_atl_setptd  <= '1';
		    else
		      dma_host_state  <= IDLE;
		    end if;
	        end case;
              else
	        current_ptd <= current_ptd +1 ;
	        if schedule_active = ASYNCHRONOUS then
                  dma_atl_setptd  <= '1';
	        end if;
	      end if;
	    end if;
	  end if;

      end case;
      
      data    <= var_data;
      pointer <= var_pointer;
      
      if usbreg_reset = '1' or usbreg_light_reset = '1' then
        dma_host_state        <= IDLE;
     	schedule_active       <= NONE;
     	current_ptd	      <= 0;
     	endtransfer	      <= '0';
     	epinfo_starttransfer  <= '0';
     	data		      <= (others => '0');
     	pointer 	      <= 0;
     	
     	dma_req 	      <= '0';
     	dma_write	      <= '0';
     	    
     	ptd_nextptd	      <= 0;
     	ptd_j		      <= '0';
     	ptd_mps 	      <= (others => '0');
     	ptd_mult	      <= (others => '0');
     	ptd_ep_nb	      <= (others => '0');
     	ptd_dev_addr	      <= (others => '0');
     	ptd_s		      <= '0';
     	ptd_reload	      <= (others => '0');
     	ptd_token	      <= (others => '0');
     	ptd_eptype	      <= (others => '0');
     	ptd_se  	      <= (others => '0');
     	ptd_port_nb	      <= (others => '0');
     	ptd_hub_addr	      <= (others => '0');
     	ptd_dt  	      <= '0';
     	ptd_sc  	      <= '0';
     	ptd_last_cs	      <= '0';
     	ptd_s_bytes	      <= (others => '0');
     	
     	nbytes  	      <= 0;
     	epinfo_nbytes_int     <= (others => '0');
     	data_address_offset   <= (others => '0');
     	
     	if RAM_ADDR_BYTE_WIDTH < 16 then
     	  data_address_base_tmp(15 - RAM_ADDR_BYTE_WIDTH downto 0) <= (others => '0');
     	end if;
     	
     	--------------------------------------------
     	-- TODO combine the 6 FF below into max 2 FF
     	dma_iso_setint  <= '0';
     	dma_int_setint  <= '0';
     	dma_atl_setint  <= '0';
     	dma_iso_setdone <= '0';
     	dma_int_setdone <= '0';
     	dma_atl_setdone <= '0';
     	--------------------------------------------
     	dma_atl_setptd  <= '0';
     	
     	end_of_frame	<= '0';
     	dword_offset	<= "00";
     	
     	ioc		<= '0';
     	hc_bytesleftinframe  <= 0;
     	
     	high_bandwidth_check <= '0';
     	decrement_bytes <= 0;
     	
     	send_lpm     <= '0';
     	dma_lpm_stat <= (others => '0');
      end if;

    end if;
    
  end process MAIN;

  -----------------------------------------------
  -- Interface towards synchronizer
  -----------------------------------------------
  
  proc_epinfo_token : process(ptd_s, ptd_sc, ptd_token, dma_host_state)
  begin
    if dma_host_state = TX_LPM then
      epinfo_token <= TOKEN_EXT;
    elsif ptd_s = '1' then -- split token
      if ptd_sc = '0' then -- start-split token
        epinfo_token <= TOKEN_SSPLIT;
      else                 -- complete-split token
        epinfo_token <= TOKEN_CSPLIT;
      end if;
    else
      case ptd_token is
        when "00" => -- OUT
	  epinfo_token <= TOKEN_OUT;
	when "01" => -- IN
	  epinfo_token <= TOKEN_IN;
	when "10" => -- SETUP
	  epinfo_token <= TOKEN_SETUP;
	when others => -- PING
	  epinfo_token <= TOKEN_PING;
      end case;
    end if;
  end process proc_epinfo_token;
  
  epinfo_devaddr	   <= usbreg_lpm_addr when dma_host_state = TX_LPM else ptd_dev_addr;
  epinfo_epnr		   <= ptd_ep_nb;
  epinfo_toggle 	   <= ptd_dt;
  epinfo_eptype 	   <= ptd_eptype;
  epinfo_mult              <= ptd_mult when schedule_active = ISOCHRONOUS
                                       else "01";
  epinfo_maxpacket         <= ptd_mps;
  epinfo_lowspeed_int	   <= '0' when schedule_active = ISOCHRONOUS else 
                              ptd_se(1);
  epinfo_lowspeed          <= epinfo_lowspeed_int;
  epinfo_sofnr  	   <= usbreg_frindex(13 downto 3);
  epinfo_nbytes            <= epinfo_nbytes_int;

  proc_epinfo_subpid : process(ptd_token, dma_host_state)
  begin
    if dma_host_state = TX_LPM then
      epinfo_subpid <= "11";
    else
      case ptd_token is
	when "01" => -- IN
	  epinfo_subpid <= "10";
	when "10" => -- SETUP
	  epinfo_subpid <= "00";
        when others => -- OUT
	  epinfo_subpid <= "01";
      end case;
    end if;
  end process proc_epinfo_subpid;
      
  epinfo_split_hubaddr     <= ptd_hub_addr;
  epinfo_split_port	   <= ptd_port_nb;
  epinfo_split_se	   <= ptd_se;
  epinfo_txdata 	   <= data(USB_DATAWIDTH-1 downto 0);
  epinfo_txdata_valid	   <= '1' when pointer /= 0 else '0';

  proc_ptd_addr : process(schedule_active,dword_offset,current_ptd,
                          usbreg_iso_base,usbreg_int_base,usbreg_atl_base)
  begin
    ptd_addr(2 downto 0) <= (others => '0');
    case schedule_active is
    when ISOCHRONOUS =>
      ptd_addr( 4 downto  3) <= dword_offset(1 downto 0);
      ptd_addr( 9 downto  5) <= std_logic_vector(to_unsigned(current_ptd,5));
      ptd_addr(31 downto 10) <= usbreg_iso_base;
    when INTERRUPT   =>
      ptd_addr( 4 downto  3) <= dword_offset(1 downto 0);
      ptd_addr( 9 downto  5) <= std_logic_vector(to_unsigned(current_ptd,5));
      ptd_addr(31 downto 10) <= usbreg_int_base;
    when others      =>
      ptd_addr( 3)           <= dword_offset(0);
      ptd_addr( 8 downto  4) <= std_logic_vector(to_unsigned(current_ptd,5));
      ptd_addr(31 downto  9) <= usbreg_atl_base;
    end case;
  end process proc_ptd_addr;
  
  proc_data_addr_base : process(usbreg_payload_base, data_address_base_tmp)
  variable var_data_address_base : std_logic_vector(31 downto 0);
  begin
    var_data_address_base(31 downto 16) := usbreg_payload_base;
    if RAM_ADDR_BYTE_WIDTH > 15 then
      var_data_address_base(15 downto 0) := (others => '0');
    else
      var_data_address_base(15 downto RAM_ADDR_BYTE_WIDTH)    := data_address_base_tmp(15 - RAM_ADDR_BYTE_WIDTH downto 0);
      var_data_address_base(RAM_ADDR_BYTE_WIDTH - 1 downto 0) := (others => '0');
    end if;
    data_address_base <= var_data_address_base(31 downto RAM_ADDR_BYTE_WIDTH);
  end process proc_data_addr_base;
  databuffer_addr(31 downto  RAM_ADDR_BYTE_WIDTH) <= data_address_base(31 downto RAM_ADDR_BYTE_WIDTH);
  databuffer_addr(RAM_ADDR_BYTE_WIDTH-1 downto log2(RAM_DATAWIDTH/8)) 
     <= std_logic_vector(data_address_offset(RAM_ADDR_BYTE_WIDTH-1 downto log2(RAM_DATAWIDTH/8)));
  databuffer_addr(log2(RAM_DATAWIDTH/8)-1 downto 0) <= (others => '0');
  
  dma_addr <= databuffer_addr  when dma_host_state = FETCH_FIRST_OUT_DATA  or
                                    dma_host_state = FETCH_OUT_DATA        or
                                    dma_host_state = WAIT_ON_FIRST_IN_DATA or
                                    dma_host_state = WAIT_ON_IN_DATA       or
				    dma_host_state = READ_DATA
                               else ptd_addr;
  dma_wdata <= data(RAM_DATAWIDTH-1 downto 0);
  
  -----------------------------------------------
  -- Interface towards REG_IF module master
  -----------------------------------------------
  dma_current_ptd <= std_logic_vector(to_unsigned(current_ptd,5));
  dma_lpm_success <= '1' when endtransfer       = '1'           and
                              send_lpm          = '1'           and
                              pie_response_sync = ACK_HANDSHAKE 
--BVE : fix for Aruba. Add check on the state because otherwise it is possible that LPM success is set without sending LPM token
                          and dma_host_state    = TX_LPM     
			 else '0';
  dma_lpm_done    <= '1' when endtransfer       = '1'           and
                              send_lpm          = '1'
--BVE : fix for Aruba. Add check on the state because otherwise it is possible that LPM success is set without sending LPM token
                          and dma_host_state    = TX_LPM     
			 else '0';
  
  usb_dma_fpga(63 downto 5) <= (others => '0');

  usb_dma_fpga(4 downto 0) <= "00000" when dma_host_state = IDLE else
                                                      "00001" when dma_host_state = CHECK_SKIP else
                                                      "00010" when dma_host_state = TX_LPM else
                                                      "00011" when dma_host_state = READ_PTD_DW0 else
                                                      "00100" when dma_host_state = READ_PTD_DW1 else
                                                      "00101" when dma_host_state = READ_PTD_DW2 else
                                                      "00110" when dma_host_state = FETCH_FIRST_OUT_DATA else
                                                      "00111" when dma_host_state = WAIT_ON_FIRST_IN_DATA else                            
                                                      "01000" when dma_host_state = FETCH_OUT_DATA else
                                                      "01001" when dma_host_state = WAIT_ON_IN_DATA else
                                                      "01010" when dma_host_state = CALC_STATUS_READ_DW3 else
                                                      "01011" when dma_host_state = CALC_STATUS_WRITE_DW3 else
                                                      "01100" when dma_host_state = CALC_STATUS_READ_DW2 else
                                                      "01101" when dma_host_state = CALC_STATUS_WRITE_DW2 else
                                                      "01110" when dma_host_state = CALC_STATUS_READ_DW1 else
                                                      "01111" when dma_host_state = CALC_STATUS_WRITE_DW1 else                          
                                                      "10000" when dma_host_state = CALC_STATUS_READ_DW0 else
                                                      "10001" when dma_host_state = CALC_STATUS_WRITE_DW0 else
						      "10010" when dma_host_state = READ_DATA else
                                                      "11111";               

end RTL; --usb_host_dma
-- TODO :

-- Check that active bit is cleared if HS ISO has transmitted last packet in uFrame and one of the packets had an error
-- or there was less bytes to transfer.

-- NakCnt reload and reclamation list for Control/Bulk

-- Gate count reduction
