class Token
  attr_reader :val, :line_info, :start_index, :end_index

  def initialize(token, line_info, index_info)
    @val = token
    @line_info = line_info
    @start_index = index_info
    @end_index = index_info +  token.length
  end

  def pretty_printing
    "Type: #{self.class.name}   Value: #{@val}   Line number: #{@line_info}   Index: #{@start_index}"
  end
end

class IdToken < Token
  def initialize(token, line_info, index_info)
    super(token, line_info, index_info)
  end
end


class KeyWordToken < Token
  def initialize(token, line_info, index_info)
    super(token.upcase, line_info, index_info)
  end
end

class NumberToken < Token
  def initialize(token, line_info, index_info)
    super(token, line_info, index_info)
  end
end

class IntegerToken < NumberToken
end

class FloatToken < NumberToken
end

class WhiteSpaceToken < Token
  def initialize(token, line_info, index_info)
    super(token, line_info, index_info)
  end
end

class ErrorToken < Token
  attr_reader :description
  def initialize(token, line_info, index_info, description)
    super(token, line_info, index_info)
    @description = description
  end

  def pretty_printing
    "Type: #{self.class.name}   Value: #{@val}   Line number: #{@line_info}   Index: #{@start_index}  Description: #{@description} \n"
  end
end


class OperatorToken <Token
  def initialize(token, line_info, index_info)
    super(token, line_info, index_info)
    case token
    when ";"
      @val = "SEMICOLON"
    when ","
      @val = "COLON"
    when "."
      @val = "DOT"
    when "+"
      @val = "ADDITION"
    when "-"
      @val = "SUBTRACTION"
    when "["
      @val = "LEFT-SQUARE-BRACKET"
    when "]"
      @val = "RIGHT-SQUARE-BRACKET"
    when "("
      @val = "LEFT-BRACKET"
    when ")"
      @val = "RIGHT-BRACKET"
    when "{"
      @val = "LEFT-CURLY-BRACKET"
    when "}"
      @val = "RIGHT-CURLY-BRACKET"
    when "<"
      @val = "LESS-THAN"
    when ">"
      @val = "GREATER-THAN"
    when ">="
      @val = "GREATE-OR-EQUAL"
    when "<="
      @val = "LESS-OR-EQUAL"
    when "<>"
      @val = "TEMPLATE"
    when "/"
      @val = "DIVISION"
    when "*"
      @val = "MULTIPLICATION"
    when "/*"
      @val = "COMMENT-START"
    when "*/"
      @val = "COMMENT-END"
    when "//"
      @val = "COLON"
    when "and"
      @val = "AND"
    when "or"
      @val = "OR"
    when "not"
      @val = "NEGATION"
    when "=="
      @val = "COMPARISION"
    when "="
      @val = "ASSIGMENT"
    end
  end
end
