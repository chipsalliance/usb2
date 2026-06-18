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
// Copyright (c) 2025 NXP Semiconductors N.V. All rights reserved
// NXP Confidential Proprietary
// ----------------------------------------------------------------------------
// FILE NAME      : ip_xxx_3516_hs_mem_wrapper.sv 
// DEPARTMENT     :  
// AUTHOR         : 
// AUTHOR'S EMAIL : 
// ----------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION  DATE        AUTHOR          DESCRIPTION
// 0.1      2026-03-05  nxp             Initial Release for USB 2.0 IP 
// 0.2      2026-03-31  cwhitehead      Replace AHB ports with AXI; add
//                                      axi_to_ahb converters internally
//----------------------------------------------------------------------------
// PURPOSE  : Top module USB 2.0 IP with AXI subordinate interfaces
// ----------------------------------------------------------------------------
// PARAMETERS
//     PARAM NAME      RANGE    : DESCRIPTION             : DEFAULT : UNITS
// e.g.DATA_WIDTH      [32:16]  : width of the data       : 32      : 
// ----------------------------------------------------------------------------

module ip_xxx_3516_hs_mem_wrapper
  import axi_pkg::*;
#(
  parameter        RAM_ADDRWIDTH = 9,
  parameter        C_NBPHYSEP = 14,
  parameter        C_SINGLE_BUFFER_SUPPORTED = 1,
  parameter        C_DOUBLE_BUFFER_SUPPORTED = 1,
  parameter        C_EPUB = 32,
  parameter        C_DAUB = 32,
  parameter        C_DALB = 17,
  parameter        C_TOGGLE_REG_READABLE = 1,
  parameter [31:0] C_EPFIFO_PAGE = 32'h00080000,
  parameter [31:0] C_DATAFIFO_PAGE = 32'h00080000,
  // AXI parameters
  parameter        AXI_DATA_WIDTH = 32,
  parameter        AXI_ID_WIDTH   = 8,
  parameter        AXI_USER_WIDTH = 32,
  parameter        AXI_DMA_ADDR_WIDTH = 32,
  parameter        AXI_DEV_ADDR_WIDTH = 32,
  parameter        AXI_HOST_ADDR_WIDTH = 32,
  // Simulation chirp timer scaling: set 1 to use reduced chirp K
  // duration and pre-chirp delay for VIP scaledown compatibility.
  // Default 0 uses USB 2.0 spec-compliant timer values.
  parameter        G_SIM_CHIRP_TIMERS = 0,
  // -----------------------------------------------------------------
  // OCP Recovery subsystem (A7 integration)
  // -----------------------------------------------------------------
  parameter        AXI_REC_ADDR_WIDTH   = 32,
  parameter int    REC_CMS_ADDR_W       = 16,
  parameter int    REC_NUM_CMS          = 2,
  // PROT_CAP bytes 0..15 (OCP Recovery v1.1 Sec 9.2 cmd 0x22 Tbl 9-3).
  // - bytes[0..7] = ASCII magic "OCP RECV" (little-endian on wire).
  // - byte[8]     = Major = 1
  // - byte[9]     = Minor = 1
  // - bytes[10..11] = CAPABILITIES bitmap, little-endian = 0x16BB:
  //     bit  0 = Identification         (CMD 0x23/IDENT)
  //     bit  1 = Forced Recovery        (CMD 0x24/RECOVERY_CTRL)
  //     bit  3 = Device Reset           (CMD 0x26/RESET)
  //     bit  4 = Device Status          (CMD 0x25/DEV_STATUS)
  //     bit  5 = Recovery memory access (CMD 0x28/INDIRECT_CTRL)
  //     bit  7 = Push C-image support
  //     bit  9 = Hardware status        (CMD 0x27/HW_STATUS)
  //     bit 10 = Vendor command         (CMD 0x2F/VENDOR)
  //     bit 12 = FIFO CMS support       (CMD 0x2C/INDIRECT_FIFO_CTRL,
  //                                      0x2D/INDIRECT_FIFO_STATUS,
  //                                      0x2E/INDIRECT_FIFO_DATA)
  // - byte[12]    = NUM_CMS_REGIONS = 2 (per REC_NUM_CMS)
  // - byte[13]    = MAX_RESPONSE_TIME (0 => spec default)
  // - byte[14]    = HEARTBEAT_PERIOD  (0 => not implemented)
  // - byte[15]    = reserved
  // Override by parameter at the SoC if a different capability bitmap is
  // needed (review delta C9 fix).
  parameter logic [127:0] REC_PROT_CAP_DEFAULT  =
      { 8'h00, 8'h00, 8'h00, 8'h02,             // [15:12] resv, HB, MRT, NUM_CMS=2
        8'h16, 8'hBB,                            // [11:10] capabilities = 0x16BB
        8'h01, 8'h01,                            // [9:8]   minor=1, major=1
        8'h56, 8'h43, 8'h45, 8'h52,              // [7:4]   'V','C','E','R'
        8'h20, 8'h50, 8'h43, 8'h4F },            // [3:0]   ' ','P','C','O'
  parameter logic [191:0] REC_DEVICE_ID_DEFAULT = 192'h0
 )  
 (
    // ----------------------------------------------------------------
    // Device AXI4-Lite subordinate interface
    // ----------------------------------------------------------------
    input                              dev_axi_aclk,
    input                              dev_axi_aresetn,
    // AR
    input  [AXI_DEV_ADDR_WIDTH-1:0]   dev_axi_araddr,
    input  [1:0]                       dev_axi_arburst,
    input  [2:0]                       dev_axi_arsize,
    input  [7:0]                       dev_axi_arlen,
    input  [AXI_USER_WIDTH-1:0]       dev_axi_aruser,
    input  [AXI_ID_WIDTH-1:0]         dev_axi_arid,
    input                              dev_axi_arlock,
    input  [3:0]                       dev_axi_arcache,
    input  [2:0]                       dev_axi_arprot,
    input  [3:0]                       dev_axi_arqos,
    input  [3:0]                       dev_axi_arregion,
    input                              dev_axi_arvalid,
    output                             dev_axi_arready,
    // R
    output [AXI_DATA_WIDTH-1:0]       dev_axi_rdata,
    output [1:0]                       dev_axi_rresp,
    output [AXI_ID_WIDTH-1:0]         dev_axi_rid,
    output [AXI_USER_WIDTH-1:0]       dev_axi_ruser,
    output                             dev_axi_rlast,
    output                             dev_axi_rvalid,
    input                              dev_axi_rready,
    // AW
    input  [AXI_DEV_ADDR_WIDTH-1:0]   dev_axi_awaddr,
    input  [1:0]                       dev_axi_awburst,
    input  [2:0]                       dev_axi_awsize,
    input  [7:0]                       dev_axi_awlen,
    input  [AXI_USER_WIDTH-1:0]       dev_axi_awuser,
    input  [AXI_ID_WIDTH-1:0]         dev_axi_awid,
    input                              dev_axi_awlock,
    input  [3:0]                       dev_axi_awcache,
    input  [2:0]                       dev_axi_awprot,
    input  [3:0]                       dev_axi_awqos,
    input  [3:0]                       dev_axi_awregion,
    input                              dev_axi_awvalid,
    output                             dev_axi_awready,
    // W
    input  [AXI_DATA_WIDTH-1:0]       dev_axi_wdata,
    input  [AXI_DATA_WIDTH/8-1:0]     dev_axi_wstrb,
    input  [AXI_USER_WIDTH-1:0]       dev_axi_wuser,
    input                              dev_axi_wvalid,
    output                             dev_axi_wready,
    input                              dev_axi_wlast,
    // B
    output [1:0]                       dev_axi_bresp,
    output [AXI_ID_WIDTH-1:0]         dev_axi_bid,
    output [AXI_USER_WIDTH-1:0]       dev_axi_buser,
    output                             dev_axi_bvalid,
    input                              dev_axi_bready,

    // ----------------------------------------------------------------
    // Host AXI4-Lite subordinate interface
    // ----------------------------------------------------------------
    input                              host_axi_aclk,
    input                              host_axi_aresetn,
    // AR
    input  [AXI_HOST_ADDR_WIDTH-1:0]  host_axi_araddr,
    input  [1:0]                       host_axi_arburst,
    input  [2:0]                       host_axi_arsize,
    input  [7:0]                       host_axi_arlen,
    input  [AXI_USER_WIDTH-1:0]       host_axi_aruser,
    input  [AXI_ID_WIDTH-1:0]         host_axi_arid,
    input                              host_axi_arlock,
    input  [3:0]                       host_axi_arcache,
    input  [2:0]                       host_axi_arprot,
    input  [3:0]                       host_axi_arqos,
    input  [3:0]                       host_axi_arregion,
    input                              host_axi_arvalid,
    output                             host_axi_arready,
    // R
    output [AXI_DATA_WIDTH-1:0]       host_axi_rdata,
    output [1:0]                       host_axi_rresp,
    output [AXI_ID_WIDTH-1:0]         host_axi_rid,
    output [AXI_USER_WIDTH-1:0]       host_axi_ruser,
    output                             host_axi_rlast,
    output                             host_axi_rvalid,
    input                              host_axi_rready,
    // AW
    input  [AXI_HOST_ADDR_WIDTH-1:0]  host_axi_awaddr,
    input  [1:0]                       host_axi_awburst,
    input  [2:0]                       host_axi_awsize,
    input  [7:0]                       host_axi_awlen,
    input  [AXI_USER_WIDTH-1:0]       host_axi_awuser,
    input  [AXI_ID_WIDTH-1:0]         host_axi_awid,
    input                              host_axi_awlock,
    input  [3:0]                       host_axi_awcache,
    input  [2:0]                       host_axi_awprot,
    input  [3:0]                       host_axi_awqos,
    input  [3:0]                       host_axi_awregion,
    input                              host_axi_awvalid,
    output                             host_axi_awready,
    // W
    input  [AXI_DATA_WIDTH-1:0]       host_axi_wdata,
    input  [AXI_DATA_WIDTH/8-1:0]     host_axi_wstrb,
    input  [AXI_USER_WIDTH-1:0]       host_axi_wuser,
    input                              host_axi_wvalid,
    output                             host_axi_wready,
    input                              host_axi_wlast,
    // B
    output [1:0]                       host_axi_bresp,
    output [AXI_ID_WIDTH-1:0]         host_axi_bid,
    output [AXI_USER_WIDTH-1:0]       host_axi_buser,
    output                             host_axi_bvalid,
    input                              host_axi_bready,

    // ----------------------------------------------------------------
    // DMA AXI4 subordinate interface (full burst support)
    // ----------------------------------------------------------------
    input                              dma_axi_aclk,
    input                              dma_axi_aresetn,
    // AR
    input  [AXI_DMA_ADDR_WIDTH-1:0]   dma_axi_araddr,
    input  [1:0]                       dma_axi_arburst,
    input  [2:0]                       dma_axi_arsize,
    input  [7:0]                       dma_axi_arlen,
    input  [AXI_USER_WIDTH-1:0]       dma_axi_aruser,
    input  [AXI_ID_WIDTH-1:0]         dma_axi_arid,
    input                              dma_axi_arlock,
    input  [3:0]                       dma_axi_arcache,
    input  [2:0]                       dma_axi_arprot,
    input  [3:0]                       dma_axi_arqos,
    input  [3:0]                       dma_axi_arregion,
    input                              dma_axi_arvalid,
    output                             dma_axi_arready,
    // R
    output [AXI_DATA_WIDTH-1:0]       dma_axi_rdata,
    output [1:0]                       dma_axi_rresp,
    output [AXI_ID_WIDTH-1:0]         dma_axi_rid,
    output [AXI_USER_WIDTH-1:0]       dma_axi_ruser,
    output                             dma_axi_rlast,
    output                             dma_axi_rvalid,
    input                              dma_axi_rready,
    // AW
    input  [AXI_DMA_ADDR_WIDTH-1:0]   dma_axi_awaddr,
    input  [1:0]                       dma_axi_awburst,
    input  [2:0]                       dma_axi_awsize,
    input  [7:0]                       dma_axi_awlen,
    input  [AXI_USER_WIDTH-1:0]       dma_axi_awuser,
    input  [AXI_ID_WIDTH-1:0]         dma_axi_awid,
    input                              dma_axi_awlock,
    input  [3:0]                       dma_axi_awcache,
    input  [2:0]                       dma_axi_awprot,
    input  [3:0]                       dma_axi_awqos,
    input  [3:0]                       dma_axi_awregion,
    input                              dma_axi_awvalid,
    output                             dma_axi_awready,
    // W
    input  [AXI_DATA_WIDTH-1:0]       dma_axi_wdata,
    input  [AXI_DATA_WIDTH/8-1:0]     dma_axi_wstrb,
    input  [AXI_USER_WIDTH-1:0]       dma_axi_wuser,
    input                              dma_axi_wvalid,
    output                             dma_axi_wready,
    input                              dma_axi_wlast,
    // B
    output [1:0]                       dma_axi_bresp,
    output [AXI_ID_WIDTH-1:0]         dma_axi_bid,
    output [AXI_USER_WIDTH-1:0]       dma_axi_buser,
    output                             dma_axi_bvalid,
    input                              dma_axi_bready,

    // ----------------------------------------------------------------
    // Non-AXI ports (unchanged)
    // ----------------------------------------------------------------
    input [63:0]   mem_q,
				   output [63:0]  mem_d,
				   output 		       mem_cs,
				   output [RAM_ADDRWIDTH-1:0]  mem_a,
				   output 		       mem_web_out,
				   output [63:0]  mem_bsel,
				   output 		       dev_usb_int_req_irq,
				   output 		       dev_usb_Int_req_fiq,
				   output 		       dev_usbframetoggle,
				   output 		       host_usb_int_req_irq,
				   input 		       USB_VBus,
				   output 		       vbuscomp_on,
				   output 		       chrgvbus,
				   output 		       dischrgvbus,
				   input 		       avalid,
				   input 		       sessend,
				   input 		       utmi_clk,
				   input [7:0] 		       utmi_rxdata,
				   input 		       utmi_rxvalid,
				   input 		       utmi_rxactive,
				   input 		       utmi_rxerror,
				   output [7:0] 	       utmi_txdata,
				   output 		       utmi_txvalid,
				   input 		       utmi_txready,
				   output 		       utmi_reset,
				   output 		       utmi_suspendm,
				   output [1:0] 	       utmi_xcvrselect,
				   output 		       utmi_termselect,
				   output [1:0] 	       utmi_opmode,
				   input [1:0] 		       utmi_linestate,
				   output [3:0] 	       utmi_vcontrol,
				   output 		       utmi_vcontrolloadm,
				   input [7:0] 		       utmi_vstatus,
				   input 		       utmi_hostdisconnect,
				   output 		       utmi_id_enable,
				   input 		       utmi_id_value,
				   output 		       utmi_dppulldown,
				   output 		       utmi_dmpulldown,
				   output 		       pdcom,
				   input 		       ulpi_clk,
				   input [7:0] 		       ulpi_rxdata,
				   output [7:0] 	       ulpi_txdata,
				   output 		       ulpi_txenable,
				   input 		       ulpi_dir,
				   output 		       ulpi_stp,
				   input 		       ulpi_nxt,
				   input 		       ulpi_ddr_sel,
				   output 		       dev_usb_needclk,
				   output 		       host_usb_needclk,
				   input 		       dev_sys_donotwakeup_n,
				   input 		       host_sys_donotwakeup_n,
				   input 		       dev_sys_wakeup_n,
				   input 		       dev_sys_utmi_clkin_lock,
				   input 		       host_sys_utmi_clkin_lock,
				   input 		       host_usb_overcurrent_n,
				   output [1:0] 	       host_usb_portindicator,
				   output 		       host_usb_portpower,
				   input [6:0] 		       token_length_counter,
				   output [6:0] 	       usb_token_length,
				   // ----------------------------------------------------------------
				   // OCP Recovery v1.1 - A7 integration (additive, 2026)
				   // ----------------------------------------------------------------
				   // Note (Phase 1c): the AXI4-Lite management port (rec_axi_*)
				   // has been removed.  The recovery register-bus is now
				   // accessed via an AHB sub-decoder taking off the existing
				   // dev_axi -> AHB path (see rec_ahb_subdec below; OCP
				   // Recovery v1.1 Section 8.5).

				   // CMS external SRAM (from A4, byte-wide)
				   output [REC_CMS_ADDR_W-1:0]      cms_addr,
				   output                            cms_wr,
				   output                            cms_rd,
				   output [7:0]                     cms_wdata,
				   input  [7:0]                     cms_rdata,

				   // Sideband inputs (SoC -> recovery FSM)
				   input                             rec_trigger,
				   input                             soc_boot_ack,

				   // Sideband outputs (recovery FSM -> SoC)
				   output                            rec_active,
				   output                            image_ready,
				   output                            boot_req,
				   output                            device_reset_req,
				   output                            fatal_err,
				   // ----------------------------------------------------------------
				   // OCP Recovery v1.1 status pins (architecture proposal 3.7)
				   // Driven by usb_ocp_recovery_fsm via wrapper sideband nets.
				   // ----------------------------------------------------------------
				   output wire                 ocp_recovery_available,
				   output wire                 ocp_firmware_activated
				   );

   // ================================================================
   // Internal AHB signals from AXI-to-AHB converters
   // ================================================================

   // -- Device AHB (Lite converter output) --
   logic [AXI_DEV_ADDR_WIDTH-1:0] dev_ahb_haddr;
   logic [2:0]                     dev_ahb_hburst;
   logic [2:0]                     dev_ahb_hsize;
   logic [1:0]                     dev_ahb_htrans;
   logic                           dev_ahb_hwrite;
   logic [AXI_DATA_WIDTH-1:0]     dev_ahb_hwdata;
   logic                           dev_ahb_hsel;
   logic                           dev_ahb_hreadymux;
   logic [AXI_DATA_WIDTH-1:0]     dev_ahb_hrdata;
   logic                           dev_ahb_hreadyout;
   logic [1:0]                     dev_ahb_hresp;

   // Legacy IP (uut) sub-decoder response nets.  Multiplexed with the
   // OCP Recovery AHB sub-decoder response below (C1) before being
   // presented back to the AXI-to-AHB converter.
   logic [AXI_DATA_WIDTH-1:0]     legacy_dev_hrdata;
   logic                           legacy_dev_hreadyout;
   logic [1:0]                     legacy_dev_hresp;

   // OCP Recovery aperture decode (combinational); used to gate the
   // legacy uut's hsel.  Definition (REC_BASE_ADDR, aperture log2)
   // lives in the recovery sub-decoder block below.
   logic                           rec_addr_in_window;

   // ---- VHDL arbiter <-> SV recovery_top byte-stream wires ----
   // Declared early so the uut port-map (~line 824) sees the proper
   // vector widths and does not auto-create conflicting implicit nets.
   logic                          rec_setup_pkt_vld_w;
   logic [63:0]                   rec_setup_pkt_w;
   logic [31:0]                   rec_ctrl_out_data_w;
   logic [3:0]                    rec_ctrl_out_be_w;
   logic                          rec_ctrl_out_vld_w;
   logic                          rec_ctrl_out_last_w;
   logic                          rec_ctrl_out_rdy_w;
   logic [31:0]                   rec_ctrl_in_data_w;
   logic [3:0]                    rec_ctrl_in_be_w;
   logic                          rec_ctrl_in_vld_w;
   logic                          rec_ctrl_in_last_w;
   logic                          rec_ctrl_in_rdy_w;
   logic                          rec_ctrl_set_stall_w;
   logic                          rec_ctrl_xfer_done_w;

   // -- Host AHB (Lite converter output) --
   logic [AXI_HOST_ADDR_WIDTH-1:0] host_ahb_haddr;
   logic [2:0]                      host_ahb_hburst;
   logic [2:0]                      host_ahb_hsize;
   logic [1:0]                      host_ahb_htrans;
   logic                            host_ahb_hwrite;
   logic [AXI_DATA_WIDTH-1:0]      host_ahb_hwdata;
   logic                            host_ahb_hsel;
   logic                            host_ahb_hreadymux;
   logic [AXI_DATA_WIDTH-1:0]      host_ahb_hrdata;
   logic                            host_ahb_hreadyout;
   logic [1:0]                      host_ahb_hresp;

   // -- DMA AHB (Full converter output) --
   logic [AXI_DMA_ADDR_WIDTH-1:0]  dma_ahb_haddr;
   logic [2:0]                      dma_ahb_hburst;
   logic [2:0]                      dma_ahb_hsize;
   logic [1:0]                      dma_ahb_htrans;
   logic                            dma_ahb_hwrite;
   logic [AXI_DATA_WIDTH-1:0]      dma_ahb_hwdata;
   logic                            dma_ahb_hsel;
   logic                            dma_ahb_hreadymux;
   logic [AXI_DATA_WIDTH-1:0]      dma_ahb_hrdata;
   logic                            dma_ahb_hreadyout;
   logic [1:0]                      dma_ahb_hresp;

   // ================================================================
   // AXI Interface instances (wired to discrete ports)
   // ================================================================

   axi_if #(
       .AW(AXI_DEV_ADDR_WIDTH),
       .DW(AXI_DATA_WIDTH),
       .IW(AXI_ID_WIDTH),
       .UW(AXI_USER_WIDTH)
   ) dev_axi_if (.clk(dev_axi_aclk), .rst_n(dev_axi_aresetn));

   // Connect dev AXI discrete ports -> interface signals
   assign dev_axi_if.araddr   = dev_axi_araddr;
   assign dev_axi_if.arburst  = dev_axi_arburst;
   assign dev_axi_if.arsize   = dev_axi_arsize;
   assign dev_axi_if.arlen    = dev_axi_arlen;
   assign dev_axi_if.aruser   = dev_axi_aruser;
   assign dev_axi_if.arid     = dev_axi_arid;
   assign dev_axi_if.arlock   = dev_axi_arlock;
   assign dev_axi_if.arcache  = dev_axi_arcache;
   assign dev_axi_if.arprot   = dev_axi_arprot;
   assign dev_axi_if.arqos    = dev_axi_arqos;
   assign dev_axi_if.arregion = dev_axi_arregion;
   assign dev_axi_if.arvalid  = dev_axi_arvalid;
   assign dev_axi_arready     = dev_axi_if.arready;
   assign dev_axi_rdata       = dev_axi_if.rdata;
   assign dev_axi_rresp       = dev_axi_if.rresp;
   assign dev_axi_rid         = dev_axi_if.rid;
   assign dev_axi_ruser       = dev_axi_if.ruser;
   assign dev_axi_rlast       = dev_axi_if.rlast;
   assign dev_axi_rvalid      = dev_axi_if.rvalid;
   assign dev_axi_if.rready   = dev_axi_rready;
   assign dev_axi_if.awaddr   = dev_axi_awaddr;
   assign dev_axi_if.awburst  = dev_axi_awburst;
   assign dev_axi_if.awsize   = dev_axi_awsize;
   assign dev_axi_if.awlen    = dev_axi_awlen;
   assign dev_axi_if.awuser   = dev_axi_awuser;
   assign dev_axi_if.awid     = dev_axi_awid;
   assign dev_axi_if.awlock   = dev_axi_awlock;
   assign dev_axi_if.awcache  = dev_axi_awcache;
   assign dev_axi_if.awprot   = dev_axi_awprot;
   assign dev_axi_if.awqos    = dev_axi_awqos;
   assign dev_axi_if.awregion = dev_axi_awregion;
   assign dev_axi_if.awvalid  = dev_axi_awvalid;
   assign dev_axi_awready     = dev_axi_if.awready;
   assign dev_axi_if.wdata    = dev_axi_wdata;
   assign dev_axi_if.wstrb    = dev_axi_wstrb;
   assign dev_axi_if.wuser    = dev_axi_wuser;
   assign dev_axi_if.wvalid   = dev_axi_wvalid;
   assign dev_axi_wready      = dev_axi_if.wready;
   assign dev_axi_if.wlast    = dev_axi_wlast;
   assign dev_axi_bresp       = dev_axi_if.bresp;
   assign dev_axi_bid         = dev_axi_if.bid;
   assign dev_axi_buser       = dev_axi_if.buser;
   assign dev_axi_bvalid      = dev_axi_if.bvalid;
   assign dev_axi_if.bready   = dev_axi_bready;

   axi_if #(
       .AW(AXI_HOST_ADDR_WIDTH),
       .DW(AXI_DATA_WIDTH),
       .IW(AXI_ID_WIDTH),
       .UW(AXI_USER_WIDTH)
   ) host_axi_if (.clk(host_axi_aclk), .rst_n(host_axi_aresetn));

   // Connect host AXI discrete ports -> interface signals
   assign host_axi_if.araddr   = host_axi_araddr;
   assign host_axi_if.arburst  = host_axi_arburst;
   assign host_axi_if.arsize   = host_axi_arsize;
   assign host_axi_if.arlen    = host_axi_arlen;
   assign host_axi_if.aruser   = host_axi_aruser;
   assign host_axi_if.arid     = host_axi_arid;
   assign host_axi_if.arlock   = host_axi_arlock;
   assign host_axi_if.arcache  = host_axi_arcache;
   assign host_axi_if.arprot   = host_axi_arprot;
   assign host_axi_if.arqos    = host_axi_arqos;
   assign host_axi_if.arregion = host_axi_arregion;
   assign host_axi_if.arvalid  = host_axi_arvalid;
   assign host_axi_arready     = host_axi_if.arready;
   assign host_axi_rdata       = host_axi_if.rdata;
   assign host_axi_rresp       = host_axi_if.rresp;
   assign host_axi_rid         = host_axi_if.rid;
   assign host_axi_ruser       = host_axi_if.ruser;
   assign host_axi_rlast       = host_axi_if.rlast;
   assign host_axi_rvalid      = host_axi_if.rvalid;
   assign host_axi_if.rready   = host_axi_rready;
   assign host_axi_if.awaddr   = host_axi_awaddr;
   assign host_axi_if.awburst  = host_axi_awburst;
   assign host_axi_if.awsize   = host_axi_awsize;
   assign host_axi_if.awlen    = host_axi_awlen;
   assign host_axi_if.awuser   = host_axi_awuser;
   assign host_axi_if.awid     = host_axi_awid;
   assign host_axi_if.awlock   = host_axi_awlock;
   assign host_axi_if.awcache  = host_axi_awcache;
   assign host_axi_if.awprot   = host_axi_awprot;
   assign host_axi_if.awqos    = host_axi_awqos;
   assign host_axi_if.awregion = host_axi_awregion;
   assign host_axi_if.awvalid  = host_axi_awvalid;
   assign host_axi_awready     = host_axi_if.awready;
   assign host_axi_if.wdata    = host_axi_wdata;
   assign host_axi_if.wstrb    = host_axi_wstrb;
   assign host_axi_if.wuser    = host_axi_wuser;
   assign host_axi_if.wvalid   = host_axi_wvalid;
   assign host_axi_wready      = host_axi_if.wready;
   assign host_axi_if.wlast    = host_axi_wlast;
   assign host_axi_bresp       = host_axi_if.bresp;
   assign host_axi_bid         = host_axi_if.bid;
   assign host_axi_buser       = host_axi_if.buser;
   assign host_axi_bvalid      = host_axi_if.bvalid;
   assign host_axi_if.bready   = host_axi_bready;

   axi_if #(
       .AW(AXI_DMA_ADDR_WIDTH),
       .DW(AXI_DATA_WIDTH),
       .IW(AXI_ID_WIDTH),
       .UW(AXI_USER_WIDTH)
   ) dma_axi_if (.clk(dma_axi_aclk), .rst_n(dma_axi_aresetn));

   // Connect DMA AXI discrete ports -> interface signals
   assign dma_axi_if.araddr   = dma_axi_araddr;
   assign dma_axi_if.arburst  = dma_axi_arburst;
   assign dma_axi_if.arsize   = dma_axi_arsize;
   assign dma_axi_if.arlen    = dma_axi_arlen;
   assign dma_axi_if.aruser   = dma_axi_aruser;
   assign dma_axi_if.arid     = dma_axi_arid;
   assign dma_axi_if.arlock   = dma_axi_arlock;
   assign dma_axi_if.arcache  = dma_axi_arcache;
   assign dma_axi_if.arprot   = dma_axi_arprot;
   assign dma_axi_if.arqos    = dma_axi_arqos;
   assign dma_axi_if.arregion = dma_axi_arregion;
   assign dma_axi_if.arvalid  = dma_axi_arvalid;
   assign dma_axi_arready     = dma_axi_if.arready;
   assign dma_axi_rdata       = dma_axi_if.rdata;
   assign dma_axi_rresp       = dma_axi_if.rresp;
   assign dma_axi_rid         = dma_axi_if.rid;
   assign dma_axi_ruser       = dma_axi_if.ruser;
   assign dma_axi_rlast       = dma_axi_if.rlast;
   assign dma_axi_rvalid      = dma_axi_if.rvalid;
   assign dma_axi_if.rready   = dma_axi_rready;
   assign dma_axi_if.awaddr   = dma_axi_awaddr;
   assign dma_axi_if.awburst  = dma_axi_awburst;
   assign dma_axi_if.awsize   = dma_axi_awsize;
   assign dma_axi_if.awlen    = dma_axi_awlen;
   assign dma_axi_if.awuser   = dma_axi_awuser;
   assign dma_axi_if.awid     = dma_axi_awid;
   assign dma_axi_if.awlock   = dma_axi_awlock;
   assign dma_axi_if.awcache  = dma_axi_awcache;
   assign dma_axi_if.awprot   = dma_axi_awprot;
   assign dma_axi_if.awqos    = dma_axi_awqos;
   assign dma_axi_if.awregion = dma_axi_awregion;
   assign dma_axi_if.awvalid  = dma_axi_awvalid;
   assign dma_axi_awready     = dma_axi_if.awready;
   assign dma_axi_if.wdata    = dma_axi_wdata;
   assign dma_axi_if.wstrb    = dma_axi_wstrb;
   assign dma_axi_if.wuser    = dma_axi_wuser;
   assign dma_axi_if.wvalid   = dma_axi_wvalid;
   assign dma_axi_wready      = dma_axi_if.wready;
   assign dma_axi_if.wlast    = dma_axi_wlast;
   assign dma_axi_bresp       = dma_axi_if.bresp;
   assign dma_axi_bid         = dma_axi_if.bid;
   assign dma_axi_buser       = dma_axi_if.buser;
   assign dma_axi_bvalid      = dma_axi_if.bvalid;
   assign dma_axi_if.bready   = dma_axi_bready;

   // ================================================================
   // AXI-to-AHB Converter instances
   // ================================================================

   // -- Device (AXI4-Lite) --
   axilite_to_ahb #(
       .AW       (AXI_DEV_ADDR_WIDTH),
       .DW       (AXI_DATA_WIDTH),
       .IW       (AXI_ID_WIDTH),
       .UW       (AXI_USER_WIDTH)
   ) u_dev_axi2ahb (
       .clk           (dev_axi_aclk),
       .rst_n         (dev_axi_aresetn),
       .axi_r         (dev_axi_if),
       .axi_w         (dev_axi_if),
       .ahb_haddr     (dev_ahb_haddr),
       .ahb_hburst    (dev_ahb_hburst),
       .ahb_hsize     (dev_ahb_hsize),
       .ahb_htrans    (dev_ahb_htrans),
       .ahb_hwrite    (dev_ahb_hwrite),
       .ahb_hwdata    (dev_ahb_hwdata),
       .ahb_hsel      (dev_ahb_hsel),
       .ahb_hreadymux (dev_ahb_hreadymux),
       .ahb_hrdata    (dev_ahb_hrdata),
       .ahb_hreadyout (dev_ahb_hreadyout),
       .ahb_hresp     (dev_ahb_hresp)
   );

   // -- Host (AXI4-Lite) --
   axilite_to_ahb #(
       .AW       (AXI_HOST_ADDR_WIDTH),
       .DW       (AXI_DATA_WIDTH),
       .IW       (AXI_ID_WIDTH),
       .UW       (AXI_USER_WIDTH)
   ) u_host_axi2ahb (
       .clk           (host_axi_aclk),
       .rst_n         (host_axi_aresetn),
       .axi_r         (host_axi_if),
       .axi_w         (host_axi_if),
       .ahb_haddr     (host_ahb_haddr),
       .ahb_hburst    (host_ahb_hburst),
       .ahb_hsize     (host_ahb_hsize),
       .ahb_htrans    (host_ahb_htrans),
       .ahb_hwrite    (host_ahb_hwrite),
       .ahb_hwdata    (host_ahb_hwdata),
       .ahb_hsel      (host_ahb_hsel),
       .ahb_hreadymux (host_ahb_hreadymux),
       .ahb_hrdata    (host_ahb_hrdata),
       .ahb_hreadyout (host_ahb_hreadyout),
       .ahb_hresp     (host_ahb_hresp)
   );

   // -- DMA (Full AXI4 with burst) --
   axi_to_ahb #(
       .AW       (AXI_DMA_ADDR_WIDTH),
       .DW       (AXI_DATA_WIDTH),
       .IW       (AXI_ID_WIDTH),
       .UW       (AXI_USER_WIDTH),
       .OSTD_R   (2),
       .OSTD_W   (2)
   ) u_dma_axi2ahb (
       .clk           (dma_axi_aclk),
       .rst_n         (dma_axi_aresetn),
       .axi_r         (dma_axi_if),
       .axi_w         (dma_axi_if),
       .ahb_haddr     (dma_ahb_haddr),
       .ahb_hburst    (dma_ahb_hburst),
       .ahb_hsize     (dma_ahb_hsize),
       .ahb_htrans    (dma_ahb_htrans),
       .ahb_hwrite    (dma_ahb_hwrite),
       .ahb_hwdata    (dma_ahb_hwdata),
       .ahb_hsel      (dma_ahb_hsel),
       .ahb_hreadymux (dma_ahb_hreadymux),
       .ahb_hrdata    (dma_ahb_hrdata),
       .ahb_hreadyout (dma_ahb_hreadyout),
       .ahb_hresp     (dma_ahb_hresp)
   );

   // ================================================================
   // USB IP Core instance
   // ================================================================

   ip_xxx_3516_hs_mem #(
      .AHB_DATAWIDTH(32),
      .RAM_DATAWIDTH(64),
      .RAM_ADDRWIDTH(RAM_ADDRWIDTH),
      .C_NBPHYSEP(C_NBPHYSEP),
      .C_EPUB(C_EPUB),
      .C_DAUB(C_DAUB),
      .C_DALB(C_DALB),
      .C_PORTPOWER_CONTROL(1),
      .C_PORTINDICATOR(1),
      .C_EPFIFO_PAGE(C_EPFIFO_PAGE),
      .C_DATAFIFO_PAGE(C_DATAFIFO_PAGE),
      .C_SINGLE_BUFFER_SUPPORTED(C_SINGLE_BUFFER_SUPPORTED),
      .C_DOUBLE_BUFFER_SUPPORTED(C_DOUBLE_BUFFER_SUPPORTED),
      .C_TOGGLE_REG_READABLE(C_TOGGLE_REG_READABLE),
      .C_PLL_ENABLE(0),
      .C_PLL_DIVIDER(7'b0010100),
      .C_ULPI_SUPPORT(0),
      .C_UTMI_SUPPORT(1),
      .C_EXTEND_TX_DELAY(1),
      .G_SIM_CHIRP_TIMERS(G_SIM_CHIRP_TIMERS)
   ) uut (
               // Device AHB -- from Lite converter.  hsel is qualified
               // by ~rec_addr_in_window so the legacy IP only sees beats
               // *outside* the OCP Recovery aperture (C1 disjoint
               // decode).  Response nets feed legacy_dev_* and are
               // muxed with the recovery sub-decoder below.
               .dev_ahbs_hresetn  (dev_axi_aresetn),
               .dev_ahbs_hclk     (dev_axi_aclk),
               .dev_ahbs_haddr    (dev_ahb_haddr[5:2]),
               .dev_ahbs_htrans   (dev_ahb_htrans),
               .dev_ahbs_hwrite   (dev_ahb_hwrite),
               .dev_ahbs_hwdata   (dev_ahb_hwdata),
               .dev_ahbs_hsel     (dev_ahb_hsel & ~rec_addr_in_window),
               .dev_ahbs_hreadyin (dev_ahb_hreadymux),
               .dev_ahbs_hrdata   (legacy_dev_hrdata),
               .dev_ahbs_hreadyout(legacy_dev_hreadyout),
               .dev_ahbs_hresp    (legacy_dev_hresp),

               // Host AHB -- from Lite converter
               .host_ahbs_hresetn  (host_axi_aresetn),
               .host_ahbs_hclk     (host_axi_aclk),
               .host_ahbs_haddr    (host_ahb_haddr[6:2]),
               .host_ahbs_htrans   (host_ahb_htrans),
               .host_ahbs_hwrite   (host_ahb_hwrite),
               .host_ahbs_hwdata   (host_ahb_hwdata),
               .host_ahbs_hsel     (host_ahb_hsel),
               .host_ahbs_hreadyin (host_ahb_hreadymux),
               .host_ahbs_hrdata   (host_ahb_hrdata),
               .host_ahbs_hreadyout(host_ahb_hreadyout),
               .host_ahbs_hresp    (host_ahb_hresp),

               // DMA AHB -- from Full converter
               .ahbs_dma_hresetn  (dma_axi_aresetn),
               .ahbs_dma_hclk     (dma_axi_aclk),
               .ahbs_dma_haddr    (dma_ahb_haddr[RAM_ADDRWIDTH-1+5:0]),
               .ahbs_dma_htrans   (dma_ahb_htrans),
               .ahbs_dma_hwrite   (dma_ahb_hwrite),
               .ahbs_dma_hwdata   (dma_ahb_hwdata),
               .ahbs_dma_hsel     (dma_ahb_hsel),
               .ahbs_dma_hreadyin (dma_ahb_hreadymux),
               .ahbs_dma_hrdata   (dma_ahb_hrdata),
               .ahbs_dma_hreadyout(dma_ahb_hreadyout),
               .ahbs_dma_hresp    (dma_ahb_hresp),
               .ahbs_dma_hsize    (dma_ahb_hsize),
               .ahbs_dma_hburst   (dma_ahb_hburst),

               // Memory interface
               .mem_q(mem_q),
               .mem_d(mem_d),
               .mem_cs(mem_cs),
               .mem_a(mem_a),
               .mem_web_out(mem_web_out),
               .mem_bsel(mem_bsel),

               // Interrupts and USB signals
               .dev_usb_int_req_irq(dev_usb_int_req_irq),
               .dev_usb_Int_req_fiq(dev_usb_Int_req_fiq),
               .dev_usbframetoggle(dev_usbframetoggle),
               .host_usb_int_req_irq(host_usb_int_req_irq),
               .USB_VBus(USB_VBus),
               .vbuscomp_on(vbuscomp_on),
               .chrgvbus(chrgvbus),
               .dischrgvbus(dischrgvbus),
               .avalid(avalid),
               .sessend(sessend),

               // UTMI
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
               .utmi_hostdisconnect(utmi_hostdisconnect),
               .utmi_id_enable(utmi_id_enable),
               .utmi_id_value(utmi_id_value),
               .utmi_dppulldown(utmi_dppulldown),
               .utmi_dmpulldown(utmi_dmpulldown),
               .pdcom(pdcom),

               // ULPI
               .ulpi_clk(ulpi_clk),
               .ulpi_rxdata(ulpi_rxdata),
               .ulpi_txdata(ulpi_txdata),
               .ulpi_txenable(ulpi_txenable),
               .ulpi_dir(ulpi_dir),
               .ulpi_stp(ulpi_stp),
               .ulpi_nxt(ulpi_nxt),
               .ulpi_ddr_sel(ulpi_ddr_sel),

               // Misc
               .dev_usb_needclk(dev_usb_needclk),
               .host_usb_needclk(host_usb_needclk),
               .dev_sys_donotwakeup_n(dev_sys_donotwakeup_n),
               .host_sys_donotwakeup_n(host_sys_donotwakeup_n),
               .dev_sys_wakeup_n(dev_sys_wakeup_n),
               .dev_sys_utmi_clkin_lock(dev_sys_utmi_clkin_lock),
               .host_sys_utmi_clkin_lock(host_sys_utmi_clkin_lock),
               .host_usb_overcurrent_n(host_usb_overcurrent_n),
               .host_usb_portindicator(host_usb_portindicator),
               .host_usb_portpower(host_usb_portpower),
               .token_length_counter(token_length_counter),
               .usb_token_length(usb_token_length),

               // Constant tie-offs -- USB protocol timing parameters
               // Values from original NXP constants in usb_host_pie.m.vhdl and
               // usb_pie.m.vhdl. All timing values are in 60 MHz UTMI clock cycles.

               // Host PIE inter-packet delays (USB 2.0 Sec 7.1.18)
               .usb_host_pie_INTER_PACKET_DELAY_LS_param(8'd80),   // 2 LS bit times
               .usb_host_pie_INTER_PACKET_DELAY_FS_param(8'd10),   // 2 FS bit times
               .usb_host_pie_INTER_PACKET_DELAY_HS_param(8'd12),   // 96 HS bit times (min 88)
               // Host PIE packet turnaround timeouts (USB 2.0 Sec 7.1.18, Sec 8.7.2)
               .usb_host_pie_PACKET_TURNAROUND_TIMEOUT_LS_param(11'd1380),
               .usb_host_pie_PACKET_TURNAROUND_TIMEOUT_FS_param(8'd204),
               .usb_host_pie_PACKET_TURNAROUND_TIMEOUT_HS_param(8'd162),
               // Host PIE packet event timeouts (state machine safety net)
               .usb_host_pie_PACKET_EVENT_TIMEOUT_LS_param(13'd2048),
               .usb_host_pie_PACKET_EVENT_TIMEOUT_FS_param(9'd256),
               .usb_host_pie_PACKET_EVENT_TIMEOUT_HS_param(9'd256),
               // Host PIE L1/L2 suspend: 0 = use synchronized signal (ASIC-safe)
               .usb_host_pie_portl1l2suspend_use_sync_n(1'b0),
               // Device PIE inter-packet delays
               .usb_pie_INTER_PACKET_DELAY_FS_param(5'd10),   // 2 FS bit times
               .usb_pie_INTER_PACKET_DELAY_HS_param(5'd2),    // min HS inter-packet gap
               // Device PIE turnaround & event timeouts
               .usb_pie_PACKET_TURNAROUND_TIMEOUT_FS_param(8'd204),
               .usb_pie_PACKET_TURNAROUND_TIMEOUT_HS_param(8'd162),
               .usb_pie_PACKET_EVENT_TIMEOUT_FS_param(9'd256),
               .usb_pie_PACKET_EVENT_TIMEOUT_HS_param(9'd256),

               // OCP Recovery v1.1 Section 8.5 arbiter byte-stream surface.
               // Drives / driven by usb_ocp_recovery_top via the VHDL
               // usb_pie_recovery_arb spliced inside ip_xxx_3511_hs.
               .rec_setup_pkt_vld   (rec_setup_pkt_vld_w),
               .rec_setup_pkt       (rec_setup_pkt_w),
               .rec_ctrl_out_data   (rec_ctrl_out_data_w),
               .rec_ctrl_out_be    (rec_ctrl_out_be_w),
               .rec_ctrl_out_vld    (rec_ctrl_out_vld_w),
               .rec_ctrl_out_last   (rec_ctrl_out_last_w),
               .rec_ctrl_out_rdy    (rec_ctrl_out_rdy_w),
               .rec_ctrl_in_data    (rec_ctrl_in_data_w),
               .rec_ctrl_in_be      (rec_ctrl_in_be_w),
               .rec_ctrl_in_vld     (rec_ctrl_in_vld_w),
               .rec_ctrl_in_last    (rec_ctrl_in_last_w),
               .rec_ctrl_in_rdy     (rec_ctrl_in_rdy_w),
               .rec_ctrl_set_stall  (rec_ctrl_set_stall_w),
               .rec_ctrl_xfer_done  (rec_ctrl_xfer_done_w),
               .rec_ctrl_claim      (),

               // DFT: must be 0 for functional operation
               .async_disable(1'b0),
               .testmode(1'b0)
   );

   // ================================================================
   // OCP Recovery v1.1 subsystem (A6: usb_ocp_recovery_top)
   // ----------------------------------------------------------------
   // Phase 1c integration:
   //   - PIE side: byte-stream surface (rec_*) flows out of the VHDL
   //     arbiter (usb_pie_recovery_arb) inside ip_xxx_3511_hs.
   //   - Management side: AHB sub-decoder below taps the existing
   //     dev_ahb_* output of axilite_to_ahb.sv and converts AHB beats
   //     addressed to SOC_USB_OCP_RECOVERY_REG_BASE_ADDR into single-byte
   //     reg-bus transactions (ext_rb_*).  AXI4-Lite alt-master removed.
   //   - CMS SRAM, sideband, and prot_cap/device_id straps unchanged.
   // ================================================================

   // ---- VHDL arbiter <-> SV recovery_top byte-stream wires ----
   // (Declared at the top of the module so the uut port-map sees the
   // proper vector widths; see decls near line 387.)

   // ---- Recovery subsystem reset (active-high, in pie_clk domain). ----
   // Move the recovery_top to the pie_clk (utmi_clk) domain so the PIE
   // arbiter byte-stream surface (rec_*) is in its native clock and
   // requires no CDC.  The AHB management surface is handled by a
   // dedicated narrow CDC bridge below (C3).
   // Synchronize the AXI subordinate reset (which is sourced from the
   // dev_axi_aclk domain) into utmi_clk before deasserting.  This is a
   // simple 2-flop synchronizer (no caliptra_prim dependency to avoid
   // a cross-tree include).  Assertion is asynchronous.
   logic rec_rst;
   logic rec_rst_pie_meta_q;
   logic rec_rst_pie_q;
   always_ff @(posedge utmi_clk or negedge dev_axi_aresetn) begin
     if (!dev_axi_aresetn) begin
       rec_rst_pie_meta_q <= 1'b1;
       rec_rst_pie_q      <= 1'b1;
     end else begin
       rec_rst_pie_meta_q <= 1'b0;
       rec_rst_pie_q      <= rec_rst_pie_meta_q;
     end
   end
   assign rec_rst = rec_rst_pie_q;

   // ==================================================================
   // OCP Recovery AHB sub-decoder + CDC bridge (review fixes C1..C4,C7,
   // C8, M2).
   //
   // Address aperture
   // ----------------
   //   Base : SOC_USB_OCP_RECOVERY_REG_BASE_ADDR = 0x2000_2000
   //   Size : 4 KiB (REC_APERTURE_LOG2 = 12)
   //   - Matches the SoC address map (next slot, I3CCSR, begins at
   //     0x2000_4000, leaving an 8 KiB gap; we use 4 KiB to leave
   //     symmetric margin and to fit a clean per-command 256 B page).
   //
   // In-aperture decode
   // ------------------
   //   haddr[11:8] = OCP command nibble; the full command byte presented
   //                 to the reg-bus is { 4'h2, haddr[11:8] }.  This
   //                 covers commands 0x20..0x2F (only 0x22..0x2F are
   //                 valid per OCP Recovery v1.1 Section 9.2 Table 9-2;
   //                 invalid codes are returned as rb_err).
   //   haddr[7:0]  = byte offset within the command payload.  Max OCP
   //                 record is INDIRECT_FIFO_DATA at 252 B (Tbl 9-12),
   //                 so 256 B/cmd is sufficient.
   //   hwdata[7:0] = reg-bus write byte (upper bytes ignored).
   //   hrdata      = { 24'h0, rb_rdata } (lower byte only).
   //
   // hsel qualification (C1)
   // -----------------------
   //   uut.dev_ahbs_hsel is driven by (dev_ahb_hsel & ~rec_addr_in_window)
   //   so the legacy 256 B endpoint register file inside the VHDL IP
   //   only sees beats outside the recovery aperture; the recovery
   //   sub-decoder owns beats inside it.  This prevents the two
   //   sub-decoders from both responding to the same beat.
   //
   // CDC (C3)
   // --------
   //   dev_axi_aclk (caliptra_ss_clk) is asynchronous to utmi_clk
   //   (60 MHz PHY clock).  recovery_top lives in utmi_clk to be in
   //   the same domain as the PIE arbiter, so the AHB beat must cross
   //   from dev_axi_aclk into utmi_clk and back.  Narrow 4-phase
   //   level/ack handshake:
   //     axi  : req_axi_q   --> 2-FF sync into utmi --> req_pie_sync
   //     pie  : ack_pie_q   --> 2-FF sync into axi  --> ack_axi_sync
   //   Payload (cmd/off/wr/wdata) is captured in axi_clk before req
   //   goes high and remains stable for the duration of the handshake
   //   so it can be sampled in utmi_clk without further CDC.  Read
   //   data is captured in utmi_clk when ack rises and held until
   //   req drops.
   //
   // Pulse semantics (C2/C7)
   // -----------------------
   //   The PIE-side FSM holds ext_rb_wr / ext_rb_rd high until it
   //   observes ext_rb_ack from the arbiter.  This is safe because
   //   usb_ocp_recovery_top now gates EXT grants behind ext_in_flight_q
   //   so a held wr/rd does not re-fire pulse strobes.
   //
   // Response mux
   // ------------
   //   When the recovery sub-decoder owns the beat (rec_ahb_owns_q),
   //   dev_ahb_hreadyout/hrdata/hresp are driven by the bridge.
   //   Otherwise they pass through legacy_dev_*.
   // ==================================================================
   localparam int          REC_APERTURE_LOG2 = 12;
   localparam logic [31:0] REC_BASE_ADDR     = 32'h2000_2000;

   // -- Aperture decode (combinational, dev_axi_aclk domain) --
   // The aaxi4_interconnect routes both the legacy device aperture
   // (0x20000000-0x20000FFF) and the OCP recovery aperture
   // (0x20002000-0x20002FFF) to the same USB DEV subordinate. Depending
   // on whether the interconnect strips the slot base address or passes
   // the absolute SoC address, dev_ahb_haddr for an OCP recovery access
   // arrives as either 0x20002xxx (absolute) or 0x00002xxx (stripped).
   // Detect on bits[13:12]==2'b10 which uniquely matches the OCP
   // recovery 4 KiB aperture in either case (legacy aperture has
   // bits[13:12]==2'b00 in both views).
   // (rec_addr_in_window declared at the top of the module so it is
   //  visible to the uut hsel gate above.)
   assign rec_addr_in_window = (dev_ahb_haddr[13:12] == 2'b10);

   // -- AHB address-phase strobe to capture in IDLE --
   logic rec_ahb_addr_phase;
   assign rec_ahb_addr_phase = dev_ahb_hsel
                             & dev_ahb_htrans[1]
                             & dev_ahb_hreadymux
                             & rec_addr_in_window;

   // -- Captured beat metadata (dev_axi_aclk domain, stable across CDC) --
   logic [7:0]  ahb_cmd_q;
   logic [7:0]  ahb_off_q;
   logic        ahb_wr_q;
   logic [31:0] ahb_wdata_q;

   // -- AXI-side AHB FSM --
   typedef enum logic [2:0] {
     A_IDLE      = 3'd0,  // wait for address phase in our window
     A_DATA      = 3'd1,  // capture hwdata (writes), assert req
     A_AWAIT_ACK = 3'd2,  // wait for ack to come back through sync
     A_COMPLETE  = 3'd3,  // drive hreadyout=1 for one cycle
     A_COOLDOWN  = 3'd4   // hold req=0 until ack_sync drops
   } a_state_e;
   a_state_e a_state_q, a_state_d;

   // CDC: dev_axi_aclk -> utmi_clk request, utmi_clk -> dev_axi_aclk ack.
   logic        req_axi_q;        // level, axi clk
   logic        req_pie_meta_q;   // 2FF sync into pie
   logic        req_pie_sync_q;
   logic        ack_pie_q;        // level, pie clk
   logic        ack_axi_meta_q;   // 2FF sync into axi
   logic        ack_axi_sync_q;

   // Read data captured in pie clk, sampled in axi clk after ack handshake.
   logic [31:0] rdata_pie_q;
   logic        err_pie_q;
   logic [31:0] rdata_axi_q;
   logic        err_axi_q;

   // -- AXI clk: FSM and metadata capture --
   always_comb begin
     a_state_d = a_state_q;
     unique case (a_state_q)
       A_IDLE:      if (rec_ahb_addr_phase)              a_state_d = A_DATA;
       A_DATA:                                            a_state_d = A_AWAIT_ACK;
       A_AWAIT_ACK: if (ack_axi_sync_q)                  a_state_d = A_COMPLETE;
       A_COMPLETE:                                        a_state_d = A_COOLDOWN;
       A_COOLDOWN:  if (!ack_axi_sync_q)                 a_state_d = A_IDLE;
       default:                                           a_state_d = A_IDLE;
     endcase
   end

   always_ff @(posedge dev_axi_aclk or negedge dev_axi_aresetn) begin
     if (!dev_axi_aresetn) begin
       a_state_q   <= A_IDLE;
       ahb_cmd_q   <= '0;
       ahb_off_q   <= '0;
       ahb_wr_q    <= 1'b0;
       ahb_wdata_q <= '0;
       req_axi_q   <= 1'b0;
       ack_axi_meta_q <= 1'b0;
       ack_axi_sync_q <= 1'b0;
       rdata_axi_q <= '0;
       err_axi_q   <= 1'b0;
     end else begin
       // 2FF sync for ack returning from pie clk
       ack_axi_meta_q <= ack_pie_q;
       ack_axi_sync_q <= ack_axi_meta_q;

       a_state_q <= a_state_d;

       // Capture cmd/off/wr at address phase (state IDLE on the edge of
       // rec_ahb_addr_phase).  Maps the flat 4 KiB byte aperture layout
       // (matches usb_ocp_recovery_rb_adapter.sv cmd_base LUT and the
       // PeakRDL-generated soc_address_map.h SOC_USB_OCP_RECOVERY_REG_*
       // per-register addresses) into the byte-wide rb_* (cmd, offset)
       // pair the adapter expects. PROT_CAP@0x000, DEVICE_ID@0x010,
       // DEVICE_STATUS@0x028, DEVICE_RESET@0x068, RECOVERY_CTRL@0x06C,
       // RECOVERY_STATUS@0x070, HW_STATUS@0x074, INDIRECT_CTRL@0x078,
       // INDIRECT_STATUS@0x080, INDIRECT_DATA@0x088, INDIRECT_FIFO_CTRL@0x184,
       // INDIRECT_FIFO_STATUS@0x18C, INDIRECT_FIFO_DATA@0x1A0, VENDOR@0x1A4.
       if (a_state_q == A_IDLE && rec_ahb_addr_phase) begin
         casez (dev_ahb_haddr[11:0])
           12'h00?:                  begin ahb_cmd_q <= 8'h22; ahb_off_q <= dev_ahb_haddr[3:0]; end // PROT_CAP 0x000-0x00F
           12'h01?, 12'h02?:         // DEVICE_ID 0x010-0x027 (24 B)
             if (dev_ahb_haddr[11:0] < 12'h028) begin
               ahb_cmd_q <= 8'h23;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h10;
             end else begin
               ahb_cmd_q <= 8'h24;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h28;
             end
           12'h03?, 12'h04?, 12'h05?, 12'h06?: // DEVICE_STATUS 0x028-0x067 plus DEVICE_RESET 0x068-0x06A and RECOVERY_CTRL 0x06C-0x06E
             if (dev_ahb_haddr[11:0] < 12'h068) begin
               ahb_cmd_q <= 8'h24;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h28;
             end else if (dev_ahb_haddr[11:0] < 12'h06C) begin
               ahb_cmd_q <= 8'h25;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h68;
             end else begin
               ahb_cmd_q <= 8'h26;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h6C;
             end
           12'h07?: // RECOVERY_STATUS 0x070-0x071, HW_STATUS 0x074-0x077, INDIRECT_CTRL 0x078-0x07D
             if (dev_ahb_haddr[3:0] < 4'h4) begin
               ahb_cmd_q <= 8'h27;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h70;
             end else if (dev_ahb_haddr[3:0] < 4'h8) begin
               ahb_cmd_q <= 8'h28;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h74;
             end else begin
               ahb_cmd_q <= 8'h29;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h78;
             end
           12'h08?: // INDIRECT_STATUS 0x080-0x087 (cmd 0x2A) or INDIRECT_DATA 0x088+ (cmd 0x2B)
             if (dev_ahb_haddr[3:0] < 4'h8) begin
               ahb_cmd_q <= 8'h2A;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h80;
             end else begin
               ahb_cmd_q <= 8'h2B;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h88;
             end
           12'h09?, 12'h0A?, 12'h0B?, 12'h0C?, 12'h0D?, 12'h0E?, 12'h0F?: // INDIRECT_DATA continuation
             begin
               ahb_cmd_q <= 8'h2B;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h88;
             end
           12'h1??: // 0x100-0x183 INDIRECT_DATA cont. (cmd 0x2B), 0x184-0x18B INDIRECT_FIFO_CTRL (cmd 0x2C), 0x18C-0x19F INDIRECT_FIFO_STATUS (cmd 0x2D), 0x1A0-0x1A3 INDIRECT_FIFO_DATA (cmd 0x2E), 0x1A4-0x1A7 VENDOR (cmd 0x2F)
             if (dev_ahb_haddr[11:0] < 12'h184) begin
               ahb_cmd_q <= 8'h2B;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h88;
             end else if (dev_ahb_haddr[11:0] < 12'h18C) begin
               ahb_cmd_q <= 8'h2C;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h84;
             end else if (dev_ahb_haddr[11:0] < 12'h1A0) begin
               ahb_cmd_q <= 8'h2D;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'h8C;
             end else if (dev_ahb_haddr[11:0] < 12'h1A4) begin
               ahb_cmd_q <= 8'h2E;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'hA0;
             end else if (dev_ahb_haddr[11:0] < 12'h1A8) begin
               ahb_cmd_q <= 8'h2F;
               ahb_off_q <= dev_ahb_haddr[7:0] - 8'hA4;
             end else begin
               // Out-of-range above VENDOR: forward an invalid cmd so the
               // adapter raises rb_err_q (which now also raises rb_ack_q
               // to avoid bus hang).
               ahb_cmd_q <= 8'h00;
               ahb_off_q <= 8'h00;
             end
           default: begin
             // Out-of-range below valid record set: invalid cmd.
             ahb_cmd_q <= 8'h00;
             ahb_off_q <= 8'h00;
           end
         endcase
         ahb_wr_q    <= dev_ahb_hwrite;
       end
       // hwdata is on the bus during the AHB data phase (one cycle
       // after address phase, when this FSM is in A_DATA).
       if (a_state_q == A_DATA && ahb_wr_q) begin
         ahb_wdata_q <= dev_ahb_hwdata[31:0];
       end

       // req level: raise from A_DATA onwards, drop at A_COMPLETE.
       if (a_state_q == A_DATA)                          req_axi_q <= 1'b1;
       else if (a_state_q == A_COMPLETE)                 req_axi_q <= 1'b0;

       // Capture response when ack first observed (axi clk).
       if (a_state_q == A_AWAIT_ACK && ack_axi_sync_q) begin
         rdata_axi_q <= rdata_pie_q;
         err_axi_q   <= err_pie_q;
       end
     end
   end

   // -- PIE clk: 2FF sync for req, PIE FSM that drives ext_rb_* --
   logic        rec_ext_rb_wr;
   logic        rec_ext_rb_rd;
   logic [31:0] rec_ext_rb_rdata;
   logic        rec_ext_rb_ack;
   logic        rec_ext_rb_err;

   typedef enum logic [1:0] {
     P_IDLE    = 2'd0,
     P_PRESENT = 2'd1,  // hold wr/rd high awaiting ext_rb_ack
     P_DONE    = 2'd2   // ack received, hold ack_pie high awaiting req drop
   } p_state_e;
   p_state_e p_state_q, p_state_d;

   always_comb begin
     p_state_d = p_state_q;
     unique case (p_state_q)
       P_IDLE:    if (req_pie_sync_q)  p_state_d = P_PRESENT;
       P_PRESENT: if (rec_ext_rb_ack)  p_state_d = P_DONE;
       P_DONE:    if (!req_pie_sync_q) p_state_d = P_IDLE;
       default:                         p_state_d = P_IDLE;
     endcase
   end

   always_ff @(posedge utmi_clk or posedge rec_rst) begin
     if (rec_rst) begin
       p_state_q      <= P_IDLE;
       req_pie_meta_q <= 1'b0;
       req_pie_sync_q <= 1'b0;
       ack_pie_q      <= 1'b0;
       rdata_pie_q    <= '0;
       err_pie_q      <= 1'b0;
     end else begin
       // 2FF sync for req coming from axi clk
       req_pie_meta_q <= req_axi_q;
       req_pie_sync_q <= req_pie_meta_q;

       p_state_q <= p_state_d;

       // Capture rdata/err the cycle ext_rb_ack fires (in P_PRESENT).
       if (p_state_q == P_PRESENT && rec_ext_rb_ack) begin
         rdata_pie_q <= rec_ext_rb_rdata;
         err_pie_q   <= rec_ext_rb_err;
       end

       // Raise ack_pie when entering P_DONE, hold until P_IDLE.
       if (p_state_d == P_DONE) ack_pie_q <= 1'b1;
       else if (p_state_d == P_IDLE) ack_pie_q <= 1'b0;
     end
   end

   // PIE-side reg-bus drive: wr/rd held high through P_PRESENT.  The
   // arbiter's ext_in_flight_q gate (in usb_ocp_recovery_top) ensures
   // the held-level does not re-fire pulse strobes if the grant
   // doesn't happen on the first cycle.
   assign rec_ext_rb_wr = (p_state_q == P_PRESENT) &&  ahb_wr_q;
   assign rec_ext_rb_rd = (p_state_q == P_PRESENT) && !ahb_wr_q;

   // -- AHB response mux --
   // rec_ahb_owns_q follows a_state_q != A_IDLE so the AHB master sees
   // a stalled hreadyout during the entire recovery transaction window
   // and a 1-cycle hreadyout=1 in A_COMPLETE.
   logic rec_ahb_owns_now;
   assign rec_ahb_owns_now = (a_state_q != A_IDLE);

   // hreadyout: 1 in A_COMPLETE (final beat completes), 0 otherwise
   // when we own the beat.  Outside our window, pass legacy through.
   assign dev_ahb_hreadyout = rec_ahb_owns_now
                            ? (a_state_q == A_COMPLETE)
                            : legacy_dev_hreadyout;
   assign dev_ahb_hrdata    = rec_ahb_owns_now
                            ? rdata_axi_q[31:0]
                            : legacy_dev_hrdata;
   assign dev_ahb_hresp     = rec_ahb_owns_now
                            ? { 1'b0, err_axi_q }
                            : legacy_dev_hresp;

   // SVA: legacy IP must NOT respond when we own the beat.
   // pragma translate_off
   property p_legacy_silent_when_rec_owns;
     @(posedge dev_axi_aclk) disable iff (!dev_axi_aresetn)
       rec_ahb_owns_now |-> (legacy_dev_hreadyout === 1'b1);
   endproperty
   // (legacy_dev_hreadyout stays high when uut's hsel is gated off.)
   assert property (p_legacy_silent_when_rec_owns)
     else $error("rec/legacy AHB sub-decoder collision");
   // pragma translate_on


   usb_ocp_recovery_top #(
       .CMS_ADDR_W        (REC_CMS_ADDR_W),
       .NUM_CMS           (REC_NUM_CMS)
   ) u_ocp_recovery (
       // Now in pie_clk (utmi_clk) domain (review fix C3).  Reset is
       // 2FF-synced to this clock above (rec_rst).  Sideband and CMS
       // ports cross to the SoC and must be sync'd on the consumer side
       // (was previously dev_axi_aclk; see residual risk note in the
       // combined fixes report).
       .clk  (utmi_clk),
       .rst  (rec_rst),

       // PIE byte-stream surface (driven by VHDL usb_pie_recovery_arb)
       .rec_setup_pkt_vld  (rec_setup_pkt_vld_w),
       .rec_setup_pkt      (rec_setup_pkt_w),
       .rec_ctrl_out_data  (rec_ctrl_out_data_w),
       .rec_ctrl_out_be   (rec_ctrl_out_be_w),
       .rec_ctrl_out_vld   (rec_ctrl_out_vld_w),
       .rec_ctrl_out_last  (rec_ctrl_out_last_w),
       .rec_ctrl_out_rdy   (rec_ctrl_out_rdy_w),
       .rec_ctrl_in_data   (rec_ctrl_in_data_w),
       .rec_ctrl_in_be     (rec_ctrl_in_be_w),
       .rec_ctrl_in_vld    (rec_ctrl_in_vld_w),
       .rec_ctrl_in_last   (rec_ctrl_in_last_w),
       .rec_ctrl_in_rdy    (rec_ctrl_in_rdy_w),
       .rec_ctrl_set_stall (rec_ctrl_set_stall_w),
       .rec_ctrl_xfer_done (rec_ctrl_xfer_done_w),

       // External reg-bus slave -- driven by the PIE-side bridge above.
       // cmd/offset/wdata are stable across the CDC handshake, so they
       // can be fed straight in from the axi-clk capture flops.
       .ext_rb_cmd     (ahb_cmd_q),
       .ext_rb_offset  ({8'h00, ahb_off_q}),
       .ext_rb_wr      (rec_ext_rb_wr),
       .ext_rb_rd      (rec_ext_rb_rd),
       .ext_rb_wdata   (ahb_wdata_q),
       .ext_rb_rdata   (rec_ext_rb_rdata),
       .ext_rb_ack     (rec_ext_rb_ack),
       .ext_rb_err     (rec_ext_rb_err),

       // CMS external SRAM passthrough
       .cms_addr  (cms_addr),
       .cms_wr    (cms_wr),
       .cms_rd    (cms_rd),
       .cms_wdata (cms_wdata),
       .cms_rdata (cms_rdata),

       // Static capability tie-offs (from parameters)
       .prot_cap_in  (REC_PROT_CAP_DEFAULT),
       .device_id_in (REC_DEVICE_ID_DEFAULT),

       // Sideband
       .rec_trigger      (rec_trigger),
       .soc_boot_ack     (soc_boot_ack),
       .recovery_active  (rec_active),
       .image_ready      (image_ready),
       .boot_req         (boot_req),
       .device_reset_req (device_reset_req),
       .fatal_err        (fatal_err)
   );

   // Legacy top-level status pins: summary view of the recovery FSM.
   assign ocp_recovery_available = rec_active;
   assign ocp_firmware_activated = image_ready;

endmodule

