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
--               File: usb_sie.m.vhdl
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
--   $Log: usb_sie.m.vhdl.rca $
--   
--    Revision: 1.5 Fri Apr 29 12:30:26 2011 beq03099
--    added buffer underrun indication
--   
--    Revision: 1.4 Wed Feb 16 11:33:47 2011 beq03099
--    Fixed LPM problem
--    No lpm_suspend interrupt was generated before
--   
--    Revision: 1.3 Mon Jul 12 15:01:50 2010 beq03099
--    modified USB_Tx lines to have DP/DM/FSE0 directly from FF to padcell
--   
--    Revision: 1.2 Tue Jun  8 10:08:56 2010 bve
--    Fixed conformal warnings
--   
--    Revision: 1.1 Thu Apr  1 09:49:54 2010 bve
--    Initial version
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

entity usb_sie is
  port  (
          ---------- To USB bus -------------------
          CR_UsbLineBits:          in  two_bits;      -- Received data
	  CR_VM_negedge: 	   in  one_bit;
          CR_jk_transition :       in  one_bit;
--          SIE_TxLogValue:          out T_UsbLog_enum; -- Data to Send
          SIE_UsbEnable_N:         out one_bit;       -- Transmit Enable

          ------------- Data to/from MM ---------------
          SIE_RxPid:               out T_Pid_enum;    -- PID value
          SIE_RxPidRdy:            out boolean;       -- PID valid
          SIE_RxSubPid:            out T_SubPid_enum; -- SubPid of LPM Rx packet
          SIE_RxData:              out S_UsbWord_bits;-- Received Data
          SIE_RxDataRdy:           out boolean;       -- Received Data valid
          SIE_LPM_HIRDRdy:         out boolean;        
          SIE_LPM_RWRdy:           out boolean;
          
          SIE_SOFByte1:            out boolean; --
                                   -- Received Data is 1st byte of frame number
          SIE_SOFByte2:            out boolean; --
                                   -- Received Data is 2nd byte of frame number

          SIE_RxEOP:               out boolean;     -- Received End of Packet

          MM_TxData1Pid:           in  boolean; --
                                   -- Send data packet with DATA1 PID
          MM_TxData:               in  S_UsbWord_bits;-- Data to Transmit
          MM_TxDataRdy:            in  boolean;     -- Data to Transmit valid
          SIE_TxDataAck:           out boolean;     -- Data to Transmit fetched
          MM_all_bytes_sent:       in  boolean;

          -------------- Error Flags -----------------
          SIE_RxErrorType:         out T_PACKET_ERROR_enum;-- Error Type
          SIE_RxError:             out boolean;            -- An error occurred

          ----------- Transaction Status -------------
          SIE_StartEndpSearch:     out boolean; -- Start Address decoding
          MM_EndpSearchReady:      in  boolean; -- Address Decoding ready
          MM_EndpSearchSelected:   in  boolean; -- Device selected
          MM_Accepted:             in  boolean; --
                                   -- Selected endpoint can handle request
          MM_Stalled:              in  boolean; -- Selected endpoint is Stalled
          MM_LPMSupported:         in  boolean; -- LPM Stalled response 
          MM_LPMNYET:              in  boolean; -- LPM NYET response
          MM_ISO:                  in  boolean; --
                                   -- Selected endpoint is isochronous

          ------------- Control Signals --------------
          SIE_RxSOF:               out boolean; -- Frame Timer synchronisation
          SIE_CREnable:            out boolean; -- Clock Recovery enable
          TM_SendResume:           in  boolean; -- Remote wake up control
          LPM_HostRetry_Reset:     out boolean; -- Host Token Retry timer reset
          LPM_LINK_STATE_EN:       in  boolean; 
                                   -- LPM Extended token Link state enable

          --------------- System --------------------
          FsClk:                   in  one_bit;       -- Bit Clock
          Reset_N:                 in  one_bit;        -- Global Reset
          UP_DP:                   out one_bit;
          UP_DM:                   out one_bit;
          UP_FSE0:                 out one_bit;

          --------------- Additional signals to measure length of token --------------------
          Clk48MHz:          in  one_bit;   --  48 MHz clock
          Reset48MHz_N:      in  one_bit;   --  Reset for 48 MHz clock
	  Token_Length:      out std_logic_vector(6 downto 0);
          adjust_req:        out std_logic;
          adjust_eof:        out std_logic;
          adjust_bias:       out std_logic_vector(2 downto 0);
	  adjust_enable:     in  std_logic

          );
end usb_sie;

architecture RTL of usb_sie is

  signal RxUsbLogValue   : T_UsbLog_enum;
  signal RxUsbLogValue_Z1: T_UsbLog_enum; -- previous value
  signal RxUsbLogValue_Z2: T_UsbLog_enum; -- previous value
  signal RxUsbLogValue_Z3: T_UsbLog_enum; -- previous value
  signal TxUsbLogValue   : T_UsbLog_enum;
--  signal TxUsbLogValue_Z : T_UsbLog_enum;
  signal TxUsbEnable     : boolean;
   
  signal RxError         : boolean;
  signal RxErrorType     : T_PACKET_ERROR_enum;
  signal RxPid           : T_Pid_enum;
  signal SubPid          : T_SubPid_enum;

  signal TimeOutStarted  : boolean;
  type T_PMState_enum is (PM_WAIT_FOR_REQUEST,
                          PM_PROCESS_LPM_TOKEN,
                          PM_SEND_LPM_HANDSHAKE,
                          PM_PROCESS_IN,
                          PM_PROCESS_OUT_SETUP,
                          PM_RECEIVE_HANDSHAKE,
                          PM_SEND_HANDSHAKE);
  signal PMState: T_PMState_enum;
  signal HostRetry_Reset : boolean;
  
  signal Token_Length_int : integer range 0 to 127;
  signal increment_token_counter : std_logic;
  signal increment_token_counter_s : std_logic;
  signal update_token_counter    : std_logic;
  signal reset_token_counter     : std_logic;
  signal reset_token_counter_d   : std_logic;
  
  signal adjust_PID, adjust_PID_s, adjust_PID_ss : std_logic;
  signal adjust_EOP, adjust_EOP_s, adjust_EOP_ss : std_logic;
  
  signal negedge_early_delay : std_logic_vector(5 downto 0);
  signal sync_negedge_early  : std_logic;
  signal eop_negedge_early   : std_logic;
  signal start_negedge_early : std_logic;
  signal jk_transition_del   : std_logic_vector(2 downto 0);

--  signal log_Token_Length_int : integer range 0 to 255;
--  signal log_pid_token_length : integer range 0 to 255;
--  signal log_eop_token_length : integer range 0 to 255;

begin

  -- Convert the TX outgoing logic values to bits
--  SIE_TxLogValue <= TxUsbLogValue when TxUsbEnable else
--                    TxUsbLogValue_Z;

  -- Enables for upstream Tx and CLKREC
  SIE_UsbEnable_N <= conv_active_low(TxUsbEnable);

  SIE_CREnable    <= not TxUsbEnable;

  -- Connection between internal signals and ports
  SIE_RxError     <= RxError;
  SIE_RxErrorType <= RxErrorType;
  SIE_RxPid       <= RxPid;
  SIE_RxSubPid    <= SubPid;

--------------------------------------------------------------
-- process MAIN (FsClk, Reset_N)
--------------------------------------------------------------
MAIN: process(FsClk , Reset_N)
  
  variable ErrorType: T_PACKET_ERROR_enum;
  variable Error:     boolean;

  variable TimeOutCnt:     integer range 0 to DEVICE_TIMEOUT +7;
  variable TimeOut:        boolean;
  variable StartTimeOut:   boolean;
  variable StopTimeOut:    boolean;

  variable PidType:        T_Pid_enum;
-- SubPidType is declared for LPM SubPid detection
  variable SubPidType:     T_SubPid_enum;
  variable PacketType:     T_Packet_enum;  --never read/used?
  variable LPMPacketType:  T_LPM_Packet_enum; --never read/used? 
  variable Ready:          boolean;
  variable SaveBit:        one_bit;

  variable Position:       S_USBWORD_WIDTH_range;
  variable BitValue:       one_bit;             -- Bit to be processed
  variable BitStuffCnt:    S_BitStuff_range;    -- length bitstuff sequence
  variable StuffedBit:     boolean;             -- Flags stuffed bits
  variable NewBitStuffCnt: S_BitStuff_range;    -- New BitStuffCnt (de)stuffing

  variable Crc5:           five_bits;    -- CRC5  for tokens
  variable Crc16:          sixteen_bits; -- CRC16 for data
  variable Crc16_tmp :     S_UsbWord_bits;

  variable Crc5ok:         boolean;      -- CRC5  of token was ok
  variable Crc16ok:        boolean;      -- CRC16 of data was ok
  variable InitCrc:        boolean;      -- Initialize the Crc5/Crc16.
  variable EvalCrc:        boolean;      -- Evaluate the Crc5/Crc16

  variable EndOfPacket:    boolean;
  variable SyncDetected:   boolean;
  variable SE0Detected:    boolean;
  variable BitstuffError:  boolean;
  variable DataWord:       S_UsbWord_bits;
  variable PidReady:       boolean;
  variable PacketSent:     boolean;

  -------------------------------------------------------------------------
  --                           Error Procedure                           --
  -------------------------------------------------------------------------

  procedure SetError(AnError: T_Packet_Error_enum) is
  begin
    Error := TRUE;
    ErrorType := AnError;
  end SetError;

  -------------------------------------------------------------------------
  --                     Low Level Tx/Rx Procedures                      --
  -------------------------------------------------------------------------
  -- Procedure to send one byte

  -- DOC_BEGIN: Procedure for sending one byte
  -- This procedure is called by the main state machine every cycle
  -- when the SIE is sending data. This procedure sends the data
  -- provided in the DataWord variable. When this byte is sent 
  -- completely, this is reported to the main state machine by 
  -- setting the Ready flag. The procedure takes care of bit stuffing
  -- and NRZI encoding.

  procedure SendWord is
  begin   
    BitValue := DataWord(Position);
    Stuff(BitValue, BitStuffCnt,
      BitStuffError, StuffedBit, NewBitStuffCnt);
    BitStuffCnt := NewBitStuffCnt;
    if (StuffedBit) then
      case EncodeNRZI(TxUsbLogValue, (not BITSTUFF_VALUE)) is
        when USB_LOG_J   =>
          UP_DP         <= '1';
          UP_DM         <= '0';
          UP_FSE0       <= '0';  
        when USB_LOG_K   =>
          UP_DP         <= '0';
          UP_DM         <= '1';
          UP_FSE0       <= '0';  
        when USB_LOG_SE0 =>
          UP_DP         <= '0';
          UP_DM         <= '0';
          UP_FSE0       <= '1';  
        when others      =>
          UP_DP         <= '1';
          UP_DM         <= '0';
          UP_FSE0       <= '0';  
      end case;
      TxUsbLogValue <= EncodeNRZI(TxUsbLogValue, (not BITSTUFF_VALUE));
      TxUsbEnable   <= TRUE;
      -- A stuffed bit should never trigger CRC evaluation
      EvalCrc := FALSE;
    else  
      case EncodeNRZI(TxUsbLogValue, BitValue) is
        when USB_LOG_J   =>
          UP_DP         <= '1';
          UP_DM         <= '0';
          UP_FSE0       <= '0';  
        when USB_LOG_K   =>
          UP_DP         <= '0';
          UP_DM         <= '1';
          UP_FSE0       <= '0';  
        when USB_LOG_SE0 =>
          UP_DP         <= '0';
          UP_DM         <= '0';
          UP_FSE0       <= '1';  
        when others      =>
          UP_DP         <= '1';
          UP_DM         <= '0';
          UP_FSE0       <= '0';  
      end case;
      TxUsbLogValue <= EncodeNRZI(TxUsbLogValue, BitValue);
      TxUsbEnable <= TRUE;
      if (IsAtMaxValue(Position, USBWORD_WIDTH)) then
        Position := 0;
        Ready := TRUE;
      else
        Position := Position + 1;
      end if;
    end if;
  end SendWord;

  -- DOC_END

  -- Procedure for sending an End of Packet
  -- DOC_BEGIN: Procedure for sending End of Packet
  -- This procedure is called by the main state machine every cycle
  -- when the SIE is sending an End of Packet. When the End of Packet 
  -- is sent completely, this is reported to the main state machine by 
  -- setting the Ready flag. The procedure also takes care of bit stuffing
  -- and NRZI encoding of the last data bit.

  procedure SendEOP is
  begin
    -- Needed to stuff the last bit before the SE0
    BitValue := DataWord(Position);
    Stuff(BitValue, BitStuffCnt,
      BitStuffError, StuffedBit, NewBitStuffCnt);
    BitStuffCnt := 0; -- reset bit stuff count during SE0
    if (StuffedBit) then
      case EncodeNRZI(TxUsbLogValue, (not BITSTUFF_VALUE)) is
        when USB_LOG_J   =>
          UP_DP         <= '1';
          UP_DM         <= '0';
          UP_FSE0       <= '0';  
        when USB_LOG_K   =>
          UP_DP         <= '0';
          UP_DM         <= '1';
          UP_FSE0       <= '0';  
        when USB_LOG_SE0 =>
          UP_DP         <= '0';
          UP_DM         <= '0';
          UP_FSE0       <= '1';  
        when others      =>
          UP_DP         <= '1';
          UP_DM         <= '0';
          UP_FSE0       <= '0';  
      end case;
      TxUsbLogValue <= EncodeNRZI(TxUsbLogValue, (not BITSTUFF_VALUE));
      TxUsbEnable   <= TRUE;
      -- A stuffed bit should never trigger CRC evaluation
      EvalCrc := FALSE;
    else  
      -- Send SE0   
      if (Position < EOP_MAX_SE0) then
        TxUsbLogValue <= USB_LOG_SE0;
        UP_DP         <= '0';
        UP_DM         <= '0';
        UP_FSE0       <= '1';
        TxUsbEnable   <= TRUE;
        Position := Position + 1;
      else 
      -- Send J
        TxUsbLogValue <= USB_LOG_J;
        UP_DP         <= '1';
        UP_DM         <= '0';
        UP_FSE0       <= '0';
        TxUsbEnable <= TRUE;
        Position := 0;
        Ready := TRUE;
        PacketSent := TRUE;
      end if;
    end if;
  end SendEOP;

  -- DOC_END

  -- Procedure for receiving one byte
  -- DOC_BEGIN: Procedure to receive data
  -- This procedure is called by the main state machine while the SIE
  -- is receiving data. When a complete byte or an SE0 are received,
  -- this is indicated to the main state machine by setting the Ready
  -- flag. The received data are stored in the DataWord variable. This
  -- procedure takes care of NRZI decoding and destuffing.
  procedure ReceiveWord is
  begin  
    BitValue := DecodeNRZI(RxUsbLogValue_Z1, RxUsbLogValue);
    DeStuff(BitValue, BitStuffCnt, BitStuffError, StuffedBit, NewBitStuffCnt);
    BitStuffCnt := NewBitStuffCnt;
    if (StuffedBit) then
      -- a stuffed bit should never be allowed to trigger
      -- a CRC evaluation
      EvalCrc := FALSE;
    else
      DataWord(Position) := BitValue;
      if (BitStuffError) then
        SetError(ERROR_BITSTUFF_ERROR);
        Ready := TRUE;
      elsif SE0Detected then
        EvalCrc := FALSE;
        -- 2 dribble bits are allowed: on position 0 and 1
        if Position > 1 then
          SetError(ERROR_TR_EOP);
        end if;
        Position := 1;
        Ready := TRUE;
      else 
        if (IsAtMaxValue(Position, USBWORD_WIDTH)) then
          Position := 0;
          Ready := TRUE;
        else
          Position := Position + 1;
        end if;
      end if;
    end if;
  end ReceiveWord;

  -- DOC_END

  -------------------------------------------------------------------------
  --                     Rx Procedures                                   --
  -------------------------------------------------------------------------

  type T_RxTxState_enum is (SOP,
                            PID,
                            ADDR_ONE,
                            ADDR_TWO,
                            DATA,
                            CRC1,
                            CRC2,
                            EOP);
  variable RxTxState: T_RxTxState_enum;

  -- Procedure for Receiving a token
  -- DOC_BEGIN: Procedure for receiving a token
  -- This procedure takes care of receiving a complete token. 
  -- In the Start of Packet (SOF) state, it waits for the end of a
  -- sync pattern. When this is received, the Packet Identifier (PID)
  -- state is entered, where the packet PID is received using the 
  -- ReceiveWord procedure. This state also takes care of SOF's and 
  -- PRE PID's. When the PID is received, the device and endpoint
  -- addresses are received in the ADDR_ONE and ADDR_TWO states.
  -- In the EOP state, and end of packet should come in after at most
  -- 2 dribble bits. At that moment the 5 bit CRC is evaluated.

-------------------------------------------------------------------------------       
-- LPM_CHANGE
-- PID state will also decode the LPM PID through CheckPidPacket function.
-- ADDR_ONE state could receive LPM token. The byte received is sent to 
-- SIEINTERFACE for Device Address decoding.
-- ADDR_TWO state would send, received byte to SIEINTERFACE for EP decoding 
-- EOP state will stop the reception.
-------------------------------------------------------------------------------

  procedure ReceiveToken is
  begin
    case RxTxState is
      when SOP =>
        if SyncDetected then
          StopTimeOut := TRUE;
          BitstuffCnt := 0;
          Error := FALSE; -- clear possible previous error
          RxTxState := PID;
          InitCrc := TRUE;
        end if;
      when PID =>
        ReceiveWord;
        if SE0Detected then
          SetError(ERROR_TR_EOP);
        end if;
        if Ready then
          if (not Error) then
            CheckPidPacket(DataWord, PACKET_TOKEN,
                           PidType, PacketType, Error, ErrorType);
          end if;
          if (not Error) then 
            if (MAX_DEVICE_SPEED = USB_FULL_SPEED) and PidType = PID_SOF then
              -- SIE_RxSOF is reset in the EOP state -> long pulse
              -- (needed to sample in the 12MHz reference domain)
              SIE_RxSOF <= TRUE;
            end if;
            PidReady := TRUE;
            RxTxState := ADDR_ONE;
            if (MAX_DEVICE_SPEED = USB_FULL_SPEED) and PidType = PID_PRE then
              -- Wait for next packet
              RxTxState := SOP; -- otherwise bitstuff errors occur
            end if;
          end if;
        end if;
      when ADDR_ONE =>
        EvalCrc := TRUE;
        ReceiveWord;
        if SE0Detected then
          SetError(ERROR_TR_EOP);
        end if;
        if Ready  and (not Error) then
          SIE_RxData <= DataWord;
          -- Last bit of first byte is the first bit of the endpoint number
          SaveBit := DataWord(7);  -- LSB of endpoint address
          RxTxState := ADDR_TWO;
          -- USB Address is ready -> start decoding
          if PidType = PID_IN or PidType = PID_OUT or PidType = PID_SETUP or
             PidType = PID_LPM then
            SIE_StartEndpSearch <= TRUE;
          -- Pass first Frame Number byte
          elsif (MAX_DEVICE_SPEED = USB_FULL_SPEED) and PidType = PID_SOF then
            SIE_SOFByte1 <= TRUE;
          end if;
        end if;
      when ADDR_TWO =>
        EvalCrc := TRUE;
        ReceiveWord;
        if SE0Detected then
          SetError(ERROR_TR_EOP);
        end if;
        if Ready and (not Error) then
          SIE_RxData <= DataWord;
          -- Pass second Frame Number byte
          if (MAX_DEVICE_SPEED = USB_FULL_SPEED) and PidType = PID_SOF then
            SIE_SOFByte2 <= TRUE;
          end if;
          RxTxState  := EOP;
        end if;
        -- Endpoint Number is ready when the first 3 bits are received.
        -- There is no time enough to wait until the end of the byte before
        -- passing it to the MM
        if (Position = 3) and (not Error) then       -- Endpoint Complete
          SIE_RxData <= "0000" & DataWord(2 downto 0) & SaveBit;
          SIE_RxDataRdy <= TRUE;
        end if;
      when others => -- EOP
        if EndOfPacket then
          RxTxState := SOP;
          -- end RxSOF pulse
          if (MAX_DEVICE_SPEED = USB_FULL_SPEED) then
            SIE_RxSOF <= FALSE;
          end if;
          if (not CRC5ok) then
            SetError(ERROR_TOKEN_CRC);
          end if;
        else 
          ReceiveWord;
          -- 2 dribble bits allowed, at position 0 and 1
          if Position >1 then
            SetError(ERROR_TR_EOP);
          end if;
        end if;
    end case;
  end ReceiveToken;

  -- DOC_END

-------------------------------------------------------------------------------       
-- LPM_CHANGE
  -- Procedure for Receiving a LPM extended token
  -- DOC_BEGIN: Procedure for receiving a LPM extended token
  -- This procedure takes care of receiving a second part
  -- of the LPM token (Extended part). 
  -- In the Start of Packet (SOP) state, it waits for the end of a
  -- sync pattern. When this is received, the PID (LPM SubPID)
  -- state is entered, where the LPM SubPID is received using the 
  -- ReceiveWord procedure.
  -- When the PID is received, the HIRD and bRemoteWake values
  -- are received in the ADDR_ONE (ATTR=Attribute) and ADDR_TWO states.
  -- In the EOP state, an end of packet should come in after at most
  -- 2 dribble bits. At that moment the 5 bit CRC is evaluated.
-------------------------------------------------------------------------------

  procedure ReceiveLPMToken is
  begin
    case RxTxState is
      when SOP =>
        if (TimeOut) then
          -- Packet not received before timeout
          StopTimeOut := TRUE;
          SetError(ERROR_TIMEOUT);
          TimeOut := FALSE;
        elsif SyncDetected then
          StopTimeOut := TRUE;
          BitstuffCnt := 0;
          Error := FALSE; -- clear possible previous error
          RxTxState := PID;
          InitCrc := TRUE;
        end if;
      when PID =>
        ReceiveWord;
        if SE0Detected then
          SetError(ERROR_TR_EOP);
        end if;
        if Ready then
          if (not Error) then
            CheckSubPidPacket(DataWord, PACKET_LPM_TOKEN ,
                              SubPidType, LPMPacketType, Error, ErrorType);
          end if;
          if (not Error) then 
            RxTxState := ADDR_ONE;
          else
          -- Wait for next packet
            RxTxState := SOP; -- otherwise bitstuff errors occur
          end if;
        end if;
      when ADDR_ONE =>
        EvalCrc := TRUE;
        ReceiveWord;
        if SE0Detected then
          SetError(ERROR_TR_EOP);
        end if;
        if Ready  and (not Error) then
          SIE_RxData <= DataWord; -- Bits 7:4 indicates the HIRD value
          SIE_LPM_HIRDRdy <= TRUE;
          RxTxState := ADDR_TWO;
        end if;
      when ADDR_TWO =>
        EvalCrc := TRUE;
        ReceiveWord;
        if SE0Detected then
          SetError(ERROR_TR_EOP);
        end if;
        if Ready and (not Error) then
          SIE_RxData <= DataWord; -- Bit 0 indicates the RemoteWakeup value
          SIE_LPM_RWRdy <= TRUE;
          RxTxState  := EOP;
          -- SIE_RxPidRdy <= PidReady;
        end if;
      when others => -- EOP
        if EndOfPacket then
          RxTxState := SOP;
          if (not CRC5ok) then
            SetError(ERROR_TOKEN_CRC);
          end if;
        else 
          ReceiveWord;
          -- 2 dribble bits allowed, at position 0 and 1
          if Position >1 then
            SetError(ERROR_TR_EOP);
          end if;
        end if;
    end case;
  end ReceiveLPMToken;

  -- DOC_END

  -- DOC_BEGIN: Procedure for receiving a handshake
  -- This procedure takes care of receiving a complete handshake. 
  -- In the Start of Packet (SOF) state, it waits for the end of a
  -- sync pattern. When this is received, the Packet Identifier (PID)
  -- state is entered, where the packet PID is received using the 
  -- ReceiveWord procedure. 
  -- If the sync pattern is not received within the allowed turn 
  -- around time, a timeout error is generated.
  -- In the EOP state, an end of packet should come in after at most
  -- 2 dribble bits. 

  procedure ReceiveHandshake is
  begin
    case RxTxState is
      when SOP =>
        if (TimeOut) then
          -- Packet not received before timeout
          StopTimeOut := TRUE;
          SetError(ERROR_TIMEOUT);
          TimeOut := FALSE;
        elsif SyncDetected then
          StopTimeOut := TRUE;
          Error := FALSE; -- clear possible previous error
          BitstuffCnt := 0;
          RxTxState := PID;
          InitCrc := TRUE;
        end if;
      when PID =>
        ReceiveWord;
        if SE0Detected then
          SetError(ERROR_TR_EOP);
        end if;
        if Ready then
          if (not Error) then
            CheckPidPacket(DataWord, PACKET_HANDSHAKE,
                           PidType, PacketType, Error, ErrorType);
          end if;
          if (not Error) then 
            PidReady := TRUE;
            RxTxState := EOP;
          end if;
        end if;
      when others => -- EOP
        if EndOfPacket then
          RxTxState := SOP;
        else 
          ReceiveWord;
          if Position >1 then
            SetError(ERROR_TR_EOP);
          end if;
        end if;
    end case; -- RxTxState
  end ReceiveHandshake;
  -- DOC_END

  -- DOC_BEGIN: Procedure for receiving a data packet
  -- This procedure takes care of receiving a complete data packet. 
  -- In the Start of Packet (SOF) state, it waits for the end of a
  -- sync pattern. When this is received, the Packet Identifier (PID)
  -- state is entered, where the packet PID is received using the 
  -- ReceiveWord procedure. 
  -- If the sync pattern is not received within the allowed token - data
  -- time, a timeout error is generated.
  -- After the PID, the DATA state is entered, until an SE0 is received.
  -- At that moment, the 16 bit CRC is evaluated, and the EOP state is
  -- entered.
  
  procedure ReceiveData is
  begin
    case RxTxState is
      when SOP =>
        if (TimeOut) then
          -- Data Packet not received before timeout
          StopTimeOut := TRUE;
          SetError(ERROR_TIMEOUT);
          TimeOut := FALSE;
        elsif SyncDetected then
          StopTimeOut := TRUE;
          Error := FALSE; -- clear possible previous error
          BitstuffCnt := 0;
          RxTxState := PID;
          InitCrc := TRUE;
        end if;
      when PID =>
        ReceiveWord;
        if Ready then
          if (not Error) then
            CheckPidPacket(DataWord, PACKET_DATA,
                           PidType, PacketType, Error, ErrorType);
          end if;
          if (not Error) then 
            PidReady := TRUE;
            RxTxState := DATA;
          end if;
        end if;
        if SE0Detected  then
          SetError(ERROR_TR_EOP);
        end if;
      when DATA =>
        EvalCrc := TRUE;
        ReceiveWord;
        -- Receive data until an EOP is seen
        if Ready and (not Error) then
          if SE0Detected then 
            RxTxState := EOP;
          else
            SIE_RxData <= DataWord;
            SIE_RxDataRdy <= TRUE;
          end if;
        end if;
      when others => -- EOP
        if (not CRC16ok) then 
          SetError(ERROR_DATA_CRC);
        end if;
        if EndOfPacket then
          RxTxState := SOP;
        elsif not SE0Detected and Position >1 then
          SetError(ERROR_TR_EOP);
        end if;
    end case;
  end ReceiveData;
  -- DOC_END

  -----------------------------------------------------------------------
  --                             Tx Procedures                         --
  -----------------------------------------------------------------------

  -- DOC_BEGIN: Procedure to send a data packet
  -- This procedure sends a data packet. After the sync pattern 
  -- and the PID, data are sent as long as available. When no data
  -- are available anymore, the CRC is added, followed by an EOP.

  procedure SendData is
  begin
    case RxTxState is
      when SOP =>
        DataWord := SYNC_PATTERN;
        SendWord;
        if Ready then
          RxTxState := PID;
          InitCrc := TRUE;
        end if;
      when PID =>
        if MM_TxData1Pid then
          DataWord := EncodePid(PID_DATA1);
        else
          DataWord := EncodePid(PID_DATA0);
        end if;
        SendWord;
        if Ready then 
          -- if data are available, fetch them, otherwise
          -- send CRC
          if MM_TxDataRdy then
            SIE_TxDataAck <= TRUE;
            DataWord := MM_TxData;
            RxTxState := DATA;
          else
            RxTxState := CRC1;
          end if;
        end if;
      when DATA =>
        EvalCrc := TRUE;
        SendWord;
        if Ready then 
          if MM_TxDataRdy then
            SIE_TxDataAck <= TRUE;
            DataWord := MM_TxData;
          else
            RxTxState := CRC1;
          end if;
        end if;
      when CRC1 =>
        if MM_all_bytes_sent then
          Crc16_tmp := not(Crc16(15 downto 8));
        else --Underrun condition
          Crc16_tmp := (Crc16(15 downto 8));
        end if;
        DataWord := InsertWord(DataWord, Crc16_tmp, Position => 0, RevIns => TRUE);
        SendWord;
        if Ready then 
          RxTxState := CRC2;
        end if;
      when CRC2 =>
        if MM_all_bytes_sent then
          Crc16_tmp := not(Crc16(7 downto 0));
        else --Underrun condition
          Crc16_tmp := Crc16(7 downto 0);
        end if;
        DataWord := InsertWord(DataWord, Crc16_tmp, Position => 0, RevIns => TRUE);
        SendWord;
        if Ready then 
          RxTxState := EOP;
        end if;
      when others => -- EOP
        -- Reset the DataWord during EOP to avoid bitstuffing
        DataWord := (others => not BITSTUFF_VALUE);
        SendEOP;
        if Ready then
          RxTxState := SOP;
        end if;
    end case; -- RxTxState
  end SendData;
  -- DOC_END

  -- DOC_BEGIN: Procedure for sending a handshake
  -- This procedure sends a handshake packet, consisting of 3 parts:
  -- a sync pattern, the PID and an EOP.
  procedure SendHandshake is
  begin
    case RxTxState is
      when SOP =>
        DataWord := SYNC_PATTERN;
        SendWord;
        if Ready then
          RxTxState := PID;
          InitCrc := TRUE;
        end if;
      when PID =>
        if MM_Stalled then
          DataWord := EncodePid(PID_STALL);
        elsif MM_Accepted then
          DataWord := EncodePid(PID_ACK);
        else
          DataWord := EncodePid(PID_NAK);
        end if;
        SendWord;
        if Ready then
          RxTxState := EOP;
        end if;
      when others => -- EOP
        -- Reset the dataword during EOP to avoid bitstuffing
        DataWord := (others => not BITSTUFF_VALUE);
        SendEOP;
        if Ready then
          RxTxState := SOP;
        end if;
    end case; -- SHState
  end SendHandshake;
  -- DOC_END

-- DOC_BEGIN: Procedure for sending a LPM handshake
  -- This procedure sends a LPM handshake packet, consisting of 3 parts:
  -- a sync pattern, the PID and an EOP.
  procedure SendLPMHandshake is
  begin
    case RxTxState is
      when SOP =>
        DataWord := SYNC_PATTERN;
        SendWord;
        if Ready then
          RxTxState := PID;
          InitCrc := TRUE;
        end if;
      when PID =>
        if (NOT LPM_LINK_STATE_EN AND MM_LPMSupported) then 
          DataWord := EncodePid(PID_STALL);
        elsif (MM_LPMNYET AND MM_LPMSupported) then
          DataWord := EncodePid(PID_NYET);
        elsif MM_LPMSupported then
          DataWord := EncodePid(PID_ACK);
-- LPM_HostRetry_Reset will activate the LPM timers in TIMERS_SF
-- A pulse must be generated at the end of the acknowledge         
          HostRetry_Reset <= TRUE;
        else
          DataWord := EncodePid(PID_STALL);
        end if;
        SendWord;
        if Ready then
          RxTxState := EOP;
        end if;
      when others => -- EOP
        -- Reset the dataword during EOP to avoid bitstuffing
        DataWord := (others => not BITSTUFF_VALUE);
        SendEOP;
        if Ready then
          RxTxState := SOP;
        end if;
    end case; -- SHState
  end SendLPMHandshake;
  -- DOC_END

begin

  if (Reset_N = ACTIVE_LOW) then
    
    PMState             <= PM_WAIT_FOR_REQUEST;
--    TxUsbLogValue_Z     <= USB_LOG_J;
    RxTxState           := SOP;
    SIE_RxDataRdy       <= FALSE;
    SIE_LPM_HIRDRdy     <= FALSE;
    SIE_LPM_RWRdy       <= FALSE;
    SIE_RxData          <= (others => '0');
    ErrorType           := ERROR_NO_ERROR;
    Error               := FALSE;
    RxErrorType         <= ERROR_NO_ERROR;
    RxError             <= FALSE;
    SIE_RxPidRdy        <= FALSE;
    RxPid               <= PID_INVALID;
    SubPID              <= LPM_INVALID0;
    SIE_TxDataAck       <= FALSE;

    if MAX_DEVICE_SPEED = USB_FULL_SPEED then
      SIE_SOFByte1 <= FALSE;
      SIE_SOFByte2 <= FALSE;
      SIE_RxSOF <= FALSE;
    end if;

    SIE_StartEndpSearch <= FALSE;
    HostRetry_Reset     <= FALSE;
    LPM_HostRetry_Reset <= FALSE;
    SIE_RxEOP           <= FALSE;
    PidType             := PID_INVALID;
    SubPidType          := LPM_INVALID0;
    SaveBit             := LOW;
    TimeOutCnt          := 0;
    TimeOutStarted      <= FALSE;
    TimeOut             := FALSE;
    PidReady            := FALSE;
    Position            := 0;
    BitstuffCnt         := 0;
    BitValue            := '0';
    DataWord            := (others => '0');
    Crc16               := (others => '0');
    Crc5                := (others => '0');
    Crc16ok             := FALSE;
    Crc5ok              := FALSE;
    
    TxUsbLogValue       <= USB_LOG_J;
    UP_DP               <= '1';
    UP_DM               <= '0';
    UP_FSE0             <= '0';
    
    TxUsbEnable         <= FALSE;
    BitstuffError       := FALSE;
    EndOFPacket         := FALSE;

    SyncDetected        := FALSE;
    SE0Detected         := FALSE;
    PacketSent          := FALSE;
    RxUsbLogValue       <= USB_LOG_J;
    RxUsbLogValue_Z1    <= USB_LOG_J;
    RxUsbLogValue_Z2    <= USB_LOG_J;
    RxUsbLogValue_Z3    <= USB_LOG_J;
    Crc16_tmp           := (others => '0');
    PacketType          := PACKET_SPECIAL;
    LPMPacketType       := PACKET_SPECIAL;
    StuffedBit          := FALSE;
    NewBitStuffCnt      := 0;
    StopTimeOut         := FALSE;
    EvalCrc             := FALSE;
    Ready               := FALSE;
    InitCrc             := FALSE;
    StartTimeOut        := FALSE;
    
    increment_token_counter <= '0';
    update_token_counter    <= '0';
    reset_token_counter     <= '0';
    reset_token_counter_d   <= '0';

    adjust_PID <= '0';    
    adjust_EOP <= '0';

  elsif (FsClk'event and FsClk='1') then
  
    reset_token_counter_d <= reset_token_counter;
   
    -- Convert the incoming bits to Logical value
    if TxUsbEnable then
      -- mask incoming bits during sending
      RxUsbLogValue <= USB_LOG_J;
    else
      RxUsbLogValue <= UsbDif2Log(CR_UsbLineBits, USB_FULL_SPEED);
    end if;
    RxUsbLogValue_Z1 <= RxUsbLogValue;
    RxUsbLogValue_Z2 <= RxUsbLogValue_Z1;
    RxUsbLogValue_Z3 <= RxUsbLogValue_Z2;

    -- Prevents generation of different registers for variable and signal
    Error := RxError;
    ErrorType := RxErrorType;
    PidType := RxPid;
    
  ------------------------------------------------------------------------
  --                           Sync Detector                            --
  ------------------------------------------------------------------------

    -- DOC_BEGIN: Detection of a sync pattern
    -- The four last incoming bits are compared to the pattern 'KJKK',
    -- which is the end of the sync pattern (KJKJKJKK).
    -- The first few bits are not used because they can be missed as the
    -- clock is not synchronized to the data stream yet.

    SyncDetected := FALSE;
    if ( (not TxUsbEnable) and 
       ( (RxUsbLogValue    = USB_LOG_K) and
         (RxUsbLogValue_Z1 = USB_LOG_K) and
         (RxUsbLogValue_Z2 = USB_LOG_J) and
         (RxUsbLogValue_Z3 = USB_LOG_K))) then
      SyncDetected := TRUE;
    end if;

    -- DOC_END

  ------------------------------------------------------------------------
  --                      End Of Packet Detector                        --
  ------------------------------------------------------------------------

    -- DOC_BEGIN: End of Packet detection
    -- An end of packet consists of at least one SE0, followed by a J.
    -- When an SE0 is received, the SE0Detect flag is set. When after this
    -- a J is received, this is considered as a valid end of packet.
    -- Otherwise an error is generated.

    EndOfPacket := FALSE;
    if (not TxUsbEnable) then  
      if (RxUsbLogValue = USB_LOG_SE0) then
        SE0Detected := TRUE;
      elsif SE0Detected then
        SE0Detected := FALSE;
        if (RxUsbLogValue = USB_LOG_J) then
          if not TimeOutStarted then
            EndOfPacket := TRUE;
          end if;  
--        else
        elsif (RxTxState /= SOP) then
          SetError(ERROR_TR_EOP);
        end if;
      end if;
    end if;

    -- DOC_END

  ------------------------------------------------------------------------
  --                     Main FSM                                       --
  ------------------------------------------------------------------------

    Ready := FALSE;
    StartTimeOut := FALSE;
    StopTimeOut := FALSE;
    InitCRC := FALSE;
    EvalCrc := FALSE;
    PidReady := FALSE;
    if MAX_DEVICE_SPEED = USB_FULL_SPEED then
      SIE_SOFByte1 <= FALSE;
      SIE_SOFByte2 <= FALSE;
    end if;
    SIE_RxDataRdy <= FALSE;
    SIE_LPM_HIRDRdy     <= FALSE;
    SIE_LPM_RWRdy       <= FALSE;
    SIE_TxDataAck <= FALSE;

    TxUsbLogValue <= USB_LOG_J;
    UP_DP         <= '1';
    UP_DM         <= '0';
    UP_FSE0       <= '0';

    TxUsbEnable <= FALSE;
    SIE_StartEndpSearch <= FALSE;
    LPM_HostRetry_Reset <= FALSE;
    BitstuffError := FALSE;
    BitValue := '0';

    -- Delayed input, for NRZI decoding
--    TxUsbLogValue_Z <= TxUsbLogValue;


    -- DOC_BEGIN: Main State Machine
    -- The Main State Machine handles the USB protocol. It determines the
    -- order of packets, using the procedures to send or receive these
    -- packets.
    -- The possible sequences are:

    -- Receive OUT Token - Receive Data 

    -- Receive OUT Token - Receive Data - Send Handshake

    -- Receive IN Token - Send Data 

    -- Receive IN Token - Send Handshake

    -- Receive IN Token - Send Data - Receive Handshake

    -- Receive LPM Token - Send Handshake - HL

    increment_token_counter <= '0';
    update_token_counter    <= '0';
    reset_token_counter     <= '0';

    case PMState is


    -- In the PM_WAIT_FOR_REQUEST state, the SIE waits for an IN, OUT,
    -- SETUP or LPM token. Other tokens (SOF, PRE) are handled in the 
    -- ReceiveToken procedure.
    -- Depending on the token, the state machine jumps to the
    -- PROCESS_IN or PROCESS_OUT_SETUP or PROCESS_LPM_TOKEN state.

-------------------------------------------------------------------------------       
    -- LPM_CHANGE
    -- In the PM_WAIT_FOR_REQUEST state, now SIE will also look for the LPM PID.
    -- Upon receiving the PID state machine will transition to the 
    -- PM_PROCESS_LPM_TOKEN.
    -- In the PM_WAIT_FOR_REQUEST state, the first part the LPM token is recieved.
    -- The first part of the LPM Token is a standard token defined in the
    -- USB Specifications.
    -- LPM_HostRetry_Reset signal is generated to reset the timer which
    -- calculates the Host Retry Time duration. The timer is implemented in the 
    -- TIMERS_SF module.
-------------------------------------------------------------------------------

      when PM_WAIT_FOR_REQUEST =>
        -- Any transaction should start with a request
        -- in the form of a token. (IN/OUT/SETUP/SOF/LPM)
        ReceiveToken;
        if EndOfPacket then -- Token received, but possibly with an error
	  reset_token_counter <= '1';
          case PidType is
            when PID_IN =>
              PMState <= PM_PROCESS_IN;
            when PID_OUT | PID_SETUP =>
              TimeOutCnt := DEVICE_TIMEOUT + 7;
              StartTimeOut := TRUE;
              PMState <= PM_PROCESS_OUT_SETUP;
            -- Added for LPM PID detection
            when PID_LPM =>
              if (MM_LPMSupported) then
                PMState <= PM_PROCESS_LPM_TOKEN;
                StartTimeOut := TRUE; -- to receive LPM extended token 
                TimeOutCnt := DEVICE_TIMEOUT + 7;
              else
                PMState <= PM_WAIT_FOR_REQUEST;
              end if;
	    when PID_SOF =>
	      update_token_counter <= '1';
            when others =>
              -- SOF or Not a valid token pid, so wait for the next one
              -- (SOF is already handled in ReceiveToken)
              null;
         end case;
       end if;

-------------------------------------------------------------------------------       
    -- LPM CHANGE
    -- The PM_PROCESS_LPM_TOKEN state waits for the extended part of LPM token.
    -- The extended token comes after Inter Packet Interval time duration.
    -- The extended token contains LPM SubPID and the LPM attributes.
    -- The length of the extended token is same as of Standard token.
    -- To decode the fields of the extended token ReceiveLPMToken procedure 
    -- is called.
    -- Upon receiving the error free extended token state machine transitions
    -- to the PM_SEND_LPM_HANDSHAKE state.
    -- The next state would be to send a proper handshake signal to USB Host
    -- SendLPMHandshake procedure is called to send the LPM Token response

      when PM_PROCESS_LPM_TOKEN =>
        ReceiveLPMToken;
        if EndOfPacket then
          if MM_EndpSearchReady then
            if MM_EndpSearchSelected then
              if (SubPidType = LPM_SubPid)  then         
                PMState <= PM_SEND_LPM_HANDSHAKE ;
              else
                PMState <= PM_WAIT_FOR_REQUEST;
                PidType := PID_INVALID;
                SubPidType := LPM_INVALID0;
              end if;
            else
              PMState <= PM_WAIT_FOR_REQUEST;
              PidType := PID_INVALID;
              SubPidType := LPM_INVALID0;
            end if;
          end if;
        end if;

      when PM_SEND_LPM_HANDSHAKE =>
        if not PacketSent then
          SendLPMHandshake;
        end if;
        if EndOfPacket then
          PMState <= PM_WAIT_FOR_REQUEST;
          --  Reset PidType
          SubPidType          := LPM_INVALID0;
          PidType             := PID_INVALID;
          LPM_HostRetry_Reset <= HostRetry_Reset;
          HostRetry_Reset     <= FALSE;
        end if;
-------------------------------------------------------------------------------
      -- The PM_PROCESS_IN state answers IN Tokens. This answer can be
      -- a handshake or a data packet, depending on the availability of
      -- data. If the answer was a data packet, the state machine jumps to
      -- the RECEIVE_HANDSHAKE state or to the WAIT_FOR_REQUEST state,
      -- depending on the endpoint properties. If the answer was a
      -- handshake, the state machine always goes to the WAIT_FOR_REQUEST
      -- state to accept the next token.

      when PM_PROCESS_IN =>
        -- Host requesting input from function, wait until the MM block
        -- has determined access is for this device
        if (MM_EndpSearchReady) then 
          if (MM_EndpSearchSelected) then
            -- The device was addressed and the endpoint number is
            -- valid -> must respond
            if MM_Accepted or MM_ISO then
              -- Data are available or the endpoint is isochronous
              -- -> A data packet should be sent (which can be empty
              -- in the case of an iso endpoint that has no data)
              if not PacketSent then
                SendData;
              end if;
            else
              -- No data are available and the endpoint is not iso
              -- -> send a handshake
              if not PacketSent then
                SendHandshake;
              end if;
            end if;
            if EndOfPacket then
              -- wait for handshake if data are sent and not ISO
              -- otherwise goto IDLE
              if MM_ISO or (not MM_Accepted) then         
                PMState <= PM_WAIT_FOR_REQUEST;
                --  Reset PidType
                PidType := PID_INVALID;
              else
                PMState <= PM_RECEIVE_HANDSHAKE;
                StartTimeOut := TRUE; -- to receive handshake
                TimeOutCnt := DEVICE_TIMEOUT + 7;
              end if;
            end if;
          else
            PMState <= PM_WAIT_FOR_REQUEST;
            --  Reset PidType
            PidType := PID_INVALID;
          end if;
        end if;


      -- The RECEIVE_HANDSHAKE state is used to receive a handshake  
      -- after sending a data packet. At the end of the handshake, the
      -- state machine jumps to the WAIT_FOR_REQUEST state to accept
      -- the next token. 

      when PM_RECEIVE_HANDSHAKE =>
        ReceiveHandshake;
        if EndOfPacket then
          PMState <= PM_WAIT_FOR_REQUEST;
          --  Reset PidType
          PidType := PID_INVALID;
        end if;

      -- The PROCESS_OUT_SETUP state is used to receive a data packet 
      -- after a SETUP or OUT token. After reception of the data packet
      -- a can jump to the SEND_HANDSHAKE or WAIT_FOR_REQUEST state, 
      -- depending on the endpoint properties.

      when PM_PROCESS_OUT_SETUP =>
        -- Host sending output to function
        ReceiveData;
        if EndOfPacket then
          if MM_EndpSearchReady then
            if MM_EndpSearchSelected then
              if MM_ISO then         
                -- endpoint is iso, so transfer is done
                PMState <= PM_WAIT_FOR_REQUEST;
                --  Reset PidType
                PidType := PID_INVALID;
              else
                -- endpoint is not iso so send a handshake
                PMState <= PM_SEND_HANDSHAKE;
              end if;
            else
              PMState <= PM_WAIT_FOR_REQUEST;
              --  Reset PidType
              PidType := PID_INVALID;
            end if;
          end if;
        end if;


      -- The SEND_HANDSHAKE state is used to send a handshake 
      -- after receiving a data packet. When the handshake is sent,
      -- The state machine goes to the WAIT_FOR_REQUEST state for
      -- accepting the next token.

      when others =>
        if not PacketSent then
          SendHandshake;
        end if;
        if EndOfPacket then
          PMState <= PM_WAIT_FOR_REQUEST;
          --  Reset PidType
          PidType := PID_INVALID;
        end if;

    end case; -- PMState
    -- DOC_END

    if (RxTxState /= SOP) and (PMState = PM_WAIT_FOR_REQUEST) and
       ((RxTxState = PID) or (RxTxState = EOP) or not(StuffedBit)) then
      increment_token_counter <= '1';
    end if;

    -- DOC_BEGIN: Error Handling and State Machine Reset
    -- At the end of each packet, the packet state machine is reset. In the case
    -- of an error, both packet and protocol state machines are reset. 
    -- Precautions are taken that the state machines can never be reset while
    -- sending (especially for babble error, which is an error that occurs while
    -- sending).

    if EndOfPacket or Error then
      RxTxState := SOP;
      PacketSent := FALSE;
      DataWord := SYNC_PATTERN;
      Position := 0;
      if (MAX_DEVICE_SPEED = USB_FULL_SPEED) then
        SIE_RxSOF <= FALSE;
      end if;
    end if;

    if Error then
      PMState <= PM_WAIT_FOR_REQUEST;
      PidType := PID_INVALID;
    end if;
    -- DOC_END 

    -- DOC_BEGIN: Remote Wake up
    -- If TM_SendResume is asserted, a remote wake up is sent, regardless 
    -- the state of the other state machines (since a remote wake up can only
    -- be sent after 5 ms of idle on the bus, the state should be WAIT_FOR_REQUEST).

    if TM_SendResume then
      TxUsbLogValue <= USB_LOG_K;
      UP_DP         <= '0';
      UP_DM         <= '1';
      UP_FSE0       <= '0';
      TxUsbEnable   <= TRUE;
    end if;
    -- DOC_END 

  ------------------------------------------------------------------------
  --                     TimeOut Handling                               --
  ------------------------------------------------------------------------

    -- DOC_BEGIN: Time Out Timing
    -- The time out timer is controlled by the StartTimeOut and StopTimeout
    -- flags. When the timer expires before it is stopped, the TimeOut flag
    -- is asserted, which generates an error.

    if TimeOutStarted and (not StopTimeOut) then
      assert (StartTimeOut = FALSE)
      report "Restarting already running timeout"
      severity note;
      --  Make sure that TimeOutCnt can not become negative
      if TimeOutCnt /= 0 then
        TimeOutCnt := TimeOutCnt -1;
      end if;
      if TimeOutCnt = 0 then
        TimeOut := TRUE;
      end if;
    elsif StartTimeOut then
      TimeOutStarted <= TRUE;
    elsif StopTimeOut then
      TimeOutStarted <= FALSE;
    end if;
    -- DOC_END

  ------------------------------------------------------------------------
  --                     CRC Generation and check                       --
  ------------------------------------------------------------------------

    -- DOC_BEGIN: CRC calculation and check
    -- CRC calculation and checks are controlled by the InitCRC flag which
    -- initializes the CRC to all 1's and the EvalCRC flag which updates
    -- the CRC with the current bit value.
    --
    -- At every byte boundary, the Crc5Ok and Crc16Ok flags, which indicate
    -- that the CRC equals the required residual, are updated.
    -- This update is only done at byte boundaries to avoid updates on dribble
    -- bits.


    if (InitCrc) then
      Crc5  := (others => '1');
      Crc16 := (others => '1');
    elsif (EvalCrc) then
      Crc5  := MultipleCRC5_D1(BitValue, Crc5);
      Crc16 := MultipleCRC16_D1(BitValue, Crc16);
    end if;

    if Position = 0 and (RxTxState /= SOP) then
      Crc5ok  := (Crc5  = CRC5_RESIDUAL);
      Crc16ok := (Crc16 = CRC16_RESIDUAL);
    end if;
    -- DOC_END

    SIE_RxEOP           <= EndOfPacket;
    SIE_RxPidRdy        <= PidReady;
    RxPid               <= PidType;
    RxError             <= Error;
    RxErrorType         <= ErrorType;
    SubPid              <= SubPidType; 
    
    adjust_PID <= '0';    
    if (PidReady) and (PidType = PID_SOF) then
      adjust_PID <= '1';
    end if;
    
    adjust_EOP <= '0';    
    if (RxTxState = EOP) and (PidType = PID_SOF) then
      adjust_EOP <= '1';
    end if;
    
  end if; -- FsClk-Reset_N
    
end process MAIN;

PROC_TOKEN_LENGTH : process(Clk48MHz,Reset48MHz_N)
begin
  if Reset48MHz_N = '0' then
    Token_Length_int <= 0;
    Token_Length     <= (others => '0');
    adjust_PID_s     <= '0';    
    adjust_EOP_s     <= '0';    
    adjust_PID_ss    <= '0';    
    adjust_EOP_ss    <= '0';    
    adjust_req       <= '0';
    adjust_eof       <= '0';
    adjust_bias      <= (others => '0');
    increment_token_counter_s <= '0';
  elsif Clk48MHz'event and Clk48MHz = '1' then
    increment_token_counter_s <= increment_token_counter;
    if adjust_enable = '1' then
      if (Token_Length_int < 127) and (increment_token_counter_s = '1') then
        Token_Length_int <= Token_Length_int + 1;
      end if;
    
      if update_token_counter = '1' then
        Token_Length <= std_logic_vector(to_unsigned(Token_Length_int,7));
      elsif reset_token_counter_d = '1' then
        Token_Length_int <= 0;
      end if;
    
      adjust_PID_s  <= adjust_PID;
      adjust_EOP_s  <= adjust_EOP;
      adjust_PID_ss <= adjust_PID_s;
      adjust_EOP_ss <= adjust_EOP_s;
      adjust_req   <= '0';
      adjust_eof   <= '0';
      if (adjust_PID_ss = '0') and 
         (adjust_PID_s   = '1') then
        adjust_req  <= '1';
        adjust_eof  <= '0';
	case Token_Length_int is
	  when  0 |  1 |  2 |  3 |  4 |  5 |  6 |  7 |  8 |  9 |
	       10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
	       20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 
	       =>
	    adjust_bias    <= "100";
	  when 30 =>
            adjust_bias(2 downto 1) <= std_logic_vector(to_unsigned(Token_Length_int,7)(1 downto 0));
	    if start_negedge_early = '1' and sync_negedge_early = '0' then
	      adjust_bias(0) <= '1';
	    else
	      adjust_bias(0) <= '0';
	    end if;
	  when 31| 32 | 33 =>
	    if start_negedge_early = '1' and sync_negedge_early = '0' then
	      adjust_bias(0) <= '1';
              adjust_bias(2 downto 1) <= std_logic_vector(to_unsigned(Token_Length_int,7)(1 downto 0));
	    elsif start_negedge_early = '0' and sync_negedge_early = '1' then
	      adjust_bias(0) <= '1';
              adjust_bias(2 downto 1) <= std_logic_vector(to_unsigned(Token_Length_int,7)(1 downto 0) - "01");
	    else
	      adjust_bias(0) <= '0';
              adjust_bias(2 downto 1) <= std_logic_vector(to_unsigned(Token_Length_int,7)(1 downto 0));
	    end if;
	  when others =>
	    adjust_bias <= "011";
	end case;
      end if;
      if (adjust_EOP_ss = '0') and 
         (adjust_EOP_s  = '1')  then
        adjust_req  <= '1';
        adjust_eof  <= '1';
	case Token_Length_int is
	  when  0 |  1 |  2 |  3 |  4 |  5 |  6 |  7 |  8 |  9 |
	       10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
	       20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 |
	       30 | 31 | 32 | 33 | 34 | 35 | 36 | 37 | 38 | 39 |
	       40 | 41 | 42 | 43 | 44 | 45 | 46 | 47 | 48 | 49 |
	       50 | 51 | 52 | 53 | 54 | 55 | 56 | 57 | 58 | 59 |
	       60 | 61 | 62 | 63 | 64 | 65 | 66 | 67 | 68 | 69 |
	       70 | 71 | 72 | 73 | 74 | 75 | 76 | 77 | 78 | 79 |
	       80 | 81 | 82 | 83 | 84 | 85 | 86 | 87 | 88 | 89 |
	       90 | 91 | 92 | 93 
	       =>
	    adjust_bias    <= "100";
	  when 94 =>
            adjust_bias(2 downto 1) <= std_logic_vector(to_unsigned(Token_Length_int,7)(1 downto 0));
            if start_negedge_early = '1' and eop_negedge_early = '0' then
	      adjust_bias(0) <= '1';
	    else
	      adjust_bias(0) <= '0';
	    end if;
	  when 95 | 96 | 97 =>
            if start_negedge_early = '1' and eop_negedge_early = '0' then
	      adjust_bias(0) <= '1';
              adjust_bias(2 downto 1) <= std_logic_vector(to_unsigned(Token_Length_int,7)(1 downto 0));
	    elsif start_negedge_early = '0' and eop_negedge_early = '1' then
	      adjust_bias(0) <= '1';
              adjust_bias(2 downto 1) <= std_logic_vector(to_unsigned(Token_Length_int,7)(1 downto 0) - "01");
	    else
	      adjust_bias(0) <= '0';
              adjust_bias(2 downto 1) <= std_logic_vector(to_unsigned(Token_Length_int,7)(1 downto 0));
	    end if;
	  when others =>
	    adjust_bias <= "011";
	end case;
      end if;
      
    else
      Token_Length_int <= 0;
      Token_Length     <= (others => '0');
      adjust_req       <= '0';
      adjust_eof       <= '0';
      adjust_bias      <= (others => '0');
    end if;    
    
  end if;
end process PROC_TOKEN_LENGTH;

PROC_POS_EDGE : process(Clk48MHz,Reset48MHz_N)
begin
  if Reset48MHz_N = '0' then
    negedge_early_delay <= (others => '0');
    start_negedge_early <= '0';
    jk_transition_del   <= (others => '0');
    
  elsif Clk48MHz'event and Clk48MHz = '1' then

    jk_transition_del(0)          <= CR_jk_transition;
    jk_transition_del(2 downto 1) <= jk_transition_del(1 downto 0);

    negedge_early_delay(0)          <= CR_VM_negedge;
    negedge_early_delay(4 downto 1) <= negedge_early_delay(3 downto 0);
    if jk_transition_del(2) = '1' then
      negedge_early_delay(5) <= negedge_early_delay(4);
    end if;
    if increment_token_counter = '0' then
      start_negedge_early <= negedge_early_delay(5);
    end if;

  end if;
end process PROC_POS_EDGE;

eop_negedge_early  <= negedge_early_delay(5);
sync_negedge_early <= negedge_early_delay(5);
end RTL;
