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

module w_mat #(
    parameter integer IN_C  = 34,
    parameter integer OUT_C = 32,
    parameter MEM_INIT_FILE = "test_data.mem",

    localparam IN_C_WIDTH = $clog2(IN_C),
    localparam W_MEM_WIDTH = OUT_C * W_WIDTH
) (
    input logic clk,
    input logic rd_en,
    input logic [IN_C_WIDTH  -1 : 0] in_c_idx,
    // output logic [OUT_C -1:0][W_WIDTH -1:0] w_vec
    output logic [W_MEM_WIDTH -1 : 0] w_vec_pack
);
    // logic [W_MEM_WIDTH -1 : 0] w_vec_pack;
    // generate
    //     for (genvar i = 0; i < OUT_C; i++) begin
    //         assign w_vec[i] = w_vec_pack[(i+1)*W_WIDTH -1 -: W_WIDTH];
    //     end
    // endgenerate

    (* rom_style = "block" *) logic [W_MEM_WIDTH -1 : 0] w_mem [0 : IN_C -1];
    initial begin  //TODO: for test
        $readmemh(MEM_INIT_FILE,w_mem);
    end

    always @ (posedge clk) begin
        if (rd_en)
            w_vec_pack <= w_mem[in_c_idx];
        else
            w_vec_pack <= '0;
    end

endmodule