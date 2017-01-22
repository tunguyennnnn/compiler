require_relative 'tokenizer'
require "minitest/autorun"

class TestTokenizer < Minitest::Test

  # Test operators that can be occured individually such as ; , . [ etc
  def test_single_operator
    tokens = tokenize(";,[]")
    #test type of token
    assert_equal("OperatorToken", tokens.first.class.name)

    #test value of token
    assert_equal("SEMICOLON", tokens.first.val)
    assert_equal("RIGHT-SQUARE-BRACKET", tokens.last.val)

    #test position of [
    assert_equal(1, tokens[2].line_info)
    assert_equal(2, tokens[2].start_index)
    assert_equal(3, tokens[2].end_index)
  end

  #test composed operators such as <> <=
  def test_compose_operator
    tokens = tokenize("<><=<>=")

    #test type of token
    assert_equal("OperatorToken", tokens.first.class.name)

    #test values
    assert_equal("TEMPLATE", tokens.first.val)
    assert_equal("LESS-OR-EQUAL", tokens[1].val)
    assert_equal("TEMPLATE", tokens[2].val)
    assert_equal("ASSIGMENT", tokens.last.val)

    #test position of <=
    assert_equal(1, tokens[1].line_info)
    assert_equal(2, tokens[1].start_index)
    assert_equal(4, tokens[1].end_index)
  end

  # test word operator such as and or not
  def test_word_operator
    tokens = tokenize("and or")

    #test type of token
    assert_equal("OperatorToken", tokens.first.class.name)

    #test values
    assert_equal("AND", tokens.first.val)
    assert_equal("OR", tokens.last.val)

    #test position
    assert_equal(4, tokens.last.start_index)
    assert_equal(6, tokens.last.end_index)
  end

  # test key words such as if else then etc
  def test_key_word
    tokens = tokenize("if then else")
    #test type of token
    assert_equal("KeyWordToken", tokens.first.class.name)

    #test values
    assert_equal("IF", tokens.first.val)
    assert_equal("THEN", tokens[2].val)
    assert_equal("ELSE", tokens.last.val)

    #test position
    assert_equal(8, tokens.last.start_index)
    assert_equal(12, tokens.last.end_index)
  end

  #test idenditifer
  def test_identifier
    tokens = tokenize("x xy x_y xy11 x_1_yy")
    #test type of token
    assert_equal("IdToken", tokens.first.class.name)

    #test values
    assert_equal("x", tokens.first.val)
    assert_equal("xy", tokens[2].val)
    assert_equal("x_y", tokens[4].val)
    assert_equal("xy11", tokens[6].val)
    assert_equal("x_1_yy", tokens.last.val)

    #test position
    assert_equal(14, tokens.last.start_index)
    assert_equal(20, tokens.last.end_index)
  end

  # test integer number
  def test_integer
    tokens = tokenize("0 123 9")
    #test type of token
    assert_equal("IntegerToken", tokens.first.class.name)

    #test values
    assert_equal("0", tokens.first.val)
    assert_equal("123", tokens[2].val)
    assert_equal("9", tokens[4].val)
  end

  # test float number
  def test_float
    tokens = tokenize("0.022 123.231 9.321")
    #test type of token
    assert_equal("FloatToken", tokens[2].class.name)

    #test values
    assert_equal("0.022", tokens.first.val)
    assert_equal("123.231", tokens[2].val)
    assert_equal("9.321", tokens[4].val)
  end

  #test special case of float number

  def test_special_float
    tokens = tokenize("20.0 0.0")
    #test type of token
    assert_equal("FloatToken", tokens[2].class.name)

    #test values
    assert_equal("20.0", tokens.first.val)
    assert_equal("0.0", tokens.last.val)

    #test position
    assert_equal(5, tokens.last.start_index)
    assert_equal(8, tokens.last.end_index)
  end

  # test multiple tokens
  def test_multiple_tokens
  end

end
