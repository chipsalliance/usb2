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
//   The converter supports burst transactions (FIXED, INCR,
//   WRAP) with up to OSTD_R outstanding reads and OSTD_W outstanding writes.
//   Burst beats are issued as individual NONSEQ AHB transfers; the AHB side
//   is inherently single-outstanding so requests are serialized.
//
//   The AXI subordinate interface uses the Caliptra `axi_if` SystemVerilog
//   interface.  The AHB master side uses discrete signals.
//
//   Clock/reset: a single clk/rst_n pair drives both the AXI and AHB sides
//   (same clock domain assumed).
//
//   ENABLE_USER_FILTER adds an exact AWUSER/ARUSER allowlist sampled at
//   each address handshake. A known low enable_axi_user_filtering_i
//   bypasses the list; zero and all-ones USER values are ordinary entries.
//   NUM_PRIV_AXI_USERS must be positive; every list entry participates.
//   Unknown enable or USER comparisons cannot authorize a request.
//   Denied bursts complete locally with SLVERR (zero read data) and never
//   select AHB. Compile-time disable removes matching and reject storage.
//

`include "caliptra_prim_assert.sv"

module axi_to_ahb
  import axi_pkg::*;
#(
    parameter int unsigned AW       = 32,   // Address width
    parameter int unsigned DW       = 32,   // Data width (must match AHB data width)
    parameter int unsigned IW       = 8,    // AXI ID width
    parameter int unsigned UW       = 32,   // AXI User width
    parameter int unsigned OSTD_R   = 2,    // Outstanding read depth  (full mode only)
    parameter int unsigned OSTD_W   = 2,    // Outstanding write depth (full mode only)
    parameter bit ENABLE_USER_FILTER = 1'b0,
    parameter int unsigned NUM_PRIV_AXI_USERS = 4
) (
    input  logic             clk,
    input  logic             rst_n,

    // ---- AXI Subordinate (using axi_if, no modport) ----
    axi_if.r_sub             axi_r,
    axi_if.w_sub             axi_w,

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

    // =================================================================
    //  Full AXI4 Mode (burst, multiple outstanding)
    // =================================================================

    // -----------------------------------------------------------
    // Types
    // -----------------------------------------------------------
    localparam int unsigned REQ_CTX_W = AW + 2 + 3 + 8 + IW; // addr, burst, size, len, id
    localparam int unsigned ReqFifoWidth = REQ_CTX_W + (ENABLE_USER_FILTER ? 1 : 0);
    localparam int unsigned W_CTX_W  = DW + BC;              // wdata, wstrb
    localparam int unsigned W_FIFO_W = W_CTX_W + 1;
    localparam int unsigned R_RESP_W = DW + 2 + IW + 1;
    localparam int unsigned B_RESP_W = 2 + IW;

    typedef struct packed {
        logic [AW-1:0]  addr;
        logic [1:0]     burst;
        logic [2:0]     size;
        logic [7:0]     len;
        logic [IW-1:0]  id;
    } req_ctx_t;

    typedef enum logic [2:0] {
        FSM_IDLE,
        FSM_RD_ADDR,
        FSM_RD_DATA,
        FSM_WR_ADDR,
        FSM_WR_DATA
    } fsm_state_e;

    // Request queues and policy decisions.
    logic                      ar_fifo_wvalid, ar_fifo_wready;
    logic [ReqFifoWidth-1:0]    ar_fifo_wdata, ar_fifo_rdata;
    logic                      ar_fifo_rvalid, ar_fifo_rready;
    logic                      aw_fifo_wvalid, aw_fifo_wready;
    logic [ReqFifoWidth-1:0]    aw_fifo_wdata, aw_fifo_rdata;
    logic                      aw_fifo_rvalid, aw_fifo_rready;
    req_ctx_t                  ar_req, aw_req, ar_head, aw_head;
    logic                      active_reject;

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
    req_ctx_t                  active_ctx_q;
    logic [7:0]                beat_cnt_q; // Beats remaining minus one.
    logic [AW-1:0]             beat_addr_q;
    logic [1:0]                resp_accum_q;
    logic [IW-1:0]             resp_id_q;
    logic [AW-1:0]             next_addr;
    logic                      rr_last_was_write_q;
    logic                      grant_rd, grant_wr;
    logic                      ar_fifo_pop, aw_fifo_pop, w_fifo_pop;
    logic                      rd_resp_accept, last_beat;
    logic                      beat_ready;
    logic [1:0]                beat_resp;  // AXI response code
    logic [DW-1:0]             beat_rdata;

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

    function automatic logic axi_user_matches(
        input logic [UW-1:0] request_user,
        input logic [UW-1:0] privileged_user
    );
        axi_user_matches = 1'b0;
        if (request_user == privileged_user)
            axi_user_matches = 1'b1;
    endfunction

    generate
        if (ENABLE_USER_FILTER) begin : gen_user_filter
            logic [NUM_PRIV_AXI_USERS-1:0] ar_user_match;
            logic [NUM_PRIV_AXI_USERS-1:0] aw_user_match;
            logic ar_reject, aw_reject;
            logic ar_head_reject, aw_head_reject;
            logic active_reject_q;

            for (genvar user_idx = 0;
                 user_idx < NUM_PRIV_AXI_USERS;
                 user_idx++) begin : gen_user_match
                assign ar_user_match[user_idx] =
                    axi_user_matches(axi_r.aruser, priv_axi_users_i[user_idx]);
                assign aw_user_match[user_idx] =
                    axi_user_matches(axi_w.awuser, priv_axi_users_i[user_idx]);
            end

            always_comb begin
                ar_reject = 1'b1;
                aw_reject = 1'b1;
                unique case (enable_axi_user_filtering_i)
                    1'b0: begin
                        ar_reject = 1'b0;
                        aw_reject = 1'b0;
                    end
                    1'b1: begin
                        ar_reject = ~|ar_user_match;
                        aw_reject = ~|aw_user_match;
                    end
                    default: begin end
                endcase
            end

            assign ar_fifo_wdata = {ar_reject, ar_req};
            assign aw_fifo_wdata = {aw_reject, aw_req};
            assign {ar_head_reject, ar_head} = ar_fifo_rdata;
            assign {aw_head_reject, aw_head} = aw_fifo_rdata;
            assign active_reject = active_reject_q;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    active_reject_q <= 1'b0;
                end else if (fsm_q == FSM_IDLE) begin
                    if (grant_rd)
                        active_reject_q <= ar_head_reject;
                    else if (grant_wr)
                        active_reject_q <= aw_head_reject;
                    else
                        active_reject_q <= '0;
                end
            end
        end else begin : gen_no_user_filter
            assign ar_fifo_wdata = ar_req;
            assign aw_fifo_wdata = aw_req;
            assign ar_head = req_ctx_t'(ar_fifo_rdata);
            assign aw_head = req_ctx_t'(aw_fifo_rdata);
            assign active_reject = 1'b0;
        end
    endgenerate

    // AR request FIFO.
    assign ar_req.addr  = axi_r.araddr;
    assign ar_req.burst = axi_r.arburst;
    assign ar_req.size  = axi_r.arsize;
    assign ar_req.len   = axi_r.arlen;
    assign ar_req.id    = axi_r.arid;

    assign ar_fifo_wvalid = axi_r.arvalid;
    assign axi_r.arready  = ar_fifo_wready;

    caliptra_prim_fifo_sync #(
        .Width           (ReqFifoWidth),
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

    assign aw_fifo_wvalid  = axi_w.awvalid;
    assign axi_w.awready   = aw_fifo_wready;

    caliptra_prim_fifo_sync #(
        .Width           (ReqFifoWidth),
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
    // W Data FIFO -- buffer a small number of write-data beats so
    // that the AW and W channels can decouple slightly. Depth
    // matches outstanding writes; beats beyond that are
    // back-pressured on wready.
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
        .i_last_addr (beat_addr_q),
        .i_size      (active_ctx_q.size),
        .i_burst     (active_ctx_q.burst),
        .i_len       (active_ctx_q.len),
        .o_next_addr (next_addr)
    );

    // Round-robin arbiter: alternate priority between R and W.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rr_last_was_write_q <= 1'b0;
        else if (fsm_q == FSM_IDLE && fsm_d != FSM_IDLE)
            rr_last_was_write_q <= (fsm_d == FSM_WR_ADDR);
    end

    // -----------------------------------------------------------
    // Read response FIFO -- buffer R-channel beats while AHB is
    // busy so the FSM can immediately start the next AHB beat.
    // Depth = max burst len would be large; instead use a modest
    // FIFO and stall AHB if the R channel backs up.
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
    assign rd_resp_accept = r_resp_wvalid && r_resp_wready;

    // A denied transaction completes against an always-ready SLVERR result
    // while the AHB output gate keeps the real bus idle.
    assign beat_ready = active_reject ? 1'b1            : ahb_hreadyout;
    assign beat_resp  = active_reject ? AXI_RESP_SLVERR : ahb_resp_to_axi(ahb_hresp);
    assign beat_rdata = active_reject ? '0              : ahb_hrdata;

    // Arbitration: who gets to go next from IDLE?
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

    always_comb begin
        fsm_d           = fsm_q;
        ar_fifo_pop     = 1'b0;
        aw_fifo_pop     = 1'b0;
        w_fifo_pop      = 1'b0;
        r_resp_wvalid   = 1'b0;
        r_resp_wdata    = '0;
        b_resp_wvalid   = 1'b0;
        b_resp_wdata    = '0;

        unique case (fsm_q)
            // -------------------------------------------------
            FSM_IDLE: begin
                if (grant_rd) begin
                    ar_fifo_pop = 1'b1;
                    fsm_d       = FSM_RD_ADDR;
                end else if (grant_wr) begin
                    aw_fifo_pop = 1'b1;
                    fsm_d       = FSM_WR_ADDR;
                end
            end

            // -------------------------------------------------
            // Read burst
            // -------------------------------------------------
            FSM_RD_ADDR: begin
                if (beat_ready)
                    fsm_d = FSM_RD_DATA;
            end
            FSM_RD_DATA: begin
                if (beat_ready && r_resp_wready) begin
                    // Push this beat's data to R response FIFO
                    r_resp_wvalid = 1'b1;
                    r_resp_wdata  = {last_beat, resp_id_q, beat_resp, beat_rdata};
                    if (last_beat) begin
                        // Burst complete -- return to IDLE
                        fsm_d = FSM_IDLE;
                    end else begin
                        // More beats -- issue next address phase
                        fsm_d = FSM_RD_ADDR;
                    end
                end
            end

            // -------------------------------------------------
            // Write burst
            // -------------------------------------------------
            FSM_WR_ADDR: begin
                // Only present AHB address when W beat data is available
                if (beat_ready && w_fifo_rvalid_pack)
                    fsm_d = FSM_WR_DATA;
            end
            FSM_WR_DATA: begin
                if (beat_ready) begin
                    if (last_beat) begin
                        // Last beat: only complete if B-response FIFO can accept
                        if (b_resp_wready) begin
                            w_fifo_pop    = 1'b1;
                            b_resp_wvalid = 1'b1;
                            b_resp_wdata  = {resp_id_q, resp_accum_q | beat_resp};
                            fsm_d         = FSM_IDLE;
                        end
                    end else begin
                        w_fifo_pop = 1'b1;
                        fsm_d      = FSM_WR_ADDR;
                    end
                end
            end

            default: fsm_d = FSM_IDLE;
        endcase
    end

    assign ar_fifo_rready       = ar_fifo_pop;
    assign aw_fifo_rready       = aw_fifo_pop;
    assign w_fifo_rready_pack   = w_fifo_pop;

    // -----------------------------------------------------------
    // FSM sequential -- state + active context
    // -----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm_q            <= FSM_IDLE;
            active_ctx_q     <= '0;
            beat_cnt_q       <= '0;
            beat_addr_q      <= '0;
            resp_accum_q     <= '0;
            resp_id_q        <= '0;
        end else begin
            fsm_q <= fsm_d;

            unique case (fsm_q)
                FSM_IDLE: begin
                    resp_accum_q <= '0;
                    if (grant_rd) begin
                        active_ctx_q      <= ar_head;
                        beat_cnt_q        <= ar_head.len;
                        beat_addr_q       <= ar_head.addr;
                        resp_id_q         <= ar_head.id;
                    end else if (grant_wr) begin
                        active_ctx_q      <= aw_head;
                        beat_cnt_q        <= aw_head.len;
                        beat_addr_q       <= aw_head.addr;
                        resp_id_q         <= aw_head.id;
                    end
                end

                FSM_RD_DATA: begin
                    if (rd_resp_accept && !last_beat) begin
                        beat_cnt_q  <= beat_cnt_q - 8'd1;
                        beat_addr_q <= next_addr;
                    end
                end

                FSM_WR_DATA: begin
                    if (w_fifo_pop) begin
                        resp_accum_q <= resp_accum_q | beat_resp;
                        if (!last_beat) begin
                            beat_cnt_q  <= beat_cnt_q - 8'd1;
                            beat_addr_q <= next_addr;
                        end
                    end
                end
                default: begin end
            endcase
        end
    end

    // -----------------------------------------------------------
    // AHB output mux
    // -----------------------------------------------------------
    always_comb begin
        ahb_haddr     = '0;
        ahb_hburst    = 3'b000;     // SINGLE
        ahb_hsize     = 3'b010;     // default 32-bit
        ahb_htrans    = HTRANS_IDLE;
        ahb_hwrite    = 1'b0;
        ahb_hwdata    = '0;
        ahb_hsel      = 1'b0;
        ahb_hreadymux = 1'b1;

        if (!active_reject) begin
            unique case (fsm_q)
                FSM_RD_ADDR: begin
                    ahb_haddr  = beat_addr_q;
                    ahb_htrans = HTRANS_NONSEQ;
                    ahb_hwrite = 1'b0;
                    ahb_hsel   = 1'b1;
                    ahb_hsize  = active_ctx_q.size;
                end
                FSM_RD_DATA: begin
                    ahb_hsel     = 1'b1;
                    ahb_hreadymux = ahb_hreadyout & r_resp_wready;
                end
                FSM_WR_ADDR: begin
                    ahb_haddr  = beat_addr_q;
                    // Only issue NONSEQ when W data is available; otherwise
                    // hold IDLE to prevent the slave latching an address
                    // for which we have no data yet.
                    ahb_htrans = w_fifo_rvalid_pack ? HTRANS_NONSEQ : HTRANS_IDLE;
                    ahb_hwrite = 1'b1;
                    ahb_hsel   = 1'b1;
                    ahb_hsize  = active_ctx_q.size;
                end
                FSM_WR_DATA: begin
                    ahb_hwdata    = w_beat_data;
                    ahb_hsel      = 1'b1;
                    ahb_hwrite    = 1'b1;
                    ahb_hreadymux = ahb_hreadyout
                                  & w_fifo_rvalid_pack
                                  & (last_beat ? b_resp_wready : 1'b1);
                end
                default: begin
                    ahb_htrans = HTRANS_IDLE;
                end
            endcase
        end
    end

    // -----------------------------------------------------------
    // Assertions
    // -----------------------------------------------------------
    `CALIPTRA_ASSERT_INIT(NumPrivAxiUsers_A, NUM_PRIV_AXI_USERS > 0)

    generate
        if (ENABLE_USER_FILTER) begin : gen_user_filter_assertions
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
            `CALIPTRA_ASSERT(ActiveRejectKnown_A,
                (fsm_q != FSM_IDLE) |-> !$isunknown(active_reject), clk, !rst_n)
            `CALIPTRA_ASSERT(DeniedRequestDoesNotSelectAhb_A,
                active_reject |-> (!ahb_hsel && (ahb_htrans == HTRANS_IDLE)
                                  && ahb_hreadymux), clk, !rst_n)
        end
    endgenerate

    `CALIPTRA_ASSERT(WriteLastPlacement_A,
        (w_fifo_rvalid_pack && w_fifo_rready_pack) |-> (w_beat_last == last_beat),
        clk, !rst_n)

endmodule
