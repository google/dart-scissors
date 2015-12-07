#!/usr/bin/python
#
# Copyright 2008 Google Inc. All Rights Reserved.

__author__ = 'elsigh@google.com (Lindsey Simon)'

import os
from django.conf.urls.defaults import *

urlpatterns = patterns('',
  (r'^i18n/', include('django.conf.urls.i18n')),
  (r'^$', 'django_cssjanus.index'),
  (r'^do/', 'django_cssjanus.do'),
  (r'^\/?files/(?P<path>.*)$', 'django.views.static.serve', 
    {'document_root': os.path.abspath(os.path.dirname(__file__))}),
)
