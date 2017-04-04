class RegisterList
  def initialize
    @register_list = (1..15).to_a.map{|i| Register.new("r#{i}")}
  end

  def get_a_register
    if @register_list.any?{|r| r.is_free?}
      register = @register_list.detect{|r| r.is_free?}
      register.take
      return register
    else
      puts "Run out of registers"
    end
  end

  def free_register(register_name)
    register = @register_list.detect{|r| r.register_name == register_name}
    register.free
  end
end

class Register
  attr_reader :register_name
  def initialize(name)
    @register_name = name
    @is_free = true
  end

  def free
    @is_free = true
  end

  def is_free?
    @is_free
  end

  def take
    @is_free = false
  end
end


class MoonInterface
  def initialize
    @current_allocation = 0
    @memory_record = {}
    @register_list = RegisterList.new
    @address_letter = "a"
    @address_number = 0
  end

  def take_a_register
    @register_list.get_a_register
  end

  def release_a_register(register_name)
    @register_list.free_register(register_name)
  end

  def generate_memory_allocation(name, size)
    @memory_record[name] = {start: @current_allocation, end: @current_allocation + size}
    @current_allocation += size
  end

  def generate_unique_address
    address = "#{@address_letter}#{@address_number}"
    if @address_number == 9
      @address_letter = @address_letter.next
      @address_number = 0
    else
      @address_number += 1
    end
    return address
  end

  def generate_zero_address
    @zero_number = @zero_number || 0
    address = "zero#{@zero_number}"
    @zero_number += 1
    return address
  end

  def generate_end_not_address
    @end_not_number = @end_not_number || 0
    address = "endnot#{@end_not_number}"
    @end_not_number += 1
    return address
  end

  def generate_end_and_address
    @end_and_number = @end_and_number || 0
    address = "endand#{@end_and_number}"
    @end_and_number += 1
    return address
  end

  def generate_else_address
    @else_number = @else_number || 0
    address = "else#{@else_number}"
    @else_number += 1
    return address
  end

  def generate_end_if_address
    @end_if_number = @end_if_number || 0
    address = "endif#{@end_if_number}"
    @end_if_number += 1
    return address
  end

  def generate_loop_symbols
    number = @loop_symbol_number = @loop_symbol_number || 0
    @loop_symbol_number += 1
    return "startloop#{number}", "goloop#{number}","endloop#{number}"
  end
end
