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
## stated as mandatory in the documentation).
##
## This is a mock-up for a possible warning message when duplicated
## sequences are present.
DESCRIPTION="issue 3 --- check for unique sequences"
WARNING="warning: some sequences were identical"
printf ">s1_1\nAA\n>s2_1\nAA\n" | \
    "${SWARM}" 2>&1 | grep -q "^${WARNING}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                         Sort by abundance (issue 4)                         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/4
##
## Swarm outputs identifiers by decreasing abundance (and no
## additional criteria to stabilize the sorting)
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
awk '$1 !~ "H" && $4 != "*" {exit 1}' "${UCLUST}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
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
## Swarm can produce output files compatible with Mothur.
for OPTION in "-r" "--mothur" ; do
    DESCRIPTION="issue 23 --- swarms accepts the option ${OPTION}"
    "${SWARM}" "${OPTION}" < "${ALL_IDENTICAL}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done


#*****************************************************************************#
#                                                                             #
#            Linearization awk code prints last line twice (issue 24)         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/24
##
## Does not concern swarm itself, but the linearization command.


#*****************************************************************************#
#                                                                             #
#                         Refine clustering (issue 25)                        #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/25
##
## Deprecated. That step is now performed directly by swarm.


#*****************************************************************************#
#                                                                             #
#                   Add d value in mothur-output (issue 26)                   #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/26
##
## -r reports the d value
DESCRIPTION="issue 26 --- -r reports the d value"
OUTPUT=$(mktemp)
D=2
printf ">a_5\nAAAA\n" | "${SWARM}" -d "${D}" -r > "${OUTPUT}" 2> /dev/null
grep -q "swarm_${D}" "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#                        Progress Indication (issue 27)                       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/27
##
## swarm indicates its progress during the clustering process
DESCRIPTION="issue 27 ---- report progress during the clustering process"
printf ">s_1\nA\n" | "${SWARM}" 2>&1 | \
    sed 's/\r/\n/' | \
    grep -q -m 2 "Clustering: .*%" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#    Accelerate pairwise comparisons for the special case d = 1 (issue 28)    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/28
##
## cannot be tested from the command line.


#*****************************************************************************#
#                                                                             #
#       Exact string matching strategy (special case d = 1) (issue 29)        #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/29
##
## implemented in swarm v1.2.8, default algorithm for d = 1


#*****************************************************************************#
#                                                                             #
#   Add the number of differences in the output of the d option (issue 30)    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/30
##
## -i number of differences is correct while -d 2 (2 expected)
OUTPUT=$(mktemp)
DESCRIPTION="issue 30 --- number of differences is correct in -i while -d 2 (2 expected)"
printf ">a_1\nAAAA\n>b_1\nAACC\n" | \
    "${SWARM}" -d 2 -i "${OUTPUT}" &> /dev/null
SORTED_OUTPUT=$(awk -F "\t" '{print $3}' "${OUTPUT}")
(( "${SORTED_OUTPUT}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#     expand on the swarm_breaker.py -b option to check $PATH (issue 31)      #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/31
##
## Deprecated.


#*****************************************************************************#
#                                                                             #
#         Extend ideas used in new strategy for d=1 to d>1 (issue 32)         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/32
##
## Dead end.


#*****************************************************************************#
#                                                                             #
# Unstable order of amplicons with new approach d=1 with >1 thread (issue 33) #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/33
##
## A, B, C, D, where abundances are a such A > B > C >D, and possible
## (d = 1)-edges as such: A - B, A - D, B - C, B - D, C - D. Without
## sorting, we could obtain the minimum spanning tree A - D - {B, C},
## that goes through a valley (D). The expected tree is A - {B - C, D}.
##
DESCRIPTION="issue 33 --- subseeds are sorted by decreasing abundant"
OUTPUT=$(mktemp)
EXPECTED=$(printf "a\tb\t1\t1\t1\na\tc\t1\t1\t1\nb\td\t1\t1\t2\n")
printf ">a_5\nAA\n>d_1\nGC\n>b_2\nAC\n>c_1\nGA\n" | \
    "${SWARM}" -i "${OUTPUT}" &> /dev/null
[[ $(< "${OUTPUT}") == "${EXPECTED}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#              Bug in the -b option output (critical) (issue 34)              #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/34
##
## Deprecated parameter -b


#*****************************************************************************#
#                                                                             #
#             Segmentation fault (or SIGABRT) with -a (issue 35)              #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/35
##
## Deprecated parameter -a


#*****************************************************************************#
#                                                                             #
#        Read input from stdin if no filename is specified (issue 36)         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/36
##
## issue 36 --- swarm reads from a pipe
DESCRIPTION="issue 36 --- swarm reads from a pipe"
printf ">s_1\na\n" | "${SWARM}" &> /dev/null && \
    success "${DESCRIPTION}" || failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#     Sequence headers with multiple underscores cause problems(issue 37)     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/37
##
## issue 37 --- fasta headers can contain more than one underscore symbol
DESCRIPTION="issue 37 --- fasta headers can contain more than one underscore symbol"
STATS=$(mktemp)
IDENTIFIER="a_2_2"
echo -e ">${IDENTIFIER}_3\nACGTACGT" | \
    "${SWARM}" -s "${STATS}" &> /dev/null
grep -qE "[[:blank:]]${IDENTIFIER}[[:blank:]]" "${STATS}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${STATS}"


#*****************************************************************************#
#                                                                             #
#    swarm_breaker.py handles multi-line fasta files incorrectly (issue 38)   #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/38
##
## swarm_breaker.py is deprecated


#*****************************************************************************#
#                                                                             #
#            swarm_breaker.py sometimes hangs forever (issue 39)              #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/39
## swarm_breaker.py is deprecated


#*****************************************************************************#
#                                                                             #
#      Integrate the swarm-breaker into the main swarm code (issue 40)        #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/40
##
## issue 40 --- swarm performs OTU breaking by default
DESCRIPTION="issue 40 --- swarm performs OTU breaking by default"
LINENUMBER=$(printf ">a_10\nACGT\n>b_9\nCGGT\n>c_1\nCCGT\n" | \
		            "${SWARM}" 2> /dev/null | wc -l)
(( "${LINENUMBER}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#        Add the OTU number to the output of the -b option (issue 41)         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/41
##
## issue 41 --- -i number of the OTU is correct #1
OUTPUT=$(mktemp)
DESCRIPTION="issue 41 --- -i number of the OTU is correct #1"
printf ">a_1\nAAAA\n>b_1\nAAAC\n" | \
    "${SWARM}" -i "${OUTPUT}" &> /dev/null
SORTED_OUTPUT=$(awk -F "\t" '{print $4}' "${OUTPUT}")
(( "${SORTED_OUTPUT}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## issue 41 --- -i number of the OTU is correct #2
OUTPUT=$(mktemp)
DESCRIPTION="issue 41 --- -i number of the OTU is correct #2"
printf ">a_1\nAA\n>b_1\nAC\n>c_1\nGG\n>d_1\nGT\n" | \
    "${SWARM}" -i "${OUTPUT}" &> /dev/null
SORTED_OUTPUT=$(awk '{n = $4} END {print n}' "${OUTPUT}")
(( "${SORTED_OUTPUT}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#        Add the OTU number to the output of the -b option (issue 42)         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/42
##
## issue 42 --- swarm accepts --fastidious options
DESCRIPTION="issue 42 --- swarm accepts --fastidious options"
printf ">s_1\nA\n" | "${SWARM}" -f &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                   Chimera checking and swarm (issue 43)                     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/43
##
## question answered requiring no test


#*****************************************************************************#
#                                                                             #
#Rewrite search8.cc and search16.cc to allow compilation for 32-bit (issue 44)#
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/44
##
## not testable


#*****************************************************************************#
#                                                                             #
#              Assigning taxonomy to swarm centroids (issue 45)               #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/45
##
## question answered requiring no test


#*****************************************************************************#
#                                                                             #
#                 Avoid SSE3 and SSSE3 dependency (issue 46)                  #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/46
##
## not testable from command line


#*****************************************************************************#
#                                                                             #
#           Downstream analysis on otutable or biom file (issue 47)           #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/47
##
## external to swarm, not testable.


#*****************************************************************************#
#                                                                             #
#               Use swarm for dereplication (-d 0) (issue 48)                 #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/48
##
## issue 48 --- swarm accepts -d 0
DESCRIPTION="issue 48 --- swarm accepts -d 0"
printf ">s_1\nA\n" | "${SWARM}" -d 0 &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## issue 48 --- -d 0 delete duplicate sequences
DESCRIPTION="issue 48 --- -d 0 delete duplicate sequences"
OBSERVED=$(printf ">s_1\nA\n>w_1\nC\n" | "${SWARM}" -d 0 2> /dev/null | wc -l) 
(( "${OBSERVED}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#               Compilation issue with swarm 2.0.4 (issue 49)                 #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/49
##
## time consuming to test and no real interest


#*****************************************************************************#
#                                                                             #
#                    Galaxy wrapper for Swarm (issue 50)                      #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/50
##
## galaxy wrapper exists : https://github.com/geraldinepascal/FROGS


#*****************************************************************************#
#                                                                             #
#Abundance annotation style should also be in the output fasta file (issue 51)#
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/51
##
## issue 51 --- -w gives abudance notation style matching the input #1
OUTPUT=$(mktemp)
DESCRIPTION="issue 51 --- -w gives abudance notation style matches input #1"
EXPECTED=$(printf ">a_1\naaaa\n")
printf ">a_1\nAAAA\n" | \
    "${SWARM}" -w "${OUTPUT}" &> /dev/null
[[ "$(< "${OUTPUT}")" == "${EXPECTED}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## issue 51 --- -w gives abudance notation style matching the input #2
OUTPUT=$(mktemp)
DESCRIPTION="issue 51 --- -w gives abudance notation style matches input #2"
EXPECTED=$(printf ">a;size=1;\naaaa\n")
printf ">a;size=1;\nAAAA\n" | \
    "${SWARM}" -w "${OUTPUT}" -z &> /dev/null
[[ "$(< "${OUTPUT}")" == "${EXPECTED}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#            Improve documentation of Fastidious option (issue 52)            #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/52
##
## not really testable, but doc has been indeed improved since this question


#*****************************************************************************#
#                                                                             #
#               Minor inconsistencies with fastidious (issue 53)              #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/53
##
## a sequence and all its microvariants should form only one OTU

function microvariants() {
    local SEQ="${1}"
    local -i LENGTH=${#SEQ}
    for ((i=0 ; i<=LENGTH ; i++)) ; do
        ## insertions
        for n in A C G T ; do 
            echo ${SEQ:0:i}${n}${SEQ:i:LENGTH}
        done
        if (( i > 0 )) ; then 
            ## deletions
            echo ${SEQ:0:i-1}${SEQ:i:LENGTH}
            ## substitutions
            for n in A C G T ; do
                echo ${SEQ:0:i-1}${n}${SEQ:i:LENGTH}
            done
        fi
    done    
}

## produce a fasta set with a seed and all its L1 microvariants
DESCRIPTION="issue 53 --- swarm correctly computes all microvariants"
OUTPUT=$(mktemp)
SEQUENCE="ACGT"
microvariants ${SEQUENCE} | \
    awk '{print ">s"NR"_1\n"$1}' | \
    "${SWARM}" -o "${OUTPUT}" 2> /dev/null
(( $(wc -l < "${OUTPUT}") == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


## produce a fasta set with a seed, all its L2 microvariants but no L1 microvariants
DESCRIPTION="issue 53 --- fastidious links L2 microvariants and the seed"
SEQUENCE="ACGT"
OUTPUT=$(mktemp)
MICROVARIANTS_L1=$(microvariants ${SEQUENCE} | sort -du | grep -v "^${SEQUENCE}$")
MICROVARIANTS_L2=$(while read MICROVARIANT ; do
                       microvariants ${MICROVARIANT}
                   done <<< "${MICROVARIANTS_L1}" | \
                       sort -du | grep -v "^${SEQUENCE}$")
(printf ">seed_1\n%s\n" ${SEQUENCE}
comm -23 <(echo "${MICROVARIANTS_L2}") <(echo "${MICROVARIANTS_L1}") | \
    awk '{print ">s"NR"_1\n"$1}') | \
    "${SWARM}" -d 1 -f -o "${OUTPUT}" 2> /dev/null
(( $(wc -l < "${OUTPUT}") == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


## perform an independent test for each L2 microvariant
DESCRIPTION="issue 53 --- fastidious links each L2 microvariant and the seed"
SEQUENCE="ACGT"
OUTPUT=$(mktemp)
## produce L1 and L2 microvariants
MICROVARIANTS_L1=$(microvariants ${SEQUENCE} | sort -du | grep -v "^${SEQUENCE}$")
MICROVARIANTS_L2=$(while read MICROVARIANT ; do
                       microvariants ${MICROVARIANT}
                   done <<< "${MICROVARIANTS_L1}" | \
                       sort -du | grep -v "^${SEQUENCE}$")
## produce a fasta set with the seed, L2 microvariants and no L1 microvariants
comm -23 <(echo "${MICROVARIANTS_L2}") <(echo "${MICROVARIANTS_L1}") | \
    while read MICROVARIANT_L2 ; do
        printf ">seed_10\n%s\n>m_1\n%s\n" ${SEQUENCE} ${MICROVARIANT_L2} | \
            "${SWARM}" -d 1 -f -o "${OUTPUT}" 2> /dev/null
        (( $(wc -l < "${OUTPUT}") == 1 )) || \
                failure "${DESCRIPTION}"
    done && success "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#                    IUPAC nucleotide ambiguity (issue 54)                    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/54
##
## nucleotide ambiguity (R,Y,S,W,K,M,M,D,B,H,V,N) won't be implemented


#*****************************************************************************#
#                                                                             #
#          Complete integration of the fastidious option? (issue 55)          #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/55
##
## It is only the internal-structure (-i) file and columns 6 and 7 of
## the statistics file (-s) that are not updated.
##
## Updating the file --statistics-file seems difficult: the 6th and
## 7th columns report the number of growth iterations and the length
## of the longest, continuous, down-hill abundance path in the
## OTU. Updating these columns would break that idea of continuity.
##
## So the output of the --internal-structure (-i) is the only thing
## that would make sense updating.

## The grafted amplicons should receive a number of differences of 2
## (present output: "", expected output: a b 2 1 2).
OUTPUT=$(mktemp)
DESCRIPTION="issue 55 --- grafted amplicon receives a number of difference of 2"
printf ">a_3\nAAAA\n>b_1\nAATT\n" | \
    "${SWARM}" -f -i "${OUTPUT}" &> /dev/null
NUMBER_OF_DIFFERENCES=$(awk '{print $3}' "${OUTPUT}")
NUMBER_OF_DIFFERENCES=${NUMBER_OF_DIFFERENCES:=0} # set to zero if null
(( "${NUMBER_OF_DIFFERENCES}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Grafted amplicons receive the OTU number of the main OTU (in this
## toy example, the 4th column should be always equal to 1)
OUTPUT=$(mktemp)
DESCRIPTION="issue 55 --- grafted amplicons receive the OTU number of the main OTU"
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_1\nATTT\n>d_1\nTTTT\n" | \
    "${SWARM}" -f -i "${OUTPUT}" &> /dev/null
awk '$4 != 1 {exit 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Number of differences between the grafted amplicon and the grafting point is 2
##
## the structure file should be:
## a   b   1   1   1
## a   c   2   1   2
## c   d   1   1   3
OUTPUT=$(mktemp)
DESCRIPTION="issue 55 --- 2 differences between the grafted amplicon and the grafting point"
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_1\nATTT\n>d_1\nTTTT\n" | \
    "${SWARM}" -f -i "${OUTPUT}" &> /dev/null
awk '$3 == 2 {s = "true"} END {exit s == "true" ? 0 : 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## The fifth column of the structure file should be equal to number of
## steps from the seed to the amplicon.
##
## the structure file should be:
## a   b   1   1   1
## a   c   2   1   2
## c   d   1   1   3
OUTPUT=$(mktemp)
DESCRIPTION="issue 55 --- 5th column is the number of steps from the seed to the amplicon"
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_1\nATTT\n>d_1\nTTTT\n" | \
    "${SWARM}" -f -i "${OUTPUT}" &> /dev/null
awk '$5 > 1 {s = "true"} END {exit s == "true" ? 0 : 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#               Clustering with d = 1 and replicates (issue 56)               #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/56
##
## issue 56 --- -i number of differences is correct with -d 1
##
## with identical sequences we expect zero difference in column 3
DESCRIPTION="issue 56 --- -i number of differences is correct with -d 1"
OUTPUT=$(mktemp)
printf ">s_1\nA\n>w_1\nA\n" | "${SWARM}" -d 1 -i "${OUTPUT}"  &> /dev/null
OBSERVED=$(awk '{print $3}' "${OUTPUT}") 
(( "${OBSERVED}" == 0 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## issue 56 --- -i number of differences is correct with -d 2
##
## with identical sequences we expect zero difference in column 3
DESCRIPTION="issue 56 --- -i number of differences is correct with -d 2"
OUTPUT=$(mktemp)
printf ">s_1\nA\n>w_1\nA\n" | "${SWARM}" -d 2 -i "${OUTPUT}"  &> /dev/null
OBSERVED=$(awk '{print $3}' "${OUTPUT}") 
(( "${OBSERVED}" == 0 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
# Sequence identifiers format, abundance annotation not found error (issue 57)#
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/57
##
## question about normal behaviour


#*****************************************************************************#
#                                                                             #
#                     Allow ambiguous bases? (issue 58)                       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/58
##
## ambigous nucleotides won't be implemented


#*****************************************************************************#
#                                                                             #
#       feature request: assume abundance = 1 when missing (issue 59)         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/59
##
## issue 59 --- swarm accepts -a option
DESCRIPTION="issue 59 --- swarm accepts -a option"
printf ">s\nA\n" | "${SWARM}" -a 2 &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## issue 59 --- number of missing abundance  notation is correct in error message #1
DESCRIPTION="issue 59 --- number of missing abundance  notation is correct in error message #1"
OUTPUT=$(mktemp)
printf ">q_1\nA\n>s\nA\n" | "${SWARM}" 2> "${OUTPUT}"
[[ $(awk '/^Error/{print $7}' "${OUTPUT}") == "1" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## issue 59 --- number of missing abundance  notation is correct in error message #2
DESCRIPTION="issue 59 --- number of missing abundance  notation is correct in error message #2"
OUTPUT=$(mktemp)
printf ">q\nA\n>s_1\nA\n>d\nA\n" | "${SWARM}" 2> "${OUTPUT}"
[[ $(awk '/^Error/{print $7}' "${OUTPUT}") == "2" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## issue 59 --- first line of abundance notation missing is correct in error message #1
DESCRIPTION="issue 59 --- first line of abundance notation missing is correct in error message #1"
OUTPUT=$(mktemp)
printf ">q\nA\n>s_1\nA\n>d\nA\n" | "${SWARM}" 2> "${OUTPUT}"
[[ $(awk '/^Error/{print $12}' "${OUTPUT}") == "1." ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## issue 59 --- first line of abundance notation missing is correct in error message #2
DESCRIPTION="issue 59 --- first line of abundance notation missing is correct in error message #2"
OUTPUT=$(mktemp)
printf ">q_1\nA\n>s\nA\n" | "${SWARM}" 2> "${OUTPUT}"
[[ $(awk '/^Error/{print $12}' "${OUTPUT}") == "3." ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## issue 59 --- swarm -a fails without argument
DESCRIPTION="issue 59 --- swarm -a fails without argument"
printf ">s\nA\n" | "${SWARM}" -a &> /dev/null&& \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## issue 59 --- swarm -a does not overwrite abundance in case of multiple _ with numbers
DESCRIPTION="issue 59 --- issue 59 --- swarm -a does not overwrite abundance in case of multiple _ with numbers"
OUTPUT=$(mktemp)
printf ">a_33_2_3\nA\n>b_33_2_3\nA\n" | \
    "${SWARM}" -a 2 -s "${OUTPUT}" &> /dev/null
(( $(awk '{print $4}' "${OUTPUT}") == 3 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#                 Ability to process fastq files (issue 60)                   #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/60
##
## the ability to process fastq files won't be implemented


#*****************************************************************************#
#                                                                             #
#                 dereplicating pooled specimens (issue 61)                   #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/61
##
## answered question about workflow


#*****************************************************************************#
#                                                                             #
#                Compilation warning with gcc 4.9 (issue 62)                  #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/62
##  
## not really testable


#*****************************************************************************#
#                                                                             #
#             Potential problem reported by cppcheck (issue 63)               #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/63
##  
## not testable (see also issue 104)


#*****************************************************************************#
#                                                                             #
#         digits transposed in file name of 2.1.5 binary (issue 64)           #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/64
##
## not testable


#*****************************************************************************#
#                                                                             #
#            Check that all input sequences are unique (issue 65)             #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/65
##
## issue 65 --- swarm complains if input sequences are not dereplicated
DESCRIPTION="issue 65 --- swarm complains if input sequences are not dereplicated"
"${SWARM}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                   Amplicon length truncation (issue 66)                     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/66
##  
## general question


#*****************************************************************************#
#                                                                             #
#             Inconsistent -o and -w output when d > 1 (issue 67)             #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/67
##
## Bug reported by Antti Karkman first and latter by Noah Hoffman
REPRESENTATIVES=$(mktemp)
SEED="seq1"
for i in {1..3} ; do
    DESCRIPTION="issue 67 --- when d = ${i}, seed is the first field of the OTU list"
    echo -e ">${SEED}_3\nA\n>seq2_1\nA" | \
	    "${SWARM}" -d ${i} -w "${REPRESENTATIVES}" &> /dev/null
    head -n 1 "${REPRESENTATIVES}" | grep -q "^>${SEED}_4$" && \
	    success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done
rm "${REPRESENTATIVES}"

## The sequence of the representatives is the sequence of the seed
REPRESENTATIVES=$(mktemp)
for i in {1..3} ; do
    DESCRIPTION="issue 67 --- the sequence of the representatives is the sequence of the seed"
    echo -e ">seq1_3\nA\n>seq2_1\nT" | \
	    "${SWARM}" -d ${i} -w "${REPRESENTATIVES}" &> /dev/null
    ##  printf ">s\nA\n" | awk 'NR == 2 {exit /^A$/ ? 0 : 1}' && echo "true" || echo "false"
    sed "2q;d" "${REPRESENTATIVES}" | grep -qi "^A$" && \
	    success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done
rm "${REPRESENTATIVES}"


#*****************************************************************************#
#                                                                             #
#  control number of generations, for the iterative growth process (issue 68) #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/68
##  
## TODO


#*****************************************************************************#
#                                                                             #
#                  compiling swarm on osx 1.8.5 (issue 69)                    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/69
##  
## not testable


#*****************************************************************************#
#                                                                             #
#                  ;size=INT not being accepted (issue 70)                    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/70
##
## it is with -z


#*****************************************************************************#
#                                                                             #
#         Make use of base quality score - Fastq support (issue 71)           #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/71
##
## won't be implemented


#*****************************************************************************#
#                                                                             #
#              Strip chr(13) from input fasta files (issue 72)                #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/72
##
## Define ASCII characters not accepted in fasta identifiers
#  0: NULL
# 10: "\n"
# 13: "\r"
# 32: SPACE
for i in 0 10 13 32 ; do
    DESCRIPTION="issue 72 --- ascii character ${i} is not allowed in fasta headers"
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">s${OCTAL}_1\nACGT\n" | \
        "${SWARM}"  &> /dev/null && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
done

## some ascii characters are accepted *if* present at the end of the header
#  0: NULL
# 10: "\n"
# 13: "\r"
# 32: SPACE
for i in 0 10 13 32 ; do
    DESCRIPTION="issue 72 --- ascii character ${i} is accepted if present at the end of the header"
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">s_1${OCTAL}\nACGT\n" | \
        "${SWARM}"  &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done


#*****************************************************************************#
#                                                                             #
#            Return status should be 0 after -h and -v (issue 73)             #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/73
##
## Return status should be 0 after -h and -v
for OPTION in "-h" "--help" "-v" "--version" ; do
    DESCRIPTION="issue 73 --- return status should be 0 after ${OPTION}"
    "${SWARM}" "${OPTION}" 2> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done


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
DESCRIPTION="issue 75 --- Pairwise alignment settings are not printed if d = 1"
"${SWARM}" -d 1 < "${ALL_IDENTICAL}" 2>&1 | \
    grep --quiet "^Scores:\|Gap penalties:\|Converted costs:" && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Pairwise alignment settings are printed if d > 1 (issue #75)
DESCRIPTION="issue 75 --- Pairwise alignment settings are printed if d > 1"
"${SWARM}" -d 2 < "${ALL_IDENTICAL}" 2>&1 | \
    grep --quiet "^Scores:\|Gap penalties:\|Converted costs:" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                  Control the range of `d` values (issue 76)                 #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/76
##  
## Number of differences (--differences is 256)
DESCRIPTION="issue 76 --- swarm aborts when --difference is 256"
"${SWARM}" -d 256 < "${ALL_IDENTICAL}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                       Sanitize input options (issue 77)                     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/77
##
## not specific enough, and covered by the tests in test_options.sh


#*****************************************************************************#
#                                                                             #
#         In rare cases Swarm does not terminate properly (issue 78)          #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/78
##  
## not reproducible yet


#*****************************************************************************#
#                                                                             #
#             Segmentation fault on empty sequences (issue 79)                #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/79
##
## issue 79 --- swarm deals with empty sequences
DESCRIPTION="issue 79 --- swarm deals with empty sequences"
printf ">s_1\n\n" | swarm &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


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
rm "${CLUSTERS_A}" "${CLUSTERS_B}"


#*****************************************************************************#
#                                                                             #
#                           Pacbio reads (issue 81)                           #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/81
##  
## general question


#*****************************************************************************#
#                                                                             #
#             Change output sequences to upper case (issue 82)                #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/82
##
## issue 82 --- output uppercase nucleotidic sequences
OUTPUT=$(mktemp)
DESCRIPTION="issue 82 --- output uppercase nucleotidic sequences (-w output)"
printf ">s_1\nt\n" | swarm -w "${OUTPUT}" &> /dev/null
awk 'NR == 2 {exit /^T$/ ? 0 : 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#Avoid producing microvariants if there's no amplicon of that length(issue 83)#
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/83
##  
## dead end


#*****************************************************************************#
#                                                                             #
#                 Compilation with GCC 6 fails (issue 84)                     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/84
##  
## fixed, not testable


#*****************************************************************************#
#                                                                             #
#               Function fatal() declared twice (issue 85)                    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/85
##  
## general question


#*****************************************************************************#
#                                                                             #
#               Add support for unseekable pipes (issue 86)                   #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/86
##  
##
## Swarm supports unseekable pipes
DESCRIPTION="issue 86 --- swarm supports unseekable pipes"
"${SWARM}" <(printf ">s_1\nT\n") &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                         speed of swarm (issue 87)                           #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/87
##
## general question


#*****************************************************************************#
#                                                                             #
#             average pairwise distances of each OTU (issue 88)               #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/88
##
## won't be implemented


#*****************************************************************************#
#                                                                             #
#               Develop a swarm-plugin for Qiime 2 (issue 89)                 #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/89
##  
## external feature


#*****************************************************************************#
#                                                                             #
#              Abundance annotation not recognised (issue 90)                 #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/90
##
## better error message to help to fix the problem
DESCRIPTION="issue 90 --- better error message to help to fix the problem"
CURRENT_MESSAGE=$(printf ">s\nT\n" | \
                         "${SWARM}" 2>&1 | sed -n '/^Error/,/sequences.$/ p')
## read is a Bash built-in so it doesn't require calling an external
## command such as cat. Putting quotes around the sentinal (EOF)
## prevents the text from undergoing parameter expansion. The -d ''
## causes it to read multiple lines (ignore newlines).
read -d '' EXPECTED_MESSAGE <<"EOF"
Error: Abundance annotations not found for 1 sequences, starting on line 1.
>s
Fasta headers must end with abundance annotations (_INT or ;size=INT).
The -z option must be used if the abundance annotation is in the latter format.
Abundance annotations can be produced by dereplicating the sequences.
The header is defined as the string comprised between the \">\" symbol
and the first space or the end of the line, whichever comes first.
EOF

[[ "${CURRENT_MESSAGE}" ==  "${EXPECTED_MESSAGE}" ]]  && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#        Remove abundance from identifiers in output file (issue 91)          #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/91
##
## won't be implemented


#*****************************************************************************#
#                                                                             #
#      Put the cluster seed identifier in the --seeds output (issue 92)       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/92
##
## problem with original poster's data.


#*****************************************************************************#
#                                                                             #
#        Why is U replaced by T when outputting the seeds (issue 93)          #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/93
##
## issue 93 --- uracil (U) is replaced with thymine (T) in output files
OUTPUT=$(mktemp)
DESCRIPTION="issue 93 --- uracil (U) is replaced with thymine (T) in -w output"
printf ">s_1\nU\n" | swarm -w "${OUTPUT}" &> /dev/null
awk 'NR == 2 {exit /^[Tt]$/ ? 0 : 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#   Alignment and identity percentage in UCLUST file may be wrong (issue 94)  #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/94
##  
## not testable, fixed


#*****************************************************************************#
#                                                                             #
#Alignments use a slightly too large gap extension penalty when d>1 (issue 95)#
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/95
## 
## issue 95 --- Alignments use a slightly too large gap extension penalty when d>1
# (example provided by Robert Müller)
# Consider the sequences CTATTGTTGTC and TCTATGTGTCT and swarm's default scoring
# function, the correct optimal alignment is (I4M2D5MI in CIGAR format):
#
#                     -ctattgttgtc-
#                     tctat--gtgtct
#
# with 5 differences and an alignment length of 13.
OUTPUT=$(mktemp)
DESCRIPTION="issue 95 --- default gap extension penalty is too large"
printf ">s1_1\nCTATTGTTGTC\n>s2_1\nTCTATGTGTCT\n" | \
    "${SWARM}" -d 5 -u "${OUTPUT}" &> /dev/null
awk '/^H/ {exit $8 == "I4M2D5MI" ? 0 : 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#                  Errors in SIMD alignment code (issue 96)                   #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/96
##
## issue 96 --- errors in SIMD alignment code
# (example provided by Robert Müller)
# Consider the sequences GAT and TT and swarm's default scoring
# function, the correct optimal alignment is (MIM in CIGAR format):
#
#                 t-t
#                 gat
#
# with 2 differences, a score of 28 and an alignment length of 3.
OUTPUT=$(mktemp)
DESCRIPTION="issue 96 --- errors in SIMD alignment code"
printf ">s1_1\nTT\n>s2_1\nGAT\n" | \
    "${SWARM}" -d 2 -u "${OUTPUT}" &> /dev/null
awk '/^H/ {exit $8 == "MIM" ? 0 : 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#                       Writing seeds > 100% (issue 98)                       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/98
##  
## issue 98 --- writing seeds never above 100%
OUTPUT=$(mktemp)
DESCRIPTION="issue 98 --- writing seeds never above 100 percent"
printf ">s_1\nA\n" | \
    "${SWARM}" -w /dev/null  2>&1 | \
    sed 's/\r/\n/' | \
    grep "Writing seeds" | \
    tr -d "%" | \
    awk '$3 > 100 {exit 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

#*****************************************************************************#
#                                                                             #
#                GCC warnings when using `-Wextra` (issue 99)                 #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/99
##  
## not testable, fixed    


#*****************************************************************************#
#                                                                             #
#Error "‘asprintf’ not declared in this scope" compiling w/ Cygwin (issue 100)#
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/100
##
## not testable


#*****************************************************************************#
#                                                                             #
#          How to handle duplicated parameters or options? (issue 101)        #
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


#*****************************************************************************#
#                                                                             #
#                   bug in abundance value parsing? (issue 102)               #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/102
##
## issue 102 --- bug in abundance value parsing?
## swarm accepts abundance values equal to 2^32
DESCRIPTION="issue 102 --- abundance values can be equal or greater than 2^32"
printf ">s1_%d\nA\n" $(( 1 << 32 )) | \
    "${SWARM}" &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#     not all memory is freed when swarm exits with an error (issue 103)      #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/103
##
## not testable
##
## printf ">s1\nA\n" | valgrind --leak-check=full --show-leak-kinds=all swarm


#*****************************************************************************#
#                                                                             #
#           static analysis of swarm's C++ code (cppcheck) (issue 104)        #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/104
##
## not testable
##
## cppcheck --enable=all swarm/ 1> /dev/null


#*****************************************************************************#
#                                                                             #
#         Swarm doesn't exit when run without any inputs (issue 105)          #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/105
##
## swarm waits when it receives no input data (no file, no pipe, no
## redirection). That's normal. See issue 36.


#*****************************************************************************#
#                                                                             #
#            bug in -w output when using the -a option (issue 106)            #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/106
##
## bug in -w output when using the -a option, amplicon identifier is
## missing (see also issue 91)
OUTPUT=$(mktemp)
DESCRIPTION="issue 106 --- bug in -w output when using the -a option"
printf ">s1\nT\n" | "${SWARM}" -a 1 -w "${OUTPUT}" &> /dev/null
grep -q "s1_1" "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


#*****************************************************************************#
#                                                                             #
#                  Port Swarm to other platforms (issue 107)                  #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/107
##
## Perhaps we should port Swarm to Linux on POWER8 and Windows on
## x86_64 as we have done for vsearch?
##
## not testable


## Clean
rm "${ALL_IDENTICAL}"

exit 0

