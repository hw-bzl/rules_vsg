# rules_vsg

Bazel rules that run [VSG (VHDL Style Guide)](https://github.com/jeremiah-c-leary/vhdl-style-guide)
against [`vhdl_library`](https://github.com/hw-bzl/bazel_rules_vhdl) targets.

- **`vsg_test`** — Bazel test rule that lints a `vhdl_library` and fails on violations.
- **`vsg_fixer`** — `bazel run`-able target that applies `vsg --fix` in place to the workspace sources.
- **`vsg_aspect`** — aspect that runs VSG as a side effect of `bazel build`, opt-in via `.bazelrc`.

Full documentation, setup instructions, and rule reference: <https://hw-bzl.github.io/rules_vsg/>.

## Quick start

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

Then:

- `bazel test //:math_pkg_vsg_test` — fails on violations
- `bazel run //:math_pkg_vsg_fix` — applies `vsg --fix` to the workspace files

`rules_vsg` ships with no registered toolchain — you supply `vsg` as a Python library and
register a `vsg_toolchain`. See the [documentation](https://hw-bzl.github.io/rules_vsg/) for the
full wiring.
