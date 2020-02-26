local rock = {}
-- This file contains the testing framework
-- NOTE: Test runner does not yet isolate tests; subsequent cases will see the state from previous runs

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
   --     expected_prints={"expected strings"}
   --     print_output={"printed string"},
   --     comparison=rock.compare_output(output, expected_output)
   --                and header.compare_tables(expected_prints, print_output)
   --     err="error string returned by test runner itself; may be nil if no error",
   --   }
rock.results = {}

rock.perform_test = function (name, func, test_case)
  if type(name) ~= "string" then error("name is not string") end
  if type(func) ~= "function" then error("func is not a function") end
  if type(test_case) ~= "table" then error("test_case must be a table") end

  if test_case.expected_output == nil then error("expected output is nil") end
  if test_case.expected_prints == nil then test_case.expected_prints = {} end
  local results = {
    name=name,
    func=func,
    input=test_case.input,
    expected_output=test_case.expected_output,
    expected_prints=test_case.expected_prints,
  }
  local get_prints = emit.record_prints()
  if type(test_case.input) == "table" then
    results.output = {xpcall(
                              function ()
                                return func(unpack(test_case.input))
                              end,
                              debug.traceback
                            )}
  else
    results.output = {xpcall(
                              function ()
                                return func(test_case.input)
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
    results.comparison = rock.compare_output(test_case.expected_output, results.output)
                                and header.compare_tables(test_case.expected_prints, results.print_output)
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

rock.perform_simple_test = function (name, func, input)
  if type(name) ~= "string" then error("name is not string") end
  if type(func) ~= "function" then error("func is not a function") end
  local results = {
    name=name,
    func=func,
    input=input,
  }
  local get_prints = emit.record_prints() -- Suppresses printing during test runs
  results.output = {xpcall(
                            function ()
                              return func(input)
                            end,
                            debug.traceback
                          )}
  get_prints() -- We don't need the output
  results.err = not table.remove(results.output, 1)
  if results.err then
    results.err = table.remove(results.output, 1)
  else
    results.comparison = results.output[1] and true or false
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
  if tests.cases == nil then error("tests.lua missing case table") end
  for name,case in pairs(tests.cases) do
    if type(name) ~= "string" then error("tests.cases should be a map of function names to case sets") end
    if type(case.func) ~= "function" then error("func must be a Lua function") end
    case.name = name
    emit.print("Function: %s", case.name)
    for i,test_case in ipairs(case.cases) do
      if type(test_case) == "table" then
        rock.perform_test(
          case.name,
          case.func,
          test_case
        )
      else
        rock.perform_simple_test(
          case.name,
          case.func,
          test_case
        )
      end
    end
    emit.write("\n")
  end
  emit.write("\n")
  return "."
end

rock.summarize_test_results = function (test_results)
  -- flag to indicate if any failures or errors happened during testing
  local all_passed = true
  emit.print("\nTest results:\n")
  local pass = {}
  local fail = {}
  local errs = {}
  for i,result in ipairs(rock.results) do
    local name = result.name
    local input = result.input ~= nil and assert(emit.format("input:\n%s", result.input)) or false
    -- If the name hasn't been seen yet, set its pass, fail, and err
    -- counts to 0
    if not pass[name] then
      pass[name] = {count=0}
      fail[name] = {count=0}
      errs[name] = {count=0}
    end
    if result.err then
      table.insert(errs[name], assert(emit.format(
        "Error in test:\n"..(input and input.."\n" or "").."error:\n%s\n",
        result.err
      )))
      errs[name].count = errs[name].count + 1
    elseif result.comparison ~= nil and not result.comparison then
      local fail_str = "Test failure:\n"
      if input then fail_str = fail_str..input.."\n" end
      if result.expected_output ~= nil then
        fail_str = fail_str..assert(emit.format("expected:\n%s", result.expected_output)).."\n"
      end
      fail_str = fail_str..assert(emit.format("output:\n%s", result.output)).."\n"
      if type(result.expected_prints) == "table" then
        fail_str = fail_str..assert(emit.format("expected prints:\n%s", result.expected_prints)).."\n"
      end   
      if type(result.print_output) == "table" then
        fail_str = fail_str..assert(emit.format("prints:\n%s", result.print_output)).."\n"
      end
      fail[name][#fail[name] + 1] = fail_str
      fail[name].count = fail[name].count + 1
    else
      pass[name].count = pass[name].count + 1
    end
  end
  for name,tbl in pairs(pass) do
    if #fail[name] > 0 or #errs[name] > 0 then
      all_passed = false
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
  -- If there was a failure or error, in any test, fail the whole thing.
  -- If a test is supposed to fail, or error, wrap it in a function that checks for the
  -- correct failure or error message.
  return all_passed
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
     -- expected_prints={"expected strings"}
     -- print_output={"printed string"},
     -- comparison=rock.compare_output(output, expected_output)
     --            and header.compare_tables(expected_prints, print_output)
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
        results.err = table.remove(results.output, 1)
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
  -- Return the value of the test summarization as the overall result of testing:
  -- If there was a failure or error, in any test, fail the whole thing.
  -- If a test is supposed to fail, or error, wrap it in a function that checks for the
  -- correct failure or error message.
  return rock.summarize_test_results(rock.results)
end

-- If this was run as a script: lua test.lua,
-- then just run the main function
if _G.arg and type(arg[0]) == "string" and (arg[0]):match("test") then
  assert(rock.run())
end
return rock
