# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-04-18

Marks the first stable release, consolidating RM-005 through RM-009 in a single delivery.

✨ The global CLI installer now verifies detached GPG signatures alongside the existing SHA256 check — configurable via `OCTOPUS_GPG_KEYRING`, `OCTOPUS_GPG_IMPORT_KEY`, `OCTOPUS_REQUIRE_SIGNATURE`, and `OCTOPUS_SKIP_SIGNATURE`, closing the remaining supply-chain gap on compromised mirrors. Installer hardening continues with new `--bin-dir` / `--cache-root` flags, `OCTOPUS_INSTALL_ENDPOINT` support for `file://` mirrors, and real SHA256 capture in `metadata.json`.

✨ Setup UX was unified across `install.sh`, the interactive wizard, and `setup.sh`. A new `cli/lib/ui.sh` module provides shared vocabulary that groups per-agent delivery under a single step line. Every wizard prompt now dispatches to the active TUI backend (fzf / whiptail / dialog / bash), and each of the eleven wizard steps gained a contextual explanation plus per-item hints.

📝 Role templates can now declare a `tools:` frontmatter field that is preserved for Claude Code and stripped for every other target. Language rules specs were promoted to Implemented alongside the behavioral detection rule and the project-override mechanism.

⚠️ BREAKING CHANGE: submodule mode is no longer supported. `cli/lib/update.sh`, `commands/update.md`, `tests/test_update.sh`, the submodule branch in `setup.sh` PROJECT_ROOT resolution, `OCTOPUS_CLI_REL`, and every submodule/legacy-shim reference across README, commands, and feature docs were removed. Existing submodule installs must switch to the global CLI (`install.sh`) and re-run `octopus setup`; the manifest is preserved. RM-010 (`octopus migrate` helper) was rejected as a consequence.

## [0.16.1] - 2026-04-06
Fixed a syntax error in the _select_one bash fallback function that was causing issues in the setup process. 🐛

## [0.16.0] - 2026-04-06
Added an interactive TUI setup wizard (`octopus setup`) that guides users through configuring `.octopus.yml` with multi-backend support (fzf/whiptail/dialog/bash) and full Windows/Git Bash compatibility. ✨

## [0.15.10] - 2026-04-05
Fixed the CLI setup for PROJECT_ROOT and added interactive scaffolding features. 🐛

## [0.15.9] - 2026-04-05
Fixed the CLI setup command by adding the missing setup command to cli/octopus.sh 🐛

## [0.15.8] - 2026-04-05
Added contents: write permission for GitHub release upload in CI workflow. 🐛

## [0.15.7] - 2026-04-05
Fixed a CI issue where the tar archive was causing self-modification errors by writing it to /tmp instead. 🐛

## [0.15.6] - 2026-04-05
🐛 Replaced softprops action with gh CLI and upgraded checkout to v6 in CI workflows.

## [0.15.5] - 2026-04-05
🔁 Set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` on the release job so all JavaScript actions (including `actions/checkout@v4`) run under Node.js 24. The `v4.x` line bundles Node.js 20 internally regardless of the pinned version tag, causing a deprecation warning that surfaced as a runtime failure on the updated GitHub runners.