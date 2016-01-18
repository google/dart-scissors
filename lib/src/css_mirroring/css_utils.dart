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
library scissors.src.css_mirroring.util_functions;

import 'package:csslib/visitor.dart';

bool isDirectionInsensitive(TreeNode node) => node is CharsetDirective ||
    node is FontFaceDirective ||
    node is ImportDirective ||
    node is NamespaceDirective;

bool hasNestedRuleSets(TreeNode node) =>
    node is MediaDirective || node is HostDirective;
