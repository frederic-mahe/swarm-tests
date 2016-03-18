#!/bin/bash -

## Print a header
SCRIPT_NAME="Pending bugs"
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
#                                Dereplication                                #
#                                                                             #
#*****************************************************************************#

## Swarm complains if input sequences are not dereplicated (issue 65)
DESCRIPTION="complains if input sequences are not dereplicated"
"${SWARM}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

#*****************************************************************************#
#                                                                             #
#                             Multithreading bugs                             #
#                                                                             #
#*****************************************************************************#

## Swarm sometimes hangs endlessly.
##
## Torbjørn wrote: This might have something to do with the starting
## and stopping of the threads and the synchronisation of the
## threads. When I developed this part of Swarm I noticed that
## sometimes it would not shut down all threads correctly and wait
## forever. I thought I had fixed it and have never experienced it
## myself thereafter. Perhaps a combination of OS version and bad luck
## makes it appear once in a while.
##
## As of now, we cannot replicate that bug and test it.


## Clean
rm "${ALL_IDENTICAL}"

exit 0
