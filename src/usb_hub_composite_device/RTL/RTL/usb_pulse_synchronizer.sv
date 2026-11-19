// SPDX-License-Identifier: Apache-2.0
// Open-loop bundled-data receiver: hold ctrl_i low through reset. Both the
// high and low levels must be sampled for each word, and data_i must remain
// stable from publication through destination capture. There is no acknowledgement.
module usb_pulse_synchronizer #(
  parameter int unsigned DATA_WIDTH = 1
) (
  input  logic                  dst_clk,
  input  logic                  dst_rst_n,
  input  logic                  ctrl_i,
  input  logic [DATA_WIDTH-1:0] data_i,
  output logic [DATA_WIDTH-1:0] data_o,
  output logic                  valid_o,
  output logic                  pulse_o
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
      pulse_o <= 1'b0;
      data_o  <= '0;
    end else begin
      valid_o <= ctrl_sync;
      pulse_o <= 1'b0;
      if (ctrl_sync && !valid_o) begin
        data_o  <= data_i;
        pulse_o <= 1'b1;
      end
    end
  end
endmodule
