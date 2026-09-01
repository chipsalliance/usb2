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
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

library usb_lib;
use usb_lib.usb_subcmp_pkg.all;
use usb_lib.usb_ep_config_pkg.all;

entity usb_app_hw_hub is
generic(C_HUB_NB_PORTS     : integer := 2;    --This can be maximum 255 according to USB spec 
        C_DATAWIDTH        : integer := 32);
port (
      sys_clk                : in  std_logic;
      sys_rst_n              : in  std_logic;
      sync_busreset          : in  std_logic;

      pie_speed              : in  std_logic_vector( 1 downto 0);

      -- HUB Status IN endpoint
      hub_epin_req           : in  std_logic;
      hub_epin_gnt           : out std_logic;
      hub_epin_addr          : in  std_logic_vector(2 downto 0); -- only needed when more than 31 downstream ports
      hub_epin_rdata         : out std_logic_vector(C_DATAWIDTH-1 downto 0);
      hub_epin_stall         : out std_logic;
      hub_epin_clear_buffer  : out std_logic;
      hub_epin_enable_buffer : out std_logic;
      hub_epin_buffer_size   : out std_logic_vector(6 downto 0);

      -- HUB Class-specific requests
      ep0_setupdone          : in  std_logic;
      ep0_request            : in  std_logic_vector( 6 downto 0);
      ep0_wvalue             : in  std_logic_vector(15 downto 0);
      ep0_windex             : in  std_logic_vector(15 downto 0);
      ep0_class_rdata        : out std_logic_vector(C_DATAWIDTH-1 downto 0);
      
      -- DOWNSTREAM PORTS
      hub_port_connect       : in  std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_port_enable        : out std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_port_reset         : out std_logic_vector(C_HUB_NB_PORTS-1 downto 0)

     );
end usb_app_hw_hub;

architecture RTL of usb_app_hw_hub is

constant C_HUB_MAX_NB_PORTS    : integer := 255;

signal hub_port_enable_int     : std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
signal hub_port_suspend        : std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
signal hub_port_suspend_change : std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
signal hub_port_reset_int      : std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
signal hub_port_reset_change   : std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
signal hub_port_connect_change : std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
signal hub_port_connect_d      : std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
signal hub_port_status_change  : std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
signal hub_dev_status_change   : std_logic;
signal hub_epin_rdata_buffer   : std_logic_vector(C_HUB_MAX_NB_PORTS downto 0);
signal data_index              : integer range 0 to C_HUB_NB_PORTS;
type t_hub_status is array (0 to C_HUB_NB_PORTS) of std_logic_vector(C_DATAWIDTH-1 downto 0);
signal hub_status              : t_hub_status;

begin

  PROC_REQUEST_HANDLING : process(sys_clk, sys_rst_n)
  variable var_port : integer range 0 to C_HUB_NB_PORTS-1;
  begin
    if sys_rst_n = '0' then
      hub_port_enable_int     <= (others => '0');
      hub_port_suspend        <= (others => '0');
      hub_port_suspend_change <= (others => '0');
      hub_port_reset_int      <= (others => '0');
      hub_port_reset_change   <= (others => '0');
      hub_port_connect_change <= (others => '0');
      hub_port_connect_d      <= (others => '0');
      data_index              <= 0;
    
    elsif rising_edge(sys_clk) then
      
      hub_port_reset_int <= (others => '0');
      hub_port_connect_d <= hub_port_connect;
      
      for i in 0 to C_HUB_NB_PORTS-1 loop
        if hub_port_connect(i) /= hub_port_connect_d(i) then
          hub_port_connect_change(i) <= '1';
        end if;
      end loop;
    
      if ep0_setupdone = '1' then
        case ep0_request is
          when C_CLASS_REQ_CLEAR_FEATURE =>
            if to_integer(unsigned(ep0_windex(15 downto 0))) > C_HUB_NB_PORTS then
              -- TODO : STALL request
            elsif to_integer(unsigned(ep0_windex)) = 0 then  --ClearHubFeature
              -- TODO : complete transfer - anything to set ???
            else                                             --ClearPortFeature
              var_port := to_integer(unsigned(ep0_windex)) - 1;
              case to_integer(unsigned(ep0_wvalue)) is
                when 0  | --Port_Connect
                     3  | --Port_Overcurrent
                     4  | --Port_Reset
                     8  | --Port_Power
                     9  | --Port_Low_speed
                     17 | --C_Port_Enable
                     19 | --C_Port_Overcurrent
                     21 | --Port_Test
                     22   --Port_Indicator
                      =>
                  null;
                when 1 => --Port_Enable
                  hub_port_enable_int(var_port)     <= '0';
                when 2 => --Port_Suspend
                  hub_port_suspend(var_port)        <= '0';
                  hub_port_suspend_change(var_port) <= '1';
                when 16 => --C_Port_Connection
                  hub_port_connect_change(var_port) <= '0';
                when 18 => --C_Port_Suspend
                  hub_port_suspend_change(var_port) <= '0';
                when 20 => --C_Port_Reset
                  hub_port_reset_change(var_port)   <= '0';
                when others =>
                  -- TODO : STALL request
              end case;
            end if;
    
          when C_CLASS_REQ_GET_STATUS =>
            if to_integer(unsigned(ep0_windex(15 downto 0))) > C_HUB_NB_PORTS then
              -- TODO : STALL request
            else                                             --GetHubStatus / GetPortStatus
              data_index <= to_integer(unsigned(ep0_windex));
            end if;
    
          when C_CLASS_REQ_SET_FEATURE =>
            if to_integer(unsigned(ep0_windex(15 downto 0))) > C_HUB_NB_PORTS then
              -- TODO : STALL request
            elsif to_integer(unsigned(ep0_windex)) = 0 then  --SetHubFeature
              -- TODO : complete transfer - anything to set ???
            else                                             --SetPortFeature
              var_port := to_integer(unsigned(ep0_windex)) - 1;
              case to_integer(unsigned(ep0_wvalue)) is
                when 0  | --Port_Connect
                     3  | --Port_Overcurrent
                     8  | --Port_Power
                     9  | --Port_Low_speed
                     16 | --C_Port_Connection
                     17 | --C_Port_Enable
                     18 | --C_Port_Suspend
                     19 | --C_Port_Overcurrent
                     20 | --C_Port_Reset
                     21 | --Port_Test
                     22   --Port_Indicator
                     =>
                       null;
                when 1 => --Port_Enable
                  hub_port_enable_int(var_port)     <= '1';
                when 2 => --Port_Suspend
                              hub_port_suspend(var_port)        <= '1'; 
                when 4 => --Port_Reset
                        hub_port_reset_int(var_port)      <= '1';
                        hub_port_reset_change(var_port)   <= '1';
                        hub_port_enable_int(var_port)     <= '1';
                        hub_port_suspend(var_port)        <= '0';
                        hub_port_suspend_change(var_port) <= '0';
                when others =>
                  -- TODO : STALL request
              end case;
            end if;
    
          when others =>
           null;

        end case;
  
      end if;
      if sync_busreset = '1' then
        hub_port_enable_int     <= (others => '0');
        hub_port_suspend	<= (others => '0');
        hub_port_suspend_change <= (others => '0');
        hub_port_reset_int      <= (others => '0');
        hub_port_reset_change   <= (others => '0');
        hub_port_connect_change <= (others => '0');
        hub_port_connect_d      <= (others => '0');
        data_index              <= 0;
      end if;
    end if;
  end process PROC_REQUEST_HANDLING;


----------------------------------
-- HUB status
----------------------------------
hub_status(0)(C_DATAWIDTH-1 downto 1)    <= (others => '0');
hub_status(0)(0)              <= '1';

GEN_HUB_PORT_STATUS : for i in 0 to C_HUB_NB_PORTS-1 generate
begin
  hub_status(i+1)(C_DATAWIDTH-1 downto 21) <= (others => '0');
  hub_status(i+1)(20)           <= hub_port_reset_change(i);
  hub_status(i+1)(19)           <= '0'; -- no overcurrent detection
  hub_status(i+1)(18)           <= hub_port_suspend_change(i);
  hub_status(i+1)(17)           <= '0'; --hub_port_enable_change;
  hub_status(i+1)(16)           <= hub_port_connect_change(i);
  hub_status(i+1)(15 downto  11) <= (others => '0');
  hub_status(i+1)(10 downto  9) <= "10" when (pie_speed = HIGH_SPEED) else "00";  -- port_high_speed = 1 &  port_low_speed = 0
  hub_status(i+1)( 8)           <= '1'; --hub_port_power; Can this be fixed to one ?
  hub_status(i+1)( 7 downto  5) <= (others => '0');
  hub_status(i+1)( 4)           <= '0'; -- hub_port_reset_int(i); This is only high for one clock. The return value can be forced to zero.
  hub_status(i+1)( 3)           <= '0'; -- no overcurrent detection
  hub_status(i+1)( 2)           <= hub_port_suspend(i);
  hub_status(i+1)( 1)           <= hub_port_enable_int(i);
  hub_status(i+1)( 0)           <= hub_port_connect(i); --embedded device is always connected.
                                                        --This is equal to connect bit, set by ARM SW.
end generate GEN_HUB_PORT_STATUS;

hub_port_enable <= hub_port_enable_int;
hub_port_reset  <= hub_port_reset_int;
ep0_class_rdata <= hub_status(data_index);

----------------------------------
-- HUB EP1 IN status
----------------------------------

GEN_HUB_STATUS_EP1 : for i in 0 to C_HUB_NB_PORTS-1 generate
begin
  hub_port_status_change(i) <= '1' when hub_port_reset_change(i)   = '1' or
                                        hub_port_suspend_change(i) = '1' or
                                        hub_port_connect_change(i) = '1'
                                   else '0';
end generate GEN_HUB_STATUS_EP1;

hub_dev_status_change <= '0'; --no hub change bits will be set as this is only for overcurrent and local power source changes

PROC_EPIN_ACTIVE : process(hub_port_status_change, hub_dev_status_change)
variable var_active : std_logic;
begin
  var_active := hub_dev_status_change;
  for i in 0 to C_HUB_NB_PORTS-1 loop
    var_active := var_active or hub_port_status_change(i);
  end loop;
  hub_epin_enable_buffer <= var_active;
end process PROC_EPIN_ACTIVE;

hub_epin_stall         <= '0';
hub_epin_clear_buffer  <= '0';
hub_epin_buffer_size   <= std_logic_vector(to_unsigned(((C_HUB_NB_PORTS+1)/8)+1,7));

hub_epin_gnt <= hub_epin_req;

PROC_HUB_EPIN_DATA : process(hub_epin_addr, hub_dev_status_change, hub_port_status_change, hub_epin_rdata_buffer)
variable var_addr : integer range 0 to ((C_HUB_MAX_NB_PORTS + 1)/C_DATAWIDTH)-1;
begin
  hub_epin_rdata_buffer(0)                           <= hub_dev_status_change;
  hub_epin_rdata_buffer(C_HUB_NB_PORTS downto 1)     <= hub_port_status_change;
  hub_epin_rdata_buffer(C_HUB_MAX_NB_PORTS downto C_HUB_NB_PORTS+1) <= (others => '0');
 
  if C_DATAWIDTH = 32 then
    var_addr := to_integer(unsigned(hub_epin_addr));
  elsif C_DATAWIDTH = 64 then
    var_addr := to_integer(unsigned(hub_epin_addr(2 downto 1)));
  else
    assert false
    report "Error : C_DATAWIDTH value not supported.";
  end if;
  for i in 0 to C_DATAWIDTH-1 loop
    hub_epin_rdata(i) <= hub_epin_rdata_buffer(var_addr*C_DATAWIDTH+i);
  end loop;
end process PROC_HUB_EPIN_DATA;


end RTL; --usb_app_hw_hub
