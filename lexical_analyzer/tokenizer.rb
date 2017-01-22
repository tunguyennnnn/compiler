class Token
  attr_reader :val, :line_info, :start_index, :end_index

  def initialize(token, line_info, index_info)
    @val = token
    @line_info = line_info
    @start_index = index_info
    @end_index = index_info +  token.length
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
  def initialize(token, line_info, index_info)
    super(token, line_info, index_info)
  end
end

LETTER = ("a".."z").to_a + ("A".."Z").to_a
DIGIT = (0..9).to_a.map{|x| x.to_s}
NON_ZERO = (1..9).to_a.map{|x| x.to_s}
WHITE_SPACE = ["\t", ' ', '\n']

KEY_WORDS = ["if", "then", "else", "for", "class", "int", "float", "get", "put", "return", "program"]
OPERATOR = ["==", "<>", "<", "<=", ">", ">=", ";", ",", ".", "+", "-", "*", "/", "=",
            "and", "not", "or", "[", "]", "{", "}", "(", ")", "/*", "*/", "//"]


WORD_OPERATORS = ["and", "not", "or"]

SINGLE_OPERATOR = [";", ",", "+", "-", "[", "]", "{", "}", "(", ")", "."]



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



def read_file(file_name)
  file = File.new(file_name, 'r')
  texts = []
  while line = file.gets
    texts.push(line)
  end
  file.close
  return texts
end


def tokenize(chars)
  tokens = []
  position = index = 0
  line = 1
  while position < chars.length
    char = chars[position]
    position +=1
    next_char = chars[position]
    case char
    when "="
      if next_char == "="
        tokens.push(OperatorToken.new("==", line, index))
        index += 2
        position += 1
      else
        index += 1
        tokens.push(OperatorToken.new(char, line, index))
      end
    when "<"
      if next_char == ">"
        tokens.push(OperatorToken.new("<>", line, index))
        index += 2
        position += 1
      elsif next_char == "="
        tokens.push(OperatorToken.new("<=", line, index))
        index += 2
        position += 1
      else
        tokens.push(OperatorToken.new(char, line, index))
        index += 1
      end
    when ">"
      if next_char == "="
        tokens.push(OperatorToken.new(">=", line, index))
        index += 2
        position += 1
      else
        tokens.push(OperatorToken.new(char, line, index))
        index += 1
      end
    when *SINGLE_OPERATOR
      tokens.push(OperatorToken.new(char, line, index))
      index += 1
    when "*"
      if next_char == "/"
        tokens.push(OperatorToken.new("*/", line, index))
        index += 2
        position += 1
      else
        tokens.push(OperatorToken.new(char, line, index))
        index +=1
      end
    when "/"
      if next_char == "/"
        tokens.push(OperatorToken.new("//", line, index))
        index +=2
        position += 1
      elsif next_char == "*"
        tokens.push(OperatorToken.new("/*", line, index))
        index += 2
        position += 1
      else
        tokens.push(OperatorToken.new(char, line, index))
        index += 1
      end

    when *LETTER
      accum = char
      while LETTER.include?(next_char) || DIGIT.include?(next_char) || next_char == '_'
        accum += next_char
        position += 1
        next_char = chars[position]
      end
      if KEY_WORDS.include?(accum)
        tokens.push(KeyWordToken.new(accum, line, index))
      elsif WORD_OPERATORS.include?(accum)
        tokens.push(OperatorToken.new(accum, line, index))
      else
        tokens.push(IdToken.new(accum, line, index))
      end
      index += accum.length
    when *DIGIT
      float = false
      accum = char
      if char == "0"
        if next_char == "."
          float = true
        elsif DIGIT.include?(next_char) || LETTER.include?(next_char)
          while DIGIT.include?(next_char) || LETTER.include?(next_char)
            accum += next_char
            position += 1
            next_char = chars[position]
          end
          tokens.push(ErrorToken.new(accum, line, index))
        else
          tokens.push(IntegerToken.new(char, line, index))
        end
      else
        while DIGIT.include?(next_char)
          accum += next_char
          position += 1
          next_char = chars[position]
        end
        if next_char == "."
          float = true
        elsif LETTER.include?(next_char)
          while LETTER.include?(next_char)
            accum += next_char
            position += 1
            next_char = chars[position]
          end
        else
          tokens.push(IntegerToken.new(accum, line, index))
        end
      end
      if float
        accum += "."
        position += 1
        next_char = chars[position]
        while DIGIT.include?(next_char)
          accum += next_char
          position += 1
          next_char = chars[position]
        end
        if accum[-1] == "." || accum[-1] == "0" && accum[-2] != "."
          tokens.push(ErrorToken.new(accum, line, index))
        else
          tokens.push(FloatToken.new(accum, line, index))
        end
      end
      index += accum.length
    when *WHITE_SPACE
      if char == '\n'
        line += 1
        index = 0
      else
        index += 1
      end
      tokens.push(WhiteSpaceToken.new(char, line, index))
    end
  end
  return tokens
end
