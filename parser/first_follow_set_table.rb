class FirstFollowSetTable
  attr_reader :table
  def initialize
    @table = {}
  end

  def insert_from_file(file_name)
    file = File.open(file_name, "r")
    line = ""
    while line = file.gets do
      nullable = false
      partitions = line.split(/\s+/)
      key = partitions[0]
      first_set, follow_set = [], []
      current_set = first_set
      partitions[1..-1].each do |word|
        if word == ","
          current_set.push(",")
          current_set = follow_set
        elsif word == "Nullable"
          nullable = true
        elsif word.include? ','
          if word == ",,"
            current_set.push(",")
          else
            current_set.push(word.gsub(',', ''))
          end
        else
          current_set.push(word)
          current_set = follow_set
        end
      end
      @table[key] = FirstFollowSet.new(first_set, follow_set, nullable)
    end
  end
end

class FirstFollowSet
  attr_reader :first_set, :follow_set, :nullable

  def initialize(first_set, follow_set, nullable)
    @first_set = first_set
    @follow_set = follow_set
    @nullable = nullable
  end

  def first_set_include? token
    if token.kind_of? IntegerToken
      @first_set.include? "integerNumber"
    elsif token.kind_of? FloatToken
      @first_set.include? "floatNumber"
    elsif token.kind_of? IdToken
      @first_set.include? "id"
    else
      @first_set.include? token.val.downcase
    end
  end

  def follow_set_include? token
    if token.kind_of? IntegerToken
      @follow_set.include? "integerNumber"
    elsif token.kind_of? FloatToken
      @follow_set.include? "floatNumber"
    elsif token.kind_of? IdToken
      @follow_set.include? "id"
    else
      @follow_set.include? token.val.downcase
    end
  end
end
