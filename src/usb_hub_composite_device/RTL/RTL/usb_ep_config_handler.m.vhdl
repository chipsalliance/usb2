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
use usb_lib.usb_ep_config_pkg.all;

entity usb_ep_config_handler is
generic(C_NBPHYSEP     : integer := 3;
        C_NBDEV        : integer := 2;
        C_EPADDRWIDTH  : integer := 16;  --hs 11
        C_EPNBYTEWIDTH : integer := 10;  --hs 15
        C_DATAWIDTH    : integer := 32;
        HIGH_SPEED_SUPPORT : boolean := FALSE );
port (
      clk                 : in  std_logic;
      rst_n               : in  std_logic;

      upd_dma_addr        : in  std_logic_vector(14 downto 0);
      upd_dma_req         : in  std_logic;
      upd_dma_gnt         : out std_logic;
      upd_dma_write       : in  std_logic;
      upd_dma_wdata       : in  std_logic_vector(C_DATAWIDTH-1 downto 0);
      upd_dma_rdata       : out std_logic_vector(C_DATAWIDTH-1 downto 0);

      --ep0 interface
      ep0_setupdone       : in  std_logic_vector(C_NBDEV-1 downto 0);
      ep0_out_active      : in  std_logic;
      ep0_in_active       : in  std_logic;
      ep0_outin_nbytes    : in  std_logic_vector(C_EPNBYTEWIDTH-1 downto 0);
      ep0_setup_dir       : in  std_logic;
      ep0_data_buffer     : in  std_logic_vector(7 downto 0);   -- buffer address offset is limited to 8 bits (agains normally 12 bits) for hw devices 

      ep_clk              : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_rst_n            : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_stall            : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_clear_buffer     : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_enable_buffer    : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_buffer_size      : in  std_logic_vector(C_NBPHYSEP*7-1 downto 0); --Buffer_size is a 7 bit signal

      buf_nbytes          : out std_logic_vector(C_NBPHYSEP*11 -1 downto 0); --Range should be dependent if double buffer supported or not
      buf_reset_addr_ptr  : out std_logic_vector(C_NBPHYSEP-1 downto 0); --Range should be dependent if double buffer supported or not

      ep_bufinuse         : out std_logic_vector(C_NBPHYSEP+1 downto 0);

      ep_set_stall        : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_clear_stall      : in  std_logic_vector(C_NBPHYSEP-1 downto 0);
      epconfig_stall      : out std_logic_vector(C_NBPHYSEP-1 downto 0);

      ep0_device_config   : in  std_logic_vector(C_NBDEV-1 downto 0)
     );
end usb_ep_config_handler;

architecture RTL of usb_ep_config_handler is

signal reg_ep0_out_active  : std_logic_vector(C_NBDEV-1 downto 0);
signal reg_ep0_in_active   : std_logic_vector(C_NBDEV-1 downto 0);
signal reg_ep0_outin_bytes : std_logic_vector(C_NBDEV*C_EPNBYTEWIDTH-1 downto 0);
signal reg_ep0_data_buffer : std_logic_vector(C_NBDEV*8-1 downto 0);
signal reg_ep0_dir         : std_logic_vector(C_NBDEV-1 downto 0);

signal reg_ep_active       : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal reg_ep_active_s     : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal reg_ep_active_ss    : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal reg_ep_disable      : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal reg_ep_stall        : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal reg_ep_toggle_reset : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal reg_ep_nbytes       : t_reg_ep_nbytes;

signal device   : integer range 0 to C_NBDEV-1;
signal offset   : integer range 0 to 63; --offset in 32 bit dword

signal epconfig_link : integer range 0 to C_NBPHYSEP;
signal epconfig_list : t_epconfig_all;

signal ep_set_enable_toggle      : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal ep_set_enable_toggle_s    : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal ep_set_enable_toggle_ss   : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal ep_set_enable_toggle_sss  : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal ep_set_enable_toggle_sync : std_logic_vector(C_NBPHYSEP-1 downto 0);

signal nbytes_update_toggle      : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal nbytes_update_toggle_s    : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal nbytes_update_toggle_ss   : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal nbytes_update_toggle_sss  : std_logic_vector(C_NBPHYSEP-1 downto 0);
signal nbytes_update_toggle_sync : std_logic_vector(C_NBPHYSEP-1 downto 0);

signal buf_nbytes_int            : t_reg_ep_nbytes;
signal nbytes                    : t_reg_ep_nbytes;


begin

  device   <= to_integer(unsigned(upd_dma_addr(14 downto 8))) when to_integer(unsigned(upd_dma_addr(14 downto 8))) < C_NBDEV
                                                              else 0;
  offset   <= to_integer(unsigned(upd_dma_addr( 7 downto 2)));

  epconfig_link <= C_EPCONFIG_LINK(device)(offset);

  
  HS_CFG : if HIGH_SPEED_SUPPORT = TRUE generate
    epconfig_list <= func_epconfig_table(reg_ep0_out_active,
                                         reg_ep0_in_active,
                                         reg_ep0_dir,
                                         reg_ep0_outin_bytes,
                                         reg_ep0_data_buffer,
                                         reg_ep_active,
                                         reg_ep_disable,
                                         reg_ep_stall,
                                         reg_ep_toggle_reset,
                                         reg_ep_nbytes,
                                         C_EPCONFIG_LINK);
  end generate HS_CFG;

  FS_CFG : if HIGH_SPEED_SUPPORT = FALSE generate
    epconfig_list <= func_epconfig_table_fs(reg_ep0_out_active,
                                          reg_ep0_in_active,
                                          reg_ep0_dir,
                                          reg_ep0_outin_bytes,
                                          reg_ep0_data_buffer,
                                          reg_ep_active,
                                          reg_ep_disable,
                                          reg_ep_stall,
                                          reg_ep_toggle_reset,
                                          reg_ep_nbytes,
                                          C_EPCONFIG_LINK);
  end generate FS_CFG;

  upd_dma_gnt   <= upd_dma_req;

  --interpretation of the right dword is done by usb_dma
  upd_dma_rdata <=  epconfig_list(device)(offset/2*2+1) & epconfig_list(device)(offset/2*2) when (C_DATAWIDTH = 64) 
                    else epconfig_list(device)(offset);

  PROC_EP_DISABLE : process(ep0_device_config)
  variable var_start_bit : integer range 0 to C_NBPHYSEP;
  begin
    var_start_bit := 0;
    for i in 0 to C_NBDEV-1 loop
      if DEV_ARRAY(i).NBPHYSEP > 0 then
        for j in 0 to DEV_ARRAY(i).NBPHYSEP-1 loop
          reg_ep_disable(var_start_bit+j) <= not(ep0_device_config(i));
        end loop;
      end if;
      var_start_bit := var_start_bit + DEV_ARRAY(i).NBPHYSEP;
    end loop;
  end process PROC_EP_DISABLE;

  PROC_WRITE_EPCONFIG : process(clk,rst_n)
  variable var_start_bit   : integer range 0 to C_NBPHYSEP;
  variable v_upd_dma_wdata : std_logic_vector(31 downto 0);   
  begin
    if rst_n = '0' then
      reg_ep0_out_active   <= (others => '0');
      reg_ep0_in_active    <= (others => '0');
      reg_ep0_outin_bytes  <= (others => '0');
      reg_ep0_data_buffer  <= (others => '0');
      reg_ep0_dir          <= (others => '0');
      reg_ep_active        <= (others => '0');
      reg_ep_toggle_reset  <= (others => '0');
      reg_ep_stall         <= (others => '0');
      nbytes_update_toggle <= (others => '0');
      nbytes               <= (others => (others => '0'));

    elsif rising_edge(clk) then

       -- Write operation from USB side
      if upd_dma_req = '1' and upd_dma_write = '1' then
        if C_DATAWIDTH = 32 then
          if upd_dma_addr(7 downto 4) = "0000" then
            if upd_dma_addr(3) = '0' then -- EP0 OUT
              reg_ep0_out_active(device)                        <= upd_dma_wdata(31);
            else
              reg_ep0_in_active(device)                         <= upd_dma_wdata(31);
            end if;
            for i in 0 to C_EPNBYTEWIDTH-1 loop
              reg_ep0_outin_bytes(C_EPNBYTEWIDTH*device +i)     <= upd_dma_wdata(i);
            end loop;
            --This is only required if there a descriptor larger than 64 bytes.
            --reg_ep0_data_buffer((device+1)*8-1 downto device*8) <= upd_dma_wdata(7 downto 0);
          else
            reg_ep_active(epconfig_link)                        <= upd_dma_wdata(31);
            reg_ep_toggle_reset(epconfig_link)                  <= upd_dma_wdata(28);
            if upd_dma_wdata(31) = '0' and upd_dma_addr(3) = '1' then -- EP IN
              -- Active bit is cleared for IN endpoint - set NBytes back to MaxPacketSize
              nbytes(epconfig_link)                             <= C_EP_FS_MAXPACKETSIZE_NON_ISO;
            else
              nbytes(epconfig_link)                             <= upd_dma_wdata(22 downto 16); -- This must be updated in case of ISO endpoint
            end if;
            nbytes_update_toggle(epconfig_link)                 <= not(nbytes_update_toggle(epconfig_link));
          end if;
        elsif C_DATAWIDTH = 64 then
          if upd_dma_addr(2) = '0' then
            v_upd_dma_wdata := upd_dma_wdata(31 downto 0);
          else
            v_upd_dma_wdata := upd_dma_wdata(63 downto 32);
          end if;

          if upd_dma_addr(7 downto 4) = "0000" then
            if upd_dma_addr(3) = '0' then -- EP0 OUT
              reg_ep0_out_active(device)                        <= v_upd_dma_wdata(31);
            else
              reg_ep0_in_active(device)                         <= v_upd_dma_wdata(31);
            end if;
            for i in 0 to C_EPNBYTEWIDTH-1 loop
              reg_ep0_outin_bytes(C_EPNBYTEWIDTH*device +i)     <= v_upd_dma_wdata(i);
            end loop;
            --This is only required if there a descriptor larger than 64 bytes.
            --reg_ep0_data_buffer((device+1)*8-1 downto device*8) <= upd_dma_wdata(7 downto 0);
          else
            reg_ep_active(epconfig_link)                        <= v_upd_dma_wdata(31);
            reg_ep_toggle_reset(epconfig_link)                  <= v_upd_dma_wdata(28);
            if upd_dma_wdata(31) = '0' and upd_dma_addr(3) = '1' then -- EP IN
              -- Active bit is cleared for IN endpoint - set NBytes back to MaxPacketSize
              nbytes(epconfig_link)                               <= C_EP_FS_MAXPACKETSIZE_NON_ISO;
            else
              nbytes(epconfig_link)                               <= v_upd_dma_wdata(22 downto 16); -- This must be updated in case of ISO endpoint
            end if;
            nbytes_update_toggle(epconfig_link)                 <= not(nbytes_update_toggle(epconfig_link));
          end if;
        else
          assert false
          report "Error : C_DATAWIDTH value not supported.";
        end if;
      end if;

      -- Update from EP0 handler
      for i in 0 to C_NBDEV-1 loop
        if ep0_setupdone(i) = '1' then
          reg_ep0_out_active(i)                       <= ep0_out_active;
          reg_ep0_in_active(i)                        <= ep0_in_active;
          reg_ep0_outin_bytes((i+1)*C_EPNBYTEWIDTH-1 downto i*C_EPNBYTEWIDTH) <= ep0_outin_nbytes;
          reg_ep0_data_buffer((i+1)* 8-1 downto i* 8) <= ep0_data_buffer;
          reg_ep0_dir(i)                              <= ep0_setup_dir;
        end if;
      end loop;

      -- Update from other EP handlers
      for i in 0 to C_NBPHYSEP-1 loop
        if ep_set_enable_toggle_sync(i) = '1' then
          reg_ep_active(i)   <= '1';
        end if;
      end loop;

      for i in 0 to C_NBPHYSEP-1 loop
        if ep_set_stall(i) = '1' then
          reg_ep_stall(i) <= '1';
        end if;
        if ep_clear_stall(i) = '1' then
          reg_ep_stall(i)        <= '0';
          reg_ep_toggle_reset(i) <= '1';
        end if;
      end loop;

      var_start_bit := 0;
      for i in 0 to C_NBDEV-1 loop
        if DEV_ARRAY(i).NBPHYSEP > 0 and ep0_device_config(i) = '0' then
          for j in 0 to DEV_ARRAY(i).NBPHYSEP-1 loop
            if HIGH_SPEED_SUPPORT = TRUE then 
              reg_ep_toggle_reset(var_start_bit+j) <= '0';
            else
              reg_ep_toggle_reset(var_start_bit+j) <= '1';
            end if;
          end loop;
        end if;
        var_start_bit := var_start_bit + DEV_ARRAY(i).NBPHYSEP;
      end loop;

      -- Other updates to be added
      -- + Control of stall bit based on ep_stall from ep_handler
      --
    end if;
  end process PROC_WRITE_EPCONFIG;

  GEN_EP_CONTROL : for i in 0 to C_NBPHYSEP-1 generate

    PROC_BUF_RST : process(ep_clk(i),ep_rst_n(i))
    begin
      if ep_rst_n(i) = '0' then
        buf_nbytes_int(i)  <= (others => '0');
        if func_epconfig_link_reverse(i).EPDIR = EP_OUT then
          reg_ep_nbytes(i)      <= (others => '0');
        else
          reg_ep_nbytes(i)      <= C_EP_FS_MAXPACKETSIZE_NON_ISO; --64
        end if;
        ep_set_enable_toggle(i)  <= '0';

      elsif rising_edge(ep_clk(i)) then
        -- By adding this function, the FF for nbytes for the IN endpoints are optimized
        if func_epconfig_link_reverse(i).EPDIR = EP_IN then
          buf_nbytes_int(i) <= (others => '0');
        end if;

        if ep_clear_buffer(i) = '1' then
          -- TODO : Add code to clear active bit if it was still set !!

          if func_epconfig_link_reverse(i).EPDIR = EP_OUT then
            reg_ep_nbytes(i)  <= (others => '0');
            buf_nbytes_int(i) <= (others => '0');
          else
            reg_ep_nbytes(i)  <= C_EP_FS_MAXPACKETSIZE_NON_ISO;
          end if;
        end if;

        if ep_enable_buffer(i) = '1' then
          reg_ep_nbytes(i)        <= ep_buffer_size((i+1)*7-1 downto i*7);
          if func_epconfig_link_reverse(i).EPDIR = EP_OUT then
            buf_nbytes_int(i)     <= ep_buffer_size((i+1)*7-1 downto i*7);
          end if;
          ep_set_enable_toggle(i) <= not(ep_set_enable_toggle(i));
        end if;

        if nbytes_update_toggle_sync(i) = '1' then
          reg_ep_nbytes(i) <= nbytes(i);
        end if;
      end if;
    end process PROC_BUF_RST;

    buf_reset_addr_ptr(i) <= ep_clear_buffer(i) or ((reg_ep_active_ss(i) and not(reg_ep_active_s(i)))) 
                             when func_epconfig_link_reverse(i).EPDIR = EP_IN
                             else ep_clear_buffer(i) or ep_enable_buffer(i);

    PROC_BUF_EXT : process(buf_nbytes_int,reg_ep_nbytes)
    begin
      buf_nbytes((i+1)*11-1 downto i*11) <= (others => '0');
      if func_epconfig_link_reverse(i).EPDIR = EP_OUT then
        buf_nbytes(i*11+6 downto i*11) <= std_logic_vector(unsigned(buf_nbytes_int(i)) -
                                                           unsigned(reg_ep_nbytes(i)));
      else
        buf_nbytes(i*11+6 downto i*11) <= reg_ep_nbytes(i);
      end if;
    end process PROC_BUF_EXT;

    PROC_SYNC_TO_EP_CLK : process(ep_clk(i),ep_rst_n(i))
    begin
      if ep_rst_n(i) = '0' then
        nbytes_update_toggle_s(i)   <= '0';
        nbytes_update_toggle_ss(i)  <= '0';
        nbytes_update_toggle_sss(i) <= '0';
        reg_ep_active_s(i)          <= '0';
        reg_ep_active_ss(i)         <= '0';

      elsif rising_edge(ep_clk(i)) then
        nbytes_update_toggle_s(i)   <= nbytes_update_toggle(i);
        nbytes_update_toggle_ss(i)  <= nbytes_update_toggle_s(i);
        nbytes_update_toggle_sss(i) <= nbytes_update_toggle_ss(i);
        reg_ep_active_s(i)          <= reg_ep_active(i);
        reg_ep_active_ss(i)         <= reg_ep_active_s(i);
      end if;
    end process PROC_SYNC_TO_EP_CLK;

    nbytes_update_toggle_sync(i) <= nbytes_update_toggle_ss(i) xor nbytes_update_toggle_sss(i);

  end generate GEN_EP_CONTROL;


  PROC_SYNC_TO_USB_CLK : process(clk,rst_n)
  begin
    if rst_n = '0' then
      ep_set_enable_toggle_s   <= (others => '0');
      ep_set_enable_toggle_ss  <= (others => '0');
      ep_set_enable_toggle_sss <= (others => '0');

    elsif rising_edge(clk) then
      ep_set_enable_toggle_s   <= ep_set_enable_toggle;
      ep_set_enable_toggle_ss  <= ep_set_enable_toggle_s;
      ep_set_enable_toggle_sss <= ep_set_enable_toggle_ss;

    end if;
  end process PROC_SYNC_TO_USB_CLK;

  ep_set_enable_toggle_sync  <= ep_set_enable_toggle_ss xor ep_set_enable_toggle_sss;

  ep_bufinuse <= (others => '0'); -- to be updated when double buffering is added

  epconfig_stall <= reg_ep_stall;

end RTL; --usb_ep_config_handler

--TODO :
--  control of bufinuse for double buffering
--  LAB assign reg_ep_stall
