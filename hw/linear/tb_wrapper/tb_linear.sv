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

module tb_linear;

    // linear Parameters
    parameter PERIOD         = 10                ;
    parameter L4_OUT_C       = 32                ;
    parameter FC_OUT_C       = 2                 ;
    parameter MEM_INIT_FILE  = "test_fc_data.mem";
    parameter MAC_LATENCY    = 4                 ;

    // linear Inputs
    logic clk                            = 0 ;
    logic rstn                           = 0 ;
    logic event_stream_clean             = 0 ;
    logic module_start                   = 0 ;
    grid_idx_t grid_idx                  = 0 ;
    logic [L4_OUT_C -1 : 0][F_WIDTH -1 : 0] max_pool_dx_out_pack = 0 ;

    // linear Outputs
    logic module_done                    ;
    logic fc_out_valid                   ;
    logic [FC_OUT_C -1 : 0][FC_OUT_WIDTH -1 : 0] fc_out_pack ;


    initial
    begin
        #1000;
        rstn <= 1'b1;
        grid_idx <= 55;
        max_pool_dx_out_pack <= {16{8'd255, 8'd0}};
        #50;
        module_start <= 1'b1;
        #10;
        module_start <= 1'b0;

        #1000;
        grid_idx <= 1;
        max_pool_dx_out_pack <= {L4_OUT_C{8'd1}};
        #50;
        module_start <= 1'b1;
        #10;
        module_start <= 1'b0;

        #1000;
        event_stream_clean <= 1'b1;
        #10;
        event_stream_clean <= 1'b0;
        #10;
        grid_idx <= 55;
        max_pool_dx_out_pack <= {16{8'd0, 8'd255}};
        #50;
        module_start <= 1'b1;
        #10;
        module_start <= 1'b0;


    end
    always #(PERIOD/2)  clk=~clk;


    linear #(
        .L4_OUT_C      ( L4_OUT_C      ),
        .FC_OUT_C      ( FC_OUT_C      ),
        .MEM_INIT_FILE ( MEM_INIT_FILE ),
        .MAC_LATENCY   ( MAC_LATENCY   )
    ) linear_inst (
        .clk                 ( clk                 ),
        .rstn                ( rstn                ),
        .event_stream_clean  ( event_stream_clean  ),
        .module_start        ( module_start        ),
        .grid_idx            ( grid_idx            ),
        .max_pool_dx_out_pack( max_pool_dx_out_pack),

        .module_done         ( module_done         ),
        .fc_out_valid        ( fc_out_valid        ),
        .fc_out_pack         ( fc_out_pack         )
    );


endmodule