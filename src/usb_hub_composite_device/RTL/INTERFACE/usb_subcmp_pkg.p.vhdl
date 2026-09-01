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


package usb_subcmp_pkg is

  ----------------------------------------------------------------
  -- Hub Port Status and port Status Change 
  ----------------------------------------------------------------
  type T_HubPortStatus is record
    Connect:     boolean;
    Enable:      boolean;
    Suspend:     boolean;
    OverCurrent: boolean;
    Reset:       boolean;
    Power:       boolean;
    LowSpeed:    boolean;
  end record;

  type T_HubPortStatusChange is record
    Connect:     boolean;
    Enable:      boolean;
    Suspend:     boolean;
    OverCurrent: boolean;
    Reset:       boolean;
  end record;

  type T_EmbPortStatus is record
    Connect:     boolean;
    Enable:      boolean;
    Suspend:     boolean;
    Reset:       boolean;
    Power:       boolean;
  end record;
 
  type T_EmbPortStatusChange is record
    Connect:     boolean;
    Enable:      boolean;
    Suspend:     boolean;
    Reset:       boolean;
  end record;
 
  type T_HubPortStatus_array is array(integer range <>) of T_HubPortStatus;
  type T_HubPortStatusChange_array is array(integer range <>) of T_HubPortStatusChange;
  type T_EmbPortStatus_array is array(integer range <>) of T_EmbPortStatus;
  type T_EmbPortStatusChange_array is array(integer range <>) of T_EmbPortStatusChange;
 
  ----------------------------------------------------------------
  -- Speed Constant
  ----------------------------------------------------------------
  -- Constant use to describe USB speed
  constant HIGH_SPEED            : std_logic_vector(1 downto 0) := "10";
  constant FULL_SPEED            : std_logic_vector(1 downto 0) := "01";
  
  ----------------------------------------------------------------
  -- Packet size
  ----------------------------------------------------------------
  -- Maximum data packet size is specified as 1024 bytes in length
  -- This is only the data size, not including SYNC etc.
  constant MAX_PACKET_LENGTH: integer := 1024;
  subtype S_PACKET_LENGTH_range is
      integer range 0 to MAX_PACKET_LENGTH - 1;

  -----------------------------------------------------------------
  -- Device addresses
  --   addresses on USB range from 0 to 127
  --   address 0 is reserved
  -----------------------------------------------------------------
  constant MAX_DEVICE_ADDRESS: integer := 128;
  subtype S_DevAddr_range is integer range 0 to MAX_DEVICE_ADDRESS - 1;
   
  constant MAX_LPM_HIRD: integer := 242;
  subtype S_LPM_HIRD_range is integer range 0 to MAX_LPM_HIRD - 1;
  constant MAX_LPM_RW: integer := 1;
  subtype S_LPM_RW_range is integer range 0 to MAX_LPM_RW - 1;

  --constant DevAddr_ADDRWIDTH: integer := 7;
  constant DevAddr_ADDRWIDTH: integer := Log2(MAX_DEVICE_ADDRESS);
  subtype S_DevAddr_bits is
      unsigned(DevAddr_ADDRWIDTH - 1 downto 0);
  constant DEFAULT_DEVICE_ADDRESS: S_DevAddr_range := 0;

  constant LPM_HIRD_WIDTH: integer := 8;
  subtype S_LPM_HIRD_bits is
      unsigned(LPM_HIRD_WIDTH - 1 downto 0);
  constant LPM_RW_WIDTH: integer := 8;
  subtype S_LPM_RW_bits is
      unsigned(LPM_RW_WIDTH - 1 downto 0);

  -----------------------------------------------------------------
  -- End points
  -- Full speed devices may have any of the 16 possible endpoints
  -- Low speed devices are limited one additional endpoint address
  -- Control endpoint 0 is reserved in all cases
  -----------------------------------------------------------------
  constant MAX_ENDPOINT_ADDRESS: integer := 16;
  subtype S_EndpAddr_range is integer range 0 to MAX_ENDPOINT_ADDRESS - 1;
  subtype S_EndpAddr_booleans is
      booleans(MAX_ENDPOINT_ADDRESS - 1 downto 0);
  --constant EndpAddr_ADDRWIDTH: integer := 4;
  constant EndpAddr_ADDRWIDTH: integer := Log2(MAX_ENDPOINT_ADDRESS);
  subtype S_EndpAddr_bits is
      unsigned(EndpAddr_ADDRWIDTH - 1 downto 0);
  constant DEFAULT_ENDPOINT_ADDRESS: S_EndpAddr_range := 0;

  ----------------------------------------------------------------
  -- Check if device/endpoint combination is addressed
  ----------------------------------------------------------------
  -- If a device is not configured, it should respond to the
  -- DEFAULT_DEVICE_ADDRESS and ignore whatever endpoint is specified
  -- If a device is configured, it should respond to its own
  -- configured DevAddr and to the active endpoints indicated
  -- in ActiveEndps. If we put the DEFAULT_ENDPOINT_ADDRESS to TRUE in
  -- this boolean array, the device will always respond to
  -- the default pipe.
  function IsDevAddr (DevAddr:     S_DevAddr_range;
                      EndpAddr:    S_EndpAddr_range;
                      ThisDevAddr: S_DevAddr_range;
                      ActiveEndps: S_EndpAddr_booleans;
                      DevConf:     boolean)
           return boolean;

  ----------------------------------------------------------------
  -- Speeds of the USB devices and bus
  --   Full speed is 12 MHz               => Tfs =  83.33 ns
  --   Low  speed is 12 MHz / 8 = 1.5 MHz => Tls = 666.66 ns
  ----------------------------------------------------------------
  type T_UsbSpeed_enum is (USB_FULL_SPEED,
                           USB_LOW_SPEED
                          );
  function DecodeUsbSpeed (SpeedType: one_bit)
           return T_UsbSpeed_enum;
  function EncodeUsbSpeed (SpeedType: T_UsbSpeed_enum)
           return one_bit;

  ----------------------------------------------------------------
  -- Frame length and EOF points 
  ----------------------------------------------------------------
  constant FLTyp: integer := 11999;
  constant FLMIN: integer := 11955;
  constant FLMAX: integer := 12045;
  constant EOF1_POINT: integer := 32; 
  constant EOF2_POINT: integer := 10; 
  constant FRAMELENGTH_FS: integer := 12000;
  constant FRAMELENGTH_LS: integer := 1500;

  function GetFrameLength(Speed: T_UsbSpeed_enum) 
           return integer;

  ----------------------------------------------------------------
  -- Frame timing (SOF)
  ----------------------------------------------------------------
  constant FRAME_TIME: integer := FLMax;
  subtype S_FRAME_TIME_range is integer range 0 to FRAME_TIME - 1;
  --constant FRAME_TIME_WIDTH: integer := 11;
  constant FRAME_TIME_WIDTH: integer := Log2(FRAME_TIME);
  subtype S_FRAME_TIME_WIDTH_bits is
          unsigned(FRAME_TIME_WIDTH - 1 downto 0);
  function ConvertAddrToTime (DevAddr: S_DevAddr_range;
                              EndpAddr: S_EndpAddr_range)
           return S_FRAME_TIME_range;

  ----------------------------------------------------------------
  -- Definitions for the USB bus convertions
  ----------------------------------------------------------------
  -- Enumerated type representing the logical values of the bus
  -- for both the Rx and Tx direction
  -- In Rx direction the values are single-ended zero, J, K and
  -- single-ended one
  -- In Tx direction the values are single-ended zero, J, K and
  -- tristate or Z
  type T_UsbLog_enum is (USB_LOG_SE0,
                         USB_LOG_J,
                         USB_LOG_K,
                         USB_LOG_SE1_OR_Z);
  function UsbBus2Log (DifInput:  one_bit;
                       LineInput: two_bits;
                       SpeedType: T_UsbSpeed_enum)
           return T_UsbLog_enum;
  function UsbDif2Log (DifInput:  two_bits;
                       SpeedType: T_UsbSpeed_enum)
           return T_UsbLog_enum;
  function UsbLog2Dif (LogInput:  T_UsbLog_enum;
                       SpeedType: T_UsbSpeed_enum)
           return two_bits;

  ----------------------------------------------------------------
  -- Start Of Packet (SOP)
  ----------------------------------------------------------------
  -- Detects a J->K transition
  function StartOfPacket (PrevLogVal: T_UsbLog_enum;
                          CurrLogVal: T_UsbLog_enum)
           return boolean;

  ----------------------------------------------------------------
  -- End Of Packet (EOP)
  ----------------------------------------------------------------
  constant EOP_MAX_SE0: integer := 2;
  subtype S_EOP_MAX_SE0_range is integer range 0 to EOP_MAX_SE0;
  -- This function only detects the SE0 in a packet
  -- transmission. It returns TRUE if the CurrLogVal = SE0
  function EndOfPacket (CurrLogVal: T_UsbLog_enum)
           return boolean;

  ----------------------------------------------------------------
  -- NRZI decoding function
  ----------------------------------------------------------------
  -- Function DecodeNRZI returns the data bit by comparing the
  -- previous value on the bus with the current value. If the
  -- previous value is different we have a LOW otherwise we
  -- have a HIGH data bit.
  function DecodeNRZI (PrevLogVal: T_UsbLog_enum;
                       CurrLogVal: T_UsbLog_enum)
           return one_bit;
  function EncodeNRZI (PrevLogVal:  T_UsbLog_enum;
                       CurrDataVal: one_bit)
           return T_UsbLog_enum;

  ----------------------------------------------------------------
  -- Bit-stuffing
  --   The BITSTUFF_LENGTH gives the number of BITSTUFF_VALUE bits
  --   that have to be detected before inserting the inverse bit.
  --   It is an Error not to have a transition when
  --   the BITSTUFF_LENGTH count is reached
  --   In USB, six consecutive HIGH should be interrupted with LOW
  ----------------------------------------------------------------
  constant BITSTUFF_LENGTH: integer := 6;
  subtype S_BitStuff_range is integer range 0 to BITSTUFF_LENGTH;
  constant BITSTUFF_VALUE:  one_bit := HIGH;
  function IncStuffedBitCnt (BitValue: one_bit)
           return boolean;
  function IsStuffedBit (BitValue: one_bit;
                         BitStuffCnt: S_BitStuff_range)
           return boolean;
  function IsBitStuffError (BitValue: one_bit;
                            BitStuffCnt: S_BitStuff_range)
           return boolean;
  -- Procedure DeStuff will determine based on the current BitValue
  -- and the current number of bits with BITSTUFF_VALUE whether:
  --   a bitstuff error has occurred
  --   whether this bit is a stuffed bit
  --   and a new BitStuffCnt value
  procedure DeStuff (BitValue:        in one_bit;
                     BitStuffCnt:     in S_BitStuff_range;
                     BitStuffError:  out boolean;
                     StuffedBit:     out boolean;
                     NewBitStuffCnt: out S_BitStuff_range);
  -- Procedure Stuff will determine based on the current BitValue
  -- and the current number of bits with BITSTUFF_VALUE whether:
  --   a bitstuff error has to be forced
  --   whether this bit position should be stuffed
  --   and a new BitStuffCnt value
  procedure Stuff (BitValue:        in one_bit;
                   BitStuffCnt:     in S_BitStuff_range;
                   BitStuffError:   in boolean;
                   StuffedBit:     out boolean;
                   NewBitStuffCnt: out S_BitStuff_range);

  ----------------------------------------------------------------
  -- Sync pattern is sent at the beginning of any packet on the
  -- USB bus. The bits are sent LSB first.
  -- This will result in J-K-J-K-J-K-J-K-K
  ----------------------------------------------------------------
  constant SYNC_PATTERN: byte := "10000000";

  ----------------------------------------------------------------
  -- All connect/disconnect/reset/timeout constants are specified
  -- in clock cycles of the full speed (12 MHz) clock
  ----------------------------------------------------------------
  -- If a device is connected or disconnected to/from host or hub, 
  -- this is detected after 56 Full Speed bit times.
  constant LS_HUB_CONNECT:    integer := 56;
  constant LS_HUB_DISCONNECT: integer := 56;
  constant FS_HUB_CONNECT:    integer := 56;
  constant FS_HUB_DISCONNECT: integer := 56;
  constant RESET_PERIOD:      integer := 56;
  constant HOST_TIMEOUT:      integer := 24;
  constant DEVICE_TIMEOUT:    integer := 16;
  subtype S_LS_HUB_CONNECT_range is
          integer range 0 to LS_HUB_CONNECT - 1;
  subtype S_LS_HUB_DISCONNECT_range is
          integer range 0 to LS_HUB_DISCONNECT - 1;
  subtype S_FS_HUB_CONNECT_range is
          integer range 0 to FS_HUB_CONNECT - 1;
  subtype S_FS_HUB_DISCONNECT_range is
          integer range 0 to FS_HUB_DISCONNECT - 1;
  subtype S_RESET_PERIOD_range is integer range 0 to RESET_PERIOD - 1;
  subtype S_HOST_TIMEOUT_range is integer range 0 to HOST_TIMEOUT - 1;
  subtype S_DEVICE_TIMEOUT_range is integer range 0 to DEVICE_TIMEOUT - 1;

  ----------------------------------------------------------------
  -- Data transferred between the Transceiver and PrtMgr
  ----------------------------------------------------------------
  subtype S_RxData_bits is byte;
  subtype S_TxData_bits is byte;
  constant RXDATA_WIDTH: integer := S_RxData_bits'length;
  constant TXDATA_WIDTH: integer := S_TxData_bits'length;
  subtype S_RXDATA_WIDTH_range is integer range 0 to RXDATA_WIDTH - 1;
  subtype S_TXDATA_WIDTH_range is integer range 0 to TXDATA_WIDTH - 1;
  subtype S_UsbWord_bits is byte;
  constant USBWORD_WIDTH: integer := S_UsbWord_bits'length;
  subtype S_UsbWord_range is integer range 0 to ((2**USBWORD_WIDTH) - 1);
  subtype S_USBWORD_WIDTH_range is integer range 0 to USBWORD_WIDTH - 1;

type T_PACKET_ERROR_enum is (ERROR_NO_ERROR,
                             ERROR_PID_ENCODING,
                             ERROR_PID_UNKNOWN,
                             ERROR_PACKET_UNEXPECTED,
                             ERROR_TOKEN_CRC,
                             ERROR_DATA_CRC,
                             ERROR_TIMEOUT,
                             ERROR_BABBLE,
                             ERROR_TR_EOP,
                             ERROR_SENT_RECEIVED_NAK,
                             ERROR_SENT_STALL,
                             ERROR_OVERRUN,
                             ERROR_SENT_EMPTYPACK,
                             ERROR_BITSTUFF_ERROR,
                             ERROR_SYNC_ERROR,
                             ERROR_DATA_IGNORED_WRONG_DATA01
                             );

  type T_Pid_enum is (
                      PID_LPM,           -- 16#0#, LPM (earlier unused, invalid pid)
                      PID_OUT,           -- 16#1#, Host -> device
                      PID_ACK,           -- 16#2#, Rx accepts error-free packet
                      PID_DATA0,         -- 16#3#, Even data packet
                      PID_RESERVED_1,    -- 16#4#, unused
                      PID_SOF,           -- 16#5#, Start of Frame, Frame nr
                      PID_NYET,          -- 16#6#, Rx can't accept LPM Token (earlier PID_ERR)
                      PID_RESERVED_2,    -- 16#7#, unused
                      PID_ERR,           -- 16#8#, Rx CRC or bitstuff error (earlier PID_RESERVED_3)
                      PID_IN,            -- 16#9#, Device -> host
                      PID_NAK,           -- 16#A#, Rx can't accept, Tx no data
                      PID_DATA1,         -- 16#B#, Even data packet
                      PID_PRE,           -- 16#C#, preamble LS->FS
                      PID_SETUP,         -- 16#D#, Setup for ctrl transaction
                      PID_STALL,         -- 16#E#, Endpoint is stalled
                      PID_INVALID        -- 16#F#, unused, invalid pid
                     );
  type T_SubPid_enum is (
                         LPM_INVALID0,     -- 16#0#, unused, invalid
                         LPM_INVALID1,     -- 16#1#, unused, invalid
                         LPM_INVALID2,     -- 16#2#, unused, invalid
                         LPM_SubPID ,      -- 16#3#, LPM SubPID
                         LPM_INVALID4,     -- 16#4#, unused, invalid
                         LPM_INVALID5,     -- 16#5#, unused, invalid
                         LPM_INVALID6,     -- 16#6#, unused, invalid
                         LPM_INVALID7,     -- 16#7#, unused, invalid
                         LPM_INVALID8,     -- 16#8#, unused, invalid
                         LPM_INVALID9,     -- 16#9#, unused, invalid
                         LPM_INVALID10,     -- 16#A#, unused, invalid
                         LPM_INVALID11,     -- 16#B#, unused, invalid
                         LPM_INVALID12,     -- 16#C#, unused, invalid
                         LPM_INVALID13,     -- 16#D#, unused, invalid
                         LPM_INVALID14,     -- 16#E#, unused, invalid
                         LPM_INVALID15      -- 16#F#, unused, invalid
                         );

-- File>>> Pid.def.vhd
--
-- Generated by: AccessVHDL
----
---- Copyright(c) 1995 by Easics NV. All rights reserved.
----
----   This source file is proprietary and confidential information
----   of Easics NV and may be used and disclosed only as authorized
----   in a consulting and/or subcontracting agreement where the
----   source code is part of the statement of work specified in
----   the agreement, or if Easics NV has given it's written consent
----   to such use or disclosure.
----   This source file remains the sole property of
----        Easics NV, Kapeldreef 60, B-3001 Leuven, Belgium.
----
-- Current user: Jan Zegers                        08/95 tijdel. NO ITCL
-- Current date: Tue Aug 22 16:44:25 1995
--

  -- 
  -- Definitions for Pid RAM
  --   Words x Bits = 0 x 8
  --     Field InvVal of 4 bits at offset 4.
  --     Field Val of 4 bits at offset 0.
  --   Layout of data fields:
  --
  -- +----------+----------+
  -- +InvVal    |Val       |
  -- +7 downto 4|3 downto 0|
  -- +----------+----------+
  --
  -- 
  constant Pid_DATAWIDTH: integer := 8;
  subtype S_Pid_DATAWIDTH_bits is
          unsigned (Pid_DATAWIDTH - 1 downto 0);
  constant Pid_InvVal_OFFSET: integer := 4;
  constant Pid_InvVal_LENGTH: integer := 4;
  subtype S_Pid_InvVal_busrange is
          integer range Pid_InvVal_OFFSET +
                        Pid_InvVal_LENGTH - 1 downto
                        Pid_InvVal_OFFSET;
  subtype S_Pid_InvVal_bitrange is
          integer range Pid_InvVal_LENGTH - 1 downto 0;
  subtype S_Pid_InvVal_bits is
          unsigned (S_Pid_InvVal_bitrange);
  function GetPidInvVal (BusData: S_Pid_DATAWIDTH_bits)
           return S_Pid_InvVal_bits;
  function PutPidInvVal (BusData: S_Pid_DATAWIDTH_bits;
                         InvVal: S_Pid_InvVal_bits)
           return S_Pid_DATAWIDTH_bits;
  constant Pid_Val_OFFSET: integer := 0;
  constant Pid_Val_LENGTH: integer := 4;
  subtype S_Pid_Val_busrange is
          integer range Pid_Val_OFFSET +
                        Pid_Val_LENGTH - 1 downto
                        Pid_Val_OFFSET;
  subtype S_Pid_Val_bitrange is
          integer range Pid_Val_LENGTH - 1 downto 0;
  subtype S_Pid_Val_bits is
          unsigned (S_Pid_Val_bitrange);
  function GetPidVal (BusData: S_Pid_DATAWIDTH_bits)
           return S_Pid_Val_bits;
  function PutPidVal (BusData: S_Pid_DATAWIDTH_bits;
                      Val: S_Pid_Val_bits)
           return S_Pid_DATAWIDTH_bits;

-- End of Pid.def.vhd ------------------------------------------

  function DecodePidVal (Pid: S_Pid_Val_bits)
           return T_Pid_enum;
  function DecodeLPMPidVal (Pid: S_Pid_Val_bits)
           return T_SubPid_enum; 
  function EncodePidVal (Pid: T_Pid_enum)
           return S_Pid_Val_bits;
  function DecodePid (Pid: S_Pid_DATAWIDTH_bits)
           return T_Pid_enum;
  function DecodeLPMPid (Pid: S_Pid_DATAWIDTH_bits)
           return T_SubPid_enum;
  function EncodeLPMSubPidVal (Pid: T_SubPid_enum)
           return S_Pid_Val_bits;
  function EncodePid (Pid: T_Pid_enum)
           return S_Pid_DATAWIDTH_bits;
  function EncodeLPMSubPid (Pid: T_SubPid_enum)
           return S_Pid_DATAWIDTH_bits;
  -- Function PidOk checks whether the encoding of the Pid is ok
  -- ie. the Val field is the one's complement of the InvVal field
  function PidOk (Pid: S_Pid_DATAWIDTH_bits)
           return boolean;

  -- Procedure CheckPid first checks whether the DataWord
  -- given is a valid PID encoded word, ie. the Val field should
  -- be equal to the one's complement of the InvVal (PidOk).
  -- If it is not, the Error is set TRUE, the PidType is
  -- set to PID_INVALID and ErrorType is set ERROR_PID_ENCODING.
  -- If the encoding is correct and the pid decoding returns
  -- an undefined or invalid pid, PidType is set to PID_INVALID
  -- Error is set TRUE, and ErrorType is set ERROR_PID_UNKNOWN.
  -- Otherwise, the correct PidType is returned with Error FALSE
  -- and ErrorType is not set.
  procedure CheckPid (DataWord:   in S_UsbWord_bits;
                      PidType:   out T_Pid_enum;
                      Error:     out boolean;
                      ErrorType: out T_PACKET_ERROR_enum);

  procedure CheckLPMPid (DataWord: in S_UsbWord_bits;
                         SubPidType: out T_SubPid_enum;
                         Error:      out boolean;
                         ErrorType: out T_PACKET_ERROR_enum);
  -- function IsValidPid return TRUE if the PidType is one
  -- of the defined PIDs of T_Pid_enum (not PID_UNKNOWN,
  -- PID_RESERVED_? or PID_ERR).
  function IsValidPid (PidType: T_Pid_enum)
           return boolean;

  -----------------------------------------------------------------
  -- Packet types: token, data, handshake, special
  -- token packets:     IN, OUT, SOF, SETUP  (pid ending in "01")
  -- data packets:      DATA0, DATA1         (pid ending in "11")
  -- handshake packets: ACK, NAK, STALL      (pid ending in "10")
  -- special packets:   PRE                  (pid ending in "00")
  -----------------------------------------------------------------
  type T_LPM_Packet_enum is (PACKET_SPECIAL,      -- "00"
                             PACKET_LPM_TOKEN,    -- "01"
                             PACKET_HANDSHAKE,    -- "10"
                             PACKET_DATA);        -- "11"

  type T_Packet_enum is (PACKET_SPECIAL,      -- "00"
                         PACKET_TOKEN,        -- "01"
                         PACKET_HANDSHAKE,    -- "10"
                         PACKET_DATA);        -- "11"
  subtype S_Packet_bits is two_bits;
  function DecodePacket (PacketType: S_Packet_bits)
           return T_Packet_enum;
  function EncodePacket (PacketType: T_Packet_enum)
           return S_Packet_bits;
  function PidToPacket (Pid: T_Pid_enum)
           return T_Packet_enum;
  function SubPidToPacket (Pid: T_SubPid_enum)
           return T_LPM_Packet_enum;
  procedure CheckPidPacket (DataWord:    in S_UsbWord_bits;
                            ExpPacket:   in T_Packet_enum;
                            PidType:    out T_Pid_enum;
                            PacketType: out T_Packet_enum;
                            Error:      out boolean;
                            ErrorType:  out T_PACKET_ERROR_enum);
  procedure CheckSubPidPacket (DataWord:   in S_UsbWord_bits;
                               ExpPacket:   in T_LPM_Packet_enum;
                               SubPidType:  out T_SubPid_enum;
                               PacketType: out T_LPM_Packet_enum;
                               Error:      out boolean;
                               ErrorType:  out T_PACKET_ERROR_enum); 

  -----------------------------------------------------------------
  -- Return TRUE is PidType is of a given Packet class
  -----------------------------------------------------------------
  function IsTokenPid (PidType: T_Pid_enum)
           return boolean;
  function IsDataPid (PidType: T_Pid_enum)
           return boolean;
  function IsHandshakePid (PidType: T_Pid_enum)
           return boolean;
  function IsSpecialPid (PidType: T_Pid_enum)
           return boolean;

  -----------------------------------------------------------------
  -- Transaction types are: bulk, control, interrupt and isochronous
  -- TR_BULK   bulk transactions        use IN/OUT PIDs
  -- TR_SETUP  control transactions     use SETUP/[IN-OUT]*/OUT-IN PIDs
  -- TR_IRQ    interrupt transactions   use IN PIDs
  -- TR_ISO    isochronous transactions use IN/OUT PIDs
  -----------------------------------------------------------------
  type T_Transaction_enum is (TR_BULK,
                              TR_SETUP,
                              TR_IRQ,
                              TR_ISO);
  subtype S_Transaction_bits is two_bits;
  function EncodeTransaction (TrType: T_Transaction_enum)
           return S_Transaction_bits;
  function DecodeTransaction (TrType: S_Transaction_bits)
           return T_Transaction_enum;

  -----------------------------------------------------------------
  -- CRC type encoding (token = CRC5, data = CRC16)
  -----------------------------------------------------------------
  type T_UsbCrc_enum is (USBCRC_TOKEN,
                         USBCRC_DATA);
  subtype S_UsbCrc_bits is one_bit;
  function EncodeUsbCrc (CrcType: T_UsbCrc_enum)
           return S_UsbCrc_bits;
  function DecodeUsbCrc (CrcType: S_UsbCrc_bits)
           return T_UsbCrc_enum;

  -----------------------------------------------------------------
  -- General CRC functions
  -----------------------------------------------------------------
  function OneBitCRC (Data: one_bit;
                      CRC: unsigned;
                      Polynomial: bit_vector) return unsigned;
  function MultiBitCRC (Data: unsigned;
                        CRC: unsigned;
                        Polynomial: bit_vector) return unsigned;
  function CalcSyndrome (CodeWord: unsigned;
                         CRC_Matrix: unsigned;
                         CRC_Degree: natural;
                         Coset: unsigned) return unsigned;
  function SyndromePosition(Syndrome: unsigned;
                            CRC_Matrix: unsigned) return integer;

  -----------------------------------------------------------------
  -- USB specific CRC functions
  --   The CRCs are given for bit-serial and byte-parallel operation
  --   to allow the designer to select where the CRC calculation
  --   will take place (low-level interface bit-serial, protocol
  --   manager byte-parallel).
  -----------------------------------------------------------------
  -- Token CRC5 is G(x) = x^5 + x^2 + 1
  -- Functions are given for calculating the CRC5 in a
  -- bit-serial fashion (function MultipleCRC5_D1) and
  -- for calculating the CRC5 on the full 11 bit at once.
  -- (7 bit device address and 4 bit end-point address)
  -- Function SingleCRC5_D11 calculates the CRC5 over the
  -- 11 data bits, MultipleCRC5_D11 allows to initialize the
  -- CRC5 to a specific value and then to calculate the
  -- CRC5 starting from that value.
  -----------------------------------------------------------------

  -- Residual for CRC5
  constant CRC5_RESIDUAL: unsigned(4 downto 0) := "01100";

  -- CRC5 with message length equal 1
  constant CRC5_D1_MATRIX: unsigned(29 downto 0) :=
    "010000" &
    "001000" &
    "100100" &
    "000010" &
    "100001";

  -- CRC5 with message length equal 11
  constant CRC5_D11_MATRIX: unsigned(79 downto 0) :=
    "1110011010010000" &
    "1111001101001000" &
    "1111100110100100" &
    "1001101001000010" &
    "1100110100100001";

  -- Multiple CRC5 with message length 1 bits
  function MultipleCRC5_D1 (D: one_bit;
                            CRC: five_bits) return five_bits;
  -- Multiple CRC5 with message length 11 bits
  function MultipleCRC5_D11 (D: eleven_bits;
                            CRC: five_bits) return five_bits;
  -- Single CRC5 with message length 11 bits
  function SingleCRC5_D11 (D: eleven_bits)
           return five_bits;

  -----------------------------------------------------------------
  -- Data packet CRC16 is G(x) = x^16 + x^15 + x^2 + 1
  -- Functions are given for calculating the CRC16 in a
  -- bit-serial fashion (function MultipleCRC16_D1) and
  -- for calculating the CRC16 on the consecutive bytes
  -- (function MultipleCRC16_D8).
  -----------------------------------------------------------------

  -- Residual for CRC16
  constant CRC16_RESIDUAL: unsigned(15 downto 0) := "1000000000001101";

  -- CRC16 with message length equal 1
  constant CRC16_D1_MATRIX: unsigned(271 downto 0) :=
    "11000000000000000" &
    "00100000000000000" &
    "00010000000000000" &
    "00001000000000000" &
    "00000100000000000" &
    "00000010000000000" &
    "00000001000000000" &
    "00000000100000000" &
    "00000000010000000" &
    "00000000001000000" &
    "00000000000100000" &
    "00000000000010000" &
    "00000000000001000" &
    "10000000000000100" &
    "00000000000000010" &
    "10000000000000001";

  -- CRC16 with message length equal 8
  constant CRC16_D8_MATRIX: unsigned(383 downto 0) :=
    "111111111000000000000000" &
    "000000000100000000000000" &
    "000000000010000000000000" &
    "000000000001000000000000" &
    "000000000000100000000000" &
    "000000000000010000000000" &
    "100000000000001000000000" &
    "110000000000000100000000" &
    "011000000000000010000000" &
    "001100000000000001000000" &
    "000110000000000000100000" &
    "000011000000000000010000" &
    "000001100000000000001000" &
    "000000110000000000000100" &
    "111111100000000000000010" &
    "111111110000000000000001";

  -- Multiple CRC16 with message length 1 bits
  function MultipleCRC16_D1 (D: one_bit;
                            CRC: two_bytes) return two_bytes;
  -- Multiple CRC16 with message length 8 bits
  function MultipleCRC16_D8 (D: byte;
                            CRC: two_bytes) return two_bytes;

end usb_subcmp_pkg;

package body usb_subcmp_pkg is

  function IsDevAddr (DevAddr:     S_DevAddr_range;
                      EndpAddr:    S_EndpAddr_range;
                      ThisDevAddr: S_DevAddr_range;
                      ActiveEndps: S_EndpAddr_booleans;
                      DevConf:     boolean)
           return boolean is
  begin
    if (not DevConf) then
      if (DevAddr = DEFAULT_DEVICE_ADDRESS) then
        return TRUE;
      else
        return FALSE;
      end if;
    else
      if (DevAddr /= ThisDevAddr) then
        return FALSE;
      else
        if (ActiveEndps(EndpAddr)) then
          return TRUE;
        else
          return FALSE;
        end if;
      end if;
    end if;
  end IsDevAddr;

  function ConvertAddrToTime (DevAddr: S_DevAddr_range;
                              EndpAddr: S_EndpAddr_range)
           return S_FRAME_TIME_range is
  begin
    assert (MAX_DEVICE_ADDRESS * MAX_ENDPOINT_ADDRESS > FRAME_TIME)
      report "ConvertAddrToTime problem"
      severity note;
    assert (DevAddr_ADDRWIDTH + EndpAddr_ADDRWIDTH /= FRAME_TIME_WIDTH)
      report "ConvertAddrToTime not possible"
      severity note;
    return (DevAddr * (2**EndpAddr_ADDRWIDTH)) + EndpAddr;
  end ConvertAddrToTime;

  function DecodeUsbSpeed (SpeedType: one_bit)
           return T_UsbSpeed_enum is
  begin
    case SpeedType is
      when LOW =>
        return USB_FULL_SPEED;
      when HIGH =>
        return USB_LOW_SPEED;
      when others =>
        assert false report "Error Not implemented" severity error;
    end case; -- SpeedType
  end DecodeUsbSpeed;

  function EncodeUsbSpeed (SpeedType: T_UsbSpeed_enum)
           return one_bit is
  begin
    case SpeedType is
      when USB_FULL_SPEED =>
        return LOW;
      when USB_LOW_SPEED =>
        return HIGH;
      when others =>
        assert false report "Error Not implemented" severity error; 
    end case; -- SpeedType
  end EncodeUsbSpeed;

  function GetFrameLength(Speed: T_UsbSpeed_enum) 
           return integer is
  begin
    case Speed is
      when USB_FULL_SPEED =>
        return FRAMELENGTH_FS;
      when USB_LOW_SPEED =>
        return FRAMELENGTH_LS;
      when others =>
        assert false report "Error Not implemented" severity error;  
    end case;
  end GetFrameLength;

  function UsbDif2Log (DifInput:  two_bits;
                       SpeedType: T_UsbSpeed_enum)
           return T_UsbLog_enum is
  begin
    case DifInput is
      when "00" =>
        return USB_LOG_SE0;
      when "01" =>
        case SpeedType is
          when USB_FULL_SPEED =>
            return USB_LOG_K;
          when USB_LOW_SPEED =>
            return USB_LOG_J;
          when others =>
            assert false report "Error Not implemented" severity error;  
        end case; -- SpeedType
      when "10" =>
        case SpeedType is
          when USB_FULL_SPEED =>
            return USB_LOG_J;
          when USB_LOW_SPEED =>
            return USB_LOG_K;
          when others =>
            assert false report "Error Not implemented" severity error;    
        end case; -- SpeedType
      when others =>
        return USB_LOG_SE1_OR_Z;
    end case; -- DifInput
  end UsbDif2Log;

  function UsbBus2Log (DifInput:  one_bit;
                       LineInput: two_bits;
                       SpeedType: T_UsbSpeed_enum)
           return T_UsbLog_enum is
  begin
    if LineInput = two_bits'("00") then
      return USB_LOG_SE0;
    elsif DifInput ='1' then
      case SpeedType is
        when USB_FULL_SPEED =>
          return USB_LOG_J;
        when USB_LOW_SPEED =>
          return USB_LOG_K;
        when others =>
          assert false report "Error Not implemented" severity error;   
      end case; -- SpeedType
    else
      case SpeedType is
        when USB_FULL_SPEED =>
          return USB_LOG_K;
        when USB_LOW_SPEED =>
          return USB_LOG_J;
        when others =>
          assert false report "Error Not implemented" severity error;   
      end case; -- SpeedType
    end if;
  end UsbBus2Log;
      
  function UsbLog2Dif (LogInput:  T_UsbLog_enum;
                       SpeedType: T_UsbSpeed_enum)
           return two_bits is
  begin
    case LogInput is
      when USB_LOG_SE0 =>
        return "00";
      when USB_LOG_J =>
        case SpeedType is
          when USB_FULL_SPEED =>
            return "10";
          when USB_LOW_SPEED =>
            return "01";
          when others =>
            assert false report "Error Not implemented" severity error;   
        end case; -- SpeedType
      when USB_LOG_K =>
        case SpeedType is
          when USB_FULL_SPEED =>
            return "01";
          when USB_LOW_SPEED =>
            return "10";
          when others =>
            assert false report "Error Not implemented" severity error;   
        end case; -- SpeedType
      when USB_LOG_SE1_OR_Z =>
        return "11";
      when others =>
        assert false report "Error Not implemented" severity error;   
    end case; -- UsbLogInput
  end UsbLog2Dif;

  function StartOfPacket (PrevLogVal: T_UsbLog_enum;
                          CurrLogVal: T_UsbLog_enum)
           return boolean is
  begin
    --if ((PrevLogVal = USB_LOG_J) and (CurrLogVal = USB_LOG_K)) then
    if ((PrevLogVal = USB_LOG_J or PrevLogVal=USB_LOG_SE1_OR_Z) and (CurrLogVal = USB_LOG_K)) then
      return TRUE;
    else
      return FALSE;
    end if;
  end StartOfPacket;

  function EndOfPacket (CurrLogVal: T_UsbLog_enum)
           return boolean is
  begin
    if (CurrLogVal = USB_LOG_SE0) then
      return TRUE;
    else
      return FALSE;
    end if;
  end EndOfPacket;

  function DecodeNRZI (PrevLogVal: T_UsbLog_enum;
                       CurrLogVal: T_UsbLog_enum)
           return one_bit is
  begin
    if (((PrevLogVal = USB_LOG_J) and (CurrLogVal = USB_LOG_K)) or
        ((PrevLogVal = USB_LOG_K) and (CurrLogVal = USB_LOG_J))) then
      return LOW;
    elsif (((PrevLogVal = USB_LOG_J) and (CurrLogVal = USB_LOG_J)) or
           ((PrevLogVal = USB_LOG_K) and (CurrLogVal = USB_LOG_K))) then
      return HIGH;
    else
      assert ((PrevLogVal = USB_LOG_SE0) or (CurrLogVal = USB_LOG_SE0))
        report "Invalid values in DecodeNRZI"
        severity note;
      return LOW;
    end if;
  end DecodeNRZI;

  function EncodeNRZI (PrevLogVal: T_UsbLog_enum;
                       CurrDataVal: one_bit)
           return T_UsbLog_enum is
    variable Result: T_UsbLog_enum;
  begin
    -- By default we return the PrevLogVal
    Result := PrevLogVal;
    if ((PrevLogVal = USB_LOG_J) and (CurrDataVal = LOW)) then
      Result := USB_LOG_K;
    elsif ((PrevLogVal = USB_LOG_K) and (CurrDataVal = LOW)) then
      Result := USB_LOG_J;
    end if;
    return Result;
  end EncodeNRZI;

  function IncStuffedBitCnt (BitValue: one_bit)
           return boolean is
  begin
    if (BitValue = BITSTUFF_VALUE) then
      return TRUE;
    else
      return FALSE;
    end if;
  end IncStuffedBitCnt;

  function IsStuffedBit (BitValue:    one_bit;
                         BitStuffCnt: S_BitStuff_range)
           return boolean is
  begin
    if ((BitStuffCnt = BITSTUFF_LENGTH) and
        (BitValue = (not BITSTUFF_VALUE))) then
      return TRUE;
    else
      return FALSE;
    end if;
  end IsStuffedBit;

  function IsBitStuffError (BitValue: one_bit;
                            BitStuffCnt: S_BitStuff_range)
           return boolean is
  begin
    if ((BitValue = BITSTUFF_VALUE) and
        (BitStuffCnt = BITSTUFF_LENGTH)) then
      return TRUE;
    else
      return FALSE;
    end if;
  end IsBitStuffError;

  procedure DeStuff (BitValue:        in one_bit;
                     BitStuffCnt:     in S_BitStuff_range;
                     BitStuffError:  out boolean;
                     StuffedBit:     out boolean;
                     NewBitStuffCnt: out S_BitStuff_range) is
  begin
    BitStuffError  := FALSE;
    StuffedBit     := FALSE;
    if (BitStuffCnt = BITSTUFF_LENGTH) then
      if (BitValue = BITSTUFF_VALUE) then
        -- sequence of BITSTUFF_VALUE too long
        BitStuffError  := TRUE;
        NewBitStuffCnt := BitStuffCnt; -- keep value at max
      else
        -- Stuffed bit found, reset count
        StuffedBit     := TRUE;
        NewBitStuffCnt := 0;
      end if;
    else
      if (BitValue = BITSTUFF_VALUE) then
        NewBitStuffCnt := BitStuffCnt + 1;
      else
        NewBitStuffCnt := 0;
      end if;
    end if;
  end DeStuff;

  -- Procedure Stuff will determine based on the current BitValue
  -- and the current number of bits with BITSTUFF_VALUE whether:
  --   a bitstuff error has to be forced
  --   whether this bit position should be stuffed
  --   and a new BitStuffCnt value
  procedure Stuff (BitValue:        in one_bit;
                   BitStuffCnt:     in S_BitStuff_range;
                   BitStuffError:   in boolean;
                   StuffedBit:     out boolean;
                   NewBitStuffCnt: out S_BitStuff_range) is
  begin
    StuffedBit := FALSE;
    if ((BitStuffCnt = BITSTUFF_LENGTH) or (BitStuffError)) then
      StuffedBit := TRUE;
      NewBitStuffCnt := 0;
    else
      if (BitValue = BITSTUFF_VALUE) then
        NewBitStuffCnt := BitStuffCnt + 1;
      else
        NewBitStuffCnt := 0;
      end if;
    end if;
  end Stuff;

-- File>>> Pid.fnc.vhd
--
-- Generated by: AccessVHDL
----
---- Copyright(c) 1995 by Easics NV. All rights reserved.
----
----   This source file is proprietary and confidential information
----   of Easics NV and may be used and disclosed only as authorized
----   in a consulting and/or subcontracting agreement where the
----   source code is part of the statement of work specified in
----   the agreement, or if Easics NV has given it's written consent
----   to such use or disclosure.
----   This source file remains the sole property of
----        Easics NV, Kapeldreef 60, B-3001 Leuven, Belgium.
----
-- Current user: Jan Zegers                        08/95 tijdel. NO ITCL
-- Current date: Tue Aug 22 16:44:25 1995
--

  function GetPidInvVal (BusData: S_Pid_DATAWIDTH_bits)
           return S_Pid_InvVal_bits is
    variable Result: S_Pid_InvVal_bits;
  begin
    Result := BusData (S_Pid_InvVal_busrange);
    return Result;
  end GetPidInvVal;

  function PutPidInvVal (BusData: S_Pid_DATAWIDTH_bits;
                         InvVal: S_Pid_InvVal_bits)
           return S_Pid_DATAWIDTH_bits is
    variable Result: S_Pid_DATAWIDTH_bits;
  begin
    Result := BusData;
    Result (S_Pid_InvVal_busrange) := InvVal;
    return Result;
  end PutPidInvVal;

  function GetPidVal (BusData: S_Pid_DATAWIDTH_bits)
           return S_Pid_Val_bits is
    variable Result: S_Pid_Val_bits;
  begin
    Result := BusData (S_Pid_Val_busrange);
    return Result;
  end GetPidVal;

  function PutPidVal (BusData: S_Pid_DATAWIDTH_bits;
                      Val: S_Pid_Val_bits)
           return S_Pid_DATAWIDTH_bits is
    variable Result: S_Pid_DATAWIDTH_bits;
  begin
    Result := BusData;
    Result (S_Pid_Val_busrange) := Val;
    return Result;
  end PutPidVal;

-- End of Pid.fnc.vhd -------------------------------------------

  -- DecodePidVal returns PID_INVALID for undefined PIDs
  -- otherwise the correct enumerated value
  function DecodePidVal (Pid: S_Pid_Val_bits)
           return T_Pid_enum is
  begin
    case Pid is
      when "0000" =>
        return PID_LPM;  -- earlier PID_INVALID
      when "0001" =>
        return PID_OUT;
      when "0010" =>
        return PID_ACK;
      when "0011" =>
        return PID_DATA0;
      when "0100" =>
        return PID_INVALID; -- PID_RESERVED_1;
      when "0101" =>
        return PID_SOF;
      when "0110" =>
        return PID_NYET; -- previous to 1.0 was return PID_ERR;
                         -- earlier PID_INVALID
      when "0111" =>
        return PID_INVALID; -- PID_RESERVED_2;
      when "1000" =>
        return PID_INVALID; -- PID_RESERVED_3;
      when "1001" =>
        return PID_IN;
      when "1010" =>
        return PID_NAK;
      when "1011" =>
        return PID_DATA1;
      when "1100" =>
        return PID_PRE;
      when "1101" =>
        return PID_SETUP;
      when "1110" =>
        return PID_STALL;
      when "1111" =>
        return PID_INVALID; -- PID_RESERVED_4;
      when others =>
        return PID_INVALID;
    end case; -- Pid
  end DecodePidVal;

-- DecodeLPMPidVal returns PID_INVALID for undefined SubPIDs
  -- otherwise the correct enumerated value
  function DecodeLPMPidVal (Pid: S_Pid_Val_bits)
           return T_SubPid_enum is
  begin
    case Pid is
      when "0011" => 
        return LPM_SubPID;
      when others =>
        return LPM_INVALID0;
    end case;
  end DecodeLPMPidVal;



  -- Note that PID_ERR is still converted although in version 1.0
  -- it should be considered as invalid and undefined.
  function EncodePidVal (Pid: T_Pid_enum)
           return S_Pid_Val_bits is
  begin
    case Pid is
      when PID_LPM =>  
        return "0000";
      when PID_OUT =>
        return "0001";
      when PID_ACK =>
        return "0010";
      when PID_DATA0 =>
        return "0011";
      when PID_RESERVED_1 =>
        return "0100";
      when PID_SOF =>
        return "0101";
      when PID_NYET =>
        return "0110"; -- earlier PID_ERR
      when PID_RESERVED_2 =>
        return "0111";
      when PID_ERR =>
        return "1000"; -- earlier PID_RESERVED_3
      when PID_IN =>
        return "1001";
      when PID_NAK =>
        return "1010";
      when PID_DATA1 =>
        return "1011";
      when PID_PRE =>
        return "1100";
      when PID_SETUP =>
        return "1101";
      when PID_STALL =>
        return "1110";
      when PID_INVALID =>
        return "1111"; -- earlier PID_RESERVED_4
      when others =>
        assert false report "Error Not implemented" severity error;   
    end case; -- Pid
  end EncodePidVal;

  function EncodeLPMSubPidVal (Pid: T_SubPid_enum)
           return S_Pid_Val_bits is
  begin
    case Pid is
      when LPM_SubPID =>  
        return "0011"; -- earlier PID_INVALID 
      when others =>
        return "1111";
    end case;
  end EncodeLPMSubPidVal;

  function DecodePid (Pid: S_Pid_DATAWIDTH_bits)
           return T_Pid_enum is
    variable PidVal: S_Pid_Val_bits;
  begin
    PidVal := Pid(S_Pid_Val_busrange);
    return DecodePidVal(PidVal);
  end DecodePid;

 function DecodeLPMPid (Pid: S_Pid_DATAWIDTH_bits)
           return T_SubPid_enum is
    variable PidVal: S_Pid_Val_bits;
  begin
    PidVal := Pid(S_Pid_Val_busrange);
    return DecodeLPMPidVal(PidVal);
  end DecodeLPMPid;

  function EncodePid (Pid: T_Pid_enum)
           return S_Pid_DATAWIDTH_bits is
    variable Result: S_Pid_DATAWIDTH_bits;
    variable PidVal: S_Pid_Val_bits;
  begin
    Result := (others => '0');
    PidVal := EncodePidVal(Pid);
    Result(S_Pid_Val_busrange)    := PidVal;
    Result(S_Pid_InvVal_busrange) := (not PidVal);
    return Result;
  end EncodePid;

  function EncodeLPMSubPid (Pid: T_SubPid_enum)
           return S_Pid_DATAWIDTH_bits is
    variable Result: S_Pid_DATAWIDTH_bits;
    variable PidVal: S_Pid_Val_bits;
  begin
    Result := (others => '0');
    PidVal := EncodeLPMSubPidVal(Pid);
    Result(S_Pid_Val_busrange)    := PidVal;
    Result(S_Pid_InvVal_busrange) := (not PidVal);
    return Result;
  end EncodeLPMSubPid;

  function PidOk (Pid: S_Pid_DATAWIDTH_bits)
           return boolean is
    variable PidVal: S_Pid_Val_bits;
    variable PidInvVal: S_Pid_InvVal_bits;
  begin
    PidVal    := GetPidVal(Pid);
    PidInvVal := GetPidInvVal(Pid);
    if (PidVal = (not PidInvVal)) then
      return TRUE;
    else
      return FALSE;
    end if;
  end PidOk;

  procedure CheckPid (DataWord:   in S_UsbWord_bits;
                      PidType:   out T_Pid_enum;
                      Error:     out boolean;
                      ErrorType: out T_PACKET_ERROR_enum) is
    variable TmpPid: T_Pid_enum;
  begin
    if (PidOk(DataWord)) then
      TmpPid := DecodePid(DataWord);
      case TmpPid is
      -- removed PID_RESERVED_3 and PID_RESERVED_4 for LPM
        when PID_INVALID | PID_RESERVED_1 | PID_RESERVED_2 | PID_ERR =>
          PidType   := PID_INVALID;
          Error     := TRUE;
          ErrorType := ERROR_PID_UNKNOWN;
        when others =>
          PidType  := TmpPid;
          Error    := FALSE;
      end case; -- PidType;
    else
      PidType   := PID_INVALID;
      Error     := TRUE;
      ErrorType := ERROR_PID_ENCODING;
    end if;
  end CheckPid;

  procedure CheckLPMPid (DataWord: in S_UsbWord_bits;
                         SubPidType: out T_SubPid_enum;
                         Error:      out boolean;
                         ErrorType: out T_PACKET_ERROR_enum) is
    variable TmpPid: T_SubPid_enum;
   begin
    if (PidOk(DataWord)) then
        TmpPid := DecodeLPMPid(DataWord);
        case TmpPid is
          when LPM_SubPID =>
            SubPidType := TmpPid;
            Error      := FALSE;
          when others =>
            SubPidType := LPM_INVALID0;
            Error      := TRUE;
            ErrorType  := ERROR_PID_UNKNOWN;
        end case;   
    else
      SubPidType:= LPM_INVALID0;
      Error     := TRUE;
      ErrorType := ERROR_PID_ENCODING;
    end if;
  end CheckLPMPid;                         

  function IsValidPid (PidType: T_Pid_enum)
           return boolean is
  begin
    case PidType is
    -- removed PID_RESERVED_3 and PID_RESERVED_4 for LPM
      when PID_INVALID | PID_RESERVED_1 | PID_RESERVED_2 | PID_ERR =>
        return FALSE;
      when others =>
        return TRUE;
    end case;
  end IsValidPid;

  function DecodePacket (PacketType: S_Packet_bits)
           return T_Packet_enum is
  begin
    case PacketType is
      when "00" =>
        return PACKET_SPECIAL;
      when "01" =>
        return PACKET_TOKEN;
      when "10" =>
        return PACKET_HANDSHAKE;
      when "11" =>
        return PACKET_DATA;
      when others =>
        return PACKET_HANDSHAKE;
    end case; -- PacketType
  end DecodePacket;

  function EncodePacket (PacketType: T_Packet_enum)
           return S_Packet_bits is
  begin
    case PacketType is
      when PACKET_SPECIAL =>
        return "00";
      when PACKET_TOKEN =>
        return "01";
      when PACKET_HANDSHAKE =>
        return "10";
      when PACKET_DATA =>
        return "11";
      when others =>
        assert false report "Error Not implemented" severity error;   
    end case; -- PacketType
  end EncodePacket;

  function PidToPacket (Pid: T_Pid_enum)
           return T_Packet_enum is
  begin
    case Pid is
      when PID_IN | PID_OUT | PID_SOF | PID_SETUP | PID_LPM =>
        return PACKET_TOKEN;
      when PID_DATA0 | PID_DATA1 =>
        return PACKET_DATA;
      when PID_PRE =>
        return PACKET_SPECIAL;
      when PID_ACK | PID_NAK | PID_STALL | PID_NYET =>
        return PACKET_HANDSHAKE;
    -- removed PID_RESERVED_3 and PID_RESERVED_4 for LPM
      when PID_INVALID | PID_RESERVED_1 | PID_RESERVED_2 | PID_ERR =>
        assert FALSE
          report "Calling PidToPacket for invalid Pid"
          severity note;
        return PACKET_HANDSHAKE;
      when others =>
        assert false report "Error Not implemented" severity error;   
    end case; -- Pid
  end PidToPacket;

 function SubPidToPacket (Pid: T_SubPid_enum)
           return T_LPM_Packet_enum is
  begin
    case Pid is
      when LPM_SubPID =>
        return PACKET_LPM_TOKEN;
      when others =>
        assert FALSE
          report "Calling PidToPacket for invalid Pid"
          severity note;
        return PACKET_HANDSHAKE;
    end case; -- Pid
  end SubPidToPacket;

  procedure CheckPidPacket (DataWord:    in S_UsbWord_bits;
                            ExpPacket:   in T_Packet_enum;
                            PidType:    out T_Pid_enum;
                            PacketType: out T_Packet_enum;
                            Error:      out boolean;
                            ErrorType:  out T_PACKET_ERROR_enum) is
    variable IntError: boolean;
    variable IntPidType: T_Pid_enum;
    variable IntPacketType: T_Packet_enum;
  begin
    CheckPid(DataWord, IntPidType, IntError, ErrorType);
    if (IntError) then
      Error      := TRUE;
      PacketType := PACKET_HANDSHAKE; -- value is in fact don't care
    else
      IntPacketType := PidToPacket(IntPidType);
      if (ExpPacket /= IntPacketType) and 
        not (ExpPacket = PACKET_TOKEN and IntPacketType = PACKET_SPECIAL) then
        Error      := TRUE;
        ErrorType  := ERROR_PACKET_UNEXPECTED;
      else
        Error      := FALSE;
      end if;
      PacketType := IntPacketType;
    end if;
    PidType := IntPidType;
  end CheckPidPacket;

  procedure CheckSubPidPacket (DataWord:    in S_UsbWord_bits;
                               ExpPacket:   in T_LPM_Packet_enum;
                               SubPidType:  out T_SubPid_enum;
                               PacketType: out T_LPM_Packet_enum;
                               Error:      out boolean;
                               ErrorType:  out T_PACKET_ERROR_enum) is
    variable IntError: boolean;
    variable IntPidType: T_SubPid_enum;
    variable IntPacketType: T_LPM_Packet_enum;
  begin
    CheckLPMPid(DataWord, IntPidType, IntError, ErrorType);
    if (IntError) then
      Error      := TRUE;
      PacketType := PACKET_HANDSHAKE; -- value is in fact don't care
    else
      IntPacketType := SubPidToPacket(IntPidType);
      if (ExpPacket /= IntPacketType)  then
            Error      := TRUE;
            ErrorType  := ERROR_PACKET_UNEXPECTED;
      else
            Error      := FALSE;
      end if;
      PacketType := IntPacketType;
    end if;
      SubPidType := IntPidType;
  end CheckSubPidPacket;

  function IsTokenPid (PidType: T_Pid_enum)
           return boolean is
  begin
    if (IsValidPid(PidType) = FALSE) then
      return FALSE;
    elsif (PidToPacket(PidType) = PACKET_TOKEN) then
      return TRUE;
    else
      return FALSE;
    end if;
  end IsTokenPid;

  function IsDataPid (PidType: T_Pid_enum)
           return boolean is
  begin
    if (IsValidPid(PidType) = FALSE) then
      return FALSE;
    elsif (PidToPacket(PidType) = PACKET_DATA) then
      return TRUE;
    else
      return FALSE;
    end if;
  end IsDataPid;

  function IsHandshakePid (PidType: T_Pid_enum)
           return boolean is
  begin
    if (IsValidPid(PidType) = FALSE) then
      return FALSE;
    elsif (PidToPacket(PidType) = PACKET_HANDSHAKE) then
      return TRUE;
    else
      return FALSE;
    end if;
  end IsHandshakePid;

  function IsSpecialPid (PidType: T_Pid_enum)
           return boolean is
  begin
    if (IsValidPid(PidType) = FALSE) then
      return FALSE;
    elsif (PidToPacket(PidType) = PACKET_SPECIAL) then
      return TRUE;
    else
      return FALSE;
    end if;
  end IsSpecialPid;

  function EncodeTransaction (TrType: T_Transaction_enum)
           return S_Transaction_bits is
  begin
    case TrType is
      when TR_BULK =>
        return "00";
      when TR_SETUP =>
        return "01";
      when TR_IRQ =>
        return "10";
      when TR_ISO =>
        return "11";
      when others =>
        assert false report "Error Not implemented" severity error;   
    end case; -- TrType
  end EncodeTransaction;

  function DecodeTransaction (TrType: S_Transaction_bits)
           return T_Transaction_enum is
  begin
    case TrType is
      when "00" =>
        return TR_BULK;
      when "01" =>
        return TR_SETUP;
      when "10" =>
        return TR_IRQ;
      when "11" =>
        return TR_ISO;
      when others =>
        return TR_BULK;
    end case; -- TrType
  end DecodeTransaction;

  function EncodeUsbCrc (CrcType: T_UsbCrc_enum)
           return S_UsbCrc_bits is
  begin
    case CrcType is
      when USBCRC_TOKEN =>
        return LOW;
      when USBCRC_DATA =>
        return HIGH;
      when others =>
        assert false report "Error Not implemented" severity error;   
    end case;
  end EncodeUsbCrc;

  function DecodeUsbCrc (CrcType: S_UsbCrc_bits)
           return T_UsbCrc_enum is
  begin
    case CrcType is
      when LOW =>
        return USBCRC_TOKEN;
      when others =>
        return USBCRC_DATA;
    end case;
  end DecodeUsbCrc;

  -- function for general CRC calculation one bit at a time
  function OneBitCRC (Data: one_bit;
                      CRC: unsigned;
                      Polynomial: bit_vector) return unsigned is
    constant CRC_DEGREE: integer := CRC'length;
    variable NewCRC: unsigned(CRC_DEGREE-1 downto 0);
  begin
    assert Polynomial'high = CRC_DEGREE
           report "Polynomial'high doesn't match CRC degree"
           severity error;
    assert Polynomial'low = 0
           report "Polynomial'low should be 0"
           severity error;
    assert Polynomial(Polynomial'high) = '1'
           report "Polynomial'high should be a '1'"
           severity error;
    assert Polynomial(Polynomial'low) = '1'
           report "Polynomial'low should be a '1'"
           severity error;
    NewCRC(0) := CRC(CRC'high) xor Data;
    for i in CRC_DEGREE - 1 downto 1 loop
      if Polynomial(i) = '1' then
        NewCRC(i) := CRC(i-1) xor NewCRC(0);
      else
        NewCRC(i) := CRC(i-1);
      end if;
    end loop;
    return NewCRC;
  end OneBitCrc;

  -- function for general CRC calculation for several bits
  function MultiBitCRC (Data: unsigned;
                        CRC: unsigned;
                        Polynomial: bit_vector) return unsigned is
    constant CRC_DEGREE: integer := CRC'length;
    variable NewCRC: unsigned(CRC_DEGREE-1 downto 0);
    variable NewCRC_Zero: one_bit;
  begin
    assert Polynomial'high = CRC_DEGREE
           report "Polynomial'high doesn't match CRC degree"
           severity error;
    assert Polynomial'low = 0
           report "Polynomial'low should be 0"
           severity error;
    assert Polynomial(Polynomial'high) = '1'
           report "Polynomial'high should be a '1'"
           severity error;
    assert Polynomial(Polynomial'low) = '1'
           report "Polynomial'low should be a '1'"
           severity error;
    NewCRC := CRC;
    for j in Data'range loop
      NewCRC_Zero := NewCRC(NewCRC'high) xor Data(j);
      for i in CRC_DEGREE - 1 downto 1 loop
        if Polynomial(i) = '1' then
          NewCRC(i) := NewCRC(i-1) xor NewCRC_Zero;
        else
          NewCRC(i) := NewCRC(i-1);
        end if;
      end loop;
      NewCRC(0) := NewCRC_Zero;
    end loop;
    return NewCRC;
  end MultiBitCrc;

  function CalcSyndrome (CodeWord: unsigned;
                         CRC_Matrix: unsigned;
                         CRC_Degree: natural;
                         Coset: unsigned) return unsigned is
    variable CodeWordWithCoset: unsigned(CodeWord'range);
    variable Syndrome: unsigned(CRC_Degree-1 downto 0);
  begin
    assert (Coset'length <= CodeWord'length)
           report "Coset too long for data word"
           severity error;
    assert (CodeWord'length * CRC_Degree = CRC_Matrix'length)
           report "CRC_Matrix does not match data length * CRC_Degree"
           severity error;
    CodeWordWithCoset := CodeWord;
    CodeWordWithCoset(Coset'length - 1 downto 0) :=
            CodeWord(Coset'length - 1 downto 0) xor Coset;
    Syndrome := (others => '0');
    for i in 0 to CRC_Degree-1 loop
      for j in 0 to CodeWord'high loop
        Syndrome(i) := Syndrome(i) xor
          (CodeWordWithCoset(j) and CRC_Matrix(CodeWord'length*i+j));
      end loop; -- Data loop
    end loop; -- CRC loop
    return Syndrome;
  end CalcSyndrome;

  function SyndromePosition(Syndrome: unsigned;
                            CRC_Matrix: unsigned) return integer is
    constant X_DIM: integer := CRC_Matrix'length / Syndrome'length;
    constant Y_DIM: integer := Syndrome'length;
    variable ErrorPosition: integer range 0 to X_DIM;
    variable MatrixRow: unsigned(Y_DIM-1 downto 0);
  begin
    ErrorPosition := X_DIM; -- syndrome not found in CRC_Matrix
    for j in 0 to X_DIM - 1 loop
      MatrixRow := (others => '0');
      for i in 0 to Y_DIM - 1 loop
        MatrixRow(i) := CRC_Matrix(i*X_DIM + j);
      end loop;
      if (Syndrome = MatrixRow) then
        return j;
      end if;
    end loop;
    return ErrorPosition;
  end SyndromePosition;

  -- Multiple CRC5 with message length 1 bits
  function MultipleCRC5_D1 (D: one_bit;
                            CRC: five_bits) return five_bits is
    variable NewCRC: five_bits;
  begin
    NewCRC(0) := CRC(4) xor D;
    NewCRC(1) := CRC(0);
    NewCRC(2) := CRC(1) xor CRC(4) xor D;
    NewCRC(3) := CRC(2);
    NewCRC(4) := CRC(3);
    return NewCRC;
  end MultipleCRC5_D1;

  -- Multiple CRC5 with message length 11 bits
  function MultipleCRC5_D11 (D: eleven_bits;
                            CRC: five_bits) return five_bits is
    variable NewCRC: five_bits;
  begin
    NewCRC(0) := CRC(4) xor D(10) xor D(5) xor CRC(0) xor CRC(3)
                   xor D(9) xor D(6) xor D(3) xor D(0);
    NewCRC(1) := CRC(0) xor D(6) xor CRC(1) xor CRC(4) xor D(10)
                   xor D(7) xor D(4) xor D(1);
    NewCRC(2) := CRC(1) xor D(7) xor CRC(2) xor D(8) xor D(2)
                   xor CRC(4) xor D(10) xor CRC(0) xor CRC(3) xor D(9)
                   xor D(6) xor D(3) xor D(0);
    NewCRC(3) := CRC(2) xor D(8) xor CRC(3) xor D(9) xor D(3)
                   xor CRC(1) xor CRC(4) xor D(10) xor D(7) xor D(4)
                   xor D(1);
    NewCRC(4) := CRC(3) xor D(9) xor CRC(4) xor D(10) xor D(4)
                   xor CRC(2) xor D(8) xor D(5) xor D(2);
    return NewCRC;
  end MultipleCRC5_D11;

  -- Single CRC5 with message length 11 bits
  function SingleCRC5_D11 (D: eleven_bits)
           return five_bits is
    variable NewCRC: five_bits;
  begin
    NewCRC(0) := D(10) xor D(5) xor D(9) xor D(6) xor D(3) xor D(0);
    NewCRC(1) := D(6) xor D(10) xor D(7) xor D(4) xor D(1);
    NewCRC(2) := D(7) xor D(8) xor D(2) xor D(10) xor D(9)
                   xor D(6) xor D(3) xor D(0);
    NewCRC(3) := D(8) xor D(9) xor D(3) xor D(10) xor D(7)
                   xor D(4) xor D(1);
    NewCRC(4) := D(9) xor D(10) xor D(4) xor D(8) xor D(5) xor D(2);
    return NewCRC;
  end SingleCRC5_D11;

  -- Multiple CRC16 with message length 1 bits
  function MultipleCRC16_D1 (D: one_bit;
                            CRC: two_bytes) return two_bytes is
    variable NewCRC: two_bytes;
  begin
    NewCRC(0) := CRC(15) xor D;
    NewCRC(1) := CRC(0);
    NewCRC(2) := CRC(1) xor CRC(15) xor D;
    NewCRC(3) := CRC(2);
    NewCRC(4) := CRC(3);
    NewCRC(5) := CRC(4);
    NewCRC(6) := CRC(5);
    NewCRC(7) := CRC(6);
    NewCRC(8) := CRC(7);
    NewCRC(9) := CRC(8);
    NewCRC(10) := CRC(9);
    NewCRC(11) := CRC(10);
    NewCRC(12) := CRC(11);
    NewCRC(13) := CRC(12);
    NewCRC(14) := CRC(13);
    NewCRC(15) := CRC(14) xor CRC(15) xor D;
    return NewCRC;
  end MultipleCRC16_D1;

  -- Multiple CRC16 with message length 8 bits
  function MultipleCRC16_D8 (D: byte;
                            CRC: two_bytes) return two_bytes is
    variable NewCRC: two_bytes;
  begin
    NewCRC(0) := CRC(8) xor CRC(9) xor CRC(10) xor CRC(11) xor CRC(12)
                   xor CRC(13) xor CRC(14) xor CRC(15) xor D(7) xor D(6)
                   xor D(5) xor D(4) xor D(3) xor D(2) xor D(1)
                   xor D(0);
    NewCRC(1) := CRC(9) xor CRC(10) xor CRC(11) xor CRC(12) xor CRC(13)
                   xor CRC(14) xor CRC(15) xor D(7) xor D(6) xor D(5)
                   xor D(4) xor D(3) xor D(2) xor D(1);
    NewCRC(2) := CRC(8) xor CRC(9) xor D(1) xor D(0);
    NewCRC(3) := CRC(9) xor CRC(10) xor D(2) xor D(1);
    NewCRC(4) := CRC(10) xor CRC(11) xor D(3) xor D(2);
    NewCRC(5) := CRC(11) xor CRC(12) xor D(4) xor D(3);
    NewCRC(6) := CRC(12) xor CRC(13) xor D(5) xor D(4);
    NewCRC(7) := CRC(13) xor CRC(14) xor D(6) xor D(5);
    NewCRC(8) := CRC(0) xor CRC(14) xor CRC(15) xor D(7) xor D(6)
                  ;
    NewCRC(9) := CRC(1) xor CRC(15) xor D(7);
    NewCRC(10) := CRC(2);
    NewCRC(11) := CRC(3);
    NewCRC(12) := CRC(4);
    NewCRC(13) := CRC(5);
    NewCRC(14) := CRC(6);
    NewCRC(15) := CRC(7) xor CRC(8) xor CRC(9) xor CRC(10) xor CRC(11)
                   xor CRC(12) xor CRC(13) xor CRC(14) xor CRC(15) xor D(7)
                   xor D(6) xor D(5) xor D(4) xor D(3) xor D(2)
                   xor D(1) xor D(0);
    return NewCRC;
  end MultipleCRC16_D8;

end usb_subcmp_pkg;

