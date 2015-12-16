#!/bin/bash
set -eux

cd `dirname $0`

./presubmit.sh

if (( "${TEST_EXAMPLES:-1}" )); then
  example/test_example.sh permutations
  example/test_example.sh angular1
  example/test_example.sh angular2
  example/test_example.sh mirroring
fi

pub publish
