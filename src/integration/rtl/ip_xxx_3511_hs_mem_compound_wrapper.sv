// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Copyright (c) 2026 NXP Semiconductors N.V.  All rights reserved.
// NXP Confidential Proprietary
// -------------------------------------------------------------------------
// FILE    : ip_xxx_3511_hs_mem_compound_wrapper.sv
// AUTHOR  : nxp
// DATE    : 2026-08-14
// -------------------------------------------------------------------------
// PURPOSE : AXI wrapper for the ip_xxx_3511_hs_mem_compound VHDL hub IP.
//
//           AXI subordinate map:
//             combo_axi_if
//               -> DEV0 CSR
//               -> OCP Recovery registers
//               -> HUB control and descriptor storage
//             dev0_mem_axi_if
//               -> DEV0 packet SRAM
//             dev1_csr_axi_if
//               -> DEV1 CSR
//             dev1_mem_axi_if
//               -> DEV1 packet SRAM
//
//           Each AXI interface pair uses one axi_to_ahb. The Combo AHB decoder
//           selects among its three downstream targets; each other interface
//           has one dedicated target.
// -------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION  DATE        AUTHOR   DESCRIPTION
// 0.1      2026-08-14  nxp      Initial integration drop; replaces 3516 wrapper
// 0.2      2026-08-14  nxp      Entity-typed mapping: 3 x axi_to_ahb, AHB reg/DMA decode
// 0.3      2026-09-04  nxp      Hub descriptor store migrated from external SRAM +
//                              dedicated DMA AHB port to an internal self-initializing
//                              flip-flop array. Removes the hub_desc_mem_* SRAM port,
//                              the 11 hub_desc_ahbs_dma_* AHB ports and tcb_clkgate_se;
//                              widens hub_ahbs_haddr to [9:2]; splits the per-device
//                              generics. See docs/usb_hub_ram_to_flipflop_migration.md
// 0.4      2026-09-11  Clayton  Overhaul AXI connections to interfaces and
//                               hide hub behind a combo AXI interface with
//                               DEV0
// 0.5      2026-09-23  MSFT     Instantiate OCP Recovery datapath on device0.
//                               Includes CONTROL arbiter, cmd decode, register set.
// -------------------------------------------------------------------------

`include "caliptra_prim_assert.sv"

module ip_xxx_3511_hs_mem_compound_wrapper
  import usb_compound_pkg::*;
#(

  // Number of 32-bit words in the hub descriptor flip-flop array. Must match
  // the IP default (172) unless the IP is reconfigured; it sets the width of
  // hub_ahbs_haddr and therefore the hub register aperture.
  parameter int unsigned C_HUB_FIFO_SIZE = 172,


  // ---- SRAM configuration -------------------------------------------------
  // Per-device EP-list / data-buffer SRAM address width. The IP splits this
  // into C_DEV0_RAM_ADDRWIDTH / C_DEV1_RAM_ADDRWIDTH; 
  parameter int unsigned C_DEV0_RAM_ADDRWIDTH = 15,
  parameter int unsigned C_DEV1_RAM_ADDRWIDTH = 15,

  // ---- USB IP configuration (forwarded to VHDL entity generics) ----------
  // C_DEV0_NBPHYSEP and C_DEV1_NBPHYSEP defines the number of physical endpoints
  // This can be different for both FW programmable devices
  // The value for these parameters must be a multiple of 2.
  // Note: the package constant C_NBPHYSEP is now hard-coded to 2 for the hub
  // itself and is unrelated to these two per-device values.
  parameter int unsigned C_DEV0_NBPHYSEP = 14,
  parameter int unsigned C_DEV1_NBPHYSEP = 14,
  parameter int unsigned C_EPUB          = 32,
  parameter int unsigned C_DAUB          = 32,
  parameter int unsigned C_DALB          = 17,
  // boolean generics: 1 = TRUE, 0 = FALSE
  // Applied to both devices; the IP now takes these per device
  parameter int unsigned C_SINGLE_BUFFER_SUPPORTED = 1,
  parameter int unsigned C_DOUBLE_BUFFER_SUPPORTED = 1,
  parameter int unsigned C_TOGGLE_REG_READABLE     = 1,
  parameter logic [31:0] C_EPFIFO_PAGE             = 32'h0008_0000,
  parameter logic [31:0] C_DATAFIFO_PAGE           = 32'h0008_0000,
  parameter int unsigned G_SIM_CHIRP_TIMERS        = 0
) (
  input  logic usb_axi_aclk,
  input  logic usb_axi_aresetn,

  // ---- Combo control AXI interface ----
  axi_if.w_sub combo_axi_if_w_sub,
  axi_if.r_sub combo_axi_if_r_sub,

  // ---- DEV0 memory AXI interface ----
  axi_if.w_sub dev0_mem_axi_if_w_sub,
  axi_if.r_sub dev0_mem_axi_if_r_sub,

  // ---- DEV1 CSR AXI interface ----
  axi_if.w_sub dev1_csr_axi_if_w_sub,
  axi_if.r_sub dev1_csr_axi_if_r_sub,

  // ---- DEV1 memory AXI interface ----
  axi_if.w_sub dev1_mem_axi_if_w_sub,
  axi_if.r_sub dev1_mem_axi_if_r_sub,

  // =========================================================================
  // USBDC0 SRAM interface  (MCU-owned device controller EP list + data buf)
  // =========================================================================
  input  logic [63:0] dev0_mem_q,
  output logic [63:0] dev0_mem_d,
  output logic dev0_mem_cs,
  output logic [C_DEV0_RAM_ADDRWIDTH-1:0] dev0_mem_a,
  output logic dev0_mem_web_out,
  output logic [63:0] dev0_mem_bsel,

  // =========================================================================
  // USBDC1 SRAM interface  (SoC-uC-owned device controller EP list + data buf)
  // =========================================================================
  input  logic [63:0] dev1_mem_q,
  output logic [63:0] dev1_mem_d,
  output logic dev1_mem_cs,
  output logic [C_DEV1_RAM_ADDRWIDTH-1:0] dev1_mem_a,
  output logic dev1_mem_web_out,
  output logic [63:0] dev1_mem_bsel,

  // =========================================================================
  // Interrupt outputs
  // =========================================================================
  output logic dev0_usb_irq,     // USBDC0 IRQ -> MCU VeeR
  output logic dev0_usb_fiq,     // USBDC0 FIQ -> MCU VeeR
  output logic dev1_usb_irq,     // USBDC1 IRQ -> SoC-uC
  output logic dev1_usb_fiq,     // USBDC1 FIQ -> SoC-uC
  output logic usb_frametoggle,  // SOF frame toggle
  output logic payload_available,
  output logic ocp_firmware_activated,

  // =========================================================================
  // USB power / VBus
  // =========================================================================
  input  logic USB_VBus,
  output logic vbuscomp_on,
  output logic chrg_vbus,
  output logic dischrg_vbus,
  input  logic avalid,
  input  logic sessend,


  input  logic utmi_clk,
  input  logic [7:0] utmi_rxdata,
  input  logic utmi_rxvalid,
  input  logic utmi_rxactive,
  input  logic utmi_rxerror,
  output logic [7:0] utmi_txdata,
  output logic utmi_txvalid,
  input  logic utmi_txready,
  output logic utmi_reset,
  output logic utmi_suspendm,
  output logic utmi_xcvrselect,   // 1-bit (was [1:0] in 3516)
  output logic utmi_termselect,
  output logic [1:0] utmi_opmode,
  input  logic [1:0] utmi_linestate,
  output logic [3:0] utmi_vcontrol,
  output logic utmi_vcontrolloadm,
  input  logic [7:0] utmi_vstatus,

  // =========================================================================
  // ULPI PHY interface
  // =========================================================================
  input  logic ulpi_clk,
  input  logic [7:0] ulpi_rxdata,
  output logic [7:0] ulpi_txdata,
  output logic ulpi_txenable,
  input  logic ulpi_dir,
  output logic ulpi_stp,
  input  logic ulpi_nxt,
  input  logic ulpi_ddr_sel,

  // =========================================================================
  // System / wakeup interface
  // =========================================================================
  output logic usb_needclk,
  input  logic sys_donotwakeup_n,
  input  logic sys_dev_wakeup_n,
  input  logic sys_utmi_clkin_lock,

  // =========================================================================
  // Hub mode control
  // =========================================================================
  input  logic USB_EnableHub,   // 0=single-device, 1=hub mode
  input  logic USB_self_powered,

  // =========================================================================
  // DFT / testability
  // =========================================================================
  input  logic testmode,
  input  logic async_disable
);
  // The fixed high-speed descriptor and setup-request image occupies 172 words.
  localparam int unsigned HUB_FIFO_SIZE_MIN = 172;
  // The EP0 memory path has a fixed 12-bit word address.
  localparam int unsigned HUB_FIFO_SIZE_MAX = 4096;

  localparam int unsigned HUB_AHB_WORD_ADDR_W = $clog2(C_HUB_FIFO_SIZE);
  localparam logic [32:0] HUB_APERTURE_BYTES  = 33'd1 << ($clog2(C_HUB_FIFO_SIZE) + 2);

  localparam int unsigned COMBO_LOCAL_ADDR_WIDTH    = $clog2(33'(HUB_BASE_ADDR + HUB_APERTURE_BYTES));
  localparam int unsigned DEV0_MEM_LOCAL_ADDR_WIDTH = C_DEV0_RAM_ADDRWIDTH + 3;
  localparam int unsigned DEV1_CSR_LOCAL_ADDR_WIDTH = DEV_CSR_ADDR_WIDTH;
  localparam int unsigned DEV1_MEM_LOCAL_ADDR_WIDTH = C_DEV1_RAM_ADDRWIDTH + 3;

  localparam int unsigned COMBO_AXI_ADDR_WIDTH   = $bits(combo_axi_if_r_sub.araddr);
  localparam int unsigned COMBO_AXI_DATA_WIDTH   = $bits(combo_axi_if_w_sub.wdata);
  localparam int unsigned COMBO_AXI_ID_WIDTH     = $bits(combo_axi_if_w_sub.awid);
  localparam int unsigned COMBO_AXI_USER_WIDTH   = $bits(combo_axi_if_w_sub.awuser);

  localparam int unsigned DEV0_MEM_AXI_ADDR_WIDTH   = $bits(dev0_mem_axi_if_r_sub.araddr);
  localparam int unsigned DEV0_MEM_AXI_DATA_WIDTH   = $bits(dev0_mem_axi_if_w_sub.wdata);
  localparam int unsigned DEV0_MEM_AXI_ID_WIDTH     = $bits(dev0_mem_axi_if_w_sub.awid);
  localparam int unsigned DEV0_MEM_AXI_USER_WIDTH   = $bits(dev0_mem_axi_if_w_sub.awuser);

  localparam int unsigned DEV1_CSR_AXI_ADDR_WIDTH   = $bits(dev1_csr_axi_if_r_sub.araddr);
  localparam int unsigned DEV1_CSR_AXI_DATA_WIDTH   = $bits(dev1_csr_axi_if_w_sub.wdata);
  localparam int unsigned DEV1_CSR_AXI_ID_WIDTH     = $bits(dev1_csr_axi_if_w_sub.awid);
  localparam int unsigned DEV1_CSR_AXI_USER_WIDTH   = $bits(dev1_csr_axi_if_w_sub.awuser);

  localparam int unsigned DEV1_MEM_AXI_ADDR_WIDTH   = $bits(dev1_mem_axi_if_r_sub.araddr);
  localparam int unsigned DEV1_MEM_AXI_DATA_WIDTH   = $bits(dev1_mem_axi_if_w_sub.wdata);
  localparam int unsigned DEV1_MEM_AXI_ID_WIDTH     = $bits(dev1_mem_axi_if_w_sub.awid);
  localparam int unsigned DEV1_MEM_AXI_USER_WIDTH   = $bits(dev1_mem_axi_if_w_sub.awuser);

  // ---- Combo AHB interface ----
  logic [COMBO_AXI_ADDR_WIDTH-1:0] combo_ahb_system_haddr;
  logic [COMBO_LOCAL_ADDR_WIDTH-1:0] combo_ahb_local_haddr;
  logic [1:0] combo_ahb_htrans;
  logic [2:0] combo_ahb_hburst;
  logic [2:0] combo_ahb_hsize;
  logic combo_ahb_hwrite;
  logic [31:0] combo_ahb_hwdata;
  logic combo_ahb_hsel;
  logic combo_ahb_hready;
  logic [31:0] combo_ahb_hrdata;
  logic combo_ahb_hreadyout;
  logic [1:0] combo_ahb_hresp;

  // ---- DEV0 memory AHB interface ----
  logic [DEV0_MEM_AXI_ADDR_WIDTH-1:0] dev0_mem_ahb_system_haddr;
  logic [DEV0_MEM_LOCAL_ADDR_WIDTH-1:0] dev0_mem_ahb_local_haddr;
  logic [1:0] dev0_mem_ahb_htrans;
  logic [2:0] dev0_mem_ahb_hburst;
  logic [2:0] dev0_mem_ahb_hsize;
  logic dev0_mem_ahb_hwrite;
  logic [31:0] dev0_mem_ahb_hwdata;
  logic dev0_mem_ahb_hsel;
  logic dev0_mem_ahb_hready;
  logic [31:0] dev0_mem_ahb_hrdata;
  logic dev0_mem_ahb_hreadyout;
  logic [1:0] dev0_mem_ahb_hresp;

  // ---- DEV1 CSR AHB interface ----
  logic [DEV1_CSR_AXI_ADDR_WIDTH-1:0] dev1_csr_ahb_system_haddr;
  logic [DEV1_CSR_LOCAL_ADDR_WIDTH-1:0] dev1_csr_ahb_local_haddr;
  logic [1:0] dev1_csr_ahb_htrans;
  logic [2:0] dev1_csr_ahb_hburst;
  logic [2:0] dev1_csr_ahb_hsize;
  logic dev1_csr_ahb_hwrite;
  logic [31:0] dev1_csr_ahb_hwdata;
  logic dev1_csr_ahb_hsel;
  logic dev1_csr_ahb_hready;
  logic [31:0] dev1_csr_ahb_hrdata;
  logic dev1_csr_ahb_hreadyout;
  logic [1:0] dev1_csr_ahb_hresp;
  logic [3:0] dev1_csr_word_addr_q;
  logic [3:0] dev1_csr_word_addr;

  // ---- DEV1 memory AHB interface ----
  logic [DEV1_MEM_AXI_ADDR_WIDTH-1:0] dev1_mem_ahb_system_haddr;
  logic [DEV1_MEM_LOCAL_ADDR_WIDTH-1:0] dev1_mem_ahb_local_haddr;
  logic [1:0] dev1_mem_ahb_htrans;
  logic [2:0] dev1_mem_ahb_hburst;
  logic [2:0] dev1_mem_ahb_hsize;
  logic dev1_mem_ahb_hwrite;
  logic [31:0] dev1_mem_ahb_hwdata;
  logic dev1_mem_ahb_hsel;
  logic dev1_mem_ahb_hready;
  logic [31:0] dev1_mem_ahb_hrdata;
  logic dev1_mem_ahb_hreadyout;
  logic [1:0] dev1_mem_ahb_hresp;

  // ---- DEV0 CSR AHB interface ----
  logic [3:0] dev0_csr_haddr;
  logic [1:0] dev0_csr_htrans;
  logic dev0_csr_hwrite;
  logic [31:0] dev0_csr_hwdata;
  logic dev0_csr_hsel;
  logic dev0_csr_hreadyin;
  logic [31:0] dev0_csr_hrdata;
  logic dev0_csr_hreadyout;
  logic [1:0] dev0_csr_hresp;

  // ---- HUB Bank AHB interface ----
  logic [HUB_AHB_WORD_ADDR_W-1:0] hub_haddr;
  logic [1:0] hub_htrans;
  logic hub_hwrite;
  logic [31:0] hub_hwdata;
  logic hub_hsel;
  logic hub_hreadyin;
  logic [31:0] hub_hrdata;
  logic hub_hreadyout;
  logic [1:0] hub_hresp;

  // ---- Recovery AHB interface ----
  logic [RECOVERY_LOCAL_ADDR_WIDTH-1:0] recovery_haddr;
  logic [1:0] recovery_htrans;
  logic [2:0] recovery_hburst;
  logic [2:0] recovery_hsize;
  logic recovery_hwrite;
  logic [31:0] recovery_hwdata;
  logic recovery_hsel;
  logic recovery_hreadyin;
  logic [31:0] recovery_hrdata;
  logic recovery_hreadyout;
  logic [1:0] recovery_hresp;

  // ---- VHDL recovery arbiter interface ----
  logic rec_setup_pkt_vld_w;
  logic [63:0] rec_setup_pkt_w;
  logic [31:0] rec_ctrl_out_data_w;
  logic rec_ctrl_out_vld_w;
  logic rec_ctrl_out_last_w;
  logic rec_ctrl_out_rdy_w;
  logic [31:0] rec_ctrl_in_data_w;
  logic [3:0] rec_ctrl_in_be_w;
  logic rec_ctrl_in_vld_w;
  logic rec_ctrl_in_last_w;
  logic rec_ctrl_in_rdy_w;
  logic [6:0] rec_ctrl_in_resp_bytes_w;
  logic rec_ctrl_in_resp_known_w;
  logic rec_ctrl_set_stall_w;
  logic rec_ctrl_xfer_done_w;
  logic rec_ctrl_xfer_abort_w;
  logic rec_ctrl_fifo_batch_abort_w;
  logic rec_ctrl_length_error_w;
  logic rec_ocp_path_disable_w;
  logic rec_ocp_claim_abort_w;
  logic rec_fw_protocol_error_req_w;
  logic [6:0] rec_fifo_free_dwords_w;
  logic rec_fifo_reservation_active_w;

  // Keep AXI2AHB at the caller's system address width, then explicitly localize
  // each port before it reaches the USB address map.
  assign combo_ahb_local_haddr = combo_ahb_system_haddr[COMBO_LOCAL_ADDR_WIDTH-1:0];
  assign dev0_mem_ahb_local_haddr = dev0_mem_ahb_system_haddr[DEV0_MEM_LOCAL_ADDR_WIDTH-1:0];
  assign dev1_csr_ahb_local_haddr = dev1_csr_ahb_system_haddr[DEV1_CSR_LOCAL_ADDR_WIDTH-1:0];
  assign dev1_mem_ahb_local_haddr = dev1_mem_ahb_system_haddr[DEV1_MEM_LOCAL_ADDR_WIDTH-1:0];

  // =========================================================================
  // AXI-to-AHB converter instantiations
  // =========================================================================
  axi_to_ahb #(
    .AW(COMBO_AXI_ADDR_WIDTH),
    .DW(COMBO_AXI_DATA_WIDTH),
    .IW(COMBO_AXI_ID_WIDTH),
    .UW(COMBO_AXI_USER_WIDTH)
  ) u_combo_axi2ahb (
    .clk(usb_axi_aclk),
    .rst_n(usb_axi_aresetn),
    .axi_r(combo_axi_if_r_sub),
    .axi_w(combo_axi_if_w_sub),
    .ahb_haddr(combo_ahb_system_haddr),
    .ahb_hburst(combo_ahb_hburst),
    .ahb_hsize(combo_ahb_hsize),
    .ahb_htrans(combo_ahb_htrans),
    .ahb_hwrite(combo_ahb_hwrite),
    .ahb_hwdata(combo_ahb_hwdata),
    .ahb_hsel(combo_ahb_hsel),
    .ahb_hreadymux(combo_ahb_hready),
    .ahb_hrdata(combo_ahb_hrdata),
    .ahb_hreadyout(combo_ahb_hreadyout),
    .ahb_hresp(combo_ahb_hresp)
  );
  axi_to_ahb #(
    .AW(DEV0_MEM_AXI_ADDR_WIDTH),
    .DW(DEV0_MEM_AXI_DATA_WIDTH),
    .IW(DEV0_MEM_AXI_ID_WIDTH),
    .UW(DEV0_MEM_AXI_USER_WIDTH)
  ) u_dev0_mem_axi2ahb (
    .clk(usb_axi_aclk),
    .rst_n(usb_axi_aresetn),
    .axi_r(dev0_mem_axi_if_r_sub),
    .axi_w(dev0_mem_axi_if_w_sub),
    .ahb_haddr(dev0_mem_ahb_system_haddr),
    .ahb_hburst(dev0_mem_ahb_hburst),
    .ahb_hsize(dev0_mem_ahb_hsize),
    .ahb_htrans(dev0_mem_ahb_htrans),
    .ahb_hwrite(dev0_mem_ahb_hwrite),
    .ahb_hwdata(dev0_mem_ahb_hwdata),
    .ahb_hsel(dev0_mem_ahb_hsel),
    .ahb_hreadymux(dev0_mem_ahb_hready),
    .ahb_hrdata(dev0_mem_ahb_hrdata),
    .ahb_hreadyout(dev0_mem_ahb_hreadyout),
    .ahb_hresp(dev0_mem_ahb_hresp)
  );
  axi_to_ahb #(
    .AW(DEV1_CSR_AXI_ADDR_WIDTH),
    .DW(DEV1_CSR_AXI_DATA_WIDTH),
    .IW(DEV1_CSR_AXI_ID_WIDTH),
    .UW(DEV1_CSR_AXI_USER_WIDTH)
  ) u_dev1_csr_axi2ahb (
    .clk(usb_axi_aclk),
    .rst_n(usb_axi_aresetn),
    .axi_r(dev1_csr_axi_if_r_sub),
    .axi_w(dev1_csr_axi_if_w_sub),
    .ahb_haddr(dev1_csr_ahb_system_haddr),
    .ahb_hburst(dev1_csr_ahb_hburst),
    .ahb_hsize(dev1_csr_ahb_hsize),
    .ahb_htrans(dev1_csr_ahb_htrans),
    .ahb_hwrite(dev1_csr_ahb_hwrite),
    .ahb_hwdata(dev1_csr_ahb_hwdata),
    .ahb_hsel(dev1_csr_ahb_hsel),
    .ahb_hreadymux(dev1_csr_ahb_hready),
    .ahb_hrdata(dev1_csr_ahb_hrdata),
    .ahb_hreadyout(dev1_csr_ahb_hreadyout),
    .ahb_hresp(dev1_csr_ahb_hresp)
  );
  axi_to_ahb #(
    .AW(DEV1_MEM_AXI_ADDR_WIDTH),
    .DW(DEV1_MEM_AXI_DATA_WIDTH),
    .IW(DEV1_MEM_AXI_ID_WIDTH),
    .UW(DEV1_MEM_AXI_USER_WIDTH)
  ) u_dev1_mem_axi2ahb (
    .clk(usb_axi_aclk),
    .rst_n(usb_axi_aresetn),
    .axi_r(dev1_mem_axi_if_r_sub),
    .axi_w(dev1_mem_axi_if_w_sub),
    .ahb_haddr(dev1_mem_ahb_system_haddr),
    .ahb_hburst(dev1_mem_ahb_hburst),
    .ahb_hsize(dev1_mem_ahb_hsize),
    .ahb_htrans(dev1_mem_ahb_htrans),
    .ahb_hwrite(dev1_mem_ahb_hwrite),
    .ahb_hwdata(dev1_mem_ahb_hwdata),
    .ahb_hsel(dev1_mem_ahb_hsel),
    .ahb_hreadymux(dev1_mem_ahb_hready),
    .ahb_hrdata(dev1_mem_ahb_hrdata),
    .ahb_hreadyout(dev1_mem_ahb_hreadyout),
    .ahb_hresp(dev1_mem_ahb_hresp)
  );

  usb_compound_ahb_decoder #(
    .C_HUB_FIFO_SIZE(C_HUB_FIFO_SIZE)
  ) u_ctrl_decoder (
    // ---- Clock and reset ----
    .clk(usb_axi_aclk),
    .rst_n(usb_axi_aresetn),

    // ---- Upstream Combo AHB interface ----
    .combo_haddr(combo_ahb_local_haddr),
    .combo_htrans(combo_ahb_htrans),
    .combo_hburst(combo_ahb_hburst),
    .combo_hsize(combo_ahb_hsize),
    .combo_hwrite(combo_ahb_hwrite),
    .combo_hsel(combo_ahb_hsel),
    .combo_hready(combo_ahb_hready),
    .combo_hwdata(combo_ahb_hwdata),
    .combo_hrdata(combo_ahb_hrdata),
    .combo_hreadyout(combo_ahb_hreadyout),
    .combo_hresp(combo_ahb_hresp),

    // ---- DEV0 CSR AHB interface (word address) ----
    .dev0_csr_haddr(dev0_csr_haddr),
    .dev0_csr_htrans(dev0_csr_htrans),
    .dev0_csr_hwrite(dev0_csr_hwrite),
    .dev0_csr_hwdata(dev0_csr_hwdata),
    .dev0_csr_hsel(dev0_csr_hsel),
    .dev0_csr_hreadyin(dev0_csr_hreadyin),
    .dev0_csr_hrdata(dev0_csr_hrdata),
    .dev0_csr_hreadyout(dev0_csr_hreadyout),
    .dev0_csr_hresp(dev0_csr_hresp),

    // ---- HUB Bank AHB interface ----
    .hub_haddr(hub_haddr),
    .hub_htrans(hub_htrans),
    .hub_hwrite(hub_hwrite),
    .hub_hwdata(hub_hwdata),
    .hub_hsel(hub_hsel),
    .hub_hreadyin(hub_hreadyin),
    .hub_hrdata(hub_hrdata),
    .hub_hreadyout(hub_hreadyout),
    .hub_hresp(hub_hresp),

    // ---- Recovery AHB interface ----
    .recovery_haddr(recovery_haddr),
    .recovery_htrans(recovery_htrans),
    .recovery_hburst(recovery_hburst),
    .recovery_hsize(recovery_hsize),
    .recovery_hwrite(recovery_hwrite),
    .recovery_hwdata(recovery_hwdata),
    .recovery_hsel(recovery_hsel),
    .recovery_hreadyin(recovery_hreadyin),
    .recovery_hrdata(recovery_hrdata),
    .recovery_hreadyout(recovery_hreadyout),
    .recovery_hresp(recovery_hresp)
  );

  usb_ocp_recovery_top #(
    .RECOVERY_LOCAL_ADDR_WIDTH(RECOVERY_LOCAL_ADDR_WIDTH)
  ) u_ocp_recovery (
    .clk(usb_axi_aclk),
    .rst_ni(usb_axi_aresetn),
    .rec_setup_pkt_vld(rec_setup_pkt_vld_w),
    .rec_setup_pkt(rec_setup_pkt_w),
    .rec_ctrl_out_data(rec_ctrl_out_data_w),
    .rec_ctrl_out_vld(rec_ctrl_out_vld_w),
    .rec_ctrl_out_last(rec_ctrl_out_last_w),
    .rec_ctrl_out_rdy(rec_ctrl_out_rdy_w),
    .rec_ctrl_in_data(rec_ctrl_in_data_w),
    .rec_ctrl_in_be(rec_ctrl_in_be_w),
    .rec_ctrl_in_vld(rec_ctrl_in_vld_w),
    .rec_ctrl_in_last(rec_ctrl_in_last_w),
    .rec_ctrl_in_rdy(rec_ctrl_in_rdy_w),
    .rec_ctrl_in_resp_bytes(rec_ctrl_in_resp_bytes_w),
    .rec_ctrl_in_resp_known(rec_ctrl_in_resp_known_w),
    .rec_ctrl_set_stall(rec_ctrl_set_stall_w),
    .rec_ctrl_xfer_done(rec_ctrl_xfer_done_w),
    .rec_ctrl_xfer_abort(rec_ctrl_xfer_abort_w),
    .rec_ctrl_fifo_batch_abort(rec_ctrl_fifo_batch_abort_w),
    .rec_ctrl_length_error(rec_ctrl_length_error_w),
    .rec_ocp_path_disable(rec_ocp_path_disable_w),
    .rec_ocp_claim_abort(rec_ocp_claim_abort_w),
    .rec_fw_protocol_error_req(rec_fw_protocol_error_req_w),
    .rec_fifo_free_dwords(rec_fifo_free_dwords_w),
    .rec_fifo_reservation_active(rec_fifo_reservation_active_w),
    .rec_ahb_haddr(recovery_haddr),
    .rec_ahb_htrans(recovery_htrans),
    .rec_ahb_hsize(recovery_hsize),
    .rec_ahb_hwrite(recovery_hwrite),
    .rec_ahb_hwdata(recovery_hwdata),
    .rec_ahb_hsel(recovery_hsel),
    .rec_ahb_hreadyin(recovery_hreadyin),
    .rec_ahb_hrdata(recovery_hrdata),
    .rec_ahb_hreadyout(recovery_hreadyout),
    .rec_ahb_hresp(recovery_hresp),
    .payload_available(payload_available),
    .recovery_image_activated(ocp_firmware_activated)
  );

  // The VHDL CSR samples its address every clock, including global waits.
  always_ff @(posedge usb_axi_aclk or negedge usb_axi_aresetn) begin
    if (!usb_axi_aresetn)
      dev1_csr_word_addr_q <= '0;
    else if (dev1_csr_ahb_hready && dev1_csr_ahb_hsel && dev1_csr_ahb_htrans[1])
      dev1_csr_word_addr_q <= dev1_csr_ahb_local_haddr[5:2];
  end
  assign dev1_csr_word_addr = dev1_csr_ahb_hready
                           ? dev1_csr_ahb_local_haddr[5:2] : dev1_csr_word_addr_q;

  // =========================================================================
  // ip_xxx_3511_hs_mem_compound instantiation  (VHDL entity, mixed-language)
  // =========================================================================
  logic [1:0] unused_dma_dword_sel_w;
  logic       unused_dma_write_access_w;
  
  ip_xxx_3511_hs_mem_compound #(
    .C_HUB_FIFO_SIZE(C_HUB_FIFO_SIZE),
    .C_DEV0_RAM_ADDRWIDTH(C_DEV0_RAM_ADDRWIDTH),
    .C_DEV1_RAM_ADDRWIDTH(C_DEV1_RAM_ADDRWIDTH),
    .C_DEV0_NBPHYSEP(C_DEV0_NBPHYSEP),
    .C_DEV1_NBPHYSEP(C_DEV1_NBPHYSEP),
    .C_EPUB(C_EPUB),
    .C_DAUB(C_DAUB),
    .C_DALB(C_DALB),
    .C_EPFIFO_PAGE(C_EPFIFO_PAGE),
    .C_DATAFIFO_PAGE(C_DATAFIFO_PAGE),
    .C_DEV0_SINGLE_BUFFER_SUPPORTED(C_SINGLE_BUFFER_SUPPORTED),
    .C_DEV0_DOUBLE_BUFFER_SUPPORTED(C_DOUBLE_BUFFER_SUPPORTED),
    .C_DEV0_TOGGLE_REG_READABLE(C_TOGGLE_REG_READABLE),
    .C_DEV1_SINGLE_BUFFER_SUPPORTED(C_SINGLE_BUFFER_SUPPORTED),
    .C_DEV1_DOUBLE_BUFFER_SUPPORTED(C_DOUBLE_BUFFER_SUPPORTED),
    .C_DEV1_TOGGLE_REG_READABLE(C_TOGGLE_REG_READABLE),
    .C_PLL_ENABLE(0),      // FALSE: no on-chip PLL
    // C_PLL_DIVIDER left at the IP default: C_PLL_ENABLE is FALSE
    .C_ULPI_SUPPORT(1),    // TRUE
    .C_UTMI_SUPPORT(1),    // TRUE
    .C_EXTEND_TX_DELAY(1), // TRUE
    .G_SIM_CHIRP_TIMERS(G_SIM_CHIRP_TIMERS)
  ) u_hub_compound (
    // ---- Clock / Reset ----
    .hclk(usb_axi_aclk),
    .hresetn(usb_axi_aresetn),
    .ahbs_resetn(usb_axi_aresetn),
    // ---- Hub control register AHB port (hub_ahbs) ----
    .hub_ahbs_haddr(hub_haddr),
    .hub_ahbs_htrans(hub_htrans),
    .hub_ahbs_hwrite(hub_hwrite),
    .hub_ahbs_hwdata(hub_hwdata),
    .hub_ahbs_hsel(hub_hsel),
    .hub_ahbs_hreadyin(hub_hreadyin),
    .hub_ahbs_hrdata(hub_hrdata),
    .hub_ahbs_hreadyout(hub_hreadyout),
    .hub_ahbs_hresp(hub_hresp),
    // ---- USBDC0 control register AHB port (dev0_ahbs) ----
    .dev0_ahbs_haddr(dev0_csr_haddr),
    .dev0_ahbs_htrans(dev0_csr_htrans),
    .dev0_ahbs_hwrite(dev0_csr_hwrite),
    .dev0_ahbs_hwdata(dev0_csr_hwdata),
    .dev0_ahbs_hsel(dev0_csr_hsel),
    .dev0_ahbs_hreadyin(dev0_csr_hreadyin),
    .dev0_ahbs_hrdata(dev0_csr_hrdata),
    .dev0_ahbs_hreadyout(dev0_csr_hreadyout),
    .dev0_ahbs_hresp(dev0_csr_hresp),
    // ---- USBDC0 DMA AHB port (dev0_ahbs_dma) ----
    .dev0_ahbs_dma_haddr(dev0_mem_ahb_local_haddr),
    .dev0_ahbs_dma_htrans(dev0_mem_ahb_htrans),
    .dev0_ahbs_dma_hwrite(dev0_mem_ahb_hwrite),
    .dev0_ahbs_dma_hwdata(dev0_mem_ahb_hwdata),
    .dev0_ahbs_dma_hsel(dev0_mem_ahb_hsel),
    .dev0_ahbs_dma_hreadyin(dev0_mem_ahb_hready),
    .dev0_ahbs_dma_hrdata(dev0_mem_ahb_hrdata),
    .dev0_ahbs_dma_hreadyout(dev0_mem_ahb_hreadyout),
    .dev0_ahbs_dma_hresp(dev0_mem_ahb_hresp),
    .dev0_ahbs_dma_hsize(dev0_mem_ahb_hsize),
    .dev0_ahbs_dma_hburst(dev0_mem_ahb_hburst),
    // ---- USBDC1 control register AHB port (dev1_ahbs) ----
    .dev1_ahbs_haddr(dev1_csr_word_addr),
    .dev1_ahbs_htrans(dev1_csr_ahb_htrans),
    .dev1_ahbs_hwrite(dev1_csr_ahb_hwrite),
    .dev1_ahbs_hwdata(dev1_csr_ahb_hwdata),
    .dev1_ahbs_hsel(dev1_csr_ahb_hsel),
    .dev1_ahbs_hreadyin(dev1_csr_ahb_hready),
    .dev1_ahbs_hrdata(dev1_csr_ahb_hrdata),
    .dev1_ahbs_hreadyout(dev1_csr_ahb_hreadyout),
    .dev1_ahbs_hresp(dev1_csr_ahb_hresp),
    // ---- USBDC1 DMA AHB port (dev1_ahbs_dma) ----
    .dev1_ahbs_dma_haddr(dev1_mem_ahb_local_haddr),
    .dev1_ahbs_dma_htrans(dev1_mem_ahb_htrans),
    .dev1_ahbs_dma_hwrite(dev1_mem_ahb_hwrite),
    .dev1_ahbs_dma_hwdata(dev1_mem_ahb_hwdata),
    .dev1_ahbs_dma_hsel(dev1_mem_ahb_hsel),
    .dev1_ahbs_dma_hreadyin(dev1_mem_ahb_hready),
    .dev1_ahbs_dma_hrdata(dev1_mem_ahb_hrdata),
    .dev1_ahbs_dma_hreadyout(dev1_mem_ahb_hreadyout),
    .dev1_ahbs_dma_hresp(dev1_mem_ahb_hresp),
    .dev1_ahbs_dma_hsize(dev1_mem_ahb_hsize),
    .dev1_ahbs_dma_hburst(dev1_mem_ahb_hburst),
    // ---- USBDC0 SRAM ----
    .dev0_mem_q(dev0_mem_q),
    .dev0_mem_d(dev0_mem_d),
    .dev0_mem_cs(dev0_mem_cs),
    .dev0_mem_a(dev0_mem_a),
    .dev0_mem_web_out(dev0_mem_web_out),
    .dev0_mem_bsel(dev0_mem_bsel),
    // ---- USBDC1 SRAM ----
    .dev1_mem_q(dev1_mem_q),
    .dev1_mem_d(dev1_mem_d),
    .dev1_mem_cs(dev1_mem_cs),
    .dev1_mem_a(dev1_mem_a),
    .dev1_mem_web_out(dev1_mem_web_out),
    .dev1_mem_bsel(dev1_mem_bsel),
    // ---- USBDC0 interrupts (routed to MCU VeeR)
    .dev0_usb_irq(dev0_usb_irq),
    .dev0_usb_fiq(dev0_usb_fiq),
    // ---- USBDC1 interrupts
    .dev1_usb_irq(dev1_usb_irq),
    .dev1_usb_fiq(dev1_usb_fiq),
    // ---- SOF frame toggle ----
    .USB_FrameToggle(usb_frametoggle),
    .rec_setup_pkt_vld(rec_setup_pkt_vld_w),
    .rec_setup_pkt(rec_setup_pkt_w),
    .rec_ctrl_out_data(rec_ctrl_out_data_w),
    .rec_ctrl_out_vld(rec_ctrl_out_vld_w),
    .rec_ctrl_out_last(rec_ctrl_out_last_w),
    .rec_ctrl_out_rdy(rec_ctrl_out_rdy_w),
    .rec_ctrl_in_data(rec_ctrl_in_data_w),
    .rec_ctrl_in_be(rec_ctrl_in_be_w),
    .rec_ctrl_in_vld(rec_ctrl_in_vld_w),
    .rec_ctrl_in_last(rec_ctrl_in_last_w),
    .rec_ctrl_in_rdy(rec_ctrl_in_rdy_w),
    .rec_ctrl_in_resp_bytes(rec_ctrl_in_resp_bytes_w),
    .rec_ctrl_in_resp_known(rec_ctrl_in_resp_known_w),
    .rec_ctrl_set_stall(rec_ctrl_set_stall_w),
    .rec_ctrl_xfer_done(rec_ctrl_xfer_done_w),
    .rec_ctrl_xfer_abort(rec_ctrl_xfer_abort_w),
    .rec_ctrl_fifo_batch_abort(rec_ctrl_fifo_batch_abort_w),
    .rec_ctrl_length_error(rec_ctrl_length_error_w),
    .rec_ocp_path_disable(rec_ocp_path_disable_w),
    .rec_ocp_claim_abort(rec_ocp_claim_abort_w),
    .rec_fw_protocol_error_req(rec_fw_protocol_error_req_w),
    .rec_fifo_free_dwords(rec_fifo_free_dwords_w),
    .rec_fifo_payload_available(payload_available),
    .rec_fifo_reservation_active(rec_fifo_reservation_active_w),
    // ---- VBus / session ----
    .USB_VBus(USB_VBus),
    .vbuscomp_on(vbuscomp_on),
    .chrg_vbus(chrg_vbus),
    .dischrg_vbus(dischrg_vbus),
    .avalid(avalid),
    .sessend(sessend),
    // ---- UTMI PHY ----
    .utmi_clk(utmi_clk),
    .utmi_rxdata(utmi_rxdata),
    .utmi_rxvalid(utmi_rxvalid),
    .utmi_rxactive(utmi_rxactive),
    .utmi_rxerror(utmi_rxerror),
    .utmi_txdata(utmi_txdata),
    .utmi_txvalid(utmi_txvalid),
    .utmi_txready(utmi_txready),
    .utmi_reset(utmi_reset),
    .utmi_suspendm(utmi_suspendm),
    .utmi_xcvrselect(utmi_xcvrselect),
    .utmi_termselect(utmi_termselect),
    .utmi_opmode(utmi_opmode),
    .utmi_linestate(utmi_linestate),
    .utmi_vcontrol(utmi_vcontrol),
    .utmi_vcontrolloadm(utmi_vcontrolloadm),
    .utmi_vstatus(utmi_vstatus),
    // ---- ULPI PHY ----
    .ulpi_clk(ulpi_clk),
    .ulpi_rxdata(ulpi_rxdata),
    .ulpi_txdata(ulpi_txdata),
    .ulpi_txenable(ulpi_txenable),
    .ulpi_dir(ulpi_dir),
    .ulpi_stp(ulpi_stp),
    .ulpi_nxt(ulpi_nxt),
    .ulpi_ddr_sel(ulpi_ddr_sel),
    // ---- System / wakeup ----
    .usb_needclk(usb_needclk),
    .sys_donotwakeup_n(sys_donotwakeup_n),
    .sys_dev_wakeup_n(sys_dev_wakeup_n),
    .sys_utmi_clkin_lock(sys_utmi_clkin_lock),
    // ---- Hub mode control ----
    .USB_EnableHub(USB_EnableHub),
    .USB_self_powered(USB_self_powered),
    // ---- DFT ----
    .async_disable(async_disable),
    .testmode(testmode),
    .usb_dma_dword_selection(unused_dma_dword_sel_w),
    .usb_dma_write_access(unused_dma_write_access_w)
  );

  `CALIPTRA_ASSERT_INIT(HubFifoSize_A,
                        (C_HUB_FIFO_SIZE >= HUB_FIFO_SIZE_MIN) &&
                        (C_HUB_FIFO_SIZE <= HUB_FIFO_SIZE_MAX))
  `CALIPTRA_ASSERT_INIT(ComboAxiAddrWidth_A,
                        (COMBO_AXI_ADDR_WIDTH >= COMBO_LOCAL_ADDR_WIDTH) &&
                        ($bits(combo_axi_if_w_sub.awaddr) == COMBO_AXI_ADDR_WIDTH))
  `CALIPTRA_ASSERT_INIT(ComboAxiDataWidth_A,
                        (COMBO_AXI_DATA_WIDTH == 32) &&
                        ($bits(combo_axi_if_r_sub.rdata) == 32))
  `CALIPTRA_ASSERT_INIT(Dev0MemAxiAddrWidth_A,
                        (DEV0_MEM_AXI_ADDR_WIDTH >= DEV0_MEM_LOCAL_ADDR_WIDTH) &&
                        ($bits(dev0_mem_axi_if_w_sub.awaddr) == DEV0_MEM_AXI_ADDR_WIDTH))
  `CALIPTRA_ASSERT_INIT(Dev0MemAxiDataWidth_A,
                        (DEV0_MEM_AXI_DATA_WIDTH == 32) &&
                        ($bits(dev0_mem_axi_if_r_sub.rdata) == 32))
  `CALIPTRA_ASSERT_INIT(Dev1CsrAxiAddrWidth_A,
                        (DEV1_CSR_AXI_ADDR_WIDTH >= DEV1_CSR_LOCAL_ADDR_WIDTH) &&
                        ($bits(dev1_csr_axi_if_w_sub.awaddr) == DEV1_CSR_AXI_ADDR_WIDTH))
  `CALIPTRA_ASSERT_INIT(Dev1CsrAxiDataWidth_A,
                        (DEV1_CSR_AXI_DATA_WIDTH == 32) &&
                        ($bits(dev1_csr_axi_if_r_sub.rdata) == 32))
  `CALIPTRA_ASSERT_INIT(Dev1MemAxiAddrWidth_A,
                        (DEV1_MEM_AXI_ADDR_WIDTH >= DEV1_MEM_LOCAL_ADDR_WIDTH) &&
                        ($bits(dev1_mem_axi_if_w_sub.awaddr) == DEV1_MEM_AXI_ADDR_WIDTH))
  `CALIPTRA_ASSERT_INIT(Dev1MemAxiDataWidth_A,
                        (DEV1_MEM_AXI_DATA_WIDTH == 32) &&
                        ($bits(dev1_mem_axi_if_r_sub.rdata) == 32))
endmodule : ip_xxx_3511_hs_mem_compound_wrapper
