#!/bin/bash
set -eux

pub run test
example/test_example.sh angular1
example/test_example.sh angular2
pub publish --dry-run

echo "# SUCCESS: good to go!"
