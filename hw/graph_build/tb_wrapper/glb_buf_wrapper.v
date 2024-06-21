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

module glb_buf_wrapper(
    input wire [$clog2(12000)-1:0] pixel_idx,
    input wire       clk,
    input wire       rstn,
    input wire       en,
    input wire       wr_rdn,  // 1 = write, 0 = read
    input wire [72-1:0]    din,
    output wire [16*72-1:0]    dout
);


    global_event_buf global_event_buf_inst(
        pixel_idx,
        clk,
        rstn,
        en,
        wr_rdn,
        din,
        dout
    );
endmodule