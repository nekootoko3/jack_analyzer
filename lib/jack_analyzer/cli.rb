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

    attr_reader :options, :jack_path, :engine
    attr_accessor :jack_files

    def initialize(options = nil)
      @vm_path = ARGV[0]

      if options
        @options = options
      else
        @options = parse_options
      end

      @engine = @options[:xml] ?
        JackAnalyzer::CompilationEngineXml :
        JackAnalyzer::CompilationEngine
    end

    def start
      load_jack_files!

      jack_files.each do |jack_file|
        puts "processing #{jack_file}..."

        tokenizer = JackAnalyzer::JackTokenizer.new(jack_file)
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.tokens do |t|
            while tokenizer.has_more_tokens?
              tokenizer.advance!
              t.send tokenizer.token_type, tokenizer.token
            end
          end
        end
        engine.new(builder.to_xml, output).compile_class!
        puts "processed #{jack_file}"
      end
    end

    private

    def parse_options
      parsed_options = {}
      OptionParser.new do |opts|
        opts.on("-x", "--xml") do |x|
          parsed_options[:xml] = x
        end
        opts.on("-d", "--debug") do |d|
          parsed_options[:debug] = d
        end
      end.parse!
      parsed_options
    end

    def load_jack_files!
      raise ArgumentError, "jack file or directory not specified" unless jack_path

      @jack_files = case File.ftype(jack_path).to_sym
        when :file
          [jack_path]
        when :directory
          Dir.glob("#{jack_path}/*.jack")
        else
          raise "Invalid file type #{File.ftype(jack_path)}"
        end
    end

    def output
      return @output if defined?(@output)

      @output = options[:debug] ? $stdout : output_file_from(jack_file)
    end

    def output_file_from(jack_file)
      ext = options[:xml] ? ".xml" : ".vm"
      File.join(File.dirname(jack_file), File.basename(jack_file, ".*") + ext)
    end
  end
end
