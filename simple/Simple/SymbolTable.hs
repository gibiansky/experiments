module Simple.SymbolTable
  where

import qualified Data.Map as Map

type SymbolTable a = [Map.Map String a]

-- Create a new symbol table
create :: SymbolTable a
create =  [Map.empty]

-- Add a new level to the symbol table
startBlock :: SymbolTable a -> SymbolTable a
startBlock table =  Map.empty : table

-- Remove a level from a symbol table
endBlock :: SymbolTable a -> SymbolTable a
endBlock (x:xs) = xs

-- Add an identifier to the symbol table
add :: String -> a -> SymbolTable a -> SymbolTable a
add name dataType (x:xs) =
   (Map.insert name dataType x) : xs

-- Check whether an identifier exists in the symbol table
exists :: String -> SymbolTable a -> Bool
exists _ [] = False
exists name (x:xs) =
  Map.member name x || exists name xs

-- Check whether an identifier exists in the symbol table at the top level
existsLocal :: String -> SymbolTable a -> Bool
existsLocal _ [] = False
existsLocal name (x:xs) = Map.member name x

-- Lookup the type of an identifier in the symbol table
-- This will break if the identifier does not exist.
get :: String -> SymbolTable a -> a
get name (x:xs) =
  case Map.lookup name x of
    Just identType -> identType
    Nothing -> get name xs
