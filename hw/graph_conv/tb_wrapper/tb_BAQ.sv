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

module tb_bias_act_quant;

    // bias_act_quant Parameters
    parameter PERIOD         = 10                  ;
    parameter OUT_C          = 32                  ;
    parameter M              = 12345               ;
    parameter NM             = 20                  ;
    parameter MEM_INIT_FILE  = "test_bias_data.mem";

    // bias_act_quant Inputs
    logic clk                            = 0 ;
    logic rstn                           = 0 ;
    logic [OUT_C -1:0][B_WIDTH -1 : 0] aggr_pack = 0 ;
    logic aggr_valid                     = 0 ;

    // bias_act_quant Outputs
    logic [OUT_C -1:0][F_WIDTH -1 : 0] conv_out_pack ;
    logic conv_out_valid                 ;


    initial
    begin
        #2000;
        rstn <= 'b1;
        aggr_pack <= {OUT_C{32'h0001}};
        aggr_valid <= 'b1;

    end

    always #(PERIOD/2)  clk=~clk;


    bias_act_quant #(
        .OUT_C         ( OUT_C         ),
        .M             ( M             ),
        .NM            ( NM            ),
        .MEM_INIT_FILE ( MEM_INIT_FILE ))
    u_bias_act_quant (
        .clk            ,
        .rstn           ,
        .aggr_pack      ,
        .aggr_valid     ,

        .conv_out_pack  ,
        .conv_out_valid
    );


endmodule