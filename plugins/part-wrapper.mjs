// Wraps a part the site theme gives no slot for in a class of its own, so theme.css can label it.
// A selector reaching such a part by position would sooner or later label a paper that has none.
// README, "The parts the site has no slot for", carries the rest.

// Parts to wrap. theme.css supplies the heading text, as template.typ does for the PDF.
const WRAPPED_PARTS = ['declaration'];

const partClass = (part) => `ark-part-${part.replaceAll('_', '-')}`;

const partWrapperTransform = {
  name: 'part-wrapper',
  doc: 'Wraps each part the theme gives no backmatter slot in a class the site can label',
  stage: 'document',
  plugin: (_opts, utils) => (tree) => {
    for (const node of utils.selectAll('block', tree)) {
      const part = node.data?.part;
      if (!WRAPPED_PARTS.includes(part)) continue;
      const className = partClass(part);
      const [first] = node.children ?? [];
      // A rerun in a watching dev server sees the tree it already wrapped
      if (first?.type === 'div' && first.class === className) continue;
      // A heading node here would reach the PDF as well, where myst-to-typst can only write it
      // numbered, beside the unnumbered heading template.typ already writes. Typst renders a div
      // as its children alone, so the PDF is untouched.
      node.children = [{ type: 'div', class: className, children: node.children ?? [] }];
    }
  },
};

export default {
  name: 'Part wrapper',
  transforms: [partWrapperTransform],
};
