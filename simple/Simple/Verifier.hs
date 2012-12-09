module Simple.Verifier (verifySimple)
  where

import qualified Simple.SymbolTable as Sym
import Simple.Parser
import Debug.Trace
import Text.Parsec.Prim
import Control.Monad.Identity
import Data.List
import Assembly.Parser

-- Verifier state and parser declaration
-----------------------------------
-- Verifier state consists of:
--   1. Remaining unverified expresssions
--   2. Function table
--   3. Data structure table
--   4. Symbol table
--   5. List of error messages
type CheckState = (Sym.SymbolTable (Type, [Var]),
                   Sym.SymbolTable [Var],
                   Sym.SymbolTable Type,
                   [String])

type Verifier a = ParsecT [Expression] CheckState Identity a
type Typer = Verifier Type
-----------------------------------

-- Functions for manipulating the state of the parser
-----------------------------------

-- Record a failure
failure :: Expression -> String -> Typer
failure expr err = 
  let message = (position expr) ++ err ++ "\n"
      updater (b, c, d, errs) = (b, c, d, message : errs)
      in updateState updater >> return NullType

-- Convenience function to construct an error message about a type mismatch
typeError :: Type -> Type -> String
typeError expected actual = "Types do not match.\nExpected: " ++ (show expected) ++ 
     "\nFound: " ++ (show actual)
  
-- Enter a new block in the symbol table
startBlock :: Verifier ()
startBlock = 
  let updater (b, c, sym, d) = (b, c, Sym.startBlock sym, d)
      in updateState updater

-- Exit the top block in the symbol table
endBlock :: Verifier ()
endBlock = 
  let updater (b, c, sym, d) = (b, c, Sym.endBlock sym, d)
      in updateState updater

-- Add a symbol to the symbol table
symbol :: String -> Type -> Verifier ()
symbol name typ =
  let updater (b, c, sym, d) = (b, c, Sym.add name typ sym, d)
      in updateState updater

-- Add a struct type to the data structure table
struct :: String -> [Var] -> Verifier ()
struct name val = 
  let updater (b, structs, c, d) = (b, Sym.add name val structs, c, d)
      in updateState updater

-- Add a function to the function table
function :: String -> (Type, [Var]) -> Verifier ()
function name val = 
  let updater (funcs, b, c, d) = (Sym.add name val funcs, b, c, d)
      in updateState updater

-- Retrieve the symbol table
getSymbolTable :: Verifier (Sym.SymbolTable Type)
getSymbolTable = do
  st <- getState
  case st of
    (_, _, sym, _) -> return sym

-- Retrieve the struct table
getStructTable :: Verifier (Sym.SymbolTable [Var])
getStructTable = do 
  st <- getState
  case st of
    (_, structs, _, _) -> return structs

-- Retrieve the function table
getFunctionTable :: Verifier (Sym.SymbolTable (Type, [Var]))
getFunctionTable = do
  st <- getState
  case st of
    (funcs, _, _, _) -> return funcs

-- Retrieve the next expression
expression :: Verifier Expression
expression =
  let showExpr expr = show expr
      testExpr expr = Just expr
      nextPos pos expr exprs = pos
      in tokenPrim showExpr nextPos testExpr

-- Verify the syntax tree and report any errors
verifySimple :: [Expression] -> ([String], Sym.SymbolTable [Var], Sym.SymbolTable (Type, [Var]))
verifySimple expressions = 
  -- Create the starting state and the parser
  let st = (Sym.create, Sym.create, Sym.create, [])
      result = runParser (many toplevel >> getState) st "Verification" expressions
      in case result of 
        -- We should never get parsing errors, because we don't do
        -- any real parsing. We are essentially using Parsec for the purpose
        -- of passing around state conveniently, and iterating over the list
        -- of toplevel expressions.
        Left error -> ([show error], Sym.create, Sym.create)

        -- Retrieve the errors we recorded from the state
        Right newState ->
          case newState of
            (funTable, structTable, _, errs) -> (errs, structTable, funTable)
----------------------------------------

-- Verification steps
----------------------------------------

-- Verify a top-level expression. There are expression types which are
-- meaningless as top-level expressions, and thus are forbidden; other
-- than that, this verifier just forwards to the expression verifier.
--
-- This is the only verifier that reads from the token stream.
toplevel :: Typer
toplevel = do
  next <- expression
  case next of
    -- Special case for array accesses
    Expr _ (InfixVal ArrayRef _ _) ->
      check next

    -- Disallow some expression types
    Expr _ (NumVal _) ->
      failure next "Forbidden numeric literal at top level."
    Expr _ (StrVal _) ->
      failure next "Forbidden string literal at top level."
    Expr _ (CharVal _) ->
      failure next "Forbidden char literal at top level."
    Expr _ (InfixVal _ _ _) ->
      failure next "Forbidden infix at top level."
    Expr _ (PrefixVal _ _) ->
      failure next "Forbidden arithmetic at top level."
    Expr _ (VarVal _) ->
      failure next "Forbidden variable at top level."
    Expr _ (SizeOfVal _) ->
      failure next "Forbidden sizeof at top level."
    Expr _ (CastVal _ _) ->
      failure next "Forbidden cast at top level."
    _ -> check next 

-- Check an expression for semantic correctness
check :: Expression -> Typer
check NullExpr = return NullType
check expr =
  case value expr of
    -- Return the type of primitive expressions
    NumVal _  -> return IntType
    StrVal _  -> return $ ArrayType CharType
    CharVal _ -> return CharType

    SizeOfVal typ -> checkSizeOf expr typ
    CastVal typ val -> checkCast expr typ val

    -- Forward checking compound expressions to specific verifiers
    BlockVal exprs                -> checkBlock expr exprs
    IfVal cond conseq alt         -> checkIf expr cond conseq alt
    WhileVal cond body            -> checkWhile expr cond body
    ForVal init cond incr body    -> checkFor expr init cond incr body
    DeclareVal (Var name typ) val -> checkDeclare expr val name typ
    AssignVal varname val         -> checkAssign expr varname val
    InfixVal op left right        -> checkInfix expr op left right
    PrefixVal op val              -> checkPrefix expr op val
    FuncVal name typ args body    -> checkFunc expr name typ args body
    FuncallVal name exprs         -> checkFuncall expr name exprs
    AssemblyVal typ code          -> checkAssembly expr typ code
    StructVal name vars           -> checkStruct expr name vars
    VarVal name                   -> checkVar expr name

-- Check a cast. Make sure the type exists.
-- Returns the type to which the value is being cast, or failure.
checkCast :: Expression -> Type -> Expression -> Typer
checkCast expr typ val = do
  check val
  case typ of
    StructType name -> do
      table <- getStructTable
      if Sym.exists name table
      then return typ
      else failure expr $ "Unknown struct type '" ++ name ++ "'"
    NullType -> failure expr "Cannot cast to null type."
    _ -> return typ

-- Check a sizeof expression. Make sure the type exists.
-- Returns IntType, or failure.
checkSizeOf :: Expression -> Type -> Typer
checkSizeOf expr typ = do
  case typ of
    StructType name -> do
      table <- getStructTable
      if Sym.exists name table
      then return IntType
      else failure expr $ "Unknown struct type '" ++ name ++ "'"
    NullType -> failure expr "Cannot take size of null type."
    _ -> return IntType

-- Check an assembly block. This pipes any errors in the assembly parser
-- to errors in the compile.
--
-- The resulting type is the declared type of the assembly block.
checkAssembly :: Expression -> Type -> String -> Typer
checkAssembly expr typ code = do
  case parseAssembly code of
    Left error -> failure expr $ "Assembly error: " ++ show error
    Right cmds -> return typ

-- Check an assembly block. This pipes any errors in the assembly parser
-- to errors in the compile.
--
-- The resulting type is the declared type of the assembly block.

-- Check an assignment. Verify that the variable to which we're assigning
-- has been declared; also verify that the type of the variable matches.
--
-- The resulting type is the type of the variable being assigned to.
checkAssign :: Expression -> String -> Expression -> Typer
checkAssign expr varname varvalue = do
  table <- getSymbolTable
  if not $ Sym.exists varname table
  then failure expr $ "Cannot assign to undeclared variable '" ++ varname ++ "'"
  else do
    vartype <- check varvalue
    let expected = Sym.get varname table
    if vartype /= expected
    then failure expr $ typeError expected vartype
    else return expected

-- Check a while loop. Verify that the condition is an integer.
--
-- The resulting type is the same as the type of the last expression in the block.
checkWhile ::  Expression -> Expression -> Expression -> Typer
checkWhile expr condition body = do
  condType <- check condition
  bodyType <- check body
  if condType /= IntType
  then failure expr "Expected integer for while loop condition."
  else return bodyType

-- Check a for loop. Verify that the condition is an integer.
--
-- The resulting type is the same as the type of the last expression in the block.
checkFor ::  Expression -> Expression -> Expression -> Expression -> Expression -> Typer
checkFor expr init condition increment body = do
  initType <- check init
  condType <- check condition
  incType <- check increment
  bodyType <- check body
  if condType /= IntType
  then failure expr "Expected integer for while loop condition."
  else return bodyType

-- Check a struct declaration. This checks that a struct with this name
-- hasn't been declared before, and if it hasn't, declares it in the
-- structure table in the monad state.
checkStruct :: Expression -> String -> [Var] -> Typer
checkStruct expr name fields = do
  table <- getStructTable
  if Sym.exists name table
  then failure expr ("Cannot re-declare struct type " ++ name)
  else 
    if structHas name fields table
    then failure expr $ "Cannot declare recursive struct '" ++ name ++ "'"
    else do 
           struct name fields
           return NullType

structHas :: String -> [Var] -> Sym.SymbolTable [Var] -> Bool
structHas _ [] _ = False
structHas name (var : vars) table =
  case var of
    Var _ IntType -> structHas name vars table
    Var _ CharType -> structHas name vars table
    Var _ (ArrayType _) -> structHas name vars table
    Var _ NullType -> structHas name vars table
    Var _ (StructType nested) ->
      if nested == name
      then True
      else (structHas name vars table) || 
        if not (Sym.exists nested table)
        then False
        else structHas name (Sym.get nested table) table

-- Check the type of an infix expression. This verifies the sub-expressions
-- and then makes sure that the elements are of the correct type.
--
-- The resulting type is an integer, unless this is a data reference,
-- in which case it is the type of the field being referenced.
checkInfix :: Expression -> InfixOp -> Expression -> Expression -> Typer
checkInfix expr op left right = do
  leftType <- check left

  case op of
    -- Access a field of a data structure
    DataRef -> dataRefExpr expr left right

    -- Access an array element
    ArrayRef -> arrayRefExpr expr left right

    -- All operators other than struct reference require integer arguments
    _ ->
      -- Split typechecking into two steps, one for right and one for left,
      -- so that we can accurately report the actual type vs. expected type
      if leftType /= IntType
      then failure expr (typeError IntType leftType)
      else do
        rightType <- check right
        if rightType /= IntType
        then failure expr (typeError IntType rightType)

        -- The result of all operators is an integer
        else return IntType

-- Check an array access. This verifies that the left expression
-- is an array, and that the right expression is an integer.
--
-- The resulting type is the type of the array being accessed.
arrayRefExpr :: Expression -> Expression -> Expression -> Typer
arrayRefExpr expr arrayExpr accessor = do
  -- Verify that the left hand side is a struct
  arrayType <- check arrayExpr
  case arrayType of
    ArrayType internalType -> 
      -- Check that the right hand side is an integer
      case accessor of
        -- Writing to an array
        Expr _ (InfixVal ArrayWrite index val) -> do
          assignType <- check val
          indexType <- check index
          if indexType /= IntType
          then failure expr "Expected integer type as array index."
          else if assignType /= internalType
               then failure expr "Array type does not match right hand value type."
               else return internalType
        index -> do
          indexType <- check index
          if indexType /= IntType
          then failure expr "Expected integer type as array index."
          else return internalType 


-- Check the a field access of a data structure. This verifies the left expression
-- in order to find the type of data structure being accessed; it also checks that 
-- the right expression is just a string (parsed as a variable reference), and that
-- it refers to a field that exists within the data structure.
--
-- The resulting type is the type of the field being accessed.
dataRefExpr :: Expression -> Expression -> Expression -> Typer
dataRefExpr expr structExpr accessor = do
  -- Verify that the left hand side is a struct
  structType <- check structExpr
  case structType of
    StructType structName -> 
      -- Check that the right hand side is just an accessor expression
      case accessor of
        -- Reading from a struct
        Expr _ (VarVal name) -> do
          -- We do not check that this struct exists because if 'check' returns 
          -- a non-existing struct type, it is a bug in the compiler code, and
          -- not an error in the code it is parsing / verifying.
          table <- getStructTable
          let fields = Sym.get structName table
              field = find (\(Var n t) -> n == name) fields
          case field of
            Just (Var fieldName fieldType) -> return fieldType
            Nothing -> failure expr $ "Cannot find field '" ++ name ++ "' in struct '" ++ structName ++ "'"

        -- Writing to a struct
        Expr _ (AssignVal name val) -> do
          table <- getStructTable
          let fields = Sym.get structName table
              field = find (\(Var n t) -> n == name) fields
          case field of
            Just (Var fieldName fieldType) -> do
              valType <- check val
              if valType /= fieldType
              then failure expr $ typeError fieldType valType
              else return fieldType
            Nothing -> failure expr $ "Cannot find field '" ++ name ++ "' in struct '" ++ structName ++ "'"
        _ -> failure expr "Expected field name after data reference."
    _ -> failure expr "Expected left expression in data reference to be a struct type."

-- Verifies the argument to a prefix expression, and makes sure it is an integer.
--
-- The resulting type is an integer.
checkPrefix :: Expression -> PrefixOp -> Expression -> Typer
checkPrefix expr op val =
  case op of 
    Address ->
      case val of
        Expr _ (VarVal name) -> do
          table <- getSymbolTable
          if Sym.exists name table
          then return $ ArrayType $ Sym.get name table
          else failure expr $ "Cannot find variable '" ++ name ++ "'"
        _ -> failure expr "Can only take address of variables, not expressions."
    _ -> do
      valType <- check val

      if valType /= IntType
      then failure expr (typeError IntType valType)
      else return IntType

-- Check a conditional if statement. The condition expression must be an integer,
-- and the types of the consequence and alternative must be the same.
--
-- The resulting type is the type of the consequence/alternative block.
checkIf :: Expression -> Expression -> Expression -> Expression -> Typer
checkIf expr cond conseq alt = do
  condType <- check cond
  conseqType <- check conseq
  altType <- check alt

  if condType /= IntType
  then failure expr "Condition must be an integer value."
  else
    if conseqType /= altType
    then failure expr "If branches much have the same type."
    else 
      -- Return a type which is guaranteed not to be null, assuming
      -- at least one of the branches has a non-null type.
      if nulltype conseqType
      then return altType
      else return conseqType

-- Check a block.
--
-- The resulting type is the type of the last expression in the block,
-- or null if the block is empty.
checkBlock :: Expression -> [Expression] -> Typer
checkBlock expr [] = return NullType
checkBlock expr (ex : exs) =
  let foldCheck left right = left >> check right in do
    -- Start a new block in the symbol table. This allows local variables
    -- to be defined and then undefined when the block is ended.
    startBlock
    blockType <- foldl foldCheck (check ex) exs

    -- End the block we started
    endBlock
    return blockType

-- Check a function call. This verifies that the function we're calling exists,
-- that is has the same number of arguments as we're passing in, that the arguments
-- are the same type as the expressions we're passing in.
--
-- The resulting type is the return type of the function being called.
checkFuncall :: Expression -> String -> [Expression] -> Typer
checkFuncall expr name args = do
  -- Get the function table and check that the function exists
  table <- getFunctionTable
  if not (Sym.exists name table)
  then failure expr $ "Using undeclared function " ++ name
  else 
    -- Get the function signature
    let (retType, argSpecs) = Sym.get name table in
      -- Check the number of arguments
      if length argSpecs /= length args
      then failure expr ("Wrong number of arguments to " ++ name ++ ". Expected " ++ 
        (show (length argSpecs)) ++ ", got " ++ (show (length args)) ++ ".")
      else do
        -- Check argument types, and return the return type
        checkFuncallArgs expr argSpecs args
        return retType

-- Check a list of function arguments against the argument specifications.
-- This does not return any useful types, but will give errors if argument
-- specifications are not met.
checkFuncallArgs :: Expression -> [Var] -> [Expression] -> Typer
checkFuncallArgs expr [] [] = return NullType
checkFuncallArgs expr (spec : specs) (arg : args) = do
  argType <- check arg

  case spec of
    Var name typ ->
      if argType /= typ
      then do
        failure expr $ "Error in argument '" ++ name ++ "'. " ++ (typeError typ argType)
        checkFuncallArgs expr specs args
      else
        checkFuncallArgs expr specs args

-- Check a function definition, and record it in the function table. This first
-- verifies that no such function has been declared before, and that the value
-- of the function is actually the same as the declared return type.
checkFunc :: Expression -> String -> Type -> [Var] -> Expression -> Typer
checkFunc expr name typ args body = do
  --  Check that the function doesn't already exist
  table <- getFunctionTable
  if Sym.exists name table
  then failure expr ("Cannot re-declare function " ++ name)
  else do
    -- Add a block for the arguments
    startBlock

    -- Bind argument variables
    let assigner (Var name typ) = checkVarAssign expr name typ NullExpr 
    foldl (>>) (return NullType) (map assigner args)

    -- Get the body type
    retType <- check body

    -- Remove the argument block
    endBlock

    -- Make sure the return type is correct
    if retType /= typ
    then failure expr $ typeError typ retType
    else do
      function name (typ, args)
      return NullType

-- Check a variable reference. This checks that the variable is defined,
-- and returns the type of the defined variable (on highest block).
checkVar :: Expression -> String -> Typer
checkVar expr name = do
  -- Check that the symbol is defined
  table <- getSymbolTable
  if not (Sym.exists name table)
  then failure expr ("Undeclared variable: '" ++ name ++ "'")
  else return $ Sym.get name table

-- Checks a variable declaration. This verifies that the expression type is
-- the same as the declared type of the variable, and that the type of the
-- variable is known. It then adds the variable to the symbol table.
checkDeclare :: Expression -> Expression -> String -> Type  -> Typer
checkDeclare expr val name typ = do
  -- Check that this variable exists locally. We only want to check the
  -- current block, because we want to be able to shadow global variables
  -- with local variables or function arguments.
  table <- getSymbolTable
  if Sym.existsLocal name table 
  then failure expr ("Cannot re-declare variable " ++ name)
  else case typ of
    -- If we encounter a user-defined type, make sure it already exists
    StructType structName ->  do
      structs <- getStructTable
      if not $ Sym.exists structName structs
      then failure expr $ "Unknown type '" ++ structName ++ "'"
      else checkVarAssign expr name typ val
    _ -> checkVarAssign expr name typ val

-- Add a variable to the symbol table, and verify that the value
-- we're assigning to it is the correct type.
checkVarAssign expr name typ val = do
  symbol name typ
  exprType <- check val
  if exprType /= typ
  then failure expr (typeError typ exprType)
  else return typ
