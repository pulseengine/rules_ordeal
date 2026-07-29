"""Module extension for ordeal toolchain setup.

Downloads pre-built ordeal release binaries from GitHub for all supported
platforms; Bazel toolchain resolution picks the right one per host.
"""

load("//ordeal/private:repo.bzl", "ordeal_release")

# Known release versions and their SHA-256 hashes per platform.
# Hashes are pinned from the release's SHA256SUMS.txt
# (https://github.com/pulseengine/ordeal/releases).
_KNOWN_VERSIONS = {
    "0.16.1": {
        "sha256": {
            "aarch64-apple-darwin": "9811c813b5b6bddaaf63b8b9cd99629e0b38e37a168bdffdfa12967b3de65f68",
            "aarch64-unknown-linux-gnu": "e5ca8836b63030379bd3a2ec1ed9139f81347feb6ab95237e9157311bf5a84cf",
            "x86_64-apple-darwin": "766524b60df9bfc53af09b94de1de7e66acc4ae4fadca2e48a22ce25f2e1d442",
            "x86_64-unknown-linux-gnu": "07d93c971a4d2ee751de741fb865df2d4360f6005fb5a63e5ab6cc24bab9e1c2",
        },
    },
}

_DEFAULT_VERSION = "0.16.1"

_PLATFORMS = [
    "aarch64-apple-darwin",
    "x86_64-apple-darwin",
    "aarch64-unknown-linux-gnu",
    "x86_64-unknown-linux-gnu",
]

# Mapping from platform triple to Bazel exec_compatible_with constraints.
# Kept in sync with _CONSTRAINTS in ordeal/private/repo.bzl.
_PLATFORM_CONSTRAINTS = {
    "aarch64-apple-darwin": ["@platforms//os:macos", "@platforms//cpu:aarch64"],
    "x86_64-apple-darwin": ["@platforms//os:macos", "@platforms//cpu:x86_64"],
    "aarch64-unknown-linux-gnu": ["@platforms//os:linux", "@platforms//cpu:aarch64"],
    "x86_64-unknown-linux-gnu": ["@platforms//os:linux", "@platforms//cpu:x86_64"],
}

_OrdealToolchainTag = tag_class(
    doc = "Configuration for ordeal toolchain download",
    attrs = {
        "version": attr.string(
            doc = "ordeal release version without the leading 'v' (e.g. '0.16.1'). Maps to GitHub release tag v{version}.",
            default = _DEFAULT_VERSION,
        ),
        "sha256": attr.string_dict(
            doc = "Per-platform SHA-256 hashes. Keys are platform triples. Overrides the built-in table (needed for versions not in _KNOWN_VERSIONS).",
            default = {},
        ),
    },
)

def _ordeal_impl(module_ctx):
    """Implementation of the ordeal toolchain extension."""
    configs = []
    for mod in module_ctx.modules:
        for toolchain in mod.tags.toolchain:
            configs.append(toolchain)

    if configs:
        config = configs[0]
        version = config.version
        sha256_overrides = config.sha256
    else:
        version = _DEFAULT_VERSION
        sha256_overrides = {}

    version_info = _KNOWN_VERSIONS.get(version)
    known_hashes = version_info["sha256"] if version_info else {}

    # Create a repository for each supported platform
    for platform in _PLATFORMS:
        sha256 = sha256_overrides.get(platform, known_hashes.get(platform, ""))

        repo_name = "ordeal_toolchains_" + platform.replace("-", "_")
        ordeal_release(
            name = repo_name,
            version = version,
            platform = platform,
            sha256 = sha256,
        )

    # Create a hub repo that declares one toolchain() per platform, so that
    # register_toolchains("@ordeal_toolchains//:all") registers all of them
    # and native toolchain resolution picks the right one.
    _ordeal_hub_repo(
        name = "ordeal_toolchains",
        platforms = _PLATFORMS,
    )

    return module_ctx.extension_metadata(reproducible = True)

def _ordeal_hub_repo_impl(rctx):
    """Create a hub repo that registers each platform's ordeal toolchain.

    The hub repo emits one `toolchain()` declaration per supported platform,
    each wrapping the platform-specific `ordeal_toolchain_info` provider from
    the downloaded release repo. Declaring `toolchain()` rules (rather than
    aliases) in the hub repo means `register_toolchains("@ordeal_toolchains//:all")`
    resolves via Bazel's wildcard-package target expansion and registers all
    platforms at once — native toolchain resolution then picks the right one
    based on `exec_compatible_with`.

    We deliberately do not emit a target literally named `all`: that name
    would shadow the wildcard and make register_toolchains resolve to a
    single target instead of iterating over the package.
    """
    platforms = rctx.attr.platforms

    lines = [
        'package(default_visibility = ["//visibility:public"])',
        "",
    ]

    for platform in platforms:
        repo_name = "ordeal_toolchains_" + platform.replace("-", "_")
        slug = platform.replace("-", "_")
        constraints = _PLATFORM_CONSTRAINTS.get(platform)
        if not constraints:
            # No constraint mapping — skip rather than emitting an un-gated
            # toolchain that could be picked for the wrong host.
            continue
        constraints_list = "[" + ", ".join(['"{}"'.format(c) for c in constraints]) + "]"
        lines.append("toolchain(")
        lines.append('    name = "{}_toolchain",'.format(slug))
        lines.append('    toolchain = "@{}//:ordeal_toolchain_info",'.format(repo_name))
        lines.append('    toolchain_type = "@rules_ordeal//ordeal:toolchain_type",')
        lines.append("    exec_compatible_with = {},".format(constraints_list))
        lines.append("    target_compatible_with = {},".format(constraints_list))
        lines.append(")")
        lines.append("")

    rctx.file("BUILD.bazel", "\n".join(lines) + "\n")

_ordeal_hub_repo = repository_rule(
    implementation = _ordeal_hub_repo_impl,
    attrs = {
        "platforms": attr.string_list(
            doc = "List of platform triples with available repos",
        ),
    },
)

ordeal = module_extension(
    doc = "ordeal solver toolchain extension. Downloads pre-built binaries from GitHub releases.",
    implementation = _ordeal_impl,
    tag_classes = {
        "toolchain": _OrdealToolchainTag,
    },
)
