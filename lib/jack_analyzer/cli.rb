require "nokogiri"

require "jack_analyzer/jack_tokenizer"
require "jack_analyzer/compilation_engine"

module JackAnalyzer::Cli
  def self.start(args)
    input_files = case File.ftype(args[0]).to_sym
      when :file
        [args[0]]
      when :directory
        Dir.glob("#{args[0]}/*.jack")
      else
        raise "Invalid file type #{File.ftype(args[0])}"
      end

    input_files.each do |input_file|
      puts "processing #{input_file}..."

      tokenizer = JackAnalyzer::JackTokenizer.new(input_file)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.tokens do |t|
          while tokenizer.has_more_tokens?
            tokenizer.advance!
            t.send tokenizer.token_type, tokenizer.token
          end
        end
      end
      JackAnalyzer::CompilationEngine.new(builder.to_xml, output_file_from(input_file)).compile_class!
      puts "processed #{input_file}"
    end
  end

  private

  def self.output_file_from(input_file)
    File.join(File.dirname(input_file), File.basename(input_file, ".*") + ".xml")
  end
end
