require_relative 'tokenizer'
def run
  puts ARGV[0]
  input_file = ARGV[0]
  output_file = ARGV[1]
  write_error = ARGV[2]
  tokenizer = Tokenizer.new
  tokenizer.read_file(input_file)
  tokenizer.tokenize
  tokenizer.write_error if write_error
  tokenizer.remove_error
  tokenizer.write_to_file(output_file)
end


if ARGV.length > 0
  run()
end
