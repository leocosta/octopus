---
name: update
description: Update Octopus to a newer version
---

---
description: Update the Octopus submodule to a newer version
agent: code
---

## Instructions

1. Run to check current version and available releases:
   ```
   ./octopus/cli/octopus.sh update --latest 2>&1 | head -10
   ```
   This shows the current version, the 5 most recent tags, and the suggested target.

2. Present to the user:
   - Current version
   - Latest available version
   - "Update to <latest>? Or specify a different version."

3. Wait for confirmation or a specific version.

4. Run the update:
   ```
   # To latest:
   ./octopus/cli/octopus.sh update --latest

   # To a specific version:
   ./octopus/cli/octopus.sh update --version v1.2.0
   ```

5. The script will:
   - Fetch remote tags
   - Checkout the target version
   - Re-run `setup.sh` to regenerate all agent configs
   - Commit the submodule update

6. Report: "Octopus updated from vX to vY. Setup re-run — all agent configs regenerated."

> **Note:** If setup.sh produces warnings or errors after update, report them before confirming success.
