##########################################
# 
# fib_template.asm
#
# Name:
#
# Template for completing Fibinnoci sequence in lab 4
#
##########################################

.globl  main

.data
fib_input:
    .word 10
    
result_str:                     # Output String
    .string "\nFibinnoci Number is "

netid_str:
    # Change the string below to include your net id
    .string "\nNet ID=<your_netid>"

.text

# Main function that calls your fibinnoci function
main:

    # Load n into a0 as the argument
    lw a0, fib_input
    
    # Call the fibinnoci function
    jal fibinnoci
    
    # Save the result into s2
    mv s2, a0 

    # Print the Result string
    la a0,result_str            # Put string pointer in a0
    li a7,4                     # System call code for print_str
    ecall                       # Make system call

    # Print the number        
     mv a0, s2
    li a7,1                     # System call code for print_int
    ecall                       # Make system call

    # Print the netid string
    la a0, netid_str            # Put string pointer in a0
    li a7, 4                    # System call code for print_str
    ecall                       # Make system call

    # Exit (93) with code 0
    li a0, 0
    li a7, 93
    ecall
    ebreak

fibinnoci:

    # This is where you should create your Fibinnoci function.
    # The input argument for your Fibinnoci arrives in a0. You should 
    # put your result in a0.
    #
    # You should properly manage the stack to save registers that
    # you use.

    ret
