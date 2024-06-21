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

module linear_wrapper #(
    parameter PERIOD         = 10                ,
    parameter L4_OUT_C       = 32                ,
    parameter FC_OUT_C       = 2                 ,
    parameter MEM_INIT_FILE  = "test_fc_data.mem",
    parameter MAC_LATENCY    = 4,
    parameter F_WIDTH = 8,
    parameter FC_OUT_WIDTH = 32
) (


    // linear Inputs
    input wire clk                           ,
    input wire rstn                          ,
    input wire event_stream_clean            ,
    input wire module_start_long            ,
    input wire [5:0] grid_idx                 ,
    input wire [L4_OUT_C * F_WIDTH -1 : 0] max_pool_dx_out_pack,

    // linear Outputs
    output wire module_start_pulse ,
    output wire module_done                    ,
    output wire fc_out_valid                   ,
    output wire [FC_OUT_C * FC_OUT_WIDTH -1 : 0] fc_out_pack
);

    reg module_start_long_reg;
    reg module_start;
    always @ (posedge clk) begin
        if (!rstn || event_stream_clean) begin
            module_start_long_reg <= 1'b0;
            module_start <= 1'b0;
        end
        else begin
            module_start_long_reg <= module_start_long;
            module_start <= ({module_start_long_reg, module_start_long}==2'b01);
        end
    end
    assign module_start_pulse = module_start;



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