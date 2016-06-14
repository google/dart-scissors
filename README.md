# sCiSSors [![Build Status](https://travis-ci.org/google/dart-scissors.svg?branch=master)](https://travis-ci.org/google/dart-scissors) [![Pub Package](https://img.shields.io/pub/v/scissors.svg)](https://pub.dartlang.org/packages/scissors)
**Smarter resources for Angular apps: CSS pruning, bidirectional layouts, SVG & PNG optimization, Sass compilation, locale permutations, automatic reload.**

_Disclaimer_: This is not an official Google product.

# Features

All of the following features are _lazy_ (only triggered when needed) and
most of them are disabled or optimized for speed with `pub serve` in debug mode.
(note: may need `pub serve --force-poll` on MacOS X)

- CSS pruning for Angular (see [example/angular1](https://github.com/google/dart-scissors/tree/master/example/angular1), [example/angular2](https://github.com/google/dart-scissors/tree/master/example/angular2)):
  - Finds which .css rules are not used by Angular templates and removes them.
  - Supports `ng-class` and `class` with programmatic interpolated fragments
    (e.g. `class="some-{{fragmented}}-class and-some-normal-class"`,
    `ng-class="{'some-class': isSome}"`).
  - Disabled by default in debug mode.
- CSS mirroring / bidirectionalization that works with Angular2's transformer:
  - Uses CSSJanus to produce a single CSS file that supports both RTL & LTR layouts!
  - Given `foo { color: blue; float: left }`, it generates:

    ```css
    foo { color: blue; }
    :host-context([dir="ltr"]) foo { float: left }
    :host-context([dir="rtl"]) foo { float: right }
    ```

    So you just need the supporting code in your `main.dart` to support bidirectional layouts (see [example/mirroring](https://github.com/google/dart-scissors/tree/master/example/mirroring)):

    ```dart
    document.body.dir = Bidi.isRtlLanguage(Intl.getCurrentLocale()) ? 'rtl' : 'ltr';
    ```

- [Sass](http://sass-lang.com) compilation:
  - Compiles `*.sass` and `*.scss` files with [`sassc`](https://github.com/sass/sassc),
    the lightning-fast C++ port of Ruby Sass.
  - Rebuilds `.css` files whenever their `.sass` sources are modified.
- Image inlining:
  - Expands [inline-image](http://compass-style.org/reference/compass/helpers/inline-data/)
    calls in CSS files into data URI links, like Compass does.
  - By default in debug mode, links to images instead of inlining them.
- PNG optimization:
  - Calls `pngcrush` to remove all metadata that is useless for rendering.
  - Disabled by default in debug mode.
- SVG optimization:
  - Removes comments, doctypes, unused namespaces.
  - Disabled by default in debug mode.
- Locale-specific permutations generation (Optional, see [example/permutations](https://github.com/google/dart-scissors/tree/master/example/permutations)):
  - Generates one .js per locale (e.g. `main_en.js`, `main_fr.js`...) with the
    deferred parts needed for that locale, which speeds up load time.
  - Supports deferred messages and deferred LTR/RTL template caches.
  - Optionally optimizes the resulting `.js` files with the Closure Compiler.
- Automatic reload support (Optional): zero-turnaround for Dart!
- [Experimental static checker](UnawaitedFutures.md) that detects unawaited futures
  (a common cause of sneaky bugs in async code):

# Usage

## Defaults vs. debug vs. release

sCiSSors is fine-tuned for fast build in `debug` mode (default for `pub serve`)
and small code size in `release` mode (default for `pub build`).

Its behaviour can be fully customized through transformer settings in
`pubspec.yaml`.
For instance, to enable PNG optimizations in all modes, and enable SVG
optimizations in `debug` only:

```yaml
transformers:
- scissors:
    optimizePng: true
    release:
        optimizeSvg: false
    debug:
        optimizeSvg: true
```

## Prerequisites

If you checked out `scissors`'s sources, you can run `. ./script/install_dependencies.sh` to get all the required dependencies, and skip the rest of this section :-)

### Installing CSSJanus

You'll need a local install of [CSSJanus](https://github.com/cegov/wiki/tree/master/maintenance/cssjanus) for CSS mirroring.

Note that this transformer uses Google's original cssjanus.py, not its .js port ([github.com/cssjanus/cssjanus](https://github.com/cssjanus/cssjanus), which might work if packaged as a binary that consumes css from stdin and outputs mirrored css on stdout).

To install CSSJanus, run the following command in a console (ensure you have something like `export PATH=~/bin:$PATH` in your `~/.profile` or `~/.bashrc`):

  ```
  mkdir ~/bin
  curl http://cssjanus.googlecode.com/svn/trunk/cssjanus.py > ~/bin/cssjanus.py
  chmod +x ~/bin/cssjanus.py
  ```

### Other deps: SassC, pngcrush...

These packages are quite standard, you can get them with `brew install` on MacOS X and with `sudo apt-get install` on Ubuntu:
- `sassc`
- `pngcrush`

## Using the `scissors` transformer

The default transformer will build Sass files in a blink of an
eye and will optimize CSS, PNG and SVG assets in `release` mode
(`pub build`).

Please only setup sCiSSors's transformer on projects you know respect sCiSSors'
conventions and limitations (see below).

Examples: see [example/angular1](https://github.com/google/dart-scissors/tree/master/example/angular1), [example/angular2](https://github.com/google/dart-scissors/tree/master/example/angular2)).

`pubspec.yaml`:

  ```
  dev_dependencies:
    scissors: ^0.6.0
  transformers:
  - scissors
  ```

Valid settings:
- `pruneCss` (boolean): `false` by default
- `imageInlining`: default is `inlineInlinedImages`
    - `inlineAllUrls`: treats `url` as `inline-image`
    - `inlineInlinedImages`: simply honours `inline-image`
    - `linkInlinedImages`: replaces `inline-image` by `url`
    - `disablePass`: leaves `inline-image` untouched
- `optimizePng` (boolean): by default, `true` in `release` only
- `optimizeSvg` (boolean): by default, `true` in `release` only
- `sasscPath`: default is `sassc`
- `compiledCssExtension`: default is `append`
    - `append`: append the `.css` extension to the SASS / SCSS file name: `foo.scss` will be compiled to `foo.scss.css`.
    - `replace`: replace the SASS / SCSS file extension by `.css`: `foo.scss` will be compiled to `foo.css`.
- `pngCrushPath`: default is `pngcrush`
- `bidiCss` (boolean): default is `false` (note that this is `true` by default in the `scissors/css_mirroring_transformer`, see below)
- `cssJanusPath`: `cssjanus.py` by default, see [prerequisites](#prerequisites)

### Limitations

- Assumes if foo.html exists, foo.css is only used from there (conventions
  matter). This means sCiSSors should be disabled or used with caution when
  using Angular2 with `ViewEncapsulation.None` (see section below).
- Very limited support of CSS rules (naive and hopefully pessimistic matching),
- Bails out of pruning as soon as it doesn't recognize the (map literal)
  syntax of an `ng-class` (or if the map has non-string-literal keys),
- Does not detect direct / handle DOM manipulations done in .dart companion
  files yet ([html:Element.classes](https://api.dartlang.org/1.12.1/dart-html/Element/classes.html), etc).
- No support for XML namespaces in CSS3 attribute selectors.
- No CSS renaming yet (just pruning for now),
- No Polymer.dart support yet.

### Style Isolation in Angular

Angular(1,2) provide the following [strategies](http://blog.thoughtram.io/angular/2015/06/29/shadow-dom-strategies-in-angular2.html):

- Shadow DOM (*default in AngularDart 1.x*), implemented by
  `ShadowDomComponentFactory` in AngularDart 1.x and `ViewEncapsulation.Native`
  in Angular2
- Shadow DOM emulation with "transclusion" (*default in Angular2*) implemented by
  `TranscludingComponentFactory` in AngularDart 1.x and `ViewEncapsulation.Emulated`
  in Angular2
- Unscoped / no Shadow DOM, implemented by `ViewEncapsulation.None` in Angular2

The first two strategies (Shadow DOM & its transcluded emulation) provide strict
encapsulation of style at the component level: styles defined in a component
do not leak to any of its sub-components or parent components. This is the
assumption by which sCiSSors lives, so you're safe with it.

The last "unscoped" strategy means there's no file- or
component-local way of deciding if a style *could* be used elsewhere. You should
not use sCiSSors on packages / projects with that strategy.

## Using `scissors/css_mirroring_transformer`

See [BidirectionalCss](BidirectionalCss.md) for more details.

Example: see [example/mirroring](https://github.com/google/dart-scissors/tree/master/example/mirroring).

`pubspec.yaml`:

  ```
  dev_dependencies:
    scissors
  transformers:
  - scissors/css_mirroring_transformer
  ```

Valid settings:
- `bidiCss` (boolean): `true` by default (Note: this is not the same default as in the `scissors` transformer)
- `originalCssDirection` (`ltr` or `rtl`): `ltr` by default, defines the direction of input css.
- `cssJanusPath`: `cssjanus.py` by default.

### Limitations

- The standalone `scissors/css_mirroring_transformer` transformer only consumes CSS files. If you need Sass support, please use the `scissors` transformer with `bidiCss: true`.
- Does not handle directives like `@keyframes` and `@page`.

## Using `scissors/permutations_transformer`

Example: see [example/permutations](https://github.com/google/dart-scissors/tree/master/example/permutations).

`pubspec.yaml`:

  ```
  dev_dependencies:
    scissors
  transformers:
  - scissors/permutations_transformer
  ```

Valid settings:
- `generatePermutations`: `true` by default
- `ltrImport` and `rtlImport`: unset by default.
   If you're deferred-loading LTR/RTL-specific template caches, these settings
   should take the alias you're importing them under. See [example/permutations](https://github.com/google/dart-scissors/tree/master/example/permutations) for a concrete example.
- `expectedPartCounts` (map of .dart.js artifact to number of expected parts): unset by default.
  For instance: `{ web/main.dart.js: 3 }`.
- `stripSourceMaps`: `false` by default.
  Removes the `sourceMappingURL` links from all generated `.js` files, to avoid
  provoking 404s in production when sourcemaps aren't served (relevant only
  when the `$dart2js` transformer has setting `sourceMaps: true`).
- `reoptimizePermutations`: `false` by default.
  Whether to optimize permutations with the Closure Compiler.
- `closureCompilerJarPath`: `compiler.jar` by default
- `javaPath`: `java` by default.

## Using `scissors/reloader/transformer`

This provides an amazing development turnaround experience, whether you're using
the other sCiSSors transformers or not.

With `pub serve --force-poll`, as soon as you save an asset (say, `foo.scss`)
and it finished building the dependent assets (say, `foo.scss.css`), the app
will reload. That's typically before you even have the time to tab-switch to
the browser (+ no need to Ctrl+R).

The transformer ensures the automatic reload logic is removed in `release`
builds (`pub build`), without interfering with source maps.

Example: see [example/permutations](https://github.com/google/dart-scissors/tree/master/example/permutations).

Just edit `pubspec.yaml` (note: it's in `dev_dependencies`, not `dependencies`):

  ```
  dev_dependencies:
    scissors
  transformers:
  - scissors/reloader/transformer
  ```

And edit `main.dart`:

  ```dart
  import 'package:scissors/reloader/reloader.dart';

  main() {
    setupReloader();
    ...
  }
  ```

Valid settings:
- `serveTimestamps` (boolean): by default, `true` in `debug` only
- `removeReloader` (boolean): by default, `true` in `release` only

# Using `scissors/src/checker/transformer` to detect unawaited futures

See [UnawaitedFutures](UnawaitedFutures.md) for more details.

Keep in mind that this transformer is very experimental, and slow.
It aims to complement Dart's new strong-mode analyzer with more static checks,
some of which could eventually graduate to the analyzer itself.

Example:

`pubspec.yaml`:

  ```
  dev_dependencies:
    scissors
  transformers:
  - scissors/src/checker/transformer:
    unawaitedFutures: error
  ```

Valid settings:
- `unawaitedFutures` (`ignore`, `warning` or `error`): `warning` by default

# Development

For things to do, please see [issues](https://github.com/google/dart-scissors/issues).

To setup dependencies, please run:
```
. scripts/install_dependencies.sh
```
This will download some executables used by Scissors and will export the following environment vars
- `SASSC_BIN`
- `CSSJANUS_BIN`
- `CLOSURE_COMPILER_JAR`
- `PNGCRUSH_BIN`

Please run the following command to test your changes + reformat + analyze sources:
```
./scripts/presubmit.sh
```

Please *never* force-push to `master`: use `git revert` to revert changes.
