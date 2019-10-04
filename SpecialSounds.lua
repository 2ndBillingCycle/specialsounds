--[[
     - Lexer                                                                        ✓
     - Parser                                                                       ✓
     - Settings Printer                                                             ✓
     - Settings Setter                                                              -
     - Settings Getter                                                              -
     - Hook function                                                                -
     - - Receive Channel Message
     - - Settings Getter on sever and channel
     - - Recurse through matches, /SPLAY-ing every match's sound
     - /show_or_add                                                                 ✗
     - - Autofills with current context
     - - /show                                                                      ✗
     - - - /showall                                                                 ✗
     - - /add                                                                       ✗
     - /delete                                                                      ✓
     - /deleteall                                                                   ✗
     - /lex                                                                         ✗
     - - Prints tokens
     - /parse                                                                       ✗
     - - Dry run with /debug on
     - /debug                                                                       ✗
     - /echo                                                                        ✗
     - on/off: echos command
     - Tab completion                                                               ✗
     - - watching for the Tab key, to autofill actions, server names, channels, etc
     - Sound file validation                                                        ✗
     - - File exists
     - - /SPLAY it so HexChat errors on bad files
     - /link                                                                        ✗
     - - Detect if not installed in plugins folder
     - - Suggest to /ssound /link to link from where it is into the plugins folder   

--]]

---[[
hexchat.register(
  "SpecialSounds",
  "5",
  "Set special sound to play on message"
)
--]]
--[[ Debug
-- Mock hexchat
local hexchat = {}
hexchat.pluginprefs = {}
hexchat.EAT_HEXCHAT = true
hexchat.EAT_NONE = true
hexchat.get_info = function (str)
  if str == "channel" then
    return "#a"
  else
    return "a"
  end
end
hexchat.get_context = function ()
  return {
    get_info = function (ctx, str)
      if str == "channel" then
        return "#a"
      else
        return "a"
      end
    end
  }
end
hexchat.strip = function (str) return str end
hexchat.command = function (str) print("hexchat.command:\n" .. str) end
hexchat.hook_command = function (a, b, c) end
hexchat.hook_print = function (str, func) return function () end end
--]]
local version = "5"

local command_name = "SSOUND"
local settings_prefix = command_name .. "_"
local hook_objects = {}
local settings = {}
local quotepattern = '(['..("%().[]*+-?"):gsub("(.)", "%%%1")..'])'
string.escape_pattern = function(str)
  str = (str:gsub(quotepattern, "%%%1")
            :gsub("^^", "%%^")
            :gsub("$$", "%%%$"))
  return str
end
string.escape_quotes = function (str)
  if type(str) ~= "string" then
    print_error("Cannot quote escape string")
    return str
  end

  if str:match('"') or str:match("%s") then
    str = '"' .. str:gsub('"', '\\"') .. '"'
  end
  return str
end

-- Neither this lexer nor parser are pretty. A very pretty one is at:
-- https://github.com/stravant/LuaMinify/blob/master/ParseLua.lua

-- Currently, no fancy printing is done
-- In the future, these could be set to make a private message, or something
local function print_error (message) print(message) end
local function print_message (message) print(message) end

---[[ Debug
local function printvars (message, tbl)
  print(message)
  for key, var in pairs(tbl) do
    print(tostring(key) .. ": " .. tostring(var))
  end
  return true
end
--]]


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
  --]]

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
  if type(server) ~= "string" or server == "" then
    server = "()"
  end
  if type(channel) ~= "string" or channel == "" then
    channel = "()"
  end
  if type(sound) ~= "string" or sound == "" then
    sound = "()"
  end
  if type(match) ~= "string" or match == "" then
    match = "()"
  end

  local str = ([[
Server:  %s
Channel: #%s
Sound:   %s
Match:   %s

]]):format(
  unstrip_parenthesis_group(server),
  unstrip_parenthesis_group(channel),
  unstrip_parenthesis_group(sound),
  unstrip_parenthesis_group(match)
)

  print_message(str)
end

local function serialize_string (str)
  if type(str) ~= "string" then
    print_error("Cannot serialize string")
    return false
  elseif #str == 0 then
    return "[[]]"
  end

  return "[[" .. str:gsub("([%[%]])", "%%%1") .. "]]"
end

local function deserialize_string (str)
  -- Must be a string, and must have at least "[[]]"
  if type(str) ~= "string" or #str < 4 or (not str:match("%[%[.-%]%]")) then
    print_error("Cannot deserialize string")
    return false
  end

  return str:sub(3,-3):gsub("%%([%[%]])", "%1")
end

local function make_settings_key (server, channel)
  if type(server) ~= "string" or type(channel) ~= "string" then
    print_error("Cannot make settings key")
    return false
  end

  return settings_prefix .. serialize_string(server) .. serialize_string(channel)
end

local function serialize_sound_match (tbl)
  if type(tbl) ~= "table" or type(tbl[1]) ~= "table" then -- NOTE: Better to check everything for validity
    print_error("Cannot serialize table")
    return false
  end

  local settings_string = ""
  for i, sound_match in ipairs(tbl) do
    settings_string = settings_string .. 
      ([[

sound = %s
match = %s
]]):format(
  serialize_string(sound_match.sound),
  serialize_string(sound_match.match)
)
  end

  return settings_string
end

local function deserialize_sound_match (sound_match_string)
  local sound_match_pattern = "sound = (%[%[.-%]%])\nmatch = (%[%[.-%]%])"
  if type(sound_match_string) ~= "string" or not sound_match_string:match(sound_match_pattern) then
    print_error("Cannot deserialize table")
    return function () return nil end
  end

  local matches = sound_match_string:gmatch(sound_match_pattern)
  return function()
    local sound, match = matches()
    if type(sound) ~= "string" or type(match) ~= "string" then
      return sound, match
    end
    return deserialize_string(sound), deserialize_string(match)
  end
end

local function retrieve_settings_value (server, channel)
  local server = server or ""
  local channel = channel or ""

  local settings_key = make_settings_key(server, channel)
  if not settings_key then return settings_key end

  if settings[settings_key] then
    return settings[settings_key]
  else
    settings[settings_key] = hexchat.pluginprefs[settings_key]
    return hexchat.pluginprefs[settings_key]
  end
end

local function retrieve_settings (server, channel)
  local server = server or ""
  local channel = channel or ""

  local settings_value = retrieve_settings_value(server, channel)
  if not settings_value then
    return function() return nil end
  end
  if type(settings_value) ~= "string" then
    print_error("Bad configuration information")
    return function() return false end
  end

  local sound_match = deserialize_sound_match(settings_value)
  local count = 0
  return function()
    local sound, match = sound_match()
    if not sound and not match and count == 0 then
      count = count + 1
      return "",""
    elseif type(sound) ~= "string" or type(match) ~= "string" then
      return nil -- Indicate iterator end
    end
    count = count + 1
    return sound, match
  end
end

local function all_servers_and_channels_settings ()
  local settings_keys = {}
  local settings_values = {}
  for key, val in pairs(hexchat.pluginprefs) do
    if key:match(settings_prefix .. "%[%[.-%]%]%[%[.-%]%]") and val:match("sound = %[%[.-%]%]\nmatch = %[%[.-%]%]") then
      settings_keys[#settings_keys + 1] = key
      settings_values[#settings_values + 1] = deserialize_sound_match(val)
    end
  end
  local key_index = 1
  local continue = false
  
  return function()
    while true do
      if key_index > #settings_keys then
        return nil
      end
      local server, channel = settings_keys[key_index]:match(
        settings_prefix .. "(%[%[.-%]%])(%[%[.-%]%])")
      if continue or type(server) ~= "string" or type(channel) ~= "string" then
        continue = true -- Skip this key, since it's malformed, but there are still more keys
      else
        server = deserialize_string(server)
        channel = deserialize_string(channel)
      end
      local sound, match
      if not continue and server and channel and type(settings_values[key_index]) == "function" then
        sound, match = settings_values[key_index]() -- We stored an iterator, so execute it
      elseif not continue then
        if settings.debug_on then
          print_error(([[
Bad settings for
server: %s
channel: %s
]]):format(tostring(server), tostring(channel)))
        end
        continue = true
      else
        continue = true
      end
      if continue or type(sound) ~= "string" then
        continue = true
      else
        return server, channel, sound, match
      end
      key_index = key_index + 1
      continue = false
    end 
  end
end

local function store_settings (server, channel, sound, match)
  local server = server or ""
  local channel = channel or ""
  local sound = sound or ""
  local match = match or ""

  local settings_key = make_settings_key(server, channel)
  if not settings_key then return settings_key end
  
  local current_settings_value = retrieve_settings_value(server, channel)

  local current_tables = {}
  local matched = false
  if type(current_settings_value) == "string" then
    for curr_sound, curr_match in deserialize_sound_match(current_settings_value) do
      if curr_match == match then
        current_tables[#current_tables + 1] = {sound=sound, match=match}
        print_message(([[
Overwriting settings:
Server: %s
Channel: #%s
Sound: %s
Match: %s
]]):format(
    unstrip_parenthesis_group(server),
    unstrip_parenthesis_group(channel),
    unstrip_parenthesis_group(sound),
    unstrip_parenthesis_group(match)))
        matched = true
      else
        current_tables[#current_tables + 1] = {sound=curr_sound, match=curr_match}
      end
    end
  end
  
  if not matched then -- Because of the local sound = sound or "", sound and match will always be strings
    current_tables[#current_tables + 1] = {sound=sound, match=match}
  end
  local settings_value = serialize_sound_match(current_tables)
  if not settings_value then
    return false
  end

  settings[settings_key] = settings_value
  hexchat.pluginprefs[settings_key] = settings_value

  return true
end

local function set_settings (server, channel, sound, match)
  local server = server or ""
  local channel = channel or ""
  local sound = sound or ""
  local match = match or ""

  if settings.debug_on then
    print_message(([[
Set settings for: %s #%s
]]):format(unstrip_parenthesis_group(server),unstrip_parenthesis_group(channel)))
  end

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
  local server = server or ""
  local channel = channel or ""

  if settings.debug_on then
    print_message(([[
Get settings for: %s #%s
]]):format(server, channel ~= "" and channel or "()"))
  end

  for sound, match in retrieve_settings(server, channel) do
    if type(sound) ~= "string" or type(match) ~= "string" then
      print_error("Malformed settings")
      return false
    end

    print_settings(server, channel, sound, match)
  end
  return true
end

local function delete_setting (server, channel, number)
  if type(server) ~= "string" or type(channel) ~= "string" or type(number) ~= "number" then
    print_error("Cannot understand delete command")
    return false
  end

  local new_sound_match_pairs = {}
  for sound, match in retrieve_settings(server, channel) do
    if #new_sound_match_pairs + 1 == number then
      -- If the item to be copied is in the same place as the item to be deleted,
      -- do nothing, so the item is never added, thereby deleting it
    if settings.debug_on then
      print_message(([[
Deleting setting:
Server: %s
Channel: %s
Number: %s
]]):format(server, channel, tostring(number)))
    end
    else
      new_sound_match_pairs[#new_sound_match_pairs + 1] = {sound=sound, match=match}
    end
  end

  if settings.debug_on then
    if #new_sound_match_pairs < 1 and not (retrieve_settings(server, channel) and retrieve_settings(server, channel)()) then
      print_message(([[
No settings found matching:
Server:  %s
Channel: %s
Number:  %s
]]):format(server, channel, tostring(number)))
    end
  end
  -- If there are any items left after deleting, serialize them into a proper string
  -- If not, leave it nil, so that when the key is set to nil, it's deleted entirely
  local new_settings_value
  if #new_sound_match_pairs > 0 then
    new_settings_value = serialize_sound_match(new_sound_match_pairs)
    if not new_settings_value then return new_settings_value end
  end
  
  local settings_key = make_settings_key(server, channel)
  if not settings_key then return settings_key end

  settings[settings_key] = new_settings_value
  hexchat.pluginprefs[settings_key] = new_settings_value

  return true
end

local function print_tokens (tokens)
  if type(tokens) ~= "table" then
    return false
  end
  for i=1, #tokens do
    print_message(([[
Token name:
%s
Token value:
%s
]]):format(tokens[i].name, tokens[i].value))
  end
  return true
end

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
  local number = false
  local action = ""
  local action_table = {}
  local function is_symbol (str)
    local symbol_types = {"text", "parenthesis_group", "number"}
    for i=1, #symbol_types do
      if str == symbol_types[i] then return true end
    end
    return false
  end
  string.is_symbol = is_symbol
  local function is_set_parameter (str)
    local set_parameters = {"sound", "match"}
    for i=1, #set_parameters do
      if str == set_parameters[i] then return true end
    end
    return false
  end
  string.is_set_parameter = is_set_parameter

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

  local sinner_parse, how_or_add_or_delete, show_action, add_action, delete_action, parse_sound, parse_match, parse_server_channel
  local autofill_server_channel, lex_action, debug_action

  function lex_action ()
    local reconstructed_command = ""
    for i=position, #tokens do
      reconstructed_command = reconstructed_command .. tokens[i].value .. " "
    end
    reconstructed_command = reconstructed_command:sub(1,-2) -- drop the last character, which is a space
    print_message(([[
Command:
%s
Tokens:
]]):format(tostring(reconstructed_command)))
    print_tokens(tokens)
    return true
  end

  function debug_action ()
    if position > #tokens then
      return true
    end

    local token = tokens[position]
    if token.name == "text" and token.value:match("^on$") then
      print_message("Extra messages turned on")
      settings.debug_on = token.value
      hexchat.pluginprefs.debug_on = token.value
      position = position + 1
      return debug_action()
    elseif token.name == "text" and token.value:match("^off$") then
      settings.debug_on = nil
      hexchat.pluginprefs.debug_on = nil
      position = position + 1
      return debug_action()
    else
      parser_error("Expected on or off:", position)
      return false
    end
  end

  function delete_action ()
    if position > #tokens then
      if #server > 0 and #channel > 0 and number ~= false then
        return delete_setting(server, channel, number)
      elseif #server > 0 or #channel > 0 then
        parser_error("Cannot determine item to delete", #tokens)
        return false
      end
    end

    local token = tokens[position]
    ---[[ Currently, we can only get here in 2 cases:
    -- 1) Called with arguments, after show_or_add_or_delete has determined the correct action
    -- 2) The /delete action was specified
    if position == #tokens and token.name == "number" then
      if token.value:match("^%d+$") and tonumber(token.value) then
        number = tonumber(token.value)

        if type(server) ~= "string" or type(channel) ~= "string" then
          print_error(([[
Something wrong with server or channel name:
Server: %s
Channel: %s
]]):format( tostring(server) , tostring(channel) ))
          return false
        end
        position = position + 1
        return delete_action()
      else
        parser_error("Cannot determine number", position)
        return false
      end
    else
      local exit_value = parse_server_channel()
      if not exit_value then return false end

      exit_value = autofill_server_channel()
      if not exit_value then return false end

      return delete_action()
    end
  end

  function parse_sound ()
    local token = tokens[position]
    if token.name == "parenthesis_group" then
      sound = strip_parenthesis_group(token.value)
    else
      sound = token.value
    end
    if not is_valid_sound(sound) then
      parser_error(("Invalid sound file: %s"):format(token.value), position)
      return false
    end
    position = position + 1
    return show_or_add_or_delete()
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
    return show_or_add_or_delete()
  end

  function parse_server_channel ()
    if position > #tokens or #server > 0 or #channel > 0 then
      local token = tokens[position]
      if type(token) == "table" and token.name == "hashmark" then
        -- Do nothing, thereby continuing
      else
        return true
      end
    end

    local token = tokens[position]
    if token.name == "hashmark" then
      local next_token = tokens[position + 1]
      if type(next_token) ~= "table" or not next_token.name:is_symbol() then
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
      return parse_server_channel()

    elseif token.name:is_symbol() and #server < 1 and #channel < 1 then
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
      return parse_server_channel() 
    end
  end

  function autofill_server_channel ()
    if #server < 1 then
      server = hexchat.get_info("server")
      if type(server) ~= "string" then
        print_error("Cannot get name of current server\nMay have to specify server and channel name")
        return false
      end
    end
    if #channel < 1 then
      channel = hexchat.get_info("channel")
      if type(channel) ~= "string" then
        print_error("Cannot get name of current channel\nMay have to specify server and channel name")
        return false
      end
      channel = channel:sub(2) -- Drop # from channel name
    end
    return true
  end

  

  action_table["lex"] = lex_action
  action_table["debug"] = debug_action
  action_table["delete"] = delete_action
  action_table["show_or_add_or_delete"] = show_or_add_or_delete 

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
      action = token.value:sub(2) -- Strip prefix /
      if not action_table[action] then
        parser_error("Not a valid action", position)
        return false
      end
      position = position + 1
      return action_table[action]()
    -- The default action is show_or_add_or_delete, so if none is specified, use that
    elseif token.name:is_symbol() or token.name == "hashmark" then
      -- position = position + 1 -- Don't skip over this token, because it's part of the action's parameter's
      action = "show_or_add_or_delete"
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
  
  return hexchat.EAT_ALL
end

local function search_settings (server, channel)
  if type(server) ~= "string" or type(channel) ~= "string" then
    return function () return nil end
  end

  local valid = {}
  for key, val in pairs(settings) do
    if key:match(settings_prefix .. "%[%[.-%]%]%[%[.-%]%]") and
       val:match("sound = %[%[.-%]%]\nmatch = %[%[.-%]%]") then
      valid[#valid + 1] = {key=key,val=val}
    end
  end

  local keys_processed = {}
  for i, tbl in ipairs(valid) do
    local _server, _channel = tbl.key:match("(%[%[.-%]%])(%[%[.-%]%])")
    keys_processed[#keys_processed + 1] = {
      server = deserialize_string(_server),
      channel = deserialize_string(_channel),
      sound_match = deserialize_sound_match(tbl.val)
    }
  end

  if #keys_processed < 1 then
    return function () return nil end
  end

  local key_index = 1
  return function ()
    while true do
      if key_index > #keys_processed then
        return nil, nil
      end
      local _server = keys_processed[key_index].server
      local _channel = keys_processed[key_index].channel
      if server:match(_server) and channel:match(_channel) then
        local sound, match = keys_processed[key_index].sound_match()
        if type(sound) == "string" and type(match) == "string" then
          key_index = key_index + 1
          return _server, _channel, sound, match
        end
      end
      key_index = key_index + 1
    end
  end
end

local function splay_on_matching_channel_message()
  return function (tbl)
    if type(tbl) ~= "table" then
      print_error("Error in text event handler")
      return hexchat.EAT_NONE
    end

    local ctx = hexchat.get_context()
    server = ctx:get_info("server")
    channel = ctx:get_info("channel")
    if channel:sub(1,1) == "#" then
      channel = channel:sub(2,-1)
    end

    local message = hexchat.strip(tbl[2])
    for server, channel, sound, match in search_settings(server, channel) do
      local first_group = message:match(match)
      if type(first_group) == "string" and first_group ~= "" and sound ~= "" then
        sound = sound:escape_quotes()
        if settings.debug_on then
          print_message("playing sound file: " .. tostring(sound))
        end
        hexchat.command("splay " .. sound)
        return hexchat.EAT_NONE
      end
    end
  end
end

local function setup ()
  if not hexchat.pluginprefs.version then
    hexchat.pluginprefs.version = version
  elseif tonumber(hexchat.pluginprefs.version) > tonumber(version) then
    print_message("The stored settings may be in a newer format than this version of the plugin:")
    print_message("Plugin version:   " .. tostring(version))
    print_message("Settings version: " .. tostring(hexchat.pluginprefs.version))
  else
    -- No releases yet, so no need to support data migration
  end
  for key, val in pairs(hexchat.pluginprefs) do
    settings[key] = val
  end
  if settings.debug_on then
    print_message("Current settings:")
  end
  for server, channel, sound, match in all_servers_and_channels_settings() do
    -- Calling this function forces the retrieval of all currently valid settings, and puts those in cache
    if settings.debug_on then
      print_settings(server, channel, sound, match)
    end
  end

  -- Unhook and delete all active hooks on reload
  for i, val in ipairs(hook_objects) do
    val:unhook()
    hook_objects[i] = nil
  end

  hook_objects[#hook_objects + 1] = hexchat.hook_print("Channel Message", splay_on_matching_channel_message())
end

setup()

-- Set the function to be called when the command is invoked, and the help text
hook_objects[#hook_objects + 1] = hexchat.hook_command(command_name, hook_command, [[
Pleays special sound on special message

DESCRIPTION

This command helps configure this plugin so that when a message is received that matches a pattern
in a specific server and/or channel, a sound is played using the HexChat /SPLAY command.

The command syntax follows this format:
/SSOUND [server name] #[channel name] sound [sound file] match [match]

If any of [server name], #[channel name], [sound file], or [match] have spaces, they must be wrapped in parenthesis.

Note that the channel name will have the # on the outside of the parenthesis.

If something that has parenthesis in it needs to be wrapped in parenthesis, the internal parenthesis need to have % added before each ( and ).

The [server name], #[channel name], and [match] are interpreted as a Lua patterns: https://www.lua.org/pil/20.2.html

If [server name] or #[channel name] are left out, they'll be filled in using the server and channel the command is typed into.

Lastly, if a [server name] needs to begin with a / then the whole name, including the / must be wrapped in parenthesis:
(/ServerName)

EXAMPLES

/SSOUND (/my server) #(a channel) sound (H:\this sound.wav) match (:%-%%) tehee %%(%-:)

  Note that in this example, the the full pattern as seen by Lua for the match is:
  :%-%) tehee %(%-:

  This will match any message with the following in it:
  :-) tehee (-:

/SSOUND freenode #irc sound D:\friend.wav match friends_nick

  Plays sound from D:\friend.wav when your friend's name is mentioned

/SSOUND freenode #irc

  Shows all sounds set for server freenode channel #irc

/SSOUND #(.*help.*) sound (D:\attention attention.wav)

  Sets the sound file to (D:\attention attention.wav) for any channel with "help" in the name, on any server

  Note, this will not play the sound, as no match has been specified yet:
  
/SSOUND #(.*help.*) match (%?)

  Now it will match anything with a question mark in it

]])