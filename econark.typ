#import "@preview/pubmatter:0.2.2"

#let venueUrl = "https://econ-ark.org";
#let venueLogo = image("logo.png");
// Econ-ARK brand palette, from econ-ark.org assets/sass/_variables.scss
#let arkBlue = rgb("#1f476b");
#let arkGrey = rgb("#676470");
// The four logo curves, top to bottom; kept to marks that echo the logo, such as the materials rules
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

// Wide figure spanning the margin rail and text column. With float: false it stays in the text flow,
// right-aligned so the excess spills left over the rail; that collides with page one's margin notes.
#let fullwidth(it, float: true) = context {
  if not float {
    align(right, box(width: 133%, it))
  } else if here().page() == 1 {
    // A top float lands above the title; both branches float, so the anchor never moves and layout converges
    place(bottom, float: true, it)
  } else {
    // A float wider than the column is centered on it, so shifting by half the 33% overhang aligns it with the rail
    place(auto, dx: -16.5%, float: true, box(width: 133%, it))
  }
}

// Styles for the tables MyST writes with tablex: a bold header, a rule above and below it, no vertical lines.
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
  let style = (map-cells: tableCells(9pt), auto-vlines: false) + named
  style.insert("map-hlines", tableRules(header-rows: named.at("header-rows", default: 1), rows: rows))
  base(..style, ..args.pos())
}

// A small labelled block in the margin rail
#let railItem(title, content) = {
  text(size: 7.5pt, fill: arkBlue, weight: "semibold", title)
  linebreak()
  text(size: 7.5pt, content)
}

// Materials under the abstract: (label, body) groups in quarter-width columns under the logo's four colours.
// All four rules show however many groups a paper has, so the block always carries the full logo palette.
#let materialsBlock(groups) = {
  set text(font: sansFont, size: 8pt)
  set par(first-line-indent: 0pt, justify: false, leading: 0.45em, spacing: 0.45em)
  text(size: 8.5pt, fill: arkBlue, weight: "semibold", "Materials")
  v(5pt, weak: true)
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
  text(size: size - 0.5pt, fill: arkBlue, weight: "semibold", "Key points")
  v(0.6em, weak: true)
  body
}

// A link shown without its scheme, so it fits the rail
#let bareLink(url) = link(url, url.replace(regex("^https?://(www\.)?"), ""))

// An author's family name with its particle, such as "van Beethoven", or else the full name
#let familyName(a) = (a.at("particle", default: none), a.at("family", default: a.name)).filter(x => x != none).join(" ")

// Authors as an author-date citation names them: "Carroll", "Carroll and Lujan", "Carroll et al."
#let shortAuthors(authors) = if authors.len() == 0 { none } else if authors.len() == 1 { familyName(authors.first()) } else if authors.len() == 2 { authors.map(familyName).join(" and ") } else { familyName(authors.first()) + " et al." }

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
  let close(s) = if s.ends-with(regex("[.?!]")) { s } else { s + "." }
  [#close(holder) ]
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
  let close(s) = if s.ends-with(regex("[.?!]")) { s } else { s + "." }
  [#close(names) ]
  if year != none [#year. ]
  ["#close(title)"]
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
  title-note: none,
  paper-size: "us-letter",
  page-start: none,
  last-page: none,
  max-page: none,
  keypoints: none,
  // Citation details for the "Cite as" block; the DOI is kept out of frontmatter so the page header does not repeat it
  doi: none,
  arxiv: none,
  zenodo: none,
  volume: none,
  issue: none,
  summary: none,
  // Funding statements and awards, as strings, added to the starred title footnote
  funding: (),
  copyright: none,
  code-license: none,
  // Materials: a REMARK name on econ-ark.org, the label over the binder link, and (title, url) downloads
  remark: none,
  binder-label: "Run online",
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
    let fundingNote = funding.filter(f => f != "").map(f => if f.ends-with(regex("[.?!]")) { f } else { f + "." }).join(" ")
    let notes = (if title-note != none { (title-note,) } else { () }) + (if fundingNote != none { (fundingNote,) } else { () }) + frontmatter.authors.filter(a => "note" in a).map(a => [#a.name: #a.note])
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
  // Only web addresses print; a download that names one of the project's own exports resolves on the MyST site alone
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

  let rail = (
    // Shown once the paper has a persistent identifier, which marks it as ready to cite
    if doiUrl != none or otherVersions.len() > 0 {
      railItem("Cite as", {
        citation(frontmatter.authors, if type(fm.date) == datetime { fm.date.year() }, frontmatter.title, frontmatter.at("venue", default: none), volume, issue, pages)
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
    {
      let license = frontmatter.at("license", default: none)
      let year = if type(fm.date) == datetime { fm.date.year() }
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
  let railBottom = {
    // Rail size set here so line spacing scales with the small type
    set text(font: sansFont, size: 7.5pt)
    set par(first-line-indent: 0pt, justify: false, leading: 0.5em, spacing: 0.6em)
    if (kind != none) {
      text(11pt, fill: arkBlue, weight: "semibold", kind)
      parbreak()
    }
    // MyST fills a missing date with the build date, so an undated paper shows the day it was built
    if (type(fm.date) == datetime) {
      text(size: 7.5pt, fill: arkGrey, fm.date.display("[month repr:long] [day padding:none], [year]"))
    }
    v(1.6em)
    grid(columns: 1, row-gutter: 1.6em, ..rail)
  }

  context {
    // The rail is 27% of the text column, which is the page less its 25% left and 1.35in right margins
    let railWidth = (page.width * 0.75 - 1.35in) * 0.27
    let height(it) = measure(block(width: railWidth, it)).height
    let keyPointsTop = height(venueLogo) + 2.4em.to-absolute()
    // Key points sit under the logo, beside the title and abstract, unless they would run into the bottom of the rail
    let railKeyPoints = keypoints != none and keyPointsTop + height(keyPoints(keypoints)) + 3em.to-absolute() + height(railBottom) + 10pt <= page.height - 2in

    place(left + bottom, dx: -33%, dy: -10pt, box(width: 27%, railBottom))
    if railKeyPoints {
      place(top, dx: -33%, dy: keyPointsTop, box(width: 27%, keyPoints(keypoints)))
    }

    // Abstract, keywords and JEL codes, set as a run-in paragraph in the economics convention,
    // then key points that did not fit the rail and the reproducibility strip, so both are read before the paper begins
    let mainKeyPoints = keypoints != none and not railKeyPoints
    if ("abstracts" in fm or summary != none or "keywords" in fm or jel.len() > 0 or materials.len() > 0 or mainKeyPoints) {
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
        // The summary part: the non-technical summary some discussion paper series ask for
        if summary != none {
          v(0.5em)
          text(font: sansFont, weight: "semibold", fill: arkBlue, size: 9.5pt, "Non-technical summary")
          h(0.7em)
          summary
          parbreak()
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
        if mainKeyPoints {
          v(1.1em, weak: true)
          keyPoints(keypoints, size: 9pt)
        }
        if (materials.len() > 0) {
          v(1.3em, weak: true)
          materialsBlock(materials)
        }
      })
    }
  }

  // Line numbers start with the main text, so the title block and abstract stay clean
  set par.line(numbering: if linenumbers { n => text(font: sansFont, size: 7pt, fill: arkGrey, str(n)) } else { none })

  show raw: set text(font: "DejaVu Sans Mono", size: 8pt)
  // Typst reads ' after a digit as a prime, so "Table 1's" would print a prime. Restore the apostrophe,
  // except in inline code, which a state marks because show rules cannot see their surroundings.
  let inCode = state("ark-inline-code", false)
  show raw.where(block: false): it => { inCode.update(true); it; inCode.update(false) }
  show regex("\d's\b"): it => context if inCode.get() { it } else { it.text.slice(0, -2) + sym.quote.r.single + "s" }
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
  // MyST writes `show figure: set block(breakable: breakableDefault)` into each article of a multi-article
  // export, where breakableDefault is true. An explicit argument outranks that set rule, so wrap figures and
  // tables in an unbreakable block; theorem-like figures stay breakable, since a proof may span pages.
  show figure: it => if it.placement == none and it.kind in ("figure", "table", "code", image, table, raw) {
    block(above: 1.4em, below: 1.4em, breakable: false, it)
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
