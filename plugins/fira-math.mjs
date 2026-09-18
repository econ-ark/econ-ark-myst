// Re-renders each equation as MathML Core so theme.css can set it in Fira Math.
// Why KaTeX's own MathML will not do, and what a reader has to install: README, "Equations on
// the site". The ordering this depends on is asserted at the transform below.

import fs from 'node:fs';
import path from 'node:path';
import yaml from 'js-yaml';
import temml from 'temml';

// MyST leaves no trace of frontmatter macros on the node, so read the project's own, once for the
// whole build. A config this cannot read yields the same empty set as a project with no macros,
// and says so: an equation missing its macro comes back in KaTeX and looks like a dead plugin.
let macroCache;

function projectMacros(file) {
  if (macroCache) return macroCache;
  const config = path.resolve('myst.yml');
  try {
    const math = yaml.load(fs.readFileSync(config, 'utf8'))?.project?.math ?? {};
    macroCache = Object.fromEntries(
      Object.entries(math).map(([key, value]) => [key, typeof value === 'string' ? value : value?.macro]),
    );
  } catch (error) {
    file.message(`fira-math: no macros read from ${config} (${error.message})`, undefined, 'fira-math');
    macroCache = {};
  }
  return macroCache;
}

const firaMathTransform = {
  name: 'fira-math',
  doc: 'Re-renders each equation as MathML Core so the site can set it in Fira Math',
  // myst-cli applies a document-stage transform straight after its own math transform, so node.html
  // already holds finished KaTeX and node.value the TeX behind it. An equation Temml cannot parse
  // keeps its KaTeX, which costs that one equation its typeface and nothing else.
  stage: 'document',
  plugin: (_opts, utils) => (tree, file) => {
    const macros = projectMacros(file);
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
