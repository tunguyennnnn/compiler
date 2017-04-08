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

  def test_semantic_correct_1
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class FirstType{
      int x;
      SecondType f(FirstType aVar, int z){
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

  def test_semantic_correct_1
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class FirstType{
      int x;
      float z[1][2][4];
      SecondType f(FirstType aVar){
        int y;
        y = 3;

      };
    };
    class SecondType{
      FirstType q[1][2];
      FirstType f(int x){
        float y;
      };
    };
    program{
      int x;
      FirstType y[1][2][3];
    };
    FirstType func2(SecondType q){
      FirstType x;
    };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
    assert_equal(true, parser.correct_semantic)
  end


  ##################TEST ATTRIBUTE MIGRATION####################

  def test_wrong_type_assignment
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        int x;
        x = 3.5;
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_correct_type_assignment
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        int x;
        x = 3;
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_wrong_type_assignment1
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        int x[1];
        x = 3;
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end
  def test_correct_type_assignment1
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        int x[1];
        x[0] = 3;
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_wrong_type_assignment2
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        float x[1];
        x[0] = 3;
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_correct_type_assignment2
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        float x[1];
        x[0] = 10.0;
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end


  def test_wrong_type_assignment3
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        float x[1];
        x[0] = 3 + 3;
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_correct_type_assignment3
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        float x[1];
        x[0] = 3.4 + 3;
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_wrong_type_assignment4
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        float x[1];
        x[0] = 3 * 3;
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_wrong_type_assignment4
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        float x[1];
        float z[1][2];
        int y;
        x[0] = 3 + z;
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end
  def test_correct_type_assignment5
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        float x[1];
        float z[1][2];
        int y;
        x[0] = 3 + z[0][0];
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end


  def test_correct_type_assignment6
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        float x[1];
        float z[1][2];
        int y;
        x[0] = y + z[0][1];
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_wrong_type_assignment7
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        float x[1];
        float z[1][2];
        int y;
        x[0] = 3 and z[0];
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_correct_type_assignment7
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        float x[1];
        float z[1][2];
        int y;
        x[0] = 3 and z[1][1];
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_wrong_argument_funcall
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        int x;
        x = 4;
        x = square(x, x);
      };
      int square(int x){
        return (x);
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_wrong_argument_funcall1
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        int x;
        x = 4;
        x = square();
      };
      int square(int x){
        return (x);
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_wrong_func_return_wrong_type
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        int x;
        x = 4;
        x = square(x);
      };
      int square(int x){
        float z;
        x = x * x;
        return (z);
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_correct_call
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        int x;
        x = 4;
        x = square(x);
      };
      int square(int x){
        x = x * x;
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_correct_funcall_assignment
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        int x;
        x = 4;
        x = square(x);
      };
      int square(int x){
        x = x * x;
        return (x);
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_correct_funcall_assignment1
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        int x;
        x = 4;
        x = square(x) + 100;
      };
      int square(int x){
        x = x * x;
        return (x);
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end


  def test_correct_funcall_assignment2
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        int x;
        x = 4;
        x = square(x) + 100.0;
      };
      int square(int x){
        x = x * x;
        return (x);
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end


  def test_correct_funcall_assignment1
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      program{
        int x;
        x = 4;
        x = square(x) + 100;
      };
      int square(int x){
        x = x * x;
        return (x);
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_class_type
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      class A{
        int x[10][10];
        int func1(A x){
          return (100);
        };
      };
      program{
        int x;
        A y;
        x = square(x) + y.x[1][1];
      };
      int square(int x){
        x = x * x;
        return (x);
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_class_type_wrong
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      class A{
        int x[10][10];
        int func1(A x){
          return (100);
        };
      };
      program{
        int x;
        A y;
        x = square(x) + y.x[1];
      };
      int square(int x){
        x = x * x;
        return (x);
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_class_type_correct
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      class A{
        int x[10][10];
        int func1(A x){
          return (100);
        };
      };
      program{
        int x;
        A y;
        x = square(x) + y.x[1][1];
      };
      int square(int x){
        x = x * x;
        return (x);
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_class_type_wrong1
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
      class A{
        int x[10][10];
        int func1(A x){
          return (100);
        };
      };
      program{
        int x;
        A y;
        x = square(x) + y.func1(x);
      };
      int square(int x){
        x = x * x;
        return (x);
      };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(false, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_class_type_correct2
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class Y{
      d p[1][2];
    };
    class d{
      Q x;
    };
    class Q{
      float x;
      int d[2][2][4];
    };
    program{
      Q y[1][2][3];
      int x;
      int d[1];
      x = 2;
      d[1]=10;
      x = d[1];
      x = 1 + 2;
      x = 2 + d[1];
      x = x +2;
      x = x + x + 5 + x;
      x = not x;
      x = x > x;
      x = x and d[1];
      if (x > 3) then {
        if (x > 20) then {
          x = 1;
        }else{
          x = d[1];
        };
      }else{
        x = 0;
      };
      for (int i = 0; i < 20; i = i + 10){
        x = 100;
      };
      y[1][1][1].x = y[1][2][1].x;
    };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end

  def test_class_type_correct2
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
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
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    parsing_is_correct = parser.parse
    if parsing_is_correct
      parser.tokens = @tokenizer.tokens
      parser.final_table = parser.global_table
      parser.final_table.generate_memory_allocation
      parser.second_pass = true
      parser.parse
      assert_equal(true, parser.correct_semantic)
    else
      throw "parsing error"
    end
  end
end
