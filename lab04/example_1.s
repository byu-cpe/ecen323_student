#######################
# example_1.s
# 
# Date: 1/22/2020
#
# Simple Factorial Program
#
#######################

.globl main
.data
input:  				# The location for the input data
	.word 4 			# allocates 4 byte set to 4
	
output: 				# The location for the output data
	.word 0 			# allocates 4 byte set to 0

.text
main:					# Label for start of program
	
	lw a0,input 		# Loads the input value from memory
	
	li t0,1				# Loads the value 1 into a t0
	ble a0,t0,done_fact	# If Input is 1 or less, then skip to end	
	addi t0,a0,-1		# Put input-1 into t0
	li a0,1				# Load 1
	li t2,1				# Load 1
do_fact:
	blez t0,done_fact	# If t0 is less than or equal to zero then jump to end
	addi t2,t2,1		# Increment t2 by 1
	mul a0,a0,t2		# Mul t2 by a0 to get next factorial
	addi t0,t0,-1		# decrement t0 
	j do_fact			# jump to top of loop to do next factorial until t0 is 0
	
done_fact:
	la t0,output		# Load output address to t0
	sw a0,0(t0)			# Save output value to output memory location
	
exit_loop:
	j exit_loop			# Loop Exit