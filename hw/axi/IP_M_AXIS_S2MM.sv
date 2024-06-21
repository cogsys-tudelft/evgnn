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

	module IP_M_AXIS_S2MM #
	(
		// Users to add parameters here
        parameter integer WRITE_BURST_LEN        = 8,
		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXIS address bus. The slave accepts the read and write addresses of width C_M_AXIS_TDATA_WIDTH.
		parameter integer C_M_AXIS_TDATA_WIDTH	= 128,  // 32/64/128 for UltraScale PS AXI HP
		// // Start count is the number of clock cycles the master will wait before initiating/issuing any transaction.
		// parameter integer C_M_START_COUNT	= 32,

        localparam integer WR_BUF_LEN = WRITE_BURST_LEN * C_M_AXIS_TDATA_WIDTH
	)
	(
		// Users to add ports here
        input  wire  uip2axi_wr_en,   // from user IP: now can start write
        output reg   axi2uip_wr_done, // tell user IP, pulse: write done
        input  reg   [WR_BUF_LEN   -1:0] wr_buffer,  // buffer to from IP, should come with wr_en
		// User ports ends
		// Do not modify the ports beyond this line

		// Global ports
		input wire  M_AXIS_ACLK,
		//
		input wire  M_AXIS_ARESETN,
		// Master Stream Ports. TVALID indicates that the master is driving a valid transfer, A transfer takes place when both TVALID and TREADY are asserted.
		output wire  M_AXIS_TVALID,
		// TDATA is the primary payload that is used to provide the data that is passing across the interface from the master.
		output wire [C_M_AXIS_TDATA_WIDTH-1 : 0] M_AXIS_TDATA,
		// TSTRB is the byte qualifier that indicates whether the content of the associated byte of TDATA is processed as a data byte or a position byte.
		output wire [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] M_AXIS_TSTRB,
		// TLAST indicates the boundary of a packet.
		output wire  M_AXIS_TLAST,
		// TREADY indicates that the slave can accept a transfer in the current cycle.
		input wire  M_AXIS_TREADY
	);
	// function called clogb2 that returns an integer which has the
	// value of the ceiling of the log base 2.
	function integer clogb2 (input integer bit_depth);
	  begin
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
	      bit_depth = bit_depth >> 1;
	  end
	endfunction
    localparam BUF_IDX_WIDTH  = clogb2(WRITE_BURST_LEN-1);

	// Define the states of state machine
	// The control state machine oversees the writing of input streaming data to the FIFO,
	// and outputs the streaming data from the FIFO
	// parameter [1:0] IDLE = 2'b00,        // This is the initial/idle state

	//                 INIT_COUNTER  = 2'b01, // This state initializes the counter, once
	//                                 // the counter reaches C_M_START_COUNT count,
	//                                 // the state machine changes state to SEND_STREAM
	//                 SEND_STREAM   = 2'b10; // In this state the
	//                                      // stream data is output through M_AXIS_TDATA
    typedef enum {IDLE, WRITE, DONE} fsm_e;


	// State variable
	fsm_e                       mst_exec_state;
    reg		[BUF_IDX_WIDTH-1:0]	buffer_idx;	// rd_buffer write pointer  // same as a data counter


	// AXI Stream internal signals
	reg  	axis_tvalid;
	reg  	axis_tlast;
    reg [C_M_AXIS_TDATA_WIDTH-1 : 0] m_axis_tdata;

	// I/O Connections assignments
	assign M_AXIS_TVALID = axis_tvalid;
	assign M_AXIS_TLAST	 = axis_tlast;
    assign M_AXIS_TDATA  = m_axis_tdata;
	assign M_AXIS_TSTRB	 = {(C_M_AXIS_TDATA_WIDTH/8){1'b1}};  // all bytes are valid

    wire  	handshake;
    assign  handshake = axis_tvalid && M_AXIS_TREADY;

    // FSM state transition
    always @ (posedge M_AXIS_ACLK) begin
        if (!M_AXIS_ARESETN) begin
            mst_exec_state <= IDLE;
        end
        else begin
            case (mst_exec_state)
                IDLE: begin
                    if (uip2axi_wr_en)
                        mst_exec_state <= WRITE;
                    else
                        mst_exec_state <= IDLE;
                end
                WRITE: begin
                    if (handshake && axis_tlast)
                        mst_exec_state <= DONE;
                    else
                        mst_exec_state <= WRITE;
                end
                DONE:
                    mst_exec_state <= IDLE;
                default:
                    mst_exec_state <= IDLE;
            endcase
        end
    end

    // buffer_idx changes
    always @ (posedge M_AXIS_ACLK) begin
        if (!M_AXIS_ARESETN) begin
            buffer_idx <= 0;
        end
        else begin
            if (handshake) begin
                if (buffer_idx < WRITE_BURST_LEN-1)
                    buffer_idx <= buffer_idx + 1;
                else  // buffer_idx == WRITE_BURST_LEN-1
                    buffer_idx <= 0;
            end
            else // usually when TREADY suddenly become 0
                buffer_idx <= buffer_idx;
        end
    end

    // FSM action signals
    always_comb begin
        if ((mst_exec_state == WRITE) && (buffer_idx <= WRITE_BURST_LEN-1))
            axis_tvalid = 1'b1;
        else
            axis_tvalid = 1'b0;
    end

    always_comb begin
        if (buffer_idx == WRITE_BURST_LEN-1)
            axis_tlast = 1'b1;
        else
            axis_tlast = 1'b0;
    end

    always_comb begin
        if (mst_exec_state == DONE)
            axi2uip_wr_done = 1'b1;
        else
            axi2uip_wr_done = 1'b0;
	end

    // wr_buffer read
    always_comb begin
        if (axis_tvalid)
            m_axis_tdata = wr_buffer[((buffer_idx+1)*C_M_AXIS_TDATA_WIDTH-1) -: C_M_AXIS_TDATA_WIDTH];
        else
            m_axis_tdata = 'b0;
	end



	endmodule
