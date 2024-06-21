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

module tb_top_bd;

    logic clk = 0;
    logic rstn = 0;
    logic ip_en = 0;
    logic ip_clean = 0;
    event_s new_event = 0;

    logic ip_done;
    logic ip_idle;
    logic ip_clear;
    logic prediction;
    logic [1:0][31:0]fc_out_pack;

    integer base_addr = 32'h1000_0000;
    integer offset = 32'h0000_0080;
    integer e_idx = 0;

    task automatic gen_tb_data(
        ref event_s new_event,
        input integer x,
        input integer y,
        input integer e_idx,
        input logic p,
        ref ip_en,
        ref ip_done
    );
        new_event.x = x[X_PIXEL_WIDTH-1:0];
        new_event.y = y[Y_PIXEL_WIDTH-1:0];
        new_event.p = p;
        new_event.t = e_idx[T_WIDTH-1:0];
        new_event.addr = (base_addr + e_idx*offset);

        #10 ip_en = 1;
        @ (posedge ip_done);
        #50 ip_en = 0;
    endtask //automatic

    initial begin
        #2000;
        rstn <= 1;

        /*
        #50;
        new_event.valid <= 'b1;
        new_event.x <= 'd16;
        new_event.y <= 'd16;
        new_event.p <= 'b1;
        new_event.t <= 'd0;
        new_event.addr <= 32'h1000_0000;
        // results should be: 0000143d, ffffebc3
        // new: 1637, -1664

        #10;
        ip_en <= 1;

        @ (posedge ip_done);
        #50;
        ip_en <= 0;

        new_event.x <= 'd17;
        new_event.y <= 'd17;
        new_event.p <= 'b1;
        new_event.t <= 'd10;
        new_event.addr <= 32'h1000_0080;
        // results should be: 00001a58, ffffe328
        // new: 1609, -1640


        #10;
        ip_en <= 1;

        @ (posedge ip_done);
        #50;
        ip_en <= 0;

        new_event.x <= 'd16;
        new_event.y <= 'd16;
        new_event.p <= 'b0;
        new_event.t <= 'd20;
        new_event.addr <= 32'h1000_0100;
        // results should be: 00001bd9, ffffe107
        // new: 2625, -2649


        #10;
        ip_en <= 1;

        @ (posedge ip_done);
        #50;
        ip_en <= 0;
        */

        new_event.valid = 'b1;
        // new_event.x = 'd0;
        // new_event.y = 'd0;
        // new_event.p = 'b1;

        #50;
        // gen_tb_data(new_event,  0, ip_en, ip_done);
        // gen_tb_data(new_event,  1, ip_en, ip_done);
        // gen_tb_data(new_event,  2, ip_en, ip_done);
        // gen_tb_data(new_event,  3, ip_en, ip_done);
        // gen_tb_data(new_event,  4, ip_en, ip_done);
        // gen_tb_data(new_event,  5, ip_en, ip_done);
        // gen_tb_data(new_event,  6, ip_en, ip_done);
        // gen_tb_data(new_event,  7, ip_en, ip_done);
        // gen_tb_data(new_event,  8, ip_en, ip_done);
        // gen_tb_data(new_event,  9, ip_en, ip_done);
        // gen_tb_data(new_event, 10, ip_en, ip_done);
        // gen_tb_data(new_event, 11, ip_en, ip_done);
        // gen_tb_data(new_event, 12, ip_en, ip_done);
        // gen_tb_data(new_event, 13, ip_en, ip_done);
        // gen_tb_data(new_event, 14, ip_en, ip_done);
        // gen_tb_data(new_event, 15, ip_en, ip_done);
        // gen_tb_data(new_event, 16, ip_en, ip_done);
        // gen_tb_data(new_event, 17, ip_en, ip_done);
        // gen_tb_data(new_event, 18, ip_en, ip_done);
        // gen_tb_data(new_event, 19, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), ( 0 +10),   0, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), ( 1 +10),   1, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), ( 0 +10),   2, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), (-1 +10),   3, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), ( 0 +10),   4, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), ( 1 +10),   5, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), ( 2 +10),   6, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), ( 1 +10),   7, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-2 +10), ( 0 +10),   8, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), (-1 +10),   9, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), (-2 +10),  10, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), (-1 +10),  11, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 2 +10), ( 0 +10),  12, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 2 +10), ( 1 +10),  13, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), ( 2 +10),  14, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), ( 3 +10),  15, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), ( 2 +10),  16, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-2 +10), ( 1 +10),  17, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-3 +10), ( 0 +10),  18, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-2 +10), (-1 +10),  19, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), (-2 +10),  20, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), (-3 +10),  21, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), (-2 +10),  22, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 2 +10), (-1 +10),  23, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 3 +10), ( 0 +10),  24, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), ( 0 +10),  25, 1, ip_en, ip_done);

        #1500 ip_clean = 1;
        @ (posedge ip_clear);
        #10 ip_clean = 0;
        #10;
        gen_tb_data(new_event, ( 0 +10), ( 0 +10),   0, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), ( 1 +10),   1, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), ( 0 +10),   2, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), (-1 +10),   3, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), ( 0 +10),   4, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), ( 1 +10),   5, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), ( 2 +10),   6, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), ( 1 +10),   7, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-2 +10), ( 0 +10),   8, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), (-1 +10),   9, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), (-2 +10),  10, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), (-1 +10),  11, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 2 +10), ( 0 +10),  12, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 2 +10), ( 1 +10),  13, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), ( 2 +10),  14, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), ( 3 +10),  15, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), ( 2 +10),  16, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-2 +10), ( 1 +10),  17, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-3 +10), ( 0 +10),  18, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-2 +10), (-1 +10),  19, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), (-2 +10),  20, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), (-3 +10),  21, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), (-2 +10),  22, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 2 +10), (-1 +10),  23, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 3 +10), ( 0 +10),  24, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), ( 0 +10),  25, 1, ip_en, ip_done);

        #1500 ip_clean = 1;
        @ (posedge ip_clear);
        #10 ip_clean = 0;
        #10;
        gen_tb_data(new_event, ( 0 +10), ( 0 +10),   0, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), ( 1 +10),   1, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), ( 0 +10),   2, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), (-1 +10),   3, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), ( 0 +10),   4, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), ( 1 +10),   5, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), ( 2 +10),   6, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), ( 1 +10),   7, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-2 +10), ( 0 +10),   8, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), (-1 +10),   9, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), (-2 +10),  10, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), (-1 +10),  11, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 2 +10), ( 0 +10),  12, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 2 +10), ( 1 +10),  13, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), ( 2 +10),  14, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), ( 3 +10),  15, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), ( 2 +10),  16, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-2 +10), ( 1 +10),  17, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-3 +10), ( 0 +10),  18, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-2 +10), (-1 +10),  19, 1, ip_en, ip_done);
        gen_tb_data(new_event, (-1 +10), (-2 +10),  20, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), (-3 +10),  21, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 1 +10), (-2 +10),  22, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 2 +10), (-1 +10),  23, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 3 +10), ( 0 +10),  24, 1, ip_en, ip_done);
        gen_tb_data(new_event, ( 0 +10), ( 0 +10),  25, 1, ip_en, ip_done);




    end

    always #5 clk = ~clk;



    top_bd_wrapper top_bd_wrapper_inst (
        .clk,
        .fc_out_pack,
        .ip_clean,
        .ip_done,
        .ip_clear,
        .ip_en,
        .ip_idle,
        .new_event,
        .prediction,
        .rstn
    );

endmodule