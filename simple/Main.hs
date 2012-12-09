module Main where

import System.Environment
import System.IO
import Numeric
import Data.List

import Assembly.Parser
import Assembly.Compiler

import Simple.Parser
import Simple.Verifier
import Simple.Compiler

-- Read file specified by command line argument. Parse file contents.
main :: IO ()
main = do
  args <- getArgs
  let filename = args !! 0
  text <- readFile filename
  let out = assemblyMain text
  --let out = languageMain text filename
  putStrLn out

assemblyMain :: String -> String
assemblyMain text =
  case parseAssembly text of
    Left error -> "Parse Error: " ++ show error
    Right value ->
      case compileAssembly value of
        Left err -> err
        Right is -> foldl (++) "" (intersperse "\n" (map show is))

languageMain :: String -> String -> String
languageMain text filename =
  case parseSimple text filename of
    Left error -> "Parse Error: " ++ show error
    Right value ->
      case verifySimple value of
        ([], structs, funs) -> printAssembly $ postProcess 0 $ compileSimple value funs structs
        (lst, _, _) -> printErrors lst

printAssembly :: [Command] -> String
printAssembly asm = 
  let asms = map show asm in
    foldl (\l r -> l ++ "\n" ++ r) "" asms

printErrors :: [String] -> String
printErrors errs = foldl (\x y -> x ++ y ++ "\n" ) "" errs

-- Convert a number to hex
numToHex :: Int -> String
numToHex x = 
  let hex = showHex x ""
      hexLen = length hex
      in concat [(take (8 - hexLen) (repeat '0')), hex, "\n"]
                                            
