#!/bin/bash
set -eux

pub get
pub run test
pub publish --dry-run

set +x
echo "+ pub run dart_style:format ..."
pub run dart_style:format -w \
  `find lib -name '*.dart'` \
  `find example -name '*.dart'` \
  `find test -name '*.dart'`
set -x

if (( "${TEST_EXAMPLES:-1}" )); then
  example/test_example.sh angular1
  example/test_example.sh angular2
fi

echo "# SUCCESS: good to go!"
