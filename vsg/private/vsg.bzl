"""Bazel rules for vsg (VHDL Style Guide)"""

load("@rules_venv//python/venv:defs.bzl", "py_venv_common")
load("@rules_vhdl//vhdl:defs.bzl", "VhdlInfo")
load(":vsg_toolchain.bzl", "TOOLCHAIN_TYPE")

_IGNORE_TAGS = [
    "no_vsg",
    "novsg",
    "no_lint",
    "nolint",
    "no_format",
    "noformat",
]

def _rlocationpath(file, workspace_name):
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]
    return "{}/{}".format(workspace_name, file.short_path)

def _vsg_test_impl(ctx):
    venv_toolchain = ctx.toolchains[py_venv_common.TOOLCHAIN_TYPE]
    vsg_toolchain = ctx.toolchains[TOOLCHAIN_TYPE]

    dep_info = py_venv_common.create_dep_info(
        ctx = ctx,
        deps = [ctx.attr._runner, vsg_toolchain.vsg],
    )

    py_info = py_venv_common.create_py_info(
        ctx = ctx,
        imports = [],
        srcs = [ctx.file._runner_main],
        dep_info = dep_info,
    )

    executable, runfiles = py_venv_common.create_venv_entrypoint(
        ctx = ctx,
        venv_toolchain = venv_toolchain,
        py_info = py_info,
        main = ctx.file._runner_main,
        runfiles = dep_info.runfiles,
    )

    srcs = ctx.attr.target[VhdlInfo].srcs
    workspace_name = ctx.workspace_name

    config_files = [ctx.file.config] + ctx.files.extra_configs

    def _src_map(file):
        return "--src={}".format(_rlocationpath(file, workspace_name))

    args = ctx.actions.args()
    args.set_param_file_format("multiline")
    for config in config_files:
        args.add("--config", _rlocationpath(config, workspace_name))
    args.add("--junit-from-env")
    args.add_all(srcs, map_each = _src_map, allow_closure = True)

    args_file = ctx.actions.declare_file("{}.vsg_args.txt".format(ctx.label.name))
    ctx.actions.write(
        output = args_file,
        content = args,
    )

    return [
        DefaultInfo(
            files = depset([executable]),
            runfiles = runfiles.merge(
                ctx.runfiles(
                    files = config_files + [args_file],
                    transitive_files = srcs,
                ),
            ),
            executable = executable,
        ),
        RunEnvironmentInfo(
            environment = {
                "RULES_VSG_RUNNER_ARGS_FILE": _rlocationpath(args_file, workspace_name),
            },
        ),
    ]

_COMMON_ATTRS = {
    "config": attr.label(
        doc = "VSG configuration file. Defaults to the `//vsg:config` label_flag.",
        cfg = "target",
        allow_single_file = [".yaml", ".yml", ".json"],
        default = Label("//vsg:config"),
    ),
    "extra_configs": attr.label_list(
        doc = "Additional VSG configuration files to merge on top of `config` (left-to-right).",
        allow_files = [".yaml", ".yml", ".json"],
    ),
    "target": attr.label(
        doc = "The `vhdl_library` (or anything providing `VhdlInfo`) whose sources to lint.",
        providers = [VhdlInfo],
        mandatory = True,
    ),
}

vsg_test = rule(
    implementation = _vsg_test_impl,
    doc = "A rule for running `vsg` as a Bazel test (check mode; fails on violations).",
    attrs = _COMMON_ATTRS | {
        "_runner": attr.label(
            doc = "The process wrapper for running vsg.",
            cfg = "exec",
            default = Label("//vsg/private:vsg_runner"),
        ),
        "_runner_main": attr.label(
            doc = "The main entrypoint for the vsg runner.",
            cfg = "exec",
            allow_single_file = True,
            default = Label("//vsg/private:vsg_runner.py"),
        ),
    },
    toolchains = [
        py_venv_common.TOOLCHAIN_TYPE,
        TOOLCHAIN_TYPE,
    ],
    test = True,
)

def _vsg_fixer_impl(ctx):
    venv_toolchain = ctx.toolchains[py_venv_common.TOOLCHAIN_TYPE]
    vsg_toolchain = ctx.toolchains[TOOLCHAIN_TYPE]

    dep_info = py_venv_common.create_dep_info(
        ctx = ctx,
        deps = [ctx.attr._fixer, vsg_toolchain.vsg],
    )

    py_info = py_venv_common.create_py_info(
        ctx = ctx,
        imports = [],
        srcs = [ctx.file._fixer_main],
        dep_info = dep_info,
    )

    executable, runfiles = py_venv_common.create_venv_entrypoint(
        ctx = ctx,
        venv_toolchain = venv_toolchain,
        py_info = py_info,
        main = ctx.file._fixer_main,
        runfiles = dep_info.runfiles,
    )

    srcs = ctx.attr.target[VhdlInfo].srcs
    workspace_name = ctx.workspace_name

    # The fixer mutates files in the source workspace, so external-repo
    # sources cannot be fixed via `bazel run`. Reject them at analysis time.
    for src in srcs.to_list():
        if src.short_path.startswith("../"):
            fail(
                "vsg_fixer cannot fix sources from external repositories: {}. ".format(src.short_path) +
                "Run the fixer in the repository that owns the source instead.",
            )

    config_files = [ctx.file.config] + ctx.files.extra_configs

    args = ctx.actions.args()
    args.set_param_file_format("multiline")
    for config in config_files:
        args.add("--config", _rlocationpath(config, workspace_name))
    for src in srcs.to_list():
        args.add("--src", src.short_path)

    args_file = ctx.actions.declare_file("{}.vsg_fixer_args.txt".format(ctx.label.name))
    ctx.actions.write(
        output = args_file,
        content = args,
    )

    return [
        DefaultInfo(
            files = depset([executable]),
            runfiles = runfiles.merge(
                ctx.runfiles(files = config_files + [args_file]),
            ),
            executable = executable,
        ),
        RunEnvironmentInfo(
            environment = {
                "RULES_VSG_FIXER_ARGS_FILE": _rlocationpath(args_file, workspace_name),
            },
        ),
    ]

vsg_fixer = rule(
    implementation = _vsg_fixer_impl,
    doc = "A `bazel run`-able rule that applies `vsg --fix` in place to the workspace sources of a `vhdl_library`.",
    attrs = _COMMON_ATTRS | {
        "_fixer": attr.label(
            doc = "The process wrapper for running `vsg --fix`.",
            cfg = "exec",
            default = Label("//vsg/private:vsg_fixer_lib"),
        ),
        "_fixer_main": attr.label(
            doc = "The main entrypoint for the vsg fixer.",
            cfg = "exec",
            allow_single_file = True,
            default = Label("//vsg/private:vsg_fixer.py"),
        ),
    },
    toolchains = [
        py_venv_common.TOOLCHAIN_TYPE,
        TOOLCHAIN_TYPE,
    ],
    executable = True,
)

def _vsg_aspect_impl(target, ctx):
    if VhdlInfo not in target:
        return []

    for tag in ctx.rule.attr.tags:
        sanitized = tag.replace("-", "_").lower()
        if sanitized in _IGNORE_TAGS:
            return []

    info = target[VhdlInfo]
    srcs = info.srcs
    if not srcs:
        return []

    venv_toolchain = py_venv_common.get_toolchain(ctx, cfg = "exec")
    vsg_toolchain = ctx.toolchains[TOOLCHAIN_TYPE]

    dep_info = py_venv_common.create_dep_info(
        ctx = ctx,
        deps = [ctx.attr._runner, vsg_toolchain.vsg],
    )

    py_info = py_venv_common.create_py_info(
        ctx = ctx,
        imports = [],
        srcs = [ctx.file._runner_main],
        dep_info = dep_info,
    )

    marker = ctx.actions.declare_file("{}.vsg.ok".format(target.label.name))
    aspect_name = "{}.vsg".format(target.label.name)

    executable, runfiles = py_venv_common.create_venv_entrypoint(
        ctx = ctx,
        venv_toolchain = venv_toolchain,
        py_info = py_info,
        main = ctx.file._runner_main,
        name = aspect_name,
        runfiles = dep_info.runfiles,
        use_runfiles_in_entrypoint = False,
        force_runfiles = True,
    )

    args = ctx.actions.args()
    args.add("--config", ctx.file._config)
    args.add("--marker", marker)
    args.add_all(srcs, format_each = "--src=%s")

    ctx.actions.run(
        mnemonic = "Vsg",
        progress_message = "Vsg %{label}",
        executable = executable,
        inputs = depset([ctx.file._config], transitive = [srcs]),
        tools = runfiles.files,
        outputs = [marker],
        arguments = [args],
        env = ctx.configuration.default_shell_env,
    )

    return [OutputGroupInfo(
        vsg_checks = depset([marker]),
    )]

vsg_aspect = aspect(
    implementation = _vsg_aspect_impl,
    doc = """\
An aspect for running `vsg` on targets providing `VhdlInfo`.

Enable by adding the following to a workspace's `.bazelrc`:

```
build --aspects=@rules_vsg//vsg:vsg_aspect.bzl%vsg_aspect
build --output_groups=+vsg_checks
```
""",
    attrs = {
        "_config": attr.label(
            doc = "VSG configuration file.",
            cfg = "target",
            allow_single_file = True,
            default = Label("//vsg:config"),
        ),
        "_runner": attr.label(
            doc = "The process wrapper for running vsg.",
            cfg = "exec",
            default = Label("//vsg/private:vsg_runner"),
        ),
        "_runner_main": attr.label(
            doc = "The main entrypoint for the vsg runner.",
            cfg = "exec",
            allow_single_file = True,
            default = Label("//vsg/private:vsg_runner.py"),
        ),
    } | py_venv_common.create_venv_attrs(),
    toolchains = [TOOLCHAIN_TYPE],
    required_providers = [VhdlInfo],
)
