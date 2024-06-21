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

module neighbor_pixels_wrapper (
    input         clk,
    input         rstn,
    input [7:0] x,
    input [7:0] y,
    output signed [$clog2(12000)+2 -1:0] neighbor_pixels [25]
);

    get_neighbor_pixels get_neighbor_pixels_inst(
        .clk(clk),
        .rstn(rstn),
        .x(x),
        .y(y),
        .neighbor_pixels(neighbor_pixels)
    );

endmodule

