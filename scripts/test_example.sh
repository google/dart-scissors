#!/bin/bash
#
# Invocation:
#   example/test_example.sh angular1
#
set -eu

readonly EXAMPLE_NAME="$1"

cd $(dirname ${BASH_SOURCE[0]})/..
cd "example/$EXAMPLE_NAME"

# TODO(ochafik): Update pubspec with current version of scissors
# sed -i.bak -E 's!scissors: .+!scissors: '$version'!' pubspec.yaml

echo "# Building $EXAMPLE_NAME"
pub get
pub build 2>&1 | \
  egrep -v "^Took .*? to compile " | \
  egrep -v ".*? took .*? msec." | \
  tee pub.out

if [[ -f pub.out.expected ]]; then
  echo "# Diffing pub output with its expectation"
  diff pub.out.expected pub.out | tee pub.out.diff
  mv pub.out pub.out.expected
else
  mv pub.out pub.out.expected
fi

if [[ -f pub.out.diff ]]; then
  LINES=`cat pub.out.diff | wc -l`
  rm pub.out.diff
  if [[ "$LINES" -gt 0 ]]; then
    echo "# ERROR: Found unexpected difference of pub output"
    exit 1
  else
    echo "# SUCCESS: Pub output is the same as expected"
  fi
fi
