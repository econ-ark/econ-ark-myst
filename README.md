# Econ-ARK MyST Template

A Typst PDF template for Econ-ARK working papers, REMARKs and technical reports, for use with [MyST](https://mystmd.org).

In your `myst.yml` or article frontmatter add:

```yaml
exports:
  - id: pdf
    format: typst
    template: https://github.com/econ-ark/econ-ark-myst.git
    article: paper.md
    output: exports/paper.pdf
    kind: Working paper
```

Then run `myst build --typst`.

MyST clones the template from that URL once and keeps the clone under `_build/templates/typst`. It reuses that copy on every later build without asking the URL what it holds now. A paper therefore goes on building against the version it first downloaded. When this template changes, run:

```sh
myst clean --templates -y
```

A build against a stale clone exits 0 and writes a well-formed PDF, typeset from whatever the old copy said. The PDF also comes out identical to the last one, which reads as a build that did nothing, and the natural response to that is to run it again. `--force` rebuilds the paper without refreshing the clone, so it leaves the export where it was.

Two ways to see which version of the template produced a file. `pdffonts` on the export names the faces it embedded. Reading the cached copy says it outright, before you have any theory about the cause:

```sh
grep '#let serifFont' _build/templates/typst/*/*/econark.typ
```

## Requirements

- Typst 0.13 or newer (tested with 0.13.1 and 0.15.1). Typst 0.12 fails inside the `pubmatter` package.
- Fonts, which this repository fetches rather than tracks. `scripts/fonts.sh` names the releases and is the only file that does, so the PDF and the site are set from one pinned source:

  ```sh
  scripts/fonts.sh install     # Fira Sans, Fira Mono and Fira Math, where Typst will find them
  npm install                  # only for the site, see Equations on the site below
  scripts/fonts.sh webfonts    # fonts/, the faces theme.css serves to a browser
  ```

  `install` is all a paper needs. `webfonts` matters to anyone publishing a site with `theme.css`; it subsets with fontTools, which it takes from the environment or, failing that, fetches through `uv`. CI and the Pages deploy run the same script. A release change therefore moves every path at once.

  One family sets the whole paper: Fira Sans for text and apparatus, Fira Mono for code, and Fira Math, its OpenType math companion, for everything between dollars. Another release of either renders the same words to different line breaks, so a paper built against one stops matching its own tracked PDF. Without any of them the template still compiles with fonts bundled in the Typst binary, falling back to New Computer Modern for the text, DejaVu Sans Mono for code and New Computer Modern Math for equations. Typst's bundled faces are serif apart from the mono, so a paper built without Fira comes out in a serif.
- Ask only for a weight that has a file. Fira Sans carries 400, 500, 600 and 700, and the template stays on those. Take one format and keep to it. The release carries the same faces as `ttf` and as `otf`, this repository builds from the `ttf`, and a machine holding both renders whichever it reaches first. A weight with no file of its own sits midway between two that have one. The order the machine happened to find those two in then decides which it uses.

## Frontmatter

| Field | Where it appears | When unset |
|-------|------------------|------------|
| `title` | Title block, plus the running header when `short_title` is unset | Required |
| `subtitle` | Grey line under the title | Omitted |
| `authors` | Title block and "Cite as" entry | Required; MyST reports an error but still builds |
| author `orcid`, `email` | Linked icons after the name | Omitted |
| author `corresponding`, `email` | "Correspondence" in the margin, naming the first author with `corresponding: true`, or else the first with an email | Omitted when no author has an email |
| author `equal_contributor` | Dagger after the name, explained under the affiliations | Omitted |
| author `note` | Starred footnote on the title, for thanks and funding | Omitted |
| `affiliations`, affiliation `ror`, `department` | Numbered list under the authors, with a linked ROR icon. A `department` goes before the institution, as in "Department of Economics, Johns Hopkins University" | Omitted |
| `short_title` | Running header from page two | The title |
| `venue.title` | Footer and "Cite as" entry | Page number only |
| `open_access` | "Open Access" badge at the top of page one when `true` | Omitted |
| `subject` | Margin, as the kind of paper, for example `Working paper` or `REMARK` | Omitted |
| `date` | Margin, plus the year in the "Cite as" entry | The build date, so set it for a PDF that rebuilds identically |
| `keywords` | Under the abstract | Omitted |
| `tags` | JEL codes under the keywords. The [Econometric Society template](https://github.com/alanlujan91/econsoc_template) reads the same field, so one manuscript builds with both | Omitted |
| `doi`, `arxiv`, `zenodo` | "Cite as" block in the margin, described below | No "Cite as" block |
| `volume`, `issue`, `last_page` | Added to the "Cite as" entry. The volume and issue also follow the venue in the footer, as in "Econ-ARK Working Papers 1 (3)" | Left out of the entry and the footer |
| `license` | Margin, with a Creative Commons badge and a copyright line. With `license: {content: CC-BY-4.0, code: MIT}`, the code license shows under the code link in the materials block | Omitted |
| `copyright` | Replaces the author names in the margin's copyright line. Text that already carries "©" or starts with "Copyright" is printed as written | "Copyright © year" and the authors' family names |
| `funding` | Each statement, then each award as "name (id)", in the starred footnote on the title. Write `funding` as a list, because mystmd 1.10.1 stops with `funding?.forEach is not a function` on a single funding object | Omitted |
| `numbering` | `headings: false` removes the section numbers, including the appendix letters | Sections are numbered |
| `binder`, `github`, `downloads` | Materials block under the abstract, described below | With none of these and no `remark` option, the four-colour rule alone ends the front matter |
| `first_page` | Starting page number, also the first page in the "Cite as" entry | Pages start at 1 |
| `bibliography` | References, in Chicago author-date style, after the declarations | No references section |

These are all the fields the template reads. It ignores the fields that serve a website or a build, such as `description` and `thumbnail`, along with author `url`, `roles` and contact details, and affiliation addresses.

The "Cite as" block appears once the paper has a `doi`, `arxiv` or `zenodo` link, since a draft without a persistent identifier changes under its readers. It gives a Chicago author-date entry, the style of the reference list, followed by the DOI as a URL, the arXiv identifier and a link to the Zenodo archive. The entry lists up to three authors and shortens more to the first author and "et al." MyST reads a suffix such as "Jr." as part of the family name. To cite such a name correctly, give the author's `name` as an object with `given`, `family` and `suffix`.

The materials block lists what exists for the paper beyond the PDF, in up to four columns under rules in the four colours of the Econ-ARK logo. All four rules print however many columns a paper fills. A paper with no materials keeps the rules without the heading, as the line between its front matter and its text. The columns keep this order:

| Column | Source |
|--------|--------|
| Run online, or the `binder_label` option | `binder`, with a note that it starts in a few minutes |
| Code | `github`, shown as `owner/repo`, with the code license under it |
| REMARK | The `remark` option |
| Also as | Each entry of `downloads` with a web address, by its `title`. An entry whose address ends in `.bib` goes to "Cite as" as a BibTeX link instead |

```yaml
binder: https://econ-ark.org/materials/LiqConstr?dashboard
downloads:
  - title: Slides
    url: https://econ-ark.github.io/LiqConstr/LiqConstr-Slides.pdf
  - title: BibTeX
    url: https://econ-ark.github.io/LiqConstr/LiqConstr-Self.bib
exports:
  - format: typst
    remark: LiqConstr
    binder_label: Dashboard
```

A link to this same PDF at its permanent address tells a reader holding an old copy where the current one lives. Title it "Latest version", since a bare "PDF" reads as the file already open. The PDF leaves out a `downloads` entry that points to one of the project's exports by `id`, because such an entry has no web address until the MyST site is published.

## Options

| Option | Description |
|--------|-------------|
| `kind` | Label in the margin, overriding `subject` for this export |
| `linenumbers` | Number the lines of the main text, for review drafts |
| `remark` | Name of the paper's REMARK on econ-ark.org, such as `LiqConstr`, linked in the materials block |
| `binder_label` | Label over the `binder` link in the materials block, such as `Dashboard`. Defaults to "Run online" |
| `figure_placement` | Where figures and tables go, described under "Figure placement" below. `none`, the default, keeps each where it is written. `auto`, `top` or `bottom` floats them |

## Figure placement

By default a figure or table stays where it is written. When the rest of the page is too short for it, it moves whole to the next page and leaves white space behind. A table taller than a page breaks across pages, and starts on a new page when its caption, header and first rows would not fit at the foot of the current one.

Floating a figure only when the rest of the page is too short for it, as LaTeX's `[h]` does, is left out on purpose. A choice made from the space left on a page moves the text above the figure. In a test with eight figures, Typst's layout failed to settle and printed wrong figure numbers.

With `figure_placement: auto` in the export block, a figure or table that fits on a page floats to the top or bottom of a page, as LaTeX floats do, and the text fills the space it would have left. `top` and `bottom` choose one end. Page one takes floats only at the bottom, below the title. A table taller than a page, a panel inside a figure with several panels, and a `fullwidth` figure never float on their own.

The option sets the placement for every figure in the export. MyST's `figure` and `table` directives carry no placement of their own, so to place one figure differently, call `placeNextFigure` in a raw Typst block just before it, like LaTeX's `[t]` or `[b]` on a single figure:

```text
:::{raw:typst}
#placeNextFigure("top")
:::

:::{figure} results.png
:label: fig-results

Results.
:::
```

`placeNextFigure` takes `"top"`, `"bottom"`, `"auto"` or `"none"` and applies to the next figure or table only. The MyST site ignores the raw block and shows the figure as written.

## Wide figures

A figure with several panels in a row can take the width of the margin rail as well as the text column. Call `widenNextFigure` in a raw Typst block just before a MyST figure or table:

```text
:::{raw:typst}
#widenNextFigure()
:::

:::{figure} three-panels.png
:label: fig-panels
:width: 100%

Three panels in one row.
:::
```

The figure keeps its MyST label, so `@fig-panels` refers to it as usual, and its caption runs the full wide width. Give the image `:width: 100%`; a narrower image is centered in the wide space. A widened MyST table also fills the wide width. Its first column keeps the width of its labels. The other columns share the rest. A wide figure, a widened MyST table and a raw Typst table in `fullwidth` all start their captions at the same left edge. On US letter paper the widths are:

| Width | Points | Inches |
|-------|--------|--------|
| Text column | 361.8 | 5.03 |
| Wide, over the margin rail | 481.2 | 6.68 |

Size a plot to the printed width, for example `figsize=(6.68, h)` in matplotlib for a wide figure, to print its fonts at their set size. A wide figure stays where it is written unless `figure_placement` or `placeNextFigure` floats it. The running head, footer and page numbers keep the text column's width. On page one the rail holds the logo and notes, so widen a figure only from page two on. A wide figure that floats from page one is placed at the foot of the page at column width.

## Parts

| Part | In the PDF | On a MyST site with article-theme |
|------|------------|-----------------------------------|
| `abstract` | Run-in abstract under the title | Above the page |
| `summary` | Run-in "Non-technical summary" after the abstract | Above the page, as "Plain Language Summary" |
| `keypoints` | Three or four short bullet points, at most 80 words, in the margin under the logo. When the margin cannot hold them above its lower notes, they move under the abstract | Above the page, as "Key Points" |
| `acknowledgments` | First unnumbered section of the back matter (`acknowledgements` and `acknowledgement` also work) | Below the page |
| `data_availability` | Unnumbered section after the acknowledgments | Below the page |
| `declaration` | Unnumbered "Declaration of competing interest" after the data availability statement | In the text, where the block is written |
| `ai_declaration` | Unnumbered "Declaration of generative AI use", immediately before the references. Same part name as [elsarticle-myst](https://github.com/alanlujan91/elsarticle-myst) | In the text, where the block is written |
| `title_note` | Starred footnote on the title, placed before any author notes | In the text, where the block is written |

A part the template does not list, such as `dedication` or `epigraph`, stays in the text of the PDF as an unlabeled paragraph.

The back matter, these four sections and then the references, goes before the `<appendix>` marker, or at the end of the paper when there is no marker. MyST removes a part from the text of a PDF wherever it is written. The `parts:` key of the project frontmatter does not reach a PDF export.

## Where the values come from

When you export one page, its frontmatter replaces the project's field by field, and any field the page leaves out comes from the project. An export with `articles:` works differently. MyST ignores the frontmatter of every page, including the page that holds the export block, and takes each field from the project. A field written in the export block replaces the project's value for that export only. This holds for every field in the table above, `keywords`, `date`, `github` and `subject` included. Options such as `kind` go only in the export block.

Parts behave differently. In an `articles:` export MyST collects each part from every article, so the acknowledgments can live in the supplement and the declaration in the paper. When two articles give the same part, the first article's wins and MyST reports an error naming the one it ignored.

## Theorems and proofs

MyST `prf:` directives (`prf:theorem`, `prf:proposition`, `prf:lemma`, `prf:definition`, `prf:assumption`, `prf:proof` and the rest) are set in the flow of the text: a bold label and number, the optional title in parentheses, then the statement. Theorems, propositions, lemmas, corollaries, conjectures and claims are italic. Definitions, assumptions and remarks are upright. A proof ends with a square. Each kind is numbered separately, and `@label` gives "Proposition 1".

## Admonitions

A MyST admonition (`note`, `warning`, `tip` and the rest) stands against a rule in the palette, with its label in the same colour. MyST's own filled box is replaced. Its ten kinds take four colours. Econ-ARK blue carries `note` and `important`, and three logo curves carry the rest: green for `tip`, `hint` and `seealso`, orange for `attention`, `caution` and `warning`, pink for `danger` and `error`. A MyST site gets the same treatment from `theme.css`.

## Tables

Tables take captions above them, set their cells unjustified, unhyphenated and at 9pt, and draw a heavy rule above the header and below the last row, with a light rule under the header. A table MyST parses from markdown or from a raw LaTeX `tabular` gets one automatic width per column, which crowds a table with many columns into the text column. For such a table, write a native Typst table in a `:::{raw:typst}` block, where you can set column widths, and pass the figure to `fullwidth`:

```text
:::{raw:typst}
#fullwidth[#figure(
  table(
    columns: (8em, ..range(10).map(_ => 1fr)),
    stroke: none,
    [Case], ..range(10).map(i => [#i]),
  ),
  caption: [Results for all ten cases.],
) <tbl-wide>]
:::
```

MyST does not know labels defined inside raw Typst, and `@tbl-wide` in the text fails the build with "the document does not contain a bibliography". Refer to the table with the inline role {raw:typst}`@tbl-wide` instead.

`fullwidth` spans the margin rail and the text column and floats the figure to the top or bottom of the page. On page one the margin holds the logo and notes, so a figure anchored there floats to the bottom of the page at column width. A float can land above an in-flow table that the text introduces earlier.

`fullwidth(float: false, ...)` keeps the figure in the text flow, directly after the sentence that introduces it, as LaTeX `[h]` does. A figure that does not fit the rest of the page moves whole to the next page and leaves white space. Use it from page two on, because on page one the wide figure would run over the margin notes.

## Appendices

Open the appendices in the body with a marker, then write them as ordinary `#` sections:

```text
:::{raw:typst}
#metadata("appendix") <appendix>
:::

(app-proofs)=
# Proofs
```

After the marker, top-level sections read "Appendix A", "Appendix B" and their subsections "A.1", "A.2". Each top-level section is its own lettered appendix, so for a single appendix with numbered parts, write the parts as subsections of one top-level section. An unnumbered heading, such as a supplement title, leaves the lettering unchanged. The acknowledgments, declarations and references move to just before the marker, the usual order in economics papers. Add `#pagebreak()` inside the marker block to start the appendices on a new page. The marker also works inside an article of a multi-article export. There MyST turns each article's title into a top-level heading and moves its sections down a level, so the marker letters the next article's title rather than the sections that follow it. List each article with `level: 0` and `title: null` to keep its sections at their own level, so that "Appendix A" goes to the first `#` section after the marker.

To keep an appendix in its own file, pull it in after the marker with the `include` directive and list the pages in the project `toc`. Without a `toc` the included file is also a page of its own, and MyST warns about duplicate identifiers.

`@app-proofs` prints the section title. To print "Appendix A", use {raw:typst}`@app-proofs`, which appears in the PDF only. Equations, figures and tables keep one numbering sequence through the appendices, because MyST writes their reference numbers into the text before Typst lays out the page.

The template defines no `appendix` part, so write appendices in the body.

## Several articles in one PDF

An export with `articles:` renders each article as a separate Typst file, which cannot see the names the template defines. In every article of such an export, MyST tables fall back to its default style (the template still removes their vertical rules and sets their size), `prf:` blocks float to the top of the page in tinted boxes, and `fullwidth` is undefined. To keep the template's styling, write one article that pulls the others in with the `include` directive:

````text
```{include} supplement.md
```
````

If you keep `articles:`, MyST restarts figure and table numbers in each article while the PDF numbers them continuously, so references and captions disagree. Set `numbering: {figure: {continue: true}, table: {continue: true}}` in the frontmatter of every article after the first.

Every article of an `articles:` export, the first included, is a separate file that sees an empty `tableStyle`. Its tables come out with a rule between every row and no bold header, since only the booktabs rules and the header depend on that style. To restore them, start each article that has a table with a block that rebinds MyST's table function for the rest of the file:

```text
:::{raw:typst}
#import "econark.typ": arkTablex
#let tablex = arkTablex.with(tablex)
:::
```

For 7pt tables, also import `smallTableStyle` and add `#let tableStyle = smallTableStyle`. Rebinding `tableStyle` to `arkTableStyle` alone, the earlier recipe, sets the header and cells but leaves the table without its bottom rule.

The running header of an `articles:` export takes the `short_title` of the project. To use a different one, set `short_title` in the export block.

## The site

`theme.css` gives a MyST site the look of the PDF: the same palette and typefaces, section headings in Econ-ARK blue, captions and tables in the sans, code on the pale blue the PDF uses, and the four logo curves as the rule that closes the front matter. Point a site at it under either theme:

```yaml
site:
  template: article-theme
  options:
    logo: logo.png
    logo_dark: logo-dark.png
    logo_text: Econ-ARK
    logo_url: https://econ-ark.org
    logo_alt: Econ-ARK
    favicon: favicon.png
    style: theme.css
```

`logo.png` is the wide website lockup, and `logo-dark.png` is the same lockup with a white wordmark, which the themes swap in at night. `favicon.png` is the four curves alone on the brand blue, because the wordmark is illegible at 16 pixels. Paths are relative to the `myst.yml` that holds them. This repository keeps its own at the root, beside the template and the stylesheet.

article-theme draws its downloads panel from the project, not from the paper whose page it is showing, so a paper that lists `downloads` in its own frontmatter still reaches the site with no link to its PDF. Name them under `project:` as well, with `file:` rather than `url:`, and the site copies each one in and links it:

```yaml
project:
  downloads:
    - file: examples/exports/paper.pdf
      title: Latest version
    - file: examples/paper.bib
      title: BibTeX
```

The paper's own `downloads` still feed the PDF's materials block, where every entry has to be a web address. The two lists coexist. The paper carries absolute URLs for print. The project carries files for the site.

### Equations on the site

MyST renders math with KaTeX, which paints glyphs from its own Computer Modern faces at positions it has already computed. No stylesheet can put another typeface under that. The equations on a MyST site therefore arrive in a serif whatever the prose around them is set in. On a paper set in Fira that mismatch is hard to miss.

`plugins/fira-math.mjs` re-renders each equation with [Temml](https://temml.org), which is KaTeX's parser with the HTML half removed and the MathML half repaired. What it emits is MathML Core, which a browser lays out itself from whatever font it is given, so the equations can take Fira Math along with everything else. Name it under the project and it runs:

```yaml
project:
  plugins:
    - plugins/fira-math.mjs
```

Another repository does not need any of this checked out. `plugins/fira-math.bundle.mjs` is the same transform with Temml and its other dependency compiled in, so it loads from a URL with nothing installed:

```yaml
project:
  plugins:
    - https://raw.githubusercontent.com/econ-ark/econ-ark-myst/main/plugins/fira-math.bundle.mjs
```

The bundle exists because MyST writes a fetched plugin into `_build/cache/`, where a bare `import temml` has no `node_modules` to resolve against. The build then reports `ERR_MODULE_NOT_FOUND` and every equation reverts to KaTeX. `npm run build:plugin` regenerates the bundle from the source file. The versions it inlines are pinned exactly, which is what lets a check rebuild the bundle and compare bytes. A bundle left behind by an edit to the source fails the run.

Three things have to be in place, and `scripts/fonts.sh webfonts` puts two of them there:

- `npm install`, for Temml itself. Building the site *here* needs it. A repository that loads the bundle skips this step.
- `fonts/FiraMath-Regular.woff2`, which unlike the text faces is served whole. Its OpenType MATH table is what stretches a bracket around a sum. A subsetter asked for a range of characters is under no obligation to carry that table through.
- `fonts/temml.css`, which `theme.css` imports first. Chromium implements none of the older MathML presentation attributes, so Temml writes CSS classes for what it cannot express and supplies the rules that read them. Without the import an `\underline` loses its rule and a `\widehat` its hat.

An equation Temml cannot parse keeps the KaTeX it already had, so the failure is one equation in the wrong typeface rather than a broken page. Macros under `project.math` are passed through. A page-level `math:` block is not visible to a transform and falls back the same way.

Two things still differ from the PDF. A binary operator inside a subscript, as in `m_{t+1}`, keeps its full spacing, because MathML Core does not tighten operator spacing at script level the way TeX does. The other is `\widehat` over a single symbol, which overstretches, where `\hat` is the right markup and sets correctly.

### The landing page

`landing/` is a second MyST project holding the page at the root of the published site, with the two theme demos under `/article` and `/book`. It takes its stylesheet, logos, fonts and math plugin from one level up, so the whole site is dressed from the same `theme.css`.

It runs on book-theme because that is the only theme carrying the landing-page block renderers, which come from `@myst-theme/landing-pages`. Blocks are plain MyST, with no plugin or directive:

````markdown
+++ { "kind": "split-image" }

An eyebrow line

## A heading

![alt text](../thumbnail.png)

Body text.
````

The kinds are `centered`, `split-image`, `justified` and `logo-cloud`. Everything up to the first heading becomes the eyebrow and the title. The rest is the body, where `split-image` needs an image and `logo-cloud` needs a grid. Lacking one, the theme prints an "Invalid block" panel into the page and still exits 0, which is what `check_landing` watches for. `theme.css` puts the blocks in the house palette, since they arrive carrying Tailwind colours of their own.

Two things to know when linking between the three sites. MyST joins `BASE_URL` to a link by concatenation, so write `/article/` rather than `article/` or `./article/`. The `nav` list rejects a root-absolute path outright, which leaves cross-site links to the page itself.

### Using this template from another repository

The PDF side works over the network. Point an export at this repository's URL and MyST clones it:

```yaml
exports:
  - format: typst
    template: https://github.com/econ-ark/econ-ark-myst.git
```

The site side does need copying. Every site option that names a file, `style`, `logo`, `logo_dark` and `favicon`, is resolved against the local directory, and a URL there fails with `ENOENT`. A site that wants this look copies the files it needs into its own repository:

| Copy | To get |
|------|--------|
| `theme.css` | The whole look: palette, typefaces, tables, admonitions, the four-curve rule, and the Econ-ARK mark over the title. The mark is embedded in the file, so nothing else has to come with it |
| `logo.png`, `logo-dark.png` | The lockup in the site header, day and night |
| `favicon.png` | The browser tab |
| `banner.svg` | The default banner behind an article-theme title card |

`theme.css` alone is enough for the typography and the palette. The other four are the site chrome. To refresh them later:

```sh
for f in theme.css logo.png logo-dark.png favicon.png banner.svg; do
  curl -sLO "https://raw.githubusercontent.com/econ-ark/econ-ark-myst/main/$f"
done
```

`banner.svg` is a default banner for a paper that wants one: the brand blue behind four consumption functions that rise towards their asymptotes, in the colours and the order of the logo curves, each carrying the kink the logo draws. article-theme lays its title card over the middle of a banner. The curves run out below the card and off the right edge, where the card leaves the field open. Set it for every page under `project:`, or for one page in its own frontmatter:

```yaml
project:
  banner: banner.svg
```

`logo.png` is the mark the PDF prints in its margin, and book-theme shows the same file in the site's navigation. article-theme leaves that place empty beside a paper. The stylesheet carries its own copy of the mark and sets it over the title. The wordmark is black. At night both marks rest on a white plate.

The stylesheet serves the fonts itself. `fonts/` holds Fira Sans and Fira Mono subset to Latin as woff2, about 125KB for the seven faces, and `theme.css` declares an `@font-face` for each. A site copies them over by naming the directory under the project's `static_files`, which is what this repository's own `myst.yml` does:

```yaml
project:
  static_files:
    - fonts
```

A site that skips them still reads correctly, since the stack falls back to the system sans, but it will not be set in the faces the PDF uses.

The site's navigation, sidebar and search keep the theme's own typeface, which the theme sizes its columns for.

## Known limitations

| Symptom | Cause | Workaround |
|---------|-------|------------|
| `[Section %s](#label)` prints "Section ??" | MyST resolves `%s` to nothing for headings in a single-article export, even with `numbering: headings: true` ([mystmd#3035](https://github.com/jupyter-book/mystmd/pull/3035)) | Refer to sections by name with `@label` or `[](#label)`, which print the section title |
| A table that breaks across pages has no rule at the foot of each page before the last | The table package MyST uses draws rules only at fixed rows | The header, with its rules, repeats on each page, and the last page ends with the bottom rule |
| The same sources give a PDF whose lines break differently on another machine | The requested font weight falls midway between the two nearest installed files, and Typst breaks that tie by the order it found them in, which is the filesystem's. A family with Medium and Bold but no SemiBold puts a request for semibold exactly between them | Ask for a weight a file actually carries, as the template now does with 500. `pdffonts` on both PDFs names the file each one embedded |
| A paper built against this template's URL shows none of a change that is on main | MyST keeps its clone of the template under `_build/templates/typst` and reuses it without re-fetching. The build takes the copy downloaded first, and its export comes out identical to the last one, which reads as a build that did nothing. `--force` rebuilds the paper without refreshing the clone | `myst clean --templates -y`, then build. `pdffonts` on the export names the faces, which tells you which version of the template produced it |
| A bibliography title reads "Stock Prices, News, In Markets" | Typst's title casing capitalizes a small word after a comma. The template lowercases And, Or, Nor, But, Of, The and For there, and leaves In, To and An, which can be first names | Write the word in braces in the `.bib` file, as in `{in}` |
| A long table without a caption prints `state("tablex_tablex_header_pages__...") did not converge` | The table package MyST uses repeats the header on each page and needs more layout passes than Typst allows | Ignore the warning, because the table still breaks across pages with its header repeated |
| A document using a macro from `project.math` fails its Typst export, with `file not found (searched at _build/temp/*/myst-imports.typ)` | MyST writes `#import "myst-imports.typ"` into the generated Typst for any document that uses a frontmatter macro. That file never reaches the export directory alongside this template. Failure is per document: a project stays green until one of them uses a macro | Write the expansion out in the document. The site takes either form, since `plugins/fira-math.mjs` reads `project.math` itself |
| A short table or figure leaves white space at the foot of a page | A table or figure that fits on one page moves whole to the next page. One taller than a page breaks across pages | Move the paragraph that introduces it, or split the table |

## Example

`examples/paper.md` exercises every field above, `examples/minimal.md` uses as few as possible, and `examples/tall-table.md` holds a table taller than a page. The project's `myst.yml` is at the root of the repository, beside the template it exports with. Run the build there. Its output, `examples/exports/paper.pdf`, is tracked. The PDF carries no creation timestamp, so rebuilding an unchanged example on the same machine leaves it byte-identical. Across machines the checks compare the rendered pages, since a font subset tag and an XMP instance id can differ between two builds that draw the same thing.

```bash
myst build --typst
```

![](thumbnail.png)

## Checks

`scripts/check-examples.sh` rebuilds the examples and reads what they produced. It fails when a PDF was not written, when a literal `??` marks an unresolved reference, when text from a template feature is missing, when the PDF carries a creation timestamp, when the tall table stays on one page and runs off its foot, when a caption is orphaned from its table, when the tracked PDF's text or rendered pages no longer match what the sources produce, when a font weight resolved to a file the template did not ask for, when more than one installed file offers a weight the template uses, when either theme's site is missing the stylesheet, the banner, a logo, the favicon, the paper as a download, or the classes the stylesheet reaches the paper through, when an admonition's rule is off the palette, and when Typst warns about a file of this template rather than an imported package. `myst build` exits 0 in all of these cases. `--self-test` seeds each defect and confirms the check catches it. CI runs both on every push with the same Typst, mystmd and fonts used for the tracked PDF.

## License

MIT; adapted from [curvenote-templates/openrxivlabs](https://github.com/curvenote-templates/openrxivlabs). See [LICENSE](LICENSE).
