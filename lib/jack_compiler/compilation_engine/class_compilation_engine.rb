module JackCompiler::CompilationEngine
  module ClassCompilationEngine
    def compile_class!
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.send :method_missing, :class do |c|
          while has_more_tokens?
            advance!

            case @token_type
            when :identifier, :symbol
              c.send @token_type, @token
            when :keyword
              case @token
              when :class
                c.send @token_type, @token
              when :static, :field
                compile_class_var_dec!(c)
              when :constructor, :function, :method
                compile_subroutine_dec!(c)
              else
  #              raise "Invalid token type for class #{@token_type}"
              end
            end
          end
        end
      end

      p builder.to_xml
    end

    def compile_class_var_dec!(builder)
    end

    def compile_subroutine_dec!(buiilder)

    end
  end
end
