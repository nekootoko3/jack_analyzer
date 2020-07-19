require "jack_analyzer/token_type"

class JackAnalyzer::JackTokenizer
  include JackAnalyzer::TokenType

  attr_reader :input

  def initialize(input_file)
    @input = File.open(input_file).read
    @location = 0
    @token = nil
    @token_type = nil
  end

  def token_type
    str_from(@token_type)
  end

  def token
    tokenize_from(@token)
  end

  # @return [Boolean]
  def has_more_tokens?
    while true
      case
      when input[@location]&.match?(/\s/)
        skip_whitespace_and_newline!
      when input[@location, 2] == "//"
        skip_single_line_comment!
      when input[@location, 2] == "/*"
        skip_multiple_line_comment!
      else
        break
      end

      break if input[@location].nil?
    end


    !input[@location].nil?
  end

  def advance!
    set_token!
    @location += 1
  end

  private

  def skip_single_line_comment!
    while !input[@location].match?(/\n/)
      @location += 1
    end

    @location += 1
  end

  def skip_multiple_line_comment!
    while input[@location, 2] != "*/"
      @location += 1
    end
    @location += 2
  end

  def skip_whitespace_and_newline!
    while input[@location]&.match?(/\s/)
      @location += 1
    end
  end

  def set_token!
    start = @location

    case
    when is_symbol?(input[@location])
      @token_type = SYMBOL
    when is_integer_constant?(input[@location])
      while input[@location+1].match?(/\d/)
        @location += 1
      end
      @token_type = INT_CONST
    when is_string_constant?(input[@location])
      start += 1 # in case of string constant, start is ".
      @location += 1
      while !input[@location+1].match?(/"/)
        @location += 1
      end
      @token_type = STRING_CONST
    else
      while input[@location+1].match?(/\w/)
        @location += 1
      end
      @token_type = is_keyword?(input[start..@location]) ?
        KEYWORD : IDENTIFIER
    end

    @token = input[start..@location]
    @location += 1 if @token_type == STRING_CONST # in case of string constant, location is ".
  end
end
