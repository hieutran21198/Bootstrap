// @ts-check
import path from 'node:path';
import {visit} from 'unist-util-visit';

/**
 * Build-time remark plugin that rewrites repo-relative Markdown links so they
 * resolve on the published site.
 *
 * The source docs (docs/, services/portal/docs/) are authored with links
 * relative to their real location in the repo. Those links are correct in-repo
 * and on GitHub, but Docusaurus renders the docs from apps/workspace-docs and
 * resolves links against site ROUTES, not the filesystem. So a link like
 * `../../packages/nix/AGENTS.md` becomes a dead route.
 *
 * This plugin resolves every relative link against the source file's real path,
 * then:
 *   - in-tree  -> rewrites to the matching site route (/docs/... or /portal/...)
 *   - out-of-tree -> rewrites to an absolute github.com blob/tree URL
 *
 * Source docs are never modified; the transform happens only in the build AST.
 *
 * @typedef {object} Options
 * @property {string} repoRoot Absolute path to the repository root.
 * @property {string} githubBaseUrl e.g. https://github.com/owner/repo
 * @property {string} [branch] Default branch for blob/tree URLs (default: main).
 * @property {ReadonlyArray<{dir: string, route: string, indexRoute?: string}>} docRoots
 *   Doc trees that ARE rendered, mapped to their site route base. `dir` is an
 *   absolute path; `route` is the URL base (e.g. "/docs"). `indexRoute` is the
 *   landing page used when a link points at the tree root itself but the tree
 *   has no index page (e.g. "/docs/AGENTS"); falls back to `route`.
 */

/** Links we must never touch. */
const SKIP_PREFIXES = ['http://', 'https://', '//', 'mailto:', 'tel:', '#'];

/**
 * @param {string} url
 * @returns {boolean}
 */
function isSkippable(url) {
  if (!url) return true;
  if (SKIP_PREFIXES.some((p) => url.startsWith(p))) return true;
  // Template placeholders like `NNNN-<title>.md` are not real links.
  if (url.includes('<') || url.includes('>')) return true;
  // Already an absolute site route.
  if (url.startsWith('/')) return true;
  return false;
}

/**
 * Split a URL into its path portion and the trailing #anchor / ?query, so we
 * can rewrite the path while preserving the suffix.
 *
 * @param {string} url
 * @returns {{pathname: string, suffix: string}}
 */
function splitSuffix(url) {
  const hashIdx = url.search(/[#?]/);
  if (hashIdx === -1) return {pathname: url, suffix: ''};
  return {pathname: url.slice(0, hashIdx), suffix: url.slice(hashIdx)};
}

/**
 * Convert an absolute repo path that lives inside a rendered doc tree into its
 * site route. Strips `.md`/`.mdx` and collapses `/README` to the dir route.
 *
 * @param {string} absTarget Absolute path of the link target.
 * @param {{dir: string, route: string, indexRoute?: string}} docRoot
 * @returns {string} Site route (e.g. "/docs/adrs").
 */
function toSiteRoute(absTarget, docRoot) {
  let rel = path.relative(docRoot.dir, absTarget);
  rel = rel.replace(/\.mdx?$/i, '');
  rel = rel.replace(/(^|\/)README$/i, '');
  rel = rel.replace(/\/$/, '');
  // A link to the tree root itself: use the landing page if the tree has no
  // index route, otherwise the route base.
  if (!rel) return docRoot.indexRoute ?? docRoot.route;
  return `${docRoot.route}/${rel}`;
}

/**
 * @param {Options} options
 */
export default function remarkRepoLinks(options) {
  const {repoRoot, githubBaseUrl, branch = 'main', docRoots} = options;
  const ghBlob = `${githubBaseUrl}/blob/${branch}`;
  const ghTree = `${githubBaseUrl}/tree/${branch}`;

  return (/** @type {import('mdast').Root} */ tree, /** @type {import('vfile').VFile} */ file) => {
    const sourceFilePath = file.path;
    if (!sourceFilePath) return;
    const sourceDir = path.dirname(sourceFilePath);

    visit(tree, 'link', (node) => {
      const original = node.url;
      if (isSkippable(original)) return;

      const {pathname, suffix} = splitSuffix(original);
      if (!pathname) return; // pure anchor like "#section"

      const absTarget = path.resolve(sourceDir, pathname);

      // 1. In-tree? Rewrite to a site route.
      for (const docRoot of docRoots) {
        if (absTarget === docRoot.dir || absTarget.startsWith(`${docRoot.dir}${path.sep}`)) {
          node.url = `${toSiteRoute(absTarget, docRoot)}${suffix}`;
          return;
        }
      }

      // 2. Inside the repo but outside the rendered trees? Point at GitHub.
      if (absTarget === repoRoot || absTarget.startsWith(`${repoRoot}${path.sep}`)) {
        const relFromRoot = path.relative(repoRoot, absTarget);
        const hasExt = /\.[a-z0-9]+$/i.test(pathname);
        const base = hasExt ? ghBlob : ghTree;
        node.url = `${base}/${relFromRoot}${suffix}`;
        return;
      }

      // 3. Anything else (escapes the repo entirely) is left untouched.
    });
  };
}
