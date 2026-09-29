#!/usr/bin/env node
// Turn a spec's LikeC4 proposal model (specs/<slug>/model/) into planning artifacts. No dependencies
// beyond the project's own likec4 (node_modules/.bin/likec4, found by walking up from the spec).
//   node model.mjs deck  <spec-dir>   model + deck/layout.json -> deck/diagram.src.json
//   node model.mjs flows <spec-dir>   dynamic views -> Mermaid blocks between <!-- flow:<view> -->
//                                     and <!-- /flow --> markers in spec.md
//   node model.mjs views <spec-dir>   list elements and views (to write layout.json from)
// Option: --export <file> reads a saved `likec4 export json` instead of running likec4.
// Exit 0 = ok, 2 = the model, layout, or markers have problems (listed on stderr),
// 3 = likec4 isn't installed, 1 = usage or I/O error.
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const errors = [];
const warnings = [];
const die = (msg, code = 1) => { console.error(msg); process.exit(code); };
const finish = () => {
  warnings.forEach(w => console.error("warning: " + w));
  if (errors.length) die("model problems:\n  " + errors.join("\n  "), 2);
};

// ---- Load the model ---------------------------------------------------------------------------
function findLikec4(from) {
  for (let d = resolve(from); ; d = dirname(d)) {
    const bin = join(d, "node_modules", ".bin", "likec4");
    if (existsSync(bin)) return bin;
    if (dirname(d) === d) return null;
  }
}

function loadModel(modelDir, exportFile) {
  let raw;
  if (exportFile) raw = readFileSync(exportFile, "utf8");
  else {
    const bin = findLikec4(modelDir);
    if (!bin) die("likec4 isn't installed in this project (npm install --save-dev --save-exact likec4)", 3);
    try { execFileSync(bin, ["validate", modelDir], { stdio: "pipe" }); }
    catch (e) { die(`model is invalid; run: npx likec4 validate ${modelDir}\n${String(e.stdout || "")}${String(e.stderr || "")}`.trim(), 2); }
    const tmp = mkdtempSync(join(tmpdir(), "likec4-"));
    try {
      execFileSync(bin, ["export", "json", "--skip-layout", "-o", join(tmp, "m.json"), modelDir], { stdio: "pipe" });
      raw = readFileSync(join(tmp, "m.json"), "utf8");
    } finally { rmSync(tmp, { recursive: true, force: true }); }
  }
  const m = [].concat(JSON.parse(raw))[0];
  if (!m?.elements) die("unexpected likec4 export format (no elements)");
  return m;
}

const txt = v => (v && typeof v === "object" ? v.txt ?? v.md ?? "" : v || "");
const deckId = fqn => { const id = fqn.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, ""); return /^[a-z]/.test(id) ? id : "n_" + id; };
const tagged = (x, t) => (x.tags || []).includes(t);
const ancestors = fqn => fqn.split(".").map((_, i, a) => a.slice(0, a.length - i).join("."));
const REF = /\bR-\d+\b/g;
// Refs are cited as "(R-2)" or "(R-2, R-5)" at the end of a step title; the deck shows them separately.
const stripRefs = s => s.replace(/\s*\((?:R-\d+(?:,\s*)?)+\)/g, "").replace(REF, "").replace(/\s{2,}/g, " ").trim();

// ---- deck: model + layout -> diagram.src.json ---------------------------------------------------
function deck(specDir, m) {
  const layoutPath = join(specDir, "deck", "layout.json");
  if (!existsSync(layoutPath)) die(`missing ${layoutPath} (deck-diagrammer writes it)`);
  const layout = JSON.parse(readFileSync(layoutPath, "utf8"));
  const placed = layout.nodes || {};

  // Map any element to the closest placed element at or above it.
  const mapTo = fqn => ancestors(fqn).find(a => a in placed) || null;
  const nodes = [];
  for (const [fqn, p] of Object.entries(placed)) {
    const el = m.elements[fqn];
    if (!el) { errors.push(`layout node "${fqn}": no such element in the model`); continue; }
    const kind = tagged(el, "new") ? "new" : tagged(el, "removed") ? "removed" : "existing";
    nodes.push({ id: deckId(fqn), label: p.label || el.title, sub: p.sub ?? el.technology ?? "", col: p.col, row: p.row, kind });
  }

  // Classify relations. A `#removed` relation cancels the untagged relation(s) it repeats.
  const rels = Object.values(m.relations);
  const cancelled = new Set(rels.filter(r => tagged(r, "removed")).map(r => `${r.source.model}>${r.target.model}`));
  const statusOf = r => {
    const s = r.source.model, t = r.target.model, es = m.elements[s], et = m.elements[t];
    if (tagged(r, "removed") || tagged(es, "removed") || tagged(et, "removed")) return "removed";
    if (tagged(r, "new") || tagged(es, "new") || tagged(et, "new")) return "new";
    return cancelled.has(`${s}>${t}`) ? null : "existing";
  };
  const pairs = new Map();
  for (const r of rels) {
    const status = statusOf(r);
    const a = mapTo(r.source.model), b = mapTo(r.target.model);
    if (!status || !a || !b || a === b) continue;
    const key = [a, b].sort().join("|");
    if (!pairs.has(key)) pairs.set(key, []);
    pairs.get(key).push({ r, a, b, status });
  }
  const edges = [];
  for (const list of pairs.values()) {
    const has = s => list.some(x => x.status === s);
    const mode = has("existing") || (has("new") && has("removed")) ? "both" : has("new") ? "after" : "before";
    const pick = list.find(x => x.status === "existing") || list.find(x => x.status === "new") || list[0];
    const edge = { from: deckId(pick.a), to: deckId(pick.b), mode };
    if (pick.r.title) edge.label = pick.r.title;
    if (pick.r.line === "dashed" || pick.r.line === "dotted") edge.dashed = true;
    edges.push(edge);
  }

  // Scenarios come from dynamic views; tone and the state panel come from the layout.
  const scenarios = [];
  for (const sc of layout.scenarios || []) {
    const v = m.views[sc.view];
    if (!v || v._type !== "dynamic") { errors.push(`layout scenario "${sc.view}": no dynamic view with that id`); continue; }
    const extra = sc.steps || {};
    const steps = [];
    (v.edges || []).forEach((e, i) => {
      const a = mapTo(e.source), b = mapTo(e.target);
      if (!a || !b) { errors.push(`view ${sc.view} step ${i + 1} (${e.source} -> ${e.target}): place ${!a ? e.source : e.target} or one of its parents in layout.json`); return; }
      if (a === b) { warnings.push(`view ${sc.view} step ${i + 1}: both ends are inside ${a}; skipped`); return; }
      const label = e.label || "", notes = txt(e.notes);
      const step = { from: deckId(a), to: deckId(b), text: notes || stripRefs(label) || `${e.source} to ${e.target}` };
      const ref = (label + " " + notes).match(REF);
      if (ref) step.ref = ref[0];
      Object.assign(step, extra[String(steps.length + 1)] || {});
      steps.push(step);
    });
    const s = { id: deckId(sc.view).replace(/_/g, "-"), label: sc.label || v.title || sc.view, tone: sc.tone || "allow", steps };
    if (sc.stateLabel) s.stateLabel = sc.stateLabel;
    scenarios.push(s);
  }
  finish();
  const out = join(specDir, "deck", "diagram.src.json");
  writeFileSync(out, JSON.stringify({ nodes, edges, scenarios }, null, 2) + "\n");
  console.log(`wrote ${out}: ${nodes.length} nodes, ${edges.length} edges, ${scenarios.length} scenarios`);
}

// ---- flows: dynamic views -> Mermaid sequence diagrams in spec.md -----------------------------------
// Mermaid treats ; and # specially in message text; entity codes keep them literal.
// One pass, so the ; inside a new #35; isn't escaped again.
const MM = { "#": "#35;", ";": "#59;", '"': "#quot;" };
const mm = s => String(s).replace(/[#;"]/g, c => MM[c]).replace(/\s+/g, " ").trim();

function sequence(m, v) {
  const order = [];
  for (const e of v.edges || []) for (const f of [e.source, e.target]) if (!order.includes(f)) order.push(f);
  const lines = ["```mermaid", "sequenceDiagram"];
  for (const f of order) lines.push(`  participant ${deckId(f)} as ${mm(m.elements[f]?.title || f)}`);
  for (const e of v.edges || []) lines.push(`  ${deckId(e.source)}${e.dir === "back" ? "-->>" : "->>"}${deckId(e.target)}: ${mm(e.label || "")}`);
  lines.push("```");
  return lines.join("\n");
}

function flows(specDir, m) {
  const specPath = join(specDir, "spec.md");
  let md = readFileSync(specPath, "utf8");
  const used = new Set();
  // A marker pair's contents are regenerated; a lone opening marker gets a block inserted after it.
  // Nothing outside a pair is ever removed.
  md = md.replace(/<!-- flow:([A-Za-z0-9_-]+) -->((?:(?!<!-- flow:)[\s\S])*?<!-- \/flow -->)?/g, (whole, id) => {
    const v = m.views[id];
    if (!v || v._type !== "dynamic") { errors.push(`spec.md marker flow:${id}: no dynamic view with that id`); return whole; }
    used.add(id);
    return `<!-- flow:${id} -->\n${sequence(m, v)}\n<!-- /flow -->`;
  });
  for (const [id, v] of Object.entries(m.views)) {
    if (v._type === "dynamic" && !String(v.sourcePath || "").startsWith("..") && !used.has(id)) {
      warnings.push(`dynamic view ${id} has no <!-- flow:${id} --> marker in spec.md`);
    }
  }
  finish();
  writeFileSync(specPath, md);
  console.log(`updated ${specPath}: ${used.size} flow diagram(s)`);
}

// ---- views: what a layout can reference ----------------------------------------------------------
function views(m) {
  console.log("elements:");
  for (const [id, el] of Object.entries(m.elements)) {
    const tags = (el.tags || []).map(t => "#" + t).join(" ");
    console.log(`  ${id}  ${el.kind}  "${el.title}"${el.technology ? `  [${el.technology}]` : ""}${tags ? "  " + tags : ""}`);
  }
  console.log("dynamic views:");
  for (const [id, v] of Object.entries(m.views)) if (v._type === "dynamic") console.log(`  ${id}  "${v.title || ""}"  ${(v.edges || []).length} steps  (${v.sourcePath})`);
}

// ---- Main ---------------------------------------------------------------------------------------
const args = process.argv.slice(2);
const ei = args.indexOf("--export");
const exportFile = ei >= 0 ? args.splice(ei, 2)[1] : null;
const [cmd, specDir] = args;
if (!["deck", "flows", "views"].includes(cmd) || !specDir) die("usage: model.mjs deck|flows|views <spec-dir> [--export <likec4.json>]");
const modelDir = join(specDir, "model");
if (!exportFile && !existsSync(modelDir)) die(`no model at ${modelDir}`);
try {
  const m = loadModel(modelDir, exportFile);
  if (cmd === "deck") deck(specDir, m);
  else if (cmd === "flows") flows(specDir, m);
  else views(m);
} catch (e) { die(String(e.message || e)); }
