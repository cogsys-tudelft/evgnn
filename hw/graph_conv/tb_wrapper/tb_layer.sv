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

module tb_layer;

    // layer Parameters
    parameter PERIOD       = 10                  ;
    parameter IN_C         = 34                  ;
    parameter OUT_C        = 32                  ;
    parameter MAC_LATENCY  = 4                   ;
    parameter M            = 12345               ;
    parameter NM           = 20                  ;
    parameter W_MEM_FILE   = "test_data.mem"     ;
    parameter B_MEM_FILE   = "test_bias_data.mem";

    // layer Inputs
    logic                            clk     = 0 ;
    logic                            rstn    = 0 ;
    logic                            is_neighbor = 0 ;
    logic                            no_neighbor = 0 ;
    logic                            clean   = 0 ;
    logic [ IN_C -1:0][F_WIDTH -1:0] feature_in = 0 ;

    // layer Outputs
    logic [OUT_C -1:0][F_WIDTH -1:0] conv_out ;
    logic                            neighbor_done ;
    logic                            conv_done ;


    initial
    begin
        #1000;
        rstn <= 1'b1;

        #50;
        is_neighbor <= 1'b1;
        for (int i = 34; i >= 1; i--) begin
            feature_in[34-i] <= i[7:0];
        end

        #390;
        is_neighbor <= 1'b0;

        #50;
        is_neighbor <= 1'b1;
        for (int i = 1; i <= 34; i++) begin
            feature_in[i-1] <= i[7:0];
        end

        #390;
        is_neighbor <= 1'b0;

        #50;
        no_neighbor <= 1'b1;

        #100;
        no_neighbor <= 1'b0;
        clean <= 1'b1;

        #20;
        clean <= 1'b0;

        #20;
        no_neighbor <= 1'b1;


    end
    always #(PERIOD/2)  clk=~clk;


    layer #(
        .IN_C        ( IN_C        ),
        .OUT_C       ( OUT_C       ),
        .MAC_LATENCY ( MAC_LATENCY ),
        .M           ( M           ),
        .NM          ( NM          ),
        .W_MEM_FILE  ( W_MEM_FILE  ),
        .B_MEM_FILE  ( B_MEM_FILE  ))
    u_layer (
        .clk              ( clk               ),
        .rstn             ( rstn              ),
        .is_neighbor      ( is_neighbor       ),
        .no_neighbor      ( no_neighbor       ),
        .clean            ( clean             ),
        .feature_in_pack  ( feature_in   ),

        .conv_out_pack    ( conv_out     ),
        .neighbor_done    ( neighbor_done     ),
        .conv_done        ( conv_done         )
    );



endmodule