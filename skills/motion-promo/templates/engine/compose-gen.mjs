// Generates index.html from templates/composition.html + beats.json +
// design.tokens.json. App-agnostic: every color/font comes from tokens,
// every scene/timeline call is derived from beats — nothing here hardcodes
// a brand, route, or copy.
import { readFileSync, writeFileSync } from "node:fs";
import config from "../promo.config.mjs";

const SCENE_OVERLAP = 0.2; // seconds two consecutive scenes crossfade

const beatsPath = new URL("../beats.json", import.meta.url);
const tokensPath = new URL("../design.tokens.json", import.meta.url);
const compositionPath = new URL("../composition.html", import.meta.url);
const outPath = new URL("../index.html", import.meta.url);

const { beats } = JSON.parse(readFileSync(beatsPath, "utf8"));
const tokens = JSON.parse(readFileSync(tokensPath, "utf8"));
let template = readFileSync(compositionPath, "utf8");

if (!Array.isArray(beats) || beats.length < 3) {
  console.error("beats.json must have >= 3 beats (see templates/beats.schema.json)");
  process.exit(1);
}

// ── small helpers ───────────────────────────────────────────────────────────

const escapeHtml = (s) =>
  String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

const slugId = (s) => String(s).replace(/[^a-zA-Z0-9_-]/g, "-");

// "Sua *academia* no piloto" → words with the *marked* one flagged accent.
// Returns [{ text, accent }].
function parseWords(line) {
  const out = [];
  const re = /\*([^*]+)\*|(\S+)/g;
  let m;
  while ((m = re.exec(line))) {
    if (m[1] !== undefined) {
      for (const w of m[1].split(/\s+/)) if (w) out.push({ text: w, accent: true });
    } else if (m[2] !== undefined) {
      out.push({ text: m[2], accent: false });
    }
  }
  return out;
}

// For CTA lines: honors *accent* word markup inline; otherwise returns plain
// escaped text (caller decides whole-line accent color).
function inlineAccentHtml(line) {
  const parts = String(line).split(/(\*[^*]+\*)/g);
  return parts
    .map((p) => {
      const m = /^\*([^*]+)\*$/.exec(p);
      return m ? `<span class="t-accent">${escapeHtml(m[1])}</span>` : escapeHtml(p);
    })
    .join("");
}

function googleFontsLink(tokens) {
  // Best-effort: pull the first font-family name out of each token and ask
  // Google Fonts for it. Harmless if the family isn't actually hosted there
  // (the <link> 404s silently and the browser falls back to the CSS stack).
  const familyOf = (stack) => {
    const first = String(stack || "").split(",")[0].trim().replace(/^['"]|['"]$/g, "");
    return first;
  };
  const families = [...new Set([familyOf(tokens.fontHero), familyOf(tokens.fontMono)].filter(Boolean))];
  if (!families.length) return "";
  const qs = families.map((f) => `family=${encodeURIComponent(f).replace(/%20/g, "+")}:wght@400;500;700;800;900`).join("&");
  return `<link href="https://fonts.googleapis.com/css2?${qs}&display=swap" rel="stylesheet" />`;
}

// ── scene + timeline generation ─────────────────────────────────────────────

function computeStarts(beats) {
  const starts = [];
  let cursor = 0;
  for (let i = 0; i < beats.length; i++) {
    const dur = beats[i].durationSec ?? 4.6;
    starts.push(i === 0 ? 0 : cursor - SCENE_OVERLAP);
    cursor = (i === 0 ? 0 : starts[i]) + dur;
  }
  return starts;
}

function renderIntro(beat, prefix, start, dur, idx) {
  const text = beat.text || {};
  const lines = text.lines || [""];
  let wordIdx = 0;
  const lineDivs = lines
    .map((line, li) => {
      const words = parseWords(line);
      const spans = words
        .map((w) => {
          const id = `${prefix}-w${wordIdx++}`;
          return `<span id="${id}" class="word${w.accent ? " t-accent" : ""}">${escapeHtml(w.text)}</span>`;
        })
        .join(" ");
      return `<div${li > 0 ? ' style="margin-top:6px;"' : ""}>${spans}</div>`;
    })
    .join("\n          ");

  const html = `
      <div id="${prefix}" class="scene clip" data-start="${start.toFixed(2)}" data-duration="${dur.toFixed(2)}" data-track-index="${idx}" style="z-index:${idx};">
        <div id="${prefix}i" style="position:absolute;inset:0;display:flex;flex-direction:column;justify-content:center;padding-left:140px;">
          <div id="${prefix}-glow" style="position:absolute;top:-260px;left:-200px;width:1200px;height:1200px;background:radial-gradient(circle,color-mix(in srgb, var(--accent) 16%, transparent) 0%,color-mix(in srgb, var(--accent) 4%, transparent) 45%,transparent 68%);pointer-events:none;"></div>
          ${text.kicker ? `<div id="${prefix}-label" class="t-label" style="opacity:0;">${escapeHtml(text.kicker)}</div>` : ""}
          <div class="t-hero" style="margin-top:22px;">
          ${lineDivs}
          </div>
          <div id="${prefix}-rule" style="width:200px;height:4px;background:var(--accent);border-radius:2px;margin-top:34px;transform-origin:left center;"></div>
          ${text.sub ? `<div id="${prefix}-sub" class="t-sub" style="margin-top:26px;opacity:0;">${escapeHtml(text.sub)}</div>` : ""}
        </div>
      </div>`;

  const wordCount = wordIdx;
  const jsLines = [];
  jsLines.push(`tl.fromTo("#${prefix}-glow", { scale:0.8, opacity:0 }, { scale:1, opacity:1, duration:0.7, ease:"power2.out" }, ${start.toFixed(2)});`);
  if (text.kicker)
    jsLines.push(`tl.fromTo("#${prefix}-label", { opacity:0, y:14 }, { opacity:1, y:0, duration:0.34, ease:"power2.out" }, ${(start + 0.12).toFixed(2)});`);
  for (let i = 0; i < wordCount; i++) {
    const at = start + 0.24 + i * 0.1;
    jsLines.push(
      `tl.fromTo("#${prefix}-w${i}", { opacity:0, y:70 }, { opacity:1, y:0, duration:0.55, ease:"expo.out" }, ${at.toFixed(2)});`
    );
  }
  const afterWords = start + 0.24 + wordCount * 0.1 + 0.06;
  jsLines.push(`tl.fromTo("#${prefix}-rule", { scaleX:0, opacity:0 }, { scaleX:1, opacity:1, duration:0.44, ease:"expo.out" }, ${afterWords.toFixed(2)});`);
  if (text.sub)
    jsLines.push(
      `tl.fromTo("#${prefix}-sub", { opacity:0, y:10 }, { opacity:1, y:0, duration:0.40, ease:"power2.out" }, ${(afterWords + 0.15).toFixed(2)});`
    );
  jsLines.push(`tl.to("#${prefix}i", { scale:1.06, filter:"blur(16px)", opacity:0, duration:0.42, ease:"power2.in" }, ${(start + dur - 0.42).toFixed(2)});`);

  return { html, js: jsLines.join("\n      ") };
}

function renderApp(beat, prefix, start, dur, idx) {
  const isMobile = beat.viewport === "mobile";
  const pushIn = beat.pushIn || {};
  const origin = pushIn.origin || "50% 50%";
  const z0 = pushIn.from ?? 1.03;
  const z1 = pushIn.to ?? 1.16;
  const still = beat.still || `assets/${beat.id}.png`;
  const callout = beat.callout;
  const side = callout?.side === "right" ? "right" : "left";
  // Alternate vertical dock so consecutive callouts don't stack the same spot.
  const dockTop = idx % 2 === 1;

  const calloutHtml = callout
    ? `
          <div id="${prefix}-callout" class="callout${side === "right" ? " right" : ""}" style="${side === "right" ? "right:90px;" : "left:90px;"}${dockTop ? "top:130px;" : "bottom:110px;"}text-align:${side === "right" ? "right" : "left"};">
            <div class="k">${escapeHtml(callout.kicker || "")}</div><div class="h">${(callout.headline || "").split("\n").map(escapeHtml).join("<br/>")}</div><div class="s">${escapeHtml(callout.sub || "")}</div>
          </div>`
    : "";

  let html, js;

  if (isMobile) {
    const vp = config.viewports?.mobile || { width: 440, height: 900 };
    const screenW = 470, screenH = 982; // .phone-screen interior after padding (498-2*14, 1010-2*14)
    const scaleX = screenW / vp.width, scaleY = screenH / vp.height;
    const highlightHtml = beat.highlight
      ? `<div id="${prefix}-fbox" class="fbox" style="left:${(beat.highlight.x * scaleX).toFixed(0)}px;top:${(beat.highlight.y * scaleY).toFixed(0)}px;width:${(beat.highlight.w * scaleX).toFixed(0)}px;height:${(beat.highlight.h * scaleY).toFixed(0)}px;">${beat.highlight.label ? `<div class="fbox-name">${escapeHtml(beat.highlight.label)}</div>` : ""}</div>`
      : "";
    html = `
      <div id="${prefix}" class="scene clip" data-start="${start.toFixed(2)}" data-duration="${dur.toFixed(2)}" data-track-index="${idx}" style="z-index:${idx};">
        <div id="${prefix}i" style="position:absolute;inset:0;opacity:0;">
          <div id="${prefix}-glow" style="position:absolute;top:50%;left:50%;width:1100px;height:1100px;margin:-550px 0 0 -550px;background:radial-gradient(circle,color-mix(in srgb, var(--accent) 13%, transparent) 0%,transparent 60%);pointer-events:none;"></div>
          <div id="${prefix}-phone" class="phone"><div class="phone-screen"><img src="${escapeHtml(still)}" />${highlightHtml}</div></div>${calloutHtml}
        </div>
      </div>`;

    const jsLines = [];
    jsLines.push(`tl.fromTo("#${prefix}i", { opacity:0, filter:"blur(16px)" }, { opacity:1, filter:"blur(0px)", duration:0.5, ease:"power2.out" }, ${start.toFixed(2)});`);
    jsLines.push(`tl.fromTo("#${prefix}-glow", { scale:0.7, opacity:0 }, { scale:1, opacity:1, duration:0.9, ease:"power2.out" }, ${(start + 0.05).toFixed(2)});`);
    jsLines.push(`tl.fromTo("#${prefix}-phone", { scale:0.86, y:30, opacity:0 }, { scale:1, y:0, opacity:1, duration:0.6, ease:"back.out(1.3)" }, ${(start + 0.15).toFixed(2)});`);
    jsLines.push(`tl.to("#${prefix}-phone", { scale:1.06, duration:${(dur - 0.7).toFixed(2)}, ease:"power1.inOut" }, ${(start + 0.7).toFixed(2)});`);
    if (beat.highlight) jsLines.push(`fbox("${prefix}-fbox", ${(start + 0.9).toFixed(2)});`);
    if (callout) jsLines.push(`callout("${prefix}-callout", ${(start + 1.1).toFixed(2)}, ${side === "left" ? -40 : 40});`);
    jsLines.push(`tl.to("#${prefix}i", { filter:"blur(16px)", opacity:0, duration:0.42, ease:"power2.in" }, ${(start + dur - 0.42).toFixed(2)});`);
    js = jsLines.join("\n      ");
  } else {
    const highlightHtml = beat.highlight
      ? `<div id="${prefix}-fbox" class="fbox" style="left:${beat.highlight.x}px;top:${beat.highlight.y}px;width:${beat.highlight.w}px;height:${beat.highlight.h}px;">${beat.highlight.label ? `<div class="fbox-name">${escapeHtml(beat.highlight.label)}</div>` : ""}</div>`
      : "";
    html = `
      <div id="${prefix}" class="scene clip" data-start="${start.toFixed(2)}" data-duration="${dur.toFixed(2)}" data-track-index="${idx}" style="z-index:${idx};">
        <div id="${prefix}i" style="position:absolute;inset:0;opacity:0;">
          <div id="${prefix}-shot" class="shot" style="transform-origin:${origin};">
            <img src="${escapeHtml(still)}" />${highlightHtml}
          </div>
          <div id="${prefix}-dim" class="dim" style="background:radial-gradient(ellipse 700px 380px at ${origin}, transparent 40%, color-mix(in srgb, var(--bg) 74%, transparent) 78%);"></div>${calloutHtml}
        </div>
      </div>`;

    const jsLines = [];
    jsLines.push(`appScene("${prefix}", ${start.toFixed(2)}, ${dur.toFixed(2)}, { z0:${z0}, z1:${z1} });`);
    if (beat.highlight) {
      const at = start + 0.9;
      jsLines.push(`fbox("${prefix}-fbox", ${at.toFixed(2)});`);
      jsLines.push(
        `tl.to("#${prefix}-fbox", { boxShadow:"0 0 42px color-mix(in srgb, var(--accent) 70%, transparent), inset 0 0 40px color-mix(in srgb, var(--accent) 12%, transparent)", duration:0.8, ease:"sine.inOut", yoyo:true, repeat:2, overwrite:"auto" }, ${(at + 0.75).toFixed(2)});`
      );
    }
    if (callout) jsLines.push(`callout("${prefix}-callout", ${(start + 1.1).toFixed(2)}, ${side === "left" ? -40 : 40});`);
    js = jsLines.join("\n      ");
  }

  return { html, js };
}

function renderCta(beat, prefix, start, dur, idx) {
  const text = beat.text || {};
  const lines = text.lines || [];

  const lineDivs = lines
    .map((line, i) => {
      const wholeLineAccent = i > 0 && !/\*/.test(line);
      return `<div id="${prefix}-h${i + 1}" class="t-hero" style="font-size:96px;text-align:center;position:relative;z-index:2;${wholeLineAccent ? "color:var(--accent);" : ""}">${inlineAccentHtml(line)}</div>`;
    })
    .join("\n          ");

  const html = `
      <div id="${prefix}" class="scene clip" data-start="${start.toFixed(2)}" data-duration="${dur.toFixed(2)}" data-track-index="${idx}" style="z-index:${idx};">
        <div id="${prefix}i" style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:26px;opacity:0;">
          <div id="${prefix}-glow" style="position:absolute;left:calc(50% - 650px);top:calc(50% - 650px);width:1300px;height:1300px;background:radial-gradient(circle,color-mix(in srgb, var(--accent) 15%, transparent) 0%,transparent 60%);pointer-events:none;"></div>
          <div id="${prefix}-ring" style="position:absolute;left:calc(50% - 420px);top:calc(50% - 420px);width:840px;height:840px;border:1px solid color-mix(in srgb, var(--accent) 10%, transparent);border-radius:50%;pointer-events:none;"></div>
          ${text.kicker ? `<div id="${prefix}-logo" class="t-label" style="font-size:32px;position:relative;z-index:2;">${escapeHtml(text.kicker)}</div>` : ""}
          ${lineDivs}
          <div id="${prefix}-div" style="width:150px;height:4px;background:var(--accent);border-radius:2px;position:relative;z-index:2;"></div>
          ${text.url ? `<div id="${prefix}-url" class="t-sub" style="color:var(--accent);font-size:46px;letter-spacing:0.05em;position:relative;z-index:2;">${escapeHtml(text.url)}</div>` : ""}
          <div id="${prefix}-fade" style="position:absolute;inset:0;background:#000;opacity:0;pointer-events:none;z-index:10;"></div>
        </div>
      </div>`;

  const jsLines = [];
  jsLines.push(`tl.fromTo("#${prefix}i", { opacity:0, filter:"blur(16px)" }, { opacity:1, filter:"blur(0px)", duration:0.5, ease:"power2.out" }, ${start.toFixed(2)});`);
  jsLines.push(`tl.fromTo("#${prefix}-glow", { scale:0.6, opacity:0 }, { scale:1, opacity:1, duration:1.0, ease:"power2.out" }, ${(start + 0.1).toFixed(2)});`);
  jsLines.push(`tl.fromTo("#${prefix}-ring", { scale:0.5, opacity:0 }, { scale:1, opacity:1, duration:1.0, ease:"power2.out" }, ${(start + 0.1).toFixed(2)});`);
  let at = start + 0.2;
  if (text.kicker) {
    jsLines.push(`tl.fromTo("#${prefix}-logo", { scale:0.86, opacity:0 }, { scale:1, opacity:1, duration:0.42, ease:"back.out(1.4)" }, ${at.toFixed(2)});`);
    at += 0.2;
  }
  lines.forEach((_, i) => {
    jsLines.push(`tl.fromTo("#${prefix}-h${i + 1}", { opacity:0, y:40 }, { opacity:1, y:0, duration:0.5, ease:"expo.out" }, ${at.toFixed(2)});`);
    at += 0.32;
  });
  jsLines.push(`tl.fromTo("#${prefix}-div", { scaleX:0 }, { scaleX:1, duration:0.4, ease:"expo.out" }, ${(at + 0.05).toFixed(2)});`);
  if (text.url) jsLines.push(`tl.fromTo("#${prefix}-url", { opacity:0, letterSpacing:"0.2em" }, { opacity:1, letterSpacing:"0.05em", duration:0.5, ease:"power2.out" }, ${(at + 0.2).toFixed(2)});`);
  jsLines.push(`tl.to("#${prefix}-fade", { opacity:1, duration:0.7, ease:"power2.in" }, ${(start + dur - 0.7).toFixed(2)});`);

  return { html, js: jsLines.join("\n      ") };
}

// ── drive generation ─────────────────────────────────────────────────────────

const starts = computeStarts(beats);
const scenesHtml = [];
const timelineJs = [];

beats.forEach((beat, i) => {
  const prefix = slugId(beat.id || `beat-${i}`);
  const start = starts[i];
  const dur = beat.durationSec ?? 4.6;
  const idx = i + 1;

  let out;
  if (beat.kind === "intro") out = renderIntro(beat, prefix, start, dur, idx);
  else if (beat.kind === "cta") out = renderCta(beat, prefix, start, dur, idx);
  else out = renderApp(beat, prefix, start, dur, idx);

  scenesHtml.push(out.html);
  timelineJs.push(`      // ── ${prefix} (${beat.kind}) ──`);
  timelineJs.push("      " + out.js);
});

const totalDuration = starts[starts.length - 1] + (beats[beats.length - 1].durationSec ?? 4.6);
const compId = config.slug || "promo";

// ── stitch into the template ─────────────────────────────────────────────────

template = template.replace("<!-- @FONTS@ -->", googleFontsLink(tokens));
template = template.replace(/:root\s*{[^}]*}/, () => `:root {
        --bg: ${tokens.bg};
        --accent: ${tokens.accent};
        --fg: ${tokens.fg};
        --muted: ${tokens.muted};
        --font-hero: ${tokens.fontHero};
        --font-mono: ${tokens.fontMono};
        --radius: ${tokens.radius};
      }`);
template = template.replace("<!-- @SCENES@ -->", scenesHtml.join("\n"));
template = template.replace("<!-- @TIMELINE@ -->", timelineJs.join("\n"));
template = template.replaceAll("@COMPID@", compId);
template = template.replaceAll("@DURATION@", totalDuration.toFixed(2));

writeFileSync(outPath, template);
console.log(`index.html written — ${beats.length} scenes, ${totalDuration.toFixed(1)}s total (composition id "${compId}").`);
