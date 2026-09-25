#!/usr/bin/env node
// Build a review deck. No dependencies.
//   node build.mjs <deck-dir>             narrative.json + diagram.src.json -> deck.json + index.html
//   node build.mjs <deck.json> <out.html> render an already complete deck
// Exit 0 = built, 2 = the deck data has problems (listed on stderr), 1 = usage or I/O error.
import { existsSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const readJSON = p => JSON.parse(readFileSync(p, "utf8"));
const errors = [];
const warnings = [];

// ---- Layout: grid positions -> pixel positions and SVG paths --------------------------------
const COL_W = 190, ROW_H = 130, X0 = 80, Y0 = 62, NODE_H = 54, HALF_H = NODE_H / 2, GAP = 2;
const MIN_W = 110, MAX_W = COL_W - 16;

function nodeWidth(n) {
  // Rough text metrics for the template's fonts: label ~7.4px/char, sub ~6.2px/char.
  const need = Math.ceil(Math.max(n.label.length * 7.4, (n.sub || "").length * 6.2) + 28);
  if (need > MAX_W) warnings.push(`node "${n.id}": label or sub is too long for its box; shorten to ~${Math.floor((MAX_W - 28) / 7.4)} chars`);
  return Math.max(MIN_W, Math.min(MAX_W, need));
}

function layout(src) {
  const nodes = src.nodes.map(n => ({
    id: n.id, label: n.label, sub: n.sub || "", kind: n.kind || "existing",
    x: X0 + n.col * COL_W, y: Y0 + n.row * ROW_H, w: n.w || nodeWidth(n), col: n.col, row: n.row,
  }));
  const byId = Object.fromEntries(nodes.map(n => [n.id, n]));
  const cells = new Set();
  for (const n of nodes) {
    const k = `${n.col},${n.row}`;
    if (cells.has(k)) errors.push(`diagram: two nodes share grid cell col ${n.col}, row ${n.row}`);
    cells.add(k);
  }
  // Pass 1: decide how each edge attaches (side-by-side, over the top, or vertical).
  const plans = [];
  for (const e of src.edges) {
    const a = byId[e.from], b = byId[e.to];
    if (!a || !b) { errors.push(`diagram edge ${e.from} -> ${e.to}: unknown node`); continue; }
    let kind, sa, sb;
    if (a.row === b.row) {
      const blocked = nodes.some(n => n.row === a.row && n.col > Math.min(a.col, b.col) && n.col < Math.max(a.col, b.col));
      if (blocked) { kind = "arc"; sa = sb = "top"; } else kind = "straight";
    } else {
      kind = "vertical";
      sa = b.y > a.y ? "bottom" : "top"; sb = b.y > a.y ? "top" : "bottom";
    }
    plans.push({ e, a, b, kind, sa, sb });
  }
  // Spread edges that share a node's top or bottom so their ends don't land on one point.
  const ports = {};
  const addPort = (node, side, other, plan, end) => (ports[`${node.id}:${side}`] ||= []).push({ other, plan, end });
  for (const p of plans) if (p.sa) { addPort(p.a, p.sa, p.b, p, "a"); addPort(p.b, p.sb, p.a, p, "b"); }
  for (const [key, list] of Object.entries(ports)) {
    const node = byId[key.split(":")[0]];
    list.sort((u, v) => u.other.x - v.other.x);
    const step = Math.min(28, (node.w * 0.6) / list.length);
    list.forEach((port, i) => { port.plan["off" + port.end] = (i - (list.length - 1) / 2) * step; });
  }
  // Pass 2: paths.
  let top = Infinity;
  const edges = [];
  for (const { e, a, b, kind, offa = 0, offb = 0 } of plans) {
    let d;
    if (kind === "straight") {
      const dir = Math.sign(b.x - a.x);
      d = `M${a.x + dir * a.w / 2} ${a.y} L${b.x - dir * (b.w / 2 + GAP)} ${b.y}`;
    } else if (kind === "arc") {
      const cy = a.y - HALF_H - 50; top = Math.min(top, cy);
      d = `M${a.x + offa} ${a.y - HALF_H} C ${a.x + offa} ${cy}, ${b.x + offb} ${cy}, ${b.x + offb} ${b.y - HALF_H - GAP}`;
    } else {
      const dir = Math.sign(b.y - a.y);
      const ax = a.x + offa, bx = b.x + offb;
      const sy = a.y + dir * HALF_H, ey = b.y - dir * (HALF_H + GAP);
      d = a.col === b.col && ax === bx ? `M${ax} ${sy} L${bx} ${ey}` : `M${ax} ${sy} C ${ax} ${(sy + ey) / 2}, ${bx} ${(sy + ey) / 2}, ${bx} ${ey}`;
    }
    const edge = { id: `${e.from}-${e.to}`, from: e.from, to: e.to, d, mode: e.mode || "after" };
    if (e.dashed) edge.dashed = true;
    if (e.ghost) edge.ghost = true;
    edges.push(edge);
  }
  const ids = edges.map(e => e.id);
  ids.filter((id, i) => ids.indexOf(id) !== i).forEach(id => errors.push(`diagram: duplicate edge ${id} (use mode "both" instead of two edges)`));

  const minX = Math.min(...nodes.map(n => n.x - n.w / 2)) - 8;
  const maxX = Math.max(...nodes.map(n => n.x + n.w / 2)) + 8;
  const minY = Math.min(top - 4, ...nodes.map(n => n.y - HALF_H)) - 10;
  const maxY = Math.max(...nodes.map(n => n.y + HALF_H)) + 10;
  return {
    viewBox: `${minX} ${minY} ${maxX - minX} ${maxY - minY}`,
    nodes: nodes.map(({ col, row, ...n }) => n),
    edges,
  };
}

// Scenario steps name nodes (from/to); resolve them to edge ids, reversing when needed.
function resolveScenarios(scenarios, edges) {
  return scenarios.map(s => ({
    ...s,
    steps: s.steps.map((st, i) => {
      if (st.path) return st;
      const { from, to, ...rest } = st;
      const fwd = edges.find(e => e.from === from && e.to === to);
      const back = edges.find(e => e.from === to && e.to === from);
      if (!fwd && !back) { errors.push(`scenario ${s.id} step ${i + 1}: no edge between ${from} and ${to}`); return rest; }
      return fwd ? { path: fwd.id, ...rest } : { path: back.id, reverse: true, ...rest };
    }),
  }));
}

// Older decks (like example-deck.json) have single-letter edge ids and no from/to.
function inferEdgeEnds(diagram) {
  for (const e of diagram.edges) {
    if (e.from) continue;
    const [a, b] = e.id.split("-");
    const find = x => diagram.nodes.filter(n => n.id === x || n.id[0] === x);
    const fa = find(a), fb = find(b);
    if (fa.length === 1 && fb.length === 1) { e.from = fa[0].id; e.to = fb[0].id; }
    else errors.push(`diagram edge ${e.id}: can't tell which nodes it joins; add from/to`);
  }
}

// ---- Minimal JSON Schema check (type, required, properties, items, enum, pattern) -----------
function check(v, s, path) {
  if (!s) return;
  const types = [].concat(s.type || []);
  const t = v === null ? "null" : Array.isArray(v) ? "array" : Number.isInteger(v) ? "integer" : typeof v;
  if (types.length && !types.includes(t) && !(t === "integer" && types.includes("number"))) {
    errors.push(`${path}: expected ${types.join("|")}, got ${t}`); return;
  }
  if (s.enum && !s.enum.includes(v)) errors.push(`${path}: ${JSON.stringify(v)} is not one of ${s.enum.join(", ")}`);
  if (s.pattern && typeof v === "string" && !new RegExp(s.pattern).test(v)) errors.push(`${path}: "${v}" doesn't match ${s.pattern}`);
  if (t === "object") {
    for (const k of s.required || []) if (!(k in v)) errors.push(`${path}: missing "${k}"`);
    for (const [k, sub] of Object.entries(s.properties || {})) if (k in v) check(v[k], sub, `${path}.${k}`);
  }
  if (t === "array" && s.items) v.forEach((x, i) => check(x, s.items, `${path}[${i}]`));
}

function crossCheck(deck) {
  const edgeIds = new Set(deck.diagram.edges.map(e => e.id));
  const reqIds = new Set(deck.problem.requirements.map(r => r.id));
  for (const s of deck.scenarios) s.steps.forEach((st, i) => {
    if (st.path && !edgeIds.has(st.path)) errors.push(`scenario ${s.id} step ${i + 1}: unknown edge "${st.path}"`);
    if (st.ref && !reqIds.has(st.ref)) errors.push(`scenario ${s.id} step ${i + 1}: unknown requirement "${st.ref}"`);
  });
}

// ---- Main ---------------------------------------------------------------------------------
const [a1, a2] = process.argv.slice(2);
if (!a1) { console.error("usage: build.mjs <deck-dir> | build.mjs <deck.json> <out.html>"); process.exit(1); }

let deck, deckOut, htmlOut;
try {
  if (statSync(a1).isDirectory()) {
    const narrative = readJSON(join(a1, "narrative.json"));
    const src = readJSON(join(a1, "diagram.src.json"));
    const diagram = layout(src);
    deck = { ...narrative, diagram, scenarios: resolveScenarios(src.scenarios || [], diagram.edges) };
    deckOut = join(a1, "deck.json");
    htmlOut = join(a1, "index.html");
  } else {
    if (!a2) { console.error("usage: build.mjs <deck.json> <out.html>"); process.exit(1); }
    deck = readJSON(a1);
    if (deck.diagram?.edges) inferEdgeEnds(deck.diagram);
    htmlOut = a2;
  }
} catch (e) { console.error(String(e.message || e)); process.exit(1); }

check(deck, readJSON(join(here, "deck.schema.json")), "deck");
if (!errors.length) crossCheck(deck);
warnings.forEach(w => console.error("warning: " + w));
if (errors.length) { console.error("deck problems:\n  " + errors.join("\n  ")); process.exit(2); }

if (deckOut) writeFileSync(deckOut, JSON.stringify(deck, null, 2) + "\n");
const tplPath = join(here, "review-deck.template.html");
if (!existsSync(tplPath)) { console.error("missing template: " + tplPath); process.exit(1); }
// JSON inside <script> must not contain "</" or it can close the tag early.
const json = JSON.stringify(deck, null, 2).replace(/<\//g, "<\\/");
const title = String(deck.meta?.title || "Design review").replace(/[<>&"]/g, c => ({ "<": "&lt;", ">": "&gt;", "&": "&amp;", '"': "&quot;" }[c]));
writeFileSync(htmlOut, readFileSync(tplPath, "utf8").replace("__DECK_DATA__", () => json).replaceAll("__DECK_TITLE__", title));
console.log(`built ${htmlOut}${deckOut ? ` and ${deckOut}` : ""}`);
