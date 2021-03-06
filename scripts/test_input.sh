#!/bin/bash -

## Print a header
SCRIPT_NAME="Test inputs"
line=$(printf "%076s\n" | tr " " "-")
printf "# %s %s\n" "${line:${#SCRIPT_NAME}}" "${SCRIPT_NAME}"

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
#                               Input channels                                #
#                                                                             #
#*****************************************************************************#

## swarm reads from a file
DESCRIPTION="swarm reads from a file"
FASTA=$(mktemp)
printf ">s_1\nA\n" > "${FASTA}"
"${SWARM}" "${FASTA}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f "${FASTA}"
unset FASTA

## swarm reads from a pipe
DESCRIPTION="swarm reads from a pipe"
printf ">s_1\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm reads from a redirection
DESCRIPTION="swarm reads from a redirection"
FASTA=$(mktemp)
printf ">s_1\nA\n" > "${FASTA}"
"${SWARM}" < "${FASTA}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f "${FASTA}"
unset FASTA

## swarm reads from a HEREDOC
DESCRIPTION="swarm reads from a HEREDOC"
cat <<End-of-message | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
>s_1
A
End-of-message

## swarm reads from a symbolic link
FASTA=$(mktemp)
FASTA_LINK=$(mktemp -u)
printf ">s_1\nA\n" > "${FASTA}"
ln -s "${FASTA}" "${FASTA_LINK}"
DESCRIPTION="swarm reads from a symbolic link"
"${SWARM}" "${FASTA_LINK}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f "${FASTA}" "${FASTA_LINK}"
unset FASTA FASTA_LINK

## swarm accepts inputs from named pipes
DESCRIPTION="swarm accepts inputs from named pipes"
mkfifo fifo_test
"${SWARM}" fifo_test > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
	    failure "${DESCRIPTION}" &
printf ">s_1\nA\n" > fifo_test
rm fifo_test

## swarm reads from a process substitution (anonymous pipe)
DESCRIPTION="swarm reads from a process substitution (unseekable)"
"${SWARM}" <(printf ">a_1\nACGT\n") > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"


#*****************************************************************************#
#                                                                             #
#                                 Fasta input                                 #
#                                                                             #
#*****************************************************************************#

## Test empty input
DESCRIPTION="swarm handles empty input"
printf "" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Swarm fails if header does not start with '>'
DESCRIPTION="swarm fails if header does not start with '>'"
printf "@s_1\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Swarm fails if input file is not readable
DESCRIPTION="swarm fails if input file is not readable"
TMP=$(mktemp)
printf ">s_1\nA\n" > "${TMP}"
chmod u-r "${TMP}"
"${SWARM}" "${TMP}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
chmod +r "${TMP}" && rm -f "${TMP}"
unset TMP

## output files are still created, even when input is empty
## (check if file is created)
DESCRIPTION="empty input yields empty output (-o)"
TMP=$(mktemp -u)
printf "" | \
    "${SWARM}" -o ${TMP} 2> /dev/null
[[ -e ${TMP} ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f ${TMP}

DESCRIPTION="empty input yields empty output (-w)"
TMP=$(mktemp -u)
printf "" | \
    "${SWARM}" -w ${TMP} 2> /dev/null
[[ -e ${TMP} ]] && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
rm -f ${TMP}

## Test empty sequence
DESCRIPTION="swarm handles empty sequences"
printf ">s_1\n\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Test completely empty header
DESCRIPTION="swarm aborts on empty fasta headers"
printf ">\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Test empty header
DESCRIPTION="swarm aborts on empty fasta headers"
printf ">_1\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Test empty header (;size=n format)
DESCRIPTION="swarm aborts on empty fasta headers (-z)"
printf ">;size=1\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Test very long header
DESCRIPTION="swarm accepts headers as long as LINE_MAX - 5 (2,043)"
MAX=2043  # ">" + MAX + "_1\n\0" = 2043 + 5 = 2048 = OK
printf ">%s_1\nA\n" $(head -c ${MAX} < /dev/zero | tr '\0' 's') | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset MAX

DESCRIPTION="swarm accepts headers longer than LINE_MAX - 5 (2,044)"
MAX=2044 # ">" + MAX + "_1\n\0" = 2044 + 5 = 2049 = OK
printf ">%s_1\nA\n" $(head -c ${MAX} < /dev/zero | tr '\0' 's') | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset MAX

## Clustering with only one sequence is accepted
DESCRIPTION="clustering with only one sequence is accepted"
printf ">s_1\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Clustering sequences of length 1 should work with d > 1 too (shorter than kmers)
DESCRIPTION="clustering a sequence shorter than kmer length is accepted"
printf ">s_1\nA\n" | \
    "${SWARM}" -d 2 > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Define ASCII characters accepted in fasta identifiers
DESCRIPTION="ascii characters 1-9, 11-12, 14-31, 33-127 allowed in fasta identifiers"
for i in {1..9} 11 12 {14..31} {33..127} ; do
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">s${OCTAL}_1\nA\n" | \
        "${SWARM}" > /dev/null 2>&1 || \
        failure "ascii character ${i} allowed in fasta identifiers"
done && success "${DESCRIPTION}"
unset OCTAL

## Define ASCII characters not accepted in fasta identifiers
#  0: NULL
# 10: "\n"
# 13: "\r"
# 32: SPACE
for i in 0 10 13 32 ; do
    DESCRIPTION="ascii character ${i} is not allowed in fasta identifiers"
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">s${OCTAL}_1\nA\n" | \
        "${SWARM}" > /dev/null 2>&1 && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
done 
unset OCTAL

## Define ASCII characters accepted in fasta headers
#  0: NULL
# 13: "\r"
# 32: SPACE
for i in 0 13 32 ; do
    DESCRIPTION="ascii character ${i} is allowed in fasta header (outside identifier)"
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">s_1 ${OCTAL}\nA\n" | \
        "${SWARM}" > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done 
unset OCTAL

## ASCII character 10 (\n) is not allowed in fasta headers (outside identifier)
# 10: "\n"
DESCRIPTION="ascii character 10 is not allowed in fasta headers (outside identifier)"
OCTAL=$(printf "\%04o" 10)
echo -e ">s_1 ${OCTAL}s\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"
unset OCTAL

## ASCII character 10 (\n) is allowed at the end of fasta headers (outside identifier)
# 10: "\n"
DESCRIPTION="ascii character 10 is allowed at the end of fasta headers (outside identifier)"
OCTAL=$(printf "\%04o" 10)
echo -e ">s_1 ${OCTAL}\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset OCTAL

## non-ASCII characters accepted in fasta identifiers
DESCRIPTION="non-ASCII characters accepted in fasta identifiers"
printf ">ø_1\nA\n" | \
    "${SWARM}"  > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Define ASCII characters accepted in fasta sequences
# 10: "\n"
# 13: "\r"
# and ACGTUacgtu
# SPACE is not allowed
for i in 0 10 13 65 67 71 84 85 97 99 103 116 117 ; do
    DESCRIPTION="ascii character ${i} is allowed in sequences"
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">s_1\nAC${OCTAL}GT\n" | \
        "${SWARM}" > /dev/null 2>&1 && \
        success "${DESCRIPTION}" || \
            failure "${DESCRIPTION}"
done
unset OCTAL

## Define ASCII characters not accepted in fasta sequences
for i in {1..9} 11 12 {14..64} 66 {68..70} {72..83} {86..96} 98 {100..102} {104..115} {118..127} ; do
    DESCRIPTION="ascii character ${i} is not allowed in sequences"
    OCTAL=$(printf "\%04o" ${i})
    echo -e ">s_1\nAC${OCTAL}GT\n" | \
        "${SWARM}" > /dev/null 2>&1 && \
        failure "${DESCRIPTION}" || \
            success "${DESCRIPTION}"
done
unset OCTAL

## Swarm aborts if fasta identifiers are not unique
DESCRIPTION="swarm aborts if fasta headers are not unique"
printf ">s_1\nA\n>s_1\nC\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## Fasta headers can contain more than one underscore symbol
DESCRIPTION="fasta headers can contain more than one underscore symbol"
printf ">s_2_2_3\nA\n" | \
    "${SWARM}" -o /dev/null -s - 2> /dev/null | \
    awk '{exit $3 == "s_2_2" ? 0 : 1}' && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Fasta headers can contain more than one "size=" (-z)
DESCRIPTION="fasta headers can contain more than one 'size=' (-z)"
printf ">asize=;size=1\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## Fasta header must contain an abundance value after being truncated
DESCRIPTION="swarm aborts if fasta headers lacks abundance value"
printf ">s s_1\nA\n" | \
    "${SWARM}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if abundance value is not a number
DESCRIPTION="swarm aborts if abundance value is not a number"
printf ">s_n\nA\n" | \
    "${SWARM}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if abundance value is zero
DESCRIPTION="swarm aborts if abundance value is zero"
printf ">s_0\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if abundance value is zero
DESCRIPTION="swarm aborts if abundance value is zero"
printf ">s_0\nA\n" | \
    "${SWARM}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if abundance value is negative
DESCRIPTION="swarm aborts if abundance value is negative"
printf ">s_-1\nA\n" | \
    "${SWARM}" 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if abundance value is negative (-z)
DESCRIPTION="swarm aborts if abundance value is negative (-z)"
printf ">s;size=-1\nA\n" | \
    "${SWARM}" -z 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if abundance value is zero (-z)
DESCRIPTION="swarm aborts if abundance value is zero (-z)"
printf ">s;size=0\nA\n" | \
    "${SWARM}" -z 2> /dev/null && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm accepts size= at the start of the header (-z)
DESCRIPTION="swarm accepts size= at the start of the header (-z)"
printf ">size=1;s\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm accepts ;size= at the start of the header (-z)
DESCRIPTION="swarm accepts ;size= at the start of the header (-z)"
printf ">;size=1;s\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm accepts ;size= at the end of the header (-z)
DESCRIPTION="swarm accepts ;size= at the end of the header (-z)"
printf ">s;size=1\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm accepts ;size=INT; at the end of the header (-z)
DESCRIPTION="swarm accepts ;size=INT; at the end of the header (-z)"
printf ">s;size=1;\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm accepts text on both sides of ;size=INT; (-z)
DESCRIPTION="swarm accepts text on both sides of ;size=INT; (-z)"
printf ">s;size=1;s\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm aborts if header has no text at all besides size=INT (-z)
DESCRIPTION="swarm aborts if header has no text at all besides size=INT (-z)"
printf ">size=1\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if header has no text at all besides ;size=INT (-z)
DESCRIPTION="swarm aborts if header has no text at all besides ;size=INT (-z)"
printf ">;size=1\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if header has no text at all besides ;size=INT; (-z)
DESCRIPTION="swarm aborts if header has no text at all besides ;size=INT; (-z)"
printf ">;size=1;\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if header has no text at all besides size=INT; (-z)
DESCRIPTION="swarm aborts if header has no text at all besides size=INT; (-z)"
printf ">size=1;\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if text and size=INT are not ;-separated (-z)
DESCRIPTION="swarm aborts if text and size=INT are not ;-separated 1 (-z)"
printf ">ssize=1\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if text and size=INT are not ;-separated (-z)
DESCRIPTION="swarm aborts if text and size=INT are not ;-separated 2 (-z)"
printf ">size=1s\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm aborts if text and size=INT are not ;-separated (-z)
DESCRIPTION="swarm aborts if text and size=INT are not ;-separated 3 (-z)"
printf ">s;size=1s\nA\n" | \
    "${SWARM}" -z > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm accepts large abundance values (2^32 - 1)
DESCRIPTION="swarm accepts large abundance values (up to 2^32 - 1)"
for POWER in {2..32} ; do
    printf ">s1_%d\nA\n" $(( (1 << POWER) - 1 )) | \
        "${SWARM}" > /dev/null 2>&1 || \
        failure "${DESCRIPTION}"
done && success "${DESCRIPTION}"
unset POWER

## swarm accepts abundance values equal to 2^32
DESCRIPTION="swarm accepts abundance values equal to 2^32"
printf ">s_%d\nA\n" $(( 1 << 32 )) | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm accepts abundance values equal to 2^32 + 1
DESCRIPTION="swarm accepts abundance values equal to 2^32 + 1"
printf ">s_%d\nA\n" $(( (1 << 32) + 1 )) | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"

## swarm aborts if abundance value has more than 20 digits
DESCRIPTION="swarm aborts if abundance value has more than 20 digits"
printf ">s_123456789012345678901\nA\n" | \
    "${SWARM}" > /dev/null 2>&1 && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm ignores stdin output if file is given
DESCRIPTION="swarm ignores stdin output if file is given"
printf ">s1_1\nA\n" | \
    "${SWARM}" <(printf ">s2_1\nT\n") 2> /dev/null | \
    grep -q "^s1_1$" && \
    failure "${DESCRIPTION}" || \
        success "${DESCRIPTION}"

## swarm d = 1 can process sequences with more than 32 nucleotides
## (zobrist.cc coverage)
DESCRIPTION="swarm d = 1 accepts sequences with 32 nucleotides or more"
MAX=40
printf ">s_1\n%s\n" $(head -c ${MAX} < /dev/zero | tr '\0' 'A') | \
    "${SWARM}" > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset MAX

## swarm d = 1 can process sequences with more than 5000 nucleotides
# test can fail if there are less than 10 A, G and Ts in the sequence
DESCRIPTION="swarm d = 1 accepts sequences with 5000 nucleotides or more"
MAX=5000
SEED=$(env LC_CTYPE=C tr -dc 'acgtACGT' < /dev/urandom | \
           tr "[:lower:]" "[:upper:]" | head -c ${MAX})
SUBSEED=$(sed 's/[AGT]/C/10' <<< $SEED)  # replace the 10th A, G or T with a C
printf ">s1_3\n%s\n>s2_1\n%s\n" $SEED $SUBSEED | \
    "${SWARM}" -l /dev/null | \
    grep -q "^s1_3 s2_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset SEED SUBSEED

## swarm d = 2 can process sequences with more than 5000 nucleotides
# test can fail if there are less than 10 A, G and Ts in the sequence
DESCRIPTION="swarm d = 2 accepts sequences with 5000 nucleotides or more"
MAX=5000
SEED=$(env LC_CTYPE=C tr -dc 'acgtACGT' < /dev/urandom | \
           tr "[:lower:]" "[:upper:]" | head -c ${MAX})
SUBSEED=$(sed 's/[AGT]/C/10' <<< $SEED)  # replace the 10th A, G or T with a C
printf ">s1_3\n%s\n>s2_1\n%s\n" $SEED $SUBSEED | \
    "${SWARM}" -d 2 -l /dev/null | \
    grep -q "^s1_3 s2_1$" && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset SEED SUBSEED

## swarm can printout sequences with more than 1025 nucleotides
## (db.cc coverage: default buffer can contain 1024 nucleotides)
DESCRIPTION="swarm can output sequences with more than 1025 nucleotides (-w)"
MAX=1025
printf ">s_1\n%s\n" $(head -c ${MAX} < /dev/zero | tr '\0' 'A') | \
    "${SWARM}" -w - > /dev/null 2>&1 && \
    success "${DESCRIPTION}" || \
        failure "${DESCRIPTION}"
unset MAX


#*****************************************************************************#
#                                                                             #
#                           Realistic input file                              #
#                                                                             #
#*****************************************************************************#

# I think it would be a good idea to add some tests using a somewhat
# larger database than the current tests. A fixed database of some
# 1000-10000 sequences, perhaps subsampled from small real dataset. It
# could be run with -d 0, -d 1, -d 1 -f, and -d 2 and with both 1 and 2
# threads. All output files could be generated and the correct contents
# of those could be checked with a fingerprint (md5 or sha1). I think it
# would trigger some of the code lines that are not covered as of
# now. It could also reveal more subtle errors introduced in the code.

## Work in progress!
# THREADS=1
# DIFFERENCES=0

# ${SWARM} \
#     -d ${DIFFERENCES} \
#     -z \
#     -t ${THREADS} \
#     -o /dev/null \
#     -l /dev/null \
#     <(zcat ../data/T111_30k_reads.fas.gz)  # 1-thread run takes 150 ms

# When testing with a natural dataset, the absolute expected result is
# not known. To solve that, an alternative would be to create a
# perfectly controlled dataset, with a know internal
# structure. Simulation is a possibility, but I could also produce an
# exhaustive set (all primary and secondary microvariants for a given
# sequence). However, it is not possible to do so for sequences longer
# than 100 nucleotides, as the number of microvariants is rougly 50
# times the squared length: 500k for a length of 100, more than 7
# million for an 18S V4 sequence.

# cd Swarms/tests/microvariants/
# python2 produce_microvariants_two_layers.py > tmp.fas

exit 0
