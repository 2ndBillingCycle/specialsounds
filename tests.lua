local rock = {}

local emit = require "emit"
---[====[ Test functions
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

local function prints_stuff ()
  emit.print("Hi! Testing")
  emit.info("Here's some info")
  emit.err("Uhoh, an error!")
  emit.write("Wrote it!")
end

rock.test_print_capture = function ()
 local get_prints = emit.record_prints()
 prints_stuff()
 local print_records = get_prints()
 return header.compare_tables(print_records, {
   {"print", "Hi! Testing"},
   {"info",  "Here's some info"},
   {"err",   "Uhoh, an error!"},
   {"write", "Wrote it!"},
 })
end
--]==]

--[==[ Each case table looks like this
The case table is a list of inputs (and outputs) to be fed to the function that is being tested.

Each element can either be a straight value, in which case the output is expected to be a literal true,
or can be a table with two keys: input and output.

Both the input and output keys can be either straight values, or can be tables.

If the input is a table, it is trated as an array of arguments to pass as inputs to the function,
and it is unpack()'d. If the output is a table, the function is assumed to return multiple values,
and each of its return values will be compared, in order, to the array in output.

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
        expected_output={nil, [[
Unbalanced parenthesis: missing )

This is the group:
(error

The full command is:
/nil (error]]},
      },
      {
        input="error)",
        expected_output={
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
    },
  },
}

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
        expected_output=
-- NOTE: The spaces indenting a nonexistent value in the key
-- that's an empty table are undesired
[=[{
  {
    key = [[value]]
  },
  [{}] = -0.01,
  [1.1] = [[
]]
}]=],
      },
    },
  },
}

-- If we're doing these tests for a build, remove the tests we're still
-- working on
-- NOTE: Could this be run twice if it's imported twice?
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

return rock
