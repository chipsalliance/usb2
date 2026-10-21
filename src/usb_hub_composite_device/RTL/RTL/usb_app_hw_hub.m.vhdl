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

use work.usb_subcmp_pkg.all;
use work.usb_ep_config_pkg.all;

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
      ep0_class_stall        : out std_logic;
      
      -- DOWNSTREAM PORTS
      hub_port_connect       : in  std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_port_enable        : out std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_port_suspend       : out std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_port_l1            : out std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_port_reset         : out std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_port_remotewakeup    : in  std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_port_lpmremotewakeup : in  std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_lpm_sup            : in  std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_lpm_data_pending   : in  std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_port_lpm_rw_enable : out std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
      hub_port_lpm_hird_sw   : in  std_logic_vector(C_HUB_NB_PORTS*4-1 downto 0);
      hub_port_lpm_hird_hw   : out std_logic_vector(C_HUB_NB_PORTS*4-1 downto 0)
     );
end usb_app_hw_hub;

architecture RTL of usb_app_hw_hub is

constant C_HUB_MAX_NB_PORTS    : integer := 255;
constant C_LPM_SUCCESS         : std_logic_vector(7 downto 0) := X"00";
constant C_LPM_NYET            : std_logic_vector(7 downto 0) := X"10"; --Status is NYET when datapending bit is set.
constant C_LPM_TIMEOUT         : std_logic_vector(7 downto 0) := X"11"; --Note : this is not used with embedded ports.
constant C_LPM_STALL           : std_logic_vector(7 downto 0) := X"30"; --Return a STALL if LPM_SUP for this port is not set.

signal hub_port_enable_int     : std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
signal hub_port_suspend_int    : std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
signal hub_port_suspend_change : std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
signal hub_port_l1_int         : std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
signal hub_port_l1_change      : std_logic_vector(C_HUB_NB_PORTS-1 downto 0);
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
signal hub_l1_status           : t_hub_status;
signal hub_port_lpm_hird_hw_int : std_logic_vector(C_HUB_NB_PORTS*4-1  downto 0);

begin

  PROC_CLASS_STALL : process(ep0_request, ep0_setupdone, ep0_windex, ep0_wvalue)
  begin --CLASS STALL signal must be high together with ep0_setupdone to prevent active bit from being set.
      ep0_class_stall <= '0';
      if ep0_setupdone = '1' then
        case ep0_request is
          when C_CLASS_REQ_CLEAR_FEATURE =>
            if to_integer(unsigned(ep0_windex(7 downto 0))) > C_HUB_NB_PORTS then --Port number is located in bits 7..0 of wIndex
              ep0_class_stall <= '1';
            elsif to_integer(unsigned(ep0_windex)) /= 0 then  --ClearPortFeature
              case to_integer(unsigned(ep0_wvalue)) is
                when 0  | --Port_Connect
                     1  | --Port_Enable
                     2  | --Port_Suspend
                     3  | --Port_Overcurrent
                     4  | --Port_Reset
                     8  | --Port_Power
                     9  | --Port_Low_speed
                     10 | --Port_L1
                     16 | --C_Port_Connection
                     17 | --C_Port_Enable
                     18 | --C_Port_Suspend
                     19 | --C_Port_Overcurrent
                     20 | --C_Port_Reset
                     21 | --Port_Test
                     22 | --Port_Indicator
                     23   --C_Port_L1
                      =>
                  ep0_class_stall <= '0';
                when others =>
                  ep0_class_stall <= '1'; --Set STALL as request is not supported
              end case;
            else --ClearHubFeature
              null;
            end if;
    
          when C_CLASS_REQ_GET_STATUS =>
            if to_integer(unsigned(ep0_windex(15 downto 0))) > C_HUB_NB_PORTS then
              ep0_class_stall <= '1';
             end if;
    
          when C_CLASS_REQ_SET_FEATURE =>
            if to_integer(unsigned(ep0_windex(7 downto 0))) > C_HUB_NB_PORTS then --Port number is located in bits 7..0 of wIndex
              ep0_class_stall <= '1';
            elsif to_integer(unsigned(ep0_windex)) /= 0 then --SetPortFeature
              case to_integer(unsigned(ep0_wvalue)) is
                when 0  | --Port_Connect
                     1  | --Port_Enable
                     2  | --Port_Suspend
                     3  | --Port_Overcurrent
                     4  | --Port_Reset
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
                  ep0_class_stall <= '0';
                when others =>
                  ep0_class_stall <= '1'; --Set STALL as request is not supported
              end case;
            else --SetHubFeature
              null;
          end if;
          
          when C_CLASS_REQ_SET_AND_TEST =>
            if (to_integer(unsigned(ep0_windex(3 downto 0))) = 0)              or
               (to_integer(unsigned(ep0_windex(3 downto 0))) > C_HUB_NB_PORTS) or --Port number is located in bits 3..0 of wIndex
               (to_integer(unsigned(ep0_wvalue)) /= 10) then --Feature selector is not equal to Port_L1
              ep0_class_stall <= '1';
            end if;
          
          when others =>
            null;

        end case;
          
      end if;    
  end process PROC_CLASS_STALL;

  PROC_REQUEST_HANDLING : process(sys_clk, sys_rst_n)
  variable var_port : integer range 0 to C_HUB_NB_PORTS-1;
  begin
    if sys_rst_n = '0' then
      hub_port_enable_int     <= (others => '0');
      hub_port_suspend_int    <= (others => '0');
      hub_port_suspend_change <= (others => '0');
      hub_port_l1_int         <= (others => '0');
      hub_port_l1_change      <= (others => '0');
      hub_port_reset_int      <= (others => '0');
      hub_port_reset_change   <= (others => '0');
      hub_port_connect_change <= (others => '0');
      hub_port_connect_d      <= (others => '0');
      hub_port_lpm_rw_enable  <= (others => '0');
      hub_port_lpm_hird_hw_int<= (others => '0');
      data_index              <= 0;
    
    elsif rising_edge(sys_clk) then
      
      hub_port_reset_int <= (others => '0');
      hub_port_connect_d <= hub_port_connect;
      
      for i in 0 to C_HUB_NB_PORTS-1 loop
        if hub_port_connect(i) /= hub_port_connect_d(i) then
          hub_port_connect_change(i) <= '1';
        end if;
        if hub_port_enable_int(i) = '1' and hub_port_reset_int(i) = '1' then
            hub_port_reset_change(i)   <= '1';
        end if;    
      end loop;
    
      if ep0_setupdone = '1' then
        case ep0_request is
          when C_CLASS_REQ_CLEAR_FEATURE =>
            if to_integer(unsigned(ep0_windex(7 downto 0))) > C_HUB_NB_PORTS then --Port number is located in bits 7..0 of wIndex
              null; -- A stall will be returned upon this request
            elsif to_integer(unsigned(ep0_windex)) /= 0 then  --ClearPortFeature
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
                  hub_port_suspend_int(var_port)    <= '0';
                  hub_port_suspend_change(var_port) <= '1';
                when 10 => --Port_L1
                  hub_port_l1_int(var_port)         <= '0';
                  hub_port_l1_change(var_port)      <= hub_port_l1_int(var_port); --If Port is in L1 set change bit, otherwise not.                 
                when 16 => --C_Port_Connection
                  hub_port_connect_change(var_port) <= '0';
                when 18 => --C_Port_Suspend
                  hub_port_suspend_change(var_port) <= '0';
                when 20 => --C_Port_Reset
                  hub_port_reset_change(var_port)   <= '0';
                when 23 => --C_Port_L1
                  hub_port_l1_change(var_port)      <= '0';
                when others =>
                  null;
              end case;
            end if;
    
          when C_CLASS_REQ_GET_STATUS =>
            if to_integer(unsigned(ep0_windex(15 downto 0))) <= C_HUB_NB_PORTS then --GetHubStatus / GetPortStatus
              data_index <= to_integer(unsigned(ep0_windex));
            end if;
    
          when C_CLASS_REQ_SET_FEATURE =>
            if to_integer(unsigned(ep0_windex(7 downto 0))) > C_HUB_NB_PORTS then --Port number is located in bits 7..0 of wIndex
              null; -- A stall will be returned upon this request
            elsif to_integer(unsigned(ep0_windex)) /= 0 then --SetPortFeature
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
                        hub_port_suspend_int(var_port)    <= '1'; 
                when 4 => --Port_Reset
                        hub_port_reset_int(var_port)      <= '1';
                        hub_port_enable_int(var_port)     <= '1';
                        hub_port_suspend_int(var_port)    <= '0';
                        hub_port_suspend_change(var_port) <= '0';
                when others =>
                  null;
              end case;
            end if;
    
          when C_CLASS_REQ_SET_AND_TEST =>
            if to_integer(unsigned(ep0_windex(3 downto 0))) = 0 then
              null; -- A stall will be returned upon this request
            elsif to_integer(unsigned(ep0_windex(3 downto 0))) <= C_HUB_NB_PORTS then --SetandTestPortFeature
              data_index <= to_integer(unsigned(ep0_windex(3 downto 0)));
              var_port := to_integer(unsigned(ep0_windex(3 downto 0))) - 1;
              if to_integer(unsigned(ep0_wvalue)) = 10 and   -- Feature selector = PORT_L1
                 hub_port_enable_int(var_port)    = '1' then -- Downstream port is enabled
                if hub_lpm_sup(var_port) = '1' and
                   hub_lpm_data_pending(var_port) = '0' and
                   ep0_windex(7 downto 4) >= hub_port_lpm_hird_sw(var_port*4+3 downto var_port*4) then
                  hub_port_l1_int(var_port)    <= '1';
                  hub_port_l1_change(var_port) <= '1';
                end if;
                hub_port_lpm_rw_enable(var_port) <= ep0_windex(15);
                hub_port_lpm_hird_hw_int(var_port*4+3 downto var_port*4) <= ep0_windex(7 downto 4);
              end if;
            end if;
          
          when others =>
           null;

        end case;
  
      end if;
      if sync_busreset = '1' then
        hub_port_enable_int     <= (others => '0');
        hub_port_suspend_int	<= (others => '0');
        hub_port_suspend_change <= (others => '0');
        hub_port_l1_int         <= (others => '0');
        hub_port_l1_change      <= (others => '0');
        hub_port_reset_int      <= (others => '0');
        hub_port_reset_change   <= (others => '0');
        hub_port_connect_change <= (others => '0');
        hub_port_connect_d      <= (others => '0');
        data_index              <= 0;
      end if;
    
      for i in 0 to C_HUB_NB_PORTS-1 loop
        if hub_port_connect(i) = '0' then
          hub_port_enable_int(i)     <= '0';
          hub_port_suspend_int(i)    <= '0';
          hub_port_suspend_change(i) <= '0';
          hub_port_l1_int(i)         <= '0';
          hub_port_l1_change(i)      <= '0';
          hub_port_reset_change(i)   <= '0';
        elsif hub_port_enable_int(i) = '0' then
          hub_port_suspend_int(i)    <= '0';
          hub_port_suspend_change(i) <= '0';
          hub_port_l1_int(i)         <= '0';
          hub_port_l1_change(i)      <= '0';          
          hub_port_reset_change(i)   <= '0';
        end if;
        if hub_port_remotewakeup(i) = '1' then
          hub_port_suspend_int(i)    <= '0';
        end if;
        if hub_port_lpmremotewakeup(i) = '1' then
          hub_port_l1_int(i)         <= '0';
        end if;
      end loop;
    end if;
  end process PROC_REQUEST_HANDLING;

hub_port_lpm_hird_hw <= hub_port_lpm_hird_hw_int;

----------------------------------
-- HUB status
----------------------------------
hub_status(0)(C_DATAWIDTH-1 downto 2) <= (others => '0');
hub_status(0)(1)                      <= '0'; --Hub contains only embedded ports. This does not require any overcurrent detection. Fixed to zero
hub_status(0)(0)                      <= '0'; --Hub and downstream ports run always on a local power supply. 
                                              --This bit can be fixed to zero (Local Power Source ok)

GEN_HUB_PORT_STATUS : for i in 0 to C_HUB_NB_PORTS-1 generate
begin
  hub_status(i+1)(C_DATAWIDTH-1 downto 22) <= (others => '0');
  hub_status(i+1)(21)           <= hub_port_l1_change(i);
  hub_status(i+1)(20)           <= hub_port_reset_change(i);
  hub_status(i+1)(19)           <= '0'; -- no overcurrent detection
  hub_status(i+1)(18)           <= hub_port_suspend_change(i);
  hub_status(i+1)(17)           <= '0'; --hub_port_enable_change;
  hub_status(i+1)(16)           <= hub_port_connect_change(i);
  hub_status(i+1)(15 downto  11) <= (others => '0');
  hub_status(i+1)(10 downto  9) <= "10" when (pie_speed = HIGH_SPEED) else "00";  -- port_high_speed = 1 &  port_low_speed = 0
  hub_status(i+1)( 8)           <= '1'; --hub_port_power;
  hub_status(i+1)( 7 downto  6) <= (others => '0');
  hub_status(i+1)( 5)           <= hub_port_l1_int(i);
  hub_status(i+1)( 4)           <= '0'; -- hub_port_reset_int(i); This is only high for one clock. The return value can be forced to zero.
  hub_status(i+1)( 3)           <= '0'; -- no overcurrent detection
  hub_status(i+1)( 2)           <= hub_port_suspend_int(i);
  hub_status(i+1)( 1)           <= hub_port_enable_int(i);
  hub_status(i+1)( 0)           <= hub_port_connect(i); --embedded device is always connected.
                                                        --This is equal to connect bit, set by ARM SW.
end generate GEN_HUB_PORT_STATUS;

hub_l1_status(0) <= (others => '0');
GEN_HUB_L1_STATUS : for i in 0 to C_HUB_NB_PORTS-1 generate
begin
  hub_l1_status(i+1)(C_DATAWIDTH-1 downto 8)   <= (others => '0');
  hub_l1_status(i+1)(7 downto 0) <= C_LPM_STALL when hub_lpm_sup(i)          = '0' else
                                    C_LPM_NYET  when (hub_port_lpm_hird_sw(4*i+3 downto 4*i) > hub_port_lpm_hird_hw_int(4*i+3 downto 4*i)) or hub_lpm_data_pending(i) = '1' else
                                    C_LPM_SUCCESS;
end generate GEN_HUB_L1_STATUS;

hub_port_enable  <= hub_port_enable_int;
hub_port_reset   <= hub_port_reset_int;
hub_port_suspend <= hub_port_suspend_int;
hub_port_l1      <= hub_port_l1_int;
ep0_class_rdata  <= hub_l1_status(data_index) when (ep0_request = C_CLASS_REQ_SET_FEATURE) else hub_status(data_index);

----------------------------------
-- HUB EP1 IN status
----------------------------------

GEN_HUB_STATUS_EP1 : for i in 0 to C_HUB_NB_PORTS-1 generate
begin
  hub_port_status_change(i) <= '1' when hub_port_l1_change(i)      = '1' or
                                        hub_port_reset_change(i)   = '1' or
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
