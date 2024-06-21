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
`timescale 1ns/1ps

module mult_wrapper (
    input         clk,
    input  [32*8-1:0]  feature,
    input  [34*8-1:0]  weight,
    input  [5:0]  addr_i,
    input  [5:0]  addr_j,
    output [15:0] product
);

    parameter LATENCY = 2;

    wire [15:0] product_array [0:31][0:33];
    assign product = product_array[addr_i][addr_j];



    generate
        for (genvar i = 0; i < 32; i = i + 1) begin
            for (genvar j = 0; j < 34; j = j + 1) begin

                mult_GNN #(
                    .LATENCY (LATENCY),
                    .DEVICE  ("code")
                )mult_GNN_inst(
                    .clk(clk),
                    .feature(feature [8*i+7 : 8*i] ),
                    .weight (weight  [8*j+7 : 8*j] ),
                    .product(product_array[i][j])
                );

            end
        end
    endgenerate

endmodule