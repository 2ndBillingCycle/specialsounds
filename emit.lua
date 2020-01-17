local rock = {}
-- Import header
local header = require "header"
rock.trailing_commas = false

rock.debug = function (str)
  --if type(str) ~= "string" then
  --  -- do nothing
  --else
  --  print(str)
  --end
end

rock.member = function (var, tbl)
  -- Checks if var is an element of array tbl
  if type(tbl) ~= "table" then error("tbl not table") end
  for i,val in ipairs(tbl) do
    if val == var then return true end
  end
  return false
end

rock.clear = function (seen, tbls)
  -- Sets all the keys in the dict seen that are tables also in the array tbl to nil
  if type(seen) ~= "table" or type(tbls) ~= "table" then
    error("both arguments must be tables")
  end
  for i,tbl in ipairs(tbls) do
    seen[tbl] = nil
  end
end

rock.string_repr = function (str)
  if type(str) ~= "string" then
    return str
  end
  return "\""..str:gsub("\n","\\n")
                  :gsub("\"","\\\"").."\""
end

rock.to_string = function (var)
  -- Should behave exactly like the builtin tostring() function,
  -- except will also pretty-print tables
  -- NOTE: Currently nested tables referencing themselves, or other
  -- cyclical references are giving me trouble; will leave looking
  -- at graph theory and loop detection for later
  -- > a={}
  -- > b={}
  -- > a[1]=b
  -- > b[1]=a
  -- > =a
  -- table: 0x56418bcb3490
  -- > =b
  -- table: 0x56418bcb6600
  -- > =a[1]
  -- table: 0x56418bcb6600
  -- > =a[1][1]
  -- table: 0x56418bcb3490
  -- > =a[1][1][1][1][1]
  -- table: 0x56418bcb6600
  -- > =a[1][1][1][1][1][1]
  -- table: 0x56418bcb3490
  -- > =b[1]
  -- table: 0x56418bcb3490
  -- > =b[1][1]
  -- table: 0x56418bcb6600

  -- Bail out early if not tables
  -- tostring(nil) -> nil
  -- This used to be the check for nil, but would also catch false:
  -- if not var then return "nil"
  if var == "nil" then return "nil"
  elseif type(var) ~= "table" then return tostring(var)
  end

  -- Global flag to keep track of when expand() should be used instead
  -- of concat()
  local expanded = false

  local concat = function (str_tbl)
    local concatted = ""
    for i,val in ipairs(str_tbl) do
      if val == "," then
        -- This needs to be in an inner block, as "}" is still a string, and if the above
        -- if statement evaluates to false, this if..elseif chain will fall through to the
        -- next, which will succeed, and the comma will be added
        if rock.trailing_commas or str_tbl[i + 1] ~= "}" then
          concatted = concatted..", "
        end
      elseif type(val) == "string" then
        concatted = concatted..val
      else
        error("val in str_tbl not a string: "..tostring(val))
      end
    end
    return concatted
  end

  local expand = function (str_tbl)
    local concatted = ""
    local indent_level = 0
    local indent_step = 2
    local indent_char = " "
    for i,val in ipairs(str_tbl) do
      if val == "{" then
        concatted = concatted.."{\n"
        indent_level = indent_level + indent_step
        concatted = concatted..string.rep(indent_char, indent_level)
      elseif val == "}" then
        concatted = concatted.."\n"
        indent_level = indent_level - indent_step
        concatted = concatted..string.rep(indent_char, indent_level).."}"
      elseif val == "," then
        if rock.trailing_commas or str_tbl[i + 1] ~= "}" then
          concatted = concatted..",\n"..string.rep(indent_char, indent_level)
        end
      elseif type(val) == "string" then
        concatted = concatted..val
      else
        error("Bad value in str_tbl: "..tostring(val))
      end
    end
    -- On its own line so the second return value of string.gsub doesn't
    -- also get returned
    local str = concatted:gsub(",?\n?$","")
    return str
  end

  local function inner (var, cur_str, seen_tables)
    if not cur_str then cur_str = {} end
    if not seen_tables then seen_tables = {} end
    
    local indices = {}
    local keys = {}
    for key, value in pairs(var) do
      if tostring(key):match("^%d+$") then
        indices[#indices + 1] = key
        if key < 1 then error("index out of range: "..tostring(key)) end
      else
        keys[#keys + 1] = key
      end
    end
    -- Reorganizes table's values using `<` and `>`
    table.sort(indices)
    -- I'm assuming that there's no ordering of values in a Lua array table
    -- that can generate a table with keys outside the range of [1,inf) of
    -- natural numbers:
    -- t={}
    -- n={-9, nil, [t]=t,[1.1]=0,[io.stdin]=2,}
    -- All of the keys for table n will be a natural number [1,inf)
    local maxn = 0 -- ensures that `for i=1,0 never runs`
    if #indices > 0 then
      maxn = indices[#indices]
    end
    cur_str[#cur_str + 1] = "{"
    for i=1,maxn do
      if indices[i] ~= i then
        cur_str[#cur_str + 1] = "nil"
        -- Doesn't matter what we insert, we just want to push the rest of the values over
        table.insert(indices, i, i)
      elseif type(var[i]) == "table" and not seen_tables[var[i]] then
        seen_tables[var[i]] = true
        inner(var[i], cur_str, seen_tables)
      elseif type(var[i]) == "table" then
        cur_str[#cur_str + 1] = tostring(var[i]).." (seen)"
      elseif type(var[i]) == "string" then
        cur_str[#cur_str + 1] = rock.string_repr(var[i])
      else
        cur_str[#cur_str + 1] = tostring(var[i])
      end
      cur_str[#cur_str + 1] = ","
    end
    for i,key in ipairs(keys) do
      local val = var[key]
      if val == nil then error("nil val from keys table") end
      if #indices > 0 or i > 1 then rock.debug("set expanded") expanded = true end
      if type(key) == "string" then
        cur_str[#cur_str + 1] = key.." = "
      elseif type(key) == "table" and not seen_tables[key] then
        seen_tables[key] = true
        cur_str[#cur_str + 1] = "["
        inner(key, cur_str, seen_tables)
        cur_str[#cur_str + 1] = "] = "
      elseif type(key) == "table" then
        cur_str[#cur_str + 1] = "["..tostring(key).." (seen)] = "
      else
        cur_str[#cur_str + 1] = "["..tostring(key).."] = "
      end
      if type(val) == "table" and not seen_tables[val] then
        seen_tables[val] = true
        inner(val, cur_str, seen_tables)
      elseif type(val) == "table" then
        cur_str[#cur_str + 1] = tostring(val).." (seen)"
      elseif type(val) == "string" then
        cur_str[#cur_str + 1] = rock.string_repr(val)
      else
        cur_str[#cur_str + 1] = tostring(val)
      end
      cur_str[#cur_str + 1] = ","
    end
    cur_str[#cur_str + 1] = "}"
    return cur_str
  end
  
  str_tbl = inner(var)
  if expanded then return expand(str_tbl) else return concat(str_tbl) end
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

rock.read_only = function (tbl)
  -- Make sure returned table is read only so nested callers can't
  -- manipulate record entries
  --
  -- Use the recipe from: https://www.lua.org/pil/13.4.5.html
  local proxy = {}
  local mt = {       -- create metatable
    __index = t,
    __newindex = function (t,k,v)
      error("attempt to update a read-only table", 2)
    end
  }
  setmetatable(proxy, mt)
  return proxy
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
    -- Don't clear records, so that calls to record() and subsequent
    -- get_records() can be made without clearing the records seen by
    -- outter calls.
    -- Records should only be cleared after the outermost get_records
    -- has been called, and a new record_output is called.
    rock.unset_record()
    return header.copy(rock.records)
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
