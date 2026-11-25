// A page's find (lib/web_find.dart, ADR 0143): the body of an async
// function of `op` ("find", "show" or "clear"), `query`, `at`, `hit`, `now`,
// `edge` and `cover` (the bar's height), which answers the matches' count
// and the current one's number. Runner/PageFind.swift runs it in a content
// world of Nushi's own; PageFindTests runs it on test pages.
const S = (window.__nushiFind ??= { ranges: [], sheet: null, style: null });
const reg = (window.CSS && CSS.highlights && window.Highlight) ? CSS.highlights : null;
const color = (c) => (typeof c === 'string' && /^rgba\([0-9., ]+\)$/.test(c)) ? c : 'transparent';
const top = typeof cover === 'number' ? cover : 0;
function clear() {
  // Emptied first: once the page has read the registry WebKit keeps its
  // own view of it, which a delete from this world doesn't reach.
  for (const r of S.ranges) r.collapse(true);
  if (reg) { reg.delete('nushi-find'); reg.delete('nushi-find-now'); }
  if (S.sheet) {
    document.adoptedStyleSheets = document.adoptedStyleSheets.filter((s) => s !== S.sheet);
    S.sheet = null;
  }
  if (S.style) { S.style.remove(); S.style = null; }
  S.ranges = [];
}
function show(i) {
  const r = S.ranges[i];
  if (!r) return;
  // The current one in its own colour only, as the transcript draws it.
  if (reg) {
    reg.set('nushi-find', new Highlight(...S.ranges.filter((_, k) => k !== i)));
    reg.set('nushi-find-now', new Highlight(r));
  }
  const el = r.startContainer.parentElement;
  let box = r.getBoundingClientRect();
  const out = () => box.top < top || box.bottom > innerHeight || box.left < 0 || box.right > innerWidth;
  if (!out()) return;
  // Its own scrolling boxes first, then the page, the match a third down.
  if (el) el.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  box = r.getBoundingClientRect();
  if (!out()) return;
  const dx = box.left < 0 || box.right > innerWidth ? box.left - innerWidth / 3 : 0;
  window.scrollBy(dx, box.top - Math.max(top, innerHeight * 0.3));
}
if (op === 'clear') { clear(); return { count: 0, at: 0 }; }
if (op === 'show') { show(at); return { count: S.ranges.length, at }; }
clear();
if (typeof query !== 'string' || query === '') return { count: 0, at: 0 };
const root = document.body || document.documentElement;
if (!root) return { count: 0, at: 0 };
const skip = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE', 'TEXTAREA', 'SELECT', 'OPTION', 'TITLE']);
const blocks = new Map();
function blockOf(el) {
  let e = el;
  while (e && e !== root) {
    let inline = blocks.get(e);
    if (inline === undefined) {
      inline = getComputedStyle(e).display.startsWith('inline');
      blocks.set(e, inline);
    }
    if (!inline) return e;
    e = e.parentElement;
  }
  return root;
}
const nodes = [], starts = [];
let text = '', last = null;
const walk = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
for (let n = walk.nextNode(); n; n = walk.nextNode()) {
  const p = n.parentElement;
  if (!n.data || !p || skip.has(p.tagName) || p.closest('[hidden]')) continue;
  if (p.getClientRects().length === 0 || getComputedStyle(p).visibility !== 'visible') continue;
  const block = blockOf(p);
  // Text in two blocks never runs together into one match.
  if (block !== last && text) text += '\n';
  last = block;
  nodes.push(n);
  starts.push(text.length);
  text += n.data;
}
function locate(pos, end) {
  let lo = 0, hi = starts.length - 1;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (end ? starts[mid] < pos : starts[mid] <= pos) lo = mid; else hi = mid - 1;
  }
  return [nodes[lo], Math.min(pos - starts[lo], nodes[lo].data.length)];
}
const re = new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'giu');
for (const m of text.matchAll(re)) {
  if (S.ranges.length >= 10000) break;
  const r = document.createRange();
  const [a, ao] = locate(m.index, false);
  const [b, bo] = locate(m.index + m[0].length, true);
  r.setStart(a, ao);
  r.setEnd(b, bo);
  S.ranges.push(r);
}
if (reg && S.ranges.length) {
  const css = `::highlight(nushi-find) { background-color: ${color(hit)}; }
    ::highlight(nushi-find-now) { background-color: ${color(now)}; text-decoration: underline 2px ${color(edge)}; }`;
  try {
    S.sheet = new CSSStyleSheet();
    S.sheet.replaceSync(css);
    document.adoptedStyleSheets = [...document.adoptedStyleSheets, S.sheet];
  } catch (e) {
    S.sheet = null;
    S.style = document.createElement('style');
    S.style.textContent = css;
    (document.head || document.documentElement).appendChild(S.style);
  }
}
const i = Math.min(Math.max(at, 0), Math.max(S.ranges.length - 1, 0));
show(i);
return { count: S.ranges.length, at: i };
