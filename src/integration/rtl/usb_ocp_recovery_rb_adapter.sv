// SPDX-License-Identifier: Apache-2.0
// ============================================================================
// usb_ocp_recovery_rb_adapter.sv
//
// Bridges the held 32-bit AHB client request to the passthrough CPU interface
// emitted by the peakrdl-generated USB Recovery register block.
// USB Recovery Agent commands use the dedicated hardware-interface and FIFO
// paths in usb_ocp_recovery_top and do not pass through this adapter.
//
// The upstream request remains asserted while ext_hld is high. write_pending_q
// converts that held level into one cpuif_req pulse so software-access side
// effects occur exactly once. Reads return the combinational CPUif response in
// the issue cycle. Writes return a registered completion on the following
// cycle. USB priority and FIFO availability are enforced before cpuif_req.
// ============================================================================

module usb_ocp_recovery_rb_adapter
  import usb_ocp_recovery_pkg::*;
(
  input  logic        clk,
  input  logic        rst_ni,

  // Held request from ahb_slv_sif.
  input  logic        ext_dv,
  input  logic        ext_write,
  input  logic [31:0] ext_wdata,
  input  logic [OCP_RECOVERY_APERTURE_ADDR_W-1:0] ext_addr,
  output logic [31:0] ext_rdata,
  output logic        ext_hld,
  output logic        ext_err,

  // USB/resource ownership used to block before CPUif commit.
  input  logic        usb_req,
  input  logic        usb_fifo_owned,
  input  logic        payload_available,

  // PeakRDL passthrough CPU interface.
  output logic        cpuif_req,
  output logic        cpuif_req_is_wr,
  output logic [OCP_RECOVERY_APERTURE_ADDR_W-1:0]
                       cpuif_addr,
  output logic [31:0] cpuif_wr_data,
  output logic [31:0] cpuif_wr_biten,
  input  logic        cpuif_rd_ack,
  input  logic        cpuif_rd_err,
  input  logic [31:0] cpuif_rd_data,
  input  logic        cpuif_wr_ack,
  input  logic        cpuif_wr_err
);

  logic access;
  logic [OCP_RECOVERY_APERTURE_ADDR_W-1:0] aligned_ext_addr;
  logic fifo_aperture_access;
  logic fifo_data_aperture_access;
  logic request_blocked;
  logic write_pending_q;
  logic cpuif_fire;
  logic local_read_fire;
  logic write_ack_q;
  logic write_err_q;
  logic completion;
  logic completion_err;

  assign access = ext_dv;
  assign aligned_ext_addr = { ext_addr[OCP_RECOVERY_APERTURE_ADDR_W-1:2], 2'b00 };
  assign fifo_aperture_access =    (aligned_ext_addr >= OCP_ADDR_INDIRECT_FIFO_CTRL[OCP_RECOVERY_APERTURE_ADDR_W-1:0])
                                && (aligned_ext_addr < OCP_ADDR_VENDOR[OCP_RECOVERY_APERTURE_ADDR_W-1:0]);
  assign fifo_data_aperture_access =    (aligned_ext_addr >= OCP_ADDR_INDIRECT_FIFO_DATA[OCP_RECOVERY_APERTURE_ADDR_W-1:0])
                                     && (aligned_ext_addr < OCP_ADDR_VENDOR[OCP_RECOVERY_APERTURE_ADDR_W-1:0]);
  assign request_blocked =    usb_req
                           || (fifo_aperture_access && usb_fifo_owned)
                           || (fifo_data_aperture_access && !ext_write && !payload_available);
  assign cpuif_fire = access && !write_pending_q && !request_blocked;
  assign local_read_fire = cpuif_fire && !ext_write;

  assign cpuif_req       = cpuif_fire;
  assign cpuif_req_is_wr = ext_write;
  assign cpuif_addr      = aligned_ext_addr;
  assign cpuif_wr_data   = ext_wdata;
  assign cpuif_wr_biten  = '1;

  always_ff @(posedge clk or negedge rst_ni) begin
    if (!rst_ni) begin
      write_ack_q     <= 1'b0;
      write_err_q     <= 1'b0;
      write_pending_q <= 1'b0;
    end else begin
      write_ack_q <= 1'b0;
      write_err_q <= 1'b0;

      if (cpuif_fire && ext_write) begin
        write_pending_q <= 1'b1;
        write_ack_q     <= 1'b1;
        write_err_q     <= cpuif_wr_err;
      end else if (write_pending_q) begin
        write_pending_q <= 1'b0;
      end
    end
  end

  assign completion     = local_read_fire ? cpuif_rd_ack : write_ack_q;
  assign completion_err = local_read_fire ? cpuif_rd_err : write_err_q;
  assign ext_hld        = access && !completion;
  assign ext_err        = ext_dv && completion && completion_err;
  assign ext_rdata      = local_read_fire ? cpuif_rd_data : '0;

`ifndef SYNTHESIS
  // synopsys translate_off
  always_ff @(posedge clk) begin
    if (rst_ni) begin
      if (access) begin
        assert (!$isunknown({ext_addr, ext_write}))
          else $error("usb_ocp_recovery_rb_adapter: X on EXT address or direction");
        assert (ext_addr[1:0] == 2'b00)
          else $error("usb_ocp_recovery_rb_adapter: ahb_slv_sif emitted a non-word-aligned address");
      end
      if (access && ext_write) begin
        assert (!$isunknown(ext_wdata))
          else $error("usb_ocp_recovery_rb_adapter: X on EXT write data");
      end
      if (local_read_fire) begin
        assert (cpuif_req && cpuif_rd_ack)
          else $error("usb_ocp_recovery_rb_adapter: EXT read missed same-cycle CPUif ack");
      end
      if (cpuif_fire && ext_write) begin
        assert (cpuif_wr_ack)
          else $error("usb_ocp_recovery_rb_adapter: EXT write missed CPUif ack");
      end
      if (request_blocked) begin
        assert (!cpuif_req)
          else $error("usb_ocp_recovery_rb_adapter: blocked EXT request fired CPUif");
      end
      if (write_ack_q) begin
        assert (write_pending_q && !cpuif_req)
          else $error("usb_ocp_recovery_rb_adapter: write completion was not a pending tail");
      end
    end
  end
  // synopsys translate_on
`endif

endmodule
