package.preload.mod = function () return {a={}} end

local mod = require "mod"
local first = mod.a
print(mod.a)

mod = nil
package.loaded.mod = nil

local mod = require "mod"
local second = mod.a
print(mod.a)
print("Table "..(first == second and "is not" or "is").." regenerated")
