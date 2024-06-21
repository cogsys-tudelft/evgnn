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

module max_pool_x #(
    localparam integer L4_OUT_C = 32
) (
    input logic clk,
    input logic rstn,
    input logic module_start,
    input logic event_stream_clean,
    output logic module_done,

    // input event_s new_event,
    input x_idx_t new_event_x,
    input y_idx_t new_event_y,
    input logic [L4_OUT_C * F_WIDTH -1 : 0] last_layer_out_pack,
    output grid_idx_t grid_idx,
    output logic [L4_OUT_C * F_WIDTH -1 : 0] max_pool_x_out_pack,
    output logic [L4_OUT_C * F_WIDTH -1 : 0] max_pool_dx_out_pack
);

    // grid_idx = (x_idx / GRID_LENGTH) + [(y_idx / GRID_HEIGHT) * GRID_X]
    function grid_idx_t get_grid_idx(input x_idx_t x_idx, y_idx_t y_idx);
        return (x_idx >> $clog2(GRID_LENGTH)) + ((y_idx >> $clog2(GRID_HEIGHT)) << $clog2(GRID_X));
    endfunction

    function f_t max (f_t ag, f_t ac);
        f_t max_one;
        max_one = (ag >= ac)? ag : ac;
        return max_one;
    endfunction

    always @ (posedge clk) begin
        if (!rstn || event_stream_clean) begin
            grid_idx <= 0;
        end
        else begin  // get grid idx doesn't need to wait for module_start
            grid_idx <= get_grid_idx(new_event_x, new_event_y);
        end
    end

    typedef enum { IDLE, READ, COMPARE, WRITE, DONE } maxp_fsm_e;
    maxp_fsm_e state;
    always @ (posedge clk) begin
        if (!rstn || event_stream_clean)
            state <= IDLE;
        else begin
            case (state)
                IDLE:
                    if (module_start)
                        state <= READ;
                READ:
                    state <= COMPARE;
                COMPARE:
                    state <= WRITE;
                WRITE:
                    state <= DONE;
                DONE:
                    state <= IDLE;
                default:
                    state <= IDLE;
            endcase
        end
    end

    logic rd_en;
    logic wr_en;
    logic compare;
    assign rd_en = (state == READ);
    assign wr_en = (state == WRITE);
    assign compare = (state == COMPARE);
    assign module_done = (state == DONE);

    (* ram_style = "block" *) logic [L4_OUT_C * F_WIDTH -1 : 0] max_history_mem [0 : GRID_NUM -1];
    logic [GRID_NUM -1 : 0] max_history_mem_valid;
    logic [L4_OUT_C * F_WIDTH -1 : 0] max_history;

    always @ (posedge clk) begin
        if (!rstn || event_stream_clean)
            max_history <= '0;
        else begin
            if (rd_en)
                max_history <= max_history_mem[grid_idx];
            else if (wr_en)
                max_history_mem[grid_idx] <= max_pool_x_out_pack;
        end
    end

    always @(posedge clk) begin
        if (!rstn || event_stream_clean) begin
            max_pool_x_out_pack <= '0;
        end
        else begin
            if (compare) begin
                if (max_history_mem_valid[grid_idx] == 1'b0) begin  // this is a new mem entry
                    max_pool_x_out_pack <= last_layer_out_pack;
                end
                else begin
                    for (int i = 0 ; i < L4_OUT_C; i++) begin
                        max_pool_x_out_pack[(i+1)*F_WIDTH -1 -: F_WIDTH] <= max(max_history[(i+1)*F_WIDTH -1 -: F_WIDTH], last_layer_out_pack[(i+1)*F_WIDTH -1 -: F_WIDTH]);
                    end
                end
            end
        end
    end

    always @(posedge clk) begin
        if (!rstn || event_stream_clean) begin
            max_pool_dx_out_pack <= '0;
            max_history_mem_valid <= '0;
        end
        else begin
            if (wr_en) begin  // at the next state of COMPARE, happens to be WRITE state
                if (max_history_mem_valid[grid_idx] == 1'b0) begin  // this is a new mem entry
                    max_history_mem_valid[grid_idx] <= 1'b1;
                    max_pool_dx_out_pack <= max_pool_x_out_pack;  // Regard max_history[:] = [0]
                end
                else begin
                    // Since max_pool_x[:] = max(max_history[:], last_layer_out[:]),
                    // max_pool_x[:] >= max_history[:],
                    // so, max_pool_dx[:] = max_pool_x[:] - max_history[:] >= 0;
                    for (int i = 0 ; i < L4_OUT_C; i++) begin
                        max_pool_dx_out_pack[(i+1)*F_WIDTH -1 -: F_WIDTH] <=
                        max_pool_x_out_pack[(i+1)*F_WIDTH -1 -: F_WIDTH]
                        - max_history[(i+1)*F_WIDTH -1 -: F_WIDTH];
                    end
                end
            end
        end
    end

endmodule