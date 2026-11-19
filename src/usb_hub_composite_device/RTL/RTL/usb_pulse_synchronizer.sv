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

// Capture one word when the destination sees ctrl_i go high. Keeping ctrl_i
// high does not send another word. There is no acknowledgment to the source.
//
// dst_clk:   Rising-edge clock for the receiver. It must run during a transfer.
// dst_rst_n: Active-low reset; clears the captured word and both indicators.
//            Keep ctrl_i low through reset and release reset safely for dst_clk.
// ctrl_i:    Raise this level to announce a word. Hold it high through capture,
//            then low long enough for the receiver to see it before sending again.
// data_i:    Present the whole word when raising ctrl_i and hold it unchanged
//            through destination capture. Only ctrl_i passes through synchronizer flops.
// data_o:    Captured word; holds its value until the next capture or reset.
// valid_o: Level. Goes high with the captured word and stays high until the
//          synchronized ctrl_i goes low. A held-high level is still one word.
// valid_pulse_o: Pulse. High for one dst_clk cycle when data_o captures a new
//                word, even if valid_o stays high for several cycles.
module usb_pulse_synchronizer #(
  parameter int unsigned DATA_WIDTH = 1
) (
  input  logic                  dst_clk,
  input  logic                  dst_rst_n,
  input  logic                  ctrl_i,
  input  logic [DATA_WIDTH-1:0] data_i,
  output logic [DATA_WIDTH-1:0] data_o,
  output logic                  valid_o,
  output logic                  valid_pulse_o
);
  logic ctrl_sync;

  caliptra_prim_flop_2sync #(
    .Width(1)
  ) u_ctrl_sync (
    .clk_i (dst_clk),
    .rst_ni(dst_rst_n),
    .d_i   (ctrl_i),
    .q_o   (ctrl_sync)
  );

  always_ff @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
      valid_o <= 1'b0;
      valid_pulse_o <= 1'b0;
      data_o  <= '0;
    end else begin
      valid_o <= ctrl_sync;
      valid_pulse_o <= 1'b0;
      if (ctrl_sync && !valid_o) begin
        data_o  <= data_i;
        valid_pulse_o <= 1'b1;
      end
    end
  end
endmodule
