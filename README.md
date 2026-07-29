<div align="center">

# rules_ordeal

<sup>Bazel rules for ordeal certificate-checked SMT verification</sup>

&nbsp;

![Bazel](https://img.shields.io/badge/Bazel-43A047?style=flat-square&logo=bazel&logoColor=white&labelColor=1a1b27)
![Certificate Checked](https://img.shields.io/badge/Certificate_Checked-00C853?style=flat-square&logoColor=white&labelColor=1a1b27)
![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-blue?style=flat-square&labelColor=1a1b27)

</div>

&nbsp;

Bazel rules for [ordeal](https://github.com/pulseengine/ordeal) — invoke the
certificate-checked QF_BV SMT solver as a hermetic build/CI verification gate.
Downloads a pinned ordeal release binary per platform (sha256-verified against
the release's `SHA256SUMS.txt`) and wires it up as a Bazel toolchain.

> [!NOTE]
> Part of the PulseEngine toolchain, paralleling `rules_verus`. ordeal only
> ever reports `unsat` after its LRAT certificate re-checked, so a green gate
> carries evidence, not just an exit code.

## Quick Start

### 1. Add to MODULE.bazel

```starlark
bazel_dep(name = "rules_ordeal", version = "0.1.0")

git_override(
    module_name = "rules_ordeal",
    remote = "https://github.com/pulseengine/rules_ordeal.git",
    commit = "<latest-commit>",
)

# Configure the ordeal toolchain — downloads the pinned, sha256-verified
# release binary for the host platform.
ordeal = use_extension("@rules_ordeal//ordeal:extensions.bzl", "ordeal")
ordeal.toolchain(version = "0.16.1")
use_repo(ordeal, "ordeal_toolchains")
register_toolchains("@ordeal_toolchains//:all")
```

### 2. Gate a QF_BV obligation

```starlark
load("@rules_ordeal//ordeal:defs.bzl", "ordeal_check")

# Each .smt2 file must decide `unsat` (the obligation holds, with a
# checker-validated LRAT certificate). A `sat`, `unknown`, or error verdict
# fails the test — the verdict TEXT is checked, because `ordeal check`
# exits 0 for cleanly decided `sat` too.
ordeal_check(
    name = "smoke",
    srcs = ["unsat.smt2"],
)
```

```
$ bazel test //:smoke
=== ordeal check gate (ordeal 0.16.1) ===
PASS  unsat.smt2: unsat (checker-validated LRAT certificate)
=== PASSED ===
```

### 3. Discharge Verus `by (bit_vector)` obligations (bonus)

```starlark
load("@rules_ordeal//ordeal:defs.bzl", "ordeal_verus_check")

# srcs are Verus --log-all query logs. Runs `ordeal verus` on each;
# passes iff every bitvector obligation discharges as checker-validated
# `unsat` (here the exit code IS authoritative). With cert_out = True the
# LRAT certificates land in the test's undeclared outputs (outputs.zip).
ordeal_verus_check(
    name = "verus_obligations",
    srcs = ["verus_bv_obligation.smt2"],
    cert_out = True,
)
```

Note: `--cert-out` belongs to `ordeal verus` only; `ordeal check` takes no
flags, so `ordeal_check` has no `cert_out` attribute.

## Rules

| Rule | Kind | Gate |
|------|------|------|
| `ordeal_check(name, srcs)` | test | every `.smt2` src must print the verdict `unsat` |
| `ordeal_verus_check(name, srcs, cert_out)` | test | every Verus bitvector obligation log must discharge (`ordeal verus` exit 0) |

Both are macros over `ordeal_check_test` / `ordeal_verus_check_test` (Bazel
requires test rule class names to end in `_test`); the `*_test` names are
exported from `defs.bzl` too.

## Pinned versions

`ordeal.toolchain(version = ...)` resolves against a built-in table of
sha256 hashes taken from the release's `SHA256SUMS.txt`:

| Version | Platform | SHA-256 |
|---------|----------|---------|
| 0.16.1 | aarch64-apple-darwin | `9811c813b5b6bddaaf63b8b9cd99629e0b38e37a168bdffdfa12967b3de65f68` |
| 0.16.1 | x86_64-apple-darwin | `766524b60df9bfc53af09b94de1de7e66acc4ae4fadca2e48a22ce25f2e1d442` |
| 0.16.1 | aarch64-unknown-linux-gnu | `e5ca8836b63030379bd3a2ec1ed9139f81347feb6ab95237e9157311bf5a84cf` |
| 0.16.1 | x86_64-unknown-linux-gnu | `07d93c971a4d2ee751de741fb865df2d4360f6005fb5a63e5ab6cc24bab9e1c2` |

For versions not in the table, pass per-platform hashes explicitly:
`ordeal.toolchain(version = "0.17.0", sha256 = {"aarch64-apple-darwin": "..."})`.

## Examples

[`examples/`](examples/) is a self-contained consumer module (via
`local_path_override`) and the CI integration test bed:

```
cd examples && bazel test //...
```

It demonstrates the positive gate (`//:smoke`), the negative case
(`//:sat_must_fail` proves a satisfiable query FAILS `ordeal_check` with the
right message), and a real Verus obligation log (`//:verus_obligations`,
fixture from ordeal's own test suite).

## Architecture

- `ordeal/extensions.bzl` — bzlmod module extension; per-platform download
  repos plus a hub repo (`@ordeal_toolchains`) that declares one
  `toolchain()` per platform, so `register_toolchains("@ordeal_toolchains//:all")`
  registers all of them and native resolution picks the host's.
- `ordeal/private/repo.bzl` — repository rule: fetches
  `ordeal-v{version}-{triple}.tar.gz` from GitHub releases, sha256-verifies,
  strips macOS quarantine, exposes the `ordeal` binary.
- `ordeal/toolchain.bzl` — `OrdealToolchainInfo` provider + toolchain rule.
- `ordeal/defs.bzl` — public `ordeal_check` / `ordeal_verus_check`.

Status: v0.1.0 (issue pulseengine/ordeal#91, FEAT-011/TR-025).

## License

Apache-2.0
