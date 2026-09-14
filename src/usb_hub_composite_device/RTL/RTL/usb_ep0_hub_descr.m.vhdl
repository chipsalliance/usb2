
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
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

library usb_lib;
use usb_lib.usb_general_subcmp_pkg.all;
use usb_lib.usb_ep_config_pkg.all;

entity usb_ep0_hub_descr is
generic(C_NWORDS : integer := 128; --Number of 32 bits words
        C_HIGH_SPEED     : boolean := TRUE);
port (
      -- interface to AHB slave module
      sys_clk           : in  std_logic;
      sys_rst_n         : in  std_logic;
      
      reg_waddr         : in  std_logic_vector((log2(C_NWORDS))-1 downto 0);
      reg_wdata         : in  std_logic_vector(31 downto 0);
      reg_raddr         : in  std_logic_vector((log2(C_NWORDS))-1 downto 0);
      reg_rdata         : out std_logic_vector(31 downto 0);
      reg_write         : in  std_logic;
      
      usb_self_powered  : in  std_logic;
      
      ep0_mem_req       : in  std_logic;
      ep0_mem_gnt       : out std_logic;
      ep0_mem_addr      : in  std_logic_vector((log2(C_NWORDS))-1 downto 0);
      ep0_mem_rdata     : out std_logic_vector(63 downto 0);
      
      USB_EnableHub     : in  std_logic;
      hub_enable        : out std_logic;
      hub_dcon          : out std_logic
     );
end usb_ep0_hub_descr;

architecture RTL of usb_ep0_hub_descr is

type t_ep0_mem is array (0 to C_NWORDS-1) of std_logic_vector(31 downto 0);

signal ep0_mem : t_ep0_mem;
signal hub_write_lock : std_logic;

constant C_HUB_CS : integer := 15; --Register address for HUB Control and Status register (Hub enable and Hub DCON bits)

function func_ep0_rom(constant HIGH_SPEED: boolean) return t_ep0_mem is
variable var_address     : integer range 0 to C_NWORDS-1;
variable var_desc_start  : integer range 0 to C_NWORDS-1;
variable var_result      : t_ep0_mem;
type t_setup_start is array (0 to C_NBDEV-1) of std_logic_vector(31 downto 0);
variable var_device      : integer range 0 to C_NBDEV-1;
variable var_setup_start : t_setup_start;
begin
  var_result := (others => (others => '0'));

-----------------------------------------------------------
-- Modify the constants below to determine the descriptors
-----------------------------------------------------------
  ---------------------------------------------------------
  -- DESCRIPTORS of DEVICE 0 (HUB)
  ---------------------------------------------------------

  -- DEVICE DESCRIPTOR (HUB)
  var_desc_start := 0;
  var_address    := 0;
  var_result(var_address)( 7 downto  0) := X"12"; --bLength
  var_result(var_address)(15 downto  8) := X"01"; --bDescriptorType = DEVICE
  var_result(var_address)(23 downto 16) := X"00"; --bcdUSB: LPM supported = X"02",X"10"
  var_result(var_address)(31 downto 24) := X"02";
  var_address := var_address+1;
  var_result(var_address)( 7 downto  0) := X"09"; --bDeviceClass
  var_result(var_address)(15 downto  8) := X"00"; --bDeviceSubClass
  var_result(var_address)(23 downto 16) := X"00"; --bDeviceProtocol
  var_result(var_address)(31 downto 24) := X"40"; --bMaxPacketSize
  var_address := var_address+1;
  var_result(var_address)( 7 downto  0) := X"C9"; --idVendor = NXP VID = 0x1FC9
  var_result(var_address)(15 downto  8) := X"1F";
  var_result(var_address)(23 downto 16) := X"00"; --idProduct = value to be checked !!!
  var_result(var_address)(31 downto 24) := X"BE";
  var_address := var_address+1;
  var_result(var_address)( 7 downto  0) := X"00"; --bcdDevice
  var_result(var_address)(15 downto  8) := X"01";
  var_result(var_address)(23 downto 16) := X"00"; --iManufacturer
  var_result(var_address)(31 downto 24) := X"00"; --iProduct
  var_address := var_address+1;
  var_result(var_address)( 7 downto  0) := X"00"; --iSerialNumber
  var_result(var_address)(15 downto  8) := X"01"; --bNumConfigurations

  -- CONFIGURATION DESCRIPTOR (HUB)
  var_desc_start := var_desc_start + 16;
  var_address    := var_desc_start;
  var_result(var_address)( 7 downto  0) := X"09"; --bLength
  var_result(var_address)(15 downto  8) := X"02"; --bDescriptorType = CONFIGURATION
  var_result(var_address)(23 downto 16) := X"19"; --
  var_result(var_address)(31 downto 24) := X"00";
  var_address := var_address+1;
  var_result(var_address)( 7 downto  0) := X"01";
  var_result(var_address)(15 downto  8) := X"01";
  var_result(var_address)(23 downto 16) := X"00";
  var_result(var_address)(31 downto 24) := X"80";
  var_address := var_address+1;
  var_result(var_address)( 7 downto  0) := X"14"; -- 20 mA max current consumption
  var_result(var_address)(15 downto  8) := X"09";
  var_result(var_address)(23 downto 16) := X"04";
  var_result(var_address)(31 downto 24) := X"00";
  var_address := var_address+1;
  var_result(var_address)( 7 downto  0) := X"00";
  var_result(var_address)(15 downto  8) := X"01";
  var_result(var_address)(23 downto 16) := X"09";
  var_result(var_address)(31 downto 24) := X"00";
  var_address := var_address+1;
  var_result(var_address)( 7 downto  0) := X"00";
  var_result(var_address)(15 downto  8) := X"00";
  var_result(var_address)(23 downto 16) := X"07";
  var_result(var_address)(31 downto 24) := X"05";
  var_address := var_address+1;
  var_result(var_address)( 7 downto  0) := X"81";
  var_result(var_address)(15 downto  8) := X"03";
  var_result(var_address)(23 downto 16) := X"01";
  var_result(var_address)(31 downto 24) := X"00";
  var_address := var_address+1;
  if HIGH_SPEED = false then 
    var_result(var_address)( 7 downto  0) := X"FF";
  else
    var_result(var_address)( 7 downto  0) := X"0F";
  end if;

  -- HUB DESCRIPTOR (Hub)
  var_desc_start := var_desc_start + 16;
  var_address    := var_desc_start;
  var_result(var_address)( 7 downto  0) := X"09"; --bLength
  var_result(var_address)(15 downto  8) := X"29"; --bDescriptorType = CONFIGURATION
  var_result(var_address)(23 downto 16) := X"02";  
  var_result(var_address)(31 downto 24) := X"14";
  var_address := var_address+1;
  var_result(var_address)( 7 downto  0) := X"00";
  var_result(var_address)(15 downto  8) := X"00";
  var_result(var_address)(23 downto 16) := X"00";
  var_result(var_address)(31 downto 24) := X"06";
  var_address := var_address+1;
  var_result(var_address)( 7 downto  0) := X"FF";

  if HIGH_SPEED = true then 
    -- HUB DEVICE QUALIFIER DESCRIPTOR
    var_desc_start := var_desc_start + 16;
    var_address    := var_desc_start;
    var_result(var_address)( 7 downto  0) := X"0A";
    var_result(var_address)(15 downto  8) := X"06";
    var_result(var_address)(23 downto 16) := X"00";
    var_result(var_address)(31 downto 24) := X"02";
    var_address := var_address+1;
    var_result(var_address)( 7 downto  0) := X"00";
    var_result(var_address)(15 downto  8) := X"00";
    var_result(var_address)(23 downto 16) := X"00";
    var_result(var_address)(31 downto 24) := X"40";
    var_address := var_address+1;
    var_result(var_address)( 7 downto  0) := X"01";
    var_result(var_address)(15 downto  8) := X"00";
  
    -- OTHER_SPEED_CONFIGURATION DESCRIPTOR (HUB)
    var_desc_start := var_desc_start + 16;
    var_address    := var_desc_start;
    var_result(var_address)( 7 downto  0) := X"09"; --bLength
    var_result(var_address)(15 downto  8) := X"07"; --bDescriptorType = OTHER CONFIGURATION
    var_result(var_address)(23 downto 16) := X"19"; --
    var_result(var_address)(31 downto 24) := X"00";
    var_address := var_address+1;
    var_result(var_address)( 7 downto  0) := X"01";
    var_result(var_address)(15 downto  8) := X"01";
    var_result(var_address)(23 downto 16) := X"00";
    var_result(var_address)(31 downto 24) := X"80";
    var_address := var_address+1;
    var_result(var_address)( 7 downto  0) := X"FA";
    var_result(var_address)(15 downto  8) := X"09";
    var_result(var_address)(23 downto 16) := X"04";
    var_result(var_address)(31 downto 24) := X"00";
    var_address := var_address+1;
    var_result(var_address)( 7 downto  0) := X"00";
    var_result(var_address)(15 downto  8) := X"01";
    var_result(var_address)(23 downto 16) := X"09";
    var_result(var_address)(31 downto 24) := X"00";
    var_address := var_address+1;
    var_result(var_address)( 7 downto  0) := X"00";
    var_result(var_address)(15 downto  8) := X"00";
    var_result(var_address)(23 downto 16) := X"07";
    var_result(var_address)(31 downto 24) := X"05";
    var_address := var_address+1;
    var_result(var_address)( 7 downto  0) := X"81";
    var_result(var_address)(15 downto  8) := X"03";
    var_result(var_address)(23 downto 16) := X"01";
    var_result(var_address)(31 downto 24) := X"00";
    var_address := var_address+1;
    var_result(var_address)( 7 downto  0) := X"0F";

  end if;

  -- LINK POINTER to start of device list
  -- This is defined at the end of the process (after all setup commands have been defined)

  -----------------------------------------------------------
  -- SETUP requests - device 0
  -----------------------------------------------------------
  var_desc_start := var_desc_start + 16; --jump to the next 16 words - allow buffer of 64 bytes for last descriptor.
  var_address    := var_desc_start;

  var_device  := 0;
  var_setup_start(var_device) := std_logic_vector(to_unsigned(var_address,32));
  var_result(var_address  ) := X"01000680"; --GetDeviceDescriptor
  var_result(var_address+2) := X"00120000"; --GetDeviceDescriptor
  var_result(var_address+1) := X"FFFF8000"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB

  var_address := var_address + 4;
  var_result(var_address  ) := X"02000680"; --GetConfigurationDescriptor
  var_result(var_address+2) := X"00190000"; --GetConfigurationDescriptor
  var_result(var_address+1) := X"FFFF8100"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000500"; --SetAddress
  var_result(var_address+2) := X"00000000"; --SetAddress
  var_result(var_address+1) := X"F8000001"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000900"; --SetConfiguration
  var_result(var_address+2) := X"00000000"; --SetConfiguration
  var_result(var_address+1) := X"FFFE0002"; --SETUP_MASK_LSB - only configuration 0 or 1 is allowed.
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000300"; --SetFeature(Device)
  var_result(var_address+2) := X"00000000"; --SetFeature(Device)
  var_result(var_address+1) := X"FFFC0003"; --SETUP_MASK_LSB - wValue = Feature selector (DEVICE_REMOTE_WAKEUP = 1 / TEST_MODE = 2 )
  var_result(var_address+3) := X"000000FF"; --SETUP_MASK_MSB - wIndex(15:8) = Test Selector

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000302"; --SetFeature(Endpoint)
  var_result(var_address+2) := X"00000000"; --SetFeature(Endpoint)
  var_result(var_address+1) := X"FFFF0004"; --SETUP_MASK_LSB - wValue = Feature selector (ENDPOINT_HALT = 0).
  var_result(var_address+3) := X"0000FF7E"; --SETUP_MASK_MSB - wIndex = Endpoint

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000B01"; --SetInterface - Only interface zero is supported
  var_result(var_address+2) := X"00000000"; --SetInterface
  var_result(var_address+1) := X"FFFF0000"; --SETUP_MASK_LSB - wValue = Alternate setting.
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB - wIndex = Interface number

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000880"; --GetConfiguration - return configuration value.
  var_result(var_address+2) := X"00010000"; --GetConfiguration
  var_result(var_address+1) := X"FFFF0005"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000A81"; --GetInterface - return interface value.
  var_result(var_address+2) := X"00010000"; --GetInterface
  var_result(var_address+1) := X"FFFF0006"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB - wIndex = Interface number

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000080"; --GetStatus(Device) - return status
  var_result(var_address+2) := X"00020000"; --GetStatus
  var_result(var_address+1) := X"FFFF0007"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000081"; --GetStatus(Interface) - return status
  var_result(var_address+2) := X"00020000"; --GetStatus
  var_result(var_address+1) := X"FFFF0008"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB - wIndex = Interface number

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000082"; --GetStatus(Endpoint) - return status
  var_result(var_address+2) := X"00020000"; --GetStatus
  var_result(var_address+1) := X"FFFF0009"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FF7E"; --SETUP_MASK_MSB - wIndex = Endpoint number

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000100"; --ClearFeature(Device) - return status
  var_result(var_address+2) := X"00000000"; --ClearFeature
  var_result(var_address+1) := X"FFFE000A"; --SETUP_MASK_LSB - wvalue = Feature selector (DEVICE_REMOTE_WAKEUP = 1 / TEST_MODE = 2 )   
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB - wIndex = Interface number

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000102"; --ClearFeature(Endpoint) - return status
  var_result(var_address+2) := X"00000000"; --ClearFeature
  var_result(var_address+1) := X"FFFF000B"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FF7E"; --SETUP_MASK_MSB - wIndex = Interface number

  var_address := var_address + 4;
  var_result(var_address  ) := X"290006A0"; --GetHubDescriptor
  var_result(var_address+2) := X"00090000"; --GetHubDescriptor
  var_result(var_address+1) := X"FFFF8200"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB

  var_address := var_address + 4;
  var_result(var_address  ) := X"000000A0"; --GetHubStatus
  var_result(var_address+2) := X"00040000"; --GetHubStatus
  var_result(var_address+1) := X"FFFF4042"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB

  var_address := var_address + 4;
  var_result(var_address  ) := X"000000A3"; --GetHubPortStatus
  var_result(var_address+2) := X"00040000"; --GetHubPortStatus
  var_result(var_address+1) := X"FFFF4042"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FFFC"; --SETUP_MASK_MSB

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000120"; --ClearHubFeature
  var_result(var_address+2) := X"00000000"; --ClearHubFeature
  var_result(var_address+1) := X"FFFE4040"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000123"; --ClearHubPortFeature
  var_result(var_address+2) := X"00000000"; --ClearHubPortFeature
  var_result(var_address+1) := X"FFE04040"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FFFC"; --SETUP_MASK_MSB

  var_address := var_address + 4;
  var_result(var_address  ) := X"00000320"; --SetHubFeature
  var_result(var_address+2) := X"00000000"; --SetHubFeature
  var_result(var_address+1) := X"FFFE4041"; --SETUP_MASK_LSB
  var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB

  if HIGH_SPEED = false then 

    var_address := var_address + 4;
    var_result(var_address  ) := X"00000323"; --SetHubPortFeature
    var_result(var_address+2) := X"00000000"; --SetHubPortFeature
    var_result(var_address+1) := X"FFE040C1"; --SETUP_MASK_LSB
    var_result(var_address+3) := X"0000FFFC"; --SETUP_MASK_MSB

  else

    var_address := var_address + 4;
    var_result(var_address  ) := X"00000323"; --SetHubPortFeature
    var_result(var_address+2) := X"00000000"; --SetHubPortFeature
    var_result(var_address+1) := X"FFE04041"; --SETUP_MASK_LSB
    var_result(var_address+3) := X"0000FFFC"; --SETUP_MASK_MSB

    var_address := var_address + 4;
    var_result(var_address  ) := X"06000680"; --GetDeviceQualifierDescriptor
    var_result(var_address+2) := X"000A0000"; --GetDeviceQualifierDescriptor
    var_result(var_address+1) := X"FFFF8C00"; --SETUP_MASK_LSB
    var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB 

    var_address := var_address + 4;
    var_result(var_address  ) := X"07000680"; --GetOtherSpeedConfigurationDescriptor
    var_result(var_address+2) := X"00190000"; --GetOtherSpeedConfigurationDescriptor
    var_result(var_address+1) := X"FFFF8E80"; --SETUP_MASK_LSB
    var_result(var_address+3) := X"0000FFFF"; --SETUP_MASK_MSB 

  end if;

  -- LINK POINTER to start of device list
  var_address := to_integer(unsigned(C_DEV_LINK_START)) - (C_NBDEV-1);
  for i in 0 to C_NBDEV-1 loop
    var_result(var_address+i) := var_setup_start(i);
  end loop;

  return var_result;
end;

constant C_EP0_ROM  : t_ep0_mem := func_ep0_rom(C_HIGH_SPEED);
constant C_ADDR_SP1 : integer := 17;
constant C_ADDR_SP2 : integer := 65;

begin

  ep0_mem_gnt      <= ep0_mem_req;
  
  PROC_ROM : process(ep0_mem_req, ep0_mem_addr, usb_self_powered )
  variable var_mem_addr_integer : integer range 0 to C_NWORDS-1;
  begin
    if ep0_mem_req = '1' then --This is required to prevent range constraint violations (as ep0_mem_addr is also used for data transfer) 
      var_mem_addr_integer       := to_integer(unsigned(ep0_mem_addr(log2(C_NWORDS)-1 downto 1)&'0'));
      ep0_mem_rdata(31 downto 0) <= C_EP0_ROM(var_mem_addr_integer); 
      var_mem_addr_integer       := to_integer(unsigned(ep0_mem_addr(log2(C_NWORDS)-1 downto 1)&'1'));
      ep0_mem_rdata(63 downto 32) <= C_EP0_ROM(var_mem_addr_integer); 
      
      if (usb_self_powered = '1') and ((to_integer(unsigned(ep0_mem_addr)) = C_ADDR_SP1) or (to_integer(unsigned(ep0_mem_addr)) = C_ADDR_SP2)) then
        ep0_mem_rdata(63 downto 56) <= X"C0";
      else
      end if;
    else
      ep0_mem_rdata <= (others => '1');
    end if;
  end process PROC_ROM;
  
  PROC_REG_READ : process(reg_raddr, ep0_mem)
  begin
    reg_rdata <= (others => '0');
    if to_integer(unsigned(reg_raddr)) < C_NWORDS then
      reg_rdata <= ep0_mem(to_integer(unsigned(reg_raddr)));
    end if;
  end process PROC_REG_READ;

  PROC_REG_WRITE : process(sys_rst_n, sys_clk)
  begin
    if sys_rst_n = '0' then
      ep0_mem <= C_EP0_ROM;
    elsif sys_clk'event and sys_clk = '1' then
      if reg_write = '1' and hub_write_lock = '0' and to_integer(unsigned(reg_waddr)) < C_NWORDS then
        ep0_mem(to_integer(unsigned(reg_waddr))) <= reg_wdata;
      end if;
      if USB_EnableHub = '1' then --If the input signal USB_EnableHub is set to 1b, it overrules the hub register bits.
        ep0_mem(C_HUB_CS)(0) <= '1';
        ep0_mem(C_HUB_CS)(16) <= '1';
      end if;
    end if;  
  end process PROC_REG_WRITE;

  hub_enable     <= ep0_mem(C_HUB_CS)(0);
  hub_dcon       <= ep0_mem(C_HUB_CS)(16);
  hub_write_lock <= ep0_mem(C_HUB_CS)(0) and ep0_mem(C_HUB_CS)(16);


end RTL; --usb_ep0_hub_descr

