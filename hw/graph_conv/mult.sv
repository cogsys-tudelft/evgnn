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

(* use_dsp = "yes" *) module mult_GNN #(
    parameter LATENCY = 2,
    parameter DEVICE  = "code"  // "code" or "ip"

)(
    input  logic  clk,
    input  f_t    feature,
    input  w_t    weight,
    output mult_t product
);

generate
    case (DEVICE)
        "ip", "IP": begin

            /* TCL:
                create_ip -name mult_gen -module_name mult_ip
                set_property -dict [list \
                    CONFIG.MultType {Parallel_Multiplier} \
                    CONFIG.Multiplier_Construction {Use_LUTs} \
                    CONFIG.OptGoal {Speed} \
                    CONFIG.PortAType {Unsigned} \
                    CONFIG.PortAWidth {8} \
                    CONFIG.PortBType {Signed} \
                    CONFIG.PortBWidth {8} \
                    CONFIG.SyncClear {false} \
                    CONFIG.PipeStages {<LATENCY>} \
                ] [get_ips mult_ip]
                generate_target all [get_ips mult_ip]s
            */

            mult_ip mult_ip_inst(
                .CLK(clk),        // input wire CLK
                .A  (feature),    // input wire [7 : 0] A
                .B  (weight),     // input wire [7 : 0] B
                .P  (product)  // output wire [15 : 0] P
            );




        end
        default: begin  // "code"


            if (LATENCY == 0) begin
                assign product = $signed({1'b0, feature}) * $signed(weight);
            end

            else if (LATENCY == 1) begin

                f_t f_reg;
                w_t w_reg;

                always @ (posedge clk) begin
                    f_reg <= feature;
                    w_reg <= weight;
                end

                assign product = $signed({1'b0, f_reg}) * $signed(w_reg);

            end


            else begin

                f_t f_reg;
                w_t w_reg;
                mult_t M [LATENCY-1];

                always @ (posedge clk) begin
                    f_reg <= feature;
                    w_reg <= weight;
                    M[0] <= $signed({1'b0, f_reg}) * $signed(w_reg);
                    for (int i = 0; i < LATENCY-2; i++) begin
                        M[i+1] <= M[i];
                    end
                end

                assign product = M[LATENCY - 2];

            end


        end
    endcase
endgenerate


endmodule
