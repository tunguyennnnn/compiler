require_relative '../lexical_analyzer/tokenizer'
require_relative 'first_follow_set_table'
require_relative 'semantic_table'
require 'terminal-table'
require 'continuation'

class String
  def val
    self
  end

  def start_index
    "last"
  end

  def line
    "last"
  end
end


class Array
  def get_product
    if self.empty?
      return 0
    else
      return self.map{|i| i.to_i + 1}.inject(:*)
    end
  end
end

class WriteToFile
  attr_reader :write
  def initialize(derivation_stack)
    @derivation_stack = derivation_stack
    @stack = []
    @write = ""
  end

  def build_stack
    if @stack.empty?
      n, *t = @derivation_stack.first
      @stack = t
      @derivation_stack = @derivation_stack[1..-1]
      build_stack
    elsif @derivation_stack.empty?
      #done
    else
      @write += @stack.join(" ") + "\n"
      n, *t = @derivation_stack.first
      indexes = @stack.each_index.select {|i| @stack[i] == n}
      unless indexes.empty?
        @stack[indexes.last] = t
        @stack.flatten!
      end
      @derivation_stack = @derivation_stack[1..-1]
      build_stack
    end
  end
end

class Parsing
  attr_reader :look_ahead, :stack, :global_table, :current_symbol_table, :correct_semantic, :code_generation
  attr_accessor :final_table, :second_pass, :tokens
  def initialize(tokens, set_table, skip_error=false)
    @tokens = tokens
    @skip_error = skip_error
    @tokens.push("$")
    @set_table = set_table
    @index = 0
    @stack = []
    @errors = ""
    @correct_semantic = true
    @final_table = nil
    File.open("semantic_error.txt", 'w') {|f| f.write("Semantic errors are: \n") }
    @code_generation = []
  end

  def second_pass?
    @second_pass = @second_pass || false
  end

  def parse
    @current_symbol_table = @global_table = SymbolTable.new(id, 'global', nil)
    @current_symbol_table_final = @final_table
    @index = 0 if second_pass?
    @look_ahead = @tokens[@index]
    if @set_table["Prog"].first_set_include? @look_ahead
      if prog() && (match("$") == '$')
        check_semantic_table
        return true
      end
    end
  end

  def skip_errors(set_table)
    if @skip_error
      if set_table.first_set_include? @look_ahead or (set_table.nullable and set_table.follow_set_include? @look_ahead)
        return true
      else
        until set_table.first_set_include? @look_ahead or set_table.follow_set_include? @look_ahead
          skip_token()
          if set_table.nullable and set_table.follow_set_include? @look_ahead
            return false
          end
        end
        return true
      end
    else
      return true
    end
  end

  def write_error(error)
    @errors += "#{error}\n"
    nil
  end

  def write_semantic_error(message, table)
    @correct_semantic = false
    open('semantic_error.txt', 'a'){ |file|
      file.puts message
      file.puts table
    }
  end

  def write_semantic_error_second_pass(message, table)
    @correct_semantic = false
    open('semantic_error.txt', 'a'){ |file|
      file.puts message
      file.puts construct_table(table, false)
    }
    return MigrationType.new
  end

  def check_semantic_table()
    classes = {}
    @global_table.each do |key, value|
      if value.kind == 'class'
        classes[key.val] = value
      end
    end
    correct_semantic?(@global_table, classes)
  end

  def correct_semantic?(table, classes)
    callcc{ |cont|
      if table.nil?
        return true
      end
      table.keys.each do |entry|
        row = table[entry]
        if ['variable', 'parameter'].include? row.kind
          unless ['int', 'float'].include? row.type[0]
            if !classes.keys.include?(row.type[0])
              write_semantic_error("Type #{row.type[0]} of #{row.kind} #{entry.val} at line:#{entry.line_info} index:#{entry.start_index} is undefined", construct_table(table, false))
              cont.call()
            end
            if table.type == 'class'
              if classes[row.type[0]].reference_classes.include?(table.id.val)
                write_semantic_error("Circular Class References of #{entry.val} at line:#{entry.line_info} index:#{entry.start_index}", "#{construct_table(table, false)} \n #{construct_table(classes[row.type[0]].link, false)}")
                cont.call()
              elsif table.id.val == row.type[0]
                write_semantic_error("Variable #{entry.val} of type #{row.type[0]} at line:#{entry.line_info} index:#{entry.start_index} reference itself", construct_table(table, false))
                cont.call()
              else
                classes[table.id.val].add_reference(row.type[0])
              end
            end
          end
        elsif row.kind == 'function' && entry.val != "program"
          unless ['int', 'float'].include? row.type[0]
            unless classes[row.type[0]]
              write_semantic_error("function #{entry.val} at line:#{entry.line_info} index:#{entry.start_index} has return type #{row.type[0]} undefined", construct_table(table, false))
              cont.call()
            end
          else
            correct_semantic?(row.link, classes)
          end
        else
          correct_semantic?(row.link, classes)
        end
      end
    }
  end

  def add_to_table(table, symbol, row)
    is_added, added = table.add_symbol(symbol, row)
    if is_added
      return true
    else
      print_table = construct_table(table, false)
      message = "The #{row.kind} #{symbol.val} at line:#{symbol.line_info} index:#{symbol.start_index} cannot be added because #{added.kind} #{symbol.val} was added before."
      write_semantic_error message, print_table
    end
  end

  def construct_table(table, expand=true)
    if table
      rows = []
      table.keys.each do |entry|
        row = table[entry]
        rows << [entry.val, row.kind, row.type, (expand ? construct_table(row.link) : row.link)]
      end
      return Terminal::Table.new rows: rows
    end
  end


  def match(token)
    if current_token = look_ahead_is(token)
      next_token()
      current_token
    else
      next_token()
      false
    end
  end


  def write(rhs, *lhs)
    @stack.push([rhs] + lhs)
    return true
  end

  def write_to_file
    File.open('derivation.txt', 'w+') do |file|
      writer = WriteToFile.new(@stack.reverse)
      writer.build_stack
      file.write(writer.write)
    end
    File.open('error.txt', 'w+') do |file|
      file.write @errors
    end
  end

  def look_ahead_is (token)
    if @look_ahead.kind_of? IdToken
      return @look_ahead if token == 'id'
    elsif @look_ahead.kind_of? IntegerToken
      return @look_ahead if token == "integerNumber"
    elsif @look_ahead.kind_of? FloatToken
      return @look_ahead if token == "floatNumber"
    else
      return @look_ahead.val if @look_ahead.val.downcase == token
    end
  end

  def next_token
    @index += 1
    @look_ahead = @tokens[@index]
    @look_ahead = '$' unless @look_ahead
  end

  def skip_token
    write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    @tokens.delete_at(@index)
    @look_ahead = @tokens[@index]
    @look_ahead = '$' unless @look_ahead
  end

  def prog
    if @set_table["ClassDecs"].first_set_include? @look_ahead
      if classDecl_star() && progBody()
        write "Prog", "ClassDecls", "ProgBody"
      end
    elsif @set_table["ProgBody"].first_set_include? @look_ahead
      if progBody()
        write "Prog", "ProgBody"
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def classDecl_star
    if @set_table['ClassDec'].first_set_include? @look_ahead
      if classDecl() && classDecl_star()
        write "ClassDecls", "ClassDecl", "ClassDecls"
      end
    elsif @set_table['ClassDecs'].follow_set_include? @look_ahead
      write "ClassDecls", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def classDecl
    if look_ahead_is "class"
      if match("class") && (id=match("id"))
        row = ClassRow.new(@global_table, 'class', '')
        if second_pass?
          @current_symbol_table_final = @final_table.get_table(id, 'class')
        end
        if add_to_table(@global_table, id, row)
          row.link = @current_symbol_table = SymbolTable.new(id, 'class', row)
        end
        if match("{") && classBody() && match("}") && match(";")
          write "ClassDecl", "class", "idToken", "{", "ClassBody", "}", ";"
          return true
        else
          return false
        end
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def classBody
    if @set_table["Type"].first_set_include? @look_ahead
      if (the_type=type()) && (id=match("id")) && varOrFuncDecl(id, the_type)
        write "ClassBody", "Type", "idToken", "VarOrFuncDecl"
      end
    elsif @set_table["ClassBody"].follow_set_include? @look_ahead
      write "ClassBody", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def varOrFuncDecl(id, the_type)
    if @set_table["ArraySizes"].first_set_include? @look_ahead
      if (the_size= arraySize_star()) && match(";")
        add_to_table(@current_symbol_table, id, TableRow.new(@current_symbol_table, 'variable', [(the_type.kind_of?(String) ? the_type : the_type.val), the_size]))
        if classBody()
          write "VarOrFuncDecl", "ArraySizes()", ";", "ClassBody"
        end
      end
    elsif look_ahead_is ";"
      if match(";")
        add_to_table(@current_symbol_table, id, TableRow.new(@current_symbol_table, 'variable', [(the_type.kind_of?(String) ? the_type : the_type.val), []]))
        if classBody()
          write "VarOrFuncDecl", ";", "ClassBody"
        end
      end
    elsif look_ahead_is "("
      if match("(") && (params=fParams()) && match(")")
        params = params.keep_if{|param| param != true}
        params_type = params.map{|param| param["type"]}

        row = TableRow.new(@current_symbol_table, 'function', [(the_type.kind_of?(String) ? the_type : the_type.val), params_type])
        if second_pass?
          @code_generation.push(@final_table.generate_function_head_code(id.val, params, @current_symbol_table_final))
          @current_symbol_table_final = @current_symbol_table_final.get_table(id, 'function')
        end
        if add_to_table(@current_symbol_table, id, row)
          row.link = @current_symbol_table = SymbolTable.new(id, 'function', row)
          params.each{|param| add_to_table(@current_symbol_table, param["id"], TableRow.new(@current_symbol_table, 'parameter', param["type"]))}
        end
        if (funcBody_value = funcBody()) && match(";")

          @current_symbol_table = @current_symbol_table.parent ? @current_symbol_table.parent.table : @global_table
          if second_pass?
            @current_symbol_table_final = @current_symbol_table_final.parent ? @current_symbol_table_final.parent.table : @final_table
            if funcBody_value == true
              return write_semantic_error_second_pass("Missing return statement for method #{id.val} of class #{@current_symbol_table_final.id.val}", @final_table)
            else
              @code_generation.push(@final_table.generate_function_end_code(id.val, funcBody_value))
            end
          end
          if funcDef_star()
            write "VarOrFuncDecl", "FParams", ")", "FuncBody", ";", "FuncDecls"
          end
        end
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def varDecl_star
    if @set_table["VarDecl"].first_set_include? @look_ahead
      if varDecl() && varDecl_star()
        write "VarDecls", "VarDecl" , "VarDecls"
      end
    elsif @set_table["VarDecls"].follow_set_include? @look_ahead
      write "VarDecls", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def funcDef_star
    if @set_table["FuncDef"].first_set_include? @look_ahead
      if funcDef() && funcDef_star()
        write "FuncDecls", "FuncDecl", "FuncDecls"
      end
    elsif @set_table["FuncDefs"].follow_set_include? @look_ahead
      write "FuncDecls", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def progBody
    if look_ahead_is "program"
      if match("program")
        row = TableRow.new(@global_table, 'function', '')
        if second_pass?
          @current_symbol_table_final = @final_table.get_table("program", "program")
        end
        if add_to_table(@global_table, 'program', row)
          row.link = @current_symbol_table = SymbolTable.new("program", 'program', row)
        end
        if funcBody() && match(";")
          @current_symbol_table = @current_symbol_table.parent ? @current_symbol_table.parent.table : @global_table
          if second_pass?
            @current_symbol_table_final = @current_symbol_table_final.parent ? @current_symbol_table_final.parent.table : @final_table
          end
          if funcDef_star()
            write "ProgBody", "program", "FuncBody", ";", "FuncDecls"
            return true
          else
            return false
          end
          return true
        else
          return false
        end
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def funcHead
    if @set_table["Type"].first_set_include? @look_ahead
      if (the_type=type()) && (id=match("id"))
        if match("(") && (params=fParams()) && match(")")
          params = params.keep_if{|param| param != true}
          params_type= params.map{|param| param["type"]}
          row = TableRow.new(@global_table, 'function', [the_type.val, params_type])
          if second_pass?
            @code_generation.push(@final_table.generate_function_head_code(id.val, params, @current_symbol_table_final))
            @current_symbol_table_final = @current_symbol_table_final.get_table(id, 'function')
          end
          if add_to_table(@current_symbol_table, id, row)
            row.link = @current_symbol_table = SymbolTable.new(id, "function", row)
            params.each{|param| add_to_table(@current_symbol_table, param["id"], TableRow.new(@current_symbol_table, 'parameter', param["type"]))}
            return id.val
          end
          write "FuncHead", "Type", "idToken", "(", "FParams", ")"
          return params
        else
          return false
        end
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def funcDef
    if @set_table["FuncHead"].first_set_include? @look_ahead
      if (func_name=funcHead()) && (funcBody_value = funcBody()) && match(";")
        @current_symbol_table = @current_symbol_table.parent ? @current_symbol_table.parent.table : @global_table
        if second_pass?
          @current_symbol_table_final = @current_symbol_table_final.parent ? @current_symbol_table_final.parent.table : @final_table
          if funcBody_value == true
            return write_semantic_error_second_pass("Missing return statement for function #{func_name}", @final_table)
          else
            @code_generation.push(@final_table.generate_function_end_code(func_name, funcBody_value))
          end
        end
        write "FuncDecl", "FuncHead", "FuncBody", ";"
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def funcBody
    if look_ahead_is "{"
      if match("{") && (funcBody_value = funcBodyInner()) && match("}")
        if second_pass?
          return funcBody_value
        end
        write "FuncBody", "{", "FuncBodyInner", "}"
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def funcBodyInner
    if look_ahead_is "float"
      if match("float") && (funcBody_value = varDeclTail("float"))
      return funcBody_value if second_pass?
        write "FuncBodyInner", "floatToken", "VarDeclTail"
      end
    elsif look_ahead_is "int"
      if match("int") && (funcBody_value = varDeclTail("int"))
        return funcBody_value if second_pass?
        write "FuncBodyInner", "intToken", "VarDeclTail"
      end
    elsif look_ahead_is "id"
      if (id=match("id")) && (funcBody_value = varDeclorAssignStat(id))
        return funcBody_value if second_pass?
        write "FuncBodyInner", "idToken", "VarDeclorAssignStat"
      end
    elsif @set_table["StatmentSpecial"].first_set_include? @look_ahead
      if (st_special_value = statementSpecial()) && (st_value = statement_star())
        if second_pass?
          if st_value.is_a? String
            return st_value
          else
            return st_special_value
          end
        end
        write "FuncBodyInner", "StatementSpecial", "Statements"
      end
    elsif @set_table["FuncBodyInner"].follow_set_include? @look_ahead
      write "FuncBodyInner", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def varDeclTail(the_type)
    if look_ahead_is "id"
      if (id=match("id")) && (the_size=arraySize_star()) && match(";")
        row = TableRow.new(@current_symbol_table, 'variable', [(the_type.kind_of?(String) ? the_type : the_type.val), the_size])
        add_to_table(@current_symbol_table, id, row)
        if second_pass?
          @code_generation.push(@final_table.generate_variable_declaration_code(id.val, the_type.val, the_size, @current_symbol_table_final))
        end
        if (funcBody_value = funcBodyInner())
          if second_pass?
            return funcBody_value
          end
          write "VarDeclTail", "idToken", "ArraySizes", ";", "FuncBodyInner"
        end
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def varDeclorAssignStat(the_type)
    if look_ahead_is "id"
      if (id=match("id")) && (the_size=arraySize_star()) && match(";")
        row = TableRow.new(@current_symbol_table, 'variable', [(the_type.kind_of?(String) ? the_type : the_type.val), the_size])
        add_to_table(@current_symbol_table, id, row)
        if second_pass?
          @code_generation.push(@final_table.generate_variable_declaration_code(id.val, the_type.val, the_size, @current_symbol_table_final))
        end
        if (funcBody_value = funcBodyInner())
          return funcBody_value if second_pass?
          write "VarDeclorAssignStat", "idToken", "ArraySizes", ";", "FuncBodyInner"
        end
      end
    elsif @set_table["Indices"].first_set_include? @look_ahead
      variableTail_type = MigrationType.new
      if (the_size= indice_star()) && (variableTail_value = variableTail(MigrationType.new(the_type), the_size, variableTail_type, @current_symbol_table_final)) && assignOp()
        expr_type = MigrationType.new
        if (expr_value = expr(expr_type)) && match(";")
          if second_pass?
            validate_type(variableTail_type, expr_type)
            @code_generation.push(@final_table.generate_assignment_code(the_type.val, the_type.val, the_size + variableTail_value.array, expr_value, @current_symbol_table_final))
          end
          if (statement_star_value = statement_star())
            return statement_star_value if second_pass?
            write "VarDeclorAssignStat", "Indices", "VariableTail", "AssignOp", "Expr", ";", "Statements"
          end
        end
      end
    elsif @set_table["AssignOp"].first_set_include? @look_ahead
      if assignOp()
        expr_type = MigrationType.new
        if (expr_value = expr(expr_type)) && match(";")
          if second_pass?
            its_type = @current_symbol_table_final.find_type(the_type)
            if its_type
              type_name, size = its_type
              validate_type(MigrationType.new(the_type, type_name, size.size), expr_type)
              @code_generation.push(@final_table.generate_assignment_code(the_type.val, type_name, size, expr_value, @current_symbol_table_final))
            else
              return write_semantic_error_second_pass("Undefined variable #{the_type.val} at #{the_type.line_info}", @current_symbol_table_final)
            end
          end
          if (statement_star_value = statement_star())
            return statement_star_value if second_pass?
            write "VarDeclorAssignStat", "AssignOp", "Expr", ";", "Statements"
          end
        end
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def varDecl
    if @set_table["type"].first_set_include? @look_ahead
      current_row = TableRow.new(@current_symbol_table, 'variable', '')
      if (variable_type=type()) && (id=match("id")) && (size=arraySize_star()) && match(";")
        current_row.type=[variable_type, size]
        add_to_table(@current_symbol_table,id, current_row)
        write "VarDecl", "Type", "idToken", "ArraySizes", ";"
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def statement_star
    if @set_table["Statement"].first_set_include? @look_ahead
      if (statement_value = statement()) && (statement_star_value = statement_star())
        if second_pass?
          if statement_star_value.is_a? String
            return statement_star_value
          else
            return statement_value
          end
        end
        write "Statements", "Statement", "Statements"
      end
    elsif @set_table["Statements"].follow_set_include? @look_ahead
      write "Statements", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def arraySize_star(ac_size=[])
    return false if (!skip_errors(@set_table["ArraySizes"]))
    if @set_table["ArraySize"].first_set_include? @look_ahead
      if (size = arraySize()) && arraySize_star(ac_size.push(size.val))
        write "ArraySizes", "ArraySize", "ArraySizes"
        return ac_size
      end
    elsif @set_table["ArraySizes"].follow_set_include? @look_ahead
      write "ArraySizes", "ε"
      return ac_size
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def statement
    if @set_table["AssignStat"].first_set_include? @look_ahead
      if assignStat() && match(";")
        write "Statement", "AssignStat", ";"
      end
    elsif @set_table["StatmentSpecial"].first_set_include? @look_ahead
      if (st_special_value = statementSpecial())
        if second_pass?
          return st_special_value
        end
        write "Statement", "StatementSpecial"
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def statementSpecial
    if look_ahead_is "if"
      if match("if") && match("(")
        expr_type = MigrationType.new
        if (expr_value = expr(expr_type)) && match(")") && match("then")
          if second_pass?
            code, else_address, end_if_address = @final_table.generate_if_head_code(expr_value)
            @code_generation.push(code)
          end
          if statBlock() && match("else")
            if second_pass?
              @code_generation.push("j #{end_if_address}")
              @code_generation.push("#{else_address}")
            end
            if statBlock() && match(";")
              @code_generation.push("#{end_if_address}")
              write "StatementSpecial", "if", "(", "Expr", ")", "then", "StatBlock", "else", "StateBlock", ";"
            end
          end
        end
      end
    elsif look_ahead_is "for"
      if match("for") && match("(") && (the_type = type()) && (id = match("id")) && assignOp()
        @current_symbol_table = @current_symbol_table.add_for_loop(id, the_type)
        @current_symbol_table_final = @current_symbol_table_final.get_for_loop() if second_pass?
        expr_type = MigrationType.new
        if (expr_value = expr(expr_type)) && match(";")
          if second_pass?
            validate_type(MigrationType.new(id.val, the_type), expr_type)
            @code_generation.push(@final_table.generate_assignment_code(id.val, the_type.val, [], expr_value, @current_symbol_table_final))
            start_loop, go_loop, end_loop = @final_table.generate_for_loop_code(@current_symbol_table_final)
            @code_generation.push("j #{start_loop}")
            @code_generation.push("#{go_loop}")
          end
          if (relExpr_value = relExpr()) && match(";") && assignStat() && match(")")
            if second_pass?
              @code_generation.push("#{start_loop}")
              @code_generation.push(relExpr_value[0])
              @code_generation.push(@final_table.generate_for_loop_body_code(relExpr_value[1], end_loop))
            end
            if statBlock() && match(";")
              @current_symbol_table = @current_symbol_table.parent.table
              if second_pass?
                @current_symbol_table_final = @current_symbol_table_final.parent.table
                @code_generation.push("j #{start_loop}")
                @code_generation.push("#{end_loop}")
              end
              write "StatementSpecial", "for", "(", "Type", "idToken", "AssignOp", "Expr", ";", "RelExpr", ";", "AssignStat", ")" && "StatBlock" && ";"
            end
          end
        end
      end
    elsif look_ahead_is "get"
      variable_type = MigrationType.new
      if match("get") && match("(") && variable(variable_type) && match(")") && match(";")
        write "StatementSpecial", "get", "(", "Variable", ")", ";"
      end
    elsif look_ahead_is "put"
      expr_type = MigrationType.new
      if match("put") && match("(") && expr(expr_type) && match(")") && match(";")
        write "StatementSpecial", "put", "(", "Expr", ")", ";"
      end
    elsif look_ahead_is "return"
      expr_type = MigrationType.new
      if match("return") && match("(") && (expr_value = expr(expr_type)) && match(")") && match(";")
        if second_pass?
          unless @current_symbol_table_final.parent.type[0] == expr_type.type_name && expr_type.size == 0
            return write_semantic_error_second_pass("Wrong return type of #{expr_type.type.val} at #{expr_type.type.line_info}", @current_symbol_table_final)
          else
            return expr_value
          end
        end
        write "StatementSpecial", "return", "(", "Expr", ")", ";"
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def assignStat
    if @set_table["Variable"].first_set_include? @look_ahead
      variable_type = MigrationType.new
      if (variable_value = variable(variable_type)) && assignOp()
        expr_type = MigrationType.new
        if (expr_value = expr(expr_type))
          if second_pass?
            validate_type(variable_type, expr_type)
            @code_generation.push(@final_table.generate_assignment_code(variable_value.type.val, variable_value.type_name, variable_value.array, expr_value, @current_symbol_table_final))
          end
          write "AssignStat", "Variable", "AssignOp", "Expr"
        end
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def statBlock
    if look_ahead_is "{"
      if match("{") && statement_star() && match("}")
        write "StatBlock", "{", "Statements", "}"
      end
    elsif @set_table["Statement"].first_set_include? @look_ahead
      if statement()
        write "StatBlock", "Statement"
      end
    elsif @set_table["StatBlock"].follow_set_include? @look_ahead
      write "StatBlock", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def expr(expr_type)
    nil if (!skip_errors(@set_table["Expr"]))
    if @set_table["ArithExpr"].first_set_include? @look_ahead
      arith_type, rel_type =  MigrationType.new, MigrationType.new
      if (arithExpr_value = arithExpr(arith_type)) && (relExprTail_value = relExprTail(arith_type, rel_type, arithExpr_value))
        if second_pass?
          expr_type.copy_type_of(rel_type)
          return relExprTail_value
        end
        write "Expr", "ArithExpr", "RelExprTail"
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def relExprTail(arith_type, rel_type, lhs_value)
    if @set_table["RelOp"].first_set_include? @look_ahead
      arith_type_prime =  MigrationType.new
      if (relOp_value = relOp()) && (rhs_value = arithExpr(arith_type_prime))
        if second_pass?
          rel_type.copy_type_of(semcheckop(arith_type, arith_type_prime))
          first_code, second_code = @final_table.generate_relative_code(relOp_value, lhs_value, rhs_value, @current_symbol_table_final)
          @code_generation.push(first_code)
          return second_code
        end
        write "RelExprTail", "RelOp", "ArithExpr"
      end
    elsif @set_table["RelExprTail"].follow_set_include? @look_ahead
      if second_pass?
        rel_type.copy_type_of(arith_type)
        return lhs_value
      end
      write "RelExprTail", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def relExpr
    if @set_table["ArithExpr"].first_set_include? @look_ahead
      arith_type1, arith_type2 = MigrationType.new, MigrationType.new
      if (lhs_value = arithExpr(arith_type1)) && (rel_value = relOp()) && (rhs_value = arithExpr(arith_type2))
        if second_pass?
          return @final_table.generate_relative_code(rel_value, lhs_value, rhs_value, @current_symbol_table_final)
        end
        write "RelExpr", "ArithExpr", "RelOp", "ArithExpr"
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def arithExpr(arith_type)
    if @set_table["Term"].first_set_include? @look_ahead
      term_type, arith_types = MigrationType.new, MigrationType.new
      if (term_value = term(term_type)) && (arithExprD_value = arithExprD_star(term_type, arith_types, term_value))
        if second_pass?
          arith_type.copy_type_of(arith_types)
          return arithExprD_value
        end
        write "ArithExpr", "Term", "ArithExprDs"
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def arithExprD_star(term_type, arith_types, term_value)
    if @set_table["ArithExprD"].first_set_include? @look_ahead
      arithExprD_type, arithExprD_types = MigrationType.new, MigrationType.new
      if (arithExprD_value = arithExprD(arithExprD_type)) && (arithExprD_star_value = arithExprD_star(arithExprD_type, arithExprD_types, arithExprD_value[1]))
        if second_pass?
          arith_types.copy_type_of(semcheckop(term_type, arithExprD_types))
          first_code, second_code = @final_table.generate_rhs_add_code(arithExprD_value[0], term_value, arithExprD_star_value, @current_symbol_table_final)
          @code_generation.push(first_code)
          return second_code
        end
        write "ArithExprDs", "ArithExprD", "ArithExprDs"
      end
    elsif @set_table["ArithExprDs"].follow_set_include? @look_ahead
      if second_pass?
        arith_types.copy_type_of(term_type)
        return term_value
      end
      write "ArithExprDs", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def arithExprD(arithExprD_type)
    if @set_table["AddOp"].first_set_include? @look_ahead
      term_type = MigrationType.new
      if (addOp_value=addOp()) && (term_value = term(term_type))
        if second_pass?
          arithExprD_type.copy_type_of(term_type)
          return addOp_value, term_value
        end
        write "ArithExprD", "AddOp", "Term"
        return []
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def term(term_type)
    if @set_table["Factor"].first_set_include? @look_ahead
      factor_type, termD_types = MigrationType.new, MigrationType.new
      if (factor_value = factor(factor_type)) && (termD_star_value = termD_star(factor_type, termD_types, factor_value))
        if second_pass?
          term_type.copy_type_of(termD_types)
          return termD_star_value
        end
        return write "Term", "Factor", "TermDs"
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def termD_star(term_type, termD_types, factor_value)
    if @set_table["TermD"].first_set_include? @look_ahead
      termD_type, termD_types_prime = MigrationType.new, MigrationType.new
      if (termD_value = termD(termD_type)) && (termD_star_value = termD_star(termD_type, termD_types_prime, termD_value[1]))
        if second_pass?
          termD_types.copy_type_of(semcheckop(termD_type, termD_types_prime))
          first_code, second_code = @final_table.generate_rhs_mulp_code(termD_value[0], factor_value, termD_star_value, @current_symbol_table_final)
          @code_generation.push(first_code)
          return second_code
        end
        write "TermDs", "TermD", "TermDs"
      end
    elsif @set_table["TermDs"].follow_set_include? @look_ahead
      if second_pass?
        termD_types.copy_type_of(term_type)
        return factor_value
      end
      write "TermDs", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def termD(termD_type)
    if @set_table["MultOp"].first_set_include? @look_ahead
      factor_type = MigrationType.new
      if (mulOp_value = mulOp()) && (factor_value  = factor(factor_type))
        write "TermD", "MulOp", "Factor"
        if second_pass?
          termD_type.copy_type_of(factor_type)
          return mulOp_value = factor_value
        end
        write "TermD", "MulOp", "Factor"
        return []
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def factor(factor_type)
    if @set_table["VarHead"].first_set_include? @look_ahead
      varHead_type = MigrationType.new
      if (varHead_value = varHead(varHead_type, @current_symbol_table_final))
        if second_pass?
          factor_type.copy_type_of(varHead_type)
          if varHead_type.is_function
            first_code, second_code = @final_table.generate_rhs_funcall_code(varHead_type.type.val, varHead_type.type_name, varHead_type.params, @current_symbol_table_final)
            @code_generation.push(first_code)
            return second_code
          else
            moon_first, moon_second = @final_table.generate_rhs_code(varHead_value.type.val, factor_type.type_name, varHead_value.array, @current_symbol_table_final)
            @code_generation.push(moon_first)
            return moon_second
          end
        end
        write "Factor", "VarHead"
      end
    elsif look_ahead_is "integerNumber"
      if (the_type=match("integerNumber"))
        if second_pass?
          factor_type.copy_type_of(MigrationType.new(the_type, "int", 0))
          return the_type.val.to_i
        end
        write "Factor", "integerNumber"
        return true
      end
    elsif look_ahead_is "floatNumber"
      if (the_type = match("floatNumber"))
        if second_pass?
          factor_type.copy_type_of(MigrationType.new(the_type, "float", 0))
          return the_type.val.to_i
        end
        write "Factor", "floatNumber"
        return true
      end
    elsif look_ahead_is "("
      arith_type = MigrationType.new
      if match("(") && (arithExpr_value = arithExpr(arith_type)) && match(")")
        if second_pass?
          factor_type.copy_type_of(arith_type)
          return arithExpr_value
        end
        write "Factor", "(", "ArithExpr", ")"
      end
    elsif look_ahead_is "not"
      factor_type_prime = MigrationType.new
      if match("not") && (factor_value = factor(factor_type_prime))
        if second_pass?
          factor_type.copy_type_of(factor_type_prime)
          first_code, second_code = @final_table.generate_not_code(factor_value, @current_table)
          @code_generation.push(first_code)
          return second_code
        end
        write "Factor", "not", "Factor"
      end
    elsif @set_table["Sign"].first_set_include? @look_ahead
      factor_type_prime = MigrationType.new
      if sign() && factor(factor_type_prime)
        factor_type.copy_type_of(factor_type_prime) if second_pass?
        write "Factor", "Sign", "Factor"
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def varHead(varHead_type, the_table)
    if look_ahead_is "id"
      varHeadTail_type = MigrationType.new
      if (the_type=match("id")) && (varHeadTail_value = varHeadTail(MigrationType.new(the_type), varHeadTail_type, the_table))
        if second_pass?
          varHead_type.copy_type_of(varHeadTail_type)
          return MigrationType.new(the_type.val, varHeadTail_value.type_name, varHeadTail_value.size, varHeadTail_value.array)
        end
        write "VarHead", "id", "VarHeadTail"
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def varHeadTail(id_type, varHeadTail_type, current_table)
    if @set_table["Indices"].first_set_include? @look_ahead
      varHeadEnd_type = MigrationType.new
      if (the_size=indice_star()) && (varHeadEnd_value = varHeadEnd(id_type, the_size, varHeadTail_type, current_table))
        if second_pass?
          varHeadTail_type.copy_type_of(varHeadTail_type)
          return MigrationType.new(id_type.type.val, varHeadTail_type.type_name, varHeadTail_type.size, the_size + varHeadEnd_value.array)
        end
        write "VarHeadTail", "Indices", "VarHeadEnd"
      end
    elsif @set_table["VarHeadEnd"].first_set_include? @look_ahead
      varHeadEnd_type = MigrationType.new
      if (varHeadEnd_value = varHeadEnd(id_type, [], varHeadEnd_type, current_table))
        if second_pass?
          varHeadTail_type.copy_type_of(varHeadEnd_type)

          return MigrationType.new(id_type.type.val, varHeadEnd_type.type_name, varHeadEnd_type.size, varHeadEnd_value.array)
        end
        write "VarHeadTail", "VarHeadEnd"
      end
    elsif look_ahead_is "("
      if match("(") && (code_params = aParams()) && match(")")
        if second_pass?
          its_type = current_table.find_type(id_type.type)
          if its_type
            type, a_params = its_type
            if a_params.size == code_params[0].size
              correct_param = true
              code_params[0].each_with_index{|p, i|
                unless p.is_equal?(a_params[i])
                  write_semantic_error_second_pass("In correct type passed to function #{id_type.type.val} at #{id_type.type.line_info}", current_table)
                  correct_param = false
                end
              }
              if correct_param
                if current_table.parent && current_table.parent.kind == "class"
                  id_type.type.val = "#{current_table.generate_name}_#{id_type.type.val}"
                else
                  id_type.type.val = id_type.type.val
                end
                varHeadTail_type.copy_type_of(MigrationType.new(id_type.type, type, 0, [], true, code_params[1]))
                return varHeadTail_type
              else
                return write_semantic_error_second_pass("Wrong argument in function #{id_type.type.val} at #{id_type.type.line_info}", current_table)
              end
            else
              return write_semantic_error_second_pass("Wrong number of argument in function #{id_type.type.val} at #{id_type.type.line_info}", current_table)
            end
          else
            return write_semantic_error_second_pass("No method #{id_type.type.val}", current_table)
          end
        end
        write "VarHeadTail", "(", "AParams", ")"
      end
    elsif @set_table["VarHeadTail"].follow_set_include? @look_ahead
      if second_pass?
        its_type = current_table.find_type(id_type.type)
        if its_type
          type, size = its_type
          varHeadTail_type.copy_type_of(MigrationType.new(id_type.type, type, size.size))
          return MigrationType.new(id_type.type, type, size.size, [])
        else
          return write_semantic_error_second_pass("Undefined variable #{id_type.type.val} at #{id_type.type.line_info}", current_table)
        end

      end
      write "VarHeadTail", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def indice_star(ac_size=[])
    if @set_table["Indice"].first_set_include? @look_ahead
      if (size=indice()) && indice_star(ac_size.push(size))
        write "Indices", "Indice", "Indices"
        return ac_size
      end
    elsif @set_table["Indices"].follow_set_include? @look_ahead
      write "Indices", "ε"
      return ac_size
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def varHeadEnd(id_type, the_size, varHeadEnd_type, current_table)
    if look_ahead_is "."
      varHead_type = MigrationType.new
      if second_pass?
        its_type = current_table.find_type(id_type.type)
        if its_type
          type, size = its_type
          if size.size == the_size.size
            if ["int", "float"].include?(type)
              return write_semantic_error_second_pass("Cant used dot notation for #{id_type.type.val} at #{id_type.type.line_info}", current_table)
            else
              current_table = @final_table.find_class_table(type)
            end
          else
            return write_semantic_error_second_pass("Cannot used dot notation of array #{id_type.type.val} at #{id_type.type.line_info}", current_table)
          end
        else
          return write_semantic_error_second_pass("undefined variable #{id_type.type.val} at #{id_type.type.line_info}", current_table)
        end
      end
      if match(".") && (varHead_value = varHead(varHead_type, current_table))
        if second_pass?
          varHeadEnd_type.copy_type_of(varHead_type)
          return varHead_value
        end
        write "VarHeadEnd", ".", "VarHead"
      end
    elsif @set_table["VarHeadEnd"].follow_set_include? @look_ahead
      if second_pass?
        its_type = current_table.find_type(id_type.type)
        if its_type
          type, size = its_type
          varHeadEnd_type.copy_type_of(MigrationType.new(id_type.type, type, size.size - the_size.size, the_size))
          return MigrationType.new(id_type.type, type, size.size - the_size.size, [])
        else
          return write_semantic_error_second_pass("undefined variable #{id_type.type.val} at #{id_type.type.line_info}", current_table)
        end
      end
      write "VarHeadEnd", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def variable(variable_type, the_type=nil, the_size=nil, the_table=nil)
    if look_ahead_is "id"
      variable_type.print_type if second_pass?
      if (the_type_prime = match("id")) && (the_size_prime = indice_star())
        next_table = @current_symbol_table_final
        if second_pass?
          if the_type
            its_type = the_table.find_type(the_type.type)
            if its_type
              type, size = its_type
              unless ['int', 'float'].include?(type)
                unless next_table = @final_table.find_class_table(type)
                  return write_semantic_error_second_pass("Undefined type #{type} of #{the_type.val} at #{the_type.line_info}", @final_table)
                end
              end
            else
              return write_semantic_error_second_pass("Undefined variable #{variable_type.type.val} at #{  variable_type.type.line_info}", @current_symbol_table_final)
            end
          end
        end
        variableTail_type = MigrationType.new
        if (variableTail_value = variableTail(MigrationType.new(the_type_prime), the_size_prime, variableTail_type, next_table))
          variable_type.copy_type_of(variableTail_type)
          if second_pass?
            ##off_set = @final_table.get_offset_of(type, variable_type.type.val)
            return MigrationType.new(the_type_prime.val, type, 0, the_size_prime + variableTail_value.array)
          end
          write "Variable", "idToken", "Indices", "VariableTail"
        end
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def variableTail(the_type, the_size, variableTail_type, the_table)
    if look_ahead_is "."
      variable_type = MigrationType.new
      if match(".") && (variable_value = variable(variable_type, the_type, the_size, the_table))
        variableTail_type.copy_type_of(variable_type)
        if second_pass?
          return variable_value
        end
        write "VariableTail", ".", "Variable"
      end
    elsif @set_table["VariableTail"].follow_set_include? @look_ahead
      if second_pass?
        its_type = the_table.find_type(the_type.type)
        if its_type
          type, size = its_type
          variableTail_type.copy_type_of(MigrationType.new(the_type.type, type, size.size - the_size.size, the_size))
          return MigrationType.new(the_type.type, type, size.size - the_size.size, [])
        else
          return write_semantic_error_second_pass("Undefined variable #{the_type.type.val}", @current_symbol_table_final)
        end
      end
      write "VariableTail", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def indice
    if look_ahead_is "["
      arith_type = MigrationType.new
      if match("[") && arithExpr(arith_type) && match("]")
        write "Indice", "[", "ArithExpr", "]"
        return (arith_type.type ? arith_type.type.val : 1)
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def arraySize
    nil if (!skip_errors(@set_table["ArraySize"]))
    if look_ahead_is "["
      if match("[") && (int = match("integerNumber")) && match("]")
        write "ArraySize", "[", "intToken", "]"
        return int
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def type
    if look_ahead_is "int" or look_ahead_is "float"
      if (the_type = match(@look_ahead.val.downcase))
        write "Type", @tokens[@index - 1].val.downcase
        return the_type.downcase
      end
    elsif look_ahead_is "id"
      if (the_type = match("id"))
        write "Type", @tokens[@index - 1].val.downcase
        return the_type
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def fParams
    if @set_table["Type"].first_set_include? @look_ahead
      if (the_type=type()) && (id=match("id")) && (size=arraySize_star()) && (other_params=fParamsTail_star())
        write "FParams", "Type", "idToken", "ArraySizes", "FParamsTails"
        return other_params.insert(0, {"id"=> id, "type"=> [(the_type.kind_of?(String) ? the_type : the_type.val), size]})
      end
    elsif @set_table["FParams"].follow_set_include? @look_ahead
      write "FParams", "ε"
      return []
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def fParamsTail_star(params=[])
    if @set_table["FParamsTail"].first_set_include? @look_ahead
      if (param=fParamsTail()) && fParamsTail_star(params.push(param))
        write "FParamsTails", "FParamsTail", "FParamsTails"
        return params
      end
    elsif @set_table["FParamsTails"].follow_set_include? @look_ahead
      write "FParamsTails", "ε"
      return params
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def aParams(accum = [], codes = [])
    if @set_table["Expr"].first_set_include? @look_ahead
      expr_type, aParamsTail_type = MigrationType.new, MigrationType.new
      if (expr_value = expr(expr_type)) && aParamsTail_star(accum.push(expr_type), codes.push(expr_value))
        write "AParams", "Expr", "AParamsTails"
        return accum, codes
      end
    elsif @set_table["AParams"].follow_set_include? @look_ahead
      write "AParams", "ε"
      return accum, codes
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def aParamsTail_star(accum, codes)
    if @set_table["AParamsTail"].first_set_include? @look_ahead
      aparamTail_type = MigrationType.new
      if (aParam_value = aParamsTail(aparamTail_type)) && aParamsTail_star(accum.push(aparamTail_type), codes.push(aParam_value))
        write "AParamsTails", "AParamsTail", "AParamsTails"
        return accum, codes
      end
    elsif @set_table["AParamsTails"].follow_set_include? @look_ahead
      write "AParamsTails", "ε"
      return accum, codes
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def fParamsTail
    if look_ahead_is ","
      if @skip_error && @tokens[@index + 1].val.downcase == ")"
        skip_token()
        return true
      end
      if match(",") && (the_type=type()) && (id=match("id")) && (the_size=arraySize_star())
        write "FParamsTail", ",", "Type", "id", "ArraySizes"
        return {"id"=> id, "type"=> [(the_type.kind_of?(String) ? the_type : the_type.val), the_size]}
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def aParamsTail(aParamsTail_type)
    if look_ahead_is ","
      if @skip_error && @tokens[@index + 1].val.downcase == ")"
        skip_token()
        return true
      end
      if match(",")
        expr_type = MigrationType.new
        if (expr_value = expr(expr_type))
          aParamsTail_type.copy_type_of(expr_type)
          return expr_value if second_pass?
          write "aParamsTail", ",", "Expr"
        end
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def assignOp
    return match(@look_ahead.val.downcase) if look_ahead_is "="
    write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
  end

  def relOp
    return match(@look_ahead.val.downcase) if look_ahead_is "==" or look_ahead_is "<>" or look_ahead_is "<" or look_ahead_is ">" or look_ahead_is "<=" or look_ahead_is ">="
    write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
  end

  def addOp
    return match(@look_ahead.val.downcase) if look_ahead_is "+" or look_ahead_is "-" or look_ahead_is "or"
    write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
  end

  def mulOp
    return match(@look_ahead.val.downcase) if look_ahead_is "*" or look_ahead_is "/" or look_ahead_is "and"
    write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
  end

  def sign
    if look_ahead_is "-" or look_ahead_is "+"
      if match(@look_ahead.val.downcase)
        write "Sign", @tokens[@index - 1].val
      end
    else
      write_error "Error occurs at line: #{@look_ahead.line_info} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def id
  end

  def float
  end

  def integer
  end

  def validate_type(type1, type2)
    if second_pass?
      # puts "Valuedata ---------------------"
      # type1.print_type
      # type2.print_type
      if type1.type && type2.type  && type1.type_name == type2.type_name && type1.size == type2.size
        return true
      else
        if type1.type && type2.type
          return write_semantic_error_second_pass("Incompatible type of assignment at #{type1.type.line_info} for #{type1.type.val}", @current_symbol_table_final)
        end
      end
    end
  end

  def semcheckop(type1, type2)
    # type1.print_type
    # type2.print_type
    if ["int", "float"].include?(type1.type_name) && ["int", "float"].include?(type2.type_name)
      if type1.size == type2.size
        if type1.type_name == type2.type_name
          return type1
        elsif type1.type_name == "int"
          return type2
        else
          return type1
        end
      else
        return write_semantic_error_second_pass("uncompatiable types: #{type1.type.val} at #{type1.type.line_info} #{type2.type.val} #{type1.type.line_info}", @final_table)
        return MigrationType.new
      end
    else
      if type1.type && type2.type
        return write_semantic_error_second_pass("Cannot performed arithmetic expression on #{type1.type_name} #{type1.type.val} at #{type1.type.line_info}  and #{type2.type_name} #{type2.type.val} at #{type2.type.line_info}", @current_symbol_table_final)
      end
      return MigrationType.new
    end
  end
end
