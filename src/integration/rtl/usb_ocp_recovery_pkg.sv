// SPDX-License-Identifier: Apache-2.0
// ============================================================================
// usb_ocp_recovery_pkg.sv
//
// Shared constants for the OCP Recovery v1.1 USB-transported register file:
// OCP command codes, per-command payload lengths, within-record byte offsets,
// and the USB class-request encoding.  This package is the SINGLE SOURCE OF
// TRUTH for these values; consumers `import usb_ocp_recovery_pkg::*` rather
// than redefining or hard-coding them.  Every literal is justified by an
// explicit OCP Recovery v1.1 Sec 9.2 reference; do NOT introduce a value here
// without a citation.
// ============================================================================

package usb_ocp_recovery_pkg;

// ----------------------------------------------------------------------------
// OCP command codes (OCP Recovery v1.1 Sec 9.2)
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
localparam logic [7:0] OCP_CMD_VENDOR               = 8'h2C;
localparam logic [7:0] OCP_CMD_INDIRECT_FIFO_CTRL   = 8'h2D;
localparam logic [7:0] OCP_CMD_INDIRECT_FIFO_STATUS = 8'h2E;
localparam logic [7:0] OCP_CMD_INDIRECT_FIFO_DATA   = 8'h2F;

localparam logic [7:0] OCP_CMD_MIN                  = 8'h22;
localparam logic [7:0] OCP_CMD_MAX                  = 8'h2F;

// Caliptra-specific (non-OCP) register command tags.  These carry no OCP
// wValue and are produced ONLY by the firmware/AXI (EXT) sub-decoder in
// ip_xxx_3516_hs_mem_wrapper.sv for the design-specific register region above
// the OCP command aperture.  They lie outside OCP_CMD_MIN..OCP_CMD_MAX, so the
// USB host command decode (usb_ocp_recovery_ctrl_decode.sv, which only accepts
// OCP_CMD_MIN..OCP_CMD_MAX) can never emit them: the Caliptra-specific
// registers are firmware-reachable only.
localparam logic [7:0] OCP_CMD_CALIPTRA_CTRL        = 8'hE0;
localparam logic [7:0] OCP_CMD_CALIPTRA_STATUS      = 8'hE1;

// ----------------------------------------------------------------------------
// Per-command payload lengths (bytes), per OCP Recovery v1.1 Sec 9.2 Command
// Summary.  These bound the regblock command window in the rb_adapter (the
// single source of truth for command lengths on the local register path).
//
// Fixed-length commands match the spec byte count exactly: DEVICE_RESET=3,
// RECOVERY_CTRL=3, RECOVERY_STATUS=2, INDIRECT_CTRL=6, INDIRECT_STATUS=6,
// INDIRECT_FIFO_CTRL=6, INDIRECT_FIFO_STATUS=20.
//
// PROT_CAP carries 15 meaningful bytes (Sec 9.2: byte 0-14).  The register
// window here is 16 B: the regblock is DWORD-granular (4x32b), so byte 15 is a
// reserved-zero pad (Sec 9.2 reserves the upper capability bits).  A compliant
// Recovery Agent reads <=15 bytes, so the reserved pad is never consumed.
//
// Minimum-length commands advertise their spec minimum (the device MAY return
// more): DEVICE_ID min 24 (spec 24-255), HW_STATUS min 4 (spec 4-255),
// DEVICE_STATUS min 7 (spec 7-255) - implemented as a fixed 64 B window
// (vendor-status room 64-7 = 57 B).
//
// Variable-length ("1-N") commands carry a representative/stub window length:
//   - INDIRECT_DATA : 252 B record-mode window (direct CMS path; unimplemented).
//   - INDIRECT_FIFO_DATA : 4 B = one DWORD streaming unit (the FIFO datapath
//                          streams N DWORDs; this is the unit, not a cap).
//   - VENDOR (stub) : 1 B accepted/returned-as-zero; spec allows a
//                     vendor-defined length, intentionally minimised here.
//
// INDIRECT_CTRL/STATUS/DATA describe the direct CMS-memory window, which this
// FIFO-only transport does NOT implement (PROT_CAP advertises FIFO CMS only);
// their constants are retained for spec reference and command-range bounds.
// ----------------------------------------------------------------------------
localparam int OCP_LEN_PROT_CAP            = 16;
localparam int OCP_LEN_DEVICE_ID           = 24;
localparam int OCP_LEN_DEVICE_STATUS       = 64;
localparam int OCP_LEN_DEVICE_RESET        = 3;
localparam int OCP_LEN_RECOVERY_CTRL       = 3;
localparam int OCP_LEN_RECOVERY_STATUS     = 2;
localparam int OCP_LEN_HW_STATUS           = 4;
localparam int OCP_LEN_INDIRECT_CTRL       = 6;
localparam int OCP_LEN_INDIRECT_STATUS     = 6;
localparam int OCP_LEN_INDIRECT_DATA       = 252;
localparam int OCP_LEN_INDIRECT_FIFO_CTRL  = 6;
localparam int OCP_LEN_INDIRECT_FIFO_STATUS= 20;
localparam int OCP_LEN_INDIRECT_FIFO_DATA  = 4;
localparam int OCP_LEN_VENDOR              = 1;  // stub - reduced from spec max

// Caliptra-specific (non-OCP) register payload lengths (bytes).
localparam int OCP_LEN_CALIPTRA_CTRL       = 4;
localparam int OCP_LEN_CALIPTRA_STATUS     = 4;

// ----------------------------------------------------------------------------
// Within-record byte offsets used by multiple modules.
// All offsets and units come from OCP Recovery v1.1 Sec 9.2 tables.  Where the
// in-tree authoritative precedent at
//   third_party/i3c-core/src/rdl/secure_firmware_recovery_interface.rdl
// disagrees with our local RDL, the i3c-rdl wins (per plan SecD0.C).
// ----------------------------------------------------------------------------
// DEVICE_STATUS (Sec 9.2)
localparam int OCP_OFF_DS_STATUS         = 0;  // byte 0  : DEVICE_STATUS
localparam int OCP_OFF_DS_PROT_ERROR     = 1;  // byte 1  : PROTOCOL_ERROR
localparam int OCP_OFF_DS_REC_REASON_LO  = 2;  // bytes 2..3 : 16b REC_REASON
localparam int OCP_OFF_DS_REC_REASON_HI  = 3;
localparam int OCP_OFF_DS_HEARTBEAT_LO   = 4;  // bytes 4..5
localparam int OCP_OFF_DS_HEARTBEAT_HI   = 5;
localparam int OCP_OFF_DS_VENDOR_LEN     = 6;  // byte 6  : VENDOR_STATUS_LENGTH
localparam int OCP_OFF_DS_VENDOR_START   = 7;  // bytes 7..N

// HW_STATUS (Sec 9.2)
localparam int OCP_OFF_HW_DEV_STATUS     = 0;
localparam int OCP_OFF_HW_VENDOR_STATUS  = 1;  // 8b vendor bitmap
localparam int OCP_OFF_HW_CTEMP          = 2;
localparam int OCP_OFF_HW_VENDOR_LEN     = 3;

// RECOVERY_CTRL (Sec 9.2)
localparam int OCP_OFF_RC_CMS            = 0;
localparam int OCP_OFF_RC_IMG_SEL        = 1;
localparam int OCP_OFF_RC_ACTIVATE       = 2;
localparam logic [7:0] OCP_RC_ACTIVATE_CODE = 8'h0F;

// DEVICE_RESET (Sec 9.2)
localparam int OCP_OFF_DR_RESET_CONTROL  = 0;
localparam int OCP_OFF_DR_FORCED_RECOV   = 1;
localparam int OCP_OFF_DR_IFACE_CONTROL  = 2;

// INDIRECT_CTRL (Sec 9.2).  IMAGE_OFFSET is in 4-byte units.
localparam int OCP_OFF_IC_CMS            = 0;
localparam int OCP_OFF_IC_RSVD           = 1;
localparam int OCP_OFF_IC_IMG_OFFSET_B0  = 2;  // bytes 2..5
localparam int OCP_OFF_IC_IMG_OFFSET_B3  = 5;

// INDIRECT_FIFO_CTRL (OCP Recovery v1.1 Sec 9.2).  IMAGE_SIZE is in 4-byte
// units and occupies command bytes 2..5.
localparam int OCP_OFF_IFC_CMS           = 0;
localparam int OCP_OFF_IFC_RESET         = 1;
localparam int OCP_OFF_IFC_IMG_SIZE_B0   = 2;
localparam int OCP_OFF_IFC_IMG_SIZE_B3   = 5;

// Both image_offset (INDIRECT_CTRL) and image_size (INDIRECT_FIFO_CTRL) are
// spec-encoded in 4-byte units.  Internal SRAM addressing in cms_fifo is
// byte-granular, so the register values are left-shifted by IMG_UNIT_LOG2
// when consumed.
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

endpackage
