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

library ieee;
use ieee.std_logic_1164.all;

entity usb_clock_gate is 
port (
      ip_Clk            : in  std_logic;
      ip_Clk_en         : in  std_logic;
      op_Clk_g          : out  std_logic;
      ip_tcb_clkgate_se : in  std_logic
);
end usb_clock_gate;

-- This is a latch-based gating system according to the ED&T DFT rules
--               -----
--               |   |
--   enable -----|   |------|--\
--               |   |      |and|---- gated clock
--               |   |    |-|--/
--               -----    |
--                 o      |
--                 |      |
--                 |      |
--   clock  ---------------

architecture RTL of usb_clock_gate is

  signal ClkEnable_Latch : std_ulogic;
  attribute syn_hier : string;
  attribute syn_hier of rtl: architecture is "firm";
  attribute syn_preserve : boolean;
  attribute syn_preserve of rtl: architecture is true;

begin  -- architecture RTL

  p_GateClk : process (ip_Clk, ip_Clk_en) is
  begin
    if (ip_Clk = '0') then
      ClkEnable_Latch <= ip_Clk_en;
    end if;
  end process p_GateClk;

  op_clk_g <= ClkEnable_Latch and ip_Clk;

end architecture RTL;

configuration usb_clock_gate_rtl_cfg of usb_clock_gate is

  for rtl

  end for;

end configuration usb_clock_gate_rtl_cfg;
