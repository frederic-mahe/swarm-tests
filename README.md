# swarm-tests

unit tests for the amplicon clustering method
[swarm](https://github.com/torognes/swarm).

The objective is to gather, organize and factorize all the scripts
written to test the behaviour, results or bugs of the clustering
algorithm **swarm**.

Tests are gathered into three categories:
* input formats (`test_input.sh`),
* option values and expected output (`test_options.sh`),
* check for regressions (`fixed_bugs.sh`).

Present and future versions of swarm should pass all the above
tests. To test a new version of swarm, simply launch:
```sh
bash run_all_tests.sh
```
(bash version 4 or higher required)
