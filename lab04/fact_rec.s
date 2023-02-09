#########################################################################
#
# Filename: fact_rec.s
# 
# Author: Mike Wirthlin
# Date: 1/22/2020
#
# Description: Program to calculate the factorial for given 
# non-zero, non-negative integer input (output = input!) with system calls 
# and subroutine that utilizes the stack through recursion
#
# Functions:
#  - fact_func: Performs factorial for input a0 (a0!) and returns result to a0
#
#########################################################################


.globl  main

# Constant defines for system calls
.eqv PRINT_INT 1
.eqv PRINT_STR 4
.eqv EXIT_CODE 93


# Global data segment
.data
input:                          # The location for the input factorial value
	.word 6                     # Allocates 4 bytes and sets the input to 6 (arbitrary)
	
output:                         # The location for the output calculated factorial
								# value given the input value data
	.word 0                     # Allocates 4 bytes and sets the output to 0 for initialization
	
result_str:                     # The location for the result string data
	.asciz "! = "               # allocates 1 byte per character plus null character

.text
main:                           # Label for start of program
	lw a0,input                 # Loads the desired input value from memory to compute the factorial
	jal fact_func               # Jump and link (save return address) to factorial subroutine (function), argument (a0 (input)) return value 
	la t0,output                # Load output address to t0
	sw a0,0(t0)                 # Save the calculated factorial result to output memory location
	
exit:                           # The factorial has finished computing, perform system calls to print
								# result and waits on debug breakpoint
	lw a0,input                 # Load Input value into a0 to be printed
	li a7,PRINT_INT             # System call code for print_int code 1
	ecall                       # Make system call
		

	la a0,result_str            # Put result_str address in a0 to be printed
	li a7,PRINT_STR             # System call code for print_str code 4
	ecall                       # Make system call
 
	lw a0,output                # Load output value into a0 to be printed
	li a7,PRINT_INT             # System call code for print_int code 1
	ecall                       # Make system call

	
	li a0,0                     # Exit (93) with code 0
	li a7,EXIT_CODE             # System call value
	ecall                       # Make system call
	ebreak                      # Finish with breakpoint

fact_func:                      # Performs factorial for input a0 (a0!) and returns result to a0

	addi sp, sp, -8             # Make room to save values on the stack
	sw s0, 0(sp)                # Save the caller s0 on stack. Used as the subroutine factorial operand
	sw ra, 4(sp)                # The return address needs to be saved to know where subroutine was called from 

	mv s0, a0                   # Save the argument into s0 (Used to compute the next factorial operand)

	bgtz a0,$L2                 # Branch if input > 0 there are additional factorial operands that still needs to be stored
	li a0,1                     # Return 1, input must be 0 so set the operand to 1 since input = 0, result = 1
	j $L1                       # Jump to code to return (end of recursion)

$L2:
	addi a0,a0,-1               # Compute n - 1
	jal fact_func               # Call factorial function to store next factorial operand, argument (a0 (input)) return value (a0)
	mul a0,a0,s0                # All factorial operands have been stored, multiple current stored operand and
								# return operand to Compute fact(input-1) * input 
	   
$L1:    
	lw s0, 0(sp)                # Restore any callee saved regs used. Load previous callee factorial operand
	lw ra, 4(sp)                # Restore return address
	addi sp, sp, 8              # Update stack pointer

	ret                         # Jump to return address
