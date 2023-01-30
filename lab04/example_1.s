#########################################################################
# Filename: example_1.s
# 
# Author: Mike Wirthlin
# Date: 1/22/2020
#
# Description: Program to calculate the factorial for given 
# non-zero, non-negative integer input (output = input!)
#
#########################################################################

.globl main
.data
input:  				# The location for the input factorial value
	.word 4 			# Allocates 4 bytes and sets the input to 4 (arbitrary)
	
output: 				# The location for the output calculated factorial 
						# value given the input value data
	.word 0		 		# Allocates 4 bytes and sets the output to 0 for initialization

.text
main:					# Label for start of program
	
	lw a0,input 		# Loads the desired input value from memory to compute the factorial
	
	li t0,1				# Loads the value 1 into a t0

	ble a0,t0,done_fact	# Check if input is 1 or less, if so then the factorial is already computed since
						# input = 1 results in output = 1, jump to the end of program otherwise compute the factorial

	addi t0,a0,-1		# Put input-1 into t0, use as number of times (count) to remain in factorial loop from input - 1 to 0
	li a0,1				# Load 1, since all factorial results contain 1 in the factorial product, use to hold the factorial result
	li t2,1				# Load 1, use as the next factorial operand; an index i from 1 to input - 1  


do_fact: # Performs the factorial when n > 0,1. Multiplies (result * i) into a single product where i increments
		 # per loop execution. Loop terminates when (count) <= 0 
	blez t0,done_fact	# If t0 (count) is less than or equal to zero then jump to end otherwise continue to compute factorial
	addi t2,t2,1		# Increment t2 (i) by 1 to obtain next factorial operand
	mul a0,a0,t2		# Mul t2 (i) by a0 (result) to get next factorial
	addi t0,t0,-1		# decrement t0 (count)
	j do_fact			# jump to top of loop to do next factorial until t0 (count) is 0
	
done_fact:
	la t0,output		# Load the address of the output to t0
	sw a0,0(t0)			# Save the calculated factorial result to output memory location
	
exit_loop: # The factorial has finished computing, remain in endless loop
	j exit_loop			# Loop Exit