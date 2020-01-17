--[[
I would like this to be a nicer test runner.

I think that'll require coroutines, as I'd like a running output, where each test section is printed, followed by a string of . for success and ❌ or X:

```text
test_lexer
.........X..X......X
test_parser
...X.......X...

results:

test_lexer: 2

input:
"(error"

error:
Mismatched parenthesis error


input:
{key = "value"}

output:
{}

expected error:
str needs to be string
...
```

I would like the following features:

- Specify the function to be tested
- Provide input
- - Optionally specify the output to match to determine if the function worked
- - Maybe specify the messages that should be printed
- Maybe write out test inputs and outputs of failed tests as they go
- Summarize the test results for each function, as well as the total pass %
- Support pre-tasks/setup for when main.lua gets tested

NOTE: Test runner does not yet isolate tests; subsequent cases will see the state from previous runs
--]]

local rock = {}

local header = require "header"
local emit = require "emit"

rock.cases = {
  ["lexer.lex"]={
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
      {
        input="error)",
        output={
          {{name="text", value="error)"}}
        },
      },
    },
  },
  ["emit.to_string"]={
    func=emit.to_string,
    cases = {
      {
        input={{1, 2, 3}},
        output="{1, 2, 3}",
      },
      {
        input={{-91,nil,nil,400,.0,nil}},
        output="{-91, nil, nil, 400, 0}",
      },
      {
        input={{key="value"}},
        output="{key = \"value\"}",
      },
      {
        input={{[1]="value"}},
        output="{\"value\"}",
      },
      {
        input={{[1.1]="2"}},
        output="{[1.1] = \"2\"}",
      },
      {
        input={{1,[1.1]="2",3}},
        output="{\n  1,\n  3,\n  [1.1] = \"2\"\n}",
      },
      {
        input={{1,2,3,[1.1]="a",[{1,key="value"}]={1,key="value"}}},
        output=
[[{
  1,
  2,
  3,
  [1.1] = "a",
  [{
    1,
    key = "value"
  }] = {
    1,
    key = "value"
  }
}]],
      },
      {
        input={{[{1,2}]={1,2}}},
        output="{[{1, 2}] = {1, 2}}",
      },
      {
        input={{1, {2, {3, nil, nil, 4}, nil, 5}, nil, 6}},
        output="{1, {2, {3, nil, nil, 4}, nil, 5}, nil, 6}",
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
  if type(desired) ~= "table" or type(received) ~= "table" then
    error("args must be tables")
  end
  -- pull out each element of the desired table, and compare to each element of received
  for k,v in pairs(desired) do
    -- first, types must match
    if type(v) ~= type(received[k]) then
      return false
    -- if they're tables, take those tables and run this function against them
    elseif type(v) == "table" then
      -- desired = {{"a"}} received = {{"a"}} -> desired={"a"} received={"a"}
      local res, err = rock.compare_output(v, received[k])
      if not res then return res, err end
    -- otherwise compare the values
    elseif received[k] ~= v then
      return false
    else
      --emit.print("passed")
    end
  end
  return true
end

rock.compare_output = function (desired, received)
--[[ Received is from pcall:
function f () return nil, "error" end
received = {pcall(func)}
for k,v in pairs(received) do
  print(k.."="..tostring(v))
end
1=true
3=error

  index 2 is nil

Desired is either true, or the output key in a test case:
{
  input="string",
  output="string,
},
{
  input="string",
  output={"multile","return","values"},
},
{
  input="string",
  output={{key="value"}},
}
--]]
  -- received output must always be a table
  if type(received) ~= "table" then error("received not table") end
  -- Did xpcall catch an error?
  if not received[1] then
    return false
  end
  -- Are we comparing error output?
  if type(desired) == "table" and desired[1] == nil and type(desired[2]) == "string" then
    return desired[2] == received[3] -- Check if the error matches
  -- If the desired value is a literal true, test received for truthiness
  elseif desired == true then
    if received[2] then return true else return false end
  -- If it's a simple type, compare the values
  elseif type(desired) ~= "table" then
    return desired == received[2]
  elseif type(desired) == "table" then
    -- desired is a table, and does not indicate an error condition
    return rock.compare_tables(desired, received[2])
  else
    error("unkown desired/received sructure")
  end
end

---[[ Each element of the results array should look like this:
   --   {
   --     name="function name",
   --     func=function,
   --     input="input argument(s)",
   --     output="desired output",
   --     result={func(input)},
   --     print={"printed string"},
   --     comparison=rock.compare_output(output, result),
   --     err="error string returned by test runner itself; may be nil if no error",
   --   }
rock.results = {}

rock.add_result = function (name, func, input, output, result, print, comparison, err)
  local last_result = rock.results[ #rock.results ]
  if type(last_result) == "table" and
     last_result.name == name and
     last_result.func == func and
     last_result.input == input and
     last_result.output == output and
     type(last_result.name) == "string" and
     type(last_result.func) == "function" and
     type(last_result.input) ~= "nil" and
     type(last_result.output) ~= "nil" then

    last_result.result = result
    last_result.print = print
    last_result.comparison = comparison
    last_result.err = err
  else
    table.insert(rock.results, {
      name=name,
      func=func,
      input=input,
      output=output,
      result=result,
      print=print,
      comparison=comparison,
      err=tostring(err),
    })
  end
end

rock.test_simple_pass = function ()
  return true
end

rock.test_simple_fail = function ()
  return false
end

rock.test_simple_error = function ()
  error("This error is intentional")
end

rock.test_expected_fail = function ()
  local f_err, result, err = pcall(rock.test_simple_fail)
  return err ~= "This error is intentional"
end

rock.test_expected_err = function ()
  local f_err, result, err = pcall(rock.test_simple_error)
  return not f_err and result:match("This error is intentional")
end

rock.perform_test = function (name, func, input, output)
  if type(name) ~= "string" then error("name is not string") end
  local results = {
    name=name,
    func=func,
    input=input,
    output=output,
  }
  local get_output = emit.record_output()
  if type(input) == "table" then
    results.result = {xpcall(
                              function ()
                                return func(unpack(input))
                              end,
                              debug.traceback
                            )}
  else
    results.result = {xpcall(
                              function ()
                                return func(input)
                              end,
                              debug.traceback
                            )}
  end
  results.print = get_output()
  -- We do the comparison here as we want to be able to print out a running line of ...x...XO..
  -- NOTE: It'd be ideal to not have errors from compare_output() be mixed in with errors from
  -- running the test, but I guess those errors would show up in the xpcall()
  results.comparison, results.err = rock.compare_output(output, results.result)
  if results.comparison then
    emit.write(".") 
  elseif results.err then
    emit.write("X")
  else
    emit.write("x")
  end
  table.insert(rock.results, results)
  return "."
end

rock.input_output_tests = function ()
  -- For each case suite, run through the test cases, and perform the test
  for name,case in pairs(rock.cases) do
    case.name = name
    emit.print("Function: %s", case.name)
    for i,test_case in ipairs(case.cases) do
      local input = ""
      local output = ""
      if type(test_case) == "table" then
        input = test_case.input
        output = test_case.output
      else
        input = test_case
        output = true -- Default is to test if the function returns a truthy value
      end

      local check, err = rock.perform_test(
        case.name,
        case.func,
        input,
        output
      )

      if not check then
        -- Store an error string in place of the result table
        rock.add_result(
          case.name,
          case.func,
          input,
          output,
          result,
          nil,
          err
        )
        emit.write("O") -- Indicate a predictable error in the test functions
      end
    end
    emit.write("\n")
  end
  emit.write("\n")
  return "."
end

rock.summarize_test_results = function (test_results)
  emit.print("\nTest results:\n")
  local pass = {}
  local fail = {}
  local errs = {}
  for i,result in ipairs(rock.results) do
    local name = result.name
    -- If the name hasn't been seen yet, set its pass, fail, and err
    -- counts to 0
    if not pass[name] then
      pass[name] = {count=0}
      fail[name] = {count=0}
      errs[name] = {count=0}
    end
    if result.err ~= nil and result.err then
      table.insert(errs[name], emit.format(
[[
Error in test:
input:
%s
error:
%s
]],
        result.input or "",
        result.err
      ))
      errs[name].count = errs[name].count + 1
    elseif result.comparison ~= nil and not result.comparison then
      table.insert(fail[name], emit.format(
[[
Test failure:
input:
%s
output:
%s
pass output:
%s
]],
        result.input or "",
        result.result,
        result.output or ""
      ))
      fail[name].count = fail[name].count + 1
    else
      pass[name].count = pass[name].count + 1
    end
  end
  for name,tbl in pairs(pass) do
    if #fail[name] > 0 or #errs[name] > 0 then
      emit.print("Results for %s\n", name)
    end
    for i,message in ipairs(fail[name]) do
      emit.print(message)
    end
    for i,message in ipairs(errs[name]) do
      emit.print(message)
    end
  end
  emit.print("\nSummary:")
  for name,_ in pairs(pass) do
    emit.print(
      [[
Function: %s
pass: %s
fail: %s
error: %s
]],
      name,
      pass[name].count,
      fail[name].count,
      errs[name].count
    )
  end
  return true
end

rock.wip_tests = {
  "test_simple_pass",
  "test_simple_fail",
  "test_simple_error",
  "test_expected_fail",
  "test_expected_err",
}

rock.wip_cases = {
  {
    name="emit.to_string",
    cases = {
      {
        input={{[{}] = -0.01, [1.1] = "\n", {key = "value"}}},
        output=
-- NOTE: The spaces indenting a nonexistent value in the key
-- that's an empty table are undesired
[[{
  {
    key = "value"
  },
  [{}] = -0.01,
  [1.1] = "\n"
}]],
      },
    },
  },
}

rock.run = function ()
  -- If we're doing these tests for a build, remove the tests we're still
  -- working on
  if skip_wip_tests then
    for i,v in ipairs(rock.wip_tests) do
      rock[v] = nil
    end
  else
    -- If this is a run during feature building, add the tests we're working on
    for i,case_tbl in ipairs(rock.wip_cases) do
      for i,case in ipairs(case_tbl.cases) do
        table.insert(rock.cases[case_tbl.name].cases, case)
      end
    end
  end
  -- Turn off pretty_printing of tables during tests, as that function is used
  -- to print error messages, as an error thrown during printing error messages
  -- would make finding the error in emit.to_string more difficult
  emit.pretty_printing = false
  -- Find functions in this module that start with test_ and run them
  emit.print("unit tests:")
  for name,func in pairs(rock) do
    if name:match("^test_.+") then
      local results = {
        name=name,
        func=func,
   --     input="input argument(s)",
   --     output="desired output",
   --     result={func(input)},
   --     print={"printed string"},
   --     comparison=rock.compare_output(output, result),
   --     err="error string returned by test runner itself; may be nil if no error",

      }
      local get_records = emit.record_output()
      results.result = {xpcall(
                                function ()
                                  return func(results)
                                end,
                                debug.traceback
                       )}
      results.print = get_records()
      results.err = not results.result[1]
      results.input = ""
      results.output = table.remove(header.copy(results.result), 1)
      if results.err then
        results.comparison = false
        emit.write("X")
      else
        results.comparison = results.result[2] and true or false
        if not results.comparison then
          emit.write("x")
        else
          emit.write(".")
        end
      end
      rock.results[ #rock.results + 1] = results
    end
  end
  emit.write("\n")
  emit.print("input/output tests:")
  rock.input_output_tests()
  -- Turn pretty printing back on for test summaries; this could still error
  emit.pretty_printing = true
  local success, err = rock.summarize_test_results(rock.results)
  if not success then return success, "Error in test summarization" end
  return "tested"
end

return rock
