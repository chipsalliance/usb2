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
//           Entity-typed mapping: one axi_to_ahb per logical entity.
//           Each AXI port covers one entity (regs + DMA) with an AHB-side
//           address-threshold decode to split register from DMA traffic.
//
//             hub_axi  (MCU, hub entity)   addr < HUB_REG_ADDR_TOP  -> hub_ahbs
//                                          addr >= HUB_REG_ADDR_TOP -> hub_desc_ahbs_dma
//             dev0_axi (MCU, USBDC0)       addr < DEV0_REG_ADDR_TOP -> dev0_ahbs
//                                          addr >= DEV0_REG_ADDR_TOP-> dev0_ahbs_dma
//             dev1_axi (SoC-uC, USBDC1)   addr < DEV1_REG_ADDR_TOP -> dev1_ahbs
//                                          addr >= DEV1_REG_ADDR_TOP-> dev1_ahbs_dma
//
//           Security: the SoC fabric access-control policy determines which
//           AXI master can reach hub_axi/dev0_axi/dev1_axi. Cross-entity
//           access is impossible at the hardware level -- the wrapper has
//           no cross-entity path.
// -------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION  DATE        AUTHOR   DESCRIPTION
// 0.1      2026-08-14  nxp      Initial integration drop; replaces 3516 wrapper
// 0.2      2026-08-14  nxp      Entity-typed mapping: 3 x axi_to_ahb, AHB reg/DMA decode
// -------------------------------------------------------------------------

module ip_xxx_3511_hs_mem_compound_wrapper
  import axi_pkg::*;
#(
  // ---- SRAM configuration -------------------------------------------------
  parameter int unsigned  RAM_ADDRWIDTH             = 9,

  // ---- USB IP configuration (forwarded to VHDL entity generics) ----------
  parameter int unsigned  C_NBPHYSEP                = 14,
  parameter int unsigned  C_EPUB                    = 32,
  parameter int unsigned  C_DAUB                    = 32,
  parameter int unsigned  C_DALB                    = 17,
  // boolean generics: 1 = TRUE, 0 = FALSE
  parameter int unsigned  C_SINGLE_BUFFER_SUPPORTED = 1,
  parameter int unsigned  C_DOUBLE_BUFFER_SUPPORTED = 1,
  parameter int unsigned  C_TOGGLE_REG_READABLE     = 1,
  parameter logic [31:0]  C_EPFIFO_PAGE             = 32'h00080000,
  parameter logic [31:0]  C_DATAFIFO_PAGE           = 32'h00080000,
  parameter int unsigned  G_SIM_CHIRP_TIMERS        = 0,

  // ---- AXI bus parameters ------------------------------------------------

  parameter int unsigned  AXI_DATA_WIDTH            = 32,
  parameter int unsigned  AXI_ID_WIDTH              = 8,
  parameter int unsigned  AXI_USER_WIDTH            = 32,
  // hub_axi: hub entity (regs + DMA), MCU-accessible
  parameter int unsigned  AXI_HUB_ADDR_WIDTH        = 32,
  // dev0_axi: USBDC0 entity (regs + DMA), MCU-accessible
  parameter int unsigned  AXI_DEV0_ADDR_WIDTH       = 32,
  // dev1_axi: USBDC1 entity (regs + DMA), SoC-uC-accessible
  parameter int unsigned  AXI_DEV1_ADDR_WIDTH       = 32,
  // ---- Per-entity register/DMA address split threshold -------------------
  // Addresses strictly below the threshold (evaluated against the
  // intra-entity offset bits, i.e. the low-order bits of the AHB haddr
  // *within* this entity's own AXI aperture -- see REG_ADDR_OFFSET_BITS
  // below) are register accesses (4-bit haddr[5:2] space used by the IP's
  // register port); offsets >= threshold are DMA accesses.
  // USB register maps max at offset 0x3C; 0x100 gives ample headroom.
  // Replace with the final SoC aperture boundary once USB2-PRG-001 is closed.
  parameter logic [31:0]  HUB_REG_ADDR_TOP          = 32'h0000_0100,
  parameter logic [31:0]  DEV0_REG_ADDR_TOP         = 32'h0000_0100,
  parameter logic [31:0]  DEV1_REG_ADDR_TOP         = 32'h0000_0100,

  // ---- Intra-entity offset width used for the reg/DMA decode -------------
  // The AHB haddr driven out of axi_to_ahb carries the FULL, absolute AXI
  // address (no base-address subtraction is done inside axi_to_ahb). Each
  // entity (hub/dev0/dev1) is mapped into the SoC address map at some base
  // address, so comparing the raw haddr directly against *_REG_ADDR_TOP
  // (a small offset-style threshold) is always false for any realistic SoC
  // address (e.g. 0x2000_1100), permanently misrouting register accesses
  // to the DMA sub-port. Instead, mask to the low-order bits that represent
  // the offset *within* this entity's own AXI aperture before comparing.
  // ASSUMPTION: each entity's AXI aperture is naturally aligned on a
  // 2**REG_ADDR_OFFSET_BITS boundary (default: 4KB, 12 bits). Adjust this
  // if the actual SoC integration uses a different per-entity aperture size
  // (see soc_address_map.h / integration spec for the authoritative value).
  parameter int unsigned  REG_ADDR_OFFSET_BITS      = 12
)
(
  // =========================================================================
  // Device AXI4-Lite subordinate  (hub control regs + USBDC0 regs)
  // =========================================================================
  input  logic                              hub_axi_aclk,
  input  logic                              hub_axi_aresetn,

  // AR
  input  logic [AXI_HUB_ADDR_WIDTH-1:0]     hub_axi_araddr,
  input  logic [1:0]                        hub_axi_arburst,
  input  logic [2:0]                        hub_axi_arsize,
  input  logic [7:0]                        hub_axi_arlen,
  input  logic [AXI_USER_WIDTH-1:0]         hub_axi_aruser,
  input  logic [AXI_ID_WIDTH-1:0]           hub_axi_arid,
  input  logic                              hub_axi_arlock,
  input  logic [3:0]                        hub_axi_arcache,
  input  logic [2:0]                        hub_axi_arprot,
  input  logic [3:0]                        hub_axi_arqos,
  input  logic [3:0]                        hub_axi_arregion,
  input  logic                              hub_axi_arvalid,
  output logic                              hub_axi_arready,
  // R
  output logic [AXI_DATA_WIDTH-1:0]         hub_axi_rdata,
  output logic [1:0]                        hub_axi_rresp,
  output logic [AXI_ID_WIDTH-1:0]           hub_axi_rid,
  output logic [AXI_USER_WIDTH-1:0]         hub_axi_ruser,
  output logic                              hub_axi_rlast,
  output logic                              hub_axi_rvalid,
  input  logic                              hub_axi_rready,
  // AW
  input  logic [AXI_HUB_ADDR_WIDTH-1:0]     hub_axi_awaddr,
  input  logic [1:0]                        hub_axi_awburst,
  input  logic [2:0]                        hub_axi_awsize,
  input  logic [7:0]                        hub_axi_awlen,
  input  logic [AXI_USER_WIDTH-1:0]         hub_axi_awuser,
  input  logic [AXI_ID_WIDTH-1:0]           hub_axi_awid,
  input  logic                              hub_axi_awlock,
  input  logic [3:0]                        hub_axi_awcache,
  input  logic [2:0]                        hub_axi_awprot,
  input  logic [3:0]                        hub_axi_awqos,
  input  logic [3:0]                        hub_axi_awregion,
  input  logic                              hub_axi_awvalid,
  output logic                              hub_axi_awready,
  // W
  input  logic [AXI_DATA_WIDTH-1:0]         hub_axi_wdata,
  input  logic [AXI_DATA_WIDTH/8-1:0]       hub_axi_wstrb,
  input  logic [AXI_USER_WIDTH-1:0]         hub_axi_wuser,
  input  logic                              hub_axi_wvalid,
  output logic                              hub_axi_wready,
  input  logic                              hub_axi_wlast,
  // B
  output logic [1:0]                        hub_axi_bresp,
  output logic [AXI_ID_WIDTH-1:0]           hub_axi_bid,
  output logic [AXI_USER_WIDTH-1:0]         hub_axi_buser,
  output logic                              hub_axi_bvalid,
  input  logic                              hub_axi_bready,

  // =========================================================================
  // Host AXI4-Lite subordinate  (USBDC1 regs, owned by SoC-uC)
  // =========================================================================
  input  logic                              dev0_axi_aclk,
  input  logic                              dev0_axi_aresetn,

  input  logic [AXI_DEV0_ADDR_WIDTH-1:0]    dev0_axi_araddr,
  input  logic [1:0]                        dev0_axi_arburst,
  input  logic [2:0]                        dev0_axi_arsize,
  input  logic [7:0]                        dev0_axi_arlen,
  input  logic [AXI_USER_WIDTH-1:0]         dev0_axi_aruser,
  input  logic [AXI_ID_WIDTH-1:0]           dev0_axi_arid,
  input  logic                              dev0_axi_arlock,
  input  logic [3:0]                        dev0_axi_arcache,
  input  logic [2:0]                        dev0_axi_arprot,
  input  logic [3:0]                        dev0_axi_arqos,
  input  logic [3:0]                        dev0_axi_arregion,
  input  logic                              dev0_axi_arvalid,
  output logic                              dev0_axi_arready,
  output logic [AXI_DATA_WIDTH-1:0]         dev0_axi_rdata,
  output logic [1:0]                        dev0_axi_rresp,
  output logic [AXI_ID_WIDTH-1:0]           dev0_axi_rid,
  output logic [AXI_USER_WIDTH-1:0]         dev0_axi_ruser,
  output logic                              dev0_axi_rlast,
  output logic                              dev0_axi_rvalid,
  input  logic                              dev0_axi_rready,
  input  logic [AXI_DEV0_ADDR_WIDTH-1:0]    dev0_axi_awaddr,
  input  logic [1:0]                        dev0_axi_awburst,
  input  logic [2:0]                        dev0_axi_awsize,
  input  logic [7:0]                        dev0_axi_awlen,
  input  logic [AXI_USER_WIDTH-1:0]         dev0_axi_awuser,
  input  logic [AXI_ID_WIDTH-1:0]           dev0_axi_awid,
  input  logic                              dev0_axi_awlock,
  input  logic [3:0]                        dev0_axi_awcache,
  input  logic [2:0]                        dev0_axi_awprot,
  input  logic [3:0]                        dev0_axi_awqos,
  input  logic [3:0]                        dev0_axi_awregion,
  input  logic                              dev0_axi_awvalid,
  output logic                              dev0_axi_awready,
  input  logic [AXI_DATA_WIDTH-1:0]         dev0_axi_wdata,
  input  logic [AXI_DATA_WIDTH/8-1:0]       dev0_axi_wstrb,
  input  logic [AXI_USER_WIDTH-1:0]         dev0_axi_wuser,
  input  logic                              dev0_axi_wvalid,
  output logic                              dev0_axi_wready,
  input  logic                              dev0_axi_wlast,
  output logic [1:0]                        dev0_axi_bresp,
  output logic [AXI_ID_WIDTH-1:0]           dev0_axi_bid,
  output logic [AXI_USER_WIDTH-1:0]         dev0_axi_buser,
  output logic                              dev0_axi_bvalid,
  input  logic                              dev0_axi_bready,

  // =========================================================================
  // DMA AXI4 subordinate  (hub-descriptor DMA + USBDC0 DMA + USBDC1 DMA)
  // =========================================================================
  input  logic                              dev1_axi_aclk,
  input  logic                              dev1_axi_aresetn,

  input  logic [AXI_DEV1_ADDR_WIDTH-1:0]    dev1_axi_araddr,
  input  logic [1:0]                        dev1_axi_arburst,
  input  logic [2:0]                        dev1_axi_arsize,
  input  logic [7:0]                        dev1_axi_arlen,
  input  logic [AXI_USER_WIDTH-1:0]         dev1_axi_aruser,
  input  logic [AXI_ID_WIDTH-1:0]           dev1_axi_arid,
  input  logic                              dev1_axi_arlock,
  input  logic [3:0]                        dev1_axi_arcache,
  input  logic [2:0]                        dev1_axi_arprot,
  input  logic [3:0]                        dev1_axi_arqos,
  input  logic [3:0]                        dev1_axi_arregion,
  input  logic                              dev1_axi_arvalid,
  output logic                              dev1_axi_arready,
  output logic [AXI_DATA_WIDTH-1:0]         dev1_axi_rdata,
  output logic [1:0]                        dev1_axi_rresp,
  output logic [AXI_ID_WIDTH-1:0]           dev1_axi_rid,
  output logic [AXI_USER_WIDTH-1:0]         dev1_axi_ruser,
  output logic                              dev1_axi_rlast,
  output logic                              dev1_axi_rvalid,
  input  logic                              dev1_axi_rready,
  input  logic [AXI_DEV1_ADDR_WIDTH-1:0]     dev1_axi_awaddr,
  input  logic [1:0]                        dev1_axi_awburst,
  input  logic [2:0]                        dev1_axi_awsize,
  input  logic [7:0]                        dev1_axi_awlen,
  input  logic [AXI_USER_WIDTH-1:0]         dev1_axi_awuser,
  input  logic [AXI_ID_WIDTH-1:0]           dev1_axi_awid,
  input  logic                              dev1_axi_awlock,
  input  logic [3:0]                        dev1_axi_awcache,
  input  logic [2:0]                        dev1_axi_awprot,
  input  logic [3:0]                        dev1_axi_awqos,
  input  logic [3:0]                        dev1_axi_awregion,
  input  logic                              dev1_axi_awvalid,
  output logic                              dev1_axi_awready,
  input  logic [AXI_DATA_WIDTH-1:0]         dev1_axi_wdata,
  input  logic [AXI_DATA_WIDTH/8-1:0]       dev1_axi_wstrb,
  input  logic [AXI_USER_WIDTH-1:0]         dev1_axi_wuser,
  input  logic                              dev1_axi_wvalid,
  output logic                              dev1_axi_wready,
  input  logic                              dev1_axi_wlast,
  output logic [1:0]                        dev1_axi_bresp,
  output logic [AXI_ID_WIDTH-1:0]           dev1_axi_bid,
  output logic [AXI_USER_WIDTH-1:0]         dev1_axi_buser,
  output logic                              dev1_axi_bvalid,
  input  logic                              dev1_axi_bready,

  // =========================================================================
  // Hub descriptor SRAM interface  (hub ROM/RAM for descriptors + SETUP table)
  // =========================================================================
  input  logic [63:0]                       hub_desc_mem_q,
  output logic [63:0]                       hub_desc_mem_d,
  output logic                              hub_desc_mem_cs,
  output logic [RAM_ADDRWIDTH-1:0]          hub_desc_mem_a,
  output logic                              hub_desc_mem_web_out,
  output logic [63:0]                       hub_desc_mem_bsel,

  // =========================================================================
  // USBDC0 SRAM interface  (MCU-owned device controller EP list + data buf)
  // =========================================================================
  input  logic [63:0]                       dev0_mem_q,
  output logic [63:0]                       dev0_mem_d,
  output logic                              dev0_mem_cs,
  output logic [RAM_ADDRWIDTH-1:0]          dev0_mem_a,
  output logic                              dev0_mem_web_out,
  output logic [63:0]                       dev0_mem_bsel,

  // =========================================================================
  // USBDC1 SRAM interface  (SoC-uC-owned device controller EP list + data buf)
  // =========================================================================
  input  logic [63:0]                       dev1_mem_q,
  output logic [63:0]                       dev1_mem_d,
  output logic                              dev1_mem_cs,
  output logic [RAM_ADDRWIDTH-1:0]          dev1_mem_a,
  output logic                              dev1_mem_web_out,
  output logic [63:0]                       dev1_mem_bsel,

  // =========================================================================
  // Interrupt outputs
  // =========================================================================
  output logic                              dev0_usb_irq,     // USBDC0 IRQ -> MCU VeeR
  output logic                              dev0_usb_fiq,     // USBDC0 FIQ -> MCU VeeR
  output logic                              dev1_usb_irq,     // USBDC1 IRQ -> SoC-uC
  output logic                              dev1_usb_fiq,     // USBDC1 FIQ -> SoC-uC
  output logic                              usb_frametoggle,  // SOF frame toggle

  // =========================================================================
  // USB power / VBus
  // =========================================================================
  input  logic                              USB_VBus,
  output logic                              vbuscomp_on,
  output logic                              chrg_vbus,
  output logic                              dischrg_vbus,
  input  logic                              avalid,
  input  logic                              sessend,


  input  logic                              utmi_clk,
  input  logic [7:0]                        utmi_rxdata,
  input  logic                              utmi_rxvalid,
  input  logic                              utmi_rxactive,
  input  logic                              utmi_rxerror,
  output logic [7:0]                        utmi_txdata,
  output logic                              utmi_txvalid,
  input  logic                              utmi_txready,
  output logic                              utmi_reset,
  output logic                              utmi_suspendm,
  output logic                              utmi_xcvrselect,   // 1-bit (was [1:0] in 3516)
  output logic                              utmi_termselect,
  output logic [1:0]                        utmi_opmode,
  input  logic [1:0]                        utmi_linestate,
  output logic [3:0]                        utmi_vcontrol,
  output logic                              utmi_vcontrolloadm,
  input  logic [7:0]                        utmi_vstatus,

  // =========================================================================
  // ULPI PHY interface
  // =========================================================================
  input  logic                              ulpi_clk,
  input  logic [7:0]                        ulpi_rxdata,
  output logic [7:0]                        ulpi_txdata,
  output logic                              ulpi_txenable,
  input  logic                              ulpi_dir,
  output logic                              ulpi_stp,
  input  logic                              ulpi_nxt,
  input  logic                              ulpi_ddr_sel,

  // =========================================================================
  // System / wakeup interface
  // =========================================================================
  output logic                              usb_needclk,
  input  logic                              sys_donotwakeup_n,
  input  logic                              sys_dev_wakeup_n,
  input  logic                              sys_utmi_clkin_lock,

  // =========================================================================
  // Hub mode control
  // =========================================================================
  input  logic                              USB_EnableHub,   // 0=single-device, 1=hub mode
  input  logic                              USB_self_powered,

  // =========================================================================
  // DFT / testability
  // =========================================================================
  input  logic                              testmode,
  input  logic                              tcb_clkgate_se,
  input  logic                              async_disable
);

  // =========================================================================
  // Internal constants
  // =========================================================================

  localparam DMA_AHB_ADDR_W = RAM_ADDRWIDTH + 5;

  // =========================================================================
  // Internal AHB bus signals produced by the three AXI-to-AHB converters
  // =========================================================================

  // -- dev AXI -> single AHB master bus (mux decoded to hub_ahbs + dev0_ahbs) --
  logic [AXI_HUB_ADDR_WIDTH-1:0]     hub_ahb_haddr;
  logic [2:0]                        hub_ahb_hburst;
  logic [2:0]                        hub_ahb_hsize;
  logic [1:0]                        hub_ahb_htrans;
  logic                              hub_ahb_hwrite;
  logic [AXI_DATA_WIDTH-1:0]         hub_ahb_hwdata;
  logic                              hub_ahb_hsel;
  logic                              hub_ahb_hreadymux;  // output from converter, used as hreadyin
  logic [AXI_DATA_WIDTH-1:0]         hub_ahb_hrdata;     // driven by response mux below
  logic                              hub_ahb_hreadyout;  // driven by response mux below
  logic [1:0]                        hub_ahb_hresp;      // driven by response mux below

  // -- host AXI -> AHB master bus (single target: dev1_ahbs) --
  logic [AXI_DEV0_ADDR_WIDTH-1:0]    dev0_ahb_haddr;
  logic [2:0]                        dev0_ahb_hburst;
  logic [2:0]                        dev0_ahb_hsize;
  logic [1:0]                        dev0_ahb_htrans;
  logic                              dev0_ahb_hwrite;
  logic [AXI_DATA_WIDTH-1:0]         dev0_ahb_hwdata;
  logic                              dev0_ahb_hsel;
  logic                              dev0_ahb_hreadymux;
  logic [AXI_DATA_WIDTH-1:0]         dev0_ahb_hrdata;    // driven by dev1 response wires
  logic                              dev0_ahb_hreadyout; // driven by dev1 response wires
  logic [1:0]                        dev0_ahb_hresp;     // driven by dev1 response wires

  // -- dma AXI -> single AHB master bus (3-way decoded to hub_desc + dev0_dma + dev1_dma) --
  logic [AXI_DEV1_ADDR_WIDTH-1:0]     dev1_ahb_haddr;
  logic [2:0]                        dev1_ahb_hburst;
  logic [2:0]                        dev1_ahb_hsize;
  logic [1:0]                        dev1_ahb_htrans;
  logic                              dev1_ahb_hwrite;
  logic [AXI_DATA_WIDTH-1:0]         dev1_ahb_hwdata;
  logic                              dev1_ahb_hsel;
  logic                              dev1_ahb_hreadymux;
  logic [AXI_DATA_WIDTH-1:0]         dev1_ahb_hrdata;     // driven by response mux below
  logic                              dev1_ahb_hreadyout;  // driven by response mux below
  logic [1:0]                        dev1_ahb_hresp;      // driven by response mux below

  // =========================================================================
  // AXI interface objects used by axilite_to_ahb / axi_to_ahb
  // =========================================================================

  axi_if #(
    .AW(AXI_HUB_ADDR_WIDTH),
    .DW(AXI_DATA_WIDTH),
    .IW(AXI_ID_WIDTH),
    .UW(AXI_USER_WIDTH)
  ) hub_axi_if (.clk(hub_axi_aclk), .rst_n(hub_axi_aresetn));

  axi_if #(
    .AW(AXI_DEV0_ADDR_WIDTH),
    .DW(AXI_DATA_WIDTH),
    .IW(AXI_ID_WIDTH),
    .UW(AXI_USER_WIDTH)
  ) dev0_axi_if (.clk(dev0_axi_aclk), .rst_n(dev0_axi_aresetn));

  axi_if #(
    .AW(AXI_DEV1_ADDR_WIDTH),
    .DW(AXI_DATA_WIDTH),
    .IW(AXI_ID_WIDTH),
    .UW(AXI_USER_WIDTH)
  ) dev1_axi_if (.clk(dev1_axi_aclk), .rst_n(dev1_axi_aresetn));

  // =========================================================================
  // Discrete port -> axi_if wiring  (dev)
  // =========================================================================
  assign hub_axi_if.araddr   = hub_axi_araddr;
  assign hub_axi_if.arburst  = hub_axi_arburst;
  assign hub_axi_if.arsize   = hub_axi_arsize;
  assign hub_axi_if.arlen    = hub_axi_arlen;
  assign hub_axi_if.aruser   = hub_axi_aruser;
  assign hub_axi_if.arid     = hub_axi_arid;
  assign hub_axi_if.arlock   = hub_axi_arlock;
  assign hub_axi_if.arcache  = hub_axi_arcache;
  assign hub_axi_if.arprot   = hub_axi_arprot;
  assign hub_axi_if.arqos    = hub_axi_arqos;
  assign hub_axi_if.arregion = hub_axi_arregion;
  assign hub_axi_if.arvalid  = hub_axi_arvalid;
  assign hub_axi_arready     = hub_axi_if.arready;
  assign hub_axi_rdata       = hub_axi_if.rdata;
  assign hub_axi_rresp       = hub_axi_if.rresp;
  assign hub_axi_rid         = hub_axi_if.rid;
  assign hub_axi_ruser       = hub_axi_if.ruser;
  assign hub_axi_rlast       = hub_axi_if.rlast;
  assign hub_axi_rvalid      = hub_axi_if.rvalid;
  assign hub_axi_if.rready   = hub_axi_rready;
  assign hub_axi_if.awaddr   = hub_axi_awaddr;
  assign hub_axi_if.awburst  = hub_axi_awburst;
  assign hub_axi_if.awsize   = hub_axi_awsize;
  assign hub_axi_if.awlen    = hub_axi_awlen;
  assign hub_axi_if.awuser   = hub_axi_awuser;
  assign hub_axi_if.awid     = hub_axi_awid;
  assign hub_axi_if.awlock   = hub_axi_awlock;
  assign hub_axi_if.awcache  = hub_axi_awcache;
  assign hub_axi_if.awprot   = hub_axi_awprot;
  assign hub_axi_if.awqos    = hub_axi_awqos;
  assign hub_axi_if.awregion = hub_axi_awregion;
  assign hub_axi_if.awvalid  = hub_axi_awvalid;
  assign hub_axi_awready     = hub_axi_if.awready;
  assign hub_axi_if.wdata    = hub_axi_wdata;
  assign hub_axi_if.wstrb    = hub_axi_wstrb;
  assign hub_axi_if.wuser    = hub_axi_wuser;
  assign hub_axi_if.wvalid   = hub_axi_wvalid;
  assign hub_axi_wready      = hub_axi_if.wready;
  assign hub_axi_if.wlast    = hub_axi_wlast;
  assign hub_axi_bresp       = hub_axi_if.bresp;
  assign hub_axi_bid         = hub_axi_if.bid;
  assign hub_axi_buser       = hub_axi_if.buser;
  assign hub_axi_bvalid      = hub_axi_if.bvalid;
  assign hub_axi_if.bready   = hub_axi_bready;

  // Discrete port -> axi_if wiring  (host)
  assign dev0_axi_if.araddr   = dev0_axi_araddr;
  assign dev0_axi_if.arburst  = dev0_axi_arburst;
  assign dev0_axi_if.arsize   = dev0_axi_arsize;
  assign dev0_axi_if.arlen    = dev0_axi_arlen;
  assign dev0_axi_if.aruser   = dev0_axi_aruser;
  assign dev0_axi_if.arid     = dev0_axi_arid;
  assign dev0_axi_if.arlock   = dev0_axi_arlock;
  assign dev0_axi_if.arcache  = dev0_axi_arcache;
  assign dev0_axi_if.arprot   = dev0_axi_arprot;
  assign dev0_axi_if.arqos    = dev0_axi_arqos;
  assign dev0_axi_if.arregion = dev0_axi_arregion;
  assign dev0_axi_if.arvalid  = dev0_axi_arvalid;
  assign dev0_axi_arready     = dev0_axi_if.arready;
  assign dev0_axi_rdata       = dev0_axi_if.rdata;
  assign dev0_axi_rresp       = dev0_axi_if.rresp;
  assign dev0_axi_rid         = dev0_axi_if.rid;
  assign dev0_axi_ruser       = dev0_axi_if.ruser;
  assign dev0_axi_rlast       = dev0_axi_if.rlast;
  assign dev0_axi_rvalid      = dev0_axi_if.rvalid;
  assign dev0_axi_if.rready   = dev0_axi_rready;
  assign dev0_axi_if.awaddr   = dev0_axi_awaddr;
  assign dev0_axi_if.awburst  = dev0_axi_awburst;
  assign dev0_axi_if.awsize   = dev0_axi_awsize;
  assign dev0_axi_if.awlen    = dev0_axi_awlen;
  assign dev0_axi_if.awuser   = dev0_axi_awuser;
  assign dev0_axi_if.awid     = dev0_axi_awid;
  assign dev0_axi_if.awlock   = dev0_axi_awlock;
  assign dev0_axi_if.awcache  = dev0_axi_awcache;
  assign dev0_axi_if.awprot   = dev0_axi_awprot;
  assign dev0_axi_if.awqos    = dev0_axi_awqos;
  assign dev0_axi_if.awregion = dev0_axi_awregion;
  assign dev0_axi_if.awvalid  = dev0_axi_awvalid;
  assign dev0_axi_awready     = dev0_axi_if.awready;
  assign dev0_axi_if.wdata    = dev0_axi_wdata;
  assign dev0_axi_if.wstrb    = dev0_axi_wstrb;
  assign dev0_axi_if.wuser    = dev0_axi_wuser;
  assign dev0_axi_if.wvalid   = dev0_axi_wvalid;
  assign dev0_axi_wready      = dev0_axi_if.wready;
  assign dev0_axi_if.wlast    = dev0_axi_wlast;
  assign dev0_axi_bresp       = dev0_axi_if.bresp;
  assign dev0_axi_bid         = dev0_axi_if.bid;
  assign dev0_axi_buser       = dev0_axi_if.buser;
  assign dev0_axi_bvalid      = dev0_axi_if.bvalid;
  assign dev0_axi_if.bready   = dev0_axi_bready;

  // Discrete port -> axi_if wiring  (dma)
  assign dev1_axi_if.araddr   = dev1_axi_araddr;
  assign dev1_axi_if.arburst  = dev1_axi_arburst;
  assign dev1_axi_if.arsize   = dev1_axi_arsize;
  assign dev1_axi_if.arlen    = dev1_axi_arlen;
  assign dev1_axi_if.aruser   = dev1_axi_aruser;
  assign dev1_axi_if.arid     = dev1_axi_arid;
  assign dev1_axi_if.arlock   = dev1_axi_arlock;
  assign dev1_axi_if.arcache  = dev1_axi_arcache;
  assign dev1_axi_if.arprot   = dev1_axi_arprot;
  assign dev1_axi_if.arqos    = dev1_axi_arqos;
  assign dev1_axi_if.arregion = dev1_axi_arregion;
  assign dev1_axi_if.arvalid  = dev1_axi_arvalid;
  assign dev1_axi_arready     = dev1_axi_if.arready;
  assign dev1_axi_rdata       = dev1_axi_if.rdata;
  assign dev1_axi_rresp       = dev1_axi_if.rresp;
  assign dev1_axi_rid         = dev1_axi_if.rid;
  assign dev1_axi_ruser       = dev1_axi_if.ruser;
  assign dev1_axi_rlast       = dev1_axi_if.rlast;
  assign dev1_axi_rvalid      = dev1_axi_if.rvalid;
  assign dev1_axi_if.rready   = dev1_axi_rready;
  assign dev1_axi_if.awaddr   = dev1_axi_awaddr;
  assign dev1_axi_if.awburst  = dev1_axi_awburst;
  assign dev1_axi_if.awsize   = dev1_axi_awsize;
  assign dev1_axi_if.awlen    = dev1_axi_awlen;
  assign dev1_axi_if.awuser   = dev1_axi_awuser;
  assign dev1_axi_if.awid     = dev1_axi_awid;
  assign dev1_axi_if.awlock   = dev1_axi_awlock;
  assign dev1_axi_if.awcache  = dev1_axi_awcache;
  assign dev1_axi_if.awprot   = dev1_axi_awprot;
  assign dev1_axi_if.awqos    = dev1_axi_awqos;
  assign dev1_axi_if.awregion = dev1_axi_awregion;
  assign dev1_axi_if.awvalid  = dev1_axi_awvalid;
  assign dev1_axi_awready     = dev1_axi_if.awready;
  assign dev1_axi_if.wdata    = dev1_axi_wdata;
  assign dev1_axi_if.wstrb    = dev1_axi_wstrb;
  assign dev1_axi_if.wuser    = dev1_axi_wuser;
  assign dev1_axi_if.wvalid   = dev1_axi_wvalid;
  assign dev1_axi_wready      = dev1_axi_if.wready;
  assign dev1_axi_if.wlast    = dev1_axi_wlast;
  assign dev1_axi_bresp       = dev1_axi_if.bresp;
  assign dev1_axi_bid         = dev1_axi_if.bid;
  assign dev1_axi_buser       = dev1_axi_if.buser;
  assign dev1_axi_bvalid      = dev1_axi_if.bvalid;
  assign dev1_axi_if.bready   = dev1_axi_bready;

  // =========================================================================
  // AXI-to-AHB converter instantiations
  // =========================================================================

// HUB control + DMA -> shared AHB bus 
  axi_to_ahb #(
    .AW (AXI_HUB_ADDR_WIDTH),
    .DW (AXI_DATA_WIDTH),
    .IW (AXI_ID_WIDTH),
    .UW (AXI_USER_WIDTH)
  ) u_hub_axi2ahb (
    .clk           (hub_axi_aclk),
    .rst_n         (hub_axi_aresetn),
    .axi_r         (hub_axi_if),
    .axi_w         (hub_axi_if),
    .ahb_haddr     (hub_ahb_haddr),
    .ahb_hburst    (hub_ahb_hburst),
    .ahb_hsize     (hub_ahb_hsize),
    .ahb_htrans    (hub_ahb_htrans),
    .ahb_hwrite    (hub_ahb_hwrite),
    .ahb_hwdata    (hub_ahb_hwdata),
    .ahb_hsel      (hub_ahb_hsel),
    .ahb_hreadymux (hub_ahb_hreadymux),
    .ahb_hrdata    (hub_ahb_hrdata),
    .ahb_hreadyout (hub_ahb_hreadyout),
    .ahb_hresp     (hub_ahb_hresp)
  );

  // host AXI4-Lite -> AHB (direct to dev1_ahbs, no further decode)
  axi_to_ahb #(
    .AW (AXI_DEV0_ADDR_WIDTH),
    .DW (AXI_DATA_WIDTH),
    .IW (AXI_ID_WIDTH),
    .UW (AXI_USER_WIDTH)
  ) u_dev0_axi2ahb (
    .clk           (dev0_axi_aclk),
    .rst_n         (dev0_axi_aresetn),
    .axi_r         (dev0_axi_if),
    .axi_w         (dev0_axi_if),
    .ahb_haddr     (dev0_ahb_haddr),
    .ahb_hburst    (dev0_ahb_hburst),
    .ahb_hsize     (dev0_ahb_hsize),
    .ahb_htrans    (dev0_ahb_htrans),
    .ahb_hwrite    (dev0_ahb_hwrite),
    .ahb_hwdata    (dev0_ahb_hwdata),
    .ahb_hsel      (dev0_ahb_hsel),
    .ahb_hreadymux (dev0_ahb_hreadymux),
    .ahb_hrdata    (dev0_ahb_hrdata),
    .ahb_hreadyout (dev0_ahb_hreadyout),
    .ahb_hresp     (dev0_ahb_hresp)
  );

  // dma AXI4 (full burst) -> shared AHB bus (decoded to 3 DMA sub-ports)
  axi_to_ahb #(
    .AW (AXI_DEV1_ADDR_WIDTH),
    .DW (AXI_DATA_WIDTH),
    .IW (AXI_ID_WIDTH),
    .UW (AXI_USER_WIDTH)
  ) u_dev1_axi2ahb (
    .clk           (dev1_axi_aclk),
    .rst_n         (dev1_axi_aresetn),
    .axi_r         (dev1_axi_if),
    .axi_w         (dev1_axi_if),
    .ahb_haddr     (dev1_ahb_haddr),
    .ahb_hburst    (dev1_ahb_hburst),
    .ahb_hsize     (dev1_ahb_hsize),
    .ahb_htrans    (dev1_ahb_htrans),
    .ahb_hwrite    (dev1_ahb_hwrite),
    .ahb_hwdata    (dev1_ahb_hwdata),
    .ahb_hsel      (dev1_ahb_hsel),
    .ahb_hreadymux (dev1_ahb_hreadymux),
    .ahb_hrdata    (dev1_ahb_hrdata),
    .ahb_hreadyout (dev1_ahb_hreadyout),
    .ahb_hresp     (dev1_ahb_hresp)
  );

  // =========================================================================
  // Per-entity AHB Address Decode: reg vs DMA via address threshold
  // =========================================================================
  // Each converter drives one AHB master bus per entity.
  // Addresses below *_REG_ADDR_TOP are register accesses (haddr[5:2] used
  // by the IP's register port). Addresses >= *_REG_ADDR_TOP are DMA accesses.
  // =========================================================================

  // -------------------------------------------------------------------------
  // Hub entity: hub_axi -> hub_ahbs (regs) + hub_desc_ahbs_dma (DMA)
  // -------------------------------------------------------------------------
  logic hub_reg_sel_comb;
  logic hub_dma_sel_comb;
  logic hub_reg_sel_dphase;  // registered: 1=reg port active in data phase

  // Compare against the intra-entity offset (low-order bits) rather than
  // the full absolute AXI address, which would always fail the "< TOP"
  // test for real SoC addresses and permanently misroute register writes
  // to the DMA sub-port.
  assign hub_reg_sel_comb = hub_ahb_hsel & (hub_ahb_haddr[REG_ADDR_OFFSET_BITS-1:0] < HUB_REG_ADDR_TOP[REG_ADDR_OFFSET_BITS-1:0]);
  assign hub_dma_sel_comb = hub_ahb_hsel & (hub_ahb_haddr[REG_ADDR_OFFSET_BITS-1:0] >= HUB_REG_ADDR_TOP[REG_ADDR_OFFSET_BITS-1:0]);

  always_ff @(posedge hub_axi_aclk or negedge hub_axi_aresetn) begin
    if (!hub_axi_aresetn)
      hub_reg_sel_dphase <= 1'b1;
    else if (hub_ahb_htrans[1] & hub_ahb_hreadymux)
      hub_reg_sel_dphase <= hub_reg_sel_comb;
  end

  // Response wires from hub IP sub-ports
  logic [AXI_DATA_WIDTH-1:0]   hub_ahbs_hrdata_w;
  logic                        hub_ahbs_hreadyout_w;
  logic [1:0]                  hub_ahbs_hresp_w;
  logic [AXI_DATA_WIDTH-1:0]   hub_desc_dma_hrdata_w;
  logic                        hub_desc_dma_hreadyout_w;
  logic [1:0]                  hub_desc_dma_hresp_w;

  always_comb begin
    if (hub_reg_sel_dphase) begin
      hub_ahb_hrdata    = hub_ahbs_hrdata_w;
      hub_ahb_hreadyout = hub_ahbs_hreadyout_w;
      hub_ahb_hresp     = hub_ahbs_hresp_w;
    end else begin
      hub_ahb_hrdata    = hub_desc_dma_hrdata_w;
      hub_ahb_hreadyout = hub_desc_dma_hreadyout_w;
      hub_ahb_hresp     = hub_desc_dma_hresp_w;
    end
  end

  // -------------------------------------------------------------------------
  // USBDC0 entity: dev0_axi -> dev0_ahbs (regs) + dev0_ahbs_dma (DMA)
  // -------------------------------------------------------------------------
  logic dev0_reg_sel_comb;
  logic dev0_dma_sel_comb;
  logic dev0_reg_sel_dphase;

  // Compare against the intra-entity offset (low-order bits) rather than
  // the full absolute AXI address, which would always fail the "< TOP"
  // test for real SoC addresses and permanently misroute register writes
  // to the DMA sub-port.
  assign dev0_reg_sel_comb = dev0_ahb_hsel & (dev0_ahb_haddr[REG_ADDR_OFFSET_BITS-1:0] < DEV0_REG_ADDR_TOP[REG_ADDR_OFFSET_BITS-1:0]);
  assign dev0_dma_sel_comb = dev0_ahb_hsel & (dev0_ahb_haddr[REG_ADDR_OFFSET_BITS-1:0] >= DEV0_REG_ADDR_TOP[REG_ADDR_OFFSET_BITS-1:0]);

  always_ff @(posedge dev0_axi_aclk or negedge dev0_axi_aresetn) begin
    if (!dev0_axi_aresetn)
      dev0_reg_sel_dphase <= 1'b1;
    else if (dev0_ahb_htrans[1] & dev0_ahb_hreadymux)
      dev0_reg_sel_dphase <= dev0_reg_sel_comb;
  end

  // Response wires from USBDC0 IP sub-ports
  logic [AXI_DATA_WIDTH-1:0]   dev0_ahbs_hrdata_w;
  logic                        dev0_ahbs_hreadyout_w;
  logic [1:0]                  dev0_ahbs_hresp_w;
  logic [AXI_DATA_WIDTH-1:0]   dev0_dma_hrdata_w;
  logic                        dev0_dma_hreadyout_w;
  logic [1:0]                  dev0_dma_hresp_w;

  always_comb begin
    if (dev0_reg_sel_dphase) begin
      dev0_ahb_hrdata    = dev0_ahbs_hrdata_w;
      dev0_ahb_hreadyout = dev0_ahbs_hreadyout_w;
      dev0_ahb_hresp     = dev0_ahbs_hresp_w;
    end else begin
      dev0_ahb_hrdata    = dev0_dma_hrdata_w;
      dev0_ahb_hreadyout = dev0_dma_hreadyout_w;
      dev0_ahb_hresp     = dev0_dma_hresp_w;
    end
  end

  // -------------------------------------------------------------------------
  // USBDC1 entity: dev1_axi -> dev1_ahbs (regs) + dev1_ahbs_dma (DMA)
  // -------------------------------------------------------------------------
  logic dev1_reg_sel_comb;
  logic dev1_dma_sel_comb;
  logic dev1_reg_sel_dphase;

  // Compare against the intra-entity offset (low-order bits) rather than
  // the full absolute AXI address, which would always fail the "< TOP"
  // test for real SoC addresses and permanently misroute register writes
  // to the DMA sub-port.
  assign dev1_reg_sel_comb = dev1_ahb_hsel & (dev1_ahb_haddr[REG_ADDR_OFFSET_BITS-1:0] < DEV1_REG_ADDR_TOP[REG_ADDR_OFFSET_BITS-1:0]);
  assign dev1_dma_sel_comb = dev1_ahb_hsel & (dev1_ahb_haddr[REG_ADDR_OFFSET_BITS-1:0] >= DEV1_REG_ADDR_TOP[REG_ADDR_OFFSET_BITS-1:0]);

  always_ff @(posedge dev1_axi_aclk or negedge dev1_axi_aresetn) begin
    if (!dev1_axi_aresetn)
      dev1_reg_sel_dphase <= 1'b1;
    else if (dev1_ahb_htrans[1] & dev1_ahb_hreadymux)
      dev1_reg_sel_dphase <= dev1_reg_sel_comb;
  end

  // Response wires from USBDC1 IP sub-ports
  logic [AXI_DATA_WIDTH-1:0]   dev1_ahbs_hrdata_w;
  logic                        dev1_ahbs_hreadyout_w;
  logic [1:0]                  dev1_ahbs_hresp_w;
  logic [AXI_DATA_WIDTH-1:0]   dev1_dma_hrdata_w;
  logic                        dev1_dma_hreadyout_w;
  logic [1:0]                  dev1_dma_hresp_w;

  always_comb begin
    if (dev1_reg_sel_dphase) begin
      dev1_ahb_hrdata    = dev1_ahbs_hrdata_w;
      dev1_ahb_hreadyout = dev1_ahbs_hreadyout_w;
      dev1_ahb_hresp     = dev1_ahbs_hresp_w;
    end else begin
      dev1_ahb_hrdata    = dev1_dma_hrdata_w;
      dev1_ahb_hreadyout = dev1_dma_hreadyout_w;
      dev1_ahb_hresp     = dev1_dma_hresp_w;
    end
  end

  // =========================================================================
  // ip_xxx_3511_hs_mem_compound instantiation  (VHDL entity, mixed-language)
  // =========================================================================
  logic [1:0] unused_dma_dword_sel_w;
  logic       unused_dma_write_access_w;

  ip_xxx_3511_hs_mem_compound #(
    .AHB_DATAWIDTH                (AXI_DATA_WIDTH),       // must be 32
    .RAM_DATAWIDTH                (64),                   // fixed 64-bit SRAM
    .RAM_ADDRWIDTH                (RAM_ADDRWIDTH),        // 9 default
    .C_NBPHYSEP_ARM               (C_NBPHYSEP),
    .C_EPUB                       (C_EPUB),
    .C_DAUB                       (C_DAUB),
    .C_DALB                       (C_DALB),
    .C_EPFIFO_PAGE                (C_EPFIFO_PAGE),
    .C_DATAFIFO_PAGE              (C_DATAFIFO_PAGE),
    .C_SINGLE_BUFFER_SUPPORTED    (C_SINGLE_BUFFER_SUPPORTED),
    .C_DOUBLE_BUFFER_SUPPORTED    (C_DOUBLE_BUFFER_SUPPORTED),
    .C_TOGGLE_REG_READABLE        (C_TOGGLE_REG_READABLE),
    .C_PLL_ENABLE                 (0),    // FALSE: no on-chip PLL
    .C_ULPI_SUPPORT               (1),    // TRUE
    .C_UTMI_SUPPORT               (1),    // TRUE
    .C_EXTEND_TX_DELAY            (1),    // TRUE
    .G_SIM_CHIRP_TIMERS           (G_SIM_CHIRP_TIMERS)
  ) u_hub_compound (

    // ---- Clock / Reset ----
    .hclk                          (hub_axi_aclk),
    .hresetn                       (hub_axi_aresetn),
    .ahbs_resetn                   (hub_axi_aresetn),

    // ---- Hub control register AHB port (hub_ahbs) ----
    // hub_axi drives this port when addr < HUB_REG_ADDR_TOP.
    // haddr[5:2] only: IP register map is 4-bit wide.
    .hub_ahbs_haddr                (hub_ahb_haddr[5:2]),
    .hub_ahbs_htrans               (hub_reg_sel_comb ? hub_ahb_htrans : 2'b00),
    .hub_ahbs_hwrite               (hub_ahb_hwrite),
    .hub_ahbs_hwdata               (hub_ahb_hwdata[31:0]),
    .hub_ahbs_hsel                 (hub_reg_sel_comb),
    .hub_ahbs_hreadyin             (hub_ahb_hreadymux),
    .hub_ahbs_hrdata               (hub_ahbs_hrdata_w),
    .hub_ahbs_hreadyout            (hub_ahbs_hreadyout_w),
    .hub_ahbs_hresp                (hub_ahbs_hresp_w),

    // ---- Hub descriptor DMA AHB port (hub_desc_ahbs_dma) ----
    // hub_axi drives this port when addr >= HUB_REG_ADDR_TOP.
    .hub_desc_ahbs_dma_haddr       (hub_ahb_haddr[DMA_AHB_ADDR_W-1:0]),
    .hub_desc_ahbs_dma_htrans      (hub_dma_sel_comb ? hub_ahb_htrans : 2'b00),
    .hub_desc_ahbs_dma_hwrite      (hub_ahb_hwrite),
    .hub_desc_ahbs_dma_hwdata      (hub_ahb_hwdata),
    .hub_desc_ahbs_dma_hsel        (hub_dma_sel_comb),
    .hub_desc_ahbs_dma_hreadyin    (hub_ahb_hreadymux),
    .hub_desc_ahbs_dma_hrdata      (hub_desc_dma_hrdata_w),
    .hub_desc_ahbs_dma_hreadyout   (hub_desc_dma_hreadyout_w),
    .hub_desc_ahbs_dma_hresp       (hub_desc_dma_hresp_w),
    .hub_desc_ahbs_dma_hsize       (hub_ahb_hsize),
    .hub_desc_ahbs_dma_hburst      (hub_ahb_hburst),

    // ---- Hub descriptor SRAM ----
    .hub_desc_mem_q                (hub_desc_mem_q),
    .hub_desc_mem_d                (hub_desc_mem_d),
    .hub_desc_mem_cs               (hub_desc_mem_cs),
    .hub_desc_mem_a                (hub_desc_mem_a),
    .hub_desc_mem_web_out          (hub_desc_mem_web_out),
    .hub_desc_mem_bsel             (hub_desc_mem_bsel),

    // ---- USBDC0 control register AHB port (dev0_ahbs) ----
    // dev0_axi drives this port when addr < DEV0_REG_ADDR_TOP.
    .dev0_ahbs_haddr               (dev0_ahb_haddr[5:2]),
    .dev0_ahbs_htrans              (dev0_reg_sel_comb ? dev0_ahb_htrans : 2'b00),
    .dev0_ahbs_hwrite              (dev0_ahb_hwrite),
    .dev0_ahbs_hwdata              (dev0_ahb_hwdata[31:0]),
    .dev0_ahbs_hsel                (dev0_reg_sel_comb),
    .dev0_ahbs_hreadyin            (dev0_ahb_hreadymux),
    .dev0_ahbs_hrdata              (dev0_ahbs_hrdata_w),
    .dev0_ahbs_hreadyout           (dev0_ahbs_hreadyout_w),
    .dev0_ahbs_hresp               (dev0_ahbs_hresp_w),

    // ---- USBDC0 DMA AHB port (dev0_ahbs_dma) ----
    // dev0_axi drives this port when addr >= DEV0_REG_ADDR_TOP.
    .dev0_ahbs_dma_haddr           (dev0_ahb_haddr[DMA_AHB_ADDR_W-1:0]),
    .dev0_ahbs_dma_htrans          (dev0_dma_sel_comb ? dev0_ahb_htrans : 2'b00),
    .dev0_ahbs_dma_hwrite          (dev0_ahb_hwrite),
    .dev0_ahbs_dma_hwdata          (dev0_ahb_hwdata),
    .dev0_ahbs_dma_hsel            (dev0_dma_sel_comb),
    .dev0_ahbs_dma_hreadyin        (dev0_ahb_hreadymux),
    .dev0_ahbs_dma_hrdata          (dev0_dma_hrdata_w),
    .dev0_ahbs_dma_hreadyout       (dev0_dma_hreadyout_w),
    .dev0_ahbs_dma_hresp           (dev0_dma_hresp_w),
    .dev0_ahbs_dma_hsize           (dev0_ahb_hsize),
    .dev0_ahbs_dma_hburst          (dev0_ahb_hburst),

    // ---- USBDC0 SRAM ----
    .dev0_mem_q                    (dev0_mem_q),
    .dev0_mem_d                    (dev0_mem_d),
    .dev0_mem_cs                   (dev0_mem_cs),
    .dev0_mem_a                    (dev0_mem_a),
    .dev0_mem_web_out              (dev0_mem_web_out),
    .dev0_mem_bsel                 (dev0_mem_bsel),

    // ---- USBDC0 interrupts (routed to MCU VeeR)
    .dev0_usb_irq                  (dev0_usb_irq),
    .dev0_usb_fiq                  (dev0_usb_fiq),

    // ---- USBDC1 control register AHB port (dev1_ahbs) ----
    // dev1_axi drives this port when addr < DEV1_REG_ADDR_TOP.
    .dev1_ahbs_haddr               (dev1_ahb_haddr[5:2]),
    .dev1_ahbs_htrans              (dev1_reg_sel_comb ? dev1_ahb_htrans : 2'b00),
    .dev1_ahbs_hwrite              (dev1_ahb_hwrite),
    .dev1_ahbs_hwdata              (dev1_ahb_hwdata[31:0]),
    .dev1_ahbs_hsel                (dev1_reg_sel_comb),
    .dev1_ahbs_hreadyin            (dev1_ahb_hreadymux),
    .dev1_ahbs_hrdata              (dev1_ahbs_hrdata_w),
    .dev1_ahbs_hreadyout           (dev1_ahbs_hreadyout_w),
    .dev1_ahbs_hresp               (dev1_ahbs_hresp_w),

    // ---- USBDC1 DMA AHB port (dev1_ahbs_dma) ----
    // dev1_axi drives this port when addr >= DEV1_REG_ADDR_TOP.
    .dev1_ahbs_dma_haddr           (dev1_ahb_haddr[DMA_AHB_ADDR_W-1:0]),
    .dev1_ahbs_dma_htrans          (dev1_dma_sel_comb ? dev1_ahb_htrans : 2'b00),
    .dev1_ahbs_dma_hwrite          (dev1_ahb_hwrite),
    .dev1_ahbs_dma_hwdata          (dev1_ahb_hwdata),
    .dev1_ahbs_dma_hsel            (dev1_dma_sel_comb),
    .dev1_ahbs_dma_hreadyin        (dev1_ahb_hreadymux),
    .dev1_ahbs_dma_hrdata          (dev1_dma_hrdata_w),
    .dev1_ahbs_dma_hreadyout       (dev1_dma_hreadyout_w),
    .dev1_ahbs_dma_hresp           (dev1_dma_hresp_w),
    .dev1_ahbs_dma_hsize           (dev1_ahb_hsize),
    .dev1_ahbs_dma_hburst          (dev1_ahb_hburst),

    // ---- USBDC1 SRAM ----
    .dev1_mem_q                    (dev1_mem_q),
    .dev1_mem_d                    (dev1_mem_d),
    .dev1_mem_cs                   (dev1_mem_cs),
    .dev1_mem_a                    (dev1_mem_a),
    .dev1_mem_web_out              (dev1_mem_web_out),
    .dev1_mem_bsel                 (dev1_mem_bsel),

    // ---- USBDC1 interrupts 
    .dev1_usb_irq                  (dev1_usb_irq),
    .dev1_usb_fiq                  (dev1_usb_fiq),

    // ---- SOF frame toggle ----
    .USB_FrameToggle               (usb_frametoggle),

    // ---- VBus / session ----
    .USB_VBus                      (USB_VBus),
    .vbuscomp_on                   (vbuscomp_on),
    .chrg_vbus                     (chrg_vbus),
    .dischrg_vbus                  (dischrg_vbus),
    .avalid                        (avalid),
    .sessend                       (sessend),

    // ---- UTMI PHY ----
    .utmi_clk                      (utmi_clk),
    .utmi_rxdata                   (utmi_rxdata),
    .utmi_rxvalid                  (utmi_rxvalid),
    .utmi_rxactive                 (utmi_rxactive),
    .utmi_rxerror                  (utmi_rxerror),
    .utmi_txdata                   (utmi_txdata),
    .utmi_txvalid                  (utmi_txvalid),
    .utmi_txready                  (utmi_txready),
    .utmi_reset                    (utmi_reset),
    .utmi_suspendm                 (utmi_suspendm),
    .utmi_xcvrselect               (utmi_xcvrselect),
    .utmi_termselect               (utmi_termselect),
    .utmi_opmode                   (utmi_opmode),
    .utmi_linestate                (utmi_linestate),
    .utmi_vcontrol                 (utmi_vcontrol),
    .utmi_vcontrolloadm            (utmi_vcontrolloadm),
    .utmi_vstatus                  (utmi_vstatus),

    // ---- ULPI PHY ----
    .ulpi_clk                      (ulpi_clk),
    .ulpi_rxdata                   (ulpi_rxdata),
    .ulpi_txdata                   (ulpi_txdata),
    .ulpi_txenable                 (ulpi_txenable),
    .ulpi_dir                      (ulpi_dir),
    .ulpi_stp                      (ulpi_stp),
    .ulpi_nxt                      (ulpi_nxt),
    .ulpi_ddr_sel                  (ulpi_ddr_sel),

    // ---- System / wakeup ----
    .usb_needclk                   (usb_needclk),
    .sys_donotwakeup_n             (sys_donotwakeup_n),
    .sys_dev_wakeup_n              (sys_dev_wakeup_n),
    .sys_utmi_clkin_lock           (sys_utmi_clkin_lock),

    // ---- Hub mode control ----
    .USB_EnableHub                 (USB_EnableHub),
    .USB_self_powered              (USB_self_powered),

    // ---- DFT ----
    .async_disable                 (async_disable),
    .testmode                      (testmode),
    .tcb_clkgate_se                (tcb_clkgate_se),

    .usb_dma_dword_selection       (unused_dma_dword_sel_w),
    .usb_dma_write_access          (unused_dma_write_access_w)
  );

endmodule : ip_xxx_3511_hs_mem_compound_wrapper

// File contains AI-generated response based on internal company sources
