// Preflight: verify system + npm deps before the pipeline. `npm run preflight`.
// System deps (chrome/ffmpeg) are NOT auto-installable — this fails loudly if absent.
import { execFileSync } from "node:child_process";
import config from "../promo.config.mjs";

const ok = (bin, args) => { try { execFileSync(bin, args, { stdio: "ignore" }); return true; } catch { return false; } };
const checks = [
  ["node", ok(process.execPath, ["--version"])],
  ["chrome (system)", ok(config.chromePath, ["--version"])],
  ["ffmpeg", ok("ffmpeg", ["-version"])],
  ["ffprobe", ok("ffprobe", ["-version"])],
];
let hasPuppeteer = false;
try { await import("puppeteer-core"); hasPuppeteer = true; } catch {}
checks.push(["puppeteer-core (npm install)", hasPuppeteer]);

for (const [name, pass] of checks) console.log(`${pass ? "✓" : "✗"} ${name}`);
const missing = checks.filter(([, p]) => !p).map(([n]) => n);
if (missing.length) {
  console.error(`\nMissing: ${missing.join(", ")}`);
  console.error("→ System deps (Chrome, ffmpeg/ffprobe) must be installed by you; npm deps via `npm install`.");
  console.error("No API keys/secrets are required — hyperframes render, fonts and music are keyless.");
  process.exit(1);
}
console.log("preflight OK — no secrets required.");
