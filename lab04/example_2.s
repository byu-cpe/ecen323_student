#########################################################################
#
# Filename: example_2.s
#
# Author: Mike Wirthlin
# Date: 1/22/2020
# 
# Description: Program to calculate the factorial for given 
# non-zero, non-negative integer input (output = input!) with system calls
# and subroutine
#
# Functions:
#  - fact_func: Performs factorial for input a0 (a0!) and returns result to a0
#
#########################################################################

.globl main

# Define constants for system calls
.eqv PRINT_INT 1            # System call number for printing an integer
.eqv PRINT_STR 4            # System call number for printing a string
.eqv EXIT_CODE 93           # System call number for the exit condition

# Global data segment
.data
input:                      # The location for the input factorial value
	.word 5                 # Allocates 4 bytes and sets the input to 5 (arbitrary)
	
output:                     # The location for the output calculated factorial
							# value given the input value data
	.word 0                 # Allocates 4 bytes and sets the output to 0 for initialization
	
result_str:                 # The location for the result string data
	.asciz "! = "           # allocates 1 byte per character plus null character (in data segment)


.text
main:                       # Label for start of program
	lw a0,input             # Loads the desired input value from memory to compute the factorial
	jal fact_func           # Jump and link (save return address) to factorial subroutine (function), 
							# argument (a0 (input)) return value (a0)
	la t0,output            # Load output address to t0
	sw a0,0(t0)             # Save the calculated factorial result to output memory location
	
exit:                       # The factorial has finished computing, perform system calls to print
							# result and waits on debug breakpoint
	lw a0,input             # Load Input value into a0 to be printed
	li a7,PRINT_INT         # System call code for print_int code 1
	ecall                   # Make system call (i.e., print int)

	la a0,result_str        # Put result_str address in a0 to be printed
	li a7,PRINT_STR         # System call code for print_str code 4
	ecall                   # Make system call (i.e., print string)
 
	lw a0,output            # Load output value into a0 to be printed
	li a7,PRINT_INT         # System call code for print_int code 1
	ecall                   # Make system call

	li a0, 0                # Exit (93) with code 0
	li a7,EXIT_CODE         # System call value
	ecall                   # Make system call
	ebreak                  # Finish with breakpoint
	
fact_func:                  # Performs factorial for input a0 (a0!) and returns result to a0
	li t0,1                 # Loads the value 1 into a t0 (a temporary constant)
	ble a0,t0,done_fact     # Check if input is 1 or less, if so then the factorial is already computed since
							# input = 1 results in output = 1, jump to the end of subroutine otherwise compute the factorial	
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

done_fact:
	ret                     # Use return address to get back to where subroutine was called from (main)


