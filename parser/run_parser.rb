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
    tokenizer.text = "
    class Q{
      int d[2][2][4];
      int w(int x, float y){
        for (int i = 0; i < 100; i = i+ 1){

        };  
        return (x);
      };
    };
    program {
    int x[1];
    Q y[2][3];
    Q z;
    x[1] = 3 + 10 - 20;
    y[2][1].d[2][1][2] = 1 + z.w(1, 2.4);
    };"
  end
  tokenizer.tokenize
  tokenizer.remove_error
  parser = Parsing.new(tokenizer.tokens.dup, table)
  puts "Parsing result is: #{parser.parse}"
  parser.write_to_file
  puts "Semantic result: #{parser.correct_semantic}"
  puts parser.construct_table(parser.global_table)
  parser.tokens = tokenizer.tokens
  parser.final_table = parser.global_table
  parser.second_pass = true
  parser.parse
end


run_parser()
