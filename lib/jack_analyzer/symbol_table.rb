require "jack_analyzer/identifier"

class JackAnalyzer::SymbolTable
  include JackAnalyzer::Identifier::Kind
  include JackAnalyzer::Identifier::Type

  def initialize
    @class_scope = {}
    @subroutine_scope = {}
    @class_exec_index = 0
    @subroutine_exec_index = 0
  end

  def start_subroutine
    @subroutine_scope = {}
  end

  # @param name [String]
  # @param type [JackAnalyzer::Identifier::Type]
  # @param kind [JackAnalyzer::Identifier::Kind]
  def define(name, type, kind)
    if class_scope?(kind)
      @class_scope[name.to_sym] = JackAnalyzer::Identifier.new(name, type, kind, @class_exec_index)
      @class_exec_index += 1
    else
      @subroutine_scope[name.to_sym] = JackAnalyzer::Identifier.new(name, type, kind, @subroutine_exec_index)
      @subroutine_exec_index += 1
    end
  end

  # @param kind [JackAnalyzer::Identifier::Kind]
  # @return [Integer]
  def var_count(kind)
    scope = class_scope?(kind) ? @class_scope : @subroutine_scope
    scope.values.count { |identifier| identifier.kind == kind }
  end

  # @param name [String]
  # @return [Integer]
  def kind_of(name)
    identifier = @subroutine_scope[name.to_sym] || @class_scope[name.to_sym]
    identifier.nil? ? NONE : identifier.kind
  end

  # @param name [String]
  # @return [String]
  def type_of(name)
    identifier = @subroutine_scope[name.to_sym] || @class_scope[name.to_sym]
    identifier.type
  end

  # @param [String]
  def index_of(name)
    identifier = @subroutine_scope[name.to_sym] || @class_scope[name.to_sym]
    identifier.index
  end
end
