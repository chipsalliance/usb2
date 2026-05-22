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
--           $RCSfile: usb_general_subcmp_pkg.p.vhdl.rca $
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
--   $Log: usb_general_subcmp_pkg.p.vhdl.rca $
--   
--    Revision: 1.3 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--
--    Revision: 1.1 Mon Sep 22 11:53:07 2008 smh
--    initial revision : from release_emirplus_v1.9be_070306
--
--
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package usb_general_subcmp_pkg is

  -- recommended bit type
  subtype one_bit is std_logic;

  -- recommended subtypes for arrays of bits
  subtype two_bits   is unsigned (1 downto 0);
  subtype three_bits is unsigned (2 downto 0);
  subtype nibble     is unsigned (3 downto 0);
  subtype four_bits  is nibble;
  subtype five_bits  is unsigned (4 downto 0);
  subtype six_bits   is unsigned (5 downto 0);
  subtype seven_bits is unsigned (6 downto 0);
  subtype byte       is unsigned (7 downto 0);

  subtype nine_bits     is unsigned (8 downto 0);
  subtype ten_bits      is unsigned (9 downto 0);
  subtype eleven_bits   is unsigned (10 downto 0);
  subtype twelve_bits   is unsigned (11 downto 0);
  subtype thirteen_bits is unsigned (12 downto 0);
  subtype fourteen_bits is unsigned (13 downto 0);
  subtype fifteen_bits  is unsigned (14 downto 0);
  subtype sixteen_bits  is unsigned (15 downto 0);
  subtype two_bytes     is sixteen_bits;

  subtype seventeen_bits    is unsigned (16 downto 0);
  subtype eighteen_bits     is unsigned (17 downto 0);
  subtype nineteen_bits     is unsigned (18 downto 0);
  subtype twenty_bits       is unsigned (19 downto 0);
  subtype twenty_one_bits   is unsigned (20 downto 0);
  subtype twenty_two_bits   is unsigned (21 downto 0);
  subtype twenty_three_bits is unsigned (22 downto 0);
  subtype twenty_four_bits  is unsigned (23 downto 0);
  subtype three_bytes       is twenty_four_bits;

  subtype twenty_five_bits  is unsigned (24 downto 0);
  subtype twenty_six_bits   is unsigned (25 downto 0);
  subtype twenty_seven_bits is unsigned (26 downto 0);
  subtype twenty_eight_bits is unsigned (27 downto 0);
  subtype twenty_nine_bits  is unsigned (28 downto 0);
  subtype thirty_bits       is unsigned (29 downto 0);
  subtype thirty_one_bits   is unsigned (30 downto 0);
  subtype thirty_two_bits   is unsigned (31 downto 0);
  subtype four_bytes        is thirty_two_bits;

  subtype thirty_three_bits is unsigned (32 downto 0);
  subtype thirty_four_bits  is unsigned (33 downto 0);
  subtype thirty_five_bits  is unsigned (34 downto 0);
  subtype thirty_six_bits   is unsigned (35 downto 0);
  subtype thirty_seven_bits is unsigned (36 downto 0);
  subtype thirty_eight_bits is unsigned (37 downto 0);
  subtype thirty_nine_bits  is unsigned (38 downto 0);
  subtype forty_bits        is unsigned (39 downto 0);
  subtype five_bytes        is forty_bits;

  subtype forty_one_bits    is unsigned (40 downto 0);
  subtype forty_two_bits    is unsigned (41 downto 0);
  subtype forty_three_bits  is unsigned (42 downto 0);
  subtype forty_four_bits   is unsigned (43 downto 0);
  subtype forty_five_bits   is unsigned (44 downto 0);
  subtype forty_six_bits    is unsigned (45 downto 0);
  subtype forty_seven_bits  is unsigned (46 downto 0);
  subtype forty_eight_bits  is unsigned (47 downto 0);
  subtype six_bytes         is forty_eight_bits;

  subtype forty_nine_bits   is unsigned (48 downto 0);
  subtype fifty_bits        is unsigned (49 downto 0);
  subtype fifty_one_bits    is unsigned (50 downto 0);
  subtype fifty_two_bits    is unsigned (51 downto 0);
  subtype fifty_three_bits  is unsigned (52 downto 0);
  subtype fifty_four_bits   is unsigned (53 downto 0);
  subtype fifty_five_bits   is unsigned (54 downto 0);
  subtype fifty_six_bits    is unsigned (55 downto 0);
  subtype seven_bytes       is fifty_six_bits;

  subtype fifty_seven_bits  is unsigned (56 downto 0);
  subtype fifty_eight_bits  is unsigned (57 downto 0);
  subtype fifty_nine_bits   is unsigned (58 downto 0);
  subtype sixty_bits        is unsigned (59 downto 0);
  subtype sixty_one_bits    is unsigned (60 downto 0);
  subtype sixty_two_bits    is unsigned (61 downto 0);
  subtype sixty_three_bits  is unsigned (62 downto 0);
  subtype sixty_four_bits   is unsigned (63 downto 0);
  subtype eight_bytes       is sixty_four_bits;

  -- useful constants
  -- use ACTIVE_LOW and INACTIVE_HIGH for active low signals
  constant LOW:           one_bit := '0';
  constant ACTIVE_LOW:    one_bit := '0';
  constant HIGH:          one_bit := '1';
  constant INACTIVE_HIGH: one_bit := '1';

  -- an array of booleans
  type booleans is array (integer range <>) of boolean;

  -- an array of bytes
  type T_byte_array is array (integer range <>) of byte;

  -- NOT SYNTHESIZABLE IN SYNERGY up till version 2.2
  -- an array of integers
  -- type integer_vector is array (integer range <>) of integer;

  -- Function IntegerPositions returns an array of integers (integer_vector)
  -- with Nr elements, with values equal to Offset + i*Distance
  -- in which i=0..Nr-1.
  -- function IntegerPositions (Nr: integer;
  --                            Offset: integer;
  --                            Distance: integer) return integer_vector;

  -- Function IsNrInList returns:
  --   TRUE: if argument Number is present in argument List
  --   FALSE: otherwise.
  -- e.g.: if List = (3, 15, 27, 29)
  --       then IsNrInList(List, 12) returns FALSE
  --       and  IsNrInList(List, 27) returns TRUE
  -- function IsNrInList (List: integer_vector; Number: integer)
  --          return boolean;

  -- Function GetIndexInList returns the position of the argument Number
  -- in the argument List.
  -- e.g.: if List = (3, 15, 27, 29), declared as integer_vector(0 to 3)
  --                  ^  ^   ^   ^
  --                  0  1   2   3
  --       then GetIndexInList(List, 27) returns 2;
  -- e.g.: if List = (3, 15, 27, 29), declared as integer_vector(3 downto 0)
  --                  ^  ^   ^   ^
  --                  3  2   1   0
  --       then GetIndexInList(List, 27) returns 1;
  -- function GetIndexInList (List: integer_vector; Number: integer)
  --          return integer;

  -- MSB detection
  function GetMsbPosition (Arg: unsigned)
           return integer;
  -- LSB detection
  function GetLsbPosition (Arg: unsigned)
           return integer;

  -- Function InsertWord inserts the InsWord in Target starting
  -- from Position. If RevIns is given the bit order is reversed.
  -- WORKS ONLY FOR DOWNTO RANGES!!! Examples are given below:
  -- 7.6.5.4.3.2.1.0 Target    7.4.3.2.1.0.1.0 Result
  --       4.3.2.1.0 InsWord     ^^^^^^^^^=InsWord
  --               2 Position
  --           FALSE RevIns
  -- 7.6.5.4.3.2.1.0 Target    7.6.0.1.2.3.4.0 Result
  --       4.3.2.1.0 InsWord       ^^^^^^^^^=InsWord
  --               1 Position
  --            TRUE RevIns
  -- 7.6.5.4.3.2.1.0 Target    2.3.4.5.6.7.8.9 Result
  -- 9.8.7.6.5.4.3.2 InsWord   ^^^^^^^^^^^^^^^=InsWord
  --               0 Position
  --            TRUE RevIns
  function InsertWord (Target:   unsigned;
                       InsWord:  unsigned;
                       Position: natural;
                       RevIns:   boolean := FALSE)
           return unsigned;

  -- extraction functions
  function ExtractMSBits (Arg: unsigned; NrBits: integer)
           return unsigned;
  function ExtractMSB (Arg: unsigned)
           return one_bit;
  function ExtractLSBits (Arg: unsigned; NrBits: integer)
           return unsigned;
  function ExtractLSB (Arg: unsigned)
           return one_bit;

  -- assembling functions
  function AssembleLSBits (Arg: unsigned; Target: unsigned)
           return unsigned;
  function AssembleLSB (Arg: one_bit; Target: unsigned)
           return unsigned;
  function AssembleMSBits (Arg: unsigned; Target: unsigned)
           return unsigned;

  -- Increment, Decrement modulo functions
  function IncMod (Arg: natural; Modulo: positive)
           return natural;
  function DecMod (Arg: natural; Modulo: positive)
           return natural;

  -- Increment, Decrement modulo functions in range LB..UB
  function IncModRange (Arg: integer; LB: integer; UB: integer)
           return integer;
  function DecModRange (Arg: integer; LB: integer; UB: integer)
           return integer;

  -- Saturatable increment function
  function IncSat (Arg: natural; SatVal: positive)
           return natural;

  -- Is at maximum value, ie. Modulo - 1
  function IsAtMaxValue (Arg: natural; Modulo: positive)
	   return boolean;

  -- useful general functions

  function Minimum (Arg1: integer; Arg2: integer)
	   return integer;
  function Maximum (Arg1: integer; Arg2: integer)
	   return integer;

  function Log2 (Arg: positive)
           return natural;

  function EventOccurred (Arg1: one_bit; Arg2: one_bit)
           return boolean;
  function EventOccurred (Arg1: boolean; Arg2: boolean)
           return boolean;

  function MakeEvent (Arg: one_bit)
           return one_bit;
  function MakeEvent (Arg: boolean)
           return boolean;

  -- DOC_BEGIN: function IsRisingEdge/IsFallingEdge
  --   Description: Detect whether there is a rising/falling edge from
  --       Previous to Current for both one_bit and Boolean objects
  --       A rising edge on a Boolean object is defined as a transition
  --       from FALSE to TRUE, a falling edge as the inverse.
  --   Returns: TRUE if the condition holds, FALSE otherwise.
  -- DOC_END
  function IsRisingEdge (Current: one_bit; Previous: one_bit)
           return boolean;
  function IsRisingEdge (Current: boolean; Previous: boolean)
           return boolean;
  function IsFallingEdge (Current: one_bit; Previous: one_bit)
           return boolean;
  function IsFallingEdge (Current: boolean; Previous: boolean)
           return boolean;

  function conv_active_low (Arg: boolean)
           return one_bit;
  function conv_active_high (Arg: boolean)
           return one_bit;
  -- for compatibility reasons = conv_active_high
  function conv_bit (Arg: boolean)
           return one_bit;

  function conv_active_low (Arg: one_bit)
           return boolean;
  function conv_active_high (Arg: one_bit)
           return boolean;

  function conv_active_low (Arg: booleans)
           return unsigned;
  function conv_active_high (Arg: booleans)
           return unsigned;

  function conv_active_low (Arg: unsigned)
           return booleans;
  function conv_active_high (Arg: unsigned)
           return booleans;

  -- overload to_integer for std_logic
  function to_integer (Arg: std_logic)
           return integer;

  -- overload shl (shift left) and shr (shift right) from Synopsys'
  -- arithmetic package, so that the shift value can be an integer
  function shl (Arg: unsigned; count: natural) return unsigned;
  function shr (Arg: unsigned; count: natural) return unsigned;

  -- reduce functions

  function and_reduce (Arg: unsigned) return one_bit;
  function nand_reduce (Arg: unsigned) return one_bit;
  function or_reduce (Arg: unsigned) return one_bit;
  function nor_reduce (Arg: unsigned) return one_bit;
  function xor_reduce (Arg: unsigned) return one_bit;
  function xnor_reduce (Arg: unsigned) return one_bit;

  function and_reduce (Arg: booleans) return boolean;
  function nand_reduce (Arg: booleans) return boolean;
  function or_reduce (Arg: booleans) return boolean;
  function nor_reduce (Arg: booleans) return boolean;
  function xor_reduce (Arg: booleans) return boolean;
  function xnor_reduce (Arg: booleans) return boolean;

  -- The following functions were defined in arithmetic in version2.2b
  -- but where no longer defined in std_logic_arith package
  -- therefore...
--  function "and" (L, R: unsigned) return unsigned;
--  function "nand" (L, R: unsigned) return unsigned;
--  function "or" (L, R: unsigned) return unsigned;
--  function "nor" (L, R: unsigned) return unsigned;
--  function "xor" (L, R: unsigned) return unsigned;
--  function xnor (L, R: unsigned) return unsigned;
-- function "not" (L: unsigned) return unsigned;

--  function "and" (L, R: signed) return signed;
--  function "nand" (L, R: signed) return signed;
--  function "or" (L, R: signed) return signed;
--  function "nor" (L, R: signed) return signed;
--  function "xor" (L, R: signed) return signed;
--  function xnor (L, R: signed) return signed;
--  function "not" (L: signed) return signed;

  -- functions to reverse (mirror) an array of bits
  function Reverse(Arg: signed) return signed;
  function Reverse(Arg: unsigned) return unsigned;

  -- functions to generate/check odd/even parity
  function GenerateOddParity (Arg: unsigned)
	   return one_bit;
  function GenerateEvenParity (Arg: unsigned)
	   return one_bit;
  function CheckOddParity (Arg: unsigned)
	   return boolean;
  function CheckEvenParity (Arg: unsigned)
	   return boolean;


function CONV   (SLV8 :STD_LOGIC_VECTOR (7 downto 0)) return CHARACTER;
function CONV   (CHAR :CHARACTER) return STD_LOGIC_VECTOR;
function nr_dwords (length: natural) return natural;
function encode_byte_en (nr_of_bits: natural) return unsigned;

  -- Gray counter functions
-- Conversion from binary code to Gray code
function BinToGray(Bin : std_logic_vector) return std_logic_vector;

-- Conversion from Gray code to binary code
function GrayToBin(Gray : std_logic_vector) return std_logic_vector;

-- Up(UpDownB=1)/Down(UpDownB=0) Gray code counter with enable
function GrayCounter(
  DIn     : std_logic_vector;
  Enable  : std_logic;
  UpDownB : std_logic)
  return std_logic_vector;

-- this funtion increments the counter value passed to it
function Increment (CntrValue : std_logic_vector)
  return std_logic_vector;
function Increment (CntrValue : unsigned)
  return unsigned;

-- this funtion decrements the counter value passed to it
function Decrement (CntrValue : std_logic_vector)
  return std_logic_vector;
function Decrement (CntrValue : unsigned)
  return unsigned;

-- This function converts a binary value to a counter value
function ToCntr (BinValue : std_logic_vector)
  return std_logic_vector;

-- This function converts a counter (gray) value to a binary value
function ToBinary (CntrValue : std_logic_vector)
  return std_logic_vector;

function to_std_logic(value : boolean) 
  return std_logic;

end usb_general_subcmp_pkg;

package body usb_general_subcmp_pkg is

  -- Integer array functions
  -- function IntegerPositions (Nr: integer;
  --                            Offset: integer;
  --                            Distance: integer)
  --          return integer_vector is
  --   variable Result: integer_vector(0 to Nr-1);
  -- begin
  --   for i in 0 to Nr-1 loop
  --     Result(i) := Offset + i * Distance;
  --   end loop;
  --   return Result;
  -- end IntegerPositions;

  -- function IsNrInList (List: integer_vector; Number: integer)
  --          return boolean is
  -- begin
  --   for i in List'range loop
  --     if (List(i) = Number) then
  --       return TRUE;
  --     end if;
  --   end loop;
  --   return FALSE;
  -- end IsNrInList;

  -- function GetIndexInList (List: integer_vector; Number: integer)
  --          return integer is
  -- begin
  --   for i in List'range loop
  --     if (List(i) = Number) then
  --       return i;
  --     end if;
  --   end loop;
  --   -- if it didn't return yet, the element is not in the list
  --   -- and we give an error
  --   assert TRUE
  --     report "ERROR -- Function GetIndexInList: Number not in List"
  --     severity ERROR;
  -- end GetIndexInList;

  -- MSB detection
  function GetMsbPosition (Arg: unsigned)
           return integer is
    subtype S_ARG_RANGE is integer range Arg'range;
    variable Result: S_ARG_RANGE;
  begin
    Result := Arg'right;
    for index in Arg'range loop
      if (Arg(index) = '1') then
	Result := index;
        exit;
      end if;
    end loop;
    return Result;
  end GetMsbPosition;

  -- LSB detection
  function GetLsbPosition (Arg: unsigned)
           return integer is
    subtype S_ARG_RANGE is integer range Arg'range;
    variable Result: S_ARG_RANGE;
  begin
    Result := Arg'left;
    for index in Arg'reverse_range loop
      if (Arg(index) = '1') then
	Result := index;
        exit;
      end if;
    end loop;
    return Result;
  end GetLsbPosition;

  function InsertWord (Target: unsigned;
                       InsWord: unsigned;
                       Position: natural;
                       RevIns: boolean := FALSE)
           return unsigned is
    constant TARGET_LENGTH: integer := Target'length;
    constant INSERT_LENGTH: integer := InsWord'length;
    variable Result: unsigned(Target'range);
  begin
    assert (INSERT_LENGTH + Position <= TARGET_LENGTH)
      report "Invalid call to InsertWord (Position + inslength > target)"
      severity note;
    Result := Target;
    if (RevIns) then
      for i in (INSERT_LENGTH-1) downto 0 loop
       -- Result(Position+i) := InsWord(InsWord'left - i);
        Result(Position+i) := InsWord(InsWord'high - i);
      end loop;
    else
      Result(INSERT_LENGTH + Position - 1 downto Position) := InsWord;
    end if;
    return Result;
  end InsertWord;

  function ExtractMSBits (Arg: unsigned; NrBits: integer)
	   return unsigned is
  begin
    assert (NrBits <= Arg'length)
      report "Arg does not have NrBits bits"
      severity ERROR;
    assert (NrBits > 1)
      report "NrBits should be larger than 1"
      severity ERROR;
    return Arg(Arg'left downto Arg'left-NrBits+1);
  end ExtractMSBits;

  function ExtractMSB (Arg: unsigned)
	   return one_bit is
  begin
    return Arg(Arg'left);
  end ExtractMSB;

  function ExtractLSBits (Arg: unsigned; NrBits: integer)
           return unsigned is
  begin
    assert (NrBits <= Arg'length)
      report "Arg does not have NrBits bits"
      severity ERROR;
    assert (NrBits > 1)
      report "NrBits should be larger than 1"
      severity ERROR;
    return Arg(Arg'right+NrBits-1 downto Arg'right);
  end ExtractLSBits;

  function ExtractLSB (Arg: unsigned)
           return one_bit is
  begin
    return Arg(Arg'right);
  end ExtractLSB;

  function AssembleLSBits (Arg: unsigned; Target: unsigned)
           return unsigned is
    variable Result: unsigned(Target'range);
  begin
    assert (Arg'length <= Target'length)
      report "Argument too wide for target"
      severity ERROR;
    Result := (others => '0');
    Result(Result'right+Arg'length-1 downto Result'right) := Arg;
    return Result;
  end AssembleLSBits;

  function AssembleLSB (Arg: one_bit; Target: unsigned)
           return unsigned is
    variable Result: unsigned(Target'range);
  begin
    Result := (others => '0');
    Result(Result'right) := Arg;
    return Result;
  end AssembleLSB;

  function AssembleMSBits (Arg: unsigned; Target: unsigned)
           return unsigned is
    variable Result: unsigned(Target'range);
  begin
    assert (Arg'length <= Target'length)
      report "Argument too wide for target"
      severity ERROR;
    Result := (others => '0');
    Result(Result'left downto Result'left-Arg'length+1) := Arg;
    return Result;
  end AssembleMSBits;

  -- Function IncMod: modulo increment of Arg
  function IncMod (Arg: natural; Modulo: positive)
           return natural is
  begin
    assert (Arg < Modulo)
      report "Argument larger than Modulo (function IncMod)"
      severity Error;
    if (Arg = Modulo - 1) then
      return 0;
    else
      return Arg + 1;
    end if;
  end IncMod;

  -- Function DecMod: modulo decrement of Arg
  function DecMod (Arg: natural; Modulo: positive)
           return natural is
  begin
    assert (Arg < Modulo)
      report "Argument larger than Modulo (function DecMod)"
      severity Error;
    if (Arg = 0) then
      return Modulo - 1;
    else
      return Arg - 1;
    end if;
  end DecMod;

  -- Function IncModRange: modulo increment of Arg in range LB..UB
  function IncModRange (Arg: integer; LB: integer; UB: integer)
	   return integer is
  begin
    assert (Arg >= LB) and (Arg <= UB)
      report "Argument not in range (function IncModRange)"
      severity Error;
    if (Arg = UB) then
      return LB;
    else
      return Arg + 1;
    end if;
  end IncModRange;

  -- Function DecModRange: modulo decrement of Arg in range LB..UB
  function DecModRange (Arg: integer; LB: integer; UB: integer)
	   return integer is
  begin
    assert (Arg >= LB) and (Arg <= UB)
      report "Argument not in range (function DecModRange)"
      severity Error;
    if (Arg = LB) then
      return UB;
    else
      return Arg - 1;
    end if;
  end DecModRange;

  -- Saturatable increment function
  function IncSat (Arg: natural; SatVal: positive)
           return natural is
  begin
    assert (Arg < SatVal)
      report "Argument larger than Saturation Value (function IncSat)"
      severity Error;
    if (Arg = SatVal - 1) then
      return Arg;
    else
      return Arg + 1;
    end if;
  end IncSat;

  function IsAtMaxValue (Arg: natural; Modulo: positive)
	   return boolean is
  begin
    assert (Arg < Modulo)
      report "Argument larger or equal to Modulo (function IsAtMaxValue)"
      severity Error;
    if (Arg = Modulo - 1) then
      return TRUE;
    else
      return FALSE;
    end if;
  end IsAtMaxValue;

  function Minimum (Arg1: integer; Arg2: integer)
	   return integer is
  begin
    if (Arg2 < Arg1) then
      return Arg2;
    else
      return Arg1;
    end if;
  end Minimum;

  function Maximum (Arg1: integer; Arg2: integer)
	   return integer is
  begin
    if (Arg2 > Arg1) then
      return Arg2;
    else
      return Arg1;
    end if;
  end Maximum;

  function Log2 (Arg: positive)
           return natural is
  begin
    assert Arg <= 2**30 report "Arg too large for Log2 (greater than 2**30)";
    for i in 1 to 30 loop
      if Arg <= 2**i then
        return i;
      end if;
    end loop;
  end Log2;

  function EventOccurred (Arg1: one_bit; Arg2: one_bit)
           return boolean is
  begin
    return (Arg1 /= Arg2);
  end EventOccurred;

  function EventOccurred (Arg1: boolean; Arg2: boolean)
           return boolean is
  begin
    return (Arg1 /= Arg2);
  end EventOccurred;

  function MakeEvent (Arg: one_bit)
           return one_bit is
  begin
    return not Arg;
  end MakeEvent;

  function MakeEvent (Arg: boolean)
           return boolean is
  begin
    return not Arg;
  end MakeEvent;

  function IsRisingEdge (Current: one_bit; Previous: one_bit)
           return boolean is
  begin
    return ((Previous = LOW) and (Current = HIGH));
  end IsRisingEdge;

  function IsRisingEdge (Current: boolean; Previous: boolean)
           return boolean is
  begin
    return ((Previous = FALSE) and (Current = TRUE));
  end IsRisingEdge;

  function IsFallingEdge (Current: one_bit; Previous: one_bit)
           return boolean is
  begin
    return ((Previous = HIGH) and (Current = LOW));
  end IsFallingEdge;

  function IsFallingEdge (Current: boolean; Previous: boolean)
           return boolean is
  begin
    return ((Previous = TRUE) and (Current = FALSE));
  end IsFallingEdge;

  function conv_active_low (Arg: boolean)
           return one_bit is
  begin
    if (Arg) then
      return one_bit' ('0');
    else
      return one_bit' ('1');
    end if;
  end conv_active_low;

  function conv_active_high (Arg: boolean)
           return one_bit is
  begin
    if (Arg) then
      return one_bit' ('1');
    else
      return one_bit' ('0');
    end if;
  end conv_active_high;

  function conv_bit (Arg: boolean)
           return one_bit is
  begin
    if (Arg) then
      return one_bit' ('1');
    else
      return one_bit' ('0');
    end if;
  end conv_bit;

  function conv_active_low (Arg: one_bit)
           return boolean is
  begin
    if (Arg = one_bit' ('0')) then
      return TRUE;
    else
      return FALSE;
    end if;
  end conv_active_low;

  function conv_active_high (Arg: one_bit)
           return boolean is
  begin
    if (Arg = one_bit' ('1')) then
      return TRUE;
    else
      return FALSE;
    end if;
  end conv_active_high;

  function conv_active_low (Arg: booleans)
           return unsigned is
    variable Result: unsigned(Arg'range);
  begin
    for i in Result'range loop
      Result(i) := conv_active_low(Arg(i));
    end loop;
    return Result;
  end conv_active_low;

  function conv_active_high (Arg: booleans)
           return unsigned is
    variable Result: unsigned(Arg'range);
  begin
    for i in Result'range loop
      Result(i) := conv_active_high(Arg(i));
    end loop;
    return Result;
  end conv_active_high;

  function conv_active_low (Arg: unsigned)
           return booleans is
    variable Result: booleans(Arg'range);
  begin
    for i in Result'range loop
      Result(i) := conv_active_low(Arg(i));
    end loop;
    return Result;
  end conv_active_low;

  function conv_active_high (Arg: unsigned)
           return booleans is
    variable Result: booleans(Arg'range);
  begin
    for i in Result'range loop
      Result(i) := conv_active_high(Arg(i));
    end loop;
    return Result;
  end conv_active_high;

  -- overload to_integer for std_logic
  function to_integer (Arg: std_logic)
           return integer is
  begin
    if Arg='1' or Arg='H' then
      Return 1;
    elsif Arg='0' or Arg='L' then
      return 0;
    else
      assert FALSE
      report "to_integer(std_logic): argument is not 0, 1, H or L. Returning 0" severity WARNING;
      return 0;
    end if;
  end to_integer;



  -- overload shl (shift left) and shr (shift right) from Synopsys'
  -- arithmetic package, so that the shift value can be a natural

  function shl(Arg: unsigned; count: natural) return unsigned is
    subtype rtype is unsigned ((Arg'length-1) downto 0);
    variable Result: rtype;
  begin
    Result := Arg;
    if (count > 0) then
      if (Arg'length = 1) then
        Result := "0";
      else
        for i in 1 to Arg'length loop
          if (count >= i) then
            Result := Result((Arg'length-2) downto 0) & "0";
          else
            exit;
          end if;
        end loop;
      end if;
    end if;
    return Result;
  end;

  function shr(Arg: unsigned; count: natural) return unsigned is
    subtype rtype is unsigned ((Arg'length-1) downto 0);
    variable Result: rtype;
  begin
    Result := Arg;
    if (count > 0) then
      if (Arg'length = 1) then
        Result := "0";
      else
        for i in 1 to Arg'length loop
          if (count >= i) then
            Result := "0" & Result((Arg'length-1) downto 1);
          else
            exit;
          end if;
        end loop;
      end if;
    end if;
    return Result;
  end;

  -- reduce functions

  function and_reduce(Arg: unsigned) return one_bit is
    variable Result: one_bit;
  begin
    Result := '1';
    for i in Arg'range loop
      Result := Result and Arg(i);
    end loop;
    return Result;
  end;

  function nand_reduce(Arg: unsigned) return one_bit is
  begin
    return not and_reduce(Arg);
  end;

  function or_reduce(Arg: unsigned) return one_bit is
    variable Result: one_bit;
  begin
    Result := '0';
    for i in Arg'range loop
      Result := Result or Arg(i);
    end loop;
    return Result;
  end;

  function nor_reduce(Arg: unsigned) return one_bit is
  begin
    return not or_reduce(Arg);
  end;

  function xor_reduce(Arg: unsigned) return one_bit is
    variable Result: one_bit;
  begin
    Result := '0';
    for i in Arg'range loop
      Result := Result xor Arg(i);
    end loop;
    return Result;
  end;

  function xnor_reduce(Arg: unsigned) return one_bit is
  begin
    return not xor_reduce(Arg);
  end;

  function and_reduce(Arg: booleans) return boolean is
    variable Result: boolean;
  begin
    Result := TRUE;
    for i in Arg'range loop
      Result := Result and Arg(i);
    end loop;
    return Result;
  end;

  function nand_reduce(Arg: booleans) return boolean is
  begin
    return not and_reduce(Arg);
  end;

  function or_reduce(Arg: booleans) return boolean is
    variable Result: boolean;
  begin
    Result := FALSE;
    for i in Arg'range loop
      Result := Result or Arg(i);
    end loop;
    return Result;
  end;

  function nor_reduce(Arg: booleans) return boolean is
  begin
    return not or_reduce(Arg);
  end;

  function xor_reduce(Arg: booleans) return boolean is
    variable Result: boolean;
  begin
    Result := FALSE;
    for i in Arg'range loop
      Result := Result xor Arg(i);
    end loop;
    return Result;
  end;

  function xnor_reduce(Arg: booleans) return boolean is
  begin
    return not xor_reduce(Arg);
  end;

  -- The following functions were defined in arithmetic in version2.2b
  -- but where no longer defined in std_logic_arith package
  -- therefore...
  -- redundant qualifying when making Result
  -- is necessary because of synthesis bug

--  function "and" (L, R: unsigned) return unsigned is
--    variable Result: std_logic_vector(L'range);
--  begin
--    Result := std_logic_vector(unsigned'(L)) and
--              std_logic_vector(unsigned'(R));
--    return unsigned(Result);
--  end;

-- function "nand" (L, R: unsigned) return unsigned is
--   variable Result: std_logic_vector(L'range);
-- begin
--   Result := std_logic_vector(unsigned'(L)) nand
--             std_logic_vector(unsigned'(R));
--   return unsigned(Result);
-- end;

-- function "or" (L, R: unsigned) return unsigned is
--   variable Result: std_logic_vector(L'range);
-- begin
--   Result := std_logic_vector(unsigned'(L)) or
--             std_logic_vector(unsigned'(R));
--   return unsigned(Result);
-- end;

-- function "nor" (L, R: unsigned) return unsigned is
--   variable Result: std_logic_vector(L'range);
-- begin
--   Result := std_logic_vector(unsigned'(L)) nor
--             std_logic_vector(unsigned'(R));
--   return unsigned(Result);
-- end;

-- function "xor" (L, R: unsigned) return unsigned is
--   variable Result: std_logic_vector(L'range);
-- begin
--   Result := std_logic_vector(unsigned'(L)) xor
--             std_logic_vector(unsigned'(R));
--   return unsigned(Result);
-- end;

--  function xnor (L, R: unsigned) return unsigned is
--    variable Result: std_logic_vector(L'range);
--  begin
--    Result := (not (std_logic_vector(unsigned'(L)) xor
--		    std_logic_vector(unsigned'(R))));
--    return unsigned(Result);
--  end;

-- function "not" (L: unsigned) return unsigned is
--   variable Result: std_logic_vector(L'range);
-- begin
--   Result := not std_logic_vector(unsigned'(L));
--   return unsigned(Result);
-- end;

-- function "and" (L, R: signed) return signed is
--   variable Result: std_logic_vector(L'range);
-- begin
--   Result := std_logic_vector(signed'(L)) and
--             std_logic_vector(signed'(R));
--   return signed(Result);
-- end;

-- function "nand" (L, R: signed) return signed is
--   variable Result: std_logic_vector(L'range);
-- begin
--   Result := std_logic_vector(signed'(L)) nand
--             std_logic_vector(signed'(R));
--   return signed(Result);
-- end;

-- function "or" (L, R: signed) return signed is
--   variable Result: std_logic_vector(L'range);
-- begin
--   Result := std_logic_vector(signed'(L)) or
--             std_logic_vector(signed'(R));
--   return signed(Result);
-- end;

-- function "nor" (L, R: signed) return signed is
--   variable Result: std_logic_vector(L'range);
-- begin
--   Result := std_logic_vector(signed'(L)) nor
--             std_logic_vector(signed'(R));
--   return signed(Result);
-- end;

-- function "xor" (L, R: signed) return signed is
--   variable Result: std_logic_vector(L'range);
-- begin
--   Result := std_logic_vector(signed'(L)) xor
--             std_logic_vector(signed'(R));
--   return signed(Result);
-- end;

--  function xnor (L, R: signed) return signed is
--    variable Result: std_logic_vector(L'range);
--  begin
--    Result := (not (std_logic_vector(signed'(L)) xor
--                    std_logic_vector(signed'(R))));
--    return signed(Result);
--  end;

-- function "not" (L: signed) return signed is
--   variable Result: std_logic_vector(L'range);
-- begin
--   Result := not std_logic_vector(signed'(L));
--   return signed(Result);
-- end;
--

  -- functions to reverse (mirror) an array of bits

  function Reverse(Arg: signed) return signed is
    variable Result: signed(Arg'reverse_range);
  begin
    for i in Arg'range loop
      Result(i) := Arg(i);
    end loop;
    return Result;
  end Reverse;

  function Reverse(Arg: unsigned) return unsigned is
    variable Result: unsigned(Arg'reverse_range);
  begin
    for i in Arg'range loop
      Result(i) := Arg(i);
    end loop;
    return Result;
  end Reverse;

  -- functions to generate/check odd/even parity

  function GenerateOddParity (Arg: unsigned)
	   return one_bit is
    variable Result: one_bit;
  begin
    Result := '1';
    for i in Arg'range loop
      Result := Result xor Arg(i);
    end loop;
    return Result;
  end GenerateOddParity;

  function GenerateEvenParity (Arg: unsigned)
	   return one_bit is
    variable Result: one_bit;
  begin
    Result := '0';
    for i in Arg'range loop
      Result := Result xor Arg(i);
    end loop;
    return Result;
  end GenerateEvenParity;

  function CheckOddParity (Arg: unsigned)
	   return boolean is
    variable Result: boolean;
  begin
    Result := FALSE;
    for i in Arg'range loop
      Result := Result xor (Arg(i) = '1');
    end loop;
    return Result;
  end CheckOddParity;

  function CheckEvenParity (Arg: unsigned)
	   return boolean is
    variable Result: boolean;
  begin
    Result := TRUE;
    for i in Arg'range loop
      Result := Result xor (Arg(i) = '1');
    end loop;
    return Result;
  end CheckEvenParity;


  ----------------------------------------------------------------------------
  --
    -- From STD_LOGIC_VECTOR to CHARACTER converter


  ----------------------------------------------------------------------------
  --
    function CONV (SLV8 :STD_LOGIC_VECTOR (7 downto 0)) return CHARACTER is
      constant XMAP :INTEGER :=0;
      variable TEMP :INTEGER :=0;
    begin
      for i in SLV8'range loop
        TEMP:=TEMP*2;
        case SLV8(i) is
          when '0' | 'L'  => null;
          when '1' | 'H'  => TEMP :=TEMP+1;
          when others     => TEMP :=TEMP+XMAP;
        end case;
      end loop;
      return CHARACTER'VAL(TEMP);
    end CONV;


  ----------------------------------------------------------------------------
  --
    -- From CHARACTER to STD_LOGIC_VECTOR (7 downto 0) converter


  ----------------------------------------------------------------------------
  --
    function CONV (CHAR :CHARACTER) return STD_LOGIC_VECTOR is
      variable SLV8 :STD_LOGIC_VECTOR (7 downto 0);
      variable TEMP :INTEGER :=CHARACTER'POS(CHAR);
    begin
      for i in SLV8'reverse_range loop
        case TEMP mod 2 is
          when 0 => SLV8(i):='0';
          when 1 => SLV8(i):='1';
          when others => null;
        end case;
        TEMP:=TEMP/2;
      end loop;
      return SLV8;
    end CONV;



    function nr_dwords (length: natural) return natural is
    variable v_nr_dwords: natural;
    begin
       if length mod 4  = 0 then
          v_nr_dwords := to_integer(to_unsigned(length,9) srl 2);
       else
          v_nr_dwords := to_integer(to_unsigned(length,9) srl 2) + 1;
       end if;
       return v_nr_dwords;
    end function nr_dwords;
    
    
    function encode_byte_en (nr_of_bits: natural) return unsigned is
     variable v_byte_en_temp: unsigned(3 downto 0);
     begin
       v_byte_en_temp:= (others => '0');
      for i in 0 to 3 loop
         if nr_of_bits > i then
            v_byte_en_temp(i) := '1';
         else
            return v_byte_en_temp;
         end if;
      end loop;
    end function encode_byte_en;


   function to_std_logic(value : boolean) return std_logic is
    variable result : std_logic;
    begin
      result := '0';
      if value then
        result := '1';
      end if;
      return result;
    end function to_std_logic;


  ----------------------------------------------------------------------------
  -- Gray counter functions  
  ----------------------------------------------------------------------------

  function BinToGray(Bin : std_logic_vector) return std_logic_vector is
    variable v_Gray : std_logic_vector(Bin'range);
  begin
    v_Gray(v_Gray'high) := Bin(Bin'high);
    for I in v_Gray'high-1 downto v_Gray'low loop
      v_Gray(I) := BIn(I+1) xor BIn(I);
    end loop;
    return v_Gray;
  end BinToGray;

  function GrayToBin(Gray : std_logic_vector) return std_logic_vector is
    variable v_Bin : std_logic_vector(Gray'range);
  begin
    v_Bin(v_Bin'high) := Gray(Gray'high);
    for I in v_Bin'high-1 downto v_Bin'low loop
      v_Bin(I) := v_BIn(I+1) xor Gray(I);
    end loop;
    return v_Bin;
  end GrayToBin;

  function GrayCounter(
    DIn     : std_logic_vector;
    Enable  : std_logic;
    UpDownB : std_logic)
    return std_logic_vector is
    variable v_Xor : std_logic_vector(DIn'range);
    variable v_Or  : std_logic_vector(DIn'range);
    variable v_Out : std_logic_vector(DIn'range);
  begin

    -- Calculates a XorReduce of the MSB with the UpDownB
    -- The UpDownB makes sure that the XorReduce when counting down is the
    -- inverse of the XorReduce when counting up.
    v_Xor(v_Xor'high) := UpDownB;
    for I in v_Xor'high-1 downto v_Xor'low loop
      v_Xor(I) := v_Xor(I+1) xor DIn(I+1);
    end loop;

    -- Calculates a OrReduce of the LSB
    -- v_Or(I) = OrReduce(DIn(I-1 downto low) & not Enable)
    v_Or(v_Or'low) := not Enable;
    for I in v_Or'low+1 to v_Or'high loop
      v_Or(I) := v_Or(I-1) or DIn(I-1);
    end loop;

-------------------------------------------------------------------------------
-- Calculate the output
-------------------------------------------------------------------------------

    -- Whenever the bit v_Or(vOr'high-1) is '0', the MSB changes sign either in
    -- up-counting or down-counting mode.
    if v_Or(v_Or'high-1) = '0' then
      v_Out(v_Out'high) := not DIn(DIn'high-1) xor UpDownB;
    else
      v_Out(v_Out'high) := DIn(DIn'high);
    end if;

    -- A data bit D(I) changes sign when v_Or(I-1) equals '0' and when D(I-1)
    -- equals '1'. In all other cases, the new data bit equals the old one.
    -- When a bit changes, it gets the value of the XorReduce at that moment.
    for I in v_Out'high-1 downto v_Out'low+1 loop
      if (DIn(I-1) = '1') and (v_Or(I-1) = '0') then
        v_Out(I) := v_Xor(I);
      else
        v_Out(I) := DIn(I);
      end if;
    end loop;

    -- The LSB of the result is always equal to the LSB of the
    -- XorReduced vector.
    if Enable = '1' then
      v_Out(v_Out'low) := v_Xor(v_Xor'low);
    else
      v_Out(v_Out'low) := DIn(DIn'low);
    end if;
    return v_Out;
  end GrayCounter;

  -- this funtion increments the counter value passed to it
  -- the counter is a Gray counter
  function Increment (CntrValue : std_logic_vector)
    return std_logic_vector is
  begin
    return GrayCounter(CntrValue, '1', '1');
  end Increment;
  function Increment (CntrValue : unsigned)
    return unsigned is
  begin  -- function Increment
    return unsigned(Increment(std_logic_vector(CntrValue)));
  end function Increment;

  -- this funtion decrements the counter value passed to it
  -- the counter is a Gray counter
  function Decrement (CntrValue : std_logic_vector)
    return std_logic_vector is
  begin
    return GrayCounter(CntrValue, '1', '0');
  end Decrement;
  function Decrement (CntrValue : unsigned)
    return unsigned is
  begin  -- function Decrement
    return unsigned(Decrement(std_logic_vector(CntrValue)));
  end function Decrement;

  -- This function converts a binary value to a counter value
  -- the counter is a Gray counter (see function Increment)
  function ToCntr (BinValue : std_logic_vector)
    return std_logic_vector is
  begin
    return BinToGray(BinValue);
  end ToCntr;

  -- This function converts a counter (gray) value to a binary value
  function ToBinary (CntrValue : std_logic_vector)
    return std_logic_vector is
  begin
    return GrayToBin(CntrValue);
  end ToBinary;





end usb_general_subcmp_pkg;
