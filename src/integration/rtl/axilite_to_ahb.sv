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
// Description:
//   AXI4-Lite to AHB-Lite protocol converter.
//
//   The converter supports single-beat transactions with one
//   outstanding read and one outstanding write (AXI4-Lite profile).
//
//   The AXI subordinate interface uses the Caliptra `axi_if` SystemVerilog
//   interface.  The AHB master side uses discrete signals.
//
//   Clock/reset: a single clk/rst_n pair drives both the AXI and AHB sides
//   (same clock domain assumed).
//

module axilite_to_ahb
  import axi_pkg::*;
#(
    parameter int unsigned AW       = 32,   // Address width
    parameter int unsigned DW       = 32,   // Data width (must match AHB data width)
    parameter int unsigned IW       = 8,    // AXI ID width
    parameter int unsigned UW       = 32,   // AXI User width
    parameter int unsigned OSTD_R   = 1,
    parameter int unsigned OSTD_W   = 1
) (
    input  logic             clk,
    input  logic             rst_n,

    // ---- AXI Subordinate (using axi_if, no modport) ----
    axi_if.r_sub             axi_r,
    axi_if.w_sub             axi_w,

    // ---- AHB-Lite Master ----
    output logic [AW-1:0]    ahb_haddr,
    output logic [2:0]       ahb_hburst,
    output logic [2:0]       ahb_hsize,
    output logic [1:0]       ahb_htrans,
    output logic             ahb_hwrite,
    output logic [DW-1:0]    ahb_hwdata,
    output logic             ahb_hsel,
    output logic             ahb_hreadymux,   // Directly driven as hreadyin for single-master
    input  logic [DW-1:0]    ahb_hrdata,
    input  logic             ahb_hreadyout,
    input  logic [1:0]       ahb_hresp
);

    // ---------------------------------------------------------------
    // Localparams
    // ---------------------------------------------------------------
    localparam int unsigned BC = DW / 8;        // Byte count

    // AHB transaction encodings
    localparam logic [1:0] HTRANS_IDLE   = 2'b00;
    localparam logic [1:0] HTRANS_NONSEQ = 2'b10;

    // ---------------------------------------------------------------
    // Function: map AHB hresp to AXI resp
    //   AHB hresp==2'b00 -> OKAY, hresp==2'b01 -> SLVERR
    //   (AHB-Lite only defines OKAY and ERROR)
    // ---------------------------------------------------------------
    function automatic logic [1:0] ahb_resp_to_axi(input logic [1:0] hresp);
        return (hresp[0]) ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
    endfunction

    // =================================================================
    //  AXI4-Lite
    // =================================================================
    // -----------------------------------------------------------
    // FSM States
    // -----------------------------------------------------------
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_AHB_RD_ADDR,     // Address phase of AHB read
        ST_AHB_RD_DATA,     // Data phase of AHB read (wait hreadyout)
        ST_AXI_RD_RESP,     // Drive rvalid, wait rready
        ST_AHB_WR_ADDR,     // Address phase of AHB write
        ST_AHB_WR_DATA,     // Data phase of AHB write (wait hreadyout)
        ST_AXI_WR_RESP      // Drive bvalid, wait bready
    } lite_state_e;

    lite_state_e state_q, state_d;

    // Buffered AXI request context
    logic              ar_pending_q;
    logic [AW-1:0]     ar_addr_q;
    logic [IW-1:0]     ar_id_q;

    logic              aw_pending_q;
    logic [AW-1:0]     aw_addr_q;
    logic [IW-1:0]     aw_id_q;
    logic [2:0]        aw_size_q;

    logic              w_pending_q;
    logic [DW-1:0]     w_data_q;
    // Note: AXI wstrb is not captured -- AHB-Lite has no byte-strobe;
    // transfer size (hsize) and alignment serve this role instead.

    // Response capture
    logic [DW-1:0]     rdata_q;
    logic [1:0]        rresp_q;
    logic [1:0]        bresp_q;

    // Round-robin arbiter for fair read/write scheduling
    logic              rr_last_was_write_q;

    // -----------------------------------------------------------
    // AXI handshake -- accept AR / AW / W into pending buffers
    // -----------------------------------------------------------
    assign axi_r.arready = ~ar_pending_q & (state_q == ST_IDLE);
    assign axi_w.awready = ~aw_pending_q & (state_q == ST_IDLE);
    assign axi_w.wready  = ~w_pending_q  & (state_q == ST_IDLE);

    // Round-robin toggle: set on write completion, clear on read completion
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rr_last_was_write_q <= 1'b0;
        else if (state_q == ST_AXI_WR_RESP && axi_w.bvalid && axi_w.bready)
            rr_last_was_write_q <= 1'b1;
        else if (state_q == ST_AXI_RD_RESP && axi_r.rvalid && axi_r.rready)
            rr_last_was_write_q <= 1'b0;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_pending_q <= 1'b0;
            ar_addr_q    <= '0;
            ar_id_q      <= '0;
        end else if (axi_r.arvalid && axi_r.arready) begin
            ar_pending_q <= 1'b1;
            ar_addr_q    <= axi_r.araddr;
            ar_id_q      <= axi_r.arid;
        end else if (state_q == ST_AXI_RD_RESP && axi_r.rvalid && axi_r.rready) begin
            ar_pending_q <= 1'b0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_pending_q <= 1'b0;
            aw_addr_q    <= '0;
            aw_id_q      <= '0;
            aw_size_q    <= '0;
        end else if (axi_w.awvalid && axi_w.awready) begin
            aw_pending_q <= 1'b1;
            aw_addr_q    <= axi_w.awaddr;
            aw_id_q      <= axi_w.awid;
            aw_size_q    <= axi_w.awsize;
        end else if (state_q == ST_AXI_WR_RESP && axi_w.bvalid && axi_w.bready) begin
            aw_pending_q <= 1'b0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_pending_q <= 1'b0;
            w_data_q    <= '0;
        end else if (axi_w.wvalid && axi_w.wready) begin
            w_pending_q <= 1'b1;
            w_data_q    <= axi_w.wdata;
        end else if (state_q == ST_AXI_WR_RESP && axi_w.bvalid && axi_w.bready) begin
            w_pending_q <= 1'b0;
        end
    end

    // -----------------------------------------------------------
    // State machine
    // -----------------------------------------------------------
    always_comb begin
        state_d = state_q;
        unique case (state_q)
            ST_IDLE: begin
                if (aw_pending_q && w_pending_q && ar_pending_q) begin
                    // Both pending -- round-robin
                    if (rr_last_was_write_q)
                        state_d = ST_AHB_RD_ADDR;
                    else
                        state_d = ST_AHB_WR_ADDR;
                end else if (aw_pending_q && w_pending_q)
                    state_d = ST_AHB_WR_ADDR;
                else if (ar_pending_q)
                    state_d = ST_AHB_RD_ADDR;
            end

            // -- Read path --
            ST_AHB_RD_ADDR: begin
                // Address presented; if slave accepts immediately, move on
                if (ahb_hreadyout)
                    state_d = ST_AHB_RD_DATA;
            end
            ST_AHB_RD_DATA: begin
                if (ahb_hreadyout)
                    state_d = ST_AXI_RD_RESP;
            end
            ST_AXI_RD_RESP: begin
                if (axi_r.rvalid && axi_r.rready)
                    state_d = ST_IDLE;
            end

            // -- Write path --
            ST_AHB_WR_ADDR: begin
                if (ahb_hreadyout)
                    state_d = ST_AHB_WR_DATA;
            end
            ST_AHB_WR_DATA: begin
                if (ahb_hreadyout)
                    state_d = ST_AXI_WR_RESP;
            end
            ST_AXI_WR_RESP: begin
                if (axi_w.bvalid && axi_w.bready)
                    state_d = ST_IDLE;
            end

            default: state_d = ST_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_q <= ST_IDLE;
        else
            state_q <= state_d;
    end

    // -----------------------------------------------------------
    // Capture AHB read data / response
    // -----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_q <= '0;
            rresp_q <= '0;
        end else if (state_q == ST_AHB_RD_DATA && ahb_hreadyout) begin
            rdata_q <= ahb_hrdata;
            rresp_q <= ahb_resp_to_axi(ahb_hresp);
        end
    end

    // AHB error response is a 2-cycle protocol: hresp=1 with hready=0
    // then hresp=1 with hready=1. Capture error on the final beat.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bresp_q <= '0;
        end else if (state_q == ST_AHB_WR_DATA && ahb_hreadyout) begin
            bresp_q <= ahb_resp_to_axi(ahb_hresp);
        end
    end

    // -----------------------------------------------------------
    // AHB outputs
    // -----------------------------------------------------------
    always_comb begin
        ahb_haddr    = '0;
        ahb_hburst   = 3'b000;   // SINGLE
        ahb_hsize    = 3'b010;   // 32-bit default
        ahb_htrans   = HTRANS_IDLE;
        ahb_hwrite   = 1'b0;
        ahb_hwdata   = '0;
        ahb_hsel     = 1'b0;
        ahb_hreadymux = 1'b1;    // Always ready as master (single-master)

        case (state_q)
            ST_AHB_RD_ADDR: begin
                ahb_haddr  = ar_addr_q;
                ahb_htrans = HTRANS_NONSEQ;
                ahb_hwrite = 1'b0;
                ahb_hsel   = 1'b1;
                ahb_hsize  = 3'(  $clog2(BC));
            end
            ST_AHB_RD_DATA: begin
                // Hold hsel, deassert htrans (data phase)
                ahb_hsel     = 1'b1;
                ahb_hreadymux = ahb_hreadyout;
            end
            ST_AHB_WR_ADDR: begin
                ahb_haddr  = aw_addr_q;
                ahb_htrans = HTRANS_NONSEQ;
                ahb_hwrite = 1'b1;
                ahb_hsel   = 1'b1;
                ahb_hsize  = aw_size_q;
            end
            ST_AHB_WR_DATA: begin
                ahb_hwdata   = w_data_q;
                ahb_hsel     = 1'b1;
                ahb_hreadymux = ahb_hreadyout;
            end
            default: ;
        endcase
    end

    // -----------------------------------------------------------
    // AXI R channel
    // -----------------------------------------------------------
    assign axi_r.rvalid = (state_q == ST_AXI_RD_RESP);
    assign axi_r.rdata  = rdata_q;
    assign axi_r.rresp  = rresp_q;
    assign axi_r.rid    = ar_id_q;
    assign axi_r.ruser  = '0;
    assign axi_r.rlast  = 1'b1;

    // -----------------------------------------------------------
    // AXI B channel
    // -----------------------------------------------------------
    assign axi_w.bvalid = (state_q == ST_AXI_WR_RESP);
    assign axi_w.bresp  = bresp_q;
    assign axi_w.bid    = aw_id_q;
    assign axi_w.buser  = '0;

endmodule
