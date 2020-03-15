--[[
One of the issues with the current test runner is a lack of isolation
between tests. I've been shown a few methods for isolating the global
namespace accessed through the _G table, but I'm worried they don't
protect against all methods Lua provides for storing state.

I'm especially worried about this in relation to how people are
implementing concatenation of a Lua script and the modules it depends
upon.

These demonstrate what I believe might be breaking cases, and their
solutions
--]]

-- This is he way a lot of concatenation solutions seem to be wrapping up
-- modules
function package.preload.example_module ()
  local rock = {}
  rock.var = 1
  return rock
end

-- State set in the module:
local function modify_and_return ()
  local example_module = require "example_module"
  example_module.var = example_module.var + 1
  return example_module.var
end

-- Is kept around:
-- <>
-- States that the module loading mechanism simply returns whatever's in
-- package.loaded[module_name]
if modify_and_return() ~= modify_and_return() then
  print("State not separated!")
end

-- If package.loaded[module_name] is set to nil between each run, this
-- may mitigate this, as the function in package.preload is called, and
-- generates everything anew.

local function clear_loaded ()
  for name,_ in pairs(package.loaded) do
    package.loaded[name] = nil
  end
end

-- This has the downside of, at least in LuaJIT, removing baked-in
-- modules: io, os, math, etc.
-- Most of those tables do not exist in package.preload
local os = _G.os -- Just an explicit reminder for myself that I'm grabbing the global module
package.loaded.os = nil
if not pcall(function () require "os" end) then
  print("os module is gone")
  package.loaded.os = os
end
