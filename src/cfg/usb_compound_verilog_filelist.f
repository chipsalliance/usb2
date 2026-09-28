// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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

// AXI-to-AHB converters
${USB_COMPILE_DIR}/../../src/integration/rtl/axilite_to_ahb.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/axi_to_ahb.sv

// OCP Recovery register block and transport
${USB_COMPILE_DIR}/../../src/integration/rtl/generated/usb_ocp_recovery_reg_pkg.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/generated/usb_ocp_recovery_reg.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/usb_ocp_recovery_pkg.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/usb_ocp_recovery_ctrl_decode.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/usb_ocp_recovery_rb_adapter.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/usb_ocp_recovery_cms_fifo.sv
${USB_COMPILE_DIR}/../../submodules/caliptra-rtl/src/libs/rtl/ahb_defines_pkg.sv
${USB_COMPILE_DIR}/../../submodules/caliptra-rtl/src/libs/rtl/ahb_slv_sif.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/usb_ocp_recovery_top.sv

// Compound wrapper and local AHB decoder
${USB_COMPILE_DIR}/../../src/integration/rtl/usb_compound_pkg.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/usb_compound_ahb_decoder.sv
${USB_COMPILE_DIR}/../../src/integration/rtl/ip_xxx_3511_hs_mem_compound_wrapper.sv
