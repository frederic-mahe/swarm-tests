#!/bin/bash -
# shellcheck disable=SC2015

# *************************************************************************** #
#                                                                             #
#                Pending fixes - regression tests (NOT wired)                 #
#                                                                             #
# *************************************************************************** #
#
# Regression tests for the issues in swarm/REFACTORING_PLAN.md
# (branch tmp_20260626151239). This file is DELIBERATELY NOT referenced
# by run_all_tests.sh.
#
# Most of those issues have been fixed; their tests were migrated into
# the permanent suite:
#   test_input.sh   : empty sequence; oversized abundance reported as too
#                     large (swarm and usearch formats).
#   test_options.sh : all-zero scoring rejected (no divide-by-zero);
#                     fastidious light-swarm count; fastidious + --ceiling
#                     on an all-heavy input; --disable-sse3 matches the
#                     default path.
#
# Only the issue below is still unfixed, so its test is still RED. Move
# it into test_options.sh once the fix lands, then delete this file.
#
# Run with:
#   bash ./scripts/pending_fixes.sh ../swarm/bin/swarm | grep -E "FAIL|PASS"

## Print a header
SCRIPT_NAME="Pending fixes"
LINE=$(printf '%.0s-' {1..76})
printf "# %s %s\n" "${LINE:${#SCRIPT_NAME}}" "${SCRIPT_NAME}"

## Declare a color code for test results
RED="\033[1;31m"
GREEN="\033[1;32m"
NO_COLOR="\033[0m"

failure () {
    printf "%bFAIL%b: %s\n" "${RED}" "${NO_COLOR}" "${1}"
    exit 1
}

success () {
    printf "%bPASS%b: %s\n" "${GREEN}" "${NO_COLOR}" "${1}"
}

## address sanitizer: disable runtime errors for mismatching
## allocation-deallocation methods (new and free for example)
## (temporary workaround)
export ASAN_OPTIONS=alloc_dealloc_mismatch=0

## use the first swarm binary in $PATH by default, unless user wants
## to test another binary
SWARM=$(which swarm 2> /dev/null)
[[ "${1}" ]] && SWARM="${1}"

DESCRIPTION="check if swarm is executable"
[[ -x "${SWARM}" ]] && success "${DESCRIPTION}" || failure "${DESCRIPTION}"


## ------------------------------------------------------------------ E1 [RED]
##
## cli.cc: the --ceiling error message says "range 8 to ..." but the
## enforced minimum (and the man page) is 40. The message for a rejected
## value (here -c 20) must not advertise 8 as a valid lower bound.
## E1 was deferred (see REFACTORING_PLAN.md), so this test is still red.
DESCRIPTION="E1 --- --ceiling error message does not advertise the wrong minimum (8)"
printf ">s_1\nACGT\n" | \
    "${SWARM}" -c 20 -o /dev/null 2>&1 | \
    grep -q "range 8 to" && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


# *************************************************************************** #
#                                                                             #
#       Fixed, but not covered by a black-box test (documented)               #
#                                                                             #
# *************************************************************************** #
#
# These findings were fixed but cannot be exercised through the swarm CLI
# on this platform; verified by code review and cross-compilation only:
#
#  RISK 4  (input_output.cc dup() sentinel)  - needs fd 0/1 closed.
#  RISK 5  (uint64 network-edge offsets)     - needs > 4 billion edges.
#  RISK 7  (Windows memory-query failure)    - Windows-only.
#  RISK 8  (__SSE3__ -> __SSSE3__ guard)     - compile-time guard.
#  RISK 9a (compute_hashtable_size overflow) - needs ~1.8e18 sequences.
#  RISK 9b (compute_hashtable_size(0))       - unreachable (empty input
#          is rejected upstream).
#  RISK 9c (header length narrowing)         - the wrap needs a > 4 GiB
#          header; the sub-limit rejection is already covered by the
#          "swarm rejects too long headers" test in test_input.sh.
#  E3      (AVX OSXSAVE/XGETBV gate)          - display-only flag.
#  E4      (hygiene: ;;, param name, mib[])   - no behaviour change.
#
# RISK 6 (8-bit SIMD gap-boundary seed) was investigated and found to be
# a FALSE POSITIVE: the 8-bit kernel runs only at d>=2, where the
# existing diff_saturation test already bounds gapopen+gapextend <= 127,
# so 2*(gapopen+gapextend) cannot overflow a byte. No fix and no test.

exit 0
