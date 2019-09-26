--[[
    Then, another function does the message matching by hooking to a server [and channel],
    and matches on message content, then issues the SPLAY command with file name to HexChat.

    I think the fancy parsing should be left to last.

    Why should it be left to last?

     - Lexer
     - Parser
     - Settings Printer
     - Settings Setter
     - Settings Getter
     - Hook function
     - - Receive Channel Message
     - - Settings Getter on sever and channel
     - - Recurse through matches, /SPLAY-ing every match's sound
--]]

hexchat.register(
  "SpecialSounds",
  "0.0.2",
  "Set special sound to play on message"
)

local command_name = "SSOUND"

local function set_sound (server_name, channel_name, sound_file, match)
  print("Hello")
end

local function print_error (message)
  print(message)
end

local function lex (str)
  if not str or #str < 1 then
    print_error("Empty command invocation")
    return false
  end

  local position = 1
  --[=[
  if str:sub(1,8):match("/[Ss][Ss][Oo][Uu][Nn][Dd] ") then
    position = 9
  else
    str = "/SSOUND " .. str
    position = 9
  end
  --]=]

  local parenthesis_count = 0
  local parenthesis_group = ""
  local symbol = ""
  local tokens = {}  


  local function unbalanced_parenthesis_error (group)
    local missing_paren = parenthesis_count > 0 and ")" or "("
    missing_paren = missing_paren:rep(math.abs( parenthesis_count ))
    print_error(([[
Unbalanced parenthesis: missing %s

This is the group:
%s

The full command is:
/%s %s
]]):format(missing_paren, parenthesis_group, command_name, str)
    )
  end

  local function unexpected_character_error (char)
    print_error(([[
Found unexpected character:
%s

Here:
/%s %s
%s
]]):format(char, command_name, str, (" "):rep(position -1 + #command_name + 2) .. "^")
    )
  end

  local lex_parenthesis_group, inner_lex

  function lex_parenthesis_group ()
    if parenthesis_count == 0 then
      tokens[#tokens + 1] = {name="parenthesis_group", value=parenthesis_group}
      parenthesis_group = ""
      return inner_lex()
    end

    if position > #str then
      unbalanced_parenthesis_error(parenthesis_group)
      return false
    end

    char = str:sub(position, position)
    if char == "%" then
      next_char = str:sub(position + 1, position + 1)
      if next_char:match("[()]") then
        position = position + 2
        parenthesis_group = parenthesis_group .. char .. next_char
        return lex_parenthesis_group()
      else
        position = position + 1
        parenthesis_group = parenthesis_group .. char
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
      return lex_parenthesis_group()
    else
      position = position + 1
      parenthesis_group = parenthesis_group .. char
      return lex_parenthesis_group()
    end
  end


  function inner_lex ()
    if position > #str then
      if #symbol > 0 then
        tokens[#tokens + 1] = {name="symbol", value=symbol}
        symbol = ""
      end
      return true
    end

    char = str:sub(position, position)
    if char == "#" then
      position = position + 1
      tokens[#tokens + 1] = {name="hashmark", value=char}
      return inner_lex()
    elseif char:match("%s") then
      position = position + 1
      if #symbol > 0 then
        tokens[#tokens + 1] = {name="symbol", value=symbol}
        symbol = ""
      end
      return inner_lex()
    elseif char == "(" then
      if #symbol == 0 then
        position = position + 1
        parenthesis_count = parenthesis_count + 1
        parenthesis_group = parenthesis_group .. char
        return lex_parenthesis_group()
      else
        position = position + 1
        symbol = symbol .. char
        return inner_lex()
      end
    elseif char == ")" then
      if #symbol == 0 then
        unexpected_character_error(char)
        return false
      else
        position = position + 1
        symbol = symbol .. char
        return inner_lex()
      end
    else
      position = position + 1
      symbol = symbol .. char
      return inner_lex()
    end
  end

  local exit_value = inner_lex()
  if not exit_value then
    return exit_value
  end
  
  --[[
  return function ()
    for i=1, #tokens do
      return tokens[i]
    end
  end
  --]]
  return tokens
end

function hook_command (words, word_eols)
  tokens = lex(word_eols[2])
  if not tokens then
    print_error("Sorry, could not lex command")
    return hexchat.EAT_HEXCHAT
  end
  
  --[=[
  for token in tokens do
    print(([[
Token name:
%s
Token:
%s

]]):format(token.name, token.value))
  end
  --]=]

  for i=1, #tokens do
    print(([[
Token name:
%s
Token:
%s

]]):format(tokens[i].name, tokens[i].value)
    )
  end
  
  return hexchat.EAT_HEXCHAT
end

---[===[
-- Debugging
local function print_hook_args (...)
  for i=1, select('#', ...) do
    print(select(i, ...))
  end
  local arg = {...}
  for i,val in ipairs(arg) do
    print("arg "..tostring(i))
    for subi,subval in ipairs(val) do
      print("item "..tostring(subi).." val: "..subval)
    end
  end
  return hexchat.EAT_HEXCHAT
end
--]===]

-- Command for configuration  
hexchat.hook_command(command_name, hook_command, [[
DESCRIPTION

Watch for message matching [match] in specific server and channel, and play sound with /SPLAY on match
/SSOUND [server name] #[channel name] sound [sound file] match [match]

If any of [server name], [channel name], [sound file], or [match] have spaces, they must be wrapped in parenthesis.
Note that the channel name will have the # on the outside of the parenthesis.

The [match] must be a Lua pattern: https://www.lua.org/pil/20.2.html

EXAMPLES

Play sound from D:\friend.wav when your friends name is mentioned:
/SSOUND freenode #irc sound D:\friend.wav match friends_nick

Show all sounds set for server freenode channel #irc:
/SSOUND freenode #irc

Set the sound file to (D:\attention attention.wav) for any channel with "help" in the name:
/SSOUND #(.*help.*) sound (D:\attention attention.wav)
Note, this will not play the sound, as no match has been specified yet:
/SSOUND #(.*help.*) match (%?)
Now it will match anything with a question mark in it.

]])