require_relative 'tokenizer'
require "minitest/autorun"

class TestReadSet < Minitest::Test
  def test_empty_class
  end

  def test_empty_program
    program = "program {};"
  end

  def test_simple_program1
    program = "program{ int x;}"
  end
end
