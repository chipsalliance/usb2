--  ----------------------------------------------------------------------------
--                     Copyright Message
--  ----------------------------------------------------------------------------
--
--   NXP B.V. confidential and proprietary.
--   COPYRIGHT (c) NXP B.V. 2011
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
--               File: ahb_dma_slave.m.vhdl
--
--             Author: Adam Fuks / Bart Vertenten
--
--       Organisation: Corporate I&T / IP & Architecture
--
--              $Date: Sun Apr 23 19:20:43 2017 $
--
--            Project: IP_3511_HS - Low gate count HS USB peripheral IP 
--
--        Description: 
--
--          $Revision: 1.5 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: ahb_dma_slave.m.vhdl.rca $
--   
--    Revision: 1.5 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--   
--   
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

library rtl;
use rtl.usb_general_subcmp_pkg.all;

entity ahb_dma_slave is
generic(
        AHB_DATAWIDTH  : integer := 32;--32, 64 
        RAM_DATAWIDTH  : integer := 64;--32, 64, 128, 256 (and must not be smaller than AHB_DATAWIDTH)
        RAM_ADDR_WIDTH : integer := 15 --256 KBytes max = 2**16 (if RAM_DATAWIDTH = 32 bits)
                                      --               = 2**15 (if RAM_DATAWIDTH = 64 bits)
                                      --               = 2**14 (if RAM_DATAWIDTH = 128 bits)
       );
port (ahb_dma_slave_fpga : out std_logic_vector(63 downto 0); 
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
end ahb_dma_slave; 

architecture RTL of ahb_dma_slave is   

constant RAM_ADDR_OFFSET : integer := log2(RAM_DATAWIDTH/8);

signal write_on    : std_logic;
signal missed_read : std_logic;
signal stored_addr : std_logic_vector((RAM_ADDR_WIDTH-1+RAM_ADDR_OFFSET) downto 0);
signal stored_size : std_logic_vector(1 downto 0);
signal use_stored  : std_logic;

signal ahb_addr    : std_logic_vector((RAM_ADDR_WIDTH-1+RAM_ADDR_OFFSET) downto 0);
signal ahb_cs      : std_logic;
signal ahb_d       : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal ahb_size    : std_logic_vector(1 downto 0);
signal ahb_web     : std_logic;
signal ahb_q       : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal ahb_bsel    : std_logic_vector(RAM_DATAWIDTH-1 downto 0);

signal ahb_stall   : std_logic;
signal write_followed_by_read : std_logic;
signal ahb_read_req           : std_logic;
signal ahb_write_req          : std_logic;
signal ahb_control            : std_logic;

signal usb_bsel    : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal usb_addr    : std_logic_vector(31 downto 0);
signal usb_cs      : std_logic;
signal usb_d       : std_logic_vector(RAM_DATAWIDTH-1 downto 0);
signal usb_web     : std_logic;
signal usb_q       : std_logic_vector(RAM_DATAWIDTH-1 downto 0);

signal read_data_available : std_logic;
signal use_ahb             : std_logic;
signal ads_mem_cs_int      : std_logic;
signal ads_mem_cs_int_d    : std_logic;
signal dma_mem_gnt         : std_logic;

begin

------------------------------
--  AHB side
--
--
--    AHB side has secondary priority, If USB needs access, it will postpone AHB transaction
--    
--    ahb_stall  - stall from arbiter (either write followed by read, or USB using the bus)
--
--    The flow is the following  :
--	 - At any point when memory is being used by USB side, a ahb_stall will be issued to AHB
--	 - In case of read, ahb will allow direct read to RAM. If ahb_stall, AHB control cycle will be stored
--	 - In case of write, ahb will store its control signals
--
--
------------------------------

-- write_followed by read is when a write from AHB is underway and a read is issued. 
-- Note that under any interaction with USB, we'd be stalled by ahb_stall so no need to worry about what happens there.
write_followed_by_read <= write_on and ahb_read_req;
  
ahb_control    <= ads_hsel       and ads_hready_in and ads_htrans(1);
ahb_write_req  <= ahb_control    and ads_hwrite;
ahb_read_req   <= ahb_control    and not(ads_hwrite);

proc_ahb_main : process(ads_hclk, ads_hresetn)
begin
   if (ads_hresetn = '0') then
     write_on	  <= '0';
     missed_read  <= '0';
     stored_addr  <= (others => '0');
     stored_size  <= (others => '0');
   elsif ads_hclk'event and ads_hclk = '1' then 
     -- if we want to read but stalling or ahb stalling and we have pending missed read
     if ((ahb_stall = '1' or  write_followed_by_read = '1') and ahb_read_req = '1') or 
        (ahb_stall  = '1' and missed_read = '1')                                    then
       missed_read <=  '1';  
     else
       missed_read <= '0';
     end if;
     
     -- if want to start a write (because write is two cycle in AHB) or we are in a state waiting for a write to take place 
     if (ahb_write_req = '1') or (ahb_stall = '1' and write_on = '1') then
       write_on <= '1';
     else
       write_on <= '0';	   
     end if;
       
     -- Store control information everything there is a valid control for our interface
     -- There will be no overflow of this, because this module will drive hready low when it is stalled.
     if ahb_control = '1' then
       stored_addr <= ads_haddr((RAM_ADDR_WIDTH-1+RAM_ADDR_OFFSET) downto 0);
       stored_size <= ads_hsize(1 downto 0); 
     end if;  
   end if;    
end process proc_ahb_main;

use_stored <= write_on or missed_read;

proc_ahb_bsel : process(ahb_size, ahb_addr)
variable var_start_byte : integer range 0 to RAM_DATAWIDTH/8-1;
begin
  ahb_bsel <= (others => '0');
  case ahb_size is 
    when "00" => 
      var_start_byte := to_integer(unsigned(ahb_addr(log2(RAM_DATAWIDTH/8)-1 downto 0)));
      for i in 0 to 7 loop
        ahb_bsel((8*var_start_byte)+i) <= '1';
      end loop;
    when "01" =>
      var_start_byte := to_integer(unsigned(ahb_addr(log2(RAM_DATAWIDTH/8)-1 downto 1)));
      for i in 0 to 15 loop
        ahb_bsel((16*var_start_byte)+i) <= '1';
      end loop;
    when "10" =>
      var_start_byte := to_integer(unsigned(ahb_addr(log2(RAM_DATAWIDTH/8)-1 downto 2)));
      for i in 0 to 31 loop
        ahb_bsel((32*var_start_byte)+i) <= '1';
      end loop;
    when others =>
      if AHB_DATAWIDTH > 32 then
        var_start_byte := to_integer(unsigned(ahb_addr(log2(RAM_DATAWIDTH/8)-1 downto 3)));
        for i in 0 to 63 loop
          ahb_bsel((8*var_start_byte)+i) <= '1';
        end loop;
      end if;
  end case;
end process proc_ahb_bsel;

ahb_addr     <= stored_addr when use_stored = '1' else ads_haddr((RAM_ADDR_WIDTH-1+RAM_ADDR_OFFSET) downto 0); 
ahb_cs       <= ahb_read_req or use_stored;

proc_ahb_d : process(ads_hwdata)
begin
  for i in 0 to (RAM_DATAWIDTH/AHB_DATAWIDTH)-1 loop
    ahb_d((AHB_DATAWIDTH*(i+1))-1 downto (AHB_DATAWIDTH*i)) <= ads_hwdata;
  end loop;
end process proc_ahb_d;

ahb_size       <= stored_size when use_stored = '1' else ads_hsize(1 downto 0);
ahb_web        <= not(write_on);

proc_ads_hrdata : process(ahb_q, stored_addr)
begin
  case RAM_DATAWIDTH is
    when 32 =>
      ads_hrdata <= ahb_q;
    when 64 =>
      if stored_addr(2) = '1' then
        ads_hrdata <= ahb_q(63 downto 32);
      else
        ads_hrdata <= ahb_q(31 downto 0);
      end if; 
    when 128 =>
      case stored_addr(3 downto 2) is
        when "00"   => ads_hrdata <= ahb_q( 31 downto 0);
	when "01"   => ads_hrdata <= ahb_q( 63 downto 32);
        when "10"   => ads_hrdata <= ahb_q( 95 downto 64);
	when others => ads_hrdata <= ahb_q(127 downto 96);
      end case; 
    when 256 =>
      case stored_addr(4 downto 2) is
        when "000"  => ads_hrdata <= ahb_q( 31 downto   0);
	when "001"  => ads_hrdata <= ahb_q( 63 downto  32);
        when "010"  => ads_hrdata <= ahb_q( 95 downto  64);
	when "011"  => ads_hrdata <= ahb_q(127 downto  96);
        when "100"  => ads_hrdata <= ahb_q(159 downto 128);
	when "101"  => ads_hrdata <= ahb_q(191 downto 160);
        when "110"  => ads_hrdata <= ahb_q(223 downto 192);
	when others => ads_hrdata <= ahb_q(255 downto 224);
      end case; 
    when others =>
      assert FALSE report "Error : RAM_DATAWIDTH value is not supported" severity error;
  end case;
end process proc_ads_hrdata;

-- Watchout : HREADY is being driven by a USB req which controls ahb_stall 
-- (this cannot be late in generation)
ads_hready_out <= not((ahb_stall and write_on) or missed_read); 

ads_hresp      <= "00";

------------------------------
--  USB side
--
--    USB side has primary priority, If USB needs access, it will postpone AHB transaction
-- 
--    (Assumption : USB will hold its control signals steady if grant signal is low)
--    (Assumption : USB always accesses 64bits)
--    
--    The flow is the following  :
--	 - In case of write, acess is always granted directly
--	 - In case of read , grant is only issued once read data is available
--
--
------------------------------

usb_addr        <= ads_dma_addr;
usb_cs          <= ads_dma_req;
usb_d           <= ads_dma_wdata;
usb_web         <= not(ads_dma_write and ads_dma_req);

proc_usb_bsel : process(ads_dma_dword_en, usb_addr)
variable var_usb_start_dword : integer range 0 to 3;
begin
  usb_bsel <= (others => '0');
  case RAM_DATAWIDTH is 
    when 64  =>
      if ads_dma_dword_en(0) = '1' then
        usb_bsel(31 downto  0) <= (others => '1');
      end if;
      if ads_dma_dword_en(1) = '1' then
        usb_bsel(63 downto 32) <= (others => '1');
      end if;
    when 128 =>
      var_usb_start_dword := to_integer(usb_addr(6));
      if ads_dma_dword_en(0) = '1' then
        usb_bsel((64*var_usb_start_dword)+31 downto (64*var_usb_start_dword)) <= (others => '1');
      end if;
      if ads_dma_dword_en(1) = '1' then
        usb_bsel((64*var_usb_start_dword)+63 downto (64*var_usb_start_dword)+32) <= (others => '1');
      end if;
    when 256 =>
      var_usb_start_dword := to_integer(unsigned(usb_addr(7 downto 6)));
      if ads_dma_dword_en(0) = '1' then
        usb_bsel((64*var_usb_start_dword)+31 downto (64*var_usb_start_dword)) <= (others => '1');
      end if;
      if ads_dma_dword_en(1) = '1' then
        usb_bsel((64*var_usb_start_dword)+63 downto (64*var_usb_start_dword)+32) <= (others => '1');
      end if;
    when others =>
      assert FALSE report "Error : RAM_DATAWIDTH value is not supported" severity error;
  end case;
end process proc_usb_bsel;

ads_dma_rdata   <= usb_q;
ads_dma_gnt     <= dma_mem_gnt;

dma_mem_gnt   <= '1' when (usb_web = '0') or
                          (read_data_available = '1') 
                     else '0';

------------------------------
--  Unified port to Memory
------------------------------

use_ahb          <= not(usb_cs); -- arbitrate

ads_mem_cs_int   <= usb_cs when use_ahb = '0' else ahb_cs; 
-- Keep chip select high for one more clock cycle.
-- In case of a read, the chip select must remain high while the read data is given.
-- This is definitely required by FPGA embedded RAM. Not sure about others.
ads_mem_cs       <= ads_mem_cs_int or ads_mem_cs_int_d;
ads_mem_a	 <= usb_addr(RAM_ADDR_WIDTH+RAM_ADDR_OFFSET-1 downto RAM_ADDR_OFFSET) 
                    when use_ahb = '0' 
		    else ahb_addr(RAM_ADDR_WIDTH+RAM_ADDR_OFFSET-1 downto RAM_ADDR_OFFSET); 
ads_mem_bsel	 <= usb_bsel when use_ahb = '0' else 
                    ahb_bsel;
ads_mem_d	 <= usb_d    when use_ahb = '0' else ahb_d;
ads_mem_web_out	 <= usb_web  when use_ahb = '0' else ahb_web;

ahb_q            <= ads_mem_q;
usb_q            <= ads_mem_q;

-- stall ahb if usb is accessing ram
ahb_stall        <= usb_cs;				  


proc_read_data_available : process(ads_hclk, ads_hresetn) 
begin
   if (ads_hresetn = '0') then
     read_data_available <= '0';
     ads_mem_cs_int_d    <= '0';
   elsif ads_hclk'event and ads_hclk = '1' then
     ads_mem_cs_int_d    <= ads_mem_cs_int;
     if ads_dma_req   = '1' and 
        ads_dma_write = '0' and 
        dma_mem_gnt   = '0' then
       read_data_available <= '1';
     else
       read_data_available <= '0';
     end if;
   end if;
end process proc_read_data_available;


ahb_dma_slave_fpga <= (others => '0');

end RTL;
