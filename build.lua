--[==[
I'm thinking that, to enable easy distribution of a multi-file Lua script, I could have the main file that's loaded combine all the other files.

This would require a Lua interpreter to do the build, but would not require one to run from source, or to use the distributed single file version.

I'd want to make this process easy for me, so I think having a build system written in Lua, included in the repository, would be ideal.

My current picture is to have all the disparate files be modules that look like the following:

```lua
local rock = {}

rock.foo = function (...) return {...} end

return rock
```

So that in the main file (probably `SpecialSounds.lua`) all that's required is `local foo = require "foo"` and then `foo.foo(nil)` to use the functions.

Then, the main file can tell when it's being run for building, and mush everything into a single file that can be distributed on the releases page.

This would probably take advantage of the fact that HexChat provides a `hexchat` table, which would be `nil` when the script is being run inside a regular Lua interpreter.

The main file would probably have a conditional that would do it's normal regitering with HexChat and submitting hook functions and such when the table is present.

When it's not, it could do a build. This would also allow unit tests to be done prior to the build! 🎉

The test step would probably just start off by using `assert()` on calls to the lexer, parser, and functions, providing a mock for the hexchat functionality.

If the tests return cleanly, then the build step would gather all the lua files, and process each in turn.

The build step would probably look something like what's on <http://lua-users.org/wiki/LuaCompilerInLua>.

It would need to replace the `return rock` at the end of every file with something like the following:

```lua
for name,func in pairs(rock) do
if package.loaded[name] ~= nil then
error("Name collision")
end
end
package.loaded["foo"] = rock
```
Actually, I was thinking of mushing all the files into one large module, but the code already uses them namespaced anyways, so the above doesn't really make sense.

All that really needs to happen is the last line, `return rock`, with:

```lua
local <filename without extension> = rock
rock = nil
```

And be done with it.

Wait, this would break the `local foo = require "foo"`...

Maybe the last line could instead load the table into `package.loaded`:

```lua
package.loaded["<filename without extension"] = rock
rock = nil
```

Sounds dandy. Only thing to do is make sure the order is correct. I don't think this could be automated, except maybe in the filenaming (e.g. `00-lex.lua`, `00-parser.lua`, etc).

This seems tedious, and I don't want to do that. I don't expect the functionality to grow so quickly that adding the filenames to a list manually to become tedious.

Also, since Lua doesn't have a native understanding of directories, it'd be easier to have it build the final file as SpecialSounds.lua in the current directory.
--]==]

local rock = {}

local function print_error (message)
  if type(message) ~= "string" then
    error("Bad string for print_error")
  end
  print(message .. "\n\n")
end
local function print_message (message)
  if type(message) ~= "string" then
    error("Bad string for print_message")
  end
  print(message .. "\n\n")
end


rock.bumpver = function ()
  -- If the global variable bumpver is not set, do nothing
  if not bumpver then return nil end
  local new_file = ""
  local handle, err = io.open("header.lua", "r")
  if not handle and err then
    print_error(("Bad file: %s"):format(tostring(err)))
  end
  local file = handle:read("*all")
  if not file then
    print_error("Missing header.lua")
  end
  version = ""
  while true do
    local line = handle:read("*line")
    if not line then break end
    local ver = line:match("^rock\.version = \"([0-9]+)\"")
    if ver and type(tonumber(ver)) == "number" then
      ver = tostring(ver + 1)
      line = ("rock.version = \"%s\""):format(ver)
    end
    new_file = new_file..line
  end
  assert(handle:close())
  local handle, err = io.open("header.lua", "w")
  if not handle and err then
    print_error(("Can't reopen: %s"):format(tostring(err)))
  end
  handle:write(new_file)
  assert(handle:close())
end
  

rock.run = function ()
  local files = {
    "header.lua", -- Check if we're running under HexChat, and register early to keep it happy
    "lexer.lua",
    "build.lua",
    "test.lua",
    "main.lua",
  }

  for i,name in ipairs(files) do
    -- Check to make sure the file exists
    local file, file_error = io.open(name, "rb")
    if file == nil then
      print_error(file_error)
      return false
    elseif not file:read(0) then
      print_error(("Empty file: %s"):format(name))
      return false
    end
    -- On the first one, optionally bump the version
    -- Load/compile the file to make sure there aren't any obvious errors like syntax errors
    -- Chop off the last line
    -- Append the necessary 2 package loading lines
    -- Mush it into the pile
  end

  -- Make directory ./build if it doesn't exist
  -- Put the mushed file into ./build/SpecialSounds.lua
  -- 🎈
end

return rock
