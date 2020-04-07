class JackAnalyzer::Identifier
  attr_reader :name, :type, :kind, :index

  def initialize(name, type, kind, index)
    @name, @type, @kind, @index = name, type, kind, index
  end

  module Kind
    NONE   = 0
    STATIC = 1
    FIELD  = 2
    ARG    = 3
    VAR    = 4

    KIND_TOKEN_MAPPING = {
      "static" => STATIC,
      "field" => FIELD,
      "argument" => ARG,
      "let" => VAR,
    }

    def class_scope?(kind)
      [STATIC, FIELD].include?(kind)
    end

    def subroutine_scope?(kind)
      [ARG, VAR].include?(kind)
    end

    def kind_from(token)
      KIND_TOKEN_MAPPING[token]
    end

    def segment_from(kind)
      case kind
      when ARG; "argument"
      when VAR; "local"
      end
    end
  end

  module Type
    UNDEFINED  = 0
    INT        = 1
    CHAR       = 2
    BOOLEAN    = 3
  end
end
