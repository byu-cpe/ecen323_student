# final.s
#
#   Test new instructions:
#    - branches
#    - lui
#    - Jumps
#    - Shifts
# 
#  This relies on the "compact, text at 0" memory configuration
#
# Version V1.1
# 
#


.text

	# LUI tests

	# Set base address for the data pointer 
	lui x1, 0x2        # 0x2 << 12 = 0x2000     	
	# Create larger negative number with LUI and addi
	#  (this will test forwarding with lui)
	# Same as: li x2, -10000
	lui x2, 0xfffff
	addi x2, x0, 0xfffff8f0

	# Branch tests (BEQ, BNE, BLT, BGE) 
	addi x6, x0, -1
	addi x7, x0, -8
	addi x8, x0, 1
	addi x9, x0, 81
	addi x10, x9, 0
	
BEQ_TEST:
	beq x8, x9, ERROR       # beq not taken 
	beq x9, x10, BNE_TEST   # beq taken
	beq x0, x0, ERROR
BNE_TEST:
	bne x9, x9, ERROR       # BNE_TEST: bne not taken
	bne x9, x8, BLT_TEST1   # bne taken
	beq x0, x0, ERROR
BLT_TEST1:
	blt x9, x6, ERROR       # BLT_TEST1: BLT not taken (81 !< -1)
	blt x6, x9, BLT_TEST2   # BLT taken (-1 < 81)
	beq x0, x0, ERROR
BLT_TEST2:
	blt x9, x8, ERROR       # BLT_TEST2: BLT not taken (81 !< 1)
	blt x8, x9, BGE_TEST1   # BLT taken (1 < 81)
	beq x0, x0, ERROR
BGE_TEST1:
	bge x6, x9, ERROR		# BGE_TEST1: BGE not taken (-1 !> 81)
	bge x9, x10 BGE_TEST2	# BGE taken (81 == 81)
	beq x0, x0, ERROR
BGE_TEST2:
	bge x7, x6, ERROR		# BGE_TEST2: BGE not taken (-8 !> -1)
	bge x6, x7, SHIFT_TESTS # BGE taken (-1 > -8)


	# shift tests
SHIFT_TESTS:
	# Prep data
	addi x2, x0, -100 # (0xffff_ff9c)
	addi x3, x0, 100  # 0x64

	# Immediate shifts
	slli x4, x2, 3    # 0xffff_ff9c << 3 = 0xffff_fce0
	slli x5, x3, 3    # 0x64 << 3 = 0x320
	srli x4, x2, 4    # 0xffff_ff9c >> 4 = 0x0fff_fff9
	srli x5, x3, 4
	srai x4, x2, 2
	srai x5, x3, 2	
	
	# Register shifts
	addi x4, x0, 0       # shift index
	addi x5, x0, 32		 # terminal count
	
SHIFT_LOOP:
	# Do all of the shifts
	sll x6, x2, x4
	sll x6, x3, x4
	srl x6, x2, x4
	srl x6, x3, x4
	sra x6, x2, x4
	sra x6, x3, x4	
	
	addi x4, x4, 1		# increment shift index
	bne x4, x5, SHIFT_LOOP

	# Jump Tests
	
	# perform a raw jump with no link (return is the same)
	jal x0, JUMP_TEST1
	# perform a raw jump *with* a link to x1 (return is jalr with no offset)
JUMP_TEST2:
	jal x31, JUMP_TEST3	# JUMP_TEST2
	# Perform a jump followed by a load-use to make sure the load-use stall is ignored.
	jal x0, JUMP_TEST4
	lw x2, 0(x1)
	addi x3, x2, 1
JUMP_TEST5:
	# Perform a jalr that requires forwarding to test forwarding out
	jal x31, JUMP_TEST6	# JUMP_TEST5
	# This instruction should be skipped because we added 4 to x1
	xor x3, x3, x0
	# This is the instruction we should return to
	addi x2, x0, -1
	# This should invert x3
	xor x3, x3, x2

	# Other tests
	
	# Set base address for the data pointer 
	lui x1, 0x2        # 0x2 << 12 = 0x2000     		
	# Test load with no offset               
	#  x2=0x01234567  Sum = 0x1235567                           01234567
	lw x2, 0(x1)
	# Test load with positive offset
	#  x3=0xfedcba98 Sum = FFF                                  fedcba98
	lw x3, 4(x1)
	# Test 'or'. 
	#  This is a load-use hazard                                00000000
	#  x4=ffffffff SUM=FFE                                      ffffffff
	or x4, x2, x3
	# Test 'and'
	#  x5=0 SUM=FFE                                             00000000
	and x5, x2, x3
	# Test 'xor' (forward with one instruction between)
	#  x6=0x01234567 ^ 0xffffffff = 0xfedcba98 SUM=FEDCCA96     fedcba98
	xor x6, x2, x4
	# test slt true
	#  (x2=0xfedcba98 < x4=0x0ffffffff) (x7=1) SUM= FEDCCA97    00000001
	slt x7, x6, x2
	# test slt false
	#  (x2=0x01234567 < x3=0xfedcba98) (x8=0) SUM=FEDCCA97      00000000
	slt x8, x2, x3
	# Subtract
	#  x7=1 - x4=01 = 2, x9=2. SUM = FEDCCA99                   00000002
	sub x9, x7, x4
	# add immediate with negative offset
	#    x9=2 + -4 = -2 x10=-2 (ffffffffe). SUM = FEDCCA97      fffffffe
	addi x10, x9, -4
	# Test 'xori'
	#  x10=fffffffe ^ 0xff = 0xfe (x11=0xffffff01). SUM =       ffffff01
	xori x11, x10, 0xff
	# ORI
	#  x9=2 | 0x370 (x11=0x372). SUM = FEDCCF93                 00000372
	ori x12, x9, 0x370
	# SLTI false
	#   x9=-2 < -3 (false, x13=0). SUM = FEDCCF93               00000000
	slti x13, x9, -3
	# SLTI true
	#   x11=3fe < 0x3ff (true, x14=1). SUM= FEDCCF94            00000001
	slti x14, x11, 0x3ff
	# load data at address 8
	#    x16=89abcdef SUM= FEDCCF9B                             89abcdef
	lw x16, 8(x1)
	# Store 4 at location 12                                    
	#     load-use hazard										00000000
	#															0000100c
	sw x16, 12(x1)
	# load it back to see if it is the same						89abcdef
	#  x17=4 SUM= FEDCCF9F
	lw x17, 12(x1)
	# Make sure they are the same (branch taken)				00000000
	#  load-use stall											00000000
	beq x17,x16, SAME_VALUE
	# bogus instructions that should not be executed
	#															00000000
	addi x2,x17,0x3f
	#															00000000
	ori x3,x5, 0x3f0
	#															00000000
	xor x3,x5,x11
	andi x4,x5,0x3ff
	sub x6,x1,x2

SAME_VALUE:
	# try a branch NOT taken (subtract result is fffff000)
	#															fffff000
	beq x0, x1, END
	# Add up all of the registers
	#															00000000
	addi x18, x0, 0  # clear register x18
	#															00001000
	add x18, x18, x1
	add x18, x18, x2
	add x18, x18, x3
	add x18, x18, x4
	add x18, x18, x5
	add x18, x18, x6
	add x18, x18, x7
	add x18, x18, x8
	add x18, x18, x9
	add x18, x18, x10
	add x18, x18, x11
	add x18, x18, x12
	add x18, x18, x13
	add x18, x18, x14
	add x18, x18, x15
	add x18, x18, x16
	add x18, x18, x17			
	
	# At this point, the sum of the registers in x18 should be: 
	
	# Now add up the first 10 data memory locations. Use Jumps instead.
	addi x23, x0, 0   # x23 will be the memory contents sum
	addi x19, x0, 0   # loop index
	addi x20, x0, 9   # terminal count
	add x21, x0, x1  # pointer that changes in loop

SIMPLE_LOOP:
	jal x31, ADD_PROC        # jump to the ADD_PROC to do the adds
	
	beq x19, x20, FINAL_SUM  # see if my loop index is the same as the terminal count. If so, exit
	addi x21,x21,4           # otherwise increment loop counter and pointer and jump back
	addi x19,x19,1
	jal x0, SIMPLE_LOOP
	
ADD_PROC:
	lw x22, 0(x21)           # Load value from memory
	add x23, x23, x22		 # add it to our running total
	jalr x0, x31, 0			 # Return to where we started (don't save return address)
	
FINAL_SUM:
	# add up the sum of the memory (x23) with the sum of the registers (x18)
	add x24, x23, x18

	# Drop through to an infinite loop
END:	# Jump to myself test
    addi a7, x0, 10   # Exit system call
    ecall
	jal x0, END
	# Should never get here

ERROR:
	beq x0, x0, ERROR
	# Target of first jump test
JUMP_TEST1:
	jal x0, JUMP_TEST2		# JUMP_TEST1 (negative PC offset)
JUMP_TEST3:
	# JALR test - link result register
	#  This should be a forwarding condition
	jalr x30, x31, 0			# JUMP_TEST3
JUMP_TEST4:					# JUMPT_TEST4
	jal x0, JUMP_TEST5
JUMP_TEST6:
	# Test forwarding with jalr. Add 4 to register
	addi x31, x31, 4			# JUMP_TEST6
	# Dummy instruction (space)
	addi x0, x0, 0
	jalr x0, x31, 0			

	NOP
	NOP
	NOP
	
.data

.word 0x01234567   # 0
.word 0xfedcba98   # 4
.word 0x89abcdef   # 8
.word 0x00000003   # 12
.word 0x00000004   # 16
.word 0x00000005   # 20
.word 0x00000006   # 24
.word 0x00000007   # 28
.word 0x00000008   # 32
.word 0x00000009   # 36


