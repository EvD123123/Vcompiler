/**
 * Nahum Markov - 592539150
 * Ely van Dijk - 561151156
 */
module main

import os
import strings

pub enum CmdType {
	add
	sub
	neg
	eq
	gt
	lt
	and
	or
	not
	push
	pop
	label
	goto
	if_goto
	function
	call
	ret
}

pub struct VMCommand {
pub:
	typ  CmdType
	arg1 string
	arg2 int
}

pub struct CodeWriter {
pub mut:
	b             strings.Builder
	label_counter int
	file_name     string
	func_name     string
	bootstrap     bool
}

const segment_map = {
	'local':    'LCL'
	'argument': 'ARG'
	'this':     'THIS'
	'that':     'THAT'
}

pub fn parse_line(line string) ?VMCommand {
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
		'or' { CmdType.or }
		'not' { CmdType.not }
		'push' { CmdType.push }
		'pop' { CmdType.pop }
		'label' { CmdType.label }
		'goto' { CmdType.goto }
		'if-goto' { CmdType.if_goto }
		'function' { CmdType.function }
		'call' { CmdType.call }
		'return' { CmdType.ret }
		else { return none }
	}
	arg1 := if parts.len > 1 { parts[1] } else { '' }
	arg2 := if parts.len > 2 { parts[2].int() } else { 0 }
	return VMCommand{
		typ:  cmd_type
		arg1: arg1
		arg2: arg2
	}
}

pub fn (mut cw CodeWriter) emit(lines ...string) {
	for line in lines {
		cw.b.writeln(line)
	}
}

pub fn (mut cw CodeWriter) bootstrap_code() {
	cw.emit('@256', // Set A-register to constant 256
	 'D=A', // D = 256
	 '@SP', // Set A-register to address of SP (stack pointer)
	 'M=D' // RAM[SP] = D (initialize SP = 256)
	 )
	cw.write_call(VMCommand{ typ: .call, arg1: 'Sys.init', arg2: 0 })
}

pub fn (mut cw CodeWriter) write_arithmetic(cmd VMCommand) {
	match cmd.typ {
		.add {
			cw.emit('@SP', // A = address of SP
			 'AM=M-1', // SP--, A = SP, M = *SP (y)
			 'D=M', // D = y
			 'A=A-1', // A = address of x (SP-1)
			 'M=M+D' // *SP-1 = x + y
			 )
		}
		.sub {
			cw.emit('@SP', // A = address of SP
			 'AM=M-1', // SP--, A = SP, M = y
			 'D=M', // D = y
			 'A=A-1', // A = address of x
			 'M=M-D' // *SP-1 = x - y
			 )
		}
		.neg {
			cw.emit('@SP', // A = address of SP
			 'A=M-1', // A = address of top element
			 'M=-M' // *SP-1 = -(*SP-1)
			 )
		}
		.and {
			cw.emit('@SP', // A = SP
			 'AM=M-1', // SP--, A = SP, M = y
			 'D=M', // D = y
			 'A=A-1', // A = SP-1
			 'M=M&D' // *SP-1 = x AND y
			 )
		}
		.or {
			cw.emit('@SP', // A = SP
			 'AM=M-1', // SP--, A = SP, M = y
			 'D=M', // D = y
			 'A=A-1', // A = SP-1
			 'M=M|D' // *SP-1 = x OR y
			 )
		}
		.not {
			cw.emit('@SP', // A = SP
			 'A=M-1', // A = SP-1
			 'M=!M' // *SP-1 = NOT(*SP-1)
			 )
		}
		.eq, .gt, .lt {
			base := cmd.typ.str().to_upper()
			jump := match cmd.typ {
				.eq { 'JEQ' } // jump condition for equal
				.gt { 'JGT' } // jump if greater than
				.lt { 'JLT' } // jump if less than
				else { '' }
			}
			true_lbl := '${cw.func_name}_${base}_TRUE_${cw.label_counter}'
			end_lbl := '${cw.func_name}_${base}_END_${cw.label_counter}'
			cw.label_counter++
			cw.emit('@SP', // A = SP
			 'AM=M-1', // SP--, A = SP, M = y
			 'D=M', // D = y
			 'A=A-1', // A = SP-1 (x)
			 'D=M-D', // D = x - y
			 '@${true_lbl}', // A = address of true label
			 'D;${jump}', // if x-y jump to TRUE
			 'D=0', // D = false (0)
			 '@${end_lbl}', // A = address of end label
			 '0;JMP', // unconditional jump to END
			 '(${true_lbl})', // (TRUE) label definition
			 'D=-1', // D = true (-1)
			 '(${end_lbl})', // (END) label definition
			 '@SP', // A = SP
			 'A=M-1', // A = SP-1
			 'M=D' // *SP-1 = D (true or false)
			 )
		}
		else {}
	}
}

pub fn (mut cw CodeWriter) write_push_pop(cmd VMCommand) {
	segment := segment_map[cmd.arg1] or { '' }
	if cmd.typ == .push {
		if cmd.arg1 == 'constant' {
			cw.emit('@${cmd.arg2}', // A = constant value
			 'D=A', // D = value
			 '@SP', // A = SP
			 'A=M', // A = address SP
			 'M=D', // *SP = value
			 '@SP', // A = SP
			 'M=M+1' // SP++
			 )
		} else if segment != '' {
			cw.emit('@${cmd.arg2}', // A = offset index
			 'D=A', // D = index
			 '@${segment}', // A = base address of segment
			 'A=M+D', // A = RAM[segment] + index
			 'D=M', // D = *(segment+index)
			 '@SP', // A = SP
			 'A=M', // A = address SP
			 'M=D', // *SP = segment[index]
			 '@SP', // A = SP
			 'M=M+1' // SP++
			 )
		} else if cmd.arg1 == 'temp' {
			cw.emit('@${5 + cmd.arg2}', // A = address 5+index (temp segment)
			 'D=M', // D = temp[index]
			 '@SP', // A = SP
			 'A=M', // A = address SP
			 'M=D', // *SP = D
			 '@SP', // A = SP
			 'M=M+1' // SP++
			 )
		} else if cmd.arg1 == 'pointer' {
			seg := if cmd.arg2 == 0 { 'THIS' } else { 'THAT' }
			cw.emit('@${seg}', // A = THIS or THAT
			 'D=M', // D = base pointer
			 '@SP', // A = SP
			 'A=M', // A = address SP
			 'M=D', // *SP = THIS/THAT
			 '@SP', // A = SP
			 'M=M+1' // SP++
			 )
		} else if cmd.arg1 == 'static' {
			cw.emit('@${cw.file_name}.${cmd.arg2}', // A = static variable var.index
			 'D=M', // D = static value
			 '@SP', // A = SP
			 'A=M', // A = address SP
			 'M=D', // *SP = static
			 '@SP', // A = SP
			 'M=M+1' // SP++
			 )
		}
	} else {
		if segment != '' {
			cw.emit('@${cmd.arg2}', // A = index
			 'D=A', // D = index
			 '@${segment}', // A = segment base
			 'D=M+D', // D = address of segment[index]
			 '@R13', // A = R13 (temp register)
			 'M=D', // R13 = target address
			 '@SP', // A = SP
			 'AM=M-1', // SP--, A = SP
			 'D=M', // D = *SP (value to pop)
			 '@R13', // A = R13
			 'A=M', // A = target address
			 'M=D' // *(segment+index) = value
			 )
		} else if cmd.arg1 == 'temp' {
			cw.emit('@SP', // A = SP
			 'AM=M-1', // SP--, A = SP
			 'D=M', // D = popped value
			 '@${5 + cmd.arg2}', // A = temp segment address
			 'M=D' // temp[index] = D
			 )
		} else if cmd.arg1 == 'pointer' {
			seg := if cmd.arg2 == 0 { 'THIS' } else { 'THAT' }
			cw.emit('@SP', // A = SP
			 'AM=M-1', // SP--, A = SP
			 'D=M', // D = popped value
			 '@${seg}', // A = THIS/THAT
			 'M=D' // THIS/THAT = D
			 )
		} else if cmd.arg1 == 'static' {
			cw.emit('@SP', // A = SP
			 'AM=M-1', // SP--, A = SP
			 'D=M', // D = popped value
			 '@${cw.file_name}.${cmd.arg2}', // A = static var
			 'M=D' // static = D
			 )
		}
	}
}

pub fn (mut cw CodeWriter) write_label(label string) {
	// Declare a label in the assembly named functionName$label for branching
	cw.emit('(${cw.func_name}$${label})' // Declare label function$label
	 )
}

pub fn (mut cw CodeWriter) write_goto(label string) {
	// Unconditional jump to the label functionName$label
	cw.emit('@${cw.func_name}$${label}', // A = label address
	 '0;JMP' // goto label
	 )
}

pub fn (mut cw CodeWriter) write_if(label string) {
	// Pop top of stack; if value != 0, jump to functionName$label
	cw.emit('@SP', // A = SP
	 'AM=M-1', // SP--, A = SP
	 'D=M', // D = popped value
	 '@${cw.func_name}$${label}', // A = label address
	 'D;JNE' // if D!=0 jump
	 )
}

pub fn (mut cw CodeWriter) write_function(name string, n_vars int) {
	// Define a function entry point and initialize n_vars local variables to 0
	cw.func_name = name
	cw.emit('(${name})' // Declare function entry label
	 )
	// On a function f k command,
	// you must push k zeros onto the stack to represent k local variables,
	// all initially 0.
	for _ in 0 .. n_vars {
		cw.emit('@0', // A = 0
		 'D=A', // D = 0
		 '@SP', // A = address of SP
		 'A=M', // A = RAM[SP] (the next free stack slot)
		 'M=D', // *SP = 0         ← push a 0 onto the stack
		 '@SP', // A = address of SP
		 'M=M+1' // SP++            ← increment the stack pointer
		 )
	}
}

pub fn (mut cw CodeWriter) write_call(cmd VMCommand) {
	// Call a function: push return address,
	// save LCL, ARG, THIS, THAT, reposition ARG and LCL,
	// then jump
	ret_lbl := '${cw.func_name}_ret_${cw.label_counter}'
	cw.label_counter++
	cw.emit('@${ret_lbl}', // A = return-address label
	 'D=A', // D = return-address
	 '@SP', // A = SP
	 'A=M', // A = SP address
	 'M=D', // push return-address
	 '@SP', // A = SP
	 'M=M+1' // SP++
	 )
	// push LCL, ARG, THIS, THAT
	for seg in ['LCL', 'ARG', 'THIS', 'THAT'] {
		cw.emit('@${seg}', // A = segment pointer
		 'D=M', // D = RAM[seg]
		 '@SP', // A = SP
		 'A=M', // A = SP address
		 'M=D', // push
		 '@SP', // A = SP
		 'M=M+1' // SP++
		 )
	}
	cw.emit('@SP', // A = SP
	 'D=M', // D = SP (SP ready for repositioning ARG)
	 '@${5 + cmd.arg2}', // A = 5 + nArgs
	 'D=D-A', // D = SP - 5 - nArgs
	 '@ARG', // A = ARG
	 'M=D', // ARG = SP-5-nArgs
	 '@SP', // A = SP
	 'D=M', // D = SP
	 '@LCL', // A = LCL
	 'M=D', // LCL = SP
	 '@${cmd.arg1}', // A = functionName
	 '0;JMP', // goto function
	 '(${ret_lbl})' // return label
	 )
}

pub fn (mut cw CodeWriter) write_return() {
	// Return from function: restore caller state and jump to return address
	cw.emit('@LCL', // A = LCL
	 'D=M', // D = LCL (frame)
	 '@R13', // A = R13
	 'M=D', // R13 = frame
	 '@5', // A = 5
	 'A=D-A', // A = frame-5 (return-address)
	 'D=M', // D = *(frame-5)
	 '@R14', // A = R14 = RET
	 'M=D', // R14 = return-address
	 '@SP', // A = SP 	(*ARG = POP)
	 'AM=M-1', // SP--, A = SP
	 'D=M', // D = return-value
	 '@ARG', // A = ARG
	 'A=M', // A = ARG address
	 'M=D', // *ARG = return-value
	 '@ARG', // A = ARG	(SP = ARG + 1)
	 'D=M+1', // D = ARG+1
	 '@SP', // A = SP
	 'M=D', // SP = ARG+1
	 '@R13', // A = R13	(THAT = *(FRAME-1))
	 'AM=M-1', // frame--, A = THAT
	 'D=M', // D = THAT
	 '@THAT', // A = THAT
	 'M=D', // THAT = *(frame)
	 '@R13', // A = R13	(THIS = *(FRAME-2))
	 'AM=M-1', // frame--, A = THIS
	 'D=M', // D = THIS
	 '@THIS', // A = THIS
	 'M=D', // THIS = *(frame)
	 '@R13', // A = R13	(ARG = *(FRAME-3))
	 'AM=M-1', // frame--, A = ARG
	 'D=M', // D = ARG
	 '@ARG', // A = ARG
	 'M=D', // ARG = *(frame)
	 '@R13', // A = R13	(LCL = *(FRAME-4))
	 'AM=M-1', // frame--, A = LCL
	 'D=M', // D = LCL
	 '@LCL', // A = LCL
	 'M=D', // LCL = *(frame)
	 '@R14', // A = R14	(goto RET)
	 'A=M', // A = return-address
	 '0;JMP' // goto return-address
	 )
}

fn main() {
	if os.args.len < 2 {
		eprintln('Usage: v run lab1.v <input.vm or folder>')
		exit(1)
	}
	arg := os.args[1]
	paths := if os.is_dir(arg) {
		os.ls(arg)!.filter(it.ends_with('.vm')).map(os.join_path(arg, it))
	} else {
		[arg]
	}
	mut cw := CodeWriter{
		b:         strings.new_builder(1024 * 50)
		file_name: os.file_name(arg).all_before_last('.')
		bootstrap: paths.len > 1
	}
	if cw.bootstrap {
		cw.bootstrap_code()
	}
	for file in paths {
		cw.file_name = os.file_name(file).all_before_last('.')
		lines := os.read_lines(file) or { panic('failed to read file: ${file}') }
		for line in lines {
			if cmd := parse_line(line) {
				match cmd.typ {
					.push, .pop { cw.write_push_pop(cmd) }
					.add, .sub, .neg, .eq, .gt, .lt, .and, .or, .not { cw.write_arithmetic(cmd) }
					.label { cw.write_label(cmd.arg1) }
					.goto { cw.write_goto(cmd.arg1) }
					.if_goto { cw.write_if(cmd.arg1) }
					.function { cw.write_function(cmd.arg1, cmd.arg2) }
					.call { cw.write_call(cmd) }
					.ret { cw.write_return() }
				}
			}
		}
	}
	out_file := if os.is_dir(arg) {
		os.join_path(arg, '${os.file_name(arg)}.asm')
	} else {
		os.join_path(os.dir(arg), '${cw.file_name}.asm')
	}
	os.write_file(out_file, cw.b.str()) or { panic('failed to write output') }
	println('Translation complete: ${out_file}')
}
