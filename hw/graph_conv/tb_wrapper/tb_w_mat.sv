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

module tb_w_mat;
    parameter IN_C  = 34;
    parameter OUT_C = 32;
    parameter MEM_INIT_FILE = "test_data.mem";

    localparam IN_C_WIDTH = $clog2(IN_C);
    localparam W_MEM_WIDTH = OUT_C * W_WIDTH;

    logic clk;
    logic rd_en;
    logic [IN_C_WIDTH  -1 : 0] in_c_idx;
    // logic [OUT_C -1:0][W_WIDTH-1:0] w_vec ;
    logic [W_MEM_WIDTH -1 : 0] w_vec_pack;

    initial begin
        clk <= 0;
        rd_en <= 0;
        in_c_idx <= 0;

        #1000;
        rd_en <= 1;

        #10;
        in_c_idx <= 1;

        #10;
        in_c_idx <= 2;

        #10;
        in_c_idx <= 3;

        #10;
        in_c_idx <= 33;

        #10;
        in_c_idx <= 34;

    end
    always #5 clk = ~clk;


    w_mat_wrapper #(
        .IN_C(IN_C),
        .OUT_C(OUT_C),
        .MEM_INIT_FILE(MEM_INIT_FILE)
    ) w_mat_inst (.*);

endmodule