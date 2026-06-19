// SPDX-License-Identifier: Apache-2.0
// ============================================================================
// usb_ocp_recovery_rb_adapter.sv
//
// Word-granular OCP Recovery v1.1 reg-bus adapter.  Bridges the 32-bit
// word-wide rb_* protocol (cmd[7:0] + word offset[15:0] + wdata[31:0] +
// wstrb[3:0]) used by A2 (ctrl_decode) and the SoC AHB sub-decoder to the
// DWORD-aligned passthrough CPU interface emitted by the peakrdl-generated
// usb_ocp_recovery regblock (see
// third_party/usb2/src/integration/rtl/generated/usb_ocp_recovery_reg.sv).
//
// rb_* is native 32-bit.  Bytes exist only on the USB wire and on the SoC AHB
// byte aperture; everything from here up to the PIE 64-bit beat is word-wide.
// rb_offset is a word index into the command window.  DEVICE_RESET and
// RECOVERY_CTRL flow through the normal CPUIF path so the regblock owns field
// layout and swmod generation, while the top-level wrapper aligns those swmod
// strobes with the registered field values before they reach the recovery FSM.
// Writes drive cpuif_wr_data = rb_wdata and expand cpuif_wr_biten from
// rb_wstrb (each strobe bit -> 8 biten bits) for native byte-enable partial-
// word writes.
//
// Endianness is preserved end-to-end: OCP byte at command-window offset N maps
// to CPUIF bits [N*8 +: 8] (little-endian byte-in-word).  Word offset W maps
// to CPUIF byte address cmd_base + (W << 2) and rb_wdata[7:0] is the lowest
// command-window byte of that word.  This matches OCP Recovery v1.1 Sec 9.2
// (little-endian) and the PeakRDL little-endian field placement.
//
// FIFO branch: commands 0x2C/0x2D/0x2E (INDIRECT_FIFO_*) are routed to A4
// (usb_ocp_recovery_cms_fifo).  This adapter forwards the word + strobe + word
// offset straight through and returns cms_fifo's word-level ack/err/rdata
// combinationally; cms_fifo owns the byte-wise sequencing against external CMS
// SRAM.  The direct CMS-memory window (0x29/0x2A/0x2B) is not implemented: it is
// advertised unsupported in PROT_CAP and dropped/ACKed as an invalid command.
//
// Latency:
//   - Regblock cmd ack: 1 cycle after rb_wr/rb_rd (registered), single-cycle
//     cpuif_req pulse so swmod fires exactly once per word.
//   - FIFO cmd ack: word-level ack from cms_fifo (combinational passthrough;
//     register records same-cycle, SRAM records when the byte sequence ends).
//
// Reset: synchronous, active-high (SV integration convention).
// ============================================================================

module usb_ocp_recovery_rb_adapter (
  input  logic        clk,
  input  logic        rst,

  // --------------------------------------------------------------------------
  // Word-wide reg-bus (producer: A2 ctrl_decode or top-level arbiter / AHB).
  // rb_offset is a word index into the command window.  rb_wstrb marks the
  // valid byte lanes (writes: byte-enable; reads: which lanes the consumer
  // will use, so the FIFO path returns exactly that many bytes).
  // --------------------------------------------------------------------------
  input  logic [7:0]  rb_cmd,
  input  logic [15:0] rb_offset,
  input  logic        rb_wr,
  input  logic        rb_rd,
  input  logic [31:0] rb_wdata,
  input  logic [3:0]  rb_wstrb,
  output logic [31:0] rb_rdata,
  output logic        rb_ack,
  output logic        rb_err,

  // --------------------------------------------------------------------------
  // FIFO branch to A4 (cms_fifo).  Native 32-bit word + 4-bit byte
  // strobe passthrough; fifo_rb_offset carries the word index of the command
  // record.
  // --------------------------------------------------------------------------
  output logic        fifo_rb_sel,
  output logic [7:0]  fifo_rb_cmd,
  output logic [15:0] fifo_rb_offset,
  output logic        fifo_rb_wr,
  output logic        fifo_rb_rd,
  output logic [31:0] fifo_rb_wdata,
  output logic [3:0]  fifo_rb_wstrb,
  input  logic [31:0] fifo_rb_rdata,
  input  logic        fifo_rb_ack,
  input  logic        fifo_rb_err,

  // --------------------------------------------------------------------------
  // peakrdl-regblock passthrough CPU interface (0-cycle balanced ack).
  // --------------------------------------------------------------------------
  output logic        cpuif_req,
  output logic        cpuif_req_is_wr,
  output logic [11:0] cpuif_addr,
  output logic [31:0] cpuif_wr_data,
  output logic [31:0] cpuif_wr_biten,
  input  logic        cpuif_rd_ack,
  input  logic        cpuif_rd_err,
  input  logic [31:0] cpuif_rd_data,
  input  logic        cpuif_wr_ack,
  input  logic        cpuif_wr_err,

  // --------------------------------------------------------------------------
  // HW_STATUS sideband write pulse to A5 FSM.  HW_STATUS regblock fields are
  // hw=w / we=false (host writes ignored at the regblock), so the host write
  // is converted to a sideband pulse + low byte rather than a cpuif write.
  // proto_err_rd_pulse implements PROTOCOL_ERROR onread=rclr (OCP Recovery
  // v1.1 Sec 9.2 Tbl 9-5): pulse on a successful read of the DEVICE_STATUS
  // word that contains PROT_ERROR (byte 1 -> word 0).
  // --------------------------------------------------------------------------
  output logic        hw_status_wr,
  output logic [7:0]  hw_status_wdata,
  output logic        proto_err_rd_pulse
);

  // --------------------------------------------------------------------------
  // OCP command code -> byte-offset base in the regblock window.
  // Source of truth: third_party/usb2/systemrdl/usb_ocp_recovery_reg.rdl
  //   PROT_CAP_0       @ 0x000  (cmd 0x22, 16 B)
  //   DEVICE_ID_0      @ 0x010  (cmd 0x23, 24 B)
  //   DEVICE_STATUS_0  @ 0x028  (cmd 0x24, 64 B)
  //   DEVICE_RESET     @ 0x068  (cmd 0x25,  3 B, CPUIF/swmod)
  //   RECOVERY_CTRL    @ 0x06C  (cmd 0x26,  3 B, CPUIF/swmod)
  //   RECOVERY_STATUS  @ 0x070  (cmd 0x27,  2 B)
  //   HW_STATUS        @ 0x074  (cmd 0x28,  4 B, write is sideband-only)
  //   INDIRECT_FIFO_*  @ 0x100+ (cmds 0x2C..0x2E, FIFO-routed)
  //   VENDOR           @ 0x1A4  (cmd 0x2F,  1 B stub)
  //   Direct CMS-memory window 0x29/0x2A/0x2B (INDIRECT_CTRL/STATUS/DATA) is
  //   not implemented; unrecognized -> invalid-command drop/ack path.
  // --------------------------------------------------------------------------
  localparam logic [7:0] CMD_PROT_CAP             = 8'h22;
  localparam logic [7:0] CMD_DEVICE_ID            = 8'h23;
  localparam logic [7:0] CMD_DEVICE_STATUS        = 8'h24;
  localparam logic [7:0] CMD_DEVICE_RESET         = 8'h25;
  localparam logic [7:0] CMD_RECOVERY_CTRL        = 8'h26;
  localparam logic [7:0] CMD_RECOVERY_STATUS      = 8'h27;
  localparam logic [7:0] CMD_HW_STATUS            = 8'h28;
  // Direct CMS-memory window commands 0x29/0x2A/0x2B (INDIRECT_CTRL /
  // INDIRECT_STATUS / INDIRECT_DATA) are NOT implemented by this transport:
  // they are advertised as unsupported in PROT_CAP (FIFO-only) and fall through
  // to the invalid-command drop/ack path below (rdata=0, ack with err, no hang).
  localparam logic [7:0] CMD_INDIRECT_FIFO_CTRL   = 8'h2C;
  localparam logic [7:0] CMD_INDIRECT_FIFO_STATUS = 8'h2D;
  localparam logic [7:0] CMD_INDIRECT_FIFO_DATA   = 8'h2E;
  localparam logic [7:0] CMD_VENDOR               = 8'h2F;

  // DEVICE_STATUS word 0 holds DEV_STATUS (byte 0) + PROT_ERROR (byte 1)
  // + REC_REASON_CODE (bytes 2..3); reading word 0 read-clears PROTOCOL_ERROR.
  localparam logic [15:0] WOFF_DS_WORD0 = 16'd0;

  // --------------------------------------------------------------------------
  // FIFO-routing decode
  // --------------------------------------------------------------------------
  logic is_fifo_cmd;
  always_comb begin
    unique case (rb_cmd)
      CMD_INDIRECT_FIFO_CTRL,
      CMD_INDIRECT_FIFO_STATUS,
      CMD_INDIRECT_FIFO_DATA: is_fifo_cmd = 1'b1;
      default:                is_fifo_cmd = 1'b0;
    endcase
  end

  // --------------------------------------------------------------------------
  // Local command base address + payload length (bytes)
  // --------------------------------------------------------------------------
  logic        is_local_cmd;
  logic [11:0] cmd_base;
  logic [15:0] cmd_len;
  always_comb begin
    is_local_cmd = 1'b1;
    cmd_base     = 12'h000;
    cmd_len      = 16'd0;
    unique case (rb_cmd)
      CMD_PROT_CAP:        begin cmd_base = 12'h000; cmd_len = 16'd16; end
      CMD_DEVICE_ID:       begin cmd_base = 12'h010; cmd_len = 16'd24; end
      CMD_DEVICE_STATUS:   begin cmd_base = 12'h028; cmd_len = 16'd64; end
      CMD_DEVICE_RESET:    begin cmd_base = 12'h068; cmd_len = 16'd3;  end
      CMD_RECOVERY_CTRL:   begin cmd_base = 12'h06C; cmd_len = 16'd3;  end
      CMD_RECOVERY_STATUS: begin cmd_base = 12'h070; cmd_len = 16'd2;  end
      CMD_HW_STATUS:       begin cmd_base = 12'h074; cmd_len = 16'd4;  end
      CMD_VENDOR:          begin cmd_base = 12'h1A4; cmd_len = 16'd1;  end
      default:             is_local_cmd = 1'b0;
    endcase
  end

  // Byte address of the addressed word base = cmd_base + (rb_offset << 2).
  // off_ok: the word base byte must lie inside the command window.  Every
  // valid word (including a partial final word) has a base byte < cmd_len.
  logic        access;
  logic [13:0] word_base_byte;
  logic        off_ok;
  logic        local_access;
  assign access         = rb_wr | rb_rd;
  assign word_base_byte = {rb_offset[11:0], 2'b00};
  assign off_ok         = (word_base_byte < {2'b00, cmd_len[11:0]});
  assign local_access   = access & is_local_cmd & ~is_fifo_cmd;

  // --------------------------------------------------------------------------
  // FIFO branch passthrough.
  //
  // The word access engine lives entirely in A4 (cms_fifo): this adapter
  // forwards the 32-bit word + 4-bit byte strobe + word offset straight
  // through and returns cms_fifo's word-level ack/err/rdata combinationally.
  // cms_fifo sequences the byte-wide SRAM access internally so the shared
  // reg-bus still observes exactly one ack per word access.
  // --------------------------------------------------------------------------
  always_comb begin
    fifo_rb_sel    = is_fifo_cmd;
    fifo_rb_cmd    = rb_cmd;
    fifo_rb_offset = rb_offset;            // WORD index of the command record
    fifo_rb_wr     = is_fifo_cmd & rb_wr;
    fifo_rb_rd     = is_fifo_cmd & rb_rd;
    fifo_rb_wdata  = rb_wdata;
    fifo_rb_wstrb  = rb_wstrb;
  end

  // --------------------------------------------------------------------------
  // Regblock CPUIF path.
  //
  // A single-cycle cpuif_req pulse per word access (busy_q suppresses re-issue
  // while the upper master holds rb_wr/rb_rd through the registered ack), so
  // swmod fires exactly once per host write.  cpuif_rd_data is combinational
  // in the request cycle and is captured into rb_rdata_q for the ack cycle.
  // --------------------------------------------------------------------------
  logic regblock_busy_q;

  // A regblock cpuif access is issued for local non-FIFO commands except
  // dropped writes (HW_STATUS sideband-only, VENDOR stub) and out-of-window
  // offsets.  Reads of every in-window local command go to the cpuif.
  logic do_cpuif_wr;
  logic do_cpuif_rd;
  always_comb begin
    do_cpuif_wr = local_access & rb_wr & off_ok
                & (rb_cmd != CMD_HW_STATUS)
                & (rb_cmd != CMD_VENDOR);
    do_cpuif_rd = local_access & rb_rd & off_ok;
  end

  // Single-cycle request: gated by ~regblock_busy_q so the held-level access
  // does not re-fire cpuif_req (and therefore swmod) on the ack cycle.
  logic cpuif_fire;
  assign cpuif_fire     = (do_cpuif_wr | do_cpuif_rd) & ~regblock_busy_q;
  assign cpuif_req      = cpuif_fire;
  assign cpuif_req_is_wr= rb_wr;
  assign cpuif_addr     = cmd_base + word_base_byte[11:0];
  assign cpuif_wr_data  = rb_wdata;
  // Expand the per-lane byte strobe into per-bit biten (8 biten bits / lane).
  assign cpuif_wr_biten = {{8{rb_wstrb[3]}}, {8{rb_wstrb[2]}},
                           {8{rb_wstrb[1]}}, {8{rb_wstrb[0]}}};

  // A local access that completes WITHOUT a cpuif transaction: invalid cmd,
  // out-of-window offset, dropped HW_STATUS/VENDOR write.  These still need a
  // (registered) ack/err so the upstream master does not hang.
  logic local_noncpuif_acc;
  logic local_noncpuif_err;
  always_comb begin
    local_noncpuif_acc = 1'b0;
    local_noncpuif_err = 1'b0;
    if (access & ~is_fifo_cmd & ~regblock_busy_q) begin
      if (~is_local_cmd) begin
        local_noncpuif_acc = 1'b1;
        local_noncpuif_err = 1'b1;     // invalid OCP command code
      end else if (~off_ok) begin
        local_noncpuif_acc = 1'b1;
        local_noncpuif_err = 1'b1;     // offset past command window
      end else if (rb_wr & ((rb_cmd == CMD_HW_STATUS) ||
                            (rb_cmd == CMD_VENDOR))) begin
        local_noncpuif_acc = 1'b1;     // dropped write (sideband / stub)
      end
    end
  end

  // HW_STATUS sideband write pulse (low byte of the word).
  logic wr_hw_status;
  assign wr_hw_status = local_access & rb_wr & off_ok &
                        (rb_cmd == CMD_HW_STATUS) & rb_wstrb[0];

  // --------------------------------------------------------------------------
  // Sequential: regblock handshake registers.
  // --------------------------------------------------------------------------
  logic        rb_ack_q;
  logic        rb_err_q;
  logic [31:0] rb_rdata_q;
  logic        hw_status_wr_q;
  logic [7:0]  hw_status_wdata_q;
  logic        proto_err_rd_pulse_q;

  always_ff @(posedge clk) begin
    if (rst) begin
      rb_ack_q             <= 1'b0;
      rb_err_q             <= 1'b0;
      rb_rdata_q           <= '0;
      regblock_busy_q      <= 1'b0;
      hw_status_wr_q       <= 1'b0;
      hw_status_wdata_q    <= 8'h00;
      proto_err_rd_pulse_q <= 1'b0;
    end else begin
      // Defaults: handshake / pulses low.
      rb_ack_q             <= 1'b0;
      rb_err_q             <= 1'b0;
      rb_rdata_q           <= '0;
      hw_status_wr_q       <= 1'b0;
      proto_err_rd_pulse_q <= 1'b0;

      // ----- Regblock CPUIF path (single-cycle req, registered ack) -----
      if (cpuif_fire) begin
        regblock_busy_q <= 1'b1;
        if (do_cpuif_rd) begin
          rb_rdata_q <= cpuif_rd_data;
          rb_err_q   <= cpuif_rd_err;
          // PROTOCOL_ERROR onread=rclr (OCP Recovery v1.1 Sec 9.2 Tbl 9-5):
          // pulse on a successful read of the DEVICE_STATUS word holding
          // PROT_ERROR (byte 1 -> word 0).
          if ((rb_cmd == CMD_DEVICE_STATUS) && (rb_offset == WOFF_DS_WORD0)) begin
            proto_err_rd_pulse_q <= 1'b1;
          end
        end else begin
          rb_err_q <= cpuif_wr_err;
        end
        rb_ack_q <= 1'b1;
      end else if (regblock_busy_q) begin
        // Ack cycle already serviced above; just clear busy.
        regblock_busy_q <= 1'b0;
      end

      // ----- Local non-cpuif completion (invalid / dropped) -----
      if (local_noncpuif_acc) begin
        regblock_busy_q <= 1'b1;
        rb_ack_q        <= 1'b1;
        rb_err_q        <= local_noncpuif_err;
      end

      // ----- HW_STATUS sideband pulse (no cpuif write) -----
      if (wr_hw_status) begin
        hw_status_wr_q    <= 1'b1;
        hw_status_wdata_q <= rb_wdata[7:0];
      end
    end
  end

  // --------------------------------------------------------------------------
  // Outputs.  Regblock / FIFO paths are mutually exclusive by is_fifo_cmd.
  //   - FIFO commands: ack/err/rdata come combinationally from A4 (cms_fifo),
  //     which now owns the word-level handshake and the byte-SRAM sequencing.
  //   - Local (regblock / sideband) commands: the registered handshake above.
  // --------------------------------------------------------------------------
  assign rb_ack             = is_fifo_cmd ? fifo_rb_ack   : rb_ack_q;
  assign rb_err             = is_fifo_cmd ? fifo_rb_err   : rb_err_q;
  assign rb_rdata           = is_fifo_cmd ? fifo_rb_rdata : rb_rdata_q;
  assign hw_status_wr       = hw_status_wr_q;
  assign hw_status_wdata    = hw_status_wdata_q;
  assign proto_err_rd_pulse = proto_err_rd_pulse_q;

  // --------------------------------------------------------------------------
  // Assertions
  // --------------------------------------------------------------------------
`ifndef SYNTHESIS
  // synopsys translate_off
  always_ff @(posedge clk) begin
    if (!rst) begin
      assert (!(rb_wr && rb_rd))
        else $error("usb_ocp_recovery_rb_adapter: rb_wr and rb_rd both asserted");
      if (rb_wr | rb_rd) begin
        assert (!$isunknown({rb_cmd, rb_offset}))
          else $error("usb_ocp_recovery_rb_adapter: X on rb_cmd/rb_offset during access");
      end
    end
  end
  // synopsys translate_on
`endif

endmodule
