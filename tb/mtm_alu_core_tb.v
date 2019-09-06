/******************************************************************************
 * (C) Copyright 2019 AGH UST All Rights Reserved
 *
 * MODULE:		mtm_Alu_core
 * PROJECT:		PPCU_VLSI
 * AUTHORS:		P. Ziebinski, S. Janik
 * DATE:
 * ------------------------------------------------------------------------------
 *
 *******************************************************************************/

//OPERATIONS
`define AND		3'b000
`define OR		3'b001
`define ADD		3'b100
`define SUB		3'b101

//FLAGS
`define CARRY		4'b1000
`define OVERFLOW	4'b0100
`define ZERO		4'b0010
`define NEGATIVE	4'b0001

//ERROR FLAGS
`define ERR_DATA	6'b100100
`define ERR_CRC		6'b010010
`define ERR_OP		6'b001001

//OTHERS
`define PARITY		1'b1


module mtm_Alu_core(
	input wire clk,
	input wire rst,	
	input wire [5:0] ERR_FLAGS_in,
	input wire [2:0] OP,		//operation selection
	input wire [31:0] A, B,	//input values
	output reg [31:0] C,	//operation result
	output reg [7:0] CTL	//operation flags or errors
	);

	reg [3:0] FLAGS;
	reg [3:0] FLAGS_nxt;
	
	reg [5:0] ERR_FLAGS;
	reg [5:0] ERR_FLAGS_nxt;
	
	reg [31:0] C_nxt;
	reg [7:0] CTL_nxt;
	
	reg CARRIAGE;

	always @(posedge clk or posedge rst) begin
		if(!rst) begin
			C	 			<= 0;
			CTL				<= 0;
			FLAGS 			<= 0;
			ERR_FLAGS		<= ERR_FLAGS_in;
			ERR_FLAGS_nxt 	<= ERR_FLAGS_in;
			CARRIAGE		<= 0;
		end
		else begin
			C 			<= C_nxt;
			CTL 		<= CTL_nxt;
			FLAGS 		<= FLAGS_nxt;
			ERR_FLAGS	<= ERR_FLAGS_nxt;
		end
	end

	always @* begin
		if(ERR_FLAGS_in == 0) begin
			case(OP) 
			`AND: begin
				C_nxt = A & B;
				ERR_FLAGS_nxt = ERR_FLAGS;
				FLAGS_nxt = FLAGS;
			end

			`OR: begin
				C_nxt = A | B;
				ERR_FLAGS_nxt = ERR_FLAGS;
				FLAGS_nxt = FLAGS;
			end

			`ADD: begin
				assign {CARRIAGE, C_nxt} = {1'b0, A} + {1'b0, B};
				if(CARRIAGE != 1'b0) FLAGS_nxt = FLAGS | `OVERFLOW;
			end	
		
			`SUB: begin
				//if(B > A) FLAGS_nxt = FLAGS | `NEGATIVE;
				C_nxt = A - B;
			end

			default: begin
				ERR_FLAGS_nxt = ERR_FLAGS | `ERR_OP;
			end		
			endcase

			if(C_nxt == 0) FLAGS_nxt = FLAGS | `ZERO;
			if(ERR_FLAGS_nxt == 0) CTL_nxt = {1'b0, FLAGS_nxt, nextCRC3_D36({C_nxt, 1'b0, FLAGS_nxt}, 4'b0000)};
			else CTL_nxt = {1'b1, ERR_FLAGS_nxt, `PARITY};
		end
		else begin
			ERR_FLAGS_nxt = ERR_FLAGS_in;
			CTL_nxt = {1'b1, ERR_FLAGS_nxt, `PARITY};
		end
	end
	
	
	function [2:0] nextCRC3_D36;
		input [35:0] Data;
		input [2:0] crc;
		reg [35:0] d;
		reg [2:0] c;
		reg [2:0] newcrc;
		
		begin
			d = Data;
			c = crc;

			newcrc[0] = d[35] ^ d[32] ^ d[31] ^ d[30] ^ d[28] ^ d[25] ^ d[24] ^ d[23] ^ d[21] ^ d[18] ^ d[17] ^ d[16] ^ d[14] ^ d[11] ^ d[10] ^ d[9] ^ d[7] ^ d[4] ^ d[3] ^ d[2] ^ d[0] ^ c[2];
			newcrc[1] = d[35] ^ d[33] ^ d[30] ^ d[29] ^ d[28] ^ d[26] ^ d[23] ^ d[22] ^ d[21] ^ d[19] ^ d[16] ^ d[15] ^ d[14] ^ d[12] ^ d[9] ^ d[8] ^ d[7] ^ d[5] ^ d[2] ^ d[1] ^ d[0] ^ c[0] ^ c[2];
			newcrc[2] = d[34] ^ d[31] ^ d[30] ^ d[29] ^ d[27] ^ d[24] ^ d[23] ^ d[22] ^ d[20] ^ d[17] ^ d[16] ^ d[15] ^ d[13] ^ d[10] ^ d[9] ^ d[8] ^ d[6] ^ d[3] ^ d[2] ^ d[1] ^ c[1];
			nextCRC3_D36 = newcrc;
		end
	endfunction
	
endmodule


`timescale  1ns/1ns

module mtm_alu_Core_tb();

reg clk;
reg rst;	
reg [5:0] ERR_FLAGS_in;
reg [2:0] OP;	
reg [31:0] A, B;	
wire [31:0] C;
wire [7:0] CTL;

mtm_Alu_core alu (.clk(clk), .rst(rst), .ERR_FLAGS_in(ERR_FLAGS_in), .OP(OP), .A(A), .B(B),
                    .C(C), .CTL(CTL) );

    initial 
    begin: CLOCK_GENERATOR
	        clk=0;
	forever	begin
	    #5 clk = ~ clk;
	end
end  

    initial begin

        rst = 0;
        #40
        rst = 1;
        #40
        OP = 3'b001;
        A = 32'b00000000000000000000000000000111;
        B = 32'b00000000000000000000000000000001;
        ERR_FLAGS_in = 0;
        #100
        rst = 0;
        #100
        rst = 1;
        #40
        OP = 3'b000;
        A = 32'b00000000000000000000000000000111;
        B = 32'b00000000000000000000000000000001;
        ERR_FLAGS_in = 0;
        #100
        rst = 0;
        #100
        rst = 1;
        #40
        OP = 3'b100;
        A = 32'b00000000000000000000000000000111;
        B = 32'b00000000000000000000000000000001;
        ERR_FLAGS_in = 0;
        #100
        rst = 0;
        #100
        rst = 1;
        #40
        OP = 3'b101;
        A = 32'b00000000000000000000000000010111;
        B = 32'b00000000000000000000000000001001;
        ERR_FLAGS_in = 0;
        #100
        rst = 0;
        #100
        rst = 1;

    end

endmodule // mtm_alu_Core_tb