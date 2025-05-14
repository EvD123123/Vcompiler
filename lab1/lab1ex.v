/**
 * Nahum Markov - 592539150
 * Ely van Dijk - 561151156
 */
/// This program reads a .vm file containing VM commands and translates it into a
/// .asm file containing Hack assembly instructions according to the VM specification.
/// Usage: v run lab1ex.v <input.vm>

module main

import os
import strings

// -------- ENUM + STRUCT DEFINITIONS --------

/// VM command types
pub enum CmdType {
	add
	sub
	neg
	eq
	gt
	lt
	and
	or
	or2
	not
	push
	pop
}

/// Parsed VM command
pub struct VMCommand {
pub:
	typ     CmdType
	segment string
	index   int
}

/// Emits assembly and tracks labels
pub struct CodeWriter {
pub mut:
	b             strings.Builder
	label_counter int
	file_name     string
}

/// Base segment pointers
const segment_map = {
	'local':    'LCL'
	'argument': 'ARG'
	'this':     'THIS'
	'that':     'THAT'
}

// -------- PARSER --------

@[inline]
pub fn parse_line(line string) ?VMCommand {
	// Strip comments
	idx := line.index('//') or { -1 }
	raw := if idx >= 0 { line[..idx] } else { line }
	text := raw.trim_space()
	if text == '' {
		return none
	}
	parts := text.fields()
	cmd := parts[0]
	cmd_type := match cmd {
		'add' { CmdType.add }
		'sub' { CmdType.sub }
		'neg' { CmdType.neg }
		'eq' { CmdType.eq }
		'gt' { CmdType.gt }
		'lt' { CmdType.lt }
		'and' { CmdType.and }
		'or#2' { CmdType.or2 }
		'or' { CmdType.or }
		'not' { CmdType.not }
		'push' { CmdType.push }
		'pop' { CmdType.pop }
		else { return none }
	}
	if cmd_type in [.push, .pop] {
		if parts.len < 3 {
			return none
		}
		return VMCommand{
			typ:     cmd_type
			segment: parts[1]
			index:   parts[2].int()
		}
	}
	return VMCommand{
		typ: cmd_type
	}
}

// -------- EMITTER HELPERS --------

@[inline]
pub fn (mut cw CodeWriter) emit(lines ...string) {
	for line in lines {
		cw.b.write_string(line + '\n')
	}
}

@[inline]
pub fn (mut cw CodeWriter) push_from(base string, offset int) {
	cw.emit('@${offset}', 'D=A', '@${base}', 'A=M+D', 'D=M', '@SP', 'A=M', 'M=D', '@SP',
		'M=M+1')
}

@[inline]
pub fn (mut cw CodeWriter) pop_to(base string, offset int) {
	cw.emit('@${offset}', 'D=A', '@${base}', 'D=M+D', '@R13', 'M=D', '@SP', 'AM=M-1',
		'D=M', '@R13', 'A=M', 'M=D')
}

// -------- ARITHMETIC --------

@[inline]
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
		.and {
			cw.emit('@SP', 'AM=M-1', 'D=M', 'A=A-1', 'M=M&D')
		}
		.or {
			cw.emit('@SP', 'AM=M-1', 'D=M', 'A=A-1', 'M=M|D')
		}
		.not {
			cw.emit('@SP', 'A=M-1', 'M=!M')
		}
		.or2 {
			cw.emit('@SP', 'AM=M-1', 'D=M', 'A=A-1', 'D=M|D', 'D=-D', '@SP', 'A=M-1',
				'M=D')
		}
		.eq, .gt, .lt {
			base := match cmd.typ {
				.eq { 'EQ' }
				.gt { 'GT' }
				.lt { 'LT' }
				else { '' }
			}
			jump := match cmd.typ {
				.eq { 'JEQ' }
				.gt { 'JGT' }
				.lt { 'JLT' }
				else { '' }
			}
			true_lbl := '${cw.file_name}_${base}_TRUE_${cw.label_counter}'
			end_lbl := '${cw.file_name}_${base}_END_${cw.label_counter}'
			cw.label_counter++
			cw.emit('@SP', 'AM=M-1', 'D=M', 'A=A-1', 'D=M-D', '@${true_lbl}', 'D;${jump}',
				'D=0', '@${end_lbl}', '0;JMP', '(${true_lbl})', 'D=-1', '(${end_lbl})',
				'@SP', 'A=M-1', 'M=D')
		}
		else {}
	}
}

// -------- PUSH/POP --------

pub fn (mut cw CodeWriter) write_push_pop(cmd VMCommand) {
	if cmd.typ == .push {
		if cmd.segment == 'constant' {
			cw.emit('@${cmd.index}', 'D=A', '@SP', 'A=M', 'M=D', '@SP', 'M=M+1')
		} else if base := segment_map[cmd.segment] {
			cw.push_from(base, cmd.index)
		} else if cmd.segment == 'temp' {
			cw.push_from('5', cmd.index)
		} else if cmd.segment == 'pointer' {
			seg := if cmd.index == 0 { 'THIS' } else { 'THAT' }
			cw.emit('@${seg}', 'D=M', '@SP', 'A=M', 'M=D', '@SP', 'M=M+1')
		} else if cmd.segment == 'static' {
			cw.emit('@${cw.file_name}.${cmd.index}', 'D=M', '@SP', 'A=M', 'M=D', '@SP',
				'M=M+1')
		}
	} else {
		if base := segment_map[cmd.segment] {
			cw.pop_to(base, cmd.index)
		} else if cmd.segment == 'temp' {
			cw.pop_to('5', cmd.index)
		} else if cmd.segment == 'pointer' {
			seg := if cmd.index == 0 { 'THIS' } else { 'THAT' }
			cw.emit('@SP', 'AM=M-1', 'D=M', '@${seg}', 'M=D')
		} else if cmd.segment == 'static' {
			cw.emit('@SP', 'AM=M-1', 'D=M', '@${cw.file_name}.${cmd.index}', 'M=D')
		}
	}
}

// -------- MAIN --------

fn main() {
	if os.args.len < 2 {
		eprintln('Usage: v run lab1.v <input.vm>')
		exit(1)
	}
	input := os.args[1]
	lines := os.read_lines(input) or {
		eprintln('Read failed: ${err}')
		exit(1)
	}
	mut commands := []VMCommand{cap: lines.len}
	for line in lines {
		if cmd := parse_line(line) {
			commands << cmd
		}
	}
	mut cw := CodeWriter{
		file_name: os.file_name(input).all_before_last('.')
	}
	for cmd in commands {
		if cmd.typ in [.push, .pop] {
			cw.write_push_pop(cmd)
		} else {
			cw.write_arithmetic(cmd)
		}
	}
	out_file := os.join_path(os.dir(input), '${cw.file_name}.asm')
	os.write_file(out_file, cw.b.str()) or {
		eprintln('Write failed: ${err}')
		exit(1)
	}
	println('Translation complete: ${out_file}')
}
