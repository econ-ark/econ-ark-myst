# Every colour, class and option a stylesheet can override

Upstream leaves this undocumented. The tables here are counted from the
[myst-theme](https://github.com/jupyter-book/myst-theme) sources, and `scripts/theme-surface.sh`
regenerates them against a checkout of it:

```bash
git clone https://github.com/jupyter-book/myst-theme /tmp/myst-theme
scripts/theme-surface.sh /tmp/myst-theme
```

Three surfaces, in the order to reach for them.

## 1. CSS custom properties, the supported override

`styles/theme-colors.css` declares 55 `--myst-color-*` properties, with a full `.dark` block, and
`styles/index.js` maps each to a Tailwind name the components use (`bg-myst-primary`,
`border-myst-info`, `text-myst-text`). Setting one recolours everything that reads it, including
chrome no selector here names: search, navigation, hover, active, focus.

They arrived in jupyter-book/myst-theme#843, "Expose colors as css custom props to allow override",
on 2026-06-18.

A site got them on 2026-09-21, when mystmd 1.10.1 began fetching the 1.4.0 themes. Both
article-theme and book-theme declare all 55 there, and their backgrounds, borders and text now read
those properties. Until that day the same fetch returned 1.3.1, which wrote Tailwind classes
throughout and carried the version string of the source that had the feature. A build fetches whatever the registry serves, so this moved under a tree nobody had
touched. Read the built artifact rather than the version string, which disagreed with it
throughout 1.3.1.

Each theme is fetched into the build that uses it. The two counts therefore come from two trees, the
root build holding article-theme alone:

```bash
rg -o -- '--myst-color-[a-z-]+:' _build/templates/site/myst/*/public/build/_assets/app-*.css |
  sort -u | wc -l
rg -o -- '--myst-color-[a-z-]+:' landing/_build/templates/site/myst/*/public/build/_assets/app-*.css |
  sort -u | wc -l
```

While that count was zero, `theme.css` overrode the theme's own utility classes, `bg-white` and
`text-blue-600` among them, which 1.4.0 no longer writes. It now sets 18 of the tokens instead, and
`check_token_coverage` fails when a page paints through one it leaves out. `check_tokens_defined`
holds the other end. A token the served stylesheet reads and nothing declares falls back to the
theme's own colour, which is what the button fill would have done.

## 2. Class hooks

The components emit 397 `myst-*` classes. They are stable enough to style and are how everything in
`theme.css` attaches. Counts by family, and how many this theme brands:

Every row below is what the script prints. Regenerate it rather than edit it by hand. Two rows are
artifacts of splitting on the second segment, `to` and `ext`, where a string like `myst-to-html`
names an export format.

| Family | Emitted | Branded here | Notes |
| --- | --- | --- | --- |
| `fm` | 93 | 4 | Front matter: title, authors, affiliations, dates, DOI, downloads |
| `jp` | 46 | 5 | Jupyter: outputs, toolbar, launch control |
| `landing` | 35 | 6 | Landing blocks and their headings |
| `to` | 17 | 2 | Export format names from the prefix split |
| `primary` | 16 | 4 | Primary sidebar, including its footer part |
| `search` | 11 | 1 | Search box and results |
| `admonition` | 8 | 13 | We also set the eight kind classes, built by interpolation |
| `article` | 7 | 3 | Article header and background |
| `outline` | 7 | 4 | The contents panel |
| `tab` | 7 | 3 | Tabbed content |
| `top` | 7 | 1 | Top navigation |
| `ext` | 6 | 0 | Prefix artifact, as with `to` |
| `footer` | 6 | 3 | Previous and next page links |
| `footnote` | 6 | 2 | Footnote anchors |
| `proof` | 6 | 4 | Theorem environments |
| `bibliography` | 5 | 3 | Reference list |
| `card` | 5 | 3 | Cards |
| `code` | 5 | 2 | Code blocks |
| `dropdown` | 5 | 2 | Dropdown directives |
| `exercise` | 5 | 3 | Exercise directives |
| `abstract` | 4 | 2 | Abstract block |
| `accent` | 4 | 0 | Accent utilities |
| `action` | 4 | 0 | Landing call-to-action buttons |
| `aside` | 4 | 2 | Margin notes |
| `backmatter` | 4 | 1 | Back matter sections |
| `bg` | 4 | 0 | Background utilities |
| `footnotes` | 4 | 2 | Footnote list |
| `keywords` | 4 | 3 | Keyword list |
| `theme` | 4 | 1 | Theme toggle |
| `toc` | 4 | 1 | Table of contents |

Unbranded, each a small closed set a few rules would cover: `myst-tab-set`,
`myst-footer-link-prev`, `myst-footer-link-next`.

Never qualify one of these by tag. `admonitions.tsx` and `proof.tsx` each return `details` when the
directive carries `:class: dropdown`, `aside` otherwise. `aside.myst-admonition` therefore brands
nine kinds and misses the tenth. Use `:is(aside, details)`, which `scripts/check-examples.sh`
enforces.

## 3. Template options and parts

Declared in each theme's `template.yml`. The two themes differ.

| | book-theme | article-theme |
| --- | --- | --- |
| Options | 20 | 18 |
| `hide_title_block`, `hide_search` | yes | no |
| Parts | `footer`, `primary_sidebar_footer`, `navbar_end` | none |

A part replaces a region wholesale. For some regions it is the only route in. book-theme
renders its own "Made with MyST" lockup whenever a site supplies no `primary_sidebar_footer`. No
option hides it. `myst.yml` here supplies that part from `brand/powered-by.md`, the Econ-ARK credit the five
`.myst-primary-sidebar-footer` rules in `theme.css` are written for.

Options shared by both: `hide_toc`, `hide_footer_links`, `hide_outline`, `hide_authors`,
`outline_maxdepth`, `twitter`, `favicon`, `logo`, `logo_dark`, `logo_text`, `logo_url`, `logo_alt`,
`analytics_google`, `analytics_plausible`, `numbered_references`, `folders`, `internal_domains`,
`style`.
