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

    task sim_op(input [2:0] func);
		tb_func = func;
        tb_sw = $urandom_range(0,65535);
		sim_clocks($urandom_range(2,7));
        tb_op = 1;
		sim_clocks($urandom_range(4,30));
        tb_op = 0;
		sim_clocks($urandom_range(4,30));
    endtask

    localparam BUTTONOP_ADD = 3'b000;
    localparam BUTTONOP_SUB = 3'b001;
    localparam BUTTONOP_AND = 3'b010;
    localparam BUTTONOP_OR  = 3'b011;
    localparam BUTTONOP_XOR = 3'b100;
    localparam BUTTONOP_LT  = 3'b101;

	initial begin
	    int i,j;
	     
        //shall print %t with scaled in ns (-9), with 2 precision digits, and would print the " ns" string
		$timeformat(-9, 0, " ns", 20);
		$display("*** Start of Caclulator Testbench Simulation ***");
		
		// Run for some time without valid inputs
		#50
		
		// execute a few clocks without any reset
		sim_clocks(3);

		// Issue a reset and clock a few cycles
		tb_rst = 1;
		sim_clocks(2);
		tb_rst = 0;
		// set deaults
	    tb_func = 0;		
        tb_op = 0;
		sim_clocks(3);
		// Issue global reset
		tb_rst = 1;
		sim_clocks(1);
		tb_rst = 0;
		
        // Test all of the functions a number of times
        for(j=0; j < $urandom_range(10,20); j=j+1) begin
            sim_op(BUTTONOP_ADD);
            sim_op(BUTTONOP_SUB);
            sim_op(BUTTONOP_AND);
            sim_op(BUTTONOP_OR);
            sim_op(BUTTONOP_XOR);
            sim_op(BUTTONOP_LT);
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
	reg [15:0] accumulator = -1;
    logic ex_d, execute;
    logic addop_os, subop_os,andop_os, orop_os = 0;

	always_ff@(negedge clk) begin
        ex_d <= ex;
        execute <= ex & ~ex_d;
    end

	// checking state
	always@(negedge clk) begin
		if (initialized) begin
			if (accumulator != result) begin
				$display("*** Error: Module accunmulator=%0d but should be %0d at time %0t", accumulator, result, $time);
				if (stop_on_error)
					$finish;
			end
			if (^result[0] === 1'bX) begin
				$display("**** Error: 'x' Values on LEDs at time %0t", $time);
				$finish;
			end

		end
	end

	// accumulator
	always@(posedge clk)
		if (rst) accumulator <= 0;
		else if (ex)
            case (func)
                3'b000: accumulator <= accumulator + sw;
                3'b001: accumulator <= accumulator - sw;
                3'b010: accumulator <= accumulator & sw;
                3'b011: accumulator <= accumulator | sw;
                3'b100: accumulator <= accumulator ^ sw;
                3'b101: accumulator <= ($signed(accumulator) < $signed(sw)) ? 32'b1 : 32'b0;
                default: accumulator <= accumulator + sw;
            endcase

endmodule
