# sCiSSors [![Build Status](https://travis-ci.org/google/dart-scissors.svg?branch=master)](https://travis-ci.org/google/dart-scissors) [![Pub Package](https://img.shields.io/pub/v/scissors.svg)](https://pub.dartlang.org/packages/scissors)
**A CSS minifier / tree-shaker / Sass runner for Angular.**

Bored of tuning your Sass imports to avoid bloated CSS? This is for you!

_Disclaimer_: This is not an official Google product.

## Features

- For each .css file, prunes rules that aren't used in its .html companion or
  in the templates inlined in its .dart companion
  (see [tests](./test/transformer_vm_test.dart) and [examples](./example))
- Supports Angular(1,2) templates inside `@Component` / `@View` annotations.
- Supports `ng-class` and `class` names with programmatic interpolated fragments
  (e.g. `class="some-{{fragmented}}-class and-some-normal-class"`,
  `ng-class="{'some-class': isSome}"`).
- Compiles `*.sass` and `*.scss` files with [`sassc`](https://github.com/sass/sassc)
  - Supports Compass's [inline-image](http://compass-style.org/reference/compass/helpers/inline-data/)
    helper to inline images.
  - Rebuilds `.css` file whenever any transitive `.sass` import is modified.
    (note: requires `pub serve --force-poll`)

## Usage

- Add the sCiSSors dep and transformer:

  ```
  dev_dependencies:
    scissors
  transformers:
  - scissors
  ```

- You can optionally point sCiSSors to your local [`sassc`](https://github.com/sass/sassc) install if it's not in the path (hint: install with `brew install sassc` on MacOS X) and provide it with extra args:

  ```
  transformers:
  - scissors:
      sasscPath: path/to/sassc
      sasscArgs:
        - -foo
        - -bar
  ```

Please only setup sCiSSors's transformer on projects you know respect sCiSSors'
conventions and limitations.

## Limitations

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

## Style Isolation in Angular

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

## TODO

Please see issues.
