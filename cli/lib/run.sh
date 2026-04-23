#!/usr/bin/env bash
# octopus run — drive a feature from requirement to PR.
#
# Usage:
#   octopus run "description"
#   octopus run --from-issue gh:<number>
#   octopus run --from-spec docs/specs/<slug>.md
#   octopus run --plan docs/plans/<slug>.md
#   octopus run --skip-spec-review "description"

set -euo pipefail
source "$CLI_DIR/lib/ui.sh"

_usage() {
  cat <<EOF
Usage: octopus run [options] [description]

Options:
  --from-issue gh:<N>        Fetch GitHub issue and plan from it
  --from-spec <spec.md>      Skip research; plan from existing spec
  --plan <plan.md>           Skip planning; execute an existing enriched plan
  --skip-spec-review         Do not pause for spec review (automation mode)
  --help                     Show this help

Examples:
  octopus run "implement JWT auth with refresh tokens"
  octopus run --from-issue gh:123
  octopus run --from-spec docs/specs/user-auth.md
  octopus run --plan docs/plans/user-auth.md
EOF
}

SKIP_SPEC_REVIEW=0
FROM_ISSUE=""
FROM_SPEC=""
PLAN_FILE=""
DESCRIPTION=""

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --help)             _usage; exit 0 ;;
    --skip-spec-review) SKIP_SPEC_REVIEW=1; shift ;;
    --from-issue)       FROM_ISSUE="${2:-}"; shift 2 ;;
    --from-spec)        FROM_SPEC="${2:-}"; shift 2 ;;
    --plan)             PLAN_FILE="${2:-}"; shift 2 ;;
    *)                  DESCRIPTION="${DESCRIPTION} ${1}"; shift ;;
  esac
done
DESCRIPTION="${DESCRIPTION# }"

# ── Mode: existing plan ────────────────────────────────────────────────────
if [[ -n "$PLAN_FILE" ]]; then
  if [[ ! -f "$PLAN_FILE" ]]; then
    ui_error "Plan file not found: $PLAN_FILE"
    exit 1
  fi
  ui_info "Running pipeline from plan: $PLAN_FILE"
  PYTHONPATH="$(dirname "$CLI_DIR")" python3 -m cli.control.pipeline "$PLAN_FILE"
  exit $?
fi

# ── Mode: existing spec ────────────────────────────────────────────────────
if [[ -n "$FROM_SPEC" ]]; then
  if [[ ! -f "$FROM_SPEC" ]]; then
    ui_error "Spec file not found: $FROM_SPEC"
    exit 1
  fi
  SLUG=$(basename "$FROM_SPEC" .md \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g' \
    | sed 's/--*/-/g' \
    | cut -c1-40 \
    | sed 's/-$//')
  ui_info "Generating pipeline plan from spec: $FROM_SPEC"
  claude --print "/octopus:doc-plan $SLUG"
  PLAN_FILE="docs/plans/${SLUG}.md"
  if [[ ! -f "$PLAN_FILE" ]]; then
    ui_error "Plan not found after doc-plan: $PLAN_FILE"
    exit 1
  fi
  PYTHONPATH="$(dirname "$CLI_DIR")" python3 -m cli.control.pipeline "$PLAN_FILE"
  exit $?
fi

# ── Mode: from GitHub issue ────────────────────────────────────────────────
if [[ -n "$FROM_ISSUE" ]]; then
  ISSUE_TYPE="${FROM_ISSUE%%:*}"
  ISSUE_ID="${FROM_ISSUE#*:}"
  case "$ISSUE_TYPE" in
    gh)
      ui_info "Fetching GitHub issue #${ISSUE_ID}..."
      ISSUE_BODY=$(gh issue view "$ISSUE_ID" --json title,body \
        --jq '"Title: " + .title + "\n\nBody:\n" + .body' 2>/dev/null) || {
        ui_error "Could not fetch GitHub issue #${ISSUE_ID}. Is gh CLI authenticated?"
        exit 1
      }
      DESCRIPTION="$ISSUE_BODY"
      ;;
    notion)
      ui_error "Notion issue fetching requires the Notion MCP server. Set it up and retry."
      exit 1
      ;;
    *)
      ui_error "Unknown issue type: $ISSUE_TYPE. Use gh:<N>."
      exit 1
      ;;
  esac
fi

# ── Mode: free text / issue body → full pipeline ──────────────────────────
if [[ -z "$DESCRIPTION" ]]; then
  ui_error "Provide a description or use --from-issue / --from-spec / --plan."
  _usage
  exit 1
fi

ui_info "Starting feature pipeline..."
ui_info "Description: $DESCRIPTION"

SLUG=$(printf '%s' "$DESCRIPTION" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9]/-/g' \
  | sed 's/--*/-/g' \
  | cut -c1-40 \
  | sed 's/-$//')
if [[ -z "$SLUG" ]]; then
  ui_error "Could not derive a slug from the description. Use more descriptive text."
  exit 1
fi
ui_info "Slug: $SLUG"

claude --print "/octopus:doc-research $SLUG
Context: $DESCRIPTION"

SPEC_FILE="docs/specs/${SLUG}.md"
if [[ ! -f "$SPEC_FILE" ]]; then
  ui_error "Spec not found after research: $SPEC_FILE"
  exit 1
fi

if [[ "$SKIP_SPEC_REVIEW" -eq 0 ]]; then
  ui_info "Spec generated at: $SPEC_FILE"
  ui_info "Review the spec, then press ENTER to continue (Ctrl+C to abort)."
  read -r
fi

claude --print "/octopus:doc-plan $SLUG"

PLAN_FILE="docs/plans/${SLUG}.md"
if [[ ! -f "$PLAN_FILE" ]]; then
  ui_error "Plan not found after doc-plan: $PLAN_FILE"
  exit 1
fi

ui_info "Executing pipeline: $PLAN_FILE"
PYTHONPATH="$(dirname "$CLI_DIR")" python3 -m cli.control.pipeline "$PLAN_FILE"
