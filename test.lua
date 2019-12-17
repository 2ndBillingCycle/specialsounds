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

rock.cases = {
  {
    name = "lexer.lex",
    func = (require "lexer").lex,
    pass_cases = {
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
    fail_cases = {
      "(error",
    },
  },
}

--[==[ Each case table looks like:
{
  name = "name of module/function",
  func = (require "module").func,
  pass_cases = {
    [[test input that is passed to the function; the function must return a truthy
    value to be considered as having passed]],
    {input="if the case is a table, the output will be compared against the output key",
    output="for the test case to be considered as having been passed"},
    {
      input={{"If", "a table"}, "or if mutliple arguments", "need to be given"},
      output={nil, "or a function may return an error", "or multiple values"},
    },
    "a nested table can be used as a test case -^",
  },
  fail_cases = {
    "same thing for fail cases, except the function is expected to return an error",
    {input="to make sure it returns the correct error",
    output={nil, "the error message can be given in a table like this in the output key"},
  },
}
--]==]

rock.compare_output = function (desired, received)
  -- received output must always be a table
  if type(received) ~= "table" then return nil, "received not table" end
  -- Are we comparing error output?
  if type(desired) == "table" and desired[1] == nil then
    return desired[2] == received[2]
  elseif type(desired) ~= "table" then
    -- Is desired a simple type?
    return desired == received[1]
  else
    -- desired is a table, and does not indicate an error condition
    for k,v in pairs(desired) do
      if type(v) == "table" and type(received[k]) ~= "table" then
        return false
      elseif type(v) == "table" then
        -- desired = {{"a"}} received = {{"a"}} -> desired={"a"} received={"a"}
        local res, err = rock.compare_output(v, received[k])
        if res == nil then return nil, err
        elseif not res then return false end
      elseif received[k] ~= v then
        return false
      end
    end
    return true
  end
end

rock.gather_output = function (name, func, input, output)
  if type(name) ~= "string" then return nil, "name is not string" end
  if type(func) ~= "function" then return nil, "func is not function" end
  local results = {
    name=name,
    func=func,
    input=input,
    output=output,
  }
  if type(input) == "table" then
    results.result = {pcall(func, unpack(input))}
  else
    results.result = {pcall(func, input)}
  end
  return results
end

rock.test_isolated_functions = function ()
  local emit = require "emit"
  
  return "✔"
end

rock.run = function ()
  -- Find functions in this module that start with test_
  for name,func in pairs(rock) do
    if name:match("test_.+") then
      local result, err = pcall(func)
      if not result then
        emit.err("Error in test %s: %s", name, err)
        rock.results[name] = tostring(err)
      else
        rock.results[name] = result
      end
    end
  end
  return "♻️"
end

return rock
