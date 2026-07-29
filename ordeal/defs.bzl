"""Public API for rules_ordeal.

Users should load rules from this file:
    load("@rules_ordeal//ordeal:defs.bzl", "ordeal_check", "ordeal_verus_check")
"""

load(
    "//ordeal/private:ordeal.bzl",
    _ordeal_check = "ordeal_check",
    _ordeal_check_test = "ordeal_check_test",
    _ordeal_verus_check = "ordeal_verus_check",
    _ordeal_verus_check_test = "ordeal_verus_check_test",
)

ordeal_check = _ordeal_check
ordeal_check_test = _ordeal_check_test
ordeal_verus_check = _ordeal_verus_check
ordeal_verus_check_test = _ordeal_verus_check_test
