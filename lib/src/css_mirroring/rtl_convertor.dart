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
library scissors.src.css_pruning.rtl_convertor;

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart'
    show CssPrinter, RuleSet, StyleSheet, TreeNode, TreeOutput, Declaration;
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import '../utils/hacks.dart' as hacks;
import 'transformer.dart' show CssMirroringSettings;

import 'signature_generator.dart';

/// Edits [transaction] to drop any CSS rule in [topLevels] that we're sure
/// is not referred to by any DOM node in [htmlTrees].
generatecommon(Transform transform,
    TextEditTransaction transaction,
    TextEditTransaction transaction1,
    TextEditTransaction transaction2,
    CssMirroringSettings settings,
    SourceFile cssSourceFile,
    SourceFile cssSourceFile1,
    SourceFile cssSourceFile2) {
  hacks.useCssLib();

  final StyleSheet cssTree =
  new css_parser.Parser(cssSourceFile, transaction.original).parse();
  List<TreeNode> topLevels = cssTree.topLevels;
  var to = new TreeOutput();
  var tp = new SignatureGenerator(to, false);
  cssTree.visit(tp);

  final StyleSheet cssTree1 = new css_parser.Parser(
      cssSourceFile1, transaction1.original).parse();
  List<TreeNode> topLevels1 = cssTree1.topLevels;
  var to1 = new TreeOutput();
  var tp1 = new SignatureGenerator(to1, false);
  cssTree1.visit(tp1);

  bool ltrDirection = true;

  void _commonmap(TextEditTransaction t) {
    for (int i = 0; i < tp.lr.length; i++) {
      bool saved = false;
      int ruleid = i;
      List<int> startpoint = new List();
      List<int> endpoint = new List();
      while (i < tp.lr.length &&
          (tp1.lr[i].span.text == tp1.lr[ruleid].span.text)) {
        if ((tp.lr[i].span.text == tp1.lr[i].span.text)) {
          if (tp.ld[i].span.text != tp1.ld[i].span.text) {
            var start = tp1.ld[i].span.start.offset;
            var end = tp1.ld[i].span.end.offset;
            if ((i < tp1.lr.length - 1) && (tp1.lr[i].span.text == tp1.lr[i + 1].span.text)) {
                end = tp1.ld[i + 1].span.start.offset;
            } else {
              while (t.file.getText(end, end + 1) != '}') {
                end++;
              }
            }
            startpoint.add(start);
            endpoint.add(end);
          }
          else {
            saved = true;

          }
        }
        i++;
      }
      if (saved == false) {
        if (i < tp1.lr.length) {
        //  print(tp1.lr[ruleid].span.text);
          t.edit(
              tp1.lr[ruleid].span.start.offset, tp1.lr[i].span.start.offset, '');
        }
        else {
          t.edit(
              tp1.lr[ruleid].span.start.offset, t.file.length, '');
        }
      }
      else {
        for (int i = 0; i < startpoint.length; i++) {
          t.edit(startpoint[i], endpoint[i], '');
        }
      }
      i--;
    }
  }

  void _differentmapfile1(TextEditTransaction t) {
    for (int i = 0; i < tp.lr.length; i++) {
      bool saved = false;
      int ruleid = i;
      List<int> startpoint = new List();
      List<int> endpoint = new List();
      while (i < tp.lr.length &&
          (tp.lr[i].span.text == tp.lr[ruleid].span.text)) {
        if ((tp.lr[i].span.text == tp1.lr[i].span.text)) {
          if (tp.ld[i].span.text == tp1.ld[i].span.text) {
            var start = tp.ld[i].span.start.offset;
            var end = tp.ld[i].span.end.offset;
            if ((i < tp.lr.length - 1) && (tp.lr[i].span.text == tp.lr[i + 1].span.text)) {
              end = tp.ld[i + 1].span.start.offset;
            } else {
              while (t.file.getText(end, end + 1) != '}') {
                end++;
              }
            }
            startpoint.add(start);
            endpoint.add(end);
          }
          else {
            saved = true;
          }
        }
        i++;
      }
      if (saved == false) {
        if (i < tp.lr.length) {
          t.edit(
              tp.lr[ruleid].span.start.offset, tp.lr[i].span.start.offset, '');
        }
        else {
          t.edit(
              tp.lr[ruleid].span.start.offset, t.file.length, '');
        }
      }
      else {
        for (int i = 0; i < startpoint.length; i++) {
          t.edit(startpoint[i], endpoint[i], '');
        }
        t.edit(tp.lr[ruleid].span.start.offset, tp.lr[ruleid].span.end.offset, ':host-context([dir="${ltrDirection ? "ltr" : "rtl"}"]) ' + tp.lr[ruleid].span.text);
      }
      i--;
    }
  }

  void _differentmapfile2(TextEditTransaction t) {
    for (int i = 0; i < tp.lr.length; i++) {
      bool saved = false;
      int ruleid = i;
      List<int> startpoint = new List();
      List<int> endpoint = new List();
      while (i < tp.lr.length &&
          (tp.lr[i].span.text == tp.lr[ruleid].span.text)) {
        if ((tp.lr[i].span.text == tp1.lr[i].span.text)) {
          if (tp.ld[i].span.text == tp1.ld[i].span.text) {
            var start = tp1.ld[i].span.start.offset;
            var end = tp1.ld[i].span.end.offset;
            if ((i < tp1.lr.length - 1) && (tp1.lr[i].span.text == tp.lr[i + 1].span.text)) {
              end = tp1.ld[i + 1].span.start.offset;
            } else {
              while (t.file.getText(end, end + 1) != '}') {
                end++;
              }
            }
            startpoint.add(start);
            endpoint.add(end);
          }
          else {
            saved = true;
          }
        }
        i++;
      }
      if (saved == false) {
        if (i < tp1.lr.length) {
          t.edit(
              tp1.lr[ruleid].span.start.offset, tp1.lr[i].span.start.offset, '');
        }
        else {
          t.edit(
              tp1.lr[ruleid].span.start.offset, t.file.length, '');
        }
      }
      else {
        for (int i = 0; i < startpoint.length; i++) {
          t.edit(startpoint[i], endpoint[i], '');
        }
        t.edit(tp1.lr[ruleid].span.start.offset, tp1.lr[ruleid].span.end.offset, ':host-context([dir="${ltrDirection ? "rtl" : "ltr"}"]) ' + tp1.lr[ruleid].span.text);
      }
      i--;
    }
  }

//  _common(transaction);
  _differentmapfile1(transaction);
  _differentmapfile2(transaction1);
  _commonmap(transaction2);
}
String _printCss(tree) =>
    (new CssPrinter()..visitTree(tree, pretty: true)).toString();

