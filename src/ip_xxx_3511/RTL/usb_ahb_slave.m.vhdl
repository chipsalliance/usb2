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
--               File: usb_ahb_slave.m.vhdl
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
--   $Log: usb_ahb_slave.m.vhdl.rca $
--   
--    Revision: 1.3 Wed Feb  1 07:37:14 2012 beq03099
--    made ahb_addr width configurable using a generic
--   
--    Revision: 1.2 Wed Mar  2 09:30:29 2011 beq03099
--    fixed problem with AHB read immediately following AHB write 
--    on the same address. Make sure that new data is read.
--   
--    Revision: 1.1 Thu Apr  1 09:49:54 2010 bve
--    Initial version
--   
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;

entity usb_ahb_slave is
generic (AHB_SLAVE_ADDR_WIDTH : integer := 4);
port (
      hclk		: in	std_logic;   
      hresetn		: in	std_logic;   
      
      haddr		: in	std_logic_vector(AHB_SLAVE_ADDR_WIDTH+1 downto 2); 
      hwrite		: in	std_logic;   
      hsel		: in	std_logic;   
      htrans1		: in	std_logic;   -- bit 1 of the htrans signal
      hwdata		: in	std_logic_vector(31 downto 0);
      hrdata		: out	std_logic_vector(31 downto 0);
      hresp		: out	std_logic_vector(1 downto 0); 
      hready		: out	std_logic;   
      hready_glb	: in	std_logic;   
      
      reg_waddr		: out	std_logic_vector(AHB_SLAVE_ADDR_WIDTH-1 downto 0);   
      reg_wdata         : out   std_logic_vector(31 downto 0);  
      reg_raddr		: out	std_logic_vector(AHB_SLAVE_ADDR_WIDTH-1 downto 0);   
      reg_rdata		: in	std_logic_vector(31 downto 0);  
      reg_write         : out   std_logic                       
     );
end usb_ahb_slave; 

architecture RTL of usb_ahb_slave is   
begin
-- -----------------------------------------------------------------------
-- AHB transfer write
-- -----------------------------------------------------------------------
   reg_wdata <= hwdata;

   proc_ahb_write : process (hresetn, hclk)
   begin
     if (hresetn = '0') then
       reg_waddr <= (others => '0');
       reg_write <= '0';
     elsif (hclk'event and hclk = '1') then
       if hsel       = '1' and 
          hready_glb = '1' and 
          htrans1    = '1' and 
          hwrite     = '1' then
         reg_write <= '1';
       else
         reg_write <= '0';
       end if;
       if hwrite = '1' then
         reg_waddr(AHB_SLAVE_ADDR_WIDTH-1 downto 0) <= haddr(AHB_SLAVE_ADDR_WIDTH+1 downto 2);
       end if;
     end if;
   end process proc_ahb_write;
  
-- -----------------------------------------------------------------------
-- AHB transfer read
-- -----------------------------------------------------------------------
   hrdata <= reg_rdata;

-- -----------------------------------------------------------------------
-- HRDATA Address Bus
--   reg_rdata is the combinatorial output of a mux controlled by reg_addr
--   The reg_raddr must be delayed by one clock cycle such that the data
--   is available at the same time when it needs to put on the AHB bus.
-- -----------------------------------------------------------------------
   proc_ahb_read : process (hresetn, hclk)
   begin
     if (hresetn = '0') then
       reg_raddr <= (others => '0');
     elsif (hclk'event and hclk = '1') then
       reg_raddr(AHB_SLAVE_ADDR_WIDTH-1 downto 0) <= haddr(AHB_SLAVE_ADDR_WIDTH+1 downto 2);
     end if;  
   end process proc_ahb_read;
       
-- -----------------------------------------------------------------------
-- HRESP[1:0] (transfer response signal)
--   It is impossible for a master to do an illegal access.
--   HRESP is fixed to all zero (=OKAY)
-- -----------------------------------------------------------------------
   hresp <= "00";
   
-- -----------------------------------------------------------------------
-- HREADY (device ready signal)
--   All accesses to registers can be done in one clock cycle
--   The slave is not introducing any wait cycles.
--   Therefor the hready signal can be fixed to one.
-- -----------------------------------------------------------------------
   hready <= '1';

end RTL; --usb_ahb_slave
