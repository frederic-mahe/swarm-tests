#!/bin/bash -

## Print a header
SCRIPT_NAME="Test results"
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
#                          Option --no-otu-breaking                           #
#                                                                             #
#*****************************************************************************#

## Effect of the --no-otu-breaking on results
VALLEY=$(mktemp)
echo -e ">a_1000\nAAAAA\n>b_1\nAATAA\n>c_500\nAATTA\n" > "${VALLEY}"

DESCRIPTION="swarm normally outputs two OTUs when breaking is active"
OTUs=$("${SWARM}" < "${VALLEY}" 2> /dev/null | wc -l)
(( ${OTUs} == 2 )) && success "${DESCRIPTION}" || failure "${DESCRIPTION}"

DESCRIPTION="swarm outputs one OTU when --no-otu-breaking is used"
OTUs=$("${SWARM}" -n < "${VALLEY}" 2> /dev/null | wc -l)
(( ${OTUs} == 1 )) && success "${DESCRIPTION}" || failure "${DESCRIPTION}"


## Clean
rm "${ALL_IDENTICAL}" "${VALLEY}"

exit 0
