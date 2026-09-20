# Known gaps

`scripts/check-examples.sh` asserts against built artifacts. It catches what a file can show. Three
things it misses, each found by hand after the suite was green. They are recorded here so the next
person reads them as known. They also mark where a check would only look like coverage.

## Hover, and anything resolved through CSS nesting

myst-theme sets its button hover with nesting:

```css
a.button, button.button, span.button, cite.button a { ...; &:hover { ... } }
```

`&` carries the specificity of the widest selector in the parent list, `cite.button a` at (0,1,2),
so the nested `&:hover` lands at (0,2,2) on every element it matches, a plain `a.button` included.
A flat `a.button:hover` in `theme.css` is (0,2,1) and loses at any load order. The fix is to nest
our hover inside our own rule with the same four selectors, so `&` resolves the same way.

The hero's outline button needed the same treatment for the opposite reason. Its base rule is
(0,4,1) against the theme's nested hover at (0,2,2). Here the theme's hover is what loses, leaving
the button to answer a pointer with nothing. Its hover is nested inside that rule now.

The suite never computes nested specificity. A static checker could parse the built `app-*.css`,
take `spec(&) = max(spec(s))` over the parent list, and fail when `theme.css` sets the same
property on an overlapping selector at lower specificity. That would have caught this one. It has
not been written. It would also have missed the next one.

## Selectors broken by nodes that exist only at runtime

The hero's second button is the quiet one, selected as a sibling of the first. Hovering the first
button makes Remix inject four elements between them:

```
a, link[rel=prefetch], link[rel=modulepreload], link[rel=modulepreload], link[rel=prefetch], a
```

`.button + .button` stops matching and the quiet button turns into a copy of the loud one until the
page reloads. `~` holds, at the same specificity, whatever gets injected and however much of it.
Confirm any replacement by hovering and measuring, never by reading the built HTML: those nodes are
in no file. `:nth-of-type(2)` survives this injection and fails the first time an anchor is
injected instead.

## Rules whose class no example renders

A rule written against a class that no example renders is a rule nothing checks, which is why
`examples/site-only.md` exists. Counted against both built sites, fifteen rules are still in that
state, in the four groups below.

Needs a page this repo has no way to produce: `.font-system` and the five `.myst-jp-*` rules want
executed kernel output, and `p[data-line-number].line::before` wants a LaTeX algorithm environment,
since that node comes from `tex-to-myst/src/algorithms.ts` and no MyST directive emits it.

Needs configuration the sites leave unset. The five `.myst-primary-sidebar-footer` rules apply only
to a site supplying a `primary_sidebar_footer` part. Neither `myst.yml` supplies one. That includes
the compound at `theme.css:221`, whose comment explains a specificity fix nothing has exercised.

Needs content of a shape the examples happen not to carry: `.sphinx-desc-signature` wants an API
signature converted from Sphinx, and `.myst-landing-centered-subtitle` wants a subtitle on a
centered block, where the landing puts its subtitle on a split-image one.

Applied by the theme's own JavaScript rather than by markup: `.myst-outline-item-active`.

A sixteenth was `article.article img.ark-banner`, styling a class this repo never emitted anywhere.
That one was dead code and has been deleted.

The blue utility overrides are deliberately a superset of what the examples render, so the six
classes no page paints are forward coverage rather than a gap. `check_blue_coverage` compares in
one direction only, which leaves that superset unreported. It now pairs each selector with its
declaration block, so a rule left empty stopped counting as an override.
