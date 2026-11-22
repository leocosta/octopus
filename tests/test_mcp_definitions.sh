#!/usr/bin/env bash
# Every MCP server Octopus ships is either a vendor-hosted endpoint over https,
# or a package launched at an exact version. An unpinned `npx <pkg>` resolves
# whatever is newest on every agent start.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$DIR/mcp" <<'PYEOF'
import json, os, re, sys
root, bad = sys.argv[1], []
LAUNCHERS = {"npx", "uvx", "bunx", "pnpx"}
PINNED = re.compile(r"^(@[^/@\s]+/)?[^@\s]+@\d+\.\d+\.\d+([-+][\w.-]+)?$")
for name in sorted(os.listdir(root)):
    if not name.endswith(".json"):
        continue
    for server, cfg in json.load(open(os.path.join(root, name))).items():
        if cfg.get("type") == "http" or "url" in cfg:
            if not str(cfg.get("url", "")).startswith("https://"):
                bad.append(f"{name}: {server} is not https")
            continue
        cmd = os.path.basename(cfg.get("command", ""))
        if cmd in LAUNCHERS:
            pkgs = [a for a in cfg.get("args", []) if not a.startswith("-") and not a.startswith("${")]
            if not pkgs or not PINNED.match(pkgs[0]):
                bad.append(f"{name}: {server} runs '{pkgs[0] if pkgs else '?'}' without an exact version")
for b in bad:
    print("FAIL:", b)
print("PASS: every MCP server is https-hosted or version-pinned" if not bad else "")
sys.exit(1 if bad else 0)
PYEOF
