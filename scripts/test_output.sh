#!/bin/bash -

## Print a header
SCRIPT_NAME="Test output formats and messages"
LINE=$(printf "%076s\n" | tr " " "-")
printf "# %s %s\n" "${LINE:${#SCRIPT_NAME}}" "${SCRIPT_NAME}"

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

## Create a test file with 100 identical sequences (different headers)
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
#                               Output messages                               #
#                                                                             #
#*****************************************************************************#

## Pairwise alignment settings are not printed if d = 1 (issue #75)
DESCRIPTION="Pairwise alignment settings are not printed if d = 1"
"${SWARM}" -d 1 < "${ALL_IDENTICAL}" 2>&1 | \
    grep --quiet "^Scores:\|Gap penalties:\|Converted costs:" && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Pairwise alignment settings are printed if d > 1 (issue #75)
DESCRIPTION="Pairwise alignment settings are printed if d > 1"
"${SWARM}" -d 2 < "${ALL_IDENTICAL}" 2>&1 | \
    grep --quiet "^Scores:\|Gap penalties:\|Converted costs:" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## If SSE2 instructions are not available, swarm exits with an error
## message. Is it possible to test that?

## Swarm correctly sorts fasta entries by decreasing abundance
echo -e ">b_2\nTT\n>c_1\nAT\n>d_1\nGG\n>a_2\nAA\n" | swarm 2> /dev/null

## 

## Statistics

# - swarm produces a 6-column table when the option -s is used (see also issue 9)

# - what happens if the OTU is a singleton? OTU radius should be zero. OK
# - if all sequences are identical, the radius should be zero. FAIL

## Clean
rm "${ALL_IDENTICAL}"

exit 0
