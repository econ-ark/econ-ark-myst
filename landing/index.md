---
title: Econ-ARK
description: A Typst template and website theme for Econ-ARK working papers and REMARKs
---

+++

:::{image} ../banner.svg
:alt: Econ-ARK
:class: col-screen ark-banner
:::

+++ { "kind": "centered" }

Econ-ARK

# One source, set twice

A working paper written in MyST becomes a Typst PDF for circulation and a website in the same
house style. The palette, the typefaces and the four logo curves are shared between them.

[The article theme](/article/)
[The book theme](/book/)
[The paper (PDF)](/article/paper.pdf)

+++ { "kind": "split-image" }

The PDF

## A paper that reproduces

![The first page of the example paper](../thumbnail.png)

The template sets the front matter, the margin rail, the tables and the theorem environments. Every
weight it asks for has a font file of its own, which is what lets the same sources give the same PDF
on another machine. The example shown here is checked byte for byte on every push.

Fira Sans carries the text, Fira Mono the code, and Fira Math everything between dollars.

+++ { "kind": "justified" }

## Equations in the same face as the prose

MyST renders site math with KaTeX, which paints glyphs from its own Computer Modern faces at
positions it has already computed, so no stylesheet can put another typeface under them. A build-time
plugin re-renders each equation as MathML Core, which a browser lays out itself from whatever font it
is given. Symbols on the page now read the same as symbols in a sentence.

+++ { "kind": "centered" }

## Use it

Point an export at this repository and MyST fetches the template. The website half is a stylesheet
and a plugin. A script fetches and subsets the fonts at build time, from one pinned release.

[Read the documentation](https://github.com/econ-ark/econ-ark-myst#readme)
[Source on GitHub](https://github.com/econ-ark/econ-ark-myst)
