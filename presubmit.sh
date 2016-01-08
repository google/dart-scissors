#!/bin/bash
set -eu

pub get

function run_analyzer() {
  echo "Running the analyzer"
  dartanalyzer --fatal-warnings `find bin -name '*.dart'` `find lib -name '*.dart'`
}

function run_tests() {
  echo "Running tests"
  # TODO(ochafik): `pub run test` again? (sometimes not reliable)
  for test in `find test -name '*.dart'` ; do
    echo "TESTING $test"
    SKIP_PATH_RESOLVER_TESTS=true pub run $test
  done
}

function run_formatter() {
  echo "Running the formatter"
  pub run dart_style:format -w \
    `find lib -name '*.dart'` \
    `find example -name '*.dart'` \
    `find test -name '*.dart'` | ( grep -v "^Unchanged " || true )
}

run_analyzer
run_tests
run_formatter
pub publish --dry-run

if (( "${TEST_EXAMPLES:-1}" )); then
  example/test_example.sh permutations
  example/test_example.sh angular1
  example/test_example.sh angular2
fi

echo "# SUCCESS: good to go!"
