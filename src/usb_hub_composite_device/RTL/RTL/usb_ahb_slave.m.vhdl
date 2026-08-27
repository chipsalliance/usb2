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
