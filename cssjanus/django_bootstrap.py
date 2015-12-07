"""Bootstrap for running a Django app."""

# Standard Python imports.
import os
import sys
import logging
import __builtin__

# Google App Hosting imports.
from google.appengine.ext.webapp import util

# Remove the standard version of Django before using it.
for k in [k for k in sys.modules if k.startswith('django')]:
  del sys.modules[k]

# Force sys.path to have our own directory first, in case we want to import
# from it.
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

import pickle
sys.modules['cPickle'] = pickle

# Enable info logging by the app (this is separate from appserver's
# logging).
logging.getLogger().setLevel(logging.INFO)

# Force sys.path to have our own directory first, so we can import from it.
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

# Must set this env var *before* importing any part of Django.
os.environ['DJANGO_SETTINGS_MODULE'] = 'django_settings'

# Make sure we can import Django.  We may end up needing to do this
# little dance, courtesy of Google third-party versioning hacks.  Note
# that this patches up sys.modules, so all other code can just use
# "from django import forms" etc.
try:
  from django import v0_96 as django
except ImportError:
  pass

# Import the part of Django that we use here.
import django.core.handlers.wsgi

def main():
  # Create a Django application for WSGI.
  application = django.core.handlers.wsgi.WSGIHandler()

  # Run the WSGI CGI handler with that application.
  util.run_wsgi_app(application)

if __name__ == '__main__':
  main()
