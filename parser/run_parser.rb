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
    class Y{
      d p[1][2];
    };
    class d{
      Q x;
    };
    class Q{
      float x;
      int d[2][2][4];
      int w(int x, float y){
        for (int i = 0; i < 100; d[2][2][4] = i+ 1){
          if (i > 10) then{
             d[2][2][4] = i+ 1;
          }else{
            i = i -1;
          };
        };
        return (x);
      };
    };
    program {
    int o;
    int x[1][3];
    Q y[2][3];
    Q z;
    x[1][2] = 3 + 10 - 20;
    y[2][1].d[2][1][2] = 1 + z.w(1, 2.4);
    };"

    # tokenizer.text = "
    # class Y{
    #   d p[1][2];
    # };
    # class d{
    #   Q x;
    # };
    # class Q{
    #   float x;
    #   int d[2][2][4];
    # };
    # program{
    #   Q y[1][2][3];
    #   int x;
    #   int d[1];
    #   x = 2;
    #   d[1]=10;
    #   x = d[1];
    #   x = 1 + 2;
    #   x = 2 + d[1];
    #   x = x +2;
    #   x = x + x + 5 + x;
    #   x = not x;
    #   x = x > x;
    #   x = x and d[1];
    #   if (x > 3) then {
    #     if (x > 20) then {
    #       x = 1;
    #     }else{
    #       x = d[1];
    #     };
    #   }else{
    #     x = 0;
    #   };
    #   for (int i = 0; i < 20; i = i + 10){
    #     x = 100;
    #   };
    #   y[1][1][1].x = y[1][2][1].x;
    # };
    # "

  # tokenizer.text = "
  #   class A{
  #     int x[10][10];
  #     int func1(A x){
  #       return (100);
  #     };
  #   };
  #   program{
  #     int x;
  #     A y;
  #     x = square(x) + y.func1(y) * x and x;
  #   };
  #   int square(int x){
  #     x = x * x;
  #     return (x);
  #   };
  # "
  end
  tokenizer.tokenize
  tokenizer.remove_error
  parser = Parsing.new(tokenizer.tokens.dup, table)
  parsing_is_correct = parser.parse
  puts "Parsing result is: #{parsing_is_correct || "False"}"
  parser.write_to_file

  if parsing_is_correct
    puts "Semantic result first pass is: #{parser.correct_semantic}"
    puts parser.construct_table(parser.global_table)
    parser.tokens = tokenizer.tokens
    parser.final_table = parser.global_table
    parser.final_table.generate_memory_allocation
    parser.second_pass = true
    parser.parse
    puts "Semantic result second pass is: #{parser.correct_semantic}"
    File.open("codes.m", 'w') do |f|
      codes = ""
      parser.code_generation.each do |line|
        codes += line + "\n"
      end
      f.write codes
    end
  end
end


run_parser()
