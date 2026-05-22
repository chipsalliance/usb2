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
--               File: usb_timers_sf.m.vhdl
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
--          $Revision: 1.4 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_timers_sf.m.vhdl.rca $
--   
--    Revision: 1.4 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.3 Wed May  4 14:51:08 2011 beq03099
--    fixed problem with inrush current
--    Only switch off USB PLL when VBusDebounced has the same value
--    as VBusAvailable
--   
--    Revision: 1.2 Tue Jun  8 10:08:56 2010 bve
--    Fixed conformal warnings
--   
--    Revision: 1.1 Fri May 21 08:55:00 2010 aes
--    First check in.
--   
--    Revision: 1.3 Tue May  4 10:16:45 2010 bve
--    fixed reset problem with Clk1kHz_zz
--   
--    Revision: 1.2 Fri Apr 16 12:00:04 2010 bve
--    added logic for internal PLL and RC circuit
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
USE rtl.usb_configuration_subcmp_pkg.all;
USE rtl.usb_subcmp_pkg.all;

entity usb_timers_sf is
  port  (
	--------------- Resume ---------------------------------
	MM_Resume:           in  boolean; -- Remote wake up request from MM
	LPM_MM_Resume:       in  boolean; -- LPM Remote wake up request from MM
	TM_SendResume:       out boolean; -- Remote wake up signal to SIE
	LPM_HostRetry_Reset: in  boolean; -- Host Retry timer reset

	--------------- Suspend/Wake up ------------------------
	MM_NeedClock:        in  boolean; -- MM needs clock
	RG_BusActive:        in  boolean; -- USB bus is not idle
	TM_Suspend:          out boolean; -- Device is suspended
	LPM_TM_Suspend:      out boolean; -- Device is LPM suspended (10us boundary)
	USB_Suspended_N:     out one_bit; -- Device is suspended 
	TM_ClockOn:          out one_bit; -- Clock control

	---------------- Frame Timer ---------------------------
	SIE_RxSOF:           in  boolean; -- SIE received SOF

	----------------- System -------------------------------
	FsClk:               in  one_bit; -- Recovered Clock
	PUReset_N:           in  one_bit; -- Reset for Recovered Clock
        Reset48MHz_N:        in  one_bit;
        Clk48MHz:            in  one_bit;
	RG_SetSE0Int:        in  boolean;
	
        LPM_HIRD_SW:         in  four_bits; -- Value programmed by SW     
        LPM_HIRD_HW:         in  four_bits; -- Value received from LPM token	  
        LPM_NYET:            in boolean;    -- LPM NYET from Device Handler
     
	USB_FrameClock:      out one_bit;    -- 1 kHz frame clock
        TM_IsoToggle:        out integer range 0 to 1; -- toggling iso buffers
	TM_1kHzPulse:        out one_bit;    -- 1 kHz frame pulse
        TM_FrameTimer:       out std_logic_vector(15 downto 0);
        TM_SOFDetect:        out std_logic;
	
	VBusAvailable:       in  boolean;
	VBusDebounced:       in  boolean;
	
	async_disable:       in  one_bit     -- async_disable input
	);
end usb_timers_sf;

architecture RTL of usb_timers_sf is

  constant SUSPEND_TIME           : integer := 3;
  constant IDLE_BEFORE_RESUME_TIME: integer := 5;
  constant RESUME_TIME            : integer := 3;
  constant CLOCK_OFF_DELAY        : integer := 7;

  constant HOSTRETRY_TIME  : integer := 10; --10us
  constant LPM_SUSPEND_TIME: integer := 60; --60us
  constant LPM_RESUME_TIME : integer := 50; --50us
  
  type T_SR_State is (IDLE, SENDING, LPM_SENDING);

  signal Clk1kHz: boolean; 
  signal Clk1kHz_Z: boolean;
  signal Clk1kHz_ZZ: boolean;
  signal Clk1kHzPulse: boolean;
  
  signal Clk1MHzPulse: boolean;
  
  signal DeviceSuspended: boolean;
  signal Suspend5ms: boolean;
  signal LPM_Suspend60us: boolean;

  signal ClockOnTimer: integer range 0 to CLOCK_OFF_DELAY;
  signal ClockOn: one_bit;
  signal Needclock: boolean;
  signal ClockIsOff: boolean;
  signal LPM_Needclock: boolean;

  signal LPM_HIRD_NeedClk: boolean;
  signal LPM_NYET_NeedClk: boolean;

  constant MAX_FRAME_LENGTH:integer := 48000;
  signal FrameTimer: integer range 0 to MAX_FRAME_LENGTH;
  signal FrameLength: integer range 0 to MAX_FRAME_LENGTH;
  signal ISOToggle: integer range 0 to 1;

  signal LPM_Counter   : four_bits;
  signal LPM_Activated : boolean;

  signal SOFDetect : std_logic;

  signal RG_BusActive_S: boolean;
  signal SR_State: T_SR_State;
  signal NeedClock_S: boolean;
  signal ClockIsOff_S: boolean;
  signal ClockIsOff_SS: boolean;
  
  signal NeedClock_old : boolean;

begin

TM_IsoToggle <= ISOToggle;

FRAMETIMER_PROCESS: process (Clk48MHz, Reset48MHz_N)
  variable RxSOF_Z: boolean;

begin
  if (Reset48MHz_N = ACTIVE_LOW) then
    RxSOF_Z    := FALSE;
    Clk1kHz    <= FALSE;

    FrameTimer <= 0;
    SOFDetect  <= '0';

  elsif Clk48MHz'event and (Clk48MHz = '1') then

----------------------------------------------------------
--         1 kHz Clock and pulse generator              --
----------------------------------------------------------
    -- DOC_BEGIN: 1kHz Clock Generator
    -- The frame timer circuit generates a 50% duty cycle frame 
    -- clock (1 kHz) and a one cycle pulse on every rising edge
    -- of the frame clock. This pulse is used by a number of  
    -- millisecond timers in this and other modules. The timer
    -- is synchronized to the Start of Frame packets in a way
    -- the rising edge of the clock occurs in the middle of the 
    -- SOF packet. If there are no SOF's (this is always the
    -- case for low speed devices), the timer is free running.
					    
    Clk1kHz      <= (FrameTimer < MAX_FRAME_LENGTH/2);

    -- set SOF when RxSOF detected
    if IsRisingEdge(SIE_RxSOF,RxSOF_Z) then
      SOFDetect <= '1';
    else
      SOFDetect <= '0';
    end if;
    RxSOF_Z      := SIE_RxSOF;

    if (SOFDetect = '1') or (FrameTimer = MAX_FRAME_LENGTH-1) then
      FrameTimer <= 0;
    else
      FrameTimer <= FrameTimer +1;
    end if; 
	
    -- DOC_END

  end if;

end process FRAMETIMER_PROCESS;


-----------------------------------------------------------------------
--                             FrameTimer                            --
----------------------------------------------------------------------- 
MAIN: process (FsClk, PUReset_N)
  	 
  variable ResumeTimer: integer range 0 to LPM_RESUME_TIME;
  variable ResumePending: boolean;
  variable LPM_ResumePending: boolean;
  variable SuspendTimer: integer range 0 to LPM_SUSPEND_TIME;

begin
	     
  if (PUReset_N = ACTIVE_LOW) then
		
    Clk1MHzPulse                <= FALSE;
    LPM_Counter                 <= "0000";
								     
    ResumeTimer                 := 0;
    SR_State                    <= IDLE;
    TM_SendResume               <= FALSE;
    ResumePending               := FALSE;
    LPM_ResumePending           := FALSE;
    RG_BusActive_S              <= FALSE;

    SuspendTimer                := 0;
    DeviceSuspended             <= FALSE;
    LPM_Suspend60us             <= FALSE;
    Suspend5ms                  <= FALSE;

    ClockOnTimer                <= 0;
    NeedClock_S                 <= TRUE;
    ClockIsOff_S                <= FALSE;
    ClockIsOff_SS               <= FALSE;

    Clk1kHz_Z                   <= FALSE;
    Clk1kHz_ZZ                  <= FALSE;

    LPM_Activated               <= FALSE;

    if SUPPORT_ISO then
      ISOToggle <= 0;
    end if;

  elsif FsClk'event and (FsClk = '1') then

    Clk1kHz_Z    <= Clk1kHz;
    Clk1kHz_ZZ   <= Clk1kHz_Z;

----------------------------------------------------------
--                       Bus reset                      --
----------------------------------------------------------

    if RG_SetSE0Int then
      ResumeTimer         := 0;
      ResumePending       := FALSE;
      LPM_ResumePending   := FALSE;
      SuspendTimer        := 0;
      DeviceSuspended     <= FALSE;
      Suspend5ms          <= FALSE;
      LPM_Suspend60us     <= FALSE;
    end if;

    if (Clk1kHz_Z and not Clk1kHz_ZZ) then
      if SUPPORT_ISO then
        ISOToggle <= 1 - ISOToggle;
      end if;
    end if;


-------------------------------------------------------------------------------
-- LPM_CHANGE 
-- 1MHz Clock pulse generation. The clock is used for LPM timers implementation.

    Clk1MhzPulse <= FALSE;
    if (LPM_Counter = "1011") then
      LPM_Counter  <= "0000";
      Clk1MhzPulse <= TRUE;
    else
      LPM_Counter <= LPM_Counter + "1";
    end if;

-------------------------------------------------------------------------------

-----------------------------------------------------------
--                 Resume Timers                         --
-----------------------------------------------------------

    -- DOC_BEGIN: Resume Timing
    -- The resume timer controls the generation of a remote
    -- wake up. The remote wake-up can be requested by the
    -- micro-controller.
    --
    -- If remote wake-up is requested then this request is
    -- queued until the bus has been idle for 5 ms.
    -- At that moment, an upstream wake up is generated
    -- for 3 ms. If any bus activity occurs before the 5 ms
    -- of idle bus, the request is discarded.

    TM_SendResume     <= FALSE;
    if (RG_BusActive_S) then
      ResumePending     := FALSE;
      LPM_ResumePending := FALSE;
    end if;

    case SR_STATE is
      when IDLE =>
	ResumeTimer     := 0;
	if MM_Resume then 
	  ResumePending        := TRUE;
        end if;
	if (ResumePending and Suspend5ms) then 
	  SR_State <= SENDING;
	end if;
-------------------------------------------------------------------------------
-- LPM_CHANGE 
-- If system sets the remote wakeup bit then resume is sent from device to host.
-- A resume is kept on hold till the LPM suspend duration is elapsed.
-- Once the LPM suspend duration is elapsed LPM Resume is sent

        if LPM_MM_Resume then
          LPM_ResumePending := TRUE;
        end if;
        if (LPM_ResumePending and LPM_Suspend60us) then 
	  SR_State <= LPM_SENDING;
	end if;
-------------------------------------------------------------------------------

      when SENDING =>
	TM_SendResume <= TRUE;
	if Clk1kHzPulse then
	  if (ResumeTimer = RESUME_TIME) then 
	    SR_State             <= IDLE;
	  end if;
	  ResumeTimer := IncSat(ResumeTimer, RESUME_TIME +1);
	end if;

-------------------------------------------------------------------------------
-- LPM_CHANGE
-- In the LPM_SENDING state a Resume timer is triggered to calculate the 
-- resume time. Once the resume duration as per the LPM is elapsed state 
-- machine goes back to Idle state. After resume of 50 us as per the LPM specs
-- is sent device will wait for activity from the Host side.

      when others => --LPM_SENDING =>
	TM_SendResume <= TRUE;
        if Clk1MHzPulse then
          if (ResumeTimer = LPM_RESUME_TIME) then
	    SR_State <= IDLE;
	  end if;
          ResumeTimer := IncSat(ResumeTimer, LPM_RESUME_TIME +1);
	end if;

    end case;
    -- DOC_END

-----------------------------------------------------------
--                 Suspend Timers                        --
-----------------------------------------------------------

    -- DOC_BEGIN: Awake/Suspend Control and LPM Awake/Suspend control
    -- In case no LPM token has been received, the timers are used
    -- for regular suspend timing
    -- The suspend timer controls the suspend/awake behavior. 
    -- There are 3 states: awake, suspended and an intermediate 
    -- state. A device is awake if there has been bus activity
    -- in the last 3 ms. A device is suspended (the low power
    -- state) when it hasn't seen any traffic for at least 5 ms.
    -- Between 3 and 5 ms there is an intermediate state during
    -- which the device prepares itself to go into the suspended
    -- state

    -- If an LPM token is received, the timers are used for LPM timing
    -- A device comes out of LPM suspend if there is bus activity
    -- A device is suspended when 10us of token retry time has elapsed.
    -- Device stays in LPM suspended state for atleast 50us.   

    -- LPM_HostRetry is from SIE which indicates that LPM Token 
    -- was Acknowledged. LPM_HostRetry will trigger the LPM_SuspendTimer
    -- LPM_HostRetry_Reset is from SIE which indicates that First half of LPM Token
    -- is received. It will also reset the LPM_SuspendTimer.

    -- DeviceSuspended goes high when LPM_SuspendTimer reaches 10us of HOSTRETRY_TIME
    -- LPM_Suspend60us goes high when LPM_SuspendTimer reaches 60us of LPM_SUSPEND_TIME
    -- Any activity on the line or Resume from either host or device would bring the 
    -- LPM_SuspendTimer to its default state.

    -- DOC_END
    if LPM_HostRetry_Reset then
      LPM_Activated   <= TRUE;
      SuspendTimer    := 0;
      DeviceSuspended <= FALSE;
      Suspend5ms      <= FALSE;
      LPM_Suspend60us <= FALSE;
    end if;

    if RG_BusActive_S then
      SuspendTimer    := 0;
      DeviceSuspended <= FALSE;
      Suspend5ms      <= FALSE;
      LPM_Suspend60us <= FALSE;
      LPM_Activated   <= FALSE;  -- Will this work or will the ACK of the LPM already clear this bit ?
    elsif LPM_Activated then
      if Clk1MHzPulse then
        DeviceSuspended <= (SuspendTimer >= HOSTRETRY_TIME);
        LPM_Suspend60us <= (SuspendTimer = LPM_SUSPEND_TIME);
        SuspendTimer    := IncSat(SuspendTimer, LPM_SUSPEND_TIME+1);
      end if;    
    else
      if Clk1kHzPulse then
        DeviceSuspended <= (SuspendTimer >= SUSPEND_TIME);
        Suspend5ms      <= (SuspendTimer = IDLE_BEFORE_RESUME_TIME);
        SuspendTimer    := IncSat(SuspendTimer,IDLE_BEFORE_RESUME_TIME+1);
      end if;
    end if;

    -- DOC_END

-------------------------------------------------------------------------------

-----------------------------------------------------------
--                 ClockOnTimer                          --
-----------------------------------------------------------

    -- DOC_BEGIN: Clock Control
    -- The clock timer controls the minimum time during which
    -- the clock is switched on for devices that switch their
    -- clock off when they are suspended. This timer is reset
    -- whenever the clock goes on, and the clock can only go 
    -- off when this timer reaches its maximum.


    if NeedClock_S or (ClockIsOff_SS and (not ClockIsOff_S)) then
      ClockOnTimer <= 0;
    else
      ClockOnTimer <= IncSat(ClockOnTimer,CLOCK_OFF_DELAY+1);
    end if;

    -- DOC_END

    NeedClock_S <= NeedClock;

    ClockIsOff_SS     <= ClockIsOff_S;
    ClockIsOff_S      <= ClockIsOff;
    RG_BusActive_S    <= RG_BusActive;

  end if;

end process MAIN;

NeedClock_old <= MM_NeedCLock           or -- Clock always on
---------------------------------------
-- BVE : When LPM is received, Suspend5ms is never set. This makes that Needclock is always high during LPM
--	         (not Suspend5ms) or 
	         ((not Suspend5ms) and (not LPM_ACTIVATED)) or 
---------------------------------------
                 RG_BusActive           or -- Bus activity detected
	         PUReset_N = ACTIVE_LOW or -- Power-on reset on-going
                 MM_Resume              or -- SW initiated resume
                 (LPM_Activated and LPM_NeedClock); -- LPM requires clock
		 
-- ECO fix to make sure that VBus is updated when clock is off.		 
NeedClock <= NeedClock_old or
             (VBusDebounced xor VBusAvailable);		 

LPM_NeedClock <= LPM_HIRD_NeedClk            or 
                 LPM_NYET_NeedClk            or
                 LPM_MM_Resume               or -- SW initiated LPM resume
                 (NOT LPM_Suspend60us);

    -- DOC_BEGIN
    -- The clock control block controls the switching of the clock.
    -- It consists of two asynchronous flip flops. Whenever a clock
    -- is needed (NeedClock = TRUE), the first flip flop is set. The
    -- output of this flip flop controls the clock. It is reset
    -- asynchronously when the clock timer reaches its maximum value,
    -- which can only happen if no clock is needed.
    -- The second flip flop is used to reset the clock timer. when the
    -- output of the first flip flop goes low, it is reset 
    -- asynchronously. When the clock restarts, the flip flop is
    -- reset synchronously, and the output of the flip flop is
    -- clocked into a delay line. The rising edge in the delay line
    -- causes the clock timer to be reset

CLOCK_ON: process(PUReset_N,FsClk,NeedClock,async_disable)
begin
  if (PUReset_N = ACTIVE_LOW) or (NeedClock and async_disable = '0') then
    ClockOn <= '1';
  elsif FsClk'event and FsClk = '1' then
    if ClockOnTimer = CLOCK_OFF_DELAY-1 then
      ClockOn <= '0';
    end if;
  end if;
end process CLOCK_ON;

CLOCK_IS_OFF: process(PUReset_N,FsClk,ClockOn,async_disable)
begin
  if (PUReset_N = ACTIVE_LOW) or (ClockOn = '0' and async_disable = '0') then
    ClockIsOff <= FALSE;
  elsif FsClk'event and FsClk = '1' then
    ClockIsOff <= (ClockOn = '0');
  end if;
end process CLOCK_IS_OFF;

    -- DOC_END

TM_ClockOn <= ClockOn;

-------------------------------------------------------------------------------
-- LPM_CHANGE 
-- HIRD value received through LPM token and HIRD value written by the system
-- is compared.
-- HIRD_HW > HIRD_SW LPM_NeedClock signal stays high and clock is kept ON
-- HIRD_HW = HIRD_SW LPM_NeedClock signal stays high and clock is kept ON
-- HIRD_HW < HIRD_SW LPM_NeedClock signal goes low and clock can be disabled

LPM_HIRD_NeedClk <= TRUE when (LPM_HIRD_HW < LPM_HIRD_SW)
                         else FALSE;

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- LPM_CHANGE 
-- LPM_NYET indicates that IN buffer is being accessed or it has data. If 
-- LPM_NYET is true LPM_NeedClock will stay active.

LPM_NYET_NeedClk <= LPM_NYET;  -- Keep the clock ON if IN buffer being accessed

USB_Suspended_N <= conv_active_low(DeviceSuspended);
TM_Suspend      <= DeviceSuspended and not(LPM_Activated);
LPM_TM_Suspend  <= DeviceSuspended and LPM_Activated;

Clk1kHzPulse    <= IsRisingEdge(Clk1kHz_Z, Clk1kHz_ZZ);
USB_FrameClock  <= conv_active_high(Clk1kHz);
TM_1kHzPulse    <= conv_active_high(Clk1kHzPulse);
TM_SOFDetect    <= SOFDetect;
TM_FrameTimer   <= std_logic_vector(to_unsigned(FrameTimer,16));

end RTL;
