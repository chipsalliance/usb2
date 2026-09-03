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

package usb_fs_emb_dev_cfg_pkg is

  constant C_bDeviceClass    : std_logic_vector( 7 downto 0) := X"00";
  constant C_bDeviceSubClass : std_logic_vector( 7 downto 0) := X"00";
  constant C_bDeviceProtocol : std_logic_vector( 7 downto 0) := X"00";

  -------------------------------------------------------
  ------- Standard Descriptors for embedded device ------
  -------------------------------------------------------
  constant C_FS_EMB_DEV_DEV_DESCR_bLength	       : std_logic_vector( 7 downto 0) := X"12";   --18 bytes
  constant C_FS_EMB_DEV_DEV_DESCR_bDescriptorType      : std_logic_vector( 7 downto 0) := X"01";
  constant C_FS_EMB_DEV_DEV_DESCR_bcdUSB               : std_logic_vector(15 downto 0) := X"0200";
  constant C_FS_EMB_DEV_DEV_DESCR_bDeviceClass         : std_logic_vector( 7 downto 0) := C_bDeviceClass; 
  constant C_FS_EMB_DEV_DEV_DESCR_bDeviceSubClass      : std_logic_vector( 7 downto 0) := C_bDeviceSubClass;   
  constant C_FS_EMB_DEV_DEV_DESCR_bDeviceProtocol      : std_logic_vector( 7 downto 0) := C_bDeviceProtocol;
  constant C_FS_EMB_DEV_DEV_DESCR_bMaxPacketSize       : std_logic_vector( 7 downto 0) := X"40";   --64 bytes
  constant C_FS_EMB_DEV_DEV_DESCR_idVendor             : std_logic_vector(15 downto 0) := X"0403"; --FTDI VID --X"1FC9"; --NXP vendor ID
  constant C_FS_EMB_DEV_DEV_DESCR_idProduct            : std_logic_vector(15 downto 0) := X"CFF8"; --FTDI PID - FT2232   --X"BE01"; --Ask Bruno !!!
  constant C_FS_EMB_DEV_DEV_DESCR_bcdDevice            : std_logic_vector(15 downto 0) := X"0500";
  constant C_FS_EMB_DEV_DEV_DESCR_iManufacturer        : std_logic_vector( 7 downto 0) := X"01";   --No string descr.
  constant C_FS_EMB_DEV_DEV_DESCR_iProduct             : std_logic_vector( 7 downto 0) := X"02";   --No string descr.
  constant C_FS_EMB_DEV_DEV_DESCR_iSerialNumber        : std_logic_vector( 7 downto 0) := X"03";   --No string descr.
  constant C_FS_EMB_DEV_DEV_DESCR_bNumConfigurations   : std_logic_vector( 7 downto 0) := X"01";   --1 configuration

  constant C_FS_EMB_DEV_EP1_DESCR_bLength              : std_logic_vector( 7 downto 0) := X"07";
  constant C_FS_EMB_DEV_EP1_DESCR_bDescriptorType      : std_logic_vector( 7 downto 0) := X"05";
  constant C_FS_EMB_DEV_EP1_DESCR_bEndpointAddress     : std_logic_vector( 7 downto 0) := X"81";
  constant C_FS_EMB_DEV_EP1_DESCR_bmAttributes         : std_logic_vector( 7 downto 0) := X"02";
  constant C_FS_EMB_DEV_EP1_DESCR_wMaxPacketSize       : std_logic_vector(15 downto 0) := X"0040";
  constant C_FS_EMB_DEV_EP1_DESCR_bInterval            : std_logic_vector( 7 downto 0) := X"00";

  constant C_FS_EMB_DEV_EP2_DESCR_bLength	       : std_logic_vector( 7 downto 0) := X"07";
  constant C_FS_EMB_DEV_EP2_DESCR_bDescriptorType      : std_logic_vector( 7 downto 0) := X"05";
  constant C_FS_EMB_DEV_EP2_DESCR_bEndpointAddress     : std_logic_vector( 7 downto 0) := X"01";
  constant C_FS_EMB_DEV_EP2_DESCR_bmAttributes         : std_logic_vector( 7 downto 0) := X"02";
  constant C_FS_EMB_DEV_EP2_DESCR_wMaxPacketSize       : std_logic_vector(15 downto 0) := X"0040";
  constant C_FS_EMB_DEV_EP2_DESCR_bInterval	       : std_logic_vector( 7 downto 0) := X"00";

  constant C_FS_EMB_DEV_EP3_DESCR_bLength	       : std_logic_vector( 7 downto 0) := X"07";
  constant C_FS_EMB_DEV_EP3_DESCR_bDescriptorType      : std_logic_vector( 7 downto 0) := X"05";
  constant C_FS_EMB_DEV_EP3_DESCR_bEndpointAddress     : std_logic_vector( 7 downto 0) := X"82";
  constant C_FS_EMB_DEV_EP3_DESCR_bmAttributes         : std_logic_vector( 7 downto 0) := X"02";
  constant C_FS_EMB_DEV_EP3_DESCR_wMaxPacketSize       : std_logic_vector(15 downto 0) := X"0040";
  constant C_FS_EMB_DEV_EP3_DESCR_bInterval	       : std_logic_vector( 7 downto 0) := X"00";

  constant C_FS_EMB_DEV_EP4_DESCR_bLength	       : std_logic_vector( 7 downto 0) := X"07";
  constant C_FS_EMB_DEV_EP4_DESCR_bDescriptorType      : std_logic_vector( 7 downto 0) := X"05";
  constant C_FS_EMB_DEV_EP4_DESCR_bEndpointAddress     : std_logic_vector( 7 downto 0) := X"02";
  constant C_FS_EMB_DEV_EP4_DESCR_bmAttributes         : std_logic_vector( 7 downto 0) := X"02";
  constant C_FS_EMB_DEV_EP4_DESCR_wMaxPacketSize       : std_logic_vector(15 downto 0) := X"0040";
  constant C_FS_EMB_DEV_EP4_DESCR_bInterval	       : std_logic_vector( 7 downto 0) := X"00";

  constant C_FS_EMB_DEV_INT_DESCR_bLength	       : std_logic_vector( 7 downto 0) := X"09"; --9 bytes
  constant C_FS_EMB_DEV_INT_DESCR_bDescriptorType      : std_logic_vector( 7 downto 0) := X"04";
  constant C_FS_EMB_DEV_INT_DESCR_bInterfaceNumber     : std_logic_vector( 7 downto 0) := X"00";
  constant C_FS_EMB_DEV_INT_DESCR_bAlternateSetting    : std_logic_vector( 7 downto 0) := X"00";
  constant C_FS_EMB_DEV_INT_DESCR_bNumEndpoints        : std_logic_vector( 7 downto 0) := X"02"; --2 endpoints
  constant C_FS_EMB_DEV_INT_DESCR_bInterfaceClass      : std_logic_vector( 7 downto 0) := X"FF";
  constant C_FS_EMB_DEV_INT_DESCR_bInterfaceSubClass   : std_logic_vector( 7 downto 0) := X"FF";
  constant C_FS_EMB_DEV_INT_DESCR_bInterfaceProtocol   : std_logic_vector( 7 downto 0) := X"FF";
  constant C_FS_EMB_DEV_INT_DESCR_iInterface           : std_logic_vector( 7 downto 0) := X"02";

  constant C_FS_EMB_DEV_INT1_DESCR_bLength	       : std_logic_vector( 7 downto 0) := X"09"; --9 bytes
  constant C_FS_EMB_DEV_INT1_DESCR_bDescriptorType     : std_logic_vector( 7 downto 0) := X"04";
  constant C_FS_EMB_DEV_INT1_DESCR_bInterfaceNumber    : std_logic_vector( 7 downto 0) := X"01";
  constant C_FS_EMB_DEV_INT1_DESCR_bAlternateSetting   : std_logic_vector( 7 downto 0) := X"00";
  constant C_FS_EMB_DEV_INT1_DESCR_bNumEndpoints       : std_logic_vector( 7 downto 0) := X"02"; --2 endpoints
  constant C_FS_EMB_DEV_INT1_DESCR_bInterfaceClass     : std_logic_vector( 7 downto 0) := X"FF";
  constant C_FS_EMB_DEV_INT1_DESCR_bInterfaceSubClass  : std_logic_vector( 7 downto 0) := X"FF";
  constant C_FS_EMB_DEV_INT1_DESCR_bInterfaceProtocol  : std_logic_vector( 7 downto 0) := X"FF";
  constant C_FS_EMB_DEV_INT1_DESCR_iInterface          : std_logic_vector( 7 downto 0) := X"02";

  constant C_FS_EMB_DEV_CONF_DESCR_bLength	       : std_logic_vector( 7 downto 0) := X"09"; --9 bytes
  constant C_FS_EMB_DEV_CONF_DESCR_bDescriptorType     : std_logic_vector( 7 downto 0) := X"02";
  constant C_FS_EMB_DEV_CONF_DESCR_wTotalLength        : std_logic_vector(15 downto 0) := 
    std_logic_vector(to_unsigned(
                                 to_integer(unsigned(C_FS_EMB_DEV_CONF_DESCR_bLength)) +
                                 to_integer(unsigned(C_FS_EMB_DEV_INT_DESCR_bLength))  +
                                 to_integer(unsigned(C_FS_EMB_DEV_INT1_DESCR_bLength)) +
				 to_integer(unsigned(C_FS_EMB_DEV_EP1_DESCR_bLength))  +
				 to_integer(unsigned(C_FS_EMB_DEV_EP2_DESCR_bLength))  +
				 to_integer(unsigned(C_FS_EMB_DEV_EP3_DESCR_bLength))  +
				 to_integer(unsigned(C_FS_EMB_DEV_EP4_DESCR_bLength))  ,16));
  constant C_FS_EMB_DEV_CONF_DESCR_bNumInterfaces      : std_logic_vector( 7 downto 0) := X"02";
  constant C_FS_EMB_DEV_CONF_DESCR_bConfigurationValue : std_logic_vector( 7 downto 0) := X"01";
  constant C_FS_EMB_DEV_CONF_DESCR_iConfiguration      : std_logic_vector( 7 downto 0) := X"00"; --No string descr.
  constant C_FS_EMB_DEV_CONF_DESCR_bmAttributes        : std_logic_vector( 7 downto 0) :=
                                       '1'                                      &   -- Reserved - must be set to '1'
				       '0'                                      &   -- Self-powered = '1' / Bus-Powered  = '0'
				       '0'                                      &   -- Remote wakeup
				       "00000"                                  ;
  constant C_FS_EMB_DEV_CONF_DESCR_bMaxPower           : std_logic_vector( 7 downto 0) := X"32"; --2mA - Give almost everything to the other device. Can not be zero because USBCV fails in this case

  constant C_FS_EMB_DEV_DEVCAP_DESCR_bLength	       : std_logic_vector( 7 downto 0) := X"07";
  constant C_FS_EMB_DEV_DEVCAP_DESCR_bDescriptorType   : std_logic_vector( 7 downto 0) := X"10";
  constant C_FS_EMB_DEV_DEVCAP_DESCR_bDevCapabilityType: std_logic_vector( 7 downto 0) := X"02";
  constant C_FS_EMB_DEV_DEVCAP_DESCR_bmAttributes      : std_logic_vector(31 downto 0) := X"00000000"; -- LPM not supported

  constant C_FS_EMB_DEV_BOS_DESCR_bLength	       : std_logic_vector( 7 downto 0) := X"05";
  constant C_FS_EMB_DEV_BOS_DESCR_bDescriptorType      : std_logic_vector( 7 downto 0) := X"0F";
  constant C_FS_EMB_DEV_BOS_DESCR_wTotalLength         : std_logic_vector(15 downto 0) :=
    std_logic_vector(to_unsigned(
                                 to_integer(unsigned(C_FS_EMB_DEV_BOS_DESCR_bLength))    +
                                 to_integer(unsigned(C_FS_EMB_DEV_DEVCAP_DESCR_bLength)) ,16));
  constant C_FS_EMB_DEV_BOS_DESCR_bNumDeviceCaps       : std_logic_vector( 7 downto 0) := X"01";

--++++++++++++++++++++++++++++++
-- Concatenation
--++++++++++++++++++++++++++++++  
  constant C_FS_EMB_DEV_DEV_DESCR  : std_logic_vector(to_integer(unsigned(C_FS_EMB_DEV_DEV_DESCR_bLength))*8-1 downto 0) :=
                                       C_FS_EMB_DEV_DEV_DESCR_bNumConfigurations    &
                                       C_FS_EMB_DEV_DEV_DESCR_iSerialNumber         &
                                       C_FS_EMB_DEV_DEV_DESCR_iProduct              &
                                       C_FS_EMB_DEV_DEV_DESCR_iManufacturer         &
                                       C_FS_EMB_DEV_DEV_DESCR_bcdDevice             &
                                       C_FS_EMB_DEV_DEV_DESCR_idProduct             &
                                       C_FS_EMB_DEV_DEV_DESCR_idVendor              &
                                       C_FS_EMB_DEV_DEV_DESCR_bMaxPacketSize	    &
                                       C_FS_EMB_DEV_DEV_DESCR_bDeviceProtocol       &
                                       C_FS_EMB_DEV_DEV_DESCR_bDeviceSubClass       &
                                       C_FS_EMB_DEV_DEV_DESCR_bDeviceClass          &
                                       C_FS_EMB_DEV_DEV_DESCR_bcdUSB                &
                                       C_FS_EMB_DEV_DEV_DESCR_bDescriptorType       &
                                       C_FS_EMB_DEV_DEV_DESCR_bLength               ;

  constant C_FS_EMB_DEV_CONF_DESCR : std_logic_vector(to_integer(unsigned(C_FS_EMB_DEV_CONF_DESCR_bLength))*8-1 downto 0) :=
                                       C_FS_EMB_DEV_CONF_DESCR_bMaxPower            &
				       C_FS_EMB_DEV_CONF_DESCR_bmAttributes         &
				       C_FS_EMB_DEV_CONF_DESCR_iConfiguration       &
				       C_FS_EMB_DEV_CONF_DESCR_bConfigurationValue  &
				       C_FS_EMB_DEV_CONF_DESCR_bNumInterfaces       &
				       C_FS_EMB_DEV_CONF_DESCR_wTotalLength         &
				       C_FS_EMB_DEV_CONF_DESCR_bDescriptorType      &
				       C_FS_EMB_DEV_CONF_DESCR_bLength              ;

  constant C_FS_EMB_DEV_INT_DESCR  : std_logic_vector(to_integer(unsigned(C_FS_EMB_DEV_INT_DESCR_bLength))*8-1 downto 0) :=
                                       C_FS_EMB_DEV_INT_DESCR_iInterface	        &
                                       C_FS_EMB_DEV_INT_DESCR_bInterfaceProtocol	&
                                       C_FS_EMB_DEV_INT_DESCR_bInterfaceSubClass	&
                                       C_FS_EMB_DEV_INT_DESCR_bInterfaceClass   	&
                                       C_FS_EMB_DEV_INT_DESCR_bNumEndpoints     	&
                                       C_FS_EMB_DEV_INT_DESCR_bAlternateSetting 	&
                                       C_FS_EMB_DEV_INT_DESCR_bInterfaceNumber  	&
                                       C_FS_EMB_DEV_INT_DESCR_bDescriptorType   	&
                                       C_FS_EMB_DEV_INT_DESCR_bLength	        ;
  
  constant C_FS_EMB_DEV_INT1_DESCR  : std_logic_vector(to_integer(unsigned(C_FS_EMB_DEV_INT1_DESCR_bLength))*8-1 downto 0) :=
                                       C_FS_EMB_DEV_INT1_DESCR_iInterface	        &
                                       C_FS_EMB_DEV_INT1_DESCR_bInterfaceProtocol	&
                                       C_FS_EMB_DEV_INT1_DESCR_bInterfaceSubClass	&
                                       C_FS_EMB_DEV_INT1_DESCR_bInterfaceClass   	&
                                       C_FS_EMB_DEV_INT1_DESCR_bNumEndpoints     	&
                                       C_FS_EMB_DEV_INT1_DESCR_bAlternateSetting 	&
                                       C_FS_EMB_DEV_INT1_DESCR_bInterfaceNumber  	&
                                       C_FS_EMB_DEV_INT1_DESCR_bDescriptorType   	&
                                       C_FS_EMB_DEV_INT1_DESCR_bLength	        ;
  
  constant C_FS_EMB_DEV_EP1_DESCR  : std_logic_vector(to_integer(unsigned(C_FS_EMB_DEV_EP1_DESCR_bLength))*8-1 downto 0) :=
                                       C_FS_EMB_DEV_EP1_DESCR_bInterval	   	&
                                       C_FS_EMB_DEV_EP1_DESCR_wMaxPacketSize  	&
                                       C_FS_EMB_DEV_EP1_DESCR_bmAttributes    	&
                                       C_FS_EMB_DEV_EP1_DESCR_bEndpointAddress	&
                                       C_FS_EMB_DEV_EP1_DESCR_bDescriptorType 	&
                                       C_FS_EMB_DEV_EP1_DESCR_bLength	        ;
				       
  constant C_FS_EMB_DEV_EP2_DESCR  : std_logic_vector(to_integer(unsigned(C_FS_EMB_DEV_EP2_DESCR_bLength))*8-1 downto 0) :=
                                       C_FS_EMB_DEV_EP2_DESCR_bInterval 	&
                                       C_FS_EMB_DEV_EP2_DESCR_wMaxPacketSize	&
                                       C_FS_EMB_DEV_EP2_DESCR_bmAttributes	&
                                       C_FS_EMB_DEV_EP2_DESCR_bEndpointAddress  &
                                       C_FS_EMB_DEV_EP2_DESCR_bDescriptorType	&
                                       C_FS_EMB_DEV_EP2_DESCR_bLength		;
				       
  constant C_FS_EMB_DEV_EP3_DESCR  : std_logic_vector(to_integer(unsigned(C_FS_EMB_DEV_EP3_DESCR_bLength))*8-1 downto 0) :=
                                       C_FS_EMB_DEV_EP3_DESCR_bInterval 	&
                                       C_FS_EMB_DEV_EP3_DESCR_wMaxPacketSize	&
                                       C_FS_EMB_DEV_EP3_DESCR_bmAttributes	&
                                       C_FS_EMB_DEV_EP3_DESCR_bEndpointAddress  &
                                       C_FS_EMB_DEV_EP3_DESCR_bDescriptorType	&
                                       C_FS_EMB_DEV_EP3_DESCR_bLength		;
				       
  constant C_FS_EMB_DEV_EP4_DESCR  : std_logic_vector(to_integer(unsigned(C_FS_EMB_DEV_EP4_DESCR_bLength))*8-1 downto 0) :=
                                       C_FS_EMB_DEV_EP4_DESCR_bInterval 	&
                                       C_FS_EMB_DEV_EP4_DESCR_wMaxPacketSize	&
                                       C_FS_EMB_DEV_EP4_DESCR_bmAttributes	&
                                       C_FS_EMB_DEV_EP4_DESCR_bEndpointAddress  &
                                       C_FS_EMB_DEV_EP4_DESCR_bDescriptorType	&
                                       C_FS_EMB_DEV_EP4_DESCR_bLength		;
				       
  constant C_FS_EMB_DEV_CONF_DESCR_FULL : std_logic_vector(to_integer(unsigned(C_FS_EMB_DEV_CONF_DESCR_wTotalLength))*8-1 downto 0) :=
				       C_FS_EMB_DEV_EP4_DESCR                       &
				       C_FS_EMB_DEV_EP3_DESCR                       &
				       C_FS_EMB_DEV_INT1_DESCR                      &
				       C_FS_EMB_DEV_EP2_DESCR                       &
				       C_FS_EMB_DEV_EP1_DESCR                       &
				       C_FS_EMB_DEV_INT_DESCR                       &
                                       C_FS_EMB_DEV_CONF_DESCR                      ;

  constant C_FS_EMB_DEV_BOS_DESCR_FULL  : std_logic_vector(to_integer(unsigned(C_FS_EMB_DEV_BOS_DESCR_wTotalLength))*8-1 downto 0) :=				       
                                       C_FS_EMB_DEV_DEVCAP_DESCR_bmAttributes	    &
				       C_FS_EMB_DEV_DEVCAP_DESCR_bDevCapabilityType &
				       C_FS_EMB_DEV_DEVCAP_DESCR_bDescriptorType    &
				       C_FS_EMB_DEV_DEVCAP_DESCR_bLength	    &
                                       C_FS_EMB_DEV_BOS_DESCR_bNumDeviceCaps	    &
				       C_FS_EMB_DEV_BOS_DESCR_wTotalLength	    &
				       C_FS_EMB_DEV_BOS_DESCR_bDescriptorType	    &
				       C_FS_EMB_DEV_BOS_DESCR_bLength		    ;

  constant C_FS_EMB_DEV_DEV_STRING0_DESCR : std_logic_vector(4*8-1 downto 0) :=
                                       X"04" &
                                       X"09" &
                                       X"03" &
				       X"04";

  constant C_FS_EMB_DEV_STRING1_DESCR_wTotalLength : std_logic_vector( 7 downto 0) := X"20";
  
  constant C_FS_EMB_DEV_DEV_STRING1_DESCR : std_logic_vector(to_integer(unsigned(C_FS_EMB_DEV_STRING1_DESCR_wTotalLength))*8-1 downto 0) :=
                                       X"00" &
                                       X"79" &
                                       X"00" &
                                       X"65" &
                                       X"00" &
                                       X"6B" &
                                       X"00" &
                                       X"47" &
                                       X"00" &
                                       X"41" &
                                       X"00" &
                                       X"54" &
                                       X"00" &
                                       X"4A" &
                                       X"00" &
                                       X"20" &
                                       X"00" &
                                       X"63" &
                                       X"00" &
                                       X"65" &
                                       X"00" &
                                       X"74" &
                                       X"00" &
                                       X"6E" &
                                       X"00" &
                                       X"6F" &
                                       X"00" &
                                       X"6D" &
                                       X"00" &
                                       X"41" &
                                       X"03" &
				       C_FS_EMB_DEV_STRING1_DESCR_wTotalLength;

  constant C_FS_EMB_DEV_STRING2_DESCR_wTotalLength : std_logic_vector( 7 downto 0) := X"20";
  
  constant C_FS_EMB_DEV_DEV_STRING2_DESCR : std_logic_vector(to_integer(unsigned(C_FS_EMB_DEV_STRING2_DESCR_wTotalLength))*8-1 downto 0) :=
                                       X"00" &
                                       X"79" &
                                       X"00" &
                                       X"65" &
                                       X"00" &
                                       X"6B" &
                                       X"00" &
                                       X"47" &
                                       X"00" &
                                       X"41" &
                                       X"00" &
                                       X"54" &
                                       X"00" &
                                       X"4A" &
                                       X"00" &
                                       X"20" &
                                       X"00" &
                                       X"63" &
                                       X"00" &
                                       X"65" &
                                       X"00" &
                                       X"74" &
                                       X"00" &
                                       X"6E" &
                                       X"00" &
                                       X"6F" &
                                       X"00" &
                                       X"6D" &
                                       X"00" &
                                       X"41" &
                                       X"03" &
				       C_FS_EMB_DEV_STRING2_DESCR_wTotalLength;

  constant C_FS_EMB_DEV_STRING3_DESCR_wTotalLength : std_logic_vector( 7 downto 0) := X"12";
  
  constant C_FS_EMB_DEV_DEV_STRING3_DESCR : std_logic_vector(to_integer(unsigned(C_FS_EMB_DEV_STRING3_DESCR_wTotalLength))*8-1 downto 0) :=
                                       X"00" &
                                       X"38" &
                                       X"00" &
                                       X"5A" &
                                       X"00" &
                                       X"44" &
                                       X"00" &
                                       X"31" &
                                       X"00" &
                                       X"36" &
                                       X"00" &
                                       X"50" &
                                       X"00" &
                                       X"32" &
                                       X"00" &
                                       X"33" &
                                       X"03" &
				       C_FS_EMB_DEV_STRING3_DESCR_wTotalLength;

  constant C_FS_EMB_DEV_VENDOR_SPEC_DESCR : std_logic_vector (128*16-1 downto 0) :=
                                       X"6D86" & --wIndex 0x7F
                                       X"0000" & --wIndex 0x7E
                                       X"0000" & --wIndex 0x7D
                                       X"0000" & --wIndex 0x7C
                                       X"0000" & --wIndex 0x7B
                                       X"0000" & --wIndex 0x7A
                                       X"0000" & --wIndex 0x79
                                       X"0000" & --wIndex 0x78
                                       X"0000" & --wIndex 0x77
                                       X"0000" & --wIndex 0x76
                                       X"0000" & --wIndex 0x75
                                       X"0000" & --wIndex 0x74
                                       X"0000" & --wIndex 0x73
                                       X"0000" & --wIndex 0x72
                                       X"0000" & --wIndex 0x71
                                       X"0000" & --wIndex 0x70
                                       X"0000" & --wIndex 0x6F
                                       X"0000" & --wIndex 0x6E
                                       X"0001" & --wIndex 0x6D
                                       X"0000" & --wIndex 0x6C
                                       X"0038" & --wIndex 0x6B
                                       X"005A" & --wIndex 0x6A
                                       X"0044" & --wIndex 0x69
                                       X"0031" & --wIndex 0x68
                                       X"0036" & --wIndex 0x67
                                       X"0050" & --wIndex 0x66
                                       X"0032" & --wIndex 0x65
                                       X"0033" & --wIndex 0x64
                                       X"0312" & --wIndex 0x63
                                       X"0079" & --wIndex 0x62
                                       X"0065" & --wIndex 0x61
                                       X"006B" & --wIndex 0x60
                                       X"0047" & --wIndex 0x5F
                                       X"0041" & --wIndex 0x5E
                                       X"0054" & --wIndex 0x5D
                                       X"004A" & --wIndex 0x5C
                                       X"0020" & --wIndex 0x5B
                                       X"0063" & --wIndex 0x5A
                                       X"0065" & --wIndex 0x59
                                       X"0074" & --wIndex 0x58
                                       X"006E" & --wIndex 0x57
                                       X"006F" & --wIndex 0x56
                                       X"006D" & --wIndex 0x55
                                       X"0041" & --wIndex 0x54
                                       X"0320" & --wIndex 0x53
                                       X"0063" & --wIndex 0x52
                                       X"0065" & --wIndex 0x51
                                       X"0074" & --wIndex 0x50
                                       X"006E" & --wIndex 0x4F
                                       X"006F" & --wIndex 0x4E
                                       X"006D" & --wIndex 0x4D
                                       X"0041" & --wIndex 0x4C
                                       X"0310" & --wIndex 0x4B
                                       X"0000" & --wIndex 0x4A
                                       X"0000" & --wIndex 0x49
                                       X"0000" & --wIndex 0x48
                                       X"0000" & --wIndex 0x47
                                       X"0000" & --wIndex 0x46
                                       X"0000" & --wIndex 0x45
                                       X"0000" & --wIndex 0x44
                                       X"0000" & --wIndex 0x43
                                       X"0000" & --wIndex 0x42
                                       X"0000" & --wIndex 0x41
                                       X"0000" & --wIndex 0x40
                                       X"0000" & --wIndex 0x3F
                                       X"0000" & --wIndex 0x3E
                                       X"0000" & --wIndex 0x3D
                                       X"0000" & --wIndex 0x3C
                                       X"0000" & --wIndex 0x3B
                                       X"0000" & --wIndex 0x3A
                                       X"0000" & --wIndex 0x39
                                       X"0000" & --wIndex 0x38
                                       X"0000" & --wIndex 0x37
                                       X"0000" & --wIndex 0x36
                                       X"0000" & --wIndex 0x35
                                       X"0000" & --wIndex 0x34
                                       X"0000" & --wIndex 0x33
                                       X"0000" & --wIndex 0x32
                                       X"0000" & --wIndex 0x31
                                       X"0000" & --wIndex 0x30
                                       X"0000" & --wIndex 0x2F
                                       X"0000" & --wIndex 0x2E
                                       X"0000" & --wIndex 0x2D
                                       X"0000" & --wIndex 0x2C
                                       X"0000" & --wIndex 0x2B
                                       X"0000" & --wIndex 0x2A
                                       X"0000" & --wIndex 0x29
                                       X"0000" & --wIndex 0x28
                                       X"0000" & --wIndex 0x27
                                       X"0000" & --wIndex 0x26
                                       X"0000" & --wIndex 0x25
                                       X"0000" & --wIndex 0x24
                                       X"0000" & --wIndex 0x23
                                       X"0000" & --wIndex 0x22
                                       X"0000" & --wIndex 0x21
                                       X"0000" & --wIndex 0x20
                                       X"0000" & --wIndex 0x1F
                                       X"0000" & --wIndex 0x1E
                                       X"0000" & --wIndex 0x1D
                                       X"0000" & --wIndex 0x1C
                                       X"0000" & --wIndex 0x1B
                                       X"0000" & --wIndex 0x1A
                                       X"0000" & --wIndex 0x19
                                       X"0000" & --wIndex 0x18
                                       X"0000" & --wIndex 0x17
                                       X"0000" & --wIndex 0x16
                                       X"0000" & --wIndex 0x15
                                       X"0000" & --wIndex 0x14
                                       X"0000" & --wIndex 0x13
                                       X"0000" & --wIndex 0x12
                                       X"0000" & --wIndex 0x11
                                       X"0000" & --wIndex 0x10
                                       X"0000" & --wIndex 0x0F
                                       X"0000" & --wIndex 0x0E
                                       X"0000" & --wIndex 0x0D
                                       X"0000" & --wIndex 0x0C
                                       X"0000" & --wIndex 0x0B
                                       X"0056" & --wIndex 0x0A
                                       X"12C6" & --wIndex 0x09
                                       X"20A6" & --wIndex 0x08
                                       X"1096" & --wIndex 0x07
                                       X"0200" & --wIndex 0x06
                                       X"0008" & --wIndex 0x05
                                       X"3280" & --wIndex 0x04
                                       X"0500" & --wIndex 0x03
                                       X"CFF8" & --wIndex 0x02
                                       X"0403" & --wIndex 0x01
                                       X"1011";  --wIndex 0x00
  

  constant C_EMB_DEV_NBPHYSEP : integer := to_integer(unsigned(C_FS_EMB_DEV_INT_DESCR_bNumEndpoints)) +
                                           to_integer(unsigned(C_FS_EMB_DEV_INT1_DESCR_bNumEndpoints)); -- Fix this !!! It must be according to the right setting.

  -------------------------------------------------------
  -------   Class Descriptors for embedded device  ------
  -------------------------------------------------------

end usb_fs_emb_dev_cfg_pkg;


package body usb_fs_emb_dev_cfg_pkg is
  
end usb_fs_emb_dev_cfg_pkg;
