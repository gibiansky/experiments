module Assembly.Compiler (compileAssembly)
  where

import Assembly.Parser
import Control.Monad
import Data.Map (Map, fromList)
import qualified Data.Map as Map
import Data.Bits
import Data.Char
import Debug.Trace

-- Externally visible function. The interface we want to expose
-- takes a list of commands, and returns an error or a list of
-- instructions that the processor can execute.
compileAssembly :: [Command] -> Either String [Int]
compileAssembly commands =
  -- Number all the commands
  let numbered = zipWith (\a b -> (a, b)) [1..] commands
      -- Compute the label table, so that jump distances can be computed
      labelTable = createLabelTable numbered

      -- Compile all the commands
      in compile numbered labelTable

-- Compile a list of numbered commands to instructions using the provided
-- label table. The label table maps the label names to their code position.
compile :: [(Int, Command)] -> Map String Int -> Either String [Int]

-- Form a base case: no commands is equivalent to no instructions
compile [] _ = Right []

-- Recursively compile each command
compile (c : cs) labelTable =
  case compiled of
       Left err -> compiled
       -- Join the generated instructions with all future generated instructions
       Right is ->  liftM (\x -> concat [is, x]) (compile cs labelTable)
  where compiled = compileCommand c labelTable

-- Compile a single instruction
compileCommand :: (Int, Command) -> Map String Int -> Either String [Int]
compileCommand (index, com) labelTable =
        case com of
           -- Do not generate any instructions for labels
           -- The generated command is a NOP.
           Label x -> Right $ makeInstruction opcode_move move_regtoreg 0 0 0

           -- Pass off further generation to one function per command
           Command Move args -> move args
           Command MoveByte args -> moveByte args

           Command Add args -> arithmetic Add args
           Command Sub args -> arithmetic Sub args
           Command Mul args -> arithmetic Mul args
           Command Div args -> arithmetic Div args
           Command And args -> arithmetic And args
           Command Or  args -> arithmetic Or args

           Command Equal    args -> arithmetic Equal args
           Command NotEqual args -> arithmetic NotEqual args
           Command Less     args -> arithmetic Less args
           Command LessEq   args -> arithmetic LessEq args
           Command Greater  args -> arithmetic Greater args
           Command GreaterEq args -> arithmetic GreaterEq args

           Command Not      args -> negation Not args
           Command Negate   args -> negation Negate args

           Command Jump      args -> jump index labelTable Jump args
           Command JumpIf     args -> jump index labelTable JumpIf args
           Command JumpUnless args -> jump index labelTable JumpUnless args

           Command JumpToReg args -> jumpToReg args

           Command Repeat args -> repeatInstr args
           Command Ascii args -> asciiInstr args

           Command LightLed args -> ledInstr args
           Command LightNumber args -> numberInstr args
           Command ReadSwitch args -> switchInstr args

           -- Throw an error if we don't recognize this command
           Command _ args -> Left $ "Unknown command, in:\n  " ++ show com

-- Create the label map, which maps label names to positions in the generated code
createLabelTable :: [(Int, Command)] -> Map String Int
createLabelTable commands =
    -- Predicate to check if a tuple hash a label
    let isLabel = \(ind, com) -> case com of
           Label _ -> True
           _ -> False
        -- Filter all commands by labels
        labels = filter isLabel commands

        -- Create the map directly from the indices
        toOrderPair = \(ind, com) -> 
          case com of
               Label str -> (str, ind)
        labelTable = fromList $ map toOrderPair labels
        in labelTable

-- Functions to generate instructions from arguments
-- One function exists per assembly command
-----------------------------------------------------
ledInstr :: [Argument] -> Either String [Int]
ledInstr args =
  let commandStr = show (Command LightLed args) in
    if length args /= 2
    then Left $ "led command takes one selector and one value argument, in: \n  " ++ commandStr
    else case (args !! 0, args !! 1) of
        (LabelArg _, _) -> cannotTakeLabelError "led" commandStr
        (_, LabelArg _) -> cannotTakeLabelError "led" commandStr
        (ValueArg (Register control), ValueArg (Register value)) -> return $ led control value
        _ -> invalidArgumentsError "led" commandStr

numberInstr :: [Argument] -> Either String [Int]
numberInstr args =
  let commandStr = show (Command LightNumber args) in
    if length args /= 2
    then Left $ "number command takes one selector and one value argument, in: \n  " ++ commandStr
    else case (args !! 0, args !! 1) of
        (LabelArg _, _) -> cannotTakeLabelError "number" commandStr
        (_, LabelArg _) -> cannotTakeLabelError "number" commandStr
        (ValueArg (Register control), ValueArg (Register value)) -> return $ number control value
        _ -> invalidArgumentsError "number" commandStr

switchInstr :: [Argument] -> Either String [Int]
switchInstr args =
  let commandStr = show (Command ReadSwitch args) in
    if length args /= 2
    then Left $ "switch command takes one destination and one selector argument, in: \n  " ++ commandStr
    else case (args !! 0, args !! 1) of
        (LabelArg _, _) -> cannotTakeLabelError "switch" commandStr
        (_, LabelArg _) -> cannotTakeLabelError "switch" commandStr
        (ValueArg (Register dest), ValueArg (Register src)) -> return $ readSwitch dest src
        _ -> invalidArgumentsError "switch" commandStr

asciiInstr :: [Argument] -> Either String [Int]
asciiInstr args =
  let commandStr = show (Command Ascii args) in
    if length args /= 1
    then Left $ "ascii command takes one string argument, in: \n  " ++ commandStr
    else case args !! 0 of
        LabelArg _ -> cannotTakeLabelError "ascii" commandStr
        ValueArg (Str strarg) -> Right $ (map ord strarg) ++ [0]
        _ -> invalidArgumentsError "ascii" commandStr

repeatInstr :: [Argument] -> Either String [Int]
repeatInstr args =
  let commandStr = show (Command Repeat args) in
    if length args /= 2
    then Left $ "repeat command takes two arguments, in: \n  " ++ commandStr
    else case (args !! 0, args !! 1) of
        (LabelArg _, _) -> cannotTakeLabelError "repeat" commandStr
        (_, LabelArg _) -> cannotTakeLabelError "repeat" commandStr
        (ValueArg dest, ValueArg src) ->
          case (dest, src) of
            (Constant val, Constant times) -> Right $ replicate times val
            _ -> invalidArgumentsError "repeat" commandStr

-- Move a word between registers, memory, etc
move :: [Argument] -> Either String [Int]
move args =
  let commandStr = show (Command Move args) in
    if length args /= 2
    then Left $ "move command takes two arguments, in: \n  " ++ commandStr
    else case (args !! 0, args !! 1) of
        (LabelArg _, _) -> cannotTakeLabelError "move" commandStr
        (_, LabelArg _) -> cannotTakeLabelError "move" commandStr
        (ValueArg dest, ValueArg src) ->
          case (dest, src) of
            (Register d, Register s) -> Right $ moveFromRegToReg d s
            (Register d, Memory r o) -> Right $ moveFromMemToReg d r o 
            (Memory r o, Register s) -> Right $ moveFromRegToMem r o s
            (Register d, Constant v) -> Right $ moveFromConstToReg d v
            _ -> invalidArgumentsError "move" commandStr

-- Moves a byte between registers, memory, etc
-- Note that this emits the same instruction as a plain move, unless
-- the instruction is writing/reading from memory.
moveByte :: [Argument] -> Either String [Int]
moveByte args =
  let commandStr = show (Command Move args) in
    if length args /= 2
    then Left $ "move-byte command takes two arguments, in: \n  " ++ commandStr
    else case (args !! 0, args !! 1) of
        (LabelArg _, _) -> cannotTakeLabelError "move-byte" commandStr
        (_, LabelArg _) -> cannotTakeLabelError "move-byte" commandStr
        (ValueArg dest, ValueArg src) ->
          case (dest, src) of
            (Register d, Register s) -> Right $ moveFromRegToReg d s
            (Register d, Memory r o) -> Right $ moveByteFromMemToReg d r o 
            (Memory r o, Register s) -> Right $ moveByteFromRegToMem r o s
            (Register d, Constant v) -> Right $ moveFromConstToReg d v
            _ -> invalidArgumentsError "move-byte" commandStr

-- Compiles negation instructions
-- This is similar to arithmetic instructions, but instead of having 2 or 3 arguments
-- these instructions only have 1 or 2 arguments.
negation :: Instruction -> [Argument] -> Either String [Int]
negation inst args =
  let commandStr = show (Command inst args) in
    if length args == 1
    then
      case args !! 0 of
        -- Do not allow labels in the arguments
        LabelArg _ -> cannotTakeLabelError "negation" commandStr

        ValueArg (Register a) -> 
          Right $ arithmeticInstructionRegReg inst a 0 register_out

        _ -> invalidArgumentsError "negation" commandStr
    else if length args == 2
         then
           case (args !! 0, args !! 1) of
             -- Do not allow labels in the arguments
             (LabelArg _, _) -> cannotTakeLabelError "negation" commandStr
             (_, LabelArg _) -> cannotTakeLabelError "negation" commandStr

             (ValueArg target, ValueArg reg) ->
               case (target, reg) of
                 -- The third argument is the register in which to store the output
                 (_, Memory _ _) -> 
                   Left $ "negation command second argument must be register, in:\n  " 
                     ++ commandStr
                 (_, Constant _) -> 
                   Left $ "negation command second argument must be register, in:\n  " 
                     ++ commandStr

                 (Register a, Register outReg) -> 
                   Right $ arithmeticInstructionRegReg inst a 0 outReg

                 _ -> invalidArgumentsError "negation" commandStr
         else
           Left $ "arithmetic commands take two or three arguments, in: \n  " ++ commandStr

-- Compiles arithmetic instructions
arithmetic :: Instruction -> [Argument] -> Either String [Int]
arithmetic inst args = 
  -- Two instructions perform an operation and store it in the default out register
  let commandStr = show (Command inst args) in
    if length args == 2
    then
      case (args !! 0, args !! 1) of
        -- Do not allow labels in the arguments
        (LabelArg _, _) -> cannotTakeLabelError "arithmetic" commandStr
        ( _, LabelArg _) -> cannotTakeLabelError "arithmetic" commandStr

        (ValueArg left, ValueArg right) ->
          case (inst, left, right) of
            (_, Register a, Register b) -> 
              Right $ arithmeticInstructionRegReg inst a b register_out

            -- The division command is a bit unusual, so make sure the assembler
            -- only allows arguments in the order of "a <operation> b"
            (Div, Constant a, Register b) -> 
              Left $ "div command cannot divide constant by register, in:\n  " ++ commandStr
            (Div, Register a, Constant b) -> 
              Right $ arithmeticInstructionRegConst inst b a

            -- Logical operations cannot use constants
            (And, Constant a, Register b) -> 
              Left $ "and command cannot use a constant, in:\n  " ++ commandStr
            (Or, Constant a, Register b) -> 
              Left $ "or command cannot use a constant, in:\n  " ++ commandStr

            (_, Constant a, Register b) -> 
              Right $ arithmeticInstructionRegConst inst a b
            _ -> invalidArgumentsError "arithmetic" commandStr
    else if length args == 3
         then
           case (args !! 0, args !! 1, args !! 2) of
             -- Do not allow labels in the arguments
             (LabelArg _, _, _) -> cannotTakeLabelError "arithmetic" commandStr
             (_, LabelArg _, _) -> cannotTakeLabelError "arithmetic" commandStr
             (_, _, LabelArg _) -> cannotTakeLabelError "arithmetic" commandStr

             (ValueArg left, ValueArg right, ValueArg reg) ->
               case (inst, left, right, reg) of
                 -- The third argument is the register in which to store the output
                 (_, _, _, Memory _ _) -> 
                   Left $ "arithmetic command third argument must be register, in:\n  " 
                     ++ commandStr
                 (_, _, _, Constant _) -> 
                   Left $ "arithmetic command third argument must be register, in:\n  " 
                     ++ commandStr

                 -- Logical operations cannot use constants
                 (And, Constant a, Register b, _) -> 
                   Left $ "and command cannot use a constant, in:\n  " ++ commandStr
                 (Or, Constant a, Register b, _) -> 
                   Left $ "or command cannot use a constant, in:\n  " ++ commandStr

                 -- Since we're using the immediate bits to store a register value,
                 -- we can't use them to store a constant. Thus the three-argument
                 -- form only works with register-register arithmetic commands.
                 (_, Constant a, Register b, _) -> 
                   Left $ "arithmetic instruction cannot take 3 arguments when using a constant, in:\n  " ++ commandStr

                 (_, Register a, Register b, Register outReg) -> 
                   Right $ arithmeticInstructionRegReg inst a b outReg

                 _ -> invalidArgumentsError "arithmetic" commandStr
         else
           Left $ "arithmetic commands take two or three arguments, in: \n  " ++ commandStr


-- Compile a jump instruction using the instruction index and label table
jump :: Int -> Map String Int -> Instruction -> [Argument] -> Either String [Int]
jump index labelTable inst args =
  let commandStr = show (Command inst args) in
    if length args /= 1
    then Left $ "jump command takes one label argument, in: \n  " ++ commandStr
    else case args !! 0 of
        ValueArg _ ->
          Left $ "jump command takes one label argument, in: \n  " ++ commandStr
        LabelArg labelName ->
          case Map.lookup labelName labelTable of
            Nothing ->
              Left $ "jump command label " ++ labelName ++ "not found, in: \n  " 
                ++ commandStr
            Just targetIndex ->
              if targetIndex - index <= 2^20 - 1 && 
                 targetIndex - index >= -2^20
              then Right $ jumpInstruction inst (targetIndex - index)
              else Left $ "jump command cannot jump so far, in:\n  " ++ commandStr

jumpToReg :: [Argument] -> Either String [Int]
jumpToReg args =
  let commandStr = show (Command JumpToReg args) in
    if length args /= 1
    then Left $ "goto command takes one register argument, in: \n  " ++ commandStr
    else case args !! 0 of
        ValueArg (Register reg) -> Right $ gotoInstruction reg
        _ -> invalidArgumentsError "goto" commandStr
-----------------------------------------------------

-- Convenience error functions
-----------------------------------------------------
cannotTakeLabelError :: String -> String -> Either String [Int]
cannotTakeLabelError name str =
  Left $ name ++ " cannot take a label, in:\n  " ++ str

invalidArgumentsError :: String -> String -> Either String [Int]
invalidArgumentsError name str =
  Left $ "Invalid arguments to " ++ name ++ ", in:\n  " ++ str
-----------------------------------------------------

-- Register constants
-----------------------------------------------------
register_out = 12 :: Int
-----------------------------------------------------

                                             
-- Constant opcodes and specifiers
-----------------------------------------------------
opcode_move   = 0 :: Int

move_regtoreg          = 0 :: Int
move_regtomem          = 1 :: Int
move_memtoreg          = 2 :: Int
move_consttoreg        = 3 :: Int
move_byte_memtoreg     = 4 :: Int
move_byte_regtomem     = 5 :: Int

opcode_arithmetic   = 1 :: Int

alu_add_reg          = 0 :: Int
alu_add_const        = 1 :: Int
alu_sub_reg          = 2 :: Int
alu_sub_const        = 3 :: Int
alu_mul_reg          = 4 :: Int
alu_mul_const        = 5 :: Int
alu_div_reg          = 6 :: Int
alu_div_const        = 7 :: Int

opcode_logical    = 2 :: Int

alu_and_reg             = 0 :: Int
alu_or_reg              = 1 :: Int
alu_neq_reg             = 2 :: Int
alu_neq_const           = 3 :: Int
alu_eq_reg              = 4 :: Int
alu_eq_const            = 5 :: Int
alu_not                 = 6 :: Int
alu_negate              = 7 :: Int

opcode_comparison = 3 :: Int

alu_lt_reg             = 0 :: Int
alu_lt_const           = 1 :: Int
alu_lte_reg            = 2 :: Int
alu_lte_const          = 3 :: Int
alu_gt_reg             = 4 :: Int
alu_gt_const           = 5 :: Int
alu_gte_reg            = 6 :: Int
alu_gte_const          = 7 :: Int

opcode_jump = 4 :: Int

jump_unconditional    = 0 :: Int
jump_if_true          = 1 :: Int
jump_if_false         = 2 :: Int
jump_to_reg           = 3 :: Int

opcode_system = 5 :: Int

system_led         = 0 :: Int
system_number      = 1 :: Int
system_read_switch = 2 :: Int
-----------------------------------------------------

-- Convenience functions to generate instructions
-----------------------------------------------------
moveFromRegToReg d s = makeInstruction opcode_move move_regtoreg d s 0
moveFromMemToReg d r o = makeInstruction opcode_move move_memtoreg d r o
moveFromRegToMem r o s = makeInstruction opcode_move move_regtomem r s o
moveFromConstToReg d v = makeInstruction opcode_move move_consttoreg d 0 v

moveByteFromMemToReg d r o = makeInstruction opcode_move move_byte_memtoreg d r o
moveByteFromRegToMem r o s = makeInstruction opcode_move move_byte_regtomem r s o

arithmeticInstructionRegReg :: Instruction -> Int -> Int -> Int -> [Int]
arithmeticInstructionRegReg inst regA regB regOut =
  case inst of
    Add -> 
      makeInstruction opcode_arithmetic alu_add_reg regA regB regOut
    Sub -> 
      makeInstruction opcode_arithmetic alu_sub_reg regA regB regOut
    Mul -> 
      makeInstruction opcode_arithmetic alu_mul_reg regA regB regOut
    Div -> 
      makeInstruction opcode_arithmetic alu_div_reg regA regB regOut

    And ->
      makeInstruction opcode_logical alu_and_reg regA regB regOut
    Or ->
      makeInstruction opcode_logical alu_or_reg regA regB regOut

    Equal ->
      makeInstruction opcode_logical alu_eq_reg regA regB regOut
    NotEqual ->
      makeInstruction opcode_logical alu_neq_reg regA regB regOut

    Less ->
      makeInstruction opcode_comparison alu_lt_reg regA regB regOut
    LessEq ->
      makeInstruction opcode_comparison alu_lte_reg regA regB regOut
    Greater ->
      makeInstruction opcode_comparison alu_gt_reg regA regB regOut
    GreaterEq ->
      makeInstruction opcode_comparison alu_gte_reg regA regB regOut

    Not ->
      makeInstruction opcode_logical alu_not regA regB regOut
    Negate ->
      makeInstruction opcode_logical alu_not regA regB regOut

arithmeticInstructionRegConst :: Instruction -> Int -> Int -> [Int]
arithmeticInstructionRegConst inst const reg =
  case inst of
    Add -> 
      makeInstruction opcode_arithmetic alu_add_const reg 0 const
    Sub -> 
      makeInstruction opcode_arithmetic alu_sub_const reg 0 const
    Mul -> 
      makeInstruction opcode_arithmetic alu_mul_const reg 0 const
    Div -> 
      makeInstruction opcode_arithmetic alu_div_const reg 0 const

    Equal ->
      makeInstruction opcode_logical alu_eq_const reg 0 const
    NotEqual ->
      makeInstruction opcode_logical alu_neq_const reg 0 const

    Less ->
      makeInstruction opcode_comparison alu_lt_const reg 0 const
    LessEq ->
      makeInstruction opcode_comparison alu_lte_const reg 0 const
    Greater ->
      makeInstruction opcode_comparison alu_gt_const reg 0 const
    GreaterEq ->
      makeInstruction opcode_comparison alu_gte_const reg 0 const

jumpInstruction :: Instruction -> Int -> [Int]
jumpInstruction inst dist =
  case inst of
    Jump ->
      makeJumpInstruction opcode_jump jump_unconditional (dist * 4)
    JumpIf ->
      makeJumpInstruction opcode_jump jump_if_true (dist * 4)
    JumpUnless ->
      makeJumpInstruction opcode_jump jump_if_false (dist * 4)

gotoInstruction :: Int -> [Int]
gotoInstruction = makeJumpInstruction opcode_jump jump_to_reg

led ctrl val = 
  makeInstruction opcode_system system_led ctrl val 0
number ctrl val = 
  makeInstruction opcode_system system_number ctrl val 0
readSwitch dest src = 
  makeInstruction opcode_system system_read_switch dest src 0
-----------------------------------------------------

-- Functions to generate binary instructions from their parts
-----------------------------------------------------

-- Create a single integer from the components of a jump instruction
makeJumpInstruction :: Int -> Int -> Int -> [Int]
makeJumpInstruction op spec dist =
  -- Shift all bits into their desired positions
  let opMask = (op `shift` (32 - 3))
      specMask = (spec `shift` (32 - 6))
      -- Make sure the destination, if negative, doesn't overwrite the opcode or specifier
      shiftedDist = dist .&. 0x001fffff
      in [opMask .|. specMask .|. shiftedDist]

-- Create a single integer from the components of an instruction
makeInstruction :: Int -> Int -> Int -> Int -> Int -> [Int]
makeInstruction op spec dest src imm =
  -- Shift all bits into their desired positions
  -- We trust that everything but the immediate is the correct length,
  -- because we are generating those numbers ourselves.
  let opMask = (op `shift` (32 - 3))
      specMask = (spec `shift` (32 - 6))
      destMask = (dest `shift` (32 - 11))
      srcMask = (src `shift` (32 - 16))
      -- Fix the immediate to be no longer than 16 bits
      immediateMask = fixImmediate imm 16
      in [opMask .|. specMask .|. destMask .|. srcMask .|. immediateMask]

-- Clear the top 16 bits of the immediate
fixImmediate :: Int -> Int -> Int
fixImmediate int len = 
  -- Haskell's shift function may perform sign extension, so to avoid that
  -- we clear the top bit. We then shift over by 16 (to lose the top 16 bits),
  -- and then shift back 16 (to place it in the right position). Finally, we restore
  -- the 16th bit to its original state.
  let lastBitTrue = testBit int (len - 1)
      lastBitCleared = clearBit int (len - 1)
      fixed = (lastBitCleared `shift` len) `shift` (-len)
      in if lastBitTrue
         then setBit fixed (len - 1)
         else fixed
-----------------------------------------------------
