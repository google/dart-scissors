# sCiSSors: a CSS minifier / tree-shaker for Angular.

Bored of tuning your SASS imports to avoid bloated CSS? This is for you!

_Disclaimer_: This is not an official Google product.

## Features

- For each .css file with a .html companion, prunes CSS rules that don't seem
  to be used. Have a look a [the tests](./test/transformer_vm_test.dart) for
  examples.
- Supports ng-class and class names with programmatic interpolated fragments
  (e.g. `class="some-{{fragmented}}-class and-some-normal-class"`,
  `ng-class="{'some-class': isSome}"`).
- Reasonably framework-agnostic (should work with Angular 1 & 2, but not with
  inlined templates yet).

## Usage

- Add the sCiSSors dep and transformer:

```
dev_dependencies:
  scissors
transformers:
  - scissors
```

Please only setup sCiSSors's transformer on projects you know respect sCiSSors'
conventions and limitations.

## Limitations

- No support for inlined templates in `@Component` / `@View` annotations in
  .dart files yet,
- Assumes if foo.html exists, foo.css is only used from there (conventions
  matter). This means sCiSSors should be disabled or used with caution when
  using Angular2 with EmulatedUnscopedShadowDomStrategy (see section below).
- Very limited support of CSS rules (naive and hopefully pessimistic matching),
- Bails out of pruning as soon as it doesn't recognize the (map literal)
  syntax of an ng-class (or if the map has non-string-literal keys),
- Does not detect direct / handle DOM manipulations done in .dart companion
  files yet (html.Element.classes, etc).
- No support for XML namespaces in CSS3 attribute selectors.
- No CSS renaming yet (just pruning for now),

## Style Isolation in Angular

Angular(1,2) provide the following strategies

- Shadow DOM (*default in AngularDart 1.x*, implemented by
  ShadowDomComponentFactory in AngularDart 1.x and NativeShadowDomStrategy
  in Angular2)
- Shadow DOM emulation with "transclusion" (implemented by
  TranscludingComponentFactory in AngularDart 1.x and EmulatedScopedShadowDomStrategy
  in Angular2)
- Unscoped / no Shadow DOM
  (*[default(?)](http://blog.thoughtram.io/angular/2015/06/29/shadow-dom-strategies-in-angular2.html)
  in Angular2*, implemented by EmulatedUnscopedShadowDomStrategy)

The first two strategies (Shadow DOM & its transcluded emulation) provide strict
encapsulation of style at the component level: styles defined in a component
do not leak to any of its sub-components or parent components. This is the
assumption by which sCiSSors lives, so you're safe with it.

The last "unscoped" strategy (the default(?) in Angular2) means there's no file- or
component-local way of deciding if a style *could* be used elsewhere. You should
not use sCiSSors on packages / projects with that strategy.

## TODO(ochafik):

- Analyze companion .dart files:
  - Extract inline templates from Angular 1 & 2 component / view annotations
  - Detect manual DOM class manipulations
  - Note that in Angular2, even in the face of EmulatedUnscopedShadowDomStrategy
    we might be able to walk down the possible subcomponents of a template, and
    perform downwards-usage-based pruning.
  - *(stretch)* Perform ahead-of-time transclusion
- Introduce mechanism to preserve classes: need to see which of the following
  options are the most SASS-friendly / most usable:
  - Javadoc-like `@retain` tags in comments,
  - Special rule `scissors { my-class: preserved; }`,
  - Special property `.my-class { scissors: preserved; ... }` (my favourite),
- Minify/rename CSS class names
- *(stretch)* Include RTL mirroring of CSS?
