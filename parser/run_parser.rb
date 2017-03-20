require_relative 'parser'


def run_parser
  puts ARGV[0]
  input_file = ARGV[0]

  set_table = FirstFollowSetTable.new
  set_table.insert_from_file 'set_table.txt'
  table = set_table.table

  tokenizer = Tokenizer.new

  if input_file
    text = File.open(input_file).read()
    puts text
    tokenizer.text = text
  else
    tokenizer.text = "class ABC {};program {};"
  end
  tokenizer.tokenize
  tokenizer.remove_error
  parser = Parsing.new(tokenizer.tokens, table)
  puts "Parsing result is: #{parser.parse}"
  parser.write_to_file
  puts "Semantic result: #{parser.correct_semantic}"
  puts parser.construct_table(parser.global_table)
end


run_parser()
