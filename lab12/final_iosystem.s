#####################################################################################
#
# final_iosystem.s
#
# This program is written using the enhanced instruction set used in the final
# processor lab.
#
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
#   0x8000- : VGA
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

    .eqv CHAR_A 0x41
    .eqv CHAR_A_RED 0x0fff00C1
    .eqv CHAR_C 0x43
    .eqv CHAR_C_YELLOW 0x00fff0C3
    .eqv CHAR_Z 0x5A
    .eqv CHAR_Z_MAGENTA 0x0f0f0fDA
    .eqv CHAR_SPACE 0x20
    .eqv COLUMN_MASK 0x1fc
    .eqv COLUMN_SHIFT 2
    .eqv ROW_MASK 0x3e00
    .eqv ROW_SHIFT 9
    .eqv LAST_COLUMN 76                 # 79 - last two columns don't show on screen
    .eqv LAST_ROW 29                    # 31 - last two rows don't show on screen
    .eqv ADDRESSES_PER_ROW 512
    .eqv NEG_ADDRESSES_PER_ROW -512
    .eqv STARTING_LOC 0x8204
    .eqv ENDING_LOC 0xb700              # 64, 27 or 0x8000+64*4+27*512=0xb700
    .eqv SEGMENT_TIMER_INTERVAL 100

    # Parameterss for the MOVE_CHARACTER subroutine
    .eqv MC_WRITE_NEW_CHARACTER 0x1
    .eqv MC_RESTORE_OLD_CHARACTER 0x2
    .eqv MC_RESTORE_OLD_WRITE_NEW_CHARACTER 0x3


main:
	# Setup the stack: sp = 0x3ffc
    li sp, 0x3ffc
	#lui sp, 4		# 4 << 12 = 0x4000
	#addi sp, sp, -4		# 0x4000 - 4 = 0x3ffc
	# setup the global pointer to the data segment (2<<12 = 0x2000)
	lui gp, 2
    # Prepare I/O base address
    li tp, 0x7f00
    # Prepare VGA base address
    li s0, 0x8000

    # Set the color from the switches
    #jal ra, SET_COLOR_FROM_SWITCHES
    jal ra, SET_COLOR_FROM_STARTING_LOC

RESTART:

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

PROC_BUTTONS:

    # Wait for a button press
    jal ra, PROCESS_BUTTONS

    # If return is zero, process another button
    beq x0, a0, PROC_BUTTONS

    # If return is non-zero, restart
    jal REACH_END
    j RESTART


################################################################################
# This procedure will check the timere and update the seven segment display
# if the timer has reached another tick value.
################################################################################
UPDATE_TIMER:
    lw t0, TIMER(tp)
    li t1, SEGMENT_TIMER_INTERVAL
    bne t1, t0, UT_DONE
    # timer has reached tick, incremenet seven segmeent display and clear timer
    sw x0, TIMER(tp)
    lw t0, SEVENSEG_OFFSET(tp)
    addi t0, t0, 1
    sw t0, SEVENSEG_OFFSET(tp)
UT_DONE:
    jalr x0, ra, 0


################################################################################
#
################################################################################
PROCESS_BUTTONS:
    # setup stack frame and save return address
	addi sp, sp, -4	    # Make room to save values on the stack
	sw ra, 0(sp)		# Copy return address to stack

    # Start out making sure the buttons are not being pressed
    # (process buttons only once per press)
PB_1:
    # Update the timer
    jal UPDATE_TIMER
    lw t0, BUTTON_OFFSET(tp)
    # Keep jumping back while a button is being pressed
    bne x0, t0, PB_1

    # A button not being pressed

    # Now wait until a button is pressed
PB_2:
    jal UPDATE_TIMER
    lw t0, BUTTON_OFFSET(tp)
    # Keep jumping back until a button is pressed
    beq x0, t0, PB_2

    # some button is being pressed.

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

    jalr x0, ra, 0


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
# Moves the character to the new location and erases the character from the
# previous location. This function doesn't check for valid addresses.
#
# a0: memory address of new location of moving character
# a1: bit 0: write moving character in new location and save old character
#     bit 1: restored old character
################################################################################
MOVE_CHARACTER:
    # Load the value of the character that is going to be displaced
    lw t1, 0(a0)
    # Load the value of the character that was previously displaced (and may need to be restored)
    lw t2, %lo(DISPLACED_CHARACTER)(gp)
    # Load the address of the old character that was previously replaced
    lw t3,%lo(MOVING_CHARACTER_LOC)(gp)

    # See if the the moving character should be written to the new location
    andi t0, a1, MC_WRITE_NEW_CHARACTER
    beq t0, x0, MC_RESTORE_OLD
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


################################################################################
#
################################################################################
SET_COLOR_FROM_STARTING_LOC:
    # Read the character at the starting location
    li t0, STARTING_LOC                                # Load address of location
    lw t1, 0(t0)                                       # Read value
    # Shift right logical 8 bits
    srli t1, t1, 8
    sw t1, CHAR_COLOR_OFFSET(tp)  # Write the new color values
    # put color in a0
    mv a0, t1
    jalr x0, ra, 0

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
################################################################################
FILL_VGA_CHARACTER:
    # Copy passed in character to t0
    mv t0, a0
    add t1, x0, s0              # Pointer to VGA space that will change
    # Create constant 0x1000
    li t2, 0x1000
FVC_1:
    sw t0, 0(t1)
    addi t2, t2, -1             # Decrement counter
    beq t2, x0, FVC_2           # Exit loop when done
    addi t1, t1, 4              # Increment memory pointer by 4 to next character address
    jal x0, FVC_1
FVC_2:
    jalr x0, ra, 0


#######################################3
# Data segment
#######################################3

.data

# This stores the value of the character that will move around
MOVING_CHARACTER:
    .word CHAR_A_RED

# This stores the value of the character that has been overwritten by the moved character.
# It will be restored when the character is moved.
DISPLACED_CHARACTER:
    .word

# This stores the value of the character that represents the destination
ENDING_CHARACTER:
    .word CHAR_C_YELLOW

# This stores the value of the character that represents the destination
MOVING_CHARACTER_LOC:
    .word STARTING_LOC

# This stores the value of the character that represents the destination
ENDING_CHARACTER_LOC:
    .word ENDING_LOC
