#!/usr/bin/env bash
# From ordeal v0.38.0 there is no x86_64-apple-darwin archive. The Intel Mac
# toolchain repo must then fail with a message saying so (and "build from
# source"), instead of a 404 or "no matching toolchain". Control: at 0.37.0
# the same repo still downloads its pinned, sha256-verified archive, so the
# refusal is gated on the version and not on the platform alone.
# Fetching the repo directly works on any host: only Intel Macs select it
# through toolchain resolution.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/intel-mac-refusal.XXXXXX")"
trap 'rm -rf "$work"' EXIT
fails=0

fetch() { # version -> output; exit status of bazel
  local dir="$work/v$1"
  mkdir -p "$dir"
  cat > "$dir/MODULE.bazel" <<MOD
module(name = "intel_mac_refusal", version = "0.0.0")
bazel_dep(name = "rules_ordeal", version = "0.1.0")
local_path_override(module_name = "rules_ordeal", path = "$root")
ordeal = use_extension("@rules_ordeal//ordeal:extensions.bzl", "ordeal")
ordeal.toolchain(version = "$1")
use_repo(ordeal, "ordeal_toolchains_x86_64_apple_darwin")
MOD
  : > "$dir/BUILD.bazel"
  (cd "$dir" && bazel query @ordeal_toolchains_x86_64_apple_darwin//:all 2>&1)
}

out="$(fetch 0.38.0)"; st=$?
if [ $st -ne 0 ] && printf '%s' "$out" | grep -q "ships no x86_64-apple-darwin (Intel macOS) binary" \
   && printf '%s' "$out" | grep -q "build from source"; then
  echo "PASS 0.38.0: Intel Mac repo refused with the message"
else
  echo "FAIL 0.38.0: expected the Intel macOS refusal (exit $st):"; printf '%s\n' "$out" | tail -15; fails=1
fi

out="$(fetch 0.37.0)"; st=$?
if [ $st -eq 0 ] && printf '%s' "$out" | grep -q "ordeal_toolchain_info"; then
  echo "PASS 0.37.0: Intel Mac archive still downloads (control)"
else
  echo "FAIL 0.37.0: control did not fetch (exit $st):"; printf '%s\n' "$out" | tail -15; fails=1
fi
exit $fails
