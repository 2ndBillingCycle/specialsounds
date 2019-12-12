--[[
Refactoring:
     - Lexer                                                                        ✗
     - Parser                                                                       ✗
     - Settings Printer                                                             ✗
     - Settings Setter                                                              ✗
     - Settings Getter                                                              ✗
     - Hook function                                                                ✗
     - - Receive Channel Message
     - - Settings Getter on sever and channel
     - - Recurse through matches, /SPLAY-ing every match's sound
     - /show_or_add_or_delete                                                       ✗
     - - Autofills with current context
     - - /show                                                                      ✗
     - - - /showall                                                                 ✗
     - - /add                                                                       ✗
     - /delete                                                                      ✗
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
     - - Write a custom WAV parser                                                  ✗
     - /link                                                                        ✗
     - - Detect if not installed in plugins folder
     - - Suggest to /ssound /link to link from where it is into the plugins folder   
     - /patterns                                                                    ✗
     - - on/off treat server, channel, match as patterns or not                      


The are a few things I want to improve:

 - The message for invalid sound files is only printed once, but it's still         ✗
   validated every time. Maybe a cache on is_valid_sound()


--]]


-- Currently, no fancy printing is done
-- In the future, these could be set to make a private message, or something
-- NOTE: These could help to wrap missing hexchat functionality when debugging the module
-- directly in the interpreter
local function print_error (message)
  if type(message) ~= "string" then
    error("Bad string for print_error")
  end
  print(message .. "\n\n")
end
local function print_message (message)
  if type(message) ~= "string" then
    error("Bad string for print_message")
  end
  print(message .. "\n\n")
end

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

---[==[ Debug
-- Mock hexchat
if not hexchat then
    hexchat = {}
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
end

local function printvars (message, tbl)
  print(message)
  for key, var in pairs(tbl) do
    print(tostring(key) .. ": " .. tostring(var))
  end
  return true
end

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
  if hexchat then return hexchat.EAT_HEXCHAT end
end

--]==]

---[[ Add HexChat's ./config/addons directory to package.path
package.path = ".\\config\\addons\\?.lua;" .. package.path
local lexer = require "lexer"

local function strip_parenthesis_group (group_string)
  if not group_string then
    print_error("No group string passed")
    return group_string
  end
  local group_string = group_string:sub(2, -2) -- Strip wrapping parenthesis
  return group_string
end

local function unstrip_parenthesis_group (group_string)
  if type(group_string) ~= "string" then
    print_error("No group string passed")
    return group_string
  end
  -- If the string has spaces in it, or if it's literally "match" or "sound", then wrap and escape it
  if group_string:match("%s") or group_string:match("^sound$") or group_string:match("^match$") then
    group_string = "(" .. group_string .. ")"
  end
  return group_string
end

local function print_settings (server, channel, sound, match, number)
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
  if type(number) ~= "number" then
    number = nil
  end

  local str = ([[
Server:  %s
Channel: #%s
Sound:   %s
Match:   %s]]):format(

  unstrip_parenthesis_group(server),
  unstrip_parenthesis_group(channel),
  unstrip_parenthesis_group(sound),
  unstrip_parenthesis_group(match)
)
  
  if number then
    str = str .. ("\nNumber:  %s"):format( tostring(number) )
  end

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

local function match_settings (server, channel)
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
      sound_match = {}
    }
    for sound, match in deserialize_sound_match(tbl.val) do
      if type(sound) == "string" and type(match) == "string" then
        local slen = #keys_processed[#keys_processed].sound_match
        keys_processed[#keys_processed].sound_match[slen + 1] = {
          sound = sound,
          match = match
        }
      end
    end
  end

  --[=[ Debug
  for i, tbl in ipairs(keys_processed) do
    print(([[
server = %s
channel = %s
sound_match:
]]):format(tbl.server, tbl.channel))
    for i, stbl in ipairs(tbl.sound_match) do
      print(([[
sound = %s
match = %s
]]):format(stbl.sound, stbl.match))
    end
  end
  --]=]

  if #keys_processed < 1 then
    return function () return nil end
  end

  local key_index = 1
  local sound_match_index = 1
  return function ()
    while true do
      if key_index > #keys_processed then
        return nil, nil, nil, nil
      end
      if sound_match_index > #keys_processed[key_index].sound_match then
        key_index = key_index + 1
        sound_match_index = 1
      else
        local _server = keys_processed[key_index].server
        local _channel = keys_processed[key_index].channel
        if server:match(_server) and channel:match(_channel) then
          local sound_match = keys_processed[key_index].sound_match[sound_match_index]
          local sound = sound_match.sound
          local match = sound_match.match
          if type(sound) == "string" and type(match) == "string" then
            sound_match_index = sound_match_index + 1
            return _server, _channel, sound, match
          end
        end
        sound_match_index = sound_match_index + 1
      end
    end
  end
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
      sound_match = {}
    }
    for sound, match in deserialize_sound_match(tbl.val) do
      if type(sound) == "string" and type(match) == "string" then
        local slen = #keys_processed[#keys_processed].sound_match
        keys_processed[#keys_processed].sound_match[slen + 1] = {
          sound = sound,
          match = match
        }
      end
    end
  end

  --[=[ Debug
  for i, tbl in ipairs(keys_processed) do
    print(([[
server = %s
channel = %s
sound_match:
]]):format(tbl.server, tbl.channel))
    for i, stbl in ipairs(tbl.sound_match) do
      print(([[
sound = %s
match = %s
]]):format(stbl.sound, stbl.match))
    end
  end
  --]=]

  if #keys_processed < 1 then
    return function () return nil end
  end

  local key_index = 1
  local sound_match_index = 1
  return function ()
    while true do
      if key_index > #keys_processed then
        return nil, nil, nil, nil
      end
      if sound_match_index > #keys_processed[key_index].sound_match then
        key_index = key_index + 1
        sound_match_index = 1
      else
        local _server = keys_processed[key_index].server
        local _channel = keys_processed[key_index].channel
        if _server:match(server) and _channel:match(channel) then
          local sound_match = keys_processed[key_index].sound_match[sound_match_index]
          local sound = sound_match.sound
          local match = sound_match.match
          if type(sound) == "string" and type(match) == "string" then
            sound_match_index = sound_match_index + 1
            return _server, _channel, sound, match
          end
        end
        sound_match_index = sound_match_index + 1
      end
    end
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
channel: %s]]):format(tostring(server), tostring(channel)))
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
      -- If we only have a sound, and an entry only has a match, add our sound to its blank sound, and visa versa
      -- If our sound or match matches and entry's that's also missing something, fill in the missing one with ours
      if curr_sound == "" and  #sound > 0 and (curr_match == match or match == "") then
        -- If they're missing a sound, and we have a sound,
        -- and either our pattern matches their pattern or we don't have a patter
        matched = true
        current_tables[#current_tables + 1] = {sound=sound, match=curr_match}
        print_message(([[
Overwriting settings with:
Server: %s
Channel: #%s
Sound: %s
Match: %s]]):format(
    unstrip_parenthesis_group(server),
    unstrip_parenthesis_group(channel),
    unstrip_parenthesis_group(sound),
    unstrip_parenthesis_group(curr_match)))
      elseif curr_match == "" and #match > 0 and (curr_sound == sound or sound == "") then
        matched = true
        current_tables[#current_tables + 1] = {sound=curr_sound, match=match}
        print_message(([[
Overwriting settings with:
Server: %s
Channel: #%s
Sound: %s
Match: %s]]):format(
    unstrip_parenthesis_group(server),
    unstrip_parenthesis_group(channel),
    unstrip_parenthesis_group(curr_sound),
    unstrip_parenthesis_group(match)))
      else
        current_tables[#current_tables + 1] = {sound=curr_sound, match=curr_match}
      end
    end
  end
  
  -- If nothing matches, add an entry
  if not matched then -- Because of the local sound = sound or "", sound and match will always be strings,
                      -- so no need to ttype check
    current_tables[#current_tables + 1] = {sound=sound, match=match}
  end
  local settings_value = serialize_sound_match(current_tables)
  if not settings_value then
    return false
  end

  settings[settings_key] = settings_value
  hexchat.pluginprefs[settings_key] = settings_value

  if matched then
    return "overwritten"
  end
  return true
end

local function set_settings (server, channel, sound, match)
  local server = server or ""
  local channel = channel or ""
  local sound = sound or ""
  local match = match or ""

  if settings.debug_on then
    print_message(("Set settings for: %s #%s"):format(
      unstrip_parenthesis_group(server),
      unstrip_parenthesis_group(channel)
    ))
  end

  local exit_value = store_settings(server, channel, sound, match)
  if not exit_value then
    print_error("Error storing settings")
    print_settings(server, channel, sound, match)
    return false
  end

  if exit_value ~= "overwritten" then
    print_settings(server, channel, sound, match)
  end
  return true
end

local function get_settings (server, channel)
  local server = server or ""
  local channel = channel or ""

  if settings.debug_on then
    print_message(("Get settings for: %s #%s"):format(
      server ~= "" and server or "()",
      channel ~= "" and channel or "()"
    ))
  end

  local index = 1
  for _server, _channel, sound, match in search_settings(server, channel) do
    if type(server) ~= "string" or type(channel) ~= "string" or
       type(sound)  ~= "string" or type(match)   ~= "string"    then
      print_error("Malformed settings")
      return false
    end

    print_settings(_server, _channel, sound, match, index)
    index = index + 1
  end
  return true
end

local function delete_setting (server, channel, number)
  if type(server) ~= "string" or type(channel) ~= "string" or type(number) ~= "number" then
    print_error("Cannot understand delete command")
    return false
  end

  local error_message = ([[
No settings found matching:
Server:  %s
Channel: #%s
Number:  %s]]):format(
  unstrip_parenthesis_group(server),
  unstrip_parenthesis_group(channel),
  tostring(number)
  )

  local index = 1
  local matched = false
  local matching_server
  local matching_channel
  local matching_sound
  local matching_match
  for _server, _channel, sound, match in search_settings(server, channel) do
    if type(_server) == "string" and
       type(_channel) == "string" and
       type(sound) == "string" and
       type(match) == "string" and
       index == number then
      matching_server = _server
      matching_channel = _channel
      matching_sound = sound
      matching_match = match
      matched = true
    end
    index = index + 1
  end

  if not matched then
    print_message(error_message)
    return false
  end

  local new_sound_match_pairs = {}
  matched = false
  for sound, match in retrieve_settings(matching_server, matching_channel) do
    if sound == matching_sound and match == matching_match and not matched then
      matched = true
      -- If the item to be copied has all the same properties as the item to be deleted,
      -- do nothing, so the item is never added, thereby deleting it
      -- Only do this once, though
      if settings.debug_on then
        print_message(([[
Deleting setting:
Server:  %s
Channel: #%s
Sound:   %s
Match:   %s
Number:  %s]]):format(
  unstrip_parenthesis_group(matching_server),
  unstrip_parenthesis_group(matching_channel),
  unstrip_parenthesis_group(sound),
  unstrip_parenthesis_group(match),
  tostring(number)
))
      end
    else
      new_sound_match_pairs[#new_sound_match_pairs + 1] = {sound=sound, match=match}
    end
  end

  if not matched then
    print_message(error_message)
    return false
  end
  
  -- If there are any items left after deleting, serialize them into a proper string
  -- If not, leave it nil, so that when the key is set to nil, it's deleted entirely
  local new_settings_value
  if #new_sound_match_pairs > 0 then
    new_settings_value = serialize_sound_match(new_sound_match_pairs)
    if not new_settings_value then return new_settings_value end
  end
  
  local settings_key = make_settings_key(matching_server, matching_channel)
  if not settings_key then return settings_key end

  settings[settings_key] = new_settings_value
  hexchat.pluginprefs[settings_key] = new_settings_value

  return true
end

local function delete_all_settings ()
  local settings_keys = {}
  for key, val in pairs(hexchat.pluginprefs) do
    if key:match(settings_prefix .. "%[%[.-%]%]%[%[.-%]%]") and val:match("sound = %[%[.-%]%]\nmatch = %[%[.-%]%]") then
      settings_keys[#settings_keys + 1] = key
    end
  end
  if settings.debug_on and #settings_keys > 0 then
    print_message("Deleting all settings")
  elseif #settings_keys < 1 then
    print_message("No settings to delete")
    return true
  end
  for _, item in ipairs(settings_keys) do
    settings[item] = nil
    hexchat.pluginprefs[item] = nil
  end
  return true
end

local function print_tokens (tokens)
  if type(tokens) ~= "table" then
    return false
  end
  for i=1, #tokens do
    print_message(([[
Token %s name:
%s
Token %s value:
%s]]):format(tostring(i), tokens[i].name, tostring(i), tokens[i].value))
  end
  return true
end

-- Currently hardly any validity checking, but these could be used to check if a sound file exists, or if Lua can parse a pattern
local function is_valid_server  (server)  return true end
local function is_valid_channel (channel) return true end
local function is_valid_sound (sound)
  if type(sound) ~= "string" then
    print_error(("Not a filename: %s"):format(tostring(sound)))
    return false
  end

  local file, file_error = io.open(sound, "rb")
  if file == nil then
    print_error(file_error)
    return false
  elseif not file:read(0) then
    print_error(("Empty file: %s"):format(sound))
    return false
  end

  if settings.debug_on then
    print_message(([[
 Testing sound file: %s
 If nothing is heard, try the following command to test if HexChat can play the file:
 /SPLAY %s]]):format(sound, sound:escape_quotes()))
  end

  print(hexchat.command("splay " .. sound:escape_quotes()))
  return true
end
local function is_valid_match   (match)   return true end

local function parse (str)
  -- First thing to do is lex the string, as the parser works with tokens
  local tokens = lexer.lex(str)
  if not tokens then
    return tokens
  end

  local position = 1
  local server = ""
  local channel = ""
  local sound = ""
  local match = ""
  local number = false
  local debug_setting = false
  local echo_setting = false
  local parse_setting = false
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
    if index > #tokens then
      index = #tokens
    else
      index = index - 1
    end
    local command_string = ("/%s "):format(command_name)
    local chars_up_to_error_token = #command_string

    for i=1, #tokens do
      if tokens[i].name == "hashmark" then
        command_string = command_string .. tokens[i].value
      else
        command_string = command_string .. tokens[i].value .. " "
      end
    end

    for i=1, index do
      if tokens[i].name == "hashmark" then
        chars_up_to_error_token = chars_up_to_error_token + #tokens[i].value
      else
        chars_up_to_error_token = chars_up_to_error_token + #tokens[i].value + 1
      end
    end

    local error_message = ([[
Parser error: %s
%s
%s]]):format(message, command_string, (" "):rep(chars_up_to_error_token) .. "^")

    print_error(error_message)
  end

  local sinner_parse, how_or_add_or_delete, show_action, add_action, delete_action, parse_sound, parse_match, parse_server_channel
  local autofill_server_channel, lex_action, debug_action, echo_action, parse_action, add_action, show_action, help_action
  local deleteall_action, showall_action

  function help_action ()
    print_message([[
DESCRIPTION

This command helps configure this plugin so that when a message is received that matches a pattern in a specific server and/or channel, a sound is played using the HexChat /SPLAY command.

The command syntax follows this format:

/SSOUND [server name] #[channel name] sound [sound file] match [pattern]

If any of [server name], #[channel name], [sound file], or [pattern] have spaces, they must be wrapped in parenthesis.

Note that the channel name will have the # on the outside of the parenthesis.

If something that has parenthesis in it needs to be wrapped in parenthesis, the internal parenthesis need to have % added before each ( and ).

If [server name] or [channel name] are left out, they'll be filled in using the server and channel the command is typed into.

Because of this, if a server is named "match" or "sound", it must be wrapped in parenthesis when typed in a command. Because channel names
always start with a # they are exempt from this rule:

/SSOUND (match) #sound sound H:\sound.wav match (word)

Also, if a [server name] needs to begin with a / then the whole name, including the / must be wrapped in parenthesis. Again, channels are unaffected:

/SSOUND (/Server Name) #/channel

The [pattern] can be a word, or a phrase, and will match any message that contains that exact word or phrase, letter for letter.

The [pattern] is case-sensitive.

The [server name] and #[channel name] are also treated this way, so a channel name of #a whill match any channel that has "a" in the name.

To be more precise, the [server name], #[channel name], and [match] are interpreted as Lua patterns: https://www.lua.org/pil/20.2.html

With two servers named "server" and "awesome server", the name (server) will match both.

Specifying (^server$) will match exactly "server" and nothing else.

Be warned when using anchors, as this plugin uses the hostname of the server the Channel Message is received from, and not the name that is
in the HexChat Network List.

Eliding the server and/or channel and issuing the command from the channel where this plugin should watch for a [pattern] should suffice.

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

  Sets the sound file to (D:\attention attention.wav) for any channel with "help" in the name, on the server the command was typed in to.

  Note, this will not play the sound, as no match has been specified yet:
  
/SSOUND #(.*help.*) match (%?)

  Now it will match anything with a question mark in it


]])
    return true
  end

  function lex_action ()
    local reconstructed_command = ""
    for i=position, #tokens do
      reconstructed_command = reconstructed_command .. tokens[i].value .. " "
    end
    reconstructed_command = reconstructed_command:sub(1,-2) -- drop the last character, which is a space
    print_message(([[
Command:
%s
Tokens:]]):format(tostring(reconstructed_command)))
    print_tokens(tokens)
    return true
  end

  function debug_action ()
    if position > #tokens then
      if debug_setting then
        print_message("Extra messages turned on")
        if parse_setting then
          parse_setting = false
          settings.debug_on = hexchat.pluginprefs.debug_on
          print_message("Parse: Turned debug on")
          return true
        else
          settings.debug_on = "on"
          hexchat.pluginprefs.debug_on = "on"
        end
      else
        if parse_setting then
          parse_setting = false
          settings.debug_on = hexchat.pluginprefs.debug_on
          print_message("Parse: Turned debug off")
          return true
        else
          settings.debug_on = nil
          hexchat.pluginprefs.debug_on = nil
        end
      end
      return true
    end

    local token = tokens[position]
    if token.name == "text" and token.value:match("^on$") then
      debug_setting = true
      position = position + 1
      return debug_action()
    elseif token.name == "text" and token.value:match("^off$") then
      debug_setting = false
      position = position + 1
      return debug_action()
    else
      parser_error("Expected on or off:", position)
      return false
    end
  end

  function echo_action ()
    if position > #tokens then
      if echo_setting then
        if settings.debug_on then
          print_message("Commands will be echoed")
        end
        if parse_setting then
          parse_setting = false
          settings.debug_on = hexchat.pluginprefs.debug_on
          print_message("Parse: Turned echo on")
          return true
        else
          settings.echo_on = "on"
          hexchat.pluginprefs.echo_on = "on"
        end
      else
        if settings.debug_on then
          print_message("Commands will no longer be echoed")
        end
        if parse_setting then
          parse_setting = false
          settings.debug_on = hexchat.pluginprefs.debug_on
          print_message("Turned echo off")
          return true
        else
          settings.echo_on = nil
          hexchat.pluginprefs.echo_on = nil
        end
      end
      return true
    end

    local token = tokens[position]
    if token.name == "text" and token.value:match("^on$") then
      echo_setting = true
      position = position + 1
      return echo_action()
    elseif token.name == "text" and token.value:match("^off$") then
      echo_setting = false
      position = position + 1
      return echo_action()
    else
      parser_error("Expected on or off:", position)
      return false
    end
  end

  -- NOTE: Doesn't reset debug_on when a function fails parsing, or errors out
  function parse_action ()
    parse_setting = true
    settings.debug_on = "on"
    return inner_parse()
  end

  function delete_action ()
    if position > #tokens then
      if #server > 0 and #channel > 0 and number ~= false then
        if parse_setting then
          parse_setting = false
          settings.debug_on = hexchat.pluginprefs.debug_on
          print_message(([[
Parse: Deleted setting
Server: %s
Channel: #%s
Number: %s]]):format(
  unstrip_parenthesis_group(server),
  unstrip_parenthesis_group(channel),
  tostring(number)
))
          return true
        else
          return delete_setting(server, channel, number)
        end
      elseif #server > 0 or #channel > 0 then
        parser_error("Cannot determine item to delete", position)
        return false
      else
        parser_error("Ambiguous command", position)
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
Channel: %s]]):format( tostring(server) , tostring(channel) ))
          return false
        end

        position = position + 1
        local exit_value = autofill_server_channel()
        if not exit_value then return exit_value end
        return delete_action()
      else
        parser_error("Cannot determine number", position)
        return false
      end

    elseif (#server < 1 and token.name ~= "hashmark") or (#channel < 1 and token.name == "hashmark") then
      local exit_value = parse_server_channel()
      if not exit_value then return false end

      exit_value = autofill_server_channel()
      if not exit_value then return false end

      return delete_action()
    else
      local error_message = "Unexpected %s"
      error_message = error_message:format(token.name:gsub("_", " "))
      parser_error(error_message, position)
      return false
    end
  end

  function deleteall_action ()
    if position > #tokens then
      if parse_setting then
        parse_setting = false
        settings.debug_on = hexchat.pluginprefs.debug_on
        print_message("Parse: Deleteing all settings")
        return true
      else
        return delete_all_settings()
      end
    else
      parser_error("/deleteall takes no arguments; unexpected text", position)
      return false
    end
  end

  function parse_sound ()
    if position > #tokens then
      parser_error("Expected sound file", position)
      return false
    end
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
    if settings.debug_on then
      print_message("Sound file: " .. sound)
    end
    position = position + 1
    return true
  end

  function parse_match ()
    if position > #tokens then
      parser_error("Expected match pattern", position)
      return false
    end
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
    if settings.debug_on then
      print_message("Match pattern: " .. match)
    end
    position = position + 1
    return true
  end

  function add_action ()
    if position > #tokens then
      if #server < 1 or #channel < 1 then
        local exit_value = autofill_server_channel()
        if not exit_value then return exit_value end
      end

      if #sound < 1 and #match < 1 then
        parser_error("Neither sound nor match were given", position)
        return false
      end

      if parse_setting then
        parse_setting = false
        settings.deubg_on = hexchat.pluginprefs.debug_on
        print_message(([[
Adding settings:
Server:  %s
Channel: #%s
Sound:   %s
Match:   %s]]):format(
  unstrip_parenthesis_group(server),
  unstrip_parenthesis_group(channel),
  unstrip_parenthesis_group(sound),
  unstrip_parenthesis_group(match)
))
        return true
      else
        return set_settings(server, channel, sound, match)
      end
    end

    local token = tokens[position]
    if #sound < 1 and token.name == "text" and token.value == "sound" then
      position = position + 1
      local exit_value = parse_sound()
      if not exit_value then return exit_value end
      return add_action()

    elseif #match < 1 and token.name == "text" and token.value == "match" then
      position = position + 1
      local exit_value = parse_match()
      if not exit_value then return exit_value end
      return add_action()

    elseif #sound < 1 and #match < 1 and
           ((#server < 1 and token.name ~= "hashmark") or (#channel < 1 and token.name == "hashmark")) then
      local exit_value = parse_server_channel()
      if not exit_value then return exit_value end
      return add_action()

    else
      local error_message = "Unexpected %s"
      error_message = error_message:format(token.name:gsub("_", " "))
      parser_error(error_message, position)
      return false
    end
  end

  function show_action ()
    if position > #tokens then
      if #server < 1 or #channel < 1 then
        local exit_value = autofill_server_channel()
        if not exit_value then return exit_value end
      end

      if parse_setting then
        parse_setting = false
        settings.deubg_on = hexchat.pluginprefs.debug_on
        print_message(([[
Showing settings:
Server:  %s
Channel: #%s]]):format(
  unstrip_parenthesis_group(server), 
  unstrip_parenthesis_group(channel)
))
        return true
      else
        return get_settings(server, channel)
      end
    end

    local token = tokens[position]
    if (#server < 1 and token.name ~= "hashmark") or (#channel < 1 and token.name == "hashmark") then
      local exit_value = parse_server_channel()
      if not exit_value then return exit_value end
      return show_action()

    else
      local error_message = "Unexpected %s"
      error_message = error_message:format(token.name:gsub("_", " "))
      parser_error(error_message, position)
      return false
    end
  end

  function showall_action ()
    if position > #tokens then
      if parse_setting then
        parse_setting = false
        settings.debug_on = hexchat.pluginprefs.debug_on
        print_message("Parse: Showing all settings")
        return true
      else
        server = ".*"
        channel = ".*"
        return show_action()
      end
    else
      parser_error("/showall takes no arguments; unexpected text", position)
      return false
    end
  end

  function parse_server_channel ()
    if position > #tokens or #server > 0 or #channel > 0 then
      local token = tokens[position]
      if #channel < 1 and type(token) == "table" and token.name == "hashmark" then
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
      if channel:sub(1,1) == '#' then
        channel = channel:sub(2) -- Drop # from channel name
      end
    end
    return true
  end

  function show_or_add_or_delete ()
    if position > #tokens then
      if #sound < 1 and #match < 1 then
        return show_action()
      else
        parser_error("Ambiguous command. Please report the command that caused this error.")
        return false
      end
    end

    local token = tokens[position]
    if position == #tokens and token.name == "number" and #sound < 1 and #match < 1 then
      return delete_action()

    elseif token.name == "text" and ((#sound < 1 and token.value == "sound") or (#match < 1 and token.value == "match")) then
      return add_action()

    elseif #sound < 1 and #match < 1 and
           ((#server < 1 and token.name ~= "hashmark") or (#channel < 1 and token.name == "hashmark")) then 
            
      local exit_value = parse_server_channel()
      if not exit_value then return exit_value end

      exit_value = autofill_server_channel()
      if not exit_value then return false end
      
      return show_or_add_or_delete()
    else
      parser_error("Unexpected " .. token.name:gsub("_", " "), position)
      return false
    end
  end

  

  action_table["help"] = help_action
  action_table["lex"] = lex_action
  action_table["debug"] = debug_action
  action_table["echo"] = echo_action
  action_table["parse"] = parse_action
  action_table["delete"] = delete_action
  action_table["deleteall"] = deleteall_action
  action_table["add"] = add_action
  action_table["show"] = show_action
  action_table["showall"] = showall_action
  action_table["show_or_add_or_delete"] = show_or_add_or_delete

  local function default_action ()
    action = "show_or_add_or_delete"
    return action_table[action]()
  end

  function inner_parse ()
    if position > #tokens then
      if #action < 1 then
        return default_action()
      end
      print_error("Nothing left to parse")
      return true
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
      return default_action()
    else
      parser_error("Could not determine action", position)
    end
  end

  return inner_parse()

end




function hook_command (words, word_eols)
  if type(word_eols[1]) ~= "nil" and settings.echo_on then
    print_message("/" .. tostring(word_eols[1]))
  end
  local exit_value = parse(word_eols[2])
  if not exit_value then
    print_error("Sorry, could not understand command")
  end
  
  return hexchat.EAT_ALL
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
    for server, channel, sound, match in match_settings(server, channel) do
      if match ~= "" then -- "" will match anything
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
end

local function setup ()
  local header = require "header"
  if not hexchat.pluginprefs.version then
    hexchat.pluginprefs.version = header.version
  elseif tonumber(hexchat.pluginprefs.version) > tonumber(header.version) then
    print_message("The stored settings may be in a newer format than this version of the plugin:")
    print_message("Plugin version:   " .. tostring(header.version))
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
  -- Set the function to be called when the command is invoked, and the help text
  hook_objects[#hook_objects + 1] = hexchat.hook_command(command_name, hook_command,
    "Usage: SSOUND [server] #[channel] sound [sound file] match [pattern], Plays a sound when a Channel Message matches a pattern"
  )

  --local lgi = require "lgi"
end

setup()
