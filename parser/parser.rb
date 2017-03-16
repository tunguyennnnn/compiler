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
  attr_reader :tokens, :look_ahead, :stack, :global_table, :current_symbol_table, :correct_semantic
  def initialize(tokens, set_table, skip_error=false)
    @tokens = tokens
    @skip_error = skip_error
    @tokens.push("$")
    @set_table = set_table
    @index = 0
    @stack = []
    @errors = ""
    @correct_semantic = true
    File.open("semantic_error.txt", 'w') {|f| f.write("Semantic errors are: \n") }
  end

  def parse
    @current_symbol_table = @global_table = SymbolTable.new(id, 'global', nil)
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
              write_semantic_error("Non type", construct_table(table, false))
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
      return @look_ahead.val.to_i if token == "integerNumber"
    elsif @look_ahead.kind_of? FloatToken
      return @look_ahead.val.to_f if token == "floatNumber"
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
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
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
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def classDecl
    if look_ahead_is "class"
      if match("class") && (id=match("id"))
        row = ClassRow.new(@global_table, 'class', '')
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
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
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
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
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
        params_type = params.map{|param| param["type"]}
        row = TableRow.new(@current_symbol_table, 'function', [(the_type.kind_of?(String) ? the_type : the_type.val), params_type])
        if add_to_table(@current_symbol_table, id, row)
          row.link = @current_symbol_table = SymbolTable.new(id, 'function', row)
          params.each{|param| add_to_table(@current_symbol_table, param["id"], TableRow.new(@current_symbol_table, 'parameter', param["type"]))}
        end
        if funcBody() && match(";")
          @current_symbol_table = @current_symbol_table.parent ? @current_symbol_table.parent.table : @global_table
          if funcDef_star()
            write "VarOrFuncDecl", "FParams", ")", "FuncBody", ";", "FuncDecls"
          end
        end
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
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
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
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
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def progBody
    if look_ahead_is "program"
      if match("program")
        row = TableRow.new(@global_table, 'function', '')
        if add_to_table(@global_table, 'program', row)
          row.link = @current_symbol_table = SymbolTable.new(id, 'program', row)
        end
        if funcBody() && match(";")
          @current_symbol_table = @current_symbol_table.parent ? @current_symbol_table.parent.table : @global_table
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
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def funcHead
    if @set_table["Type"].first_set_include? @look_ahead
      if (type=type()) && (id=match("id"))
        if match("(") && (params=fParams()) && match(")")
          params_type= params.map{|param| param["type"]}
          row = TableRow.new(@global_table, 'function', [type, params_type])
          if add_to_table(@current_symbol_table, id, row)
            row.link = @current_symbol_table = SymbolTable.new(id, "function", row)
            params.each{|param| add_to_table(@current_symbol_table, param["id"], TableRow.new(@current_symbol_table, 'parameter', param["type"]))}
          end
          write "FuncHead", "Type", "idToken", "(", "FParams", ")"
          return params
        else
          return false
        end
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def funcDef
    if @set_table["FuncHead"].first_set_include? @look_ahead
      if (params=funcHead()) && funcBody() && match(";")
        @current_symbol_table = @current_symbol_table.parent ? @current_symbol_table.parent.table : @global_table
        write "FuncDecl", "FuncHead", "FuncBody", ";"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def funcBody
    if look_ahead_is "{"
      if match("{") && funcBodyInner() && match("}")
        write "FuncBody", "{", "FuncBodyInner", "}"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def funcBodyInner
    if look_ahead_is "float"
      if match("float") && varDeclTail("float")
        write "FuncBodyInner", "floatToken", "VarDeclTail"
      end
    elsif look_ahead_is "int"
      if match("int") && varDeclTail("int")
        write "FuncBodyInner", "intToken", "VarDeclTail"
      end
    elsif look_ahead_is "id"
      if (id=match("id")) && varDeclorAssignStat(id)
        write "FuncBodyInner", "idToken", "VarDeclorAssignStat"
      end
    elsif @set_table["StatmentSpecial"].first_set_include? @look_ahead
      if statementSpecial() && statement_star()
        write "FuncBodyInner", "StatementSpecial", "Statements"
      end
    elsif @set_table["FuncBodyInner"].follow_set_include? @look_ahead
      write "FuncBodyInner", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def varDeclTail(the_type)
    if look_ahead_is "id"
      if (id=match("id")) && (the_size=arraySize_star()) && match(";")
        row = TableRow.new(@current_symbol_table, 'variable', [(the_type.kind_of?(String) ? the_type : the_type.val), the_size])
        add_to_table(@current_symbol_table, id, row)

        if funcBodyInner()
          write "VarDeclTail", "idToken", "ArraySizes", ";", "FuncBodyInner"
        end
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def varDeclorAssignStat(the_type)
    if look_ahead_is "id"
      if (id=match("id")) && (the_size=arraySize_star()) && match(";")
        row = TableRow.new(@current_symbol_table, 'variable', [(the_type.kind_of?(String) ? the_type : the_type.val), the_size])
        add_to_table(@current_symbol_table, id, row)
        if funcBodyInner()
          write "VarDeclorAssignStat", "idToken", "ArraySizes", ";", "FuncBodyInner"
        end
      end
    elsif @set_table["Indices"].first_set_include? @look_ahead
      if indice_star() && variableTail() && assignOp() && expr() && match(";")  && statement_star()
        write "VarDeclorAssignStat", "Indices", "VariableTail", "AssignOp", "Expr", ";", "Statements"
      end
    elsif @set_table["AssignOp"].first_set_include? @look_ahead
      if assignOp() && expr() && match(";") && statement_star()
        write "VarDeclorAssignStat", "AssignOp", "Expr", ";", "Statements"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
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
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def statement_star
    if @set_table["Statement"].first_set_include? @look_ahead
      if statement() && statement_star()
        write "Statements", "Statement", "Statements"
      end
    elsif @set_table["Statements"].follow_set_include? @look_ahead
      write "Statements", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def arraySize_star(ac_size=[])
    return false if (!skip_errors(@set_table["ArraySizes"]))
    if @set_table["ArraySize"].first_set_include? @look_ahead
      if (size = arraySize()) && arraySize_star(ac_size.push(size))
        write "ArraySizes", "ArraySize", "ArraySizes"
        return ac_size
      end
    elsif @set_table["ArraySizes"].follow_set_include? @look_ahead
      write "ArraySizes", "ε"
      return ac_size
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def statement
    if @set_table["AssignStat"].first_set_include? @look_ahead
      if assignStat() && match(";")
        write "Statement", "AssignStat", ";"
      end
    elsif @set_table["StatmentSpecial"].first_set_include? @look_ahead
      if statementSpecial()
        write "Statement", "StatementSpecial"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def statementSpecial
    if look_ahead_is "if"
      if match("if") && match("(") && expr() && match(")") && match("then") && statBlock() && match("else") && statBlock() && match(";")
        write "StatementSpecial", "if", "(", "Expr", ")", "then", "StatBlock", "else", "StateBlock", ";"
      end
    elsif look_ahead_is "for"
      if match("for") && match("(") && type() && match("id") && assignOp() && expr() && match(";") && relExpr() && match(";") && assignStat() && match(")") && statBlock() && match(";")
        write "StatementSpecial", "for", "(", "Type", "idToken", "AssignOp", "Expr", ";", "RelExpr", ";", "AssignStat", ")" && "StatBlock" && ";"
      end
    elsif look_ahead_is "get"
      if match("get") && match("(") && variable() && match(")") && match(";")
        write "StatementSpecial", "get", "(", "Variable", ")", ";"
      end
    elsif look_ahead_is "put"
      if match("put") && match("(") && expr() && match(")") && match(";")
        write "StatementSpecial", "put", "(", "Expr", ")", ";"
      end
    elsif look_ahead_is "return"
      if match("return") && match("(") && expr() && match(")") && match(";")
        write "StatementSpecial", "return", "(", "Expr", ")", ";"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def assignStat
    if @set_table["Variable"].first_set_include? @look_ahead
      if variable() && assignOp() && expr()
        write "AssignStat", "Variable", "AssignOp", "Expr"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
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
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def expr
    nil if (!skip_errors(@set_table["Expr"]))
    if @set_table["ArithExpr"].first_set_include? @look_ahead
      if arithExpr() && relExprTail()
        write "Expr", "ArithExpr", "RelExprTail"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def relExprTail
    if @set_table["RelOp"].first_set_include? @look_ahead
      if relOp() && arithExpr()
        write "RelExprTail", "RelOp", "ArithExpr"
      end
    elsif @set_table["RelExprTail"].follow_set_include? @look_ahead
      write "RelExprTail", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def relExpr
    if @set_table["ArithExpr"].first_set_include? @look_ahead
      if arithExpr() && relOp() && arithExpr()
        write "RelExpr", "ArithExpr", "RelOp", "ArithExpr"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def arithExpr
    if @set_table["Term"].first_set_include? @look_ahead
      if term() && arithExprD_star()
        write "ArithExpr", "Term", "ArithExprDs"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def arithExprD_star
    if @set_table["ArithExprD"].first_set_include? @look_ahead
      if arithExprD() && arithExprD_star()
        write "ArithExprDs", "ArithExprD", "ArithExprDs"
      end
    elsif @set_table["ArithExprDs"].follow_set_include? @look_ahead
      write "ArithExprDs", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def arithExprD
    if @set_table["AddOp"].first_set_include? @look_ahead
      if addOp() && term()
        write "ArithExprD", "AddOp", "Term"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def term
    if @set_table["Factor"].first_set_include? @look_ahead
      if factor() && termD_star()
        write "Term", "Factor", "TermDs"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end

  end

  def termD_star
    if @set_table["TermD"].first_set_include? @look_ahead
      if termD() && termD_star()
        write "TermDs", "TermD", "TermDs"
      end
    elsif @set_table["TermDs"].follow_set_include? @look_ahead
      write "TermDs", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def termD
    if @set_table["MultOp"].first_set_include? @look_ahead
      if mulOp() && factor()
        write "TermD", "MulOp", "Factor"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def factor
    if @set_table["VarHead"].first_set_include? @look_ahead
      if varHead()
        write "Factor", "VarHead"
      end
    elsif look_ahead_is "integerNumber"
      if match("integerNumber")
        write "Factor", "integerNumber"
      end
    elsif look_ahead_is "floatNumber"
      if match("floatNumber")
        write "Factor", "floatNumber"
      end
    elsif look_ahead_is "("
      if match("(") && arithExpr() && match(")")
        write "Factor", "(", "ArithExpr", ")"
      end
    elsif look_ahead_is "not"
      if match("not") && factor()
        write "Factor", "not", "Factor"
      end
    elsif @set_table["Sign"].first_set_include? @look_ahead
      if sign() && factor()
        write "Factor", "Sign", "Factor"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def varHead
    if look_ahead_is "id"
      if match("id") && varHeadTail()
        write "VarHead", "id", "VarHeadTail"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def varHeadTail

    if @set_table["Indices"].first_set_include? @look_ahead
      if indice_star() && varHeadEnd()
        write "VarHeadTail", "Indices", "VarHeadEnd"
      end
    elsif @set_table["VarHeadEnd"].first_set_include? @look_ahead
      if varHeadEnd()
        write "VarHeadTail", "VarHeadEnd"
      end
    elsif look_ahead_is "("
      if match("(") && aParams() && match(")")
        write "VarHeadTail", "(", "AParams", ")"
      end
    elsif @set_table["VarHeadTail"].follow_set_include? @look_ahead
      write "VarHeadTail", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def indice_star
    if @set_table["Indice"].first_set_include? @look_ahead
      if indice() && indice_star()
        write "Indices", "Indice", "Indices"
      end
    elsif @set_table["Indices"].follow_set_include? @look_ahead
      write "Indices", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def varHeadEnd
    if look_ahead_is "."
      if match(".") && varHead()
        write "VarHeadEnd", ".", "VarHead"
      end
    elsif @set_table["VarHeadEnd"].follow_set_include? @look_ahead
      write "VarHeadEnd", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end


  def idnest
    if look_ahead_is "id"
      if match("id") && indice_star && match(".")
        write "Idnest", "idToken", "Indices", "."
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def variable
    if look_ahead_is "id"
      if match("id") && indice_star() && variableTail()
        write "Variable", "idToken", "Indices", "VariableTail"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def variableTail
    if look_ahead_is "."
      if match(".") && variable()
        write "VariableTail", ".", "Variable"
      end
    elsif @set_table["VariableTail"].follow_set_include? @look_ahead
      write "VariableTail", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def indice
    if look_ahead_is "["
      if match("[") && arithExpr() && match("]")
        write "Indice", "[", "ArithExpr", "]"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
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
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
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
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def fParams
    if @set_table["Type"].first_set_include? @look_ahead
      if (the_type=type()) && (id=match("id")) && (size=arraySize_star()) && (other_params=fParamsTail_star())
        write "FParams", "Type", "idToken", "ArraySizes", "FParamsTails"
        return other_params.push({"id"=> id, "type"=> [(the_type.kind_of?(String) ? the_type : the_type.val), size]})
      end
    elsif @set_table["FParams"].follow_set_include? @look_ahead
      write "FParams", "ε"
      return []
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
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
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def aParams
    if @set_table["Expr"].first_set_include? @look_ahead
      if expr() && aParamsTail_star()
        write "AParams", "Expr", "AParamsTails"
      end
    elsif @set_table["AParams"].follow_set_include? @look_ahead
      write "AParams", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def aParamsTail_star
    if @set_table["AParamsTail"].first_set_include? @look_ahead
      if aParamsTail() && aParamsTail_star()
        write "AParamsTails", "AParamsTail", "AParamsTails"
      end
    elsif @set_table["AParamsTails"].follow_set_include? @look_ahead
      write "AParamsTails", "ε"
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
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
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def aParamsTail
    if look_ahead_is ","
      if @skip_error && @tokens[@index + 1].val.downcase == ")"
        skip_token()
        return true
      end
      if match(",") && expr()
        write "aParamsTail", ",", "Expr"
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def assignOp
    return match(@look_ahead.val.downcase) if look_ahead_is "="
    write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
  end

  def relOp
    return match(@look_ahead.val.downcase) if look_ahead_is "==" or look_ahead_is "<>" or look_ahead_is "<" or look_ahead_is ">" or look_ahead_is "<=" or look_ahead_is ">="
    write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
  end

  def addOp
    return match(@look_ahead.val.downcase) if look_ahead_is "+" or look_ahead_is "-" or look_ahead_is "or"
    write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
  end

  def mulOp
    return match(@look_ahead.val.downcase) if look_ahead_is "*" or look_ahead_is "/" or look_ahead_is "and"
    write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
  end

  def sign
    if look_ahead_is "-" or look_ahead_is "+"
      if match(@look_ahead.val.downcase)
        write "Sign", @tokens[@index - 1].val
      end
    else
      write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
    end
  end

  def id
  end

  def float
  end

  def integer
  end

end

set_table = FirstFollowSetTable.new
set_table.insert_from_file 'set_table.txt'
@set_table = set_table.table

@tokenizer = Tokenizer.new
@tokenizer.text = "
class FirstClass {
  FirstClass x;
  int x3[1][2][3];

  float method2(OtherType y){
    FirstClass var;
  };
};
program{
  FirstClass y[0][0][0];
  int y;
};
"
@tokenizer.tokenize
@tokenizer.remove_error
parser = Parsing.new(@tokenizer.tokens, @set_table)
puts "result is: #{parser.parse} done"

puts parser.construct_table(parser.global_table)
puts "Semantic result: #{parser.correct_semantic}"
