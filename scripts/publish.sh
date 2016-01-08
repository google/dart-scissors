#!/bin/bash
set -eux

cd $(dirname ${BASH_SOURCE[0]})/..

scripts/presubmit.sh

pub publish
