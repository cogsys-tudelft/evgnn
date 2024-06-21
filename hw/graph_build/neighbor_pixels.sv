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

module get_neighbor_pixels (
    input         clk,
    input         rstn,
    input x_idx_t x,
    input y_idx_t y,
    output logic signed [$clog2(TOT_PIXEL)+2 -1:0] neighbor_pixels [MAX_DS_RANGE]
);

    typedef struct packed {
        logic signed [X_PIXEL_WIDTH+1 -1:0] calculated;
        logic                               overflow;
    } x_coordinate_s;

    typedef struct packed {
        logic signed [Y_PIXEL_WIDTH+1 -1:0] calculated;
        logic                               overflow;
    } y_coordinate_s;

    x_coordinate_s x_neighbor [7];  // [x-3, x-2, x-1, x, x+1, x+2, x+3]
    y_coordinate_s y_neighbor [7];

    generate
        for (genvar i = 0; i < 7; i++) begin

            assign x_neighbor[i].calculated = $signed(x) + i - 3;
            assign y_neighbor[i].calculated = $signed(y) + i - 3;

            always_comb begin
                if (($signed(x_neighbor[i].calculated) < 0) || ($signed(x_neighbor[i].calculated) >= X_PIXEL) || (x >= X_PIXEL)) begin
                    x_neighbor[i].overflow = 'b1;
                end
                else x_neighbor[i].overflow = 'b0;
            end

            always_comb begin
                if (($signed(y_neighbor[i].calculated) < 0) || ($signed(y_neighbor[i].calculated) >= Y_PIXEL) || (y >= Y_PIXEL)) begin
                    y_neighbor[i].overflow = 'b1;
                end
                else y_neighbor[i].overflow = 'b0;
            end



        end
    endgenerate

    function logic [$clog2(TOT_PIXEL)+2 -1:0] xy2pixel (
        x_coordinate_s x_neighbor,
        y_coordinate_s y_neighbor
    );
        logic signed [$clog2(TOT_PIXEL)+2 -1:0] pseudo_pixel_idx;  // "pseudo": if pixel_idx is illegal, return -1
        logic overflow;

        overflow = (x_neighbor.overflow == 1'b1) || (y_neighbor.overflow == 1'b1);
        pseudo_pixel_idx = (overflow == 1'b1)? $signed(-1) : (x_neighbor.calculated + y_neighbor.calculated * X_PIXEL);

        // always_comb begin
        //     if ((x_neighbor.overflow == 1'b1) || (y_neighbor.overflow == 1'b1)) begin
        //         pseudo_pixel_idx = $signed(-1);
        //     end
        //     else begin
        //         pseudo_pixel_idx = x_neighbor.calculated + y_neighbor.calculated * X_PIXEL;
        //     end
        // end

        return pseudo_pixel_idx;
    endfunction

    // assign all neighbor pixels in a certain order
    always_ff @( posedge clk ) begin : Assigning
        if (!rstn) begin
            for (int j = 0; j < MAX_DS_RANGE; j++)
                neighbor_pixels[j] <= $signed(-1);
        end
        else begin
            // L1 distance = 0:
            neighbor_pixels[ 0] <= xy2pixel(x_neighbor[ 0 +3], y_neighbor[ 0 +3]);
            // L1 distance = 1:
            neighbor_pixels[ 1] <= xy2pixel(x_neighbor[ 0 +3], y_neighbor[ 1 +3]);
            neighbor_pixels[ 2] <= xy2pixel(x_neighbor[-1 +3], y_neighbor[ 0 +3]);
            neighbor_pixels[ 3] <= xy2pixel(x_neighbor[ 0 +3], y_neighbor[-1 +3]);
            neighbor_pixels[ 4] <= xy2pixel(x_neighbor[ 1 +3], y_neighbor[ 0 +3]);
            // L1 distance = 2:
            neighbor_pixels[ 5] <= xy2pixel(x_neighbor[ 1 +3], y_neighbor[ 1 +3]);
            neighbor_pixels[ 6] <= xy2pixel(x_neighbor[ 0 +3], y_neighbor[ 2 +3]);
            neighbor_pixels[ 7] <= xy2pixel(x_neighbor[-1 +3], y_neighbor[ 1 +3]);
            neighbor_pixels[ 8] <= xy2pixel(x_neighbor[-2 +3], y_neighbor[ 0 +3]);
            neighbor_pixels[ 9] <= xy2pixel(x_neighbor[-1 +3], y_neighbor[-1 +3]);
            neighbor_pixels[10] <= xy2pixel(x_neighbor[ 0 +3], y_neighbor[-2 +3]);
            neighbor_pixels[11] <= xy2pixel(x_neighbor[ 1 +3], y_neighbor[-1 +3]);
            neighbor_pixels[12] <= xy2pixel(x_neighbor[ 2 +3], y_neighbor[ 0 +3]);
            // L1 distance = 3:
            neighbor_pixels[13] <= xy2pixel(x_neighbor[ 2 +3], y_neighbor[ 1 +3]);
            neighbor_pixels[14] <= xy2pixel(x_neighbor[ 1 +3], y_neighbor[ 2 +3]);
            neighbor_pixels[15] <= xy2pixel(x_neighbor[ 0 +3], y_neighbor[ 3 +3]);
            neighbor_pixels[16] <= xy2pixel(x_neighbor[-1 +3], y_neighbor[ 2 +3]);
            neighbor_pixels[17] <= xy2pixel(x_neighbor[-2 +3], y_neighbor[ 1 +3]);
            neighbor_pixels[18] <= xy2pixel(x_neighbor[-3 +3], y_neighbor[ 0 +3]);
            neighbor_pixels[19] <= xy2pixel(x_neighbor[-2 +3], y_neighbor[-1 +3]);
            neighbor_pixels[20] <= xy2pixel(x_neighbor[-1 +3], y_neighbor[-2 +3]);
            neighbor_pixels[21] <= xy2pixel(x_neighbor[ 0 +3], y_neighbor[-3 +3]);
            neighbor_pixels[22] <= xy2pixel(x_neighbor[ 1 +3], y_neighbor[-2 +3]);
            neighbor_pixels[23] <= xy2pixel(x_neighbor[ 2 +3], y_neighbor[-1 +3]);
            neighbor_pixels[24] <= xy2pixel(x_neighbor[ 3 +3], y_neighbor[ 0 +3]);

        end
    end


endmodule