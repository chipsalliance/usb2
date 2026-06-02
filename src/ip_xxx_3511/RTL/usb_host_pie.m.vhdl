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
--   COPYRIGHT (c) NXP B.V. 2011
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
--               File: usb_host_pie.m.vhdl
--
--             Author: Gaetan Marsin
--
--       Organisation: Corporate I&T / IP & Architecture
--
--              $Date: Wed May 29 12:25:34 2019 $
--
--            Project: IP_3515_hs - Low gate count HS USB Host IP
--
--        Description:
--
--          $Revision: 1.13 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_host_pie.m.vhdl.rca $
--   
--    Revision: 1.13 Wed May 29 12:25:34 2019 usb00219
--    Added chicken bit for CDC crossing fix made for artf663122. Updates from Soong.
--    
--
--    Revision: 1.67 Wed Jan  9 17:21:37 2013 beq03196
--    Increase T_TSE0EOR duration to match SMS PHy requirements.
--    utmi_rxerror is only taken into account when rxactive is high (prevent iussue after remote wake-up sent by device).
--    Interpacket delay depending on port speed for Special token.
--
--    Revision: 1.66 Mon Dec  3 10:31:59 2012 beq03196
--    PR#67 fix: host_traffic_24: unexpected bytes in ISO OUT HBW packet.
--
--    Revision: 1.65 Wed Aug  1 11:47:35 2012 beq03099
--    utmi_vcontrolloadm is an active low signal
--
--    Revision: 1.64 Thu Jun 21 16:23:04 2012 beq03196
--    fix PR#65: fpga: 3515 at 35 MHz, Dword number 3 of data payload incorrect
--
--    Revision: 1.63 Fri Jun 15 16:13:15 2012 beq03196
--    fix PR#63: host_traffic_28: data toogle mismatch on fs iso in, X bit set
--
--    Revision: 1.62 Mon Jun  4 17:36:46 2012 beq03196
--    Fix PR#57: Host_power_12 ulpi : L1 host resume never ends
--
--    Revision: 1.61 Thu May 31 11:08:39 2012 beq03196
--    bug fix PR#48:host_port_7 ulpi: no test data packet send on usb
--
--    Revision: 1.60 Wed May 30 16:03:29 2012 beq03196
--    fix PR53:host power 12: Host Resume time is fixed to 6000 T
--
--    Revision: 1.59 Wed May 30 15:50:16 2012 beq03196
--    fix PR#45:host_traffic_24 : SSplit ISO out after a HBW ISO out not working
--
--    Revision: 1.58 Wed May 30 09:01:55 2012 beq03196
--    Fix PR#51 (2nd part): FPGA UTMI LS mouse on FS hub colide
--
--    Revision: 1.57 Wed May 30 08:33:06 2012 beq03196
--    Fix PR#42 (2nd part): host_traffc_30: data words get lost
--
--    Revision: 1.56 Wed May 23 15:23:05 2012 beq03196
--    update debug FPGA signals + Fix PR#51 (typo fixed): FPGA UTMI LS mouse on FS hub colide
--
--    Revision: 1.55 Wed May 23 09:43:56 2012 beq03196
--    Fix PR#51: FPGA UTMI LS mouse on FS hub colide
--
--    Revision: 1.54 Tue May 22 13:39:55 2012 beq03196
--    Fix PR#44: host_power_12: lpm token ack but no suspend
--
--    Revision: 1.53 Mon May 21 15:29:09 2012 beq03196
--    Fix PR# 39: suspend L2 asserted: possible data packet corruption
--
--    Revision: 1.52 Mon May 14 15:16:48 2012 beq03196
--    fix PR46: ulpi disconnected device: usb clock does not stop when run bit is 0
--
--    Revision: 1.51 Fri May 11 13:45:03 2012 beq03196
--    fix PR#42: ip_3511 : host_traffc_30: data words get lost
--
--    Revision: 1.50 Thu May 10 16:26:53 2012 beq03196
--    fix PR#41:host_power_11: overcurrent
--
--    Revision: 1.49 Thu May 10 15:35:09 2012 beq03067
--    added overcurrent input
--
--    Revision: 1.48 Thu May 10 11:14:04 2012 beq03196
--    Fix PR#40: host_traffic_29: unexpected babble error
--
--    Revision: 1.47 Mon May  7 16:34:23 2012 beq03196
--    fix for PR#35:host_power_1: suspendm stuck at 1 when device is not connected
--    fix for PR#36: force port resume : not sw controlled
--    fix for PR#37: end of HS resume, utmi_termselect & utmi_xcvrselect issue
--    fix for PR#38: port sc suspend bit 7
--
--    Revision: 1.46 Mon May  7 11:51:56 2012 beq03099
--    fixed problem with low power implementation
--
--
--    Revision: 1.45 Thu Apr 26 08:58:17 2012 beq03196
--    Fix PR#33: host lock after many connect/disconnect samsung, dma stuck in TX data state
--
--    Revision: 1.44 Wed Apr 25 17:03:49 2012 beq03067
--    added vbus debounce i nthe sensitivity list
--
--    Revision: 1.43 Wed Apr 25 16:05:51 2012 beq03196
--    fix PR#9: Add a check on vbus valid (Bvalid) in the host_pie
--
--    Revision: 1.42 Wed Apr 25 10:49:04 2012 beq03196
--    fix PR#29: 3515_hs_mem on FPGA: Second port reset sequence issue
--
--    Revision: 1.41 Wed Apr 25 10:07:41 2012 beq03196
--    update after code review.
--
--    Revision: 1.40 Thu Apr 12 14:02:05 2012 beq03099
--    Finished LPM implementation
--
--    Revision: 1.39 Thu Apr  5 15:23:23 2012 beq03196
--    add host ctrl reset for  ulpi_oper_fsm_clk_proc process
--
--    Revision: 1.38 Wed Apr  4 14:44:13 2012 beq03067
--    added ulpi state machine on fpga debug
--
--    Revision: 1.37 Wed Apr  4 11:11:24 2012 beq03067
--    added bus event power state in the fpga debug
--
--    Revision: 1.36 Tue Apr  3 14:49:01 2012 beq03196
--    Fix PR#25: host_traffic_17: split interrupt in, nrbytestransferred 854 bytes iso 1024 bytes
--
--    Revision: 1.35 Fri Mar 30 10:29:18 2012 beq03196
--    FIX CR#9: Add a check on vbus valid (Bvalid) in the host_pie + Filtering option on vbus
--
--    Revision: 1.34 Wed Mar 28 15:25:16 2012 beq03196
--    fix PR#16: host_traffic_27 : host must send ACK when a data toggle mismatch occurs
--
--    Revision: 1.33 Wed Mar 28 08:25:53 2012 beq03196
--    Fix PR#19:host_traffic_16: split INT OUT and PR#21 host_traffic_18: LS interrupt OUT: no complete split sent at uF 4
--
--    Revision: 1.32 Tue Mar 27 16:17:48 2012 beq03196
--    fix PR#17: host_traffic_24 : pie_rx_nbytes is not updated for complete split transactions
--
--    Revision: 1.31 Tue Mar 27 11:42:36 2012 beq03196
--    LPM is implemented.
--
--    Revision: 1.30 Fri Mar 23 14:07:24 2012 beq03196
--    add 1 clk period before asserting txvalid when xcvrselect goes to "11" (Preamble)
--
--    Revision: 1.29 Fri Mar 23 11:32:59 2012 beq03196
--    Add preamble handling.
--
--    Revision: 1.28 Thu Mar 22 10:41:26 2012 beq03196
--    FIX PR#15: host_traffic_12: 3 out token instead of 2
--
--    Revision: 1.27 Tue Mar 20 13:55:42 2012 beq03196
--    Fix PR# 14: host_traffic_24 : Time between split token and out/in token too long
--
--    Revision: 1.26 Tue Mar 20 12:36:13 2012 beq03196
--    fix PR12:  host_traffic_12 HBW ISO, data packet 2 and 3 are missing
--
--    Revision: 1.25 Mon Mar 19 16:31:01 2012 beq03196
--    fix CRC5 calculation for split transactions.
--
--    Revision: 1.24 Mon Mar 19 14:50:37 2012 beq03196
--    iso_rcv_transact_cnt_up must be updated at the end of a successfull transaction.
--
--    Revision: 1.23 Mon Mar 19 11:41:27 2012 beq03196
--    iso out: clear pending txtransfer for last transaction.
--
--    Revision: 1.22 Mon Mar 19 09:33:09 2012 beq03196
--    SPLIT transactions are implemented.
--
--    Revision: 1.21 Wed Mar 14 14:05:01 2012 beq03196
--    Iso is implemented + add interpacket delay between unrealted transactions
--
--    Revision: 1.20 Mon Mar 12 15:04:50 2012 beq03196
--    testpacket correction.
--
--    Revision: 1.19 Mon Mar 12 10:53:47 2012 beq03196
--    add low speed device attached on a low speed port
--
--    Revision: 1.18 Mon Mar 12 10:14:30 2012 beq03196
--    usbreg_phy_test_mode can be reduced to 3 bits width. shortcut to  specific sport speed is not required anymore.
--
--    Revision: 1.17 Fri Mar  9 11:57:17 2012 beq03196
--    req_rx_pkt_r was still set at the end of the transmitted ACK (after an IN packet)
--
--    Revision: 1.16 Fri Mar  9 10:49:51 2012 beq03196
--    bus_event_timer is not used for timeout protection anymore + add fpga debug signals.
--
--    Revision: 1.15 Fri Mar  9 09:48:29 2012 beq03196
--    set_pie_response was missing at 2 places when pie_response_int was updated
--
--    Revision: 1.14 Fri Mar  9 08:16:40 2012 beq03099
--    fixed problem with starttransfer_pending
--
--    Revision: 1.13 Thu Mar  8 16:14:48 2012 beq03196
--    Fix PR#5(host_traffic_1 : time between HS OUT token and HS OUT data is too long) and fix PR#6:host_traffic_1 : NAK handshake not recognized by host_pie block
--
--    Revision: 1.12 Thu Mar  8 13:52:44 2012 beq03196
--    fix PR#7: endtransfer timing.
--
--    Revision: 1.11 Tue Mar  6 14:17:40 2012 beq03196
--    receiving data packet mechanism is implemented + endtransfer at the end of sof is removed
--
--    Revision: 1.10 Fri Mar  2 12:01:12 2012 beq03196
--    bug fix PR#2: Range Constraint Violation in ...usb_host_pie_1:linestate_filter_clk_proc
--
--    Revision: 1.9 Thu Mar  1 16:51:03 2012 beq03196
--    Fix PR#1: utmi_hostdisconnect should only be used during high-speed mode
--
--    Revision: 1.8 Thu Mar  1 15:26:20 2012 beq03196
--    transmitted data packet mechanism (1st version) is implemented + Test packet
--
--    Revision: 1.7 Tue Feb 28 12:29:19 2012 beq03196
--    Correct xcvrselect for Low Speed reset and TDCHSEO (force IDLE state at the end of chirp sequence )
--
--    Revision: 1.6 Tue Feb 28 10:10:17 2012 beq03196
--    HS detection: EOR must not clear the bus_event timers.
--
--    Revision: 1.5 Fri Feb 24 15:53:56 2012 beq03196
--    add end_transfer pulse at the end of the SOF generation
--
--    Revision: 1.4 Thu Feb 23 12:11:50 2012 beq03196
--    add generation of SOF and ULPI Interface
--
--    Revision: 1.3 Fri Feb 17 12:32:09 2012 beq03099
--    Added back usbreg_portenable_clear_sync
--
--    Revision: 1.2 Fri Feb 17 11:44:36 2012 beq03196
--    adapted after 1st revision of bus event FSM
--
--    Revision: 1.1 Tue Feb 14 17:23:50 2012 beq03196
--    1st version.
--
--
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY rtl;
USE rtl.usb_subcmp_pkg.all;

entity usb_host_pie is
      generic(
              ULPI_SUPPORT  : boolean := TRUE;
              UTMI_SUPPORT  : boolean := TRUE;
              USB_DATAWIDTH : integer := 64
         --     FILT_VBUS     : boolean := TRUE
      	);
      port (
            reset_n                       : in std_logic; -- AHB reset after resynchronization, active LOW
            pie_clk                       : in std_logic; -- UTMI/ULPI clock
            dbc_vbus_en                   : in std_logic;
            epinfo_starttransfer_sync     : in  std_logic;
            epinfo_token_sync             : in  std_logic_vector(2 downto 0);
            epinfo_devaddr_sync           : in  std_logic_vector(6 downto 0);
            epinfo_epnr_sync              : in  std_logic_vector(3 downto 0);
            epinfo_toggle_sync            : in  std_logic;
            epinfo_eptype_sync            : in  std_logic_vector(1 downto 0);
            epinfo_mult_sync              : in  std_logic_vector(1 downto 0);
            epinfo_maxpacket_sync         : in  std_logic_vector(10 downto 0);
            epinfo_nbytes_sync            : in  std_logic_vector(11 downto 0);
            epinfo_lowspeed_sync          : in  std_logic;
            epinfo_sofnr_sync             : in  std_logic_vector(10 downto 0);
            epinfo_subpid_sync            : in  std_logic_vector(1 downto 0);
            epinfo_lpm_linkstate_sync     : in  std_logic_vector(3 downto 0);
            epinfo_lpm_hird_sync          : in  std_logic_vector(3 downto 0);
            epinfo_lpm_bremotewakeup_sync : in  std_logic;
            epinfo_split_hubaddr_sync     : in  std_logic_vector(6 downto 0);
            epinfo_split_port_sync        : in  std_logic_vector(6 downto 0);
            epinfo_split_se_sync          : in  std_logic_vector(1 downto 0);
            pie_txdatafetched             : out std_logic;
            epinfo_txdata_sync            : in  std_logic_vector(USB_DATAWIDTH-1 downto 0);
            epinfo_txdata_valid_sync      : in  std_logic;
            pie_rx_nbytes                 : out std_logic_vector(11 downto 0);
            pie_rxdata                    : out std_logic_vector(USB_DATAWIDTH-1 downto 0);
            pie_rxdatavalid               : out std_logic;
            pie_endtransfer               : out std_logic;
            pie_response                  : out std_logic_vector(2 downto 0);
            usbreg_phy_addr_sync          : in  std_logic_vector(7 downto 0);
            pie_phy_rdata                 : out std_logic_vector(7 downto 0);
            usbreg_phy_wdata_sync         : in  std_logic_vector(7 downto 0);
            usbreg_phy_write_sync         : in  std_logic;
            usbreg_phy_start_sync         : in  std_logic;
            pie_phy_endtoggle             : out std_logic;
            usbreg_phy_mode_sync          : in  std_logic;
            usbreg_reset_sync             : in  std_logic;
            usbreg_light_reset_sync       : in  std_logic;
            usbreg_portpower_sync         : in std_logic;
            usbreg_portreset_sync         : in std_logic;
            usbreg_portsuspend_sync       : in  std_logic;
            usbreg_portl1l2suspend_sync   : in  std_logic;
            usbreg_portresume_sync        : in  std_logic;
	    usbreg_portenable_clear_sync  : in  std_logic;
	    usbreg_port_force_fullspeed   : in  std_logic;
            pie_resume_detected           : out std_logic;
            pie_resume_done               : out std_logic;
            pie_portconnect               : out std_logic;
            pie_portenable                : out std_logic;
            pie_linestate                 : out std_logic_vector(1 downto 0);
            usbreg_pll_on                 : in  std_logic;
            usbreg_phy_test_mode          : in  std_logic_vector(2 downto 0);
            usbreg_phy_test_mode_change_sync : in std_logic;
            pie_devicespeed               : out std_logic_vector(1 downto 0);
            usb_send_sof                  : in  std_logic;
            usb_endofframe                : in  std_logic;
            usb_overcurrent_sync          : in  std_logic;
            utmi_vbusvalid                : in  std_logic;
            utmi_rxdata                   : in  std_logic_vector(7 downto 0);
            utmi_rxvalid                  : in  std_logic;
            utmi_rxactive                 : in  std_logic;
            utmi_rxerror                  : in  std_logic;
            utmi_txdata                   : out std_logic_vector(7 downto 0);
            utmi_txvalid                  : out std_logic;
            utmi_txready                  : in  std_logic;
            utmi_reset                    : out std_logic;
            pie_lowpower_n                : out std_logic;
            utmi_xcvrselect               : out std_logic_vector(1 downto 0);
            utmi_termselect               : out std_logic;
            utmi_opmode                   : out std_logic_vector(1 downto 0);
            utmi_linestate                : in  std_logic_vector(1 downto 0);
            utmi_hostdisconnect           : in  std_logic;
            utmi_vcontrol                 : out std_logic_vector(3 downto 0);
            utmi_vcontrolloadm            : out std_logic;
            utmi_vstatus                  : in  std_logic_vector(7 downto 0);
            ulpi_rxdata                   : in   std_logic_vector(7 downto 0);
            ulpi_txdata                   : out  std_logic_vector(7 downto 0);
            ulpi_txenable                 : out  std_logic;
            ulpi_dir                      : in   std_logic;
            ulpi_stp                      : out  std_logic;
            ulpi_nxt                      : in   std_logic;
            ulpi_pwrctrl_wakeup           : in  std_logic;
            usb_host_pie_fpga             : out std_logic_vector(63 downto 0);
            INTER_PACKET_DELAY_LS_param   : in  std_logic_vector(7 downto 0);
            INTER_PACKET_DELAY_FS_param   : in  std_logic_vector(7 downto 0);
            INTER_PACKET_DELAY_HS_param   : in  std_logic_vector(7 downto 0);
            PACKET_TURNAROUND_TIMEOUT_LS_param : in  std_logic_vector(10 downto 0);
            PACKET_TURNAROUND_TIMEOUT_FS_param : in  std_logic_vector(7 downto 0);
            PACKET_TURNAROUND_TIMEOUT_HS_param : in  std_logic_vector(7 downto 0);
            PACKET_EVENT_TIMEOUT_LS_param : in  std_logic_vector(12 downto 0);
            PACKET_EVENT_TIMEOUT_FS_param : in  std_logic_vector(8 downto 0);
            PACKET_EVENT_TIMEOUT_HS_param : in  std_logic_vector(8 downto 0);
            usb_host_pie_portl1l2suspend_use_sync_n : in  std_logic

	  );
end usb_host_pie;


architecture RTL of usb_host_pie is

-- encoding/decoding to/from USB: PIDs
constant PID_EXT   : std_logic_vector(3 downto 0) := "0000"; -- PID: F0h - Protocol extension token
constant PID_OUT   : std_logic_vector(3 downto 0) := "0001"; -- PID: E1h - Address + EPnr in host-to-function transaction
constant PID_ACK   : std_logic_vector(3 downto 0) := "0010"; -- PID: D2h - Receiver accepts err-free packet
constant PID_DATA0 : std_logic_vector(3 downto 0) := "0011"; -- PID: C3h - Data packet PID even
constant PID_PING  : std_logic_vector(3 downto 0) := "0100"; -- PID: B4h - HS flow control probe for bulk/control EP
constant PID_SOF   : std_logic_vector(3 downto 0) := "0101"; -- PID: A5h - Start-of-Frame marker and frame number
constant PID_NYET  : std_logic_vector(3 downto 0) := "0110"; -- PID: 96h - No response from receiver
constant PID_DATA2 : std_logic_vector(3 downto 0) := "0111"; -- PID: 87h - Data packet high-speed, high-BW, isochronous in a uFrame
constant PID_SPLIT : std_logic_vector(3 downto 0) := "1000"; -- PID: 78h - HS split transaction token
constant PID_IN    : std_logic_vector(3 downto 0) := "1001"; -- PID: 69h - Address + EPnr in function-to-host transaction
constant PID_NAK   : std_logic_vector(3 downto 0) := "1010"; -- PID: 5Ah - Cannot accept or transmit data
constant PID_DATA1 : std_logic_vector(3 downto 0) := "1011"; -- PID: 4Bh - Data packet PID odd
constant PID_PRE   : std_logic_vector(3 downto 0) := "1100"; -- PID: 3Ch - Host issued preamble to enable LS
constant PID_ERR   : std_logic_vector(3 downto 0) := "1100"; -- PID: 3Ch - Split transaction errror handshake
constant PID_SETUP : std_logic_vector(3 downto 0) := "1101"; -- PID: 2Dh - Address + EPnr host-to-func trans for setup to a control pipe
constant PID_STALL : std_logic_vector(3 downto 0) := "1110"; -- PID: 1Eh - EP halted or control pipe request not supported
constant PID_MDATA : std_logic_vector(3 downto 0) := "1111"; -- PID: 0Fh - Data packet for split and HS, high-BW, isochronous trans

constant SUB_PID_LPM : std_logic_vector(3 downto 0) := "0011";  -- LPM token

-- decoding from others blocks: epinfo_token_sync
constant TOKEN_RESERVED : std_logic_vector(2 downto 0) := "000";
constant TOKEN_EXT      : std_logic_vector(2 downto 0) := "001";  -- Protocol Extension Token (e.g LPM Token)
constant TOKEN_SETUP    : std_logic_vector(2 downto 0) := "010";  -- SETUP
constant TOKEN_OUT      : std_logic_vector(2 downto 0) := "011";  -- OUT
constant TOKEN_IN       : std_logic_vector(2 downto 0) := "100";  -- IN
constant TOKEN_PING     : std_logic_vector(2 downto 0) := "101";  -- PING
constant TOKEN_SSPLIT   : std_logic_vector(2 downto 0) := "110";  -- START SPLIT
constant TOKEN_CSPLIT   : std_logic_vector(2 downto 0) := "111";  -- COMPLETE SPLIT

-- decoding from others blocks: epinfo_subpid_sync:
constant SUB_TOKEN_SETUP : std_logic_vector(1 downto 0) := "00";  -- FS/LS SETUP
constant SUB_TOKEN_OUT   : std_logic_vector(1 downto 0) := "01";  -- FS/LS OUT
constant SUB_TOKEN_IN    : std_logic_vector(1 downto 0) := "10";  -- FS/LS IN
constant SUB_TOKEN_LPM   : std_logic_vector(1 downto 0) := "11";  -- LPM


-- encoding to others blocks: pie_response field :
constant RESP_DEFAULT        : std_logic_vector(2 downto 0) := "000";   -- reset value
constant RESP_TIMEOUT_ERR    : std_logic_vector(2 downto 0) := "000";  -- Timeout or transaction error. Nothing received or packet received with bit errors
constant RESP_BUFF_ERR_OR_MDATA : std_logic_vector(2 downto 0) := "001";  -- Data Buffer error (underrun only)/MDATA received in a split transaction
constant RESP_BABBLE_ERR     : std_logic_vector(2 downto 0) := "010";  -- Babble error. SOP detected but no EOP detected before the EOF
                                                                       -- or device returns more bytes than expected by host
constant RESP_RCV_ERR_HSK    : std_logic_vector(2 downto 0) := "011";  -- ERR handshake received
constant RESP_RCV_TX_ACK_HSK : std_logic_vector(2 downto 0) := "100";  -- ACK handsahke is received/transmitted or ISO OUT/IN packet is sent/received
constant RESP_RCV_STALL_HSK  : std_logic_vector(2 downto 0) := "101";  -- STALL handsahke received
constant RESP_RCV_NAK_HSK    : std_logic_vector(2 downto 0) := "110";  -- NAK  handsahke received
constant RESP_RCV_NYET_HSK   : std_logic_vector(2 downto 0) := "111";  -- NYET  handsahke received

-- decoding from others blocks: epinfo_eptype_sync
constant EP_CTRL  : std_logic_vector(1 downto 0) := "00";  -- CONTROL EP
constant EP_ISO   : std_logic_vector(1 downto 0) := "01";  -- ISO EP
constant EP_BULK  : std_logic_vector(1 downto 0) := "10";  -- BULK EP
constant EP_INT   : std_logic_vector(1 downto 0) := "11";  -- INTERRUPT EP



-- LPM linkState:
constant LINKSTATE_L1 :std_logic_vector(3 downto 0) := "0001";  -- L1 (sleep)

constant MAX_HSFS_SE0_FILT_CNT : integer := 2;
constant MAX_LS_SE0_FILT_CNT : integer := 14;

constant MAX_LINESTATE_DBC_CNT : natural := 192; --   debounce time of > 2.5us (3.2 us @ 60MHz)
 -- line state constants
 -- Line State(1) = D-
 -- Line State(0) = D+
 --
constant LINESTATE_SE0       : std_logic_vector(1 downto 0) := "00";
constant LINESTATE_FS_J         : std_logic_vector(1 downto 0) := "01";
constant LINESTATE_FS_K         : std_logic_vector(1 downto 0) := "10";
constant LINESTATE_LS_J         : std_logic_vector(1 downto 0) := "10";
constant LINESTATE_LS_K         : std_logic_vector(1 downto 0) := "01";
constant LINESTATE_SE1       : std_logic_vector(1 downto 0) := "11";
constant LINESTATE_INCST     : std_logic_vector(1 downto 0) := "11";


-- timers constants in clk cycles (clk =60 MHz)

constant T_TDCHBIT          : natural := 3000; -- 50 us (7.1.7.5 USB2.0 spec)
constant T_TDCHSE0          : natural := 18000;      -- 300 us (7.1.7.5 USB2.0 spec)
constant T_THSIDLE          : natural := 240000; -- 4 ms  (7.1.7.6.1 USB2.0 spec)
--constant T_TDRSMDN          : natural := 1320000; -- 22 ms  (20ms +10 %) (7.1.7.7 USB2.0 spec)
constant T_TSE0EOR          : natural := 2100; --  35 us (should be 16 LS bit times but some PHY's need more time )(3.2 UTMI+ spec)
constant T_TL1_HUB_DRV_RESUME2 : natural := 6000; -- 100 us (must be minimum 60 us, max 990 us) (4.9 LPM Spec) -- GMA: TO BE CHECKED

constant MAX_BUS_EVENT_TIMER : natural := T_THSIDLE +1;--  Maximum timer value + 1 => error condition


--constant INTER_PACKET_DELAY_LS : natural := 80; -- 2 LS bit times
--constant INTER_PACKET_DELAY_FS : natural := 10; -- 2 FS bit times
--constant INTER_PACKET_DELAY_HS : natural := 12;  -- 96 HS bit times (min is 88 bit times)
signal INTER_PACKET_DELAY_LS : natural;
signal INTER_PACKET_DELAY_FS : natural;
signal INTER_PACKET_DELAY_HS : natural;

----------------------------------------------
-- the following 6 constant are PHY depedent :
----------------------------------------------
-- These three constants are measuring the turnaround time on the USB bus. It checks the time between 
-- txready going back to zero at the end of a transmission until rxactive goes high upon receiving the response.
-- These values must be a little bit higher than what is specified in the USB2.0 core spec + the delay in the 
-- PHY for asserting the different signals. The USB2 core spec states that for FS/LS the maximum bus turn-around 
-- time is 7.5 bit times. For HS this is maximum 192 bit times. To check these values, you will need to generate 
-- a simulation where the response of the device is delayed up to the maximum value allowed by the USB spec.
-- WARNING WARNING WARNING
-- Same name constant also declared in usb_pie.m.vhdl, need to make sure they have same value
--constant PACKET_TURNAROUND_TIMEOUT_LS : natural := 1380;        -- for 8 bit data width
--constant PACKET_TURNAROUND_TIMEOUT_FS : natural := 204;         -- for 8 bit data width
--constant PACKET_TURNAROUND_TIMEOUT_HS : natural := 162;         -- for 8 bit data width
signal PACKET_TURNAROUND_TIMEOUT_LS : natural;
signal PACKET_TURNAROUND_TIMEOUT_FS : natural;
signal PACKET_TURNAROUND_TIMEOUT_HS : natural;
--
-- These three constants are only there to make sure that the controller state machine is not stuck when 
-- a problem was detected by the PHY (e.g. rxactive has been asserted, but no rxvalid is asserted. This 
-- can happen when there is no valid SYNC pattern detected in the PHY). There is no side effect if you 
-- increase these values. 
-- WARNING WARNING WARNING
-- Same name constant also declared in usb_pie.m.vhdl, need to make sure they have same value
--constant PACKET_EVENT_TIMEOUT_LS : natural := 2048;     -- old : 1380
--constant PACKET_EVENT_TIMEOUT_FS : natural := 256;      -- old : 128
--constant PACKET_EVENT_TIMEOUT_HS : natural := 256;      -- old : 128
signal PACKET_EVENT_TIMEOUT_LS : natural;
signal PACKET_EVENT_TIMEOUT_FS : natural;
signal PACKET_EVENT_TIMEOUT_HS : natural;

constant END_TRANSFER_DELAY : natural := 8;

--constant MAX_PACKET_HANDLING_TIMER : natural := PACKET_EVENT_TIMEOUT_LS;
constant MAX_PACKET_HANDLING_TIMER : natural := 4096;   -- hard coded to a value 2x PACKET_EVENT_TIMEOUT_LS 

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


signal set_bus_event_eorst: std_logic;
signal clear_bus_event_eorst: std_logic;
signal bus_event_eorst_r: std_logic;

signal set_resume_detected: std_logic;
signal set_resume_end : std_logic;

signal rxdata                  :   std_logic_vector(7 downto 0);
signal rxvalid                 :   std_logic;
signal rxactive                :   std_logic;
signal rxactive_temp           :   std_logic;
signal rxactive_r                :   std_logic;
signal rxerror                 :   std_logic;
signal txready                 :   std_logic;
signal txready_r                 :   std_logic;
signal linestate               :   std_logic_vector(1 downto 0);
signal hostdisconnect          : std_logic;
signal hostdisconnect_sm       : std_logic_vector(1 downto 0);


signal utmi_rxvalid_r        : std_logic;
signal utmi_rxactive_r       : std_logic;
signal utmi_rxerror_r        : std_logic;
signal utmi_linestate_r      : std_logic_vector(1 downto 0);
signal utmi_rxdata_r         : std_logic_vector(7 downto 0);
signal utmi_hostdisconnect_r : std_logic;


signal suspendm_nxt : std_logic;
signal opmode_nxt: std_logic_vector(1 downto 0);
signal xcvrselect_nxt : std_logic_vector(1 downto 0);
signal termselect_nxt: std_logic;
signal txvalid_nxt : std_logic;
signal txdata_nxt : std_logic_vector(7 downto 0);
signal txvalid_pkt_nxt : std_logic;
signal txdata_pkt_nxt: std_logic_vector(7 downto 0);


signal se0_filt_cnt : natural range 0 to MAX_LS_SE0_FILT_CNT; --worst case is 14 CLK cycles for LS Bus speed for 8-bit interface
signal linestate_r         : std_logic_vector(1 downto 0);
signal ls_filt             : std_logic_vector(1 downto 0);

signal init_linestate_dbc  : std_logic;
signal linestate_dbc_cnt   : natural range 0 to MAX_LINESTATE_DBC_CNT;
signal ls_dbc              : std_logic_vector(1 downto 0);

signal rxdata_valid : std_logic;
signal rxdata_valid_toggle_r : std_logic;
signal rx_ok : std_logic;
signal rx_ok_r : std_logic;

signal portpacket_enabled: std_logic;


signal starttransfer_pending_r: std_logic;
signal clear_starttransfer : std_logic;
signal set_transfer_pending : std_logic;
signal transfer_pending_r : std_logic;
signal set_pie_response : std_logic;
signal pie_response_int : std_logic_vector(2 downto 0);

signal phy_endtoggle_r: std_logic;

signal crc16_eval_rx: std_logic;
signal crc16_eval_tx: std_logic;
signal crc16_valid_nxt : std_logic;

signal data_fifo_fill_rx : std_logic;
signal data_fifo_fill_tx : std_logic;
signal clear_data_fifo   : std_logic;
signal txdata_fetched_toggle_r: std_logic;
signal txdata_req_r: std_logic;

signal data_fifo_r : std_logic_vector (USB_DATAWIDTH -1 downto 0);
signal data_fifo_rx_r : std_logic_vector (USB_DATAWIDTH -1 downto 0);
signal data_fifo_previous_byte_r : std_logic_vector( 7 downto 0);

signal data_byte_cnt_incr    : std_logic;
signal clear_data_byte_cnt   : std_logic;
signal data_byte_cnt         : unsigned(11 downto 0); -- MAX_DATA_BYTE_CNT

signal decr_iso_transact_cnt_down: std_logic;
signal clear_iso_transact_cnt_down: std_logic;
signal load_iso_transact_cnt_down: std_logic;
signal iso_transact_cnt_down_r : unsigned (1 downto 0);
signal iso_transact_cnt_down_nxt : unsigned (1 downto 0);

signal moved_to_tx : std_logic;
signal moved_to_tx_d : std_logic;
signal keepprevdata_r: std_logic;
signal pie_endtransfer_int: std_logic;

signal incr_iso_transact_cnt_up: std_logic;
signal clear_iso_transact_cnt_up: std_logic;
signal iso_transact_cnt_up_r : unsigned (1 downto 0);

signal pid_nxt:std_logic_vector(3 downto 0);

signal set_ignore_data : std_logic;
signal clear_ignore_data : std_logic;
signal ignore_data_r : std_logic;


signal eop_tx: std_logic;
signal sop_start: std_logic;
signal sop_det_r: std_logic;
signal clear_sop_det: std_logic;

signal utmi_vbusvalid_r : std_logic;
signal vbusvalid        : std_logic;

signal clear_portenable_int : std_logic;

signal usbreg_portresume_r : std_logic;
signal usbreg_portresume_falling : std_logic;
signal usbreg_portsuspend_mux : std_logic;


type t_bus_event_state is
(
BUS_EVENT_INIT,
BUS_EVENT_POWERED,
BUS_EVENT_DISCON,
BUS_EVENT_DEV_ATTACH,
BUS_EVENT_RESET_WF_START_CHIRP_K,
BUS_EVENT_RESET_WF_END_CHIRP_K,
BUS_EVENT_RESET_DRIVE_CHIRP_K,
BUS_EVENT_RESET_DRIVE_CHIRP_J,
BUS_EVENT_RESET_LS_WF_EOR,
BUS_EVENT_RESET_FS_WF_EOR,
BUS_EVENT_RESET_HS_WF_EOR,
BUS_EVENT_LS_ENABLED,
BUS_EVENT_FS_ENABLED,
BUS_EVENT_HS_ENABLED,
BUS_EVENT_WF_LS_FS_ENABLED,
BUS_EVENT_LS_FS_ENABLED,
BUS_EVENT_HS_WF_SUSPEND_L2,
BUS_EVENT_SUSPEND_L2,
BUS_EVENT_HS_WF_SUSPEND_L1,
BUS_EVENT_HOST_DRIVE_RESUME_L1,
BUS_EVENT_REFLECT_DEV_RESUME_L1,
BUS_EVENT_SUSPEND_L1,
BUS_EVENT_DRIVE_RESUME_L2,
BUS_EVENT_FSLS_END_RESUME,
BUS_EVENT_HS_END_RESUME,
BUS_EVENT_TEST_MODE

);



signal bus_event_state_nxt, bus_event_state_r : t_bus_event_state;


type t_packet_handling_state is
(
USB_PROT_WF_IDLE,
USB_PROT_IDLE,
USB_PROT_TX_SOF_PID,
USB_PROT_TX_SOF_BYTE2,
USB_PROT_TX_SOF_BYTE3,
USB_PROT_TX_SOF_WF_EOP,
USB_PROT_ALL_WF_END_TX_PACKET,
USB_PROT_WF_STARTSOF,
USB_PROT_WF_TX_TOKEN_PKT_PID,
USB_PROT_TX_TOKEN_PKT_PID,
USB_PROT_TX_TOKEN_PKT_BYTE2,
USB_PROT_TX_TOKEN_PKT_BYTE3,
USB_PROT_TX_SPECIAL_TOKEN_PID,
USB_PROT_TX_SPECIAL_TOKEN_BYTE2,
USB_PROT_TX_SPECIAL_TOKEN_BYTE3,
USB_PROT_TX_SPECIAL_TOKEN_BYTE4,
USB_PROT_WF_END_TX_SPECIAL_TOKEN,
USB_PROT_OUT_SETUP_WF_TX_DATA_PID,
USB_PROT_OUT_SETUP_TX_DATA_PID_1,
USB_PROT_OUT_SETUP_TX_DATA_PID_2,
USB_PROT_OUT_SETUP_TX_DATA_PACKET,
USB_PROT_OUT_SETUP_TX_CRC16_BYTE1,
USB_PROT_OUT_SETUP_TX_CRC16_BYTE2,
USB_PROT_BAD_OUT_SETUP_TX_CRC16_BYTE1,
USB_PROT_BAD_OUT_SETUP_TX_CRC16_BYTE2,
USB_PROT_ALL_WF_RX_RESP,
USB_PROT_IN_RCV_DATA_PACKET,
USB_PROT_WF_END_TRANSFER_DELAY,
USB_PROT_IN_WF_TX_ACK_HANDSHAKE,
USB_PROT_IN_TX_ACK_HANDSHAKE,
USB_PROT_ISO_WF_NXT_PKT,
USB_PROT_TX_TEST_PACKET,
USB_PROT_WF_END_TX_TEST_PACKET,
USB_PROT_WF_TX_TEST_PACKET
);

signal packet_handling_state_nxt,packet_handling_state_r : t_packet_handling_state;

type T_UsbSpeed is (USB_LOW_SPEED,
	            USB_FULL_SPEED,
	            USB_HIGH_SPEED
			  );
signal port_speed_r: T_UsbSpeed;

signal set_dev_ls: std_logic;
signal set_dev_fs: std_logic;
signal set_dev_hs: std_logic;
signal set_dev_disc : std_logic;
signal set_tx_pending_pkt : std_logic;
signal clear_tx_pending_pkt: std_logic;
signal tx_pending_pkt_r : std_logic;
signal set_req_rx_pkt : std_logic;
signal clear_req_rx_pkt : std_logic;
signal req_rx_pkt_r : std_logic;
signal timer_packet_handling_r : natural range 0 to MAX_PACKET_HANDLING_TIMER;
signal timer_packet_handling_nxt : natural range 0 to MAX_PACKET_HANDLING_TIMER;
signal reload_timer_packet_handling_nxt : std_logic;
signal crc16_result_r             :  std_logic_vector(15 downto 0);
signal crc16_result_rx             :  std_logic_vector(15 downto 0);
signal crc16_result_tx             :  std_logic_vector(15 downto 0);
signal maxsize_currentpacket: unsigned(10 downto 0);

signal decr_remaining_nbytes : std_logic;
signal load_remaining_nbytes : std_logic;
signal remaining_nbytes_r: unsigned (11 downto 0);

signal set_iso_in_pending : std_logic;
signal clear_iso_in_pending: std_logic;
signal iso_in_pending_r : std_logic;
signal set_iso_out_pending : std_logic;
signal clear_iso_out_pending: std_logic;
signal iso_out_pending_r : std_logic;

signal set_rx_nbytes : std_logic;
signal rx_nbytes : std_logic_vector(11 downto 0);
signal rx_nbytes_r : std_logic_vector(11 downto 0);
signal set_last_rxdata_valid: std_logic;
signal set_lpm_l1_ok : std_logic;


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
signal set_ulpi_new_rxcmd : std_logic;
signal ulpi_rxerror_cmd : std_logic;
signal ulpi_txready: std_logic;
signal ulpi_rxerror_r : std_logic;
signal ulpi_linestate_r : std_logic_vector(1 downto 0);
signal ulpi_linestate_cmd : std_logic_vector(1 downto 0);
signal ulpi_hostdisconnect_cmd : std_logic;
signal ulpi_hostdisconnect_r : std_logic;
signal ulpi_opmode_r : std_logic_vector(1 downto 0);
signal ulpi_xcvrselect_r : std_logic_vector(1 downto 0);
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



--FUNCTIONS:

 function bit_reverse8
    ( data_in         : std_logic_vector(7 downto 0))
    return std_logic_vector is -- 8 bits
    variable v_data_out : std_logic_vector(7 downto 0);
  begin  -- bit_reverse8
    v_data_out := (others => '0');
    for i_bit_reverse8 in 7 downto 0 loop
      v_data_out(i_bit_reverse8) := data_in(7 - i_bit_reverse8);
    end loop;  -- i_bit_reverse8
    return (v_data_out);
  end bit_reverse8;

 function bit_reverse5
      ( data_in         : std_logic_vector(4 downto 0))
      return std_logic_vector is -- 5 bits
      variable v_data_out : std_logic_vector(4 downto 0);
    begin  -- bit_reverse5
      v_data_out := (others => '0');
      for i_bit_reverse5 in 4 downto 0 loop
        v_data_out(i_bit_reverse5) := data_in(4 - i_bit_reverse5);
      end loop;  -- i_bit_reverse5
      return (v_data_out);
    end bit_reverse5;

    function bit_reverse11
      ( data_in         : std_logic_vector(10 downto 0))
      return std_logic_vector is -- 11 bits
      variable v_data_out : std_logic_vector(10 downto 0);
    begin  -- bit_reverse11
      v_data_out := (others => '0');
      for i_bit_reverse11 in 10 downto 0 loop
        v_data_out(i_bit_reverse11) := data_in(10 - i_bit_reverse11);
      end loop;  -- i_bit_reverse11
      return (v_data_out);
    end bit_reverse11;

    function bit_reverse19
      ( data_in         : std_logic_vector(18 downto 0))
      return std_logic_vector is -- 19 bits
      variable v_data_out : std_logic_vector(18 downto 0);
    begin  -- bit_reverse19
      v_data_out := (others => '0');
      for i_bit_reverse19 in 18 downto 0 loop
        v_data_out(i_bit_reverse19) := data_in(18 - i_bit_reverse19);
      end loop;  -- i_bit_reverse19
      return (v_data_out);
  end bit_reverse19;

 function generate_pid_byte
    ( data_in         : std_logic_vector(3 downto 0))
    return std_logic_vector is -- 8 bits
    variable v_data_out : std_logic_vector(7 downto 0);
  begin  -- generate_pid_byte
    v_data_out(7 downto 4) := not data_in;
    v_data_out(3 downto 0) := data_in;
    return (v_data_out);
  end generate_pid_byte;


  function crc5_data11 -- CRC5 calculation is made in 1 clk cycle from data of 11 bits width
      ( data11 : std_logic_vector(10 downto 0) )
      return std_logic_vector is -- 5 bits

      variable v_d    : std_logic_vector(10 downto 0);
      constant PRELOAD : std_logic_vector(4 downto 0) := "11111";
      variable v_newcrc5 : std_logic_vector(4 downto 0);

    begin
      v_d    := data11;
      v_newcrc5 := (others => '0');

      v_newcrc5(0) := v_d(10) xor v_d(9) xor v_d(6) xor v_d(5) xor v_d(3) xor v_d(0) xor
                 PRELOAD(0) xor PRELOAD(3) xor PRELOAD(4);
      v_newcrc5(1) := v_d(10) xor v_d(7) xor v_d(6) xor v_d(4) xor v_d(1) xor
                 PRELOAD(0) xor PRELOAD(1) xor PRELOAD(4);
      v_newcrc5(2) := v_d(10) xor v_d(9) xor v_d(8) xor v_d(7) xor v_d(6) xor v_d(3) xor v_d(2) xor v_d(0) xor
                 PRELOAD(0) xor PRELOAD(1) xor PRELOAD(2) xor PRELOAD(3) xor PRELOAD(4);
      v_newcrc5(3) := v_d(10) xor v_d(9) xor v_d(8) xor v_d(7) xor v_d(4) xor v_d(3) xor v_d(1) xor
                 PRELOAD(1) xor PRELOAD(2) xor PRELOAD(3) xor PRELOAD(4);
      v_newcrc5(4) := v_d(10) xor v_d(9) xor v_d(8) xor v_d(5) xor v_d(4) xor v_d(2) xor
                 PRELOAD(2) xor PRELOAD(3) xor PRELOAD(4);

      return v_newcrc5;

    end crc5_data11;


    function crc5_data19 -- CRC5 calculation is made in 1 clk cycle from data of 19 bits width
      ( data19 : std_logic_vector(18 downto 0) )
      return std_logic_vector is -- 5 bits

      variable v_d    : std_logic_vector(18 downto 0);
      constant PRELOAD    : std_logic_vector(4 downto 0) := "11111";
      variable v_newcrc5 : std_logic_vector(4 downto 0);

    begin
      v_d       := data19;
      v_newcrc5    := (others => '0');
      v_newcrc5(0) := v_d(18) xor v_d(17) xor v_d(13) xor v_d(12) xor v_d(11) xor v_d(10) xor
                 v_d(9) xor v_d(6) xor v_d(5) xor v_d(3) xor v_d(0) xor
                 PRELOAD(3) xor PRELOAD(4);
      v_newcrc5(1) := v_d(18) xor v_d(14) xor v_d(13) xor v_d(12) xor v_d(11) xor v_d(10) xor
                 v_d(7) xor v_d(6) xor v_d(4) xor v_d(1) xor
                 PRELOAD(0) xor PRELOAD(4);
      v_newcrc5(2) := v_d(18) xor v_d(17) xor v_d(15) xor v_d(14) xor v_d(10) xor v_d(9) xor
                 v_d(8) xor v_d(7) xor v_d(6) xor v_d(3) xor v_d(2) xor v_d(0) xor
                 PRELOAD(0) xor PRELOAD(1) xor PRELOAD(3) xor PRELOAD(4);
      v_newcrc5(3) := v_d(18) xor v_d(16) xor v_d(15) xor v_d(11) xor v_d(10) xor v_d(9) xor
                 v_d(8) xor v_d(7) xor v_d(4) xor v_d(3) xor v_d(1) xor
                 PRELOAD(1) xor PRELOAD(2) xor PRELOAD(4);
      v_newcrc5(4) := v_d(17) xor v_d(16) xor v_d(12) xor v_d(11) xor v_d(10) xor v_d(9) xor
                 v_d(8) xor v_d(5) xor v_d(4) xor v_d(2) xor
                 PRELOAD(2) xor PRELOAD(3);

      return v_newcrc5;

    end crc5_data19;

  function crc16_data8
  -- CRC16 calculation is made in n clk cycles (n is the number of bytes on which CRC16 calculation must be performed)
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

-- lpm_hird_decod function:
-- decodes the "Host Initiated Resume Duration"parameter
 function lpm_hird_decod(lpm_hird: std_logic_vector (3 downto 0))
       return natural is
       variable var_lpm_hird_decod: natural;
       begin
        case lpm_hird is
           when "0000" =>
              var_lpm_hird_decod := 3000;  -- 50 us
           when "0001" =>
              var_lpm_hird_decod := 7500;  -- 125 us
           when "0010" =>
              var_lpm_hird_decod := 12000; -- 200 us
           when "0011" =>
              var_lpm_hird_decod := 16500; -- 275 us
           when "0100" =>
              var_lpm_hird_decod := 21000; -- 350 us
           when "0101" =>
              var_lpm_hird_decod := 25500; -- 425 us
           when "0110" =>
              var_lpm_hird_decod := 30000; -- 500 us
           when "0111" =>
              var_lpm_hird_decod := 34500; -- 575 us
           when "1000" =>
              var_lpm_hird_decod := 39000; -- 650 us
           when "1001" =>
              var_lpm_hird_decod := 43500; -- 725 us
           when "1010" =>
              var_lpm_hird_decod := 48000; -- 800 us
           when "1011" =>
              var_lpm_hird_decod := 52500; -- 875 us
           when "1100" =>
              var_lpm_hird_decod := 57000; -- 950 us
           when "1101" =>
              var_lpm_hird_decod := 61500; -- 1025 us
           when "1110" =>
              var_lpm_hird_decod := 66000; -- 1100 us
           when  others => -- "1111"
           var_lpm_hird_decod := 70500; -- 1175 us
        end case;

         return var_lpm_hird_decod;

   end function lpm_hird_decod;

begin

-- convert param 
param_conv: process (INTER_PACKET_DELAY_LS_param, INTER_PACKET_DELAY_FS_param, INTER_PACKET_DELAY_HS_param,
    PACKET_TURNAROUND_TIMEOUT_LS_param, PACKET_TURNAROUND_TIMEOUT_FS_param, PACKET_TURNAROUND_TIMEOUT_HS_param,
    PACKET_EVENT_TIMEOUT_LS_param, PACKET_EVENT_TIMEOUT_FS_param, PACKET_EVENT_TIMEOUT_HS_param
 )
begin
    INTER_PACKET_DELAY_LS <= to_integer(unsigned(INTER_PACKET_DELAY_LS_param));
    INTER_PACKET_DELAY_FS <= to_integer(unsigned(INTER_PACKET_DELAY_FS_param));
    INTER_PACKET_DELAY_HS <= to_integer(unsigned(INTER_PACKET_DELAY_HS_param));

    PACKET_TURNAROUND_TIMEOUT_LS <= to_integer(unsigned(PACKET_TURNAROUND_TIMEOUT_LS_param));
    PACKET_TURNAROUND_TIMEOUT_FS <= to_integer(unsigned(PACKET_TURNAROUND_TIMEOUT_FS_param));
    PACKET_TURNAROUND_TIMEOUT_HS <= to_integer(unsigned(PACKET_TURNAROUND_TIMEOUT_HS_param));

    PACKET_EVENT_TIMEOUT_LS <= to_integer(unsigned(PACKET_EVENT_TIMEOUT_LS_param));
    PACKET_EVENT_TIMEOUT_FS <= to_integer(unsigned(PACKET_EVENT_TIMEOUT_FS_param));
    PACKET_EVENT_TIMEOUT_HS <= to_integer(unsigned(PACKET_EVENT_TIMEOUT_HS_param));

end process param_conv;

--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------
--               TO DO LIST (begin)                         --
--------------------------------------------------------------
--------------------------------------------------------------


-- update usbreg_light_reset_sync on each process (KEPT HERE AS A REMINDER)
-- usbreg_reset_sync on each process (KEPT HERE AS A REMINDER)

--------------------------------------------------------------
--------------------------------------------------------------
--               TO DO LIST (end)                           --
--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------




--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------
--               UTMI/ULPI INTERFACE (begin)                --
--------------------------------------------------------------
--------------------------------------------------------------
-- ASSUMPTIONS UTMI:
--
-- UTMI+ Level 3
-- HS/FS/LS Version
-- 8-bit unidirectional (utmi_clk = 60 MHz)



--UTMI/ULPI selection

-- selection of the input clock is moved to 3515_hs toplevel

linestate <= utmi_linestate_r when usbreg_phy_mode_sync = '0' else
             ulpi_linestate_r;

rxdata <=  utmi_rxdata_r when usbreg_phy_mode_sync = '0' else
           ulpi_rxdata_r;

rxvalid <=  utmi_rxvalid_r when usbreg_phy_mode_sync = '0' else
            ulpi_rxvalid_r;

-- the rxactive is causing an un-real race condition in AMS sim 
-- so add this artificial 1ns delay to avoid race condition
rxactive_temp <=  utmi_rxactive_r when usbreg_phy_mode_sync = '0' else
             ulpi_rxactive_r;
rxactive <= rxactive_temp after 1 ns;

rxerror <=  utmi_rxerror_r when usbreg_phy_mode_sync = '0' else
            ulpi_rxerror_r;

hostdisconnect <=  '0'                   when hostdisconnect_sm(1) = '0' else
                   utmi_hostdisconnect_r when usbreg_phy_mode_sync = '0' else
                   ulpi_hostdisconnect_r;

--BVE : modified state machine as rxactive from PHY SMS is low during transmit
--      only start looking at hostdisconnect when sending 2nd SOF while in HS_ENABLED state
PROC_HOSTDISCONNECT_SM : process(pie_clk, reset_n)
begin
  if reset_n = '0' then
    hostdisconnect_sm <= "00";
  elsif pie_clk'event and pie_clk ='1' then
    if bus_event_state_r /= BUS_EVENT_HS_ENABLED then
      hostdisconnect_sm <= "00";
    elsif (usb_send_sof = '1') then
      hostdisconnect_sm(0) <= '1';
      hostdisconnect_sm(1) <= hostdisconnect_sm(0);
    end if;
  end if;
end process PROC_HOSTDISCONNECT_SM;

rx_ok <= '1' when rxvalid ='1'and rxactive='1' and rxerror='0' else '0';

txready <=  utmi_txready when usbreg_phy_mode_sync = '0' else
            ulpi_txready;

vbusvalid <=     utmi_vbusvalid_r when usbreg_phy_mode_sync = '0' else
                 ulpi_vbusvalid_r;


utmi_ulpi_clk_proc: process (pie_clk, reset_n)

begin

if reset_n = '0' then
--utmi output signals
   utmi_opmode <= "01";
   utmi_xcvrselect <= "01";
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
   utmi_hostdisconnect_r     <= '0';
   utmi_vbusvalid_r          <= '0';
-- ulpi internal signals
   ulpi_dir_r <= '0';
   ulpi_dir_r_s <= '0';
   ulpi_nxt_r <= '0';
   ulpi_rxdata_r <= (others => '0');
   ulpi_opmode_r <= "01";
   ulpi_xcvrselect_r <= "01";
   ulpi_termselect_r <= '0';
   ulpi_suspendm_r <= '0';
   ulpi_txdata <= (others => '0');
-- ulpi external signal
   ulpi_stp_r <= '1';
elsif pie_clk'event and pie_clk ='1'then
   txready_r <= txready;
   if usbreg_phy_mode_sync = '1' then -- ULPI interface is selected
      utmi_opmode <= "01";
      utmi_xcvrselect <= "01";
      utmi_termselect <= '0';
      utmi_txvalid <= '0';
      utmi_txdata <= (others => '0');
      utmi_rxdata_r             <= (others => '0');
      utmi_rxvalid_r            <= '0';
      utmi_rxactive_r           <= '0';
      utmi_rxerror_r            <= '0';
      utmi_linestate_r          <= "00";
      utmi_hostdisconnect_r     <= '0';
      utmi_vbusvalid_r          <= '0';
      ulpi_stp_r <= ulpi_stp_nxt;
      ulpi_dir_r <= ulpi_dir_int;
      ulpi_dir_r_s <= ulpi_dir_r;
      ulpi_nxt_r <= ulpi_nxt_int;
      ulpi_rxdata_r <= ulpi_rxdata;
      if packet_handling_state_r = USB_PROT_OUT_SETUP_TX_DATA_PACKET or packet_handling_state_r = USB_PROT_TX_TEST_PACKET then
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
      utmi_hostdisconnect_r     <= utmi_hostdisconnect;
      utmi_txvalid <= txvalid_nxt;
      utmi_vbusvalid_r          <= utmi_vbusvalid;
      if packet_handling_state_r = USB_PROT_OUT_SETUP_TX_DATA_PACKET or packet_handling_state_r = USB_PROT_TX_TEST_PACKET then
         if txready ='1' then  --  utmi_txdata must only change when txready is high
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
      ulpi_xcvrselect_r <= "01";
      ulpi_termselect_r <= '0';
      ulpi_suspendm_r <= '1';
      ulpi_stp_r <= '1';
   end if;
   if usbreg_reset_sync = '1' then
   --utmi output signals
      utmi_opmode <= "01";
      utmi_xcvrselect <= "01";
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
      utmi_hostdisconnect_r     <= '0';
      utmi_vbusvalid_r          <= '0';
   -- ulpi internal signals
      ulpi_dir_r <= '0';
      ulpi_dir_r_s <= '0';
      ulpi_nxt_r <= '0';
      ulpi_rxdata_r <= (others => '0');
   --   ulpi_txvalid_int_r <= '0';
      ulpi_opmode_r <= "01";
      ulpi_xcvrselect_r <= "01";
      ulpi_termselect_r <= '0';
      ulpi_suspendm_r <= '0';
      ulpi_txdata <= (others => '0');
   -- ulpi external signal
      ulpi_stp_r <= '1';
   end if;
end if;

end process utmi_ulpi_clk_proc;

ulpi_txenable <= '1' when ulpi_dir_int = '0' and ulpi_dir_r = '0' else '0';

ulpi_dir_int <= ulpi_dir;

ulpi_nxt_int <= ulpi_nxt;

ulpi_stp <= ulpi_stp_r when ulpi_async_mode_r = '0' else
            ulpi_stp_async;

-- UTMI/ULPI signals that are driven combinatorially
utmi_ulpi_out_comb_proc: process (suspendm_nxt,ulpi_oper_state_r,reset_n,usbreg_phy_mode_sync,ulpi_dir_r)

begin
   if usbreg_phy_mode_sync = '0' then -- UTMI mode
      utmi_reset <= not reset_n;
      pie_lowpower_n   <= suspendm_nxt;
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

utmi_ulpi_vendor_specific_comb_proc: process (usbreg_phy_mode_sync,utmi_vstatus,usbreg_phy_addr_sync,usbreg_phy_start_sync,phy_endtoggle_r,usbreg_phy_write_sync,usbreg_phy_wdata_sync,ulpi_xreg_rdata_r )

begin
  -- default values
   pie_phy_rdata <= (others => '0');
   utmi_vcontrol <= (others => '0');
   utmi_vcontrolloadm <= '1';
   ulpi_xreg_add <= (others => '0');
   ulpi_xreg_wdata <= (others => '0');
   ulpi_xreg_write <= '0';
   pie_phy_rdata <= (others => '0');
   pie_phy_endtoggle <= phy_endtoggle_r;
   if usbreg_phy_mode_sync = '0' then
      utmi_vcontrol <= usbreg_phy_addr_sync(3 downto 0);
      utmi_vcontrolloadm <= not(usbreg_phy_start_sync);
      pie_phy_rdata <= utmi_vstatus;
   else
      ulpi_xreg_add   <= usbreg_phy_addr_sync;
      ulpi_xreg_wdata <= usbreg_phy_wdata_sync;
      ulpi_xreg_write  <= usbreg_phy_write_sync;
      pie_phy_rdata    <= ulpi_xreg_rdata_r;
   end if;

end process utmi_ulpi_vendor_specific_comb_proc;


utmi_ulpi_vendor_specific_clk_proc: process (pie_clk, reset_n)

begin

if reset_n = '0' then

   phy_endtoggle_r <= '0';

elsif pie_clk'event and pie_clk ='1'then

   if usbreg_phy_mode_sync = '0' then
      if usbreg_phy_start_sync = '1' then
         phy_endtoggle_r <= not phy_endtoggle_r;
      end if;
   elsif set_ulpi_phy_endtoggle = '1' then
      phy_endtoggle_r <= not phy_endtoggle_r;
   end if;
   if usbreg_reset_sync = '1' then
      phy_endtoggle_r <= '0';
   end if;
end if;

end process utmi_ulpi_vendor_specific_clk_proc;


--For UTMI+ interface, phy_endtoggle is inverted when usbreg_phy_start_sync = ‘1’.”




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

--FS/LS mode: the LineState transition from the J State (Idle) to a K
--State marks the beginning of a packet on the bus
--LineState transition from the SE0 to the J-State marks the end of a FS packet on the bus.


-- USB BUS EVENT STATE MACHINE
-- BUS EVENTS (according to UTMI Spec):
---------------------------------------


bus_event_fsm_comb_proc : process (bus_event_state_r,usbreg_portpower_sync,usbreg_portreset_sync,usbreg_phy_test_mode,
                                   ls_filt,ls_dbc,bus_event_eorst_r,usbreg_phy_test_mode_change_sync,packet_handling_state_r,
                                   timer_bus_event_timeout_r,hostdisconnect,usbreg_portsuspend_sync,port_speed_r,
                                   timer_bus_event,usbreg_portresume_sync,usbreg_portenable_clear_sync,clear_portenable_int,
                                   epinfo_lowspeed_sync,set_transfer_pending,transfer_pending_r,set_lpm_l1_ok,
                                   epinfo_lpm_hird_sync,vbusvalid,dbc_vbus_en,usbreg_portresume_falling,usb_overcurrent_sync,
                                   usbreg_port_force_fullspeed)

begin

-- default values
   bus_event_state_nxt <= bus_event_state_r;
   init_linestate_dbc <= '0';
   clear_timer_bus_event <= '0';
   set_dev_ls <= '0';
   set_dev_fs <= '0';
   set_dev_hs <= '0';
   set_dev_disc <= '0';
   set_bus_event_eorst <= '0';
   clear_bus_event_eorst <= '0';
   set_resume_detected <= '0';
   set_resume_end <= '0';

   if usbreg_portpower_sync = '0' or timer_bus_event_timeout_r = '1' or usb_overcurrent_sync = '1' then
      bus_event_state_nxt <= BUS_EVENT_INIT;
      clear_timer_bus_event <= '1';
      clear_bus_event_eorst <= '1';
      init_linestate_dbc <= '1';
      set_dev_ls <= '1';

   elsif usbreg_phy_test_mode /= "000" and usbreg_phy_test_mode_change_sync = '1' then
         bus_event_state_nxt <= BUS_EVENT_TEST_MODE;
         clear_timer_bus_event <= '1';
         clear_bus_event_eorst <= '1';
         init_linestate_dbc <= '1';
         set_dev_hs <= '1';
   else
      case bus_event_state_r is

         when BUS_EVENT_INIT => -- Initial State. Wait for downstream Port is powered
            if usbreg_portpower_sync = '1' and vbusvalid = '1' then
               bus_event_state_nxt <= BUS_EVENT_POWERED;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_POWERED => -- VBus is asserted and port is powered. Wait for vbus is stable for debounced duration
            if vbusvalid = '0' or usbreg_portpower_sync = '0' then
               clear_timer_bus_event <= '1';
               bus_event_state_nxt <= BUS_EVENT_INIT;
               init_linestate_dbc <= '1';
            elsif (timer_bus_event = T_THSIDLE or dbc_vbus_en = '0' ) then -- if debouncing on vbus is enabled, vbus has been stable for 4 ms
               clear_timer_bus_event <= '1';
               bus_event_state_nxt <= BUS_EVENT_DISCON;
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_DISCON => -- DS port is powered. Start to detect if a device is attached
            if ls_dbc =  LINESTATE_FS_J then-- (HS/FS device is attached)
               set_dev_fs <= '1'; -- go to FS mode (and HS detection handshake)
               bus_event_state_nxt <= BUS_EVENT_DEV_ATTACH;
            elsif ls_dbc =  LINESTATE_LS_J then-- (LS device is attached)
               set_dev_ls <= '1'; -- go to LS mode
               bus_event_state_nxt <= BUS_EVENT_DEV_ATTACH;
            end if;

         when BUS_EVENT_DEV_ATTACH => -- = DISABLED state. A device is attached. Waiting for bus reset
            if ls_dbc =  LINESTATE_SE0 then -- linestate = SEO > 2.5 us means host disconnect -- hostdisconnect signal is only used when hs port is enabled
               bus_event_state_nxt <= BUS_EVENT_DISCON;
	       clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
               set_dev_disc <= '1';
            elsif usbreg_portreset_sync = '1' then -- USB bus reset process can start
               if port_speed_r = USB_LOW_SPEED then -- Low Speed device is attached. No need to wait for chirp K. Wait for end of reset
                  bus_event_state_nxt <= BUS_EVENT_RESET_LS_WF_EOR;
                  clear_timer_bus_event <= '1';
                  init_linestate_dbc <= '1';
               else   -- Full/High Speed device is attached.
                  bus_event_state_nxt <= BUS_EVENT_RESET_WF_START_CHIRP_K;
                  clear_timer_bus_event <= '1';
                  init_linestate_dbc <= '1';
               end if;
            end if;

         when BUS_EVENT_RESET_WF_START_CHIRP_K => --looking for chirp K from device
            if usbreg_portreset_sync = '0' then -- Chirp K has not been detected on time. A FS device is attached.
               bus_event_state_nxt <= BUS_EVENT_FS_ENABLED;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif (ls_dbc = LINESTATE_FS_K) and (usbreg_port_force_fullspeed = '0') then 
               -- Disable chirp-K detection when port is forced in fullspeed mode
               -- CHIRP K is detected  > 2.5 us is detected --> waiting for end of chirp K
               bus_event_state_nxt <= BUS_EVENT_RESET_WF_END_CHIRP_K;
               clear_timer_bus_event <= '1';
               -- the host will be more relaxed but it's more robust to keep a timeout in case the device would not release its chirp K
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_RESET_WF_END_CHIRP_K =>
            if usbreg_portreset_sync = '0' then   -- EOR is reached, while device is still driving its chirp K
            --> not expected behaviour. GO TO FS
               clear_timer_bus_event <= '1';
               bus_event_state_nxt <= BUS_EVENT_FS_ENABLED;
               init_linestate_dbc <= '1';
            elsif ls_filt = LINESTATE_SE0 then -- end of chirp K detected
               bus_event_state_nxt <= BUS_EVENT_RESET_DRIVE_CHIRP_K;
               clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	    end if;

        when BUS_EVENT_RESET_DRIVE_CHIRP_K =>
           if usbreg_portreset_sync = '0' then  -- EOR is reached, let's continue to drive a complete chirp K-J sequence
	      set_bus_event_eorst <= '1';
	   end if;
           if timer_bus_event = T_TDCHBIT then
              bus_event_state_nxt <= BUS_EVENT_RESET_DRIVE_CHIRP_J;
              init_linestate_dbc <= '1';
              clear_timer_bus_event <= '1';
           end if;

        when BUS_EVENT_RESET_DRIVE_CHIRP_J =>
           if usbreg_portreset_sync = '0' then  -- EOR is reached, let's continue to drive a complete chirp K-J sequence
	      set_bus_event_eorst <= '1';
           end if;
           if timer_bus_event = T_TDCHBIT then
	      bus_event_state_nxt <= BUS_EVENT_RESET_DRIVE_CHIRP_K;
	      init_linestate_dbc <= '1';
	      clear_timer_bus_event <= '1';
	      if bus_event_eorst_r = '1'then
	         clear_bus_event_eorst <= '1';
	         set_bus_event_eorst <= '0';
	         bus_event_state_nxt <= BUS_EVENT_RESET_HS_WF_EOR;
	      end if;
	   end if;


         when BUS_EVENT_RESET_LS_WF_EOR => -- Wait for the End of the reset time
            if usbreg_portreset_sync = '0' then
               bus_event_state_nxt <= BUS_EVENT_LS_ENABLED;
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_RESET_FS_WF_EOR => -- Wait for the End of the reset time
            if usbreg_portreset_sync = '0' then
	       bus_event_state_nxt <= BUS_EVENT_FS_ENABLED;
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_RESET_HS_WF_EOR => -- Add extra time to prevent the host to send a SOF right after the chirp sequence
            if timer_bus_event = T_TDCHSE0 then
               bus_event_state_nxt <= BUS_EVENT_HS_ENABLED;
	       set_dev_hs <= '1';
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_LS_ENABLED =>
            if ls_dbc =  LINESTATE_SE0 then -- linestate = SEO > 2.5 us means host disconnect -- hostdisconnect signal is only used when hs port is enabled
	       bus_event_state_nxt <= BUS_EVENT_DISCON;
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	       set_dev_disc <= '1';
	    elsif usbreg_portenable_clear_sync = '1' or clear_portenable_int = '1' then
	       bus_event_state_nxt <= BUS_EVENT_DEV_ATTACH; -- Go back to DISABLED state
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	    elsif usbreg_portreset_sync = '1' then -- USB bus reset process must re-start. @ LS, no chirping sequence.
	       bus_event_state_nxt <= BUS_EVENT_RESET_LS_WF_EOR;
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	    elsif set_lpm_l1_ok = '1' then -- jump to L1 state of LPM
               bus_event_state_nxt <= BUS_EVENT_SUSPEND_L1;
	       clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
	    elsif usbreg_portsuspend_sync = '1' and usbreg_portresume_sync = '0' and ls_dbc /= LINESTATE_INCST
	             and packet_handling_state_r = USB_PROT_IDLE then
	       bus_event_state_nxt <= BUS_EVENT_SUSPEND_L2;
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_FS_ENABLED =>
            if ls_dbc =  LINESTATE_SE0 then -- linestate = SEO > 2.5 us means host disconnect -- hostdisconnect signal is only used when hs port is enabled
	       bus_event_state_nxt <= BUS_EVENT_DISCON;
	       clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
               set_dev_disc <= '1';
            elsif usbreg_portenable_clear_sync = '1' or clear_portenable_int = '1' then
               bus_event_state_nxt <= BUS_EVENT_DEV_ATTACH; -- Go back to DISABLED state
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif usbreg_portreset_sync = '1' then -- USB bus reset process must re-start
               bus_event_state_nxt <= BUS_EVENT_RESET_WF_START_CHIRP_K;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif set_lpm_l1_ok = '1' then -- jump to L1 state of LPM
               bus_event_state_nxt <= BUS_EVENT_SUSPEND_L1;
	       clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif usbreg_portsuspend_sync = '1' and usbreg_portresume_sync = '0' and ls_dbc /= LINESTATE_INCST
                    and packet_handling_state_r = USB_PROT_IDLE then -- port speed must be saved
               bus_event_state_nxt <= BUS_EVENT_SUSPEND_L2;
	       clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif epinfo_lowspeed_sync = '1' and (set_transfer_pending = '1' or transfer_pending_r = '1') then
               bus_event_state_nxt <= BUS_EVENT_WF_LS_FS_ENABLED; -- full-/low speed signaling environment
	       clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_HS_ENABLED =>
            if hostdisconnect = '1' then
	       bus_event_state_nxt <= BUS_EVENT_DISCON;
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	       set_dev_disc <= '1';
	    elsif usbreg_portenable_clear_sync = '1' or clear_portenable_int = '1' then
	       bus_event_state_nxt <= BUS_EVENT_DEV_ATTACH; -- Go back to DISABLED state
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	       set_dev_fs <= '1';  -- go back to FS mode
	    elsif usbreg_portreset_sync = '1' then -- USB bus reset process must re-start
	       bus_event_state_nxt <= BUS_EVENT_RESET_WF_START_CHIRP_K;
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	       set_dev_fs <= '1';  -- go back to FS mode
	    elsif set_lpm_l1_ok = '1' then
	       bus_event_state_nxt <= BUS_EVENT_HS_WF_SUSPEND_L1; -- @ HS cannot go directly to SUSPEND STATE --> prevent an unintended disconnect detection
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	    elsif usbreg_portsuspend_sync = '1' and usbreg_portresume_sync = '0' and ls_dbc /= LINESTATE_INCST
	       and packet_handling_state_r = USB_PROT_IDLE then
	       bus_event_state_nxt <= BUS_EVENT_HS_WF_SUSPEND_L2; -- @ HS cannot go directly to SUSPEND STATE --> prevent an unintended disconnect detection
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_WF_LS_FS_ENABLED => -- wait for 1 clk before driving tx_valid
            bus_event_state_nxt <= BUS_EVENT_LS_FS_ENABLED; -- full-/low speed signaling environment

         when BUS_EVENT_LS_FS_ENABLED => -- Low speed device attached via a FS port
            if ls_dbc =  LINESTATE_SE0 then -- linestate = SEO > 2.5 us means host disconnect -- hostdisconnect signal is only used when hs port is enabled
	       bus_event_state_nxt <= BUS_EVENT_DISCON;
	       clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
               set_dev_disc <= '1';
            elsif usbreg_portenable_clear_sync = '1'or clear_portenable_int = '1' then
               bus_event_state_nxt <= BUS_EVENT_DEV_ATTACH; -- Go back to DISABLED state
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif usbreg_portreset_sync = '1' then -- USB bus reset process must re-start
               bus_event_state_nxt <= BUS_EVENT_RESET_WF_START_CHIRP_K;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif set_lpm_l1_ok = '1' then -- jump to L1 state of LPM
               bus_event_state_nxt <= BUS_EVENT_SUSPEND_L1;
	       clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif usbreg_portsuspend_sync = '1' and usbreg_portresume_sync = '0' and ls_dbc /= LINESTATE_INCST
            and packet_handling_state_r = USB_PROT_IDLE then
               bus_event_state_nxt <= BUS_EVENT_SUSPEND_L2;  -- port speed must be saved
	       clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            elsif epinfo_lowspeed_sync = '0' or transfer_pending_r = '0' then
               bus_event_state_nxt <= BUS_EVENT_FS_ENABLED; -- go back to full speed signaling environment
	       clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
            end if;

-- LPM specific----------------------------------------------------- BEGIN
-- BVE : only disable disconnect detection in this state
--       other events (like resume / remote wakeup / ...) must still be done
         when BUS_EVENT_HS_WF_SUSPEND_L1 => -- rvert to FS termination immediatelly
         -- LPM spec 4.8.2.: @ HS port must not perform normal disconnect detection until at least 4ms after entering this state
         --> prevent an unintended disconnect detection.
            if timer_bus_event = T_THSIDLE then
               bus_event_state_nxt <= BUS_EVENT_SUSPEND_L1;
               clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
-- BVE fix - remove clear_portenable_int check. 
-- Do not disable port when a transfer is pending while in suspend state
	    elsif usbreg_portenable_clear_sync = '1' then
	       bus_event_state_nxt <= BUS_EVENT_DEV_ATTACH; -- Go back to DISABLED state
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	       if port_speed_r /= USB_LOW_SPEED then
	    	  set_dev_fs <= '1';  -- If HS or FS : go back to FS mode
	       end if;
	    elsif usbreg_portreset_sync = '1' then -- USB bus reset process must re-start
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	       if port_speed_r /= USB_LOW_SPEED then
	          set_dev_fs <= '1';  -- If HS or FS : go back to FS mode
	          bus_event_state_nxt <= BUS_EVENT_RESET_WF_START_CHIRP_K;
	       else
	          bus_event_state_nxt <= BUS_EVENT_RESET_LS_WF_EOR;
	       end if;
	    elsif usbreg_portresume_sync = '1' then -- a resume will be driven by the host
	       bus_event_state_nxt <= BUS_EVENT_HOST_DRIVE_RESUME_L1;
	       clear_timer_bus_event <= '1';
       	       init_linestate_dbc <= '1';
       	    elsif (port_speed_r =  USB_LOW_SPEED and ls_dbc = LINESTATE_LS_K) or -- remote wake-up from device is detected
       	          (port_speed_r /= USB_LOW_SPEED and ls_dbc = LINESTATE_FS_K) then
       	       bus_event_state_nxt <= BUS_EVENT_REFLECT_DEV_RESUME_L1;
	       clear_timer_bus_event <= '1';
       	       init_linestate_dbc <= '1';
       	       set_resume_detected <= '1';
            end if;

         when BUS_EVENT_SUSPEND_L1 => -- Sleep state as defined in LPM addendum

	    if ls_dbc =  LINESTATE_SE0 then -- linestate = SEO > 2.5 us means host disconnect -- hostdisconnect signal is only used when hs port is enabled
	       bus_event_state_nxt <= BUS_EVENT_DISCON;
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	       set_dev_disc <= '1';
-- BVE fix - remove clear_portenable_int check. 
-- Do not disable port when a transfer is pending while in suspend state
	    elsif usbreg_portenable_clear_sync = '1' then
	       bus_event_state_nxt <= BUS_EVENT_DEV_ATTACH; -- Go back to DISABLED state
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	       if port_speed_r /= USB_LOW_SPEED then
	    	  set_dev_fs <= '1';  -- If HS or FS : go back to FS mode
	       end if;
	    elsif usbreg_portreset_sync = '1' then -- USB bus reset process must re-start
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	       if port_speed_r /= USB_LOW_SPEED then
	          set_dev_fs <= '1';  -- If HS or FS : go back to FS mode
	          bus_event_state_nxt <= BUS_EVENT_RESET_WF_START_CHIRP_K;
	       else
	          bus_event_state_nxt <= BUS_EVENT_RESET_LS_WF_EOR;
	       end if;
	    elsif usbreg_portresume_sync = '1' then -- a resume will be driven by the host
	       bus_event_state_nxt <= BUS_EVENT_HOST_DRIVE_RESUME_L1;
	       clear_timer_bus_event <= '1';
       	       init_linestate_dbc <= '1';
       	    elsif (port_speed_r = USB_LOW_SPEED and ls_dbc = LINESTATE_LS_K) or -- remote wake-up from device is detected
       	    (port_speed_r /= USB_LOW_SPEED and ls_dbc = LINESTATE_FS_K) then
       	       bus_event_state_nxt <= BUS_EVENT_REFLECT_DEV_RESUME_L1;
	       clear_timer_bus_event <= '1';
       	       init_linestate_dbc <= '1';
       	       set_resume_detected <= '1';
            end if;

         when BUS_EVENT_HOST_DRIVE_RESUME_L1 =>
	-- the resume signaling must be ended differently depending on the speed the port was operating
	--when it was suspended  (USB2.0 spec 7.1.7.7)
	    if timer_bus_event = lpm_hird_decod (epinfo_lpm_hird_sync) then -- decoded from HIRD = TL1HubDrvResume1 -- LPM spec
	       if port_speed_r /= USB_HIGH_SPEED then
	          bus_event_state_nxt <= BUS_EVENT_FSLS_END_RESUME;
	       else
	          bus_event_state_nxt <= BUS_EVENT_HS_END_RESUME;
	       end if;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
	       --set_resume_end <= '1';
            end if;

         when BUS_EVENT_REFLECT_DEV_RESUME_L1 =>
	-- the resume signaling must be ended differently depending on the speed the port was operating
	--when it was suspended  (USB2.0 spec 7.1.7.7)
	    if timer_bus_event = T_TL1_HUB_DRV_RESUME2 then -- TL1HubDrvResume2 -- LPM spec
	       if port_speed_r /= USB_HIGH_SPEED then
	          bus_event_state_nxt <= BUS_EVENT_FSLS_END_RESUME;
	       else
	          bus_event_state_nxt <= BUS_EVENT_HS_END_RESUME;
	       end if;
               clear_timer_bus_event <= '1';
               init_linestate_dbc <= '1';
	       --set_resume_end <= '1';
            end if;
-- LPM specific ----------------------------------------------------- END

         when BUS_EVENT_HS_WF_SUSPEND_L2 =>
         -- USB2.0. spec 7.1.7.6.1.: @ HS cannot go directly to SUSPEND STATE --> prevent an unintended disconnect detection
            if timer_bus_event = T_THSIDLE then
               bus_event_state_nxt <= BUS_EVENT_SUSPEND_L2;
               clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
            end if;

         when BUS_EVENT_SUSPEND_L2 => -- Suspend State as defined in USB 2.0 spec and in LPM addendum

	    if ls_dbc =  LINESTATE_SE0 then -- linestate = SEO > 2.5 us means host disconnect -- hostdisconnect signal is only used when hs port is enabled
	       bus_event_state_nxt <= BUS_EVENT_DISCON;
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	       set_dev_disc <= '1';
-- BVE  fix - remove clear_portenable_int check. 
-- Do not disable port when a transfer is pending while in suspend state
	    elsif usbreg_portenable_clear_sync = '1' then
	       bus_event_state_nxt <= BUS_EVENT_DEV_ATTACH; -- Go back to DISABLED state
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	       if port_speed_r /= USB_LOW_SPEED then
	    	  set_dev_fs <= '1';  -- If HS or FS : go back to FS mode
	       end if;
	    elsif usbreg_portreset_sync = '1' then -- USB bus reset process must re-start
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	       if port_speed_r /= USB_LOW_SPEED then
	          set_dev_fs <= '1';  -- If HS or FS : go back to FS mode
	          bus_event_state_nxt <= BUS_EVENT_RESET_WF_START_CHIRP_K;
	       else
	          bus_event_state_nxt <= BUS_EVENT_RESET_LS_WF_EOR;
	       end if;
	    elsif usbreg_portresume_sync = '1' then -- EHCI spec: duration of resume is now controlled by SW
	       bus_event_state_nxt <= BUS_EVENT_DRIVE_RESUME_L2;
	       clear_timer_bus_event <= '1';
       	       init_linestate_dbc <= '1';
       	    elsif (port_speed_r = USB_LOW_SPEED and ls_dbc = LINESTATE_LS_K) or -- remote wake-up from device is detected
       	    (port_speed_r /= USB_LOW_SPEED and ls_dbc = LINESTATE_FS_K) then
       	    -- EHCI spec: duration of resume is now controlled by SW
       	       bus_event_state_nxt <= BUS_EVENT_DRIVE_RESUME_L2;
	       clear_timer_bus_event <= '1';
       	       init_linestate_dbc <= '1';
       	       set_resume_detected <= '1';
            end if;

	 when BUS_EVENT_DRIVE_RESUME_L2 =>
	 -- the resume signaling must be ended differently depending on the speed the port was operating
	 --when it was suspended  (USB2.0 spec 7.1.7.7)
	 -- EHCI spec: duration of resume is now controlled by SW
	    --if timer_bus_event = T_TDRSMDN then
	    if usbreg_portresume_falling = '1' then
	       if port_speed_r /= USB_HIGH_SPEED then
                  bus_event_state_nxt <= BUS_EVENT_FSLS_END_RESUME;
	       else
                  bus_event_state_nxt <= BUS_EVENT_HS_END_RESUME;
	       end if;
               clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
--	       set_resume_end <= '1';
            end if;

-- END OF RESUME: The resume recovery time (TRSMRCY = 10 ms , USB 2.0 spec 7.1.7.7.) is handled by SW
-- idem for LPM: L1 Exit device Recovery time (TL1ExitDevRecovery = min 10 us) as defined in LPM spec 4.9
	 when BUS_EVENT_FSLS_END_RESUME =>
	 -- resume signaling must be ended by a standard LS EOP (2 LS bit-time SEO followed by 1 LS bit-time J)
	    if timer_bus_event = T_TSE0EOR then
	       if port_speed_r = USB_LOW_SPEED then
                  bus_event_state_nxt <= BUS_EVENT_LS_ENABLED;
	       else -- USB_FULL_SPEED
	          bus_event_state_nxt <= BUS_EVENT_FS_ENABLED;
	       end if;
	       set_resume_end <= '1';
               clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	    end if;

	 when BUS_EVENT_HS_END_RESUME =>
 	 -- resume signaling must be ended by a transition to HS IDLE state
	 -- PHY should not be switched in HS mode no earlier than when SE0 is detected on LineState (UTMI+ spec 3.2)
	 -- xcvselect and termselect keeps their FS terminations
	    if ls_filt = LINESTATE_SE0 then
	       set_resume_end <= '1';
	       bus_event_state_nxt <= BUS_EVENT_HS_ENABLED;
	       clear_timer_bus_event <= '1';
	       init_linestate_dbc <= '1';
	    end if;

	 when others =>   --BUS_EVENT_TEST_MODE
	    if usbreg_phy_test_mode = "000" and usbreg_phy_test_mode_change_sync = '1' then  -- for debug purpose, normal way to exit this state is via a Power cycle
	       bus_event_state_nxt <= BUS_EVENT_INIT;
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
      if usbreg_reset_sync = '1' then
         bus_event_state_r <= BUS_EVENT_INIT;
      end if;
   end if;
end process bus_event_fsm_clk_proc;



bus_event_to_phy_comb_proc : process (bus_event_state_nxt,usbreg_pll_on,txvalid_pkt_nxt,txdata_pkt_nxt,port_speed_r,usbreg_phy_test_mode)


begin
  -- default values

   suspendm_nxt <= '1';
   opmode_nxt <= "00";
   xcvrselect_nxt <= "01";
   termselect_nxt <= '0';
   txvalid_nxt <= '0';
   txdata_nxt <= (others => '0');

      case bus_event_state_nxt is

         when BUS_EVENT_INIT => --
	    suspendm_nxt <= usbreg_pll_on;
	    opmode_nxt <= "01";
	    xcvrselect_nxt <= "01";
            termselect_nxt <= '0';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_POWERED => --
	    suspendm_nxt <= usbreg_pll_on;
	    opmode_nxt <= "01";
	    xcvrselect_nxt <= "01";
            termselect_nxt <= '0';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_DISCON =>
	    suspendm_nxt <= usbreg_pll_on;
	    opmode_nxt <= "00";
	    xcvrselect_nxt <= "01";
            termselect_nxt <= '1';
            txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_DEV_ATTACH => -- = DISABLED state
            suspendm_nxt <= usbreg_pll_on;
	    opmode_nxt <= "00";
	    xcvrselect_nxt <= "01";
	    termselect_nxt <= '1';
	    txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_RESET_WF_START_CHIRP_K =>
            suspendm_nxt <= '1';
	    opmode_nxt <= "10"; -- RESUME/CHIRP
	    xcvrselect_nxt <= "00"; -- switch to HS
	    termselect_nxt <= '0';
	    txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_RESET_WF_END_CHIRP_K =>
            suspendm_nxt <= '1';
	    opmode_nxt <= "10"; -- RESUME/CHIRP
	    xcvrselect_nxt <= "00"; -- switch to HS
	    termselect_nxt <= '0';
	    txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_RESET_DRIVE_CHIRP_K =>
            suspendm_nxt <= '1';
	    opmode_nxt <= "10"; -- RESUME/CHIRP
	    xcvrselect_nxt <= "00"; -- switch to HS
	    termselect_nxt <= '0';
	    txvalid_nxt <= '1';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_RESET_DRIVE_CHIRP_J =>
            suspendm_nxt <= '1';
	    opmode_nxt <= "10"; -- RESUME/CHIRP
	    xcvrselect_nxt <= "00"; -- switch to HS
	    termselect_nxt <= '0';
	    txvalid_nxt <= '1';
            txdata_nxt <= (others => '1');

         when BUS_EVENT_RESET_LS_WF_EOR =>
            suspendm_nxt <= '1';
	    opmode_nxt <= "10"; -- RESUME/CHIRP
	    xcvrselect_nxt <= "00"; -- wait for the end of the reset before switching to LS
	    termselect_nxt <= '0';
	    txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_RESET_FS_WF_EOR =>
            suspendm_nxt <= '1';
	    opmode_nxt <= "10"; -- RESUME/CHIRP
	    xcvrselect_nxt <= "01"; -- switch to FS
	    termselect_nxt <= '0';
	    txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_RESET_HS_WF_EOR =>
            suspendm_nxt <= '1';
	    opmode_nxt <= "10"; -- RESUME/CHIRP
	    xcvrselect_nxt <= "00"; -- switch to HS
	    termselect_nxt <= '0';
	    txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_LS_ENABLED =>
            suspendm_nxt <= '1';
	    opmode_nxt <= "00";
	    xcvrselect_nxt <= "10"; -- switch to LS
	    termselect_nxt <= '1';
	    txvalid_nxt <= txvalid_pkt_nxt; -- from packet_handling_fsm
            txdata_nxt <=  txdata_pkt_nxt; -- from packet_handling_fsm

         when BUS_EVENT_FS_ENABLED =>
            suspendm_nxt <= '1';
	    opmode_nxt <= "00";
	    xcvrselect_nxt <= "01"; -- switch to FS
	    termselect_nxt <= '1';
	    txvalid_nxt <= txvalid_pkt_nxt; -- from packet_handling_fsm
            txdata_nxt <=  txdata_pkt_nxt; -- from packet_handling_fsm

         when BUS_EVENT_HS_ENABLED =>
            suspendm_nxt <= '1';
	    opmode_nxt <= "00";
	    xcvrselect_nxt <= "00"; -- switch to HS
	    termselect_nxt <= '0';
	    txvalid_nxt <= txvalid_pkt_nxt; -- from packet_handling_fsm
            txdata_nxt <=  txdata_pkt_nxt; -- from packet_handling_fsm

         when BUS_EVENT_WF_LS_FS_ENABLED => -- To be able to drive the preamble, PHY requests 1 clk cycle before txvalid is asserted.
            suspendm_nxt <= '1';
	    opmode_nxt <= "00";
	    xcvrselect_nxt <= "11"; -- Send a LS packet on a FS bus or receive a LS packet
	    termselect_nxt <= '1';
	    txvalid_nxt <= '0';
            txdata_nxt <=  (others => '0');

         when BUS_EVENT_LS_FS_ENABLED => -- Low speed device attached via a FS port
            suspendm_nxt <= '1';
	    opmode_nxt <= "00";
	    xcvrselect_nxt <= "11"; -- Send a LS packet on a FS bus or receive a LS packet
	    termselect_nxt <= '1';
	    txvalid_nxt <= txvalid_pkt_nxt; -- from packet_handling_fsm
            txdata_nxt <=  txdata_pkt_nxt; -- from packet_handling_fsm


         when BUS_EVENT_HS_WF_SUSPEND_L1|BUS_EVENT_HS_WF_SUSPEND_L2 =>
            suspendm_nxt <= '1'; -- GMA: TO BE CHECKED
	    opmode_nxt <= "00";
	    if port_speed_r = USB_LOW_SPEED then
	       xcvrselect_nxt <= "10"; -- LS
	    else
	       xcvrselect_nxt <= "01"; -- switch to FS
	    end if;
	    termselect_nxt <= '1';
	    txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_SUSPEND_L1|BUS_EVENT_SUSPEND_L2 =>
            suspendm_nxt <= usbreg_pll_on; -- clocks can be switched off
	    opmode_nxt <= "00";
	    if port_speed_r = USB_LOW_SPEED then
	       xcvrselect_nxt <= "10"; -- LS
	    else
	       xcvrselect_nxt <= "01"; -- switch to FS
	    end if;
	    termselect_nxt <= '1';
	    txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_HOST_DRIVE_RESUME_L1|BUS_EVENT_REFLECT_DEV_RESUME_L1|BUS_EVENT_DRIVE_RESUME_L2 =>
            suspendm_nxt <= '1';
	    opmode_nxt <= "10"; -- RESUME/CHIRP
	    if port_speed_r = USB_LOW_SPEED then
	       xcvrselect_nxt <= "10"; -- LS
	    else
	       xcvrselect_nxt <= "01"; -- switch to FS
	    end if;
	    termselect_nxt <= '1';
	    txvalid_nxt <= '1';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_FSLS_END_RESUME =>
            suspendm_nxt <= '1';
	    opmode_nxt <= "10"; -- RESUME/CHIRP
	    if port_speed_r = USB_LOW_SPEED then
	       xcvrselect_nxt <= "10"; --LS
	    else
	       xcvrselect_nxt <= "01"; -- switch to FS
	    end if;
	    termselect_nxt <= '1';
	    txvalid_nxt <= '0';
            txdata_nxt <= (others => '0');

         when BUS_EVENT_HS_END_RESUME =>
            suspendm_nxt <= '1';
	    opmode_nxt <= "10"; -- RESUME/CHIRP
	    xcvrselect_nxt <= "01"; -- keep FS
	    termselect_nxt <= '1'; -- keep FS
	    txvalid_nxt <= '0';   -- Stop driving resume
            txdata_nxt <= (others => '0');

         when others => --BUS_EVENT_TEST_MODE
             case usbreg_phy_test_mode is
                when "001" =>  -- Test_J
                   suspendm_nxt <= '1';
                   opmode_nxt <= "10";
                   xcvrselect_nxt <= "00"; -- switch to HS
        	   termselect_nxt <= '0';
	    	   txvalid_nxt <= '1';
	           txdata_nxt <= (others => '1');

	        when "010" =>  -- Test_K
	           suspendm_nxt <= '1';
	    	   opmode_nxt <= "10";
	    	   xcvrselect_nxt <= "00"; -- switch to HS
	    	   termselect_nxt <= '0';
	    	   txvalid_nxt <= '1';
	           txdata_nxt <= (others => '0');

	        when "011" =>  -- Test_SE0_NAK
	    	   suspendm_nxt <= '1';
	    	   opmode_nxt <= "00";
	    	   xcvrselect_nxt <= "00"; -- switch to HS
	    	   termselect_nxt <= '0';
	    	   txvalid_nxt <= '0';
	    	   txdata_nxt <= (others => '0');

	        when "100" =>  -- Test_Packet_data
	    	   suspendm_nxt <= '1';
	    	   opmode_nxt <= "00";
	    	   xcvrselect_nxt <= "00"; -- switch to HS
	    	   termselect_nxt <= '0';
	    	   txvalid_nxt <= txvalid_pkt_nxt; -- from packet_handling_fsm
	    	   txdata_nxt <=  txdata_pkt_nxt; -- from packet_handling_fsm

	    	when "101" => -- Test_Force_Enable
	    	   suspendm_nxt <= '1';
	    	   opmode_nxt <= "00";
	    	   xcvrselect_nxt <= "00"; -- switch to HS
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

bus_event_to_others_clk_proc : process (pie_clk,reset_n)

begin
-- pie_portconnect:
-- This signal is set to one when a USB device is connected to
-- the port.
-- The signal is cleared when the device is disconnected, power
-- on the port is removed or an overcurrent condition exists.

-- pie_portenable:
-- This signal is set when a device is connected and the port
-- has been reset.
-- This is cleared when the device is disconnected, the power
-- on the port has been removed or an overcurrent situation
-- exists.

   if reset_n = '0' then
     pie_portconnect <= '0';
     pie_portenable <=  '0';
   elsif pie_clk'event and pie_clk='1' then

      case bus_event_state_r is

         when BUS_EVENT_INIT|BUS_EVENT_POWERED|BUS_EVENT_DISCON =>
            pie_portconnect <= '0';
            pie_portenable <=  '0';

         when BUS_EVENT_DEV_ATTACH|BUS_EVENT_RESET_WF_START_CHIRP_K|
              BUS_EVENT_RESET_WF_END_CHIRP_K|BUS_EVENT_RESET_DRIVE_CHIRP_K|BUS_EVENT_RESET_DRIVE_CHIRP_J|
              BUS_EVENT_RESET_LS_WF_EOR|BUS_EVENT_RESET_FS_WF_EOR|BUS_EVENT_RESET_HS_WF_EOR =>
            pie_portconnect <= '1';
	    pie_portenable <=  '0';

         when others =>
            pie_portconnect <= '1';
            pie_portenable <=  '1';

         end case;
   end if;

end process bus_event_to_others_clk_proc;

portpacket_enabled <= '1' when bus_event_state_r = BUS_EVENT_LS_ENABLED or -- port can propagate both upstream and downstream traffic
                               bus_event_state_r = BUS_EVENT_FS_ENABLED or
                               bus_event_state_r = BUS_EVENT_HS_ENABLED or
                               bus_event_state_r = BUS_EVENT_WF_LS_FS_ENABLED or
                               bus_event_state_r = BUS_EVENT_LS_FS_ENABLED or
                               bus_event_state_r = BUS_EVENT_TEST_MODE else
                      '0';


pie_devicespeed <= "01" when port_speed_r = USB_FULL_SPEED else
                   "10" when port_speed_r = USB_HIGH_SPEED else
                   "00"; -- when port_speed_r = USB_LOW_SPEED


pie_linestate <= ls_filt;

usbreg_portresume_falling <= '1' when usbreg_portresume_sync = '0' and usbreg_portresume_r = '1' else '0';

usbreg_portsuspend_mux <= usbreg_portl1l2suspend_sync when usb_host_pie_portl1l2suspend_use_sync_n = '0' else usbreg_portsuspend_sync;

bus_event_decod_reg_clk_proc : process (pie_clk,reset_n)
begin
   if reset_n = '0' then
      port_speed_r <= USB_LOW_SPEED;
      bus_event_eorst_r <= '0';
      pie_resume_detected <= '0';
      pie_resume_done <= '0';
      usbreg_portresume_r <= '0';
   elsif pie_clk'event and pie_clk='1' then
      usbreg_portresume_r <= usbreg_portresume_sync;
      if set_dev_disc = '1' then
         port_speed_r <= USB_LOW_SPEED;
      elsif set_dev_ls = '1' then
         port_speed_r <= USB_LOW_SPEED;
      elsif set_dev_fs = '1' then
         port_speed_r <= USB_FULL_SPEED;
      elsif set_dev_hs = '1' then
         port_speed_r <= USB_HIGH_SPEED;
      end if;
      if set_bus_event_eorst = '1' then
         bus_event_eorst_r <= '1';
      elsif clear_bus_event_eorst = '1' then
         bus_event_eorst_r <= '0';
      end if;
      -- pie_resume_detected:
      -- This signal is set to one if a resume is received on a
      -- suspended port. The signal is cleared if the
      -- usbreg_portresume_sync signal is high (usb_host_reg_if has reflected the resume)
      if set_resume_detected = '1' then
         pie_resume_detected <= '1';
      elsif usbreg_portresume_sync = '1' then
         pie_resume_detected <= '0';
      end if;
      -- At the end of the resume generated by the host, this
      -- signal is set to one. The signal is cleared, when the
      -- usbreg_portsuspend_sync signal is zero
      if set_resume_end = '1' then
         pie_resume_done <= '1';
      --elsif usbreg_portsuspend_sync = '0' then
      --elsif usbreg_portl1l2suspend_sync = '0' then -- handshake needs to be for both L1 and L2 resume
      elsif usbreg_portsuspend_mux = '0' then
         pie_resume_done <= '0';
      end if;
      if usbreg_reset_sync = '1' then
         port_speed_r <= USB_LOW_SPEED;
         bus_event_eorst_r <= '0';
         pie_resume_detected <= '0';
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


packet_handling_fsm_comb_proc : process(packet_handling_state_r,portpacket_enabled,usb_send_sof,txready,eop_tx,port_speed_r,
starttransfer_pending_r,epinfo_starttransfer_sync,rxerror, usb_endofframe,epinfo_token_sync,rxactive,tx_pending_pkt_r,
req_rx_pkt_r,transfer_pending_r,epinfo_txdata_valid_sync,maxsize_currentpacket,data_byte_cnt,txdata_req_r,iso_transact_cnt_down_r,epinfo_eptype_sync,
bus_event_state_r,usbreg_phy_test_mode,timer_packet_handling_r,sop_start,rxdata,pid_nxt,epinfo_toggle_sync,crc16_valid_nxt,iso_in_pending_r,
rxvalid,epinfo_mult_sync,iso_transact_cnt_up_r,epinfo_subpid_sync,epinfo_maxpacket_sync,remaining_nbytes_r,ignore_data_r)

--variable v_over_run_size         : integer range 0 to MAX_DATA_BYTE_CNT+2;
variable v_over_run_size         : integer range 0 to MAX_DATA_PACKET_SIZE+2;
variable v_nbytes_prev_packets : natural range 0 to MAX_DATA_PACKET_SIZE *2;
variable v_total_data_bytes_sent : unsigned (12 downto 0);

begin
-- default values
   packet_handling_state_nxt <= packet_handling_state_r;
   pie_endtransfer_int  <= '0';
   clear_starttransfer <= '0';

   set_tx_pending_pkt <= '0'; -- data packet
   clear_tx_pending_pkt <= '0'; -- data packet

   set_req_rx_pkt <= '0'; -- data packet or handshake
   clear_req_rx_pkt <= '0'; -- data packet or handshake

   set_transfer_pending <= '0';
   --clear_transfer_pending <= '0';  -- replaced by pie_enddtransfer

   set_pie_response <= '0';
   -- clear_pie_response <= '0'; -- done via epinfo_starttransfer_sync
   pie_response_int <= RESP_DEFAULT;

   timer_packet_handling_nxt <= 0;
   reload_timer_packet_handling_nxt <= '0';
   data_byte_cnt_incr <= '0';
   clear_data_byte_cnt <= '0';

   decr_iso_transact_cnt_down <= '0';
   clear_iso_transact_cnt_down <= '0';
   load_iso_transact_cnt_down <= '0';
   iso_transact_cnt_down_nxt  <= "00";

   set_iso_in_pending <= '0';
   clear_iso_in_pending <= '0';

   set_iso_out_pending   <= '0';
   clear_iso_out_pending <= '0';

   clear_iso_transact_cnt_up <= '0';
   incr_iso_transact_cnt_up <= '0';

   load_remaining_nbytes <= '0';
   decr_remaining_nbytes <= '0';

   data_fifo_fill_rx <= '0';
   data_fifo_fill_tx <= '0';
   clear_data_fifo   <= '0';

   set_rx_nbytes <= '0';
   rx_nbytes     <= (others => '0');

   clear_sop_det <= '0';

   moved_to_tx <= '0';

   set_lpm_l1_ok <= '0';
   set_ignore_data <= '0';
   clear_ignore_data <= '0';

   clear_portenable_int <= '0';
   set_last_rxdata_valid <= '0';


   if portpacket_enabled = '0' and packet_handling_state_r /=USB_PROT_WF_IDLE then
      packet_handling_state_nxt <= USB_PROT_WF_IDLE;
      if transfer_pending_r = '1' or epinfo_starttransfer_sync = '1' or starttransfer_pending_r = '1' then
      -- if a transaction was pending and the port is disabled OR the port was disabled and the dma initiates a start of transfer
         pie_endtransfer_int <= '1';
         set_pie_response <= '1';
         pie_response_int <= RESP_DEFAULT;
      end if;
      clear_starttransfer <= '1';
      clear_tx_pending_pkt <= '1';
      clear_req_rx_pkt <= '1';
      clear_data_byte_cnt <= '1';
      clear_iso_transact_cnt_down <= '1';
      clear_iso_in_pending <= '1';
      clear_iso_out_pending <= '1';
      clear_iso_transact_cnt_up <= '1';
      clear_data_fifo <= '1';
      clear_sop_det <= '1';
      clear_ignore_data <= '1';

   elsif usb_endofframe = '1' and (bus_event_state_r/= BUS_EVENT_TEST_MODE  or usbreg_phy_test_mode = "101") then
      packet_handling_state_nxt <= USB_PROT_WF_STARTSOF;
      if transfer_pending_r = '1' then
      --  any ongoing transfer must be aborted
         pie_endtransfer_int <= '1';
         set_pie_response <= '1';
         pie_response_int <= RESP_BABBLE_ERR;
         clear_starttransfer <= '1';
	 clear_tx_pending_pkt <= '1';
	 clear_req_rx_pkt <= '1';
	 clear_data_byte_cnt <= '1';
	 clear_iso_transact_cnt_down <= '1';
	 clear_iso_in_pending <= '1';
	 clear_iso_out_pending <= '1';
	 clear_iso_transact_cnt_up <= '1';
	 clear_data_fifo <= '1';
         clear_sop_det <= '1';
         clear_ignore_data <= '1';
         clear_portenable_int <= '1'; --the port must be disabled
      end if;

-- BVE : SMS PHY keeps rxerror asserted during remote wakeup until first sync is detected.
--       RxActive is high before first sync is detected. RxError must only be taken into account when RxValid is high.
--   elsif rxerror = '1' and rxactive = '1' then  --  We assume rxerror = 0 during transmission
   elsif rxerror = '1' and rxactive = '1' and rxvalid = '1' then  
      packet_handling_state_nxt <= USB_PROT_WF_IDLE;
--------------------
-- BVE : Do not set pie_endtransfer_int at this moment yet.
--       Wait until rxactive is low      
--      pie_endtransfer_int <= '1';
--------------------
      set_pie_response <= '1';
      pie_response_int <= RESP_TIMEOUT_ERR;
      clear_starttransfer <= '1';
      clear_tx_pending_pkt <= '1';
      clear_req_rx_pkt <= '1';
      clear_data_byte_cnt <= '1';
      clear_iso_transact_cnt_down <= '1';
      clear_iso_in_pending <= '1';
      clear_iso_out_pending <= '1';
      clear_iso_transact_cnt_up <= '1';
      clear_data_fifo <= '1';
      clear_sop_det <= '1';
      clear_ignore_data <= '1';

   else
      case packet_handling_state_r is

         when USB_PROT_WF_IDLE =>
            if rxactive ='0' then
               if transfer_pending_r = '1' then
                  pie_endtransfer_int <= '1'; -- pie_response is already updated in a previous state
               end if;
               clear_iso_in_pending <= '1';
               clear_iso_out_pending <= '1';
               clear_iso_transact_cnt_down <= '1';
               clear_iso_transact_cnt_up <= '1';
               if portpacket_enabled = '1' then
                  packet_handling_state_nxt <= USB_PROT_IDLE;
               end if;
               clear_tx_pending_pkt <= '1';
               clear_req_rx_pkt <= '1';
               clear_data_byte_cnt <= '1';
               clear_data_fifo    <= '1';
               clear_sop_det <= '1';
               clear_ignore_data <= '1';
               -- insert an interpacket delay for any cases
	       if port_speed_r = USB_LOW_SPEED or (port_speed_r = USB_FULL_SPEED and bus_event_state_r=BUS_EVENT_LS_FS_ENABLED)then
	          timer_packet_handling_nxt <= INTER_PACKET_DELAY_LS-1;
	       elsif port_speed_r = USB_FULL_SPEED then
	          timer_packet_handling_nxt <= INTER_PACKET_DELAY_FS-1;
	       else
	          timer_packet_handling_nxt <= INTER_PACKET_DELAY_HS-1;
	       end if;
               reload_timer_packet_handling_nxt <= '1';
            end if;

         when USB_PROT_IDLE =>
            if bus_event_state_r = BUS_EVENT_TEST_MODE and usbreg_phy_test_mode = "100" then
	       packet_handling_state_nxt <= USB_PROT_WF_TX_TEST_PACKET;
	       clear_data_byte_cnt <= '1';
               clear_data_fifo    <= '1';
    	       clear_iso_in_pending <= '1';
    	       clear_iso_out_pending <= '1';
    	       clear_iso_transact_cnt_down <= '1';
    	       clear_iso_transact_cnt_up <= '1';
               clear_starttransfer <= '1';
               clear_ignore_data <= '1';
               if transfer_pending_r = '1' then
	          pie_endtransfer_int <= '1'; -- pie_response is already updated in a previous state
               end if;
               timer_packet_handling_nxt <= PACKET_TURNAROUND_TIMEOUT_HS-1;
               reload_timer_packet_handling_nxt <= '1';
            elsif usb_send_sof = '1'  then
               packet_handling_state_nxt <= USB_PROT_TX_SOF_PID;
            elsif (starttransfer_pending_r = '1' or epinfo_starttransfer_sync = '1') and timer_packet_handling_r = 0 then
               set_transfer_pending <= '1';
               clear_starttransfer <= '1';

               case epinfo_token_sync is
                  when TOKEN_EXT => -- Special Token packet of 4 bytes must be sent
                     packet_handling_state_nxt <= USB_PROT_TX_SPECIAL_TOKEN_PID;

                  when TOKEN_SETUP => -- Token packet of 3 bytes must be sent
                     packet_handling_state_nxt <= USB_PROT_TX_TOKEN_PKT_PID;

                  when TOKEN_OUT => -- Token packet of 3 bytes must be sent
                     packet_handling_state_nxt <= USB_PROT_TX_TOKEN_PKT_PID;
                     if epinfo_eptype_sync = EP_ISO then -- isochronous endpoint
		        set_iso_out_pending <= '1';
                        load_remaining_nbytes <= '1'; -- done once at the start of the transfer
                        load_iso_transact_cnt_down <= '1';
			-- iso_transact_cnt_down_r is updated at the start of each transaction depending of PID received
			if epinfo_mult_sync = "00" then -- not expected value, will be handled as epinfo_mult_sync = "01"
			   iso_transact_cnt_down_nxt <= "01"; -- 1 transaction is expected
			else
			   iso_transact_cnt_down_nxt  <= unsigned(epinfo_mult_sync); -- 1 or more transactions are expected
	                end if;
	             end if;

                  when TOKEN_IN => -- Token packet of 3 bytes must be sent
                     packet_handling_state_nxt <= USB_PROT_TX_TOKEN_PKT_PID;
                     if epinfo_eptype_sync = EP_ISO then -- isochronous endpoint
                        set_iso_in_pending <= '1';
                        load_remaining_nbytes <= '1'; -- done once at the start of the transfer
                        load_iso_transact_cnt_down <= '1';
                        -- iso_transact_cnt_down_r is updated at the start of each transaction depending of PID received
                        if epinfo_mult_sync = "00" then -- not expected value, will be handled as epinfo_mult_sync = "01"
                           iso_transact_cnt_down_nxt <= "01"; -- 1 transaction is expected
                        else
	                   iso_transact_cnt_down_nxt  <= unsigned(epinfo_mult_sync); -- 1 or more transactions are expected
	                end if;
	             end if;

                  when TOKEN_PING => -- Token packet of 3 bytes must be sent
                     packet_handling_state_nxt <= USB_PROT_TX_TOKEN_PKT_PID;

                  when TOKEN_SSPLIT => -- Special Token packet of 4 bytes must be sent
                     packet_handling_state_nxt <= USB_PROT_TX_SPECIAL_TOKEN_PID;

                  when TOKEN_CSPLIT => -- Special Token packet of 4 bytes must be sent
                     packet_handling_state_nxt <= USB_PROT_TX_SPECIAL_TOKEN_PID;

                  when others =>-- TOKEN_RESERVED -- back to idle -- this behaviour is not expected
                     packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               end case;

            end if;

         -------------------------- SOF HANDLING------------------------------

         when USB_PROT_WF_STARTSOF => -- IDLE STATE any others packets can be transmitted
            if usb_send_sof = '1' then
               packet_handling_state_nxt <= USB_PROT_TX_SOF_PID;
            end if;

         when USB_PROT_TX_SOF_PID =>
            if txready = '1' then
               if port_speed_r = USB_LOW_SPEED then -- LS Keep-alive will be sent. For this, only PID must be sent
                  packet_handling_state_nxt <= USB_PROT_ALL_WF_END_TX_PACKET;
               else
                  packet_handling_state_nxt <= USB_PROT_TX_SOF_BYTE2;
               end if;
            end if;

         when USB_PROT_TX_SOF_BYTE2 =>
            if txready = '1'  then
               packet_handling_state_nxt <= USB_PROT_TX_SOF_BYTE3;
            end if;

         when USB_PROT_TX_SOF_BYTE3 =>
            if txready = '1' then
	       packet_handling_state_nxt <= USB_PROT_TX_SOF_WF_EOP;
	    end if;

	 when USB_PROT_TX_SOF_WF_EOP =>
	    if eop_tx = '1' then
	      -- no endtransfer pulse at the end of sof
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
	    end if;

         ------------------ PACKET TOKEN HANDLING-------------------------------------

         when USB_PROT_WF_TX_TOKEN_PKT_PID =>  -- interperpacket delay between 2 packets of token phase
         --(EXT or SPLIT transactions) or 2 ISO HBW transactions of the same transfer
            if timer_packet_handling_r = 0 then
               packet_handling_state_nxt <= USB_PROT_TX_TOKEN_PKT_PID;
            end if;

         when USB_PROT_TX_TOKEN_PKT_PID =>
            if txready = '1' then
               packet_handling_state_nxt <= USB_PROT_TX_TOKEN_PKT_BYTE2;
            end if;

         when USB_PROT_TX_TOKEN_PKT_BYTE2 =>
            if txready = '1'  then
               packet_handling_state_nxt <= USB_PROT_TX_TOKEN_PKT_BYTE3;
            end if;

         when USB_PROT_TX_TOKEN_PKT_BYTE3 =>
            if txready = '1' then
	       packet_handling_state_nxt <= USB_PROT_ALL_WF_END_TX_PACKET;
               case epinfo_token_sync is

		  when TOKEN_SETUP|TOKEN_OUT => -- DATA PACKET must be transmitted
		     set_tx_pending_pkt <= '1';

                  when TOKEN_IN => -- DATA PACKET or HANDSHAKE is expected
                     set_req_rx_pkt <= '1';

                  when TOKEN_PING => -- HANDSHAKE is expected
    	             set_req_rx_pkt <= '1';

    	          when TOKEN_SSPLIT =>
    	             case epinfo_subpid_sync is
		        when SUB_TOKEN_SETUP|SUB_TOKEN_OUT =>
		           set_tx_pending_pkt <= '1'; -- DATA PACKET must be transmitted

		        when SUB_TOKEN_IN =>
		           case epinfo_eptype_sync is
                              when EP_CTRL|EP_BULK => -- HANDSHAKE is expected
                                 set_req_rx_pkt <= '1';

		              when others => -- EP_ISO|EP_INT  -- no handshake is expected. Waiting for the end of the transaction.
		           -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
                               set_pie_response <= '1';
                               pie_response_int <= RESP_RCV_TX_ACK_HSK;
                               -- Indicates to the dma that the  pie is ready to go to the complete split transaction
                           end case;
                        when others => -- SUB_TOKEN_LPM
                            --Not expected
                        end case;

    	          when TOKEN_CSPLIT =>
                  -- DATA PACKET or HANDSHAKE is expected
                     set_req_rx_pkt <= '1';

    	          when TOKEN_EXT =>
    	             if epinfo_subpid_sync = SUB_TOKEN_LPM then-- HANDSHAKE is expected
                        set_req_rx_pkt <= '1';
                     end if;

                  when others =>  --TOKEN_RESERVED
                     --Not expected
	         end case;
             end if;



         -------------------- SPECIAL PID HANDLING (CSPLIT/SSPLIT or EXT)-------------------------------------
	 when USB_PROT_TX_SPECIAL_TOKEN_PID =>
	    if txready = '1' then
               packet_handling_state_nxt <= USB_PROT_TX_SPECIAL_TOKEN_BYTE2;
            end if;

         when USB_PROT_TX_SPECIAL_TOKEN_BYTE2 =>
            if txready = '1'  then
               packet_handling_state_nxt <= USB_PROT_TX_SPECIAL_TOKEN_BYTE3;
            end if;

         when USB_PROT_TX_SPECIAL_TOKEN_BYTE3 =>
            if txready = '1'  then
               if epinfo_token_sync = TOKEN_EXT then -- only 3 bytes
                 packet_handling_state_nxt <= USB_PROT_WF_END_TX_SPECIAL_TOKEN;
               else -- SPLIT transaction token is 4 bytes
                  packet_handling_state_nxt <= USB_PROT_TX_SPECIAL_TOKEN_BYTE4;
               end if;
            end if;

         when USB_PROT_TX_SPECIAL_TOKEN_BYTE4 =>
            if txready = '1' then
	       packet_handling_state_nxt <= USB_PROT_WF_END_TX_SPECIAL_TOKEN;
	    end if;

	 when USB_PROT_WF_END_TX_SPECIAL_TOKEN => -- wait the end of the packet of the first token of the token phase
	 -- this state is also used as waiting time between 2 transactions in iso HBW
	    if eop_tx = '1' then  --  Wait Until the EOP
                if port_speed_r = USB_LOW_SPEED or (port_speed_r = USB_FULL_SPEED and bus_event_state_r=BUS_EVENT_LS_FS_ENABLED) then
	       	   timer_packet_handling_nxt  <= INTER_PACKET_DELAY_LS-1;
	       	elsif port_speed_r = USB_FULL_SPEED then
	       	   timer_packet_handling_nxt <= INTER_PACKET_DELAY_FS-1;
	       	else
	       	   timer_packet_handling_nxt <= INTER_PACKET_DELAY_HS-1;
		end if;
	       reload_timer_packet_handling_nxt <= '1';
	       -- jump to the 2nd token of the token phase (SPLIT/EXT) or token phase(ISO HBW)
	       packet_handling_state_nxt <= USB_PROT_WF_TX_TOKEN_PKT_PID;
            end if;

        --------------- HANDLING OF END OF TRANSMITTED PACKET (incl. end of token phase)--------------------------------------
	 when USB_PROT_ALL_WF_END_TX_PACKET =>
	    if eop_tx = '1' then  --  Wait Until the EOP
	       if req_rx_pkt_r = '1' then -- handshake or data packet from device is expected, start timeout timer
	          if port_speed_r = USB_LOW_SPEED or (port_speed_r = USB_FULL_SPEED and bus_event_state_r=BUS_EVENT_LS_FS_ENABLED)then
	             timer_packet_handling_nxt <= PACKET_TURNAROUND_TIMEOUT_LS-1;
	       	  elsif port_speed_r = USB_FULL_SPEED then
	       	     timer_packet_handling_nxt <= PACKET_TURNAROUND_TIMEOUT_FS-1;
	          else
	             timer_packet_handling_nxt <= PACKET_TURNAROUND_TIMEOUT_HS-1;
	          end if;
	          reload_timer_packet_handling_nxt <= '1';
                  packet_handling_state_nxt <= USB_PROT_ALL_WF_RX_RESP;
                  clear_sop_det <= '1'; -- next state is waiting for SOP. Safer to clear the SOP detection.
                  clear_req_rx_pkt <= '1'; -- no other packet (data or hanshake) is expected after this one
	       elsif tx_pending_pkt_r = '1' then -- data packet to be transmitted
	          if port_speed_r = USB_LOW_SPEED or (port_speed_r = USB_FULL_SPEED and bus_event_state_r=BUS_EVENT_LS_FS_ENABLED)then
	            timer_packet_handling_nxt  <= INTER_PACKET_DELAY_LS-1;
	          elsif port_speed_r = USB_FULL_SPEED then
		     timer_packet_handling_nxt <= INTER_PACKET_DELAY_FS-1;
		  else
		     timer_packet_handling_nxt <= INTER_PACKET_DELAY_HS-1;
		  end if;
                  reload_timer_packet_handling_nxt <= '1';
                  packet_handling_state_nxt <= USB_PROT_OUT_SETUP_WF_TX_DATA_PID;
               else
                  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
	       end if;
	    end if;

--------------- HANDLING OF RCV PID ------------------------------------------------------------------------------
         when USB_PROT_ALL_WF_RX_RESP => -- Received DATA PACKET or HANDSHAKE is expected
            if timer_packet_handling_r = 0 then -- TIMEOUT : Data Packet or handshake not received on time
               --pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
               set_pie_response <= '1';
               pie_response_int <= RESP_TIMEOUT_ERR;
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
            elsif sop_start = '1' then
            -- Start of packet is detected (pulse event). Timer is reloaded.
            -- This time, it is used to avoid the FSM stays stuck forever in this state.
            -- Waiting for rxactive is asserted
               if port_speed_r = USB_LOW_SPEED or (port_speed_r = USB_FULL_SPEED and bus_event_state_r=BUS_EVENT_LS_FS_ENABLED) then
                  timer_packet_handling_nxt <= PACKET_EVENT_TIMEOUT_LS-1;
               elsif port_speed_r = USB_FULL_SPEED then
	          timer_packet_handling_nxt <= PACKET_EVENT_TIMEOUT_FS-1;
	       else
	          timer_packet_handling_nxt <= PACKET_EVENT_TIMEOUT_HS-1;
	       end if;
	       reload_timer_packet_handling_nxt <= '1';
	    end if;
	    if rxactive = '1' and rxvalid ='1' then
               clear_sop_det <= '1';
	       if rxdata(7 downto 4) = not rxdata(3 downto 0) then -- chech for valid PID
                  -- Hanshake received with a Special Token
	          if epinfo_token_sync = TOKEN_SSPLIT or epinfo_token_sync = TOKEN_CSPLIT or
	               (epinfo_token_sync = TOKEN_EXT and epinfo_subpid_sync = SUB_TOKEN_LPM ) then
	             case pid_nxt is
	                when PID_ACK =>
	                   if epinfo_token_sync = TOKEN_CSPLIT and epinfo_subpid_sync = SUB_TOKEN_IN then
	                   -- data packet is expected or another handshake (apart from ACK)
	                      pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
			   else -- ACK is a valid handshake
			      pie_response_int <= RESP_RCV_TX_ACK_HSK;
	                   end if;
	                   -- pie_endtransfer_int <= '1'; -- end of transaction: indicated to dma when FSM jumps to USB_PROT_IDLE
			   set_pie_response <= '1';
			   packet_handling_state_nxt <= USB_PROT_WF_IDLE;
			   if epinfo_token_sync = TOKEN_EXT and epinfo_subpid_sync = SUB_TOKEN_LPM then
			      set_lpm_l1_ok <= '1'; -- device has ACKed the LPM request
			   end if;

	                when PID_NAK =>
	                -- NAK is always a valid answer when a packet is expected after the token phase of a split transaction/LPM
	                   pie_response_int <= RESP_RCV_NAK_HSK;
  	                   -- pie_endtransfer_int <= '1'; -- end of transaction: indicated to dma when FSM jumps to USB_PROT_IDLE
   			   set_pie_response <= '1';
			   packet_handling_state_nxt <= USB_PROT_WF_IDLE;

	                when PID_STALL =>
	                -- to simplify the logic, return STALL even if it is not a valid HSK for some specific transaction sequences
	                   pie_response_int <= RESP_RCV_STALL_HSK;
			   -- pie_endtransfer_int <= '1'; -- end of transaction: indicated to dma when FSM jumps to USB_PROT_IDLE
			   set_pie_response <= '1';
			   packet_handling_state_nxt <= USB_PROT_WF_IDLE;

			when PID_NYET =>
			-- to simplify the logic, return NYET even if it is not a valid HSK for some specific transaction sequences
			    pie_response_int <= RESP_RCV_NYET_HSK;
			   -- pie_endtransfer_int <= '1'; -- end of transaction: indicated to dma when FSM jumps to USB_PROT_IDLE
			    set_pie_response <= '1';
			    packet_handling_state_nxt <= USB_PROT_WF_IDLE;

	                when PID_ERR =>
	                -- to simplify the logic, return ERR even if it is not a valid HSK for some specific transaction sequences
			   pie_response_int <= RESP_RCV_ERR_HSK;
		           -- pie_endtransfer_int <= '1'; -- end of transaction: indicated to dma when FSM jumps to USB_PROT_IDLE
			   set_pie_response <= '1';
			   packet_handling_state_nxt <= USB_PROT_WF_IDLE;

	                when PID_DATA0|PID_DATA1 =>
	                 -- only valid for IN Complete Split transactions
	                   if epinfo_token_sync = TOKEN_CSPLIT and epinfo_subpid_sync = SUB_TOKEN_IN then
			      if (epinfo_toggle_sync ='0' and pid_nxt =  PID_DATA0) or (epinfo_toggle_sync ='1' and pid_nxt =  PID_DATA1) then

			          packet_handling_state_nxt <= USB_PROT_IN_RCV_DATA_PACKET;
			          clear_data_byte_cnt <= '1';
			           -- response is already registered here to make the distinction from a PID_MDATA
				   -- No acknowledge is expected after this data packet.
				   -- if there is no transaction error by the end of the transaction, pie_response will indicate ACK to the dma
				   -- (last data received successfully) at the end of this transaction
				   -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
				  pie_response_int <= RESP_RCV_TX_ACK_HSK; --
                                  set_pie_response <= '1';
			      else
			         pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
			   	  -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
			   	 set_pie_response <= '1';
			   	 packet_handling_state_nxt <= USB_PROT_WF_IDLE;
			      end if;
			   else -- PID_DATA0/PID_DATA1 was not expected for this transaction
			      pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
			      -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
			      set_pie_response <= '1';
			      packet_handling_state_nxt <= USB_PROT_WF_IDLE;
			   end if;

	                when PID_MDATA =>
	                -- only valid for IN Complete Split Interrupt or Iso transactions
	                   if epinfo_token_sync = TOKEN_CSPLIT and epinfo_subpid_sync = SUB_TOKEN_IN and
	                              (epinfo_eptype_sync = EP_INT or epinfo_eptype_sync = EP_ISO) then

  		              packet_handling_state_nxt <= USB_PROT_IN_RCV_DATA_PACKET;
			      clear_data_byte_cnt <= '1';
			      -- response is already registered here to make the distinction from a PID_DATAx.
			      -- No acknowledge is expected after this data packet.
			      -- if there is no transaction error by the end of the transaction, pie_response will indicate MDATA to the dma
			      -- at the end of this transaction (= current data is received successfully, more data to be received,
			      -- DMA should request a new complete split in the next uframe
			      pie_response_int <= RESP_BUFF_ERR_OR_MDATA; -- if the
			      set_pie_response <= '1';

			   else -- PID_MDATA was not expected for this transaction
			     -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
			      pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
			      set_pie_response <= '1';
			      packet_handling_state_nxt <= USB_PROT_WF_IDLE;
			   end if;

	                when others => -- unexpected PID
	                    -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
	                    set_pie_response <= '1';
		            pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
                            packet_handling_state_nxt <= USB_PROT_WF_IDLE;
	                 end case;

	          elsif iso_in_pending_r = '1' then -- iso in FS/HS/HBW in a no split transaction
	             case pid_nxt is
	                 when PID_DATA0 =>
	                    if (iso_transact_cnt_down_r = "01" or iso_transact_cnt_up_r = "00") then -- valid transaction
	                    -- the check on iso_transact_cnt_up is required to filter out
	                    -- "iso_transact_cnt_down_r = "10" AND iso_transact_cnt_up = "01" " case
	                    -- (direct jump from PID_DATA2 --> PID_DATA0 is not possible)
	                       load_iso_transact_cnt_down <= '1';
	                       iso_transact_cnt_down_nxt  <= "00"; -- this is the last transaction of the uframe
                               packet_handling_state_nxt <= USB_PROT_IN_RCV_DATA_PACKET;
                               clear_data_byte_cnt <= '1';
                            else
                               -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
			       set_pie_response <= '1';
			       pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
                               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                            end if;
	                 when PID_DATA1 =>
	                    if (iso_transact_cnt_down_r = "11" or iso_transact_cnt_down_r = "10") then -- valid transaction
			       load_iso_transact_cnt_down <= '1';
			       iso_transact_cnt_down_nxt  <= "01"; -- there is still one transaction after this one, next one must be PID_DATA0
			       packet_handling_state_nxt <= USB_PROT_IN_RCV_DATA_PACKET;
                               clear_data_byte_cnt <= '1';
                            elsif epinfo_mult_sync = "00" or epinfo_mult_sync = "01" then -- Host Controller should be able to accept DATA1 PID in no HBW iso
                               load_iso_transact_cnt_down <= '1';
			       iso_transact_cnt_down_nxt  <= "00"; -- this is the last transaction of the uframe
			       packet_handling_state_nxt <= USB_PROT_IN_RCV_DATA_PACKET;
                               clear_data_byte_cnt <= '1';
                            else
                               -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
			       set_pie_response <= '1';
			       pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
                               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                            end if;
	                 when PID_DATA2 =>
	                    if iso_transact_cnt_down_r = "11" then -- valid transaction
	                       load_iso_transact_cnt_down <= '1';
	                       iso_transact_cnt_down_nxt  <= "10"; -- there are still two transactions after this one, next one must be PID_DATA1
			       packet_handling_state_nxt <= USB_PROT_IN_RCV_DATA_PACKET;
			       clear_data_byte_cnt <= '1';
			    else
			      -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
                               set_pie_response <= '1';
			       pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
			       packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                            end if;

	                 when others => -- unexpected PID
	                  -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
	                  set_pie_response <= '1';
		          pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
                          packet_handling_state_nxt <= USB_PROT_WF_IDLE;
                     end case;
	          else -- standard transaction (excl. iso)
	          -- To save some logic, like for the split transactions, the pie can return the real handshake received
	          -- from device as pie_response (only possible for NAK, STALL and NYET, check whether ACK, DATAx is an allowed feedback must
	          -- always be performed
	          --
	             case pid_nxt is
	                when PID_ACK =>
	                   if epinfo_token_sync = TOKEN_IN then  -- ACK was not expected for this transaction
		              pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
	                   else -- ACK is a valid handshake
		              pie_response_int <= RESP_RCV_TX_ACK_HSK;
	                   end if;
	                  -- pie_endtransfer_int <= '1'; -- end of transaction: indicated to dma when FSM jumps to USB_PROT_IDLE
			   set_pie_response <= '1';
			   packet_handling_state_nxt <= USB_PROT_WF_IDLE;
	                when PID_NAK =>
                           pie_response_int <= RESP_RCV_NAK_HSK;
	                   -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
			   set_pie_response <= '1';
			   packet_handling_state_nxt <= USB_PROT_WF_IDLE;

	                when PID_STALL =>
                           pie_response_int <= RESP_RCV_STALL_HSK;
		           -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
		           set_pie_response <= '1';
			   packet_handling_state_nxt <= USB_PROT_WF_IDLE;

	                when PID_NYET =>
	                   pie_response_int <= RESP_RCV_NYET_HSK;
                         -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
			   set_pie_response <= '1';
			   packet_handling_state_nxt <= USB_PROT_WF_IDLE;

	                when PID_DATA0|PID_DATA1 =>
	                   if epinfo_token_sync = TOKEN_IN then
                              if (epinfo_toggle_sync ='0' and pid_nxt =  PID_DATA0) or (epinfo_toggle_sync ='1' and pid_nxt =  PID_DATA1) then
                                  packet_handling_state_nxt <= USB_PROT_IN_RCV_DATA_PACKET;
  		                  clear_data_byte_cnt <= '1';
                               else
                                  pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
			          -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
			          set_ignore_data <= '1';
			          set_pie_response <= '1';
			          packet_handling_state_nxt <= USB_PROT_IN_RCV_DATA_PACKET;
  		                  clear_data_byte_cnt <= '1';
                               end if;
                           else -- PID_DATA0/PID_DATA1 was not expected for this transaction
			      pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
			      -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
			      set_pie_response <= '1';
			      packet_handling_state_nxt <= USB_PROT_WF_IDLE;
	                   end if;

	                when others => -- unexpected PID
	                  -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
	                  set_pie_response <= '1';
		          pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
                          packet_handling_state_nxt <= USB_PROT_WF_IDLE;

	              end case;
	          end if; -- if iso_in_pending_r = '1'
	       else -- bad PID, Ignore the remainder packet
	          -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
	          set_pie_response <= '1';
		  pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
                  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               end if;
            end if;


----------------------HANDLING of DATA IN TRANSACTION (RCV PACKET + TX HANDSHAKE) --------------------------------------
         when USB_PROT_IN_RCV_DATA_PACKET => -- crc16 computing has started

	    --v_over_run_size:= to_integer(maxsize_currentpacket * (iso_transact_cnt_up_r +1))+2; -- v_over_run_size takes into account the 2 CRC16 bytes
	    v_over_run_size:= to_integer(maxsize_currentpacket)+2; -- v_over_run_size takes into account the 2 CRC16 bytes

            if rxactive ='0' then -- EOP is detected, CRC16 should be valid
               if ignore_data_r = '1' then
               --If there is a data toggle mismatch on a bulk, interrupt or control transfer that is not a split transaction,
               -- the host controller must send an ACK towards the device
                  packet_handling_state_nxt <= USB_PROT_IN_WF_TX_ACK_HANDSHAKE;
                  if port_speed_r = USB_LOW_SPEED or (port_speed_r = USB_FULL_SPEED and bus_event_state_r=BUS_EVENT_LS_FS_ENABLED)then
		     timer_packet_handling_nxt <= INTER_PACKET_DELAY_LS-1;
		  elsif port_speed_r = USB_FULL_SPEED then
		     timer_packet_handling_nxt <= INTER_PACKET_DELAY_FS-1;
		  else
		     timer_packet_handling_nxt <= INTER_PACKET_DELAY_HS-1;
		  end if;
                  reload_timer_packet_handling_nxt <= '1';
               elsif crc16_valid_nxt = '1' then
                  if epinfo_token_sync = TOKEN_CSPLIT then
                     packet_handling_state_nxt <= USB_PROT_WF_END_TRANSFER_DELAY; -- split transaction, no handshake to be returned to the device
                     -- pie_response has been registered in the previous state (RESP_BUFF_ERR_OR_MDATA or RESP_RCV_TX_ACK_HSK)
                     -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
                     set_rx_nbytes <= '1';
		     rx_nbytes      <=  std_logic_vector(data_byte_cnt-2); -- nr of data bytes = data_byte counter - 2 bytes of CRC16
		     timer_packet_handling_nxt <= END_TRANSFER_DELAY;
		     reload_timer_packet_handling_nxt <= '1';

	          elsif iso_in_pending_r = '0' then -- non isochronous ep : packet will be ACKed
		     packet_handling_state_nxt <= USB_PROT_IN_WF_TX_ACK_HANDSHAKE;
		     if port_speed_r = USB_LOW_SPEED or (port_speed_r = USB_FULL_SPEED and bus_event_state_r=BUS_EVENT_LS_FS_ENABLED)then
		        timer_packet_handling_nxt <= INTER_PACKET_DELAY_LS-1;
		     elsif port_speed_r = USB_FULL_SPEED then
		        timer_packet_handling_nxt <= INTER_PACKET_DELAY_FS-1;
		     else
		        timer_packet_handling_nxt <= INTER_PACKET_DELAY_HS-1;
		     end if;
                     reload_timer_packet_handling_nxt <= '1';
                     set_rx_nbytes <= '1'; -- moved to next state
		     rx_nbytes      <=  std_logic_vector(data_byte_cnt-2); -- nr of data bytes = data_byte counter - 2 bytes of CRC16
                  else -- isochronous ep -- no handshake is returned. Data packet is processed
                     if iso_transact_cnt_down_r  = "00" or (data_byte_cnt-2 /= unsigned('0' & epinfo_maxpacket_sync)) or
                     remaining_nbytes_r <= unsigned('0' & epinfo_maxpacket_sync) then -- last iso transaction
                        -- it was the last possible transaction (PID = DATA0) OR
                        -- In the current transaction, the host has received less bytes than maxpacket OR
                        -- the total expected remaining number of bytes (incl. the current transaction) is less than maxpacket size
		        clear_iso_in_pending   <= '1';
                        set_rx_nbytes <= '1';
                        v_nbytes_prev_packets:= to_integer(unsigned(epinfo_maxpacket_sync)) * to_integer(iso_transact_cnt_up_r);
                        rx_nbytes      <=  std_logic_vector(data_byte_cnt-2 + to_unsigned(v_nbytes_prev_packets,12));
                        packet_handling_state_nxt <= USB_PROT_WF_END_TRANSFER_DELAY;
                        timer_packet_handling_nxt <= END_TRANSFER_DELAY;
			reload_timer_packet_handling_nxt <= '1';
                        -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
                        set_pie_response <= '1';
		        pie_response_int <= RESP_RCV_TX_ACK_HSK; -- last ISO in transaction is received
		     else -- valid iso transaction, not the last one
		        incr_iso_transact_cnt_up <= '1';
		        decr_remaining_nbytes <= '1';
		     --   set_rx_nbytes <= '1'; -- will be only used to generate the last rxdata_valid in case maxpacket is not a nice multiple of USB_DATAWIDTH_IN_BYTES
	             --v_nbytes_prev_packets:= to_integer(unsigned(epinfo_maxpacket_sync)) * to_integer(iso_transact_cnt_up_r);
                     --rx_nbytes      <=  std_logic_vector(data_byte_cnt-2 + to_unsigned(v_nbytes_prev_packets,12));
		        packet_handling_state_nxt <= USB_PROT_ISO_WF_NXT_PKT;
		        if port_speed_r = USB_LOW_SPEED or (port_speed_r = USB_FULL_SPEED and bus_event_state_r=BUS_EVENT_LS_FS_ENABLED)then
			   timer_packet_handling_nxt <= INTER_PACKET_DELAY_LS-1;
			elsif port_speed_r = USB_FULL_SPEED then
			   timer_packet_handling_nxt <= INTER_PACKET_DELAY_FS-1;
			else
			   timer_packet_handling_nxt <= INTER_PACKET_DELAY_HS-1;
			end if;
                        reload_timer_packet_handling_nxt <= '1';
	             end if;
                  end if;

               else  --  BAD CRC: Data Packet Corrupted , no  handshake is returned
                  -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
		  set_pie_response <= '1';
		  pie_response_int <= RESP_TIMEOUT_ERR; -- transaction error
                  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               end if;

            elsif rxvalid = '1' and ignore_data_r = '0' then  -- 1 data byte is ready and PIE can accept it
               if to_integer(data_byte_cnt) < v_over_run_size then -- prevent buffer overflow
                  data_byte_cnt_incr <= '1';
                  data_fifo_fill_rx  <= '1';
               else
                  set_pie_response <= '1';
		  pie_response_int <= RESP_BABBLE_ERR; -- transaction error
		  -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
		  packet_handling_state_nxt <= USB_PROT_WF_IDLE;
               end if;
            end if;

         when USB_PROT_WF_END_TRANSFER_DELAY =>
            if timer_packet_handling_r = 0 then --insert a delay to let more time to the DMA to read last fifo
               set_last_rxdata_valid <= '1';
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
            end if;

         when USB_PROT_IN_WF_TX_ACK_HANDSHAKE => -- wait for interpacket delay expires
            if timer_packet_handling_r = 0 then
	 	packet_handling_state_nxt <= USB_PROT_IN_TX_ACK_HANDSHAKE;
	 	if ignore_data_r = '0' then
	 	   set_last_rxdata_valid <= '1';
		end if;
	    end if;

	 when USB_PROT_IN_TX_ACK_HANDSHAKE => -- HandShake Packet is only one byte
	    if txready = '1' then
	       packet_handling_state_nxt <= USB_PROT_ALL_WF_END_TX_PACKET;
	       if ignore_data_r = '0' then -- DATA IN packet has been accepted
	          set_pie_response <= '1';
	          pie_response_int <= RESP_RCV_TX_ACK_HSK;  -- ACK hanshake is transmitted
	       end if;
	       -- pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
            end if;


         when USB_PROT_ISO_WF_NXT_PKT => -- insert interpacket delay before next transaction (Iso HBW only)
            if timer_packet_handling_r = 0 then
               packet_handling_state_nxt <=  USB_PROT_TX_TOKEN_PKT_PID;
            end if;

--------------- HANDLING OF OUT/SETUP DATA PACKET--------------------------------------
         when USB_PROT_OUT_SETUP_WF_TX_DATA_PID =>
            if timer_packet_handling_r = 0 then -- interpacket delay has expired
               packet_handling_state_nxt <= USB_PROT_OUT_SETUP_TX_DATA_PID_1;
               moved_to_tx <= '1';
               clear_data_byte_cnt <= '1'; -- initialise data byte counter for the packet to be sent (must be done even for HBW transactions)
            end if;

   -- USB_PROT_OUT_SETUP_TX_DATA_PID is split into 2 states _1 and _2 to let more time to the dma_handler
   --to prepare its first data. Before txready from PHY is high,
   -- data from dma does not have to be there
         when USB_PROT_OUT_SETUP_TX_DATA_PID_1 =>
          v_total_data_bytes_sent := data_byte_cnt + (unsigned(epinfo_maxpacket_sync) * iso_transact_cnt_up_r);
           -- pid byte must be driven until txready is high
            if epinfo_txdata_valid_sync ='1' and txready = '0' then
               if to_integer(v_total_data_bytes_sent(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0))= 0 then
               -- for 2nd and 3rd transaction of ISO OUT HBW, only when a new packet of USB_DATAWIDTH_IN_BYTES is required from DMA
               -- (maxpacket size is a nice multiple of USB_DATAWIDTH_IN_BYTES)
     	          data_fifo_fill_tx <= '1'; -- first data is available
     	       end if;
	       packet_handling_state_nxt <= USB_PROT_OUT_SETUP_TX_DATA_PID_2;
	    elsif txready = '1' then  -- empty packet or buffer underrun
	     -- DATAx PID is sent
	        if to_integer(maxsize_currentpacket) = 0 then -- empty packet to transmit
	            packet_handling_state_nxt <= USB_PROT_OUT_SETUP_TX_CRC16_BYTE1;
                else
                 -- buffer underrun error, PIE will corrupt the CRC
                 -- error will be reported at the end of the packet
                    packet_handling_state_nxt <= USB_PROT_BAD_OUT_SETUP_TX_CRC16_BYTE1;
                end if;
             end if;

	  when USB_PROT_OUT_SETUP_TX_DATA_PID_2 =>
	     if txready = '1' then
	     -- DATAx PID is sent
	 	if to_integer(maxsize_currentpacket) = 0 then -- empty packet to transmit
	 	   packet_handling_state_nxt <= USB_PROT_OUT_SETUP_TX_CRC16_BYTE1;
                else -- non empty packet must be transmit
                   data_byte_cnt_incr <= '1';
	 	   packet_handling_state_nxt <= USB_PROT_OUT_SETUP_TX_DATA_PACKET;
	 	end if;
	     end if;

	  when USB_PROT_OUT_SETUP_TX_DATA_PACKET => -- CRC16 computing has started
	     if txready = '1' then  -- data must be sent to the PHY
                if data_byte_cnt < maxsize_currentpacket then
                   data_byte_cnt_incr <= '1';
                else -- end of packet to transmit, generate CRC16 bytes
                   packet_handling_state_nxt <= USB_PROT_OUT_SETUP_TX_CRC16_BYTE1;
	        end if;
	     end if;
	     if txdata_req_r = '1' then -- request time for a new data from DMA
	        if epinfo_txdata_valid_sync ='1' then  -- data is available from dma
	           data_fifo_fill_tx <= '1';
	        else -- buffer underrun error, PIE will corrupt the CRC
	        -- error will be reported at the end of the packet
	           packet_handling_state_nxt <= USB_PROT_BAD_OUT_SETUP_TX_CRC16_BYTE1;
	        end if;
	     end if;

	  when USB_PROT_OUT_SETUP_TX_CRC16_BYTE1 =>
	     if txready = '1' then
	        packet_handling_state_nxt <= USB_PROT_OUT_SETUP_TX_CRC16_BYTE2;
	     end if;

	  when USB_PROT_OUT_SETUP_TX_CRC16_BYTE2 =>
	     if txready = '1' then
	        if epinfo_eptype_sync = EP_INT and epinfo_token_sync = TOKEN_SSPLIT then
	        -- in SSPLIT int out, transfer is finished with the last transmitted byte (no handshake expected)
                   set_pie_response <= '1';
		   pie_response_int <= RESP_RCV_TX_ACK_HSK; -- means SSPLIT INT out packet is sent
		   --pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
		   clear_tx_pending_pkt <= '1';
	           packet_handling_state_nxt <= USB_PROT_ALL_WF_END_TX_PACKET;
	        elsif epinfo_eptype_sync /= EP_ISO  then
	           set_req_rx_pkt <= '1'; -- handshake is expected
	           clear_tx_pending_pkt <= '1';
	           packet_handling_state_nxt <= USB_PROT_ALL_WF_END_TX_PACKET;
	        elsif remaining_nbytes_r <= unsigned('0' & epinfo_maxpacket_sync) or
	         iso_transact_cnt_up_r = "10" or iso_transact_cnt_down_r = "00" then   -- it was the last transaction
	        -- we assume epinfo_nbytes is max 3072 bytes, check on iso_transact_cnt_up_r is not required.
	           clear_iso_out_pending <= '1';
		  -- in iso, transfer is finished with the last transmitted byte (no handshake expected)
	           set_pie_response <= '1';
                   pie_response_int <= RESP_RCV_TX_ACK_HSK; -- means ISO out packet is sent
	           --pie_endtransfer_int <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
	           clear_tx_pending_pkt <= '1';
	           packet_handling_state_nxt <= USB_PROT_ALL_WF_END_TX_PACKET;
	  	else  -- ISO HBW only: there is space for a new transaction
	  	   incr_iso_transact_cnt_up <= '1';
	  	   decr_iso_transact_cnt_down <= '1';
	  	   decr_remaining_nbytes <= '1';
	  	   packet_handling_state_nxt <= USB_PROT_WF_END_TX_SPECIAL_TOKEN; -- waiting time before sending TOKEN PID of the next transaction
	 	end if;
             end if;

	  when USB_PROT_BAD_OUT_SETUP_TX_CRC16_BYTE1 =>
	     if txready = '1' then
	 	packet_handling_state_nxt <= USB_PROT_BAD_OUT_SETUP_TX_CRC16_BYTE2;
	     end if;

	  when USB_PROT_BAD_OUT_SETUP_TX_CRC16_BYTE2 =>
	     if txready = '1' then
	  	packet_handling_state_nxt <= USB_PROT_ALL_WF_END_TX_PACKET;
	        if epinfo_eptype_sync /= EP_ISO then
	          -- no handshake is expected. Transfer is finished.
                    set_pie_response <= '1';
                    pie_response_int <= RESP_BUFF_ERR_OR_MDATA; -- data buffer underrun error
	            --pie_endtransfer_int    <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
	        elsif iso_transact_cnt_down_r  = "00" then -- last transaction
	 	    clear_iso_out_pending <= '1';
	 	    set_pie_response <= '1';
	 	    pie_response_int <= RESP_BUFF_ERR_OR_MDATA; -- data buffer underrun error
	            --pie_endtransfer_int    <= '1'; -- end of transaction: will be indicated to dma when FSM jumps to USB_PROT_IDLE
	 	else
	 	     decr_iso_transact_cnt_down  <= '1';
	 	end if;
	     end if;

--------------- HANDLING OF TEST PACKET--------------------------------------
          when USB_PROT_TX_TEST_PACKET => -- transmit test packet
            if txready = '1' then  -- data must be sent to the PHY
    	       if data_byte_cnt < TESTPACKET_SIZE then
	          data_byte_cnt_incr <= '1';
	       else -- end of test packet to transmit
                  clear_data_byte_cnt <= '1';
	          packet_handling_state_nxt <= USB_PROT_WF_END_TX_TEST_PACKET;
	       end if;
            end if;

         when USB_PROT_WF_END_TX_TEST_PACKET =>
	    if txready = '0' then  --  Wait Until the EOP
	       packet_handling_state_nxt <= USB_PROT_WF_TX_TEST_PACKET;
               timer_packet_handling_nxt <= PACKET_TURNAROUND_TIMEOUT_HS-1; -- must be less than 125 us, so PACKET_TURNAROUND_TIMEOUT is OK as interpacket delay
               reload_timer_packet_handling_nxt <= '1';
            end if;

         when others => -- USB_PROT_WF_TX_TEST_PACKET => -- test packet mode:  send the same packet repetively. Interpacket delay is still required.
            if bus_event_state_r /= BUS_EVENT_TEST_MODE then
               packet_handling_state_nxt <= USB_PROT_WF_IDLE;
            elsif timer_packet_handling_r = 0 then
               if data_byte_cnt < TESTPACKET_SIZE-1 then -- not really required, data_byte_cnt should be reset before jumping to this state
	          data_byte_cnt_incr <= '1';
	       end if;
               packet_handling_state_nxt <= USB_PROT_TX_TEST_PACKET;
            end if;
      end case;
   end if;
end process packet_handling_fsm_comb_proc;


packet_handling_fsm_clk_proc : process (pie_clk,reset_n)

begin
   if reset_n = '0' then
      packet_handling_state_r <= USB_PROT_WF_IDLE;

   elsif pie_clk'event and pie_clk='1' then
      packet_handling_state_r <= packet_handling_state_nxt;

      if usbreg_light_reset_sync = '1' or usbreg_reset_sync = '1' then
         packet_handling_state_r <= USB_PROT_WF_IDLE;
      end if;
   end if;

end process packet_handling_fsm_clk_proc;


packet_handling_to_phy_comb_proc : process(packet_handling_state_nxt,epinfo_sofnr_sync,epinfo_token_sync,epinfo_epnr_sync,
epinfo_devaddr_sync,epinfo_split_hubaddr_sync,epinfo_eptype_sync,epinfo_split_se_sync,epinfo_split_port_sync,
moved_to_tx,moved_to_tx_d,epinfo_toggle_sync,txready_r,txready,keepprevdata_r,data_fifo_previous_byte_r,data_fifo_r,crc16_result_r,
data_byte_cnt,iso_out_pending_r,epinfo_subpid_sync,remaining_nbytes_r,epinfo_maxpacket_sync,iso_transact_cnt_up_r,
epinfo_lpm_hird_sync,epinfo_lpm_linkstate_sync,epinfo_lpm_bremotewakeup_sync)

 variable v_crc5: std_logic_vector(4 downto 0);
 variable v_offset_in_bits : natural range 0 to USB_DATAWIDTH-8;-- if USB_DATAWIDTH=128 bits, max v_offset_in_bits= 120
 variable v_total_data_bytes_sent : unsigned (12 downto 0);

begin
       v_crc5:= (others => '0');
       txvalid_pkt_nxt <= '0';
       txdata_pkt_nxt <= (others => '0');

       v_total_data_bytes_sent := data_byte_cnt + (unsigned(epinfo_maxpacket_sync) * iso_transact_cnt_up_r);
        -- alignment of the bytes @ host_dma interface is calculated on the total amount of bytes already sent (v_total_data_bytes_sent)
       v_offset_in_bits:= 8*(to_integer(v_total_data_bytes_sent(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0)));
      case packet_handling_state_nxt is

         when USB_PROT_TX_SOF_PID =>
            txvalid_pkt_nxt <= '1';
	    txdata_pkt_nxt <= generate_pid_byte(PID_SOF);

         when USB_PROT_TX_SOF_BYTE2 =>
            txvalid_pkt_nxt <= '1';
	    txdata_pkt_nxt <= epinfo_sofnr_sync (7 downto 0);

         when USB_PROT_TX_SOF_BYTE3 =>
            txvalid_pkt_nxt <= '1';
            v_crc5 := not bit_reverse5(crc5_data11(bit_reverse11(epinfo_sofnr_sync)));
	    txdata_pkt_nxt <= v_crc5 & epinfo_sofnr_sync (10 downto 8);

	 when USB_PROT_TX_TOKEN_PKT_PID =>
            txvalid_pkt_nxt <= '1';
            case epinfo_token_sync is
	       when TOKEN_SETUP =>
	          txdata_pkt_nxt <= generate_pid_byte(PID_SETUP);

	       when TOKEN_OUT =>
	          txdata_pkt_nxt <= generate_pid_byte(PID_OUT);

	       when TOKEN_IN =>
	          txdata_pkt_nxt <= generate_pid_byte(PID_IN);

	       when TOKEN_PING =>
	          txdata_pkt_nxt <= generate_pid_byte(PID_PING);

	       when TOKEN_SSPLIT|TOKEN_CSPLIT|TOKEN_EXT =>
	          case epinfo_subpid_sync is
	            when SUB_TOKEN_SETUP =>
	               txdata_pkt_nxt <= generate_pid_byte(PID_SETUP);
	            when SUB_TOKEN_OUT =>
	               txdata_pkt_nxt <= generate_pid_byte(PID_OUT);
	            when SUB_TOKEN_IN =>
	               txdata_pkt_nxt <= generate_pid_byte(PID_IN);
	            when others => -- SUB_TOKEN_LPM
	               txdata_pkt_nxt <= generate_pid_byte(SUB_PID_LPM);
                  end case;

               when others =>  -- TOKEN_RESERVED -- not possible to arrive here


	    end case;

	 when USB_PROT_TX_TOKEN_PKT_BYTE2 =>
	    txvalid_pkt_nxt <= '1';
	    if epinfo_token_sync = TOKEN_EXT and epinfo_subpid_sync = SUB_TOKEN_LPM then
	       txdata_pkt_nxt <= epinfo_lpm_hird_sync & epinfo_lpm_linkstate_sync;
	    else
	       txdata_pkt_nxt <= epinfo_epnr_sync(0) & epinfo_devaddr_sync;
	    end if;

         when USB_PROT_TX_TOKEN_PKT_BYTE3 =>
	    txvalid_pkt_nxt <= '1';
	    if epinfo_token_sync = TOKEN_EXT and epinfo_subpid_sync = SUB_TOKEN_LPM then
	       v_crc5:= not bit_reverse5(crc5_data11(bit_reverse11("00" & epinfo_lpm_bremotewakeup_sync & epinfo_lpm_hird_sync &  epinfo_lpm_linkstate_sync )));
	       txdata_pkt_nxt <= v_crc5 & "00" & epinfo_lpm_bremotewakeup_sync;
	    else
	       v_crc5:= not bit_reverse5(crc5_data11(bit_reverse11(epinfo_epnr_sync & epinfo_devaddr_sync )));
	       txdata_pkt_nxt <= v_crc5 & epinfo_epnr_sync(3 downto 1);
	    end if;

         when USB_PROT_TX_SPECIAL_TOKEN_PID =>
            txvalid_pkt_nxt <= '1';
            if epinfo_token_sync = TOKEN_EXT then
               txdata_pkt_nxt <= generate_pid_byte(PID_EXT);
            else
	       txdata_pkt_nxt <= generate_pid_byte(PID_SPLIT);
	    end if;

         when USB_PROT_TX_SPECIAL_TOKEN_BYTE2 =>
	    txvalid_pkt_nxt <= '1';
	    if epinfo_token_sync = TOKEN_EXT then
	        txdata_pkt_nxt <= epinfo_epnr_sync(0) & epinfo_devaddr_sync;
	    else -- SPLIT transactions
	       txdata_pkt_nxt <= epinfo_token_sync(0) & epinfo_split_hubaddr_sync; -- SC field & Hub Addr
	    end if;

	 when USB_PROT_TX_SPECIAL_TOKEN_BYTE3 =>
	    txvalid_pkt_nxt <= '1';
	    if epinfo_token_sync = TOKEN_EXT then
	       v_crc5:= not bit_reverse5(crc5_data11(bit_reverse11(epinfo_epnr_sync & epinfo_devaddr_sync )));
	       txdata_pkt_nxt <= v_crc5 & epinfo_epnr_sync(3 downto 1);
	    else -- SPLIT transactions
	       txdata_pkt_nxt <= epinfo_split_se_sync(1) & epinfo_split_port_sync; -- S field & Port Field
	    end if;

	 when USB_PROT_TX_SPECIAL_TOKEN_BYTE4 =>  -- Only SPLIT transactions
	    txvalid_pkt_nxt <= '1';
	    v_crc5 := not bit_reverse5(crc5_data19(bit_reverse19(epinfo_eptype_sync & epinfo_split_se_sync(0) & epinfo_split_se_sync(1) & epinfo_split_port_sync & epinfo_token_sync(0) & epinfo_split_hubaddr_sync)));
	    txdata_pkt_nxt <= v_crc5 & epinfo_eptype_sync & epinfo_split_se_sync(0); -- CRC5 Field & ET field  & E field

         when USB_PROT_OUT_SETUP_TX_DATA_PID_1 =>
            if ((moved_to_tx = '0') and (moved_to_tx_d = '0')) then
               txvalid_pkt_nxt<= '1';
            end if;
            if iso_out_pending_r = '1' then -- Isochronous transaction only
               if remaining_nbytes_r <= unsigned('0' & epinfo_maxpacket_sync) then -- last transaction
                  case iso_transact_cnt_up_r  is
                     when "00" => -- 1 transaction
                        txdata_pkt_nxt <= generate_pid_byte(PID_DATA0);
                     when "01" => -- last transaction of 2
                        txdata_pkt_nxt <= generate_pid_byte(PID_DATA1);
                     when others => -- iso_transact_cnt_up_r = "10" -- last transaction of 3
                        txdata_pkt_nxt <= generate_pid_byte(PID_DATA2);
                  end case;
               else  -- this is not the last transaction
                     txdata_pkt_nxt <= generate_pid_byte(PID_MDATA);
               end if;
            elsif epinfo_toggle_sync ='0' then
	       txdata_pkt_nxt <= generate_pid_byte(PID_DATA0);
	    else
	       txdata_pkt_nxt <= generate_pid_byte(PID_DATA1);
	    end if;

         when USB_PROT_OUT_SETUP_TX_DATA_PID_2 =>
            txvalid_pkt_nxt<= '1';
	    if iso_out_pending_r = '1' then -- Isochronous transaction only
	       if remaining_nbytes_r <= unsigned('0' & epinfo_maxpacket_sync) then -- last transaction
	          case iso_transact_cnt_up_r  is
	             when "00" => -- 1 transaction
	                txdata_pkt_nxt <= generate_pid_byte(PID_DATA0);
	             when "01" => -- last transaction of 2
	                txdata_pkt_nxt <= generate_pid_byte(PID_DATA1);
	             when others => -- iso_transact_cnt_up_r = "10" -- last transaction of 3
	                txdata_pkt_nxt <= generate_pid_byte(PID_DATA2);
	             end case;
	       else  -- this is not the last transaction
	          txdata_pkt_nxt <= generate_pid_byte(PID_MDATA);
	       end if;
	    elsif epinfo_toggle_sync ='0' then
	       txdata_pkt_nxt <= generate_pid_byte(PID_DATA0);
	    else
	       txdata_pkt_nxt <= generate_pid_byte(PID_DATA1);
	    end if;

         when USB_PROT_OUT_SETUP_TX_DATA_PACKET =>
            txvalid_pkt_nxt<= '1';
	    if txready = '1' and txready_r ='0' and keepprevdata_r ='1' then
	       txdata_pkt_nxt <= data_fifo_previous_byte_r;
	    else
	       txdata_pkt_nxt <= data_fifo_r(v_offset_in_bits + 7 downto v_offset_in_bits);
            end if;

         when USB_PROT_IN_TX_ACK_HANDSHAKE =>
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= generate_pid_byte(PID_ACK);

         when USB_PROT_OUT_SETUP_TX_CRC16_BYTE1 =>
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= not bit_reverse8(crc16_result_r(15 downto 8));

         when USB_PROT_OUT_SETUP_TX_CRC16_BYTE2 =>
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= not bit_reverse8(crc16_result_r(7 downto 0));

         when USB_PROT_BAD_OUT_SETUP_TX_CRC16_BYTE1 =>
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= bit_reverse8(crc16_result_r(15 downto 8)); -- by not inverting CRC, we are sure a bad crc is sent

         when USB_PROT_BAD_OUT_SETUP_TX_CRC16_BYTE2 =>
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= bit_reverse8(crc16_result_r(7 downto 0)); -- by not inverting CRC, we are sure a bad crc is sent

         when USB_PROT_TX_TEST_PACKET => -- transmit test packet
            txvalid_pkt_nxt<= '1';
            txdata_pkt_nxt <= std_logic_vector(test_paket_decod (data_byte_cnt(5 downto 0)));

         when others =>
            txvalid_pkt_nxt <= '0';
            txdata_pkt_nxt <= (others => '0');

      end case;
end process packet_handling_to_phy_comb_proc;

-- packets and signals that need to be registered
packet_reg_clk_proc : process (pie_clk,reset_n)

variable v_offset_in_bits : natural range 0 to USB_DATAWIDTH-8;
variable v_total_data_bytes_rcv: unsigned (12 downto 0);
variable v_total_data_bytes_sent : unsigned (12 downto 0);


begin

   if reset_n = '0' then
      starttransfer_pending_r <= '0';
      req_rx_pkt_r  <= '0';
      tx_pending_pkt_r  <= '0';
      transfer_pending_r  <= '0';
      pie_response <= RESP_DEFAULT;
      moved_to_tx_d  <= '0';
      rxactive_r <= '0';
      crc16_result_r          <= (others => '1'); -- crc intermediate result must be registered
      data_fifo_r <= (others => '0');
      data_fifo_rx_r <= (others => '0');
      rxdata_valid_toggle_r <= '0';
      txdata_req_r <= '0';
      keepprevdata_r <= '0';
      data_fifo_previous_byte_r <= (others => '0');
      iso_in_pending_r <= '0';
      iso_out_pending_r <= '0';
      rx_nbytes_r <= (others => '0');
      rx_ok_r    <= '0';
      sop_det_r <= '0';
      txdata_fetched_toggle_r <= '0';
      ignore_data_r <= '0';

   elsif pie_clk'event and pie_clk='1' then
      if set_ignore_data = '1' then
         ignore_data_r <= '1';
      elsif clear_ignore_data = '1'then
         ignore_data_r <= '0';
      end if;
      if set_pie_response = '1' then
         pie_response <= pie_response_int;
      elsif epinfo_starttransfer_sync = '1' then
         pie_response <= RESP_DEFAULT; -- pie_response is clear to zero on the next pulse on epinfo_starttransfer
      end if;
      if clear_starttransfer = '1' then
         starttransfer_pending_r <= '0';
      elsif epinfo_starttransfer_sync = '1' then
         starttransfer_pending_r <= '1';
      end if;
      if set_req_rx_pkt = '1' then
         req_rx_pkt_r  <= '1';
      elsif clear_req_rx_pkt = '1' or  pie_endtransfer_int = '1' then
          req_rx_pkt_r  <= '0';
      end if;
      if set_tx_pending_pkt = '1'  then
         tx_pending_pkt_r  <= '1';
      elsif clear_tx_pending_pkt = '1' or  pie_endtransfer_int = '1' then
         tx_pending_pkt_r  <= '0';
      end if;
      if set_transfer_pending = '1' then
         transfer_pending_r  <= '1';
      --elsif clear_transfer_pending = '1' then
      elsif pie_endtransfer_int = '1' then
         transfer_pending_r  <= '0';
      end if;

      rxactive_r <= rxactive;
      rx_ok_r    <= rx_ok;
      moved_to_tx_d <= moved_to_tx;

      -- OUT Packet handling:
      -- if USB_DATAWIDTH=128 bits,MAX_DATA_BYTE_CNT_LSB = 15, only 4 lsb of data_byte_cnt must be = 0b1111
      -- txready set at '1' is taken into account via data_byte_cnt -- > avoid double pulses on txdata_req in HS when bitstuffing
      -- alignment of the bytes @ host_dma interface is calculated on the total amount of bytes already sent (v_total_data_bytes_sent)
      v_total_data_bytes_sent := data_byte_cnt + (unsigned(epinfo_maxpacket_sync) * iso_transact_cnt_up_r);
      if to_integer(v_total_data_bytes_sent(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0))= MAX_DATA_BYTE_CNT_LSB-1 and
         data_byte_cnt < (maxsize_currentpacket-2) and txready = '1' then
       -- DOC: txdata_req_r <= '1' if data_byte_cnt = 15, 31, 47,... for USB_DATAWIDTH_IN_BYTES=16
          txdata_req_r <= '1'; -- a full word of width "USB_DATAWIDTH" is requested by the PIE
      else
          txdata_req_r <= '0';
      end if;

      if crc16_eval_rx = '1' then
         crc16_result_r <= crc16_result_rx;
      elsif crc16_eval_tx = '1' then
         crc16_result_r <= crc16_result_tx;
      elsif packet_handling_state_r = USB_PROT_IDLE or packet_handling_state_r =  USB_PROT_ALL_WF_END_TX_PACKET
             or packet_handling_state_r = USB_PROT_ISO_WF_NXT_PKT then
         crc16_result_r <= (others => '1');
      end if;

      -- USB DATA FIFO : Same FIFO is used for both transmitting and receiving (assumption: never happened at the same time)
      -- width of USB_DATA_WIDTH
      --
      -- if USB_DATAWIDTH=128 bits,USB_DATAWIDTH_IN_BYTES = 16, max v_offset_in_bits= 120, only 4 lsb of data_byte_cnt are used
      v_total_data_bytes_rcv := data_byte_cnt + (unsigned(epinfo_maxpacket_sync) * iso_transact_cnt_up_r);
      v_offset_in_bits:= 8*(to_integer(v_total_data_bytes_rcv(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0)));
      if clear_data_fifo = '1' then
         data_fifo_r <= (others => '0');
      -- filling of the data fifo from USB (byte per byte)
      -- if data_byte_cnt = 19 and USB_DATAWIDTH_IN_BYTES=16, v_offset_in_bits returns 24
      -- if data_byte_cnt = 16 and USB_DATAWIDTH_IN_BYTES=16, v_offset_in_bits returns 0
      elsif data_fifo_fill_rx = '1' then
         data_fifo_r(v_offset_in_bits + 7 downto v_offset_in_bits) <= rxdata;
      -- filling of the data fifo from DMA
      elsif data_fifo_fill_tx = '1' then
         data_fifo_r <= epinfo_txdata_sync; -- the complete data_fifo_r is filled in one clock pulse (epinfo_txdata_valid is set)
        -- MSByte of datafifo_r is stored, used for corner case (txready =0 (bitstuffing)and txdatafetched =1)
         data_fifo_previous_byte_r <= data_fifo_r(USB_DATAWIDTH-1 downto USB_DATAWIDTH -8);
      end if;

      --rxdata_valid_toggle_r must be a toggle signal
      if rxdata_valid = '1' then
         rxdata_valid_toggle_r <= not rxdata_valid_toggle_r;
         data_fifo_rx_r <= data_fifo_r;
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
         rx_nbytes_r <= rx_nbytes;
      end if;

      if sop_start = '1' then
         sop_det_r <= '1';
      elsif clear_sop_det = '1' then
         sop_det_r <= '0';
      end if;


      --> txdata_fetched_toggle_r must be a toggle signal
      if maxsize_currentpacket >= USB_DATAWIDTH_IN_BYTES then
         if data_fifo_fill_tx = '1' and ((data_byte_cnt = 0) or (data_byte_cnt < maxsize_currentpacket-USB_DATAWIDTH_IN_BYTES-1) or
         (iso_out_pending_r = '1' and not (iso_transact_cnt_up_r = "10" or iso_transact_cnt_down_r = "00" ))) then -- ISO OUT HBW, not the last transaction
              txdata_fetched_toggle_r <= not txdata_fetched_toggle_r;
         end if;
      end if;


      if usbreg_light_reset_sync = '1' or usbreg_reset_sync = '1' then
         starttransfer_pending_r <= '0';
	 req_rx_pkt_r  <= '0';
	 tx_pending_pkt_r  <= '0';
	 transfer_pending_r  <= '0';
	 pie_response <= RESP_DEFAULT;
	 moved_to_tx_d  <= '0';
	 rxactive_r <= '0';
	 crc16_result_r          <= (others => '1'); -- crc intermediate result must be registered
	 data_fifo_r <= (others => '0');
	 data_fifo_rx_r <= (others => '0');
	 rxdata_valid_toggle_r <= '0';
	 txdata_req_r <= '0';
	 keepprevdata_r <= '0';
	 data_fifo_previous_byte_r <= (others => '0');
	 iso_in_pending_r <= '0';
	 iso_out_pending_r <= '0';
	 rx_nbytes_r <= (others => '0');
	 rx_ok_r    <= '0';
	 sop_det_r <= '0';
         txdata_fetched_toggle_r <= '0';
         ignore_data_r <= '0';
      end if;

   end if;
end process packet_reg_clk_proc;

-- decoding of packets
packet_decod_comb_proc : process(txready,port_speed_r,txready_r,linestate,ls_filt,packet_handling_state_r,pie_endtransfer_int,
epinfo_nbytes_sync,epinfo_maxpacket_sync,data_byte_cnt,rx_ok_r,crc16_result_r,
txdata_pkt_nxt,rxdata,rx_ok,txdata_fetched_toggle_r,packet_handling_state_nxt,maxsize_currentpacket,data_fifo_rx_r,
sop_det_r,rxdata_valid_toggle_r,rxactive_r,rxactive,iso_out_pending_r,iso_in_pending_r,
remaining_nbytes_r,iso_transact_cnt_up_r,rx_nbytes_r,set_last_rxdata_valid)

variable v_crc16_rx      : std_logic_vector(15 downto 0);
variable v_crc16_tx      : std_logic_vector(15 downto 0);
variable v_crc16_valid : std_logic;
--variable v_rx_ok : std_logic;
variable v_crc16_eval_rx : std_logic;
variable v_crc16_eval_tx : std_logic;
variable v_total_data_bytes_rcv: unsigned (12 downto 0);

begin

pie_endtransfer    <= pie_endtransfer_int; --does not need to be registered
pie_rxdatavalid    <= rxdata_valid_toggle_r;
pie_txdatafetched  <= txdata_fetched_toggle_r;
pie_rxdata         <= data_fifo_rx_r;
pie_rx_nbytes      <= rx_nbytes_r;

pid_nxt <= rxdata(3 downto 0);

sop_start <= '0';
--eop_rx <= '0';
eop_tx <= '0';


-- Start of Packet detection (@FS/LS, use of linestate is required for bus turnaround timings)
if port_speed_r = USB_FULL_SPEED then
   if packet_handling_state_r = USB_PROT_ALL_WF_RX_RESP then
      if linestate = LINESTATE_FS_K and ls_filt = LINESTATE_FS_J and sop_det_r = '0'then
         sop_start <= '1';
      end if;
   end if;
elsif port_speed_r = USB_LOW_SPEED then
   if packet_handling_state_r = USB_PROT_ALL_WF_RX_RESP then
      if linestate = LINESTATE_LS_K and ls_filt = LINESTATE_LS_J and sop_det_r = '0'then
         sop_start <= '1';
      end if;
   end if;
elsif packet_handling_state_r = USB_PROT_ALL_WF_RX_RESP and  sop_det_r = '0' then -- port_speed_r = USB_HIGH_SPEED
   sop_start <= rxactive and not rxactive_r; -- at HS, start of packet is detected via a rising edge of rxactive
end if;

-- End of Packet detection (@FS/LS, use of linestate is required for bus turnaround timings in case of a transmit)
-- Receive packet
--   if packet_handling_state_r = USB_PROT_IN_WF_END_RX_PACKET then
--      eop_rx <= not rxactive and rxactive_r;
--   end if;


-- Transmit packet
if packet_handling_state_r = USB_PROT_ALL_WF_END_TX_PACKET or packet_handling_state_r = USB_PROT_TX_SOF_WF_EOP or
             packet_handling_state_r =  USB_PROT_WF_END_TX_SPECIAL_TOKEN then
   if port_speed_r = USB_FULL_SPEED then
      if linestate = LINESTATE_FS_J and ls_filt = LINESTATE_SE0 then
         eop_tx <= '1';
      end if;
   elsif port_speed_r = USB_LOW_SPEED then
      if linestate = LINESTATE_LS_J and ls_filt = LINESTATE_SE0 then
            eop_tx <= '1';
      end if;
   else
      eop_tx <= not txready and txready_r ; -- at HS, end of a transmit packet is detected via a falling edge of txready
   end if;
end if;



 -- CRC16:
 if packet_handling_state_r = USB_PROT_IN_RCV_DATA_PACKET and rx_ok= '1' then
    v_crc16_eval_rx := '1';
 else
    v_crc16_eval_rx := '0';
 end if;

 if packet_handling_state_nxt = USB_PROT_OUT_SETUP_TX_DATA_PACKET and txready = '1' then  -- TX CRC16 must be done on the NXT state together with the NXT data to be transmitted
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

 -- IN Packet handling:
 -- if USB_DATAWIDTH=128 bits,USB_DATAWIDTH_IN_BYTES = 16, only 4 lsb of data_byte_cnt must be = 0b0000
 -- rxdata_valid pulse is generated each time v_total_data_bytes_rcv = 16 (0b10000), 32(0b100000), 48(0b110000),... for USB_DATAWIDTH_IN_BYTES=16
 -- it indicates to the dma handler that a full word of width "USB_DATAWIDTH" is available
 -- at the end of the received packet, if number of bytes of the data payload
 -- is not a nice multiple of USB_DATAWIDTH_IN_BYTES, an extra rxdata_valid pulse must be set to ask the dma_handler to fetch the
 -- remaining bytes from the data_fifo_rx_r. Since data_fifo_rx_r can also contain the CRC16 bytes
 -- the extra pulse is not sent at the end of the received packet if lsb's of v_total_data_bytes_rcv are equal
 -- to 0 or 1 (meaning all the bytes of the datapayload are already fetched)
 -- it is needed to take delayed version of rx_ok (=rx_ok_r) since v_total_data_bytes_rcv is only updated at the next clock cycle following rx_ok pulse

 v_total_data_bytes_rcv := data_byte_cnt + (unsigned(epinfo_maxpacket_sync) * iso_transact_cnt_up_r);

 if data_byte_cnt/=0  and
 (
 --(to_integer(data_byte_cnt(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0))=0 and rx_ok_r='1')
 (to_integer(v_total_data_bytes_rcv(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0))=0 and rx_ok_r='1')
 or
 (set_last_rxdata_valid = '1' and to_integer(unsigned(rx_nbytes_r(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0))) /= 0 and
 to_integer(v_total_data_bytes_rcv(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0)) /= 0 and -- data_fifo_r does not contain any new bytes of data payload
 to_integer(v_total_data_bytes_rcv(log2(USB_DATAWIDTH_IN_BYTES)-1 downto 0)) /= 1 )) then -- data_fifo_r does not contain any new bytes of data payload
 -- DOC: rxdata_valid <= '1' if data_byte_cnt = 16 (0b10000), 32(0b100000), 48(0b110000),... for USB_DATAWIDTH_IN_BYTES=16
    rxdata_valid <= '1'; -- a full word of width "USB_DATAWIDTH" is available
 else
    rxdata_valid <= '0';
 end if;


 -- signals used outside from this process
 crc16_eval_tx <= v_crc16_eval_tx;
 crc16_eval_rx <= v_crc16_eval_rx;

--if iso_in_pending_r = '1' and epinfo_maxpacket_sync(10) = '1' then -- iso HS or iso HBW
--   if epinfo_nbytes_sync(11 downto 10) = "11" and  epinfo_mult_sync = "11" then -- corner case: 3 transactions of 1024 bytes each, lsb (9 downto 0) are ignored
--      maxsize_currentpacket <= unsigned(epinfo_maxpacket_sync); -- 1024 bytes
--   elsif iso_transact_cnt_down_r = "00" and iso_transact_cnt_up_r > "00"  then -- HBW iso only: last transaction
--      maxsize_currentpacket <= '0' & unsigned(epinfo_nbytes_sync(9 downto 0)); -- max 1023 bytes
--   elsif unsigned(epinfo_nbytes_sync) < unsigned(epinfo_maxpacket_sync) then
--      maxsize_currentpacket <= unsigned(epinfo_nbytes_sync(10 downto 0)); -- max 1023 bytes
--   else -- first transactions (iso HBW) or single transaction of max 1024 bytes
--      maxsize_currentpacket <= unsigned(epinfo_maxpacket_sync); -- 1024 bytes
--   end if;
if iso_out_pending_r = '1' or iso_in_pending_r = '1' then
   if remaining_nbytes_r <= unsigned('0' & epinfo_maxpacket_sync) then
      maxsize_currentpacket <= unsigned(remaining_nbytes_r(10 downto 0));
   else
      maxsize_currentpacket <= unsigned(epinfo_maxpacket_sync);
   end if;
else -- non iso HBW ep
   if unsigned(epinfo_nbytes_sync) < unsigned('0' & epinfo_maxpacket_sync) then
      maxsize_currentpacket <= unsigned(epinfo_nbytes_sync(10 downto 0));
   else
      maxsize_currentpacket <= unsigned(epinfo_maxpacket_sync);
   end if;
end if;


-- maxsize_currentpacket <= packetsize_decod(epinfo_maxpacket_sync,epinfo_nbytes,iso_transact_cnt_down_r,iso_mdata_cnt_up, iso_in_pending_r,iso_out_pending_r);

end process packet_decod_comb_proc;



counter_packet_clk_proc : process (pie_clk, reset_n)

begin

if reset_n = '0' then

   data_byte_cnt <= (others => '0');
   remaining_nbytes_r <= (others => '0');
   iso_transact_cnt_down_r  <= (others => '0');
   iso_transact_cnt_up_r <= (others => '0');

elsif pie_clk'event and pie_clk ='1'then

   if clear_data_byte_cnt = '1' then
      data_byte_cnt <= (others => '0');
   elsif data_byte_cnt_incr = '1' then
      if to_integer(data_byte_cnt) < MAX_DATA_BYTE_CNT - 1 then
         data_byte_cnt <= data_byte_cnt +1;
      end if;
   end if;
    -- ISO only
   if load_remaining_nbytes = '1' then -- done at the start of the transfer
      remaining_nbytes_r <= unsigned(epinfo_nbytes_sync);
   elsif decr_remaining_nbytes = '1' then -- decr_remaining_nbytes is set to '1'only if remaining_nbytes_r > epinfo_maxpacket_sync
      remaining_nbytes_r <= remaining_nbytes_r - unsigned('0' & epinfo_maxpacket_sync);
   end if;
   -- ISO High bandwidth only
   -- this counter is used to check that number of token (IN or OUT) for the same iso HBW ep does not exceed the maximum of transactions per uframe
   -- the counter is loaded at the start of a transfer with the maximum of transactions per uframe
   if clear_iso_transact_cnt_down  = '1' then
      iso_transact_cnt_down_r  <= (others => '0');
   elsif load_iso_transact_cnt_down  = '1' then
      iso_transact_cnt_down_r  <= iso_transact_cnt_down_nxt;
   elsif decr_iso_transact_cnt_down  = '1' then
     if iso_transact_cnt_down_r  /= "00" then -- decr_iso_transact_cnt_down  = '1' and iso_transact_cnt_down_r  = "00" should never happend
        iso_transact_cnt_down_r  <= iso_transact_cnt_down_r  - 1;
     end if;
   end if;
   -- ISO High bandwidth only
   -- iso_transact_cnt_up (incremented each time a valid DATAx pid is received in USB_PROT_IN_RCV_DATA_PACKET state)
   -- this counter is used to check the number of DATA transaction already received for the incoming transfer (IN ep only)
   -- if counter = 0, next Data PID can only be DATA0 or DATA1 or DATA2
   -- if counter = 1, next Data PID can only be DATA0 or DATA1
   -- if counter = 2, next Data PID can only be DATA0
   if clear_iso_transact_cnt_up  = '1' then
      iso_transact_cnt_up_r  <= (others => '0');
   elsif incr_iso_transact_cnt_up  = '1' and iso_transact_cnt_up_r < "11" then -- a maximum of 3 transactions is allowed for a transfer
      iso_transact_cnt_up_r  <= iso_transact_cnt_up_r  + 1;
   end if;
   if usbreg_light_reset_sync = '1' or usbreg_reset_sync = '1' then
      data_byte_cnt <= (others => '0');
      remaining_nbytes_r <= (others => '0');
      iso_transact_cnt_down_r  <= (others => '0');
      iso_transact_cnt_up_r <= (others => '0');
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
   if usbreg_reset_sync = '1' then
      ls_dbc <= LINESTATE_INCST;
      linestate_r <= LINESTATE_INCST;
      linestate_dbc_cnt <= 0;
   end if;
end if;

end process linestate_debouncing_proc;



-- LineState Filtering (only occurs on an SE0) UTMI+ spec 2.1.2.2.
-- Supress unwanted SE0 states due to skew on the DP/DM signals
-- 2 CLK cycles for FS/HS Bus speed for 8-bit interface  (UTMI_16_BIT_INTERFACE is false)
-- 14 CLK cycles for LS Bus speed for 8-bit interface  (UTMI_16_BIT_INTERFACE is false)


linestate_filter_clk_proc: process (pie_clk, reset_n)

begin

if reset_n = '0' then

   ls_filt <= LINESTATE_SE0;
   se0_filt_cnt       <= 0;

elsif pie_clk'event and pie_clk ='1'then

   if linestate /= LINESTATE_SE0 then
      ls_filt <= linestate;
      se0_filt_cnt <= 0;
   elsif ((se0_filt_cnt = MAX_LS_SE0_FILT_CNT and xcvrselect_nxt(1) = '1') or
         (se0_filt_cnt = MAX_HSFS_SE0_FILT_CNT and xcvrselect_nxt(1) = '0')) then
      ls_filt <= linestate;   -- equivalent to linestate_filered <= SE0
   elsif se0_filt_cnt < MAX_LS_SE0_FILT_CNT then -- to prevent overflow when linestate = SE0 and switch from LS --> HS/FS
      se0_filt_cnt <= se0_filt_cnt + 1; -- linestate_filtered
   end if;
   if usbreg_reset_sync = '1' then
      ls_filt <= LINESTATE_SE0;
      se0_filt_cnt       <= 0;
   end if;
end if;

end process linestate_filter_clk_proc;




timer_bus_event_clk_proc : process (pie_clk, reset_n)

begin

if reset_n = '0' then

   timer_bus_event <= 0;
   timer_bus_event_timeout_r <= '0';

elsif pie_clk'event and pie_clk ='1'then

   timer_bus_event_timeout_r <= '0';

   if clear_timer_bus_event = '1' then
      timer_bus_event <= 0;
   elsif timer_bus_event =  MAX_BUS_EVENT_TIMER then  -- timeout occurs. unexpected behaviour
      timer_bus_event_timeout_r <= '1';
      timer_bus_event <= 0;
   elsif timer_bus_event_run = '1' then
      timer_bus_event <= timer_bus_event + 1;
   end if;
   if usbreg_reset_sync = '1' then
      timer_bus_event <= 0;
      timer_bus_event_timeout_r <= '0';
   end if;
end if;

end process timer_bus_event_clk_proc;



timer_bus_event_comb_proc : process (bus_event_state_r)

begin

   case bus_event_state_r is

      when BUS_EVENT_POWERED|BUS_EVENT_HS_WF_SUSPEND_L1|BUS_EVENT_HOST_DRIVE_RESUME_L1|BUS_EVENT_REFLECT_DEV_RESUME_L1|
           BUS_EVENT_HS_WF_SUSPEND_L2|
           BUS_EVENT_RESET_DRIVE_CHIRP_K|BUS_EVENT_RESET_DRIVE_CHIRP_J|BUS_EVENT_RESET_HS_WF_EOR|BUS_EVENT_FSLS_END_RESUME =>
         timer_bus_event_run <= '1';

      when others =>
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
   if usbreg_light_reset_sync = '1' or usbreg_reset_sync = '1' then
      timer_packet_handling_r <= 0;
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


-- FOR DEVICE ONLY:
--set_ulpi_req_low_power_mode <= '1' when suspendm_nxt = '0' and (ulpi_suspendm_r = '1' or -- enter into suspend ouside the ULPI reset cycle
--                                    set_ulpi_req_txcmd_fct_ctrl_wr_oprst='1'  or -- enter into suspend during ULPI reset cycle
--                                   (bus_event_state_r /= BUS_EVENT_INIT and usbreg_dev_connect = '0') or -- disconnect (No USB suspend)
--     (bus_event_state_r = BUS_EVENT_INIT and usbreg_dev_connect = '0' and set_ulpi_new_rxcmd ='1' and ulpi_vbusvalid_cmd = '0')or -- false interrupt after disconnect (No USB suspend)
--     (bus_event_state_r = BUS_EVENT_SUSPEND_L2 and set_ulpi_new_rxcmd ='1' and ulpi_linestate_cmd = LINESTATE_J and ulpi_vbusvalid_cmd = '1')) -- false interrupt after reconnect while host is still in suspend
--                                   else  '0';

-- FOR HOST:
set_ulpi_req_low_power_mode <= '1' when suspendm_nxt = '0' and (ulpi_suspendm_r = '1' or -- enter into suspend outside the ULPI reset cycle
                                    set_ulpi_req_txcmd_fct_ctrl_wr_oprst='1' or   -- enter into suspend during ULPI reset cycle
                                    (bus_event_state_nxt = BUS_EVENT_DISCON and bus_event_state_r /= BUS_EVENT_DISCON)) -- disconnect (no USB suspend)
                                   else  '0';


clear_ulpi_req_low_power_mode <= '1' when (ulpi_dir_int = '0' and ulpi_dir_r = '1') and
                                       (usbreg_portresume_sync='1' or -- from register interface
                                       ulpi_pwrctrl_wakeup = '1' or -- from suspend control module at toplevel structure
                                       ulpi_suspendm_r= '1' or
                                       ulpi_oper_state_r = ULPI_OPER_EXIT_LOW_POWER
                                       ) else
                             '0';
-- Extended Register access (Vendor Specific)
-- -- new request during pending transaction will be ignored
set_ulpi_req_xreg_wr <= '1' when usbreg_phy_start_sync = '1' and ulpi_xreg_write = '1' and ulpi_req_xreg_wr_r = '0' else '0';
set_ulpi_req_xreg_rd <= '1' when usbreg_phy_start_sync = '1' and ulpi_xreg_write = '0' and ulpi_req_xreg_rd_r = '0' else '0';




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
                               set_ulpi_req_xreg_rd,ulpi_req_xreg_rd_r,set_ulpi_req_txcmd_fct_ctrl_wr_oprst)
                               --set_ulpi_req_txcmd_otg_ctrl_wr_oprst,ulpi_req_txcmd_otg_ctrl_wr_r)

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

--elsif set_ulpi_req_txcmd_otg_ctrl_wr_oprst = '1' or ulpi_req_txcmd_otg_ctrl_wr_r = '1' then -- OTG Control Register -- clear
--   ulpi_arb_reg_nxt <= ULPI_ARB_OTGCTRL_REG_WR;
--   ulpi_reg_access_req <= '1';

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
     ulpi_tx_data_wr  <=  '0' & '1' & '0' & opmode_nxt & termselect_nxt & xcvrselect_nxt; -- xcvrselect is now 2 bits

--  when ULPI_ARB_OTGCTRL_REG_WR =>  -- OTG Control Register -- clear
--     ulpi_reg_access_wr_i <= '1';
--     ulpi_ext_reg <= '0';
--     ulpi_reg_tx_addr <= ULPI_ADDR_OTGCTRL_REG_CLR;
--     ulpi_tx_data_wr  <=  "00000110"; -- DEVICE: clear dppulldown/dmpulldown

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

  when others =>
     -- default values
     ulpi_reg_access_wr_i <= '0';
     ulpi_ext_reg <= '0';
     ulpi_reg_tx_addr <= (others => '0');
     ulpi_tx_data_wr  <= (others => '0');

   end case;
end process ulpi_reg_access_comb_proc;

set_ulpi_rxactive_line <= ulpi_dir_r  and ulpi_nxt_r and ulpi_turnaround; -- USB receive while dir was previously low
set_ulpi_new_rxcmd <= '1' when ulpi_turnaround = '0' and ulpi_nxt_r = '0' and  -- only last rxcmd is taken into account
                          (ulpi_oper_state_r = ULPI_OPER_CMD_RCV or ulpi_oper_state_r =  ULPI_OPER_RESET_CMD_RCV) and
                          ulpi_async_mode_r = '0'
                          else '0';


--decoding from rxcommand byte:
ulpi_rxactive_cmd <= '1' when ulpi_rxdata_r(5 downto 4)= "01" or ulpi_rxdata_r(5 downto 4)= "11" else '0';
ulpi_rxerror_cmd <= '1' when ulpi_rxdata_r(5 downto 4)= "11"  else '0';
ulpi_linestate_cmd  <= ulpi_rxdata_r(1 downto 0);
ulpi_vbusvalid_cmd  <= '1' when ulpi_rxdata_r(3) = '1' else '0';
ulpi_hostdisconnect_cmd <= '1' when ulpi_rxdata_r(5 downto 4)= "10"  else '0';


set_ulpi_tx_nopid_req <= '1' when (bus_event_state_r = BUS_EVENT_RESET_WF_END_CHIRP_K and      -- NOPID TX CMD
                          bus_event_state_nxt = BUS_EVENT_RESET_DRIVE_CHIRP_K) -- HS detection handshake: -- Host will drive chirp K/ChirpJ
                          or (bus_event_state_r = BUS_EVENT_SUSPEND_L2 and      -- NOPID TX CMD
                          bus_event_state_nxt = BUS_EVENT_DRIVE_RESUME_L2) -- Remote Wake-up: -- Host will drive K to signal Resume
                          or (bus_event_state_r = BUS_EVENT_SUSPEND_L1 and      -- NOPID TX CMD
                          (bus_event_state_nxt = BUS_EVENT_HOST_DRIVE_RESUME_L1 or bus_event_state_nxt = BUS_EVENT_REFLECT_DEV_RESUME_L1)) -- Remote Wake-up: -- Host will drive K to signal Resume
                          else '0';

clear_ulpi_tx_nopid_req <= '1' when (bus_event_state_r = BUS_EVENT_RESET_DRIVE_CHIRP_J and      -- NOPID TX CMD
                          bus_event_state_nxt = BUS_EVENT_RESET_HS_WF_EOR) -- HS detection handshake: -- Host will stop driving chirp K/ChirpJ
                          or (bus_event_state_r = BUS_EVENT_DRIVE_RESUME_L2 and      -- NOPID TX CMD
                          (bus_event_state_nxt = BUS_EVENT_FSLS_END_RESUME or bus_event_state_nxt = BUS_EVENT_HS_END_RESUME))  -- Resume: -- Host will stop driving K
                          or ((bus_event_state_r = BUS_EVENT_HOST_DRIVE_RESUME_L1 or bus_event_state_r = BUS_EVENT_REFLECT_DEV_RESUME_L1) and      -- NOPID TX CMD
                          (bus_event_state_nxt = BUS_EVENT_FSLS_END_RESUME or bus_event_state_nxt = BUS_EVENT_HS_END_RESUME))  -- Resume: -- Host will stop driving K
                          --or (bus_event_state_r = BUS_EVENT_LPM_SW_WAKEUP_1 and      -- NOPID TX CMD --BUS_EVENT_SW_WAKEUP_2 = BUS_EVENT_LPM_SW_WAKEUP_2
                          --bus_event_state_nxt = BUS_EVENT_SW_WAKEUP_2)  -- Remote Wake-up:: -- peripheral will stop driving K
                          else '0';



set_ulpi_pwrst_det <= ulpi_pwrst_r and not ulpi_pwrst_r_s; -- end of power on reset is detected

ulpi_packet_idle <= '1' when packet_handling_state_r = USB_PROT_IDLE or (packet_handling_state_r = USB_PROT_WF_IDLE and ulpi_rxactive_r ='0') or
                             packet_handling_state_r = USB_PROT_WF_TX_TEST_PACKET else
                    '0';

-- main FSM
ulpi_oper_fsm_comb_proc: process (ulpi_oper_state_r,ulpi_dir_r,ulpi_dir_int,ulpi_nxt_r,ulpi_reg_access_req,
set_ulpi_tx_nopid_req,ulpi_reg_access_wr_i,txvalid_nxt,ulpi_turnaround,ulpi_pwrst_det_r,ulpi_ext_reg,
ulpi_tx_nopid_req_r,ulpi_arb_reg_nxt,clear_ulpi_tx_nopid_req,usbreg_phy_mode_sync,ulpi_dir_r_s,ulpi_nxt_int,ulpi_packet_idle,
suspendm_nxt,ulpi_pwrctrl_wakeup,ulpi_req_low_power_mode_r,ulpi_arb_reg_pending_r,ulpi_arb_reg_r,
ulpi_req_txcmd_fct_ctrl_susp_r )

begin
-- default values
ulpi_oper_state_nxt <= ulpi_oper_state_r;
--ulpi_reg_end_cycle_nxt <= '0';
set_ulpi_arb_reg_pending <= '0';
clear_ulpi_req_txcmd <= '0';
ulpi_stp_nxt <= '0';
clear_ulpi_pwrst_det <= '0';
set_ulpi_req_txcmd_fct_ctrl_reset <= '0';
set_ulpi_req_txcmd_int_stat <= '0';
set_ulpi_req_txcmd_dbg <= '0';
set_ulpi_req_txcmd_fct_ctrl_wr_oprst <= '0';
--set_ulpi_req_txcmd_otg_ctrl_wr_oprst <= '0';
set_ulpi_async_mode <= '0';
clear_ulpi_async_mode <= '0';
set_ulpi_phy_endtoggle <= '0';
set_ulpi_reg_rdata_vld <= '0';
if usbreg_phy_mode_sync = '0'then -- UTMI Interface
   ulpi_oper_state_nxt <= ULPI_OPER_RESET_PWR_INIT;
  -- ulpi_reg_end_cycle_nxt <= '0';
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
     -- ulpi_reg_end_cycle_nxt <= '1';
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
      --   set_ulpi_req_txcmd_otg_ctrl_wr_oprst <= '1'; -- request update of dppulldown/dmpulldown (only for DEVICE)
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
 --        ulpi_reg_end_cycle_nxt <= '1';
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
       --elsif packet_handling_state_r = USB_PROT_ALL_WF_END_TX_PACKET then
      elsif txvalid_nxt = '0' then -- end of transmitting packet -- packet is only one byte (Handshake PID)
        ulpi_oper_state_nxt <= ULPI_OPER_PKT_TX_END;
        ulpi_stp_nxt <= '1';
      elsif ulpi_nxt_int = '1' then
        ulpi_oper_state_nxt <= ULPI_OPER_PID_TX_DATA;
      end if;

   when ULPI_OPER_PID_TX_DATA => -- pie transmits USB packet that contains PID to the PHY
      if ulpi_dir_r = '1' then
         ulpi_oper_state_nxt <=  ULPI_OPER_PKT_RCV;
      --elsif packet_handling_state_r = USB_PROT_ALL_WF_END_TX_PACKET then
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
   when others => -- ULPI_OPER_EXIT_LOW_POWER =>
      if ulpi_dir_r = '0' and ulpi_dir_r_s = '1' then   -- falling edge of ulpi_dir_r
      --(The Link de-asserts stp in the cycle following the deassertion of dir)
      -- stp can remain asserted for more than 1 clock cycle if the clock is not made available(due too PLL locking)
      -- should not be an issue for the phy
         clear_ulpi_async_mode <= '1';
         ulpi_oper_state_nxt <= ULPI_OPER_IDLE;
      end if;

   end case;
end if;
end process ulpi_oper_fsm_comb_proc;

ulpi_oper_fsm_clk_proc : process (pie_clk, reset_n)

begin
   if reset_n = '0' then
      ulpi_oper_state_r <= ULPI_OPER_RESET_PWR_INIT;

   elsif pie_clk'event and pie_clk='1' then
      ulpi_oper_state_r <= ulpi_oper_state_nxt;
      if usbreg_reset_sync = '1' then
         ulpi_oper_state_r <= ULPI_OPER_RESET_PWR_INIT;
      end if;
   end if;
end process ulpi_oper_fsm_clk_proc;

-- main FSM
ulpi_oper_decod_nxt_comb_proc: process (ulpi_oper_state_nxt,ulpi_reg_tx_addr,ulpi_tx_data_wr,txdata_nxt               )

begin
-- default values
--   ulpi_txvalid_nxt_i <= '0';
   ulpi_txdata_nxt_i <= (others => '0');
   ulpi_stp_async <= '0';
   case ulpi_oper_state_nxt is
   when ULPI_OPER_RESET_PWR_INIT =>

   when ULPI_OPER_IDLE =>
-- An RX CMD has lower priority than USB receive or transmit data, but has higher priority than Register Read and Write commands.
      ulpi_txdata_nxt_i <= (others => '0');

   when ULPI_OPER_IREG_WR_TX_CMD|ULPI_OPER_RESET_IREG_WR_TX_CMD =>
      ulpi_txdata_nxt_i <=  "10"& ulpi_reg_tx_addr(5 downto 0);
 --     ulpi_txvalid_nxt_i <= '1';

   when ULPI_OPER_XREG_WR_TX_CMD =>
      ulpi_txdata_nxt_i <=  "10101111"; -- keeps register write command
--      ulpi_txvalid_nxt_i <= '1';

   when ULPI_OPER_XREG_WR_TX_ADD =>
      ulpi_txdata_nxt_i <= ulpi_reg_tx_addr;
  --    ulpi_txvalid_nxt_i <= '1';

   when ULPI_OPER_REG_WR_TX_DATA|ULPI_OPER_RESET_REG_WR_TX_DATA =>
      ulpi_txdata_nxt_i <= ulpi_tx_data_wr;
  --    ulpi_txvalid_nxt_i <= '1';

   when ULPI_OPER_IREG_RD_TX_CMD =>
      ulpi_txdata_nxt_i <= "11"& ulpi_reg_tx_addr(5 downto 0);
 --     ulpi_txvalid_nxt_i <= '1';

   when ULPI_OPER_XREG_RD_TX_CMD =>
      ulpi_txdata_nxt_i <= "11101111";
--      ulpi_txvalid_nxt_i <= '1';

   when ULPI_OPER_XREG_RD_TX_ADD =>
      ulpi_txdata_nxt_i <= ulpi_reg_tx_addr;
 --     ulpi_txvalid_nxt_i <= '1';

   when ULPI_OPER_REG_RD_TX_DATA => -- no data to transmit
      ulpi_txdata_nxt_i <= (others => '0') ;

   when ULPI_OPER_REG_END_CYCLE =>

   when ULPI_OPER_PKT_RCV =>

   when ULPI_OPER_CMD_RCV|ULPI_OPER_RESET_CMD_RCV =>

   when ULPI_OPER_NOPID_TX_CMD =>
      ulpi_txdata_nxt_i <= "01000000";

   when ULPI_OPER_NOPID_TX_DATA =>
      ulpi_txdata_nxt_i <= txdata_nxt; -- from bus event fsm
 --     ulpi_txvalid_nxt_i <= '1';

   when ULPI_OPER_PID_TX_CMD=>
      ulpi_txdata_nxt_i <= "0100" & txdata_nxt(3 downto 0); -- txdata_nxt(3 downto 0) = USB PID
 --     ulpi_txvalid_nxt_i <= '1';

   when ULPI_OPER_PID_TX_DATA =>
      ulpi_txdata_nxt_i <= txdata_nxt; -- from bus event fsm
--      ulpi_txvalid_nxt_i <= '1';

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
      ulpi_hostdisconnect_r <= '0';
      ulpi_linestate_r <= "00";
      ulpi_req_txcmd_fct_ctrl_reset_r <= '0';
      ulpi_req_txcmd_fct_ctrl_wr_r <= '0';
      ulpi_req_txcmd_fct_ctrl_susp_r <= '0';
--      ulpi_req_txcmd_otg_ctrl_wr_r <= '0';
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
     -- ulpi_low_power_mode_phy_r <= '0';
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
      if set_ulpi_new_rxcmd = '1' then  -- update of registers via a RXCMD byte
         ulpi_rxactive_r <= ulpi_rxactive_cmd;
         ulpi_rxerror_r <= ulpi_rxerror_cmd;
         ulpi_linestate_r <= ulpi_linestate_cmd;
         ulpi_vbusvalid_r <= ulpi_vbusvalid_cmd;
         ulpi_hostdisconnect_r <= ulpi_hostdisconnect_cmd;

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
--      if set_ulpi_req_txcmd_otg_ctrl_wr_oprst = '1' then
--         ulpi_req_txcmd_otg_ctrl_wr_r <= '1';
--      elsif clear_ulpi_req_txcmd = '1' and ulpi_arb_reg_r = ULPI_ARB_OTGCTRL_REG_WR then
--         ulpi_req_txcmd_otg_ctrl_wr_r <= '0';
--      end if;
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
         ulpi_xreg_rdata_r <= ulpi_rxdata_r; -- read data needs to be hold until next usbreg_phy_start_sync pulse. ulpi_rxdata_r can have changed in the meantime
      end if;

      if usbreg_reset_sync = '1' then
         ulpi_rxactive_r <= '0';
         ulpi_rxerror_r <= '0';
         ulpi_hostdisconnect_r <= '0';
         ulpi_linestate_r <= "00";
         ulpi_req_txcmd_fct_ctrl_reset_r <= '0';
         ulpi_req_txcmd_fct_ctrl_wr_r <= '0';
         ulpi_req_txcmd_fct_ctrl_susp_r <= '0';
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


  usb_host_pie_fpga(63 downto 46) <= (others => '0');


    usb_host_pie_fpga(0) <= usbreg_reset_sync;
      usb_host_pie_fpga(1) <= reset_n;
      usb_host_pie_fpga(3 downto 2) <= ls_filt;
      usb_host_pie_fpga(5 downto 4) <= linestate;
      usb_host_pie_fpga(7 downto 6) <= ls_dbc;
      usb_host_pie_fpga(9 downto 8) <= linestate_r;


  usb_host_pie_fpga(14 downto 10) <= "00000" when bus_event_state_r = BUS_EVENT_INIT else --0x00
				     "00001" when bus_event_state_r = BUS_EVENT_POWERED else --0x01
                                     "00010" when bus_event_state_r = BUS_EVENT_DISCON else --0x02
                                     "00011" when bus_event_state_r = BUS_EVENT_DEV_ATTACH else --0x03
                                     "00100" when bus_event_state_r = BUS_EVENT_RESET_WF_START_CHIRP_K else --0x04
                                     "00101" when bus_event_state_r = BUS_EVENT_RESET_WF_END_CHIRP_K else --0x05
                                     "00110" when bus_event_state_r = BUS_EVENT_RESET_DRIVE_CHIRP_K else --0x06
                                     "00111" when bus_event_state_r = BUS_EVENT_RESET_DRIVE_CHIRP_J else --0x07
                                     "01000" when bus_event_state_r = BUS_EVENT_RESET_LS_WF_EOR else --0x08
                                     "01001" when bus_event_state_r = BUS_EVENT_RESET_FS_WF_EOR else --0x09
                                     "01010" when bus_event_state_r = BUS_EVENT_RESET_HS_WF_EOR else --0x0A
                                     "01011" when bus_event_state_r = BUS_EVENT_LS_ENABLED else --0x0B
                                     "01100" when bus_event_state_r = BUS_EVENT_FS_ENABLED else --0x0C
                                     "01101" when bus_event_state_r = BUS_EVENT_HS_ENABLED else --0x0D
                                     "01110" when bus_event_state_r = BUS_EVENT_WF_LS_FS_ENABLED else --0x0E
                                     "01111" when bus_event_state_r = BUS_EVENT_LS_FS_ENABLED else --0x0F
                                     "10000" when bus_event_state_r = BUS_EVENT_HS_WF_SUSPEND_L1 else --0x10
				     "10001" when bus_event_state_r = BUS_EVENT_SUSPEND_L1 else --0x11
                                     "10010" when bus_event_state_r = BUS_EVENT_HOST_DRIVE_RESUME_L1 else --0x12
                                     "10011" when bus_event_state_r = BUS_EVENT_REFLECT_DEV_RESUME_L1 else --0x13
                                     "10100" when bus_event_state_r = BUS_EVENT_HS_WF_SUSPEND_L2 else --0x14
                                     "10101" when bus_event_state_r = BUS_EVENT_SUSPEND_L2 else --0x15
                                     "10110" when bus_event_state_r = BUS_EVENT_DRIVE_RESUME_L2 else --0x16
                                     "10111" when bus_event_state_r = BUS_EVENT_FSLS_END_RESUME else --0x17
                                     "11000" when bus_event_state_r = BUS_EVENT_HS_END_RESUME else --0x18
                                     "11001" when bus_event_state_r = BUS_EVENT_TEST_MODE else --0x19
                                     "11111";

  usb_host_pie_fpga(20 downto 15) <= "000000" when packet_handling_state_r = USB_PROT_WF_IDLE else --0x00
                                     "000001" when packet_handling_state_r = USB_PROT_IDLE else --0x01
                                     "000010" when packet_handling_state_r = USB_PROT_TX_SOF_PID else --0x02
                                     "000011" when packet_handling_state_r = USB_PROT_TX_SOF_BYTE2 else --0x03
                                     "000100" when packet_handling_state_r = USB_PROT_TX_SOF_BYTE3 else --0x04
                                     "000101" when packet_handling_state_r = USB_PROT_TX_SOF_WF_EOP else --0x05
                                     "000110" when packet_handling_state_r = USB_PROT_ALL_WF_END_TX_PACKET else --0x06
                                     "000111" when packet_handling_state_r = USB_PROT_WF_STARTSOF else --0x07
                                     "001000" when packet_handling_state_r = USB_PROT_WF_TX_TOKEN_PKT_PID else --0x08
                                     "001001" when packet_handling_state_r = USB_PROT_TX_TOKEN_PKT_PID else --0x09
                                     "001010" when packet_handling_state_r = USB_PROT_TX_TOKEN_PKT_BYTE2 else --0x0A
                                     "001011" when packet_handling_state_r = USB_PROT_TX_TOKEN_PKT_BYTE3 else --0x0B
                                     "001100" when packet_handling_state_r = USB_PROT_TX_SPECIAL_TOKEN_PID else --0x0C
                                     "001101" when packet_handling_state_r = USB_PROT_TX_SPECIAL_TOKEN_BYTE2 else --0x0D
                                     "001110" when packet_handling_state_r = USB_PROT_TX_SPECIAL_TOKEN_BYTE3 else --0x0E
                                     "001111" when packet_handling_state_r = USB_PROT_TX_SPECIAL_TOKEN_BYTE4 else --0x0F
                                     "010000" when packet_handling_state_r = USB_PROT_WF_END_TX_SPECIAL_TOKEN else --0x10
                                     "010001" when packet_handling_state_r = USB_PROT_OUT_SETUP_WF_TX_DATA_PID else --0x11
                                     "010010" when packet_handling_state_r = USB_PROT_OUT_SETUP_TX_DATA_PID_1 else --0x12
                                     "010011" when packet_handling_state_r = USB_PROT_OUT_SETUP_TX_DATA_PID_2 else --0x13
                                     "010100" when packet_handling_state_r = USB_PROT_OUT_SETUP_TX_DATA_PACKET else --0x14
                                     "010101" when packet_handling_state_r = USB_PROT_OUT_SETUP_TX_CRC16_BYTE1 else --0x15
                                     "010110" when packet_handling_state_r = USB_PROT_OUT_SETUP_TX_CRC16_BYTE2 else --0x16
                                     "010111" when packet_handling_state_r = USB_PROT_BAD_OUT_SETUP_TX_CRC16_BYTE1 else --0x17
                                     "011000" when packet_handling_state_r = USB_PROT_BAD_OUT_SETUP_TX_CRC16_BYTE2 else --0x18
                                     "011001" when packet_handling_state_r = USB_PROT_ALL_WF_RX_RESP else --0x19
                                     "011010" when packet_handling_state_r = USB_PROT_IN_RCV_DATA_PACKET else --0x1A
                                     "011011" when packet_handling_state_r = USB_PROT_IN_WF_TX_ACK_HANDSHAKE else --0x1B
                                     "011100" when packet_handling_state_r = USB_PROT_IN_TX_ACK_HANDSHAKE else --0x1C
                                     "011101" when packet_handling_state_r = USB_PROT_ISO_WF_NXT_PKT else --0x1D
                                     "011110" when packet_handling_state_r = USB_PROT_TX_TEST_PACKET else --0x1E
                                     "011111" when packet_handling_state_r = USB_PROT_WF_END_TX_TEST_PACKET else --0x1F
                                     "100000" when packet_handling_state_r = USB_PROT_WF_TX_TEST_PACKET else --0x20
                                     "100001" when packet_handling_state_r = USB_PROT_WF_END_TRANSFER_DELAY else --0x21
                                     "111111";


usb_host_pie_fpga(22 downto 21) <= "00" when port_speed_r = USB_LOW_SPEED else
                                     "01" when port_speed_r = USB_FULL_SPEED else
                                     "10" when port_speed_r = USB_HIGH_SPEED else
                                     "11";

  usb_host_pie_fpga(23) <= pie_response_int(0);
  usb_host_pie_fpga(24) <= pie_response_int(1);
  usb_host_pie_fpga(25) <= pie_response_int(2);
  usb_host_pie_fpga(26) <= set_pie_response;

  --usb_host_pie_fpga(25) <= eop_tx;
  --usb_host_pie_fpga(26) <= req_rx_pkt_r;
  usb_host_pie_fpga(27) <= '1' when timer_packet_handling_r = 0 else '0';
  usb_host_pie_fpga(28) <= sop_det_r;
  usb_host_pie_fpga(29) <= sop_start;
  usb_host_pie_fpga(30) <= txvalid_nxt;
  usb_host_pie_fpga(31) <= rxactive_r;
  usb_host_pie_fpga(32) <= rx_ok;
  usb_host_pie_fpga(33) <= req_rx_pkt_r;
  usb_host_pie_fpga(34) <= eop_tx;
  usb_host_pie_fpga(37 downto 35) <= epinfo_token_sync(2 downto 0);
  usb_host_pie_fpga(38) <= iso_in_pending_r;
  usb_host_pie_fpga(39) <= data_fifo_fill_rx;
  usb_host_pie_fpga(40) <= data_fifo_fill_tx;



  usb_host_pie_fpga(45 downto 41) <= "00000" when ulpi_oper_state_r = ULPI_OPER_RESET_PWR_INIT else --0x00
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
                                     "11001" when ulpi_oper_state_r = ULPI_OPER_EXIT_LOW_POWER else --0x19
				     "11111";




end RTL;
