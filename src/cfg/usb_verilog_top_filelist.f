-work rtl
+incdir+${USB_COMPILE_DIR}/../../src/integration/rtl
+incdir+${USB_COMPILE_DIR}/../../submodules/caliptra-rtl/src/caliptra_prim/rtl
+incdir+${USB_COMPILE_DIR}/../../submodules/caliptra-rtl/src/libs/rtl

// Caliptra AXI package and primitives
${USB_COMPILE_DIR}/../../submodules/caliptra-rtl/src/axi/rtl/axi_pkg.sv
${USB_COMPILE_DIR}/../../submodules/caliptra-rtl/src/caliptra_prim/rtl/caliptra_prim_util_pkg.sv
${USB_COMPILE_DIR}/../../submodules/caliptra-rtl/src/caliptra_prim/rtl/caliptra_prim_fifo_sync_cnt.sv
${USB_COMPILE_DIR}/../../submodules/caliptra-rtl/src/caliptra_prim/rtl/caliptra_prim_fifo_sync.sv
${USB_COMPILE_DIR}/../../submodules/caliptra-rtl/src/axi/rtl/axi_if.sv
${USB_COMPILE_DIR}/../../submodules/caliptra-rtl/src/axi/rtl/axi_addr.v

// AXI-to-AHB converter
${USB_COMPILE_DIR}/../../src/integration/rtl/axilite_to_ahb.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/axi_to_ahb.sv

// Top-level wrapper
${USB_COMPILE_DIR}/../../src/integration/rtl/ip_xxx_3516_hs_mem_wrapper.sv

// Top-tb
${USB_COMPILE_DIR}/../../src/integration/tb/usb_top_tb.sv
