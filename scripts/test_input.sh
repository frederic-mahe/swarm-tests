#!/bin/bash -

## Print a header
SCRIPT_NAME="Test inputs"
line=$(printf "%076s\n" | tr " " "-")
printf "# %s %s\n" "${line:${#SCRIPT_NAME}}" "${SCRIPT_NAME}"

## Declare a color code for test results
RED="\033[1;31m"
GREEN="\033[1;32m"
NO_COLOR="\033[0m"

failure () {
    printf "${RED}FAIL${NO_COLOR}: ${1}\n"
    # exit -1
}

success () {
    printf "${GREEN}PASS${NO_COLOR}: ${1}\n"
}

## Create a test file with 10 identical sequences (different headers)
ALL_IDENTICAL=$(mktemp)
for ((i=1 ; i<=10 ; i++)) ; do
    printf ">%s%d_1\nACGT\n" "seq" ${i}
done > "${ALL_IDENTICAL}"

## use the first swarm binary in $PATH by default, unless user wants
## to test another binary
SWARM=$(which swarm)
[[ "${1}" ]] && SWARM="${1}"

DESCRIPTION="check if swarm is executable"
[[ -x "${SWARM}" ]] && success "${DESCRIPTION}" || failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                               Input channels                                #
#                                                                             #
#*****************************************************************************#

## swarm reads from a file
DESCRIPTION="swarm reads from a file"
"${SWARM}" "${ALL_IDENTICAL}" &> /dev/null && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"

## swarm reads from a pipe
DESCRIPTION="swarm reads from a pipe"
cat "${ALL_IDENTICAL}" | "${SWARM}" &> /dev/null && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"

## swarm reads from a redirection
DESCRIPTION="swarm reads from a redirection"
"${SWARM}" < "${ALL_IDENTICAL}" &> /dev/null && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"

## swarm reads from a HEREDOC
DESCRIPTION="swarm reads from a HEREDOC"
cat <<End-of-message | swarm &> /dev/null \
    && success "${DESCRIPTION}" || failure "${DESCRIPTION}"
>a_1
ACGT
End-of-message

## swarm reads from a symbolic link
ALL_IDENTICAL2=$(mktemp -u)
ln -s "${ALL_IDENTICAL}" "${ALL_IDENTICAL2}"
DESCRIPTION="swarm reads from a symbolic link"
"${SWARM}" "${ALL_IDENTICAL2}" &> /dev/null && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"
rm -f "${ALL_IDENTICAL2}"

## swarm accepts inputs from named pipes
DESCRIPTION="swarm accepts inputs from named pipes"
mkfifo fifoTestInput123
"${SWARM}" fifoTestInput123 &> /dev/null && \
    success "${DESCRIPTION}" || \
	    failure "${DESCRIPTION}" &
printf ">s_1\nA\n" > fifoTestInput123
rm fifoTestInput123

## swarm reads from a process substitution (anonymous pipe)
DESCRIPTION="swarm reads from a process substitution (unseekable)"
"${SWARM}" <(printf ">a_1\nACGT\n") &> /dev/null && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                                 Fasta input                                 #
#                                                                             #
#*****************************************************************************#

## Test empty sequence
DESCRIPTION="swarm handles empty sequences"
printf ">a_10\n\n" | \
    "${SWARM}" &> /dev/null && \
    failure "${DESCRIPTION}" || success "${DESCRIPTION}"

## Test empty header
DESCRIPTION="swarm aborts on empty fasta headers"
printf ">;size=10\nACGT\n" | \
    "${SWARM}" -z &> /dev/null && \
    failure "${DESCRIPTION}" || success "${DESCRIPTION}"

## Clustering with only one sequence is accepted
DESCRIPTION="clustering with only one sequence is accepted"
printf ">a_10\nACGT\n" | \
    "${SWARM}" &> /dev/null && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"

## Clustering sequences of length 1 should work with d > 1 too (shorter than kmers)
DESCRIPTION="clustering a sequence shorter than kmer length is accepted"
printf ">a_10\nA\n" | \
    "${SWARM}" -d 2 &> /dev/null && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"

## Define ASCII characters accepted in fasta identifiers
DESCRIPTION="ascii characters 1-9, 11-12, 14-31, 33-127 allowed in fasta identifiers"
for i in {1..9} 11 12 {14..31} {33..127} ; do
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">aa${OCTAL}aa_1\nACGT\n" | \
        "${SWARM}" &> /dev/null || \
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
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">aa${OCTAL}aa_1\nACGT\n" | \
        "${SWARM}" &> /dev/null && \
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
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">aa_1 ${OCTAL}padding\nACGT\n" | \
        "${SWARM}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done 
unset OCTAL

## ASCII character 10 (\n) is not allowed in fasta headers (outside identifier)
# 10: "\n"
DESCRIPTION="ascii character 10 is not allowed in fasta headers (outside identifier)"
OCTAL=$(printf "\%04o" 10)
echo -e ">aa_1 ${OCTAL}padding\nACGT\n" | \
    "${SWARM}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
unset OCTAL

## non-ASCII characters accepted in fasta identifiers
DESCRIPTION="non-ASCII characters accepted in fasta identifiers"
printf ">ø_1\nACGT\n" | \
    "${SWARM}"  &> /dev/null && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"

## Define ASCII characters accepted in fasta sequences
# 10: "\n"
# 13: "\r"
# and ACGTUacgtu
# SPACE is not allowed
for i in 0 10 13 65 67 71 84 85 97 99 103 116 117 ; do
    DESCRIPTION="ascii character ${i} is allowed in sequences"
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">aaaa_1\nAC${OCTAL}GT\n" | \
        "${SWARM}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done
unset OCTAL

## Define ASCII characters not accepted in fasta sequences
for i in {1..9} 11 12 {14..64} 66 {68..70} {72..83} {86..96} 98 {100..102} {104..115} {118..127} ; do
    DESCRIPTION="ascii character ${i} is not allowed in sequences"
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">s_1\nAC${OCTAL}GT\n" | \
        "${SWARM}" &> /dev/null && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
done
unset OCTAL

## Swarm aborts if fasta identifiers are not unique
DESCRIPTION="swarm aborts if fasta headers are not unique"
printf ">a_10\nACGT\n>a_10\nAAGT\n" | \
    "${SWARM}" &> /dev/null && \
    failure "${DESCRIPTION}" || success "${DESCRIPTION}"

## Fasta headers can contain more than one underscore symbol
DESCRIPTION="fasta headers can contain more than one underscore symbol"
STATS=$(mktemp)
IDENTIFIER="a_2_2"
printf ">%s_3\nACGTACGT\n" "${IDENTIFIER}" | \
    "${SWARM}" -s "${STATS}" &> /dev/null
grep -qE "[[:blank:]]${IDENTIFIER}[[:blank:]]" "${STATS}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f "${STATS}"
unset IDENTIFIER

## Fasta header must contain an abundance value after being truncated
DESCRIPTION="swarm aborts if fasta headers lacks abundance value"
printf ">a a_1\nACGT\n" | \
    "${SWARM}" 2> /dev/null && \
    failure "${DESCRIPTION}" || success "${DESCRIPTION}"

## swarm aborts if abundance value is not a number
DESCRIPTION="swarm aborts if abundance value is not a number"
printf ">a_n\nACGT\n" | \
    "${SWARM}" 2> /dev/null && \
    failure "${DESCRIPTION}" || success "${DESCRIPTION}"

## swarm aborts if abundance value is zero
DESCRIPTION="swarm aborts if abundance value is zero"
printf ">a_0\nACGT\n" | \
    "${SWARM}" 2> /dev/null && \
    failure "${DESCRIPTION}" || success "${DESCRIPTION}"

## swarm aborts if abundance value is negative
DESCRIPTION="swarm aborts if abundance value is negative"
printf ">a_-1\nACGT\n" | \
    "${SWARM}" 2> /dev/null && \
    failure "${DESCRIPTION}" || success "${DESCRIPTION}"

## swarm accepts large abundance values (2^32 - 1)
DESCRIPTION="swarm accepts large abundance values (up to 2^32 - 1)"
for POWER in {2..32} ; do
    printf ">s1_%d\nA\n" $(( (1 << POWER) - 1 )) | \
        "${SWARM}" &> /dev/null || \
        failure "${DESCRIPTION}"
done && success "${DESCRIPTION}"

## swarm accepts abundance values equal to 2^32
DESCRIPTION="swarm accepts abundance values equal to 2^32"
printf ">s1_%d\nA\n" $(( 1 << 32 )) | \
    "${SWARM}" &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm accepts abundance values equal to 2^32 + 1
DESCRIPTION="swarm accepts abundance values equal to 2^32 + 1"
printf ">s1_%d\nA\n" $(( (1 << 32) + 1 )) | \
    "${SWARM}" &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Clean
rm -f "${ALL_IDENTICAL}"

exit 0

