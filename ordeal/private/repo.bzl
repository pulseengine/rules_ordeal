"""Repository rule for downloading ordeal release binaries."""

# Supported target triples. ordeal release assets are named directly after
# the triple: ordeal-v{version}-{triple}.tar.gz
_SUPPORTED_PLATFORMS = [
    "aarch64-apple-darwin",
    "x86_64-apple-darwin",
    "aarch64-unknown-linux-gnu",
    "x86_64-unknown-linux-gnu",
]

# Mapping from platform triple to Bazel constraint labels.
# Kept in sync with _PLATFORM_CONSTRAINTS in ordeal/extensions.bzl.
_CONSTRAINTS = {
    "aarch64-apple-darwin": '["@platforms//os:macos", "@platforms//cpu:aarch64"]',
    "x86_64-apple-darwin": '["@platforms//os:macos", "@platforms//cpu:x86_64"]',
    "aarch64-unknown-linux-gnu": '["@platforms//os:linux", "@platforms//cpu:aarch64"]',
    "x86_64-unknown-linux-gnu": '["@platforms//os:linux", "@platforms//cpu:x86_64"]',
}

# ordeal stopped publishing Intel macOS (x86_64-apple-darwin) archives with
# v0.38.0 (fleet-wide decision, 2026-11-20). Older pins still download theirs;
# from v0.38.0 an Intel Mac host fails here, with this message, when Bazel
# resolves the ordeal toolchain for it. Other hosts never fetch this repo.
_LAST_INTEL_MAC_VERSION = (0, 37)

_INTEL_MAC_REFUSAL = (
    "ordeal v{version} ships no x86_64-apple-darwin (Intel macOS) binary: " +
    "ordeal stopped building Intel macOS archives from v0.38.0 on. " +
    "Intel Mac users: build from source (cargo install ordeal --version {version}), " +
    "or pin ordeal.toolchain(version = \"0.37.0\") or older."
)

def _major_minor(version):
    parts = version.split(".")
    if len(parts) < 2 or not parts[0].isdigit() or not parts[1].isdigit():
        fail("ordeal version must look like X.Y.Z, got: {}".format(version))
    return (int(parts[0]), int(parts[1]))

# BUILD file template for the downloaded ordeal toolchain
_BUILD_FILE_CONTENT = '''
load("@rules_ordeal//ordeal:toolchain.bzl", "ordeal_toolchain_info")

package(default_visibility = ["//visibility:public"])

# The ordeal solver binary
filegroup(
    name = "ordeal_bin",
    srcs = ["ordeal"],
)

# All release files (for runfiles)
filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

ordeal_toolchain_info(
    name = "ordeal_toolchain_info",
    ordeal = ":ordeal_bin",
    version = "{version}",
)

toolchain(
    name = "ordeal_toolchain",
    toolchain = ":ordeal_toolchain_info",
    toolchain_type = "@rules_ordeal//ordeal:toolchain_type",
    exec_compatible_with = {exec_constraints},
)
'''

def _ordeal_release_impl(rctx):
    """Download and extract an ordeal release binary."""
    version = rctx.attr.version
    platform = rctx.attr.platform

    if platform not in _SUPPORTED_PLATFORMS:
        fail("Unsupported platform: {}. Supported: {}".format(
            platform,
            ", ".join(_SUPPORTED_PLATFORMS),
        ))

    if platform == "x86_64-apple-darwin" and _major_minor(version) > _LAST_INTEL_MAC_VERSION:
        fail(_INTEL_MAC_REFUSAL.format(version = version))

    # Construct download URL. Release tag is v{version}; the tarball contains
    # the flat files ./ordeal, ./README.md, ./LICENSE (no directory prefix).
    url = "https://github.com/pulseengine/ordeal/releases/download/v{version}/ordeal-v{version}-{platform}.tar.gz".format(
        version = version,
        platform = platform,
    )

    rctx.download_and_extract(
        url = url,
        sha256 = rctx.attr.sha256,
    )

    # Make the binary executable (important for macOS)
    rctx.execute(["chmod", "+x", "ordeal"])

    # Remove macOS quarantine if targeting macOS
    if "apple-darwin" in platform:
        rctx.execute(["xattr", "-cr", "."], quiet = True)

    exec_constraints = _CONSTRAINTS[platform]

    rctx.file("BUILD.bazel", _BUILD_FILE_CONTENT.format(
        version = version,
        exec_constraints = exec_constraints,
    ))

ordeal_release = repository_rule(
    implementation = _ordeal_release_impl,
    attrs = {
        "version": attr.string(
            mandatory = True,
            doc = "ordeal release version without the leading 'v' (e.g. '0.16.1')",
        ),
        "platform": attr.string(
            mandatory = True,
            doc = "Target platform triple",
        ),
        "sha256": attr.string(
            default = "",
            doc = "SHA-256 hash of the release tar.gz (empty to skip verification)",
        ),
    },
    doc = "Downloads a pre-built ordeal release binary from GitHub.",
)
