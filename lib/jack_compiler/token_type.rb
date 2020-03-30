require "Set"

module JackCompiler::TokenType
  UNDEFINED    = 0
  KEYWORD      = 1
  SYMBOL       = 2
  IDENTIFIER   = 3
  INT_CONST    = 4
  STRING_CONST = 5

  TOKEN_TYPE_STRING_MAPPING = {
    KEYWORD      => "keyword",
    SYMBOL       => "symbol",
    IDENTIFIER   => "identifier",
    INT_CONST    => "integerConstant",
    STRING_CONST => "stringConstant",
  }

  KEYWORD_SET = Set.new([
    "class",
    "constructor",
    "function",
    "method",
    "field",
    "static",
    "var",
    "int",
    "char",
    "boolean",
    "void",
    "true",
    "false",
    "null",
    "this",
    "let",
    "do",
    "if",
    "else",
    "while",
    "return",
  ])

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

  def is_keyword?(str)
    KEYWORD_SET.member?(str)
  end

  def is_symbol?(str)
    SYMBOL_SET.member?(str)
  end

  def is_integer_constant?(str)
    str.match?(/\d/)
  end

  def is_string_constant?(str)
    str == '"'
  end

  def tokenize_from(symbol, token_type = nil)
    SYMBOL_TOKEN_MAPPING[symbol] || symbol
  end

  def str_from(token_type)
    TOKEN_TYPE_STRING_MAPPING[token_type]
  end
end
