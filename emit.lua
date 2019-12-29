local rock = {}
-- Import header
local header = require "header"

rock.format = function (...)
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
    args[i] = tostring(args[i])
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

rock.err = function (...)
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

rock.info = rock.err

rock.print = function (...)
  local message, err = rock.format(...)
  -- If there was an error, print the error message
  if not message then
    hexchat.print("Error in emit: "..tostring(err))
    error(err)
  end

  hexchat.print(message)

  return message
end

-- This function won't show any output while running under HexChat
rock.write = function (...)
  local message, err = rock.format(...)
  -- If there was an error, print the error message
  if not message then
    hexchat.print("Error in emit: "..tostring(err))
    error(err)
  end

  io.write(message)

  return message
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
