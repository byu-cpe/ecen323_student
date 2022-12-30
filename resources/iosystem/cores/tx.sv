//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: tx.v
//
//  Author: Mike Wirthlin
//  
//////////////////////////////////////////////////////////////////////////////////

module tx(clk, din, send, odd, tx_out, busy);
	
	parameter CLK_FREQUECY = 100000000;
    parameter BAUD_RATE = 19200;
    parameter INCORRECT_PARITY = 0;   // set to 1 to simulate incorrect parity
    parameter INCORRECT_BIT_ORDER = 0;    // set to 1 to simulate sending bits in reverse order
    parameter INCORRECT_BAUD_RATE_MULTIPLIER = 1;  // set to higher than 1 or less than one to simulate errors
    
	// Ports and parameters
	input logic clk, send, odd;
	input logic [7:0] din;
	output logic  busy;
	output logic tx_out;

	// Ceiling log2b function
    function integer clogb2;
        input [31:0] value;
        begin
            value = value - 1;
            for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1) begin
                value = value >> 1;
            end
        end
    endfunction
    
    // Local parameters (constants)
	localparam BIT_COUNTER_MAX_VAL = INCORRECT_BAUD_RATE_MULTIPLIER * CLK_FREQUECY / BAUD_RATE - 1;
	localparam BIT_COUNTER_BITS = clogb2(BIT_COUNTER_MAX_VAL);

    // FSM constants
	localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam COUNT = 3'b010;
    localparam SHIFT = 3'b011;
    localparam WAIT = 3'b100;
    
    // Internal Sequential Signals
    reg [BIT_COUNTER_BITS-1:0] baud_counter = 0;
    reg [3:0] bit_counter = 0;
    reg [9:0] shift_register = 10'b111111111;
    reg [2:0] state = IDLE;
    reg [2:0] next_state;

    reg Load, ResetCounter, ResetTimer, EnableTimer, Shift, NextBit;
    wire LastCycle, LastBit;
    wire ParityBit;
    
	// Baud Rate Timer
    always@(posedge clk)
        if (ResetTimer == 1'b1)
            baud_counter <= 0;
        else if (EnableTimer == 1'b1)
            baud_counter <= baud_counter + 1;
    assign LastCycle = (baud_counter == BIT_COUNTER_MAX_VAL) ? 1'b1 : 1'b0;

	// Bit Counter
	always@(posedge clk)
	   if (ResetCounter == 1'b1)
	       bit_counter <= 0;
	   else if (NextBit == 1'b1)
	       bit_counter <= bit_counter + 1;
	assign LastBit = (bit_counter == 10) ? 1'b1 : 1'b0;


    // Parity Generator
    assign ParityBit = (^din)^(odd)^INCORRECT_PARITY;

	// shift register
	always@(posedge clk)
		if (Load == 1'b1)
		    if (INCORRECT_BIT_ORDER) // simulate incorrect ordering of bits
    			shift_register <= {ParityBit,{din[0],din[1],din[2],din[3],din[4],din[5],din[6],din[7]},1'b0};
		    else // normal operation
    			shift_register <= {ParityBit,din,1'b0};
		else if (Shift == 1'b1)
			shift_register <= {1'b1,shift_register[9:1]};
			
    assign tx_out = shift_register[0];

	// FSM
	always @(posedge clk)
	begin
       state <= next_state;
	end
	
	// Next state logic and outputs
	always @(*)
	begin
		// Default values
		Load = 1'b0;
		busy = 1'b1;
	    ResetCounter = 1'b0;
	    ResetTimer = 1'b0;
        EnableTimer = 1'b0;
	    Shift = 1'b0;
	    NextBit = 1'b0;
		next_state = state;
	
		case(state)
			IDLE: begin
				busy = 1'b0;
				if (send == 1'b1) begin
					next_state = LOAD;
			        Load = 1'b1;
				end
			end
			LOAD: begin
			    ResetCounter = 1'b1;
			    ResetTimer = 1'b1;
			    next_state = COUNT;
		    end
            COUNT: begin
                EnableTimer = 1'b1;
				if (LastCycle == 1'b1) begin
					next_state = SHIFT;
				end
			end
			SHIFT: begin
			    Shift = 1'b1;
			    ResetTimer = 1'b1;
			    NextBit = 1'b1;
				if (LastBit == 1'b1)
					next_state = WAIT;
				else
				    next_state = COUNT;
			end
			WAIT:
				if (send == 1'b0)
					next_state = IDLE;
            //default:
		endcase
	end

endmodule