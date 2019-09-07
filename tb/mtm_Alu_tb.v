`timescale 1ns/1ps
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
 
module mtm_Alu_tb (
    output wire clk,
    output wire rst_n,
    output reg sin,
    input wire sout
	);

	localparam
	//ALU OPERATIONS
	AND		= 3'b000,
	OR		= 3'b001,
	ADD		= 3'b100,
	SUB		= 3'b101,

	//FRAME TYPES
 	TYPE_DATA	= 1'b0,
 	TYPE_CMD	= 1'b1 ;

	reg [2:0] OP;
	reg [54:0] alu_data;

	reg clock = 0, reset = 1;
	reg finish_simulation = 0;
	// 245.76 Mhz clock and simulation control
	initial begin
		#100;
		finish_simulation = 0;
		clock = 0;
		#2.0345;
		while (!finish_simulation)
		#2.0345 clock <= ~clock;
	end
	
	assign clk = clock;
	assign rst_n = reset;

	initial begin
		reset_DUT;
		test_random_data;
		reset_DUT;
		test_max_min;
		reset_DUT;
		test_wrong_crc;
		reset_DUT;
		test_wrong_num_of_packets;
		reset_DUT;
		test_wrong_op;
	end
	
	
	/////////////////// TASKS ///////////////////

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
		input [2:0] OPeration,
		input [3:0] CRC
		);
		
		begin
			send_byte(TYPE_DATA, B[31:24]);
			send_byte(TYPE_DATA, B[23:16]);
			send_byte(TYPE_DATA, B[15:8]);
			send_byte(TYPE_DATA, B[7:0]);
			
			send_byte(TYPE_DATA, A[31:24]);
			send_byte(TYPE_DATA, A[23:16]);
			send_byte(TYPE_DATA, A[15:8]);
			send_byte(TYPE_DATA, A[7:0]);
			
			send_byte(TYPE_CMD, {1'b0, OPeration, CRC});
		end
	endtask
	
	
	task compare(
		input [54:0] expected_data
		);
	
		integer bit_counter;
		
		begin
		
			alu_data <= 0;
			@(negedge sout);
			repeat(11) begin
				@(negedge clk);
				alu_data = {alu_data, sout};
			end
			//IS DATA FRAME?
			if(alu_data[9] == TYPE_DATA) begin
				repeat(4) begin
					@(negedge sout);
					repeat(11) begin
						@(negedge clk);
						alu_data = {alu_data, sout};
					end
				end
				//PASS
				if(alu_data[54:0] == expected_data[54:0]) begin	
					$display("	PASS: Received DATA as expected");
				end
				
				//FAIL
				else begin
					$display("	FAIL: Alu returned wrong DATA %b; expected: %b", alu_data, expected_data);
					//$stop;
					//$finish;
				end
			end
			
			//PASS
			else if(alu_data[10:0] == expected_data[10:0]) begin	
				$display("	PASS: Received CTL as expected");
			end
			
			//FAIL
			else begin
				$display("	FAIL: Alu returned wrong CTL %b; expected: %b", alu_data, expected_data);
				//$stop;
				//$finish;
			end
			
		end
	endtask
	
	
	task reset_DUT;
		begin
			@(posedge clk);
			reset <= 0;
			alu_data <= 0;
			@(posedge clk);
			reset <= 1;
		end
	endtask
	
	
	/////////////////// TESTS ///////////////////
	
	
	reg [31:0] A;
	reg [31:0] B;
	reg [54:0] C;
	reg [3:0] CRC;

	task test_random_data(
		);
	
		begin
			$display("\nStarting 250 random 'ADD' params test");
			repeat(250)
			begin
				OP = ADD;
				A = $random;
				B = $random;
				C = calculate(A, B, OP);
				CRC4forData68({B, A, 1'b1, OP}, CRC);
				
				send_calculation_data(A, B, OP, CRC);
				compare(C);
			end
			
			$display("\nStarting 250 random 'SUB' params test");
			repeat(250)
			begin
				OP = SUB;
				A = $random;
				B = $random;
				C = calculate(A, B, OP);
				CRC4forData68({B, A, 1'b1, OP}, CRC);
				
				send_calculation_data(A, B, OP, CRC);
				compare(C);
			end
			
			$display("\nStarting 250 random 'AND' params test");
			repeat(250)
			begin
				OP = AND;
				A = $random;
				B = $random;
				C = calculate(A, B, OP);
				CRC4forData68({B, A, 1'b1, OP}, CRC);
				
				send_calculation_data(A, B, OP, CRC);
				compare(C);
			end
			
			$display("\nStarting 250 random 'OR' params test");
			repeat(250)
			begin
				OP = OR;
				A = $random;
				B = $random;
				C = calculate(A, B, OP);
				CRC4forData68({B, A, 1'b1, OP}, CRC);
				
				send_calculation_data(A, B, OP, CRC);
				compare(C);
			end
		end
	endtask
	

	reg [31:0] min;
	reg [31:0] max;
	
	task test_max_min;
			
		begin
			CRC4forData68({B, A, 1'b1, OP}, CRC);
			min = 32'h00000000;
			max = 32'hFFFFFFFF;
			
			$display("\nStarting max/min data test");
			
			//ADDITION
			$display("Addition");
			OP = ADD;
			C = calculate(min, max, OP);
			CRC4forData68({max, min, 1'b1, OP}, CRC);
			send_calculation_data(min, max, OP, CRC);
			compare(C);
			C = calculate(max, min, OP);
			CRC4forData68({min, max, 1'b1, OP}, CRC);
			send_calculation_data(max, min, OP, CRC);
			compare(C);
			C = calculate(max, max, OP);
			CRC4forData68({max, max, 1'b1, OP}, CRC);
			send_calculation_data(max, max, OP, CRC);
			compare(C);
			C = calculate(min, min, OP);
			CRC4forData68({min, min, 1'b1, OP}, CRC);
			send_calculation_data(min, min, OP, CRC);
			compare(C);
			
			//SUBTRACTION
			$display("Subtraction");
			OP = SUB;
			C = calculate(min, max, OP);
			CRC4forData68({max, min, 1'b1, OP}, CRC);
			send_calculation_data(min, max, OP, CRC);
			compare(C);
			C = calculate(max, min, OP);
			CRC4forData68({min, max, 1'b1, OP}, CRC);
			send_calculation_data(max, min, OP, CRC);
			compare(C);
			C = calculate(max, max, OP);
			CRC4forData68({max, max, 1'b1, OP}, CRC);
			send_calculation_data(max, max, OP, CRC);
			compare(C);
			C = calculate(min, min, OP);
			CRC4forData68({min, min, 1'b1, OP}, CRC);
			send_calculation_data(min, min, OP, CRC);
			compare(C);
			
			//BITWISE OR
			$display("OR");
			OP = OR;
			C = calculate(min, max, OP);
			CRC4forData68({max, min, 1'b1, OP}, CRC);
			send_calculation_data(min, max, OP, CRC);
			compare(C);
			C = calculate(max, min, OP);
			CRC4forData68({min, max, 1'b1, OP}, CRC);
			send_calculation_data(max, min, OP, CRC);
			compare(C);
			C = calculate(max, max, OP);
			CRC4forData68({max, max, 1'b1, OP}, CRC);
			send_calculation_data(max, max, OP, CRC);
			compare(C);
			C = calculate(min, min, OP);
			CRC4forData68({min, min, 1'b1, OP}, CRC);
			send_calculation_data(min, min, OP, CRC);
			compare(C);
			
			//BITWISE AND
			$display("AND");
			OP = AND;
			C = calculate(min, max, OP);
			CRC4forData68({max, min, 1'b1, OP}, CRC);
			send_calculation_data(min, max, OP, CRC);
			compare(C);
			C = calculate(max, min, OP);
			CRC4forData68({min, max, 1'b1, OP}, CRC);
			send_calculation_data(max, min, OP, CRC);
			compare(C);
			C = calculate(max, max, OP);
			CRC4forData68({max, max, 1'b1, OP}, CRC);
			send_calculation_data(max, max, OP, CRC);
			compare(C);
			C = calculate(min, min, OP);
			CRC4forData68({min, min, 1'b1, OP}, CRC);
			send_calculation_data(min, min, OP, CRC);
			compare(C);
		end
	endtask
	

	reg [10:0] CMD;
	
	task test_wrong_num_of_packets;
		begin
			A = 32'h11111111;
			B = 32'h22222222;
			OP = ADD;
			CRC4forData68({B, A, 1'b1, OP}, CRC);
			CMD = 11'b01110010011;	//frame with ERR_DATA flag

			$display("\nStarting wrong number of packets test");
			
			$display("Too many frames");
			send_byte(TYPE_DATA, B[31:24]);
			send_byte(TYPE_DATA, B[23:16]);
			send_byte(TYPE_DATA, B[15:8]);
			send_byte(TYPE_DATA, B[7:0]);
			
			send_byte(TYPE_DATA, A[31:24]);
			send_byte(TYPE_DATA, A[23:16]);
			send_byte(TYPE_DATA, A[23:16]);	//additional A frame
			send_byte(TYPE_DATA, A[15:8]);
			send_byte(TYPE_DATA, A[7:0]);
											//no CTL frame
			compare(CMD);
			
			
			$display("Too few frames");
			send_byte(TYPE_DATA, B[31:24]);
			send_byte(TYPE_DATA, B[23:16]);
			send_byte(TYPE_DATA, B[15:8]);		//no last frame from B
			
			send_byte(TYPE_DATA, A[31:24]);
			send_byte(TYPE_DATA, A[23:16]);
			send_byte(TYPE_DATA, A[15:8]);
			send_byte(TYPE_DATA, A[7:0]);
			
			send_byte(TYPE_CMD, {1'b0, OP, CRC});
			compare(CMD);
			
		end
	endtask
	
	
	task test_wrong_op;
		begin
			A = 32'h11111111;
			B = 32'h22222222;
			OP = 3'b010;	//there is no such operation
			CMD = 11'b01100100111;	//frame with ERR_OP flag
			CRC4forData68({B, A, 1'b1, OP}, CRC);

			$display("\nStarting wrong operation test");
			send_byte(TYPE_DATA, B[31:24]);
			send_byte(TYPE_DATA, B[23:16]);
			send_byte(TYPE_DATA, B[15:8]);
			send_byte(TYPE_DATA, B[7:0]);
			
			send_byte(TYPE_DATA, A[31:24]);
			send_byte(TYPE_DATA, A[23:16]);
			send_byte(TYPE_DATA, A[15:8]);
			send_byte(TYPE_DATA, A[7:0]);
			
			send_byte(TYPE_CMD, {1'b0, OP, CRC});
			compare(CMD);
		end
	endtask
	
	
	task test_wrong_crc;	
		begin
			A = 32'h11111111;
			B = 32'h22222222;
			OP = ADD;
			CRC = 4'b0000;
			CMD = 11'b01101001011;	//frame with ERR_CRC flag

			$display("\nStarting wrong CRC test");
			send_byte(TYPE_DATA, B[31:24]);
			send_byte(TYPE_DATA, B[23:16]);
			send_byte(TYPE_DATA, B[15:8]);
			send_byte(TYPE_DATA, B[7:0]);
			
			send_byte(TYPE_DATA, A[31:24]);
			send_byte(TYPE_DATA, A[23:16]);
			send_byte(TYPE_DATA, A[15:8]);
			send_byte(TYPE_DATA, A[7:0]);
			
			send_byte(TYPE_CMD, {1'b0, OP, CRC});
			compare(CMD);
		end
	endtask
	
	
	/////////////////// FUNCTIONS ///////////////////
	
	function [54:0] calculate;
		input [31:0] A;
		input [31:0] B;
		input [2:0] OP;
		
		reg [31:0] C;
		reg carry;
		reg [3:0] flags;
		reg [2:0] CRC3;
		
        begin
			flags = 4'b0000;
			carry = 1'b0;
            case(OP)
			
                3'b000: C = A & B;
                3'b001: C = A | B;
                3'b100: begin
					{carry, C} = {1'b0, B} + {1'b0, A};
					//flag carry
					flags[3] = carry;
					//flag overflow
					flags[2] = ((B[31] ^ C[31]) ^ A[31]) ^ carry;
				end		
                3'b101: begin
					{carry, C} = {1'b0, A} - {1'b0, B};
					//flag carry
					flags[3] = carry;
					//flag overflow
					flags[2] = ((B[31] ^ C[31]) ^ A[31]) ^ carry;
				end
            endcase

            //flag zero
			flags[1] = (C == 0);
            //flag negative
			flags[0] = C[31];
			
			calculate = 0;
			CRC3forData37({C, 1'b0, flags}, CRC3);
            calculate = {calculate, 2'b00, C[31:24], 1'b1};
            calculate = {calculate, 2'b00, C[23:16], 1'b1};
            calculate = {calculate, 2'b00, C[15:8], 1'b1};
            calculate = {calculate, 2'b00, C[7:0], 1'b1};
			calculate = {calculate, 3'b010, flags, CRC3, 1'b1};
	   end
	endfunction
	
	
	task CRC3forData37;
	  // polynomial: x^3 + x^1 + 1 (0x5) with initial value 0
	  input reg [36:0] Data_in;
	  output reg [2:0] CRC3_result;

	  reg [36:0] d;
	  reg [2:0] Result;

	  begin
		 d = Data_in;
		 Result[0] = d[35] ^ d[32] ^ d[31] ^ d[30] ^ d[28] ^ d[25] ^ d[24] ^ d[23] ^ d[21] ^ d[18] ^ d[17] ^ d[16] ^ d[14] ^ d[11] ^ d[10] ^ d[9] ^ d[7] ^ d[4] ^ d[3] ^ d[2] ^ d[0];
		 Result[1] = d[36] ^ d[35] ^ d[33] ^ d[30] ^ d[29] ^ d[28] ^ d[26] ^ d[23] ^ d[22] ^ d[21] ^ d[19] ^ d[16] ^ d[15] ^ d[14] ^ d[12] ^ d[9] ^ d[8] ^ d[7] ^ d[5] ^ d[2] ^ d[1] ^ d[0];
		 Result[2] = d[36] ^ d[34] ^ d[31] ^ d[30] ^ d[29] ^ d[27] ^ d[24] ^ d[23] ^ d[22] ^ d[20] ^ d[17] ^ d[16] ^ d[15] ^ d[13] ^ d[10] ^ d[9] ^ d[8] ^ d[6] ^ d[3] ^ d[2] ^ d[1];
		 CRC3_result = Result;
	  end
	endtask
	
	task CRC4forData68;
      // polynomial: x^4 + x^1 +1 (0x9) with initial value 0
      input reg [67:0] Data_in;
      output reg [3:0] CRC4_result;
      
      reg [67:0] d;
      reg [3:0] Result;

      begin
         d = Data_in;
         Result[0] = d[66] ^ d[64] ^ d[63] ^ d[60] ^ d[56] ^ d[55] ^ d[54] ^ d[53] ^ d[51] ^ d[49] ^ d[48] ^ d[45] ^ d[41] ^ d[40] ^ d[39] ^ d[38] ^ d[36] ^ d[34] ^ d[33] ^ d[30] ^ d[26] ^ d[25] ^ d[24] ^ d[23] ^ d[21] ^ d[19] ^ d[18] ^ d[15] ^ d[11] ^ d[10] ^ d[9] ^ d[8] ^ d[6] ^ d[4] ^ d[3] ^ d[0];
         Result[1] = d[67] ^ d[66] ^ d[65] ^ d[63] ^ d[61] ^ d[60] ^ d[57] ^ d[53] ^ d[52] ^ d[51] ^ d[50] ^ d[48] ^ d[46] ^ d[45] ^ d[42] ^ d[38] ^ d[37] ^ d[36] ^ d[35] ^ d[33] ^ d[31] ^ d[30] ^ d[27] ^ d[23] ^ d[22] ^ d[21] ^ d[20] ^ d[18] ^ d[16] ^ d[15] ^ d[12] ^ d[8] ^ d[7] ^ d[6] ^ d[5] ^ d[3] ^ d[1] ^ d[0];
         Result[2] = d[67] ^ d[66] ^ d[64] ^ d[62] ^ d[61] ^ d[58] ^ d[54] ^ d[53] ^ d[52] ^ d[51] ^ d[49] ^ d[47] ^ d[46] ^ d[43] ^ d[39] ^ d[38] ^ d[37] ^ d[36] ^ d[34] ^ d[32] ^ d[31] ^ d[28] ^ d[24] ^ d[23] ^ d[22] ^ d[21] ^ d[19] ^ d[17] ^ d[16] ^ d[13] ^ d[9] ^ d[8] ^ d[7] ^ d[6] ^ d[4] ^ d[2] ^ d[1];
         Result[3] = d[67] ^ d[65] ^ d[63] ^ d[62] ^ d[59] ^ d[55] ^ d[54] ^ d[53] ^ d[52] ^ d[50] ^ d[48] ^ d[47] ^ d[44] ^ d[40] ^ d[39] ^ d[38] ^ d[37] ^ d[35] ^ d[33] ^ d[32] ^ d[29] ^ d[25] ^ d[24] ^ d[23] ^ d[22] ^ d[20] ^ d[18] ^ d[17] ^ d[14] ^ d[10] ^ d[9] ^ d[8] ^ d[7] ^ d[5] ^ d[3] ^ d[2];
         CRC4_result = Result;
      end
   endtask
	
endmodule
