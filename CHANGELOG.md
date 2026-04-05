# Changelog

All notable changes to this project will be documented in this file.

## [0.15.4] - 2026-04-05

🐛 Updated GitHub Actions to use Node.js 24 compatible versions, ensuring the CI pipeline runs smoothly on the latest runtime.

## [0.15.3] - 2026-04-05

🔁 Fixed the `build-release.yml` CI workflow that was silently failing on every release since `v0.15.0`, causing `install.sh` and `install.ps1` to never be uploaded as release assets (resulting in a 404 when running `curl .../install.sh`). The root cause was two redundant `cp` commands that tried to copy each file onto itself — the runner's working directory is already `$GITHUB_WORKSPACE`, so `cp install.sh install.sh` aborted with a same-file error under bash `-e`, skipping the entire upload step. Removed the two lines; the files are already in the correct location after `actions/checkout`.

## [0.15.2] - 2026-04-05

🐛 Fixed global installation issues and added Windows support. The curl installer now correctly uploads `install.sh` and `install.ps1` as GitHub release assets. The octopus setup no longer crashes because `download_release()` now extracts to `cache/<version>/` matching the `CACHE_DIR` expected by the shim. Fixed `RELEASE_ROOT` detection in global shim to handle both submodule and global modes. The install.sh now writes `metadata.json` so `resolve_version()` works without requiring `octopus install` to run first. Added macOS compatibility fixes (replaced `readlink -f` with plain `readlink`), progress bar to curl downloads, and status messages to install/update commands. Created ASCII art octopus with structured welcome banner. Added `install.ps1` for Windows with PowerShell installer, correct path conversion for WSL/Git Bash, and PATH auto-configuration. 📝 Revised README with multi-platform installation guide, cleaned features table with links to docs/, and moved detailed content to docs/features/*.md.

## [0.15.0] - 2026-04-04

✨ Introduced a global CLI tool to reduce the friction of using git submodules across repositories. The new `bin/octopus` serves as a standalone shim that resolves versions from a local cache (`~/.octopus-cli`), respects per-repository lockfiles (`.octopus/cli-lock.yaml`), and delegates to the existing workflow commands (`branch-create`, `dev-flow`, `pr-open`, etc.). A shell installer (`install.sh`) downloads tagged releases from GitHub, verifies SHA256 checksums, and creates a shim at `~/.local/bin/octopus`. The `setup.sh` and legacy `./octopus/cli/octopus.sh` paths remain as migration shims that forward to the global CLI. Added RFC and spec documents under `docs/rfcs/` and `docs/specs/` to guide future development, along with tests (`test_global_cli.sh`, `test_installer.sh`) covering install, doctor, and update workflows.

## [0.14.0] - 2026-04-04

🚀 Renamed the `antigravity` agent to `gemini` to align with the official Gemini CLI naming and ensure out-of-the-box compatibility by generating `GEMINI.md` as the default output. Updated all agent manifests, core documentation (including `README.md` and commit conventions), and fixed test suites (`test_parse_yaml.sh`, `test_concatenate_agent.sh`, `test_commands.sh`, `test_workflow_commands.sh`) to support the new agent name and its associated conventions. This migration ensures the Octopus framework is 100% compatible with the latest Gemini CLI standards.

## [0.13.0] - 2026-04-04

✨ Role files can now declare a `tools:` field in their YAML frontmatter to restrict
which tools a Claude Code agent can use. The `social-media` role ships with an initial
declaration (`Read`, `Write`, `WebSearch`, `WebFetch`), serving as the documented
pattern for new roles. `normalize_role_frontmatter_for_agent()` was refactored to strip
this Claude Code-specific field for all non-Claude agents (OpenCode and future native
platforms), preserving correct frontmatter across the full delivery matrix. Three new
tests cover the field's preservation in Claude, removal in OpenCode, and absence in
Copilot inline output. 📝 The `pr-open` command now displays the full PR body after
creation, and `dev-flow` was updated to reflect this as default workflow behavior.

## [0.11.3] - 2026-04-03

🐛 This patch release fixes OpenCode/Kilo startup failures caused by YAML frontmatter parsing in generated agent files. Octopus now emits quoted hex values such as `color: "#800080"` for native OpenCode roles, preventing the `#` from being parsed as a comment and leaving the `color` field empty at runtime.

📝 Shared role templates were aligned with the same quoted-hex format, the role-generation test suite now asserts the YAML-safe output, and the documentation knowledge module records the confirmed root cause so future agent-schema fixes start from the right constraint.

## [0.11.2] - 2026-04-03

🐛 This patch release strengthens Octopus's documentation workflow by expanding the `product-manager` and `tech-writer` roles with more actionable guidance, aligning ADR instructions with the real `docs/adrs/` path, and fixing knowledge index generation so projects with knowledge enabled but no active modules still get a useful `INDEX.md` instead of silently skipping it.

📝 The sample config, README, ADR template, and feature-lifecycle guidance now reflect the current knowledge mapping and documentation flow, including the post-`v0.11.1` README sync updates. 🧪 Role, knowledge, and YAML parsing coverage were updated to verify the new product-manager mappings and preserve the executable shell entrypoints that the documented workflow runs directly.

## [0.11.1] - 2026-04-03

🐛 This patch release fixes OpenCode native role generation by normalizing role `color` frontmatter to valid hex values before writing agent files, which prevents the `Invalid hex color format color` failure when launching generated agents. Existing shared roles were updated to use explicit hex colors, and 🧪 role-generation coverage now verifies native OpenCode output alongside the current Claude and Copilot delivery paths.

📝 The README now includes a detailed Claude Code operating guide for the `tech-writer` role, covering setup, prompts, session flow, expected outputs, and troubleshooting. The new `knowledge/documentation/` module captures the documentation lessons behind this change so future role and docs work stays grounded in reproducible guidance.