`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: tb_calc.sv
//
//  Author: Mike Wirthlin
//  
//  Description: 
//
//  Version 1.0
//
//  1/11/2021
//
//////////////////////////////////////////////////////////////////////////////////

module tb_calc();

	//parameter numPulsesPerTest = 9;
	logic tb_clk, tb_rst, tb_op;
    logic [2:0] tb_func;
	logic [15:0] tb_count;
    logic [15:0] tb_sw;
	
	// Instance alu module
	calc my_calc(.clk(tb_clk), .btnu(tb_rst), .btnl(tb_func[2]), .btnc(tb_func[1]), .btnr(tb_func[0]), 
        .btnd(tb_op),   
        .sw(tb_sw), .led(tb_count));

	// Tester module
	ALUTester tester(.clk(tb_clk), .rst(tb_rst), .func(tb_func), .ex(tb_op), .sw(tb_sw), .result(tb_count));

    task sim_clocks(input int clocks);
		automatic int i;
		for(i=0; i < clocks; i=i+1) begin
			//@(negedge tb_clk);
            #5 tb_clk = 1; #5 tb_clk = 0;
        end
    endtask

	// Perform a simulation operation (random values)
    task sim_op(input [2:0] func);
		tb_func = func;
        tb_sw = $urandom_range(0,65535);
		sim_clocks($urandom_range(2,7));
        tb_op = 1;
		sim_clocks($urandom_range(6,30));
        tb_op = 0;
		sim_clocks($urandom_range(4,30));
    endtask

    localparam BUTTONOP_ADD = 3'b000;
    localparam BUTTONOP_SUB = 3'b001;
    localparam BUTTONOP_AND = 3'b010;
    localparam BUTTONOP_OR  = 3'b011;
    localparam BUTTONOP_XOR = 3'b100;
    localparam BUTTONOP_LT  = 3'b101;
    localparam BUTTONOP_SLL = 3'b110;
    localparam BUTTONOP_SRA = 3'b111;

	initial begin
	    int i,j;
	     
        //shall print %t with scaled in ns (-9), with 2 precision digits, and would print the " ns" string
		$timeformat(-9, 0, " ns", 20);
		$display("*** Start of Calculator Testbench Simulation ***");
		
		// Run for some time without valid inputs
		#50
		
		// execute a few clocks without any reset
		sim_clocks(3);

		// Issue a reset and clock a few cycles
		tb_rst = 1;
		sim_clocks(10);
		tb_rst = 0;
		// set deaults
	    tb_func = 0;		
        tb_op = 0;
		sim_clocks(3);

        // Test random function 10 times
        for(j=0; j < 10; j=j+1) begin
            sim_op($urandom_range(0,7));
        end

        // Issue reset to test reset functionality
		tb_rst = 1;
		sim_clocks(10);
		tb_rst = 0;

        // Test all of the functions a number of times
        for(j=0; j < $urandom_range(10,20); j=j+1) begin
            sim_op(BUTTONOP_ADD);
            sim_op(BUTTONOP_SUB);
            sim_op(BUTTONOP_AND);
            sim_op(BUTTONOP_OR);
            sim_op(BUTTONOP_XOR);
            sim_op(BUTTONOP_LT);
            sim_op(BUTTONOP_SLL);
            sim_op(BUTTONOP_SRA);
        end
        
        sim_clocks(100);

        // Test random function random number of times
        for(j=0; j < $urandom_range(50,60); j=j+1) begin
            sim_op($urandom_range(0,7));
        end


		// Issue global reset
		tb_rst = 1;
		sim_clocks(1);
		tb_rst = 0;

		// Random delay
		sim_clocks($urandom_range(50,150));		

		$display("*** Successful simulation. Final count=%0d. Ended at %0t *** ", tb_count, $time);
        $finish;
        
	end  // end initial

endmodule

// Behavioral module that will test UpDownButtonCount
module ALUTester(clk, rst, func, ex, sw, result);

    input wire logic clk;
    input wire logic rst;
    input wire logic [2:0] func;
    input wire logic ex;
    input [15:0] sw;
    input [15:0] result;
    
	parameter stop_on_error = 1;
	
	int initialized = 0;
    int op_delay = 0;
	reg [15:0] accumulator = -1;
    int ex_delay = 0;

	always_ff@(posedge clk) begin
        if (rst)
            initialized <= 1;
        if (ex)
            ex_delay <= ex_delay + 1;
        else
            ex_delay <= 0;
    end

	// checking state
    localparam delay_check = 2;
	always@(negedge clk) begin
		if (initialized && ex_delay == delay_check) begin
			if (accumulator != result) begin
				$display("*** Error: Module accumulator=%0x but should be %0x at time %0t", result, accumulator, $time);
				if (stop_on_error)
					$fatal;
			end
			if (^result[0] === 1'bX) begin
				$display("**** Error: 'x' Values on LEDs at time %0t", $time);
				if (stop_on_error)
					$fatal;
			end

		end
	end

    localparam BUTTONOP_ADD = 3'b000;
    localparam BUTTONOP_SUB = 3'b001;
    localparam BUTTONOP_AND = 3'b010;
    localparam BUTTONOP_OR  = 3'b011;
    localparam BUTTONOP_XOR = 3'b100;
    localparam BUTTONOP_LT  = 3'b101;
    localparam BUTTONOP_SLL = 3'b110;
    localparam BUTTONOP_SRA = 3'b111;


	// accumulator
	always@(posedge clk)
		if (rst) accumulator <= 0;
		else if (ex_delay == 1)
            case (func)
                BUTTONOP_ADD: accumulator <= accumulator + sw;
                BUTTONOP_SUB: accumulator <= accumulator - sw;
                BUTTONOP_AND: accumulator <= accumulator & sw;
                BUTTONOP_OR: accumulator <= accumulator | sw;
                BUTTONOP_XOR: accumulator <= accumulator ^ sw;
                BUTTONOP_LT: accumulator <= ($signed(accumulator) < $signed(sw)) ? 32'b1 : 32'b0;
                BUTTONOP_SLL: accumulator <= accumulator << sw[4:0];
                BUTTONOP_SRA: accumulator <= $unsigned($signed(accumulator) >>> sw[4:0]);
                default: accumulator <= accumulator + sw;
            endcase

endmodule
