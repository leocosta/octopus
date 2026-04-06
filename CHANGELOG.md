# Changelog

All notable changes to this project will be documented in this file.

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