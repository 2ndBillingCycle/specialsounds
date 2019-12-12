local rock = {}

-- Don't lose the original
rock.print = print

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

  -- First, collect all the arguments, and convert them to strings
  -- NOTE: Is there any reason for the type check if tostring()
        -- doesn't mess with strings?
  local args = {}
  for i,arg in ipairs(...) do
    if type(arg) ~= "string" then
      args[#args + 1] = tostring(arg)
    end
    args[#args + 1] = arg
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
  if err == "" and #args > 0 then
    rock.print(message:format(unpack(args)).."\n\n")
  elseif err == "" then
    rock.print(message)
  else
  -- I need to be able to exit cleanly when running under hexchat,
  -- and crash when not.
  --
  -- Under HexChat, I need to unregister any hook functions and
  -- unload the plugin.
  -- I can mock those function calls, but where would I keep track of the hooks
  -- so that I can unregister them inside this module, and add to them in whichever
  -- module will do the setup?
  --
  -- Also, how would I make it so that this function doesn't have to know it's being
  -- mocked, and will make the calls to unregister hooks and modules whether it's
  -- mocked or not.
  --
  -- Maybe under HexChat I can replace the global error() function with one that
  -- cleanly exits.

