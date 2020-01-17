local rock = {}

rock.copy = function (tbl)
  -- Make a copy of the input table
  -- It's very bad, I know:
  -- It's for use with record_output();
  -- don't sue me
  if type(tbl) ~= "table" then error("can only copy tables") end
  local new_tbl = {}
  for k,v in pairs(tbl) do new_tbl[k]=v end
  return new_tbl
end

---[==[ Mock hexchat table
if not hexchat then
  hexchat = {}
  hexchat.print = print
  hexchat.pluginprefs = {}
  hexchat.EAT_HEXCHAT = true
  hexchat.EAT_NONE = true
  hexchat.get_info = function (str)
    if str == "channel" then
      return "#test"
    else
      return "test.example.com"
    end
  end
  hexchat.get_context = function ()
    return {
      get_info = function (ctx, str)
        if str == "channel" then
          return "#test"
        else
          return "test.example.com"
        end
      end
    }
  end
  hexchat.strip = function (str) return str end
  hexchat.command = function (str) print("hexchat.command:\n" .. str) end
  hexchat.hook_command = function (a, b, c) return {unhook = function () end} end
  hexchat.hook_print = function (str, func) return {unhook = function () end} end
  hexchat.register = function (...) return end
end
--]==]

rock.version = "10"
hexchat.register(
  "SpecialSounds",
  rock.version,
  "Set special sound to play on message"
)

return rock
