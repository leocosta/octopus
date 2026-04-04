# Changelog

All notable changes to this project will be documented in this file.

## [0.12.0] - 2026-04-04

✨ This release introduces a new social-media role with X publishing capabilities, expanding Octopus's workflow automation for social media management. 🐛 The dev-flow command was fixed to improve the development workflow experience.

## [0.11.3] - 2026-04-03

🐛 This patch release fixes OpenCode/Kilo startup failures caused by YAML frontmatter parsing in generated agent files. Octopus now emits quoted hex values such as `color: "#800080"` for native OpenCode roles, preventing the `#` from being parsed as a comment and leaving the `color` field empty at runtime.

📝 Shared role templates were aligned with the same quoted-hex format, the role-generation test suite now asserts the YAML-safe output, and the documentation knowledge module records the confirmed root cause so future agent-schema fixes start from the right constraint.