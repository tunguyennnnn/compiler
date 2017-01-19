class Token

end

class IdToken < Token
  def initialize(token)
    @val = token
  end
end


class KeyWordToken < Token
  def initialize(token)
    @val = token
  end
end

class NumberToken < Token
  def initialize(number)
    @val = number
  end
end

class IntegerToken < NumberToken

end

class FloatToken < NumberToken
end


LETTER = []
DIGIT = []
NON_ZERO = []
WHITE_SPACE = ["\t", ' ', '\n']

KEY_WORDS = ["if", "then", "else", "for", "class", "int", "float", "get", "put", "return", "program"]
OPERATOR = ["==", "<>", "<", "<=", ">", ">=", ";", ",", ".", "+", "-", "*", "/", "=",
            "and", "not", "or", "[", "]", "{", "}", "(", ")", "/*", "*/", "//"]


WORD_OPERATORS = ["and", "not", "or"]

SINGLE_OPERATOR = [";", ",", "+", "-", "[", "]", "{", "}", "(", ")"]


class OperatorToken
  attr_reader :type
  def initialize(simple)
    @val = nil
    case simple
    when ";"
      @val = "SEMICOLON"
    when ","
      @val = "COLON"
    when "."
      @val = "COLON"
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
  position = 0
  while position < chars.length
    char = chars[position]
    case char
    when "="
      position +=1
      next_char = chars[position]
      if next_char == "="
        tokens.push(OperatorToken.new("=="))
        position += 1
      else
        tokens.push(OperatorToken.new(char))
      end
    when "<"
      if next_char == ">"
        tokens.push(OperatorToken.new("<>"))
        position += 1
      elsif next_char == "="
        tokens.push(OperatorToken.new("<="))
        position += 1
      else
        tokens.push(OperatorToken.new(char))
      end
    when ">"
      position +=1
      next_char = chars[position]
      if next_char == "="
        tokens.push(OperatorToken.new(">="))
        position += 1
      else
        tokens.push(OperatorToken.new(char))
      end
    when *SINGLE_OPERATOR
      tokens.push(OperatorToken.new(char))
      position += 1
    when "*"
      position +=1
      next_char = chars[position]
      if next_char == "/"
        tokens.push(OperatorToken.new("*/"))
        position += 1
      else
        tokens.push(OperatorToken.new(char))
      end
    when "/"
      position +=1
      next_char = chars[position]
      if next_char == "/"
        tokens.push(OperatorToken.new("//"))
        position += 1
      elsif next_char = "*"
        tokens.push(OperatorToken.new("/*"))
        position += 1
      else
        tokens.push(OperatorToken.new(char))
      end

    when *LETTER
      accum = char
      position += 1
      next_char = chars[position]
      while LETTER.include?(chars[position]) || DIGIT.include?(chars[position]) || chars[position] == '_'
        accum += chars[position]
        position += 1
        next_char = chars[position]
      end
      if KEY_WORDS.include?(accum)
        tokens.push(KeyWordToken.new(accum))
      elsif WORD_OPERATORS.include?(accum)
        tokens.push(OperatorToken.new(accum))
      else
        tokens.push(IdToken.new(accum))
      end
    when *DIGIT
      position += 1
      next_char = chars[position]
      float = false
      accum = char
      if char == "0"
        if next_char == "."
          float = true
        else
        end
      else
        while DIGIT.include?(next_char)
          acum += next_char
          position += 1
          next_char = chars[position]
        end
        if next_char == "."
          float = true
        else
        end
        if float
          accum += "."
          position += 1
          next_char = chars[position]
          if DIGIT.include?(next_char)
            while DIGIT.include?(next_char)
              accum += next_char
              position += 1
              next_char = chars[position]
            end
            if NON_ZERO.include?(accum.last)
            else
            end
        else
        end
      end
    end
  end
end
