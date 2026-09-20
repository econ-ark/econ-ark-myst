---
title: Econ-ARK
description: A Typst template and website theme for Econ-ARK working papers and REMARKs
site:
  # A landing carries its own navigation, and the hero below is the title, so the rails and the
  # frontmatter title block both come off.
  hide_toc: true
  hide_outline: true
  hide_title_block: true
---

+++ { "kind": "centered", "class": "ark-hero col-screen" }

# One source, set twice

A working paper written in MyST becomes a Typst PDF for circulation and a website in the same
house style. The palette, the typefaces and the four logo curves are shared between them.

{button}`See the article theme </article/>`
{button}`Read the paper (PDF) </article/paper.pdf>`

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

The consumer discounts next period at $\beta$ and earns $R$ on what is left, which is the same
$\beta$ and the same $R$ the display below is set from:

```{math}
v(m_t) = \max_{c_t} \; u(c_t) + \beta \mathbb{E}_t \left[ v(m_{t+1}) \right],
\qquad m_{t+1} = R (m_t - c_t) + y_{t+1}.
```

+++ { "class": "ark-section col-body-outset" }

## Use it

Four steps, in the order you take them. {button}`Read the guide <https://mystmd.org/guide>`

::::{grid} 1 1 2 2
:class: ark-steps

:::{card}
**Point an export at this repository**
^^^
MyST fetches the Typst template itself, so nothing is vendored into your paper.
:::

:::{card}
**Name the stylesheet**
^^^
The website half is `theme.css` and one plugin, which your `myst.yml` points at by path.
:::

:::{card}
**Subset the fonts**
^^^
A script fetches and subsets every face at build time, from one pinned release.
:::

:::{card}
**Check the artifact**
^^^
The suite builds both themes and the paper, then asserts what reached the page.
:::

::::

+++ { "class": "ark-section col-body-outset" }

## Where to look next

::::{grid} 1 1 2 2
:class: ark-ways

:::{card}
:link: /article/
**Article theme**
^^^
One paper, with the banner, the margin rail and the front matter the PDF sets.
:::

:::{card}
:link: /book/
**Book theme**
^^^
A site of many pages, with the sidebar and the landing blocks this page uses.
:::

:::{card}
:link: https://github.com/econ-ark/econ-ark-myst#readme
**Documentation**
^^^
What each option does, down to what a consumer puts in its own `myst.yml`.
:::

:::{card}
:link: https://github.com/econ-ark/econ-ark-myst
**Source**
^^^
The template, the stylesheet, the font script and the checks that guard them.
:::

::::
