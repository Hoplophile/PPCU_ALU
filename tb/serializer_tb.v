module mtm_Alu_serializer1
(
	input wire clk, reset,
	input wire [31:0] Cin,
	input wire [7:0] CTLin,
	output reg sout
);
	
	reg	[2:0] state, next_state;
	reg [2:0] bit_counter, next_bit_counter;
  	reg [3:0] byte_counter, next_byte_counter;
	reg [31:0] C;
	reg [7:0] CTL;
	
	parameter IDLE = 3'b000, SET_START_BIT = 3'b001, SET_PACKET_TYPE = 3'b010, TRANSMIT_DATA = 3'b011,
		TRANSMIT_COMMAND = 3'b100, TRANSMIT_ERROR = 3'b101, GET_NEXT_BYTE = 3'b110, SET_STOP_BIT = 3'b111;
	
	initial begin
		state = IDLE;
		next_state = IDLE;
		bit_counter = 0; 
		next_bit_counter = 0;
		byte_counter = 0; 
		next_byte_counter = 0;
	end

	always @ (posedge clk) begin
		if (reset == 1) begin
			state <= IDLE;
			bit_counter <= 0;
			next_bit_counter <= 0;
      		byte_counter <= 0;
			next_byte_counter <= 0;
			sout <= 1;
			C <= 0;
			CTL <= 0;
		end
		else begin 
			bit_counter <= next_bit_counter;
			byte_counter <= next_byte_counter;
			state <= next_state;
		end
		
	end

	always @* begin
		//next_state = state;
		case (state)
			IDLE: begin
				if( (CTLin[7] == 0) || CTLin[7:0] == 8'b11001001 || CTLin[7:0] == 8'b10010011 || CTLin[7:0] == 8'b10100101) begin
					next_bit_counter = 0;
					next_byte_counter = 0;
					C = Cin;
					CTL = CTLin;
					next_state = SET_START_BIT;
				end
				else sout = 1;
			end
			SET_START_BIT: begin
				next_bit_counter = 0;
				sout = 0;
				next_state = SET_PACKET_TYPE;
			end
			SET_PACKET_TYPE: begin
				if (CTL[7:0] == 8'b11001001 || CTL[7:0] == 8'b10010011 || CTL[7:0] == 8'b10100101) begin

					sout = 1;
					next_state = TRANSMIT_ERROR;

				end	else if (byte_counter == 4 ) begin

					sout = 1;
					next_state = TRANSMIT_COMMAND;
					
				end else begin
					sout = 0;
					next_state = TRANSMIT_DATA;
					

				end 
			end
			TRANSMIT_DATA: begin
				if (bit_counter == 7 ) begin

					sout = C[31 - (bit_counter + byte_counter*8)];
					next_bit_counter = bit_counter + 1;

					next_state = GET_NEXT_BYTE;
					next_byte_counter = byte_counter + 1;
				end else begin
					
					sout = C[31 - (bit_counter + byte_counter*8)];
					next_bit_counter = bit_counter + 1;
				end
			end
			TRANSMIT_COMMAND: begin
				if (bit_counter == 7) begin
					sout = CTL[(7 - bit_counter)];
					next_bit_counter = bit_counter + 1;
					next_state = SET_STOP_BIT;
				end else begin
					sout = CTL[(7 - bit_counter)];
					next_bit_counter = bit_counter + 1;
					
				end
			end

			TRANSMIT_ERROR: begin
				if (bit_counter == 7) begin
					sout = CTL[(7 - bit_counter)];
					next_bit_counter = bit_counter + 1;
					next_state = SET_STOP_BIT;
				end else begin
					sout = CTL[(7 - bit_counter)];
					next_bit_counter = bit_counter + 1;
					
				end
			end

			GET_NEXT_BYTE: begin
				sout = 1;
				if (byte_counter < 5) begin
					next_state = SET_START_BIT;
				end else begin 
					next_state = IDLE;
				end
			end

			SET_STOP_BIT: begin
				sout = 1;
				next_state = IDLE;
			end
		
		endcase
	end

	
	
endmodule

`timescale  1ns/1ns

module serializer_tb();

    reg clk, reset;
    reg [31:0] Cin;
    reg [7:0] CTLin;
    wire sout;


    mtm_Alu_serializer serializer (.clk(clk), .reset(reset), .Cin(Cin), 
                                    .CTLin(CTLin), .sout(sout));

   initial
        begin: CLOCK_GENERATOR
	clk=0;
	forever
	begin
	#5 clk = ~ clk;
	end
	
 end

    initial begin
        reset = 1;
        #400
        reset = 0;
        #400
        Cin = 32'b11110011001000101010110010101010; 
		CTLin = 8'b00101010;
		#50
		Cin = 0; CTLin = 0;
		#1200
		reset = 1;
		#200
		reset = 0;
        #400
        Cin = 0; CTLin = 8'b01001001;
       


    end

endmodule