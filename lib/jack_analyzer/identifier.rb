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

    def class_scope?(kind)
      [STATIC, FIELD].include?(kind)
    end

    def subroutine_scope?(kind)
      [ARG, VAR].include?(kind)
    end
  end

  module Type
    UNDEFINED  = 0
    INT        = 1
    CHAR       = 2
    BOOLEAN    = 3
    CLASS_NAME = 4

    def type_from(str)
    end

    def str_from(type)
    end
  end
end
