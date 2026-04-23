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
--               File: usb_fs_hub_pkg.p.vhdl
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
--   $Log: usb_fs_hub_pkg.p.vhdl.rca $
--   
--    Revision: 1.3 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.2 Thu Aug  5 08:05:59 2010 beq03099
--    Added BOS descriptor
--   
--    Revision: 1.1 Wed Jul 28 13:47:49 2010 beq03099
--    Initial version for configuration files of ip_xxx_3511_compound
--   
--------------------------------------------------------------------------------
      
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library rtl;
use rtl.usb_general_subcmp_pkg.all;


package usb_fs_hub_cfg_pkg is

  -------------------------------------------------------
  ------- Standard Descriptors for full-speed hub  ------
  -------------------------------------------------------
  constant C_FS_HUB_DEV_DESCR_bLength	           : std_logic_vector( 7 downto 0) := X"12";   --18 bytes
  constant C_FS_HUB_DEV_DESCR_bDescriptorType      : std_logic_vector( 7 downto 0) := X"01";
  constant C_FS_HUB_DEV_DESCR_bcdUSB               : std_logic_vector(15 downto 0) := X"0201";
  constant C_FS_HUB_DEV_DESCR_bDeviceClass         : std_logic_vector( 7 downto 0) := X"09";   -- HUB_CLASSCODE
  constant C_FS_HUB_DEV_DESCR_bDeviceSubClass      : std_logic_vector( 7 downto 0) := X"00";   
  constant C_FS_HUB_DEV_DESCR_bDeviceProtocol      : std_logic_vector( 7 downto 0) := X"00";
  constant C_FS_HUB_DEV_DESCR_bMaxPacketSize       : std_logic_vector( 7 downto 0) := X"40";   --64 bytes
  constant C_FS_HUB_DEV_DESCR_idVendor             : std_logic_vector(15 downto 0) := X"1FC9"; --NXP vendor ID
  constant C_FS_HUB_DEV_DESCR_idProduct            : std_logic_vector(15 downto 0) := X"BE00"; --Ask Bruno !!!
  constant C_FS_HUB_DEV_DESCR_bcdDevice            : std_logic_vector(15 downto 0) := X"0100";
  constant C_FS_HUB_DEV_DESCR_iManufacturer        : std_logic_vector( 7 downto 0) := X"00";   --No string descr.
  constant C_FS_HUB_DEV_DESCR_iProduct             : std_logic_vector( 7 downto 0) := X"00";   --No string descr.
  constant C_FS_HUB_DEV_DESCR_iSerialNumber        : std_logic_vector( 7 downto 0) := X"00";   --No string descr.
  constant C_FS_HUB_DEV_DESCR_bNumConfigurations   : std_logic_vector( 7 downto 0) := X"01";   --1 configuration

  constant C_FS_HUB_EP1_DESCR_bLength              : std_logic_vector( 7 downto 0) := X"07";
  constant C_FS_HUB_EP1_DESCR_bDescriptorType      : std_logic_vector( 7 downto 0) := X"05";
  constant C_FS_HUB_EP1_DESCR_bEndpointAddress     : std_logic_vector( 7 downto 0) := X"81";
  constant C_FS_HUB_EP1_DESCR_bmAttributes         : std_logic_vector( 7 downto 0) := X"03";
  constant C_FS_HUB_EP1_DESCR_wMaxPacketSize       : std_logic_vector(15 downto 0) := X"0001";
  constant C_FS_HUB_EP1_DESCR_bInterval            : std_logic_vector( 7 downto 0) := X"FF";

  constant C_FS_HUB_INT_DESCR_bLength	           : std_logic_vector( 7 downto 0) := X"09"; --9 bytes
  constant C_FS_HUB_INT_DESCR_bDescriptorType      : std_logic_vector( 7 downto 0) := X"04";
  constant C_FS_HUB_INT_DESCR_bInterfaceNumber     : std_logic_vector( 7 downto 0) := X"00";
  constant C_FS_HUB_INT_DESCR_bAlternateSetting    : std_logic_vector( 7 downto 0) := X"00";
  constant C_FS_HUB_INT_DESCR_bNumEndpoints        : std_logic_vector( 7 downto 0) := X"01"; --1 endpoint
  constant C_FS_HUB_INT_DESCR_bInterfaceClass      : std_logic_vector( 7 downto 0) := X"09";
  constant C_FS_HUB_INT_DESCR_bInterfaceSubClass   : std_logic_vector( 7 downto 0) := X"00";
  constant C_FS_HUB_INT_DESCR_bInterfaceProtocol   : std_logic_vector( 7 downto 0) := X"00";
  constant C_FS_HUB_INT_DESCR_iInterface           : std_logic_vector( 7 downto 0) := X"00";

  constant C_FS_HUB_CONF_DESCR_bLength	           : std_logic_vector( 7 downto 0) := X"09"; --9 bytes
  constant C_FS_HUB_CONF_DESCR_bDescriptorType     : std_logic_vector( 7 downto 0) := X"02";
  constant C_FS_HUB_CONF_DESCR_wTotalLength        : std_logic_vector(15 downto 0) := 
    std_logic_vector(to_unsigned(
                                 to_integer(unsigned(C_FS_HUB_CONF_DESCR_bLength)) +
                                 to_integer(unsigned(C_FS_HUB_INT_DESCR_bLength))  +
				 to_integer(unsigned(C_FS_HUB_EP1_DESCR_bLength))  ,16));
  constant C_FS_HUB_CONF_DESCR_bNumInterfaces      : std_logic_vector( 7 downto 0) := X"01";
  constant C_FS_HUB_CONF_DESCR_bConfigurationValue : std_logic_vector( 7 downto 0) := X"01";
  constant C_FS_HUB_CONF_DESCR_iConfiguration      : std_logic_vector( 7 downto 0) := X"00"; --No string descr.
  constant C_FS_HUB_CONF_DESCR_bmAttributes        : std_logic_vector( 7 downto 0) :=
                                       '1'                                      &   -- Reserved - must be set to '1'
				       '0'                                      &   -- Self-powered = '1' / Bus-Powered  = '0'
				       '0'                                      &   -- Remote wakeup
				       "00000"                                  ;
  constant C_FS_HUB_CONF_DESCR_bMaxPower           : std_logic_vector( 7 downto 0) := X"FA"; --500mA - Is this okay ?

  constant C_FS_HUB_DEVCAP_DESCR_bLength           : std_logic_vector( 7 downto 0) := X"07";
  constant C_FS_HUB_DEVCAP_DESCR_bDescriptorType   : std_logic_vector( 7 downto 0) := X"10";
  constant C_FS_HUB_DEVCAP_DESCR_bDevCapabilityType: std_logic_vector( 7 downto 0) := X"02";
  constant C_FS_HUB_DEVCAP_DESCR_bmAttributes      : std_logic_vector(31 downto 0) := X"00000000"; --LPM not supported

  constant C_FS_HUB_BOS_DESCR_bLength              : std_logic_vector( 7 downto 0) := X"05";
  constant C_FS_HUB_BOS_DESCR_bDescriptorType      : std_logic_vector( 7 downto 0) := X"0F";
  constant C_FS_HUB_BOS_DESCR_wTotalLength         : std_logic_vector(15 downto 0) :=
    std_logic_vector(to_unsigned(
                                 to_integer(unsigned(C_FS_HUB_BOS_DESCR_bLength))    +
                                 to_integer(unsigned(C_FS_HUB_DEVCAP_DESCR_bLength)) ,16));
  constant C_FS_HUB_BOS_DESCR_bNumDeviceCaps       : std_logic_vector( 7 downto 0) := X"01";


--++++++++++++++++++++++++++++++
-- Concatenation
--++++++++++++++++++++++++++++++  
  constant C_FS_HUB_DEV_DESCR  : std_logic_vector(to_integer(unsigned(C_FS_HUB_DEV_DESCR_bLength))*8-1 downto 0) :=
                                       C_FS_HUB_DEV_DESCR_bNumConfigurations    &
                                       C_FS_HUB_DEV_DESCR_iSerialNumber	        &
                                       C_FS_HUB_DEV_DESCR_iProduct  	        &
                                       C_FS_HUB_DEV_DESCR_iManufacturer	        &
                                       C_FS_HUB_DEV_DESCR_bcdDevice 	        &
                                       C_FS_HUB_DEV_DESCR_idProduct 	        &
                                       C_FS_HUB_DEV_DESCR_idVendor  	        &
                                       C_FS_HUB_DEV_DESCR_bMaxPacketSize	&
                                       C_FS_HUB_DEV_DESCR_bDeviceProtocol	&
                                       C_FS_HUB_DEV_DESCR_bDeviceSubClass	&
                                       C_FS_HUB_DEV_DESCR_bDeviceClass	        &
                                       C_FS_HUB_DEV_DESCR_bcdUSB		&
                                       C_FS_HUB_DEV_DESCR_bDescriptorType	&
                                       C_FS_HUB_DEV_DESCR_bLength		;

  constant C_FS_HUB_CONF_DESCR : std_logic_vector(to_integer(unsigned(C_FS_HUB_CONF_DESCR_bLength))*8-1 downto 0) :=
                                       C_FS_HUB_CONF_DESCR_bMaxPower            &
				       C_FS_HUB_CONF_DESCR_bmAttributes         &
				       C_FS_HUB_CONF_DESCR_iConfiguration       &
				       C_FS_HUB_CONF_DESCR_bConfigurationValue  &
				       C_FS_HUB_CONF_DESCR_bNumInterfaces       &
				       C_FS_HUB_CONF_DESCR_wTotalLength         &
				       C_FS_HUB_CONF_DESCR_bDescriptorType      &
				       C_FS_HUB_CONF_DESCR_bLength              ;

  constant C_FS_HUB_INT_DESCR  : std_logic_vector(to_integer(unsigned(C_FS_HUB_INT_DESCR_bLength))*8-1 downto 0) :=
                                       C_FS_HUB_INT_DESCR_iInterface	        &
                                       C_FS_HUB_INT_DESCR_bInterfaceProtocol	&
                                       C_FS_HUB_INT_DESCR_bInterfaceSubClass	&
                                       C_FS_HUB_INT_DESCR_bInterfaceClass   	&
                                       C_FS_HUB_INT_DESCR_bNumEndpoints     	&
                                       C_FS_HUB_INT_DESCR_bAlternateSetting 	&
                                       C_FS_HUB_INT_DESCR_bInterfaceNumber  	&
                                       C_FS_HUB_INT_DESCR_bDescriptorType   	&
                                       C_FS_HUB_INT_DESCR_bLength	        ;
  
  constant C_FS_HUB_EP1_DESCR  : std_logic_vector(to_integer(unsigned(C_FS_HUB_EP1_DESCR_bLength))*8-1 downto 0) :=
                                       C_FS_HUB_EP1_DESCR_bInterval	   	&
                                       C_FS_HUB_EP1_DESCR_wMaxPacketSize  	&
                                       C_FS_HUB_EP1_DESCR_bmAttributes    	&
                                       C_FS_HUB_EP1_DESCR_bEndpointAddress	&
                                       C_FS_HUB_EP1_DESCR_bDescriptorType 	&
                                       C_FS_HUB_EP1_DESCR_bLength	        ;
				       
  constant C_FS_HUB_CONF_DESCR_FULL : std_logic_vector(to_integer(unsigned(C_FS_HUB_CONF_DESCR_wTotalLength))*8-1 downto 0) :=
				       C_FS_HUB_EP1_DESCR                       &
				       C_FS_HUB_INT_DESCR                       &
                                       C_FS_HUB_CONF_DESCR                      ;
				       
  constant C_FS_HUB_BOS_DESCR_FULL  : std_logic_vector(to_integer(unsigned(C_FS_HUB_BOS_DESCR_wTotalLength))*8-1 downto 0) :=				       
                                       C_FS_HUB_DEVCAP_DESCR_bmAttributes       &
				       C_FS_HUB_DEVCAP_DESCR_bDevCapabilityType &
				       C_FS_HUB_DEVCAP_DESCR_bDescriptorType	&
				       C_FS_HUB_DEVCAP_DESCR_bLength		&
                                       C_FS_HUB_BOS_DESCR_bNumDeviceCaps        &
				       C_FS_HUB_BOS_DESCR_wTotalLength          &
				       C_FS_HUB_BOS_DESCR_bDescriptorType       &
				       C_FS_HUB_BOS_DESCR_bLength	        ;
	
  -------------------------------------------------------
  -------   Class Descriptors for full-speed hub   ------
  -------------------------------------------------------
  constant C_FS_HUB_HUB_DESCR_bLength             : std_logic_vector( 7 downto 0) := X"09";
  constant C_FS_HUB_HUB_DESCR_bDescriptorType     : std_logic_vector( 7 downto 0) := X"29";
  constant C_FS_HUB_HUB_DESCR_bNbrPorts           : std_logic_vector( 7 downto 0) := X"02";
  constant C_FS_HUB_HUB_DESCR_wHubCharacteristics : std_logic_vector(15 downto 0) := 
                                       "00000000" &
				       "000"      &
				       "10"       & -- No overcurrent protection
				       '1'        & -- Compound device = '1'
				       "00"       ; -- Ganged Power Switching = "00"
  constant C_FS_HUB_HUB_DESCR_bPwrOn2PwrGood      : std_logic_vector( 7 downto 0) := X"00";  
  constant C_FS_HUB_HUB_DESCR_bHubContrCurrent    : std_logic_vector( 7 downto 0) := X"00";  
  constant C_FS_HUB_HUB_DESCR_DeviceRemovable     : std_logic_vector( 7 downto 0) := X"06";  
  constant C_FS_HUB_HUB_DESCR_PortPwrCtrlMask     : std_logic_vector( 7 downto 0) := X"FF";  
  
  constant C_FS_HUB_HUB_DESCR  : std_logic_vector(to_integer(unsigned(C_FS_HUB_HUB_DESCR_bLength))*8-1 downto 0) :=
                                       C_FS_HUB_HUB_DESCR_PortPwrCtrlMask      &
                                       C_FS_HUB_HUB_DESCR_DeviceRemovable      &
                                       C_FS_HUB_HUB_DESCR_bHubContrCurrent     &
                                       C_FS_HUB_HUB_DESCR_bPwrOn2PwrGood       &
                                       C_FS_HUB_HUB_DESCR_wHubCharacteristics  &
                                       C_FS_HUB_HUB_DESCR_bNbrPorts	       &
                                       C_FS_HUB_HUB_DESCR_bDescriptorType      &
                                       C_FS_HUB_HUB_DESCR_bLength	       ;

end usb_fs_hub_cfg_pkg;


package body usb_fs_hub_cfg_pkg is
  
end usb_fs_hub_cfg_pkg;
