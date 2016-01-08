#!/bin/bash
set -eu

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

function run_travis_lint() {
  echo "Checking travis config"
  which travis || gem install travis --no-rdoc --no-ri
  travis lint -x --skip-completion-check
}

cd $(dirname ${BASH_SOURCE[0]})/..

pub get
. scripts/install_dependencies.sh

run_travis_lint
run_analyzer
run_tests
run_formatter
pub publish --dry-run

if (( "${TEST_EXAMPLES:-1}" )); then
  scripts/test_example.sh permutations
  scripts/test_example.sh angular1
  scripts/test_example.sh angular2
fi

echo "# SUCCESS: good to go!"
