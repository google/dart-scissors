#!/bin/bash
set -eux

pub get
pub run test
pub publish --dry-run

echo "# SUCCESS: good to go!"
