`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: riscv_final_tb.v
//
//////////////////////////////////////////////////////////////////////////////////

module riscv_final_tb ();

	parameter TEXT_MEMORY_FILENAME = "final_text.mem";
	parameter DATA_MEMORY_FILENAME = "final_data.mem";
	parameter TEXT_SEGMENT_START_ADDRESSS = 32'h00000000; // 32'h00400000;
	parameter INSTRUCTION_MEMORY_WORDS = 1024;
	parameter DATA_MEMORY_WORDS = 2048;
	parameter DATA_SEGMENT_START_ADDRESSS = 32'h00002000;
	parameter MAX_INSTRUCTIONS = 1000000; //2000;
	localparam DATA_SEGMENT_END_ADDRESSS = DATA_SEGMENT_START_ADDRESSS + DATA_MEMORY_WORDS*4-1;

	reg clk, rst;
	wire [31:0] tb_PC, tb_ALUResult, tb_Address, tb_dWriteData, tb_WriteBackData;
	wire tb_MemRead, tb_MemWrite;
	wire tb_iMemRead;

	reg [31:0] tb_dReadData;
    reg [31:0] tb_instruction;
	integer i;
	wire [31:0] error_count;

	`include "../lab08/tb_pipeline_inc.sv"

	localparam EBREAK_INSTRUCTION = 32'h00100073;
	// Data memory

	// Instance student processor module
	riscv_final #(.INITIAL_PC(TEXT_SEGMENT_START_ADDRESSS))
		riscv(.clk(clk), .rst(rst), .instruction(tb_instruction), .iMemRead(tb_iMemRead), .PC(tb_PC),	
			.ALUResult(tb_ALUResult), .dAddress(tb_Address), .dWriteData(tb_dWriteData), .dReadData(tb_dReadData),
			.MemRead(tb_MemRead), .MemWrite(tb_MemWrite), .WriteBackData(tb_WriteBackData) );

	// Instance testbench simulation model
	riscv_final_sim_model #(.INITIAL_PC(TEXT_SEGMENT_START_ADDRESSS), 
							.DATA_MEMORY_START_ADDRESSS(DATA_SEGMENT_START_ADDRESSS), 
							.INSTRUCTION_MEMORY_WORDS(INSTRUCTION_MEMORY_WORDS),
							.DATA_MEMORY_WORDS(DATA_MEMORY_WORDS)
							) 
		riscv_model(.tb_clk(clk), .tb_rst(rst), 
		.rtl_PC(tb_PC), .rtl_Instruction(tb_instruction), .rtl_iMemRead(tb_iMemRead),
			.rtl_ALUResult(tb_ALUResult),
			.rtl_dAddress(tb_Address), .rtl_dWriteData(tb_dWriteData), .rtl_dReadData(tb_dReadData), 
			.rtl_MemRead(tb_MemRead), .rtl_MemWrite(tb_MemWrite), .rtl_WriteBackData(tb_WriteBackData),
			.inst_mem_filename(TEXT_MEMORY_FILENAME), .data_mem_filename(DATA_MEMORY_FILENAME),
			.error_count(error_count));

	// Instruction Memory
	instruction_memory #(.INSTRUCTION_MEMORY_WORDS(INSTRUCTION_MEMORY_WORDS),
		.TEXT_MEMORY_FILENAME(TEXT_MEMORY_FILENAME),
		.PC_OFFSET(TEXT_SEGMENT_START_ADDRESSS)) 
		imem(.clk(clk),.rst(rst),.imem_read(tb_iMemRead),.pc(tb_PC),.instruction(tb_instruction));

	// Data Memory	
	data_memory #(.DATA_MEMORY_WORDS(DATA_MEMORY_WORDS),
		.DATA_MEMORY_FILENAME(DATA_MEMORY_FILENAME),
		.DATA_SEGMENT_START_ADDRESSS(DATA_SEGMENT_START_ADDRESSS)
		) 
		dmem(.clk(clk),.rst(rst),.read(tb_MemRead),.write(tb_MemWrite),.address(tb_Address),
			.read_data(tb_dReadData),.write_data(tb_dWriteData));
	
	
	//////////////////////////////////////////////////////////////////////////////////
	//	Main
	//////////////////////////////////////////////////////////////////////////////////
	initial begin
		$display("===== RISCV FINAL TESTBENCH =====");
		$display(" use run -all");

		//////////////////////////////////
		//	Reset
		//$display("[%0tns]Reset", $time/1000.0);
		//dReadData = 0;
		rst <= 0;
		clk <= 0;
		#10;
		rst <= 1;
		#10;
		clk <= 1;
        #5;
        clk <= 0;
        rst <= 0;
        		
		#10;

		for(i=0;i<MAX_INSTRUCTIONS ; i = i+1) begin
			clk <=1; #5;
			clk <=0; #5;
		end

		if (i == MAX_INSTRUCTIONS) begin
			// Didn't reach EBREAK_INSTRUCTION
			$display("ERROR: Did not reach the EBREAK Instruction");
			if(error_count > 0)
				$display("ERROR: %1d instruction error(s) found!",error_count);
			else
				$display("No Instruction Errors");
		end
		else
			if(error_count > 0)
				$display("ERROR: %1d instruction error(s) found!",error_count);
			else 
				$display("You Passed!");
			
		
		$finish;
	end


	module riscv_final_sim_model
		(tb_clk, tb_rst, rtl_PC, rtl_Instruction, rtl_iMemRead, rtl_ALUResult, rtl_dAddress, rtl_dWriteData, 
		rtl_dReadData, rtl_MemRead, rtl_MemWrite, rtl_WriteBackData, inst_mem_filename, data_mem_filename, error_count);

		parameter INITIAL_PC = 32'h00400000;
		parameter DATA_MEMORY_START_ADDRESSS = 32'h10010000;
		parameter INSTRUCTION_MEMORY_WORDS = 1024;  // 4x1024 - 4096 bytes
		parameter DATA_MEMORY_WORDS = 256;

		input tb_clk, tb_rst;			// testbench clock and reset
		input [31:0] rtl_PC;			// PC from the RTL model (used for comparison)
		input [31:0] rtl_Instruction;	// Instruction from the RTL model
		input rtl_iMemRead;				// iMemRead signal from the model
		input [31:0] rtl_ALUResult;
		input [31:0] rtl_dAddress;
		input [31:0] rtl_dWriteData;
		input [31:0] rtl_dReadData;
		input [31:0] rtl_WriteBackData;
		input rtl_MemRead, rtl_MemWrite;
		input string inst_mem_filename, data_mem_filename;
		output [31:0] error_count;
		//input [31:0] pc_halt_address;
			
		`include "tb_pipeline_inc.sv"

		// Internal shadow state
		logic [31:0] int_reg [31:0];
		instruction_t instruction_id, instruction_ex, instruction_mem, instruction_wb;
		logic iMemRead;
		logic [31:0] if_PC, id_PC, ex_PC, mem_PC, wb_PC;	// PC from the simulation model
		logic [31:0] ex_read1, ex_read2, ex_operand1, ex_operand2, ex_immediate, ex_s_immediate, ex_u_immediate;
		logic [31:0] ex_branchjump_target, ex_alu_result, ex_write_data;
		logic [31:0] mem_dAddress, mem_dWriteData, mem_branchjump_target, mem_alu_result;
		logic mem_PC_changed, mem_branch_taken, wb_PC_changed;
		logic [31:0] wb_writedata, wb_dReadData, wb_alu_result;
		logic wb_RegWrite, mem_RegWrite;
		logic mem_MemRead, mem_MemWrite;
		reg [31:0] errors=0;
		logic load_use_condition, load_use;
		logic [1:0] forwardA, forwardB;
		wire insert_ex_bubble, insert_mem_bubble;
		
		assign error_count = errors;
		localparam sim_model_version = "Version 1.3";
		//localparam NOP_INSTRUCTION = 32'h00000013; // addi x0, x0, 0
		localparam EBREAK_INSTRUCTION = 32'h00100073;
		localparam EBREAK_OPCODE = 7'b1110011;
		localparam ECALL_INSTRUCTION = 32'h00000073;
		localparam UNKNOWN_INST = "ERROR: Unknown Instruction";

		initial begin
			$timeformat(-9, 0, " ns", 20);
			$display("===== RISC-V Final Simulation Model %s =====", sim_model_version);
		end
		
			
		// checking
		always@(negedge tb_clk) begin
			
			if ($time != 0 && !tb_rst) begin
			
				// Print the time and accumulated errors (so they can identify error #1)
				$display("%0t:",$time);
				//if (errors > 0)
				//	$display(" (%0d errors)",errors);
				//else
				//	$display("No Errors");
				
				// IF Stage Printing
				errors += if_stage_check(if_PC, rtl_PC, iMemRead, rtl_iMemRead);
					
				// ID Stage Printing (enable enhanced instructions)
				errors += id_stage_check(id_PC,instruction_id,rtl_Instruction,iMemRead,insert_ex_bubble,1);
				
				// EX Stage Printing
				errors += ex_stage_check(ex_PC,instruction_ex,ex_alu_result,rtl_ALUResult,mem_alu_result,
					wb_writedata, forwardA, forwardB, insert_mem_bubble);

				// MEM Stage Printing
				errors += mem_stage_check(mem_PC,instruction_mem,mem_dAddress,mem_dWriteData,rtl_dAddress,rtl_dWriteData,
					rtl_MemRead, rtl_MemWrite, mem_branch_taken);

				// WB Stage Printing
				errors += wb_stage_check(wb_PC,instruction_wb,wb_writedata,rtl_WriteBackData,wb_RegWrite);
				
			end
			if (errors > 0) begin
				$display("*** Error: Simulation Stopped due to errors ***");
				$finish;
			end
		end

		///////
		// IF
		///////
		assign iMemRead = !load_use;
		always@(posedge tb_clk) begin
			if (tb_rst) begin
				if_PC <= INITIAL_PC;
				id_PC <= 32'hxxxxxxxx;
			end else begin
				if (iMemRead) begin
					if (mem_PC_changed)
						if_PC <= mem_branchjump_target;			
					else
						if_PC <= if_PC + 4;			
					id_PC <= if_PC;
				end
			end
		end
			
		// Simulation Instruction Memory
		instruction_memory #(.INSTRUCTION_MEMORY_WORDS(INSTRUCTION_MEMORY_WORDS),
			.TEXT_MEMORY_FILENAME(TEXT_MEMORY_FILENAME),
			.PC_OFFSET(TEXT_SEGMENT_START_ADDRESSS)) 
			imem(.clk(tb_clk),.rst(tb_rst),.imem_read(iMemRead),.pc(if_PC),.instruction(instruction_id));
		
		///////
		// ID
		///////
		logic [4:0] id_rs1;
		assign id_rs1 = (instruction_id.itype.opcode == LUI_OPCODE) ? 0 :  instruction_id.rtype.rs1;	
		
		always@(posedge tb_clk) begin
			if (tb_rst) begin
				// clear contents of registers
				for (int i = 0; i < 32; i=i+1)
					int_reg[i] = 0;
				ex_read1 <= 0;
				ex_read2 <= 0;
			end
			else begin
				// register reads
				ex_read1 <= int_reg[id_rs1];
				ex_read2 <= int_reg[instruction_id.rtype.rs2];
				// register writes
				if (wb_RegWrite)
				begin				
					int_reg[instruction_wb.rtype.rd] = wb_writedata;
					if (instruction_id.rtype.rs1 == instruction_wb.rtype.rd)
						ex_read1 <= wb_writedata;
					if (instruction_id.rtype.rs2 == instruction_wb.rtype.rd)
						ex_read2 <= wb_writedata;					
				end
			end
		end

		// Registers
		assign insert_ex_bubble = load_use || mem_PC_changed || wb_PC_changed ;
		always@(posedge tb_clk) begin
			if (tb_rst) begin
				instruction_ex <= NOP_INSTRUCTION;
				ex_PC <= 32'hxxxxxxxx;
			end
			else if (insert_ex_bubble) begin
				instruction_ex <= NOP_INSTRUCTION;
				ex_PC <= 32'hxxxxxxxx;
			end
			else begin
				instruction_ex <= instruction_id;
				ex_PC <= id_PC;
			end
		end

		///////
		// EX
		///////

		always@(*) begin
		
			// Immediate
			ex_immediate = {{20{instruction_ex.itype.imm[11]}},instruction_ex.itype.imm};
			ex_s_immediate = {{20{instruction_ex.stype.imm11_5[11]}},instruction_ex.stype.imm11_5,instruction_ex.stype.imm4_0};
			ex_u_immediate = {instruction_ex.utype.imm,12'h000};

			
			// Operand 1 (forwarding logic)
			forwardA = 0;
			if (mem_RegWrite && instruction_mem.itype.rd != 0 && 
				instruction_mem.itype.rd == instruction_ex.rtype.rs1) begin
				ex_operand1 = mem_alu_result;
				forwardA = 1;
			end else if (wb_RegWrite && instruction_wb.itype.rd != 0 && 
				instruction_wb.itype.rd == instruction_ex.rtype.rs1) begin
				ex_operand1 = wb_writedata;
				forwardA = 2;
			end else if (instruction_ex.itype.opcode == LUI_OPCODE)
				ex_operand1 = 0;
			else
				ex_operand1 = ex_read1;
				
			// Operand 2 (forwarding logic)
			forwardB = 0;
			if (instruction_ex.itype.opcode == I_OPCODE ||
						instruction_ex.itype.opcode == L_OPCODE)
				ex_operand2 = ex_immediate;
			else if (instruction_ex.utype.opcode == LUI_OPCODE)
				ex_operand2 = ex_u_immediate;
			else if (mem_RegWrite && instruction_mem.itype.rd != 0 && 
					instruction_mem.itype.rd == instruction_ex.rtype.rs2) begin
				ex_operand2 = mem_alu_result;
				forwardB = 1;
			end else if (wb_RegWrite && instruction_wb.itype.rd != 0 && 
						instruction_wb.itype.rd == instruction_ex.rtype.rs2) begin
				ex_operand2 = wb_writedata;
				forwardB = 2;
			end else
				ex_operand2 = ex_read2;

			if (instruction_ex.itype.opcode == S_OPCODE) begin
				ex_write_data = ex_operand2;	// the forwarded data goes to the "write data"
				ex_operand2 = ex_s_immediate;   // operand 2 needs to be overwritten by immediate data
			end
			
			// ALU
			ex_alu_result = alu_result(instruction_ex,ex_operand1,ex_operand2);
				
			// PC target (branches and jumps)(
			//   Branch and JAL: immediate + PC  (unique immediate computed in ID stage)
			//   JALR:   immediate + rs1 (least significant bit is always zero)
							
			if (instruction_ex.itype.opcode == BR_OPCODE) 
				ex_branchjump_target = ex_PC + 	
					{{20{instruction_ex.btype.imm12}}, instruction_ex.btype.imm11, 
					instruction_ex.btype.imm10_5, instruction_ex.btype.imm4_1,1'b0};
			else if (instruction_ex.itype.opcode == JAL_OPCODE) 
				ex_branchjump_target = ex_PC + 	
					{{12{instruction_ex[31]}},instruction_ex[31],instruction_ex[19:12],instruction_ex[20],instruction_ex[30:21],1'b0};
			else if (instruction_ex.itype.opcode == JALR_OPCODE) 
				ex_branchjump_target = {ex_operand1[31:1],1'b0} + ex_immediate;
			else
				ex_branchjump_target = 32'hxxxxxxxx;
		end
		
		assign load_use_condition =	(instruction_ex.itype.opcode == L_OPCODE) &&  // EX is a load
							((instruction_ex.rtype.rd == instruction_id.rtype.rs1) || // desitination reguster of EX used by ID1
							(instruction_ex.rtype.rd == instruction_id.rtype.rs2));  // desitination reguster of EX used by ID2						
		assign load_use = load_use_condition && !mem_PC_changed;
		
		assign insert_mem_bubble = mem_PC_changed;
		always@(posedge tb_clk) begin
			if (tb_rst | insert_mem_bubble) begin
				instruction_mem <= NOP_INSTRUCTION;
				mem_branchjump_target <= 0;
				mem_alu_result <= 0;
				mem_dWriteData <= 0;
				mem_PC <= 32'hxxxxxxxx;
			end else begin
				instruction_mem <= instruction_ex;
				mem_branchjump_target <= ex_branchjump_target;
				// For jumps, write the PC+4 to the register file
				if (instruction_ex.itype.opcode == JAL_OPCODE || instruction_ex.itype.opcode == JALR_OPCODE)
					mem_alu_result <= ex_PC + 4;
				else
					mem_alu_result <= ex_alu_result;			
				mem_dWriteData <= ex_write_data;
				mem_PC <= ex_PC;
			end
		end
		
		///////
		// Mem
		///////
		
		// Determine branch taken condition
		always_comb
		begin
			mem_branch_taken = 0;  // default case (not taken)
			if (instruction_mem.itype.opcode == BR_OPCODE)
				case (instruction_mem.btype.funct3)
					BEQ_FUNCT3: mem_branch_taken = (mem_alu_result == 0);
					BNE_FUNCT3: mem_branch_taken = (mem_alu_result != 0);
					BGE_FUNCT3: mem_branch_taken = ((mem_alu_result == 0) || ($signed(mem_alu_result) > 0));
					BLT_FUNCT3: mem_branch_taken = ($signed(mem_alu_result) < 0);
				endcase
		end
		assign mem_PC_changed = (mem_branch_taken || 
								instruction_mem.itype.opcode == JAL_OPCODE ||
								instruction_mem.itype.opcode == JALR_OPCODE);
		
		// Data memory
		assign mem_dAddress = mem_alu_result;
		
		assign mem_RegWrite = ((instruction_mem.itype.opcode == R_OPCODE || 
						instruction_mem.itype.opcode == I_OPCODE ||
						instruction_mem.itype.opcode == LUI_OPCODE ||
						instruction_mem.itype.opcode == L_OPCODE)) && 
						(instruction_mem.itype.rd != 0);


		data_memory #(.DATA_MEMORY_WORDS(DATA_MEMORY_WORDS),
			.DATA_MEMORY_FILENAME(DATA_MEMORY_FILENAME),
			.DATA_SEGMENT_START_ADDRESSS(TEXT_SEGMENT_START_ADDRESSS)) 
			dmem(.clk(tb_clk),.rst(tb_rst),.read(mem_MemRead),.write(mem_MemWrite),.address(mem_dAddress),.read_data(wb_dReadData),.write_data(mem_dWriteData));

		/*
		// Data Memory
		logic [31:0] data_memory[DATA_MEMORY_WORDS-1:0];

		initial begin
			//d_filename = copy_string(data_mem_filename);
			$readmemh(DATA_MEMORY_FILENAME, data_memory);
			//$readmemh("pipe_data_memory.txt", data_memory);
			if (^data_memory[0] === 1'bX) begin
				$display($sformatf("**** Error: RISC-V Simulation model data memory '%s' failed to load****",data_mem_filename));
				//$finish;
			end
			else 
				$display($sformatf("**** RISC-V Simulation model: Loaded data memory '%s' ****",data_mem_filename));
		end
		*/

		assign mem_MemRead = (instruction_mem.itype.opcode == L_OPCODE);
		assign mem_MemWrite = (instruction_mem.itype.opcode == S_OPCODE);
		always@(posedge tb_clk) begin
			if (tb_rst) begin
				//wb_dReadData <= 0;
				wb_alu_result <= 0;
				wb_PC_changed <= 0;
				wb_PC <= 32'hxxxxxxxx;
				instruction_wb <= NOP_INSTRUCTION;
			end
			else begin
				//if (mem_MemRead)
				//	wb_dReadData <= data_memory[(mem_dAddress - DATA_MEMORY_START_ADDRESSS) >> 2];
				//if (mem_MemWrite)
				//	data_memory[(mem_dAddress - DATA_MEMORY_START_ADDRESSS) >> 2] <= mem_dWriteData;
				wb_alu_result <= mem_alu_result;
				wb_PC_changed <= mem_PC_changed;
				wb_PC <= mem_PC;
				instruction_wb <= instruction_mem;
			end
		end
			
		///////
		// WB
		///////
		assign wb_writedata = (instruction_wb.itype.opcode == L_OPCODE) ? wb_dReadData : wb_alu_result;
		assign wb_RegWrite = ((instruction_wb.itype.opcode == R_OPCODE || 
						instruction_wb.itype.opcode == I_OPCODE ||
						instruction_wb.itype.opcode == LUI_OPCODE ||
						instruction_wb.itype.opcode == JAL_OPCODE ||
						instruction_wb.itype.opcode == JALR_OPCODE ||
						instruction_wb.itype.opcode == L_OPCODE)) && 
						(instruction_wb.itype.rd != 0);

		// Exit condition
		always_comb
			if (instruction_wb == EBREAK_INSTRUCTION || instruction_wb == ECALL_INSTRUCTION) begin
				$display("Passed! EBREAK/ECALL instruction reached WB stage at location 0x%8h",wb_PC);
				$finish;
			end
		
	endmodule

endmodule