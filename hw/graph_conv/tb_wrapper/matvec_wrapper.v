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

module matvec_wrapper #(
    parameter integer IN_C = 34,
    parameter integer OUT_C = 32,
    parameter MEM_INIT_FILE = "test_data.mem",
    parameter MAC_LATENCY = 4,
    parameter W_WIDTH = 8,
    parameter F_WIDTH = 8,
    parameter B_WIDTH = 32,

    localparam IN_C_WIDTH  = $clog2(IN_C),
    localparam OUT_C_WIDTH = $clog2(OUT_C),
    localparam W_MEM_WIDTH = OUT_C * W_WIDTH
) (
    input  wire                            clk,
    input  wire                            rstn,
    input  wire                            clean,
    input  wire                            calc_en,
    input  wire [ IN_C * F_WIDTH -1:0] feature_in_pack,
    output wire [OUT_C * B_WIDTH -1:0] accum_out_pack,
    output wire                            accum_out_valid
);


    matvec #(
        .IN_C (IN_C),
        .OUT_C (OUT_C),
        .MEM_INIT_FILE (MEM_INIT_FILE),
        .MAC_LATENCY (MAC_LATENCY)
    )matvec_inst (
        .clk(clk),
        .rstn(rstn),
        .clean(clean),
        .calc_en(calc_en),
        .feature_in_pack(feature_in_pack),
        .accum_out_pack(accum_out_pack),
        .accum_out_valid(accum_out_valid)
    );


endmodule