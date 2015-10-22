#!/bin/bash
set -eux

cd `dirname $0`

./presubmit.sh

example/test_example.sh angular1
example/test_example.sh angular2

pub publish
