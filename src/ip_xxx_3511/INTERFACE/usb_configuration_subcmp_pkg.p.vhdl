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
--   COPYRIGHT (c) NXP B.V. 2007
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
--           $RCSfile: usb_configuration_subcmp_pkg.p.vhdl.rca $
--
--             Author: Sonia Mehri
--
--       Organisation: Corporate I&T / IP & Architecture
--
--              $Date: Sun Apr 23 19:20:43 2017 $
--
--            Project: Low gate count USB peripheral IP 
--
--        Description: 
--
--          $Revision: 1.3 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_configuration_subcmp_pkg.p.vhdl.rca $
--   
--    Revision: 1.3 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.2 Thu Feb 24 08:07:48 2011 beq03099
--    removed unused package
--   
--    Revision: 1.1 Thu Apr  1 09:47:55 2010 bve
--    Initial version
--   
--    Revision: 1.2 Mon Sep 29 09:25:44 2008 smh
--    Step1 Endpoint configurability : new unique endpoint configuration,
--    removed unused constants/types ..
--   
--    Revision: 1.1 Mon Sep 22 11:53:07 2008 smh
--    initial revision : from release_emirplus_v1.9be_070306
--   
--   
--   
--------------------------------------------------------------------------------
      
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library rtl;
use rtl.usb_general_subcmp_pkg.all;
use rtl.usb_subcmp_pkg.all;

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
