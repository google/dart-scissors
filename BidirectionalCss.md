BidiCssGenerator generates a CSS which comprises of orientation neutral, orientation specific and flipped orientation
specific parts.

Given the example CSS: 
    
    foo {
       color: red;
       margin-left: 10px;
    }
     
it'd get converted to a CSS containing 3 sections:

    foo {
        color: red;                        orientation neutral (Independent of direction)
    }

    :host-context([dir="ltr"]) foo {
        margin-left: 10px;                 orientation specific (orientation specific parts in original CSS)
    }

    :host-context([dir="rtl"]) foo {
        margin-right: 10px;               flipped orientation specific (orientation specific parts in flipped CSS)
    }

The `BidiCssGenerator` takes a CSS contents as a string, the CSS's source filename, nativeDirection of input CSS and
path to CSSJanus. It generates a flipped version of the input CSS by passing it to CSSJanus.
E.g: passing 
    
    foo {
        color: red;
        margin-left: 10px;            will be used as Original CSS
    }
     
to CSSJanus returns

    foo {
        color: red;
        margin-right: 10px;           will be used as flipped CSS.
    }

Next it creates three transactions(CSS strings)

1. **Orientation Neutral**: It is made from original CSS string. 
                           Direction dependent parts will be removed from it to keep only neutral parts.
                           e.g.: if it initially contains `foo { color: red; margin-left: 10px;}`, it will get modified 
                           to `foo { color: red;}`.
 
2. **Orientation specific**: It is made from original CSS string.
                            Direction independent parts will be removed from it to keep only direction dependent parts 
                            of original CSS. For example, if it initially contains `foo { color: red; margin-left: 10px;}`, 
                            it will get modified to `:host-context([dir="ltr"]) foo { margin-left: 10px;}`.

3. **Flipped Orientation specific**: It is made from flipped CSS string.
                                    Direction independent parts will be removed from it to keep only direction dependent parts of original CSS.
                                    eg: if it initially contains `foo { color: red; margin-right: 10px;}`, 
                                    it will get modified to `:host-context([dir="rtl"]) foo { margin-right: 10px;}`

For each of these transactions it extracts toplevels of the originalCss and flippedCss and iterate on them.

If a topLevel is of the type **Rule Set** 
for example:

    a {                                         
        foo: bar;
        margin-left: 1em;
        background-position:25% 75%;
    }
  
it iterates over declarations in them.
Depending on the mode of retention which could be `keepBidiNeutral`, `keepOriginalBidiSpecific`, `keepFlippedBidiSpecific`,
it checks if the declaration is to be removed and store their start and end location.
Now if only some declarations have to be removed, it removes them using their start and end points already stored.
And if all declarations in a ruleset are to be removed, it removes the ruleset (No need to keep empty rule)

If topLevel is of type **Media Directive** or **Host Directive**
for example:

    @media screen and (min-width: 401px) {
        foo { margin-left: 13px }             
    }

It picks a ruleset and stores removable declarations in it.
If only some of the declaration have to be removed, it removes them from transaction.
If all declarations in ruleset are removable, it stores start and end location of rule set(dont edit transaction because
if all rulesets of directive have to be deleted then we will delete directive itself)

If only some rulesets in Directive have to be removed it removes them using store start and end location.
If all the rulesets have to be removed it removes the directive itself.

If topLevel is a **Direction Independent Directive**
for example:

    @charset "UTF-8";                                 Charset Directive
    @namespace url(http://www.w3.org/1999/xhtml);     Namespace Directive
 
We keep it in one of the transaction and remove it from other two (Here we are keeping it in orientation neutral transaction).

We then combine these transactions to get the expected output CSS.