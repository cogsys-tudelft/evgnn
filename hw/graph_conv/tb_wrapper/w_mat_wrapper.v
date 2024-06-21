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

module w_mat_wrapper #(
    parameter IN_C  = 34,
    parameter OUT_C = 32,
    parameter MEM_INIT_FILE = "test_data.mem",
    parameter W_WIDTH = 8,

    localparam IN_C_WIDTH = $clog2(IN_C),
    localparam W_MEM_WIDTH = OUT_C * W_WIDTH
) (
    input wire clk,
    input wire rd_en,
    input wire [IN_C_WIDTH  -1 : 0] in_c_idx,
    output wire [W_MEM_WIDTH -1:0] w_vec_pack
);
    w_mat #(
        .IN_C  (IN_C),
        .OUT_C (OUT_C),
        .MEM_INIT_FILE(MEM_INIT_FILE)
    )w_mat_inst (
        clk,
        rd_en,
        in_c_idx,
        w_vec_pack
    );


endmodule