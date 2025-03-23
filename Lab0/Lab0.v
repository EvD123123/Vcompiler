import os

// Write helper functions for each type of command
//
// handle_add Handles arithmetic command "add"
fn handle_add(mut f os.File) {
	f.writeln('command: add') or {}
}

// handle_sub Handles arithmetic command "sub"
fn handle_sub(mut f os.File) {
	f.writeln('command: sub') or {}
}

// handle_neg Handles arithmetic command "neg"
fn handle_neg(mut f os.File) {
	f.writeln('command: neg') or {}
}

// handle_eq Handles logical command "eq" and updates the counter
fn hande_eq(mut f os.File, counter int) int {
	f.writeln('command: eq') or {}
	f.writeln('counter: ${counter}') or {}
	return counter + 1
}

// handle_gt Handles logical command "gt" and updates the counter
fn handle_gt(mut f os.File, counter int) int {
	f.writeln('command: gt') or {}
	f.writeln('counter: ${counter}') or {}
	return counter + 1
}

// handle_lt Handles logical command "lt" and updates the counter
fn handle_lt(mut f os.File, counter int) int {
	f.writeln('command: lt') or {}
	f.writeln('counter: ${counter}') or {}
	return counter + 1
}

// handle_push Handles memory access command "push <segment> <index>"
fn handle_push(mut f os.File, segment string, index int) {
	f.writeln('command: push segment: ${segment} index: ${index}') or {}
}

// handle_pop Handles memory access command "pop <segment> <index>"
fn handle_pop(mut f os.File, segment string, index int) {
	f.writeln('command: pop segment: ${segment} index: ${index}') or {}
}

fn process_vm_file(vm_path string, mut file os.File) {
	vm_filename := os.file_name(vm_path).all_before_last('.vm')

	mut logical_command_count := 1

	// Open the .vm file for reading
	vm_content := os.read_lines(vm_path) or {
		println('Error: Unable to read ${vm_filename}.vm')
		return
	}

	// Read line by line
	for line in vm_content {
		clean_line := line.trim_space()
		if clean_line.len == 0 || clean_line.starts_with('//') {
			continue // Skip empty lines or comments
		}

		// Extract words from the line
		words := clean_line.split(' ')
		command := words[0]

		match command {
			'add' {
				handle_add(mut file)
			}
			'sub' {
				handle_sub(mut file)
			}
			'neg' {
				handle_neg(mut file)
			}
			'eq' {
				logical_command_count = hande_eq(mut file, logical_command_count)
			}
			'gt' {
				logical_command_count = handle_gt(mut file, logical_command_count)
			}
			'lt' {
				logical_command_count = handle_lt(mut file, logical_command_count)
			}
			'push' {
				if words.len == 3 {
					segment := words[1]
					index := words[2].int()
					handle_push(mut file, segment, index)
				}
			}
			'pop' {
				if words.len == 3 {
					segment := words[1]
					index := words[2].int()
					handle_pop(mut file, segment, index)
				}
			}
			else {
				println("Warning: Unknown command '${command}' in line: ${line}")
			}
		}
	}

	println('End of input file: ${vm_filename}')
}

fn main() {
	// Receive from user path to vm files
	folder_path := os.input('Enter the folder path: ').trim_space()

	if !os.is_dir(folder_path) {
		println('Error: The specified path is not a folder or does not exist.')
		return
	}

	// Create output file Lab0.asm and open it in write mode
	output_file := os.join_path(folder_path, 'Lab0')
	mut file := os.create(output_file) or {
		println('Error: Failed to open Lab0.asm for writing')
		return
	}
	defer { file.close() }

	// Traverse all .vm files, the number of files is known in advance (traversal order is irrelevant)
	// Get all .vm files in the folder
	files := os.ls(folder_path) or {
		println('Error: Unable to read folder contents')
		return
	}

	vm_files := files.filter(it.ends_with('.vm'))

	if vm_files.len == 0 {
		println('No .vm files found in the folder.')
		return
	}

	for vm_file in vm_files {
		vm_path := os.join_path(folder_path, vm_file)
		process_vm_file(vm_path, mut file)
	}
	println('Output file is ready: Lab0.asm')
}
