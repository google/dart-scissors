## Current development tree

...

## 0.6.8

### Features

- Added a `bidi_css` executable that exposes this package's CSS mirroring
  functionality.

## 0.6.7 (2016-12-05)

### Features

- Added Compass polyfills support for css-filters, css-placeholder, inline-block

## 0.6.7 (2016-11-08)

### Features

- scissors-sassc runner now supports Bazel.io workers (combo of `--persistent_worker` flag, `@@args_file` argument and proto-based standard input / output communication protocol with Bazel).

## 0.6.5 (2016-09-16)

### Bugfixes

- Made image inlining more robust (#53).
- Fix sass aggregate transformer (skip non-scss files)

### Features

- New dart image inliner transformer + CLI

## 0.6.4 (2016-06-30)

### Bugfixes

- Fix skipping of image inlining for unaffected files (see issue #53)

## 0.6.3 (2016-06-14)

### Bugfixes

- Fixed bidirectionalization of `@media` rules.
- Fixed race condition + some embarrassing typos in Sass settings
  (caused some includes to not be resolved)
- Merged SassC & ImageInlining transformers to avoid some errors
  "Both {SassC on ..., ImageInlining on ...} emitted the same file."
- Switched hidden onlyCompileOutOfDateSass option's default to false (caused
  pub to hang when used in combination with some other transformers)

### Features

- Removed experimental `scissors/src/checker/transformer`, which feature was
  integrated to the Dart Linter package from version 0.1.19.
- Switched some defaults around: `pruneCss: false`, `imageInlining: inlineInlinedImages`

## 0.6.2 (2016-06-02)

### Features

- Added experimental `scissors/src/checker/transformer` that detects unawaited futures.
  These extra static checks are slow, but prevent accidental fire-and-forget of
  futures within async method bodies.

## 0.6.1 (2016-05-26)

### Bugfixes

- Fixed Bidi CSS which had been wrongly simplified (issue #43)

## 0.6.0 (2016-03-16)

### Bugfixes

- Switched from a [code_transformers](pub.dartlang.org/packages/code_transformers) dependency to a [transformer_test](https://pub.dartlang.org/packages/transformer_test) dev dependency (issue #35)

## 0.5.0 (2016-03-14)

### Features

- Added a sourcemap-stripping transformer, usable standalone or in
  `scissors/permutations_transformer` with `stripSourceMaps: true` (relevant
  only when the `$dart2js` transformer has `sourceMaps: true`)
- Added [Compass polyfills](https://github.com/google/dart-scissors/blob/91bb07ab7892fdd34b40438dec015a9049641ee5/lib/compass/_polyfills.scss)
  for `prefix-usage`, `browsers`, `browser-prefixes`, `compact` (makes
  [lots of Compass mixins to work well](https://github.com/google/dart-scissors/blob/91bb07ab7892fdd34b40438dec015a9049641ee5/test/compass/polyfills_test.dart))

### Bugfixes

- CSS pruning:

  - Handle Angular2 [attr.name] and [class.name] syntaxes in CSS pruning (issues #30 & #31)
  - Skip :host rules (issue #29)

- Bidirectional CSS:

  - Fix Css mirroring to handle multiple selectors in RuleSet
  - Transformer is now an aggregate (more solid interaction with other transformers)

- Follow symlinks in path resolution logic.
- `scissors-sassc` now automatically finds compass stylesheets

## 0.4.3 (2016-03-04)

### Features

- Introduced `scissors-sassc` binary that wraps `sassc` and adds `inline-image`
  support.

## 0.4.2 (2016-03-03)

### Bugfixes

- Fixed "Bad state: Setting sasscArgs wasn't read yet." (issue #27).

## 0.4.1 (2016-01-19)

### Bugfixes

- Simplified bidirectional CSS output (issue #23): now produces smaller code.

## 0.4.0 (2016-01-19)

### Features

- Added `scissors/css_mirroring_transformer` that makes CSS files to support
  bidirectional layouts (uses [CSSJanus](https://github.com/cegov/wiki/tree/master/maintenance/cssjanus).
  Given `foo { color: blue; float: left }`, it generates:

    ```css
    foo { color: blue }
    :host-context([dir="ltr"]) foo { float: left }
    :host-context([dir="rtl"]) foo { float: right }
    ```

    So you just need the supporting code in your `main.dart` to support bidirectional layouts (see [example/mirroring](https://github.com/google/dart-scissors/tree/master/example/mirroring)):

    ```dart
    document.body.dir = Bidi.isRtlLanguage(Intl.getCurrentLocale()) ? 'rtl' : 'ltr';
    ```

  This feature is also available in the regular `scissors` transformer, but it
  must be enabled with `bidiCss: true`.

- Added `compiledCssExtension` option to control how `foo.scss` is compiled:
  `append` yields `foo.scss.css` (default), while `replace` produces `foo.css`.


### Bugfixes

- Fixed support for `-I` / `--load-path` arguments in `sasscArgs` setting (issue #21)

## 0.3.0 (2016-01-13)

### Features

- Added `scissors-sassc-compass` binary that provides a best-effort replacement
  for Compass using SassC: it processes any `inline-image` function detected,
  and falls back to using plain Compass if SassC fails to compile the input
  (or if it does not understand the command-line arguments).

### Bugfixes

- `scissors/permutations_transformer`: generate sourcemaps for permutations
  (limited to source map of main fragment; shouldn't hurt much if deferred
  parts only contain messages and template caches)

## 0.2.2 (2016-01-05)

### Bugfixes

- Systematically resolve paths from settings (for pngcrush, sassc, etc)
- `scissors/permutations_transformer`: generate permutation for `defaultLocale`
  (language in which the messages are written in the source, defaults to `en_US`)

## 0.2.1 (2015-12-14)

### Bugfixes

- Resolve files with the `.packages` file to prepare for disappearance of `packages/`.
- `scissors/transformer`: made Sass transformer really lazy.
- `scissors/permutations_transformer`: hard-fail when parts check fails (consume the `.dart.js`)
- `scissors/reloader/transformer`: added named argument `timestampBaseUrl` to `setupReloader`.

## 0.2.0 (2015-11-19)

### Features

- Added inline_images.dart entry point for standalone inlining

### Bugfixes

- Improved asset file resolution with package_name/path pattern.
- Made permutations transformer lazy

## 0.1.9 (2015-11-15)

### Features

- Added new `scissors/reloader/transformer` + runtime lib that allow instant
  reload whenever assets are updated (triggered at the end of the pub build).
  Reloader usage is erased from `release` builds by default (respecting source
  maps).
- Don't prune css in debug by default

### Bugfixes

- Sass transformer respects existing `.scss.css` input and only rebuilds them
  from the `.scss` sources when it's out of date (timestamp-based; can be
  disabled with `onlyCompileOutOfDateSass: false`).

## 0.1.8 (2015-11-14)

This version comes with a massive refactoring that splits out most features into
their own transformer. Please note that there are still only
3 officially-supported transformer entry points:

- `scissors/transformer` (lazy Sass compilation, CSS and image optimizations)
- `scissors/eager_transformer` (eager version of the previous: builds all the
  assets upfront when pub serve is run)
- `scissors/permutations_transformer` (lazy locale-specific permutations with
  optional Closure Compilation to reoptimize the outputs)

### Bugfixes

- Permutations transformer (`scissors/permutations_transformer`):

  - Permutations are now built lazily (fixes `pub serve` + Dartium experience)
  - Disabled `reoptimizePermutations` by default
  - Respect `javaPath` when running the Closure Compiler.
  - Added `expectedPartCounts` check (takes a map of `.dart.js` script path to
    number of expected parts, see [example/permutations](https://github.com/google/dart-scissors/tree/master/example/permutations))

- Fixed path resolution regression (dotted package names)

## 0.1.7 (2015-11-12)

### Bugfixes

- Fixed image linking (`imageInlining: linkInlinedImages`), with a new
  `packageRewrites` setting (with `fromPattern,toReplacement` syntax; defaults
  to `^package:,packages/`, which works well with pub serve).
- Fixed usage of `pngCrushPath` setting.

## 0.1.6 (2015-11-12)

### Bugfixes

- Fixed support of wildcard `*` CSS rules.

### Features

- Added support for LTR/RTL-specific parts in
  `scissors/permutations_transformer` (see [example/permutations](https://github.com/google/dart-scissors/tree/master/example/permutations)).

## 0.1.5 (2015-11-12)

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

## 0.1.4 (2015-10-30)

### Bugfixes

- Cleaner path resolution logic (easier to override)
- Stricter regexp in recursive sass imports consumer

## 0.1.3 (2015-10-28)

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

## 0.1.2 (2015-10-26)

### Features

* Improved [sassc](https://github.com/sass/sassc) integration:

  * Resolving `${FOO}` environment variables in `sasscPath` and `sasscArgs` settings
  * Automatically set `--load-path` arguments with list of root directories, with clean
    fork point (`path_resolver.dart`)
  * Output css sourcemaps

## 0.1.1 (2015-10-23)

### Features

* Preliminary support for compiling `*.scss` and `*.sass` files with
  [sassc](https://github.com/sass/sassc).

## 0.1.0 (2015-10-22)

### Features

* Basic support for .css pruning based on companion .html template or inlined templates in companion .dart file (Angular1 and Angular2)
* Support for `ng-class` and interpolated name fragments inside `class` in templates
