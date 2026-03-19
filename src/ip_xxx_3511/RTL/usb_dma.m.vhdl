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
--               File: usb_dma.m.vhdl
--
--             Author: Bart Vertenten
--
--       Organisation: Corporate I&T / IP & Architecture
--
--              $Date: Mon Nov  6 19:32:25 2017 $
--
--            Project: IP_3511_HS - Low gate count USB peripheral IP 
--
--        Description: 
--
--          $Revision: 1.6 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_dma.m.vhdl.rca $
--   
--    Revision: 1.6 Mon Nov  6 19:32:25 2017 usb06610
--    buf fix for artf263291 : USB HS: Resetting interrupt endpoint resets DATAx sequence to DATA1
--    
--   
--    Revision: 1.21 Thu Jan 19 11:08:24 2012 beq03099
--    changed behaviour of epinfo_addr_offset
--   
--    Revision: 1.20 Thu Oct 20 10:56:01 2011 beq03099
--    fixed problem where epconfig list was not updated correctly
--    this happens if endtransfer goes to one while still writing data to the RAM
--   
--    Revision: 1.19 Tue Jul 12 09:22:41 2011 beq03099
--    fixed range constraint violation when endpoint number was 
--    bigger than constant
--   
--    Revision: 1.18 Tue Jul  5 10:41:16 2011 beq03067
--    Added fpga debug
--   
--    Revision: 1.17 Fri Jul  1 14:12:53 2011 beq03099
--    fixed problem with clearing active bit for HBW interrupt
--   
--    Revision: 1.16 Tue Jun 21 09:47:59 2011 beq03099
--    added extra signal epinfo_maxpacket
--   
--    Revision: 1.15 Thu Jun 16 20:15:26 2011 beq03099
--    fixed problem with IN token data buffer
--   
--    Revision: 1.14 Thu Jun 16 18:56:36 2011 beq03099
--    fixed problem with decrementing nbytes when sending data on IN token
--   
--    Revision: 1.13 Wed Jun  1 16:27:57 2011 beq03099
--    fixed problem with databuffer address when used in 64 bit mode
--   
--    Revision: 1.12 Tue May 31 11:59:21 2011 beq03196
--    dma handler issue with RAM width of 64 bits for Endpoint 0 SETUP
--   
--    Revision: 1.11 Wed May 25 11:03:45 2011 beq03196
--    var_pointer calculation issue.USB_DATAWIDTH must be devided by 8.
--   
--    Revision: 1.10 Mon May 16 16:39:23 2011 beq03099
--    added word_enable signal
--   
--    Revision: 1.9 Mon May 16 07:40:22 2011 beq03099
--    fixed array shape mismatch
--   
--    Revision: 1.8 Tue May 10 15:25:32 2011 beq03099
--    replace constant by generic for USB_RAMWIDTH
--   
--    Revision: 1.7 Wed Mar 16 15:23:55 2011 beq03099
--    implemented fixes for embedded device
--   
--    Revision: 1.6 Tue Mar  1 10:53:03 2011 beq03099
--    fixed issue with embdev_toggle
--   
--    Revision: 1.5 Thu Feb 24 10:04:21 2011 beq03099
--    removed usb_cfg package
--   
--    Revision: 1.4 Wed Feb 23 13:10:56 2011 beq03099
--    Modified NBytes and addr offset fields according to spec v2.2
--   
--    Revision: 1.3 Thu Feb 10 12:24:06 2011 beq03099
--    modified usbreg_speed into pie_speed
--   
--    Revision: 1.2 Wed Feb  9 13:47:46 2011 beq03099
--    made size of rxnbytes and txnbytes configurable to support hs device
--   
--    Revision: 1.1 Wed Feb  9 11:29:12 2011 beq03099
--    Initial version started from usb_fs_dma.m.vhdl v1.3
--    Modified according to architecture doc v2.1
--   
--   
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

library usb_lib;
use usb_lib.usb_subcmp_pkg.all;
use usb_lib.usb_fs_emb_dev_cfg_pkg.all;

entity usb_dma is
generic(USB_DATAWIDTH      : integer := 8;
        RAM_DATAWIDTH      : integer := 32;
        C_NBPHYSEP         : integer := 14;
        C_DALB             : integer := 22);
port (
      hclk              : in    std_logic; 
      hresetn           : in    std_logic; 
            
      dma_addr          : out   std_logic_vector(31 downto 0); 
      dma_req           : out   std_logic;                     
      dma_gnt           : in    std_logic;                     
      dma_write         : out   std_logic;                     
      dma_wdata         : out   std_logic_vector(RAM_DATAWIDTH-1 downto 0); 
      dma_rdata         : in    std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      dma_word_enable   : out   std_logic_vector(RAM_DATAWIDTH/32 - 1 downto 0); 

      -- from usb_synchronizer module --
      sync_sieint_epinfo_req:     in  std_logic;                   
      sync_sieint_epinfo_epnr:    in  std_logic_vector(3 downto 0);
      sync_sieint_epinfo_epdir:   in  std_logic;
      sync_sieint_epinfo_setup:   in  std_logic;
      epinfo_sync_valid:          out std_logic;                   
 
      epinfo_sync_active:         out std_logic;
      epinfo_sync_disabled:       out std_logic;
      epinfo_sync_toggle:         out std_logic;
      epinfo_sync_stall:          out std_logic;
      epinfo_sync_iso:            out std_logic;
      epinfo_sync_ratefeedbackmode:out std_logic;
      epinfo_sync_nbytes:         out std_logic_vector(14 downto 0);
      epinfo_sync_maxpacket:      out std_logic_vector(1 downto 0);
         
      sync_sieint_txdatafetched:  in  std_logic;                   
      epinfo_sync_txdata:         out std_logic_vector(USB_DATAWIDTH-1 downto 0);
      epinfo_sync_txdata_valid:   out std_logic;                   
         
      sync_sieint_rx_nbytes:      in  std_logic_vector(11 downto 0);
      sync_sieint_rxdata:         in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
      sync_sieint_rxdatavalid:    in  std_logic;                   
        
      sync_sieint_endtransfer:    in  std_logic;                   
      sync_sieint_success:        in  std_logic; 
      sync_sieint_sentNAK:        in  std_logic;

      sync_busreset:              in  std_logic;
      
      dma_ahb_selected:           out std_logic;

      -- from fs_reg module
      usbreg_setup:               in  std_logic;
      pie_speed:                  in  std_logic_vector( 1 downto 0);
      usbreg_ep_list_start:       in  std_logic_vector(31 downto 8);
      usbreg_ep_skip_list_start:  in  std_logic_vector(31 downto 8);
      usbreg_data_buffer_start:   in  std_logic_vector(31 downto C_DALB);
      usbreg_ep_bufinuse:         in  std_logic_vector(C_NBPHYSEP+1 downto 0);
      usbreg_ep_skip:             in  std_logic_vector(C_NBPHYSEP+1 downto 0);
      usbreg_epinfo_toggle:       in  std_logic_vector(C_NBPHYSEP+1 downto 0);
      dma_clear_toggle:           out std_logic;
      dma_set_toggle:             out std_logic;
      dma_sent_NAK:               out std_logic;
      dma_set_int:                out std_logic;
      dma_physepnr:               out integer range 0 to C_NBPHYSEP+1;
      dma_clear_skip:             out std_logic;
      dma_skip_ep:                out integer range 0 to C_NBPHYSEP+1;
      usb_dma_fpga:               out std_logic_vector(63 downto 0)

     );
end usb_dma; 
      
architecture RTL of usb_dma is

constant FIFO_NBYTES : integer := (USB_DATAWIDTH + RAM_DATAWIDTH) / 8;
type t_dma_state_enum is (IDLE,
                          READ_EPINFO_SKIP,
                          READ_EPINFO,
                          CHECK_EPINFO,
                          FETCH_INEP_DATA,
                          WAIT_ON_OUTEP_DATA,
                          WAIT_ON_GNT_FOR_SKIP_UPDATE,
                          WAIT_ON_GNT_FOR_UPDATE,
                          WAIT_ON_ENDTRANSFER_NO_UPDATE
                         );
signal dma_state : t_dma_state_enum;
signal epinfo_req               : std_logic;
signal epinfo_valid             : std_logic;
signal epinfo_active            : std_logic;
signal epinfo_disabled          : std_logic;
signal epinfo_txdata_valid      : std_logic;
--signal epinfo_toggle            : std_logic_vector(C_NBPHYSEP+1 downto 0);
signal epinfo_stall             : std_logic;
signal epinfo_iso               : std_logic;
signal epinfo_periodic          : std_logic;
signal epinfo_rf_tv             : std_logic;
signal epinfo_ratefeedbackmode  : std_logic;
signal epinfo_nbytes            : std_logic_vector(14 downto 0);
signal epinfo_addr_offset       : std_logic_vector(C_DALB-7 downto 0);
signal epinfo_addr              : std_logic_vector(31 downto 0);
signal epinfo_skip_addr         : std_logic_vector(31 downto 0);
signal databuffer_addr          : std_logic_vector(31 downto 0);
signal setup_not_cleared        : std_logic;
signal endpoint_nr_dir          : integer range 0 to C_NBPHYSEP+1; 
-- no range constraint violation possible because there is a check in sieint

signal word_number              : integer range 0 to 15;
signal pointer                  : integer range 0 to FIFO_NBYTES;
signal data                     : std_logic_vector(FIFO_NBYTES*8-1 downto 0);
signal nbytes                   : integer range 0 to 3072;
signal endtransfer              : std_logic;
signal epinfo_req_delayed       : std_logic;
signal skip_ep                  : integer range 0 to C_NBPHYSEP+1;
signal usbreg_setup_int         : std_logic;
signal ahb_selected             : std_logic;

begin

  epinfo_req <= sync_sieint_epinfo_req;
  
  usbreg_setup_int <= usbreg_setup;

  -----------------------------------------------
  -- MAIN state machine
  -----------------------------------------------
  MAIN : process (hclk,hresetn)
  variable var_pointer : integer range 0 to FIFO_NBYTES;
  variable var_data    : std_logic_vector(FIFO_NBYTES*8-1 downto 0);
  variable var_maxpacket : integer range 0 to 3072;
  variable clear_active: boolean;
  begin
    if hresetn = '0' then
      dma_state               <= IDLE;
      epinfo_valid            <= '0';
      epinfo_active           <= '0';
      epinfo_disabled         <= '0';
--      epinfo_toggle           <= (others => '0');
      epinfo_stall            <= '0';
      epinfo_periodic         <= '0';
      epinfo_ratefeedbackmode <= '0';
      epinfo_rf_tv            <= '0';
      epinfo_nbytes           <= (others => '0');
      epinfo_addr_offset      <= (others => '0');
      dma_req                 <= '0';
      dma_write               <= '0';
      word_number             <= 0;
      data                    <= (others => '0');
      pointer                 <= 0;
      nbytes                  <= 0;
      dma_set_int             <= '0';
      endtransfer             <= '0';
      dma_clear_skip          <= '0';
      skip_ep                 <= 0;
      epinfo_req_delayed      <= '0';
      setup_not_cleared       <= '0';
      dma_set_toggle          <= '0';
      dma_clear_toggle        <= '0';
      epinfo_txdata_valid     <= '0'; 

      
    elsif hclk'event and hclk = '1' then
      var_data    := data;
      var_pointer := pointer;
      
      dma_set_int             <= '0';
      dma_clear_skip          <= '0';
      dma_set_toggle          <= '0';
      dma_clear_toggle        <= '0';

      if sync_sieint_endtransfer = '1' then
        endtransfer <= '1';
      end if;

      case dma_state is 
        when IDLE =>
          endtransfer       <= '0';
          epinfo_valid      <= '0';
          dma_write         <= '0';
          word_number       <= 0;
          var_pointer       := 0;
          clear_active      := FALSE;
          setup_not_cleared <= usbreg_setup_int;
          if usbreg_ep_skip(skip_ep) = '1' then
            clear_active := TRUE;
          else
            if skip_ep = C_NBPHYSEP+1 then
              skip_ep <= 0;
            else
              skip_ep <= skip_ep + 1;
            end if;
          end if; 
          if epinfo_req = '1' or epinfo_req_delayed = '1' then
            epinfo_req_delayed <= '0';
            dma_req            <= '1';
            dma_write          <= '0';
            dma_state          <= READ_EPINFO;
          elsif clear_active then
            dma_req   <= '1';
            dma_write <= '0';
            dma_state <= READ_EPINFO_SKIP;
          end if;

        when READ_EPINFO_SKIP =>
          setup_not_cleared <= usbreg_setup_int;
          if epinfo_req = '1' then
            epinfo_req_delayed <= '1';
          end if;
          if dma_gnt = '1' then
            if epinfo_req = '1' or epinfo_req_delayed = '1' then
              epinfo_req_delayed    <= '0';
              dma_req               <= '1';
              dma_write             <= '0';
              dma_state             <= READ_EPINFO;
            else
              dma_req               <= '1';
              dma_write             <= '1';
              dma_state             <= WAIT_ON_GNT_FOR_SKIP_UPDATE;
              -- generate interrupt when active bit is cleared
              if RAM_DATAWIDTH = 32 then
                dma_set_int           <= dma_rdata(31); 
                var_data(31)          := '0';
                var_data(30 downto 0) := dma_rdata(30 downto 0);
                dma_clear_skip        <= '1';
              elsif RAM_DATAWIDTH = 64 then
                if epinfo_skip_addr(2) = '1' then
                  dma_set_int           <= dma_rdata(63); 
                  var_data(63)          := '0';
                  var_data(62 downto 0) := dma_rdata(62 downto 0);
                  dma_clear_skip        <= '1';                
                else
                  dma_set_int           <= dma_rdata(31); 
                  var_data(63 downto 32):= dma_rdata(63 downto 32);
                  var_data(31)          := '0';
                  var_data(30 downto 0) := dma_rdata(30 downto 0);
                  dma_clear_skip        <= '1';                
                end if;
              else
                assert false
                  report "Error : RAM_DATAWIDTH value not supported.";
              end if;
            end if;
          end if;
          
        when READ_EPINFO =>
          if dma_gnt = '1' then
            dma_req                 <= '0';
            dma_write               <= '0';
            epinfo_valid            <= '1';
            if sync_sieint_epinfo_setup = '1' then
              epinfo_active           <= '1';
              epinfo_disabled         <= '0';
              --epinfo_toggle(0)        <= '0';
              epinfo_stall            <= '0';
              epinfo_periodic         <= '0';
              epinfo_rf_tv            <= '0';
              epinfo_ratefeedbackmode <= '0';
              epinfo_nbytes           <= std_logic_vector(to_unsigned(8,15));
              if RAM_DATAWIDTH = 32 then
                epinfo_addr_offset      <= dma_rdata(C_DALB-7 downto 0);
              elsif RAM_DATAWIDTH = 64 then
                epinfo_addr_offset      <= dma_rdata(C_DALB-7+32 downto 32);
              else
                assert false
                report "Error : RAM_DATAWIDTH value not supported.";
              end if;
            else
              if RAM_DATAWIDTH = 32 then
                epinfo_active         <= dma_rdata(31);
                if sync_sieint_epinfo_epnr = "0000" then
                  epinfo_disabled       <= '0';
                else
                  epinfo_disabled       <= dma_rdata(30);
                end if;
                epinfo_stall            <= dma_rdata(29);
                if dma_rdata(28) = '1' then
                  -- toggle reset
                  ----------------------------------------
                  -- BVE : fix for artf263291
                  --      do not look at the RF/TV bit when TR bit is set. 
                  --      TR bit must reset the toggle to zero always
                  --      because for an interrupt endpoint RF/TV is set to '1'.
                  --if dma_rdata(27) = '1' then
                  --  dma_set_toggle   <= '1';
                  --else
                  --  dma_clear_toggle <= '1';
                  --end if;
                  dma_clear_toggle <= '1';
                  ----------------------------------------
                  epinfo_ratefeedbackmode <= '0';
                elsif (not (dma_rdata(26) = '0' and dma_rdata(27) = '1') ) or sync_sieint_epinfo_epnr = "0000" then  
                  -- no toggle reset and (ratefeedbackmode not set or ignored).
                  epinfo_ratefeedbackmode <= '0';
                else                                                                
                  -- no toggle reset and ratefeedbackmode set
                  --epinfo_toggle(endpoint_nr_dir)   <= '0';
                  dma_clear_toggle        <= '1';
                  epinfo_ratefeedbackmode <= '1';
                end if;
                if sync_sieint_epinfo_epnr = "0000" then
                  epinfo_periodic       <= '0';
                  epinfo_rf_tv          <= '0';
                else
                  epinfo_periodic       <= dma_rdata(26);
                  epinfo_rf_tv          <= dma_rdata(27);
                end if;
                epinfo_nbytes           <= dma_rdata(25 downto 11);
                epinfo_addr_offset      <= dma_rdata(C_DALB-7 downto 0);
              elsif RAM_DATAWIDTH = 64 then
                if epinfo_addr(2) = '1' then
                  epinfo_active         <= dma_rdata(63);
                  if sync_sieint_epinfo_epnr = "0000" then
                    epinfo_disabled       <= '0';
                  else
                    epinfo_disabled       <= dma_rdata(62);
                  end if;
                  epinfo_stall            <= dma_rdata(61);
                  if dma_rdata(60) = '1' then --toggle reset
                    --epinfo_toggle(endpoint_nr_dir)   <= dma_rdata(59);
                    if dma_rdata(59) = '1' then
                      dma_set_toggle   <= '1';
                    else
                      dma_clear_toggle <= '1';
                    end if;
                    epinfo_ratefeedbackmode <= '0';
                  elsif (not (dma_rdata(58) = '0' and dma_rdata(59) = '1') ) or sync_sieint_epinfo_epnr = "0000" then  
                    -- no toggle reset and (ratefeedbackmode not set or ignored).
                    epinfo_ratefeedbackmode <= '0';
                  else                                                                
                    -- no toggle reset and ratefeedbackmode set
                    dma_clear_toggle        <= '1';
                    epinfo_ratefeedbackmode <= '1';
                  end if;
                  if sync_sieint_epinfo_epnr = "0000" then
                    epinfo_periodic         <= '0';
                    epinfo_rf_tv            <= '0';
                  else
                    epinfo_periodic         <= dma_rdata(58);
                    epinfo_rf_tv            <= dma_rdata(59);
                  end if;
                  epinfo_nbytes           <= dma_rdata(57 downto 43);
                  epinfo_addr_offset      <= dma_rdata(C_DALB-7+32 downto 32);
                  
                else
                  epinfo_active         <= dma_rdata(31);
                  if sync_sieint_epinfo_epnr = "0000" then
                    epinfo_disabled       <= '0';
                  else
                    epinfo_disabled       <= dma_rdata(30);
                  end if;
                  epinfo_stall            <= dma_rdata(29);
                  if dma_rdata(28) = '1' then --toggle Reset
                  ----------------------------------------
                  -- BVE : fix for artf263291
                  --      do not look at the RF/TV bit when TR bit is set. 
                  --      TR bit must reset the toggle to zero always
                  --      because for an interrupt endpoint RF/TV is set to '1'.
                  --if dma_rdata(27) = '1' then
                  --  dma_set_toggle   <= '1';
                  --else
                  --  dma_clear_toggle <= '1';
                  --end if;
                  dma_clear_toggle <= '1';
                  ----------------------------------------
                  elsif (not (dma_rdata(26) = '0' and dma_rdata(27) = '1') ) or sync_sieint_epinfo_epnr = "0000" then  
                    -- no toggle reset and (ratefeedbackmode not set or ignored).
                    epinfo_ratefeedbackmode        <= '0';
                  else                                                                
                    -- no toggle reset and ratefeedbackmode set
                    dma_clear_toggle               <= '1';
                    epinfo_ratefeedbackmode        <= '1';
                  end if;
                  if sync_sieint_epinfo_epnr = "0000" then
                    epinfo_periodic         <= '0';
                    epinfo_rf_tv            <= '0';
                  else
                    epinfo_periodic         <= dma_rdata(26);
                    epinfo_rf_tv            <= dma_rdata(27);
                  end if;
                  epinfo_nbytes           <= dma_rdata(25 downto 11);
                  epinfo_addr_offset      <= dma_rdata(C_DALB-7 downto 0);
                end if;
              else
                assert false
                  report "Error : RAM_DATAWIDTH value not supported.";
              end if;
            end if;
            dma_state               <= CHECK_EPINFO;
          end if;
          
        when CHECK_EPINFO =>
          if pie_speed = HIGH_SPEED then
            if sync_sieint_epinfo_epnr = "0000" then
              var_maxpacket := 64;
            elsif epinfo_periodic = '1' then
              if epinfo_rf_tv = '0' then --HBW ISO
                var_maxpacket := 3072;
              else                       --HBW Interrupt (high bandwith are handled at the software layer)
                var_maxpacket := 1024;
              end if;
            else                         --Gen Ep (Bulk Interrupt ratefeedback mode)
              var_maxpacket := 512;
            end if;
          else
            if epinfo_periodic = '1' and epinfo_rf_tv = '0' then --FS ISO
              var_maxpacket := 1023;
            else
              var_maxpacket := 64;
            end if;
          end if;
          if to_integer(unsigned(epinfo_nbytes)) < var_maxpacket then
            nbytes <= to_integer(unsigned(epinfo_nbytes));
          else
            nbytes <= var_maxpacket;
          end if;
          if epinfo_disabled = '1' or epinfo_active = '0'
                                   or (setup_not_cleared = '1' and 
                                       sync_sieint_epinfo_epnr = "0000") then
            dma_state <= WAIT_ON_ENDTRANSFER_NO_UPDATE;     
          elsif epinfo_active = '1' then 
            if epinfo_addr(3) = '1' then -- IN endpoint
              if to_integer(unsigned(epinfo_nbytes)) /= 0 then
                dma_req   <= '1';
                dma_write <= '0';
              end if;
              dma_state <= FETCH_INEP_DATA;
            else                         -- OUT endpoint
              dma_state <= WAIT_ON_OUTEP_DATA;
            end if;
          end if;

        when FETCH_INEP_DATA =>
          if sync_sieint_txdatafetched = '1' then
            var_data(FIFO_NBYTES*8-1-USB_DATAWIDTH downto 0) 
                                          := var_data(FIFO_NBYTES*8-1 downto USB_DATAWIDTH);
            var_data(FIFO_NBYTES*8-1 downto FIFO_NBYTES*8-USB_DATAWIDTH) 
                                          := (others => '0');
            var_pointer                   := var_pointer - USB_DATAWIDTH/8;
          end if;
          if dma_gnt = '1' then
            dma_req   <= '0';
            dma_write <= '0';
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
            if RAM_DATAWIDTH = 32 then
              if word_number = 15 then
                word_number        <= 0;
                epinfo_addr_offset 
                      <= std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
              else
                word_number <= word_number + 1;
              end if;
            elsif RAM_DATAWIDTH = 64 then
              if word_number = 7 then
                word_number        <= 0;
                epinfo_addr_offset 
                      <= std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
              else
                word_number <= word_number + 1;
              end if;
            else
              assert false
                report "Error : RAM_DATAWIDTH value not supported.";
            end if;
          end if;
          if var_pointer <= FIFO_NBYTES - (RAM_DATAWIDTH/8) and nbytes /= 0 then 
            dma_req   <= '1';
            dma_write <= '0';
          elsif endtransfer = '1' then 
            if sync_sieint_success = '1' then
              dma_state <= WAIT_ON_GNT_FOR_UPDATE;
              dma_req   <= '1';
              dma_write <= '1';
              if RAM_DATAWIDTH = 32 then
                var_data(31) := epinfo_active;
                if pie_speed = HIGH_SPEED then
                  if sync_sieint_epinfo_epnr = "0000" then
                    var_maxpacket := 64;
                  elsif epinfo_periodic = '1' then
                    --if epinfo_ratefeedbackmode = '0' then --HBW Iso
                    if epinfo_rf_tv = '0' then --HBW Iso
                      var_maxpacket := 3072;
                    else                       --HBW Interrupt  (high bandwith are handled at the software layer)
                      var_maxpacket := 1024;
                    end if;
                  else                         --Gen Ep (Bulk Interrupt ratefeedback mode)
                    var_maxpacket := 512;
                  end if;
                else
                  if epinfo_periodic = '1' and epinfo_rf_tv = '0' then --FS ISO
                    var_maxpacket := 1023;
                  else
                    var_maxpacket := 64;
                  end if;
                end if;
                if (epinfo_periodic = '1' and epinfo_rf_tv = '0')     or 
                   not(var_maxpacket < to_integer(unsigned(epinfo_nbytes))) then
                  var_data(31)    := '0';
                  -- generate interrupt because active is cleared
                  dma_set_int <= '1'; 
                end if;
                var_data(30) := epinfo_disabled;
                var_data(29) := epinfo_stall;
                var_data(28) := '0'; 
                var_data(27) := epinfo_rf_tv;
                var_data(26) := epinfo_periodic;
                if var_maxpacket < to_integer(unsigned(epinfo_nbytes)) then
                  var_data(25 downto 11) := std_logic_vector(to_unsigned
                              (to_integer(unsigned(epinfo_nbytes))
                             - var_maxpacket,15));
                else
                  var_data(25 downto 11) := (others => '0');
                end if;
                ----------------------------------------------------------
                -- BVE : bug fix on Aruba (Aruba has C_DALB defined as 19)
                ----------------------------------------------------------
                --if C_DALB < 17 then
                --  var_data(10 downto C_DALB-6) := (others => '0');
                --end if;
                --if word_number /= 0 then
                --  var_data(C_DALB-7 downto  0)
                --      := std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
                --else
                --  var_data(C_DALB-7 downto  0) := epinfo_addr_offset; 
                --end if;
                if C_DALB < 17 then
                  var_data(10 downto C_DALB-6) := (others => '0');
                  if word_number /= 0 then
                    var_data(C_DALB-7 downto  0)
                      := std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
                  else
                    var_data(C_DALB-7 downto  0) := epinfo_addr_offset(C_DALB-7 downto  0); 
                  end if;
                else
                  if word_number /= 0 then
                    var_data(10 downto  0)
                      := std_logic_vector(unsigned(epinfo_addr_offset(10 downto 0)) + to_unsigned(1,11));
                  else
                    var_data(10 downto  0) := epinfo_addr_offset(10 downto 0); 
                  end if;
                end if;
                ----------------------------------------------------------
                if (epinfo_periodic = '0' and epinfo_rf_tv = '0') or  -- Bulk or Interrupt
                   (epinfo_periodic = '1' and epinfo_rf_tv = '1') then
                  --epinfo_toggle(endpoint_nr_dir) 
                  --                       <= not(epinfo_toggle(endpoint_nr_dir));
                  if usbreg_epinfo_toggle(endpoint_nr_dir) = '1' then
                    dma_clear_toggle <= '1';
                  else
                    dma_set_toggle   <= '1';
                  end if;
                end if;
              elsif RAM_DATAWIDTH = 64 then
                if epinfo_addr(2) = '1' then
                  var_data(63) := epinfo_active;
                  if pie_speed = HIGH_SPEED then
                    if sync_sieint_epinfo_epnr = "0000" then
                      var_maxpacket := 64;
                    elsif epinfo_periodic = '1' then
                      if epinfo_rf_tv = '0' then --HBW ISO 
                        var_maxpacket := 3072;
                      else                       --HBW Interrupt (high bandwith are handled at the software layer) 
                        var_maxpacket := 1024;
                      end if;
                    else                         --Gen Ep (Bulk Interrupt ratefeedback mode) 
                      var_maxpacket := 512;
                    end if;
                  else
                    if epinfo_periodic = '1' and epinfo_rf_tv = '0' then --FS ISO
                      var_maxpacket := 1023;
                    else
                      var_maxpacket := 64;
                    end if;
                  end if;
                  if (epinfo_periodic = '1' and epinfo_rf_tv = '0')     or 
                     not(var_maxpacket < to_integer(unsigned(epinfo_nbytes))) then
                    var_data(63)    := '0';
                    -- generate interrupt because active is cleared
                    dma_set_int <= '1'; 
                  end if;
                  var_data(62) := epinfo_disabled;
                  var_data(61) := epinfo_stall;
                  var_data(60) := '0'; 
                  var_data(59) := epinfo_rf_tv;
                  var_data(58) := epinfo_periodic;
                  if var_maxpacket < to_integer(unsigned(epinfo_nbytes)) then
                    var_data(57 downto 43) := std_logic_vector(to_unsigned
                              (to_integer(unsigned(epinfo_nbytes))
                             - var_maxpacket,15));
                  else
                    var_data(57 downto 43) := (others => '0');
                  end if;
                  ----------------------------------------------------------
                  -- BVE : bug fix on Aruba (Aruba has C_DALB defined as 19)
                  ----------------------------------------------------------
                  --if C_DALB < 17 then
                  --  var_data(42 downto C_DALB-6+32) := (others => '0');
                  --end if;
                  --if word_number /= 0 then
                  --  var_data(C_DALB-7+32 downto  32)
                  --    := std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
                  --else
                  --  var_data(C_DALB-7+32 downto  32) := epinfo_addr_offset; 
                  --end if;
                  if C_DALB < 17 then
                    var_data(42 downto C_DALB-6+32) := (others => '0');
                    if word_number /= 0 then
                      var_data(C_DALB-7+32 downto  32)
                        := std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
                    else
                      var_data(C_DALB-7+32 downto  32) := epinfo_addr_offset(C_DALB-7 downto  0); 
                    end if;
                  else
                    if word_number /= 0 then
                      var_data(42 downto  32)
                        := std_logic_vector(unsigned(epinfo_addr_offset(10 downto 0)) + to_unsigned(1,11));
                    else
                      var_data(42 downto  32) := epinfo_addr_offset(10 downto 0); 
                    end if;
                  end if;
                  ----------------------------------------------------------
                  if (epinfo_periodic = '0' and epinfo_rf_tv = '0') or
                     (epinfo_periodic = '1' and epinfo_rf_tv = '1') then -- bulk or interrupt
                    if usbreg_epinfo_toggle(endpoint_nr_dir) = '1' then
                      dma_clear_toggle <= '1';
                    else
                      dma_set_toggle   <= '1';
                    end if;
                  end if;

                else -- epinfo_addr(2) = '0'
                  var_data(31) := epinfo_active;
                  if pie_speed = HIGH_SPEED then
                    if sync_sieint_epinfo_epnr = "0000" then
                      var_maxpacket := 64;
                    elsif epinfo_periodic = '1' then
                      if epinfo_rf_tv = '0' then  --HBW ISO 
                        var_maxpacket := 3072;
                      else                        --HBW Interrupt (high bandwith are handled at the software layer) 
                        var_maxpacket := 1024;
                      end if;
                    else                         --Gen Ep (Bulk Interrupt ratefeedback mode) 
                      var_maxpacket := 512;
                    end if;
                  else
                    if epinfo_periodic = '1'  and epinfo_rf_tv = '0' then --FS ISO
                      var_maxpacket := 1023;
                    else
                      var_maxpacket := 64;
                    end if;
                  end if;
                  if (epinfo_periodic = '1' and epinfo_rf_tv = '0')     or 
                     not(var_maxpacket < to_integer(unsigned(epinfo_nbytes))) then
                    var_data(31)    := '0';
                    -- generate interrupt because active is cleared
                    dma_set_int <= '1'; 
                  end if;
                  var_data(30) := epinfo_disabled;
                  var_data(29) := epinfo_stall;
                  var_data(28) := '0'; 
                  var_data(27) := epinfo_rf_tv;
                  var_data(26) := epinfo_periodic;
                  if var_maxpacket < to_integer(unsigned(epinfo_nbytes)) then
                    var_data(25 downto 11) := std_logic_vector(to_unsigned
                              (to_integer(unsigned(epinfo_nbytes))
                             - var_maxpacket,15));
                  else
                    var_data(25 downto 11) := (others => '0');
                  end if;
                ----------------------------------------------------------
                -- BVE : bug fix on Aruba (Aruba has C_DALB defined as 19)
                ----------------------------------------------------------
                --if C_DALB < 17 then
                --  var_data(10 downto C_DALB-6) := (others => '0');
                --end if;
                --if word_number /= 0 then
                --  var_data(C_DALB-7 downto  0)
                --      := std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
                --else
                --  var_data(C_DALB-7 downto  0) := epinfo_addr_offset; 
                --end if;
                if C_DALB < 17 then
                  var_data(10 downto C_DALB-6) := (others => '0');
                  if word_number /= 0 then
                    var_data(C_DALB-7 downto  0)
                      := std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
                  else
                    var_data(C_DALB-7 downto  0) := epinfo_addr_offset(C_DALB-7 downto  0); 
                  end if;
                else
                  if word_number /= 0 then
                    var_data(10 downto  0)
                      := std_logic_vector(unsigned(epinfo_addr_offset(10 downto 0)) + to_unsigned(1,11));
                  else
                    var_data(10 downto  0) := epinfo_addr_offset(10 downto 0); 
                  end if;
                end if;
                ----------------------------------------------------------
                  if (epinfo_periodic = '0' and epinfo_rf_tv = '0') or
                     (epinfo_periodic = '1' and epinfo_rf_tv = '1') then -- bulk or interrupt 
                    if usbreg_epinfo_toggle(endpoint_nr_dir) = '1' then
                      dma_clear_toggle <= '1';
                    else
                      dma_set_toggle   <= '1';
                    end if;
                  end if;
                end if;
              else
                assert false
                  report "Error : RAM_DATAWIDTH value not supported.";
              end if;
            else
              dma_state <= IDLE;
            end if;
          end if;

        when WAIT_ON_OUTEP_DATA =>
          if dma_gnt = '1' then
            var_data(FIFO_NBYTES*8-1-RAM_DATAWIDTH downto 0) 
                                         := var_data(FIFO_NBYTES*8-1 downto RAM_DATAWIDTH);
            var_data(FIFO_NBYTES*8-1 downto FIFO_NBYTES*8-RAM_DATAWIDTH) 
                                         := (others => '0');
            dma_req     <= '0';
            dma_write   <= '0';
            if RAM_DATAWIDTH = 32 then
              if word_number = 15 then
                word_number        <= 0;
                epinfo_addr_offset 
                    <= std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
              else
                word_number <= word_number + 1;
              end if;
            elsif RAM_DATAWIDTH = 64 then
              if word_number = 7 then
                word_number        <= 0;
                epinfo_addr_offset 
                    <= std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
              else
                word_number <= word_number + 1;
              end if;
            else
              assert false
                report "Error : RAM_DATAWIDTH value not supported.";
            end if;
            if var_pointer >= RAM_DATAWIDTH/8 then
              var_pointer := var_pointer - RAM_DATAWIDTH/8;
            else
              var_pointer := 0;
            end if;
          end if;
          if sync_sieint_rxdatavalid = '1' then
            for i in 0 to USB_DATAWIDTH-1 loop
              var_data(var_pointer*8+i) := sync_sieint_rxdata(i);
            end loop;
            var_pointer := var_pointer + USB_DATAWIDTH/8;
          end if;       
          if var_pointer >= RAM_DATAWIDTH/8 then
            dma_req   <= '1';
            dma_write <= '1'; 
          elsif endtransfer = '1' then
            if var_pointer /= 0 then
              dma_req   <= '1';
              dma_write <= '1';
            elsif sync_sieint_success = '1' then
              if pointer = 0 then
                if sync_sieint_epinfo_setup = '0' then
                  dma_state <= WAIT_ON_GNT_FOR_UPDATE;
                  dma_req   <= '1';
                  dma_write <= '1';
                  if RAM_DATAWIDTH = 32 then
                    var_data(31) := epinfo_active;
                    if pie_speed = HIGH_SPEED then
                      if sync_sieint_epinfo_epnr = "0000" then
                        var_maxpacket := 64;
                      elsif epinfo_periodic = '1' then
                        if epinfo_rf_tv = '0' then --HBW ISO 
                          var_maxpacket := 3072;
                        else                       --HBW Interrupt (high bandwith are handled at the software layer) 
                          var_maxpacket := 1024;
                        end if;
                      else                         --Gen Ep (Bulk Interrupt ratefeedback mode) 
                        var_maxpacket := 512;
                      end if;
                    else
                      if epinfo_periodic = '1' and epinfo_rf_tv = '0' then --FS ISO
                        var_maxpacket := 1023;
                      else
                        var_maxpacket := 64;
                      end if;
                    end if;
                    if (to_integer(unsigned(sync_sieint_rx_nbytes)) < var_maxpacket)
                        or (epinfo_periodic = '1' and epinfo_rf_tv = '0')                                          
                        or not(to_integer(unsigned(sync_sieint_rx_nbytes)) 
                                       < to_integer(unsigned(epinfo_nbytes))) then
                      var_data(31)    := '0';
                      --generate interrupt because active bit is cleared
                      dma_set_int        <= '1'; 
                    end if;
                    var_data(30) := epinfo_disabled;
                    var_data(29) := epinfo_stall;
                    var_data(28) := '0';
                    var_data(27) := epinfo_rf_tv;
                    var_data(26) := epinfo_periodic;
                    if to_integer(unsigned(sync_sieint_rx_nbytes)) 
                                        < to_integer(unsigned(epinfo_nbytes)) then
                      var_data(25 downto 11) := std_logic_vector(to_unsigned
                                (to_integer(unsigned(epinfo_nbytes)) 
                               - to_integer(unsigned(sync_sieint_rx_nbytes)),15));
                    else
                      var_data(25 downto 11) := (others => '0');
                    end if;
                    ----------------------------------------------------------
                    -- BVE : bug fix on Aruba (Aruba has C_DALB defined as 19)
                    ----------------------------------------------------------
                    --if C_DALB < 17 then
                    --  var_data(10 downto C_DALB-6) := (others => '0');
                    --end if;
                    --if word_number /= 0 then
                    --  var_data(C_DALB-7 downto  0)
                    --      := std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
                    --else
                    --  var_data(C_DALB-7 downto  0) := epinfo_addr_offset; 
                    --end if;
                    if C_DALB < 17 then
                      var_data(10 downto C_DALB-6) := (others => '0');
                      if word_number /= 0 then
                        var_data(C_DALB-7 downto  0)
                          := std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
                      else
                        var_data(C_DALB-7 downto  0) := epinfo_addr_offset(C_DALB-7 downto  0); 
                      end if;
                    else
                      if word_number /= 0 then
                        var_data(10 downto  0)
                          := std_logic_vector(unsigned(epinfo_addr_offset(10 downto 0)) + to_unsigned(1,11));
                      else
                        var_data(10 downto  0) := epinfo_addr_offset(10 downto 0); 
                      end if;
                    end if;
                    ----------------------------------------------------------
                    if (epinfo_periodic = '0' and epinfo_rf_tv = '0') or 
                       (epinfo_periodic = '1' and epinfo_rf_tv = '1') then  -- bulk or interrupt 
                      if usbreg_epinfo_toggle(endpoint_nr_dir) = '1' then
                        dma_clear_toggle <= '1';
                      else
                        dma_set_toggle   <= '1';
                      end if;
                    end if;
                  elsif RAM_DATAWIDTH = 64 then
                    if epinfo_addr(2) = '1' then
                      var_data(63) := epinfo_active;
                      if pie_speed = HIGH_SPEED then
                        if sync_sieint_epinfo_epnr = "0000" then
                          var_maxpacket := 64;
                        elsif epinfo_periodic = '1' then
                          if epinfo_rf_tv = '0' then --HBW ISO 
                            var_maxpacket := 3072;
                          else                       --HBW Interrupt (high bandwith are handled at the software layer) 
                            var_maxpacket := 1024;
                          end if;
                        else                         --Gen Ep (Bulk Interrupt ratefeedback mode) 
                          var_maxpacket := 512;
                        end if;
                      else
                        if epinfo_periodic = '1' and epinfo_rf_tv = '0' then --FS ISO
                          var_maxpacket := 1023;
                        else
                          var_maxpacket := 64;
                        end if;
                      end if;
                      if (to_integer(unsigned(sync_sieint_rx_nbytes)) < var_maxpacket)
                          or (epinfo_periodic = '1' and epinfo_rf_tv = '0')                                           
                          or not(to_integer(unsigned(sync_sieint_rx_nbytes)) 
                                       < to_integer(unsigned(epinfo_nbytes))) then
                        var_data(63)        := '0';
                        --generate interrupt because active bit is cleared
                        dma_set_int          <= '1'; 
                      end if;
                      var_data(62) := epinfo_disabled;
                      var_data(61) := epinfo_stall;
                      var_data(60) := '0';
                      var_data(59) := epinfo_rf_tv;
                      var_data(58) := epinfo_periodic;
                      if to_integer(unsigned(sync_sieint_rx_nbytes)) 
                                        < to_integer(unsigned(epinfo_nbytes)) then
                        var_data(57 downto 43) := std_logic_vector(to_unsigned
                                (to_integer(unsigned(epinfo_nbytes)) 
                               - to_integer(unsigned(sync_sieint_rx_nbytes)),15));
                      else
                        var_data(57 downto 43) := (others => '0');
                      end if;
                      ----------------------------------------------------------
                      -- BVE : bug fix on Aruba (Aruba has C_DALB defined as 19)
                      ----------------------------------------------------------
                      --if C_DALB < 17 then
                      --  var_data(42 downto C_DALB-6+32) := (others => '0');
                      --end if;
                      --if word_number /= 0 then
                      --  var_data(C_DALB-7+32 downto  32)
                      --    := std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
                      --else
                      --  var_data(C_DALB-7+32 downto  32) := epinfo_addr_offset; 
                      --end if;
                      if C_DALB < 17 then
                        var_data(42 downto C_DALB-6+32) := (others => '0');
                        if word_number /= 0 then
                          var_data(C_DALB-7+32 downto  32)
                            := std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
                        else
                          var_data(C_DALB-7+32 downto  32) := epinfo_addr_offset(C_DALB-7 downto  0); 
                        end if;
                      else
                        if word_number /= 0 then
                          var_data(42 downto  32)
                            := std_logic_vector(unsigned(epinfo_addr_offset(10 downto 0)) + to_unsigned(1,11));
                        else
                          var_data(42 downto  32) := epinfo_addr_offset(10 downto 0); 
                        end if;
                      end if;
                      ----------------------------------------------------------
                      if (epinfo_periodic = '0' and epinfo_rf_tv = '0') or 
                         (epinfo_periodic = '1' and epinfo_rf_tv = '1') then  -- bulk or interrupt 
                        if usbreg_epinfo_toggle(endpoint_nr_dir) = '1' then
                          dma_clear_toggle <= '1';
                        else
                          dma_set_toggle   <= '1';
                        end if;
                      end if;
                    else
                      var_data(31) := epinfo_active;
                      if pie_speed = HIGH_SPEED then
                        if sync_sieint_epinfo_epnr = "0000" then
                          var_maxpacket := 64;
                        elsif epinfo_periodic = '1' then
                          if epinfo_rf_tv = '0' then --HBW ISO 
                            var_maxpacket := 3072;
                          else                       --HBW Interrupt (high bandwith are handled at the software layer) 
                            var_maxpacket := 1024;
                          end if;
                        else                         --Gen Ep (Bulk Interrupt ratefeedback mode) 
                          var_maxpacket := 512;
                        end if;
                      else
                        if epinfo_periodic = '1' and epinfo_rf_tv = '0' then --FS ISO
                          var_maxpacket := 1023;
                        else
                          var_maxpacket := 64;
                        end if;
                      end if;
                      if (to_integer(unsigned(sync_sieint_rx_nbytes)) < var_maxpacket)
                          or (epinfo_periodic = '1' and epinfo_rf_tv = '0')                                           
                          or not(to_integer(unsigned(sync_sieint_rx_nbytes)) 
                                       < to_integer(unsigned(epinfo_nbytes))) then
                        var_data(31)        := '0';
                        --generate interrupt because active bit is cleared
                        dma_set_int          <= '1'; 
                      end if;
                      var_data(30) := epinfo_disabled;
                      var_data(29) := epinfo_stall;
                      var_data(28) := '0';
                      var_data(27) := epinfo_rf_tv;
                      var_data(26) := epinfo_periodic;
                      if to_integer(unsigned(sync_sieint_rx_nbytes)) 
                                        < to_integer(unsigned(epinfo_nbytes)) then
                        var_data(25 downto 11) := std_logic_vector(to_unsigned
                                (to_integer(unsigned(epinfo_nbytes)) 
                               - to_integer(unsigned(sync_sieint_rx_nbytes)),15));
                      else
                        var_data(25 downto 11) := (others => '0');
                      end if;
                      ----------------------------------------------------------
                      -- BVE : bug fix on Aruba (Aruba has C_DALB defined as 19)
                      ----------------------------------------------------------
                      --if C_DALB < 17 then
                      --  var_data(10 downto C_DALB-6) := (others => '0');
                      --end if;
                      --if word_number /= 0 then
                      --  var_data(C_DALB-7 downto  0)
                      --      := std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
                      --else
                      --  var_data(C_DALB-7 downto  0) := epinfo_addr_offset; 
                      --end if;
                      if C_DALB < 17 then
                        var_data(10 downto C_DALB-6) := (others => '0');
                        if word_number /= 0 then
                          var_data(C_DALB-7 downto  0)
                            := std_logic_vector(unsigned(epinfo_addr_offset) + to_unsigned(1,C_DALB-6));
                        else
                          var_data(C_DALB-7 downto  0) := epinfo_addr_offset(C_DALB-7 downto  0); 
                        end if;
                      else
                        if word_number /= 0 then
                          var_data(10 downto  0)
                            := std_logic_vector(unsigned(epinfo_addr_offset(10 downto 0)) + to_unsigned(1,11));
                        else
                          var_data(10 downto  0) := epinfo_addr_offset(10 downto 0); 
                        end if;
                      end if;
                      ----------------------------------------------------------
                      if (epinfo_periodic = '0' and epinfo_rf_tv = '0') or 
                         (epinfo_periodic = '1' and epinfo_rf_tv = '1') then  -- bulk or interrupt 
                        if usbreg_epinfo_toggle(endpoint_nr_dir) = '1' then
                          dma_clear_toggle <= '1';
                        else
                          dma_set_toggle   <= '1';
                        end if;
                      end if;
                    end if;
                  else
                    assert false
                      report "Error : RAM_DATAWIDTH value not supported.";
                  end if;
                else
                  --generate interrupt for SETUP received
                  dma_set_int <= '1';      
                  --reset toggle value for both directions to '1';
                  --This is done in the fs_reg module
                  --epinfo_toggle(0) <= '1'; 
                  --epinfo_toggle(1) <= '1';
                  dma_state   <= IDLE;
                end if;
              end if;
            else
              dma_state <= IDLE;
            end if;
          end if; 

        when WAIT_ON_GNT_FOR_UPDATE =>
          if dma_gnt = '1' then
            dma_req   <= '0';
            dma_write <= '0';
            dma_state <= IDLE;
          end if;
          
        when WAIT_ON_GNT_FOR_SKIP_UPDATE =>
          if epinfo_req = '1' then
            epinfo_req_delayed <= '1';
          end if;
          if dma_gnt = '1' then
            dma_req   <= '0';
            dma_write <= '0';
            dma_state <= IDLE;
          end if;

        when others => -- WAIT_ON_ENDTRANSFER_NO_UPDATE
          if endtransfer = '1' then
            dma_state <= IDLE;
          end if;
      end case;

      data    <= var_data;
      pointer <= var_pointer;

      if var_pointer /= 0 then
        epinfo_txdata_valid <= '1'; 
      else
        epinfo_txdata_valid <= '0';
      end if;

      if sync_busreset = '1' then -- when a busreset is detected, reset the state machine
        dma_state               <= IDLE;
        epinfo_valid            <= '0';
        epinfo_active           <= '0';
        epinfo_disabled         <= '0';
        --epinfo_toggle           <= (others => '0');
        epinfo_stall            <= '0';
        epinfo_periodic         <= '0';
        epinfo_ratefeedbackmode <= '0';
        epinfo_rf_tv            <= '0';
        epinfo_nbytes           <= (others => '0');
        epinfo_addr_offset      <= (others => '0');
        dma_req                 <= '0';
        dma_write               <= '0';
        word_number             <= 0;
        data                    <= (others => '0');
        pointer                 <= 0;
        epinfo_txdata_valid     <= '0'; 
        nbytes                  <= 0;
        dma_set_int             <= '0';
        endtransfer             <= '0';
        dma_clear_skip          <= '0';
        skip_ep                 <= 0;
        epinfo_req_delayed      <= '0';
      end if;
    
    end if;
    
  end process MAIN;

  -----------------------------------------------
  -- Interface towards synchronizer
  -----------------------------------------------
  epinfo_sync_valid           <= epinfo_valid;
   
  -- send NAK on control EP until usbreg_setup bit is cleared
  epinfo_sync_active          <= '0' when setup_not_cleared = '1' and 
                                          sync_sieint_epinfo_epnr = "0000" 
                                     else epinfo_active;
  epinfo_sync_disabled        <= epinfo_disabled;
  
  epinfo_sync_toggle          <= usbreg_epinfo_toggle(endpoint_nr_dir);

  epinfo_sync_stall           <= '0' when setup_not_cleared = '1' and 
                                          sync_sieint_epinfo_epnr = "0000" 
                                     else epinfo_stall and not(epinfo_active);

  epinfo_iso                  <= '1' when epinfo_periodic = '1' and 
                                          epinfo_rf_tv = '0' 
                                     else '0';

  epinfo_sync_iso             <= epinfo_iso;
  epinfo_sync_ratefeedbackmode<= epinfo_ratefeedbackmode;
  epinfo_sync_nbytes          <= epinfo_nbytes;

  epinfo_sync_txdata_valid    <= epinfo_txdata_valid;
  epinfo_sync_txdata          <= data(USB_DATAWIDTH-1 downto 0);


  -- pie decode max packets as follow 
  -- "00": maxpaxcket = 64  : This is set for FS Control, Bulk and Interrupt endpoints and HS Control endpoint
  -- "01": maxpacket = 512  : This is set for HS bulk endpoints and HS interrupt with MaxPacket of 512 bytes
  -- "10": maxpacket = 1023 : This will only be set for FS isochronous endpoints with MaxPacket of 1023 bytes
  -- "11": maxpacket = 1024 : This is set for HS isochronous and HS interrupt endpoints with MaxPacketSize bigger than 512 (including both high-bandwidth iso and interrupt endpoints)

  epinfo_sync_maxpacket <= "00" when ((pie_speed = FULL_SPEED) and 
                                      (epinfo_iso = '0')     ) or
                                     (sync_sieint_epinfo_epnr = "0000") else
                           "10" when (pie_speed = FULL_SPEED) and
                                     (epinfo_iso = '1')                 else
                           "11" when (pie_speed = HIGH_SPEED) and     
                                     (epinfo_periodic = '1')            else
                           "01";


  -----------------------------------------------
  -- Interface towards AHB master
  -----------------------------------------------
  -- sieint module will only issue a request if endpoint number <= NBPHYS_EP+1
  -- it is save to set endpoint_nr_dir equal to zero when epinfo_addr(7 downto 3) 
  -- is bigger than NBPHYS_EP+1. This will prevent a possible range constraint 
  -- violation
  endpoint_nr_dir <= to_integer(unsigned(epinfo_addr(7 downto 3))) 
                     when to_integer(unsigned(sync_sieint_epinfo_epnr & sync_sieint_epinfo_epdir))
                                              <= C_NBPHYSEP+1
                     else 0;

  epinfo_addr     (31 downto  8) <= usbreg_ep_list_start(31 downto 8);
  epinfo_addr     ( 7 downto  4) <= sync_sieint_epinfo_epnr;
  epinfo_addr     ( 3 )          <= sync_sieint_epinfo_epdir;
  epinfo_addr     ( 2 )  <= '1' when (sync_sieint_epinfo_setup = '1')            or
                                     (usbreg_ep_bufinuse(endpoint_nr_dir) = '1')
                                else '0';
  epinfo_addr     ( 1 downto  0) <= (others => '0');

  epinfo_skip_addr(31 downto  8) <= usbreg_ep_skip_list_start(31 downto 8);
  epinfo_skip_addr( 7 downto  3) <= std_logic_vector(to_unsigned(skip_ep,5));
  epinfo_skip_addr( 2 )          <= '1' when (usbreg_ep_bufinuse(skip_ep) = '1')
                                        else '0';
  epinfo_skip_addr( 1 downto  0) <= (others => '0');
  
  proc_databuffer_addr : process(usbreg_data_buffer_start, epinfo_addr_offset, word_number)
  begin
    databuffer_addr (      31 downto C_DALB) <= usbreg_data_buffer_start(31 downto C_DALB);
    databuffer_addr (C_DALB-1 downto      6) <= epinfo_addr_offset;
    if RAM_DATAWIDTH = 32 then
      databuffer_addr (     5 downto      2) <= std_logic_vector(to_unsigned(word_number,4));
    elsif RAM_DATAWIDTH = 64 then
      databuffer_addr(      5 downto      3) <= std_logic_vector(to_unsigned(word_number,4)(2 downto 0));
      databuffer_addr(2)                     <= '0';     
    else
      assert false
        report "Error : RAM_DATAWIDTH value not supported.";
    end if;
    databuffer_addr (       1 downto      0) <= (others => '0');
  end process;

  dma_addr <= databuffer_addr  when dma_state = CHECK_EPINFO       or
                                    dma_state = FETCH_INEP_DATA    or
                                    dma_state = WAIT_ON_OUTEP_DATA else
              epinfo_skip_addr when dma_state = READ_EPINFO_SKIP  or
                                    dma_state = WAIT_ON_GNT_FOR_SKIP_UPDATE
                               else epinfo_addr;
  dma_wdata <= data(RAM_DATAWIDTH-1 downto 0);

  ahb_selected      <= '1';
  dma_ahb_selected <= ahb_selected;
  dma_word_enable  <= "11" when RAM_DATAWIDTH = 64 and
                                (dma_state = CHECK_EPINFO       or
                                 dma_state = FETCH_INEP_DATA    or
                                 dma_state = WAIT_ON_OUTEP_DATA or
                                 dma_state = READ_EPINFO_SKIP   or
                                 dma_state = WAIT_ON_GNT_FOR_SKIP_UPDATE) else
                      "10" when RAM_DATAWIDTH  = 64 and
                                epinfo_addr(2) = '1'    
                           else "01";
  
  -----------------------------------------------
  -- Interface towards FS_REG module master
  -----------------------------------------------
  --dma_epinfo_toggle <= epinfo_toggle;
  dma_sent_NAK      <= sync_sieint_sentNAK;
  dma_physepnr      <= endpoint_nr_dir;
  dma_skip_ep       <= skip_ep;

  usb_dma_fpga(3 downto 0) <= "0000" when dma_state = IDLE else
                              "0001" when dma_state = READ_EPINFO_SKIP else
                              "0010" when dma_state = READ_EPINFO else
                              "0011" when dma_state = CHECK_EPINFO else
                              "0100" when dma_state = FETCH_INEP_DATA else
                              "0101" when dma_state = WAIT_ON_OUTEP_DATA else
                              "0110" when dma_state = WAIT_ON_GNT_FOR_SKIP_UPDATE else
                              "0111" when dma_state = WAIT_ON_GNT_FOR_UPDATE else
                              "1000";-- when dma_state = WAIT_ON_ENDTRANSFER_NO_UPDATE else

  usb_dma_fpga(4) <= epinfo_req;
  usb_dma_fpga(5) <= epinfo_valid;
  usb_dma_fpga(6) <= epinfo_active;
  usb_dma_fpga(7) <= epinfo_disabled;
  usb_dma_fpga(8) <= epinfo_stall;
  usb_dma_fpga(9) <= epinfo_req;
  usb_dma_fpga(19 downto 10) <= epinfo_nbytes(9 downto 0);
  usb_dma_fpga(20) <= setup_not_cleared;
  usb_dma_fpga(24 downto 21) <= sync_sieint_epinfo_epnr;
  usb_dma_fpga(25) <= epinfo_addr(2);
  usb_dma_fpga(26) <= dma_rdata(31);
  usb_dma_fpga(27) <= dma_rdata(63);
  usb_dma_fpga(63 downto 28) <= (others => '0');

end RTL;

-- LAB epinfo_ratefeedbackmode could be removed
--
