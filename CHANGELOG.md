# Current development tree

### Features

- The transformer is now lazy by default, which speeds up startup time of
  `pub serve` (use `scissors/eager_transformer` to force eager transform)
- Sass compilation supports Compass's
  [inline-image](http://compass-style.org/reference/compass/helpers/inline-data/)
  helper to inline images.
- Rebuilds `.css` files when any transitive `.sass` import is modified:
  - Requires `pub serve --force-poll`
  - The default (lazy) transformer will just invalidate stale resources, while
    `scissors/eager_transformer` will eagerly rebuild them.

<a name="0.1.2"></a>
# 0.1.2 (2015-10-26)

### Features

* Improved [sassc](https://github.com/sass/sassc) integration:
  * Resolving `${FOO}` environment variables in `sasscPath` and `sasscArgs` settings
  * Automatically set `--load-path` arguments with list of root directories, with clean
    fork point (`path_resolver.dart`)
  * Output css sourcemaps

<a name="0.1.1"></a>
# 0.1.1 (2015-10-23)

### Features

* Preliminary support for compiling `*.scss` and `*.sass` files with
  [sassc](https://github.com/sass/sassc).

<a name="0.1.0"></a>
# 0.1.0 (2015-10-22)

### Features

* Basic support for .css pruning based on companion .html template or inlined templates in companion .dart file (Angular1 and Angular2)
* Support for `ng-class` and interpolated name fragments inside `class` in templates
