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
    if self.has_key? symbol
      return false, self[symbol]
    else
      self[symbol] = val
      val.table = self
      return true, val
    end
  end
end
