require "jack_compiler/jack_tokenizer"

module JackCompiler::Cli
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

      output_file = File.open(
        File.join(File.dirname(input_file), File.basename(input_file, ".*") + ".xml"),
        "w+"
      )
      tokenizer = JackCompiler::JackTokenizer.new(input_file)

      output_file.puts("<tokens>")
      while tokenizer.has_more_tokens?
        tokenizer.advance!
        output_file.puts("<#{tokenizer.token_type}> #{tokenizer.token} </#{tokenizer.token_type}>")
      end
      output_file.puts("</tokens>")

      puts "processed #{input_file}"
    end
  end
end
