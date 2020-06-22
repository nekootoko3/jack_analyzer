require "nokogiri"
require "optparse"

require "jack_analyzer/jack_tokenizer"
require "jack_analyzer/compilation_engine"
require "jack_analyzer/compilation_engine_xml"

module JackAnalyzer
  class Cli
    def self.start(options = nil)
      new(options).start
    end

    def initialize(options = nil)
      if options
        @options = options
        return
      end

      @options = {}
      OptionParser.new do |opts|
        opts.on("-x", "--xml") do |x|
          @options[:xml] = x
        end
        opts.on("-d", "--debug") do |d|
          @options[:debug] = d
        end
      end.parse!
    end

    def start
      input = ARGV[0]
      if input.nil?
        raise "Input file specified"
      end

      input_files = case File.ftype(input).to_sym
        when :file
          [input]
        when :directory
          Dir.glob("#{input}/*.jack")
        else
          raise "Invalid file type #{File.ftype(input)}"
        end

      input_files.each do |input_file|
        puts "processing #{input_file}..."

        output = @options[:debug] ? $stdout : output_file_from(input_file)
        tokenizer = JackAnalyzer::JackTokenizer.new(input_file)
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.tokens do |t|
            while tokenizer.has_more_tokens?
              tokenizer.advance!
              t.send tokenizer.token_type, tokenizer.token
            end
          end
        end
        engine.new(builder.to_xml, output).compile_class!
        puts "processed #{input_file}"
      end
    end

    private

    def output_file_from(input_file)
      ext = @options[:xml] ? ".xml" : ".vm"
      File.join(File.dirname(input_file), File.basename(input_file, ".*") + ext)
    end

    def engine
      @options[:xml] ?
        JackAnalyzer::CompilationEngineXml :
        JackAnalyzer::CompilationEngine
    end
  end
end
