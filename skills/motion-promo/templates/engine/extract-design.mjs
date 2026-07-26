// Sample the TARGET app's design system so the promo overlays match its brand.
// Outputs design.tokens.json (bg, accent, fg, fontHero, fontMono, radius).
// Config overrides in promo.config.design win over sampled values.
import { writeFileSync } from "node:fs";
import { launchBrowser, newAuthedPage, gotoReady } from "./browser.mjs";
import config from "../promo.config.mjs";

const rgbToHex = (rgb) => {
  const m = String(rgb).match(/\d+/g);
  if (!m) return null;
  const [r, g, b, a] = m.map(Number);
  if (a === 0) return null; // transparent — useless as a token
  return "#" + [r, g, b].map((n) => n.toString(16).padStart(2, "0")).join("");
};
const luminance = (hex) => {
  const n = parseInt(hex.slice(1), 16);
  return (0.2126 * ((n >> 16) & 255) + 0.7152 * ((n >> 8) & 255) + 0.0722 * (n & 255)) / 255;
};

const browser = await launchBrowser();
const page = await newAuthedPage(browser, { viewport: "desktop" });
await gotoReady(page, "/", { waitFor: "body" });

const sampled = await page.evaluate(() => {
  const cs = (el, p) => (el ? getComputedStyle(el)[p] : null);
  // background: body / largest full-bleed container
  const bg = cs(document.body, "backgroundColor");
  // accent: the most saturated color among buttons/links (brand primary)
  const cands = [...document.querySelectorAll("button, a, [class*=primary], [role=button]")].slice(0, 200);
  const colorCount = {};
  for (const el of cands) {
    for (const p of ["backgroundColor", "color", "borderColor"]) {
      const c = cs(el, p);
      if (c) colorCount[c] = (colorCount[c] || 0) + 1;
    }
  }
  // headings + mono
  const h = document.querySelector("h1, h2, [class*=title]");
  const fontHero = cs(h, "fontFamily");
  const monoEl = [...document.querySelectorAll("*")].find((e) => /mono/i.test(cs(e, "fontFamily") || ""));
  const fontMono = cs(monoEl, "fontFamily");
  const fg = cs(h, "color");
  const radius = cs(document.querySelector("button, [class*=card]"), "borderRadius");
  return { bg, fg, fontHero, fontMono, radius, colorCount };
});

// pick accent: most saturated non-grey, non-bg color
function saturation(hex) {
  const n = parseInt(hex.slice(1), 16);
  const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b);
  return mx === 0 ? 0 : (mx - mn) / mx;
}
const bgHex = rgbToHex(sampled.bg) || "#17191c";
let accent = null, best = 0;
for (const [rgb, count] of Object.entries(sampled.colorCount)) {
  const hex = rgbToHex(rgb);
  if (!hex || hex === bgHex) continue;
  const score = saturation(hex) * Math.log2(1 + count);
  if (saturation(hex) > 0.25 && score > best) { best = score; accent = hex; }
}

const dark = luminance(bgHex) < 0.4;
const tokens = {
  bg: bgHex,
  accent: accent || "#70a23f",
  fg: rgbToHex(sampled.fg) || (dark ? "#f5f4f0" : "#101215"),
  muted: dark ? "#c0bcaf" : "#5b5f66",
  fontHero: sampled.fontHero || "'Bricolage Grotesque', sans-serif",
  fontMono: sampled.fontMono || "'DM Mono', monospace",
  // cap pill radii: a sampled button often gives 9999px, which would round the
  // rectangular highlight box into a stadium. Keep only sane card-like radii.
  radius: (() => {
    const m = String(sampled.radius || "").match(/^([\d.]+)px$/);
    const px = m ? Number(m[1]) : NaN;
    return Number.isFinite(px) && px <= 32 ? sampled.radius : "16px";
  })(),
  ...(config.design || {}), // hard overrides win
};

writeFileSync(new URL("../design.tokens.json", import.meta.url), JSON.stringify(tokens, null, 2));
console.log("design tokens:", tokens);
await browser.close();
