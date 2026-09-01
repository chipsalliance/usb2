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
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library usb_lib;
use usb_lib.usb_general_subcmp_pkg.all;
use usb_lib.usb_subcmp_pkg.all;
use usb_lib.usb_configuration_subcmp_pkg.all;

entity usb_upstreamled is
  port  (
       --- LED control ---
       Configured_LED:     out one_bit; -- LED output

       --- Device State  ---
       SH_Succes:          in boolean; -- Successful transfer
       SH_Configured:      in boolean; -- Device is configured
       TM_Suspend:         in boolean; -- Device is suspended
       LPM_TM_Suspend:     in boolean; -- Device is suspended

       --- from timers ---
       TM_1kHzPulse:       in one_bit; -- 1 kHz clock pulse
       
       --- system ---
       FsClk:              in one_bit; -- Recovered clock
       Reset_N:            in one_bit -- Reset for Recovered clock
        );
end usb_upstreamled;

architecture RTL of usb_upstreamled is

  constant BLINK_TIME: integer := 256;
  subtype S_BlinkTime is integer range 0 to BLINK_TIME-1;
  signal Blinking: boolean;
  signal BlinkTimer: S_BlinkTime;

begin
  process(FsClk,Reset_N)
  begin
    if (Reset_N = ACTIVE_LOW) then

      BlinkTimer <= 0;
      Blinking <= FALSE;

    elsif FsClk'event and (FsClk = '1') then 

      -- DOC_BEGIN
      -- When a successful transfer occured, the blink timer
      -- is reset at its maximum value. From that moment it starts
      -- counting down every millisecond. The LED blinks as long as the
      -- timer value is higher than half the maximum value.<p>
      -- The timer stops at 0. From that moment on it waits again
      -- for a new successful transfer.<p>

      Blinking <= (BlinkTimer >= BLINK_TIME /2);

      if (BlinkTimer = 0) then
        if SH_Succes then
          BlinkTimer <= BLINK_TIME-1;
        end if;
      else
        if (TM_1kHzPulse = '1') then
          BlinkTimer <= BlinkTimer -1;
        end if;
      end if;
      -- DOC_END

    end if;

  end process;

  -- DOC_BEGIN
  -- There are two modes for the leds. When NoBlinkingLEDs(ConfigArray)
  -- is true, the LEDs wont blink. When NoBlinkingLEDs(ConfigArray) is
  -- false blinking is allowed.<p>
  -- When not configured the LED is default off. When configured,
  -- it is default on.<p>
  -- Blinking is superposed on these states as follows.
  -- The LEDs blink when Blinking = TRUE and the configuration
  -- allows blinking. During global suspend, the LED is always off
  -- to save power.<p>

  Configured_LED <= conv_active_high(
    SH_Configured and not (TM_Suspend or LPM_TM_Suspend)) when NoBlinkingLEDs else
                    conv_active_high(
                      ((not SH_Configured and Blinking) or
                       (SH_Configured and not Blinking)) and
                      (not (TM_Suspend or LPM_TM_Suspend)));
  -- DOC_END

end RTL;

