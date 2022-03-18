#####################################################################
#
# load_mem.tcl
#
#  Scripts for updating the internal BRAM memory with different types
#  of data.
#
# Version 1.7
#
#####################################################################

# write_bitstream -force ../../multicycle_io/template/multicycle_io/multicycle_io.runs/impl_1/riscv_io_system2.bit
# load_brams_interleaved_32hextext  [list instruction_reg_0 instruction_reg_1] ../../multicycle_io/solution/second_count_text.txt

# updatemem (command line, not vivado)
#
# generate_mem_files -force .
#  WARNING: [Memdata 28-176] There are no bmm files or elf files. Therefore Vivado could not produce any .mem files. Check the design for the existence of processors and associated elf files.
# write_bmm
#   write_bmm template.bmm
#   ERROR: [Memdata 28-96] Could not find a BMM_INFO_DESIGN property in the design. Could not generate the merged BMM file: c:/wirthlin/ee323/git/labs/iosystem/final_template/template.bmm
#   ERROR: [Common 17-69] Command failed: Failed to create a merged bmm file.
#  write_mem_inf
#   ERROR: [Common 17-69] Command failed: Failed to create the: c:/wirthlin/ee323/git/labs/iosystem/final_template/template.mm file. You will not be able to use the updatemem program to update the bitstream with new data.
#  write_sysdef
#
# https://www.xilinx.com/support/answers/63041.html

set version "1.7"
set debug 0

# Get a list of the BRAMs that are used in a design
proc get_brams {} {
    return [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ BMEM.bram.* }]
}

# creates an ordered list of strings from the BRAM init values with
# each word specified by the given word size (in bits). The word size
# should be a mulitple of 4 (i.e., one nibble from the string).
# 
# Example: getBRAMDataList instruction_reg_0 16
# (creates a list of the memory in 16-bit words from the INIT string)
proc getBRAMDataList { bram {wordSize 32} } {

	# Determine how many property strings the BRAM has
	set numStrings [ BRAM_property_size $bram]
	set numWords [ expr 256 / $wordSize ]
	set nibblesPerWord [expr $wordSize / 4]
	for {set i 0} {$i < $numStrings} {incr i} {
		set property_name INIT_[format %02X $i]
        set pString [get_property $property_name  [get_cells $bram] ]
		set propertyStringSize [string length $pString ]
		# The string has 256 bits or 64 characters. Iterate over substrings
        puts "$property_name"
		puts "$pString"
		for {set j 0} {$j < $numWords} { incr j} {
			# The first nibble is associated with the last character
			set firstNibble [expr $j * $nibblesPerWord ]
			set lastChar [expr $propertyStringSize - $firstNibble - 1]
			set firstChar [expr $lastChar - $nibblesPerWord + 1]
			set word [string range $pString $firstChar $lastChar ]
			#puts "$word"
			lappend subList $word
		}
	}
	return $subList
}

# Print instruction memory for a pair of interleved memories
# (default is "instruction_reg")
proc dumpMemory { {bramBaseName instruction_reg} { filehandle stdout } } {
	set bram0 [join [list $bramBaseName _0] ""]
	set bram1 [join [list $bramBaseName _1] ""]

	set bram0List [ getBRAMDataList $bram0 16 ]
	set bram1List [ getBRAMDataList $bram1 16 ]

	# Print a header
	puts $filehandle "// Data for memories: $bram0 and $bram1"
	for {set i 0} { $i < [llength $bram0List]} {incr i} {
		set lowWord [ lindex $bram0List $i ]
		set highWord [ lindex $bram1List $i ]
		puts $filehandle "$highWord$lowWord"
	}
}


# Loads the specified BRAM with the contents specified by the given
# filename. The file should have text HEX numbers (verilog memory file)
proc load_bram_32hextext {bram_cell_name filename} {
	# Get all the words in the file
	set word_array [parse_32bit_hex $filename]
	# Determine size of BRAM
	set num_init_strings [BRAM_property_size $bram_cell_name]
	# Create the property strings
	set data_strings [generate_ascii_string_256 $word_array $num_init_strings]
	# set the properties
	set_BRAM_INIT $data_strings $bram_cell_name
}

# Loads the specified BRAM with the contents specified by the given
# filename. Multiple BRAMs are used and each 
# 1 BRAM: no interleaving: each 32-bit data is entry in the one BRAM
# 2 BRAMs: 16-bit words interleaved in each BRAM
#
# bram_cells must be an array/list? of BRAMs that need to be loaded (1, 2, 4, ...)
#
# Example: >load_brams_interleaved_32hextext [list instruction_reg_0 instruction_reg_1] myfile_text.txt
#
proc load_brams_interleaved_32hextext {bram_cells filename} {
	global debug
	if {$debug > 0} { puts "load_brams_interleaved_32hextext $bram_cells $filename" }
	# Get all the words in the file
	set word_array [parse_32bit_hex $filename]

	set num_brams [llength $bram_cells]
	set interleave_word_size [expr 32 / $num_brams]
	#set mask [expr 0xffffffff >> $interleave_word_size]
	
	# Iterate over all of the BRAMs
	set pos 0
	foreach bram $bram_cells {
		puts "Processing BRAM '$bram' in position $pos"
		# Determine size of BRAM
		set num_init_strings [BRAM_property_size $bram]
		set bram_data  [extract_interleave_data $word_array $interleave_word_size $pos ]
		
		#set bram_data [extract_interleave_data $word_array $interleave_word_size $pos]
		
		# Create the property strings
		set data_strings [generate_ascii_string_256 $bram_data $num_init_strings]
		#puts "$data_strings"
		# set the properties
		set_BRAM_INIT $data_strings $bram
		incr pos
	}
	
}

# Loads the specified BRAM with the contents specified by the given
# filename. The file should have text binary numbers
proc load_bram_8bintext {bram_cell_name filename} {
	# Get all the bytes in the file
	set byte_array [parse_8bit_binary $filename]
	# Convert array of bytes to array of words
	set word_array [create_32bitarray_from_8bitarray $byte_array]
	# Determine size of BRAM
	set num_init_strings [BRAM_property_size $bram_cell_name]
	# Create the property strings
	set data_strings [generate_ascii_string_256 $word_array $num_init_strings]
	# set the properties
	set_BRAM_INIT $data_strings $bram_cell_name
}

# Loads the specified BRAM with the contents of a character
# map.
proc load_bram_textmap {bram_cell_name filename} {
	# Get all the bytes in the file
	set byte_array [parse_character_map $filename]
	# Convert array of bytes to array of words
	set word_array [create_32bitarray_from_8bitarray $byte_array]
	# Determine size of BRAM
	set num_init_strings [BRAM_property_size $bram_cell_name]
	# Create the property strings
	set data_strings [generate_ascii_string_256 $word_array $num_init_strings]
	# set the properties
	set_BRAM_INIT $data_strings $bram_cell_name
}


# Reads through an array of 32-bit words and extracts sub-sets of each word
# to create a new word of interleaved values. 
#
# word_array: the array of words to get interleaved data (array of 32-bit values)
# interleave_bits: number of bits of interleaved word (must be power of 2)
# interleave_position: slot number of interleaved bits (starting with 0)
proc extract_interleave_data {word_array interleave_bits interleave_position} {
	global debug
	if {$debug > 0} { puts "* extract_interleave_data $interleave_bits $interleave_position" }
	if {$debug > 0} { puts "$word_array" }
	# determine the number of interleave slots
	set interleave_slots [expr 32 / $interleave_bits]
	if {$debug > 0} { puts "interleave_slots $interleave_slots" }
	# Example: 8 interlave bits, interleave position 2:  
	#   (0xffffffff >> (32-8) = 0xff) << (8 * 2) = 0x00ff0000
	set mask [expr (0xffffffff >> (32- $interleave_bits)) << ($interleave_bits * $interleave_position)]
	if {$debug > 0} { puts "Mask=[format %08X $mask]" }
	
	# current interleave position in the word (will cycle between 0 and interleave_slots-1)
	set word_pos 0
	foreach word $word_array {
		if {$debug > 2} { puts "word= $word" }
		# extract interleave region
		set masked_word [expr $word & $mask]
		#puts "Masked Data [format %08X $masked_word]"
		# Shift the masked data down to 0
		set interleaved_data [expr $masked_word >> ($interleave_bits * $interleave_position) ]
		#puts "Word [format %08X $word], shifted data [format %08X $interleaved_data]"
		if {$word_pos == 0} {
			# Start over with a new word
			set build_word $interleaved_data
		} else {
			# insert interleaved word
			set build_word [expr $build_word | ($interleaved_data << ($word_pos * $interleave_bits)) ]
		}
		if {$word_pos == [expr $interleave_slots-1]} {
			# Save word and start over`
			set word_pos 0
			lappend new_word_array $build_word
        	#puts [set hex_value [format %08X $build_word] ]
		} else {
			incr word_pos
		}
	}
	# At the end of the list, add the last remaining word (if it didn't complete)
	if {$word_pos != 0} {
		lappend new_word_array $build_word
	}
	return $new_word_array
}

# Creates an array of words from a file with 32-bit hex values
proc parse_32bit_hex {file} {
	global debug
	if {$debug > 0 } { puts "* parse_32bit_hex $file" }

	# Read the file
    set a [open $file]
    set lines [split [read $a] "\n"]
    close $a;

	# Create an array of 32-bit text hex strings
	set word_array {}
    foreach line $lines {
		# Skip comment lines
		if {[regexp  {^(\s*)//.*$} $line]} {
			if {$debug > 1} { puts "comment line: $line"  }
			continue
		}
		# Filter text after the comments
		set filtered [regsub -all -line {^(.*)//.*$} $line {\1} ]
		# Remove leading white space?
		set hex_word [regsub -all -line {^[ \t\r]*(.*\S)?[ \t\r]*$} $filtered {\1}]
		if {$debug > 2} { puts "hex_word: $hex_word" }
		if {[string length $hex_word] > 0} {
			# Need to do a better job parsing line (make sure it is hex, remove early white space, etc.)
			# Make sure there are 8 digits, etc.
			set value [string range $hex_word 0 7]
			set bin_value [scan $value "%x"]
			#puts "$value - $bin_value"
			lappend word_array $bin_value
		}
    }
	return $word_array
}

# Creates an array of bytes (numberes from 0-255) 
# from a file with 8-bit binary values (text 1s and 0s)
proc parse_8bit_binary {file} {
    set a [open $file]
    set lines [split [read $a] "\n"]
    close $a;

	# Create an array of bytes
	set byte_list {}
    foreach line $lines {
		set filtered [regsub -all -line {^(.*)//.*$} $line {\1} ]
		set filtered [regsub -all -line {^[ \t\r]*(.*\S)?[ \t\r]*$} $filtered {\1}]
		if {[string length $filtered] > 0} {
			if {[regexp {\d\d\d\d\d\d\d\d} $filtered data]} {
				set num [binary_text_to_number $data]
				#puts "$data - $num"
				lappend byte_list $num
			}
		}
	}
	return $byte_list
}

# Creates an array of bytes from a character map.
proc parse_character_map {file} {
    set a [open $file]
    set lines [split [read $a] "\n"]
    close $a;

	# Create an array of bytes
	set byte_list {}
    foreach line $lines {
		puts $line
		# Process each line
		for { set i 0} { $i < [string length $line] && $i < 128 } { incr i} {
			set c [string index $line $i ]
			scan $c "%c" num 
			lappend byte_list $num
			# check to see if this is the last character in the line.
			# If so, pad with zeros so there is 128 bytes per line
			if {$i == [expr [string length $line] - 1]} {
				for {set j [expr $i+1]} { $j < 128} { incr j} {
					lappend byte_list 0
				}
			}
		}
	}
	return $byte_list
}

proc create_32bitarray_from_8bitarray byte_array {
	# Organize bytes as words
	set byte_index 0
	set word_list {}
	foreach byte $byte_array {
        if {$byte_index % 4 == 0} {
            set word $byte
			set byte_index 0
        } else {
            set word [expr $word + ($byte<<(8*$byte_index))]
        }
		#puts "[format %02X $byte]-[format %08X $word]"
        incr byte_index
        if {$byte_index % 4 == 0} {
			#puts "![format %08X $word]"
            lappend word_list $word
        }
		
	}
	return $word_list
}



# Takes an array of unsigned ints and builds an array of hex strings.
# 
# The INIT strings are 64 characters long: 256 bits, with each character a nibble. 
# The final string will also be 64 characters long and have zero padding
# if necessary. These strings are unsed for INIT properties on BRAMs.
# 
# The 'word_array' is an array of unsigned ints as long as necessary.
# Padding will be provided if the array is not long enough. The array
# would need to be 1024 long to fully fill the (32k) memory
#
# A "Require" parameter indicates how many strings are required.
# A 32 kbit BRAM has 2^15 bits or 128 strings (00-7f) so the default
# is 128. This parameter is used to pad the strinigs with zeros
# if the word_array does not contain sufficient data to fill the
# init strings.
proc generate_ascii_string_256 {word_array {require 128}} {
    set word_index 0
	set hex_strings {}

	# Create 256 bit hex string from array of 32 bit data
	foreach value $word_array {
		# convert to ascii hex
		#puts $value
        set hex_value [format %08X $value]
        if {$word_index % 8 == 0} {
            set string_256 $hex_value
        } else {
            set string_256 ${hex_value}${string_256}
        }
        incr word_index
        if {$word_index % 8 == 0} {
			#puts "!$string_256"
            lappend hex_strings $string_256
        }
	}
	
	# At this point, we may have a half finished string. Finish it up with zeros
    set zero_value [format %08X 0]	
	#set value "00000000"
	for {} {$word_index % 8 != 0} {} {
		set string_256 ${zero_value}${string_256}
        incr word_index
        if {$word_index % 8 == 0} {
            lappend hex_strings $string_256
			#puts "!$string_256"
        }
	}

	# add appending zero strings if needed
	if {$require > [llength $hex_strings]} {
        set empty_string [format %064X 0]
		for {set i [llength $hex_strings]} {$i < $require} {incr i} {
            lappend hex_strings $empty_string
		}
	}

	return $hex_strings
}

# Determines how many property strings this BRAM can support
proc BRAM_property_size {cell_name} {
	set REF_NAME [get_property REF_NAME [get_cells $cell_name]]
	puts "$cell_name $REF_NAME"
	if {[string equal $REF_NAME "RAMB18E1"]} {
		return 64
	} elseif {[string equal $REF_NAME "RAMB36E1"]} {
		return 128
	} else {
		return 0
	}
	
}

# Sets the data property strings for BRAMs
proc set_BRAM_INIT {ascii_string_256_array cell_name} {
	set init_index 0
	foreach init_string $ascii_string_256_array {
		set property_name INIT_[format %02X $init_index]
        incr init_index
        puts "$property_name=$init_string"
        set_property $property_name $init_string [get_cells $cell_name]
	}
}

# Sets the data property strings for BRAMs
proc set_BRAM_INITP {ascii_string_256_array cell_name} {
	set init_index 0
	foreach init_string $ascii_string_256_array {
		set property_name INITP_[format %02X $init_index]
        incr init_index
        puts "$property_name=$init_string"
        set_property $property_name $init_string [get_cells $cell_name]
	}
}

# Sets the data property strings for BRAMs
proc dump_BRAM_contents {cell_name} {
	set init_strings [BRAM_property_size $cell_name]
	for {set i 0} {$i < $init_strings} {incr i} {
		set property_name INIT_[format %02X $i]
		set property [get_property $property_name [get_cells $cell_name]]
		puts "$property_name $property"
	}
}

# Converts a binary number represented in text as a regular integer
# Assume input is string with just 1's and 0's
proc binary_text_to_number bintext {
	set num 0
	set multiplier 1
	set len [string length $bintext]
	#puts "# $bintext ($len)"
	for {set i 0} {$i < $len} {incr i} {
		set c_index [expr $len - $i - 1]
		set c [string index $bintext $c_index] 
		#puts "$c_index $c"
		if {$c == "1"} {
			set num [expr $num + $multiplier]
			#puts "  $i $multiplier"
		}
		set multiplier [expr $multiplier * 2]
	}
	return $num
}

proc write_bit {bitfile} {
    write_bitstream -force $bitfile
}

# ############################################################################
# deprecated
# ############################################################################
proc load_mem_32 {cell_name file} {
    set a [open $file]
    set lines [split [read $a] "\n"]
    close $a;                          # Saves a few bytes :-)

	# Create an array of 32-bit text hex strings
	set word_array {}
    foreach line $lines {
		# Remove comments
		set filtered [regsub -all -line {^(.*)//.*$} $line {\1} ]
		set filtered [regsub -all -line {^[ \t\r]*(.*\S)?[ \t\r]*$} $filtered {\1}]
		set line $filtered
		# Need to do a better job parsing line (make sure it is hex, remove early white space, etc.)
		# Make sure there are 8 digits, etc.
        set value [string range $line 0 7]
		lappend word_array $value
        # if {$word_index % 8 == 0} {
            # set input_word $value
        # } else {
            # set input_word ${value}${input_word}
        # }
        # incr word_index
        
        # if {$word_index % 8 == 0} {
            # set index [format %02X $init_index]
            # puts $index
            # incr init_index
            # puts $input_word
            # set_property INIT_$index $input_word [get_cells $cell_name]
        # }
    }
	puts $word_array

    set word_index 0
	set properties {}
	# Create property strings from those words that were parsed
	foreach value $word_array {
        if {$word_index % 8 == 0} {
            set property $value
        } else {
            set property ${value}${property}
        }
        incr word_index
        if {$word_index % 8 == 0} {
            lappend properties $property
        }
	}
	# flush out the last property string with zeros if it wasn't finished
	set value "00000000"
	for {} {$word_index % 8 != 0} {
		set property ${value}${property}
        incr word_index
        if {$word_index % 8 == 0} {
            lappend properties $property
        }
	}
	
	# Add all zeros lines
	
    for {} {$word_index < 1024} {} {
       set value "00000000"
        if {$word_index % 8 == 0} {
            set input_word $value
        } else {
            set input_word ${value}${input_word}
        }
        incr word_index
        if {$word_index % 8 == 0} {
            set index [format %02X $init_index]
            puts $index
            incr init_index
            puts $input_word
            set_property INIT_$index $input_word [get_cells $cell_name]
        }
    }

    for {} {$word_index < 1024} {} {
       set value "00000000"
        if {$word_index % 8 == 0} {
            set input_word $value
        } else {
            set input_word ${value}${input_word}
        }
        incr word_index
        if {$word_index % 8 == 0} {
            set index [format %02X $init_index]
            puts $index
            incr init_index
            puts $input_word
            set_property INIT_$index $input_word [get_cells $cell_name]
        }
    }
}

# This procedure is for updating the character ROM
# Each INIT sttring is 256 bits (32 bytes). Each character is 16x8 bits (128 bits)
#  (2 characters per INIT string)
# The INIT string starts out by putting bytes from right to left
# 
proc load_mem_font {cell_name file} {
    set a [open $file]
    set lines [split [read $a] "\n"]
    close $a;                          # Saves a few bytes :-)
    set byte_index 0
    set init_index 0
	set debug 1

	#set byte_list {}
	# Parse the lines and convert into hex bytes
    foreach line $lines {
		# Filter out all text after a comment
		#set filtered [regsub -all -line {^(.*)//.*$} $line {\1} ]
		#puts "before:$line"
		#set filtered [regsub -all -line {^(.*)//} $line {\1} ]
		set replacement ""
		regsub -all -line "//.*$" $line ${replacement} filtered
		#puts "after:$filtered"
		# Get rid of white space before and after the actual text
		set filtered [regsub -all -line {^[ \t\r]*(.*\S)?[ \t\r]*$} $filtered {\1}]
		if {[string length $filtered] > 0} {
			#if {$debug > 0} { puts "$line - $filtered" }
			if {[regexp {\d\d\d\d\d\d\d\d} $filtered data]} {
				set nible2 [string range $data 0 3 ]
				set nible1 [string range $data 4 7 ]
				set hex2 [bin2hex_t $nible2]
				set hex1 [bin2hex_t $nible1]
				#puts "$filtered $data $nible2 $nible1 $hex2 $hex1"
				set byte_val $hex2$hex1
				#puts "$data $hex2 $hex1 $byte_val"
				#lappend byte_list $byte_val
				# Filter comment lines
				#puts "Data"
				
				# Prepare INIT string. There are 
				if {$byte_index %32 == 0} {
					set input_word $byte_val
				} else {
					set input_word ${byte_val}${input_word}
				}
				incr byte_index
        
				if {$byte_index % 32 == 0} {
					set index [format %02X $init_index]
					incr init_index
					puts "$index=$input_word"
					set_property INIT_$index $input_word [get_cells $cell_name]
				}				
			}
		} else {
			if {$debug > 0} { puts "skipped line $line" }
		}
    }
}

proc bin2hex_t bin {
    array set t {
	0000 0 0001 1 0010 2 0011 3 0100 4
	0101 5 0110 6 0111 7 1000 8 1001 9
	1010 a 1011 b 1100 c 1101 d 1110 e 1111 f
    }
	return $t($bin)
}

proc bin2hex bin {
    array set t {
	0000 0 0001 1 0010 2 0011 3 0100 4
	0101 5 0110 6 0111 7 1000 8 1001 9
	1010 10 1011 11 1100 12 1101 13 1110 14 1111 15
    }
	return $t($bin)
}

proc load_brams_dict_32hextext { bramList netBaseName filename} {

	set bramDict [findDataPorts $bramList $netBaseName]

	# ASSUME we are broken up into two BRAMS
	global debug
	if {$debug > 0} { puts "load_brams_dict_32hextext $dict $filename" }
	# Get all the words in the file
	set word_array [parse_32bit_hex $filename]
	set len [llength $word_array]
	puts "File $filename is $len in size"

	# Create two lists for each bram. One is 16 bits for data and the other is 2 bits for parity
	set list16_0 [list]
	set list16_1 [list]
	set list2p_0 [list]
	set list2p_1 [list]
	# Initialize lists to zero and make the correct size
	foreach word $word_array {
		lappend list16_0 0
		lappend list16_1 0
		lappend list2p_0 0
		lappend list2p_1 0
	}
	# Iterate over every bit
	for {set i 0} {$i < 32} {incr i} {
		if {$debug > 2} { puts "bit= $i" }
		set bitLoc [dict get $bramDict $i]
		puts "Bit $i: $bitLoc"
		# Figure out which BRAM to load (look at last character of BRAM name)
		set bram [lindex $bitLoc 0]
		puts "BRAM=$bram"
		if { [string index $bram [expr [string length $bram] - 1]] == "0" } {
			set lowBRAM 1
			puts "lowBRAM"
			set bram0_name $bram
		} else {
			set lowBRAM 0
			puts "highBRAM"
			set bram1_name $bram
		}
		# Split port into index and name
		set mem_pin [lindex $bitLoc 1]
		set match [regexp -all -line  {^.*/(.*\S)\[(\d+)\]$} $mem_pin fullmatch portname index]
		if { $match } {
			puts "D: $portname $index"
			if { $portname == "DOADO" } {
				set dataBit 1
			} else {
				set dataBit 0
			}
		} else {
			puts "WARNING: NO match for $mem_pin"
		}

		for {set j 0} {$j < [llength $word_array] } {incr j} {
			set word [lindex $word_array $j]
			set fword [format %08X $word]
			set bit [expr (($word & (1 << $i)) >> $i) ]
			if {$word != 0} {
				puts "  $j: Word: $fword Bit: $bit"
			}
			if {$bit} {
				set bit [expr $bit << $index]
				puts "new bit:$bit"
				if {$lowBRAM} {
					if {$dataBit} {
						lset list16_0 $j [expr [lindex $list16_0 $j] | $bit]
					} else {						
						lset list2p_0 $j [expr [lindex $list2p_0 $j] | $bit]
					}
				} else {
					if {$dataBit} {
						lset list16_1 $j [expr [lindex $list16_1 $j] | $bit]
					} else {						
						lset list2p_1 $j [expr [lindex $list2p_1 $j] | $bit]
					}
				}				
			}
		}
	}
	# Print all the data words
	for {set j 0} {$j < [llength $word_array] } {incr j} {
		set word [lindex $word_array $j]
		if {$word != 0} {
			set l16_0 [lindex $list16_0 $j]
			set l16_1 [lindex $list16_1 $j]
			set l2p_0 [lindex $list2p_0 $j]
			set l2p_1 [lindex $list2p_1 $j]
			puts "$j [format %08X $word] [format %08X $l16_0] [format %08X $l16_1] $l2p_0 $l2p_1"
		}
	}
	# Prepare 32-bit arrays from the lists of words from the data array
	set i 0
	set a0 [list]
	set a1 [list]
	for {set j 0} {$j < [llength $word_array] } {incr j 2} {
		set l0_0 [expr [lindex $list16_0 $j]]
		set l1_0 [expr [lindex $list16_1 $j]]
		set jp [expr $j + 1]
		if { $jp < [llength $word_array] } {
			set l0_1 [expr [lindex $list16_0 $jp]]
			set l1_1 [expr [lindex $list16_1 $jp]]
		} else {
			set l0_1 0
			set l1_1 0
		}
		set l0 [expr $l0_0 | ($l0_1 << 16)]
		set l1 [expr $l1_0 | ($l1_1 << 16)]
		#puts "$l0 $l1"
		lappend a0 $l0
		lappend a1 $l1
	}
	set b0strings [generate_ascii_string_256 $a0]
	set b1strings [generate_ascii_string_256 $a1]
	set_BRAM_INIT $b0strings $bram0_name
	set_BRAM_INIT $b1strings $bram1_name

	# Prepare 32-bit arrays for the parity bits. Each BRAM has 64x4x16 = 4096 parity bits
	# 1024 x 4
	# 
	# Content Initialization - INITP_xx
	# INITP_xx attributes define the initial contents of the memory cells corresponding to
	# DIP/DOP buses (parity bits). By default these memory cells are also initialized to all zeros.
	# The initialization attributes represent the memory contents of the parity bits. The eight
	# initialization attributes are INITP_00 through INITP_07 for the RAMB18E1. The
	# 16 initialization attributes are INITP_00 through INITP_0F for the RAMB36E1. Each
	# INITP_xx is a 64-digit hex-encoded bit vector with a regular INIT_xx attribute behavior.
	# The same formula can be used to calculate the bit positions initialized by a particular
	# INITP_xx attribute.
	set i 0
	set a0 [list]
	set a1 [list]
	for {set j 0} {$j < [llength $word_array] } {incr j} {
		if {[expr $j % 16 == 0]} {
			set p0 0
			set p1 0
		}
		set tp0 [expr [lindex $list2p_0 $j]]
		set tp1 [expr [lindex $list2p_1 $j]]
		set p0 [expr $p0 | ($tp0 << ($j % 16)*2) ]
		set p1 [expr $p1 | ($tp1 << ($j % 16)*2) ]
		if {[expr $j % 16 == 15]} {
			lappend a0 $p0
			lappend a1 $p1
		}
	}
	# Add the last set if it didn't end on a add to list
	# (j got incremented at the end. check the previous j for not being the end of a word)
	if {[expr ($j-1) % 16 != 15]} {
		lappend a0 $p0
		lappend a1 $p1
	}
	puts "a0 strings [llength $a0] [llength $word_array] $j"
	set b0pstrings [generate_ascii_string_256 $a0 16]
	set b1pstrings [generate_ascii_string_256 $a1 16]
	puts "p strings [llength $b0pstrings]"
	set_BRAM_INITP $b0pstrings $bram0_name
	set_BRAM_INITP $b1pstrings $bram1_name

	# Now update the init strings
}

# findDataPorts [list data_memory_reg_0 data_memory_reg_1 ] data_memory_read_wb
proc findDataPorts { bramList netBaseName } {
	set debug 1
	# iterate over the brams
	#   vga/charGen/charmem/data_write_value[28]
	foreach bram $bramList {
		#set bram [lindex $bramList 0]
		# vga/charGen/charmem/char_ram_reg_0
		puts "BRAM $bram"
		# iterate over all of the ports of the bram
		set pins [get_pins -of_objects [get_cells $bram]]
		foreach pin $pins {
			set net [get_nets -quiet -of_objects $pin]
			#vga/charGen/charmem/char_ram_reg_1/DIADI[3]
			#get_nets  -of  [get_pins vga/charGen/charmem/char_ram_reg_1/DIADI[3] ]
			if {$net != ""} {
				#if { $debug} { puts "PIN $pin $net" }
				# Strip off any indexing part of the string
				set match [regexp -all -line  {^(.*\S)\[(\d+)\]$} $net fullmatch base index]
				if { $match } {
					if { [string equal $base $netBaseName] } {
						# vga/charGen/charmem/char_data_to_write[12]
						puts " Pin $pin"
						puts "  Net=$net"
						puts "   Base = $base; Index = $index"
						# See if the net matches the netBaseName
						set item [ list $bram $pin ]
						puts "    $index - $bram:$pin"
	#					  Key: bit number, value: list (BRAM/PIN)
						dict set bramDict $index $item
					}
				}
			}
		}
	}
	# Iterate through dictionary
	set maxIndex -1
	foreach key [dict keys $bramDict] {
		set value [dict get $bramDict $key]
		puts "$key - $value"
		if {$key > $maxIndex} {
			set maxIndex $key
		}
	}
	puts "max index=$maxIndex"
	# Sort
	set dictLength [dict size $bramDict]
	for { set i 0 } {$i < [expr $maxIndex + 1] } { incr i } {
		set value [dict get $bramDict $i]
		puts "$i-$value"
	}
	return $bramDict
}

# Find the bram memory that includes the base_name. This is used to find memories
# whose hierarchy may not match what is expected
proc findMemoryWithBase { base_name} {
	#puts "Finding $base_name"
	# Get a list of all of the BRAMs
	set bramList [get_brams]
	# Iterate over all of the BRAMs to see if a match can be found
	foreach bram $bramList {
		#puts "BRAM $bram"
		if {[string first $base_name $bram] != -1} {
			#puts "Match with $base_name"
			return $bram
		}
	}
	return "None"
}

proc updateRiscvMemories { textFileName dataFileName bitstreamName { checkpointfilename ""}} {
	# Determine the names of the instruction memory
	set inst_0 [findMemoryWithBase "instruction_reg_0"]
	set inst_1 [findMemoryWithBase "instruction_reg_1"]
	set data_0 [findMemoryWithBase "data_memory_reg_0"]
	set data_1 [findMemoryWithBase "data_memory_reg_1"]
	puts "Instruction memories: $inst_0 $inst_1"
	puts "Data memories: $data_0 $data_1"
	if {[string equal "None" $inst_0] || [string equal "None" $inst_1] ||
		[string equal "None" $data_0] || [string equal "None" $data_1]} {
		puts "Cannot find instruction memory"
		return
	}
	# Load the instruction memories
	load_brams_interleaved_32hextext [list $inst_0 $inst_1] $textFileName
	# Load the .data file
	load_brams_interleaved_32hextext [list $data_0 $data_1] $dataFileName
	# Write the bitfile
	write_bitstream -force $bitstreamName
	# See if there is a checkpoint write command
	if {![string equal $checkpointfilename ""]} {
		puts "Generating new checkpoint file"
		write_checkpoint $checkpointfilename -force
	}
}


# Memory names
#iosystem/vga/charGen/charmem/BRAM_inst_0/bram
#iosystem/vga/charGen/charmem/BRAM_inst_1/bram 
#iosystem/vga/charGen/charmem/BRAM_inst_2/bram 
#iosystem/vga/charGen/charmem/BRAM_inst_3/bram 
#iosystem/vga/charGen/fontrom/addr_reg_reg 
#mem/data_memory_reg_0 
#mem/data_memory_reg_1
#mem/instruction_reg_0 
#mem/instruction_reg_1
set inst_0 mem/instruction_reg_0
set inst_1 mem/instruction_reg_1
set data_0 mem/data_memory_reg_0
set data_1 mem/data_memory_reg_1

# Process the tcl arguments
#  dumpMem <checkpoint file> <output file>
#  updateMem <checkpoint file> <.text file> <.data file> <bitstream file>
#
#  Commands for updating the character memory and font ROM
if { [llength $argv] > 0 } {
	# copy command name
	set command [lindex $argv 0]

	# Open checkpoint file (must have check point file as second argument)
	if {[llength $argv] > 1} {
		set checkpointFilename [lindex $argv 1]
		open_checkpoint $checkpointFilename

		if {[string equal $command "dumpMem"]} {
			puts "Executing 'dumpMem' command"
			# Output file for dump
			if {[llength $argv] > 2} {
				set outputFilename [lindex $argv 2]
				set filehandle [open $outputFilename w]
			} else {
				set filehandle stdout
			}
			dumpMemory instruction_reg $filehandle
			dumpMemory data_memory_reg $filehandle
			if {[llength $argv] > 2} {
				close $filehandle
			}
		} elseif {[string equal $command "updateMem"]} {
			#  updateMem <cheeckpoint> <.text file> <.data file> <bitstream file>
			puts "Executing 'updateMem' command"
			if {[llength $argv] < 5} {
				puts "Missing arguments: updateMem <checkpoint file> <.text file> <.data file> <bitstream file> \[optional .dcp file\]"
			} else {
				# Extract parameters
				set textFileName [lindex $argv 2]
				set dataFileName [lindex $argv 3]
				set bitstreamName [lindex $argv 4]
				if {[llength $argv] >= 6} {
					set checkpointname [lindex $argv 5]
				} else {
					set checkpointname ""
				}
				updateRiscvMemories $textFileName $dataFileName $bitstreamName $checkpointname
			}
		} elseif {[string equal $command "updateData"]} {
			puts "Executing 'updateData' command"
			if {[llength $argv] < 4} {
				puts "Missing arguments: updateData <checkpoint file> <.data file> <bitstream file> \[optional .dcp file\]"
			} else {
				# Load the .data file
				set dataFileName [lindex $argv 2]
				load_brams_dict_32hextext [list data_memory_reg_0 data_memory_reg_1 ] data_memory_read_wb $dataFileName
				# Write the bitfile
				set bitstreamName [lindex $argv 3]
				write_bitstream -force $bitstreamName
				# See if there is a checkpoint write command
				if {[llength $argv] >= 5} {
					puts "Generating new checkpoint file"
					set bitstreamName [lindex $argv 4]
					write_checkpoint $bitstreamName -force
				}
			}
		} elseif {[string equal $command "updateFont"]} {
#vivado -mode batch -source ../../project/solution/load_mem.tcl -tclargs updateFont ./final.dcp ../../project/solution/font_mem_mod.txt font.bit font.dcp			puts "Executing 'updateFont' command"
			if {[llength $argv] < 4} {
				puts "Missing arguments:"
			} else {
				# Load the .text file
				set textFileName [lindex $argv 2]
				#set bram vga/charGen/fontrom/addr_reg_reg
				set bram iosystem/vga/charGen/fontrom/addr_reg_reg
				load_mem_font $bram $textFileName
				# Write the bitfile
				set bitstreamName [lindex $argv 3]
				write_bitstream -force $bitstreamName
				# See if there is a checkpoint write command
				if {[llength $argv] >= 5} {
					puts "Generating new checkpoint file"
					set checkpointName [lindex $argv 4]
					write_checkpoint $checkpointName -force
				}
			}
		} elseif {[string equal $command "updateBackground"]} {
#vivado -mode batch -source ../../project/solution/load_mem.tcl -tclargs updateFont ./final.dcp ../../project/solution/font_mem_mod.txt font.bit font.dcp			puts "Executing 'updateFont' command"
			puts "Executing 'updateBackground' command"
			if {[llength $argv] < 4} {
				puts "Missing arguments:"
			} else {
				# Load the .text file
				set textFileName [lindex $argv 2]
				# Set background vga values
				set bram0 iosystem/vga/charGen/charmem/BRAM_inst_0/bram
				set bram1 iosystem/vga/charGen/charmem/BRAM_inst_1/bram
				set bram2 iosystem/vga/charGen/charmem/BRAM_inst_2/bram
				set bram3 iosystem/vga/charGen/charmem/BRAM_inst_3/bram
				set bramList [ list $bram0 $bram1 $bram2 $bram3 ]

				# Load memories
				load_brams_interleaved_32hextext  $bramList $textFileName

				# Write the bitfile
				set bitstreamName [lindex $argv 3]
				write_bitstream -force $bitstreamName
				# See if there is a checkpoint write command
				if {[llength $argv] >= 5} {
					puts "Generating new checkpoint file"
					set checkpointName [lindex $argv 4]
					write_checkpoint $checkpointName -force
				}
			}
		} else {
			puts "Unknown command: $command"
		}
	} else {
		puts "Missing Checkpoint file"
	}

} else {
	# No commandline arguments. Determine whether a project is open
	set a [current_project -quiet]
	if { [expr { $a == "" } ] } {
		# No current project. Missing command line options
		puts $a
		puts "Missing Command Name. Options:"
		puts " dumpMem <checkpoint file> \[output file\]"
		puts " updateMem <checkpoint file> <.text file> <.data file> <bitstream file> \[Optional .dcp file\]"
		puts " updateData <checkpoint file> <.data file> <bitstream file> \[Optional .dcp file\]"
		puts " updateFont <checkpoint file> <font file> <bitfile> \[output checkpoint file\]"
		puts " updateBackground <checkpoint file> <background file> <bitfile>"
	} else {
		puts "Script loaded with current project $a"
	}


}
