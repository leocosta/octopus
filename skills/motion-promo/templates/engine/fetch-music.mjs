// Ensures assets/music.mp3 exists. Priority:
//   1. assets/music.mp3 already present → use it, do nothing.
//   2. config.music.source is a local path or URL (not "auto") → fetch/copy it.
//   3. config.music.source === "auto" → try a short list of known-good CC-BY
//      tracks (incompetech) and use the first that validates.
// CC-BY requires attribution (see SKILL.md Rules → Music licensing); this
// script writes assets/music.attribution.txt whenever it falls back to a
// CC-BY track.
import { existsSync, writeFileSync, copyFileSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import config from "../promo.config.mjs";

const outPath = fileURLToPath(new URL("../assets/music.mp3", import.meta.url));
const attributionPath = fileURLToPath(new URL("../assets/music.attribution.txt", import.meta.url));

const MIN_BYTES = 500 * 1024; // 500 KB — floor to reject truncated/error-page downloads

// A handful of known-good, direct CC-BY mp3 URLs (Kevin MacLeod / incompetech).
// Tried in order; first that downloads + validates wins.
const FALLBACK_TRACKS = [
  {
    url: "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Inspired.mp3",
    title: "Inspired",
    author: "Kevin MacLeod",
    license: "CC BY 4.0",
    licenseUrl: "https://creativecommons.org/licenses/by/4.0/",
    source: "https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1200079",
  },
  {
    url: "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Upbeat%20Forever.mp3",
    title: "Upbeat Forever",
    author: "Kevin MacLeod",
    license: "CC BY 4.0",
    licenseUrl: "https://creativecommons.org/licenses/by/4.0/",
    source: "https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1300021",
  },
  {
    url: "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Deliberate%20Thought.mp3",
    title: "Deliberate Thought",
    author: "Kevin MacLeod",
    license: "CC BY 4.0",
    licenseUrl: "https://creativecommons.org/licenses/by/4.0/",
    source: "https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1200060",
  },
];

function looksLikeMp3(buf) {
  if (buf.length < 4) return false;
  if (buf[0] === 0x49 && buf[1] === 0x44 && buf[2] === 0x33) return true; // "ID3"
  // MPEG frame sync: 11 bits set (0xFFE0) with a valid MPEG version/layer nibble
  if (buf[0] === 0xff && (buf[1] & 0xe0) === 0xe0) return true;
  return false;
}

function fileMagicIsAudio(path) {
  try {
    const out = execFileSync("file", ["--mime-type", "-b", path], { encoding: "utf8" }).trim();
    return out.startsWith("audio/");
  } catch {
    return null; // `file` unavailable — caller falls back to magic-byte check
  }
}

async function validateAndSave(buf, meta) {
  if (buf.length < MIN_BYTES) {
    console.warn(`  ✗ ${meta.title || meta.url}: only ${(buf.length / 1024).toFixed(0)} KB, rejecting.`);
    return false;
  }
  if (!looksLikeMp3(buf)) {
    console.warn(`  ✗ ${meta.title || meta.url}: doesn't look like mp3 (bad magic bytes), rejecting.`);
    return false;
  }
  writeFileSync(outPath, buf);
  const mime = fileMagicIsAudio(outPath);
  if (mime === false) {
    console.warn(`  ✗ ${meta.title || meta.url}: \`file\` says not audio/*, rejecting.`);
    return false;
  }
  console.log(`  ✓ saved ${(buf.length / 1024 / 1024).toFixed(2)} MB → assets/music.mp3`);
  return true;
}

async function main() {
  if (existsSync(outPath)) {
    console.log("fetch-music: assets/music.mp3 already present — leaving it as-is.");
    return;
  }

  const source = config.music?.source;

  if (source && source !== "auto") {
    console.log(`fetch-music: using configured source "${source}".`);
    if (/^https?:\/\//.test(source)) {
      const res = await fetch(source);
      if (!res.ok) {
        console.error(`fetch-music: configured source returned HTTP ${res.status}.`);
        process.exit(1);
      }
      const buf = Buffer.from(await res.arrayBuffer());
      if (!(await validateAndSave(buf, { url: source }))) process.exit(1);
    } else {
      if (!existsSync(source)) {
        console.error(`fetch-music: configured local path "${source}" does not exist.`);
        process.exit(1);
      }
      copyFileSync(source, outPath);
      const { size } = statSync(outPath);
      console.log(`fetch-music: copied local track (${(size / 1024 / 1024).toFixed(2)} MB) → assets/music.mp3.`);
    }
    // A project-provided track's licensing is the project's responsibility —
    // no attribution file is written here unless attributionRequired is set
    // and the project didn't already document it.
    return;
  }

  console.log("fetch-music: source=auto, trying CC-BY fallback tracks…");
  for (const track of FALLBACK_TRACKS) {
    console.log(`  trying "${track.title}" (${track.url})`);
    try {
      const res = await fetch(track.url);
      if (!res.ok) {
        console.warn(`  ✗ HTTP ${res.status}`);
        continue;
      }
      const buf = Buffer.from(await res.arrayBuffer());
      if (await validateAndSave(buf, track)) {
        writeFileSync(
          attributionPath,
          `"${track.title}" by ${track.author} (${track.source})\nLicensed under ${track.license} — ${track.licenseUrl}\n\nRequired credit line for the landing page / video description:\n"${track.title}" by ${track.author} (incompetech.com) — licensed under ${track.license}.\n`
        );
        console.log(`fetch-music: attribution recorded → assets/music.attribution.txt (${track.license}).`);
        return;
      }
    } catch (err) {
      console.warn(`  ✗ ${err.message}`);
    }
  }

  console.error(
    "fetch-music: no fallback track could be fetched/validated (network egress blocked, or incompetech unreachable).\n" +
      "Drop a track yourself at assets/music.mp3 (or set config.music.source to a local path/URL) and re-run."
  );
  process.exit(1);
}

await main();
