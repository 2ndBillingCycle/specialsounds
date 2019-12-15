local rock = {}

rock.err = function (...)
---[[ This function tries to refactor the idiom:
   -- print(("Error: %s"):format(err))
   -- into
   -- local print = require "print"
   -- print.err("Err: %s", err)
   --
   -- It also tries to switch between hexchat behavriour, where
   -- crashing Lua by calling error() is a bad idea, and running
   -- under the interpreter during builds and testing, where
   -- failing early is the desired action.
   --
   -- Lastly, this only naively wraps around string substitution
   -- with %s, as opposed to the whole sprintf motley.
   -- This can be expanded later if need be.

  -- Import header
  local header = require "header"

  -- First, collect all the arguments, and convert them to strings
  -- NOTE: Is there any reason for the type check if tostring()
        -- doesn't mess with strings?
  local args = {...}
  for i=1,#args do
    if type(args[i]) ~= "string" then
      args[i] = tostring(args[i])
    end
  end
  -- Do nothing if no arguments were passed
  if #args < 1 then return nil end
  
  local err = ""
  -- Count how many %s substitution markers are in the message
  local _, subs = (args[1]):gsub("%%s", "")
  -- Check to make sure we have exactly enough replacements for
  -- each %s
  if subs ~= (#args - 1) then
    err = "Imbalance in replacements"
  end

  -- Always check for errors; we'll emit them at the end when we
  -- check if we're running under HexChat or not

  -- Pop out the first argument, which is the primary string
  local message = ""
  if err == "" then
    message = table.remove(args, 1)
  end
  -- If there were replacements, format the string
  if err == "" and #args > 0 then
    hexchat.print(message:format(unpack(args)).."\n\n")
  -- If not, just print the string
  elseif err == "" then
    hexchat.print(message)
  -- If there was an error, print the error message
  else
    hexchat.print(("Bad call to emit: %s"):format(err))
    return false
  end
  
  return true
end

rock.info = rock.err

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
