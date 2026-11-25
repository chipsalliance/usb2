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

// Each source valid sample flips the toggle, or only the rising sample when
// SRC_RISE_ONLY is set. src_launch_o qualifies the same source edge.
// Hold the registered source word until destination capture and space launches
// so neither transition is missed.
// This crossing has no acknowledgment or queue; reset both sides together.
module usb_toggle_bus_synchronizer #(
  parameter int unsigned DATA_WIDTH = 1,
  parameter bit SRC_RISE_ONLY = 1'b0
) (
  input  logic                  src_clk,
  input  logic                  src_rst_n,
  input  logic                  src_valid_i,
  input  logic [DATA_WIDTH-1:0] src_data_i,
  input  logic                  dst_clk,
  input  logic                  dst_rst_n,
  output logic                  valid_pulse_o,
  output logic [DATA_WIDTH-1:0] dst_data_o,
  output logic                  src_launch_o
);
  logic src_toggle, toggle_sync, toggle_seen;
  logic beat_event;

  if (SRC_RISE_ONLY) begin : gen_src_rise
    logic src_valid_q;

    always_ff @(posedge src_clk or negedge src_rst_n) begin
      if (!src_rst_n) begin
        src_valid_q <= 1'b0;
      end else begin
        src_valid_q <= src_valid_i;
      end
    end

    assign src_launch_o = src_valid_i & ~src_valid_q;
  end else begin : gen_src_valid
    assign src_launch_o = src_valid_i;
  end

  always_ff @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n) begin
      src_toggle <= 1'b0;
    end else if (src_launch_o) begin
      src_toggle <= !src_toggle;
    end
  end

  caliptra_prim_flop_2sync #(
    .Width(1)
  ) u_toggle_sync (
    .clk_i  (dst_clk),
    .rst_ni (dst_rst_n),
    .d_i    (src_toggle),
    .q_o    (toggle_sync)
  );

  assign beat_event = toggle_sync ^ toggle_seen;

  always_ff @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
      toggle_seen <= 1'b0;
      valid_pulse_o <= 1'b0;
      dst_data_o <= '0;
    end else begin
      toggle_seen <= toggle_sync;
      valid_pulse_o <= beat_event;
      if (beat_event) begin
        dst_data_o <= src_data_i;
      end
    end
  end
endmodule
