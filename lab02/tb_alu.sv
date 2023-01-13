`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: tb_alu.sv
//
//  Author: Mike Wirthlin
//  
//  Description: 
//
//  Version 1.0
//
//  4/30/2020
//
//////////////////////////////////////////////////////////////////////////////////

module tb_alu();

	logic tb_zero;
	logic [31:0] tb_op1, tb_op2, tb_result;
	logic [3:0] tb_alu_op;

	int errors = 0;

	localparam[3:0] UNDEFINED_OP1 = 4'b0100;
	localparam[3:0] UNDEFINED_OP2 = 4'b0101;
	localparam[3:0] UNDEFINED_OP3 = 4'b0011;
	localparam[3:0] UNDEFINED_OP4 = 4'b1011;
	localparam[3:0] UNDEFINED_OP5 = 4'b1100;
	localparam[3:0] UNDEFINED_OP6 = 4'b1110;
	localparam[3:0] UNDEFINED_OP7 = 4'b1111;
	localparam[3:0] ALUOP_AND = 4'b0000;
	localparam[3:0] ALUOP_OR = 4'b0001;
	localparam[3:0] ALUOP_ADD = 4'b0010;
	localparam[3:0] ALUOP_SUB = 4'b0110;
	localparam[3:0] ALUOP_LT = 4'b0111;
	localparam[3:0] ALUOP_SRL = 4'b1000;
	localparam[3:0] ALUOP_SLL = 4'b1001;
	localparam[3:0] ALUOP_SRA = 4'b1010;
	localparam[3:0] ALUOP_XOR = 4'b1101;

	// Constants for the operands of the deterministic ALU test
	localparam[31:0] OP1_VAL = 32'h12345678;
	localparam[31:0] OP2_VAL = 32'h2456fdec;
	// Number of random tests per ALU op
	localparam NUM_RANDOM_TESTS = 10;

    localparam non_specified_alu_op_tests = 2;
    localparam specified_alu_op_tests = 16;


	// Function to check if inputs are defined
    function logic [15:0] inputs_defined();
        inputs_defined = 1;
		if (^tb_op1 === 1'bX || ^tb_op2 === 1'bX || ^tb_alu_op === 1'bX)
			inputs_defined = 0;
    endfunction

	// function to check if the outputs are defined
    function logic [15:0] results_defined();
		if (^tb_result === 1'bX)
			results_defined = 0;
		else
			results_defined = 1;
    endfunction

	// Task for simulating a single ALU operation
	task sim_alu_op;
		input [3:0] operation;
		input [31:0] operand1, operand2;
		begin
			#10
			tb_op1 = operand1;
			tb_op2 = operand2;
			tb_alu_op = operation;
			#5
			;
		end
	endtask

	// Task for simulating a single ALU operation multiple times with random inputs
	task sim_alu_op_random;
		input [3:0] operation;
		input int num_tests;
		int i;
		begin
			for(i=0; i < num_tests; i=i+1) begin
				#10
				sim_alu_op(operation,$urandom,$urandom);
			end
		end
	endtask

	// Instance alu module
	alu alu_dut(.op1(tb_op1), .op2(tb_op2), .alu_op(tb_alu_op),
		.result(tb_result), .zero(tb_zero));

	// Start of simulation
	initial begin
	    int i,j,test_count;
	     
        //shall print %t with scaled in ns (-9), with 2 precision digits, and would print the " ns" string
		$timeformat(-9, 0, " ns", 20);
		$display("*** Start of ALU Testbench Simulation ***");
		
		// Run for some time without valid inputs
		#50
		
		// Set values to all zero
		tb_alu_op = 0;
		tb_op1 = 0;
		tb_op2 = 0;
		#50

		// Perform a few deterministic tests with no random inputs
		sim_alu_op(ALUOP_AND, OP1_VAL, OP2_VAL);
		sim_alu_op(ALUOP_OR, OP1_VAL, OP2_VAL);
		sim_alu_op(ALUOP_ADD, OP1_VAL, OP2_VAL);
		sim_alu_op(ALUOP_SUB, OP1_VAL, OP2_VAL);
		sim_alu_op(ALUOP_LT, OP1_VAL, OP2_VAL);
		sim_alu_op(ALUOP_SRL, OP1_VAL, OP2_VAL);
		sim_alu_op(ALUOP_SLL, OP1_VAL, OP2_VAL);
		sim_alu_op(ALUOP_SRA, OP1_VAL, OP2_VAL);
		sim_alu_op(ALUOP_XOR, OP1_VAL, OP2_VAL);

		// Test all control inputs with random stimulus
		sim_alu_op_random(ALUOP_AND, NUM_RANDOM_TESTS);
		sim_alu_op_random(ALUOP_OR, NUM_RANDOM_TESTS);
		sim_alu_op_random(ALUOP_ADD, NUM_RANDOM_TESTS);
		sim_alu_op_random(ALUOP_SUB, NUM_RANDOM_TESTS);
		sim_alu_op_random(ALUOP_LT, NUM_RANDOM_TESTS);
		sim_alu_op_random(ALUOP_SRL, NUM_RANDOM_TESTS);
		sim_alu_op_random(ALUOP_SLL, NUM_RANDOM_TESTS);
		sim_alu_op_random(ALUOP_SRA, NUM_RANDOM_TESTS);
		sim_alu_op_random(ALUOP_XOR, NUM_RANDOM_TESTS);

		// Wrap up tests
		#200
		tb_op1 = 32'h1;
		tb_op2 = 32'hffffffff; // -1
		tb_alu_op = ALUOP_ADD;

		$display("*** Simulation Complete ***");
		if (errors != 0) begin
			$error("  *** %0d Errors ***",errors);
			$fatal;
		end
        $finish;
        
	end  // end initial

	logic expected_zero;
	assign expected_zero = (tb_result == 0);
	// Check the zero output
	always@(tb_alu_op, tb_op1, tb_op2) begin
		// Wait 5 ns after op has changed
		#5
		// See if any of the inputs are 'x'. If so, ignore
		if (inputs_defined()) begin
			if ((tb_zero == 1'bz) || (tb_zero == 1'bx)) begin
		        $error("[%0t] Error: Invalid 'zero' value", $time);
				$fatal;
				errors = errors + 1;
			end
			else begin
				if (tb_zero != expected_zero) begin
		        	$error("[%0t] Error: Invalid 'zero' value %x but expecting %x", $time, tb_zero, expected_zero);
					$fatal;
					errors = errors + 1;
				end
			end
		end
	end


	// Check the result
	logic [31:0] expected_result;
	always@(tb_alu_op, tb_op1, tb_op2) begin
		// Wait 5 ns after op has changed
		#5
		// See if any of the inputs are 'x'. If so, ignore
		if (inputs_defined()) begin
			if (!results_defined()) begin
		        $error("[%0t] Error: Invalid result (x's)", $time);
				$fatal;
			end
			else begin
				case(tb_alu_op)
					ALUOP_AND: expected_result = tb_op1 & tb_op2;
					ALUOP_OR: expected_result = tb_op1 | tb_op2;
					ALUOP_ADD: expected_result = tb_op1 + tb_op2;
					ALUOP_SUB: expected_result = tb_op1 - tb_op2;
					ALUOP_LT: expected_result = ($signed(tb_op1) < $signed(tb_op2)) ? 32'd1 : 32'd0;
					ALUOP_SRL: expected_result = tb_op1 >> tb_op2[4:0]; 
					ALUOP_SLL: expected_result = tb_op1 << tb_op2[4:0]; 
					ALUOP_SRA: expected_result = $unsigned($signed(tb_op1) >>> tb_op2[4:0]); 
					ALUOP_XOR: expected_result = tb_op1 ^ tb_op2; 
					default: expected_result = tb_op1 + tb_op2;
				endcase
				if (tb_result != expected_result) begin
		        	$error("[%0t] Error: Invalid 'result' value %x but expecting %x", $time, tb_result, expected_result);
					$fatal;
					errors = errors + 1;
				end
			end
		end
	end

endmodule
