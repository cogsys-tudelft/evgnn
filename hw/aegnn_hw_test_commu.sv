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

module aegnn_hw_test_commu #(
    parameter FC_OUT_C = 2
) (
    input  logic clk,
    input  logic rstn,

    input  logic ip_en,
    input  logic ip_clean,
    input  event_s new_event,

    output logic ip_idle,
    output logic ip_done,
    output logic prediction,
    output logic [FC_OUT_C * FC_OUT_WIDTH -1:0] FC_out
);

    logic valid;
    logic p;
    x_idx_t x;
    y_idx_t y;
    time_t  t;
    mem_addr_t addr;

    assign valid = new_event.valid;
    assign p = new_event.p;
    assign x = new_event.x;
    assign y = new_event.y;
    assign t = new_event.t;
    assign addr = new_event.addr;

    typedef enum { IDLE, CLEAN, PROC1, PROC2, DONE } test_fsm_e;
    test_fsm_e state;

    always @ (posedge clk) begin
        if (!rstn)
            state <= IDLE;
        else begin
            case (state)
                IDLE: begin
                    if (ip_en)
                        state <= PROC1;
                    if (ip_clean)
                        state <= CLEAN;
                end
                CLEAN:
                    if (!ip_clean)
                        state <= IDLE;
                PROC1:
                    state <= PROC2;
                PROC2:
                    state <= DONE;
                DONE:
                    if (!ip_en)
                        state <= IDLE;
                default:
                    state <= IDLE;
            endcase
        end
    end

    assign ip_idle = (state == IDLE);
    assign ip_done = (state == DONE);

    assign prediction = 1'b1;
    assign FC_out = 64'h0A0B0C0D_DEADBEEF;


endmodule