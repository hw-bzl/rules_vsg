"""# rules_vsg

Bazel rules for the [vsg (VHDL Style Guide)](https://github.com/jeremiah-c-leary/vhdl-style-guide) linter and formatter.

### Setup

`rules_vsg` ships with NO registered toolchain. You must register one yourself, supplying
`vsg` as a Python library (typically from pip). The example below uses
[`rules_req_compile`](https://github.com/periareon/req-compile), but any pip integration that
exposes a `py_library` for `vsg` will work.

In your `MODULE.bazel`:

```python
bazel_dep(name = "rules_vsg", version = "0.1.0")
bazel_dep(name = "rules_vhdl", version = "0.1.1")
bazel_dep(name = "rules_venv", version = "0.17.0")
bazel_dep(name = "rules_req_compile", version = "1.1.2")

requirements = use_extension("@rules_req_compile//extensions:python.bzl", "requirements")
requirements.parse(
    name = "pip_deps",
    requirements_locks = {
        "//path/to:requirements_linux_x86_64.txt": "//path/to:linux_x86_64",
    },
)
use_repo(requirements, "pip_deps")

register_toolchains("//path/to/your:vsg_toolchain")
```

In `//path/to/your/BUILD.bazel`:

```python
load("@rules_vsg//vsg:defs.bzl", "vsg_toolchain")

vsg_toolchain(
    name = "vsg_toolchain_impl",
    vsg = "@pip_deps//vsg",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "vsg_toolchain",
    toolchain = ":vsg_toolchain_impl",
    toolchain_type = "@rules_vsg//vsg:toolchain_type",
    visibility = ["//visibility:public"],
)
```

### Usage

Operate on `vhdl_library` targets (anything providing `VhdlInfo`):

```python
load("@rules_vhdl//vhdl:defs.bzl", "vhdl_library")
load("@rules_vsg//vsg:defs.bzl", "vsg_test", "vsg_fixer")

vhdl_library(
    name = "my_lib",
    srcs = ["foo.vhd", "bar.vhd"],
)

vsg_test(
    name = "my_lib_vsg_test",
    target = ":my_lib",
    config = ":vsg_config.yaml",
)

vsg_fixer(
    name = "my_lib_vsg_fix",
    target = ":my_lib",
    config = ":vsg_config.yaml",
)
```

Run the test with `bazel test //:my_lib_vsg_test` and apply fixes in place with
`bazel run //:my_lib_vsg_fix`.

To run vsg as a build-time check on every `vhdl_library` in the workspace, add to `.bazelrc`:

```text
build --aspects=@rules_vsg//vsg:vsg_aspect.bzl%vsg_aspect
build --output_groups=+vsg_checks
build --@rules_vsg//vsg:config=//:my_vsg.yaml
```
"""

load(
    ":vsg_aspect.bzl",
    _vsg_aspect = "vsg_aspect",
)
load(
    ":vsg_fixer.bzl",
    _vsg_fixer = "vsg_fixer",
)
load(
    ":vsg_test.bzl",
    _vsg_test = "vsg_test",
)
load(
    ":vsg_toolchain.bzl",
    _vsg_toolchain = "vsg_toolchain",
)

vsg_aspect = _vsg_aspect
vsg_fixer = _vsg_fixer
vsg_test = _vsg_test
vsg_toolchain = _vsg_toolchain
