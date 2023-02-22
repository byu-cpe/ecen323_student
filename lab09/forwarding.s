######################################################################
#
# forwarding.s
#
# This program is used as a test case for the forwarding processor.
# This program uses a data segment at 0x2000. x31 is configured
# to point to this data segment.
#
# This program assumes the "Compact, text at 0" memory configuration
#
######################################################################

.eqv MAJOR_VERSION 1
.eqv MINOR_VERSION 6


.text

    ##############################################################
    # Version Information
    ##############################################################

    # First two instructions are to specify the version number so
    # we can see early in the simulation what version of the code
    # is running.
    addi x1, x0, MAJOR_VERSION
    addi x2, x0, MINOR_VERSION

    ##############################################################
    # Basic Forwarding Tests (standard forwarding situations)
    ##############################################################
    
    # R1 forwarded from WB, R2 forwarded from MEM (double forward)
    add x3, x1, x2 
    # R1 forwarded from MEM, R2 forwarded from WB (double forward)
    sub x4, x3, x2
    # R1 forwarded from MEM, R2 not forwarded
    and x5, x4, x1
    # R1 forwarded from WB, R2 not forwarded
    slt x6, x4, x2
    # R1 not forwarded, R2 forwarded from MEM
    or x7, x4, x6
    # R1 not forwarded, R2 forwarded from WB
    xor x8, x5, x6
    # R1 and R2 forwarded from MEM
    add x9, x8, x8
    # R1 and R2 forwarded from WB
    slt x10, x8, x8
    # Make sure register file can read and write to same register
    add x1, x1, x1
    # NOPs to flush out pipline before next test
    nop
    nop

    ##############################################################
    # Forwarding x0 tests 
    # (write to x0 and forward result: Don't forward non-zero result)
    ##############################################################

    # Attempt to write value to x0 (will not be loaded into reg file
    # but non-zero result will be in pipeline for forwarding)
    addi x0, x0, 1
    # x0 result forwarded from R1 in MEM
    add x3, x0, x1
    # x0 result forwarded from R1 in WB
    sub x4, x0, x1
    # Attempt to write new value in x0
    addi x0, x0, 2
    # x0 result forwarded from R2 in MEM
    xor x5, x4, x0
    # x0 result forwarded from R2 in WB
    and x6, x5, x0
    # NOPs to flush out pipline before next test
    nop
    nop
    
    ##############################################################
    # Forwarding with immediates 
    #  Immediate data should not forward. Bottom 5 bits of immediate
    #  field map to the 5 bits of rs2. 
    ##############################################################
    
    # Seed pipeline with instruction writing to x8
    addi x8, x0, 0xff
    # R1 forwarded from MEM, constant that may try to forward from MEM (imm 8 vs x8)
    addi x9, x8, 8
    # R1 forwarded from WB, constant may try to forward from WB (imm 8 vs x8)
    ori x10, x8, 8
     # R1 no forwarding, constant may try to forward from MEM (imm 10 vs x10)
    andi x11, x7, 10
     # R1 no forwarding, constant may try to forward from WB (imm 10 vs x10)
    xori x12, x6, 10
    # NOPs to flush out pipline before next test
    nop
    nop

    ##############################################################
    # Prepare the data base pointer for load/store tests
    ##############################################################
    
    # setup a pointer (x31)
    # Data segment is at 0x2000
    # Intitialize to 0x400 (largest immediate)
    addi x31, x0, 0x400		# Setup x31 with pointer to 0x2000 (start at 0x400)
    slli x31, x31, 3        # Shift x31 by 3 (multiply by 8) to get 0x2000
    # test forwarding of the base pointer (forward from MEM)
    lw x13, 0(x31)
    # test forwarding of the base pointer (forward from WB)
    lw x14, 4(x31)

    ##############################################################
    # Load Use hazard (insert bubble)
    ##############################################################
    
    # load use into r1
    lw x15, 32(x31)	
    or x16, x15, x4

    # load use into r2
    lw x17, 4(x31)	
    and x17, x1, x17

    # load use with instruction in between (should forward to r1)
    lw x18, 8(x31)
    add x19, x17, x16
    sub x20, x18, x19
    
    # load use with instruction in between (should forward to r2)
    lw x17, 8(x31)
    sub x18, x16, x15
    xor x19, x18, x17

    # load use with a 'load' base address as the use
    lw x20, 40(x31)			# Should load 0x2000 into x20
    lw x21, 0(x20)
    # NOPs to flush out pipline before next test
    nop
    nop

    ##############################################################
    # Load use hazard with stores
    ##############################################################

    # Load use hazard with the store value as the "use"
    lw x13, 0(x31)
    sw x13, 32(x31)

    # Load use hazard with the base address for the store is the "use"
    lw x13, 40(x31)         # Should load 0x2000 into x20
    sw x2, 8(x13)           # Should write to location 0x2008

    # Previous load-use store test
    lw x13, 0(x31)
    sw x13, 32(x31)
    lw x13, 32(x31)
    sub x13, x13, x12

    # Load use followed by a store use (student bug example)
    lw x13, 0(x31)
    and x13, x13, x12
    sw x13, 12(x31)
    # NOPs to flush out pipline before next test
    nop
    nop

    ##############################################################
    # Branch Hazards
    ##############################################################

 
    # seed x1
    addi x1, x0, 1
    # 1. Branch not taken without forwarding
    beq x0, x1, ERROR
    # add some instructions to avoid branch nesting at this point
    addi x19, x19, 1
    add x19, x19, x19
    sub x19, x19, x2
    # 2. Branch not taken with forwarding (MEM)
    xor x19, x18, x17
    beq x19, x18, ERROR
    # 3. Branch not taken with forwarding (WB)
    sub x18, x16, x15
    xor x19, x18, x17
    beq x16, x18, ERROR
    # Add some instructions to avoid back to back branches (don't use nops)
    sub x18, x16, x15
    xor x19, x18, x17
    sub x19, x19, x2

    # 4. Branch taken without forwarding
    beq  x15, x15, SKIP1
    # These instructions should not be executed
    addi x18, x18, -1
    xori x18, x18, 0x3ff
    andi x18, x18, 0x3ff
    
SKIP1:
    # 5. Branch taken with forwarding (MEM)
    addi x20, x0, 35		# SKIP1
    addi x21, x20, -3
    addi x21, x21, 3
    beq x21, x20, SKIP2
    # These instructions should not be executed
    addi x18, x18, -1
    xori x18, x18, 0x3ff
    andi x18, x18, 0x3ff
    
SKIP2:
    # 6. Branch taken with forwarding (WB)
    addi x20, x0, -1		# SKIP2
    addi x21, x20, 1
    addi x20, x21, 3
    beq x21, x0, SKIP3
    # These instructions should not be executed
    addi x18, x18, -1
    xori x18, x18, 0x3ff
    andi x18, x18, 0x3ff

SKIP3:
    # 7. Nested branches: Taken followed by would be taken
    beq x19, x19, SKIP4		# SKIP3
    # Shouldn't execute this (will take branch if we execute it)
    beq x0, x0, ERROR
    beq x18, x18, ERROR
    xori x18, x18, 0x3ff

SKIP4: 	
    # 8. Nested branches: Not Taken followed by Taken
    beq x0, x18, ERROR		# SKIP4
    beq x15, x15, SKIP5
    # These instructions should not be executed
    addi x18, x18, -1
    xori x18, x18, 0x3ff
    andi x18, x18, 0x3ff
    
SKIP5: 	
    # 9. Branch to next instruction (will flush the instructions we started)
    beq x14, x14, SKIP6		# SKIP5	
SKIP6:
    # 10. Test a branch taken followed by a load-use hazard
    beq x15, x15, SKIP7     # SKIP6
    # Shouldn't execute these if the load-use stall is not performed for the special case
    lw x16, 0(x31)
    add x17, x17, x16
    addi x17, x17, -1
    beq x0, x0, ERROR

SKIP7:
    # Now add up the first 10 data memory locations
    addi x18, x0, 0   		# SKIP7: x18 is the runnning total (initialize to zero)
    addi x19, x0, 0   		# loop index (initialize to zero)
    addi x20, x0, 9   		# terminal count (initiLize to 9)
    add x21, x0, x31  		# pointer that changes in loop (initialize to x31)
SIMPLE_LOOP:
    lw x22, 0(x21)			# SIMPLE_LOOP: Load value from memory
    add x18, x18, x22		# add it to our running total
    beq x19, x20, SKIP8		# see if my loop index is the same as the terminal count. If so, exit
    addi x21,x21,4			# otherwise increment loop counter and pointer and jump back
    addi x19,x19,1
    beq x0,x0, SIMPLE_LOOP

SKIP8:
    # load-use where the use is a branch not taken
    lw x22, 0(x31)          # SKIP8
    beq x0, x22, ERROR
    # load-use where the use is a branch taken
    lw x23, 0(x31)
    beq x23, x22, SKIP9
    # These instructions should not be executed
    addi x18, x18, -1
    xori x18, x18, 0x3ff
    andi x18, x18, 0x3ff

SKIP9:
    # Load use followed by branch not taken, branch taken
    lw x22, 0(x31)          # SKIP9
    beq x0, x22, ERROR      # Branch not taken
    beq x23, x22, SKIP10    # Branch taken
    # These instructions should not be executed
    addi x18, x18, -1
    xori x18, x18, 0x3ff
    andi x18, x18, 0x3ff

SKIP10:
    # Load use followed by branch not taken, branch not taken
    lw x22, 0(x31)          # SKIP9
    beq x0, x22, ERROR      # Branch not taken
    beq x23, x22, ERROR     # Branch not taken
    lw x24, 12(x31)         # Executed!

END:
    nop
    nop
    nop
    # Stop executing here: 
    ebreak
    
    
ERROR:
    mul x0, x0, x0
    beq x0, x0, ERROR
    nop
    nop
    nop
    
##################################################################################
# Global data segment (0x2000)
##################################################################################

.data
Data:
    .word 0x01234567	# 0x2000
    .word 0xfedcba98 	# 0x2004
    .word 0x89abcdef   	# 0x2008
    .word 0x00000003  	# 0x200c
    .word 0x00000004 	# 0x2010
    .word 0x00000005   	# 0x2014
    .word 0x00000006  	# 0x2018
    .word 0x00000007  	# 0x201c
    .word 0x00000008   	# 0x2020
    .word 0x00000009   	# 0x2024
    .word 0x00002000   	# 0x2028 (offset decimal 40)

