library scissors.test.src.test_utils;

import 'dart:io';

bool hasExecutable(String name) =>
    Process.runSync('which', [name]).exitCode == 0;
