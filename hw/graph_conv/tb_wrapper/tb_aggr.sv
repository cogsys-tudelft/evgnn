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

module tb_aggr;

    // aggr Parameters
    parameter PERIOD         = 10                  ;
    parameter OUT_C          = 32                  ;
    parameter M              = 12345               ;
    parameter NM             = 20                  ;
    parameter MEM_INIT_FILE  = "test_bias_data.mem";

    // aggr Inputs
    logic clk                            = 0 ;
    logic rstn                           = 0 ;
    logic is_neighbor                    = 0 ;
    logic no_neighbor                    = 0 ;
    logic clean                          = 0 ;
    logic [OUT_C * B_WIDTH -1 : 0] accum_out_pack = 0 ;
    logic accum_out_valid                = 0 ;

    // aggr Outputs
    logic [OUT_C * B_WIDTH -1 : 0] aggr_pack ;
    logic aggr_valid                     ;


    accum_t ag = 0;
    accum_t ac = 0;
    accum_t max_out;
    function accum_t max (accum_t ag, accum_t ac);
        accum_t max_one;
        max_one = ($signed(ag) >= $signed(ac))? ag : ac;
        return max_one;
    endfunction
    assign max_out = max(ag, ac);


    initial
    begin
        #2000;
        rstn <= 1'b1;
        ag <= (-1);
        ac <= (-2);

        #10;
        ag <= 'h8000_0000;
        ac <= 'h8000_0001;

        #10;
        ag <= 'h7fff_ffff;
        ac <= 'h8000_0000;

        #10;
        ag <= 2;
        ac <= 'h7fff_ffff;

        #10;
        ag <= 'hffff_ffff;
        ac <= 0;

        #10;
        ag <= 'hdead_beef;
        ac <= (-1);
    end

    always #(PERIOD/2)  clk=~clk;

    aggr #(
        .OUT_C         ( OUT_C         ),
        .M             ( M             ),
        .NM            ( NM            ),
        .MEM_INIT_FILE ( MEM_INIT_FILE ))
    u_aggr (
        .clk                ( clk              ),
        .rstn               ( rstn             ),
        .is_neighbor        ( is_neighbor      ),
        .no_neighbor        ( no_neighbor      ),
        .clean              ( clean            ),
        .accum_out_pack     ( accum_out_pack   ),
        .accum_out_valid    ( accum_out_valid  ),

        .aggr_pack          ( aggr_pack        ),
        .aggr_valid         ( aggr_valid       )
    );

endmodule