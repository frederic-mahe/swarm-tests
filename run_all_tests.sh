#!/bin/bash

## Launch all tests
for s in ./scripts/*.sh ; do
    bash "${s}"
    echo
done

exit 0
