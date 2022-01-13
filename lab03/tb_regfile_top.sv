`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: tb_regfile_top.sv
//
//  Author: Mike Wirthlin
//  
//  Description: 
//
//
//////////////////////////////////////////////////////////////////////////////////

module tb_regfile_top();

	logic tb_clk, tb_btnc, tb_btnd, tb_btnu, tb_btnl;
	logic [15:0] tb_led;
    logic [15:0] tb_sw;

	// Instance regfile module
    regfile_top my_datapath(.clk(tb_clk), .btnc(tb_btnc), .sw(tb_sw), .btnd(tb_btnd),
        .btnl(tb_btnl), .btnu(tb_btnu), .led(tb_led));

    datapathBehavioralModel model(.clk(tb_clk), .btnc(tb_btnc), .sw(tb_sw), .btnd(tb_btnd),
        .btnl(tb_btnl), .btnu(tb_btnu), .led(tb_led));

    task sim_clocks(input int clocks);
		automatic int i;
		for(i=0; i < clocks; i=i+1) begin
			//@(negedge tb_clk);
            #5 tb_clk = 1; #5 tb_clk = 0;
        end
    endtask

    localparam POST_SW_CLOCKS = 4;
    localparam BUTTON_HIGH_CLOCKS = 3;
    localparam POST_BUTTON_CLOCKS = 4;

    localparam[3:0] ALUOP_AND = 4'b0000;
    localparam[3:0] ALUOP_XOR = 4'b1101;
    localparam[3:0] ALUOP_LT = 4'b0111;
    localparam[3:0] ALUOP_ADD = 4'b0010;
    localparam[3:0] ALUOP_SUB = 4'b0110;
    localparam[3:0] ALUOP_OR = 4'b0001;
    localparam[3:0] ALUOP_SRL = 4'b1000;
    localparam[3:0] ALUOP_SLL = 4'b1001;
    localparam[3:0] ALUOP_SRA = 4'b1010;

    // Load the address register
    task load_addr_reg(input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
        tb_sw = (rd << 10) | (rs2 << 5) | rs1;
        sim_clocks(POST_SW_CLOCKS);
        // Press btnl
        tb_btnl = 1;
        sim_clocks(BUTTON_HIGH_CLOCKS);
        // release btnl
        tb_btnl = 0;
        sim_clocks(POST_BUTTON_CLOCKS);
    endtask

    // Execute an operation (2 phases: load address register and issue operation)
    task execute_op(input [4:0] rd, input [4:0] rs1, input [4:0] rs2, input [3:0] op);
        load_addr_reg(rd,rs1,rs2);
        sim_clocks(10);
        // Load operation (lower 4 bits of k)
        tb_sw = op;
        sim_clocks(POST_SW_CLOCKS);
        tb_btnc = 1;
        sim_clocks(BUTTON_HIGH_CLOCKS);
        tb_btnc = 0;
        sim_clocks(POST_BUTTON_CLOCKS);
    endtask

    // Load a register with a value
    task load_reg(input [4:0] rd, input [14:0] value);
        load_addr_reg(rd,rd,0);
        sim_clocks(10);
        // Load value into register
        tb_sw = 16'h8000 | value;
        sim_clocks(POST_SW_CLOCKS);
        tb_btnc = 1;
        sim_clocks(BUTTON_HIGH_CLOCKS);
        tb_btnc = 0;
        sim_clocks(POST_BUTTON_CLOCKS);
    endtask

	initial begin
	    int i,j,k;
        //shall print %t with scaled in ns (-9), with 2 precision digits, and would print the " ns" string
		$timeformat(-9, 0, " ns", 20);
		$display("*** Start of Top-Level Regfile Testbench Simulation ***");
		
		// Run for some time without valid inputs
		#50
		
		// execute a few clocks without any reset
        sim_clocks(3);

		// set deaults
        tb_btnd = 0;
        tb_btnc = 0;
        tb_btnl = 0;
        tb_sw = 0;
        tb_btnu = 0;
        sim_clocks(2);
        // Issue reset
        tb_btnu = 1;
        sim_clocks(1);
		tb_btnu = 0;
        sim_clocks(2);
		
        // Put initial values into all of the registers
		for(i=0; i < 32; i=i+1) begin
            load_reg(i, (i | (i << 8)));
		end

        // Put a -1 in register 1
        load_reg(1, -1);

        sim_clocks(30);
        // Invert some registers using XOR
		for(i=2; i < 6; i=i+1) begin
            execute_op(i,1,i,ALUOP_XOR); // XOR
        end
        // Perform some less than (both ways)
		for(i=0; i < 4; i=i+1) begin
            execute_op(31,i,i+1,ALUOP_LT);
            execute_op(31,i+1,i,ALUOP_LT);
        end
        // Perform some AND
		for(i=4; i < 8; i=i+1) begin
            execute_op(i,i,i+1,ALUOP_AND);
        end
        // Perform some ADD
		for(i=8; i < 12; i=i+1) begin
            execute_op(i,i,i+1,ALUOP_ADD);
        end
        // Perform some SUB
		for(i=12; i < 16; i=i+1) begin
            execute_op(i,i,i+1,ALUOP_SUB);
        end
        // Perform some OR
		for(i=16; i < 20; i=i+1) begin
            execute_op(i,i,i+1,ALUOP_OR);
        end
        // Perform some SRL
		for(i=20; i < 23; i=i+1) begin
            execute_op(i,i,i+1,ALUOP_SRL);
        end
        // Perform some SLL
		for(i=23; i < 26; i=i+1) begin
            execute_op(i,i,i+1,ALUOP_SLL);
        end
        // Perform some SRA
		for(i=26; i < 29; i=i+1) begin
            execute_op(i,i,i+1,ALUOP_SRA);
        end

        // read both halfs of every register
		$display("*** Reading both halfs of every register ***");
		for(i=0; i < 32; i=i+1) begin
            // Read lower half of register
            tb_btnd = 0;
            load_addr_reg(i,i,i);
            sim_clocks(BUTTON_HIGH_CLOCKS+POST_BUTTON_CLOCKS);
            #1
            // Read upper half of register
            tb_btnd = 1;
            sim_clocks(BUTTON_HIGH_CLOCKS+POST_BUTTON_CLOCKS);
            #1
            tb_btnd = 0;
        end

		$display("*** Successful simulation. Ended at %0t *** ", $time);
        $finish;
        
	end  // end initial

endmodule

// Behavioral module that will test Register file
module datapathBehavioralModel(clk, sw, btnc, btnd, btnl, btnu, led);

	input wire logic clk, btnc, btnd, btnl, btnu;
    input wire logic [15:0] sw;
	input wire logic [15:0] led;

	parameter stop_on_error = 1;
	int initialized = 0;
    logic btnu_d;
    logic [31:0] tmpfile [31:0];  
    logic btnl_d, btnl_os;
    logic btnc_d, btnc_os;
    //logic btnr_d, btnr_os;
    logic [31:0] l_readA, l_readB;
    logic [14:0] addresses;
    logic [4:0] rd, rs1, rs2;
    logic [31:0] se_sw, writeData;
    logic [31:0] alu;
    logic [3:0] op;
    logic [15:0] l_result;

    localparam[3:0] ALUOP_AND = 4'b0000;
    localparam[3:0] ALUOP_XOR = 4'b1101;
    localparam[3:0] ALUOP_LT = 4'b0111;
    localparam[3:0] ALUOP_ADD = 4'b0010;
    localparam[3:0] ALUOP_SUB = 4'b0110;
    localparam[3:0] ALUOP_OR = 4'b0001;
    localparam[3:0] ALUOP_SRL = 4'b1000;
    localparam[3:0] ALUOP_SLL = 4'b1001;
    localparam[3:0] ALUOP_SRA = 4'b1010;
    
    // Signal to check the state
    int check_led_cnt = 0;
    logic check_led;
    localparam BUTTON_DELAY_CHECK = 3;
	always@(negedge clk) begin
        check_led <= 0;
		if (initialized) begin
            if (check_led_cnt == 0 && (btnd || btnc) )
                check_led_cnt <= 1;
            else if (check_led_cnt != 0) begin
                if (check_led_cnt == BUTTON_DELAY_CHECK) begin
                    check_led_cnt <= 0;
                    check_led <= 1;                
                end
                else
                    check_led_cnt <= check_led_cnt + 1;
            end

        end
    end

	// checking state
	always@(negedge clk) begin
		if (initialized && check_led) begin
			if (^led[0] === 1'bX) begin
				$display("**** Error: 'x' Values on LEDs at time %0t", $time);
				$finish;
			end
			if (l_result != led) begin
				$display("*** Error: LED=0x%h but should be 0x%h at time %0t", led, l_result,  $time);
				if (stop_on_error)
					$finish;
			end
            //else
			//	$display("OK at %0t", $time);
		end
	end


	// Initialize state of temp regfile
	integer i;
	initial begin
        for (i=0;i<32;i=i+1)
           tmpfile[i] = 0;
    end

	always@(posedge clk) begin
        btnl_d <= btnl;
        btnl_os <= btnl & ~btnl_d;
        //btnr_d <= btnr;
        //btnr_os <= btnr & ~btnr_d;
        btnu_d <= btnu;
        btnc_d <= btnc;
        btnc_os <= btnc & ~btnc_d;
    end

    assign rd = addresses[14:10];
    assign rs2 = addresses[9:5];
    assign rs1 = addresses[4:0];
    assign writeData = sw[15] ? se_sw : alu;

	always@(posedge clk) begin
		if (btnu_d) begin 
            addresses <= 0;
            initialized <= 1;
        end
        if (initialized) begin
            if (btnl_os) begin
                addresses <= sw[14:0];
                $display("%0t: Setting register addresses rd=[%0d] rs2=[%0d] rs1=[%0d] ", $time,
                    sw[14:10],sw[9:5],sw[4:0]);
            end
            l_readA <= tmpfile[rs1];
            l_readB <= tmpfile[rs2];
            if (btnc_os && rd !=0) begin
                if (sw[15]) begin
                    $display("%0t: Write Value: R[%0d]=0x%h ", $time, rd, writeData);
                end
                else begin
                    $write("%0t: ALU OP (%0b): R[%0d]=R[%0d](0x%h) ", $time, op, rd, rs1, l_readA);
                    case(op)
                        ALUOP_AND: $write("AND");
                        ALUOP_OR: $write("OR");
                        ALUOP_ADD: $write("Add");
                        ALUOP_SUB: $write("Sub");
                        ALUOP_LT: $write("<");
                        ALUOP_XOR: $write("XOR");
                        ALUOP_SRL: $write(">>");
                        ALUOP_SLL: $write("<<");
                        ALUOP_SRA: $write(">>>");
                        default: $write("Add");
                    endcase
                    $display( " R[%0d](0x%h) = 0x%h ", rs2, l_readB, alu);
                    //$display( " R[%0d](0x%h)", rs2, l_readB);
                end
                tmpfile[rd] <= writeData;
                // if reading same register we are wrting, return new data
                if (rs1 == rd)
                    l_readA <= writeData;
                if (rs2 == rd)
                    l_readB <= writeData;
            end        
        end
    end

    // Simple ALU model
    assign se_sw = {{17{sw[14]}}, sw[14:0]};
    assign op = sw[3:0];
    assign alu =    (op == ALUOP_AND) ? l_readA & l_readB :
                    (op == ALUOP_OR) ? l_readA | l_readB :
                    (op == ALUOP_ADD) ? l_readA + l_readB :
                    (op == ALUOP_SUB) ? l_readA - l_readB :
                    (op == ALUOP_LT) ?  (($signed(l_readA) < $signed(l_readB)) ? 32'b1 : 32'b0) :
                    (op == ALUOP_XOR) ? l_readA ^ l_readB :
                    (op == ALUOP_SRL) ?  l_readA >> l_readB[4:0] :
                    (op == ALUOP_SLL) ?  l_readA << l_readB[4:0] :
                    (op == ALUOP_SRA) ?  $unsigned($signed(l_readA) >>> l_readB[4:0]) :
                    l_readA + l_readB;
    assign l_result = btnd ? l_readA[31:16] : l_readA[15:0];


endmodule
