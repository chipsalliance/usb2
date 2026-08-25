// SPDX-License-Identifier: Apache-2.0
//
// usb_ocp_recovery_cms_fifo
// -------------------------------------------------------------------------
// OCP Recovery v1.1 Sec 8.2 and Sec 9.2 INDIRECT_FIFO_* command owner.
//
// Micro-architecture
//   Data plane:
//     - FIFO_SIZE and MAX_TRANSFER_SIZE report the implemented 64-DWORD depth.
//       WRITE_INDEX and READ_INDEX are modulo-depth debug fields; FULL and EMPTY
//       disambiguate equal indices.
//     - Payload storage is caliptra_prim_fifo_sync with 64 physical DWORDs.
//       Producer, consumer, register block, and firmware all run in clk, so a
//       single-clock synchronous FIFO reports occupancy exactly with no
//       clock-domain-crossing pointer lag.
//     - WRITE_INDEX increments only on actual primitive write acceptance.
//       READ_INDEX is derived as (WRITE_INDEX - depth) mod 65 from the exact
//       synchronous depth, so occupancy advertised through INDIRECT_FIFO_STATUS
//       reflects a just-freed slot on the cycle after the pop.
//     - USB accesses still use the direct fifo_rb_* path. EXT accesses arrive
//       only through cpuif/hwif swacc events from the generated regblock.
//     - EXT INDIRECT_FIFO_DATA reads still come back through the generated
//       regblock field storage. ext_data_mirror_ready_q is deasserted by any
//       head-changing event (pop, push into empty, or FIFO reset) and only
//       reasserts after a later clk edge sees fifo_rvalid_int high with no new
//       head change. That edge is when the regblock samples hwif next with the
//       current head, so the NEXT cycle is the first safe EXT cpuif read.
//
//   Control plane:
//     - fifo_cms_q, image_size_q, write_index_q, accepted_push_count_q,
//       overflow_q, region_reset_q, image_done_q, and image_push_active_q are
//       the sole live owners of FIFO control, status, payload progress, and
//       image-completion accounting. READ_INDEX is derived from write-domain
//       depth rather than stored as an independent counter.
//     - USB and EXT each capture an independent five-word status snapshot so a
//       multiword INDIRECT_FIFO_STATUS read stays source-consistent.
//
//   Arbitration:
//     - usb_ocp_recovery_top.sv blocks EXT cpuif issue for INDIRECT_FIFO_CTRL
//       and INDIRECT_FIFO_DATA while USB owns the FIFO resource, so EXT cannot
//       backpressure the Recovery Agent data path.
// -------------------------------------------------------------------------

module usb_ocp_recovery_cms_fifo #(
  parameter int CMS_ADDR_W = 16,
  parameter int NUM_CMS    = 2,
  parameter int FIFO_WIDTH = 32,
  parameter int FIFO_DEPTH = usb_ocp_recovery_pkg::OCP_FIFO_PHYSICAL_DEPTH_DWORDS
)(
  input  logic clk,
  input  logic rst_ni,

  // Compatibility-only legacy surface. EXT data no longer pops in clk_rd.
  input  logic clk_rd,
  input  logic rst_rd_n,
  output logic        fifo_rd_valid,
  input  logic        fifo_rd_ready,
  output logic [31:0] fifo_rd_data,
  output logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_rd_depth,

  // Direct USB FIFO command path.
  input  logic        fifo_rb_sel,
  input  logic [7:0]  fifo_rb_cmd,
  input  logic [15:0] fifo_rb_offset,
  input  logic        fifo_rb_wr,
  input  logic        fifo_rb_rd,
  input  logic [31:0] fifo_rb_wdata,
  input  logic [3:0]  fifo_rb_wstrb,
  output logic [31:0] fifo_rb_rdata,
  output logic        fifo_rb_ack,
  output logic        fifo_rb_err,

  // EXT cpuif -> hwif access events.
  input  logic        ext_fifo_ctrl_0_access,
  input  logic        ext_fifo_ctrl_1_access,
  input  logic        ext_fifo_status_0_access,
  input  logic        ext_fifo_status_1_access,
  input  logic        ext_fifo_status_2_access,
  input  logic        ext_fifo_status_3_access,
  input  logic        ext_fifo_status_4_access,
  input  logic        ext_fifo_data_access,
  input  logic        ext_cpuif_req_is_wr,
  input  logic [31:0] ext_cpuif_wr_data,
  input  logic [3:0]  ext_cpuif_wr_strb,

  // Status to A5 FSM.
  output logic        image_push_active,
  output logic        image_push_done,
  output logic        fifo_overflow,
  output logic        payload_available,
  output logic        fifo_reset_pulse,
  output logic        batch_aborted,
  output logic [31:0] image_size,
  output logic [31:0] bytes_pushed,

  input  logic        fifo_abort_i,

  // Regblock mirrors.
  output logic [7:0]  fifo_ctrl_cms,
  output logic        fifo_ctrl_reset,
  output logic [31:0] fifo_ctrl_image_size,
  output logic [31:0] fifo_status_word_0,
  output logic [31:0] fifo_status_word_1,
  output logic [31:0] fifo_status_word_2,
  output logic [31:0] fifo_status_word_3,
  output logic [31:0] fifo_status_word_4,
  output logic [31:0] fifo_data_peek,
  output logic        ext_data_mirror_ready
);

  import usb_ocp_recovery_pkg::*;

  localparam int FIFO_DEPTH_W = $clog2(FIFO_DEPTH+1);
  localparam logic [31:0] FIFO_INDEX_MAX_DWORDS = 32'(usb_ocp_recovery_pkg::OCP_FIFO_INDEX_MAX);
  localparam logic [31:0] FIFO_RING_SIZE_DWORDS = 32'(usb_ocp_recovery_pkg::OCP_FIFO_RING_SIZE_DWORDS);
  localparam logic [31:0] FIFO_SIZE_DWORDS      = 32'(usb_ocp_recovery_pkg::OCP_FIFO_RING_SIZE_DWORDS);
  localparam logic [31:0] MAX_XFER_SIZE_DWORDS  = 32'(usb_ocp_recovery_pkg::OCP_FIFO_MAX_TRANSFER_DWORDS);

  logic [7:0]  fifo_cms_q;
  logic [31:0] image_size_q;
  logic [31:0] write_index_q;
  logic [31:0] accepted_push_count_q;
  logic        overflow_q;
  logic        region_reset_q;
  logic        image_done_q;
  logic        image_push_active_q;
  logic        payload_available_q;
  logic        batch_aborted_q;

  logic        usb_status_snapshot_vld_q;
  logic [2:0]  usb_status_snapshot_next_word_q;
  logic        ext_status_snapshot_vld_q;
  logic [2:0]  ext_status_snapshot_next_word_q;
  logic [31:0] usb_status_snapshot_q [0:4];
  logic [31:0] ext_status_snapshot_q [0:4];

  logic                       fifo_flush;
  logic                       fifo_wvalid;
  logic                       fifo_wready;
  logic                       fifo_full_int;
  logic [FIFO_WIDTH-1:0]      fifo_wdata;
  logic [FIFO_DEPTH_W-1:0]    fifo_wdepth;
  logic                       fifo_rready_int;
  logic                       fifo_rvalid_int;
  logic [FIFO_WIDTH-1:0]      fifo_rdata_int;
  logic [FIFO_DEPTH_W-1:0]    fifo_rdepth_int;
  logic                       unused_compat;

  logic is_fifo_ctrl;
  logic is_fifo_status;
  logic is_fifo_data;
  logic is_reg_cmd;
  logic rb_req;
  logic [2:0] word_idx;

  logic usb_ctrl_word0_wr;
  logic usb_ctrl_word1_wr;
  logic ext_ctrl_word0_wr;
  logic ext_ctrl_word1_wr;
  logic usb_status_rd;
  logic ext_status_0_rd;
  logic ext_status_1_rd;
  logic ext_status_2_rd;
  logic ext_status_3_rd;
  logic ext_status_4_rd;
  logic usb_data_wr;
  logic usb_data_rd;
  logic ext_data_wr;
  logic ext_data_rd;

  logic [31:0] ctrl_word0_wdata;
  logic [31:0] ctrl_word1_wdata;
  logic [3:0]  ctrl_word0_wstrb;
  logic [3:0]  ctrl_word1_wstrb;

  logic        fifo_empty;
  logic        fifo_full;
  logic        image_complete;
  logic        push_req;
  logic        push_accept;
  logic        push_drop_full;
  logic        pop_req;
  logic        pop_accept;
  logic [3:0]  push_wstrb;
  logic [31:0] push_raw_wdata;
  logic [31:0] push_wdata;

  logic        usb_fifo_status_snapshot_start;
  logic        usb_fifo_status_snapshot_use;
  logic        ext_fifo_status_snapshot_start;
  logic        ext_fifo_status_snapshot_use;

  logic [31:0] fifo_status_live_word_0;
  logic [31:0] fifo_status_live_word_1;
  logic [31:0] fifo_status_live_word_2;
  logic [31:0] fifo_status_live_word_3;
  logic [31:0] fifo_status_live_word_4;
  logic [7:0]  status_byte_0;
  logic [31:0] write_index_next;
  logic [31:0] read_index_derived;
  logic [FIFO_DEPTH_W-1:0] fifo_occupancy;
  logic        ext_data_mirror_ready_q;
  logic        ext_head_change;
  logic        push_creates_head;
  logic        fifo_clear;
  logic        fifo_becomes_full;
  logic        fifo_becomes_empty;
  logic        terminal_image_push;

  function automatic logic [31:0] fifo_index_next(input logic [31:0] index);
    logic [31:0] next_index;
    begin
      next_index = (index == FIFO_INDEX_MAX_DWORDS) ? 32'd0 : (index + 32'd1);
      return next_index;
    end
  endfunction

  function automatic logic [31:0] fifo_index_sub_depth(
    input logic [31:0] index,
    input logic [FIFO_DEPTH_W-1:0] depth
  );
    logic [31:0] depth_ext;
    logic [31:0] sub_index;
    begin
      depth_ext = 32'(depth);
      if (index >= depth_ext) begin
        sub_index = index - depth_ext;
      end else begin
        sub_index = index + FIFO_RING_SIZE_DWORDS - depth_ext;
      end
      return sub_index;
    end
  endfunction

  initial begin
    assert (FIFO_DEPTH > 0)
      else $fatal(1, "FIFO_DEPTH must be > 0");
    assert (FIFO_WIDTH == 32)
      else $fatal(1, "FIFO_WIDTH must be 32");
    assert (FIFO_DEPTH == usb_ocp_recovery_pkg::OCP_FIFO_PHYSICAL_DEPTH_DWORDS)
      else $fatal(1, "FIFO_DEPTH must match the 64-DWORD physical payload store");
    assert (usb_ocp_recovery_pkg::OCP_FIFO_RING_SIZE_DWORDS == FIFO_DEPTH)
      else $fatal(1, "OCP FIFO ring size must match physical depth");
    assert (usb_ocp_recovery_pkg::OCP_FIFO_MAX_TRANSFER_DWORDS == FIFO_DEPTH)
      else $fatal(1, "OCP max transfer size must match the physical FIFO depth");
  end

  always_comb begin
    is_fifo_ctrl   = fifo_rb_sel && (fifo_rb_cmd == OCP_CMD_INDIRECT_FIFO_CTRL);
    is_fifo_status = fifo_rb_sel && (fifo_rb_cmd == OCP_CMD_INDIRECT_FIFO_STATUS);
    is_fifo_data   = fifo_rb_sel && (fifo_rb_cmd == OCP_CMD_INDIRECT_FIFO_DATA);
    is_reg_cmd     = is_fifo_ctrl || is_fifo_status;
    rb_req         = fifo_rb_sel && (fifo_rb_wr || fifo_rb_rd);
    word_idx       = fifo_rb_offset[2:0];
    unused_compat  = ^{clk_rd, rst_rd_n, fifo_rd_ready};
  end

  assign usb_ctrl_word0_wr = is_fifo_ctrl && fifo_rb_wr && (word_idx == 3'd0);
  assign usb_ctrl_word1_wr = is_fifo_ctrl && fifo_rb_wr && (word_idx == 3'd1);
  assign ext_ctrl_word0_wr = ext_fifo_ctrl_0_access && ext_cpuif_req_is_wr;
  assign ext_ctrl_word1_wr = ext_fifo_ctrl_1_access && ext_cpuif_req_is_wr;

  assign usb_status_rd = is_fifo_status && fifo_rb_rd;
  assign ext_status_0_rd = ext_fifo_status_0_access && !ext_cpuif_req_is_wr;
  assign ext_status_1_rd = ext_fifo_status_1_access && !ext_cpuif_req_is_wr;
  assign ext_status_2_rd = ext_fifo_status_2_access && !ext_cpuif_req_is_wr;
  assign ext_status_3_rd = ext_fifo_status_3_access && !ext_cpuif_req_is_wr;
  assign ext_status_4_rd = ext_fifo_status_4_access && !ext_cpuif_req_is_wr;

  assign usb_data_wr = is_fifo_data && fifo_rb_wr;
  assign usb_data_rd = is_fifo_data && fifo_rb_rd;
  assign ext_data_wr = ext_fifo_data_access && ext_cpuif_req_is_wr;
  assign ext_data_rd = ext_fifo_data_access && !ext_cpuif_req_is_wr;

  assign ctrl_word0_wdata = usb_ctrl_word0_wr ? fifo_rb_wdata : ext_cpuif_wr_data;
  assign ctrl_word1_wdata = usb_ctrl_word1_wr ? fifo_rb_wdata : ext_cpuif_wr_data;
  assign ctrl_word0_wstrb = usb_ctrl_word0_wr ? fifo_rb_wstrb : ext_cpuif_wr_strb;
  assign ctrl_word1_wstrb = usb_ctrl_word1_wr ? fifo_rb_wstrb : ext_cpuif_wr_strb;

  assign write_index_next = fifo_index_next(write_index_q);
  assign read_index_derived = fifo_index_sub_depth(write_index_q, fifo_wdepth);
  assign fifo_occupancy = fifo_wdepth;
  assign fifo_empty = (fifo_wdepth == FIFO_DEPTH_W'(0));
  assign fifo_full  = fifo_full_int;
  assign image_complete = (image_size_q != '0) && (accepted_push_count_q >= image_size_q);

  assign push_req = usb_data_wr || ext_data_wr;
  assign push_accept = fifo_wvalid && fifo_wready;
  assign push_drop_full = push_req && fifo_full && !image_complete && !fifo_clear;
  assign push_raw_wdata = usb_data_wr ? fifo_rb_wdata : ext_cpuif_wr_data;
  assign push_wstrb = usb_data_wr ? fifo_rb_wstrb : ext_cpuif_wr_strb;
  always_comb begin
    push_wdata = '0;
    for (int i = 0; i < 4; i++) begin
      if (push_wstrb[i]) begin
        push_wdata[i*8 +: 8] = push_raw_wdata[i*8 +: 8];
      end
    end
  end

  assign pop_req = usb_data_rd || ext_data_rd;
  assign pop_accept = pop_req && fifo_rvalid_int && !fifo_clear;
  assign push_creates_head = push_accept && fifo_empty;
  assign ext_head_change = pop_accept || push_creates_head || fifo_clear;
  assign fifo_becomes_full = push_accept
                           && (fifo_wdepth == FIFO_DEPTH_W'(FIFO_DEPTH - 1));
  assign fifo_becomes_empty = pop_accept
                            && (fifo_wdepth == FIFO_DEPTH_W'(1));
  assign terminal_image_push = push_accept && (image_size_q != '0)
                            && ((accepted_push_count_q + 32'd1) >= image_size_q);

  always_comb begin
    fifo_wvalid = push_req && !image_complete && !fifo_clear;
    fifo_wdata  = push_wdata;
    fifo_rready_int = pop_req && !fifo_clear;
  end

  always_comb begin
    status_byte_0 = {6'b0, fifo_full, fifo_empty};
    fifo_status_live_word_0 = {16'h0000, 8'h00, status_byte_0};
    fifo_status_live_word_1 = write_index_q;
    fifo_status_live_word_2 = read_index_derived;
    fifo_status_live_word_3 = FIFO_SIZE_DWORDS;
    fifo_status_live_word_4 = MAX_XFER_SIZE_DWORDS;
  end

  assign usb_fifo_status_snapshot_start = usb_status_rd && (word_idx == 3'd0);
  assign ext_fifo_status_snapshot_start = ext_status_0_rd;
  assign usb_fifo_status_snapshot_use = usb_status_snapshot_vld_q;
  assign ext_fifo_status_snapshot_use = ext_status_snapshot_vld_q;

  always_comb begin
    fifo_flush = 1'b0;
    if (usb_ctrl_word0_wr || ext_ctrl_word0_wr) begin
      fifo_flush = ctrl_word0_wstrb[1] && ctrl_word0_wdata[8];
    end
  end
  assign fifo_clear = fifo_flush || fifo_abort_i;

  caliptra_prim_fifo_sync #(
    .Width            (FIFO_WIDTH),
    .Pass             (1'b0),
    .Depth            (FIFO_DEPTH),
    .OutputZeroIfEmpty(1'b0)
  ) u_indirect_fifo (
    .clk_i    (clk),
    .rst_ni   (rst_ni),
    .clr_i    (fifo_clear),
    .wvalid_i (fifo_wvalid),
    .wready_o (fifo_wready),
    .wdata_i  (fifo_wdata),
    .rvalid_o (fifo_rvalid_int),
    .rready_i (fifo_rready_int),
    .rdata_o  (fifo_rdata_int),
    .full_o   (fifo_full_int),
    .depth_o  (fifo_wdepth),
    .err_o    ()
  );

  // Single-clock synchronous FIFO: the read-side depth equals the write-side
  // depth exposed on depth_o.
  assign fifo_rdepth_int = fifo_wdepth;

  always_ff @(posedge clk) begin
    if (!rst_ni) begin
      fifo_cms_q          <= '0;
      image_size_q        <= '0;
      write_index_q       <= '0;
      accepted_push_count_q <= '0;
      overflow_q          <= 1'b0;
      region_reset_q      <= 1'b0;
      image_done_q        <= 1'b0;
      image_push_active_q <= 1'b0;
      payload_available_q <= 1'b0;
      batch_aborted_q    <= 1'b0;
      ext_data_mirror_ready_q <= 1'b0;
      usb_status_snapshot_vld_q <= 1'b0;
      usb_status_snapshot_next_word_q <= '0;
      ext_status_snapshot_vld_q <= 1'b0;
      ext_status_snapshot_next_word_q <= '0;
      for (int i = 0; i < 5; i++) begin
        usb_status_snapshot_q[i] <= '0;
        ext_status_snapshot_q[i] <= '0;
      end
    end else begin
      if (fifo_clear || fifo_becomes_empty || (fifo_empty && !push_accept)) begin
        payload_available_q <= 1'b0;
      end else if (fifo_becomes_full || terminal_image_push) begin
        payload_available_q <= 1'b1;
      end

      if (usb_fifo_status_snapshot_start) begin
        usb_status_snapshot_vld_q <= 1'b1;
        usb_status_snapshot_next_word_q <= 3'd1;
        usb_status_snapshot_q[0] <= fifo_status_live_word_0;
        usb_status_snapshot_q[1] <= fifo_status_live_word_1;
        usb_status_snapshot_q[2] <= fifo_status_live_word_2;
        usb_status_snapshot_q[3] <= fifo_status_live_word_3;
        usb_status_snapshot_q[4] <= fifo_status_live_word_4;
      end else if (usb_status_rd) begin
        if (usb_status_snapshot_vld_q && (word_idx == usb_status_snapshot_next_word_q)) begin
          if (word_idx == 3'd4) begin
            usb_status_snapshot_vld_q <= 1'b0;
            usb_status_snapshot_next_word_q <= '0;
          end else begin
            usb_status_snapshot_next_word_q <= usb_status_snapshot_next_word_q + 3'd1;
          end
        end else begin
          usb_status_snapshot_vld_q <= 1'b0;
          usb_status_snapshot_next_word_q <= '0;
        end
      end

      if (ext_fifo_status_snapshot_start) begin
        ext_status_snapshot_vld_q <= 1'b1;
        ext_status_snapshot_next_word_q <= 3'd1;
        ext_status_snapshot_q[0] <= fifo_status_live_word_0;
        ext_status_snapshot_q[1] <= fifo_status_live_word_1;
        ext_status_snapshot_q[2] <= fifo_status_live_word_2;
        ext_status_snapshot_q[3] <= fifo_status_live_word_3;
        ext_status_snapshot_q[4] <= fifo_status_live_word_4;
      end else if (ext_status_1_rd || ext_status_2_rd || ext_status_3_rd || ext_status_4_rd) begin
        unique case (1'b1)
          ext_status_1_rd: begin
            if (ext_status_snapshot_vld_q && (ext_status_snapshot_next_word_q == 3'd1)) begin
              ext_status_snapshot_next_word_q <= 3'd2;
            end else begin
              ext_status_snapshot_vld_q <= 1'b0;
              ext_status_snapshot_next_word_q <= '0;
            end
          end
          ext_status_2_rd: begin
            if (ext_status_snapshot_vld_q && (ext_status_snapshot_next_word_q == 3'd2)) begin
              ext_status_snapshot_next_word_q <= 3'd3;
            end else begin
              ext_status_snapshot_vld_q <= 1'b0;
              ext_status_snapshot_next_word_q <= '0;
            end
          end
          ext_status_3_rd: begin
            if (ext_status_snapshot_vld_q && (ext_status_snapshot_next_word_q == 3'd3)) begin
              ext_status_snapshot_next_word_q <= 3'd4;
            end else begin
              ext_status_snapshot_vld_q <= 1'b0;
              ext_status_snapshot_next_word_q <= '0;
            end
          end
          ext_status_4_rd: begin
            ext_status_snapshot_vld_q <= 1'b0;
            ext_status_snapshot_next_word_q <= '0;
          end
          default: begin
            ext_status_snapshot_vld_q <= 1'b0;
            ext_status_snapshot_next_word_q <= '0;
          end
        endcase
      end

      if (usb_ctrl_word0_wr) begin
        if (ctrl_word0_wstrb[0]) fifo_cms_q <= ctrl_word0_wdata[7:0];
        if (ctrl_word0_wstrb[2]) image_size_q[7:0] <= ctrl_word0_wdata[23:16];
        if (ctrl_word0_wstrb[3]) image_size_q[15:8] <= ctrl_word0_wdata[31:24];
        if (ctrl_word0_wstrb[1] && ctrl_word0_wdata[8]) begin
          write_index_q       <= '0;
          accepted_push_count_q <= '0;
          overflow_q          <= 1'b0;
          region_reset_q      <= 1'b1;
          image_done_q        <= 1'b0;
          image_push_active_q <= 1'b0;
          ext_data_mirror_ready_q <= 1'b0;
          usb_status_snapshot_vld_q <= 1'b0;
          usb_status_snapshot_next_word_q <= '0;
          ext_status_snapshot_vld_q <= 1'b0;
          ext_status_snapshot_next_word_q <= '0;
        end
      end else if (ext_ctrl_word0_wr) begin
        if (ctrl_word0_wstrb[0]) fifo_cms_q <= ctrl_word0_wdata[7:0];
        if (ctrl_word0_wstrb[1] && ctrl_word0_wdata[8]) begin
          write_index_q       <= '0;
          accepted_push_count_q <= '0;
          overflow_q          <= 1'b0;
          region_reset_q      <= 1'b1;
          image_done_q        <= 1'b0;
          image_push_active_q <= 1'b0;
          ext_data_mirror_ready_q <= 1'b0;
          usb_status_snapshot_vld_q <= 1'b0;
          usb_status_snapshot_next_word_q <= '0;
          ext_status_snapshot_vld_q <= 1'b0;
          ext_status_snapshot_next_word_q <= '0;
        end
      end

      if (usb_ctrl_word1_wr) begin
        if (ctrl_word1_wstrb[0]) image_size_q[23:16] <= ctrl_word1_wdata[7:0];
        if (ctrl_word1_wstrb[1]) image_size_q[31:24] <= ctrl_word1_wdata[15:8];
      end else if (ext_ctrl_word1_wr) begin
        if (ctrl_word1_wstrb[0]) image_size_q[7:0]   <= ctrl_word1_wdata[7:0];
        if (ctrl_word1_wstrb[1]) image_size_q[15:8]  <= ctrl_word1_wdata[15:8];
        if (ctrl_word1_wstrb[2]) image_size_q[23:16] <= ctrl_word1_wdata[23:16];
        if (ctrl_word1_wstrb[3]) image_size_q[31:24] <= ctrl_word1_wdata[31:24];
      end

      if (push_accept) begin
        write_index_q       <= write_index_next;
        accepted_push_count_q <= accepted_push_count_q + 32'd1;
        image_push_active_q <= 1'b1;
        if (terminal_image_push) begin
          image_done_q        <= 1'b1;
          image_push_active_q <= 1'b0;
        end
      end

      if (push_drop_full) begin
        overflow_q <= 1'b1;
      end

      if (ext_head_change) begin
        ext_data_mirror_ready_q <= 1'b0;
      end else if (fifo_rvalid_int || fifo_empty) begin
        ext_data_mirror_ready_q <= 1'b1;
      end else begin
        ext_data_mirror_ready_q <= 1'b0;
      end

      if (fifo_abort_i) begin
        write_index_q          <= '0;
        accepted_push_count_q  <= '0;
        overflow_q             <= 1'b0;
        image_done_q           <= 1'b0;
        image_push_active_q    <= 1'b0;
        payload_available_q    <= 1'b0;
        ext_data_mirror_ready_q <= 1'b0;
        usb_status_snapshot_vld_q <= 1'b0;
        usb_status_snapshot_next_word_q <= '0;
        ext_status_snapshot_vld_q <= 1'b0;
        ext_status_snapshot_next_word_q <= '0;
      end
      if (fifo_flush) begin
        batch_aborted_q <= 1'b0;
      end else if (fifo_abort_i) begin
        batch_aborted_q <= 1'b1;
      end
    end
  end

  always_comb begin
    fifo_rb_rdata = 32'h0;
    if (usb_data_rd) begin
      fifo_rb_rdata = fifo_rvalid_int ? fifo_rdata_int : 32'h0;
    end else if (usb_status_rd) begin
      unique case (word_idx)
        3'd0: fifo_rb_rdata = usb_fifo_status_snapshot_use ? usb_status_snapshot_q[0] : fifo_status_live_word_0;
        3'd1: fifo_rb_rdata = usb_fifo_status_snapshot_use ? usb_status_snapshot_q[1] : fifo_status_live_word_1;
        3'd2: fifo_rb_rdata = usb_fifo_status_snapshot_use ? usb_status_snapshot_q[2] : fifo_status_live_word_2;
        3'd3: fifo_rb_rdata = usb_fifo_status_snapshot_use ? usb_status_snapshot_q[3] : fifo_status_live_word_3;
        3'd4: fifo_rb_rdata = usb_fifo_status_snapshot_use ? usb_status_snapshot_q[4] : fifo_status_live_word_4;
        default: fifo_rb_rdata = 32'h0;
      endcase
    end
  end

  always_comb begin
    fifo_rb_ack = rb_req && (is_reg_cmd || is_fifo_data);
    fifo_rb_err = 1'b0;
    if (fifo_rb_sel && !(is_reg_cmd || is_fifo_data)) begin
      fifo_rb_err = rb_req;
    end
  end

  always_comb begin
    fifo_rd_valid = fifo_rvalid_int;
    fifo_rd_data  = fifo_rdata_int;
    fifo_rd_depth = fifo_rdepth_int;

    image_push_active = image_push_active_q;
    image_push_done   = image_done_q;
    fifo_overflow     = overflow_q;
    payload_available = payload_available_q;
    fifo_reset_pulse  = fifo_flush;
    batch_aborted     = batch_aborted_q;
    image_size        = {image_size_q[29:0], 2'b00};
    bytes_pushed      = {accepted_push_count_q[29:0], 2'b00};

    fifo_ctrl_cms        = fifo_cms_q;
    fifo_ctrl_reset      = region_reset_q;
    fifo_ctrl_image_size = image_size_q;

    fifo_status_word_0 = ext_fifo_status_snapshot_use ? ext_status_snapshot_q[0] : fifo_status_live_word_0;
    fifo_status_word_1 = ext_fifo_status_snapshot_use ? ext_status_snapshot_q[1] : fifo_status_live_word_1;
    fifo_status_word_2 = ext_fifo_status_snapshot_use ? ext_status_snapshot_q[2] : fifo_status_live_word_2;
    fifo_status_word_3 = ext_fifo_status_snapshot_use ? ext_status_snapshot_q[3] : fifo_status_live_word_3;
    fifo_status_word_4 = ext_fifo_status_snapshot_use ? ext_status_snapshot_q[4] : fifo_status_live_word_4;
    fifo_data_peek     = fifo_rvalid_int ? fifo_rdata_int : 32'h0;
    ext_data_mirror_ready = ext_data_mirror_ready_q;
  end

`ifndef SYNTHESIS
  // synopsys translate_off
  always_ff @(posedge clk) begin
    if (rst_ni) begin
      if (fifo_rb_sel) begin
        assert (!$isunknown(fifo_rb_cmd))
          else $error("usb_ocp_recovery_cms_fifo: fifo_rb_cmd is X");
      end
      assert (!(push_req && pop_req))
        else $error("usb_ocp_recovery_cms_fifo: USB and EXT sources must serialize push and pop requests");
      assert (!(fifo_flush && (push_req || pop_req)))
        else $error("usb_ocp_recovery_cms_fifo: FIFO flush (INDIRECT_FIFO_CTRL reset) collided with a data push/pop; clr_i and the synchronous control-plane reset assume mutual exclusivity");
      assert (!(fifo_abort_i && (push_accept || pop_accept)))
        else $error("usb_ocp_recovery_cms_fifo: abort accepted a FIFO transfer");
      assert (!(usb_data_rd && ext_data_rd))
        else $error("usb_ocp_recovery_cms_fifo: both sources attempted DATA pop");
      assert (!ext_data_rd || ext_data_mirror_ready_q)
        else $error("usb_ocp_recovery_cms_fifo: EXT data read fired before the regblock mirror was ready");
      if ($past(rst_ni)) begin
        assert (!$past(ext_head_change) || !ext_data_mirror_ready_q)
          else $error("usb_ocp_recovery_cms_fifo: head-changing event failed to clear EXT mirror readiness");
      end
      assert (!((usb_data_wr || usb_data_rd || usb_ctrl_word0_wr || usb_ctrl_word1_wr)
                && (ext_data_wr || ext_data_rd || ext_ctrl_word0_wr || ext_ctrl_word1_wr)))
        else $error("usb_ocp_recovery_cms_fifo: USB and EXT fifo control/data activity collided");
      assert (write_index_q <= FIFO_INDEX_MAX_DWORDS)
        else $error("usb_ocp_recovery_cms_fifo: WRITE_INDEX exceeded 64");
      assert (read_index_derived <= FIFO_INDEX_MAX_DWORDS)
        else $error("usb_ocp_recovery_cms_fifo: READ_INDEX exceeded 64");
      assert (fifo_occupancy == fifo_wdepth)
        else $error("usb_ocp_recovery_cms_fifo: protocol occupancy mismatches write-domain depth");
      assert (read_index_derived == fifo_index_sub_depth(write_index_q, fifo_wdepth))
        else $error("usb_ocp_recovery_cms_fifo: READ_INDEX derivation mismatch");
      assert (fifo_empty == (fifo_wdepth == FIFO_DEPTH_W'(0)))
        else $error("usb_ocp_recovery_cms_fifo: EMPTY mismatches write-domain depth");
      assert (fifo_full == (fifo_wdepth == FIFO_DEPTH_W'(FIFO_DEPTH)))
        else $error("usb_ocp_recovery_cms_fifo: FULL without physical depth");
      assert (!payload_available_q || !fifo_empty)
        else $error("usb_ocp_recovery_cms_fifo: payload available while FIFO empty");
      assert (!batch_aborted_q || !payload_available_q)
        else $error("usb_ocp_recovery_cms_fifo: aborted batch remains available");
      assert (!ext_data_rd || payload_available_q)
        else $error("usb_ocp_recovery_cms_fifo: EXT read before payload available");
      if (push_accept) begin
        for (int i = 0; i < 4; i++) begin
          if (!push_wstrb[i]) begin
            assert (fifo_wdata[i*8 +: 8] == 8'h00)
              else $error("usb_ocp_recovery_cms_fifo: masked byte was not zero padded");
          end
        end
      end
      if ($past(rst_ni) && $past(batch_aborted_q) && !fifo_flush) begin
        assert (batch_aborted_q)
          else $error("usb_ocp_recovery_cms_fifo: batch aborted cleared without reset");
      end
      if ($past(rst_ni) && $past(payload_available_q) && !fifo_clear && !fifo_empty) begin
        assert (payload_available_q)
          else $error("usb_ocp_recovery_cms_fifo: payload available dropped before FIFO empty");
      end
      if (push_drop_full) begin
        assert ($stable(write_index_q))
          else $error("usb_ocp_recovery_cms_fifo: rejected push changed WRITE_INDEX");
        assert ($stable(accepted_push_count_q))
          else $error("usb_ocp_recovery_cms_fifo: rejected push changed accepted push count");
      end
      if (ext_data_rd) begin
        assert (pop_accept)
          else $error("usb_ocp_recovery_cms_fifo: non-empty EXT data read did not pop exactly one word");
      end
    end
  end
  // synopsys translate_on
`endif

endmodule : usb_ocp_recovery_cms_fifo
