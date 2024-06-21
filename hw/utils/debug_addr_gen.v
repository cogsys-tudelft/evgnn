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

module debug_addr_gen #(
    parameter integer LENGTH = 12000,
    parameter integer WIDTH  = $clog2(LENGTH)
) (
    input wire clk,
    output reg [WIDTH-1:0] debug_addr
);

    wire rstn = 'b1;

    always @ (posedge clk) begin
        if (!rstn)
            debug_addr <= 'b0;
        else begin
            if (debug_addr < LENGTH)
                debug_addr <= debug_addr + 1'b1;
            else
                debug_addr <= 'b0;
        end
    end
endmodule