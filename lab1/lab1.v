module main

import os

// A simple parser that reads the input file line by line.
struct Parser {
mut:
	lines   []string
	current int
}

fn (mut p Parser) has_more() bool {
	return p.current < p.lines.len
}

fn (mut p Parser) advance() string {
	// Loop until we find a non-empty line (ignoring comments)
	for p.current < p.lines.len {
		mut line := p.lines[p.current].trim_space()
		p.current++
		if line == '' || line.starts_with('//') {
			continue
		}
		// Remove any trailing comment.
		if idx := line.index('//') {
			if idx > 0 {
				line = line[..idx].trim_space()
			}
		}
		if line.len > 0 {
			return line
		}
	}
	return ''
}

// CodeWriter accumulates output Hack assembly code. It also maintains a label counter
// for arithmetic commands (eq, gt, lt) that require unique labels and holds the file name (for static variables).
struct CodeWriter {
mut:
	label_counter int
	output        []string
	file_name     string
}

fn (mut cw CodeWriter) write_arithmetic(command string) {
	match command {
		'add' {
			cw.output << '@SP'
			cw.output << 'AM=M-1'
			cw.output << 'D=M'
			cw.output << 'A=A-1'
			cw.output << 'M=M+D'
		}
		'sub' {
			cw.output << '@SP'
			cw.output << 'AM=M-1'
			cw.output << 'D=M'
			cw.output << 'A=A-1'
			cw.output << 'M=M-D'
		}
		'neg' {
			cw.output << '@SP'
			cw.output << 'A=M-1'
			cw.output << 'M=-M'
		}
		'eq' {
			mut lt_true := 'EQ_TRUE' + cw.label_counter.str()
			mut lt_end := 'EQ_END' + cw.label_counter.str()
			cw.label_counter++
			cw.output << '@SP'
			cw.output << 'AM=M-1'
			cw.output << 'D=M'
			cw.output << 'A=A-1'
			cw.output << 'D=M-D'
			cw.output << '@' + lt_true
			cw.output << 'D;JEQ'
			cw.output << 'D=0'
			cw.output << '@' + lt_end
			cw.output << '0;JMP'
			cw.output << '(' + lt_true + ')'
			cw.output << 'D=-1'
			cw.output << '(' + lt_end + ')'
			cw.output << '@SP'
			cw.output << 'A=M-1'
			cw.output << 'M=D'
		}
		'gt' {
			mut lt_true := 'GT_TRUE' + cw.label_counter.str()
			mut lt_end := 'GT_END' + cw.label_counter.str()
			cw.label_counter++
			cw.output << '@SP'
			cw.output << 'AM=M-1'
			cw.output << 'D=M'
			cw.output << 'A=A-1'
			cw.output << 'D=M-D'
			cw.output << '@' + lt_true
			cw.output << 'D;JGT'
			cw.output << 'D=0'
			cw.output << '@' + lt_end
			cw.output << '0;JMP'
			cw.output << '(' + lt_true + ')'
			cw.output << 'D=-1'
			cw.output << '(' + lt_end + ')'
			cw.output << '@SP'
			cw.output << 'A=M-1'
			cw.output << 'M=D'
		}
		'lt' {
			mut lt_true := 'LT_TRUE' + cw.label_counter.str()
			mut lt_end := 'LT_END' + cw.label_counter.str()
			cw.label_counter++
			cw.output << '@SP'
			cw.output << 'AM=M-1'
			cw.output << 'D=M'
			cw.output << 'A=A-1'
			cw.output << 'D=M-D'
			cw.output << '@' + lt_true
			cw.output << 'D;JLT'
			cw.output << 'D=0'
			cw.output << '@' + lt_end
			cw.output << '0;JMP'
			cw.output << '(' + lt_true + ')'
			cw.output << 'D=-1'
			cw.output << '(' + lt_end + ')'
			cw.output << '@SP'
			cw.output << 'A=M-1'
			cw.output << 'M=D'
		}
		'and' {
			cw.output << '@SP'
			cw.output << 'AM=M-1'
			cw.output << 'D=M'
			cw.output << 'A=A-1'
			cw.output << 'M=M&D'
		}
		'or' {
			cw.output << '@SP'
			cw.output << 'AM=M-1'
			cw.output << 'D=M'
			cw.output << 'A=A-1'
			cw.output << 'M=M|D'
		}
		'not' {
			cw.output << '@SP'
			cw.output << 'A=M-1'
			cw.output << 'M=!M'
		}
		else {
			// Unrecognized arithmetic command; do nothing.
		}
	}
}

fn (mut cw CodeWriter) write_push_constant(value string) {
	cw.output << '@' + value
	cw.output << 'D=A'
	cw.output << '@SP'
	cw.output << 'A=M'
	cw.output << 'M=D'
	cw.output << '@SP'
	cw.output << 'M=M+1'
}

// write_push_pop handles push/pop commands for memory access.
// It supports constant, local, argument, this, that, pointer, temp, and static segments.
fn (mut cw CodeWriter) write_push_pop(cmd string, segment string, index string) {
	if cmd == 'push' {
		match segment {
			'constant' {
				cw.write_push_constant(index)
			}
			'local', 'argument', 'this', 'that' {
				seg_reg := match segment {
					'local' { 'LCL' }
					'argument' { 'ARG' }
					'this' { 'THIS' }
					'that' { 'THAT' }
					else { '' }
				}
				cw.output << '@' + index
				cw.output << 'D=A'
				cw.output << '@' + seg_reg
				cw.output << 'A=M+D'
				cw.output << 'D=M'
				cw.output << '@SP'
				cw.output << 'A=M'
				cw.output << 'M=D'
				cw.output << '@SP'
				cw.output << 'M=M+1'
			}
			'temp' {
				// Temp segment base is at RAM address 5.
				// Compute address = 5 + index.
				// In V, convert index string to int with index.int().
				mut temp_addr := 5 + index.int()
				cw.output << '@' + temp_addr.str()
				cw.output << 'D=M'
				cw.output << '@SP'
				cw.output << 'A=M'
				cw.output << 'M=D'
				cw.output << '@SP'
				cw.output << 'M=M+1'
			}
			'pointer' {
				// Pointer: index 0 -> THIS, index 1 -> THAT.
				mut seg := ''
				if index == '0' {
					seg = 'THIS'
				} else if index == '1' {
					seg = 'THAT'
				}
				cw.output << '@' + seg
				cw.output << 'D=M'
				cw.output << '@SP'
				cw.output << 'A=M'
				cw.output << 'M=D'
				cw.output << '@SP'
				cw.output << 'M=M+1'
			}
			'static' {
				// For static, use a symbol composed of the file name and index.
				cw.output << '@' + cw.file_name + '.' + index
				cw.output << 'D=M'
				cw.output << '@SP'
				cw.output << 'A=M'
				cw.output << 'M=D'
				cw.output << '@SP'
				cw.output << 'M=M+1'
			}
			else {
				// Unknown segment.
			}
		}
	} else if cmd == 'pop' {
		match segment {
			'local', 'argument', 'this', 'that' {
				seg_reg := match segment {
					'local' { 'LCL' }
					'argument' { 'ARG' }
					'this' { 'THIS' }
					'that' { 'THAT' }
					else { '' }
				}
				// Compute target address: base register + index, store in R13.
				cw.output << '@' + index
				cw.output << 'D=A'
				cw.output << '@' + seg_reg
				cw.output << 'D=M+D'
				cw.output << '@R13'
				cw.output << 'M=D'
				// Pop top of stack and store into address in R13.
				cw.output << '@SP'
				cw.output << 'AM=M-1'
				cw.output << 'D=M'
				cw.output << '@R13'
				cw.output << 'A=M'
				cw.output << 'M=D'
			}
			'temp' {
				mut temp_addr := 5 + index.int()
				cw.output << '@SP'
				cw.output << 'AM=M-1'
				cw.output << 'D=M'
				cw.output << '@' + temp_addr.str()
				cw.output << 'M=D'
			}
			'pointer' {
				mut seg := ''
				if index == '0' {
					seg = 'THIS'
				} else if index == '1' {
					seg = 'THAT'
				}
				cw.output << '@SP'
				cw.output << 'AM=M-1'
				cw.output << 'D=M'
				cw.output << '@' + seg
				cw.output << 'M=D'
			}
			'static' {
				cw.output << '@SP'
				cw.output << 'AM=M-1'
				cw.output << 'D=M'
				cw.output << '@' + cw.file_name + '.' + index
				cw.output << 'M=D'
			}
			else {
				// pop constant is invalid.
			}
		}
	}
}

fn main() {
	if os.args.len < 2 {
		println('Usage: vm_translator <inputfile.vm>')
		return
	}
	input_file := os.args[1]
	data := os.read_file(input_file) or {
		println('Error reading file: ${input_file}')
		return
	}

	lines := data.split_into_lines()
	mut parser := Parser{
		lines:   lines
		current: 0
	}
	mut code_writer := CodeWriter{
		label_counter: 0
		output:        []string{}
		file_name:     ''
	}

	// Determine the base file name (without extension) for static variables.
	mut base := os.file_name(input_file)
	ext := os.file_ext(base)
	if ext.len > 0 {
		base = base[..base.len - ext.len]
	}
	code_writer.file_name = base

	// Process each VM command in the file.
	for parser.has_more() {
		command := parser.advance()
		if command == '' {
			continue
		}
		parts := command.split(' ')
		// If the command is "push" or "pop", handle it with write_push_pop.
		if parts[0] == 'push' || parts[0] == 'pop' {
			// Expecting at least three parts: [cmd, segment, index]
			if parts.len >= 3 {
				code_writer.write_push_pop(parts[0], parts[1], parts[2])
			}
		} else {
			// Otherwise, assume an arithmetic/Boolean command.
			match parts[0] {
				'add', 'sub', 'neg', 'eq', 'gt', 'lt', 'and', 'or', 'not' {
					code_writer.write_arithmetic(parts[0])
				}
				else {
					// Ignore unhandled commands.
				}
			}
		}
	}

	// Write the output to an .asm file with the same base name as the input file.
	output_file := os.join_path(os.dir(input_file), base + '.asm')
	os.write_file(output_file, code_writer.output.join('\n')) or {
		println('Error writing to file: ${output_file}')
		return
	}
	println('Translation complete. Output written to ${output_file}')
}
