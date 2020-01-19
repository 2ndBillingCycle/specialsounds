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
local tests = require "tests"

rock.compare_output = function (expected_output, output)
  -- output output must always be a table
  if type(output) ~= "table" then error("output not table") end
  -- Are we comparing error output?
  if type(expected_output) == "table"
     and expected_output[1] == nil
     and type(expected_output[2]) == "string" then
    return not output[1] and expected_output[2] == output[2] -- Check if the error matches
  -- If the expected_output value is a literal true, test output for truthiness
  elseif expected_output == true then
    if output[1] then return true else return false end
  -- If it's a simple type, compare the values
  elseif type(expected_output) ~= "table" then
    return expected_output == output[1]
  elseif type(expected_output) == "table" then
    -- expected_output is a table, and does not indicate an error condition
    return header.compare_tables(expected_output, output)
  else
    error("unkown expected_output/output sructure")
  end
end

---[[ Each element of the results array should look like this:
   --   {
   --     name="function name",
   --     func=function,
   --     input="input argument(s)",
   --     expected_output="expected output",
   --     output={func(input)},
   --     expected_print={"expected strings"}
   --     print_output={"printed string"},
   --     comparison=rock.compare_output(output, expected_output)
   --                and header.compare_tables(expected_print, print_output)
   --     err="error string returned by test runner itself; may be nil if no error",
   --   }
rock.results = {}

rock.perform_test = function (name, func, input, expected_output, expected_print)
  if type(name) ~= "string" then error("name is not string") end
  if type(func) ~= "function" then error("func is not a function") end
  if expected_output == nil then error("expected output is nil") end
  if expected_print == nil then expected_print = {} end
  local results = {
    name=name,
    func=func,
    input=input,
    expected_output=expected_output,
    expected_print=expected_print,
  }
  local get_prints = emit.record_prints()
  if type(input) == "table" then
    results.output = {xpcall(
                              function ()
                                return func(unpack(input))
                              end,
                              debug.traceback
                            )}
  else
    results.output = {xpcall(
                              function ()
                                return func(input)
                              end,
                              debug.traceback
                            )}
  end
  results.print_output = get_prints()
  results.err = not table.remove(results.output, 1)
  if results.err then
    results.err = table.remove(results.output, 1)
  else
    -- We do the comparison here as we want to be able to print out a running line of ...x...XO..
    -- NOTE: It'd be ideal to not have errors from compare_output() be mixed in with errors from
    -- running the test, but I guess those errors would show up in the xpcall()
    results.output_comparison = rock.compare_output(expected_output, results.output)
                                and header.compare_tables(expected_print, results.print_output)
  end
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
  for name,case in pairs(tests.cases) do
    case.name = name
    emit.print("Function: %s", case.name)
    for i,test_case in ipairs(case.cases) do
      local input = ""
      local expected_output = ""
      if type(test_case) == "table" then
        input = test_case.input
        expected_output = test_case.expected_output
      else
        input = test_case
        expected_output = true -- Default is to test if the function returns a truthy value
      end

      rock.perform_test(
        case.name,
        case.func,
        input,
        expected_output
      )
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
    local input = result.input ~= nil and emit.format("\ninput:\n%s", result.input) or "\n"
    local expected_output = ""
    if result.expected_output ~= nil then
      expected_output = assert(emit.format("expected:\n%s", result.expected_output))
    end
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
Error in test:%s
error:
%s
]],
        input,
        result.err
      ))
      errs[name].count = errs[name].count + 1
    elseif result.comparison ~= nil and not result.comparison then
      table.insert(fail[name], emit.format(
[[
Test failure:%s
output:
%s
%s
]],
        input,
        result.output,
        expected_output
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

rock.run = function ()
  -- Turn off pretty_printing of tables during tests, as that function is used
  -- to print error messages, as an error thrown during printing error messages
  -- would make finding the error in emit.to_string more difficult
  emit.pretty_printing = false
  -- Find functions in this module that start with test_ and run them
  emit.print("unit tests:")
  for name,func in pairs(tests) do
    if name:match("^test_.+") and type(func) == "function" then
      local results = {
        name=name,
        func=func,
     -- input="input argument(s)",
     -- expected_output="expected output",
     -- output={func(input)},
     -- expected_print={"expected strings"}
     -- print_output={"printed string"},
     -- comparison=rock.compare_output(output, expected_output)
     --            and header.compare_tables(expected_print, print_output)
     -- err="error string returned by test runner itself; may be nil if no error",
      }
      local get_prints = emit.record_prints()
      results.output = {xpcall(
                                function ()
                                  return func(results)
                                end,
                                debug.traceback
                       )}
      results.print_output = get_prints()
      results.err = not table.remove(results.output, 1)
      if results.err then
        emit.write("X")
      end
      results.comparison = results.output[1] and true or false
      if results.comparison then
        emit.write(".")
      else
        emit.write("x")
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
