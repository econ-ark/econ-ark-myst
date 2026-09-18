#import "@preview/pubmatter:0.2.2"

#let venueUrl = "https://econ-ark.org";
#let venueLogo = image("logo.png");
// Econ-ARK brand palette. The blue is the one econ-ark.org sets throughout its own stylesheet
#let arkBlue = rgb("#1f476b");
#let arkGrey = rgb("#676470");
// The four logo curves, top to bottom, as the Econ-ARK design guidelines name them. The logo EPS
// authors them in CMYK, 0/35/85/0, 0/95/20/0, 75/0/100/0 and 100/0/0/0, and these are that set
// converted; kept to marks that echo the logo, such as the materials rules
#let arkCurves = (rgb("#fbaf3f"), rgb("#ed2a7b"), rgb("#00adef"), rgb("#38b449"));
// One family carries the whole paper. Fira Math is the OpenType math companion to Fira Sans, and
// having it is what lets the body face be a sans: symbols in running text keep the voice of the
// prose. The fallbacks are the four faces Typst bundles, all serif except the mono.
#let sansFont = ("Fira Sans", "New Computer Modern");
#let serifFont = ("Fira Sans", "New Computer Modern");
#let mathFont = ("Fira Math", "New Computer Modern Math");
#let monoFont = ("Fira Mono", "DejaVu Sans Mono");

#let leftCaption(it) = context {
  set text(font: sansFont, size: 8.5pt)
  set align(left)
  set par(justify: false, first-line-indent: 0pt)
  // Fira Mono and Fira Sans share an x-height, so inline code takes the caption's own size
  show raw.where(block: false): set text(size: 1em)
  text(weight: 500, fill: arkBlue)[#it.supplement #it.counter.display(it.numbering)]
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
    align(right, box(width: 133%, nested(it)))
  } else if here().page() == 1 {
    // A top float lands above the title; both branches float, so the anchor never moves and layout converges
    place(bottom, float: true, nested(it))
  } else {
    // A float wider than the column is centered on it, so shifting by half the 33% overhang aligns it with the rail
    place(auto, dx: -16.5%, float: true, box(width: 133%, nested(it)))
  }
}

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

// Wraps MyST's subpar.grid so a subfigure's (a) label matches the caption above it, in the sans at
// Econ-ARK blue. ark-subpar.typ binds it; that file exists because the binding must be a module.
#let arkSubparGrid(base) = if base != none {
  base.grid.with(show-sub-caption: (num, it) => {
    text(font: sansFont, weight: 500, fill: arkBlue, num)
    h(0.4em)
    it.body
  })
}

// A "Label  content" run-in field, which the front matter sets its abstract, summary, keywords
// and JEL codes as. One definition, so a change of label weight or colour reaches all of them.
#let labeledField(label, content, size: 8.5pt) = {
  text(font: sansFont, weight: 500, fill: arkBlue, size: size, label)
  h(0.7em)
  content
}

// A small labelled block in the margin rail
#let railItem(title, content) = {
  text(size: 7.5pt, fill: arkBlue, weight: 500, title)
  linebreak()
  text(size: 7.5pt, content)
}

// Materials under the abstract: (label, body) groups in quarter-width columns under the logo's four colours.
// All four rules show however many groups a paper has, so the block always carries the full logo palette.
// With no groups the rules alone remain, as the divider that ends the front matter.
#let materialsBlock(groups) = {
  set text(font: sansFont, size: 8pt)
  set par(first-line-indent: 0pt, justify: false, leading: 0.45em, spacing: 0.45em)
  if groups.len() > 0 {
    text(size: 8.5pt, fill: arkBlue, weight: 500, "Materials")
    v(5pt, weak: true)
  }
  grid(
    columns: (1fr,) * 4,
    column-gutter: 1.4em,
    row-gutter: 4pt,
    ..arkCurves.map(colour => line(length: 100%, stroke: 1pt + colour)),
    ..groups.map(((label, body)) => {
      text(size: 7pt, fill: arkGrey, label)
      linebreak()
      body
    }),
  )
}

// A note under a material, such as how long a dashboard takes to start
#let materialNote(body) = text(size: 6.5pt, fill: arkGrey, body)

// The keypoints part: a short list read beside the title and abstract
#let keyPoints(body, size: 8pt) = {
  set text(font: sansFont, size: size)
  set par(first-line-indent: 0pt, justify: false, leading: 0.5em, spacing: 0.7em)
  set list(marker: text(fill: arkBlue, sym.bullet), indent: 0pt, body-indent: 0.5em, spacing: 0.8em)
  // Label half a point under the text, matching the rail labels and, under the abstract, the keyword labels
  text(size: size - 0.5pt, fill: arkBlue, weight: 500, "Key points")
  v(0.6em, weak: true)
  body
}

// An author's family name with its particle, such as "van Beethoven", or else the full name
#let familyName(a) = (a.at("particle", default: none), a.at("family", default: a.name)).filter(x => x != none).join(" ")

// Authors as an author-date citation names them: "Carroll", "Carroll and Lujan", "Carroll et al."
#let shortAuthors(authors) = if authors.len() == 0 { none } else if authors.len() == 1 { familyName(authors.first()) } else if authors.len() == 2 { authors.map(familyName).join(" and ") } else { familyName(authors.first()) + " et al." }

// A field the author wrote without a full stop still has to read as a sentence where it is set
#let closeSentence(s) = if s.ends-with(regex("[.?!]")) { s } else { s + "." }

// The wide left margin carries the rail, so the text column is the page less both margins.
// Every width measured against that column reads it from here, which is what makes a change
// to the margins in the set page call below take effect everywhere at once.
#let marginLeft = 25%
#let marginRight = 1.35in
#let textColumn() = page.width - page.width * marginLeft - marginRight
// The rail is in the left margin, offset from the text column and narrower than it. Both the
// placed boxes and the height measured for them read these, so the rail moves as one piece.
#let railOffset = -33%
#let railFraction = 0.27
#let railWidthPercent = railFraction * 100%
// The gap above and below a figure, which every placement path sets alike
#let figureSpacing = 1.4em

// Copyright line and license terms for the margin. The copyright field replaces the generated holder,
// and is printed as written when it already carries a copyright sign.
#let copyrightNotice(authors, year, copyright, license) = {
  let holder = if copyright == none {
    ("Copyright ©", year, shortAuthors(authors)).filter(x => x != none).map(str).join(" ")
  } else if copyright.contains("©") or lower(copyright).starts-with("copyright") {
    copyright
  } else {
    ("Copyright ©", year, copyright).filter(x => x != none).map(str).join(" ")
  }
  [#closeSentence(holder) ]
  if license != none {
    // pubmatter's wording, so existing papers read the same
    let terms = (
      "CC-BY-4.0": [, which enables reusers to distribute, remix, adapt, and build upon the material in any medium or format, so long as attribution is given to the creator],
      "CC-BY-NC-4.0": [, which enables reusers to distribute, remix, adapt, and build upon the material in any medium or format for _noncommercial purposes only_, and only so long as attribution is given to the creator],
      "CC-BY-NC-SA-4.0": [, which enables reusers to distribute, remix, adapt, and build upon the material in any medium or format for noncommercial purposes only, and only so long as attribution is given to the creator. If you remix, adapt, or build upon the material, you must license the modified material under identical terms],
      "CC-BY-ND-4.0": [, which enables reusers to copy and distribute the material in any medium or format in _unadapted form only_, and only so long as attribution is given to the creator],
      "CC-BY-NC-ND-4.0": [, which enables reusers to copy and distribute the material in any medium or format in _unadapted form only_, for _noncommercial purposes only_, and only so long as attribution is given to the creator],
    )
    [This article is distributed under the terms of the #link(license.url, license.name) license#terms.at(license.id, default: none).]
  }
}

// Chicago author-date entry for the paper itself, the style of its reference list.
// Lists up to three authors; with more, the first author and "et al."
#let citation(authors, year, title, venue, volume, issue, pages) = {
  let family = familyName
  let inverted(a) = if "family" in a { (family(a), a.at("given", default: none), a.at("suffix", default: none)).filter(x => x != none).join(", ") } else { a.name }
  let direct(a) = if "family" in a { ((a.at("given", default: none), family(a)).filter(x => x != none).join(" "), a.at("suffix", default: none)).filter(x => x != none).join(", ") } else { a.name }
  let names = if authors.len() == 1 {
    inverted(authors.first())
  } else if authors.len() <= 3 {
    let rest = authors.slice(1).map(direct)
    inverted(authors.first()) + ", " + rest.slice(0, -1).map(n => n + ", ").sum(default: "") + "and " + rest.last()
  } else {
    inverted(authors.first()) + ", et al"
  }
  [#closeSentence(names) ]
  if year != none [#year. ]
  ["#closeSentence(title)"]
  if venue != none {
    [ #emph(venue)]
    if volume != none [ #volume]
    if issue != none [ (#issue)]
    if pages != none [: #pages]
    [.]
  }
}

// Theorem-like blocks from MyST prf: directives, set in flow the way economics papers set them.
// Replaces MyST's own proof(), which floats each block to the top of the page inside a tinted box.

// amsthm's plain style, which italicises its statement, less the kinds MyST has no directive for.
// Its definition and remark styles both set upright, which is what every other kind gets here.
#let italicKinds = ("theorem", "lemma", "proposition", "corollary", "conjecture", "criterion")
// pubmatter sets the authors in "semibold", which resolves by discovery order wherever the text
// face carries no file at that weight. This is its title block with the authors pinned to the
// weight the rest of the template asks for.

// Footnote marks for an author's note. Typst's own "*" sequence runs * then a dagger, and
// pubmatter already prints a dagger against an equal contributor, so this one leaves it out.
#let authorNoteSymbol = n => ("*", "‡", "§", "¶").at(calc.rem(n - 1, 4))

#let titleBlock(fm) = pubmatter.with-theme(_ => {
  pubmatter.show-title(fm)
  pubmatter.show-authors(fm, weight: 500)
  pubmatter.show-affiliations(fm)
})

// Admonitions, which MyST otherwise draws as a filled box in a colour outside the palette.
// A rule in the palette carries them instead, with the label in the same colour.

#let arkAdmonition(body, heading: none, color: arkBlue) = block(
  width: 100%,
  above: 1.2em,
  below: 1.2em,
  stroke: (left: 2pt + color),
  inset: (left: 9pt, top: 5pt, bottom: 5pt),
  {
    set par(first-line-indent: 0pt)
    if heading != none {
      block(below: 0.5em, text(font: sansFont, size: 9pt, weight: 500, fill: color, heading))
    }
    body
  },
)

// Which curve each of MyST's ten admonition kinds takes. Blue for the neutral ones, green for
// the helpful, orange for the wary and pink for the severe. The palette belongs beside the
// palette; template.typ only renames these to the bindings MyST looks up.
#let arkAdmonitions = (
  note: arkAdmonition.with(heading: [Note], color: arkBlue),
  important: arkAdmonition.with(heading: [Important], color: arkBlue),
  tip: arkAdmonition.with(heading: [Tip], color: arkCurves.at(3)),
  hint: arkAdmonition.with(heading: [Hint], color: arkCurves.at(3)),
  seealso: arkAdmonition.with(heading: [See Also], color: arkCurves.at(3)),
  attention: arkAdmonition.with(heading: [Attention], color: arkCurves.at(0)),
  caution: arkAdmonition.with(heading: [Caution], color: arkCurves.at(0)),
  warning: arkAdmonition.with(heading: [Warning], color: arkCurves.at(0)),
  danger: arkAdmonition.with(heading: [Danger], color: arkCurves.at(1)),
  error: arkAdmonition.with(heading: [Error], color: arkCurves.at(1)),
)

// color and float take the arguments MyST's own proof() accepts and ignore them: a theorem here is
// set in the flow of the text, never in a coloured box and never floated.
#let arkProof(body, heading: [], kind: "proof", supplement: "Proof", labelName: none, color: none, float: false) = {
  let note = if heading != [] { [ (#heading)] }
  if kind == "proof" {
    block(above: 1em, below: 1.2em, width: 100%, {
      set par(first-line-indent: 0pt)
      // The fixed gap keeps the square off the last word when the line is full
      [#emph(supplement)#note. #body#h(0.8em)#h(1fr)$square$]
    })
    return
  }
  let statement = if kind in italicKinds { emph(body) } else { body }
  [#show figure.where(kind: kind): it => block(above: 1.2em, below: 1.2em, width: 100%, {
      set align(left)
      set par(first-line-indent: 0pt)
      [#text(font: sansFont, weight: 500, fill: arkBlue)[#it.supplement #it.counter.display(it.numbering)]#note. #it.body]
    })
    #figure(kind: kind, supplement: supplement, numbering: "1", outlined: false, statement)#if labelName != none { label(labelName) }]
}

// Appendix number of the heading at loc, such as "A" or "B.2", or none before the <appendix> marker.
// Counted from the marker, so the author need not reset the heading counter; call inside context.
#let appendixNumber(loc) = {
  let markers = query(selector(<appendix>).before(loc))
  if markers.len() == 0 { return none }
  let nums = counter(heading).at(loc)
  let first = nums.at(0) - counter(heading).at(markers.last().location()).at(0, default: 0)
  if first < 1 { return none }
  (numbering("A", first), ..nums.slice(1).map(str)).join(".")
}

#let template(
  frontmatter: (),
  heading-numbering: "1.1.1",
  kind: none,
  jel: (),
  linenumbers: false,
  binder: none,
  // Not an option of the template: the rail width below and the figure widths in the README are
  // measured on this size, and another size would need both recomputed
  paper-size: "us-letter",
  page-start: none,
  last-page: none,
  keypoints: none,
  // Citation details for the "Cite as" block; the DOI is kept out of frontmatter so the page header does not repeat it
  doi: none,
  arxiv: none,
  zenodo: none,
  volume: none,
  issue: none,
  summary: none,
  // A dedication is set on its own above the abstract; an epigraph follows it, attribution and all
  dedication: none,
  epigraph: none,
  // People who are not authors, each a list of names, shown in the margin rail
  reviewers: (),
  editors: (),
  // Where the work itself lives, shown with the other materials
  source: none,
  // Funding statements and awards, as strings, shown in the margin rail
  funding: (),
  copyright: none,
  code-license: none,
  // Materials: a REMARK name on econ-ark.org, the label over the binder link, and (title, url) downloads
  remark: none,
  binder-label: "Run online",
  // "auto", "top" or "bottom" floats figures that fit a page; "none" keeps each figure where it is written
  figure-placement: "none",
  downloads: (),
  // The paper's content.
  body
) = {
  let fm = pubmatter.load(frontmatter)
  // pubmatter.load drops a document-level github
  let github = frontmatter.at("github", default: none)

  // Set document metadata; no creation timestamp, so rebuilding an unchanged paper gives identical bytes
  set document(title: fm.title, author: fm.authors.map(author => author.name), date: none)
  let theme = (color: arkBlue, font: sansFont)
  if (page-start != none) {counter(page).update(page-start)}
  state("THEME").update(theme)
  set page(
    paper: paper-size,
    margin: (left: marginLeft, right: marginRight, top: 1in, bottom: 1in),
    header: {
      set text(font: sansFont, size: 8pt, fill: arkGrey)
      pubmatter.show-page-header(fm)
    },
    footer: block(
      width: 100%,
      stroke: (top: 0.5pt + arkGrey.lighten(40%)),
      inset: (top: 8pt, right: 2pt),
      context [
        #set text(font: sansFont, size: 8pt, fill: arkGrey)
        // The venue with its volume and issue, in the form the "Cite as" entry uses
        #if "venue" in fm [#fm.venue#if volume != none [ #volume]#if issue != none [ (#issue)]]
        #h(1fr)
        #counter(page).display()
      ]
    ),
  )

  // Rules for text in footnotes go here, before the title block: a footnote picks up only rules set before it
  show raw.where(block: true): set text(font: monoFont, size: 8pt)
  // Typst reads ' after a digit as a prime, so "Table 1's" would print a prime. Restore the apostrophe,
  // except in inline code, which a state marks because show rules cannot see their surroundings.
  let inCode = state("ark-inline-code", false)
  // Inline code keeps Typst's 0.8em against a text face of the same x-height, so it reads a shade
  // smaller than its surroundings. An empty box after _ and . lets a long name wrap without
  // adding a character to copied text.
  show raw.where(block: false): it => {
    set text(font: monoFont)
    show regex("[_.]"): s => [#s#box()]
    inCode.update(true); it; inCode.update(false)
  }
  show regex("\d's\b"): it => context if inCode.get() { it } else { it.text.slice(0, -2) + sym.quote.r.single + "s" }

  // Citations and URLs leave the document, so they are blue; internal references stay black
  show link: it => if type(it.dest) == str { text(fill: arkBlue, it) } else { it }
  show cite: set text(fill: arkBlue)
  // A native reference to an appendix heading reads "Appendix A" rather than "Section 3"
  show ref: it => context {
    let el = it.element
    let appendix = if el != none and el.func() == heading and el.numbering != none { appendixNumber(el.location()) }
    if appendix == none { it } else { link(it.target)[Appendix #appendix] }
  }

  // Body text: serif at 11pt keeps the measure under 80 characters
  set text(font: serifFont, size: 11pt, number-type: "lining")
  set par(justify: true, leading: 0.72em, spacing: 0.72em, first-line-indent: 1.2em)
  show math.equation: set text(font: mathFont)
  set math.equation(numbering: "(1)")
  show math.equation.where(block: true): set block(spacing: 1.1em)
  set footnote.entry(separator: line(length: 25%, stroke: 0.5pt + arkGrey))
  show footnote.entry: set text(size: 8.5pt)

  // Configure lists.
  set enum(indent: 1.2em, body-indent: 0.6em)
  set list(indent: 1.2em, body-indent: 0.6em)

  // A definition list sets its term the way the margin sets a field label, in the sans at Econ-ARK blue
  // Replacing the item drops the block Typst wraps it in, so the block comes back here
  show terms.item: it => block(above: 0.7em, below: 0.7em, {
    set par(first-line-indent: 0pt)
    text(font: sansFont, weight: 500, fill: arkBlue, it.term)
    h(0.7em)
    it.description
  })

  // A quotation carries the admonition's left rule, in grey so it reads quieter than a note
  show quote.where(block: true): it => block(
    width: 100%,
    inset: (left: 0.9em),
    stroke: (left: 2pt + arkGrey.lighten(50%)),
    {
      it.body
      if it.attribution != none {
        parbreak()
        text(font: sansFont, size: 9pt, fill: arkGrey, [#sym.dash.em #it.attribution])
      }
    },
  )

  // Headings: sans, sentence case as written, numbers in grey
  set heading(numbering: heading-numbering)
  show heading: it => {
    let number = if it.numbering != none {
      context {
        let appendix = appendixNumber(it.location())
        let shown = if appendix == none { counter(heading).display(it.numbering) } else if it.level == 1 { [Appendix #appendix] } else { appendix }
        text(fill: arkGrey, weight: "regular", shown)
      }
      h(0.6em)
    }
    set par(first-line-indent: 0pt, justify: false)
    if it.level == 1 {
      set text(font: sansFont, size: 13pt, weight: 500, fill: arkBlue)
      block(above: 1.8em, below: 0.9em, sticky: true, number + it.body)
    } else if it.level == 2 {
      set text(font: sansFont, size: 11pt, weight: 500)
      block(above: 1.4em, below: 0.7em, sticky: true, number + it.body)
    } else {
      set text(style: "italic")
      block(above: 1.2em, below: 0.6em, sticky: true, number + it.body)
    }
  }

  // Margin rail, top: the logo links to econ-ark.org
  place(
    top,
    dx: -33%,
    float: false,
    box(width: railWidthPercent, link(venueUrl, venueLogo)),
  )

  // Title block. An author's note is that author's, so it hangs off their name rather than the
  // paper's title; the funding statement is the paper's and sits in the margin rail below.
  {
    set par(first-line-indent: 0pt, justify: false)
    let fm-title = fm
    fm-title.authors = fm.authors.map(a => if "note" in a {
      a + (name: [#a.name#footnote(numbering: authorNoteSymbol, a.note)])
    } else { a })
    titleBlock(fm-title)
  }
  counter(footnote).update(0)

  let corresponding = pubmatter.get-corresponding-author(fm)
  // Only web addresses print; a download that points to one of the project's own exports resolves on the MyST site alone
  let webDownloads = downloads.filter(d => d.url.starts-with(regex("https?://")))
  let bibtexUrl = webDownloads.find(d => d.url.ends-with(".bib"))
  let formats = webDownloads.filter(d => not d.url.ends-with(".bib"))
  // In this order: running the paper, its code, its REMARK, the paper in other formats
  let materials = (
    if binder != none {
      (binder-label, [#link(binder)[Launch] \ #materialNote[Starts in a few minutes]])
    },
    if github != none {
      let repo = github.replace(regex("^https?://(www\.)?github\.com/"), "").trim("/")
      ("Code", [#link(github, repo)#if code-license != none [ \ #materialNote[#link(code-license.url, code-license.id) license]]])
    },
    if remark != none {
      ("REMARK", link("https://econ-ark.org/materials/" + remark, remark))
    },
    if source != none {
      ("Source", link(source, source.replace(regex("^https?://(www\.)?"), "").trim("/")))
    },
    if formats.len() > 0 {
      ("Also as", formats.map(d => link(d.url, d.title)).join(linebreak()))
    },
  ).filter(x => x != none)

  // The DOI follows the citation as a URL, as Chicago style asks; arXiv and Zenodo follow as short links
  let doiUrl = if doi != none { "https://doi.org/" + doi.replace(regex("^https?://(dx\.)?doi\.org/"), "") }
  let otherVersions = (
    if arxiv != none { link(arxiv, "arXiv:" + arxiv.replace(regex("^https?://(www\.)?arxiv\.org/(abs|pdf)/|\.pdf$"), "")) },
    if zenodo != none { link(zenodo, "Zenodo archive") },
    if bibtexUrl != none { link(bibtexUrl.url, "BibTeX") },
  ).filter(x => x != none)
  let pages = if page-start != none and last-page != none { str(page-start) + "-" + str(last-page) }
  // The citation and the copyright line date the paper the same way, from the one date it has
  let year = if type(fm.date) == datetime { fm.date.year() }

  // The rail in two groups. The first and last are what a reader of the paper needs beside it; the
  // middle one moves under the abstract when the column cannot hold everything, the way key points
  // do, since a rail placed from the bottom would otherwise grow up over the logo.
  let railHead = (
    // Shown once the paper has a persistent identifier, which marks it as ready to cite
    if doiUrl != none or otherVersions.len() > 0 {
      railItem("Cite as", {
        citation(frontmatter.authors, year, frontmatter.title, frontmatter.at("venue", default: none), volume, issue, pages)
        // A new line for each link, so a long URL breaks once rather than mid-sentence
        for version in (if doiUrl != none { (link(doiUrl),) } else { () }) + otherVersions {
          linebreak()
          version
        }
      })
    },
    if corresponding != none and "email" in corresponding {
      railItem("Correspondence", [#corresponding.name\ #link("mailto:" + corresponding.email, corresponding.email)])
    },
  ).filter(x => x != none)

  // People who worked on the paper without authoring it, and the money behind it. MyST carries all
  // three and a site theme shows none of them, so the rail is where a reader meets them.
  let fundingStatements = funding.filter(f => f != "").map(closeSentence)
  let railExtra = (
    ..(("Reviewers", reviewers), ("Editors", editors)).map(((label, names)) => {
      if names.len() > 0 { (label, names.join(linebreak()), names.join(", ")) }
    }),
    if fundingStatements.len() > 0 { ("Funding", fundingStatements.join(" "), fundingStatements.join(" ")) },
  ).filter(x => x != none)

  let railTail = (
    {
      let license = frontmatter.at("license", default: none)
      let notice = {
        set par(justify: false)
        set text(size: 6.5pt, fill: arkGrey)
        copyrightNotice(frontmatter.authors, year, copyright, license)
      }
      if license != none {
        railItem([License #h(1fr) #pubmatter.show-license-badge(color: arkGrey, fm)], notice)
      } else if copyright != none {
        railItem("Copyright", notice)
      }
    },
  ).filter(x => x != none)

  // Margin rail, bottom: what kind of paper this is, then the information a reader acts on
  let railBottomWith(extras) = {
    // Rail size set here so line spacing scales with the small type
    set text(font: sansFont, size: 7.5pt)
    set par(first-line-indent: 0pt, justify: false, leading: 0.5em, spacing: 0.6em)
    if (kind != none) {
      text(11pt, fill: arkBlue, weight: 500, kind)
      parbreak()
    }
    // MyST fills a missing date with the build date, so an undated paper shows the day it was built
    if (type(fm.date) == datetime) {
      text(size: 7.5pt, fill: arkGrey, fm.date.display("[month repr:long] [day padding:none], [year]"))
    }
    v(1.6em)
    grid(columns: 1, row-gutter: 1.6em, ..(railHead + extras.map(((label, railBody, _)) => railItem(label, railBody)) + railTail))
  }

  context {
    let railWidth = textColumn() * railFraction
    let height(it) = measure(block(width: railWidth, it)).height
    let keyPointsTop = height(venueLogo) + 2.4em.to-absolute()
    // The rail is placed from the bottom, so anything it cannot hold grows up over the logo. Give
    // the reviewers, editors and funding to the front matter instead when they do not fit under it.
    let railRoom = page.height - 2in - keyPointsTop - 1em.to-absolute() - 10pt
    // Typst holds back part of the region for the footnotes a page carries, and place(bottom) lands
    // on what is left, 43pt up the page for the two on page one. The room below counts none of that,
    // so it is discounted: undiscounted, a rail measuring 573pt into 576pt printed over the logo.
    let railExtraFits = height(railBottomWith(railExtra)) <= railRoom * 0.9
    let railBottom = railBottomWith(if railExtraFits { railExtra } else { () })
    // Key points sit under the logo, beside the title and abstract, unless they would run into the bottom of the rail
    let railKeyPoints = keypoints != none and keyPointsTop + height(keyPoints(keypoints)) + 3em.to-absolute() + height(railBottom) + 10pt <= page.height - 2in

    place(left + bottom, dx: railOffset, dy: -10pt, box(width: railWidthPercent, railBottom))
    if railKeyPoints {
      place(top, dx: railOffset, dy: keyPointsTop, box(width: railWidthPercent, keyPoints(keypoints)))
    }

    // Abstract, keywords and JEL codes, set as a run-in paragraph in the economics convention,
    // then key points that did not fit the rail and the reproducibility strip, so both are read before the paper begins
    let mainKeyPoints = keypoints != none and not railKeyPoints
    // Always drawn: the four-colour rule closes the front matter even when the paper has nothing above it
    {
      block(above: 1.4em, below: 2em, inset: (x: 1.5em), {
        set par(first-line-indent: 0pt)
        set text(size: 10pt)
        if ("abstracts" in fm) {
          for abs in fm.abstracts {
            labeledField(abs.title, abs.content, size: 9.5pt)
            parbreak()
          }
        }
        // MyST's `summary` part. Plainly "Summary": both "Plain Language" and "Non-technical"
        // tell the reader they are the ones needing it simplified. theme.css relabels the site,
        // whose theme hardcodes "Plain Language Summary", so one name serves both halves.
        if summary != none {
          v(0.5em)
          labeledField("Summary", summary, size: 9.5pt)
          parbreak()
        }
        set text(size: 9pt)
        set par(justify: false, spacing: 0.65em)
        if ("keywords" in fm and fm.keywords.len() > 0) {
          v(0.5em)
          labeledField("Keywords", fm.keywords.join(", "))
          parbreak()
        }
        if (jel.len() > 0) {
          labeledField("JEL codes", jel.join(", "))
        }
        // Whatever the rail could not hold, run in beside the keywords so none of it is lost
        if not railExtraFits {
          for (label, _, runIn) in railExtra {
            parbreak()
            labeledField(label, runIn)
          }
        }
        if mainKeyPoints {
          v(1.1em, weak: true)
          keyPoints(keypoints, size: 9pt)
        }
        // A bare rule sits a little lower, so it reads as a divider between the front matter and the text
        v(if materials.len() > 0 { 1.3em } else { 1.8em }, weak: true)
        materialsBlock(materials)
      })
    }
  }

  // A dedication is centred on a line of its own, as a book sets one, and an epigraph follows it as
  // a quotation set in from the right. Both come after the front matter and before the first
  // heading, which is where a site renders them and where a reader meets them in a book.
  if dedication != none {
    align(center, text(style: "italic", dedication))
    v(0.9em)
  }
  if epigraph != none {
    align(right, block(width: 72%, {
      set par(justify: false)
      set text(size: 9pt, style: "italic")
      epigraph
    }))
    v(0.9em)
  }

  // Line numbers start with the main text, so the title block and abstract stay clean
  set par.line(numbering: if linenumbers { n => text(font: sansFont, size: 7pt, fill: arkGrey, str(n)) } else { none })

  show raw.where(block: true): (it) => {
    set align(left)
    set par(justify: false)
    block(sticky: true, fill: arkBlue.lighten(95%), width: 100%, inset: 9pt, radius: 2pt, it)
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
      let columnWidth = textColumn() * (if wide { 1.33 } else { 1 })
      let height = measure(block(width: columnWidth, it)).height
      let fits = height <= page.height - 2in - 3em.to-absolute()
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

  set bibliography(title: [References], style: "chicago-author-date")
  show bibliography: (it) => {
    set text(9.5pt)
    set par(first-line-indent: 0pt, justify: false)
    set block(spacing: 0.7em)
    // Typst's title casing capitalizes a small word after a comma: "Money, Credit, And Banking".
    // Lowercase the words that are never given names; In, To and An can be, so they stay as set.
    show regex(", (And|Or|Nor|But|Of|The|For) "): m => lower(m.text)
    it
  }

  // Display the paper's contents.
  body
}
