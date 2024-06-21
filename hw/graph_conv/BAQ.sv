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

module bias_act_quant #(
    parameter integer        OUT_C = 32,
    parameter [M_WIDTH -1:0] M     = 12345,  // quant scaling factor
    parameter integer        NM    = 20,     // quant scaling right shifting bits
    parameter                MEM_INIT_FILE = "test_bias_data.mem"
) (
    input  logic                          clk,
    input  logic                          rstn,
    input  logic [OUT_C * B_WIDTH -1 : 0] aggr_pack,  // Here, the aggregation is "max"
    input  logic                          aggr_valid,
    output logic [OUT_C * F_WIDTH -1 : 0] conv_out_pack,
    output logic                          conv_out_valid
);

    // Define bias vector
    bias_t bias [0 : OUT_C-1];
    initial begin
        $readmemh(MEM_INIT_FILE, bias);
    end

    generate
        for (genvar out_c_idx = 0; out_c_idx < OUT_C; out_c_idx++) begin

            accum_t aggr;
            assign aggr = aggr_pack[(out_c_idx+1)*B_WIDTH -1 -: B_WIDTH];

            logic signed [B_WIDTH+1         -1 : 0] psum;
            logic signed [B_WIDTH+M_WIDTH+1 -1 : 0] psum_scaled;
            logic signed [B_WIDTH+M_WIDTH+1 -1 : 0] psum_shifted;
            f_t   conv_out;

            always @ (posedge clk) begin
                if (!rstn) begin
                    psum <= '0;
                    psum_scaled <= '0;
                    psum_shifted <= '0;
                    conv_out <= '0;
                end
                else begin
                    if (aggr_valid) begin
                        // Add bias
                        psum <= $signed(aggr) + $signed(bias[out_c_idx]);
                        // Quant scaling
                        psum_scaled <= $signed(psum) * $signed({1'b0, M});
                        psum_shifted <= (psum_scaled >>> NM);  // After scaling and shifting, normal psum_shifted should be at [-255,255]
                        // ReLU and clamp
                        conv_out <= (psum_shifted[B_WIDTH+M_WIDTH-1] == 1'b1)? 8'd0   :  // psum_shifted < 0, relu
                                    ($signed(psum_shifted) > 255)?             8'd255 :  // psum_shifted > 255, clamp
                                                                            psum_shifted[F_WIDTH -1:0];
                    end
                end
            end

            assign conv_out_pack[(out_c_idx+1)*F_WIDTH -1 -: F_WIDTH] = conv_out;

        end
    endgenerate

    // logic [3:0] conv_out_valid_reg;
    // always @ (posedge clk) begin
    //     if (!rstn)
    //         conv_out_valid_reg <= '0;
    //     else begin
    //         conv_out_valid_reg[0] <= aggr_valid;
    //         for (int j = 0; j < 3; j++) begin
    //             conv_out_valid_reg[j+1] <= conv_out_valid_reg[j];
    //         end
    //     end
    // end
    // assign conv_out_valid = conv_out_valid_reg[3];

    // Generate conv_out_valid FSM
    typedef enum { IDLE, WAIT, OUT } valid_fsm_e;
    valid_fsm_e state;
    localparam integer WAIT_CYCLE = 3;
    logic [$clog2(WAIT_CYCLE) -1:0] wait_cnt;

    always @ (posedge clk) begin
        if (!rstn) begin
            state  <= IDLE;
            wait_cnt <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (aggr_valid) begin
                        wait_cnt <= 0;
                        state <= WAIT;
                    end
                    else begin
                        wait_cnt <= 0;
                        state <= IDLE;
                    end
                end
                WAIT: begin
                    if (wait_cnt < WAIT_CYCLE - 1) begin
                        wait_cnt <= wait_cnt + 1;
                        state <= WAIT;
                    end
                    else begin  // wait_cnt == WAIT_CYCLE - 1
                        wait_cnt <= 0;
                        state <= OUT;
                    end
                end
                OUT: begin
                    if (aggr_valid)
                        state <= OUT;
                    else
                        state <= IDLE;
                end
                default: begin
                    state  <= state;
                    wait_cnt <= wait_cnt;
                end
            endcase
        end
    end

    assign conv_out_valid = ((state == OUT) && (aggr_valid));

endmodule