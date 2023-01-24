##########################################
# fact_rec.s
# 
# Factorial demonstration using recursion
#
##########################################


.globl  main
.data
input:                          # The location for the input data
    .word 6                     # allocates 4 byte set to 4
    
output:                         # The location for the output data
    .word 0                     # allocates 4 byte set to 4
    
result_str:                     # The location for the result string data
    .asciz "! = "               # allocates 1 byte per chacter plus null character

.text
main:                           # Label for start of program
    lw a0,input                 # Load input Value
    jal fact_func
    la t0,output                # Load output address to t0
    sw a0,0(t0)                 # Save output value to output memory location
    
exit:
    lw a0,input                 # Load Input value into a0 
    li a7,1                     # System call code for print_int code 1
    ecall                       # Make system call
        

    la a0,result_str            # Put result_str address in a0
    li a7,4                     # System call code for print_str code 4
    ecall                       # Make system call
 
    lw a0,output                # Load output value into a0
    li a7,1                     # System call code for print_int code 1
    ecall                       # Make system call

    
    li a0, 0                    # Exit (93) with code 0
    li a7, 93                   # System call value
    ecall                       # Make system call
    ebreak                      # Finish with breakpoint

fact_func:

    addi sp, sp, -8             # Make room to save values on the stack
    sw s0, 0(sp)                # This function uses 1 callee save regs
    sw ra, 4(sp)                # The return address needs to be saved 

    mv s0, a0                   # Save the argument into s0

    bgtz a0,$L2                 # Branch if n > 0
    li a0,1                     # Return 1
    j $L1                       # Jump to code to return

$L2:
    addi a0,a0,-1               # Compute n - 1
    jal fact_func               # Call factorial function
    mul a0,a0,s0                # Compute fact(n-1) * n
       
$L1:
    
    lw s0, 0(sp)                # Restore any callee saved regs used
    lw ra, 4(sp)                # Restore return address
    addi sp, sp, 8              # Update stack pointer

    ret                         # Jump to return address
