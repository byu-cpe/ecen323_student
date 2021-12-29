`timescale 1ns / 100ps
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: tb_regfile.sv
//
//  Author: Mike Wirthlin
//  
//  Description: 
//
//
//////////////////////////////////////////////////////////////////////////////////

module tb_regfile();

	logic tb_clk, tb_write;
    logic tb_init = 0;
    logic [4:0] regAddrA, regAddrB, regAddrWrite;
    logic [31:0] regWriteData, regReadDataA, regReadDataB;


	// Instance regfile module
    regfile my_regfile(.clk(tb_clk), .regAddrA(regAddrA), .regAddrB(regAddrB), .regAddrWrite(regAddrWrite),
        .regWriteData(regWriteData), .regWrite(tb_write), .regReadDataA(regReadDataA), .regReadDataB(regReadDataB));


    regfileBehavioralModel model(.clk(tb_clk), .initialized(tb_init), .regAddrA(regAddrA), .regAddrB(regAddrB), .regAddrWrite(regAddrWrite),
                             .regWriteData(regWriteData), .regWrite(tb_write), .regReadDataA(regReadDataA),
                             .regReadDataB(regReadDataB));

    task sim_clocks(input int clocks);
		automatic int i;
		for(i=0; i < clocks; i=i+1) begin
			//@(negedge tb_clk);
            #5 tb_clk = 1; #5 tb_clk = 0;
        end
    endtask

    task write_word(input [4:0] addr, input [31:0] data);
		automatic int i;
        regAddrWrite=addr;
        regWriteData=data;
        tb_write = 1;
        #5 tb_clk = 1; #5 tb_clk = 0;
        tb_write = 0;
    endtask

	initial begin
	    int i,j;
        //shall print %t with scaled in ns (-9), with 2 precision digits, and would print the " ns" string
		$timeformat(-9, 0, " ns", 20);
		$display("*** Start of Regfile Testbench Simulation ***");
		
		// Run for some time without valid inputs
		#50
		
		// execute a few clocks without any initialization
        sim_clocks(3);

        // Initilize inputs
        regAddrA=0;
        regAddrB=0; 
        regAddrWrite=0;
        regWriteData=0;
        tb_write = 0;
        sim_clocks(5);

        tb_init = 1;
        sim_clocks(1);

		$display("*** Testing x0 register at time %0t", $time);
        for(i=0; i < 32; i=i+1) begin
            write_word(0,(i+1)*255);
            sim_clocks(1);
        end
        sim_clocks(5);

        // initialize memories (with non-zero value in 0)
		$display("*** Testing write to each register at %0t", $time);
        for(i=1; i < 32; i=i+1) begin
            write_word(i,i);
            regAddrA=i;
            regAddrB=i; 
            sim_clocks(1);
        end
        sim_clocks(5);

        // initialize memories (with non-zero value in 0)
		$display("*** Testing simultaneous reads and writes to each register at %0t", $time);
        for(i=1; i < 32; i=i+1) begin
            regAddrA=i;
            regAddrB=i; 
            write_word(i,i|i<<8|i<<16|i<<24);
        end
        sim_clocks(5);

        // read contents of memory
		$display("*** Testing different read addresses at %0t", $time);
        for(i=0; i < 32; i=i+1) begin
            regAddrA=i;
            regAddrB=~i; 
            #5 tb_clk = 1; #5 tb_clk = 0;
        end

        // simulate some transactions
		$display("*** Testing random transaactions at %0t", $time);
        for(i=0; i < 300; i=i+1) begin
            j=$urandom_range(0,3);
            regAddrA=$urandom_range(0,31);
            regAddrB=~$urandom_range(0,31);
            if (j==0) begin
                //write
                write_word($urandom_range(0,31),$urandom);
            end
            else begin
                // read only            
                #5 tb_clk = 1; #5 tb_clk = 0;
            end
        end

		// Random delay
        sim_clocks($urandom_range(30,50));		

		$display("*** Successful simulation. Ended at %0t *** ", $time);
        $finish;
        
	end  // end initial

endmodule

// Behavioral module that will test Register file
module regfileBehavioralModel(clk, initialized, regAddrA, regAddrB, regAddrWrite, regWriteData, regWrite,
    regReadDataA, regReadDataB);

	input wire logic clk;
    input wire logic initialized;
    input wire logic [4:0] regAddrA;
    input wire logic [4:0] regAddrB;
	input wire logic [4:0] regAddrWrite;
    input wire logic [31:0] regWriteData;
	input wire logic regWrite;
    input wire logic [31:0] regReadDataA, regReadDataB;

    logic [31:0] tmpfile [31:0];
    logic [31:0] l_readA, l_readB;

	// Initialize state
	integer i;
	initial begin
	    //$display("Initializing Register File Model");
        for (i=0;i<32;i=i+1)
           tmpfile[i] = 0;
    end

	// checking state
	always@(negedge clk) begin
		if (initialized) begin
			if (l_readA != regReadDataA) begin
				$display("*** Error: Model read port A=0x%h but should be 0x%h at time %0t", 
                    regReadDataA, l_readA,  $time);
				$finish;
			end
			if (l_readB != regReadDataB) begin
				$display("*** Error: Model read port B=0x%h but should be 0x%h at time %0t", 
                    regReadDataB, l_readB,  $time);
				$finish;
			end
			if (^regReadDataB[0] === 1'bX) begin
				$display("**** Error: 'x' Values on B read port at time %0t", $time);
				$finish;
			end
			if (^regReadDataA[0] === 1'bX) begin
				$display("**** Error: 'x' Values on A read port at time %0t", $time);
				$finish;
			end
		end
	end

	always@(posedge clk) begin
        if (initialized) begin
            l_readA <= tmpfile[regAddrA];
            l_readB <= tmpfile[regAddrB];
            if (regWrite && regAddrWrite !=0) begin
                tmpfile[regAddrWrite] <= regWriteData;
                // if reading same register we are wrting, return new data
                if (regAddrA == regAddrWrite)
                    l_readA <= regWriteData;
                if (regAddrB == regAddrWrite)
                    l_readB <= regWriteData;
            end        
        end
    end

endmodule
