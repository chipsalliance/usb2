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
use IEEE.numeric_std.ALL;

entity usb_fs_mux is
  generic(C_DATAWIDTH        : integer := 32);
  port (
      dma_dma_addr      : in    std_logic_vector(31 downto 0); 
      dma_dma_req       : in    std_logic;                     
      dma_dma_gnt       : out   std_logic;                     
      dma_dma_write     : in    std_logic;                     
      dma_dma_wdata     : in    std_logic_vector(C_DATAWIDTH-1 downto 0); 
      dma_dma_rdata     : out   std_logic_vector(C_DATAWIDTH-1 downto 0); 

      ahb_dma_addr      : out   std_logic_vector(31 downto 0); 
      ahb_dma_req       : out   std_logic;                       
      ahb_dma_gnt       : in    std_logic;                      
      ahb_dma_write     : out   std_logic;                       
      ahb_dma_wdata     : out   std_logic_vector(C_DATAWIDTH-1 downto 0); 
      ahb_dma_rdata     : in    std_logic_vector(C_DATAWIDTH-1 downto 0); 

      upd_dma_addr      : out   std_logic_vector(31 downto 0); 
      upd_dma_req       : out   std_logic;                     
      upd_dma_gnt       : in    std_logic;                     
      upd_dma_write     : out   std_logic;                     
      upd_dma_wdata     : out   std_logic_vector(C_DATAWIDTH-1 downto 0); 
      upd_dma_rdata     : in    std_logic_vector(C_DATAWIDTH-1 downto 0);
      
      dma_ahb_selected  : in    std_logic 
     );
end usb_fs_mux; 
      
architecture RTL of usb_fs_mux is   

begin

ahb_dma_addr  <= dma_dma_addr;
upd_dma_addr  <= dma_dma_addr;

ahb_dma_req   <= dma_dma_req and dma_ahb_selected;
upd_dma_req   <= dma_dma_req and not(dma_ahb_selected);

dma_dma_gnt   <= ahb_dma_gnt when dma_ahb_selected = '1' else upd_dma_gnt;

ahb_dma_write <= dma_dma_write;
upd_dma_write <= dma_dma_write;

ahb_dma_wdata <= dma_dma_wdata;
upd_dma_wdata <= dma_dma_wdata;

dma_dma_rdata <= ahb_dma_rdata when dma_ahb_selected = '1' else upd_dma_rdata;

 
end RTL; --usb_fs_mux
