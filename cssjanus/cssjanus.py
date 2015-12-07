#!/usr/bin/python
#
# Copyright 2008 Google Inc. All Rights Reserved.

"""Converts a LeftToRight Cascading Style Sheet into a RightToLeft one.

   This is a utility script for replacing "left" oriented things in a CSS file
   like float, padding, margin with "right" oriented values.
   It also does the opposite.
   The goal is to be able to conditionally serve one large, cat'd, compiled CSS
   file appropriate for LeftToRight oriented languages and RightToLeft ones.
   This utility will hopefully help your structural layout done in CSS in
   terms of its RTL compatibility. It will not help with some of the more
   complicated bidirectional text issues.
"""

__author__ = ['elsigh@google.com (Lindsey Simon)']
__contributors__ = ['roozbeh@gmail.com (Roozbeh Pournader)',
			  		'ebryon77@gmail.com (Bryon Engelhardt)']
__version__ = '0.1'

import logging
import re
import sys
import getopt
import os

import csslex

logging.getLogger().setLevel(logging.INFO)

# Global for the command line flags.
SWAP_LTR_RTL_IN_URL_DEFAULT = False
SWAP_LEFT_RIGHT_IN_URL_DEFAULT = False
IGNORE_BAD_BGP_DEFAULT = False
FLAGS = {'swap_ltr_rtl_in_url': SWAP_LTR_RTL_IN_URL_DEFAULT,
         'swap_left_right_in_url': SWAP_LEFT_RIGHT_IN_URL_DEFAULT,
         'ignore_bad_bgp': IGNORE_BAD_BGP_DEFAULT}

# Generic token delimiter character.
TOKEN_DELIMITER = '~'

# This is a temporary match token we use when swapping strings.
TMP_TOKEN = '%sTMP%s' % (TOKEN_DELIMITER, TOKEN_DELIMITER)

# Token to be used for joining lines.
TOKEN_LINES = '%sJ%s' % (TOKEN_DELIMITER, TOKEN_DELIMITER)

# Global constant text strings for CSS value matches.
LTR = 'ltr'
RTL = 'rtl'
LEFT = 'left'
RIGHT = 'right'

# This is a lookbehind match to ensure that we don't replace instances
# of our string token (left, rtl, etc...) if there's a letter in front of it.
# Specifically, this prevents replacements like 'background: url(bright.png)'.
LOOKBEHIND_NOT_LETTER = r'(?<![a-zA-Z])'

# This is a lookahead match to make sure we don't replace left and right
# in actual classnames, so that we don't break the HTML/CSS dependencies.
# Read literally, it says ignore cases where the word left, for instance, is
# directly followed by valid classname characters and a curly brace.
# ex: .column-left {float: left} will become .column-left {float: right}
LOOKAHEAD_NOT_OPEN_BRACE = (r'(?!(?:%s|%s|%s|#|\:|\.|\,|\+|>)*?{)' %
                            (csslex.NMCHAR, TOKEN_LINES, csslex.SPACE))


# These two lookaheads are to test whether or not we are within a
# background: url(HERE) situation.
# Ref: http://www.w3.org/TR/CSS21/syndata.html#uri
VALID_AFTER_URI_CHARS = r'[\'\"]?%s' % csslex.WHITESPACE
LOOKAHEAD_NOT_CLOSING_PAREN = r'(?!%s?%s\))' % (csslex.URL_CHARS,
                                                VALID_AFTER_URI_CHARS)
LOOKAHEAD_FOR_CLOSING_PAREN = r'(?=%s?%s\))' % (csslex.URL_CHARS,
                                                VALID_AFTER_URI_CHARS)

# Compile a regex to swap left and right values in 4 part notations.
# We need to match negatives and decimal numeric values.
# The case of border-radius is extra complex, so we handle it separately below.
# ex. 'margin: .25em -2px 3px 0' becomes 'margin: .25em 0 3px -2px'.

POSSIBLY_NEGATIVE_QUANTITY = r'((?:-?%s)|(?:inherit|auto))' % csslex.QUANTITY
POSSIBLY_NEGATIVE_QUANTITY_SPACE = r'%s%s%s' % (POSSIBLY_NEGATIVE_QUANTITY,
                                                csslex.SPACE,
                                                csslex.WHITESPACE)
FOUR_NOTATION_QUANTITY_RE = re.compile(r'%s%s%s%s' %
                                       (POSSIBLY_NEGATIVE_QUANTITY_SPACE,
                                        POSSIBLY_NEGATIVE_QUANTITY_SPACE,
                                        POSSIBLY_NEGATIVE_QUANTITY_SPACE,
                                        POSSIBLY_NEGATIVE_QUANTITY),
                                       re.I)
COLOR = r'(%s|%s)' % (csslex.NAME, csslex.HASH)
COLOR_SPACE = r'%s%s' % (COLOR, csslex.SPACE)
FOUR_NOTATION_COLOR_RE = re.compile(r'(-color%s:%s)%s%s%s(%s)' %
                                    (csslex.WHITESPACE,
                                     csslex.WHITESPACE,
                                     COLOR_SPACE,
                                     COLOR_SPACE,
                                     COLOR_SPACE,
                                     COLOR),
                                    re.I)

# border-radius is very different from usual 4 part notation: ABCD should
# change to BADC (while it would be ADCB in normal 4 part notation), ABC
# should change to BABC, and AB should change to BA
BORDER_RADIUS_RE = re.compile(r'((?:%s)?)border-radius(%s:%s)'
                               '(?:%s)?(?:%s)?(?:%s)?(?:%s)'
                               '(?:%s/%s(?:%s)?(?:%s)?(?:%s)?(?:%s))?' % (csslex.IDENT,
                                                                          csslex.WHITESPACE,
                                                                          csslex.WHITESPACE,
                                                                          POSSIBLY_NEGATIVE_QUANTITY_SPACE,
                                                                          POSSIBLY_NEGATIVE_QUANTITY_SPACE,
                                                                          POSSIBLY_NEGATIVE_QUANTITY_SPACE,
                                                                          POSSIBLY_NEGATIVE_QUANTITY,
                                                                          csslex.WHITESPACE,
                                                                          csslex.WHITESPACE,
                                                                          POSSIBLY_NEGATIVE_QUANTITY_SPACE,
                                                                          POSSIBLY_NEGATIVE_QUANTITY_SPACE,
                                                                          POSSIBLY_NEGATIVE_QUANTITY_SPACE,
                                                                          POSSIBLY_NEGATIVE_QUANTITY),
                              re.I)

# Compile the cursor resize regexes
CURSOR_EAST_RE = re.compile(LOOKBEHIND_NOT_LETTER + '([ns]?)e-resize')
CURSOR_WEST_RE = re.compile(LOOKBEHIND_NOT_LETTER + '([ns]?)w-resize')

# Matches the condition where we need to replace the horizontal component
# of a background-position value when expressed in horizontal percentage.
# Had to make two regexes because in the case of position-x there is only
# one quantity, and otherwise we don't want to match and change cases with only
# one quantity.
BG_HORIZONTAL_PERCENTAGE_RE = re.compile(r'background(-position)?(%s:%s)'
                                         '([^%%]*?)(%s)%%'
                                         '(%s(?:%s|top|center|bottom))' % (csslex.WHITESPACE,
                                                                           csslex.WHITESPACE,
                                                                           csslex.NUM,
                                                                           csslex.WHITESPACE,
                                                                           POSSIBLY_NEGATIVE_QUANTITY))

BG_HORIZONTAL_PERCENTAGE_X_RE = re.compile(r'background-position-x(%s:%s)'
                                           '(%s)%%' % (csslex.WHITESPACE,
                                                       csslex.WHITESPACE,
                                                       csslex.NUM))

# Non-percentage units used for CSS lengths
LENGTH_UNIT = r'(?:em|ex|px|cm|mm|in|pt|pc)'
# To make sure the lone 0 is not just starting a number (like "02") or a percentage like ("0 %")
LOOKAHEAD_END_OF_ZERO = '(?![0-9]|%s%%)' % csslex.WHITESPACE
# A length with a unit specified. Matches "0" too, as it's a length, not a percentage.
LENGTH = '(?:-?%s(?:%s%s)|0+%s)' % (csslex.NUM,
                                    csslex.WHITESPACE,
                                    LENGTH_UNIT,
                                    LOOKAHEAD_END_OF_ZERO)

# Zero length. Used in the replacement functions.
ZERO_LENGTH = re.compile(r'(?:-?0+(?:%s%s)|0+%s)$' % (csslex.WHITESPACE,
                                                      LENGTH_UNIT,
                                                      LOOKAHEAD_END_OF_ZERO))

# Matches background, background-position, and background-position-x
# properties when using a CSS length for its horizontal positioning.
BG_HORIZONTAL_LENGTH_RE = re.compile(r'background(-position)?(%s:%s)'
                                      '((?:.+?%s+)??)(%s)'
                                      '((?:%s+)(?:%s|top|center|bottom))'% (csslex.WHITESPACE,
                                                                            csslex.WHITESPACE,
                                                                            csslex.SPACE,
                                                                            LENGTH,
                                                                            csslex.SPACE,
                                                                            POSSIBLY_NEGATIVE_QUANTITY))

BG_HORIZONTAL_LENGTH_X_RE = re.compile(r'background-position-x(%s:%s)'
                                        '(%s)' % (csslex.WHITESPACE,
                                                  csslex.WHITESPACE,
                                                  LENGTH))

# Matches the opening of a body selector.
BODY_SELECTOR = r'body%s{%s' % (csslex.WHITESPACE, csslex.WHITESPACE)

# Matches anything up until the closing of a selector.
CHARS_WITHIN_SELECTOR = r'[^\}]*?'

# Matches the direction property in a selector.
DIRECTION_RE = r'direction%s:%s' % (csslex.WHITESPACE, csslex.WHITESPACE)

# These allow us to swap "ltr" with "rtl" and vice versa ONLY within the
# body selector and on the same line.
BODY_DIRECTION_LTR_RE = re.compile(r'(%s)(%s)(%s)(ltr)' %
                                   (BODY_SELECTOR, CHARS_WITHIN_SELECTOR,
                                    DIRECTION_RE),
                                   re.I)
BODY_DIRECTION_RTL_RE = re.compile(r'(%s)(%s)(%s)(rtl)' %
                                   (BODY_SELECTOR, CHARS_WITHIN_SELECTOR,
                                    DIRECTION_RE),
                                   re.I)


# Allows us to swap "direction:ltr" with "direction:rtl" and
# vice versa anywhere in a line.
DIRECTION_LTR_RE = re.compile(r'%s(ltr)' % DIRECTION_RE)
DIRECTION_RTL_RE = re.compile(r'%s(rtl)' % DIRECTION_RE)

# We want to be able to switch left with right and vice versa anywhere
# we encounter left/right strings, EXCEPT inside the background:url(). The next
# two regexes are for that purpose. We have alternate IN_URL versions of the
# regexes compiled in case the user passes the flag that they do
# actually want to have left and right swapped inside of background:urls.
LEFT_RE = re.compile('%s((?:top|bottom)?)(%s)%s%s' % (LOOKBEHIND_NOT_LETTER,
                                                      LEFT,
                                                      LOOKAHEAD_NOT_CLOSING_PAREN,
                                                      LOOKAHEAD_NOT_OPEN_BRACE),
                     re.I)
RIGHT_RE = re.compile('%s((?:top|bottom)?)(%s)%s%s' % (LOOKBEHIND_NOT_LETTER,
                                                       RIGHT,
                                                       LOOKAHEAD_NOT_CLOSING_PAREN,
                                                       LOOKAHEAD_NOT_OPEN_BRACE),
                      re.I)
LEFT_IN_URL_RE = re.compile('%s(%s)%s' % (LOOKBEHIND_NOT_LETTER,
                                          LEFT,
                                          LOOKAHEAD_FOR_CLOSING_PAREN),
                            re.I)
RIGHT_IN_URL_RE = re.compile('%s(%s)%s' % (LOOKBEHIND_NOT_LETTER,
                                           RIGHT,
                                           LOOKAHEAD_FOR_CLOSING_PAREN),
                             re.I)
LTR_IN_URL_RE = re.compile('%s(%s)%s' % (LOOKBEHIND_NOT_LETTER,
                                         LTR,
                                         LOOKAHEAD_FOR_CLOSING_PAREN),
                           re.I)
RTL_IN_URL_RE = re.compile('%s(%s)%s' % (LOOKBEHIND_NOT_LETTER,
                                         RTL,
                                         LOOKAHEAD_FOR_CLOSING_PAREN),
                           re.I)

COMMENT_RE = re.compile('(%s)' % csslex.COMMENT, re.I)

NOFLIP_TOKEN = r'\@noflip'
# The NOFLIP_TOKEN inside of a comment. For now, this requires that comments
# be in the input, which means users of a css compiler would have to run
# this script first if they want this functionality.
NOFLIP_ANNOTATION = r'/\*%s%s%s\*/' % (csslex.WHITESPACE,
                                       NOFLIP_TOKEN,
                                       csslex. WHITESPACE)

# After a NOFLIP_ANNOTATION, and within a class selector, we want to be able
# to set aside a single rule not to be flipped. We can do this by matching
# our NOFLIP annotation and then using a lookahead to make sure there is not
# an opening brace before the match.
NOFLIP_SINGLE_RE = re.compile(r'(%s%s[^;}]+;?)' % (NOFLIP_ANNOTATION,
                                                   LOOKAHEAD_NOT_OPEN_BRACE),
                              re.I)

# After a NOFLIP_ANNOTATION, we want to grab anything up until the next } which
# means the entire following class block. This will prevent all of its
# declarations from being flipped.
NOFLIP_CLASS_RE = re.compile(r'(%s%s})' % (NOFLIP_ANNOTATION,
                                           CHARS_WITHIN_SELECTOR),
                             re.I)

# border-radis properties and their values
BORDER_RADIUS_TOKENIZER_RE = re.compile(r'((?:%s)?border-radius%s:[^;}]+;?)' % (csslex.IDENT,
                                                                                csslex.WHITESPACE),
                                        re.I)

# CSS gradients can't be expressed in normal regular expressions, since they
# can contain nested parentheses. So we emulate a re.sub-like function here.

class MatchLike:
  def __init__(self, match):
    self.match = match
  
  def group(self, group_number):
    return self.match


GRADIENT_RE = re.compile(r'%s[\.-]gradient%s\(' % (csslex.IDENT, csslex.WHITESPACE), re.I)

class GradientMatcher:
  def sub(self, match_function, input_string):
    output = []
    m = GRADIENT_RE.search(input_string)
    while m:
      paren_count = 1
      index = m.end(0)
      while paren_count > 0:
        if input_string[index] == '(':
          paren_count += 1
        elif input_string[index] == ')':
          paren_count -= 1
        index += 1
      # Here, index would point to the character after the matching closing parenthesis
      replacement = match_function(MatchLike(input_string[m.start(0):index]))

      output.append(input_string[:m.start(0)] + replacement)
      input_string = input_string[index:]
      m = GRADIENT_RE.search(input_string)
    return ''.join(output)+input_string


class Tokenizer:
  """Replaces any CSS comments with string tokens and vice versa."""

  def __init__(self, token_re, token_string):
    """Constructor for the Tokenizer.

    Args:
      token_re: A regex for the string to be replace by a token.
      token_string: The string to put between token delimiters when tokenizing.
    """
    logging.debug('Tokenizer::init token_string=%s' % token_string)
    self.token_re = token_re
    self.token_string = token_string
    self.originals = []

  def Tokenize(self, line):
    """Replaces any string matching token_re in line with string tokens.

    By passing a function as an argument to the re.sub line below, we bypass
    the usual rule where re.sub will only replace the left-most occurrence of
    a match by calling the passed in function for each occurrence.

    Args:
      line: A line to replace token_re matches in.

    Returns:
      line: A line with token_re matches tokenized.
    """
    line = self.token_re.sub(self.TokenizeMatches, line)
    logging.debug('Tokenizer::Tokenize returns: %s' % line)
    return line

  def DeTokenize(self, line):
    """Replaces tokens with the original string.

    Args:
      line: A line with tokens.

    Returns:
      line with any tokens replaced by the original string.
    """

    # Put all of the comments back in by their comment token.
    for i, original in enumerate(self.originals):
      token = '%s%s_%s%s' % (TOKEN_DELIMITER, self.token_string, i + 1,
                             TOKEN_DELIMITER)
      line = line.replace(token, original)
      logging.debug('Tokenizer::DeTokenize i:%s w/%s' % (i, token))
    logging.debug('Tokenizer::DeTokenize returns: %s' % line)
    return line

  def TokenizeMatches(self, m):
    """Replaces matches with tokens and stores the originals.

    Args:
      m: A match object.

    Returns:
      A string token which replaces the CSS comment.
    """
    logging.debug('Tokenizer::TokenizeMatches %s' % m.group(1))
    self.originals.append(m.group(1))
    return '%s%s_%s%s' % (TOKEN_DELIMITER,
                          self.token_string,
                          len(self.originals),
                          TOKEN_DELIMITER)


def FixBodyDirectionLtrAndRtl(line):
  """Replaces ltr with rtl and vice versa ONLY in the body direction.

  Args:
    line: A string to replace instances of ltr with rtl.
  Returns:
    line with direction: ltr and direction: rtl swapped only in body selector.
    line = FixBodyDirectionLtrAndRtl('body { direction:ltr }')
    line will now be 'body { direction:rtl }'.
  """

  line = BODY_DIRECTION_LTR_RE.sub('\\1\\2\\3%s' % TMP_TOKEN, line)
  line = BODY_DIRECTION_RTL_RE.sub('\\1\\2\\3%s' % LTR, line)
  line = line.replace(TMP_TOKEN, RTL)
  logging.debug('FixBodyDirectionLtrAndRtl returns: %s' % line)
  return line


def FixLeftAndRight(line):
  """Replaces left with right and vice versa in line.

  Args:
    line: A string in which to perform the replacement.

  Returns:
    line with left and right swapped. For example:
    line = FixLeftAndRight('padding-left: 2px; margin-right: 1px;')
    line will now be 'padding-right: 2px; margin-left: 1px;'.
  """

  line = LEFT_RE.sub("\\1" + TMP_TOKEN, line)
  line = RIGHT_RE.sub("\\1" + LEFT, line)
  line = line.replace(TMP_TOKEN, RIGHT)
  logging.debug('FixLeftAndRight returns: %s' % line)
  return line


def FixLeftAndRightInUrl(line):
  """Replaces left with right and vice versa ONLY within background urls.

  Args:
    line: A string in which to replace left with right and vice versa.

  Returns:
    line with left and right swapped in the url string. For example:
    line = FixLeftAndRightInUrl('background:url(right.png)')
    line will now be 'background:url(left.png)'.
  """

  line = LEFT_IN_URL_RE.sub(TMP_TOKEN, line)
  line = RIGHT_IN_URL_RE.sub(LEFT, line)
  line = line.replace(TMP_TOKEN, RIGHT)
  logging.debug('FixLeftAndRightInUrl returns: %s' % line)
  return line


def FixLtrAndRtlInUrl(line):
  """Replaces ltr with rtl and vice versa ONLY within background urls.

  Args:
    line: A string in which to replace ltr with rtl and vice versa.

  Returns:
    line with left and right swapped. For example:
    line = FixLtrAndRtlInUrl('background:url(rtl.png)')
    line will now be 'background:url(ltr.png)'.
  """

  line = LTR_IN_URL_RE.sub(TMP_TOKEN, line)
  line = RTL_IN_URL_RE.sub(LTR, line)
  line = line.replace(TMP_TOKEN, RTL)
  logging.debug('FixLtrAndRtlInUrl returns: %s' % line)
  return line


def FixCursorProperties(line):
  """Fixes directional CSS cursor properties.

  Args:
    line: A string to fix CSS cursor properties in.

  Returns:
    line reformatted with the cursor properties substituted. For example:
    line = FixCursorProperties('cursor: ne-resize')
    line will now be 'cursor: nw-resize'.
  """

  line = CURSOR_EAST_RE.sub('\\1' + TMP_TOKEN, line)
  line = CURSOR_WEST_RE.sub('\\1e-resize', line)
  line = line.replace(TMP_TOKEN, 'w-resize')
  logging.debug('FixCursorProperties returns: %s' % line)
  return line


def FixBorderRadius(line):
  """Fixes border-radius and its browser-specific variants.

  Args:
    line: A string to fix border-radius in.

  Returns:
    line reformatted with the border-radius values rearranged. For example:
    line = FixBorderRadius('border-radius: 1px 2px 3px 4px / 5px 6px 7px')
    line will now be 'border-radius: 2px 1px 4px 3px / 6px 5px 6px 7px'.
  """
  line = BORDER_RADIUS_RE.sub(ReorderBorderRadius, line)
  logging.debug('FixBorderRadius returns: %s' % line)
  return line


def FixFourPartNotation(line):
  """Fixes the second and fourth positions in 4 part CSS notation.

  Args:
    line: A string to fix 4 part CSS notation in.

  Returns:
    line reformatted with the 4 part notations swapped. For example:
    line = FixFourPartNotation('padding: 1px 2px 3px 4px')
    line will now be 'padding: 1px 4px 3px 2px'.
  """
  line = FOUR_NOTATION_QUANTITY_RE.sub('\\1 \\4 \\3 \\2', line)
  line = FOUR_NOTATION_COLOR_RE.sub('\\1\\2 \\5 \\4 \\3', line)
  logging.debug('FixFourPartNotation returns: %s' % line)
  return line


def FixBackgroundPosition(line):
  """Fixes horizontal background values in line.

  Args:
    line: A string to fix horizontal background position values in.

  Returns:
    line reformatted with the horizontal background values replaced, if possible.
    Otherwise, an exception would be raised.
  """
  line = BG_HORIZONTAL_PERCENTAGE_RE.sub(CalculateNewBackgroundPosition, line)
  line = BG_HORIZONTAL_PERCENTAGE_X_RE.sub(CalculateNewBackgroundPositionX,
                                           line)
  line = BG_HORIZONTAL_LENGTH_RE.sub(CalculateNewBackgroundLengthPosition, line)
  line = BG_HORIZONTAL_LENGTH_X_RE.sub(CalculateNewBackgroundLengthPositionX,
                                       line)
  logging.debug('FixBackgroundPosition returns: %s' % line)
  return line


def ReorderBorderRadiusPart(part):
  """Takes a list of zero to four border radius parts and returns a string of them
  reordered for bidi mirroring.
  """

  # Remove any piece which may be 'None'
  part = [piece for piece in part if piece is not None]
  
  if len(part) == 4:
    return '%s %s %s %s' % (part[1], part[0], part[3], part[2])
  elif len(part) == 3:
    return '%s %s %s %s' % (part[1], part[0], part[1], part[2])
  elif len(part) == 2:
    return '%s %s' % (part[1], part[0])
  elif len(part) == 1:
    return part[0]
  elif len(part) == 0:
    return ''
  else:
    raise Error("This can't happen!")
    

def ReorderBorderRadius(m):
  """Receives a match object for a border-radius element and reorders it
  pieces.
  """
  first_group = ReorderBorderRadiusPart(m.groups()[2:6])
  second_group = ReorderBorderRadiusPart(m.groups()[6:])
  if second_group == '':
    return '%sborder-radius%s%s' % (m.group(1),
                                    m.group(2),
                                    first_group)
  else:
    return '%sborder-radius%s%s / %s' % (m.group(1),
                                         m.group(2),
                                         first_group,
                                         second_group)
                      

def CalculateNewBackgroundPosition(m):
  """Fixes horizontal background-position percentages.

  This function should be used as an argument to re.sub since it needs to
  perform replacement specific calculations.

  Args:
    m: A match object.

  Returns:
    A string with the horizontal background position percentage fixed.
    BG_HORIZONTAL_PERCENTAGE_RE.sub(FixBackgroundPosition,
                                    'background-position: 75% 50%')
    will return 'background-position: 25% 50%'.
  """

  # The flipped value is the offset from 100%
  new_x = str(100-int(m.group(4)))

  # Since m.group(1) may very well be None type and we need a string..
  if m.group(1):
    position_string = m.group(1)
  else:
    position_string = ''

  return 'background%s%s%s%s%%%s' % (position_string, m.group(2), m.group(3),
                                     new_x, m.group(5))


def CalculateNewBackgroundPositionX(m):
  """Fixes percent based background-position-x.

  This function should be used as an argument to re.sub since it needs to
  perform replacement specific calculations.

  Args:
    m: A match object.

  Returns:
    A string with the background-position-x percentage fixed.
    BG_HORIZONTAL_PERCENTAGE_X_RE.sub(CalculateNewBackgroundPosition,
                                      'background-position-x: 75%')
    will return 'background-position-x: 25%'.
  """

  # The flipped value is the offset from 100%
  new_x = str(100-int(m.group(2)))

  return 'background-position-x%s%s%%' % (m.group(1), new_x)

BACKGROUND_POSITION_ERROR_MESSAGE = 'Unmirrorable horizonal value %s: %s\n'

# An exception created for background-position horizontal values set to
# non-zero lengths which makes them unmirrorable.
class BackgroundPositionError(Exception):
  def __init__(self, bad_length, whole_value):
    self.bad_length = bad_length
    self.whole_value = whole_value
  
  def __str__(self):
    return BACKGROUND_POSITION_ERROR_MESSAGE % (repr(self.bad_length), self.whole_value)

def WarnForBackgroundPosition(bad_length, whole_value):
  if FLAGS['ignore_bad_bgp']:
    sys.stderr.write(BACKGROUND_POSITION_ERROR_MESSAGE % (repr(bad_length), whole_value))
  else:
    raise BackgroundPositionError(bad_length, whole_value)

def CalculateNewBackgroundLengthPosition(m):
  """Fixes horizontal background-position lengths.

  This function should be used as an argument to re.sub since it needs to
  perform replacement specific calculations.

  Args:
    m: A match object.

  Returns:
    A string with the horizontal background position set to 100%, if zero. 
    Otherwise, an exception will be raised.
    BG_HORIZONTAL_LENGTH_RE.sub(CalculateNewBackgroundLengthPosition,
                                'background-position: 0px 10px')
    will return 'background-position: 100% 10px'.
  """

  # raise an exception if the length is not zero-valued
  if not ZERO_LENGTH.match(m.group(4)):
    WarnForBackgroundPosition(m.group(4), m.group(0))
    return m.group(0)

  # Since m.group(1) may very well be None type and we need a string..
  if m.group(1):
    position_string = m.group(1)
  else:
    position_string = ''

  return 'background%s%s%s100%%%s' % (position_string, m.group(2), m.group(3),
                                      m.group(5))


def CalculateNewBackgroundLengthPositionX(m):
  """Fixes background-position-x lengths.

  This function should be used as an argument to re.sub since it needs to
  perform replacement specific calculations.

  Args:
    m: A match object.

  Returns:
    A string with the background-position-x set to 100%, if zero.
    Otherwiser, an exception will be raised.
    BG_HORIZONTAL_LENGTH_X_RE.sub(CalculateNewBackgroundLengthPositionX,
                                  'background-position-x: 0')
    will return 'background-position-x: 100%'.
  """

  # raise an exception if the length is not zero-valued
  if not ZERO_LENGTH.match(m.group(2)):
    WarnForBackgroundPosition(m.group(2), m.group(0))
    return m.group(0)

  return 'background-position-x%s100%%' % m.group(1)


def ChangeLeftToRightToLeft(lines,
                            swap_ltr_rtl_in_url=None,
                            swap_left_right_in_url=None):
  """Turns lines into a stream and runs the fixing functions against it.

  Args:
    lines: An list of CSS lines.
    swap_ltr_rtl_in_url: Overrides this flag if param is set.
    swap_left_right_in_url: Overrides this flag if param is set.

  Returns:
    The same lines, but with left and right fixes.
  """

  global FLAGS

  # Possibly override flags with params.
  logging.debug('ChangeLeftToRightToLeft swap_ltr_rtl_in_url=%s, '
                'swap_left_right_in_url=%s' % (swap_ltr_rtl_in_url,
                                               swap_left_right_in_url))
  if swap_ltr_rtl_in_url is None:
    swap_ltr_rtl_in_url = FLAGS['swap_ltr_rtl_in_url']
  if swap_left_right_in_url is None:
    swap_left_right_in_url = FLAGS['swap_left_right_in_url']

  # Turns the array of lines into a single line stream.
  logging.debug('LINES COUNT: %s' % len(lines))
  line = TOKEN_LINES.join(lines)

  # Tokenize any single line rules with the /* noflip */ annotation.
  noflip_single_tokenizer = Tokenizer(NOFLIP_SINGLE_RE, 'NOFLIP_SINGLE')
  line = noflip_single_tokenizer.Tokenize(line)

  # Tokenize any class rules with the /* noflip */ annotation.
  noflip_class_tokenizer = Tokenizer(NOFLIP_CLASS_RE, 'NOFLIP_CLASS')
  line = noflip_class_tokenizer.Tokenize(line)

  # Tokenize the comments so we can preserve them through the changes.
  comment_tokenizer = Tokenizer(COMMENT_RE, 'C')
  line = comment_tokenizer.Tokenize(line)

  # Tokenize gradients since we don't want to mirror the values inside
  gradient_tokenizer = Tokenizer(GradientMatcher(), 'GRADIENT')
  line = gradient_tokenizer.Tokenize(line)

  # Here starteth the various left/right orientation fixes.
  line = FixBodyDirectionLtrAndRtl(line)

  if swap_left_right_in_url:
    line = FixLeftAndRightInUrl(line)

  if swap_ltr_rtl_in_url:
    line = FixLtrAndRtlInUrl(line)

  line = FixLeftAndRight(line)
  line = FixCursorProperties(line)

  line = FixBorderRadius(line)
  # Since FourPartNotation conflicts with BorderRadius, we tokenize border-radius properties here.
  border_radius_tokenizer = Tokenizer(BORDER_RADIUS_TOKENIZER_RE, 'BORDER_RADIUS')
  line = border_radius_tokenizer.Tokenize(line)
  line = FixFourPartNotation(line)
  line = border_radius_tokenizer.DeTokenize(line)
  
  line = FixBackgroundPosition(line)

  line = gradient_tokenizer.DeTokenize(line)

  # DeTokenize the single line noflips.
  line = noflip_single_tokenizer.DeTokenize(line)

  # DeTokenize the class-level noflips.
  line = noflip_class_tokenizer.DeTokenize(line)

  # DeTokenize the comments.
  line = comment_tokenizer.DeTokenize(line)

  # Rejoin the lines back together.
  lines = line.split(TOKEN_LINES)

  return lines

def usage():
  """Prints out usage information."""

  print 'Usage:'
  print '  ./cssjanus.py < file.css > file-rtl.css'
  print 'Flags:'
  print '  --swap_left_right_in_url: Fixes "left"/"right" string within urls.'
  print '  Ex: ./cssjanus.py --swap_left_right_in_url < file.css > file_rtl.css'
  print '  --swap_ltr_rtl_in_url: Fixes "ltr"/"rtl" string within urls.'
  print '  Ex: ./cssjanus.py --swap_ltr_rtl_in_url < file.css > file_rtl.css'
  print '  --ignore_bad_bgp: Ignores unmirrorable background-position values.'
  print '  Ex: ./cssjanus.py --ignore_bad_bgp < file.css > file_rtl.css'

def setflags(opts):
  """Parse the passed in command line arguments and set the FLAGS global.

  Args:
    opts: getopt iterable intercepted from argv.
  """

  global FLAGS

  # Parse the arguments.
  for opt, arg in opts:
    logging.debug('opt: %s, arg: %s' % (opt, arg))
    if opt in ("-h", "--help"):
      usage()
      sys.exit()
    elif opt in ("-d", "--debug"):
      logging.getLogger().setLevel(logging.DEBUG)
    elif opt == '--swap_ltr_rtl_in_url':
      FLAGS['swap_ltr_rtl_in_url'] = True
    elif opt == '--swap_left_right_in_url':
      FLAGS['swap_left_right_in_url'] = True
    elif opt == '--ignore_bad_bgp':
      FLAGS['ignore_bad_bgp'] = True


def main(argv):
  """Sends stdin lines to ChangeLeftToRightToLeft and writes to stdout."""

  # Define the flags.
  try:
    opts, args = getopt.getopt(argv, 'hd', ['help', 'debug',
                                            'swap_left_right_in_url',
                                            'swap_ltr_rtl_in_url',
                                            'ignore_bad_bgp'])
  except getopt.GetoptError:
    usage()
    sys.exit(2)

  # Parse and set the flags.
  setflags(opts)

  # Call the main routine with all our functionality.
  fixed_lines = ChangeLeftToRightToLeft(sys.stdin.readlines())
  sys.stdout.write(''.join(fixed_lines))

if __name__ == '__main__':
  main(sys.argv[1:])
