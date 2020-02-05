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

Okay, so the list for testing so far is:

- Install LuaJIT, luarocks
- Use luarocks to install cluacov
- tell lua about LuaCov via `luarocks path`
- run tests with luacov loaded as a library
- Upload tests using the CodeCov GitHub Action
- Mark the luarocks files for caching

---

There are a few things that should be done differently for builds:

- skip_wip_tests should be set

Well, currently, I have a set of Work In Progress tests which includes both tests I've written and am writing functionality so they pass (a la Test-Driven Development), and tests of the testing framework. These should really be split.

Or should WIP tests be a thing at all? The point is that I don't want tests failing for non-existent functionality when I'm committing, but really, the work on that functionality should be encapsulated into its own branch, and then I _do_ want the tests to fail until the functionality is implemented, as I want failing tests to block me from merging broken code.

I guess I should drop the WIP tests, as I can't think of a situation in which I want to merge failing or non-existant code into master.

Well, aside from that, there are some more details on how I want the tests to work:

1. Install LuaJIT and build-essential, the latter ensuring lua C extensions installed by luarocks can be built from source
1. `update-alternatives` so LuaJIT is `lua`
1. Install luarocks
1. Use luarocks to install cluacov
1. Set environment variables [`LUA_PATH` ](https://www.lua.org/manual/5.1/manual.html#pdf-package.path) and [`LUA_CPATH`](https://www.lua.org/manual/5.1/manual.html#pdf-package.cpath) so LuaJIT can find the rocks installed by luarocks
1. Run the tests with the luacov library loaded
1. Run `luacov` to generate a report, the format of which [CodeCove.io already knows how to process](https://docs.codecov.io/reference#acceptable-report-formats)
1. Upload the coverage report to [CodeCov.io](https://codecov.io)
1. Cache the luarocks downloaded and generated files, including the compiled cluacov, based on the current version of luacov and luarocks  
   Really, I don't know if luarocks is okay with copying the whole of its `--local` directory en-masse, but I guess we'll see

As for the build step; well, the build step isn't really building so much as concatenation, but this may change in the future, so we're still calling it building. Anyways, I want the build process to do the following:

- Bump the version in `header.lua`
- Do the "build" step (currently `lua -e build=1 build.lua`)
- Take the generated `SpecialSounds.lua` and both push it as a release artefact, and `mv` it to the root directory of the repository so that anyone visiting the GitHub page has an obvious file to download
- Make a draft release using the changed files

Hmm, that doesn't quite make sense: I think releases use the most recent tag, annotated or not, and I want to be able to type the message out for the annotated tag that tags a new release, so I can put in a blurb about what changed.

I may be able to automate that when I can automate the generation of a changelog, but that requires some scripting with `git`, and relies on well-structured and written `git` commit messages, which I also don't have, so that whole process will have to wait.

Instead, I think I can kick the whole process off with an annotated tag on master.

This means any merges into master won't necessarily mean I immediately make a build. It'd feel really cool to have multiple [WIP] PRs merge one after another, and then make a release.

So, right now, the build process sounds like it'll be kicked off from an annotated tag.

Alright, so the process would probably look like

1. Make a draft release using the annotated tag
1. Run tests as above
1. Run the "build" step and version bump all at once: `lua -e "bumpver=true build=true" build.lua`
1. Push the generated `SpecialSounds.lua` file as a release artifact
1. Move the `SpecialSounds.lua` file to the root of the repository
1. Somehow make the updated `header.lua` and `SpecialSounds.lua` files part of the release

This would seem to me like since I don't like munging the repository history (also munging it would force me to have to do a git pull --force after every release) it would require the commit the annotated tag points to to be changed.

[This Stack Overflow answer](https://stackoverflow.com/a/8044605/5059062) follows along fairly nicely with the [info from the Pro Git book](https://git-scm.com/book/en/v2/Git-Basics-Tagging#_deleting_tags) on deleting tags.

It looks like it's possible to delete tags, thereby letting you make a new tag with the same name, making it look like you moved the tag.

So I guess the info I wanted to keep from the annotated tag, namely the message, could be saved, the tag deleted, the changes committed as a new commit, and a new tag created that points to the new commit that simply bumps the version and includes the updted `SpecialSounds.lua`.

So then the process for building would look like:

1. Merge in all the PRs for this release to `master`
1. Create an annotated tag describing the gist of the changes in this release

And then the CI/CD would:

1. Save the message from the most recent annotated tag
1. Delete the tag in the local repository on the build runner only
1. Run tests as above
1. Run the "build" step and version bump all at once: `lua -e "bumpver=true build=true" build.lua`
1. Move the `SpecialSounds.lua` file to the root of the repository
1. Commit the changes with the message of something like "Release ${v...}"
1. Delete the tag in remote (the actual repository hosted on GitHub)
1. Make a new annotated tag with the previous tag name and message, pointing to this new commit
1. Push both the new commit and the annotated tag pointing to it
1. Make a release using the annotated tag
1. Push the generated `SpecialSounds.lua` file as a release artifact

On a side note, at some point, I think I want to change the process to not use global variables, and instead do something like:

```sh
lua -lluacov -lbuild -e "bumpver() test() build()"
```

I'm not quite sure right now how I'd implement that, but we'll get there.

Also, eventually I want to run this on linux _and_ Windows, also downloading HexChat for running integration tests.

Now, I know I can get the plugin to get HexChat to pretend a particular message is from a server, so it can run real life integration tests, but I've no idea how to get HexChat to report a plugin crashing.

I might have to look at how HexChat is tested and see if it would be possible to run an automated integration test.

Without knowing anything about the process, my first guess would be to have the tests save a file as part of their run inside HexChat, but that wouldn't tell me if a "beep" was made when it was supposed to be.
