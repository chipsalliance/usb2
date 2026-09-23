// SPDX-License-Identifier: Apache-2.0
// ============================================================================
// usb_ocp_recovery_rb_adapter.sv
//
// Bridges held 32-bit EXT/AHB register requests to the passthrough CPU
// interface emitted by the peakrdl-generated USB Recovery register block.
// USB Recovery Agent commands use the dedicated hardware-interface and FIFO
// paths in usb_ocp_recovery_top and do not pass through this adapter.
//
// The upstream EXT request remains asserted until rb_ack. regblock_busy_q
// converts that held level into one cpuif_req pulse so software-access side
// effects occur exactly once. Reads return the combinational CPUif response in
// the request cycle. Writes return a registered acknowledgement.
// ============================================================================

module usb_ocp_recovery_rb_adapter
  import usb_ocp_recovery_pkg::*;
(
  input  logic        clk,
  input  logic        rst_ni,

  // Held EXT request from the AHB bridge.
  input  logic        rb_wr,
  input  logic        rb_rd,
  input  logic [31:0] rb_wdata,
  input  logic [3:0]  rb_wstrb,
  output logic [31:0] rb_rdata,
  output logic        rb_ack,
  output logic        rb_err,

  // Aperture-relative byte address captured by ahb_slv_sif.
  input  logic [OCP_RECOVERY_APERTURE_ADDR_W-1:0]
                       ext_aperture_offset,

  // PeakRDL passthrough CPU interface.
  output logic        cpuif_req,
  output logic        cpuif_req_is_wr,
  output logic [OCP_RECOVERY_APERTURE_ADDR_W-1:0]
                       cpuif_addr,
  output logic [31:0] cpuif_wr_data,
  output logic [31:0] cpuif_wr_biten,
  input  logic        cpuif_req_block,
  input  logic        cpuif_rd_ack,
  input  logic        cpuif_rd_err,
  input  logic [31:0] cpuif_rd_data,
  input  logic        cpuif_wr_ack,
  input  logic        cpuif_wr_err
);

  logic access;
  logic regblock_busy_q;
  logic cpuif_fire;
  logic local_read_fire;
  logic rb_ack_q;
  logic rb_err_q;

  assign access          = rb_wr | rb_rd;
  assign cpuif_fire      = access & ~regblock_busy_q & ~cpuif_req_block;
  assign local_read_fire = rb_rd & cpuif_fire;

  assign cpuif_req       = cpuif_fire;
  assign cpuif_req_is_wr = rb_wr;
  assign cpuif_addr      = ext_aperture_offset;
  assign cpuif_wr_data   = rb_wdata;
  assign cpuif_wr_biten  = {{8{rb_wstrb[3]}}, {8{rb_wstrb[2]}},
                            {8{rb_wstrb[1]}}, {8{rb_wstrb[0]}}};

  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) begin
      rb_ack_q        <= 1'b0;
      rb_err_q        <= 1'b0;
      regblock_busy_q <= 1'b0;
    end else begin
      rb_ack_q <= 1'b0;
      rb_err_q <= 1'b0;

      if (cpuif_fire) begin
        regblock_busy_q <= 1'b1;
        if (rb_wr) begin
          rb_ack_q <= 1'b1;
          rb_err_q <= cpuif_wr_err;
        end
      end else if (regblock_busy_q) begin
        regblock_busy_q <= 1'b0;
      end
    end
  end

  assign rb_ack   = local_read_fire ? cpuif_rd_ack : rb_ack_q;
  assign rb_err   = local_read_fire ? cpuif_rd_err : rb_err_q;
  assign rb_rdata = local_read_fire ? cpuif_rd_data : '0;

`ifndef SYNTHESIS
  // synopsys translate_off
  always_ff @(posedge clk) begin
    if (rst_ni) begin
      assert (!(rb_wr && rb_rd))
        else $error("usb_ocp_recovery_rb_adapter: rb_wr and rb_rd both asserted");
      if (access) begin
        assert (!$isunknown({ext_aperture_offset, rb_wstrb}))
          else $error("usb_ocp_recovery_rb_adapter: X on EXT address or byte enables");
      end
      if (rb_wr) begin
        assert (!$isunknown(rb_wdata))
          else $error("usb_ocp_recovery_rb_adapter: X on EXT write data");
      end
      if (local_read_fire) begin
        assert (cpuif_req && cpuif_rd_ack)
          else $error("usb_ocp_recovery_rb_adapter: EXT read missed same-cycle CPUif ack");
      end
      if (cpuif_fire && rb_wr) begin
        assert (cpuif_wr_ack)
          else $error("usb_ocp_recovery_rb_adapter: EXT write missed CPUif ack");
      end
    end
  end
  // synopsys translate_on
`endif

endmodule
