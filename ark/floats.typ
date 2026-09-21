// Code blocks, table figures and the figure-placement decision: whether a figure sits where it was
// written, floats to an end of the page, or breaks across pages. Applied as
// `show: arkFloats.with(figure-placement)` after the front matter, where the body starts.
#import "brand.typ": *
#import "layout.typ": *
#import "figures.typ": *

#let arkFloats(figure-placement, doc) = {
  show raw.where(block: true): (it) => {
    set align(left)
    set par(justify: false)
    set text(fill: arkCodeInk)
    block(sticky: true, fill: arkTint, width: 100%, inset: 9pt, radius: 2pt, it)
  }
  show figure.caption: leftCaption
  // MyST emits the string kind; a native table() in a raw typst block gets the function kind.
  // Naming both once keeps a new table setting from having to be written twice.
  let tableKind = figure.where(kind: "table").or(figure.where(kind: table))
  show tableKind: set figure.caption(position: top)
  // Justified text stretches a short cell and hyphenation splits its words
  show tableKind: set par(justify: false)
  show tableKind: set text(hyphenate: false)
  // Articles in a multi-article export are #include'd files that see MyST's empty tableStyle,
  // so tablex draws a full grid there. Drop its vertical rules and lighten the rest; lines
  // drawn with an explicit stroke, as the template's tableStyle does, keep that stroke.
  show figure.where(kind: "table"): it => {
    show line: l => if l.start.at(0) == l.end.at(0) { none } else { l }
    set line(stroke: 0.5pt + arkGrey)
    set text(size: 9pt)
    it
  }
  // Figures are breakable, and the rule below wraps each figure that fits a page in an unbreakable block,
  // whose explicit argument takes precedence over MyST's `show figure: set block(breakable: ...)`.
  show figure: set block(above: figureSpacing, below: figureSpacing, breakable: true)
  // A figure that fits moves whole, or floats under figure_placement (bottom only on page one, below the title);
  // a taller one breaks across pages. Theorem-like figures stay breakable, since a proof may span pages.
  show figure: it => if it.placement == none and it.kind in ("figure", "table", "code", image, table, raw) {
    context {
      let wide = nextFigureWide.get() and figureDepth.get() == 0
      let columnWidth = textColumn() * (if wide { wideWidth } else { 100% })
      let height = measure(block(width: columnWidth, it)).height
      let fits = height <= textHeight() - 3em.to-absolute()
      let whole = block(above: figureSpacing, below: figureSpacing, breakable: not fits, nested(it))
      let mode = nextFigurePlacement.get()
      if mode == none { mode = figure-placement }
      // Page one floats only to the bottom, since a top float would land above the title
      let floatTo(end) = place(if here().page() == 1 { bottom } else { end }, float: true, clearance: figureSpacing, whole)
      // Placement never reads the page position: a choice made from the space left on the page moves the text
      // before the figure, and eight figures placed that way failed to converge and misnumbered
      if wide and fits {
        // In the flow unless a placement mode floats it; fullwidth keeps page one's float at column width
        if mode == "none" { block(above: figureSpacing, below: figureSpacing, breakable: false, fullwidth(float: false, it)) } else { fullwidth(it) }
      } else if not fits {
        // Like LaTeX's \needspace: an empty unbreakable block moves to the next page when the caption, header and
        // first rows would not fit, and the negative space returns the table to where that block starts
        block(breakable: false, height: 10em, above: figureSpacing, below: 0pt)
        v(-10em)
        whole
      } else if mode == "none" or figureDepth.get() > 0 {
        whole
      } else {
        floatTo(("auto": auto, "top": top, "bottom": bottom).at(mode))
      }
      nextFigurePlacement.update(none)
      nextFigureWide.update(false)
    }
  } else { it }
  set figure(placement: none)

  doc
}
