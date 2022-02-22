`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: riscv_final_tb.v
//
//  Author: Mike Wirthlin
//  
//  Version 1.2 (3/4/2020)
//   - Change the text below to reflect the version in the testbench output
//     search for "Version"
//   
//////////////////////////////////////////////////////////////////////////////////

package typePack;

typedef enum logic[6:0]{
	LUI = 7'b0110111,
	JAL = 7'b1101111,
	JALR = 7'b1100111,
	AUIPC = 7'b0010111,
	IMM = 7'b0010011,
	BRANCH = 7'b1100011,
	OP = 7'b0110011,
	S = 7'b0100011,
	L = 7'b0000011
}
opcodes /* verilator public */;

typedef enum logic[2:0]{
	ADD = 3'b000,
	SLT = 3'b010,
	SLTU = 3'b011,
	SLL = 3'b001,
	SR = 3'b101,
	XOR = 3'b100,
	OR = 3'b110,
	AND = 3'b111
} FIMM  /* verilator public */;

typedef enum logic[2:0]{
	BEQ = 3'b000,
	BNE = 3'b001,
	BGE = 3'b101,
	BGEU = 3'b111,
	BLTU = 3'b110,
	BLT = 3'b100
} BIMM  /* verilator public */;

typedef enum logic[2:0]{
	SBYTE = 3'b000,
	SSHORT = 3'b001,
	SWORD = 3'b010
} SIMM  /* verilator public */;

typedef enum logic[2:0]{
	LBYTE = 3'b000,
	LSHORT = 3'b001,
	LWORD = 3'b010,
	LUBYTE = 3'b100,
	LUSHORT = 3'b101
} LIMM  /* verilator public */;

localparam ASUB = 7'b0100000;



typedef struct packed
{
	logic[11:5] imm11_5;
	logic [4:0] rs2;
	logic [4:0] rs1;
	logic [2:0] funct3;
	logic [4:0] imm4_0;
	opcodes opcode;


} STYPE_T  /* verilator public */;
typedef struct packed
{
	logic[11:0] imm;
	logic [4:0] rs1;
	logic [2:0] funct3;
	logic [4:0] rd;
	opcodes opcode;


} ITYPE_T  /* verilator public */;
typedef struct packed
{
	logic [6:0] funct7;
	logic [4:0] rs2;
	logic [4:0] rs1;
	logic [2:0] funct3;
	logic [4:0] rd;
	opcodes opcode;


} RTYPE_T  /* verilator public */;
typedef struct packed
{
	logic[19:0] imm;
	logic [4:0] rd;
	opcodes opcode;


} UTYPE_T  /* verilator public */;
typedef struct packed
{
	logic imm20;
	logic [10:1] imm10_1;
	logic imm11;
	logic [19:12] imm19_12;
	logic [4:0] rd;
	opcodes opcode;


} JTYPE_T  /* verilator public */;
typedef struct packed
{
	logic imm12;
	logic [10:5] imm10_5;
	logic [4:0] rs2;
	logic [4:0] rs1;
	logic [2:0] funct3;
	logic [4:1] imm4_1;
	logic imm11;
	opcodes opcode;


} BTYPE_T  /* verilator public */;

typedef union packed
{
  ITYPE_T itype;
  STYPE_T stype;
  RTYPE_T rtype;
  UTYPE_T utype;
  JTYPE_T jtype;
  BTYPE_T btype;
} instruction_t /* verilator public */;


endpackage : typePack

module riscv_final_tb ();

	parameter TEXT_MEMORY_FILENAME = "final_text.txt";
	parameter DATA_MEMORY_FILENAME = "final_data.txt";
	parameter TEXT_SEGMENT_START_ADDRESSS = 32'h00000000; // 32'h00400000;
	parameter INSTRUCTION_MEMORY_WORDS = 1024;
	parameter DATA_MEMORY_WORDS = 2048;
	parameter DATA_SEGMENT_START_ADDRESSS = 32'h00002000;
	parameter DATA_SEGMENT_END_ADDRESSS = DATA_SEGMENT_START_ADDRESSS + DATA_MEMORY_WORDS*4-1;
	parameter MAX_INSTRUCTIONS = 1000000; //2000;

	reg clk, rst;
	wire [31:0] tb_PC, tb_ALUResult, tb_Address, tb_dWriteData, tb_WriteBackData;
	wire tb_MemRead, tb_MemWrite;
	wire tb_iMemRead;

	reg [31:0] tb_dReadData;
    reg [31:0] tb_instruction;
	integer i;
	wire [31:0] error_count;
	
	localparam EBREAK_INSTRUCTION = 32'h00100073;
	// Data memory

	riscv_final #(.INITIAL_PC(TEXT_SEGMENT_START_ADDRESSS))
						riscv(.clk(clk), .rst(rst), .instruction(tb_instruction), .iMemRead(tb_iMemRead), .PC(tb_PC),	
							.ALUResult(tb_ALUResult), .dAddress(tb_Address), .dWriteData(tb_dWriteData), .dReadData(tb_dReadData),
							.MemRead(tb_MemRead), .MemWrite(tb_MemWrite), .WriteBackData(tb_WriteBackData) );

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
	reg [31:0] instruction_memory[INSTRUCTION_MEMORY_WORDS-1:0];
	localparam NOP_INSTRUCTION = 32'h00000013; // addi x0, x0, 0
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
		  tb_instruction <= NOP_INSTRUCTION;  // Initialize instruction with "NOP"
		end
	    else begin
			// Only read instruction if iMemRead is high
			if (tb_iMemRead)
				tb_instruction <= instruction_memory[(tb_PC-TEXT_SEGMENT_START_ADDRESSS) >> 2];
		end
	end
	

	// Data Memory
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

	//////////////////////////////////////////////////////////////////////////////////
	// Data memory access
	//////////////////////////////////////////////////////////////////////////////////
	wire [31:0] local_dMem_Address;
	wire valid_dMem_Address;
	assign local_dMem_Address = (tb_Address-DATA_SEGMENT_START_ADDRESSS) >> 2;
	assign valid_dMem_Address = (tb_Address >= DATA_SEGMENT_START_ADDRESSS) && (tb_Address < DATA_SEGMENT_END_ADDRESSS);
	always@(posedge clk or posedge rst) begin
	   if (rst)
	       tb_dReadData <= 0; 
	   else
		if (tb_MemRead) begin
			if (valid_dMem_Address)
				tb_dReadData <= data_memory[local_dMem_Address];
			else
				tb_dReadData <= 32'hX;
		end else if (tb_MemWrite) begin
			if (valid_dMem_Address)
				data_memory[local_dMem_Address] <= tb_dWriteData;
			// If invalid just ignore write
		end
	end
	
	
	//////////////////////////////////////////////////////////////////////////////////
	//	Main
	//////////////////////////////////////////////////////////////////////////////////
	initial begin
		$display("===== RISCV FINAL TESTBENCH V 1.2 =====");
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
			
		// Internal shadow state
		logic [31:0] int_reg [31:0];
		typePack::instruction_t instruction_id, instruction_ex, instruction_mem, instruction_wb;
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
		localparam NOP_INSTRUCTION = 32'h00000013; // addi x0, x0, 0
		localparam EBREAK_INSTRUCTION = 32'h00100073;
		localparam EBREAK_OPCODE = 7'b1110011;
		localparam ECALL_INSTRUCTION = 32'h00000073;
		localparam UNKNOWN_INST = "ERROR: Unknown Instruction";

		function string dec_inst(input typePack::instruction_t i);
			string inst_name;
			if (i == NOP_INSTRUCTION) 
				dec_inst = $sformatf("nop");
			else begin
				
			case(i.itype.opcode)
			
				typePack::L: dec_inst = $sformatf("lw x%1d,0x%1h(x%1d)", i.itype.rd, {{20{i.itype.imm[11]}},i.itype.imm}, i.itype.rs1);
				typePack::S: dec_inst = $sformatf("sw x%1d,0x%1h(x%1d)", i.stype.rs2, {{20{i.stype.imm11_5[11]}}, i.stype.imm11_5, i.stype.imm4_0}, i.itype.rs1);
				typePack::JAL: dec_inst = $sformatf("jal x%1d,0x%1h", i.jtype.rd, 
					{{12{i[31]}},i[31],i[19:12],i[20],i[30:21]/*,1'b0*/}); // just the immediate, not the offset
				typePack::JALR: dec_inst = $sformatf("jalr x%1d,x%1d,0x%1h", i.itype.rd,  i.itype.rs1, {{20{i.itype.imm[11]}},i.itype.imm});
				typePack::BRANCH: begin
					case (i.btype.funct3)
						typePack::BEQ: inst_name = "beq";
						typePack::BNE: inst_name = "bne";
						typePack::BGE: inst_name = "bge";
						typePack::BLT: inst_name = "blt";
					endcase
					dec_inst = $sformatf("%s x%1d,x%1d,0x%1h", inst_name, i.btype.rs1, i.btype.rs2, 
							{{20{i.btype.imm12}},i.btype.imm12,i.btype.imm11,i.btype.imm10_5,i.btype.imm4_1,1'b0});	
					end 
				typePack::OP: 
					case(i.rtype.funct3)
						typePack::OR : dec_inst = $sformatf("or x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1, i.rtype.rs2);
						typePack::AND : dec_inst = $sformatf("and x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1, i.rtype.rs2);
						typePack::XOR : dec_inst = $sformatf("xor x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1, i.rtype.rs2);
						typePack::SLT :dec_inst = $sformatf("slt x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1, i.rtype.rs2);
						typePack::ADD :
							if (i.rtype.funct7[5] == 1) dec_inst = $sformatf("sub x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1, i.rtype.rs2);
							else dec_inst = $sformatf("add x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1, i.rtype.rs2);
						typePack::SLL : dec_inst = $sformatf("sll x%1d,x%1d,x%1d", i.itype.rd, i.itype.rs1, i.rtype.rs2);
						typePack::SR : 
							if (i.rtype.funct7[5] == 1) dec_inst = $sformatf("sra x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1, i.rtype.rs2);
							else dec_inst = $sformatf("srl x%1d,x%1d,x%1d", i.rtype.rd, i.rtype.rs1,  i.rtype.rs2);
						default begin dec_inst = UNKNOWN_INST; errors = errors + 1; end
					endcase
				typePack::IMM: 
					case(i.itype.funct3)
						typePack::OR : dec_inst = $sformatf("ori x%1d,x%1d,0x%1h", i.itype.rd, i.itype.rs1,{{20{i.itype.imm[11]}},i.itype.imm});
						typePack::AND : dec_inst = $sformatf("andi x%1d,x%1d,0x%1h", i.itype.rd, i.itype.rs1,{{20{i.itype.imm[11]}},i.itype.imm});
						typePack::XOR : dec_inst = $sformatf("xori x%1d,x%1d,0x%1h", i.itype.rd, i.itype.rs1,{{20{i.itype.imm[11]}},i.itype.imm});
						typePack::SLT : dec_inst = $sformatf("slti x%1d,x%1d,0x%1h", i.itype.rd, i.itype.rs1,{{20{i.itype.imm[11]}},i.itype.imm});
						typePack::ADD : dec_inst = $sformatf("addi x%1d,x%1d,0x%1h", i.itype.rd, i.itype.rs1,{{20{i.itype.imm[11]}},i.itype.imm});
						typePack::SLL : dec_inst = $sformatf("slli x%1d,x%1d,%1d", i.itype.rd, i.itype.rs1, i.itype.imm[4:0]);
						typePack::SR : 
							if (i.rtype.funct7[5] == 1) dec_inst = $sformatf("srai x%1d,x%1d,%1d", i.rtype.rd, i.rtype.rs1, i.itype.imm[4:0]);
							else dec_inst = $sformatf("srli x%1d,x%1d,%1d", i.rtype.rd, i.rtype.rs1,  i.itype.imm[4:0]);
						default begin dec_inst = UNKNOWN_INST; errors = errors + 1; end
						endcase
				EBREAK_OPCODE: 
					dec_inst = "ebreak";
				typePack::LUI:
					dec_inst = $sformatf("lui x%1d,0x%1h", i.utype.rd, i.utype.imm);
					
				default begin
					// Received an instruction that is not known
					dec_inst = UNKNOWN_INST;
					errors = errors + 1;
				end 
			endcase
			end
		endfunction

		function string stage_state(input [31:0] inst);
			automatic typePack::instruction_t i = inst;
			stage_state = $sformatf("%s",dec_inst(i));
		endfunction
		
		/* This function will copy each character of a string into a single array of bits
		for use by readmemh for the Vivado simulator. The format of bit array must be as
		follows:
		- The last character of the string  must be located at [7:0] of the 
		- The second to last character of the string must be located at [15:8] and so on
		- The first character of the string must be located at [l*8-1:(l-1)*8]
			where l is the number of characters in the array
		- The location at [(l+1)*8-1:l*8] must be 0 (null terminated string)

		logic [31: 0] a_vect;
	logic [0 :31] b_vect;
	logic [63: 0] dword;
	integer sel;
	a_vect[ 0 +: 8] // == a_vect[ 7 : 0]
	a_vect[15 -: 8] // == a_vect[15 : 8]
	b_vect[ 0 +: 8] // == b_vect[0 : 7]
	b_vect[15 -: 8] // == b_vect[8 :15]
	dword[8*sel +: 8] // variable part-select with fixed width

	https://forums.xilinx.com/t5/Simulation-and-Verification/readmemh-doesn-t-support-string-as-the-filename/td-p/833603
		*/
		function reg [256*8-1:0] copy_string(string str);
			automatic int i;
			//$display("String:%s len=%1d",str,str.len());
			for (i=0;i<str.len();i=i+1) begin
				// Copy characters from the end of the string to the start
				copy_string[(i+1)*8-1 -: 8] = str.getc(str.len()-i-1);
				//$write("%c-0x%h-%1d ",str.getc(str.len()-i-1),copy_string[(i+1)*8-1 -: 8],i);
			end
			//$display();
			//$write("%d ",i);
			copy_string[(i+1)*8-1 -: 8] = 0;
			//$write(" %c-0x%h-%1d ",str.getc(i),copy_string[(i+1)*8-1 -: 8],i);
			//$display();
		endfunction
		
		function  print_string(reg [256*8-1:0] str);
			automatic int i;
			for (i=0;i<256;i=i+1) begin
				$write("0x%h-%1d ",str[(i+1)*8-1-:8],i);
				if (i%16 == 0)
					$display();
			end
			$display();
		endfunction

		initial begin
			$timeformat(-9, 0, " ns", 20);
			$display("===== RISC-V Final Simulation Model %s =====", sim_model_version);
		end
		
			
		// checking
		always@(negedge tb_clk) begin
			
			if ($time != 0 && !tb_rst) begin
			
				// Print the time and accumulated errors (so they can identify error #1)
				$write("%0t:",$time);
				//if (errors > 0)
				//	$display(" (%0d errors)",errors);
				//else
				//	$display("No Errors");
				$display();
				
				/////////////////////////////////////////
				// IF Stage Printing
				/////////////////////////////////////////
				$write("  IF: PC=0x%8h",if_PC);
				if (!iMemRead) begin
					$write(" Load Use Stall (iMemRead=0)");				
				end
							if (if_PC != rtl_PC) begin
					$write(" ** ERR** incorrect PC=%h", rtl_PC);
					errors = errors + 1;
				end
				if (iMemRead != rtl_iMemRead) begin
					$write(" ** ERR** incorrect iMemRead=%1h", rtl_iMemRead);
					errors = errors + 1;
				end
				$display();
					
				/////////////////////////////////////////
				// ID Stage Printing
				/////////////////////////////////////////
				$write("  ID: PC=0x%8h I=0x%8h [%s]",id_PC, instruction_id, stage_state(instruction_id));
				if (!iMemRead)
					$write(" Load Use Stall");
				if (insert_ex_bubble)
					$write(" Insert Bubble into EX");	
				// If there is a bubble in the id_PC, ignore the compare
				if (!(id_PC[0] === 1'bX) && rtl_Instruction != instruction_id) begin
					$display(" ** ERR** incorrect I=%h", rtl_Instruction);
					errors = errors + 1;
				end
				else $display();
				
				/////////////////////////////////////////
				// EX Stage Printing
				/////////////////////////////////////////
				$write("  EX: PC=0x%8h I=0x%8h [%s]", ex_PC,instruction_ex,stage_state(instruction_ex));
				// See if this is an instruction that uses the ALU result
				if (instruction_ex.itype.opcode == typePack::S ||
					instruction_ex.itype.opcode == typePack::L ||
					instruction_ex.itype.opcode == typePack::BRANCH ||
					instruction_ex.itype.opcode == typePack::LUI ||
					/* instruction_ex.itype.opcode == typePack::JAL || */
					/* instruction_ex.itype.opcode == typePack::JALR || */
					((instruction_ex.itype.opcode == typePack::IMM ||    // ALU Op that doesn't write to r0
					instruction_ex.itype.opcode == typePack::OP) &&
					instruction_ex.itype.rd != 0)
					) begin
					$write(" alu result=0x%1h ",ex_alu_result);
					if (forwardA == 1)
						$write(" [FWD MEM(0x%1h) to r1]",mem_alu_result);
					else if (forwardA == 2)
						$write(" [FWD WB(0x%1h) to r1]",wb_writedata);
					if (forwardB == 1)
						$write(" [FWD MEM(0x%1h) to r2]",mem_alu_result);
					else if (forwardB == 2)
						$write(" [FWD WB(0x%1h) to r2]",wb_writedata);
					if (!(rtl_ALUResult === ex_alu_result)) begin   // Don't allow 'x' matching
						$write(" ** ERR** incorrect alu result=%1h", rtl_ALUResult);
						errors = errors + 1;
					end
						
				end  // Don't care about the else case
				// Print MEM bubble insertion
				if (insert_mem_bubble)
					$write(" Insert Bubble into MEM");			
				$display();

				/////////////////////////////////////////
				// MEM Stage Printing
				/////////////////////////////////////////
				$write("  MEM:PC=0x%8h I=0x%8h [%s]",mem_PC,instruction_mem, stage_state(instruction_mem));
				// See if this is an instruction that uses memory
				if (instruction_mem.itype.opcode == typePack::S) begin
					// Is this a store instruction? Check to see that memory is used properly
					if (rtl_MemRead) begin
						$write(" ERR: MemRead should be 0");
						errors = errors + 1;
					end
					if (!rtl_MemWrite) begin
						$write(" ERR: MemWrite should be 1");
						errors = errors + 1;
					end
					if (rtl_dWriteData != mem_dWriteData) begin
						$write(" Err: Memory Write value 0x%1h but expecting value 0x%1h",rtl_dWriteData,mem_dWriteData);
						errors = errors + 1;
					end else begin
						$write("  Memory Write Data=0x%1h ",rtl_dWriteData);
					end
					if (rtl_dAddress != mem_dAddress) begin
						$write(" Err: Memory Write to address 0x%1h but expecting address 0x%1h",rtl_dAddress,mem_dAddress);
						errors = errors + 1;
					end else
						$write("  Memory write to address 0x%1h",rtl_dAddress);					
				end else if (instruction_mem.itype.opcode == typePack::L) begin
					// Is this a load instruction? Check to see that memory is used properly
					if (!rtl_MemRead) begin
						$write(" ERR: MemRead should be 1");
						errors = errors + 1;
					end
					if (rtl_MemWrite) begin
						$write(" ERR: MemWrite should be 0");
						errors = errors + 1;
					end
					if (!(rtl_dAddress === mem_dAddress)) begin
						$write(" Err: Memory Read from address 0x%1h but expecting address 0x%1h",rtl_dAddress,mem_dAddress);
						errors = errors + 1;
					end
					else begin
						// Only print the memory read address: the data is not available until the next cycle
						// (if there is a memory read mismatch, it won't happen until the next cycle)
						$write(" Memory Read from address 0x%1h",rtl_dAddress);
					end
				end else begin
					// If it is not an instruction that uses memory, make sure the memory is not being used
					// (No debug necessary if no read operations are occuring)
					if (rtl_MemRead) begin
						$write(" ERR: MemRead should be 0");
						errors = errors + 1;
					end
					if (rtl_MemWrite) begin
						$write(" ERR: MemWrite should be 0");
						errors = errors + 1;
					end
				end
				// See if we have a branch instruction and indicate whether it is taken or not
				if (instruction_mem.itype.opcode == typePack::BRANCH) begin
					if (mem_branch_taken == 0)
						$write(" Branch NOT Taken");
					else
						$write(" Branch Taken");
				end
				// See if there is a jump in the stage
				if (instruction_mem.itype.opcode == typePack::JAL || 
					instruction_mem.itype.opcode == typePack::JALR)
					$write(" Jump Taken");

				$display();

				/////////////////////////////////////////
				// WB Stage Printing
				/////////////////////////////////////////
				$write("  WB: PC=0x%8h I=0x%8h [%s] ",wb_PC,instruction_wb,stage_state(instruction_wb));
				if (wb_RegWrite) begin
					// Check to see if this instruction writes back to the register file
					$write("WriteBackData=0x%1h ",rtl_WriteBackData);
					if (!(rtl_WriteBackData === wb_writedata)) begin
						$write(" ** ERR** expecting to write back data=0x%1h", wb_writedata);
						errors = errors + 1;
					end else if (^rtl_WriteBackData === 1'bX || ^wb_writedata === 1'bX) begin
						$write(" ** ERR** Write back data is undefined=0x%1h", wb_writedata);
						errors = errors + 1;
					end
				end
				// no else: We don't know if the rtl is trying to write to the register file
				$display();
				
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
			
		// Instruction Memory
		logic [31:0] instruction_memory[INSTRUCTION_MEMORY_WORDS-1:0];
		reg [256*8-1:0] i_filename;
		initial begin
			i_filename = copy_string(inst_mem_filename);
			$readmemh(i_filename, instruction_memory);
			if (^instruction_memory[0] === 1'bX) begin
				$display($sformatf("**** Error: RISC-V Simulation model instruction memory '%s' failed to load****",inst_mem_filename));
			end
			else
				$display($sformatf("**** RISC-V Simulation model: Loaded instruction memory '%s' ****",inst_mem_filename));
		end

		// Instruction memory read (synchronous read). No writes
		// Read every clock cycle (even if we will end up ignoring NOP instructions that are read)
		wire [31:0] local_PC = (if_PC - INITIAL_PC) >> 2;
		always@(posedge tb_clk) begin
			if (tb_rst) begin
			instruction_id <= NOP_INSTRUCTION;  // Initialize instruction with "NOP"
			end
			else begin
				if (iMemRead) begin
					instruction_id <= instruction_memory[local_PC];
				end
			end
		end

		
		///////
		// ID
		///////
		logic [4:0] id_rs1;
		assign id_rs1 = (instruction_id.itype.opcode == typePack::LUI) ? 0 :  instruction_id.rtype.rs1;	
		
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
			if (mem_RegWrite && instruction_mem.itype.rd != 0 && instruction_mem.itype.rd == instruction_ex.rtype.rs1) begin
				ex_operand1 = mem_alu_result;
				forwardA = 1;
			end else if (wb_RegWrite && instruction_wb.itype.rd != 0 && instruction_wb.itype.rd == instruction_ex.rtype.rs1) begin
				ex_operand1 = wb_writedata;
				forwardA = 2;
			end else if (instruction_ex.itype.opcode == typePack::LUI)
				ex_operand1 = 0;
			else
				ex_operand1 = ex_read1;
				
			// Operand 2 (forwarding logic)
			forwardB = 0;
			if (instruction_ex.itype.opcode == typePack::IMM ||
						instruction_ex.itype.opcode == typePack::L)
				ex_operand2 = ex_immediate;
			else if (instruction_ex.utype.opcode == typePack::LUI)
				ex_operand2 = ex_u_immediate;
			else if (mem_RegWrite && instruction_mem.itype.rd != 0 && instruction_mem.itype.rd == instruction_ex.rtype.rs2) begin
				ex_operand2 = mem_alu_result;
				forwardB = 1;
			end else if (wb_RegWrite && instruction_wb.itype.rd != 0 && instruction_wb.itype.rd == instruction_ex.rtype.rs2) begin
				ex_operand2 = wb_writedata;
				forwardB = 2;
			end else
				ex_operand2 = ex_read2;

			if (instruction_ex.itype.opcode == typePack::S) begin
				ex_write_data = ex_operand2;	// the forwarded data goes to the "write data"
				ex_operand2 = ex_s_immediate;   // operand 2 needs to be overwritten by immediate data
			end
			
			// ALU
			if (instruction_ex.itype.opcode == typePack::L || instruction_ex.itype.opcode == typePack::S)
				ex_alu_result = ex_operand1 + ex_operand2;
			else if (instruction_ex.itype.opcode == typePack::BRANCH)
				ex_alu_result = ex_operand1 - ex_operand2;
			else if (instruction_ex.itype.opcode == typePack::LUI)
				ex_alu_result = ex_operand1 + ex_operand2;
			else if (instruction_ex.itype.opcode == typePack::OP || instruction_ex.itype.opcode == typePack::IMM)
					case(instruction_ex.itype.funct3)
						typePack::ADD: 
							if (instruction_ex.rtype.opcode == typePack::OP && instruction_ex.rtype.funct7 ==  7'b0100000)
								ex_alu_result = ex_operand1 - ex_operand2;
							else
								ex_alu_result = ex_operand1 + ex_operand2;
						typePack::SLT: ex_alu_result = ($signed(ex_operand1) < $signed(ex_operand2)) ? 32'd1 : 32'd0;
						typePack::AND: ex_alu_result = ex_operand1 & ex_operand2;
						typePack::OR: ex_alu_result = ex_operand1 | ex_operand2;
						typePack::XOR: ex_alu_result = ex_operand1 ^ ex_operand2;
						typePack::SLL: ex_alu_result = ex_operand1 << ex_operand2[4:0];
						typePack::SR: 
							if (instruction_ex.rtype.funct7 ==  7'b0100000)
								ex_alu_result =  $signed(ex_operand1) >>> ex_operand2[4:0];   // SRA
							else
								ex_alu_result =  ex_operand1 >> ex_operand2[4:0];   // SRL
						default: ex_alu_result = 32'hxxxxxxxx;
					endcase
			else
				ex_alu_result = 32'hxxxxxxxx;
				
				
			// PC target (branches and jumps)(
			//   Branch and JAL: immediate + PC  (unique immediate computed in ID stage)
			//   JALR:   immediate + rs1 (least significant bit is always zero)
							
			if (instruction_ex.itype.opcode == typePack::BRANCH) 
				ex_branchjump_target = ex_PC + 	
					{{20{instruction_ex.btype.imm12}}, instruction_ex.btype.imm11, 
					instruction_ex.btype.imm10_5, instruction_ex.btype.imm4_1,1'b0};
			else if (instruction_ex.itype.opcode == typePack::JAL) 
				ex_branchjump_target = ex_PC + 	
					{{12{instruction_ex[31]}},instruction_ex[31],instruction_ex[19:12],instruction_ex[20],instruction_ex[30:21],1'b0};
			else if (instruction_ex.itype.opcode == typePack::JALR) 
				ex_branchjump_target = {ex_operand1[31:1],1'b0} + ex_immediate;
					
			else
				ex_branchjump_target = 32'hxxxxxxxx;
											
		end
		
		assign load_use_condition =	(instruction_ex.itype.opcode == typePack::L) &&  // EX is a load
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
				if (instruction_ex.itype.opcode == typePack::JAL || instruction_ex.itype.opcode == typePack::JALR)
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
			if (instruction_mem.itype.opcode == typePack::BRANCH)
				case (instruction_mem.btype.funct3)
					typePack::BEQ: mem_branch_taken = (mem_alu_result == 0);
					typePack::BNE: mem_branch_taken = (mem_alu_result != 0);
					typePack::BGE: mem_branch_taken = ((mem_alu_result == 0) || ($signed(mem_alu_result) > 0));
					typePack::BLT: mem_branch_taken = ($signed(mem_alu_result) < 0);
				endcase
		end
		assign mem_PC_changed = (mem_branch_taken || 
								instruction_mem.itype.opcode == typePack::JAL ||
								instruction_mem.itype.opcode == typePack::JALR);
		
		// Data memory
		assign mem_dAddress = mem_alu_result;
		reg [256*8-1:0] d_filename;
		
		assign mem_RegWrite = ((instruction_mem.itype.opcode == typePack::OP || 
						instruction_mem.itype.opcode == typePack::IMM ||
						instruction_mem.itype.opcode == typePack::LUI ||
						instruction_mem.itype.opcode == typePack::L)) && 
						(instruction_mem.itype.rd != 0);

		
		// Data Memory
		logic [31:0] data_memory[DATA_MEMORY_WORDS-1:0];

		initial begin
			d_filename = copy_string(data_mem_filename);
			$readmemh(d_filename, data_memory);
			//$readmemh("pipe_data_memory.txt", data_memory);
			if (^data_memory[0] === 1'bX) begin
				$display($sformatf("**** Error: RISC-V Simulation model data memory '%s' failed to load****",data_mem_filename));
				//$finish;
			end
			else 
				$display($sformatf("**** RISC-V Simulation model: Loaded data memory '%s' ****",data_mem_filename));
		end

		assign mem_MemRead = (instruction_mem.itype.opcode == typePack::L);
		assign mem_MemWrite = (instruction_mem.itype.opcode == typePack::S);
		always@(posedge tb_clk) begin
			if (tb_rst) begin
				wb_dReadData <= 0;
				wb_dReadData <= 0;
				wb_alu_result <= 0;
				wb_PC_changed <= 0;
				wb_PC <= 32'hxxxxxxxx;
				instruction_wb <= NOP_INSTRUCTION;
			end
			else begin
				if (mem_MemRead)
					wb_dReadData <= data_memory[(mem_dAddress - DATA_MEMORY_START_ADDRESSS) >> 2];
				if (mem_MemWrite)
					data_memory[(mem_dAddress - DATA_MEMORY_START_ADDRESSS) >> 2] <= mem_dWriteData;
				wb_alu_result <= mem_alu_result;
				wb_PC_changed <= mem_PC_changed;
				wb_PC <= mem_PC;
				instruction_wb <= instruction_mem;
			end
		end
			
		///////
		// WB
		///////
		assign wb_writedata = (instruction_wb.itype.opcode == typePack::L) ? wb_dReadData : wb_alu_result;
		assign wb_RegWrite = ((instruction_wb.itype.opcode == typePack::OP || 
						instruction_wb.itype.opcode == typePack::IMM ||
						instruction_wb.itype.opcode == typePack::LUI ||
						instruction_wb.itype.opcode == typePack::JAL ||
						instruction_wb.itype.opcode == typePack::JALR ||
						instruction_wb.itype.opcode == typePack::L)) && 
						(instruction_wb.itype.rd != 0);

		// Exit condition
		always_comb
			if (instruction_wb == EBREAK_INSTRUCTION || instruction_wb == ECALL_INSTRUCTION) begin
				$display("Passed! EBREAK/ECALL instruction reached WB stage at location 0x%8h",wb_PC);
				$finish;
			end
		
	endmodule

endmodule