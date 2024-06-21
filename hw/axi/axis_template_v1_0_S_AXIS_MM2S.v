
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
`timescale 1 ns / 1 ps

	module axis_template_v1_0_S_AXIS_MM2S #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// AXI4Stream sink: Data Width
		parameter integer C_S_AXIS_TDATA_WIDTH	= 128    // 32/64/128 for UltraScale PS AXI HP
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line

		// AXI4Stream sink: Clock
		input wire  S_AXIS_ACLK,
		// AXI4Stream sink: Reset
		input wire  S_AXIS_ARESETN,
		// Ready to accept data in
		output wire  S_AXIS_TREADY,
		// Data in
		input wire [C_S_AXIS_TDATA_WIDTH    -1 : 0] S_AXIS_TDATA,
		// Byte qualifier
		input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,
		// Indicates boundary of last packet
		input wire  S_AXIS_TLAST,
		// Data is in valid
		input wire  S_AXIS_TVALID
	);
	// function called clogb2 that returns an integer which has the
	// value of the ceiling of the log base 2.
	function integer clogb2 (input integer bit_depth);
	  begin
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
	      bit_depth = bit_depth >> 1;
	  end
	endfunction

	// Total number of input data.
	localparam NUMBER_OF_INPUT_WORDS  = 8;  // TODO: template = 8*32=256bit; in real I need 1024bit
	// bit_num gives the minimum number of bits needed to address 'NUMBER_OF_INPUT_WORDS' size of FIFO.
	localparam bit_num  = clogb2(NUMBER_OF_INPUT_WORDS-1);
	// Define the states of state machine
	// The control state machine oversees the writing of input streaming data to the FIFO,
	// and outputs the streaming data from the FIFO
	parameter [1:0] IDLE = 1'b0,        // This is the initial/idle state

	                WRITE_FIFO  = 1'b1; // In this state FIFO is written with the
	                                    // input stream data S_AXIS_TDATA


	wire					axis_tready;	// Inner axis ready signal
	reg						mst_exec_state;	// FSM State variable
	wire					handshake;		// Indicating a successful handshake
	wire					fifo_wren;		// FIFO write enable
	reg						fifo_full_flag;	// FIFO full flag
	reg		[bit_num-1:0]	write_pointer;	// FIFO write pointer  // same as a write data counter
	reg						writes_done;	// sink has accepted all the streaming data and stored in FIFO
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
	          if (S_AXIS_TVALID)
	            begin
	              mst_exec_state <= WRITE_FIFO;
	            end
	          else
	            begin
	              mst_exec_state <= IDLE;
	            end
	      WRITE_FIFO:
	        // When the sink has accepted all the streaming input data,
	        // the interface swiches functionality to a streaming master
	        if (writes_done)
	          begin
	            mst_exec_state <= IDLE;
	          end
	        else
	          begin
	            // The sink accepts and stores tdata
	            // into FIFO
	            mst_exec_state <= WRITE_FIFO;
	          end

	    endcase
	end
	// AXI Streaming Sink
	//
	// The example design sink is always ready to accept the S_AXIS_TDATA  until
	// the FIFO is not filled with NUMBER_OF_INPUT_WORDS number of input words.
	assign axis_tready = ((mst_exec_state == WRITE_FIFO) && (write_pointer <= NUMBER_OF_INPUT_WORDS-1));

	// Handshake success
	assign handshake = S_AXIS_TVALID && axis_tready;

	always@(posedge S_AXIS_ACLK)
	begin
	  if(!S_AXIS_ARESETN)
	    begin
	      write_pointer <= 0;
	      writes_done <= 1'b0;
	    end
	  else
	    if (write_pointer <= NUMBER_OF_INPUT_WORDS-1)
	      begin
	        if (handshake)
	          begin
	            // write pointer is incremented after every write to the FIFO
	            // when FIFO write signal is enabled.
	            write_pointer <= write_pointer + 1;
	            writes_done <= 1'b0;
	          end
	          if ((write_pointer == NUMBER_OF_INPUT_WORDS-1)|| S_AXIS_TLAST)
	            begin
	              // reads_done is asserted when NUMBER_OF_INPUT_WORDS numbers of streaming data
	              // has been written to the FIFO which is also marked by S_AXIS_TLAST(kept for optional usage).
	              writes_done <= 1'b1;
	            end
	      end
	end

	// FIFO write enable generation
	assign fifo_wren = handshake;  // handshake success

	// FIFO Implementation and width transition
	generate
	  for(genvar byte_index=0; byte_index<= (C_S_AXIS_TDATA_WIDTH/8-1); byte_index=byte_index+1)
	  begin:FIFO_GEN

	    reg  [(C_S_AXIS_TDATA_WIDTH/4)-1:0] stream_data_fifo [0 : NUMBER_OF_INPUT_WORDS-1];

	    // Streaming input data is stored in FIFO

	    always @( posedge S_AXIS_ACLK )  // 32bit tdata -> 8bit fifo data
	    begin
	      if (fifo_wren)// && S_AXIS_TSTRB[byte_index])
	        begin
	          stream_data_fifo[write_pointer] <= S_AXIS_TDATA[(byte_index*8+7) -: 8];
	        end
	    end
	  end
	endgenerate

	// Add user logic here

	// User logic ends

	endmodule
