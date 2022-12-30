####################################################################################3#
#
# forwarding_iosystem.s
#
# This program is written using the primitive instruction set
# for the forwarding RISC-V processor.
#
# This program does not use the data segment.
#
# Memory Organization:
#   0x0000-0x1fff : text
#   0x2000-0x3fff : data
#   0x7f00-0x7fff : I/O
#   0x8000- : VGA
#
# Registers:
# x3(gp):   I/O base address
# x4(tp):   VGA Base address
# x8(s0):   Memory pointer to location to display character
# x9(s1):   Current column index
# x18(s2):  Current row index
#
####################################################################################3#
.globl  main

.data
    .word 0

.text


# I/O address offset constants
    .eqv LED_OFFSET 0x0
    .eqv SWITCH_OFFSET 0x4
    .eqv SEVENSEG_OFFSET 0x18
    .eqv BUTTON_OFFSET 0x24
    .eqv CHAR_COLOR_OFFSET 0x34

# I/O mask constants
    .eqv BUTTON_C_MASK 0x01
    .eqv BUTTON_L_MASK 0x02
    .eqv BUTTON_D_MASK 0x04
    .eqv BUTTON_R_MASK 0x08
    .eqv BUTTON_U_MASK 0x10

# ASCI SPACE
    .eqv SPACE_CHAR 0x20
    .eqv LAST_COLUMN 77                 # 79 - last two columns don't show on screen
    .eqv LAST_ROW 29                    # 31 - last two rows down't show on screen
    .eqv ADDRESSES_PER_ROW 512
    .eqv NEG_ADDRESSES_PER_ROW -512

main:
    # Prepare I/O base address
    addi gp, x0, 0x7f
    # Add to itself 8 times (shift 8)
    addi t0, x0, 8
L1:
    add gp, gp, gp
    addi t0, t0, -1
    beq t0, x0, L2
    beq x0, x0, L1

L2:
    # 0x7f00 should be in gp

    # Prepare VGA base address
    addi tp, x0, 0x40
    # Add to itself 9 times (shift 9)
    addi t0, x0, 9
L3:
    add tp, tp, tp
    addi t0, t0, -1
    beq t0, x0, L4
    beq x0, x0, L3

L4:
    # 0x8000 should be in tp

CLEAR_VGA:

    # Set the foreground based on switches (t2). 
    lw t2, SWITCH_OFFSET(gp)
    # Mask the bottom 12 bits of what is read from switches
    addi t0, x0, 0x7ff
    add t0, t0, t0     # ffe
    addi t0, t0, 1     # fff
    and t2, t2, t0
    # invert foreground to generate the background (t3)
    xori t3, t2, -1
    # Mask the new background
    and t3, t3, t0
    # Shift the background color (t3) 12 to the left
    addi t0, x0, 12
L4_1:
    add t3, t3, t3
    addi t0, t0, -1
    beq t0, x0, L4_2
    beq x0, x0, L4_1
L4_2:
    # Merge the foreground and the background
    or t2, t2, t3
    sw t2, CHAR_COLOR_OFFSET(gp)  # Write the new color values

    # Write a space to all locations in VGA memory
    addi t0, x0, SPACE_CHAR       # ASCII character for space
    add t1, x0, tp                # Pointer to VGA space that will change
    # Create constant 0x1000
    addi t2, x0, 0x400            # 0x400
    add t2, t2, t2                # 0x800
    add t2, t2, t2                # 0x1000

L5:
    sw t0, 0(t1)
    addi t2, t2, -1             # Decrement counter
    beq t2, x0, L6              # Exit loop when done
    addi t1, t1, 4              # Increment memory pointer by 4 to next character address
    beq x0, x0, L5
L6:
    # Done initializing screen
    # Initialize the VGA character write constants
    addi s0, tp, 0              # s0: pointer to VGA locations
    addi s1, x0, 0              # s1: current column
    addi s2, x0, 0              # s2: current row
    # Clear Seven segment display and LEDs
    sw x0, SEVENSEG_OFFSET(gp)
    sw x0, LED_OFFSET(gp)
    # Display the first character at location 0,0
    beq x0, x0, DISPLAY_LOCATION

    # Wait until all the buttons are released before proceeding to check for status of buttons
    # (this is a one shot functionality to prevent one button press from causing more than one
    #  response)
BTN_RELEASE:
    lw t0, BUTTON_OFFSET(gp)
    # Keep jumping back until a button is pressed
    beq x0, t0, BTN_PRESS
    beq x0, x0, BTN_RELEASE

BTN_PRESS:
    # Wait for button press
    lw t0, BUTTON_OFFSET(gp)
    # Keep jumping back until a button is pressed
    beq x0, t0, BTN_PRESS

    # See if BUTTON_C is pressed. If so, clear VGA
    addi t1, x0, BUTTON_C_MASK
    beq t0, t1, CLEAR_VGA

UPDATE_DISPLAY_POINTER:
    # Any other button means print the character of the switches on the VGA and move the pointer

    # Update the pointer based on the button
    addi t1, x0, BUTTON_L_MASK
    beq t0, t1, PROCESS_BTNL
    addi t1, x0, BUTTON_R_MASK
    beq t0, t1, PROCESS_BTNR
    addi t1, x0, BUTTON_U_MASK
    beq t0, t1, PROCESS_BTNU
    addi t1, x0, BUTTON_D_MASK
    beq t0, t1, PROCESS_BTND

    # Shouldn't get here
    beq x0, x0, BTN_RELEASE

PROCESS_BTNR:
    # Move pointer right
    addi t0, x0, LAST_COLUMN
    beq s1, t0, BTN_RELEASE                     # Ignore if on last column
    addi s1, s1, 1                              # Increment column
    addi s0, s0, 4                              # Increment pointer
    beq x0, x0, DISPLAY_LOCATION

PROCESS_BTNL:
    # Move pointer left
    beq s1, x0, BTN_RELEASE                     # Ignore if on first column
    addi s1, s1, -1                             # Decrement column
    addi s0, s0, -4                             # Decrement pointer
    beq x0, x0, DISPLAY_LOCATION

PROCESS_BTNU:
    # Move pointer Up
    beq s2, x0, BTN_RELEASE                     # Ignore if on first row
    addi s2, s2, -1                             # Decrement row
    addi s0, s0, NEG_ADDRESSES_PER_ROW          # Decrement pointer
    beq x0, x0, DISPLAY_LOCATION

PROCESS_BTND:
    # Move pointer Down
    addi t0, x0, LAST_ROW
    beq s2, t0, BTN_RELEASE                     # Ignore if on last row
    addi s2, s2, 1                              # Increment row
    addi s0, s0, ADDRESSES_PER_ROW              # Increment pointer
    beq x0, x0, DISPLAY_LOCATION

DISPLAY_LOCATION:
    # Display the character at the current location
    lw t1, SWITCH_OFFSET(gp)                    # Read the switches
    sw t1, 0(s0)                                # Write the character to the VGA

    # Display pointer on LCD
    sw s0, SEVENSEG_OFFSET(gp)
    # Display col,row on LEDs
    add t0, s1, x0                              # Load s1 (column) to t0
    # Shift by 8
    add t0, t0, t0
    add t0, t0, t0
    add t0, t0, t0
    add t0, t0, t0
    add t0, t0, t0
    add t0, t0, t0
    add t0, t0, t0
    add t0, t0, t0
    # Or s2 (row)
    or t0, t0, s2
    # Write to LEDs
    sw t0, LED_OFFSET(gp)

    # Go back to button release
    beq x0, x0, BTN_RELEASE