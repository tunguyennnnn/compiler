class TableRow
  attr_accessor :type, :kind, :link
  def initialize(kind, type, link=nil)
    @kind = kind
    @type = type
    @link = link
  end
end

class SymbolTable < Hash
  attr_accessor :type, :parent
  def initialize(type,parent=nil) # parent = nil ->
    super()
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
      return true
    end
  end
end
