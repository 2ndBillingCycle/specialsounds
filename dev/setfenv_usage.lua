package.preload.mod = function (...)
  local module_name = (...)
  local g = {}
  for k,v in pairs(_G) do
    if k ~= "_G" then
      g[k] = v
    end
  end
  local ns = {}
  setmetatable(ns, {__index = g})
  setfenv(1, ns)
  a = 1
  function func ()
    print("Hi, I'm "..tostring(module_name).."!")
  end
  return ns
end

local mod = require "mod"
if mod.a == 1 and a == nil then
   print("Contained :D")
else
  print("Not contained!")
end
mod.func()
