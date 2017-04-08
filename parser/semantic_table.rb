require_relative 'moon_interface'

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
  attr_accessor :type, :type_name, :size, :array, :is_function, :params
  def initialize(type=nil, type_name = '', size = 0, array = [], is_function=false, params = [])
    @type = type
    @type_name = type_name
    @size = size
    @array = array
    @is_function = is_function
    @params = params
  end

  def copy_type_of(another_type)
    @type = another_type.type
    @type_name = another_type.type_name
    @size = another_type.size
    @array = another_type.array
    @is_function = another_type.is_function
    @params = another_type.params
  end

  def print_type
    puts "variable #{@type.val} type: #{@type_name} size: #{@size} array: #{@array} is function: #{@is_function}" if @type
  end

  def is_equal?(type)
    if self.type_name == type[0] && self.size == type[1].size
      return true
    end
    return false
  end
end

class SymbolTable < Hash
  attr_accessor :type, :parent, :id, :memory_allocation
  def initialize(id,type,parent=nil) # parent = nil ->
    super()
    @id = id
    @type = type
    @parent = parent
    @loop_index = 1
    @get_for_loop = 1
    @moon_interface = MoonInterface.new
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

  def add_for_loop(id, type)
    row = TableRow.new(self, 'for-loop', [])
    self.add_symbol("for-loop-#{@loop_index}", row)
    loop_table = SymbolTable.new("for-loop-#{@loop_index}", "for-loop", row)
    row.link = loop_table
    loop_table.add_symbol(id, TableRow.new(loop_table, 'variable', [type, []]))
    @loop_index += 1
    return loop_table
  end

  def get_for_loop()
    loop_table = self["for-loop-#{@get_for_loop}"].link
    @get_for_loop += 1
    return loop_table
  end

  def find_variable(id)
    match_key = self.keys.keep_if{ |key| key.val == id.val}.first
    if match_key
      return self[match_key]
    else
      if self.parent
        return self.parent.table.find_variable(id)
      else
        return nil
      end
    end
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

  def generate_memory_allocation
    @memory_allocation = {}
    pending_classes = {}
    self.each do |key, value|
      word_key = key.val
      unless word_key == "program"
        if value.kind == "class"
          allocation = generate_class_allocation(word_key, value)
          if allocation[1].kind_of? MemoryAllocation
            @memory_allocation[allocation[0]] = allocation[1]
          else
            type, pending_process = allocation
            pending_classes[type] = pending_classes[type] || []
            pending_classes[type].push(pending_process)
          end
        else
          #generate_function_allocation(word_key, value, "function-#{word_key}")
        end
      end
    end
    until pending_classes.empty?
      pending_classes.each do |type, processes|
        if @memory_allocation.keys.include? type
          processes.each_with_index do |process, index|
            allocation = process.call()
            if allocation[1].kind_of? MemoryAllocation
              @memory_allocation[allocation[0]] = allocation[1]
            else
              dependency_type, process = allocation
              pending_classes[dependency_type].push(process)
            end
            processes.delete(process)
          end
        end
        if pending_classes[type].empty?
          pending_classes.delete(type)
        end
      end
    end
  end

  def generate_function_allocation(function_name, value, root)

  end

  def generate_class_allocation(class_name, class_info, allocation = nil, done_list = [])
    class_table = class_info.link
    allocation = allocation || MemoryAllocation.new(class_name, "class", "class-#{class_name}")
    done_list = done_list
    class_table.each do |key, row|
      word_key = key.val
      unless done_list.include? word_key
        if row.kind == "variable"
          type, size = row.type
          if ["int", "float"].include?(type)
            allocation.add_variable(word_key, type, size, type == "int" ? 1 : 2)
            done_list.push(word_key)
          else
            if @memory_allocation[type]
              allocation.add_variable(word_key, type, size, @memory_allocation[type].size)
              done_list.push(word_key)
            else
              return type, lambda{
                allocation.add_variable(word_key, type, size, @memory_allocation[type].size)
                done_list.push(word_key)
                return generate_class_allocation(class_name, class_info, allocation, done_list)
              }
            end
          end
        else
          #generate_function_allocation(word_key, row, "#{allocation.root}_function-#{word_key}")
        end
      end
    end
    return class_name, allocation
  end

  def generate_variable_declaration_code(name, type, size, current_table)
    kind = current_table.find_variable(name).kind
    variable_name = "#{current_table.generate_name}_#{kind}-#{name}"
    if ["int", "float"].include? type
      if size.size == 0
        @moon_interface.generate_memory_allocation(variable_name, type=="int"? 1: 2)
        return "#{variable_name}    dw 0"
      else
        memory_size = size.map{|i| i.to_i}.inject(:*) * (type=="int"? 1: 2)
        @moon_interface.generate_memory_allocation(variable_name, memory_size)
        return "#{variable_name}    res #{memory_size}"
      end
    else
      if size.size == 0
        size = [1]
      else
        size = size.map{|i| i.to_i}
      end
      memory_size = size.map{|i| i.to_i}.inject(:*) * get_size_of(type)
      @moon_interface.generate_memory_allocation(variable_name, memory_size)
      return "#{variable_name}    res #{memory_size}"
    end
  end

  def generate_assignment_code(lsh_name, type, size, rhs, current_table)
    register = @moon_interface.take_a_register
    register_name = register.register_name
    kind = current_table.find_variable(lsh_name).kind
    lsh_name = "#{current_table.generate_name}_#{kind}-#{lsh_name}"
    if rhs.is_a? Numeric
      if size.size == 0
        register.free
        return "sub #{register_name},#{register_name},#{register_name}\n"+"addi #{register_name},#{register_name},#{rhs}\n"  + "sw #{lsh_name}(r0),#{register_name}"
      else
        size_register = @moon_interface.take_a_register
        size_register_name = size_register.register_name
        register.free
        size_register.free
        return "sub #{register_name},#{register_name},#{register_name}\naddi #{register_name},#{register_name},#{rhs}\n"  + "sub #{size_register_name},#{size_register_name},#{size_register_name}\n"  + "addi #{size_register_name},#{size_register_name},#{size.map{|i| i.to_i + 1}.inject(:*)}\n"  + "sw #{lsh_name}(#{size_register_name}),#{register_name}"
      end
    elsif rhs.is_a? String
      if size.size == 0
        register.free
        return "lw #{register_name},#{rhs}\n"  + "sw #{lsh_name},#{register_name}"
      else
        size_register = @moon_interface.take_a_register
        size_register_name = size_register.register_name
        size_register.free
        register.free
        return "sub #{register_name},#{register_name},#{register_name}\n"  + "addi #{register_name},#{register_name},#{rhs}\n"  + "sub #{size_register_name},#{size_register_name},#{size_register_name}\n"  + "addi #{size_register_name},#{size_register_name},#{size.map{|i| i.to_i + 1}.inject(:*)}\n"  + "sw #{lsh_name}(#{size_register_name}),#{register_name}"
      end
    end
  end

  def generate_for_loop_code(current_table)
    return @moon_interface.generate_loop_symbols
  end

  def generate_for_loop_body_code(condition, end_loop)
    register = @moon_interface.take_a_register
    r_name = register.register_name
    register.free
    return "lw #{r_name},#{condition}\n" +
           "bnz #{r_name},#{end_loop}"
  end


  def generate_rhs_code(name, type, size, current_table)
    kind = current_table.find_variable(name).kind
    if size.size == 0
      return "", "#{current_table.generate_name}_#{kind}-#{name}(r0)"
    else
      register = @moon_interface.take_a_register
      register_name = register.register_name
      register.free
      return "sub #{register_name},#{register_name},#{register_name}\n"  + "addi #{register_name},#{register_name},#{size.map{|i| i.to_i + 1}.inject(:*)}", "#{current_table.generate_name}_#{kind}-#{name}(#{register_name})"
    end
  end

  def generate_rhs_add_code(addOp_value,lhs, rhs, current_table)
    if ["+", "-"].include? addOp_value
      add_assembly = (addOp_value == "+" ? "add" : "sub")
      if lhs.is_a? Numeric and rhs.is_a? Numeric
        register = @moon_interface.take_a_register
        register_name = register.register_name
        register.free
        unique_address = @moon_interface.generate_unique_address
        return "#{add_assembly}i #{register_name},#{lhs},#{rhs}\n"  + "#{unique_address} dw 0\n"  + "sw #{unique_address}(r0),#{register_name}", "#{unique_address}(r0)"
      elsif lhs.is_a? Numeric and rhs.is_a? String
        register = @moon_interface.take_a_register
        register_name = register.register_name
        register.free
        second_register = @moon_interface.take_a_register
        second_register_name = second_register.register_name
        unique_address = @moon_interface.generate_unique_address
        register.free
        second_register.free
        return "lw #{register_name},#{rhs}\n"  + "#{add_assembly}i #{second_register_name},#{lhs},#{register_name}\n"  + "#{unique_address} dw 0\n"  + "sw #{unique_address}(r0),#{second_register_name}", "#{unique_address}(r0)"
      elsif rhs.is_a? Numeric and lhs.is_a? String
        register = @moon_interface.take_a_register
        register_name = register.register_name
        register.free
        second_register = @moon_interface.take_a_register
        second_register_name = second_register.register_name
        unique_address = @moon_interface.generate_unique_address
        register.free
        second_register.free
        return "lw #{register_name},#{lhs}\n"  + "#{add_assembly}i #{second_register_name},#{register_name},#{rhs}\n"  + "#{unique_address} dw 0\n"  + "sw #{unique_address}(r0),#{second_register_name}", "#{unique_address}(r0)"
      else
        register_one = @moon_interface.take_a_register
        register_two = @moon_interface.take_a_register
        register_three = @moon_interface.take_a_register
        r1_name = register_one.register_name
        r2_name = register_two.register_name
        r3_name = register_three.register_name
        register_one.free
        register_two.free
        register_three.free
        unique_address = @moon_interface.generate_unique_address
        return "lw #{r1_name},#{rhs}\n"  + "lw #{r2_name},#{lhs}\n"  + "#{add_assembly} #{r3_name},#{r1_name},#{r2_name}\n"  + "#{unique_address} dw 0\n"  + "sw #{unique_address}(r0),#{r3_name}", "#{unique_address}(r0)"
      end
    else

    end
  end

  def generate_rhs_mulp_code(mulOp_value, lhs, rhs, current_table)
    if ["*", "/"].include? mulOp_value
      mul_assembly = (mulOp_value == "*" ? "mul" : "div")
      if lhs.is_a? Numeric and rhs.is_a? Numeric
        register = @moon_interface.take_a_register
        register_name = register.register_name
        register.free
        unique_address = @moon_interface.generate_unique_address
        return "#{mul_assembly}i #{register_name},#{lhs},#{rhs}\n"  + "#{unique_address} dw 0\n"  + "sw #{unique_address}(r0),#{register_name}", "#{unique_address}(r0)"
      elsif lhs.is_a? Numeric and rhs.is_a? String
        register = @moon_interface.take_a_register
        register_name = register.register_name
        register.free
        second_register = @moon_interface.take_a_register
        second_register_name = second_register.register_name
        unique_address = @moon_interface.generate_unique_address
        register.free
        second_register.free
        return "lw #{register_name},#{rhs}\n"  + "#{mul_assembly}i #{second_register_name},#{lhs},#{register_name}\n"  + "#{unique_address} dw 0\n"  + "sw #{unique_address}(r0),#{second_register_name}", "#{unique_address}(r0)"
      elsif rhs.is_a? Numeric and lhs.is_a? String
        register = @moon_interface.take_a_register
        register_name = register.register_name
        register.free
        second_register = @moon_interface.take_a_register
        second_register_name = second_register.register_name
        unique_address = @moon_interface.generate_unique_address
        register.free
        second_register.free
        return "lw #{register_name},#{lhs}\n"  + "#{mul_assembly}i #{second_register_name},#{register_name},#{rhs}\n"  + "#{unique_address} dw 0\n"  + "sw #{unique_address}(r0),#{second_register_name}", "#{unique_address}(r0)"
      else
        register_one = @moon_interface.take_a_register
        register_two = @moon_interface.take_a_register
        register_three = @moon_interface.take_a_register
        r1_name = register_one.register_name
        r2_name = register_two.register_name
        r3_name = register_three.register_name
        register_one.free
        register_two.free
        register_three.free
        unique_address = @moon_interface.generate_unique_address
        return "lw #{r1_name},#{rhs}\n"  + "lw #{r2_name},#{lhs}\n"  + "#{mul_assembly} #{r3_name},#{r1_name},#{r2_name}\n"  + "#{unique_address} dw 0\n"  + "sw #{unique_address}(r0),#{r3_name}", "#{unique_address}(r0)"
      end
    else
      register_one = @moon_interface.take_a_register
      register_two = @moon_interface.take_a_register
      register_three = @moon_interface.take_a_register
      r1_name = register_one.register_name
      r2_name = register_two.register_name
      r3_name = register_three.register_name
      register_one.free
      register_two.free
      register_three.free
      unique_address = @moon_interface.generate_unique_address
      zero_address = @moon_interface.generate_zero_address
      end_address = @moon_interface.generate_end_and_address
      return "lw #{r1_name},#{lhs}\n" +
             "lw #{r2_name},#{rhs}\n" +
             "and #{r3_name},#{r1_name},#{r2_name}\n"+
             "#{unique_address} dw 0\n" +
             "bz #{r3_name},#{zero_address}\n"+
             "addi #{r1_name}, r0, 1\n" +
             "sw #{unique_address}(r0),#{r1_name}\n" +
             "j #{end_address}\n" +
             "#{zero_address} sw #{unique_address}(r0), r0\n" +
             "#{end_address}",
             "#{unique_address}(r0)"
    end
  end

  def generate_if_head_code(rel_body)
    register_1 = @moon_interface.take_a_register
    r1_name = register_1.register_name
    register_1.free
    else_address = @moon_interface.generate_else_address
    end_if_address = @moon_interface.generate_end_if_address
    return "lw #{r1_name},#{rel_body}\n" +
           "bz #{r1_name},#{else_address}\n", else_address, end_if_address
  end

  def generate_relative_code(operator, lhs, rhs, current_table)
    case operator
    when "=="
      rel_operator = "ceq"
    when ">"
      rel_operator = "cgt"
    when "<"
      rel_operator = "clt"
    when ">="
      rel_operator = "cge"
    when "<="
      rel_operator = "cle"
    else
    end
    if lhs.is_a? Numeric and rhs.is_a? Numeric
      register_1 = @moon_interface.take_a_register
      register_2 = @moon_interface.take_a_register
      register_3 = @moon_interface.take_a_register
      r1_name = register_1.register_name
      r2_name = register_2.register_name
      r3_name = register_3.register_name
      register_1.free
      register_2.free
      register_3.free
      unique_address = @moon_interface.generate_unique_address
      return "addi #{r1_name},r0,#{lhs}\n" +
             "addi #{r2_name},r0,#{rhs}\n" +
             "#{rel_operator} #{r3_name},#{r1_name},#{r2_name}\n" +
             "#{unique_address} dw 0\n" +
             "sw #{unique_address}(r0),#{r3_name}",
             "#{unique_address}(r0)"
    elsif lhs.is_a? String and rhs.is_a? Numeric
      register_1 = @moon_interface.take_a_register
      register_2 = @moon_interface.take_a_register
      r1_name = register_1.register_name
      r2_name = register_2.register_name
      register_1.free
      register_2.free
      unique_address = @moon_interface.generate_unique_address
      return "lw #{r1_name},#{lhs}\n"+
             "#{rel_operator}i #{r2_name},#{r1_name},#{rhs}\n" +
             "#{unique_address} dw 0\n" +
             "sw #{unique_address}(r0),#{r2_name}",
             "#{unique_address}(r0)"
    elsif lhs.is_a? Numeric and rhs.is_a? String
      register_1 = @moon_interface.take_a_register
      register_2 = @moon_interface.take_a_register
      r1_name = register_1.register_name
      r2_name = register_2.register_name
      register_1.free
      register_2.free
      unique_address = @moon_interface.generate_unique_address
      return "lw #{r1_name},#{rhs}\n"+
             "#{rel_operator}i #{r2_name},#{r1_name},#{lhs}\n" +
             "#{unique_address} dw 0\n" +
             "sw #{unique_address}(r0),#{r2_name}",
             "#{unique_address}(r0)"
    else
      register_1 = @moon_interface.take_a_register
      register_2 = @moon_interface.take_a_register
      register_3 = @moon_interface.take_a_register
      r1_name = register_1.register_name
      r2_name = register_2.register_name
      r3_name = register_3.register_name
      register_1.free
      register_2.free
      register_3.free
      unique_address = @moon_interface.generate_unique_address
      return "lw #{r1_name},#{lhs}\n" +
             "lw #{r2_name},#{rhs}\n" +
             "#{rel_operator} #{r3_name},#{r1_name},#{r2_name}\n" +
             "#{unique_address} dw 0\n" +
             "sw #{unique_address}(r0),#{r3_name}\n",
             "#{unique_address}(r0)"
    end
  end

  def generate_not_code(body, current_symbol_table)
    if body.is_a? Numeric
      first_register = @moon_interface.take_a_register
      first_register_name = first_register.register_name
      second_register = @moon_interface.take_a_register
      second_register_name = second_register.register_name
      first_register.free
      second_register.free
      unique_address_1 = @moon_interface.generate_unique_address
      zero_address = @moon_interface.generate_zero_address
      end_not = @moon_interface.generate_end_not_address
      return "sub #{first_register_name},#{first_register_name},#{first_register_name},\n"  + "addi #{first_register_name},#{first_register_name},#{body}\n" +
             "not #{second_register_name},#{first_register_name}\n" +
             "#{unique_address_1} dw 0\n" +
             "bz #{second_register_name},#{zero_address}\n" +
             "addi #{first_register_name},r0,1\n" +
             "sw #{unique_address_1}(r0),#{first_register_name}" +
             "j #{end_not}\n" +
             "#{zero_address} sw #{unique_address_1}(r0),r0\n" +
             "#{end_not}", "#{unique_address_1}(r0)"
    else
      first_register = @moon_interface.take_a_register
      first_register_name = first_register.register_name
      second_register = @moon_interface.take_a_register
      second_register_name = second_register.register_name
      first_register.free
      second_register.free
      unique_address_1 = @moon_interface.generate_unique_address
      zero_address = @moon_interface.generate_zero_address
      end_not = @moon_interface.generate_end_not_address
      return "lw #{first_register_name}, #{body}\n"  + "not #{second_register_name},#{first_register_name}\n" +
             "#{unique_address_1} dw 0\n" +
             "bz #{second_register_name},#{zero_address}\n" +
             "addi #{first_register_name},r0,1\n" +
             "sw #{unique_address_1}(r0),#{first_register_name}" +
             "j #{end_not}\n" +
             "#{zero_address} sw #{unique_address_1}(r0),r0\n" +
             "#{end_not}", "#{unique_address_1}(r0)"
    end
  end

  def generate_rhs_funcall_code(name, type, params,current_table)
    codes = ""
    params.each_with_index do |p, i|
      codes += "lw r#{i + 1},#{p}\n"
    end
    unique_address = @moon_interface.generate_unique_address
    return "#{codes}lw r15,#{unique_address}\n"+
          "jr #{name}\n" +
          "#{unique_address}", "#{name}res"
  end

  def generate_function_head_code(fn_name, parameters, current_table)
    if current_table.parent
      fn_name = "class-#{current_table.id.val}_#{fn_name}"
    end
    params_code = ""
    registers = []
    parameters.each do |param|
      register = @moon_interface.take_a_register
      r_name = register.register_name
      registers.push(register)
      params_code += "#{fn_name}_#{param["id"].val} dw 0\n" +"#{fn_name} sw #{fn_name}_#{param["id"].val}(r0),#{r_name}\n"
    end
    registers.each{|r| r.free}
    return "#{fn_name}res dw 0\n" + "#{params_code}"
  end

  def generate_function_end_code(fn_name, return_address)
    first_register = @moon_interface.take_a_register
    r1_name = first_register.register_name
    first_register.free
    return "lw #{r1_name},#{return_address}\n " + "sw #{fn_name}res(r0),#{r1_name}\n" + "jr r15"
  end

  def get_size_of(type)
    @memory_allocation[type].size
  end

  def generate_name
    if self.parent.table.parent && !(self.parent.kind == "for-loop")
      "method-#{@id.val}"
    else
      "#{@type}-#{@id.val}"
    end
  end

  def get_offset_of(class_name, variable_name)
    unless ["int", "float"].include? class_name
      the_class = self.memory_allocation[class_name]
      if the_class
        off_set = []
        the_class.info.each_with_index do |variable|
          if variable.keys.first.include?("variable-#{variable_name}")
            break
          else
            if variable[variable.keys.first].size > 0
              off_set += variable[variable.keys.first]
            else
              off_set += ["0"]
            end
          end
        end
        return off_set
      else
        return [0]
      end
    else
      return [0]
    end
  end
end

class MemoryAllocation
  attr_accessor :name, :type, :size, :info
  def initialize(name, type, root)
    @name = name
    @type = type
    @root = root
    @size = 0
    @info = []
  end

  def add_variable(name, type, size, multiply_factor)
    if size.empty?
      @size += multiply_factor
    else
      @size += size.map{|i| i.to_i}.inject(:*)*multiply_factor
    end
    @info.push({"#{@root}_variable-#{name}" => size})
  end
end
