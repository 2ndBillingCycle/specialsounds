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

I would like the following features:

- Specify the function to be tested
- Provide input
- - Optionally specify the output to match to determine if the function worked
- - Maybe specify the messages that should be printed
- Write out test inputs and outputs of failed tests as they go
- Summarize the test results for each function, as well as the total pass %
- Support preconditions for when main.lua gets tested

NOTE: Test runner does not yet isolate tests; following runs will see the state from previous runs
--]]

local rock = {}
local lexer = require "lexer"

rock.results = {}

rock.check_output = function (name, func, input, output)
  if type(name) ~= "string" then return false, "Bad name" end
  if type(func) ~= "function" then return false, "func is not function" end
  local results = {
    input=input,
    output=output,
  }
  if type(input) == "table" then
    input[#input + 1] = func
    results.result = {pcall(unpack(input))}
    input[#input] = nil
  else
    results.result = {pcall(func, input)}
  end
  if rock.results[name] == nil then
    rock.results[name] = {}
  end
  table.insert(rock.results[name], results)
end

rock.cases = {
  {
    name = "lexer.lex",
    func = lexer.lex,
    good_cases = {
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
    },
    bad_cases = {
      "(error",
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
    if not name:match("test_.+") then end
    local result, err = pcall(func())
    if not result then
      emit.err("Error in test %s: %s", name, err)
      rock.results[name] = err
    else
      rock.results[name] = result
    end
  end
  return "♻️
end

return rock
