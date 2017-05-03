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
## Description is not precise enough to create a test. There are tests
## covering the -s output in the file test_options.sh


#*****************************************************************************#
#                                                                             #
#        More informative error message for illegal characters (issue 24)     #
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
## cannot be tested from the command line.

#*****************************************************************************#
#                                                                             #
#   Add the number of differences in the output of the d option (issue 30)    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/30
##
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
#                                Dereplication                                #
#                                                                             #
#*****************************************************************************#

## issue 65 --- swarm complains if input sequences are not dereplicated
DESCRIPTION="issue 65 --- swarm complains if input sequences are not dereplicated"
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
## Deprecated parameter -b


#*****************************************************************************#
#                                                                             #
#             Segmentation fault (or SIGABRT) with -a (issue 35)              #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/35
##
## Deprecated paramater -a


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
#Sequence headers with multiple underscore characters cause problems(issue 37)#
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
rm -f "${STATS}"


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
## issue 51 --- -w gives abudance notation style matches input #1
OUTPUT=$(mktemp)
DESCRIPTION="issue 51 --- -w gives abudance notation style matches input #1"
EXPECTED=$(printf ">a_1\naaaa\n")
printf ">a_1\nAAAA\n" | \
    "${SWARM}" -w "${OUTPUT}" &> /dev/null
[[ "$(< "${OUTPUT}")" == "${EXPECTED}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## issue 51 --- -w gives abudance notation style matches input #2
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
## not testable

#*****************************************************************************#
#                                                                             #
#                    IUPAC nucleotide ambiguity (issue 54)                    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/54
##
## nucleotide almbiguity (R,Y,S,W,K,M,M,D,B,H,V,N) won't be implemented

#*****************************************************************************#
#                                                                             #
#               Clustering with d = 1 and replicates (issue 56)               #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/56
##
## issue 56 --- -i number of differences is correct with -d 1
DESCRIPTION="issue 56 --- -i number of differences is correct with -d 1"
OUTPUT=$(mktemp)
printf ">s_1\nA\n>w_1\nA\n" | "${SWARM}" -d 1 -i "${OUTPUT}"  &> /dev/null
OBSERVED=$(awk '{print $3}' "${OUTPUT}") 
(( "${OBSERVED}" == 0 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## issue 56 --- -i number of differences is correct with -d 2
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
## TODO test -a accepted; test error message when missing abundance notation;
## output if _ in sequence name when using -a; fail if -a without arg


#*****************************************************************************#
#                                                                             #
#                 Ability to process fastq files (issue 60)                   #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/60
##  


#*****************************************************************************#
#                                                                             #
#                 dereplicating pooled specimens (issue 61)                   #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/61
##  


#*****************************************************************************#
#                                                                             #
#                Compilation warning with gcc 4.9 (issue 62)                  #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/62
##  


#*****************************************************************************#
#                                                                             #
#             Potential problem reported by cppcheck (issue 63)               #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/63
##  


#*****************************************************************************#
#                                                                             #
#         digits transposed in file name of 2.1.5 binary (issue 64)           #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/64
##  


#*****************************************************************************#
#                                                                             #
#                   Amplicon length truncation (issue 66)                     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/66
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
#                  compiling swarm on osx 1.8.5 (issue 69)                    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/69
##  


#*****************************************************************************#
#                                                                             #
#                  ;size=INT not being accepted (issue 70)                    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/70
##  


#*****************************************************************************#
#                                                                             #
#         Make use of base quality score - Fastq support (issue 71)           #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/71
##  


#*****************************************************************************#
#                                                                             #
#              Strip chr(13) from input fasta files (issue 72)                #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/72
##  


#*****************************************************************************#
#                                                                             #
#            Return status should be 0 after -h and -v (issue 73)             #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/73
##  


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
#         In rare cases Swarm does not terminate properly (issue 78)          #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/78
##  


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


#*****************************************************************************#
#                                                                             #
#               Function fatal() declared twice (issue 85)                    #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/85
##  


#*****************************************************************************#
#                                                                             #
#                         speed of swarm (issue 87)                           #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/87
##  


#*****************************************************************************#
#                                                                             #
#        Why is U replaced by T when outputting the seeds (issue 93)          #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/93
##  


#*****************************************************************************#
#                                                                             #
#   Alignment and identity percentage in UCLUST file may be wrong (issue 94)  #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/94
##  


#*****************************************************************************#
#                                                                             #
#Alignments use a slightly too large gap extension penalty when d>1 (issue 95)#
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/95
##  


#*****************************************************************************#
#                                                                             #
#                  Errors in SIMD alignment code (issue 96)                   #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/96
##  


#*****************************************************************************#
#                                                                             #
#                       Writing seeds > 100% (issue 98)                       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/98
##  


#*****************************************************************************#
#                                                                             #
#                GCC warnings when using `-Wextra` (issue 99)                 #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/99
##  
     

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
