local rock = {}
-- This file contains the testing framework
-- NOTE: Test runner does not yet isolate tests; subsequent cases will see the state from previous runs

--[=[ Recipe for sandboxing code
from: https://www.slideshare.net/jgrahamc/lua-the-worlds-most-infuriating-language

local env = { print = print }
local envmeta = { __index={}, __newindex=function() end }
setmetatable(env,envmeta)

function run(code)
  local f = loadstring(code)
  setfenv(f, env)
  pcall(f)
end

run([[
  local x = "Hello, world!"
  print(x)
  local y = string.len(x)    -- Will throw error, as only print is defined in the "global" table
]])

Also, note from: http://www.lua.org/manual/5.1/manual.html#pdf-_G

"Lua itself does not use [_G]; changing its value does not affect any environment, nor vice-versa. (Use setfenv to change environments.)"
-- Recipe for sandboxing code ]=]

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

--[[ Results dictionary structureEach element of the results array should look like this:
{
  name="function name",
  input={"table of", "input argument(s)"},
  expected_output={"table of", "expected output"},
  expected_prints={{"print", "expected strings"}},
  print_output={{"print", "printed strings"},
  expected_error="error string expected to be returned by the function",
  xpcall_return={false, "Values returned by xpcall"}
}
-- Results dictionary structure ]]
rock.results = {}

rock.add_result = function(func, result_table)
  if type(func) ~= "function" or type(result_table) ~= "table" then
    error("func must be a function, result_table a table")
  end
  if type(rock.results[func]) == "table" then
    table.insert(rock.results[func], result_table)
  else
    rock.results[func] = {result_table}
  end
  return true
end

rock.perform_test = function (name, func, test_case)
  if type(name) ~= "string" then error("name is not string") end
  if type(func) ~= "function" then error("func is not a function") end
  if type(test_case) ~= "table" then error("test_case must be a table") end

  if test_case.expected_output == nil and test_case.expected_error == nil then
    error("One of expected_output or expected_error is needed")
  end
  if test_case.expected_prints == nil then test_case.expected_prints = {} end
  local results = {
    name=name,
    input=test_case.input,
    expected_output=test_case.expected_output,
    expected_error=test_case.expected_error,
    expected_prints=test_case.expected_prints,
  }
  local get_prints = emit.record_prints()
  results.xpcall_return = {xpcall(
                            function ()
                              return func(unpack(test_case.input))
                            end,
                            debug.traceback
                          )}
  results.print_output = get_prints()
  return results
end

rock.perform_simple_test = function (name, func, input)
  if type(name) ~= "string" then error("name is not string") end
  if type(func) ~= "function" then error("func is not a function") end
  local results = {
    name=name,
    input=input,
    expected_output=true,
    expected_prints={},
  }
  local get_prints = emit.record_prints() -- Suppresses printing during test runs
  results.xpcall_return = {xpcall(
                             function ()
                               return func(input)
                             end,
                             debug.traceback
                          )}
  get_prints() -- We don't need the output
  return results
end

rock.run_case_tests = function ()
  -- For each case suite, run through the test cases, and perform the test
  local tests = require "tests"
  for name, case_table in pairs(tests) do
    if type(case_table) == "table" and name:match("^case_.+") then
      emit.print("Function: %s", case_table.name)
      for i,test_case in ipairs(case_table) do
        if type(test_case) == "table" then
          local results = rock.perform_test(
            case_table.name,
            case_table.func,
            test_case
          )
        else
          local results = rock.perform_simple_test(
            case_table.name,
            case_table.func,
            test_case
          )
        end
        if type(results) ~= "table" then error("Results not table") end
        rock.add_result(func, results)
      end
      emit.write("\n")
    end
  emit.write("\n")
  return true
end

rock.summarize_test_results = function (test_results)
  -- This function goes through the results table, pulling out the runs for each function,
  -- doing the following:
  -- 
  -- - Prints nothing if the function passed the test
  -- - If it failed,
  --   - Prints out the name of the function that ran the test, or
  --   - Prints out the input for each run, if there was any
  --   - Prints the output and expected output, or
  --   - Prints out the error message and expected error message, or
  --
  -- At the end, it prints out the number of failures and errors overall
  -- Printing out the count for each case is unnecessary: That's what the test coverage
  -- reports are for, and anyways, stuff shouldn't be failing.
  -- flag to indicate if any failures or errors happened during testing

  local summaries = {}
  -- Process the results for each function
  for func,results in pairs(test_results) do
    summaries[func] = summarize_results(func, results)
  end

  local summary_reports = {}
  for func,summary in pairs(summaries) do
    table.insert(summary_reports, summary_report(func, summary))
  end

  local all_summaries = ""
  for _,summary in ipairs(summary_reports) do
    all_summaries = all_summaries.."\n\n"..summary
  end

  if any_errors_or_failures(summaries) then
    return false, all_summaries
  else
    return true, all_summaries
  end
end
--[===[
rock.summarize_test_results = function (test_results)
  local all_passed = true
  emit.print("\nTest results:\n")
  local pass = {}
  local fail = {}
  local errs = {}
  for func,results in pairs(rock.results) do
    for i, result in ipairs(results) do
    local name = result.name
    if result.input == nil then
      local input_str = false
    else
      local input_str = assert(emit.format("input:\n%s", result.input))
    end
    -- If the name hasn't been seen yet, set its pass, fail, and err
    -- counts to 0
    if not pass[name] then
      pass[name] = {count=0}
      fail[name] = {count=0}
      errs[name] = {count=0}
    end
    -- Using result.xpcall_return, determine if the function did what it was supposed to do, failed, or errored
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
  --]===]

rock.run_test_functions = function ()
  local tests = require "tests"
  for name,func in pairs(tests) do
    if type(func) == "function" and name:match("^test_.+") then
      local func_name = name:match "^test_(.+)"
      emit.print(func_name)
      rock.add_result(
        func,
        rock.perform_simple_test(name, func, nil)
      )
    end
  end
  return true
end

rock.run_test_functions = function ()
  local tests = require "tests"
  for name,func in pairs(tests) do
    if type(func) == "function" and name:match("^test_.+") then
      local func_name = name:match "^test_(.+)"
      emit.print(func_name)
      rock.add_result(
        func,
        rock.perform_simple_test(name, func, nil)
      )
    end
  end
  return true
end

rock.run = function ()
  -- Turn off pretty_printing of tables during tests, as that function is used
  -- to print error messages, as an error thrown during printing error messages
  -- would make finding the error in emit.to_string more difficult
  emit.pretty_printing = false
  -- Find functions in this module that start with test_ and run them
  emit.print("Running unit tests")
  assert(rock.run_test_functions())
  emit.write("\n")
  emit.print("input/output tests")
  assert(rock.run_case_tests())
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
