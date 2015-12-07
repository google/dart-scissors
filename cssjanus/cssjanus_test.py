#!/usr/bin/python
#
# Copyright 2008 Google Inc. All Rights Reserved.
#
"""Tests converting Cascading Style Sheets from LTR to RTL.

   This is a series of CSS test cases for cssjanus.py
"""

__author__ = 'elsigh@google.com (Lindsey Simon)'

import unittest
import cssjanus

class CSSJANUSUnitTest(unittest.TestCase):

  def testPreserveComments(self):
    testcase = ['/* left /* right */left: 10px']
    shouldbe = ['/* left /* right */right: 10px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['/*left*//*left*/left: 10px']
    shouldbe = ['/*left*//*left*/right: 10px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['/* Going right is cool */\n#test {left: 10px}']
    shouldbe = ['/* Going right is cool */\n#test {right: 10px}']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['/* padding-right 1 2 3 4 */\n#test {left: 10px}\n/*right*/']
    shouldbe = ['/* padding-right 1 2 3 4 */\n#test {right: 10px}\n/*right*/']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['/** Two line comment\n * left\n \*/\n#test {left: 10px}']
    shouldbe = ['/** Two line comment\n * left\n \*/\n#test {right: 10px}']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testPositionAbsoluteOrRelativeValues(self):
    testcase = ['left: 10px']
    shouldbe = ['right: 10px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testFourNotation(self):
    testcase = ['padding: .25em 15px 0pt 0ex']
    shouldbe = ['padding: .25em 0ex 0pt 15px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['margin: 1px -4px 3px 2px']
    shouldbe = ['margin: 1px 2px 3px -4px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['padding:0 15px .25em 0']
    shouldbe = ['padding:0 0 .25em 15px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['padding: 1px 4.1grad 3px 2%']
    shouldbe = ['padding: 1px 2% 3px 4.1grad']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['padding: 1px 2px 3px auto']
    shouldbe = ['padding: 1px auto 3px 2px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['padding: 1px inherit 3px auto']
    shouldbe = ['padding: 1px auto 3px inherit']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    # not really four notation
    testcase = ['#settings td p strong']
    shouldbe = testcase
    self.assertEquals(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testThreeNotation(self):
    testcase = ['margin: 1em 0 .25em']
    shouldbe = ['margin: 1em 0 .25em']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['margin:-1.5em 0 -.75em']
    shouldbe = ['margin:-1.5em 0 -.75em']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testTwoNotation(self):
    testcase = ['padding: 1px 2px']
    shouldbe = ['padding: 1px 2px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testOneNotation(self):
    testcase = ['padding: 1px']
    shouldbe = ['padding: 1px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testDirection(self):
    # we don't want direction to be changed other than in body
    testcase = ['direction: ltr']
    shouldbe = ['direction: ltr']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    # we don't want direction to be changed other than in body
    testcase = ['direction: rtl']
    shouldbe = ['direction: rtl']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    # we don't want direction to be changed other than in body
    testcase = ['input { direction: ltr }']
    shouldbe = ['input { direction: ltr }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['body { direction: ltr }']
    shouldbe = ['body { direction: rtl }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['body { padding: 10px; direction: ltr; }']
    shouldbe = ['body { padding: 10px; direction: rtl; }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['body { direction: ltr } .myClass { direction: ltr }']
    shouldbe = ['body { direction: rtl } .myClass { direction: ltr }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['body{\n direction: ltr\n}']
    shouldbe = ['body{\n direction: rtl\n}']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testDoubleDash(self):
    testcase = ['border-left-color: red']
    shouldbe = ['border-right-color: red']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['border-right-color: red']
    shouldbe = ['border-left-color: red']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  # This is for compatibility strength, in reality CSS has no properties
  # that are currently like this.
  def testCSSProperty(self):
    testcase = ['alright: 10px']
    shouldbe = ['alright: 10px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['alleft: 10px']
    shouldbe = ['alleft: 10px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testFloat(self):
    testcase = ['float: right']
    shouldbe = ['float: left']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['float: left']
    shouldbe = ['float: right']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testUrlWithFlagOff(self):
    swap_ltr_rtl_in_url = False
    swap_left_right_in_url = False

    testcase = ['background: url(/foo/bar-left.png)']
    shouldbe = ['background: url(/foo/bar-left.png)']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['background: url(/foo/left-bar.png)']
    shouldbe = ['background: url(/foo/left-bar.png)']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['url("http://www.blogger.com/img/triangle_ltr.gif")']
    shouldbe = ['url("http://www.blogger.com/img/triangle_ltr.gif")']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ["url('http://www.blogger.com/img/triangle_ltr.gif')"]
    shouldbe = ["url('http://www.blogger.com/img/triangle_ltr.gif')"]
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ["url('http://www.blogger.com/img/triangle_ltr.gif'  )"]
    shouldbe = ["url('http://www.blogger.com/img/triangle_ltr.gif'  )"]
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['background: url(/foo/bar.left.png)']
    shouldbe = ['background: url(/foo/bar.left.png)']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['background: url(/foo/bar-rtl.png)']
    shouldbe = ['background: url(/foo/bar-rtl.png)']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['background: url(/foo/bar-rtl.png); left: 10px']
    shouldbe = ['background: url(/foo/bar-rtl.png); right: 10px']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['background: url(/foo/bar-right.png); direction: ltr']
    shouldbe = ['background: url(/foo/bar-right.png); direction: ltr']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['background: url(/foo/bar-rtl_right.png);'
                'left:10px; direction: ltr']
    shouldbe = ['background: url(/foo/bar-rtl_right.png);'
                'right:10px; direction: ltr']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

  def testUrlWithFlagOn(self):
    swap_ltr_rtl_in_url = True
    swap_left_right_in_url = True

    testcase = ['background: url(/foo/bar-left.png)']
    shouldbe = ['background: url(/foo/bar-right.png)']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['background: url(/foo/left-bar.png)']
    shouldbe = ['background: url(/foo/right-bar.png)']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['url("http://www.blogger.com/img/triangle_ltr.gif")']
    shouldbe = ['url("http://www.blogger.com/img/triangle_rtl.gif")']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ["url('http://www.blogger.com/img/triangle_ltr.gif')"]
    shouldbe = ["url('http://www.blogger.com/img/triangle_rtl.gif')"]
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ["url('http://www.blogger.com/img/triangle_ltr.gif'  )"]
    shouldbe = ["url('http://www.blogger.com/img/triangle_rtl.gif'  )"]
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['background: url(/foo/bar.left.png)']
    shouldbe = ['background: url(/foo/bar.right.png)']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['background: url(/foo/bright.png)']
    shouldbe = ['background: url(/foo/bright.png)']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['background: url(/foo/bar-rtl.png)']
    shouldbe = ['background: url(/foo/bar-ltr.png)']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['background: url(/foo/bar-rtl.png); left: 10px']
    shouldbe = ['background: url(/foo/bar-ltr.png); right: 10px']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['background: url(/foo/bar-right.png); direction: ltr']
    shouldbe = ['background: url(/foo/bar-left.png); direction: ltr']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

    testcase = ['background: url(/foo/bar-rtl_right.png);'
                'left:10px; direction: ltr']
    shouldbe = ['background: url(/foo/bar-ltr_left.png);'
                'right:10px; direction: ltr']
    self.assertEqual(shouldbe,
                     cssjanus.ChangeLeftToRightToLeft(testcase,
                                                      swap_ltr_rtl_in_url,
                                                      swap_left_right_in_url))

  def testPadding(self):
    testcase = ['padding-right: bar']
    shouldbe = ['padding-left: bar']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['padding-left: bar']
    shouldbe = ['padding-right: bar']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testMargin(self):
    testcase = ['margin-left: bar']
    shouldbe = ['margin-right: bar']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['margin-right: bar']
    shouldbe = ['margin-left: bar']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testBorder(self):
    testcase = ['border-left: bar']
    shouldbe = ['border-right: bar']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['border-right: bar']
    shouldbe = ['border-left: bar']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testCursor(self):
    testcase = ['cursor: e-resize']
    shouldbe = ['cursor: w-resize']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['cursor: w-resize']
    shouldbe = ['cursor: e-resize']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['cursor: se-resize']
    shouldbe = ['cursor: sw-resize']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['cursor: sw-resize']
    shouldbe = ['cursor: se-resize']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['cursor: ne-resize']
    shouldbe = ['cursor: nw-resize']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['cursor: nw-resize']
    shouldbe = ['cursor: ne-resize']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testBGPosition(self):
    testcase = ['background: url(/foo/bar.png) top left']
    shouldbe = ['background: url(/foo/bar.png) top right']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['background: url(/foo/bar.png) top right']
    shouldbe = ['background: url(/foo/bar.png) top left']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['background-position: top left']
    shouldbe = ['background-position: top right']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['background-position: top right']
    shouldbe = ['background-position: top left']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testBGPositionPercentage(self):
    testcase = ['background-position: 100% 40%']
    shouldbe = ['background-position: 0% 40%']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['background-position: 0% 40%']
    shouldbe = ['background-position: 100% 40%']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['background-position: 23% 0']
    shouldbe = ['background-position: 77% 0']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['background-position: 23% auto']
    shouldbe = ['background-position: 77% auto']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['background-position-x: 23%']
    shouldbe = ['background-position-x: 77%']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['background-position-y: 23%']
    shouldbe = ['background-position-y: 23%']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['background:url(../foo-bar_baz.2008.gif) no-repeat 75% 50%']
    shouldbe = ['background:url(../foo-bar_baz.2008.gif) no-repeat 25% 50%']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['.test { background: 10% 20% } .test2 { background: 40% 30% }']
    shouldbe = ['.test { background: 90% 20% } .test2 { background: 60% 30% }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['.test { background: 0% 20% } .test2 { background: 40% 30% }']
    shouldbe = ['.test { background: 100% 20% } .test2 { background: 60% 30% }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testDirectionalClassnames(self):
    """Makes sure we don't unnecessarily destroy classnames with tokens in them.

    Despite the fact that that is a bad classname in CSS, we don't want to
    break anybody.
    """
    testcase = ['.column-left { float: left }']
    shouldbe = ['.column-left { float: right }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['#bright-light { float: left }']
    shouldbe = ['#bright-light { float: right }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['a.left:hover { float: left }']
    shouldbe = ['a.left:hover { float: right }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    #tests newlines
    testcase = ['#bright-left,\n.test-me { float: left }']
    shouldbe = ['#bright-left,\n.test-me { float: right }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    #tests newlines
    testcase = ['#bright-left,', '.test-me { float: left }']
    shouldbe = ['#bright-left,', '.test-me { float: right }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    #tests multiple names and commas
    testcase = ['div.leftpill, div.leftpillon {margin-right: 0 !important}']
    shouldbe = ['div.leftpill, div.leftpillon {margin-left: 0 !important}']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['div.left > span.right+span.left { float: left }']
    shouldbe = ['div.left > span.right+span.left { float: right }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['.thisclass .left .myclass {background:#fff;}']
    shouldbe = ['.thisclass .left .myclass {background:#fff;}']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['.thisclass .left .myclass #myid {background:#fff;}']
    shouldbe = ['.thisclass .left .myclass #myid {background:#fff;}']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))


  def testLongLineWithMultipleDefs(self):
    testcase = ['body{direction:rtl;float:right}'
                '.b2{direction:ltr;float:right}']
    shouldbe = ['body{direction:ltr;float:left}'
                '.b2{direction:ltr;float:left}']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testNoFlip(self):
    """Tests the /* @noflip */ annotation on classnames."""
    testcase = ['/* @noflip */ div { float: left; }']
    shouldbe = ['/* @noflip */ div { float: left; }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['/* @noflip */ div, .notme { float: left; }']
    shouldbe = ['/* @noflip */ div, .notme { float: left; }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['/* @noflip */ div { float: left; } div { float: left; }']
    shouldbe = ['/* @noflip */ div { float: left; } div { float: right; }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['/* @noflip */\ndiv { float: left; }\ndiv { float: left; }']
    shouldbe = ['/* @noflip */\ndiv { float: left; }\ndiv { float: right; }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    # Test @noflip on single rules within classes
    testcase = ['div { float: left; /* @noflip */ float: left; }']
    shouldbe = ['div { float: right; /* @noflip */ float: left; }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['div\n{ float: left;\n/* @noflip */\n float: left;\n }']
    shouldbe = ['div\n{ float: right;\n/* @noflip */\n float: left;\n }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['div\n{ float: left;\n/* @noflip */\n text-align: left\n }']
    shouldbe = ['div\n{ float: right;\n/* @noflip */\n text-align: left\n }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['div\n{ /* @noflip */\ntext-align: left;\nfloat: left\n  }']
    shouldbe = ['div\n{ /* @noflip */\ntext-align: left;\nfloat: right\n  }']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['/* @noflip */div{float:left;text-align:left;}div{float:left}']
    shouldbe = ['/* @noflip */div{float:left;text-align:left;}div{float:right}']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['/* @noflip */','div{float:left;text-align:left;}a{foo:left}']
    shouldbe = ['/* @noflip */', 'div{float:left;text-align:left;}a{foo:right}']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testBorderRadiusNotation(self):
    testcase = ['border-radius: .25em 15px 0pt 0ex']
    shouldbe = ['border-radius: 15px .25em 0ex 0pt']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['border-radius: 10px 15px 0px']
    shouldbe = ['border-radius: 15px 10px 15px 0px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['border-radius: 7px 8px']
    shouldbe = ['border-radius: 8px 7px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['border-radius: 5px']
    shouldbe = ['border-radius: 5px']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

  def testGradientNotation(self):
    testcase = ['background-image: -moz-linear-gradient(#326cc1, #234e8c)']
    shouldbe = ['background-image: -moz-linear-gradient(#326cc1, #234e8c)']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

    testcase = ['background-image: -webkit-gradient(linear, 100% 0%, 0% 0%, from(#666666), to(#ffffff))']
    shouldbe = ['background-image: -webkit-gradient(linear, 100% 0%, 0% 0%, from(#666666), to(#ffffff))']
    self.assertEqual(shouldbe, cssjanus.ChangeLeftToRightToLeft(testcase))

if __name__ == '__main__':
  unittest.main()
