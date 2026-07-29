"""Implementation of ordeal verification rules.

`ordeal check` prints the verdict (`unsat` / `sat` / `unknown`) on the first
line of stdout and exits 0 on any cleanly decided run — including `sat`.
The gate therefore asserts the *verdict text* is `unsat`, never just the
exit code.

`ordeal verus` is different: its exit code is authoritative (0 iff every
obligation discharged as checker-validated `unsat` and at least one was
discharged), and it accepts `--cert-out DIR`. `ordeal check` takes no flags —
do not add any here without verifying them against the real binary.
"""

_TOOLCHAIN_TYPE = "@rules_ordeal//ordeal:toolchain_type"

def _ordeal_check_impl(ctx):
    """Test rule: every .smt2 src must decide `unsat`."""
    toolchain = ctx.toolchains[_TOOLCHAIN_TYPE]
    ordeal_info = toolchain.ordeal_info
    ordeal = ordeal_info.ordeal

    srcs = ctx.files.srcs
    if not srcs:
        fail("ordeal_check requires at least one .smt2 source file")

    src_paths = " ".join(['"{}"'.format(s.short_path) for s in srcs])

    script_content = """\
#!/bin/bash
set -u

ORDEAL="{ordeal}"
TMP="${{TEST_TMPDIR:-/tmp}}"

echo "=== ordeal check gate (ordeal {version}) ==="
fail=0
for src in {src_paths}; do
    out="$("$ORDEAL" check "$src" 2>"$TMP/ordeal_stderr")"
    status=$?
    err="$(cat "$TMP/ordeal_stderr")"
    verdict="$(printf '%s\\n' "$out" | head -n 1)"
    if [ "$verdict" = "unsat" ]; then
        echo "PASS  $src: unsat (checker-validated LRAT certificate)"
    else
        echo "FAIL  $src: expected verdict 'unsat', got '${{verdict:-<no output>}}' (exit $status)"
        if [ -n "$out" ]; then
            printf 'stdout:\\n%s\\n' "$out"
        fi
        if [ -n "$err" ]; then
            printf 'stderr:\\n%s\\n' "$err"
        fi
        fail=1
    fi
done

if [ $fail -eq 0 ]; then
    echo "=== PASSED ==="
else
    echo "=== FAILED ==="
fi
exit $fail
""".format(
        ordeal = ordeal.short_path,
        version = ordeal_info.version,
        src_paths = src_paths,
    )

    test_script = ctx.actions.declare_file(ctx.label.name + "_ordeal_check.sh")
    ctx.actions.write(
        output = test_script,
        content = script_content,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = test_script,
            runfiles = ctx.runfiles(files = srcs + [ordeal]),
        ),
    ]

ordeal_check_test = rule(
    implementation = _ordeal_check_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".smt2"],
            mandatory = True,
            doc = "QF_BV SMT-LIB2 scripts that must each decide `unsat`.",
        ),
    },
    toolchains = [_TOOLCHAIN_TYPE],
    test = True,
    doc = """Test that each .smt2 src decides `unsat` under ordeal.

Passes only when ordeal prints the verdict `unsat` (which ordeal only does
after its LRAT certificate re-checked). A `sat`, `unknown`, parse error, or
unsupported-op error fails the test with the actual verdict and stderr.""",
)

def _ordeal_verus_check_impl(ctx):
    """Test rule: discharge Verus `by (bit_vector)` obligation logs."""
    toolchain = ctx.toolchains[_TOOLCHAIN_TYPE]
    ordeal_info = toolchain.ordeal_info
    ordeal = ordeal_info.ordeal

    srcs = ctx.files.srcs
    if not srcs:
        fail("ordeal_verus_check requires at least one .smt2 Verus log file")

    src_paths = " ".join(['"{}"'.format(s.short_path) for s in srcs])

    # `ordeal verus` exits 0 iff no obligation failed AND at least one was
    # discharged, so the exit code is the gate. --cert-out drops the LRAT
    # certificates into the test's undeclared outputs for later re-checking.
    cert_flag = ""
    cert_setup = ""
    if ctx.attr.cert_out:
        cert_setup = 'CERT_DIR="${TEST_UNDECLARED_OUTPUTS_DIR:-$TEST_TMPDIR}/certs"\nmkdir -p "$CERT_DIR"'
        cert_flag = '--cert-out "$CERT_DIR"'

    script_content = """\
#!/bin/bash
set -u

ORDEAL="{ordeal}"
{cert_setup}

echo "=== ordeal verus gate (ordeal {version}) ==="
fail=0
for src in {src_paths}; do
    echo "--- $src"
    if ! "$ORDEAL" verus "$src" {cert_flag}; then
        fail=1
    fi
done

if [ $fail -eq 0 ]; then
    echo "=== PASSED ==="
else
    echo "=== FAILED ==="
fi
exit $fail
""".format(
        ordeal = ordeal.short_path,
        version = ordeal_info.version,
        src_paths = src_paths,
        cert_setup = cert_setup,
        cert_flag = cert_flag,
    )

    test_script = ctx.actions.declare_file(ctx.label.name + "_ordeal_verus.sh")
    ctx.actions.write(
        output = test_script,
        content = script_content,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = test_script,
            runfiles = ctx.runfiles(files = srcs + [ordeal]),
        ),
    ]

ordeal_verus_check_test = rule(
    implementation = _ordeal_verus_check_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".smt2"],
            mandatory = True,
            doc = "Verus --log-all query logs containing `by (bit_vector)` obligations.",
        ),
        "cert_out": attr.bool(
            default = False,
            doc = "Write the checker-validated LRAT certificates to the test's undeclared outputs (outputs.zip).",
        ),
    },
    toolchains = [_TOOLCHAIN_TYPE],
    test = True,
    doc = """Test that discharges Verus `by (bit_vector)` obligations with ordeal.

Runs `ordeal verus` on each log; passes iff every file's obligations
discharge as checker-validated `unsat` (non-zero ordeal exit fails).
Note: a log with zero bitvector obligations fails (ordeal exits 1 when
nothing was discharged).""",
)

def ordeal_check(name, srcs, **kwargs):
    """Macro wrapper so users write `ordeal_check` (Bazel requires the
    underlying test rule class name to end in `_test`)."""
    kwargs.setdefault("size", "small")
    ordeal_check_test(name = name, srcs = srcs, **kwargs)

def ordeal_verus_check(name, srcs, cert_out = False, **kwargs):
    """Macro wrapper so users write `ordeal_verus_check` (Bazel requires the
    underlying test rule class name to end in `_test`)."""
    kwargs.setdefault("size", "small")
    ordeal_verus_check_test(name = name, srcs = srcs, cert_out = cert_out, **kwargs)
