[#- macro s(value) -#]"[- value | replace("\\", "\\\\") | replace('"', '\\"') -]"[#- endmacro -#]
#import "econ-ark.typ": *

[-IMPORTS-]

// MyST sets figure breakability from this binding; econ-ark.typ keeps a figure that fits a page whole
#let breakableDefault = true
// Theorem-like blocks in flow, replacing the floating boxes defined in the imports above
#let proof = arkProof

#let tableStyle = arkTableStyle
// Admonitions, replacing the boxes defined in the imports above. The names are what MyST looks
// up; arkAdmonitions in econ-ark.typ is which colour each kind takes.
#let noteBlock = arkAdmonitions.note
#let importantBlock = arkAdmonitions.important
#let tipBlock = arkAdmonitions.tip
#let hintBlock = arkAdmonitions.hint
#let seealsoBlock = arkAdmonitions.seealso
#let attentionBlock = arkAdmonitions.attention
#let cautionBlock = arkAdmonitions.caution
#let warningBlock = arkAdmonitions.warning
#let dangerBlock = arkAdmonitions.danger
#let errorBlock = arkAdmonitions.error
// MyST's own imports above bind tablex for a document with a table, leaving econ-ark.typ's none
// standing for one without. subpar arrives the same way but is called as a field, so the wrapper
// has to be a module, and a module can only come from a file.
[# if IMPORTS #]
#let tablex = if tablex != none { arkTablex.with(tablex) }
#import "ark/subpar.typ" as subpar
[# endif #]

// Every frontmatter string goes through s(), which escapes backslashes and double quotes for a Typst string
#show: template.with(
  frontmatter: (
    title: [-s(doc.title)-],
  [# if parts.abstract #]
    abstract: [
      [-parts.abstract-]
    ],
  [# endif #]
  [# if doc.subtitle #]
    subtitle: [-s(doc.subtitle)-],
  [# endif #]
  [# if doc.short_title #]
    short-title: [-s(doc.short_title)-],
  [# endif #]
  [# if doc.venue.title #]
    venue: [-s(doc.venue.title)-],
  [# endif #]
  [# if doc.open_access #]
    // pubmatter shows the badge whenever the key is present, so open_access: false must leave it out
    open-access: true,
  [# endif #]
  [# if doc.github #]
    github: [-s(doc.github)-],
  [# endif #]
  [# if doc.date #]
    date: datetime(
      year: [-doc.date.year-],
      month: [-doc.date.month-],
      day: [-doc.date.day-],
    ),
  [# endif #]
  [# if doc.keywords #]
    keywords: (
      [#- for keyword in doc.keywords -#][-s(keyword)-],[#- endfor -#]
    ),
  [# endif #]
    authors: (
  [# for author in doc.authors #]
      (
        name: [-s(author.name)-],
  [# if author.nameParsed.family #]
        family: [-s(author.nameParsed.family)-],
  [# endif #]
  [# if author.nameParsed.given #]
        given: [-s(author.nameParsed.given)-],
  [# endif #]
  [# if author.nameParsed.non_dropping_particle #]
        particle: [-s(author.nameParsed.non_dropping_particle)-],
  [# endif #]
  [# if author.nameParsed.suffix #]
        suffix: [-s(author.nameParsed.suffix)-],
  [# endif #]
  [# if author.orcid #]
        orcid: [-s(author.orcid)-],
  [# endif #]
  [# if author.email #]
        email: [-s(author.email)-],
  [# endif #]
  [# if author.note #]
        note: [-s(author.note)-],
  [# endif #]
  [# if author.corresponding #]
        corresponding: [-author.corresponding.value-],
  [# endif #]
  [# if author.equal_contributor #]
        equal-contributor: [-author.equal_contributor-],
  [# endif #]
  [# if author.affiliations #]
        affiliations: ([#- for aff in author.affiliations -#]"[-aff.index-]"[#- if not loop.last -#],[#- endif -#][#- endfor -#]),
  [# endif #]
      ),
  [# endfor #]
    ),
    affiliations: (
  [# for aff in doc.affiliations #]
      (
        id: "[-aff.index-]",
  [# if aff.department and aff.name.indexOf(aff.department) == -1 #]
        name: [-s(aff.department ~ ", " ~ aff.name)-],
  [# else #]
        name: [-s(aff.name)-],
  [# endif #]
  [# if aff.ror #]
        ror: [-s(aff.ror)-],
  [# endif #]
      ),
  [# endfor #]
    ),
  [# if doc.license.content #]
    license: (id: [-s(doc.license.content.id)-], name: [-s(doc.license.content.name)-], url: [-s(doc.license.content.url)-]),
  [# endif #]
  ),
  [# if options.kind #]
  kind: [-s(options.kind)-],
  [# elif doc.subject #]
  kind: [-s(doc.subject)-],
  [# endif #]
  [# if parts.keypoints #]
  keypoints: [
    [-parts.keypoints-]
  ],
  [# endif #]
  [# if doc.doi #]
  doi: [-s(doc.doi)-],
  [# endif #]
  [# if doc.identifiers.arxiv #]
  arxiv: [-s(doc.identifiers.arxiv)-],
  [# endif #]
  [# if doc.identifiers.zenodo #]
  zenodo: [-s(doc.identifiers.zenodo)-],
  [# endif #]
  [# if doc.volume.number #]
  volume: [-s(doc.volume.number)-],
  [# endif #]
  [# if doc.issue.number #]
  issue: [-s(doc.issue.number)-],
  [# endif #]
  [# if doc.last_page #]
  last-page: [-s(doc.last_page)-],
  [# endif #]
  [# if doc.tags #]
  jel: ([#- for code in doc.tags -#][-s(code)-],[#- endfor -#]),
  [# endif #]
  [# if options.linenumbers #]
  linenumbers: true,
  [# endif #]
  [# if doc.binder #]
  binder: [-s(doc.binder)-],
  [# endif #]
  [# if options.binder_label #]
  binder-label: [-s(options.binder_label)-],
  [# endif #]
  [# if options.figure_placement #]
  figure-placement: [-s(options.figure_placement)-],
  [# endif #]
  [# if options.remark #]
  remark: [-s(options.remark)-],
  [# endif #]
  [# if doc.downloads #]
  downloads: (
  [# for d in doc.downloads #]
  [# if d.url #]
    (url: [-s(d.url)-], title: [-s(d.title or d.filename or (d.url.split("/") | last))-]),
  [# endif #]
  [# endfor #]
  ),
  [# endif #]
  [# if parts.summary #]
  summary: [
    [-parts.summary-]
  ],
  [# endif #]
  [# if parts.dedication #]
  dedication: [
    [-parts.dedication-]
  ],
  [# endif #]
  [# if parts.epigraph #]
  epigraph: [
    [-parts.epigraph-]
  ],
  [# endif #]
  [# if doc.source #]
  source: [-s(doc.source)-],
  [# endif #]
  // MyST keeps one pool of people under doc.contributors, listing reviewers and editors as ids into it
  [# for group in [["reviewers", doc.reviewers], ["editors", doc.editors]] #]
  [# if group[1] #]
  [-group[0]-]: (
  [# for person in doc.contributors #]
  [# if group[1].includes(person.id) #]
    [-s(person.name)-],
  [# endif #]
  [# endfor #]
  ),
  [# endif #]
  [# endfor #]
  [# if doc.funding #]
  funding: (
  [# for entry in doc.funding #]
  [# if entry.statement #]
    [-s(entry.statement)-],
  [# endif #]
  [# for award in entry.awards #]
  [# if award.name and award.id #]
    [-s(award.name ~ " (" ~ award.id ~ ")")-],
  [# elif award.name or award.id #]
    [-s(award.name or award.id)-],
  [# endif #]
  [# endfor #]
  [# endfor #]
  ),
  [# endif #]
  [# if doc.copyright #]
  copyright: [-s(doc.copyright)-],
  [# endif #]
  [# if doc.license.code #]
  code-license: (id: [-s(doc.license.code.id)-], name: [-s(doc.license.code.name)-], url: [-s(doc.license.code.url)-]),
  [# endif #]
  [# if doc.numbering.heading_1.enabled === false or (doc.numbering.heading_1 === undefined and doc.numbering.all.enabled === false) #]
  heading-numbering: none,
  [# endif #]
  [# if doc.first_page #]
  page-start: [-doc.first_page-],
  [# endif #]
)

// Declarations come first to match the site, where the theme has a backmatter slot for
// acknowledgments and data availability but none for declarations, so the declarations render in
// the body above both and no reordering here can be met on that side.
#let backMatter = [
[# for part in [["Declarations", parts.declaration], ["Acknowledgments", parts.acknowledgments], ["Data availability", parts.data_availability]] #]
[# if part[1] #]
#heading(numbering: none)[[-part[0]-]]

[-part[1]-]
[# endif #]
[# endfor #]

[# if doc.bibtex #]
#bibliography([-s(doc.bibtex)-])
[# endif #]
]

// The back matter and references go before an <appendix> marker, or at the end when there is none.
// Show rules and labels, unlike names, also reach articles included in a multi-article export.
#show <appendix>: it => backMatter + it

[-CONTENT-]

#context if query(<appendix>).len() == 0 { backMatter }
