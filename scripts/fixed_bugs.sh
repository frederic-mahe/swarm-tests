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
#       Swarm radius values should be available via an option (issue 1)       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/1
##
## Swarm radius values are available in the statistics file (-s), 7th column.
DESCRIPTION="issue 1 --- theoretical radii of OTUs is available with -s"
STATISTICS=$(mktemp)
echo -e ">seq1_3\nACGTACGT\n>seq2_1\nACGTTCGT" | \
    "${SWARM}" -d 1 -s "${STATISTICS}" &> /dev/null
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
    "${SWARM}" &> /dev/null && \
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
DESCRIPTION="issue 3 --- check for unique sequences"
failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                         Sort by abundance (issue 4)                         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/4
##
## Swarm outputs sequences by decreasing abundance (and no additional
## criteria to stabilize the sorting)
DESCRIPTION="issue 4 --- fasta entries are sorted by decreasing abundance"
REPRESENTATIVES=$(mktemp)
SEED="seq1"
echo -e ">b_1\nACGTACGT\n>${SEED}_10\nACGTTCGT\n" | \
    "${SWARM}" -w "${REPRESENTATIVES}" &> /dev/null
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
#                   Store sequences using 2 bits (issue 7)                    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/7
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
"${SWARM}" -u "${UCLUST}" "${ALL_IDENTICAL}" &> /dev/null
[[ -s "${UCLUST}" ]] && success "${DESCRIPTION}" || failure "${DESCRIPTION}"
rm "${UCLUST}"


#*****************************************************************************#
#                                                                             #
#             Output detailed statistics for each swarm (issue 9)             #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/9
##
## Output detailed statistics for each swarm (option -s)
DESCRIPTION="issue 9 --- produce a statistics file with -s"
STATS=$(mktemp)
"${SWARM}" -s "${STATS}" "${ALL_IDENTICAL}" &> /dev/null
[[ -s "${STATS}" ]] && success "${DESCRIPTION}" || failure "${DESCRIPTION}"
rm "${STATS}"


#*****************************************************************************#
#                                                                             #
#                     Check for unique headers (issue 10)                     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/10
##
## Check for unique headers and report error if duplicates are found
DESCRIPTION="issue 10 --- check for unique headers"
echo -e ">a_10\nACGT\n>a_5\nACGT\n" | \
    "${SWARM}" &> /dev/null && \
    failure "${DESCRIPTION}" || success "${DESCRIPTION}"


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
#                          Adapt to AVX2 (issue 12)                           #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/12
##
## That optimization cannot be tested from the command line.


#*****************************************************************************#
#                                                                             #
#    UCLUST: 4th column of lines starting with C should be "*" (issue 13)     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/13
##
## Check if the 4th column for lines starting with C is "*" (according
## to http://www.drive5.com/usearch/manual/ucout.html, identity
## percentage should only be given for H-records)
DESCRIPTION="issue 13 --- uclust-file's 4th column is \"*\" for non-H lines"
UCLUST=$(mktemp)
"${SWARM}" -u "${UCLUST}" "${ALL_IDENTICAL}" &> /dev/null
VALUE=$(awk -F "\t" '$1 !~ "H" {print $4}' "${UCLUST}" | sort -du)
[[ "${VALUE}" == "*" ]] && success "${DESCRIPTION}" || failure "${DESCRIPTION}"
rm "${UCLUST}"


#*****************************************************************************#
#                                                                             #
#       Swarm radius in statistics should be multiplied by d (issue 14)       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/14
##
## The 7th column in statistic file represents the maximum radius. It
## is computed as the sum of the differences from the initial seed to
## to the subseed. This value should be less or equal to the
## generation number multipled by /d/. In the examples below, the
## expected sum is 4 differences (2 + 2), or 3 differences (2 + 1).
DESCRIPTION="issue 14 --- radius is at most a multiple of d (radius <= g * d)"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAACC\n>c_1\nCCCC\n" | \
    "${SWARM}" -d 2 -s "${OUTPUT}" &> /dev/null
(( $(awk -F "\t" '{print $7}' "${OUTPUT}") == 4 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

DESCRIPTION="issue 14 --- radius is in fact the sum of differences"
OUTPUT=$(mktemp)
printf ">a_3\nAAA\n>b_2\nACC\n>c_1\nCCC\n" | \
    "${SWARM}" -d 2 -s "${OUTPUT}" &> /dev/null
(( $(awk -F "\t" '{print $7}' "${OUTPUT}") == 3 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#             Fix bug in affine alignment backtracking (issue 15)             #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/15
##
## TODO: can that be tested?


#*****************************************************************************#
#                                                                             #
#                Improve speed by advanced filtering (issue 16)               #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/16
##
## That kmer-based optimization cannot be tested from the command line.


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
#            Graceful exit if cpu features are missing (issue 18)             #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/18
##
## That optimization cannot be tested from the command line.


#*****************************************************************************#
#                                                                             #
#             Avoid requirement of POPCNT instruction (issue 19)              #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/19
##
## That optimization cannot be tested from the command line.


#*****************************************************************************#
#                                                                             #
#            Errors in statistics: radius and generation (issue 20)           #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/20
##
## Description is not precise enough to create a test. There are tests
## covering the -s output in the file test_options.sh


#*****************************************************************************#
#                                                                             #
#        More informative error message for illegal characters (issue 21)     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/21
##
## When an illegal character in a sequence is detected, inform the
## user of where that character was found. SWARM (1.2.6) now reports
## the line number and the bad character.
DESCRIPTION="issue 21 --- report first illegal fasta character and line number"
OCTAL=$(printf "\%04o" 66)
echo -e ">aaaa_1\nAC${OCTAL}GT\n" | \
    "${SWARM}" 2>&1 | \
    grep -qE "Error: Illegal character \'.\' in sequence on line [0-9]+" && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#             Support for usearch amplicon-abundance (issue 22)               #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/22
##
## support for usearch amplicon-abundance notation style
USEARCH=$(mktemp)
for OPTION in "-z" "--usearch-abundance" ; do
    for STYLE in '/^>/ s/_/;size=/' '/^>/ s/_/;size=/ ; /^>/ s/$/;/' ; do
	    sed "${STYLE}" "${ALL_IDENTICAL}" > "${USEARCH}"
	    if [[ "${STYLE}" == '/^>/ s/_/;size=/' ]] ; then	    
	        DESCRIPTION="issue 22 --- support for usearch abundance ending with semicolon (${OPTION})"
	    else
	        DESCRIPTION="issue 22 --- support for usearch abundance ending without semicolon (${OPTION})"
	    fi
	    "${SWARM}" "${OPTION}" "${USEARCH}" &> /dev/null && \
	        success "${DESCRIPTION}" || failure "${DESCRIPTION}"
    done
done
rm "${USEARCH}"


#*****************************************************************************#
#                                                                             #
#                Provide Mothur-compatible output files (issue 23)            #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/23
##
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! TODO


#*****************************************************************************#
#                                                                             #
#        More informative error message for illegal characters (issue 24)     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/24
##

#*****************************************************************************#
#                                                                             #
#                         Refine clustering (issue 25)                        #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/25
##

#*****************************************************************************#
#                                                                             #
#                   Add d value in mothur-output (issue 26)                   #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/26
##

#*****************************************************************************#
#                                                                             #
#                        Progress Indication (issue 27)                       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/27
##

#*****************************************************************************#
#                                                                             #
#    Accelerate pairwise comparisons for the special case d = 1 (issue 28)    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/28
##

#*****************************************************************************#
#                                                                             #
#       Exact string matching strategy (special case d = 1) (issue 29)        #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/29
##

#*****************************************************************************#
#                                                                             #
#   Add the number of differences in the output of the d option (issue 30)    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/30
##

#*****************************************************************************#
#                                                                             #
#     expand on the swarm_breaker.py -b option to check $PATH (issue 31)      #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/31
##

#*****************************************************************************#
#                                                                             #
#         Extend ideas used in new strategy for d=1 to d>1 (issue 32)         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/32
##

#*****************************************************************************#
#                                                                             #
# Unstable order of amplicons with new approach d=1 with >1 thread (issue 33) #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/33
##


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
#              Bug in the -b option output (critical) (issue 34)              #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/34
##

#*****************************************************************************#
#                                                                             #
#             Segmentation fault (or SIGABRT) with -a (issue 35)              #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/35
##

#*****************************************************************************#
#                                                                             #
#        Read input from stdin if no filename is specified (issue 36)         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/36
##

#*****************************************************************************#
#                                                                             #
#Sequence headers with multiple underscore characters cause problems(issue 37)#
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/37
##

#*****************************************************************************#
#                                                                             #
#    swarm_breaker.py handles multi-line fasta files incorrectly (issue 38)   #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/38
##

#*****************************************************************************#
#                                                                             #
#            swarm_breaker.py sometimes hangs forever (issue 39)              #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/39
##

#*****************************************************************************#
#                                                                             #
#      Integrate the swarm-breaker into the main swarm code (issue 40)        #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/40
##

#*****************************************************************************#
#                                                                             #
#             Inconsistent -o and -w output when d > 1 (issue 67)             #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/67
##
## Bug reported by Antti Karkman first and latter by Noah Hoffman.
DESCRIPTION="issue 67 --- when d > 1, seed is the first field of the OTU list"
REPRESENTATIVES=$(mktemp)
SEED="seq1"
echo -e ">${SEED}_3\nACGTACGT\n>seq2_1\nACGTTCGT" | \
    "${SWARM}" -w "${REPRESENTATIVES}" &> /dev/null
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


#*****************************************************************************#
#                                                                             #
#        Pairwise alignement settings not printed with -d 1 (issue 75)        #
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


#*****************************************************************************#
#                                                                             #
#       Stable input sorting to avoid variability in results (issue 80)       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/80
##
## Swarm internally sorts sequences by decreasing abundance. Sequences
## should also be sorted by increasing alpha-numerical order to
## stabilize the sorting (assuming headers are unique)
DESCRIPTION="issue 80 --- clustering results are not affected by input order"
CLUSTERS_A=$(mktemp)
CLUSTERS_B=$(mktemp)
echo -e ">a_2\nAA\n>b_2\nTT\n>c_1\nAT\n" | \
    "${SWARM}" -o "${CLUSTERS_A}" 2> /dev/null
echo -e ">b_2\nTT\n>a_2\nAA\n>c_1\nAT\n" | \
    "${SWARM}" -o "${CLUSTERS_B}" 2> /dev/null
cmp -s "${CLUSTERS_A}" "${CLUSTERS_B}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f "${CLUSTERS_A}" "${CLUSTERS_B}"


#*****************************************************************************#
#                                                                             #
#         How to handle duplicated parameters or options ? (issue 101)        #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/101
##
## issue 101 --- fail if an option is passed twice #1
DESCRIPTION="issue 101 --- fail if an option is passed twice #1"
"${SWARM}" -d 2 -d 2 < "${ALL_IDENTICAL}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## issue 101 --- fail if an option is passed twice #2
DESCRIPTION="issue 101 --- fail if an option is passed twice #2"
"${SWARM}" -v -v < "${ALL_IDENTICAL}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## issue 101 --- fail if an unknown option is passed
DESCRIPTION="issue 101 --- fail if an unknown option is passed"
"${SWARM}" --smurf < "${ALL_IDENTICAL}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


## Clean
rm "${ALL_IDENTICAL}"

exit 0

(
