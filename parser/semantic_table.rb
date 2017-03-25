class TableRow
  attr_accessor :type, :kind, :link, :table
  def initialize(table, kind, type, link=nil)
    @kind = kind
    @type = type
    @link = link
    @table = table
  end
end

class ClassRow < TableRow
  attr_accessor :reference_classes
  def initialize(table, kind, type, link=nil)
    super(table, kind, type, link)
    @reference_classes = []
  end

  def add_reference(class_name)
    @reference_classes.push(class_name)
  end
end

class MigrationType
  attr_accessor :type, :type_name, :size
  def initialize(type=nil, type_name = '', size = 0)
    @type = type
    @type_name = type_name
    @size = size
  end

  def copy_type_of(another_type)
    @type = another_type.type
    @type_name = another_type.type_name
    @size = another_type.size
  end

  def print_type
    puts "variable #{@type.val} type: #{@type_name} size: #{@size}"
  end

  def is_equal?(type)
    puts type
    if self.type_name == type[0] && self.size == type[1].size
      return true
    end
    return false
  end
end

class SymbolTable < Hash
  attr_accessor :type, :parent, :id
  def initialize(id,type,parent=nil) # parent = nil ->
    super()
    @id = id
    @type = type
    @parent = parent
  end

  def is_global?
    !@parent
  end

  def add_symbol(symbol, val)
    key = self.keys.keep_if{|k| k.val == symbol.val}
    if key.first
      return false, self[key.first]
    else
      self[symbol] = val
      val.table = self
      return true, val
    end
  end

  def get_table(id, type)
    match_key = self.keys.keep_if{ |key| key.val == id.val}.first
    return self[match_key].link
  end

  def find_type(id)
    match_key = self.keys.keep_if{ |key| key.val == id.val}.first
    if match_key
      return self[match_key].type
    else
      if self.parent
        return self.parent.table.find_type(id)
      else
        return nil
      end
    end
  end

  def find_class_table(class_name)
    match_key = self.keys.keep_if{|key| key.val == class_name}.first
    if match_key
      return self[match_key].link
    else
      return nil
    end
  end
end
