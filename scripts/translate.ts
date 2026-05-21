#!/usr/bin/env bun
// Batch translator for docs/site → docs/site/pt-br.
//
// Modes:
//   bun scripts/translate.ts                # process queue (~/.octopus/translation-queue.txt)
//   bun scripts/translate.ts --all          # retranslate every page (bootstrap or refresh)
//   bun scripts/translate.ts --page <rel>   # retranslate one page (path relative to docs/site/)
//   bun scripts/translate.ts --dry-run      # list what would run, no LLM calls
//   bun scripts/translate.ts --model <name> # override Claude Code model (default: inherits)
//
// Each page is translated by piping the EN source through `claude -p` in
// headless mode. Output is written under docs/site/pt-br/<rel> with
// source_hash and needs_retranslation: false in the frontmatter.

import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import {
  readFileSync,
  writeFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  statSync,
} from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { homedir } from "node:os";

const ROOT = resolve(import.meta.dir, "..");
const SITE_DIR = join(ROOT, "docs/site");
const PTBR_DIR = join(SITE_DIR, "pt-br");
const GLOSSARY_PATH = join(SITE_DIR, ".translation-glossary.md");
const QUEUE_PATH = join(homedir(), ".octopus", "translation-queue.txt");

type Args = {
  all: boolean;
  page: string | null;
  dryRun: boolean;
  model: string | null;
};

function parseArgs(argv: string[]): Args {
  const out: Args = { all: false, page: null, dryRun: false, model: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--all") out.all = true;
    else if (a === "--dry-run") out.dryRun = true;
    else if (a === "--page") out.page = argv[++i] ?? null;
    else if (a === "--model") out.model = argv[++i] ?? null;
  }
  return out;
}

function sha256(filePath: string): string {
  const h = createHash("sha256");
  h.update(readFileSync(filePath));
  return h.digest("hex");
}

function walkMarkdown(dir: string, out: string[] = []): string[] {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    const st = statSync(full);
    if (name.startsWith(".")) continue; // skip dotfiles (e.g., .translation-glossary.md)
    if (st.isDirectory()) walkMarkdown(full, out);
    else if (name.endsWith(".md") || name.endsWith(".mdx")) out.push(full);
  }
  return out;
}

function splitFrontmatter(text: string): {
  fmText: string;
  body: string;
  hasFm: boolean;
} {
  const m = text.match(/^---\n([\s\S]*?)\n---\n?/);
  if (!m) return { fmText: "", body: text, hasFm: false };
  return { fmText: m[1], body: text.slice(m[0].length), hasFm: true };
}

function readGlossary(): string {
  if (!existsSync(GLOSSARY_PATH)) return "";
  return readFileSync(GLOSSARY_PATH, "utf8");
}

// Segment-based translation: split the EN body into alternating prose and
// code-fence blocks. Only prose segments are sent to the LLM. Code blocks
// (including their content and fences) are restored byte-identically. This
// is the only reliable way to keep ``` fences and embedded JSX intact when
// translating technical docs with an LLM.

type Segment =
  | { kind: "prose"; text: string }
  | { kind: "code"; text: string };

function splitProseAndCode(body: string): Segment[] {
  const segments: Segment[] = [];
  const lines = body.split("\n");
  let i = 0;
  let proseBuf: string[] = [];

  const flushProse = () => {
    if (proseBuf.length > 0) {
      segments.push({ kind: "prose", text: proseBuf.join("\n") });
      proseBuf = [];
    }
  };

  while (i < lines.length) {
    const line = lines[i];
    const fenceMatch = line.match(/^(\s*)(```+|~~~+)(.*)$/);
    if (fenceMatch) {
      flushProse();
      const indent = fenceMatch[1];
      const fence = fenceMatch[2];
      const codeBuf: string[] = [line];
      i++;
      // Consume until a closing fence at same indent + same fence char.
      while (i < lines.length) {
        codeBuf.push(lines[i]);
        const closeMatch = lines[i].match(
          new RegExp(`^${indent}${fence}\\s*$`),
        );
        i++;
        if (closeMatch) break;
      }
      segments.push({ kind: "code", text: codeBuf.join("\n") });
      continue;
    }
    proseBuf.push(line);
    i++;
  }
  flushProse();
  return segments;
}

function buildSingleCallPrompt(content: string, glossary: string): string {
  return `You are a professional technical translator. Translate the following Octopus documentation file from English into Brazilian Portuguese (pt-BR).

Hard rules — violations make the output unusable:
1. Preserve all Markdown/MDX syntax exactly: frontmatter delimiters (---), headings, lists, blockquotes, tables, links, inline code (\`like-this\`), JSX tags, HTML, component imports.
2. The text contains sentinel tokens of the form <<<CODE_BLOCK_N>>> where N is an integer. Preserve every sentinel EXACTLY as written, on its own line, in the same order. Do not translate, alter, or remove any sentinel.
3. In the frontmatter, translate only the values of \`title\` and \`description\`. Keep every other key and value byte-identical (sidebar, order, tableOfContents, template, etc.). Never invent new keys.
4. Glossary terms below must stay in English exactly as written. They appear in body, headings, links, and frontmatter values alike.
5. Do not translate: code identifiers, CLI flags, file paths, URLs, environment variable names, component or prop names, or anything inside backtick-delimited inline code.
6. Use informal-but-professional pt-BR register ("você", not "tu"). Avoid Brazilian regionalisms. For widely-used dev anglicisms (deploy, build, commit, merge, pull request, branch, prompt, repo, workflow), prefer the English form.
7. Output ONLY the translated file content. No preamble, no commentary, no fence wrapping the whole output.

---GLOSSARY---
${glossary}

---SOURCE---
${content}`;
}

function buildProsePrompt(prose: string, glossary: string): string {
  return `You are a professional technical translator. Translate the following Markdown/MDX prose from English into Brazilian Portuguese (pt-BR).

Hard rules — violations make the output unusable:
1. Preserve all Markdown/MDX syntax exactly: headings, lists, blockquotes, tables, links, inline code (\`like-this\`), JSX tags, HTML, and component imports. Do not change the document structure.
2. Glossary terms below must stay in English exactly as written.
3. Do not translate: code identifiers, CLI flags, file paths, URLs, environment variable names, component or prop names, or anything inside backtick-delimited inline code.
4. Use informal-but-professional pt-BR register ("você", not "tu"). Avoid Brazilian regionalisms. For widely-used dev anglicisms (deploy, build, commit, merge, pull request, branch, prompt, repo, workflow), prefer the English form.
5. Output ONLY the translated prose. Same line count is preferred but not required. No preamble, no commentary, no fence wrapping the whole output.

---GLOSSARY---
${glossary}

---SOURCE---
${prose}`;
}

function buildFrontmatterPrompt(fm: string, glossary: string): string {
  return `Translate the values of \`title\` and \`description\` in the YAML frontmatter below from English to Brazilian Portuguese (pt-BR). Keep every other key and value byte-identical. Do not translate values that contain code identifiers, file paths, CLI flags, or URLs.

Glossary terms must stay in English exactly:
${glossary}

Output ONLY the rewritten frontmatter block contents — no leading \`---\`, no trailing \`---\`, no commentary.

---SOURCE---
${fm}`;
}

function invokeClaude(prompt: string, model: string | null): string {
  const args = ["-p", prompt];
  if (model) args.push("--model", model);
  const res = spawnSync("claude", args, {
    encoding: "utf8",
    maxBuffer: 50 * 1024 * 1024,
    timeout: 300_000,
  });
  if (res.error) throw res.error;
  if (res.status !== 0) {
    throw new Error(
      `claude exited ${res.status}: ${(res.stderr || "").slice(0, 500)}`,
    );
  }
  return (res.stdout || "").trim();
}

// Splice top-level scalar fields into a frontmatter block while preserving
// every other key (including nested YAML blocks like `sidebar:\n  order: 2`).
// For each field: if a top-level line `<key>:` exists, replace its full block
// (including any indented continuation lines) with `<key>: <value>`. Else
// append the new line at the end of the frontmatter block.
function setFrontmatterFields(
  output: string,
  fields: Record<string, string>,
): string {
  const { hasFm, fmText, body } = splitFrontmatter(output);
  if (!hasFm) {
    const fmLines = Object.entries(fields).map(([k, v]) => `${k}: ${v}`);
    return `---\n${fmLines.join("\n")}\n---\n${output}`;
  }

  let lines = fmText.split("\n");
  const isTopLevelKey = (line: string, key: string) =>
    line.match(new RegExp(`^${key}\\s*:`));

  for (const [key, value] of Object.entries(fields)) {
    let idx = -1;
    for (let i = 0; i < lines.length; i++) {
      if (isTopLevelKey(lines[i], key)) {
        idx = i;
        break;
      }
    }
    const replacement = `${key}: ${value}`;
    if (idx === -1) {
      lines.push(replacement);
    } else {
      // Drop any indented continuation lines belonging to this key.
      let end = idx + 1;
      while (end < lines.length && /^[ \t]/.test(lines[end])) end++;
      lines.splice(idx, end - idx, replacement);
    }
  }

  return `---\n${lines.join("\n")}\n---\n${body}`;
}

function ptbrPathFor(enAbs: string): string {
  const rel = relative(SITE_DIR, enAbs);
  return join(PTBR_DIR, rel);
}

function enPathFor(ptbrAbs: string): string {
  const rel = relative(PTBR_DIR, ptbrAbs);
  return join(SITE_DIR, rel);
}

function readQueue(): string[] {
  if (!existsSync(QUEUE_PATH)) return [];
  return readFileSync(QUEUE_PATH, "utf8")
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean);
}

function writeQueue(paths: string[]): void {
  if (paths.length === 0 && existsSync(QUEUE_PATH)) {
    writeFileSync(QUEUE_PATH, "");
    return;
  }
  mkdirSync(dirname(QUEUE_PATH), { recursive: true });
  writeFileSync(QUEUE_PATH, paths.join("\n") + (paths.length ? "\n" : ""));
}

function listEnPages(): string[] {
  // All EN markdown under docs/site/, excluding pt-br/.
  return walkMarkdown(SITE_DIR).filter(
    (p) => !p.startsWith(PTBR_DIR + "/") && p !== PTBR_DIR,
  );
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!existsSync(SITE_DIR)) {
    console.error(`docs/site/ not found at ${SITE_DIR}`);
    process.exit(1);
  }
  mkdirSync(PTBR_DIR, { recursive: true });

  let targets: string[] = []; // EN absolute paths to (re)translate

  if (args.page) {
    const enAbs = join(SITE_DIR, args.page);
    if (!existsSync(enAbs)) {
      console.error(`page not found: ${enAbs}`);
      process.exit(1);
    }
    targets = [enAbs];
  } else if (args.all) {
    targets = listEnPages();
  } else {
    // Queue mode: queue stores pt-BR paths; map back to EN.
    const queued = readQueue();
    for (const ptbr of queued) {
      const en = enPathFor(ptbr);
      if (existsSync(en)) targets.push(en);
    }
  }

  if (targets.length === 0) {
    console.log("nothing to translate");
    return;
  }

  console.log(
    `target pages: ${targets.length}${args.dryRun ? " (dry-run)" : ""}${
      args.model ? ` model=${args.model}` : ""
    }`,
  );

  if (args.dryRun) {
    for (const t of targets) console.log(`  ${relative(SITE_DIR, t)}`);
    return;
  }

  const glossary = readGlossary();
  let ok = 0;
  let fail = 0;
  const remainingQueue = new Set(readQueue());

  for (const enAbs of targets) {
    const rel = relative(SITE_DIR, enAbs);
    const ptbrAbs = ptbrPathFor(enAbs);
    process.stdout.write(`[${ok + fail + 1}/${targets.length}] ${rel} ... `);
    try {
      const enContent = readFileSync(enAbs, "utf8");
      const t0 = Date.now();

      // Replace fenced code blocks with sentinels before sending to the LLM,
      // then restore them byte-identically. This is the only reliable way to
      // keep ``` fences and embedded JSX intact across the LLM round-trip.
      const segments = splitProseAndCode(enContent);
      const codeBlocks: string[] = [];
      const stitched = segments
        .map((s) => {
          if (s.kind === "code") {
            const idx = codeBlocks.length;
            codeBlocks.push(s.text);
            return `<<<CODE_BLOCK_${idx}>>>`;
          }
          return s.text;
        })
        .join("\n");

      const prompt = buildSingleCallPrompt(stitched, glossary);
      let raw = invokeClaude(prompt, args.model);
      raw = raw.replace(/^```(?:\w+)?\n([\s\S]*?)\n```\s*$/m, "$1");

      // Restore code blocks. Fail loudly if a sentinel is missing.
      for (let i = 0; i < codeBlocks.length; i++) {
        const token = `<<<CODE_BLOCK_${i}>>>`;
        if (!raw.includes(token)) {
          throw new Error(
            `LLM dropped sentinel ${token} (page has ${codeBlocks.length} code blocks)`,
          );
        }
        raw = raw.replace(token, codeBlocks[i]);
      }

      const dt = ((Date.now() - t0) / 1000).toFixed(1);

      const sha = sha256(enAbs);
      const withMeta = setFrontmatterFields(raw, {
        source_hash: `"sha256:${sha}"`,
        needs_retranslation: "false",
      });

      mkdirSync(dirname(ptbrAbs), { recursive: true });
      writeFileSync(ptbrAbs, withMeta);
      remainingQueue.delete(ptbrAbs);
      ok++;
      console.log(`ok (${dt}s, ${codeBlocks.length} blocks)`);
    } catch (e: any) {
      fail++;
      console.log(`FAIL`);
      console.error(`    ${e?.message || e}`);
    }
  }

  writeQueue([...remainingQueue]);

  console.log(`\nsummary: ${ok} ok, ${fail} failed, ${targets.length} total`);
  if (fail > 0) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
