`timescale 1ns/1ps


module mtm_Alu_deserializer(
	input wire clk,
	input wire rst,	
	input wire sin,				//serial input
	output reg [31:0] A,		//A output
	output reg [31:0] B,		//B output
	output reg [7:0] CTL		//CTL output
	
);
	
    reg [1:0] state, next_state;
    reg [31:0] buffA, buffB, next_buffA, next_buffB, next_A, next_B;
    reg [7:0] buffCTL, next_buffCTL, next_CTL;
    reg [3:0] bit_counter, next_bit_counter;
  	reg [3:0] byte_counter, next_byte_counter, CRC;	
	
	parameter IDLE = 2'b00, START = 2'b01, READ = 2'b10, ERROR = 2'b11;

  
    always @ (posedge clk) begin
		if (!rst) begin
			state <= IDLE;
            A <= 32'hFFFFFFFF;
            B <= 32'hFFFFFFFF;
            CTL <= 8'b11111111;

			next_state <= IDLE;
			bit_counter <= 0; 
			next_bit_counter <= 0;
			byte_counter <= 0; 
			next_byte_counter <= 0;
			next_A <= 32'hFFFFFFFF;
			next_B <= 32'hFFFFFFFF;
			next_CTL <= 8'b11111111;

			buffA <= 0;
			buffB <= 0;
			buffCTL <= 0;
			next_buffA <= 0;
			next_buffB <= 0;
			next_buffCTL <= 0;

        CRC <= 0;

        end	else begin

            state <= next_state;
            buffA <= next_buffA;
            buffB <= next_buffB;
            buffCTL <= next_buffCTL;
            bit_counter <= next_bit_counter;
            byte_counter <= next_byte_counter;
            A <= next_A;
            B <= next_B;
            CTL <= next_CTL;

        end			
	end
	
	always @* begin
		case (state)
			IDLE: // watiting for '0' start bit
				begin
                
                    next_bit_counter = 0;
                    
					
                    if (sin == 0) begin
                        next_state = START;
                    end else begin
                        next_state = IDLE;
                    end
                end


			START: // determine packet type, handle data errors
				begin

					next_A <= 32'hFFFFFFFF;
					next_B <= 32'hFFFFFFFF;
					next_CTL <= 8'b11111111;
					
                    // packet DATA not starting with 0 
                    if(byte_counter <= 7 && bit_counter == 0 && sin == 1) begin
                        next_CTL = 8'b11001001;
                        next_state = ERROR;
                    end
                    
                    // packet CTL not starting with 1
                    else if(byte_counter == 8 && bit_counter == 0 && sin == 0) begin
                        next_CTL = 8'b11001001;
                        next_state = ERROR;
                    end

                    // too many packets chyba źle
                    /*else if (sin == 0 && byte_counter == 9) begin
                         next_CTL = 8'b11001001;
                        next_state = ERROR;
                    end
                    */
                    
                    // packet starting correctly - read payload
                    else begin
                        next_bit_counter = bit_counter + 1;
                        next_state = READ;
                    end
                end


			READ:
				begin
					
                    if (bit_counter <= 8) begin
                        next_bit_counter = bit_counter + 1;
                        
                        if (byte_counter <= 3) begin
                            next_buffB = {buffB, sin};                            
                        end else if (byte_counter > 3 && byte_counter <= 7) begin
                            next_buffA = {buffA, sin}; 
                        end else if (byte_counter == 8) begin
                            next_buffCTL = {buffCTL, sin};
                        end
                    end else if (bit_counter == 9) begin // wrong closing bit
                        if(sin == 0) begin
                            next_CTL = 8'b11001001;
                            next_state = IDLE;
                            
                        end else if (byte_counter == 8) begin
                            next_buffA = 0;
                            next_buffB = 0;
                            next_buffCTL = 0;
							next_byte_counter = 0;

                            //CRC = nextCRC4_D68({B, A, 1'b1, buffCTL[6:4]}, 4'b0000);

							CRC4forData68({buffB,buffA,1'b1,buffCTL[6:4]}, CRC);

                            if(CRC == buffCTL[3:0]) begin
                                next_A = buffA;
                                next_B = buffB;
								
                                next_CTL = buffCTL;
                                next_state = IDLE;
                            end else begin
                                next_CTL = 8'b10100101;
                                next_state = IDLE;
                            end
                        end else begin
                            next_byte_counter = byte_counter + 1;
                            next_bit_counter = 0;
                            next_state = IDLE;
                        end
                    end
                    
                end
			ERROR:
				begin
                    if (bit_counter < 9) begin
                        next_bit_counter = bit_counter + 1;
                    end else begin
                        next_state = IDLE;
                        next_CTL = 8'b11111111;
                    end     
                end
		endcase
	end

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
	
	
endmodule //deserializer