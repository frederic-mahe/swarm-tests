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
    exit -1
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

# swarm reads from a stream
# swarm reads from a file
# swarm reads from a redirection
# swarm reads from a named pipe


#*****************************************************************************#
#                                                                             #
#                                 Fasta input                                 #
#                                                                             #
#*****************************************************************************#

# issue 2: ASCII characters accepted in fasta headers (test all of them: \x01 should be valid)
# issue 2: test non-ASCII characters (frédéric and torbjørn)

# Test empty sequence
# Test empty header

# Test characters accepted in sequences
# Improve help regarding N characters

# Clustering with only one sequence should work

# Clustering sequences of length 1 should work with d > 1 too (shorter than kmers)

## Fasta headers can contain more than one underscore symbol
DESCRIPTION="fasta headers can contain more than one underscore symbol"
STATS=$(mktemp)
IDENTIFIER="a_2_2"
echo -e ">${IDENTIFIER}_3\nACGTACGT" | \
    "${SWARM}" -s "${STATS}" 2> /dev/null > /dev/null
grep -qE "[[:blank:]]${IDENTIFIER}[[:blank:]]" "${STATS}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${STATS}"


## Clean
rm "${ALL_IDENTICAL}"

exit 0

