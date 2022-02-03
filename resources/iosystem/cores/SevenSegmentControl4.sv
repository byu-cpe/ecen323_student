//////////////////////////////////////////////////////////////////////////////////
//
//  Filename: SevenSegmentControl4.v
//
//  Author: Mike Wirthlin
//  
//  Description:
//
//     
//////////////////////////////////////////////////////////////////////////////////

module SevenSegmentControl4(clk, dataIn, digitDisplay, digitPoint, anode, segment, dp);

	parameter integer COUNT_BITS = 17;
	
	input clk;
	input [15:0] dataIn;
	input [3:0] digitDisplay;
	input [3:0] digitPoint;	
	output [6:0] segment;
	output [3:0] anode;
    output dp;

	reg [COUNT_BITS-1:0] count_val=0;
	wire [1:0] anode_select;
	wire [3:0] cur_anode;

	wire [3:0] cur_nibble;
	
	// Create counter
    always@(posedge clk)
        count_val <= count_val + 1;

	// Signal to indicate which anode we are driving
	assign anode_select = count_val[COUNT_BITS-1:COUNT_BITS-2];

	// current andoe
	assign cur_anode = 
						(anode_select == 2'b00) ? 4'b1110 :
						(anode_select == 2'b01) ? 4'b1101 :
						(anode_select == 2'b10) ? 4'b1011 :                        
						4'b0111;
						
	// Mask anode values that are not enabled with digit display
	//  (if a bit of digitDisplay is '0' (off), then it will be 
	//   inverted and "ored" with the annode making it '1' (no drive)
	assign anode = cur_anode | (~digitDisplay);
    
    // Determine the current nibble to display
	assign cur_nibble = 
						(anode_select == 2'b00) ? dataIn[3:0] :
						(anode_select == 2'b01) ? dataIn[7:4]  :
						(anode_select == 2'b10) ? dataIn[11:8]  :
						dataIn[15:12] ;
	
	// Digit point (drive segmetn with inverted version of input digit point)
	assign dp = 
						(anode_select == 2'b00) ? ~digitPoint[0] :
						(anode_select == 2'b01) ? ~digitPoint[1]  :
						(anode_select == 2'b10) ? ~digitPoint[2]  :
						~digitPoint[3] ;

    assign segment[6:0] =
        (cur_nibble == 0) ? 7'b1000000 :
        (cur_nibble == 1) ? 7'b1111001 :
        (cur_nibble == 2) ? 7'b0100100 :
        (cur_nibble == 3) ? 7'b0110000 :
        (cur_nibble == 4) ? 7'b0011001 :
        (cur_nibble == 5) ? 7'b0010010 :
        (cur_nibble == 6) ? 7'b0000010 :
        (cur_nibble == 7) ? 7'b1111000 :
        (cur_nibble == 8) ? 7'b0000000 :
        (cur_nibble == 9) ? 7'b0010000 :
        (cur_nibble == 10) ? 7'b0001000 :
        (cur_nibble == 11) ? 7'b0000011 :
        (cur_nibble == 12) ? 7'b1000110 :
        (cur_nibble == 13) ? 7'b0100001 :
        (cur_nibble == 14) ? 7'b0000110 :
        7'b0001110;

						
endmodule