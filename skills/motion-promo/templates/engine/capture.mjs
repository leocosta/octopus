// Captures a clean still per kind:app beat that doesn't already supply
// `still`, and/or measures a selector-based highlight rect on the live page.
// One browser instance for the whole run so the memoized login in
// browser.mjs costs exactly one auth round-trip (demo APIs commonly
// rate-limit /auth). App-agnostic: routes/viewports/waitFor/selectors all
// come from beats.json.
import { existsSync, mkdirSync, statSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { launchBrowser, newAuthedPage, gotoReady } from "./browser.mjs";

const beatsPath = new URL("../beats.json", import.meta.url);
const assetsDir = fileURLToPath(new URL("../assets/", import.meta.url));
const highlightsPath = fileURLToPath(new URL("../highlights.json", import.meta.url));
const { beats } = JSON.parse(readFileSync(beatsPath, "utf8"));

if (!existsSync(assetsDir)) mkdirSync(assetsDir, { recursive: true });

const MIN_BYTES = 10 * 1024; // 10 KB — below this, the shot is almost certainly a spinner/blank
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// A beat needs a browser visit if it has no pre-supplied still (must be
// screenshotted) OR it has a selector-based highlight (must be measured live,
// even when a still is already supplied — the still alone can't tell us the
// element's rect).
const needsVisit = (b) => b.kind === "app" && (!b.still || b.highlight?.selector);
const toVisit = beats.filter(needsVisit);

if (!toVisit.length) {
  console.log("capture: no beats need capturing or measuring (all kind:app beats have a pre-supplied `still` and no selector highlight).");
  process.exit(0);
}

// Measure a selector's rect on the live page and expand it by `padding` (each
// side). Returns null (and warns) if the selector doesn't match — callers
// should fall back to any manual highlight.x/y/w/h already on the beat.
async function measureHighlight(page, highlight, beatId) {
  const { selector, padding = 8 } = highlight;
  try {
    const rect = await page.$eval(selector, (el) => {
      const r = el.getBoundingClientRect();
      return { x: r.left, y: r.top, w: r.width, h: r.height };
    });
    if (!rect || (rect.w <= 0 && rect.h <= 0)) throw new Error("zero-size rect");
    const p = padding;
    const x = Math.max(0, Math.round(rect.x - p));
    const y = Math.max(0, Math.round(rect.y - p));
    const w = Math.round(rect.w + 2 * p);
    const h = Math.round(rect.h + 2 * p);
    console.log(`✓ ${beatId}: measured highlight for "${selector}" → {x:${x}, y:${y}, w:${w}, h:${h}}`);
    return { x, y, w, h };
  } catch (err) {
    console.warn(`⚠ ${beatId}: highlight selector "${selector}" did not match (${err.message}) — leaving manual highlight (if any) as fallback.`);
    return null;
  }
}

const browser = await launchBrowser();
let failures = 0;
let shotCount = 0;
const highlights = {};

try {
  for (const beat of toVisit) {
    const page = await newAuthedPage(browser, { viewport: beat.viewport || "desktop" });
    try {
      await gotoReady(page, beat.route, { waitFor: beat.waitFor || "main" });

      if (Array.isArray(beat.captureClicks)) {
        for (const selector of beat.captureClicks) {
          await page.waitForSelector(selector, { timeout: 15000 });
          await page.click(selector);
          await sleep(800);
          await page.waitForNetworkIdle({ idleTime: 500, timeout: 15000 }).catch(() => {});
        }
      }

      if (!beat.still) {
        shotCount++;
        const outPath = fileURLToPath(new URL(`../assets/${beat.id}.png`, import.meta.url));
        await page.screenshot({ path: outPath });
        const { size } = statSync(outPath);
        const kb = (size / 1024).toFixed(1);
        if (size < MIN_BYTES) {
          failures++;
          console.warn(`⚠ ${beat.id}: ${outPath} is only ${kb} KB — likely blank/spinner. Check route "${beat.route}" and waitFor "${beat.waitFor || "main"}".`);
        } else {
          console.log(`✓ ${beat.id}: ${outPath} (${kb} KB)`);
        }
      }

      if (beat.highlight?.selector) {
        const rect = await measureHighlight(page, beat.highlight, beat.id);
        if (rect) highlights[beat.id] = rect;
      }
    } finally {
      await page.close();
    }
  }
} finally {
  await browser.close();
}

if (Object.keys(highlights).length) {
  writeFileSync(highlightsPath, JSON.stringify(highlights, null, 2) + "\n");
  console.log(`capture: wrote ${highlightsPath} (${Object.keys(highlights).length} measured highlight(s)).`);
}

if (failures) {
  console.warn(`capture: ${failures}/${shotCount} still(s) look suspiciously small — review before compositing.`);
}
console.log(`capture: done (${shotCount} shot, ${beats.length - shotCount} pre-supplied, ${Object.keys(highlights).length} highlight(s) measured).`);
