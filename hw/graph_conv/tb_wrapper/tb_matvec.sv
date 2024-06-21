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

module tb_matvec;

    parameter integer IN_C = 34;
    parameter integer OUT_C = 32;
    parameter MEM_INIT_FILE = "test_data.mem";
    parameter LATENCY = 4;

    localparam IN_C_WIDTH  = $clog2(IN_C);
    localparam OUT_C_WIDTH = $clog2(OUT_C);
    localparam W_MEM_WIDTH = OUT_C * W_WIDTH;

    logic                            clk;
    logic                            rstn;
    logic                            clean;
    logic                            calc_en;
    logic [ IN_C -1:0][F_WIDTH -1:0] feature_in;
    logic [OUT_C -1:0][B_WIDTH -1:0] accum_out;
    logic                            accum_out_valid;

    matvec_wrapper #(
        .IN_C  (IN_C),
        .OUT_C (OUT_C),
        .MEM_INIT_FILE (MEM_INIT_FILE),
        .MAC_LATENCY (LATENCY)
    ) matvec_inst (
        .clk,
        .rstn,
        .clean,
        .calc_en,
        .feature_in_pack(feature_in),
        .accum_out_pack(accum_out),
        .accum_out_valid
    );

    initial begin
        clk <= 1'b0;
        rstn <= 1'b0;
        calc_en <= '0;
        feature_in <= '0;
        clean <= '1;

        #2000;
        rstn <= 1'b1;

        #50;
        // feature_in <= {8'd1, 8'd2, 8'd3, 8'd4, 8'd5, 8'd6, 8'd7, 8'd8, 8'd9, 8'd10, 8'd11, 8'd12, 8'd13, 8'd14, 8'd15, 8'd16, 8'd17, 8'd18, 8'd19, 8'd20, 8'd21, 8'd22, 8'd23, 8'd24, 8'd25, 8'd26, 8'd27, 8'd28, 8'd29, 8'd30, 8'd31, 8'd32, 8'd33, 8'd34};
        for (int i = 1; i <= 34; i++) begin
            feature_in[i-1] <= i[7:0];
        end

        #50;
        calc_en <= 1'b1;
        clean <= 0;


        #380;
        calc_en <= '0;
        clean = '1;

        #10;
        clean = '0;
        calc_en <= '1;

        // #20;
        // calc_en <= '1;

        // #50;
        // clean = '1;
        // #10;
        // clean = '0;
    end

    always #5 clk = ~clk;

endmodule