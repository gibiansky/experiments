module Assembly.Parser 
  (parseAssembly, postProcess, Instruction (..), Command (..), Argument(..), Value(..))
  where

import Text.ParserCombinators.Parsec
import Control.Monad
import Numeric
import Data.List
import Debug.Trace

-- Data type definitons:
-----------------------------------------------------
-- The instruction type
data Instruction = Move |
                   MoveByte |
                   Add |
                   Sub |
                   Mul |
                   Div |
                   And |
                   Or  |
                   Equal    |
                   NotEqual |
                   Not      |
                   Negate   |
                   Less     |
                   LessEq   |
                   Greater  |
                   GreaterEq |
                   Jump      |
                   JumpIf     |
                   JumpUnless |
                   JumpToReg |
                   Repeat |
                   Ascii |
                   Call |
                   Return |
                   Push |
                   Pop |
                   LightLed | 
                   LightNumber |
                   ReadSwitch |
                   UnknownInstruction String
                   deriving Eq

-- A command (a full instruction or a label)
data Command = Command Instruction [Argument] |
               Label String |
               InternalCommand String [Argument]
               deriving Eq

-- An argument to an instruction
data Argument = LabelArg String |
                ValueArg Value
                deriving Eq

-- A value argument (register, memory address, or constant)
data Value = Register Int |
             Memory Int Int |
             Constant Int |
             Str String 
             deriving Eq

instance Show Command where
  show (Command inst []) = "  " ++ show inst
  show (Command inst args) = 
    let (sArg : sArgs) = map show args in 
      "  " ++ show inst ++ " " ++ foldl (\l r -> l ++ ", " ++ r) sArg sArgs
  show (Label name) = "\n" ++ name ++ ":\n"
  show (InternalCommand str args) =
    let (sArg : sArgs) = map show args in 
      "  " ++ str ++ " " ++ foldl (\l r -> l ++ ", " ++ r) sArg sArgs

instance Show Instruction where
    show Move = "move"
    show MoveByte = "move-byte"
    show Add = "add"
    show Sub = "sub"
    show Mul = "mul"
    show Div = "div"
    show And = "and"
    show Or = "or"
    show Equal = "eq"
    show NotEqual = "neq"
    show Not = "not"
    show Negate = "negate"
    show Less = "lt"
    show LessEq = "lte"
    show Greater = "gt"
    show GreaterEq = "gte"
    show Jump = "jump"
    show JumpIf = "jump-if"
    show JumpUnless = "jump-unless"
    show JumpToReg = "goto"
    show Repeat = "repeat"
    show Ascii = "string"
    show Call = "call"
    show Return = "return"
    show Pop = "pop"
    show Push = "push"
    show LightLed = "led"
    show LightNumber = "number"
    show ReadSwitch = "switch"

instance Show Argument where
  show (LabelArg name) = name
  show (ValueArg val) = show val

instance Show Value where
  show (Register num) = "$" ++ showRegister num
  show (Constant int) = show int
  show (Memory regnum offset) = "$" ++ showRegister regnum ++ "[" ++ show offset ++ "]"
  show (Str str) = "\"" ++ str ++ "\""

showRegister 0 = "0"
showRegister 1 = "1"
showRegister 2 = "2"
showRegister 3 = "3"
showRegister 4 = "4"
showRegister 5 = "5"
showRegister 6 = "6"
showRegister 7 = "7"
showRegister 8 = "8"
showRegister 9 = "9"
showRegister 10 = "instruction"
showRegister 11 = "stack"
showRegister 12 = "out"
showRegister 13 = "ret"
showRegister 14 = "frame"
showRegister 15 = "static"
showRegister n  
  | n > 31 || n < 0 = "reg(" ++ show n ++ ")"
  | n <= 23 = "arg-" ++ show (n - 16)
  | n <= 29 = "saved-" ++ show (n - 24)
  | n <= 31 = "temp-" ++ show (n - 30)
-----------------------------------------------------

-- Convert between strings and our data types
-----------------------------------------------------

-- Convert a string into an instruction
instruction :: String -> Instruction
instruction "move"      = Move
instruction "move-byte" = MoveByte
instruction "add"       = Add
instruction "sub"       = Sub
instruction "mul"       = Mul
instruction "div"       = Div
instruction "and"       = And
instruction "or"        = Or
instruction "eq"        = Equal
instruction "neq"       = NotEqual
instruction "not"       = Not
instruction "negate"    = Negate
instruction "lt"        = Less
instruction "lte"       = LessEq
instruction "gt"        = Greater
instruction "gte"       = GreaterEq
instruction "jump"      = Jump
instruction "jump-if"   = JumpIf
instruction "jump-unless"= JumpUnless
instruction "goto"      = JumpToReg
instruction "led"       = LightLed
instruction "number"    = LightNumber
instruction "switch"    = ReadSwitch

instruction "repeat"    = Repeat
instruction "string"    = Ascii
instruction "push"      = Push
instruction "pop"       = Pop
instruction "call"      = Call
instruction "return"    = Return

instruction i           = UnknownInstruction i

-- Convert a register name into a number
regnum "0" = 0
regnum "1" = 1
regnum "2" = 2
regnum "3" = 3
regnum "4" = 4
regnum "5" = 5
regnum "6" = 6
regnum "7" = 7
regnum "8" = 8
regnum "9" = 9
regnum "instruction" = 10
regnum "stack" = 11
regnum "out" = 12
regnum "ret" = 13
regnum "frame" = 14
regnum "static" = 15

regnum "arg-0" = 16
regnum "arg-1" = 17
regnum "arg-2" = 18
regnum "arg-3" = 19
regnum "arg-4" = 20
regnum "arg-5" = 21
regnum "arg-6" = 22
regnum "arg-7" = 23

regnum "saved-0" = 24
regnum "saved-1" = 25
regnum "saved-2" = 26
regnum "saved-3" = 27
regnum "saved-4" = 28
regnum "saved-5" = 29
-----------------------------------------------------

-- Perform parsing
-----------------------------------------------------

-- Parse a string into a list of commands
parseAssembly :: String -> Either ParseError [Command]
parseAssembly input = 
  let result = parse file "assembly" input in
    case result of
      Left err -> result
      Right commands -> Right $ postProcess 0 commands

-- Parse an entire file, with many lines
file :: Parser [Command]
file = do
  commands <- many $ try line
  many whitespace
  eof
  return commands

-- Parse a single line
line :: Parser Command
line =
  do skip
     value <- symbol
     let inst = instruction value
     case inst of
          UnknownInstruction value -> linelabel value
          i -> command i

-- Attempt to parse the end of a label. If parsing a label marker succeeds, 
-- return a label with the name given by the input.
linelabel :: String -> Parser Command
linelabel name = 
  do char ':'
     return $ Label name

-- Parse a command given an instruction
command :: Instruction -> Parser Command
command inst =  
  do args <- arguments
     return $ Command inst args

-- Parse an argument list
arguments :: Parser [Argument]
arguments = sepBy argument comma

-- Parse an argument to an instruction
argument :: Parser Argument
argument = 
  do spaces
     try memory <|> try registerarg <|> try constant <|> try strarg <|> labelarg

-- Parse a comma
comma :: Parser Char
comma = char ','

-- Parse a comment
-- A comment begins with a semicolon (;) and ends at the end of line
-- Return the comment string
comment :: Parser String
comment = do
  char ';'
  str <- many (noneOf "\n")
  eol
  return str

-- Parse a whitespace character
-- Return it as a string
whitespace :: Parser String
whitespace = do
  c <- oneOf " \n\t"
  return [c]

-- Parse anything that has no meaning and that we want to skip
-- This includes comments and whitespace
skip :: Parser [String]
skip = many $ comment <|> whitespace

-- Parse a symbol
symbol :: Parser String
symbol = many (alphaNum <|> char '-' <|> char '_')

-- Parse a label argument
labelarg :: Parser Argument
labelarg = do
  s <- symbol
  return $ LabelArg s

-- Parse a register name
regname :: Parser String
regname = do
  (string "0") <|>
    (string "1") <|>
    (string "2") <|>
    (string "3") <|>
    (string "4") <|>
    (string "5") <|>
    (string "6") <|>
    (string "7") <|>
    (string "8") <|>
    (string "9") <|>
    try (string "instruction") <|>
    try (string "stack") <|>
    try (string "out") <|>
    try (string "ret") <|>
    try (string "static") <|>
    try (string "frame") <|>
    try (string "arg-0") <|>
    try (string "arg-1") <|>
    try (string "arg-2") <|>
    try (string "arg-3") <|>
    try (string "arg-4") <|>
    try (string "arg-5") <|>
    try (string "arg-6") <|>
    try (string "arg-7") <|>
    try (string "saved-0") <|>
    try (string "saved-1") <|>
    try (string "saved-2") <|>
    try (string "saved-3") <|>
    try (string "saved-4") <|>
    try (string "saved-5")

-- Convert a parsed register into an argument
registerarg :: Parser Argument
registerarg = do
  r <- register
  return $ ValueArg $ Register $ r

-- Parse a register number
register :: Parser Int
register = do
  char '$'
  name <- regname
  return $ regnum name
  
-- Parse a memory address as register / offset pair
memory :: Parser Argument
memory = do
  reg <- register
  char '['
  offset <- number
  char ']'
  return $ ValueArg $ Memory reg offset

strarg :: Parser Argument
strarg = do
  char '"'
  str <- many (noneOf "\n\"")
  char '"'
  return $ ValueArg $ Str $ read $ "\"" ++ str ++ "\""

-- Parse end of line
eol :: Parser Char
eol = char '\n'
-----------------------------------------------------

-- Number parsing
-----------------------------------------------------

-- Read in a numeric string in different bases
numstr :: Parser String
numstr = many1 $ oneOf "0123456789"

hexstr :: Parser String
hexstr = many1 $ oneOf "0123456789abcdefABCDEF"

binstr :: Parser String
binstr = many1 $ oneOf "01"

-- Convert a parsed integer into a constant value
constant :: Parser Argument
constant = do
  const <- number
  return $ ValueArg $ Constant const

-- Parse a number
number :: Parser Int
number = try hexadecimal <|> try binary <|> decimal

-- Parse a hex number (0x)
hexadecimal :: Parser Int
hexadecimal = do
  string "0x"
  hexnum <- hexstr
  let [(num, remaining)] = readHex hexnum
  return num
  
-- Parse a binary (0b) number
binary :: Parser Int
binary = do
  string "0b"
  binnum <- binstr
  -- Create a binary parser
  let readBin = readInt 2 (`elem` "01") (\x -> if x == '0' then 0 else 1)
  let [(num, remaining)] = readBin binnum
  return num
  
-- Parse a normal, decimal number
decimal :: Parser Int
decimal = do
  num <- numstr
  return $ read num

-----------------------------------------------------

-- Post-processor macros
-----------------------------------------------------

data Macro = Replacement Instruction ([Argument] -> [Command])

genRegisterArg :: Int -> Argument
genRegisterArg x = ValueArg (Register x)

regInstruction = 10
regStack = 11
regOut = 12
regReturn = 13
regFrame = 14

macroCall = Replacement Call (\[LabelArg destination] -> 
  [
    Command Push $ [genRegisterArg regReturn],
    Command Push $ [genRegisterArg regFrame],
    Command Move $ [genRegisterArg regFrame, genRegisterArg regStack],
    Command Add  $ [genRegisterArg regInstruction, ValueArg $ Constant 1],
    Command Move $ [genRegisterArg regReturn, genRegisterArg regOut],
    Command Jump $ [LabelArg destination]
  ])


macroReturn = Replacement Return (\empty ->
  [
    
    Command Pop $ [genRegisterArg regFrame],
    Command Move $ [genRegisterArg 0, genRegisterArg regReturn],
    Command Pop $ [genRegisterArg regReturn],
    Command JumpToReg $ [genRegisterArg 0]
  ])

macroPush = Replacement Push (\[ValueArg val] ->
  [
    Command Move $ [ValueArg (Memory regStack 4), ValueArg val],
    Command Add $ [genRegisterArg regStack, ValueArg $ Constant 4],
    Command Move $ [genRegisterArg regStack, genRegisterArg regOut]
  ])

macroPop = Replacement Pop (\[ValueArg val] ->
  [
    Command Move $ [ValueArg val, ValueArg $ Memory regStack  (-4)],
    Command Add $ [genRegisterArg regStack, ValueArg $ Constant (-4)],
    Command Move $ [genRegisterArg regStack, genRegisterArg regOut]
  ])

macros = [macroCall, macroReturn, macroPush, macroPop]

postProcess :: Int -> [Command] -> [Command]
postProcess 0 cs = cs
postProcess level commands = 
  let prevLength = length commands
      result = concatMap replacement commands
      newLength = length result 
      in if prevLength /= newLength
         then postProcess (level - 1) result
         else result

replacement :: Command -> [Command]
replacement (Command inst args) = 
  let macroMatcher (Replacement mac fun) = (mac == inst) in
    case find macroMatcher macros of
      Nothing -> [Command inst args]
      Just (Replacement _ processor) -> processor args

replacement lab = [lab]

-----------------------------------------------------
