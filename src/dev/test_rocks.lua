function package.preload.first ()
local rock = {}

rock.a = "works"
rock.foo = (function () return
  function ()
    print(rock.a)
  end
end)()

return rock
end


function package.preload.second ()
local rock = {}

rock.b = "still works"
rock.bar = function () print(rock.b) end

return rock
end


local first = require "first"
local second = require "second"
first.foo()
second.bar()
