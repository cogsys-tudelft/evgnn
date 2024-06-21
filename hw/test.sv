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
`timescale 1ps/1ps
`include "mytest.svh"
import mytest::*;



module m1 (
    test_i.A itf
);
    always_ff @( posedge itf.clk ) begin
        itf.b <= itf.a;
        itf.d <= '1;
    end
endmodule

module m2 (
    test_i.B itf
);
    always_ff @( posedge itf.clk ) begin
        itf.c <= itf.b;
    end
endmodule


module bigtest;
    reg clk;

    always #5ns clk=~clk;

    wire o;

    test_i itf(clk);
    // m1 m1(.itf(itf));
    // m2 m2(.itf(itf));
    m1 m1(.*);
    m2 m2(.itf);

    initial begin
        clk <= '0;
        itf.a <= '1;
    end



    mytest::m_t ahaha;
    assign ahaha.b = 'b10110;
endmodule
