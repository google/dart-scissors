#!/bin/bash
set -eu

function find_dart_files() {
  find bin -name '*.dart' | grep -v 'smart_clone.dart'
  find lib -name '*.dart' | grep -v 'lib/src/checker/'
}
function find_dart_test_files() {
  find test -name '*.dart' | grep -v 'test/checker/'
}
function run_analyzer() {
  echo "Running the analyzer"
  dartanalyzer \
    --strong \
    --lints \
    --fatal-warnings \
    --fatal-hints \
    --fatal-lints \
    `find_dart_files`
}

function run_tests() {
  export TEST_COMPASS_POLYFILLED_FUNCTIONS=true
  echo "Running tests"
  # TODO(ochafik): `pub run test` again? (sometimes not reliable)
  for test in `find_dart_test_files` ; do
    echo "TESTING $test"
    SKIP_PATH_RESOLVER_TESTS=true pub run -c $test
  done
}

function run_formatter() {
  echo "Running the formatter"
  pub run dart_style:format -w \
    `find_dart_files` `find_dart_test_files` \
    `ls example/{angular1,angular2,permutations,mirroring}/web/*.dart` | \
      ( grep -v "^Unchanged " || true )
}

function run_travis_lint() {
  echo "Checking travis config"
  which travis || gem install travis --no-rdoc --no-ri
  travis lint -x --skip-completion-check
}

function run_checker() {
  echo "Pub-building to self-check"
  cp pubspec.yaml pubspec.yaml.orig
  echo "
transformers:
  - scissors/src/checker/transformer:
      unawaitedFutures: error
  - \$dart2js:
      \$exclude: '**'
" >> pubspec.yaml
  pub build
  mv -f pubspec.yaml.orig pubspec.yaml
}

cd $(dirname ${BASH_SOURCE[0]})/..

pub get
. scripts/install_dependencies.sh

run_formatter
run_analyzer
run_tests
if (( ${RUN_TRAVIS_LINT:-0} )); then
  run_travis_lint
fi
if (( ${RUN_CHECKER:-0} )); then
  run_checker
fi
pub publish --dry-run || false

if (( "${TEST_EXAMPLES:-1}" )); then
  # The order of execution of pub transforms cannot be made to be predictive.
  scripts/test_example.sh permutations || true
  scripts/test_example.sh angular1 || true
  scripts/test_example.sh angular2 || true
  scripts/test_example.sh mirroring || true
fi

echo "# SUCCESS: good to go!"
