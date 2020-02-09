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

---

Also, it looks as if I'll want 3 jobs:

- Test
- Build
- Release

Where the following trigger each event:

- Test: any push/pull request
- Build: Pull requests and pushes to master
- Release: Tags of the form `/v[0-9\.]+` on the master branch

Builds might need more context on what triggered the build, so it has soe way of providing a build artifact, unless the green chack marks on a commit would take someone to the GitHub Actions page that includes the output.

The order is also fairly dependant here: The release step needs a build artifact, and nothing should be done if tests are failing.

Fortunately, [there's syntax for that](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/workflow-syntax-for-github-actions#jobsjob_idneeds).

Also, my suspicions were correct ([from the docs](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/workflow-syntax-for-github-actions#jobsjob_idsteps)):

> Each step runs in its own process in the runner environment and has access to the workspace and filesystem.
> Because steps run in their own process, changes to environment variables are not preserved between steps.

We'll find the ["proper way"](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/using-environment-variables) later.

I think it'd be good to set some sensible limits [on the runtime](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/workflow-syntax-for-github-actions#jobsjob_idtimeout-minutes), as I expect the steps to finish pretty quickly. 10 minutes is probably already generous.

Following a [Google breadcrumb trail](https://github.com/maxheld83/ghactions/issues/89#issuecomment-538776275) to [this article](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/development-tools-for-github-actions#set-an-environment-variable-set-env):

```text
::set-env name={name}::{value}
```
```sh
echo "::set-env name=action_state::yellow"
```

Now we can set environment variables that persist until the end of the job.

So it looks like this is what's left to figure out:

- Run a job from the step of another job:
  - Run the `test` job as part of the `build` job
  - If this isn't possible, not a big deal: we can make the order dependent with [`needs:`](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/workflow-syntax-for-github-actions#jobsjob_idneeds)
- How to manipulate the remote repository using the [`GITHUB_TOKEN`](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/authenticating-with-the-github_token)
- Make a GitHub release
- Attach build artifacts to different places they'd need to be:
  - Attach the generated `SpecialSounds.lua` as an artifact to:
    - The release
    - A comment in a PR
    - A comment on a commit

For the repository manipulation, the actions we want to be able to take are:

- Deleting a tag
- Pushing a commit
- Pushing an annotated tag

All of these can be done programmatically using `git`, as long as that has authenticated push access to the repo.

[`actions/github-script`](https://github.com/actions/github-script) looks promising for doing GitHub specific stuff, but not so much for `git` stuff.

In the meantime, there are actions specifically for:

- Making a release: [`actions/create-release`](https://github.com/actions/create-release)
- Uploading a release asset: [`actions/upload-release-asset`](https://github.com/actions/upload-release-asset)

I hope I won't need [the ability to SSH into the running GitHub action to debug it](https://github.com/mxschmitt/action-tmate), but I might need to.

It also turns out other people want to automate committing to a repo from within a GitHub Action:

- Someone made a [GitHub action to push changes made to the local repository](https://github.com/ad-m/github-push-action)
- Another exposed each part of the GitHub REST API as an action, [including commits](https://github.com/maxkomarychev/octions/blob/master/octions/git/create-commit/README.md)
- Another few people settled on a few variations of changing the remote url in `git`:
  - [dlunch in the forums](https://github.community/t5/GitHub-Actions/how-does-one-commit-from-an-action/m-p/30340/highlight/true#M407)
  - [garethr on their website](https://garethr.dev/2019/09/github-actions-that-commit-to-github/)

I also need to find the most recent tag, and grab its name and message. I had a couple ways to grab its name:

- `git log --tags="v*" --format="format:%S" -n 1` from me
- `git describe --tags --match "v*" --abbrev=0` from [the docs](https://git-scm.com/docs/git-describe#_options) as pointed by [here](https://stackoverflow.com/a/1404862/5059062)

Dropping `--tags` from the latter guarantees only annotated tags will be returned.

~I'm getting the message using [`git show`](https://git-scm.com/docs/git-show#_pretty_formats):~

I'm getting the message using [`git log`](https://git-scm.com/docs/git-log) since `git show` shows a lot of information by default:

```bash
git log -n 1 --format="%B" --no-notes $(git describe --match "v*" --abbrev=0)
```

And actually, naming the commit after the new release number would require me to preemptively find the release number, and mentally increment it, and that sounds like extra work the computer could do.

If I just name the release commit `release`, that should be enough of a magic name to be able to programmatically find it and replace it with `v...`.

To err on the side of caution, though, it'd probably be safer to name it `prerelease`, just in case the tests or build fails, and the tag is left there.

To do all of this, I'm going wih the action-less approach:

```bash
# Do version bump, testing, and building
git config --local user.name "GitHub Actions"
git config --local user.email "2nd+githubactions@2ndbillingcycle.stream"
git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
# Unfortunately the following doesn't work: git mv :/src/SpecialSounds.lua :/
mv src/SpecialSounds.lua ./
git add :/SpecialSounds.lua :/src/header.lua
export TAG_NAME="$(git describe --match 'prerelease' --abbrev=0)"
export TAG_MESSAGE="$(git log -n 1 --format=%B --no-notes ${TAG_NAME}"
git commit -m "Release ${TAG_NAME}"
git tag --force --annotate --no-sign --message="${TAG_MESSAGE}" "${TAG_NAME}"
git push origin --delete "${TAG_NAME}"
git push --tags origin master # Explicitly push the new master, and the new tag
```

We can make a release by using one of the aforementioned actions, now that the new annotated tag has been made:

```yaml
- name: Grab most recent tag name and message
  run: |
    export TAG_NAME="$(git describe --match 'v*' --abbrev=0)"
    # Multiline: https://github.com/actions/starter-workflows/issues/68#issuecomment-581479448
    export TAG_MESSAGE=$(git log -n 1 --format="%B" --no-notes ${TAG_NAME} | sed -e 's/\n/%0A/g')
    echo "::set-env name=TAG_NAME::${TAG_NAME}"
    echo "::set-env name=TAG_MESSAGE::${TAG_MESSAGE}"
- name: Make release
  id: make_release
  uses: action/create-release@master
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    tag_name: ${{ env.TAG_NAME }}
    release_name: ${{ env.TAG_NAME }}
    body: ${{ env.TAG_MESSAGE }}
    draft: false
    prerelease: false
```

And then attach `SpecialSounds.lua`, using the [output from the previous step](https://github.com/actions/create-release#outputs) which we [can reference](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/contexts-and-expression-syntax-for-github-actions#steps-context):

```yaml
- name: Upload release asset
  id: upload_asset
  uses: action/upload-release-asset@master
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    upload_url: ${{ steps.make_release.outputs.upload_url }}
```

Before putting it all together, I want to review how these workflows should be triggered:

- Testing and building: Every push to any branch, and every pull request
- Testing, building, and releasing: only on tags pushed to master

I kind of worry that that might go over [the usage limits](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/about-github-actions#usage-limits), but I don't think this repository currently, or will ever, see enough activity to have to worry about that.

Actually, I don't think 1000 API calls in 1 hour is going to be possible, as it seems there's no weekly or daily limit on the number of times the CI can be triggered.
