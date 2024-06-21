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
//`include "global_event_buf.sv"
import aegnn::*;

module tb_glb_buf;

    // pixel_idx_t pixel_idx;
    logic [$clog2(12000)-1:0] pixel_idx;
    logic       clk;
    logic       rstn;
    logic       en;
    logic       wr_rdn;  // 1 = write, 0 = read
    // event_s    din;
    // event_s [MAX_DEGREE -1 : 0] dout;
    logic [72-1:0] din;
    logic [16*72-1:0] dout;


    initial begin
        pixel_idx <= '0;
        clk <= 'b0;
        rstn <= 'b0;
        en  <= 'b0;
        wr_rdn <= 'b0;


        #13;
        rstn <= 'b1;

        #4;
        en <= 'b1;

        #7;
        wr_rdn <= 'b1;
        din <= 'hDEAD_BEEF_DEAD_BEEF;


        #10;
        din <= 'h0000_BEEF_0000_BEEF;

        #10;
        din <= 'hDEAD_0000_DEAD_0000;

        #10;
        wr_rdn <= 'b0;

        #20;
        wr_rdn <= 'b1;

        // #10;
        // wr_rdn <= 'b0;

        // #10;
        // wr_rdn <= 'b1;

        // #10;
        // wr_rdn <= 'b0;

    end

    always #5 clk = ~clk;

    // global_event_buf global_event_buf(.*);
    glb_buf_wrapper glb_buf_wrapper_inst(.*);

endmodule