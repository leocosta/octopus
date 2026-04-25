---
name: update
description: Update the Octopus submodule to a newer version
cli: octopus update
---

## Instructions

1. Run to check current version and available releases:
   ```
   octopus update --latest 2>&1 | head -10
   ```

2. Present to the user:
   - Current version
   - Latest available version
   - "Update to <latest>? Or specify a different version."

3. Wait for confirmation or a specific version.

4. Run the update:
   ```
   # To latest:
   octopus update --latest

   # To a specific version:
   octopus update --version v1.2.0
   ```

5. The script will:
   - Fetch and install the target version
   - Re-run `octopus setup` automatically to regenerate all agent configs
   - If no `.octopus.yml` is found, print a warning and skip setup

6. Report the result to the user: "Octopus updated from vX to vY — agent configs regenerated."
   If the output says "skipping setup" or "Setup failed", prompt the user to run `octopus setup` manually.

> **Note:** If setup produces warnings or errors, report them before confirming success.
