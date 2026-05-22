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
  parameter        G_SIM_CHIRP_TIMERS = 0
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
				   output [6:0] 	       usb_token_length
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

   // Connect dev AXI discrete ports → interface signals
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

   // Connect host AXI discrete ports → interface signals
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

   // Connect DMA AXI discrete ports → interface signals
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
               // Device AHB — from Lite converter
               .dev_ahbs_hresetn  (dev_axi_aresetn),
               .dev_ahbs_hclk     (dev_axi_aclk),
               .dev_ahbs_haddr    (dev_ahb_haddr[5:2]),
               .dev_ahbs_htrans   (dev_ahb_htrans),
               .dev_ahbs_hwrite   (dev_ahb_hwrite),
               .dev_ahbs_hwdata   (dev_ahb_hwdata),
               .dev_ahbs_hsel     (dev_ahb_hsel),
               .dev_ahbs_hreadyin (dev_ahb_hreadymux),
               .dev_ahbs_hrdata   (dev_ahb_hrdata),
               .dev_ahbs_hreadyout(dev_ahb_hreadyout),
               .dev_ahbs_hresp    (dev_ahb_hresp),

               // Host AHB — from Lite converter
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

               // DMA AHB — from Full converter
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

               // Constant tie-offs — USB protocol timing parameters
               // Values from original NXP constants in usb_host_pie.m.vhdl and
               // usb_pie.m.vhdl. All timing values are in 60 MHz UTMI clock cycles.

               // Host PIE inter-packet delays (USB 2.0 §7.1.18)
               .usb_host_pie_INTER_PACKET_DELAY_LS_param(8'd80),   // 2 LS bit times
               .usb_host_pie_INTER_PACKET_DELAY_FS_param(8'd10),   // 2 FS bit times
               .usb_host_pie_INTER_PACKET_DELAY_HS_param(8'd12),   // 96 HS bit times (min 88)
               // Host PIE packet turnaround timeouts (USB 2.0 §7.1.18, §8.7.2)
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
               // DFT: must be 0 for functional operation
               .async_disable(1'b0),
               .testmode(1'b0)
   );

endmodule

