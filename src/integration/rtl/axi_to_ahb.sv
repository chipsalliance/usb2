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
//   OSTD_R read and OSTD_W write requests. One granted burst at a time drives
//   the AHB address phase, one beat per NONSEQ transfer, while a data-phase
//   register holds the previous beat's response context and staged write
//   data. Address and data phases overlap, so a zero-wait subordinate
//   completes one beat per clock; the next burst is granted as the current
//   burst's final beat is accepted, so bursts chain without idle cycles.
//
//   Response backpressure is applied before issue: a read beat, or the final
//   beat of a write, is issued only when its R or B response FIFO has a free
//   slot not already promised to the beat in its data phase. The bridge never
//   extends an AHB data phase; HREADY follows the selected subordinate's
//   HREADYOUT. All FIFOs allow empty bypass; WVALID can reach AHB address
//   control, and AHB responses can reach AXI without a FIFO storage cycle.
//   The active burst context and AHB write data remain registered.
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
//   requests. NUM_PRIV_AXI_USERS must be positive and every entry
//   participates. Denied bursts issue local beats through the same pipeline:
//   they never select AHB, consume their W beats, and complete in order with
//   SLVERR (zero read data).
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
    output logic             ahb_hreadymux,   // Subordinate HREADYIN; follows ahb_hreadyout, so only the subordinate stalls the data phase
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
    // Retain response storage for a buffered result, the data-phase
    // reservation, and the next issue, even when empty bypass is enabled.
    localparam int unsigned R_RESP_DEPTH   = (OSTD_R < 2) ? 3 : OSTD_R + 1;
    localparam int unsigned B_RESP_DEPTH   = (OSTD_W < 2) ? 3 : OSTD_W + 1;
    localparam int unsigned W_FIFO_DEPTH   = OSTD_W + 1;
    localparam int unsigned R_RESP_DEPTH_W = $clog2(R_RESP_DEPTH + 1);
    localparam int unsigned B_RESP_DEPTH_W = $clog2(B_RESP_DEPTH + 1);
    localparam int unsigned W_FIFO_DEPTH_W = $clog2(W_FIFO_DEPTH + 1);

    typedef struct packed {
        logic                          reject; // USER authorization failed at address acceptance
        logic [AW-1:0]                 addr;
        logic [$bits(axi_burst_e)-1:0] burst;
        logic [2:0]                    size;
        logic [7:0]                    len;
        logic [IW-1:0]                 id;
    } req_ctx_t;

    localparam int unsigned REQ_CTX_W = $bits(req_ctx_t);

    // A beat in its data phase. A local beat belongs to a denied burst and
    // never reaches AHB.
    typedef struct packed {
        logic          write;
        logic          local_beat;
        logic          last;
        logic [IW-1:0] id;
        logic [DW-1:0] wdata;
    } dp_beat_t;

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
    logic [W_FIFO_DEPTH_W-1:0] w_fifo_depth;
    logic                      w_beat_last;
    logic [BC-1:0]             w_beat_strb;
    logic [DW-1:0]             w_beat_data;

    // Address phase: the active burst presents its current beat.
    logic                      seq_busy_q, seq_busy_d;   // A granted burst still has beats to issue
    logic                      seq_write_q, seq_write_d;
    req_ctx_t                  active_ctx_q, active_ctx_d; // addr tracks the address-phase beat
    logic [7:0]                beat_cnt_q, beat_cnt_d;   // Beats remaining minus one.
    logic [AW-1:0]             next_addr;
    logic                      rr_last_was_write_q, rr_last_was_write_d;
    logic                      seq_last;                 // The address-phase beat is the burst's final beat
    logic                      seq_free;                 // The sequencer can accept a new grant
    logic                      w_next_avail;             // A W beat remains for a newly granted write
    logic                      grant_rd, grant_wr;
    logic                      ar_fifo_pop, aw_fifo_pop, w_fifo_pop;
    logic                      beat_vld;    // A beat, with its W beat for writes, is presented
    logic                      beat_ahb;    // The presented beat is authorized and selects AHB
    logic                      beat_credit; // The beat's response slot is available
    logic                      beat_take;   // The beat moves to the data-phase register
    logic                      rd_credit, b_credit;

    // Data phase.
    logic                      dp_valid_q;
    dp_beat_t                  dp_q, dp_d;
    logic                      dp_done;     // The data phase completes this cycle
    logic                      dp_advance;  // The data-phase register may load or empty
    logic [1:0]                dp_resp;     // AXI response for the completing beat
    logic [1:0]                resp_accum_q, resp_accum_d; // Earlier beats' errors in the write burst

    // Response queues.
    logic [R_RESP_W-1:0]        r_resp_wdata, r_resp_rdata;
    logic                      r_resp_wvalid, r_resp_wready;
    logic                      r_resp_rvalid, r_resp_rready;
    logic [R_RESP_DEPTH_W-1:0] r_resp_depth;
    logic                      r_out_rlast;
    logic [IW-1:0]             r_out_rid;
    logic [1:0]                r_out_rresp;
    logic [DW-1:0]             r_out_rdata;
    logic [B_RESP_W-1:0]        b_resp_wdata, b_resp_rdata;
    logic                      b_resp_wvalid, b_resp_wready;
    logic                      b_resp_rvalid, b_resp_rready;
    logic [B_RESP_DEPTH_W-1:0] b_resp_depth;
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
        .Pass            (1'b1),
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
        .Pass            (1'b1),
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
    // on WREADY. Empty bypass lets an arriving beat issue immediately
    // within an active burst.
    // -----------------------------------------------------------
    assign w_fifo_wdata_pack = {axi_w.wlast, axi_w.wstrb, axi_w.wdata};
    assign w_fifo_wvalid     = axi_w.wvalid;
    assign axi_w.wready      = w_fifo_wready_pack;

    caliptra_prim_fifo_sync #(
        .Width           (W_FIFO_W),
        .Pass            (1'b1),
        .Depth           (W_FIFO_DEPTH), // OSTD_W + 1 to allow AW/W decoupling
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
        .depth_o  (w_fifo_depth),
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
    // Read response FIFO -- empty bypass, at least three R beats so AHB
    // reads continue while RREADY is low. When its free slots are all
    // reserved, the next read waits in the active burst.
    // -----------------------------------------------------------
    caliptra_prim_fifo_sync #(
        .Width           (R_RESP_W),
        .Pass            (1'b1),
        .Depth           (R_RESP_DEPTH),
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
        .depth_o  (r_resp_depth),
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
    // B response FIFO -- empty bypass, at least three responses.
    // -----------------------------------------------------------
    caliptra_prim_fifo_sync #(
        .Width           (B_RESP_W),
        .Pass            (1'b1),
        .Depth           (B_RESP_DEPTH),
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
        .depth_o  (b_resp_depth),
        .err_o    ()
    );

    assign {b_out_bid, b_out_bresp} = b_resp_rdata;

    assign axi_w.bvalid = b_resp_rvalid;
    assign axi_w.bresp  = b_out_bresp;
    assign axi_w.bid    = b_out_bid;
    assign axi_w.buser  = '0;
    assign b_resp_rready = axi_w.bready;

    // -----------------------------------------------------------
    // Address phase: active burst
    // -----------------------------------------------------------
    // AxLEN encodes beats minus one, so zero means the final beat, including
    // the first beat of a single-beat burst. For writes, WriteLastPlacement_A
    // checks that the WLAST supplied with the data agrees with this count.
    assign seq_last = (beat_cnt_q == 8'd0);

    // A write beat, denied or not, is presented only with its W beat, which
    // moves into the data-phase register with it.
    assign beat_vld = seq_busy_q && (!seq_write_q || w_fifo_rvalid_pack);
    assign beat_ahb = beat_vld && !active_ctx_q.reject;

    // Response backpressure is applied before issue. The bridge is the only
    // producer of the R and B FIFOs, and a slot promised to the beat in its
    // data phase counts as used, so a slot free at issue stays free until that
    // beat completes. These terms only relax while a data phase waits, so a
    // NONSEQ driven during a wait state stays valid until accepted.
    assign rd_credit   = (32'(r_resp_depth) + 32'(dp_valid_q && !dp_q.write)) < R_RESP_DEPTH;
    assign b_credit    = (32'(b_resp_depth) + 32'(dp_valid_q && dp_q.write && dp_q.last)) < B_RESP_DEPTH;
    assign beat_credit = seq_write_q ? (!seq_last || b_credit) : rd_credit;

    // An AHB beat leaves on its address-phase acceptance, which also completes
    // any AHB data phase ahead of it. A local beat needs only the data-phase
    // register to be free, preserving response order.
    assign dp_done    = dp_valid_q && (dp_q.local_beat || ahb_hreadyout);
    assign dp_advance = !dp_valid_q || dp_done;
    assign beat_take  = beat_vld && beat_credit && (active_ctx_q.reject ? dp_advance : ahb_hreadyout);
    assign seq_free   = !seq_busy_q || (beat_take && seq_last);
    assign w_fifo_pop = beat_take && seq_write_q;

    // While a write beat is popped, a following write is ready only if another
    // W beat is stored behind it.
    assign w_next_avail = w_fifo_depth > W_FIFO_DEPTH_W'(w_fifo_pop);

    // Arbitration when the sequencer is free: alternate between read and
    // write when both are ready; otherwise take the ready one. A write is ready
    // only when its first W beat is available, so an AW waiting for data does
    // not block reads.
    always_comb begin
        grant_rd = 1'b0;
        grant_wr = 1'b0;
        if (seq_free) begin
            if (ar_fifo_rvalid && aw_fifo_rvalid && w_next_avail) begin
                if (rr_last_was_write_q) grant_rd = 1'b1;
                else                     grant_wr = 1'b1;
            end else if (ar_fifo_rvalid) begin
                grant_rd = 1'b1;
            end else if (aw_fifo_rvalid && w_next_avail) begin
                grant_wr = 1'b1;
            end
        end
    end

    always_comb begin
        seq_busy_d          = seq_busy_q;
        seq_write_d         = seq_write_q;
        active_ctx_d        = active_ctx_q;
        beat_cnt_d          = beat_cnt_q;
        rr_last_was_write_d = rr_last_was_write_q;
        ar_fifo_pop         = 1'b0;
        aw_fifo_pop         = 1'b0;

        if (beat_take) begin
            if (seq_last) begin
                seq_busy_d = 1'b0;
            end else begin
                // Even errored or denied bursts issue all AxLEN+1 beats.
                // Advance using the original FIXED/INCR/WRAP geometry.
                beat_cnt_d        = beat_cnt_q - 8'd1;
                active_ctx_d.addr = next_addr;
            end
        end

        // A grant owns the sequencer for the entire burst. Capture the queued
        // reject decision rather than rechecking live policy, which may have
        // changed since the address was accepted.
        if (grant_rd) begin
            ar_fifo_pop         = 1'b1;
            active_ctx_d        = ar_head;
            beat_cnt_d          = ar_head.len;
            seq_write_d         = 1'b0;
            seq_busy_d          = 1'b1;
            rr_last_was_write_d = 1'b0;
        end else if (grant_wr) begin
            aw_fifo_pop         = 1'b1;
            active_ctx_d        = aw_head;
            beat_cnt_d          = aw_head.len;
            seq_write_d         = 1'b1;
            seq_busy_d          = 1'b1;
            rr_last_was_write_d = 1'b1;
        end
    end

    assign ar_fifo_rready     = ar_fifo_pop;
    assign aw_fifo_rready     = aw_fifo_pop;
    assign w_fifo_rready_pack = w_fifo_pop;

    // A denied beat never selects AHB and keeps its address off the bus.
    assign ahb_hsel      = beat_ahb;
    assign ahb_htrans    = (beat_ahb && beat_credit) ? HTRANS_NONSEQ : HTRANS_IDLE;
    assign ahb_haddr     = active_ctx_q.reject ? '0 : active_ctx_q.addr;
    assign ahb_hwrite    = beat_ahb && seq_write_q;
    assign ahb_hsize     = active_ctx_q.reject ? 3'b010 : active_ctx_q.size;
    assign ahb_hburst    = 3'b000;     // SINGLE: each AXI beat is a separate AHB transfer
    assign ahb_hreadymux = ahb_hreadyout;

    // -----------------------------------------------------------
    // Data phase and response generation
    // -----------------------------------------------------------
    always_comb begin
        dp_d.write      = seq_write_q;
        dp_d.local_beat = active_ctx_q.reject;
        dp_d.last       = seq_last;
        dp_d.id         = active_ctx_q.id;
        dp_d.wdata      = (seq_write_q && !active_ctx_q.reject) ? w_beat_data : '0;
    end

    // HWDATA is staged when the address phase is accepted and holds through
    // wait states. It is zero for reads and denied beats.
    assign ahb_hwdata = dp_q.wdata;

    assign dp_resp = dp_q.local_beat ? AXI_RESP_SLVERR : ahb_resp_to_axi(ahb_hresp);

    // Every beat, AHB or local, returns its own R beat; a denied read returns
    // zero data. A write burst returns one B with any error from its beats.
    assign r_resp_wvalid = dp_done && !dp_q.write;
    assign r_resp_wdata  = {dp_q.last, dp_q.id, dp_resp, (dp_q.local_beat ? {DW{1'b0}} : ahb_hrdata)};
    assign b_resp_wvalid = dp_done && dp_q.write && dp_q.last;
    assign b_resp_wdata  = {dp_q.id, resp_accum_q | dp_resp};

    always_comb begin
        resp_accum_d = resp_accum_q;
        if (dp_done && dp_q.write)
            resp_accum_d = dp_q.last ? 2'b00 : (resp_accum_q | dp_resp);
    end

    // -----------------------------------------------------------
    // Registers
    // -----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_busy_q          <= 1'b0;
            seq_write_q         <= 1'b0;
            active_ctx_q        <= '0;
            beat_cnt_q          <= '0;
            rr_last_was_write_q <= 1'b0;
            dp_valid_q          <= 1'b0;
            dp_q                <= '0;
            resp_accum_q        <= '0;
        end else begin
            seq_busy_q          <= seq_busy_d;
            seq_write_q         <= seq_write_d;
            active_ctx_q        <= active_ctx_d;
            beat_cnt_q          <= beat_cnt_d;
            rr_last_was_write_q <= rr_last_was_write_d;
            // A take always finds the data-phase register advancing.
            if (dp_advance)
                dp_valid_q <= beat_take;
            if (beat_take)
                dp_q       <= dp_d;
            resp_accum_q        <= resp_accum_d;
        end
    end

    // -----------------------------------------------------------
    // Assertions
    // -----------------------------------------------------------
    // Startup parameter checks: the allowlist must be non-empty, and both
    // ARUSER and AWUSER must be exactly UW bits wide for exact USER matching.
    `CALIPTRA_ASSERT_INIT(NumPrivAxiUsers_A, NUM_PRIV_AXI_USERS > 0)
    `CALIPTRA_ASSERT_INIT(UserWidthsMatch_A,
        ($bits(axi_r.aruser) == UW) && ($bits(axi_w.awuser) == UW))

    // The filter enable must be known whenever an AR or AW address is accepted,
    // since that is when the reject decision is captured.
    `CALIPTRA_ASSERT(EnableKnownAtAddress_A,
        ((axi_r.arvalid && axi_r.arready) || (axi_w.awvalid && axi_w.awready))
        |-> !$isunknown(enable_axi_user_filtering_i), clk, !rst_n)

    // With filtering enabled, ARUSER must be known when a read address is accepted.
    `CALIPTRA_ASSERT(ReadUserKnownAtAddress_A,
        (axi_r.arvalid && axi_r.arready && (enable_axi_user_filtering_i === 1'b1))
        |-> !$isunknown(axi_r.aruser), clk, !rst_n)

    // With filtering enabled, AWUSER must be known when a write address is accepted.
    `CALIPTRA_ASSERT(WriteUserKnownAtAddress_A,
        (axi_w.awvalid && axi_w.awready && (enable_axi_user_filtering_i === 1'b1))
        |-> !$isunknown(axi_w.awuser), clk, !rst_n)

    // With filtering enabled, every allowlist entry must be known when any
    // address is accepted, even if another entry already matches.
    for (genvar user_idx = 0;
         user_idx < NUM_PRIV_AXI_USERS;
         user_idx++) begin : gen_policy_assert
        `CALIPTRA_ASSERT(ListEntryKnownAtAddress_A,
            (((axi_r.arvalid && axi_r.arready) || (axi_w.awvalid && axi_w.awready))
             && (enable_axi_user_filtering_i === 1'b1))
            |-> !$isunknown(priv_axi_users_i[user_idx]), clk, !rst_n)
    end

    // The stored reject bit of the granted FIFO head must be known at grant.
    `CALIPTRA_ASSERT(RejectKnownAtGrant_A,
        (grant_rd || grant_wr)
        |-> !$isunknown(grant_rd ? ar_head.reject : aw_head.reject), clk, !rst_n)

    // A grant captures the head's reject bit for every beat of its burst.
    `CALIPTRA_ASSERT(GrantCapturesReject_A,
        (grant_rd || grant_wr)
        |=> (seq_busy_q && (active_ctx_q.reject == $past(grant_rd ? ar_head.reject : aw_head.reject))),
        clk, !rst_n)

    // A denied beat never selects AHB: no select, IDLE transfer, and all
    // other address-phase outputs at their default values. HREADY is not an
    // output here: it follows the subordinate's HREADYOUT.
    `CALIPTRA_ASSERT(DeniedRequestDoesNotSelectAhb_A,
        (seq_busy_q && active_ctx_q.reject)
        |-> (!ahb_hsel && (ahb_htrans == HTRANS_IDLE)
             && (ahb_haddr == '0) && !ahb_hwrite
             && (ahb_hsize == 3'b010) && (ahb_hburst == 3'b000)), clk, !rst_n)
    `CALIPTRA_ASSERT(DeniedBeatDrivesNoWriteData_A,
        (dp_valid_q && dp_q.local_beat) |-> (ahb_hwdata == '0), clk, !rst_n)

    // Every consumed W beat has WLAST set only on the AWLEN-derived last beat.
    `CALIPTRA_ASSERT(WriteLastPlacement_A,
        (w_fifo_rvalid_pack && w_fifo_rready_pack) |-> (w_beat_last == seq_last),
        clk, !rst_n)

    // Issue-time response reservation needs real storage.
    `CALIPTRA_ASSERT_INIT(ReadQueueDepthPositive_A, OSTD_R > 0)
    `CALIPTRA_ASSERT_INIT(WriteQueueDepthPositive_A, OSTD_W > 0)

    // The reservation made at issue must hold for the whole data phase,
    // including subordinate wait states and two-cycle ERROR responses.
    `CALIPTRA_ASSERT(ReadDataHasRSlot_A,
        (dp_valid_q && !dp_q.write) |-> r_resp_wready, clk, !rst_n)
    `CALIPTRA_ASSERT(WriteFinalDataHasBSlot_A,
        (dp_valid_q && dp_q.write && dp_q.last) |-> b_resp_wready, clk, !rst_n)

    // AHB manager rules: once NONSEQ is driven, the address phase holds
    // until HREADY, and HWDATA holds through data-phase wait states.
    `CALIPTRA_ASSERT(AddressPhaseHeldDuringWait_A,
        ((ahb_htrans == HTRANS_NONSEQ) && !ahb_hreadyout)
        |=> ((ahb_htrans == HTRANS_NONSEQ) && $stable(ahb_haddr) && $stable(ahb_hwrite)
             && $stable(ahb_hsize) && $stable(ahb_hburst)), clk, !rst_n)
    `CALIPTRA_ASSERT(WriteDataHeldDuringWait_A,
        (dp_valid_q && !dp_done) |=> $stable(ahb_hwdata), clk, !rst_n)

    // A blocked beat keeps its burst context.
    `CALIPTRA_ASSERT(BlockedBeatHolds_A,
        (beat_vld && !beat_take)
        |=> (beat_vld && $stable(active_ctx_q) && $stable(beat_cnt_q) && $stable(seq_write_q)),
        clk, !rst_n)

    // An AHB beat is taken only through an accepted NONSEQ, a take always
    // finds the data-phase register advancing, and that register is loaded
    // only by a take.
    `CALIPTRA_ASSERT(AhbBeatTakenOnAcceptance_A,
        (beat_take && !active_ctx_q.reject)
        |-> ((ahb_htrans == HTRANS_NONSEQ) && ahb_hsel && ahb_hreadyout), clk, !rst_n)
    `CALIPTRA_ASSERT(TakeIntoFreeDataPhase_A,
        beat_take |-> dp_advance, clk, !rst_n)
    `CALIPTRA_ASSERT(DataPhaseFollowsTake_A,
        dp_advance |=> (dp_valid_q == $past(beat_take)), clk, !rst_n)

    // Each completing data phase produces exactly one result: one R push per
    // read beat and one B push per write burst; an empty stage pushes none.
    `CALIPTRA_ASSERT(ReadCompletionPushesOnce_A,
        (dp_valid_q && !dp_q.write) |-> (r_resp_wvalid == dp_done), clk, !rst_n)
    `CALIPTRA_ASSERT(WriteCompletionPushesOnce_A,
        (dp_valid_q && dp_q.write) |-> (b_resp_wvalid == (dp_done && dp_q.last)),
        clk, !rst_n)
    `CALIPTRA_ASSERT(IdleDataPhasePushesNothing_A,
        !dp_valid_q |-> (!r_resp_wvalid && !b_resp_wvalid), clk, !rst_n)

    // Cover the reservation path: a full response FIFO defers issue, then
    // the transfer issues and completes.
    `CALIPTRA_COVER(ReadIssueDeferredThenCompleted_C,
        (beat_ahb && !seq_write_q && !beat_credit)
        ##[1:$] (dp_valid_q && !dp_q.write && !dp_q.local_beat && ahb_hreadyout), clk, !rst_n)
    `CALIPTRA_COVER(WriteFinalIssueDeferredThenCompleted_C,
        (beat_ahb && seq_write_q && seq_last && !beat_credit)
        ##[1:$] (dp_valid_q && dp_q.write && dp_q.last && !dp_q.local_beat && ahb_hreadyout), clk, !rst_n)

    // Cover overlap within a burst, chaining across bursts, and a denied beat
    // presented directly behind an AHB beat.
    `CALIPTRA_COVER(AddressOverlapsData_C,
        beat_take && beat_ahb && dp_done && !dp_q.local_beat, clk, !rst_n)
    `CALIPTRA_COVER(BurstChainedWithoutBubble_C,
        beat_take && seq_last && (grant_rd || grant_wr), clk, !rst_n)
    `CALIPTRA_COVER(DeniedBeatFollowsAhbBeat_C,
        beat_vld && active_ctx_q.reject && dp_valid_q && !dp_q.local_beat, clk, !rst_n)

endmodule
