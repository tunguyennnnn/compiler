require_relative 'token'


class Tokenizer
  attr_reader :tokens, :position, :line, :index
  attr_accessor :text

  LETTER = ("a".."z").to_a + ("A".."Z").to_a
  DIGIT = (0..9).to_a.map{|x| x.to_s}
  NON_ZERO = (1..9).to_a.map{|x| x.to_s}
  WHITE_SPACE = ["\t", ' ', "\n"]
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
    file = File.new(file_name, 'r')
    while (line = file.gets)
      @text += line
    end
    file.close
  end


  def write_to_file(file_name)
    File.open(file_name, 'w+'){|file|
      file.write(@tokens.map{|tk| tk.pretty_printing}.join("\n"))
    }
  end

  def write_error
    File.open('error.txt', 'w+'){ |file|
      @tokens.each do |token|
        if token.class == ErrorToken
          file.write(token.pretty_printing)
        end
      end
    }
  end

  def remove_error
    @tokens.delete_if do |token|
      token.class == ErrorToken
    end
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
          @index = 0
        else
          @index += 1
        end
      else
        tokens.push(ErrorToken.new(@char, @line, @index, "Illegal Symbol #{@char}"))
        @index += 1
      end
    end
  end

  def handle_single_line_comment
    until @next_char == "\n"
      increment
    end
    increment
    @line += 1
  end

  def handle_multiple_line_comment
    counter = 1
    done = false
    until done or @next_char.nil?
      if @next_char == "*"
        increment
        if @next_char == "/"
          if counter ==  1
            done = true
          else
            counter -= 1
          end
        end
        increment
      elsif @next_char == "/"
        increment
        if @next_char == "*"
          counter += 1
        end
        increment
      elsif @next_char == "\n"
        @line += 1
        increment
      else
        increment
      end
    end
  end

  def handle_letter_token
    accumulator = @char
    while can_follow_id?(@next_char)
      accumulator += @next_char
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
    if start_operator == "/"
      puts @next_char
      if @next_char == "/"
        increment
        handle_single_line_comment
      elsif @next_char == "*"
        increment
        handle_multiple_line_comment
      else
        @tokens.push(OperatorToken.new(start_operator, @line, @index))
        increment
      end
    elsif follow_operators.include?(@next_char)
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
