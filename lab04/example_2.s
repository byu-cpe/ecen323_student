#########################################################################
# example_2.s
# 
# Author: Mike Wirthlin
# Date: 1/22/2020
#
# Description: Program to calculate the factorial for given 
# non-zero, non-negative integer input (output = input!) with subroutine
# and system calls
#
# Functions:
#  - fact_func: Performs factorial for input a0 (a0!) and returns result to a0
#
#########################################################################

.globl main

# Constant defines for system calls
.eqv PRINT_INT 1
.eqv PRINT_STR 4
.eqv EXIT_CODE 93

# Global data segment
.data
input:						# The location for the input factorial value
	.word 5 				# Allocates 4 bytes and sets the input to 5 (arbitrary)
	
output:						# The location for the output calculated factorial
							# value given the input value data
	.word 0					# Allocates 4 bytes and sets the output to 0 for initialization
	
result_str:					# The location for the result string data
	.asciz "! = "			# allocates 1 byte per character plus null character (in data segment)


.text
main:						# Label for start of program

	lw a0,input				# Loads the desired input value from memory to compute the factorial

	jal fact_func			# Jump and link (save return address) to factorial subroutine (function)
	la t0,output			# Load output address to t0
	sw a0,0(t0)				# Save the calculated factorial result to output memory location
	
exit:						# The factorial has finished computing, perform system calls to print
							# result and waits on debug breakpoint

	lw a0,input				# Load Input value into a0 to be printed
	li a7,PRINT_INT			# System call code for print_int code 1
	ecall					# Make system call		

	la a0,result_str     	# Put result_str address in a0 to be printed
	li a7,PRINT_STR			# System call code for print_str code 4
	ecall					# Make system call
 
	lw a0,output			# Load output value into a0 to be printed
	li a7,PRINT_INT			# System call code for print_int code 1
	ecall					# Make system call

	li a0, 0				# Exit (93) with code 0 (NULL character to represent end of string)
	li a7,EXIT_CODE			# System call value
	ecall					# Make system call
	ebreak					# Finish with breakpoint

fact_func: 					# Performs factorial for input a0 (a0!) and returns result to a0

	li t0,1					# Loads the value 1 into a t0
	ble a0,t0,done_fact		# Check if input is 1 or less, if so then the factorial is already computed since
							# input = 1 results in output = 1, jump to the end of subroutine otherwise compute the factorial	
	
	addi t0,a0,-1			# Put input-1 into t0, use as number of times (count) to remain in factorial loop from input - 1 to 0
	li a0,1					# Load 1, since all factorial results contain 1 in the factorial product, use to hold the factorial result
	li t2,1					# Load 1, use as the next factorial operand; an index i from 1 to input - 1

do_fact:					# Performs the factorial when n > 0,1. Multiplies (result * i) into a single product where i increments
							# per loop execution. Loop terminates when (count) <= 0

	blez t0,done_fact		# If t0 (count) is less than or equal to zero then jump to end otherwise continue to compute factorial
	addi t2,t2,1			# Increment t2 (i) by 1 to obtain next factorial operand
	mul a0,a0,t2			# Mul t2 (i) by a0 (result) to get next factorial
	addi t0,t0,-1			# decrement t0 (count) 
	j do_fact				# jump to top of loop to do next factorial until t0 (count) is 0

done_fact:
	ret						# Use return address to get back to where subroutine was called from (main)
