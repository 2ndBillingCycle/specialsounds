--[[
     - Lexer               ✓
     - Parser              ✓
     - Settings Printer    ✓
     - Settings Setter     -
     - Settings Getter     -
     - Hook function       ✗
     - - Receive Channel Message
     - - Settings Getter on sever and channel
     - - Recurse through matches, /SPLAY-ing every match's sound


     Explanatory comments are much needed, in case I want to go through and fix bugs, after I've forgotten
     how I wrote all of this.

     I'll also probably eventually want to make specifying channel AND server name optional, as currently,
     only one needs to be specified, but the one elided is treated as a non-match (), and if both are missing,
     the next piece of text is treated as the server name.
--]]

hexchat.register(
  "SpecialSounds",
  "0.0.2",
  "Set special sound to play on message"
)

local command_name = "SSOUND"
local settings_prefix = command_name .. "_"

local function set_sound (server_name, channel_name, sound_file, match)
  print("Hello")
end

-- Neither this lexer or parser are pretty. A very pretty one is at:
-- https://github.com/stravant/LuaMinify/blob/master/ParseLua.lua
-- Currently, no fancy printing is done
-- In the future, these could be set to make a private message, or something
local function print_error (message) print(message) end
local function print_message (message) print(message) end

local function lex (str)
  --[[
    This function is passed the command invocation as seen b HexChat,
    with the expectation that the command name is stripped:
    
    /SSOUND rest of command
    to
    rest of command

    If this is not done, this lexer/tokenizer will still function correctly,
    and will simply pass "/SSOUND" as the first symbol token.
  --]]

  --[[
    Make sure not to length check potentially nil variables
    before nil checking first.

    Because the hook_command takes the second word_eols value, and,
    if the command is simply "/SSOUND", the word_eols table is only
    1 item in length, all the rest of the table items will return
    as nil.
  --]]
  if not str or #str < 1 then
    print_error("Empty command invocation\nFor help, type:\n/HELP SSOUND")
    return false
  end

  --[[
    The general idea is we're given the command invocation as a string, and we
    walk through the string, looking at each character in order, and deciding
    what to do based on what we see.
    
    Lua supports tail-call elimination in pretty cool ways, so for each "branch"
    of the state machine, we wrap up by either calling the main loop function again,
    this time with the state set to the next character, or to a branch for processing
    a particular token.

    All this does is split up the command into basic components:
     - parenthesis groups: anything wrapped between two parenthesis
     - Every other group of characters separated by spaces
    
    Each component, or token, is assumed to be separated from the next by 1 or more spaces.

    The processing of the tokens is the parser's job.

    Here we just make sure we have valid tokens:
     - Parenthesis groups have a balanced number of parenthesis:
     - - (() (%()) (hello)) <-- all bad
     - We don't have malformed tokens:
     - - Currently, everything goes except, starting a token with )
  ]]
  local position = 1           -- Tracks of position in the command string
  local parenthesis_count = 0  -- ( -> +1   and   ) -> -1
                               -- So if the number of parenthesis match up, this should be 0
  local parenthesis_group = "" -- The characters in the current parenthesis group, including wrapping parenthesis
  local symbol = ""            -- The characters in the current symbol
  local tokens = {}            -- An array of the tokens encountered, in the order they're encountered
  --[[
    The format of tokens is:

    {
      {name=token_name, value=token value},
      {name=token_name, value=token_value},
      ...
    }
  ]]

  ---[[ Special errors for specific cases
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
  --]]

  ---[[ Because these functions have "indirect recursive definitions",
     -- they need to be declared as variables before being defined,
     -- so that they are in scope for each other in their definitions.
     -- The variable is looked up at run-time, so they can start out
     -- undefined, or nil

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

local function strip_parenthesis_group (group_string)
  if not group_string then
    print_error("No group string passed")
    return group_string
  end
  local group_string = group_string:sub(2, -2) -- Strip wrapping parenthesis
  group_string = group_string:gsub("%%([()])", "%1") -- Remove escaping % from ( and )
  return group_string
end

local function unstrip_parenthesis_group (group_string)
  if not group_string then
    print_error("No group string passed")
    return group_string
  end
  if group_string:match("%s") then
    group_string = group_string:gsub("([()])", "%%%1")
    group_string = "(" .. group_string .. ")"
  end
  return group_string
end

local function print_settings (server, channel, sound, match)
  if not server or server == "" then
    server = "()"
  end
  if not channel or channel == "" then
    channel = "()"
  end
  if not sound or sound == "" then
    sound = "()"
  end
  if not match or match == "" then
    match = "()"
  end

  local str = ([[
Server:  %s
Channel: #%s
Sound:   %s
Match:   %s

]]):format(
  server,
  channel,
  sound,
  match
)

  print_message(str)
end

local function serialize_string (str)
  if type(str) ~= "string" then
    print_error(("Cannot serialize: %s"):format(str))
    return false
  elseif #str == 0 then
    return str
  end

  local serialized = str:gsub("([%[%]])", "%%%1")
  return serialized
end

local function deserialize_string (str)
  if type(str) ~= "string" then
    print_error(("Cannot deserialize: %s"):format(str))
    return false
  elseif #str == 0 then
    return str
  end

  return str:gsub("%%([%[%]])", "%1")
end

local function retrieve_settings (server)
  local server = server or ""
  local channel = channel or ""

  local setting_name = settings_prefix .. server

  return hexchat.pluginprefs[setting_name] or ""
end

local function load_settings (server)

local function store_settings (server, channel, sound, match)
  local server = server or ""
  local channel = channel or ""
  local sound = sound or ""
  local match = match or ""

  local setting_name = settings_prefix .. server
  local setting_value = ([=[
Channel{
  name = [[%s]],
  sound = [[%s]],
  match = [[%s]]}
]=]):format(
  serialize_string(channel),
  serialize_string(sound),
  serialize_string(match))

  local current_setting_value = retrieve_settings(server, channel)

  hexchat.pluginprefs[setting_name] = current_setting_value .. setting_value

  return true
end


local function set_settings (server, channel, sound, match)
  local server = server or "()"
  server = #server < 1 and "()" or unstrip_parenthesis_group(server)
  local channel = channel or "()"
  channel = #channel < 1 and "()" or unstrip_parenthesis_group(channel)
  local sound = sound or "()"
  sound = #sound < 1 and "()" or unstrip_parenthesis_group(sound)
  local match = match or "()"
  match = #match < 1 and "()" or unstrip_parenthesis_group(match)

  print_message(([[
Set settings for: %s #%s
]]):format(server, channel))

  local exit_value = store_settings(server, channel, sound, match)
  if not exit_value then
    print_error("Error storing settings")
    print_settings(server, channel, sound, match)
    return false
  end

  print_settings(server, channel, sound, match)
  return true
end

local function get_settings (server, channel)
  local server = server or "()"
  server = #server < 1 and "()" or unstrip_parenthesis_group(server)
  local channel = channel or "()"
  channel = #channel < 1 and "()" or unstrip_parenthesis_group(channel)

  print_message(([[
Get settings for: %s #%s
]]):format(server, channel))

  local setting_value = retrieve_settings(server, channel)
  if not setting_value or setting_value == "" then
    print_message("No settings found")
    return true
  end

  local server_settings = {}

  -- NOTE: Not ideal having a global function
  function Channel (tbl) -- Has to be global for loadstring to be able to see it
    server_settings[#server_settings + 1] = tbl
  end

  local f, error_message
  f, error_message = loadstring(setting_value)

  if not f then
    print_error(("Trouble reading configuration. Error was:\n%s"):format(error_message))
    return f
  end

  f() -- Should populate server_settings

  local sound, match
  for i, channel_table in ipairs(server_settings) do
    if channel_table.name == channel then
      sound = channel_table.sound
      match = channel_table.match
      break
    end
  end

  print_settings(server, channel, sound, match) -- If no channel is found, sound and match are passed as nil
  return true
end


---[===[ Debug
local function print_tokens (tokens)
  for i=1, #tokens do
          print(([[
Token name:
%s
Token value:
%s
]]):format(tokens[i].name, tokens[i].value))
  end
end
--]===]


-- Currently no validity checking, but these could be used to check if a sound file exists, or if Lua can parse a pattern
local function is_valid_server  (server)  return true end
local function is_valid_channel (channel) return true end
local function is_valid_sound   (sound)   return true end
local function is_valid_match   (match)   return true end

local function parse (str)
  -- First thing to do is lex the string, as the parser works with tokens
  local tokens = lex(str)
  if not tokens then
    return tokens
  end

  local position = 1
  local server = ""
  local channel = ""
  local sound = ""
  local match = ""
  local action = ""
  local action_table = {}

  local function parser_error (message, index)
    local command_string = ("/%s "):format(command_name)
    local chars_up_to_error_token = #command_string

    for i=1, #tokens do
      if tokens[i].name == "hashmark" then
        command_string = command_string .. tokens[i].value
      else
        command_string = command_string .. tokens[i].value .. " "
      end
    end

    for i=1, (index - 1) do
      if tokens[i].name == "hashmark" then
        chars_up_to_error_token = chars_up_to_error_token + #tokens[i].value
      else
        chars_up_to_error_token = chars_up_to_error_token + #tokens[i].value + 1
      end
    end

    local error_message = ([[
Parser error: %s
%s
%s

]]):format(message, command_string, (" "):rep(chars_up_to_error_token) .. "^")

    print_error(error_message)
  end

  local getter_setter_action, parse_sound, parse_match, echo_action, inner_parse

  function echo_action ()
    local echo_text = ""
    for i=position, #tokens do
      echo_text = echo_text .. tokens[i].value .. " "
    end
    echo_text = echo_text:sub(1,-2) -- drop the last character, which is a space
    print_message(echo_text)
    return true
  end

  function parse_sound ()
    local token = tokens[position]
    if token.name == "parenthesis_group" then
      sound = strip_parenthesis_group(token.value)
    else
      sound = token.value
    end
    if not is_valid_sound(token.value) then
      parser_error(("Invalid sound file: %s"):format(token.value), position)
      return false
    end
    position = position + 1
    return getter_setter_action()
  end

  function parse_match ()
    local token = tokens[position]
    if token.name == "parenthesis_group" then
      match = strip_parenthesis_group(token.value)
    else
      match = token.value
    end
    if not is_valid_match(token.value) then
      parser_error(("Invalid match pattern: %s"):format(token.value), position)
      return false
    end
    position = position + 1
    return getter_setter_action()
  end

  function getter_setter_action ()
    if position > #tokens then
      --[===[ Debug
      print(([[
server: %s
channel: %s
sound: %s
match: %s
]]):format(server,channel,sound,match))
      --]===]
      if #server < 1 and #channel < 1 then
        parser_error("Found neither server nor channel name", position)
        return false
      end
      -- Autofill empty server or channel name with a pattern to match everything
      if #server < 1 then server = "(.*)" end
      if #channel < 1 then channel = "(.*)" end
      if #sound > 0 or #match > 0 then
        return set_settings(server, channel, sound, match)
      else
        return get_settings(server, channel)
      end
    end

    local token = tokens[position]
    --[===[ Debug
    print(("Token name: %s\nToken value: %s"):format(token.name, token.value))
    --]===]
    if token.name == "hashmark" then
      next_token = tokens[position + 1]
      if not next_token then
        parser_error("Expected channel name", position)
        return false
      end
      if next_token.name == "parenthesis_group" then
        channel = strip_parenthesis_group(next_token.value)
      else
        channel = next_token.value
      end
      if not is_valid_channel(channel) then
        local error_message = "Not a valid channel: %s"
        error_message = error_message:format(channel)
        parser_error(error_message, position)
        return false
      end
      position = position + 2
      return getter_setter_action()

    elseif (token.name == "text" or token.name == "parenthesis_group") and #server < 1 and #channel < 1 then
      if token.name == "parenthesis_group" then
        server = strip_parenthesis_group(token.value)
      else
        server = token.value
      end
      if not is_valid_server(server) then
        local error_message = "Not a valid server: %s"
        error_message = error_message:format(server)
        parser_error(error_message, position)
        return false
      end
      position = position + 1
      return getter_setter_action()

    elseif (token.name == "text" or token.name == "parenthesis_group") and token.value == "sound" then
      position = position + 1
      return parse_sound()

    elseif (token.name == "text" or token.name == "parenthesis_group") and token.value == "match" then
      position = position + 1
      return parse_match()

    else
      local error_message = "Unexpected %s"
      error_message = error_message:format(token.name:gsub("_", " "))
      parser_error(error_message, position)
      if #channel < 1 then
        print_error("Maybe a channel name should go there, or the channel name is missing a '#' ?")
      elseif #server > 1 and (#sound < 1 or #match < 1) then
        print_error('Maybe missing "sound" or "match"')
      end
      return false
    end

  end

  action_table["echo"] = echo_action
  action_table["getter_setter"] = getter_setter_action 

  function inner_parse ()
    if position > #tokens then
      if #action < 1 then
        parser_error("No action found")
        return false
      end
      return action_table[action]()
    end

    local token = tokens[position]
    if token.name == "action" then
      position = position + 1
      action = token.value:sub(2) -- Strip prefix /
      if not action_table[action] then
        parser_error("Not a valid action", position)
        return false
      end
      return action_table[action]()
    -- The default action is getter_setter, so if none is specified, use that
    elseif token.name == "text" or token.name == "parenthesis_group" or token.name == "hashmark" then
      -- position = position + 1 -- Don't skip over this token, because it's part of the action's parameter's
      action = "getter_setter"
      return action_table[action]()
    else
      parser_error("Could not determine action", position)
    end
  end

  

  return inner_parse()

end

---[===[ Debug
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
local function print_error (message) print(message) end
local function print_message (message) print(message) end
--]===]


function hook_command (words, word_eols)
  local exit_value = parse(word_eols[2])
  if not exit_value then
    print_error("Sorry, could not understand command")
  end
  
  return hexchat.EAT_HEXCHAT
end



-- Set the function to be called when the command is invoked, and the help text
hexchat.hook_command(command_name, hook_command, [[
DESCRIPTION

This command helps configure this plugin so that when a message is received that matches a pattern
in a specific server and/or channel, a sound is played using the HexChat /SPLAY command.

The command syntax follows this format:
/SSOUND [server name] #[channel name] sound [sound file] match [match]

The [match] is interpreted as a Lua pattern: https://www.lua.org/pil/20.2.html

Only one of [server name] and #[channel name] are required, but at least one must be given.

If any of [server name], [channel name], [sound file], or [match] have spaces, they must be wrapped in parenthesis.
Note that the channel name will have the # on the outside of the parenthesis.
If something that has parenthesis in it needs to be wrapped in parenthesis, the internal parenthesis need to be escaped with the %.

Example:

/SSOUND (my server) #(a channel) sound (H:\this sound.wav) match (:%-%%) tehee %%(%-:)

Note that in this example, the the full pattern as seen by Lua for the match is:
:%-%) tehee %(%-:

This will match any message with the following in it:
:-) tehee (-:

EXAMPLES

Play sound from D:\friend.wav when your friend's name is mentioned:
/SSOUND freenode #irc sound D:\friend.wav match friends_nick

Show all sounds set for server freenode channel #irc:
/SSOUND freenode #irc

Set the sound file to (D:\attention attention.wav) for any channel with "help" in the name, on any server:
/SSOUND #(.*help.*) sound (D:\attention attention.wav)
Note, this will not play the sound, as no match has been specified yet:
/SSOUND #(.*help.*) match (%?)
Now it will match anything with a question mark in it.

]])