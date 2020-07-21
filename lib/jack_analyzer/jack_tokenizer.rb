require "jack_analyzer/token_type"

class JackAnalyzer::JackTokenizer
  include JackAnalyzer::TokenType

  attr_reader :input
  attr_accessor :location, :raw_token, :raw_token_type

  def initialize(input_file)
    @input = File.open(input_file).read
    @location = 0
    @raw_token = nil
    @raw_token_type = nil
  end

  def token_type
    str_from(raw_token_type)
  end

  def token
    tokenize_from(raw_token)
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
    when is_symbol?(input[location])
      self.raw_token_type = SYMBOL
    when is_integer_constant?(input[location])
      while input[location+1].match?(/\d/)
        self.location += 1
      end
      self.raw_token_type = INT_CONST
    when is_string_constant?(input[location])
      start += 1 # in case of string constant, start is ".
      self.location += 1
      while !input[location+1].match?(/"/)
        self.location += 1
      end
      self.raw_token_type = STRING_CONST
    else
      while input[location+1].match?(/\w/)
        self.location += 1
      end
      self.raw_token_type = is_keyword?(input[start..location]) ?
        KEYWORD : IDENTIFIER
    end

    self.raw_token = input[start..location]
    self.location += 1 if raw_token_type == STRING_CONST # in case of string constant, location is ".
  end
end
