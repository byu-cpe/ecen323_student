####################################################################################3#
#
# multicycle_iosystem.s
#
# This simple test program demonstrates the operation of all the LEDs, switches,
# buttons, and seven segment display in the I/O sub-system. 
#
#  - The timer value is copied to the seven segment display
#  - Button behavior:
#    - BTNC clears the timer/seven segment display
#    - BTND turns all the LEDs OFF
#    - BTNU turns all the LEDs to on
#    - BTNR inverts values from the switches when displaying on LEDs
#    - BTNL shifts the values from the switches left one
#    - No button:
#      The value of the switches are read and then used to drive the LEDs
#
# This version of the program is written using the primitive instruction set
# for the multi-cycle RISC-V processor developed in the first labs.
#
# This program does not use the data segment.
#
# Memory Organization:
#   0x0000-0x1fff : text
#   0x2000-0x3fff : data
#   0x7f00-0x7fff : I/O
#
# Registers:
#  x3(gp):  I/O base address
#  x8(s0):  Value of buttons
#  x9(s1):  Value of switches
#  x18(s2): Value to write in LEDs
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
    .eqv TIMER 0x30
    .eqv BUTTON_OFFSET 0x24

# I/O mask constants
    .eqv BUTTON_C_MASK 0x01
    .eqv BUTTON_L_MASK 0x02
    .eqv BUTTON_D_MASK 0x04
    .eqv BUTTON_R_MASK 0x08
    .eqv BUTTON_U_MASK 0x10

main:
    # Prepare I/O base address
    addi gp, x0, 0x7f
    # Add x3 to itself 8 times (0x7f << 8 = 0x7f00)
    addi t0, x0, 8
L1:
    add gp, gp, gp
    addi t0, t0, -1
    beq t0, x0, L2
    beq x0, x0, L1
L2:
    # 0x7f00 should be in gp (x3)

    # Set constants
    sw x0, SEVENSEG_OFFSET(gp)          # Clear seven segment display
    sw x0, TIMER(gp)                    # Clear timer to zero

LOOP_START:

    # Load the buttons
    lw s0, BUTTON_OFFSET(gp)
    # Read the switches
    lw s1, SWITCH_OFFSET(gp)

    # Mask the buttons for button C
    andi t0, s0, BUTTON_C_MASK
    # If button is not pressed, skip btnc code
    beq t0, x0, UPDATE_SEVEN_SEG
    # Button C pressed - fall through to clear timer and seven segmeent dislplay
    sw x0, SEVENSEG_OFFSET(gp)          # Clear seven segment display
    sw x0, TIMER(gp)                    # Clear timer to zero
    beq x0, x0, LOOP_START              # Don't process other buttons

UPDATE_SEVEN_SEG:
    lw t0, TIMER(gp)                   # Load timer
    # Write timer to seven seg
    sw t0, SEVENSEG_OFFSET(gp)         

BUTTON_CHECK:       # Label to check all buttons

BTND_CHK:           # Check btnd

    # Check button D: turn LEDs off
    andi t0, s0, BUTTON_D_MASK
    # If button is not pressed, skip
    beq t0, x0, BTNU_CHK
    # Button D pressed - write 0 to LEDs (turn then off)
    add s2, x0, x0
    beq x0, x0, WRITE_LED

BTNU_CHK:
    # Mask the buttons for button U
    andi t0, s0, BUTTON_U_MASK
    # If button is not pressed, skip
    beq t0, x0, BTNR_CHK
    # Button U pressed - write ffff to LEDs (turn them on)
    add s2, x0, x0        # load 0 in t0
    xori s2, s2, -1      # invert t0
    beq x0, x0, WRITE_LED

BTNR_CHK:
    # Check button R: Invert switches when displaying on LEDs
    andi t0, s0, BUTTON_R_MASK
    # If button is not pressed, skip
    beq t0, x0, BTNL_CHK
    # Button R pressed - invert switches
    xori s2, s1, -1      # invert switch read
    beq x0, x0, WRITE_LED

BTNL_CHK:
    # Check button L: Shift switches left when displaying on LEDs
    andi t0, s0, BUTTON_L_MASK
    # If button is not pressed, skip
    beq t0, x0, NO_BTN
    # Button L pressed - add switchces for a left shift
    add s2, s1, s1
    beq x0, x0, WRITE_LED

NO_BTN:
    # load switches to LEDs
    add s2, s1, x0

WRITE_LED:
    sw s2, LED_OFFSET(gp)
    beq x0, x0, LOOP_START

