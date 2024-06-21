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

// inst fifo module at top.sv
module select_neighbors #(
    parameter int WIDTH = 72,  //TODO: 想一想到底写什么
    parameter int DATA_COUNT_WIDTH = $clog2(MAX_DEGREE) + 1
    // localparam
) (
    // ports
    input  logic clk,
    input  logic rstn,

    input  logic   local_buffer_valid,
    input  event_s local_buffer [MAX_DEGREE],
    output logic   select_neighbors_ready,
    output logic   select_neighbors_done,

    input  time_t t_now,

    // global_neighbor_buffer FIFO Write group
    output logic               fifo_wr_en,
    output logic [WIDTH-1 : 0] fifo_din,
    input  logic               fifo_full
    // input  logic               fifo_wr_ack
    // input  logic                        fifo_overflow,
    // input  logic [DATA_COUNT_WIDTH-1:0] fifo_wr_data_count,
    // input  logic                        fifo_wr_rst_busy
);
    typedef enum {
        IDLE,
        FIFO_WRITE,
        DONE
    } fsm_states_e;

    //                                                                                       if full -> stop the whole graph_build
    // t_now  with  ts_old  -> dts  -> if dts<Maxdt -> take these data -> if global_fifo is not full -> push into global_fifo -> stop graph_build
    //                                 if dts>=Maxdt or data.valid==0 -> ignore them

    time_t                   dt [MAX_DEGREE];  // since t_now >= ts_old, so this dt buffer is always unsigned
    logic  [MAX_DEGREE -1:0] within_max_dt;
    logic  [MAX_DEGREE -1:0] is_neighbor;

    generate
        for (genvar i = 0; i < MAX_DEGREE; i++) begin
            assign dt[i]            = t_now - local_buffer[i].t;
            assign within_max_dt[i] = (dt[i] <= MAX_DT) ? 1'b1 : 1'b0;
            assign is_neighbor[i]   = local_buffer[i].valid & within_max_dt[i];
        end
    endgenerate

    logic has_neighbor;
    assign has_neighbor = |is_neighbor;

    logic        [$clog2(MAX_DEGREE) -1:0] buffer_idx;
    fsm_states_e                           state;
    // Describe state transition
    always @(posedge clk) begin
        if (!rstn) begin
            state      <= IDLE;
            buffer_idx <= (MAX_DEGREE-1);
        end
        else begin
            case (state)
                IDLE: begin
                    if (local_buffer_valid) begin
                        if ((has_neighbor) && (!fifo_full))  // if the neighbor pixel has a real time-space neighbor w.r.t. new_event, and the fifo is not full
                            state <= FIFO_WRITE;
                        else
                            state <= DONE;
                    end
                    else
                        state <= IDLE;
                end
                FIFO_WRITE: begin
                    if ((buffer_idx == 'd0) || (fifo_full) || (!is_neighbor[buffer_idx]))  // if read out all buffer / fifo is full / the remaining neighbors is not within the certain time-space distance
                        state <= DONE;
                    else begin
                        buffer_idx <= buffer_idx - 'd1;  // inverse counter: older the event, smaller the idx, but we want to take the most recent events into the FIFO.
                        state      <= FIFO_WRITE;
                    end
                end
                DONE: begin
                    state      <= IDLE;
                    buffer_idx <= (MAX_DEGREE-1);
                end
                default: state <= IDLE;
            endcase
        end
    end

    // Describe state action
    always_comb begin
        if ((state == FIFO_WRITE) && (is_neighbor[buffer_idx])) begin
            fifo_wr_en = 'b1;
            fifo_din   = local_buffer[buffer_idx];  //TODO: 想一想到底写什么， 至少应该有p
        end
        else begin
            fifo_wr_en = '0;
            fifo_din   = '0;
        end
    end

    always_comb begin
        if ((state == FIFO_WRITE) || (state == DONE)) begin
            select_neighbors_ready = 'b0;
        end
        else begin
            select_neighbors_ready = 'b1;
        end
    end

    always_comb begin
        if (state == DONE) begin
            select_neighbors_done = 'b1;
        end
        else begin
            select_neighbors_done = 'b0;
        end
    end

endmodule
