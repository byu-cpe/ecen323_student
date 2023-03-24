#####################################################################################
#
# final_iosystem.s
#
# This program is written using the enhanced instruction set as an exmaple for
# the final processor lab. With the extended instructions we are able to employ regular
# assembly language programming constructs like "procedure calls" and the use
# of the stack. This program is given as an example of a variety of assembly
# programming techniques that you can use when you create your final project.
# 
# This program implements a simple game in which the user moves a character throughout
# the screen to reach a final destination. The timer times the player and
# saves the fastest time. If the user beats the fastest time then the LEDs
# are lit up.
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
    .eqv BLOCK_LOC 0x987C               # The VGA memory address where the 'block character' is located
                                        # 31, 12 or 0x8000+31*4+12*512=0x987C
    .eqv SEGMENT_TIMER_INTERVAL 100     # This constant represents the number of timer ticks (each 1 ms)
                                        # that are needed before incrementing the timer value on the seven
                                        # segment display. With a value of 100, the timer will increment
                                        # every 100 ms (or 10 times a second).

    .eqv INIT_FASTEST_SCORE 0xffff      # Fastest score initialized to 0xffff (should get lower with better play)

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

    # End in infinite loop (should never get here)
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

    # Game initialization code that is only executed once.

    # setup stack frame and save return address
    addi sp, sp, -4	    # Make room to save return address on stack
    sw ra, 0(sp)		# Put return address on stack

    # Initialize the default color (based on the value at the starting location)
    #  The default color is needed for VGA memories that are not initialized
    #  with a default background.
    li t0, STARTING_LOC                                # Address of starting location
    lw t1, 0(t0)                                       # Read value at this address
    # Shift right logical 8 bits (to bring the foreground and background for use by color offset)
    srli t1, t1, 8
    sw t1, CHAR_COLOR_OFFSET(tp)    # Write the new color values

    # Display a single blocking character
    li t0, BLOCK_LOC
    li t1, CHAR_Z_MAGENTA
    sw t1, 0(t0)

    # Initialize the seven segment display with the default fastest time (0xffff)
    li t1, INIT_FASTEST_SCORE
    sw t1, SEVENSEG_OFFSET(tp)
    # Initialize the LEDs with 0 (not a high score)
    sw x0, LED_OFFSET(tp)

MCG_RESTART:
    # This occurs when we want to prepare for another game. We get here
    # at power up, after a finished game, and after exiting a game with btnc.

    # Write ending character at given location
    lw t0, %lo(ENDING_CHARACTER)(gp)                   # Load character value to write
    lw t1, %lo(ENDING_CHARACTER_LOC)(gp)               # Load address of character location
    sw t0, 0(t1)

    # Write moving character at starting location (without restore)
    li a0, STARTING_LOC
    jal MOVE_CHARACTER

MCG_NO_BUTTON_START:
    # Make sure no buttons are being pressed before looking for button to start game
    # (a previous button press to end the game or reset the game could lead to this
    #  code entry. Need to wait until this button press is let go before proceeding).
    lw t0, BUTTON_OFFSET(tp)
    bne t0, x0, MCG_NO_BUTTON_START 

MCG_BUTTON_START:
    # Wait for a new button press to start the game
    lw t0, BUTTON_OFFSET(tp)
    beq t0, x0, MCG_BUTTON_START 

    # A button has been pressed to start the game (t0)
    # Copy button press value
    mv a0, t0
    # Clear timer and seven segment display and LEDs
    sw x0, SEVENSEG_OFFSET(tp)
    sw x0, TIMER(tp)
    sw x0, LED_OFFSET(tp)
    
MCG_PROC_BUTTONS:
    # At this point a button has been pressed and its value is in a0

    # See if btnc is pressed (to end game)
    li t0, BUTTON_C_MASK
    beq t0, a0, MCG_END_GAME_EARLY

    # btnc not pressed, process other button
    jal UPDATE_CHAR_ADDR            # returns new address in a0

    # Move the character (a0 has new address)
    jal MOVE_CHARACTER
    
    # See if the new location is the end location
    lw t1, %lo(ENDING_CHARACTER_LOC)(gp)               # Load address of end location
    beq t1, a0, MCG_GAME_ENDED

    # Continue playing game
MCG_CONTINUE:
    # Wait for button release while updating timer
    jal UPDATE_TIMER
    lw t0, BUTTON_OFFSET(tp)
    bne x0, t0, MCG_CONTINUE

    # Now that the button has been released, wait for a new button while updating timer
MCG_CONTINUE_BTN:
    jal UPDATE_TIMER
    lw t0, BUTTON_OFFSET(tp)
    beq x0, t0, MCG_CONTINUE_BTN
    mv a0, t0               # copy button value to a0
    j MCG_PROC_BUTTONS

MCG_GAME_ENDED:
    # The character made it to the end. Stop updating display and keep latest
    # score on the display. If the new score is less than the high score then
    # display the LEDs to highlight a new fastest score.

    lw t0, %lo(FASTEST_SCORE)(gp)       # Load fastest score
    lw t1, SEVENSEG_OFFSET(tp)          # Load current score
    slt t2, t1, t0                      # Is new score less than fastest score?
    beq t2, x0, MCG_GAME_ENDED_NO_NEW_FASTEST_SCORE
    # Fall through when we have a new fastest score
    addi t0, gp, %lo(FASTEST_SCORE)         # Compute address of fastest score memory location
    sw t1, 0(t0)                            # Update fastest score with new value
    # Turn on all LEDs 
    li t0, 0xffff
    sw t0, LED_OFFSET(tp)

MCG_GAME_ENDED_NO_NEW_FASTEST_SCORE:
    j MCG_RESTART

MCG_END_GAME_EARLY:
    # When btnc is pressed, write a 0xffff to Seven segment display (indicating bogus play)
    # erase the current character, and prepare for new game
    li t1, INIT_FASTEST_SCORE
    sw t1, SEVENSEG_OFFSET(tp)
    # Initialize the LEDs with 0 (not a high score)
    sw x0, LED_OFFSET(tp)
    # Move the current character to the start location
    #li a0, STARTING_LOC
    jal MOVE_CHARACTER
    #li a0, STARTING_LOC
    #li a1, 1
    #jal MOVE_CHARACTER
    # Restart game
    j MCG_RESTART

    # Should never get here. Will play game indefinitely
MCG_EXIT:   # exit game procedure
    # Restore stack
    lw ra, 0(sp)		# Restore return address
    addi sp, sp, 4		# Update stack pointer
    ret                 # same as jalr x0, ra, 0


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
#  returns in a0: New address of character location. If BTNC is pressed,
#                 return 0 indicating an early end to the game.
#
################################################################################
UPDATE_CHAR_ADDR:

    # load current character address in t2
    lw t2, %lo(DISPLACED_CHARACTER_LOC)(gp)   # Load address of current character

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
    # Move pointer right (if not in last column)
    li t1, LAST_COLUMN
    beq t3, t1, UCA_DONE            # Last column, do nothing
    addi t2, t2, 4                  # Increment pointer
    j UCA_DONE

UCA_CHECK_BTNL:
    li t0, BUTTON_L_MASK
    bne t0, a0, UCA_CHECK_BTND
    # Move Pointer left (if not in first column)
    beq x0, t3, UCA_DONE            # Too far left, skip
    addi t2, t2, -4                 # Decrement pointer
    j UCA_DONE

UCA_CHECK_BTND:
    li t0, BUTTON_D_MASK
    bne t0, a0, UCA_CHECK_BTNU
    # Move pointer down
    li t1, LAST_ROW
    bge t4, t1, UCA_DONE            # Too far down, skip
    addi t2, t2, ADDRESSES_PER_ROW  # Increment pointer
    j UCA_DONE

UCA_CHECK_BTNU:
    li t0, BUTTON_U_MASK
    bne t0, a0, UCA_DONE            # Exit - no buttons matched
    # Move pointer up
    beq x0, t4, UCA_DONE                             # Too far up, skip
    addi t2, t2, NEG_ADDRESSES_PER_ROW               # Increment pointer

UCA_DONE:
    # Load the character at the new location. 
    lw t0, 0(t2)
    # Mask the bottom 7 bits (only the ASCII value, not its color)
    andi t0, t0 0x7f
    # Load the blocking character
    lw t1, %lo(BLOCK_CHARACTER_VALUE)(gp)
    # See if character at new position is same as blocking character. If so, don't move
    bne t0, t1, UCA_RET
    # New address is block wall. Go back and get original address (to prevent moving on block)
    lw t2, %lo(DISPLACED_CHARACTER_LOC)(gp) 
UCA_RET:
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
# MOVE_CHARACTER
#
# Moves the character to the new location and erases the character from the
# previous location. This function doesn't check for valid addresses.
#
# a0: memory address of new location of moving character
#
# a0 is not changed (returns the memory address provided as parameter)
#
################################################################################
MOVE_CHARACTER:

    # setup stack frame and save return address
    addi sp, sp, -4	    # Make room to save return address on stack
    sw ra, 0(sp)		# Put return address on stack


    # Load the address of the old character that was previously replaced
    lw t3,%lo(DISPLACED_CHARACTER_LOC)(gp)
    # If this address is zero, no need to restore character
    beq t3, x0, MC_SAVE_DISPLACED_CHAR

    # Load the value of the character that was previously displaced
    lw t2, %lo(DISPLACED_CHARACTER)(gp)
    # restore the character that was displaced
    sw t2,0(t3)

MC_SAVE_DISPLACED_CHAR:         # Save the address and value of the displaced character

    # Load the value of the character that is going to be displaced (so it can be restored later)
    lw t1, 0(a0)
    # Load address of the displaced character location
    addi t0,gp,%lo(DISPLACED_CHARACTER)
    # Save the value of the displaced character
    sw t1,0(t0)
    # Save the address of the displaced character
    addi t0,gp,%lo(DISPLACED_CHARACTER_LOC)
    sw a0, 0(t0)

MC_UPDATE_MOVING_CHAR:          # Write moving character to its new location

    # Load the character value to write into the new location
    lw t0, %lo(MOVING_CHARACTER)(gp)
    # Write the new character (overwriting the old character)
    sw t0, 0(a0)

MC_EXIT:
    lw ra, 0(sp)		# Restore return address
    addi sp, sp, 4		# Update stack pointer
    ret                 # same as jalr x0, ra, 0


    # You should always add three 'nop' instructions at the end of your program to make
    # sure your pipeline always has a valid instruction. You should never get here.
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
# It will be restored when the moving character moves off of its spot.
DISPLACED_CHARACTER:
    .word 0

# This stores the ASCII value of the character that represents the destination location
ENDING_CHARACTER:
    .word CHAR_C_YELLOW

# This stores the memory address of the moving character.
# It is initialized to zero so that the first call will not restore a character
DISPLACED_CHARACTER_LOC:
    .word 0

# This stores the memory address of the ending character location
ENDING_CHARACTER_LOC:
    .word ENDING_LOC

# Storage for the fastest recorded score. Starts out with highest value
FASTEST_SCORE:
    .word INIT_FASTEST_SCORE

# Storage for the last recorded score. Starts out with highest value
LAST_SCORE:
    .word INIT_FASTEST_SCORE

# This stores the value of the character that acts as a "wall"
BLOCK_CHARACTER_VALUE:
    .word CHAR_Z

