#####################################################################################
#
# final_iosystem.s
#
# This program is written using the enhanced instruction set used in the final
# processor lab. With the extended instructions we are able to employ regular
# assembly language programming constructs like "procedure calls" and the use
# of the stack. This program is given as an example of a variety of assembly
# programming techniques that you can use when you create your final project.
# 
# The program operates as follows:
#
# 1. Setup the global registers (see note below about these registers)
# 2. Set 
#
# - Reads the switches to determine the 
# - Clear the screen with a color and foreground based on switches
#   - Place default character to display at given location
#   (upon startup and when BTNC is pressed)
# - Change defaults for each subsequent press of btnc without other button
#   2: change the character that is moved in the screen by switches
#   3: change the foregound of the character
#   4: change the background of the character
# - Move a given character around the screen with four direction buttons
#
#
#
# Memory Organization:
#   0x0000-0x1fff : text
#   0x2000-0x3fff : data
#   0x7f00-0x7fff : I/O
#   0x8000-0xbfff : VGA
#
# The stack will operate in the data segment and thus starts at 0x3ffc 
# and works its way down.
#
# Registers:
#  x1(ra):  Return address
#  x2(sp):  Stack Pointer
#  x3(gp):  Data segment pointer
#  x4(tp):  I/O base address
#  x8(s0):  VGA base address
#
#
####################################################################################3#
.globl  main

.text


# I/O address offset constants
    .eqv LED_OFFSET 0x0
    .eqv SWITCH_OFFSET 0x4
    .eqv SEVENSEG_OFFSET 0x18
    .eqv BUTTON_OFFSET 0x24
    .eqv CHAR_COLOR_OFFSET 0x34
    .eqv TIMER 0x30

# I/O mask constants
    .eqv BUTTON_C_MASK 0x01
    .eqv BUTTON_L_MASK 0x02
    .eqv BUTTON_D_MASK 0x04
    .eqv BUTTON_R_MASK 0x08
    .eqv BUTTON_U_MASK 0x10

# Game specific constants
    .eqv CHAR_A 0x41                    # ASCII 'A'
    .eqv CHAR_A_RED 0x0fff00C1          # 'A' character with red foreground, black background
    .eqv CHAR_C 0x43                    # ASCII 'C'
    .eqv CHAR_C_YELLOW 0x00fff0C3       # 'C' character with yellow foreground, black background
    .eqv CHAR_Z 0x5A                    # ASCII 'Z'
    .eqv CHAR_Z_MAGENTA 0x0f0f0fDA      # 'Z' character with magenta foreground, black background
    .eqv CHAR_SPACE 0x20                # ASCII ' '
    .eqv COLUMN_MASK 0x1fc              # Mask for the bits in the VGA address for the column
    .eqv COLUMN_SHIFT 2                 # Number of right shifts to determine VGA column
    .eqv ROW_MASK 0x3e00                # Mask for the bits in the VGA address for the row
    .eqv ROW_SHIFT 9                    # Number of right shifts to determine VGA row
    .eqv LAST_COLUMN 76                 # 79 - last two columns don't show on screen
    .eqv LAST_ROW 29                    # 31 - last two rows don't show on screen
    .eqv ADDRESSES_PER_ROW 512
    .eqv NEG_ADDRESSES_PER_ROW -512
    .eqv STARTING_LOC 0x8204            # The VGA memory address wher ethe 'starting' character is located.
                                        # 1,2 or 0x8000+1*4+2*512=0x8204
    .eqv ENDING_LOC 0xb700              # The VGA memory address where the 'ending character' is located
                                        # 64, 27 or 0x8000+64*4+27*512=0xb700

    .eqv SEGMENT_TIMER_INTERVAL 100     # This constant represents the number of timer ticks (each 1 ms)
                                        # that are needed before incrementing the timer value on the seven
                                        # segment display. With a value of 100, the timer will increment
                                        # every 100 ms (or 10 times a second).

    .eqv INIT_FASTEST_SCORE 0xffff      # Fastest score initialized to 0xffff (should get lower with better play)

    # Parameters for the MOVE_CHARACTER subroutine
    .eqv MC_WRITE_NEW_CHARACTER 0x1
    .eqv MC_RESTORE_OLD_CHARACTER 0x2
    .eqv MC_RESTORE_OLD_WRITE_NEW_CHARACTER 0x3


main:

    # The purpose of this initial section is to setup the global registers that
    # will be used for the entire program execution. This setup portion will only
    # be run once.

    # Setup the stack pointer: sp = 0x3ffc
    li sp, 0x3ffc
    # The previous "pseudo instruction" will be compiled into the following two instructions:
    #  lui sp, 4		# 4 << 12 = 0x4000
    #  addi sp, sp, -4		# 0x4000 - 4 = 0x3ffc

    # setup the global pointer to the data segment (2<<12 = 0x2000)
    lui gp, 2

    # Prepare I/O base address
    li tp, 0x7f00
 
    # Prepare VGA base address
    li s0, 0x8000

    # Call main program procedure
    jal MOVE_CHAR_GAME

    # End in infinite loop
END_MAIN:
    j END_MAIN

################################################################################
#
# MOVE_CHAR_GAME
#
#  This procedure contains the functionality of the game.
#
################################################################################
MOVE_CHAR_GAME:

    # setup stack frame and save return address
    addi sp, sp, -4	    # Make room to save return address on stack
    sw ra, 0(sp)		# Put return address on stack

    # Initialize the default color (based on the value at the starting location)
    li t0, STARTING_LOC                                # Address of starting location
    lw t1, 0(t0)                                       # Read value at this address
    # Shift right logical 8 bits (to bring the foreground and background for use by color offset)
    srli t1, t1, 8
    sw t1, CHAR_COLOR_OFFSET(tp)  # Write the new color values

    # This occurs when we restart the game
MCG_RESTART:

    # Clear timer and seven segment display
    sw x0, SEVENSEG_OFFSET(tp)
    sw x0, TIMER(tp)

    # Write ending character at given location
    lw t0, %lo(ENDING_CHARACTER)(gp)                   # Load character value to write
    lw t1, %lo(ENDING_CHARACTER_LOC)(gp)               # Load address of character location
    sw t0, 0(t1)

    # Write moving character at starting location
    li a0, STARTING_LOC
    li a1, MC_WRITE_NEW_CHARACTER
    jal MOVE_CHARACTER

    # The game has been reset and is ready to play. 

MCG_WAIT_FOR_FIRST_BUTTON_PRESS:
    # Wait for first button press and display high score

MCG_PROC_BUTTONS:
    # Start by making sure that no buttons are pressed (i.e., wait for previous button press to stop)
    li a0, 0                        # 0 parameter means "wait for no buttons"
    jal WAIT_FOR_BUTTONS

    # Now wait for a button press
    li a0, 1                        # 1 parameter means "wait for a button"
    jal WAIT_FOR_BUTTONS


    # If return is zero, process another button
    beq x0, a0, PROC_BUTTONS

    # If return is non-zero, restart
    jal REACH_END
    j MCG_RESTART


MCG_EXIT:   # exit game procedure
    # Restore stack
    lw ra, 0(sp)		# Restore return address
    addi sp, sp, 4		# Update stack pointer
    ret                 # same as jalr x0, ra, 0


################################################################################
# WAITING_FOR_GAME_START
#
#  This procedure is called when the game has not started and we are waiting for
#  any button press to start. This procedure will look at the global variables
#  FASTEST_SCORE and LAST_SCORE to determine what to do.
#  
#  - The game has not been played before (LAST_SCORE==0xffff)
#    :display 0xffff on seven segment display, LEDs are set to zero
#  - The game has been played before and the last play was the high score 
#     (LAST_SCORE!=0xfff and 
#  - The game has been played before and the last play was not the high score
#
################################################################################
WAITING_FOR_GAME_START:

    # Read the value of the timer
    lw t0, TIMER(tp)
    # Load the timer interval constant
    li t1, SEGMENT_TIMER_INTERVAL
    # If they are equal, fall through and increment the seven segment display.
    # Otherwise, exit the procedure (do nothing).
    bne t1, t0, UT_DONE
    # timer has reached the number of required ticks. incremenet seven segmeent display and clear timer

    # Clear timer by writing a 0 to it
    sw x0, TIMER(tp)
    # Load the current value being displayed on the seven segment display
    lw t0, SEVENSEG_OFFSET(tp)
    # Add 1 to this value
    addi t0, t0, 1
    # Update the seven segment display with this value
    sw t0, SEVENSEG_OFFSET(tp)
UT_DONE:
    # Read the seven segment value and place it in a0 (return value)
    lw a0, SEVENSEG_OFFSET(tp)
    ret             # jalr x0, ra, 0

################################################################################
#
# PROCESS_BUTTONS
#
#  This procedure will evaluate the value of the buttons and 
#
#  The value of the buttons are passed into this procedure as a parameter (a0)
#
#  Because this procedure calls another procedure, it must save the return 
#  address on the stack.
#
################################################################################
PROCESS_BUTTONS:

    # setup stack frame and save return address
    addi sp, sp, -4	    # Make room to save values on the stack
    sw ra, 0(sp)		# Copy return address to stack

    # Start out making sure the buttons are not being pressed
    # (process buttons only once per press). While waiting for the buttons
    # to be released, keep updating the timer.
    addi a0, x0, 0
    jal WAIT_FOR_BUTTONS
    # At this point, no buttons are being pressed. 
    # Now wait until a button is pressed (it will be a new button press)
    addi a0, x0, 1
    jal WAIT_FOR_BUTTONS
    # Button press and button value is in a0

    #  load current character address in s1
    lw s1, %lo(MOVING_CHARACTER_LOC)(gp)               # Load address current character

PB_CHECK_BTNR:
    addi t1, x0, BUTTON_R_MASK
    bne t0, t1, PB_CHECK_BTNL
    # Code for BTNR - Move pointer right
    li t2, LAST_COLUMN
    li t0, COLUMN_MASK
    and t1, t0, s1                # Mask bits in address of column 
    srli t1, t1, COLUMN_SHIFT     # Shift down to get column number
    beq t1, t2, PB_DONE_BTN_CHECK # Last column, skip
    addi a0, s1, 4                # Increment pointer
    li a1, MC_RESTORE_OLD_WRITE_NEW_CHARACTER
    jal MOVE_CHARACTER
    j PB_DONE_BTN_CHECK

PB_CHECK_BTNL:
    addi t1, x0, BUTTON_L_MASK
    bne t0, t1, PB_CHECK_BTND
    # Code for BTNL - Move Pointer left
    li t0, COLUMN_MASK
    and t1, t0, s1               # Mask bits in address of column 
    srli t1, t1, COLUMN_SHIFT    # Shift down to get column number
    beq x0, t1, PB_DONE_BTN_CHECK # Too far left, skip
    addi a0, s1, -4              # Decrement pointer
    li a1, MC_RESTORE_OLD_WRITE_NEW_CHARACTER
    jal MOVE_CHARACTER
    j PB_DONE_BTN_CHECK

PB_CHECK_BTND:
    addi t1, x0, BUTTON_D_MASK
    bne t0, t1, PB_CHECK_BTNU
    # Code for BTND - Move pointer down
    li t2, LAST_ROW
    li t0, ROW_MASK
    and t1, t0, s1                 # Mask bits in address of row 
    srli t1, t1, ROW_SHIFT         # Shift down to get column number
    bge t1, t2, PB_DONE_BTN_CHECK   # Too far up, skip
    addi a0, s1, ADDRESSES_PER_ROW               # Increment pointer
    li a1, MC_RESTORE_OLD_WRITE_NEW_CHARACTER
    jal MOVE_CHARACTER
    j PB_DONE_BTN_CHECK

PB_CHECK_BTNU:
    addi t1, x0, BUTTON_U_MASK
    bne t0, t1, PB_CHECK_BTNC
    # Code for BTNU - Move pointer up
    li t0, ROW_MASK
    and t1, t0, s1                 # Mask bits in address of row 
    srli t1, t1, ROW_SHIFT         # Shift down to get column number
    beq t1, x0, PB_DONE_BTN_CHECK   # Too far up, skip
    addi a0, s1, NEG_ADDRESSES_PER_ROW               # Increment pointer
    li a1, MC_RESTORE_OLD_WRITE_NEW_CHARACTER
    jal MOVE_CHARACTER
    j PB_DONE_BTN_CHECK


PB_CHECK_BTNC:
    addi t1, x0, BUTTON_C_MASK
    # This branch will only be taken if multiple buttons are pressed
    bne t0, t1, PB_DONE_BTN_CHECK
    # Code for BTNC


PB_DONE_BTN_CHECK:
    # See if the new location is the end location
    lw t1, %lo(ENDING_CHARACTER_LOC)(gp)               # Load address of end location
    bne t1, a0, PB_EXIT_NOT_AT_END
    # Reached the end - return a 1
    addi a0, x0, 1
    beq x0, x0, PB_EXIT

PB_EXIT_NOT_AT_END:
    # return 0 - not reached end
    mv a0, x0

PB_EXIT:
    # Restore stack
    lw ra, 0(sp)		# Restore return address
    addi sp, sp, 4		# Update stack pointer
    ret                 # jalr x0, ra, 0

################################################################################
# UPDATE_CHAR_ADDR
#
#  This procedure will read the current location of the character and update
#  the address of the character based on the a0 parameter. The parameter is
#  the value of the buttons and the updating will depend on whether up, down,
#  left, or right is pressed. The new address will be returned in a0.
#
#  a0: button values
#  t0, t1: temporaries
#  t2: address of character (to be updated)
#  t3: current column
#  t4: current row
#
#  returns in a0: New address of character location
#
################################################################################
UPDATE_CHAR_ADDR:

    # load current character address in t2
    lw t2, %lo(MOVING_CHARACTER_LOC)(gp)   # Load address of current character

    # Compute the current column (t3) and row (t4) from the current character address
    li t0, COLUMN_MASK
    and t3, t0, t2                  # Mask bits in address of column 
    srli t3, t3, COLUMN_SHIFT       # Shift down to get column number
    li t0, ROW_MASK
    and t4, t0, t2                  # Mask bits in address of row 
    srli t4, t4, ROW_SHIFT          # Shift down to get column number

UCA_CHECK_BTNR:
    li t0, BUTTON_R_MASK
    bne t0, a0, UCA_CHECK_BTNL
    # Code for BTNR - Move pointer right (if not in last column)
    li t0, LAST_COLUMN
    beq t0, t3, UCA_DONE            # Last column, do nothing
    addi t2, t2, 4                  # Increment pointer
    j UCA_DONE

UCA_CHECK_BTNL:
    li t0, BUTTON_L_MASK
    bne t0, a0, UCA_CHECK_BTND
    # Code for BTNL - Move Pointer left (if not in first column)
    beq x0, t3, UCA_DONE            # Too far left, skip
    addi t2, t2, -4                 # Decrement pointer
    j UCA_DONE

UCA_CHECK_BTND:
    li t0, BUTTON_D_MASK
    bne t0, a0, UCA_CHECK_BTNU
    # Code for BTND - Move pointer down
    li t0, LAST_ROW
    bge t0, t4, UCA_DONE            # Too far down, skip
    addi t2, t2, ADDRESSES_PER_ROW  # Increment pointer
    j UCA_DONE

UCA_CHECK_BTNU:
    li t0, BUTTON_U_MASK
    bne t0, a0, UCA_DONE            # Exit - no buttons matched
    # Code for BTNU - Move pointer up
    beq x0, t4, UCA_DONE                             # Too far up, skip
    addi t2, t2, NEG_ADDRESSES_PER_ROW               # Increment pointer

UCA_DONE:
    mv a0, t2                       # Return updated character address
    ret

################################################################################
# UPDATE_ROW
#
#  This procedure will read the current location of the character and update
#  the address of the character based on the a0 parameter. For a0==0, try
#  to decrement the row, for a0==1, increment the row. The new address
#  of the row will be returned in a0.
#
################################################################################
UPDATE_ROW:

    # load current character address in t2
    lw t2, %lo(MOVING_CHARACTER_LOC)(gp)   # Load address of current character






    # Extract the column number
    li t0, COLUMN_MASK
    and t1, t0, s1                # Mask bits in address of column 
    srli t1, t1, COLUMN_SHIFT     # Shift down to get column number (t1)
    # Reduce column? (a0 == 0)
    beq x0, a0, UC_REDUCE_COLUMN
    # Increase column
    li t0, LAST_COLUMN              # Get last column number
    beq t1, t0, UC_DONE             # If last column, don't increment
    addi t2, t2, 4                  # Increment pointer
    beq x0, x0, UC_DONE

UR_REDUCE_COLUMN:
    # Are we at the left most column? (0)
    beq x0, t2, UC_DONE             # If first column, don't decremenet
    # Decrease column    
    addi t2, t2, -4                 # Decrement pointer

UR_DONE:
    mv a0, t2                       # Return updated character address
    ret

################################################################################
# UPDATE_TIMER
#
#  This procedure will check the timer and update the seven segment display.
#  If the timer has reached another tick value, increment the display.
#  This procedure will return the current timer value.
#
################################################################################
UPDATE_TIMER:

    # Read the value of the timer
    lw t0, TIMER(tp)
    # Load the timer interval constant
    li t1, SEGMENT_TIMER_INTERVAL
    # If they are equal, fall through and increment the seven segment display.
    # Otherwise, exit the procedure (do nothing).
    bne t1, t0, UT_DONE
    # timer has reached the number of required ticks. incremenet seven segmeent display and clear timer

    # Clear timer by writing a 0 to it
    sw x0, TIMER(tp)
    # Load the current value being displayed on the seven segment display
    lw t0, SEVENSEG_OFFSET(tp)
    # Add 1 to this value
    addi t0, t0, 1
    # Update the seven segment display with this value
    sw t0, SEVENSEG_OFFSET(tp)
UT_DONE:
    # Read the seven segment value and place it in a0 (return value)
    lw a0, SEVENSEG_OFFSET(tp)
    ret             # jalr x0, ra, 0

################################################################################
#
# WAIT_FOR_BUTTONS
#
#  Based on the value of the parameter, this procedure will wait until a button
#  is pressed (a0 != 1) or when no buttons are pressed (a0 == 0). The procedure
#  will return the value of the buttons when the given condition is reached.
#  This procedure will call the "UPDATE_TIMER" procedure for each reading of the
#  buttons to keep the timer counting while waiting for button presses. 
#  Because this is not a leaf procedure, a stack frame is needed.
#
#  t0 is used for the button value
#
################################################################################

WAIT_FOR_BUTTONS:

    # setup stack frame and save return address
    addi sp, sp, -4	    # Make room to save values on the stack
    sw ra, 0(sp)		# Copy return address to stack

WFB_READ_BUTTONS:
    # Update the timer
    jal UPDATE_TIMER
    # Read buttons
    lw t0, BUTTON_OFFSET(tp)
    # For a==0, see if no buttons are being pressed
    beq x0, a0, WFB_CHECK_NO_BUTTONS
    # Fall through if a!=0. Exit if a button is being pressed
    bne x0, t0, WFB_DONE
    # If button not pressed, read again
    beq x0, x0, WFB_READ_BUTTONS

WFB_CHECK_NO_BUTTONS:
    # Read buttons again if a button is being pressed (otherwise fall through to exit)
    bne x0, t0, WFB_READ_BUTTONS

WFB_DONE:
    # Return last button value read (t0)
    mv a0, t0
    # Restore stack
    lw ra, 0(sp)		# Restore return address
    addi sp, sp, 4		# Update stack pointer
    ret                 # jalr x0, ra, 0


################################################################################
#
################################################################################
REACH_END:
    # Display the end character
    li t0, CHAR_Z_MAGENTA
    lw t1, %lo(ENDING_CHARACTER_LOC)(gp)               # Load address of end location
    sw t0, 0(t1)

    # Wait for no button (so last button doesn't count)
RE_1:
    lw t0, BUTTON_OFFSET(tp)
    # Keep jumping back while a button is being pressed
    bne x0, t0, RE_1
    # A button not being pressed
    # Now wait until a button is pressed
RE_2:
    lw t0, BUTTON_OFFSET(tp)
    # Keep jumping back until a button is pressed
    beq x0, t0, RE_2

    jalr x0, ra, 0

################################################################################
#
# MOVE_CHARACTER
#
# Moves the character to the new location and erases the character from the
# previous location. This function doesn't check for valid addresses.
#
# a0: memory address of new location of moving character
# a1: bit 0: write moving character in new location and save old character
#     bit 1: restore old character
################################################################################
MOVE_CHARACTER:

    # setup stack frame and save return address
    addi sp, sp, -4	    # Make room to save return address on stack
    sw ra, 0(sp)		# Put return address on stack

    # Load the value of the character that is going to be displaced
    lw t1, 0(a0)

    # See if the the moving character should be written to the new location
    andi t0, a1, MC_WRITE_NEW_CHARACTER
    beq t0, x0, MC_RESTORE_OLD      # It should not be written - branch to restore

    # Load the character value to write
    lw t0, %lo(MOVING_CHARACTER)(gp)
    # Write the new character (overwriting a character)
    sw t0, 0(a0)
    # Update the pointer to the new location
    addi t0,gp,%lo(MOVING_CHARACTER_LOC)
    sw a0, 0(t0)
    # Load address of the displaced character location
    addi t0,gp,%lo(DISPLACED_CHARACTER)
    # Save the value of the displaced character
    sw t1,0(t0)

    # At this point, the new character has been written, the displaced
    # character value has been stored, and the address of this location updated

MC_RESTORE_OLD:
    # See if the old displaced character should be restored
    andi t0, a1, MC_RESTORE_OLD_CHARACTER
    beq t0, x0, MC_EXIT
    # Load the value of the character that was previously displaced (and may need to be restored)
    lw t2, %lo(DISPLACED_CHARACTER)(gp)
    # Load the address of the old character that was previously replaced
    lw t3,%lo(MOVING_CHARACTER_LOC)(gp)
    # restore the character that was displaced
    sw t2,0(t3)

MC_EXIT:
    jalr x0, ra, 0

    # Write moving character
    lw t0, %lo(MOVING_CHARACTER)(gp)                   # Load character value to write
    sw t0, 0(a0)                                       # Write new character
    # Erase old character
    lw t1, %lo(MOVING_CHARACTER_LOC)(gp)               # Load address of old character location
    addi t0, x0, CHAR_SPACE
    sw t0, 0(t1)                                        # Write space in old location
    # Update location of new character
    addi t1,gp,%lo(MOVING_CHARACTER_LOC)
    sw a0, 0(t1)

    jalr x0, ra, 0

    lw ra, 0(sp)		# Restore return address
    addi sp, sp, 4		# Update stack pointer
    ret                 # same as jalr x0, ra, 0


################################################################################
# Sets the value of the default foreground to the value of the switches. Sets
# the value of the background to the inverse of the switches.
# 
# No arguments
# return value: None
#
################################################################################
SET_COLOR_FROM_SWITCHES:
    # setup stack frame and save return address
    addi sp, sp, -4	    # Make room to save values on the stack
    sw ra, 0(sp)		# This function uses 2 callee save regs

    # Set the foreground based on switches (t2). 
    lw t2, SWITCH_OFFSET(tp)                            # SET_COLOR_FROM_SWITCHES
    # Mask the bottom 12 bits of what is read from switches
    li t0, 0xffff
    and t2, t2, t0
    # invert foreground to generate the background (t3)
    xori t3, t2, -1
    # Mask the new background
    and t3, t3, t0
    # Shift the background color (t3) 12 to the left
    slli t3, t3, 12
    # Merge the foreground and the background
    or t2, t2, t3
    sw t2, CHAR_COLOR_OFFSET(tp)  # Write the new color values

    # put color in a0
    mv a0, t2
    # Restore stack
    lw ra, 0(sp)		# Restore return address
    addi sp, sp, 4		# Update stack pointer

    jalr x0, ra, 0


    # You should always add three 'nop' instructions at the end of your program to make
    # sure your pipeline always has a valid instruction.
    nop
    nop
    nop

################################################################################
# Data segment
#
#   The data segment is used to store global variables that are accessible by
#   any of the procedures.
#
################################################################################

.data

# This location stores the ASCII value of the character that will move around the screen
MOVING_CHARACTER:
    .word CHAR_A_RED

# This stores the value of the character that has been overwritten by the moved character.
# It will be restored when the memory location when the moving character moves off of its spot.
DISPLACED_CHARACTER:
    .word

# This stores the ASCII value of the character that represents the destination location
ENDING_CHARACTER:
    .word CHAR_C_YELLOW

# This stores the memory address of the moving character
MOVING_CHARACTER_LOC:
    .word STARTING_LOC

# This stores the memory address of the ending character location
ENDING_CHARACTER_LOC:
    .word ENDING_LOC

# Storage for the fastest recorded score. Starts out with highest value
FASTEST_SCORE:
    .word INIT_FASTEST_SCORE

# Storage for the last recorded score. Starts out with highest value
LAST_SCORE:
    .word INIT_FASTEST_SCORE
