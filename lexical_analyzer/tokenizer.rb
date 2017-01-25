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
  attr_reader :description
  def initialize(token, line_info, index_info, description)
    super(token, line_info, index_info)
    @description = description
  end
end

LETTER = ("a".."z").to_a + ("A".."Z").to_a
DIGIT = (0..9).to_a.map{|x| x.to_s}
NON_ZERO = (1..9).to_a.map{|x| x.to_s}
WHITE_SPACE = ["\t", ' ', '\n']

KEY_WORDS = ["if", "then", "else", "for", "class", "int", "float", "get", "put", "return", "program"]
LEGAL_SYMS = ["=", "<", ">", ";", ",", ".", "+", "-", "*", "/", "=",
             "[", "]", "{", "}", "(", ")"]


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

class Tokenizer
  attr_reader :tokens, :position, :line, :index
  attr_accessor :text
  LETTER = ("a".."z").to_a + ("A".."Z").to_a
  DIGIT = (0..9).to_a.map{|x| x.to_s}
  NON_ZERO = (1..9).to_a.map{|x| x.to_s}
  WHITE_SPACE = ["\t", ' ', '\n']
  KEY_WORDS = ["if", "then", "else", "for", "class", "int", "float", "get", "put", "return", "program"]
  WORD_OPERATORS = ["and", "not", "or"]
  SINGLE_OPERATOR = [";", ",", "+", "-", "[", "]", "{", "}", "(", ")", "."]

  COMPOSED_OPERATOR = {"=" => ["="],
                       ">" => ["="],
                       "<" => [">", "="],
                       "*" => ["/"],
                       "/" => ["/", "*"]}

  LEGAL_OPERATORS = WHITE_SPACE + SINGLE_OPERATOR + COMPOSED_OPERATOR.keys

  def initialize
    @tokens = []
    @position = 0
    @line = 1
    @index = 0
    @text = ''
  end

  def read_file(file_name)
  end

  def tokenize
    while @position < @text.length
      @char = @text[@position]
      increment
      case @char
      when *SINGLE_OPERATOR
        @tokens.push(OperatorToken.new(@char, @line, @index))
        @index += 1
      when *COMPOSED_OPERATOR.keys
        handle_composed_operator(@char, COMPOSED_OPERATOR[@char])
      when *LETTER
        handle_letter_token
      when *DIGIT
        handle_digit_token
      when *WHITE_SPACE
        if @char == "\n"
          @line += 1
        else
          @index += 1
        end
      end
    end
  end

  def handle_letter_token
    accumulator = @char
    until LEGAL_OPERATORS.include?(@next_char) || @next_char.nil?
      if can_follow_id?(@next_char)
        accumulator += @next_char
      else
        @tokens.push(ErrorToken.new(@next_char, @line, @index, "Ilegal character in variables: #{@next_char}"))
        @index += 1
      end
      increment
    end

    if KEY_WORDS.include?(accumulator)
      @tokens.push(KeyWordToken.new(accumulator, @line, @index))
    elsif WORD_OPERATORS.include?(accumulator)
      @tokens.push(OperatorToken.new(accumulator, @line, @index))
    else
      @tokens.push(IdToken.new(accumulator, @line, @index))
    end
    @index += accumulator.length
  end

  def can_follow_id?(char)
    LETTER.include?(char) || DIGIT.include?(char) || char == "_"
  end

  def handle_composed_operator(start_operator, follow_operators)
    if follow_operators.include?(@next_char)
      @tokens.push(OperatorToken.new(start_operator + @next_char, @line, @index))
      @index += 2
      increment
    else
      @tokens.push(OperatorToken.new(start_operator, @line, @index))
      @index += 1
    end
  end

  def handle_digit_token
    accumulator = @char
    float = false
    if @char == "0"
      if @next_char == "."
        float = true
      elsif DIGIT.include?(@next_char)
        @tokens.push(ErrorToken.new(@char, @line, @index, "Illegal number: starts with #{@char}"))
        @index += 1
      else
        @tokens.push(IntegerToken.new(@char, @line, @index))
        @index += 1
      end
    else
      while DIGIT.include?(@next_char)
        accumulator += @next_char
        increment
      end
      if @next_char == "."
        float = true
      else
        @tokens.push(IntegerToken.new(accumulator, @line, @index))
      end
    end

    if float
      accumulator += "."
      increment
      while DIGIT.include?(@next_char)
        accumulator += @next_char
        increment
      end

      if accumulator[-1] == "."
        @tokens.push(FloatToken.new(accumulator + "0", @line, @index))
        @index += (accumulator.length + 1)
      elsif accumulator[-1] == "0" && accumulator[-2] != "."
        error_accumulator = ""
        while accumulator[-2] != "."
          if accumulator[-1] == "0"
            error_accumulator += accumulator[-1]
            accumulator = accumulator[0..-2]
          else
            break
          end
        end
        @tokens.push(FloatToken.new(accumulator, @line, @index))
        @index += accumulator.length
        @tokens.push(ErrorToken.new(error_accumulator.reverse, @line, @index, "Ilegal Float #{accumulator}: follows by #{error_accumulator.reverse}"))
        @index += error_accumulator.length
      else
        @tokens.push(FloatToken.new(accumulator, @line, @index))
        @index += accumulator.length
      end
    end
  end

  def increment
    @position += 1
    @next_char = @text[@position]
  end

end
