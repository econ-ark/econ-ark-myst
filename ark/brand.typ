// The Econ-ARK palette, the faces and the venue mark. Changing anything here changes how the
// brand looks; where things sit on the page is ark/layout.typ.
// image() resolves against the file holding the call, so the logo path climbs out of ark/.
#let venueUrl = "https://econ-ark.org";
#let venueLogo = image("../brand/logo.png");
// Econ-ARK brand palette. The blue is the one econ-ark.org sets throughout its own stylesheet
#let arkBlue = rgb("#1f476b");
#let arkGrey = rgb("#676470");
// The grey a rule takes when it marks without speaking: the footer, a quotation. theme.css holds
// the same value under --ark-rule, where it also draws the table rules
#let arkRule = arkGrey.lighten(40%);
// The surface behind a listing, authored in theme.css as --ark-tint. This was arkBlue.lighten(95%),
// a paler blue, so one block had two colours across the two media. The four code roles clear 4.5
// to 1 against this darker value, which is the one that binds them.
#let arkTint = rgb("#e8edf2");
// Unscoped code, authored in theme.css as --ark-code-ink. brand/code.tmTheme names it too, but
// Typst gives a theme's foreground only to scoped tokens and leaves the rest on the document's
// fill, so the listing has to be set in it here.
#let arkCodeInk = rgb("#48464e");
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
