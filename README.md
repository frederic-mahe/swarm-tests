# swarm-tests

Datasets and scripts to test the amplicon clustering method
[swarm](https://github.com/torognes/swarm).

The objective is to gather and rationalize all the scripts written to
test the behaviour, the results or bugs of the clustering algorithm
**swarm**.

Test scripts are gathered into four categories:
* valid and invalid option values (`test_options.sh`),
* valid and invalid input formats (`test_input.sh`),
* expected output formats (`test_output.sh`),
* check for regressions (`fixed_bugs.sh`),

Present and future versions of swarm should pass all the above
tests. A last category groups tests triggering unfixed bugs
(`pending_bugs.sh`). That category is transitory and should remain
empty most of the time.

To test a new version of swarm, simply launch:
```sh
bash run_all_tests.sh
```
