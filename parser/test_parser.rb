require_relative 'parser'
require "minitest/autorun"

class TestReadSet < Minitest::Test

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

  
end
