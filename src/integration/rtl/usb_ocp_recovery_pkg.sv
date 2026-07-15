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

typedef logic [7:0] ocp_cmd_t;

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
localparam int OCP_LEN_UNSUPPORTED_READ_STUB = OCP_LEN_INDIRECT_FIFO_DATA;
localparam int OCP_MAX_IMPLEMENTED_RESPONSE_BYTES = OCP_LEN_DEVICE_STATUS;

typedef struct packed {
  logic       known;
  logic [6:0] bytes;
} ocp_response_meta_t;

function automatic logic ocp_response_bytes_known(input logic [7:0] cmd);
  logic known;
  begin
    known = 1'b1;
    unique case (cmd)
      OCP_CMD_PROT_CAP,
      OCP_CMD_DEVICE_ID,
      OCP_CMD_DEVICE_STATUS,
      OCP_CMD_DEVICE_RESET,
      OCP_CMD_RECOVERY_CTRL,
      OCP_CMD_RECOVERY_STATUS,
      OCP_CMD_HW_STATUS,
      OCP_CMD_INDIRECT_CTRL,
      OCP_CMD_INDIRECT_STATUS,
      OCP_CMD_INDIRECT_DATA,
      OCP_CMD_VENDOR,
      OCP_CMD_INDIRECT_FIFO_CTRL,
      OCP_CMD_INDIRECT_FIFO_STATUS,
      OCP_CMD_INDIRECT_FIFO_DATA: known = 1'b1;
      default:                   known = 1'b0;
    endcase
    return known;
  end
endfunction

function automatic logic [6:0] ocp_response_bytes(input logic [7:0] cmd);
  logic [6:0] bytes;
  begin
    bytes = '0;
    unique case (cmd)
      OCP_CMD_PROT_CAP:             bytes = 7'(OCP_LEN_PROT_CAP);
      OCP_CMD_DEVICE_ID:            bytes = 7'(OCP_LEN_DEVICE_ID);
      OCP_CMD_DEVICE_STATUS:        bytes = 7'(OCP_LEN_DEVICE_STATUS);
      OCP_CMD_DEVICE_RESET:         bytes = 7'(OCP_LEN_DEVICE_RESET);
      OCP_CMD_RECOVERY_CTRL:        bytes = 7'(OCP_LEN_RECOVERY_CTRL);
      OCP_CMD_RECOVERY_STATUS:      bytes = 7'(OCP_LEN_RECOVERY_STATUS);
      OCP_CMD_HW_STATUS:            bytes = 7'(OCP_LEN_HW_STATUS);
      OCP_CMD_INDIRECT_CTRL:        bytes = 7'(OCP_LEN_UNSUPPORTED_READ_STUB);
      OCP_CMD_INDIRECT_STATUS:      bytes = 7'(OCP_LEN_UNSUPPORTED_READ_STUB);
      OCP_CMD_INDIRECT_DATA:        bytes = 7'(OCP_LEN_UNSUPPORTED_READ_STUB);
      OCP_CMD_VENDOR:               bytes = 7'(OCP_LEN_VENDOR);
      OCP_CMD_INDIRECT_FIFO_CTRL:   bytes = 7'(OCP_LEN_INDIRECT_FIFO_CTRL);
      OCP_CMD_INDIRECT_FIFO_STATUS: bytes = 7'(OCP_LEN_INDIRECT_FIFO_STATUS);
      OCP_CMD_INDIRECT_FIFO_DATA:   bytes = 7'(OCP_LEN_INDIRECT_FIFO_DATA);
      default:                      bytes = '0;
    endcase
    return bytes;
  end
endfunction

function automatic ocp_response_meta_t ocp_response_meta(input logic [7:0] cmd);
  ocp_response_meta_t meta;
  begin
    meta.known = ocp_response_bytes_known(cmd);
    meta.bytes = ocp_response_bytes(cmd);
    return meta;
  end
endfunction

// ----------------------------------------------------------------------------
// Specification payload bounds. These constants describe the Recovery Agent
// command contract and are intentionally separate from the OCP_LEN_* register
// window sizes above, which may include implementation padding or stub sizes.
// OCP Recovery v1.1 Sec 9.2.
// ----------------------------------------------------------------------------
localparam int OCP_SPEC_LEN_PROT_CAP             = 15;
localparam int OCP_SPEC_MIN_LEN_DEVICE_ID        = 24;
localparam int OCP_SPEC_MAX_LEN_DEVICE_ID        = 255;
localparam int OCP_SPEC_MIN_LEN_DEVICE_STATUS    = 7;
localparam int OCP_SPEC_MAX_LEN_DEVICE_STATUS    = 255;
localparam int OCP_SPEC_LEN_DEVICE_RESET         = 3;
localparam int OCP_SPEC_LEN_RECOVERY_CTRL        = 3;
localparam int OCP_SPEC_LEN_RECOVERY_STATUS      = 2;
localparam int OCP_SPEC_MIN_LEN_HW_STATUS        = 4;
localparam int OCP_SPEC_MAX_LEN_HW_STATUS        = 255;
localparam int OCP_SPEC_LEN_INDIRECT_CTRL        = 6;
localparam int OCP_SPEC_LEN_INDIRECT_STATUS      = 6;
localparam int OCP_SPEC_MIN_LEN_INDIRECT_DATA    = 1;
localparam int OCP_SPEC_MIN_LEN_VENDOR           = 1;
localparam int OCP_SPEC_LEN_INDIRECT_FIFO_CTRL   = 6;
localparam int OCP_SPEC_LEN_INDIRECT_FIFO_STATUS = 20;
localparam int OCP_SPEC_MIN_LEN_INDIRECT_FIFO_DATA = 1;

// ----------------------------------------------------------------------------
// PROT_CAP fields and capability bits (OCP Recovery v1.1 Sec 9.2).
// ----------------------------------------------------------------------------
localparam int OCP_OFF_PC_MAGIC_START       = 0;
localparam int OCP_OFF_PC_MAGIC_END         = 7;
localparam int OCP_OFF_PC_VERSION_MAJOR     = 8;
localparam int OCP_OFF_PC_VERSION_MINOR     = 9;
localparam int OCP_OFF_PC_AGENT_CAPS_LO     = 10;
localparam int OCP_OFF_PC_AGENT_CAPS_HI     = 11;
localparam int OCP_OFF_PC_CMS_COUNT         = 12;
localparam int OCP_OFF_PC_MAX_RESPONSE_TIME = 13;
localparam int OCP_OFF_PC_HEARTBEAT_PERIOD  = 14;

localparam logic [7:0] OCP_SPEC_PROT_CAP_MAGIC [0:7] = '{
  8'h4F, 8'h43, 8'h50, 8'h20, 8'h52, 8'h45, 8'h43, 8'h56
};
localparam logic [7:0] OCP_SPEC_VERSION_MAJOR = 8'h01;
localparam logic [7:0] OCP_SPEC_VERSION_MINOR = 8'h01;

localparam int OCP_CAP_IDENTIFICATION       = 0;
localparam int OCP_CAP_FORCED_RECOVERY      = 1;
localparam int OCP_CAP_MGMT_RESET           = 2;
localparam int OCP_CAP_DEVICE_RESET         = 3;
localparam int OCP_CAP_DEVICE_STATUS        = 4;
localparam int OCP_CAP_INDIRECT_CTRL        = 5;
localparam int OCP_CAP_LOCAL_C_IMAGE        = 6;
localparam int OCP_CAP_PUSH_C_IMAGE         = 7;
localparam int OCP_CAP_INTERFACE_ISOLATION  = 8;
localparam int OCP_CAP_HW_STATUS            = 9;
localparam int OCP_CAP_VENDOR               = 10;
localparam int OCP_CAP_FLASHLESS_BOOT       = 11;
localparam int OCP_CAP_INDIRECT_FIFO        = 12;
localparam logic [15:0] OCP_CAP_RESERVED_MASK = 16'hE000;

// ----------------------------------------------------------------------------
// DEVICE_ID fields and descriptor types (OCP Recovery v1.1 Sec 9.2).
// ----------------------------------------------------------------------------
localparam int OCP_OFF_DID_DESC_TYPE         = 0;
localparam int OCP_OFF_DID_VENDOR_STRING_LEN = 1;
localparam int OCP_OFF_DID_ID_START          = 2;
localparam int OCP_OFF_DID_VENDOR_STRING     = 24;

typedef enum logic [7:0] {
  OCP_DEVICE_ID_PCI_VENDOR       = 8'h00,
  OCP_DEVICE_ID_IANA             = 8'h01,
  OCP_DEVICE_ID_UUID             = 8'h02,
  OCP_DEVICE_ID_PNP_VENDOR       = 8'h03,
  OCP_DEVICE_ID_ACPI_VENDOR      = 8'h04,
  OCP_DEVICE_ID_IANA_ENTERPRISE  = 8'h05,
  OCP_DEVICE_ID_NVME_MI          = 8'hFF
} ocp_device_id_type_e;

// ----------------------------------------------------------------------------
// DEVICE_STATUS values and protocol errors (OCP Recovery v1.1 Sec 9.2).
// ----------------------------------------------------------------------------
typedef enum logic [7:0] {
  OCP_DEVICE_STATUS_PENDING          = 8'h00,
  OCP_DEVICE_STATUS_HEALTHY          = 8'h01,
  OCP_DEVICE_STATUS_ERROR            = 8'h02,
  OCP_DEVICE_STATUS_RECOVERY_MODE    = 8'h03,
  OCP_DEVICE_STATUS_RECOVERY_PENDING = 8'h04,
  OCP_DEVICE_STATUS_RUNNING_RECOVERY = 8'h05,
  OCP_DEVICE_STATUS_BOOT_FAILURE     = 8'h0E,
  OCP_DEVICE_STATUS_FATAL_ERROR      = 8'h0F
} ocp_device_status_e;

typedef enum logic [7:0] {
  OCP_PROTOCOL_ERROR_NONE                  = 8'h00,
  OCP_PROTOCOL_ERROR_UNSUPPORTED_COMMAND   = 8'h01,
  OCP_PROTOCOL_ERROR_UNSUPPORTED_PARAMETER = 8'h02,
  OCP_PROTOCOL_ERROR_LENGTH                = 8'h03,
  OCP_PROTOCOL_ERROR_CRC                   = 8'h04,
  OCP_PROTOCOL_ERROR_GENERAL               = 8'hFF
} ocp_protocol_error_e;

localparam int OCP_DEVICE_STATUS_HEARTBEAT_MAX = 4095;
localparam int OCP_DEVICE_STATUS_VENDOR_LEN_MAX = 248;
localparam logic [15:0] OCP_REC_REASON_STANDARD_MAX = 16'h0012;
localparam logic [15:0] OCP_REC_REASON_VENDOR_MIN   = 16'h0080;
localparam logic [15:0] OCP_REC_REASON_VENDOR_MAX   = 16'h00FF;

// ----------------------------------------------------------------------------
// RECOVERY_STATUS fields and values (OCP Recovery v1.1 Sec 9.2).
// ----------------------------------------------------------------------------
localparam int OCP_OFF_RS_STATUS_IMAGE_INDEX = 0;
localparam int OCP_OFF_RS_VENDOR_STATUS      = 1;
localparam logic [7:0] OCP_RS_STATUS_MASK     = 8'h0F;
localparam logic [7:0] OCP_RS_IMAGE_INDEX_MASK = 8'hF0;
localparam int OCP_RS_IMAGE_INDEX_SHIFT      = 4;

typedef enum logic [3:0] {
  OCP_RECOVERY_STATUS_NOT_IN_RECOVERY = 4'h0,
  OCP_RECOVERY_STATUS_AWAITING_IMAGE  = 4'h1,
  OCP_RECOVERY_STATUS_BOOTING_IMAGE   = 4'h2,
  OCP_RECOVERY_STATUS_SUCCESS         = 4'h3,
  OCP_RECOVERY_STATUS_FAILED          = 4'hC,
  OCP_RECOVERY_STATUS_AUTH_ERROR      = 4'hD,
  OCP_RECOVERY_STATUS_ENTRY_ERROR     = 4'hE,
  OCP_RECOVERY_STATUS_INVALID_CMS     = 4'hF
} ocp_recovery_status_e;

// ----------------------------------------------------------------------------
// HW_STATUS and INDIRECT_FIFO_STATUS fields (OCP Recovery v1.1 Sec 9.2).
// ----------------------------------------------------------------------------
localparam logic [7:0] OCP_HW_STATUS_RESERVED_MASK = 8'hF8;
localparam int OCP_HW_STATUS_VENDOR_LEN_MAX = 251;

localparam int OCP_OFF_IFS_STATUS            = 0;
localparam int OCP_OFF_IFS_REGION_TYPE       = 1;
localparam int OCP_OFF_IFS_RESERVED_LO       = 2;
localparam int OCP_OFF_IFS_RESERVED_HI       = 3;
localparam int OCP_OFF_IFS_WRITE_INDEX_B0    = 4;
localparam int OCP_OFF_IFS_WRITE_INDEX_B3    = 7;
localparam int OCP_OFF_IFS_READ_INDEX_B0     = 8;
localparam int OCP_OFF_IFS_READ_INDEX_B3     = 11;
localparam int OCP_OFF_IFS_FIFO_SIZE_B0      = 12;
localparam int OCP_OFF_IFS_FIFO_SIZE_B3      = 15;
localparam int OCP_OFF_IFS_MAX_TRANSFER_B0   = 16;
localparam int OCP_OFF_IFS_MAX_TRANSFER_B3   = 19;
localparam logic [7:0] OCP_IFS_EMPTY_MASK     = 8'h01;
localparam logic [7:0] OCP_IFS_FULL_MASK      = 8'h02;
localparam logic [7:0] OCP_IFS_STATUS_RSVD_MASK = 8'hFC;

localparam logic [7:0] OCP_REGION_RECOVERY_CODE_WO = 8'h00;
localparam logic [7:0] OCP_REGION_DEBUG_LOG_RO     = 8'h01;
localparam logic [7:0] OCP_REGION_VENDOR_WO        = 8'h04;
localparam logic [7:0] OCP_REGION_VENDOR_RO        = 8'h05;
localparam logic [7:0] OCP_REGION_UNSUPPORTED      = 8'h07;

// ----------------------------------------------------------------------------
// OCP Recovery USB functional descriptor (OCP Recovery v1.1 Sec 8.5.3).
// ----------------------------------------------------------------------------
localparam int OCP_USB_FUNC_DESC_LEN              = 10;
localparam logic [7:0] OCP_USB_FUNC_DESC_TYPE     = 8'h24;
localparam logic [7:0] OCP_USB_FUNC_DESC_SUBTYPE  = 8'h01;
localparam int OCP_OFF_UFD_LENGTH                  = 0;
localparam int OCP_OFF_UFD_TYPE                    = 1;
localparam int OCP_OFF_UFD_SUBTYPE                 = 2;
localparam int OCP_OFF_UFD_RESERVED                = 3;
localparam int OCP_OFF_UFD_MAX_WR_LO               = 4;
localparam int OCP_OFF_UFD_MAX_WR_HI               = 5;
localparam int OCP_OFF_UFD_MAX_RD_LO               = 6;
localparam int OCP_OFF_UFD_MAX_RD_HI               = 7;
localparam int OCP_OFF_UFD_BCD_VERSION_LO          = 8;
localparam int OCP_OFF_UFD_BCD_VERSION_HI          = 9;
localparam logic [15:0] OCP_USB_BCD_VERSION_1P1    = 16'h0110;
localparam int OCP_USB_MIN_TRANSFER_SIZE           = 64;

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
