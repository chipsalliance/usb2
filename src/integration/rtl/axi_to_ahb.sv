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
//   AXI4 to AHB-Lite protocol converter.
//
//   Capabilities:
//   - Aligned FIXED, INCR (up to 256 beats), and WRAP bursts.
//   - Matching AXI/AHB data widths and a common clock/reset.
//   - Independent AR/AW queues, W/R beat buffers, and a B response FIFO.
//   - Empty bypass on all five AXI channel FIFOs.
//   - Burst-level round-robin read/write arbitration.
//   - Pipelined AHB SINGLE/NONSEQ transfers, up to one beat per clock.
//   - Response-credit backpressure and AHB wait-state handling.
//   - AWUSER/ARUSER allowlist filtering captured at address acceptance.
//   - Local SLVERR completion for denied bursts; denied reads return zero.
//   - Per-beat R responses and one B response with accumulated write errors.
//
//   Limits: legal burst geometry required; no WSTRB masking or unaligned conversion.
//   WUSER is ignored; the fabric must preserve AW/W transaction association.
//   RUSER/BUSER are zero.
//

`include "caliptra_prim_assert.sv"

module axi_to_ahb
  import axi_pkg::*;
#(
    parameter int unsigned AW                 = 32,
    parameter int unsigned DW                 = 32, // Must match AXI and AHB data widths.
    parameter int unsigned IW                 = 8,
    parameter int unsigned UW                 = 32,
    // FIFO entries: AR/AW requests, W/R beats, B burst responses.
    // Request depths do not cap total outstanding transactions.
    parameter int unsigned AR_FIFO_DEPTH      = 2,
    parameter int unsigned AW_FIFO_DEPTH      = 2,
    parameter int unsigned W_FIFO_DEPTH       = 3,
    parameter int unsigned R_FIFO_DEPTH       = 3,
    parameter int unsigned B_FIFO_DEPTH       = 3,
    parameter int unsigned NUM_PRIV_AXI_USERS = 4
) (
    input  logic          clk,
    input  logic          rst_n,

    // ---- AXI Subordinate ----
    axi_if.r_sub          axi_r,
    axi_if.w_sub          axi_w,

    // ---- AXI USER allowlist ----
    input  logic          enable_axi_user_filtering_i,
    input  logic [UW-1:0] priv_axi_users_i [NUM_PRIV_AXI_USERS],

    // ---- AHB-Lite Master ----
    output logic [AW-1:0] ahb_haddr,
    output logic [2:0]    ahb_hburst,
    output logic [2:0]    ahb_hsize,
    output logic [1:0]    ahb_htrans,
    output logic          ahb_hwrite,
    output logic [DW-1:0] ahb_hwdata,
    output logic          ahb_hsel,
    output logic          ahb_hreadymux, // Forwarded HREADYIN; no manager-inserted data stalls.
    input  logic [DW-1:0] ahb_hrdata,
    input  logic          ahb_hreadyout,
    input  logic [1:0]    ahb_hresp
);

    // -----------------------------------------------------------
    // Common constants and types
    // -----------------------------------------------------------
    localparam int unsigned AXI_STRB_W = DW / 8;
    localparam int unsigned AXI_RESP_W = 2;
    localparam int unsigned AXI_LAST_W = 1;

    // AHB transaction encodings
    localparam logic [1:0] HTRANS_IDLE   = 2'b00;
    localparam logic [1:0] HTRANS_NONSEQ = 2'b10;

    localparam int unsigned W_PAYLOAD_W = DW + AXI_STRB_W;
    localparam int unsigned W_FIFO_W    = W_PAYLOAD_W + AXI_LAST_W;
    localparam int unsigned R_FIFO_W    = DW + AXI_RESP_W + IW + AXI_LAST_W;
    localparam int unsigned B_FIFO_W    = AXI_RESP_W + IW;

    localparam int unsigned W_FIFO_DEPTH_W = $clog2(W_FIFO_DEPTH + 1);
    localparam int unsigned R_FIFO_DEPTH_W = $clog2(R_FIFO_DEPTH + 1);
    localparam int unsigned B_FIFO_DEPTH_W = $clog2(B_FIFO_DEPTH + 1);

    // Request context (ctx): one AXI burst's address, geometry, ID, and permission decision.
    // Queued in AR/AW FIFOs, then held in ap_ctx_q with addr tracking the current beat.
    typedef struct packed {
        logic                          reject; // Acceptance-time USER decision.
        logic [AW-1:0]                 addr;
        logic [$bits(axi_burst_e)-1:0] burst;
        logic [2:0]                    size;
        logic [7:0]                    len;    // Original AxLEN for WRAP geometry.
        logic [IW-1:0]                 id;
    } req_ctx_t;

    localparam int unsigned REQ_CTX_W = $bits(req_ctx_t);

    // Data-phase context (ctx): one beat's direction, final-beat flag, ID, and held write data.
    // Captured in dp_ctx_q on ap_accept; reject means permission denial, not an AHB response error.
    typedef struct packed {
        logic          write;
        logic          reject;
        logic          last;
        logic [IW-1:0] id;
        logic [DW-1:0] wdata;
    } dp_ctx_t;

    // Ingress signals.
    logic                          ar_fifo_wvalid, ar_fifo_wready;
    logic [REQ_CTX_W-1:0]          ar_fifo_wdata, ar_fifo_rdata;
    logic                          ar_fifo_rvalid, ar_fifo_rready;
    logic                          aw_fifo_wvalid, aw_fifo_wready;
    logic [REQ_CTX_W-1:0]          aw_fifo_wdata, aw_fifo_rdata;
    logic                          aw_fifo_rvalid, aw_fifo_rready;
    req_ctx_t                      ar_req, aw_req, ar_head, aw_head;
    logic [NUM_PRIV_AXI_USERS-1:0] ar_user_match, aw_user_match;
    logic                          ar_reject, aw_reject;

    logic                          w_fifo_wvalid, w_fifo_wready;
    logic [W_FIFO_W-1:0]           w_fifo_wdata, w_fifo_rdata;
    logic                          w_fifo_rvalid, w_fifo_rready;
    logic [W_FIFO_DEPTH_W-1:0]     w_fifo_depth;
    logic                          w_beat_last;
    logic [AXI_STRB_W-1:0]         w_beat_strb;
    logic [DW-1:0]                 w_beat_data;

    // Address-phase (ap_) signals.
    logic                          ap_busy_q, ap_busy_d;
    logic                          ap_write_q, ap_write_d;
    req_ctx_t                      ap_ctx_q, ap_ctx_d;
    logic [7:0]                    ap_beat_cnt_q, ap_beat_cnt_d; // Remaining beats minus one.
    logic [AW-1:0]                 ap_next_addr;
    logic                          ap_last_grant_write_q, ap_last_grant_write_d;
    logic                          ap_last;
    logic                          ap_can_grant;
    logic                          ap_wdata_available;
    logic                          ap_ar_grant, ap_aw_grant;
    logic                          ap_ar_pop, ap_aw_pop, ap_w_pop;
    logic                          ap_valid;
    logic                          ap_ahb;                       // HSEL qualification; HTRANS also needs credit.
    logic                          ap_credit;
    logic                          ap_accept;
    logic                          ap_r_credit, ap_b_credit;

    // Data-phase (dp_) signals.
    logic                          dp_valid_q;
    dp_ctx_t                       dp_ctx_q, dp_ctx_d;
    logic                          dp_complete;
    logic                          dp_advance;
    logic [AXI_RESP_W-1:0]         dp_resp;
    logic [AXI_RESP_W-1:0]         dp_resp_accum_q, dp_resp_accum_d;

    // Egress signals.
    logic [R_FIFO_W-1:0]           r_fifo_wdata, r_fifo_rdata;
    logic                          r_fifo_wvalid, r_fifo_wready;
    logic                          r_fifo_rvalid, r_fifo_rready;
    logic [R_FIFO_DEPTH_W-1:0]     r_fifo_depth;
    logic                          r_out_last;
    logic [IW-1:0]                 r_out_id;
    logic [AXI_RESP_W-1:0]         r_out_resp;
    logic [DW-1:0]                 r_out_data;

    logic [B_FIFO_W-1:0]           b_fifo_wdata, b_fifo_rdata;
    logic                          b_fifo_wvalid, b_fifo_wready;
    logic                          b_fifo_rvalid, b_fifo_rready;
    logic [B_FIFO_DEPTH_W-1:0]     b_fifo_depth;
    logic [IW-1:0]                 b_out_id;
    logic [AXI_RESP_W-1:0]         b_out_resp;

    // -----------------------------------------------------------
    // Stage 1: AXI ingress - authorization and AR/AW/W buffering
    // -----------------------------------------------------------
    for (genvar user_idx = 0;
         user_idx < NUM_PRIV_AXI_USERS;
         user_idx++) begin : gen_user_match
        assign ar_user_match[user_idx] = (axi_r.aruser == priv_axi_users_i[user_idx]);
        assign aw_user_match[user_idx] = (axi_w.awuser == priv_axi_users_i[user_idx]);
    end

    // USER authorization.
    always_comb begin
        ar_reject = 1'b1;
        aw_reject = 1'b1;
        unique case (enable_axi_user_filtering_i)
            1'b0: begin
                ar_reject = 1'b0;
                aw_reject = 1'b0;
            end
            1'b1: begin
                if (|ar_user_match) begin
                    ar_reject = 1'b0;
                end
                if (|aw_user_match) begin
                    aw_reject = 1'b0;
                end
            end
            default: begin end
        endcase
    end

    // AR request FIFO.
    assign ar_req.addr   = axi_r.araddr;
    assign ar_req.burst  = axi_r.arburst;
    assign ar_req.size   = axi_r.arsize;
    assign ar_req.len    = axi_r.arlen;
    assign ar_req.id     = axi_r.arid;
    assign ar_req.reject = ar_reject;

    assign ar_fifo_wdata  = ar_req;
    assign ar_head        = req_ctx_t'(ar_fifo_rdata);
    assign ar_fifo_wvalid = axi_r.arvalid;
    assign ar_fifo_rready = ap_ar_pop;
    assign axi_r.arready  = ar_fifo_wready;

    caliptra_prim_fifo_sync #(
        .Width             (REQ_CTX_W),
        .Pass              (1'b1),
        .Depth             (AR_FIFO_DEPTH),
        .OutputZeroIfEmpty (1'b1)
    ) u_ar_fifo (
        .clk_i    (clk),
        .rst_ni   (rst_n),
        .clr_i    (1'b0),
        .wvalid_i (ar_fifo_wvalid),
        .wready_o (ar_fifo_wready),
        .wdata_i  (ar_fifo_wdata),
        .rvalid_o (ar_fifo_rvalid),
        .rready_i (ar_fifo_rready),
        .rdata_o  (ar_fifo_rdata),
        .full_o   (),
        .depth_o  (),
        .err_o    ()
    );

    // AW request FIFO.
    assign aw_req.addr   = axi_w.awaddr;
    assign aw_req.burst  = axi_w.awburst;
    assign aw_req.size   = axi_w.awsize;
    assign aw_req.len    = axi_w.awlen;
    assign aw_req.id     = axi_w.awid;
    assign aw_req.reject = aw_reject;

    assign aw_fifo_wdata  = aw_req;
    assign aw_head        = req_ctx_t'(aw_fifo_rdata);
    assign aw_fifo_wvalid = axi_w.awvalid;
    assign aw_fifo_rready = ap_aw_pop;
    assign axi_w.awready  = aw_fifo_wready;

    caliptra_prim_fifo_sync #(
        .Width             (REQ_CTX_W),
        .Pass              (1'b1),
        .Depth             (AW_FIFO_DEPTH),
        .OutputZeroIfEmpty (1'b1)
    ) u_aw_fifo (
        .clk_i    (clk),
        .rst_ni   (rst_n),
        .clr_i    (1'b0),
        .wvalid_i (aw_fifo_wvalid),
        .wready_o (aw_fifo_wready),
        .wdata_i  (aw_fifo_wdata),
        .rvalid_o (aw_fifo_rvalid),
        .rready_i (aw_fifo_rready),
        .rdata_o  (aw_fifo_rdata),
        .full_o   (),
        .depth_o  (),
        .err_o    ()
    );

    // W data FIFO.
    assign w_fifo_wdata  = {axi_w.wlast, axi_w.wstrb, axi_w.wdata};
    assign w_fifo_wvalid = axi_w.wvalid;
    assign w_fifo_rready = ap_w_pop;
    assign axi_w.wready  = w_fifo_wready;

    caliptra_prim_fifo_sync #(
        .Width             (W_FIFO_W),
        .Pass              (1'b1),
        .Depth             (W_FIFO_DEPTH),
        .OutputZeroIfEmpty (1'b1)
    ) u_w_fifo (
        .clk_i    (clk),
        .rst_ni   (rst_n),
        .clr_i    (1'b0),
        .wvalid_i (w_fifo_wvalid),
        .wready_o (w_fifo_wready),
        .wdata_i  (w_fifo_wdata),
        .rvalid_o (w_fifo_rvalid),
        .rready_i (w_fifo_rready),
        .rdata_o  (w_fifo_rdata),
        .full_o   (),
        .depth_o  (w_fifo_depth),
        .err_o    ()
    );

    assign {w_beat_last, w_beat_strb, w_beat_data} = w_fifo_rdata;

    // -----------------------------------------------------------
    // Stage 2: Burst/address phase - grant, sequence, and AHB issue
    // -----------------------------------------------------------
    // Flow sections do not add registers; ap_ and dp_ are the AHB pipeline phases.
    axi_addr #(
        .AW (AW),
        .DW (DW)
    ) u_axi_addr (
        .i_last_addr (ap_ctx_q.addr),
        .i_size      (ap_ctx_q.size),
        .i_burst     (ap_ctx_q.burst),
        .i_len       (ap_ctx_q.len),
        .o_next_addr (ap_next_addr)
    );

    // AWLEN, not WLAST, controls write-burst completion.
    assign ap_last = (ap_beat_cnt_q == 8'd0);

    // A beat is available before credit gating; writes also need W FIFO data.
    assign ap_valid = ap_busy_q && (!ap_write_q || w_fifo_rvalid);
    assign ap_ahb   = ap_valid && !ap_ctx_q.reject;

    // Count the data-phase reservation; do not rely on same-cycle response draining.
    // Credit cannot shrink during an AHB wait, keeping a presented transfer valid.
    assign ap_r_credit = (32'(r_fifo_depth) + 32'(dp_valid_q && !dp_ctx_q.write)) < R_FIFO_DEPTH;
    assign ap_b_credit = (32'(b_fifo_depth) + 32'(dp_valid_q && dp_ctx_q.write && dp_ctx_q.last)) < B_FIFO_DEPTH;
    assign ap_credit   = ap_write_q ? (!ap_last || ap_b_credit) : ap_r_credit;

    // Hand the current beat to DP: accept AHB address/control, or advance a denied beat locally.
    // This is not completion of that beat's data phase or its AXI response.
    assign ap_accept    = ap_valid && ap_credit && (ap_ctx_q.reject ? dp_advance : ahb_hreadyout);
    // Select a new burst only when idle or accepting the current burst's final beat.
    assign ap_can_grant = !ap_busy_q || (ap_accept && ap_last);
    // Consume W data when captured into DP, not when its AHB data phase completes.
    assign ap_w_pop     = ap_accept && ap_write_q;

    // Only stored W beats remaining after this pop count toward a new grant.
    assign ap_wdata_available = w_fifo_depth > W_FIFO_DEPTH_W'(ap_w_pop);

    // Response credit gates issue, not grants; a granted burst cannot be preempted.
    always_comb begin
        ap_ar_grant = 1'b0;
        ap_aw_grant = 1'b0;
        if (ap_can_grant) begin
            if (ar_fifo_rvalid && aw_fifo_rvalid && ap_wdata_available) begin
                if (ap_last_grant_write_q) begin
                    ap_ar_grant = 1'b1;
                end else begin
                    ap_aw_grant = 1'b1;
                end
            end else if (ar_fifo_rvalid) begin
                ap_ar_grant = 1'b1;
            end else if (aw_fifo_rvalid && ap_wdata_available) begin
                ap_aw_grant = 1'b1;
            end
        end
    end

    always_comb begin
        ap_busy_d             = ap_busy_q;
        ap_write_d            = ap_write_q;
        ap_ctx_d              = ap_ctx_q;
        ap_beat_cnt_d         = ap_beat_cnt_q;
        ap_last_grant_write_d = ap_last_grant_write_q;
        ap_ar_pop             = 1'b0;
        ap_aw_pop             = 1'b0;

        if (ap_accept) begin
            // This edge accepts AHB address/control with HREADYOUT high, or advances a denied beat locally.
            if (ap_last) begin
                // The final beat enters the data phase; release the sequencer, not the pending data/response.
                ap_busy_d = 1'b0;
            end else begin
                // More beats remain: prepare the next address even after an AHB error or permission denial.
                ap_beat_cnt_d = ap_beat_cnt_q - 8'd1;
                ap_ctx_d.addr = ap_next_addr;
            end
        end

        // Later grant assignments override the updates above, keeping busy with the new context to avoid an idle cycle.
        // Preserve the head's acceptance-time policy decision, including FIFO bypass.
        if (ap_ar_grant) begin
            ap_ar_pop             = 1'b1;
            ap_ctx_d              = ar_head;
            ap_beat_cnt_d         = ar_head.len;
            ap_write_d            = 1'b0;
            ap_busy_d             = 1'b1;
            ap_last_grant_write_d = 1'b0;
        end else if (ap_aw_grant) begin
            ap_aw_pop             = 1'b1;
            ap_ctx_d              = aw_head;
            ap_beat_cnt_d         = aw_head.len;
            ap_write_d            = 1'b1;
            ap_busy_d             = 1'b1;
            ap_last_grant_write_d = 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ap_busy_q             <= 1'b0;
            ap_write_q            <= 1'b0;
            ap_ctx_q              <= '0;
            ap_beat_cnt_q         <= '0;
            ap_last_grant_write_q <= 1'b0;
        end else begin
            ap_busy_q             <= ap_busy_d;
            ap_write_q            <= ap_write_d;
            ap_ctx_q              <= ap_ctx_d;
            ap_beat_cnt_q         <= ap_beat_cnt_d;
            ap_last_grant_write_q <= ap_last_grant_write_d;
        end
    end

    // Hide rejected addresses even when HTRANS is IDLE.
    assign ahb_hsel      = ap_ahb;
    assign ahb_htrans    = (ap_ahb && ap_credit) ? HTRANS_NONSEQ : HTRANS_IDLE;
    assign ahb_haddr     = ap_ctx_q.reject ? '0 : ap_ctx_q.addr;
    assign ahb_hwrite    = ap_ahb && ap_write_q;
    assign ahb_hsize     = ap_ctx_q.reject ? 3'b010 : ap_ctx_q.size;
    assign ahb_hburst    = 3'b000; // SINGLE
    assign ahb_hreadymux = ahb_hreadyout;

    // -----------------------------------------------------------
    // Stage 3: AHB data phase - held data, completion, and errors
    // -----------------------------------------------------------
    function automatic logic [AXI_RESP_W-1:0] ahb_resp_to_axi(input logic [1:0] hresp);
        return (hresp == 2'b00) ? AXI_RESP_OKAY : AXI_RESP_SLVERR;
    endfunction

    // The valid beat finishes its data phase on this edge: HREADYOUT ends an AHB transfer;
    // a denied/local beat finishes without AHB. This does not mean AXI accepted the response.
    assign dp_complete = dp_valid_q && (dp_ctx_q.reject || ahb_hreadyout);
    // DP can be replaced because it is empty or its current beat is completing.
    // This is readiness, not a transfer; ap_accept determines whether a new beat fills the slot.
    assign dp_advance  = !dp_valid_q || dp_complete;

    always_comb begin
        dp_ctx_d.write      = ap_write_q;
        dp_ctx_d.reject     = ap_ctx_q.reject;
        dp_ctx_d.last       = ap_last;
        dp_ctx_d.id         = ap_ctx_q.id;
        dp_ctx_d.wdata      = (ap_write_q && !ap_ctx_q.reject) ? w_beat_data : '0;
    end

    // HWDATA belongs to the data phase, not the current address phase.
    assign ahb_hwdata = dp_ctx_q.wdata;

    // Denied beats synthesize SLVERR; other beats translate the AHB data-phase response.
    assign dp_resp = dp_ctx_q.reject ? AXI_RESP_SLVERR : ahb_resp_to_axi(ahb_hresp);

    // The accumulator follows write data phases, not sequencer grants.
    // On the final beat, B captures the accumulated/final status while this register clears.
    always_comb begin
        dp_resp_accum_d = dp_resp_accum_q;
        if (dp_complete && dp_ctx_q.write) begin
            dp_resp_accum_d = dp_ctx_q.last ? 2'b00 : (dp_resp_accum_q | dp_resp);
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dp_valid_q      <= 1'b0;
            dp_ctx_q        <= '0;
            dp_resp_accum_q <= '0;
        end else begin
            // An available slot takes a new beat or becomes empty; a stalled beat remains valid.
            if (dp_advance) begin
                dp_valid_q <= ap_accept;
            end
            // Capture metadata and W data together at the address-phase handoff.
            if (ap_accept) begin
                dp_ctx_q <= dp_ctx_d;
            end
            dp_resp_accum_q <= dp_resp_accum_d;
        end
    end

    // -----------------------------------------------------------
    // Stage 4: AXI egress - response buffering and R/B delivery
    // -----------------------------------------------------------
    // R response FIFO.
    // Each completed read beat produces one R response, independently of AXI RREADY.
    assign r_fifo_wvalid = dp_complete && !dp_ctx_q.write;
    assign r_fifo_wdata  = {dp_ctx_q.last, dp_ctx_q.id, dp_resp, (dp_ctx_q.reject ? {DW{1'b0}} : ahb_hrdata)};

    caliptra_prim_fifo_sync #(
        .Width             (R_FIFO_W),
        .Pass              (1'b1),
        .Depth             (R_FIFO_DEPTH),
        .OutputZeroIfEmpty (1'b1)
    ) u_r_resp_fifo (
        .clk_i    (clk),
        .rst_ni   (rst_n),
        .clr_i    (1'b0),
        .wvalid_i (r_fifo_wvalid),
        .wready_o (r_fifo_wready),
        .wdata_i  (r_fifo_wdata),
        .rvalid_o (r_fifo_rvalid),
        .rready_i (r_fifo_rready),
        .rdata_o  (r_fifo_rdata),
        .full_o   (),
        .depth_o  (r_fifo_depth),
        .err_o    ()
    );

    assign {r_out_last, r_out_id, r_out_resp, r_out_data} = r_fifo_rdata;
    assign axi_r.rvalid  = r_fifo_rvalid;
    assign axi_r.rdata   = r_out_data;
    assign axi_r.rresp   = r_out_resp;
    assign axi_r.rid     = r_out_id;
    assign axi_r.rlast   = r_out_last;
    assign axi_r.ruser   = '0;
    assign r_fifo_rready = axi_r.rready;

    // B response FIFO.
    // Only the final write beat produces B; the FIFO holds it if AXI BREADY is low.
    assign b_fifo_wvalid = dp_complete && dp_ctx_q.write && dp_ctx_q.last;
    assign b_fifo_wdata  = {dp_ctx_q.id, dp_resp_accum_q | dp_resp};

    caliptra_prim_fifo_sync #(
        .Width             (B_FIFO_W),
        .Pass              (1'b1),
        .Depth             (B_FIFO_DEPTH),
        .OutputZeroIfEmpty (1'b1)
    ) u_b_resp_fifo (
        .clk_i    (clk),
        .rst_ni   (rst_n),
        .clr_i    (1'b0),
        .wvalid_i (b_fifo_wvalid),
        .wready_o (b_fifo_wready),
        .wdata_i  (b_fifo_wdata),
        .rvalid_o (b_fifo_rvalid),
        .rready_i (b_fifo_rready),
        .rdata_o  (b_fifo_rdata),
        .full_o   (),
        .depth_o  (b_fifo_depth),
        .err_o    ()
    );

    assign {b_out_id, b_out_resp} = b_fifo_rdata;
    assign axi_w.bvalid  = b_fifo_rvalid;
    assign axi_w.bresp   = b_out_resp;
    assign axi_w.bid     = b_out_id;
    assign axi_w.buser   = '0;
    assign b_fifo_rready = axi_w.bready;

    // -----------------------------------------------------------
    // Assertions
    // -----------------------------------------------------------
    // The AR request FIFO must have positive depth.
    `CALIPTRA_ASSERT_INIT(ArFifoDepthPositive_A, AR_FIFO_DEPTH > 0)
    // The AW request FIFO must have positive depth.
    `CALIPTRA_ASSERT_INIT(AwFifoDepthPositive_A, AW_FIFO_DEPTH > 0)
    // W storage is required before granting a write.
    `CALIPTRA_ASSERT_INIT(WFifoDepthPositive_A, W_FIFO_DEPTH > 0)
    // Read issue requires at least one R response slot.
    `CALIPTRA_ASSERT_INIT(RFifoDepthPositive_A, R_FIFO_DEPTH > 0)
    // Final write issue requires at least one B response slot.
    `CALIPTRA_ASSERT_INIT(BFifoDepthPositive_A, B_FIFO_DEPTH > 0)

    // The USER allowlist must contain at least one entry.
    `CALIPTRA_ASSERT_INIT(NumPrivAxiUsers_A, NUM_PRIV_AXI_USERS > 0)
    // Both address USER fields must match the configured comparison width.
    `CALIPTRA_ASSERT_INIT(UserWidthsMatch_A,
        ($bits(axi_r.aruser) == UW) && ($bits(axi_w.awuser) == UW))

    // Filtering enable must be known at every AR/AW acceptance.
    `CALIPTRA_ASSERT(EnableKnownAtAddress_A,
        ((axi_r.arvalid && axi_r.arready) || (axi_w.awvalid && axi_w.awready))
        |-> !$isunknown(enable_axi_user_filtering_i), clk, !rst_n)

    // An accepted read must have known ARUSER when filtering is enabled.
    `CALIPTRA_ASSERT(ReadUserKnownAtAddress_A,
        (axi_r.arvalid && axi_r.arready && (enable_axi_user_filtering_i === 1'b1))
        |-> !$isunknown(axi_r.aruser), clk, !rst_n)

    // An accepted write must have known AWUSER when filtering is enabled.
    `CALIPTRA_ASSERT(WriteUserKnownAtAddress_A,
        (axi_w.awvalid && axi_w.awready && (enable_axi_user_filtering_i === 1'b1))
        |-> !$isunknown(axi_w.awuser), clk, !rst_n)

    for (genvar user_idx = 0;
         user_idx < NUM_PRIV_AXI_USERS;
         user_idx++) begin : gen_policy_assert
        // Every allowlist entry must be known at a filtered address acceptance.
        `CALIPTRA_ASSERT(ListEntryKnownAtAddress_A,
            (((axi_r.arvalid && axi_r.arready) || (axi_w.awvalid && axi_w.awready))
             && (enable_axi_user_filtering_i === 1'b1))
            |-> !$isunknown(priv_axi_users_i[user_idx]), clk, !rst_n)
    end

    // Only one grant allowed at a time.
    `CALIPTRA_ASSERT(ReadWriteGrantsExclusive_A, !(ap_ar_grant && ap_aw_grant), clk, !rst_n)

    // The granted FIFO head must have a known reject decision.
    `CALIPTRA_ASSERT(RejectKnownAtGrant_A,
        (ap_ar_grant || ap_aw_grant)
        |-> !$isunknown(ap_ar_grant ? ar_head.reject : aw_head.reject), clk, !rst_n)

    // The next cycle must hold an active burst with the granted reject decision.
    `CALIPTRA_ASSERT(GrantCapturesReject_A,
        (ap_ar_grant || ap_aw_grant)
        |=> (ap_busy_q && (ap_ctx_q.reject == $past(ap_ar_grant ? ar_head.reject : aw_head.reject))),
        clk, !rst_n)

    // Denied requests select no AHB target and drive idle/default address controls.
    // A preceding authorized data phase may still be active.
    `CALIPTRA_ASSERT(DeniedRequestDoesNotSelectAhb_A,
        (ap_busy_q && ap_ctx_q.reject)
        |-> (!ahb_hsel && (ahb_htrans == HTRANS_IDLE)
             && (ahb_haddr == '0) && !ahb_hwrite
             && (ahb_hsize == 3'b010) && (ahb_hburst == 3'b000)), clk, !rst_n)
    // A denied data phase drives zero HWDATA.
    `CALIPTRA_ASSERT(DeniedBeatDrivesNoWriteData_A,
        (dp_valid_q && dp_ctx_q.reject) |-> (ahb_hwdata == '0), clk, !rst_n)

    // Each consumed W beat's WLAST must match the AWLEN-derived final-beat flag.
    `CALIPTRA_ASSERT(WriteLastPlacement_A,
        (w_fifo_rvalid && w_fifo_rready) |-> (w_beat_last == ap_last),
        clk, !rst_n)

    // Every valid read data phase has writable R FIFO capacity.
    `CALIPTRA_ASSERT(ReadDataHasRSlot_A,
        (dp_valid_q && !dp_ctx_q.write) |-> r_fifo_wready, clk, !rst_n)
    // Every final write data phase has writable B FIFO capacity.
    `CALIPTRA_ASSERT(WriteFinalDataHasBSlot_A,
        (dp_valid_q && dp_ctx_q.write && dp_ctx_q.last) |-> b_fifo_wready, clk, !rst_n)

    // Waited NONSEQ holds HTRANS/HADDR/HWRITE/HSIZE/HBURST, including through ERROR.
    `CALIPTRA_ASSERT(AddressPhaseHeldDuringWait_A,
        ((ahb_htrans == HTRANS_NONSEQ) && !ahb_hreadyout)
        |=> ((ahb_htrans == HTRANS_NONSEQ) && $stable(ahb_haddr) && $stable(ahb_hwrite)
             && $stable(ahb_hsize) && $stable(ahb_hburst)), clk, !rst_n)
    // HWDATA stays stable while a valid data phase waits to complete.
    `CALIPTRA_ASSERT(WriteDataHeldDuringWait_A,
        (dp_valid_q && !dp_complete) |=> $stable(ahb_hwdata), clk, !rst_n)

    // An unaccepted beat stays valid with unchanged context, count, and direction.
    `CALIPTRA_ASSERT(BlockedBeatHolds_A,
        (ap_valid && !ap_accept)
        |=> (ap_valid && $stable(ap_ctx_q) && $stable(ap_beat_cnt_q) && $stable(ap_write_q)),
        clk, !rst_n)

    // An authorized beat is taken only with HSEL, NONSEQ, and HREADYOUT asserted.
    `CALIPTRA_ASSERT(AhbBeatTakenOnAcceptance_A,
        (ap_accept && !ap_ctx_q.reject)
        |-> ((ahb_htrans == HTRANS_NONSEQ) && ahb_hsel && ahb_hreadyout), clk, !rst_n)
    // A taken beat requires the data-phase stage to be empty or completing.
    `CALIPTRA_ASSERT(TakeIntoFreeDataPhase_A,
        ap_accept |-> dp_advance, clk, !rst_n)
    // After a stage advance, dp_valid reflects whether a beat was taken.
    `CALIPTRA_ASSERT(DataPhaseFollowsTake_A,
        dp_advance |=> (dp_valid_q == $past(ap_accept)), clk, !rst_n)

    // A valid read data phase requests an R response exactly when it completes.
    `CALIPTRA_ASSERT(ReadCompletionPushesOnce_A,
        (dp_valid_q && !dp_ctx_q.write) |-> (r_fifo_wvalid == dp_complete), clk, !rst_n)
    // During a write data phase, B is requested exactly on final-beat completion.
    `CALIPTRA_ASSERT(WriteCompletionPushesOnce_A,
        (dp_valid_q && dp_ctx_q.write) |-> (b_fifo_wvalid == (dp_complete && dp_ctx_q.last)),
        clk, !rst_n)
    // An empty data-phase stage drives neither response FIFO's write-valid.
    `CALIPTRA_ASSERT(IdleDataPhasePushesNothing_A,
        !dp_valid_q |-> (!r_fifo_wvalid && !b_fifo_wvalid), clk, !rst_n)

    // -----------------------------------------------------------
    // Coverage
    // -----------------------------------------------------------
    // Observe credit-blocked read issue followed by a later AHB read completion.
    `CALIPTRA_COVER(ReadIssueDeferredThenCompleted_C,
        (ap_ahb && !ap_write_q && !ap_credit)
        ##[1:$] (dp_valid_q && !dp_ctx_q.write && !dp_ctx_q.reject && ahb_hreadyout), clk, !rst_n)
    // Observe credit-blocked final-write issue followed by a later final AHB write completion.
    `CALIPTRA_COVER(WriteFinalIssueDeferredThenCompleted_C,
        (ap_ahb && ap_write_q && ap_last && !ap_credit)
        ##[1:$] (dp_valid_q && dp_ctx_q.write && dp_ctx_q.last && !dp_ctx_q.reject && ahb_hreadyout), clk, !rst_n)

    // Observe AHB address acceptance and preceding AHB data completion together.
    `CALIPTRA_COVER(AddressOverlapsData_C,
        ap_accept && ap_ahb && dp_complete && !dp_ctx_q.reject, clk, !rst_n)
    // Observe a grant on final-beat issue; this does not require next-cycle AHB acceptance.
    `CALIPTRA_COVER(BurstChainedWithoutBubble_C,
        ap_accept && ap_last && (ap_ar_grant || ap_aw_grant), clk, !rst_n)
    // Observe a denied beat presented while an AHB data phase remains active.
    `CALIPTRA_COVER(DeniedBeatFollowsAhbBeat_C,
        ap_valid && ap_ctx_q.reject && dp_valid_q && !dp_ctx_q.reject, clk, !rst_n)

endmodule
