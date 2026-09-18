// Sets the site's equations in Fira Math, so a reader sees the same face between dollars that the
// PDF uses and that the prose around it is set in.
//
// MyST renders math with KaTeX, which paints glyphs from its own Computer Modern faces at fixed
// positions. A typeface cannot be swapped underneath that: the positions are baked in. The MathML
// KaTeX also emits is the part a browser lays out itself, and therefore the part that can take any
// font with an OpenType MATH table. That MathML is not usable as it stands, because KaTeX writes
// mathvariant="double-struck" for \mathbb, and MathML Core dropped every mathvariant value except
// normal, so Chromium has never rendered it: the E of an expectation arrives as a plain upright E.
//
// Temml is KaTeX's parser with the HTML half removed and the MathML half fixed. It writes the
// Mathematical Alphanumeric Symbols directly, so \mathbb{E} is U+1D53C and survives.
//
// This runs at stage 'document', which myst-cli applies immediately after its own math transform,
// so node.html holds finished KaTeX output and node.value the TeX that produced it. An equation
// Temml cannot parse keeps the KaTeX it already had, which costs that one equation its typeface
// and nothing else.

import fs from 'node:fs';
import path from 'node:path';
import yaml from 'js-yaml';
import temml from 'temml';

// MyST hands frontmatter macros to KaTeX itself and leaves no trace of them on the node, so read
// the project's own. A page-level `math:` block is not visible here and falls back to KaTeX.
function projectMacros() {
  try {
    const config = yaml.load(fs.readFileSync(path.resolve('myst.yml'), 'utf8'));
    const math = config?.project?.math ?? {};
    return Object.fromEntries(
      Object.entries(math).map(([key, value]) => [key, typeof value === 'string' ? value : value?.macro]),
    );
  } catch {
    return {};
  }
}

const firaMathTransform = {
  name: 'fira-math',
  doc: 'Re-renders each equation as MathML Core so the site can set it in Fira Math',
  stage: 'document',
  plugin: (_opts, utils) => (tree, file) => {
    const macros = projectMacros();
    let replaced = 0;
    let kept = 0;
    for (const node of utils.selectAll('math,inlineMath', tree)) {
      if (!node.html || !node.value) continue;
      try {
        node.html = temml.renderToString(node.value, {
          displayMode: node.type === 'math',
          macros: { ...macros },
          throwOnError: true,
        });
        replaced += 1;
      } catch {
        kept += 1;
      }
    }
    if (kept > 0) {
      file.message(
        `fira-math: ${replaced} equations set in Fira Math, ${kept} left in KaTeX's own fonts`,
        undefined,
        'fira-math',
      );
    }
  },
};

export default {
  name: 'Fira Math',
  transforms: [firaMathTransform],
};
