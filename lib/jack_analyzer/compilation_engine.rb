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
    @symbol_table = JackAnalyzer::SymbolTable.new
    @vm = []

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
        compile_class_var_dec # classVarDec
      when "constructor", "function", "method"
        compile_subroutine_dec # subroutineDec
      else
        raise "Invalid token for compile_class!: #{@token}"
      end
      advance! # classVarDec | subroutineDec | }
    end
    @output.puts(@vm)
  end


  private

  # ('static' | 'field') type varName (',' varName)* ';'
  def compile_class_var_dec
    # 'static' | 'field'
    advance! # type
    var_type = @token
    advance! # varName
    @symbol_table.define(@token, var_type, kind_from(token))
    advance! # , | ;
    while @token == ","
      # ,
      advance! # varName
      @symbol_table.define(@token, var_type, kind_from(token))
      advance! # ;
    end
    # ;
  end

  # ('constructor' | 'function' | 'method') ('void' | type) subroutineName '(' parameterList ')' subroutineBody
  def compile_subroutine_dec
    @subroutine_vm = []
    @symbol_table.initialize_subroutine_scope

    # <keyword> constructor | function | method </keyword>
    subroutine_type = @token
    if subroutine_type == "method"
      # set object's base address to segment this
      @subroutine_vm << write_push("argument", 0)
      @subroutine_vm << write_pop("pointer", 0)
    end

    advance! # 'void' | type
    return_type = @token
    advance! # subroutineName
    subroutine_name = subroutine_type == "method" ?
      @token : @class_name + "." + @token
    advance! # (
    advance! # parameterList | )
    if token_is_type?
      compile_parameter_list # parameterList
      advance! # )
    end
    advance! # subroutineBody
    compile_subroutine_body
    @subroutine_vm << write_return

    @subroutine_vm.unshift(write_function(subroutine_name, @symbol_table.var_count(VAR)))
    @vm.concat(@subroutine_vm)
  end

  # ((type varName) (',' type varName)*)?
  def compile_parameter_list
    # type
    var_type = @token
    advance! # varName
    @symbol_table.define(@token, var_type, ARG)
    while next_token == ","
      advance! # ,
      advance! # type
      var_type = @token
      advance! # varName
      @symbol_table.define(@token, var_type, ARG)
    end
  end

  # '{' varDec* statements '}'
  def compile_subroutine_body
    raise "Invalid token #{@token} for subroutineBody" unless @token == "{"

    # {
    advance! # var | statements
    while @token == "var"
      compile_var_dec # varDec
      advance! # statements
    end
    compile_statements! # statements
    advance! # }
  end

  # 'var' type varName (',' varName)* ';'
  def compile_var_dec
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
      when "let"; compile_let
      when "if"; compile_if
      when "while"; compile_while
      when "do"; compile_do
      when "return"; compile_return
      else
        raise
      end
      advance! if is_statement?(next_token)
    end
  end

  # 'let' varName(identifier) ('[' expression ']' )? '=' expression ';'
  def compile_let
    # let
    advance! # varName
    var_name = @token
    var_kind = @symbol_table.kind_of(var_name)
    var_type = @symbol_table.type_of(var_name)
    advance! # [ | =
    # TODO: Array access case
    if @token == "["
      advance! # expression
      compile_expression
      advance! # ]
      advance! # =
    end
    advance! # expression
    compile_expression
    @subroutine_vm << write_pop(
      @symbol_table.segment_of(var_name),
      @symbol_table.index_of(var_name)
    )
    advance! # ;
  end

  # 'if' '(' expression ')' '{' statements '}' ('else' '{' statements '}')? ';'
  def compile_if
    label_false = new_label("if_false")
    label_end = new_label("if_end")

    # if
    advance!; advance! # ( expression
    compile_expression
    @subroutine_vm << write_arithmetic("not")
    advance!; advance! # ) {
    @subroutine_vm << write_if(label_false)
    advance! # statements
    compile_statements!
    @subroutine_vm << write_goto(label_end)
    advance! # else | }
    @subroutine_vm << write_label(label_false)
    if next_token == "else"
      advance!; advance!; advance!# else { statements
      compile_statements!
      advance! # }
    end
    @subroutine_vm << write_label(label_end)
  end

  # 'while' '(' expression ')' '{' statements '}'
  #
  # label while_label
  #   ~(cond)
  #   if-goto end_label
  # . statements
  # . goto while_label
  # label end_label
  def compile_while
    while_label = new_label("while_start")
    end_label = new_label("while_end")

    # while
    advance!; advance! # ( expression
    @subroutine_vm << write_label(while_label)
    compile_expression
    @subroutine_vm << write_arithmetic(unary_command_from("~"))
    @subroutine_vm << write_if(end_label)
    advance!; advance!; advance! # ) { statements
    compile_statements!
    @subroutine_vm << write_goto(while_label)
    @subroutine_vm << write_label(end_label)

    advance! # }
  end

  # 'do' subroutineCall ';'
  def compile_do
    # do
    advance! # subroutineCall
    compile_subroutine_call
    advance! # ;
    @subroutine_vm << write_pop("temp", 0)
  end

  # 'return' expression? ';'
  def compile_return
    # return
    advance! # expression | ;
    if @token != ";"
      compile_expression # expression
      advance! # ;
    else
      @subroutine_vm << write_push("constant", 0)
    end
  end

  # term (op term)
  def compile_expression
    # term
    compile_term
    while OP_SET.member?(next_token)
      advance! # op
      op = @token
      advance! # term
      compile_term
      @subroutine_vm << write_arithmetic(binary_command_from(op))
    end
  end

  # integerConstant | stringConstant | keywordConstant |
  # varName | varName '[' expression ']' | subroutineCall |
  # '(' expression ')' | unaryOp term
  def compile_term
    case @token_type.to_sym
    when :integerConstant
      @subroutine_vm << write_push("constant", @token)
    when :stringConstant
      @subroutine_vm << write_push("constant", @token)
    when :keyword
      case @token
      when "true"
        @subroutine_vm << write_push("constant", 1)
        @subroutine_vm << write_arithmetic("neg")
      when "false", "null"
        @subroutine_vm << write_push("constant", 0)
      when "this"
        @subroutine_vm << write_push("pointer", 0)
      end
    when :identifier
      case next_token
      when ".", "("
        # subroutineCall
        compile_subroutine_call
      when "[" # array index access
        # identifier
        advance! # [
        advance! # expression
        compile_expression
        advance! # ]
      else
        @subroutine_vm << write_push(
          @symbol_table.segment_of(@token),
          @symbol_table.index_of(@token)
        )
      end
    when :symbol
      if @token == "(" # grouped expression
        # (
        advance! # expression
        compile_expression
        advance! # )
      elsif UNARY_OP_SET.member?(@token)
        op = @token # unary operator
        advance!
        compile_term # term
        @subroutine_vm << write_arithmetic(unary_command_from(op))
      else
        raise "Invalid token for compile_term: #{@token}"
      end
    else
      raise "Invalid token type for compile_term: #{@token_type}"
    end
  end

  # subroutineName '(' expressionList ')' |
  # (className | varName)  '.' subroutineName '(' expressionList ')'
  def compile_subroutine_call
    called_function = @token # subroutineName | className | varName
    advance! # . | (
    if @token == "."
      # .
      class_or_var_name = called_function

      receiver_kind = @symbol_table.kind_of(class_or_var_name)
      case receiver_kind
      when ARG, VAR
        # pass receiver address to function as hidden argument 0
        @subroutine_vm << write_push(segment_from(receiver_kind), @symbol_table.index_of(class_or_var_name))
      else
        # NONE: class function call
      end
      advance! # subroutineName
      called_function = called_function + "." + @token
      advance! # (
    else
      # self method call case
      @subroutine_vm << write_push("pointer", 0)
    end
    advance! # expressionList | )

    if @token != ")"
      n_args = compile_expression_list # expressionList
      advance! # )
    end
    n_args ||= 0
    @subroutine_vm << write_call(called_function, n_args)
  end

  # ( expression (',' expression)* )?
  def compile_expression_list
    compile_expression # expression
    n_args = 1
    while next_token == ","
      advance!; advance! # , expression
      compile_expression
      n_args += 1
    end
    return n_args
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

  def new_label(annotation = nil)
    @label_num = 0 unless defined?(@label_num)

    label = @class_name + "_" + @label_num.to_s
    label += "_#{annotation}" if annotation
    @label_num += 1
    label
  end
end
