// Captures a clean still per kind:app beat that doesn't already supply
// `still`. One browser instance for the whole run so the memoized login in
// browser.mjs costs exactly one auth round-trip (demo APIs commonly
// rate-limit /auth). App-agnostic: routes/viewports/waitFor all come from
// beats.json.
import { existsSync, mkdirSync, statSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { launchBrowser, newAuthedPage, gotoReady } from "./browser.mjs";

const beatsPath = new URL("../beats.json", import.meta.url);
const assetsDir = fileURLToPath(new URL("../assets/", import.meta.url));
const { beats } = JSON.parse(readFileSync(beatsPath, "utf8"));

if (!existsSync(assetsDir)) mkdirSync(assetsDir, { recursive: true });

const MIN_BYTES = 10 * 1024; // 10 KB — below this, the shot is almost certainly a spinner/blank

const toCapture = beats.filter((b) => b.kind === "app" && !b.still);

if (!toCapture.length) {
  console.log("capture: no beats need capturing (all kind:app beats have a pre-supplied `still`).");
  process.exit(0);
}

const browser = await launchBrowser();
let failures = 0;

try {
  for (const beat of toCapture) {
    const outPath = fileURLToPath(new URL(`../assets/${beat.id}.png`, import.meta.url));
    const page = await newAuthedPage(browser, { viewport: beat.viewport || "desktop" });
    try {
      await gotoReady(page, beat.route, { waitFor: beat.waitFor || "main" });
      await page.screenshot({ path: outPath });
      const { size } = statSync(outPath);
      const kb = (size / 1024).toFixed(1);
      if (size < MIN_BYTES) {
        failures++;
        console.warn(`⚠ ${beat.id}: ${outPath} is only ${kb} KB — likely blank/spinner. Check route "${beat.route}" and waitFor "${beat.waitFor || "main"}".`);
      } else {
        console.log(`✓ ${beat.id}: ${outPath} (${kb} KB)`);
      }
    } finally {
      await page.close();
    }
  }
} finally {
  await browser.close();
}

if (failures) {
  console.warn(`capture: ${failures}/${toCapture.length} still(s) look suspiciously small — review before compositing.`);
}
console.log(`capture: done (${toCapture.length} shot, ${beats.length - toCapture.length} pre-supplied).`);
