require "nokogiri"
require "set"
require "jack_analyzer/identifier"
require "jack_analyzer/symbol_table"
require "jack_analyzer/vm_writer"

class JackAnalyzer::CompilationEngine
  include JackAnalyzer::Identifier::Kind
  include JackAnalyzer::Identifier::Type
  include JackAnalyzer::VmWriter

  OP_SET = Set.new(["+", "-", "*", "/", "&", "|", "<", ">", "="])
  UNARY_OP_SET = Set.new(["-", "~"])
  TYPE_KEYWORD_SET = Set.new(["int", "char", "boolean"])

  def initialize(input, output)
    @input = Nokogiri::Slop(input).tokens.element_children
    @output = File.new(output, "w+")
    @vm = []
    @symbol_table = JackAnalyzer::SymbolTable.new

    advance!
  end

  # 'class' className '{' classVarDec* subroutineDec* '}'
  def compile_class!
    # <keyword> class </keyword>
    advance! # className
    @class_name = @token
    advance! # <symbol> { </symbol>
    advance! # classVarDec | subroutineDec | }
    while @token != "}"
      case @token
      when "static", "field"
        compile_class_var_dec! # classVarDec
      when "constructor", "function", "method"
        compile_subroutine_dec! # subroutineDec
      else
        raise "Invalid token for compile_class!: #{@token}"
      end
      advance! # classVarDec | subroutineDec | }
    end
    @output.puts(@vm)
  end


  private

  # ('static' | 'field') type varName (',' varName)* ';'
  def compile_class_var_dec!
    # 'static' | 'field'
    advance! # type
    advance! # varName
    advance! # , | ;
    while @token == ","
      # ,
      advance! # varName
      advance! # ;
    end
    # ;
  end

  # ('constructor' | 'function' | 'method') ('void' | type) subroutineName '(' parameterList ')' subroutineBody
  def compile_subroutine_dec!
    @subroutine_vm = []

    # <keyword> constructor | function | method </keyword>
    subroutine_type = @token
    advance! # 'void' | type
    return_type = @token
    advance! # subroutineName
    subroutine_name = subroutine_type == "method" ? @token : @class_name + "." + @token
    advance! # (
    advance! # parameterList | )
    if token_is_type?
      compile_parameter_list! # parameterList
      advance! # )
    end
    advance! # subroutineBody
    compile_subroutine_body!
    if return_type == "void"
      # if return type is void, we have to push 0. and caller will pop it
      @subroutine_vm << write_push("constant", 0)
    end
    @subroutine_vm << write_return

    @subroutine_vm.unshift(write_function(subroutine_name, @symbol_table.var_count(VAR)))
    @vm.concat(@subroutine_vm)
  end

  # ((type varName) (',' type varName)*)?
  def compile_parameter_list!
    # type
    type = @token
    advance! # varName
    @symbol_table.define(@token, type, ARG)
    while next_token == ","
      advance! # ,
      advance! # type
      type = @token
      advance! # varName
      @symbol_table.define(@token, type, ARG)
    end
  end

  # '{' varDec* statements '}'
  def compile_subroutine_body!
    raise "Invalid token #{@token} for subroutineBody" unless @token == "{"

    # {
    advance! # var | statements
    while @token == "var"
      compile_var_dec! # varDec
      advance! # statements
    end
    compile_statements! # statements
    advance! # }
  end

  # 'var' type varName (',' varName)* ';'
  def compile_var_dec!
    raise "Invalid token #{@token} for varDec" unless @token == "var"

    # var
    advance! # type
    advance! # varName
    @symbol_table.define(@token, previous_token, VAR)
    @subroutine_vm << write_push("constant", 0)
    @subroutine_vm << write_pop("local", @symbol_table.index_of(@token))
    advance! # , | ;
    while @token == ","
      advance! # varName
      @symbol_table.define(@token, previous_token, VAR)
      @subroutine_vm << write_push("constant", 0)
      @subroutine_vm << write_pop("local", @symbol_table.index_of(@token))
      advance! # ;
    end
  end

  # statement*
  # statement: letStatement | ifStatement | whileStatement | doStatement | returnStatement
  def compile_statements!
    while is_statement?(@token)
      # statement
      case @token
      when "let"; compile_let!
      when "if"; compile_if!
      when "while"; compile_while!
      when "do"; compile_do!
      when "return"; compile_return!
      else
        raise
      end
      advance! if is_statement?(next_token)
    end
  end

  # 'let' varName(identifier) ('[' expression ']' )? '=' expression ';'
  def compile_let!
    # let
    advance! # varName
    advance! # [ | =
    if @token == "["
      advance! # expression
      compile_expression!
      advance! # ]
      advance! # =
    end
    advance! # expression
    compile_expression!
    advance! # ;
  end

  # 'if' '(' expression ')' '{' statements '}' ('else' '{' statements '}')? ';'
  def compile_if!
    # if
    advance! # (
    advance! # expression
    compile_expression!
    advance! # )
    advance! # {
    advance! # statements
    compile_statements!
    advance! # else | }
    if next_token == "else"
      advance! # else
      advance! # {
      advance! # statements
      compile_statements!
      advance! # }
    end
  end

  # 'while' '(' expression ')' '{' statements '}'
  def compile_while!
    # while
    advance! # (
    advance! # expression
    compile_expression!
    advance! # )
    advance! # {
    advance! # statements
    compile_statements!
    advance! # }
  end

  # 'do' subroutineCall ';'
  def compile_do!
    # do
    advance! # subroutineCall
    compile_subroutine_call!
    advance! # ;
    @subroutine_vm << write_pop("temp", 0)
  end

  # 'return' expression? ';'
  def compile_return!
    # return
    advance! # expression | ;
    if @token != ";"
      compile_expression! # expression
      advance! # ;
    end
  end

  # term (op term)
  def compile_expression!
    # term
    compile_term!
    while OP_SET.member?(next_token)
      advance! # op
      op = @token
      advance! # term
      compile_term!
      @subroutine_vm << write_arithmetic(binary_command_from(op))
    end
  end

  # integerConstant | stringConstant | keywordConstant |
  # varName | varName '[' expression ']' | subroutineCall |
  # '(' expression ')' | unaryOp term
  def compile_term!
    case @token_type.to_sym
    when :integerConstant, :stringConstant, :keyword
      # integerConstant | stringConstant | keywordConstant
      @subroutine_vm << write_push("constant", @token)
    when :identifier
      case next_token
      when ".", "("
        # subroutineCall
        compile_subroutine_call!
      when "[" # array index access
        # identifier
        advance! # [
        advance! # expression
        compile_expression!
        advance! # ]
      else
        # identifier
      end
    when :symbol
      if @token == "(" # grouped expression
        # (
        advance! # expression
        compile_expression!
        advance! # )
      elsif UNARY_OP_SET.member?(@token)
        # unary operator
        advance!
        compile_term! # term
      else
        raise "Invalid token for compile_term!: #{@token}"
      end
    else
      raise "Invalid token type for compile_term!: #{@token_type}"
    end
  end

  # subroutineName '(' expressionList ')' |
  # (className | varName)  '.' subroutineName '(' expressionList ')'
  def compile_subroutine_call!
    receiver_or_function = called_function = @token # subroutineName | className | varName
    should_push_self = true
    advance! # . | (
    if @token == "."
      # .
      advance! # subroutineName
      called_function = called_function + "." + @token
      should_push_self = false unless self_needed_function?(receiver_or_function)
      advance! # (
    end
    advance! # expressionList | )
    @n_args = 0
    if @token != ")"
      compile_expression_list! # expressionList
      advance! # )
    end
    @subroutine_vm << write_call(called_function, @n_args)
  end

  # ( expression (',' expression)* )?
  def compile_expression_list!
    compile_expression! # expression
    @n_args += 1
    while next_token == ","
      advance! # ,
      advance! # expression
      compile_expression!
      @n_args += 1
    end
  end

  def advance!
    defined?(@index) ? @index += 1 : @index = 0

    @token_type = @input[@index].name
    @token = @input[@index].content
  end

  def token_is_type?(token_type: @token_type, token: @token)
    token_type.to_sym == :identifier || TYPE_KEYWORD_SET.member?(token)
  end

  def is_statement?(token)
    ["let", "if", "while", "do", "return"].include?(token)
  end

  def next_token_type
    @input[@index + 1]&.name
  end

  def next_token
    @input[@index + 1]&.content
  end

  def previous_token
    @input[@index - 1]&.content
  end

  def self_needed_function?(receiver)
    @symbol_table.kind_of(receiver) != NONE
  end
end
