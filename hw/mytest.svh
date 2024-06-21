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
package mytest;
    typedef struct {
        logic [7:0] a [5];
        logic [4:0] b;
    } m_t;
endpackage

interface test_i(input clk);
    logic a;
    logic b;
    logic c;
    logic d;

    modport A (
        input clk,
        input a,
        output b,
        output d
    );

    modport B (
        input clk,
        input b,
        output c
    );
endinterface //test_i
