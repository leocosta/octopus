// Muxes assets/music.mp3 onto the latest silent render, and (with --reframe)
// derives a 9:16 blurred-letterbox cut from the scored master. All paths
// come from config.slug — nothing app-specific is hardcoded.
//
// Usage:
//   node engine/mux.mjs              → renders/<slug>-final.mp4
//   node engine/mux.mjs --reframe     → renders/<slug>-9x16.mp4 (requires
//                                       renders/<slug>-final.mp4 already built)
import { existsSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import config from "../promo.config.mjs";

const slug = config.slug || "promo";
const rendersDir = fileURLToPath(new URL("../renders/", import.meta.url));
const assetsDir = fileURLToPath(new URL("../assets/", import.meta.url));

const args = process.argv.slice(2);
const reframeOnly = args.includes("--reframe");

function ffprobe(field, path) {
  return execFileSync(
    "ffprobe",
    ["-v", "error", "-select_streams", "v:0", "-show_entries", field, "-of", "default=noprint_wrappers=1:nokey=1", path],
    { encoding: "utf8" }
  ).trim();
}

function probeSummary(path) {
  const duration = parseFloat(execFileSync(
    "ffprobe",
    ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", path],
    { encoding: "utf8" }
  ).trim());
  let dims = "unknown";
  try {
    const w = ffprobe("stream=width", path);
    const h = ffprobe("stream=height", path);
    dims = `${w}x${h}`;
  } catch {
    // no video stream (shouldn't happen for our outputs)
  }
  return { duration, dims };
}

function hasAudioStream(path) {
  try {
    const out = execFileSync(
      "ffprobe",
      ["-v", "error", "-select_streams", "a", "-show_entries", "stream=index", "-of", "csv=p=0", path],
      { encoding: "utf8" }
    ).trim();
    return out.length > 0;
  } catch {
    return false;
  }
}

function findLatestSilentRender() {
  if (!existsSync(rendersDir)) {
    console.error(`mux: renders/ directory not found (expected ${rendersDir}). Run \`npx hyperframes render\` first.`);
    process.exit(1);
  }
  const re = new RegExp(`^${slug.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}_.*\\.mp4$`);
  const candidates = readdirSync(rendersDir)
    .filter((f) => re.test(f))
    .filter((f) => !/trilha|final/i.test(f))
    .map((f) => ({ f, mtime: statSync(rendersDir + f).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime);
  if (!candidates.length) {
    console.error(`mux: no silent render matching "${slug}_*.mp4" found in renders/ (excluding *trilha*/*final*).`);
    process.exit(1);
  }
  return rendersDir + candidates[0].f;
}

function runDefaultMux() {
  const silent = findLatestSilentRender();
  const musicPath = assetsDir + "music.mp3";
  const finalPath = rendersDir + `${slug}-final.mp4`;

  if (!existsSync(musicPath)) {
    console.error(`mux: ${musicPath} not found. Run engine/fetch-music.mjs first.`);
    process.exit(1);
  }

  const { duration: videoDuration } = probeSummary(silent);
  const fadeOutStart = Math.max(0, videoDuration - 3.2);
  const startOffset = config.music?.startOffsetSec ?? 0;

  console.log(`mux: silent=${silent}`);
  console.log(`mux: video duration=${videoDuration.toFixed(2)}s, music start offset=${startOffset}s, fade out @ ${fadeOutStart.toFixed(2)}s`);

  const audioFilter =
    `atrim=start=${startOffset},asetpts=PTS-STARTPTS,` +
    `loudnorm=I=-16:TP=-1.5:LRA=11,` +
    `afade=t=in:st=0:d=0.7,` +
    `afade=t=out:st=${fadeOutStart.toFixed(2)}:d=3.2`;

  execFileSync(
    "ffmpeg",
    [
      "-y",
      "-i", silent,
      "-i", musicPath,
      "-filter:a", audioFilter,
      "-map", "0:v:0",
      "-map", "1:a:0",
      "-c:v", "copy",
      "-c:a", "aac",
      "-b:a", "192k",
      "-shortest",
      finalPath,
    ],
    { stdio: "inherit" }
  );

  const summary = probeSummary(finalPath);
  console.log(`mux: wrote ${finalPath} — ${summary.dims}, ${summary.duration.toFixed(2)}s`);
  return finalPath;
}

function runReframe() {
  const finalPath = rendersDir + `${slug}-final.mp4`;
  const outPath = rendersDir + `${slug}-9x16.mp4`;

  if (!existsSync(finalPath)) {
    console.error(`mux --reframe: ${finalPath} not found. Run \`node engine/mux.mjs\` (without --reframe) first.`);
    process.exit(1);
  }

  const audioPresent = hasAudioStream(finalPath);
  const filterComplex =
    "[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=40:1,eq=brightness=-0.25[bg];" +
    "[0:v]scale=1080:-2[fg];" +
    "[bg][fg]overlay=(W-w)/2:(H-h)/2";

  const ffmpegArgs = ["-y", "-i", finalPath, "-filter_complex", filterComplex];
  if (audioPresent) {
    ffmpegArgs.push("-map", "0:a:0", "-c:a", "aac", "-b:a", "192k");
  } else {
    ffmpegArgs.push("-an");
  }
  ffmpegArgs.push("-c:v", "libx264", "-pix_fmt", "yuv420p", outPath);

  execFileSync("ffmpeg", ffmpegArgs, { stdio: "inherit" });

  const summary = probeSummary(outPath);
  console.log(`mux --reframe: wrote ${outPath} — ${summary.dims}, ${summary.duration.toFixed(2)}s (audio: ${audioPresent ? "copied" : "none"})`);
  return outPath;
}

if (reframeOnly) {
  runReframe();
} else {
  runDefaultMux();
}
