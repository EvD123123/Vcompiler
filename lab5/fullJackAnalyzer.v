import os
import strings

// Token types
enum TokenType {
	keyword
	symbol
	identifier
	int_const
	string_const
}

// Symbol kinds
enum SymbolKind {
	static_var
	field
	arg
	var
	class_name
	subroutine
}

// VM Segments
enum Segment {
	constant
	argument
	local
	static_seg
	this
	that
	pointer
	temp
}

// VM Commands
enum Command {
	add
	sub
	neg
	eq
	gt
	lt
	and_cmd
	or_cmd
	not_cmd
}

// Jack language keywords
const jack_keywords = [
	'class', 'constructor', 'function', 'method', 'field', 'static', 'var',
	'int', 'char', 'boolean', 'void', 'true', 'false', 'null', 'this',
	'let', 'do', 'if', 'else', 'while', 'return'
]

// Jack language symbols
const jack_symbols = [
	'{', '}', '(', ')', '[', ']', '.', ',', ';', '+', '-', '*', '/', '&',
	'|', '<', '>', '=', '~'
]

// Token structure
struct Token {
	token_type TokenType
	value      string
}

// Symbol information
struct Symbol {
	name  string
type  string
kind  SymbolKind
index int
}

// Symbol Table
struct SymbolTable {
mut:
class_scope      map[string]Symbol
subroutine_scope map[string]Symbol
static_count     int
field_count      int
arg_count        int
var_count        int
}

fn new_symbol_table() SymbolTable {
return SymbolTable{
class_scope: map[string]Symbol{}
subroutine_scope: map[string]Symbol{}
static_count: 0
field_count: 0
arg_count: 0
var_count: 0
}
}

fn (mut st SymbolTable) start_subroutine() {
st.subroutine_scope.clear()
st.arg_count = 0
st.var_count = 0
}

fn (mut st SymbolTable) define(name string, type_ string, kind SymbolKind) {
mut index := 0
match kind {
.static_var {
index = st.static_count
st.static_count++
st.class_scope[name] = Symbol{name, type_, kind, index}
}
.field {
index = st.field_count
st.field_count++
st.class_scope[name] = Symbol{name, type_, kind, index}
}
.arg {
index = st.arg_count
st.arg_count++
st.subroutine_scope[name] = Symbol{name, type_, kind, index}
}
.var {
index = st.var_count
st.var_count++
st.subroutine_scope[name] = Symbol{name, type_, kind, index}
}
else {}
}
}

fn (st &SymbolTable) var_count_of(kind SymbolKind) int {
match kind {
.static_var { return st.static_count }
.field { return st.field_count }
.arg { return st.arg_count }
.var { return st.var_count }
else { return 0 }
}
}

fn (st &SymbolTable) kind_of(name string) ?SymbolKind {
if name in st.subroutine_scope {
return st.subroutine_scope[name].kind
}
if name in st.class_scope {
return st.class_scope[name].kind
}
return none
}

fn (st &SymbolTable) type_of(name string) ?string {
if name in st.subroutine_scope {
return st.subroutine_scope[name].type
}
if name in st.class_scope {
return st.class_scope[name].type
}
return none
}

fn (st &SymbolTable) index_of(name string) ?int {
if name in st.subroutine_scope {
return st.subroutine_scope[name].index
}
if name in st.class_scope {
return st.class_scope[name].index
}
return none
}

// VM Writer - generates VM code
struct VMWriter {
mut:
output strings.Builder
}

fn new_vm_writer() VMWriter {
return VMWriter{
output: strings.new_builder(1000)
}
}

fn (mut vm VMWriter) write_push(segment Segment, index int) {
seg_name := match segment {
.constant { 'constant' }
.argument { 'argument' }
.local { 'local' }
.static_seg { 'static' }
.this { 'this' }
.that { 'that' }
.pointer { 'pointer' }
.temp { 'temp' }
}
vm.output.writeln('push ${seg_name} ${index}')
}

fn (mut vm VMWriter) write_pop(segment Segment, index int) {
seg_name := match segment {
.argument { 'argument' }
.local { 'local' }
.static_seg { 'static' }
.this { 'this' }
.that { 'that' }
.pointer { 'pointer' }
.temp { 'temp' }
else { 'local' } // Default case
}
vm.output.writeln('pop ${seg_name} ${index}')
}

fn (mut vm VMWriter) write_arithmetic(command Command) {
cmd_name := match command {
.add { 'add' }
.sub { 'sub' }
.neg { 'neg' }
.eq { 'eq' }
.gt { 'gt' }
.lt { 'lt' }
.and_cmd { 'and' }
.or_cmd { 'or' }
.not_cmd { 'not' }
}
vm.output.writeln('${cmd_name}')
}

fn (mut vm VMWriter) write_label(label string) {
vm.output.writeln('label ${label}')
}

fn (mut vm VMWriter) write_goto(label string) {
vm.output.writeln('goto ${label}')
}

fn (mut vm VMWriter) write_if(label string) {
vm.output.writeln('if-goto ${label}')
}

fn (mut vm VMWriter) write_call(name string, n_args int) {
vm.output.writeln('call ${name} ${n_args}')
}

fn (mut vm VMWriter) write_function(name string, n_vars int) {
vm.output.writeln('function ${name} ${n_vars}')
}

fn (mut vm VMWriter) write_return() {
vm.output.writeln('return')
}

fn (mut vm VMWriter) get_output() string {
return vm.output.str()
}

// JackTokenizer - handles lexical analysis
struct JackTokenizer {
mut:
input       string
tokens      []Token
current_pos int
}

fn new_jack_tokenizer(input string) JackTokenizer {
mut tokenizer := JackTokenizer{
input: input
tokens: []Token{}
current_pos: 0
}
tokenizer.tokenize()
return tokenizer
}

fn (mut t JackTokenizer) tokenize() {
mut i := 0
input_chars := t.input.runes()

for i < input_chars.len {
ch := input_chars[i].str()

// Skip whitespace
if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
i++
continue
}

// Skip comments
if i < input_chars.len - 1 {
two_char := input_chars[i].str() + input_chars[i + 1].str()
if two_char == '//' {
// Skip line comment
for i < input_chars.len && input_chars[i].str() != '\n' {
i++
}
continue
}
if two_char == '/*' {
// Skip block comment
i += 2
for i < input_chars.len - 1 {
if input_chars[i].str() + input_chars[i + 1].str() == '*/' {
i += 2
break
}
i++
}
continue
}
}

// String constants
if ch == '"' {
i++
mut str_val := ''
for i < input_chars.len && input_chars[i].str() != '"' {
str_val += input_chars[i].str()
i++
}
i++ // Skip closing quote
t.tokens << Token{TokenType.string_const, str_val}
continue
}

// Symbols
if ch in jack_symbols {
t.tokens << Token{TokenType.symbol, ch}
i++
continue
}

// Numbers
if ch >= '0' && ch <= '9' {
mut num_str := ''
for i < input_chars.len && (input_chars[i].str() >= '0' && input_chars[i].str() <= '9') {
num_str += input_chars[i].str()
i++
}
t.tokens << Token{TokenType.int_const, num_str}
continue
}

// Identifiers and keywords
if (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_' {
mut id_str := ''
for i < input_chars.len && ((input_chars[i].str() >= 'a' && input_chars[i].str() <= 'z') ||
(input_chars[i].str() >= 'A' && input_chars[i].str() <= 'Z') ||
(input_chars[i].str() >= '0' && input_chars[i].str() <= '9') ||
input_chars[i].str() == '_') {
id_str += input_chars[i].str()
i++
}

if id_str in jack_keywords {
t.tokens << Token{TokenType.keyword, id_str}
} else {
t.tokens << Token{TokenType.identifier, id_str}
}
continue
}

i++
}
}

fn (t &JackTokenizer) has_more_tokens() bool {
return t.current_pos < t.tokens.len
}

fn (mut t JackTokenizer) advance() {
if t.has_more_tokens() {
t.current_pos++
}
}

fn (t &JackTokenizer) token_type() TokenType {
if t.has_more_tokens() {
return t.tokens[t.current_pos].token_type
}
return TokenType.keyword // Default
}

fn (t &JackTokenizer) keyword() string {
return t.tokens[t.current_pos].value
}

fn (t &JackTokenizer) symbol() string {
return t.tokens[t.current_pos].value
}

fn (t &JackTokenizer) identifier() string {
return t.tokens[t.current_pos].value
}

fn (t &JackTokenizer) int_val() int {
return t.tokens[t.current_pos].value.int()
}

fn (t &JackTokenizer) string_val() string {
return t.tokens[t.current_pos].value
}

fn (t &JackTokenizer) current_token() string {
if t.has_more_tokens() {
return t.tokens[t.current_pos].value
}
return ''
}

fn (t &JackTokenizer) peek() string {
if t.current_pos + 1 < t.tokens.len {
return t.tokens[t.current_pos + 1].value
}
return ''
}

// CompilationEngine - now generates VM code
struct CompilationEngine {
mut:
tokenizer         JackTokenizer
vm_writer         VMWriter
symbol_table      SymbolTable
current_class     string
current_subroutine string
label_counter     int
}

fn new_compilation_engine(mut tokenizer JackTokenizer) CompilationEngine {
return CompilationEngine{
tokenizer: tokenizer
vm_writer: new_vm_writer()
symbol_table: new_symbol_table()
current_class: ''
current_subroutine: ''
label_counter: 0
}
}

fn (mut c CompilationEngine) get_unique_label(prefix string) string {
label := '${prefix}_${c.label_counter}'
c.label_counter++
return label
}

fn (mut c CompilationEngine) eat(expected string) {
if c.tokenizer.current_token() == expected {
c.tokenizer.advance()
} else {
panic('Expected ${expected}, got ${c.tokenizer.current_token()}')
}
}

fn (mut c CompilationEngine) kind_to_segment(kind SymbolKind) Segment {
return match kind {
.static_var { Segment.static_seg }
.field { Segment.this }
.arg { Segment.argument }
.var { Segment.local }
else { Segment.local }
}
}

fn (mut c CompilationEngine) compile_class() {
// 'class'
c.eat('class')

// className
c.current_class = c.tokenizer.current_token()
c.tokenizer.advance()

// '{'
c.eat('{')

// classVarDec*
for c.tokenizer.current_token() in ['static', 'field'] {
c.compile_class_var_dec()
}

// subroutineDec*
for c.tokenizer.current_token() in ['constructor', 'function', 'method'] {
c.compile_subroutine()
}

// '}'
c.eat('}')
}

fn (mut c CompilationEngine) compile_class_var_dec() {
// ('static' | 'field')
kind_str := c.tokenizer.current_token()
kind := if kind_str == 'static' { SymbolKind.static_var } else { SymbolKind.field }
c.tokenizer.advance()

// type
type_name := c.tokenizer.current_token()
c.tokenizer.advance()

// varName
var_name := c.tokenizer.current_token()
c.symbol_table.define(var_name, type_name, kind)
c.tokenizer.advance()

// (',' varName)*
for c.tokenizer.current_token() == ',' {
c.eat(',')
var_name_extra := c.tokenizer.current_token()
c.symbol_table.define(var_name_extra, type_name, kind)
c.tokenizer.advance()
}

// ';'
c.eat(';')
}

fn (mut c CompilationEngine) compile_subroutine() {
// Start new subroutine scope
c.symbol_table.start_subroutine()

// ('constructor' | 'function' | 'method')
subroutine_kind := c.tokenizer.current_token()
c.tokenizer.advance()

// If method, add 'this' as first argument
if subroutine_kind == 'method' {
c.symbol_table.define('this', c.current_class, SymbolKind.arg)
}

// ('void' | type)
c.tokenizer.advance()

// subroutineName
c.current_subroutine = c.tokenizer.current_token()
c.tokenizer.advance()

// '('
c.eat('(')

// parameterList
c.compile_parameter_list()

// ')'
c.eat(')')

// subroutineBody
c.compile_subroutine_body(subroutine_kind)
}

fn (mut c CompilationEngine) compile_parameter_list() {
if c.tokenizer.current_token() != ')' {
// type
param_type := c.tokenizer.current_token()
c.tokenizer.advance()

// varName
param_name := c.tokenizer.current_token()
c.symbol_table.define(param_name, param_type, SymbolKind.arg)
c.tokenizer.advance()

// (',' type varName)*
for c.tokenizer.current_token() == ',' {
c.eat(',')
param_type_extra := c.tokenizer.current_token()
c.tokenizer.advance()
param_name_extra := c.tokenizer.current_token()
c.symbol_table.define(param_name_extra, param_type_extra, SymbolKind.arg)
c.tokenizer.advance()
}
}
}

fn (mut c CompilationEngine) compile_subroutine_body(subroutine_kind string) {
// '{'
c.eat('{')

// varDec*
for c.tokenizer.current_token() == 'var' {
c.compile_var_dec()
}

// Generate function declaration
function_name := '${c.current_class}.${c.current_subroutine}'
n_vars := c.symbol_table.var_count_of(SymbolKind.var)
c.vm_writer.write_function(function_name, n_vars)

// Handle constructor/method setup
if subroutine_kind == 'constructor' {
// Allocate memory for new object
field_count := c.symbol_table.var_count_of(SymbolKind.field)
c.vm_writer.write_push(Segment.constant, field_count)
c.vm_writer.write_call('Memory.alloc', 1)
c.vm_writer.write_pop(Segment.pointer, 0)
} else if subroutine_kind == 'method' {
// Set THIS to point to the current object
c.vm_writer.write_push(Segment.argument, 0)
c.vm_writer.write_pop(Segment.pointer, 0)
}

// statements
c.compile_statements()

// '}'
c.eat('}')
}

fn (mut c CompilationEngine) compile_var_dec() {
// 'var'
c.eat('var')

// type
var_type := c.tokenizer.current_token()
c.tokenizer.advance()

// varName
var_name := c.tokenizer.current_token()
c.symbol_table.define(var_name, var_type, SymbolKind.var)
c.tokenizer.advance()

// (',' varName)*
for c.tokenizer.current_token() == ',' {
c.eat(',')
var_name_extra := c.tokenizer.current_token()
c.symbol_table.define(var_name_extra, var_type, SymbolKind.var)
c.tokenizer.advance()
}

// ';'
c.eat(';')
}

fn (mut c CompilationEngine) compile_statements() {
for c.tokenizer.current_token() in ['let', 'if', 'while', 'do', 'return'] {
match c.tokenizer.current_token() {
'let' { c.compile_let() }
'if' { c.compile_if() }
'while' { c.compile_while() }
'do' { c.compile_do() }
'return' { c.compile_return() }
else { break }
}
}
}

fn (mut c CompilationEngine) compile_do() {
// 'do'
c.eat('do')

// subroutineCall
c.compile_subroutine_call()

// Pop the returned value (do statements ignore return values)
c.vm_writer.write_pop(Segment.temp, 0)

// ';'
c.eat(';')
}

fn (mut c CompilationEngine) compile_let() {
// 'let'
c.eat('let')

// varName
var_name := c.tokenizer.current_token()
c.tokenizer.advance()

mut is_array := false

// ('[' expression ']')?
if c.tokenizer.current_token() == '[' {
is_array = true
// Push array base address
if kind := c.symbol_table.kind_of(var_name) {
if index := c.symbol_table.index_of(var_name) {
segment := c.kind_to_segment(kind)
c.vm_writer.write_push(segment, index)
}
}

c.eat('[')
c.compile_expression()
c.eat(']')

// Calculate array[index] address
c.vm_writer.write_arithmetic(Command.add)
}

// '='
c.eat('=')

// expression
c.compile_expression()

// ';'
c.eat(';')

// Store the value
if is_array {
// Store in array element
c.vm_writer.write_pop(Segment.temp, 0)
c.vm_writer.write_pop(Segment.pointer, 1)
c.vm_writer.write_push(Segment.temp, 0)
c.vm_writer.write_pop(Segment.that, 0)
} else {
// Store in variable
if kind := c.symbol_table.kind_of(var_name) {
if index := c.symbol_table.index_of(var_name) {
segment := c.kind_to_segment(kind)
c.vm_writer.write_pop(segment, index)
}
}
}
}

fn (mut c CompilationEngine) compile_while() {
while_label := c.get_unique_label('WHILE')
end_label := c.get_unique_label('WHILE_END')

// 'while'
c.eat('while')

c.vm_writer.write_label(while_label)

// '('
c.eat('(')

// expression
c.compile_expression()

// ')'
c.eat(')')

// Negate condition and jump to end if false
c.vm_writer.write_arithmetic(Command.not_cmd)
c.vm_writer.write_if(end_label)

// '{'
c.eat('{')

// statements
c.compile_statements()

// '}'
c.eat('}')

// Jump back to while condition
c.vm_writer.write_goto(while_label)
c.vm_writer.write_label(end_label)
}

fn (mut c CompilationEngine) compile_return() {
// 'return'
c.eat('return')

// expression?
if c.tokenizer.current_token() != ';' {
c.compile_expression()
} else {
// Void function - push 0
c.vm_writer.write_push(Segment.constant, 0)
}

// ';'
c.eat(';')

c.vm_writer.write_return()
}

fn (mut c CompilationEngine) compile_if() {
else_label := c.get_unique_label('IF_ELSE')
end_label := c.get_unique_label('IF_END')

// 'if'
c.eat('if')

// '('
c.eat('(')

// expression
c.compile_expression()

// ')'
c.eat(')')

// Negate condition and jump to else
c.vm_writer.write_arithmetic(Command.not_cmd)
c.vm_writer.write_if(else_label)

// '{'
c.eat('{')

// statements
c.compile_statements()

// '}'
c.eat('}')

// Jump to end (skip else part)
c.vm_writer.write_goto(end_label)

// Else label
c.vm_writer.write_label(else_label)

// ('else' '{' statements '}')?
if c.tokenizer.current_token() == 'else' {
c.eat('else')
c.eat('{')
c.compile_statements()
c.eat('}')
}

c.vm_writer.write_label(end_label)
}

fn (mut c CompilationEngine) compile_expression() {
// term
c.compile_term()

// (op term)*
op_symbols := ['+', '-', '*', '/', '&', '|', '<', '>', '=']
for c.tokenizer.current_token() in op_symbols {
op := c.tokenizer.current_token()
c.tokenizer.advance()
c.compile_term()

// Generate VM command for operation
match op {
'+' { c.vm_writer.write_arithmetic(Command.add) }
'-' { c.vm_writer.write_arithmetic(Command.sub) }
'*' { c.vm_writer.write_call('Math.multiply', 2) }
'/' { c.vm_writer.write_call('Math.divide', 2) }
'&' { c.vm_writer.write_arithmetic(Command.and_cmd) }
'|' { c.vm_writer.write_arithmetic(Command.or_cmd) }
'<' { c.vm_writer.write_arithmetic(Command.lt) }
'>' { c.vm_writer.write_arithmetic(Command.gt) }
'=' { c.vm_writer.write_arithmetic(Command.eq) }
else {}
}
}
}

fn (mut c CompilationEngine) compile_term() {
token_type := c.tokenizer.token_type()
current_token := c.tokenizer.current_token()

match token_type {
.int_const {
// Integer constant
value := c.tokenizer.int_val()
c.vm_writer.write_push(Segment.constant, value)
c.tokenizer.advance()
}
.string_const {
// String constant
str_val := c.tokenizer.string_val()
c.vm_writer.write_push(Segment.constant, str_val.len)
c.vm_writer.write_call('String.new', 1)
for ch in str_val.runes() {
c.vm_writer.write_push(Segment.constant, int(ch))
c.vm_writer.write_call('String.appendChar', 2)
}
c.tokenizer.advance()
}
.keyword {
// true | false | null | this
match current_token {
'true' {
c.vm_writer.write_push(Segment.constant, 1)
c.vm_writer.write_arithmetic(Command.neg)
}
'false', 'null' {
c.vm_writer.write_push(Segment.constant, 0)
}
'this' {
c.vm_writer.write_push(Segment.pointer, 0)
}
else {}
}
c.tokenizer.advance()
}
.identifier {
next_token := c.tokenizer.peek()
if next_token == '[' {
// varName '[' expression ']'
var_name := c.tokenizer.current_token()
c.tokenizer.advance()

// Push array base
if kind := c.symbol_table.kind_of(var_name) {
if index := c.symbol_table.index_of(var_name) {
segment := c.kind_to_segment(kind)
c.vm_writer.write_push(segment, index)
}
}

c.eat('[')
c.compile_expression()
c.eat(']')

// Calculate and push array[index]
c.vm_writer.write_arithmetic(Command.add)
c.vm_writer.write_pop(Segment.pointer, 1)
c.vm_writer.write_push(Segment.that, 0)
} else if next_token in ['(', '.'] {
// subroutineCall
c.compile_subroutine_call()
} else {
// varName
var_name := c.tokenizer.current_token()
if kind := c.symbol_table.kind_of(var_name) {
if index := c.symbol_table.index_of(var_name) {
segment := c.kind_to_segment(kind)
c.vm_writer.write_push(segment, index)
}
}
c.tokenizer.advance()
}
}
.symbol {
if current_token == '(' {
// '(' expression ')'
c.eat('(')
c.compile_expression()
c.eat(')')
} else if current_token in ['-', '~'] {
// unaryOp term
op := c.tokenizer.current_token()
c.tokenizer.advance()
c.compile_term()

match op {
'-' { c.vm_writer.write_arithmetic(Command.neg) }
'~' { c.vm_writer.write_arithmetic(Command.not_cmd) }
else {}
}
}
}
}
}

fn (mut c CompilationEngine) compile_subroutine_call() {
// Handle subroutine calls: foo() or obj.foo() or Class.foo()
mut n_args := 0
mut function_name := ''

first_name := c.tokenizer.current_token()
c.tokenizer.advance()

if c.tokenizer.current_token() == '.' {
c.eat('.')
second_name := c.tokenizer.current_token()
c.tokenizer.advance()

// Check if first_name is a variable (object method call)
if kind := c.symbol_table.kind_of(first_name) {
if type_name := c.symbol_table.type_of(first_name) {
if index := c.symbol_table.index_of(first_name) {
// Object method call - push object reference
segment := c.kind_to_segment(kind)
c.vm_writer.write_push(segment, index)
function_name = '${type_name}.${second_name}'
n_args = 1 // Account for 'this' argument
}
}
} else {
// Class method call (static)
function_name = '${first_name}.${second_name}'
}
} else {
// Method call on current object: foo() -> this.foo()
c.vm_writer.write_push(Segment.pointer, 0) // Push 'this'
function_name = '${c.current_class}.${first_name}'
n_args = 1 // Account for 'this' argument
}

c.eat('(')
n_args += c.compile_expression_list()
c.eat(')')

c.vm_writer.write_call(function_name, n_args)
}

fn (mut c CompilationEngine) compile_expression_list() int {
mut n_expressions := 0

if c.tokenizer.current_token() != ')' {
c.compile_expression()
n_expressions++

for c.tokenizer.current_token() == ',' {
c.eat(',')
c.compile_expression()
n_expressions++
}
}

return n_expressions
}

fn (mut c CompilationEngine) get_output() string {
return c.vm_writer.get_output()
}

// JackAnalyzer - main program
struct JackAnalyzer {
mut:
source_path string
}

fn new_jack_analyzer(source_path string) JackAnalyzer {
return JackAnalyzer{
source_path: source_path
}
}

fn (mut ja JackAnalyzer) analyze() ! {
if os.is_file(ja.source_path) {
if ja.source_path.ends_with('.jack') {
ja.analyze_file(ja.source_path)!
} else {
println('Error: File must have .jack extension')
}
} else if os.is_dir(ja.source_path) {
files := os.ls(ja.source_path)!
for file in files {
if file.ends_with('.jack') {
full_path := os.join_path(ja.source_path, file)
ja.analyze_file(full_path)!
}
}
} else {
println('Error: Source path does not exist')
}
}

fn (mut ja JackAnalyzer) analyze_file(file_path string) ! {
// Read input file
input := os.read_file(file_path)!

// Generate VM code output
base_name := file_path.replace('.jack', '')
vm_output_path := base_name + '.vm'
ja.generate_vm_code(input, vm_output_path)!
}

fn (mut ja JackAnalyzer) generate_vm_code(input string, output_path string) ! {
mut tokenizer := new_jack_tokenizer(input)
mut engine := new_compilation_engine(mut tokenizer)

engine.compile_class()

os.write_file(output_path, engine.get_output())!
println('Generated VM code: ${output_path}')
}

// Main function
fn main() {
	if os.args.len < 2 {
		println('Usage: jack_analyzer <source>')
		println('  source: .jack file or directory containing .jack files')
		return
	}

	source_path := os.args[1]
	mut analyzer := new_jack_analyzer(source_path)
	analyzer.analyze() or {
	println('Error: ${err}')
	}
}
