################################################################################
#
# This file contains a set of routines that might be interesting for use in
# your projects.
#
################################################################################




################################################################################
# Procedure that will clear the screen by writing a given character to all
# locations on the screen. The "Default" mode of character writing will be
# used and the caller should have already set the default colors.
# 
# a0: character to write 
# return value: None
#
# This procedure is not recursive, does not call any other procedures, and
# does not use any saved registers. As such, no stack is created.
#
################################################################################
FILL_VGA_CHARACTER:

    # setup stack frame and save return address
    addi sp, sp, -4	            # Make room to save values on the stack
    sw ra, 0(sp)		        # Save return address

    # Copy passed in character to t0
    mv t0, a0
    add t1, x0, s0              # Pointer to VGA space that will change
    # Create constant 0x1000
    li t2, 0x1000
FVC_1:
    sw t0, 0(t1)                # Write character to screen
    addi t2, t2, -1             # Decrement counter
    beq t2, x0, FVC_2           # Exit loop when done
    addi t1, t1, 4              # Increment memory pointer by 4 to next character address
    j FVC_1
FVC_2:
    # Restore stack
    lw ra, 0(sp)		        # Restore return address
    addi sp, sp, 4		        # Update stack pointer
    ret                         # jalr x0, ra, 0
