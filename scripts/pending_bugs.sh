#!/bin/bash -

## Declare a color code for test results
RED="\033[0;31m"
GREEN="\033[0;32m"
NO_COLOR="\033[0m"

failure () {
    printf "${RED}FAIL${NO_COLOR}: ${1}\n"
    exit -1
}

success () {
    printf "${GREEN}SUCCESS${NO_COLOR}: ${1}\n"
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
#                             Multithreading bugs                             #
#                                                                             #
#*****************************************************************************#

## Number of threads should not impact clustering results (WIP)
for ((t=1 ; t<=30 ; t++)) ; do
    swarm -d 3 -t ${t} < test.fas 2> /dev/null | wc -l
done | sort -nu > /dev/null

exit 0
