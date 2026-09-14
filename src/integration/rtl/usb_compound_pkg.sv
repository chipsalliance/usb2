// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// you may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
package usb_compound_pkg;
  // Map addresses are Combo-port-local byte offsets. Address limits are
  // exclusive upper bounds; actual AXI interface widths come from axi_if.
  localparam int unsigned AXI_ADDR_WIDTH_MAX = 32;

  localparam logic [32:0] DEV0_CSR_BASE_ADDR = 33'h0000_0000;
  localparam logic [32:0] DEV_CSR_APERTURE_BYTES = 33'h0000_0040;
  localparam int unsigned DEV_CSR_ADDR_WIDTH = $clog2(DEV_CSR_APERTURE_BYTES);
  localparam logic [32:0] DEV0_CSR_ADDR_LIMIT = DEV0_CSR_BASE_ADDR + DEV_CSR_APERTURE_BYTES;

  localparam logic [32:0] RECOVERY_BASE_ADDR = 33'h0000_0800;
  localparam logic [32:0] RECOVERY_APERTURE_BYTES = 33'h0000_0800;
  localparam logic [32:0] RECOVERY_ADDR_LIMIT = RECOVERY_BASE_ADDR + RECOVERY_APERTURE_BYTES;
  localparam int unsigned RECOVERY_LOCAL_ADDR_WIDTH = $clog2(RECOVERY_APERTURE_BYTES);

  localparam logic [32:0] HUB_BASE_ADDR = 33'h0000_1000;
endpackage : usb_compound_pkg
