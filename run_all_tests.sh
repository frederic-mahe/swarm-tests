#!/bin/bash

## tests use the first swarm binary in $PATH by default, use ${1} to
## point to another binary

## Launch all tests
for s in ./scripts/{test_input,test_options,fixed_bugs}.sh ; do
    bash "${s}" "${1}" || exit 1
    echo
done

exit 0
