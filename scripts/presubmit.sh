#!/bin/bash
set -eu

function run_analyzer() {
  echo "Running the analyzer"
  dartanalyzer \
    --strong \
    --fatal-warnings \
    --fatal-hints \
    --fatal-lints \
    `find bin -name '*.dart'` `find lib -name '*.dart'`
}

function run_tests() {
  export TEST_COMPASS_POLYFILLED_FUNCTIONS=true
  echo "Running tests"
  # TODO(ochafik): `pub run test` again? (sometimes not reliable)
  for test in `find test -name '*.dart'` ; do
    echo "TESTING $test"
    SKIP_PATH_RESOLVER_TESTS=true pub run -c $test
  done
}

function run_formatter() {
  echo "Running the formatter"
  pub run dart_style:format -w \
    `find lib -name '*.dart'` \
    `ls example/{angular1,angular2,permutations,mirroring}/web/*.dart` \
    `find test -name '*.dart'` | ( grep -v "^Unchanged " || true )
}

function run_travis_lint() {
  echo "Checking travis config"
  which travis || gem install travis --no-rdoc --no-ri
  travis lint -x --skip-completion-check
}

function run_pub_build() {
  echo "Pub-building to self-check"
  pub build
}

cd $(dirname ${BASH_SOURCE[0]})/..

pub get
. scripts/install_dependencies.sh

run_formatter
run_analyzer
run_tests
run_travis_lint
run_pub_build
pub publish --dry-run

if (( "${TEST_EXAMPLES:-1}" )); then
  # The order of execution of pub transforms cannot be made to be predictive.
  scripts/test_example.sh permutations || true
  scripts/test_example.sh angular1 || true
  scripts/test_example.sh angular2 || true
  scripts/test_example.sh mirroring || true
fi

echo "# SUCCESS: good to go!"
