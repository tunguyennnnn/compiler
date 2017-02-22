require_relative 'parser'
require "minitest/autorun"

class TestParser < Minitest::Test

  def setup
    set_table = FirstFollowSetTable.new
    set_table.insert_from_file 'set_table.txt'
    @set_table = set_table.table
  end

  def test_empty_class
    @tokenizer = Tokenizer.new
    @tokenizer.text = "class ABC {};program {};"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_multiple_classes
    @tokenizer = Tokenizer.new
    @tokenizer.text = "class ABC {} ;class ABD{} ;class ABE{};program {};"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_single_program
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{ };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_single_program_with_fundefs
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{ }; int X_func(float x, Type2 y){}; float X_func(Type1 x, int y){};"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_single_class_program_with_fundefs
    @tokenizer = Tokenizer.new
    @tokenizer.text = "class X {};program{ }; int X_func(float x, Type2 y){}; float X_func(Type1 x, int y){};"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_class_body_varDecl
    @tokenizer = Tokenizer.new
    @tokenizer.text = "class FirstClass {
      int x1;
      SomeType x2;
      float x3[10][20][100];
      SomeOtherType x4[123][22][30];
    };
    program{ };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_class_body_with_FuncDefs
    @tokenizer = Tokenizer.new
    @tokenizer.text = "class FirstClass {
      int x1;
      SomeType x2;
      float x3[10][20][100];
      SomeOtherType x4[123][22][30];

      float method1(int x, SomeType y){
      };
      SomeType method2(OtherType y){

      };
    };
    program{ };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_class_body_with_only_FuncDefs
    @tokenizer = Tokenizer.new
    @tokenizer.text = "class FirstClass {

      float method1(int x, SomeType y){
      };

      SomeType method2(OtherType y){

      };
    };
    program{ };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end


  def test_class_body_with_wrong_order_of_varDecl_and_FuncDefs
    @tokenizer = Tokenizer.new
    @tokenizer.text = "class FirstClass {
      int x1;
      SomeType x2;

      float method1(int x, SomeType y){
      };

      float x3[10][20][100];
      SomeOtherType x4[123][22][30];

      SomeType method2(OtherType y){

      };
    };
    program{ };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_nil(parser.parse)
  end


  def test_fundef_header_1
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{};
    int first_func(){
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_fundef_header_with_primitive_types
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{};
    int first_func(int x, float y){
    };
    float first_func(int x, float y){
    };
    "
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_funcdef_header_with_new_type
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{};
    new_type1 first_func(new_type2 x, new_type3 y){
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_funcdef_header_with_mixed_type
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{};
    new_type1 first_func(new_type2 x, int y, float z, newType Y){
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_if_statement
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{};
    new_type1 first_func(new_type2 x, int y, float z, newType Y){
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_class_funcBody_with_varDecls
    @tokenizer = Tokenizer.new
    @tokenizer.text = "class FirstClass {
      float method1(int x, SomeType y){
        int x1;
        SomeType x2[1][2][4];
        x1 = 10;
      };

    };
    program{ };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_class_funcBody_with_onlyStatments
    @tokenizer = Tokenizer.new
    @tokenizer.text = "class FirstClass {
      float method1(int x, SomeType y){
        if (x == 3) then
          x = y.x[1];
        else
          x = 5;
        ;
        x[1][2] = newVar;
        return (x.y);
      };

    };
    program{ };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_class_funcBody_with_varDecls_and_statments
    @tokenizer = Tokenizer.new
    @tokenizer.text = "class FirstClass {
      float method1(int x, SomeType y){
        int x1;
        SomeType x2[1][2][4];
        x1 = 10;
        put (x[1][2].y[1][2]);

        if (x == 3) then
          x = y.x[1];
        else
          x = 5;
        ;
        return (x.y);
      };

    };
    program{ };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_class_funcBody_with_varDecls_and_statments
    @tokenizer = Tokenizer.new
    @tokenizer.text = "class FirstClass {
      float method1(int x, SomeType y){
        int x1;
        SomeType x2[1][2][4];
        x1 = 10;
        put (x[1][2].y[1][2]);

        if (x == 3) then
          x = y.x[1];
        else
          x = 5;
        ;
        return (x.y);
      };

    };
    program{ };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_class_funcBody_with_varDecls_and_statments_wrong_order
    @tokenizer = Tokenizer.new
    @tokenizer.text = "class FirstClass {
      float method1(int x, SomeType y){
        int x1;
        SomeType x2[1][2][4];
        x1 = 10;
        put (x[1][2].y[1][2]);

        if (x == 3) then
          x = y.x[1];
        else
          x = 5;
        ;

        int x1;
        SomeType x2[1][2][4];
        return (x.y);
      };

    };
    program{ };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_nil(parser.parse)
  end

  def test_programBody
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{
      int x1;
      SomeType x2[1][2][4];
      x1 = 10;
      put (x[1][2].y[1][2]);

      if (x == 3) then
        x = y.x[1];
      else
        x = 5;
        ;
      return (x.y);
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end


  #test details:

  def test_assign_statement_and_expr
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{
      float x;
      Type_Z z;
      int y;
      y = 100;
      x = 0.123;
      x = 0.123 * 10.10 + 100 - 100 + 20.2;
      y = 1 + 2 * 3 + 4/5;
      z = x*y + 3 * (x and y) + 5 - -3 + +4;
      z = x[1][1] * y[4].z[2][2]  or x + 3 and (x * 3);
      x = y ++ 3;

      x = y > x;
      x = y > (x + 3);
      x = y == (x[y].d[2] and y[3] or x);
      z = (a + b[2][3]) <= 3;
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_if_statement
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{
      y = 4;
      if ( x >= 20.0) then
        return (x);
      else{

      };

      if ( x + 10 >= 20.0) then{
        if (x ++3 <> y[1][2]) then {
          return (x);
        }else;
      }
      else{
        if (x and y[2][3] + 100) then
        else
          if (y - 10 <= y) then{
            get (x[1][2][3]);
            return (x and y);
          }
          else
            return (not x);
          ;
        ;
      };

    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_for_statement
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{
      X_type x[1][2][3];
      x[1] = 100;
      for(int i = 0; i < 100; i = i ++1){
        x[2] = 100 + x[3][4];
        for (X_type y = x[1] + x[3]; y[2] >= x[1]; y[2] = x[1] and x[2]){
          put (x[1][2] and y[1][2]);
          get (x[2][100]);
          if (x[2] < y[2]) then {
            return (x[3].run() or x[1].run());
          }else;
        };
      };
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def function_call_aParams
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{
      X_type x[1][2][3];
      x = y.func() and y.run();
      x = x.run(a, b);
      x = x.run(a + b, b and b[a] + 3 * (x + y[1][2]), 1, 2, 3.23);
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  def test_big_program
    @tokenizer = Tokenizer.new
    @tokenizer.text = "
    class Utility{
      int var1[4][5][7][8][9][1][0];
      float var2;
      int findMax(int array[100]){
        int maxValue;
        int idx;
        maxValue = array[100];
        for( int idx = 99; idx > 0; idx = idx - 1 )
        {
          if(array[idx] > maxValue) then {
          maxValue = array[idx];
          }else{};
        };
        return (maxValue);
      };
      int findMin(int array[100])
        {
          int minValue;
          int idx;
          minValue = array[100];
          for( int idx = 1; idx <= 99; idx = ( idx ) + 1)
          {
          if(array[idx] < maxValue) then {
            maxValue = array[idx];
          }else{};
        };
        return (minValue);
      };
    };
    program {
      int sample[100];
      int idx;
      int maxValue;
      int minValue;
      Utility utility;
      Utility arrayUtility[2][3][6][7];
      for(int t = 0; t<=100 ; t = t + 1)
      {
        get(sample[t]);
        sample[t] = (sample[t] * randomize());
      };
      maxValue = utility.findMax(sample);
      minValue = utility.findMin(sample);
      utility. var1[4][1][0][0][0][0][0] = 10;
      arrayUtility[1][1][1][1].var1[4][1][0][0][0][0][0] = 2;
      put(maxValue);
      put(minValue);
    };
    float randomize(){
      float value;
      value = 100 * (2 + 3.0 / 7.0006);
      value = 1.05 + ((2.04 * 2.47) - 3.0) + 7.0006 ;
      return (value);
    };
    float run_program(int x, X_type x){
      for(int x = 0; x <= y and z; y = y + x[2]){
        if(array[idx] < maxValue) then {
          maxValue = array[idx];
        }else{};
      };
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table)
    assert_equal(true, parser.parse)
  end

  #error recovery:
  def test_recovery_array_size
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{
      X_type x[1]2]2][3];
    };
    int randomize(X_type x[1]2][2], int y[2]){

    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table, true)
    assert_equal(true, parser.parse)
    parser.tokens.each do |token|
      puts token.val
    end
    new_parser = Parsing.new(parser.tokens, @set_table)
    assert_equal(true, new_parser.parse)
  end

  def test_func_call_recovery
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{
      x = a(a, b,);
      x = a(a + 2 and y,);
    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table, true)
    assert_equal(true, parser.parse)

    new_parser = Parsing.new(parser.tokens, @set_table)
    assert_equal(true, new_parser.parse)
  end

  def test_funcdef_error_recovery
    @tokenizer = Tokenizer.new
    @tokenizer.text = "program{
      x = a(a, b,);
      x = a(a + 2 and y,);
    };
    int f(int x, float y,){

    };
    float func2(X_y time, ){

    };"
    @tokenizer.tokenize
    @tokenizer.remove_error
    parser = Parsing.new(@tokenizer.tokens, @set_table, true)
    assert_equal(true, parser.parse)

    new_parser = Parsing.new(parser.tokens, @set_table)
    assert_equal(true, new_parser.parse)
  end
end
