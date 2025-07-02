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

// Usage types
enum Usage {
	declared
	used
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

// CompilationEngine - enhanced with symbol table support
struct CompilationEngine {
mut:
tokenizer     JackTokenizer
output        strings.Builder
indent_level  int
symbol_table  SymbolTable
current_class string
current_subroutine string
}

fn new_compilation_engine(mut tokenizer JackTokenizer) CompilationEngine {
return CompilationEngine{
tokenizer: tokenizer
output: strings.new_builder(1000)
indent_level: 0
symbol_table: new_symbol_table()
current_class: ''
current_subroutine: ''
}
}

fn (mut c CompilationEngine) write_indent() {
for _ in 0 .. c.indent_level {
c.output.write_string('  ')
}
}

fn (mut c CompilationEngine) write_terminal() {
c.write_indent()
token_type := c.tokenizer.token_type()
token_value := c.tokenizer.current_token()

match token_type {
.keyword {
c.output.writeln('<keyword> ${token_value} </keyword>')
}
.symbol {
// Handle XML escape sequences
escaped_value := match token_value {
'<' { '&lt;' }
'>' { '&gt;' }
'"' { '&quot;' }
'&' { '&amp;' }
else { token_value }
}
c.output.writeln('<symbol> ${escaped_value} </symbol>')
}
.identifier {
c.output.writeln('<identifier> ${token_value} </identifier>')
}
.int_const {
c.output.writeln('<integerConstant> ${token_value} </integerConstant>')
}
.string_const {
c.output.writeln('<stringConstant> ${token_value} </stringConstant>')
}
}
c.tokenizer.advance()
}

fn (mut c CompilationEngine) write_identifier_with_info(usage Usage) {
c.write_indent()
token_value := c.tokenizer.current_token()

// Get symbol information
mut category := 'unknown'
mut index := -1
mut defined := false

if kind := c.symbol_table.kind_of(token_value) {
match kind {
.static_var { category = 'static' }
.field { category = 'field' }
.arg { category = 'arg' }
.var { category = 'local' }
.class_name { category = 'class' }
.subroutine { category = 'subroutine' }
}

if idx := c.symbol_table.index_of(token_value) {
index = idx
}
defined = true
}

// Usage string
usage_str := match usage {
.declared { 'declared' }
.used { 'used' }
}

// Enhanced XML output with symbol information
if defined && index >= 0 {
c.output.writeln('<identifier name="${token_value}" category="${category}" index="${index}" usage="${usage_str}"> ${token_value} </identifier>')
} else {
c.output.writeln('<identifier name="${token_value}" category="${category}" usage="${usage_str}"> ${token_value} </identifier>')
}

c.tokenizer.advance()
}

fn (mut c CompilationEngine) write_open_tag(tag string) {
c.write_indent()
c.output.writeln('<${tag}>')
c.indent_level++
}

fn (mut c CompilationEngine) write_close_tag(tag string) {
c.indent_level--
c.write_indent()
c.output.writeln('</${tag}>')
}

fn (mut c CompilationEngine) compile_class() {
c.write_open_tag('class')

// 'class'
c.write_terminal()

// className
c.current_class = c.tokenizer.current_token()
c.write_identifier_with_info(Usage.declared)

// '{'
c.write_terminal()

// classVarDec*
for c.tokenizer.current_token() in ['static', 'field'] {
c.compile_class_var_dec()
}

// subroutineDec*
for c.tokenizer.current_token() in ['constructor', 'function', 'method'] {
c.compile_subroutine()
}

// '}'
c.write_terminal()

c.write_close_tag('class')
}

fn (mut c CompilationEngine) compile_class_var_dec() {
c.write_open_tag('classVarDec')

// ('static' | 'field')
kind_str := c.tokenizer.current_token()
kind := if kind_str == 'static' { SymbolKind.static_var } else { SymbolKind.field }
c.write_terminal()

// type
type_name := c.tokenizer.current_token()
c.write_terminal()

// varName
var_name := c.tokenizer.current_token()
c.symbol_table.define(var_name, type_name, kind)
c.write_identifier_with_info(Usage.declared)

// (',' varName)*
for c.tokenizer.current_token() == ',' {
c.write_terminal() // ','
var_name_extra := c.tokenizer.current_token()
c.symbol_table.define(var_name_extra, type_name, kind)
c.write_identifier_with_info(Usage.declared)
}

// ';'
c.write_terminal()

c.write_close_tag('classVarDec')
}

fn (mut c CompilationEngine) compile_subroutine() {
c.write_open_tag('subroutineDec')

// Start new subroutine scope
c.symbol_table.start_subroutine()

// ('constructor' | 'function' | 'method')
subroutine_kind := c.tokenizer.current_token()
c.write_terminal()

// If method, add 'this' as first argument
if subroutine_kind == 'method' {
c.symbol_table.define('this', c.current_class, SymbolKind.arg)
}

// ('void' | type)
c.write_terminal()

// subroutineName
c.current_subroutine = c.tokenizer.current_token()
c.write_identifier_with_info(Usage.declared)

// '('
c.write_terminal()

// parameterList
c.compile_parameter_list()

// ')'
c.write_terminal()

// subroutineBody
c.compile_subroutine_body()

c.write_close_tag('subroutineDec')
}

fn (mut c CompilationEngine) compile_parameter_list() {
c.write_open_tag('parameterList')

if c.tokenizer.current_token() != ')' {
// type
param_type := c.tokenizer.current_token()
c.write_terminal()

// varName
param_name := c.tokenizer.current_token()
c.symbol_table.define(param_name, param_type, SymbolKind.arg)
c.write_identifier_with_info(Usage.declared)

// (',' type varName)*
for c.tokenizer.current_token() == ',' {
c.write_terminal() // ','
param_type_extra := c.tokenizer.current_token()
c.write_terminal() // type
param_name_extra := c.tokenizer.current_token()
c.symbol_table.define(param_name_extra, param_type_extra, SymbolKind.arg)
c.write_identifier_with_info(Usage.declared)
}
}

c.write_close_tag('parameterList')
}

fn (mut c CompilationEngine) compile_subroutine_body() {
c.write_open_tag('subroutineBody')

// '{'
c.write_terminal()

// varDec*
for c.tokenizer.current_token() == 'var' {
c.compile_var_dec()
}

// statements
c.compile_statements()

// '}'
c.write_terminal()

c.write_close_tag('subroutineBody')
}

fn (mut c CompilationEngine) compile_var_dec() {
c.write_open_tag('varDec')

// 'var'
c.write_terminal()

// type
var_type := c.tokenizer.current_token()
c.write_terminal()

// varName
var_name := c.tokenizer.current_token()
c.symbol_table.define(var_name, var_type, SymbolKind.var)
c.write_identifier_with_info(Usage.declared)

// (',' varName)*
for c.tokenizer.current_token() == ',' {
c.write_terminal() // ','
var_name_extra := c.tokenizer.current_token()
c.symbol_table.define(var_name_extra, var_type, SymbolKind.var)
c.write_identifier_with_info(Usage.declared)
}

// ';'
c.write_terminal()

c.write_close_tag('varDec')
}

fn (mut c CompilationEngine) compile_statements() {
c.write_open_tag('statements')

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

c.write_close_tag('statements')
}

fn (mut c CompilationEngine) compile_do() {
c.write_open_tag('doStatement')

// 'do'
c.write_terminal()

// subroutineCall
c.compile_subroutine_call()

// ';'
c.write_terminal()

c.write_close_tag('doStatement')
}

fn (mut c CompilationEngine) compile_let() {
c.write_open_tag('letStatement')

// 'let'
c.write_terminal()

// varName
c.write_identifier_with_info(Usage.used)

// ('[' expression ']')?
if c.tokenizer.current_token() == '[' {
c.write_terminal() // '['
c.compile_expression()
c.write_terminal() // ']'
}

// '='
c.write_terminal()

// expression
c.compile_expression()

// ';'
c.write_terminal()

c.write_close_tag('letStatement')
}

fn (mut c CompilationEngine) compile_while() {
c.write_open_tag('whileStatement')

// 'while'
c.write_terminal()

// '('
c.write_terminal()

// expression
c.compile_expression()

// ')'
c.write_terminal()

// '{'
c.write_terminal()

// statements
c.compile_statements()

// '}'
c.write_terminal()

c.write_close_tag('whileStatement')
}

fn (mut c CompilationEngine) compile_return() {
c.write_open_tag('returnStatement')

// 'return'
c.write_terminal()

// expression?
if c.tokenizer.current_token() != ';' {
c.compile_expression()
}

// ';'
c.write_terminal()

c.write_close_tag('returnStatement')
}

fn (mut c CompilationEngine) compile_if() {
c.write_open_tag('ifStatement')

// 'if'
c.write_terminal()

// '('
c.write_terminal()

// expression
c.compile_expression()

// ')'
c.write_terminal()

// '{'
c.write_terminal()

// statements
c.compile_statements()

// '}'
c.write_terminal()

// ('else' '{' statements '}')?
if c.tokenizer.current_token() == 'else' {
c.write_terminal() // 'else'
c.write_terminal() // '{'
c.compile_statements()
c.write_terminal() // '}'
}

c.write_close_tag('ifStatement')
}

fn (mut c CompilationEngine) compile_expression() {
c.write_open_tag('expression')

// term
c.compile_term()

// (op term)*
op_symbols := ['+', '-', '*', '/', '&', '|', '<', '>', '=']
for c.tokenizer.current_token() in op_symbols {
c.write_terminal() // op
c.compile_term()   // term
}

c.write_close_tag('expression')
}

fn (mut c CompilationEngine) compile_term() {
c.write_open_tag('term')

token_type := c.tokenizer.token_type()
current_token := c.tokenizer.current_token()

match token_type {
.int_const, .string_const {
c.write_terminal()
}
.keyword {
// true | false | null | this
if current_token in ['true', 'false', 'null', 'this'] {
c.write_terminal()
}
}
.identifier {
next_token := c.tokenizer.peek()
if next_token == '[' {
// varName '[' expression ']'
c.write_identifier_with_info(Usage.used)
c.write_terminal() // '['
c.compile_expression()
c.write_terminal() // ']'
} else if next_token in ['(', '.'] {
// subroutineCall
c.compile_subroutine_call()
} else {
// varName
c.write_identifier_with_info(Usage.used)
}
}
.symbol {
if current_token == '(' {
// '(' expression ')'
c.write_terminal() // '('
c.compile_expression()
c.write_terminal() // ')'
} else if current_token in ['-', '~'] {
// unaryOp term
c.write_terminal() // unaryOp
c.compile_term()
}
}
}

c.write_close_tag('term')
}

fn (mut c CompilationEngine) compile_subroutine_call() {
// subroutineName '(' expressionList ')' |
// (className | varName) '.' subroutineName '(' expressionList ')'

c.write_identifier_with_info(Usage.used) // subroutineName or className/varName

if c.tokenizer.current_token() == '.' {
c.write_terminal() // '.'
c.write_identifier_with_info(Usage.used) // subroutineName
}

c.write_terminal() // '('
c.compile_expression_list()
c.write_terminal() // ')'
}

fn (mut c CompilationEngine) compile_expression_list() {
c.write_open_tag('expressionList')

if c.tokenizer.current_token() != ')' {
c.compile_expression()

for c.tokenizer.current_token() == ',' {
c.write_terminal() // ','
c.compile_expression()
}
}

c.write_close_tag('expressionList')
}

fn (mut c CompilationEngine) get_output() string {
return c.output.str()
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

// Stage 1: Enhanced Parser output with symbol table info (Xxx.xml)
base_name := file_path.replace('.jack', '')
parse_output_path := base_name + '.xml'
ja.generate_enhanced_parse_output(input, parse_output_path)!
}

fn (mut ja JackAnalyzer) generate_enhanced_parse_output(input string, output_path string) ! {
mut tokenizer := new_jack_tokenizer(input)
mut engine := new_compilation_engine(mut tokenizer)

engine.compile_class()

os.write_file(output_path, engine.get_output())!
println('Generated enhanced parse output with symbol table info: ${output_path}')
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
