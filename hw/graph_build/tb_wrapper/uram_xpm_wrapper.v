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
`timescale 1ns/1ns

module uram_xpm_wrapper (
    input  wire             clk,
    input  wire             we,
    input  wire [$clog2(12000)-1:0] addr,
    input  wire [16*72-1:0] din,
    output wire [16*72-1:0] dout
);
    wire en = 'b1;
    wire rstn = 'b1;

    // wire [72-1:0] d [0:16-1];

    // genvar j;
    // generate
    //     for (j = 0; j < 16; j=j+1) begin

    //         assign dout[72*j+71:72*j] = d[j][72-1:0];
    //     end
    // endgenerate

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin
            uram_xpm uram_xpm_inst (
                clk,
                en,
                rstn,
                we,
                addr,
                din[72*i+71:72*i],
                dout[72*i+71:72*i]
            );
        end
    endgenerate



endmodule
