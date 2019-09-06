`timescale 1ns/1ps


module mtm_Alu_serializer(
	input wire clk,
	input wire rst,	
	input wire [54:0] aluin,
	input wire dataready,				
	output reg sout

);
	
    reg [1:0] state, next_state;
	reg [54:0] buffer, buffer_next;
	reg[5:0] bit_counter, bit_counter_next;
	reg sout_next;
   
	
	parameter IDLE = 2'b00, SET_TYPE = 2'b01, FRAME = 2'b10;
  
    always @ (posedge clk) begin
		if (!rst) begin

			state <= IDLE;
            next_state <= IDLE;

            			
        end	else begin

            state <= next_state;   
			buffer <= buffer_next;        
			sout <= sout_next;  
			bit_counter <= bit_counter_next;

        end			
	end

    always @* begin
        
		buffer_next = buffer;
		sout_next = 1'b1;


        case (next_state)
            IDLE: begin      

				sout_next = 1'b1;
				bit_counter_next = 0;
				buffer_next = 0;
				
            end

            SET_TYPE: begin

				buffer_next = aluin;
				sout_next = 1'b1;
				
				if (aluin[8] == 1) begin
					bit_counter_next = 12;
				end else begin
					bit_counter_next = 56;
				end

        	end

			FRAME: begin

				bit_counter_next = bit_counter - 1;
				sout_next = buffer[bit_counter - 1];			
				              
        	end

			
        endcase
    end
	
	always @* begin
		case (state)

			IDLE: begin              
				if (dataready == 1) begin
					next_state = SET_TYPE;
				end else begin
					next_state = IDLE;
				end
            end

            SET_TYPE: begin

				next_state = FRAME;

        	end

			FRAME: begin
				if (bit_counter == 0) begin
					next_state = IDLE;					
				end else begin
					next_state = FRAME;
				end				              
        	end

			
            default:
                next_state = IDLE;

		endcase
	end

  
	
	
endmodule //deserializer




