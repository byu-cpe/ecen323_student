# Create project, specify part, and update project settings
create_project -force final_io ./proj
set_property "part" "xc7a35tcpg236-1" [get_projects [current_project]]
source ../resources/new_project_settings.tcl
# Add the top-level I/O system and constraints file (provided in the lab)
add_files riscv_io_final.sv
add_files -fileset constrs_1 ../resources/iosystem/iosystem.xdc
# Add files from your previous labs and set the include directories
add_files ../lab11/riscv_final.sv
add_files ../lab03/regfile.sv ../lab02/alu.sv ../lab02/riscv_alu_constants.sv
set_property include_dirs {../lab02 ../include} [current_fileset]
# Add the files associated with the top-level I/O system
add_files ../resources/iosystem/iosystem.sv
add_files ../resources/iosystem/io_clocks.sv
add_files ../resources/iosystem/riscv_mem.sv
add_files ../resources/iosystem/cores/SevenSegmentControl4.sv
add_files ../resources/iosystem/cores/debounce.sv
add_files ../resources/iosystem/cores/rx.sv
add_files ../resources/iosystem/cores/tx.sv
add_files ../resources/iosystem/cores/vga/vga_ctl3.sv
add_files ../resources/iosystem/cores/vga/charGen3.sv
add_files ../resources/iosystem/cores/vga/vga_timing.sv
add_files ../resources/iosystem/cores/vga/font_rom.sv
add_files ../resources/iosystem/cores/vga/charColorMem3BRAM.sv
add_files ../resources/iosystem/cores/vga/bramMacro.v
