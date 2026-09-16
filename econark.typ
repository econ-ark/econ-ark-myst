#import "@preview/pubmatter:0.2.2"

#let venueUrl = "https://econ-ark.org";
#let venueLogo = image("logo.png");
// Econ-ARK brand palette, from econ-ark.org assets/sass/_variables.scss
#let arkBlue = rgb("#1f476b");
#let arkGrey = rgb("#676470");
// The four logo curves, top to bottom; used only in the logo's own contexts, never for text
#let arkCurves = (rgb("#fcb040"), rgb("#ed217c"), rgb("#00aeef"), rgb("#39b54a"));
// Preferred fonts first, then fonts bundled with Typst so the template always compiles
#let sansFont = ("Roboto", "Libertinus Serif");
#let serifFont = ("Libertinus Serif", "New Computer Modern");
#let mathFont = ("Libertinus Math", "New Computer Modern Math");

#let leftCaption(it) = context {
  set text(font: sansFont, size: 8.5pt)
  set align(left)
  set par(justify: false, first-line-indent: 0pt)
  text(weight: "semibold", fill: arkBlue)[#it.supplement #it.counter.display(it.numbering)]
  h(6pt)
  it.body
}

// Wide figure spanning the margin rail and text column, floated to the top or bottom of the page.
// Page one floats to the bottom at column width: a top float lands above the title. Both branches
// float, so the choice never moves the anchor and the layout converges.
#let fullwidth(it) = context {
  if here().page() == 1 {
    place(bottom, float: true, it)
  } else {
    // A float wider than the column is centered on it, so shifting by half the 33% overhang aligns it with the rail
    place(auto, dx: -16.5%, float: true, box(width: 133%, it))
  }
}

#let smallTableStyle = (
  map-cells: cell => {
    if (cell.y == 0) {
      return (..cell, content: strong(text(cell.content, 7pt)))
    }
    (..cell, content: text(cell.content, 7pt))
  },
  auto-vlines: false,
  map-hlines: line => {
    if (line.y == 0 or line.y == 1) {
      line.stroke = arkGrey + 0.75pt;
    } else {
      line.stroke = 0pt;
    }
    return line
  },
)

// A small labelled block in the margin rail
#let railItem(title, content) = {
  text(size: 7.5pt, fill: arkBlue, weight: "semibold", title)
  linebreak()
  text(size: 7.5pt, content)
}

// Reproducibility strip under the abstract: the logo's four curves as its edge, items in one row
#let reproduceBlock(items) = {
  set text(font: sansFont)
  set par(first-line-indent: 0pt, justify: false, leading: 0.45em, spacing: 0.45em)
  // Cell fills stretch to the row height, which a rect cannot do
  grid(
    columns: (1.2pt, 1.2pt, 1.2pt, 1.2pt, 1fr),
    column-gutter: (0.9pt, 0.9pt, 0.9pt, 8pt),
    inset: 0pt,
    fill: (x, y) => if x < arkCurves.len() { arkCurves.at(x) },
    [], [], [], [],
    block(inset: (y: 2pt), {
      text(size: 8.5pt, fill: arkBlue, weight: "semibold", "Reproduce this paper")
      v(5pt, weak: true)
      grid(
        columns: items.len(),
        column-gutter: 1.6em,
        ..items.map(((label, value)) => {
          text(size: 7pt, fill: arkGrey, label)
          linebreak()
          text(size: 8pt, value)
        }),
      )
    }),
  )
}

// Theorem-like blocks from MyST prf: directives, set in flow the way economics papers set them.
// Replaces MyST's own proof(), which floats each block to the top of the page inside a tinted box.
#let italicKinds = ("theorem", "lemma", "proposition", "corollary", "conjecture", "claim")
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
      [#text(font: sansFont, weight: "semibold", fill: arkBlue)[#it.supplement #it.counter.display(it.numbering)]#note. #it.body]
    })
    #figure(kind: kind, supplement: supplement, numbering: "1", outlined: false, statement)#if labelName != none { label(labelName) }]
}

#let template(
  frontmatter: (),
  heading-numbering: "1.1.1",
  kind: none,
  jel: (),
  linenumbers: false,
  binder: none,
  title-note: none,
  paper-size: "us-letter",
  page-start: none,
  max-page: none,
  // The paper's content.
  body
) = {
  let fm = pubmatter.load(frontmatter)
  // pubmatter.load drops a document-level github and defaults a missing date to today
  let github = frontmatter.at("github", default: none)
  let has-date = "date" in frontmatter

  // Set document metadata; no creation timestamp, so rebuilding an unchanged paper gives identical bytes
  set document(title: fm.title, author: fm.authors.map(author => author.name), date: none)
  let theme = (color: arkBlue, font: sansFont)
  if (page-start != none) {counter(page).update(page-start)}
  state("THEME").update(theme)
  set page(
    paper: paper-size,
    margin: (left: 25%, right: 1.35in, top: 1in, bottom: 1in),
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
        #if "venue" in fm { fm.venue }
        #h(1fr)
        #counter(page).display()
      ]
    ),
  )

  // Citations and URLs leave the document, so they are blue; internal references stay black
  show link: it => if type(it.dest) == str { text(fill: arkBlue, it) } else { it }
  show cite: set text(fill: arkBlue)

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

  // Headings: sans, sentence case as written, numbers in grey
  set heading(numbering: heading-numbering)
  show heading: it => {
    let number = if it.numbering != none {
      text(fill: arkGrey, weight: "regular", counter(heading).display(it.numbering))
      h(0.6em)
    }
    set par(first-line-indent: 0pt, justify: false)
    if it.level == 1 {
      set text(font: sansFont, size: 13pt, weight: "semibold", fill: arkBlue)
      block(above: 1.8em, below: 0.9em, sticky: true, number + it.body)
    } else if it.level == 2 {
      set text(font: sansFont, size: 11pt, weight: "semibold")
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
    box(width: 27%, link(venueUrl, venueLogo)),
  )

  // Title block, with the title note and author notes as a starred footnote on the title
  {
    set par(first-line-indent: 0pt, justify: false)
    let notes = (if title-note != none { (title-note,) } else { () }) + frontmatter.authors.filter(a => "note" in a).map(a => [#a.name: #a.note])
    if notes.len() > 0 {
      let fm-title = fm
      fm-title.title = [#fm.title#footnote(numbering: "*", notes.join(" "))]
      pubmatter.show-title-block(fm-title)
    } else {
      pubmatter.show-title-block(fm)
    }
  }
  counter(footnote).update(0)

  let corresponding = pubmatter.get-corresponding-author(fm)
  let reproduce = (
    if github != none { ("Code", link(github, github.replace(regex("^https?://(www\.)?"), ""))) },
    if binder != none { ("Run online", link(binder, "Launch on Binder")) },  ).filter(x => x != none)

  let rail = (
    if corresponding != none and "email" in corresponding {
      railItem("Correspondence", [#corresponding.name\ #link("mailto:" + corresponding.email, corresponding.email)])
    },
    if "license" in fm and fm.license != none {
      railItem([License #h(1fr) #pubmatter.show-license-badge(color: arkGrey, fm)], {
        set par(justify: false)
        set text(size: 6.5pt, fill: arkGrey)
        pubmatter.show-copyright(fm)
      })
    },
  ).filter(x => x != none)

  // Margin rail, bottom: what kind of paper this is, then the information a reader acts on
  place(
    left + bottom,
    dx: -33%,
    dy: -10pt,
    box(width: 27%, {
      // Rail size set here so line spacing scales with the small type
      set text(font: sansFont, size: 7.5pt)
      set par(first-line-indent: 0pt, justify: false, leading: 0.5em, spacing: 0.6em)
      if (kind != none) {
        text(11pt, fill: arkBlue, weight: "semibold", kind)
        parbreak()
      }
      if (has-date and type(fm.date) == datetime) {
        text(size: 7.5pt, fill: arkGrey, fm.date.display("[month repr:long] [day], [year]"))
      }
      v(1.6em)
      grid(columns: 1, row-gutter: 1.6em, ..rail)
    }),
  )

  // Abstract, keywords and JEL codes, set as a run-in paragraph in the economics convention,
  // then the reproducibility strip, so it is read before the paper begins
  if ("abstracts" in fm or "keywords" in fm or jel.len() > 0 or reproduce.len() > 0) {
    block(above: 1.4em, below: 2em, inset: (x: 1.5em), {
      set par(first-line-indent: 0pt)
      set text(size: 10pt)
      if ("abstracts" in fm) {
        for abs in fm.abstracts {
          text(font: sansFont, weight: "semibold", fill: arkBlue, size: 9.5pt, abs.title)
          h(0.7em)
          abs.content
          parbreak()
        }
      }
      set text(size: 9pt)
      set par(justify: false, spacing: 0.65em)
      if ("keywords" in fm and fm.keywords.len() > 0) {
        v(0.5em)
        text(font: sansFont, weight: "semibold", fill: arkBlue, size: 8.5pt, "Keywords")
        h(0.7em)
        fm.keywords.join(", ")
        parbreak()
      }
      if (jel.len() > 0) {
        text(font: sansFont, weight: "semibold", fill: arkBlue, size: 8.5pt, "JEL codes")
        h(0.7em)
        jel.join(", ")
      }
      if (reproduce.len() > 0) {
        v(1.1em, weak: true)
        reproduceBlock(reproduce)
      }
    })
  }

  // Line numbers start with the main text, so the title block and abstract stay clean
  set par.line(numbering: if linenumbers { n => text(font: sansFont, size: 7pt, fill: arkGrey, str(n)) } else { none })

  show raw: set text(font: "DejaVu Sans Mono", size: 8pt)
  show raw.where(block: true): (it) => {
    set align(left)
    set par(justify: false)
    block(sticky: true, fill: arkBlue.lighten(95%), width: 100%, inset: 9pt, radius: 2pt, it)
  }
  show figure.caption: leftCaption
  // MyST emits the string kind; a native table() in a raw typst block gets the function kind
  show figure.where(kind: "table"): set figure.caption(position: top)
  show figure.where(kind: table): set figure.caption(position: top)
  // Justified text stretches a short cell and hyphenation splits its words
  show figure.where(kind: "table"): set par(justify: false)
  show figure.where(kind: table): set par(justify: false)
  show figure.where(kind: "table"): set text(hyphenate: false)
  show figure.where(kind: table): set text(hyphenate: false)
  // Articles in a multi-article export are #include'd files that see MyST's empty tableStyle,
  // so tablex draws a full grid there. Drop its vertical rules and lighten the rest; lines
  // drawn with an explicit stroke, as the template's tableStyle does, keep that stroke.
  show figure.where(kind: "table"): it => {
    show line: l => if l.start.at(0) == l.end.at(0) { none } else { l }
    set line(stroke: 0.5pt + arkGrey)
    set text(size: 9pt)
    it
  }
  // Figures and tables move whole to the next page rather than splitting a table across the break
  show figure: set block(above: 1.4em, below: 1.4em, breakable: false)
  set figure(placement: none)

  set bibliography(title: [References], style: "chicago-author-date")
  show bibliography: (it) => {
    set text(9.5pt)
    set par(first-line-indent: 0pt, justify: false)
    set block(spacing: 0.7em)
    it
  }

  // Display the paper's contents.
  body
}
