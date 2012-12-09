module Simple.Parser 
  (Type(..), Expression(..), Value(..), InfixOp(..), PrefixOp(..), Var(..), 
   parseSimple, position, value, nulltype)
  where

import Text.ParserCombinators.Parsec
import Text.ParserCombinators.Parsec.Expr
import Control.Monad
import Numeric
import Debug.Trace
import Data.Functor.Identity

-- Data type definitons:
-----------------------------------------------------

-- Possible variable types
-- Note that Null can be any of these.
data Type = IntType  |
            CharType |
            ArrayType Type |
            StructType String |
            NullType 
            deriving (Show)

instance Eq Type where
  first == second =
    case (first, second) of
      (NullType, _) -> True
      (_, NullType) -> True

      (IntType, IntType) -> True
      (CharType, CharType) -> True

      (ArrayType a, ArrayType b) -> a == b
      (StructType a, StructType b) -> a == b

      _ -> False

-- Check whether a type is null
--
-- We need a separate function for this because equality
-- cannot tell you whether any given type is null.
nulltype :: Type -> Bool
nulltype NullType = True
nulltype _ = False

-- Expression data type
-- All expressions that are non-null have a type, while
-- null can be assimilated into any type.
data Expression = Expr SourcePos Value |
                  NullExpr

-- Expression values
data Value      = NumVal Int |
                  StrVal String |
                  CharVal Char |
                  SizeOfVal Type |

                  CastVal Type Expression | 

                  BlockVal [Expression] |
                  IfVal Expression Expression Expression |
                  WhileVal Expression Expression |
                  ForVal Expression Expression Expression Expression |
                  DeclareVal Var Expression |
                  AssignVal String Expression |
                  InfixVal InfixOp Expression Expression |
                  PrefixVal PrefixOp Expression |
                  FuncVal String Type [Var] Expression |
                  FuncallVal String [Expression] |
                  AssemblyVal Type String |
                  StructVal String [Var] |
                  VarVal String
                  deriving (Show)

data Var = Var String Type 
           deriving Show

data InfixOp = Plus | Minus | Times | Divide | Mod | ArrayRef | ArrayWrite |
               Exponentiate | And | Or | BitAnd | BitOr | DataRef |
               Equals | NotEquals | Greater | Less | GreaterEq | LessEq
               deriving Show

data PrefixOp = Negative | BitNegate | Address
                deriving Show 

-- Pretty-print expressions
instance Show Expression where
  show (Expr pos val) = "(" ++ show val ++ ")"
  show NullExpr = "NULL"
-----------------------------------------------------

-- Top level parser: Parse a string into a list of expressions
-----------------------------------------------------
parseSimple :: String -> String -> Either ParseError [Expression]
parseSimple input filename = parse expressions filename input

-- Parse a list of expressions
expressions :: Parser [Expression]
expressions = do
  exprs <- many $ try expression
  skipped eof
  return exprs

-- Parse an expression. Parsers should always begin with a skip, so that
-- comments and whitespace do not matter.
expression :: Parser Expression
expression = do
  try infixExpr <|> nonInfixExpression

-- Parse an expression, but don't allow infix expressions
-- We separate this from the others because infix expressions
-- can only have non-infix expressions as the terms.
nonInfixExpression :: Parser Expression
nonInfixExpression = do
  -- Try all parsers in order. Note that order is important in some cases.
  let expressionParsers = [parens expression, structExpr, whileExpr, functionExpr, sizeExpr,
                          assemblyExpr, forExpr, numExpr, declareExpr, castExpr, funcallExpr, 
                          charExpr, stringExpr, assignExpr, doExpr, ifExpr, varExpr]
      attempts = map try expressionParsers

  -- Skip whitespace after the expression instead of before due to quirks in the
  -- infix expression parser provided by Parsec.
  out <- foldl (<|>) (head attempts) (tail attempts)
  skip
  return out

-- Parse an element in parentheses
parens :: Parser a -> Parser a
parens parser = do
  skipped $ char '('
  x <- parser

  skipped $ char ')'
  return x

castExpr :: Parser Expression
castExpr = do
  pos <- skip
  string "cast"
  (typename, expr) <- parens (do
                                e <- skipped expression
                                skipped $ string "to"
                                t <- skipped datatype
                                return (t, e))
                               
  return $ Expr pos $ CastVal typename expr


sizeExpr :: Parser Expression
sizeExpr = do
  pos <- skip
  string "sizeof"
  typename <- parens datatype
  return $ Expr pos $ SizeOfVal typename

-- Parse an assignment
assignExpr :: Parser Expression
assignExpr = do
  pos <- skip
  dest <- identifier

  skipped $ char '='
  exp <- skipped expression

  return $ Expr pos $ AssignVal dest exp

-- Parse a struct declaration
structExpr :: Parser Expression
structExpr = do
  pos <- skip
  string "struct"

  name <- identifier
  elements <- parens varlist
  return $ Expr pos $ StructVal name elements

-- Parse a function call
funcallExpr :: Parser Expression
funcallExpr = do
  pos <- skip

  funname <- identifier
  args <- parens funcArgs

  return $ Expr pos $ FuncallVal funname args 

-- Parse a series of comma-separated expressions
-- This is used for function argument parsing.
funcArgs :: Parser [Expression]
funcArgs = do
  skipped $ expression `sepBy` (skipped $ char ',')

-- Parse an assembly function declaration
assemblyExpr :: Parser Expression
assemblyExpr = do
  pos <- skip
  string "assembly"

  typeSym
  d <- datatype
  asm <- stringLiteral
  return $ Expr pos $ AssemblyVal d asm

-- Convert a string literal into an expression
charExpr :: Parser Expression
charExpr = do
  pos <- skip
  char '\''
  c <- anyChar
  if c == '\\'
  then do
    myChar <- anyChar
    char '\''
    return $ Expr pos $ CharVal $ read ("'" ++ [myChar] ++ "'")
  else do
    char '\''
    return $ Expr pos $ CharVal c

-- Convert a string literal into an expression
stringExpr :: Parser Expression
stringExpr = do
  pos <- skip
  str <- stringLiteral
  return $ Expr pos $ StrVal str

-- Parse a string literal
stringLiteral :: Parser String
stringLiteral = try multiLineString <|> singleLineString

-- Allow multiple-line string literals with <<< and >>>
multiLineString :: Parser String
multiLineString = do
  skipped $ string "<<<"

  str <- many $ (notFollowedBy (string ">>>")) >> anyChar
  skipped $ string ">>>"
  return str

-- Allow single-line strings with quotes
-- Note that this implementation also permits the strings to span multiple lines.
singleLineString :: Parser String
singleLineString = do
  skipped $ char '"'

  str <- many $ (notFollowedBy (char '"')) >> anyChar
  char '"'
  return $ read $ "\"" ++ str ++ "\""

-- Parse a function declaration
functionExpr :: Parser Expression
functionExpr = do
  pos <- skip
  string "function"

  name <- identifier
  typeSym
  retType <- datatype
  args <- parens varlist
  b <- block
  return $ Expr pos $ FuncVal name retType args b

-- Parse a function argument list 
varlist :: Parser [Var]
varlist = skipped $ var `sepBy` (skip >> char ',')

-- Parse a function argument which has a name and a type
var :: Parser Var
var = do
  name <- skipped identifier
  typeSym
  d <- datatype
  return $ Var name d

-- Parse a variable declaration (and possible assignment)
declareExpr :: Parser Expression
declareExpr = do 
  -- The convention is that any parser which generates an expression
  -- gets the position right after skipping whitespace and comments.
  pos <- skip

  var <- var
  val <- try assignment <|> return NullExpr
  return $ Expr pos $ DeclareVal var val

-- Parse the second half of an assignment, starting with the equal sign.
assignment :: Parser Expression
assignment = do
  skipped $ char '='
  skipped expression

-- Parse a number
numExpr :: Parser Expression
numExpr = do
  pos <- skip
  str <- many1 (oneOf "0123456789")
  return $ Expr pos $ NumVal $ fst (readDec str !! 0)

-- Parse a variable reference
varExpr :: Parser Expression
varExpr = do
  pos <- skip

  ident <- identifier
  return $ Expr pos $ VarVal ident

-- Parse a while loop.
whileExpr :: Parser Expression
whileExpr = do
  pos <- skip
  string "while"

  condition <- skipped expression
  exprs <- block

  return $ Expr pos $ WhileVal condition exprs

-- Parse a for loop.
forExpr :: Parser Expression
forExpr = do
  pos <- skip
  string "for"

  initialization <- skipped expression
  skipped $ char ';'
  condition <- skipped expression
  skipped $ char ';'
  increment <- skipped expression
  exprs <- block

  return $ Expr pos $ ForVal initialization condition increment exprs

-- Parse a do statement, which executes a block and returns the last value.
doExpr :: Parser Expression
doExpr = do
  pos <- skip
  string "do"
  skipped block

-- Parse an if statement. This may or may not have an else clause;
-- if it doesn't, the else class is replaced with a Null expression.
ifExpr :: Parser Expression
ifExpr = do
  pos <- skip
  string "if"

  condition <- skipped expression
  consequence <- block
  alternative <- ifAlternative

  -- Check that the types of the then and else blocks are the same
  return $ Expr pos $ IfVal condition consequence alternative 

-- Parse the alternative of an if statement. If we can't find one, return a null.
ifAlternative :: Parser Expression
ifAlternative = try (skip >> string "else" >> block) <|> return NullExpr

-- Parse a block. Blocks are series of expressions surrounded by braces and
-- separated internally by semicolons. (Semicolons must go between expressions
-- in a block, not after each expression.) A block cannot be empty.
block :: Parser Expression
block = do
  pos <- skip

  string "{"
  exprs <- blockExpressions

  skipped $ string "}"
  -- The type of a block is the type of the last expression. The value of
  -- a block is the value of its last expression.
  return $ Expr pos $ BlockVal exprs

blockExpressions :: Parser [Expression]
blockExpressions = do
  try (do
         firstExpr <- skipped expression
         exprs <- many $ try $ skipped $ semicolon >> expression 
         return $ firstExpr:exprs)
      <|> return []

-- Parse a datatype. This can be one of the predefined datatypes, or
-- can be an array (pointer to) one of the predefined datatypes.
datatype :: Parser Type
datatype = do
  skip
  try (string "int" >> return IntType) <|>
    try (string "char" >> return CharType) <|>
    try (identifier >>= \x -> return $ StructType x) <|>
      do
        char '['
        subtype <- datatype
        skipped $ char ']'
        return $ ArrayType subtype
-----------------------------------------------------

-- Infix operator parsing
-----------------------------------------------------
infixOperatorTable :: OperatorTable Char () Expression
infixOperatorTable = [
                       [
                         Prefix (prefixOp "@" Address)
                       ],
                       [
                         Infix (binaryInfixOp "." DataRef) AssocLeft
                       ],
                       [
                         Infix (binaryInfixOp "#" ArrayRef) AssocLeft
                       ],
                       [
                         Infix (binaryInfixOp "←" ArrayWrite) AssocLeft
                       ],
                       {-
                       [
                         Infix (binaryInfixOp "^" Exponentiate) AssocRight
                       ],
                       -}
                       [
                         Prefix (prefixOp "~" BitNegate),
                         Prefix (prefixOp "-" Negative)
                       ],
                       [
                         Infix (binaryInfixOp "*" Times) AssocLeft,
                         Infix (binaryInfixOp "/" Divide) AssocLeft
                       ],
                       [
                         Infix (binaryInfixOp "+" Plus) AssocLeft,
                         Infix (binaryInfixOp "-" Minus) AssocLeft
                       ],
                       {-
                       [
                         Infix (binaryInfixOp "%" Mod) AssocLeft
                       ],
                       -}
                       [
                         Infix (binaryInfixOp "&" BitAnd) AssocLeft,
                         Infix (binaryInfixOp "|" BitOr) AssocLeft
                       ],
                       [
                         Infix (binaryInfixOp "==" Equals) AssocLeft,
                         Infix (binaryInfixOp "!=" NotEquals) AssocLeft,
                         Infix (binaryInfixOp ">" Greater) AssocLeft,
                         Infix (binaryInfixOp ">=" GreaterEq) AssocLeft,
                         Infix (binaryInfixOp "<" Less) AssocLeft,
                         Infix (binaryInfixOp "<=" LessEq) AssocLeft
                       ],
                       [
                         Infix (binaryInfixOp "==" Equals) AssocLeft,
                         Infix (binaryInfixOp "!=" NotEquals) AssocLeft,
                         Infix (binaryInfixOp ">" Greater) AssocLeft,
                         Infix (binaryInfixOp ">=" GreaterEq) AssocLeft,
                         Infix (binaryInfixOp "<" Less) AssocLeft,
                         Infix (binaryInfixOp "<=" LessEq) AssocLeft
                       ],
                       [
                         Infix (binaryInfixOp "&&" And) AssocLeft,
                         Infix (binaryInfixOp "||" Or) AssocLeft
                       ]
                     ]

binaryInfixOp :: String -> InfixOp -> Parser (Expression -> Expression -> Expression)
binaryInfixOp name op = do
  -- Due to constraints of the expression parser, we have to
  -- skip whitespace after the token instead of before, as is the convention.
  pos <- getPosition
  string name
  skip

  -- Return a function that composes two expressions into an expression with this operator
  return $ \left right -> Expr pos $ (InfixVal op left right)

prefixOp :: String -> PrefixOp -> Parser (Expression -> Expression)
prefixOp name op = do
  -- Due to constraints of the expression parser, we have to
  -- skip whitespace after the token instead of before, as is the convention.
  pos <- getPosition
  string name
  skip

  -- Return a function that composes two expressions into an expression with this operator
  return $ \a -> Expr pos $ (PrefixVal op a)

infixExpr = buildExpressionParser infixOperatorTable nonInfixExpression
-----------------------------------------------------

-- Convenience token parsers:
-----------------------------------------------------
-- Parse a type symbol. This token divides a variable name
-- and the declared type; it occurs in variable and function declarations.
typeSym :: Parser String
typeSym = skipped $ string "::"

-- Parse a semicolon
semicolon :: Parser Char
semicolon = skipped $ char ';'

-- Parse an identifier. These match [a-zA-Z0-9_]+
identifier :: Parser String
identifier = skipped $ many1 $ alphaNum <|> oneOf "_"

-- Wrap a parser in skips
skipped :: Parser a -> Parser a
skipped parser = do
  skip
  x <- parser
  skip
  return x

-- Skip anything that isn't code: whitespace and comments
skip :: Parser SourcePos
skip = do
  many $ whitespace <|> comment
  getPosition

-- Parse a whitespace character
-- Return it as a string
whitespace :: Parser String
whitespace = do
  c <- oneOf " \n\t"
  return [c]

-- Parse a comment
-- Return the comment string
comment :: Parser String
comment = (try singleLineComment) <|> multiLineComment

-- Single line comments start with a // and end at the end of the line
singleLineComment :: Parser String
singleLineComment = do
  string "$:"
  str <- many (noneOf "\n")
  eol
  return str

-- Multiline comments start with a /* and end with a */
multiLineComment :: Parser String
multiLineComment = do
  string "$("
  str <- many $ noneOf ")" <|> try (char ')' >> noneOf "$")
  string ")$"
  return str

-- Parse end of line
eol :: Parser Char
eol = char '\n'

-- Pretty print position of an expression
position :: Expression -> String
position (Expr a b) = (show a) ++ "\n"
position NullExpr = ""

-- Get the value out of an expression
value :: Expression -> Value
value (Expr pos val) = val
-----------------------------------------------------
