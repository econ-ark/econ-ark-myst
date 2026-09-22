// The template's public surface: template.typ glob-imports this file, and Typst re-exports what a
// module glob-imported, so every name the modules below define arrives through here unchanged.
#import "@preview/pubmatter:0.2.2"
#import "ark/brand.typ": *
#import "ark/layout.typ": *
#import "ark/figures.typ": *
#import "ark/tables.typ": *
#import "ark/frontmatter.typ": *
#import "ark/blocks.typ": *
#import "ark/typography.typ": *
#import "ark/floats.typ": *

// MyST writes myst-imports.typ, and template.typ glob-imports it over this file, only for a
// document that needs a package. This default is what a document without one leaves standing, so
// template.typ can ask whether the name arrived rather than whether a file was written.
#let tablex = none

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
  // Where the MyST site is served, such as "https://econ-ark.org". A page exported on its own links
  // the project's other pages by path, and each path resolves against this address
  site-url: none,
  // "all", or the labels of the tables whose Typst twin is the copy to print, described in ark/tables.typ
  twinned-tables: none,
  // Labels of the figures that span the margin rail as well as the text column
  wide-figures: none,
  // Label of the heading the appendices start at, in place of an <appendix> marker in the body
  appendix-from: none,
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
    margin: (left: marginLeft, right: marginRight, top: marginTop, bottom: marginBottom),
    header: {
      set text(font: sansFont, size: 8pt, fill: arkGrey)
      pubmatter.show-page-header(fm)
    },
    footer: block(
      width: 100%,
      stroke: (top: 0.5pt + arkRule),
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

  // The running text, set before the title block because a footnote picks up only rules set
  // before it, and the title block carries the author notes
  show: arkTypography.with(heading-numbering, site-url)

  // Margin rail, top: the logo links to econ-ark.org
  place(
    top,
    dx: railOffset,
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
  // The code leads, being the column that outlives the rest: a binder link is the first to rot.
  // Then running it, its REMARK, the paper in other formats. Four colours, so four slots: source
  // and github name the same thing often enough that they share one, and source wins it.
  let repoUrl = if source != none { source } else { github }
  let materials = (
    if repoUrl != none {
      // The slash is the break a reader expects; Typst otherwise prefers a hyphen inside the name,
      // which fills the line better. Boxing each part makes the slash preferred, and a name too
      // long for its column still breaks at its hyphens. A box leaves copied text unchanged.
      let repo = repoUrl.replace(regex("^https?://(www\.)?github\.com/"), "").trim("/")
      let broken = repo.split("/").map(part => box(part)).intersperse("/").join()
      ("Code", [#link(repoUrl, broken)#if code-license != none [ \ #materialNote[#link(code-license.url, code-license.id) license]]])
    },
    if binder != none {
      (binder-label, [#link(binder)[Launch] \ #materialNote[Starts in a few minutes]])
    },
    if remark != none {
      // The slug alone reads as a second code link, so the note names where it leads
      ("REMARK", [#link("https://econ-ark.org/materials/" + remark, remark) \ #materialNote[on econ-ark.org]])
    },
    if formats.len() > 0 {
      ("Download", formats.map(d => link(d.url, d.title)).join(linebreak()))
    },
  ).filter(x => x != none)
  // Four colours, four slots. Reaching five means a new material kind arrived without one being
  // retired. Fail at build time; a fifth column would otherwise print under no rule.
  assert(materials.len() <= 4, message: "the materials block holds four columns, one per logo colour, and " + str(materials.len()) + " materials were given")

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
    let railRoom = textHeight() - keyPointsTop - 1em.to-absolute() - 10pt
    // Typst holds back part of the region for the footnotes a page carries, and place(bottom) lands
    // on what is left, 43pt up the page for the two on page one. The room below counts none of that,
    // so it is discounted: undiscounted, a rail measuring 573pt into 576pt printed over the logo.
    let railWithExtra = railBottomWith(railExtra)
    let railExtraFits = height(railWithExtra) <= railRoom * 0.9
    let railBottom = if railExtraFits { railWithExtra } else { railBottomWith(()) }
    // Key points sit under the logo, beside the title and abstract, unless they would run into the bottom of the rail
    let railKeyPoints = keypoints != none and keyPointsTop + height(keyPoints(keypoints)) + 3em.to-absolute() + height(railBottom) + 10pt <= textHeight()

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

  // Code blocks, table figures and where each figure ends up
  show: arkFloats.with(figure-placement, arkLabelList(wide-figures))
  // Last, so it reaches a twinned table before the rules above wrap it, and so the twin it puts in
  // the parsed copy's place is styled and placed as every other table here is
  show: arkTwinnedTables.with(arkTwinnedSpec(twinned-tables))
  // The marker the appendix lettering counts from, in front of the heading the option names
  show: arkAppendixFrom.with(appendix-from)

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

  // A label the document does not carry passes silently through the options below: the table
  // prints twice, the figure stays narrow, the appendices go unlettered. Stop the build instead.
  context {
    let absent = ()
    for (option, labels) in (
      ("twinned_tables", arkTwinnedSpec(twinned-tables)),
      ("wide_figures", arkLabelList(wide-figures)),
      ("appendix_from", arkLabelList(appendix-from)),
    ) {
      if type(labels) == array {
        for name in labels {
          if query(label(name)).len() == 0 { absent.push(option + " names " + name) }
        }
      }
    }
    assert(absent.len() == 0, message: absent.join("; ") + ", and this document carries no such label")
  }
}
