"""ordeal toolchain definitions."""

OrdealToolchainInfo = provider(
    doc = "Information about an ordeal solver toolchain",
    fields = {
        "ordeal": "File: The ordeal solver binary",
        "version": "String: ordeal release version (e.g. '0.16.1')",
    },
)

def _ordeal_toolchain_info_impl(ctx):
    """Create an OrdealToolchainInfo provider for the toolchain."""
    ordeal_files = ctx.files.ordeal
    ordeal = ordeal_files[0] if ordeal_files else None
    if not ordeal:
        fail("ordeal_toolchain_info requires the ordeal binary")

    ordeal_info = OrdealToolchainInfo(
        ordeal = ordeal,
        version = ctx.attr.version,
    )

    return [
        platform_common.ToolchainInfo(
            ordeal_info = ordeal_info,
        ),
    ]

ordeal_toolchain_info = rule(
    implementation = _ordeal_toolchain_info_impl,
    attrs = {
        "ordeal": attr.label(
            allow_files = True,
            doc = "The ordeal solver binary",
        ),
        "version": attr.string(
            doc = "ordeal version string",
        ),
    },
    doc = "Provides ordeal toolchain information",
)
