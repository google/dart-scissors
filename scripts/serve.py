#!/usr/bin/env python
# https://gist.github.com/ochafik/9929ec51d3c4d3d613b71b5f5b45130b
# For SPDY / HTTP2 push:
# https://w3c.github.io/preload/
# https://github.com/eigengo/opensourcejournal/blob/master/2014.1/spdynetty/spdynetty.md

import getopt
import os
import re
import sys
import threading
import urllib

from SimpleHTTPServer import SimpleHTTPRequestHandler
from BaseHTTPServer import HTTPServer, BaseHTTPRequestHandler
from SocketServer import ThreadingMixIn

# Example usage:
#
#   ./scripts/serve.py --push -p 8080 -r example/angular2/packages -v example/angular2/web@/
#

# List of (served_path, served_path_with_slash, directory) tuples.
served_directories = []
# List of directories from which packages should be resolved.
root_directories = []
verbose = False
push_imported_files = False
gzip = False

def main():
    global served_directories
    global root_directories
    global verbose
    global push_imported_files

    port = 8080
    hostname = '0.0.0.0'
    # The bazel root directory.
    bazel_root = os.getcwd()
    try:
        opts, args = getopt.getopt(
            sys.argv[1:],
            "p:r:vg",
            [
              "verbose",
              "port=",
              "root=",
              "add-relative-root=",
              "hostname",
              "gzip",
              "push"
            ])
    except getopt.GetoptError as err:
        print str(err)
        sys.exit(2)

    # See http://www.bazel.io/docs/output_directories.html
    relative_roots = [
      "blaze-genfiles",
      "blaze-bin",
      "blaze-out",
      "bazel-genfiles",
      "bazel-bin",
      "bazel-out",
      "../READONLY",
    ]
    for o, a in opts:
        if o in ("-v", "--verbose"):
            verbose = True
        elif o in ("-p", "--port"):
            port = int(a)
        elif o == "--push":
            push_imported_files = True
        elif o == "--hostname":
            hostname = a
        elif o in ("-r", "--root"):
            bazel_root = a
        elif o in ("-z", "--gzip"):
            gzip = True
        elif o in ("--add-relative-root"):
            relative_roots.append(a)
        else:
            assert False, "unhandled option"

    for arg in args:
      parts = arg.split("@")
      if len(parts) == 2:
          [directory, served_path] = parts
      else:
          [directory] = parts
          served_path = "/"

      if served_path == "/":
          served_path_with_slash = served_path
      elif served_path.endswith("/"):
          served_path_with_slash = served_path
          served_path = served_path[:-1]
      else:
          served_path_with_slash = served_path + "/"

    #   directory = os.path.relpath(directory, bazel_root)
      served_directories.append((served_path, served_path_with_slash, directory))

    root_directories.append(bazel_root)
    for sub in relative_roots:
        dir = os.path.join(bazel_root, sub)
        if os.path.isdir(dir):
            root_directories.append(dir)

    if verbose:
        print "Served dirs:", served_directories
        print "  Root dirs: ", root_directories

    print 'Starting server, use <Ctrl-C> to stop'
    ThreadedHTTPServer((hostname, port), DartRequestHandler).serve_forever()

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    """Handle requests in a separate thread."""

    daemon_threads = True
    allow_reuse_address = True

dart_package_re = re.compile('^(.*?/package(?:s/|:))([^/]+)/(.*)$')
# TODO(ochafik): Handle DDC ES6 modules preloading.
# dart_package_uri_re = re.compile('package:([^/]+)/(.*?)')
dart_import_re = re.compile('import\s*[\'"]([^:\'"]+|package:[^\'"]+)[\'"]', re.MULTILINE)

ddc_import_re = re.compile("dart_library\.library\([^,]+,[^,]+,.*?\[([^\]]*)\],.*?\[([^\]]*)\]", re.MULTILINE)
# ddc_import_re = re.compile("dart_library\\.library\\('[^']+', null, /\\* Imports \\*/\[([^\]])], /\\* Lazy imports \\*/\[([^\]])]", re.MULTILINE)

class DartRequestHandler(SimpleHTTPRequestHandler):

    resolved_paths = {}

    def resolve_path(self):
        global served_directories
        global verbose

        if self.path in self.resolved_paths:
            resolved_path = self.resolved_paths[self.path];
            if os.path.exists(resolved_path):
                return resolved_path

        path = urllib.unquote(self.path)

        candidates = []
        m = dart_package_re.match(path)
        if m:
            file = os.path.join(m.group(2).replace(".", "/"), "lib", m.group(3))
            candidates += [
              file,
              os.path.join("third_party", "dart", file),
            ]
        else:
            for served_path, served_path_with_slash, directory in served_directories:
                if path == served_path:
                    candidates.append(os.path.join(directory, "index.html"))
                    break
                elif path.startswith(served_path_with_slash):
                    candidates.append(os.path.join(directory, path[len(served_path_with_slash):]))
                    break


        if verbose:
            print "Path: ", self.path
            print "Candidates: ", ", ".join(candidates)
        file = self.find_file(candidates)
        if file:
            self.resolved_paths[self.path] = file
        return file

    def do_GET(self):
        global served_directories
        global verbose

        file = self.resolve_path()
        if file:
            etag = "\"%s\"" % int(os.path.getmtime(file))
            if self.headers.get('If-None-Match', None) == etag:
                self.send_response(304)
                self.end_headers()
                return

            content_type = 'application/dart' if file.endswith(".dart") else self.guess_type(file)
            # Don't open as text as file size wouldn't match if newlines are modified
            mode = 'r' if push_imported_files else 'rb'

            try:
                # Try to open the file 3 times
                # TODO(ochafik): Print / understand errors (fuse-specific?).
                try:
                    f = open(file, mode)
                except IOError:
                    try:
                        f = open(file, mode)
                    except IOError:
                        f = open(file, mode)

                if push_imported_files or gzip:
                    # Server push for Dart sources.
                    content = f.read()
                    f.close()

                    links = []
                    if push_imported_files:
                        if file.endswith(".dart"):
                            links += self.get_dart_preload_links(file, content)
                        elif file.endswith(".js"):
                            links += self.get_js_preload_links(file, content)

                    self.send_response(200)
                    if gzip:
                        content = self.gzipencode(content)
                    self.send_header("Content-Length", len(content))
                    self.send_header("Content-Type", content_type)
                    self.send_header("ETag", etag)
                    if len(links) > 0:
                        links = set([os.path.normpath(l) for l in links])
                        self.send_header("Link", ", ".join(links))
                        if verbose:
                            print "Links for ", self.path, ":\n\t", "\n\t".join(links)
                    self.end_headers()
                    self.wfile.write(content)

                    if gzip:
                        self.send_header("Content-Encoding", "gzip")
                    self.wfile.flush()
                    # self.wfile.close();
                    f.close()
                else:
                    self.send_response(200)
                    self.send_header("Content-Length", os.fstat(f.fileno()).st_size)
                    self.send_header("Content-Type", content_type)
                    self.send_header("ETag", etag)
                    self.end_headers()
                    self.copyfile(f, self.wfile)
                    self.wfile.flush()
                    f.close()
                return
            except IOError:
                self.send_error(404, "File not found: " + file)

        self.send_error(404, "File not found")

    def get_packages_base(self):
        path = self.path
        m = dart_package_re.match(path)
        return m.group(1) if m else os.path.join(os.path.dirname(path), "packages/")

    def find_file(self, candidates):
        global root_directories
        for root_directory in root_directories:
            for candidate in candidates:
                file = os.path.join(root_directory, candidate)
                if os.path.exists(file):
                    return file
        return None

    def get_js_preload_links(self, file, content):
        links = []
        links += self.get_es6_import_preload_links(file, content)
        links += self.get_ddc_js_preload_links(file, content)
        # TODO(ochafik): Closure imports?
        return links

    # For ES6 and TypeScript
    def get_es6_import_preload_links(self, file, content):
        links = []
        # TODO(ochafik)
        return links

    def get_ddc_js_preload_links(self, file, content):
        links = []
        m = ddc_import_re.match(content)
        dir = os.path.dirname(file)
        base_path = os.path.dirname(self.path)
        if m:
            for import_list in [m.group(1), m.group(2)]:
                for item in import_list.split(","):
                    item = item.strip()
                    if item.startswith("'") and item.endswith("'"):
                        module_file = item[1:-1] + ".js"
                        candidates = [module_file]
                        if dir.endswith("/dev_compiler/runtime/dart"):
                            # Inside sdk already,
                            candidates += [os.path.join("..", module_file)]
                        else:
                            # Before reaching out for the correct dart/ file, try and return the SDK.
                            candidates += [
                              os.path.join("dev_compiler", "runtime", "dart_sdk.js"),
                              os.path.join("dev_compiler", "runtime", module_file)
                            ]
                        for candidate in candidates:
                            #print "EXISTS? ", os.path.join(dir, candidate)
                            if os.path.exists(os.path.join(dir, candidate)):
                                links.append(script_preload_link(os.path.join(base_path, candidate)))
                                break

        return links

    def get_angular_dart_preload_links(self, file, content):
        # TODO(ochafik): Parse actual templateUrl and scriptUrl instead of this poor heuristic.
        companions = [
            file[:-len(".dart")] + ".html",
            file[:-len(".dart")] + ".css",
            file[:-len(".dart")] + ".scss.css",
        ]
        base_path = os.path.dirname(self.path)
        return [
          script_preload_link(os.path.join(base_path, os.path.basename(companion)))
          for companion in companions
          if os.path.exists(companion)
        ]

    def get_dart_preload_links(self, file, content):
        links = []
        links += self.get_angular_dart_preload_links(file, content)

        for dart_import_m in dart_import_re.finditer(content):
            dart_import = dart_import_m.group(1)
            packages_base = self.get_packages_base()
            link = None
            if dart_import.startswith("package:"):
               link = os.path.join(packages_base, dart_import[len("package:"):])
            else:
               link = os.path.join(os.path.dirname(self.path), dart_import)
            #links.append("<%s>; rel=preload; as=script" % link)
            links.append("<%s>; rel=preload" % link)

        return links

def script_preload_link(url):
    # return "<%s>; rel=preload" % url
    return "<%s>; rel=preload; as=script" % url

if __name__ == "__main__":
    main()
