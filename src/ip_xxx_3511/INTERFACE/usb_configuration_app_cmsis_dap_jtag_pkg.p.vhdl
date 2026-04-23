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
--           $RCSfile: usb_configuration_app_cmsis_dap_jtag_pkg.p.vhdl.rca $
--
--             Author: Gaetan Marsin
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

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library rtl;
use rtl.usb_general_subcmp_pkg.all;
use rtl.usb_subcmp_pkg.all;

package usb_configuration_app_cmsis_dap_jtag_pkg is

--------------------------------------------------------------------
-- Function packages
--------------------------------------------------------------------
function GetMultSpeed (ext_clock, high_speed: boolean)
           return integer;

function GetSysclkFreq (ext_clock, high_speed: boolean)
           return four_bytes;

function IsFreqSupported (ext_clock: boolean; input_clk_freq, clk_freq: four_bytes)
         return boolean;

function GetFreqDiv (ext_clock: boolean; input_clk_freq, clk_freq: four_bytes)
         return std_logic_vector;

--------------------------------------------------------------------
-- Constant definition
--------------------------------------------------------------------

-- Define the maximum length for Instruction Register, must be between 1 and 255
constant C_MAX_IR_LENGTH : natural:= 8;
-- Define the maximum number of devices on the JTAG device chain, must be between 1 and 255
constant C_MAX_NR_DEVICES : natural:= 4;

--------------------------------------------------------------------
-- DAP_Info Response :Get Information about CMSIS-DAP Debug Unit  --
--------------------------------------------------------------------

--following infos have fixed length:

constant C_INFO_SWD_IMPLEMENTED  : boolean := FALSE;
constant C_INFO_JTAG_IMPLEMENTED : boolean := TRUE;
--constant C_INFO_TARGET_CAPABILITIES : byte := "00000010"; This constant is now decoded from C_INFO_SWD_IMPLEMENTED and C_INFO_JTAG_IMPLEMENTED
-- information about the Capabilities (BYTE) of the Debug Unit
-- •Bit 0: 1 = SWD Serial Wire Debug communication is implemented (0 = not implemented).
-- •Bit 1: 1 = JTAG communication is implemented (0 = not implemented).

constant C_INFO_MAX_PKT_COUNT : natural:= 1; -- maximum Packet Count (BYTE).must be between 1 and 255
constant C_INFO_MAX_PKT_SIZE : natural:= 64; --maximum Packet Size (SHORT), must be between 64 and 32768

-- following infos are string encoded in US ASCII, numbers of characters is limited to 256 (including the \x00 terminator)
constant C_INFO_VENDOR_ID_PRESENT : boolean:= FALSE;
constant C_INFO_VENDOR_ID_VALUE : string:= "TO BE FILLED";

constant C_INFO_PRODUCT_ID_PRESENT : boolean:= FALSE;
constant C_INFO_PRODUCT_ID_VALUE : string:= "TO BE FILLED";

constant C_INFO_SERIAL_NR_PRESENT : boolean:= FALSE;
constant C_INFO_SERIAL_NR_VALUE : string:= "TO BE FILLED";

constant C_INFO_CMSIS_DAP_FIRMWARE_VERS_PRESENT : boolean:= FALSE;
constant C_INFO_CMSIS_DAP_FIRMWARE_VERS_VALUE : string:= "TO BE FILLED";

constant C_INFO_TARGET_DEVICE_VENDOR_PRESENT: boolean:= FALSE;
constant C_INFO_TARGET_DEVICE_VENDOR_VALUE: string:= "TO BE FILLED";-- only available on Debug Units with known Target Device

constant C_INFO_TARGET_DEVICE_NAME_PRESENT: boolean:= FALSE;
constant C_INFO_TARGET_DEVICE_NAME_VALUE: string:= "TO BE FILLED";-- only available on Debug Units with known Target Device

--------------------------------------------------------------------
-- DAP_CONNECT : Connect to Device and selected DAP mode  --
--------------------------------------------------------------------

-- DO NOT MODIFY THIS, NOT CONFIGURABLE: BEGIN
constant C_PORT_JTAG      :  byte := X"02";
constant C_PORT_SWD       :  byte := X"01";
constant C_PORT_DISABLED  :  byte := X"00";
 -- DO NOT MODIFY THIS: END

constant C_DEFAULT_DAP_MODE: byte :=  C_PORT_JTAG;

--------------------------------------------------------------------
-- DAP_ResetTarget : Reset Target with Device specific sequence   --
--------------------------------------------------------------------
-- Execute: indicates whether a device specific reset sequence was executed.
 --FALSE = no device specific reset sequence is implemented.
 --TRUE: = a device specific reset sequence is implemented.
 -- e.g.when a device needs a time-critical unlock sequence that enables the debug port.

constant C_RESET_TARGET_PRESENT      :  boolean := FALSE; --change to TRUE when a device reset sequence is implemented

--------------------------------------------------------------------
-- DAP_SWJ_Pins : Control and monitor SWD/JTAG Pins.    --
--------------------------------------------------------------------
constant C_NRESET_PIN_FEEDBACK_PRESENT : boolean := TRUE;

--------------------------------------------------------------------
-- DAP_SWJ_CLOCKS : Select SWD/JTAG Clock.                   .    --
--------------------------------------------------------------------
constant C_EXT_SYS_CLK_IN_HZ : four_bytes := X"05F5E100"; -- 100 MHz -- To be filled by integrator in case external cmsis dap is provided
constant C_FS_SYS_CLK_IN_HZ  : four_bytes := X"00B71B00"; -- 12 MHz  -- Full Speed Device
constant C_HS_SYS_CLK_IN_HZ  : four_bytes := X"03938700"; -- 60 MHz  -- High Speed Device

constant C_EXT_MULT_SPEED : integer:= 100; -- To be filled by integrator in case of external clock : 1 us = xx* sys_clk periods at xx MHz 
constant C_FS_MULT_SPEED : integer:= 12; -- 1 us = 12* sys_clk periods at 12 MHz -- Full Speed Device
constant C_HS_MULT_SPEED : integer:= 60; -- 1 us = 60* sys_clk periods at 60 MHz -- High Speed Device

constant C_MAX_BUFF_SIZE: natural:= C_INFO_MAX_PKT_SIZE;

constant C_DIV_WIDTH : natural:= 6;
constant C_MAX_DIV   : natural:= 2**C_DIV_WIDTH; --64

type t_DIV_ARRAY is array(natural range <>) of integer;

--constant C_DIV_ARRAY : t_DIV_ARRAY(C_MAX_DIV-1 downto 0) :=
--    (0      => 10,  --divider setting <=> x/10 division factor
--     1      => 8,
--     2      => 6,
--     3      => 5,
--     4      => 4,
--     5      => 3,
--     6      => 2,
--     7      => 1
--     );

end usb_configuration_app_cmsis_dap_jtag_pkg;

package body usb_configuration_app_cmsis_dap_jtag_pkg is

--------------------------------------------------------------------
-- Function Bodies
--------------------------------------------------------------------

function GetMultSpeed (ext_clock, high_speed: boolean)
         return integer is
begin
    if ext_clock = true then
      return C_EXT_MULT_SPEED;
    else
      if high_speed = true then
        return C_HS_MULT_SPEED;
      else
        return C_FS_MULT_SPEED;
      end if;
    end if;
end GetMultSpeed;

function GetSysclkFreq (ext_clock, high_speed: boolean)
         return four_bytes is
begin
    if ext_clock = true then
      return C_EXT_SYS_CLK_IN_HZ;
    else
      if high_speed = true then
        return C_HS_SYS_CLK_IN_HZ;
      else
        return C_FS_SYS_CLK_IN_HZ;
      end if;
    end if;
end GetSysclkFreq;

function IsFreqSupported (ext_clock: boolean; input_clk_freq, clk_freq: four_bytes)
         return boolean is
  variable v_supported : boolean := false;           
begin

  if clk_freq > input_clk_freq then 
    v_supported := false;
  else
    if ext_clock = true then
      -- To be adapted by integrator
      v_supported := true;
    else
      for i in 0 to C_MAX_DIV-1 loop
        -- check for overflow 
        if to_integer(input_clk_freq)/(i+1) >= to_integer(clk_freq) then
          if to_integer(input_clk_freq) = to_integer(clk_freq) * (i+1) then
            v_supported := true;
            exit;
          end if;
        end if;
      end loop;
    end if;
  end if;
  return v_supported;

end IsFreqSupported;

function GetFreqDiv (ext_clock: boolean; input_clk_freq, clk_freq: four_bytes)
         return std_logic_vector is
  variable v_cmsis_dap_div : std_logic_vector(C_DIV_WIDTH-1 downto 0) := (others => '0');           
begin

  if clk_freq > input_clk_freq then 
    v_cmsis_dap_div := (others => '0');
  else
    if ext_clock = true then
      -- To be adapted by integrator
      v_cmsis_dap_div := (others => '0');
    else
      for i in 0 to C_MAX_DIV-1 loop
        -- check for overflow 
        if to_integer(input_clk_freq)/(i+1) >= to_integer(clk_freq) then
          if to_integer(input_clk_freq) = to_integer(clk_freq) * (i+1) then
            v_cmsis_dap_div := std_logic_vector(to_unsigned(i,C_DIV_WIDTH));
            exit;
          end if;
        end if;
      end loop;
    end if;
  end if;
  return v_cmsis_dap_div;

end GetFreqDiv;

end usb_configuration_app_cmsis_dap_jtag_pkg;

