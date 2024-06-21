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
typedef logic [$clog2(12000)-1:0] pixel_idx_t;
typedef logic [64-1:0] event_s;


module global_event_buf #(
    parameter TOT_PIXEL = 12000,
    parameter MAX_DEGREE = 16
)(
    input pixel_idx_t pixel_idx,
    input logic       clk,
    input logic       rst,
    input logic       en,
    input logic       wr_rdn,  // 1 = write, 0 = read
    input event_s    din
);
    event_s    local_buffer [MAX_DEGREE + 1];

    always @ (posedge clk) begin
        if (rst) local_buffer[MAX_DEGREE] <= '0;
        else local_buffer[MAX_DEGREE] <= din;
    end


    genvar i;
    generate
        for (i = 0; i < MAX_DEGREE; i++) begin

            (* ram_style = "ultra" *) event_s global_buffer[TOT_PIXEL-1:0];

            always @(posedge clk) begin
                if (rst) local_buffer[i] <= '0;

                else begin
                    if (en) begin
                        if (!wr_rdn) begin
                            local_buffer[i] <= global_buffer[pixel_idx];
                        end else begin
                            global_buffer[pixel_idx] <= local_buffer[i+1];
                        end
                    end
                end
            end

        end
    endgenerate

endmodule
