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

entity usb_ep0_handler is
generic(C_NBPHYSEP  : integer := 2;
        C_NBDEV     : integer := 1;
        C_DATAWIDTH : integer := 32;
        C_EPNBYTEWIDTH : integer := 10); --should be 15 for highspeed
port (
      clk               : in  std_logic; 
      rst_n             : in  std_logic; 
            
      upd_dma_addr      : in  std_logic_vector(14 downto 0); 
      upd_dma_req       : in  std_logic;                     
      upd_dma_gnt       : out std_logic;                     
      upd_dma_write     : in  std_logic;                     
      upd_dma_wdata     : in  std_logic_vector(C_DATAWIDTH-1 downto 0); 
      upd_dma_rdata     : out std_logic_vector(C_DATAWIDTH-1 downto 0);
      
      usbreg_setup_to_decode : in std_logic_vector(C_NBDEV-1 downto 0);

      -- config_handler interface
      ep0_setupdone     : out std_logic_vector(C_NBDEV-1 downto 0);
      ep0_new_address   : out std_logic;
      ep0_address       : out std_logic_vector(6 downto 0); --New address communicated by SET_ADDRESS command.
      ep0_device_config : out std_logic_vector(C_NBDEV-1 downto 0);
      ep0_remote_wake_enabled : out std_logic_vector(C_NBDEV-1 downto 0);
      ep_set_stall      : out std_logic_vector(C_NBPHYSEP-1 downto 0);
      ep_clear_stall    : out std_logic_vector(C_NBPHYSEP-1 downto 0);
      
      ep0_out_active    : out std_logic;
      ep0_in_active     : out std_logic;
      ep0_outin_nbytes  : out std_logic_vector( C_EPNBYTEWIDTH-1 downto 0);
      ep0_setup_dir     : out std_logic;
      ep0_data_buffer   : out std_logic_vector( 7 downto 0);
     
      -- usb_app_hw_hub interface
      ep0_request       : out std_logic_vector( 6 downto 0);
      ep0_wvalue        : out std_logic_vector(15 downto 0);
      ep0_windex        : out std_logic_vector(15 downto 0);
      ep0_class_rdata   : in  std_logic_vector(C_DATAWIDTH-1 downto 0);
      ep0_class_addr    : out std_logic_vector( 3 downto 0);
      
      -- rom interface
      ep0_mem_req       : out std_logic;
      ep0_mem_gnt       : in  std_logic;
      ep0_mem_addr      : out std_logic_vector(11 downto 0); --DWORD address - max is 4k 32bit words
      ep0_mem_rdata     : in  std_logic_vector(C_DATAWIDTH-1 downto 0);
      
      sync_busreset     : in  std_logic;
      usbreg_dev_connect: in  std_logic;
      
      usb_phy_test_mode : out  std_logic_vector(2 downto 0);
      usb_self_powered  : in  std_logic;
      epconfig_stall    : in  std_logic_vector(C_NBPHYSEP-1 downto 0)
       
     );
end usb_ep0_handler; 
      
architecture RTL of usb_ep0_handler is   

type t_setup_decode_state is (IDLE,
                              READ_DEV_LINK,
                              READ_SETUP_LSB,
                              READ_SETUP_MASK_LSB,
                              READ_SETUP_MSB,
                              READ_SETUP_MASK_MSB,
                              SETUP_DONE);
signal setup_decode_state : t_setup_decode_state;
signal device             : integer range 0 to C_NBDEV-1;
signal setup_check        : std_logic_vector(15 downto 0);
type t_setup_bytes is array(0 to C_NBDEV-1) of std_logic_vector(63 downto 0);
signal setup_bytes        : t_setup_bytes;
signal match_lsb          : std_logic;
signal setup_mem_req      : std_logic;
signal setup_mem_addr     : unsigned(11 downto 0);
signal setup_request      : std_logic_vector( 6 downto 0);
signal setup_last         : std_logic;
signal setup_data_buffer  : std_logic_vector( 7 downto 0);
signal setup_data         : std_logic_vector(31 downto 0);
signal ep0_setupdone_int  : std_logic_vector(C_NBDEV-1 downto 0);
signal setup_mem_gnt      : std_logic;
signal ep0_new_config     : std_logic;
type t_ep0_mem_access_state is (USB_DATA, SETUP_DECODE);
signal ep0_mem_access_state : t_ep0_mem_access_state;
signal std_req_data       : std_logic_vector(31 downto 0);
signal ep0_device_config_int : std_logic_vector(C_NBDEV-1 downto 0);
signal clear_remote_wake_enabled : std_logic;
signal set_remote_wake_enabled   : std_logic;
signal set_usb_phy_test_mode     : std_logic;

signal ep0_mem_rdata_int  : std_logic_vector(31 downto 0);
signal ep0_mem_addr_int   : std_logic_vector(11 downto 0); --DWORD address - max is 4k 32bit words
signal ep0_remote_wake_enabled_int : std_logic_vector(C_NBDEV-1 downto 0);

signal ep0_out_active_int : std_logic;
signal ep0_in_active_int  : std_logic;
signal ep0_out_stall      : std_logic;
signal ep0_in_stall       : std_logic;


begin

  PROC_SETUP_DECODE : process(clk,rst_n)
  variable var_setup_masked : std_logic_vector(15 downto 0);
  variable var_device : integer range 0 to 127;
  begin
    if rst_n = '0' then
      setup_decode_state <= IDLE;
      device             <= 0;
      setup_mem_req      <= '0';
      setup_mem_addr     <= (others => '0');
      setup_check        <= (others => '0');
      setup_request      <= (others => '0');
      setup_last         <= '0';
      setup_data_buffer  <= (others => '0');
      match_lsb          <= '0';
      ep0_in_active_int  <= '0';
      ep0_out_active_int <= '0';
      ep0_setupdone_int  <= (others => '0');
      setup_bytes        <= (others => (others => '0'));

      var_setup_masked   := (others => '0');
      var_device         := 0;

    elsif rising_edge(clk) then

      ep0_setupdone_int  <= (others => '0');
      
      if setup_mem_gnt = '1' then
        setup_mem_req <= '0';
      end if;
      
      case setup_decode_state is
        when IDLE                =>
          ep0_in_active_int  <= '0';
          ep0_out_active_int <= '0';
          if usbreg_setup_to_decode(device) = '1' then
            setup_decode_state <= READ_DEV_LINK;
            setup_mem_req      <= '1';
            setup_mem_addr     <= unsigned(C_DEV_LINK_START) + to_unsigned(device,12);
          else
            if device = C_NBDEV-1 then
              device <= 0;
            else
              device <= device + 1;
            end if;
          end if;
          
        when READ_DEV_LINK       =>
          if ep0_mem_gnt = '1' then
            setup_decode_state <= READ_SETUP_LSB;
            setup_mem_req      <= '1';
            setup_mem_addr     <= unsigned(ep0_mem_rdata_int(11 downto 0));
          end if;
          
        when READ_SETUP_LSB      =>
          if ep0_mem_gnt = '1' then
            setup_check <= ep0_mem_rdata_int(31 downto 16);
            if ep0_mem_rdata_int(15 downto 0) = setup_bytes(device)(15 downto 0) then
              match_lsb <= '1';
            else
              match_lsb <= '0';
            end if;
            setup_decode_state <= READ_SETUP_MASK_LSB;
            setup_mem_req      <= '1';
            setup_mem_addr     <= setup_mem_addr + X"001";
          end if;
          
        when READ_SETUP_MASK_LSB =>
          if ep0_mem_gnt = '1' then
            var_setup_masked := ep0_mem_rdata_int(31 downto 16) and setup_bytes(device)(31 downto 16);
            setup_request     <= ep0_mem_rdata_int(6 downto 0);
            setup_last        <= ep0_mem_rdata_int(7);
            if ep0_mem_rdata_int(15 downto 14) = "00" then
              setup_data_buffer <= std_logic_vector(to_unsigned(device,8));
            else
              setup_data_buffer <= ep0_mem_rdata_int(15 downto 8);
            end if;
            if (match_lsb = '1') and 
               (var_setup_masked = setup_check) then
              setup_decode_state    <= READ_SETUP_MSB;
              setup_mem_req         <= '1';
              setup_mem_addr        <= setup_mem_addr + X"001";
            elsif ep0_mem_rdata_int(7) = '1' then -- LAST bit is set
              setup_decode_state        <= SETUP_DONE;
              ep0_setupdone_int(device) <= '1';
              setup_request             <= (others => '0'); -- Clear setup_request such that nothing else is triggered
            else
              setup_decode_state    <= READ_SETUP_LSB;
              setup_mem_req         <= '1';
              setup_mem_addr        <= setup_mem_addr + X"003";
            end if;
          end if;
          
        when READ_SETUP_MSB      =>
          if ep0_mem_gnt = '1' then
            setup_check <= ep0_mem_rdata_int(15 downto 0);
            if ep0_mem_rdata_int(31 downto 16) < setup_bytes(device)(63 downto 48) then
              setup_bytes(device)(63 downto 48) <= ep0_mem_rdata_int(31 downto 16);
            end if;
            setup_decode_state <= READ_SETUP_MASK_MSB;
            setup_mem_req      <= '1';
            setup_mem_addr     <= setup_mem_addr + X"001";
          end if;
          
        when READ_SETUP_MASK_MSB =>
          if ep0_mem_gnt = '1' then
            var_setup_masked := ep0_mem_rdata_int(15 downto 0) and setup_bytes(device)(47 downto 32);
            if (match_lsb = '1') and 
               (var_setup_masked = setup_check) then
              setup_decode_state        <= SETUP_DONE;
              ep0_setupdone_int(device) <= '1';
              ep0_in_active_int         <= '1';
              -- Enable OUT buffer when transfer is from device to host or when NBytes is greater than zero.
              if (setup_bytes(device)(7) = '1') or (setup_bytes(device)(63 downto 48) /= X"0000") then
                ep0_out_active_int      <= '1';
              end if;
            elsif setup_last = '1' then -- LAST bit is set
              setup_decode_state        <= SETUP_DONE;
              ep0_setupdone_int(device) <= '1';
              setup_request             <= (others => '0'); -- Clear setup_request such that nothing else is triggered
            else
              setup_decode_state    <= READ_SETUP_LSB;
              setup_mem_req         <= '1';
              setup_mem_addr        <= setup_mem_addr + X"001";
            end if;
          end if;
        
        when others              => --SETUP_DONE
          setup_decode_state <= IDLE;
          ep0_in_active_int  <= '0';
          ep0_out_active_int <= '0';
      end case;

      --device index is extracted from the dma address (=> the buffer address offset of the ep config list)
      var_device := to_integer(unsigned(upd_dma_addr(12 downto 6)));
      if upd_dma_req = '1' and upd_dma_write = '1' and upd_dma_addr(14) = '1' then
        if var_device < C_NBDEV then
          if C_DATAWIDTH = 32 then   
            if upd_dma_addr(2) = '0' then
              setup_bytes(var_device)(31 downto  0) <= upd_dma_wdata;
            else
              setup_bytes(var_device)(63 downto 32) <= upd_dma_wdata;
            end if;
          else
            setup_bytes(var_device)(63 downto 0) <= upd_dma_wdata;
            if C_DATAWIDTH /= 64 then
              assert false
              report "Error : C_DATAWIDTH value not supported.";
            end if;
          end if;
        end if;
      end if;
      
      for i in 0 to C_NBDEV-1 loop
        if ep0_setupdone_int(device) = '1' then
          setup_bytes(device)(31 downto 0) <= setup_data;
        end if;
      end loop;
      
    end if;
  end process PROC_SETUP_DECODE;

  ep0_setupdone    <= ep0_setupdone_int;
  ep0_out_active   <= ep0_out_active_int and not(ep0_out_stall);
  ep0_in_active    <= ep0_in_active_int and not(ep0_in_stall);

  ep0_request      <= setup_request;
  ep0_setup_dir    <= setup_bytes(device)(7) when device < C_NBDEV else '0';
  ep0_data_buffer  <= setup_data_buffer;
  ep0_wvalue       <= setup_bytes(device)(31 downto 16) when device < C_NBDEV else (others => '0');
  ep0_windex       <= setup_bytes(device)(47 downto 32) when device < C_NBDEV else (others => '0');

  ep0_outin_nbytes <= setup_bytes(device)(48+C_EPNBYTEWIDTH-1 downto 48) when device < C_NBDEV else (others => '0');
  
  ep0_address      <= setup_bytes(device)(22 downto 16); --wValue contains new address

  PROC_STD_REQ_DECODE : process(ep0_setupdone_int, 
                                device, 
                                setup_request,
                                setup_bytes,
                                ep0_device_config_int,
                                epconfig_stall,
                                usb_self_powered,
                                ep0_remote_wake_enabled_int )
  variable var_offset : integer range 0 to 63;
  begin
    ep0_new_address <= '0';
    ep0_new_config  <= '0';
    ep_set_stall    <= (others => '0');
    ep_clear_stall  <= (others => '0');
    set_remote_wake_enabled   <= '0';
    clear_remote_wake_enabled <= '0';
    set_usb_phy_test_mode     <= '0';
    setup_data      <= setup_bytes(device)(31 downto 0);
    ep0_out_stall <= '0';
    ep0_in_stall  <= '0';

    if setup_bytes(device)(39) = EP_IN then
      var_offset := to_integer(unsigned(setup_bytes(device)(35 downto 32)) * 4) + 2;
    else
      var_offset := to_integer(unsigned(setup_bytes(device)(35 downto 32)) * 4);
    end if;
    if ep0_setupdone_int(device) = '1' then
      case setup_request is

        when C_STD_REQ_SET_ADDRESS =>
          ep0_new_address <= '1';

        when C_STD_REQ_SET_CONFIGURATION => 
          ep0_new_config  <= '1';
          ep_clear_stall(C_EPCONFIG_LINK(device)(var_offset)) <= '1';
          
        when C_STD_REQ_SET_FEATURE_DEV =>
          if setup_bytes(device)(16) = '1' then
            set_remote_wake_enabled <= '1';
          end if;
          -- test mode is only valid for Hub command (reason : compound device with non removal nor accessible ports)
          if setup_bytes(device)(17 downto 16) = "11" then
            -- not allowed should stall
            ep0_in_stall  <= '1';
          elsif setup_bytes(device)(17 downto 16) = "10" and device = 0 then
            -- stall if test selector is not valid..
            if unsigned(setup_bytes(device)(47 downto 40)) > 5 then 
              ep0_in_stall  <= '1';
            else
              set_usb_phy_test_mode <= '1';
            end if; 
          end if;

        when C_STD_REQ_SET_FEATURE_EP =>
          -- TODO : how to generate a stall on an endpoint that is disabled and which cannot be masked by SETUP_MASK bits ???
          ep_set_stall(C_EPCONFIG_LINK(device)(var_offset)) <= '1';
        
--        when C_STD_REQ_SET_INTERFACE =>
--        --<<TBD>> Undefined:  hubs are allowed to support only one interface, for hid it is not clear
          --ep_clear_stall(C_EPCONFIG_LINK(device)(var_offset)) <= '1';

        when C_STD_REQ_GET_CONFIGURATION =>
          setup_data(7 downto 1) <= (others => '0'); --Only one configuration supported (Config zero or one)
          setup_data(0)          <= ep0_device_config_int(device);
        
        when C_STD_REQ_GET_INTERFACE =>
          setup_data(7 downto 0) <= (others => '0'); --Only one interface supported (Interface zero)          
        
        when C_STD_REQ_GET_STATUS_DEV => 
          setup_data(15 downto 2) <= (others => '0');
          setup_data(1)           <= ep0_remote_wake_enabled_int(device);
          setup_data(0)           <= usb_self_powered;
        
        when C_STD_REQ_GET_STATUS_IF => 
          setup_data(15 downto 0) <= (others => '0');
        
        when C_STD_REQ_GET_STATUS_EP => 
          -- TODO : how to generate a stall on an endpoint that is disabled and which cannot be masked by SETUP_MASK bits ???
          setup_data(15 downto 1) <= (others => '0');
          setup_data(0)           <= epconfig_stall(C_EPCONFIG_LINK(device)(var_offset));
        
        when C_STD_REQ_CLEAR_FEATURE_DEV =>
          if setup_bytes(device)(16) = '1' then
            clear_remote_wake_enabled <= '1';
          end if;
        
        when C_STD_REQ_CLEAR_FEATURE_EP =>
          -- TODO : how to generate a stall on an endpoint that is disabled and which cannot be masked by SETUP_MASK bits ???
          ep_clear_stall(C_EPCONFIG_LINK(device)(var_offset)) <= '1';
        
        when others =>
          null;
      end case;
    end if;           
  end process PROC_STD_REQ_DECODE;

  PROC_STD_REQ_CONFIG : process(clk,rst_n)
  begin
    if rst_n ='0' then
      ep0_device_config_int   <= (others => '0');
      ep0_remote_wake_enabled_int <= (others => '0');
      usb_phy_test_mode <= (others => '0');
    elsif rising_edge(clk) then
      if ep0_new_config = '1' then
        --Only single configuration is supported - must be configuration '1'. wValue contains configuration value
        ep0_device_config_int(device) <= setup_bytes(device)(16); 
      end if;
      if set_remote_wake_enabled = '1' then
        ep0_remote_wake_enabled_int(device) <= '1';
      end if;
      if clear_remote_wake_enabled = '1' then
        ep0_remote_wake_enabled_int(device) <= '0';
      end if;
      if set_usb_phy_test_mode = '1' then
        usb_phy_test_mode <= setup_bytes(device)(42 downto 40);
      end if;
      if sync_busreset = '1' or usbreg_dev_connect = '0' then
        ep0_device_config_int   <= (others => '0');
        ep0_remote_wake_enabled_int <= (others => '0');
      end if;
    end if;
  end process PROC_STD_REQ_CONFIG;
  
  ep0_device_config <= ep0_device_config_int;
  ep0_remote_wake_enabled <= ep0_remote_wake_enabled_int;
  
  upd_dma_gnt   <= ep0_mem_gnt     when ep0_mem_access_state = USB_DATA else '0';
  
  PROC_UPD_DMA_RDATA : process(ep0_mem_rdata,upd_dma_addr, ep0_mem_addr_int, ep0_class_rdata,std_req_data)
  begin
    if (C_DATAWIDTH = 32) then
      ep0_mem_rdata_int <= ep0_mem_rdata;
      if (upd_dma_addr(13) = '1') then
        upd_dma_rdata <= ep0_mem_rdata;
      elsif (upd_dma_addr(12) = '1') then
        upd_dma_rdata <= ep0_class_rdata;
      else
        upd_dma_rdata <= std_req_data;
      end if;
    else
      if (ep0_mem_addr_int(0) = '1') then 
        ep0_mem_rdata_int <= ep0_mem_rdata(63 downto 32);
      else
        ep0_mem_rdata_int <= ep0_mem_rdata(31 downto 0);
      end if;
      if (upd_dma_addr(13) = '1') then
        upd_dma_rdata <= ep0_mem_rdata;
      elsif (upd_dma_addr(12) = '1') then
        upd_dma_rdata <= ep0_class_rdata;
      else
        -- all standard get request except GetDescriptor have wLength <= 2, so the upper bits (63:32) do not matter, just duplicate them 
        upd_dma_rdata <= std_req_data & std_req_data ;
      end if;
      if C_DATAWIDTH /= 64 then
        assert false
        report "Error : C_DATAWIDTH value not supported.";
      end if;
    end if;
  end process PROC_UPD_DMA_RDATA;


  ep0_class_addr <= upd_dma_addr(5 downto 2);

  setup_mem_gnt <= ep0_mem_gnt   when ep0_mem_access_state = SETUP_DECODE else '0';
  
  ep0_mem_req       <= upd_dma_req                     when ep0_mem_access_state = USB_DATA else setup_mem_req;
  ep0_mem_addr_int  <= '0' & upd_dma_addr(12 downto 2) when ep0_mem_access_state = USB_DATA else std_logic_vector(setup_mem_addr);
  ep0_mem_addr      <= ep0_mem_addr_int;

 PROC_EP0_MEM_ACCESS : process(clk,rst_n)
  begin
    if rst_n = '0' then
      ep0_mem_access_state <= USB_DATA;
    elsif rising_edge(clk) then
      if ep0_mem_gnt = '1' then
        if ep0_mem_access_state = USB_DATA then
          ep0_mem_access_state <= SETUP_DECODE;
        elsif upd_dma_req = '1' then
          ep0_mem_access_state <= USB_DATA;
        end if;
      else
        if setup_mem_req = '0' then
          ep0_mem_access_state <= USB_DATA;
        elsif upd_dma_req = '0' then
          ep0_mem_access_state <= SETUP_DECODE;
        end if;
      end if;
    end if;   
  end process PROC_EP0_MEM_ACCESS;
  
  PROC_STD_REQ_DATA : process(upd_dma_addr, setup_bytes)
  variable var_device : integer range 0 to C_NBDEV-1;
  begin
    if to_integer(unsigned(upd_dma_addr(12 downto 6))) < C_NBDEV then
      var_device := to_integer(unsigned(upd_dma_addr(12 downto 6)));
    else
      var_device := 0;
    end if;
    std_req_data <= setup_bytes(var_device)(31 downto 0);
  end process PROC_STD_REQ_DATA;


end RTL; --usb_ep0_handler

