local rock = {}
-- This file contains all of the tests that are run by the testing framework

local emit = require "emit"
local header = require "header"

---[====[ Example test functions
rock.test_simple_pass = function ()
  return true
end

rock.test_simple_fail = function ()
  local function fails ()
    return nil, "Error message"
  end

  return not fails()
end

rock.test_simple_error = function ()
  local function throws_error ()
    error("This error is intentional")
  end

  local return_value = {pcall(throws_error)}
  return return_value[1] == false and
         type(return_value[2]) == "string" and
         return_value[2]:match("This error is intentional")
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

expected_print = {
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
  {input={}, expected_output={}},
  {
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
