# rules_ordeal

Bazel rules for [ordeal](https://github.com/pulseengine/ordeal) — invoke the
certificate-checked QF_BV solver as a hermetic build/CI verification gate.

Parallels `rules_verus` / `rules_lean`: downloads a pinned ordeal release
binary (sha256-verified against the release's `SHA256SUMS.txt`) and exposes:

- `ordeal_check(name, srcs)` — a test rule: each `.smt2` file must decide
  `unsat` (the obligation holds) with a checker-validated LRAT certificate;
  any `sat`/`unknown`/error fails the build.
- certificate outputs surfaced as build artifacts (`--cert-out`), so a green
  gate leaves re-checkable evidence, not just an exit code.

Status: scaffolding (issue pulseengine/ordeal#91, FEAT-011/TR-025).
