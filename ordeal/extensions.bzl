"""Module extension for ordeal toolchain setup.

Downloads pre-built ordeal release binaries from GitHub for all supported
platforms; Bazel toolchain resolution picks the right one per host.
"""

load("//ordeal/private:repo.bzl", "ordeal_release")

# Known release versions and their SHA-256 hashes per platform.
# Hashes are pinned from the release's SHA256SUMS.txt
# (https://github.com/pulseengine/ordeal/releases).
_KNOWN_VERSIONS = {
    "0.33.0": {
        "sha256": {
            "aarch64-apple-darwin": "5ea7c97b5de9e98507f60887822f54339a79c9b10cb970dae1a5ea79a4a4db1c",
            "aarch64-unknown-linux-gnu": "97da325510440a4c60230f0bf1c7ff6af573623cf2c5234dad5c9e5cb95a0fea",
            "x86_64-apple-darwin": "88877698e90ffdc51e387cee240339d764a4a62ac65fdaf74e7fbfc43de66d69",
            "x86_64-unknown-linux-gnu": "2a1ffd9992bbbe1fd68a214d7177416e59d2f3db33a0d9f724ca9a0fe1eff586",
        },
    },
    "0.32.1": {
        "sha256": {
            "aarch64-apple-darwin": "95bc020f723a5a37515bb944124c85befea3c3794b2e5b713e35cc1463e3d1f9",
            "aarch64-unknown-linux-gnu": "c330e47f6c5222603a0cbaaa0a8fca4423eb225d945af0abae85ba764b6ceed9",
            "x86_64-apple-darwin": "36798d5baa63add2a509317d69f6acff63b945dd7e41fc6f06eca079bffd8f7b",
            "x86_64-unknown-linux-gnu": "84f77fa34872bca46f74704b5ce08a91750d01874dd5b22d69b4df32440498cb",
        },
    },
    "0.32.0": {
        "sha256": {
            "aarch64-apple-darwin": "a3f5e925c139703f6766fda9708849472cd4f372b42d331b71cd99643722b4fc",
            "aarch64-unknown-linux-gnu": "b2883517aafafc5ce486f42583bdfd225146b2996ab52cf0201fe7b3639063a3",
            "x86_64-apple-darwin": "1f78e45139d1128cf3396ec310773c103e05b342b398692912723b69138f835f",
            "x86_64-unknown-linux-gnu": "bf41cf3af67a1f987c0d2fc28a6c40d96eddbe2187ba81b81b5bc615ada74176",
        },
    },
    "0.31.0": {
        "sha256": {
            "aarch64-apple-darwin": "46e25c12701bb6526f5eb3453dec0c9196e5718b66bfadde30bc5f2b59b5563c",
            "aarch64-unknown-linux-gnu": "c4463f3d3357bd1feaa249f44a92864315b27adc09f20081a25aa1c38b6f518c",
            "x86_64-apple-darwin": "f10474cc4dc27bb7f5ce88a2d5cd982dde5df700e6a02a0ddf9660db415e4d0b",
            "x86_64-unknown-linux-gnu": "c1015be73e66bf865d7c246d3cc5ec47f5708ca1a0cac2ba649ddc46f03f6803",
        },
    },
    "0.30.0": {
        "sha256": {
            "aarch64-apple-darwin": "e3b1e74ce36d96342db65e34c4b1df7374cbf2fd296aca68315302f655dd3513",
            "aarch64-unknown-linux-gnu": "b186a33408ddb991cca2982ea01420b2ef533a70f8bb01af4c19aac5b552fe20",
            "x86_64-apple-darwin": "da356876674805f1227f4ae4c817a895b1c49a926b47ed0ea903068aae208fee",
            "x86_64-unknown-linux-gnu": "5c297704c9ce21d91a9c9539896b7da0d5597b97c0ce8ce912a5cc3205679cb5",
        },
    },
    "0.29.0": {
        "sha256": {
            "aarch64-apple-darwin": "6eddc519e24ee45e079dbb123afebc9c58123795c5e2c6b0b12c40f2a35d7077",
            "aarch64-unknown-linux-gnu": "0a5bf7997cde502cead60289a4f73625b47a68cfa9cbef2728dd8920da8f5480",
            "x86_64-apple-darwin": "1728ff2616e4e524334963381562e0d89bfc844131f96e6f954f9b12dcf5ac38",
            "x86_64-unknown-linux-gnu": "de2bab1770d1f2273dd1d3f2886cc49929cb611b3a022ea22ced6be61dd215d7",
        },
    },
    "0.28.0": {
        "sha256": {
            "aarch64-apple-darwin": "aab2c565563fabd001cd4275032a5ee90eb888e97a4927ba39a884b5b4fd7f3f",
            "aarch64-unknown-linux-gnu": "b00a3ea77c12e138c72470d7b663a96e1fe96d478c3c56e2625a014f19e5313a",
            "x86_64-apple-darwin": "4c798775711e524b1abc2443fc99377b20ab4b68eb55a0cb44ab464333005219",
            "x86_64-unknown-linux-gnu": "597a55cfd70dbf7174942a1f666d20b45a9ad1d13a4a84786c68cb13c79e1d2a",
        },
    },
    "0.27.0": {
        "sha256": {
            "aarch64-apple-darwin": "fad80ee2322dfb9f2a8bb27dabf438eb2fcfce42ea335ab7596d10d8b8299bbf",
            "aarch64-unknown-linux-gnu": "7178ce13753f9855eeb6af97054220e4117741892646ef402f361532623077a0",
            "x86_64-apple-darwin": "a652a9a954bb9fcfeb993934b25a634bcf33118714d6d34ce57dc3948cb0e221",
            "x86_64-unknown-linux-gnu": "8e81d9474b8eae5ebd9477929e05b809bef393e0dfd78d895aa032820bd1a5d3",
        },
    },
    "0.26.0": {
        "sha256": {
            "aarch64-apple-darwin": "e65156de29519e0d982812f6a8e77135cb3deaa35a19e8dce6a3d1e717c03c87",
            "aarch64-unknown-linux-gnu": "e61c4b204a5f9696db8cf86d104cce9beebf6b071fb191448a06a6ae4056a208",
            "x86_64-apple-darwin": "a46071141a6129b190cd770524d5dbca62462ff6751114f1d952449431aab8c3",
            "x86_64-unknown-linux-gnu": "4ac9469d2afe22b27119fa61e7fc2d2c8ef5d4dae1986bbb176abf0e17ca56cd",
        },
    },
    "0.25.0": {
        "sha256": {
            "aarch64-apple-darwin": "15a9fc0c5b42cbbb7c05afaaf7e9f705adb9127e7993c2ca6d67ba180f0d8a4a",
            "aarch64-unknown-linux-gnu": "8d1bdb3e028258a777bbdf0f3a950855fc0c24f8969c93f5fd4d47cc91eb023a",
            "x86_64-apple-darwin": "e8e2f77297a9e9cedca227f9d108b24fcaf42a03037b121e6c4e0c3822eaf81f",
            "x86_64-unknown-linux-gnu": "e4e34d9836e1a573d0bfa3dc32feb5343ef7cda5afec28e902ebd7e26bbfd4ef",
        },
    },
    "0.24.0": {
        "sha256": {
            "aarch64-apple-darwin": "b46a0f2483ca63ad0d1e91e619c17cbaae00c31f1a29ce5d5c053d0e7727dcff",
            "aarch64-unknown-linux-gnu": "2b7f065949292be1db885ed5f1f02d43611748e7911363dbe6488cdeb3bd245d",
            "x86_64-apple-darwin": "7360ebbe8a1cd88bde44124fb68cdfafa6821118ae3905341a85767f621cdbd4",
            "x86_64-unknown-linux-gnu": "8fa29b0c7007b8a85c52175cea53f7f1e06778be16c95fa21656e377af74184c",
        },
    },
    "0.23.0": {
        "sha256": {
            "aarch64-apple-darwin": "9382af870971e6d06b4e4f7e67fc123fbba4c47b36398c829f1da377b6de9dfe",
            "aarch64-unknown-linux-gnu": "e1717c7bca6e82e55d8095d95d713e697319700dbe07307c652b32f0e51bd72f",
            "x86_64-apple-darwin": "940e4f0104168f183c0adbf7341048cd1e2073bda22174dd5837d1b9da5d2ea1",
            "x86_64-unknown-linux-gnu": "f746872d8226a39447de89d9649609d408ba19439d87a2e63421c588c5a8c292",
        },
    },
    "0.22.1": {
        "sha256": {
            "aarch64-apple-darwin": "8dc8a56e0f8fc458a404f193e17da9ea3d360b0ce864469197d34d3de3559084",
            "aarch64-unknown-linux-gnu": "894af1f96bf29c755ba27b9cf4b7ddfce543ceadafdb160375300f9d875bc70f",
            "x86_64-apple-darwin": "277cc2f37608a27f02216e34b92ba0dad15d40f166d07f2a8fc2aaa87229bc40",
            "x86_64-unknown-linux-gnu": "f806a2cb7f9df87dcf2c83bdfc9bbef0ce9dc1b222ee54ddaa53d6b6118f603f",
        },
    },
    "0.22.0": {
        "sha256": {
            "aarch64-apple-darwin": "8ce04d10106253a4871e0a697143d8dffee85da784283caf278c2639c1e7b0c3",
            "aarch64-unknown-linux-gnu": "2b073a8f4837ba4a0b776fde4e356b14211839647acdd7e43a9959f2d2859518",
            "x86_64-apple-darwin": "c78ea9fe27723e6c545ea75b118f690a67598a92eec37774650e974121828f15",
            "x86_64-unknown-linux-gnu": "5a4006152c8695e2b1c43ba3db6312259864696edcfa7cdbd249b9bb65a061a6",
        },
    },
    "0.21.0": {
        "sha256": {
            "aarch64-apple-darwin": "8a6f76bfe56b0f8087efb5652fd6a07e9ab76384af033e59e2e7e7d2450e4a74",
            "aarch64-unknown-linux-gnu": "2096ee52887acffcbabe2759b7167433f32f35325ca93ecfa20c6b8b00630de3",
            "x86_64-apple-darwin": "871d99495a6afa84c540bcf9bbcd70d307e70f8f05a5031ed378549c3448e80d",
            "x86_64-unknown-linux-gnu": "4ed04915a10cbeb5243a9366a8b0d225eecfc75bfe0b70987e9fb58f9bf64512",
        },
    },
    "0.20.0": {
        "sha256": {
            "aarch64-apple-darwin": "10a76f32567d3460420ff1851fc88fd269ccfac94c1f560a319b02a2e8ac3e19",
            "aarch64-unknown-linux-gnu": "534378d3c2c7b5415d64e6fddf9e132c69ceb1454ff148c948d490df769c11c3",
            "x86_64-apple-darwin": "31e4ab47f3b6369d01deb11e99b8fc3912ba5ef92d6813e0c82775217de10696",
            "x86_64-unknown-linux-gnu": "38da1601cd9e1c2729cea5a078e39b5ddff1dd78a0afc7c3a4499f108c2f5df1",
        },
    },
    "0.19.0": {
        "sha256": {
            "aarch64-apple-darwin": "939a8577a3c91d311e459a000555437449afe223610fab11a02d445ff7adc5fe",
            "aarch64-unknown-linux-gnu": "d2340510688782942ea8dd1f3a9877654c4d12fd40c1a5167a78442acab06453",
            "x86_64-apple-darwin": "3dabeb4eaac5dc130670be75c8567857758eab047b1ed9dc0f0b628ee59c378e",
            "x86_64-unknown-linux-gnu": "8c839641d0aa3319bb32631064b3f4bc24648606ef5741378f04b8b0ef3b628f",
        },
    },
    "0.18.0": {
        "sha256": {
            "aarch64-apple-darwin": "d423eea3b6e817a35f3bbecc676be36b50c57fb5dd8696f9e0a5478dfaddfbb1",
            "aarch64-unknown-linux-gnu": "239197bac8f4ceef72341f00e8fba34815666b218277e55ee1abe4950190f071",
            "x86_64-apple-darwin": "cb938dfab96df7fca65e2a09df5c74b44bbbb093de26a68d09ff93e082d4b038",
            "x86_64-unknown-linux-gnu": "fde23dbcdc22dc44401db4436eaca264106a73cfeea9ae07b6fbaf2fc8ddbc5d",
        },
    },
    "0.17.0": {
        "sha256": {
            "aarch64-apple-darwin": "3ed82853c4bf97adbdbfcf1ce8c809fea8163a0810777c9a3be4ca101a6e2835",
            "aarch64-unknown-linux-gnu": "eca5ae45ba8db0bb2a905f798df5e0b7f5224bff728f572625f21e85ff2d3cd6",
            "x86_64-apple-darwin": "1d574b684ee9005b4c58619c5ad5f548626dd51e9784f30dfcd06eb3bf7d23d4",
            "x86_64-unknown-linux-gnu": "f8b5429277cd2f02a57e916b6960f7d72f50d1ba0fd0bdb589be69fa0fea57ae",
        },
    },
    "0.16.1": {
        "sha256": {
            "aarch64-apple-darwin": "9811c813b5b6bddaaf63b8b9cd99629e0b38e37a168bdffdfa12967b3de65f68",
            "aarch64-unknown-linux-gnu": "e5ca8836b63030379bd3a2ec1ed9139f81347feb6ab95237e9157311bf5a84cf",
            "x86_64-apple-darwin": "766524b60df9bfc53af09b94de1de7e66acc4ae4fadca2e48a22ce25f2e1d442",
            "x86_64-unknown-linux-gnu": "07d93c971a4d2ee751de741fb865df2d4360f6005fb5a63e5ab6cc24bab9e1c2",
        },
    },
}

_DEFAULT_VERSION = "0.33.0"

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
