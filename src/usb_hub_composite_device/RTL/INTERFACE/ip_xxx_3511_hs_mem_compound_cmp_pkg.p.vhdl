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

USE work.usb_general_subcmp_pkg.all;

package ip_xxx_3511_hs_mem_compound_cmp_pkg is
component ip_xxx_3511_hs_mem_compound
    generic(
        C_HUB_FIFO_SIZE                : integer                       := 172;
        C_DEV0_RAM_ADDRWIDTH           : integer                       := 15;
        C_DEV1_RAM_ADDRWIDTH           : integer                       := 15;
        C_DEV0_NBPHYSEP                : integer                       := 14;
        C_DEV1_NBPHYSEP                : integer                       := 14;
        C_EPUB                         : integer                       := 32;
        C_DAUB                         : integer                       := 32;
        C_DALB                         : integer                       := 17;
        C_EPFIFO_PAGE                  : std_logic_vector(31 downto 0) := X"00080000";
        C_DATAFIFO_PAGE                : std_logic_vector(31 downto 0) := X"00080000";
        C_DEV0_SINGLE_BUFFER_SUPPORTED : boolean                       := TRUE;
        C_DEV0_DOUBLE_BUFFER_SUPPORTED : boolean                       := TRUE;
        C_DEV0_TOGGLE_REG_READABLE     : boolean                       := TRUE;
        C_DEV1_SINGLE_BUFFER_SUPPORTED : boolean                       := TRUE;
        C_DEV1_DOUBLE_BUFFER_SUPPORTED : boolean                       := TRUE;
        C_DEV1_TOGGLE_REG_READABLE     : boolean                       := TRUE;
        C_PLL_ENABLE                   : boolean                       := FALSE;
        C_PLL_DIVIDER                  : std_logic_vector(6 downto 0)  := "0010100";
        C_ULPI_SUPPORT                 : boolean                       := TRUE;
        C_UTMI_SUPPORT                 : boolean                       := TRUE;
        C_EXTEND_TX_DELAY              : boolean                       := TRUE;
        G_SIM_CHIRP_TIMERS             : boolean                       := FALSE
    );
    port(
        hclk                    : in  std_logic;
        hresetn                 : in  std_logic;
        ahbs_resetn             : in  std_logic;
        hub_ahbs_haddr          : in  std_logic_vector(log2(C_HUB_FIFO_SIZE)-1+2 downto 2);
        hub_ahbs_htrans         : in  std_logic_vector(1 downto 0);
        hub_ahbs_hwrite         : in  std_logic;
        hub_ahbs_hwdata         : in  std_logic_vector(31 downto 0);
        hub_ahbs_hsel           : in  std_logic;
        hub_ahbs_hreadyin       : in  std_logic;
        hub_ahbs_hrdata         : out std_logic_vector(31 downto 0);
        hub_ahbs_hreadyout      : out std_logic;
        hub_ahbs_hresp          : out std_logic_vector(1 downto 0);
        dev0_ahbs_haddr         : in  std_logic_vector(5 downto 2);
        dev0_ahbs_htrans        : in  std_logic_vector(1 downto 0);
        dev0_ahbs_hwrite        : in  std_logic;
        dev0_ahbs_hwdata        : in  std_logic_vector(31 downto 0);
        dev0_ahbs_hsel          : in  std_logic;
        dev0_ahbs_hreadyin      : in  std_logic;
        dev0_ahbs_hrdata        : out std_logic_vector(31 downto 0);
        dev0_ahbs_hreadyout     : out std_logic;
        dev0_ahbs_hresp         : out std_logic_vector(1 downto 0);
        dev0_ahbs_dma_haddr     : in  std_logic_vector(C_DEV0_RAM_ADDRWIDTH-1+3 downto 0);
        dev0_ahbs_dma_htrans    : in  std_logic_vector(1 downto 0);
        dev0_ahbs_dma_hwrite    : in  std_logic;
        dev0_ahbs_dma_hwdata    : in  std_logic_vector(31 downto 0);
        dev0_ahbs_dma_hsel      : in  std_logic;
        dev0_ahbs_dma_hreadyin  : in  std_logic;
        dev0_ahbs_dma_hrdata    : out std_logic_vector(31 downto 0);
        dev0_ahbs_dma_hreadyout : out std_logic;
        dev0_ahbs_dma_hresp     : out std_logic_vector(1 downto 0);
        dev0_ahbs_dma_hsize     : in  std_logic_vector(2 downto 0);
        dev0_ahbs_dma_hburst    : in  std_logic_vector(2 downto 0);
        dev0_mem_q              : in  std_logic_vector(63 downto 0);
        dev0_mem_d              : out std_logic_vector(63 downto 0);
        dev0_mem_cs             : out std_logic;
        dev0_mem_a              : out std_logic_vector(C_DEV0_RAM_ADDRWIDTH-1 downto 0);
        dev0_mem_web_out        : out std_logic;
        dev0_mem_bsel           : out std_logic_vector(63 downto 0);
        dev0_usb_irq            : out std_logic;
        dev0_usb_fiq            : out std_logic;
        dev1_ahbs_haddr         : in  std_logic_vector(5 downto 2);
        dev1_ahbs_htrans        : in  std_logic_vector(1 downto 0);
        dev1_ahbs_hwrite        : in  std_logic;
        dev1_ahbs_hwdata        : in  std_logic_vector(31 downto 0);
        dev1_ahbs_hsel          : in  std_logic;
        dev1_ahbs_hreadyin      : in  std_logic;
        dev1_ahbs_hrdata        : out std_logic_vector(31 downto 0);
        dev1_ahbs_hreadyout     : out std_logic;
        dev1_ahbs_hresp         : out std_logic_vector(1 downto 0);
        dev1_ahbs_dma_haddr     : in  std_logic_vector(C_DEV1_RAM_ADDRWIDTH-1+3 downto 0);
        dev1_ahbs_dma_htrans    : in  std_logic_vector(1 downto 0);
        dev1_ahbs_dma_hwrite    : in  std_logic;
        dev1_ahbs_dma_hwdata    : in  std_logic_vector(31 downto 0);
        dev1_ahbs_dma_hsel      : in  std_logic;
        dev1_ahbs_dma_hreadyin  : in  std_logic;
        dev1_ahbs_dma_hrdata    : out std_logic_vector(31 downto 0);
        dev1_ahbs_dma_hreadyout : out std_logic;
        dev1_ahbs_dma_hresp     : out std_logic_vector(1 downto 0);
        dev1_ahbs_dma_hsize     : in  std_logic_vector(2 downto 0);
        dev1_ahbs_dma_hburst    : in  std_logic_vector(2 downto 0);
        dev1_mem_q              : in  std_logic_vector(63 downto 0);
        dev1_mem_d              : out std_logic_vector(63 downto 0);
        dev1_mem_cs             : out std_logic;
        dev1_mem_a              : out std_logic_vector(C_DEV1_RAM_ADDRWIDTH-1 downto 0);
        dev1_mem_web_out        : out std_logic;
        dev1_mem_bsel           : out std_logic_vector(63 downto 0);
        dev1_usb_irq            : out std_logic;
        dev1_usb_fiq            : out std_logic;
        USB_FrameToggle         : out std_logic;
        rec_setup_pkt_vld       : out std_logic;
        rec_setup_pkt           : out std_logic_vector(63 downto 0);
        rec_ctrl_out_data       : out std_logic_vector(31 downto 0);
        rec_ctrl_out_vld        : out std_logic;
        rec_ctrl_out_last       : out std_logic;
        rec_ctrl_out_rdy        : in  std_logic;
        rec_ctrl_in_data        : in  std_logic_vector(31 downto 0);
        rec_ctrl_in_be          : in  std_logic_vector(3 downto 0);
        rec_ctrl_in_vld         : in  std_logic;
        rec_ctrl_in_last        : in  std_logic;
        rec_ctrl_in_rdy         : out std_logic;
        rec_ctrl_in_resp_bytes  : in  std_logic_vector(6 downto 0);
        rec_ctrl_in_resp_known  : in  std_logic;
        rec_ctrl_set_stall      : in  std_logic;
        rec_ctrl_xfer_done      : out std_logic;
        rec_ctrl_xfer_abort     : out std_logic;
        rec_ctrl_fifo_batch_abort : out std_logic;
        rec_ctrl_length_error   : out std_logic;
        rec_ocp_path_disable    : in  std_logic;
        rec_ocp_claim_abort     : in  std_logic;
        rec_fw_protocol_error_req : in  std_logic;
        rec_fifo_free_dwords    : in  std_logic_vector(6 downto 0);
        rec_fifo_payload_available : in  std_logic;
        rec_fifo_reservation_active : out std_logic;
        USB_VBus                : in  std_logic;
        vbuscomp_on             : out std_logic;
        chrg_vbus               : out std_logic;
        dischrg_vbus            : out std_logic;
        avalid                  : in  std_logic;
        sessend                 : in  std_logic;
        utmi_clk                : in  std_logic;
        utmi_rxdata             : in  std_logic_vector(7 downto 0);
        utmi_rxvalid            : in  std_logic;
        utmi_rxactive           : in  std_logic;
        utmi_rxerror            : in  std_logic;
        utmi_txdata             : out std_logic_vector(7 downto 0);
        utmi_txvalid            : out std_logic;
        utmi_txready            : in  std_logic;
        utmi_reset              : out std_logic;
        utmi_suspendm           : out std_logic;
        utmi_xcvrselect         : out std_logic;
        utmi_termselect         : out std_logic;
        utmi_opmode             : out std_logic_vector(1 downto 0);
        utmi_linestate          : in  std_logic_vector(1 downto 0);
        utmi_vcontrol           : out std_logic_vector(3 downto 0);
        utmi_vcontrolloadm      : out std_logic;
        utmi_vstatus            : in  std_logic_vector(7 downto 0);
        ulpi_clk                : in  std_logic;
        ulpi_rxdata             : in  std_logic_vector(7 downto 0);
        ulpi_txdata             : out std_logic_vector(7 downto 0);
        ulpi_txenable           : out std_logic;
        ulpi_dir                : in  std_logic;
        ulpi_stp                : out std_logic;
        ulpi_nxt                : in  std_logic;
        ulpi_ddr_sel            : in  std_logic;
        usb_needclk             : out std_logic;
        sys_donotwakeup_n       : in  std_logic;
        sys_dev_wakeup_n        : in  std_logic;
        sys_utmi_clkin_lock     : in  std_logic;
        USB_EnableHub           : in  std_logic;
        USB_self_powered        : in  std_logic;
        async_disable           : in  std_logic;
        testmode                : in  std_logic;
        usb_dma_dword_selection : out std_logic_vector(1 downto 0);
        usb_dma_write_access    : out std_logic
    );
end component ip_xxx_3511_hs_mem_compound;
end ip_xxx_3511_hs_mem_compound_cmp_pkg;
