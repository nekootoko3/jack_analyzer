require "jack_analyzer/identifier"

module JackAnalyzer
  class SymbolTable
    include Identifier::Kind

    attr_reader :class_scope, :static_index, :field_index
    attr_accessor :subroutine_scope, :argument_index, :local_index

    def initialize
      @class_scope = {}
      @subroutine_scope = {}
      @static_index = 0
      @field_index = 0
      @argument_index = 0
      @local_index = 0
    end

    def initialize_subroutine_scope
      @subroutine_scope = {}
      @argument_index = 0
      @local_index = 0
    end

    # @param name [String]
    # @param type [String]
    # @param kind [JackAnalyzer::Identifier::Kind]
    def define(name, type, kind)
      case kind
      when STATIC
        class_scope[name.to_sym] = Identifier.new(name, type, kind, @static_index)
        self.static_index += 1
      when FIELD
        class_scope[name.to_sym] = Identifier.new(name, type, kind, @field_index)
        self.field_index += 1
      when ARG
        subroutine_scope[name.to_sym] = Identifier.new(name, type, kind, @argument_index)
        self.argument_index += 1
      when VAR
        subroutine_scope[name.to_sym] = Identifier.new(name, type, kind, @local_index)
        self.local_index += 1
      else
        raise
      end
    end

    # @param kind [JackAnalyzer::Identifier::Kind]
    # @return [Integer]
    def var_count(kind)
      scope = class_scope?(kind) ? class_scope : subroutine_scope
      scope.values.count { |identifier| identifier.kind == kind }
    end

    # @param name [String]
    # @return [Integer]
    def kind_of(name)
      identifier = subroutine_scope[name.to_sym] || class_scope[name.to_sym]
      identifier.nil? ? NONE : identifier.kind
    end

    # @param name [String]
    # @return [String]
    def type_of(name)
      identifier = subroutine_scope[name.to_sym] || class_scope[name.to_sym]
      identifier.type
    end

    # @param [String]
    def index_of(name)
      identifier = subroutine_scope[name.to_sym] || class_scope[name.to_sym]
      identifier.index
    end

    def segment_of(token)
      case kind_of(token)
      when ARG; "argument"
      when VAR; "local"
      when STATIC; "static"
      when FIELD; "this"
      else
        raise
      end
    end
  end
end
