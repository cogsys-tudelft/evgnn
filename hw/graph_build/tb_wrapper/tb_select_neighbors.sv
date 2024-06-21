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

module tb_select_neighbors;

    parameter int WIDTH = 48;  //TODO: 想一想到底写什么
    parameter int DATA_COUNT_WIDTH = $clog2(MAX_DEGREE) + 1;


    logic clk;
    logic rstn;

    logic local_buffer_valid;
    event_s local_buffer      [MAX_DEGREE];

    time_t t_now;

    logic                        fifo_wr_en;
    logic [         WIDTH-1 : 0] fifo_din;
    logic                        fifo_full;

    initial begin
        clk <= 1'b0;
        rstn <= 1'b0;
        local_buffer_valid <= 'b0;
        for (int i = 0; i < MAX_DEGREE; i++) begin
            local_buffer[i] <= '0;
        end

        #7;
        rstn <= 1'b1;
        t_now <= 'd65536;
        fifo_full <= 'b0;

        #10;
        local_buffer_valid <= 'd1;
        local_buffer[13].valid <= 'b1;
        local_buffer[13].t <= 'd0;
        local_buffer[14].valid <= 'b1;
        local_buffer[14].t <= 'd1;
        local_buffer[15].valid <= 'b1;
        local_buffer[15].t <= 'd65534;

        #15;
        fifo_full <= 'b1;

    end

    always #5 clk = ~clk;


    select_neighbors select_neighbors_inst(
        // ports
        clk,
        rstn,

        local_buffer_valid,
        local_buffer ,

        t_now,

        // global_neighbor_buffer FIFO Write group
        fifo_wr_en,
        fifo_din,
        fifo_full
    );

endmodule