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
#                              Option --threads                               #
#                                                                             #
#*****************************************************************************#

## Number of threads (--threads is not specified)
DESCRIPTION="swarm runs normally when --threads is not specified"
[[ $("${SWARM}" < "${ALL_IDENTICAL}" 2> /dev/null ) ]] && \
    success  "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of threads (--threads from 1 to 256)
MIN=1
MAX=256
for ((t=$MIN ; t<=$MAX ; t++)) ; do
    DESCRIPTION="swarm runs normally when --threads goes from ${MIN} to ${MAX}"
    [[ $("${SWARM}" -t ${t} < "${ALL_IDENTICAL}" 2> /dev/null ) ]] || \
        failure "swarm aborts when --threads equals ${t}"
done && success  "${DESCRIPTION}"

## Number of threads (--threads is empty)
DESCRIPTION="swarm aborts when --threads is empty"
[[ $("${SWARM}" -t < "${ALL_IDENTICAL}" 2> /dev/null ) ]] && \
    failure "${DESCRIPTION}" || \
        success  "${DESCRIPTION}"

## Number of threads (--threads is zero)
DESCRIPTION="swarm aborts when --threads is zero"
[[ $("${SWARM}" -t 0 < "${ALL_IDENTICAL}" 2> /dev/null ) ]] && \
    failure "${DESCRIPTION}" || \
        success  "${DESCRIPTION}"

## Number of threads (--threads is 257)
DESCRIPTION="swarm aborts when --threads is 257"
[[ $("${SWARM}" -t 257 < "${ALL_IDENTICAL}" 2> /dev/null ) ]] && \
    failure "${DESCRIPTION}" || \
        success  "${DESCRIPTION}"

## Number of threads (--threads is way too large)
DESCRIPTION="swarm aborts when --threads is 8 billions"
[[ $("${SWARM}" -t 8000000000 < "${ALL_IDENTICAL}" 2> /dev/null ) ]] && \
    failure "${DESCRIPTION}" || \
        success  "${DESCRIPTION}"

## Number of threads (--threads is non-numerical)
DESCRIPTION="swarm aborts when --threads is not numerical"
[[ $("${SWARM}" -t "a" < "${ALL_IDENTICAL}" 2> /dev/null ) ]] && \
    failure "${DESCRIPTION}" || \
        success  "${DESCRIPTION}"

## Clean
rm "${ALL_IDENTICAL}"

exit 0
