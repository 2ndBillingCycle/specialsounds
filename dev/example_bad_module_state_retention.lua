package.preload.mod = function ()
  return {a=1}
end
local mod = require "mod"
local function modify_a ()
  mod.a = 10
  print("  inside function mod.a is "..tostring(mod.a))
end
local env = {}
local mt = {
  __index={
    mod=mod,
    tostring=tostring,
    print=print,
  },
}
setmetatable(env, mt)
setfenv(modify_a, env)
print("before calling function, mod.a is "..tostring(mod.a))
print("calling function inside sandbox")
print("function "..( pcall(modify_a) and "succeeded" or "failed"))
print("after calling function, mod.a is "..tostring(mod.a))