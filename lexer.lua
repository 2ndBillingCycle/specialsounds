-- Neither this lexer nor parser are pretty. A very pretty one is at:
-- https://github.com/stravant/LuaMinify/blob/master/ParseLua.lua
local rock = {}
local emit = require "emit"
rock.lex = function (str)
---[[ This function is passed the command invocation as seen by HexChat,
   -- with the expectation that the command name is stripped:
   -- 
   --     /SSOUND rest of command
   --     to
   --     rest of command

   -- If this is not done, this lexer/tokenizer will still function correctly,
   -- and will simply include "/SSOUND" as the first symbol token.

---[[ Make sure not to length check potentially nil variables
   -- before nil checking first, as checking the length of a nil value
   -- always errors.

   -- Because the hook_command takes the second word_eols value, and,
   -- if the command is simply "/SSOUND", the word_eols table is only
   -- 1 item in length, all the rest of the table items will return
   -- as nil.
  if type(str) ~= "string" or #str < 1 then
    str = ""
  end

---[[ The general idea is we're given the command invocation as a string, and we
   -- walk through the string, looking at each character in order, and deciding
   -- what to do based on what we see.
   -- 
   -- Lua supports tail-call elimination in pretty cool ways, so for each "branch"
   -- of the state machine, we wrap up by either calling the main loop function again,
   -- this time with the state set to the next character, or to a branch for processing
   -- a particular token.

   -- All this does is split up the command into basic components:
   --  - parenthesis groups: anything wrapped between two parenthesis
   --  - Every other group of characters separated by spaces
   -- 
   -- Each component, or token, is assumed to be separated from the next by 1 or more spaces.

   -- The processing of the tokens is the parser's job.

   -- Here we just make sure we have valid tokens:
   --  - Parenthesis groups have a balanced number of parenthesis:
   --  - - (() (%()) (hello)) <-- all bad
   --  - We don't have malformed tokens:
   --  - - Currently, everything goes except, starting a token with )
  local position = 1           -- Tracks of position in the command string
  local parenthesis_count = 0  -- ( -> +1   and   ) -> -1
                               -- So if the number of parenthesis match up, this should be 0
  local parenthesis_group = "" -- The characters in the current parenthesis group, including wrapping parenthesis
  local symbol = ""            -- The characters in the current symbol
  local tokens = {}            -- An array of the tokens encountered, in the order they're encountered
  --[[
    The format of tokens is:

    {
      1={name=token_name, value=token value},
      2={name=token_name, value=token_value},
      ...
    }
  --]]

---[[ Special errors for specific cases
  local function unbalanced_parenthesis_error (group)
    local missing_paren = parenthesis_count > 0 and ")" or "("
    missing_paren = missing_paren:rep(math.abs( parenthesis_count ))
    emit.err([[
Unbalanced parenthesis: missing %s

This is the group:
%s

The full command is:
/%s %s]],
      missing_paren,
      parenthesis_group,
      command_name,
      str
    )
  end

  local function unexpected_character_error (char)
    emit.err([[
Found unexpected character:
%s

Here:
/%s %s
%s]],
      char,
      command_name,
      str,
      (" "):rep(position -1 + #command_name + 2) .. "^"
    )
  end
--]]

---[[ Because these functions have "indirect recursive definitions",
   -- they need to be declared as variables before being defined,
   -- so that they are in scope for each other in their definitions.
   -- The variable value is looked up at run-time, so they can start
   -- out undefined, or nil.
  local lex_parenthesis_group, lex_symbol, inner_lex

  -- This is the branch for the parenthesis group token
  function lex_parenthesis_group ()
    if position > #str then
      -- If we've suddenly reached the end of the string without a closing ) then this is an error
      unbalanced_parenthesis_error(parenthesis_group)
      return false
    end

    -- For every branch, including the main one, we start out by grabbing the current character
    char = str:sub(position, position)
    if char == "%" then
      next_char = str:sub(position + 1, position + 1)
      -- A % can escape a paren, so if it is, consume both without changing the parenthesis_count
      -- and if not, consume just the %
      if next_char:match("[()]") then
        position = position + 2
        parenthesis_group = parenthesis_group .. char .. next_char
        return lex_parenthesis_group()
      else
        position = position + 1
        parenthesis_group = parenthesis_group .. char
        return lex_parenthesis_group()
      end
    elseif char == "(" then
      parenthesis_count = parenthesis_count + 1
      position = position + 1
      parenthesis_group = parenthesis_group .. char
      return lex_parenthesis_group()
    elseif char == ")" then
      parenthesis_count = parenthesis_count - 1
      position = position + 1
      parenthesis_group = parenthesis_group .. char
      
      -- Only if the parenthesis are balanced should we wrap up this parenthesis group
      -- Anything else is an error
      if parenthesis_count == 0 then
        tokens[#tokens + 1] = {name="parenthesis_group", value=parenthesis_group}
        parenthesis_group = ""
        return inner_lex()
      end
      
      return lex_parenthesis_group()
    else
      position = position + 1
      parenthesis_group = parenthesis_group .. char
      return lex_parenthesis_group()
    end
  end

  -- Branch for any token that's not a parenthesis group
  function lex_symbol (symbol_name)
    local symbol_name = symbol_name or "text"
    if position > #str then
      --[[
        If we've reached the end of the string, and we have something for a symbol,
        add it.
        Either way, return back to the main loop.
        Branches never terminate lexing on their own.
        In case different exit codes need to be given in the future, having the branches
        return to the main loop means updating those return values in 1 place only.
      --]]
      if #symbol > 0 then
        tokens[#tokens + 1] = {name=symbol_name, value=symbol}
        symbol = ""
      end
      return inner_lex()
    end

    char = str:sub(position, position)
    if char:match("%s") then
      -- A space character denotes the end of a symbol,
      -- so even if there's lots of spaces in a row, we return to the main loop, and let that handle them
      if #symbol > 0 then
        position = position + 1
        tokens[#tokens + 1] = {name=symbol_name, value=symbol}
        symbol = ""
      end
      return inner_lex()
    elseif symbol_name == "number" and not char:match("%d") then
      position = position + 1
      symbol = symbol .. char
      symbol_name = "text"
      return lex_symbol(symbol_name)
    else
      -- Everything else is a valid symbol character, including ( and )
      position = position + 1
      symbol = symbol .. char
      return lex_symbol(symbol_name)
    end
  end

  function inner_lex ()
    if position > #str then
      return true
    end

    char = str:sub(position, position)
    if char == "#" then
      position = position + 1
      tokens[#tokens + 1] = {name="hashmark", value=char}
      return inner_lex()
    elseif char:match("%s") then
      position = position + 1
      return inner_lex()
    elseif char == "(" then
      -- Jump to the lex_parenthesis group branch without changing state
        return lex_parenthesis_group()
    elseif char == ")" then
      unexpected_character_error(char)
      return false
    elseif char == "/" then
      return lex_symbol("action")
    elseif char:match("%d") then
      return lex_symbol("number")
    else
      -- Jump to the lex_symbol branch without changing state
      return lex_symbol()
    end
  end

  -- Check the return value of lexing by lexing the command string, and grabbing the function's output.
  -- Truthy values mean success, falsey values indicate failure.
  local exit_value = inner_lex()
  if not exit_value then
    return exit_value
  end
  
  -- This should not return an empty table of tokens
  return tokens
end
--]]
return rock
