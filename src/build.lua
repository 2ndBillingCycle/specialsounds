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
package.loaded["<filename without extension>"] = rock
rock = nil
```

Sounds dandy. Only thing to do is make sure the order is correct. I don't think this could be automated, except maybe in the filenaming (e.g. `00-lex.lua`, `00-parser.lua`, etc).

This seems tedious, and I don't want to do that. I don't expect the functionality to grow so quickly that adding the filenames to a list manually to become tedious.

Also, since Lua doesn't have a native understanding of directories, it'd be easier to have it build the final file as SpecialSounds.lua in the current directory.
--]==]

local rock = {}
local emit = require "emit"

-- NOTE: Changes line endings to CRLF :(
rock.bumpver = function ()
  -- If the global variable bumpver is not set, do nothing
  if not bumpver then return nil, emit.err("bumpver not set; won't bump") end
  local handle = assert(io.open("header.lua", "r"))
  local file = handle:read("*all")
  assert(handle:close())
  if not file then
    emit.err("Empty header.lua")
    return false
  end
  -- Matching line used to be as below, witht he match wrapped in newlines so as to match
  -- ONLY the version string no a single line, as opposed to one in a comment somewhere,
  -- but LuaJIT doesn't like that
  --local ver = file:match("\nrock%.version = \"([0-9]+)\"\n")
  local ver = file:match("rock%.version = \"([0-9]+)\"")
  local line = ""
  if ver and type(tonumber(ver)) == "number" then
    ver = tostring(ver + 1)
    line = ("rock.version = \"%s\""):format(ver)
  else
    error("Can't find version number")
  end
  new_file = file:gsub("rock%.version = \"([0-9]+)\"", "rock.version = \""..ver.."\"")
  local handle = assert(io.open("header.lua", "w"))
  assert(handle:write(new_file))
  assert(handle:close())
  return true
end
  

rock.run = function ()
  local files = {
    "header.lua", -- Check if we're running under HexChat, and register early to keep it happy
    "emit.lua",   -- Implements print(("%s"):format(""))
    "lexer.lua",
    "tests.lua",
    "test.lua",
    "main.lua",
  }

  local outfile, file_error = io.open("SpecialSounds.lua", "w")
  if outfile == nil then
    emit.err(file_error)
    return false
  end
  for i,name in ipairs(files) do
    -- Check to make sure the file exists
    local file, file_error = io.open(name, "r")
    if file == nil then
      emit.err(file_error)
      assert(outfile:close())
      return false
    elseif not file:read(0) then
      emit.err("Empty file: %s", name)
      assert(file:close())
      assert(outfile:close())
      return false
    end
    text = file:read("*a")
    assert(file:close())
    -- NOTE: Should probably load/compile the file to make sure there aren't any obvious
    -- errors like syntax errors

    -- Is this a multiline file
    local _, num_line_end = text:gsub("[\n\r]", "")
    if num_line_end < 2 then
      emit.err("File only 1 line: %s", name)
      assert(outfile:close())
    end
    -- If this is main.lua, don't mangle it
    --[[ Old way
    if name ~= "main.lua" then
        -- Chop off the last line
        text = text:match("(.*)\n.+")
        -- Append the necessary 2 package loading lines
        text = text.."\npackage.loaded[\""..name.."\"] = rock\nrock = nil\n"
    end
    --]]
    if name ~= "main.lua" then
      local mod = name:match("^(%a+)%.lua")
      if mod == nil then
        return nil, emit.err("Bad file name: %s", name) end
      -- Add function package.preload.<name> () ... end lines
      text = "function package.preload."..mod.." ()\n"..text.."\nend\n"
    end
    -- Mush it into the pile
    assert(outfile:write(text))
  end
  assert(outfile:close())

  emit.info("Built")
  return "Built"
end

if test    then local test = require "test" assert(test.run())     end
if bumpver then                             assert(rock.bumpver()) end
if build   then                             assert(rock.run())     end

return rock