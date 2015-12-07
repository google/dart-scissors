#!/usr/bin/python2.5
#
# Copyright 2007 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License.  You may obtain a copy
# of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

"""Session backend for Django that uses the DataStore."""

__author__ = 'damonkohler@google.com (Damon Kohler)'

import datetime

from django.conf import settings
from django.contrib.sessions.backends.base import SessionBase
from django.core.exceptions import SuspiciousOperation

from google.appengine.ext import db


class Session(db.Model):

  """Django provides full support for anonymous sessions.

  The session framework lets you store and retrieve arbitrary data on a
  per-site-visitor basis. It stores data on the server side and abstracts the
  sending and receiving of cookies. Cookies contain a session ID -- not the
  data itself.

  The Django sessions framework is entirely cookie-based. It does not fall back
  to putting session IDs in URLs. This is an intentional design decision. Not
  only does that behavior make URLs ugly, it makes your site vulnerable to
  session-ID theft via the "Referer" header.

  For complete documentation on using Sessions in your code, consult the
  sessions documentation that is shipped with Django (also available on the
  Django website).

  """
  session_key = db.StringProperty()
  session_data = db.StringProperty(multiline=True)
  expire_date = db.DateTimeProperty()


class SessionStore(SessionBase):

  """Implements DataStore session store."""

  def __init__(self, session_key=None):
    super(SessionStore, self).__init__(session_key)

  def load(self):
    try:
      s = Session.gql('WHERE session_key = :1 AND expire_date > :2 LIMIT 1',
                      self.session_key, datetime.datetime.now())[0]
      return self.decode(s.session_data)
    except (IndexError, SuspiciousOperation):
      # Create a new session_key for extra security.
      self.session_key = self._get_new_session_key()
      self._session_cache = {}
      # Save immediately to minimize collision
      self.save()
      # Ensure the user is notified via a new cookie.
      self.modified = True
      return {}

  def exists(self, session_key):
    sessions = Session.gql('WHERE session_key = :1 LIMIT 1', session_key)
    return bool(list(sessions))

  def save(self):
    s = Session(key_name='session_' + self.session_key)
    s.session_key = self.session_key
    s.session_data = self.encode(self._session)
    s.expire_date = (datetime.datetime.now() +
                     datetime.timedelta(seconds=settings.SESSION_COOKIE_AGE))
    s.put()

  def delete(self, session_key):
    try:
      Session.gql('WHERE session_key = :1 LIMIT 1')[0].delete()
    except IndexError:
      pass
