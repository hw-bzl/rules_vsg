"""vsg toolchain rules."""

load("@rules_venv//python:py_info.bzl", "PyInfo")

TOOLCHAIN_TYPE = str(Label("//vsg:toolchain_type"))

def _vsg_toolchain_impl(ctx):
    vsg_target = ctx.attr.vsg

    # For some reason, simply forwarding `DefaultInfo` from
    # the target results in a loss of data. To avoid this a
    # new provider is created with the same info.
    default_info = DefaultInfo(
        files = vsg_target[DefaultInfo].files,
        runfiles = vsg_target[DefaultInfo].default_runfiles,
    )

    return [
        platform_common.ToolchainInfo(
            vsg = ctx.attr.vsg,
        ),
        default_info,
        vsg_target[PyInfo],
        vsg_target[OutputGroupInfo],
        vsg_target[InstrumentedFilesInfo],
    ]

vsg_toolchain = rule(
    implementation = _vsg_toolchain_impl,
    doc = "A toolchain for the [vsg](https://github.com/jeremiah-c-leary/vhdl-style-guide) VHDL style guide rules.",
    attrs = {
        "vsg": attr.label(
            doc = "The `vsg` `py_library` to use with the rules.",
            providers = [PyInfo],
            mandatory = True,
        ),
    },
)

def _current_vsg_toolchain_impl(ctx):
    toolchain = ctx.toolchains[TOOLCHAIN_TYPE]

    vsg_target = toolchain.vsg

    default_info = DefaultInfo(
        files = vsg_target[DefaultInfo].files,
        runfiles = vsg_target[DefaultInfo].default_runfiles,
    )

    return [
        toolchain,
        default_info,
        vsg_target[PyInfo],
        vsg_target[OutputGroupInfo],
        vsg_target[InstrumentedFilesInfo],
    ]

current_vsg_toolchain = rule(
    doc = "A rule for exposing the current registered `vsg_toolchain`.",
    implementation = _current_vsg_toolchain_impl,
    toolchains = [TOOLCHAIN_TYPE],
)
