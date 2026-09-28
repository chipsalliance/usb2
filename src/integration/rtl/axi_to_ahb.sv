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
//   The converter accepts FIXED, INCR, and WRAP bursts and queues up to
//   OSTD_R read and OSTD_W write requests. Burst beats are issued as
//   individual NONSEQ AHB transfers; the AHB side is single-outstanding,
//   so requests are serialized.
//
//   The AXI subordinate interface uses the Caliptra `axi_if` SystemVerilog
//   interface.  The AHB master side uses discrete signals.
//
//   Clock/reset: a single clk/rst_n pair drives both the AXI and AHB sides
//   (same clock domain assumed).
//
//   AWUSER/ARUSER filtering: each request's USER is compared against an
//   exact-match allowlist when its address is accepted, and the decision is
//   stored with the request. A low enable_axi_user_filtering_i allows all
//   requests. Zero and all-ones are ordinary entries; NUM_PRIV_AXI_USERS must
//   be positive and every entry participates. Denied bursts complete locally
//   with SLVERR (zero read data) and never select AHB.
//

`include "caliptra_prim_assert.sv"

module axi_to_ahb
  import axi_pkg::*;
#(
    parameter int unsigned AW       = 32,   // Address width
    parameter int unsigned DW       = 32,   // Data width (must match AHB data width)
    parameter int unsigned IW       = 8,    // AXI ID width
    parameter int unsigned UW       = 32,   // AXI User width
    parameter int unsigned OSTD_R   = 2,    // Read request queue depth
    parameter int unsigned OSTD_W   = 2,    // Write request queue depth
    parameter int unsigned NUM_PRIV_AXI_USERS = 4
) (
    input  logic             clk,
    input  logic             rst_n,

    // ---- AXI Subordinate (axi_if read/write subordinate modports) ----
    axi_if.r_sub             axi_r,
    axi_if.w_sub             axi_w,

    // ---- AXI USER allowlist ----
    input  logic             enable_axi_user_filtering_i,
    input  logic [UW-1:0]    priv_axi_users_i [NUM_PRIV_AXI_USERS],

    // ---- AHB-Lite Master ----
    output logic [AW-1:0]    ahb_haddr,
    output logic [2:0]       ahb_hburst,
    output logic [2:0]       ahb_hsize,
    output logic [1:0]       ahb_htrans,
    output logic             ahb_hwrite,
    output logic [DW-1:0]    ahb_hwdata,
    output logic             ahb_hsel,
    output logic             ahb_hreadymux,   // Subordinate HREADYIN; low while the subordinate or the bridge stalls the data phase
    input  logic [DW-1:0]    ahb_hrdata,
    input  logic             ahb_hreadyout,
    input  logic [1:0]       ahb_hresp
);

    // ---------------------------------------------------------------
    // Localparams
    // ---------------------------------------------------------------
    localparam int unsigned BC = DW / 8;        // Bytes per data word

    // AHB transaction encodings
    localparam logic [1:0] HTRANS_IDLE   = 2'b00;
    localparam logic [1:0] HTRANS_NONSEQ = 2'b10;

    // -----------------------------------------------------------
    // Types
    // -----------------------------------------------------------
    localparam int unsigned W_CTX_W  = DW + BC;              // wdata, wstrb
    localparam int unsigned W_FIFO_W = W_CTX_W + 1;
    localparam int unsigned R_RESP_W = DW + 2 + IW + 1;
    localparam int unsigned B_RESP_W = 2 + IW;

    typedef struct packed {
        logic                          reject; // USER authorization failed at address acceptance
        logic [AW-1:0]                 addr;
        logic [$bits(axi_burst_e)-1:0] burst;
        logic [2:0]                    size;
        logic [7:0]                    len;
        logic [IW-1:0]                 id;
    } req_ctx_t;

    localparam int unsigned REQ_CTX_W = $bits(req_ctx_t);

    typedef enum logic [2:0] {
        FSM_IDLE,
        FSM_RD_ADDR,
        FSM_RD_DATA,
        FSM_WR_ADDR,
        FSM_WR_DATA,
        FSM_RD_REJECT,
        FSM_WR_REJECT,
        FSM_WR_REJECT_RESP
    } fsm_state_e;

    // Request queues and policy decisions.
    logic                      ar_fifo_wvalid, ar_fifo_wready;
    logic [REQ_CTX_W-1:0]       ar_fifo_wdata, ar_fifo_rdata;
    logic                      ar_fifo_rvalid, ar_fifo_rready;
    logic                      aw_fifo_wvalid, aw_fifo_wready;
    logic [REQ_CTX_W-1:0]       aw_fifo_wdata, aw_fifo_rdata;
    logic                      aw_fifo_rvalid, aw_fifo_rready;
    req_ctx_t                  ar_req, aw_req, ar_head, aw_head;
    logic [NUM_PRIV_AXI_USERS-1:0] ar_user_match, aw_user_match;
    logic                      ar_reject, aw_reject;

    // Write data queue.
    logic                      w_fifo_wvalid;
    logic [W_FIFO_W-1:0]        w_fifo_wdata_pack, w_fifo_rdata_pack;
    logic                      w_fifo_rvalid_pack, w_fifo_rready_pack;
    logic                      w_fifo_wready_pack;
    logic                      w_beat_last;
    logic [BC-1:0]             w_beat_strb;
    logic [DW-1:0]             w_beat_data;

    // Serialized transaction control and datapath.
    fsm_state_e                fsm_q, fsm_d;
    req_ctx_t                  active_ctx_q, active_ctx_d; // addr tracks the current beat
    logic [7:0]                beat_cnt_q, beat_cnt_d; // Beats remaining minus one.
    logic [1:0]                resp_accum_q, resp_accum_d;
    logic [AW-1:0]             next_addr;
    logic                      rr_last_was_write_q, rr_last_was_write_d;
    logic                      grant_rd, grant_wr;
    logic                      ar_fifo_pop, aw_fifo_pop, w_fifo_pop;
    logic                      last_beat;

    // Response queues.
    logic [R_RESP_W-1:0]        r_resp_wdata, r_resp_rdata;
    logic                      r_resp_wvalid, r_resp_wready;
    logic                      r_resp_rvalid, r_resp_rready;
    logic                      r_out_rlast;
    logic [IW-1:0]             r_out_rid;
    logic [1:0]                r_out_rresp;
    logic [DW-1:0]             r_out_rdata;
    logic [B_RESP_W-1:0]        b_resp_wdata, b_resp_rdata;
    logic                      b_resp_wvalid, b_resp_wready;
    logic                      b_resp_rvalid, b_resp_rready;
    logic [IW-1:0]             b_out_bid;
    logic [1:0]                b_out_bresp;

    function automatic logic [1:0] ahb_resp_to_axi(input logic [1:0] hresp);
        return (hresp == 2'b00) ? AXI_RESP_OKAY : AXI_RESP_SLVERR;
    endfunction

    for (genvar user_idx = 0;
         user_idx < NUM_PRIV_AXI_USERS;
         user_idx++) begin : gen_user_match
        assign ar_user_match[user_idx] = (axi_r.aruser == priv_axi_users_i[user_idx]);
        assign aw_user_match[user_idx] = (axi_w.awuser == priv_axi_users_i[user_idx]);
    end

    // A request is rejected unless filtering is disabled or its USER matches
    // an allowlist entry.
    always_comb begin
        ar_reject = 1'b1;
        aw_reject = 1'b1;
        unique case (enable_axi_user_filtering_i)
            1'b0: begin
                ar_reject = 1'b0;
                aw_reject = 1'b0;
            end
            1'b1: begin
                if (|ar_user_match)
                    ar_reject = 1'b0;
                if (|aw_user_match)
                    aw_reject = 1'b0;
            end
            default: begin end
        endcase
    end

    assign ar_fifo_wdata = ar_req;
    assign aw_fifo_wdata = aw_req;
    assign ar_head       = req_ctx_t'(ar_fifo_rdata);
    assign aw_head       = req_ctx_t'(aw_fifo_rdata);

    // AR request FIFO.
    assign ar_req.addr  = axi_r.araddr;
    assign ar_req.burst = axi_r.arburst;
    assign ar_req.size  = axi_r.arsize;
    assign ar_req.len   = axi_r.arlen;
    assign ar_req.id    = axi_r.arid;
    assign ar_req.reject = ar_reject;

    assign ar_fifo_wvalid = axi_r.arvalid;
    assign axi_r.arready  = ar_fifo_wready;

    caliptra_prim_fifo_sync #(
        .Width           (REQ_CTX_W),
        .Pass            (1'b0),
        .Depth           (OSTD_R),
        .OutputZeroIfEmpty(1'b1)
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

    // -----------------------------------------------------------
    // AW Request FIFO
    // -----------------------------------------------------------
    assign aw_req.addr  = axi_w.awaddr;
    assign aw_req.burst = axi_w.awburst;
    assign aw_req.size  = axi_w.awsize;
    assign aw_req.len   = axi_w.awlen;
    assign aw_req.id    = axi_w.awid;
    assign aw_req.reject = aw_reject;

    assign aw_fifo_wvalid  = axi_w.awvalid;
    assign axi_w.awready   = aw_fifo_wready;

    caliptra_prim_fifo_sync #(
        .Width           (REQ_CTX_W),
        .Pass            (1'b0),
        .Depth           (OSTD_W),
        .OutputZeroIfEmpty(1'b1)
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

    // -----------------------------------------------------------
    // W Data FIFO -- buffers up to OSTD_W + 1 write-data beats so the
    // AW and W channels can decouple. Further beats are back-pressured
    // on WREADY.
    // -----------------------------------------------------------
    assign w_fifo_wdata_pack = {axi_w.wlast, axi_w.wstrb, axi_w.wdata};
    assign w_fifo_wvalid     = axi_w.wvalid;
    assign axi_w.wready      = w_fifo_wready_pack;

    caliptra_prim_fifo_sync #(
        .Width           (W_FIFO_W),
        .Pass            (1'b1),       // Allow passthrough for low latency
        .Depth           (OSTD_W + 1), // +1 to allow AW/W decoupling
        .OutputZeroIfEmpty(1'b1)
    ) u_w_fifo (
        .clk_i    (clk),
        .rst_ni   (rst_n),
        .clr_i    (1'b0),
        .wvalid_i (w_fifo_wvalid),
        .wready_o (w_fifo_wready_pack),
        .wdata_i  (w_fifo_wdata_pack),
        .rvalid_o (w_fifo_rvalid_pack),
        .rready_i (w_fifo_rready_pack),
        .rdata_o  (w_fifo_rdata_pack),
        .full_o   (),
        .depth_o  (),
        .err_o    ()
    );

    // Unpack W FIFO read port
    assign {w_beat_last, w_beat_strb, w_beat_data} = w_fifo_rdata_pack;

    axi_addr #(
        .AW(AW),
        .DW(DW)
    ) u_axi_addr (
        .i_last_addr (active_ctx_q.addr),
        .i_size      (active_ctx_q.size),
        .i_burst     (active_ctx_q.burst),
        .i_len       (active_ctx_q.len),
        .o_next_addr (next_addr)
    );

    // -----------------------------------------------------------
    // Read response FIFO -- holds up to OSTD_R + 1 R beats so AHB
    // reads can continue while RREADY is low. When it is full, the
    // FSM stalls the AHB data phase.
    // -----------------------------------------------------------
    caliptra_prim_fifo_sync #(
        .Width           (R_RESP_W),
        .Pass            (1'b1),
        .Depth           (OSTD_R + 1),
        .OutputZeroIfEmpty(1'b1)
    ) u_r_resp_fifo (
        .clk_i    (clk),
        .rst_ni   (rst_n),
        .clr_i    (1'b0),
        .wvalid_i (r_resp_wvalid),
        .wready_o (r_resp_wready),
        .wdata_i  (r_resp_wdata),
        .rvalid_o (r_resp_rvalid),
        .rready_i (r_resp_rready),
        .rdata_o  (r_resp_rdata),
        .full_o   (),
        .depth_o  (),
        .err_o    ()
    );

    // R response FIFO -> AXI R channel
    assign {r_out_rlast, r_out_rid, r_out_rresp, r_out_rdata} = r_resp_rdata;

    assign axi_r.rvalid = r_resp_rvalid;
    assign axi_r.rdata  = r_out_rdata;
    assign axi_r.rresp  = r_out_rresp;
    assign axi_r.rid    = r_out_rid;
    assign axi_r.rlast  = r_out_rlast;
    assign axi_r.ruser  = '0;
    assign r_resp_rready = axi_r.rready;

    // -----------------------------------------------------------
    // B response FIFO
    // -----------------------------------------------------------
    caliptra_prim_fifo_sync #(
        .Width           (B_RESP_W),
        .Pass            (1'b1),
        .Depth           (OSTD_W),
        .OutputZeroIfEmpty(1'b1)
    ) u_b_resp_fifo (
        .clk_i    (clk),
        .rst_ni   (rst_n),
        .clr_i    (1'b0),
        .wvalid_i (b_resp_wvalid),
        .wready_o (b_resp_wready),
        .wdata_i  (b_resp_wdata),
        .rvalid_o (b_resp_rvalid),
        .rready_i (b_resp_rready),
        .rdata_o  (b_resp_rdata),
        .full_o   (),
        .depth_o  (),
        .err_o    ()
    );

    assign {b_out_bid, b_out_bresp} = b_resp_rdata;

    assign axi_w.bvalid = b_resp_rvalid;
    assign axi_w.bresp  = b_out_bresp;
    assign axi_w.bid    = b_out_bid;
    assign axi_w.buser  = '0;
    assign b_resp_rready = axi_w.bready;

    // -----------------------------------------------------------
    // FSM combinational logic
    // -----------------------------------------------------------
    assign last_beat      = (beat_cnt_q == 8'd0);

    // Arbitration from IDLE: alternate between read and write when both are
    // ready; otherwise take the ready one. A write is ready only when its
    // first W beat is available.
    always_comb begin
        grant_rd = 1'b0;
        grant_wr = 1'b0;
        if (ar_fifo_rvalid && aw_fifo_rvalid && w_fifo_rvalid_pack) begin
            // Both ready -- use round-robin
            if (rr_last_was_write_q) grant_rd = 1'b1;
            else                     grant_wr = 1'b1;
        end else if (ar_fifo_rvalid) begin
            grant_rd = 1'b1;
        end else if (aw_fifo_rvalid && w_fifo_rvalid_pack) begin
            grant_wr = 1'b1;
        end
    end

    // Next state, FIFO controls, register updates, and AHB outputs.
    always_comb begin
        fsm_d               = fsm_q;
        active_ctx_d        = active_ctx_q;
        beat_cnt_d          = beat_cnt_q;
        resp_accum_d        = resp_accum_q;
        rr_last_was_write_d = rr_last_was_write_q;
        ar_fifo_pop         = 1'b0;
        aw_fifo_pop         = 1'b0;
        w_fifo_pop          = 1'b0;
        r_resp_wvalid       = 1'b0;
        r_resp_wdata        = '0;
        b_resp_wvalid       = 1'b0;
        b_resp_wdata        = '0;
        ahb_haddr           = '0;
        ahb_hburst          = 3'b000;     // SINGLE
        ahb_hsize           = 3'b010;     // default 32-bit
        ahb_htrans          = HTRANS_IDLE;
        ahb_hwrite          = 1'b0;
        ahb_hwdata          = '0;
        ahb_hsel            = 1'b0;
        ahb_hreadymux       = 1'b1;

        unique case (fsm_q)
            // -------------------------------------------------
            FSM_IDLE: begin
                resp_accum_d = '0;
                if (grant_rd) begin
                    ar_fifo_pop         = 1'b1;
                    active_ctx_d        = ar_head;
                    beat_cnt_d          = ar_head.len;
                    rr_last_was_write_d = 1'b0;
                    fsm_d               = ar_head.reject ? FSM_RD_REJECT : FSM_RD_ADDR;
                end else if (grant_wr) begin
                    aw_fifo_pop         = 1'b1;
                    active_ctx_d        = aw_head;
                    beat_cnt_d          = aw_head.len;
                    rr_last_was_write_d = 1'b1;
                    fsm_d               = aw_head.reject ? FSM_WR_REJECT : FSM_WR_ADDR;
                end
            end

            // -------------------------------------------------
            // Read burst
            // -------------------------------------------------
            FSM_RD_ADDR: begin
                ahb_haddr  = active_ctx_q.addr;
                ahb_htrans = HTRANS_NONSEQ;
                ahb_hwrite = 1'b0;
                ahb_hsel   = 1'b1;
                ahb_hsize  = active_ctx_q.size;
                if (ahb_hreadyout)
                    fsm_d = FSM_RD_DATA;
            end
            FSM_RD_DATA: begin
                ahb_hsel      = 1'b1;
                ahb_hreadymux = ahb_hreadyout & r_resp_wready;
                if (ahb_hreadyout && r_resp_wready) begin
                    // Push this beat's data to R response FIFO
                    r_resp_wvalid = 1'b1;
                    r_resp_wdata  = {last_beat, active_ctx_q.id, ahb_resp_to_axi(ahb_hresp), ahb_hrdata};
                    if (last_beat) begin
                        // Burst complete -- return to IDLE
                        fsm_d = FSM_IDLE;
                    end else begin
                        // More beats -- issue next address phase
                        beat_cnt_d        = beat_cnt_q - 8'd1;
                        active_ctx_d.addr = next_addr;
                        fsm_d             = FSM_RD_ADDR;
                    end
                end
            end

            // -------------------------------------------------
            // Write burst
            // -------------------------------------------------
            FSM_WR_ADDR: begin
                ahb_haddr  = active_ctx_q.addr;
                // Only issue NONSEQ when W data is available; otherwise
                // hold IDLE to prevent the slave latching an address
                // for which we have no data yet.
                ahb_htrans = w_fifo_rvalid_pack ? HTRANS_NONSEQ : HTRANS_IDLE;
                ahb_hwrite = 1'b1;
                ahb_hsel   = 1'b1;
                ahb_hsize  = active_ctx_q.size;
                if (ahb_hreadyout && w_fifo_rvalid_pack)
                    fsm_d = FSM_WR_DATA;
            end
            FSM_WR_DATA: begin
                ahb_hwdata    = w_beat_data;
                ahb_hsel      = 1'b1;
                ahb_hwrite    = 1'b1;
                ahb_hreadymux = ahb_hreadyout
                              & w_fifo_rvalid_pack
                              & (last_beat ? b_resp_wready : 1'b1);
                if (ahb_hreadyout) begin
                    if (last_beat) begin
                        // Last beat: only complete if B-response FIFO can accept
                        if (b_resp_wready) begin
                            w_fifo_pop    = 1'b1;
                            resp_accum_d  = resp_accum_q | ahb_resp_to_axi(ahb_hresp);
                            b_resp_wvalid = 1'b1;
                            b_resp_wdata  = {active_ctx_q.id, resp_accum_q | ahb_resp_to_axi(ahb_hresp)};
                            fsm_d         = FSM_IDLE;
                        end
                    end else begin
                        w_fifo_pop        = 1'b1;
                        resp_accum_d      = resp_accum_q | ahb_resp_to_axi(ahb_hresp);
                        beat_cnt_d        = beat_cnt_q - 8'd1;
                        active_ctx_d.addr = next_addr;
                        fsm_d             = FSM_WR_ADDR;
                    end
                end
            end

            // -------------------------------------------------
            // Denied bursts: complete locally, AHB outputs stay at defaults
            // -------------------------------------------------
            FSM_RD_REJECT: begin
                if (r_resp_wready) begin
                    r_resp_wvalid = 1'b1;
                    r_resp_wdata  = {last_beat, active_ctx_q.id, AXI_RESP_SLVERR, {DW{1'b0}}};
                    if (last_beat)
                        fsm_d = FSM_IDLE;
                    else
                        beat_cnt_d = beat_cnt_q - 8'd1;
                end
            end

            FSM_WR_REJECT: begin
                if (w_fifo_rvalid_pack && (!last_beat || b_resp_wready)) begin
                    w_fifo_pop = 1'b1;
                    if (last_beat)
                        fsm_d = FSM_WR_REJECT_RESP;
                    else
                        beat_cnt_d = beat_cnt_q - 8'd1;
                end
            end

            // Separate B generation from a potentially passing-through final W beat.
            FSM_WR_REJECT_RESP: begin
                if (b_resp_wready) begin
                    b_resp_wvalid = 1'b1;
                    b_resp_wdata  = {active_ctx_q.id, AXI_RESP_SLVERR};
                    fsm_d         = FSM_IDLE;
                end
            end
        endcase
    end

    assign ar_fifo_rready       = ar_fifo_pop;
    assign aw_fifo_rready       = aw_fifo_pop;
    assign w_fifo_rready_pack   = w_fifo_pop;

    // -----------------------------------------------------------
    // FSM registers
    // -----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm_q               <= FSM_IDLE;
            active_ctx_q        <= '0;
            beat_cnt_q          <= '0;
            resp_accum_q        <= '0;
            rr_last_was_write_q <= 1'b0;
        end else begin
            fsm_q               <= fsm_d;
            active_ctx_q        <= active_ctx_d;
            beat_cnt_q          <= beat_cnt_d;
            resp_accum_q        <= resp_accum_d;
            rr_last_was_write_q <= rr_last_was_write_d;
        end
    end

    // -----------------------------------------------------------
    // Assertions
    // -----------------------------------------------------------
    `CALIPTRA_ASSERT_INIT(NumPrivAxiUsers_A, NUM_PRIV_AXI_USERS > 0)
    `CALIPTRA_ASSERT_INIT(UserWidthsMatch_A,
        ($bits(axi_r.aruser) == UW) && ($bits(axi_w.awuser) == UW))
    `CALIPTRA_ASSERT(EnableKnownAtAddress_A,
        ((axi_r.arvalid && axi_r.arready) || (axi_w.awvalid && axi_w.awready))
        |-> !$isunknown(enable_axi_user_filtering_i), clk, !rst_n)
    `CALIPTRA_ASSERT(ReadUserKnownAtAddress_A,
        (axi_r.arvalid && axi_r.arready && (enable_axi_user_filtering_i === 1'b1))
        |-> !$isunknown(axi_r.aruser), clk, !rst_n)
    `CALIPTRA_ASSERT(WriteUserKnownAtAddress_A,
        (axi_w.awvalid && axi_w.awready && (enable_axi_user_filtering_i === 1'b1))
        |-> !$isunknown(axi_w.awuser), clk, !rst_n)
    for (genvar user_idx = 0;
         user_idx < NUM_PRIV_AXI_USERS;
         user_idx++) begin : gen_policy_assert
        `CALIPTRA_ASSERT(ListEntryKnownAtAddress_A,
            (((axi_r.arvalid && axi_r.arready) || (axi_w.awvalid && axi_w.awready))
             && (enable_axi_user_filtering_i === 1'b1))
            |-> !$isunknown(priv_axi_users_i[user_idx]), clk, !rst_n)
    end
    `CALIPTRA_ASSERT(RejectKnownAtGrant_A,
        ((fsm_q == FSM_IDLE) && (grant_rd || grant_wr))
        |-> !$isunknown(grant_rd ? ar_head.reject : aw_head.reject), clk, !rst_n)
    // Route checks use the reject bit sampled at the grant, not the live head.
    `CALIPTRA_ASSERT(ReadGrantRoutesRequest_A,
        ((fsm_q == FSM_IDLE) && grant_rd && !$isunknown(ar_head.reject))
        |=> (fsm_q == ($past(ar_head.reject) ? FSM_RD_REJECT : FSM_RD_ADDR)), clk, !rst_n)
    `CALIPTRA_ASSERT(WriteGrantRoutesRequest_A,
        ((fsm_q == FSM_IDLE) && grant_wr && !$isunknown(aw_head.reject))
        |=> (fsm_q == ($past(aw_head.reject) ? FSM_WR_REJECT : FSM_WR_ADDR)), clk, !rst_n)
    `CALIPTRA_ASSERT(DeniedRequestDoesNotSelectAhb_A,
        (fsm_q inside {FSM_RD_REJECT, FSM_WR_REJECT, FSM_WR_REJECT_RESP})
        |-> (!ahb_hsel && (ahb_htrans == HTRANS_IDLE) && ahb_hreadymux
             && (ahb_haddr == '0) && (ahb_hwdata == '0) && !ahb_hwrite
             && (ahb_hsize == 3'b010) && (ahb_hburst == 3'b000)), clk, !rst_n)
    `CALIPTRA_ASSERT(RejectedWriteDrainHasNoResponse_A,
        (fsm_q == FSM_WR_REJECT) |-> !b_resp_wvalid, clk, !rst_n)
    `CALIPTRA_ASSERT(RejectedWriteFinalPop_A,
        ((fsm_q == FSM_WR_REJECT) && w_fifo_pop && last_beat)
        |=> (fsm_q == FSM_WR_REJECT_RESP), clk, !rst_n)
    `CALIPTRA_ASSERT(RejectedWriteResponseAfterDrain_A,
        (fsm_q == FSM_WR_REJECT_RESP)
        |-> (!w_fifo_pop
             && ($past(fsm_q == FSM_WR_REJECT_RESP)
                 || $past((fsm_q == FSM_WR_REJECT) && w_fifo_pop && last_beat))), clk, !rst_n)
    `CALIPTRA_ASSERT(RejectedWriteResponseCompletes_A,
        (fsm_q == FSM_WR_REJECT_RESP)
        |-> (!w_fifo_pop && (b_resp_wvalid == b_resp_wready)
             && (!b_resp_wvalid || (b_resp_wdata == {active_ctx_q.id, AXI_RESP_SLVERR})))
            ##1 ($past(b_resp_wvalid) ? (fsm_q == FSM_IDLE)
                                      : ((fsm_q == FSM_WR_REJECT_RESP) && $stable(active_ctx_q))),
        clk, !rst_n)

    `CALIPTRA_ASSERT(WriteLastPlacement_A,
        (w_fifo_rvalid_pack && w_fifo_rready_pack) |-> (w_beat_last == last_beat),
        clk, !rst_n)

endmodule
