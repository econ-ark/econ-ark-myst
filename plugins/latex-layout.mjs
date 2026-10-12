// A `latex` directive: a raw LaTeX block whose layout commands reach the LaTeX export and stay off
// the page. MyST's own ```{raw} latex``` block writes its body verbatim into a LaTeX export and also
// parses it for the site and the Typst PDF, and that parser stops on commands that only set
// spacing or alignment (`\setlength`, `\addlinespace`, `\raggedright`), one error per use. After
// an `\addlinespace` it also drops the column span of the `\multicolumn` that follows, so a
// table's section row shrinks to one cell. README, "Raw LaTeX tables", carries the rest.

// Each rewrite applies to the parsed copy alone; the LaTeX export keeps the body as written. A
// command not listed here still reaches the parser, so a new one still raises its own error.
const LAYOUT_REWRITES = [
  // Spacing that only the PDF can use
  [/\\setlength\s*\{\\[A-Za-z]+\}\s*\{[^{}]*\}/g, ''],
  [/\\addlinespace(\s*\[[^\]]*\])?/g, ''],
  // Ragged cells, written `{\raggedright text\par}` because a p-column resets the alignment
  [/\\raggedright\b\s*/g, ''],
  [/\\par\b/g, ''],
  // Font switches inside a group, kept as the commands the parser reads
  [/\{\\itshape\s+([^{}]*)\}/g, '{\\textit{$1}}'],
  [/\{\\bfseries\s+([^{}]*)\}/g, '{\\textbf{$1}}'],
];

export const parsedCopy = (body) =>
  LAYOUT_REWRITES.reduce((text, [pattern, replacement]) => text.replace(pattern, replacement), body);

const latexDirective = {
  name: 'latex',
  doc: 'Raw LaTeX written verbatim into LaTeX exports and parsed, without its layout commands, for the site and Typst',
  body: { type: String, doc: 'LaTeX source', required: true },
  run(data) {
    const body = data.body ?? '';
    // The node `{raw} latex` builds, with `value`, the text the parser reads, swapped for the
    // copy; myst-to-tex writes `tex` whenever it is set and myst-to-typst renders the children.
    return [{ type: 'raw', lang: 'latex', tex: `\n${body}\n`, value: parsedCopy(body) }];
  },
};

export default {
  name: 'LaTeX layout',
  directives: [latexDirective],
};
