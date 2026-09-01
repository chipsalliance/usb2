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

LIBRARY usb_lib;
USE usb_lib.usb_subcmp_pkg.all;

entity usb_pie is
      generic (
      ULPI_SUPPORT          : boolean := TRUE;
      UTMI_SUPPORT          : boolean := TRUE;
      USB_DATAWIDTH         : integer := 64;
      C_NBDEV               : integer := 1;
      C_NBPHYSEP            : integer := 14;
      C_EXTEND_TX_DELAY     : boolean := FALSE
   );
    port (
          ----- To/From usb synchronizer ------------------------
         pie_epinfo_req               : out std_logic;
         pie_epinfo_epnr              : out std_logic_vector(3 downto 0);
         pie_epinfo_epdir             : out std_logic;
         pie_epinfo_setup             : out std_logic;
         pie_epinfo_setup_received    : out std_logic;
         pie_usbaddress               : out std_logic_vector(6 downto 0);

         epinfo_valid                 : in  std_logic;
         epinfo_active                : in  std_logic;
         epinfo_disabled              : in  std_logic;
         epinfo_toggle                : in  std_logic;
         epinfo_stall                 : in  std_logic;
         epinfo_iso                   : in  std_logic;
         epinfo_nbytes                : in  std_logic_vector(14 downto 0);
         epinfo_maxpacket             : in std_logic_vector(1 downto 0);

         pie_txdata_fetched           : out std_logic;
         epinfo_txdata                : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
         epinfo_txdata_valid          : in  std_logic;

         pie_rx_nbytes                : out std_logic_vector(11 downto 0);
         pie_rxdata                   : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
         pie_rxdatavalid              : out std_logic;

         pie_endtransfer              : out std_logic;
         pie_success                  : out std_logic;
         pie_error                    : out std_logic;
         pie_errortype                : out std_logic_vector(3 downto 0);
         pie_sentNAK                  : out std_logic;
         pie_isotoggle                : out std_logic;
         pie_busreset                 : out std_logic;
         pie_devicespeed              : out std_logic;
         pie_suspend                  : out std_logic;
         pie_lpm_suspend              : out std_logic;
         pie_lpm_remotewake_enable    : out std_logic;
         pie_lpm_hird_hw              : out std_logic_vector(3 downto 0);

         pie_vbusvalid                : out std_logic;
         pie_lowpower_n               : out std_logic;

         -- phy test mode
         phy_address                  : in std_logic_vector(7 downto 0);
         phy_readdata                 : out std_logic_vector(7 downto 0);
         phy_writedata                : in std_logic_vector(7 downto 0);
         phy_write                    : in std_logic;
         phy_start                    : in std_logic;
         phy_endtoggle                : out std_logic;
         phy_mode                     : in std_logic;

         sync_usbreg_phy_test_mode_change  : in std_logic;  -- phy_test_mode change, resynchronized with usb_pie clock
         sync_usbreg_remotewakeup     : in std_logic;  -- usbreg_remotewakeup from reg_if resynchronized with usb_pie clock
         sync_usbreg_lpmremotewakeup     : in std_logic;  -- usbreg_lpmremotewakeup from reg_if resynchronized with usb_pie clock

         reset_n                      : in std_logic; -- AHB reset after resynchronization, active LOW
         pie_clk                      : in std_logic; -- UTMI/ULPI clock


          -----  To/From usb_reg_if ------------------------
          ------ To/From ahb register module - pseudo-static signals
         usbreg_pll_on                : in  std_logic;
         usbreg_deviceenabled         : in  std_logic_vector(C_NBDEV-1 downto 0);
         usbreg_dev_connect           : in  std_logic;
         usbreg_remotewakeup          : in  std_logic;
         usbreg_lpm_sup               : in  std_logic;
         usbreg_lpmremotewakeup       : in  std_logic;
         usbreg_lpm_hird_sw           : in std_logic_vector(3 downto 0);
         usbreg_lpm_nyet              : in std_logic;
         usbreg_frame_number          : out std_logic_vector(10 downto 0);
         usbreg_usbaddress            : in  std_logic_vector(C_NBDEV*7-1 downto 0);
         usbreg_usbaddress_tmp        : in  std_logic_vector(C_NBDEV*7-1 downto 0);
         usbreg_phy_test_mode         : in  std_logic_vector(2 downto 0);
         usbreg_port_force_fullspeed  : in  std_logic;
	 
	 token_length_counter         : in  std_logic_vector(6 downto 0);
	 usb_token_length             : out std_logic_vector(6 downto 0);


         -- UTMI INTERFACE
         -- These signals are only to be used when the generic
         -- UTMI_SUPPORT is set to TRUE
         --utmi_clk                     : in  std_logic;
         utmi_rxdata                  : in  std_logic_vector(7 downto 0);
         utmi_rxvalid                 : in  std_logic;
         utmi_rxactive                : in  std_logic;
         utmi_rxerror                 : in  std_logic;
         utmi_txdata                  : out std_logic_vector(7 downto 0);
         utmi_txvalid                 : out std_logic;
         utmi_txready                 : in  std_logic;
         utmi_reset                   : out std_logic;
         utmi_xcvrselect              : out std_logic;
         utmi_termselect              : out std_logic;
         utmi_opmode                  : out std_logic_vector(1 downto 0);
         utmi_linestate               : in  std_logic_vector(1 downto 0);
         utmi_vcontrol                : out std_logic_vector(3 downto 0);
         utmi_vcontrolloadm           : out std_logic;
         utmi_vstatus                 : in std_logic_vector(7 downto 0);
         utmi_vbusvalid               : in std_logic;

         -- ULPI INTERFACE
         -- These signals are only to be used when the generic
         -- ULPI_SUPPORT is set to TRUE
         --ulpi_clk                     : in  std_logic;
         ulpi_rxdata                  : in std_logic_vector(7 downto 0);
         ulpi_txdata                  : out std_logic_vector(7 downto 0);
         ulpi_txenable                : out std_logic;
         ulpi_dir                     : in  std_logic;
         ulpi_stp                     : out std_logic;
         ulpi_nxt                     : in  std_logic;
         ulpi_pwrctrl_wakeup          : in std_logic;

         VBusDebounced                : in std_logic;
         pie_dev_selected             : out integer range 0 to C_NBDEV - 1;

         --fpga debug
         usb_pie_fpga                 : out std_logic_vector(63 downto 0)
          );
end usb_pie;


architecture RTL of usb_pie is


constant PID_OUT   : std_logic_vector(3 downto 0) := "0001";  -- Address + EPnr in host-to-function transaction
constant PID_IN    : std_logic_vector(3 downto 0) := "1001";  -- Address + EPnr in function-to-host transaction
constant PID_SOF   : std_logic_vector(3 downto 0) := "0101";  -- Start-of-Frame marker and frame number
constant PID_SETUP : std_logic_vector(3 downto 0) := "1101";  -- Address + EPnr host-to-func trans for setup to a control pipe
constant PID_DATA0 : std_logic_vector(3 downto 0) := "0011";  -- Data packet PID even
constant PID_DATA1 : std_logic_vector(3 downto 0) := "1011";  -- Data packet PID odd
constant PID_DATA2 : std_logic_vector(3 downto 0) := "0111";  -- Data packet high-speed, high-BW, isochronous in a uFrame
constant PID_MDATA : std_logic_vector(3 downto 0) := "1111";  -- Data packet for split and HS, high-BW, isochronous trans
constant PID_ACK   : std_logic_vector(3 downto 0) := "0010";  -- Receiver accepts err-free packet
constant PID_NAK   : std_logic_vector(3 downto 0) := "1010";  -- Cannot accept or transmit data
constant PID_STALL : std_logic_vector(3 downto 0) := "1110";  -- EP halted or control pipe request not supported
constant PID_NYET  : std_logic_vector(3 downto 0) := "0110";  -- No response from receiver
constant PID_PRE   : std_logic_vector(3 downto 0) := "1100";  -- Host issued preamble to enable LS
constant PID_ERR   : std_logic_vector(3 downto 0) := "1100";  -- Split transaction errror handshake
constant PID_SPLIT : std_logic_vector(3 downto 0) := "1000";  -- HS split transaction token
constant PID_PING  : std_logic_vector(3 downto 0) := "0100";  -- HS flow control probe for bulk/control EP
constant PID_EXT   : std_logic_vector(3 downto 0) := "0000";  -- Protocol extension token

constant SUB_PID_LPM : std_logic_vector(3 downto 0) := "0011";  -- LPM token
-- LPM linkState:
constant LINKSTATE_L1 :std_logic_vector(3 downto 0) := "0001";  -- L1 (sleep)

constant MAX_SE0_FILT_CNT : integer := 2;
constant MAX_SE1_FILT_CNT : integer := 2;

constant MAX_LINESTATE_DBC_CNT : natural := 192; --   debounce time of > 2.5us (3.2 us @ 60MHz)
 -- line state constants
constant LINESTATE_SE0       : std_logic_vector(1 DOWNTO 0) := "00";
constant LINESTATE_J         : std_logic_vector(1 DOWNTO 0) := "01";
constant LINESTATE_K         : std_logic_vector(1 DOWNTO 0) := "10";
constant LINESTATE_SE1       : std_logic_vector(1 DOWNTO 0) := "11";
constant LINESTATE_INCST     : std_logic_vector(1 DOWNTO 0) := "11";


-- timers constants in clk cycles (clk =60 MHz)

-- T_3ms can be used for several timings: -  3ms < TWTREV (3.072 ms @ 60 MHz) < 3.125 ms &  T3 (5.22.1.1 UTMI spec)
-- - 1 ms < TDRSMUP (1.1 us @ 60 MHz) < 15 ms (5.22.3 UTMI spec) & TUCH (min 1 ms), max 7 ms
constant T_3ms             : natural := 184320;  --  3ms < TWTREV (3.072 ms @ 60 MHz) < 3.125 ms &  T3 (5.22.1.1 UTMI spec)

constant T_60us            : natural := 3600;  -- 60 us @ 60 MHz
constant T_125us           : natural := 7500;  -- 125 us @ 60 MHz
constant T_1ms             : natural := 60000;  -- 1ms @ 60 MHz
constant T_TWTRSTHS        : natural := 18000; -- 100 us < TWTRSTHS (300 us @ 60 MHz)< 875 us
--constant T_TDRSMUP         : natural := 66000; -- 1 ms < TDRSMUP (1.1 ms @ 60 MHz) < 15 ms (5.22.3 UTMI spec) & TUCH
------------------------------------------
--BVE : SMS PHY requires a longer time to stop transmitting resume - increase it to 30 us
--constant T_TxENDDELAY        : natural := 384;  -- UTMI Spec 4.1.5
constant T_TxENDDELAY        : natural := 1800;  -- UTMI Spec 4.1.5
------------------------------------------
constant T_TWTFS              : natural :=  144000; -- 1.0 ms < TWTFS (2.4 ms @60 MHz) < 2.5 ms (5.22.2.1 UTMI spec)
constant T_L1_Token_Retry     : natural := 540; -- 9 us @ 60MHz -- 8us < T_L1_Token_Retry < 10 us

constant MAX_BUS_EVENT_TIMER  : natural := T_3ms + 1; --  = Maximum timer value + 1 => error condition
constant MAX_CHIRP_COUNT      : natural := 6;

constant INTER_PACKET_DELAY_FS : natural := 10;
constant INTER_PACKET_DELAY_HS : natural := 2;
constant PACKET_TURNAROUND_TIMEOUT_FS : natural := 88; -- correspond to 16 to 18 bit (*5 @60MHz) - phy margin 
constant PACKET_TURNAROUND_TIMEOUT_HS : natural := 96;

constant PACKET_EVENT_TIMEOUT_FS : natural := 127;
constant PACKET_EVENT_TIMEOUT_HS : natural := 127;

constant MAX_PACKET_HANDLING_TIMER : natural := PACKET_EVENT_TIMEOUT_FS;
constant CRC5_RESIDUAL : std_logic_vector(4 downto 0) := "01100";
constant CRC16_RESIDUAL : std_logic_vector(15 downto 0) := "1000000000001101";

constant ZERO4: std_logic_vector(3 downto 0) := (others => '0');

constant USB_DATAWIDTH_IN_BYTES : natural := USB_DATAWIDTH/8; -- assumption: can only be divided by 8
constant MAX_DATA_BYTE_CNT_LSB : natural := USB_DATAWIDTH_IN_BYTES -1;
constant MAX_DATA_BYTE_CNT : natural := 3072; -- 3 * MAX_DATA_PACKET_SIZE

constant MAX_DATA_PACKET_SIZE: natural := 1024; --
constant TESTPACKET_SIZE : natural := 56 ; -- 1 PID + 53 bytes + 2 byte CRC ; 56 bytes

signal timer_bus_event : natural range 0 to MAX_BUS_EVENT_TIMER;
signal clear_timer_bus_event: std_logic;
signal timer_bus_event_run: std_logic;
signal timer_bus_event_timeout_r : std_logic;
signal chirp_count :  natural range 0 to MAX_CHIRP_COUNT-1;
signal chirp_count_pls: std_logic;
signal chirp_count_clear : std_logic;
signal timer_sof         : natural range 0 to T_1ms-1;

signal timer_packet_handling_r : natural range 0 to MAX_PACKET_HANDLING_TIMER;
signal timer_packet_handling_nxt : natural range 0 to MAX_PACKET_HANDLING_TIMER;
signal reload_timer_packet_handling_nxt : std_logic;

signal data_byte_cnt_incr    : std_logic;
signal data_byte_cnt_clear   : std_logic;
signal data_byte_cnt         : unsigned(11 downto 0); -- MAX_DATA_BYTE_CNT

signal rxdata                : std_logic_vector(7 downto 0);
signal rxvalid               : std_logic;
signal rxactive              : std_logic;
signal rxactive_r            : std_logic;
signal rxerror               : std_logic;
signal txready               : std_logic;
signal txready_r             : std_logic;
signal linestate             : std_logic_vector(1 DOWNTO 0);

signal utmi_rxvalid_r        : std_logic;
signal utmi_rxactive_r       : std_logic;
signal utmi_rxerror_r        : std_logic;
signal utmi_linestate_r      : std_logic_vector(1 downto 0);
signal utmi_rxdata_r         : std_logic_vector(7 downto 0);

signal suspendm_nxt : std_logic;
signal opmode_nxt: std_logic_vector(1 downto 0);
signal xcvrselect_nxt : std_logic;
signal termselect_nxt: std_logic;
signal txvalid_nxt : std_logic;
signal txdata_nxt : std_logic_vector(7 downto 0);

signal txvalid_pkt_nxt : std_logic;

signal se0_filt_cnt : natural range 0 to MAX_SE0_FILT_CNT; --2 CLK cycles for FS/HS Bus speed for 8-bit interface
signal se1_filt_cnt : natural range 0 to MAX_SE1_FILT_CNT; --2 CLK cycles for FS/HS Bus speed for 8-bit interface
signal linestate_r         : std_logic_vector(1 DOWNTO 0);
signal ls_filt             : std_logic_vector(1 DOWNTO 0);

signal init_linestate_dbc  : std_logic;
signal linestate_dbc_cnt   : natural range 0 to MAX_LINESTATE_DBC_CNT;
signal ls_dbc              : std_logic_vector(1 DOWNTO 0);

signal rxdata_16 : std_logic_vector(15 DOWNTO 0);
signal rxdata_r : std_logic_vector(7 DOWNTO 0);
signal rxdata_valid : std_logic;
signal rxdata_valid_r : std_logic;
signal rx_ok : std_logic;
signal rx_ok_r : std_logic;

signal data_fifo_r : std_logic_vector (USB_DATAWIDTH -1 downto 0);
signal data_fifo_rx_r : std_logic_vector (USB_DATAWIDTH -1 downto 0);
signal data_fifo_previous_byte_r : std_logic_vector( 7 downto 0);

signal set_req_handshake : std_logic;
signal clear_req_handshake : std_logic;
signal req_handshake_r : std_logic;

signal set_pie_endtransfer: std_logic;
signal clear_pie_endtransfer: std_logic;

signal set_pie_error: std_logic;
signal clear_pie_error: std_logic;
signal pie_error_r: std_logic;

signal set_iso_in_pending : std_logic;
signal clear_iso_in_pending: std_logic;
signal iso_in_pending_r : std_logic;
signal set_iso_out_pending : std_logic;
signal clear_iso_out_pending: std_logic;
signal iso_out_pending_r : std_logic;

signal clear_wf_ext_token_packet: std_logic;
signal set_wf_ext_token_packet: std_logic;
signal wf_ext_token_packet_r: std_logic;
signal lpm_hird_hw_r : std_logic_vector(3 downto 0);
signal linkstate_r : std_logic_vector(3 downto 0);
signal bremotewake_r : std_logic;
signal set_lpm_init_valid: std_logic;
signal clear_lpm_init_valid: std_logic;
signal clear_lpm_wf_l1_state : std_logic;
signal set_lpm_wf_l1_state : std_logic;
signal set_lpm_l1_state: std_logic;
signal lpm_wf_l1_state_r: std_logic;
signal lpm_init_valid_r: std_logic;

signal phy_endtoggle_r: std_logic;


type t_bus_event_state is
(
  BUS_EVENT_INIT,
  BUS_EVENT_FS_IDLE,
  BUS_EVENT_FS_ACTIVE,
  BUS_EVENT_HS_IDLE,
  BUS_EVENT_HS_ACTIVE,
  BUS_EVENT_WF_SUSPEND_OR_RST,
  BUS_EVENT_RESET,
  BUS_EVENT_WF_SUSPEND,
  BUS_EVENT_SUSPEND,
  BUS_EVENT_SW_WAKEUP_WF_CLK,
  BUS_EVENT_SW_WAKEUP_1,
  BUS_EVENT_SW_WAKEUP_2,
  BUS_EVENT_SW_WAKEUP_3,
  BUS_EVENT_HOST_RESUME,
  BUS_EVENT_WF_EOR_FS,    -- Wait for End of Reset FS
  BUS_EVENT_HS_DET_HSK_1, -- High Speed Detection HandShake
  BUS_EVENT_HS_DET_HSK_2,
  BUS_EVENT_HS_DET_HSK_3,
  BUS_EVENT_HS_DET_HSK_4,
  BUS_EVENT_WF_ENDCHIRP_HS,
  BUS_EVENT_TEST_MODE,
  BUS_EVENT_LPM_SUSPEND_L1,
  BUS_EVENT_LPM_SW_WAKEUP_WF_CLK,
  BUS_EVENT_LPM_SW_WAKEUP_1);



signal bus_event_state_nxt, bus_event_state_r : t_bus_event_state;


type t_packet_handling_state is
(
  USB_PROT_IDLE,
  USB_PROT_WF_IDLE,
  USB_PROT_WF_TOKEN_PID,
  USB_PROT_WF_TOKEN_BYTE2,
  USB_PROT_WF_TOKEN_BYTE3,
  USB_PROT_IN_WF_EOP,
  USB_PROT_IN_WF_EP_INFO_VALID,
  USB_PROT_OUT_SETUP_WF_EOP,
  USB_PROT_OUT_SETUP_WF_EP_INFO_VALID,
  USB_PROT_PING_WF_EOP,
  USB_PROT_PING_WF_EP_INFO_VALID,
  USB_PROT_OUT_SETUP_PING_WF_TX_ACK_HANDSHAKE,
  USB_PROT_OUT_SETUP_PING_TX_ACK_HANDSHAKE,
  USB_PROT_IN_OUT_PING_WF_TX_NAK_HANDSHAKE,
  USB_PROT_IN_OUT_PING_TX_NAK_HANDSHAKE,
  USB_PROT_IN_OUT_PING_WF_TX_STALL_HANDSHAKE,
  USB_PROT_IN_OUT_PING_TX_STALL_HANDSHAKE,
  USB_PROT_OUT_WF_TX_NYET_HANDSHAKE,
  USB_PROT_OUT_TX_NYET_HANDSHAKE,
  USB_PROT_ALL_WF_END_TX_PACKET,
  USB_PROT_OUT_SETUP_WF_RX_DATA_PID,
  USB_PROT_OUT_SETUP_RCV_DATA_PACKET,
  USB_PROT_IN_TX_DATA_PID_1,
  USB_PROT_IN_TX_DATA_PID_2,
  USB_PROT_IN_TX_DATA_PACKET,
  USB_PROT_IN_TX_CRC16_BYTE1,
  USB_PROT_IN_TX_CRC16_BYTE2,
  USB_PROT_BAD_IN_TX_CRC16_BYTE1,
  USB_PROT_BAD_IN_TX_CRC16_BYTE2,
  USB_PROT_IN_WF_RX_HANDSHAKE,
  USB_PROT_TX_TEST_PACKET,
  USB_PROT_WF_END_TX_TEST_PACKET,
  USB_PROT_WF_TX_TEST_PACKET,
  USB_PROT_WF_EXT_TOKEN_PID,
  USB_PROT_WF_EXT_TOKEN_BYTE2,
  USB_PROT_WF_EXT_TOKEN_BYTE3
);

signal packet_handling_state_nxt,packet_handling_state_r : t_packet_handling_state;

type T_UsbSpeed is (USB_FULL_SPEED,
                    USB_HIGH_SPEED
                          );
signal dev_speed_r: T_UsbSpeed;

signal set_dev_fs: std_logic;
signal set_dev_hs: std_logic;
signal isotoggle_r : std_logic;

signal pid_r : std_logic_vector(3 downto 0);
signal ep_r       : std_logic_vector(3 downto 0);
signal epinfo_req_r      :  std_logic;
signal epinfo_epnr_r     :  std_logic_vector(3 downto 0);
signal epinfo_epdir_r    :  std_logic;
signal epinfo_setup_r    :  std_logic;
signal epinfo_setup_ok_r :  std_logic;
signal usbaddress_r      :  std_logic_vector(6 downto 0);
signal ignore_data_r     :  std_logic;
signal crc16_result_r    :  std_logic_vector(15 downto 0);

signal crc16_result_rx   :  std_logic_vector(15 downto 0);
signal crc16_result_tx   :  std_logic_vector(15 downto 0);


signal pid_nxt:std_logic_vector(3 downto 0);
signal new_pid_vld : std_logic;
signal new_token_byte2_vld : std_logic;
signal new_token_byte3_vld : std_logic;
signal new_ext_token_byte2_vld : std_logic;
signal new_ext_token_byte3_vld : std_logic;

signal new_sof_vld : std_logic;
signal new_inoutsetup_vld : std_logic;

signal clear_epinfo_req : std_logic;

signal set_ignore_data : std_logic;
signal clear_ignore_data : std_logic;


signal crc5_valid_nxt : std_logic;
signal txdata_pkt_nxt               :  std_logic_vector(7 downto 0);
signal crc16_eval_rx: std_logic;
signal crc16_eval_tx: std_logic;
signal crc16_valid_nxt : std_logic;

signal data_fifo_fill_rx : std_logic;
signal data_fifo_fill_tx : std_logic;
signal clear_data_fifo   : std_logic;
signal txdata_fetched: std_logic;
signal txdata_req_r: std_logic;

signal clear_pie_success: std_logic;
signal set_pie_success: std_logic;
signal errortype      : std_logic_vector(3 downto 0);

signal set_pie_sentNAK : std_logic;
signal clear_pie_sentNAK : std_logic;

signal keepprevdata_r: std_logic;

signal packetsize: unsigned(14 downto 0);

signal decr_iso_transact_cnt_down: std_logic;
signal clear_iso_transact_cnt_down: std_logic;
signal load_iso_transact_cnt_down: std_logic;
signal iso_transact_cnt_down : unsigned (1 downto 0);

signal incr_iso_mdata_cnt_up: std_logic;
signal clear_iso_mdata_cnt_up: std_logic;
signal iso_mdata_cnt_up : unsigned (1 downto 0);

signal rx_nbytes : std_logic_vector(11 downto 0);
signal set_rx_nbytes : std_logic;

signal moved_to_tx : std_logic;
signal moved_to_tx_d : std_logic;
signal moved_to_tx_dd : std_logic;
signal moved_to_tx_ddd : std_logic;

signal eop_rx: std_logic;
signal eop_tx: std_logic;
signal sop_start: std_logic;
signal sop_det_r: std_logic;
signal clear_sop_det: std_logic;

--ULPI specific
type t_ulpi_oper_state is
(
  ULPI_OPER_RESET_PWR_INIT,
  ULPI_OPER_RESET_IREG_WR_TX_CMD,
  ULPI_OPER_RESET_REG_WR_TX_DATA,
  ULPI_OPER_RESET_WF_START_RESET_PHY,
  ULPI_OPER_RESET_WF_END_RESET_PHY,
  ULPI_OPER_RESET_WF_RXCMD_UPDATE,
  ULPI_OPER_RESET_CMD_RCV,
  ULPI_OPER_IDLE,
  ULPI_OPER_IREG_WR_TX_CMD,
  ULPI_OPER_XREG_WR_TX_CMD,
  ULPI_OPER_XREG_WR_TX_ADD,
  ULPI_OPER_REG_WR_TX_DATA,
  ULPI_OPER_IREG_RD_TX_CMD,
  ULPI_OPER_XREG_RD_TX_CMD,
  ULPI_OPER_XREG_RD_TX_ADD,
  ULPI_OPER_REG_RD_TX_DATA,
  ULPI_OPER_REG_END_CYCLE,
  ULPI_OPER_CMD_RCV,
  ULPI_OPER_PKT_RCV,
  ULPI_OPER_NOPID_TX_CMD,
  ULPI_OPER_NOPID_TX_DATA,
  ULPI_OPER_PID_TX_CMD,
  ULPI_OPER_PID_TX_DATA,
  ULPI_OPER_PKT_TX_END,
  ULPI_OPER_LOW_POWER,
  ULPI_OPER_EXIT_LOW_POWER
);

constant ULPI_ADDR_FCTCTRL_REG_WR  : std_logic_vector(7 downto 0) := "00000100"; -- 04h
constant ULPI_ADDR_FCTCTRL_REG_SET : std_logic_vector(7 downto 0) := "00000101"; -- 05h
constant ULPI_ADDR_FCTCTRL_REG_CLR : std_logic_vector(7 downto 0) := "00000110"; -- 06h
constant ULPI_ADDR_OTGCTRL_REG_CLR : std_logic_vector(7 downto 0) := "00001100"; -- 0Ch
constant ULPI_ADDR_INT_REG_RD      : std_logic_vector(7 downto 0) := "00010011"; -- 13h
constant ULPI_ADDR_DBG_REG_RD      : std_logic_vector(7 downto 0) := "00010101"; -- 15h

constant ULPI_ARB_FCTCTRL_REG_RESET : std_logic_vector(3 downto 0) := "0001"; -- 1h
constant ULPI_ARB_FCTCTRL_REG_SUSP  : std_logic_vector(3 downto 0) := "0010"; -- 2h
constant ULPI_ARB_FCTCTRL_REG_WR    : std_logic_vector(3 downto 0) := "0011"; -- 3h
constant ULPI_ARB_OTGCTRL_REG_WR    : std_logic_vector(3 downto 0) := "0100"; -- 4h
constant ULPI_ARB_INT_REG_RD        : std_logic_vector(3 downto 0) := "0101"; -- 5h
constant ULPI_ARB_DBG_REG_RD        : std_logic_vector(3 downto 0) := "0110"; -- 6h
constant ULPI_ARB_XREG_WR           : std_logic_vector(3 downto 0) := "1000"; -- 8h
constant ULPI_ARB_XREG_RD           : std_logic_vector(3 downto 0) := "1001"; -- 9h


signal ulpi_oper_state_nxt, ulpi_oper_state_r : t_ulpi_oper_state;
signal ulpi_dir_r: std_logic;
signal ulpi_dir_int: std_logic;
signal ulpi_dir_r_s: std_logic;
signal ulpi_nxt_r: std_logic;
signal ulpi_nxt_int: std_logic;
signal ulpi_rxdata_r: std_logic_vector (7 downto 0);
signal ulpi_reg_access_req: std_logic;
signal ulpi_reg_access_wr_i: std_logic;
signal ulpi_ext_reg : std_logic;
signal set_ulpi_tx_nopid_req: std_logic;
signal ulpi_tx_nopid_req_r: std_logic;
signal clear_ulpi_tx_nopid_req: std_logic;
signal ulpi_txdata_nxt_i : std_logic_vector (7 downto 0);
signal ulpi_stp_nxt : std_logic;
signal ulpi_stp_r : std_logic;
signal ulpi_stp_async : std_logic;
signal ulpi_reg_tx_addr  : std_logic_vector(7 downto 0);
signal ulpi_tx_data_wr:std_logic_vector (7 downto 0);
signal ulpi_turnaround : std_logic;
signal ulpi_rxvalid_r : std_logic;
signal ulpi_rxactive_r : std_logic;
signal ulpi_rxactive_cmd : std_logic;
signal set_ulpi_rxactive_line: std_logic;
signal set_new_rxcmd : std_logic;
signal ulpi_rxerror_cmd : std_logic;
signal ulpi_txready: std_logic;
signal ulpi_rxerror_r : std_logic;
signal ulpi_linestate_r : std_logic_vector(1 downto 0);
signal ulpi_linestate_cmd : std_logic_vector(1 downto 0);
signal ulpi_opmode_r : std_logic_vector(1 downto 0);
signal ulpi_xcvrselect_r : std_logic;
signal ulpi_termselect_r : std_logic;
signal ulpi_suspendm_r : std_logic;
signal ulpi_arb_reg_nxt : std_logic_vector (3 downto 0);
signal ulpi_arb_reg_r : std_logic_vector (3 downto 0);
signal clear_ulpi_req_txcmd : std_logic;
signal set_ulpi_arb_reg_pending : std_logic;
signal ulpi_packet_idle : std_logic;

signal set_ulpi_req_txcmd_fct_ctrl_wr : std_logic;
signal set_ulpi_req_txcmd_fct_ctrl_wr_oprst : std_logic;
signal ulpi_req_txcmd_fct_ctrl_wr_r : std_logic;

signal set_ulpi_req_txcmd_fct_ctrl_susp : std_logic;
signal ulpi_req_txcmd_fct_ctrl_susp_r : std_logic;

signal set_ulpi_req_txcmd_fct_ctrl_reset : std_logic;
signal ulpi_req_txcmd_fct_ctrl_reset_r : std_logic;

signal set_ulpi_req_txcmd_otg_ctrl_wr_oprst : std_logic;
signal ulpi_req_txcmd_otg_ctrl_wr_r : std_logic;

signal set_ulpi_req_txcmd_int_stat : std_logic;
signal ulpi_req_txcmd_int_stat_r : std_logic;

signal set_ulpi_req_txcmd_dbg : std_logic;
signal ulpi_req_txcmd_dbg_r : std_logic;

signal set_ulpi_req_xreg_wr : std_logic;
signal ulpi_req_xreg_wr_r : std_logic;

signal set_ulpi_req_xreg_rd : std_logic;
signal ulpi_req_xreg_rd_r : std_logic;
signal ulpi_pwrst_r: std_logic;
signal ulpi_pwrst_r_s: std_logic;
signal set_ulpi_pwrst_det: std_logic;
signal clear_ulpi_pwrst_det: std_logic;
signal ulpi_pwrst_det_r: std_logic;
signal ulpi_vbusvalid_r : std_logic;
signal ulpi_vbusvalid_cmd : std_logic;
signal ulpi_req_low_power_mode_r : std_logic;
signal clear_ulpi_req_low_power_mode : std_logic;
signal set_ulpi_req_low_power_mode : std_logic;
signal ulpi_async_mode_r : std_logic;
signal set_ulpi_async_mode: std_logic;
signal clear_ulpi_async_mode: std_logic;

signal ulpi_arb_reg_pending_r: std_logic;

signal ulpi_xreg_add: std_logic_vector(7 downto 0);
signal ulpi_xreg_wdata: std_logic_vector(7 downto 0);
signal ulpi_xreg_write : std_logic;
signal ulpi_xreg_rdata_r: std_logic_vector(7 downto 0);
signal set_ulpi_phy_endtoggle : std_logic;
signal set_ulpi_reg_rdata_vld : std_logic;

signal pie_success_int : std_logic;
signal pie_dev_selected_int : integer range 0 to C_NBDEV - 1;

--FUNCTIONS:


function bit_reverse16
    ( data_in         : std_logic_vector(15 downto 0))
    return std_logic_vector is -- 16 bits
    variable v_data_out : std_logic_vector(15 downto 0);
  begin  -- bit_reverse16
    v_data_out := (others => '0');
    for i_bit_reverse16 in 15 downto 0 loop
      v_data_out(i_bit_reverse16) := data_in(15 - i_bit_reverse16);
    end loop;  -- i_bit_reverse16
    return (v_data_out);
  end bit_reverse16;

 function bit_reverse8
    ( data_in         : std_logic_vector(7 downto 0))
    return std_logic_vector is -- 8 bits
    variable v_data_out : std_logic_vector(7 downto 0);
  begin  -- bit_reverse16
    v_data_out := (others => '0');
    for i_bit_reverse8 in 7 downto 0 loop
      v_data_out(i_bit_reverse8) := data_in(7 - i_bit_reverse8);
    end loop;  -- i_bit_reverse8
    return (v_data_out);
  end bit_reverse8;

 function generate_pid_byte
    ( data_in         : std_logic_vector(3 downto 0))
    return std_logic_vector is -- 8 bits
    variable v_data_out : std_logic_vector(7 downto 0);
  begin  -- bit_reverse16
    v_data_out(7 downto 4) := not data_in;
    v_data_out(3 downto 0) := data_in;
    return (v_data_out);
  end generate_pid_byte;

function crc5_data16
    ( data16 : std_logic_vector(15 downto 0) )
    return std_logic_vector is -- 5 bits

    variable v_d      : std_logic_vector(15 downto 0);
    constant PRELOAD  : std_logic_vector(4 downto 0) := "11111";
    variable v_newcrc5 : std_logic_vector(4 downto 0);
  begin
    v_d       := data16;
    v_newcrc5    := (others => '0');
    v_newcrc5(0) := v_d(13) xor v_d(12) xor v_d(11) xor v_d(10) xor v_d(9) xor v_d(6) xor
               v_d(5) xor v_d(3) xor v_d(0) xor PRELOAD(0) xor PRELOAD(1) xor PRELOAD(2);
    v_newcrc5(1) := v_d(14) xor v_d(13) xor v_d(12) xor v_d(11) xor v_d(10) xor v_d(7) xor
               v_d(6) xor v_d(4) xor v_d(1) xor PRELOAD(0) xor PRELOAD(1) xor PRELOAD(2) xor PRELOAD(3);
    v_newcrc5(2) := v_d(15) xor v_d(14) xor v_d(10) xor v_d(9) xor v_d(8) xor v_d(7) xor
               v_d(6) xor v_d(3) xor v_d(2) xor v_d(0) xor PRELOAD(3) xor PRELOAD(4);
    v_newcrc5(3) := v_d(15) xor v_d(11) xor v_d(10) xor v_d(9) xor v_d(8) xor v_d(7) xor
               v_d(4) xor v_d(3) xor v_d(1) xor PRELOAD(0) xor PRELOAD(4);
    v_newcrc5(4) := v_d(12) xor v_d(11) xor v_d(10) xor v_d(9) xor v_d(8) xor v_d(5) xor
               v_d(4) xor v_d(2) xor PRELOAD(0) xor PRELOAD(1);
    return (v_newcrc5);
  end crc5_data16;


  function crc16_data8
        ( data8      : std_logic_vector(7 downto 0);
          last_crc16 : std_logic_vector(15 downto 0) )
        return std_logic_vector is -- 16 bits

        variable v_d     : std_logic_vector(7 downto 0);
        variable v_c     : std_logic_vector(15 downto 0);
        variable v_newcrc16 : std_logic_vector(15 downto 0);
      begin
        v_d        := data8;
        v_c        := last_crc16;
        v_newcrc16    := (others => '0');
        v_newcrc16(0) := v_d(7) xor v_d(6) xor v_d(5) xor v_d(4) xor v_d(3) xor v_d(2) xor
                    v_d(1) xor v_d(0) xor v_c(8) xor v_c(9) xor v_c(10) xor v_c(11) xor
                    v_c(12) xor v_c(13) xor v_c(14) xor v_c(15);
        v_newcrc16(1) := v_d(7) xor v_d(6) xor v_d(5) xor v_d(4) xor v_d(3) xor v_d(2) xor
                    v_d(1) xor v_c(9) xor v_c(10) xor v_c(11) xor v_c(12) xor v_c(13) xor
                    v_c(14) xor v_c(15);
        v_newcrc16(2)  := v_d(1) xor v_d(0) xor v_c(8) xor v_c(9);
        v_newcrc16(3)  := v_d(2) xor v_d(1) xor v_c(9) xor v_c(10);
        v_newcrc16(4)  := v_d(3) xor v_d(2) xor v_c(10) xor v_c(11);
        v_newcrc16(5)  := v_d(4) xor v_d(3) xor v_c(11) xor v_c(12);
        v_newcrc16(6)  := v_d(5) xor v_d(4) xor v_c(12) xor v_c(13);
        v_newcrc16(7)  := v_d(6) xor v_d(5) xor v_c(13) xor v_c(14);
        v_newcrc16(8)  := v_d(7) xor v_d(6) xor v_c(0) xor v_c(14) xor v_c(15);
        v_newcrc16(9)  := v_d(7) xor v_c(1) xor v_c(15);
        v_newcrc16(10) := v_c(2);
        v_newcrc16(11) := v_c(3);
        v_newcrc16(12) := v_c(4);
        v_newcrc16(13) := v_c(5);
        v_newcrc16(14) := v_c(6);
        v_newcrc16(15) := v_d(7) xor v_d(6) xor v_d(5) xor v_d(4) xor v_d(3) xor v_d(2) xor
                     v_d(1) xor v_d(0) xor v_c(7) xor v_c(8) xor v_c(9) xor v_c(10) xor
                     v_c(11) xor v_c(12) xor v_c(13) xor v_c(14) xor v_c(15);
        return v_newcrc16;
    end crc16_data8;

   function log2 (x : natural) return natural is --log2 of 8 will return 3
           variable temp,v_res,flag_rem2: natural;
         begin
           temp := x;
           v_res := 0;
           flag_rem2 := 0;
           if x <= 1 then
              return 0;
           else
              while (temp > 1) loop
                 if temp rem 2 = 1 then
                    flag_rem2 := 1;
                 end if;
                 temp := temp/2;
                 v_res := v_res + 1;
              end loop;
              return v_res + flag_rem2;
           end if;
    end function log2;

    function packetsize_decod(
            epinfo_maxpacket:std_logic_vector(1 downto 0);
            epinfo_nbytes:std_logic_vector(14 downto 0);
            iso_transact_cnt_down: unsigned(1 downto 0);
            iso_mdata_cnt_up : unsigned (1 downto 0);
            iso_in_pending_r : std_logic;
            iso_out_pending_r : std_logic
            )
    return unsigned is
       variable v_maxpacket: unsigned(14 downto 0); ---- matches size of epinfo_nbytes
    begin
      case epinfo_maxpacket is
      when "00" => --This is set for FS Control, Bulk and Interrupt endpoints and HS Control endpoint
         v_maxpacket := to_unsigned(64,15);
      when "01" => -- This is set for HS bulk endpoints and HS interrupt with MaxPacket of 512 bytes
         v_maxpacket := to_unsigned(512,15);
      when "10" => -- This will only be set for FS isochronous endpoints
         v_maxpacket := to_unsigned(1023,15);
      when others => --  = "11"  This is set for HS isochronous and HS interrupt endpoints with MaxPacketSize
      -- bigger than 512 (including both high-bandwidth iso and interrupt endpoints)
         v_maxpacket := to_unsigned(1024,15);
      end case;
      if epinfo_maxpacket = "11" and iso_in_pending_r = '1' then  -- High-Bandwidth Iso IN
         if epinfo_nbytes(11 downto 10) = "11" then -- corner case: 3 transactions of 1024 bytes each, lsb (9 downto 0) are ignored
            return v_maxpacket; --1024 bytes
         elsif iso_transact_cnt_down = "00" then -- last transaction or single transaction
            return "00000" & unsigned(epinfo_nbytes(9 downto 0)); -- max 1023 bytes
         else   -- first transactions
            return v_maxpacket; --1024 bytes
         end if;
      elsif epinfo_maxpacket = "11" and iso_out_pending_r = '1' then  -- High-Bandwidth Iso OUT
         if epinfo_nbytes(11 downto 10) = "11" then -- corner case: 3 transactions of 1024 bytes each, lsb (9 downto 0) are ignored
            return v_maxpacket; --1024 bytes
         elsif iso_transact_cnt_down = "00" and iso_mdata_cnt_up /="00"  then -- last transaction
            return "00000" & unsigned(epinfo_nbytes(9 downto 0)); -- max 1023 bytes
         else   -- first transactions or single transaction ( 1 single transaction of 1024 bytes is accepted)
            return v_maxpacket; --1024 bytes
         end if;
      else
         if unsigned(epinfo_nbytes) < v_maxpacket then
            return unsigned(epinfo_nbytes);
         else
            return v_maxpacket;
         end if;
      end if;
   end function packetsize_decod;

   function test_paket_decod(test_pkt_byte_cnt: unsigned (5 downto 0))
      return unsigned is
      variable var_test_pkt_byte: unsigned (7 downto 0);
      begin
       case test_pkt_byte_cnt is
       when "000000" =>
          var_test_pkt_byte := "11000011"; -- 0xc3 (DATA0)
       when "000001"|"000010"|"000011"|"000100"|
            "000101"|"000110"|"000111"|"001000"|"001001" =>
          var_test_pkt_byte := "00000000";  -- 0x00 (TP01 --> TP09) 9 bytes
       when "001010"|"001011"|"001100"|"001101"|
            "001110"|"001111"|"010000"|"010001" =>
          var_test_pkt_byte := "10101010";  -- 0xaa (TP10 --> TP17) 8 bytes
       when "010010"|"010011"|"010100"|"010101"|
            "010110"|"010111"|"011000"|"011001" =>
          var_test_pkt_byte := "11101110";  -- 0xee (TP18 --> TP25) 8 bytes
       when "011010" =>
          var_test_pkt_byte := "11111110";  -- 0xfe (TP26) 1 byte
       when "011011"|"011100"|"011101"|"011110"|"011111"|
            "100000"|"100001"|"100010"|"100011"|"100100"| "100101"=>
          var_test_pkt_byte := "11111111";  -- 0xff (TP27 --> TP37) 11 bytes
       when "100110" =>
          var_test_pkt_byte := "01111111";  -- 0x7f (TP38)
       when "100111" =>
          var_test_pkt_byte := "10111111";  -- 0xbf (TP39)
       when "101000" =>
          var_test_pkt_byte := "11011111";  -- 0xdf (TP40)
       when "101001" =>
          var_test_pkt_byte := "11101111";  -- 0xef (TP41)
       when "101010" =>
          var_test_pkt_byte := "11110111";  -- 0xf7 (TP42)
       when "101011" =>
          var_test_pkt_byte := "11111011";  -- 0xfb (TP43)
       when "101100" =>
          var_test_pkt_byte := "11111101";  -- 0xfd (TP44)
       when "101101" =>
          var_test_pkt_byte := "11111100";  -- 0xfc (TP45)
       when "101110" =>
          var_test_pkt_byte := "01111110";  -- 0x7e (TP46)
       when "101111" =>
          var_test_pkt_byte := "10111111";  -- 0xbf (TP47)
       when "110000" =>
          var_test_pkt_byte := "11011111";  -- 0xdf (TP48)
       when "110001" =>
          var_test_pkt_byte := "11101111";  -- 0xef (TP49)
       when "110010" =>
          var_test_pkt_byte := "11110111";  -- 0xf7 (TP50)
       when "110011" =>
          var_test_pkt_byte := "11111011";  -- 0xfb (TP51)
       when "110100" =>
          var_test_pkt_byte := "11111101";  -- 0xfd (TP52)
       when "110101" =>
          var_test_pkt_byte := "01111110";  -- 0x7e (TP53)
       when "110110" =>
          var_test_pkt_byte := "10110110";  -- 0xb6 (CRC16) LSB is sent first
       when "110111" =>
          var_test_pkt_byte := "11001110";  -- 0xce (CRC16) LSB is sent first
       when  others =>
         var_test_pkt_byte :=  "00000000";
        end case;

        return var_test_pkt_byte;

   end function test_paket_decod;



begin


--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------
--               UTMI/ULPI INTERFACE (begin)                --
--------------------------------------------------------------
--------------------------------------------------------------
-- ASSUMPTIONS UTMI:
--
-- UTMI+ Level 0 only
-- HS/FS Version
-- 8-bit unidirectional (utmi_clk = 60 MHz)
-- No Vendor Status/Controls as defined in UTMI spec rev 1.05



--UTMI/ULPI selection

-- selection of the input clock is moved to 3511_hs toplevel
-- pie_clk <= utmi_clk when UTMI_SUPPORT= true and phy_mode = '0' else
--           ulpi_clk when ULPI_SUPPORT= true and phy_mode = '1' else
--            '0';

linestate <= utmi_linestate_r when phy_mode = '0' else
             ulpi_linestate_r;

rxdata <=  utmi_rxdata_r when phy_mode = '0' else
           ulpi_rxdata_r;

rxvalid <=  utmi_rxvalid_r when phy_mode = '0' else
            ulpi_rxvalid_r;

rxactive <=  utmi_rxactive_r when phy_mode = '0' else
             ulpi_rxactive_r;

rxerror <=  utmi_rxerror_r when phy_mode = '0' else
            ulpi_rxerror_r;

rx_ok <= '1' when rxvalid ='1'and rxactive='1' and rxerror='0' else '0';

txready <=  utmi_txready when phy_mode = '0' else
            ulpi_txready;

pie_vbusvalid <= utmi_vbusvalid when phy_mode = '0' else
                 ulpi_vbusvalid_r;


utmi_ulpi_clk_proc: process (pie_clk, reset_n)

begin

if reset_n = '0' then
   --utmi output signals
   utmi_opmode <= "01";
   utmi_xcvrselect <= '0';
   utmi_termselect <= '0';
   utmi_txvalid <= '0';
   utmi_txdata <= (others => '0');
   --utmi internal signals
   txready_r <= '0';
   utmi_rxdata_r             <= (others => '0');
   utmi_rxvalid_r            <= '0';
   utmi_rxactive_r           <= '0';
   utmi_rxerror_r            <= '0';
   utmi_linestate_r          <= "00";
   -- ulpi internal signals
   ulpi_dir_r <= '0';
   ulpi_dir_r_s <= '0';
   ulpi_nxt_r <= '0';
   ulpi_rxdata_r <= (others => '0');
   ulpi_opmode_r <= "01";
   ulpi_xcvrselect_r <= '0';
   ulpi_termselect_r <= '0';
   ulpi_suspendm_r <= '0';
   ulpi_txdata <= (others => '0');
    -- ulpi external signal
   ulpi_stp_r <= '1';
elsif pie_clk'event and pie_clk ='1'then
   txready_r <= txready;
   if phy_mode = '1' then -- ULPI interface is selected
      utmi_opmode <= "01";
      utmi_xcvrselect <= '0';
      utmi_termselect <= '0';
      utmi_txvalid <= '0';
      utmi_txdata <= (others => '0');
      utmi_rxdata_r             <= (others => '0');
      utmi_rxvalid_r            <= '0';
      utmi_rxactive_r           <= '0';
      utmi_rxerror_r            <= '0';
      utmi_linestate_r          <= "00";
      ulpi_stp_r <= ulpi_stp_nxt;
      ulpi_dir_r <= ulpi_dir_int;
      ulpi_dir_r_s <= ulpi_dir_r;
      ulpi_nxt_r <= ulpi_nxt_int;
      ulpi_rxdata_r <= ulpi_rxdata;
      if packet_handling_state_r = USB_PROT_IN_TX_DATA_PACKET or packet_handling_state_r = USB_PROT_TX_TEST_PACKET then
         if ulpi_nxt_int ='1' then  -- IN HS/FS mode, ulpi_txdata must only change when ulpi_nxt_int is high
            ulpi_txdata <= ulpi_txdata_nxt_i;
         end if;
      else
         ulpi_txdata <= ulpi_txdata_nxt_i;
      end if;
      ulpi_opmode_r <= opmode_nxt;
      ulpi_xcvrselect_r <= xcvrselect_nxt;
      ulpi_termselect_r <= termselect_nxt;
      ulpi_suspendm_r <= suspendm_nxt;
   else  -- UTMI interface is selected
      utmi_opmode <= opmode_nxt;
      utmi_xcvrselect <= xcvrselect_nxt;
      utmi_termselect <= termselect_nxt;
      utmi_rxdata_r             <= utmi_rxdata;
      utmi_rxvalid_r            <= utmi_rxvalid;
      utmi_rxactive_r           <= utmi_rxactive;
      utmi_rxerror_r            <= utmi_rxerror;
      utmi_linestate_r          <= utmi_linestate;
      utmi_txvalid <= txvalid_nxt;
      if packet_handling_state_r = USB_PROT_IN_TX_DATA_PACKET or packet_handling_state_r = USB_PROT_TX_TEST_PACKET then
         if txready ='1' then  -- IN HS/FS mode, utmi_txdata must only change when txready is high
            utmi_txdata <= txdata_nxt;
         end if;
      else
         utmi_txdata <= txdata_nxt;
      end if;
      ulpi_dir_r <= '0';
      ulpi_dir_r_s <= '0';
      ulpi_nxt_r <= '0';
      ulpi_rxdata_r <= (others => '0');
      ulpi_txdata <= (others => '0');
      ulpi_opmode_r <= "01";
      ulpi_xcvrselect_r <= '0';
      ulpi_termselect_r <= '0';
      ulpi_suspendm_r <= '1';
      ulpi_stp_r <= '1';
   end if;
end if;

end process utmi_ulpi_clk_proc;

ulpi_txenable <= '1' when ulpi_dir_int = '0' and ulpi_dir_r = '0' and ULPI_SUPPORT and phy_mode = '1'
                     else '0';

ulpi_dir_int <= ulpi_dir when  ULPI_SUPPORT and phy_mode = '1'
                     else '0';

ulpi_nxt_int <= ulpi_nxt when  ULPI_SUPPORT and phy_mode = '1'
                     else '0';

ulpi_stp <= ulpi_stp_r when ulpi_async_mode_r = '0' else
            ulpi_stp_async;

-- UTMI/ULPI signals that are driven combinatorially
utmi_ulpi_out_comb_proc: process (suspendm_nxt,ulpi_oper_state_r,reset_n,phy_mode,ulpi_dir_r)

begin
   if phy_mode = '0' then -- UTMI mode
      utmi_reset     <= not reset_n;
      pie_lowpower_n <= suspendm_nxt;
   else -- ULPI mode
      utmi_reset <= '0';
      if ulpi_oper_state_r = ULPI_OPER_LOW_POWER and ulpi_dir_r = '1'then
      -- should mimic the internal suspend bit register of the PHY (not directly equivalent to suspend_nxt)
         pie_lowpower_n <= '0';
      else
         pie_lowpower_n <= '1';
      end if;
end if;

end process utmi_ulpi_out_comb_proc;

-- UTMI+/ULPI Vendor specific Interface
---------------------------------------

utmi_ulpi_vendor_specific_comb_proc: process (phy_mode,utmi_vstatus,phy_address,phy_start,phy_endtoggle_r,phy_write,phy_writedata,ulpi_xreg_rdata_r )

begin
  -- default values
   phy_readdata <= (others => '0');
   utmi_vcontrol <= (others => '0');
   utmi_vcontrolloadm <= '1';
   ulpi_xreg_add <= (others => '0');
   ulpi_xreg_wdata <= (others => '0');
   ulpi_xreg_write <= '0';
   phy_readdata <= (others => '0');
   phy_endtoggle <= phy_endtoggle_r;
   if phy_mode = '0' then
      utmi_vcontrol <= phy_address(3 downto 0);
      utmi_vcontrolloadm <= not(phy_start);
      phy_readdata <= utmi_vstatus;
   else
      ulpi_xreg_add   <= phy_address;
      ulpi_xreg_wdata <= phy_writedata;
      ulpi_xreg_write  <= phy_write;
      phy_readdata    <= ulpi_xreg_rdata_r;
   end if;

end process utmi_ulpi_vendor_specific_comb_proc;


utmi_ulpi_vendor_specific_clk_proc: process (pie_clk, reset_n)

begin

if reset_n = '0' then

   phy_endtoggle_r <= '0';

elsif pie_clk'event and pie_clk ='1'then

   if phy_mode = '0' then
      if phy_start = '1' then
         phy_endtoggle_r <= not phy_endtoggle_r;
      end if;
   elsif set_ulpi_phy_endtoggle = '1' then
      phy_endtoggle_r <= not phy_endtoggle_r;
   end if;
end if;

end process utmi_ulpi_vendor_specific_clk_proc;


--For UTMI+ interface, phy_endtoggle is inverted when phy_start = �1�.�




--------------------------------------------------------------
--------------------------------------------------------------
--               UTMI/ULPI INTERFACE (end)                  --
--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------


--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------
--                BUS EVENT HANDLING (begin)              --
--------------------------------------------------------------
--------------------------------------------------------------


--HS mode: LineState transition from the Idle state (SE0) to a
--non-Idle state (J) marks the beginning of a packet on the bus
--LineState transition from a non-Idle
--state (J) to the Idle state (SE0) marks the end of a packet on the bus

--FS mode: the LineState transition from the J State (Idle) to a K
--State marks the beginning of a packet on the bus
--LineState transition from the SE0 to the J-State marks the end of a FS packet on the bus.


-- USB BUS EVENT STATE MACHINE
-- BUS EVENTS (according to UTMI Spec):
---------------------------------------
-- FS ACTVE MODE
-- HS ACTIVE MODE
-- HS RESET
-- FS RESET
-- SUSPEND MODE
-- HS DETECTION HANDSHAKE (chirp incl.):
-- a/FS DS Port
-- b/HS DS Port
-- c/from Suspend port
-- ASSERTION RESUME
-- DETECTION RESUME
-- HS DEVICE ATTACH
-- TEST MODE
-- TRANSMIT ERROR

bus_event_fsm_comb_proc : process (bus_event_state_r,ls_dbc,linestate,timer_bus_event,usbreg_dev_connect,
                                   usbreg_remotewakeup,ls_filt,chirp_count,usbreg_phy_test_mode,sync_usbreg_phy_test_mode_change,
                                   timer_bus_event_timeout_r,dev_speed_r,rxactive,lpm_wf_l1_state_r,usbreg_lpmremotewakeup,
                                   sync_usbreg_lpmremotewakeup,sync_usbreg_remotewakeup,usbreg_port_force_fullspeed)

begin
-- default values
   bus_event_state_nxt <= bus_event_state_r;
   init_linestate_dbc <= '0';
   clear_timer_bus_event <= '0';
   chirp_count_pls <= '0';
   chirp_count_clear <= '0';
   set_dev_fs <= '0';
   set_dev_hs <= '0';
   clear_lpm_wf_l1_state <= '0';
   set_lpm_l1_state <= '0';

   if usbreg_dev_connect = '0' then
      bus_event_state_nxt <= BUS_EVENT_INIT;
      clear_timer_bus_event <= '1';
      init_linestate_dbc <= '1';
      chirp_count_pls <= '0';
      chirp_count_clear <= '0';
      clear_lpm_wf_l1_state <= '1';
      set_dev_fs <= '1'; --when disconnected and while running, needs to set back to FS
   elsif timer_bus_event_timeout_r = '1' then
      bus_event_state_nxt <= BUS_EVENT_FS_IDLE; -- no need to switch off the clock
      clear_timer_bus_event <= '1';
      init_linestate_dbc <= '1';
      chirp_count_pls <= '0';
      chirp_count_clear <= '0';
      clear_lpm_wf_l1_state <= '1';
      set_dev_fs <= '1'; -- need to set back to FS
   elsif usbreg_phy_test_mode /= "000" and sync_usbreg_phy_test_mode_change = '1' then
      bus_event_state_nxt <= BUS_EVENT_TEST_MODE; -- normal way to exit this state is via a Power cycle
      clear_timer_bus_event <= '1';
      init_linestate_dbc <= '1';
   else
      case bus_event_state_r is
         when BUS_EVENT_INIT =>
            if usbreg_dev_connect = '1' then
               bus_event_state_nxt <= BUS_EVENT_FS_IDLE;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_FS_IDLE =>
            if ls_dbc =  LINESTATE_SE0 then -- SEO > 2.5 us
               bus_event_state_nxt <= BUS_EVENT_RESET;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif rxactive= '1' then  -- FS activity
               bus_event_state_nxt <= BUS_EVENT_FS_ACTIVE;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
               if lpm_wf_l1_state_r = '1' then -- lpm: ACK has not been seen by the host
                  clear_lpm_wf_l1_state <= '1';
               end if;
            elsif timer_bus_event = T_L1_Token_Retry and linestate = LINESTATE_J and lpm_wf_l1_state_r = '1' then -- IDLE for > 9us
               bus_event_state_nxt <= BUS_EVENT_LPM_SUSPEND_L1;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
               clear_lpm_wf_l1_state <= '1';
               set_lpm_l1_state <= '1';
            elsif timer_bus_event = T_3ms and linestate = LINESTATE_J then -- IDLE for > 3ms
               bus_event_state_nxt <= BUS_EVENT_WF_SUSPEND;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_FS_ACTIVE =>
            if ls_dbc =  LINESTATE_SE0 then -- SEO > 2.5 us
               bus_event_state_nxt <= BUS_EVENT_RESET;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif ls_dbc = LINESTATE_J then -- USB is IDLE  for > 2.5 us
               bus_event_state_nxt <= BUS_EVENT_FS_IDLE;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_HS_IDLE => -- SE0
            if rxactive = '1'then  -- HS activity
               bus_event_state_nxt <= BUS_EVENT_HS_ACTIVE;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
               if lpm_wf_l1_state_r = '1' then -- lpm: ACK has not been seen by the host
                  clear_lpm_wf_l1_state <= '1';
               end if;
            elsif timer_bus_event = T_L1_Token_Retry and linestate = LINESTATE_SE0 and lpm_wf_l1_state_r = '1' then -- IDLE for > 9us
               bus_event_state_nxt <= BUS_EVENT_LPM_SUSPEND_L1;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
               clear_lpm_wf_l1_state <= '1';
               set_lpm_l1_state <= '1';
-- BVE : The change below is not part of the IP in LPC55s69
--            in HS mode, the RXACTIVE signal indicates if the linestate is different from SE0. No need to explicitly check line state.
--            elsif timer_bus_event = T_3ms and linestate = LINESTATE_SE0 then -- IDLE for > 3ms
            elsif timer_bus_event = T_3ms then -- IDLE for > 3ms
               bus_event_state_nxt <= BUS_EVENT_WF_SUSPEND_OR_RST;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_HS_ACTIVE => -- K or J
            if ls_dbc = LINESTATE_SE0 or rxactive ='0' then -- HS inactivity > 2.5 us
               bus_event_state_nxt <= BUS_EVENT_HS_IDLE;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_WF_SUSPEND_OR_RST => -- TO BE CHECKED: what if a K is detected or linestate is not stable ?
            if timer_bus_event = T_TWTRSTHS and ls_dbc = LINESTATE_SE0 then -- RESET detected > 2.5 us
               bus_event_state_nxt <= BUS_EVENT_RESET;
               clear_timer_bus_event <= '1';
               set_dev_fs <= '1'; -- back to FS mode
               init_linestate_dbc <= '1';
            elsif timer_bus_event = T_TWTRSTHS and ls_dbc = LINESTATE_J then -- SUSPEND detected > 2.5 us
               bus_event_state_nxt <= BUS_EVENT_WF_SUSPEND;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif timer_bus_event = T_TWTRSTHS and ls_dbc = LINESTATE_K then -- Host is already driving USB resume signal
-- BVE : the line below was part of the IP used in LPC55s69
--       This was creating a bug when the host does not wait 3.072 milliseconds before sending resume
--       USB2 spec states that host can generate USB resume at any moment.
--               bus_event_state_nxt <= BUS_EVENT_FS_IDLE;
               bus_event_state_nxt <= BUS_EVENT_HOST_RESUME;
               clear_timer_bus_event <= '1';
               set_dev_fs <= '1'; -- back to FS mode
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_RESET =>
            if usbreg_port_force_fullspeed = '1' then
               bus_event_state_nxt <= BUS_EVENT_WF_EOR_FS;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif timer_bus_event = T_125us then -- add extra delay before driving chirp K
               bus_event_state_nxt <= BUS_EVENT_HS_DET_HSK_1;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_WF_SUSPEND =>
            if ls_dbc = LINESTATE_SE0 then -- RESET detected > 2.5 us -- host initiates a bus reset
               bus_event_state_nxt <= BUS_EVENT_RESET;
               clear_timer_bus_event <= '1';
               set_dev_fs <= '1'; -- back to FS mode
               init_linestate_dbc <= '1';
            elsif timer_bus_event = T_3ms then  -- t= HS Reset T0 + TWTRSM (= T2SUSP) (UTMI spec 5.22.1.1)
               bus_event_state_nxt <= BUS_EVENT_SUSPEND;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;
         when BUS_EVENT_SUSPEND =>
            if ls_dbc = LINESTATE_SE0 then -- SE0 detected > 2.5 us
               bus_event_state_nxt <= BUS_EVENT_RESET;
               clear_timer_bus_event <= '1';
               set_dev_fs <= '1'; -- back to FS mode
               init_linestate_dbc <= '1';
            elsif ls_dbc = LINESTATE_K then  -- RESUME detected > 2.5 us
               bus_event_state_nxt <= BUS_EVENT_HOST_RESUME;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif usbreg_remotewakeup='1' then  -- DEVICE asserts its own RESUME
               bus_event_state_nxt <= BUS_EVENT_SW_WAKEUP_WF_CLK;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_SW_WAKEUP_WF_CLK =>
            if sync_usbreg_remotewakeup = '1' then -- txdata/txvalid must be driven in the usb clock domain (pie clock) to avoid metastability
               bus_event_state_nxt <= BUS_EVENT_SW_WAKEUP_1;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_SW_WAKEUP_1 =>
            if timer_bus_event = T_3ms  then
               bus_event_state_nxt <= BUS_EVENT_SW_WAKEUP_2;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_SW_WAKEUP_2 =>
            if timer_bus_event = T_TxENDDELAY then
               bus_event_state_nxt <= BUS_EVENT_SW_WAKEUP_3;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_SW_WAKEUP_3 =>
            if ls_filt = LINESTATE_SE0 then -- SE0 detected => Low Speed EOP (SE0 for 1.25-1.5 us)
               if dev_speed_r = USB_HIGH_SPEED then
                  bus_event_state_nxt <= BUS_EVENT_HS_IDLE;
                  clear_timer_bus_event <= '1';
                  init_linestate_dbc <= '1';
               else
                  bus_event_state_nxt <= BUS_EVENT_FS_IDLE;
                  clear_timer_bus_event <= '1';
                  init_linestate_dbc <= '1';
               end if;
            end if;
         when BUS_EVENT_HOST_RESUME =>
            if ls_filt = LINESTATE_SE0 then -- SE0 detected => Low Speed EOP (SE0 for 1.25-1.5 us)
               if dev_speed_r = USB_HIGH_SPEED then
                  bus_event_state_nxt <= BUS_EVENT_HS_IDLE;
                       clear_timer_bus_event <= '1';
                       init_linestate_dbc <= '1';
               else
                  bus_event_state_nxt <= BUS_EVENT_FS_IDLE;
                       clear_timer_bus_event <= '1';
                       init_linestate_dbc <= '1';
               end if;
            elsif linestate =  LINESTATE_J then  -- Wrong resume
               bus_event_state_nxt <= BUS_EVENT_SUSPEND;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_WF_EOR_FS => -- Wait for End of Reset FS
            if linestate /= LINESTATE_SE0 then -- End of reset is detected
               bus_event_state_nxt <= BUS_EVENT_FS_IDLE;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_HS_DET_HSK_1 => -- High Speed Detection HandShake
            if timer_bus_event = T_3ms  then --  TUCH minimum requirement is 1ms (UTMI spec 5.22.2.1)
               bus_event_state_nxt <= BUS_EVENT_HS_DET_HSK_2;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_HS_DET_HSK_2 => -- device starts looking for Chirp KJKJKJ sequence
            if timer_bus_event = T_TWTFS then -- chirp sequence timeout, back to FS
               bus_event_state_nxt <= BUS_EVENT_WF_EOR_FS;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif ls_dbc = LINESTATE_K then  -- chirp K detected for > 2.5 us
              -- timer_bus_event is still running !
               bus_event_state_nxt <= BUS_EVENT_HS_DET_HSK_3;
               chirp_count_clear <= '1'; -- initialise chirp counter
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_HS_DET_HSK_3 =>  -- waiting for Chirp J
            if timer_bus_event = T_TWTFS then -- chirp sequence timeout, back to FS
               bus_event_state_nxt <= BUS_EVENT_WF_EOR_FS;
               clear_timer_bus_event <= '1';
               chirp_count_clear <= '1';
               init_linestate_dbc <= '1';
            elsif ls_dbc = LINESTATE_J then  -- chirp J detected for > 2.5 us
               -- timer_bus_event is still running !
               bus_event_state_nxt <= BUS_EVENT_HS_DET_HSK_4;
               chirp_count_pls <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_HS_DET_HSK_4 => -- waiting for Chirp K
            if chirp_count = MAX_CHIRP_COUNT-1 then -- Chirp KJKJKJ sequence is detected (counter starts at 0)
               bus_event_state_nxt <= BUS_EVENT_WF_ENDCHIRP_HS;
               clear_timer_bus_event <= '1';
               chirp_count_clear <= '1';
               set_dev_hs <= '1';   -- device is operating at High Speed
               init_linestate_dbc <= '1';
            elsif timer_bus_event = T_TWTFS then -- chirp sequence timeout, back to FS
               bus_event_state_nxt <= BUS_EVENT_WF_EOR_FS;
               clear_timer_bus_event <= '1';
               chirp_count_clear <= '1';
               init_linestate_dbc <= '1';
            elsif ls_dbc = LINESTATE_K then  -- chirp K detected for > 2.5 us
               -- timer_bus_event is still running !
               bus_event_state_nxt <= BUS_EVENT_HS_DET_HSK_3;
               chirp_count_pls <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_WF_ENDCHIRP_HS => -- Wait for End of Chirp Sequence
            if ls_dbc = LINESTATE_SE0 then -- SE0 detected > 2.5 us  SE0 is asserted for min 100 us, max 500 us (5.22.2.2)
               bus_event_state_nxt <= BUS_EVENT_HS_IDLE;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_LPM_SUSPEND_L1 => --LPM L1 State (Sleep)
            if ls_dbc = LINESTATE_SE0 then -- SE0 detected > 2.5 us
               bus_event_state_nxt <= BUS_EVENT_RESET;
               clear_timer_bus_event <= '1';
               set_dev_fs <= '1'; -- back to FS mode
               init_linestate_dbc <= '1';
             elsif ls_dbc = LINESTATE_K then  -- RESUME detected > 2.5 us
               bus_event_state_nxt <= BUS_EVENT_HOST_RESUME;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
             elsif usbreg_lpmremotewakeup ='1' then  -- DEVICE asserts its own RESUME
                   bus_event_state_nxt <= BUS_EVENT_LPM_SW_WAKEUP_WF_CLK;
                   clear_timer_bus_event <= '1';
                   init_linestate_dbc <= '1';
             end if;

          when BUS_EVENT_LPM_SW_WAKEUP_WF_CLK =>
             if sync_usbreg_lpmremotewakeup = '1' then -- txdata/txvalid must be driven in the usb clock domain (pie clock) to avoid metastability
                bus_event_state_nxt <= BUS_EVENT_LPM_SW_WAKEUP_1;
                clear_timer_bus_event <= '1';
                init_linestate_dbc <= '1';
             end if;

          when BUS_EVENT_LPM_SW_WAKEUP_1 =>
             --TL1DevDrvResume1 min. is 50 us and maximum 60us (because host will drive resume upon remote wake for minimum 60 us)
             if timer_bus_event = T_60us  then 
                bus_event_state_nxt <= BUS_EVENT_SW_WAKEUP_2;
                 clear_timer_bus_event <= '1';
                 init_linestate_dbc <= '1';
             end if;

          -- when BUS_EVENT_LPM_SW_WAKEUP_2 =>          equivalent to BUS_EVENT_SW_WAKEUP_2
          -- when BUS_EVENT_LPM_SW_WAKEUP_3 =>          equivalent to BUS_EVENT_SW_WAKEUP_3

         when others =>   --TEST MODE
            if usbreg_phy_test_mode = "000" and sync_usbreg_phy_test_mode_change = '1' then  -- for debug purpose, normal way to exit this state is via a Power cycle
               bus_event_state_nxt <= BUS_EVENT_FS_IDLE;
               init_linestate_dbc <= '1';
            end if;


         end case;

   end if;
end process bus_event_fsm_comb_proc;


bus_event_fsm_clk_proc : process (pie_clk,reset_n)
begin
   if reset_n = '0' then
      bus_event_state_r <= BUS_EVENT_INIT;
   elsif pie_clk'event and pie_clk='1' then
      bus_event_state_r <= bus_event_state_nxt;
   end if;
end process bus_event_fsm_clk_proc;


bus_event_to_phy_comb_proc : process (bus_event_state_nxt,usbreg_pll_on,txvalid_pkt_nxt,txdata_pkt_nxt,usbreg_phy_test_mode,VBusDebounced,usbreg_dev_connect)
begin
  -- default values

   suspendm_nxt <= '1';
   opmode_nxt <= "00";
   xcvrselect_nxt <= '0';
   termselect_nxt <= '0';
   txvalid_nxt <= '0';
   txdata_nxt <= (others => '0');

      case bus_event_state_nxt is

         when BUS_EVENT_INIT => --

             -- clocks can be switched off if device is not attached yet or device is detached
            --BVE : enable clock only when software has indicated that a connect must be done
            --suspendm_nxt <= usbreg_pll_on or VBusDebounced;
            suspendm_nxt <= usbreg_pll_on or usbreg_dev_connect;
            opmode_nxt <= "01";  -- device disconnected from the bus
            xcvrselect_nxt <= '0';
            termselect_nxt <= '0';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_FS_IDLE =>

            suspendm_nxt <= '1';
            opmode_nxt <= "00";
            xcvrselect_nxt <= '1';
            termselect_nxt <= '1';
            txvalid_nxt <= txvalid_pkt_nxt; -- from packet_handling_fsm
            txdata_nxt <=  txdata_pkt_nxt; -- from packet_handling_fsm

         when BUS_EVENT_FS_ACTIVE =>

            suspendm_nxt <= '1';
            opmode_nxt <= "00";
            xcvrselect_nxt <= '1';
            termselect_nxt <= '1';
            txvalid_nxt <= txvalid_pkt_nxt; -- from packet_handling_fsm
            txdata_nxt <=  txdata_pkt_nxt; -- from packet_handling_fsm

         when BUS_EVENT_HS_IDLE =>

            suspendm_nxt <= '1';
            opmode_nxt <= "00";
            xcvrselect_nxt <= '0';
            termselect_nxt <= '0';
            txvalid_nxt <= txvalid_pkt_nxt; -- from packet_handling_fsm
            txdata_nxt <=  txdata_pkt_nxt; -- from packet_handling_fsm

         when BUS_EVENT_HS_ACTIVE =>

            suspendm_nxt <= '1';
            opmode_nxt <= "00";
            xcvrselect_nxt <= '0';
            termselect_nxt <= '0';
            txvalid_nxt <= txvalid_pkt_nxt; -- from packet_handling_fsm
            txdata_nxt <=  txdata_pkt_nxt; -- from packet_handling_fsm

         when BUS_EVENT_WF_SUSPEND_OR_RST =>
           -- Phy is placed in FS Mode
            suspendm_nxt <= '1';
            opmode_nxt <= "00";
            xcvrselect_nxt <= '1';
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_RESET =>

            suspendm_nxt <= '1';
            opmode_nxt <= "10";
            xcvrselect_nxt <= '0';
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_WF_SUSPEND =>

            suspendm_nxt <= '1';
            opmode_nxt <= "00";
            xcvrselect_nxt <= '1';
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_SUSPEND =>

            suspendm_nxt <= usbreg_pll_on;
            opmode_nxt <= "00";
            xcvrselect_nxt <= '1';
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

          when BUS_EVENT_SW_WAKEUP_WF_CLK =>
            -- device asserts its own resume
            -- PHY must be resumed asynchronously
            -- FS 'K' is not asserted yet
            suspendm_nxt <= '1';
            opmode_nxt <= "00";
            xcvrselect_nxt <= '1';
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_SW_WAKEUP_1 =>
            -- device asserts its own resume --
            -- asserts  FS 'K' on the bus
            suspendm_nxt <= '1';
            opmode_nxt <= "10";
            xcvrselect_nxt <= '1';
            termselect_nxt <= '1';
            txvalid_nxt <= '1';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_SW_WAKEUP_2 =>
         -- device asserts its own resume --
         -- releases  FS 'K' on the bus

            suspendm_nxt <= '1';
            opmode_nxt <= "10";
            xcvrselect_nxt <= '1';
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_SW_WAKEUP_3 =>

            suspendm_nxt <= '1';
            opmode_nxt <= "00"; -- back to normal mode (UTMI 4.1.5)
            xcvrselect_nxt <= '1';
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_HOST_RESUME =>

            suspendm_nxt <= '1';
            opmode_nxt <= "00";
            xcvrselect_nxt <= '1';
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_WF_EOR_FS => -- Wait for End of Reset FS

            suspendm_nxt <= '1';
            opmode_nxt <= "00";
            xcvrselect_nxt <= '1';
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_HS_DET_HSK_1 => -- High Speed Detection HandShake
           -- Device asserts Chirp K on the Bus
            suspendm_nxt <= '1';
            opmode_nxt <= "10";
            xcvrselect_nxt <= '0';
            termselect_nxt <= '1';
            txvalid_nxt <= '1';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_HS_DET_HSK_2 =>
            -- Device removes Chirp K from the Bus
            suspendm_nxt <= '1';
            opmode_nxt <= "10";
            xcvrselect_nxt <= '0';
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_HS_DET_HSK_3 =>
            -- Waiting for Chirp K
            suspendm_nxt <= '1';
            opmode_nxt <= "10";
            xcvrselect_nxt <= '0';
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_HS_DET_HSK_4 =>
            -- Waiting for Chirp J
            suspendm_nxt <= '1';
            opmode_nxt <= "10";
            xcvrselect_nxt <= '0';
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_WF_ENDCHIRP_HS => -- Wait for End of Reset HS
            suspendm_nxt <= '1';
            opmode_nxt <= "00";
            xcvrselect_nxt <= '0';
            termselect_nxt <= '0';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_LPM_SUSPEND_L1 =>
             -- clocks can be switched off
            suspendm_nxt <= usbreg_pll_on;
             opmode_nxt <= "00";
             xcvrselect_nxt <= '1';
             termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_LPM_SW_WAKEUP_WF_CLK =>
            -- device asserts its own resume
            -- PHY must be resumed asynchronously
            -- FS 'K' is not asserted yet
            suspendm_nxt <= '1';
             opmode_nxt <= "00";
            xcvrselect_nxt <= '1';
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

          when BUS_EVENT_LPM_SW_WAKEUP_1 =>
           -- device asserts its own resume (K is driven)
            suspendm_nxt <= '1';
            opmode_nxt <= "10";
             xcvrselect_nxt <= '1';
             termselect_nxt <= '1';
            txvalid_nxt <= '1';
            txdata_nxt <= (others => '0');

         when others => --BUS_EVENT_TEST_MODE
            case usbreg_phy_test_mode is

               when "001" =>  -- Test_J
                  suspendm_nxt <= '1';
                  opmode_nxt <= "10";
                  xcvrselect_nxt <= '0';
                  termselect_nxt <= '0';
                  txvalid_nxt <= '1';
                  txdata_nxt <= (others => '1');

               when "010" =>  -- Test_K
                   suspendm_nxt <= '1';
                   opmode_nxt <= "10";
                   xcvrselect_nxt <= '0';
                   termselect_nxt <= '0';
                   txvalid_nxt <= '1';
                   txdata_nxt <= (others => '0');

               when "011" =>  -- Test_SE0_NAK
                   suspendm_nxt <= '1';
                   opmode_nxt <= "00";
                   xcvrselect_nxt <= '0';
                   termselect_nxt <= '0';
                   txvalid_nxt <= txvalid_pkt_nxt; -- from packet_handling_fsm
                   txdata_nxt <=  txdata_pkt_nxt; -- from packet_handling_fsm

               when "100" =>  -- Test_Packet_data
                   suspendm_nxt <= '1';
                   opmode_nxt <= "00";
                    xcvrselect_nxt <= '0';
                    termselect_nxt <= '0';
                    txvalid_nxt <= txvalid_pkt_nxt; -- from packet_handling_fsm
                   txdata_nxt <=  txdata_pkt_nxt; -- from packet_handling_fsm


               when others =>
               -- default values
               end case;


         end case;

end process bus_event_to_phy_comb_proc;

-- Interface to the others modules
-- BVE : created a clocked process to prevent possible glitches when these signals go to the synchronizer module

bus_event_to_others_comb_proc : process (pie_clk,reset_n)
begin
  if reset_n = '0' then
    pie_busreset <= '0';
    pie_suspend <=  '0';
    pie_lpm_suspend <= '0';
  elsif pie_clk'event and pie_clk='1' then
    -- default values
    pie_busreset <= '0';
    pie_suspend <=  '0';
    pie_lpm_suspend <= '0';

    case bus_event_state_r is

      when BUS_EVENT_SUSPEND =>
        pie_suspend <= '1';

      when BUS_EVENT_WF_ENDCHIRP_HS|BUS_EVENT_WF_EOR_FS =>
        pie_busreset <= '1';

      when BUS_EVENT_LPM_SUSPEND_L1 =>
        pie_lpm_suspend <= '1';

      when others =>
        -- default values
        pie_busreset <= '0';
        pie_suspend <=  '0';
        pie_lpm_suspend <= '0';
    end case;
  end if;
end process bus_event_to_others_comb_proc;


pie_devicespeed <= '1' when dev_speed_r = USB_HIGH_SPEED else
                   '0';

pie_isotoggle <= isotoggle_r;

bus_event_decod_reg_clk_proc : process (pie_clk,reset_n)
begin
   if reset_n = '0' then
      dev_speed_r <= USB_FULL_SPEED;
   elsif pie_clk'event and pie_clk='1' then
      if set_dev_fs = '1' then
         dev_speed_r <= USB_FULL_SPEED;
      elsif set_dev_hs = '1' then
         dev_speed_r <= USB_HIGH_SPEED;
      end if;
   end if;
end process bus_event_decod_reg_clk_proc;


--------------------------------------------------------------
--------------------------------------------------------------
--               BUS EVENT HANDLING (end)                   --
--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------



--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------
--                USB PACKETS HANDLING (begin)              --
--------------------------------------------------------------
--------------------------------------------------------------

-- Low gate count strategy:
-- If a data/signal must be registered (e.g. handshake PID), instead of adding extra register
-- to store the info, we have added one state per case in the FSM.
-- By concentrating the "storage"in the FSM, the total nr of registers should be optimized

packet_handling_fsm_comb_proc : process(packet_handling_state_r,rxactive,rxvalid,rxerror,rxdata,pid_nxt,new_sof_vld,
epinfo_valid,epinfo_disabled,epinfo_toggle,epinfo_txdata_valid,req_handshake_r,timer_packet_handling_r,
crc5_valid_nxt,pid_r,epinfo_iso,epinfo_stall,epinfo_active,ep_r,txready,epinfo_nbytes,crc16_valid_nxt,ignore_data_r,data_byte_cnt,
txdata_req_r,dev_speed_r,epinfo_req_r,packetsize,epinfo_setup_r,iso_in_pending_r,iso_out_pending_r,iso_transact_cnt_down,
iso_mdata_cnt_up,bus_event_state_r,rxdata_16,usbreg_deviceenabled,usbreg_usbaddress,usbreg_usbaddress_tmp,wf_ext_token_packet_r,
usbreg_lpm_hird_sw,lpm_hird_hw_r,usbreg_lpm_nyet,usbreg_lpm_sup,usbreg_phy_test_mode,linkstate_r,lpm_init_valid_r,epinfo_maxpacket,
eop_rx,eop_tx,sop_start,sop_det_r)


-- DOC_BEGIN: Procedure SetError
    -- SetError generates an error of the specified type.
    procedure SetError(SetErrorType: T_PACKET_ERROR_enum) is
    begin

      case SetErrorType is
        when ERROR_NO_ERROR         => errortype <= "0000";
        when ERROR_PID_ENCODING     => errortype <= "0001";
        when ERROR_PID_UNKNOWN      => errortype <= "0010";
        when ERROR_PACKET_UNEXPECTED=> errortype <= "0011";
        when ERROR_TOKEN_CRC        => errortype <= "0100";
        when ERROR_DATA_CRC         => errortype <= "0101";
        when ERROR_TIMEOUT          => errortype <= "0110";
        when ERROR_BABBLE           => errortype <= "0111";
        when ERROR_TR_EOP           => errortype <= "1000";
        when ERROR_SENT_RECEIVED_NAK=> errortype <= "1001";
        when ERROR_SENT_STALL       => errortype <= "1010";
        when ERROR_OVERRUN          => errortype <= "1011";
        when ERROR_SENT_EMPTYPACK   => errortype <= "1100";
        when ERROR_BITSTUFF_ERROR   => errortype <= "1101";
        when ERROR_SYNC_ERROR       => errortype <= "1110";
        when others --Wrong data toggle
                                    => errortype <= "1111";
      end case;

      set_pie_error       <= '1';
      set_pie_endtransfer <= '1';
      clear_pie_success <= '1';
      clear_iso_in_pending <= '1';
      clear_iso_out_pending <= '1';
      clear_iso_transact_cnt_down <= '1';
      clear_iso_mdata_cnt_up <= '1';
      clear_wf_ext_token_packet <= '1';
      clear_sop_det <= '1';
      if SetErrorType = ERROR_SENT_RECEIVED_NAK then
        set_pie_sentNAK <= '1';
      end if;
    end;
  -- DOC_END

   variable DevAddrChecked   : boolean;
   variable var_address1     : std_logic_vector(6 downto 0);
   variable var_address2     : std_logic_vector(6 downto 0);
   variable v_over_run_size       : integer range 0 to MAX_DATA_PACKET_SIZE+2;
   variable v_nbytes_prev_packets : natural range 0 to MAX_DATA_PACKET_SIZE *2;
begin

-- default values
   packet_handling_state_nxt <= packet_handling_state_r;

   new_pid_vld <= '0';
   new_token_byte2_vld <= '0';
   new_token_byte3_vld <= '0';
   new_ext_token_byte2_vld <= '0';
   new_ext_token_byte3_vld <= '0';
   new_sof_vld         <= '0';
   new_inoutsetup_vld  <= '0';

   set_ignore_data <= '0';
   clear_ignore_data <= '0';
   clear_epinfo_req    <= '0';

   set_pie_sentNAK <= '0';
   clear_pie_sentNAK <= '0';
   set_pie_success <= '0'; -- pie_success should be updated together with pie_endtransfer rising edge.
   clear_pie_success <= '0';
   set_pie_endtransfer <= '0';
   clear_pie_endtransfer <= '0';

   set_pie_error       <= '0';
   clear_pie_error       <= '0';
   errortype <= "0000";

   data_byte_cnt_incr <= '0';
   data_byte_cnt_clear <= '0';

   decr_iso_transact_cnt_down <= '0';
   clear_iso_transact_cnt_down <= '0';
   load_iso_transact_cnt_down <= '0';

   clear_iso_mdata_cnt_up <= '0';
   incr_iso_mdata_cnt_up <= '0';

   data_fifo_fill_rx <= '0';
   data_fifo_fill_tx <= '0';
   clear_data_fifo   <= '0';

   set_rx_nbytes <= '0';
   rx_nbytes     <= (others => '0');

   set_req_handshake <= '0';
   clear_req_handshake <= '0';

   timer_packet_handling_nxt <= 0;
   reload_timer_packet_handling_nxt <= '0';

   set_iso_in_pending <= '0';
   clear_iso_in_pending <= '0';
   set_iso_out_pending <= '0';
   clear_iso_out_pending <= '0';

   set_wf_ext_token_packet <= '0';
   clear_wf_ext_token_packet <= '0';
   set_lpm_init_valid <= '0';
   clear_lpm_init_valid <= '0';
   set_lpm_wf_l1_state <= '0';

   moved_to_tx <= '0';
   clear_sop_det <= '0';


   v_over_run_size:=0;
   v_nbytes_prev_packets:= 0;
   if bus_event_state_r = BUS_EVENT_INIT then
      packet_handling_state_nxt <= USB_PROT_WF_IDLE;
-- ------------------
-- BVE : the SMS PHY keeps rxerror asserted during resume signaling until first sync is detected.
--       this makes that the first received token after resume is seen as an error.
--       to prevent this, it must only look at rxerror when both rxvalid and rxactive are also 1b
--   elsif rxerror = '1' then
   elsif rxerror = '1' and rxactive = '1' and rxvalid = '1' then
      packet_handling_state_nxt <= USB_PROT_WF_IDLE;
      clear_pie_success        <= '1';
      set_pie_endtransfer      <= '1';
      clear_epinfo_req    <= '1';
      clear_ignore_data  <= '1';
      clear_data_fifo    <= '1';
      clear_sop_det <= '1';
      data_byte_cnt_clear <= '1';
   else
      case packet_handling_state_r is
         when USB_PROT_WF_IDLE => -- waiting for the EOP
            if rxactive ='0' then
               clear_epinfo_req    <= '1';
               packet_handling_state_nxt <= USB_PROT_IDLE;
               clear_ignore_data  <= '1';
               clear_data_fifo    <= '1';
               clear_sop_det <= '1';
               data_byte_cnt_clear <= '1';
            end if;

         when USB_PROT_IDLE =>
            if bus_event_state_r = BUS_EVENT_TEST_MODE and usbreg_phy_test_mode = "100" then
               packet_handling_state_nxt <= USB_PROT_WF_TX_TEST_PACKET;
               data_byte_cnt_clear <= '1';
               clear_epinfo_req    <= '1';
               clear_ignore_data  <= '1';
               clear_data_fifo    <= '1';
               clear_pie_success <= '1';
               clear_iso_in_pending <= '1';
               clear_iso_out_pending <= '1';
               clear_iso_transact_cnt_down <= '1';
               clear_iso_mdata_cnt_up <= '1';
               clear_req_handshake <= '1';
               clear_pie_endtransfer <= '1';
               clear_pie_error <= '1';
               clear_wf_ext_token_packet <= '1';
               timer_packet_handling_nxt <= PACKET_TURNAROUND_TIMEOUT_HS-1;
               reload_timer_packet_handling_nxt <= '1';

            elsif req_handshake_r = '1' then  -- handshake is expected to be received from the host
               if timer_packet_handling_r = 0 then -- TIMEOUT : Start of packet of the Handshake is not received on time
                  SetError(ERROR_TIMEOUT);
                  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                  clear_req_handshake <= '1';
                  clear_pie_success        <= '1';
                  set_pie_endtransfer      <= '1';
               elsif sop_start = '1' then -- pulse event, start of packet is detected
                  packet_handling_state_nxt <= USB_PROT_IN_WF_RX_HANDSHAKE;
                  clear_req_handshake <= '1';
                  -- Timer is reloaded and is used to avoid the FSM stays stuck forever in the next state.
                  if dev_speed_r = USB_FULL_SPEED then
                     timer_packet_handling_nxt <= PACKET_EVENT_TIMEOUT_FS-1;
                  else
                     timer_packet_handling_nxt <= PACKET_EVENT_TIMEOUT_HS-1;
                  end if;
                  reload_timer_packet_handling_nxt <= '1';
               end if;

            elsif rxactive = '1' then   -- Token is expected to be received from the host,
               clear_pie_success        <= '1';
               clear_pie_endtransfer      <= '1';
               clear_pie_error <= '1';
               clear_pie_sentNAK          <= '1';
               if wf_ext_token_packet_r = '1' then
                  packet_handling_state_nxt <= USB_PROT_WF_EXT_TOKEN_PID;
               else
                  packet_handling_state_nxt <= USB_PROT_WF_TOKEN_PID;
               end if;
            end if;

         when USB_PROT_WF_TOKEN_PID =>  -- waiting For Token PID or PING PID or EXT PID
         -- no timeout to check, exit condition is covered with rxactive = 0
            if rxactive = '1' and rxvalid = '1' then
               if rxdata(7 downto 4) = not rxdata(3 downto 0) then -- chech for valid PID
                  case pid_nxt is
                     when PID_IN|PID_OUT|PID_SETUP|PID_SOF|PID_EXT =>
                        packet_handling_state_nxt <= USB_PROT_WF_TOKEN_BYTE2;
                        new_pid_vld <= '1';
                     when PID_PING =>
                        if dev_speed_r = USB_FULL_SPEED then -- FS device does not support PING Protocol and should not answer
                           SetError(ERROR_PID_UNKNOWN);
                           packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                        else
                           packet_handling_state_nxt <= USB_PROT_WF_TOKEN_BYTE2;
                           new_pid_vld <= '1';
                        end if;
                     when others => -- unexpected PID
                     --   SetError(ERROR_PID_UNKNOWN); -- Could be a SPLIT PID not relevant for the device. It is not an error
                        packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                  end case;
               else -- bad PID, Ignore the remainder packet
                  SetError(ERROR_PID_ENCODING);
                  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               end if;
            elsif rxactive = '0' then -- 1st byte is not sent, wrong start of packet
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               SetError(ERROR_TR_EOP);
            end if;

         when USB_PROT_WF_TOKEN_BYTE2 =>  -- waiting For 2nd Byte of the Token Packet
         -- (including crc5 check)
            if rxactive = '1' and rxvalid = '1' then
               new_token_byte2_vld <= '1';
               packet_handling_state_nxt <= USB_PROT_WF_TOKEN_BYTE3;
            elsif rxactive = '0' then -- no 2nd byte
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               SetError(ERROR_TR_EOP);
            end if;

         when USB_PROT_WF_TOKEN_BYTE3 =>  -- waiting For 3rd Byte of the Token Packet
                  -- (including crc5 check)
            if rxactive = '1' and rxvalid = '1' then
               new_token_byte3_vld <= '1';
               if crc5_valid_nxt = '1' then
                  case pid_r is
                     when PID_IN => -- IN data packet must be transmitted
                        if iso_out_pending_r = '0' then
                           packet_handling_state_nxt <= USB_PROT_IN_WF_EOP;
                           new_inoutsetup_vld <= '1';
                        else  -- PID_OUT was expected
                           SetError(ERROR_PACKET_UNEXPECTED);
                           packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                        end if;
                     when PID_OUT =>
                        if iso_in_pending_r = '0' then
                           packet_handling_state_nxt <= USB_PROT_OUT_SETUP_WF_EOP;
                           new_inoutsetup_vld <= '1';
                        else  -- PID_IN was expected
                           SetError(ERROR_PACKET_UNEXPECTED);
                           packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                        end if;

                     when PID_SETUP =>
                        if iso_in_pending_r = '0' and iso_out_pending_r = '0' then
                           packet_handling_state_nxt <= USB_PROT_OUT_SETUP_WF_EOP;
                           new_inoutsetup_vld <= '1';
                        else  -- PID_IN/PID_OUT was expected
                           SetError(ERROR_PACKET_UNEXPECTED);
                           packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                        end if;

                     when PID_PING =>
                        if iso_in_pending_r = '0' and iso_out_pending_r = '0' then
                           packet_handling_state_nxt <= USB_PROT_PING_WF_EOP;
                           new_inoutsetup_vld <= '1';
                        else-- PID_IN/PID_OUT was expected
                           SetError(ERROR_PACKET_UNEXPECTED);
                           packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                        end if;

                      when PID_EXT =>
                        -- loop through device address table (content search)
                        DevAddrChecked      := FALSE;
                        for i in 0 to C_NBDEV-1 loop
                          for j in 0 to 6 loop
                            var_address1(j) := usbreg_usbaddress(i*7+j);
                            var_address2(j) := usbreg_usbaddress_tmp(i*7+j);
                          end loop;
                          if (var_address1 = rxdata_16(6 downto 0)  or 
                              var_address2 = rxdata_16(6 downto 0)) and
                              usbreg_deviceenabled(i) = '1'           then
                            DevAddrChecked      := TRUE;
                          end if;
                        end loop;

                        if DevAddrChecked then 
                          set_wf_ext_token_packet <= '1';
                          packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                        end if;

                     when others => -- = PID_SOF
                        new_sof_vld <= '1';
                        clear_iso_in_pending <= '1';
                        clear_iso_out_pending <= '1';
                        clear_iso_transact_cnt_down <= '1';
                        clear_iso_mdata_cnt_up <= '1';
                        packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                        if iso_in_pending_r = '1' or iso_out_pending_r = '1' then
                        --PID_IN/PID_OUT was expected, SOF will clear all pending iso transactions.
                           SetError(ERROR_PACKET_UNEXPECTED);
                        end if;
                  end case;
               else  -- CRC5 not valid. Packet is ignore
                  SetError(ERROR_TOKEN_CRC);
                  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               end if;
            elsif rxactive = '0' then -- no 3rd byte
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               SetError(ERROR_TR_EOP);
            end if;

         when USB_PROT_IN_WF_EOP =>  -- waiting for End of Packet
            if rxactive = '0' then -- wait for EOP before starting inter-packet delay timer
               packet_handling_state_nxt <= USB_PROT_IN_WF_EP_INFO_VALID;
               if dev_speed_r = USB_FULL_SPEED then
                  timer_packet_handling_nxt <= INTER_PACKET_DELAY_FS-1;
                  reload_timer_packet_handling_nxt <= '1';
               else
                  timer_packet_handling_nxt <= INTER_PACKET_DELAY_HS-1;
                  reload_timer_packet_handling_nxt <= '1';
               end if;
            end if;

         when USB_PROT_IN_WF_EP_INFO_VALID => -- waiting for ep_info_valid signal is asserted
            if bus_event_state_r = BUS_EVENT_TEST_MODE and usbreg_phy_test_mode = "011" then-- -- Test_SE0_NAK
               -- NAK handshake must be returned
               packet_handling_state_nxt <= USB_PROT_IN_OUT_PING_WF_TX_NAK_HANDSHAKE;
               SetError(ERROR_SENT_RECEIVED_NAK);
            elsif epinfo_req_r = '0' then -- EP or address not valid
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
            elsif epinfo_valid = '1' then -- information from the DMA Handler is valid
               if epinfo_disabled = '1' then -- ep is disabled. no data nor hanshake must be returned
                  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                  clear_pie_success        <= '1';
                  set_pie_endtransfer      <= '1';
               elsif epinfo_iso = '1' then -- isochronous endpoint
                  if epinfo_active = '0' or epinfo_stall = '1' then
                     packet_handling_state_nxt <= USB_PROT_WF_IDLE; -- no handshake must be returned
                     clear_pie_success        <= '1';
                     set_pie_endtransfer      <= '1';
                  else
                     if iso_in_pending_r = '0' then -- first transaction
                        set_iso_in_pending <= '1';
                        load_iso_transact_cnt_down <='1';
                        data_byte_cnt_clear <= '1';
                        moved_to_tx <= '1';
                        packet_handling_state_nxt <= USB_PROT_IN_TX_DATA_PID_1;
                     else -- 2nd or 3rd transaction
                        data_byte_cnt_clear <= '1';
                        moved_to_tx <= '1';
                        packet_handling_state_nxt <= USB_PROT_IN_TX_DATA_PID_1;
                     end if;
                  end if;
               elsif epinfo_stall = '1' and epinfo_active = '0' then -- stall handshake must be returned
                  packet_handling_state_nxt <= USB_PROT_IN_OUT_PING_WF_TX_STALL_HANDSHAKE;
                  SetError(ERROR_SENT_STALL);
               elsif  epinfo_active = '0' then -- NAK handshake must be returned
                  packet_handling_state_nxt <= USB_PROT_IN_OUT_PING_WF_TX_NAK_HANDSHAKE;
                  SetError(ERROR_SENT_RECEIVED_NAK);
               else   -- normal operation --  minimum interpacket delay is guaranteed (no timer needed)
                  data_byte_cnt_clear <= '1';
                  moved_to_tx <= '1';
                  packet_handling_state_nxt <= USB_PROT_IN_TX_DATA_PID_1;
               end if;
            end if;

         when USB_PROT_OUT_SETUP_WF_EOP =>  -- waiting for End of Packet
            if eop_rx = '1' then -- EOP is reached, waiting for a Start of Packet
               packet_handling_state_nxt <= USB_PROT_OUT_SETUP_WF_EP_INFO_VALID;
               clear_sop_det <= '1';
               if dev_speed_r = USB_FULL_SPEED then
                  timer_packet_handling_nxt <= PACKET_TURNAROUND_TIMEOUT_FS-1;
               else
                  timer_packet_handling_nxt <= PACKET_TURNAROUND_TIMEOUT_HS-1;
               end if;
               reload_timer_packet_handling_nxt <= '1';
            end if;

         when USB_PROT_OUT_SETUP_WF_EP_INFO_VALID => -- waiting for ep_info_valid signal is asserted
            if epinfo_req_r = '0' then -- EP or address not valid, no need to wait for timeout
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
            elsif timer_packet_handling_r = 0 then -- TIMEOUT : Data Packet or epinfo_valid is not received on time
               SetError(ERROR_TIMEOUT);
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
            elsif sop_start = '1' and sop_det_r = '0' then
            -- Start of packet is detected (pulse event). Timer is reloaded.
            -- This time, it is used to avoid the FSM stays stuck forever in this state.
            -- Waiting for epinfo_valid and rxactive are asserted
               if dev_speed_r = USB_FULL_SPEED then
                  timer_packet_handling_nxt <= PACKET_EVENT_TIMEOUT_FS-1;
               else
                  timer_packet_handling_nxt <= PACKET_EVENT_TIMEOUT_HS-1;
               end if;
               reload_timer_packet_handling_nxt <= '1';
            end if;
            if rxactive= '1' then -- start of packet is/has been detected
               if rxvalid = '1' then -- 1st byte of the data packet is received before epinfo is valid
                  SetError(ERROR_OVERRUN);
                  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               elsif epinfo_req_r = '0' then -- EP or address not valid, remaining packet can be ignored
                  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               elsif epinfo_valid = '1' then -- information from the DMA Handler is valid
                  if epinfo_disabled = '1' then -- ep is disabled. no data nor hanshake must be returned (not possible for a SETUP token)
                     packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                     clear_pie_success        <= '1';
                     set_pie_endtransfer      <= '1';
                  elsif pid_r = PID_SETUP then -- ep must accept SETUP token
                     if (ep_r = ZERO4) then
                        packet_handling_state_nxt <= USB_PROT_OUT_SETUP_WF_RX_DATA_PID;
                     else
                     -- non control EP must ignore the transaction and return no response USB2.0 spec 8.4.6.4.
                       packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                         end if;
                  else -- A Data Packet is expected.
                     packet_handling_state_nxt <= USB_PROT_OUT_SETUP_WF_RX_DATA_PID;
                     if epinfo_stall = '1' or epinfo_active = '0' then
                        set_ignore_data <= '1'; -- data won't be transferred to the dma handler but crc computation is still performed.
                     end if;
                     if epinfo_iso = '1' then -- isochronous endpoint
                        if iso_out_pending_r = '0' then -- first transaction
                             set_iso_out_pending <= '1';
                             load_iso_transact_cnt_down <='1';  -- max number of transactions per (u)frame
                        end if;
                     end if;
                  end if;
               end if;
            end if;

         when USB_PROT_PING_WF_EOP =>  -- waiting for End of Packet
            if rxactive = '0' then -- wait for EOP before starting inter-packet delay timer
               packet_handling_state_nxt <= USB_PROT_PING_WF_EP_INFO_VALID;
               timer_packet_handling_nxt <= INTER_PACKET_DELAY_HS-1; -- PING, only for HS devices
               reload_timer_packet_handling_nxt <= '1';
            end if;

         when USB_PROT_PING_WF_EP_INFO_VALID => -- waiting for ep_info_valid signal is asserted
            if epinfo_req_r = '0' then -- EP or address not valid
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
            elsif epinfo_valid = '1' then -- information from the DMA Handler is valid
               if epinfo_disabled = '1' or epinfo_iso = '1' then
               -- ep is disabled or this ep cannot support PING.
               --no data nor hanshake must be returned
                  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                  clear_pie_success        <= '1';
                  set_pie_endtransfer      <= '1';
               elsif epinfo_stall = '1' and epinfo_active = '0' then -- stall handshake must be returned
                  packet_handling_state_nxt <= USB_PROT_IN_OUT_PING_WF_TX_STALL_HANDSHAKE;
                  SetError(ERROR_SENT_STALL);
               elsif  epinfo_active = '0' then -- NAK handshake must be returned
                  packet_handling_state_nxt <= USB_PROT_IN_OUT_PING_WF_TX_NAK_HANDSHAKE;
                  SetError(ERROR_SENT_RECEIVED_NAK);
               else   -- Endpoint has space for a MaxPacketSize data payload
                  packet_handling_state_nxt <= USB_PROT_OUT_SETUP_PING_WF_TX_ACK_HANDSHAKE;
                  clear_pie_success        <= '1';
                  set_pie_endtransfer      <= '1';
               end if;
            end if;

         when USB_PROT_OUT_SETUP_PING_WF_TX_ACK_HANDSHAKE => -- wait for interpacket delay expires
            if timer_packet_handling_r = 0 then
               packet_handling_state_nxt <= USB_PROT_OUT_SETUP_PING_TX_ACK_HANDSHAKE;
            end if;

         when USB_PROT_OUT_SETUP_PING_TX_ACK_HANDSHAKE => -- HandShake Packet is only one byte
            if txready = '1' then
               packet_handling_state_nxt <= USB_PROT_ALL_WF_END_TX_PACKET;
            end if;

         when USB_PROT_OUT_WF_TX_NYET_HANDSHAKE => -- wait for interpacket delay expires
            if timer_packet_handling_r = 0 then
               packet_handling_state_nxt <= USB_PROT_OUT_TX_NYET_HANDSHAKE;
            end if;

         when USB_PROT_OUT_TX_NYET_HANDSHAKE => -- HandShake Packet is only one byte
            if txready = '1' then
               packet_handling_state_nxt <= USB_PROT_ALL_WF_END_TX_PACKET;
            end if;

         when USB_PROT_IN_OUT_PING_WF_TX_NAK_HANDSHAKE => -- wait for interpacket delay expires
            if timer_packet_handling_r = 0 then
               packet_handling_state_nxt <= USB_PROT_IN_OUT_PING_TX_NAK_HANDSHAKE;
            end if;

         when USB_PROT_IN_OUT_PING_TX_NAK_HANDSHAKE => -- HandShake Packet is only one byte
             if txready = '1' then
                packet_handling_state_nxt <= USB_PROT_ALL_WF_END_TX_PACKET;
             end if;

         when USB_PROT_IN_OUT_PING_WF_TX_STALL_HANDSHAKE => -- wait for interpacket delay expires
            if timer_packet_handling_r = 0 then
               packet_handling_state_nxt <= USB_PROT_IN_OUT_PING_TX_STALL_HANDSHAKE;
            end if;

         when USB_PROT_IN_OUT_PING_TX_STALL_HANDSHAKE => -- HandShake Packet is only one byte
              if txready = '1' then
                 packet_handling_state_nxt <= USB_PROT_ALL_WF_END_TX_PACKET;
             end if;

         when USB_PROT_ALL_WF_END_TX_PACKET =>
            if eop_tx = '1' then  --  Wait Until the EOP
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               if lpm_init_valid_r = '1' then -- LPM
                  set_lpm_wf_l1_state <= '1'; -- BUS_EVENT FSM will wait for T_L1_Token_Retry time before moving to LPM suspend state L1
                  clear_lpm_init_valid <= '1'; -- ACK has been transmitted by the device
               end if;
               if req_handshake_r = '1' then -- handshake from host is expected, start timeout timer
                  if dev_speed_r = USB_FULL_SPEED then
                     timer_packet_handling_nxt <= PACKET_TURNAROUND_TIMEOUT_FS-1;
                  else
                     timer_packet_handling_nxt <= PACKET_TURNAROUND_TIMEOUT_HS-1;
                  end if;
                  reload_timer_packet_handling_nxt <= '1';
               end if;
            end if;

         when USB_PROT_OUT_SETUP_WF_RX_DATA_PID =>    -- Waiting for the DATA PID sent by the host
            if rxactive = '1' and rxvalid = '1' then
               if rxdata(7 downto 4) = not rxdata(3 downto 0) then
                  new_pid_vld <= '1';
                  if iso_out_pending_r = '1' then -- isochronous endpoint
                     case pid_nxt is
                        when PID_MDATA => --high BW iso only, it cannot be the last transaction
                           if iso_transact_cnt_down = "00" or iso_mdata_cnt_up = "10" then
                              -- (for a FS ep, this PID is not expected,  since iso_transact_cnt_down is always = "00", check is implicit)
                              -- a 3rd MDATA transaction is not possible whatever epinfo_nbytes
                              --unexpected PID: ignore the remainder packet,
                              -- all the data transferred during the uframe must be treated as if it had encountered an error
                              SetError(ERROR_PID_UNKNOWN);
                              packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                           else
                              packet_handling_state_nxt <= USB_PROT_OUT_SETUP_RCV_DATA_PACKET;
                              data_byte_cnt_clear <= '1';
                              incr_iso_mdata_cnt_up <= '1';
                           end if;

                        when PID_DATA2 => --high BW iso only, it can only be the last transaction of 3 after receiving 2 valid MDATA transactions
                           if dev_speed_r = USB_FULL_SPEED or iso_mdata_cnt_up /= "10"then -- unexpected PID
                           --unexpected PID: ignore the remainder packet,
                           -- all the data transferred during the uframe must be treated as if it had encountered an error
                              SetError(ERROR_PID_UNKNOWN);
                                packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                             else
                              packet_handling_state_nxt <= USB_PROT_OUT_SETUP_RCV_DATA_PACKET;
                              clear_iso_transact_cnt_down <= '1'; -- it is the last transaction of 3
                                data_byte_cnt_clear <= '1';
                           end if;

                        when PID_DATA1 =>
                        -- in FS iso , PID_DATA1 is not expected but must be accepted,
                        -- in High BW iso, it can only be the last transaction of 2 (after receiving 1 valid MDATA transaction)
                           if iso_mdata_cnt_up /= "01" and dev_speed_r = USB_HIGH_SPEED then -- unexpected PID
                           --unexpected PID: ignore the remainder packet,
                           -- all the data transferred during the uframe must be treated as if it had encountered an error
                              SetError(ERROR_PID_UNKNOWN);
                              packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                           else
                              packet_handling_state_nxt <= USB_PROT_OUT_SETUP_RCV_DATA_PACKET;
                              clear_iso_transact_cnt_down <= '1'; -- it is the last transaction of 2
                              data_byte_cnt_clear <= '1';
                           end if;

                        when PID_DATA0 =>
                           -- in High BW iso, it can only be the single transaction
                           if iso_mdata_cnt_up   /= "00" then -- unexpected PID
                           --unexpected PID: ignore the remainder packet,
                           -- all the data transferred during the uframe must be treated as if it had encountered an error
                              SetError(ERROR_PID_UNKNOWN);
                              packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                           else
                              packet_handling_state_nxt <= USB_PROT_OUT_SETUP_RCV_DATA_PACKET;
                              clear_iso_transact_cnt_down <= '1'; -- it is the last transaction of 1
                              data_byte_cnt_clear <= '1';
                           end if;

                        when others => --unexpected PID
                           SetError(ERROR_PID_UNKNOWN); -- TO BE CHECKED
                           packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                        end case;

                  else -- non isochronous endpoint
                  -- expecting DATA0 or DATA1 PID
                  case pid_nxt is
                        when PID_DATA1 =>
                           if epinfo_toggle='0' then
                           -- data packet will be ignored but packet will be ACKed
                           --(sequence bits of both host and device will be again synchro)
                              set_ignore_data <= '1';
                           end if;
                           packet_handling_state_nxt <= USB_PROT_OUT_SETUP_RCV_DATA_PACKET;
                           data_byte_cnt_clear <= '1';
                        when PID_DATA0 =>
                           if epinfo_toggle='1' and epinfo_setup_r='0' then
                           -- Setup is always received with DATA0
                           -- data packet will be ignored but packet will be ACKed
                           --(sequence bits of both host and device will be again synchro)
                              set_ignore_data <= '1';
                           end if;
                           packet_handling_state_nxt <= USB_PROT_OUT_SETUP_RCV_DATA_PACKET;
                           data_byte_cnt_clear <= '1';

                        when others => --unexpected PID, ignore the remainder packet
                           SetError(ERROR_PID_UNKNOWN); -- TO BE CHECKED
                           packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                        end case;
                  end if;
               else  -- bad PID, Ignore the remainder packet
                  SetError(ERROR_PID_ENCODING);
                  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               end if;
            elsif rxactive= '0' then  -- Unexpected EOP
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               SetError(ERROR_TR_EOP);
            end if;


         when USB_PROT_OUT_SETUP_RCV_DATA_PACKET => -- crc16 computing has started

            v_over_run_size:= to_integer(packetsize)+2; -- v_over_run_size takes into account the 2 CRC16 bytes

            if rxactive ='0' then -- EOP is detected, CRC16 should be valid

               if epinfo_stall = '1' and epinfo_active = '0' and crc16_valid_nxt = '1' then -- stall handshake must be returned
                 -- if rxactive = '0' then -- wait for EOP before starting inter-packet delay timer
                  if iso_out_pending_r = '0' then -- non isochronous ep
                     packet_handling_state_nxt <= USB_PROT_IN_OUT_PING_WF_TX_STALL_HANDSHAKE;
                     SetError(ERROR_SENT_STALL);
                     if dev_speed_r = USB_FULL_SPEED then
                        timer_packet_handling_nxt <= INTER_PACKET_DELAY_FS-1;
                        reload_timer_packet_handling_nxt <= '1';
                     else
                        timer_packet_handling_nxt <= INTER_PACKET_DELAY_HS-1;
                        reload_timer_packet_handling_nxt <= '1';
                     end if;
                  else -- isochronous ep -- no handshake is returned. Data packet is not treated
                     SetError(ERROR_PACKET_UNEXPECTED);
                     packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                  end if;
                 -- end if;

               elsif  epinfo_active = '0' and crc16_valid_nxt = '1' then
                 -- NAK handshake must be returned after the data packet (epinfo_active is always ='1' for setup)
                 -- if rxactive = '0' then -- wait for EOP before starting inter-packet delay timer
                  if iso_out_pending_r = '0' then -- non isochronous ep
                     packet_handling_state_nxt <= USB_PROT_IN_OUT_PING_WF_TX_NAK_HANDSHAKE;
                     SetError(ERROR_SENT_RECEIVED_NAK);
                     if dev_speed_r = USB_FULL_SPEED then
                         timer_packet_handling_nxt <= INTER_PACKET_DELAY_FS-1;
                         reload_timer_packet_handling_nxt <= '1';
                     else
                        timer_packet_handling_nxt <= INTER_PACKET_DELAY_HS-1;
                        reload_timer_packet_handling_nxt <= '1';
                     end if;
                  else -- isochronous ep -- no handshake is returned. Data packet is not treated
                     SetError(ERROR_PACKET_UNEXPECTED);
                     packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                  end if;
                 -- end if;
               elsif crc16_valid_nxt = '1' then
                  if iso_out_pending_r = '0' then -- non isochronous ep : packet will be ACKed
                     if dev_speed_r = USB_FULL_SPEED then
                        timer_packet_handling_nxt <= INTER_PACKET_DELAY_FS-1;
                        reload_timer_packet_handling_nxt <= '1';
                        packet_handling_state_nxt <= USB_PROT_OUT_SETUP_PING_WF_TX_ACK_HANDSHAKE;
                     else
                        timer_packet_handling_nxt <= INTER_PACKET_DELAY_HS-1;
                        reload_timer_packet_handling_nxt <= '1';
                        if unsigned(epinfo_nbytes) <= packetsize and epinfo_setup_r ='0' and epinfo_maxpacket(1) ='0' then
                        -- if unsigned(epinfo_nbytes) = packetsize is equivalent to < or = max packet size,
                        -- epinfo_maxpacket(1) ='0' means neither iso neither HS Interrupt
                           packet_handling_state_nxt <= USB_PROT_OUT_WF_TX_NYET_HANDSHAKE;
                        else
                           packet_handling_state_nxt <= USB_PROT_OUT_SETUP_PING_WF_TX_ACK_HANDSHAKE;
                        end if;
                     end if;
                     if ignore_data_r ='0' then
                        set_pie_success        <= '1';
                        set_pie_endtransfer    <= '1';
                        set_rx_nbytes <= '1';
                        rx_nbytes      <=  std_logic_vector(data_byte_cnt(11 downto 0)-2); -- nr of data bytes = data_byte counter - 2 bytes of CRC16
                     else
                       SetError(ERROR_DATA_IGNORED_WRONG_DATA01);
                     end if;
                  else -- isochronous ep -- no handshake is returned. Data packet is treated
                     if iso_transact_cnt_down  = "00" then -- last valid iso transaction
                        clear_iso_out_pending   <= '1';
                        clear_iso_mdata_cnt_up <= '1';
                        if ignore_data_r ='0' then
                           set_pie_success   <= '1';
                        else
                           clear_pie_success <= '1';
                        end if;
                        set_pie_endtransfer    <= '1';
                        -- nr of data bytes = data_byte counter - 2 bytes of CRC16 + nr of transactions MDATA* max packet size
                        set_rx_nbytes <= '1';
                        v_nbytes_prev_packets:= MAX_DATA_PACKET_SIZE * to_integer(iso_mdata_cnt_up);
                        rx_nbytes      <=  std_logic_vector(data_byte_cnt(11 downto 0)-2 + to_unsigned(v_nbytes_prev_packets,12));
                        packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                     else -- valid iso transaction, not the last one
                        decr_iso_transact_cnt_down  <= '1';
                        packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                     end if;

                  end if;

               else  --  BAD CRC: Data Packet Corrupted , no  hanshake is returned
                  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                  SetError(ERROR_DATA_CRC);
               end if;

            elsif rxvalid = '1' and ignore_data_r ='0' then  -- 1 data byte is ready and PIE can accept it
               if to_integer(data_byte_cnt) < v_over_run_size then -- prevent buffer overflow
                  data_byte_cnt_incr <= '1';
                  data_fifo_fill_rx  <= '1';
               else
                  SetError(ERROR_OVERRUN);
               end if;
            end if;

         when USB_PROT_IN_TX_DATA_PID_1 =>
            -- pid byte must be driven until txready is high
            if epinfo_txdata_valid ='1' and txready = '0' then
               data_fifo_fill_tx <= '1'; -- first data is available
               packet_handling_state_nxt <= USB_PROT_IN_TX_DATA_PID_2;
            elsif txready = '1' then  -- empty packet or buffer underrun
                 -- DATAx PID is sent
               if to_integer(packetsize) = 0 then -- empty packet to transmit
                  packet_handling_state_nxt <= USB_PROT_IN_TX_CRC16_BYTE1;
               else
                   -- buffer underrun error, PIE will corrupt the CRC
                 packet_handling_state_nxt <= USB_PROT_BAD_IN_TX_CRC16_BYTE1;
                 SetError(ERROR_TIMEOUT);
               end if;
            end if;

         when USB_PROT_IN_TX_DATA_PID_2 =>
            if txready = '1' then
            -- DATAx PID is sent
               if to_integer(packetsize) = 0 then -- empty packet to transmit
                  packet_handling_state_nxt <= USB_PROT_IN_TX_CRC16_BYTE1;
               else -- non empty packet must be transmit
                  data_byte_cnt_incr <= '1';
                  packet_handling_state_nxt <= USB_PROT_IN_TX_DATA_PACKET;
               end if;
            end if;

         when USB_PROT_IN_TX_DATA_PACKET => -- CRC16 computing has started
            if txready = '1' then  -- data must be sent to the PHY
               if ("000" & data_byte_cnt) < packetsize then
                  data_byte_cnt_incr <= '1';
               else -- end of packet to transmit, generate CRC16 bytes
                  packet_handling_state_nxt <= USB_PROT_IN_TX_CRC16_BYTE1;
               end if;
            end if;
            if txdata_req_r = '1' then -- request time for a new data from DMA
               if epinfo_txdata_valid ='1' then  -- data is available from dma
                  data_fifo_fill_tx <= '1';
               else -- buffer underrun error, PIE will corrupt the CRC
                  packet_handling_state_nxt <= USB_PROT_BAD_IN_TX_CRC16_BYTE1;
                  SetError(ERROR_TIMEOUT);
               end if;
            end if;

         when USB_PROT_IN_TX_CRC16_BYTE1 =>
            if txready = '1' then
               packet_handling_state_nxt <= USB_PROT_IN_TX_CRC16_BYTE2;
            end if;

         when USB_PROT_IN_TX_CRC16_BYTE2 =>
            if txready = '1' then
               packet_handling_state_nxt <= USB_PROT_ALL_WF_END_TX_PACKET;
               if epinfo_iso ='0' then
                  set_req_handshake <= '1';
               elsif iso_transact_cnt_down  = "00" then -- last transaction
                  clear_iso_in_pending <= '1';
                  -- in iso, transfer is finished with the last transmitted byte (no handshake expected)
                  set_pie_success        <= '1';
                  set_pie_endtransfer    <= '1';
                else
                   decr_iso_transact_cnt_down  <= '1';
               end if;
            end if;

         when USB_PROT_BAD_IN_TX_CRC16_BYTE1 =>
            if txready = '1' then
               packet_handling_state_nxt <= USB_PROT_BAD_IN_TX_CRC16_BYTE2;
            end if;

         when USB_PROT_BAD_IN_TX_CRC16_BYTE2 =>
         -- in iso mode, even if the current transaction won't be handled by the host (because of buffer underrun)
         -- remaining transactions can still be handled by the host
             if txready = '1' then
                packet_handling_state_nxt <= USB_PROT_ALL_WF_END_TX_PACKET;
                if epinfo_iso ='0' then
                   clear_pie_success        <= '1';
                   set_pie_endtransfer    <= '1';
                elsif iso_transact_cnt_down  = "00" then -- last transaction
                   clear_iso_in_pending <= '1';
                   clear_pie_success        <= '1';
                   set_pie_endtransfer    <= '1';
                else
                   decr_iso_transact_cnt_down  <= '1';
               end if;
            end if;


         when USB_PROT_IN_WF_RX_HANDSHAKE => -- only ACK handshake or No reply (==> detected via timeout) are expected behaviours
            if timer_packet_handling_r = 0 then  -- TIMEOUT : no answer from host means data error
               SetError(ERROR_TIMEOUT);          -- timeout is still taken into account in case of rxvalid would never be set.
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               clear_req_handshake <= '1';
               clear_pie_success        <= '1';
               set_pie_endtransfer    <= '1';
            elsif rxactive = '1' and rxvalid = '1' then
               if rxdata(7 downto 4) = not rxdata(3 downto 0) then -- chech for valid PID
                  case pid_nxt is
                     when PID_ACK =>
                        packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                        set_pie_success        <= '1';
                        set_pie_endtransfer    <= '1';
                     when others => -- unexpected PID
                        SetError(ERROR_PID_UNKNOWN); -- TO BE CHECKED
                        packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                        clear_pie_success        <= '1';
                        set_pie_endtransfer    <= '1';
                   end case;
               else -- bad PID, Ignore the remainder packet
                   SetError(ERROR_PID_ENCODING);
                   packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                   clear_pie_success        <= '1';
                   set_pie_endtransfer    <= '1';
               end if;
            end if;

       when USB_PROT_TX_TEST_PACKET => -- transmit test packet
            if txready = '1' then  -- data must be sent to the PHY
                   if data_byte_cnt < TESTPACKET_SIZE then
                  data_byte_cnt_incr <= '1';
               else -- end of test packet to transmit
                  data_byte_cnt_clear <= '1';
                  packet_handling_state_nxt <= USB_PROT_WF_END_TX_TEST_PACKET;
               end if;
            end if;

         when USB_PROT_WF_END_TX_TEST_PACKET =>
            if txready = '0' then  --  Wait Until the EOP
               packet_handling_state_nxt <= USB_PROT_WF_TX_TEST_PACKET;
               timer_packet_handling_nxt <= PACKET_TURNAROUND_TIMEOUT_HS-1;
               reload_timer_packet_handling_nxt <= '1';
            end if;

         when USB_PROT_WF_TX_TEST_PACKET => -- test packet mode:  send the same packet repetively. Interpacket delay is still required.
            if bus_event_state_r /= BUS_EVENT_TEST_MODE then
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
            elsif timer_packet_handling_r = 0 then
               if data_byte_cnt < TESTPACKET_SIZE-1 then -- not really required,, data_byte_cnt should be reset before jumping to this state
                  data_byte_cnt_incr <= '1';
               end if;
               packet_handling_state_nxt <= USB_PROT_TX_TEST_PACKET;
            end if;


         when USB_PROT_WF_EXT_TOKEN_PID =>  -- waiting For SubPID
            if rxactive = '1' and rxvalid = '1' then
               if rxdata(7 downto 4) = not rxdata(3 downto 0) then -- chech for valid SubPID
                  case pid_nxt is
                  when SUB_PID_LPM => -- LPM Token is the only SubPid supported
                     packet_handling_state_nxt <= USB_PROT_WF_EXT_TOKEN_BYTE2;
                     new_pid_vld <= '1';

                  when others => -- unexpected PID
                     SetError(ERROR_PID_UNKNOWN);
                      packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                  end case;
               else -- bad PID, Ignore the remainder packet
                  SetError(ERROR_PID_ENCODING);
                  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               end if;
            end if;

         when USB_PROT_WF_EXT_TOKEN_BYTE2 =>  -- waiting For 2nd Byte of the Extended Token Packet
                  -- (including crc5 check)
            if rxactive = '1' and rxvalid = '1' then
               new_ext_token_byte2_vld <= '1';
               packet_handling_state_nxt <= USB_PROT_WF_EXT_TOKEN_BYTE3;
            elsif rxactive = '0' then -- no 2nd byte
               clear_wf_ext_token_packet <= '1'; -- host has to resend Token + Extended Token
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
            end if;

         when USB_PROT_WF_EXT_TOKEN_BYTE3 =>  -- waiting For 3rd Byte of the Extended Token Packet
                           -- (including crc5 check)
            if rxactive = '1' and rxvalid = '1' then
               new_ext_token_byte3_vld <= '1';
               clear_wf_ext_token_packet <= '1';
               if crc5_valid_nxt = '1' then
                  if dev_speed_r = USB_FULL_SPEED then
                     timer_packet_handling_nxt <= INTER_PACKET_DELAY_FS-1;
                     reload_timer_packet_handling_nxt <= '1';
                  else
                     timer_packet_handling_nxt <= INTER_PACKET_DELAY_HS-1;
                     reload_timer_packet_handling_nxt <= '1';
                  end if;
                  if (usbreg_lpm_hird_sw > lpm_hird_hw_r) or usbreg_lpm_nyet= '1' then
                     packet_handling_state_nxt <= USB_PROT_OUT_WF_TX_NYET_HANDSHAKE;
                  elsif usbreg_lpm_sup = '0' or linkstate_r /= LINKSTATE_L1 then
                     packet_handling_state_nxt <= USB_PROT_IN_OUT_PING_WF_TX_STALL_HANDSHAKE;
                  else
                     packet_handling_state_nxt <= USB_PROT_OUT_SETUP_PING_WF_TX_ACK_HANDSHAKE;
                     set_lpm_init_valid <= '1';
                  end if;
                else  -- CRC5 not valid. Packet is ignore
                   SetError(ERROR_TOKEN_CRC);
                   packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                end if;
             elsif rxactive = '0' then -- no 3rd byte
                packet_handling_state_nxt <= USB_PROT_WF_IDLE;
            end if;


         when others =>
            packet_handling_state_nxt <= USB_PROT_WF_IDLE;
      end case;
   end if;
end process packet_handling_fsm_comb_proc;


packet_handling_fsm_clk_proc : process (pie_clk,reset_n)
begin
   if reset_n = '0' then
      packet_handling_state_r <= USB_PROT_IDLE;

   elsif pie_clk'event and pie_clk='1' then
      packet_handling_state_r <= packet_handling_state_nxt;
   end if;
end process packet_handling_fsm_clk_proc;


packet_handling_to_phy_comb_proc : process(packet_handling_state_nxt,data_byte_cnt,epinfo_toggle,data_fifo_r,
crc16_result_r,data_fifo_previous_byte_r,keepprevdata_r,txready,txready_r,iso_transact_cnt_down ,iso_in_pending_r,
moved_to_tx,moved_to_tx_d,moved_to_tx_dd,moved_to_tx_ddd)

variable v_offset_in_bits : natural range 0 to USB_DATAWIDTH-8;-- if USB_DATAWIDTH=128 bits, max v_offset_in_bits= 120

begin
-- if USB_DATAWIDTH=128 bits,USB_DATAWIDTH_IN_BYTES = 16, max v_offset_in_bits= 120, only 4 lsb of data_byte_cnt are used
   v_offset_in_bits:= 8*(to_integer(data_byte_cnt(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0)));
-- default values
       txvalid_pkt_nxt <= '0';
       txdata_pkt_nxt <= (others => '0');

      case packet_handling_state_nxt is

         when USB_PROT_WF_IDLE => -- waiting for the EOP

         when USB_PROT_IDLE =>

         when USB_PROT_WF_TOKEN_PID =>  -- waiting For PID

         when USB_PROT_WF_TOKEN_BYTE2 =>  -- waiting For 2nd Byte of the Token Packet
         -- (including crc5 check)

         when USB_PROT_WF_TOKEN_BYTE3 =>  -- waiting For 3rd Byte of the Token Packet
                  -- (including crc5 check)

         when USB_PROT_IN_WF_EOP =>  -- waiting for End of Packet

         when USB_PROT_IN_WF_EP_INFO_VALID => -- waiting for ep_info_valid signal is asserted

         when USB_PROT_OUT_SETUP_WF_EOP =>  -- waiting for End of Packet

         when USB_PROT_OUT_SETUP_WF_EP_INFO_VALID => -- waiting for ep_info_valid signal is asserted

         when USB_PROT_PING_WF_EOP =>  -- waiting for End of Packet

         when USB_PROT_PING_WF_EP_INFO_VALID => -- waiting for ep_info_valid signal is asserted

         --when USB_PROT_WF_TX_HANDSHAKE => -- device will reply with Handshake. Wait for Bus Idle

         when USB_PROT_OUT_SETUP_PING_TX_ACK_HANDSHAKE => -- HandShake Packet is only one byte
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= generate_pid_byte(PID_ACK);

         when USB_PROT_OUT_TX_NYET_HANDSHAKE => -- HandShake Packet is only one byte
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= generate_pid_byte(PID_NYET);

         when USB_PROT_IN_OUT_PING_TX_NAK_HANDSHAKE => -- HandShake Packet is only one byte
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= generate_pid_byte(PID_NAK);

         when USB_PROT_IN_OUT_PING_TX_STALL_HANDSHAKE => -- HandShake Packet is only one byte
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= generate_pid_byte(PID_STALL);

         when USB_PROT_ALL_WF_END_TX_PACKET => --
            txvalid_pkt_nxt<= '0';
            txdata_pkt_nxt <= (others => '0');

         when USB_PROT_IN_TX_DATA_PID_1 =>
          if C_EXTEND_TX_DELAY then
             if ((moved_to_tx = '0') and (moved_to_tx_d = '0') and
                          (moved_to_tx_dd = '0') and (moved_to_tx_ddd = '0') ) then
                txvalid_pkt_nxt<= '1';
             end if;
          elsif ((moved_to_tx = '0') and (moved_to_tx_d = '0')) then
            txvalid_pkt_nxt<= '1';
          end if;
            if iso_in_pending_r = '1' then -- Isochronous transaction only
               case iso_transact_cnt_down  is
                  when "00" =>
                     txdata_pkt_nxt <= generate_pid_byte(PID_DATA0);
                  when "01" =>
                     txdata_pkt_nxt <= generate_pid_byte(PID_DATA1);
                  when others => -- = "10". "11" is not allowed
                     txdata_pkt_nxt <= generate_pid_byte(PID_DATA2);
               end case;
            elsif epinfo_toggle='0' then
               txdata_pkt_nxt <= generate_pid_byte(PID_DATA0);
            else
               txdata_pkt_nxt <= generate_pid_byte(PID_DATA1);
            end if;

         when USB_PROT_IN_TX_DATA_PID_2 =>
            txvalid_pkt_nxt<= '1';
            if iso_in_pending_r = '1' then -- Isochronous transaction only
               case iso_transact_cnt_down  is
                  when "00" =>
                     txdata_pkt_nxt <= generate_pid_byte(PID_DATA0);
                  when "01" =>
                     txdata_pkt_nxt <= generate_pid_byte(PID_DATA1);
                  when others => -- = "10". "11" is not allowed
                     txdata_pkt_nxt <= generate_pid_byte(PID_DATA2);
               end case;
            elsif epinfo_toggle='0' then
               txdata_pkt_nxt <= generate_pid_byte(PID_DATA0);
            else
               txdata_pkt_nxt <= generate_pid_byte(PID_DATA1);
            end if;

         when USB_PROT_IN_TX_DATA_PACKET =>
            txvalid_pkt_nxt<= '1';
            if txready = '1' and txready_r ='0' and keepprevdata_r ='1' then
               txdata_pkt_nxt <= data_fifo_previous_byte_r;
            else
               txdata_pkt_nxt <= data_fifo_r(v_offset_in_bits + 7 downto v_offset_in_bits);
            end if;
         when USB_PROT_IN_TX_CRC16_BYTE1 =>
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= not bit_reverse8(crc16_result_r(15 downto 8));

         when USB_PROT_IN_TX_CRC16_BYTE2 =>
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= not bit_reverse8(crc16_result_r(7 downto 0));

         when USB_PROT_BAD_IN_TX_CRC16_BYTE1 =>
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= bit_reverse8(crc16_result_r(15 downto 8)); -- by not inverting CRC, we are sure a bad crc is sent

         when USB_PROT_BAD_IN_TX_CRC16_BYTE2 =>
             txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= bit_reverse8(crc16_result_r(7 downto 0)); -- by not inverting CRC, we are sure a bad crc is sent

         when USB_PROT_IN_WF_RX_HANDSHAKE =>

         when USB_PROT_TX_TEST_PACKET => -- transmit test packet
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= std_logic_vector(test_paket_decod (data_byte_cnt(5 downto 0)));

         when USB_PROT_WF_END_TX_TEST_PACKET =>

         when USB_PROT_WF_TX_TEST_PACKET =>

         when others =>

      end case;
end process packet_handling_to_phy_comb_proc;


-- packets and signals that need to be registered
packet_reg_clk_proc : process (pie_clk,reset_n)
variable v_offset_in_bits : natural range 0 to USB_DATAWIDTH-8;
variable DevAddrEnabled   : boolean;
variable var_address1     : std_logic_vector(6 downto 0);
variable var_address2     : std_logic_vector(6 downto 0);
variable var_epinfo_setup : std_logic;
begin

   if reset_n = '0' then
      rxactive_r <= '0';
      pid_r <= (others => '0');
      rxdata_r <= (others => '0'); -- TO BE CHECKED: could be replaced by data_fifo_r
      ep_r <= (others => '0');
      epinfo_req_r            <= '0';
      epinfo_epnr_r           <= (others => '0');
      epinfo_epdir_r          <= '0';
      epinfo_setup_r          <= '0';
      epinfo_setup_ok_r       <= '0';
      var_epinfo_setup        := '0';
      usbaddress_r            <= (others => '0');
      ignore_data_r           <= '0';
      crc16_result_r          <= (others => '1'); -- crc intermediate result must be registered
      -- initial crc16_result_r = PRELOAD CRC
      req_handshake_r  <= '0';
      data_fifo_r <= (others => '0');
      data_fifo_rx_r <= (others => '0');
      usbreg_frame_number <= (others => '0');
      rxdata_valid_r <= '0';
      pie_success_int <= '0';
      pie_endtransfer <= '0';
      pie_error_r <= '0';
      pie_errortype <= (others => '0');
      pie_sentNAK <= '0';
      txdata_req_r <= '0';
      keepprevdata_r <= '0';
      data_fifo_previous_byte_r <= (others => '0');
      iso_in_pending_r <= '0';
      iso_out_pending_r <= '0';
      pie_rx_nbytes <= (others => '0');
      wf_ext_token_packet_r <= '0';
      lpm_hird_hw_r <= (others => '0');
      linkstate_r <= (others => '0');
      bremotewake_r  <= '0';
      pie_lpm_remotewake_enable <= '0';
      pie_lpm_hird_hw   <= (others => '0');
      lpm_wf_l1_state_r <= '0';
      lpm_init_valid_r <= '0';
      moved_to_tx_d  <= '0';
      moved_to_tx_dd  <= '0';
      moved_to_tx_ddd  <= '0';
      sop_det_r <= '0';
      rx_ok_r    <= '0';
      DevAddrEnabled := FALSE;
      var_address1 := (others => '0'); 
      var_address2 := (others => '0'); 
      pie_dev_selected_int <= 0;
      usb_token_length <= (others => '0');

   elsif pie_clk'event and pie_clk='1' then

      if sop_start = '1' then
         sop_det_r <= '1';
      elsif clear_sop_det = '1' then
         sop_det_r <= '0';
      end if;

      rxactive_r <= rxactive;
      rx_ok_r    <= rx_ok;
      moved_to_tx_d <= moved_to_tx;
      moved_to_tx_dd <= moved_to_tx_d;
      moved_to_tx_ddd <= moved_to_tx_dd;
      -- IN Packet handling:
       -- if USB_DATAWIDTH=128 bits,MAX_DATA_BYTE_CNT_LSB = 15, only 4 lsb of data_byte_cnt must be = 0b1111
       -- txready set at '1' is taken into accound via data_byte_cnt -- > avoid double pulses on txdata_req in HS when bitstuffing
      if to_integer(data_byte_cnt(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0))= MAX_DATA_BYTE_CNT_LSB-1 and
         ("000" &  data_byte_cnt) < (packetsize-2) and txready = '1' then
      -- DOC: txdata_req_r <= '1' if data_byte_cnt = 15, 31, 47,... for USB_DATAWIDTH_IN_BYTES=16
         txdata_req_r <= '1'; -- a full word of width "USB_DATAWIDTH" is requested by the PIE
      else
         txdata_req_r <= '0';
      end if;
      if  clear_req_handshake = '1' then
         req_handshake_r  <= '0';
      elsif set_req_handshake = '1' then
         req_handshake_r  <= '1';
      end if;
      if rxerror = '0' and rxactive = '1' and rxvalid = '1' then
         rxdata_r <= rxdata;  -- used to build a received data bus of 16 bits
      end if;
      if new_pid_vld = '1' then
         pid_r <= rxdata(3 downto 0);
      end if;
      if new_token_byte2_vld = '1' then
         --fct_addr_r <= rxdata(6 downto 0); -- is registered with the next byte coming in (if new_inoutsetup_vld ='1'..)
         ep_r(0)    <= rxdata(7);
      end if;
      if new_token_byte3_vld = '1' then
         --crc5                <= rxdata(7 downto 3);
         ep_r(3 downto 1)    <= rxdata(2 downto 0);
      end if;
      if new_sof_vld= '1' then
         usbreg_frame_number <= rxdata_16(10 downto 0);
	 usb_token_length    <= token_length_counter;
      end if;
      -- EXT TOKEN & LPM
      ------------------
      if clear_wf_ext_token_packet = '1'then
         wf_ext_token_packet_r <= '0';
      elsif set_wf_ext_token_packet = '1' then
         wf_ext_token_packet_r <= '1' ;
      end if;
      if new_ext_token_byte2_vld = '1' then
         linkstate_r <= rxdata(3 downto 0);
         lpm_hird_hw_r <= rxdata(7 downto 4);
      end if;
      if new_ext_token_byte3_vld = '1' then
         bremotewake_r        <= rxdata(0);
      end if;
      if clear_lpm_wf_l1_state = '1' then
         lpm_wf_l1_state_r           <= '0';
      elsif set_lpm_wf_l1_state = '1' then
         lpm_wf_l1_state_r           <= '1';
      end if;
      if clear_lpm_init_valid = '1' then
         lpm_init_valid_r <= '0';
      elsif set_lpm_init_valid = '1' then
         lpm_init_valid_r <= '1';
      end if;
      if set_lpm_l1_state = '1' then
         pie_lpm_remotewake_enable <= bremotewake_r; -- values must be updated only when a ACK will be returned, and device is moving to LPM L1 State
         pie_lpm_hird_hw           <= lpm_hird_hw_r;
      end if;

      if new_inoutsetup_vld ='1' then
        -- Request information from the dma handler when:
        -- USB device is enabled AND
        -- received token (rxdata_16(6 downto 0) has an address =  usbreg_usbaddress or usbreg_usbaddress_tmp AND
        -- endpoint nr of the token (rxdata_16(10 downto 7)) is smaller than or equal to the highest ep that is implemented
        
        DevAddrEnabled      := FALSE;
        for i in 0 to C_NBDEV-1 loop
          for j in 0 to 6 loop
            var_address1(j) := usbreg_usbaddress(i*7+j);
            var_address2(j) := usbreg_usbaddress_tmp(i*7+j);
          end loop;
          if (var_address1 = rxdata_16(6 downto 0)  or 
              var_address2 = rxdata_16(6 downto 0)) and
              usbreg_deviceenabled(i) = '1'           then
            DevAddrEnabled  := TRUE;
            pie_dev_selected_int <= i;

          end if;
        end loop;

        if DevAddrEnabled and
           (to_integer(unsigned(rxdata_16(10 downto 7))) <= C_NBPHYSEP) then
           epinfo_req_r   <= '1'; -- this register value is transmitted to the dma handler and is also used in the others states of protocol FSM
           -- to indicate if ep/address are valid
           epinfo_epnr_r  <=  rxdata_16(10 downto 7);
           if pid_r = PID_IN then
              epinfo_epdir_r <= '1';               -- '1' : IN direction / '0' : OUT direction
           else
              epinfo_epdir_r <= '0';
           end if;
           if pid_r = PID_SETUP then
              epinfo_setup_r   <= '1';
              var_epinfo_setup := '1';
           else
              epinfo_setup_r   <= '0';
              var_epinfo_setup := '0';
           end if;
           usbaddress_r   <=  rxdata_16(6 downto 0);
        else
           epinfo_req_r <= '0';
        end if;
      end if;
      if clear_epinfo_req = '1' then
         epinfo_req_r <= '0';
      end if;
      if set_ignore_data = '1' then
         ignore_data_r <= '1';
      elsif clear_ignore_data = '1'then
         ignore_data_r <= '0';
      end if;
      if crc16_eval_rx = '1' then
         crc16_result_r <= crc16_result_rx;
      elsif crc16_eval_tx = '1' then
         crc16_result_r <= crc16_result_tx;
      elsif packet_handling_state_r = USB_PROT_IDLE then
         crc16_result_r <= (others => '1');
      end if;


      -- USB DATA FIFO : Same FIFO is used for both transmitting and receiving (assumption: never happened at the same time)
      -- width of USB_DATA_WIDTH
      --
      -- if USB_DATAWIDTH=128 bits,USB_DATAWIDTH_IN_BYTES = 16, max v_offset_in_bits= 120, only 4 lsb of data_byte_cnt are used
      v_offset_in_bits:= 8*(to_integer(data_byte_cnt(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0)));
      if clear_data_fifo = '1' then
        data_fifo_r <= (others => '0');
        -- filling of the data fifo from USB (byte per byte)
        -- if data_byte_cnt = 19 and USB_DATAWIDTH_IN_BYTES=16, v_offset_in_bits returns 24
        -- if data_byte_cnt = 16 and USB_DATAWIDTH_IN_BYTES=16, v_offset_in_bits returns 0
      elsif data_fifo_fill_rx = '1' then
         data_fifo_r(v_offset_in_bits + 7 downto v_offset_in_bits) <= rxdata;
       -- filling of the data fifo from DMA
      elsif data_fifo_fill_tx = '1' then
         data_fifo_r <= epinfo_txdata; -- the complete data_fifo_r is filled in one clock pulse (epinfo_txdata_valid is set)
         -- MSByte of datafifo_r is stored, used for corner case (txready =0 (bitstuffing)and txdatafetched =1)
         data_fifo_previous_byte_r <= data_fifo_r(USB_DATAWIDTH-1 downto USB_DATAWIDTH -8);
      end if;

      rxdata_valid_r <= rxdata_valid ; -- pulse must be set at the same time data is available
      if rxdata_valid = '1' then
         data_fifo_rx_r <= data_fifo_r;
      end if;

      if clear_pie_success = '1'then
         pie_success_int <= '0'; -- pie_success should be updated together with pie_endtransfer rising edge.
      elsif set_pie_success= '1' then
         pie_success_int <= '1'; -- pie_success should be updated together with pie_endtransfer rising edge.
      end if;
      if clear_pie_endtransfer = '1' then
         pie_endtransfer <= '0';
      elsif set_pie_endtransfer = '1' then
         pie_endtransfer <= '1';
      end if;

      if set_pie_error = '1' and pie_error_r = '0' then
         pie_error_r <= '1';
         pie_errortype <= errortype;
      elsif clear_pie_error = '1' then
         pie_error_r <= '0';
         pie_errortype <= (others => '0');
      end if;
      if clear_pie_sentNAK = '1' then
         pie_sentNAK <= '0';
      elsif set_pie_sentNAK = '1' then
         pie_sentNAK <= '1';
      end if;
      if txready='0' and txdata_req_r = '1' then
         keepprevdata_r <= '1';
      elsif txready='1' then  -- in FS keepprevdata_r will stay high until, next txready pulse, in HS mode,
      -- keepprevdata_r is high only for 1 clock cycle (bit stuffing at the same time as fetching data from dma handler)
         keepprevdata_r <= '0';
      end if;

      if clear_iso_in_pending = '1' then
        iso_in_pending_r <= '0';
      elsif set_iso_in_pending = '1' then
        iso_in_pending_r <= '1';
      end if;

      if clear_iso_out_pending = '1' then
         iso_out_pending_r <= '0';
      elsif set_iso_out_pending = '1' then
         iso_out_pending_r <= '1';
      end if;

      if set_rx_nbytes = '1' then
         pie_rx_nbytes <= rx_nbytes;
      end if;

      if (set_pie_success = '1') or (pie_success_int = '1' and clear_pie_endtransfer = '0') then
        epinfo_setup_ok_r <= var_epinfo_setup;
      else
        epinfo_setup_ok_r <= '0';
      end if;

   end if;
end process packet_reg_clk_proc;

pie_error   <= pie_error_r;
pie_success <= pie_success_int;
pie_dev_selected <= pie_dev_selected_int; 

-- decoding of packets
packet_decod_comb_proc : process (rxdata,rxdata_r,crc16_result_r,packet_handling_state_r,
                                  rxactive,txdata_pkt_nxt,data_fifo_fill_tx,
                                  packet_handling_state_nxt,data_byte_cnt,epinfo_nbytes,ignore_data_r,
                                  epinfo_maxpacket,packetsize,iso_transact_cnt_down ,iso_in_pending_r,
                                  iso_out_pending_r,iso_mdata_cnt_up,linestate,ls_filt,
                                  dev_speed_r,rxactive_r,txready_r,txready,sop_det_r,set_rx_nbytes,rx_nbytes,rx_ok,rx_ok_r)
variable v_crc5       : std_logic_vector(4 downto 0);
variable v_crc5_valid : std_logic;
variable v_crc16_rx      : std_logic_vector(15 downto 0);
variable v_crc16_tx      : std_logic_vector(15 downto 0);
variable v_crc16_valid : std_logic;
variable v_crc16_eval_rx : std_logic;
variable v_crc16_eval_tx : std_logic;
variable v_rxdata_16 : std_logic_vector(15 downto 0);

begin

sop_start <= '0';
eop_rx <= '0';
eop_tx <= '0';

-- Start of Packet detection (@FS, use of linestate is required for bus turnaround timings)
if dev_speed_r = USB_FULL_SPEED then
   if packet_handling_state_r = USB_PROT_IDLE or packet_handling_state_r = USB_PROT_OUT_SETUP_WF_EP_INFO_VALID then
      if linestate = LINESTATE_K and ls_filt = LINESTATE_J and sop_det_r = '0'then
         sop_start <= '1';
      end if;
   end if;
else
   sop_start <= rxactive and not rxactive_r; -- at HS, start of packet is detected via a rising edge of rxactive
end if;

-- End of Packet detection (@FS, use of linestate is required for bus turnaround timings in case of a transmit)
-- Receive packet
   if packet_handling_state_r = USB_PROT_OUT_SETUP_WF_EOP then
      eop_rx <= not rxactive and rxactive_r;
   end if;

-- Transmit packet
if packet_handling_state_r = USB_PROT_ALL_WF_END_TX_PACKET then
   if dev_speed_r = USB_FULL_SPEED then
      if linestate = LINESTATE_J and ls_filt = LINESTATE_SE0 then
         eop_tx <= '1';
      end if;
   else
      eop_tx <= not txready and txready_r ; -- at HS, end of a transmit packet is detected via a falling edge of txready
   end if;
end if;


pid_nxt <= rxdata(3 downto 0);

v_rxdata_16 := rxdata & rxdata_r;

-- CRC5:
--at the time of CRC5 evaluation, received crc5 and 3 msb of the Endpoint number
-- are extracted combinatiorally from the 8-bit bus
 v_crc5 := crc5_data16(bit_reverse16(v_rxdata_16(15 downto 0))); -- bits are swapped
 if v_crc5 = CRC5_RESIDUAL then
    v_crc5_valid := '1';
 else
    v_crc5_valid := '0';
 end if;
 crc5_valid_nxt <= v_crc5_valid;

 -- CRC16:
 if packet_handling_state_r = USB_PROT_OUT_SETUP_RCV_DATA_PACKET and rx_ok= '1' then
    v_crc16_eval_rx := '1';
 else
    v_crc16_eval_rx := '0';
 end if;

 if packet_handling_state_nxt = USB_PROT_IN_TX_DATA_PACKET and txready = '1' then  -- TX CRC16 must be done on the NXT state together with the NXT data to be transmitted
    v_crc16_eval_tx := '1';
 else
    v_crc16_eval_tx := '0';
 end if;

 v_crc16_rx:= crc16_data8(bit_reverse8(rxdata), crc16_result_r);
 if v_crc16_eval_rx = '1' then
    crc16_result_rx <= v_crc16_rx;
 else
    crc16_result_rx <= crc16_result_r;
 end if;

 v_crc16_tx:= crc16_data8(bit_reverse8(txdata_pkt_nxt), crc16_result_r);
 if v_crc16_eval_tx = '1' then
    crc16_result_tx <= v_crc16_tx;
 else
    crc16_result_tx <= crc16_result_r;
 end if;

 if crc16_result_r = CRC16_RESIDUAL then
    v_crc16_valid := '1';
 else
    v_crc16_valid := '0';
 end if;
 crc16_valid_nxt <= v_crc16_valid;

 -- OUT Packet handling:
 -- if USB_DATAWIDTH=128 bits,USB_DATAWIDTH_IN_BYTES = 16, only 4 lsb of data_byte_cnt must be = 0b0000
 -- rxdata_valid pulse is generated each time data_byte_cnt = 16 (0b10000), 32(0b100000), 48(0b110000),... for USB_DATAWIDTH_IN_BYTES=16
 -- it indicates to the dma handler that a full word of width "USB_DATAWIDTH" is available
 -- at the end of the receioved packet, if number of bytes of the data payload
 -- is not a nice multiple of USB_DATAWIDTH_IN_BYTES, an extra rxdata_valid pulse must be set to ask the dma_handler to fetch the
 -- remaining bytes from the data_fifo_rx_r. Since data_fifo_rx_r can also contain the CRC16 bytes
 -- the extra pulse is not sent at the end of the received packet if lsb's of data_byte_cnt are equal
 -- to 0 or 1 (meaning all the bytes of the datapayload are already fetched)
 -- it is needed to take delayed version of rx_ok (=rx_ok_r) since data_byte_cnt is only updated at the next clock cycle following rx_ok pulse
 if data_byte_cnt/=0 and ignore_data_r = '0' and
 (
 (to_integer(data_byte_cnt(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0))=0 and rx_ok_r='1')
 or
 (set_rx_nbytes = '1' and to_integer(unsigned(rx_nbytes(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0))) /= 0 and
 to_integer(data_byte_cnt(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0)) /= 0 and -- data_fifo_r does not contain any new bytes of data payload
 to_integer(data_byte_cnt(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0)) /= 1 )) then -- data_fifo_r does not contain any new bytes of data payload
 -- DOC: rxdata_valid <= '1' if data_byte_cnt = 16 (0b10000), 32(0b100000), 48(0b110000),... for USB_DATAWIDTH_IN_BYTES=16
    rxdata_valid <= '1'; -- a full word of width "USB_DATAWIDTH" is available
 else
    rxdata_valid <= '0';
 end if;

 if packetsize > USB_DATAWIDTH_IN_BYTES then
    if (("000" & data_byte_cnt) < packetsize-USB_DATAWIDTH_IN_BYTES-1) or (data_byte_cnt = 0)
       or (iso_in_pending_r = '1' and iso_transact_cnt_down /= "00")then
       txdata_fetched <= data_fifo_fill_tx;
    else
       txdata_fetched <= '0';
    end if;
 else
    txdata_fetched <= '0';
 end if;
 -- signals used outside from this process
 crc16_eval_tx <= v_crc16_eval_tx;
 crc16_eval_rx <= v_crc16_eval_rx;

 rxdata_16 <= v_rxdata_16;

 packetsize <= packetsize_decod(epinfo_maxpacket,epinfo_nbytes,iso_transact_cnt_down,iso_mdata_cnt_up, iso_in_pending_r,iso_out_pending_r);

end process packet_decod_comb_proc;


pie_epinfo_req            <= epinfo_req_r;
pie_epinfo_epnr           <= epinfo_epnr_r;
pie_epinfo_epdir          <= epinfo_epdir_r;
pie_epinfo_setup          <= epinfo_setup_r;
pie_epinfo_setup_received <= epinfo_setup_ok_r;
pie_usbaddress            <= usbaddress_r;
pie_rxdatavalid           <= rxdata_valid_r;
pie_txdata_fetched        <= txdata_fetched;
pie_rxdata                <= data_fifo_rx_r;

counter_packet_clk_proc : process (pie_clk, reset_n)

begin

if reset_n = '0' then

   data_byte_cnt <= (others => '0');
   iso_transact_cnt_down  <= (others => '0');
   iso_mdata_cnt_up <= (others => '0');

elsif pie_clk'event and pie_clk ='1'then

   if data_byte_cnt_clear = '1' then
      data_byte_cnt <= (others => '0');
   elsif data_byte_cnt_incr = '1' then
      if to_integer(data_byte_cnt) < MAX_DATA_BYTE_CNT - 1 then
         data_byte_cnt <= data_byte_cnt +1;
      end if;
   end if;
   -- ISO High bandwidth only
   -- iso_transact_cnt_down is loaded with the maximum of transactions according to epinfo_bytes
   -- count down decrements each time a data packet is received (USB_PROT_OUT_SETUP_RCV_DATA_PACKET)
   -- or is transmitted (USB_PROT_IN_TX_CRC16_BYTE2/USB_PROT_BAD_IN_TX_CRC16_BYTE2)
   -- this counter is used to check that number of token (IN or OUT) for the same iso HBW ep does not exceed the maximum of transactions per uframe
   if clear_iso_transact_cnt_down  = '1' then
      iso_transact_cnt_down  <= (others => '0');
   elsif load_iso_transact_cnt_down  = '1' then
      if unsigned( epinfo_nbytes(11 downto 10)) = "11" then
      -- special case: nr of bytes for this ep = 3072 bytes (3 transactions of 1024 bytes each)
         iso_transact_cnt_down  <= "10"; -- 3 transactions only.
      else
         iso_transact_cnt_down  <= unsigned( epinfo_nbytes(11 downto 10));
      end if;
   elsif decr_iso_transact_cnt_down  = '1' then
     if iso_transact_cnt_down  /= "00" then -- decr_iso_transact_cnt_down  = '1' and iso_transact_cnt_down  = "00" should never happend
        iso_transact_cnt_down  <= iso_transact_cnt_down  - 1;
     end if;
   end if;
   -- ISO OUT High bandwidth only
   -- iso_mdata_cnt_up (incremented each time a valid MDATA pid is received in USB_PROT_OUT_SETUP_WF_RX_DATA_PID state)
   -- this counter is used to check the number of MDATA transaction already received for the ongoing transfer (OUT ep only)
   -- if counter = 0, next Data PID can only be DATA0 or MDATA
   -- if counter = 1, next Data PID can only be DATA1 or MDATA
   -- if counter = 2, next Data PID can only be DATA2
   if clear_iso_mdata_cnt_up  = '1' then
      iso_mdata_cnt_up  <= (others => '0');
   elsif incr_iso_mdata_cnt_up  = '1' and iso_mdata_cnt_up < "11" then -- a maximum of 2 MDATA transactions is allowed for a transfer
     iso_mdata_cnt_up  <= iso_mdata_cnt_up  + 1;
   end if;

end if;
end process counter_packet_clk_proc;

--------------------------------------------------------------
--------------------------------------------------------------
--               USB PACKETS HANDLING (end)                 --
--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------



--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------
--               USB TIMER (begin)                          --
--------------------------------------------------------------
--------------------------------------------------------------

-- mentionned timing in UTMI Spec rev 1.05:
------------------------------------------
--
-- Min.3ms IDLE State in HS mode (SE0) via LineState ===> TAKEN INTO ACCOUNT via T_3ms
-- The assertion of OpMode to Normal mode at the end of the 1 ms signaling period should occur until after the maximum TX End
-- Delay (TXValid has been de-asserted for at least 40 bit times or in FS mode 160 CLKs).4.1.5 ===> TAKEN INTO ACCOUNT via T_TxENDDELAY
-- FS mode: EOP detected = SE0 < 2 LS bit times (1.3 us) via LineState ===> TAKEN INTO ACCOUNT via RXACTIVE deasserted (TO BE CHECKED)
-- FS mode: Reset detected = SE0 > 4 LS bit times (2.5 us) via LineState ===> TAKEN INTO ACCOUNT via MAX_LINESTATE_DBC_CNT
-- HS Mode: Reset Detected = SE0 for > 3ms followed by SE0 detected after switching to FS mode ===> TAKEN INTO ACCOUNT via T_3ms
-- HS Mode: Suspend Detected = SE0 for > 3ms followed by J detected after switching to FS mode ===> TAKEN INTO ACCOUNT via T_3ms
--
-- HS Mode: Suspend Detection
-----------------------------
-- T1(TWTREV): The time at which the device must place itself in FS mode after bus activity stops.
-- HS Reset T0 + 3.0 ms < T1 {TWTREV} <HS Reset T0 + 3.125 ms (debouncing time) ===> TAKEN INTO ACCOUNT via T_3ms
-- T2(TWTWRSTHS): PIE samples LineState. If LineState = 'J',then the initial SE0 on the bus (T0 - T1)
-- had been due to a Suspend state and the PIE remains in HS mode.===> TAKEN INTO ACCOUNT via T_TWTRSTHS
-- T2: T1 + 100 �s < T2 {TWTWRSTHS} <T1 + 875 �s (elapse time before sampling)
-- T3 (TWTRSM): The earliest time where a device can issue Resume signaling.
-- T3 > HS Reset T0 + 5ms {TWTRSM} ===> TAKEN INTO ACCOUNT via T_3ms (from T2)
-- T4(T2SUSP): The latest time that a device must actually be suspended,
-- drawing no more than the suspend current from the bus.
-- T4 < HS Reset T0 + 10ms {T2SUSP} ===> MERGED WITH PREVIOUS STATE

-- HS Mode: Reset Detection
---------------------------
-- T1(TWTREV): Earliest time at which the device may place itself in FS mode after bus activity stops.
-- HS Reset T0 + 3.0 ms < T1 {TWTREV} <HS Reset T0 + 3.125 ms ===>  IDEM AS T1 SUSPEND
-- T2((TWTWRSTHS): PIE samples LineState. If LineState = SE0, then the SE0 on the bus is due to
-- a Reset state. The device now enters the HS Detection Handshake protocol.
-- T2: T1 + 100 �s < T2 {TWTWRSTHS} <T1 + 875 �s ===> IDEM AS T2 SUSPEND. ACTION IS DIFFERENT

-- HS Detection HandShake
-------------------------
-- A device has up to 6 ms after the release of SuspendM (HS Reset T0) to assert a minimum of a 1 ms Chirp K.
-- device chirp must last at least 1.0ms and must end no later than 7.0ms after HS Reset T0
-- The PIE must assert the Chirp K for 66000 CLK cycles to ensure a 1ms minimum duration.  ===> TAKEN INTO ACCOUNT via T_3ms
-- The PIE must employ a counter (Chirp Count) to count the number of Chirp K and Chirp J states (0--> max value =6).===> TAKEN INTO ACCOUNT via chirp counter
-- LineState signal transitions must be used by the PIE to step through the Chirp K-J-K-J-K-J state diagram ===> TAKEN INTO ACCOUNT via bus_event FSM
-- LineState does not filter the bus signals so the requirement that a bus state must be "continuously asserted
-- for 2.5 �s" must be verified by the PIE sampling the LineState signals ===> TAKEN INTO ACCOUNT via MAX_LINESTATE_DBC_CNT
-- T1 should be > T0 + 125 us to be compliant with all 2.0 Host ===> TAKEN INTO ACCOUNT via T_125us

-- FS Downstream Port:

-- T1: Device enables HS Transceiver and asserts Chirp K on the bus.
-- T1: T0(+125us) < T1 < HS Reset T0 + 6.0 ms ===> TAKEN INTO ACCOUNT via T_125us
-- T2(TUCHEND): Device removes Chirp K from the bus. 1 ms minimum width
-- T2: T1 + 1.0 ms {TUCH} < T2 < HS Reset T0 + 7.0 ms {TUCHEND} ===> TAKEN INTO ACCOUNT via T_3ms
-- T3: Earliest time when downstream port may assert Chirp K on the bus
-- T3: T2 < T3 < T2+100 �s {TWTDCH} ==> NOT RELEVANT FOR DEVICE
-- T4 (TWTFS): Downstream port chirp not detected by the device.
-- Device reverts to FS default state and waits for end of reset.
-- T4: T2 + 1.0 ms < T4 {TWTFS} < T2 + 2.5 ms ===> TAKEN INTO ACCOUNT via T_TWTFS
-- T5 (TDRST (Min): Earliest time at which downstream port may end reset
-- T5: HS Reset T0 + 10 ms {TDRST (Min)}  ==> NOT RELEVANT FOR DEVICE

-- HS Downstream port:

-- T1: Device asserts Chirp K on the bus.
-- T1: T0 (+125us) < T1 < HS Reset T0 + 6.0 ms{TUCHEND - TUCH}  ===> IDEM AS T1 FS DS Port
-- T2: Device removes Chirp K from the bus. 1 ms minimum width.
-- T2: T1 + 1.0 ms {TUCH} < T2 < HS Reset T0 + 7.0 ms {TUCHEND} ===> IDEM AS T2 FS DS Port
-- T3: Downstream port asserts Chirp K on the bus
-- T3: T2 < T3 < T2+100 �s {TWTDCH}  ===> NOT RELEVANT FOR DEVICE
-- T4: Downstream port toggles Chirp K to Chirp J on the bus.
-- T4: T3 + 40 �s {TDCHBIT (min)} < T4 < T3 + 60 �s {TDCHBIT (max)} ===> REPLACED BY CHIRP COUNTER on LineState_filtered
-- T5: Downstream port toggles Chirp J to Chirp K on the bus.
-- T5: T4 + 40 �s {TDCHBIT (min)} < T5 < T4 + 60 �s {TDCHBIT (max)} ===> REPLACED BY CHIRP COUNTER on LineState_filtered
-- T6 Device detects downstream port chirp. ===> NOT RELEVANT FOR DEVICE
-- T7 : Downstream port chirp detected by the device. Device removes D+ pull-up and asserts HS
-- terminations, reverts to HS default state and waits for end of reset.
-- T7: T6 < T7 < T6 + 500 �s {TWTHS}
-- T8: Terminate downstream port Chirp K-J sequence (Repeating T4 and T5) ===> NOT RELEVANT FOR DEVICE
-- T8: T9 - 500 �s {TDCHSE0 (max)} < T8 < T9 - 100 �s {TDCHSE0 (min)}
-- T9 The earliest time at which downstream port may end reset. The latest time at which the
-- device may remove the D+ pull-up and assert the HS terminations, reverts to HS default state.
-- T9 > HS Reset T0 + 10 ms {TDRST(Min)} ===> REPLACED BY CHECK on Linestate_debounced = SE0

-- HS Detection Handshake Timing Values from Suspend:

-- T0 : While in suspend state an SE0 is detected on the USB. HS Handshake begins.
-- D+ pull-up enabled, HS terminations disabled, SuspendM negated.
-- When reset is entered from a suspended state (J to SE0 transition reported by LineState), SuspendM is
-- combinatorially negated at time T0 by the PIE. ===> TO BE DONE
-- T1: First transition of CLK. CLK "Usable" ===> T1 calculation NOT RELEVANT FOR DEVICE
-- but a timer must be initialized at this time. SE0 of > 2.5 us must be detected
-- T1: T0 < T1 < T0 + 5.6 ms
-- T2: Device asserts Chirp K on the bus.
-- T2: T1 (+125 us) < T2 < T0 + 5.8 ms ===> IDEM AS T1 HS Detection HandShake FS DS Port
-- T3: Device removes Chirp K from the bus. (1 ms minimum width) and begins looking for downstream chirps.
-- T3: T2 + 1.0 ms {TUCH} < T3 < T0 + 7.0 ms {TUCHEND} ===> IDEM AS T2 FS DS Port
-- T4: CLK "Nominal" (CLK is frequency accurate to �500 ppm, duty cycle accurate to 50�5%).
-- T4: T1 < T4 < T0 + 20.0 ms {TDRST (Min) + TRSMRCY}


-- ASSERTION OF RESUME --
-------------------------
-- A device with remote wake-up capability must wait for at least 5 ms after the bus is in the idle state
-- before sending the remote wake-up resume signaling. ===> IDEM as T3 of SUSPEND DETECTION

-- The assertion of OpMode to Normal mode at the end of the 1 ms signaling period should occur until after the maximum TX End
-- Delay (TXValid has been de-asserted for at least 40 bit times or in FS mode 160 CLKs).4.1.5
-- ===> TAKEN INTO ACCOUNT via T_TxENDDELAY


-- T1: Device asserts FS 'K' on the bus to signal resume request to downstream port
-- T1: T0 < T1 < T0 + 10 ms. {TDRSMDN} ===> NOT TAKEN INTO ACCOUNT by the DEVICE
-- T2: The device releases FS 'K' on the bus, however by this time the 'K' state is held by downstream port.
-- T2: T1 + 1.0 ms {TDRSMUP (min)} < T2 < T1 + 15 ms {TDRSMUP (max)} ===> TAKEN INTO ACCOUNT via T_3ms
-- T3: Downstream port asserts SE0
-- T3: T1 + 20 ms {TDRSMDN} ===> T3 Calculation NOT RELEVANT FOR DEVICE
-- T4: Latest time at which a device, which was previously in HS mode,
-- must restore HS mode after bus activity stops.SE0 must be detected before switching !!!
-- T4 <  T3 + 1.33 �s {2 Low-speed bit times} ===> SEO DETECTED via Linestate filtered.


-- DETECTION OF RESUME --
-------------------------
-- The PIE uses the LineState signals to determine when the USB transitions from the 'J' to the 'K' state
-- and finally to the terminating low-speed EOP (SE0 for 1.25-1.5 �s.).
-- It is recommended that all PIE implementations key off the 'J' to 'K' transition for exiting suspend mode
-- (SuspendM = 1). And within 1.25 �s after the transition to the SE0 state (low-speed EOP) the PIE must
-- enable normal operation, i.e. enter HS or FS mode depending on the mode the device was in when it was
-- suspended.
-- If the device was in FS mode before the suspend: then the PIE leaves the FS terminations enabled
-- If the device was in HS mode before the suspend: then the PIE must switch to the HS terminations before
-- the SE0 expires ( < 1.25 �s). ===> TAKEN INTO ACCOUNT via BUS EVENT FSM & debounced LINESTATE (K detection) &
-- & filtered LINESTATE  (SEO detection)

-- DEVICE ATTACH
----------------
-- T1: Maximum time from Vbus valid ( > 4.01 V) to when the device must signal attach
-- T1 < T0 + 100 ms {TSIGATT} ===> NOT TAKEN INTO ACCOUNT by the DEVICE
-- T2 (HS Reset T0): Debounce interval. The device now enters the HS Detection Handshake protocol.
-- T2 > T1 + 100 ms {TATTDB} ===> NOT TAKEN INTO ACCOUNT by the DEVICE


-- INTER PACKET DELAYS --
-------------------------

-- HS Inter-packet delay for a receive followed by a transmit:

-- NO TIMEOUT
-- the PIE Decision Time must not take more than 14 CLKs to ensure that it does not exceed the inter-packet delay
-- maximum of 192 bit times (24 CLKs).
-- Max 14 CLK Cycles ===> CONSTRAINT TO TAKE INTO ACCOUNT in the DESIGN, NO TIMER TO IMPLEMENT
--

-- HS Inter-packet delay for a Transmit followed by a Receive:

-- delay is taken into account by downstream port ===> NO DELAY TO IMPLEMENT, TIMEOUT TO IMPLEMENT
-- Minimum PIE Prep Time (PIE Prep Time is the delay between negating TXValid and
-- detecting the assertion of RXActive.)  will be as short as 6 CLKs
-- No Timeout if Interpacket delay is < 92 clk cycles
-- Timeout if Interpacket delay is > 102 clk cycles

-- HS Inter-packet delay for a receive followed by a receive
-- In this case the minimum 32 bit time delay is guaranteed by the USB specification
-- ===> TIMEOUT TO IMPLEMENT  (Not specified in UTMI spec)
-- No Timeout if Interpacket delay is < 92 clk cycles
-- Timeout if Interpacket delay is > 102 clk cycles


-- FS Inter-packet delay for a Receive followed by a Transmit
-- Minimum InterPacket delay is 2 bit times (10 clk cycles) and maximum 6.5 (32.5 clk cycles)
-- For timing the inter-packet delay the PIE must utilize LineState to determine the EOP transition
-- from SE0 (SE0 width is about 10 clk cycles) to the J-State.
-- RXActive must also be negated before TXValid can be asserted because the PIE must parse
-- the received data to determine what data to return with the following transmit operation
-- PIE Decision Time (measured from end of EOP) must be between 2 and 24 Clk Cycles.
-- ===> OPTION A (the only option allowed by UTMI spec)/ Start transfert (= pie_epinfo_req asserted) of receive data
-- after end of EOP detected via LineState (14 clk cycles introduced < maximum 6.5 bit times) ???
-- ===> OPTION B (allowed by UTMI+ spec)/ Start transfert (= pie_epinfo_req asserted) of receive data
-- after RXActive is negated (14 clk cycles introduced which is > minimum 2 bit times ) ???
-- UTMI+ Spec does not force the use of linestate

-- FS Inter-packet delay for a Transmit followed by a Receive
-- For a transmit followed by a receive the downstream port determines the inter-packet delay. The PIE must
-- measure the inter-packet delay to determine whether a timeout has occurred or not
-- The PIE must use LineState to measure inter-packet delays. (UTMI + allows the use of the others ctrl signals)
-- ===> TIMEOUT TO IMPLEMENT:
-- No Timeout if Interpacket delay is < 80 clk cycles
-- Timeout if Interpacket delay is > 90 clk cycles


-- Line Sate Debouncing (= LineSate if Line State has beed unchanged for more than 4 Low Speed bit times)
-- LineState is debounced for > 2.5 us: 2.9us (60 MHz + 10 %) < debouncing time < 3.56 us (60 MHz - 10 %)
--
linestate_debouncing_proc: process (pie_clk, reset_n)

begin

if reset_n = '0' then

   ls_dbc <= LINESTATE_INCST;
   linestate_r <= LINESTATE_INCST;
   linestate_dbc_cnt <= 0;

elsif pie_clk'event and pie_clk ='1'then

   linestate_r <= linestate;

   if linestate /= linestate_r or init_linestate_dbc ='1' then
      linestate_dbc_cnt <= 0;
      ls_dbc <= LINESTATE_INCST;
   elsif linestate_dbc_cnt < MAX_LINESTATE_DBC_CNT then
      ls_dbc <= LINESTATE_INCST;
      linestate_dbc_cnt <= linestate_dbc_cnt + 1;
   else   -- linestate has been stable for MAX_LINESTATE_DBC_CNT pie_clk cycles
      ls_dbc <= linestate_r;
   end if;

end if;

end process linestate_debouncing_proc;


-- LineState Filtering (occurs on SE0 and SE1) UTMI+ spec 2.1.1.2.
-- Supress unwanted SE0 states due to skew on the DP/DM signals
-- 2 CLK cycles for FS/HS Bus speed for 8-bit interface  (UTMI_16_BIT_INTERFACE is false)


linestate_filter_clk_proc: process (pie_clk, reset_n)

begin

if reset_n = '0' then
   ls_filt <= LINESTATE_SE0;
   se0_filt_cnt       <= 0;
   se1_filt_cnt       <= 0;

elsif pie_clk'event and pie_clk ='1'then

   if linestate /= LINESTATE_SE0 and linestate /= LINESTATE_SE1 then
      ls_filt <= linestate;
      se0_filt_cnt <= 0;
      se1_filt_cnt <= 0;
   elsif linestate = LINESTATE_SE0 and se0_filt_cnt = MAX_SE0_FILT_CNT then
      ls_filt <= linestate;   -- equivalent to linestate_filered <= SE0
   elsif linestate = LINESTATE_SE1 and se1_filt_cnt = MAX_SE1_FILT_CNT then
      ls_filt <= linestate;   -- equivalent to linestate_filered <= SE1
   else
     if linestate = LINESTATE_SE0 then
      se0_filt_cnt <= se0_filt_cnt + 1; -- linestate_filtered
     elsif linestate = LINESTATE_SE1 then 
      se1_filt_cnt <= se1_filt_cnt + 1; -- linestate_filtered
     end if;
   end if;

end if;

end process linestate_filter_clk_proc;




timer_bus_event_clk_proc : process (pie_clk, reset_n)

begin

if reset_n = '0' then

   timer_bus_event <= 0;
   timer_bus_event_timeout_r <= '0';
   chirp_count <= 0;
   isotoggle_r <= '0';
   timer_sof     <= 0;

elsif pie_clk'event and pie_clk ='1'then

   timer_bus_event_timeout_r <= '0';

   if clear_timer_bus_event = '1' then
      timer_bus_event <= 0;
   elsif timer_bus_event =  MAX_BUS_EVENT_TIMER then  -- timeout occurs. unexpected behaviour
      timer_bus_event_timeout_r <= '1';
      timer_bus_event <= 0;
   elsif  timer_bus_event_run = '1' then
      timer_bus_event <= timer_bus_event + 1;
   end if;

   -- timer_sof (count down) is reinitialised if:
   -- 1/ timer reaches 0 OR
   -- 2/ if a SOF is correctly received OR
   --
   -- pie_isotoggle (isotoggle) signal is toggled :
   --  1/ every time the timer expires (reaches 0) regardless a SOF is detected OR
   --  2/ if a SOF is received in the half period of time preceding the expiration of the timer.
   -- Check of the timer value when a SOF is received is done to avoid double toggling of
   -- the signal if SOF is received a few clock cycles later than expected
   if timer_sof = 0 then
      isotoggle_r <= not isotoggle_r;
      if dev_speed_r = USB_HIGH_SPEED then
         timer_sof <= T_125us-1;
      else
         timer_sof <= T_1ms-1;
      end if;
   elsif new_sof_vld = '1' then
      if dev_speed_r = USB_HIGH_SPEED then
         if timer_sof < T_125us/2  then
            isotoggle_r <= not isotoggle_r;
         end if;
         timer_sof <= T_125us-1;
      else
         if timer_sof < T_1ms/2 then
            isotoggle_r <= not isotoggle_r;
         end if;
         timer_sof <= T_1ms-1;
      end if;
   else
      timer_sof <= timer_sof - 1;
   end if;

   if chirp_count_clear ='1' then
      chirp_count <= 0;
   elsif chirp_count_pls = '1' and chirp_count /=  MAX_CHIRP_COUNT-1 then
      chirp_count <= chirp_count +1;
   end if;

end if;

end process timer_bus_event_clk_proc;



timer_bus_event_comb_proc : process (bus_event_state_r)

begin

   case bus_event_state_r is

      when BUS_EVENT_FS_IDLE|BUS_EVENT_HS_IDLE|BUS_EVENT_WF_SUSPEND_OR_RST|BUS_EVENT_RESET|BUS_EVENT_WF_SUSPEND|
           BUS_EVENT_SW_WAKEUP_WF_CLK|BUS_EVENT_SW_WAKEUP_1|BUS_EVENT_SW_WAKEUP_2|BUS_EVENT_HS_DET_HSK_1|BUS_EVENT_HS_DET_HSK_2|
           BUS_EVENT_HS_DET_HSK_3|BUS_EVENT_HS_DET_HSK_4|BUS_EVENT_LPM_SW_WAKEUP_WF_CLK|BUS_EVENT_LPM_SW_WAKEUP_1 =>

         timer_bus_event_run <= '1';

      when others => --BUS_EVENT_INIT|BUS_EVENT_FS_ACTIVE|BUS_EVENT_HS_ACTIVE|BUS_EVENT_SUSPEND|BUS_EVENT_SW_WAKEUP_3|
      --BUS_EVENT_HOST_RESUME|BUS_EVENT_WF_EOR_FS|BUS_EVENT_WF_ENDCHIRP_HS|BUS_EVENT_TEST_MODE|BUS_EVENT_LPM_SUSPEND_L1

         timer_bus_event_run <= '0';

   end case;

end process timer_bus_event_comb_proc;



timer_packet_handling_clk_proc: process (pie_clk, reset_n)

begin

if reset_n = '0' then

   timer_packet_handling_r <= 0;

elsif pie_clk'event and pie_clk ='1'then
   if reload_timer_packet_handling_nxt = '1' then
      timer_packet_handling_r <= timer_packet_handling_nxt;
   elsif timer_packet_handling_r/= 0 then
      timer_packet_handling_r <= timer_packet_handling_r -1;
   end if;
end if;

end process timer_packet_handling_clk_proc;

--------------------------------------------------------------
--------------------------------------------------------------
--               USB  TIMER (end)                           --
--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------


--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------
--               ULPI SPECIFIC (begin)                      --
--------------------------------------------------------------
--------------------------------------------------------------




ulpi_txready <= ulpi_nxt_int when ulpi_oper_state_r = ULPI_OPER_PID_TX_CMD or -- USB Packet Transmit (PID))
                              ulpi_oper_state_r = ULPI_OPER_PID_TX_DATA or -- USB Packet Transmit (PID))
                              ulpi_oper_state_r = ULPI_OPER_NOPID_TX_DATA  -- chirp/resume
                              else '0';

ulpi_turnaround <= ulpi_dir_r xor ulpi_dir_r_s;
ulpi_rxvalid_r <=  '1' when ulpi_oper_state_r = ULPI_OPER_PKT_RCV and ulpi_turnaround = '0' and ulpi_nxt_r = '1' else '0';

-- Functional control register: writing access only (pattern on the data bus will be written over all bits of the register
-- according to bus_event_to_phy_comb_proc
set_ulpi_req_txcmd_fct_ctrl_wr <= '1' when ulpi_opmode_r /= opmode_nxt or
                                           ulpi_xcvrselect_r/= xcvrselect_nxt or
                                           ulpi_termselect_r /= termselect_nxt
                                      else '0';


-- Requesting to go to low power mode does not mean that the phy will enter effectivelly to low power mode
-- Exiting low power mode (including asserting stp line to indicate to the PHY to exit low power mode) is only relevant if
-- PHY was effectively in Low Power Mode. Check must be preformed.

set_ulpi_req_txcmd_fct_ctrl_susp <= set_ulpi_req_low_power_mode;


set_ulpi_req_low_power_mode <= '1' when suspendm_nxt = '0' and (ulpi_suspendm_r = '1' or -- enter into suspend ouside the ULPI reset cycle
                                    set_ulpi_req_txcmd_fct_ctrl_wr_oprst='1'  or -- enter into suspend during ULPI reset cycle
                                   (bus_event_state_r /= BUS_EVENT_INIT and usbreg_dev_connect = '0') or -- disconnect (No USB suspend)
     (bus_event_state_r = BUS_EVENT_INIT and usbreg_dev_connect = '0' and set_new_rxcmd ='1' and ulpi_vbusvalid_cmd = '0')or -- false interrupt after disconnect (No USB suspend)
     (bus_event_state_r = BUS_EVENT_SUSPEND and set_new_rxcmd ='1' and ulpi_linestate_cmd = LINESTATE_J and ulpi_vbusvalid_cmd = '1')) -- false interrupt after reconnect while host is still in suspend
                                   else  '0';

clear_ulpi_req_low_power_mode <= '1' when (ulpi_dir_int = '0' and ulpi_dir_r = '1') and
                                       (usbreg_remotewakeup='1' or -- from register interface
                                       ulpi_pwrctrl_wakeup = '1' or -- from suspend control module at toplevel structure
                                       ulpi_suspendm_r= '1' or
                                       ulpi_oper_state_r = ULPI_OPER_EXIT_LOW_POWER
                                       ) else
                             '0';
-- Extended Register access (Vendor Specific)
-- -- new request during pending transaction will be ignored
set_ulpi_req_xreg_wr <= '1' when phy_start = '1' and ulpi_xreg_write = '1' and ulpi_req_xreg_wr_r = '0' else '0';
set_ulpi_req_xreg_rd <= '1' when phy_start = '1' and ulpi_xreg_write = '0' and ulpi_req_xreg_rd_r = '0' else '0';




-- Register Map (PHY) access handling TXCMD
-- All the requests (read or Write) are registered
-- Read or Write access must be arbitrated (priority handling)

-- List of immediate registers :
--------------------------------
-- Function Control Register (Write/Set access)
-- OTG Control Register (Clear access)
-- USB Interrupt Status register (Current Value of Vbus Valid)
-- Debug Control Register (Current Values of lineState, used at the startup) (Reading Only)

ulpi_reg_access_arb_comb_proc: process (set_ulpi_req_txcmd_fct_ctrl_wr,set_ulpi_req_txcmd_fct_ctrl_reset,
                               set_ulpi_req_txcmd_fct_ctrl_susp,ulpi_req_txcmd_fct_ctrl_susp_r,
                               ulpi_req_txcmd_fct_ctrl_wr_r,ulpi_req_txcmd_fct_ctrl_reset_r,
                               set_ulpi_req_txcmd_int_stat,ulpi_req_txcmd_int_stat_r,
                               set_ulpi_req_txcmd_dbg,ulpi_req_txcmd_dbg_r,
                               set_ulpi_req_xreg_wr,ulpi_req_xreg_wr_r,
                               set_ulpi_req_xreg_rd,ulpi_req_xreg_rd_r,set_ulpi_req_txcmd_fct_ctrl_wr_oprst,
                               set_ulpi_req_txcmd_otg_ctrl_wr_oprst,ulpi_req_txcmd_otg_ctrl_wr_r)

begin
-- default values

   ulpi_arb_reg_nxt <= (others => '0');
   ulpi_reg_access_req <= '0';

if set_ulpi_req_txcmd_fct_ctrl_reset = '1' or ulpi_req_txcmd_fct_ctrl_reset_r = '1' then -- Function Control Register -- reset
   ulpi_arb_reg_nxt <= ULPI_ARB_FCTCTRL_REG_RESET;
   ulpi_reg_access_req <= '1';

elsif set_ulpi_req_txcmd_fct_ctrl_susp = '1' or ulpi_req_txcmd_fct_ctrl_susp_r = '1' then -- Function Control Register -- suspend
   ulpi_arb_reg_nxt <= ULPI_ARB_FCTCTRL_REG_SUSP;
   ulpi_reg_access_req <= '1';

elsif set_ulpi_req_txcmd_fct_ctrl_wr = '1' or set_ulpi_req_txcmd_fct_ctrl_wr_oprst = '1' or
                 ulpi_req_txcmd_fct_ctrl_wr_r = '1' then -- Function Control Register
   ulpi_arb_reg_nxt <= ULPI_ARB_FCTCTRL_REG_WR;
   ulpi_reg_access_req <= '1';

elsif set_ulpi_req_txcmd_otg_ctrl_wr_oprst = '1' or ulpi_req_txcmd_otg_ctrl_wr_r = '1' then -- OTG Control Register -- clear
   ulpi_arb_reg_nxt <= ULPI_ARB_OTGCTRL_REG_WR;
   ulpi_reg_access_req <= '1';

elsif set_ulpi_req_txcmd_int_stat = '1' or ulpi_req_txcmd_int_stat_r = '1' then -- USB Interrupt Status register
   ulpi_arb_reg_nxt <= ULPI_ARB_INT_REG_RD;
   ulpi_reg_access_req <= '1';

elsif set_ulpi_req_txcmd_dbg = '1' or ulpi_req_txcmd_dbg_r = '1' then -- Debug Control Register
   ulpi_arb_reg_nxt <= ULPI_ARB_DBG_REG_RD;
   ulpi_reg_access_req <= '1';

elsif set_ulpi_req_xreg_wr = '1' or ulpi_req_xreg_wr_r = '1' then -- Extended Control Register (WRITE)
   ulpi_arb_reg_nxt <= ULPI_ARB_XREG_WR;
   ulpi_reg_access_req <= '1';

elsif set_ulpi_req_xreg_rd = '1' or ulpi_req_xreg_rd_r = '1' then -- Extended Control Register (READ)
   ulpi_arb_reg_nxt <= ULPI_ARB_XREG_RD;
   ulpi_reg_access_req <= '1';
end if;

end process ulpi_reg_access_arb_comb_proc;


ulpi_reg_access_comb_proc: process (ulpi_arb_reg_r,opmode_nxt,termselect_nxt ,xcvrselect_nxt,ulpi_xreg_add,ulpi_xreg_wdata)
begin

  -- default values
     ulpi_reg_access_wr_i <= '0';
     ulpi_ext_reg <= '0';
     ulpi_reg_tx_addr <= (others => '0');
     ulpi_tx_data_wr  <= (others => '0');


case ulpi_arb_reg_r is

  when ULPI_ARB_FCTCTRL_REG_RESET => -- Function Control Register -- reset
     ulpi_reg_access_wr_i <= '1';
     ulpi_ext_reg <= '0';
     ulpi_reg_tx_addr <= ULPI_ADDR_FCTCTRL_REG_SET;
     ulpi_tx_data_wr  <=  "00" & '1' & "00000";

  when ULPI_ARB_FCTCTRL_REG_SUSP => -- Function Control Register -- suspend
     ulpi_reg_access_wr_i <= '1';
     ulpi_ext_reg <= '0';
     ulpi_reg_tx_addr <= ULPI_ADDR_FCTCTRL_REG_CLR;
     ulpi_tx_data_wr  <=  '0' & '1' & "000000";

  when ULPI_ARB_FCTCTRL_REG_WR => -- Function Control Register -- will never be used to reset or put the PHY into LPW
     ulpi_reg_access_wr_i <= '1';
     ulpi_ext_reg <= '0';
     ulpi_reg_tx_addr <= ULPI_ADDR_FCTCTRL_REG_WR;
     ulpi_tx_data_wr  <=  '0' & '1' & '0' & opmode_nxt & termselect_nxt & '0' & xcvrselect_nxt;

  when ULPI_ARB_OTGCTRL_REG_WR =>  -- OTG Control Register -- clear
     ulpi_reg_access_wr_i <= '1';
     ulpi_ext_reg <= '0';
     ulpi_reg_tx_addr <= ULPI_ADDR_OTGCTRL_REG_CLR;
     ulpi_tx_data_wr  <=  "00000110"; -- clear dppulldown/dmpulldown

  when ULPI_ARB_INT_REG_RD => -- -- Debug Control Register
     ulpi_reg_access_wr_i <= '0';
     ulpi_ext_reg <= '0';
     ulpi_reg_tx_addr <= ULPI_ADDR_INT_REG_RD;
     --ulpi_tx_data_wr  -- READ ONLY

  when ULPI_ARB_DBG_REG_RD =>  -- Debug Control Register
     ulpi_reg_access_wr_i <= '0';
     ulpi_ext_reg <= '0';
     ulpi_reg_tx_addr <= ULPI_ADDR_DBG_REG_RD;
     --ulpi_tx_data_wr  -- READ ONLY

  when ULPI_ARB_XREG_WR => -- Extended Control Register (WRITE)
     ulpi_reg_access_wr_i <= '1';
     ulpi_ext_reg <= '1';
     ulpi_reg_tx_addr <= ulpi_xreg_add;
     ulpi_tx_data_wr  <= ulpi_xreg_wdata;

  when ULPI_ARB_XREG_RD => -- Extended Control Register (READ)
     ulpi_reg_access_wr_i <= '0';
     ulpi_ext_reg <= '1';
     ulpi_reg_tx_addr <= ulpi_xreg_add;
     --ulpi_tx_data_wr  <= -- READ ONLY

  when others => -- Extended Control Register (READ)
     -- default values
     ulpi_reg_access_wr_i <= '0';
     ulpi_ext_reg <= '0';
     ulpi_reg_tx_addr <= (others => '0');
     ulpi_tx_data_wr  <= (others => '0');

   end case;
end process ulpi_reg_access_comb_proc;

set_ulpi_rxactive_line <= ulpi_dir_r  and ulpi_nxt_r and ulpi_turnaround; -- USB receive while dir was previously low
set_new_rxcmd <= '1' when ulpi_turnaround = '0' and ulpi_nxt_r = '0' and  -- only last rxcmd is taken into account
                          (ulpi_oper_state_r = ULPI_OPER_CMD_RCV or ulpi_oper_state_r =  ULPI_OPER_RESET_CMD_RCV) and
                          ulpi_async_mode_r = '0'
                          else '0';


--decoding from rxcommand byte:
ulpi_rxactive_cmd <= '1' when ulpi_rxdata_r(5 downto 4)= "01" or ulpi_rxdata_r(5 downto 4)= "11" else '0';
ulpi_rxerror_cmd <= '1' when ulpi_rxdata_r(5 downto 4)= "11"  else '0';
ulpi_linestate_cmd  <= ulpi_rxdata_r(1 downto 0);
ulpi_vbusvalid_cmd  <= '1' when ulpi_rxdata_r(3) = '1' else '0';


set_ulpi_tx_nopid_req <= '1' when (bus_event_state_r = BUS_EVENT_RESET and      -- NOPID TX CMD
                          bus_event_state_nxt = BUS_EVENT_HS_DET_HSK_1) -- HS detection handshake: -- peripheral will drive chirp K
                          or (bus_event_state_r = BUS_EVENT_SW_WAKEUP_WF_CLK and      -- NOPID TX CMD
                          bus_event_state_nxt = BUS_EVENT_SW_WAKEUP_1) -- Remote Wake-up: -- peripheral will drive K to signal Resume
                          or (bus_event_state_r = BUS_EVENT_LPM_SW_WAKEUP_WF_CLK and      -- NOPID TX CMD
                          bus_event_state_nxt = BUS_EVENT_LPM_SW_WAKEUP_1) -- Remote Wake-up: -- peripheral will drive K to signal Resume
                          else '0';

clear_ulpi_tx_nopid_req <= '1' when (bus_event_state_r = BUS_EVENT_HS_DET_HSK_1 and      -- NOPID TX CMD
                          bus_event_state_nxt = BUS_EVENT_HS_DET_HSK_2) -- HS detection handshake: -- peripheral will stop driving chirp K
                          or (bus_event_state_r = BUS_EVENT_SW_WAKEUP_1 and      -- NOPID TX CMD
                          bus_event_state_nxt = BUS_EVENT_SW_WAKEUP_2) -- -- Remote Wake-up:: -- peripheral will stop driving K
                          or (bus_event_state_r = BUS_EVENT_LPM_SW_WAKEUP_1 and      -- NOPID TX CMD --BUS_EVENT_SW_WAKEUP_2 = BUS_EVENT_LPM_SW_WAKEUP_2
                          bus_event_state_nxt = BUS_EVENT_SW_WAKEUP_2)  -- Remote Wake-up:: -- peripheral will stop driving K
                          else '0';



set_ulpi_pwrst_det <= ulpi_pwrst_r and not ulpi_pwrst_r_s; -- end of power on reset is detected

ulpi_packet_idle <= '1' when packet_handling_state_r = USB_PROT_IDLE or (packet_handling_state_r = USB_PROT_WF_IDLE and ulpi_rxactive_r ='0') else
                    '0'; -- packet_handling_state_r does not move to USB_PROT_IDLE if bus_event_state_r = BUS_EVENT_INIT (device not attached yet)

-- main FSM
ulpi_oper_fsm_comb_proc: process (ulpi_oper_state_r,ulpi_dir_r,ulpi_dir_int,ulpi_nxt_r,ulpi_reg_access_req,
set_ulpi_tx_nopid_req,ulpi_reg_access_wr_i,txvalid_nxt,ulpi_turnaround,ulpi_pwrst_det_r,ulpi_ext_reg,
ulpi_tx_nopid_req_r,ulpi_arb_reg_nxt,clear_ulpi_tx_nopid_req,phy_mode,ulpi_dir_r_s,ulpi_nxt_int,ulpi_packet_idle,
suspendm_nxt,ulpi_pwrctrl_wakeup,ulpi_req_low_power_mode_r,ulpi_arb_reg_pending_r,ulpi_arb_reg_r,
ulpi_req_txcmd_fct_ctrl_susp_r )

begin
-- default values
ulpi_oper_state_nxt <= ulpi_oper_state_r;
set_ulpi_arb_reg_pending <= '0';
clear_ulpi_req_txcmd <= '0';
ulpi_stp_nxt <= '0';
clear_ulpi_pwrst_det <= '0';
set_ulpi_req_txcmd_fct_ctrl_reset <= '0';
set_ulpi_req_txcmd_int_stat <= '0';
set_ulpi_req_txcmd_dbg <= '0';
set_ulpi_req_txcmd_fct_ctrl_wr_oprst <= '0';
set_ulpi_req_txcmd_otg_ctrl_wr_oprst <= '0';
set_ulpi_async_mode <= '0';
clear_ulpi_async_mode <= '0';
set_ulpi_phy_endtoggle <= '0';
set_ulpi_reg_rdata_vld <= '0';
if phy_mode = '0'then -- UTMI Interface
   ulpi_oper_state_nxt <= ULPI_OPER_RESET_PWR_INIT;
else
   case ulpi_oper_state_r is

   when ULPI_OPER_RESET_PWR_INIT =>
      if ulpi_dir_int = '1' then -- ulpi_dir_r cannot be used if the clock is not running yet
         ulpi_stp_nxt <= '1'; -- force the PHY to holding state to protect its data inputs
      elsif ulpi_pwrst_det_r = '1' then -- end of power on reset
         clear_ulpi_pwrst_det <= '1';
         ulpi_stp_nxt <= '1'; -- force the PHY to holding state to protect its data inputs
         --ulpi_oper_state_nxt <= ULPI_OPER_RESET_IREG_WR_TX_CMD;
         set_ulpi_req_txcmd_fct_ctrl_reset <= '1';
         set_ulpi_arb_reg_pending <= '1';
      elsif ulpi_arb_reg_pending_r = '1'  then
            ulpi_oper_state_nxt <= ULPI_OPER_RESET_IREG_WR_TX_CMD;
      end if;
   when ULPI_OPER_RESET_IREG_WR_TX_CMD => -- Immediate Register Write access
      if ulpi_dir_r = '1' then -- reset cycle must restart
         ulpi_stp_nxt <= '1'; -- force the PHY to holding state to protect its data inputs
         ulpi_oper_state_nxt <= ULPI_OPER_RESET_PWR_INIT;
      elsif ulpi_nxt_int = '1' then
         ulpi_oper_state_nxt <= ULPI_OPER_RESET_REG_WR_TX_DATA;
      end if;

   when ULPI_OPER_RESET_REG_WR_TX_DATA => --  Register Write Data
      if ulpi_dir_r = '1' then -- reset cycle must restart
         ulpi_stp_nxt <= '1'; -- force the PHY to holding state to protect its data inputs
         ulpi_oper_state_nxt <= ULPI_OPER_RESET_PWR_INIT;
      elsif ulpi_nxt_int = '1' then
         ulpi_oper_state_nxt <= ULPI_OPER_RESET_WF_START_RESET_PHY;
         ulpi_stp_nxt <= '1';
         clear_ulpi_req_txcmd <= '1';
      end if;

   when ULPI_OPER_RESET_WF_START_RESET_PHY =>
      if ulpi_dir_r = '1' then
         ulpi_oper_state_nxt <= ULPI_OPER_RESET_WF_END_RESET_PHY;
      end if;

   when ULPI_OPER_RESET_WF_END_RESET_PHY =>
      if ulpi_dir_r = '0' then
         ulpi_oper_state_nxt <= ULPI_OPER_RESET_WF_RXCMD_UPDATE;
      end if;

   when ULPI_OPER_RESET_WF_RXCMD_UPDATE =>
      if ulpi_dir_r = '1' and ulpi_nxt_r = '0'  then  -- RXCMD is received
         ulpi_oper_state_nxt <= ULPI_OPER_RESET_CMD_RCV;
      end if;

   when ULPI_OPER_RESET_CMD_RCV =>
      if ulpi_dir_r = '0' then  -- End Of CMD
         ulpi_oper_state_nxt <= ULPI_OPER_IDLE;
         set_ulpi_req_txcmd_fct_ctrl_wr_oprst <= '1'; -- request update of opmode/termselect/xcvrselect and suspend (if required)
         set_ulpi_req_txcmd_otg_ctrl_wr_oprst <= '1'; -- request update of dppulldown/dmpulldown
     --    set_ulpi_req_txcmd_int_stat <= '1'; -- update vbusvalid  -- is it required, since vbusvalid should be updated via rxcmd ?
      end if;

   when ULPI_OPER_IDLE =>
-- An RX CMD has lower priority than USB receive or transmit data, but has higher priority than Register Read and Write commands.
-- register access via SW ulpi_arb_reg_nxt(ulpi_arb_reg_nxt'HIGH) = '1' has the lowest priority
-- in case of double event (device initiates a remote wake-up), TX_CMD (Reg Write) should occur before TX_CMD NOPID
      if ulpi_req_low_power_mode_r = '1' and ulpi_req_txcmd_fct_ctrl_susp_r = '0' then -- PHY has received the TX command to force the suspend
         ulpi_oper_state_nxt <= ULPI_OPER_LOW_POWER;
         set_ulpi_async_mode <= '1';
      elsif ulpi_dir_r = '1' then
         if ulpi_nxt_r = '1' then
            ulpi_oper_state_nxt <= ULPI_OPER_PKT_RCV;
         else
            ulpi_oper_state_nxt <= ULPI_OPER_CMD_RCV;
         end if;
      elsif ulpi_reg_access_req = '1' and ulpi_packet_idle = '1' and ulpi_arb_reg_pending_r = '0'then
         set_ulpi_arb_reg_pending <= '1';
      elsif ulpi_packet_idle = '1' and ulpi_arb_reg_pending_r = '1'and
         ulpi_arb_reg_r(ulpi_arb_reg_r'HIGH) = '0' then

      -- Register Tx Command inititated by HW: waiting for idle USB bus
         --set_ulpi_arb_reg_pending <= '1';
         if ulpi_reg_access_wr_i = '1' then --WRITE REGISTER
            if ulpi_ext_reg = '1' then -- EXTW Extended Register Write command. 8-bit address available in the next cycle
               ulpi_oper_state_nxt <= ULPI_OPER_XREG_WR_TX_CMD;
            else
               ulpi_oper_state_nxt <= ULPI_OPER_IREG_WR_TX_CMD; -- Immediate Register Write access
            end if;
         else               -- READ REGISTER
            if ulpi_ext_reg = '1' then -- EXTW Extended Register Read command. 8-bit address available in the next cycle
               ulpi_oper_state_nxt <= ULPI_OPER_XREG_RD_TX_CMD;
            else
               ulpi_oper_state_nxt <= ULPI_OPER_IREG_RD_TX_CMD; -- Immediate Register Read access
            end if;
         end if;
      elsif txvalid_nxt = '1' and (set_ulpi_tx_nopid_req = '1' or ulpi_tx_nopid_req_r = '1') then
         ulpi_oper_state_nxt <= ULPI_OPER_NOPID_TX_CMD;
      elsif txvalid_nxt = '1' then
         ulpi_oper_state_nxt <= ULPI_OPER_PID_TX_CMD;
      elsif ulpi_arb_reg_pending_r = '1' and ulpi_packet_idle = '1' and ulpi_arb_reg_nxt(ulpi_arb_reg_nxt'HIGH) = '1'then
      -- Register Tx Command initiated by SW: waiting for idle USB bus
         --set_ulpi_arb_reg_pending <= '1';
         if ulpi_reg_access_wr_i = '1' then --WRITE REGISTER
            if ulpi_ext_reg = '1' then -- EXTW Extended Register Write command. 8-bit address available in the next cycle
               ulpi_oper_state_nxt <= ULPI_OPER_XREG_WR_TX_CMD;
            else
               ulpi_oper_state_nxt <= ULPI_OPER_IREG_WR_TX_CMD; -- Immediate Register Write access
            end if;
         else               -- READ REGISTER
            if ulpi_ext_reg = '1' then -- EXTW Extended Register Read command. 8-bit address available in the next cycle
               ulpi_oper_state_nxt <= ULPI_OPER_XREG_RD_TX_CMD;
            else
               ulpi_oper_state_nxt <= ULPI_OPER_IREG_RD_TX_CMD; -- Immediate Register Read access
            end if;
         end if;
      end if;

   when ULPI_OPER_IREG_WR_TX_CMD => -- Immediate Register Write access
      if ulpi_dir_r = '1' then
         if ulpi_nxt_r = '1' then
            ulpi_oper_state_nxt <= ULPI_OPER_PKT_RCV;
         else
            ulpi_oper_state_nxt <= ULPI_OPER_CMD_RCV;
         end if;
      elsif ulpi_nxt_int = '1' then
         ulpi_oper_state_nxt <= ULPI_OPER_REG_WR_TX_DATA;
      end if;

   when ULPI_OPER_XREG_WR_TX_CMD =>  -- EXTW Extended Register Write command

      if ulpi_dir_r = '1' then
         if ulpi_nxt_r = '1' then
            ulpi_oper_state_nxt <= ULPI_OPER_PKT_RCV;
         else
            ulpi_oper_state_nxt <= ULPI_OPER_CMD_RCV;
         end if;
      elsif ulpi_nxt_int = '1' then
         ulpi_oper_state_nxt <= ULPI_OPER_XREG_WR_TX_ADD;
      end if;

   when ULPI_OPER_XREG_WR_TX_ADD => -- EXTW Extended Register Write Address
      if ulpi_dir_r = '1' then
         if ulpi_nxt_r = '1' then
            ulpi_oper_state_nxt <= ULPI_OPER_PKT_RCV;
         else
            ulpi_oper_state_nxt <= ULPI_OPER_CMD_RCV;
         end if;
      elsif ulpi_nxt_int = '1' then
         ulpi_oper_state_nxt <= ULPI_OPER_REG_WR_TX_DATA;
      end if;

   when ULPI_OPER_REG_WR_TX_DATA => --  Register Write Data (for both eXtended & Immediate register access)
      if ulpi_dir_int = '1' then
         if ulpi_nxt_int = '1' then
            ulpi_oper_state_nxt <= ULPI_OPER_PKT_RCV;
         else
            ulpi_oper_state_nxt <= ULPI_OPER_CMD_RCV;
         end if;
      elsif ulpi_nxt_int = '1' then
         ulpi_oper_state_nxt <= ULPI_OPER_REG_END_CYCLE;
         ulpi_stp_nxt <= '1';
         clear_ulpi_req_txcmd <= '1';
         if ulpi_ext_reg = '1' then -- End of Extended Register access
            set_ulpi_phy_endtoggle <= '1';
         end if;
      end if;

   when ULPI_OPER_IREG_RD_TX_CMD => -- Immediate Register Read access
      if ulpi_dir_r = '1' then
         if ulpi_nxt_r = '1' then
            ulpi_oper_state_nxt <= ULPI_OPER_PKT_RCV;
         else
            ulpi_oper_state_nxt <= ULPI_OPER_CMD_RCV;
         end if;
      elsif ulpi_nxt_int = '1' then
         ulpi_oper_state_nxt <= ULPI_OPER_REG_RD_TX_DATA;
      end if;

   when ULPI_OPER_XREG_RD_TX_CMD => -- EXTW Extended Register Read command
      if ulpi_dir_r = '1' then
         if ulpi_nxt_r = '1' then
            ulpi_oper_state_nxt <= ULPI_OPER_PKT_RCV;
         else
            ulpi_oper_state_nxt <= ULPI_OPER_CMD_RCV;
         end if;
      elsif ulpi_nxt_int = '1' then
         ulpi_oper_state_nxt <= ULPI_OPER_XREG_RD_TX_ADD;
      end if;

   when ULPI_OPER_XREG_RD_TX_ADD => -- EXTW Extended Register Read Address
      if ulpi_dir_r = '1' then
         if ulpi_nxt_r = '1' then
            ulpi_oper_state_nxt <= ULPI_OPER_PKT_RCV;
         else
            ulpi_oper_state_nxt <= ULPI_OPER_CMD_RCV;
         end if;
      elsif ulpi_nxt_int = '1' then
         ulpi_oper_state_nxt <= ULPI_OPER_REG_RD_TX_DATA;
      end if;

   when ULPI_OPER_REG_RD_TX_DATA => --  Register Read Data (for both eXtended & Immediate register access)
      if ulpi_dir_r = '1' and ulpi_nxt_r = '1' then
            ulpi_oper_state_nxt <= ULPI_OPER_PKT_RCV;
        -- else
        --    ulpi_oper_state_nxt <= ULPI_OPER_CMD_RCV;
         --end if;
      elsif ulpi_dir_r_s = '1' and ulpi_turnaround = '0' then
         ulpi_oper_state_nxt <= ULPI_OPER_REG_END_CYCLE;
         set_ulpi_reg_rdata_vld <= '1';
         clear_ulpi_req_txcmd <= '1';
         if ulpi_ext_reg = '1' then -- End of Extended Register access
            set_ulpi_phy_endtoggle <= '1';
         end if;
      end if;

   when ULPI_OPER_REG_END_CYCLE =>
      if ulpi_dir_r = '1' then
         if ulpi_nxt_r = '1' then
            ulpi_oper_state_nxt <= ULPI_OPER_PKT_RCV;
         else
            ulpi_oper_state_nxt <= ULPI_OPER_CMD_RCV;
         end if;
      else
         ulpi_oper_state_nxt <= ULPI_OPER_IDLE;
      end if;

   when ULPI_OPER_PKT_RCV =>
      if ulpi_dir_r = '0' then  -- End Of USB Packet
         ulpi_oper_state_nxt <= ULPI_OPER_IDLE;
      elsif ulpi_nxt_int = '0' then -- Rcv USB CMD
         ulpi_oper_state_nxt <= ULPI_OPER_CMD_RCV;
      end if;

   when ULPI_OPER_CMD_RCV =>
      if ulpi_dir_r = '0' then  -- End Of CMD
         ulpi_oper_state_nxt <= ULPI_OPER_IDLE;
      elsif ulpi_nxt_int = '1' then -- RCV command followed by Rcv USB Packet
         ulpi_oper_state_nxt <= ULPI_OPER_PKT_RCV;
      end if;

   when ULPI_OPER_NOPID_TX_CMD => -- pie transmits USB data that does not contain PID (chirp and resume signaling)
      if ulpi_dir_r = '1' then
         ulpi_oper_state_nxt <=  ULPI_OPER_PKT_RCV;
      elsif ulpi_nxt_int = '1' then
         ulpi_oper_state_nxt <= ULPI_OPER_NOPID_TX_DATA;
      end if;

   when ULPI_OPER_NOPID_TX_DATA => -- pie transmits USB data that does not contain PID (chirp and resume signaling)
      if ulpi_dir_r = '1' then
         ulpi_oper_state_nxt <=  ULPI_OPER_PKT_RCV;
      elsif clear_ulpi_tx_nopid_req= '1' then -- stops driving chirp K/resume signaling
        ulpi_oper_state_nxt <= ULPI_OPER_PKT_TX_END;
        ulpi_stp_nxt <= '1';
      end if;

   when ULPI_OPER_PID_TX_CMD => -- pie transmits USB packet that contains PID to the PHY
      if ulpi_dir_r = '1' then
         ulpi_oper_state_nxt <=  ULPI_OPER_PKT_RCV;
      elsif txvalid_nxt = '0' then -- end of transmitting packet -- packet is only one byte (Handshake PID)
        ulpi_oper_state_nxt <= ULPI_OPER_PKT_TX_END;
        ulpi_stp_nxt <= '1';
      elsif ulpi_nxt_int = '1' then
        ulpi_oper_state_nxt <= ULPI_OPER_PID_TX_DATA;
      end if;

   when ULPI_OPER_PID_TX_DATA => -- pie transmits USB packet that contains PID to the PHY
      if ulpi_dir_r = '1' then
         ulpi_oper_state_nxt <=  ULPI_OPER_PKT_RCV;
      elsif txvalid_nxt = '0' then -- end of transmitting packet
        ulpi_oper_state_nxt <= ULPI_OPER_PKT_TX_END;
        ulpi_stp_nxt <= '1';
      end if;

   when ULPI_OPER_PKT_TX_END => -- EOP
      ulpi_oper_state_nxt <= ULPI_OPER_IDLE;

   when ULPI_OPER_LOW_POWER =>
      if (suspendm_nxt = '1' or ulpi_pwrctrl_wakeup = '1') and ulpi_dir_r = '1' then
         ulpi_oper_state_nxt <=  ULPI_OPER_EXIT_LOW_POWER;
      end if;
   when ULPI_OPER_EXIT_LOW_POWER =>
      if ulpi_dir_r = '0' and ulpi_dir_r_s = '1' then   -- falling edge of ulpi_dir_r
      --(The Link de-asserts stp in the cycle following the deassertion of dir)
      -- stp can remain asserted for more than 1 clock cycle if the clock is not made available(due too PLL locking)
      -- should not be an issue for the phy
         clear_ulpi_async_mode <= '1';
         ulpi_oper_state_nxt <= ULPI_OPER_IDLE;
      end if;

   when others =>
      ulpi_oper_state_nxt <= ULPI_OPER_IDLE;

   end case;
end if;
end process ulpi_oper_fsm_comb_proc;

ulpi_oper_fsm_clk_proc : process (pie_clk, reset_n)

begin
   if reset_n = '0' then
      ulpi_oper_state_r <= ULPI_OPER_RESET_PWR_INIT;

   elsif pie_clk'event and pie_clk='1' then
      ulpi_oper_state_r <= ulpi_oper_state_nxt;
   end if;
end process ulpi_oper_fsm_clk_proc;

-- main FSM
ulpi_oper_decod_nxt_comb_proc: process (ulpi_oper_state_nxt,ulpi_reg_tx_addr,ulpi_tx_data_wr,txdata_nxt               )

begin
-- default values
   ulpi_txdata_nxt_i <= (others => '0');
   ulpi_stp_async <= '0';
   case ulpi_oper_state_nxt is
   when ULPI_OPER_RESET_PWR_INIT =>

   when ULPI_OPER_IDLE =>
-- An RX CMD has lower priority than USB receive or transmit data, but has higher priority than Register Read and Write commands.
      ulpi_txdata_nxt_i <= (others => '0');

   when ULPI_OPER_IREG_WR_TX_CMD|ULPI_OPER_RESET_IREG_WR_TX_CMD =>
      ulpi_txdata_nxt_i <=  "10"& ulpi_reg_tx_addr(5 downto 0);

   when ULPI_OPER_XREG_WR_TX_CMD =>
      ulpi_txdata_nxt_i <=  "10101111"; -- keeps register write command

   when ULPI_OPER_XREG_WR_TX_ADD =>
      ulpi_txdata_nxt_i <= ulpi_reg_tx_addr;

   when ULPI_OPER_REG_WR_TX_DATA|ULPI_OPER_RESET_REG_WR_TX_DATA =>
      ulpi_txdata_nxt_i <= ulpi_tx_data_wr;

   when ULPI_OPER_IREG_RD_TX_CMD =>
      ulpi_txdata_nxt_i <= "11"& ulpi_reg_tx_addr(5 downto 0);

   when ULPI_OPER_XREG_RD_TX_CMD =>
      ulpi_txdata_nxt_i <= "11101111";

   when ULPI_OPER_XREG_RD_TX_ADD =>
      ulpi_txdata_nxt_i <= ulpi_reg_tx_addr;

   when ULPI_OPER_REG_RD_TX_DATA => -- no data to transmit
      ulpi_txdata_nxt_i <= (others => '0') ;

   when ULPI_OPER_REG_END_CYCLE =>

   when ULPI_OPER_PKT_RCV =>

   when ULPI_OPER_CMD_RCV|ULPI_OPER_RESET_CMD_RCV =>

   when ULPI_OPER_NOPID_TX_CMD =>
      ulpi_txdata_nxt_i <= "01000000";

   when ULPI_OPER_NOPID_TX_DATA =>
      ulpi_txdata_nxt_i <= txdata_nxt; -- from bus event fsm

   when ULPI_OPER_PID_TX_CMD=>
      ulpi_txdata_nxt_i <= "0100" & txdata_nxt(3 downto 0); -- txdata_nxt(3 downto 0) = USB PID

   when ULPI_OPER_PID_TX_DATA =>
      ulpi_txdata_nxt_i <= txdata_nxt; -- from bus event fsm

   when ULPI_OPER_PKT_TX_END =>

   when ULPI_OPER_LOW_POWER =>

   when ULPI_OPER_EXIT_LOW_POWER =>
    --  if (suspendm_nxt = '1' or ulpi_pwrctrl_wakeup = '1') and ulpi_dir_r = '1' then
         ulpi_stp_async <= '1';
    --  end if;
   when others =>
      ulpi_txdata_nxt_i <= (others => '0') ;

   end case;

end process ulpi_oper_decod_nxt_comb_proc;

ulpi_reg_clk_proc : process(pie_clk,reset_n)
begin
   if reset_n = '0' then
      ulpi_rxactive_r <= '0';
      ulpi_rxerror_r <= '0';
      ulpi_linestate_r <= "00";
      ulpi_req_txcmd_fct_ctrl_reset_r <= '0';
      ulpi_req_txcmd_fct_ctrl_wr_r <= '0';
      ulpi_req_txcmd_fct_ctrl_susp_r <= '0';
      ulpi_req_txcmd_otg_ctrl_wr_r <= '0';
      ulpi_req_txcmd_int_stat_r <= '0';
      ulpi_req_txcmd_dbg_r <= '0';
      ulpi_req_xreg_wr_r <= '0';
      ulpi_req_xreg_rd_r <= '0';
      ulpi_tx_nopid_req_r <= '0';
      ulpi_pwrst_r <= '0';
      ulpi_pwrst_r_s <= '0';
      ulpi_pwrst_det_r <= '0';
      ulpi_arb_reg_r <= (others => '0');
      ulpi_vbusvalid_r <= '0';
      ulpi_req_low_power_mode_r <= '0';
      ulpi_async_mode_r <= '0';
      ulpi_arb_reg_pending_r <= '0';
      ulpi_xreg_rdata_r <= (others => '0');
   elsif pie_clk'event and pie_clk='1' then
      ulpi_pwrst_r <= '1';
      ulpi_pwrst_r_s <= ulpi_pwrst_r;
      -- end of power-on-reset information needs to be registered until ulpi_dir_int is de-asserted by the PHY
      if set_ulpi_pwrst_det = '1' then
         ulpi_pwrst_det_r <= '1';
      elsif clear_ulpi_pwrst_det = '1' then
         ulpi_pwrst_det_r <= '0';
      end if;
      if set_new_rxcmd = '1' then  -- update of registers via a RXCMD byte
         ulpi_rxactive_r <= ulpi_rxactive_cmd;
         ulpi_rxerror_r <= ulpi_rxerror_cmd;
         ulpi_linestate_r <= ulpi_linestate_cmd;
         ulpi_vbusvalid_r <= ulpi_vbusvalid_cmd;
      elsif set_ulpi_rxactive_line = '1' then  -- update of rxactive when dir was previously low
         ulpi_rxactive_r <= '1';
      elsif ulpi_dir_r = '0' and ulpi_dir_r_s = '1' then   -- falling edge of ulpi_dir_r
         ulpi_rxactive_r <= '0';
      end if;
      if set_ulpi_req_txcmd_fct_ctrl_reset = '1' then
         ulpi_req_txcmd_fct_ctrl_reset_r <= '1';
      elsif clear_ulpi_req_txcmd = '1' and ulpi_arb_reg_r = ULPI_ARB_FCTCTRL_REG_RESET then
         ulpi_req_txcmd_fct_ctrl_reset_r <= '0';
      end if;
      if set_ulpi_req_txcmd_fct_ctrl_wr = '1' or set_ulpi_req_txcmd_fct_ctrl_wr_oprst = '1' then
         ulpi_req_txcmd_fct_ctrl_wr_r <= '1';
      elsif clear_ulpi_req_txcmd = '1' and ulpi_arb_reg_r = ULPI_ARB_FCTCTRL_REG_WR then
         ulpi_req_txcmd_fct_ctrl_wr_r <= '0';
      end if;
      if set_ulpi_req_txcmd_fct_ctrl_susp = '1' then
        ulpi_req_txcmd_fct_ctrl_susp_r <= '1';
      elsif clear_ulpi_req_txcmd = '1' and ulpi_arb_reg_r = ULPI_ARB_FCTCTRL_REG_SUSP then
         ulpi_req_txcmd_fct_ctrl_susp_r <= '0';
      end if;
      if set_ulpi_req_txcmd_otg_ctrl_wr_oprst = '1' then
         ulpi_req_txcmd_otg_ctrl_wr_r <= '1';
      elsif clear_ulpi_req_txcmd = '1' and ulpi_arb_reg_r = ULPI_ARB_OTGCTRL_REG_WR then
         ulpi_req_txcmd_otg_ctrl_wr_r <= '0';
      end if;
      if set_ulpi_req_txcmd_int_stat = '1' then
         ulpi_req_txcmd_int_stat_r <= '1';
      elsif clear_ulpi_req_txcmd = '1' and ulpi_arb_reg_r = ULPI_ARB_INT_REG_RD then
         ulpi_req_txcmd_int_stat_r <= '0';
      end if;
      if set_ulpi_req_txcmd_dbg = '1' then
         ulpi_req_txcmd_dbg_r <= '1';
      elsif clear_ulpi_req_txcmd = '1' and ulpi_arb_reg_r = ULPI_ARB_DBG_REG_RD then
         ulpi_req_txcmd_dbg_r <= '0';
      end if;
      if set_ulpi_req_xreg_wr = '1' then
         ulpi_req_xreg_wr_r <= '1';
      elsif clear_ulpi_req_txcmd = '1' and ulpi_arb_reg_r = ULPI_ARB_XREG_WR then
         ulpi_req_xreg_wr_r <= '0';
      end if;
      if set_ulpi_req_xreg_rd = '1' then
          ulpi_req_xreg_rd_r <= '1';
      elsif clear_ulpi_req_txcmd = '1' and ulpi_arb_reg_r = ULPI_ARB_XREG_RD then
          ulpi_req_xreg_rd_r <= '0';
      end if;
      if set_ulpi_arb_reg_pending = '1' then  -- pending register name needs to be memorized
         ulpi_arb_reg_r <= ulpi_arb_reg_nxt;
         ulpi_arb_reg_pending_r <= '1';
      elsif clear_ulpi_req_txcmd = '1' then
         ulpi_arb_reg_r <= (others => '0');
         ulpi_arb_reg_pending_r <= '0';
      end if;
      if set_ulpi_tx_nopid_req = '1' then
         ulpi_tx_nopid_req_r <= '1';
      elsif clear_ulpi_tx_nopid_req = '1' then
         ulpi_tx_nopid_req_r <= '0';
      end if;
      -- low power mode specific (set has priority to clear):
      if set_ulpi_req_low_power_mode = '1' then
         ulpi_req_low_power_mode_r <= '1';
      elsif clear_ulpi_req_low_power_mode = '1' then
         ulpi_req_low_power_mode_r <= '0';
      end if;
      if set_ulpi_async_mode = '1' then
         ulpi_async_mode_r <= '1';
      elsif clear_ulpi_async_mode = '1' then
         ulpi_async_mode_r <= '0';
      end if;
      -- ext registers access
      if set_ulpi_reg_rdata_vld = '1' and ulpi_ext_reg = '1' then
         ulpi_xreg_rdata_r <= ulpi_rxdata_r; -- read data needs to be hold until next phy_start pulse. ulpi_rxdata_r can have changed in the meantime
      end if;
   end if;
end process ulpi_reg_clk_proc;





--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------
--               ULPI SPECIFIC (end)                        --
--------------------------------------------------------------
--------------------------------------------------------------


--fpga debug


  usb_pie_fpga(4 downto 0) <= "00000" when bus_event_state_r = BUS_EVENT_INIT else --0x00
                            "00001" when bus_event_state_r = BUS_EVENT_FS_IDLE else --0x01
                            "00010" when bus_event_state_r = BUS_EVENT_FS_ACTIVE else --0x02
                            "00011" when bus_event_state_r = BUS_EVENT_HS_IDLE else --0x03
                            "00100" when bus_event_state_r = BUS_EVENT_HS_ACTIVE else --0x04
                            "00101" when bus_event_state_r = BUS_EVENT_WF_SUSPEND_OR_RST else --0x05
                            "00110" when bus_event_state_r = BUS_EVENT_RESET else --0x06
                            "00111" when bus_event_state_r = BUS_EVENT_WF_SUSPEND else --0x07
                            "01000" when bus_event_state_r = BUS_EVENT_SUSPEND else --0x08
                            "01001" when bus_event_state_r = BUS_EVENT_SW_WAKEUP_1 else --0x09
                            "01010" when bus_event_state_r = BUS_EVENT_SW_WAKEUP_2 else --0x0A
                            "01011" when bus_event_state_r = BUS_EVENT_SW_WAKEUP_3 else --0x0B
                            "01100" when bus_event_state_r = BUS_EVENT_HOST_RESUME else --0x0C
                            "01101" when bus_event_state_r = BUS_EVENT_WF_EOR_FS else --0x0D
                            "01110" when bus_event_state_r = BUS_EVENT_HS_DET_HSK_1 else --0x0E
                            "01111" when bus_event_state_r = BUS_EVENT_HS_DET_HSK_2 else --0x0F
                            "10000" when bus_event_state_r = BUS_EVENT_HS_DET_HSK_3 else --0x10
                            "10001" when bus_event_state_r = BUS_EVENT_HS_DET_HSK_4 else --0x11
                            "10010" when bus_event_state_r = BUS_EVENT_WF_ENDCHIRP_HS else --0x12
                            "10011" when bus_event_state_r = BUS_EVENT_TEST_MODE else --0x13
                            "10100" when bus_event_state_r = BUS_EVENT_LPM_SUSPEND_L1 else --0x14
                            "10101" when bus_event_state_r = BUS_EVENT_LPM_SW_WAKEUP_1 else --0x15
                            "10110" when bus_event_state_r = BUS_EVENT_SW_WAKEUP_WF_CLK else --0x16
                            "10111";-- when bus_event_state_r = BUS_EVENT_LPM_SW_WAKEUP_WF_CLK else --0x17





  usb_pie_fpga(10 downto 5) <= "000000" when packet_handling_state_r = USB_PROT_IDLE else --0x00
                            "000001" when packet_handling_state_r = USB_PROT_WF_IDLE else --0x01
                            "000010" when packet_handling_state_r = USB_PROT_WF_TOKEN_PID else --0x02
                            "000011" when packet_handling_state_r = USB_PROT_WF_TOKEN_BYTE2 else --0x03
                            "000100" when packet_handling_state_r = USB_PROT_WF_TOKEN_BYTE3 else --0x04
                            "000101" when packet_handling_state_r = USB_PROT_IN_WF_EOP else --0x05
                            "000110" when packet_handling_state_r = USB_PROT_IN_WF_EP_INFO_VALID else --0x06
                            "000111" when packet_handling_state_r = USB_PROT_OUT_SETUP_WF_EOP else --0x07
                            "001000" when packet_handling_state_r = USB_PROT_OUT_SETUP_WF_EP_INFO_VALID else --0x08
                            "001001" when packet_handling_state_r = USB_PROT_PING_WF_EOP else --0x09
                            "001010" when packet_handling_state_r = USB_PROT_PING_WF_EP_INFO_VALID else --0x0A
                            "001101" when packet_handling_state_r = USB_PROT_OUT_SETUP_PING_WF_TX_ACK_HANDSHAKE else --0x0D
                            "001110" when packet_handling_state_r = USB_PROT_OUT_SETUP_PING_TX_ACK_HANDSHAKE else --0x0E
                            "001111" when packet_handling_state_r = USB_PROT_IN_OUT_PING_WF_TX_NAK_HANDSHAKE else --0x0F
                            "010000" when packet_handling_state_r = USB_PROT_IN_OUT_PING_TX_NAK_HANDSHAKE else --0x10
                            "010001" when packet_handling_state_r = USB_PROT_IN_OUT_PING_WF_TX_STALL_HANDSHAKE else --0x11
                            "010010" when packet_handling_state_r = USB_PROT_IN_OUT_PING_TX_STALL_HANDSHAKE else --0x12
                            "010011" when packet_handling_state_r = USB_PROT_ALL_WF_END_TX_PACKET else --0x13
                            "010100" when packet_handling_state_r = USB_PROT_OUT_SETUP_WF_RX_DATA_PID else --0x14
                            "010101" when packet_handling_state_r = USB_PROT_OUT_SETUP_RCV_DATA_PACKET else --0x15
                            "010110" when packet_handling_state_r = USB_PROT_IN_TX_DATA_PID_1 else --0x16
                            "010111" when packet_handling_state_r = USB_PROT_IN_TX_DATA_PACKET else --0x17
                            "011000" when packet_handling_state_r = USB_PROT_IN_TX_CRC16_BYTE1 else --0x18
                            "011001" when packet_handling_state_r = USB_PROT_IN_TX_CRC16_BYTE2 else --0x19
                            "011010" when packet_handling_state_r = USB_PROT_BAD_IN_TX_CRC16_BYTE1 else --0x1A
                            "011011" when packet_handling_state_r = USB_PROT_BAD_IN_TX_CRC16_BYTE2 else --0x1B
                            "011100" when packet_handling_state_r = USB_PROT_IN_TX_DATA_PID_2 else --0x1C
                            "011101" when packet_handling_state_r = USB_PROT_OUT_WF_TX_NYET_HANDSHAKE else --0x1D
                            "011110" when packet_handling_state_r = USB_PROT_OUT_TX_NYET_HANDSHAKE else --0x1E
                            "011111" when packet_handling_state_r = USB_PROT_TX_TEST_PACKET else --0x1F
                            "100000" when packet_handling_state_r = USB_PROT_WF_END_TX_TEST_PACKET else --0x20
                            "100001" when packet_handling_state_r = USB_PROT_WF_TX_TEST_PACKET else --0x21
                            "100010" when packet_handling_state_r = USB_PROT_IN_WF_RX_HANDSHAKE else--0x22
                            "100011" when packet_handling_state_r = USB_PROT_WF_EXT_TOKEN_PID else--0x23
                            "100100" when packet_handling_state_r = USB_PROT_WF_EXT_TOKEN_BYTE2 else--0x24
                            "100101";-- when packet_handling_state_r = USB_PROT_WF_EXT_TOKEN_BYTE3 else--0x25


  usb_pie_fpga(11) <= '0' when dev_speed_r = USB_FULL_SPEED else '1';


  usb_pie_fpga(16 downto 12) <= "00000" when bus_event_state_nxt = BUS_EVENT_INIT else --0x00
                            "00001" when bus_event_state_nxt = BUS_EVENT_FS_IDLE else --0x01
                            "00010" when bus_event_state_nxt = BUS_EVENT_FS_ACTIVE else --0x02
                            "00011" when bus_event_state_nxt = BUS_EVENT_HS_IDLE else --0x03
                            "00100" when bus_event_state_nxt = BUS_EVENT_HS_ACTIVE else --0x04
                            "00101" when bus_event_state_nxt = BUS_EVENT_WF_SUSPEND_OR_RST else --0x05
                            "00110" when bus_event_state_nxt = BUS_EVENT_RESET else --0x06
                            "00111" when bus_event_state_nxt = BUS_EVENT_WF_SUSPEND else --0x07
                            "01000" when bus_event_state_nxt = BUS_EVENT_SUSPEND else --0x08
                            "01001" when bus_event_state_nxt = BUS_EVENT_SW_WAKEUP_1 else --0x09
                            "01010" when bus_event_state_nxt = BUS_EVENT_SW_WAKEUP_2 else --0x0A
                            "01011" when bus_event_state_nxt = BUS_EVENT_SW_WAKEUP_3 else --0x0B
                            "01100" when bus_event_state_nxt = BUS_EVENT_HOST_RESUME else --0x0C
                            "01101" when bus_event_state_nxt = BUS_EVENT_WF_EOR_FS else --0x0D
                            "01110" when bus_event_state_nxt = BUS_EVENT_HS_DET_HSK_1 else --0x0E
                            "01111" when bus_event_state_nxt = BUS_EVENT_HS_DET_HSK_2 else --0x0F
                            "10000" when bus_event_state_nxt = BUS_EVENT_HS_DET_HSK_3 else --0x10
                            "10001" when bus_event_state_nxt = BUS_EVENT_HS_DET_HSK_4 else --0x11
                            "10010" when bus_event_state_nxt = BUS_EVENT_WF_ENDCHIRP_HS else --0x12
                            "10011" when bus_event_state_nxt = BUS_EVENT_TEST_MODE else --0x13
                            "10100" when bus_event_state_nxt = BUS_EVENT_LPM_SUSPEND_L1 else --0x14
                            "10101" when bus_event_state_nxt = BUS_EVENT_LPM_SW_WAKEUP_1 else --0x15
                            "10110" when bus_event_state_nxt = BUS_EVENT_SW_WAKEUP_WF_CLK else --0x16
                            "10111";-- when bus_event_state_nxt = BUS_EVENT_LPM_SW_WAKEUP_WF_CLK else --0x17



  usb_pie_fpga(21 downto 17) <= "00000" when ulpi_oper_state_r = ULPI_OPER_RESET_PWR_INIT else --0x00
                            "00001" when ulpi_oper_state_r = ULPI_OPER_RESET_IREG_WR_TX_CMD else --0x01
                            "00010" when ulpi_oper_state_r = ULPI_OPER_RESET_REG_WR_TX_DATA else --0x02
                            "00011" when ulpi_oper_state_r = ULPI_OPER_RESET_WF_START_RESET_PHY else --0x03
                            "00100" when ulpi_oper_state_r = ULPI_OPER_RESET_WF_END_RESET_PHY else --0x04
                            "00101" when ulpi_oper_state_r = ULPI_OPER_RESET_WF_RXCMD_UPDATE else --0x05
                            "00110" when ulpi_oper_state_r = ULPI_OPER_RESET_CMD_RCV else --0x06
                            "00111" when ulpi_oper_state_r = ULPI_OPER_IDLE else --0x07
                            "01000" when ulpi_oper_state_r = ULPI_OPER_IREG_WR_TX_CMD else --0x08
                            "01001" when ulpi_oper_state_r = ULPI_OPER_XREG_WR_TX_CMD else --0x09
                            "01010" when ulpi_oper_state_r = ULPI_OPER_XREG_WR_TX_ADD else --0x0A
                            "01011" when ulpi_oper_state_r = ULPI_OPER_REG_WR_TX_DATA else --0x0B
                            "01100" when ulpi_oper_state_r = ULPI_OPER_IREG_RD_TX_CMD else --0x0C
                            "01101" when ulpi_oper_state_r = ULPI_OPER_XREG_RD_TX_CMD else --0x0D
                            "01110" when ulpi_oper_state_r = ULPI_OPER_XREG_RD_TX_ADD else --0x0E
                            "01111" when ulpi_oper_state_r = ULPI_OPER_REG_RD_TX_DATA else --0x0F
                            "10000" when ulpi_oper_state_r = ULPI_OPER_REG_END_CYCLE else --0x10
                            "10001" when ulpi_oper_state_r = ULPI_OPER_CMD_RCV else --0x11
                            "10010" when ulpi_oper_state_r = ULPI_OPER_PKT_RCV else --0x12
                            "10011" when ulpi_oper_state_r = ULPI_OPER_NOPID_TX_CMD else --0x13
                            "10100" when ulpi_oper_state_r = ULPI_OPER_NOPID_TX_DATA else --0x14
                            "10101" when ulpi_oper_state_r = ULPI_OPER_PID_TX_CMD else --0x15
                            "10110" when ulpi_oper_state_r = ULPI_OPER_PID_TX_DATA else --0x16
                            "10111" when ulpi_oper_state_r = ULPI_OPER_PKT_TX_END else --0x17
                            "11000" when ulpi_oper_state_r = ULPI_OPER_LOW_POWER else --0x18
                            "11001";-- when ulpi_oper_state_r = ULPI_OPER_EXIT_LOW_POWER else --0x19


  usb_pie_fpga(26 downto 22) <= "00000" when ulpi_oper_state_nxt = ULPI_OPER_RESET_PWR_INIT else --0x00
                            "00001" when ulpi_oper_state_nxt = ULPI_OPER_RESET_IREG_WR_TX_CMD else --0x01
                            "00010" when ulpi_oper_state_nxt = ULPI_OPER_RESET_REG_WR_TX_DATA else --0x02
                            "00011" when ulpi_oper_state_nxt = ULPI_OPER_RESET_WF_START_RESET_PHY else --0x03
                            "00100" when ulpi_oper_state_nxt = ULPI_OPER_RESET_WF_END_RESET_PHY else --0x04
                            "00101" when ulpi_oper_state_nxt = ULPI_OPER_RESET_WF_RXCMD_UPDATE else --0x05
                            "00110" when ulpi_oper_state_nxt = ULPI_OPER_RESET_CMD_RCV else --0x06
                            "00111" when ulpi_oper_state_nxt = ULPI_OPER_IDLE else --0x07
                            "01000" when ulpi_oper_state_nxt = ULPI_OPER_IREG_WR_TX_CMD else --0x08
                            "01001" when ulpi_oper_state_nxt = ULPI_OPER_XREG_WR_TX_CMD else --0x09
                            "01010" when ulpi_oper_state_nxt = ULPI_OPER_XREG_WR_TX_ADD else --0x0A
                            "01011" when ulpi_oper_state_nxt = ULPI_OPER_REG_WR_TX_DATA else --0x0B
                            "01100" when ulpi_oper_state_nxt = ULPI_OPER_IREG_RD_TX_CMD else --0x0C
                            "01101" when ulpi_oper_state_nxt = ULPI_OPER_XREG_RD_TX_CMD else --0x0D
                            "01110" when ulpi_oper_state_nxt = ULPI_OPER_XREG_RD_TX_ADD else --0x0E
                            "01111" when ulpi_oper_state_nxt = ULPI_OPER_REG_RD_TX_DATA else --0x0F
                            "10000" when ulpi_oper_state_nxt = ULPI_OPER_REG_END_CYCLE else --0x10
                            "10001" when ulpi_oper_state_nxt = ULPI_OPER_CMD_RCV else --0x11
                            "10010" when ulpi_oper_state_nxt = ULPI_OPER_PKT_RCV else --0x12
                            "10011" when ulpi_oper_state_nxt = ULPI_OPER_NOPID_TX_CMD else --0x13
                            "10100" when ulpi_oper_state_nxt = ULPI_OPER_NOPID_TX_DATA else --0x14
                            "10101" when ulpi_oper_state_nxt = ULPI_OPER_PID_TX_CMD else --0x15
                            "10110" when ulpi_oper_state_nxt = ULPI_OPER_PID_TX_DATA else --0x16
                            "10111" when ulpi_oper_state_nxt = ULPI_OPER_PKT_TX_END else --0x17
                            "11000" when ulpi_oper_state_nxt = ULPI_OPER_LOW_POWER else --0x18
                            "11001";-- when ulpi_oper_state_nxt = ULPI_OPER_EXIT_LOW_POWER else --0x19

usb_pie_fpga(27) <= new_sof_vld;
usb_pie_fpga(28) <= new_inoutsetup_vld;

usb_pie_fpga(36 downto 29) <= rxdata;
usb_pie_fpga(37) <= rxactive;
usb_pie_fpga(38) <= rxvalid;
usb_pie_fpga(39) <= rxerror;
usb_pie_fpga(40) <= epinfo_txdata_valid;
usb_pie_fpga(41) <= epinfo_valid;
usb_pie_fpga(42) <= epinfo_req_r;
usb_pie_fpga(43) <= pie_error_r;
usb_pie_fpga(47 downto 44) <= errortype;
usb_pie_fpga(48) <= sop_start;
usb_pie_fpga(49) <= req_handshake_r;
usb_pie_fpga(56 downto 50) <= std_logic_vector(to_unsigned(timer_packet_handling_r,7));
usb_pie_fpga(58 downto 57) <= linestate;
usb_pie_fpga(60 downto 59) <= ls_filt;
usb_pie_fpga(61) <= sop_det_r;
usb_pie_fpga(63 downto 62) <=std_logic_vector(to_unsigned(pie_dev_selected_int,2));

end RTL;
