#######################
# example_3.s
# 
# Date: 1/22/2020
#
# Factorial demonstration using the stack
#
#######################

.globl main

# Defines
.eqv PRINT_INT 1
.eqv PRINT_STR 4
.eqv EXIT_CODE 93

# Global data segment
.data
input:						# The location for the input data
	.word 6 				# allocates 4 byte set to 6
	
output:						# The location for the output data
	.word 0					# allocates 4 byte set to 0
	
result_str:					# The location for the result string data
	.asciz "! = "			# allocates 1 byte per chacter plus null character


.text
main:						# Label for start of program
	lw a0,input				# Load input Value
	jal fact_func			# Jump and link (save return address) to factorial function
	la t0,output			# Load output address to t0
	sw a0,0(t0)				# Save output value to output memory location
	
exit:
	lw a0,input				# Load Input value into a0 
	li a7,PRINT_INT        	# System call code for print_int code 1
	ecall                 	# Make system call
		

	la a0,result_str     	# Put result_str address in a0
	li a7,PRINT_STR       	# System call code for print_str code 4
	ecall                	# Make system call
 
	lw a0,output			# Load output value into a0
	li a7,PRINT_INT      	# System call code for print_int code 1
	ecall                 	# Make system call

	
	li a0, 0				# Exit (93) with code 0
	li a7,EXIT_CODE			# System call value
	ecall					# Make system call
	ebreak					# Finish with breakpoint

	
	
fact_func:
	addi sp, sp, -16		# Make room to save values on the stack
	sw s0,  0(sp)			# This function uses 3 callee save regs
	sw s1,  4(sp)			# This function is responsible for them
	sw s2,  8(sp)			# Each register is 4 bytes
	sw ra, 12(sp)			# The ra needs to be saved in case jal is used again
	
	mv s0, a0				# Save the argument into s0
	
	li t0,1					# Loads the value 1 into a t0
	ble s0,t0,done_fact		# If Input is 1 or less, then skip to end
	addi s1,s0,-1			# Put input-1 into s1
	li a0,1					# Load 1 in a0 (caller saved/ argument)
	li s2,1					# Load 1 in s2 (callee saved)
do_fact:
	blez s1,done_fact		# If s1 is less than or equal to zero then jump to end
	addi s2,s2,1			# Increment s2 by 1	
	
	mv   a1,s2				# Move s2 into a1 (argument)
	jal mul_func		# Multiply subroutine, argument (a0,a1) return value (a0)
		
	addi s1,s1,-1		# decrement s1 counter
	j do_fact		# jump to top of loop to do next factorial until s1 is 0
done_fact:
	
	lw s0,  0(sp)		# Restore any callee saved regs used
	lw s1,  4(sp)		# Each register is 4 bytes
	lw s2,  8(sp)		#
	lw ra, 12(sp)		# Retore correct return address
	addi sp, sp, 16		# Update stack pointer
	ret			# Jump to return address
	
	
mul_func:
	addi sp, sp, -12	# Make room to save values on the stack
	sw s0, 0(sp)		# This function uses 2 callee save regs
	sw s1, 4(sp)		# This function is responsible for them
	sw ra, 8(sp)		# Save the return address
	
	mv s0, a0		# Save the arguments in callee save regs
	mv s1, a1		# 
	
	mul a0,s0,s1		# Multiply argument and output to a0
	
	lw s0, 0(sp)		# Restore any callee saved regs used
	lw s1, 4(sp)		# Each register is 4 bytes
	lw ra, 8(sp)		# Restore return address
	addi sp, sp, 12		# Update stack pointer
	ret			# Jump to return address
