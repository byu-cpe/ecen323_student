#########################################################################
# example_3.s
# 
# Author: Mike Wirthlin
# Date: 1/22/2020
#
# Description: Program to calculate the factorial for given 
# non-zero, non-negative integer input (output = input!) with system calls 
# and subroutine that utilizes the stack.
#
# Functions:
#  - fact_func: Performs factorial for input a0 (a0!) and returns result to a0
#  - mul_func:  Performs a multiple for input a0, a1 (a0 * a1) and returns result to a0
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
	.word 6 				# Allocates 4 bytes and sets the input to 6 (arbitrary)
	
output:						# The location for the output calculated factorial
							# value given the input value data
	.word 0					# Allocates 4 bytes and sets the output to 0 for initialization
							
							

result_str:					# The location for the result string data
	.asciz "! = "			# allocates 1 byte per character plus null character


.text
main:						# Label for start of program

	lw a0,input				# Loads the desired input value from memory to compute the factorial
	jal fact_func			# Jump and link (save return address) to factorial subroutine (function), argument (a0 (input)) return value (a0)
	la t0,output			# Load output address to t0
	sw a0,0(t0)				# Save the calculated factorial result to output memory location
	
exit:						# The factorial has finished computing, perform system calls to print
							# result and waits on debug breakpoint

	lw a0,input				# Load Input value into a0 to be printed
	li a7,PRINT_INT        	# System call code for print_int code 1
	ecall                 	# Make system call
		
	la a0,result_str     	# Put result_str address in a0 to be printed
	li a7,PRINT_STR       	# System call code for print_str code 4
	ecall                	# Make system call
 
	lw a0,output			# Load output value into a0 to be printed
	li a7,PRINT_INT      	# System call code for print_int code 1
	ecall                 	# Make system call
	
	li a0, 0				# Exit (93) with code 0 (NULL character to represent end of string)
	li a7,EXIT_CODE			# System call value
	ecall					# Make system call
	ebreak					# Finish with breakpoint

fact_func:					# Performs factorial for input a0 (a0!) and returns result to a0

	addi sp, sp, -16		# Make room to save 4 byte registers on the stack
	sw s0,  0(sp)			# The subroutine needs s0, save the caller s0 on stack. Used to operate on the input value
	sw s1,  4(sp)			# The subroutine needs s1 save the caller s1 on stack. Used to hold the count of a factorial loop
	sw s2,  8(sp)			# The subroutine needs s2, save the caller s2 on stack. Used to hold the next factorial operand
	sw ra, 12(sp)			# The ra needs to be stored to know where subroutine was called from in case jal is used again
	
	mv s0, a0				# Save the argument into s0
	
	li t0,1					# Loads the value 1 into a t0
	ble s0,t0,done_fact		# Check if input is 1 or less, if so then the factorial is already computed since
							# input = 1 results in output = 1, jump to the end of subroutine otherwise compute the factorial	

	addi s1,s0,-1			# Put input-1 into s1, use as number of times (count) to remain in factorial loop from input - 1 to 0
	li a0,1					# Load 1 in a0 (caller saved/ argument)
	li s2,1					# Load 1 in s2 (callee saved) # Load 1, use as the next factorial operand; an index i from 1 to input - 1

do_fact:					# Performs the factorial when n > 0,1. Multiplies (result * i) into a single product where i increments
							# per loop execution. Loop terminates when (count) <= 0

	blez s1,done_fact		# If s1 (count) is less than or equal to zero then jump to end otherwise continue to compute factorial
	addi s2,s2,1			# Increment s2 (i) by 1 to obtain next factorial operand
	
	mv a1,s2				# Move s2 (i) into a1 (argument) for the multiple subroutine
	jal mul_func			# Perform multiple to obtain result. Multiply subroutine, argument (a0 (result),a1 (i)) return value (a0)
		
	addi s1,s1,-1			# decrement s1 (count)
	j do_fact				# jump to top of loop to do next factorial until s1 (count) is 0

done_fact:					# The factorial is finished, load register values from previous caller and update stack pointer
	
	lw s0,  0(sp)			# Restore any callee saved regs used
	lw s1,  4(sp)			# Each register is 4 bytes
	lw s2,  8(sp)			#
	lw ra, 12(sp)			# Restore correct return address
	addi sp, sp, 16			# Update stack pointer
	ret						# Jump to return address
		

mul_func: 					# Performs a multiple for input a0, a1 (a0 * a1) and returns result to a0
	addi sp, sp, -12		# Make room to save values on the stack
	sw s0, 0(sp)			# This function uses 2 callee save regs
	sw s1, 4(sp)			# This function is responsible for them
	sw ra, 8(sp)			# Save the return address
	
	mv s0, a0				# Save the argument a0 in callee save regs as operand 1
	mv s1, a1				# Save the argument a0 in callee save regs as operand 2
	
	mul a0,s0,s1			# Perform multiply and output to a0
	
	lw s0, 0(sp)			# Restore any callee saved regs used
	lw s1, 4(sp)			# Each register is 4 bytes
	lw ra, 8(sp)			# Restore return address
	addi sp, sp, 12			# Update stack pointer
	ret						# Jump to return address
