#!/bin/bash -

## Print a header
SCRIPT_NAME="Test options"
LINE=$(printf "%076s\n" | tr " " "-")
printf "# %s %s\n" "${LINE:${#SCRIPT_NAME}}" "${SCRIPT_NAME}"

## Declare a color code for test results
RED="\033[1;31m"
GREEN="\033[1;32m"
NO_COLOR="\033[0m"

failure () {
    printf "${RED}FAIL${NO_COLOR}: ${1}\n"
    exit 1
}

success () {
    printf "${GREEN}PASS${NO_COLOR}: ${1}\n"
}

## use the first swarm binary in $PATH by default, unless user wants
## to test another binary
SWARM=$(which swarm 2> /dev/null)
[[ "${1}" ]] && SWARM="${1}"

DESCRIPTION="check if swarm is executable"
[[ -x "${SWARM}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                             Read from stdin (-)                             #
#                                                                             #
#*****************************************************************************#

## Accept to read from /dev/stdin
DESCRIPTION="swarm reads from /dev/stdin"
printf ">s_1\nA\n" | \
    "${SWARM}" /dev/stdin > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Accept "-" as a placeholder for stdin
DESCRIPTION="swarm reads from stdin when - is used"
printf ">s_1\nA\n" | \
    "${SWARM}" - > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                                  No option                                  #
#                                                                             #
#*****************************************************************************#

## No option, only standard input
DESCRIPTION="swarm runs normally when no option is specified (data on stdin)"
printf ">s_1\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## No option, only a fasta file
DESCRIPTION="swarm runs normally when no option is specified (data in file)"
FASTA=$(mktemp)
printf ">s_1\nA\n" > "${FASTA}"
"${SWARM}" "${FASTA}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${FASTA}"
unset FASTA


#*****************************************************************************#
#                                                                             #
#                             Normal output                                   #
#                                                                             #
#*****************************************************************************#

## OTUs are correct
DESCRIPTION="OTUs are correct"
printf ">s1_2\nAA\n>s2_1\nAT\n>s3_1\nCC\n" | \
    "${SWARM}" 2> /dev/null | \
    tr "\n" "@" | \
    grep -q "s1_2 s2_1@s3_1" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## OTUs number is correct
DESCRIPTION="number of OTUs is correct"
printf ">s1_2\nAA\n>s2_1\nAT\n>s3_1\nCC\n" | \
    "${SWARM}" 2> /dev/null | \
    wc -l | \
    grep -q "^ *2$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## OTU seed is the most abundant amplicon
DESCRIPTION="OTU seed is the most abundant amplicon"
printf ">s1_1\nA\n>s2_2\nT\n" | \
    "${SWARM}" 2> /dev/null | \
    grep -q "^s2_2" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## OTU amplicons are sorted alphabetically
DESCRIPTION="amplicons with the same abundance are sorted alphabetically"
printf ">b_1\nA\n>a_1\nT\n" | \
    "${SWARM}" 2> /dev/null | \
    grep -q "^a_1 b_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# subseeds of a seed are sorted per generation, not globally (sorting
# is done inside a "layer" or "generation": s3 is more abundant than
# s3 and s4, but it belongs to the second generation, not the
# first. That's why it appears after s4, even if its abundance is
# higher)
DESCRIPTION="subseeds of a seed are sorted per generation, not globally"
printf ">s1_9\nA\n>s2_5\nAA\n>s3_4\nAAA\n>s4_3\nAT\n" | \
    "${SWARM}" 2> /dev/null | \
    grep -q "^s1_9 s2_5 s4_3 s3_4$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                             End of options (--)                             #
#                                                                             #
#*****************************************************************************#

## End of option marker is supported (usefull for weirdly named input files)
DESCRIPTION="swarm runs normally when -- marks the end of options"
FASTA=$(mktemp)
printf ">s_1\nA\n" > "${FASTA}"
"${SWARM}" -- "${FASTA}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${FASTA}"
unset FASTA


#*****************************************************************************#
#                                                                             #
#                                Dependencies                                 #
#                                                                             #
#*****************************************************************************#

## Check for SSE2 instructions (x86-64 only)
# works on both Linux and MacOS? alternative is lscpu 2> /dev/null |
# awk '$0 ~ "Architecture" {print $NF}'
ARCHITECTURE=$(uname -a | awk '{print $(NF-1)}')

if [[ "${ARCHITECTURE}" == "x86_64" ]] ; then
    ## SSE2 instructions (first introduced in GGC 3.1)
    SSE2=""
    # on a x86-64 linux system
    SSE2=$(grep -io -m 1 "sse2" /proc/cpuinfo 2> /dev/null)
    # or on a x86-64 MacOS system
    [[ -z "${SSE2}" ]] && \
        SSE2=$(sysctl -n machdep.cpu.features 2> /dev/null | grep -io "SSE2")
    # if sse2 is present, check if swarm runs normally
    if [[ -n "${SSE2}" ]] ; then
        DESCRIPTION="swarm runs normally when SSE2 instructions are available"
        printf ">s_1\nA\n" | \
            "${SWARM}" > /dev/null 2>&1 && \
            success "${DESCRIPTION}" || \
                failure "${DESCRIPTION}"
    else
        # swarm aborts with a non-zero status if SSE2 is missing (hardcoded)
        DESCRIPTION="swarm aborts when SSE2 instructions are not available"
        printf ">s_1\nA\n" | \
            "${SWARM}" > /dev/null 2>&1 && \
            failure "${DESCRIPTION}" || \
                success "${DESCRIPTION}"
    fi
fi
unset ARCHITECTURE SSE2


#*****************************************************************************#
#                                                                             #
#                        Options --version and --help                         #
#                                                                             #
#*****************************************************************************#

## Return status should be 0 after -h and -v (GNU standards)
for OPTION in "-h" "--help" "-v" "--version" ; do
    DESCRIPTION="return status should be 0 after ${OPTION}"
    "${SWARM}" "${OPTION}" 2> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done


#*****************************************************************************#
#                                                                             #
#                              Option --threads                               #
#                                                                             #
#*****************************************************************************#

## Swarm accepts the options -t and --threads
for OPTION in "-t" "--threads" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s_1\nA\n" | \
        "${SWARM}" "${OPTION}" 1 > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Number of threads (--threads from 1 to 256)
MIN=1
MAX=256
DESCRIPTION="swarm runs normally when --threads goes from ${MIN} to ${MAX}"
for ((t=$MIN ; t<=$MAX ; t++)) ; do
    printf ">s_1\nA\n" | \
        "${SWARM}" -t ${t} > /dev/null 2>&1 || \
        failure "swarm aborts when --threads equals ${t}"
done && success "${DESCRIPTION}"
unset MIN MAX t

## Number of threads (--threads is empty)
DESCRIPTION="swarm aborts when --threads is empty"
printf ">s_1\nA\n" | \
    "${SWARM}" -t 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of threads (--threads is zero)
DESCRIPTION="swarm aborts when --threads is zero"
printf ">s_1\nA\n" | \
    "${SWARM}" -t 0 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of threads (--threads is 257)
DESCRIPTION="swarm aborts when --threads is 257"
printf ">s_1\nA\n" | \
    "${SWARM}" -t 257 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of threads (number of threads is way too large)
DESCRIPTION="swarm aborts when --threads is intmax_t (signed)"
printf ">s_1\nA\n" | \
    "${SWARM}" -t $(((1<<63)-1)) 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of threads (--threads is non-numerical)
DESCRIPTION="swarm aborts when --threads is not numerical"
printf ">s_1\nA\n" | \
    "${SWARM}" -t "a" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## It should be possible to check how many threads swarm is using
## (with ps huH | grep -c "swarm") but I cannot get it to work
## properly.


#*****************************************************************************#
#                                                                             #
#                            Options --differences                            #
#                                                                             #
#*****************************************************************************#

## Swarm accepts the options -d and --differences
for OPTION in "-d" "--differences" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s_1\nA\n" | \
        "${SWARM}" "${OPTION}" 1 > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Number of differences (--differences from 0 to 255)
MIN=0
MAX=255
DESCRIPTION="swarm runs normally when --differences goes from ${MIN} to ${MAX}"
for ((d=$MIN ; d<=$MAX ; d++)) ; do
    printf ">s_1\nA\n" | \
        "${SWARM}" -d ${d} > /dev/null 2>&1 || \
        failure "swarm aborts when --differences equals ${d}"
done && success "${DESCRIPTION}"
unset MIN MAX d

## Number of differences (--difference is empty)
DESCRIPTION="swarm aborts when --difference is empty"
printf ">s_1\nA\n" | \
    "${SWARM}" -d 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of differences (--differences is negative)
DESCRIPTION="swarm aborts when --difference is -1"
printf ">s_1\nA\n" | \
    "${SWARM}" -d \-1 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of differences (--differences is 256)
DESCRIPTION="swarm aborts when --difference is 256"
printf ">s_1\nA\n" | \
    "${SWARM}" -d 256 > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of differences (number of differences is way too large)
DESCRIPTION="swarm aborts when --difference is intmax_t (signed)"
printf ">s_1\nA\n" | \
    "${SWARM}" -d $(((1 << 63) - 1)) > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of differences (--difference is non-numerical)
DESCRIPTION="swarm aborts when --difference is not numerical"
printf ">s_1\nA\n" | \
    "${SWARM}" -d "a" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Resolution (d) too high for the given scoring system
# use primer numbers for scoring parameters (greatest common denominator is 1)
DESCRIPTION="swarm aborts when --difference is too high for the scoring system"
printf ">s1_2\nAA\n>s2_1\nAC\n" | \
    "${SWARM}" -d 255 -m 947 -p 953 -g 967 -e 971 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## trigger pairwise alignment using 16 bits on 8 channels (-d >= 16)
# pairwise alignment scores can be stored either on 8 or 16 bits. The
# number of bits is chosen as such:
# if d <= min(255 / mismatch penalty , 255 / gap open + extend) then 8 else 16
# with default pairwise alignment parameters, 255 / 16 is the minimum
# (almost 16), so -d 16 will force pairwise alignments using 16 bits.
DESCRIPTION="trigger pairwise alignment using 16 bits on 8 channels (-d >= 16)"
printf ">s1_1\nAAAAA\n>s2_1\nAAGGA\n" | \
    "${SWARM}" -d 16 > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## trigger pairwise alignment backtracking (d > 1, length > 8,
## insertion) (nw.cc:213)
DESCRIPTION="trigger pairwise alignment backtracking (length > 8, insertion)"
printf ">s1_1\nAAAAAAAAAA\n>s2_1\nAAAAAAAAAAGG\n" | \
    "${SWARM}" -d 2 -u - > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## once down with a cluster, swarm goes back to the first unclustered
## amplicon in the pool (d > 1, algo.cc:266)
DESCRIPTION="swarm goes back to the 1st unclustered amplicon in the pool (d>1)"
printf ">s1_3\nAAA\n>s2_2\nGGG\n>s3_1\nAAG\n" | \
    "${SWARM}" -d 2 > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm -d 2 -w ouputs cluster seeds (algo.cc:591)
DESCRIPTION="swarm -w ouputs cluster seeds (d > 1)"
printf ">s1_3\nAAA\n>s2_2\nGGG\n>s3_1\nAAG\n" | \
    "${SWARM}" -d 2 -w - > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## trigger 16-bit computation for second-generation hits (algo.cc:377)
# With default alignment score parameters, d needs to be at least 7 to
# use 16-bit computations. We also need to use three sequences that
# have 1-7 differences between A and B, and 1-7 differences between B
# and C, and >7 differences between A and C to trigger the scan for
# second-generation hits.
DESCRIPTION="trigger 16-bit computation for second-generation hits"
printf ">a_3\nAAAACCCC\n>b_2\nAAAAGGGG\n>c_1\nTTTTGGGG\n" | \
    "${SWARM}" -d 7 > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


## disable SSE3 instructions (x86-64 only)
ARCHITECTURE=$(uname -a | awk '{print $(NF-1)}')
if [[ "${ARCHITECTURE}" == "x86_64" ]] ; then
    ## trigger pairwise alignment using 16 bits on 8 channels (-d >= 16)
    # pairwise alignment scores can be stored either on 8 or 16 bits. The
    # number of bits is chosen as such:
    # if d <= min(255 / mismatch penalty , 255 / gap open + extend) then 8 else 16
    # with default pairwise alignment parameters, 255 / 16 is the minimum
    # (almost 16), so -d 16 will force pairwise alignments using 16 bits.
    DESCRIPTION="trigger pairwise alignment using 16 bits on 8 channels (-d >= 16) (no SSE3)"
    printf ">s1_1\nAAAAA\n>s2_1\nAAGGA\n" | \
        "${SWARM}" -d 16 --disable-sse3 > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    ## trigger pairwise alignment backtracking (d > 1, length > 8,
    ## insertion) (nw.cc:213)
    DESCRIPTION="trigger pairwise alignment backtracking (length > 8, insertion) (no SSE3)"
    printf ">s1_1\nAAAAAAAAAA\n>s2_1\nAAAAAAAAAAGG\n" | \
        "${SWARM}" -d 2 -u - --disable-sse3 > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    ## trigger 16-bit computation for second-generation hits (algo.cc:377)
    # With default alignment score parameters, d needs to be at least 7 to
    # use 16-bit computations. We also need to use three sequences that
    # have 1-7 differences between A and B, and 1-7 differences between B
    # and C, and >7 differences between A and C to trigger the scan for
    # second-generation hits.
    DESCRIPTION="trigger 16-bit computation for second-generation hits (no SSE3)"
    printf ">a_3\nAAAACCCC\n>b_2\nAAAAGGGG\n>c_1\nTTTTGGGG\n" | \
        "${SWARM}" -d 7 --disable-sse3 > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
fi
unset ARCHITECTURE


#*****************************************************************************#
#                                                                             #
#                             --no-otu-breaking                               #
#                                                                             #
#*****************************************************************************#

## Swarm accepts the options -n and --no-otu-breaking
for OPTION in "-n" "--no-otu-breaking" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s_1\nA\n" | \
        "${SWARM}" "${OPTION}" > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Deactivate the built-in OTU refinement
DESCRIPTION="deactivate OTU breaking"
printf ">s1_9\nAA\n>s2_8\nCC\n>s3_1\nAC\n" | \
    "${SWARM}" -n 2> /dev/null | \
    wc -l | \
    grep -q "^ *1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                             Fastidious options                              #
#                                                                             #
#*****************************************************************************#

## Swarm accepts the options -f and --fastidious
for OPTION in "-f" "--fastidious" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s1_3\nAA\n>s2_1\nCC\n" | \
        "${SWARM}" "${OPTION}" > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm fastidious option only works with d = 1
DESCRIPTION="swarm fastidious only works with d = 1"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -d 2 -f > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm performs a second clustering (aka fastidious)
DESCRIPTION="swarm groups small OTUs with large OTUs (boundary = 3)"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f 2> /dev/null | \
    wc -l | \
    grep -q "^ *1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm attaches small clusters to the largest (or first input) cluster
# if amplicons forming a small cluster can be attached to different
# big clusters, then the first attachment has priority
DESCRIPTION="swarm attaches small clusters to the largest (or first input) cluster"
printf ">s1_3\nAAA\n>s2_1\nACC\n>s3_1\nCCC\n>s4_3\nCGG\n" | \
    "${SWARM}" -f 2> /dev/null | \
    tr "\n" "@" | \
    grep -q "^s1_3 s2_1 s3_1@s4_3@$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


## Boundary -------------------------------------------------------------------

## Swarm accepts the options -b and --boundary
for OPTION in "-b" "--boundary" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s1_3\nAA\n>s2_1\nCC\n" | \
        "${SWARM}" -f "${OPTION}" 3 > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Boundary (-b is empty)
DESCRIPTION="swarm aborts when --boundary is empty"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -b 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Boundary (-b is negative)
DESCRIPTION="swarm aborts when --boundary is -1"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -b \-1 > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Boundary (-b is non-numerical)
DESCRIPTION="swarm aborts when --boundary is not numerical"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -b "a" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Boundary (-b == 1)
DESCRIPTION="swarm aborts when --boundary is 1"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -b 1 > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Accepted values for the boundary option are integers > 1
MIN=2
MAX=255
DESCRIPTION="swarm runs normally when --boundary goes from ${MIN} to ${MAX}"
for ((b=$MIN ; b<=$MAX ; b++)) ; do
    printf ">s1_3\nAA\n>s2_1\nCC\n" | \
        "${SWARM}" -f -b ${b} > /dev/null 2>&1 || \
        failure "swarm aborts when --boundary equals ${b}"
done && success "${DESCRIPTION}"
unset MIN MAX b

## boundary option accepts large integers #1
DESCRIPTION="swarm accepts large values for --boundary (2^32)"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -b $(( 1 << 32 )) > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## boundary option accepts large integers #2
DESCRIPTION="swarm accepts large values for --boundary (2^64, signed)"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -b $(((1 << 63) - 1)) > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Boundary value is taken into account by the fastidious option (-b 2)
DESCRIPTION="boundary value taken into account by fastidious option (-b 2)"
printf ">s1_3\nAA\n>s2_2\nCC\n" | \
    "${SWARM}" -f -b 2 2> /dev/null | \
    wc -l | \
    grep -q "^ *2$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Passing the --boundary option without the fastidious option should fail
DESCRIPTION="swarm fails when the boundary option is specified without -f"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -b 3 > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


## Ceiling --------------------------------------------------------------------

## Swarm accepts the options -c and --ceiling
for OPTION in "-c" "--ceiling" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s1_3\nAA\n>s2_1\nCC\n" | \
        "${SWARM}" -f "${OPTION}" 10 > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Ceiling (-c is empty)
DESCRIPTION="swarm aborts when --ceiling is empty"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -c 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Ceiling (-c is negative)
DESCRIPTION="swarm aborts when --ceiling is -1"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -c \-1 > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Ceiling (-c is non-numerical)
DESCRIPTION="swarm aborts when --ceiling is not numerical"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -c "a" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Ceiling should fail when 0 <= c < 8
for ((c=0 ; c<8; c++)) ; do
    DESCRIPTION="swarm aborts when --ceiling is ${c}"
    printf ">s1_3\nAA\n>s2_1\nCC\n" | \
        "${SWARM}" -f -c ${c} > /dev/null 2>&1 && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
done

## Bloom filter needs at least 8 MB, even for a minimal example
DESCRIPTION="swarm fastidious needs at least 8 MB for the Bloom filter"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -c 8 > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## ceiling option accepts positive integers
MIN=8
MAX=255
DESCRIPTION="swarm runs normally when --ceiling goes from 8 to ${MAX}"
for ((c=$MIN ; c<=$MAX ; c++)) ; do
    printf ">s1_3\nAA\n>s2_1\nCC\n" | \
        "${SWARM}" -f -c ${c} > /dev/null 2>&1 || \
        failure "swarm aborts when --ceiling equals ${c}"
done && success "${DESCRIPTION}"
unset MIN MAX c

## ceiling option accepts large integers
DESCRIPTION="swarm accepts large values for --ceiling (up to 2^30)"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -c $(( 1 << 30 )) > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## ceiling option rejects very large integers
DESCRIPTION="swarm rejects very large values for --ceiling (up to 2^32)"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -c $(( 1 << 32 )) > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Passing the --ceiling option without the fastidious option should fail
DESCRIPTION="swarm fails when the ceiling option is specified without -f"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -c 10 > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


## Bloom bits -----------------------------------------------------------------

## Swarm accepts the options -y and --bloom-bits
for OPTION in "-y" "--bloom-bits" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s1_3\nAA\n>s2_1\nCC\n" | \
        "${SWARM}" -f "${OPTION}" 8 > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Bloom bits (-y is empty)
DESCRIPTION="swarm aborts when --bloom-bits is empty"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -y 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Bloom bits (-y is negative)
DESCRIPTION="swarm aborts when --bloom-bits is -1"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -y \-1 > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Bloom bits (-y is non-numerical)
DESCRIPTION="swarm aborts when --bloom-bits is not numerical"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -y "a" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Accepted values for the --bloom-bits option goes from 2 to 64
MIN=2
MAX=64
DESCRIPTION="swarm runs normally when --bloom-bits goes from ${MIN} to ${MAX}"
for ((y=$MIN ; y<=$MAX ; y++)) ; do
    printf ">s1_3\nAA\n>s2_1\nCC\n" | \
        "${SWARM}" -f -y ${y} > /dev/null 2>&1 || \
        failure "swarm aborts when --bloom-bits equals ${y}"
done && success "${DESCRIPTION}"
unset MIN MAX y

## Rejected values for the --bloom-bits option are < 2
DESCRIPTION="swarm aborts when --bloom-bits is lower than 2"
for y in 0 1 ; do
    printf ">s1_3\nAA\n>s2_1\nCC\n" | \
        "${SWARM}" -f -y ${y} > /dev/null 2>&1 && \
        failure "swarm runs normally when --bloom-bits equals ${y}"
done || success "${DESCRIPTION}"
unset y

## Rejected values for the --bloom-bits option goes from 65 to +infinite
MIN=65
MAX=255
DESCRIPTION="swarm aborts when --bloom-bits is higher than 64"
for ((y=$MIN ; y<=$MAX ; y++)) ; do
    printf ">s1_3\nAA\n>s2_1\nCC\n" | \
        "${SWARM}" -f -y ${y} > /dev/null 2>&1 && \
        failure "swarm runs normally when --bloom-bits equals ${y}"
done || success "${DESCRIPTION}"
unset MIN MAX y

## Passing the --bloom-bits option without the fastidious option should fail
DESCRIPTION="swarm fails when the --bloom-bits option is specified without -f"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -y 16 > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                            Input/Output options                             #
#                                                                             #
#*****************************************************************************#

## ----------------------------------------------------------- append-abundance

## Swarm accepts the options -a and --append-abundance
for OPTION in "-a" "--append-abundance" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s\nA\n" | \
        "${SWARM}" "${OPTION}" 2 > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm -a aborts if abundance value is zero
DESCRIPTION="-a aborts if abundance value is zero"
printf ">s\nA\n" | \
    "${SWARM}" -a 0 > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm -a appends an abundance value to OTU members
DESCRIPTION="-a appends an abundance number to OTU members (-o output)"
printf ">s\nA\n" | \
    "${SWARM}" -a 2 -o - 2> /dev/null | \
    grep -q "^s_2$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm -a appends an abundance value to OTU members (-z)
DESCRIPTION="-a appends an abundance number to OTU members (-o output, -z)"
printf ">s\nA\n" | \
    "${SWARM}" -z -a 2 -o - 2> /dev/null | \
    grep -qE "^s;size=2;?$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm append an abundance value to representative sequences
DESCRIPTION="-a appends an abundance value (-w output)"
printf ">s\nA\n" | \
    "${SWARM}" -a 2 -o /dev/null -w - 2> /dev/null | \
    grep -q "^>s_2$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm append the abundance number set with -a for swarm notation
DESCRIPTION="-a appends an abundance value (-w output, -z)"
printf ">s\nA\n" | \
    "${SWARM}" -z -a 2 -o /dev/null -w - 2> /dev/null | \
    grep -qE "^>s;size=2;?$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm append the abundance number set with -a for usearch notation
DESCRIPTION="-a appends the abundance number (usearch notation)"
printf ">s1;size=3;\nA\n>s2\nC\n" | \
    "${SWARM}" -z -a 2 -o /dev/null -w - 2> /dev/null | \
    grep -qE "^>s1;size=5;?$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm does not overwrite the abundance number with -a for swarm notation
DESCRIPTION="-a does not overwrite the abundance number (swarm notation)"
printf ">s_3\nA\n" | \
    "${SWARM}" -a 2 -o /dev/null -w - 2> /dev/null | \
    grep -q "^>s_3$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm does not overwrite the abundance number with -a for usearch notation
DESCRIPTION="-a does not overwrite the abundance number (usearch notation)"
printf ">s;size=3;\nA\n" | \
    "${SWARM}" -z -a 2 -o /dev/null -w - 2> /dev/null | \
    grep -qE "^>s;size=3;?$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## when using -a, check if the added abundance annotation appears in -o output
DESCRIPTION="-a abundance annotation appears in -o output"
printf ">s\nA\n" | \
    "${SWARM}" -a 2 -o - 2> /dev/null | \
    grep -q "^s_2$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## when using -a, the added abundance annotation should not appear in -i output
DESCRIPTION="-a abundance annotation does not appear in -i output"
printf ">s1_1\nA\n>s2\nT\n" | \
    "${SWARM}" -a 1 -o /dev/null -i - 2> /dev/null | \
    awk '{exit $2 == "s2" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## when using -a and -r, the added abundance annotation appears in -o output
DESCRIPTION="-a abundance annotation appears in -o output when using -r"
printf ">s1_1\nA\n>s2\nT\n" | \
    "${SWARM}" -a 1 -r -o - 2> /dev/null | \
    grep -q "s2_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## when using -a, check if the added abundance annotation influences -s output
DESCRIPTION="-a abundance annotation influences -s output"
printf ">s1\nA\n>s2_1\nT\n" | \
    "${SWARM}" -a 2 -o /dev/null -s - 2> /dev/null | \
    awk '{exit $3 == "s1" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## when using -a, check if the added abundance annotation appears in -u output
DESCRIPTION="-a abundance annotation appears in -u output"
printf ">s1\nA\n>s2_1\nT\n" | \
    "${SWARM}" -a 2 -o /dev/null -u - 2> /dev/null | \
    grep -q "s1_2" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


## --------------------------------------------------------- internal structure

## Swarm accepts the options -i and --internal-structure
for OPTION in "-i" "--internal-structure" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s_1\nA\n" | \
        "${SWARM}" "${OPTION}" /dev/null > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm -i fails if no output file given
DESCRIPTION="-i fails if no output file given"
printf ">s_1\nA\n" | \
    "${SWARM}" -i > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm -i fails if unable to open output file for writing
DESCRIPTION="-i fails if unable to open output file for writing"
TMP=$(mktemp) && chmod u-w ${TMP}  # remove write permission
printf ">s_1\nA\n" | \
    "${SWARM}" -i ${TMP} > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
chmod u+w ${TMP} && rm -f ${TMP}
unset TMP

## Swarm -i create and fill given output file
DESCRIPTION="-i creates and fill given output file"
printf ">s1_1\nA\n>s2_1\nT\n" | \
    "${SWARM}" -o /dev/null -i - 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm -i output is tab-separated
DESCRIPTION="-i output is tab-separated"
printf ">s1_1\nA\n>s2_1\nT\n" | \
    "${SWARM}" -o /dev/null -i - 2> /dev/null | \
    tr "\t" "@" | \
    grep -q "^s1@s2@1@1@1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm -i output has 5 columns
DESCRIPTION="-i output has 5 columns"
printf ">s1_1\nA\n>s2_1\nT\n" | \
    "${SWARM}" -o /dev/null -i - 2> /dev/null | \
    awk '{exit (NF == 5) ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i columns 1 and 2 contain sequence names
DESCRIPTION="-i columns 1 and 2 contain sequence names"
printf ">s1_1\nA\n>s2_1\nT\n" | \
    "${SWARM}" -o /dev/null -i - 2> /dev/null | \
    awk '{exit ($1 == "s1" && $2 == "s2") ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of differences is correct (0 expected)
DESCRIPTION="-i number of differences is correct (0 expected)"
printf ">s1_1\nA\n>s2_1\nA\n" | \
    "${SWARM}" -o /dev/null -i - 2> /dev/null | \
    awk '{exit ($3 == 0) ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of differences is correct when -d 2 (2 expected)
DESCRIPTION="-i number of differences is correct when -d 2 (2 expected)"
printf ">s1_1\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -d 2 -o /dev/null -i - 2> /dev/null | \
    awk '{exit ($3 == 2) ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of differences is correct when -d 2 (1 expected)
DESCRIPTION="-i number of differences is correct when -d 2 (1 expected)"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -d 2 -o /dev/null -i - 2> /dev/null | \
    awk '{exit ($3 == 1) ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of the OTU is correct #1
DESCRIPTION="-i number of the OTU is correct #1"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -d 2 -o /dev/null -i - 2> /dev/null | \
    awk '{exit ($4 == 1) ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i outputs one line per OTU
DESCRIPTION="-i outputs one line per OTU"
printf ">s1_1\nAA\n>s2_1\nAC\n>s3_1\nGG\n>s4_1\nGT\n" | \
    "${SWARM}" -o /dev/null -i - 2> /dev/null | \
    wc -l | \
    grep -q "^ *2$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of the OTU is correct #2
DESCRIPTION="-i number of the OTU is correct #2"
printf ">s1_1\nAA\n>s2_1\nAC\n>s3_1\nGG\n>s4_1\nGT\n" | \
    "${SWARM}" -o /dev/null -i - 2> /dev/null | \
    awk 'NR == 2 {exit ($4 == 2) ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of steps is correct (1 expected)
DESCRIPTION="-i number of steps is correct (1 expected)"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -i - 2> /dev/null | \
    awk '{exit ($5 == 1) ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of steps is correct (3 expected)
DESCRIPTION="-i number of steps is correct (3 expected)"
printf ">s1_1\nAA\n>s2_1\nAC\n>s3_1\nCC\n>s4_1\nCT\n" | \
    "${SWARM}" -o /dev/null -i - 2> /dev/null | \
    awk 'NR == 3 {exit ($5 == 3) ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of steps is correct when -d 2 (1 expected)
DESCRIPTION="-i number of steps is correct when -d 2 (1 expected)"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -d 2 -o /dev/null -i - 2> /dev/null | \
    awk '{exit ($5 == 1) ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of steps is correct while -d 2 (2 expected)
DESCRIPTION="-i number of steps is correct while -d 2 (2 expected)"
printf ">s1_1\nAAAA\n>s2_1\nAACC\n>s3_1\nCCCC\n" | \
    "${SWARM}" -d 2 -o /dev/null -i - 2> /dev/null | \
    awk 'NR == 2 {exit ($5 == 2) ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i -f OTU numbering is updated (2nd line, col. 4 should be 1)
# a	b	1	1	1
# b	c	2	1	2
# c	d	1	1	1
DESCRIPTION="-i -f OTU numbering is updated"
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_1\nATTT\n>d_1\nTTTT\n" | \
    "${SWARM}" -f -o /dev/null -i - 2> /dev/null | \
    awk 'NR == 2 {exit $4 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i -f OTU numbering is contiguous (no gap) (4th line, col. 4 should be 2)
# a	b	1	1	1
# b	c	2	1	2
# c	d	1	1	1
# e	f	1	2	1
DESCRIPTION="-i -f OTU numbering is contiguous (no gap)"
(printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_1\nATTT\n"
 printf ">d_1\nTTTT\n>e_1\nGGGG\n>f_1\nGGGA\n") | \
    "${SWARM}" -f -o /dev/null -i - 2> /dev/null | \
    awk 'NR == 4 {exit $4 == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i -f small clusters can be grafted via a subseed
##
## If you run fastidious with boundary 4 you will first get a and b
## clustered with a as the seed and then c and d clustered with c as
## the seed. In the fastidious phase b will be connected to d. Here is
## the expected resulting structure:
##
## a	b	1	1	1
## b	d	2	1	2
## c	d	1	1	1
##
DESCRIPTION="-i -f small clusters can be grafted via a subseed"
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_2\nTTTT\n>d_1\nATTT\n" | \
    "${SWARM}" -f -b 4 -o /dev/null -i - 2> /dev/null | \
    awk 'NR == 2 {exit $1 == "b" && $2 == "d" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i -f small cluster internal links are always given after the graft link
##
## If you run fastidious with boundary 4 you will first get a and b
## clustered with a as the seed and then c and d clustered with c as
## the seed. In the fastidious phase b will be connected to d. Here is
## the expected resulting structure:
##
## a	b	1	1	1
## b	d	2	1	2
## c	d	1	1	1
##
DESCRIPTION="-i -f small cluster internal links are always given after the graft link"
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_2\nTTTT\n>d_1\nATTT\n" | \
    "${SWARM}" -f -b 4 -o /dev/null -i - 2> /dev/null | \
    awk 'NR == 3 {exit $1 == "c" && $2 == "d" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i -f number of steps between grafted amplicon and its new seed is
## not updated (3rd line, col. 5 is set to 1)
##
## If you run fastidious with boundary 4 you will first get a and b
## clustered with a as the seed and then c and d clustered with c as
## the seed. In the fastidious phase b will be connected to d, and the
## number of steps between the amplicon d and its new seed is not
## updated. Here is the expected resulting structure:
##
## a	b	1	1	1
## b	d	2	1	2
## c	d	1	1	1
##
DESCRIPTION="-i -f # of steps between grafted amplicon and seed is not updated"
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_2\nTTTT\n>d_1\nATTT\n" | \
    "${SWARM}" -f -b 4 -o /dev/null -i - 2> /dev/null | \
    awk 'NR == 3 {exit $5 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i print semicolon if the abundance is not at either end (gcov)
##
## >s1;size=1;length=1 is parsed as s1 size=1 length=1, when printing
## to ouput files, this function adds a semicolon to separate the
## remaining header elements: "s1" + ";" + "length=1"
##
DESCRIPTION="-i print semicolon if the abundance is not at either end (gcov)"
printf ">s1;size=1;length=1\nA\n>s2;size=1;length=1\nT\n" | \
    "${SWARM}" -z -o /dev/null -i - 2> /dev/null | \
    grep -Eq "^s1;length=1[[:blank:]]s2;length=1" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


## --------------------------------------------------------------- network-file

# when d = 1, dumps the network of single-difference amplicons to a
# specified file in a sorted and tab-separated format (seed amplicon,
# neighbour amplicon). Use -n to get the full network, otherwise only
# links between amplicons where the abundance of the seed is higher or
# equal to the abundance of the neighbour is included.

## Swarm accepts the options -j and --network-file
for OPTION in "-j" "--network-file" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s1_1\nA\n>s2_1\nT\n" | \
        "${SWARM}" "${OPTION}" /dev/null > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

# fatal error if network output file is not writable
DESCRIPTION="-j output file is not writable"
TMP=$(mktemp)
chmod ugo-w "${TMP}"
printf ">s1_2\nAA\n>s2_1\nAC\n" | \
    "${SWARM}" -j "${TMP}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
rm -f "${TMP}"
unset TMP

## tests written with Milena Königshofen:
# https://github.com/milenazilena/Internship_2019/blob/master/Tests/test_network_option.sh

# test sequences with one difference (different abundances): we expect
# one link
DESCRIPTION="-j one difference, different abundances: one link"
printf ">s1_3\nA\n>s2_1\nC\n" | \
    "${SWARM}" -l /dev/null -o /dev/null -j - | \
    awk '{exit NR == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# test sequences with two differences (different abundances): we
# expect no link
DESCRIPTION="-j two differences, different abundances: no link"
printf ">s1_3\nA\n>s2_1\nCC\n" | \
    "${SWARM}" -l /dev/null -o /dev/null -j - | \
    awk '{exit NR == 0 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# test sequences with one difference (same abundances): we expect two
# links
DESCRIPTION="-j one difference, same abundance: two links"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -l /dev/null -o /dev/null -j - | \
    awk 'END {exit NR == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# test sequences with two differences (same abundances): we expect no
# link
DESCRIPTION="-j two differences, same abundance: no link"
printf ">s1_1\nA\n>s2_1\nCC\n" | \
    "${SWARM}" -l /dev/null -o /dev/null -j - | \
    awk '{exit NR == 0 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# tab-separated format
DESCRIPTION="-j tab-separated format"
printf ">s1_3\nA\n>s2_1\nC\n" | \
    "${SWARM}" -l /dev/null -o /dev/null -j - | \
    grep -q $'\t' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# sorted by decreasing abundances within link (most abundant amplicon
# first)
DESCRIPTION="-j link members are sorted by decreasing abundance"
printf ">s1_1\nA\n>s2_3\nC\n" | \
    "${SWARM}" -l /dev/null -o /dev/null -j - | \
    awk '{exit $1 == "s2_3" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# sorted by decreasing abundances between lines (most abundant
# amplicon first)
DESCRIPTION="-j links are sorted by decreasing abundance"
printf ">s1_2\nA\n>s2_1\nC\n>s3_1\nTT\n>s4_3\nGT\n" | \
    "${SWARM}" -l /dev/null -o /dev/null -j - | \
    cut -f 1 | \
    tr "\n" " " | \
    awk -F "[_ ]" '{exit $2 > $4 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# binds from high to low abundances: we expect only one link if
# sequences have different abundance values
DESCRIPTION="-j link from high to low abundance"
printf ">s1_3\nA\n>s2_1\nC\n" | \
    "${SWARM}" -l /dev/null -o /dev/null -j - | \
    awk '{exit NR == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# binds between equals: we expect double link if sequences have
# different abundance values
DESCRIPTION="-j double link when equal abundance"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -l /dev/null -o /dev/null -j - | \
    tr "\n" " " | \
    awk '{exit $1 == $4 && $2 == $3 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# double links are from A to B and from B to A
DESCRIPTION="-j double link when equal abundance (A to B and B to A)"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -l /dev/null -o /dev/null -j - | \
    awk 'END {exit NR == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# double links also between layers: we expect double links between
# s2_1 and s3_1
DESCRIPTION="-j expect double link between layers too"
printf ">s1_3\nA\n>s2_1\nC\n>s3_1\nCT\n" | \
    "${SWARM}" -l /dev/null -o /dev/null -j - | \
        tail -n 2 | \
        tr "\n" " " | \
        awk '{exit $1 == $4 && $2 == $3 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# only with d = 1: we expect no link
DESCRIPTION="-j only when -d 1"
printf ">s1_3\nA\n>s2_1\nC\n>s3_1\nG\n" | \
    "${SWARM}" -d 2 -o /dev/null -j - 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

# using fastidious option: we expect no error
DESCRIPTION="-j works with -f"
printf ">s1_3\nA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -l /dev/null -o /dev/null -j - && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# with fastidious option: we expect no link (referred to "test
# sequences with two differences (different abundances)")
DESCRIPTION="-j -f no link if two differences"
printf ">s1_3\nA\n>s2_1\nCC\n" | \
    "${SWARM}" -f -l /dev/null -o /dev/null -j - | \
    awk '{exit NR == 0 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# fastidious option doesn't change behaviour of -j
DESCRIPTION="-f does not change the behaviour of -j"
printf ">s1_3\nA\n>s2_1\nC\n" | \
    "${SWARM}" -f -l /dev/null -o /dev/null -j - | \
    awk '{exit NR == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# -n to get full network (abundance values don't matter anymore)
# we expect a double link
DESCRIPTION="-n does not change the behaviour of -j"
printf ">s1_3\nA\n>s2_1\nC\n" | \
    "${SWARM}" -n -l /dev/null -o /dev/null -j - | \
    tr "\n" " " | \
    awk '{exit $1 == $4 && $2 == $3 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


## ------------------------------------------------------------------------ log

## Swarm accepts the options -l and --log
for OPTION in "-l" "--log" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s_1\nA\n" | \
        "${SWARM}" "${OPTION}" /dev/null > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm -l writes to the specified output file
DESCRIPTION="-l writes to the specified output file"
printf ">s_1\nA\n" | \
    "${SWARM}" -o /dev/null -l - 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm -l fails if unable to open output file for writing
DESCRIPTION="-l fails if unable to open output file for writing"
TMP=$(mktemp) && chmod u-w ${TMP}  # remove write permission
printf ">s_1\nA\n" | \
    "${SWARM}" -l ${TMP} > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
chmod u+w ${TMP} && rm -f ${TMP}
unset TMP

## Swarm does not write on standard error when using -l
DESCRIPTION="swarm does not write on stderr when using -l"
printf ">s_1\nA\n" | \
    "${SWARM}" -o /dev/null -l /dev/null 2>&1 | \
    grep -q "." && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm does write on standard error when using -l, except for errors
DESCRIPTION="swarm does not write on stderr when using -l, except for errors"
# voluntary error (missing d value) to create an error message
printf ">s_1\nA\n" | \
    "${SWARM}" -d -o /dev/null -l /dev/null 2>&1 | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm -l clobbers when using /dev/stdout (linux only, no clobbering on MacOS)
# DESCRIPTION="swarm -l clobbers when using /dev/stdout"
# LOG=$(mktemp)
# echo "pass 1" > ${LOG}
# printf ">s_1\nA\n" | \
#     "${SWARM}" -o /dev/null -l /dev/stdout >> ${LOG}
# head -n 1 ${LOG} | \
#     grep -q "^pass 1$" && \
#     failure "${DESCRIPTION}" || \
#         success "${DESCRIPTION}"
# rm -f ${LOG}
# unset LOG

## Swarm -l does no clobber when using "-"
DESCRIPTION="swarm -l does no clobber when using '-'"
LOG=$(mktemp)
echo "pass 1" > ${LOG}
printf ">s_1\nA\n" | \
    "${SWARM}" -o /dev/null -l - >> ${LOG}
head -n 1 ${LOG} | \
    grep -q "^pass 1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f ${LOG}
unset LOG


## ---------------------------------------------------------------- output-file

## Swarm accepts the options -o and --output-file
for OPTION in "-o" "--output-file" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s_1\nA\n" | \
        "${SWARM}" "${OPTION}" /dev/null 2> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm outputs to stdout if -o is not used
DESCRIPTION="swarm writes to stdout if -o is not used"
printf ">s_1\nA\n" | \
    "${SWARM}" 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm creates output file with -o option
DESCRIPTION="-o writes to the specified output file"
printf ">s_1\nA\n" | \
    "${SWARM}" -o - 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm -o fails if unable to open output file for writing
DESCRIPTION="-o fails if unable to open output file for writing"
TMP=$(mktemp) && chmod u-w ${TMP}  # remove write permission
printf ">s_1\nA\n" | \
    "${SWARM}" -o ${TMP} > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
chmod u+w ${TMP} && rm -f ${TMP}
unset TMP

## Swarm fills correctly output file with -o option
DESCRIPTION="-o creates and fills the output file"
printf ">s_1\nA\n" | \
    "${SWARM}" -o - 2> /dev/null | \
    grep -q "^s_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


## --------------------------------------------------------------------- mothur

## Swarm accepts the options -r and --mothur
for OPTION in "-r" "--mothur" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s_1\nA\n" | \
        "${SWARM}" "${OPTION}" > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## -r first row is correct
DESCRIPTION="-r first row is correct"
printf ">s_1\nA\n" | \
    "${SWARM}" -r 2> /dev/null | \
    grep -q "^swarm_1" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -r first row is correct with -d 2
DESCRIPTION="-r first row is correct (d = 2)"
printf ">s_1\nA\n" | \
    "${SWARM}" -d 2 -r 2> /dev/null | \
    grep -q "^swarm_2" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -r first row is correct
DESCRIPTION="-r field separator is a tabulation"
printf ">s_1\nA\n" | \
    "${SWARM}" -r 2> /dev/null | \
    awk 'BEGIN {FS = "[\t]"} {exit NF == 3 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -r number of OTUs is correct (1 OTU)
DESCRIPTION="-r number of OTUs is correct (1 line expected)"
printf ">s_1\nA\n" | \
    "${SWARM}" -r 2> /dev/null | \
    wc -l | \
    grep -q "^ *1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="-r number of OTUs is correct (2nd field is 1)"
printf ">s_1\nA\n" | \
    "${SWARM}" -r 2> /dev/null | \
    awk '{exit $2 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="-r number of OTUs is correct (last field is s_1)"
printf ">s_1\nA\n" | \
    "${SWARM}" -r 2> /dev/null | \
    awk '{exit $NF == "s_1" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -r number of OTUs is correct (2 OTUs)
DESCRIPTION="-r number of OTUs is correct (2nd field is 2)"
printf ">s1_1\nAA\n>s2_1\nTT\n" | \
    "${SWARM}" -r 2> /dev/null | \
    awk '{exit $2 == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

DESCRIPTION="-r number of OTUs is correct (last field is s2_1)"
printf ">s1_1\nAA\n>s2_1\nTT\n" | \
    "${SWARM}" -r 2> /dev/null | \
    awk '{exit $NF == "s2_1" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -r number of fields is correct (4 fields expected)
DESCRIPTION="-r number of fields is correct (4 fields expected)"
printf ">s1_1\nAA\n>s2_1\nAT\n>s3_1\nGG\n" | \
    "${SWARM}" -r 2> /dev/null | \
    awk '{exit NF == 4 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -r composition of OTUs is correct #1
DESCRIPTION="-r composition of OTUs is correct (1 OTU)"
printf ">s1_1\nAA\n>s2_1\nAT\n" | \
    "${SWARM}" -r 2> /dev/null | \
    awk '{exit $NF == "s1_1,s2_1" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -r composition of OTUs is correct #2
DESCRIPTION="-r composition of OTUs is correct (2 OTUs #1)"
printf ">s1_1\nAA\n>s2_1\nAT\n>s3_1\nGG\n" | \
    "${SWARM}" -r 2> /dev/null | \
    awk '{exit $NF == "s3_1" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -r composition of OTUs is correct #3
DESCRIPTION="-r composition of OTUs is correct (2 OTUs #2)"
printf ">s1_1\nAA\n>s2_1\nGG\n>s3_1\nGC\n" | \
    "${SWARM}" -r 2> /dev/null | \
    awk '{exit $NF == "s2_1,s3_1" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -r output takes into account -a
DESCRIPTION="-r output takes into account -a"
printf ">s\nA\n" | \
    "${SWARM}" -a 2 -r 2> /dev/null | \
    awk '{exit $NF == "s_2" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -r composition of OTUs is correct with -a
DESCRIPTION="-r composition of OTUs is correct with -a"
printf ">s1_1\nA\n>s2\nT\n" | \
    "${SWARM}" -a 2 -r 2> /dev/null | \
    awk '{exit $NF == "s2_2,s1_1" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -r composition of OTUs is correct with -z
DESCRIPTION="-r OTUs is correct with -z"
printf ">s;size=1\nA\n" | \
    "${SWARM}" -z -r 2> /dev/null | \
    awk '{exit $NF == "s;size=1" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -r OTU is correct with -z -a (adds ;size=INT;, with a terminal ";")
DESCRIPTION="-r OTU is correct with -z -a"
printf ">s\nA\n" | \
    "${SWARM}" -z -a 1 -r 2> /dev/null | \
    awk '{exit $NF == "s;size=1;" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -r composition of OTUs is correct with -z -a (2 sequences)
## note the mix of ;size=INT and ;size=INT;
DESCRIPTION="-r OTUs is correct with -z -a (2 sequences)"
printf ">s1\nA\n>s2;size=2\nT\n" | \
    "${SWARM}" -z -a 1 -r 2> /dev/null | \
    awk '{exit $NF == "s2;size=2,s1;size=1;" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


## ------------------------------------------------------------ statistics-file

## Swarm accepts the options -s and --statistics-file
for OPTION in "-s" "--statistics-file" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s_1\nA\n" | \
        "${SWARM}" "${OPTION}" /dev/null > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm -s create and fill given filename
DESCRIPTION="-s create and fill filename given"
OUTPUT=$(mktemp)
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2>&1
[[ -s "${OUTPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm -s fails if no filename given
DESCRIPTION="-s fails if no filename given"
printf ">s_1\nA\n" | \
    "${SWARM}" -s  > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm -s fails if file is not writable
DESCRIPTION="-s fails if file is not writable"
OUTPUT=$(mktemp)
chmod -w "${OUTPUT}"
printf ">s_1\nA\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
chmod +w "${OUTPUT}" && rm -f "${OUTPUT}"
unset OUTPUT

## Number of unique amplicons is correct (1 expected)
DESCRIPTION="-s number of unique amplicons is correct (1 expected)"
printf ">s_1\nA\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk '{exit $1 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of unique amplicons is correct (2 expected)
DESCRIPTION="-s number of unique amplicons is correct (2 expected)"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk '{exit $1 == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of unique amplicons is correct (1 expected)
DESCRIPTION="-s number of unique amplicons is correct (1 expected)"
printf ">s1_1\nA\n>s2_1\nC\n>s3_1\nGG\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk 'NR == 2 {exit $1 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Total abundance of amplicons is correct (1 expected)
DESCRIPTION="-s total abundance of amplicons is correct (1 expected)"
printf ">s_5\nA\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk '{exit $2 == 5 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Total abundance of amplicons is correct (2 expected)
DESCRIPTION="-s total abundance of amplicons is correct (2 expected)"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk '{exit $2 == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## id of initial seed is correct with -s
DESCRIPTION="-s ID of initial seed is correct"
printf ">s_1\nA\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk '{exit $3 == "s" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## second seed id is correct with -s
DESCRIPTION="-s ID of second seed is correct"
printf ">s1_3\nAA\n>s2_2\nAC\n>s3_1\nGG\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} NR == 2 {exit $3 == "s3" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Abundance of initial seed is correct with -s
DESCRIPTION="-s abundance of initial seed is correct"
printf ">s1_3\nAA\n>s2_2\nAC\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} NR == 1 {exit $4 == 3 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Abundance of second seed is correct with -s
DESCRIPTION="-s abundance of second seed is correct"
printf ">s1_3\nAA\n>s2_2\nAC\n>s3_1\nGG\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} NR == 2 {exit $4 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of amplicons with an abundance of 1 is correct with -s (0 exp)
DESCRIPTION="-s number of amplicons with an abundance of 1 (0 expected)"
printf ">s1_3\nAA\n>s2_2\nAC\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} NR == 1 {exit $5 == 0 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of amplicons with an abundance of 1 is correct with -s (1 exp)
DESCRIPTION="-s number of amplicons with an abundance of 1 (1 expected)"
printf ">s1_3\nAA\n>s2_1\nAC\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} NR == 1 {exit $5 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of iterations is correct with -s (0 expected)
DESCRIPTION="-s number of iterations is correct (0 expected)"
printf ">s_1\nA\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} NR == 1 {exit $6 == 0 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of iterations is correct with (d = 1) (1 expected)
DESCRIPTION="-s number of iterations is correct with d = 1 (1 expected)"
printf ">s1_3\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} NR == 1 {exit $6 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of iterations is correct with (d = 2) (1 expected)
DESCRIPTION="-s number of iterations is correct with d = 2 (1 expected)"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -d 2 -o /dev/null -s - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} NR == 1 {exit $6 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of iterations is correct with -s -d 2 (2 expected)
DESCRIPTION="-s number of iterations is correct with d = 2 (2 expected)"
printf ">s1_3\nAAA\n>s2_1\nAAC\n>s3_1\nCCC\n" | \
    "${SWARM}" -d 2 -o /dev/null -s - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} NR == 1 {exit $6 == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Theorical radius is correct with -s (0 expected)
DESCRIPTION="-s theorical maximum radius is correct (0 expected)"
printf ">s_1\nA\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} NR == 1 {exit $7 == 0 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Theorical radius is correct with -s (1 expected)
DESCRIPTION="-s theorical maximum radius is correct (1 expected)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} NR == 1 {exit $7 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Theorical radius is correct with -s -d 2 (2 expected)
DESCRIPTION="-s theorical maximum radius is correct -d 2 (2 expected)"
printf ">s1_3\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -d 2 -o /dev/null -s - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} NR == 1 {exit $7 == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## reported radius != real radius  with -s -d 2 (actual radius is 3)
DESCRIPTION="-s reported radius != real radius -d 2"
printf ">s1_3\nAAAA\n>s2_3\nAACC\n>s3_2\nCCCC\n>s4_2\nCCAC\n" | \
    "${SWARM}" -d 2 -o /dev/null -s - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} NR == 1 {exit $7 == 5 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -s print semicolon if the abundance is not at either end (gcov)
##
## >s;size=1;length=1 is parsed as s size=1 length=1, when printing
## to ouput files, this function adds a semicolon to separate the
## remaining header elements: "s" + ";" + "length=1"
##
DESCRIPTION="-s print semicolon if the abundance is not at either end (gcov)"
printf ">s;size=1;length=1\nA\n" | \
    "${SWARM}" -z -o /dev/null -s - 2> /dev/null | \
    grep -Eq "[[:blank:]]s;length=1[[:blank:]]" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


## ---------------------------------------------------------------- uclust-file

## Swarm accepts the options -u and --uclust-file
for OPTION in "-u" "--uclust-file" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s1_1\nA\n>s2_1\nC\n" | \
        "${SWARM}" "${OPTION}" /dev/null > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm -u fails if no output file given
DESCRIPTION="-u fails if no output file given"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -u > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm -u creates and fills file given as argument
OUTPUT=$(mktemp)
DESCRIPTION="-u creates and fills file given in argument"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -u "${OUTPUT}" > /dev/null 2>&1
[[ -s "${OUTPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm -u fails if file is not writable
DESCRIPTION="-u fails if file is not writable"
OUTPUT=$(mktemp)
chmod -w "${OUTPUT}"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -u "${OUTPUT}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
chmod +w "${OUTPUT}" && rm -f "${OUTPUT}"
unset OUTPUT

## -u number of hits is correct (1)
DESCRIPTION="-u number of hits is 1"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {s += 1} END {exit s == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u number of hits is correct (2)
DESCRIPTION="-u number of hits is 2"
printf ">s1_1\nA\n>s2_1\nC\n>s3_1\nG\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {s += 1} END {exit s == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u number of centroids is correct (1)
DESCRIPTION="-u number of centroids is 1"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "S" {s += 1} END {exit s == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u number of centroids is correct (2)
DESCRIPTION="-u number of centroids is 2"
printf ">s1_1\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "S" {s += 1} END {exit s == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u number of clusters is correct (1)
DESCRIPTION="-u number of clusters is 1"
printf ">s1_1\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {s += 1} END {exit s == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u number of clusters is correct (2)
DESCRIPTION="-u number of clusters is 2"
printf ">s1_1\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {s += 1} END {exit s == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u cluster number is correct (2nd column)
DESCRIPTION="-u cluster number is zero"
printf ">s_1\nA\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {v = $2} END {exit v == 0 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u cluster number is correct (2nd column)
DESCRIPTION="-u cluster number is 1 (for second cluster)"
printf ">s1_1\nAA\n>s2_1\nCC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {v = $2} END {exit v == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u cluster size is correct (3rd column)
DESCRIPTION="-u cluster size is 1"
printf ">s_1\nA\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {exit $3 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u cluster size is correct (3rd column)
## usearch tallies amplicons, not reads:
# printf ">s1;size=2;\nAAAA\n>s2;size=1;\nAAAA\n" > tmp.fas
# usearch7 -cluster_fast tmp.fas -minseqlength 1 -id 0.5 -uc tmp.uc
# cat tmp.uc
# rm tmp.*
DESCRIPTION="-u cluster size is 2 (2 amplicons in total)"
printf ">s1_2\nA\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {exit $3 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u cluster size is 2 (3rd column, second cluster)
DESCRIPTION="-u cluster size is 2 (second cluster)"
printf ">s1_3\nAA\n>s2_2\nCC\n>s3_1\nCT\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {v = $3} END {exit v == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u centroid length is 2 (3rd column)
DESCRIPTION="-u centroid length is 2 (3rd column)"
printf ">s_1\nAA\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "S" {exit $3 == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u centroid length is 1 (3rd column, second cluster)
DESCRIPTION="-u centroid length is 1 (3rd column, second cluster)"
printf ">s1_3\nAA\n>s2_2\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "S" {v = $3} END {exit v == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u centroid length is 1 (3rd column, centroid is shorter than hit)
DESCRIPTION="-u centroid length is 1 (3rd column, centroid shorter than hit)"
printf ">s1_3\nA\n>s2_1\nAA\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "S" {exit $3 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u query length is 1 (3rd column)
DESCRIPTION="-u query length is 1 (3rd column)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $3 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u query length is 2 (3rd column, second cluster)
DESCRIPTION="-u query length is 2 (3rd column, second cluster)"
printf ">s1_3\nA\n>s2_2\nCC\n>s3_1\nCG\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $3 == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u query length is 2 (3rd column, query is longer than centroid)
DESCRIPTION="-u query length is 2 (3rd column, query longer than centroid)"
printf ">s1_2\nA\n>s2_1\nAA\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $3 == 2 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u similarity percentage is zero in 4th column
## Sequences s1 and s2 should be grouped inside the same OTU, with a
## similarity of 0.0.
DESCRIPTION="-u similarity percentage is 0.0"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $4 == "0.0" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u similarity percentage is zero in 4th column and centroid is s1
## Sequences are sorted by fasta identifier to break abundance ties.
DESCRIPTION="-u similarity percentage is zero (sorted by fasta identifier)"
printf ">s2_1\nC\n>s1_1\nA\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $10 == "s1_1" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u similarity percentage is 50% in 4th column
DESCRIPTION="-u similarity percentage is 50.0"
printf ">s1_2\nAA\n>s2_1\nAC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $4 == "50.0" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u similarity percentage is * for the cluster centroid (S)
DESCRIPTION="-u similarity percentage is * for cluster centroid"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "S" {exit $4 == "*" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u similarity percentage is * for the cluster record (C)
DESCRIPTION="-u similarity percentage is * for cluster record"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {exit $4 == "*" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u match orientation is + for hits
DESCRIPTION="-u match orientation is + for hits"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $5 == "+" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u match orientation is * for the cluster centroid (S)
DESCRIPTION="-u match orientation is * for the cluster centroid (S)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "S" {exit $5 == "*" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u match orientation is * for the cluster record (C)
DESCRIPTION="-u match orientation is * for the cluster record (C)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {exit $5 == "*" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u unused column 6 is * for hits
DESCRIPTION="-u unused column 6 is 0 for hits"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $6 == 0 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u unused column 6 is * for the cluster centroid (S)
DESCRIPTION="-u unused column 6 is * for the cluster centroid (S)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "S" {exit $6 == "*" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u unused column 6 is * for the cluster record (C)
DESCRIPTION="-u unused column 6 is * for the cluster record (C)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {exit $6 == "*" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u unused column 7 is * for hits
DESCRIPTION="-u unused column 7 is 0 for hits"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $7 == 0 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u unused column 7 is * for the cluster centroid (S)
DESCRIPTION="-u unused column 7 is * for the cluster centroid (S)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "S" {exit $7 == "*" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u unused column 7 is * for the cluster record (C)
DESCRIPTION="-u unused column 7 is * for the cluster record (C)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {exit $7 == "*" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u column 8 (CIGAR) is * for the cluster centroid (S)
DESCRIPTION="-u column 8 (CIGAR) is * for cluster centroid (S)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "S" {exit $8 == "*" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u column 8 (CIGAR) is * for the cluster record (C)
DESCRIPTION="-u column 8 (CIGAR) is * for cluster record (C)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {exit $8 == "*" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u column 8 (CIGAR) is 4M for hit
## (4 matches/mismatches)
DESCRIPTION="-u column 8 (CIGAR) is 4M for hit"
printf ">s1_1\nAAAA\n>s2_1\nAAAC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $8 == "4M" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u column 8 (CIGAR) is D3M for hit
## (a deletion, 3 matches/mismatches)
DESCRIPTION="-u column 8 (CIGAR) is D3M for hit"
printf ">s1_1\nAAAA\n>s2_1\nAAA\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $8 == "D3M" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u column 8 (CIGAR) is 4MI for hit
## (4 matches/mismatches, with a terminal insertion)
DESCRIPTION="-u column 8 (CIGAR) is D3M for hit"
printf ">s1_1\nAAAA\n>s2_1\nAAAAA\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $8 == "4MI" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u column 8 (CIGAR) is = for hit (perfect alignment)
DESCRIPTION="-u column 8 (CIGAR) is = for hit"
printf ">s1_1\nAAAA\n>s2_1\nAAAA\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $8 == "=" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u column 8 (CIGAR) is 4M for hit (d = 4)
DESCRIPTION="-u column 8 (CIGAR) is 4M for hit (d = 4)"
printf ">s1_1\nAAAA\n>s2_1\nACGT\n" | \
    "${SWARM}" -d 4 -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $8 == "4M" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u column 8 (CIGAR) is 2D2M for hit (d = 4)
DESCRIPTION="-u column 8 (CIGAR) is 2D2M for hit (d = 4)"
printf ">s1_1\nAAAA\n>s2_1\nCG\n" | \
    "${SWARM}" -d 4 -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $8 == "2D2M" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u column 8 (CIGAR) is 4M2I for hit (d = 4)
DESCRIPTION="-u column 8 (CIGAR) is 4M2I for hit (d = 4)"
printf ">s1_1\nAAAA\n>s2_1\nACGTTT\n" | \
    "${SWARM}" -d 4 -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $8 == "4M2I" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u query's label is s2_1 for hit
DESCRIPTION="-u query's label is s2_1 for hit"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $9 == "s2_1" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u query's label is s1_2 for the cluster centroid (S)
DESCRIPTION="-u query's label is s1_2 for the cluster centroid (S)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "S" {exit $9 == "s1_2" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u query's label is s1_2 for the cluster record (C)
DESCRIPTION="-u query's label is s1_2 for the cluster record (C)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {exit $9 == "s1_2" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u centroid's label is s2_1 for hit (H)
DESCRIPTION="-u centroid's label is s1_2 for hit"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "H" {exit $10 == "s1_2" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u centroid's label is * for the cluster centroid (S)
DESCRIPTION="-u centroid's label is * for the cluster centroid (S)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "S" {exit $10 == "*" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u centroid's label is * for the cluster record (C)
DESCRIPTION="-u centroid's label is * for the cluster record (C)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {exit $10 == "*" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u -f OTU numbering is contiguous (no gap)
## s3-s4 is grafted onto s1-s2, so s5 becomes the second OTU
DESCRIPTION="-u -f OTU numbering is contiguous (no gap)"
printf ">s1_3\nAAAA\n>s2_1\nAAAT\n>s3_1\nATTT\n>s4_1\nTTTT\n>s5_1\nGGGG\n" | \
    "${SWARM}" -f -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"}
         $1 == "C" && $9 == "s5_1" {exit $2 == 1 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u clusters are reported by decreasing (seed) abundance
DESCRIPTION="-u clusters are reported by decreasing (seed) abundance"
printf ">s1_1\nAA\n>s2_2\nCC\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {exit $9 == "s2_2" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -u clusters are reported by decreasing seed abundance
# C	0	1	*	*	*	*	*	s2_3	*
# S	0	2	*	*	*	*	*	s2_3	*
# C	1	2	*	*	*	*	*	s1_2	*
# S	1	2	*	*	*	*	*	s1_2	*
# H	1	2	50.0	+	0	0	2M	s3_2	s1_2
DESCRIPTION="-u clusters are reported by decreasing seed abundance"
printf ">s1_2\nAA\n>s2_3\nCC\n>s3_2\nAG\n" | \
    "${SWARM}" -o /dev/null -u - 2> /dev/null | \
    awk 'BEGIN {FS = "\t"} $1 == "C" {exit $9 == "s2_3" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


## ---------------------------------------------------------------------- seeds

## Swarm accepts the options -w and --seeds
for OPTION in "-w" "--seeds" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s_1\nA\n" | \
        "${SWARM}" "${OPTION}" - > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## -w creates and fills file given in argument
DESCRIPTION="swarm -w create and fill file given in argument"
printf ">s_1\nA\n" | \
    "${SWARM}" -o /dev/null -w - 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm -w fails if no output file given
DESCRIPTION="-w fails if no output file given"
printf ">s_1\nA\n" | \
    "${SWARM}" -o /dev/null -w 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm -w fails if unable to open output file for writing
DESCRIPTION="-w fails if unable to open output file for writing"
TMP=$(mktemp) && chmod u-w ${TMP}  # remove write permission
printf ">s_1\nA\n" | \
    "${SWARM}" -w ${TMP} > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
chmod u+w ${TMP} && rm -f ${TMP}
unset TMP

## -w gives expected output (1 cluster)
DESCRIPTION="-w gives expected output (1 cluster)"
printf ">s1_2\nA\n>s2_1\nC\n" | \
    "${SWARM}" -o /dev/null -w - 2> /dev/null | \
    tr -d "\n" | \
    grep -q "^>s1_3A$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -w gives expected output (1 cluster, seed is the most abundant sequence)
DESCRIPTION="-w gives expected output (1 cluster, most abundant seed)"
printf ">s1_1\nA\n>s2_2\nC\n" | \
    "${SWARM}" -o /dev/null -w - 2> /dev/null | \
    tr -d "\n" | \
    grep -q "^>s2_3C$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -w gives expected output (2 clusters)
DESCRIPTION="-w gives expected output (2 clusters)"
printf ">s1_2\nAA\n>s2_1\nAC\n>s3_1\nGG\n" | \
    "${SWARM}" -o /dev/null -w - 2> /dev/null | \
    tr -d "\n" | \
    grep -q "^>s1_3AA>s3_1GG$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Check the output order (it should be sorted by abundance, then by
## alphabetical order of headers). Ordering by sequences (A, C, G and
## T) is never necessary since sequence labels are always different
## (even when d = 0).

## -w expected output order (2 clusters, ordered by abundance)
DESCRIPTION="-w expected output order (2 clusters, abundance)"
printf ">s1_1\nAA\n>s2_2\nGG\n" | \
    "${SWARM}" -o /dev/null -w - 2> /dev/null | \
    tr -d "\n" | \
    grep -q "^>s2_2GG>s1_1AA$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -w expected order (2 clusters, ordered by abundance, then by labels)
DESCRIPTION="-w expected output order (2 clusters, abundance, labels)"
printf ">s2_1\nAA\n>s1_1\nGG\n" | \
    "${SWARM}" -o /dev/null -w - 2> /dev/null | \
    tr -d "\n" | \
    grep -q "^>s1_1GG>s2_1AA$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -w can sum up large abundance values (2 * (2^32 + 1) = 4294967297)
## 4294967297 * 2 = 8589934594
DESCRIPTION="-w can sum up large abundance values (2 * (2^32 + 1))"
printf ">s1_4294967297\nA\n>s2_4294967297\nT\n" | \
    "${SWARM}" -o /dev/null -w - 2> /dev/null | \
    tr -d "\n" | \
    grep -q "^>s1_8589934594A$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -d 2 -w when seeds have the same abundance
DESCRIPTION="-w when seeds have the same abundance (d > 1)"
printf ">s1_1\nAAA\n>s2_1\nCCC\n" | \
    "${SWARM}" -d 2 -o /dev/null -w - 2> /dev/null | \
    tr -d "\n" | \
    grep -q "^>s1_1AAA>s2_1CCC$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -d 2 -w when the second seed has a higher abundance
DESCRIPTION="-w when the second seed has a higher abundance (d > 1)"
printf ">s1_2\nAAA\n>s2_2\nCCC\n>s3_1\nCCCC\n" | \
    "${SWARM}" -d 2 -o /dev/null -w - 2> /dev/null | \
    tr -d "\n" | \
    grep -q "^>s2_3CCC>s1_2AAA$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


## --------------------------------------------------------------- disable-sse3

# disables SSE3 and any other x86 extensions beyond SSE2 (which is
# always present on x86_64). SSE3 is only used when d>1.

## Swarm accepts the options -x and --disable-sse3
for OPTION in "-x" "--disable-sse3" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">s1_1\nA\n>s2_1\nT\n" | \
        "${SWARM}" -d 2 "${OPTION}" > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## disable SSE3 instructions (x86-64 only)
ARCHITECTURE=$(uname -a | awk '{print $(NF-1)}')
if [[ "${ARCHITECTURE}" == "x86_64" ]] ; then
    ## CPU features (sse3 and above are correctly detected)
    DESCRIPTION="detect cpu features (-d 2) (with SSE3)"
    printf ">s1_1\nA\n" | \
        "${SWARM}" -d 2 2>&1 > /dev/null | \
        grep "^CPU features" | \
        grep -q "sse3" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    ## CPU features (sse3 and above are correctly disabled)
    DESCRIPTION="disable sse3 and above (-d 2)"
    printf ">s1_1\nA\n" | \
        "${SWARM}" -d 2 --disable-sse3 2>&1 > /dev/null | \
        grep "^CPU features" | \
        grep -q "sse3" && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
fi
unset ARCHITECTURE

# SSE3 instructions are only used when d > 1
DESCRIPTION="swarms accepts -x when d > 1"
printf ">s1_1\nAA\n>s2_1\nTT\n" | \
    "${SWARM}" -d 2 -x > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

# -x has no effect when d = 1 or d = 0
DESCRIPTION="swarms rejects -x when d = 1"
printf ">s1_1\nA\n>s2_1\nT\n" | \
    "${SWARM}" -d 1 -x > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

# -x has no effect when d = 0
DESCRIPTION="swarms rejects -x when d = 0"
printf ">s1_1\nA\n>s2_1\nT\n" | \
    "${SWARM}" -d 0 -x > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


## ---------------------------------------------------------- usearch-abundance

# what are the output files impacted by the -z option?
## reminder: >header[[:blank:]]   and   header = label_[1-9][0-9]*$

## output created by the -i option is not modified by the option -z
DESCRIPTION="in -i ouput, -z has no visible effect (-i reports only labels)"
printf ">s1;size=1;\nA\n>s2;size=1;\nT\n" | \
    "${SWARM}" -z -o /dev/null -i - 2> /dev/null | \
    grep -qE "^s1[[:blank:]]s2[[:blank:]]" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## output created by the -l option is not modified by the option -z
DESCRIPTION="in -l ouput, -z has no visible effect"
printf ">s;size=1;\nA\n" | \
    "${SWARM}" -z -o /dev/null -l - 2> /dev/null | \
    grep -E ";size=[0-9]+" && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## output created by the -o option is not modified by the option -z
DESCRIPTION="in -o ouput, -z has no direct effect"
printf ">s;size=1;\nA\n" | \
    "${SWARM}" -z -o - 2> /dev/null | \
    grep -q "^s;size=1;$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## output created by the -o option is not modified by the option -z
DESCRIPTION="in -o ouput, -z has no direct effect (-o reports headers)"
printf ">s;size=1\nA\n" | \
    "${SWARM}" -z -o - 2> /dev/null | \
    grep -q "^s;size=1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## output created by the -r option is not modified by the option -z
DESCRIPTION="in -r ouput, -z has no direct effect"
printf ">s1;size=1;\nA\n>s2;size=1;\nC\n" | \
    "${SWARM}" -z -r -o - 2> /dev/null | \
    grep -q "s1;size=1;,s2;size=1;$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## output created by the -r option is not modified by the option -z
DESCRIPTION="in -r ouput, -z has no direct effect (-r reports headers)"
printf ">s1;size=1\nA\n>s2;size=1\nC\n" | \
    "${SWARM}" -z -r -o - 2> /dev/null | \
    grep -q "s1;size=1,s2;size=1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## output created by the -s option is not modified by the option -z
DESCRIPTION="in -s ouput, -z has no direct effect (-s reports labels)"
printf ">s;size=1;\nA\n" | \
    "${SWARM}" -z -o /dev/null -s - 2> /dev/null | \
    grep -qE "[[:blank:]]s[[:blank:]]" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## output created by the -u option is not modified by the option -z
DESCRIPTION="in -u ouput, -z has no direct effect"
printf ">s;size=1;\nA\n" | \
    "${SWARM}" -z -o /dev/null -u - 2> /dev/null | \
    grep -qE "[[:blank:]]s;size=1;[[:blank:]]" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## output created by the -u option is not modified by the option -z
DESCRIPTION="in -u ouput, -z has no direct effect (-s reports headers)"
printf ">s;size=1\nA\n" | \
    "${SWARM}" -z -o /dev/null -u - 2> /dev/null | \
    grep -qE "[[:blank:]]s;size=1[[:blank:]]" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## in the output created by the -w option, -z modifies the header format
DESCRIPTION="in -w ouput, -z modifies the header format"
printf ">s;size=1;\nA\n" | \
    "${SWARM}" -z -o /dev/null -w - 2> /dev/null | \
    grep -q "^>s;size=1;$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## a semi-colon is added if it is not in the input
DESCRIPTION="in -w ouput, -z adds a terminal ';' to sequence headers"
printf ">s;size=1\nA\n" | \
    "${SWARM}" -z -o /dev/null -w - 2> /dev/null | \
    grep -q "^>s;size=1;$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                dereplication options and behavior (-d 0)                    #
#                                                                             #
#*****************************************************************************#

## see https://github.com/torognes/swarm/issues/125

## check that swarm behaves as expected when d = 0:
# swarm -d 0 [-rz] [-a int] [-i filename] [-l filename] [-o filename]
#     [-s filename] [-u filename] [-w filename] [filename]

## d = 0 identical sequences are merged
DESCRIPTION="swarm merges identical sequences (-d 0)"
printf ">s1_1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 2> /dev/null | \
    grep -qx "s2_5 s1_1" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 different sequences are not merged
DESCRIPTION="swarm does not merge different sequences (-d 0)"
printf ">s1_1\nA\n>s2_5\nT\n" | \
    "${SWARM}" -d 0 2> /dev/null | \
    wc -l | \
    grep -q "^ *2$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 outputs clusters (stdout)
DESCRIPTION="swarm outputs clusters to stdout (-d 0)"
printf ">s1_1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 outputs clusters (file)
DESCRIPTION="swarm outputs clusters to file (-d 0)"
printf ">s1_1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 -o - 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 produces a fasta output
DESCRIPTION="swarm produces a fasta output (-d 0)"
printf ">s1_1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 -o /dev/null -w - 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 identical sequences are merged in fasta output (merged abundances)
DESCRIPTION="swarm merges identical sequences in fasta output (-d 0)"
printf ">s1_1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 -o /dev/null -w - 2> /dev/null | \
    grep -qx ">s2_6" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 identical sequences are merged (;size=)
DESCRIPTION="swarm merges identical sequences (-z) (-d 0)"
printf ">s1;size=1\nA\n>s2;size=5\nA\n" | \
    "${SWARM}" -d 0 -z 2> /dev/null | \
    grep -qx "s2;size=5 s1;size=1" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 identical sequences are merged in fasta output (merged abundances)
DESCRIPTION="swarm merges identical sequences in fasta output (-z) (-d 0)"
printf ">s1;size=1\nA\n>s2;size=5\nA\n" | \
    "${SWARM}" -d 0 -z -o /dev/null -w - 2> /dev/null | \
    grep -qx ">s2;size=6;" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 outputs to a log file
DESCRIPTION="swarm outputs to a log file (-d 0)"
printf ">s1_1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 -o /dev/null -l - 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 outputs a structure file
DESCRIPTION="swarm outputs struct to file (-d 0)"
printf ">s1_1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 -o /dev/null -i - 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 produces structure output
DESCRIPTION="swarm produces a correct struct output (-d 0)"
printf ">s1_1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 -o /dev/null -i - 2> /dev/null | \
    tr "\t" "@" | \
    grep -qx "s2@s1@0@1@0" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 outputs a stats file
DESCRIPTION="swarm outputs stats to file (-d 0)"
printf ">s1_1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 -o /dev/null -s - 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 produces stats output
DESCRIPTION="swarm produces a correct stats output (-d 0)"
printf ">s1_1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 -o /dev/null -s - 2> /dev/null | \
    tr "\t" "@" | \
    grep -qx "2@6@s2@5@1@0@0" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 outputs a uclust file
DESCRIPTION="swarm outputs uclust-format to file (-d 0)"
printf ">s1_1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 -o /dev/null -u - 2> /dev/null | \
    grep -q "." && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 produces uclust output
DESCRIPTION="swarm produces a correct uclust output (-d 0)"
printf ">s1_1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 -o /dev/null -u - 2> /dev/null | \
    awk 'END {exit NR == 3 && NF == 10 ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 produces mothur-like output
DESCRIPTION="swarm produces a mothur-like output (-d 0)"
printf ">s1_1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 -r 2> /dev/null | \
    tr "\t" "@" | \
    grep -qx "swarm_0@1@s2_5,s1_1" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## d = 0 missing abundances are replaced as expected
DESCRIPTION="swarm missing abundances are replaced as expected (-a) (-d 0)"
printf ">s1\nA\n>s2_5\nA\n" | \
    "${SWARM}" -d 0 -a 1 -o /dev/null -w - 2> /dev/null | \
    grep -qx ">s2_6" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                              Output sorting                                 #
#                                                                             #
#*****************************************************************************#

## Swarm sorts amplicons in an OTU by decreasing abundance
DESCRIPTION="swarm sorts amplicons in an OTU by decreasing abundance"
printf ">s3_1\nA\n>s1_3\nC\n>s2_2\nG\n" | \
    "${SWARM}" 2> /dev/null | \
    grep -q "^s1_3 s2_2 s3_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm sorts fasta output by decreasing abundance
DESCRIPTION="swarm sorts fasta output by decreasing abundance"
printf ">s1_1\nAA\n>s2_3\nCC\n" | \
    "${SWARM}" 2> /dev/null | \
    awk 'NR == 1 {exit ($1 == "s2_3") ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                     Pairwise alignment advanced options                     #
#                                                                             #
#*****************************************************************************#

while read LONG SHORT ; do
    ## Using option when d = 1 should fail (or warning?)
    DESCRIPTION="swarm aborts when --${LONG} is specified and d = 1"
    printf ">s_1\nA\n" | \
        "${SWARM}" -d 1 ${SHORT} 1 > /dev/null 2>&1 && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"

    ## option is empty
    DESCRIPTION="swarm aborts when --${LONG} is empty"
    printf ">s_1\nA\n" | \
        "${SWARM}" -d 2 ${SHORT} > /dev/null 2>&1 && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"

    ## option is negative
    DESCRIPTION="swarm aborts when --${LONG} is -1"
    printf ">s_1\nA\n" | \
        "${SWARM}" -d 2 ${SHORT} \-1 > /dev/null 2>&1 && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"

    ## option is non-numerical
    DESCRIPTION="swarm aborts when --${LONG} is not numerical"
    printf ">s_1\nA\n" | \
        "${SWARM}" -d 2 ${SHORT} "a" > /dev/null 2>&1 && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"

    ## option is null (allowed for -m & -p, not for -g & -e)
    if [[ "${SHORT}" == "-m" || "${SHORT}" == "-p" ]] ; then
        DESCRIPTION="swarm aborts when --${LONG} is null"
        printf ">s_1\nA\n" | \
            "${SWARM}" -d 2 ${SHORT} 0 > /dev/null 2>&1 && \
            failure "${DESCRIPTION}" || \
                success "${DESCRIPTION}"
    elif [[ "${SHORT}" == "-g" || "${SHORT}" == "-e" ]] ; then
        DESCRIPTION="swarm runs normally when --${LONG} is null"
        printf ">s_1\nA\n" | \
            "${SWARM}" -d 2 ${SHORT} 0 > /dev/null 2>&1 && \
            success "${DESCRIPTION}" || \
                failure "${DESCRIPTION}"
    else
        DESCRIPTION="unknown option"
        failure "${DESCRIPTION}"
    fi

    ## Accepted values for the option goes from 1 to 255
    MIN=1
    MAX=255
    DESCRIPTION="swarm runs normally when --${LONG} goes from ${MIN} to ${MAX}"
    for ((i=$MIN ; i<=$MAX ; i++)) ; do
        printf ">s_1\nA\n" | \
            "${SWARM}" -d 2 "${SHORT}" ${i} > /dev/null 2>&1 || \
            failure "swarm aborts when --${LONG} equals ${i}"
    done && success "${DESCRIPTION}"

done <<EOF
match-reward -m
mismatch-penalty -p
gap-opening-penalty -g
gap-extension-penalty -e
EOF

## swarm aborts if gap opening + gap extension is less than 1
DESCRIPTION="swarm aborts if -g plus -e is zero"
printf ">s_1\nA\n" | \
    "${SWARM}" -d 2 -g 0 -e 0 > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                 search for leaks and errors with valgrind                   #
#                                                                             #
#*****************************************************************************#

## valgrind errors
if which valgrind > /dev/null 2>&1 ; then

    ## basic options

    DESCRIPTION="valgrind check for errors: -v"
    valgrind \
        --log-fd=1 \
        --leak-check=full \
        "${SWARM}" -v 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -h"
    valgrind \
        --log-fd=1 \
        --leak-check=full \
        "${SWARM}" -h 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"


    ## options available when d = 1

    DESCRIPTION="valgrind check for errors: default"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -a 1"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -a 1 <(printf ">s1\nAA\n>s2\nAC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -d 1"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 1 <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -n"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -n <(printf ">s1_2\nAA\n>s2_1\nAC\n>s3_2\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -r"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -r <(printf ">s1_2\nAA\n>s2_1\nAC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -t 1"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -t 1 <(printf ">s1_2\nAA\n>s2_1\nAC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -z"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -z <(printf ">s;size=1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -i"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -i - <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -l"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -l - <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -o"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -o - <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -s"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -s - <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -u"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -u - <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -w"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -w - <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"


    ## fastidious options (Bloom filter requires more memory when
    ## using valgrind)

    DESCRIPTION="valgrind check for errors: -f"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -f <(printf ">s1_3\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -f -b 2"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -f -b 2 <(printf ">s1_3\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    # -c 8 is enough without valgrind
    DESCRIPTION="valgrind check for errors: -f -c 100"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -f -c 100 <(printf ">s1_3\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -f -y 12"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -f -y 12 <(printf ">s1_3\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"


    ## options available when d > 1

    DESCRIPTION="valgrind check for errors: -d 2"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 2 <(printf ">s1_2\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -d 2 -e 3"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 2 -e 3 <(printf ">s1_2\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -d 2 -g 11"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 2 -g 11 <(printf ">s1_2\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -d 2 -m 4"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 2 -m 4 <(printf ">s1_2\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors: -d 2 -p 3"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 2 -p 3 <(printf ">s1_2\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"


    ## options available when d = 0 (dereplication)

    DESCRIPTION="valgrind check for errors (-d 0): default"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors (-d 0): -a 1"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -a 1 <(printf ">s1\nA\n>s2\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors (-d 0): -r"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -r <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors (-d 0): -t 1"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -t 1 <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors (-d 0): -z"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -z <(printf ">s1;size=1\nA\n>s2;size=1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors (-d 0): -i"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -i - <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors (-d 0): -l"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -l - <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors (-d 0): -o"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -o - <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors (-d 0): -s"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -s - <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors (-d 0): -u"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -u - <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for errors (-d 0): -w"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -w - <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "ERROR SUMMARY: 0 errors" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
fi


## valgrind leaks
if which valgrind > /dev/null 2>&1 ; then

    ## basic options

    DESCRIPTION="valgrind check for unfreed memory: -v"
    valgrind \
        --log-fd=1 \
        --leak-check=full \
        "${SWARM}" -v 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -h"
    valgrind \
        --log-fd=1 \
        --leak-check=full \
        "${SWARM}" -h 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"


    ## options available when d = 1

    DESCRIPTION="valgrind check for unfreed memory: default"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -a 1"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -a 1 <(printf ">s1\nAA\n>s2\nAC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -d 1"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 1 <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -n"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -n <(printf ">s1_2\nAA\n>s2_1\nAC\n>s3_2\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -r"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -r <(printf ">s1_2\nAA\n>s2_1\nAC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -t 1"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -t 1 <(printf ">s1_2\nAA\n>s2_1\nAC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -z"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -z <(printf ">s;size=1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -i"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -i - <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -l"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -l - <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -o"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -o - <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -s"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -s - <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -u"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -u - <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -w"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -w - <(printf ">s_1\nA\n") 3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"


    ## fastidious options (Bloom filter requires much more memory when
    ## using valgrind)

    DESCRIPTION="valgrind check for unfreed memory: -f"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -f <(printf ">s1_3\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -f -b 2"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -f -b 2 <(printf ">s1_3\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    # -c 8 is enough without valgrind
    DESCRIPTION="valgrind check for unfreed memory: -f -c 100"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -f -c 100 <(printf ">s1_3\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -f -y 12"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -f -y 12 <(printf ">s1_3\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"


    ## options available when d > 1

    DESCRIPTION="valgrind check for unfreed memory: -d 2"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 2 <(printf ">s1_2\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -d 2 -e 3"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 2 -e 3 <(printf ">s1_2\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -d 2 -g 11"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 2 -g 11 <(printf ">s1_2\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -d 2 -m 4"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 2 -m 4 <(printf ">s1_2\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory: -d 2 -p 3"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 2 -p 3 <(printf ">s1_2\nAA\n>s2_1\nCC\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"


    ## options available when d = 0 (dereplication)

    DESCRIPTION="valgrind check for unfreed memory (-d 0): default"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory (-d 0): -a 1"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -a 1 <(printf ">s1\nA\n>s2\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory (-d 0): -r"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -r <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory (-d 0): -t 1"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -t 1 <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory (-d 0): -z"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -z <(printf ">s1;size=1\nA\n>s2;size=1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory (-d 0): -i"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -i - <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory (-d 0): -l"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -l - <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory (-d 0): -o"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -o - <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory (-d 0): -s"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -s - <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory (-d 0): -u"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -u - <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"

    DESCRIPTION="valgrind check for unfreed memory (-d 0): -w"
    valgrind \
        --log-fd=3 \
        --leak-check=full \
        "${SWARM}" -d 0 -w - <(printf ">s1_1\nA\n>s2_1\nA\n") \
        3>&1 1> /dev/null 2> /dev/null | \
        grep -q "in use at exit: 0 bytes" && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
fi


# ## valgrind thread issues (DOES NOT WORK WHEN DEBUG IS ACTIVATED!)
# if which valgrind > /dev/null 2>&1 ; then

#     DESCRIPTION="valgrind check for thread issues (-d 0)"
#     valgrind \
#         --log-fd=3 \
#         --tool=helgrind \
#         "${SWARM}" -d 0 -t 2 \
#         <(printf ">s1_1\nA\n>s2_1\nA\n>s3_1\nA\n>s4_1\nA\n") \
#         3>&1 1> /dev/null 2> /dev/null | \
#         grep -q "ERROR SUMMARY: 0 errors" && \
#         success "${DESCRIPTION}" || \
#             failure "${DESCRIPTION}"

#     DESCRIPTION="valgrind check for thread issues (-d 1)"
#     valgrind \
#         --log-fd=3 \
#         --tool=helgrind \
#         "${SWARM}" -d 1 -t 2 \
#         <(printf ">s1_1\nA\n>s2_1\nC\n>s3_1\nG\n>s4_1\nT\n") \
#         3>&1 1> /dev/null 2> /dev/null | \
#         grep -q "ERROR SUMMARY: 0 errors" && \
#         success "${DESCRIPTION}" || \
#             failure "${DESCRIPTION}"

#     DESCRIPTION="valgrind check for thread issues (-d 1 -f)"
#     valgrind \
#         --log-fd=3 \
#         --tool=helgrind \
#         "${SWARM}" -d 1 -f -t 2 \
#         <(printf ">s1_3\nAA\n>s2_1\nAC\n>s3_1\nAG\n>s4_1\nTT\n") \
#         3>&1 1> /dev/null 2> /dev/null | \
#         grep -q "ERROR SUMMARY: 0 errors" && \
#         success "${DESCRIPTION}" || \
#             failure "${DESCRIPTION}"

#     DESCRIPTION="valgrind check for thread issues (-d 2)"
#     valgrind \
#         --log-fd=3 \
#         --tool=helgrind \
#         "${SWARM}" -d 2 -t 2 \
#         <(printf ">s1_3\nAAA\n>s2_1\nACC\n>s3_1\nAGG\n>s4_1\nATT\n") \
#         3>&1 1> /dev/null 2> /dev/null | \
#         grep -q "ERROR SUMMARY: 0 errors" && \
#         success "${DESCRIPTION}" || \
#             failure "${DESCRIPTION}"

# fi

exit 0
