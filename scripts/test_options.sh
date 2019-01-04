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
    # exit -1
}

success () {
    printf "${GREEN}PASS${NO_COLOR}: ${1}\n"
}       

## Create a test file with 10 identical sequences (different headers)
ALL_IDENTICAL=$(mktemp)
for ((i=0 ; i<=9 ; i++)) ; do
    printf ">%s%d_1\nACGT\n" "seq" ${i}
done > "${ALL_IDENTICAL}"

## use the first swarm binary in $PATH by default, unless user wants
## to test another binary
SWARM=$(which swarm)
[[ "${1}" ]] && SWARM="${1}"

DESCRIPTION="check if swarm is executable"
[[ -x "${SWARM}" ]] && success "${DESCRIPTION}" || failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                                  No option                                  #
#                                                                             #
#*****************************************************************************#

## No option, only standard input
DESCRIPTION="swarm runs normally when no option is specified (data on stdin)"
"${SWARM}" < "${ALL_IDENTICAL}" &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## No option, only a fasta file
DESCRIPTION="swarm runs normally when no option is specified (data in file)"
"${SWARM}" "${ALL_IDENTICAL}" &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                             Normal output                                   #
#                                                                             #
#*****************************************************************************#

## OTUs are correct
DESCRIPTION="OTUs are correct"
OUTPUT=$(printf ">s1_2\nAAAA\n>s2_1\nAAAA\n>s3_1\nCCCC\n" | \
    "${SWARM}" 2> /dev/null)
[[ "${OUTPUT}" == $(printf "s1_2 s2_1\ns3_1") ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## OTUs number is correct
DESCRIPTION="number of OTUs is correct"
OUTPUT=$(printf ">s1_2\nAAAA\n>s2_1\nAAAA\n>s3_1\nCCCC\n" | \
                "${SWARM}" 2> /dev/null)
(( $(wc -l <<< "${OUTPUT}") == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## OTUs' seeds are the more abundants amplicons
DESCRIPTION="OTUs' seeds are the more abundants amplicons"
OUTPUT=$(printf ">s1_1\nAAAA\n>s2_2\nAAAA\n>s3_1\nAAAAA\n" | \
    "${SWARM}" 2> /dev/null | awk 'NR==1 {print $1}')
[[ "${OUTPUT}" == "s2_2" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## OTUs' amplicons are sorted in alphabetical order
DESCRIPTION="amplicons with the same abundance are sorted alphabetically"
OUTPUT=$(printf ">a_1\nAAAA\n>c_1\nAAAA\n>b_1\nAAAA\n" | \
    "${SWARM}" 2> /dev/null)
[[ "${OUTPUT}" == "a_1 b_1 c_1" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                             End of options (--)                             #
#                                                                             #
#*****************************************************************************#

## End of option marker is supported (usefull for weirdly named input files)
DESCRIPTION="swarm runs normally when -- marks the end of options"
"${SWARM}" -- "${ALL_IDENTICAL}" &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                             Read from stdin (-)                             #
#                                                                             #
#*****************************************************************************#

## Accept to read from /dev/stdin
DESCRIPTION="swarm reads from /dev/stdin"
"${SWARM}" /dev/stdin < "${ALL_IDENTICAL}" &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Accept "-" as a placeholder for stdin
DESCRIPTION="swarm reads from stdin when - is used"
"${SWARM}" - < "${ALL_IDENTICAL}" &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                                Dependencies                                 #
#                                                                             #
#*****************************************************************************#

## SSE2 instructions (first introduced in GGC 3.1)
SSE2=""
# on a linux system
SSE2=$(grep -io -m 1 "sse2" /proc/cpuinfo 2> /dev/null)
# or on a MacOS system
[[ -z "${SSE2}" ]] && \
    SSE2=$(sysctl -n machdep.cpu.features 2> /dev/null | grep -io "SSE2")
# if sse2 is present, check if swarm runs normally
if [[ -n "${SSE2}" ]] ; then
    DESCRIPTION="swarm runs normally when SSE2 instructions are available"
    "${SWARM}" "${ALL_IDENTICAL}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
else
    # swarm aborts with a non-zero status if SSE2 is missing (hardcoded)
    DESCRIPTION="swarm aborts when SSE2 instructions are not available"
    "${SWARM}" "${ALL_IDENTICAL}" &> /dev/null && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
fi
unset SSE2


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
    "${SWARM}" "${OPTION}" 1 < "${ALL_IDENTICAL}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Number of threads (--threads from 1 to 256)
MIN=1
MAX=256
DESCRIPTION="swarm runs normally when --threads goes from ${MIN} to ${MAX}"
for ((t=$MIN ; t<=$MAX ; t++)) ; do
    "${SWARM}" -t ${t} < "${ALL_IDENTICAL}" &> /dev/null || \
        failure "swarm aborts when --threads equals ${t}"
done && success "${DESCRIPTION}"

## Number of threads (--threads is empty)
DESCRIPTION="swarm aborts when --threads is empty"
"${SWARM}" -t < "${ALL_IDENTICAL}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of threads (--threads is zero)
DESCRIPTION="swarm aborts when --threads is zero"
"${SWARM}" -t 0 < "${ALL_IDENTICAL}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of threads (--threads is 257)
DESCRIPTION="swarm aborts when --threads is 257"
"${SWARM}" -t 257 < "${ALL_IDENTICAL}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of threads (number of threads is way too large)
DESCRIPTION="swarm aborts when --threads is intmax_t (signed)"
"${SWARM}" -t $(((1<<63)-1)) < "${ALL_IDENTICAL}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of threads (--threads is non-numerical)
DESCRIPTION="swarm aborts when --threads is not numerical"
"${SWARM}" -t "a" < "${ALL_IDENTICAL}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## It should be possible to check how many threads swarm is using
## (with ps huH | grep -c "swarm") but I cannot get it to work
## properly.

unset MIN MAX


#*****************************************************************************#
#                                                                             #
#                            Options --differences                            #
#                                                                             #
#*****************************************************************************#

## Swarm accepts the options -d and --differences
for OPTION in "-d" "--differences" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    "${SWARM}" "${OPTION}" 1 < "${ALL_IDENTICAL}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Number of differences (--differences from 0 to 255)
MIN=0
MAX=255
DESCRIPTION="swarm runs normally when --differences goes from ${MIN} to ${MAX}"
for ((d=$MIN ; d<=$MAX ; d++)) ; do
    "${SWARM}" -d ${d} < "${ALL_IDENTICAL}" &> /dev/null || \
        failure "swarm aborts when --differences equals ${d}"
done && success "${DESCRIPTION}"

## Number of differences (--difference is empty)
DESCRIPTION="swarm aborts when --difference is empty"
"${SWARM}" -d < "${ALL_IDENTICAL}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of differences (--differences is negative)
DESCRIPTION="swarm aborts when --difference is -1"
"${SWARM}" -d \-1 < "${ALL_IDENTICAL}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of differences (--differences is 256)
DESCRIPTION="swarm aborts when --difference is 256"
"${SWARM}" -d 256 < "${ALL_IDENTICAL}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of differences (number of differences is way too large)
DESCRIPTION="swarm aborts when --difference is intmax_t (signed)"
"${SWARM}" -d $(((1 << 63) - 1)) < "${ALL_IDENTICAL}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of differences (--difference is non-numerical)
DESCRIPTION="swarm aborts when --difference is not numerical"
"${SWARM}" -d "a" < "${ALL_IDENTICAL}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

unset MIN MAX


#*****************************************************************************#
#                                                                             #
#                             --no-otu-breaking                               #
#                                                                             #
#*****************************************************************************#

## Swarm accepts the options -n and --no-otu-breaking
for OPTION in "-n" "--no-otu-breaking" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">a_10\nACGT\n>b_9\nCGGT\n>c_1\nCCGT\n" | \
        "${SWARM}" "${OPTION}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Deactivate the built-in OTU refinement
DESCRIPTION="deactivate OTU breaking"
LINENUMBER=$(printf ">a_10\nACGT\n>b_9\nCGGT\n>c_1\nCCGT\n" | \
                    "${SWARM}" -n 2> /dev/null | wc -l)
(( ${LINENUMBER} == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset LINENUMBER


#*****************************************************************************#
#                                                                             #
#                             Fastidious options                              #
#                                                                             #
#*****************************************************************************#

FASTIDOUSINPUT=$(mktemp)
printf ">a_10\nACGT\n>b_2\nAGCT\n" > "${FASTIDOUSINPUT}"

## Swarm accepts the options -f and --fastidious
for OPTION in "-f" "--fastidious" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    "${SWARM}" "${OPTION}" < "${FASTIDOUSINPUT}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm performs a second clustering (aka fastidious)
DESCRIPTION="swarm performs a second clustering (-b 3)"
LINENUMBER=$("${SWARM}" -f "${FASTIDOUSINPUT}" 2> /dev/null | wc -l)
(( ${LINENUMBER} == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset LINENUMBER

## Boundary -------------------------------------------------------------------

## Swarm accepts the options -b and --boundary
for OPTION in "-b" "--boundary" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    "${SWARM}" -f "${OPTION}" 3 < "${FASTIDOUSINPUT}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Boundary (-b is empty)
DESCRIPTION="swarm aborts when --boundary is empty"
"${SWARM}" -f -b < "${FASTIDOUSINPUT}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Boundary (-b is negative)
DESCRIPTION="swarm aborts when --boundary is -1"
"${SWARM}" -f -b \-1 < "${FASTIDOUSINPUT}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Boundary (-b is non-numerical)
DESCRIPTION="swarm aborts when --boundary is not numerical"
"${SWARM}" -f -b "a" < "${FASTIDOUSINPUT}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Boundary (-b == 1)
DESCRIPTION="swarm aborts when --boundary is 1"
"${SWARM}" -f -b 1 < "${FASTIDOUSINPUT}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Accepted values for the boundary option are integers > 1
MIN=2
MAX=255
DESCRIPTION="swarm runs normally when --boundary goes from ${MIN} to ${MAX}"
for ((b=$MIN ; b<=$MAX ; b++)) ; do
    "${SWARM}" -f -b ${b} < "${FASTIDOUSINPUT}" &> /dev/null || \
        failure "swarm aborts when --boundary equals ${b}"
done && success "${DESCRIPTION}"
unset MIN MAX

## boundary option accepts large integers #1
DESCRIPTION="swarm accepts large values for --boundary (2^32)"
"${SWARM}" -f -b $(( 1 << 32 )) < "${FASTIDOUSINPUT}" &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## boundary option accepts large integers #2
DESCRIPTION="swarm accepts large values for --boundary (2^64, signed)"
"${SWARM}" -f -b $(((1 << 63) - 1)) < "${FASTIDOUSINPUT}" &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Boundary value is taken into account by the fastidious option (-b 2)
DESCRIPTION="boundary value is taken into account by the fastidious option (-b 2)"
LINENUMBER=$("${SWARM}" -f -b 2 < "${FASTIDOUSINPUT}" 2> /dev/null | wc -l)
(( ${LINENUMBER} == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset LINENUMBER

## Passing the --boundary option without the fastidious option should fail
DESCRIPTION="swarm fails when the boundary option is specified without -f"
"${SWARM}" -b 3 < "${FASTIDOUSINPUT}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


## Ceiling --------------------------------------------------------------------

## Swarm accepts the options -c and --ceiling
for OPTION in "-c" "--ceiling" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    "${SWARM}" -f "${OPTION}" 10 < "${FASTIDOUSINPUT}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Ceiling (-c is empty)
DESCRIPTION="swarm aborts when --ceiling is empty"
"${SWARM}" -f -c < "${FASTIDOUSINPUT}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Ceiling (-c is negative)
DESCRIPTION="swarm aborts when --ceiling is -1"
"${SWARM}" -f -c \-1 < "${FASTIDOUSINPUT}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Ceiling (-c is non-numerical)
DESCRIPTION="swarm aborts when --ceiling is not numerical"
"${SWARM}" -f -c "a" < "${FASTIDOUSINPUT}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Ceiling should fail when 0 <= c < 3
for ((c=0 ; c<3; c++)) ; do
    DESCRIPTION="swarm aborts when --ceiling is ${c}"
    "${SWARM}" -f -c ${c} < "${FASTIDOUSINPUT}" &> /dev/null && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
done
unset c

## ceiling option accepts positive integers
MIN=3
MAX=255
DESCRIPTION="swarm runs normally when --ceiling goes from 3 to ${MAX}"
for ((c=$MIN ; c<=$MAX ; c++)) ; do
    printf ">a_10\nACGT\n>b_2\nAGCT\n" | \
        "${SWARM}" -f -c ${c} &> /dev/null || \
        failure "swarm aborts when --ceiling equals ${c}"
done && success "${DESCRIPTION}"
unset MIN MAX c

## ceiling option accepts large integers
DESCRIPTION="swarm accepts large values for --ceiling (up to 2^30)"
"${SWARM}" -f -c $(( 1 << 30 )) < "${FASTIDOUSINPUT}" &> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## ceiling option rejects very large integers
DESCRIPTION="swarm rejects very large values for --ceiling (up to 2^32)"
"${SWARM}" -f -c $(( 1 << 32 )) < "${FASTIDOUSINPUT}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Passing the --ceiling option without the fastidious option should fail
DESCRIPTION="swarm fails when the ceiling option is specified without -f"
"${SWARM}" -c 10 < "${FASTIDOUSINPUT}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


## Bloom bits -----------------------------------------------------------------

## Swarm accepts the options -y and --bloom-bits
for OPTION in "-y" "--bloom-bits" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    "${SWARM}" -f "${OPTION}" 8 < "${FASTIDOUSINPUT}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Bloom bits (-y is empty)
DESCRIPTION="swarm aborts when --bloom-bits is empty"
"${SWARM}" -f -y < "${FASTIDOUSINPUT}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Bloom bits (-y is negative)
DESCRIPTION="swarm aborts when --bloom-bits is -1"
"${SWARM}" -f -y \-1 < "${FASTIDOUSINPUT}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Bloom bits (-y is non-numerical)
DESCRIPTION="swarm aborts when --bloom-bits is not numerical"
"${SWARM}" -f -y "a" < "${FASTIDOUSINPUT}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Accepted values for the --bloom-bits option goes from 2 to 64
MIN=2
MAX=64
DESCRIPTION="swarm runs normally when --bloom-bits goes from ${MIN} to ${MAX}"
for ((y=$MIN ; y<=$MAX ; y++)) ; do
    "${SWARM}" -f -y ${y} < "${FASTIDOUSINPUT}" &> /dev/null || \
        failure "swarm aborts when --bloom-bits equals ${y}"
done && success "${DESCRIPTION}"
unset MIN MAX

## Rejected values for the --bloom-bits option are < 2
DESCRIPTION="swarm aborts when --bloom-bits is lower than 2"
for y in 0 1 ; do
    "${SWARM}" -f -y ${y} < "${FASTIDOUSINPUT}" &> /dev/null && \
        failure "swarm runs normally when --bloom-bits equals ${y}"
done || success "${DESCRIPTION}"

## Rejected values for the --bloom-bits option goes from 65 to +infinite
MIN=65
MAX=255
DESCRIPTION="swarm aborts when --bloom-bits is higher than 64"
for ((y=$MIN ; y<=$MAX ; y++)) ; do
    "${SWARM}" -f -y ${y} < "${FASTIDOUSINPUT}" &> /dev/null && \
        failure "swarm runs normally when --bloom-bits equals ${y}"
done || success "${DESCRIPTION}"
unset MIN MAX

## Passing the --bloom-bits option without the fastidious option should fail
DESCRIPTION="swarm fails when the --bloom-bits option is specified without -f"
"${SWARM}" -y 16 < "${FASTIDOUSINPUT}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
rm "${FASTIDOUSINPUT}"


#*****************************************************************************#
#                                                                             #
#                            Input/Output options                             #
#                                                                             #
#*****************************************************************************#

## ----------------------------------------------------------- append-abundance

## Swarm accepts the options -a and --append-abundance
for OPTION in "-a" "--append-abundance" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    "${SWARM}" "${OPTION}" 2 < "${ALL_IDENTICAL}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm -a appends an abundance value to OTU members
OUTPUT=$(mktemp)
DESCRIPTION="-a appends an abundance number to OTU members (-o output)"
printf ">b\nACGT\n" | "${SWARM}" -a 2 -o "${OUTPUT}" &> /dev/null
ABUNDANCE=$(sed -n 's/.*_//p' "${OUTPUT}")
[[ "${ABUNDANCE}" == "2" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset ABUNDANCE

## Swarm append the abundance number set with -a for swarm notation
OUTPUT=$(mktemp)
DESCRIPTION="-a appends the abundance number (vsearch notation)"
printf ">a_3\nACGT\n>b\nACGT\n" | \
    "${SWARM}" -a 2 -w "${OUTPUT}" &> /dev/null
SUMABUNDANCES=$(sed -n '/^>/ s/.*_//p' "${OUTPUT}")
(( "${SUMABUNDANCES}" == 5 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset SUMABUNDANCE

## Swarm append the abundance number set with -a for usearch notation
OUTPUT=$(mktemp)
DESCRIPTION="-a appends the abundance number (usearch notation)"
printf ">a;size=3\nACGT\n>b\nACGT\n" | \
    "${SWARM}" -z -a 2 -w "${OUTPUT}" &> /dev/null
SUMABUNDANCES=$(awk -F "[;=]" '/^>/ {print $3}' "${OUTPUT}")
(( "${SUMABUNDANCES}" == 5 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset SUMABUNDANCE

## Swarm does not overwrite the abundance number with -a for swarm notation
OUTPUT=$(mktemp)
DESCRIPTION="-a does not overwrite the abundance number (swarm notation)"
printf ">b_3\nACGT\n" | "${SWARM}" -a 2 -w "${OUTPUT}" &> /dev/null
SUMABUNDANCES=$(sed -n '/^>/ s/.*_//p' "${OUTPUT}")
(( "${SUMABUNDANCES}" == 3 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset SUMABUNDANCE

## Swarm does not overwrite the abundance number with -a for usearch notation
OUTPUT=$(mktemp)
DESCRIPTION="-a does not overwrite the abundance number (usearch notation)"
printf ">b;size=3\nACGT\n" | "${SWARM}" -z -a 2 -w "${OUTPUT}" &> /dev/null
SUMABUNDANCES=$(awk -F "[;=]" '/^>/ {print $3}' "${OUTPUT}")
(( "${SUMABUNDANCES}" == 3 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset SUMABUNDANCE

## when using -a, check if the added abundance annotation appears in -o output
OUTPUT=$(mktemp)
DESCRIPTION="-a abundance annotation appears in -o output"
printf ">s1\nA\n" | "${SWARM}" -a 1 -o "${OUTPUT}" &> /dev/null
awk '{exit $1 == "s1_1" ? 0 : 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## when using -a, check if the added abundance annotation appears in -i output
OUTPUT=$(mktemp)
DESCRIPTION="-a abundance annotation appears in -i output"
printf ">s1_1\nA\n>s2\nT\n" | "${SWARM}" -a 1 -i "${OUTPUT}" &> /dev/null
awk '{exit $2 == "s2" ? 0 : 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## when using -a and -r, check if the added abundance annotation appears in -o output
OUTPUT=$(mktemp)
DESCRIPTION="-a abundance annotation appears in -o output when using -r"
printf ">s1_1\nA\n>s2\nT\n" | "${SWARM}" -a 1 -r -o "${OUTPUT}" &> /dev/null
grep -q "s2_1$" "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## when using -a, check if the added abundance annotation appears in -s output
OUTPUT=$(mktemp)
DESCRIPTION="-a abundance annotation appears in -s output"
printf ">s1\nA\n>s2_1\nT\n" | "${SWARM}" -a 2 -s "${OUTPUT}" &> /dev/null
awk '{exit $3 == "s1" ? 0 : 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## when using -a, check if the added abundance annotation appears in -u output
OUTPUT=$(mktemp)
DESCRIPTION="-a abundance annotation appears in -u output"
printf ">s1\nT\n>s2_1\nT\n" | "${SWARM}" -a 2 -u "${OUTPUT}" &> /dev/null
grep -q "s1_2" "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## when using -a, check if the added abundance annotation appears in -w output
OUTPUT=$(mktemp)
DESCRIPTION="-a abundance annotation appears in -w output"
printf ">s1\nT\n" | "${SWARM}" -a 1 -w "${OUTPUT}" &> /dev/null
grep -q "s1_1" "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


## --------------------------------------------------------- internal structure

## Swarm accepts the options -i and --internal-structure
for OPTION in "-i" "--internal-structure" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    "${SWARM}" "${OPTION}" /dev/null < "${ALL_IDENTICAL}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm -i fails if no output file given
DESCRIPTION="-i fails if no output file given"
"${SWARM}" -i  < "${ALL_IDENTICAL}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm -i create and fill given output file
OUTPUT=$(mktemp)
DESCRIPTION="-i creates and fill given output file"
"${SWARM}" --internal-structure "${OUTPUT}" < "${ALL_IDENTICAL}" &> /dev/null
[[ -s "${OUTPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## -i columns 1 and 2 contain sequence names
OUTPUT=$(mktemp)
DESCRIPTION="-i columns 1 and 2 contain sequence names"
printf ">a_1\nAAAA\n>b_1\nAAAA\n" | \
    "${SWARM}" -i "${OUTPUT}" &> /dev/null
awk '{exit ($1 == "a" && $2 == "b") ? 0 : 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## -i number of differences is correct (0 expected)
OUTPUT=$(mktemp)
DESCRIPTION="-i number of differences is correct (0 expected)"
printf ">a_1\nAAAA\n>b_1\nAAAA\n" | \
    "${SWARM}" -i "${OUTPUT}" &> /dev/null
NUMBER_OF_DIFFERENCES=$(awk -F "\t" '{print $3}' "${OUTPUT}")
(( "${NUMBER_OF_DIFFERENCES}" == 0 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_DIFFERENCES

## -i number of differences is correct when -d 2 (2 expected)
OUTPUT=$(mktemp)
DESCRIPTION="-i number of differences is correct when -d 2 (2 expected)"
printf ">a_1\nAAAA\n>b_1\nAACC\n" | \
    "${SWARM}" -d 2 -i "${OUTPUT}" &> /dev/null
NUMBER_OF_DIFFERENCES=$(awk -F "\t" '{print $3}' "${OUTPUT}")
(( "${NUMBER_OF_DIFFERENCES}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_DIFFERENCES

## -i number of differences is correct while -d 2 (1 expected)
OUTPUT=$(mktemp)
DESCRIPTION="-i number of differences is correct while -d 2 (1 expected)"
printf ">a_1\nAAAA\n>b_1\nAAAC\n" | \
    "${SWARM}" -d 2 -i "${OUTPUT}" &> /dev/null
NUMBER_OF_DIFFERENCES=$(awk -F "\t" '{print $3}' "${OUTPUT}")
(( "${NUMBER_OF_DIFFERENCES}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_DIFFERENCES

## -i number of the OTU is correct #1
OUTPUT=$(mktemp)
DESCRIPTION="-i number of the OTU is correct #1"
printf ">a_1\nAAAA\n>b_1\nAAAC\n" | \
    "${SWARM}" -i "${OUTPUT}" &> /dev/null
NUMBER_OF_OTUs=$(awk -F "\t" '{print $4}' "${OUTPUT}")
(( "${NUMBER_OF_OTUs}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_OTUs

## -i number of the OTU is correct #2
OUTPUT=$(mktemp)
DESCRIPTION="-i number of the OTU is correct #2"
printf ">a_1\nAA\n>b_1\nAC\n>c_1\nGG\n>d_1\nGT\n" | \
    "${SWARM}" -i "${OUTPUT}" &> /dev/null
NUMBER_OF_OTUs=$(awk '{n = $4} END {print n}' "${OUTPUT}")
(( "${NUMBER_OF_OTUs}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_OTUs

## -i number of steps is correct (1 expected)
OUTPUT=$(mktemp)
DESCRIPTION="-i number of steps is correct (1 expected)"
printf ">a_1\nAAAA\n>b_1\nAAAC\n" | \
    "${SWARM}" -i "${OUTPUT}" &> /dev/null
NUMBER_OF_STEPS=$(awk -F "\t" '{print $5}' "${OUTPUT}")
(( "${NUMBER_OF_STEPS}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_STEPS

## -i number of steps is correct (3 expected)
OUTPUT=$(mktemp)
DESCRIPTION="-i number of steps is correct (3 expected)"
printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nAACC\n>d_1\nACCC\n" | \
    "${SWARM}" -i "${OUTPUT}" &> /dev/null
NUMBER_OF_STEPS=$(awk -F "\t" '{print $5}' "${OUTPUT}" | sed '3q;d' )
(( "${NUMBER_OF_STEPS}" == 3 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_STEPS

## -i number of steps is correct while -d 2 (1 expected)
OUTPUT=$(mktemp)
DESCRIPTION="-i number of steps is correct while -d 2 (1 expected)"
printf ">a_1\nAAAA\n>c_1\nAACC\n" | \
    "${SWARM}" -d 2 -i "${OUTPUT}" &> /dev/null
NUMBER_OF_STEPS=$(awk -F "\t" '{print $5}' "${OUTPUT}" )
(( "${NUMBER_OF_STEPS}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_STEPS

## -i number of steps is correct while -d 2 (2 expected)
OUTPUT=$(mktemp)
DESCRIPTION="-i number of steps is correct while -d 2 (2 expected)"
printf ">a_1\nAAAA\n>b_1\nAACC\n>c_1\nACCC\n" | \
    "${SWARM}" -d 2 -i "${OUTPUT}" &> /dev/null
NUMBER_OF_STEPS=$(awk -F "\t" 'NR == 2 {print $5}' "${OUTPUT}")
(( "${NUMBER_OF_STEPS}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_STEPS

## -i -f OTU numbering is updated (2nd line, col. 4 should be 1)
# a	b	1	1	1
# b	c	2	1	2
# c	d	1	1	1
DESCRIPTION="-i -f OTU numbering is updated"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_1\nATTT\n>d_1\nTTTT\n" | \
    "${SWARM}" -f -i "${OUTPUT}" &> /dev/null
awk 'NR == 2 {exit $4 == 1 ? 0 : 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## -i -f OTU numbering is contiguous (no gap) (4th line, col. 4 should be 2)
# a	b	1	1	1
# b	c	2	1	2
# c	d	1	1	1
# e	f	1	2	1
DESCRIPTION="-i -f OTU numbering is contiguous (no gap)"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_1\nATTT\n>d_1\nTTTT\n>e_1\nGGGG\n>f_1\nGGGA\n" | \
    "${SWARM}" -f -i "${OUTPUT}" &> /dev/null
awk 'NR == 4 {exit $4 == 2 ? 0 : 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

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
DESCRIPTION="-i -f number of steps between grafted amplicon and its new seed is not updated"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_2\nTTTT\n>d_1\nATTT\n" | \
    "${SWARM}" -f -b 4 -i "${OUTPUT}" &> /dev/null
awk 'NR == 3 {exit $5 == 1 ? 0 : 1}' "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


## ------------------------------------------------------------------------ log

## Swarm accepts the options -l and --log
for OPTION in "-l" "--log" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    "${SWARM}" "${OPTION}" /dev/null < "${ALL_IDENTICAL}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm does not write on standard error when using -l
ERRORINPUT=$(mktemp)
DESCRIPTION="-l writes on standard error"
"${SWARM}" -l /dev/null < "${ALL_IDENTICAL}" > /dev/null 2> "${ERRORINPUT}"
[[ ! -s "${ERRORINPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${ERRORINPUT}"

## Swarm does write on standard error when using -l, except for errors
ERRORINPUT=$(mktemp)
DESCRIPTION="-l writes on standard error, except for errors"
# voluntary error (missing d value) to create an error message
"${SWARM}" -d -l /dev/null < "${ALL_IDENTICAL}" &> "${ERRORINPUT}"
[[ -s "${ERRORINPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${ERRORINPUT}"

## ---------------------------------------------------------------- output-file

## Swarm accepts the options -o and --output-file
for OPTION in "-o" "--output-file" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    "${SWARM}" "${OPTION}" /dev/null < "${ALL_IDENTICAL}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm creates output file with -o option
OUTPUT=$(mktemp)
DESCRIPTION="-o writes to the specified output file"
"${SWARM}" -o  "${OUTPUT}" < "${ALL_IDENTICAL}" &> /dev/null
[[ -s "${OUTPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm fills correctly output file with -o option
OUTPUT=$(mktemp)
DESCRIPTION="-o creates and fills the output file"
"${SWARM}" -o  "${OUTPUT}" < "${ALL_IDENTICAL}" &> /dev/null
EXPECTED=$(sed -n '/^>/ s/>//p' "${ALL_IDENTICAL}" | tr "\n" " " | sed 's/ $//')
[[ $(< "${OUTPUT}") == "${EXPECTED}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset EXPECTED


## --------------------------------------------------------------------- mothur

## Swarm accepts the options -r and --mothur
for OPTION in "-r" "--mothur" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    "${SWARM}" "${OPTION}" < "${ALL_IDENTICAL}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## -r first row is correct
DESCRIPTION="-r first row is correct"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n" | "${SWARM}" -r  > "${OUTPUT}" 2> /dev/null
FIRST_ROW=$(awk -F "\t" '{print $1}' "${OUTPUT}")
[[ "${FIRST_ROW}" == "swarm_1" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset FIRST_ROW

## -r first row is correct with -d 2
DESCRIPTION="-r first row is correct with -d 2"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n" | "${SWARM}" -r -d 2 > "${OUTPUT}" 2> /dev/null
FIRST_ROW=$(awk -F "\t" '{print $1}' "${OUTPUT}")
[[ "${FIRST_ROW}" == "swarm_2" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset FIRST_ROW

## -r number of OTUs is correct (1 expected)
DESCRIPTION="-r number of OTUs is correct (1 expected)"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n" | "${SWARM}" -r -d 2 > "${OUTPUT}" 2> /dev/null
NUMBER_OF_OTUs=$(awk -F "\t" '{print $2}' "${OUTPUT}")
(( "${NUMBER_OF_OTUs}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_OTUs

## -r number of OTUs is correct (2 expected)
DESCRIPTION="-r number of OTUs is correct (2 expected)"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n>b_5\nAAAA\n>c_5\nAACC\n" | \
    "${SWARM}" -r > "${OUTPUT}" 2> /dev/null
NUMBER_OF_OTUs=$(awk -F "\t" '{print $2}' "${OUTPUT}")
(( "${NUMBER_OF_OTUs}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_OTUs

## -r number of fields is correct (4 fields expected)
DESCRIPTION="-r number of fields is correct (4 fields expected)"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n>b_5\nAAAA\n>c_5\nAACC\n" | \
    "${SWARM}" -r > "${OUTPUT}" 2> /dev/null
NUMBER_OF_FIELDS=$(awk -F "\t" '{print NF}' "${OUTPUT}")
(( "${NUMBER_OF_FIELDS}" == 4 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_FIELDS

## -r composition of OTUs is correct #1
DESCRIPTION="-r composition of OTUs is correct #1"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n>b_5\nAAAA\n>c_5\nAACC\n" | \
    "${SWARM}" -r > "${OUTPUT}" 2> /dev/null
OTU=$(awk -F "\t" '{print $3}' "${OUTPUT}")
[[ "${OTU}" == "a_5,b_5" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset OTU

## -r composition of OTUs is correct #2
DESCRIPTION="-r composition of OTUs is correct #2"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n>b_5\nACCC\n>c_5\nAAAC\n" | \
    "${SWARM}" -r > "${OUTPUT}" 2> /dev/null
OTU=$(awk -F "\t" '{print $3}' "${OUTPUT}")
[[ "${OTU}" == "a_5,c_5" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## -r composition of OTUs is correct #3
DESCRIPTION="-r composition of OTUs is correct #3"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n>b_5\nACCC\n>c_5\nAACC\n" | \
    "${SWARM}" -r > "${OUTPUT}" 2> /dev/null
OTU=$(awk -F "\t" '{print $3}' "${OUTPUT}")
[[ "${OTU}" == "a_5" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset OTU

## -r composition of OTUs is correct with -a 2 #1
DESCRIPTION="-r composition of OTUs is correct with -a 2 #1"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n>b\nAAAC\n>c\nACCC\n" | \
    "${SWARM}" -r -a 2 > "${OUTPUT}" 2> /dev/null
OTU=$(awk -F "\t" '{print $3}' "${OUTPUT}")
[[ "${OTU}" == "a_5,b_2" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset OTU

## -r composition of OTUs is correct with -a 2 #2
DESCRIPTION="-r composition of OTUs is correct with -a 2 #2"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n>b\nACCC\n>c\nAAAC\n" | \
    "${SWARM}" -r -a 2 > "${OUTPUT}" 2> /dev/null
OTU=$(awk -F "\t" '{print $3}' "${OUTPUT}")
[[ "${OTU}" == "a_5,c_2" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset OTU

## -r composition of OTUs is correct with -z
DESCRIPTION="-r composition of OTUs is correct with -z"
OUTPUT=$(mktemp)
printf ">a;size=5\nAAAA\n>b;size=4\nAAAC\n>c;size=5\nACCC\n" | \
    "${SWARM}" -r -z > "${OUTPUT}" 2> /dev/null
OTU=$(awk -F "\t" '{print $3}' "${OUTPUT}")
[[ "${OTU}" == "a;size=5,b;size=4" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset OTU

## -r composition of OTUs is correct with -z -a 2 #1
DESCRIPTION="-r composition of OTUs is correct with -z -a 2 #1"
OUTPUT=$(mktemp)
printf ">a;size=5;\nAAAA\n>b\nAAAC\n>c\nACCC\n" | \
    "${SWARM}" -z -r -a 2 > "${OUTPUT}" 2> /dev/null
OTU=$(awk -F "\t" '{print $3}' "${OUTPUT}")
[[ "${OTU}" == "a;size=5;,b;size=2;" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset OTU

## -r composition of OTUs is correct with -z -a 2 #2
DESCRIPTION="-r composition of OTUs is correct with -z -a 2 #2"
OUTPUT=$(mktemp)
printf ">a;size=5\nAAAA\n>b\nACCC\n>c\nAAAC\n" | \
    "${SWARM}" -z -r -a 2 > "${OUTPUT}" 2> /dev/null
OTU=$(awk -F "\t" '{print $3}' "${OUTPUT}")
[[ "${OTU}" == "a;size=5,c;size=2;" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset OTU

## ------------------------------------------------------------ statistics-file

## Swarm accepts the options -s and --statistics-file
for OPTION in "-s" "--statistics-file" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    "${SWARM}" "${OPTION}" /dev/null < "${ALL_IDENTICAL}" &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm -s create and fill given filename
DESCRIPTION="-s create and fill filename given"
OUTPUT=$(mktemp)
"${SWARM}" -s "${OUTPUT}" < "${ALL_IDENTICAL}" &> /dev/null
[[ -s "${OUTPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm -s fails if no filename given
DESCRIPTION="-s fails if no filename given"
"${SWARM}" -s  < "${ALL_IDENTICAL}" &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of unique amplicons is correct with -s (1 expected)
DESCRIPTION="-s number of unique amplicons is correct (1 expected)"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n" | "${SWARM}" -s "${OUTPUT}" &> /dev/null
UNIQUE_AMPLICONS=$(awk -F "\t" '{print $1}' "${OUTPUT}")
(( "${UNIQUE_AMPLICONS}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset UNIQUE_AMPLICONS

## Number of unique amplicons is correct with -s (2 expected)
DESCRIPTION="-s number of unique amplicons is correct (2 expected)"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n>b_1\nAAAC\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
UNIQUE_AMPLICONS=$(awk -F "\t" '{print $1}' "${OUTPUT}")
(( "${UNIQUE_AMPLICONS}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset UNIQUE_AMPLICONS

## Number of unique amplicons is still correct with -s (2 expected)
DESCRIPTION="-s number of unique amplicons is still correct (2 expected)"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n>b_5\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
UNIQUE_AMPLICONS=$(awk -F "\t" 'NR == 1 {print $1}' "${OUTPUT}")
(( "${UNIQUE_AMPLICONS}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset UNIQUE_AMPLICONS

## Total abundance of amplicons is correct with -s (1 expected)
DESCRIPTION="-s total abundance of amplicons is correct (1 expected)"
OUTPUT=$(mktemp)
printf ">a_1\nAAAA\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
TOTAL_ABUNDANCE=$(awk -F "\t" '{print $2}' "${OUTPUT}")
(( "${TOTAL_ABUNDANCE}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset TOTAL_ABUNDANCE

## Total abundance of amplicons is correct with -s (5 expected)
DESCRIPTION="-s total abundance of amplicons is correct (5 expected)"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
TOTAL_ABUNDANCE=$(awk -F "\t" 'NR == 1 {print $2}' "${OUTPUT}")
(( "${TOTAL_ABUNDANCE}" == 5 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset TOTAL_ABUNDANCE

## Total abundance of amplicons is still correct with -s (5 expected)
DESCRIPTION="-s total abundance of amplicons is still correct (5 expected)"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
TOTAL_ABUNDANCE=$(awk -F "\t" 'NR == 1 {print $2}' "${OUTPUT}")
(( "${TOTAL_ABUNDANCE}" == 5 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset TOTAL_ABUNDANCE

## Id of initial seed is correct with -s
DESCRIPTION="-s ID of initial seed is correct"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
SEED_ID=$(awk -F "\t" 'NR == 1 {print $3}' "${OUTPUT}")
[[ "${SEED_ID}" == "a" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset SEED_ID

## Id of initial seed is still correct with -s
DESCRIPTION="-s ID of initial seed is still correct"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
SEED_ID=$(awk -F "\t" 'NR == 2 {print $3}' "${OUTPUT}")
[[ "${SEED_ID}" == "c" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset SEED_ID

## Abundance of initial seed is correct with -s
DESCRIPTION="-s abundance of initial seed is correct"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
SEED_ABUNDANCE=$(awk -F "\t" 'NR == 1 {print $4}' "${OUTPUT}")
(( "${SEED_ABUNDANCE}" == 3 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset SEED_ABUNDANCE

## Abundance of initial seed is still correct with -s
DESCRIPTION="-s abundance of initial seed is still correct"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
SEED_ABUNDANCE=$(awk -F "\t" 'NR == 2 {print $4}' "${OUTPUT}")
(( "${SEED_ABUNDANCE}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset SEED_ABUNDANCE

## Number of amplicons with an abundance of 1 is correct with -s (0 exp)
DESCRIPTION="-s number of amplicons with an abundance of 1 is correct (0 expected)"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
NUMBER_OF_AMPLICONS=$(awk -F "\t" 'NR == 1 {print $5}' "${OUTPUT}")
(( "${NUMBER_OF_AMPLICONS}" == 0 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_AMPLICONS

## Number of amplicons with an abundance of 1 is correct with -s (1 exp)
DESCRIPTION="-s number of amplicons with an abundance of 1 is correct (1 expected)"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
NUMBER_OF_AMPLICONS=$(awk -F "\t" 'NR == 2 {print $5}' "${OUTPUT}")
(( "${NUMBER_OF_AMPLICONS}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_AMPLICONS

## Number of iterations is correct with -s (0 expected)
DESCRIPTION="-s number of iterations is correct (0 expected)"
OUTPUT=$(mktemp)
printf ">a_2\nAAAA\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
NUMBER_OF_ITERATIONS=$(awk -F "\t" 'NR == 1 {print $6}' "${OUTPUT}")
(( "${NUMBER_OF_ITERATIONS}" == 0 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_ITERATIONS

## Number of iterations is correct with -s -d 2 (1 expected)
DESCRIPTION="-s number of iterations is correct (1 expected)"
OUTPUT=$(mktemp)
printf ">a_2\nAAAA\n>c_1\nAACC\n" | \
    "${SWARM}" -d 2 -s "${OUTPUT}" &> /dev/null
NUMBER_OF_ITERATIONS=$(awk -F "\t" 'NR == 1 {print $6}' "${OUTPUT}")
(( "${NUMBER_OF_ITERATIONS}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_ITERATIONS

## Number of iterations is correct with -s -d 2 (2 expected)
DESCRIPTION="-s number of iterations is correct (2 expected)"
OUTPUT=$(mktemp)
printf ">a_2\nAAAA\n>b_2\nAAAC\n>c_1\nACCC\n" | \
    "${SWARM}" -d 2 -s "${OUTPUT}" &> /dev/null
NUMBER_OF_ITERATIONS=$(awk -F "\t" 'NR == 1 {print $6}' "${OUTPUT}")
(( "${NUMBER_OF_ITERATIONS}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_ITERATIONS

## Theorical radius is correct with -s (0 expected)
DESCRIPTION="-s theorical maximum radius is correct (0 expected)"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
THEORICAL_RADIUS=$(awk -F "\t" 'NR == 1 {print $7}' "${OUTPUT}")
(( "${THEORICAL_RADIUS}" == 0 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset THEORICAL_RADIUS

## Theorical radius is correct with -s (2 expected)
DESCRIPTION="-s theorical maximum radius is correct (2 expected)"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nAACC\n" | \
    "${SWARM}" -s "${OUTPUT}" &> /dev/null
THEORICAL_RADIUS=$(awk -F "\t" 'NR == 1 {print $7}' "${OUTPUT}")
(( "${THEORICAL_RADIUS}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset THEORICAL_RADIUS

## Theorical radius is correct with -s -d 2 (2 expected)
DESCRIPTION="-s theorical maximum radius is correct -d 2 (2 expected)"
OUTPUT=$(mktemp)
printf ">a_2\nAAAA\n>c_1\nAACC\n" | \
    "${SWARM}" -d 2 -s "${OUTPUT}" &> /dev/null
THEORICAL_RADIUS=$(awk -F "\t" 'NR == 1 {print $7}' "${OUTPUT}")
(( "${THEORICAL_RADIUS}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset THEORICAL_RADIUS

## Theorical radius != actuel radius  with -s -d 2
DESCRIPTION="-s theorical radius != actuel radius -d 2"
OUTPUT=$(mktemp)
printf ">a_3\nAAAAA\n>b_3\nAAACC\n>c_2\nACCCC\n>d_2\nACCAC\n" | \
    "${SWARM}" -d 2 -s "${OUTPUT}" &> /dev/null
THEORICAL_RADIUS=$(awk -F "\t" 'NR == 1 {print $7}' "${OUTPUT}")
(( "${THEORICAL_RADIUS}" == 5 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset THEORICAL_RADIUS


## ---------------------------------------------------------------- uclust-file

## Swarm accepts the options -u and --uclust-file
for OPTION in "-u" "--uclust-file" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nGGGG" | \
        "${SWARM}" "${OPTION}" /dev/null &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## Swarm -u fails if no output file given
DESCRIPTION="-u fails if no output file given"
printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nGGGG" | \
    "${SWARM}" -u &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm -u creates and fills file given as argument
OUTPUT=$(mktemp)
DESCRIPTION="-u creates and fills file given in argument"
printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nGGGG" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
[[ -s "${OUTPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"  

## -u number of hits is correct in 1st column #1
DESCRIPTION="-u number of hits is correct in the first column #1"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
NUMBER_OF_HITS=$(grep -c "^H" "${OUTPUT}")
(( "${NUMBER_OF_HITS}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_HITS

## -u number of hits is correct in 1st column #2
DESCRIPTION="-u number of hits is correct in the first column #2"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n>b_3\nAAAA\n>c_3\nAAAC\n>d_3\nAACC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
NUMBER_OF_HITS=$(grep -c "^H" "${OUTPUT}")
(( "${NUMBER_OF_HITS}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_HITS

## -u number of centroids is correct in 1st column #1
DESCRIPTION="-u number of centroids is correct in the first column #1"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n>b_3\nAAAA\n>c_3\nAAAC\n>d_3\nAACC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
NUMBER_OF_CENTROIDS=$(grep -c "^S" "${OUTPUT}")
(( "${NUMBER_OF_CENTROIDS}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_CENTROIDS

## -u number of centroids is correct in 1st column #2
DESCRIPTION="-u number of centroids is correct in the first column #2"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
NUMBER_OF_CENTROIDS=$(grep -c "^S" "${OUTPUT}")
(( "${NUMBER_OF_CENTROIDS}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_CENTROIDS

## -u number of cluster records is correct in the first column #1
DESCRIPTION="-u number of cluster records is correct in the first column #1"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n>b_3\nAAAA\n>c_3\nAAAC\n>d_3\nAACC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
NUMBER_OF_CLUSTERS=$(grep -c "^C" "${OUTPUT}")
(( "${NUMBER_OF_CLUSTERS}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_CLUSTERS

## -u number of cluster records is correct in the first column #2
DESCRIPTION="-u number of cluster records is correct in the first column #2"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
NUMBER_OF_CLUSTERS=$(grep -c "^C" "${OUTPUT}")
(( "${NUMBER_OF_CLUSTERS}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset NUMBER_OF_CLUSTERS

## -u cluster number is correct in 2nd column #1
DESCRIPTION="-u cluster number is correct in 2nd column #1"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CLUSTER_NUMBER=$(awk '/^C/ {v = $2} END {print v}' "${OUTPUT}")
(( "${CLUSTER_NUMBER}" == 0 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CLUSTER_NUMBER

## -u cluster number is correct in 2nd column #2
DESCRIPTION="-u cluster number is correct in 2nd column #2"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n>b_3\nAAAA\n>c_3\nAAAC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CLUSTER_NUMBER=$(awk '/^C/ {v = $2} END {print v}' "${OUTPUT}")
(( "${CLUSTER_NUMBER}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CLUSTER_NUMBER

## -u cluster size is correct in 3rd column #1
DESCRIPTION="-u cluster number is correct in 3rd column #1"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n>b_3\nAAAA\n>c_3\nAAAC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CLUSTER_SIZE=$(awk '/^C/ {v = $3} END {print v}' "${OUTPUT}")
(( "${CLUSTER_SIZE}" == 2 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CLUSTER_SIZE

## -u cluster size is correct in 3rd column #2
DESCRIPTION="-u cluster number is correct in 3rd column #2"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n>b_3\nAAAA\n>c_3\nAAAC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CLUSTER_SIZE=$(grep "^C" "${OUTPUT}" | \
               awk -F "\t" '{if (NR == 2) {print $2}}')
[[ "${CLUSTER_SIZE}" == "1" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CLUSTER_SIZE

## -u centroid length is correct in 3rd column #1
DESCRIPTION="-u centroid length is correct in 3rd column #1"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CENTROID_LENGTH=$(awk '/^S/ {v = $3} END {print v}' "${OUTPUT}")
(( "${CENTROID_LENGTH}" == 4 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTIONz}"
rm "${OUTPUT}"
unset CENTROIS_LENGTH

## -u centroid length is correct in 3rd column #2
DESCRIPTION="-u centroid length is correct in 3rd column #2"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n>b_3\nA\n>c_3\nC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CENTROID_LENGTH=$(awk '/^S/ {v = $3} END {print v}' "${OUTPUT}")
[[ "${CENTROID_LENGTH}" == "1" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CENTROIS_LENGTH

## -u query length is correct in 3rd column #1
DESCRIPTION="-u query length is correct in 3rd column #1"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n>b_3\nAA\n>c_3\nAAA\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
QUERY_LENGTH=$(awk '/^H/ {if (NR == 5) {print $3}}' "${OUTPUT}")
[[ "${QUERY_LENGTH}" == "3" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset QUERY_LENGTH

## -u query length is correct in 3rd column #2
DESCRIPTION="-u query length is correct in 3rd column #2"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n>b_3\nA\n>c_3\nA\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
QUERY_LENGTH=$(awk '/^H/ {v = $3} END {print v}' "${OUTPUT}")
(( "${QUERY_LENGTH}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset QUERY_LENGTH

## -u similarity percentage is correct in 4th column #1
DESCRIPTION="-u similarity percentage is correct in 4th column #1"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n>b_3\nAAAA\n>c_3\nAAAC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
SIMILARITY_PERCENTAGE=$(awk '/^H/ {v = $4} END {print v}' "${OUTPUT}")
[[ "${SIMILARITY_PERCENTAGE}" == "75.0" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset SIMILARITY_PERCENTAGE

## Sequence "a" and sequence "e" should be grouped inside the same
## OTU, with a similarity of 0.0 between "a" and "e". Note that
## sequences are now automatically sorted by fasta identifier to break
## abundance ties.
DESCRIPTION="-u similarity percentage is correct in 4th column #2"
SIMILARITY_PERCENTAGE=$(\
    printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_3\nAACC\n>d_3\nACCC\n>e_3\nCCCC\n" | \
        "${SWARM}" -o /dev/null -u - 2> /dev/null | \
        awk '/^H/ {v = $4} END {print v}')
[[ "${SIMILARITY_PERCENTAGE}" == "0.0" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset SIMILARITY_PERCENTAGE

## -u similarity percentage is correct in 4th column #3
DESCRIPTION="-u similarity percentage is correct in 4th column #3"
OUTPUT=$(mktemp)
printf ">a_3\nAAAAAAAA\n>b_3\nAAAAAAAC\n>c_3\nAAAAAACC\n>d_3\nAAAAACCC\n>e_3\nAAAACCCC\n>f_3\nAAACCCCC\n>g_3\nAACCCCCC\n>h_3\nACCCCCCC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
SIMILARITY_PERCENTAGE=$(awk '/^H/ {v = $4} END {print v}' "${OUTPUT}")
[[ "${SIMILARITY_PERCENTAGE}" == "12.5" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset SIMILARITY_PERCENTAGE

## -u similarity percentage is * in 4th column with S
DESCRIPTION="-u similarity percentage is * in 4th column with S"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n>b_3\nAAAA\n>c_3\nAAAC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
SIMILARITY_PERCENTAGE=$(grep "^S" "${OUTPUT}" | \
               awk -F "\t" '{if (NR == 1) {print $4}}')
[[ "${SIMILARITY_PERCENTAGE}" == "*" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset SIMILARITY_PERCENTAGE

## -u match orientation is correct in 5th column with H
DESCRIPTION="-u match orientation is correct in 5th column with H"
OUTPUT=$(mktemp)
printf ">a_3\nGGGG\n>b_3\nAAAA\n>c_3\nAAAC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
MATCH_ORIENTATION=$(awk '/^H/ {v = $5} END {print v}' "${OUTPUT}")
[[ "${MATCH_ORIENTATION}" == "+" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset MATCH_ORIENTATION

## -u match orientation is * in 5th column with S
DESCRIPTION="-u match orientation is correct in 5th column with S"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_3\nAACC\n>d_3\nAGCC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
MATCH_ORIENTATION=$(awk '/^S/ {v = $5} END {print v}' "${OUTPUT}")
[[ "${MATCH_ORIENTATION}" == "*" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset MATCH_ORIENTATION

## -u match orientation is * in 5th column with C
DESCRIPTION="-u match orientation is correct in 5th column with C"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_3\nAACC\n>d_3\nAGCC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
MATCH_ORIENTATION=$(awk '/^C/ {v = $5} END {print v}' "${OUTPUT}")
[[ "${MATCH_ORIENTATION}" == "*" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset MATCH_ORIENTATION

## -u 6th column is * with C
DESCRIPTION="-u 6th column is * with C"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_3\nAACC\n>d_3\nAGCC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
COLUMN_6=$(awk '/^C/ {v = $6} END {print v}' "${OUTPUT}")
[[ "${COLUMN_6}" == "*" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset COLUMN_6

## -u 6th column is * with S
DESCRIPTION="-u 6th column is * with S"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_3\nAACC\n>d_3\nAGCC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
COLUMN_6=$(awk '/^S/ {v = $6} END {print v}' "${OUTPUT}")
[[ "${COLUMN_6}" == "*" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset COLUMN_6

## -u 6th column is 0 with H
DESCRIPTION="-u 6th column is 0 with H"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_3\nAACC\n>d_3\nAGCC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
COLUMN_6=$(awk '/^H/ {v = $6} END {print v}' "${OUTPUT}")
(( "${COLUMN_6}" == 0 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset COLUMN_6

## -u 7th column is * with C
DESCRIPTION="-u 7th column is * with C"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_3\nAACC\n>d_3\nAGCC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
COLUMN_7=$(awk '/^C/ {v = $7} END {print v}' "${OUTPUT}")
[[ "${COLUMN_7}" == "*" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset COLUMN_7

## -u 7th column is * with S
DESCRIPTION="-u 7th column is * with S"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_3\nAACC\n>d_3\nAGCC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
COLUMN_7=$(grep "^S" "${OUTPUT}" | \
                  awk -F "\t" '{if (NR == 1) {print $7}}')
[[ "${COLUMN_7}" == "*" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset COLUMN_7

## -u 7th column is 0 with H
DESCRIPTION="-u 7th column is 0 with H"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_3\nAACC\n>d_3\nAGCC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
COLUMN_7=$(awk '/^H/ {v = $7} END {print v}' "${OUTPUT}")
[[ "${COLUMN_7}" == "0" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset COLUMN_7

## -u CIGAR is * with S
DESCRIPTION="-u CIGAR is * with S"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_3\nAACC\n>d_3\nAGCC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CIGAR=$(awk '/^S/ {v = $8} END {print v}' "${OUTPUT}")
[[ "${CIGAR}" == "*" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CIGAR

## -u CIGAR is * with C
DESCRIPTION="-u CIGAR is * with C"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_3\nAACC\n>d_3\nAGCC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CIGAR=$(awk '/^C/ {v = $8} END {print v}' "${OUTPUT}")
[[ "${CIGAR}" == "*" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CIGAR

## -u CIGAR notation is correct in 8th column is with H #1
DESCRIPTION="-u CIGAR notation is correct in 8th column is with H #1"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CIGAR=$(awk '/^H/ {v = $8} END {print v}' "${OUTPUT}")
[[ "${CIGAR}" == "4M" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CIGAR

## -u CIGAR notation is correct in 8th column is with H #2
DESCRIPTION="-u CIGAR notation is correct in 8th column is with H #2"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAA\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CIGAR=$(awk '/^H/ {v = $8} END {print v}' "${OUTPUT}")
[[ "${CIGAR}" == "D3M" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CIGAR

## -u CIGAR notation is correct in 8th column is with H #3
DESCRIPTION="-u CIGAR notation is correct in 8th column is with H #3"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAAA\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CIGAR=$(awk '/^H/ {v = $8} END {print v}' "${OUTPUT}")
[[ "${CIGAR}" == "4MI" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CIGAR

## -u CIGAR notation is correct in 8th column is with H #4
DESCRIPTION="-u CIGAR notation is correct in 8th column is with H #4"
OUTPUT=$(mktemp)
printf ">a_3\nACGT\n>b_3\nACGT\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CIGAR=$(awk '/^H/ {v = $8} END {print v}' "${OUTPUT}")
[[ "${CIGAR}" == "=" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CIGAR

## -u CIGAR notation is correct in 8th column is with H using -d 5 #1
DESCRIPTION="-u CIGAR notation is correct in 8th column is with H using -d 5 #1"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nACGT\n" | \
    "${SWARM}" -d 5 -u "${OUTPUT}" &> /dev/null
CIGAR=$(awk '/^H/ {v = $8} END {print v}' "${OUTPUT}")
[[ "${CIGAR}" == "4M" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CIGAR

## -u CIGAR notation is correct in 8th column is with H using -d 5 #2
DESCRIPTION="-u CIGAR notation is correct in 8th column is with H using -d 5 #2"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nCG\n" | \
    "${SWARM}" -d 5 -u "${OUTPUT}" &> /dev/null
CIGAR=$(awk '/^H/ {v = $8} END {print v}' "${OUTPUT}")
[[ "${CIGAR}" == "2D2M" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CIGAR

## -u CIGAR notation is correct in 8th column is with H using -d 5 #3
DESCRIPTION="-u CIGAR notation is correct in 8th column is with H using -d 5 #3"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nACGTTT\n" | \
    "${SWARM}" -d 5 -u "${OUTPUT}" &> /dev/null
CIGAR=$(awk '/^H/ {v = $8} END {print v}' "${OUTPUT}")
[[ "${CIGAR}" == "4M2I" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CIGAR

## -u query sequence's label is correct in 9th column with H #1
DESCRIPTION="-u query sequence's label is correct in 9th column with H #1"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
QUERY_LABEL=$(awk '/^H/ {v = $9} END {print v}' "${OUTPUT}")
[[ "${QUERY_LABEL}" == "b_3" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset QUERY_LABEL

## -u query sequence's label is correct in 9th column with H #2
DESCRIPTION="-u query sequence's label is correct in 9th column with H #2"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_1\nAACC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
QUERY_LABEL=$(awk '/^H/ {v = $9} END {print v}' "${OUTPUT}")
[[ "${QUERY_LABEL}" == "c_1" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset QUERY_LABEL

## -u centroid sequence's label is correct in 9th column with S #1
DESCRIPTION="-u centroid sequence's label is correct in 9th column with S #1"
OUTPUT=$(mktemp)
printf ">a_2\nGGGG\n>b_3\nAAAA\n>c_2\nAAAC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CENTROID_LABEL=$(awk '/^S/ {v = $9} END {print v}' "${OUTPUT}")
[[ "${CENTROID_LABEL}" == "a_2" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CENTROID_LABEL

## -u centroid sequence's label is correct in 9th column with S #2
DESCRIPTION="-u centroid sequence's label is correct in 9th column with S #2"
OUTPUT=$(mktemp)
printf ">a_2\nAAAA\n>b_3\nAAAC\n>c_1\nAACC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CENTROID_LABEL=$(awk '/^S/ {v = $9} END {print v}' "${OUTPUT}")
[[ "${CENTROID_LABEL}" == "b_3" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CENTROID_LABEL

## -u centroid sequence's label is correct in 9th column with C #1
DESCRIPTION="-u centroid sequence's label is correct in 9th column with C #1"
OUTPUT=$(mktemp)
printf ">a_2\nGGGG\n>b_3\nAAAA\n>c_2\nAAAC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CENTROID_LABEL=$(awk '/^C/ {v = $9} END {print v}' "${OUTPUT}")
[[ "${CENTROID_LABEL}" == "a_2" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CENTROID_LABEL

## -u centroid sequence's label is correct in 9th column with C #2
DESCRIPTION="-u centroid sequence's label is correct in 9th column with C #2"
OUTPUT=$(mktemp)
printf ">a_2\nAAAA\n>b_3\nAAAC\n>c_1\nAACC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CENTROID_LABEL=$(awk '/^S/ {v = $9} END {print v}' "${OUTPUT}")
[[ "${CENTROID_LABEL}" == "b_3" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CENTROID_LABEL

## -u centroid sequence's label is correct in 10th column with H
DESCRIPTION="-u centroid sequence's label is correct in 10th column with H"
OUTPUT=$(mktemp)
printf ">a_2\nAAAA\n>b_3\nAAAC\n>c_1\nAACC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CENTROID_LABEL=$(awk '/^H/ {v = $10} END {print v}' "${OUTPUT}")
[[ "${CENTROID_LABEL}" == "b_3" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CENTROID_LABEL

## -u 10th column is * with C
DESCRIPTION="-u 10th column is * with C"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_3\nAACC\n>d_3\nAGCC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CENTROID_LABEL=$(awk '/^C/ {v = $10} END {print v}' "${OUTPUT}")
[[ "${CENTROID_LABEL}" == "*" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CENTROID_LABEL

## -u 10th column is * with S
DESCRIPTION="-u 10th column is * with S"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_3\nAAAC\n>c_3\nAACC\n>d_3\nAGCC\n" | \
    "${SWARM}" -u "${OUTPUT}" &> /dev/null
CENTROID_LABEL=$(awk '/^S/ {v = $10} END {print v}' "${OUTPUT}")
[[ "${CENTROID_LABEL}" == "*" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset CENTROID_LABEL

## -u -f OTU numbering is contiguous (no gap)
DESCRIPTION="-u -f OTU numbering is contiguous (no gap)"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_1\nAAAT\n>c_1\nATTT\n>d_1\nTTTT\n>e_1\nGGGG\n" | \
    "${SWARM}" -f -u "${OUTPUT}" &> /dev/null
OTU_NUMBER=$(awk '/^C/ {v = $2} END {print v}' "${OUTPUT}")
(( "${OTU_NUMBER}" == 1 )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset OTU_NUMBER


## ---------------------------------------------------------------------- seeds

## Swarm accepts the options -w and --seeds
for OPTION in "-w" "--seeds" ; do
    DESCRIPTION="swarms accepts the option ${OPTION}"
    printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nGGGG" | \
        "${SWARM}" "${OPTION}" /dev/null &> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done

## -w creates and fills file given in argument
OUTPUT=$(mktemp)
DESCRIPTION="swarm -w create and fill file given in argument"
printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -w "${OUTPUT}" &> /dev/null
[[ -s "${OUTPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"  

## Swarm -w fails if no output file given
DESCRIPTION="-w fails if no output file given"
printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nGGGG" | \
    "${SWARM}" -w &> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## -w gives expected output
OUTPUT=$(mktemp)
DESCRIPTION="-w gives expected output"
EXPECTED=$(printf ">a_2\nAAAA\n>c_1\nGGGG\n")
printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nGGGG" | \
    "${SWARM}" -w "${OUTPUT}" &> /dev/null
[[ "$(sed '/^>/! y/acgt/ACGT/' "${OUTPUT}")" == "${EXPECTED}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset EXPECTED

## -w can sum up large abundance values (2 * (2^32 + 1))
OUTPUT=$(mktemp)
DESCRIPTION="-w can sum up large abundance values (2 * (2^32 + 1))"
EXPECTED=$(( ((1 << 32) + 1) * 2 ))
printf ">s1_%d\nA\n>s2_%d\nT\n" $(( (1 << 32) + 1)) $(( (1 << 32) + 1)) | \
    "${SWARM}" -w "${OUTPUT}" &> /dev/null
(( "$(awk -F "_" '/^>/ {print $2}' "${OUTPUT}")" == ${EXPECTED} )) && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"
unset EXPECTED


#*****************************************************************************#
#                                                                             #
#                              Output sorting                                 #
#                                                                             #
#*****************************************************************************#

## Swarm sorts amplicons in an OTU by decreasing abundance
OUTPUT=$(mktemp)
DESCRIPTION="swarm sorts amplicons in an OTU by decreasing abundance"
printf ">c_1\nAAAA\n>a_3\nAAAC\n>b_2\nAACC\n" | \
    "${SWARM}" > "${OUTPUT}" 2> /dev/null
grep -q "^a_3 b_2 c_1$" "${OUTPUT}" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"  

## Swarm sorts fasta output by decreasing abundance
OUTPUT=$(mktemp)
DESCRIPTION="swarm sorts fasta output by decreasing abundance"
printf ">c_1\nAAAA\n>a_3\nGGGG\n>b_2\nTTTT\n" | \
    "${SWARM}" > "${OUTPUT}" 2> /dev/null
[[ $(< "${OUTPUT}") == $(printf "a_3\nb_2\nc_1") ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"  


#*****************************************************************************#
#                                                                             #
#                     Pairwise alignment advanced options                     #
#                                                                             #
#*****************************************************************************#

while read LONG SHORT ; do
    ## Using option when d = 1 should fail (or warning?)
    DESCRIPTION="swarm aborts when --${LONG} is specified and d = 1"
    "${SWARM}" -d 1 ${SHORT} 1 < "${ALL_IDENTICAL}" &> /dev/null && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"

    ## option is empty
    DESCRIPTION="swarm aborts when --${LONG} is empty"
    "${SWARM}" -d 2 ${SHORT} < "${ALL_IDENTICAL}" &> /dev/null && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"

    ## option is negative
    DESCRIPTION="swarm aborts when --${LONG} is -1"
    "${SWARM}" -d 2 ${SHORT} \-1 < "${ALL_IDENTICAL}" &> /dev/null && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"

    ## option is non-numerical
    DESCRIPTION="swarm aborts when --${LONG} is not numerical"
    "${SWARM}" -d 2 ${SHORT} "a" < "${ALL_IDENTICAL}" &> /dev/null && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"

    ## option is null (allowed for -m & -p, not for -g & -e)
    if [[ "${SHORT}" == "-m" || "${SHORT}" == "-p" ]] ; then
        DESCRIPTION="swarm aborts when --${LONG} is null"
        "${SWARM}" -d 2 ${SHORT} 0 < "${ALL_IDENTICAL}" &> /dev/null && \
            failure "${DESCRIPTION}" || \
                success "${DESCRIPTION}"
    elif [[ "${SHORT}" == "-g" || "${SHORT}" == "-e" ]] ; then
        DESCRIPTION="swarm runs normally when --${LONG} is null"
        "${SWARM}" -d 2 ${SHORT} 0 < "${ALL_IDENTICAL}" &> /dev/null && \
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
        "${SWARM}" -d 2 "${SHORT}" ${i} < "${ALL_IDENTICAL}" &> /dev/null || \
            failure "swarm aborts when --${LONG} equals ${i}"
    done && success "${DESCRIPTION}"
    
done <<EOF
match-reward -m
mismatch-penalty -p
gap-opening-penalty -g
gap-extension-penalty -e
EOF


## Clean
rm "${ALL_IDENTICAL}"

exit 0
