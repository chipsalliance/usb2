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
--               File: usb_host_sof_timer.m.vhdl
--
--             Author: Bart Vertenten
--
--       Organisation: CentralR&D / Design Services / MSS
--
--              $Date: Sun Apr 23 19:20:43 2017 $
--
--            Project: IP_3515 - Low gate count USB host IP 
--
--        Description: 
--
--          $Revision: 1.3 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_host_sof_timer.m.vhdl.rca $
--   
--    Revision: 1.3 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.6 Tue Mar 13 13:45:34 2012 beq03099
--    fix for PR#10 - full-speed interrupt must be sent immediate after SOF
--   
--    Revision: 1.5 Fri Mar  9 14:30:17 2012 beq03099
--    added signal usb_decrement_bytes
--   
--    Revision: 1.4 Tue Mar  6 10:52:21 2012 beq03099
--    added usbreg_reset_sync and usbreg_light_reset_sync to entity of usb_host_sof_timer
--   
--    Revision: 1.3 Fri Feb  3 14:28:05 2012 beq03099
--    fixed SOF length (is running on 60MHz clock)
--   
--    Revision: 1.2 Fri Feb  3 13:57:13 2012 beq03099
--    fixed sof generation issue
--   
--    Revision: 1.1 Wed Jan 18 08:58:36 2012 beq03099
--    initial version
--   
--   
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

entity usb_host_sof_timer is
port (
      --To/From external
      usb_rst_n                  : in  std_logic;
      usb_clk                    : in  std_logic;

      --To/From usb_host_synchronizer module
      usbreg_reset_sync          : in  std_logic;
      usbreg_light_reset_sync    : in  std_logic;
      usbreg_run_sync            : in  std_logic;
      usbreg_fladj_sync          : in  std_logic_vector(5 downto 0);
      usbreg_fladj_change_sync   : in  std_logic;
      usb_inc_frindex_toggle     : out std_logic;
      usb_decrement_bytes        : out std_logic;
      usb_uframe_count           : out std_logic_vector(2 downto 0);

      --To/From usb_host_pie module
      pie_devicespeed            : in  std_logic_vector(1 downto 0);
      usb_send_sof               : out std_logic;
      usb_endofframe             : out std_logic
     );
end usb_host_sof_timer; 

architecture RTL of usb_host_sof_timer is   

constant MAX_FRAME_COUNT  : integer := 7625;
constant MAX_FRAME_COUNT_MIN_FLADJ : integer := 7499-64;
constant ENDOFFRAME_TIME  : integer := 70; -- This is 560 HS bit times
constant INC_FRINDEX_TIME : integer := 32;

constant HIGH_SPEED  : std_logic_vector(1 downto 0) := "10";
constant FULL_SPEED  : std_logic_vector(1 downto 0) := "01";
constant LOW_SPEED   : std_logic_vector(1 downto 0) := "00";

signal frame_counter : integer range 0 to MAX_FRAME_COUNT-1;
signal fladj         : integer range 0 to 63;
signal uframe_count  : integer range 0 to 7;
signal usb_inc_frindex_toggle_int : std_logic;

begin

  usb_uframe_count <= std_logic_vector(to_unsigned(uframe_count,3));

  usb_inc_frindex_toggle <= usb_inc_frindex_toggle_int;

  proc_sync_usb : process (usb_clk, usb_rst_n)
  begin
    if usb_rst_n = '0' then
      frame_counter              <= 0;
      fladj                      <= 32;
      usb_inc_frindex_toggle_int <= '0';
      uframe_count               <= 0;
    elsif usb_clk'event and usb_clk = '1' then
      if usbreg_fladj_change_sync = '1' then
        fladj <= to_integer(unsigned(usbreg_fladj_sync));
      end if;    
      
      if usbreg_run_sync = '1' then
        if frame_counter = INC_FRINDEX_TIME then
	  usb_inc_frindex_toggle_int <= not(usb_inc_frindex_toggle_int);
	end if;
        if frame_counter = 0 then
	  frame_counter <= MAX_FRAME_COUNT_MIN_FLADJ + fladj*2;
	else
	  frame_counter <= frame_counter - 1;
	end if;

        if pie_devicespeed = HIGH_SPEED then
          uframe_count <= 0;
        elsif frame_counter = 0 then
          if uframe_count = 0 then
	    uframe_count <= 7;
	  else
	    uframe_count <= uframe_count - 1;
	  end if;
        end if;
      else
        frame_counter <= 0;
	uframe_count  <= 0;
      end if;
      
      -- reset flipflops on a software reset
      if usbreg_reset_sync = '1' or usbreg_light_reset_sync = '1' then
        frame_counter              <= 0;
        fladj                      <= 32;
        usb_inc_frindex_toggle_int <= '0';
        uframe_count               <= 0;
      end if;
    end if;
  end process proc_sync_usb;

  usb_send_sof   <= '1' when frame_counter   = 0   and
                             uframe_count    = 0   and
                             usbreg_run_sync = '1' 
			else '0';
			
  usb_endofframe <= '1' when frame_counter   = ENDOFFRAME_TIME and
                             uframe_count    = 0               and
                             usbreg_run_sync = '1' 
			else '0';
			
  usb_decrement_bytes <= to_unsigned(frame_counter,13)(3); -- every edge 8 bytes are decremented
end RTL; --usb_host_sof_timer
