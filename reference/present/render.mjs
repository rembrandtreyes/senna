#!/usr/bin/env node
// Usage: node render.mjs <deck.json> <out.html> [template.html]
// Injects deck data into the review-deck template. No dependencies.
// TODO (Claude Code): validate against deck.schema.json with ajv; cross-check that every
// scenario step's `path` is a diagram edge id and every `ref` is a requirement id.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const [deckPath, outPath, tplArg] = process.argv.slice(2);
if (!deckPath || !outPath) { console.error("usage: render.mjs <deck.json> <out.html> [template.html]"); process.exit(1); }
const here = dirname(fileURLToPath(import.meta.url));
const tpl = readFileSync(tplArg || join(here, "review-deck.template.html"), "utf8");
const deck = JSON.parse(readFileSync(deckPath, "utf8"));

const errors = [];
const edgeIds = new Set((deck.diagram?.edges || []).map(e => e.id));
const reqIds = new Set((deck.problem?.requirements || []).map(r => r.id));
for (const s of deck.scenarios || []) for (const [i, st] of (s.steps || []).entries()) {
  if (!edgeIds.has(st.path)) errors.push(`scenario ${s.id} step ${i + 1}: unknown edge "${st.path}"`);
  if (st.ref && !reqIds.has(st.ref)) errors.push(`scenario ${s.id} step ${i + 1}: unknown requirement "${st.ref}"`);
}
if (errors.length) { console.error("deck.json problems:\n  " + errors.join("\n  ")); process.exit(2); }

// JSON inside <script> must not contain "</" or it can close the tag early.
const json = JSON.stringify(deck, null, 2).replace(/<\//g, "<\\/");
const title = String(deck.meta?.title || "Design review").replace(/[<>&"]/g, c => ({ "<": "&lt;", ">": "&gt;", "&": "&amp;", '"': "&quot;" }[c]));
writeFileSync(outPath, tpl.replace("__DECK_DATA__", () => json).replaceAll("__DECK_TITLE__", title));
console.log(`rendered ${outPath}`);
