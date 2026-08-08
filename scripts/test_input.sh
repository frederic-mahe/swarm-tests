#!/bin/bash -
# shellcheck disable=SC2015

## Print a header
SCRIPT_NAME="Test inputs"
line=$(printf '%.0s-' {1..76})
printf "# %s %s\n" "${line:${#SCRIPT_NAME}}" "${SCRIPT_NAME}"

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
[[ -x "${SWARM}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                               Input channels                                #
#                                                                             #
#*****************************************************************************#

## swarm reads from a file
DESCRIPTION="swarm reads from a file"
FASTA=$(mktemp)
printf ">s_1\nA\n" > "${FASTA}"
"${SWARM}" "${FASTA}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f "${FASTA}"
unset FASTA

## swarm reads from a pipe
DESCRIPTION="swarm reads from a pipe"
printf ">s_1\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm reads from a redirection
DESCRIPTION="swarm reads from a redirection"
FASTA=$(mktemp)
printf ">s_1\nA\n" > "${FASTA}"
"${SWARM}" < "${FASTA}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f "${FASTA}"
unset FASTA

## swarm reads from a HEREDOC
DESCRIPTION="swarm reads from a HEREDOC"
cat <<End-of-message | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
>s_1
A
End-of-message

## swarm reads from a symbolic link
FASTA=$(mktemp)
FASTA_LINK=$(mktemp -u)
printf ">s_1\nA\n" > "${FASTA}"
ln -s "${FASTA}" "${FASTA_LINK}"
DESCRIPTION="swarm reads from a symbolic link"
"${SWARM}" "${FASTA_LINK}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f "${FASTA}" "${FASTA_LINK}"
unset FASTA FASTA_LINK

## swarm accepts inputs from named pipes
# DESCRIPTION="swarm accepts inputs from named pipes"
# mkfifo fifo_test
# "${SWARM}" fifo_test > /dev/null 2>&1 && \
#     success "${DESCRIPTION}" || \
#       failure "${DESCRIPTION}" &
# printf ">s_1\nA\n" > fifo_test
# rm fifo_test
# sleep 2s && kill $(ps -C $(basename "${SWARM}") -o pid=) 2> /dev/null

## swarm reads from a process substitution (anonymous pipe)
DESCRIPTION="swarm reads from a process substitution (unseekable)"
"${SWARM}" <(printf ">a_1\nACGT\n") > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm now checks its streams when it closes them, and a failed read
## is one of the failures that reports. A directory can be opened but
## not read, so it reaches that check; swarm used to treat the failed
## read as the end of the input, cluster nothing, and return 0.
DESCRIPTION="an input that cannot be read is reported"
TMP=$(mktemp -d)
"${SWARM}" -o /dev/null "${TMP}" 2>&1 > /dev/null | \
    grep -qx "Error: I/O error on a swarm file; the output may be incomplete." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rmdir "${TMP}"
unset TMP

DESCRIPTION="an input that cannot be read returns a status of 1"
TMP=$(mktemp -d)
"${SWARM}" -o /dev/null "${TMP}" > /dev/null 2>&1
STATUS=$?
rmdir "${TMP}"
[[ "${STATUS}" -eq 1 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset TMP STATUS


#*****************************************************************************#
#                                                                             #
#                                 Fasta input                                 #
#                                                                             #
#*****************************************************************************#

## Test empty input
DESCRIPTION="swarm handles empty input"
printf "" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm fails if header does not start with '>'
DESCRIPTION="swarm errors out if header does not start with '>'"
printf "@s_1\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm fails if input file is not readable
DESCRIPTION="swarm errors out if input file is not readable"
TMP=$(mktemp)
printf ">s_1\nA\n" > "${TMP}"
chmod u-r "${TMP}"
"${SWARM}" "${TMP}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
chmod +r "${TMP}" && rm -f "${TMP}"
unset TMP

## output files are still created, even when input is empty
## (check if file is created)
DESCRIPTION="empty input yields empty output (-o)"
TMP=$(mktemp -u)
printf "" | \
    "${SWARM}" -o "${TMP}" 2> /dev/null
[[ -e "${TMP}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f "${TMP}"

DESCRIPTION="empty input yields empty output (-w)"
TMP=$(mktemp -u)
printf "" | \
    "${SWARM}" -w "${TMP}" 2> /dev/null
[[ -e "${TMP}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f "${TMP}"

## Test empty sequence
DESCRIPTION="swarm handles empty sequences (single \\\n)"
printf ">s_1\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

DESCRIPTION="swarm handles empty sequences (double \\\n)"
printf ">s_1\n\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## ---------------------------- set of early-detection tests for db_read issues

## std::cin

DESCRIPTION="accepts empty sequence line (first line)"
printf ">s1_1\n\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="accepts empty sequence line (last line)"
printf ">s1_1\nA\n\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="accepts empty sequence line (middle line)"
printf ">s1_1\nA\n\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="accepts missing final new line"
printf ">s1_1\nA" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="rejects empty last sequence"
printf ">s1_1\nA\n>s2_1\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

DESCRIPTION="rejects empty first sequence"
printf ">s1_1\n>s2_1\nC\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

DESCRIPTION="rejects empty middle sequence"
printf ">s1_1\nA\n>s2_1\n>s3_1\nG\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## file descriptor input

DESCRIPTION="accepts empty sequence line (first line)"
"${SWARM}" <(printf ">s1_1\n\nA\n") > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="accepts empty sequence line (last line)"
"${SWARM}" <(printf ">s1_1\nA\n\n") > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="accepts empty sequence line (middle line)"
"${SWARM}" <(printf ">s1_1\nA\n\nA\n") > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="accepts missing final new line"
"${SWARM}" <(printf ">s1_1\nA") > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="rejects empty last sequence"
"${SWARM}" <(printf ">s1_1\nA\n>s2_1\n") > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

DESCRIPTION="rejects empty first sequence"
"${SWARM}" <(printf ">s1_1\n>s2_1\nC\n") > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

DESCRIPTION="rejects empty middle sequence"
"${SWARM}" <(printf ">s1_1\nA\n>s2_1\n>s3_1\nG\n") > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## ------------------------------------------------------------------------ end

## Test completely empty header
DESCRIPTION="swarm aborts on empty fasta headers"
printf ">\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Test empty header
DESCRIPTION="swarm aborts on empty fasta headers"
printf ">_1\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Test empty header (;size=n format)
DESCRIPTION="swarm aborts on empty fasta headers (-z)"
printf ">;size=1\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Test empty sequence
# the pairwise aligner relies on this rejection (an empty alignment
# would otherwise divide by zero when computing percent identity)
DESCRIPTION="swarm aborts on an empty sequence with a clear error"
printf ">s_1\n\n" | \
    "${SWARM}" -d 1 -o /dev/null 2>&1 | \
    grep -q "Empty sequence" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Test abundance value at the int64_t maximum (19 digits)
DESCRIPTION="swarm accepts an abundance equal to int64_t max (9223372036854775807)"
printf ">s_9223372036854775807\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Test abundance value overflowing int64_t (20 digits, _ format)
DESCRIPTION="swarm aborts on an abundance value overflowing int64_t"
printf ">s_99999999999999999999\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Test abundance value overflowing int64_t (;size=n format)
DESCRIPTION="swarm aborts on an abundance value overflowing int64_t (-z)"
printf ">s;size=99999999999999999999\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## A present-but-oversized abundance must be reported as too large, not
## silently treated as a missing annotation (it used to be reported as
## "Abundance annotations not found"). Strengthens the exit-code tests
## above by checking the error message (_ format).
DESCRIPTION="swarm reports an overflowing abundance as too large, not missing"
printf ">s_99999999999999999999\nACGT\n" | \
    "${SWARM}" -d 1 -o /dev/null 2>&1 | \
    grep -q "is too large" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## same, with the usearch-style ";size=" annotation (-z)
DESCRIPTION="swarm reports an overflowing abundance as too large, not missing (-z)"
printf ">s;size=99999999999999999999\nACGT\n" | \
    "${SWARM}" -d 1 -z -o /dev/null 2>&1 | \
    grep -q "is too large" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Test long headers
DESCRIPTION="swarm accepts headers as long as (127 - 5) chars"
MAX=122  # ">" + MAX + "_1\n\0" = MAX + 5
HEADER="$(head -c ${MAX} < /dev/zero | tr '\0' 's')"
printf ">%s_1\nA\n" "${HEADER}" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset MAX HEADER

DESCRIPTION="swarm accepts headers as long as (255 - 5) chars"
MAX=250  # ">" + MAX + "_1\n\0" = MAX + 5
HEADER="$(head -c ${MAX} < /dev/zero | tr '\0' 's')"
printf ">%s_1\nA\n" "${HEADER}" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset MAX HEADER

DESCRIPTION="swarm accepts headers as long as LINE_MAX - 5 (2,043)"
MAX=2043  # ">" + MAX + "_1\n\0" = 2043 + 5 = 2048 = OK
HEADER="$(head -c ${MAX} < /dev/zero | tr '\0' 's')"
printf ">%s_1\nA\n" "${HEADER}" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset MAX HEADER

DESCRIPTION="swarm accepts headers as long as (32767 - 5) chars"
MAX=32762  # ">" + MAX + "_1\n\0" = MAX + 5
HEADER="$(head -c ${MAX} < /dev/zero | tr '\0' 's')"
printf ">%s_1\nA\n" "${HEADER}" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset MAX HEADER

DESCRIPTION="swarm accepts headers as long as (65535 - 5) chars"
MAX=65530  # ">" + MAX + "_1\n\0" = MAX + 5
HEADER="$(head -c ${MAX} < /dev/zero | tr '\0' 's')"
printf ">%s_1\nA\n" "${HEADER}" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset MAX HEADER

# tests requiring at least a gigabyte of available RAM
if which free > /dev/null 2>&1 ; then
    AVAILABLE_RAM=$(free | awk 'NR == 2 {print $7}')
    if [[ ${AVAILABLE_RAM} -ge 1048576 ]] ; then
        DESCRIPTION="swarm: trigger reallocation (2^20 chars header, size of memchunk)"
        MAX=$(( 1024 * 1024 ))  # ">" + MAX + "_1\n\0" = MAX + 5
        HEADER="$(head -c ${MAX} < /dev/zero | tr '\0' 's')"
        printf ">%s_1\nA\n" "${HEADER}" | \
            "${SWARM}" > /dev/null 2>&1 && \
            success "${DESCRIPTION}" || \
                failure "${DESCRIPTION}"
        unset MAX HEADER

        DESCRIPTION="swarm: trigger reallocation (add sequence length)"
        MAX=$(( 1024 * 1024 - 8 ))  # ">" + MAX + "_1\n\0" = MAX + 5
        HEADER="$(head -c ${MAX} < /dev/zero | tr '\0' 's')"
        printf ">%s_1\nA\n" "${HEADER}" | \
            "${SWARM}" > /dev/null 2>&1 && \
            success "${DESCRIPTION}" || \
                failure "${DESCRIPTION}"
        unset MAX HEADER

        DESCRIPTION="swarm: trigger reallocation (add sequence number)"
        MAX=$(( 1024 * 1024 - 20 ))  # ">" + MAX + "_1\n\0" = MAX + 5
        HEADER="$(head -c ${MAX} < /dev/zero | tr '\0' 's')"
        printf ">%s_1\nA\n>r_1\nC\n" "${HEADER}" | \
            "${SWARM}" > /dev/null 2>&1 && \
            success "${DESCRIPTION}" || \
                failure "${DESCRIPTION}"
        unset MAX HEADER

        DESCRIPTION="swarm: trigger reallocation (add remaining nt_buffer)"
        MAX=$(( 1024 * 1024 - 20 ))  # ">" + MAX + "_1\n\0" = MAX + 5
        HEADER="$(head -c ${MAX} < /dev/zero | tr '\0' 's')"
        printf ">%s_1\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC\n" "${HEADER}" | \
            "${SWARM}" > /dev/null 2>&1 && \
            success "${DESCRIPTION}" || \
                failure "${DESCRIPTION}"
        unset MAX HEADER
    fi
fi


# DESCRIPTION="swarm aborts on headers longer than LINE_MAX - 5 (2,044)"
# MAX=2044 # ">" + MAX + "_1\n\0" = 2044 + 5 = 2049 = ERROR
# printf ">%s_1\nA\n" $(head -c ${MAX} < /dev/zero | tr '\0' 's') | \
#     "${SWARM}" > /dev/null 2>&1 && \
#     failure "${DESCRIPTION}" || \
#         success "${DESCRIPTION}"
# unset MAX

## Clustering with only one sequence is accepted
DESCRIPTION="clustering with only one sequence is accepted"
printf ">s_1\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Clustering sequences of length 1 should work with d > 1 too (shorter than kmers)
DESCRIPTION="clustering a sequence shorter than kmer length is accepted"
printf ">s_1\nA\n" | \
    "${SWARM}" -d 2 > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Define ASCII characters accepted in fasta identifiers
DESCRIPTION="ascii characters 1-9, 11-12, 14-31, 33-127 allowed in fasta identifiers"
for i in {1..9} 11 12 {14..31} {33..127} ; do
    OCTAL=$(printf "\%04o" "${i}")
    echo -e ">s${OCTAL}_1\nA\n" | \
        "${SWARM}" > /dev/null 2>&1 || \
        failure "ascii character ${i} allowed in fasta identifiers"
done && success "${DESCRIPTION}"
unset OCTAL

## Define ASCII characters not accepted in fasta identifiers
#  0: NULL
# 10: "\n"
# 13: "\r"
# 32: SPACE
for i in 0 10 13 32 ; do
    DESCRIPTION="ascii character ${i} is not allowed in fasta identifiers"
    OCTAL=$(printf "\%04o" "${i}")
    echo -e ">s${OCTAL}_1\nA\n" | \
        "${SWARM}" > /dev/null 2>&1 && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
done
unset OCTAL

## Define ASCII characters accepted in fasta headers
#  0: NULL
# 13: "\r"
# 32: SPACE
for i in 0 13 32 ; do
    DESCRIPTION="ascii character ${i} is allowed in fasta header (outside identifier)"
    OCTAL=$(printf "\%04o" "${i}")
    echo -e ">s_1 ${OCTAL}\nA\n" | \
        "${SWARM}" > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done
unset OCTAL

## ASCII character 10 (\n) is not allowed in fasta headers (outside identifier)
# 10: "\n"
DESCRIPTION="ascii character 10 is not allowed in fasta headers (outside identifier)"
OCTAL=$(printf "\%04o" 10)
echo -e ">s_1 ${OCTAL}s\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
unset OCTAL

## ASCII character 10 (\n) is allowed at the end of fasta headers (outside identifier)
# 10: "\n"
DESCRIPTION="ascii character 10 is allowed at the end of fasta headers (outside identifier)"
OCTAL=$(printf "\%04o" 10)
echo -e ">s_1 ${OCTAL}\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset OCTAL

## non-ASCII characters accepted in fasta identifiers
DESCRIPTION="non-ASCII characters accepted in fasta identifiers"
printf ">ø_1\nA\n" | \
    "${SWARM}"  > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Define ASCII characters accepted in fasta sequences
# 10: "\n"
# 13: "\r"
# and ACGTUacgtu
# SPACE is not allowed
for i in 0 10 13 65 67 71 84 85 97 99 103 116 117 ; do
    DESCRIPTION="ascii character ${i} is allowed in sequences"
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">s_1\nAC${OCTAL}GT\n" | \
        "${SWARM}" > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done
unset OCTAL

## Define ASCII characters not accepted in fasta sequences
for i in {1..9} 11 12 {14..64} 66 {68..70} {72..83} {86..96} 98 {100..102} {104..115} {118..127} ; do
    DESCRIPTION="ascii character ${i} is not allowed in sequences"
    OCTAL=$(printf "\%04o" "${i}")
    echo -e ">s_1\nAC${OCTAL}GT\n" | \
        "${SWARM}" > /dev/null 2>&1 && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
done
unset OCTAL

## Bytes with the high bit set are not nucleotides either. The manual
## states that swarm "exits with an error message if any other symbol is
## present", and these are the byte values the accept/reject loops above
## do not reach: 128 to 255 cannot be spelled as an ascii character, but
## they occur in real input (a latin-1 file, a UTF-8 byte-order mark,
## non-ascii text pasted into a sequence line).
for i in {128..255} ; do
    DESCRIPTION="byte ${i} is not allowed in sequences"
    OCTAL=$(printf "\%04o" "${i}")
    echo -e ">s_1\nAC${OCTAL}GT\n" | \
        "${SWARM}" > /dev/null 2>&1 && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
done
unset OCTAL

## The loop above checks the exit status, which cannot tell a clean
## rejection from a crash. Before the classification table was sized to
## the whole byte range, byte 144 indexed past its end: in a release build
## it was silently read as a 'C' (so "AC<144>GT" clustered as the 5
## nucleotide sequence ACCGT), and in a sanitizer build the same read
## aborted inside the redzone. Both exit non-zero for the wrong reason, so
## assert the message too.
DESCRIPTION="a byte with the high bit set is reported as an illegal character"
printf ">s_1\nAC%bGT\n" "\x90" | \
    "${SWARM}" 2>&1 > /dev/null | \
    grep -qx "Error: Illegal character (byte value 144) in sequence on line 2." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## A NUL inside a sequence line truncates the sequence there, silently:
## "AC\x00GT" is read as "AC", so the amplicon is 2 nt long, not 4. The
## "ascii character 0 is allowed in sequences" test above checks only the
## exit status, so it cannot see the truncation. Assert the length the
## -u record reports instead (field 3 of the S line).
DESCRIPTION="a NUL inside a sequence line truncates the sequence (2 nt, not 4)"
printf ">s_1\nAC%bGT\n" "\x00" | \
    "${SWARM}" \
        -o /dev/null \
        -u - 2> /dev/null | \
    awk -F'\t' '$1 == "S" {print $3}' | \
    grep -qx "2" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## A NUL inside a header truncates the identifier there, so the abundance
## annotation that follows it is not seen, and the error message reports
## the truncated identifier. Complements the issue 72 tests in
## fixed_bugs.sh, which assert that this input is rejected without
## showing what swarm read.
DESCRIPTION="a NUL inside a header truncates the identifier before the annotation"
printf ">s%b_1\nA\n" "\x00" | \
    "${SWARM}" \
        -o /dev/null 2>&1 | \
    grep -q "^>s$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## A null byte at the *start* of a line yields a zero-length line, not
## end-of-input. It used to be indistinguishable from end-of-input, so
## swarm silently discarded the rest of the file: the second amplicon
## below simply vanished and swarm still exited 0. Note this is distinct
## from a null byte *inside* a line, which still truncates that line
## (see the two tests above).
DESCRIPTION="a line starting with a NUL does not truncate the input"
printf ">s_1\nAAAA\n%b\n>t_1\nCCCC\n" "\x00" | \
    "${SWARM}" -o /dev/null 2>&1 | \
    grep -q "2 sequences" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## a null byte before the first header leaves swarm looking at a
## zero-length line where a header is required
DESCRIPTION="a NUL before the first header is rejected"
printf "%b>s_1\nA\n" "\x00" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm aborts if fasta identifiers are not unique
DESCRIPTION="swarm aborts if fasta headers are not unique"
printf ">s_1\nA\n>s_1\nC\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm aborts if fasta identifiers are not unique, and reports the
## first duplicated identifier (abundance annotations are removed)
DESCRIPTION="swarm reports the first duplicated identifier (default)"
printf ">ampliconid_10\nA\n>ampliconid_1\nC\n" | \
    "${SWARM}" 2>&1 > /dev/null | \
    grep -m 1 "^Error" | \
    grep -oq "ampliconid$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm aborts if fasta identifiers are not unique, and reports the
## first duplicated identifier (abundance annotations are removed)
DESCRIPTION="swarm reports the first duplicated identifier (;size=)"
printf ">ampliconid;size=10\nA\n>ampliconid;size=1\nC\n" | \
    "${SWARM}" -z 2>&1 > /dev/null | \
    grep -m 1 "^Error" | \
    grep -oq "ampliconid$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm reports the duplicated identifier when the first occurrence
## uses the 'size=N;label' style (abundance-first) and the second uses
## the 'label;size=N' style (abundance-last)
DESCRIPTION="swarm reports the duplicated identifier (size=N;label first, then label;size=N)"
printf ">size=10;ampliconid\nA\n>ampliconid;size=1\nC\n" | \
    "${SWARM}" -z 2>&1 > /dev/null | \
    grep -m 1 "^Error" | \
    grep -oq "ampliconid$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Fasta headers can contain more than one underscore symbol
DESCRIPTION="fasta headers can contain more than one underscore symbol"
printf ">s_2_2_3\nA\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk '{exit $3 == "s_2_2" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Fasta headers can contain more than one "size=" (-z)
DESCRIPTION="fasta headers can contain more than one 'size=' (-z)"
printf ">asize=;size=1\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Fasta header must contain an abundance value after being truncated
DESCRIPTION="swarm aborts if fasta headers lacks abundance value"
printf ">s s_1\nA\n" | \
    "${SWARM}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if abundance value is not a number
DESCRIPTION="swarm aborts if abundance value is not a number"
printf ">s_n\nA\n" | \
    "${SWARM}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if abundance value is zero
DESCRIPTION="swarm aborts if abundance value is zero"
printf ">s_0\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if abundance value is zero
DESCRIPTION="swarm aborts if abundance value is zero"
printf ">s_0\nA\n" | \
    "${SWARM}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if abundance value is negative
DESCRIPTION="swarm aborts if abundance value is negative"
printf ">s_-1\nA\n" | \
    "${SWARM}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if abundance value is negative (-z)
DESCRIPTION="swarm aborts if abundance value is negative (-z)"
printf ">s;size=-1\nA\n" | \
    "${SWARM}" -z 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if abundance value is zero (-z)
DESCRIPTION="swarm aborts if abundance value is zero (-z)"
printf ">s;size=0\nA\n" | \
    "${SWARM}" -z 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm accepts size= at the start of the header (-z)
DESCRIPTION="swarm accepts size= at the start of the header (-z)"
printf ">size=1;s\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm accepts ;size= at the start of the header (-z)
DESCRIPTION="swarm accepts ;size= at the start of the header (-z)"
printf ">;size=1;s\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm accepts ;size= at the end of the header (-z)
DESCRIPTION="swarm accepts ;size= at the end of the header (-z)"
printf ">s;size=1\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm accepts ;size=INT; at the end of the header (-z)
DESCRIPTION="swarm accepts ;size=INT; at the end of the header (-z)"
printf ">s;size=1;\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm accepts text on both sides of ;size=INT; (-z)
DESCRIPTION="swarm accepts text on both sides of ;size=INT; (-z)"
printf ">s;size=1;s\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm aborts if header has no text at all besides size=INT (-z)
DESCRIPTION="swarm aborts if header has no text at all besides size=INT (-z)"
printf ">size=1\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if header has no text at all besides ;size=INT (-z)
DESCRIPTION="swarm aborts if header has no text at all besides ;size=INT (-z)"
printf ">;size=1\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if header has no text at all besides ;size=INT; (-z)
DESCRIPTION="swarm aborts if header has no text at all besides ;size=INT; (-z)"
printf ">;size=1;\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if header has no text at all besides size=INT; (-z)
DESCRIPTION="swarm aborts if header has no text at all besides size=INT; (-z)"
printf ">size=1;\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if text and size=INT are not ;-separated (-z)
DESCRIPTION="swarm aborts if text and size=INT are not ;-separated 1 (-z)"
printf ">ssize=1\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if text and size=INT are not ;-separated (-z)
DESCRIPTION="swarm aborts if text and size=INT are not ;-separated 2 (-z)"
printf ">size=1s\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if text and size=INT are not ;-separated (-z)
DESCRIPTION="swarm aborts if text and size=INT are not ;-separated 3 (-z)"
printf ">s;size=1s\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## the header ends with 'size=' but the digit run is empty: no match,
## swarm scans to the end of the header and reports a missing abundance
DESCRIPTION="swarm aborts if the header ends with an empty size= (-z)"
printf ">s;size=\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## same as above, but the header consists solely of an empty 'size='
DESCRIPTION="swarm aborts if the header is exactly an empty size= (-z)"
printf ">size=\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm accepts large abundance values (2^32 - 1)
DESCRIPTION="swarm accepts large abundance values (up to 2^32 - 1)"
for POWER in {2..32} ; do
    printf ">s1_%d\nA\n" $(( (1 << POWER) - 1 )) | \
        "${SWARM}" > /dev/null 2>&1 || \
        failure "${DESCRIPTION}"
done && success "${DESCRIPTION}"
unset POWER

## swarm accepts abundance values equal to 2^32
DESCRIPTION="swarm accepts abundance values equal to 2^32"
printf ">s_%d\nA\n" $(( 1 << 32 )) | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm accepts abundance values equal to 2^32 + 1
DESCRIPTION="swarm accepts abundance values equal to 2^32 + 1"
printf ">s_%d\nA\n" $(( (1 << 32) + 1 )) | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm aborts if abundance value has more than 20 digits
DESCRIPTION="swarm aborts if abundance value has more than 20 digits"
printf ">s_123456789012345678901\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm ignores stdin output if file is given
DESCRIPTION="swarm ignores stdin output if file is given"
printf ">s1_1\nA\n" | \
    "${SWARM}" <(printf ">s2_1\nT\n") 2> /dev/null | \
    grep -q "^s1_1$" && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm d = 1 can process sequences with more than 32 nucleotides
## (zobrist.cc coverage)
DESCRIPTION="swarm d = 1 accepts sequences with 32 nucleotides or more"
MAX=32
SEQUENCE="$(head -c ${MAX} < /dev/zero | tr '\0' 'A')"
printf ">s_1\n%s\n" "${SEQUENCE}" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset MAX SEQUENCE

## swarm d = 1 can process sequences with more than 5000 nucleotides
DESCRIPTION="swarm d = 1 accepts sequences with 5000 nucleotides or more"
MAX=5000
SEED="$(head -c ${MAX} < /dev/zero | tr '\0' 'A')"
SUBSEED="${SEED/A/C}"
printf ">s1_3\n%s\n>s2_1\n%s\n" "${SEED}" "${SUBSEED}" | \
    "${SWARM}" -l /dev/null | \
    grep -q "^s1_3 s2_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset SEED SUBSEED

## swarm d = 2 can process sequences with more than 5000 nucleotides
DESCRIPTION="swarm d = 2 accepts sequences with 5000 nucleotides or more"
MAX=5000
SEED="$(head -c ${MAX} < /dev/zero | tr '\0' 'A')"
SUBSEED="${SEED/A/C}"
printf ">s1_3\n%s\n>s2_1\n%s\n" "${SEED}" "${SUBSEED}" | \
    "${SWARM}" -d 2 -l /dev/null | \
    grep -q "^s1_3 s2_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset SEED SUBSEED

## swarm can printout sequences with more than 1025 nucleotides
## (db.cc coverage: default buffer can contain 1024 nucleotides)
DESCRIPTION="swarm can output sequences with more than 1025 nucleotides (-w)"
MAX=1025
SEQUENCE="$(head -c ${MAX} < /dev/zero | tr '\0' 'A')"
printf ">s_1\n%s\n" "${SEQUENCE}" | \
    "${SWARM}" -w - > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset MAX SEQUENCE

## swarm does not accept compressed input on stdin
DESCRIPTION="swarm does not accept compressed input (gz)"
printf ">s1_2\nAA\n>s2_1\nAT\n" | \
    gzip --stdout | \
    "${SWARM}" -d 2 -x > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

DESCRIPTION="swarm does not accept compressed input (bz2)"
printf ">s1_2\nAA\n>s2_1\nAT\n" | \
    bzip2 --stdout | \
    "${SWARM}" -d 2 -x > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


## swarm accepts decompressed input on stdin
DESCRIPTION="swarm accepts decompressed input (gz)"
printf ">s1_2\nAA\n>s2_1\nAT\n" | \
    gzip --stdout | \
    zcat | \
    "${SWARM}" -d 2 -x > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="swarm accept decompressed input (bz2)"
printf ">s1_2\nAA\n>s2_1\nAT\n" | \
    bzip2 --stdout | \
    bzcat | \
    "${SWARM}" -d 2 -x > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


## An empty positional argument is rejected at parse time. swarm's input
## filename defaults to '-' (stdin), so downstream code takes "the
## filename is always set" for granted and asserts it. Without the parse
## time check the empty string reached that assert, which aborted a
## DEBUG build (SIGABRT) on what is ordinary bad input, while a release
## build reported the fopen failure instead. The next three tests pin the
## rejection, its message, and the two neighbouring cases that must keep
## their own behaviour.
## a status of exactly 1, not merely non-zero: the manpage requires 1 for
## any error, and the abort this used to produce exited 134, which a plain
## '|| success' would have accepted
DESCRIPTION="swarm rejects an empty input file name with a status of 1"
printf ">s1_1\nA\n" | \
    "${SWARM}" "" > /dev/null 2>&1
[[ $? -eq 1 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="swarm reports an empty input file name as such"
printf ">s1_1\nA\n" | \
    "${SWARM}" "" 2>&1 > /dev/null | \
    grep -q "Empty input file name" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## '-' is the documented way to ask for stdin, and is what the option
## defaults to: it must not be caught by the check above
DESCRIPTION="swarm accepts '-' as the input file name (stdin)"
printf ">s1_1\nA\n" | \
    "${SWARM}" - 2> /dev/null | \
    grep -q "^s1_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## a non-empty name that cannot be opened still reports the open failure,
## not the empty-name message
DESCRIPTION="swarm reports an unopenable input file name as such"
"${SWARM}" /dev/null/nonexistent 2>&1 > /dev/null | \
    grep -q "Unable to open input data file" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                           Realistic input file                              #
#                                                                             #
#*****************************************************************************#

# I think it would be a good idea to add some tests using a somewhat
# larger database than the current tests. A fixed database of some
# 1000-10000 sequences, perhaps subsampled from small real dataset. It
# could be run with -d 0, -d 1, -d 1 -f, and -d 2 and with both 1 and 2
# threads. All output files could be generated and the correct contents
# of those could be checked with a fingerprint (md5 or sha1). I think it
# would trigger some of the code lines that are not covered as of
# now. It could also reveal more subtle errors introduced in the code.

## Work in progress!
# THREADS=1
# DIFFERENCES=0

# ${SWARM} \
#     -d ${DIFFERENCES} \
#     -z \
#     -t ${THREADS} \
#     -o /dev/null \
#     -l /dev/null \
#     <(zcat ../data/T111_30k_reads.fas.gz)  # 1-thread run takes 150 ms

# When testing with a natural dataset, the absolute expected result is
# not known. To solve that, an alternative would be to create a
# perfectly controlled dataset, with a know internal
# structure. Simulation is a possibility, but I could also produce an
# exhaustive set (all primary and secondary microvariants for a given
# sequence). However, it is not possible to do so for sequences longer
# than 100 nucleotides, as the number of microvariants is rougly 50
# times the squared length: 500k for a length of 100, more than 7
# million for an 18S V4 sequence.

# cd Swarms/tests/microvariants/
# python2 produce_microvariants_two_layers.py > tmp.fas

exit 0
