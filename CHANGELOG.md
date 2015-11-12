# Current development tree

### Bugfixes

- Fixed image linking (`imageInlining: linkInlinedImages`), with a new
  `packageRewrites` setting (with `fromPattern,toReplacement` syntax; defaults
  to `^package:,packages/`, which works well with pub serve).
- Fixed usage of `pngCrushPath` setting.

<a name="0.1.6"></a>
# 0.1.6 (2015-11-12)

### Bugfixes

- Fixed support of wildcard `*` CSS rules.

### Features

- Added support for LTR/RTL-specific parts in
  `scissors/permutations_transformer` (see [example/permutations](https://github.com/google/dart-scissors/tree/master/example/permutations)).

<a name="0.1.5"></a>
# 0.1.5 (2015-11-12)

### Bugfixes

- Fixed base64 format in `inline-image`

### Features

- Added experimental SVG optimization (poor-man heuristics, enabled in release,
  disable with `optimizeSvg: false`)
- Added experimental PNG optimization relying on `pngcrush` (enabled in release,
  disable with `optimizePng: false`, provide path to `pngcrush` with
  `pngCrushPath: path/to/pngcrush`)
- Added `imageInlining` setting to control image inlining inside CSS files,
  accepts values:
  - `inlineAllUrls`: inlines `inline-image` *and* `url` references
  - `inlineInlinedImages`: inlines `inline-image` only (default in `release`
    mode)
  - `linkInlinedImages`: rewrites `inline-image` references into `url`
    references (default in `debug` mode): images are not inlined.
  - `disablePass`: don't touch `inline-image` references (may produce invalid
    CSS).
- Added experimental `scissors/permutations_transformer` transformer that
  generates locale-specific .js artefacts when using defer-loaded messages
  (package:intl).

<a name="0.1.4"></a>
# 0.1.4 (2015-10-30)

### Bugfixes

- Cleaner path resolution logic (easier to override)
- Stricter regexp in recursive sass imports consumer

<a name="0.1.3"></a>
# 0.1.3 (2015-10-28)

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
