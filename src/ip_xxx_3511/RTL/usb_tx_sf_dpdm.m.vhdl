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
--           $RCSfile: usb_tx_sf_dpdm.m.vhdl.rca $
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
--   $Log: usb_tx_sf_dpdm.m.vhdl.rca $
--   
--    Revision: 1.3 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.1 Fri May 21 08:55:00 2010 aes
--    First check in.
--   
--    Revision: 1.2 Mon Apr 19 14:29:27 2010 bve
--    *** empty comment string ***
--   
--    Revision: 1.1 Thu Apr  1 09:49:54 2010 bve
--    Initial version
--   
--    Revision: 1.2 Mon Sep 29 08:50:49 2008 smh
--    Step1 Endpoint configurability: removed usb_setup_subcmp_pkg
--   
--    Revision: 1.1 Mon Sep 22 11:52:58 2008 smh
--    initial revision : from release_emirplus_v1.9be_070306
--   
--   
--   
--------------------------------------------------------------------------------
  
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY rtl;
USE rtl.usb_general_subcmp_pkg.all;
USE rtl.usb_subcmp_pkg.all;
USE rtl.usb_configuration_subcmp_pkg.all;

entity usb_tx_sf_dpdm is
  port  (

	  SIE_TxLogValue: in T_UsbLog_enum;

	  UP_DP:          out one_bit;
	  UP_DM:          out one_bit;
	  UP_FSE0:        out one_bit

	);
end usb_tx_sf_dpdm;

architecture RTL of usb_tx_sf_dpdm is
begin

UP_DP <= conv_active_high(
  (SIE_TxLogValue = USB_LOG_J) or 
  (SIE_TxLogValue = USB_LOG_SE1_OR_Z));
UP_DM <= conv_active_high(
  (SIE_TxLogValue = USB_LOG_K) or 
  (SIE_TxLogValue = USB_LOG_SE1_OR_Z));
UP_FSE0 <= conv_active_high(
  (SIE_TxLogValue = USB_LOG_SE0));

end RTL;
