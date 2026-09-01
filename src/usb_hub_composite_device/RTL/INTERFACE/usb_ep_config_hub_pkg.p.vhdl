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

package usb_ep_config_pkg is

constant C_EP_FS_MAXPACKETSIZE_NON_ISO : std_logic_vector(6 downto 0) := "1000000";

constant C_DEV_LINK_START            : std_logic_vector(11 downto 0) := X"0F0";
constant C_NBDEV                     : integer := 1;  -- number of hardware devices (e.g hub + hid), software device is not included
constant C_NBPHYSEP_IN               : integer := 1;
constant C_NBPHYSEP_OUT              : integer := 0;
constant C_NBPHYSEP                  : integer := C_NBPHYSEP_IN + C_NBPHYSEP_OUT;
constant C_NBBUF_OUT                 : integer := 1;
constant C_NBBUF_IN                  : integer := 1;

constant C_STD_REQ_IDLE              : std_logic_vector(6 downto 0) := "0000000"; -- This is used if only a descriptor must be returned.
constant C_STD_REQ_SET_ADDRESS       : std_logic_vector(6 downto 0) := "0000001";
constant C_STD_REQ_SET_CONFIGURATION : std_logic_vector(6 downto 0) := "0000010";
constant C_STD_REQ_SET_FEATURE_DEV   : std_logic_vector(6 downto 0) := "0000011";
constant C_STD_REQ_SET_FEATURE_EP    : std_logic_vector(6 downto 0) := "0000100";
constant C_STD_REQ_GET_CONFIGURATION : std_logic_vector(6 downto 0) := "0000101";
constant C_STD_REQ_GET_INTERFACE     : std_logic_vector(6 downto 0) := "0000110";
constant C_STD_REQ_GET_STATUS_DEV    : std_logic_vector(6 downto 0) := "0000111";
constant C_STD_REQ_GET_STATUS_IF     : std_logic_vector(6 downto 0) := "0001000";
constant C_STD_REQ_GET_STATUS_EP     : std_logic_vector(6 downto 0) := "0001001";
constant C_STD_REQ_CLEAR_FEATURE_DEV : std_logic_vector(6 downto 0) := "0001010";
constant C_STD_REQ_CLEAR_FEATURE_EP  : std_logic_vector(6 downto 0) := "0001011";
--constant C_STD_REQ_SET_INTERFACE     : std_logic_vector(6 downto 0) := "0000011";
constant C_CLASS_REQ_CLEAR_FEATURE   : std_logic_vector(6 downto 0) := "1000000";
constant C_CLASS_REQ_SET_FEATURE     : std_logic_vector(6 downto 0) := "1000001";
constant C_CLASS_REQ_GET_STATUS      : std_logic_vector(6 downto 0) := "1000010";

constant EP_OUT : std_logic := '0';
constant EP_IN  : std_logic := '1';
constant NON_ISO: std_logic := '0';
constant ISO    : std_logic := '1';

type t_ep is record
  EPNB     : integer range 0 to 15;
  EPDIR    : std_logic;
  BUFF     : integer range 0 to 2;
  EPTYPE   : std_logic;
  ISO_SIZE : integer range 0 to 1024;
end record;
type t_ep_array is array(0 to 29) of t_ep;
type t_dev is record
  NBPHYSEP : integer range 0 to 30; --0 indicates that only EP0 exists - EP0 is not part of this list
  EP       : t_ep_array;
end record;
type t_dev_array is array(0 to C_NBDEV-1) of t_dev;

function FUNC_ASSIGN_DEV_ARRAY return t_dev_array;

constant DEV_ARRAY : t_dev_array := FUNC_ASSIGN_DEV_ARRAY;

type t_epconfig_device is array(0 to 63) of std_logic_vector(31 downto 0);
type t_epconfig_all is array (0 to C_NBDEV-1) of t_epconfig_device;
type t_epconfig_link_dev is array(0 to 63) of integer range 0 to C_NBPHYSEP-1;
type t_epconfig_link is array (0 to C_NBDEV-1) of t_epconfig_link_dev;

-- ep number of byte is 7 bits only while it could be much more
-- The reason of this implementation is probably coming from the full speed where the max packt is 64 x2 if dounle buffering is used
type t_reg_ep_nbytes is array(0 to C_NBPHYSEP-1) of std_logic_vector(6 downto 0);

function func_epconfig_table_fs(ep0_out_active   : std_logic_vector(C_NBDEV-1 downto 0);
                                ep0_in_active    : std_logic_vector(C_NBDEV-1 downto 0);
                                ep0_setup_dir    : std_logic_vector(C_NBDEV-1 downto 0);
                                ep0_outin_nbytes : std_logic_vector(C_NBDEV*10-1 downto 0);
                                ep0_data_buffer  : std_logic_vector(C_NBDEV*8-1 downto 0);
                                ep_active        : std_logic_vector(C_NBPHYSEP-1 downto 0);
                                ep_disable       : std_logic_vector(C_NBPHYSEP-1 downto 0);
                                ep_stall         : std_logic_vector(C_NBPHYSEP-1 downto 0);
                                ep_toggle_reset  : std_logic_vector(C_NBPHYSEP-1 downto 0);
                                ep_nbytes        : t_reg_ep_nbytes;
                                epconfig_link    : t_epconfig_link
                              ) return t_epconfig_all;

function func_epconfig_table(ep0_out_active   : std_logic_vector(C_NBDEV-1 downto 0);
                             ep0_in_active    : std_logic_vector(C_NBDEV-1 downto 0);
                             ep0_setup_dir    : std_logic_vector(C_NBDEV-1 downto 0);
                             ep0_outin_nbytes : std_logic_vector(C_NBDEV*15-1 downto 0);
                             ep0_data_buffer  : std_logic_vector(C_NBDEV*8-1 downto 0);
                             ep_active        : std_logic_vector(C_NBPHYSEP-1 downto 0);
                             ep_disable       : std_logic_vector(C_NBPHYSEP-1 downto 0);
                             ep_stall         : std_logic_vector(C_NBPHYSEP-1 downto 0);
                             ep_toggle_reset  : std_logic_vector(C_NBPHYSEP-1 downto 0);
                             ep_nbytes        : t_reg_ep_nbytes;
                             epconfig_link    : t_epconfig_link
                              ) return t_epconfig_all;

function func_epconfig_link(DEV_ARRAY : t_dev_array) return t_epconfig_link;

function func_epconfig_link_reverse(bitnumber : integer range 0 to C_NBPHYSEP-1) return t_ep;

constant C_EPCONFIG_LINK : t_epconfig_link := func_epconfig_link(DEV_ARRAY);

end usb_ep_config_pkg;


package body usb_ep_config_pkg is

function func_epconfig_table_fs(ep0_out_active   : std_logic_vector(C_NBDEV-1 downto 0);
                                ep0_in_active    : std_logic_vector(C_NBDEV-1 downto 0);
                                ep0_setup_dir    : std_logic_vector(C_NBDEV-1 downto 0);
                                ep0_outin_nbytes : std_logic_vector(C_NBDEV*10-1 downto 0);
                                ep0_data_buffer  : std_logic_vector(C_NBDEV*8-1 downto 0);
                                ep_active        : std_logic_vector(C_NBPHYSEP-1 downto 0);
                                ep_disable       : std_logic_vector(C_NBPHYSEP-1 downto 0);
                                ep_stall         : std_logic_vector(C_NBPHYSEP-1 downto 0);
                                ep_toggle_reset  : std_logic_vector(C_NBPHYSEP-1 downto 0);
                                ep_nbytes        : t_reg_ep_nbytes;
                                epconfig_link    : t_epconfig_link
                              ) return t_epconfig_all is
variable var_epram_bufin,  var_epnoram_bufin   : integer range 0 to 255;
variable var_epram_bufout, var_epnoram_bufout  : integer range 0 to 255;
variable var_result : t_epconfig_all;
variable var_offset : integer range 0 to 63;
begin
  var_epram_bufin    := 0;
  var_epnoram_bufin  := 0;
  var_epram_bufout   := 0;
  var_epnoram_bufout := 0;
  var_result := (others => (others => X"40000000")); -- Set disable bit by default
  for i in 0 to C_NBDEV-1 loop
    -- assign EP0 OUT values
    var_result(i)(0)(31) := ep0_out_active(i);
    var_result(i)(0)(30) := '0'; --Disable bit
    var_result(i)(0)(29) := '1'; --Stall bit
    var_result(i)(0)(28) := '0'; --Toggle reset
    var_result(i)(0)(27) := '0'; --Toggle reset value
    var_result(i)(0)(26) := '0'; --Endpoint type

    if ep0_setup_dir(i) = '0' then -- Host to device
      var_result(i)(0)(25 downto 16) := ep0_outin_nbytes((i+1)*10-1 downto i*10); --NBytes
    else
      var_result(i)(0)(25 downto 16) := "0001000000"; --NBytes - set to maxpacketsize to receive any size of status packet
    end if;
    var_result(i)(0)(15 downto  0) := "00000" & "000" & ep0_data_buffer((i+1)*8-1 downto i*8); -- Addres Offset

    -- assign EP0 SETUP values
    var_result(i)(1)(31 downto 16) := (others => '0');

    var_result(i)(1)(15 downto  0) := "00000" & "001" & '0' & std_logic_vector(to_unsigned(i,7)); -- Address Offset
    
    -- assign EP0 IN values
    var_result(i)(2)(31) := ep0_in_active(i);
    var_result(i)(2)(30) := '0'; --Disable bit
    var_result(i)(2)(29) := '1'; --Stall bit
    var_result(i)(2)(28) := '0'; --Toggle reset
    var_result(i)(2)(27) := '0'; --Toggle reset value
    var_result(i)(2)(26) := '0'; --Endpoint type

    if ep0_setup_dir(i) = '0' then -- Host to device
      var_result(i)(2)(25 downto 16) := (others => '0'); --NBytes
    else
      var_result(i)(2)(25 downto 16) := ep0_outin_nbytes((i+1)*10-1 downto i*10); --NBytes
    end if;
    var_result(i)(2)(15 downto  0) := "00000" & "000" & ep0_data_buffer((i+1)*8-1 downto i*8); -- Addres Offset

    -- assign values for other endpoints
    for j in 0 to DEV_ARRAY(i).NBPHYSEP-1 loop
      if DEV_ARRAY(i).EP(j).EPDIR = '1' then
        var_offset := 4*DEV_ARRAY(i).EP(j).EPNB + 2;
      else
        var_offset := 4*DEV_ARRAY(i).EP(j).EPNB;
      end if;
      case DEV_ARRAY(i).EP(j).BUFF is
        -- no buffer
        when 0 =>
          var_result(i)(var_offset)(31)           := ep_active(epconfig_link(i)(var_offset)) and not ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(30)           := ep_disable(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(29)           := ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(28)           := ep_toggle_reset(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(27)           := '0';
          var_result(i)(var_offset)(26)           := DEV_ARRAY(i).EP(j).EPTYPE;

          var_result(i)(var_offset)(25 downto 23) := "000";
          var_result(i)(var_offset)(22 downto 16) := ep_nbytes(epconfig_link(i)(var_offset)); --NBytes
          if DEV_ARRAY(i).EP(j).EPDIR = EP_OUT then
            var_result(i)(var_offset)(15 downto  0) := "00000" & 
                                                       "01"    &
                                                       EP_OUT  &
                                                       std_logic_vector(to_unsigned(var_epnoram_bufout,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epnoram_bufout := var_epnoram_bufout + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epnoram_bufout := var_epnoram_bufout + 1;
            end if;
          else
            var_result(i)(var_offset)(15 downto  0) := "00000" & 
                                                       "01"    &
                                                       EP_IN   &
                                                       std_logic_vector(to_unsigned(var_epnoram_bufin,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epnoram_bufin := var_epnoram_bufin + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epnoram_bufin := var_epnoram_bufin + 1;
            end if;
          end if;
        -- single buffer
        when 1 =>
          var_result(i)(var_offset)(31)           := ep_active(epconfig_link(i)(var_offset)) and not ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(30)           := ep_disable(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(29)           := ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(28)           := ep_toggle_reset(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(27)           := '0';
          var_result(i)(var_offset)(26)           := DEV_ARRAY(i).EP(j).EPTYPE;

          var_result(i)(var_offset)(25 downto 23) := "000";
          var_result(i)(var_offset)(22 downto 16) := ep_nbytes(epconfig_link(i)(var_offset)); --NBytes
          if DEV_ARRAY(i).EP(j).EPDIR = EP_OUT then
            var_result(i)(var_offset)(15 downto  0) := "00000" & 
                                                       "10"    &
                                                       EP_OUT  &
                                                       std_logic_vector(to_unsigned(var_epram_bufout,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epram_bufout := var_epram_bufout + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epram_bufout := var_epram_bufout + 1;
            end if;
          else
            var_result(i)(var_offset)(15 downto  0) := "00000" & 
                                                       "10"    &
                                                       EP_IN   &
                                                       std_logic_vector(to_unsigned(var_epram_bufin,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epram_bufin := var_epram_bufin + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epram_bufin := var_epram_bufin + 1;
            end if;
          end if;

        -- double buffer
        when 2 =>
          var_result(i)(var_offset)(31)           := ep_active(epconfig_link(i)(var_offset)) and not ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(30)           := ep_disable(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(29)           := ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(28)           := ep_toggle_reset(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(27)           := '0';
          var_result(i)(var_offset)(26)           := DEV_ARRAY(i).EP(j).EPTYPE;

          var_result(i)(var_offset)(25 downto 23) := "000";
          var_result(i)(var_offset)(22 downto 16) := ep_nbytes(epconfig_link(i)(var_offset)); --NBytes
          if DEV_ARRAY(i).EP(j).EPDIR = EP_OUT then
            var_result(i)(var_offset)(15 downto  0) := "00000" & 
                                                       "10"    &
                                                       EP_OUT  &
                                                       std_logic_vector(to_unsigned(var_epram_bufout,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epram_bufout := var_epram_bufout + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epram_bufout := var_epram_bufout + 1;
            end if;
          else
            var_result(i)(var_offset)(15 downto  0) := "00000" & 
                                                       "10"    &
                                                       EP_IN   &
                                                       std_logic_vector(to_unsigned(var_epram_bufin,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epram_bufin := var_epram_bufin + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epram_bufin := var_epram_bufin + 1;
            end if;
          end if;

          var_result(i)(var_offset+1)(31)           := ep_active(epconfig_link(i)(var_offset+1)) and not ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset+1)(30)           := ep_disable(epconfig_link(i)(var_offset+1));
          var_result(i)(var_offset+1)(29)           := ep_stall(epconfig_link(i)(var_offset+1));
          var_result(i)(var_offset+1)(28)           := ep_toggle_reset(epconfig_link(i)(var_offset+1));
          var_result(i)(var_offset+1)(27)           := '0';
          var_result(i)(var_offset+1)(26)           := DEV_ARRAY(i).EP(j).EPTYPE;

          var_result(i)(var_offset+1)(25 downto 23) := "000";
          var_result(i)(var_offset+1)(22 downto 16) := ep_nbytes(epconfig_link(i)(var_offset+1)); --NBytes
          if DEV_ARRAY(i).EP(j).EPDIR = EP_OUT then
            var_result(i)(var_offset+1)(15 downto  0) := "00000" & 
                                                         "10"    &
                                                         EP_OUT  &
                                                         std_logic_vector(to_unsigned(var_epram_bufout,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epram_bufout := var_epram_bufout + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epram_bufout := var_epram_bufout + 1;
            end if;
          else
            var_result(i)(var_offset)(15 downto  0) := "00000" & 
                                                       "10"    &
                                                       EP_IN   &
                                                       std_logic_vector(to_unsigned(var_epram_bufin,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epram_bufin := var_epram_bufin + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epram_bufin := var_epram_bufin + 1;
            end if;
          end if;

        -- not supported
        when others =>
          assert false
            report "Error : Not supported.";
        end case;
      end loop;
    end loop;
  return var_result;
end;


-- This function returns the hardcoded endpoint config list.
function func_epconfig_table(ep0_out_active   : std_logic_vector(C_NBDEV-1 downto 0);
                             ep0_in_active    : std_logic_vector(C_NBDEV-1 downto 0);
                             ep0_setup_dir    : std_logic_vector(C_NBDEV-1 downto 0);
                             ep0_outin_nbytes : std_logic_vector(C_NBDEV*15-1 downto 0);
                             ep0_data_buffer  : std_logic_vector(C_NBDEV*8-1 downto 0);
                             ep_active        : std_logic_vector(C_NBPHYSEP-1 downto 0);
                             ep_disable       : std_logic_vector(C_NBPHYSEP-1 downto 0);
                             ep_stall         : std_logic_vector(C_NBPHYSEP-1 downto 0);
                             ep_toggle_reset  : std_logic_vector(C_NBPHYSEP-1 downto 0);
                             ep_nbytes        : t_reg_ep_nbytes;
                             epconfig_link    : t_epconfig_link
                              ) return t_epconfig_all is
variable var_epram_bufin,  var_epnoram_bufin   : integer range 0 to 255;
variable var_epram_bufout, var_epnoram_bufout  : integer range 0 to 255;
variable var_result : t_epconfig_all;
variable var_offset : integer range 0 to 63;
begin
  var_epram_bufin    := 0;
  var_epnoram_bufin  := 0;
  var_epram_bufout   := 0;
  var_epnoram_bufout := 0;
  var_result := (others => (others => X"40000000")); -- Set disable bit by default
  for i in 0 to C_NBDEV-1 loop
    -- assign EP0 OUT values
    var_result(i)(0)(31) := ep0_out_active(i);
    var_result(i)(0)(30) := '0'; --Disable bit
    var_result(i)(0)(29) := '1'; --Stall bit
    var_result(i)(0)(28) := '0'; --Toggle reset
    var_result(i)(0)(27) := '0'; --Toggle reset value
    var_result(i)(0)(26) := '0'; --Endpoint type

    if ep0_setup_dir(i) = '0' then -- Host to device
      var_result(i)(0)(25 downto 11) := ep0_outin_nbytes((i+1)*15-1 downto i*15); --NBytes
    else
      var_result(i)(0)(25 downto 11) := "000000001000000"; --NBytes - set to maxpacketsize to receive any size of status packet
    end if;
    var_result(i)(0)(10 downto  0) := "000" & ep0_data_buffer((i+1)*8-1 downto i*8); -- Addres Offset

    -- assign EP0 SETUP values
    var_result(i)(1)(31 downto 16) := (others => '0');

    var_result(i)(1)(15 downto  0) := "00000" & "001" & '0' & std_logic_vector(to_unsigned(i,7)); -- Address Offset
    
    -- assign EP0 IN values
    var_result(i)(2)(31) := ep0_in_active(i);
    var_result(i)(2)(30) := '0'; --Disable bit
    var_result(i)(2)(29) := '1'; --Stall bit
    var_result(i)(2)(28) := '0'; --Toggle reset
    var_result(i)(2)(27) := '0'; --Toggle reset value
    var_result(i)(2)(26) := '0'; --Endpoint type

    if ep0_setup_dir(i) = '0' then -- Host to device
      var_result(i)(2)(25 downto 11) := (others => '0'); --NBytes
    else
      var_result(i)(2)(25 downto 11) := ep0_outin_nbytes((i+1)*15-1 downto i*15); --NBytes
    end if;
    var_result(i)(2)(10 downto  0) := "000" & ep0_data_buffer((i+1)*8-1 downto i*8); -- Addres Offset

    -- assign values for other endpoints
    for j in 0 to DEV_ARRAY(i).NBPHYSEP-1 loop
      if DEV_ARRAY(i).EP(j).EPDIR = '1' then
        var_offset := 4*DEV_ARRAY(i).EP(j).EPNB + 2;
      else
        var_offset := 4*DEV_ARRAY(i).EP(j).EPNB;
      end if;
      case DEV_ARRAY(i).EP(j).BUFF is
        -- no buffer
        when 0 =>
          var_result(i)(var_offset)(31)           := ep_active(epconfig_link(i)(var_offset)) and not ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(30)           := ep_disable(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(29)           := ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(28)           := ep_toggle_reset(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(27)           := '0';
          var_result(i)(var_offset)(26)           := DEV_ARRAY(i).EP(j).EPTYPE;

          var_result(i)(var_offset)(25 downto 23) := "000";
          var_result(i)(var_offset)(22 downto 11) := "00000" & ep_nbytes(epconfig_link(i)(var_offset)); --NBytes
          if DEV_ARRAY(i).EP(j).EPDIR = EP_OUT then
            var_result(i)(var_offset)(10 downto  0) := "01"    &
                                                       EP_OUT  &
                                                       std_logic_vector(to_unsigned(var_epnoram_bufout,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epnoram_bufout := var_epnoram_bufout + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epnoram_bufout := var_epnoram_bufout + 1;
            end if;
          else
            var_result(i)(var_offset)(10 downto  0) := "01"    &
                                                       EP_IN   &
                                                       std_logic_vector(to_unsigned(var_epnoram_bufin,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epnoram_bufin := var_epnoram_bufin + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epnoram_bufin := var_epnoram_bufin + 1;
            end if;
          end if;
        -- single buffer
        when 1 =>
          var_result(i)(var_offset)(31)           := ep_active(epconfig_link(i)(var_offset)) and not ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(30)           := ep_disable(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(29)           := ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(28)           := ep_toggle_reset(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(27)           := '0';
          var_result(i)(var_offset)(26)           := DEV_ARRAY(i).EP(j).EPTYPE;

          var_result(i)(var_offset)(26)           := '1';  --Endpoint type = Periodic endpoint
          var_result(i)(var_offset)(27)           := '1';  --Interrupt Endpoint TV=1/T=1
          var_result(i)(var_offset)(25 downto 23) := "000";
          var_result(i)(var_offset)(22 downto 11) := "00000" & ep_nbytes(epconfig_link(i)(var_offset)); --NBytes
          if DEV_ARRAY(i).EP(j).EPDIR = EP_OUT then
            var_result(i)(var_offset)(10 downto  0) := "10"    &
                                                       EP_OUT  &
                                                       std_logic_vector(to_unsigned(var_epram_bufout,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epram_bufout := var_epram_bufout + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epram_bufout := var_epram_bufout + 1;
            end if;
          else
            var_result(i)(var_offset)(10 downto  0) := "10"    &
                                                       EP_IN   &
                                                       std_logic_vector(to_unsigned(var_epram_bufin,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epram_bufin := var_epram_bufin + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epram_bufin := var_epram_bufin + 1;
            end if;
          end if;

        -- double buffer
        when 2 =>
          var_result(i)(var_offset)(31)           := ep_active(epconfig_link(i)(var_offset)) and not ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(30)           := ep_disable(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(29)           := ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(28)           := ep_toggle_reset(epconfig_link(i)(var_offset));
          var_result(i)(var_offset)(27)           := '0';
          var_result(i)(var_offset)(26)           := DEV_ARRAY(i).EP(j).EPTYPE;

          var_result(i)(var_offset)(26)           := '1';  --Endpoint type = Periodic endpoint
          var_result(i)(var_offset)(27)           := '1';  --Interrupt Endpoint TV=1/T=1
          var_result(i)(var_offset)(25 downto 23) := "000";
          var_result(i)(var_offset)(22 downto 11) := "00000" & ep_nbytes(epconfig_link(i)(var_offset)); --NBytes
          if DEV_ARRAY(i).EP(j).EPDIR = EP_OUT then
            var_result(i)(var_offset)(10 downto  0) := "10"    &
                                                       EP_OUT  &
                                                       std_logic_vector(to_unsigned(var_epram_bufout,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epram_bufout := var_epram_bufout + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epram_bufout := var_epram_bufout + 1;
            end if;
          else
            var_result(i)(var_offset)(10 downto  0) := "10"    &
                                                       EP_IN   &
                                                       std_logic_vector(to_unsigned(var_epram_bufin,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epram_bufin := var_epram_bufin + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epram_bufin := var_epram_bufin + 1;
            end if;
          end if;
          var_result(i)(var_offset+1)(31)           := ep_active(epconfig_link(i)(var_offset+1)) and not ep_stall(epconfig_link(i)(var_offset));
          var_result(i)(var_offset+1)(30)           := ep_disable(epconfig_link(i)(var_offset+1));
          var_result(i)(var_offset+1)(29)           := ep_stall(epconfig_link(i)(var_offset+1));
          var_result(i)(var_offset+1)(28)           := ep_toggle_reset(epconfig_link(i)(var_offset+1));
          var_result(i)(var_offset+1)(27)           := '0';
          var_result(i)(var_offset+1)(26)           := DEV_ARRAY(i).EP(j).EPTYPE;

          var_result(i)(var_offset+1)(26)           := '1';  --Endpoint type = Periodic endpoint
          var_result(i)(var_offset+1)(27)           := '1';  --Interrupt Endpoint TV=1/T=1
          var_result(i)(var_offset+1)(25 downto 23) := "000";
          var_result(i)(var_offset+1)(22 downto 11) := "00000" & ep_nbytes(epconfig_link(i)(var_offset+1)); --NBytes
          if DEV_ARRAY(i).EP(j).EPDIR = EP_OUT then
            var_result(i)(var_offset+1)(10 downto  0) := "10"    &
                                                         EP_OUT  &
                                                         std_logic_vector(to_unsigned(var_epram_bufout,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epram_bufout := var_epram_bufout + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epram_bufout := var_epram_bufout + 1;
            end if;
          else
            var_result(i)(var_offset)(10 downto  0) := "10"    &
                                                       EP_IN   &
                                                       std_logic_vector(to_unsigned(var_epram_bufin,8)); --Address
            if DEV_ARRAY(i).EP(j).EPTYPE = ISO then
              var_epram_bufin := var_epram_bufin + ((DEV_ARRAY(i).EP(j).ISO_SIZE-1)/64);
            else
              var_epram_bufin := var_epram_bufin + 1;
            end if;
          end if;

        -- not supported
        when others =>
          --synthesis translate_off
          assert false
            report "Error : Not supported.";
          --synthesis translate_on
        end case;
      end loop;
    end loop;
  return var_result;
end;

-- This function determines the location in the bit map based on device number, endpoint number and buffer
function func_epconfig_link(DEV_ARRAY : t_dev_array) return t_epconfig_link is
variable var_ep_position : integer range 0 to C_NBPHYSEP;
variable var_offset      : integer range 0 to 63;
variable var_result      : t_epconfig_link;
begin
  var_ep_position := 0;
  var_result      := (others => (others => 0));
  for i in 0 to C_NBDEV-1 loop
    if DEV_ARRAY(i).NBPHYSEP > 0 then
      for j in 0 to DEV_ARRAY(i).NBPHYSEP-1 loop
        if DEV_ARRAY(i).EP(j).EPDIR = EP_IN then
          var_offset := 4*DEV_ARRAY(i).EP(j).EPNB + 2;
        else
          var_offset := 4*DEV_ARRAY(i).EP(j).EPNB;
        end if;
        case DEV_ARRAY(i).EP(j).BUFF is
          when 0 | 1 =>
            var_result(i)(var_offset)   := var_ep_position;
            var_ep_position             := var_ep_position + 1;
          when 2 =>
            var_result(i)(var_offset)   := var_ep_position;
            var_result(i)(var_offset+1) := var_ep_position;
            var_ep_position             := var_ep_position + 2;

          -- not supported
          when others =>
            assert false
              report "Error : Not supported.";
          end case;
      end loop;
    end if;
  end loop;
  return var_result;
end;

-- This function determines device number, endpoint number and buffer based on the location in the bit map
function func_epconfig_link_reverse(bitnumber : integer range 0 to C_NBPHYSEP-1) return t_ep is
variable var_ep_search : integer range 0 to C_NBPHYSEP-1;
variable var_result    : t_ep;
begin
  var_ep_search       := bitnumber;
  var_result.EPNB     := 0;
  var_result.EPDIR    := '0';
  var_result.BUFF     := 0;
  var_result.EPTYPE   := '0';
  var_result.ISO_SIZE := 0;
  for i in 0 to C_NBDEV-1 loop
    if DEV_ARRAY(i).NBPHYSEP > var_ep_search then
      var_result := DEV_ARRAY(i).EP(var_ep_search);
    else
      var_ep_search := var_ep_search - DEV_ARRAY(i).NBPHYSEP;
    end if;
  end loop;
  return var_result;
end;

-------------------------------------------------------
-- Device and endpoint configuration
-------------------------------------------------------
function FUNC_ASSIGN_DEV_ARRAY return t_dev_array is
variable var_nbdev  : integer;
variable var_nbep   : integer;
variable var_result : t_dev_array;
begin
  
  for i in 0 to C_NBDEV-1 loop
    var_result(i).NBPHYSEP := 0;
    for j in 0 to 29 loop
      var_result(i).EP(j).EPNB     := 0;
      var_result(i).EP(j).EPDIR    := EP_OUT;
      var_result(i).EP(j).BUFF     := 0;
      var_result(i).EP(j).EPTYPE   := NON_ISO;
      var_result(i).EP(j).ISO_SIZE := 0;
    end loop;
  end loop;
  
  var_nbdev := 0;
  
  --------------------------------
  --Definition for device 0 - HUB
  --------------------------------
  var_nbep  := 0;
  var_result(var_nbdev).EP(var_nbep).EPNB     := 1;
  var_result(var_nbdev).EP(var_nbep).EPDIR    := EP_IN;
  var_result(var_nbdev).EP(var_nbep).BUFF     := 0; -- no buffer
  var_result(var_nbdev).EP(var_nbep).EPTYPE   := NON_ISO; --0
  var_result(var_nbdev).EP(var_nbep).ISO_SIZE := 64;
  var_nbep := var_nbep + 1;
  var_result(var_nbdev).NBPHYSEP              := var_nbep;
  var_nbdev := var_nbdev + 1;

  --------------------------------

  --------------------------------
  --End of definition for devices
  --------------------------------
      
  
  return var_result;
end function FUNC_ASSIGN_DEV_ARRAY;

end usb_ep_config_pkg;
