require "jack_analyzer/token_type"

module JackAnalyzer
  class JackTokenizer
    KEYWORD      = "keyword"
    SYMBOL       = "symbol"
    IDENTIFIER   = "identifier"
    INT_CONST    = "integerConstant"
    STRING_CONST = "stringConstant"

    KEYWORD_SET = Set.new([
      "class", "constructor", "function", "method",
      "field", "static", "var", "int", "char", "boolean",
      "void", "true", "false", "null", "this", "let",
      "do", "if", "else", "while", "return"])
    SYMBOL_SET = Set.new([
      "{", "}", "(", ")", "[", "]",
      ".", ",", ";",
      "+", "-", "*", "/",
      "&", "|",
      "<", ">", "=", "~",
    ])
    SYMBOL_TOKEN_MAPPING = {
      "<" => "&lt;",
      ">" => "&gt;",
      "&" => "&amp;",
    }

    attr_reader :input
    attr_accessor :location, :token, :token_type

    def initialize(input_file)
      @input = File.open(input_file).read
      @location = 0
    end

    # @return [Boolean]
    def has_more_tokens?
      while true
        case
        when input[location]&.match?(/\s/)
          skip_whitespace_and_newline!
        when input[location, 2] == "//"
          skip_single_line_comment!
        when input[location, 2] == "/*"
          skip_multiple_line_comment!
        else
          break
        end

        break if input[location].nil?
      end

      !input[location].nil?
    end

    def advance!
      set_token!
      self.location += 1
    end

    private

    def skip_single_line_comment!
      while !input[location].match?(/\n/)
        self.location += 1
      end

      self.location += 1
    end

    def skip_multiple_line_comment!
      while input[location, 2] != "*/"
        self.location += 1
      end

      self.location += 2
    end

    def skip_whitespace_and_newline!
      while input[location]&.match?(/\s/)
        self.location += 1
      end
    end

    def set_token!
      start = location

      case
      when symbol?(input[location])
        self.token_type = SYMBOL
      when integer_constant?(input[location])
        while input[location+1].match?(/\d/)
          self.location += 1
        end
        self.token_type = INT_CONST
      when string_constant?(input[location])
        start += 1 # in case of string constant, start is ".
        self.location += 1
        while !input[location+1].match?(/"/)
          self.location += 1
        end
        self.token_type = STRING_CONST
      else
        while input[location+1].match?(/\w/)
          self.location += 1
        end
        self.token_type =
          keyword?(input[start..location]) ? KEYWORD : IDENTIFIER
      end

      self.token = input[start..location]
      self.location += 1 if token_type == STRING_CONST # in case of string constant, location is ".
    end

    def keyword?(str)
      KEYWORD_SET.member?(str)
    end

    def symbol?(str)
      SYMBOL_SET.member?(str)
    end

    def integer_constant?(str)
      str.match?(/\d/)
    end

    def string_constant?(str)
      str == '"'
    end
  end
end
