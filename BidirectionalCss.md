`BidiCssGenerator` augments the original CSS with some flipped/mirror rules, tagged with `[dir="rtl"]` (or `[dir="ltr"]`) selectors.

Given the example CSS:

```css
    foo {
       color: red;
       margin-left: 10px;
    }
```

it'd get converted to a CSS containing 3 sections:

```css
    foo {
        color: red;
    }

    :host-context([dir="ltr"]) foo {
        margin-left: 10px;
    }

    :host-context([dir="rtl"]) foo {
        margin-right: 10px; /* flipped orientation specific declarations *
    }
```

It starts by runing CSSJanus on the input CSS:

```css
    foo {
        color: red;
        margin-left: 10px;            will be used as Original CSS
    }
```

is transformed by CSSJanus to:

```css
    foo {
        color: red;
        margin-right: 10px;           will be used as flipped CSS.
    }
```

It then parses both CSS sources matches rules and declarations 1:1 between the
original and the flipped versions. It builds a "flipped" fragment by dropping
elements that are identical in the two versions.

If a topLevel entity is of the type **Rule Set**
for example:

```css
    a {                                         
        foo: bar;
        margin-left: 1em;
        background-position:25% 75%;
    }
```

it recurses over declarations in them.

If only some declarations have to be removed, it uses heuristics to get good
start and end offsets for removal, and if all declarations in a ruleset need to
be removed, it removes the ruleset (no need to keep an empty flipped rule).

If topLevel is of type **Media Directive** or **Host Directive**
for example:

```css
    @media screen and (min-width: 401px) {
        foo { margin-left: 13px }             
    }
```

It recurses into its rule sets, and removes the directive altogether if all
rule sets are removed.

If topLevel is a **Direction Independent Directive**
for example:

```css
    @charset "UTF-8";                                 /* Charset Directive */
    @namespace url(http://www.w3.org/1999/xhtml);     /* Namespace Directive */
```

We don't generate anything special.

We then combine the original file with the flipped fragment to get the final CSS.
