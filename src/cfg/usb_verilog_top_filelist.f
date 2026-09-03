-work rtl
+incdir+${USB_COMPILE_DIR}/../../src/integration/rtl
+incdir+${CALIPTRA_RTL_ROOT}/src/caliptra_prim/rtl
+incdir+${CALIPTRA_RTL_ROOT}/src/libs/rtl

// Caliptra AXI package and primitives
${CALIPTRA_RTL_ROOT}/src/axi/rtl/axi_pkg.sv
${CALIPTRA_RTL_ROOT}/src/caliptra_prim/rtl/caliptra_prim_util_pkg.sv
${CALIPTRA_RTL_ROOT}/src/caliptra_prim/rtl/caliptra_prim_fifo_sync_cnt.sv
${CALIPTRA_RTL_ROOT}/src/caliptra_prim/rtl/caliptra_prim_fifo_sync.sv
${CALIPTRA_RTL_ROOT}/src/axi/rtl/axi_if.sv
${CALIPTRA_RTL_ROOT}/src/axi/rtl/axi_addr.v

// AXI-to-AHB converter
${USB_COMPILE_DIR}/../../src/integration/rtl/axilite_to_ahb.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/axi_to_ahb.sv

// Top-level wrapper
${USB_COMPILE_DIR}/../../src/integration/rtl/ip_xxx_3516_hs_mem_wrapper.sv

// OCP Recovery v1.1 over USB (regblock generated from
// ../../systemrdl/usb_ocp_recovery_reg.rdl by peakrdl)
${USB_COMPILE_DIR}/../../src/integration/rtl/generated/usb_ocp_recovery_reg_pkg.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/generated/usb_ocp_recovery_reg.sv
// Shared OCP command-code / length / offset constants (single source of truth).
${USB_COMPILE_DIR}/../../src/integration/rtl/usb_ocp_recovery_pkg.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/usb_ocp_recovery_ctrl_decode.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/usb_ocp_recovery_rb_adapter.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/usb_ocp_recovery_cms_fifo.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/usb_ocp_recovery_top.sv

// Top-tb
${USB_COMPILE_DIR}/../../src/integration/tb/usb_top_tb.sv
