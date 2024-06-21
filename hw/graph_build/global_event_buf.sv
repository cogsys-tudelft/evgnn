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


module global_event_buf #(
    parameter int READ_LATENCY = 2,  // TODO: 实际检查一下uram时序
    parameter int WRITE_LATENCY = 1
)(
    input pixel_idx_t pixel_idx,
    input logic       clk,
    input logic       rstn,
    input logic       clean,
    input logic       en,
    input logic       wr_rdn,  // 1 = write, 0 = read
    input event_s    din,
    output event_s  dout [MAX_DEGREE],
    output logic    dout_valid
);
    event_s    local_buffer [MAX_DEGREE + 1];
    logic write_en;
    logic read_en;
    assign write_en = en & wr_rdn;
    assign read_en  = en & (~wr_rdn);

    always @ (posedge clk) begin
        for (int j = 0 ; j < MAX_DEGREE; j++) begin
            if (!rstn) begin
                dout[j] <= '0;
            end
            else begin
                dout[j] <= local_buffer[j];
            end
        end
    end

    assign local_buffer[MAX_DEGREE] = din;

    generate
        for (genvar i = 0; i < MAX_DEGREE; i++) begin
            uram_xpm #(
                .READ_LATENCY(READ_LATENCY)
            ) uram_xpm_inst (
                .clk(clk),
                .en(en),
                .rstn(rstn),
                .we(wr_rdn),
                .addr(pixel_idx),
                .din((local_buffer[i + 1] & {URAM_WIDTH{~clean}})),  // if clean, all set to 0; else, just normal
                .dout(local_buffer[i])
            );
        end
    endgenerate

    //  if read_en = 0->1, after READ_LATENCY, dout_valid = 1; if read_en = 1->0, after 1clk, dout_valid = 0
    // logic [READ_LATENCY -1:0] dout_valid_delay ;
    // always_ff @ (posedge clk) begin
    //     if (!rstn) begin
    //         dout_valid <= 'b0;
    //         for (int i = 0; i < READ_LATENCY; i++) begin
    //             dout_valid_delay[i] <= 'b0;
    //         end
    //     end
    //     else begin
    //         dout_valid_delay[0] <= read_en;
    //         for (int i = 0; i < (READ_LATENCY -1); i++) begin
    //             dout_valid_delay[i + 1] <= dout_valid_delay[i];
    //         end
    //         dout_valid <= dout_valid_delay[READ_LATENCY-1] & read_en;
    //     end
    // end

    typedef enum { IDLE, READ_WAIT, OUT_RISE, OUT_HOLD } fsm_dout_valid_e;
    fsm_dout_valid_e state;
    logic [$clog2(READ_LATENCY) -1:0] read_wait_cnt;

    always @ (posedge clk) begin
        if (!rstn) begin
            state <= IDLE;
            read_wait_cnt <= '0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (read_en) begin
                        state <= READ_WAIT;
                    end
                    else begin
                        state <= IDLE;
                        read_wait_cnt <= '0;
                    end
                end
                READ_WAIT: begin
                    if (read_en) begin
                        if (read_wait_cnt < (READ_LATENCY-1)) begin
                            read_wait_cnt <= read_wait_cnt + 1'd1;
                            state <= READ_WAIT;
                        end
                        else begin
                            read_wait_cnt <= '0;
                            state <= OUT_RISE;
                        end
                    end
                    else begin
                        state <= IDLE;
                        read_wait_cnt <= '0;
                    end
                end
                OUT_RISE: begin
                    if (read_en) begin
                        state <= OUT_HOLD;
                    end
                    else begin
                        state <= IDLE;
                        read_wait_cnt <= '0;
                    end
                end
                OUT_HOLD: begin
                    state <= IDLE;
                    read_wait_cnt <= '0;
                end
                default: begin
                    state <= IDLE;
                    read_wait_cnt <= '0;
                end
            endcase
        end
    end

    always_comb begin
        case (state)
            OUT_RISE, OUT_HOLD:
                dout_valid = 1'b1;
            default:
                dout_valid = 1'b0;
        endcase
    end


endmodule
