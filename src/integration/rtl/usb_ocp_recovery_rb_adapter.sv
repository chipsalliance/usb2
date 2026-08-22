// SPDX-License-Identifier: Apache-2.0
// ============================================================================
// usb_ocp_recovery_rb_adapter.sv
//
// Word-granular OCP Recovery v1.1 reg-bus adapter. Bridges the USB command
// path and raw EXT aperture offsets to the DWORD-aligned passthrough CPU
// interface emitted by the peakrdl-generated
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
// All EXT accesses route through the generated cpuif. This includes
// INDIRECT_FIFO_CTRL / INDIRECT_FIFO_STATUS / INDIRECT_FIFO_DATA, HW_STATUS, and
// VENDOR. The regblock mediates address decode, byte-lane qualification, and
// software-access event generation, while the top-level wrapper consumes the
// resulting hwif outputs to update usb_ocp_recovery_cms_fifo or the recovery FSM.
// The direct CMS-memory window (INDIRECT_CTRL/STATUS/DATA) is not implemented:
// it is advertised unsupported in PROT_CAP and dropped/ACKed as an invalid
// command.
//
// Latency:
//   - Regblock cmd ack: 1 cycle after rb_wr/rb_rd (registered), single-cycle
//     cpuif_req pulse so swmod fires exactly once per word.
//   - All implemented EXT commands ack through the regblock cpuif path.
//
// Reset: synchronous, active-high (SV integration convention).
// ============================================================================

module usb_ocp_recovery_rb_adapter (
  input  logic        clk,
  input  logic        rst,

  // --------------------------------------------------------------------------
  // Word-wide USB command path.
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
  // Source qualifier from the top-level arbiter: '1' when the current rb_*
  // access belongs to the EXT (SoC AHB/firmware) master, '0' when it belongs
  // to the USB host.  Derived request-side (same-cycle mux select), NOT from
  // the registered owner_q, so it is valid the same cycle as rb_wr/rb_rd (OCP
  // Recovery v1.1 Sec 9.1 write-to-RO / capability source-qualification).
  // --------------------------------------------------------------------------
  input  logic        rb_is_ext,
  input  logic [10:0] ext_aperture_offset,

  // --------------------------------------------------------------------------
  // peakrdl-regblock passthrough CPU interface (0-cycle balanced ack).
  // --------------------------------------------------------------------------
  output logic        cpuif_req,
  output logic        cpuif_req_is_wr,
  output logic [11:0] cpuif_addr,
  output logic [31:0] cpuif_wr_data,
  output logic [31:0] cpuif_wr_biten,
  input  logic        cpuif_req_block,
  input  logic        cpuif_rd_ack,
  input  logic        cpuif_rd_err,
  input  logic [31:0] cpuif_rd_data,
  input  logic        cpuif_wr_ack,
  input  logic        cpuif_wr_err,

  // Unsupported-command detect pulse to A5 FSM (OCP Recovery v1.1 Sec 9.1:
  // unsupported command MUST set DEVICE_STATUS.PROTOCOL_ERROR).  High for one
  // cycle in the (registered) ack window of an access to an unsupported OCP
  // command code (any code not in the local or FIFO command set, e.g. the
  // direct CMS-memory window (INDIRECT_CTRL/STATUS/DATA) that this FIFO-only transport does
  // not implement).
  output logic        unsupported_cmd_pulse
);

  // --------------------------------------------------------------------------
  // OCP command code -> byte-offset base in the regblock window.
  // Source of truth: third_party/usb2/systemrdl/usb_ocp_recovery_reg.rdl
  //   PROT_CAP_0       @ 0x000  (16 B)
  //   DEVICE_ID_0      @ 0x010  (24 B)
  //   DEVICE_STATUS_0  @ 0x028  (64 B)
  //   DEVICE_RESET     @ 0x068  ( 3 B, CPUIF/swmod)
  //   RECOVERY_CTRL    @ 0x06C  ( 3 B, CPUIF/swmod)
  //   RECOVERY_STATUS  @ 0x070  ( 2 B)
  //   HW_STATUS        @ 0x074  ( 4 B)
  //   INDIRECT_FIFO_*  @ 0x184+ (cpuif mediated, cms_fifo owned)
  //   VENDOR           @ 0x1A4  ( 1 B stub)
  //   Direct CMS-memory window INDIRECT_CTRL/STATUS/DATA is
  //   not implemented: an access to any unsupported command code raises
  //   unsupported_cmd_pulse -> PROTOCOL_ERROR=0x01 in the FSM and acks
  //   (OCP Recovery v1.1 Sec 9.1).
  //
  // Command-code constants are sourced from the shared package so the wire
  // wValue decode has a single definition (OCP Recovery v1.1 Sec 9.2).
  // --------------------------------------------------------------------------
  import usb_ocp_recovery_pkg::*;

  // --------------------------------------------------------------------------
  // Local command base address + payload length (bytes)
  // --------------------------------------------------------------------------
  logic        is_local_cmd;
  logic [11:0] cmd_base;
  logic [15:0] cmd_len;
  always_comb begin
    is_local_cmd = rb_is_ext;
    cmd_base     = OCP_ADDR_PROT_CAP;
    cmd_len      = 16'd0;
    if (!rb_is_ext) begin
    is_local_cmd = 1'b1;
    unique case (rb_cmd)
      OCP_CMD_PROT_CAP:        begin cmd_base = OCP_ADDR_PROT_CAP;             cmd_len = 16'(OCP_LEN_PROT_CAP);        end
      OCP_CMD_DEVICE_ID:       begin cmd_base = OCP_ADDR_DEVICE_ID;            cmd_len = 16'(OCP_LEN_DEVICE_ID);       end
      OCP_CMD_DEVICE_STATUS:   begin cmd_base = OCP_ADDR_DEVICE_STATUS;        cmd_len = 16'(OCP_LEN_DEVICE_STATUS);   end
      OCP_CMD_DEVICE_RESET:    begin cmd_base = OCP_ADDR_DEVICE_RESET;         cmd_len = 16'(OCP_LEN_DEVICE_RESET);    end
      OCP_CMD_RECOVERY_CTRL:   begin cmd_base = OCP_ADDR_RECOVERY_CTRL;        cmd_len = 16'(OCP_LEN_RECOVERY_CTRL);   end
      OCP_CMD_RECOVERY_STATUS: begin cmd_base = OCP_ADDR_RECOVERY_STATUS;      cmd_len = 16'(OCP_LEN_RECOVERY_STATUS); end
      OCP_CMD_HW_STATUS:       begin cmd_base = OCP_ADDR_HW_STATUS;            cmd_len = 16'(OCP_LEN_HW_STATUS);       end
      OCP_CMD_VENDOR:          begin cmd_base = OCP_ADDR_VENDOR;               cmd_len = 16'(OCP_LEN_VENDOR);          end
      OCP_CMD_INDIRECT_FIFO_CTRL: begin cmd_base = OCP_ADDR_INDIRECT_FIFO_CTRL;   cmd_len = 16'(OCP_LEN_INDIRECT_FIFO_CTRL); end
      OCP_CMD_INDIRECT_FIFO_STATUS: begin cmd_base = OCP_ADDR_INDIRECT_FIFO_STATUS; cmd_len = 16'(OCP_LEN_INDIRECT_FIFO_STATUS); end
      OCP_CMD_INDIRECT_FIFO_DATA: begin cmd_base = OCP_ADDR_INDIRECT_FIFO_DATA;   cmd_len = 16'(OCP_LEN_INDIRECT_FIFO_DATA); end
      // Caliptra-specific (non-OCP) registers, firmware/EXT-reachable only (see
      // rb_is_ext guard below).  They live above the OCP command aperture.
      OCP_CMD_CALIPTRA_CTRL:   begin cmd_base = OCP_ADDR_CALIPTRA_CTRL;   cmd_len = 16'(OCP_LEN_CALIPTRA_CTRL);   end
      OCP_CMD_CALIPTRA_STATUS: begin cmd_base = OCP_ADDR_CALIPTRA_STATUS; cmd_len = 16'(OCP_LEN_CALIPTRA_STATUS); end
      default:             is_local_cmd = 1'b0;
    endcase
    end
    // Defense-in-depth: the Caliptra-specific registers are addressed only by
    // the firmware/AXI (EXT) sub-decoder; the USB ctrl_decode can never emit
    // these command tags (they are outside OCP_CMD_MIN..MAX), but drop the
    // local-command routing for a non-EXT access so a stray USB access can
    // never reach them.
    if (((rb_cmd == OCP_CMD_CALIPTRA_CTRL) ||
         (rb_cmd == OCP_CMD_CALIPTRA_STATUS)) && !rb_is_ext) begin
      is_local_cmd = 1'b0;
    end
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
  assign off_ok         = rb_is_ext || (word_base_byte < {2'b00, cmd_len[11:0]});
  assign local_access   = access & is_local_cmd;

  // --------------------------------------------------------------------------
  // Host-RO command detect (OCP Recovery v1.1 Sec 9.2 r/w=ro column): PROT_CAP,
  // DEVICE_ID, DEVICE_STATUS, RECOVERY_STATUS, HW_STATUS.  A USB-host write to
  // any of these MUST raise DEVICE_STATUS.PROTOCOL_ERROR=0x01 (Sec 9.1,
  // "Writing to a read only command ... MUST generate an 'unsupported command'
  // error").  INDIRECT_FIFO_STATUS is also host-RO.
  // VENDOR is host-RW per spec and is excluded.
  // --------------------------------------------------------------------------
  logic is_host_ro_cmd;
  always_comb begin
    unique case (rb_cmd)
      OCP_CMD_PROT_CAP,
      OCP_CMD_DEVICE_ID,
      OCP_CMD_DEVICE_STATUS,
      OCP_CMD_RECOVERY_STATUS,
      OCP_CMD_HW_STATUS,
      OCP_CMD_INDIRECT_FIFO_STATUS: is_host_ro_cmd = 1'b1;
      default:           is_host_ro_cmd = 1'b0;
    endcase
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

  // A regblock cpuif access is issued for every implemented local command except
  // out-of-window offsets and USB-host writes to PROT_CAP (capability sub-fields are
  // sw=rw so EXT/firmware can configure them, but the USB host must not be
  // able to write them -- see is_host_ro_cmd / host_ro_write_violation
  // below).  Reads of every in-window local command go to the cpuif.
  logic do_cpuif_wr;
  logic do_cpuif_rd;
  always_comb begin
    do_cpuif_wr = local_access & rb_wr & off_ok
                & ~((rb_cmd == OCP_CMD_PROT_CAP) & ~rb_is_ext);
    do_cpuif_rd = local_access & rb_rd & off_ok;
  end

  // Single-cycle request: gated by ~regblock_busy_q so the held-level access
  // does not re-fire cpuif_req (and therefore swmod) on the ack cycle.
  logic cpuif_fire;
  logic local_read_fire;
  assign cpuif_fire     = (do_cpuif_wr | do_cpuif_rd) & ~regblock_busy_q & ~cpuif_req_block;
  assign local_read_fire = do_cpuif_rd & ~regblock_busy_q & ~cpuif_req_block;
  assign cpuif_req      = cpuif_fire;
  assign cpuif_req_is_wr= rb_wr;
  assign cpuif_addr     = rb_is_ext ? {1'b0, ext_aperture_offset}
                                    : cmd_base + word_base_byte[11:0];
  assign cpuif_wr_data  = rb_wdata;
  // Expand the per-lane byte strobe into per-bit biten (8 biten bits / lane).
  assign cpuif_wr_biten = {{8{rb_wstrb[3]}}, {8{rb_wstrb[2]}},
                           {8{rb_wstrb[1]}}, {8{rb_wstrb[0]}}};

  // A local access that completes WITHOUT a cpuif transaction: invalid cmd,
  // out-of-window offset, or a USB-host write to PROT_CAP (excluded from
  // do_cpuif_wr above).  These still need a
  // (registered) ack/err so the upstream master does not hang.
  logic local_noncpuif_acc;
  logic local_noncpuif_err;
  always_comb begin
    local_noncpuif_acc = 1'b0;
    local_noncpuif_err = 1'b0;
    if (access & ~regblock_busy_q) begin
      if (~is_local_cmd) begin
        // Unsupported OCP command code (e.g. the removed direct CMS-memory
        // window INDIRECT_CTRL/STATUS/DATA).
        // Complete the access cleanly (ack, NO err) rather than signalling a
        // reg-bus error: a reg-bus error makes ctrl_decode STALL the USB
        // control transfer, and the recovery arbiter's claim FSM does not
        // cleanly retire a STALLed claimed transfer (it can wedge the
        // recovery endpoint until the next SETUP).  The
        // unsupported condition is instead reported per OCP Recovery v1.1
        // Sec 9.1 by raising unsupported_cmd_pulse ->
        // DEVICE_STATUS.PROTOCOL_ERROR = 0x01 (see unsupported_access below);
        // the read returns 0 data / the write is dropped.
        local_noncpuif_acc = 1'b1;
        local_noncpuif_err = 1'b0;
      end else if (~off_ok) begin
        local_noncpuif_acc = 1'b1;
        local_noncpuif_err = 1'b1;     // offset past command window
      end else if (rb_wr & (rb_cmd == OCP_CMD_PROT_CAP) & ~rb_is_ext) begin
        // USB-host write to PROT_CAP: excluded from do_cpuif_wr above so the
        // now-sw=rw capability sub-fields cannot be corrupted by the host
        // (OCP Recovery v1.1 Sec 9.2, PROT_CAP is host-RO).  Ack cleanly, no
        // reg-bus error (same STALL-avoidance rationale as above); the
        // PROTOCOL_ERROR report is raised via host_ro_write_violation below.
        local_noncpuif_acc = 1'b1;
      end
    end
  end

  // --------------------------------------------------------------------------
  // Host-RO write violation (OCP Recovery v1.1 Sec 9.1): a USB-host write to
  // any host-RO local command (PROT_CAP, DEVICE_ID, DEVICE_STATUS,
  // RECOVERY_STATUS, HW_STATUS) MUST raise DEVICE_STATUS.PROTOCOL_ERROR=0x01.
  // Gated by ~regblock_busy_q so it qualifies exactly one request cycle,
  // matching unsupported_access below.  Only DEVICE_ID/DEVICE_STATUS/
  // RECOVERY_STATUS/HW_STATUS writes still pass through to the cpuif (they
  // have no sw=rw field so the write is a harmless no-op at the regblock);
  // PROT_CAP writes are additionally blocked from the cpuif above.
  // --------------------------------------------------------------------------
  logic host_ro_write_violation;
  assign host_ro_write_violation = local_access & rb_wr & off_ok & ~rb_is_ext
                                  & is_host_ro_cmd & ~regblock_busy_q;

  // Unsupported-command detect: an access (read or write) to a command code
  // that is neither a local nor a FIFO command (e.g. the removed direct
  // CMS-memory window INDIRECT_CTRL/STATUS/DATA, or any unknown code).  Gated
  // by ~regblock_busy_q so
  // it qualifies exactly one request cycle, aligning the registered pulse
  // below with the rb_ack window.  Fires for EITHER master so the bus never
  // hangs; the PROTOCOL_ERROR report itself is additionally source-qualified
  // where it is registered below (an EXT/firmware access to an
  // unsupported command is an internal firmware issue, not a USB protocol
  // violation, so it must not surface to the USB host). OCP Recovery v1.1
  // Sec 9.1.
  logic unsupported_access;
  assign unsupported_access = access & ~is_local_cmd & ~regblock_busy_q;

  // --------------------------------------------------------------------------
  // Sequential: regblock handshake registers.
  // --------------------------------------------------------------------------
  logic        rb_ack_q;
  logic        rb_err_q;
  logic [31:0] rb_rdata_q;
  logic        unsupported_cmd_pulse_q;

  always_ff @(posedge clk) begin
    if (rst) begin
      rb_ack_q             <= 1'b0;
      rb_err_q             <= 1'b0;
      rb_rdata_q           <= '0;
      regblock_busy_q      <= 1'b0;
      unsupported_cmd_pulse_q <= 1'b0;
    end else begin
      // Defaults: handshake / pulses low.
      rb_ack_q             <= 1'b0;
      rb_err_q             <= 1'b0;
      rb_rdata_q           <= '0;
      // PROTOCOL_ERROR report (Sec 9.1) is source-qualified: an EXT/firmware
      // access to an unsupported command is dropped without raising the
      // USB-host-visible protocol error; host_ro_write_violation is
      // already USB-only by construction.
      unsupported_cmd_pulse_q <= (unsupported_access & ~rb_is_ext)
                                | host_ro_write_violation;

      // ----- Regblock CPUIF path (single-cycle req, registered ack) -----
      if (cpuif_fire) begin
        regblock_busy_q <= 1'b1;
        if (do_cpuif_rd) begin
          rb_rdata_q <= cpuif_rd_data;
          rb_err_q   <= cpuif_rd_err;
        end else begin
          rb_ack_q <= 1'b1;
          rb_err_q <= cpuif_wr_err;
        end
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
    end
  end

  // --------------------------------------------------------------------------
  // Outputs.
  //   - Local writes and non-cpuif completions: the registered handshake above.
  //   - Local reads: cpuif_rd_data/ack are combinational in the one-shot
  //     request cycle, so return them immediately. This removes the otherwise
  //     unnecessary rb_ack_q cycle while regblock_busy_q still prevents a
  //     held rb_rd level from issuing more than one cpuif request.
  // --------------------------------------------------------------------------
  assign rb_ack             = local_read_fire ? cpuif_rd_ack
                            : rb_ack_q;
  assign rb_err             = local_read_fire ? cpuif_rd_err
                            : rb_err_q;
  assign rb_rdata           = local_read_fire ? cpuif_rd_data
                            : rb_rdata_q;
  assign unsupported_cmd_pulse = unsupported_cmd_pulse_q;

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
      if (local_read_fire) begin
        assert (cpuif_req && cpuif_rd_ack)
          else $error("usb_ocp_recovery_rb_adapter: local read did not receive a same-cycle cpuif ack");
      end
    end
  end
  // synopsys translate_on
`endif

endmodule
