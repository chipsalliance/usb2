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
--               File: usb_rgen.m.vhdl
--
--             Author: Bart Vertenten
--
--       Organisation: Corporate I&T / IP & Architecture
--
--              $Date: Sun Apr 23 19:20:43 2017 $
--
--            Project: IP_3511 - Low gate count USB peripheral IP 
--
--        Description: 
--
--          $Revision: 1.3 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_rgen.m.vhdl.rca $
--   
--    Revision: 1.3 Mon May 31 09:34:14 2010 bve
--    added one more fix for generating bus reset interrupt
--   
--    Revision: 1.2 Fri May 28 09:29:26 2010 bve
--    start busreset counter only when the device is connected
--   
--    Revision: 1.1 Thu Apr  1 09:49:54 2010 bve
--    Initial version
--   
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY rtl;
USE rtl.usb_general_subcmp_pkg.all;
USE rtl.usb_subcmp_pkg.all;
USE rtl.usb_configuration_subcmp_pkg.all;

entity usb_rgen is
  port  (
          --- generated reset signals  ---
          RG_SetSE0Int:      out boolean; -- sets SE0 interrupt
          RG_BUSReset:       out boolean; -- Bus Reset
          Reset_N:           out one_bit; -- reset active low
          PUReset_N:         out one_bit; -- power up reset
          Reset48MHz_N:      out one_bit; -- 48 MHz reset

          --- inputs ---
          UP_DsLineBits:     in  two_bits; -- downstream USB bus
          PU_Reset_N:        in  one_bit;  -- power up reset
          usbreg_dev_connect: in one_bit;

          --- system ---
          FsClk:             in  one_bit; -- clock
          Clk48MHz:          in  one_bit; -- 48 MHz clock
          RG_BusActive:      out boolean; -- Bus is not idle
          async_disable:     in  one_bit  -- test control pin
        );
end usb_rgen;

architecture RTL of usb_rgen is
 
  signal BUSReset_N: one_bit;
  signal BUSReset_N_Z1: one_bit;
  signal BUSReset_N_Z2: one_bit;
  signal PUReset_N_int: one_bit;

  signal Reset48Mhz_N_S1: one_bit;
  signal Reset48Mhz_N_S2: one_bit;

  signal Reset12Mhz_N_S1: one_bit;
  signal Reset12Mhz_N_S2: one_bit;

  signal PUorBUSReset12MHz_N: one_bit;

  signal SE0Detect: boolean;
  signal SE0Detect_S1: boolean;
  signal SE0Detect_S2: boolean;

  signal UP_DsLogValue: T_UsbLog_enum;

  signal PU_Reset_N_async : one_bit; 

begin

PU_Reset_N_async <= PU_Reset_N OR async_disable;

----------------------------------------------------------
------------        Reset for 48 MHz       ---------------
----------------------------------------------------------

RESET_48MHz: process(PU_Reset_N_async, Clk48Mhz)
begin

-- DOC_BEGIN: Reset for 48 MHz  
-- Introduce 2 synchronisation
-- flip flops
-- for 48 MHz domain
  
 if PU_Reset_N_async = ACTIVE_LOW then
   Reset48MHz_N_S1 <= ACTIVE_LOW;
   Reset48MHz_N_S2 <= ACTIVE_LOW;
   
 elsif (Clk48Mhz'event and Clk48Mhz = '1') then
   Reset48MHz_N_S1 <= PU_Reset_N;
   Reset48MHz_N_S2 <= Reset48Mhz_N_S1;
 end if;

--DOC_END
 
end process;

Reset48MHz_N <= Reset48Mhz_N_S2 OR async_disable;


----------------------------------------------------------
----------    Reset for 12 MHz recovered     -------------
----------------------------------------------------------

RESET12MHzRef: process(PU_Reset_N_async, FsClk)

-- DOC_BEGIN: Reset for 12 MHz recovered 
-- Introduce 2 synchronisation flip flops
-- for 12 MHz recovered domain
  
begin
 if PU_Reset_N_async = ACTIVE_LOW then
   Reset12Mhz_N_S1 <= ACTIVE_LOW;
   Reset12Mhz_N_S2 <= ACTIVE_LOW;
 elsif (FsClk'event and FsClk = '1') then
   Reset12Mhz_N_S1 <= PU_Reset_N;
   Reset12Mhz_N_S2 <= Reset12Mhz_N_S1;
 end if;
end process;

-- DOC_END

PUReset_N_int <= Reset12Mhz_N_S2 OR async_disable;
PUReset_N     <= PUReset_N_int;


----------------------------------------------------------
----------  Bus Reset for 12 MHz recovered   -------------
----------------------------------------------------------

-- DOC_BEGIN: Bus Reset for 12 MHz recovered
-- Give a reset when Power up reset or bus reset.
PUorBUSReset12MHz_N <= conv_active_low(
                         BUSReset_N = ACTIVE_LOW or
                         Reset12Mhz_N_S2 = ACTIVE_LOW);

Reset_N <= PUorBUSReset12Mhz_N OR async_disable;
-- DOC_END

----------------------------------------------------------
----------       Interrupt generator         -------------
----------------------------------------------------------


INT_GEN: process(PUReset_N_int, FsClk)
begin
-- DOC_BEGIN
-- Insert two delay flip flops
-- to introduce edge detection
  
  if PUReset_N_int = ACTIVE_LOW then
    BUSReset_N_Z1 <= HIGH;
    BUSReset_N_Z2 <= HIGH;
    RG_SetSE0Int <= FALSE;
  elsif (FsClk'event and FsClk = '1') then
    BUSReset_N_Z1 <= BUSReset_N;
    BUSReset_N_Z2 <= BUSReset_N_Z1;
    
    -- detect rising edge, active low to inactive high
    -- on bus reset line 
    -- to make pulse on RG_SetSE0Int
    
    RG_SetSE0Int <= (BUSReset_N_Z2 = ACTIVE_LOW and
                     BUSReset_N_Z1 = INACTIVE_HIGH);
  end if;
end process;
-- DOC_END

----------------------------------------------------------
----------       Bus Reset Detector          -------------
----------------------------------------------------------

-- DOC_BEGIN: Bus SE0 Detector 
-- Convert
-- the incoming UP bits
-- to a logical representation

UP_DsLogValue <= UsbDif2Log(UP_DsLineBits, USB_FULL_SPEED);
SE0Detect <= (Up_DsLogValue = USB_LOG_SE0);
-- DOC_END
  
BUSRESET_DETECT: process(PUReset_N_int, FsClk)
  constant RESET_TIMER_RANGE: integer := 64;
  constant RESET_DETECT_TIME: integer := 48;

  variable BusResetTimer: integer range 0 to RESET_TIMER_RANGE-1;
begin
  if (PUReset_N_int = ACTIVE_LOW) then
    BusResetTimer := 0;
    BUSReset_N <= INACTIVE_HIGH;
    SE0Detect_S1 <= FALSE;
    SE0Detect_S2 <= FALSE;
    
  elsif (FsClk'event and FsClk = '1') then
    
    -- DOC_BEGIN:  Bus reset pulse generation (delay and extention)
    
    -- As long as there is no SE0, BusResetTimer stays at 0.
    -- Mind that the Inc(rement) part in IncSat() makes BusResetTimer overflow
    -- when it is incremented by 1 from RESET_TIMER_RANGE-1
    -- The Sat(uration) part in IncSat() also keeps it at 0.
    
    BusResetTimer := IncSat(BusResetTimer , RESET_TIMER_RANGE);
    
    -- When there is an SE0, BusResetTimer starts counting. If there is 
    -- 1 cycle of non-SE0, it is reset to 0.
    -- Up to 48 BUSReset_N is INACTIVE_HIGH.
    
    if (BusResetTimer < RESET_DETECT_TIME) then
      BUSReset_N <= INACTIVE_HIGH;
      if (not SE0Detect_S2) or (usbreg_dev_connect = '0') then 
        BusResetTimer := 0;
      end if;
      
    -- When BusResetTimer reaches 48 (about 4 us), BUSReset_N goes ACTIVE_LOW
    -- and BusResetTimer keeps counting, even if there is no SE0
    -- anymore on the bus.
      
    elsif (BusResetTimer < RESET_TIMER_RANGE-1) then
      BUSReset_N <= ACTIVE_LOW;
      
    -- When the timer reaches 63, BusReset_N goes INACTIVE_HIGH again.
    -- The timer stays at 63 until the SE0 ends.
    -- This guarantees a reset pulse with a fixed width.
      
    else
      BUSReset_N <= INACTIVE_HIGH;
      if (not SE0Detect_S2) or (usbreg_dev_connect = '0') then 
        BusResetTimer := 0;
      end if;
    end if;

    SE0Detect_S1 <= SE0Detect;
    SE0Detect_S2 <= SE0Detect_S1;
    -- DOC_END

    
  end if;

end process;

  RG_BUSReset <= (BUSReset_N = ACTIVE_LOW);

  -- bus active signal
  RG_BusActive <=
    (UsbDif2Log(UP_DsLineBits, USB_FULL_SPEED) /= USB_LOG_J);

end RTL;
