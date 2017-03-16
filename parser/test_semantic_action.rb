require_relative 'parser'
require "minitest/autorun"

class TestSemanticAction < Minitest::Test
  def setup
    set_table = FirstFollowSetTable.new
    set_table.insert_from_file 'set_table.txt'
    @set_table = set_table.table
  end

  def test_wrong_program_using_primitive_type
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class FirstClass {
      int x1;
      float x2;
      int x3[1][2][3];

      float method1(int x, float y){
        float y1[1][2][4];
      };

      float method2(OtherType y){

      };
    };
    program{ };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(false, parser.correct_semantic)
  end

  def test_wrong_program_using_new_type_1
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class FirstClass {
      int x1;
      float x2;
      int x3[1][2][3];

      float method1(int x, float y){
        float y1[1][2][4];
      };

      float method2(OtherType y){
        FirstClass var;
      };
    };
    program{
      FirstClass y[0][0][0];
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(false, parser.correct_semantic)
  end

  def test_semantic_error_in_program_repeated_var
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    program{
      int x;
      int y[0][1][2];
      float y;
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(false, parser.correct_semantic)
  end

  def test_semantic_error_in_function_header_repeated
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    program{
      int x;
      float y;
    };
    float y(){
      int x;
    };
    int f(int y[2][3], float y){
      float z;
    };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(false, parser.correct_semantic)
  end

  def test_semantic_error_in_function_body
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    program{
      int x;
      int y[0][1][2];
      float y;
    };
    int f(int y[2][3]){
      float z;
      int z;
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(false, parser.correct_semantic)
  end

  def test_semantic_error_function_header_and_body
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    program{
      int x;
      int y[0][1][2];
      float y;
    };
    int f(int y[2][3]){
      float y;
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(false, parser.correct_semantic)
  end

  def test_semantic_error_same_variable_in_class
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class X{
      int x;
      float x;
    };
    program{
    };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(false, parser.correct_semantic)
  end

  def test_semantc_error_in_class_using_non_exsiting_type
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class X{
      int x;
      Sometype y[1][2][3];
    };
    program{
    };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(false, parser.correct_semantic)
  end

  def test_semantic_error_in_class_using_circular_type
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class FirstType{
      int x;
      SecondType y[0][1];
    };
    class SecondType{
      FirstType z[1];
    };
    program{
      int x;
    };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(false, parser.correct_semantic)
  end

  def test_semantic_error_in_class_method_no_type
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class FirstType{
      int x;
      SecondType f(){
      };
    };
    program{
      int x;
    };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(false, parser.correct_semantic)
  end

  def test_semantic_error_in_class_method_header
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class FirstType{
      int x;
      SecondType f(){
      };
    };
    class SecondType{
      FirstType f(int x, FirstType x){
        float y;
      };
    };
    program{
      int x;
    };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(false, parser.correct_semantic)
  end

  def test_semantic_error_in_class_method_body
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class FirstType{
      int x;
      SecondType f(){
        int y;
        float y;
      };
    };
    class SecondType{
      FirstType f(int x){
        float y;
      };
    };
    program{
      int x;
    };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(false, parser.correct_semantic)
  end

  def test_semantic_error_in_class_method_body
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class FirstType{
      int x;
      SecondType f(SecondType y){
        int y;
      };
    };
    class SecondType{
      FirstType f(int x){
        float y;
      };
    };
    program{
      int x;
    };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(false, parser.correct_semantic)
  end

  #test correct program

  def test_semantic_correct_1
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class FirstType{
      int x;
      SecondType f(FirstType aVar){
        int y;
        y = 3;
      };
    };
    class SecondType{
      FirstType f(int x){
        float y;
      };
    };
    program{
      int x;
    };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(true, parser.correct_semantic)
  end

end
