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

## use the first swarm binary in $PATH by default, unless user wants
## to test another binary
SWARM=$(which swarm 2> /dev/null)
[[ "${1}" ]] && SWARM="${1}"

DESCRIPTION="check if swarm is executable"
[[ -x "${SWARM}" ]] && success "${DESCRIPTION}" || failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#     Swarm sorts subseeds by abundance before searching for sub-subseeds     #
#                                                                             #
#*****************************************************************************#

## issue reported outside GitHub
##
## Swarm sorts subseeds by abundance, and then by aphabetical order
## before searching for sub-subseeds

# input: subseeds already sorted by abundance and by alphabetical order
DESCRIPTION="non-github issue 1 --- no subseed sorting when input is already sorted"
printf ">s_3\nA\n>s1_2\nAT\n>s2_1\nTA\n>s3_1\nATA\n" | \
    "${SWARM}" 2> /dev/null | \
    grep -q "^s_3 s1_2 s2_1 s3_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# input: subseeds not sorted by abundance and not sorted by alphabetical order
DESCRIPTION="non-github issue 1 --- subseed sorting by abundance (input is shuffled)"
printf ">s_3\nA\n>s2_1\nAT\n>s1_2\nTA\n>s3_1\nATA\n" | \
    "${SWARM}" 2> /dev/null | \
    grep -q "^s_3 s1_2 s2_1 s3_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# input: subseeds not sorted by abundance and sorted by alphabetical order
DESCRIPTION="non-github issue 1 --- subseed sorting by abundance (input is alpha-sorted)"
printf ">s_3\nA\n>s1_1\nAT\n>s2_2\nTA\n>s3_1\nATA\n" | \
    "${SWARM}" 2> /dev/null | \
    grep -q "^s_3 s2_2 s1_1 s3_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# input: subseeds have the same abundance and are sorted by alphabetical order
DESCRIPTION="non-github issue 1 --- subseed sorting by header's alphabetical order (input is alpha-sorted)"
printf ">s_3\nA\n>s1_1\nAT\n>s2_1\nTA\n>s3_1\nATA\n" | \
    "${SWARM}" 2> /dev/null | \
    grep -q "^s_3 s1_1 s2_1 s3_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# input: subseeds have the same abundance and are not sorted by alphabetical order
DESCRIPTION="non-github issue 1 --- subseed sorting by header's alphabetical order (input is shuffled)"
printf ">s_3\nA\n>s2_1\nAT\n>s1_1\nTA\n>s3_1\nATA\n" | \
    "${SWARM}" 2> /dev/null | \
    grep -q "^s_3 s1_1 s2_1 s3_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# Conflict between the shell's /dev/stdout and C++'s stdout. Swarm now
# avoids opening /dev/stdout unless asked by the user:
# https://github.com/torognes/swarm/commit/5a9ae812cca0333876250929ba0ece850fa64c0c
DESCRIPTION="non-github issue 2 --- file capturing /dev/stdout is not empty"
TMP=$(mktemp)
(echo "1" ; "${SWARM}" -v 2> /dev/null) > "${TMP}"
[[ -s "${TMP}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${TMP}"

DESCRIPTION="non-github issue 2 --- file capturing /dev/stdout contains the expected string"
TMP=$(mktemp)
(echo "1" ; "${SWARM}" -v 2> /dev/null) > "${TMP}"
grep -q "^1" "${TMP}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${TMP}"

DESCRIPTION="non-github issue 2 --- file capturing /dev/stdout contains no null character"
TMP=$(mktemp)
(echo "1" ; "${SWARM}" -v 2> /dev/null ; echo "2") > "${TMP}"
# grep -E to work on OSX and -P on GNU/Linux
(grep -Eqa '\x00' "${TMP}" || grep -Pqa '\x00' "${TMP}") && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
rm "${TMP}"

DESCRIPTION="non-github issue 2 --- file capturing /dev/stderr starts with the expected string"
TMP=$(mktemp)
(echo "1" 1>&2 ; "${SWARM}" -v ; echo "2" 1>&2) 2> "${TMP}"
grep -q "^1" "${TMP}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${TMP}"


#*****************************************************************************#
#                                                                             #
#       Swarm radius values should be available via an option (issue 1)       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/1
##
## Swarm radius values are available in the statistics file (-s), 7th column.
DESCRIPTION="issue 1 --- theoretical radii of OTUs is available with -s"
printf ">s1_3\nA\n>s2_1\nT\n" | \
    "${SWARM}" -d 1 -o /dev/null -s - 2> /dev/null | \
    awk '{exit $7 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
printf ">s\01a_1\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
printf ">s1_1\nA\n>s2_1\nA\n" | \
    "${SWARM}" 2>&1 | \
    grep -q "^WARNING: 1 duplicated sequences detected." && \
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
printf ">s1_1\nT\n>s2_10\nA\n" | \
    "${SWARM}" -o /dev/null -w - 2> /dev/null | \
    grep -q "^>s2_11$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
DESCRIPTION="issue 8 --- produce a non-empty uclust file with -u"
printf ">s1_2\nA\n>s2_1\nT\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#             Output detailed statistics for each swarm (issue 9)             #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/9
##
## Output detailed statistics for each swarm (option -s)
DESCRIPTION="issue 9 --- produce a statistics file with -s"
printf ">s_2\nA\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                     Check for unique headers (issue 10)                     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/10
##
## Check for unique headers and report error if duplicates are found
DESCRIPTION="issue 10 --- check for unique headers"
printf ">s_2\nA\n>s_1\nT\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


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
printf ">s1_2\nA\n>s2_1\nT\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk '$1 !~ "H" && $4 != "*" {exit 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
printf ">a_3\nAAAA\n>b_2\nAACC\n>c_1\nCCCC\n" | \
    "${SWARM}" -d 2 -o /dev/null -s - 2> /dev/null | \
    awk '{exit $7 <= 4 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="issue 14 --- radius is in fact the sum of differences"
printf ">a_3\nAAA\n>b_2\nACC\n>c_1\nCCC\n" | \
    "${SWARM}" -d 2 -o /dev/null -s - 2> /dev/null | \
    awk '{exit $7 == 3 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
printf ">s_1\nB\n" | \
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
for OPTION in "-z" "--usearch-abundance" ; do
    DESCRIPTION="issue 22 --- support for usearch abundance ending with semicolon (${OPTION})"
    printf ">s;size=1;\nA\n" | \
	    "${SWARM}" "${OPTION}" > /dev/null 2>&1 && \
	    success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="issue 22 --- support for usearch abundance ending without semicolon (${OPTION})"
    printf ">s;size=1\nA\n" | \
	    "${SWARM}" "${OPTION}" > /dev/null 2>&1 && \
	    success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done
unset OPTION


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
    printf ">s_1\nA\n" | \
        "${SWARM}" "${OPTION}" > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done
unset OPTION


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
printf ">s_1\nA\n" | \
    "${SWARM}" -d 2 -r -o - 2> /dev/null | \
    grep -q "swarm_2" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                        Progress Indication (issue 27)                       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/27
##
## swarm indicates its progress during the clustering process
DESCRIPTION="issue 27 ---- report progress during the clustering process"
printf ">s_1\nA\n" | \
    "${SWARM}" 2>&1 | \
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
DESCRIPTION="issue 30 --- number of differences is correct in -i while -d 2 (2 expected)"
printf ">a_1\nAAAA\n>b_1\nAACC\n" | \
    "${SWARM}" -d 2 -o /dev/null -i - 2> /dev/null | \
    awk '{exit $3 == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
cmp -s \
    <(printf ">a_5\nAA\n>d_1\nGC\n>b_2\nAC\n>c_1\nGA\n" | \
          "${SWARM}" -o /dev/null -i - 2> /dev/null) \
    <(printf "a\tb\t1\t1\t1\na\tc\t1\t1\t1\nb\td\t1\t1\t2\n") && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
printf ">s_1\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#     Sequence headers with multiple underscores cause problems(issue 37)     #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/37
##
## issue 37 --- fasta headers can contain more than one underscore symbol
DESCRIPTION="issue 37 --- fasta headers can contain more than one underscore symbol"
printf ">s_2_2_3\nA\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk '{exit $3 == "s_2_2" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
## issue 40 --- swarm performs OTU breaking by default (AA-AC CC)
DESCRIPTION="issue 40 --- swarm performs OTU breaking by default"
printf ">s1_3\nAA\n>s2_3\nCC\n>s3_1\nAC\n" | \
	"${SWARM}" 2> /dev/null | \
    wc -l | \
    grep -q "^2$" && \
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
DESCRIPTION="issue 41 --- -i number of the OTU is correct #1"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -i - -o /dev/null 2> /dev/null | \
    awk -F "\t" '{exit $4 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## issue 41 --- -i number of the OTU is correct #2
DESCRIPTION="issue 41 --- -i number of the OTU is correct #2"
printf ">s1_1\nAA\n>s2_1\nAC\n>s3_1\nGG\n>s4_1\nGT\n" | \
    "${SWARM}" -i - -o /dev/null 2> /dev/null | \
    awk 'NR == 2 {exit $4 == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#        Add the OTU number to the output of the -b option (issue 42)         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/42
##
## issue 42 --- swarm accepts --fastidious options (-d 1 is implicit)
DESCRIPTION="issue 42 --- swarm accepts --fastidious options"
printf ">s_1\nA\n" | \
    "${SWARM}" -f > /dev/null 2>&1 && \
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
printf ">s_1\nA\n" | \
    "${SWARM}" -d 0 > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## issue 48 --- -d 0 delete duplicate sequences
DESCRIPTION="issue 48 --- -d 0 delete duplicate sequences"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -d 0 2> /dev/null | \
    awk 'END {exit NR == 2 ? 0 : 1}' && \
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
#     Abundance annotation style should also be in the output fasta file      #
#     (issue 51)                                                              #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/51
##
## issue 51 --- -w gives abundance notation style matching the input #1
DESCRIPTION="issue 51 --- -w outputs abundance notation style matching the input #1"
printf ">s_1\nA\n" | \
    "${SWARM}" -w - -o /dev/null 2> /dev/null | \
    grep -q "^>s_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## issue 51 --- -w gives abundance notation style matching the input #2
DESCRIPTION="issue 51 --- -w outputs abundance notation style matching the input #2"
printf ">s;size=1\nA\n" | \
    "${SWARM}" -z -w - -o /dev/null 2> /dev/null | \
    grep -q "^>s;size=1;$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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

microvariants() {
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

## produce a fasta set with a seed and all its unique L1 microvariants
## (output should contain only one cluster)
DESCRIPTION="issue 53 --- swarm correctly computes all microvariants"
microvariants "ACGT" | \
    sort -du | \
    awk '{print ">s"NR"_1\n"$1}' | \
    "${SWARM}" -o - 2> /dev/null | \
    awk 'END {exit NR == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## produce a fasta set with a seed, all its unique L2 microvariants
## but no L1 microvariants (output should contain only one cluster)
DESCRIPTION="issue 53 --- fastidious links L2 microvariants and the seed"
SEQUENCE="ACGT"
MICROVARIANTS_L1=$(microvariants ${SEQUENCE} | sort -du | grep -v "^${SEQUENCE}$")
MICROVARIANTS_L2=$(while read MICROVARIANT ; do
                       microvariants ${MICROVARIANT}
                   done <<< "${MICROVARIANTS_L1}" | \
                       sort -du | grep -v "^${SEQUENCE}$")
(printf ">seed_1\n%s\n" ${SEQUENCE}
 comm -23 <(echo "${MICROVARIANTS_L2}") <(echo "${MICROVARIANTS_L1}") | \
     awk '{print ">s"NR"_1\n"$1}') | \
    "${SWARM}" -d 1 -f -o - 2> /dev/null | \
    awk 'END {exit NR == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset SEQUENCE MICROVARIANTS_L1 MICROVARIANTS_L2

## perform an independent test for each L2 microvariant
DESCRIPTION="issue 53 --- fastidious links each L2 microvariant and the seed"
SEQUENCE="ACGT"
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
            "${SWARM}" -d 1 -f -o - 2> /dev/null | \
            awk 'END {exit NR == 1 ? 0 : 1}' || \
            failure "${DESCRIPTION}"
    done && success "${DESCRIPTION}"
unset SEQUENCE MICROVARIANTS_L1 MICROVARIANTS_L2


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
DESCRIPTION="issue 55 --- grafted amplicon receives a number of difference of 2"
printf ">a_3\nAAAA\n>b_1\nAATT\n" | \
    "${SWARM}" -f -o /dev/null -i - 2> /dev/null | \
    awk '{exit $3 == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Grafted amplicons receive the OTU number of the main OTU (in this
## toy example, the 4th column should be always equal to 1)
##
## a	b	1	1	1
## b	c	2	1	2
## c	d	1	1	1
DESCRIPTION="issue 55 --- grafted amplicons receive the OTU number of the main OTU"
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_1\nATTT\n>d_1\nTTTT\n" | \
    "${SWARM}" -f -o /dev/null -i - 2> /dev/null | \
    awk '$4 != 1 {exit 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of differences between the grafted amplicon and the grafting point is 2
##
## the structure file should be:
## a   b   1   1   1
## b   c   2   1   2
## c   d   1   1   1
DESCRIPTION="issue 55 --- 2 differences between the grafted amplicon and the grafting point"
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_1\nATTT\n>d_1\nTTTT\n" | \
    "${SWARM}" -f -o /dev/null -i - 2> /dev/null | \
    awk '$2 == "c" && $3 == 2 {s++} END {exit s ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## The fifth column of the structure file should be equal to number of
## steps from the seed to the amplicon (1 or 2 steps in the example).
##
## the structure file should be:
## a   b   1   1   1
## b   c   2   1   2
## c   d   1   1   1
DESCRIPTION="issue 55 --- 5th column is the number of steps from the seed to the amplicon"
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_1\nATTT\n>d_1\nTTTT\n" | \
    "${SWARM}" -f -i - -o /dev/null 2> /dev/null | \
    awk '$5 < 1 || $5 > 2 {exit 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#               Clustering with d = 1 and replicates (issue 56)               #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/56
##
## issue 56 --- -i number of differences is correct with -d 1
##
## with one-diff sequences we expect one difference in column 3
DESCRIPTION="issue 56 --- -i number of differences is correct with -d 1"
printf ">s1_1\nA\n>s2_1\nT\n" | \
    "${SWARM}" -d 1 -o /dev/null -i - 2> /dev/null | \
    awk '{exit $3 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## issue 56 --- -i number of differences is correct with -d 2
##
## with identical sequences we expect zero difference in column 3
DESCRIPTION="issue 56 --- -i number of differences is correct with -d 2"
printf ">s1_1\nA\n>s2_1\nT\n" | \
    "${SWARM}" -d 2 -o /dev/null -i - 2> /dev/null | \
    awk '{exit $3 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#     Sequence identifiers format, abundance annotation not found error       #
#     (issue 57)                                                              #
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
printf ">s\nA\n" | \
    "${SWARM}" -a 2 > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## issue 59 --- number of missing abundance  notation is correct in error message #1
DESCRIPTION="issue 59 --- number of missing abundance  notation is correct in error message #1"
printf ">s1_1\nA\n>s2\nT\n" | \
    "${SWARM}" 2>&1 | \
    grep -q "^Error.*for 1 sequences" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## issue 59 --- number of missing abundance  notation is correct in error message #2
DESCRIPTION="issue 59 --- number of missing abundance  notation is correct in error message #2"
printf ">s1\nA\n>s2_1\nC\n>s3\nG\n" | \
    "${SWARM}" 2>&1 | \
    grep -q "^Error.*for 2 sequences" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## issue 59 --- first line of abundance notation missing is correct in error message
DESCRIPTION="issue 59 --- first line of abundance notation missing is correct in error message"
printf ">s1_1\nA\n>s2\nT\n" | \
    "${SWARM}" 2>&1 | \
    grep -q "^Error.*starting on line 3." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## issue 59 --- swarm -a fails without argument
DESCRIPTION="issue 59 --- swarm -a fails without argument"
printf ">s\nA\n" | \
    "${SWARM}" -a 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## issue 59 --- swarm -a does not overwrite abundance in case of multiple _ with numbers
DESCRIPTION="issue 59 --- -a does not overwrite abundance in case of multiple _ with numbers"
printf ">s1_1_2\nA\n>s2_1_2\nA\n" | \
    "${SWARM}" -a 1 2> /dev/null | \
    grep -q "^s1_1_2 s2_1_2$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
DESCRIPTION="issue 65 --- swarm complains if input sequences are duplicated (d=2)"
printf ">s1;size=1\nAA\n>s2;size=2\nAA\n" | \
    "${SWARM}" -z -d 2 2>&1 | \
    grep -q "^WARNING: 1 duplicated sequences detected." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="issue 65 --- swarm complains if input sequences are duplicated (d=1)"
printf ">s1;size=1\nAA\n>s2;size=2\nAA\n" | \
    "${SWARM}" -z -d 1 2>&1 | \
    grep -q "^WARNING: 1 duplicated sequences detected." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="issue 65 --- swarm does not complain if input sequences are duplicated (d=0)"
printf ">s1;size=1\nAA\n>s2;size=2\nAA\n" | \
    "${SWARM}" -z -d 0 2>&1 | \
    grep -q "^WARNING: 1 duplicated sequences detected." && \
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
for i in {1..3} ; do
    DESCRIPTION="issue 67 --- name of the representative is tshe name of the seed (-d ${i})"
    printf ">s1_3\nA\n>s2_1\nT\n" | \
        "${SWARM}" -d ${i} -o /dev/null -w - 2> /dev/null | \
        grep -q "^>s1_4$" && \
	    success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## The sequence of the representatives is the sequence of the seed
for i in {1..3} ; do
    DESCRIPTION="issue 67 --- sequence of the representative is the sequence of the seed (-d ${i})"
    printf ">s1_3\nA\n>s2_1\nT\n" | \
	    "${SWARM}" -d ${i} -o /dev/null -w - 2> /dev/null | \
        grep -qi "^A$" && \
	    success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done


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
#  0 : NULL  : 00
# 10 : \n    : 0A
# 13 : \r    : 0D
# 32 : SPACE : 20
for i in 00 0A 0D 20 ; do
    DESCRIPTION="issue 72 --- ascii character x${i} is not allowed in fasta headers"
    printf ">s\x${i}_1\nA\n" | \
        "${SWARM}"  > /dev/null 2>&1 && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
done

## some ascii characters are accepted *if* present at the end of the header
#  0 : NULL  : 00
# 10 : \n    : 0A
# 13 : \r    : 0D
# 32 : SPACE : 20
for i in 00 0A 0D 20 ; do
    DESCRIPTION="issue 72 --- ascii character x${i} is accepted if present at the end of the header"
    printf ">s_1\x${i}\nA\n" | \
        "${SWARM}"  > /dev/null 2>&1 && \
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
unset OPTION


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
DESCRIPTION="issue 74 --- run normally with short undereplicated sequences"
for ((d=1 ; d<=5 ; d++)) ; do
    for ((t=1 ; t<=30 ; t++)) ; do
        printf ">s_1\nA\n" | \
            "${SWARM}" -d ${d} -t ${t} > /dev/null 2> /dev/null || \
            failure "clustering fails for d=${d} and t=${t}"
    done
done && success "${DESCRIPTION}"
unset d t


#*****************************************************************************#
#                                                                             #
#        Pairwise alignement settings not printed with -d 1 (issue 75)        #
#                                                                             #
#*****************************************************************************#

## Pairwise alignment settings are not printed if d = 1 (issue #75)
DESCRIPTION="issue 75 --- Pairwise alignment settings are not printed if d = 1"
printf ">s_1\nA\n" | \
    "${SWARM}" -d 1 2>&1 | \
    grep -q "^Scores:\|Gap penalties:\|Converted costs:" && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Pairwise alignment settings are printed if d > 1 (issue #75)
DESCRIPTION="issue 75 --- Pairwise alignment settings are printed if d > 1"
printf ">s_1\nA\n" | \
    "${SWARM}" -d 2 2>&1 | \
    grep -q "^Scores:\|Gap penalties:\|Converted costs:" && \
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
printf ">s_1\nA\n" | \
    "${SWARM}" -d 256 > /dev/null 2>&1 && \
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
printf ">s_1\n\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
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
cmp -s \
    <(printf ">a_2\nAA\n>b_2\nTT\n>c_1\nAT\n" | \
          "${SWARM}" -o - 2> /dev/null) \
    <(printf ">b_2\nTT\n>a_2\nAA\n>c_1\nAT\n" | \
          "${SWARM}" -o - 2> /dev/null) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
DESCRIPTION="issue 82 --- output uppercase nucleotidic sequences (-w output)"
printf ">s_1\nt\n" | \
    "${SWARM}" -o /dev/null -w - 2> /dev/null | \
    awk 'NR == 2 {exit /^T$/ ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
printf ">s_1\nT\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
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
                      "${SWARM}" 2>&1 | sed -n '/^Error/,/first.$/ p')
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
unset CURRENT_MESSAGE EXPECTED_MESSAGE


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
DESCRIPTION="issue 93 --- uracil (U) is replaced with thymine (T) in -w output"
printf ">s_1\nU\n" | \
    "${SWARM}" -o /dev/null -w - 2> /dev/null | \
    awk 'NR == 2 {exit /^[Tt]$/ ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
DESCRIPTION="issue 95 --- default gap extension penalty is too large"
printf ">s1_1\nCTATTGTTGTC\n>s2_1\nTCTATGTGTCT\n" | \
    "${SWARM}" -d 5 -o /dev/null -u - 2> /dev/null | \
    awk '/^H/ {exit $8 == "I4M2D5MI" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
DESCRIPTION="issue 96 --- errors in SIMD alignment code"
printf ">s1_1\nTT\n>s2_1\nGAT\n" | \
    "${SWARM}" -d 2 -o /dev/null -u - 2> /dev/null | \
    awk '/^H/ {exit $8 == "MIM" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                       Writing seeds > 100% (issue 98)                       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/98
##  
## issue 98 --- writing seeds never above 100%
DESCRIPTION="issue 98 --- writing seeds never above 100 percent"
printf ">s_1\nA\n" | \
    "${SWARM}" -o /dev/null -w /dev/null 2>&1 | \
    sed 's/\r/\n/' | \
    grep "Writing seeds" | \
    tr -d "%" | \
    awk '$3 > 100 {exit 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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
printf ">s_1\nA\n" | \
    "${SWARM}" -d 2 -d 2 > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## issue 101 --- fail if an option is passed twice #2
DESCRIPTION="issue 101 --- fail if an option is passed twice #2"
printf ">s_1\nA\n" | \
    "${SWARM}" -v -v > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## issue 101 --- fail if an unknown option is passed
DESCRIPTION="issue 101 --- fail if an unknown option is passed"
printf ">s_1\nA\n" | \
    "${SWARM}" --smurf > /dev/null 2>&1 && \
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
printf ">s1_4294967296\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#     not all memory is freed when swarm exits with an error (issue 103)      #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/103
##
## testable, but won't be fixed:
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
## redirection). That's normal. See also issue 36. Commented as it
## does not work on MacOS.
# DESCRIPTION="issue 105 --- when no filename is given, swarm says it is waiting for data on stdin"
# (cmdpid=${BASHPID}
#  (sleep 1 ; kill -PIPE ${cmdpid} > /dev/null 2>&1) & "${SWARM}" 2>&1) | \
#     grep -q "^Waiting" && \
#     success "${DESCRIPTION}" || \
#         failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#            bug in -w output when using the -a option (issue 106)            #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/106
##
## bug in -w output when using the -a option, amplicon identifier is
## missing (see also issue 91)
DESCRIPTION="issue 106 --- bug in -w output when using the -a option"
printf ">s\nT\n" | \
    "${SWARM}" -a 1 -o /dev/null -w - 2> /dev/null | \
    grep -q "s_1" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


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


#*****************************************************************************#
#                                                                             #
#                 Wrong cluster id in the uc output (issue 108)               #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/108
##
## Swarm shows the wrong cluster number on the H lines of UC files
## when using fastidious mode. The number shown is the original
## cluster number, before the fastidious grafting (it should be zero).
##
## C	0	4	*	*	*	*	*	a_1	*
## S	0	4	*	*	*	*	*	a_1	*
## H	1	4	75.0	+	0	0	4M	c_1	a_1
## H	1	4	50.0	+	0	0	4M	d_1	a_1
## H	1	4	25.0	+	0	0	4M	b_2	a_1

DESCRIPTION="issue 108 --- (fastidious) wrong cluster number in the UC output"
printf ">a_1\nTGGA\n>b_2\nTTTT\n>c_1\nTTGA\n>d_1\nCTGA\n" | \
    "${SWARM}" -f -o /dev/null -u - 2> /dev/null | \
    awk '$2 != 0 {exit 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#       segmentation fault error when using swarm with -d 1 (issue 109)       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/109
##
## Swarm stores the sequences matching a seed in an array. This array
## is allocated once and then kept until the program is finished. But
## it can grow if necessary.
##
## Usually the size of this array is initialized to 7l+4 where l is
## the length of the longest amplicon in the dataset, since this is
## the maximum number of subseeds that can occur with a single change
## (subst, del, ins). Normally this is enough, unless the dataset is
## not dereplicated. In that case, there could be many more matches
## than expected.
##
## There is a check in swarm to see if the array is too small to hold
## all the matches. If the array is too small, it is doubled one
## time. That's the cause of the segmentation fault.
##
## The solution is to double the size of the array as many times as
## necessary to hold all the matching sequences.
##
## In the toy example below, all sequences are identical and of length
## 1 (equivalent of a undereplicated dataset). Previous versions of
## swarm would create an array of that could hold 7l+4 matching
## sequences. That array could be doubled once, and having one more
## match would trigger a segmentation fault. That means we need 24
## input sequences of length 1 to trigger the bug: 1 seed + 2 * (7 +
## 4) + 1 excess match = 1 + 22 + 1 = 24

## This test should pass on swarm 2.2.0
DESCRIPTION="issue 109 --- segmentation fault error with undereplicated dataset #1"
for ((i=1 ; i<=23 ; i++)) ; do
    printf ">s%d_1\nA\n" ${i}
done | "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## This test should fail on swarm 2.2.0 and pass on more recent versions
DESCRIPTION="issue 109 --- segmentation fault error with undereplicated dataset #2"
for ((i=1 ; i<=24 ; i++)) ; do
    printf ">s%d_1\nA\n" ${i}
done | "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#           Swarm does not start clustering in rare cases (issue 110)         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/110

## In rare conditions, a deadlock can appear between two threads. The
## solution was to add a waiting step to guarantee that all worker
## threads are done before going to the next step.


#*****************************************************************************#
#                                                                             #
#             Can you update bioconda with latest? (issue 111)                #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/111

## Bioconda is an external project. Colin Brislawn took care of it.


#*****************************************************************************#
#                                                                             #
#           Compilation warnings with the new GCC 8.0 (issue 112)             #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/112

## Solved by replacing strcopy with memcopy


#*****************************************************************************#
#                                                                             #
#             Compatibility with old GCC versions? (issue 113)                #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/113

## Solved by replacing -Wpedantic with -pedantic (GCC < 4.8)


#*****************************************************************************#
#                                                                             #
#                      improve groff code (issue 114)                         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/114

## not testable


#*****************************************************************************#
#                                                                             #
#      Potential vulnerabilities identified by Flawfinder (issue 115)         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/115

## not testable


#*****************************************************************************#
#                                                                             #
#                Problem with fasta header? (issue 116)                       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/116

## The problem was in vsearch (https://github.com/torognes/vsearch/issues/338)


#*****************************************************************************#
#                                                                             #
#                       swarm output file (issue 118)                         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/118

## not testable


#*****************************************************************************#
#                                                                             #
#                      ikos static analyzer (issue 119)                       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/119

## not testable


#*****************************************************************************#
#                                                                             #
#      Benign buffer overflow when parsing fasta sequences (issue 120)        #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/120

## not testable


#*****************************************************************************#
#                                                                             #
#           segmentation faults with the zobrist branch (issue 121)           #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/121

## no problem when the input contains 3 sequences or more
DESCRIPTION="issue 121 --- segmentation fault when there are only 1 or 2 input sequences"
printf ">s1_1\nA\n>s2_1\nT\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                  small tasks around swarm 3.0 (issue 122)                   #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/122

## not testable


#*****************************************************************************#
#                                                                             #
#          memory-allocation error in swarm 3 fastidious (issue 123)          #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/123

## memory was not allocated correctly for sequences shorter than 6 nt
if which valgrind > /dev/null ; then
    DESCRIPTION="issue 123 --- no memory allocation error for short sequences"
    valgrind \
        "${SWARM}" -f -o /dev/null <(printf ">s1_10\nAA\n>s2_1\nCC\n") 2>&1 | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
fi


#*****************************************************************************#
#                                                                             #
#          small memory leak when using the --log option (issue 124)          #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/124

## the log file was not closed properly
if which valgrind > /dev/null ; then
    DESCRIPTION="issue 124 --- no memory leak when --log is not use"
    valgrind \
        "${SWARM}" -o /dev/null <(printf ">s1_10\nAA\n>s2_1\nCC\n") 2>&1 | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
    DESCRIPTION="issue 124 --- no memory leak when using the --log option"
    valgrind \
        "${SWARM}" -o /dev/null -l /dev/null \
        <(printf ">s1_10\nAA\n>s2_1\nCC\n") 2>&1 | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
fi


#*****************************************************************************#
#                                                                             #
#       incomplete creation of microvariants in swarm 3.0 (issue 125)         #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/125

## swarm 3.0 stops on duplicated sequences, where swarm 2.0 used to
## dereplicate silently
DESCRIPTION="issue 125 --- swarm only accepts dereplicated sequences (-d 1)"
printf ">s1_2\nA\n>s2_1\nA\n" | \
    "${SWARM}" -d 1 > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

DESCRIPTION="issue 125 --- swarm only accepts dereplicated sequences (-d 2)"
printf ">s1_2\nA\n>s2_1\nA\n" | \
    "${SWARM}" -d 2 > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#       minor unfreed memory allocation (all swarm versions) (issue 126)      #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/126

## when using the options -v, -h or -i, parsing command line arguments
## triggers one memory allocation (heap). That memory allocation is
## not freed by swarm before exiting (it is freed by the operating
## system though).
if which valgrind > /dev/null ; then
    DESCRIPTION="issue 126 --- all memory allocations are freed"
    valgrind \
        "${SWARM}" \
        -o /dev/null \
        -l /dev/null \
        -i /dev/null <(printf ">s_1\nA\n") 2>&1 | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
fi


#*****************************************************************************#
#                                                                             #
#   Fastidious Bloom filter requires more memory than indicated in the help   #
#   (issue 127)                                                               #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/127

## Bloom filter needs at least 8 MB, even for a minimal example
## (manpage used to indicate 3 MB)
DESCRIPTION="issue 127 --- (fastidious) Bloom filter needs at least 8 MB (can fail)"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -c 8 > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Ceiling should fail when 0 <= c < 8
for ((c=0 ; c<8; c++)) ; do
    DESCRIPTION="issue 127 --- aborts when --ceiling is ${c}"
    printf ">s1_3\nAA\n>s2_1\nCC\n" | \
        "${SWARM}" -f -c ${c} > /dev/null 2>&1 && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
done
unset c


#*****************************************************************************#
#                                                                             #
#          Error occur in amplicon_contingency_table.py (issue 128)           #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/128

## not testable


#*****************************************************************************#
#                                                                             #
#                Makefile: add an "install" recipe (issue 129)                #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/129

## not testable


#*****************************************************************************#
#                                                                             #
#                     Measure code coverage (issue 130)                       #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/130

## not a single issue, many tests necessary


#*****************************************************************************#
#                                                                             #
#                abundance values generator? (issue 131)                      #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/131

## swarm can read vsearch's abundance annotations (with option -z)
if which vsearch > /dev/null ; then
    DESCRIPTION="issue 131 --- swarm can read vsearch's abundance annotations"
    printf ">s1;size=3\nA\n>s2;size=2\nA\n>s3;size=1\nT\n" | \
        vsearch \
            --derep_fulllength - \
            --minseqlength 1 \
            --sizein \
            --sizeout \
            --quiet \
            --output - | \
        "${SWARM}" -z -l /dev/null | \
        grep -q "^s1;size=5 s3;size=1$"  && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
fi


#*****************************************************************************#
#                                                                             #
#                       pooled samples? (issue 132)                           #
#                                                                             #
#*****************************************************************************#

## https://github.com/torognes/swarm/issues/132

## not testable


exit 0

