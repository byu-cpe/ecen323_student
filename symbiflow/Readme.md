# SymbiFlow Instructions for ECEN 323

This page provides instructions on modifying your ECEN 323 projects to work with the Symbiflow build scripts.

## The following files have changed to support the SymbiFlow tool

* lab07/multicycle_iosystem.sv
  * Hard code text segment filename
* resources/iosystem/iosystem.xdc
  * Simplified the clock definition (for symbiflow)
* resources/iosystem/io_clocks.sv
  * Used a single MMCM instead of two
* resources/iosystem/riscv_mem.sv
  * Changed parameters using the newer parameter syntax
  * REmoved initialization of instruction memory with NOPs
  * Changed the logic for instruciton memory in a way that is supported by symbiflow

* resources/iosystem/cores/vga/bramMacro.v
  * Removed instantiation of BRAM and created behavioral model


## Lab 7

Run the script `create_multicycle_project_symbi.tcl` in your lab07 direcotry to build a project for symbiflow.

# Dr. Nelson's notes

## Changes Made to main branch to get it to work


1. lab07/multicycle_iosystem.sv
    - Define value for parameter TEXT_MEMORY_FILENAME at the top level
        - I asked and there is a way in the compile script to supply it if there is no default but the answer (and question) seem to be gone.  But, there is a way.

2. resources/iosystem/cores/vga/bramMacro.v
    - Changed some signals to be of type reg:   
        a_dout, b_dout, a_dout_i, b_dout_i
    - Made BRAM behavioral since RAMB36E1 doesn't work
        - Issue #262
        - ??? Remove INJECTDBITERR to test

3. resources/iosystem/io_clocks.sv
    - Combined 2 MMCM's into 1
        - Issue #268

4. resources/iosystem/iosystem.sv
    - Just DEBUG stuff
        - Added pc as in input, added counter, used 2-button combos to display on 7 segment (debug stuff)

5. resources/iosystem/iosystem.xdc
    - Removed extra stuff on clock definition line
        - Fixed some time ago

6. resources/iosystem/riscv_mem.sv
    - Moved all parameters up to be in module defn since it doesn't like old style parameters when passed in  
        - Issue #266
    - Don't initialize inst memory with NOP before $readmemh()
        - Issue #281
    - Rewrote instruction memory since doesn't get inferred
        - Issue #277
