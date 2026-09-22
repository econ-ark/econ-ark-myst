// Booktabs styling for the tables MyST writes with tablex.
#import "brand.typ": *
#import "figures.typ": arkLabelList, nextFigureWide

// Styles for the tables MyST writes with tablex: a bold header between two rules, with horizontal rules only.
// Cells are set ragged and unhyphenated, since a justified narrow cell stretches and splits its words.
#let tableCells(size) = cell => {
  let body = {
    set par(justify: false)
    set text(size: size, hyphenate: false)
    cell.content
  }
  (..cell, content: if cell.y == 0 { strong(body) } else { body })
}
// Booktabs rules: heavier at the top and bottom of the table, lighter under the header.
// Only arkTablex knows the row count, so a style used on its own draws just the top and header rules.
#let tableRules(header-rows: 1, rows: none) = line => {
  line.stroke = if line.y == 0 or line.y == rows { arkGrey + 0.75pt } else if header-rows > 0 and line.y == header-rows { arkGrey + 0.5pt } else { 0pt }
  line
}
#let arkTableStyle = (map-cells: tableCells(9pt), auto-vlines: false, map-hlines: tableRules())
#let smallTableStyle = (map-cells: tableCells(7pt), auto-vlines: false, map-hlines: tableRules())

// A table written as a code-generated fragment reaches a Typst export twice. MyST parses the
// fragment's LaTeX float, which carries the label the page cites, and the fragment's Typst twin is
// the copy that prints. twinned_tables is "all", or the labels of the copies that have a twin.
#let arkTwinnedSpec(value) = if value == none {
  none
} else if value.trim() == "all" {
  auto
} else {
  arkLabelList(value)
}

// The parsed copy stays in the document, hidden, so its label still resolves and a reference to it
// still points at the page holding it. It gives its number back and the twin beside it takes that
// number, which leaves one counter numbering every table in the order MyST numbered them.
#let arkTwinnedTables(twinned, doc) = if twinned == none { doc } else {
  show figure: it => {
    let tableLabel = it.at("label", default: none)
    if it.kind == table {
      // The twin, given the kind MyST's own tables carry. The label stays with the parsed copy,
      // which is how the branch below tells a twin from a copy when the rule takes its output back.
      figure(
        it.body,
        caption: it.caption,
        kind: "table",
        supplement: it.supplement,
        numbering: it.numbering,
        placement: it.placement,
        scope: it.scope,
        gap: it.gap,
        outlined: it.outlined,
      )
    } else if it.kind == "table" and tableLabel != none and (twinned == auto or twinned.contains(str(tableLabel))) {
      place(hide(it))
      counter(figure.where(kind: "table")).update(n => n - 1)
    } else {
      it
    }
  }
  doc
}

// Wraps MyST's tablex to count the rows, which the bottom rule needs, and to style a table MyST left unstyled.
// Bind it with `#let tablex = arkTablex.with(tablex)`: template.typ does, and each article of a multi-article export must.
#let arkTablex(base, ..args) = {
  let named = args.named()
  let cols = named.at("columns", default: auto)
  let ncols = if type(cols) == int { cols } else if type(cols) == array { cols.len() } else { none }
  // A plain cell fills one grid slot and a cellx fills its colspan times its rowspan; hlinex and vlinex count zero
  let slots = args.pos().map(item => if type(item) != dictionary { 1 } else if item.at("tablex-dict-type", default: none) == "cell" { item.at("colspan", default: 1) * item.at("rowspan", default: 1) } else { 0 }).sum(default: 0)
  let rows = if ncols != none and ncols > 0 { calc.ceil(slots / ncols) }
  let style = arkTableStyle + named
  style.insert("map-hlines", tableRules(header-rows: named.at("header-rows", default: 1), rows: rows))
  // A widened table fills the wide width, as a wide figure does: the label column keeps its width, the rest share it
  context {
    let wideStyle = style
    if nextFigureWide.get() and type(cols) == int and cols > 1 {
      wideStyle.insert("columns", (auto,) + (1fr,) * (cols - 1))
    }
    base(..wideStyle, ..args.pos())
  }
}
