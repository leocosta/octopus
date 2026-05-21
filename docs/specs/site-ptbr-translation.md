# Spec: pt-BR Translation of the Public Site

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-05-20 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | TBD |

---

## 1. Summary

This spec describes a human-supervised, LLM-assisted workflow for translating
the Octopus public documentation site (`docs/site/`, 61 pages) into Brazilian
Portuguese. Translated content lives under `docs/site/pt-br/` and is published
alongside the English source on GitHub Pages via Astro Starlight. Staleness is
tracked through frontmatter hashes: a lightweight PostToolUse hook marks
pt-BR files as needing retranslation whenever their English counterpart is
edited inside Claude Code; a local batch script drives the actual LLM calls
using Claude Code CLI in headless mode. No LLM calls happen in CI.

---

## 2. Goals and Non-Goals

### Goals

1. Translate all 61 pages currently under `docs/site/` into pt-BR and publish
   them on GitHub Pages under a `/pt-br/` URL prefix.
2. Provide a language switcher (EN / PT-BR) in the Starlight header.
3. Show readers a visible staleness banner when a pt-BR page is outdated;
   fall back to the English source when no translation exists yet.
4. Automate staleness detection: any Claude Code Edit or Write to an English
   source file automatically marks its pt-BR counterpart as stale — no manual
   bookkeeping.
5. Keep the retranslation process a one-command local operation:
   `bun run translate`.

### Non-Goals

- Translating README, skills, rules, knowledge modules, or CHANGELOG.
- Running LLM calls in CI or during Astro's build.
- Generating translations on-the-fly at page-serve time (SSR).
- Supporting any language other than pt-BR.
- Automatically detecting and tracking English edits made outside Claude Code
  (e.g., direct git commits or editor saves without Claude Code). This is an
  accepted gap; maintainers can force-retranslate individual pages manually.
- Automated git-hook detection as a safety net for non-Claude-Code edits.

---

## 3. Architecture Overview

### 3.1 Data flow

```
Maintainer edits docs/site/<page>.mdx in Claude Code
         │
         ▼
[PostToolUse hook: mark-stale-translation.sh]
  - reads tool_input.file_path from stdin (JSON)
  - skips if path is under docs/site/pt-br/ (already translated)
  - skips if no pt-BR counterpart exists yet
  - computes SHA-256 of the English file
  - writes needs_retranslation: true + source_hash: <sha>
    into the frontmatter of docs/site/pt-br/<same-relative-path>
  - appends the pt-BR path to ~/.octopus/translation-queue.txt
  - exits 0 always (never blocks the Edit/Write)
         │
         ▼ (async, local, on maintainer request)
[bun run translate]  →  scripts/translate.ts
  - reads ~/.octopus/translation-queue.txt (or --all flag)
  - for each queued pt-BR file where needs_retranslation: true:
      1. reads the English source
      2. calls `claude -p "<prompt>" --model <model>` with file content
      3. writes the LLM output to docs/site/pt-br/<path>
      4. sets needs_retranslation: false, source_hash: <sha of en>
      5. removes entry from queue
  - reports per-page status to stdout
         │
         ▼
git add docs/site/pt-br/
git commit  (maintainer reviews diff, commits manually)
         │
         ▼
[GitHub Actions CI: bun run build]
  Astro builds both EN and pt-BR pages
  No LLM calls — all content already in repo
         │
         ▼
GitHub Pages: leocosta.github.io/octopus/
             leocosta.github.io/octopus/pt-br/
```

### 3.2 Staleness banner logic (runtime, client-side Astro component)

```
pt-BR page requested
        │
        ├─ needs_retranslation: true  →  render pt-BR + yellow banner
        │                                 "This translation may be outdated."
        │
        ├─ needs_retranslation: false  →  render pt-BR, no banner
        │
        └─ pt-BR file does not exist  →  render EN + blue banner
                                          "Not yet translated. Showing English."
```

---

## 4. Directory Layout

### Before

```
docs/site/
  get-started/
    what-is-octopus.mdx
    install.mdx
    quickstart.mdx
    mental-model.mdx
  skills/
    index.mdx
    implement.mdx
    debug.mdx
    ... (17 more)
  bundles/
    ... (6 files)
  commands/
    ... (11 files)
  hooks/
    ... (6 files)
  roles/
    ... (7 files)
  architecture/
    ... (5 files)
  404.md
```

### After

```
docs/site/
  get-started/              ← unchanged (English source, canonical)
  skills/                   ← unchanged
  ... (all existing dirs)
  pt-br/                    ← NEW: mirrors the English tree
    get-started/
      what-is-octopus.mdx
      install.mdx
      quickstart.mdx
      mental-model.mdx
    skills/
      index.mdx
      implement.mdx
      ...
    bundles/
    commands/
    hooks/
    roles/
    architecture/
    404.md
  .translation-glossary.md  ← NEW: terms that must not be translated

scripts/
  translate.ts              ← NEW: batch translation driver
  translate-one.sh          ← NEW: helper for single-page retranslation

hooks/post-tool-use/
  mark-stale-translation.sh ← NEW: PostToolUse hook
```

---

## 5. Frontmatter Schema

### 5.1 English source pages (no change)

English pages keep their existing frontmatter unchanged. No translation
metadata is added to them.

Example (`docs/site/get-started/install.mdx`):
```yaml
---
title: Installation
description: Install Octopus on macOS, Linux, or Windows with a single command.
sidebar:
  order: 2
---
```

### 5.2 pt-BR pages

pt-BR pages carry two additional frontmatter fields managed by the tooling.
All other frontmatter keys (title, description, sidebar) are translated
by the LLM along with the body.

```yaml
---
title: Instalação                          # translated by LLM
description: Instale o Octopus no macOS… # translated by LLM
sidebar:
  order: 2                                 # preserved as-is
source_hash: "sha256:<hex>"                # SHA-256 of the English source file
needs_retranslation: false                 # true = stale, set by hook
---
```

**Field invariants:**

| Field | Type | Set by | Cleared by |
|---|---|---|---|
| `source_hash` | string (`sha256:<64-hex>`) | hook (initial) + batch script (after retranslation) | never deleted |
| `needs_retranslation` | boolean | hook (sets `true`) | batch script (sets `false`) |

- The hook sets both fields when it first encounters an EN edit for a page
  that already has a pt-BR counterpart. If the pt-BR file does not yet exist,
  the hook does nothing (bootstrap creates it).
- The batch script always writes both fields after a successful translation.
- `source_hash` being absent means the page was never translated; the batch
  script treats it as needing translation.

---

## 6. Hook Design

### 6.1 Identity

| Attribute | Value |
|---|---|
| **File** | `hooks/post-tool-use/mark-stale-translation.sh` |
| **Event** | `PostToolUse` |
| **Matcher** | `Write\|Edit` |
| **ID** | `mark-stale-translation` |
| **Timeout** | `5000` ms |

Registration in `hooks/hooks.json` (append to the `PostToolUse` array):

```json
{
  "matcher": "Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "octopus/hooks/post-tool-use/mark-stale-translation.sh",
      "id": "mark-stale-translation",
      "timeout": 5000
    }
  ]
}
```

### 6.2 Input contract

Claude Code delivers a JSON object on stdin. The hook reads:

```json
{
  "tool_input": {
    "file_path": "/abs/path/to/docs/site/skills/implement.mdx"
  }
}
```

### 6.3 Behavior (pseudocode)

```bash
file_path = parse stdin → tool_input.file_path
exit 0 if file_path is empty or does not match "docs/site/**"
exit 0 if file_path contains "/pt-br/"   # guard: don't recurse on translated files
exit 0 if file_path is not *.md or *.mdx

relative = strip "docs/site/" prefix from file_path
ptbr_path = "docs/site/pt-br/" + relative

exit 0 if ptbr_path does not exist as a file  # page not yet translated; bootstrap will create it

sha = sha256sum(file_path)

update frontmatter of ptbr_path:
  set needs_retranslation: true
  set source_hash: "sha256:<sha>"

append ptbr_path to ~/.octopus/translation-queue.txt (idempotent: skip if already present)

exit 0
```

### 6.4 Idempotency

- Running the hook multiple times for the same file is safe: `needs_retranslation`
  stays `true` and `source_hash` is updated to the latest hash.
- The queue file deduplicates entries before appending.

### 6.5 Error handling

- The hook must never exit non-zero. Any failure (missing tools, parse error,
  read-only filesystem) is logged to stderr and the hook exits 0. This
  ensures a failing hook never blocks Claude Code's Edit or Write operation.

### 6.6 Implementation notes

- Parse frontmatter without a YAML library: use simple line-based sed/awk
  to replace `needs_retranslation:` and `source_hash:` values. This avoids
  dependencies on Python or Node inside the hook.
- Alternatively, a minimal Python one-liner is acceptable if Python 3 is
  guaranteed (it is on all target platforms).
- The hook does not call `claude` or any LLM. It is purely a file-mutation
  and queue-append operation.

---

## 7. Batch Script Design

### 7.1 Entry point

```
bun run translate                          # translate all queued stale pages
bun run translate -- --all                 # retranslate all pt-BR pages regardless of flag
bun run translate -- --page skills/implement.mdx  # retranslate one page
bun run translate -- --dry-run            # print what would be translated, no writes
```

Implemented as `scripts/translate.ts` (TypeScript, runs with Bun).

`package.json` addition:
```json
{
  "scripts": {
    "translate": "bun run scripts/translate.ts"
  }
}
```

### 7.2 Page discovery

```
--all flag:
  find docs/site/pt-br/**/*.{md,mdx}

default (queue mode):
  read ~/.octopus/translation-queue.txt
  filter to lines where the file exists AND needs_retranslation: true

--page <rel>:
  translate docs/site/pt-br/<rel> unconditionally
```

### 7.3 Per-page flow

```
for each ptbr_path in pages:
  1. read EN source:   en_path = ptbr_path.replace("docs/site/pt-br/", "docs/site/")
     abort page if en_path does not exist (log warning)

  2. read glossary:    docs/site/.translation-glossary.md
     (attached as context to every LLM call)

  3. build prompt:     see §7.4

  4. invoke LLM:       claude -p "<escaped prompt>" [--model <model>]
     capture stdout as translated_content
     abort page on non-zero exit (log error, leave needs_retranslation: true)

  5. write output:     write translated_content to ptbr_path
     update frontmatter: needs_retranslation: false, source_hash: sha256(en_path)

  6. remove ptbr_path from ~/.octopus/translation-queue.txt

  7. print:  "[translated] skills/implement.mdx" or "[error] ..."
```

### 7.4 Prompt template for `claude -p`

```
You are a technical translator. Translate the following Octopus documentation
page from English to Brazilian Portuguese (pt-BR).

Rules:
1. Preserve all MDX/Markdown syntax exactly: frontmatter delimiters (---),
   component imports, JSX tags, code fences, and code block contents.
2. Translate frontmatter fields: title, description. Preserve all other
   frontmatter keys and values unchanged (sidebar, order, source_hash,
   needs_retranslation, etc.).
3. Do NOT translate the following terms — keep them in English exactly as
   written: [insert glossary terms].
4. Do NOT translate: code identifiers, CLI flags, file paths, URLs,
   component names, prop names.
5. Use informal but professional pt-BR register. Avoid localisms.
6. Output ONLY the translated file content — no preamble, no commentary.

---GLOSSARY---
[contents of .translation-glossary.md]

---SOURCE---
[contents of en_path]
```

### 7.5 Error handling and retries

- A failed `claude -p` invocation (non-zero exit or empty output) leaves the
  pt-BR file unchanged and `needs_retranslation: true`.
- The queue entry is NOT removed on failure, so the next `bun run translate`
  will retry automatically.
- The script reports per-page status and exits with code 1 if any page failed.
- No automatic retry loop; maintainer reruns the command.

### 7.6 Idempotency

- Running `bun run translate` twice is safe: pages already at
  `needs_retranslation: false` with matching `source_hash` are skipped in
  queue mode.
- `--all` re-translates unconditionally; the maintainer is responsible for
  reviewing the diff before committing.

### 7.7 Glossary file

`docs/site/.translation-glossary.md` lists terms that must not be translated.
Initial recommended terms (extend as the project evolves):

```
- skill
- bundle
- hook
- agent
- plan
- role
- manifest
- PostToolUse / PreToolUse
- CLAUDE.md
- AGENTS.md
- slash command
- octopus (when referring to the tool)
```

The glossary is maintained manually by the maintainer and attached verbatim
to every LLM translation call.

---

## 8. Astro / Starlight Changes

### 8.1 Content collection

Starlight's `docsLoader()` auto-discovers content from
`site/src/content/docs/`. The pt-BR collection must live at
`site/src/content/docs/pt-br/` and be linked (or copied) from
`docs/site/pt-br/` at build time, consistent with how the English content is
currently linked from `docs/site/`.

> **Open question (build wiring):** Confirm whether `docs/site/` is
> symlinked into `site/src/content/docs/` or copied by a build step. Resolve
> this before wiring the pt-BR content directory.

### 8.2 Routing

Starlight generates routes from the content collection path. Pages under
`site/src/content/docs/pt-br/` will be served at:

```
/octopus/pt-br/get-started/install/
/octopus/pt-br/skills/implement/
...
```

No custom routing adapter is needed; Starlight's default file-based routing
handles this automatically.

### 8.3 Language switcher component

Add a `LanguageSwitcher` component to the Starlight header via the
`components` override in `astro.config.mjs`.

**Behavior:**

```
current URL: /octopus/skills/implement/
click "PT-BR" → navigate to /octopus/pt-br/skills/implement/

current URL: /octopus/pt-br/skills/implement/
click "EN" → navigate to /octopus/skills/implement/
```

**Pseudocode (component logic):**

```
currentPath = window.location.pathname
base = "/octopus"

if currentPath starts with base + "/pt-br/":
  enPath = currentPath.replace("/pt-br/", "/")
  ptbrPath = currentPath
  activeLocale = "pt-BR"
else:
  enPath = currentPath
  ptbrPath = currentPath.replace(base + "/", base + "/pt-br/")
  activeLocale = "EN"

render: <select> or two <a> links, one highlighted per activeLocale
        EN  →  href=enPath
        PT-BR  →  href=ptbrPath
```

**Switcher persistence (open question):** Whether to remember the user's
locale choice across navigations via `localStorage` or cookie is unresolved.
See §10.

### 8.4 Staleness banner component

A `TranslationBanner` component reads the `needs_retranslation` frontmatter
field from the current page and renders conditionally.

```
needs_retranslation: true
  → yellow banner: "Esta tradução pode estar desatualizada. Ver original em inglês."
    with a link to the EN counterpart.

no pt-BR file (EN page served as fallback)
  → blue banner: "Esta página ainda não foi traduzida. Exibindo conteúdo em inglês."
    [inferred: the fallback case requires a server-side or build-time redirect
     or a 404 handler that serves the EN page; see §8.5]

needs_retranslation: false (or field absent on EN pages)
  → no banner rendered
```

The component is injected via Starlight's `components.Banner` override slot.

### 8.5 Fallback for missing pt-BR pages

When a reader navigates to `/octopus/pt-br/<page>/` and no translated file
exists:

- Option A (preferred during bootstrap): Astro's 404 page catches the
  missing route. The 404 page is customized to detect `/pt-br/` in the path,
  redirect to the EN equivalent, and show the blue banner on the EN page.
- Option B: A catch-all `[...slug].astro` page under `src/pages/pt-br/`
  handles missing slugs, reads the EN counterpart, and renders it with the
  banner.

> **Implementation note:** Option A is simpler and requires no dynamic
> routing. The banner on the EN side requires the EN page to detect that it
> is being rendered as a fallback, which may need a query parameter or
> session state. Resolve before implementation.

### 8.6 `astro.config.mjs` changes (sketch)

```js
// Add to starlight() config:
components: {
  // Override Header to inject language switcher
  Header: './src/components/HeaderWithSwitcher.astro',
  // Override Banner to inject staleness notice
  Banner: './src/components/TranslationBanner.astro',
},
// Add pt-BR sidebar (mirrors EN sidebar, all labels translated)
// This is a separate sidebar config block for the pt-br locale.
```

Starlight's built-in i18n support (`locales` config key) is an alternative
to manual routing. Evaluate whether enabling it is simpler than the manual
`pt-br/` subdirectory approach, given that the English content must remain at
the repo root path (`/octopus/`, not `/octopus/en/`). The manual subdir
approach (Layout B from the interview) was chosen specifically to keep EN
URLs stable.

---

## 9. Bootstrap Migration Plan

The initial batch run translates all 61 English pages and creates the full
`docs/site/pt-br/` tree. The maintainer executes this once before opening
the feature PR.

### Step-by-step

1. **Create the glossary.**
   Write `docs/site/.translation-glossary.md` with the initial term list
   (see §7.7). Commit it separately.

2. **Scaffold the pt-BR directory tree.**
   ```bash
   find docs/site -name "*.mdx" -o -name "*.md" \
     | grep -v "/pt-br/" \
     | while read f; do
         rel="${f#docs/site/}"
         dest="docs/site/pt-br/$rel"
         mkdir -p "$(dirname "$dest")"
         # Copy frontmatter only as skeleton; translate.ts will fill body
         cp "$f" "$dest"
       done
   ```
   This creates skeleton files so the hook has targets to mark stale.
   Alternatively, `translate.ts --all` can create files from scratch if
   they do not exist.

3. **Run the batch translator.**
   ```bash
   bun run translate -- --all --dry-run   # verify page list and prompt
   bun run translate -- --all             # execute; monitor for errors
   ```
   Expected output: 61 lines of `[translated] <path>` or `[error] <path>`.
   Rerun for any pages that errored.

4. **Review the diff.**
   ```bash
   git diff --stat docs/site/pt-br/
   ```
   Spot-check 3–5 pages manually, especially those with heavy code blocks
   or JSX components. Verify glossary terms were preserved.

5. **Wire Astro.**
   Implement the content collection link, language switcher, and banner
   components (§8). Run `bun run build` locally to confirm no build errors.

6. **Register the hook.**
   Add the `mark-stale-translation` entry to `hooks/hooks.json`. Run one
   test edit of an English page inside Claude Code to verify the hook marks
   the pt-BR counterpart stale and appends to the queue.

7. **Commit and open PR.**
   ```
   feat(site): add pt-BR translation — 61 pages, language switcher, staleness hook
   ```
   The PR should include:
   - `docs/site/pt-br/**` (all 61 translated pages)
   - `docs/site/.translation-glossary.md`
   - `scripts/translate.ts`
   - `hooks/post-tool-use/mark-stale-translation.sh`
   - `hooks/hooks.json` (updated)
   - Astro component and config changes

8. **Post-merge.**
   GitHub Actions builds and deploys. Verify `/octopus/pt-br/get-started/install/`
   renders correctly and the switcher links EN ↔ PT-BR.

---

## 10. Open Questions

These questions were explicitly deferred during scoping. They must be resolved
before implementation begins or at the phase indicated.

| # | Question | Phase | Owner |
|---|---|---|---|
| OQ-1 | **Switcher persistence:** store the user's locale choice in `localStorage` (persists across sessions, same-origin only) or cookie (survives full browser close, readable server-side) or neither (URL-only, simplest). | Before Astro implementation | Leonardo |
| OQ-2 | **Model selection:** use Claude Code CLI's default model for batch translation, or force `--model claude-haiku-4-5` (cheaper, faster) for the 61-page bootstrap. Haiku's translation quality for technical docs should be validated on 2–3 sample pages before committing. | Before first bootstrap run | Leonardo |
| OQ-3 | **Glossary coverage:** validate that the initial glossary term list (§7.7) is complete against all 61 pages. A grep pass over `docs/site/**` for candidate proper nouns is recommended before the bootstrap run. | Before bootstrap | Leonardo |
| OQ-4 | **Content collection wiring:** confirm whether `docs/site/` is currently symlinked into `site/src/content/docs/` or copied by a build step, and apply the same mechanism for `docs/site/pt-br/`. | Before Astro implementation | Leonardo |
| OQ-5 | **Fallback rendering:** choose between the 404-based redirect (Option A) and catch-all route (Option B) for missing pt-BR pages (§8.5). | Before Astro implementation | Leonardo |
| OQ-6 | **Starlight i18n integration:** evaluate whether Starlight's built-in `locales` config (which expects EN at a locale-prefixed path like `/en/`) is compatible with the Layout B decision (EN stays at root). If not compatible, document the manual routing approach as the accepted alternative. | Before Astro implementation | Leonardo |

---

## 11. Out of Scope

- Translation of: `README.md`, `skills/`, `rules/`, `knowledge/`, `CHANGELOG.md`, `docs/roadmap.md`, `docs/specs/`, `docs/plans/`, `docs/adrs/`.
- LLM calls in GitHub Actions CI or during Astro static build.
- On-the-fly server-side rendering of translations.
- Any language other than pt-BR.
- Automatic staleness detection for English edits made outside Claude Code
  (direct git commits, editor saves, other tools). Maintainers can trigger
  retranslation manually with `bun run translate -- --page <path>`.
- Automated spell-check or grammar validation of the LLM output.
- Translation memory or segment-level diff (full-page retranslation only).

---

## 12. Success Criteria and Acceptance Tests

### 12.1 Content

- [ ] All 61 pages from `docs/site/` have a corresponding translated file
      under `docs/site/pt-br/` with `needs_retranslation: false`.
- [ ] Every pt-BR page has a valid `source_hash` matching the SHA-256 of its
      English source at the time of translation.
- [ ] Glossary terms (§7.7) appear untranslated in at least 3 spot-checked pages.
- [ ] No code block contents were altered by the LLM.

### 12.2 Site

- [ ] `bun run build` completes without errors on a clean checkout.
- [ ] `/octopus/pt-br/get-started/install/` renders the Portuguese content.
- [ ] `/octopus/get-started/install/` URL is unchanged (EN stays at root).
- [ ] Language switcher links EN ↔ PT-BR on every page tested.

### 12.3 Staleness flow

- [ ] Edit an English page in Claude Code. Immediately after the Edit tool
      returns, the corresponding `docs/site/pt-br/` file has
      `needs_retranslation: true` and an updated `source_hash`.
- [ ] The edited pt-BR path appears in `~/.octopus/translation-queue.txt`.
- [ ] `bun run translate` retranslates only the stale page, sets
      `needs_retranslation: false`, and removes the entry from the queue.

### 12.4 Banners

- [ ] A pt-BR page with `needs_retranslation: true` displays the yellow banner.
- [ ] A pt-BR page with `needs_retranslation: false` displays no banner.
- [ ] Navigating to a missing pt-BR URL serves the EN page with the blue banner.

### 12.5 Hook safety

- [ ] Editing a file outside `docs/site/` does not trigger the hook's mutation
      logic (hook exits 0 silently).
- [ ] Editing a file under `docs/site/pt-br/` does not trigger the hook
      (guard against recursion).
- [ ] Intentionally causing the hook to fail (e.g., read-only filesystem) does
      not produce a non-zero exit and does not block Claude Code's write.
