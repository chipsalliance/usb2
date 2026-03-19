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
--               File: usb_ahb_master.m.vhdl
--
--             Author: Bart Vertenten
--
--       Organisation: Corporate I&T / IP & Architecture
--
--              $Date: Sun Apr 23 19:20:43 2017 $
--
--            Project: IP_3511 - Low gate count full-speed USB peripheral IP 
--
--        Description: 
--
--          $Revision: 1.3 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_ahb_master.m.vhdl.rca $
--   
--    Revision: 1.3 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.1 Thu Apr  1 09:49:54 2010 bve
--    Initial version
--   
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;

entity usb_ahb_master is
port (
      hclk              : in   std_logic;
      hresetn           : in   std_logic;
      
      haddr             : out   std_logic_vector(31 downto 0);
      hwrite            : out   std_logic;                    
      htrans            : out   std_logic_vector( 1 downto 0); 
      hwdata            : out   std_logic_vector(31 downto 0);
      hrdata            : in    std_logic_vector(31 downto 0);
--      hresp            : in    std_logic_vector(1 downto 0); -- not used 
      hready            : in    std_logic;                    
      hsize             : out   std_logic_vector( 2 downto 0); 
      hburst            : out   std_logic_vector( 2 downto 0); 
      hprot             : out   std_logic_vector( 3 downto 0);
      
      dma_addr          : in    std_logic_vector(31 downto 0); 
      dma_req           : in    std_logic;                     
      dma_gnt           : out   std_logic;                     
      dma_write         : in    std_logic;                     
      dma_wdata         : in    std_logic_vector(31 downto 0); 
      dma_rdata         : out   std_logic_vector(31 downto 0)  

     );
end usb_ahb_master; 
      

architecture RTL of usb_ahb_master is   

signal data_phase : std_logic;

begin

  --------------------------------------------------
  -- No burst need to be supported
  -- Only single word transfers are done for IP_3511
  --------------------------------------------------
  hburst <= (others => '0');

  --------------------------------------------------
  -- All access to memory will always be 32 bit
  -- for both read and write operations.
  --------------------------------------------------
  hsize  <= "010";
  
  --------------------------------------------------
  -- All access by the DMA has always the same type
  -- Bit 0 = '1' : data access
  -- Bit 1 = '0' : user access
  -- Bit 2 = '0' : not bufferable
  -- Bit 3 = '0' : not cacheable
  --------------------------------------------------
  hprot  <= "0001";
  
  --------------------------------------------------
  -- The bus master is only doing non-sequential accesses
  -- Bit 0 of the HTRANS signal can be fixed to zero
  -- Bit 1 of the HTRANS signal indicates if there is a buss access or not
  --         -> this is only required during the address phase
  --------------------------------------------------
  htrans(0)  <= '0';
  htrans(1)  <= dma_req and not(data_phase) ;
  
  --------------------------------------------------
  -- The bus master is only doing non-sequential accesses
  -- Each transfer has 2 phases (address + data)
  -- This block is not starting the second access 
  -- before the firs one is completely finished
  --------------------------------------------------
  haddr     <= dma_addr;
  hwrite    <= dma_write;
  hwdata    <= dma_wdata;
  dma_rdata <= hrdata;
  
  --------------------------------------------------
  -- No support on this moment for any hresp signals
  -- Master always expects an OKAY on hresp signal
  --------------------------------------------------
  -- hresp  
  
  --------------------------------------------------
  -- Return grant while a data phase is on-going
  -- and the ready signal is asserted
  --------------------------------------------------
  dma_gnt <= data_phase and hready;

  proc_phase_select : process(hclk, hresetn)
  begin
    if hresetn = '0' then
      data_phase <= '0';
    elsif hclk'event and hclk = '1' then
      if dma_req = '1' and hready = '1' then
        data_phase <= not(data_phase);
      end if;
    end if;
  end process proc_phase_select;

end RTL; --usb_ahb_master
