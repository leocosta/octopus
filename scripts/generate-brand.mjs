#!/usr/bin/env node
// Generates Octopus brand assets (logo + cover, light + dark) via OpenAI gpt-image-1.
// Reads OpenAI key from ~/Projects/tatame/api/.env (OpenAi__ApiKey).

import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const ENV_FILE = path.join(os.homedir(), "Projects/tatame/api/.env");
const OUT_DIR = path.join(os.homedir(), "Projects/octopus/images");

function readEnvKey(file, key) {
  const txt = fs.readFileSync(file, "utf8");
  const m = txt.match(new RegExp(`^${key}=(.+)$`, "m"));
  if (!m) throw new Error(`${key} not found in ${file}`);
  return m[1].trim();
}

const apiKey = readEnvKey(ENV_FILE, "OpenAi__ApiKey");

const PROMPT_BASE = `
Brand mark for "Octopus" — a developer tool that centralizes AI coding agent configuration across many repositories.
Style: modern, minimalist, vector-like, flat with subtle gradients, crisp clean lines, professional tech-brand identity (think Vercel, Linear, Cursor aesthetic).
Subject: a highly stylized geometric octopus head viewed from the front, with eight smooth curved tentacles radiating outward symmetrically. Each tentacle terminates in a small glowing node, representing repositories/agents being orchestrated from a single source.
NO realistic 3D render, NO photo-realism, NO third-party logos, NO chrome/metallic textures, NO text or letters in the image.
Composition: centered, symmetrical, generous negative space, geometric precision, scalable to favicon size.
`.trim();

const VARIANTS = [
  {
    name: "logo-dark",
    size: "1024x1024",
    extra:
      "Color palette: bright electric cyan (#22D3EE), vivid blue (#3B82F6), soft violet accents. Glowing neon outlines suited for DARK backgrounds. The mark itself should be luminous and readable on black.",
  },
  {
    name: "logo-light",
    size: "1024x1024",
    extra:
      "Color palette: deep indigo (#1E3A8A), cobalt blue (#1D4ED8), teal accents (#0E7490). Solid, saturated strokes suited for LIGHT backgrounds. The mark should have strong contrast on white, no glow effects.",
  },
  {
    name: "cover-dark",
    size: "1536x1024",
    extra:
      "Wider hero composition: the octopus mark on the LEFT half, tentacles flowing horizontally to the RIGHT toward a constellation of small glowing nodes interconnected by faint circuit lines. Color palette: electric cyan, vivid blue, neon glow. Suited for DARK backgrounds. Plenty of empty space on the right for overlay text.",
  },
  {
    name: "cover-light",
    size: "1536x1024",
    extra:
      "Wider hero composition: the octopus mark on the LEFT half, tentacles flowing horizontally to the RIGHT toward a constellation of small nodes interconnected by faint circuit lines. Color palette: deep indigo, cobalt, teal. Solid strokes, no glow, suited for LIGHT backgrounds. Plenty of empty space on the right for overlay text.",
  },
];

async function generate({ name, size, extra }) {
  const prompt = `${PROMPT_BASE}\n\n${extra}`;
  console.log(`[${name}] requesting ${size}...`);
  const res = await fetch("https://api.openai.com/v1/images/generations", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-image-1",
      prompt,
      size,
      background: "transparent",
      n: 1,
      quality: "high",
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`OpenAI error for ${name}: ${res.status} ${err}`);
  }
  const json = await res.json();
  const b64 = json.data[0].b64_json;
  const outPath = path.join(OUT_DIR, `${name}.png`);
  fs.writeFileSync(outPath, Buffer.from(b64, "base64"));
  console.log(`[${name}] saved -> ${outPath}`);
}

for (const v of VARIANTS) {
  try {
    await generate(v);
  } catch (e) {
    console.error(e.message);
  }
}
