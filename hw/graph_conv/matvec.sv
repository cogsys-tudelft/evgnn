/*
Copyright 2024 Yufeng Yang (CogSys Group)
SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

Licensed under the Solderpad Hardware License v 2.1 (the “License”);
you may not use this file except in compliance with the License, or,
at your option, the Apache License version 2.0.
You may obtain a copy of the License at

https://solderpad.org/licenses/SHL-2.1/

Unless required by applicable law or agreed to in writing,
any work distributed under the License is distributed on an “AS IS” BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.
*/
`include "aegnn.svh"
import aegnn::*;

module matvec #(
    parameter integer IN_C          = 34,
    parameter integer OUT_C         = 32,
    parameter integer MAC_LATENCY   = 4,
    parameter         MEM_INIT_FILE = "test_data.mem",

    localparam IN_C_WIDTH  = $clog2(IN_C),
    localparam OUT_C_WIDTH = $clog2(OUT_C),
    localparam W_MEM_WIDTH = OUT_C * W_WIDTH
) (
    input  logic                            clk,
    input  logic                            rstn,
    input  logic                            clean,
    input  logic                            calc_en,
    input  logic [ IN_C * P_WIDTH -1:0]     feature_in_pack,
    output logic [OUT_C * B_WIDTH -1:0]     accum_out_pack,
    output logic                            accum_out_valid
);
    logic [ IN_C -1:0][P_WIDTH -1:0] feature_in;
    logic [IN_C_WIDTH          -1:0] in_c_idx;
    logic                            last_idx;

    logic [OUT_C * W_WIDTH     -1:0] w_vec_pack;
    logic [P_WIDTH             -1:0] feature_reg;
    logic [P_WIDTH             -1:0] feature_clean;
    logic [P_WIDTH             -1:0] feature;

    generate
        for (genvar i = 0; i < IN_C; i++) begin
            assign feature_in[i] = feature_in_pack[(i+1)*P_WIDTH -1 -: P_WIDTH];
        end
    endgenerate

    // For w[OUT_C][IN_C], get w_vec = w[:][in_c_idx]
    w_mat #(
        .IN_C          (IN_C         ),
        .OUT_C         (OUT_C        ),
        .MEM_INIT_FILE (MEM_INIT_FILE)
    ) w_mat_inst (
        .clk          (clk       ),
        .rd_en        (calc_en   ),
        .in_c_idx     (in_c_idx  ),
        .w_vec_pack   (w_vec_pack)
    );

    // Traverse all the input feature
    always @(posedge clk) begin
        if (clean || !rstn)
            in_c_idx <= 0;
        else begin
            if (calc_en) begin
                if (in_c_idx < IN_C - 1)
                    in_c_idx <= in_c_idx + 1;
                else  // in_c_idx == IN_C - 1, hold
                    in_c_idx <= in_c_idx;
            end
            else
                in_c_idx <= 0;
        end
    end

    always @(posedge clk) begin
        if (clean || !rstn)
            last_idx <= 1'b0;
        else begin
            if (calc_en) begin
                if (in_c_idx == IN_C - 1)
                    last_idx <= 1'b1;
                else
                    last_idx <= 1'b0;
            end
            else
                last_idx <= 1'b0;
        end
    end

    // Delay 1 clk to sync with w_mat (BRAM)
    always @(posedge clk) begin
        if (clean || !rstn) begin
            feature_reg <= 0;
        end
        else begin
            if (calc_en)
                feature_reg <= feature_in[in_c_idx];
            else
                feature_reg <= 0;
        end
    end

    always @ (posedge clk) begin
        if (last_idx)
            feature_clean <= '0;
        else
            feature_clean <= '1;
    end
    assign feature = feature_reg & feature_clean;  // to stop accumulation

    // Element-wise mult broadcasted feature and w_vec, then accumulated
    generate
        for (genvar out_c_idx = 0; out_c_idx < OUT_C; out_c_idx++) begin
            w_t w_vec;
            assign w_vec = w_vec_pack[(out_c_idx+1)*W_WIDTH -1 -: W_WIDTH];
            accum_t accum_out;
            assign accum_out_pack[(out_c_idx+1)*B_WIDTH -1 -: B_WIDTH] = accum_out;

            MAC #(
                .LATENCY   (MAC_LATENCY)
            ) MAC_inst (
                .clk       (clk),
                .rstn      (rstn & ~clean),
                .feature   (feature),
                .weight    (w_vec),
                .accum_out (accum_out)
            );
        end
    endgenerate

    // Generate accum_out_valid
    logic [MAC_LATENCY -1:0] accum_out_valid_reg ;
    always @ (posedge clk) begin
        if (clean || !rstn)
            accum_out_valid_reg <= '0;
        else begin
            accum_out_valid_reg[0] <= last_idx;
            for (int i = 0; i < MAC_LATENCY - 1; i++)
                accum_out_valid_reg[i+1] <= accum_out_valid_reg[i];
        end
    end
    assign accum_out_valid = accum_out_valid_reg[MAC_LATENCY - 1];

endmodule
