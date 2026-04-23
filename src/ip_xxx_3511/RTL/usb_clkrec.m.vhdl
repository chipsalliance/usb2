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
--               File: usb_clkrec.m.vhdl
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
--          $Revision: 1.5 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_clkrec.m.vhdl.rca $
--   
--    Revision: 1.5 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.2 Tue Jun  8 10:08:56 2010 bve
--    Fixed conformal warnings
--   
--    Revision: 1.1 Fri May 21 08:55:00 2010 aes
--    First check in.
--   
--    Revision: 1.2 Tue May 11 15:13:29 2010 bve
--    fix for resistor ECN
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

entity usb_clkrec is

  port  (
         ---  Input from Hub or Upstream Port  ---
         HB_UsbDifBit:      in  one_bit;   --  Differential Usb input
         HB_UsbLineBits:    in  two_bits;  --  Single ended Usb inputs
    
         ---  Output to SIE  ---
         CR_UsbLineBits:    out two_bits;  --  Dplus and Dmin for SIE
         CR_VM_negedge :    out one_bit;   --  VM indication on 48MHz negedge clock
         CR_jk_transition:  out one_bit;
    
         ---  For Debugging  ---
         CR_DebugRecDataP:  out one_bit;   --  Dplus for debugging
         CR_DebugRecDataN:  out one_bit;   --  Dmin for debugging
    
         ---  Clock Outputs  ---
         Clk12MHz_O:        out one_bit;   --  Recovered clock
         Clk12MHzRef_O:     out one_bit;   --  Reference clock
    
         ---  Enable Signal  ---
         SIE_CREnable:      in  boolean;   --  Enable clock recovery
    
         ---  Suspend Input  ---
         TM_Suspend:        in  boolean;   --  Suspend
         LPM_TM_Suspend:    in  boolean;   --  LPM_Suspend
         lowpurenable:      out boolean;
    
         ---  System  ---
         Clk48MHz:          in  one_bit;   --  48 MHz clock
         Clk48MHz_neg:      in  one_bit;   --  48 MHz clock
         Reset48MHz_N:      in  one_bit;   --  Reset for 48 MHz clock
         PU_Reset_N:        in  one_bit   --  Power On Reset
    );

end usb_clkrec;

architecture RTL of usb_clkrec is

signal UsbLineBits: two_bits;
signal SyncCREN: booleans(2 downto 0);
signal SyncD, SyncP, SyncN: two_bits;
signal SyncSuspend: booleans(1 downto 0);
signal DelayLineD, DelayLineP, DelayLineN: six_bits; 
signal DelayLineSample: five_bits;
signal Count: integer range 0 to 5;
signal RefCount: integer range 0 to 3;
signal lowpurenable_cnt: integer range 0 to 28;
signal lowpurenable_cnt_reached: boolean;
signal Reduce, Extend, Rephase: boolean; 
signal NegEdgeTime, EvalTime, PosEdgeTime, ExtendedPosEdgeTime: boolean;
signal RxUsbLogValue : T_UsbLog_enum;
signal RxUsbLogValue_Z1  : T_UsbLog_enum; -- previous value
signal lowpurenable_status: boolean;

signal SyncN_negedge	   : two_bits;
signal VM_negedge	   : one_bit;
signal DelayLineVM_negedge : six_bits;

signal jk_transition_pos   : std_logic;
signal jk_transition_neg   : std_logic;

begin

lowpurenable  <= lowpurenable_status;

RECOVERY_PROCESS: process (Clk48MHz, Reset48MHz_N)

  begin

    if (Reset48MHz_N = ACTIVE_LOW) then

      SyncCREN <= (others => FALSE);
      SyncD <= (others => LOW); 
      SyncP <= (others => LOW); 
      SyncN <= (others => LOW); 
      SyncSuspend <= (others => FALSE);
      DelayLineD <= (others => HIGH);
      DelayLineP <= (others => HIGH);
      DelayLineN <= (others => LOW);
      DelayLineSample <= (others => HIGH);
      Count <= 0;
      RefCount <= 0;
      lowpurenable_cnt <= 0;
      lowpurenable_cnt_reached <= FALSE;
      Reduce <= FALSE;
      Extend <= FALSE;
      RePhase <= FALSE;
      NegEdgeTime <= FALSE;
      EvalTime <= FALSE;
      PosEdgeTime <= FALSE;
      ExtendedPosEdgeTime <= FALSE;
      Clk12MHz_O <= LOW; 
      Clk12MHzRef_O <= LOW; 
      UsbLineBits <= (LOW, LOW); 

      RxUsbLogValue    <= USB_LOG_J;
      RxUsbLogValue_Z1 <= USB_LOG_J;
      lowpurenable_status <= TRUE;  

    elsif Clk48MHz'event and (Clk48MHz = '1') then

      EvalTime <= FALSE;

      -- DOC_BEGIN: Synchronizers and Delay Lines
      -- Warning: this implementation is biased towards high speed
      -- function clock recovery 
      -- A number of signals influencing the clock recovery come from
      -- the recovered clock domain. This causes problems with a synchronous
      -- reset strategy as in USBALB. To solve this generally, we will force
      -- these signals asynchronously to 0 during reset
      -- This is not a conceptual problem as these signals are treated
      -- in this module as asynchronous signals anyway: in other words,
      -- they are synchronized to the 48MHz clock before being used

      -- Synchronizer for Clock Recovery Enable from SIE module
      SyncCREN <= (SyncCREN(1), SyncCREN(0),
                   (SIE_CREnable and (PU_Reset_N = INACTIVE_HIGH)));

      -- Synchronizers for differential and single ended inputs
      SyncD <= (SyncD(0) , (HB_USBDifBit and PU_Reset_N)); 
      SyncP <= (SyncP(0) , (HB_USBLineBits(1) and PU_Reset_N)); 
      SyncN <= (SyncN(0) , (HB_USBLineBits(0) and PU_Reset_N)); 

      -- Synchronizer for Suspend from the Timers module
      SyncSuspend <= (SyncSuspend(0),
                      ((TM_Suspend OR LPM_TM_Suspend) and (PU_Reset_N = INACTIVE_HIGH))); 

      -- Delay Line for the differential and single ended inputs
      DelayLineD <= DelayLineD(DelayLineD'high-1 downto 0) & SyncD(1); 
      DelayLineP <= DelayLineP(DelayLineP'high-1 downto 0) & SyncP(1); 
      DelayLineN <= DelayLineN(DelayLineN'high-1 downto 0) & SyncN(1); 
      -- DOC_END

      -- DOC_BEGIN: No Rephase during SE0
      -- Avoid rephase during SE0, during SE0 the RCV input is not well
      -- defined and can toggle causing rephase. This is not a problem,
      -- but is unwanted. It is solved by filling the DelayLineD that is
      -- used for rephase with the last value before SE0 was detected.
      -- This is done as long as SE0 is detected. SE0 is detected by
      -- looking at three values in the delay line of the single ended
      -- receivers.
      if (SyncP(1) = LOW)      and (SyncN(1) = LOW) and
         (DelayLineP(0) = LOW) and (DelayLineN(0) = LOW) and
         (DelayLineP(1) = LOW) and (DelayLineN(1) = LOW) then
        DelayLineD <= (others => DelayLineD(DelayLineD'high-1));
      end if;  
      -- DOC_END

      -- DOC_BEGIN: Generating the Recovered Clock
      -- The recovered clock is generated using a counter Count. The
      -- phase of this clock can be adjusted. When there is no
      -- activity on the Usb Bus, the recovered clock is free running
      -- on 12 MHz. When there is activity, the clock has to be
      -- rephased so that the rising edge is in the middle of the
      -- bit on the Usb Bus. Changing the phase is done by changing
      -- the way the counter Count is reset to 0. The counter can
      -- be reset to 0 at different times defined by the signals Reduce,
      -- Extend and Rephase.

      NegEdgeTime <= ((Count = 1) and Reduce) or
                     ((Count = 2) and (not (Reduce or Extend or Rephase))) or
                     ((Count = 3) and Extend) or
                     ((Count = 4) and Rephase);

      -- Reset the counter and take a sample of the delay line.
      -- Evaluation of this sample is used for rephasing (EvalTime).
      -- Recovered clock becomes LOW.

      if NegEdgeTime then
        Clk12MHz_O <= LOW; 
        Count <= 0;
        Reduce <= FALSE;
        Extend <= FALSE;
        Rephase <= FALSE;
        DelayLineSample <= DelayLineD(4 downto 0); 
        EvalTime <= TRUE;
      else
        Count <= Count + 1;
      end if;

      -- The following code generates the HIGH period of the recovered
      -- clock. If there is a rephase, defined by Rephase, the clock
      -- stays high for one extra 48 MHz period. If this was not done,
      -- the clock would only stay HIGH for one 48 MHz period. This
      -- means an increase in frequency which is not allowed.

      PosEdgeTime <= (Count = 0);
      ExtendedPosEdgeTime <= (Count = 1);

      if PosEdgeTime and not Rephase then
        Clk12MHz_O <= HIGH; 
      end if;

      if ExtendedPosEdgeTime and Rephase then
        Clk12MHz_O <= HIGH; 
      end if;
      -- DOC_END

      -- DOC_BEGIN: Evaluation Delay Line Sample
      -- Reset delay line sample (on 'J') while not SyncCREN(1)  
      -- The goal is to prevent packets that are sent out to
      -- influence the clock recovery 

      if not SyncCREN(1) then
        DelayLineSample <= (others => HIGH);
      end if;

      -- The delay line sample is evaluated to decide what kind of
      -- rephasing is needed.
      -- Qualify eval time with SyncCREN(2) (consistent with reset above) 

      if EvalTime and SyncCREN(2) then 
        if    ( DelayLineSample(0) /= DelayLineSample(1) ) then
          Extend <= TRUE; 
        elsif ( DelayLineSample(2) /= DelayLineSample(3) ) then
          Reduce <= TRUE; 
        elsif ( DelayLineSample(3) /= DelayLineSample(4) ) then 
          -- Out-of-phase error condition 
          Rephase <= TRUE; 
        end if;
      end if;
      -- DOC_END

      -- DOC_BEGIN: Generate Dplus and Dmin for SIE
      -- Generation of clean DP and DM from incoming DP, DM and RCV
      -- in Suspend, take bus signals from single-ended receivers
      -- because differential receiver may be turned of
      
      -- BVE addition : filter out a single cycle SE0 pulse to make sure that there is no
      --                false EOP detection in the SIE module

      if (SyncSuspend(1)) then
        UsbLineBits <= (DelayLineP(5), DelayLineN(5)); 
      elsif (two_bits'(DelayLineP(5), DelayLineN(5)) = two_bits'("00")) and 
            ((UsbLineBits = (LOW, LOW)) or
	     two_bits'(DelayLineP(4), DelayLineN(4)) = two_bits'("00")) then
        UsbLineBits <= (LOW, LOW); 
      else
        UsbLineBits <= (DelayLineD(5), not DelayLineD(5));
      end if;
      -- DOC_END

      -- DOC_BEGIN: Reference Clock
      -- Free running 12 MHz reference clock.

      RefCount <= (RefCount + 1) mod 4;
      Clk12MHzRef_O <= conv_active_high(RefCount >= 2);       
      -- DOC_END

  ------------------------------------------------------------------------
  -- lowpurenable and fstermenable generation as SW2 and SW1 respectively
  ------------------------------------------------------------------------
  -- From resistor_ecn.pdf
  --      Bus State    | SW1=fstermenable | SW2=lowpurenable
  ---     ------------------------------------------------
  --      Idle         | Closed           | Closed
  --      Receiving    | Closed           | Open     
  --      Transmitting | X                | X
  --      Vbus Off     | Open             | X
  ---     -------------------------------------------------
  -- DOC_BEGIN: Detection of J to K Transition in the recovered data.
  -- At reset lowpurenable is TRUE
  -- At J to K transition in the recovered data lowpurenable is FALSE
  -- When SE0 is detected on USB lines for 0.5bit times lowpurenable is TRUE
      if SIE_CREnable then
        RxUsbLogValue <= UsbDif2Log(HB_UsbLineBits, USB_FULL_SPEED);
      else
        -- mask incoming bits during sending
        RxUsbLogValue <= USB_LOG_J;
      end if;  
      RxUsbLogValue_Z1  <= RxUsbLogValue;

      if (lowpurenable_cnt_reached) then
        lowpurenable_cnt <= 0;
      elsif((RxUsbLogValue = USB_LOG_J)) then
        lowpurenable_cnt <= lowpurenable_cnt + 1;
      else
        lowpurenable_cnt <= 0;
      end if;

      if (lowpurenable_cnt=27) then
        lowpurenable_cnt_reached <= TRUE;
      else
        lowpurenable_cnt_reached <= FALSE;
      end if;

      if((RxUsbLogValue = USB_LOG_K) and (RxUsbLogValue_Z1 = USB_LOG_J)) then
        lowpurenable_status <= FALSE;
      elsif (((RxUsbLogValue = USB_LOG_SE0) and 
              (RxUsbLogValue_Z1 = USB_LOG_SE0)) or
             (lowpurenable_cnt_reached)) then
        lowpurenable_status <= TRUE;  
      end if;
    end if;

  end process RECOVERY_PROCESS;

  -- recovered output data
  CR_UsbLineBits <= UsbLineBits;

  -- recovered output data for debug purposes 
  CR_DebugRecDataP <= UsbLineBits(1);
  CR_DebugRecDataN <= UsbLineBits(0);

---------------------------------------------
-- Logic added for FRO trimming indication
---------------------------------------------
RECOVERY_NEGEDGE_PROCESS: process (Clk48MHz_neg, Reset48MHz_N)

  begin

    if (Reset48MHz_N = ACTIVE_LOW) then
      SyncN_negedge       <= (others => LOW); 
      
      VM_negedge          <= LOW;
      
      DelayLineVM_negedge <= (others => LOW);
      
      jk_transition_neg    <= '0';
      
    elsif Clk48MHz_neg'event and (Clk48MHz_neg = '1') then
    
      jk_transition_neg    <= jk_transition_pos;

      -- Synchronizers for single ended inputs
      SyncN_negedge <= (SyncN_negedge(0) , (HB_USBLineBits(0) and PU_Reset_N)); 

      -- Delay Line for the differential and single ended inputs
      DelayLineVM_negedge  <= DelayLineVM_negedge(DelayLineVM_negedge'high-1 downto 0) & SyncN_negedge(1);

      if (jk_transition_neg = '0') then
        VM_negedge         <= DelayLineVM_negedge(5);
      end if;
    end if;
  end process RECOVERY_NEGEDGE_PROCESS;

RECOVERY_POSEDGE_PROCESS: process (Clk48MHz, Reset48MHz_N)

  begin
    if (Reset48MHz_N = ACTIVE_LOW) then
      jk_transition_pos  <= '0';
      
    elsif Clk48MHz'event and (Clk48MHz = '1') then
    
      if DelayLineN(5) = '0' and DelayLineN(4) = '1' then
        jk_transition_pos <= '1';
      elsif DelayLineN(5) = '1' and DelayLineN(4) = '0' then
        jk_transition_pos <= '0';
      end if;
      
    end if;
  end process RECOVERY_POSEDGE_PROCESS;

CR_VM_negedge    <= VM_negedge;
CR_jk_transition <= jk_transition_pos;

end RTL;
