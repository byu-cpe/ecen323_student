///////////////////////////////////////////////////////////////////////////////////////////////
// 
// Filename: riscv_mem.sv
//
// Author: Mike Wirthlin
// Date: 2/4/2022
//
// Instruction and data memory for the RISC-V procssor.
//
///////////////////////////////////////////////////////////////////////////////////////////////

module riscv_mem (clk, rst, PC, iMemRead, instruction, dAddress, MemWrite, dWriteData, dReadData);

    input logic clk, rst;
    input logic [31:0] PC;
    input logic iMemRead;
    input logic [31:0] dAddress;
    input logic MemWrite;
    input logic [31:0] dWriteData;
    output logic [31:0] instruction;
    output logic [31:0] dReadData;

    // Parameters
    parameter INSTRUCTION_BRAMS = 2;
    parameter DATA_BRAMS = 2;
    parameter TEXT_MEMORY_FILENAME = "";
    parameter DATA_MEMORY_FILENAME = "";
    parameter TEXT_START_ADDRESS = 32'h00400000;
    parameter DATA_START_ADDRESS = 32'h00800000;
    
    // Local constants
	localparam INSTRUCTION_WORDS = INSTRUCTION_BRAMS*1024;
	localparam INSTRUCTION_ADDR_BITS = 11 + INSTRUCTION_BRAMS; // 1 BRAM = 2^12 (11:0)
	localparam DATA_WORDS = DATA_BRAMS*1024;
	localparam DATA_ADDR_BITS = 11 + DATA_BRAMS;
	localparam NOP_INSTRUCTION = 32'h00000013;

	// Instruction memory (use property to make sure it is mapped to a BRAM)
    (* rom_style = "block" *) reg [31:0] inst_memory [0:INSTRUCTION_WORDS-1];
	// Data memory
    logic [31:0] data_memory [0:DATA_WORDS-1];

	// Initialize instruction memory
    initial
    begin
		integer i;

		// Load the Instruction Memory
		if (TEXT_MEMORY_FILENAME == "") begin
			$display("**** Top-Level I/O System: No instruction memory defined");
			$finish;
		end
		else begin
			// Initialize memory with NOPs
			for (i = 0; i < INSTRUCTION_WORDS; i=i+1)
				inst_memory[i] = NOP_INSTRUCTION;
			// Update memory with contents of memory file
        	$readmemh(TEXT_MEMORY_FILENAME,inst_memory);
		end

		// Debug messages for simulation

		// synthesis translate_off
		if (^inst_memory[0] === 1'bX || inst_memory[0] == NOP_INSTRUCTION ) begin
			$display("**** Top-Level I/O System: Error - Instruction memory file '%s' failed to load ****",TEXT_MEMORY_FILENAME);
			$finish;
		end
		else
			$display("**** Top-Level I/O System: Instruction memory file '%s' loaded ****",TEXT_MEMORY_FILENAME);
		// synthesis translate_on
    end


	// Initialize data memory
    initial
    begin

		// Load the Data Memory
		if (DATA_MEMORY_FILENAME == "") begin
			$display("**** Top-Level I/O System: Warning: No data memory defined");
		end else begin
        	$readmemh(DATA_MEMORY_FILENAME,data_memory);
		end

		// Debug messages for simulation

		// synthesis translate_off
		if (DATA_MEMORY_FILENAME != "")
			if (^data_memory[0] === 1'bX) begin
				$display("**** Top-Level I/O System: Error - Simulation model instruction memory %s failed to load****",DATA_MEMORY_FILENAME);
				$finish;
			end
			else
				$display("**** Top-Level I/O System: Data memory file '%s' loaded ****",DATA_MEMORY_FILENAME);
		else
				$display("**** No Data memory contents defined - no initalialization ****");
		// synthesis translate_on
    end



	// Instruction Memory Read (synchronous)
	logic valid_upper_text_address;
    assign valid_upper_text_address =
		(PC[31:INSTRUCTION_ADDR_BITS] == TEXT_START_ADDRESS[31:INSTRUCTION_ADDR_BITS]);

    always_ff @(posedge clk)
    begin
		// Force a reset on the synchronous output register. This will act sort of like act
		// "NOP" in the pipeline for the first instruction.
		if (rst)   
			instruction <= 0;// only supports reset to zero, not a non-zero value
        else if(iMemRead == 1 && valid_upper_text_address)
            instruction <= inst_memory[PC[INSTRUCTION_ADDR_BITS-1:2]];            
    end

    // Data Memory
    logic data_space_mem;
	assign data_space_mem = 
		(dAddress[31:DATA_ADDR_BITS] == DATA_START_ADDRESS[31:DATA_ADDR_BITS]);

	// Data Memory Read (synchronous)
    always_ff @(posedge clk)
    begin
        if(MemWrite == 1 && data_space_mem)
            data_memory[dAddress[DATA_ADDR_BITS-1:2]] <= dWriteData;
        dReadData <= data_memory[dAddress[DATA_ADDR_BITS-1:2]];   
    end


endmodule