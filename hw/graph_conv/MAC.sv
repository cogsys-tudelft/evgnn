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

(* use_dsp = "yes" *) module MAC #(
    parameter LATENCY = 4,      // min= 4
    parameter DEVICE  = "code"  // "code" or "ip"

)(
    input  logic  clk,
    input  logic  rstn,
    input  p_t    feature,
    input  w_t    weight,
    output accum_t accum_out
);
    p_t f_reg;
    w_t w_reg;
    mult_t product;
    accum_t accum;


    always @ (posedge clk) begin
        if (!rstn) begin
            f_reg <= '0;
            w_reg <= '0;
            product <= '0;
            accum <= '0;
        end
        else begin
            f_reg <= feature;
            w_reg <= weight;
            product <= $signed({1'b0, f_reg}) * $signed(w_reg);
            accum <= accum + product;
        end
    end

    accum_t accum_reg [LATENCY-3];
    always @ (posedge clk) begin
        if (!rstn) begin
            for (int i = 0; i < LATENCY-3; i++)
                accum_reg[i] <= '0;
        end
        else begin
            accum_reg[0] <= accum;
            for (int i = 0; i < LATENCY-4; i++)
                accum_reg[i + 1] <= accum_reg[i];
        end
    end
    assign accum_out = accum_reg[LATENCY-4];


    // mult_t product;
    // accum_t accum_prev;
    // accum_t accum_prev_reg [LATENCY];

    // mult_GNN #(
    //     .LATENCY (LATENCY - 1),
    //     .DEVICE  ("code")
    // )mult_GNN_inst(
    //     .clk(clk),
    //     .feature(feature),
    //     .weight (weight),
    //     .product(product)
    // );

    // always @ (posedge clk) begin
    //     if (!rstn) begin
    //         accum <= '0;
    //     end
    //     else begin
    //         accum <= accum_prev_reg[LATENCY-1] + product;
    //     end
    // end

    // always @ (posedge clk) begin
    //     if (!rstn) begin
    //         accum_prev <= '0;
    //     end
    //     else begin
    //         accum_prev <= accum;
    //     end
    // end

    // always @ (posedge clk) begin
    //     if (!rstn) begin
    //         for (int i = 0; i < LATENCY; i++)
    //             accum_prev_reg[i] <= '0;
    //     end
    //     else begin
    //         accum_prev_reg[0] <= accum_prev;
    //         for (int i = 0; i < LATENCY-1; i++)
    //             accum_prev_reg[i + 1] <= accum_prev_reg[i];
    //     end
    // end


endmodule