// SPDX-License-Identifier: Apache-2.0
// ============================================================================
// usb_ocp_recovery_pkg.svh
//
// Shared constants for the OCP Recovery v1.1 USB-transported register file.
//
// HAND-AUTHORED (this revision).  Intended source: regeneration from
//   third_party/usb2/systemrdl/usb_ocp_recovery.regs
// via the existing peakrdl-style generator path (see tools/scripts/
// gen_soc_regs.sh).  Bringing that generator up for usb_ocp_recovery.regs
// is tracked separately; in the meantime this header is the single source of
// truth for command codes, payload lengths, and within-record byte offsets
// shared between usb_ocp_recovery_regs.sv, usb_ocp_recovery_cms_fifo.sv, and
// usb_ocp_recovery_ctrl_decode.sv.
//
// Every literal here is justified by an explicit OCP Recovery v1.1 Sec 9.2
// table reference.  Do NOT introduce a value here without a citation.
// ============================================================================

// ============================================================================
// Note on include style: this header is deliberately NOT guarded.  It is
// included *inside* the module body of each consumer so its localparams land
// in module-scope.  A `ifndef ... `define ... `endif guard would cause the
// second module's include to no-op (the guard set by the first include
// persists across files in one compilation unit), leaving the second module
// without the localparams.  If you ever need a guarded header, refactor this
// into a SystemVerilog `package usb_ocp_recovery_pkg; ... endpackage` and
// `import usb_ocp_recovery_pkg::*;` in each consumer.
// ============================================================================

// ----------------------------------------------------------------------------
// OCP command codes (OCP Recovery v1.1 Sec 9.2 Tbl 9-1)
// ----------------------------------------------------------------------------
localparam logic [7:0] OCP_CMD_PROT_CAP             = 8'h22;
localparam logic [7:0] OCP_CMD_DEVICE_ID            = 8'h23;
localparam logic [7:0] OCP_CMD_DEVICE_STATUS        = 8'h24;
localparam logic [7:0] OCP_CMD_DEVICE_RESET         = 8'h25;
localparam logic [7:0] OCP_CMD_RECOVERY_CTRL        = 8'h26;
localparam logic [7:0] OCP_CMD_RECOVERY_STATUS      = 8'h27;
localparam logic [7:0] OCP_CMD_HW_STATUS            = 8'h28;
localparam logic [7:0] OCP_CMD_INDIRECT_CTRL        = 8'h29;
localparam logic [7:0] OCP_CMD_INDIRECT_STATUS      = 8'h2A;
localparam logic [7:0] OCP_CMD_INDIRECT_DATA        = 8'h2B;
localparam logic [7:0] OCP_CMD_INDIRECT_FIFO_CTRL   = 8'h2C;
localparam logic [7:0] OCP_CMD_INDIRECT_FIFO_STATUS = 8'h2D;
localparam logic [7:0] OCP_CMD_INDIRECT_FIFO_DATA   = 8'h2E;
localparam logic [7:0] OCP_CMD_VENDOR               = 8'h2F;

localparam logic [7:0] OCP_CMD_MIN                  = 8'h22;
localparam logic [7:0] OCP_CMD_MAX                  = 8'h2F;

// ----------------------------------------------------------------------------
// Per-command payload lengths (bytes).
// PROT_CAP, DEVICE_ID, DEVICE_RESET, RECOVERY_CTRL, RECOVERY_STATUS, HW_STATUS,
// INDIRECT_CTRL, INDIRECT_FIFO_CTRL: OCP Recovery v1.1 Sec 9.2 Tbls 9-3, 9-4,
// 9-7, 9-9, 9-10, 9-11, 9-12, 9-14.  Status records (DEVICE_STATUS,
// INDIRECT_STATUS, INDIRECT_FIFO_STATUS, INDIRECT_DATA window, VENDOR stub)
// have implementation-defined caps:
//   - DEVICE_STATUS  : implementation cap = 64 B (spec max 256 B per Sec 9.2);
//                      vendor payload room = 64 - 7 = 57 B.  Documented here.
//   - INDIRECT_DATA  : 252 B sliding window per OCP record-mode usage.
//   - INDIRECT_FIFO_STATUS : 20 B per Sec 9.2 Tbl 9-15 (5x32b dword status).
//   - VENDOR (stub)  : 1 B accepted/returned-as-zero; spec allows up to
//                      vendor-defined length, intentionally minimised here.
// ----------------------------------------------------------------------------
localparam int OCP_LEN_PROT_CAP            = 16;
localparam int OCP_LEN_DEVICE_ID           = 24;
localparam int OCP_LEN_DEVICE_STATUS       = 64;
localparam int OCP_LEN_DEVICE_RESET        = 3;
localparam int OCP_LEN_RECOVERY_CTRL       = 3;
localparam int OCP_LEN_RECOVERY_STATUS     = 2;
localparam int OCP_LEN_HW_STATUS           = 4;
localparam int OCP_LEN_INDIRECT_CTRL       = 6;
localparam int OCP_LEN_INDIRECT_STATUS     = 8;
localparam int OCP_LEN_INDIRECT_DATA       = 252;
localparam int OCP_LEN_INDIRECT_FIFO_CTRL  = 6;
localparam int OCP_LEN_INDIRECT_FIFO_STATUS= 20;
localparam int OCP_LEN_INDIRECT_FIFO_DATA  = 4;
localparam int OCP_LEN_VENDOR              = 1;  // stub - reduced from spec max

// ----------------------------------------------------------------------------
// Within-record byte offsets used by multiple modules.
// All offsets and units come from OCP Recovery v1.1 Sec 9.2 tables.  Where the
// in-tree authoritative precedent at
//   third_party/i3c-core/src/rdl/secure_firmware_recovery_interface.rdl
// disagrees with our local RDL, the i3c-rdl wins (per plan SecD0.C).
// ----------------------------------------------------------------------------
// DEVICE_STATUS (Sec 9.2 Tbl 9-5)
localparam int OCP_OFF_DS_STATUS         = 0;  // byte 0  : DEVICE_STATUS
localparam int OCP_OFF_DS_PROT_ERROR     = 1;  // byte 1  : PROTOCOL_ERROR
localparam int OCP_OFF_DS_REC_REASON_LO  = 2;  // bytes 2..3 : 16b REC_REASON
localparam int OCP_OFF_DS_REC_REASON_HI  = 3;
localparam int OCP_OFF_DS_HEARTBEAT_LO   = 4;  // bytes 4..5
localparam int OCP_OFF_DS_HEARTBEAT_HI   = 5;
localparam int OCP_OFF_DS_VENDOR_LEN     = 6;  // byte 6  : VENDOR_STATUS_LENGTH
localparam int OCP_OFF_DS_VENDOR_START   = 7;  // bytes 7..N

// HW_STATUS (Sec 9.2 Tbl 9-11)
localparam int OCP_OFF_HW_DEV_STATUS     = 0;
localparam int OCP_OFF_HW_VENDOR_STATUS  = 1;  // 8b bitmap (was byte 3 in b6f3c08; corrected)
localparam int OCP_OFF_HW_CTEMP          = 2;
localparam int OCP_OFF_HW_VENDOR_LEN     = 3;  // (was byte 1 in b6f3c08; corrected)

// RECOVERY_CTRL (Sec 9.2 Tbl 9-9)
localparam int OCP_OFF_RC_CMS            = 0;
localparam int OCP_OFF_RC_IMG_SEL        = 1;
localparam int OCP_OFF_RC_ACTIVATE       = 2;
localparam logic [7:0] OCP_RC_ACTIVATE_CODE = 8'h0F;

// DEVICE_RESET (Sec 9.2 Tbl 9-7)
localparam int OCP_OFF_DR_RESET_CONTROL  = 0;
localparam int OCP_OFF_DR_FORCED_RECOV   = 1;
localparam int OCP_OFF_DR_IFACE_CONTROL  = 2;

// INDIRECT_CTRL (Sec 9.2 Tbl 9-12).  IMAGE_OFFSET is in 4-byte units.
localparam int OCP_OFF_IC_CMS            = 0;
localparam int OCP_OFF_IC_RSVD           = 1;
localparam int OCP_OFF_IC_IMG_OFFSET_B0  = 2;  // bytes 2..5
localparam int OCP_OFF_IC_IMG_OFFSET_B3  = 5;

// INDIRECT_FIFO_CTRL (Sec 9.2 Tbl 9-14).  IMAGE_SIZE is in 4-byte units and
// lives at bytes 2..5 (b6f3c08 had it at 4..7 - corrected).
localparam int OCP_OFF_IFC_CMS           = 0;
localparam int OCP_OFF_IFC_RESET         = 1;
localparam int OCP_OFF_IFC_IMG_SIZE_B0   = 2;
localparam int OCP_OFF_IFC_IMG_SIZE_B3   = 5;

// Both image_offset (0x29) and image_size (0x2C) are spec-encoded in 4-byte
// units.  Internal SRAM addressing in cms_fifo is byte-granular, so the
// register values are left-shifted by IMG_UNIT_LOG2 when consumed.
localparam int OCP_IMG_UNIT_LOG2         = 2;  // 4-byte units

// ----------------------------------------------------------------------------
// USB class request encoding (USB 2.0 Sec 9.3, OCP Recovery v1.1 Sec 8.5.1)
// bmRequestType layout:
//   [7]   direction (0 = host->dev WRITE, 1 = dev->host READ)
//   [6:5] type      (00 std, 01 class, 10 vendor, 11 rsvd)
//   [4:0] recipient (0 device, 1 interface, 2 endpoint, ...)
// bRequest = 0x00 (OCP_RECOVERY_TRANSFER) per Sec 8.5.1.
// wValue[7:0] = OCP command code (0x22..0x2F).
// wIndex[7:0] = interface number.
// ----------------------------------------------------------------------------
localparam logic [1:0] BMRT_TYPE_CLASS        = 2'b01;
localparam logic [4:0] BMRT_RECIPIENT_IFACE   = 5'b00001;
localparam logic [7:0] OCP_BREQUEST_XFER      = 8'h00;
