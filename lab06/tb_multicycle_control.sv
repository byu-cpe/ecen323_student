`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: tb_multicycle_control.v
//
//  Author: Mike Wirthlin
//  
//  Description: 
// 
//
//  Change Log:
//   

//////////////////////////////////////////////////////////////////////////////////

module tb_multicycle_control #(

	parameter USE_MEMORY = 0,
	parameter instruction_memory_filename = "testbench_inst.txt",
	parameter data_memory_filename = "testbench_data.txt");

	localparam INST_MEMORY_SIZE = 256;
	localparam DATA_MEMORY_DEPTH = 64;
	localparam INITIAL_PC = 32'h00400000;
	localparam INITIAL_DATA = 32'h10010000;
	
	localparam EBREAK_INSTRUCTION = 32'h00100073;

	reg clk;
	//reg [8:0] tb_ControlSignals;
	reg tb_MemWrite, tb_MemRead, tb_rst;
	logic [31:0] tb_PC,  tb_dWriteData, tb_dAddress, tb_WriteBackData;
	reg [31:0] tb_dReadData;
	reg [31:0] tb_instruction;

    logic [31:0] tmpfile [31:0];  
	logic [31:0] l_readA, l_readB, b_operand, alu, writeData;
	logic [31:0] int_PC;
	logic int_Zero, int_MemWrite, int_MemRead, int_RegWrite;
	integer i;
    logic initialized=0;
    logic [2:0] cycle_num;

    // Ends on a negative clock
    task sim_clocks(input int clocks);
		automatic int i;
		for(i=0; i < clocks; i=i+1) begin
			//@(negedge tb_clk);
            #5 clk = 1; #5 clk = 0;
        end
    endtask

	task error();
		// Provide some delay after error so that you don't have to look at end of waveform
		#10 clk = 0;
		$finish;
	endtask;

    // Used for non memorry simulation
    // Assumes we are in negative edge of IF stage
	task execute_instruction;
		input [31:0] instruction;
		begin
            tb_instruction = instruction;
            sim_clocks(5);
		end
	endtask

	task execute_rtype_alu_instruction;
		input [4:0] rd, rs1, rs2;
		input [2:0] func3;
		input [6:0] func7;
		input [3:0] ALUCtrl;
		begin
			logic [31:0] instruction;
			instruction = {func7, rs2, rs1, func3, rd, 7'b0110011};
			execute_instruction(.instruction(instruction));
		end
	endtask

	task execute_immediate_alu_instruction;
		input [4:0] rd, rs1;
		input [2:0] func3;
		input [11:0] immediate;
		input [3:0] ALUCtrl;
		begin
			logic [31:0] instruction;
			instruction = {immediate, rs1, func3, rd, 7'b0010011};
			execute_instruction(.instruction(instruction));
		end
	endtask

	task execute_add_instruction;
		input [4:0] rd, rs1, rs2;
		$display("[%0t] add x%0d,x%0d,x%0d", $time, rd, rs1, rs2);
		execute_rtype_alu_instruction(.rd(rd),.rs1(rs1),.rs2(rs2),.func3(0),.func7(0),.ALUCtrl(4'b0010));
	endtask

	task execute_sub_instruction;
		input [4:0] rd, rs1, rs2;
		$display("[%0t] sub x%0d,x%0d,x%0d", $time, rd, rs1, rs2);
		execute_rtype_alu_instruction(.rd(rd),.rs1(rs1),.rs2(rs2),.func3(3'b000),.func7(7'b0100000),.ALUCtrl(4'b0110));
	endtask

	task execute_and_instruction;
		input [4:0] rd, rs1, rs2;
		$display("[%0t] and x%0d,x%0d,x%0d", $time, rd, rs1, rs2);
		execute_rtype_alu_instruction(.rd(rd),.rs1(rs1),.rs2(rs2),.func3(3'b111),.func7(7'b0000000),.ALUCtrl(4'b0000));
	endtask

	task execute_or_instruction;
		input [4:0] rd, rs1, rs2;
		$display("[%0t] or x%0d,x%0d,x%0d", $time, rd, rs1, rs2);
		execute_rtype_alu_instruction(.rd(rd),.rs1(rs1),.rs2(rs2),.func3(3'b110),.func7(7'b0000000),.ALUCtrl(4'b0001));
	endtask

	task execute_xor_instruction;
		input [4:0] rd, rs1, rs2;
		$display("[%0t] xor x%0d,x%0d,x%0d", $time, rd, rs1, rs2);
		execute_rtype_alu_instruction(.rd(rd),.rs1(rs1),.rs2(rs2),.func3(3'b100),.func7(7'b0000000),.ALUCtrl(4'b1011));
	endtask

	task execute_slt_instruction;
		input [4:0] rd, rs1, rs2;
		$display("[%0t] slt x%0d,x%0d,x%0d", $time, rd, rs1, rs2);
		execute_rtype_alu_instruction(.rd(rd),.rs1(rs1),.rs2(rs2),.func3(3'b010),.func7(7'b0000000),.ALUCtrl(4'b0111));
	endtask

	task execute_addi_instruction;
		input [4:0] rd, rs1;
		input [11:0] immediate;
		$display("[%0t] addi x%0d,x%0d,%0d", $time, rd, rs1, $signed({ {20{immediate[11]}}, immediate}) );
		execute_immediate_alu_instruction(.rd(rd),.rs1(rs1),.immediate(immediate),.func3(0),.ALUCtrl(4'b0010));
	endtask

	task execute_xori_instruction;
		input [4:0] rd, rs1;
		input [11:0] immediate;
		$display("[%0t] xori x%0d,x%0d,%0d", $time, rd, rs1, $signed({ {20{immediate[11]}}, immediate}) );
		execute_immediate_alu_instruction(.rd(rd),.rs1(rs1),.immediate(immediate),.func3(3'b100),.ALUCtrl(4'b1101));
	endtask

	task execute_ori_instruction;
		input [4:0] rd, rs1;
		input [11:0] immediate;
		$display("[%0t] ori x%0d,x%0d,%0d", $time, rd, rs1, $signed({ {20{immediate[11]}}, immediate}) );
		execute_immediate_alu_instruction(.rd(rd),.rs1(rs1),.immediate(immediate),.func3(3'b110),.ALUCtrl(4'b0001));
	endtask

	task execute_andi_instruction;
		input [4:0] rd, rs1;
		input [11:0] immediate;
		$display("[%0t] andi x%0d,x%0d,%0d", $time, rd, rs1, $signed({ {20{immediate[11]}}, immediate}) );
		execute_immediate_alu_instruction(.rd(rd),.rs1(rs1),.immediate(immediate),.func3(3'b111),.ALUCtrl(4'b0000));
	endtask

	task execute_slti_instruction;
		input [4:0] rd, rs1;
		input [11:0] immediate;
		$display("[%0t] slti x%0d,x%0d,%0d", $time, rd, rs1, $signed({ {20{immediate[11]}}, immediate}) );
		execute_immediate_alu_instruction(.rd(rd),.rs1(rs1),.immediate(immediate),.func3(3'b010),.ALUCtrl(4'b0111));
	endtask

	task execute_lw_instruction;
		input [4:0] rd, rs1;
		input [11:0] immediate;
		logic [31:0] instruction;
		// all load instructions use the 0000011 opcode. The 011 funct3 is for the ld. I should use
		// the 010 for lw instead of ld. 
		instruction = {immediate, rs1, 3'b010, rd, 7'b0000011};
		$display("[%0t] lw x%0d,%0d(x%0d)", $time, rd,  $signed({ {20{immediate[11]}}, immediate}), rs1 );
		execute_instruction(.instruction(instruction));
	endtask

	task execute_sw_instruction;
		input [4:0] rs2, rs1;
		input [11:0] immediate;
		logic [31:0] instruction;
		// all load instructions use the 0000011 opcode. The 011 funct3 is for the ld. I should use
		// the 010 for lw instead of ld. 
		instruction = {immediate[11:5], rs2, rs1, 3'b011, immediate[4:0], 7'b0100011};
		$display("[%0t] sw x%0d,%0d(x%0d)", $time, rs2,  $signed({ {20{immediate[11]}}, immediate}), 
			rs1 );
		execute_instruction(.instruction(instruction));
	endtask

	task execute_beq_instruction;
		input [4:0] rs2, rs1;
		input [11:0] immediate;
		logic [31:0] instruction;
		logic [12:0] imm;
		assign imm = {immediate, 1'b0};
		instruction = {imm[12],imm[10:5], rs2, rs1, 3'b000, imm[4:1],  imm[11], 7'b1100011};
		$display("[%0t] beq x%0d,x%0d,%0d", $time, rs1, rs2,  $signed({ {19{imm[12]}}, imm}));
		execute_instruction(.instruction(instruction));
	endtask

	task execute_random_instruction;
		automatic int r1,r2,imm;
		automatic int num_instructions = 13;

		// Generate random instruction fields
		automatic int rd = $urandom_range(0,31);
		automatic int rs1 = $urandom_range(0,31);
		automatic int rs2 = $urandom_range(0,31);
		imm = $urandom_range(0,12'hfff);
		
		case($urandom % num_instructions)
			0: execute_add_instruction(rd,rs1,rs2);
			1: execute_sub_instruction(rd,rs1,rs2);
			3: execute_and_instruction(rd,rs1,rs2);
			4: execute_or_instruction(rd,rs1,rs2);
			5: execute_xor_instruction(rd,rs1,rs2);
			6: execute_slt_instruction(rd,rs1,rs2);
			7: execute_addi_instruction(rd,rs1,imm);
			8: execute_andi_instruction(rd,rs1,imm);
			10: execute_ori_instruction(rd,rs1,imm);
			11: execute_xori_instruction(rd,rs1,imm);
			12: execute_slti_instruction(rd,rs1,imm);
		endcase
	endtask

    // Check all signals on negative clock cycle
    always_ff@(negedge clk) begin
        if (initialized) begin
            if (int_PC != tb_PC) begin
                $display("*** Error: PC=%h but expect %h at time %0t", tb_PC, int_PC, $time);
                error();
            end
			if (^tb_PC[0] === 1'bX) begin
				$display("**** Error: PC unititialized at time %0t",$time);
				error();
			end
            if (alu != tb_dAddress && (cycle_num == 2 | cycle_num == 3 && cycle_num == 4)) begin
                $display("*** Error: dAddress=%h but expect %h at time %0t", tb_dAddress, alu, $time);
                error();
            end
			if (^tb_dAddress[0] === 1'bX) begin
				$display("**** Error: dAddress unititialized at time %0t",$time);
				error();
			end
            if (tb_MemWrite != int_MemWrite) begin
                $display("*** Error: MemWrite=%h but expect %h at time %0t", tb_MemWrite, int_MemWrite, $time);
                error();
            end
			if (tb_MemWrite == 1'bX) begin
				$display("**** Error: MemWrite unititialized at time %0t",$time);
				error();
			end
            if (tb_MemRead != int_MemRead) begin
                $display("*** Error: MemRead=%h but expect %h at time %0t", tb_MemRead, int_MemRead, $time);
                error();
            end
			if (tb_MemRead == 1'bX) begin
				$display("**** Error: MemRead unititialized at time %0t",$time);
				error();
			end
            if (int_MemWrite && tb_dWriteData != l_readB) begin
                $display("*** Error: dWriteData=%h but expect %h at time %0t", tb_dWriteData,
                l_readB, $time);
                error();
            end
            if (tb_MemWrite && ^tb_dWriteData[0] === 1'bX) begin
                $display("*** Error: WriteData unitialized at time %0t", $time);
                error();
            end
            /* - no need to check memory read : both testbench and circuit will read the same data
            if (MemRead && tb_dReadData != internalRead) begin
                $display("*** Error: dWriteData=%h but expect %h at time %0t", tb_dWriteData,
                l_readB, $time);
                error();
            end
            */
            if (int_RegWrite && tb_WriteBackData != writeData) begin
                $display("*** Error: WriteBackData=%h but expect %h at time %0t", tb_WriteBackData,
                writeData, $time);
                error();
            end
        end
    end

	task non_memory_simulation;
		int i;

        //shall print %t with scaled in ns (-9), with 2 precision digits, and would print the " ns" string
		$timeformat(-9, 0, " ns", 20);
		$display("*** Start of Simulation:Non-Memory Simulation ***");
		
		// A few clocks to get things going
		//sim_clocks(3);
		//tb_rst = 0;

        // Issue rerset
		tb_rst = 1;
		sim_clocks(3);
		tb_instruction = 0; //32'h00000013; // nop
		sim_clocks(3);
		tb_rst = 0;
        initialized=1;

		// ends at the negative clock edge. Add a half period and raise clock (start at clock edge)
		//#5 clk = 1;

		// DO NOT CHANGE THE ISNTRUCTION ORDER - EXAM RELIES ON THIS SEQUENCE

		$display("[%0t]Testing immediate instructions", $time);
		execute_addi_instruction(.rd(1), .rs1(0), .immediate(1) );
		execute_addi_instruction(.rd(2), .rs1(1), .immediate(-3) );
		execute_andi_instruction(.rd(3), .rs1(2), .immediate(8'hff) );
		execute_ori_instruction(.rd(4), .rs1(3), .immediate(12'h700) );
		execute_ori_instruction(.rd(5), .rs1(0), .immediate(12'hca5) );
		execute_xori_instruction(.rd(6), .rs1(2), .immediate(12'h7ff) );

		$display("[%0t]Testing x0 Register", $time);
		execute_addi_instruction(.rd(0), .rs1(0), .immediate(1) );

		$display("[%0t]Testing ALU register instructions", $time);
		execute_add_instruction(.rd(7), .rs1(1), .rs2(2) );
		execute_add_instruction(.rd(8), .rs1(3), .rs2(1) );
		execute_add_instruction(.rd(9), .rs1(0), .rs2(1) );
		execute_add_instruction(.rd(10), .rs1(0), .rs2(2) );

		execute_sub_instruction(.rd(11), .rs1(1), .rs2(2) );
		execute_sub_instruction(.rd(12), .rs1(3), .rs2(1) );
		execute_sub_instruction(.rd(13), .rs1(0), .rs2(1) );
		execute_sub_instruction(.rd(14), .rs1(0), .rs2(2) );

		execute_and_instruction(.rd(15), .rs1(2), .rs2(3) );

		execute_or_instruction(.rd(16), .rs1(0), .rs2(3) );

		execute_xor_instruction(.rd(17), .rs1(0), .rs2(2) );

		execute_slt_instruction(.rd(18), .rs1(0), .rs2(1) );
		execute_slt_instruction(.rd(19), .rs1(1), .rs2(0) );
		execute_slt_instruction(.rd(20), .rs1(2), .rs2(1) );
		execute_slt_instruction(.rd(21), .rs1(1), .rs2(2) );

		// Need to setup the base address for the data memory
		execute_addi_instruction(.rd(22), .rs1(0), .immediate(12'h400) );
		// add to self: 0x800
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) );
		// add to self: 0x1000
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) );
		// add to self: 0x1001
		execute_addi_instruction(.rd(22), .rs1(22), .immediate(1) );
		// Add to self 16 times
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x00002002
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x00004004
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x00008008
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x00010010
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x00020020
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x00040040
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x00080080
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x00100100
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x00200200
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x00400400
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x00800800
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x01001000
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x02002000
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x04004000
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x08008000
		execute_add_instruction(.rd(22), .rs1(22), .rs2(22) ); // 0x10001000

		$display("[%0t]Testing Load Memory instructions", $time);
		execute_lw_instruction(.rd(23), .rs1(22), .immediate(0) );
		execute_lw_instruction(.rd(24), .rs1(22), .immediate(4) );
		execute_lw_instruction(.rd(25), .rs1(22), .immediate(8) );
		execute_lw_instruction(.rd(26), .rs1(22), .immediate(12) );
		execute_addi_instruction(.rd(27), .rs1(22), .immediate(16) );
		execute_lw_instruction(.rd(28), .rs1(27), .immediate(-4) );
		execute_lw_instruction(.rd(29), .rs1(27), .immediate(-8) );
		execute_lw_instruction(.rd(30), .rs1(27), .immediate(-12) );
		execute_lw_instruction(.rd(31), .rs1(27), .immediate(-16) );

		$display("[%0t]Testing Store Memory instructions", $time);
		execute_sw_instruction(.rs2(1), .rs1(22), .immediate(0) );
		execute_sw_instruction(.rs2(2), .rs1(22), .immediate(4) );
		execute_sw_instruction(.rs2(3), .rs1(22), .immediate(8) );
		execute_sw_instruction(.rs2(4), .rs1(22), .immediate(12) );
		// Check what was written
		execute_lw_instruction(.rd(23), .rs1(22), .immediate(0) );
		execute_lw_instruction(.rd(24), .rs1(22), .immediate(4) );
		execute_lw_instruction(.rd(25), .rs1(22), .immediate(8) );
		execute_lw_instruction(.rd(26), .rs1(22), .immediate(12) );
		execute_addi_instruction(.rd(27), .rs1(22), .immediate(16) );

		execute_sw_instruction(.rs2(5), .rs1(27), .immediate(-4) );
		execute_sw_instruction(.rs2(6), .rs1(27), .immediate(-8) );
		execute_sw_instruction(.rs2(7), .rs1(27), .immediate(-12) );
		execute_sw_instruction(.rs2(8), .rs1(27), .immediate(-16) );
		// Check what was written
		execute_lw_instruction(.rd(28), .rs1(27), .immediate(-4) );
		execute_lw_instruction(.rd(29), .rs1(27), .immediate(-8) );
		execute_lw_instruction(.rd(30), .rs1(27), .immediate(-12) );
		execute_lw_instruction(.rd(31), .rs1(27), .immediate(-16) );

		$display("[%0t]Testing Branch instructions", $time);
		// BEQ not taken
		execute_beq_instruction(.rs1(0), .rs2(1), .immediate(8) );
		// BEQ taken forrward
		execute_beq_instruction(.rs1(1), .rs2(1), .immediate(256) );
		// BEQ not taken backward
		execute_beq_instruction(.rs1(0), .rs2(1), .immediate(-64) );
		// BEQ taken backward
		execute_beq_instruction(.rs1(1), .rs2(1), .immediate(-64) );

		//////////////////////////////////
		//	Random testing
		$display("[%0t]Testing Random instructions", $time);
		for(i=0;i<100;i=i+1)
			execute_random_instruction();

		#100ns;
		sim_clocks(20);

		$display("*** Simulation done *** %0t", $time);

        $finish;
	endtask

	int MAX_TIME_NS = 100000;
	task memory_simulation;
        //shall print %t with scaled in ns (-9), with 2 precision digits, and would print the " ns" string
		$timeformat(-9, 0, " ns", 20);
		$display("*** Start of Simulation: Memory Simulation ***");
		
        // Issue rerset
		tb_rst = 1;
		sim_clocks(3);
		tb_rst = 0;
        initialized=1;
      	while (tb_instruction != EBREAK_INSTRUCTION) begin
			sim_clocks(1);
			if ($time > MAX_TIME_NS) begin
				$display("*** ERROR: Simulation has not ended by time %0t ***", $time);
				$finish;
			end
		end
		//sim_clocks(100);

		$display("*** Simulation done *** %0t", $time);
		sim_clocks(2);
		$finish;			

	endtask

	// Control module
	riscv_multicycle riscv(
        .clk(clk), 
        .rst(tb_rst), 
        .PC(tb_PC), 
        .instruction(tb_instruction), 
        .dAddress(tb_dAddress), 
        .dReadData(tb_dReadData), 
        .dWriteData(tb_dWriteData),
        .MemRead(tb_MemRead), 
        .MemWrite(tb_MemWrite),
	    .WriteBackData(tb_WriteBackData)
    );

	// Data and instruction Memory
	logic [31:0] data_memory[DATA_MEMORY_DEPTH-1:0];
	logic [31:0] inst_memory [0:INST_MEMORY_SIZE-1];
	initial
	begin
		if (USE_MEMORY) begin
			$readmemh(data_memory_filename,data_memory);
			if (^data_memory[0] === 1'bX) begin
				$display("**** Warning: Failed to load the data memory:%s",data_memory_filename);
				$display("****  Make sure the file exists and is added to the project.");
				$finish;
			end
			else
				$display("**** Loaded data memory ****");
			$readmemh(instruction_memory_filename,inst_memory);
			if (^inst_memory[0] === 1'bX) begin
				$display("**** Warning: Failed to load the instruction memory:%s",instruction_memory_filename);
				$display("****  Make sure the file exists and is added to the project.");
				$finish;
			end
			else
				$display("**** Loaded instruction memory ****");
		end
		else begin
			// Initialize data memory
			for(i=0;i<DATA_MEMORY_DEPTH;i=i+1)
				data_memory[i] = i;
			// customize data memory
			data_memory[0] = 32'hdeadbeef;
			data_memory[1] = 32'h01234567;
			data_memory[2] = 32'h87654321;
			data_memory[3] = 32'h89abcdef;
		end
	end

	// Data memory reads
	always@(posedge clk) begin
		if (tb_MemWrite)
			data_memory[(tb_dAddress-INITIAL_DATA)>>2] <= tb_dWriteData;
		if (tb_MemRead)
			tb_dReadData <= data_memory[(tb_dAddress-INITIAL_DATA)>>2];
		else
			tb_dReadData <= 32'hxxxxxxxx;
	end
	// Instruction memory reads
	always@(posedge clk)
		if (USE_MEMORY)
			tb_instruction <= inst_memory[(tb_PC - INITIAL_PC)>>2];

    // ALU
	always_comb begin
		if (tb_instruction[6:0] == 7'b0000011) // load
			alu = l_readA + b_operand;
		else if (tb_instruction[6:0] == 7'b0100011) // store
			alu = l_readA + b_operand;
		else if (tb_instruction[6:0] == 7'b1100011) // branch
			alu = l_readA - b_operand;
		else
			case(tb_instruction[14:12])
				3'b000: // add or sub
					if (tb_instruction[30] && tb_instruction[6:0] == 7'b0110011)   // Only for register/register operations
						alu = l_readA - b_operand; // sub
					else
						alu = l_readA + b_operand; // add
				3'b010: alu = (($signed(l_readA) < $signed(b_operand)) ? 32'b1 : 32'b0); // slti
				3'b111: alu = l_readA & b_operand;
				3'b110: alu = l_readA | b_operand;
				3'b100: alu = l_readA ^ b_operand;
				default: alu = l_readA + b_operand;
			endcase
	end
	assign int_Zero = (alu == 0);
	assign int_MemRead = (cycle_num == 3 && (tb_instruction[6:0] == 7'b0000011)); // load
	assign int_MemWrite = (cycle_num == 3 && (tb_instruction[6:0] == 7'b0100011)); // store

	// load operation (memtoreg)
	assign writeData = (tb_instruction[6:0] == 7'b0000011) ? tb_dReadData : alu;

    // PC and register file
	assign int_RegWrite = cycle_num == 4 && 
			((tb_instruction[6:0] == 7'b0010011)  || // alu immediate
			 (tb_instruction[6:0] == 7'b0110011)  ||  // ALU register
			 (tb_instruction[6:0] == 7'b0000011)     // load instruction
			);
	always@(posedge clk) begin
        l_readA <= tmpfile[tb_instruction[19:15]]; // rs1
        l_readB <= tmpfile[tb_instruction[24:20]]; // rs2
		if (int_RegWrite &&
			tb_instruction[11:7] != 0) begin
			tmpfile[tb_instruction[11:7]] <= writeData;
			// if reading same register we are wrting, return new data
			if (tb_instruction[19:15] == tb_instruction[11:7])
				l_readA <= writeData;
			if (tb_instruction[24:20] == tb_instruction[11:7])
				l_readB <= writeData;
        end
		if (tb_rst)
			int_PC <= INITIAL_PC;
		else if (cycle_num == 4)
			if (int_Zero && // zero 
				(tb_instruction[6:0] == 7'b1100011) && // branch
				(tb_instruction[14:12] == 3'b000) // BEQ
			)
				int_PC <= int_PC + 
					$signed({{20{tb_instruction[31]}},tb_instruction[7],tb_instruction[30:25],tb_instruction[11:8],1'b0});
			else
				int_PC <= int_PC + 4;
        if (tb_rst)
            cycle_num <= 0;
        else begin
            if (cycle_num == 4)
                cycle_num <= 0;
            else
                cycle_num <= cycle_num + 1;
        end
    end


	assign b_operand = 
		// Store Instruction
		(tb_instruction[6:0] == 7'b0100011) ? //  Store instruction
			{{20{tb_instruction[31]}},tb_instruction[31:25], tb_instruction[11:7]}
		// Load instruction or ALU immediate
		: ((tb_instruction[6:0] == 7'b0000011) || //  Load instruction
			(tb_instruction[6:0] == 7'b0010011)) ?    //  ALU Immediate
			{{20{tb_instruction[31]}},tb_instruction[31:20]}
		// register file
		:  l_readB;


	initial begin
	
		// Regfile
        for (i=0;i<32;i=i+1)
           tmpfile[i] = 0;

		if (USE_MEMORY == 0)
			non_memory_simulation();
		else
			memory_simulation();

		$display("*** Simulation done *** %0t", $time);

        $finish;

	end  // end initial
	
endmodule