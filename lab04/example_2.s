#######################
# example_2.s
# 
# Date: 1/22/2020
#
# Factorial demonstration of system calls
#
#######################

.globl main

# Constant Defines
.eqv PRINT_INT 1
.eqv PRINT_STR 4
.eqv EXIT_CODE 93

.data
input:						# The location for the input data
	.word 5 				# allocates 4 byte set to 5
	
output:						# The location for the output data
	.word 0					# allocates 4 byte set to 0
	
result_str:					# The location for the result string data
	.asciz "! = "			# allocates 1 byte per chacter plus null character (in data segment)


.text
main:						# Label for start of program
	lw a0,input				# Load input Value
	jal fact_func			# Jump and link (save return address) to factorial function
	la t0,output			# Load output address to t0
	sw a0,0(t0)				# Save output value to output memory location
	
exit:
	lw a0,input				# Load Input value into a0 
	li a7,PRINT_INT			# System call code for print_int code 1
	ecall					# Make system call		

	la a0,result_str     	# Put result_str address in a0
	li a7,print_str			# System call code for print_str code 4
	ecall					# Make system call
 
	lw a0,output			# Load output value into a0
	li a7,PRINT_INT			# System call code for print_int code 1
	ecall					# Make system call

	li a0, 0				# Exit (93) with code 0
	li a7,EXIT_CODE			# System call value
	ecall					# Make system call
	ebreak					# Finish with breakpoint
	
fact_func:	
	li t0,1					# Loads the value 1 into a t0
	ble a0,t0,done_fact		# If Input is 1 or less, then skip to end	
	addi t0,a0,-1			# Put input-1 into t0
	li a0,1					# Load 1
	li t2,1					# Load 1

do_fact:
	blez t0,done_fact		# If t0 is less than or equal to zero then jump to end
	addi t2,t2,1			# Increment t2 by 1
	mul a0,a0,t2			# Mul t2 by a0 to get next factorial
	addi t0,t0,-1			# decrement t0 
	j do_fact				# jump to top of loop to do next factorial until t0 is 0

done_fact:
	ret						# Use return address to get back to main
