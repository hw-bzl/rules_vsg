# rules_vsg

Bazel rules for [VSG (VHDL Style Guide)](https://github.com/jeremiah-c-leary/vhdl-style-guide).

## Overview

`rules_vsg` runs the VSG linter and formatter against
[`vhdl_library`](https://github.com/hw-bzl/bazel_rules_vhdl) targets:

- **[`vsg_test`](./vsg_test.md)** — a Bazel test rule that lints a `vhdl_library` and fails on violations.
- **[`vsg_fixer`](./vsg_fixer.md)** — a `bazel run`-able target that applies `vsg --fix` in place to the workspace sources.
- **[`vsg_aspect`](./vsg_aspect.md)** — an aspect that runs VSG as a side effect of `bazel build`, opt-in via `.bazelrc`.
- **[`vsg_toolchain`](./vsg_toolchain.md)** — wraps the `vsg` pip package as a Bazel toolchain.

## Setup

`rules_vsg` ships with **no** registered toolchain. VSG is a pip-distributed Python tool and you
supply it as a `py_library` via whichever pip integration you prefer.

The example below uses [`rules_req_compile`](https://github.com/periareon/req-compile), but anything
that produces a `py_library` exposing the `vsg` package will work.

### MODULE.bazel

```python
bazel_dep(name = "rules_vsg",  version = "{version}")
bazel_dep(name = "rules_vhdl", version = "0.1.2")
bazel_dep(name = "rules_venv", version = "0.17.0")
bazel_dep(name = "rules_req_compile", version = "1.1.2")

requirements = use_extension("@rules_req_compile//extensions:python.bzl", "requirements")
requirements.parse(
    name = "pip_deps",
    requirements_locks = {
        "//tools/requirements:requirements_linux_x86_64.txt": "//tools/requirements:linux_x86_64",
    },
)
use_repo(requirements, "pip_deps")

register_toolchains("//tools/toolchains:vsg_toolchain")
```

### //tools/toolchains/BUILD.bazel

```python
load("@rules_vsg//vsg:defs.bzl", "vsg_toolchain")

vsg_toolchain(
    name = "vsg_toolchain_impl",
    vsg = "@pip_deps//vsg",
)

toolchain(
    name = "vsg_toolchain",
    toolchain = ":vsg_toolchain_impl",
    toolchain_type = "@rules_vsg//vsg:toolchain_type",
)
```

### //tools/requirements/requirements.in

```
vsg
```

Populate the lockfile with:

```bash
bazel run //tools/requirements:requirements.linux_x86_64.update
```

## Usage

```python
load("@rules_vhdl//vhdl:defs.bzl", "vhdl_library")
load("@rules_vsg//vsg:defs.bzl", "vsg_fixer", "vsg_test")

vhdl_library(
    name = "math_pkg",
    srcs = ["math_pkg.vhd", "adder.vhd"],
)

vsg_test(
    name = "math_pkg_vsg_test",
    target = ":math_pkg",
    config = ":vsg_config.yaml",
)

vsg_fixer(
    name = "math_pkg_vsg_fix",
    target = ":math_pkg",
    config = ":vsg_config.yaml",
)
```

Run:

- `bazel test //:math_pkg_vsg_test` — fails on violations
- `bazel run //:math_pkg_vsg_fix` — applies `vsg --fix` in place to workspace files

`vsg_test` always emits JUnit XML at `$XML_OUTPUT_FILE` when running under `bazel test`, so test
results integrate with the standard Bazel test report. `vsg_fixer` rejects external-repo sources at
analysis time (you cannot fix files outside the calling workspace).

## Aspect mode

To run VSG on every `vhdl_library` in the workspace as part of `bazel build`, add to `.bazelrc`:

```text
build:vsg --aspects=@rules_vsg//vsg:vsg_aspect.bzl%vsg_aspect
build:vsg --output_groups=+vsg_checks
build:vsg --@rules_vsg//vsg:config=//:vsg_config.yaml
```

Then run with `bazel build --config=vsg //...`. Tag a target with `no_vsg` (or `nolint`,
`noformat`) to opt out.

## Rule reference

Generated reference for each rule is in the [Rules](./rules.md) section.
