local rock = {}
-- This file contains all of the tests that are run by the testing framework

local emit = require "emit"
local header = require "header"

---[====[ Example test functions
-- Simple test for success
rock.passing_test = function ()
  local function success ()
    return true
  end

  return success() == true
end

-- Simple test for failure (checks for correct failure reason)
rock.failure_test = function ()
  local function fails ()
    return nil, "Error message"
  end

  local return_values = {fails()}

  return return_values[1] == false and
         return_values[2]:match("Error message")
end

-- Simple test for error (tests for the correct error message)
rock.error_test = function ()
  local function throws_error ()
    error("This error is intentional")
  end

  local return_values = {pcall(throws_error)}
  return return_values[1] == false and
         type(return_values[2]) == "string" and
         return_values[2]:match("This error is intentional")
end

local function prints_stuff ()
  return {
    emit.print("Hi! Testing"),
    emit.info("Here's some info"),
    emit.err("Uhoh, an error!"),
    emit.write("Wrote it!"),
  }
end

rock.test_print_capture = function ()
 local get_prints = emit.record_prints()
 local return_value = prints_stuff()
 local print_records = get_prints()
 return header.compare_tables(print_records, {
   {"print", "Hi! Testing"},
   {"info",  "Here's some info"},
   {"err",   "Uhoh, an error!"},
   {"write", "Wrote it!"},
 })
    and header.compare_tables(return_value, {
      "Hi! Testing",
      "Here's some info",
      "Uhoh, an error!",
      "Wrote it!",
    })
end
-- Example test functions ]====]

---[====[ Testing framework test suite
-- NOTE: Any unexpected failures here should be errors
-- Don't want the tests to continue when the testing framework is failing
local test = require "test"
local tft = {} -- Testing Framework Tests

tft.test_perform_simple_test = function ()
  -- Utility functions
  local function check_error (func, error_message)

    string.escape_pattern = function(str)
      str = (str:gsub(quotepattern, "%%%1")
                :gsub("^^", "%%^")
                :gsub("$$", "%%%$"))
      return str
    end

    local return_values = {xpcall(func, debug.traceback)}
    return not return_values[1] and
           return_values[2]:match( error_message:escape_pattern() ),
           error_message -- assert() will throw this, so it's easier to find the check that failed
  end
  
  -- Test input value type checking
  assert(check_error(
    function ()
      return test.perform_simple_test(123, function()end, {})
    end,
    "name must be a string"
  ))

  assert(check_error(
    function ()
      return test.perform_simple_test("", 123, {})
    end,
    "func must be a function"
  ))

  -- Test elided input
  local return_values = {xpcall(
    function ()
      return test.perform_simple_test("name", function()end)
    end,
    debug.traceback
  )}
  if not (
          return_values[1] == true and
          type(return_values[2]) == "table" and
          type(return_values[2].xpcall_return) == "table"
         )
     then
    error("input should be optional for perform_simple_test, but isn't")
  end

  -- Test a failing, silent function
  local function failing_silent ()
    return false
  end

  -- NOTE: Need to validate the returned table's contents
  assert(xpcall(
    function ()
      return test.perform_simple_test("name", failing_silent)
    end,
    debug.traceback
  ))
  -- Test a failing, chatty function
  local function
  -- Test a succeeding, silent function
  -- Test a succeeding, chatty function
  -- Test an erroring, silent function
  -- Test an erroring, chatty function
    
end

rock.test_summarize_test_results_failures = function ()
  local function example_function () end
  local example_xpcall_return = {xpcall(example_function, debug.traceback)}

  local test_results = {
    [example_function] = {
      {
        name="example function",
        expected_output={true},
        xpcall_return=example_xpcall_return,
      },
      {
        name="example function",
        expected_output={nil},
        xpcall_return=example_xpcall_return,
      },
    },
  }

  local expected_summary = 
[[
example function results:
failures: 1

expected output:
true

actual output:
nil
]]

  local summary = (require "test").summarize_test_results(test_results)
  return expected_summary == summary
end

rock.test_summarize_test_results_errors = function ()
  local function example_function ()
    error("Error message")
  end
  local xpcall_return = {xpcall(example_function, debug.traceback)}

  local test_results = {
    [example_function] = {
      {
        name="example function",
        expected_output={nil},
        xpcall_return=example_xpcall_return,
      },
      {
        name="example function",
        expected_error="",
        xpcall_return=example_xpcall_return,
      },
      {
        name="example function",
        expected_error="Error message",
        xpcall_return=example_xpcall_return,
      },
    },
  }

  local expected_summary =
[[
example function results:
failures: 1

expected error:


actual error:
Error message

errors: 1

expected output:
nil

Got error instead:
Error message
]]

  local summary = (require "test").summarize_results(test_results)
  return expected_summary == summary
end


rock.test_summarize_results_prints = function ()
  -- Printed and returned what was expected
  local test_results = {
    [prints_stuff] = {
      {
        name="prints stuff",
        expected_output=rock.cases_print_example[1].expected_output,
        expected_prints=rock.cases_print_example[1].expected_prints,
        xpcall_return={xpcall(prints_stuff, debug.traceback)},
      },
    },
  }

  -- Failed to print anything and succeeded
  local function doesnt_print () return true end

  test_results = {
    [doesnt_print] = {
      {
        name="Doesn't print",
        expected_output={true},
        expected_prints={{"print", "anything"}},
        xpcall_return={xpcall(doesnt_print, debug.traceback)},
      },
    },
  }

  -- Failed to print anything and failed
  local function silent_failure () return false end

  test_results = {
    [silent_failure] = {
      {
        name="Silent failure",
        expected_output={true},
        expected_prints={{"print", "anything"}},
        xpcall_return={xpcall(silent_failure, debug.traceback)},
      },
    },
  }

  -- Printed the right type but the wrong message and succeeded
  local function say_what_i_want ()
    emit.print("The wrong thing")
    return true
  end

  test_results = {
    [say_what_i_want] = {
      {
        name="I say what I want!",
        expected_output={true},
        expected_prints={{"print", "The correct thing"}},
        xpcall_return={xpcall(silent_failure, debug.traceback)},
      },
    },
  }

  -- Printed the right type and message, but failed
  local function said_but_didnt_do ()
    emit.print("The correct thing")
    return false
  end

  test_results = {
    [said_but_didnt_do] = {
      {
        name="Said but didn't do",
        expected_output={true},
        expected_prints={{"print", "The right thing"}},
        xpcall_return={xpcall(said_but_didnt_do, debug.traceback)},
      },
    },
  }

  -- Printed the right type but the wrong message and failed


  -- Printed the wrong type but the right message and succeeded
  -- Printed the wrong type but the right message and failed
  local function wrong_type_fail ()
    emit.info("Hi")
    return false
  end

  test_results = {
    [wrong_type_fail] = {
      {
        name="Wrong type, correct message, failed",
        expected_output={true},
        expected_prints={{"print", "Hi"}},
        xpcall_return={xpcall(wrong_type_fail, debug.traceback)},
      },
    },
  }

  -- Printed wrong thing and failed
  local function everything_wrong ()
    emit.print("The wrong thing")
    return false
  end

  -- Not expected to print anything (unexpected print) and succeeded
  local function chatty_success ()
    emit.print("Hi!")
    return true
  end

  -- Not expected to print anything (unexpected print) and failed
  local function chatty_failure ()
    emit.print("Hi!")
    return false
  end

end
-- Test functions [====]

--[==[ Case table structure
The case table is a list of inputs (and outputs) to be fed to the function that is being tested.

The keys are:
name = the name of the function
func = the function

Each element can be one of two things: A table or anything other than a table (excluding nil).

If it's not a table, the value is passed to the function, and the output is expected to be truthy.

If it's a table, it's expected to have at least these keys:

- input: an array of value to pass as the arguments to the function under test

It may also have only one of these keys:

- expected_error: a string that uses Lua patterns to match against the error message as returned by
                  xpcall(func, debug.traceback)
- expected_output: an array of outputs expected from the function (can be omitted if none are expected

It may optionally contain the keys:

- expected_prints: an array where each element is a pair of strings, the first indicating
                   which print function was expected, the second indicating the message expected.
                   For example:

expected_prints = {
  {"print", "Hi! Testing"},
  {"info", "Here's some info"},
  {"err", "Uhoh, an error!"},
  {"write", "Wrote it!"},
}

If the input and/or output need to be tables, input and expected_output must still be arrays, and so can have a
table as their only element: an input specified as input={{key="value"}} will pass the table {key="value"} as
the first and only argument to the function under test.
-- Case table structure ]==]

---[=======[ Case tables
rock.cases_print_example = {
  name = "print example",
  func=prints_stuff,
  {
    input={},
    expected_output={{
      "Hi! Testing",
      "Here's some info",
      "Uhoh, an error!",
      "Wrote it!",
    }},
    expected_prints={
      {"print", "Hi! Testing"},
      {"info", "Here's some info"},
      {"err", "Uhoh, an error!"},
      {"write", "Wrote it!"},
    },
  },
}

rock.cases_lexer_lex = {
  name = "lexer.lex",
  func = (require "lexer").lex,
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
    input={"(error"},
    expected_error={nil, [[
Unbalanced parenthesis: missing )

This is the group:
(error

The full command is:
/nil (error]]},
  },
  {
    input={"noerror)"},
    expected_output={
      {
        {name="text", value="noerror)"},
      },
    },
  },
}

rock.cases_emit_to_string = {
  name = "emit.to_string",
  func = emit.to_string,
  {
    input={{1, 2, 3}},
    expected_output="{1, 2, 3}",
  },
  {
    input={{-91,nil,nil,400,.0,nil}},
    expected_output="{-91, nil, nil, 400, 0}",
  },
  {
    input={{key="value"}},
    expected_output="{key = [[value]]}",
  },
  {
    input={{[1]="value"}},
    expected_output="{[[value]]}",
  },
  {
    input={{[1.1]="2"}},
    expected_output="{[1.1] = [[2]]}",
  },
  {
    input={{1,[1.1]="2",3}},
    expected_output="{\n  1,\n  3,\n  [1.1] = [[2]]\n}",
  },
  {
    input={{1,2,3,[1.1]="a",[{1,key="value"}]={1,key="value"}}},
    expected_output=
[=[{
  1,
  2,
  3,
  [1.1] = [[a]],
  [{
    1,
    key = [[value]]
  }] = {
    1,
    key = [[value]]
  }
}]=],
  },
  {
    input={{[{1,2}]={1,2}}},
    expected_output="{[{1, 2}] = {1, 2}}",
  },
  {
    input={{1, {2, {3, nil, nil, 4}, nil, 5}, nil, 6}},
    expected_output="{1, {2, {3, nil, nil, 4}, nil, 5}, nil, 6}",
  },
  {
        input={{[{}] = -0.01, [1.1] = "\n", {key = "value"}}},
        expected_output=
-- NOTE: The spaces indenting a nonexistent value in the key
-- which is an empty table are undesired
[=[{
  {
    key = [[value]]
  },
  [{}] = -0.01,
  [1.1] = [[
]]
}]=],
  },
}

-- Case tables ]=======]

return rock
