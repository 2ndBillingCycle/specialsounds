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
    cases = {
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
      {
        input="(error",
        output={nil, [[
Unbalanced parenthesis: missing )

This is the group:
(error

The full command is:
/nil (error]]},
      },
    },
  },
}

--[==[ Each case table looks like this
The case table is a list of inputs (and outputs) to be fed to the function that is being tested.

Each element can either be a straight value, in which case the output is expected to be a literal true,
or can be a table with two keys: input and output.

Both the input and output keys can be either straight values, or can be tables.

If the input is a table, it is trated as an array of arguments to pass as inputs to the function,
and it is unpack()'d. If the output is a table, the function is assumed to return multiple values,
and each of its return values will be compared, in order, tot he array in output.

If the input and/or output need to be tables, input and output must still be arrays, and so can have a
table as their only element: input={{key="value"}}

Example:
{
  "string",
  {input="string", output=false},
  {
    input={1,2,3},
    output={"a","b","c"},
  },
  {
    input={{key="value"}},
    output={{key="value"}},
  },
}
--]==]

rock.compare_tables = function (desired, received)
  if type(desired) ~= "table" or type(received) ~= "tables" then
    return nil, "args must be tables"
  end
  -- pull out each element of the desired table, and compare to each element of received
  for k,v in pairs(desired) do
    -- first, types must match
    if type(v) ~= type(received[k]) then
      return false
    end
    -- if they're tables, take those tables and run this function against them
    if type(v) == "table" then
      -- desired = {{"a"}} received = {{"a"}} -> desired={"a"} received={"a"}
      local res, err = rock.compare_output(v, received[k])
      if not res then return res, err end
    end
    -- otherwise compare the values
    return received[k] == v
  end
end

rock.compare_output = function (desired, received)
  -- received output must always be a table
  if type(received) ~= "table" then return nil, "received not table" end
  -- Did pcall catch an error?
  if not received[1] then
    return false
  else
    -- pcall didn't see any errors, so shift the first true out of the table
    table.remove(received, 1)
  end
  -- Are we comparing error output?
  if type(desired) == "table" and desired[1] == nil and type(desired[2]) == "string" then
    return desired[2] == received[2]
  -- If the desired value is a literal true, test received for truthiness
  elseif desired == true then
    if received[1] then return true else return false end
  -- If it's a simple type, compare the values
  elseif type(desired) ~= "table" then
    return desired == received[1]
  elseif type(desired) == "table" then
    -- desired is a table, and does not indicate an error condition
    return rock.compare_tables(desired, received[1])
  else
    return nil, "unkown desired/received sructure"
  end
end

--[[ Each element of the results array should look like this:
{
  name="function name",
  func=function,
  input="input argument(s)",
  output="desired output",
  result={func(input)},
  comparison=rock.compare_output(output, result),
  err="error string returned by test runner itself; may be nil if no error",
}
--]]
rock.results = {}

local emit = require "emit"
rock.perform_test = function (name, func, input, output)
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
  for k,v in pairs(results.result) do
    emit.info("k: %s\nv: %s", k, v)
  end
  results.comparison = rock.compare_output(output, results.result)
  print(results.comparison)
  table.insert(rock.results, results)
  return "."
end

rock.test_isolated_functions = function ()
  local emit = require "emit"
  -- For each case suite, run through the test cases, and perform the test
  for i,case in ipairs(rock.cases) do
    for i,test_case in ipairs(case.cases) do
      if type(test_case) == "table" then
        local input = test_case.input
        local output = test_case.output
      else
        local input = test_case
        local output = true -- Default is to test if the function returns a truthy value
      end
      local result, err = rock.perform_test(
        case.name,
        case.func,
        input,
        output
      )
      if not result then
        -- Store an error string in place of the result table
        local last_result = rock.results[ #(rock.results) ]
        if last_result.name ~= case.name or
           last_result.func ~= case.func or
           last_result.input ~= input or
           last_result.output ~= output then
          table.insert(rock.results, {
            name=case.name,
            func=case.func,
            input=input,
            output=output,
            result=nil,
            comparison=nil,
            err=tostring(err),
          })
          io.write(".")
        else
          last_result.err = tostring(err)
          io.write("x")
        end
      end
    end
  end
  io.write("\n")
  return "."
end

rock.summarize_test_results = function (test_results)
  -- Fill out later
  return "🤷‍♀️"
end

rock.run = function ()
  local results = {}
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
  local success, err = rock.summarize_test_results(rock.results)
  if not success then return success, "Error in test summarization" end
  return "♻️"
end

return rock