`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: riscv_pipeline_tb.v
//
//  Author: Mike Wirthlin
//   
//////////////////////////////////////////////////////////////////////////////////

module riscv_pipeline_tb();

    reg clk, rst;
    wire [31:0] tb_PC, tb_ALUResult, tb_Address, tb_dWriteData, tb_WriteBackData;
    wire tb_MemRead, tb_MemWrite;

    reg [31:0] tb_dReadData;
    reg [31:0] tb_instruction;
    integer i;
    integer error_count;
    
    parameter TEXT_MEMORY_FILENAME = "pipeline_nop_text.mem";
    parameter DATA_MEMORY_FILENAME = "pipeline_nop_data.mem";
    localparam EBREAK_INSTRUCTION = 32'h00100073;
    localparam TEXT_SEGMENT_START_ADDRESSS = 32'h00000000; // 32'h00400000;
    localparam INSTRUCTION_MEMORY_WORDS = 128;
    // Data memory
    localparam DATA_MEMORY_WORDS = 64;
    localparam DATA_SEGMENT_START_ADDRESSS = 32'h00002000;
    localparam DATA_SEGMENT_END_ADDRESSS = DATA_SEGMENT_START_ADDRESSS + DATA_MEMORY_WORDS*4-1;

    // Instance student pipeline processor
    riscv_basic_pipeline #(.INITIAL_PC(TEXT_SEGMENT_START_ADDRESSS))  
                        riscv(.clk(clk), .rst(rst), .instruction(tb_instruction), .PC(tb_PC), 
                            .ALUResult(tb_ALUResult), .dAddress(tb_Address), .dWriteData(tb_dWriteData), .dReadData(tb_dReadData),
                            .MemRead(tb_MemRead), .MemWrite(tb_MemWrite), .WriteBackData(tb_WriteBackData) );
                            
    // Instance simulation model
    riscv_sim_model #(.INITIAL_PC(TEXT_SEGMENT_START_ADDRESSS), .DATA_MEMORY_START_ADDRESSS(DATA_SEGMENT_START_ADDRESSS) ) 
                        riscv_model(.tb_clk(clk), .tb_rst(rst), .tb_PC(tb_PC), .tb_Instruction(tb_instruction), .tb_ALUResult(tb_ALUResult),
                            .tb_dAddress(tb_Address), .tb_dWriteData(tb_dWriteData), .tb_dReadData(tb_dReadData), 
                            .tb_MemRead(tb_MemRead), .tb_MemWrite(tb_MemWrite), .tb_WriteBackData(tb_WriteBackData),
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
            $fatal;
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
            $fatal;
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

    // Initialize the simulation with reset
    initial begin
        $display("===== RISCV PIPELINE TESTBENCH =====");
        $display(" use run -all");

        //////////////////////////////////
        //	Reset
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

        // Execute up to the maximum number of instructions, the ebreak instructions, or an error
        for(i=0; i<MAX_INSTRUCTIONS && !(tb_instruction === EBREAK_INSTRUCTION) && error_count == 0 ; i = i+1) begin
            clk <=1; #5;
            clk <=0; #5;
        end

        // Check for errors
        if (error_count > 0) begin
            $display("ERROR: %1d error(s) found",error_count);
            $fatal(1);
        end
        if (i == MAX_INSTRUCTIONS) begin
            // Didn't reach EBREAK_INSTRUCTION
            $display("ERROR: Did not reach the EBREAK Instruction");
            $fatal(1);
        end

        // If no errors, all is well
        if (error_count == 0)	
            $display("You Passed!");
        else
            // shouldn't get here
            $display("Testbench failed");
        // End simulation
        $finish;

    end


endmodule

module riscv_sim_model #(parameter INITIAL_PC = 32'h00400000, DATA_MEMORY_START_ADDRESSS = 32'h10010000) 
    (tb_clk, tb_rst, tb_PC, tb_Instruction, tb_ALUResult, tb_dAddress, tb_dWriteData, 
    tb_dReadData, tb_MemRead, tb_MemWrite, tb_WriteBackData, inst_mem_filename, data_mem_filename, error_count);

    input tb_clk, tb_rst;
    input [31:0] tb_PC, tb_Instruction;
    input [31:0] tb_ALUResult;
    input [31:0] tb_dAddress;
    input [31:0] tb_dWriteData;
    input [31:0] tb_dReadData;
    input [31:0] tb_WriteBackData;
    input tb_MemRead, tb_MemWrite;
    input string inst_mem_filename, data_mem_filename;
    output [31:0] error_count;
        
    // Internal shadow state
    logic [31:0] int_reg [31:0];
    //typePack::instruction_t instruction_if, instruction_id, instruction_ex, instruction_mem, instruction_wb;
    logic [31:0] instruction_id, instruction_ex, instruction_mem, instruction_wb;
    logic [31:0] instruction;
    logic [31:0] if_PC, id_PC, ex_PC;
    logic [31:0] ex_read1, ex_read2, ex_operand2;
    logic [31:0] ex_branch_target, ex_alu_result;
    logic [31:0] mem_dAddress, mem_dWriteData, mem_branch_target, mem_alu_result;
    logic mem_branch_taken;
    logic [31:0] wb_writedata, wb_dReadData, wb_alu_result;
    logic wb_RegWrite;
    logic [31:0] pc_id, pc_ex, pc_mem, pc_wb;
    logic [31:0] tb_instruction_ex ,tb_instruction_mem, tb_instruction_wb;	
    logic mem_MemRead, mem_MemWrite;
    reg [31:0] errors=0;
    
    assign error_count = errors;
    
    `include "../include/tb_pipeline_inc.sv"

    initial begin
        $timeformat(-9, 0, " ns", 20);
        $display("===== RISC-V Pipeline Simulation Model =====");
    end
        
    // Need to allow students to have x's in their WB stage as the processor fills the pipeline
    // This signal is a shift register that keeps track of the valid stages to allow x's until
    // the pipeline fills up. 
    logic [4:0] valid_wb = 0; 
    always_ff@(posedge tb_clk) begin
        if (tb_rst)
            valid_wb = 0;
        else
            valid_wb <= { valid_wb[3:0] , 1'b1 };
    end

    // Create a debug message at each negative edge of the clock
    always@(negedge tb_clk) begin
        
        if ($time != 0) begin

            // Print time message
            $display("%0t:",$time);

            // Print IF stage debug
            $write("  IF: PC=0x%8h",tb_PC);
            if (if_PC != tb_PC || ^tb_PC[0] === 1'bX) begin
                $display(" ** ERR** expecting PC=%h", if_PC);
                errors = errors + 1;
            end
            else $display();
                
            // Print ID stage debug
            $write("  ID: PC=0x%8h I=0x%8h [%s]",pc_id,tb_Instruction, dec_inst(tb_Instruction));
            if (tb_Instruction != instruction_id || ^tb_Instruction[0] === 1'bX) begin
                $display(" ** ERR** expecting Instruction=%h", instruction_id);
                errors = errors + 1;
            end
            else if (!valid_inst(tb_Instruction)) begin
                $display(" Unknown Instruction=%h", tb_Instruction);
                errors = errors + 1;
            end
            else $display();
            
            $write("  EX: PC=0x%8h I=0x%8h [%s] alu result=0x%h ",pc_ex,tb_instruction_ex,dec_inst(tb_instruction_ex),tb_ALUResult);
            if (tb_ALUResult != ex_alu_result || ^tb_ALUResult[0] === 1'bX) begin
                $display(" ** ERR** expecting alu result=%h", ex_alu_result);
                errors = errors + 1;
            end
            else $display();

            $write("  MEM:PC=0x%8h I=0x%8h [%s] ",pc_mem,tb_instruction_mem, dec_inst(tb_instruction_mem));
            // Check for undefined memory control signals
            if ($isunknown(tb_MemRead)) begin
                    $write("*** ERR: MemRead undefined ");
                    errors = errors + 1;				
            end
            else if ($isunknown(tb_MemWrite))begin
                    $write("*** ERR: MemWrite undefined ");
                    errors = errors + 1;								
            end
            // Print debug message for memory stage
            if (mem_MemRead == 1'b0 && mem_MemWrite == 1'b0) // No reads or writes going on in simulation model
                if (tb_MemRead) begin 
                    $write("*** ERR: MemRead should be low ");
                    errors = errors + 1;
                end else if (tb_MemWrite) begin
                    $write("*** ERR: MemWrite should be low ");
                    errors = errors + 1;
                end else $write("No memory read/write ");  // debug message (all is well)

            else if (mem_MemRead == 1'b1 && mem_MemWrite == 1'b0)  // Memory read in simulation model
                if (!tb_MemRead) begin
                    $write("*** ERR: MemRead should be high ");
                    errors = errors + 1;
                end else if (tb_MemWrite) begin
                    $write("*** ERR: MemWrite should be low ");
                    errors = errors + 1;
                end else if (tb_dAddress != mem_dAddress) begin
                    $write("*** Err: Memory Read to address 0x%1h but expecting address 0x%1h",tb_dAddress,mem_dAddress);
                    errors = errors + 1;
                end else $write("Memory Read from address 0x%1h ",tb_dAddress);  // Note: data not ready until next cycle

            else if (mem_MemRead == 1'b0 && mem_MemWrite == 1'b1)  // Memory write in simulation model
                if (tb_MemRead) begin
                    $write("*** ERR: MemRead should be low ");
                    errors = errors + 1;
                end else if (!tb_MemWrite) begin
                    $write("*** ERR: MemWrite should be high ***");
                    errors = errors + 1;
                end else if (tb_dAddress != mem_dAddress) begin
                    $write("*** Err: Memory Write to address 0x%1h but expecting address 0x%1h",tb_dAddress,mem_dAddress);
                    errors = errors + 1;
                end else if (tb_dWriteData != mem_dWriteData) begin
                    $write("*** Err: Memory Write value 0x%1h but expecting value 0x%1h",tb_dWriteData,mem_dWriteData);
                    errors = errors + 1;
                end else $write("Memory Write 0x%1h to address 0x%1h ",tb_dWriteData,tb_dAddress);
            else begin  // Should never get here (simulation model will not do simulataneous read/write)
                $write("*** ERROR: simultaneous read and write ");
                errors = errors + 1;				
            end
            $display();

            // Write back debug messages
            $write("  WB: PC=0x%8h I=0x%8h [%s] ",pc_wb,tb_instruction_wb,dec_inst(tb_instruction_wb));
            $write("WriteBackData=0x%h ",tb_WriteBackData);
            if (!(tb_WriteBackData === wb_writedata)) begin
                $display(" ** ERR** expecting write back data=%h", wb_writedata);
                errors = errors + 1;
            end else if ( (^tb_WriteBackData === 1'bX || ^wb_writedata === 1'bX) && valid_wb[4] == 1'b1) begin
                $display(" ** ERR** Write back data is undefined=%h", wb_writedata);
                errors = errors + 1;
            end else $display();

        end
    end

    //////////////////////////////////////////////////////////////////////////////////
    // pipeline
    //////////////////////////////////////////////////////////////////////////////////
    always@(posedge tb_clk) begin
        if (tb_rst) begin
            //instruction_if <= NOP_INSTRUCTION;
            //instruction_id <= NOP_INSTRUCTION;
            instruction_ex <= NOP_INSTRUCTION;
            instruction_mem <= NOP_INSTRUCTION;
            instruction_wb <= NOP_INSTRUCTION;
            pc_id <= 32'bx;
            pc_ex <= 32'bx;
            pc_mem <= 32'bx;
            pc_wb <= 32'bx;
            tb_instruction_ex <= NOP_INSTRUCTION;
            tb_instruction_mem <= NOP_INSTRUCTION;
            tb_instruction_wb <= NOP_INSTRUCTION;
        end
        else begin
            //instruction_id <= instruction_if;
            instruction_ex <= instruction_id;
            instruction_mem <= instruction_ex;
            instruction_wb <= instruction_mem;
            pc_id <= tb_PC;
            pc_ex <= pc_id;
            pc_mem <= pc_ex;
            pc_wb <= pc_mem;
            tb_instruction_ex <= tb_Instruction;
            tb_instruction_mem <= tb_instruction_ex;
            tb_instruction_wb <= tb_instruction_mem;
        end
    end

    // IF
    always@(posedge tb_clk or posedge tb_rst) begin
        if (tb_rst)
            if_PC <= INITIAL_PC;
        else begin
            if (mem_branch_taken)
                if_PC <= mem_branch_target;			
            else
                if_PC <= if_PC + 4;			
            id_PC <= if_PC;
        end
    end
    
    // Instruction Memory
    localparam INSTRUCTION_MEMORY_WORDS = 1024;  // 4x1024 - 4096 bytes
    logic [31:0] instruction_memory[INSTRUCTION_MEMORY_WORDS-1:0];
    reg [256*8-1:0] i_filename;
    initial begin
        i_filename = copy_string(inst_mem_filename);
        //i_filename = "pipeline_nop.txt";   print_string(i_filename);
        //$readmemh("pipeline_nop.txt", instruction_memory);
        $readmemh(i_filename, instruction_memory);
        if (^instruction_memory[0] === 1'bX) begin
            $display($sformatf("**** Error: RISC-V Simulation model instruction memory '%s' failed to load****",inst_mem_filename));
        end
        else
            $display($sformatf("**** RISC_V Simulation model: Loaded instruction memory '%s' ****",inst_mem_filename));
    end

    // Instruction memory read (synchronous read). No writes
    // Read every clock cycle (even if we will end up ignoring NOP instructions that are read)
    always@(posedge tb_clk) begin
        if (tb_rst) begin
          instruction <= NOP_INSTRUCTION;  // Initialize instruction with "NOP"
        end
        else begin
          instruction <= instruction_memory[(if_PC - INITIAL_PC) >> 2];
        end
    end
    assign instruction_id = instruction;
    
    // ID
    logic [4:0] instruction_id_rd;
    assign instruction_id_rd = instruction_id[11:7];
    logic [4:0] instruction_id_rs1;
    assign  instruction_id_rs1 = instruction_id[19:15];
    logic [4:0] instruction_id_rs2;
    assign instruction_id_rs2 = instruction_id[24:20];
    logic [4:0] instruction_mem_rd;
    assign instruction_mem_rd = instruction_mem[11:7];
    logic [4:0] instruction_wb_rd;
    assign instruction_wb_rd = instruction_wb[11:7];
    logic [4:0] instruction_wb_rs1;
    assign instruction_wb_rs1 = instruction_wb[19:15];
    logic [4:0] instruction_wb_rs2;
    assign instruction_wb_rs2 = instruction_wb[4:0];

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
            ex_PC <= id_PC;
        end
    end

    logic [6:0] instruction_ex_op;
    assign  instruction_ex_op = instruction_ex[6:0];
    logic [2:0] instruction_ex_funct3;
    assign instruction_ex_funct3 = instruction_ex[14:12];
    logic [6:0] instruction_ex_funct7;
    assign  instruction_ex_funct7 = instruction_ex[31:25];
    logic [31:0] instruction_ex_brImm;
    assign  instruction_ex_brImm = {{20{instruction_ex[31]}}, instruction_ex[7], 
            instruction_ex[30:25],  instruction_ex[11:8], 1'b0};
    logic [31:0] instruction_ex_Imm;
    assign instruction_ex_Imm = {{20{instruction_ex[31]}}, instruction_ex[31:20]};
    logic [31:0] instruction_ex_sImm;
    assign  instruction_ex_sImm= {{20{instruction_ex[31]}}, instruction_ex[31:25], instruction_ex[11:7]};

    always@(*) begin
            ex_branch_target = ex_PC + instruction_ex_brImm;
                //{{20{id_instruction[31]}},id_instruction[7],id_instruction[30:25],id_instruction[11:8],1'b0};
            // Immediate
            //ex_immediate = {{20{instruction_ex.itype.imm[11]}},instruction_ex.itype.imm};
            //ex_s_immediate = {{20{instruction_ex.stype.imm11_5[11]}},instruction_ex.stype.imm11_5,instruction_ex.stype.imm4_0};
    
            ex_operand2 = 
                        (instruction_ex_op == S_OPCODE) ?  instruction_ex_sImm : 
                        (instruction_ex_op == I_OPCODE ||
                         instruction_ex_op == L_OPCODE) ? instruction_ex_Imm :
                        ex_read2;

                    // ALU
            case(instruction_ex_op)
                L_OPCODE: ex_alu_result = ex_read1 + ex_operand2;
                S_OPCODE: ex_alu_result = ex_read1 + ex_operand2;
                BR_OPCODE: ex_alu_result = ex_read1 - ex_operand2;
                default: // R or Immediate instructions
                    case(instruction_ex_funct3)
                        ADDSUB_FUNCT3: 
                            if (instruction_ex_op == R_OPCODE && 
                                instruction_ex_funct7 ==  7'b0100000)
                                ex_alu_result = ex_read1 - ex_operand2;
                            else
                                ex_alu_result = ex_read1 + ex_operand2;
                        SLL_FUNCT3: ex_alu_result = ex_read1 << ex_operand2[4:0];
                        SLT_FUNCT3: ex_alu_result = ($signed(ex_read1) < $signed(ex_operand2)) ? 32'd1 : 32'd0;
                        AND_FUNCT3: ex_alu_result = ex_read1 & ex_operand2;
                        OR_FUNCT3: ex_alu_result = ex_read1 | ex_operand2;
                        XOR_FUNCT3: ex_alu_result = ex_read1 ^ ex_operand2;
                        SRLSRA_FUNCT3: 
                            if (instruction_ex_funct7 ==  7'b0100000)
                                ex_alu_result = $unsigned($signed(ex_read1) >>> ex_operand2[4:0]);
                            else
                                ex_alu_result =  ex_read1 >> ex_operand2[4:0];
                        default: ex_alu_result = ex_read1 + ex_operand2;
                    endcase
            endcase
    end
    
    
    always@(posedge tb_clk) begin
        if (tb_rst) begin
            mem_branch_target <= 0;
            mem_alu_result <= 0;
            mem_dWriteData <= 0;
        end
        else begin
            mem_branch_target <= ex_branch_target;
            mem_alu_result <= ex_alu_result;
            mem_dWriteData <= ex_read2;
        end
    end
    
    // Mem
    logic [6:0] instruction_mem_op;
    assign  instruction_mem_op = instruction_mem[6:0];
    assign mem_branch_taken = (instruction_mem_op == BR_OPCODE && mem_alu_result == 0);
    // Data memory
    localparam DATA_MEMORY_WORDS = 256;
    assign mem_dAddress = mem_alu_result;
    reg [256*8-1:0] d_filename;
    
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

    assign mem_MemRead = (instruction_mem_op == L_OPCODE);
    assign mem_MemWrite = (instruction_mem_op == S_OPCODE);
    always@(posedge tb_clk) begin
        if (tb_rst) begin
            wb_dReadData <= 0;
            wb_dReadData <= 0;
            wb_alu_result <= 0;
        end
        else begin
            if (mem_MemRead)
                wb_dReadData <= data_memory[(mem_dAddress - DATA_MEMORY_START_ADDRESSS) >> 2];
            if (mem_MemWrite)
                data_memory[(mem_dAddress - DATA_MEMORY_START_ADDRESSS) >> 2] <= mem_dWriteData;
            wb_alu_result <= mem_alu_result;
        end
    end
    
    
    // WB
    logic [6:0] instruction_wb_op;
    assign instruction_wb_op= instruction_wb[6:0];
    //logic [2:0] instruction_wb_rd = instruction_wb[11:7];
    assign wb_writedata = (instruction_wb_op == L_OPCODE) ? wb_dReadData : wb_alu_result;
    assign wb_RegWrite = ((instruction_wb_op == R_OPCODE || 
                    instruction_wb_op == I_OPCODE ||
                    instruction_wb_op == L_OPCODE)) && 
                    (instruction_wb_rd != 0);
        
    
endmodule