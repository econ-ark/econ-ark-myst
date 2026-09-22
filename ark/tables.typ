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
// One step per parsed copy hidden and one per twin that took its place, counted so the template
// can ask at the end whether every table it hid was replaced by the twin meant to stand for it.
#let arkTwinsHidden = counter("ark-twins-hidden")
#let arkTwinsTaken = counter("ark-twins-taken")

// The words a caption carries, flattened, which is how a twin is told from any other Typst table:
// the fragment writes one caption into its LaTeX float and the same one into its twin.
#let arkCaptionText(body) = {
  if body == none {
    ""
  } else if type(body) == str {
    body
  } else if body.func() == [ ].func() {
    // The walk below reads text, children and body, and the space between two children has none
    // of them, so a caption holding any markup would flatten with its words run together
    " "
  } else {
    let parts = body.fields()
    if "text" in parts {
      parts.text
    } else if "children" in parts {
      parts.children.map(arkCaptionText).join("")
    } else if "body" in parts {
      arkCaptionText(parts.body)
    } else {
      // A reference or a citation keeps what it points at in a field of its own, and dropping it
      // would leave two captions alike but for which work they cite reading as one caption
      repr(body)
    }
  }
}

// The whole caption, which is what pairs the two copies of one table: a generator writes it into
// both halves word for word, where two tables on a page can share any opening a prefix would read
#let arkCaptionKey(caption) = {
  if caption == none { return "" }
  arkCaptionText(caption.body).replace(regex("\\s+"), " ").trim()
}

#let arkTwinnedTables(twinned, doc) = if twinned == none { doc } else {
  // A parsed copy leaves its caption here as it is hidden, and the Typst table that comes next
  // takes its place only by carrying the same caption, which is what the fragment writes twice.
  let expectingTwin = state("ark-expecting-twin", none)
  show figure: it => {
    let tableLabel = it.at("label", default: none)
    if it.kind == table {
      context if expectingTwin.get() != arkCaptionKey(it.caption) {
        // The twin the fragment writes comes next or never, so an expectation this table does not
        // answer is spent here rather than left standing for a table further down the page
        expectingTwin.update(none)
        it
      } else {
        // The twin, given the kind MyST's own tables carry. The label stays with the parsed copy,
        // which is how the branch below tells a twin from a copy when the rule takes its output back.
        expectingTwin.update(none)
        arkTwinsTaken.step()
        figure(
          it.body,
          caption: it.caption,
          kind: "table",
          supplement: it.supplement,
          alt: it.alt,
          numbering: it.numbering,
          placement: it.placement,
          scope: it.scope,
          gap: it.gap,
          outlined: it.outlined,
        )
      }
    } else if it.kind == "table" and tableLabel != none and (twinned == auto or twinned.contains(str(tableLabel))) {
      expectingTwin.update(arkCaptionKey(it.caption))
      arkTwinsHidden.step()
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
