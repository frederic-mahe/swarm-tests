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
for ((i=1 ; i<=10 ; i++)) ; do
    printf ">%s%d_1\nACGT\n" "seq" ${i}
done > "${ALL_IDENTICAL}"

## Is swarm installed?
SWARM=$(which swarm)
DESCRIPTION="check if swarm is in the PATH"
[[ "${SWARM}" ]] && success "${DESCRIPTION}" || failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                                  No option                                  #
#                                                                             #
#*****************************************************************************#

## No option, only standard input
DESCRIPTION="swarm runs normally when no option is specified (data on stdin)"
"${SWARM}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## No option, only a fasta file
DESCRIPTION="swarm runs normally when no option is specified (data in file)"
"${SWARM}" "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                             End of options (--)                             #
#                                                                             #
#*****************************************************************************#

## End of option marker is supported (usefull for weirdly named input files)
DESCRIPTION="swarm runs normally when -- marks the end of options"
"${SWARM}" -- "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                             Read from stdin (-)                             #
#                                                                             #
#*****************************************************************************#

## Accept "-" as a placeholder for stdin
DESCRIPTION="swarm reads from stdin when - is used"
"${SWARM}" - < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                                Dependencies                                 #
#                                                                             #
#*****************************************************************************#

## SSE2 instructions (first introduced in GGC 3.1)
if $(grep -m 1 "flags" /proc/cpuinfo | grep -q sse2) ; then
    DESCRIPTION="swarm runs normally when SSE2 instructions are available"
    "${SWARM}" "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
else
    # swarm aborts with a non-zero status if SSE2 is missing (hardcoded)
    DESCRIPTION="swarm aborts when SSE2 instructions are not available"
    "${SWARM}" "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
fi


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

## Number of threads (--threads from 1 to 256)
MIN=1
MAX=256
DESCRIPTION="swarm runs normally when --threads goes from ${MIN} to ${MAX}"
for ((t=$MIN ; t<=$MAX ; t++)) ; do
    "${SWARM}" -t ${t} < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null || \
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
DESCRIPTION="swarm aborts when --threads is intmax_t"
"${SWARM}" -t $(((1<<63)-1)) < "${ALL_IDENTICAL}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of threads (--threads is non-numerical)
DESCRIPTION="swarm aborts when --threads is not numerical"
"${SWARM}" -t "a" < "${ALL_IDENTICAL}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                            Options --differences                            #
#                                                                             #
#*****************************************************************************#

## Number of differences (--differences from 0 to 256)
MIN=0
MAX=256
DESCRIPTION="swarm runs normally when --differences goes from ${MIN} to ${MAX}"
for ((d=$MIN ; d<=$MAX ; d++)) ; do
    "${SWARM}" -d ${d} < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null || \
        failure "swarm aborts when --differences equals ${d}"
done && success "${DESCRIPTION}"

## Number of differences (--difference is empty)
DESCRIPTION="swarm aborts when --difference is empty"
"${SWARM}" -d < "${ALL_IDENTICAL}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of differences (--differences is negative)
DESCRIPTION="swarm aborts when --difference is -1"
"${SWARM}" -d -1 < "${ALL_IDENTICAL}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of differences (--differences is 257)
DESCRIPTION="swarm aborts when --difference is 257"
"${SWARM}" -d 257 < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of differences (number of differences is way too large)
DESCRIPTION="swarm aborts when --difference is intmax_t"
"${SWARM}" -d $(((1<<63)-1)) < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Number of differences (--difference is non-numerical)
DESCRIPTION="swarm aborts when --difference is not numerical"
"${SWARM}" -d "a" < "${ALL_IDENTICAL}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                             --no-otu-breaking                               #
#                                                                             #
#*****************************************************************************#

## Initialiasing input that should break
BREAKINGINPUT=$(mktemp)
printf ">a_10\nACGT\n>b_9\nCGGT\n>c_1\nCCGT\n" > "${BREAKINGINPUT}" 

## Swarm accepts --no-otu-breaking 
DESCRIPTION="swarms accepts --no-otu-breaking "
"${SWARM}" --no-otu-breaking < "${BREAKINGINPUT}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm accepts option -n 
DESCRIPTION="swarm accepts option -n"
"${SWARM}" -n < "${BREAKINGINPUT}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Deactivate the built-in OTU refinement
INPUT=$(mktemp)
printf ">a_10\nACGT\n>b_9\nCGGT\n>c_1\nCCGT\n" > "${INPUT}" 
DESCRIPTION="deactivate OTU breaking"
LINENUMBER=$("${SWARM}" -n "${BREAKINGINPUT}" 2> /dev/null | wc -l)
[[ $LINENUMBER == 1 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${INPUT}"
rm "${BREAKINGINPUT}"


#*****************************************************************************#
#                                                                             #
#                             Fastidious options                              #
#                                                                             #
#*****************************************************************************#

FASTIDOUSINPUT=$(mktemp)
printf ">a_10\nACGT\n>b_2\nAGCT\n" > "${FASTIDOUSINPUT}"

## Swarm should run normally when the fastidious option is specified
DESCRIPTION="swarm runs normally when the fastidious option is specified"
"${SWARM}" -f < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarms actually performs a second clustering 
DESCRIPTION="swarms actually performs a second clustering (-b 3)"
LINENUMBER=$("${SWARM}" -f "${FASTIDIOUSINPUT}" 2> /dev/null | wc -l)
[[ $LINENUMBER == 1 ]] && \
    success "${DESCRIPTION}" || \
	
        failure "${DESCRIPTION}"

## Boundary -------------------------------------------------------------------

## Boundary (-b is empty)
DESCRIPTION="swarm aborts when --boundary is empty"
"${SWARM}" -f -b < "${FASTIDOUSINPUT}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Boundary (-b is negative)
DESCRIPTION="swarm aborts when --boundary is -1"
"${SWARM}" -f -b -1 < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Boundary (-b is non-numerical)
DESCRIPTION="swarm aborts when --boundary is not numerical"
"${SWARM}" -f -b "a" < "${FASTIDOUSINPUT}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Boundary (-b == 1)
DESCRIPTION="swarm aborts when --boundary is 1"
"${SWARM}" -f -b 1 < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Accepted values for the boundary option are integers > 1
MIN=2
MAX=255
DESCRIPTION="swarm runs normally when --boundary goes from ${MIN} to ${MAX}"
for ((b=$MIN ; b<=$MAX ; b++)) ; do
    "${SWARM}" -f -b ${b} < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null || \
        failure "swarm aborts when --boundary equals ${b}"
done && success "${DESCRIPTION}"

## Passing the --boundary option without the fastidious option should fail
DESCRIPTION="swarm fails when the boundary option is specified without -f"
"${SWARM}" -b 3 < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Boundary value is taken into account by the fastidious option (-b 2)
DESCRIPTION="boundary value is taken into account by the fastidious option (-b 2)"
LINENUMBER=$("${SWARM}" -f -b 2 "${FASTIDIOUSINPUT}" 2> /dev/null | wc -l)
[[ $LINENUMBER == 2 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Ceiling --------------------------------------------------------------------

## Ceiling (-c is empty)
DESCRIPTION="swarm aborts when --ceiling is empty"
"${SWARM}" -f -c < "${FASTIDOUSINPUT}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Ceiling (-c is negative)
DESCRIPTION="swarm aborts when --ceiling is -1"
"${SWARM}" -f -c -1 < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Ceiling (-c is non-numerical)
DESCRIPTION="swarm aborts when --ceiling is not numerical"
"${SWARM}" -f -c "a" < "${FASTIDOUSINPUT}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Ceiling (-c == 0)
DESCRIPTION="swarm aborts when --ceiling is 0"
"${SWARM}" -f -c 0 < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Accepted values for the ceiling option are positive integers
MIN=1
MAX=255
DESCRIPTION="swarm runs normally when --ceiling goes from ${MIN} to ${MAX}"
for ((c=$MIN ; c<=$MAX ; c++)) ; do
    "${SWARM}" -f -c ${c} < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null || \
        failure "swarm aborts when --ceiling equals ${c}"
done && success "${DESCRIPTION}"

## Passing the --ceiling option without the fastidious option should fail
DESCRIPTION="swarm fails when the ceiling option is specified without -f"
"${SWARM}" -c 10 < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Bloom bits -----------------------------------------------------------------

## Bloom bits (-y is empty)
DESCRIPTION="swarm aborts when --bloom-bits is empty"
"${SWARM}" -f -y < "${FASTIDOUSINPUT}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Bloom bits (-y is negative)
DESCRIPTION="swarm aborts when --bloom-bits is -1"
"${SWARM}" -f -y -1 < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null && \
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
    "${SWARM}" -f -y ${y} < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null || \
        failure "swarm aborts when --bloom-bits equals ${y}"
done && success "${DESCRIPTION}"

## Rejected values for the --bloom-bits option are < 2
DESCRIPTION="swarm aborts when --bloom-bits is lower than 2"
for y in 0 1 ; do
    "${SWARM}" -f -y ${y} < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null && \
        failure "swarm runs normally when --bloom-bits equals ${y}"
done || success "${DESCRIPTION}"

## Accepted values for the --bloom-bits option goes from 2 to 64
MIN=65
MAX=255
DESCRIPTION="swarm aborts when --bloom-bits is higher than 64"
for ((y=$MIN ; y<=$MAX ; y++)) ; do
    "${SWARM}" -f -y ${y} < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null && \
        failure "swarm runs normally when --bloom-bits equals ${y}"
done || success "${DESCRIPTION}"

## Passing the --bloom-bits option without the fastidious option should fail
DESCRIPTION="swarm fails when the --bloom-bits option is specified without -f"
"${SWARM}" -y 16 < "${FASTIDOUSINPUT}" > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
rm "${FASTIDOUSINPUT}"


#*****************************************************************************#
#                                                                             #
#                            Input/Output options                             #
#                                                                             #
#*****************************************************************************#

## Swarm accepts --append-abundance option
DESCRIPTION="swarm accepts --append-abundance option"
"${SWARM}" --append-abundance "${LOG}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm accepts -a option
DESCRIPTION="swarm accepts -a option"
"${SWARM}" -a "${LOG}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm appends the abundance value set with -a
INPUT=$(mktemp)
OUTPUT=$(mktemp)
printf ">b\nACGT\n" > "${INPUT}"
DESCRIPTION="swarm append the abundance number set with -a"
"${SWARM}" -a 2 -w "${OUTPUT}" < "${INPUT}" > /dev/null 2> /dev/null
SUMABUNDANCES=$(sed -n '/^>/ s/.*_//p' "${OUTPUT}")
[[ "${SUMABUNDANCES}" -eq 2 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${INPUT}"
rm "${OUTPUT}"

## Swarm does not overwrite the abundance number with -a for swarm notation
INPUT=$(mktemp)
OUTPUT=$(mktemp)
printf ">b_3\nACGT\n" > "${INPUT}"
DESCRIPTION="swarm does not overwrite the abundance number with -a for vsearch notation"
"${SWARM}" -a 2 -w "${OUTPUT}" < "${INPUT}" > /dev/null 2> /dev/null
SUMABUNDANCES=$(sed -n '/^>/ s/.*_//p' "${OUTPUT}")
[[ "${SUMABUNDANCES}" -eq 3 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${INPUT}"
rm "${OUTPUT}"

## Swarm does not overwrite the abundance number with -a for usearch notation
INPUT=$(mktemp)
OUTPUT=$(mktemp)
printf ">b;size=3\nACGT\n" > "${INPUT}"
DESCRIPTION="swarm does not overwrite the abundance number with -a for usearch notation"
"${SWARM}" -z -a 2 -w "${OUTPUT}" < "${INPUT}" > /dev/null 2> /dev/null
SUMABUNDANCES=$(awk -F "[;=]" '/^>/ {print $3}' "${OUTPUT}")
[[ "${SUMABUNDANCES}" -eq 3 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${INPUT}"
rm "${OUTPUT}"

## Swarm append the abundance number set with -a for swarm notation
OUTPUT=$(mktemp)
DESCRIPTION="swarm append the abundance number set with -a for vsearch notation"
printf ">a_3\nACGT\n>b\nACGT\n" | \
    "${SWARM}" -a 2 -w "${OUTPUT}" > /dev/null 2> /dev/null
SUMABUNDANCES=$(sed -n '/^>/ s/.*_//p' "${OUTPUT}")
[[ "${SUMABUNDANCES}" -eq 5 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm append the abundance number set with -a for usearch notation
OUTPUT=$(mktemp)
DESCRIPTION="swarm append the abundance number set with -a for usearch notation"
printf ">a;size=3\nACGT\n>b\nACGT\n" | \
    "${SWARM}" -z -a 2 -w "${OUTPUT}" > /dev/null 2> /dev/null
SUMABUNDANCES=$(awk -F "[;=]" '/^>/ {print $3}' "${OUTPUT}")
[[ "${SUMABUNDANCES}" -eq 5 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"


## Swarm accepts -a option
DESCRIPTION="swarm accepts -a option"
"${SWARM}" -a "${LOG}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm appends the abundance value set with -a
INPUT=$(mktemp)
OUTPUT=$(mktemp)
printf ">b\nACGT\n" > "${INPUT}"
DESCRIPTION="swarm append the abundance number set with -a"
"${SWARM}" -a 2 -w "${OUTPUT}" < "${INPUT}" > /dev/null 2> /dev/null
SUMABUNDANCES=$(sed -n '/^>/ s/.*_//p' "${OUTPUT}")
[[ "${SUMABUNDANCES}" -eq 2 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${INPUT}"
rm "${OUTPUT}"

## Swarm does not overwrite the abundance number with -a for swarm notation
INPUT=$(mktemp)
OUTPUT=$(mktemp)
printf ">b_3\nACGT\n" > "${INPUT}"
DESCRIPTION="swarm does not overwrite the abundance number with -a for vsearch notation"
"${SWARM}" -a 2 -w "${OUTPUT}" < "${INPUT}" > /dev/null 2> /dev/null
SUMABUNDANCES=$(sed -n '/^>/ s/.*_//p' "${OUTPUT}")
[[ "${SUMABUNDANCES}" -eq 3 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${INPUT}"
rm "${OUTPUT}"

## Swarm does not overwrite the abundance number with -a for usearch notation
INPUT=$(mktemp)
OUTPUT=$(mktemp)
printf ">b;size=3\nACGT\n" > "${INPUT}"
DESCRIPTION="swarm does not overwrite the abundance number with -a for usearch notation"
"${SWARM}" -z -a 2 -w "${OUTPUT}" < "${INPUT}" > /dev/null 2> /dev/null
SUMABUNDANCES=$(awk -F "[;=]" '/^>/ {print $3}' "${OUTPUT}")
[[ "${SUMABUNDANCES}" -eq 3 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${INPUT}"
rm "${OUTPUT}"

## Swarm append the abundance number set with -a for swarm notation
OUTPUT=$(mktemp)
DESCRIPTION="swarm append the abundance number set with -a for vsearch notation"
printf ">a_3\nACGT\n>b\nACGT\n" | \
    "${SWARM}" -a 2 -w "${OUTPUT}" > /dev/null 2> /dev/null
SUMABUNDANCES=$(sed -n '/^>/ s/.*_//p' "${OUTPUT}")
[[ "${SUMABUNDANCES}" -eq 5 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm append the abundance number set with -a for usearch notation
OUTPUT=$(mktemp)
DESCRIPTION="swarm append the abundance number set with -a for usearch notation"
printf ">a;size=3\nACGT\n>b\nACGT\n" | \
    "${SWARM}" -z -a 2 -w "${OUTPUT}" > /dev/null 2> /dev/null
SUMABUNDANCES=$(awk -F "[;=]" '/^>/ {print $3}' "${OUTPUT}")
[[ "${SUMABUNDANCES}" -eq 5 ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm accepts --internal-structure option
OUTPUT=$(mktemp)
DESCRIPTION="swarm accepts --internal-structure option"
"${SWARM}" --internal-structure "${OUTPUT}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm accepts -i option
OUTPUT=$(mktemp)
DESCRIPTION="swarm accepts -i option"
"${SWARM}" -i "${OUTPUT}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm -i fails if no output file given
DESCRIPTION="swarm -i fails if no output file given"
"${SWARM}" -i  < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm -i create and fill given output file
OUTPUT=$(mktemp)
DESCRIPTION="swarm -i create and fill given output file"
"${SWARM}" --internal-structure "${OUTPUT}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null
    [[ -s "${OUTPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## -i number of differences is correct (0 expected)
OUTPUT=$(mktemp)
DESCRIPTION="number of differences is correct (0 expected)"
printf ">a_1\nAAAA\n>b_1\nAAAA\n" | \
"${SWARM}" -i "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $3}' "${OUTPUT}")
    [[ "${OUTPUT}" == "0" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of differences is correct while -d 2 (2 expected)
OUTPUT=$(mktemp)
DESCRIPTION="-i number of differences is correct while -d 2 (2 expected)"
printf ">a_1\nAAAA\n>b_1\nAACC\n" | \
"${SWARM}" -d 2 -i "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $3}' "${OUTPUT}")
    [[ "${OUTPUT}" == "2" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of steps is correct (1 expected)
OUTPUT=$(mktemp)
DESCRIPTION="-i number of steps is correct (1 expected)"
printf ">a_1\nAAAA\n>b_1\nAAAC\n" | \
"${SWARM}" -i "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $5}' "${OUTPUT}")
    [[ "${OUTPUT}" == "1" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of steps is correct (3 expected)
OUTPUT=$(mktemp)
DESCRIPTION="-i number of steps is correct (3 expected)"
printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nAACC\n>d_1\nACCC\n" | \
"${SWARM}" -i "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $5}' "${OUTPUT}" | sed '3q;d' )
    [[ "${OUTPUT}" == "3" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of steps is correct while -d 2 (1 expected)
OUTPUT=$(mktemp)
DESCRIPTION="-i number of steps is correct while -d 2 (1 expected)"
printf ">a_1\nAAAA\n>c_1\nAACC\n" | \
"${SWARM}" -d 2 -i "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $5}' "${OUTPUT}" )
    [[ "${OUTPUT}" == "1" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## -i number of steps is correct while -d 2 (2 expected)
OUTPUT=$(mktemp)
DESCRIPTION="-i number of steps is correct while -d 2 (2 expected)"
printf ">a_1\nAAAA\n>b_1\nAACC\n>c_1\nACCC\n" | \
"${SWARM}" -d 2 -i "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $5}' "${OUTPUT}" | sed '2q;d')
    [[ "${OUTPUT}" == "2" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
    
## Initializing log file
LOG=$(mktemp)

## Swarm accepts --log option
DESCRIPTION="swarm accepts --log option"
"${SWARM}" --log "${LOG}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm accepts -l option
DESCRIPTION="swarm accepts -l option"
"${SWARM}" -l "${LOG}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${LOG}"

## Swarm does not write on standard error when using -l
ERRORINPUT=$(mktemp)
DESCRIPTION="swarm does not write on standard error when using -l"
"${SWARM}" -l /dev/null < "${ALL_IDENTICAL}" > /dev/null 2> "${ERRORINPUT}"
[[ ! -s "${ERRORINPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${ERRORINPUT}"

## Swarm does write on standard error when using -l, except for errors
ERRORINPUT=$(mktemp)
DESCRIPTION="swarm does write on standard error when using -l, except for errors"
"${SWARM}" -d -l /dev/null < "${ALL_IDENTICAL}" > /dev/null 2> "${ERRORINPUT}"
[[ -s "${ERRORINPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${ERRORINPUT}"

## Swarm accepts -o option
OUTPUT=$(mktemp)
DESCRIPTION="swarm accepts -o option"
"${SWARM}" -o "${OUTPUT}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm accepts --output-file option
OUTPUT=$(mktemp)
DESCRIPTION="swarm accepts --output-file option"
"${SWARM}" --output-file "${OUTPUT}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm creates output file with -o option
OUTPUT=$(mktemp)
DESCRIPTION="swarm create output file with -o option"
"${SWARM}" -o  "${OUTPUT}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null
[[ -s "${OUTPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm fills correctly output file with -o option
OUTPUT=$(mktemp)
DESCRIPTION="swarm fill correctly output file with -o option"
"${SWARM}" -o  "${OUTPUT}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null
EXPECTED=$(sed -n '/^>/ s/>//p' "${ALL_IDENTICAL}" | tr "\n" " " | sed 's/ $//')
[[ $(cat "${OUTPUT}") == "${EXPECTED}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm accepts --statistics-file option
DESCRIPTION="swarm accepts --statistics-file option"
OUTPUT=$(mktemp)
"${SWARM}" --statistics-file "${OUTPUT}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm accepts -s option
DESCRIPTION="swarm accepts -s option"
OUTPUT=$(mktemp)
"${SWARM}" -s "${OUTPUT}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm -s create and fill given filename
DESCRIPTION="swarm -s create and fill filename given"
OUTPUT=$(mktemp)
"${SWARM}" -s "${OUTPUT}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null
[[ -s "${OUTPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm -s fails if no filename given
DESCRIPTION="swarm -s fails if no filename given"
"${SWARM}" -s  < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm -s create and fill given filename
DESCRIPTION="swarm -s create and fill filename given"
OUTPUT=$(mktemp)
"${SWARM}" -s "${OUTPUT}" < "${ALL_IDENTICAL}" > /dev/null 2> /dev/null
[[ -s "${OUTPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Number of unique amplicons is correct for -s (1 expected)
DESCRIPTION="number of unique amplicons is correct for -s (1 expected)"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $1}' "${OUTPUT}")
[[ "${OUTPUT}" == "1" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of unique amplicons is correct for -s (2 expected)
DESCRIPTION="number of unique amplicons is correct for -s (2 expected)"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n>b_1\nAAAC\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $1}' "${OUTPUT}")
[[ "${OUTPUT}" == "2" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of unique amplicons is still correct for -s (2 expected)
DESCRIPTION="number of unique amplicons is still correct for -s (2 expected)"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n>b_5\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $1}' "${OUTPUT}" | sed '1q;d')
[[ "${OUTPUT}" == "2" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Total abundance of amplicons is correct for -s (1 expected)
DESCRIPTION="total abundance of amplicons is correct for -s (1 expected)"
OUTPUT=$(mktemp)
printf ">a_1\nAAAA\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $2}' "${OUTPUT}")
[[ "${OUTPUT}" == "1" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Total abundance of amplicons is correct for -s (5 expected)
DESCRIPTION="total abundance of amplicons is correct for -s (5 expected)"
OUTPUT=$(mktemp)
printf ">a_5\nAAAA\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $2}' "${OUTPUT}" | sed '1q;d')
[[ "${OUTPUT}" == "5" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Total abundance of amplicons is still correct for -s (5 expected)
DESCRIPTION="total abundance of amplicons is still correct for -s (5 expected)"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $2}' "${OUTPUT}" | sed '1q;d')
[[ "${OUTPUT}" == "5" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Id of initial seed is correct with -s
DESCRIPTION="Id of initial seed is correct with -s"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $3}' "${OUTPUT}" | sed '1q;d')
[[ "${OUTPUT}" == "a" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Id of initial seed is still correct with -s
DESCRIPTION="Id of initial seed is still correct with -s"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $3}' "${OUTPUT}" | sed '2q;d')
[[ "${OUTPUT}" == "c" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Abundance of initial seed is correct with -s
DESCRIPTION="abundance of initial seed is correct with -s"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $4}' "${OUTPUT}" | sed '1q;d')
[[ "${OUTPUT}" == "3" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Abundance of initial seed is still correct with -s
DESCRIPTION="abundance of initial seed is still correct with -s"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $4}' "${OUTPUT}" | sed '2q;d')
[[ "${OUTPUT}" == "1" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of amplicons with an abundance of 1 is correct with -s (0 exp)
DESCRIPTION="number of amplicons with an abundance of 1 is correct with -s (0 exp)"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $5}' "${OUTPUT}" | sed '1q;d')
[[ "${OUTPUT}" == "0" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Number of amplicons with an abundance of 1 is correct with -s (1 exp)
DESCRIPTION="number of amplicons with an abundance of 1 is correct with -s (1 exp)"
OUTPUT=$(mktemp)
printf ">a_3\nAAAA\n>b_2\nAAAC\n>c_1\nGGGG\n" | \
    "${SWARM}" -s "${OUTPUT}" > /dev/null 2> /dev/null
OUTPUT=$(awk -F "\t" '{print $5}' "${OUTPUT}" | sed '2q;d')
[[ "${OUTPUT}" == "1" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm accepts --seeds option
DESCRIPTION="swarm accepts --seeds option"
OUTPUT=$(mktemp)
printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nGGGG" | \
"${SWARM}" --seeds "${OUTPUT}"  > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm accepts -w option
OUTPUT=$(mktemp)
DESCRIPTION="swarm accepts -w option"
printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nGGGG" | \
"${SWARM}" -w "${OUTPUT}"  > /dev/null 2> /dev/null && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"

## Swarm -w fails if no output file given
DESCRIPTION="swarm -w fails if no output file given"
printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nGGGG" | \
"${SWARM}" -w > /dev/null 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm -w create anf fill file given in argument
OUTPUT=$(mktemp)
DESCRIPTION="swarm -w create anf fill file given in argument"
printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nGGGG" | \
"${SWARM}" -w "${OUTPUT}" > /dev/null 2> /dev/null
[[ -s "${OUTPUT}" ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm "${OUTPUT}"  

## Swarm -w gives expected output
OUTPUT=$(mktemp)

DESCRIPTION="swarm -w gives expected output"
EXPECTED=$(printf ">a_2\naaaa\n>c_1\ngggg\n")
printf ">a_1\nAAAA\n>b_1\nAAAC\n>c_1\nGGGG" | \
"${SWARM}" -w "${OUTPUT}" > /dev/null 2> /dev/null
[[ "$(cat "${OUTPUT}")" == "${EXPECTED}" ]] && \
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
    DESCRIPTION="swarm fails when --${LONG} is specified and d = 1"
    "${SWARM}" -d 1 "${OPTION}" 1 < "${ALL_IDENTICAL}" \
               > /dev/null 2> /dev/null && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"

    ## option is empty
    DESCRIPTION="swarm aborts when --${LONG} is empty"
    "${SWARM}" -d 2 ${SHORT} < "${ALL_IDENTICAL}" 2> /dev/null && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"

    ## option is negative
    DESCRIPTION="swarm aborts when --${LONG} is -1"
    "${SWARM}" -d 2 ${SHORT} -1 < "${ALL_IDENTICAL}" \
               > /dev/null 2> /dev/null && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"

    ## option is non-numerical
    DESCRIPTION="swarm aborts when --${LONG} is not numerical"
    "${SWARM}" -d 2 ${SHORT} "a" < "${ALL_IDENTICAL}" 2> /dev/null && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"

    ## option is negative (allowed for -m & -p, not for -g & -e)
    if [[ "${SHORT}" == "-m" || "${SHORT}" == "-p" ]] ; then
        DESCRIPTION="swarm aborts when --${LONG} is null"
        "${SWARM}" -d 2 ${SHORT} 0 < "${ALL_IDENTICAL}" \
                   > /dev/null 2> /dev/null && \
            failure "${DESCRIPTION}" || \
                success "${DESCRIPTION}"
    elif [[ "${SHORT}" == "-g" || "${SHORT}" == "-e" ]] ; then
        DESCRIPTION="swarm runs normally when --${LONG} is null"
        "${SWARM}" -d 2 ${SHORT} 0 < "${ALL_IDENTICAL}" \
                   > /dev/null 2> /dev/null && \
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
        "${SWARM}" -d 2 "${SHORT}" ${i} < "${ALL_IDENTICAL}" \
                   > /dev/null 2> /dev/null || \
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
