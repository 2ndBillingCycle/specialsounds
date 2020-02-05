local rock = {}

---[==[ Utility functions
rock.copy = function (tbl)
  -- Make a shallow copy of the input table
  -- It's very bad, I know;
  -- don't sue me
  if type(tbl) ~= "table" then error("can only copy tables") end
  local new_tbl = {}
  for k,v in pairs(tbl) do new_tbl[k]=v end
  return new_tbl
end

rock.member = function (var, tbl)
  -- Checks if var is an element of array tbl
  if type(tbl) ~= "table" then error("tbl not table") end
  for i,val in ipairs(tbl) do
    if val == var then return true end
  end
  return false
end

rock.read_only = function (tbl)
  -- Make sure returned table is read only so nested callers can't
  -- manipulate entries
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

rock.compare_tables = function (tbl1, tbl2)
  -- Fails if the same key in both tables doesn't have the same value, otherwise it succeeds
  -- If the values are tables, checks if those tables match
  -- NOTE: Does not work with nested tables:
  -- a={} a[1]=a rock.compare_tables(a,a) -> ./test.lua:183: stack overflow
  if type(tbl1) ~= "table" or type(tbl2) ~= "table" then
    error("args must be tables")
  end
  -- Is one of the tables empty, and if so, is the other?
  -- From: https://stackoverflow.com/a/1252776 and https://www.lua.org/manual/5.1/manual.html#pdf-next
  if next(tbl1) == nil then return next(tbl2) == nil end
  -- pull out each element of the desired table, and compare to each element of received
  for k,v in pairs(tbl1) do
    -- first, types must match
    if type(v) ~= type(tbl2[k]) then
      return false
    -- if they're tables, take those tables and run this function against them
    elseif type(v) == "table" then
      -- tbl1 = {{"a"}} tbl2 = {{"a"}} -> tbl1={"a"} tbl2={"a"}
      if not rock.compare_tables(v, tbl2[k]) then return false end
    -- otherwise compare the values
    elseif tbl2[k] ~= v then
      return false
    end
  end
  return true
end
--]==]

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
