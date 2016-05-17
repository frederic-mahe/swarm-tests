#!/bin/bash -

## Print a header
SCRIPT_NAME="Fixed bugs"
LINE=$(printf "%076s\n" | tr " " "-")
printf "# %s %s\n" "${LINE:${#SCRIPT_NAME}}" "${SCRIPT_NAME}"

## Declare a color code for test results
RED="\033[1;31m"
GREEN="\033[1;32m"
NO_COLOR="\033[0m"
NULL="/dev/null"

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
#       Swarm radius values should be available via an option (issue 1)       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/1
##
## Swarm radius values are available in the statistics file (-s), 7th column.
DESCRIPTION="issue 1 --- theoretical radii of OTUs is available with -s"
STATISTICS=$(mktemp)
echo -e ">seq1_3\nACGTACGT\n>seq2_1\nACGTTCGT" | \
    "${SWARM}" -d 1 -s "${STATISTICS}" 2> /dev/null > /dev/null
RADIUS=$(awk -F "\t" '{print $7}' "${STATISTICS}")
[[ "${RADIUS}" -eq 1 ]] && success "${DESCRIPTION}" || failure "${DESCRIPTION}"
rm "${STATISTICS}"

#*****************************************************************************#
#                                                                             #
#                    Allow ascii \x01 in headers (issue 2)                    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/1
##
## Allow ascii \x01 in headers (start-of-header, used by NCBI to
## separate entries in the FASTA headers of the NR and NT databases).
DESCRIPTION="issue 2 --- ascii \\\x01 is allowed in fasta headers"
echo -e ">aaa\0001aaa_1\nACGT\n" | \
    "${SWARM}" 2> /dev/null > /dev/null && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                    Check for unique sequences (issue 3)                     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/3
##
## Sequence uniqueness is not checked by swarm (pre-dereplication is
## stated as mandatory in the documentation)


#*****************************************************************************#
#                                                                             #
#                         Sort by abundance (issue 4)                         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/4
##
## Swarm sorts sequences by decreasing abundance (and additional
## criteria to stabilize the sorting)
DESCRIPTION="issue 4 --- fasta entries are sorted by decreasing abundance"
REPRESENTATIVES=$(mktemp)
SEED="seq1"
echo -e ">b_1\nACGTACGT\n>${SEED}_10\nACGTTCGT\n" | \
    "${SWARM}" -w "${REPRESENTATIVES}" 2> /dev/null > /dev/null
head -n 1 "${REPRESENTATIVES}" | grep -q "^>${SEED}_11$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${REPRESENTATIVES}"


#*****************************************************************************#
#                                                                             #
#            Check length of sequences during comparison (issue 5)            #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/5
##
## That optimization cannot be tested from the command line.


#*****************************************************************************#
#                                                                             #
#        Check compositition of sequences during comparison (issue 6)         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/6
##
## That optimization cannot be tested from the command line.


#*****************************************************************************#
#                                                                             #
#                     UCLUST file format output (issue 8)                     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/8
##
## Simply check that swarm produces a non-empty file when using -u
DESCRIPTION="issue 8 --- produce a uclust file with -u"
UCLUST=$(mktemp)
"${SWARM}" -u "${UCLUST}" "${ALL_IDENTICAL}" 2> /dev/null > /dev/null
[[ -e "${UCLUST}" ]] && success "${DESCRIPTION}" || failure "${DESCRIPTION}"
rm "${UCLUST}"


#*****************************************************************************#
#                                                                             #
#                          Compile on Mac (issue 11)                          #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/11
##
## Swarm can be compiled on a Mac.


#*****************************************************************************#
#                                                                             #
#    UCLUST: 4th column of lines starting with C should be "*" (issue 13)     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/13
##
## Check if the 4th column for lines starting with C is "*" (according
## to http://www.drive5.com/usearch/manual/ucout.html, %id should only
## be given for H-records)
DESCRIPTION="issue 13 --- uclust-file's 4th column is \"*\" for non-H lines"
UCLUST=$(mktemp)
"${SWARM}" -u "${UCLUST}" "${ALL_IDENTICAL}" 2> /dev/null > /dev/null
VALUE=$(awk -F "\t" '$1 !~ "H" {print $4}' "${UCLUST}" | sort -du)
[[ "${VALUE}" == "*" ]] && success "${DESCRIPTION}" || failure "${DESCRIPTION}"
rm "${UCLUST}"

#*****************************************************************************#
#                                                                             #
#                   Remove requirement of SSE4.1 (issue 17)                   #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/17
##
## Swarm can be compiled on older computers.


#*****************************************************************************#
#                                                                             #
#             Inconsistent -o and -w output when d > 1 (issue 67)             #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/67
##
## Bug reported by Antti Karkman first and latter by Noah Hoffman.
##
DESCRIPTION="issue 67 --- when d > 1, seed is the first field of the OTU list"
REPRESENTATIVES=$(mktemp)
SEED="seq1"
echo -e ">${SEED}_3\nACGTACGT\n>seq2_1\nACGTTCGT" | \
    "${SWARM}" -w "${REPRESENTATIVES}" 2> /dev/null > /dev/null
head -n 1 "${REPRESENTATIVES}" | grep -q "^>${SEED}_4$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${REPRESENTATIVES}"


#*****************************************************************************#
#                                                                             #
#                      Multithreading bugs (issue 74)                         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/74
##
## Clustering fails on extremely short undereplicated sequences when
## using multithreading.
##
## Sequence or microvariant of sequences have to be of length =
## threads - 1, and have to be repeated (identical sequences)
## (https://github.com/torognes/swarm/issues/74)
MAX_D=5
MAX_T=30
DESCRIPTION="issue 74 --- run normally with short undereplicated sequences"
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
