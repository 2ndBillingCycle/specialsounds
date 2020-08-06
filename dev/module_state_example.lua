local function setup_prank ()
  io.write = function (text)
    print("You got pranked")
  end
end

local g = {}
for k,v in pairs(_G) do
  if k ~= "_G" then
    g[k] = v
  end
end
g["_G"] = g
local env = {}
setmetatable(env, {__index=g})
setfenv(setup_prank, env)

setup_prank()

io.write("Sandboxed!\n")
