module Simple.ControlFlowGraph (assignRegisters, optimize)
  where

import Assembly.Parser
import Debug.Trace
import Data.List

-- Control Flow Graph data types
-------------------------------------- {
-- A control flow graph (CFG) stores it's own node and the nodes it links to
data CFG = CFG CFGNode [CFG]
  deriving Show

-- A CFG node just stores the command at that node, and
-- the index of that command in the command sequence.
type CFGNode = (Command, Int)
-------------------------------------- }

-- Create a control flow graph. Includes tools for working with the CFGs.
-------------------------------------- {
-- Convert a set of commands into a set of CFGNodes
nodes :: [Command] -> [CFGNode]
nodes commands = zip commands [1,2..]

-- External interface, create a CFG from a list of commands
createControlFlowGraph :: [Command] -> CFG
createControlFlowGraph commands = 
  let x = nodes commands in
    cfg x x

-- Create a control flow graph, given a list of nodes.
-- The first argument is a list of all nodes in the command list,
-- used so that we can lookup labels in the command list.
-- The second argument is the starting point for the control flow graphs
-- and all commands that are sequentially after the starting point.
cfg :: [CFGNode] -> [CFGNode] -> CFG
cfg all commands =
  let node = head commands
      start = fst node
      cfgFromLabel label = cfg all (findLabel all label)
      cfgNext = cfg all (tail commands) in
    case start of
        -- For jump commands, look up the destination for the jump. If this is unconditional,
        -- the next CFG will go directly to the label; if it is a conditional jump, there will
        -- be two branching CFGs, one to the label and one to the next instruction.
        --
        -- We assume that a branching jump never occurs as the last instruction in a program.
        Command Jump [LabelArg label] -> CFG node [cfgFromLabel label]
        Command JumpIf [LabelArg label] -> CFG node [cfgFromLabel label, cfgNext]
        Command JumpUnless [LabelArg label] -> CFG node [cfgFromLabel label, cfgNext]

        -- A return statement is equivalent to the end of a program, since the 
        -- CFGs for functions are constructed separately for each function, and 
        -- a return only occurs when the function is exiting.
        Command Return [] -> CFG node []

        -- If we have neither a jump nor a return:
        _ -> 
          case tail commands of
            -- If there are no more commands, this is the end of
            -- a program and there are no places to go afterwards.
            [] -> CFG node []

            -- If there are more instructions, the CFG will just advance to the next one.
            xs -> CFG node $ [cfgNext]

-- Given a list of all the commands and a label name,
-- find the label in the command list and return
-- a list of all commands starting with that label.
findLabel :: [CFGNode] -> String -> [CFGNode]
findLabel all label =
  -- If this starts with the correct label, return the current list of nodes.
  case fst $ head all of
    Label name ->
      if name == label 
      then all

      -- If this doesn't start with the right label, just recurse until we find one.
      else findLabel (tail all) label
    other -> findLabel (tail all) label

-- Check whether a register is used downstream in a control flow graph.
-- The parameters are:
--  a set of indices for which cfg nodes have already been visited 
--      (to prevent infinite looping when exploring a cyclic graph)
--  the control flow graph for the commands to analyze
--  the register to check for
--  the register to which the real register will be assigned if this works.
--      (this is also used for an edge case, see code). If this is not applicable,
--      just pass the same register twice as the real and fake register.
usedDownstream :: [Int] -> CFG -> Int -> Int -> Bool
usedDownstream visited graph real fake = 
  case graph of 
    CFG (command, index) nexts ->
      -- If we've already visited this index, that means that 
      -- the register wasn't used at it (otherwise True would've already
      -- been returned), so we return False.
      if index `elem` visited
      then False
      else 
        -- If a command uses the register, return True.
        if command `uses` real
        then True
        else 
          -- If we've reached the end of a program, and still haven't seen
          -- this register used, then we have guaranteed that it is not used downstream,
          -- so we can safely return False.
          if null nexts
          then False
          else
            -- If a command defines the register that we're looking at, then we can't possibly
            -- care about its value after the definition, since it no longer holds the value
            -- that we care about. Thus, we return False, except in one special edge case:
            --   If a command defines the real register we want to use, but we're really testing
            --   to see if the real register is a valid replacement for a placeholder register (and real /= fake),
            --   then we also want to check to make sure that the placeholder register isn't used after this
            --   definition. If it is used, then we can't use this real register, because the value in the placeholder
            --   register would be overwritten by whatever code already exists. An example of this problem is the following code:
            --
            --     move $reg(37), 20
            --     move $0, 30
            --     move $reg(38), $reg(37)
            --
            --   In this code example, $0 is not a valid replacement for $reg(37) because $reg(37) is used after $0 is overwritten.
            if command `defines` real 
            then real /= fake && usedDownstream [] (head nexts) fake fake
            else 
              -- If we've passed all the tests for this command, then navigate down all possible
              -- branches in the control flow graph to continue checking.
              let checker x = usedDownstream (index : visited) x real fake in
                -- If any of the branches say the register is used, return True.
                any checker nexts
-------------------------------------- }

-- Convenience functions to deal with registers and command inspection and modification.
-------------------------------------- {
regOut = 12
regStack = 11
regFrame = 14
regTempFirst = 30
regTempSecond = 31

-- Check whether a given command type has a source location.
hasSource :: Command -> Bool
hasSource (Command inst _) = inst `elem` [Move]
hasSource _ = False

-- Check whether a given command type has a destination location.
hasDestination :: Command -> Bool
hasDestination (Command inst _) = inst `elem` [Move, Greater]
hasDestination _ = False

-- Get the destination of a command.
destination :: Command -> Argument
destination (Command Move [a, b]) = a
destination (Command Greater [a, b, c]) = c

-- Get the source of a command.
source :: Command -> Argument
source (Command Move [a, b]) = b

-- Set the destination of a command and return the modified command.
setDestination :: Command -> Argument -> Command
setDestination (Command Move [a, b]) dest = Command Move [dest, b]
setDestination (Command Greater [a, b, c]) dest = Command Greater [a, b, dest]

-- Determine whether a given command uses (reads) from a register.
uses :: Command -> Int -> Bool
uses (Command Move [ValueArg dest, ValueArg (Register src)]) reg = (src == reg)
uses (Command Greater [ValueArg (Register fst), ValueArg (Register snd), _]) reg = (fst == reg) || (snd == reg)
uses (Command Greater [ValueArg (Register fst), _]) reg = (reg == fst)
uses (Command Greater [_, ValueArg (Register snd)]) reg = (reg == snd)
uses (Command Mul [ValueArg (Register fst), ValueArg (Register snd), _]) reg = (fst == reg) || (snd == reg)
uses (Command Mul [ValueArg (Register fst), _]) reg = (reg == fst)
uses (Command Mul [_, ValueArg (Register snd)]) reg = (reg == snd)
uses (Command Add [ValueArg (Register fst), ValueArg (Register snd), _]) reg = (fst == reg) || (snd == reg)
uses (Command Add [ValueArg (Register fst), _]) reg = (reg == fst)
uses (Command Add [_, ValueArg (Register snd)]) reg = (reg == snd)
uses _ _ = False

-- Determine whether a given command defines (writes to) a register.
defines :: Command -> Int -> Bool
defines (Command Move [ValueArg (Register dest), ValueArg src]) reg = (dest == reg)
defines (Command Greater [_, _, ValueArg (Register dest)]) reg = (dest == reg)
defines (Command Greater [_, _]) reg = (reg == regOut)
defines (Command Mul [_, _, ValueArg (Register dest)]) reg = (dest == reg)
defines (Command Mul [_, _]) reg = (reg == regOut)
defines (Command Add [_, _, ValueArg (Register dest)]) reg = (dest == reg)
defines (Command Add [_, _]) reg = (reg == regOut)
defines _ _ = False
-------------------------------------- }
--
-- Post process a command stream for optimization
-------------------------------------- {
-- Optimize a set of commands. This implements some small optimizations that
-- we can use to reduce the number of emitted commands. Currently, the only
-- optimization implemented merges commands of the form:
--     move intermediate, src
--     move dest, intermediate
-- when the merge does not affect the meaning of the code (i.e. the intermediate
-- is not used later on in the computation.)
optimize :: [Command] -> [Command]
optimize commands =
  -- Repeat the optimization until it no longer has an effect
  let originalLength = length commands
      cfg = createControlFlowGraph commands 
      processed = process (nodes commands) commands
      newLength = length processed in
    if originalLength == newLength
    then processed
    else optimize processed

-- Perform one round of optimizations.
process :: [CFGNode] -> [Command] -> [Command]

-- Optimizations can only be performed on two or more
-- consecutive commands. 
process all (first : second : rest) =
  -- Build a control flow graph for all commands after
  -- the ones that we're analyzing.
  let graph = cfg all (nodes rest)

      -- Attempt to optimize these two commands into one, if possible.
      firstPairResult = pairProcess graph first second in

    -- If we can optimize the two commands into one, then
    -- replace the two commands with one and optimize the rest.
    -- If we cannot optimize the two commands, then try to optimize
    -- the rest (without the first command) and then conjoin
    -- them back together.
    case firstPairResult of
      Just result -> result : (process all rest)
      Nothing -> first : (process all $ second : rest)

-- We cannot perform optimizations when there are no commands
-- or when there is only one command, so just return the
-- input when that is the case.
process _ notEnough = notEnough

-- Process a pair of commands.
pairProcess :: CFG -> Command -> Command -> Maybe Command
pairProcess cfg first second =
  -- Check:
  --   that the two commands can be optimized (merged into one), and
  --   that removing the intermediate storage location has no side effects
  --     (i.e. the storage location is and can not be used later)
  if match first second && not (usedAfter cfg (destination first))

    -- If we can optimize the two, return their combination.
    -- Otherwise, return nothing.
  then Just $ combine first second
  else Nothing

-- Check whether a pair of commands can be merged into one.
-- This checks whether the two commands use an intermediate storage location.
match :: Command -> Command -> Bool
match first second = 
  hasDestination first && hasDestination second && hasSource second && destination first == source second

-- Combine two commands into one.
-- This operates by making the first operation write to the destination of
-- the second command, thus bypassing the intermediate that was previously used.
combine :: Command -> Command -> Command 
combine first second = setDestination first (destination second)

-- Check whether a given argument register
-- is ever used further down the control flow graph.
usedAfter :: CFG -> Argument -> Bool
usedAfter cfg reg =
  case reg of 
    -- For a register, we can determine if it is used later
    -- by analyzing the control flow graph for whether 
    -- the register is used downstream.
    ValueArg (Register regnum) -> usedDownstream [] cfg regnum regnum

    -- If this isn't a register, it could be memory or something else,
    -- in which case it may be used after (via, say, reading from memory).
    _ -> True
-------------------------------------- }

-- Assign machine registers to the placeholder (fake)
-- registers generated by the compilation process.
-------------------------------------- {
-- External interface for assigning machine registers to compiler-generated
-- placeholder registers. Arguments are:
--   A list of available registers, listed in order of preference 
--   The list of commands to process
--   Whether to emit push instructions to allocate memory on the stack
--     (this is unnecessary in the global scope, since memory is pre-allocated, but
--     is necessary for functions, where the stack needs to be expanded)
assignRegisters :: [Int] -> [Command] -> Bool -> [Command]
assignRegisters registers coms emitPush =
  let 
      -- Proccess @ (address-of) commands. These require that their
      -- arguments be on the stack and not in registers, so we process them
      -- separately and process them first.
      commands = removeAddressInternalCommands coms emitPush

      -- Collect all the placeholder registers, so we know what registers need to be replaced.
      fakes = collectFakeRegisters commands in

    -- Forward the processed commands to the real workhorse function.
    assignRegistersInternal 0 registers commands fakes emitPush

-- Assign machine registers to placeholder registers. 
-- Arguments:
--   How much stack space has been used (bytes)
--   List of possible registers
--   List of commands to process
--   List of placeholder registers to which machine registers need to be assigned
assignRegistersInternal :: Int -> [Int] -> [Command] -> [Int] -> Bool -> [Command]
assignRegistersInternal usedStack registers commands fakes emitPush =
  case fakes of
    -- If we have no more placeholder registers to replace, we're done.
    [] -> commands
    target : remaining -> 
      -- Replace the first placeholder register, and recurse. Accumulate how much of the stack is used.
      let (replaced, newUsedStack) = assignRegisterTo usedStack target registers (createControlFlowGraph commands) commands emitPush in
        assignRegistersInternal newUsedStack registers replaced remaining emitPush

-- Collect a list of all the placeholder registers used in this command block.
collectFakeRegisters :: [Command] -> [Int]
collectFakeRegisters commands =
  let argCollector (ValueArg (Register x)) = if x >= 32 then [x] else []
      argCollector _ = []
      comCollector (Label _) = []
      comCollector (Command inst args) = concatMap argCollector args in

    -- Make sure output has no duplicates
    nub $ concatMap comCollector commands

-- Process commands that need an address of a register. Make sure that those
-- registers get placed into memory, and not a machine register.
removeAddressInternalCommands :: [Command] -> Bool -> [Command]
removeAddressInternalCommands commands emitPush =
  let
      -- Find all registers that we need to put on the stack
      fakes = collectAddressedRegisters commands

      -- Put those registers on the stack by assigning registers to them, but
      -- not giving them any machine registers to use.
      replaced = assignRegistersInternal 0 [] commands fakes emitPush in

    -- Finally, replace the ADDRESS_OF internal commands generated by the compiler
    -- with arithmetic instructions which compute the memory location of the
    -- data being addressed and place them in the appropriate registers.
    replaceAddressCommandsWithArithmetic replaced

-- Collect a list of all the placeholder registers which are used in address-of instructions.
collectAddressedRegisters :: [Command] -> [Int]
collectAddressedRegisters commands =
  let argCollector (ValueArg (Register x)) = if x >= 32 then [x] else []
      argCollector _ = []
      comCollector (InternalCommand "ADDRESS_OF" [arg1, arg2]) = concatMap argCollector [arg1]
      comCollector _ = [] in

    -- Make sure output has no duplicates
    nub $ concatMap comCollector commands

-- Perform a search and replace for ADDRESS_OF commands, and
-- replace them with add instructions that compute the address.
replaceAddressCommandsWithArithmetic :: [Command] -> [Command]
replaceAddressCommandsWithArithmetic (com : coms) =
  case com of
    InternalCommand "ADDRESS_OF" [ValueArg (Memory reg offset), dest] -> 
      -- Add the constant offset to the register value, then store the
      -- output into the destination register.
      (Command Add [ValueArg $ Register reg, ValueArg $ Constant offset]) : 
      (Command Move [dest, ValueArg $ Register regOut]) :

      -- Recurse to process the remaining commands.
      replaceAddressCommandsWithArithmetic coms
    _ -> com : replaceAddressCommandsWithArithmetic coms

replaceAddressCommandsWithArithmetic [] = []

-- Try to assign a machine register to a placeholder register.
assignRegisterTo :: Int -> Int -> [Int] -> CFG -> [Command] -> Bool -> ([Command], Int)

-- Case 1: We have more machine registers to try.
-- Check whether the first machine register is valid for this placeholder register,
-- and if it is, perform the replacement. If it isn't, recurse and try other machine registers.
--
-- Return the resulting commands, as well as the stack usage (in bytes) after this assignment.
assignRegisterTo usedStack target (tryReg : otherRegs) cfg commands emitPush =
  if validRegisterAssignment cfg tryReg target
  then (performRegisterReplacement tryReg target commands, usedStack)
  else assignRegisterTo usedStack target otherRegs cfg commands emitPush

-- Case 2: We have no available machine registers, so we put
-- this register on the stack. We do not emit a push command
-- if this is being done in the global scope, but we need to
-- emit commands to allocate stack space if it's being done
-- in the function scope.
assignRegisterTo usedStack target [] cfg commands emitPush =
  let 
      -- Generate and emit a push command to allocate stack space (if necessary)
      pushCommand = Command Push [ValueArg $ Register 0]
      commandsWithAlloc = if emitPush then pushCommand : commands else commands

      -- Replace the register argument with the memory argument
      regArg = ValueArg $ Register target
      memArg = ValueArg $ Memory regFrame usedStack

      -- Perform plain argument search and replace
      commandsReplaced = performArgReplace regArg memArg commandsWithAlloc

      -- Fix command arguments. The search and replace will sometimes
      -- generate erroneous commands, which try to perform addition on
      -- memory contents. These are invalid, and need to have additional
      -- commands to load from the memory commands.
      commandsFixed = fixCommandArguments commandsReplaced in

    (commandsFixed, usedStack + 4)

-- Replace one register with another via argument search and replace
performRegisterReplacement real fake commands =
  let fakeReg = ValueArg $ Register fake
      realReg = ValueArg $ Register real in
    performArgReplace fakeReg realReg commands 

-- Search for a given argument in all the commands,
-- and replace any instances of this argument with
-- another argument.
performArgReplace original new commands =
  let argReplacer arg = if (arg == original) then new else arg
      processor (Command inst args) = Command inst (map argReplacer args) 
      processor (InternalCommand inst args) = InternalCommand inst (map argReplacer args) 
      processor label = label in
    map processor commands

-- Fix all the commands individually.
fixCommandArguments :: [Command] -> [Command]
fixCommandArguments commands =
  concatMap fixCommand commands

-- Check all possible broken commands and replace them
-- with the commands necessary to fix them. This will usually involve
-- generating some store and load instructions to access memory
-- before and after arithmetic.
fixCommand :: Command -> [Command]
fixCommand command = 
  case command of
    Command Move [ValueArg (Memory reg1 offset1), ValueArg (Memory reg2 offset2)] ->
      [Command Move [ValueArg $ Register regTempFirst, ValueArg $ Memory reg2 offset2],
       Command Move [ValueArg $ Memory reg1 offset1, ValueArg $ Register regTempFirst]]

    Command inst ((ValueArg (Memory reg offset)) : rest) ->
      if isArithmeticInstruction inst
      then
        (Command Move [ValueArg $ Register regTempFirst, ValueArg $ Memory reg offset]) :
         (fixCommand $ Command inst $ (ValueArg $ Register regTempFirst) : rest)
      else [command]

    Command inst (start : (ValueArg (Memory reg offset)) : rest) ->
      if isArithmeticInstruction inst
      then
        (Command Move [ValueArg $ Register regTempSecond, ValueArg $ Memory reg offset]) :
         (fixCommand $ Command inst $ start : (ValueArg $ Register regTempSecond) : rest)
      else [command]

    Command inst [first, second, (ValueArg (Memory reg offset))] ->
      if isArithmeticInstruction inst
      then 
        [Command inst [first, second, ValueArg $ Register regTempSecond],
         Command Move [ValueArg $ Memory reg offset, ValueArg $ Register regTempSecond]]
      else [command]

    _ -> [command]

-- Check whether an instruction is an arithmetic instruction.
isArithmeticInstruction :: Instruction -> Bool
isArithmeticInstruction inst =
  inst `elem` [Add, Sub, Mul, Div, Greater, GreaterEq, Less, LessEq, Equal, NotEqual, And, Or, Not, Negate]

-- Check if a given machine register is validly used when assigned
-- to some placeholder value by tracing out the liveness and use
-- on the control fow graph.
validRegisterAssignment graph real fake = 
  -- First, find the location where this placeholder register is defined.
  -- We only care about the control flow graph afterwards.
  case findDefinition fake [] graph of
    -- If we don't find the definition, something has gone horribly wrong.
    Nothing -> error $ "Could not find register " ++ show fake

    -- Check for validity:
    --   The machine register we want to assign can't be in use downstream, and
    --   If we want to assign a non-saved register, it can't be in use after a 'call' instruction.
    Just def -> not (usedDownstream [] def real fake) && (real > 9 || not (usedAfterCall fake [] def))

-- Find the first place where a register is defined
findDefinition :: Int -> [Int] ->  CFG -> Maybe CFG
findDefinition register visited graph =
  case graph of
    CFG (command, index) nexts ->
      -- If a command defines the register we're looking for, we've found the right place.
      if command `defines` register
      then Just graph
      else 
        -- If we're at the end of the CFG, or we've looped around, 
        -- then we haven't found anything.
        if index `elem` visited || null nexts
        then Nothing
        else 
          -- If this command doesn't define the register, check all possible paths
          -- downstream in this control flow graph. Mark this current command
          -- as visited, so that if we loop back to it we stop.
          let finder Nothing = False
              finder (Just _) = True in
            case find finder (map (findDefinition register (index : visited)) nexts) of
              Nothing -> Nothing
              Just x -> x

-- Check whether a given fake register is used after a call command
usedAfterCall :: Int -> [Int] -> CFG -> Bool
usedAfterCall register visited cfg =
  case cfg of
    CFG (command, index) nexts ->
      -- If we reach the end of a control flow graph, the register isn't used.
      -- If we loop, then the register isn't used either.
      if null nexts || index `elem` visited
      then False
      else case command of
        -- If we found a call instruction, check if the register is used downstream.
        Command Call _ -> usedDownstream [] cfg register register

        -- If we have anything but a call instruction, just go down the different CFG brances.
        _ -> any (usedAfterCall register (index : visited)) nexts
-------------------------------------- }
