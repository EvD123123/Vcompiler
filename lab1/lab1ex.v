/**
 * Nahum Markov - 592539150
 * Ely van Dijk - 561151156
 */
/// This program reads a .vm file containing VM commands and translates it into a
/// .asm file containing Hack assembly instructions according to the VM specification.
/// Usage: v run lab1.v <input.vm>

module main

import os

// -------- ENUM + STRUCT DEFINITIONS --------

/// Enumeration of all supported VM command types.
pub enum CmdType {
	add   ///< Arithmetic add
	sub   ///< Arithmetic subtract
	neg   ///< Arithmetic negation
	eq    ///< Equality comparison
	gt    ///< Greater-than comparison
	lt    ///< Less-than comparison
	and   ///< Bitwise AND
	or    ///< Bitwise OR
	or2   ///< Bitwise OR then negation (new command or#2)  // ← new---------------------------------------------------------------------------------------------------------------
	not   ///< Bitwise NOT
	push  ///< Push value onto stack
	pop   ///< Pop value from stack
}

/// Represents a single parsed VM command.
///
/// Fields:
/// - typ: The command type
/// - segment: Memory segment (for push/pop)
/// - index: Index within the segment (for push/pop)
pub struct VMCommand {
	pub:
	typ     CmdType
	segment string
	index   int
}

/// Accumulates assembly output and tracks state for writing code.
///
/// Fields:
/// - out: Generated assembly lines
/// - label_counter: Counter for generating unique labels
/// - file_name: Base name of the input file (for static variables)
pub struct CodeWriter {
	pub mut:
	out           []string
	label_counter int
	file_name     string
}

// -------- PARSER --------

/// Parses a single line of VM code into a VMCommand.
///
/// Returns none for blank lines or comments.
pub fn parse_line(line string) ?VMCommand {
	// Trim whitespace and ignore empty/comment lines
	text := line.trim_space()
	if text == '' || text.starts_with('//') {
		return none
	}
	mut clean := text
	// Remove inline comments
	if idx := clean.index('//') {
		if idx > 0 {
			clean = clean[..idx].trim_space()
		} else {
			return none
		}
	}
	// Split into components
	parts := clean.fields()
	cmd_str := parts[0]
	// Map string to command type
	cmd_type := match cmd_str {
		'add'   { CmdType.add }
		'sub'   { CmdType.sub }
		'neg'   { CmdType.neg }
		'eq'    { CmdType.eq }
		'gt'    { CmdType.gt }
		'lt'    { CmdType.lt }
		'and'   { CmdType.and }
		'or#2'  { CmdType.or2 }  // ← new---------------------------------------------------------------------------------------------------------------
		'or'    { CmdType.or }
		'not'   { CmdType.not }
		'push'  { CmdType.push }
		'pop'   { CmdType.pop }
		else    { return none }
	}
	// For push/pop commands, parse segment and index
	if cmd_type in [.push, .pop] {
		if parts.len < 3 {
			return none
		}
		idx := parts[2].int()
		return VMCommand{
			typ:     cmd_type
			segment: parts[1]
			index:   idx
		}
	}
	return VMCommand{
		typ: cmd_type
	}
}

// -------- CODE WRITER UTILITIES --------

/// Appends one or more lines to the output buffer.
pub fn (mut cw CodeWriter) emit(lines ...string) {
	cw.out << lines
}

/// Writes assembly code for arithmetic and logical commands.
pub fn (mut cw CodeWriter) write_arithmetic(cmd VMCommand) {
	match cmd.typ {
		.add {
			cw.emit('@SP', 'AM=M-1', 'D=M', 'A=A-1', 'M=M+D')
		}
		.sub {
			cw.emit('@SP', 'AM=M-1', 'D=M', 'A=A-1', 'M=M-D')
		}
		.neg {
			cw.emit('@SP', 'A=M-1', 'M=-M')
		}
		.eq, .gt, .lt {
			// Generate unique labels for comparisons
			label := match cmd.typ {
				.eq { 'EQ' }
				.gt { 'GT' }
				.lt { 'LT' }
				else { 'CMP' }
			}
			true_label := '${label}_TRUE${cw.label_counter}'
			end_label := '${label}_END${cw.label_counter}'
			jump := match cmd.typ {
				.eq { 'JEQ' }
				.gt { 'JGT' }
				.lt { 'JLT' }
				else { '' }
			}
			cw.label_counter++
			cw.emit(
				'@SP', 'AM=M-1', 'D=M', 'A=A-1', 'D=M-D',
				'@${true_label}', 'D;${jump}',
				'D=0', '@${end_label}', '0;JMP',
				'(${true_label})', 'D=-1',
				'(${end_label})', '@SP',
				'A=M-1', 'M=D',
			)
		}
		.and {
			cw.emit('@SP', 'AM=M-1', 'D=M', 'A=A-1', 'M=M&D')
		}
		.or {
			cw.emit('@SP', 'AM=M-1', 'D=M', 'A=A-1', 'M=M|D')
		}
		.or2 {  // ← new---------------------------------------------------------------------------------------------------------------
		// Compute neg(x OR y):
			cw.emit(
				'@SP',      // SP--
				'AM=M-1',
				'D=M',      // D = y
				'A=A-1',    // address of x
				'D=M|D',    // D = x OR y
				'D=-D',     // D = - (x OR y)
				'@SP',
				'A=M-1',    // back to top-of-stack
				'M=D',      // *SP-1 = D
			)
		}
		.not {
			cw.emit('@SP', 'A=M-1', 'M=!M')
		}
		else {}
	}
}

/// Writes assembly code for push and pop commands.
pub fn (mut cw CodeWriter) write_push_pop(cmd VMCommand) {
	if cmd.typ == .push {
		match cmd.segment {
			'constant' {
				cw.emit('@${cmd.index}', 'D=A', '@SP', 'A=M', 'M=D', '@SP', 'M=M+1')
			}
			'local', 'argument', 'this', 'that' {
				seg := match cmd.segment {
					'local'    { 'LCL' }
					'argument' { 'ARG' }
					'this'     { 'THIS' }
					'that'     { 'THAT' }
					else       { '' }
				}
				cw.emit(
					'@${cmd.index}', 'D=A', '@${seg}', 'A=M+D', 'D=M',
					'@SP', 'A=M', 'M=D', '@SP', 'M=M+1',
				)
			}
			'temp' {
				temp_addr := 5 + cmd.index
				cw.emit('@${temp_addr}', 'D=M', '@SP', 'A=M', 'M=D', '@SP', 'M=M+1')
			}
			'pointer' {
				seg := if cmd.index == 0 { 'THIS' } else { 'THAT' }
				cw.emit('@${seg}', 'D=M', '@SP', 'A=M', 'M=D', '@SP', 'M=M+1')
			}
			'static' {
				cw.emit('@${cw.file_name}.${cmd.index}', 'D=M', '@SP', 'A=M', 'M=D', '@SP', 'M=M+1')
			}
			else {}
		}
	} else {
		// pop
		match cmd.segment {
			'local', 'argument', 'this', 'that' {
				seg := match cmd.segment {
					'local'    { 'LCL' }
					'argument' { 'ARG' }
					'this'     { 'THIS' }
					'that'     { 'THAT' }
					else       { '' }
				}
				cw.emit(
					'@${cmd.index}', 'D=A', '@${seg}', 'D=M+D',
					'@R13', 'M=D', '@SP', 'AM=M-1', 'D=M',
					'@R13', 'A=M', 'M=D',
				)
			}
			'temp' {
				temp_addr := 5 + cmd.index
				cw.emit('@SP', 'AM=M-1', 'D=M', '@${temp_addr}', 'M=D')
			}
			'pointer' {
				seg := if cmd.index == 0 { 'THIS' } else { 'THAT' }
				cw.emit('@SP', 'AM=M-1', 'D=M', '@${seg}', 'M=D')
			}
			'static' {
				cw.emit('@SP', 'AM=M-1', 'D=M', '@${cw.file_name}.${cmd.index}', 'M=D')
			}
			else {}
		}
	}
}

// -------- MAIN ENTRY POINT --------

/// Program entry point. Reads VM commands, translates, and writes output.
fn main() {
	// Validate arguments
	if os.args.len < 2 {
		eprintln('Usage: v run lab1.v <input.vm>')
		exit(1)
	}
	// Read input file
	input := os.args[1]
	lines := os.read_lines(input) or {
		eprintln('Failed to read file: ${input}')
		exit(1)
	}
	// Parse commands
	mut commands := []VMCommand{}
	for line in lines {
		if cmd := parse_line(line) {
			commands << cmd
		}
	}
	// Initialize code writer
	mut cw := CodeWriter{
		file_name: os.file_name(input).all_before_last('.')
	}
	// Generate code
	for cmd in commands {
		if cmd.typ in [.push, .pop] {
			cw.write_push_pop(cmd)
		} else {
			cw.write_arithmetic(cmd)
		}
	}
	// Write output file
	out_file := os.join_path(os.dir(input), '${cw.file_name}.asm')
	os.write_lines(out_file, cw.out) or {
		eprintln('Failed to write output file')
		exit(1)
	}
	println('Translation complete: ${out_file}')
}
