print("Defining module")
package.preload.mod = function ()
  return {var="unmodified"}
end

print("loading module")
local mod = require "mod"
print("mod.var is "..tostring(mod.var))

print("Define functions that manipulate the module's inner state")
local modify_var = function ()
  mod.var = "modified"
  print("  inside modify_var(), mod.var is "..tostring(mod.var))
end
local require_then_modify_var = function ()
  local mod = require "mod"
  mod.var = "modified"
  print("  inside require_then_modify_var(), mod.var is "..tostring(mod.var))
end

print("Setup testing isolation")
local test_isolation = require "test_isolation"
local shadow_module, run_with_env, empty_env = test_isolation.shadow_module, test_isolation.run_with_env, test_isolation.empty_env
local env = empty_env()
env.mod = shadow_module(mod)
env.tostring = tostring
env.print = print
env.require = require

print("before running modify_var() in sandbox, mod.var is "..tostring(mod.var))
print("running modify_var() inside sandbox")
print("function "..( run_with_env(modify_var, env) and "succeeded" or "failed"))
print("looking at the sandbox environment, mod.var is "..tostring(env.mod.var))
print("outside the sandbox, mod.var is "..tostring(mod.var))

io.write("\n")

print("resetting mod")
package.loaded.mod=nil
local mod = require "mod"
print("mod reset")
print("mod.var is currently "..tostring(mod.var))

print("running modify_var() inside already defined sandbox")
print("function "..( run_with_env(modify_var, env) and "succeeded" or "failed"))
print("looking at the sandbox environment, mod.var is "..tostring(env.mod.var))
print("after running modify_var(), mod.var is "..tostring(mod.var))

io.write("\n")

print("redefining state modifying functions")
modify_var = function ()
  mod.var = "modified"
  print("  inside modify_var(), mod.var is "..tostring(mod.var))
end
require_then_modify_var = function ()
  local mod = require "mod"
  mod.var = "modified"
  print("  inside require_then_modify_var(), mod.var is "..tostring(mod.var))
end

print("running modify_var() inside already defined sandbox environment")
print("function "..( run_with_env(modify_var, env) and "succeeded" or "failed"))
print("looking at the sandbox environment, mod.var is "..tostring(env.mod.var))
print("after running modify_var(), mod.var is "..tostring(mod.var))

io.write("\n")

print("resetting mod")
package.loaded.mod=nil
local mod = require "mod"
print("mod reset")
print("mod.var is currently "..tostring(mod.var))

print("running modify_var() inside already defined sandbox environment")
print("function "..( run_with_env(modify_var, env) and "succeeded" or "failed"))
print("looking at the sandbox environment, mod.var is "..tostring(env.mod.var))
print("after running modify_var(), mod.var is "..tostring(mod.var))
print("running require_then_modify_var() inside already defined sandbox environment")
print("function "..( run_with_env(require_then_modify_var, env) and "succeeded" or "failed"))
print("looking at the sandbox environment, mod.var is "..tostring(env.mod.var))
print("after running require_then_modify_var(), mod.var is "..tostring(mod.var))

io.write("\n")

print("resetting mod without redeclaring")
package.loaded.mod=nil
mod = require "mod"
print("mod reset")
print("mod.var is currently "..tostring(mod.var))

print("running modify_var() inside already defined sandbox environment")
print("function "..( run_with_env(modify_var, env) and "succeeded" or "failed"))
print("looking at the sandbox environment, mod.var is "..tostring(env.mod.var))
print("after running modify_var(), mod.var is "..tostring(mod.var))
print("running require_then_modify_var() inside already defined sandbox environment")
print("function "..( run_with_env(require_then_modify_var, env) and "succeeded" or "failed"))
print("looking at the sandbox environment, mod.var is "..tostring(env.mod.var))
print("after running require_then_modify_var(), mod.var is "..tostring(mod.var))

io.write("\n")

print("clearing mod, then redeclaring")
package.loaded.mod=nil
mod = nil
local mod = require "mod"
print("mod reset")
print("mod.var is currently "..tostring(mod.var))

print("running modify_var() inside already defined sandbox environment")
print("function "..( run_with_env(modify_var, env) and "succeeded" or "failed"))
print("looking at the sandbox environment, mod.var is "..tostring(env.mod.var))
print("after running modify_var(), mod.var is "..tostring(mod.var))
print("running require_then_modify_var() inside already defined sandbox environment")
print("function "..( run_with_env(require_then_modify_var, env) and "succeeded" or "failed"))
print("looking at the sandbox environment, mod.var is "..tostring(env.mod.var))
print("after running require_then_modify_var(), mod.var is "..tostring(mod.var))

io.write("\n")

print("loading mod with different name")
local mod_2 = require "mod"
