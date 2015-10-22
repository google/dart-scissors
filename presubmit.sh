#!/bin/bash
set -eux

pub get
pub run test
pub publish --dry-run || true

echo "# SUCCESS: good to go!"
