--[[
I would like this to be a nicer test runner.

I think that'll require coroutines, as I'd like a running output, where each test section is printed, followed by a string of . for success and ❌ or ✗:

```text
test_lexer
.........✗..✗......
test_parser
...✗.......✗...

results:
test_lexer: 2
case:
"(error"
👇
Mismatched parenthesis error

...
```
--]]

local rock = {}
local lexer = require "lexer"

rock.results = {}

rock.test_lexer = function ()
  rock.results.lexer = {}

  test_commands = {
    "/SSOUND /add server #channel sound H:\\sound.wav match (matc%(h pattern)",
    "/SSOUND /add server #channel sound H:\\sound.wav",
    "/SSOUND /add server #channel match pattern",
    "/SSOUND /add server match pattern",
    "/SSOUND /add server sound sound",
    "/SSOUND /add #channel match word",
    "/SSOUND /add #channel sound sound.wav",
    "/SSOUND /add match (pitter patter)",
    "/SSOUND /add sound rain.wav",
    "/SSOUND /add (match) match match sound sound",
    "/SSOUND /show server #channel",
    "/SSOUND /show server",
    "/SSOUND /show #channel",
    "/SSOUND /show (match)",
    "/SSOUND /show ",
    "/SSOUND /delete server #channel 2",
    "/SSOUND /delete server #channel 1",
    "/SSOUND /delete server 1",
    "/SSOUND /delete #channel 1",
    "/SSOUND /delete (match) 1",
    "/SSOUND /delete 1",
  }

  for i,command in ipairs(test_commands) do
    if type(lexer.lex(command)) ~= "table" then
      local err = ("error\n%s"):format(tostring(lexer.lex(command)))
      print(err)
      return nil, err
    end
  end

  return "✔"
end

rock.good_output = function (func, input, output)
    if not output then
        return assert(func(unpack(input)))
    else
        return output == assert(func(unpack(input)))
    end
end

rock.bad_output = function (func, input, output)
    if not output then
        return func(unpack(input))
    else
        return output == func(unpack(input))
    end
end

rock.bad_cases = {
    {
        name = "lexer.lex",
        func = lexer.lex,
        cases = {
            {input={"(error"}},
        },
    },
}

rock.test_bad_cases = function ()
    local emit = require "emit"
    for i, case_pack in ipairs(rock.bad_cases) do
        emit.info("%s bad", case_pack.name)
        for i,case in ipairs(case_pack.cases) do
            if not rock.bad_output(case_pack.func, case.input, case.output) then
                io.write(".")
            else
                io.write("✗")
            end
        end
    end
    return "✔"
end


rock.run = function ()
  for name,func in pairs(rock) do
    if name:match("test_.+") then
      assert( func() )
    end
  end
end

return rock
