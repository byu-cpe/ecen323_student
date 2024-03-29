# Create project, specify part, and update project settings
create_project -force forwarding_io ./proj
set_property "part" "xc7a35tcpg236-1" [get_projects [current_project]]
source ../resources/new_project_settings.tcl
# Add the top-level I/O system and constraints file (provided in the lab)
add_files forwarding_iosystem.sv
add_files -fileset constrs_1 ../resources/iosystem/iosystem.xdc
# Add files from your previous labs and set the include directories
add_files ../lab09/riscv_forwarding_pipeline.sv
add_files ../lab03/regfile.sv ../lab02/alu.sv ../lab02/riscv_alu_constants.sv
set_property include_dirs {../include} [current_fileset]
# Add the files associated with the top-level I/O system
add_files ../resources/iosystem/iosystem.sv
add_files ../resources/iosystem/io_clocks.sv
add_files ../resources/iosystem/riscv_mem.sv
add_files ../resources/iosystem/cores/SevenSegmentControl4.sv
add_files ../resources/iosystem/cores/debounce.sv
add_files ../resources/iosystem/cores/rx.sv
add_files ../resources/iosystem/cores/tx.sv
add_files ../resources/iosystem/cores/vga/vga_ctl3.vhd
add_files ../resources/iosystem/cores/vga/charGen3.vhd
add_files ../resources/iosystem/cores/vga/vga_timing.vhd
add_files ../resources/iosystem/cores/vga/list_ch13_01_font_rom.vhd
add_files ../resources/iosystem/cores/vga/charColorMem3BRAM.vhd
add_files ../resources/iosystem/cores/vga/bramMacro.v
