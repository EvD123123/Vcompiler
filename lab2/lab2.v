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
	cw.emit('@256', // A = 256 literal value
	 'D=A', // D register = A (256)
	 '@SP', // A = address of SP pointer
	 'M=D' // RAM[SP] = D (initialize SP to 256)
	 )
	cw.write_call(VMCommand{ typ: .call, arg1: 'Sys.init', arg2: 0 })
}

pub fn (mut cw CodeWriter) write_arithmetic(cmd VMCommand) {
	match cmd.typ {
		.add {
			cw.emit('@SP', // A = address of SP
			 'AM=M-1', // SP--; A = SP (now pointing to y)
			 'D=M', // D = *SP (y)
			 'A=A-1', // A = SP-1 (address of x)
			 'M=M+D' // *SP-1 = x + y
			 )
		}
		.sub {
			cw.emit('@SP', // A = address of SP
			 'AM=M-1', // SP--; A = SP (y)
			 'D=M', // D = y
			 'A=A-1', // A = SP-1 (x)
			 'M=M-D' // *SP-1 = x - y
			 )
		}
		.neg {
			cw.emit('@SP', // A = address of SP
			 'A=M-1', // A = SP-1 (top stack element)
			 'M=-M' // *SP-1 = -(*SP-1)
			 )
		}
		.and {
			cw.emit('@SP', // A = address of SP
			 'AM=M-1', // SP--; A = SP (y)
			 'D=M', // D = y
			 'A=A-1', // A = SP-1 (x)
			 'M=M&D' // *SP-1 = x AND y
			 )
		}
		.or {
			cw.emit('@SP', // A = address of SP
			 'AM=M-1', // SP--; A = SP (y)
			 'D=M', // D = y
			 'A=A-1', // A = SP-1 (x)
			 'M=M|D' // *SP-1 = x OR y
			 )
		}
		.not {
			cw.emit('@SP', // A = address of SP
			 'A=M-1', // A = SP-1 (top stack element)
			 'M=!M' // *SP-1 = NOT(*SP-1)
			 )
		}
		.eq, .gt, .lt {
			base := cmd.typ.str().to_upper()
			jump := match cmd.typ {
				.eq { 'JEQ' }
				.gt { 'JGT' }
				.lt { 'JLT' }
				else { '' }
			}
			true_lbl := '${cw.func_name}*${base}*TRUE*${cw.label_counter}'
			end_lbl := '${cw.func_name}*${base}*END*${cw.label_counter}'
			cw.label_counter++
			cw.emit('@SP', // A = address of SP
			 'AM=M-1', // SP--; A = SP (y)
			 'D=M', // D = y
			 'A=A-1', // A = SP-1 (x)
			 'D=M-D', // D = x - y
			 '@${true_lbl}', // A = address of TRUE label
			 'D;${jump}', // if D (x-y) jump condition holds
			 'D=0', // D = false (0)
			 '@${end_lbl}', // A = address of END label
			 '0;JMP', // unconditional jump to END
			 '(${true_lbl})', // (TRUE) label location
			 'D=-1', // D = true (-1)
			 '(${end_lbl})', // (END) label location
			 '@SP', // A = address of SP
			 'A=M-1', // A = SP-1
			 'M=D' // *SP-1 = D (boolean result)
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
			 'D=A', // D = constant
			 '@SP', // A = SP address
			 'A=M', // A = SP (no increment yet)
			 'M=D', // *SP = D
			 '@SP', // A = SP address
			 'M=M+1' // SP++
			 )
		} else if segment != '' {
			cw.emit('@${cmd.arg2}', // A = index
			 'D=A', // D = index
			 '@${segment}', // A = base segment pointer (e.g., LCL)
			 'A=M+D', // A = base + index
			 'D=M', // D = *(base+index)
			 '@SP', // A = SP address
			 'A=M', // A = SP
			 'M=D', // *SP = D
			 '@SP', // A = SP address
			 'M=M+1' // SP++
			 )
		} else if cmd.arg1 == 'temp' {
			cw.emit('@${5 + cmd.arg2}', // A = temp base (5) + index
			 'D=M', // D = RAM[5+index]
			 '@SP', // A = SP address
			 'A=M', // A = SP
			 'M=D', // *SP = D
			 '@SP', // A = SP address
			 'M=M+1' // SP++
			 )
		} else if cmd.arg1 == 'pointer' {
			seg := if cmd.arg2 == 0 { 'THIS' } else { 'THAT' }
			cw.emit('@${seg}', // A = THIS or THAT
			 'D=M', // D = base pointer value
			 '@SP', // A = SP
			 'A=M', // A = SP
			 'M=D', // *SP = D
			 '@SP', // A = SP
			 'M=M+1' // SP++
			 )
		} else if cmd.arg1 == 'static' {
			cw.emit('@${cw.file_name}.${cmd.arg2}', // A = static var label
			 'D=M', // D = static var
			 '@SP', // A = SP
			 'A=M', // A = SP
			 'M=D', // *SP = D
			 '@SP', // A = SP
			 'M=M+1' // SP++
			 )
		}
	} else {
		if segment != '' {
			cw.emit('@${cmd.arg2}', // A = index
			 'D=A', // D = index
			 '@${segment}', // A = base segment pointer
			 'D=M+D', // D = address = base+index
			 '@R13', // A = temp register R13
			 'M=D', // R13 = target address
			 '@SP', // A = SP
			 'AM=M-1', // SP--; A = SP (value to pop)
			 'D=M', // D = popped value
			 '@R13', // A = R13
			 'A=M', // A = target address
			 'M=D' // *(base+index) = D
			 )
		} else if cmd.arg1 == 'temp' {
			cw.emit('@SP', // A = SP
			 'AM=M-1', // SP--; A = SP
			 'D=M', // D = popped value
			 '@${5 + cmd.arg2}', // A = temp slot
			 'M=D' // temp slot = D
			 )
		} else if cmd.arg1 == 'pointer' {
			seg := if cmd.arg2 == 0 { 'THIS' } else { 'THAT' }
			cw.emit('@SP', // A = SP
			 'AM=M-1', // SP--; A = SP
			 'D=M', // D = popped value
			 '@${seg}', // A = THIS or THAT
			 'M=D' // THIS/THAT = D
			 )
		} else if cmd.arg1 == 'static' {
			cw.emit('@SP', // A = SP
			 'AM=M-1', // SP--; A = SP
			 'D=M', // D = popped value
			 '@${cw.file_name}.${cmd.arg2}', // A = static label
			 'M=D' // static var = D
			 )
		}
	}
}

pub fn (mut cw CodeWriter) write_label(label string) {
	cw.emit('(${cw.func_name}$$${label})' // Define label scoped to current function
	 )
}

pub fn (mut cw CodeWriter) write_goto(label string) {
	cw.emit('@${cw.func_name}$$${label}', // A = target label address
	 '0;JMP' // unconditional jump
	 )
}

pub fn (mut cw CodeWriter) write_if(label string) {
	cw.emit('@SP', // A = SP
	 'AM=M-1', // SP--; A = SP
	 'D=M', // D = popped value
	 '@${cw.func_name}$$${label}', // A = target label
	 'D;JNE' // if D != 0 jump
	 )
}

pub fn (mut cw CodeWriter) write_function(name string, n_vars int) {
	cw.func_name = name
	cw.emit('(${name})' // Define function entry label
	 )
	for _ in 0 .. n_vars {
		cw.emit('@0', // A = 0 literal
		 'D=A', // D = 0
		 '@SP', // A = SP
		 'A=M', // A = SP
		 'M=D', // *SP = 0 (initialize local var)
		 '@SP', // A = SP
		 'M=M+1' // SP++
		 )
	}
}

pub fn (mut cw CodeWriter) write_call(cmd VMCommand) {
	ret_lbl := '${cw.func_name}*ret*${cw.label_counter}'
	cw.label_counter++
	// Push return address
	cw.emit('@${ret_lbl}', // A = return address label
	 'D=A', // D = address
	 '@SP', // A = SP
	 'A=M', // A = SP
	 'M=D', // *SP = return address
	 '@SP', // A = SP
	 'M=M+1' // SP++
	 )
	// Save LCL, ARG, THIS, THAT
	for seg in ['LCL', 'ARG', 'THIS', 'THAT'] {
		cw.emit('@${seg}', // A = segment pointer
		 'D=M', // D = segment base
		 '@SP', // A = SP
		 'A=M', // A = SP
		 'M=D', // *SP = segment base
		 '@SP', // A = SP
		 'M=M+1' // SP++
		 )
	}
	// Reposition ARG
	cw.emit('@SP', // A = SP
	 'D=M', // D = SP value
	 '@${5 + cmd.arg2}', // A = 5 + n_args
	 'D=D-A', // D = SP - (5+n_args)
	 '@ARG', // A = ARG
	 'M=D' // ARG = SP-(5+n_args)
	 )
	// Reposition LCL
	cw.emit('@SP', // A = SP
	 'D=M', // D = SP
	 '@LCL', // A = LCL
	 'M=D' // LCL = SP
	 )
	// Transfer control
	cw.emit('@${cmd.arg1}', // A = function name
	 '0;JMP' // goto function
	 )
	// Declare return label
	cw.emit('(${ret_lbl})' // return label
	 )
}

pub fn (mut cw CodeWriter) write_return() {
	cw.emit('@LCL', // A=LCL
	 'D=M', // D=frame (LCL)
	 '@R13', // A=R13
	 'M=D', // R13=frame
	 '@5', // A=5
	 'A=D-A', // A=frame-5 (return addr)
	 'D=M', // D=return address
	 '@R14', // A=R14
	 'M=D', // R14=return addr
	 '@SP', // A=SP
	 'AM=M-1', // SP--; A=SP
	 'D=M', // D=return value
	 '@ARG', // A=ARG
	 'A=M', // A=ARG
	 'M=D', // *ARG = return value
	 '@ARG', // A=ARG
	 'D=M+1', // D=ARG+1
	 '@SP', // A=SP
	 'M=D', // SP = ARG+1
	 '@R13', // A=R13
	 'AM=M-1', // frame--; A=frame-1
	 'D=M', // D=THAT
	 '@THAT', // A=THAT
	 'M=D', // THAT = *(frame-1)
	 '@R13', // A=R13
	 'AM=M-1', // frame--; A=frame-1
	 'D=M', // D=THIS
	 '@THIS', // A=THIS
	 'M=D', // THIS = *(frame-1)
	 '@R13', // A=R13
	 'AM=M-1', // frame--; A=frame-1
	 'D=M', // D=ARG
	 '@ARG', // A=ARG
	 'M=D', // ARG = *(frame-1)
	 '@R13', // A=R13
	 'AM=M-1', // frame--; A=frame-1
	 'D=M', // D=LCL
	 '@LCL', // A=LCL
	 'M=D', // LCL = *(frame-1)
	 '@R14', // A=R14
	 'A=M', // A=return address
	 '0;JMP' // goto return address
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
