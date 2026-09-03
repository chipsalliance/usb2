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

package usb_configuration_subcmp_pkg is


  -------------------------------------------------------
  -------          Constant Declarations          -------
  -------------------------------------------------------

  -- Maximum value of clock divider
  constant MAX_CLK_DIV: integer := 1;

  -- Number of register configuration bits
  constant MAX_DEVICE_SPEED: T_UsbSpeed_enum := USB_FULL_SPEED;

  -- Maximum data packet size
  constant MAX_BUFFER_SIZE: integer := 1023; -- maximum packet size for full-speed devices

  -- Maximum data packet size +2
  constant MAX_OVERFLOW_SIZE: integer := MAX_BUFFER_SIZE+2;-- changed by arkrish 00/04/11: ISO is now 514 bytes

  -- Device supports iso data
  constant SUPPORT_ISO: boolean := TRUE;

  -- Debounce time for VBUS
  constant VBUS_DEBOUNCE_TIME: integer := 3;
     
  -------------------------------------------------------
  -------------------------------------------------------
  -------            Feature Definitions          -------
  -------------------------------------------------------

 function NoBlinkingLEDs
	       return boolean;

end usb_configuration_subcmp_pkg;


package body usb_configuration_subcmp_pkg is

  -- Functions for DEVICE_HANDLER (ID = 1) --

 function NoBlinkingLEDs
	       return boolean is
 begin
   return TRUE;
 end NoBlinkingLEDs;

end usb_configuration_subcmp_pkg;
