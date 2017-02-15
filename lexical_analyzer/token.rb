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
  attr_reader :val_name
  def initialize(token, line_info, index_info)
    super(token.upcase, line_info, index_info)
    case token
    when ";"
      @val_name = "SEMICOLON"
    when ","
      @val_name = "COLON"
    when "."
      @val_name = "DOT"
    when "+"
      @val_name = "ADDITION"
    when "-"
      @val_name = "SUBTRACTION"
    when "["
      @val_name = "LEFT-SQUARE-BRACKET"
    when "]"
      @val_name = "RIGHT-SQUARE-BRACKET"
    when "("
      @val_name = "LEFT-BRACKET"
    when ")"
      @val_name = "RIGHT-BRACKET"
    when "{"
      @val_name = "LEFT-CURLY-BRACKET"
    when "}"
      @val_name = "RIGHT-CURLY-BRACKET"
    when "<"
      @val_name = "LESS-THAN"
    when ">"
      @val_name = "GREATER-THAN"
    when ">="
      @val_name = "GREATE-OR-EQUAL"
    when "<="
      @val_name = "LESS-OR-EQUAL"
    when "<>"
      @val_name = "TEMPLATE"
    when "/"
      @val_name = "DIVISION"
    when "*"
      @val_name = "MULTIPLICATION"
    when "/*"
      @val_name = "COMMENT-START"
    when "*/"
      @val_name = "COMMENT-END"
    when "//"
      @val_name = "COLON"
    when "and"
      @val_name = "AND"
    when "or"
      @val_name = "OR"
    when "not"
      @val_name = "NEGATION"
    when "=="
      @val_name = "COMPARISION"
    when "="
      @val_name = "ASSIGMENT"
    end
  end
end
