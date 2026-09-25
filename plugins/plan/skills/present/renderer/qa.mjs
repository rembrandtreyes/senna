#!/usr/bin/env node
// Visual QA for a built deck: screenshots every section in light/dark at 1440px and 390px and
// runs automated checks (overflow, clipped text, diagram labels, contrast, density, JS errors).
//   node qa.mjs <index.html> <out-dir>
// Writes <out-dir>/<variant>/<nn>-<section>.png and <out-dir>/qa-report.json.
// Exit 0 = no issues, 4 = issues found, 3 = playwright-core missing, 1 = other error.
// Needs playwright-core in $HARNESS_PW_DIR (default ~/.cache/my-harness/present) and a Chrome
// or Chromium install. Setup: npm install --prefix ~/.cache/my-harness/present playwright-core
import { mkdirSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const [htmlArg, outArg] = process.argv.slice(2);
if (!htmlArg || !outArg) { console.error("usage: qa.mjs <index.html> <out-dir>"); process.exit(1); }
const pwDir = process.env.HARNESS_PW_DIR || join(homedir(), ".cache", "my-harness", "present");

let chromium;
try { ({ chromium } = createRequire(join(pwDir, "package.json"))("playwright-core")); }
catch {
  console.error(`playwright-core not found in ${pwDir}.\nInstall: npm install --prefix ${pwDir} playwright-core`);
  process.exit(3);
}

let browser;
for (const opts of [{ channel: "chrome" }, { channel: "chromium" }, {}]) {
  try { browser = await chromium.launch(opts); break; } catch { /* try the next one */ }
}
if (!browser) { console.error("No Chrome or Chromium found. Install Google Chrome, or run: npx playwright install chromium"); process.exit(1); }

const VARIANTS = [
  { name: "light-1440", colorScheme: "light", width: 1440, height: 900 },
  { name: "dark-1440", colorScheme: "dark", width: 1440, height: 900 },
  { name: "light-390", colorScheme: "light", width: 390, height: 844 },
  { name: "dark-390", colorScheme: "dark", width: 390, height: 844 },
];

// Runs in the page against the visible section.
function inspect() {
  const out = [];
  const W = innerWidth, H = innerHeight;
  const slide = document.querySelector("section.slide:not([hidden])");
  if (!slide) return [{ check: "render", detail: "no visible section" }];
  const label = el => {
    const t = (el.textContent || "").trim().replace(/\s+/g, " ").slice(0, 60);
    return `${el.tagName.toLowerCase()}${el.id ? "#" + el.id : ""}${el.classList.length ? "." + [...el.classList].join(".") : ""}${t ? ` "${t}"` : ""}`;
  };
  const visible = el => { const r = el.getBoundingClientRect(); const s = getComputedStyle(el); return r.width > 0 && r.height > 0 && s.visibility !== "hidden" && s.display !== "none" && +s.opacity !== 0; };

  if (document.documentElement.scrollWidth > W + 1) out.push({ check: "page-overflow", detail: `page is ${document.documentElement.scrollWidth}px wide in a ${W}px viewport` });

  const els = [...slide.querySelectorAll("*")].filter(visible);
  // Content inside a horizontal scroll container is reachable by design (wide tables, diagrams).
  const inScroller = el => { for (let e = el.parentElement; e && e !== slide; e = e.parentElement) if (/auto|scroll/.test(getComputedStyle(e).overflowX)) return true; return false; };
  let n = 0;
  for (const el of els) {
    if (el.closest("svg") && el.tagName.toLowerCase() !== "svg") continue;
    if (inScroller(el)) continue;
    const r = el.getBoundingClientRect();
    if (r.right > W + 1 && n++ < 5) out.push({ check: "offscreen", detail: `${label(el)} extends ${Math.round(r.right - W)}px past the right edge` });
  }
  n = 0;
  for (const el of els) {
    const s = getComputedStyle(el);
    const clips = /hidden|clip/.test(s.overflowX) || s.textOverflow === "ellipsis";
    if (clips && el.scrollWidth > el.clientWidth + 1 && !el.closest("svg") && n++ < 5) out.push({ check: "clipped-text", detail: `${label(el)} is cut off (${el.scrollWidth}px of content in ${el.clientWidth}px)` });
  }
  for (const g of slide.querySelectorAll("svg .node")) {
    if (!visible(g)) continue;
    const rect = g.querySelector("rect"); if (!rect) continue;
    const w = rect.getBBox().width;
    for (const t of g.querySelectorAll("text")) if (t.getBBox().width > w - 8) out.push({ check: "diagram-label", detail: `"${t.textContent}" (${Math.round(t.getBBox().width)}px) doesn't fit its ${Math.round(w)}px box` });
  }

  // WCAG contrast on text-bearing elements.
  const parse = c => { const m = c.match(/[\d.]+/g); return m ? m.map(Number) : null; };
  const lum = ([r, g, b]) => { const f = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }; return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b); };
  const bgOf = el => { for (let e = el; e; e = e.parentElement) { const c = parse(getComputedStyle(e).backgroundColor); if (c && (c.length < 4 || c[3] > 0.5)) return c; } return parse(getComputedStyle(document.body).backgroundColor) || [255, 255, 255]; };
  n = 0;
  const seen = new Set();
  for (const el of els) {
    if (el.closest("svg")) continue;
    const own = [...el.childNodes].some(c => c.nodeType === 3 && c.textContent.trim());
    if (!own) continue;
    const s = getComputedStyle(el);
    const fg = parse(s.color); if (!fg || (fg.length > 3 && fg[3] < 0.1)) continue;
    const L1 = lum(fg), L2 = lum(bgOf(el));
    const ratio = (Math.max(L1, L2) + 0.05) / (Math.min(L1, L2) + 0.05);
    const size = parseFloat(s.fontSize), bold = +s.fontWeight >= 700;
    const need = size >= 24 || (size >= 18.66 && bold) ? 3 : 4.5;
    const key = s.color + s.fontSize;
    if (ratio < need && !seen.has(key) && n++ < 5) { seen.add(key); out.push({ check: "contrast", detail: `${label(el)}: ${ratio.toFixed(2)}:1, needs ${need}:1` }); }
  }

  const words = (slide.innerText || "").split(/\s+/).filter(Boolean).length;
  if (words > 350) out.push({ check: "density", detail: `${words} words in one section; aim for under ~250` });
  if (W >= 1000 && slide.scrollHeight > H * 2.2) out.push({ check: "density", detail: `section is ${Math.round(slide.scrollHeight / H * 10) / 10} screens tall at desktop width` });
  return out;
}

const url = pathToFileURL(resolve(htmlArg)).href;
const report = { url, variants: {} };
let total = 0;
for (const v of VARIANTS) {
  const ctx = await browser.newContext({ viewport: { width: v.width, height: v.height }, colorScheme: v.colorScheme, reducedMotion: "reduce", deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  const jsErrors = [];
  page.on("pageerror", e => jsErrors.push(String(e.message || e)));
  page.on("console", m => { if (m.type() === "error") jsErrors.push(m.text()); });
  await page.goto(url);
  await page.waitForTimeout(300);
  const sections = await page.$$eval("[data-go]", bs => bs.map(b => ({ i: +b.dataset.go, name: b.textContent.trim().replace(/\d+$/, "").trim() })));
  const dir = join(outArg, v.name); mkdirSync(dir, { recursive: true });
  const results = [];
  for (const s of sections) {
    await page.$eval(`[data-go="${s.i}"]`, b => b.click());
    await page.waitForTimeout(250);
    const issues = await page.evaluate(inspect);
    const file = join(dir, `${String(s.i + 1).padStart(2, "0")}-${s.name.toLowerCase().replace(/[^a-z0-9]+/g, "-")}.png`);
    await page.screenshot({ path: file, fullPage: true });
    results.push({ section: s.name, screenshot: file, issues });
    total += issues.length;
  }
  if (jsErrors.length) { results.push({ section: "(page)", issues: jsErrors.map(e => ({ check: "js-error", detail: e })) }); total += jsErrors.length; }
  report.variants[v.name] = results;
  await ctx.close();
}
await browser.close();

mkdirSync(outArg, { recursive: true });
writeFileSync(join(outArg, "qa-report.json"), JSON.stringify(report, null, 2) + "\n");
for (const [name, results] of Object.entries(report.variants)) for (const r of results) for (const i of r.issues) console.log(`${name}  ${r.section}  [${i.check}] ${i.detail}`);
console.log(`${total} issue(s). Report: ${join(outArg, "qa-report.json")}`);
process.exit(total ? 4 : 0);
