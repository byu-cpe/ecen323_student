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

    localparam non_specified_alu_op_tests = 2;
    localparam specified_alu_op_tests = 16;


    function logic [15:0] inputs_valid();
        inputs_valid = 1;
		if (^tb_op1 === 1'bX || ^tb_op2 === 1'bX || ^tb_alu_op === 1'bX)
			inputs_valid = 0;
    endfunction

    function logic [15:0] result_valid();
		if (^tb_result === 1'bX)
			result_valid = 0;
		else
			result_valid = 1;
    endfunction

	// Instance alu module
	alu alu_dut(.op1(tb_op1), .op2(tb_op2), .alu_op(tb_alu_op),
		.result(tb_result), .zero(tb_zero));

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

		// Test all control inputs 
		for(i=0; i < 16; i=i+1) begin
            #10
			tb_alu_op = i;
			$display("Testing alu_op ");
	        $display("[%0t] Testing alu op 0x%h", $time, tb_alu_op);
			// Perform fewer tests for non-specified op-codes
			if (i == UNDEFINED_OP1 || i == UNDEFINED_OP2 || i == UNDEFINED_OP3 || i == UNDEFINED_OP4 ||
				i == UNDEFINED_OP5 || i == UNDEFINED_OP6 || i == UNDEFINED_OP7)
				test_count = non_specified_alu_op_tests;
			else
				test_count = 16;
			for (j=0; j < test_count; j=j+1) begin
				#10
				// Generate random number for both operands
				tb_op1 = $urandom();
				tb_op2 = $urandom();
				// 10 ns delay
			end
		end

		// Wrap up tests
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
	always@(tb_alu_op) begin
		// Wait 5 ns after op has changed
		#5
		// See if any of the inputs are 'x'. If so, ignore
		if (inputs_valid()) begin
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
	always@(tb_alu_op) begin
		// Wait 5 ns after op has changed
		#5
		// See if any of the inputs are 'x'. If so, ignore
		if (inputs_valid()) begin
			if (!result_valid()) begin
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
