# Testing

Goals for the framework:

- Specify the input to the function, as well as the expected output, and expected use of `emit`
- - Watch for spurious use of bare `print`
- Monitor state for unintended side effects
- Summarize the test results for each function, as well as the total pass %
- Support pre-tasks/setup for when main.lua gets tested
- Isolate tests (e.g. `hexchat.settings` is the same at the start of each run)
- Collect the line numbers from failed tests to aid finding them quickly

## Implementation:

The last of those points can be implemented by passing the test functions to `debug.getinfo`. That'd get pretty close for the majority of the stuff that's not defined in case tables. For this, I guess it'd be easier to keep doing what we're doing: print the function, and the input that caused it to fail. For the functions, we can just make sure that the test function has a `short_src` of `./tests.lua`, to ensure it's a test function.

Monitoring the global state of Lua is going to be challenging without some plugins/extensions that are written in C. For now, we'll just hope and pray there aren't any unintended side-effects.

