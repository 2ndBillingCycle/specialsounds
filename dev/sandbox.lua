local module_name = (...)

---[[ Imports
local setmetatable = setmetatable
local setfenv = setfenv
local debug_traceback = debug.traceback

---[[ Module prep
local g = {}
for k,v in pairs(_G) do
  if k ~= "_G" then
    g[k] = v
  end
end
g["_G"] = g
local namespace = {}
setmetatable(namespace, {__index = g})
setfenv(1, namespace)
--]]


function run (func, env)
  if type(func) ~= "function" then
    error("func is not a function", 2)
  end

  if env ~= nil and type(env) ~= "table" then
    error("env must be a table that will be used as the environment", 2)
  elseif env == nil then
    env = {}
    setmetatable(env, {__index=g})
  end

  setfenv(func, env)
  local result = {xpcall(func, debug_traceback)}

  return result
end

return namespace
