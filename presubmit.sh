#!/bin/bash
set -eu

pub get

#pub run test
for test in `find test -name '*.dart'` ; do
  echo "TESTING $test"
  pub run $test
done
pub publish --dry-run

echo "+ pub run dart_style:format ..."
pub run dart_style:format -w \
  `find lib -name '*.dart'` \
  `find example -name '*.dart'` \
  `find test -name '*.dart'` | ( grep -v "^Unchanged " || true )

if (( "${TEST_EXAMPLES:-1}" )); then
  example/test_example.sh permutations
  example/test_example.sh angular1
  example/test_example.sh angular2
fi

echo "# SUCCESS: good to go!"
