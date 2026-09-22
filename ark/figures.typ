// Figure captions, the nesting depth floats are decided on, and the per-figure placement and
// width a raw Typst block sets just before a MyST figure.
#import "brand.typ": *
#import "layout.typ": *

// Labels as a template option can carry them, since MyST options take a string and never a list:
// separated by commas or spaces, and written with or without the # a cross-reference uses.
#let arkLabelList(value) = if value == none {
  ()
} else {
  value.split(regex("[,\\s]+")).map(part => part.trim("#")).filter(part => part != "")
}

// The sans at Econ-ARK blue that a figure number, a theorem head and a subfigure's (a) all take.
// One definition, so a change of weight or colour reaches the three of them together.
#let labelText(body) = text(font: sansFont, weight: 500, fill: arkBlue, body)

// The "Figure 1" or "Proposition 2" a caption and a theorem head both open with.
#let numberLabel(it) = labelText[#it.supplement #it.counter.display(it.numbering)]

// Wraps MyST's subpar.grid so a subfigure's (a) label matches the caption above it. ark/subpar.typ
// binds it; that file exists because the binding must be a module.
#let arkSubparGrid(base) = base.grid.with(show-sub-caption: (num, it) => {
  labelText(num)
  h(0.4em)
  it.body
})

#let leftCaption(it) = context {
  set text(font: sansFont, size: 8.5pt)
  set align(left)
  set par(justify: false, first-line-indent: 0pt)
  // Fira Mono and Fira Sans share an x-height, so inline code takes the caption's own size
  show raw.where(block: false): set text(size: 1em)
  numberLabel(it)
  h(6pt)
  it.body
}

// Counts the figures and fullwidth wrappers enclosing a point, so figure_placement floats only outermost figures
#let figureDepth = state("ark-figure-depth", 0)
#let nested(it) = { figureDepth.update(d => d + 1); it; figureDepth.update(d => d - 1) }

// Placement for the next figure only, like LaTeX's [t], [b] and [h]: "top", "bottom", "auto" or "none".
// Write it in a raw Typst block just before a MyST figure, which has no placement setting of its own.
#let nextFigurePlacement = state("ark-next-figure-placement", none)
#let placeNextFigure(placement) = {
  assert(placement in ("top", "bottom", "auto", "none"), message: "placeNextFigure takes \"top\", \"bottom\", \"auto\" or \"none\"")
  nextFigurePlacement.update(placement)
}
// Widen the next figure over the margin rail, as fullwidth does for a figure written in raw Typst
#let nextFigureWide = state("ark-next-figure-wide", false)
#let widenNextFigure() = nextFigureWide.update(true)

// Wide figure spanning the margin rail and text column. With float: false it stays in the text flow,
// right-aligned so the excess spills left over the rail; that collides with page one's margin notes.
#let fullwidth(it, float: true) = context {
  if not float {
    align(right, box(width: wideWidth, nested(it)))
  } else if here().page() == 1 {
    // A top float lands above the title; both branches float, so the anchor never moves and layout converges
    place(bottom, float: true, nested(it))
  } else {
    // A float wider than the column is centered on it, so wideShift aligns it with the rail
    place(auto, dx: wideShift, float: true, box(width: wideWidth, nested(it)))
  }
}
