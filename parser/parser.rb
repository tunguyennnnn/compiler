require_relative '../lexical_analyzer/main.rb'

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
          current_set.push(word.gsub(',', ''))
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

class String
  def val
    self
  end
end

class Parsing
  attr_reader :tokens, :look_ahead
  def initialize(tokens, set_table)
    @tokens = tokens
    @tokens.push("$")
    @set_table = set_table
    @index = 0
    @stack = ""
  end

  def parse
    @look_ahead = @tokens[@index]
    if @set_table["Prog"].first_set_include? @look_ahead
      return prog() && match("$")
    end
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

  def write(derivation)
    @stack += "#{derivation}\n"
    return true
  end

  def look_ahead_is (token)
    if @look_ahead.kind_of? IdToken
      token == "id"
    elsif @look_ahead.kind_of? IntegerToken
      token == "integer" || token == "num"
    elsif @look_ahead.kind_of? FloatToken
      token == "num"
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
      return classDecl_star() && progBody()
    elsif @set_table["ProgBody"].first_set_include? @look_ahead
      return progBody()
    else
      false
    end
  end

  def classDecl_star
    if @set_table['ClassDec'].first_set_include? @look_ahead
      return classDecl() && classDecl_star()
    elsif @set_table['ClassDecs'].follow_set_include? @look_ahead
      return true
    end
  end

  def classDecl
    if look_ahead_is "class"
      return match("class") && match("id") && match("{") && classBody() && match("}") && match(";")
    end
  end

  def classBody
    if @set_table["Type"].first_set_include? @look_ahead
      return type() && match("id") && varOrFuncDecl()
    elsif @set_table["ClassBody"].follow_set_include? @look_ahead
      return true
    end
  end

  def varOrFuncDecl
    if @set_table["ArraySizes"].first_set_include? @look_ahead
      return arraySize_star() && match(";") && classBody()
    elsif look_ahead_is ";"
      return match(";") && classBody()
    elsif look_ahead_is "("
      return match("(") && fParams() && match(")") && funcBody() && match(";") && funcDef_star()
    end
  end

  def varDecl_star
    if @set_table["VarDecl"].first_set_include? @look_ahead
      return varDecl() && varDecl_star()
    elsif @set_table["VarDecls"].follow_set_include? @look_ahead
      return true
    end
  end

  def funcDef_star
    if @set_table["FuncDef"].first_set_include? @look_ahead
      return funcDef() && funcDef_star()
    elsif @set_table["FuncDefs"].follow_set_include? @look_ahead
      return true
    else
      return false
    end
  end

  def progBody
    if look_ahead_is "program"
      return match("program") && funcBody() && match(";") && funcDef_star()
    else
      return false
    end
  end

  def funcHead
    if @set_table["Type"].first_set_include? @look_ahead
      return type() && match("id") && match("(") && fParams() && match(")")
    end
  end

  def funcDef
    if @set_table["FuncHead"].first_set_include? @look_ahead
      return funcHead() && funcBody() && match(";")
    end
  end

  def funcBody
    if look_ahead_is "{"
      return match("{") && funcBodyInner() && match("}")
    end
  end

  def funcBodyInner
    if look_ahead_is "float"
      return match("float") && varDeclTail()
    elsif look_ahead_is "int"
      return match("int") && varDeclTail()
    elsif look_ahead_is "id"
      return match("id") && varDeclorAssignStat()
    elsif @set_table["StatmentSpecial"].first_set_include? @look_ahead
      return statementSpecial() && statement_star()
    elsif @set_table["FuncBodyInner"].follow_set_include? @look_ahead
      return true
    end
  end

  def varDeclTail
    if look_ahead_is "id"
      return match("id") && arraySize_star() && match(";") && funcBodyInner()
    end
  end

  def varDeclorAssignStat
    if look_ahead_is "id"
      return match("id") && arraySize_star() && match(";") && funcBodyInner()
    elsif @set_table["Indices"].first_set_include? @look_ahead
      return indices() && variableTail() && assignOp() && expr() && match(";")  && statement_star()
    elsif @set_table["AssignOp"].first_set_include? @look_ahead
      return assignOp() && expr() && match(";") && statement_star()
    end
  end

  def varDecl
    if @set_table["type"].first_set_include? @look_ahead
      return type() && match("id") && arraySize_star() && match(";")
    end
  end

  def statement_star
    if @set_table["Statement"].first_set_include? @look_ahead
      return statement() && statement_star()
    elsif @set_table["Statements"].follow_set_include? @look_ahead
      return true
    end
  end

  def arraySize_star
    if @set_table["ArraySize"].first_set_include? @look_ahead
      return arraySize() && arraySize_star()
    elsif @set_table["ArraySizes"].follow_set_include? @look_ahead
      return true
    end
  end

  def statement
    if @set_table["AssignStat"].first_set_include? @look_ahead
      return assignStat() && match(";")
    elsif @set_table["StatmentSpecial"].first_set_include? @look_ahead
      return statementSpecial()
    end
  end

  def statementSpecial
    if look_ahead_is "if"
      return match("if") && match("(") && expr() && match(")") && match("then") && statBlock() && match("else") && statBlock() && match(";")
    elsif look_ahead_is "for"
      return match("for") && match("(") && type() && match("id") && assignOp() && expr() && match(";") && relExpr() && match(";") && assignStat() && match(")") && statBlock() && match(";")
    elsif look_ahead_is "get"
      return match("get") && match("(") && variable() && match(")") && match(";")
    elsif look_ahead_is "put"
      return match("put") && match("(") && expr() && match(")") && match(";")
    elsif look_ahead_is "return"
      return match("return") && match("(") && expr() && match(")") && match(";")
    end
  end

  def assignStat
    if @set_table["Variable"].first_set_include? @look_ahead
      return variable() && assignOp() && expr()
    end
  end

  def statBlock
    if look_ahead_is "{"
      return match("{") && statement_star() && match("}")
    elsif @set_table["Statement"].first_set_include? @look_ahead
      return statement()
    elsif @set_table["StatBlock"].follow_set_include? @look_ahead
      return true
    end
  end

  def expr
    if @set_table["ArithExpr"].first_set_include? @look_ahead
      return arithExpr() && relExprTail()
    end
  end

  def relExprTail
    if @set_table["RelOp"].first_set_include? @look_ahead
      return relOp() && arithExpr()
    elsif @set_table["RelExprTail"].follow_set_include? @look_ahead
      return true
    end
  end
  def relExpr
    if @set_table["ArithExpr"].first_set_include? @look_ahead
      return arithExpr() && relOp() && arithExpr()
    end
  end

  def arithExpr
    if @set_table["Term"].first_set_include? @look_ahead
      return term() && arithExprD_star()
    end
  end

  def arithExprD_star
    if @set_table["ArithExprD"].first_set_include? @look_ahead
      return arithExprD() && arithExprD_star()
    elsif @set_table["ArithExprDs"].follow_set_include? @look_ahead
      return true
    end
  end

  def arithExprD
    if @set_table["AddOp"].first_set_include? @look_ahead
      return addOp() && term()
    end
  end

  def term
    if @set_table["Factor"].first_set_include? @look_ahead
      return factor() && termD_star()
    end

  end

  def termD_star
    if @set_table["TermD"].first_set_include? @look_ahead
      return termD() && termD_star()
    elsif @set_table["TermDs"].follow_set_include? @look_ahead
      return true
    end
  end

  def termD
    if @set_table["MultOp"].first_set_include? @look_ahead
      return mulOp() && factor()
    end
  end

  def factor
    if @set_table["VarHead"].first_set_include? @look_ahead
      return varHead()
    elsif look_ahead_is "num"
      return match("num")
    elsif look_ahead_is "("
      return match("(") && arithExpr() && match(")")
    elsif look_ahead_is "not"
      return match("not") && factor()
    elsif @set_table["Sign"].first_set_include? @look_ahead
      return sign() && factor()
    end
  end

  def varHead
    if look_ahead_is "id"
      return match("id") && varHeadTail()
    end
  end

  def varHeadTail
    if @set_table["Indices"].first_set_include? @look_ahead
      return indice_star() && varHeadEnd()
    elsif @set_table["VarHeadEnd"].first_set_include? @look_ahead
      return varHeadEnd()
    elsif look_ahead_is "("
      return match("(") && aParams() && match(")")
    elsif @set_table["VarHeadTail"].follow_set_include? @look_ahead
      return true
    end
  end

  def indice_star
    if @set_table["Indice"].first_set_include? @look_ahead
      return indice() && indice_star()
    elsif @set_table["Indices"].follow_set_include? @look_ahead
      return true
    end
  end

  def varHeadEnd

    if look_ahead_is "."
      return match(".") && varHead()
    elsif @set_table["VarHeadEnd"].follow_set_include? @look_ahead
      return true
    end
  end


  def idnest
    if look_ahead_is "id"
      return match("id") && indice_star && match(".")
    end
  end

  def variable
    if look_ahead_is "id"
      return match("id") && indice_star() && variableTail()
    end
  end

  def variableTail
    if look_ahead_is "."
      return match(".") && variable()
    elsif @set_table["VariableTail"].follow_set_include? @look_ahead
      return true
    end
  end

  def indice
    if look_ahead_is "["
      return match("[") && arithExpr() && match("]")
    end
  end

  def arraySize
    if look_ahead_is "["
      return match("[") && match("integer") && match("]")
    end
  end

  def type
    if look_ahead_is "int" or look_ahead_is "float" or look_ahead_is "id"
      return match(@look_ahead.val.downcase)
    end
  end

  def fParams
    if @set_table["Type"].first_set_include? @look_ahead
      return type() && match("id") && arraySize_star() && fParamsTail_star()
    elsif @set_table["FParams"].follow_set_include? @look_ahead
      return true
    end
  end

  def fParamsTail_star
    if @set_table["FParamsTail"].first_set_include? @look_ahead
      return fParamsTail() && fParamsTail_star()
    elsif @set_table["FParamsTails"].follow_set_include? @look_ahead
      return true
    end
  end

  def aParams
    if @set_table["Expr"].first_set_include? @look_ahead
      x = expr()
      return x && aParamsTail_star()
    elsif @set_table["AParams"].follow_set_include? @look_ahead
      return true
    end
  end

  def aParamsTail_star
    if @set_table["AParamsTail"].first_set_include? @look_ahead
      return aParamsTail() && aParamsTail_star()
    elsif @set_table["AParamsTails"].follow_set_include? @look_ahead
      return true
    end
  end

  def fParamsTail
    if look_ahead_is ","
      return match(",") && type() && match("id") && arraySize_star()
    end
  end

  def aParamsTail
    if look_ahead_is ","
      return match(",") && expr()
    end
  end

  def assignOp
    match(@look_ahead.val.downcase) if look_ahead_is "="
  end

  def relOp
    match(@look_ahead.val.downcase) if look_ahead_is "==" or look_ahead_is "<>" or look_ahead_is "<" or look_ahead_is ">" or look_ahead_is "<=" or look_ahead_is "=>"
  end

  def addOp
    match(@look_ahead.val.downcase) if look_ahead_is "+" or look_ahead_is "-" or look_ahead_is "or"
  end

  def mulOp
    match(@look_ahead.val.downcase) if look_ahead_is "*" or look_ahead_is "/" or look_ahead_is "and"
  end

  def id
  end

  def float
  end

  def integer
  end

end


#2: intersection type id of variable declaration and func declaration -> merge 2 things into one
#3: program .... and function after man function ->

#expr: -> dont allow 1 < 2 > 1
#idnest:

#indice: inside is an expression could be a.b.c.d.e


a = FirstFollowSetTable.new
a.insert_from_file 'set_table.txt'
tokenizer = Tokenizer.new
tokenizer.text =
"class Utility
{
int var1[4][5][7][8][9][1][0];
float var2;
int findMax(int array[100])
{
int maxValue;
int idx;
maxValue = array[100];
for( int idx = 99; idx > 0; idx = idx - 1 )
{
if(array[idx] > maxValue) then {
maxValue = array[idx];
}else{};
};
return (maxValue);
};
int findMin(int array[100])
{
int minValue;
int idx;
minValue = array[100];
for( int idx = 1; idx <= 99; idx = ( idx ) + 1)
{
if(array[idx] < maxValue) then {
maxValue = array[idx];
}else{};
};
return (minValue);
};
};
program {
int sample[100];
int idx;
int maxValue;
int minValue;
Utility utility;
Utility arrayUtility[2][3][6][7];
for(int t = 0; t<=100 ; t = t + 1)
{
get(sample[t]);
sample[t] = (sample[t] * randomize());
};
maxValue = utility.findMax(sample);
minValue = utility.findMin(sample);
utility. var1[4][1][0][0][0][0][0] = 10;
arrayUtility[1][1][1][1].var1[4][1][0][0][0][0][0] = 2;
put(maxValue);
put(minValue);
};
float randomize()
{
float value;
value = 100 * (2 + 3.0 / 7.0006);
value = 1.05 + ((2.04 * 2.47) - 3.0) + 7.0006 ;
return (value);
};"
tokenizer.tokenize
tokenizer.remove_error

x = Parsing.new(tokenizer.tokens, a.table)
puts x.parse
