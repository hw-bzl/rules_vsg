"""A script for applying vsg `--fix` to VHDL files within the Bazel workspace."""

import argparse
import os
import platform
import sys
from pathlib import Path
from typing import Optional, Sequence

from python.runfiles import Runfiles
from vsg.__main__ import main as vsg_main


def _rlocation(runfiles: Runfiles, rlocationpath: str) -> Path:
    """Look up a runfile and ensure the file exists."""
    source_repo = None
    if platform.system() == "Windows":
        source_repo = ""
    runfile = runfiles.Rlocation(rlocationpath, source_repo)
    if not runfile:
        raise FileNotFoundError(f"Failed to find runfile: {rlocationpath}")
    path = Path(runfile)
    if not path.exists():
        raise FileNotFoundError(f"Runfile does not exist: ({rlocationpath}) {path}")
    return path


def _runfile(arg: str) -> Path:
    """Resolve an argument as a runfile path (always — fixer runs under `bazel run`)."""
    runfiles = Runfiles.Create()
    if not runfiles:
        raise EnvironmentError("Failed to locate runfiles")
    return _rlocation(runfiles, arg)


def parse_args(args: Optional[Sequence[str]] = None) -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser("VSG Fixer")

    parser.add_argument(
        "--config",
        dest="configs",
        action="append",
        type=_runfile,
        required=True,
        help="VSG configuration file. May be repeated; files are merged left-to-right.",
    )
    parser.add_argument(
        "--src",
        dest="sources",
        action="append",
        required=True,
        help="A workspace-relative VHDL source path to fix in place.",
    )

    return parser.parse_args(args)


def _load_args() -> Sequence[str]:
    """Load command line arguments, resolving the args file from runfiles."""
    if "RULES_VSG_FIXER_ARGS_FILE" in os.environ:
        arg_file = _runfile(os.environ["RULES_VSG_FIXER_ARGS_FILE"])
        return arg_file.read_text(encoding="utf-8").splitlines()

    return sys.argv[1:]


def main() -> None:
    """The main entrypoint."""
    if "BUILD_WORKSPACE_DIRECTORY" not in os.environ:
        raise EnvironmentError(
            "BUILD_WORKSPACE_DIRECTORY is not set. Run this target via `bazel run`."
        )

    workspace_dir = Path(os.environ["BUILD_WORKSPACE_DIRECTORY"])

    args = parse_args(_load_args())

    vsg_args = ["--fix"]
    for config in args.configs:
        vsg_args.extend(["-c", str(config)])
    vsg_args.append("-f")
    vsg_args.extend(args.sources)

    old_cwd = os.getcwd()
    os.chdir(str(workspace_dir))

    old_argv = list(sys.argv)
    sys.argv = [sys.argv[0]] + vsg_args

    exit_code = 0
    try:
        vsg_main()
    except SystemExit as exc:
        if exc.code is None:
            exit_code = 0
        elif isinstance(exc.code, str):
            exit_code = int(exc.code)
        else:
            exit_code = exc.code
    finally:
        sys.argv = old_argv
        os.chdir(old_cwd)

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
