/******************************************************************************
 * (C) Copyright 2019 AGH UST All Rights Reserved
 *
 * MODULE:		mtm_Alu tb
 * PROJECT:		PPCU_VLSI
 * AUTHORS:		P. Ziebinski, S. Janik
 * DATE:
 * ------------------------------------------------------------------------------
 * This module (TB) provides test patterns for the ALU, reads data from the ALU and 
 * verifies if the operation result is correct.
 * 
 * The TB must include:
 * - task send_byte to send a CMD or CTL command to the ALU
 * - task send_calculation_data that will send 9 bytes to the ALU for given
 *   operands and operation
 * - procedural block for capturing the input data from the ALU
 * - task compare to compare the result from the ALU and the expected data.
 * 
 * The test vectors must provide at least:
 * - sending max (0xFFFF) and min (0) data with all the ALU operations (AND OR, ADD,SUB)
 * - sending 1000 random valid data
 * - sending invalid data (wrong number of DATA packets before CTL packet)
 * - sending data with CRC error
 * 
 * The testbench should print final PASS/FAIL text information.
 */
 //FRAME TYPES
 `define DATA_FRAME 1'b0
 `define CMD_FRAME 	1'b1

 //ALU OPERATIONS
`define AND		3'b000;
`define OR		3'b001;
`define ADD		3'b100;
`define SUB		3'b101;
 
 
module mtm_Alu_tb (
    output reg clk,
    output reg rst_n,
    output reg sin,
    input wire sout
);

	task send_byte(
		input frame_indicator,
		input [7:0] data
		);
		
		reg [10:0] full_frame;
		integer bit_counter;
		
		begin
			full_frame = {1'b0, frame_indicator, data, 1'b1};
			for(bit_counter = 10; bit_counter >= 0; bit_counter = bit_counter - 1) begin
				@(negedge clk);
				sin = full_frame[bit_counter];
			end
		end
	endtask
	
	
	task send_calculation_data(
		input [31:0] A, B,
		input [2:0] OP,
		input [3:0] CRC
		);
		
		begin
			send_byte(`DATA_FRAME, B[31:24]);
			send_byte(`DATA_FRAME, B[23:16]);
			send_byte(`DATA_FRAME, B[15:8]);
			send_byte(`DATA_FRAME, B[7:0]);
			
			send_byte(`DATA_FRAME, B[31:24]);
			send_byte(`DATA_FRAME, B[23:16]);
			send_byte(`DATA_FRAME, B[15:8]);
			send_byte(`DATA_FRAME, B[7:0]);
			
			send_byte(`CMD_FRAME, {1'b0, OP, CRC});
		end
	endtask
	
	
	task compare;
	
	endtask
	
endmodule
