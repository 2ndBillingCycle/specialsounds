local rock={}

rock.shadow_table = function (tbl)
  if type(tbl) ~= "table" then
    error("tbl must be a table", 2)
  end
  local shadow_tbl = {}
  local mt = {__index=tbl}
  setmetatable(shadow_tbl, mt)
  return shadow_tbl
end

rock.requireable = function (name)
  if type(name) ~= "string" then
    error("name must be a string", 2)
  end
  local mod = require(name)
  package.loaded[name] = nil
  local function try_require ()
    return require(name)
  end
  local env = {
    require=require,
  }
  setfenv(try_require, env)
  local res = {pcall(try_require)}
  package.loaded[name] = mod
  return res[1] and true or false
end
  
rock.shadow_module = function (mod)
  -- Aims to return a copy of a module that is able to be require()'d
  -- such that any state internal to the module can be changed by a
  -- function under test in a sandbox, without that changed state
  -- being seen outside the sandbox
  --[[ Example
  package.preload.mod = function ()
    return {a=1}
  end
  local mod = require "mod"
  print("mod.a is "..tostring(mod.a))
  local function modify_a ()
    mod.a = 10
  end
  local env = {}
  local mt = {__index={mod=mod}}
  setmetatable(env, mt)
  setfenv(modify_a, env)
  print(pcall(modify_a))
  print("mod.a is "..tostring(mod.a))
  --]]
  local name = false
  if type(mod) == "string" then
    name = mod
  elseif type(mod) == "table" then
    for k,v in pairs(package.loaded) do
      if rawequal(v, mod) then
        name = k
      end
    end
    if not name then
      error("module must be loaded", 2)
    end
  else
    error('mod must be the module as returned by require("mod") or a module name as a string')
  end

  if not rock.requireable(name) then
    error("mod must be able to be require()'d")
  end

  local our_mod = require(name)
  package.loaded[name] = nil
  local clean_mod = require(name)
  package.loaded[name] = our_mod
  return rock.shadow_table(clean_mod)
end

rock.run_with_env = function (func, env)
  -- Modifies a function to run with access only to the provided environment
  -- and then runs it with xpcall()
  if type(func) ~= "function" then
    error("func must be a function", 2)
  elseif type(env) ~= "table" or
         type(getmetatable(env)) ~= "table" or
         rawget(getmetatable(env), "is_env") ~= true then
    error("env must be a table made by base_env()", 2)
  end
  -- Ensures function cannot modify provided environment
  -- NOTE: It can't, can it?
  local new_env = rock.shadow_table(env)
  setfenv(func, new_env)
  return xpcall(func, debug.traceback)
end
    
rock.empty_env = function ()
-- Returns a table that can be used with setfenv()
  local meta_env = {__index={}, is_env=true}
  local env = {}
  env._G = env
  setmetatable(env, meta_env)
  return env
end

rock.base_env = function ()
  local header = require "header"
  local env = rock.empty_env()
  env.require = require
  env.hexchat = rock.shadow_table(hexchat)
  return env
end

return rock
