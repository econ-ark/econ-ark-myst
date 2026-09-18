// Re-renders each equation as MathML Core so theme.css can set it in Fira Math.
// Why KaTeX's own MathML will not do, and what a reader has to install: README, "Equations on
// the site". The ordering this depends on is asserted at the transform below.

import fs from 'node:fs';
import path from 'node:path';
import yaml from 'js-yaml';
import temml from 'temml';

// MyST leaves no trace of frontmatter macros on the node, so both levels are read from their files.
// A config this cannot read yields the same empty set as a project with no macros, and says so: an
// equation missing its macro comes back in KaTeX and looks like a dead plugin.
const macroCache = new Map();

// A macro is written either as a string or as an object carrying it under `macro`
const asMacros = (math) =>
  Object.fromEntries(
    Object.entries(math ?? {}).map(([key, value]) => [key, typeof value === 'string' ? value : value?.macro]),
  );

// The config is found by walking up from the page, never from the process's directory: a build
// launched anywhere else would read no project macros at all and say nothing. Cached per config,
// since one process can build more than one project, as the landing page is.
function projectMacros(file) {
  let dir = path.dirname(path.resolve(file?.path ?? '.'));
  let config;
  for (;;) {
    if (fs.existsSync(path.join(dir, 'myst.yml'))) {
      config = path.join(dir, 'myst.yml');
      break;
    }
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  if (config === undefined) {
    file.message('fira-math: no myst.yml above this page, so no project macros', undefined, 'fira-math');
    return {};
  }
  if (macroCache.has(config)) return macroCache.get(config);
  let macros = {};
  try {
    macros = asMacros(yaml.load(fs.readFileSync(config, 'utf8'))?.project?.math);
  } catch (error) {
    file.message(`fira-math: no macros read from ${config} (${error.message})`, undefined, 'fira-math');
  }
  macroCache.set(config, macros);
  return macros;
}

// A page may define its own macros, which MyST layers over the project's, and those leave no trace
// on the node either. Read them from the page source, cached per file, so a paper that keeps its
// notation local to itself gets the same treatment as one that declares it project-wide.
const pageCache = new Map();

function pageMacros(file) {
  const source = file?.path;
  if (!source) return {};
  if (pageCache.has(source)) return pageCache.get(source);
  let macros = {};
  try {
    const frontmatter = /^---\r?\n([\s\S]*?)\r?\n---/.exec(fs.readFileSync(source, 'utf8'));
    macros = asMacros(yaml.load(frontmatter?.[1] ?? '')?.math);
  } catch (error) {
    file.message(`fira-math: no macros read from ${source} (${error.message})`, undefined, 'fira-math');
  }
  pageCache.set(source, macros);
  return macros;
}

const firaMathTransform = {
  name: 'fira-math',
  doc: 'Re-renders each equation as MathML Core so the site can set it in Fira Math',
  // myst-cli applies a document-stage transform straight after its own math transform, so node.html
  // already holds finished KaTeX and node.value the TeX behind it. An equation Temml cannot parse
  // keeps its KaTeX, which costs that one equation its typeface and nothing else.
  stage: 'document',
  plugin: (_opts, utils) => (tree, file) => {
    const macros = { ...projectMacros(file), ...pageMacros(file) };
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
