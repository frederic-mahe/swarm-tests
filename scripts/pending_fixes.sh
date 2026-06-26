#!/bin/bash -
# shellcheck disable=SC2015

# *************************************************************************** #
#                                                                             #
#                Pending fixes - regression tests (NOT wired)                 #
#                                                                             #
# *************************************************************************** #
#
# This file collects regression tests for the issues described in
# swarm/REFACTORING_PLAN.md (branch tmp_20260626151239). It is
# DELIBERATELY NOT referenced by run_all_tests.sh, because most tests
# below are RED: they describe the *target* behaviour and therefore
# FAIL against the current swarm binary. As with every script here,
# failure() exits on the first failing test, so this file stops at the
# first not-yet-fixed issue.
#
# Workflow: when a fix lands in swarm, re-run this file; once a test
# turns green, MOVE it into fixed_bugs.sh (the permanent suite) and
# delete it from here. When this file is empty, delete it.
#
# Test status is marked per block:
#   [RED]   - fails today, passes once the fix lands
#   [GUARD] - passes today; protects the fix / documents an invariant
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


# *************************************************************************** #
#                                                                             #
#                 GUARDS (pass today, protect the fixes)                       #
#                                                                             #
# *************************************************************************** #

## --------------------------------------------------------------- BUG 3 [GUARD]
##
## arch/x86_64/qgram_compare.cc:101 uses an MMX intrinsic
## (_mm_movepi64_pi64) without EMMS on the SSE2-without-POPCNT path,
## reached on any machine with --disable-sse3 (-x). The defect is UB
## and may not visibly manifest, so this guard instead checks that the
## fallback (-x) path produces the same clustering as the default path.
## It must keep passing after the fix (option 3A: _mm_cvtsi128_si64).
DESCRIPTION="BUG3 --- --disable-sse3 (-x) clustering matches the default path (d=2)"
DEFAULT=$(printf ">a_5\nACGTACGTAC\n>b_1\nACGTACGTTT\n" | \
              "${SWARM}" -d 2 -o - 2> /dev/null)
FALLBACK=$(printf ">a_5\nACGTACGTAC\n>b_1\nACGTACGTTT\n" | \
               "${SWARM}" -d 2 -x -o - 2> /dev/null)
[[ "${DEFAULT}" == "${FALLBACK}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset DEFAULT FALLBACK

## -------------------------------------------------------------- RISK 11 [GUARD]
##
## cigar.cc / nw_aligner.cc would invoke UB / produce NaN on a
## zero-length alignment. Recommendation 11A is to rely on the parser
## rejecting empty sequences (db.cc:300). This guard documents that
## invariant: an empty sequence must be rejected cleanly (no crash).
DESCRIPTION="RISK11 --- an empty sequence is rejected with a clean error"
printf ">s_1\n\n" | \
    "${SWARM}" -d 1 -o /dev/null 2>&1 | \
    grep -q "Empty sequence" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


# *************************************************************************** #
#                                                                             #
#                   PENDING FIXES (red until fixed)                           #
#                                                                             #
# *************************************************************************** #

## ----------------------------------------------------------------- BUG 1 [RED]
##
## cli.cc:587-596: set_alignment_scoring_system() divides the penalties
## by gcd(...) BEFORE validate_alignment() runs, so scoring parameters
## that drive all penalties to zero cause an integer divide-by-zero
## (SIGFPE / ASan FPE) instead of a clean rejection. After the fix the
## invalid parameters must be reported with swarm's normal "Error:"
## message rather than crashing.
DESCRIPTION="BUG1 --- all-zero scoring is rejected, not a divide-by-zero crash"
printf ">s_1\nACGT\n" | \
    "${SWARM}" -d 2 -m 0 -p 0 -e 0 -g 0 -o /dev/null 2>&1 | \
    grep -q "Error:" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## ---------------------------------------------------------------- BUG 2a [RED]
##
## algod1_statistics.cc:53-66: count_cluster_stats iterates the
## over-allocated padding entries of swarminfo_v (resized in 1024-entry
## chunks) because the resize-down to swarmcount happens only after
## run_fastidious_pass. Padding entries have mass 0 < boundary and are
## miscounted as light swarms, inflating the reported "Light swarms"
## count. Here there is exactly ONE light swarm (b_1) and one heavy
## swarm (a_5), far apart so no graft occurs.
DESCRIPTION="BUG2a --- fastidious reports the true number of light swarms (1, not padding)"
printf ">a_5\nAAAAAAAAAA\n>b_1\nCCCCCCCCCC\n" | \
    "${SWARM}" -d 1 -f -o /dev/null 2>&1 | \
    grep -qx "Light swarms: 1, with 1 amplicons" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## ---------------------------------------------------------------- BUG 2b [RED]
##
## Same root cause: with zero genuine light swarms but padding present,
## the small_clusters==0 short-circuit is defeated and
## compute_bloom_geometry (algod1_statistics.cc:118) divides by
## nucleotides_in_small_clusters==0 when --ceiling is set -> SIGFPE.
## Both swarms here are heavy (a_5, b_5), far apart. The fixed binary
## must complete normally (exit 0).
DESCRIPTION="BUG2b --- fastidious + --ceiling on an all-heavy input does not crash"
printf ">a_5\nAAAAAAAAAA\n>b_5\nCCCCCCCCCC\n" | \
    "${SWARM}" -d 1 -f -c 30000 -o /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## --------------------------------------------------------------- RISK 10a [RED]
##
## db.cc:461-499: a digit run that overflows int64_t makes
## parse_abundance_digits return false, which is indistinguishable from
## "no annotation present". A present-but-oversized swarm-format
## abundance must therefore NOT be reported as a missing annotation.
DESCRIPTION="RISK10a --- oversized swarm-format abundance is not reported as missing"
printf ">s_99999999999999999999\nACGT\n" | \
    "${SWARM}" -d 1 -o /dev/null 2>&1 | \
    grep -q "Abundance annotations not found" && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## --------------------------------------------------------------- RISK 10b [RED]
##
## Same issue via the usearch-style ";size=" annotation (-z).
DESCRIPTION="RISK10b --- oversized usearch-format abundance is not reported as missing"
printf ">s;size=99999999999999999999\nACGT\n" | \
    "${SWARM}" -d 1 -z -o /dev/null 2>&1 | \
    grep -q "Abundance annotations not found" && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## ------------------------------------------------------------------ E1 [RED]
##
## cli.cc:364-368: the --ceiling error message says "range 8 to ..."
## but the enforced minimum is 40. The message for a rejected value
## (here -c 20) must not advertise 8 as a valid lower bound.
DESCRIPTION="E1 --- --ceiling error message does not advertise the wrong minimum (8)"
printf ">s_1\nACGT\n" | \
    "${SWARM}" -c 20 -o /dev/null 2>&1 | \
    grep -q "range 8 to" && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


# *************************************************************************** #
#                                                                             #
#            Issues not covered by a black-box test (documented)              #
#                                                                             #
# *************************************************************************** #
#
# The following review findings cannot be exercised through the swarm
# CLI on this platform; they are verified by code reading only and have
# no test here:
#
#  RISK 4  (input_output.cc dup() > 0)  - needs fd 0/1 closed before
#          exec; not portably expressible in bash.
#  RISK 5  (unsigned int network-edge overflow) - needs > 4 billion
#          d=1 edges.
#  RISK 6  (8-bit SIMD gap-boundary seed truncation) - the buggy and
#          correct paths are selected internally; no CLI oracle.
#          Needs a human-provided expected result (scoring semantics).
#  RISK 7  (Windows GetProcessMemoryInfo/GlobalMemoryStatusEx) -
#          Windows-only.
#  RISK 8  (#ifdef __SSE3__ vs __SSSE3__) - compile-time guard.
#  RISK 9a (compute_hashtable_size uint64 overflow) - needs ~1.8e18
#          sequences.
#  RISK 9b (compute_hashtable_size(0) returns 1) - unreachable: empty
#          input is rejected upstream.
#  RISK 9c (header length narrowed before the size check) - the wrap
#          needs a header > 4 GiB; a sub-limit header is already
#          rejected correctly.
#  E2      (db.cc:917 static buffer in fprintseq) - single-threaded
#          output; no observable effect.
#  E3      (AVX/AVX2 reported without OSXSAVE/XGETBV) - display-only.
#  E4      (assorted hygiene: signedness of asserts, db.cc:141 ";;",
#          db.cc:180 param name, macos C array) - no behaviour change.

exit 0
