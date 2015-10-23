#!/bin/bash
set -eux

pub get
pub run test
pub publish --dry-run || true

if (( "${TEST_EXAMPLES:-1}" )); then
  example/test_example.sh angular1
  example/test_example.sh angular2
fi

echo "# SUCCESS: good to go!"
