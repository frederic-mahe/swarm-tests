#!/bin/bash -

## Print a header
SCRIPT_NAME="Fixed bugs"
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
#                             Multithreading bugs                             #
#                                                                             #
#*****************************************************************************#

## Clustering fails on extremely short undereplicated sequences when
## using multithreading.
##
## Sequence or microvariant of sequences have to be of length =
## threads - 1, and have to be repeated (identical sequences)
## (https://github.com/torognes/swarm/issues/74)
MAX_D=5
MAX_T=30
DESCRIPTION="swarm runs normally with short undereplicated sequences"
for ((d=1 ; d<=$MAX_D ; d++)) ; do
    for ((t=1 ; t<=$MAX_T ; t++)) ; do
        OTUs=$("${SWARM}" \
                   -d ${d} \
                   -t ${t} < ${ALL_IDENTICAL} 2> /dev/null | \
                      wc -l)
        (( ${OTUs} == 1 )) || failure "clustering fails for d=${d} and t=${t}"
    done
done && success "${DESCRIPTION}"

## Clean
rm "${ALL_IDENTICAL}"

exit 0
