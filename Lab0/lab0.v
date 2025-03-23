/**
 * Nahum Markov - 592539150
 * Ely van Dijk - 561151156
 */
import os

// Entry point of the program
fn main() {
	// Ask the user for the folder path containing .vm files
	folder := os.input('Enter path to folder with .vm files: ').trim_space()
	if !os.exists(folder) || !os.is_dir(folder) {
		eprintln('Invalid folder path.')
		return
	}

	// Create the output file name using the folder name + ".asm"
	output_filename := folder.all_after_last(os.path_separator) + '.asm'
	mut output_file := os.create(os.join_path(folder, output_filename)) or {
		eprintln('Failed to create output file.')
		return
	}

	// List all files in the folder
	files := os.ls(folder) or { return }
	for file in files {
		if file.ends_with('.vm') {
			// For each .vm file, process it and write to output
			full_path := os.join_path(folder, file)
			process_vm_file(full_path, mut output_file)
			println('End of input file: ${file}')
		}
	}

	// Final message to confirm the output file is ready
	println('Output file is ready: ${output_filename}')
}

// Processes a single .vm file line by line
fn process_vm_file(path string, mut output_file os.File) {
	lines := os.read_lines(path) or { return }
	mut counter := 1 // Logical command counter for eq/gt/lt

	for line in lines {
		// Split each line into tokens by spaces
		tokens := line.split(' ').filter(it.len > 0)
		if tokens.len == 0 {
			continue // Skip empty lines
		}

		cmd := tokens[0] // First word is the VM command

		// Dispatch to the appropriate handler based on command
		match cmd {
			'add' {
				handle_add(mut output_file)
			}
			'sub' {
				handle_sub(mut output_file)
			}
			'neg' {
				handle_neg(mut output_file)
			}
			'eq' {
				counter = handle_eq(mut output_file, counter)
			}
			'gt' {
				counter = handle_gt(mut output_file, counter)
			}
			'lt' {
				counter = handle_lt(mut output_file, counter)
			}
			'push' {
				if tokens.len == 3 {
					// For push <segment> <index>
					segment := tokens[1]
					index := tokens[2].int()
					handle_push(mut output_file, segment, index)
				}
			}
			'pop' {
				if tokens.len == 3 {
					// For pop <segment> <index>
					segment := tokens[1]
					index := tokens[2].int()
					handle_pop(mut output_file, segment, index)
				}
			}
			else {} // Ignore unknown/unsupported commands
		}
	}
}

// Handles arithmetic command "add"
fn handle_add(mut f os.File) {
	f.writeln('command: add') or {}
}

// Handles arithmetic command "sub"
fn handle_sub(mut f os.File) {
	f.writeln('command: sub') or {}
}

// Handles arithmetic command "neg"
fn handle_neg(mut f os.File) {
	f.writeln('command: neg') or {}
}

// Handles logical command "eq" and updates the counter
fn handle_eq(mut f os.File, counter int) int {
	f.writeln('command: eq') or {}
	f.writeln('counter: ${counter}') or {}
	return counter + 1
}

// Handles logical command "gt" and updates the counter
fn handle_gt(mut f os.File, counter int) int {
	f.writeln('command: gt') or {}
	f.writeln('counter: ${counter}') or {}
	return counter + 1
}

// Handles logical command "lt" and updates the counter
fn handle_lt(mut f os.File, counter int) int {
	f.writeln('command: lt') or {}
	f.writeln('counter: ${counter}') or {}
	return counter + 1
}

// Handles memory access command "push <segment> <index>"
fn handle_push(mut f os.File, segment string, index int) {
	f.writeln('command: push segment: ${segment} index: ${index}') or {}
}

// Handles memory access command "pop <segment> <index>"
fn handle_pop(mut f os.File, segment string, index int) {
	f.writeln('command: pop segment: ${segment} index: ${index}') or {}
}
