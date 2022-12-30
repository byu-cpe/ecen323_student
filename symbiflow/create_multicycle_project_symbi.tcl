# Create lab 7 project based on Symbiflow files
#  This script assumes that you are running this in the lab07 directory
create_project -force multicycle_io_v ./proj_symbiflow
set_property "part" "xc7a35tcpg236-1" [get_projects [current_project]]
source ../resources/new_project_settings.tcl
# Add the top-level I/O system and constraints file (provided in the lab)
#add_files multicycle_iosystem.sv
add_files ../symbiflow/multicycle_iosystem.sv
#add_files -fileset constrs_1 ../resources/iosystem/iosystem.xdc
add_files -fileset constrs_1 ../symbiflow/iosystem.xdc
# Add files from your previous labs and set the include directories
add_files ../lab06/riscv_multicycle.sv
add_files ../lab05/riscv_simple_datapath.sv ../lab05/riscv_datapath_constants.sv
add_files ../lab03/regfile.sv ../lab02/alu.sv ../lab02/riscv_alu_constants.sv
set_property include_dirs {../lab02 ../lab05} [current_fileset]
# Add the files associated with the top-level I/O system
add_files ../resources/iosystem/iosystem.sv
# add_files ../resources/iosystem/io_clocks.sv
add_files ../symbiflow/io_clocks.sv
#add_files ../resources/iosystem/riscv_mem.sv
add_files ../symbiflow/riscv_mem.sv
add_files ../resources/iosystem/cores/SevenSegmentControl4.sv
add_files ../resources/iosystem/cores/debounce.sv
add_files ../resources/iosystem/cores/rx.sv
add_files ../resources/iosystem/cores/tx.sv
add_files ../resources/iosystem/cores/vga/vga_ctl3.sv
add_files ../resources/iosystem/cores/vga/charGen3.sv
add_files ../resources/iosystem/cores/vga/vga_timing.sv
add_files ../resources/iosystem/cores/vga/font_rom.sv
add_files ../resources/iosystem/cores/vga/charColorMem3BRAM.sv
# Add the memory file
add_files multicycle_iosystem_text.mem
# add_files ../resources/iosystem/cores/vga/bramMacro.v
add_files ../symbiflow/bramMacro.sv
