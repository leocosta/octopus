# Language

## Core Rule: Match the Project, Not the Conversation

The language used in conversation NEVER determines the language of created artifacts.
Always determine the appropriate language by reading the project itself.

## Detection Signals (priority order)

1. **`language.local.md`** in this same directory — if present, it takes full precedence over all signals below
2. **Documentation**: check `docs/` — match the language of existing specs, ADRs, READMEs
3. **Commit history**: `git log --oneline -20` — detect the language pattern in use
4. **UI strings**: check `locales/`, `i18n/`, or existing translation files

If no signals are found for a specific type → default to **English**.

## Non-Negotiable

- **Code identifiers** (function/class/variable names, file names): always **English**
- **Conversation language** never influences artifact language
