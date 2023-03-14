`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: tb_riscv.sv
//
//////////////////////////////////////////////////////////////////////////////////

// Instruction memory simulation model
// - Issues a $finish if the memory contents cannot be loaded
module instruction_memory(clk, rst, imem_read, pc, instruction);

    input logic clk, rst, imem_read;
    input logic [31:0] pc;
    output logic [31:0] instruction;

    parameter INSTRUCTION_MEMORY_WORDS = 1024;
    parameter TEXT_MEMORY_FILENAME = "";
	parameter PC_OFFSET = 32'h00000000;

    `include "tb_pipeline_inc.sv"

	// Instruction Memory
	reg [31:0] instruction_memory[INSTRUCTION_MEMORY_WORDS-1:0];

    // Initialize instruction memory
	initial begin
		$readmemh(TEXT_MEMORY_FILENAME, instruction_memory);
		if (^instruction_memory[0] === 1'bX) begin
			$display("**** Warning: Testbench failed to load the instruction memory. Make sure the %s file",TEXT_MEMORY_FILENAME);
			$display("**** is added to the project.");
			$finish;
		end
		else
			$display("**** Testbench: Loaded instruction memory ****");
	end
	
	// Instruction memory read (synchronous read). No writes
	// Read every clock cycle (even if we will end up ignoring NOP instructions that are read)
	always@(posedge clk or posedge rst) begin
		if (rst) begin
		  instruction <= NOP_INSTRUCTION;  // Initialize instruction with "NOP"
		end
	    else begin
			// Only read instruction if iMemRead is high
			if (imem_read)
				instruction <= instruction_memory[(pc-PC_OFFSET) >> 2];
		end
	end

endmodule

// Data memory simulation model
// - Issues a $finish if the memory contents cannot be loaded
module data_memory(clk, rst, read, write, address, read_data, write_data);

    input logic clk, rst, read, write;
    input logic [31:0] address, write_data;
    output logic [31:0] read_data;

    parameter DATA_MEMORY_WORDS = 256;
    parameter DATA_MEMORY_FILENAME = "";
	parameter DATA_SEGMENT_START_ADDRESSS = 32'h10010000;
	localparam DATA_SEGMENT_END_ADDRESSS = DATA_SEGMENT_START_ADDRESSS + DATA_MEMORY_WORDS*4-1;

    `include "tb_pipeline_inc.sv"

	reg [31:0] data_memory[DATA_MEMORY_WORDS-1:0];

	initial begin
		$readmemh(DATA_MEMORY_FILENAME, data_memory);
		if (^data_memory[0] === 1'bX) begin
			$display("**** Warning: Testbench failed to load the data memory. Make sure the %s file",DATA_MEMORY_FILENAME);
			$display("**** is added to the project.");
			$finish;
		end
		else
			$display("**** Testbench: Loaded data memory ****");
	end

	// Data memory access
	wire [31:0] local_dMem_Address;
	wire valid_dMem_Address;
	assign local_dMem_Address = (address-DATA_SEGMENT_START_ADDRESSS) >> 2;

	assign valid_dMem_Address = (address >= DATA_SEGMENT_START_ADDRESSS) && (address < DATA_SEGMENT_END_ADDRESSS);
	always@(posedge clk or posedge rst) begin
	   if (rst)
	       read_data <= 0; 
	   else
		if (read) begin
			if (valid_dMem_Address)
				read_data <= data_memory[local_dMem_Address];
			else
				read_data <= 32'hX;
		end else if (write) begin
			if (valid_dMem_Address)
				data_memory[local_dMem_Address] <= write_data;
			// If invalid just ignore write
		end
	end

endmodule
