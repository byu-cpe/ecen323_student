# pipeline_nop.s
#
# This assembly language program must be written with the assumption that there is
# is no hazard detection or hardware stalling. All hazards must be resolved by the
# code (i.e., add NOP instructions as needed).
#
# This code assumes the data segment is at 0x2000 and text at 0x0000
# (CompactTextAtZero)
#
# Version V1.1
#  (Note: reflect the version number in the first two instructions)
#

.eqv MAJOR_VERSION 1
.eqv MINOR_VERSION 1

.text

	#####################
	# Version Instructions
	#####################

	# First two instructions are to specify the version number so
	# we can see early in the simulation what version of the code
	# is running
	addi x1, x0, MAJOR_VERSION
	addi x2, x0, MINOR_VERSION
	
	#####################
	# ALU Instructions
	#####################

	# This set of instructions will test various ALU instructions
	# and their modes. Note that at least two instructions should
	# be placed between dependent instructions.
	#
	# Possible new modes:
	# - ori with negative constant
	# - andi with negative constant
	# - slti with negative constant
	# - xori with negative constant
	
	addi x1, x0, 1024 		# Add immediate with pos v (x1=0x400)
	addi x2, x0, -1			# Add immediate with neg value: x2 = 0xffffffff (-1)
	ori x3, x0, 0xff		# Basic positive ori : x3 = 0xff
	add x1, x1, x1			# regiser operation: Double x1 (x1=0x800)
	andi x5, x2, 0xff		# and immediate pos value : x5 = 0xffffffff & 0xff = 0xff
	sub x4, x3, x2			# Subtract : x4 = 0xff - 0xffffffff (255-(-1)) = 256 or 0x100
	add x1, x1, x1			# Add operation: Double x1 : x1 = 0x1000
	slti x6, x3, 0xfe 		# slti : x3 < 0xfe = false, x6=0
	slti x7, x3, 0x101		# slti : x3 < 0x101 = true, x7=1
	addi x0, x0, 1			# make sure you can't write to register 0. x0 = 0
	xori x8, x2, 0x5a		# xor immediate. x8 = 0xffffffff ^ 0x5a = 0xffffffa5
	
	#####################
	# Branch Instructions
	#####################
	
	beq x0, x1, SKIP		# Branch not taken  (x0 /= x1)
	# Need 3 NOPs after branches 
	nop
	nop
	nop

	add x15, x3, x0			# should execute this instruction  (x15 = x3 or 0xff)
	nop
	nop
	
	beq x15, x3, SKIP		# This branch should be taken (x15 = x3 = 0xff)
	NOP
	NOP
	NOP
	add x15, x14, x13  		# should not be executed
	sub x14, x12, x10  		# should not be executed
	and x13, x11, x12  		# should not be executed

SKIP:
		
	#####################
	# Setup .data base pointer
	#####################

	# setup a pointer (x19) to the start of data (this is a pain 
	# without the auipc instruction and without stalling). 
	# Data segment is at 0x2000
	# Intitialize to 0x400 (largest immediate)
	addi x19, x0, 0x400		# Setup x19 with pointer to 0x2000 (start at 0x400)
	NOP
	NOP
	add x19, x19, x19		# Add to self (x19 = 0x800)
	NOP
	NOP
	add x19, x19, x19		# Add to self (x19 = 0x1000)
	NOP
	NOP
	add x19, x19, x19		# Add to self (x19 = 0x2000). Now points to .data
	NOP
	NOP
	# Setup a pointer to 0x2040 (0x2000 + 0x40 (64)) to test negative offsets
	addi x20, x19, 64		# Create x20 as a pointer to 0x2040
	
	#####################
	# Load/Store Instructions
	#  (test positive, negative, and zero offsets)
	#####################

	# Do some loads with positive and negative offsets
	lw x9, 0(x19)			# Load word at 0x2000+0 (0x11111111)
	lw x10, 4(x19)			# Load word at 0x2000+4 (0x22222222)
	lw x11, -16(x20)		# Load word at 0x2040-16 (0x88888888)
	lw x12, -20(x20)		# Load word at 0x2040-20 (0xffffffff)
	
	sub x31, x10, x9		# x31 = 22222222 - 11111111 = 11111111 (x10 and x9 should be ready)	
	lw x13, 16(x19)			# Load word (0x55555555)
	lw x14, 20(x19)			# Load word (0x66666666)
	beq x31, x9, SKIP2		# x31 (11111111) == x9 (11111111). Should be taken
	
	# instructions should not be executed (skipped over)
	# Invert x11
	xor x11, x0, x11		# Should not be executed
	# Invert x12
	xor x12, x0, x12		# Should not be executed
	NOP
	NOP
	
SKIP2:
	sub x31, x14, x13		# SKIP2: x31=0x66666666 - 0x55555555 = 0x11111111
	lw x15, 24(x19)			# Load word at 0x2000+24 (0x77777777)
	lw x16, 28(x19)			# Load word at 0x2000+28 (0xffffffff)

	# 
	beq x31, x9, STORE		# 0x11111111==0x11111111 (should be taken)
	NOP
	NOP
	NOP
	
	beq x0, x0, ERROR		# Shouldn't get here. Will branch to error holding point

	# test stores
	# (need both positive and negative stores)
	
STORE:	
	# 0xffffffff to 0x0
	# Store followed by a load
	#  sw: IF  ID  EX  MEM(write to reg) WB
	#  lw:     IF  ID  EX                MEM(read what was written)  WB

	# sw with zero offset
	sw x16, 0(x19)			# STORE: store x16 (0xffffffff) to address 0x2000
	# sw with positive offset
	# Read what we wrote
	lw x31, 0(x19)			# Read what was written to adress 0x2000 (should be 0xffffffff)
	# sw with positive offset
	sw x10, 32(x19)			# store x10 (0x22222222) to address 0x2020
	# read what we wrote
	lw x30, 32(x19)	
	beq x16, x31, STORE1	# see if we read what we wrote (x16=x31 - should branch)
	NOP
	NOP
	NOP
	beq x0, x0, ERROR		# Should not get here
	
STORE1:
	beq x10, x30, STORE2	# STORE1: see if we read what we wrote (x10=x31 - should branch)
	NOP
	NOP
	NOP
	
STORE2:
	# Store with negative offset
	sw x11, -20(x20)		# Store x11 (0x88888888) to 0x2040 - 20 = 0x202C
	lw x31, -20(x20)		# Read what we wrote
	NOP
	NOP
	beq x11, x31, END
	NOP
	NOP
	NOP
	beq x0, x0, ERROR		#Shouldn't get here. If so, branch to ERROR
	NOP
	NOP
	NOP
	
END:	
	ebreak					# END: ebreak: simluator will halt when it gets here
	NOP
	NOP
	NOP
	NOP

ERROR:						
	beq x0, x0 ERROR		# ERROR: Branch back to self
	NOP
	NOP
	NOP
	NOP

# .data is at 0x2000
# Only reserving 64 bytes (16 words)
.data
Data:
	.word 0x11111111		# 0x2000
	.word 0x22222222		# 0x2004
	.word 0x33333333		# 0x2008
	.word 0x44444444		# 0x200C
	.word 0x55555555		# 0x2010
	.word 0x66666666		# 0x2014
	.word 0x77777777		# 0x2018
	.word 0xffffffff		# 0x201C
	.word 0x88888888		# 0x2020
	.word 0x99999999		# 0x2024
	.word 0xaaaaaaaa		# 0x2028
	.word 0xbbbbbbbb		# 0x202C
	.word 0xcccccccc		# 0x2030
	.word 0xdddddddd		# 0x2034
	.word 0xeeeeeeee		# 0x2038
	.word 0xa5a55a5a		# 0x203C