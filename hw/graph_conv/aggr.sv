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

module aggr #(
    parameter integer        OUT_C = 32
) (
    input logic clk,
    input logic rstn,
    input logic is_neighbor,  // indicate a neighbor comes
    input logic no_neighbor,  // indicate no future neighbor will come
    input logic clean,        // indicate the whole graph conv of this event is finish, clean for next event
    input logic [OUT_C * B_WIDTH -1 : 0] accum_out_pack,  // Here, the aggregation is "max"
    input logic accum_out_valid,
    output logic [OUT_C * B_WIDTH -1 : 0] aggr_pack,
    output logic aggr_valid
);

    // Constant. Min val of a B_WIDTH signed number
    accum_t min_val;
    assign min_val[B_WIDTH -1] = 1'b1;
    assign min_val[B_WIDTH -2:0] = '0;

    // Handy signals
    logic [OUT_C -1 : 0][B_WIDTH -1 : 0] accum_out;
    logic [OUT_C -1 : 0][B_WIDTH -1 : 0] aggr;
    generate
        for (genvar i = 0; i < OUT_C; i++) begin
            assign accum_out[i] = accum_out_pack[(i+1)*B_WIDTH -1 -: B_WIDTH];
            assign aggr_pack[(i+1)*B_WIDTH -1 -: B_WIDTH] = aggr[i];
        end
    endgenerate

    // FSM
    typedef enum { IDLE, PASS_THROUGH, COMPARE, OUTPUT, CLEAN } fsm_e;
    fsm_e state;

    // FSM state transition
    always @ (posedge clk) begin
        if (!rstn) begin
            state <= IDLE;
        end
        else begin
            case (state)
                IDLE: begin
                    if (is_neighbor)       // if a real neighbor comes
                        state <= COMPARE;
                    else if (no_neighbor)  // if no neighbor at all (fifo_empty at the beginning)
                        state <= PASS_THROUGH;
                    else
                        state <= IDLE;
                end
                PASS_THROUGH: begin
                    if (clean)
                        state <= CLEAN;
                    else
                        state <= PASS_THROUGH;
                end
                COMPARE: begin
                    if (no_neighbor)       // if no more neighbors (fifo_empty)
                        state <= OUTPUT;
                    else
                        state <= COMPARE;
                end
                OUTPUT:
                    if (clean)
                        state <= CLEAN;
                    else
                        state <= OUTPUT;
                CLEAN:                  // 1 clk for aggr to recover back to min_val
                    state <= IDLE;
                default:
                    state <= IDLE;
            endcase
        end
    end

    // FSM actions
    always_comb begin
        if ((state == OUTPUT) || (state == PASS_THROUGH))
            aggr_valid = 1'b1;
        else
            aggr_valid = 1'b0;
    end

    // TODO
    function accum_t max (accum_t ag, accum_t ac);
        accum_t max_one;
        max_one = ($signed(ag) >= $signed(ac))? ag : ac;
        return max_one;
    endfunction

    generate
        for (genvar j = 0; j < OUT_C; j++) begin

            always @ (posedge clk) begin
                if (!rstn) begin
                    aggr[j] <= min_val;
                end
                else begin
                    case (state)
                        IDLE: begin
                            if (no_neighbor)  // <=> next_state == PASS_THROUGH
                                aggr[j] <= '0;
                            else
                                aggr[j] <= min_val;
                        end
                        COMPARE:
                            if (accum_out_valid) begin
                                aggr[j] <= max(aggr[j], accum_out[j]);
                            end
                            else
                                aggr[j] <= aggr[j];
                        CLEAN:
                            aggr[j] <= min_val;
                        default:
                            aggr[j] <= aggr[j];
                    endcase
                end
            end

        end
    endgenerate





endmodule