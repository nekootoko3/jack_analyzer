module JackAnalyzer::VmWriter
  BINARY_OPERATION_COMMAND_TOKEN_MAPPING = {
    "+" => "add",
    "-" => "sub",
    "&" => "and",
    "|" => "or",
    "=" => "eq",
    ">" => "gt",
    "<" => "lt",
  }
  UNARY_OPERATION_COMMAND_TOKEN_MAPPING = {
    "-" => "neg",
    "~" => "not",
  }

  def write_push(segment, index)
    "push %s %d" % [segment, index]
  end

  def write_pop(segment, index)
    "pop %s %d" % [segment, index]
  end

  def write_arithmetic(command)
    "%s" % command
  end

  def write_label(label)
    "label %s" % label
  end

  def write_goto(label)
    "goto %s" % label
  end

  def write_if(label)
    "if-goto %s" % label
  end

  def write_call(name, n_args)
    "call %s %d" % [name, n_args]
  end

  def write_function(name, n_locals)
    "function %s %d" % [name, n_locals]
  end

  def write_return
    "return"
  end

  def close
    @output.close
  end

  def binary_command_from(token)
    case token
    when "+", "-", "&", "|", "=", ">", "<"
      BINARY_OPERATION_COMMAND_TOKEN_MAPPING[token]
    when "*"
      "call Math.multiply 2"
    when "/"
      "call Math.divide 2"
    else
      raise
    end
  end

  def unary_command_from(token)
    command = UNARY_OPERATION_COMMAND_TOKEN_MAPPING[token]
    raise unless command
    command
  end
end
