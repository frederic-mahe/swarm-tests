#!/bin/bash -

## Print a header
SCRIPT_NAME="Test inputs"
line=$(printf "%076s\n" | tr " " "-")
printf "# %s %s\n" "${line:${#SCRIPT_NAME}}" "${SCRIPT_NAME}"

## Declare a color code for test results
RED="\033[1;31m"
GREEN="\033[1;32m"
NO_COLOR="\033[0m"
NULL="/dev/null"

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

## Is swarm installed?
SWARM=$(which swarm)
DESCRIPTION="check if swarm is in the PATH"
[[ "${SWARM}" ]] && success "${DESCRIPTION}" || failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                               Input channels                                #
#                                                                             #
#*****************************************************************************#

## swarm reads from a file
DESCRIPTION="swarm reads from a file"
"${SWARM}" "${ALL_IDENTICAL}" 2> "${NULL}" > "${NULL}"  && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"

## swarm reads from a pipe
DESCRIPTION="swarm reads from a pipe"
cat "${ALL_IDENTICAL}" | "${SWARM}" 2> "${NULL}" > "${NULL}"  && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"

## swarm reads from a redirection
DESCRIPTION="swarm reads from a redirection"
"${SWARM}" < "${ALL_IDENTICAL}" 2> "${NULL}" > "${NULL}"  && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"

## swarm reads from a HEREDOC
DESCRIPTION="swarm reads from a HEREDOC"
cat <<End-of-message | swarm 2> "${NULL}" > "${NULL}" \
    && success "${DESCRIPTION}" || failure "${DESCRIPTION}"
>a_1
ACGT
End-of-message

## swarm reads from a symbolic link
ALL_IDENTICAL2=$(mktemp -u)
ln -s "${ALL_IDENTICAL}" "${ALL_IDENTICAL2}"
DESCRIPTION="swarm reads from a symbolic link"
"${SWARM}" "${ALL_IDENTICAL2}" 2> "${NULL}" > "${NULL}"  && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"
rm -f "${ALL_IDENTICAL2}"

## swarm reads from a named pipe (problem: how to close the named pipe?)
# NAMED_PIPE=$(mktemp -u)
# mkfifo "${NAMED_PIPE}"
# echo -e ">a_1\nACGT\n" > "${NAMED_PIPE}"
# DESCRIPTION="swarm reads from a named pipe"
# "${SWARM}" "${NAMED_PIPE}" 2> "${NULL}" > "${NULL}"  && \
#     success "${DESCRIPTION}" || failure "${DESCRIPTION}"
# rm -f "${NAMED_PIPE}"

## swarm reads from a process substitution (anonymous pipe)
DESCRIPTION="swarm reads from a process substitution (unseekable)"
"${SWARM}" <(echo -e ">a_1\nACGT\n") 2> "${NULL}" > "${NULL}"  && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                                 Fasta input                                 #
#                                                                             #
#*****************************************************************************#

## Test empty sequence
DESCRIPTION="swarm handles empty sequences"
echo -e ">a_10\n" | \
    "${SWARM}" 2> "${NULL}" > "${NULL}" && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"

## Test empty header
DESCRIPTION="swarm aborts on empty fasta headers"
echo -e ">;size=10\nACGT\n" | \
    "${SWARM}" -z 2> "${NULL}" > "${NULL}" && \
    failure "${DESCRIPTION}" || success "${DESCRIPTION}"

## Clustering with only one sequence is accepted
DESCRIPTION="clustering with only one sequence is accepted"
echo -e ">a_10\nACGNT\n" | \
    "${SWARM}" 2> "${NULL}" > "${NULL}" && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"

## Clustering sequences of length 1 should work with d > 1 too (shorter than kmers)
DESCRIPTION="clustering a sequence shorter than kmer length is accepted"
echo -e ">a_10\nA" | \
    "${SWARM}" -d 2 2> "${NULL}" > "${NULL}" && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"

## Define ASCII characters accepted in fasta headers
DESCRIPTION="ascii characters 1-9, 11-12, 14-31, 33-127 allowed in fasta headers"
for i in {1..9} 11 12 {14..31} {33..127} ; do
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">aa${OCTAL}aa_1\nACGT\n" | \
        "${SWARM}" 2> "${NULL}" > "${NULL}" || \
        failure "ascii character ${i} allowed in fasta header"
done && success "${DESCRIPTION}"

## Define ASCII characters not accepted in fasta headers
#  0: NULL
# 10: "\n"
# 13: "\r"
# 32: SPACE
for i in 0 10 13 32 ; do
    DESCRIPTION="ascii character ${i} is not allowed in fasta headers"
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">aa${OCTAL}aa_1\nACGT\n" | \
        "${SWARM}" 2> "${NULL}" > "${NULL}" && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
done 

## non-ASCII characters accepted in fasta headers
DESCRIPTION="non-ASCII characters accepted in fasta headers"
echo -e ">ø_1\nACGT\n" | \
    "${SWARM}"  2> "${NULL}" > "${NULL}" && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"

## Define ASCII characters accepted in fasta sequences
for i in 0 10 13 65 67 71 84 85 97 99 103 116 117 ; do
    DESCRIPTION="ascii character ${i} is allowed in sequences"
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">aaaa_1\nAC${OCTAL}GT\n" | \
        "${SWARM}" 2> "${NULL}" > "${NULL}" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Define ASCII characters not accepted in fasta sequences
for i in {1..9} 11 12 {14..64} 66 {68..70} {72..83} {86..96} 98 {100..102} {104..115} {118..127} ; do
    DESCRIPTION="ascii character ${i} is not allowed in sequences"
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">aaaa_1\nAC${OCTAL}GT\n" | \
        "${SWARM}" 2> "${NULL}" > "${NULL}" && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
done

## Swarm aborts if fasta identifiers are not unique
DESCRIPTION="swarm aborts if fasta headers are not unique"
echo -e ">a_10\nACGT\n>a_10\nAAGT\n" | \
    "${SWARM}" 2> "${NULL}" > "${NULL}" && \
    failure "${DESCRIPTION}" || success "${DESCRIPTION}"

## Fasta headers can contain more than one underscore symbol
DESCRIPTION="fasta headers can contain more than one underscore symbol"
STATS=$(mktemp)
IDENTIFIER="a_2_2"
echo -e ">${IDENTIFIER}_3\nACGTACGT" | \
    "${SWARM}" -s "${STATS}" 2> "${NULL}" > "${NULL}"
grep -qE "[[:blank:]]${IDENTIFIER}[[:blank:]]" "${STATS}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f "${STATS}"

## Fasta header must contain an abundance value after being truncated
DESCRIPTION="swarm aborts if fasta headers lacks abundance value"
echo -e ">a a_1\nACGT" | \
    "${SWARM}" 2> "${NULL}" && \
    failure "${DESCRIPTION}" || success "${DESCRIPTION}"

## Test -a, --append-abundance positive integer
# all or *some* sequences can lack abundance values

## Clean
rm -f "${ALL_IDENTICAL}"

exit 0

