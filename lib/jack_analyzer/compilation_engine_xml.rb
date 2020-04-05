require "nokogiri"
require "set"

class JackAnalyzer::CompilationEngineXml
  OP_SET = Set.new(["+", "-", "*", "/", "&", "|", "<", ">", "="])
  UNARY_OP_SET = Set.new(["-", "~"])
  TYPE_KEYWORD_SET = Set.new(["int", "char", "boolean"])

  def initialize(input, output)
    @input = Nokogiri::Slop(input).tokens.element_children
    @output = File.new(output, "w+")

    advance!
  end

  # 'class' className '{' classVarDec* subroutineDec* '}'
  def compile_class!
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.send :method_missing, :class do |c|
        c.send @token_type, @token    # <keyword> class </keyword>
        advance!
        c.send @token_type, @token    # className
        advance!
        c.send @token_type, @token    # <symbol> { </symbol>
        advance!
        while @token != "}"           # classVarDec* subroutineDec*
          case @token
          when "static", "field"
            compile_class_var_dec!(c)  # classVarDec
          when "constructor", "function", "method"
            compile_subroutine_dec!(c) # subroutineDec
          else
            raise "Invalid token for compile_class!: #{@token}"
          end
          advance!
        end

        c.send @token_type, @token    # <symbol> } </symbol>
      end
    end
    @output.puts(builder.to_xml)
    puts builder.to_xml
  end

  private

  # ('static' | 'field') type varName (',' varName)* ';'
  def compile_class_var_dec!(builder)
    builder.classVarDec do |cvd|
      cvd.send @token_type, @token   # 'static' | 'field'
      advance!
      cvd.send @token_type, @token   # type
      advance!
      cvd.send @token_type, @token   # varName
      advance!
      while @token == ","
        cvd.send @token_type, @token # <symbol> , </symbol>
        advance!
        cvd.send @token_type, @token   # varName
        advance!
      end
      builder.send @token_type, @token # <symbol> ; </symbol>
    end
  end

  # ('constructor' | 'function' | 'method') ('void' | type) subroutineName '(' parameterList ')' subroutineBody
  def compile_subroutine_dec!(builder)
    builder.subroutineDec do |sd|
      sd.send @token_type, @token  # <keyword> constructor | function | method </keyword>
      advance!
      sd.send @token_type, @token  # 'void' | type
      advance!
      sd.send @token_type, @token  # <identifier> subroutineName </identifier>
      advance!
      sd.send @token_type, @token  # <symbol> ( </symbol>
      advance!
      sd.parameterList do |pl|
        if is_type?
          compile_parameter_list!(pl)
          advance!
        end
      end
      sd.send @token_type, @token # <symbol> ) </symbol>
      advance!
      compile_subroutine_body!(sd)
    end
  end

  # ((type varName) (',' type varName)*)?
  def compile_parameter_list!(builder)
    builder.send @token_type, @token   # type
    advance!
    builder.send @token_type, @token   # varName
    while next_token == ","
      advance!
      builder.send @token_type, @token # <symbol> , </symbol>
      advance!
      builder.send @token_type, @token # type
      advance!
      builder.send @token_type, @token # varName
    end
  end

  # '{' varDec* statements '}'
  def compile_subroutine_body!(builder)
    raise "Invalid token #{@token} for subroutineBody" unless @token == "{"

    builder.subroutineBody do |body|
      body.send @token_type, @token # <symbol> { </symbol>
      advance!
      while @token == "var"
        compile_var_dec!(body)      # varDec
        advance!
      end
      compile_statements!(body)     # statements
      advance!
      body.send @token_type, @token # <symbol> } </symbol>
    end
  end

  # 'var' type varName (',' varName)* ';'
  def compile_var_dec!(builder)
    raise "Invalid token #{@token} for varDec" unless @token == "var"

    builder.varDec do |vd|
      vd.send @token_type, @token # <keyword> var </keyword>
      advance!
      vd.send @token_type, @token # type
      advance!
      vd.send @token_type, @token # <identifier> varName </identifier>
      advance!
      while @token == ","
        vd.send @token_type, @token # <symbol> , </symbol>
        advance!
        vd.send @token_type, @token # <identifier> varName </identifier>
        advance!
      end
      vd.send @token_type, @token # <symbol> ; </symbol>
    end
  end

  # statement*
  # statement: letStatement | ifStatement | whileStatement | doStatement | returnStatement
  def compile_statements!(builder)
    builder.statements do |s|
      while is_statement?(@token)
        case @token
        when "let"; compile_let!(s)
        when "if"; compile_if!(s)
        when "while"; compile_while!(s)
        when "do"; compile_do!(s)
        when "return"; compile_return!(s)
        else; raise
        end
        advance! if is_statement?(next_token)
      end
    end
  end

  # 'let' varName(identifier) ('[' expression ']' )? '=' expression ';'
  def compile_let!(builder)
    builder.letStatement do |ls|
      ls.send @token_type, @token # <keyword> let </keyword>
      advance!
      ls.send @token_type, @token # <identifier> varName </identifier>
      advance!
      if @token == "["
        ls.send @token_type, @token # <symbol> [ </symbol>
        advance!
        compile_expression!(ls)
        advance!
        ls.send @token_type, @token # <symbol> ] </symbol>
        advance!
      end
      ls.send @token_type, @token # <symbol> = </symbol>
      advance!
      compile_expression!(ls)     # expression
      advance!
      ls.send @token_type, @token # <symbol> ; </symbol>
    end
  end

  # 'if' '(' expression ')' '{' statements '}' ('else' '{' statements '}')? ';'
  def compile_if!(builder)
    builder.ifStatement do |is|
      is.send @token_type, @token # <keyword> if </keyword>
      advance!
      is.send @token_type, @token # <keyword> ( </keyword>
      advance!
      compile_expression!(is)     # expression
      advance!
      is.send @token_type, @token # <keyword> ) </keyword>
      advance!
      is.send @token_type, @token # <keyword> { </keyword>
      advance!
      compile_statements!(is)     # statements
      advance!
      is.send @token_type, @token # <keyword> } </keyword>
      if next_token == "else"
        advance!
        is.send @token_type, @token # <keyword> else </keyword>
        advance!
        is.send @token_type, @token # <keyword> { </keyword>
        advance!
        compile_statements!(is)     # statements
        advance!
        is.send @token_type, @token # <keyword> } </keyword>
      end
    end
  end

  # 'while' '(' expression ')' '{' statements '}'
  def compile_while!(builder)
    builder.whileStatement do |ws|
      ws.send @token_type, @token # <keyword> while </keyword>
      advance!
      ws.send @token_type, @token # <symbol> ( </symbol>
      advance!
      compile_expression!(ws)     # expression
      advance!
      ws.send @token_type, @token # <symbol> ) </symbol>
      advance!
      ws.send @token_type, @token # <symbol> { </symbol>
      advance!
      compile_statements!(ws)     # statements
      advance!
      ws.send @token_type, @token # <symbol> } </symbol>
    end
  end

  # 'do' subroutineCall ';'
  def compile_do!(builder)
    builder.doStatement do |ds|
      ds.send @token_type, @token # <keyword> do </keyword>
      advance!
      compile_subroutine_call!(ds) # subroutineCall
      advance!
      ds.send @token_type, @token # <symbol> ; </symbol>
    end
  end

  # 'return' expression? ';'
  def compile_return!(builder)
    builder.returnStatement do |rs|
      rs.send @token_type, @token # <keyword> return </keyword>
      advance!
      while @token != ";"
        compile_expression!(rs)   # expression
        advance!
      end
      rs.send @token_type, @token # <symbol> ; </symbol>
    end
  end

  # term (op term)
  def compile_expression!(builder)
    builder.expression do |ex|
      compile_term!(ex)             # term
      while OP_SET.member?(next_token)
        advance!
        ex.send @token_type, @token # <symbol> op </symbol>
        advance!
        compile_term!(ex)
      end
    end
  end

  # integerConstant | stringConstant | keywordConstant |
  # varName | varName '[' expression ']' | subroutineCall |
  # '(' expression ')' | unaryOp term
  def compile_term!(builder)
    builder.term do |t|
      case @token_type.to_sym
      when :integerConstant, :stringConstant, :keyword
        t.send @token_type, @token # integerConstant | stringConstant | keywordConstant
      when :identifier
        case next_token
        when ".", "(" # subroutineCall
          compile_subroutine_call!(t) # subroutineCall
        when "[" # array index access
          t.send @token_type, @token # <identifier> identifier </identifier>
          advance!
          t.send @token_type, @token # <symbol> [ </symbol>
          advance!
          compile_expression!(t)     # expression
          advance!
          t.send @token_type, @token # <symbol> ] </symbol>
        else
          t.send @token_type, @token # <identifier> identifier </identifier>
        end
      when :symbol
        if @token == "(" # grouped expression
          t.send @token_type, @token # <symbol> ( </symbol>
          advance!
          compile_expression!(t)
          advance!
          t.send @token_type, @token # <symbol> ) </symbol>
        elsif UNARY_OP_SET.member?(@token)
          t.send @token_type, @token
          advance!
          compile_term!(t)
        else
          raise "Invalid token for compile_term!: #{@token}"
        end
      else
        raise "Invalid token type for compile_term!: #{@token_type}"
      end
    end
  end

  # subroutineName '(' expressionList ')' |
  # (className | varName)  '.' subroutineName '(' expressionList ')'
  def compile_subroutine_call!(builder)
    builder.send @token_type, @token   # subroutineName | className | varName
    advance!
    if @token == "."
      builder.send @token_type, @token # <symbol> . </symbol>
      advance!
      builder.send @token_type, @token # subroutineName
      advance!
    end
    builder.send @token_type, @token # <symbol> ( </symbol>
    advance!
    builder.expressionList do |el|
      if @token != ")"
        compile_expression_list!(el) # expressionList
        advance!
      end
    end
    builder.send @token_type, @token # <symbol> ) </symbol>
  end

  # ( expression (',' expression)* )?
  def compile_expression_list!(builder)
    compile_expression!(builder)       # expression
    while next_token == ","
      advance!
      builder.send @token_type, @token # <symbol>, </symbol>
      advance!
      compile_expression!(builder)
    end
  end

  def advance!
    defined?(@index) ? @index += 1 : @index = 0

    @token_type = @input[@index].name
    @token = @input[@index].content
  end

  def is_type?(token_type: @token_type, token: @token)
    token_type.to_sym == :identifier || TYPE_KEYWORD_SET.member?(token)
  end

  def is_statement?(token)
    ["let", "if", "while", "do", "return"].include?(token)
  end

  def next_token_type
    @input[@index+1]&.name
  end

  def next_token
    @input[@index+1]&.content
  end
end
