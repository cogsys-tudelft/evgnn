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

module tb_neighbor_pixels;

    logic                                   clk;
    logic                                   rstn;
    x_idx_t                                 x;
    y_idx_t                                 y;
    logic signed [$clog2(TOT_PIXEL)+2 -1:0] neighbor_pixels[MAX_DS_RANGE];

    initial begin
        clk <= 'b0;
        rstn <= 'b0;
        x <= '0;
        y <= '0;

        #10;
        rstn <= 'b1;

        #10;
        x <= 'd12;
        y <= 'd25;

        #10;
        x <= 'd119;
        y <= 'd99;

        #10;
        x <= 'd119;
        y <= 'd10;

        #10;
        x <= 'd10;
        y <= 'd99;

        #10;
        x <= 'd120;
        y <= 'd99;

        #10;
        x <= 'd119;
        y <= 'd100;


    end

    always #5 clk = ~clk;

    get_neighbor_pixels get_neighbor_pixels_inst(.*);

endmodule
