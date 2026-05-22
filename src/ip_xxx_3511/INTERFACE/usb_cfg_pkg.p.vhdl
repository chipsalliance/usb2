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
--               File: usb_cfg_pkg.p.vhdl
--
--             Author: Bart Vertenten
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
--   $Log: usb_cfg_pkg.p.vhdl.rca $
--   
--    Revision: 1.3 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.4 Wed Feb 16 11:33:22 2011 beq03099
--    Modified minor version to 0x01
--   
--    Revision: 1.3 Mon Jul 26 09:19:45 2010 beq03099
--    Modified constants to be equal to settings for first MCO product with this IP
--   
--    Revision: 1.2 Thu Jul 22 17:46:11 2010 beq03099
--    added a new constant C_DALB
--   
--    Revision: 1.1 Fri May 21 08:54:59 2010 aes
--    First check in.
--   
--    Revision: 1.2 Fri Apr 16 11:59:33 2010 bve
--    added logic for an internal PLL and RC circuit
--   
--    Revision: 1.1 Mon Oct  6 12:28:02 2008 smh
--    Step1 Endpoint configurability : new unique endpoint configuration
--   
--   
--   
--------------------------------------------------------------------------------
      
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library rtl;
use rtl.usb_general_subcmp_pkg.all;


package usb_cfg_pkg is
  -------------------------------------------------------
  -------     IP_3511 configurable parameters     -------
  -------------------------------------------------------
  constant C_NBPHYSEP: integer := 14; --16

  constant C_EPUB: integer := 32; --16; 
  constant C_DAUB: integer := 32; --Requirement : C_DAUB > C_DALB
  constant C_DALB: integer := 22; --maximum allowed value is 22
                                  --minimum allowed value is 7

  constant C_EPFIFO_PAGE  : std_logic_vector(31 downto 0) := X"00080000";
  constant C_DATAFIFO_PAGE: std_logic_vector(31 downto 0) := X"00080000";

  constant C_SINGLE_BUFFER_SUPPORTED: boolean := TRUE;
  constant C_DOUBLE_BUFFER_SUPPORTED: boolean := TRUE;

  constant C_TOGGLE_REG_READABLE: boolean := TRUE;

  constant C_PLL_ENABLE:          boolean := TRUE;
                                -- set to TRUE if the design has an embedded PLL
                                -- set to FALSE if there is only a 48MHz external clock
  constant C_PLL_DIVIDER:         std_logic_vector(6 downto 0) := "0010100";
                                -- integer value that indicates the M value of the PLL
                                -- This must be 480MHz/(2xInputclock frequency)
                                -- E.g. 480 / (2 x 12) = 20

  constant C_MINOR_REV: std_logic_vector(7 downto 0) := X"01";
  constant C_MAJOR_REV: std_logic_vector(7 downto 0) := X"01";

end usb_cfg_pkg;


package body usb_cfg_pkg is
  
end usb_cfg_pkg;
