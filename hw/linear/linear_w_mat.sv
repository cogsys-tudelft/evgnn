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

module linear_w_mat #(
    parameter integer FC_IN_C = 1792,
    parameter integer FC_OUT_C = 2,
    parameter         MEM_INIT_FILE = "test_fc_data.mem",

    localparam integer FC_IN_C_WIDTH = $clog2(FC_IN_C)
) (
    input  logic clk,
    input  logic rd_en,
    input  logic [FC_IN_C_WIDTH -1 : 0] w_idx,
    output logic [FC_OUT_C * FC_W_WIDTH -1:0] fc_w
);

    (* rom_style = "block" *) logic [FC_OUT_C * FC_W_WIDTH -1 : 0] fc_w_mem [0 : FC_IN_C -1];
    initial begin
        $readmemh(MEM_INIT_FILE, fc_w_mem);
    end


    always @ (posedge clk) begin
        if (rd_en)
            fc_w <= fc_w_mem[w_idx];
        else
            fc_w <= '0;
    end
endmodule