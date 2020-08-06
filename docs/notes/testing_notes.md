# Testing

Goals for the framework:

- Specify the input to the function, as well as the expected output, and expected use of `emit`
- - Watch for spurious use of bare `print`
- Monitor state for unintended side effects
- Summarize the test results for each function, as well as the total pass %
- Support pre-tasks/setup for when main.lua gets tested
- Isolate tests (e.g. `hexchat.settings` is the same at the start of each run)
- Collect the line numbers from failed tests to aid finding them quickly

## Implementation:

The last of those points can be implemented by passing the test functions to `debug.getinfo`. That'd get pretty close for the majority of the stuff that's not defined in case tables. For this, I guess it'd be easier to keep doing what we're doing: print the function, and the input that caused it to fail. For the functions, we can just make sure that the test function has a `short_src` of `./tests.lua`, to ensure it's a test function.

<del>Monitoring the global state of Lua is going to be challenging without some plugins/extensions that are written in C. For now, we'll just hope and pray there aren't any unintended side-effects.</del>

<del>Using [`setfenv`] and [`setmetatable`], an effective sandbox can be created: see [`dev/setfenv_usage.lua`](./dev/setfev_usage.lua).</del>

Looks like I forgot I was working on making protecting modules.

The current issue is that if there's a module like:

```lua
package.preload.mod = function (...)
  return {a=1}
end

local function modifies_a (mod)
  mod.a = 2
end

modifies_a(mod)

assert(mod.a == 1)
```

I don't currently know of a way to protect the module from being manipulated.

This has implications for functions under test, as even in a sandbox, they may need access to certain standard library functions, and may modify those if they're passed in as-is. For example:

```lua
local function setup_prank ()
  io.write = function (text)
    print("You got pranked")
  end
end

local env = {
  io = io,
  print = print,
}

setfenv(setup_prank, env)

setup_prank()

io.write("Sandboxed!\n")
```

This can actually be "sandboxed" by recreating the table, or with indirection through `setmetatable`.

Table copy:

```lua
local function setup_prank ()
  io.write = function (text)
    print("You got pranked")
  end
end

local env = {
  io = {
    write = io.write,
  },
  print = print,
}

setfenv(setup_prank, env)

setup_prank()

io.write("Sandboxed!\n")
```

Redirection/ingeritance:

```lua
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
```

The reason the above example doesn't work is that, even with the redirection, the `setup_prank()` function is still getting access to the same `io` table as is in the outer environment, which means any modifications to that table "excape" the sandbox.

Just like the first example, this can be resolved with automatic deep copies, or manually specifying a copy.

The downside comes from needing to deepcopy or specify _everything_ in the environment, and needing to deepcopy the included modules.

It might be better to use [`busted`], as long as it and all its dependencies can be included in a build step by [`amalg`] or other similar tool.

[`setfenv`]: <https://www.lua.org/manual/5.1/manual.html#pdf-setfenv> "setfenv() function in Lua 5.1 docs"
[`setmetatable`]: <https://www.lua.org/manual/5.1/manual.html#pdf-setmetatable> "setmetatable() function in Lua 5.1 docs"
[`busted`]: <https://olivinelabs.com/busted/> "busted docs"
[`amalg`]: <https://github.com/siffiejoe/lua-amalg> "lua-amalg on GitHub"
