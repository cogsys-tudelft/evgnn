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
`timescale 1ns / 1ps

// Assume that this is the true IP
module dummy_test_ip #(
    parameter [31:0] TEST_ADDR = 32'h1000_0000
)(
    input wire clk,
    input wire rstn,

    input wire test_start,
    output reg test_done,
    output reg [1:0] check_error, // 00: wait checking; 01: OK; 11: error

    output reg           wr_en,
    input  wire          wr_done,
    output reg  [  31:0] wr_addr,
    output reg  [1023:0] wr_buffer,

    output reg           rd_en,
    input  wire          rd_done,
    output reg  [  31:0] rd_addr,
    input  wire [1023:0] rd_buffer
);

    localparam INTERVAL_WAIT  = 10;  // insert 10 clk waiting between write and read
    localparam [3:0] IDLE     = 'd0,
                     WRITE    = 'd1,
                     INTERVAL = 'd2,
                     READ     = 'd3,
                     CHECK    = 'd4,
                     DONE     = 'd5;  // FSM states

    reg [3:0] state;

    wire [1023:0] test_data;
    assign test_data[128*1 -1 -: 128] = 128'hDEADBEEF_11111111_11111111_11111111;
    assign test_data[128*2 -1 -: 128] = 128'hDEADdead_22222222_22222222_22222222;
    assign test_data[128*3 -1 -: 128] = 128'hbeefBEEF_33333333_33333333_33333333;
    assign test_data[128*4 -1 -: 128] = 128'h0ABC0DEF_44444444_44444444_44444444;
    assign test_data[128*5 -1 -: 128] = 128'hBEEFDEAD_55555555_55555555_55555555;
    assign test_data[128*6 -1 -: 128] = 128'hbeefBEEF_66666666_66666666_66666666;
    assign test_data[128*7 -1 -: 128] = 128'hDEADdead_77777777_77777777_77777777;
    assign test_data[128*8 -1 -: 128] = 128'hFED0CBA0_88888888_88888888_88888888;

    reg [1023:0] store_rd_buffer;

    reg [3:0] interval_wait_cnt;
    // FSM state transition
    always @ (posedge clk) begin
        if(!rstn) begin
            state <= IDLE;
            interval_wait_cnt <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (test_start)
                        state <= WRITE;
                    else
                        state <= IDLE;
                end
                WRITE: begin
                    if (wr_done)
                        state <= INTERVAL;
                    else
                        state <= WRITE;
                end
                INTERVAL: begin
                    if (interval_wait_cnt < INTERVAL_WAIT - 1) begin
                        interval_wait_cnt <= interval_wait_cnt + 1;
                        state <= INTERVAL;
                    end
                    else begin
                        interval_wait_cnt <= 0;
                        state <= READ;
                    end
                end
                READ: begin
                    if (rd_done)
                        state <= CHECK;
                    else
                        state <= READ;
                end
                CHECK: begin
                    state <= DONE;
                end
                DONE: begin
                    state <= IDLE;
                    interval_wait_cnt <= 0;
                end
                default: begin
                    state <= IDLE;
                    interval_wait_cnt <= 0;
                end
            endcase
        end
    end

    // FSM action

    // generate write logic
    always @ (*) begin
        if (state == WRITE) begin
            wr_en = 1'b1;
            wr_addr = TEST_ADDR;
            wr_buffer = test_data;
        end
        else begin
            wr_en = 1'b0;
            wr_addr = 0;
            wr_buffer = 0;
        end
    end

    // generate read logic
    always @ (*) begin
        if (state == READ) begin
            rd_en = 1'b1;
            rd_addr = TEST_ADDR;
        end
        else begin
            rd_en = 1'b0;
            rd_addr = 0;
        end
    end

    // store read buffer for checking
    always @ (posedge clk) begin
        if (!rstn) begin
            store_rd_buffer <= 0;
        end
        else begin
            if ((state == READ) && (rd_done))
                store_rd_buffer <= rd_buffer;
        end
    end

    // checking
    always @ (posedge clk) begin
        if (!rstn) begin
            check_error <= 2'b00;
        end
        else begin
            if (state == CHECK) begin
                check_error[0] <= 1'b1;
                if (store_rd_buffer != test_data)
                    check_error[1] <= 1'b1;
                else
                    check_error[1] <= 1'b0;
            end
            else begin
                check_error <= 2'b00;
            end
        end
    end

    // done signal
    always @ (*) begin
        if (state == DONE) begin
            test_done = 1'b1;
        end
        else begin
            test_done = 1'b0;
        end
    end



endmodule
