# Known gaps

`scripts/check-examples.sh` asserts against built artifacts. It catches what a file can show. What
it misses is below, each one found by hand after the suite was green. This file records them so the
next person reads them as known. They also mark where a check would only look like coverage.

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
the button to answer a pointer with nothing. Its hover now nests inside that rule.

The suite never computes nested specificity. A static checker could parse the built `app-*.css`,
take `spec(&) = max(spec(s))` over the parent list, and fail when `theme.css` sets the same
property on an overlapping selector at lower specificity. That would have caught this one. Nobody has
written it. It would also have missed the next one.

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

## The proof kind, which no stylesheet can read

The PDF italicises six of the fifteen `prf:` kinds, amsthm's plain style: theorem, lemma,
proposition, corollary, conjecture and criterion. The site sets all fifteen upright. No rule in
`theme.css` can change that.

myst-theme writes one class list for every kind, so a proposition and a proof both arrive as
`class="myst-proof ..."`, the way `myst-aside-${kind}` arrives as that literal string for a margin
note. That leaves the colour scheme as the one per-kind signal, and `getColorScheme` in
`myst-to-react/src/proof.tsx` groups kinds across the amsthm split: `proposition` shares a scheme
with `definition`, while `corollary` and `criterion` share one with `property`. Those are the pairs
a rule would have to separate, so no selector over that class reaches them.

Italicising every `.myst-proof-body` would misset the nine kinds amsthm leaves upright, a worse
answer than leaving all fifteen that way. The guard therefore runs against the PDF alone:
`check_proof_style` compares the font of a statement against the font of its own `(Title).` run.
It needs one kind of each style to compare, which is what the definition beside the proposition in
`paper.md` is for.

`arkProof` itself is kind-agnostic and so is every `.myst-proof` rule, so all fifteen kinds render
in both media, plus `exercise` and `solution`, which `myst-to-typst/src/proofs.ts` routes through
the same handler without their being in `PROOF_KINDS`.

## The name highlight.js never scopes

`brand/code.tmTheme` and `theme.css` give a listing the same four accents, the same ink and the same
tint, which is enough for a block to look the same in either medium. Weight is where the two
grammars limit each other. highlight.js scopes a Python name only where it is defined, emitting
`.hljs-title` after a `def` or a `class` and `.hljs-built_in` for a builtin. A call site and an
attribute stay in the surrounding text. Typst reads the same code through MagicPython, which scopes
a definition under `entity.name.function` or `entity.name.class`, a builtin under
`support.function`, and a call site under `variable.function`.

`brand/code.tmTheme` therefore names the definition and builtin scopes alone. Naming
`variable.function` beside them would bold `agent.solve()` in the PDF and nothing on the site.
`check_code_weight` asserts both halves against the built paper: bold on `target_wealth` and
`float`, plain on the call sites beside them.

## The admonition colour on the site, which nothing measures

Both media give an admonition a rule in one of four palette colours. The PDF half is measured:
`check_rule` samples the band beside the word and fails on a pixel off palette, once per colour
group. The site half has no equivalent. `theme.css` sets `--ark-admonition` per
`.myst-admonition-<kind>` class. What the suite reads on the site stops at the tag split, so a kind
pointed at the wrong curve reaches a reader with the suite green.

A static read of the stylesheet would catch a kind whose rule names the wrong token. Nobody has
written it. It would still stop short of what a browser resolves, since nothing here renders a page.
`check_token_coverage` leaves the nine kind token families out for this reason, their colours coming
from these rules rather than from the theme's tokens.

## Rules whose class no example renders

A rule counts as checked only where some example renders its class, which is why
`examples/site-only.md` exists. Counted against both built sites, ten rules are still in that
state, in the three groups below.

Needs a page this repo has no way to produce: `.font-system` and the five `.myst-jp-*` rules want
executed kernel output, and `p[data-line-number].line::before` wants a LaTeX algorithm environment,
since that node comes from `tex-to-myst/src/algorithms.ts` and no MyST directive emits it.

Needs content of a shape the examples happen not to carry: `.sphinx-desc-signature` wants an API
signature converted from Sphinx, and `.myst-landing-centered-subtitle` wants a subtitle on a
centered block, where the landing puts its subtitle on a split-image one.

Applied by the theme's own JavaScript rather than by markup: `.myst-outline-item-active`.

Two entries have left this list. `article.article img.ark-banner` styled a class this repo never
emitted anywhere, which made it dead code rather than a gap, and `theme.css` no longer carries it.
The five `.myst-primary-sidebar-footer` rules waited on a `primary_sidebar_footer` part. `myst.yml`
now supplies one from `brand/powered-by.md`, and all five paint on the paper under book-theme, the
build the deploy publishes at `/book/`. The other two sites each stop short of them for a reason of
their own. article-theme declares parts nowhere in its template, so it passes this one by, and
book-theme drops the sidebar footer wholesale where a site sets both `nav` and `hide_toc`, as the
landing does.

The blue utility overrides this paragraph used to describe are gone. myst-theme 1.4.0 paints its
chrome through `--myst-color-*` tokens, and `theme.css` sets those instead. `check_token_coverage`
reads the tokens the pages paint through and compares in one direction only, so it never reports a
token set here that no page reaches, as it never reported the surplus blue classes.
