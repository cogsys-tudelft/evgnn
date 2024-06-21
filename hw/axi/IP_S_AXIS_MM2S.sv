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

	module IP_S_AXIS_MM2S #
	(
		// Users to add parameters here
        parameter integer READ_BURST_LEN        = 8,
		// User parameters ends
		// Do not modify the parameters beyond this line

		// AXI4Stream sink: Data Width
		parameter integer C_S_AXIS_TDATA_WIDTH	= 128,    // 32/64/128 for UltraScale PS AXI HP

        localparam integer RD_BUF_LEN = READ_BURST_LEN * C_S_AXIS_TDATA_WIDTH
        // localparam integer F_BUF_LEN =  RD_BUF_LEN / F_WIDTH
	)
	(
		// Users to add ports here
        input  wire  uip2axi_rd_en,   // from user IP: now can start read
        output reg   axi2uip_rd_done, // tell user IP, pulse: sink has accepted all the streaming data and stored in buffer
        // output wire  [RD_BUF_LEN   -1:0] rd_feature_buffer,
        output reg   [RD_BUF_LEN   -1:0] rd_buffer,  // buffer to store AXIS_TDATA

		// User ports ends
		// Do not modify the ports beyond this line

		input wire  S_AXIS_ACLK,
		input wire  S_AXIS_ARESETN,
		output wire  S_AXIS_TREADY,  // Ready to accept data in
		input wire [C_S_AXIS_TDATA_WIDTH    -1 : 0] S_AXIS_TDATA,  // Data in
		input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,  // Byte qualifier
		input wire  S_AXIS_TLAST,  // Indicates boundary of last packet / end of last packet
		input wire  S_AXIS_TVALID  // Indicates Tdata is in valid now
	);
	// function called clogb2 that returns an integer which has the
	// value of the ceiling of the log base 2.
	function integer clogb2 (input integer bit_depth);
	  begin
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
	      bit_depth = bit_depth >> 1;
	  end
	endfunction

	// // Total number of input data.
	// localparam NUMBER_OF_INPUT_WORDS  = 8;  // TODO: template = 8*32=256bit; in real I need 1024bit
	// BUF_IDX_WIDTH gives the minimum number of bits needed to address 'READ_BURST_LEN' size of rd_buffer.
	localparam BUF_IDX_WIDTH  = clogb2(READ_BURST_LEN-1);

	// Define the states of state machine
	// The control state machine oversees the writing of input streaming data to the FIFO,
	// and outputs the streaming data from the FIFO
	// parameter [1:0] IDLE = 'b00,       // This is the initial/idle state
	//                 READ = 'b01,       // In this state rd_buffer is written with the input stream data S_AXIS_TDATA
    //                 DONE = 'b11;       // Read finish
    typedef enum {IDLE, READ, DONE} fsm_e;


	wire					axis_tready;	// Inner axis ready signal
	fsm_e			        mst_exec_state;	// FSM State variable
	wire					handshake;		// Indicating a successful handshake
	// wire					fifo_wren;		// FIFO write enable
	// reg						fifo_full_flag;	// FIFO full flag
    // reg     [RD_BUF_LEN   -1:0] rd_buffer;  // buffer to store AXIS_TDATA
	reg		[BUF_IDX_WIDTH-1:0]	buffer_idx;	// rd_buffer write pointer  // same as a data counter

	// genvar  byte_index;  // FIFO implementation signals


	assign S_AXIS_TREADY	= axis_tready;  // I/O Connections assignments


	// Control state machine implementation
	always @(posedge S_AXIS_ACLK)
	begin
	  if (!S_AXIS_ARESETN)
	  // Synchronous reset (active low)
	    begin
	      mst_exec_state <= IDLE;
	    end
	  else
	    case (mst_exec_state)
	      IDLE:
	        // The sink starts accepting tdata when
	        // there tvalid is asserted to mark the
	        // presence of valid streaming data
	          if (S_AXIS_TVALID && uip2axi_rd_en)
	            begin
	              mst_exec_state <= READ;
	            end
	          else
	            begin
	              mst_exec_state <= IDLE;
	            end
	      READ:
	        if ((buffer_idx == READ_BURST_LEN-1) || S_AXIS_TLAST)
	          begin
	            mst_exec_state <= DONE;
	          end
	        else
	          begin
	            // The sink accepts and stores tdata into FIFO
	            mst_exec_state <= READ;
	          end
          DONE:
                mst_exec_state <= IDLE;
          default:
                mst_exec_state <= IDLE;

	    endcase
	end
	// AXI Streaming Sink
	//
	// The example design sink is always ready to accept the S_AXIS_TDATA  until
	// the FIFO is not filled with NUMBER_OF_INPUT_WORDS number of input words.
	assign axis_tready = ((mst_exec_state == READ) && (buffer_idx <= READ_BURST_LEN-1));

	// Handshake success
	assign handshake = S_AXIS_TVALID && axis_tready;

	always@(posedge S_AXIS_ACLK)
	begin
	  if(!S_AXIS_ARESETN)
	    begin
	      buffer_idx <= 0;
	    end
	  else
	    if (buffer_idx <= READ_BURST_LEN-1)
	      begin
	        if ((buffer_idx < READ_BURST_LEN-1) && (handshake))
	          begin
	            // write pointer is incremented after every write to the rd_buffer
	            // when rd_buffer write signal is enabled.
	            buffer_idx <= buffer_idx + 1;
	          end

            if ((buffer_idx == READ_BURST_LEN-1) || S_AXIS_TLAST)
            begin
                // reads_done is asserted when READ_BURST_LEN numbers of streaming data
                // has been written to the rd_buffer which is also marked by S_AXIS_TLAST(kept for optional usage).
                buffer_idx <= 0;
            end

	      end
	end

    always_comb begin
        if (mst_exec_state == DONE)
            axi2uip_rd_done = 1'b1;
        else
            axi2uip_rd_done = 1'b0;
	end

    // rd_buffer write
    always @( posedge S_AXIS_ACLK )
	    begin
	      if (handshake)
	        begin
	          rd_buffer[((buffer_idx+1)*C_S_AXIS_TDATA_WIDTH-1) -: C_S_AXIS_TDATA_WIDTH] <= S_AXIS_TDATA;
	        end
	    end

    //TODO: leave width transition to user ip
    // assign rd_feature_buffer = rd_buffer;
    // // width transition: READ_BURST_LEN * "C_S_AXIS_TDATA_WIDTH"bit -> F_BUF_LEN * "F_WIDTH"bit
    // generate
    //     for(genvar feature_idx = 0; feature_idx < F_BUF_LEN-1; feature_idx = feature_idx + 1) begin
    //         assign rd_feature_buffer[feature_idx] = rd_buffer[((feature_idx+1)*F_WIDTH-1) -: F_WIDTH];
    //     end
    // endgenerate




	// // FIFO write enable generation
	// assign fifo_wren = handshake;  // handshake success

	// // FIFO Implementation and width transition
	// generate
	//   for(genvar byte_index=0; byte_index<= (C_S_AXIS_TDATA_WIDTH/8-1); byte_index=byte_index+1)
	//   begin:FIFO_GEN

	//     reg  [(C_S_AXIS_TDATA_WIDTH/4)-1:0] stream_data_fifo [0 : NUMBER_OF_INPUT_WORDS-1];

	//     // Streaming input data is stored in FIFO

	//     always @( posedge S_AXIS_ACLK )  // 32bit tdata -> 8bit fifo data
	//     begin
	//       if (fifo_wren)// && S_AXIS_TSTRB[byte_index])
	//         begin
	//           stream_data_fifo[buffer_idx] <= S_AXIS_TDATA[(byte_index*8+7) -: 8];
	//         end
	//     end
	//   end
	// endgenerate

	// Add user logic here

	// User logic ends

	endmodule
