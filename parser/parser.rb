require_relative '../lexical_analyzer/main.rb'
require_relative 'first_follow_set_table'

class String
  def val
    self
  end
end

class Parsing
  attr_reader :tokens, :look_ahead, :stack
  def initialize(tokens, set_table, skip_error=false)
    @tokens = tokens
    @skip_error = skip_error
    @tokens.push("$")
    @set_table = set_table
    @index = 0
    @stack = []
    @errors = ""
  end

  def parse
    @look_ahead = @tokens[@index]
    if @set_table["Prog"].first_set_include? @look_ahead
      return prog() && match("$")
    end
  end

  def skip_errors(set_table)
    if @skip_error
      if set_table.first_set_include? @look_ahead or set_table.nullable and set_table.follow_set_include? @look_ahead
        return true
      else
        write_error "Error occurs at line: #{@look_ahead} index: #{@look_ahead.start_index} token: #{@look_ahead.val}"
        until set_table.first_set_include? @look_ahead or set_table.follow_set_include? @look_ahead
          next_token()
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
  end

  def match(token)
    if look_ahead_is token
      next_token()
      true
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
      @stack.reverse.each do |derivation|
        lsh, *rhs = derivation
        file.write "#{lsh} => #{rhs.join("  ")}\n"
      end
    end
    File.open('error.txt', 'w+') do |file|
      file.write @errors
    end
  end

  def look_ahead_is (token)
    if @look_ahead.kind_of? IdToken
      token == "id"
    elsif @look_ahead.kind_of? IntegerToken
      token == "integerNumber"
    elsif @look_ahead.kind_of? FloatToken
      token == "floatNumber"
    else
      @look_ahead.val.downcase == token
    end
  end

  def next_token
    @index += 1
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
      false
    end
  end

  def classDecl_star
    if @set_table['ClassDec'].first_set_include? @look_ahead
      if classDecl() && classDecl_star()
        write "ClassDecls", "ClassDecl", "ClassDecls"
      end
    elsif @set_table['ClassDecs'].follow_set_include? @look_ahead
      write "ClassDecls", "epsilon"
    end
  end

  def classDecl
    if look_ahead_is "class"
      if match("class") && match("id") && match("{") && classBody() && match("}") && match(";")
        write "ClassDecl", "class", "idToken", "{", "ClassBody", "}", ";"
      end
    end
  end

  def classBody
    if @set_table["Type"].first_set_include? @look_ahead
      if type() && match("id") && varOrFuncDecl()
        write "ClassBody", "Type", "idToken", "VarOrFuncDecl"
      end
    elsif @set_table["ClassBody"].follow_set_include? @look_ahead
      write "ClassBody", "epsilon"
    end
  end

  def varOrFuncDecl
    if @set_table["ArraySizes"].first_set_include? @look_ahead
      if arraySize_star() && match(";") && classBody()
        write "VarOrFuncDecl", "ArraySizes()", ";", "ClassBody"
      end
    elsif look_ahead_is ";"
      if match(";") && classBody()
        write "VarOrFuncDecl", ";", "ClassBody"
      end
    elsif look_ahead_is "("
      if match("(") && fParams() && match(")") && funcBody() && match(";") && funcDef_star()
        write "VarOrFuncDecl", "FParams", ")", "FuncBody", ";", "FuncDecls"
      end
    end
  end

  def varDecl_star
    if @set_table["VarDecl"].first_set_include? @look_ahead
      if varDecl() && varDecl_star()
        write "VarDecls", "VarDecl" , "VarDecls"
      end
    elsif @set_table["VarDecls"].follow_set_include? @look_ahead
      write "VarDecls", "epsilon"
    end
  end

  def funcDef_star
    if @set_table["FuncDef"].first_set_include? @look_ahead
      if funcDef() && funcDef_star()
        write "FuncDecls", "FuncDecl", "FuncDecls"
      end
    elsif @set_table["FuncDefs"].follow_set_include? @look_ahead
      write "FuncDecls", "epsilon"
    end
  end

  def progBody
    if look_ahead_is "program"
      if match("program") && funcBody() && match(";") && funcDef_star()
        write "ProgBody", "program", "FuncBody", ";", "FuncDecls"
      end
    end
  end

  def funcHead
    if @set_table["Type"].first_set_include? @look_ahead
      if type() && match("id") && match("(") && fParams() && match(")")
        write "FuncHead", "Type", "idToken", "(", "FParams", ")"
      end
    end
  end

  def funcDef
    if @set_table["FuncHead"].first_set_include? @look_ahead
      if funcHead() && funcBody() && match(";")
        write "FuncDecl", "FuncHead", "FuncBody", ";"
      end
    end
  end

  def funcBody
    if look_ahead_is "{"
      if match("{") && funcBodyInner() && match("}")
        write "FuncBody", "{", "FuncBodyInner", "}"
      end
    end
  end

  def funcBodyInner
    if look_ahead_is "float"
      if match("float") && varDeclTail()
        write "FuncBodyInner", "floatToken", "VarDeclTail"
      end
    elsif look_ahead_is "int"
      if match("int") && varDeclTail()
        write "FuncBodyInner", "intToken", "VarDeclTail"
      end
    elsif look_ahead_is "id"
      if match("id") && varDeclorAssignStat()
        write "FuncBodyInner", "idToken", "VarDeclorAssignStat"
      end
    elsif @set_table["StatmentSpecial"].first_set_include? @look_ahead
      if statementSpecial() && statement_star()
        write "FuncBodyInner", "statementSpecial", "Statements"
      end
    elsif @set_table["FuncBodyInner"].follow_set_include? @look_ahead
      write "FuncBodyInner", "epsilon"
    end
  end

  def varDeclTail
    if look_ahead_is "id"
      if match("id") && arraySize_star() && match(";") && funcBodyInner()
        write "VarDeclTail", "idToken", "ArraySizes", ";", "FuncBodyInner"
      end
    end
  end

  def varDeclorAssignStat
    if look_ahead_is "id"
      if match("id") && arraySize_star() && match(";") && funcBodyInner()
        write "VarDeclorAssignStat", "idToken", "ArraySizes", ";", "FuncBodyInner"
      end
    elsif @set_table["Indices"].first_set_include? @look_ahead
      if indice_star() && variableTail() && assignOp() && expr() && match(";")  && statement_star()
        write "VarDeclorAssignStat", "Indices", "VariableTail", "AssignOp", "Expr", ";", "Statements"
      end
    elsif @set_table["AssignOp"].first_set_include? @look_ahead
      if assignOp() && expr() && match(";") && statement_star()
        write "VarDeclorAssignStat", "AssignOp", "Expr", ";", "Statements"
      end
    end
  end

  def varDecl
    if @set_table["type"].first_set_include? @look_ahead
      if type() && match("id") && arraySize_star() && match(";")
        write "VarDecl", "Type", "idToken", "ArraySizes", ";"
      end
    end
  end

  def statement_star
    if @set_table["Statement"].first_set_include? @look_ahead
      if statement() && statement_star()
        write "Statements", "Statement", "Statements"
      end
    elsif @set_table["Statements"].follow_set_include? @look_ahead
      write "Statements", "epsilon"
    end
  end

  def arraySize_star
    if @set_table["ArraySize"].first_set_include? @look_ahead
      if arraySize() && arraySize_star()
        write "ArraySizes", "ArraySize", "ArraySizes"
      end
    elsif @set_table["ArraySizes"].follow_set_include? @look_ahead
      write "ArraySizes", "epsilon"
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
    end
  end

  def assignStat
    if @set_table["Variable"].first_set_include? @look_ahead
      if variable() && assignOp() && expr()
        write "AssignStat", "Variable", "AssignOp", "Expr"
      end
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
      write "StatBlock", "epsilon"
    end
  end

  def expr
    if @set_table["ArithExpr"].first_set_include? @look_ahead
      if arithExpr() && relExprTail()
        write "Expr", "ArithExpr", "RelExprTail"
      end
    end
  end

  def relExprTail
    if @set_table["RelOp"].first_set_include? @look_ahead
      if relOp() && arithExpr()
        write "RelExprTail", "RelOp", "ArithExpr"
      end
    elsif @set_table["RelExprTail"].follow_set_include? @look_ahead
      write "RelExprTail", "epsilon"
    end
  end

  def relExpr
    if @set_table["ArithExpr"].first_set_include? @look_ahead
      if arithExpr() && relOp() && arithExpr()
        write "RelExpr", "ArithExpr", "RelOp", "ArithExpr"
      end
    end
  end

  def arithExpr
    if @set_table["Term"].first_set_include? @look_ahead
      if term() && arithExprD_star()
        write "ArithExpr", "Term", "ArithExprDs"
      end
    end
  end

  def arithExprD_star
    if @set_table["ArithExprD"].first_set_include? @look_ahead
      if arithExprD() && arithExprD_star()
        write "ArithExprDs", "ArithExprD", "ArithExprDs"
      end
    elsif @set_table["ArithExprDs"].follow_set_include? @look_ahead
      write "ArithExprDs", "epsilon"
    end
  end

  def arithExprD
    if @set_table["AddOp"].first_set_include? @look_ahead
      if addOp() && term()
        write "ArithExprD", "AddOp", "Term"
      end
    end
  end

  def term
    if @set_table["Factor"].first_set_include? @look_ahead
      if factor() && termD_star()
        write "Term", "Factor", "TermDs"
      end
    end

  end

  def termD_star
    if @set_table["TermD"].first_set_include? @look_ahead
      if termD() && termD_star()
        write "TermDs", "TermD", "TermDs"
      end
    elsif @set_table["TermDs"].follow_set_include? @look_ahead
      write "TermDs", "epsilon"
    end
  end

  def termD
    if @set_table["MultOp"].first_set_include? @look_ahead
      if mulOp() && factor()
        write "TermD", "MulOp", "Factor"
      end
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
    end
  end

  def varHead
    if look_ahead_is "id"
      if match("id") && varHeadTail()
        write "VarHead", "id", "VarHeadTail"
      end
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
      write "VarHeadTail", "epsilon"
    end
  end

  def indice_star
    if @set_table["Indice"].first_set_include? @look_ahead
      if indice() && indice_star()
        write "Indices", "Indice", "Indices"
      end
    elsif @set_table["Indices"].follow_set_include? @look_ahead
      write "Indices", "epsilon"
    end
  end

  def varHeadEnd
    if look_ahead_is "."
      if match(".") && varHead()
        write "VarHeadEnd", ".", "VarHead"
      end
    elsif @set_table["VarHeadEnd"].follow_set_include? @look_ahead
      write "VarHeadEnd", "epsilon"
    end
  end


  def idnest
    if look_ahead_is "id"
      if match("id") && indice_star && match(".")
        write "Idnest", "idToken", "Indices", "."
      end
    end
  end

  def variable
    if look_ahead_is "id"
      if match("id") && indice_star() && variableTail()
        write "Variable", "idToken", "Indices", "VariableTail"
      end
    end
  end

  def variableTail
    if look_ahead_is "."
      if match(".") && variable()
        write "VariableTail", ".", "Variable"
      end
    elsif @set_table["VariableTail"].follow_set_include? @look_ahead
      write "VariableTail", "epsilon"
    end
  end

  def indice
    if look_ahead_is "["
      if match("[") && arithExpr() && match("]")
        write "Indice", "[", "ArithExpr", "]"
      end
    end
  end

  def arraySize
    if look_ahead_is "["
      if match("[") && match("integerNumber") && match("]")
        write "ArraySize", "[", "intToken", "]"
      end
    end
  end

  def type
    if look_ahead_is "int" or look_ahead_is "float"
      if match(@look_ahead.val.downcase)
        write "Type", @look_ahead.val.downcase
      end
    elsif look_ahead_is "id"
      if match("id")
        write "Type", @look_ahead.val.downcase
      end
    end
  end

  def fParams
    if @set_table["Type"].first_set_include? @look_ahead
      if type() && match("id") && arraySize_star() && fParamsTail_star()
        write "FParams", "Type", "idToken", "ArraySizes", "FParamsTails"
      end
    elsif @set_table["FParams"].follow_set_include? @look_ahead
      write "FParams", "epsilon"
    end
  end

  def fParamsTail_star
    if @set_table["FParamsTail"].first_set_include? @look_ahead
      if fParamsTail() && fParamsTail_star()
        write "FParamsTails", "FParamsTail", "FParamsTails"
      end
    elsif @set_table["FParamsTails"].follow_set_include? @look_ahead
      write "FParamsTails", "epsilon"
    end
  end

  def aParams
    if @set_table["Expr"].first_set_include? @look_ahead
      if expr() && aParamsTail_star()
        write "AParams", "Expr", "AParamsTails"
      end
    elsif @set_table["AParams"].follow_set_include? @look_ahead
      write "AParams", "epsilon"
    end
  end

  def aParamsTail_star
    if @set_table["AParamsTail"].first_set_include? @look_ahead
      if aParamsTail() && aParamsTail_star()
        write "AParamsTails", "AParamsTail", "AParamsTails"
      end
    elsif @set_table["AParamsTails"].follow_set_include? @look_ahead
      write "AParamsTails", "epsilon"
    end
  end

  def fParamsTail
    if look_ahead_is ","
      if match(",") && type() && match("id") && arraySize_star()
        write "FParamsTail", ",", "Type", "id", "ArraySizes"
      end
    end
  end

  def aParamsTail
    if look_ahead_is ","
      if match(",") && expr()
        write "aParamsTail", ",", "Expr"
      end
    end
  end

  def assignOp
    match(@look_ahead.val.downcase) if look_ahead_is "="
  end

  def relOp
    match(@look_ahead.val.downcase) if look_ahead_is "==" or look_ahead_is "<>" or look_ahead_is "<" or look_ahead_is ">" or look_ahead_is "<=" or look_ahead_is ">="
  end

  def addOp
    match(@look_ahead.val.downcase) if look_ahead_is "+" or look_ahead_is "-" or look_ahead_is "or"
  end

  def mulOp
    match(@look_ahead.val.downcase) if look_ahead_is "*" or look_ahead_is "/" or look_ahead_is "and"
  end

  def sign
    if look_ahead_is "-" or look_ahead_is "+"
      if match(@look_ahead.val.downcase)
        write "Sign", @tokens[@index - 1].val
      end
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
table = set_table.table

@tokenizer = Tokenizer.new
@tokenizer.text = "program{
  X_type x[1][2][3];
  x = y.func() and y.run();
  x = x.run(a, b);
  x = x.run(a + b, b and b[a] + 3 * (x + y[1][2]), 1, 2, 3.23);
};"
@tokenizer.tokenize
@tokenizer.remove_error
parser = Parsing.new(@tokenizer.tokens, table)
puts parser.parse

parser.write_to_file
