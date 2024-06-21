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

module graph_build #(
    parameter WIDTH = 72  //TODO: 想一想到底写什么
    // localparam
) (
    // ports
    input  logic   clk,
    input  logic   rstn,
    input  logic   data_valid,
    input  logic   event_stream_clean,
    output logic   stream_clean_done,
    input  event_s new_event, //TODO: 拼接一下当前事件, 或许应该在 control&config 模块做
    output logic   module_ready,
    output logic   module_done,

    // global_neighbor_buffer FIFO Write group
    output logic               fifo_wr_en,
    output logic [WIDTH-1 : 0] fifo_din,
    input  logic               fifo_full
    // input  logic                        fifo_wr_ack,
    // input  logic                        fifo_overflow,
    // input  logic [DATA_COUNT_WIDTH-1:0] fifo_wr_data_count,
    // input  logic                        fifo_wr_rst_busy
);

    event_s                                      past_events_at_pixel[  MAX_DEGREE];

    logic signed      [ $clog2(TOT_PIXEL)+2 -1:0] neighbor_pixels     [MAX_DS_RANGE];
    logic             [$clog2(MAX_DS_RANGE) -1:0] neighbor_pixel_idx;
    pixel_idx_t                                   neighbor_pixel;
    logic                                         is_real_pixel;

    // assign is_real_pixel = ($signed(neighbor_pixels[neighbor_pixel_idx]) != $signed(-1))? 1'b1 : 1'b0;
    assign is_real_pixel = (&neighbor_pixels[neighbor_pixel_idx] != 1'b1)? 1'b1 : 1'b0;   // TODO: 检查等价性
    assign neighbor_pixel = neighbor_pixels[neighbor_pixel_idx][$clog2(TOT_PIXEL)-1:0];

    logic global_buffer_en;
    logic global_buffer_wr_rdn;

    logic local_buffer_valid;
    logic select_neighbors_done;

    // event stream clean process
    logic clean;
    pixel_idx_t clean_pixel;
    pixel_idx_t processing_pixel;
    assign processing_pixel = (clean)? clean_pixel : neighbor_pixel;

    event_s processing_din;
    assign processing_din = (clean)? '0 : new_event;




    // sub-modules inst
    get_neighbor_pixels get_neighbor_pixels_inst (
        .clk,
        .rstn,
        .x(new_event.x),
        .y(new_event.y),
        .neighbor_pixels
    );

    global_event_buf #(
        .READ_LATENCY(4)
    ) global_event_buf_inst (
        .clk,
        .rstn,
        .clean    (clean),
        .pixel_idx(processing_pixel),
        .en       (global_buffer_en),
        .wr_rdn   (global_buffer_wr_rdn),  // 1 = write, 0 = read
        .din      (processing_din),
        .dout     (past_events_at_pixel),
        .dout_valid (local_buffer_valid)
    );

    select_neighbors #(
        .WIDTH(WIDTH),  //TODO: 想一想到底写什么
        .DATA_COUNT_WIDTH($clog2(MAX_DEGREE) + 1)
    ) select_neighbors_inst (
        .clk,
        .rstn,
        .local_buffer_valid    (local_buffer_valid),     //TODO: valid 握手是不是也要考虑回ack，然后valid变低？
        .local_buffer          (past_events_at_pixel),
        .select_neighbors_ready(),
        .select_neighbors_done (select_neighbors_done),
        .t_now(new_event.t),
        // global_neighbor_buffer FIFO Write group
        .fifo_wr_en,
        .fifo_din,
        .fifo_full
    );



    typedef enum {
        IDLE,
        GET_PIXELS,
        GET_OLD_EVENTS,
        NOT_REAL_PIXEL,
        SELECT_NEIGHBORS,
        WRITE_BACK_NEW_EVENT,
        DONE,
        CLEAN,
        CLEAN_DONE
    } fsm_graph_build_e;
    fsm_graph_build_e    state;

    // Describe state transition
    always @ (posedge clk) begin
        if (!rstn) begin
            state <= IDLE;
            neighbor_pixel_idx <= '0;
            clean_pixel <= '0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (data_valid)
                        state <= GET_PIXELS;
                    else if (event_stream_clean)
                        state <= CLEAN;
                    else
                        state <= IDLE;
                end
                GET_PIXELS: begin    // when state == GET_PIXELS, the "neighbor_pixels[]" is already valid
                    if (is_real_pixel)   // if neighbor_pixels[0] is not -1
                        state <= GET_OLD_EVENTS;
                    else
                        state <= NOT_REAL_PIXEL;
                end
                GET_OLD_EVENTS: begin
                    if (is_real_pixel) begin
                        if (!local_buffer_valid)  // waiting for ram read finishing
                            state <= GET_OLD_EVENTS;
                        else
                            state <= SELECT_NEIGHBORS;
                    end
                    else
                        state <= NOT_REAL_PIXEL;
                end
                NOT_REAL_PIXEL: begin
                    if (neighbor_pixel_idx < (MAX_DS_RANGE - 1)) begin
                        neighbor_pixel_idx <= neighbor_pixel_idx + 1'd1;
                        state <= GET_OLD_EVENTS;
                    end
                    else begin
                        neighbor_pixel_idx <= '0;
                        state <= DONE;
                    end
                end
                SELECT_NEIGHBORS: begin
                    if (!select_neighbors_done)
                        state <= SELECT_NEIGHBORS;
                    else begin
                        if (neighbor_pixel_idx == '0) begin  // if it is the pixel that new event located, since we already read out its older neighbors, we have to write it back into the global event buffer right now
                            state <= WRITE_BACK_NEW_EVENT;
                        end
                        else begin
                            if (neighbor_pixel_idx < (MAX_DS_RANGE - 1)) begin
                                neighbor_pixel_idx <= neighbor_pixel_idx + 1'd1;
                                state <= GET_OLD_EVENTS;
                            end
                            else begin
                                neighbor_pixel_idx <= '0;
                                state <= DONE;
                            end
                        end
                    end
                end
                WRITE_BACK_NEW_EVENT: begin
                    // for 1clk ram write latency
                    neighbor_pixel_idx <= neighbor_pixel_idx + 1'd1;  // neighbor_pixel_idx == 0 for now, so it must be < (MAX_DS_RANGE - 1)
                    state <= GET_OLD_EVENTS;
                end
                DONE: begin
                    state <= IDLE;
                    neighbor_pixel_idx <= '0;
                end
                CLEAN: begin
                    if (clean_pixel < TOT_PIXEL - 1) begin
                        clean_pixel <= clean_pixel + 1;
                    end
                    else begin
                        clean_pixel <= '0;
                        state <= CLEAN_DONE;
                    end
                end
                CLEAN_DONE: begin
                    state <= IDLE;
                    neighbor_pixel_idx <= '0;
                end
                default: begin
                    state <= IDLE;
                    neighbor_pixel_idx <= '0;
                end
            endcase
        end
    end

    /*
    case (state)
        IDLE:
        GET_PIXELS:
        GET_OLD_EVENTS:
        NOT_REAL_PIXEL:
        SELECT_NEIGHBORS:
        DONE:
        default:
    endcase
    */
    // Describe state action
    always_comb begin
        // outside handshake control
        case (state)
            IDLE:
                module_ready = 1'b1;
            // GET_PIXELS, GET_OLD_EVENTS, NOT_REAL_PIXEL, SELECT_NEIGHBORS, WRITE_BACK_NEW_EVENT:
            //     module_ready = 1'b0;
            // DONE:
            //     module_ready = 1'b0;
            default:
                module_ready = 1'b0;
        endcase

        // outside done signal
        case (state)
            DONE:
                module_done = 1'b1;
            default:
                module_done = 1'b0;
        endcase

        // global_event_buffer_control
        case (state)
            GET_OLD_EVENTS: begin
                if (is_real_pixel) begin  // ram read  //! Mealy: debug: 检查功能
                    global_buffer_en = 1'b1;
                    global_buffer_wr_rdn = 1'b0;
                end
                else begin  // ram idle
                    global_buffer_en = 1'b0;
                    global_buffer_wr_rdn = 1'b0;
                end
            end
            WRITE_BACK_NEW_EVENT: begin // ram write
                global_buffer_en = 1'b1;
                global_buffer_wr_rdn = 1'b1;
            end
            CLEAN: begin // ram write
                global_buffer_en = 1'b1;
                global_buffer_wr_rdn = 1'b1;
            end
            default: begin  // ram idle
                global_buffer_en = 1'b0;
                global_buffer_wr_rdn = 1'b0;
            end
        endcase

    end

    assign stream_clean_done = (state == CLEAN_DONE);
    assign clean = (state == CLEAN);


endmodule
