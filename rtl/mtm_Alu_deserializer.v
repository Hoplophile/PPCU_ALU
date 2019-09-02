/******************************************************************************
 * (C) Copyright 2019 AGH UST All Rights Reserved
 *
 * MODULE:    mtm_Alu_deserializer
 * PROJECT:   PPCU_VLSI
 * AUTHORS:
 * DATE:
 * ------------------------------------------------------------------------------
 *
 *******************************************************************************/

//DEMUX STATES
`define IDLE 	2'b00
`define START	2'b01
`define READ	2'b10
`define STOP	2'b11

module mtm_Alu_deserializer(
	input wire clk,
	input wire rst,	
	input wire sin,		//serial input
	output reg [31:0] Aout	//A output
	output reg [31:0] Aout	//A output
	output reg [7:0] CTLout	//A output
);
	//todo liczenie, czy przyszło 8 ramek danych (flaga data error)
	
	reg [31:0] Aout_nxt;
	reg [31:0] Bout_nxt;
	reg [31:0] CTLout_nxt;

	reg [3:0] bit_counter;
	reg [3:0] bit_counter_nxt;
	
	reg [3:0] packet_counter;
	reg [3:0] packet_counter_nxt;

	reg [2:0] demux_state;
	reg [2:0] demux_state_nxt;

	reg [98:0] full_msg;
	reg [98:0] full_msg_nxt;


	always @(posedge clk or posedge rst) begin
		if(!rst) begin
			Aout	<= 1;
			demux_state <= `IDLE;
			full_msg <= 0;
		end
		else begin
			Aout <= Aout_nxt
			demux_state <= demux_state_nxt;
			full_msg <= full_msg_nxt;
		end
	end

	always @* begin
		case(demux_state)
		'IDLE: begin
			Aout_nxt = Aout;
			bit_counter_nxt = 0;
			packet_counter_nxt = packet_counter;
			if(sin == 0) begin
				demux_state = `READ;
				full_msg_nxt = {full_msg, sin}
			end
			else begin
				demux_state = `IDLE;
			end
		end

		'READ: begin
			full_msg_nxt = {full_msg, sin};
			if(packet_counter <= 3) begin	//A comes
				A
			end
			bit_counter_nxt += 1;
			packet_counter_nxt = packet_counter;
			demux_state = (bit_counter == 8) ? `STOP : `READ;
		end

		'STOP: begin
		end			
		endcase
	end
endmodule

