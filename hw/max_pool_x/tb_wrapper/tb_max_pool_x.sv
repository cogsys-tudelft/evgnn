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

module tb_max_pool_x;

    // max_pool_x Parameters
    parameter PERIOD  = 10;
    parameter L4_OUT_C = 32;


    // max_pool_x Inputs
    logic clk                            = 0 ;
    logic rstn                           = 0 ;
    logic module_start                   = 0 ;
    logic event_stream_clean             = 0 ;
    // event_s new_event                    = 0 ;
    x_idx_t new_event_x = 0;
    y_idx_t new_event_y = 0;
    logic [L4_OUT_C -1:0][F_WIDTH -1 : 0] last_layer_out_pack = 0 ;

    // max_pool_x Outputs
    logic module_done                    ;
    grid_idx_t grid_idx                  ;
    logic [L4_OUT_C -1:0][F_WIDTH -1 : 0] max_pool_x_out_pack ;
    logic [L4_OUT_C -1:0][F_WIDTH -1 : 0] max_pool_dx_out_pack;


    initial
    begin
        #1000;
        rstn <= 1'b1;
        new_event_x <= 16;
        new_event_y <= 16;
        for (int i = 1; i < 33; i++) begin
            last_layer_out_pack[i-1] <= i[7:0];
        end
        #50;
        module_start <= 1'b1;
        #10;
        module_start <= 1'b0;

        #1000;
        new_event_x <= 16;
        new_event_y <= 16;
        for (int i = 2; i < 33; i++) begin
            last_layer_out_pack[i-2] <= i[7:0];
        last_layer_out_pack[31] <= 8'b1;
        end
        #50;
        module_start <= 1'b1;
        #10;
        module_start <= 1'b0;

        #1000;
        event_stream_clean <= 1'b1;
        #10;
        event_stream_clean <= 1'b0;
        #10;
        new_event_x <= 1;
        new_event_y <= 1;
        for (int i = 0; i < 32; i++) begin
            last_layer_out_pack[i] <= i[7:0];
        end
        #50;
        module_start <= 1'b1;
        #10;
        module_start <= 1'b0;


    end
    always #(PERIOD/2)  clk=~clk;


    max_pool_x  u_max_pool_x (
        .clk                  ( clk                 ),
        .rstn                 ( rstn                ),
        .module_start         ( module_start        ),
        .event_stream_clean   ( event_stream_clean  ),
        // .new_event            ( new_event           ),
        .new_event_x            ( new_event_x           ),
        .new_event_y            ( new_event_y           ),
        .last_layer_out_pack  ( last_layer_out_pack ),

        .module_done          ( module_done         ),
        .grid_idx             ( grid_idx            ),
        .max_pool_x_out_pack  ( max_pool_x_out_pack ),
        .max_pool_dx_out_pack ( max_pool_dx_out_pack)
    );

endmodule