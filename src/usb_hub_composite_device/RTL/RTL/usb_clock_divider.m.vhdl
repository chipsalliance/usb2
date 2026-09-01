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
use ieee.numeric_std.all;

library usb_lib;
use usb_lib.usb_general_subcmp_pkg.all;

entity usb_clock_divider is 
generic (C_WIDTH          : natural := 3 );
port (
      ip_clk            : in  std_logic;
      ip_rstn           : in  std_logic;
      ip_clk_en         : in  std_logic;
      ip_divider        : in  std_logic_vector(C_WIDTH-1 downto 0);
      op_clk            : out std_logic;
      ip_tcb_clkgate_se : in  std_logic
);
end usb_clock_divider;

architecture rtl of usb_clock_divider is

  component usb_clock_gate 
    port(
        ip_clk            : in  std_logic;
        ip_clk_en         : in  std_logic;
        op_clk_g          : out std_logic;
        ip_tcb_clkgate_se : in  std_logic
      );
  end component;

  signal s_clk_gate_en : std_logic;
  signal s_clkenable   : std_logic;
  signal s_clk_en_s    : std_logic;
  signal s_clk_cnt_en  : std_logic;

  signal s_ClkCnt      : unsigned(C_WIDTH-1 downto 0);
  signal s_clkperiod   : unsigned(C_WIDTH-1 downto 0);


begin  -- architecture rtl
 
  usb_clock_gate_1 : usb_clock_gate
    port map (
      ip_clk            => ip_clk,
      ip_clk_en         => s_clk_gate_en,
      op_clk_g          => op_clk,
      ip_tcb_clkgate_se => ip_tcb_clkgate_se);
  
  -- Convert counter values to gray.
  s_clkperiod <= unsigned(BinToGray(ip_divider));

  -- Gray counter to do the clock division
  p_ClkCounter : process (ip_clk, ip_rstn)
    variable ResetCounter : std_logic;
  begin

    if (ip_rstn = '0') then
      s_clk_cnt_en   <= '0';
      s_clk_en_s     <= '0';
      ResetCounter   := '1';
      s_ClkCnt       <= (others => '0');

    elsif rising_edge(ip_clk) then

      s_clk_cnt_en <= '0';
      s_clk_en_s   <= ip_clk_en;
      ResetCounter := '0';
      if (s_ClkCnt = s_clkperiod) or (ip_clk_en = '0') then  
        ResetCounter  := '1';
      end if;

      if (ResetCounter = '1') then
        s_ClkCnt <= (others => '0');
      else 
        s_ClkCnt <= increment(s_ClkCnt);
      end if;

      if (to_integer(s_ClkCnt) = 0) then
        s_clk_cnt_en <= '1';
      end if;

    end if;

  end process p_ClkCounter;

  s_clkenable <= s_clk_en_s and ip_clk_en;

  s_clk_gate_en <= '0' when (s_clkenable = '0') else
                   '1' when ((s_clkperiod = 0) and (s_clkenable = '1')) else 
                   s_clk_cnt_en;

end architecture rtl;
