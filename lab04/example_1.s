#########################################################################
#
# Filename: example_1.s
#
# Author: Mike Wirthlin
# Date: 1/22/2020
# 
# Description: Program to calculate the factorial for given non-zero, 
# non-negative integer input (output = input!) without system calls
#
#########################################################################

.globl main

# Global data segment
.data

input:                      # The location for the input factorial value
	.word 4                 # Allocates 4 bytes and sets the input to 4 (arbitrary)
	
output:                     # The location for the output calculated factorial 
							# value given the input value data
	.word 0                 # Allocates 4 bytes and sets the output to 0 for initialization

.text
main:                       # Label for start of program
	
	lw a0,input             # Loads the desired input value from memory to compute the factorial
	
	li t0,1                 # Loads the value 1 into a t0 (a temporary constant)
	ble a0,t0,done_fact     # Check if input is 1 or less, if so then the factorial is already computed since
							# input = 1 results in output = 1, jump to the end of program otherwise compute the factorial	
	addi t0,a0,-1           # Load the value input-1 into t0 (loop counter variable)
	li a0,1                 # Load 1 as initial output value a0 (result) since all factorials contain 1 in the factorial product
	li t2,1                 # Load 1 (t2 is number to multiply by, the next factorial operand (fo) to multiple the current result)

do_fact:                    # Performs the factorial when n > 0,1. Multiplies (result * fo) into a single product where
							# fo increments per loop execution. Loop terminates when (loop counter) <= 0
	blez t0,done_fact       # If t0 (loop counter) is less than or equal to zero then jump to end otherwise continue
	addi t2,t2,1            # Increment t2 (fo) by 1 to obtain next factorial operand
	mul a0,a0,t2            # Multiply t2 (fo) by a0 (result) to get next factorial
	addi t0,t0,-1           # decrement t0 (loop counter)
	j do_fact               # jump to top of loop to do next factorial until t0 (loop counter) is 0
	
done_fact:                  # The factorial is finished, load output address and store result at output address
	la t0,output            # Load output address to t0
	sw a0,0(t0)             # Save the calculated factorial result to output memory location
	
exit_loop:                  # The factorial has finished computing, remain in endless loop
	j exit_loop             # Loop Exit

