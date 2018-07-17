// Copyright 2015 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
library scissors.src.css_mirroring.cssjanus_runner;

import 'dart:async';
import 'dart:io';

import '../utils/process_utils.dart';

/// Runs cssjanus (https://github.com/cegov/wiki/tree/master/maintenance/cssjanus)
/// on [css], and returns the flipped CSS.
///
/// [cssJanusPath] points to an executable.
Future<String> runCssJanus(String css, String cssJanusPath) async =>
    successString(
        'cssjanus',
        await pipeInAndOutOfNewProcess(
            await Process.start(cssJanusPath, [], runInShell: true), css));
