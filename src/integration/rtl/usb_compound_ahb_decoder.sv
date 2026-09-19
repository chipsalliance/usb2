// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// you may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
`include "caliptra_prim_assert.sv"

module usb_compound_ahb_decoder
  import usb_compound_pkg::*;
#(
  parameter int unsigned C_HUB_FIFO_SIZE = 172,
  localparam int unsigned HUB_WORD_ADDR_WIDTH = $clog2(C_HUB_FIFO_SIZE),
  localparam logic [32:0] HUB_APERTURE_BYTES =
      33'd1 << ($clog2(C_HUB_FIFO_SIZE) + 2),
  localparam int unsigned COMBO_LOCAL_ADDR_WIDTH =
      $clog2(33'(HUB_BASE_ADDR + HUB_APERTURE_BYTES))
) (
  // ---- Clock and reset ----
  input  logic                               clk,
  input  logic                               rst_n,

  // ---- Upstream Combo AHB interface ----
  input  logic [COMBO_LOCAL_ADDR_WIDTH-1:0]  combo_haddr,
  input  logic [1:0]                         combo_htrans,
  input  logic [2:0]                         combo_hburst,
  input  logic [2:0]                         combo_hsize,
  input  logic                               combo_hwrite,
  input  logic                               combo_hsel,
  input  logic                               combo_hready,
  input  logic [31:0]                        combo_hwdata,
  output logic [31:0]                        combo_hrdata,
  output logic                               combo_hreadyout,
  output logic [1:0]                         combo_hresp,

  // ---- DEV0 CSR AHB interface (word address) ----
  output logic [3:0]                         dev0_csr_haddr,
  output logic [1:0]                         dev0_csr_htrans,
  output logic                               dev0_csr_hwrite,
  output logic [31:0]                        dev0_csr_hwdata,
  output logic                               dev0_csr_hsel,
  output logic                               dev0_csr_hreadyin,
  input  logic [31:0]                        dev0_csr_hrdata,
  input  logic                               dev0_csr_hreadyout,
  input  logic [1:0]                         dev0_csr_hresp,

  // ---- HUB Bank AHB interface ----
  output logic [HUB_WORD_ADDR_WIDTH-1:0]     hub_haddr,
  output logic [1:0]                         hub_htrans,
  output logic                               hub_hwrite,
  output logic [31:0]                        hub_hwdata,
  output logic                               hub_hsel,
  output logic                               hub_hreadyin,
  input  logic [31:0]                        hub_hrdata,
  input  logic                               hub_hreadyout,
  input  logic [1:0]                         hub_hresp,

  // ---- Recovery AHB interface (local byte address) ----
  output logic [RECOVERY_LOCAL_ADDR_WIDTH-1:0] recovery_haddr,
  output logic [1:0]                         recovery_htrans,
  output logic [2:0]                         recovery_hburst,
  output logic [2:0]                         recovery_hsize,
  output logic                               recovery_hwrite,
  output logic [31:0]                        recovery_hwdata,
  output logic                               recovery_hsel,
  output logic                               recovery_hreadyin,
  input  logic [31:0]                        recovery_hrdata,
  input  logic                               recovery_hreadyout,
  input  logic [1:0]                         recovery_hresp
);
  ////////////////////////////////////////////////////////////
  // Address map and AHB response states
  ////////////////////////////////////////////////////////////

  localparam logic [32:0] HUB_ADDR_LIMIT = HUB_BASE_ADDR + HUB_APERTURE_BYTES;

  localparam logic [1:0] AHB_RESP_OKAY  = 2'b00;
  localparam logic [1:0] AHB_RESP_ERROR = 2'b01;

  // The registered selection also identifies the two default-error phases.
  typedef enum logic [2:0] {
    RESP_IDLE,
    RESP_DEV0_CSR,
    RESP_HUB,
    RESP_RECOVERY,
    RESP_ERROR_FIRST,
    RESP_ERROR_FINAL
  } ahb_select_t;

  // Raw address decode.
  logic [32:0] addr_phase_byte_addr;
  logic addr_phase_hub_hit;
  logic addr_phase_dev0_csr_hit;
  logic addr_phase_recovery_hit;
  logic [2:0] addr_phase_hits;

  // Transfer qualification.
  logic addr_phase_active;
  logic addr_phase_word_valid;
  logic addr_phase_endpoint_enable;

  // Prepared address-phase metadata.
  ahb_select_t addr_phase_select;
  logic [HUB_WORD_ADDR_WIDTH-1:0] addr_phase_csr_word_addr;

  // Registered data-phase metadata.
  ahb_select_t data_phase_select_q;
  logic [HUB_WORD_ADDR_WIDTH-1:0] data_phase_csr_word_addr_q;

  ////////////////////////////////////////////////////////////
  // Address-phase decode and metadata preparation
  ////////////////////////////////////////////////////////////

  // Keep full-width byte bounds until a destination has been selected.
  assign addr_phase_byte_addr = 33'(combo_haddr);

  // Raw address hits are independent of transfer/profile qualification.
  assign addr_phase_hub_hit      = (addr_phase_byte_addr >= HUB_BASE_ADDR) && (addr_phase_byte_addr < HUB_ADDR_LIMIT);
  assign addr_phase_dev0_csr_hit = (addr_phase_byte_addr >= DEV0_CSR_BASE_ADDR) && (addr_phase_byte_addr < DEV0_CSR_ADDR_LIMIT);
  assign addr_phase_recovery_hit = (addr_phase_byte_addr >= RECOVERY_BASE_ADDR) && (addr_phase_byte_addr < RECOVERY_ADDR_LIMIT);
  assign addr_phase_hits         = {addr_phase_hub_hit, addr_phase_dev0_csr_hit, addr_phase_recovery_hit};

  // Control endpoints accept aligned 32-bit accesses only.
  // During reset, the AHB manager must drive HTRANS to IDLE.
  // Endpoint selection is independent of the ready-qualified register capture.
  assign addr_phase_active          = combo_hsel && combo_htrans[1];
  assign addr_phase_word_valid      = (combo_hsize == 3'd2) && (combo_haddr[1:0] == '0);
  assign addr_phase_endpoint_enable = addr_phase_active && addr_phase_word_valid;

  always_comb begin : prepare_address_phase
    // IDLE/BUSY, deselection, and non-CSR transfers carry no CSR address.
    addr_phase_select        = RESP_IDLE;
    addr_phase_csr_word_addr = '0;

    // Active requests default to ERROR; a qualified one-hot hit selects a slave.
    if (addr_phase_active) begin
      addr_phase_select = RESP_ERROR_FIRST;
    end

    dev0_csr_hsel  = 1'b0;
    hub_hsel       = 1'b0;
    recovery_hsel  = 1'b0;
    recovery_haddr = '0;

    // HSEL follows the current address; endpoints accept it only on global HREADY.
    // The complete HUB/recovery apertures include endpoint-owned padding and holes.
    case (addr_phase_hits)
      3'b100: begin
        hub_hsel = addr_phase_endpoint_enable;
        if (addr_phase_endpoint_enable) begin
          addr_phase_select        = RESP_HUB;
          addr_phase_csr_word_addr = HUB_WORD_ADDR_WIDTH'((addr_phase_byte_addr - HUB_BASE_ADDR) >> 2);
        end
      end

      3'b010: begin
        dev0_csr_hsel = addr_phase_endpoint_enable;
        if (addr_phase_endpoint_enable) begin
          addr_phase_select        = RESP_DEV0_CSR;
          addr_phase_csr_word_addr = HUB_WORD_ADDR_WIDTH'(4'((addr_phase_byte_addr - DEV0_CSR_BASE_ADDR) >> 2));
        end
      end

      3'b001: begin
        recovery_hsel = addr_phase_endpoint_enable;
        if (addr_phase_endpoint_enable) begin
          addr_phase_select = RESP_RECOVERY;
          recovery_haddr    = RECOVERY_LOCAL_ADDR_WIDTH'(addr_phase_byte_addr - RECOVERY_BASE_ADDR);
        end
      end

      // No-hit, multi-hit, and X/Z patterns select no endpoint and retain ERROR.
    endcase
  end

  // Forward a common HREADY to every slave. Do not gate HWDATA with the current
  // HSEL: write data belongs to the previously accepted address phase.

  // DEV0 CSR.
  assign dev0_csr_htrans   = combo_htrans;
  assign dev0_csr_hwrite   = combo_hwrite;
  assign dev0_csr_hreadyin = combo_hready;
  assign dev0_csr_hwdata   = combo_hwdata;

  // HUB Bank.
  assign hub_htrans   = combo_htrans;
  assign hub_hwrite   = combo_hwrite;
  assign hub_hreadyin = combo_hready;
  assign hub_hwdata   = combo_hwdata;

  // Recovery.
  assign recovery_htrans   = combo_htrans;
  assign recovery_hburst   = combo_hburst;
  assign recovery_hsize    = combo_hsize;
  assign recovery_hwrite   = combo_hwrite;
  assign recovery_hreadyin = combo_hready;
  assign recovery_hwdata   = combo_hwdata;

  ////////////////////////////////////////////////////////////
  // Address-to-data phase register boundary
  ////////////////////////////////////////////////////////////

  always_ff @(posedge clk or negedge rst_n) begin : register_selection
    if (!rst_n) begin
      data_phase_select_q        <= RESP_IDLE;
      data_phase_csr_word_addr_q <= '0;
    end else if (data_phase_select_q == RESP_ERROR_FIRST) begin
      // First ERROR drives HREADYOUT low, so its phase must advance without HREADY.
      data_phase_select_q <= RESP_ERROR_FINAL;
    end else if (combo_hready) begin
      // Capture the prepared metadata together, including idle data phases.
      data_phase_select_q        <= addr_phase_select;
      data_phase_csr_word_addr_q <= addr_phase_csr_word_addr;
    end
  end

  ////////////////////////////////////////////////////////////
  // Native CSR address forwarding and wait-state retention
  ////////////////////////////////////////////////////////////

  // During a wait state, keep driving the pending transfer's saved CSR address.
  // The next pipelined transfer may already select the same endpoint, so check
  // the stalled data-phase owner before forwarding the live address-phase address.
  always_comb begin : drive_dev0_csr_address
    if (!combo_hready && (data_phase_select_q == RESP_DEV0_CSR)) begin
      dev0_csr_haddr = 4'(data_phase_csr_word_addr_q);
    end else if (dev0_csr_hsel) begin
      dev0_csr_haddr = 4'(addr_phase_csr_word_addr);
    end else begin
      dev0_csr_haddr = '0;
    end
  end

  always_comb begin : drive_hub_address
    if (!combo_hready && (data_phase_select_q == RESP_HUB)) begin
      hub_haddr = data_phase_csr_word_addr_q;
    end else if (hub_hsel) begin
      hub_haddr = addr_phase_csr_word_addr;
    end else begin
      hub_haddr = '0;
    end
  end

  ////////////////////////////////////////////////////////////
  // Data-phase response mux
  ////////////////////////////////////////////////////////////

  // Select responses using the accepted owner, never the live address decode.
  // Asynchronous reset selects RESP_IDLE, which uses the zero-wait OKAY defaults.
  always_comb begin : select_response
    combo_hrdata    = '0;
    combo_hreadyout = 1'b1;
    combo_hresp     = AHB_RESP_ERROR;

    unique case (data_phase_select_q)
      RESP_IDLE: begin
        combo_hresp = AHB_RESP_OKAY;
      end

      RESP_DEV0_CSR: begin
        combo_hrdata    = dev0_csr_hrdata;
        combo_hreadyout = dev0_csr_hreadyout;
        combo_hresp     = dev0_csr_hresp;
      end

      RESP_HUB: begin
        combo_hrdata    = hub_hrdata;
        combo_hreadyout = hub_hreadyout;
        combo_hresp     = hub_hresp;
      end

      RESP_RECOVERY: begin
        combo_hrdata    = recovery_hrdata;
        combo_hreadyout = recovery_hreadyout;
        combo_hresp     = recovery_hresp;
      end

      // Only the default responder generates errors here; endpoint errors
      // are forwarded above without replacing their response sequence.
      RESP_ERROR_FIRST: begin
        combo_hreadyout = 1'b0;
        combo_hresp     = AHB_RESP_ERROR;
      end

      RESP_ERROR_FINAL: begin
        combo_hresp = AHB_RESP_ERROR;
      end

      default: begin
        combo_hresp = AHB_RESP_ERROR;
      end
    endcase
  end

  ////////////////////////////////////////////////////////////
  // Protocol assertions
  ////////////////////////////////////////////////////////////

  // Configuration checks.

  // Ensure the local address width is representable and covers the HUB aperture.
  `CALIPTRA_ASSERT_INIT(ComboAddressWidthCoversHubAperture_A,
                        (COMBO_LOCAL_ADDR_WIDTH > 0) &&
                        (COMBO_LOCAL_ADDR_WIDTH <= AXI_ADDR_WIDTH_MAX) &&
                        (HUB_ADDR_LIMIT <= (33'd1 << COMBO_LOCAL_ADDR_WIDTH)))

  // Ensure the DEV0 CSR, recovery, and HUB address regions do not overlap.
  `CALIPTRA_ASSERT_INIT(ControlAddressRegionsDoNotOverlap_A,
                        (DEV0_CSR_ADDR_LIMIT <= RECOVERY_BASE_ADDR) &&
                        (RECOVERY_ADDR_LIMIT <= HUB_BASE_ADDR))

  // Interface validity checks.

  // Ensure control, registered owner, and upstream response signals are known.
  `CALIPTRA_ASSERT(ControlAndResponseSignalsKnown_A,
                   !$isunknown({combo_hready, combo_hsel, data_phase_select_q,
                                combo_hreadyout, combo_hresp}),
                   clk, !rst_n,
                   "AHB control, registered owner, or response contains X or Z")

  // Ensure a selected transfer presents a known transfer type when accepted.
  `CALIPTRA_ASSERT(AcceptedTransferTypeKnown_A,
                   combo_hready && combo_hsel |-> !$isunknown(combo_htrans),
                   clk, !rst_n,
                   "Accepted AHB transfer has an unknown HTRANS value")

  // Ensure an active accepted transfer presents known address and control fields.
  `CALIPTRA_ASSERT(AcceptedAddressAndControlKnown_A,
                   combo_hready && combo_hsel && combo_htrans[1] |->
                     !$isunknown({combo_haddr, combo_hburst, combo_hsize,
                                  combo_hwrite}),
                   clk, !rst_n,
                   "Accepted active AHB transfer has an unknown address or control field")

  // Decode and endpoint-selection checks.

  // Ensure an address phase selects no more than one downstream endpoint.
  `CALIPTRA_ASSERT(AtMostOneEndpointSelected_A,
                   $onehot0({dev0_csr_hsel, hub_hsel, recovery_hsel}),
                   clk, !rst_n,
                   "AHB address decode selected more than one downstream endpoint")

  // Ensure invalid, inactive, or unsupported transfers select no endpoint.
  `CALIPTRA_ASSERT(UnqualifiedTransferSelectsNoEndpoint_A,
                   !addr_phase_endpoint_enable |->
                     ({dev0_csr_hsel, hub_hsel, recovery_hsel} == '0),
                   clk, !rst_n,
                   "Unqualified AHB transfer selected a downstream endpoint")

endmodule : usb_compound_ahb_decoder
