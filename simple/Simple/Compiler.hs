module Simple.Compiler (compileSimple)
  where


import qualified Simple.SymbolTable as Sym
import Simple.ControlFlowGraph
import Simple.Parser as Simple
import Assembly.Parser as Asm
import Text.Parsec.Prim
import Control.Monad.Identity
import Data.List
import Data.Char
import Debug.Trace

-- Processor state and parser declaration
----------------------------------- {
-- Processor state consists of:
--   1. Function table
--   2. Data structure table
--   3. Symbol table (mapping from variable name to memory location)
--   4. Mapping between global variable name and static offset
--   5. Register number currently being used
--   6. List of commands
type CompileState = (Sym.SymbolTable (Type, [Var]),
                     Sym.SymbolTable [Var],
                     Sym.SymbolTable (Type, Argument),
                     Sym.SymbolTable Int,
                     Int,
                     [Command])

type Processor a = ParsecT [Expression] CompileState Identity a
type Compiler = Processor ()
----------------------------------- }

-- Functions for manipulating the state of the parser
----------------------------------- {

-- State updaters and accessors
-- {

-- Add a command to the end of the command list
command :: Command -> Compiler
command cmd = 
  -- Note that the way we are doing this, the commands end up backwards.
  -- We later reverse them before returning, in compileSimple.
  let updater (a, b, c, d, x, commands) = (a, b, c, d, x, cmd : commands)
      in updateState updater

-- Enter a new block in the symbol table
startBlock :: Compiler
startBlock = 
  let updater (b, c, sym, d, e, f) = (b, c, Sym.startBlock sym, d, e, f)
      in updateState updater

-- Exit the top block in the symbol table
endBlock :: Compiler
endBlock = 
  let updater (b, c, sym, d, e, f) = (b, c, Sym.endBlock sym, d, e, f)
      in updateState updater

-- Add a symbol to the symbol table
symbol :: String -> (Type, Argument) -> Compiler
symbol name loc =
  let updater (b, c, sym, d, e, f) = (b, c, Sym.add name loc sym, d, e, f)
      in updateState updater

-- Add a struct type to the data structure table
struct :: String -> [Var] -> Compiler
struct name val = 
  let updater (b, structs, c, d, e, f) = (b, Sym.add name val structs, c, d, e, f)
      in updateState updater

-- Add a function to the function table
function :: String -> (Type, [Var]) -> Compiler
function name val = 
  let updater (funcs, b, c, d, e, f) = (Sym.add name val funcs, b, c, d, e, f)
      in updateState updater

-- Gets the next register number
nextRegister :: Processor Int
nextRegister = do
  (b, c, a, o, num, d) <- getState
  let updater (b, c, a, o, num, d) = (b, c, a, o, num + 1, d)
      in updateState updater >> return num

-- Retrieve the symbol table
getSymbol :: String -> Processor (Type, Argument)
getSymbol name = do
  st <- getState
  case st of
    (_, _, sym, _, _, _) -> return $ Sym.get name sym

-- Retrieve the struct table
getStruct :: String -> Processor [Var]
getStruct name = do 
  st <- getState
  case st of
    (_, structs, _, _, _, _) -> return $ Sym.get name structs

-- Retrieve the function table
getFunction :: String -> Processor (Type, [Var])
getFunction name = do
  st <- getState
  case st of
    (funcs, _, _, _, _, _) -> return $ Sym.get name funcs

-- Get the current index in the command list
getCurrentCommandIndex :: Processor Int
getCurrentCommandIndex = do
  st <- getState
  case st of
    (_, _, _, _, _, commands) -> return $ length commands

-- Get a block of commands
getCommandBlock :: Int -> Int -> Processor [Command]
getCommandBlock start end = do
  st <- getState
  case st of
    (_, _, _, _, _, commands) -> return $ reverse $ take (end - start + 1) $ drop (length commands - end) commands

-- Replace a block of commands
replaceCommandBlock :: [Command] -> Int -> Int -> Compiler
replaceCommandBlock replacement start end = 
  let updater (a, b, c, d, e, commands) = (a, b, c, d, e, concat [take (length commands - end) commands, reverse replacement, drop (length commands - start + 1) commands])
      in updateState updater

-- Retrieve the next expression
expression :: Processor Expression
expression =
  let showExpr expr = show expr
      testExpr expr = Just expr
      nextPos pos expr exprs = pos
      in tokenPrim showExpr nextPos testExpr
-- }

-- Compile the syntax tree and report any errors
compileSimple :: [Expression] -> Sym.SymbolTable (Type, [Var]) -> Sym.SymbolTable [Var] -> [Command]
compileSimple expressions funs structs = 
  -- Create the starting state and the compilers
  let st = (funs, structs, Sym.create, Sym.create, 32, [])

      -- Compiler to allocate space for the static section and set $static
      staticSectionCompiler = do
        -- Emit starting instructions
        compilerStart

        -- Compute the size of the strings in the program and
        -- allocate space in the static section for the string data.
        (exprs, stringBytes) <- computeStringSize 0

        -- Allocate space for global variables in the static section
        computeStaticSectionSize exprs stringBytes 0

        -- Return the state of the compiler
        getState

      -- Main compiler, for toplevel statements
      compiler = do
        -- Initialize global variables, define functions, etc
        many toplevel
        getState

      -- Run the compilers, ignoring errors.
      -- We should never get errors, as the verifier should take care of error checking.
      in case runParser staticSectionCompiler st "Static Computation" expressions of
        Right state ->
          case (runParser compiler state "Compilation" expressions) of

            -- Retrieve the compiled commands
            Right newState ->
              case newState of
                -- We reverse the commands, because we append to the front.
                -- Since we're using lists, appending to the back is inefficient.
                -- If this reversing is a problem, we can switch to using Data.Sequence.
                (_, _, _, _, _, commands) ->
                  let final = optimize $ reverse commands
                      regs = [0..9] ++ [24..29] in
                    assignRegisters regs final False
---------------------------------------- }

-- Convenience functions for emitting commands
---------------------------------------- {

-- Register numbers.
regStatic = 15
regStack = 11
regFrame = 14
regOut = 12
regInstruction = 10
regReturnValue = regOut

-- Align a value to some number of bytes, rounding up.
-- Ex: align 4 3 = 4
--     align 3 8 = 9
align :: Int -> Int -> Int
align bytes val = bytes * (ceiling ((toRational val) / (toRational bytes)))

-- Create a constant value argument to a command.
constant :: Int -> Argument
constant x = ValueArg (Constant x)

-- Create a register value argument to a command.
register :: Int -> Argument
register x = ValueArg (Register x)

-- Create an argument register value argument to a command.
-- Note that there are only 8 argument registers.
argumentRegister x
  | (x >= 0 && x <= 7) = ValueArg (Register (x + 16))

-- Create a static memory argument to a command.
staticMem :: Int -> Argument
staticMem x = ValueArg (Memory regStatic x)

-- Create a memory location argument to a command.
mem :: Int -> Int -> Argument
mem reg off = ValueArg $ Memory reg off

-- Convert an infix operator into an instruction type. Many of the
-- infix operators map directly to instructions, so use this to create the mapping.
arithmeticInstruction :: InfixOp -> Instruction
arithmeticInstruction Simple.Plus      = Asm.Add
arithmeticInstruction Simple.Minus     = Asm.Sub
arithmeticInstruction Simple.Times     = Asm.Mul
arithmeticInstruction Simple.Divide    = Asm.Div
arithmeticInstruction Simple.And       = Asm.And
arithmeticInstruction Simple.Or        = Asm.Or 
arithmeticInstruction Simple.BitAnd    = Asm.And
arithmeticInstruction Simple.BitOr     = Asm.Or
arithmeticInstruction Simple.Equals    = Asm.Equal
arithmeticInstruction Simple.NotEquals = Asm.NotEqual
arithmeticInstruction Simple.Greater   = Asm.Greater
arithmeticInstruction Simple.Less      = Asm.Less
arithmeticInstruction Simple.GreaterEq = Asm.GreaterEq
arithmeticInstruction Simple.LessEq    = Asm.LessEq

-- Compute the size of a type. Currently, we only support
-- types that have a size of one word. (Even structs are actually
-- pointers to structs, also with size of one word!)
computeSize :: Type -> Processor Int
computeSize _ = return 4

-- Compute the size of a struct.
computeStructSize (StructType name) = do
  -- Get the struct fields
  fields <- getStruct name

  -- Sum type sizes over all the fields.
  let folder left (Var name typ) = do 
                                     leftVal <- left
                                     rightVal <- computeSize typ
                                     return $ leftVal + rightVal
  foldl folder (return 0) fields
---------------------------------------- }

-- Static section initialization
---------------------------------------- {

-- Emit starting commands, that form the beginning of any program.
compilerStart :: Compiler
compilerStart = do
  -- Label the beginning of the program.
  command $ Label "Compiler_ProgramStart"

  -- Set $static to the current position, since we're mixing instructions and static data.
  command $ Command Move [register regStatic, register regInstruction]
  command $ Command Move [register regFrame, register regInstruction]
  command $ Command Move [register regStack, register regInstruction]

  -- Skip the static data section. (Jump to the next instructions)
  command $ Command Jump [LabelArg "Compiler_EndStatic"]

-- Compute the size of the strings. For convenience, since
-- this reads all of the expressions (exhausting the token stream)
-- just return a list of all the expressions for later use.
computeStringSize :: Int -> Processor ([Expression], Int)
computeStringSize prev =
  -- Find strings in the next expression.
  try (do
         expr <- expression
         new <- findStrings (value expr) prev

         -- Recurse to find strings in all remaining expressions.
         (es, ret) <- computeStringSize $ new
         return (expr : es, ret))

  -- If there are no expressions, we're done looking for strings.
  -- Emit a command to align the end of the strings to a word,
  -- and return the remaining expressions and the length.
    <|> (do
           let aligned = align 4 prev
           command $ Command Repeat [constant 0, constant (aligned - prev)]
           return ([], aligned))

-- Computes how much space the static data section takes up. Also, store the location
-- of each global symbol in the symbol table (as well as its type).
computeStaticSectionSize :: [Expression] -> Int -> Int -> Processor Int

-- If we still have expressions to parse:
computeStaticSectionSize (expr : exprs) strOffset prev =
  case value expr of
      -- For variable declarations, allocate space for the variable.
      DeclareVal (Var name typ) val -> do
        size <- computeSize typ
        -- Store location in the symbol table.
        symbol name (typ, staticMem $ strOffset + prev)

        -- Recurse on the next expressions, incrementing the static section offset.
        computeStaticSectionSize exprs strOffset $ prev + size
  
      -- For non-variable declarations, ignore them and just go onto the next expressions.
      _ -> computeStaticSectionSize exprs strOffset prev

-- When we're done parsing, just emit a repeat command to 
-- allocate that much space in the static section.
computeStaticSectionSize [] strOffset prev = do
  command $ Command Repeat [constant 0, constant prev]

  -- Label the end of the static section, so the program can jump here and skip the static section.
  command $ Label "Compiler_EndStatic"
  return prev

-- Find all strings in an expression, allocate space for 
-- them, and store a reference to their location in symbol table.
findStrings :: Simple.Value -> Int -> Processor Int

-- For a string value:
findStrings (StrVal str) prev = do
  -- Calculate length of the string, including the NULL character at the end
  let strSize = 1 + (length str)

      -- Store the string in the symbol table with an esoteric name, so there are no conflicts.
      strSymb = "!Compiler_Internal! " ++ str

  symbol strSymb (ArrayType CharType, staticMem prev)
  command $ Command Ascii [ValueArg $ Str str]
  return $ prev + strSize

-- For a non-string value:
findStrings val prev = do
  -- Check all subexpressions
  let exprs = getSubExpressions val
      -- Sequence all actions by executing the
      -- left one and passing its result to the right one.
      -- In case the right one is a null expression, just 
      -- return the result so far.
      folder x y = do 
        z <- x
        case y of
          NullExpr -> return z
          _ -> findStrings (value y) z

  foldl folder (return prev) exprs

-- Get all subexpressions of a given value. This 
-- has to be defined for each value type, and just
-- returns a list of all expressions the value uses.
getSubExpressions :: Simple.Value -> [Expression]
getSubExpressions (BlockVal exprs) = exprs
getSubExpressions (IfVal a b c) =  [a, b, c]
getSubExpressions (WhileVal a b) = [a, b]
getSubExpressions (ForVal a b c d) = [a, b, c, d]
getSubExpressions (DeclareVal _ a) = [a]
getSubExpressions (AssignVal _ a) = [a] 
getSubExpressions (InfixVal _ a b) = [a, b]
getSubExpressions (PrefixVal _ a) = [a]
getSubExpressions (FuncVal _ _ _ a) = [a]
getSubExpressions (FuncallVal _ exprs) = exprs
getSubExpressions (CastVal _ a) = [a]

-- By default, assume there are no subexpressions.
getSubExpressions _ = []

computeOffset :: [Var] -> String -> Processor Int
computeOffset ((Var name typ):vars) varname
  | name == varname = return 0
  | True = do
             size <- computeSize typ
             nextOffset <- computeOffset vars varname
             return (size + nextOffset)
  
computeType :: Expression -> Processor Type
computeType (Expr _ (VarVal name)) = do
  (symType, symLoc) <- getSymbol name
  return symType

---------------------------------------- }

-- Compiling commands
---------------------------------------- {

-- Compile a toplevel expression.
toplevel :: Compiler
toplevel = do
  expr <- expression
  case value expr of
    -- We must special-case a declaration because we have
    -- already done the "declaration" step when we allocate
    -- memory for this variable in the static data section.
    -- We do not care about the result, so put it in a nonsensical register.
    DeclareVal (Var name typ) val -> compileAssign (-1) name val

    -- For most expressions, just compile them as we would if they were non-toplevel.
    _ -> compile expr >> return ()

-- Compile an expression. Return the register into which the result of the expression was stored.
compile :: Expression -> Processor Int

-- For a null expression:
compile NullExpr = do
  -- Get a new unused register.
  out <- nextRegister

  -- Store a zero in the destination. (NULL = 0).
  command $ Command Move [register out, constant 0]
  return out

-- For a non-null expression:
compile expr = do
  -- Get a new unused reigster.
  out <- nextRegister

  -- We have separate compilation functions for most expression types.
  case value expr of
    -- For number and character literals, just store the value in the register. 
    NumVal int -> command $ Command Move [register out, constant int]
    CharVal c -> command $ Command Move [register out, constant (ord c)]

    -- For strings, store the location of the string in the register.
    -- Lookup the location in the symbol table.
    StrVal str -> do
      (_, ValueArg (Memory reg offset)) <- getSymbol $ "!Compiler_Internal! " ++ str
      command $ Command Add [register reg, constant offset, register out]

    -- For typecasts, just compile the expression that's being cast. A typecast
    -- has no meaning for the compiler, and it's only there for the verifier.
    CastVal typ val -> do
      res <- compile val
      command $ Command Move [register out, register res]

    -- A sizeof expression is actually similar to a constant expression. However,
    -- we need to compute the size of the type first. Once we have the size,
    -- just store the constant result into the output register.
    SizeOfVal typ -> do
      size <- case typ of 
                StructType name -> computeStructSize typ
                _ -> computeSize typ
      command $ Command Move [register out, constant size]

    -- Forward each expression type to it's own compilation function.
    -- Pass the destination register to the compilation function; the compilation
    -- functions are responsible for putting their output into that register.
    BlockVal exprs -> compileBlock out exprs
    IfVal cond conseq alt -> compileIf out cond conseq alt
    ForVal init cond incr body -> compileFor out init cond incr body
    WhileVal cond body -> compileWhile out cond body
    AssignVal name val -> compileAssign out name val
    VarVal name -> compileVar out name
    DeclareVal (Var name typ) val -> compileDeclare out name val typ
    AssemblyVal typ code -> compileAssembly code
    FuncVal name typ args block -> compileFunc out name args block
    FuncallVal name args -> compileFuncall out name args
    PrefixVal op expr -> compilePrefix out op expr

    -- Some infix commands are actually special operators. Forward those to separate compilation functions.
    InfixVal ArrayRef left right -> compileArrayRef out left right
    InfixVal ArrayWrite (Expr _ (InfixVal ArrayRef arr ind)) obj -> compileArrayWrite out arr ind obj
    InfixVal DataRef left (Expr _ (VarVal name)) -> compileStructRef out left name
    InfixVal DataRef left (Expr _ (AssignVal name expr)) -> compileStructWrite out left name expr

    -- Infix commands that aren't special operators also have their own compilation function.
    InfixVal op left right -> compileInfix op out left right

    -- Type declarations are for the verifier.
    StructVal _ _ ->  return ()

  -- Return the register to which we stored the result.
  return out

-- Compile a block.
compileBlock :: Int -> [Expression] -> Compiler
compileBlock out exprs = do
  -- Compile all the expressions in the block, the last one is the result.
  let folder left right = left >> compile right
  startBlock
  output <- foldl folder (return 0) exprs
  endBlock
  command $ Command Move [register out, register output]

-- Compile an if statement.
compileIf :: Int -> Expression -> Expression -> Expression -> Compiler
compileIf out cond conseq alt = do
  condReg <- compile cond
  let elseLabel = "Compiler_Else_" ++ show out 
      endLabel = "Compiler_EndIf_" ++ show out
  command $ Command Move [register regOut, register condReg]
  command $ Command JumpUnless [LabelArg elseLabel]
  conseqReg <- compile conseq
  command $ Command Move [register out, register conseqReg]
  command $ Command Jump [LabelArg endLabel]
  command $ Label elseLabel
  altReg <- compile alt
  command $ Command Move [register out, register altReg]
  command $ Label endLabel

-- Compile a for loop.
compileFor :: Int -> Expression -> Expression -> Expression -> Expression -> Compiler
compileFor out init cond incr body = do
  let startLabel = "Compiler_ForStart_" ++ show out
      endLabel = "Compiler_ForEnd_" ++ show out

  -- Perform the for loop in its own block so values declared in the initialization can be used in the body.
  startBlock
  compile init
  command $ Label startLabel
  condReg <- compile cond
  command $ Command Move [register regOut, register condReg]
  command $ Command JumpUnless [LabelArg endLabel]
  bodyReg <- compile body
  compile incr
  endBlock

  command $ Command Jump [LabelArg startLabel]
  command $ Label endLabel
  command $ Command Move [register out, register bodyReg]

-- Compile a while loop.
compileWhile :: Int -> Expression -> Expression -> Compiler
compileWhile out cond body = do
  let startLabel = "Compiler_WhileStart_" ++ show out
      endLabel = "Compiler_WhileEnd_" ++ show out
  command $ Label startLabel
  condReg <- compile cond
  command $ Command Move [register regOut, register condReg]
  command $ Command JumpUnless [LabelArg endLabel]
  bodyReg <- compile body
  command $ Command Jump [LabelArg startLabel]
  command $ Label endLabel
  command $ Command Move [register out, register bodyReg]

-- Compile an assignment (or a toplevel declaration).
compileAssign :: Int -> String -> Expression -> Compiler
compileAssign out name val = do
  -- Get the location to which we're assigning
  (_, loc) <- getSymbol name

  -- Compile the value we're assigning
  valReg <- compile val

  -- Move the value we're assigning to the destination register and to the location
  command $ Command Move [loc, register valReg]
  command $ Command Move [register out, register valReg]

-- Compile a variable reference. This is just a lookup in the symbol table to
-- find the location of the variable in registers or memory, and move the result to the destination.
compileVar :: Int -> String -> Compiler
compileVar out name = do
  (_, loc) <- getSymbol name
  command $ Command Move [register out, loc]

-- Compile a variable declaration (non-toplevel).
compileDeclare :: Int -> String -> Expression -> Type -> Compiler
compileDeclare out name val typ = do
  -- Compile the value, store the destination register in the symbol table.
  valReg <- compile val
  symbol name (typ, (register out))
  command $ Command Move [register out, register valReg]

-- Compile an assembly statement. This just parses the commands in the
-- assembly string and includes them in the output.
compileAssembly :: String -> Compiler
compileAssembly code =
  case parseAssembly code of
    Right cmds -> 
      foldl (>>) (return ()) $ map command cmds

-- Compile a function declaration.
compileFunc :: Int -> String -> [Var] -> Expression -> Compiler
compileFunc out name args block = do
  -- Surround the function with start and end labels.
  let startLabel = "Compiler_FuncStart_" ++ name
      endLabel = "Compiler_FuncEnd_" ++ name

  -- Store location of this function in the desination register
  command $ Command Add [register regInstruction, constant 1]
  command $ Command Move [register out, register regOut]
  
  -- Skip the function contents so we don't execute them on definition
  command $ Command Jump [LabelArg endLabel]

  -- Delimit the function with labels
  command $ Label startLabel 

  startBlock
  startIndex <- getCurrentCommandIndex

  -- Define the arguments
  let orderedArgs = zip args [0, 1..]
      definer left (Var name typ, ind) = do
                                           left
                                           argReg <- nextRegister
                                           command $ Command Move [register argReg, argumentRegister ind]
                                           symbol name (typ, register argReg)
  foldl definer (return ()) orderedArgs

  -- Compile function statements
  outreg <- compile block 

  endBlock

  -- Store return value in out register
  command $ Command Move [register regReturnValue, register outreg]

  -- Exit the function
  command $ Command Return []

  -- Label function end so we can jump there in order to skip executing the function
  command $ Label endLabel 

  endIndex <- getCurrentCommandIndex

  -- Optimize the function separately
  commands <- getCommandBlock (startIndex + 1) endIndex
  let final = optimize commands
      regs = [0..9] ++ [24..29]
      optimized = assignRegisters regs final True
  
  replaceCommandBlock optimized (startIndex + 1) endIndex

-- Compile a function call.
compileFuncall :: Int -> String -> [Expression] -> Compiler
compileFuncall out name args = do
  -- Evaluate function arguments, store them in registers
  let argumentEvaluator left right = do {
    curlist <- left; 
    argout <- compile right;
    return (argout : curlist)
  }
  argregs <- foldl argumentEvaluator (return []) args

  -- Move registers into argument registers
  let mover argreg argnum = command $ Command Move [argumentRegister argnum, register argreg]
  foldl (>>) (return ()) $ zipWith mover (reverse argregs) [0,1..]

  -- Jump to the function label, and move the function return value into the output register.
  command $ Command Call [LabelArg $ "Compiler_FuncStart_" ++ name]
  command $ Command Move [register out, register regReturnValue]

-- Compile a prefix expression.
compilePrefix :: Int -> PrefixOp -> Expression -> Compiler
compilePrefix out op expr =
  case op of
    -- For negations and bitwise negations, compile the argument expression and then apply the operation.
    Negative -> do
      outreg <- compile expr
      command $ Command Not [register outreg, register out]
    BitNegate -> do
      outreg <- compile expr
      command $ Command Negate [register outreg, register out]

    -- For an address operation, we are unable to do the compilation at this step because
    -- this requires that the target variable is stored in memory. However, this is only known
    -- (or, in this case, set) at register allocation, so instead of doing this compilation
    -- now we emit an internal command that the register allocator will later replace
    -- with the appropriate assembly commands.
    Address -> 
      case value expr of
        VarVal name -> do
          (_, arg) <- getSymbol name
          command $ InternalCommand "ADDRESS_OF" [arg, register out]

-- Compile an array reference. (Accessing a value in an array).
compileArrayRef :: Int -> Expression -> Expression -> Compiler
compileArrayRef out array index = do
  -- Compile the array and index expressions.
  indexReg <- compile index
  arrayReg <- compile array

  -- Compute location of memory we're accessing.
  command $ Command Mul [register indexReg, constant 4]
  command $ Command Add [register arrayReg, register regOut]

  -- Read from the appropriate memory location.
  command $ Command Move [register out, mem regOut 0]

-- Compile a write to an array.
compileArrayWrite :: Int -> Expression -> Expression -> Expression -> Compiler
compileArrayWrite out array index writedata = do
  -- Compile the array, index, and data expressions.
  indexReg <- compile index
  arrayReg <- compile array
  dataReg <- compile writedata

  -- Compute memory location.
  command $ Command Mul [register indexReg, constant 4]
  command $ Command Add [register arrayReg, register regOut]

  -- Move data into the memory location. Also, move data into the output register.
  command $ Command Move [mem regOut 0, register dataReg]
  command $ Command Move [register out, register dataReg]

-- Compile a read from a struct field. This is similar to an array read, but
-- we compute the offset statically from the struct information instead of
-- dynamically from the array index.
compileStructRef :: Int -> Expression -> String -> Compiler
compileStructRef out expr name = do
  -- Find struct info and field offset
  exprType <- computeType expr 
  let (StructType structName) = exprType
  structVars <- getStruct structName
  offset <- computeOffset structVars name

  -- Compile the struct expression
  exprReg <- compile expr

  -- Move the data from memory to the output register
  command $ Command Move [register out, mem exprReg offset]

-- Compile a write to a field of a struct. This is similar to an array write,
-- but we compute the offset statically from the struct information instead of
-- dynamically from the array index.
compileStructWrite :: Int -> Expression -> String -> Expression -> Compiler
compileStructWrite out expr name writedata = do
  -- Compute the struct type of the expression, and retrieve that struct field info.
  (StructType structName) <- computeType expr 
  structVars <- getStruct structName

  -- Compute the data offset of the field we're writing to
  offset <- computeOffset structVars name

  -- Compile the expression and the data being written
  exprReg <- compile expr
  dataReg <- compile writedata

  -- Move the data into the struct. Also, move the data into the output register.
  command $ Command Move [mem exprReg offset, register dataReg]
  command $ Command Move [register out, register dataReg]

-- Compile an infix command.
compileInfix :: InfixOp -> Int -> Expression -> Expression -> Compiler
compileInfix op out left right = do
  -- Compile both arguments to the infix operator.
  leftReg <- compile left
  rightReg <- compile right

  -- Perform the operation on the two input registers, and store the result in the output register.
  command $ Command (arithmeticInstruction op) [register leftReg, register rightReg, register out]
---------------------------------------- }
