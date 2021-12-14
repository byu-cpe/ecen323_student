// This timescale statement indicates that each time tick of the simulator
// is 1 nanosecond and the simulator has a precision of 1 picosecond. This 
// is used for simulation and all of your SystemVerilog files should have 
// this statement at the top. 
`timescale 1 ns / 1 ps 

/***************************************************************************
* 
* Module: ButtonCount.sv
*
* Author: Professor Mike Wirthlin
* Class: ECEN 323, Winter Semester 2020
* Date: 12/10/2020
*
* Description:
*    This module includes a state machine that will provide a one cycle
*    signal every time the center button (btnc) is pressed (this is sometimes
*    called a 'single-shot' filter of the button signal). This signal
*    is used to increment a counter that is displayed on the LEDs. The
*    bottom button (btnb) is used as an asynchronous reset.
*
*    This module is used to help students review their RTL design skills and
*    get the design tools working.  
*
****************************************************************************/

module ButtonCount(clk, btnc, btnu, led);

	input wire logic clk, btnc, btnu;
	output logic [15:0] led;
	
    // Constants for the state machine state assignments.
    //  CODING STANDARD: You should always use a named constant (localparam)
    //  rather than "magic constants" in the body of your RTL code.
	localparam ZERO = 2'b00;
	localparam INC = 2'b01;
	localparam ONE = 2'b10;

    // The internal 16-bit count signal. 
	logic [15:0] count_i;
    // The increment counter output from the state machine
	logic inc_count;
    // The current state and next state of the state machine
	logic [1:0] state, next_state;

    logic rst, inc;

    assign rst = btnc;
    assign inc = btnu;

	// 16-bit Counter. Increments once each time button is pressed. 
    //
    // This is an exmaple of a 'sequential' statement that will synthesize flip-flops
    // as well as the logic for incrementing the count value.
    //
    //  CODING STANDART: Every "segment/block" of your RTL code must have at least
    //  one line of white space between it and the previous and following block. Also,
    //  ALL always blocks must have a coment.
	always_ff@(posedge clk)
		if (rst)
			count_i <= 0;
		else if (inc_count)
			count_i <= count_i + 1;
    
    // Assign the 'led' output the value of the internal count_i signal.
	assign led = count_i;

    // Button state machine
    //  This state machine is used to detect the first zero to one transition
    //  on the button input signal. When this transition occurs, the output signal
    //  will be asserted and used to increment the counter. This state machine is
    //  necessary to make sure that the counter is incremented only once for each
    //  button press. This is an exmaple of a "Moore" state machine (outputs only
    //  depend on current state and not the inputs).

	// State register for button state machine. This sequential code will synthesize
    // the flip flops for the state register.
	always_ff@(posedge clk)
		if (rst)
			state = ZERO;
		else
			state = next_state;

	// Next state logic for state machine
    //  This is a *combinational* circuit - no flip-flops or state are synthesized
    //  for this statement. 
	always_comb begin
        // Default assignment statement (stay in the same state)
		next_state = state;
        // Case statement for each state to override the default next_state
        // assignment.
		case(state)
            // The ZERO state occurs when the button is not pressed (zero) and 
            // will stay in this state until the button is first pressed.
			ZERO:
                // Transition to the INC state when the 'inc' signal is high
                // (otherwise stay in this state due to the default assignment statement)
				if (inc)
					next_state = INC;
            // The INC state occurs when the button is first pressed. The state machine
            // will only be in this state for one clock cycle and move directly to either the 
            // ONE state or the ZERO state.
			INC:
                if (inc)
				    next_state = ONE;
                else
                    next_state = ZERO;
            // The ONE state occurs when the button is being pressed. The state machine
            // will stay in this state until the button is released.
			ONE:
                // Transition to the ZERO state when the 'inc' signal is low. Otherwise
                //   stay in this state.
				if (!inc)
					next_state = ZERO;
		endcase
	end

    // Output forming logic. This combinational logic will set the value of the 
    // "inc_count" signal high when the current state of the state machine is in the
    // "INC" state. 
	assign inc_count = (state == INC);
	
endmodule