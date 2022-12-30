`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: riscv_forwarding_tb.v
//
//  Author: Mike Wirthlin
//  
//  Version 1.3 (2/25/2020)
//   - Change the text below to reflect the version in the testbench output
//     search for "RISCV PIPELINE TESTBENCH V"
//   
//////////////////////////////////////////////////////////////////////////////////

module riscv_forwarding_tb();

	reg clk, rst;
	wire [31:0] tb_PC, tb_ALUResult, tb_Address, tb_dWriteData, tb_WriteBackData;
	wire tb_MemRead, tb_MemWrite;
	wire tb_iMemRead;

	reg [31:0] tb_dReadData;
    reg [31:0] tb_instruction;
	integer i;
	wire [31:0] error_count;
	
	localparam TEXT_MEMORY_FILENAME = "forwarding_text.mem";
	localparam DATA_MEMORY_FILENAME = "forwarding_data.mem";
	localparam EBREAK_INSTRUCTION = 32'h00100073;
	localparam TEXT_SEGMENT_START_ADDRESSS = 32'h00000000; // 32'h00400000;
	localparam INSTRUCTION_MEMORY_WORDS = 128;
	// Data memory
	localparam DATA_MEMORY_WORDS = 64;
	localparam DATA_SEGMENT_START_ADDRESSS = 32'h00002000;
	localparam DATA_SEGMENT_END_ADDRESSS = DATA_SEGMENT_START_ADDRESSS + DATA_MEMORY_WORDS*4-1;

	riscv_forwarding_pipeline #(.INITIAL_PC(TEXT_SEGMENT_START_ADDRESSS))
						riscv(.clk(clk), .rst(rst), .instruction(tb_instruction), .iMemRead(tb_iMemRead), .PC(tb_PC),	
							.ALUResult(tb_ALUResult), .dAddress(tb_Address), .dWriteData(tb_dWriteData), .dReadData(tb_dReadData),
							.MemRead(tb_MemRead), .MemWrite(tb_MemWrite), .WriteBackData(tb_WriteBackData) );

	riscv_forward_sim_model #(.INITIAL_PC(TEXT_SEGMENT_START_ADDRESSS), .DATA_MEMORY_START_ADDRESSS(DATA_SEGMENT_START_ADDRESSS) ) 
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
			$display("**** ERROR: Testbench failed to load the instruction memory. Make sure the %s file",TEXT_MEMORY_FILENAME);
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
	localparam MAX_INSTRUCTIONS = 2000;
	initial begin
		$display("===== RISCV FORWARDING TESTBENCH V 1.3 =====");
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


endmodule



module riscv_forward_sim_model #(parameter INITIAL_PC = 32'h00400000, DATA_MEMORY_START_ADDRESSS = 32'h10010000) 
	(tb_clk, tb_rst, rtl_PC, rtl_Instruction, rtl_iMemRead, rtl_ALUResult, rtl_dAddress, rtl_dWriteData, 
	rtl_dReadData, rtl_MemRead, rtl_MemWrite, rtl_WriteBackData, inst_mem_filename, data_mem_filename, error_count);

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
	//typePack::instruction_t instruction_id, instruction_ex, instruction_mem, instruction_wb;
	logic [31:0] instruction_id, instruction_ex, instruction_mem, instruction_wb;
	logic iMemRead;
	logic [31:0] if_PC, id_PC, ex_PC, mem_PC, wb_PC;	// PC from the simulation model
	logic [31:0] ex_read1, ex_read2, ex_operand1, ex_operand2;
	//logic [31:0] ex_immediate, ex_s_immediate;
	logic [31:0] ex_branch_target, ex_alu_result;
	logic [31:0] mem_dAddress, mem_dWriteData, mem_branch_target, mem_alu_result;
	logic mem_branch_taken, wb_branch_taken;
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

	localparam [6:0] S_OPCODE = 7'b0100011;
	localparam [6:0] L_OPCODE = 7'b0000011;
	localparam [6:0] BR_OPCODE = 7'b1100011;
	localparam [6:0] R_OPCODE = 7'b0110011;
	localparam [6:0] I_OPCODE = 7'b0010011;

	localparam [2:0] ADD_FUNCT3 = 3'b000;
	localparam [2:0] SLT_FUNCT3 = 3'b010;
	localparam [2:0] AND_FUNCT3 = 3'b111;
	localparam [2:0] OR_FUNCT3 = 3'b110;
	localparam [2:0] XOR_FUNCT3 = 3'b100;

	function string dec_inst(input [31:0] i);
		logic [4:0] rd, rs1, rs2;
		logic [2:0] funct3;
		logic [31:0] i_imm, s_imm, b_imm;
		logic [6:0] funct7;
		rd = i[11:7];
		rs1 = i[19:15];
		rs2 = i[24:20];
		i_imm = {{20{i[31]}},i[31:20]};
		s_imm = {{20{i[31]}},i[31:25],i[11:7]};
		b_imm = {{19{i[31]}},i[31],i[7],i[30:25],i[11:8],1'b0};
		funct3 = i[14:12];
		funct7 = i[31:25];
		if (i==32'h00000013)
			dec_inst = $sformatf("nop");
		else
			case(i[6:0])
				L_OPCODE: // LW
					dec_inst = $sformatf("lw x%1d,0x%1h(x%1d)", rd, i_imm, rs1);
				//typePack::L: dec_inst = $sformatf("lw x%1d,0x%1h(x%1d)", i.itype.rd, {{20{i.itype.imm[11]}},i.itype.imm}, i.itype.rs1);
				S_OPCODE: // SW
					dec_inst = $sformatf("sw x%1d,0x%1h(x%1d)", rs2, s_imm, rs1);
				// typePack::S: dec_inst = $sformatf("sw x%1d,0x%1h(x%1d)", i.stype.rs2, {{20{i.stype.imm11_5[11]}}, i.stype.imm11_5, i.stype.imm4_0}, i.itype.rs1);
				BR_OPCODE: // BEQ
					dec_inst = $sformatf("beq x%1d,x%1d,0x%1h", rs1, rs2, b_imm);
				//typePack::BRANCH: dec_inst = $sformatf("beq x%1d,x%1d,0x%1h", i.btype.rs1, i.btype.rs2, 
				//	{{20{i.btype.imm12}},i.btype.imm12,i.btype.imm11,i.btype.imm10_5,i.btype.imm4_1,1'b0});
				// R-type
				R_OPCODE:
					unique case(funct3)
						3'b110 : dec_inst = $sformatf("or x%1d,x%1d,x%1d", rd, rs1, rs2);
						3'b111 : dec_inst = $sformatf("and x%1d,x%1d,x%1d", rd, rs1, rs2);
						3'b100 : dec_inst = $sformatf("xor x%1d,x%1d,x%1d", rd, rs1, rs2);
						3'b010 :dec_inst = $sformatf("slt x%1d,x%1d,x%1d", rd, rs1, rs2);
						3'b000 :
							if (funct7[5] == 1) dec_inst = $sformatf("sub x%1d,x%1d,x%1d", rd, rs1, rs2);
							else dec_inst = $sformatf("add x%1d,x%1d,x%1d",  rd, rs1, rs2);
					endcase
				// Immediate (double)
				I_OPCODE:
					case(funct3)
						3'b110 : dec_inst = $sformatf("ori x%1d,x%1d,0x%1h", rd, rs1, i_imm);
						3'b111 : dec_inst = $sformatf("andi x%1d,x%1d,0x%1h", rd, rs1, i_imm);
						3'b100 : dec_inst = $sformatf("xori x%1d,x%1d,0x%1h", rd, rs1, i_imm);
						3'b010 : dec_inst = $sformatf("slti x%1d,x%1d,0x%1h", rd, rs1, i_imm);
						3'b000 : dec_inst = $sformatf("addi x%1d,x%1d,0x%1h", rd, rs1, i_imm);
						default: dec_inst = $sformatf("IMMEDIATE with unknown funct3 0x%1h",funct3);
					endcase
				default dec_inst = "N/A";
			endcase
	endfunction
	

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
		$display("===== RISC-V Forwarding Simulation Model %s =====", sim_model_version);
	end
	
	logic [4:0] instruction_id_rs1;
	assign  instruction_id_rs1 = instruction_id[19:15];
	logic [4:0] instruction_id_rs2;
	assign  instruction_id_rs2 = instruction_id[24:20];
	logic [6:0] instruction_ex_op;
	assign  instruction_ex_op = instruction_ex[6:0];
	logic [4:0] instruction_ex_rd;
	assign  instruction_ex_rd = instruction_ex[11:7];
	logic [4:0] instruction_ex_rs1;
	assign  instruction_ex_rs1 = instruction_ex[19:15];
	logic [4:0] instruction_ex_rs2;
	assign  instruction_ex_rs2 = instruction_ex[24:20];
	logic [2:0] instruction_ex_funct3;
	assign instruction_ex_funct3 = instruction_ex[14:12];
	logic [6:0] instruction_ex_funct7;
	assign  instruction_ex_funct7 = instruction_ex[31:25];
	logic [6:0] instruction_mem_op;
	assign  instruction_mem_op = instruction_mem[6:0];
	logic [4:0] instruction_mem_rd;
	assign  instruction_mem_rd = instruction_mem[11:7];
	logic [6:0] instruction_wb_op;
	assign  instruction_wb_op = instruction_wb[6:0];
	logic [4:0] instruction_wb_rd;
	assign  instruction_wb_rd = instruction_wb[11:7];
		
	// checking
	always@(negedge tb_clk) begin
		
		if ($time != 0) begin
		
			// Print the time and accumulated errors (so they can identify error #1)
			$write("%0t:",$time);
			//if (errors > 0)
			//	$display(" (%0d errors)",errors);
			//else
			//	$display("No Errors");
			$display();
			
			// Print the status of the IF stage
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
				
			// Print the status of the ID stage
			$write("  ID: PC=0x%8h I=0x%8h [%s]",id_PC, instruction_id, dec_inst(instruction_id));
			if (!iMemRead)
				$write(" Load Use Stall");
			if (insert_ex_bubble)
				$write(" Insert Bubble");			
			if (rtl_Instruction != instruction_id) begin
				$display(" ** ERR** I=%h but expecting:%h", rtl_Instruction, instruction_id);
				errors = errors + 1;
			end
			// See if there is a bad instruction memory read
			if ( /*!(^id_PC[0] === 1'bX) && */ ^instruction_id[0] === 1'bx) begin
				$display(" ** ERR** Bad instruction read");
				//errors = errors + 1;				
			end
			else $display();
			
			// Print the status of the EX stage
			$write("  EX: PC=0x%8h I=0x%8h [%s]", ex_PC,instruction_ex,dec_inst(instruction_ex));
			// See if this is an instruction that uses the ALU result
			if (instruction_ex_op == S_OPCODE ||
				instruction_ex_op == L_OPCODE ||
				instruction_ex_op == BR_OPCODE ||
				((instruction_ex_op == I_OPCODE ||    // ALU Op that doesn't write to r0
				  instruction_ex_op == R_OPCODE) &&
				  instruction_ex_rd != 0)
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
				if (rtl_ALUResult != ex_alu_result) begin
					$write(" ** ERR** incorrect alu result=%1h but expecting %1h", rtl_ALUResult, ex_alu_result);
					errors = errors + 1;
				end
					
			end  // Don't care about the else case
			// Print MEM bubble insertion
			if (insert_mem_bubble)
				$write(" Insert Bubble");			
			$display();

			// Print the status of the MEM stage
			$write("  MEM:PC=0x%8h I=0x%8h [%s]",mem_PC,instruction_mem, dec_inst(instruction_mem));
			// See if this is an instruction that uses memory
			if (instruction_mem_op == S_OPCODE) begin
				// Is this a store instruction? Check to see that memory is used properly
				if (rtl_MemRead) begin
					$write(" ERR: MemRead should be 0");
					errors = errors + 1;
				end
				if (!rtl_MemWrite) begin
					$write(" ERR: MemWrite should be 1");
					errors = errors + 1;
				end
				if (rtl_dAddress != mem_dAddress) begin
					$write(" Err: Memory Write to address 0x%1h but expecting address 0x%1h",rtl_dAddress,mem_dAddress);
					errors = errors + 1;
				end
				if (rtl_dWriteData != mem_dWriteData) begin
					$write(" Err: Memory Write value 0x%1h but expecting value 0x%1h",rtl_dWriteData,mem_dWriteData);
					errors = errors + 1;
				end
				if (rtl_dAddress == mem_dAddress && rtl_dWriteData == mem_dWriteData) begin
					$write(" Memory Write 0x%1h to address 0x%1h ",rtl_dWriteData,rtl_dAddress);
				end
			end else if (instruction_mem_op == L_OPCODE) begin
				// Is this a load instruction? Check to see that memory is used properly
				if (!rtl_MemRead) begin
					$write(" ERR: MemRead should be 1");
					errors = errors + 1;
				end
				if (rtl_MemWrite) begin
					$write(" ERR: MemWrite should be 0");
					errors = errors + 1;
				end
				if (rtl_dAddress != mem_dAddress) begin
					$write(" Err: Memory Read from address 0x%1h but expecting address 0x%1h",rtl_dAddress,mem_dAddress);
					errors = errors + 1;
				end
				if (rtl_dAddress == mem_dAddress && rtl_dWriteData == mem_dWriteData) begin
					$write(" Memory Read from address 0x%1h ",rtl_dAddress);  // Note: data not ready until next cycle
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
			if (instruction_mem_op == BR_OPCODE) begin
				if (mem_alu_result == 0)
					$write(" Branch Taken");
				else
					$write(" Branch NOT Taken");
			end

			$display();

			// Print the status of the WB stage
			$write("  WB: PC=0x%8h I=0x%8h [%s] ",wb_PC,instruction_wb,dec_inst(instruction_wb));
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
			$fatal;
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
				if (mem_branch_taken)
					if_PC <= mem_branch_target;			
				else
					if_PC <= if_PC + 4;			
				id_PC <= if_PC;
			end
		end
	end
		
	// Instruction Memory
	localparam INSTRUCTION_MEMORY_WORDS = 1024;  // 4x1024 - 4096 bytes
	logic [31:0] instruction_memory[INSTRUCTION_MEMORY_WORDS-1:0];
	reg [256*8-1:0] i_filename;
	initial begin
		i_filename = copy_string(inst_mem_filename);
		$readmemh(i_filename, instruction_memory);
		if (^instruction_memory[0] === 1'bX) begin
			$display($sformatf("**** Error: RISC-V Forwarding model instruction memory '%s' failed to load****",inst_mem_filename));
		end
		else
			$display($sformatf("**** RISC_V Forwarding model: Loaded instruction memory '%s' ****",inst_mem_filename));
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
			ex_read1 <= int_reg[instruction_id_rs1];
			ex_read2 <= int_reg[instruction_id_rs2];
			// register writes
			if (wb_RegWrite) 
			begin				
				int_reg[instruction_wb_rd] = wb_writedata;
				if (instruction_id_rs1 == instruction_wb_rd)
					ex_read1 <= wb_writedata;
				if (instruction_id_rs2 == instruction_wb_rd)
					ex_read2 <= wb_writedata;					
			end
		end
	end

	// Registers
	assign insert_ex_bubble = load_use || mem_branch_taken || wb_branch_taken ;
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

	logic [31:0] instruction_ex_brImm;
	assign  instruction_ex_brImm = {{20{instruction_ex[31]}}, instruction_ex[7], 
			instruction_ex[30:25],  instruction_ex[11:8], 1'b0};
	logic [31:0] instruction_ex_Imm;
	assign instruction_ex_Imm = {{20{instruction_ex[31]}}, instruction_ex[31:20]};
	logic [31:0] instruction_ex_sImm;
	assign  instruction_ex_sImm= {{20{instruction_ex[31]}}, instruction_ex[31:25], instruction_ex[11:7]};

	always@(*) begin
			ex_branch_target = ex_PC + 
				instruction_ex_brImm;
				//{{20{instruction_ex.btype.imm12}}, instruction_ex.btype.imm11, 
				//	instruction_ex.btype.imm10_5, instruction_ex.btype.imm4_1,1'b0};
			// Immediate
			//ex_immediate = {{20{instruction_ex.itype.imm[11]}},instruction_ex.itype.imm};
			//ex_s_immediate = {{20{instruction_ex.stype.imm11_5[11]}},instruction_ex.stype.imm11_5,instruction_ex.stype.imm4_0};
			
			// Operand 1 (forwarding logic)
			forwardA = 0;
			if (mem_RegWrite && instruction_mem_rd != 0 && instruction_mem_rd == instruction_ex_rs1) begin
				ex_operand1 = mem_alu_result;
				forwardA = 1;
			end else if (wb_RegWrite && instruction_wb_rd != 0 && instruction_wb_rd == instruction_ex_rs1) begin
				ex_operand1 = wb_writedata;
				forwardA = 2;
			end else
				ex_operand1 = ex_read1;


			// Operand 2 (forwarding logic)
			forwardB = 0;
			if (instruction_ex_op == S_OPCODE)
				//ex_operand2 = ex_s_immediate;
				ex_operand2 = instruction_ex_sImm;
			else if (instruction_ex_op == I_OPCODE ||
						 instruction_ex_op == L_OPCODE)
				//ex_operand2 = ex_immediate;
				ex_operand2 = instruction_ex_Imm;
			else if (mem_RegWrite && instruction_mem_rd != 0 && instruction_mem_rd == instruction_ex_rs2) begin
				ex_operand2 = mem_alu_result;
				forwardB = 1;
			end else if (wb_RegWrite && instruction_wb_rd != 0 && instruction_wb_rd == instruction_ex_rs2) begin
				ex_operand2 = wb_writedata;
				forwardB = 2;
			end else
				ex_operand2 = ex_read2;

			// ALU
			case(instruction_ex_op)
				L_OPCODE: ex_alu_result = ex_operand1 + ex_operand2;
				S_OPCODE: ex_alu_result = ex_operand1 + ex_operand2;
				BR_OPCODE: ex_alu_result = ex_operand1 - ex_operand2;
				default: // R or Immediate instructions
					case(instruction_ex_funct3)
						ADD_FUNCT3: 
							if (instruction_ex_op == R_OPCODE && instruction_ex_funct7 ==  7'b0100000)
								ex_alu_result = ex_operand1 - ex_operand2;
							else
								ex_alu_result = ex_operand1 + ex_operand2;
						SLT_FUNCT3: ex_alu_result = ($signed(ex_operand1) < $signed(ex_operand2)) ? 32'd1 : 32'd0;
						AND_FUNCT3: ex_alu_result = ex_operand1 & ex_operand2;
						OR_FUNCT3: ex_alu_result = ex_operand1 | ex_operand2;
						XOR_FUNCT3: ex_alu_result = ex_operand1 ^ ex_operand2;
						default: ex_alu_result = ex_operand1 + ex_operand2;
					endcase
			endcase
	end
	
	assign load_use_condition =	(instruction_ex_op == L_OPCODE) &&  // EX is a load
						((instruction_ex_rd == instruction_id_rs1) || // desitination reguster of EX used by ID1
						 (instruction_ex_rd == instruction_id_rs2));  // desitination reguster of EX used by ID2						
	assign load_use = load_use_condition && !mem_branch_taken;
	
	assign insert_mem_bubble = mem_branch_taken;
	always@(posedge tb_clk) begin
		if (tb_rst) begin
			instruction_mem <= NOP_INSTRUCTION;
			mem_branch_target <= 0;
			mem_alu_result <= 0;
			mem_dWriteData <= 0;
			mem_PC <= 32'hxxxxxxxx;
		end else if (insert_mem_bubble) begin
			instruction_mem <= NOP_INSTRUCTION;
			mem_branch_target <= 0;
			mem_alu_result <= 0;
			mem_dWriteData <= 0;
			mem_PC <= 32'hxxxxxxxx;
		end else begin
			instruction_mem <= instruction_ex;
			mem_branch_target <= ex_branch_target;
			mem_alu_result <= ex_alu_result;
			mem_dWriteData <= ex_read2;
			mem_PC <= ex_PC;
		end
	end

	
	///////
	// Mem
	///////
	
	assign mem_branch_taken = (instruction_mem_op == BR_OPCODE && mem_alu_result == 0);
	// Data memory
	localparam DATA_MEMORY_WORDS = 256;
	assign mem_dAddress = mem_alu_result;
	reg [256*8-1:0] d_filename;
	
	assign mem_RegWrite = ((instruction_mem_op == R_OPCODE || 
					instruction_mem_op == I_OPCODE ||
					instruction_mem_op == L_OPCODE)) && 
					(instruction_mem_rd != 0);

	
	// Data Memory
	logic [31:0] data_memory[DATA_MEMORY_WORDS-1:0];

	initial begin
		d_filename = copy_string(data_mem_filename);
		$readmemh(d_filename, data_memory);
		//$readmemh("pipe_data_memory.txt", data_memory);
		if (^data_memory[0] === 1'bX) begin
			$display($sformatf("**** Error: RISC-V Simulation model data memory '%s' failed to load****",data_mem_filename));
			$error;
		end
		else 
			$display($sformatf("**** RISC-V Simulation model: Loaded data memory '%s' ****",data_mem_filename));
	end

	assign mem_MemRead = (instruction_mem_op == L_OPCODE);
	assign mem_MemWrite = (instruction_mem_op == S_OPCODE);
	always@(posedge tb_clk) begin
		if (tb_rst) begin
			wb_dReadData <= 0;
			wb_dReadData <= 0;
			wb_alu_result <= 0;
			wb_branch_taken <= 0;
			wb_PC <= 32'hxxxxxxxx;
			instruction_wb <= NOP_INSTRUCTION;
		end
		else begin
			if (mem_MemRead)
				wb_dReadData <= data_memory[(mem_dAddress - DATA_MEMORY_START_ADDRESSS) >> 2];
			if (mem_MemWrite)
				data_memory[(mem_dAddress - DATA_MEMORY_START_ADDRESSS) >> 2] <= mem_dWriteData;
			wb_alu_result <= mem_alu_result;
			wb_branch_taken <= mem_branch_taken;
			wb_PC <= mem_PC;
			instruction_wb <= instruction_mem;
		end
	end
		
	///////
	// WB
	///////
	assign wb_writedata = (instruction_wb_op == L_OPCODE) ? wb_dReadData : wb_alu_result;
	assign wb_RegWrite = ((instruction_wb_op == R_OPCODE || 
					instruction_wb_op == I_OPCODE ||
					instruction_wb_op == L_OPCODE)) && 
					(instruction_wb_rd != 0);

	// Exit condition
	always_comb
		if (instruction_wb == EBREAK_INSTRUCTION) begin
			$display("Passed! EBREAK instruction reached WB stage at location 0x%8h",wb_PC);
			$finish;
		end
	
endmodule