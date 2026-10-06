---
title: Elements the site renders and the PDF cannot
description: Directives with no Typst conversion, kept out of the exported examples
---

The frontmatter here omits `exports`, so `myst build --typst` never reaches this page. Each
directive below hits `Unhandled Typst conversion` and vanishes from a PDF. Putting them in an
exported example made the build report errors over content a reader would never have seen.

They belong here because `theme.css` styles them for the site. A rule written against a class that
no example renders is a rule nothing checks.

:::{dropdown} A dropdown
Its own directive, separate from an admonition carrying `:class: dropdown`. Both reach the page as
`details`, and a stylesheet that qualifies by tag misses them.
:::

:::{aside} A note in the margin
Its label takes the brand sans. The fill is left to the theme, which gives one to a `topic` and none
to a margin note.

The kind cannot be read from a stylesheet: `myst-aside-${kind}` reaches the class attribute as that
literal string, so `topic`, `margin` and `sidebar` are indistinguishable.
:::

The two parts below belong to the Elsevier template, which a paper written for both carries. In a
real paper each holds raw LaTeX, which the site hides as the PDF leaves it out. Here each holds
plain text, so the hiding can be read off the page.

+++ {"part": "graphical_abstract"}

Graphicaltext stays off the page.

+++ {"part": "biography"}

Biotext stays off the page.

+++
