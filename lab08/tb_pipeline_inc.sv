//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: tb_pipeline_inc.sv
//
//    Common testbench simulation code for pipeline and forwarding testbenches.
//
//////////////////////////////////////////////////////////////////////////////////

localparam [6:0] S_OPCODE =    7'b0100011;
localparam [6:0] L_OPCODE =    7'b0000011;
localparam [6:0] BR_OPCODE =   7'b1100011;
localparam [6:0] R_OPCODE =    7'b0110011;
localparam [6:0] I_OPCODE =    7'b0010011;
localparam [6:0] JAL_OPCODE =  7'b1101111;
localparam [6:0] JALR_OPCODE = 7'b1100111;
localparam [6:0] SYS_OPCODE =  7'b1110011;

localparam [2:0] ADDSUB_FUNCT3 = 3'b000;
localparam [2:0] SLL_FUNCT3 = 3'b001;
localparam [2:0] SLT_FUNCT3 = 3'b010;
localparam [2:0] SLTU_FUNCT3 = 3'b011;
localparam [2:0] XOR_FUNCT3 = 3'b100;
localparam [2:0] SRLSRA_FUNCT3 = 3'b101;
localparam [2:0] OR_FUNCT3 = 3'b110;
localparam [2:0] AND_FUNCT3 = 3'b111;

localparam [2:0] LW_FUNCT3 = 3'b010;
localparam [2:0] SW_FUNCT3 = 3'b010;
localparam [2:0] BEQ_FUNCT3 = 3'b000;
localparam [2:0] EBREAK_ECALL_FUNCT3 = 3'b000;

localparam [31:0] NOP_INSTRUCTION = 32'h00000013; // addi x0, x0, 0

// Determine if the instruction is valid or not (i.e., an instruction that the lab should execute.)
function automatic int valid_inst(input [31:0] i);
    logic[6:0] opcode = i[6:0]; 
    logic[2:0] funct3 = i[14:12]; 
    logic[6:0] funct7 = i[31:25];
    logic[11:0] immed = i[31:20];

    case(i[6:0])
        L_OPCODE: // LW
            // Make sure lw
            if (funct3 == LW_FUNCT3)
                valid_inst = 1;
            else
                valid_inst = 0;
        S_OPCODE: // SW
            // Make sure sw
            if (funct3 == SW_FUNCT3)
                valid_inst = 1;
            else
                valid_inst = 0;
        BR_OPCODE: // BEQ
            // Make sure supported branch
            if (funct3 == BEQ_FUNCT3)
                valid_inst = 1;
            else
                valid_inst = 0;
        // R-type
        R_OPCODE:
            // All R type instructions should be supported
            valid_inst = 1;
        I_OPCODE:
            // All I type instructions should be supported
            valid_inst = 1;
        SYS_OPCODE: // ebreak
            if (funct3 == EBREAK_ECALL_FUNCT3 && immed[0] == 1)
                valid_inst = 1;
            else
                valid_inst = 0;
        default:
            valid_inst = 0;
    endcase
endfunction

// Decode the current instruction and return a string describing the instruction.
function string dec_inst(input [31:0] i);
    logic [4:0] rd, rs1, rs2;
    logic [2:0] funct3;
    logic [31:0] i_imm, s_imm, b_imm;
    logic [6:0] funct7;
    int i_offset, s_offset;
    rd = i[11:7];
    rs1 = i[19:15];
    rs2 = i[24:20];
    i_imm = {{20{i[31]}},i[31:20]};
    s_imm = {{20{i[31]}},i[31:25],i[11:7]};
    b_imm = {{19{i[31]}},i[31],i[7],i[30:25],i[11:8],1'b0};
    funct3 = i[14:12];
    funct7 = i[31:25];
    i_offset = i_imm;
    s_offset = s_imm;

    if (i==NOP_INSTRUCTION)
        dec_inst = $sformatf("nop");
    else
        case(i[6:0])
            L_OPCODE: // LW
                //dec_inst = $sformatf("lw x%1d,0x%1h(x%1d)", rd, i_imm, rs1);
                dec_inst = $sformatf("lw x%1d,%1d(x%1d)", rd, i_offset, rs1);
            S_OPCODE: // SW
                //dec_inst = $sformatf("sw x%1d,0x%1h(x%1d)", rs2, s_imm, rs1);
                dec_inst = $sformatf("sw x%1d,%1d(x%1d)", rs2, s_offset, rs1);
            BR_OPCODE: // BEQ
                dec_inst = $sformatf("beq x%1d,x%1d,0x%1h", rs1, rs2, b_imm);
            // R-type
            R_OPCODE:
                case(funct3)
                    ADDSUB_FUNCT3 :
                        if (funct7[5] == 1) dec_inst = $sformatf("sub x%1d,x%1d,x%1d", rd, rs1, rs2);
                        else dec_inst = $sformatf("add x%1d,x%1d,x%1d",  rd, rs1, rs2);
                    SLL_FUNCT3 : dec_inst = $sformatf("sll x%1d,x%1d,x%1d", rd, rs1, rs2);
                    SLT_FUNCT3 : dec_inst = $sformatf("slt x%1d,x%1d,x%1d", rd, rs1, rs2);
                    SLTU_FUNCT3 : dec_inst = $sformatf("sltu x%1d,x%1d,x%1d", rd, rs1, rs2);
                    XOR_FUNCT3 : dec_inst = $sformatf("xor x%1d,x%1d,x%1d", rd, rs1, rs2);
                    SRLSRA_FUNCT3 :
                        if (funct7[5] == 1) dec_inst = $sformatf("sra x%1d,x%1d,x%1d", rd, rs1, rs2);
                        else dec_inst = $sformatf("srl x%1d,x%1d,x%1d",  rd, rs1, rs2);
                    OR_FUNCT3 : dec_inst = $sformatf("or x%1d,x%1d,x%1d", rd, rs1, rs2);
                    AND_FUNCT3 : dec_inst = $sformatf("and x%1d,x%1d,x%1d", rd, rs1, rs2);
                    default: begin
                        dec_inst = $sformatf("Register/Register Instruction with UNKNOWN funct3 0x%1h",funct3);
                    end
                endcase
            // Immediate (double)
            I_OPCODE:
                case(funct3)
                    ADDSUB_FUNCT3 : dec_inst = $sformatf("addi x%1d,x%1d,0x%1h", rd, rs1, i_imm);
                    SLL_FUNCT3 : dec_inst = $sformatf("slli x%1d,x%1d,0x%1h", rd, rs1, i_imm);
                    SLT_FUNCT3 : dec_inst = $sformatf("slti x%1d,x%1d,0x%1h", rd, rs1, i_imm);
                    SLTU_FUNCT3 : dec_inst = $sformatf("sltiu x%1d,x%1d,0x%1h", rd, rs1, i_imm);
                    XOR_FUNCT3 : dec_inst = $sformatf("xori x%1d,x%1d,0x%1h", rd, rs1, i_imm);
                    SRLSRA_FUNCT3 : 
                        if (funct7[5] == 1) dec_inst = $sformatf("srai x%1d,x%1d,0x%1h", rd, rs1, i_imm[4:0]);
                        else dec_inst = $sformatf("srli x%1d,x%1d,0x%1h", rd, rs1, i_imm);
                    OR_FUNCT3 : dec_inst = $sformatf("ori x%1d,x%1d,0x%1h", rd, rs1, i_imm);
                    AND_FUNCT3 : dec_inst = $sformatf("andi x%1d,x%1d,0x%1h", rd, rs1, i_imm);
                    default: begin
                        dec_inst = $sformatf("IMMEDIATE with UNKNOWN funct3 0x%1h",funct3);
                    end
                endcase
            default dec_inst = "N/A";
        endcase
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
function reg [256*8-1:0] copy_string(input string str);
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

function  print_string(input reg [256*8-1:0] str);
    automatic int i;
    for (i=0;i<256;i=i+1) begin
        $write("0x%h-%1d ",str[(i+1)*8-1-:8],i);
        if (i%16 == 0)
            $display();
    end
    $display();
endfunction

// Calculate result of the ALU
function automatic int alu_result(input [31:0] instruction, input[31:0] op1, input[31:0] op2);

    logic [6:0] i_op = instruction[6:0];
    logic [2:0] i_funct3 = instruction[14:12];
    logic [6:0] i_funct7 = instruction[31:25];

    //$display("i=%h op1=%h op2=%h",instruction,op1,op2);
    case(i_op)
        L_OPCODE: alu_result = op1 + op2;
        S_OPCODE: alu_result = op1 + op2;
        BR_OPCODE: alu_result = op1 - op2;
        default: // R or Immediate instructions
            case(i_funct3)
                ADDSUB_FUNCT3: 
                    if (i_op == R_OPCODE && 
                        i_funct7 ==  7'b0100000)
                        alu_result = op1 - op2;
                    else
                        alu_result = op1 + op2;
                SLL_FUNCT3: alu_result = op1 << op2[4:0];
                SLT_FUNCT3: alu_result = ($signed(op1) < $signed(op2)) ? 32'd1 : 32'd0;
                AND_FUNCT3: alu_result = op1 & op2;
                OR_FUNCT3: alu_result = op1 | op2;
                XOR_FUNCT3: alu_result = op1 ^ op2;
                SRLSRA_FUNCT3: 
                    if (i_funct7 ==  7'b0100000)
                        alu_result = $unsigned($signed(op1) >>> op2[4:0]);
                    else
                        alu_result =  op1 >> op2[4:0];
                default: alu_result = op1 + op2;
            endcase
    endcase

    //$display("i=%h op1=%h op2=%h r=%h",instruction,op1,op2,alu_result);

endfunction

// Print IF stage information and check validity
function automatic int if_stage_check(
    input logic[31:0] tb_pc, 
    input logic[31:0]  rtl_pc,
    input logic tb_imemread = 1, 
    input logic rtl_imemread = 1);

    int errors = 0;

    $write("  IF: PC=0x%8h",tb_pc);
    if (!tb_imemread) begin
        $write(" Load Use Stall (iMemRead=0)");				
    end
    if (tb_pc != rtl_pc) begin
        $write(" ** ERR** incorrect PC=%h", rtl_PC);
        errors = errors + 1;
    end
    if (tb_imemread != rtl_imemread) begin
        $write(" ** ERR** incorrect iMemRead=%1h", rtl_imemread);
        errors = errors + 1;
    end
    $display();

    if_stage_check = errors;

endfunction

function automatic int id_stage_check(
    input logic [31:0] tb_id_pc, 
    input logic [31:0] tb_id_instruction,
    input logic [31:0] rtl_id_instruction,
    input logic tb_imemread = 1, 
    input logic insert_ex_bubble = 0);

    int errors = 0;

    $write("  ID: PC=0x%8h I=0x%8h [%s]",tb_id_pc, tb_id_instruction, dec_inst(tb_id_instruction));
    if (!tb_imemread)
        $write(" Load Use Stall");
    if (insert_ex_bubble)
        $write(" Insert Bubble into EX");	
    // If there is a bubble in the id_PC, ignore the compare
    if (!(tb_id_pc[0] === 1'bX) && rtl_id_instruction != tb_id_instruction) begin
        $write(" ** ERR ** I=%h but expecting:%h", rtl_id_instruction, tb_id_instruction);
        errors = errors + 1;
    end
    else if(^tb_id_instruction[0] === 1'bx) begin
        $write(" ** ERR ** Bad instruction read");
        errors = errors + 1;
    end
    if (!valid_inst(rtl_id_instruction) && !(^rtl_id_instruction[0] === 1'bx)) begin
        $display(" Unknown Instruction=%h", rtl_id_instruction);
        errors = errors + 1;
    end
    $display();

    id_stage_check = errors;

endfunction

function int uses_alu(input logic [31:0] instruction);

	logic [6:0] instruction_ex_op;
    logic [2:0] instruction_ex_rd;

	assign  instruction_ex_op = instruction[6:0];
	assign  instruction_ex_rd = instruction[11:7];

	if (instruction_ex_op == S_OPCODE ||
				instruction_ex_op == L_OPCODE ||
				instruction_ex_op == BR_OPCODE ||
				((instruction_ex_op == I_OPCODE ||    // ALU Op that doesn't write to r0
				  instruction_ex_op == R_OPCODE) &&
				  instruction_ex_rd != 0)
				)
        uses_alu = 1;
    else
        uses_alu = 0;

endfunction


function automatic int ex_stage_check(
    input logic [31:0] tb_ex_PC, 
    input logic [31:0] tb_ex_instruction,
    input logic [31:0] tb_ex_aluresult,
    input logic [31:0] rtl_ALUResult,
    input logic [31:0] tb_mem_aluresult,
    input logic [31:0] tb_wb_writedata,
    input int forwardA = 0,
    input int forwardB = 0,
    input logic insert_mem_bubble = 0
    );

    int errors = 0;

    $write("  EX: PC=0x%8h I=0x%8h [%s]", tb_ex_PC,tb_ex_instruction,dec_inst(tb_ex_instruction));
    if (uses_alu(tb_ex_instruction)) begin
        $write(" alu result=0x%1h ",tb_ex_aluresult);
        if (forwardA == 1)
            $write(" [FWD MEM(0x%1h) to r1]",tb_mem_aluresult);
        else if (forwardA == 2)
            $write(" [FWD WB(0x%1h) to r1]",tb_wb_writedata);
        if (forwardB == 1)
            $write(" [FWD MEM(0x%1h) to r2]",tb_mem_aluresult);
        else if (forwardB == 2)
            $write(" [FWD WB(0x%1h) to r2]",tb_wb_writedata);
        if (rtl_ALUResult != tb_ex_aluresult) begin
            $write(" ** ERR ** incorrect alu result=%1h but expecting %1h", rtl_ALUResult, tb_ex_aluresult);
            errors = errors + 1;
        end
    end
    if (insert_mem_bubble)
        $write(" Insert Bubble");			
    $display();

    ex_stage_check = errors;

endfunction

function automatic int mem_stage_check(
    input logic [31:0] tb_mem_PC, 
    input logic [31:0] tb_mem_instruction,
    input logic [31:0] tb_mem_dAddress,
    input logic [31:0] tb_mem_dWriteData,
    input logic [31:0] rtl_mem_dAddress,
    input logic [31:0] rtl_mem_dWriteData,
    input logic rtl_MemRead,
    input logic rtl_MemWrite,
    input logic tb_branch_taken
    );

    logic [7:0] tb_mem_insruction_op = tb_mem_instruction[6:0];

    int errors = 0;

    $write("  MEM:PC=0x%8h I=0x%8h [%s]",tb_mem_PC,tb_mem_instruction, dec_inst(tb_mem_instruction));

    // Make sure settings for memory interface are correct based on the current instruciton
    if (tb_mem_insruction_op == S_OPCODE || tb_mem_insruction_op == L_OPCODE) begin
        // This is a load or a store. Check the address
        if (rtl_mem_dAddress != tb_mem_dAddress) begin
            $write(" Err: Memory address=0x%1h but expecting address 0x%1h",rtl_mem_dAddress,tb_mem_dAddress);
            errors = errors + 1;
        end

        // Is this a store instruction? Check to see that memory is used properly
        if (tb_mem_insruction_op == S_OPCODE) begin
            if (rtl_MemRead) begin
                $write(" ERROR: MemRead should be 0 (store instruction)");
                errors = errors + 1;
            end
            if (!rtl_MemWrite) begin
                $write(" ERROR: MemWrite should be 1 (store instruction)");
                errors = errors + 1;
            end
            if (rtl_mem_dWriteData != tb_mem_dWriteData) begin
                $write(" Err: Memory Write value 0x%1h but expecting value 0x%1h",rtl_mem_dWriteData,tb_mem_dWriteData);
                errors = errors + 1;
            end
            if (rtl_mem_dAddress == tb_mem_dAddress && rtl_mem_dWriteData == tb_mem_dWriteData) begin
                // Valid write debug message
                $write(" Memory Write 0x%1h to address 0x%1h ",rtl_dWriteData,rtl_dAddress);
            end
        // Is this a load instruction? Check to see that memory is used properly
        end else if (tb_mem_insruction_op == L_OPCODE) begin
            if (!rtl_MemRead) begin
                $write(" ERR: MemRead should be 1");
                errors = errors + 1;
            end
            if (rtl_MemWrite) begin
                $write(" ERR: MemWrite should be 0");
                errors = errors + 1;
            end
            if (rtl_mem_dAddress == tb_mem_dAddress && rtl_mem_dWriteData == tb_mem_dWriteData) begin
                $write(" Memory Read from address 0x%1h ",tb_mem_dAddress);  // Note: data not ready until next cycle
            end
        end 

    end

    else begin
        // If it is not an instruction that uses memory, make sure the memory is not being used
        // (No debug necessary if no read operations are occuring)
        if (rtl_MemRead) begin
            $write(" ERROR: MemRead should be 0");
            errors = errors + 1;
        end
        if (rtl_MemWrite) begin
            $write(" ERROR: MemWrite should be 0");
            errors = errors + 1;
        end
    end

    // See if we have a branch instruction and indicate whether it is taken or not
    if (tb_mem_insruction_op == BR_OPCODE) begin
        if (tb_branch_taken == 1)
            $write(" Branch Taken");
        else
            $write(" Branch NOT Taken");
    end

    // See if there is a jump in the stage
    if (tb_mem_insruction_op == JAL_OPCODE || 
        tb_mem_insruction_op == JALR_OPCODE)
        $write(" Jump Taken");

    $display();

    mem_stage_check = errors;

endfunction


function automatic int wb_stage_check(
    input logic [31:0] tb_wb_PC, 
    input logic [31:0] tb_wb_instruction,
    input logic [31:0] tb_wb_WriteBackData,
    input logic [31:0] rtl_wb_WriteBackData,
    input logic tb_wb_RegWrite
    );

    int errors = 0;

    $write("  WB: PC=0x%8h I=0x%8h [%s] ",tb_wb_PC,tb_wb_instruction,dec_inst(tb_wb_instruction));
    // Check to see if this instruction writes back to the register file
    if (tb_wb_RegWrite) begin
        if (!(rtl_wb_WriteBackData === tb_wb_WriteBackData)) begin
            $write(" ** ERR** expecting to write back data=0x%1h but received 0x%1h", tb_wb_WriteBackData, rtl_wb_WriteBackData);
            errors = errors + 1;
        end else if (^rtl_wb_WriteBackData === 1'bX || ^tb_wb_WriteBackData === 1'bX) begin
            $write(" ** ERR** Write back data is undefined=0x%1h", tb_wb_WriteBackData);
            errors = errors + 1;
        end
        else begin
            $write("WriteBackData=0x%1h ",rtl_wb_WriteBackData);
        end
    end

    wb_stage_check = errors;

endfunction