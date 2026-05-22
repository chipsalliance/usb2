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
--               File: ahb_dma_slave_cmp_pkg.p.vhdl
--
--             Author: Alexandre Esquenet
--
--       Organisation: IP & Architecture/ CENTRAL R&D
--
--              $Date: Sun Apr 23 19:20:43 2017 $
--
--            Project: IP_3511_HS - Low gate count HS USB peripheral IP 
--
--        Description: componenet package of ahb_dma_slave module
--
--          $Revision: 1.4 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: ahb_dma_slave_cmp_pkg.p.vhdl.rca $
--   
--    Revision: 1.4 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.3 Wed Mar 30 18:02:16 2011 beq03067
--    wrong check in before.
--   
--    Revision: 1.2 Wed Mar 30 18:01:27 2011 beq03067
--    sram write enable is not driven low in case the sram chip select is not set.
--    "Problem" was seen on FPGA on a single ahb write transfert.
--   
--    Revision: 1.1 Thu Mar  3 16:47:59 2011 beq03067
--    First check in.
--   
--   
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package ahb_dma_slave_cmp_pkg is
component ahb_dma_slave
generic(
        AHB_DATAWIDTH  : integer := 32;--32, 64
        RAM_DATAWIDTH  : integer := 64;--32, 64, 128, 256 (and must be above or equal to AHB_DATAWIDTH)
        RAM_ADDR_WIDTH : integer := 15 --256 KBytes max = 2**16 (if RAM_DATAWIDTH = 32 bits)
                                      --               = 2**15 (if RAM_DATAWIDTH = 64 bits)
                                      --               = 2**14 (if RAM_DATAWIDTH = 128 bits)
       );
port ( --system input
      ads_hclk          : in  std_logic; 
      ads_hresetn       : in  std_logic; 
      --"dma" internal ip_3511 interface
      ads_dma_addr      : in  std_logic_vector(31 downto 0); 
      ads_dma_req       : in  std_logic;       
      ads_dma_gnt       : out std_logic;
      ads_dma_write     : in  std_logic;
      ads_dma_wdata     : in std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      ads_dma_rdata     : out  std_logic_vector(RAM_DATAWIDTH-1 downto 0);
      ads_dma_dword_en  : in   std_logic_vector(RAM_DATAWIDTH/32-1 downto 0);
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
      ads_hsize         : in  std_logic_vector(2 downto 0);
      ads_hburst        : in  std_logic_vector(2 downto 0);
      ads_hwdata        : in  std_logic_vector(AHB_DATAWIDTH-1 downto 0);
      ads_hrdata        : out std_logic_vector(AHB_DATAWIDTH-1 downto 0);
      ads_hresp         : out std_logic_vector(1 downto 0); 
      ads_hready_out    : out std_logic;   
      ads_hready_in     : in  std_logic  
      
      );
end component;
end ahb_dma_slave_cmp_pkg;
