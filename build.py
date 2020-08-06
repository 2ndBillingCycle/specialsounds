"""
This script requires Python 3.7 or higher

This is run to produce a build artefact on each platform
It's intended to be run in a CI environment, and while it generally only
creates and manipulates files in the local directory, it does make some changes
to the system, does not undo these once done, and generally assumes a clean,
well-ordered environment that can be deleted once the process is completed.

This expects to be run from a source checkout from
https://github.com/2ndBillingCycle/specialsounds.git

This will create directories and install lua and luarocks as needed, and end
with a final specialsounds.lua
"""
# isort: off
import sys

assert sys.version_info >= (3, 7), "Python 3.7 or higher is required\nDetected: " + str(
    sys.version
)
# isort: on

import logging
import os
from contextlib import contextmanager
from pathlib import Path
from subprocess import CompletedProcess, run
from typing import Iterator, NamedTuple, Union

SPath = Union[str, Path]


class CommandResults(NamedTuple):
    lua51: "CompletedProcess[str]"
    luajit: "CompletedProcess[str]"


@contextmanager
def cd(path: SPath) -> Iterator[Path]:
    """Allows changing Python directory in with statement

    from: https://stackoverflow.com/a/24469659
    """
    old_path = os.getcwd()
    new_path = Path(path)
    os.chdir(str(new_path))
    try:
        yield new_path
    finally:
        os.chdir(old_path)


def shell(script: str, check: bool = True) -> "CompletedProcess[str]":
    """Run a script using the shell"""
    logging.info("{}".format(script))
    return run(script, capture_output=True, check=check, shell=True, text=True)


def main() -> None:
    """Runs the build

    Installs and sets up lua and luarocks
    Installs necessary dependencies
    Runs build process
    Executes build output to run internal tests
    """
    logging.basicConfig(format="%(message)s", level=logging.DEBUG)

    install_hererocks()
    install_dependencies()


def where_hererocks() -> Path:
    """Returns location of hererocks executable

    Only checks to make sure it's installed where it's expected
    """
    pipx_bin = Path("~/.local/bin/").expanduser()
    if not pipx_bin.is_dir():
        raise FileNotFoundError(
            "Could not find directories where pipx installs binaries\n"
            "expected '{}'".format(pipx_bin)
        )

    if (pipx_bin / "hererocks").is_file():
        hererocks = pipx_bin / "hererocks"
    else:
        hererocks = pipx_bin / "hererocks.exe"

    if not hererocks.is_file():
        raise FileNotFoundError(
            "'hererocks' installed but not found\n"
            "expected to be at '{}'".format(hererocks.resolve(strict=False))
        )

    hererocks_version = shell("{} --version".format(hererocks), check=False)
    if hererocks_version.returncode != 0 or "Hererocks" not in hererocks_version.stdout:
        raise FileNotFoundError(
            "Error running 'hererocks --version'\n"
            "used hererocks at '{}'\ngot:\n{}\n{}".format(
                hererocks, hererocks_version.stdout, hererocks_version.stderr
            )
        )

    return hererocks


def install_hererocks() -> None:
    """Installs hererocks

    This is one aspect of the build that does affect directories outside that
    which this is run from
    """
    if (
        shell(
            "python -c 'import sys;assert sys.version_info <= (3, 7)'", check=False
        ).returncode
        == 0
    ):
        raise ValueError(
            "This script needs to call Python 3.7 or higher, but it couldn't find that"
        )

    logging.info("Installing pipx...")
    shell("python -m pip install --user -U pipx")
    shell("python -m pipx ensurepath")

    logging.info("Installing hererocks...")
    shell("python -m pipx install hererocks")


def install_dependencies() -> None:
    """Installs lua + luarocks and others

    Installs both PUC-Rio Lua and LuaJIT
    Installs both build dependencies and script dependencies,
    mostly through luarocks
    """
    logging.info("Checking hererocks is installed")
    hererocks_path = where_hererocks()
    Path("./build/").mkdir(exist_ok=True)
    build_dir = Path("./build/").resolve(strict=True)

    def hererocks(commands: str, check: bool = True) -> "CompletedProcess[str]":
        """shortcut to run hererocks commands"""
        return shell("{} {}".format(hererocks_path, commands), check=check)

    logging.info("Installing lua, luajit, and luarocks in {}".format(build_dir))
    hererocks("--lua 5.1 --luarocks latest --patch build/lua51")
    hererocks("--luajit 2.1 --luarocks latest --compat 5.1 build/luajit")

    lua51_dir = build_dir / "lua51"
    luajit_dir = build_dir / "luajit"

    def luarocks(commands: str, check: bool = True) -> CommandResults:
        """shortcut to run luarocks commands"""
        with cd(lua51_dir) as path:
            lua51_result = shell(
                "{}/bin/luarocks {}".format(path, commands), check=check
            )
        with cd(luajit_dir) as path:
            luajit_result = shell(
                "{}/bin/luarocks {}".format(path, commands), check=check
            )
        return CommandResults(lua51=lua51_result, luajit=luajit_result)

    logging.info("Installing dependencies...")
    luarocks("install amalg")
    luarocks("install busted")


if __name__ == "__main__":
    main()
