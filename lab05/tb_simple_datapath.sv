`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: tb_simple_datapath.v
//
//  Author: Mike Wirthlin
//  
//////////////////////////////////////////////////////////////////////////////////

module tb_simple_datapath();

    reg clk;
    //reg [8:0] tb_ControlSignals;
    reg tb_PCSrc, tb_ALUSrc, tb_RegWrite, tb_MemtoReg, tb_MemWrite, tb_MemRead, tb_rst, tb_loadPC;
    reg [3:0] tb_ALUCtrl;
    wire [31:0] tb_PC,  tb_dWriteData, tb_dAddress, tb_WriteBackData;
    reg [31:0] tb_dReadData;
    reg [31:0] tb_instruction;

    wire tb_Zero;
    logic [31:0] tmpfile [31:0];
    logic [31:0] l_readA, l_readB, b_operand, alu, writeData;
    logic [31:0] int_PC;
    logic int_Zero, tb_branch;
    integer i;

    localparam RTYPE_ALU_OPCODE = 7'b0110011;
    localparam IMMEDIATE_ALU_OPCODE = 7'b0010011;
    localparam STORE_OPCODE = 7'b0100011;

    localparam ADD_OP = 4'b0010;
    localparam SUB_OP = 4'b0110;
    localparam AND_OP = 4'b0000;
    localparam OR_OP = 4'b0001;
    localparam XOR_OP = 4'b1101;
    localparam SLT_OP = 4'b0111;
    localparam SLL_OP = 4'b1001;
    localparam SRL_OP = 4'b1000;
    localparam SRA_OP = 4'b1010;


    localparam ADD_FUNC3 = 3'b000;
    localparam SUB_FUNC3 = 3'b000;
    localparam AND_FUNC3 = 3'b111;
    localparam OR_FUNC3 = 3'b110;
    localparam XOR_FUNC3 = 3'b100;
    localparam SLT_FUNC3 = 3'b010;
    localparam SLL_FUNC3 = 3'b001;
    localparam SRL_FUNC3 = 3'b101;
    localparam SRA_FUNC3 = 3'b101;

    localparam DEFAULT_FUNC7 = 7'b0000000;
    localparam SUB_FUNC7 = 7'b0100000;
    localparam SRA_FUNC7 = 7'b0100000;

    // Use a non-standard initial PC to make sure parameters are supported
    localparam TB_INITIAL_PC = 32'h00200000;		

    task sim_clocks(input int clocks);
        automatic int i;
        for(i=0; i < clocks; i=i+1) begin
            //@(negedge tb_clk);
            #5 clk = 1; #5 clk = 0;
        end
    endtask

    task init_control();
        // Initializes all of the control signals to zero
        tb_branch = 0;
        tb_ALUSrc = 0;
        tb_RegWrite = 0;
        tb_MemWrite = 0;
        tb_MemRead = 0;
        tb_loadPC = 0;
        tb_ALUCtrl = 0;
        tb_MemtoReg = 0;
    endtask

    task error();
        // Provide some delay after error so that you don't have to look at end of waveform
        #10 clk = 0;
        //$error;
        $finish;
    endtask;

    /* Clocking during each instruction phase:
     * 1. Each instruction phase should start at 2ns after the positive clock edge
     *   (so that all propagation after the clock edge has occurred)
     * 2. The phase can change signals at this time as propagation has occured
     * 3. Provide a delay of 3ns and change the clock to 0
     * 4. Perform signal checking at this point during the phase
     * 5. Provide a 5 ns delay and then change the clock to 1
     * 6. Provide a 2 ns delay for propagation time
    */

    // activate: instruction (keep for rest of instruction)
    //    loadPC=0 (kept same until wb stage), PCSrc=previous, ALUSrc=previous, ALUCtrl=(previous), RegWrite=(previous), MemtoReg=(previous)
    // check: PC
    task if_stage;
        tb_loadPC = 0;  // return loadPC to zero
        tb_RegWrite = 0;  // return reg write back to zero
        #3 clk = 0;
        if (int_PC != tb_PC || ^tb_PC[0] === 1'bX) begin
            $display("*** Error: PC=%h but expect %h at time %0t", tb_PC, int_PC, $time);
            error();
        end else
        #5 clk = 1;
        #2;
    endtask	

    // Instruction received from instruction memory
    task id_stage;
        input [31:0] instruction;
        tb_instruction = instruction;  // simulate instruction read
        #3 clk = 0;
        #5 clk = 1;
        #2;
    endtask

    // activate: ALUSrc and ALUCtrl (keep for rest of instruction)
    //    all others previous
    // check: dAddress (this is the ALU result) and check zero
    task ex_stage;
        input ALUSrc;
        input [3:0] ALUCtrl;
        tb_ALUCtrl = ALUCtrl;
        tb_ALUSrc = ALUSrc;
        #3 clk = 0;
        if (alu != tb_dAddress || ^tb_dAddress[0] === 1'bX) begin
            $display("*** Error: dAddress=%h but expect %h at time %0t", tb_dAddress,
            alu, $time);
            error();
        end else
        if (int_Zero != tb_Zero || tb_Zero == 1'bX) begin
            $display("*** Error: Zero=%h but expect %h at time %0t", tb_Zero,
            int_Zero, $time);
            error();
        end else
        #5 clk = 1;
        #2;
    endtask

    // activate: internal tesbench MemWrite signals
    // check: dWriteData if doing a write(address was already checked in last cycle)
    task mem_stage;
        input MemWrite;
        input MemRead;
        tb_MemWrite = MemWrite;
        tb_MemRead = MemRead;
        #3 clk = 0;
        if (MemWrite && (tb_dWriteData != l_readB || ^tb_dWriteData[0] === 1'bX ) ) begin
            $display("*** Error: dWriteData=%h but expect %h at time %0t", tb_dWriteData,
            l_readB, $time);
            error();
        end else
        #5 clk = 1;
        #2;
    endtask

    // activate: loadPC=1 and set pcsrc and regwrite. Provide read result
    // check: writebackdata
    task wb_stage;
        input branch;
        input RegWrite;
        input MemtoReg;

        tb_loadPC = 1;
        tb_branch = branch;
        tb_MemWrite = 0;
        tb_MemRead = 0;
        tb_RegWrite = RegWrite;
        tb_MemtoReg = MemtoReg;
        #3 clk = 0;
        if (RegWrite && (tb_WriteBackData != writeData || ^tb_WriteBackData[0] === 1'bX)) begin
            $display("*** Error: WriteBackData=%h but expect %h at time %0t", tb_WriteBackData,
            writeData, $time);
            error();
        end else
        #5 clk = 1;
        #2;
    endtask

    task execute_instruction;
        // Perform the five instruction phases
        input [31:0] instruction;
        input string inst_str;
        input ALUSrc;
        input [3:0] ALUCtrl;
        input MemWrite;
        input MemRead;
        input branch;
        input RegWrite;
        input MemtoReg;
        begin
            //$display("[%0t] sub x%0d,x%0d,x%0d", $time, rd, rs1, rs2);
            $display("[%0t] [PC=%08h] %s", $time, int_PC, inst_str);
            if_stage();
            id_stage(instruction);
            ex_stage(.ALUSrc(ALUSrc), .ALUCtrl(ALUCtrl));
            mem_stage(MemWrite, MemRead);
            wb_stage(.branch(branch),.RegWrite(RegWrite), .MemtoReg(MemtoReg));
        end
    endtask

    task execute_rtype_alu_instruction;
        input [4:0] rd, rs1, rs2;
        input [2:0] func3;
        input [6:0] func7;
        input [3:0] ALUCtrl;
        input string mnemonic;
        begin
            logic [31:0] instruction;
            //$display("[%0t] sub x%0d,x%0d,x%0d", $time, rd, rs1, rs2);
            automatic string inst_string = $sformatf("%s x%0d,x%0d,x%0d", mnemonic, rd, rs1, rs2);
            instruction = {func7, rs2, rs1, func3, rd, RTYPE_ALU_OPCODE};

            execute_instruction(.instruction(instruction), .inst_str(inst_string), 
                .ALUSrc(0), .ALUCtrl(ALUCtrl), .MemWrite(0), .MemRead(0),
                .branch(0), .RegWrite(1), .MemtoReg(0));
        end
    endtask

    task execute_immediate_alu_instruction;
        input [4:0] rd, rs1;
        input [2:0] func3;
        input [11:0] immediate;
        input [3:0] ALUCtrl;
        input string mnemonic;
        begin
            logic [31:0] instruction;
            //$display("[%0t] addi x%0d,x%0d,%0d", $time, rd, rs1, $signed({ {20{immediate[11]}}, immediate}) );
            automatic string inst_string = $sformatf("%s x%0d,x%0d,%0d", mnemonic, rd, rs1, immediate);
            instruction = {immediate, rs1, func3, rd, IMMEDIATE_ALU_OPCODE};
            execute_instruction(.instruction(instruction), .inst_str(inst_string), .ALUSrc(1), .ALUCtrl(ALUCtrl), .MemWrite(0),.MemRead(0),
                .branch(0),.RegWrite(1),.MemtoReg(0));
        end
    endtask

    // Register/Register ALU instructions
    task execute_add_instruction;
        input [4:0] rd, rs1, rs2;
        execute_rtype_alu_instruction(.mnemonic("add"),.rd(rd),.rs1(rs1),.rs2(rs2),.func3(ADD_FUNC3),.func7(DEFAULT_FUNC7),.ALUCtrl(ADD_OP));
    endtask

    task execute_sub_instruction;
        input [4:0] rd, rs1, rs2;
        execute_rtype_alu_instruction(.mnemonic("sub"),.rd(rd),.rs1(rs1),.rs2(rs2),.func3(SUB_FUNC3),.func7(SUB_FUNC7),.ALUCtrl(SUB_OP));
    endtask

    task execute_and_instruction;
        input [4:0] rd, rs1, rs2;
        execute_rtype_alu_instruction(.mnemonic("and"),.rd(rd),.rs1(rs1),.rs2(rs2),.func3(AND_FUNC3),.func7(DEFAULT_FUNC7),.ALUCtrl(AND_OP));
    endtask

    task execute_or_instruction;
        input [4:0] rd, rs1, rs2;
        execute_rtype_alu_instruction(.mnemonic("or"),.rd(rd),.rs1(rs1),.rs2(rs2),.func3(OR_FUNC3),.func7(DEFAULT_FUNC7),.ALUCtrl(OR_OP));
    endtask

    task execute_xor_instruction;
        input [4:0] rd, rs1, rs2;
        execute_rtype_alu_instruction(.mnemonic("xor"),.rd(rd),.rs1(rs1),.rs2(rs2),.func3(XOR_FUNC3),.func7(DEFAULT_FUNC7),.ALUCtrl(XOR_OP));
    endtask

    task execute_slt_instruction;
        input [4:0] rd, rs1, rs2;
        execute_rtype_alu_instruction(.mnemonic("slt"),.rd(rd),.rs1(rs1),.rs2(rs2),.func3(SLT_FUNC3),.func7(DEFAULT_FUNC7),.ALUCtrl(SLT_OP));
    endtask

    task execute_sll_instruction;
        input [4:0] rd, rs1, rs2;
        execute_rtype_alu_instruction(.mnemonic("sll"),.rd(rd),.rs1(rs1),.rs2(rs2),.func3(SLL_FUNC3),.func7(DEFAULT_FUNC7),.ALUCtrl(SLL_OP));
    endtask

    task execute_srl_instruction;
        input [4:0] rd, rs1, rs2;
        execute_rtype_alu_instruction(.mnemonic("srl"),.rd(rd),.rs1(rs1),.rs2(rs2),.func3(SRL_FUNC3),.func7(DEFAULT_FUNC7),.ALUCtrl(SRL_OP));
    endtask

    task execute_sra_instruction;
        input [4:0] rd, rs1, rs2;
        execute_rtype_alu_instruction(.mnemonic("sra"),.rd(rd),.rs1(rs1),.rs2(rs2),.func3(SRA_FUNC3),.func7(SRA_FUNC7),.ALUCtrl(SRA_OP));
    endtask

    // Immediate ALU instructions
    task execute_addi_instruction;
        input [4:0] rd, rs1;
        input [11:0] immediate;
        execute_immediate_alu_instruction(.mnemonic("addi"),.rd(rd),.rs1(rs1),.immediate(immediate),.func3(ADD_FUNC3),.ALUCtrl(ADD_OP));
    endtask

    task execute_xori_instruction;
        input [4:0] rd, rs1;
        input [11:0] immediate;
        execute_immediate_alu_instruction(.mnemonic("xori"),.rd(rd),.rs1(rs1),.immediate(immediate),.func3(XOR_FUNC3),.ALUCtrl(XOR_OP));
    endtask

    task execute_ori_instruction;
        input [4:0] rd, rs1;
        input [11:0] immediate;
        execute_immediate_alu_instruction(.mnemonic("ori"),.rd(rd),.rs1(rs1),.immediate(immediate),.func3(OR_FUNC3),.ALUCtrl(OR_OP));
    endtask

    task execute_andi_instruction;
        input [4:0] rd, rs1;
        input [11:0] immediate;
        execute_immediate_alu_instruction(.mnemonic("andi"),.rd(rd),.rs1(rs1),.immediate(immediate),.func3(AND_FUNC3),.ALUCtrl(ADD_OP));
    endtask

    task execute_slti_instruction;
        input [4:0] rd, rs1;
        input [11:0] immediate;
        execute_immediate_alu_instruction(.mnemonic("slti"),.rd(rd),.rs1(rs1),.immediate(immediate),.func3(SLT_FUNC3),.ALUCtrl(SLT_OP));
    endtask

    task execute_slli_instruction;
        input [4:0] rd, rs1;
        input [11:0] immediate;
        execute_immediate_alu_instruction(.mnemonic("slli"),.rd(rd),.rs1(rs1),.immediate(immediate),.func3(SLL_FUNC3),.ALUCtrl(SLL_OP));
    endtask

    task execute_srli_instruction;
        input [4:0] rd, rs1;
        input [11:0] immediate;
        execute_immediate_alu_instruction(.mnemonic("srli"),.rd(rd),.rs1(rs1),.immediate(immediate),.func3(SRL_FUNC3),.ALUCtrl(SRL_OP));
    endtask

    task execute_srai_instruction;
        input [4:0] rd, rs1;
        input [11:0] immediate;
        execute_immediate_alu_instruction(.mnemonic("srai"),.rd(rd),.rs1(rs1),.immediate(immediate),.func3(SRA_FUNC3),.ALUCtrl(SRA_OP));
    endtask


    // Memory instructions
    task automatic execute_lw_instruction;
        input [4:0] rd, rs1;
        input [11:0] immediate;

        logic [31:0] instruction;
        logic [6:0] LW_OPCODE = 7'b0000011;
        logic [2:0] LW_FUNC3 = 3'b010;
		string inst_string;
		instruction = {immediate, rs1, LW_FUNC3, rd, LW_OPCODE};
		//$display("[%0t] lw x%0d,%0d(x%0d)", $time, rd,  $signed({ {20{immediate[11]}}, immediate}), rs1 );
		inst_string = $sformatf("lw x%0d,%0d(x%0d)", rd, $signed({ {20{immediate[11]}}, immediate}), rs1 );
		execute_instruction(.instruction(instruction), .inst_str(inst_string), .ALUSrc(1), .ALUCtrl(ADD_OP), // add
			.MemWrite(0),.MemRead(1),.branch(0),.RegWrite(1),.MemtoReg(1));
    endtask

    task execute_sw_instruction;
        input [4:0] rs2, rs1;
        input [11:0] immediate;
        logic [31:0] instruction;
		string inst_string;
        instruction = {immediate[11:5], rs2, rs1, 3'b011, immediate[4:0], 7'b0100011};
        //$display("[%0t] sw x%0d,%0d(x%0d)", $time, rs2,  $signed({ {20{immediate[11]}}, immediate}), rs1 );
		inst_string = $sformatf("sw x%0d,%0d(x%0d)",rs2,  $signed({ {20{immediate[11]}}, immediate}), rs1 );
        execute_instruction(.instruction(instruction), .inst_str(inst_string), .ALUSrc(1), .ALUCtrl(ADD_OP), // add
             .MemWrite(1),.MemRead(0),.branch(0),.RegWrite(0),.MemtoReg(0));
    endtask

    // Branch instruction
    task execute_beq_instruction;
        input [4:0] rs2, rs1;
        input [11:0] immediate;
        logic [31:0] instruction;
        logic [12:0] imm;
		string inst_string;
        imm = {immediate, 1'b0};
        instruction = {imm[12],imm[10:5], rs2, rs1, 3'b000, imm[4:1],  imm[11], 7'b1100011};
        //$display("[%0t] beq x%0d,x%0d,%0d", $time, rs1, rs2,  $signed({ {19{imm[12]}}, imm}));
		inst_string = $sformatf("beq x%0d,x%0d,%0d",rs1, rs2,  $signed({ {19{imm[12]}}, imm}) );
        execute_instruction(.instruction(instruction), .inst_str(inst_string), .ALUSrc(0), .ALUCtrl(SUB_OP), // sub
             .MemWrite(0),.MemRead(0),.branch(1),.RegWrite(0),.MemtoReg(0));
    endtask

    task execute_random_instruction;
    endtask

    // Instance Datapath module
    riscv_simple_datapath #(.INITIAL_PC(TB_INITIAL_PC)) datapath(
        .clk(clk), 
        .rst(tb_rst),
        .PCSrc(tb_PCSrc), 
        .loadPC(tb_loadPC), 
        .ALUSrc(tb_ALUSrc), 
        .RegWrite(tb_RegWrite), 
        .MemtoReg(tb_MemtoReg), 
        .ALUCtrl(tb_ALUCtrl), 
        .instruction(tb_instruction), 
        .PC(tb_PC), 
        .Zero(tb_Zero),
        .dReadData(tb_dReadData), 
        .dWriteData(tb_dWriteData), 
        .dAddress(tb_dAddress),
        .WriteBackData(tb_WriteBackData)
    );

    // Data Memory
    localparam DATA_MEMORY_DEPTH = 64;
    reg [31:0] data_memory[DATA_MEMORY_DEPTH-1:0];
    initial
    begin
        // Initialize data memory
        for(i=0;i<DATA_MEMORY_DEPTH;i=i+1)
            data_memory[i] = i;
        // customize data memory
        data_memory[0] = 32'hdeadbeef;
        data_memory[1] = 32'h01234567;
        data_memory[2] = 32'h87654321;
        data_memory[3] = 32'h89abcdef;
    end

    // Simulate the writing and reading to the memory
    always@(posedge clk) begin
        if (tb_MemWrite)
            data_memory[tb_dAddress>>2] <= tb_dWriteData;
        if (tb_MemRead)
            tb_dReadData <= data_memory[tb_dAddress>>2];
        else
            tb_dReadData <= 32'hxxxxxxxx;
    end

    // Simulate the PC
    always_ff@(posedge clk) begin
        if (tb_rst)
            int_PC <= TB_INITIAL_PC;
        else if (tb_loadPC)
            if (tb_PCSrc)
                int_PC <= int_PC + 
                    $signed({{20{tb_instruction[31]}},tb_instruction[7],tb_instruction[30:25],tb_instruction[11:8],1'b0});
            else
                int_PC <= int_PC + 4;
    end

    // Simulate the ALU
    assign alu =    (tb_ALUCtrl == AND_OP) ? l_readA & b_operand :
                    (tb_ALUCtrl == OR_OP) ? l_readA | b_operand :
                    (tb_ALUCtrl == ADD_OP) ? l_readA + b_operand :
                    (tb_ALUCtrl == SUB_OP) ? l_readA - b_operand :
                    (tb_ALUCtrl == SRL_OP) ? l_readA >> b_operand[4:0] :
                    (tb_ALUCtrl == SLL_OP) ? l_readA << b_operand[4:0] :
                    (tb_ALUCtrl == SRA_OP) ? $unsigned($signed(l_readA) >>> b_operand[4:0] ):
                    (tb_ALUCtrl == SLT_OP) ?  (($signed(l_readA) < $signed(b_operand)) ? 32'b1 : 32'b0) :
                    (tb_ALUCtrl[3:0] == XOR_OP) ? l_readA ^ b_operand :
                    l_readA + b_operand;
    assign int_Zero = (alu == 0);
    assign tb_PCSrc = int_Zero & tb_branch;

    assign writeData = tb_MemtoReg ? tb_dReadData : alu;

    // Simulate the register file
    always@(posedge clk) begin
        l_readA <= tmpfile[tb_instruction[19:15]]; // rs1
        l_readB <= tmpfile[tb_instruction[24:20]]; // rs2
        if (tb_RegWrite & tb_instruction[11:7] != 0) begin
            tmpfile[tb_instruction[11:7]] <= writeData;
            // if reading same register we are wrting, return new data
            if (tb_instruction[19:15] == tb_instruction[11:7])
                l_readA <= writeData;
            if (tb_instruction[24:20] == tb_instruction[11:7])
                l_readB <= writeData;
        end
    end

    assign b_operand = 
        // regiser file
        (tb_ALUSrc==0) ? l_readB 
        // store instruction
        : (tb_instruction[6:0] == STORE_OPCODE) ? 
            {{20{tb_instruction[31]}},tb_instruction[31:25], tb_instruction[11:7]}
        // conventional
        : {{20{tb_instruction[31]}},tb_instruction[31:20]};


    initial begin
    
        // Initialize Regfile
        for (i=0;i<32;i=i+1)
           tmpfile[i] = 0;

        //shall print %t with scaled in ns (-9), with 2 precision digits, and would print the " ns" string
        $timeformat(-9, 0, " ns", 20);
        $display("*** Start of Simulation ***");
        
        // Initialize the inputs
        sim_clocks(3);
        tb_rst = 0;
        tb_instruction = 0;
        sim_clocks(3);
        // Default control signals
        init_control();

        // Issue a global reset
        tb_rst = 1;
        sim_clocks(3);
        tb_rst = 0;
        sim_clocks(3);

        // ends at the negative clock edge. Add a half period and raise clock (start at clock edge)
        #5 clk = 1;

        $display("[%0t] *** Testing immediate instructions ***", $time);
        // addi x1, x0, 1     positive (r1=0+1=1) 0x00000001
        execute_addi_instruction(.rd(1), .rs1(0), .immediate(1) );
        // addi x2, x1, -3   negative (r2=r1-3=1-3=-2) 0xfffffffe
        execute_addi_instruction(.rd(2), .rs1(1), .immediate(-3) );
        // andi x3, x2, 0xfff sign extension (r3=r2 AND 0xffffffff=-2) 0xfffffffe
        execute_andi_instruction(.rd(3), .rs1(2), .immediate(12'hfff) );
        // andi x3, x3, 0xff  AND no sign extension (r3=r3 AND 0xff=0xfe)
        execute_andi_instruction(.rd(3), .rs1(3), .immediate(12'h0ff) );
        // ori, x4, x3, 0x700  0x7fe
        execute_ori_instruction(.rd(4), .rs1(3), .immediate(12'h700) );
        // ori, x5, x0, 0xca5 0xfffffcaf
        execute_ori_instruction(.rd(5), .rs1(0), .immediate(12'hca5) );
        // xori x6, x2,0xfff  (invert or not) 0x00000001
        execute_xori_instruction(.rd(6), .rs1(2), .immediate(12'hfff) );
        // slli x7, x2, 0x1  0xfffffffc
        execute_slli_instruction(.rd(7), .rs1(2), .immediate(12'h1) );
        // srai x8, x7, 0x1  0xfffffffe
        execute_srai_instruction(.rd(8), .rs1(7), .immediate(12'h1) );
        // srli x9, x2, 0x1  0xefffffff
        execute_srli_instruction(.rd(9), .rs1(2), .immediate(12'h1) );

        $display("[%0t] *** Testing x0 Register ***", $time);
        execute_addi_instruction(.rd(0), .rs1(0), .immediate(1) );

        $display("[%0t] *** Testing ALU register instructions ***", $time);
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

        // 1 << 1 == 2
        execute_sll_instruction(.rd(22), .rs1(1), .rs2(1) );
        // 0xfffffffe << 2 == 0xfffffff8
        execute_sll_instruction(.rd(23), .rs1(2), .rs2(22) );
        // 0xfffffff8 >>  1 == 0xfffffffc
        execute_sra_instruction(.rd(24), .rs1(23), .rs2(1) );
        // 0xfffffffc >>  1 == 0x7fffffff
        execute_srl_instruction(.rd(25), .rs1(24), .rs2(1) );

        $display("[%0t] *** Testing Load Memory instructions ***", $time);
        execute_lw_instruction(.rd(22), .rs1(0), .immediate(0) );
        execute_lw_instruction(.rd(23), .rs1(0), .immediate(4) );
        execute_lw_instruction(.rd(24), .rs1(0), .immediate(8) );
        execute_lw_instruction(.rd(25), .rs1(0), .immediate(12) );
        execute_addi_instruction(.rd(26), .rs1(0), .immediate(16) );
        execute_lw_instruction(.rd(27), .rs1(26), .immediate(-4) );
        execute_lw_instruction(.rd(28), .rs1(26), .immediate(-8) );
        execute_lw_instruction(.rd(29), .rs1(26), .immediate(-12) );
        execute_lw_instruction(.rd(30), .rs1(26), .immediate(-16) );

        $display("[%0t] *** Testing Store Memory instructions ***", $time);
        execute_sw_instruction(.rs2(1), .rs1(0), .immediate(0) );
        execute_sw_instruction(.rs2(2), .rs1(0), .immediate(4) );
        execute_sw_instruction(.rs2(3), .rs1(0), .immediate(8) );
        execute_sw_instruction(.rs2(4), .rs1(0), .immediate(12) );
        // Check what was written
        execute_lw_instruction(.rd(22), .rs1(0), .immediate(0) );
        execute_lw_instruction(.rd(23), .rs1(0), .immediate(4) );
        execute_lw_instruction(.rd(24), .rs1(0), .immediate(8) );
        execute_lw_instruction(.rd(25), .rs1(0), .immediate(12) );
        execute_addi_instruction(.rd(26), .rs1(0), .immediate(16) );

        execute_sw_instruction(.rs2(5), .rs1(26), .immediate(-4) );
        execute_sw_instruction(.rs2(6), .rs1(26), .immediate(-8) );
        execute_sw_instruction(.rs2(7), .rs1(26), .immediate(-12) );
        execute_sw_instruction(.rs2(8), .rs1(26), .immediate(-16) );
        // Check what was written
        execute_lw_instruction(.rd(27), .rs1(26), .immediate(-4) );
        execute_lw_instruction(.rd(28), .rs1(26), .immediate(-8) );
        execute_lw_instruction(.rd(29), .rs1(26), .immediate(-12) );
        execute_lw_instruction(.rd(30), .rs1(26), .immediate(-16) );

        $display("[%0t] *** Testing Branch instructions ***", $time);
        // BEQ not taken
        execute_beq_instruction(.rs1(0), .rs2(1), .immediate(8) );
        // BEQ taken forward
        execute_beq_instruction(.rs1(1), .rs2(1), .immediate(256) );
        // BEQ not taken backward
        execute_beq_instruction(.rs1(0), .rs2(1), .immediate(-64) );
        // BEQ taken backward
        execute_beq_instruction(.rs1(1), .rs2(1), .immediate(-64) );
        // BEQ taken forward
        execute_beq_instruction(.rs1(5), .rs2(5), .immediate(128) );
        // BEQ taken backward
        execute_beq_instruction(.rs1(21), .rs2(21), .immediate(-32) );

		// Last instruction to show branch location
        execute_addi_instruction(.rd(1), .rs1(0), .immediate(1) );

        init_control();
        
        sim_clocks(20);

        $display("*** Simulation done *** %0t", $time);

        $finish;

    end  // end initial
    
endmodule