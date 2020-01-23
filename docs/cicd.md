# CI/CD Setup and Configuration

I'm making these notes so I know how I setup CI/CD.

## Choices

I'm looking for:

- Testing
  - On push
  - On pull request
- On successful merges to master:
  - Bumping the version
  - Re-testing
  - Building a `SpecialSounds.lua` file
  - Making it the package for the repository
  - Make an annotated tag for the new version
  - Make a release based on this tag
  - Upload the `SpecialSounds.lua` as a release asset

I've gone with [CodeCov](https://codecov.io) and GitHub Actions. The decision was arbitrary.

## Setup

CodeCov says to link a GitHub account, so we do what CodeCov says, select our repository, and get a token.

We stick that token into the repositories `Settings -> Secrets`.

We'll write out a `.github/worklows/workflow.yml` file, using the suggested starter version.

Looks like the suggestion includes some out-of-date versions for the [GitHub actions](https://github.com/actions) themselves. We'll update those version numbers, because.

CodeCov has a [suggested example GitHub Action](https://github.com/codecov/example-lua), which uses [LuaCov](http://keplerproject.github.io/luacov/). It looks like I'll need to make sure to install [LuaJIT](http://luajit.org/luajit.html), as [HexChat uses LuaJIT](https://hexchat.readthedocs.io/en/latest/script_lua.html#environment).

Installing LuaCov is suggested to be done with [`luarocks`](https://luarocks.org/#quick-start), and it looks like `cluacov` is what we'll used to "improve performance and analysis accuracy".

`luarocks` lists downloading and `make`ing for installation, but `apt-cache luarocks` is telling me I can be lazier, if I want.

I wonder if GitHub Actions caches `apt` stuff, or if that should be done manually.

I do know it'd be a good idea to cache the [luarocks files in `~/.luarocks/`](https://github.com/luarocks/luarocks/wiki/File-locations#user-content-paths-to-rocks-trees).

Additionally, Lua needs to know about these things, and luarocks doesn't appear to configure any environment variables for us, but a quick `eval $(luarocks path)` does the trick.

Okay, so the list so far is:

- Install LuaJIT, luarocks
- Use luarocks to install cluacov
- tell lua about LuaCov via `luarocks path`
