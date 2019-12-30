local rock = {}
-- Import header
local header = require "header"

rock.member = function (var, tbl)
  -- Checks if var is an element of array tbl
  if type(tbl) ~= "table" then error("tbl not table") end
  for i,val in ipairs(tbl) do
    if val == var then return true end
  end
  return false
end

rock.to_string = function (var, cur_str, seen_tables)
  if not cur_str then cur_str = "" end
  if not seen_tables then seen_tables = {} end
  if not var then return "nil"
  elseif type(var) ~= "table" then return tostring(var)
  end
  
  local array = {}
  local maxn = table.maxn(var)
  local dict = {}
  for key, value in pairs(var) do
    if type(key) == "number" and tostring(key):match("^%d+$") then
      array[#array + 1] = key
    else
      dict[#dict + 1] = key
    end
  end
  table.sort(array)
  for i=1,maxn do
    if i ~= array[i] then
      table.insert(array, i, "nil")
    end
  end
  cur_str = cur_str.."{ "
  for i,key in ipairs(array) do
    if type(var[key]) == "table" and not rock.member(var[key], seen_tables) then
      table.insert(seen_tables, var[key])
      cur_str = rock.to_string(var[key], cur_str, seen_tables)
    elseif type(var[key]) == "table" then
      cur_str = cur_str..tostring(var[key]).." (seen), "
    else
      cur_str = cur_str..tostring(var[key])..", "
    end
  end
  for i,val in ipairs(dict) do
    local val_str = "\n"
    if type(val) == "string" then
      val_str = val_str..val.." = "
    elseif type(val) == "table" and not rock.member(val, seen_tables) then
      table.insert(seen_tables, val)
      val_str = val_str.."[ "..rock.to_string(val, "", seen_tables).." ] = "
    elseif type(val) == "table" then
      val_str = val_str.."["..tostring(val).." (seen)] = "
    else
      val_str = val_str.."["..tostring(val).."] = "
    end
    if type(var[val]) == "table" and not rock.member(val, seen_tables) then
      table.insert(seen_tables, val)
      val_str = val_str..rock.to_string(var[val], "", seen_tables)..",\n"
    elseif type(var[val]) == "table" then
      val_str = val_str..tostring(var[val]).." (seen),\n"
    else
      val_str = val_str..tostring(var[val])..",\n"
    end
    cur_str = cur_str..val_str
  end
  return cur_str.."}"
end

rock._format = function (...)
---[[ This function tries to refactor the idiom:
   -- ("Error: %s"):format(err)
   -- into
   -- local emit = require "emit"
   -- print(emit.format("Err: %s", err))
   --
   -- This only wraps around string substitution %s,
   -- as opposed to the whole sprintf motley.
   -- This can be expanded later if need be.

  -- First, collect all the arguments, and convert them to strings
  local args = {...}
  for i=1,#args do
    if rock.pretty_printing then
      args[i] = rock.to_string(args[i])
    else
      args[i] = tostring(args[i])
    end
  end
  -- Return empty string if no arguments were passed
  if #args < 1 then return "" end

  -- Count how many %s substitution markers are in the message
  local _, subs = (args[1]):gsub("%%s", "")
  -- Check to make sure we have exactly enough replacements for
  -- each %s
  if subs ~= (#args - 1) then
    return nil, "Imbalance in replacements"
  end

  -- Pop out the first argument, which is the primary string
  local message = table.remove(args, 1)
  -- If there were replacements, format the string
  if #args > 0 then
    message = message:format(unpack(args))
    -- If not, don't modify the message
  -- If there was an error, print the error message
  end

  return message
end
rock.format = rock._format
rock.pretty_printing = true

rock._err = function (...)
  local message, err = rock.format(...)
  -- If there was an error, print the error message
  if not message then
    hexchat.print("Error in emit: "..tostring(err))
    error(err)
  end

  hexchat.print(message.."\n\n")

---[[ The following allows for this pattern:
   -- if err then
   --   return nil, emit.err("Error: %s", err)
  return message
end
rock.err = rock._err
rock._info = rock._err
rock.info = rock._err

rock._print = function (...)
  local message, err = rock.format(...)
  -- If there was an error, print the error message
  if not message then
    hexchat.print("Error in emit: "..tostring(err))
    error(err)
  end

  hexchat.print(message)

  return message
end
rock.print = rock._print

-- This function won't show any output while running under HexChat
rock._write = function (...)
  local message, err = rock.format(...)
  -- If there was an error, print the error message
  if not message then
    hexchat.print("Error in emit: "..tostring(err))
    error(err)
  end

  io.write(message)

  return message
end
rock.write = rock._write

rock.record = function (...)
  local message, err = rock.format(...)
  if not message then
    error(err)
  end
  rock.records[ #rock.records + 1 ] = message
  return message
end

rock.set_record = function ()
  rock.err = rock.record
  rock.info = rock.record
  rock.print = rock.record
  rock.write = rock.record
end

rock.unset_record = function ()
  rock.err = rock._err
  rock.info = rock._info
  rock.print = rock._print
  rock.write = rock._write
end

rock.record_output = function()
---[[ Sets all the output functions to record their output instead of printing it,
   -- Returns a function which, when called, resets the printing functions,
   -- and returns an array of all the strings that were generated from calling
   -- the print functions.
   -- This is meant to be used like a wrapper:
   -- 
   --> emit = require "emit"                    
   --> get_output = emit.record_output()
   --> (function () emit.print("Hello!") end)()
   --> emit.info("Hi!")                         
   --> records = get_output()
   --> emit.print("Hello!")
   --Hello!
   --> =#records
   --2
   --> =records[1] 
   --Hello!
   --> =records[2]
   --Hi!
   -- 
   -- Currently, this loses the custom formatting done by any functions 🤷‍♀️

  -- If anything is currently being recorded, don't clear the records
  if rock.err == rock.record or
     rock.info == rock.record or
     rock.print == rock.record or
     rock.write == rock.record then
    rock.set_record()
  else
    rock.set_record()
    rock.records = {}
  end
  
  local get_records = function ()
    rock.unset_record()
    return rock.records
  end
  return get_records
end
-- I need to be able to exit cleanly when running under hexchat,
-- and crash when not.
-- We would not do this in the print function
-- The codebase already only uses these print functions for communication
-- No function currently expects these to call error() on a fatal error
-- I'm only going to be running this outside of HexChat during manual and
-- automated tests, and in the automated case, I don't actually want a test
-- case to crash the whole test system; I want the test to fail. Calling
-- error() would stop the whole test run.
-- 
-- The best way to get this behaviour is by, at the site where the
-- print_error() function is called, if it's fatal, since the codebase
-- already does this, to return an error value and let that propogate to a
-- place where hook_objects is accessible, and things can be unhooked.
--
-- Under HexChat, I need to unregister any hook functions and
-- unload the plugin.
-- The unhooking should be handled by the caller, not the print function
-- that the callee calls to signal an error to the user
-- I can mock those function calls, but where would I keep track of the hooks
-- so that I can unregister them inside this module, and add to them in whichever
-- module will do the setup?
--
-- Also, how would I make it so that this function doesn't have to know it's being
-- mocked, and will make the calls to unregister hooks and modules whether it's
-- mocked or not.
-- Make calls to hexchat.print() as opposed to print() directly
-- This doesn't address this question, but it does address how to make sure the
-- dependency order is clear for modules, where this module depends upon header.lua
--
-- Maybe under HexChat I can replace the global error() function with one that
-- cleanly exits.
return rock
