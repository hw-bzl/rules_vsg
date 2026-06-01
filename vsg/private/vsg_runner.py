"""A script for running vsg within Bazel."""

import argparse
import os
import platform
import sys
import tempfile
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


def _maybe_runfile(arg: str) -> Path:
    """Parse an argument into a path while resolving runfiles when running under Bazel test."""
    if "BAZEL_TEST" not in os.environ:
        return Path(arg)

    runfiles = Runfiles.Create()
    if not runfiles:
        raise EnvironmentError("Failed to locate runfiles")
    return _rlocation(runfiles, arg)


def parse_args(args: Optional[Sequence[str]] = None) -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser("VSG Runner")

    parser.add_argument(
        "--config",
        dest="configs",
        action="append",
        type=_maybe_runfile,
        required=True,
        help="VSG configuration file. May be repeated; files are merged left-to-right.",
    )
    parser.add_argument(
        "--marker",
        type=_maybe_runfile,
        help="The file to create as an indication that the 'Vsg' action succeeded.",
    )
    parser.add_argument(
        "--src",
        dest="sources",
        action="append",
        type=_maybe_runfile,
        required=True,
        help="A VHDL source file to lint.",
    )
    parser.add_argument(
        "--junit-from-env",
        action="store_true",
        help="If set and $XML_OUTPUT_FILE is in the environment, emit JUnit XML there.",
    )

    parsed_args = parser.parse_args(args)

    if not parsed_args.sources:
        parser.error("No source files were provided.")

    return parsed_args


def _load_args() -> Sequence[str]:
    """Load command line arguments, resolving the args file from runfiles under bazel test."""
    if "BAZEL_TEST" in os.environ and "RULES_VSG_RUNNER_ARGS_FILE" in os.environ:
        runfiles = Runfiles.Create()
        if not runfiles:
            raise EnvironmentError("Failed to locate runfiles")
        arg_file = _rlocation(runfiles, os.environ["RULES_VSG_RUNNER_ARGS_FILE"])
        return arg_file.read_text(encoding="utf-8").splitlines()

    return sys.argv[1:]


def main() -> None:
    """The main entrypoint."""
    args = parse_args(_load_args())

    vsg_args = []
    for config in args.configs:
        vsg_args.extend(["-c", str(config)])

    if args.junit_from_env and "XML_OUTPUT_FILE" in os.environ:
        vsg_args.extend(["-j", os.environ["XML_OUTPUT_FILE"]])

    vsg_args.append("-f")
    vsg_args.extend(str(src) for src in args.sources)

    tmp_dir = tempfile.mkdtemp(prefix="bazel-vsg-", dir=os.getenv("TEST_TMPDIR"))
    os.environ["HOME"] = tmp_dir
    os.environ["USERPROFILE"] = tmp_dir

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

    if args.marker and exit_code == 0:
        args.marker.write_bytes(b"")

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
