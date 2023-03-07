# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# defuse.s
#
# This code simulates a 'bomb' that you need to defuse. Most of the code has no
# comments and you will need to read through the code and figure out what buttons
# and switches to press to defuse the 'bomb'.
#
#
#
# Memory Organization:
#   0x0000-0x1fff : text
#   0x2000-0x3fff : data
#   0x7f00-0x7fff : I/O
#   0x8000-? : VGA
#
# Registers:
#  x3(gp):  I/O base address
#  x4(tp):  VGA Base address
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

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
    .eqv MS_PER_SECOND 1000
    .eqv CHAR_COLOR_OFFSET 0x34
    .eqv SPACE_CHAR 0x20

# I/O mask constants
    .eqv BUTTON_C_MASK 0x01
    .eqv BUTTON_L_MASK 0x02
    .eqv BUTTON_D_MASK 0x04
    .eqv BUTTON_R_MASK 0x08
    .eqv BUTTON_U_MASK 0x10

main:
    # Prepare I/O base address
    addi gp, x0, 0x7f
    # Shift gp left 8 to generate 0x7f00
    slli gp, gp, 8
    # 0x7f00 should be in gp

    # Prepare VGA base address
    addi tp, x0, 0x40
    # Shift tp left 9 (0x8000 in tp)
    slli tp, tp, 9

    # Comments and proper coding style are intentionally removed for the code below
    # for this exercise.
L1_4:
    addi s0, x0, 0x400
    slli s0, s0, 2
    addi s3, x0, 0x7ff
    slli s3, s3, 5
    ori s3, s3, 0xff

FUSE_LIT:
    addi t1, x0, 0xff
    slli t1, t1, 16
    sw t1, 0x34(gp)
    addi t0, x0, 0x20
    add t1, x0, tp
    add t2, x0, s0
L2_3:
    sw t0, 0(t1)
    addi t2, t2, -1
    beq t2, x0, L3_1
    addi t1, t1, 4
    beq x0, x0, L2_3
L3_1:
    lw s1, 0x30(gp)
    sw x0, 0x18(gp)
    sw x0, 0x0(gp)
L3_2:
    lw t0, 0x24(gp)
    beq x0, t0, L3_2
    addi t1, x0, 0x10
    beq t0, t1, L4_1
    beq x0, x0, EXPLODE
L4_1:
    addi t0, x0, 1
    sw t0, 0x18(gp)
L4_1_4:
    lw t0, 0x24(gp)
    beq t0, x0, L4_1_5
    beq x0, x0, L4_1_4
L4_1_5:
    lw t2, 0x4(gp)
    sw t2, 0x0(gp)
    lw t0, 0x24(gp)
    beq x0, t0, L4_1_5
    addi t1, x0, 0x04
    beq t0, t1, L4_1_6
    beq x0, x0, EXPLODE
L4_1_6:
    beq t2, s3, L4_2
    beq x0, x0, EXPLODE

L4_2:
    addi t0, x0, 2
    sw t0, 0x18(gp)
L4_2_4:
    lw t0, 0x24(gp)
    beq t0, x0, L4_2_5
    beq x0, x0, L4_2_4
L4_2_5:
    addi t1, x0, 0x02
    ori t1, t1, 0x01
    ori t1, t1, 0x08
L4_2_6:
    lw t0, 0x24(gp)
    beq x0, t0, L4_2_6
    or t2, t1, t0
    beq t2, t1, L4_2_7
    beq x0, x0, EXPLODE
L4_2_7:
    beq t0, t1, L4_3
    beq x0, x0, L4_2_6

L4_3:
    addi t0, x0, 3
    sw t0, 0x18(gp)
L4_3_4:
    lw t0, 0x24(gp)
    beq t0, x0, L4_3_5
    beq x0, x0, L4_3_4
L4_3_5:
    lw s2, 0x30(gp)
    and s2, s2, s3
    sw s2, 0x0(gp)
L4_4:
    lw t0, 0x24(gp)
    beq x0, t0, L4_4
    addi t1, x0, 0x01
    beq t0, t1, L4_5
    beq x0, x0, EXPLODE
L4_5:
    lw t0, 0x4(gp)
    beq t0, s2, L9
    beq x0, x0, EXPLODE
L9:
    addi t0, x0, 4
    sw t0, 0x18(gp)
L9_1_4:
    lw t0, 0x24(gp)
    beq t0, x0, L9_1_5
    beq x0, x0, L9_1_4
L9_1_5:
    add t2, s2, s2
    #add t2, s2, t2
    and t2, t2, s3
L10:
    lw t0, 0x24(gp)
    beq x0, t0, L10
    addi t1, x0, 0x08
    beq t0, t1, L11
    beq x0, x0, EXPLODE
L11:
    lw t0, 0x4(gp)
    beq t0, t2, DISARM
    beq x0, x0, EXPLODE
DISARM:
    addi t0, x0, 5
    sw t0, 0x18(gp)
    addi t1, x0, 0xf0
    addi t0, x0, 12
L12_1:
    add t1, t1, t1
    addi t0, t0, -1
    beq t0, x0, L12_2
    beq x0, x0, L12_1
L12_2:
    sw t1, 0x34(gp)
    addi t0, x0, 0x20
    add t1, x0, tp
    add t2, x0, s0
L12_3:
    sw t0, 0(t1)
    addi t2, t2, -1
    beq t2, x0, L13
    addi t1, t1, 4
    beq x0, x0, L12_3
L13:
    addi t0, tp, 0
    addi t1, x0, 0x46
    sw t1, 0(t0)
    addi t0, t0, 4
    addi t1, x0, 0x33
    sw t1, 0(t0)
    addi t0, t0, 4
    addi t1, x0, 0x42
    sw t1, 0(t0)
    addi t0, t0, 4
    addi t1, x0, 0x30
    sw t1, 0(t0)
    addi t0, t0, 4
    addi t1, x0, 0x31
    sw t1, 0(t0)
    addi t0, t0, 4
L13_1:
    lw t0, 0x24(gp)
    beq x0, t0, L13_2
    beq x0, x0, L13_1
L13_2:
    lw t0, 0x24(gp)
    beq x0, t0, L13_2
L13_3:
    lw t0, 0x24(gp)
    beq x0, t0, FUSE_LIT
    beq x0, x0, L13_3

EXPLODE:
    sw s3, SEVENSEG_OFFSET(gp)
    addi t1, x0, 0xf0
    slli t1, t1, 16
    sw t1, CHAR_COLOR_OFFSET(gp)
    addi t0, x0, SPACE_CHAR
    add t1, x0, tp
    add t2, x0, s0
L14_3:
    sw t0, 0(t1)
    addi t2, t2, -1
    beq t2, x0, L20
    addi t1, t1, 4
    beq x0, x0, L14_3
L20:
    lw t0, BUTTON_OFFSET(gp)
    beq x0, t0, L20_1
    beq x0, x0, L20
L20_1:
    lw t0, BUTTON_OFFSET(gp)
    beq x0, t0, L20_1
L20_2:
    lw t0, BUTTON_OFFSET(gp)
    beq x0, t0, FUSE_LIT
    beq x0, x0, L20_2

