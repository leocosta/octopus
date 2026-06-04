# cli/lib/setup.sh — Configure Octopus in the current repository or at user scope.
# Sourced by bin/octopus. Variable $CLI_DIR must be set by caller.

RELEASE_DIR="$(cd "$CLI_DIR/.." && pwd)"
SETUP_SCRIPT="$RELEASE_DIR/setup.sh"
EXAMPLE_ENV="$RELEASE_DIR/.env.octopus.example"

# shellcheck source=./ui.sh
source "$CLI_DIR/lib/ui.sh"

if [[ ! -f "$SETUP_SCRIPT" ]]; then
  ui_error "setup.sh not found at $SETUP_SCRIPT"
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------
SETUP_BUNDLE=""
SETUP_SCOPE=""
SETUP_STACK=""
SETUP_REVIEWERS=""
SETUP_HOOKS="true"
SETUP_WORKFLOW="true"
SETUP_DRY_RUN="false"
SETUP_NO_DETECT="false"
_setup_remaining_args=()
_setup_prev_arg=""

for _setup_arg in "$@"; do
  case "$_setup_arg" in
    --bundle=*)    SETUP_BUNDLE="${_setup_arg#--bundle=}" ;;
    --scope=*)     SETUP_SCOPE="${_setup_arg#--scope=}" ;;
    --stack=*)     SETUP_STACK="${_setup_arg#--stack=}" ;;
    --reviewers=*) SETUP_REVIEWERS="${_setup_arg#--reviewers=}" ;;
    --no-hooks)    SETUP_HOOKS="false" ;;
    --no-workflow) SETUP_WORKFLOW="false" ;;
    --no-detect)   SETUP_NO_DETECT="true" ;;
    --dry-run)     SETUP_DRY_RUN="true"; export OCTOPUS_DRY_RUN="true" ;;
    --reconfigure) _setup_remaining_args+=("$_setup_arg") ;;
    --bundle|--scope|--stack|--reviewers) ;;  # value comes next iteration
    *)             _setup_remaining_args+=("$_setup_arg") ;;
  esac
  # Handle space-separated: --bundle starter
  case "$_setup_prev_arg" in
    --bundle)    SETUP_BUNDLE="$_setup_arg" ;;
    --scope)     SETUP_SCOPE="$_setup_arg" ;;
    --stack)     SETUP_STACK="$_setup_arg" ;;
    --reviewers) SETUP_REVIEWERS="$_setup_arg" ;;
  esac
  _setup_prev_arg="$_setup_arg"
done
unset _setup_arg _setup_prev_arg

# Normalise --bundle: accept comma or space-separated list → space-separated
SETUP_BUNDLE=$(printf '%s' "$SETUP_BUNDLE" | tr ',' ' ' | tr -s ' ')

# ---------------------------------------------------------------------------
# Resolve scope
# ---------------------------------------------------------------------------
if [[ -n "$SETUP_SCOPE" ]]; then
  export OCTOPUS_SCOPE="$SETUP_SCOPE"
  export OCTOPUS_SCOPE_PINNED=1
fi
OCTOPUS_SCOPE="${OCTOPUS_SCOPE:-repo}"
export OCTOPUS_SCOPE

case "$OCTOPUS_SCOPE" in
  repo|user) ;;
  *) ui_error "Invalid --scope '$OCTOPUS_SCOPE' — use 'repo' or 'user'."; exit 1 ;;
esac

export PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
USER_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/octopus"

if [[ "$OCTOPUS_SCOPE" == "user" ]]; then
  MANIFEST_DIR="$USER_CONFIG_DIR"
else
  MANIFEST_DIR="$PROJECT_ROOT"
fi
MANIFEST_PATH="$MANIFEST_DIR/.octopus.yml"
export MANIFEST_PATH

# ---------------------------------------------------------------------------
# Stack/DB detection (RM-138)
# ---------------------------------------------------------------------------
# Scan a repo and echo the matching profile-bundle names (one per line):
# stack-<lang> from file presence, db-<engine> from driver signals in
# dependency manifests / config. Read-only; reuses the fleet-bootstrap detect
# signals and the dba-* trigger keywords. Self-contained (single column-0 `}`)
# so tests can extract it via sed.
_detect_stack() {
  local root="${1:-${PROJECT_ROOT:-$PWD}}"
  local found=()
  local prune=( -name node_modules -o -name .git -o -name obj -o -name bin -o -name dist )

  # Language stacks — file presence.
  if find "$root" -maxdepth 5 \( "${prune[@]}" \) -prune -o -type f \
       \( -name '*.csproj' -o -name '*.sln' -o -name '*.fsproj' \) -print 2>/dev/null | grep -q .; then
    found+=("stack-csharp")
  fi
  if find "$root" -maxdepth 5 \( "${prune[@]}" \) -prune -o -type f -name package.json -print 2>/dev/null | grep -q . \
     && find "$root" -maxdepth 5 \( "${prune[@]}" \) -prune -o -type f \
          \( -name tsconfig.json -o -name '*.ts' -o -name '*.tsx' \) -print 2>/dev/null | grep -q .; then
    found+=("stack-typescript")
  fi
  if find "$root" -maxdepth 5 \( "${prune[@]}" \) -prune -o -type f \
       \( -name pyproject.toml -o -name setup.py -o -name 'requirements*.txt' \) -print 2>/dev/null | grep -q .; then
    found+=("stack-python")
  fi

  # Databases — precise driver signals in dependency manifests / config.
  local inc=( --include='*.csproj' --include='*.fsproj' --include='package.json' \
              --include='pyproject.toml' --include='requirements*.txt' \
              --include='appsettings*.json' --include='.env*' )
  grep -rqiE 'Npgsql|psycopg|postgres(ql)?://|"pg":'                                 "${inc[@]}" "$root" 2>/dev/null && found+=("db-postgres")
  grep -rqiE 'Microsoft\.Data\.SqlClient|System\.Data\.SqlClient|"mssql":|sqlserver' "${inc[@]}" "$root" 2>/dev/null && found+=("db-mssql")
  grep -rqiE 'MongoDB\.Driver|"mongoose":|pymongo|mongodb(\+srv)?://'                "${inc[@]}" "$root" 2>/dev/null && found+=("db-mongodb")
  grep -rqiE 'StackExchange\.Redis|"ioredis":|redis-py|"redis":|redis://'           "${inc[@]}" "$root" 2>/dev/null && found+=("db-redis")

  [[ ${#found[@]} -gt 0 ]] && printf '%s\n' "${found[@]}"
  return 0
}

# ---------------------------------------------------------------------------
# Manifest generation
# ---------------------------------------------------------------------------
_setup_generate_manifest() {
  local bundles_str="$1" hooks="$2" workflow="$3" reviewers="$4" profiles="$5"

  mkdir -p "$(dirname "$MANIFEST_PATH")"

  # Merge intent bundles + resolved stack/db profiles (RM-139), order-stable and
  # de-duplicated. Profiles are bundles, so they need no separate manifest key —
  # expand_bundles turns stack-csharp into dotnet + csharp rules, db-mssql into
  # dba-mssql, etc.
  local _all=() _b
  for _b in $bundles_str $profiles; do
    case " ${_all[*]:-} " in *" $_b "*) ;; *) _all+=("$_b") ;; esac
  done

  {
    printf '# Edit and re-run '"'"'octopus setup'"'"' to apply changes.\n'
    printf 'agents:\n  - claude\n'
    printf 'bundles:\n'
    for _b in "${_all[@]}"; do printf '  - %s\n' "$_b"; done

    [[ "$hooks" == "true" ]]    && printf 'hooks: true\n'
    [[ "$workflow" == "true" ]] && printf 'workflow: true\n'

    if [[ -n "$reviewers" ]]; then
      printf 'reviewers:\n'
      local IFS=','
      for _r in $reviewers; do
        printf '  - %s\n' "${_r// /}"
      done
    fi

    printf '\n# Uncomment to configure:\n'
    printf '# reviewers: [user1, user2]\n'
    printf '# mcp:\n'
    printf '#   - name: github\n'
  } > "$MANIFEST_PATH"
}

# ---------------------------------------------------------------------------
# Interactive follow-up (reviewers)
# ---------------------------------------------------------------------------
_setup_prompt_reviewers() {
  printf "  GitHub usernames (comma-separated): "
  local reply
  read -r reply </dev/tty
  SETUP_REVIEWERS="$reply"
}

# ---------------------------------------------------------------------------
# Resolve stack/DB profiles (RM-138/139)
# ---------------------------------------------------------------------------
# Profiles are category-tagged bundles (stack-*/db-*), so they flow into the
# manifest's bundles: list. Source = legacy --stack mapping + auto-detection
# (unless --no-detect). The picker pre-selects these (SETUP_PROFILES exported);
# the user's confirmed selection stays authoritative there.
SETUP_PROFILES=""
case "$SETUP_STACK" in
  dotnet|csharp)   SETUP_PROFILES="stack-csharp" ;;
  node|typescript) SETUP_PROFILES="stack-typescript" ;;
  python)          SETUP_PROFILES="stack-python" ;;
esac
if [[ "$SETUP_NO_DETECT" != "true" ]]; then
  while IFS= read -r _p; do
    [[ -n "$_p" ]] && SETUP_PROFILES+=" $_p"
  done < <(_detect_stack "$PROJECT_ROOT")
fi
# De-duplicate, order-stable.
SETUP_PROFILES="$(printf '%s\n' $SETUP_PROFILES | awk 'NF && !seen[$0]++' | tr '\n' ' ')"
SETUP_PROFILES="${SETUP_PROFILES% }"
export SETUP_PROFILES

# ---------------------------------------------------------------------------
# Main flow
# ---------------------------------------------------------------------------
if [[ ! -f "$MANIFEST_PATH" ]]; then
  if [[ -n "$SETUP_BUNDLE" ]]; then
    # Flag-driven: no interaction — detected/affirmed profiles join the bundles.
    _setup_generate_manifest \
      "$SETUP_BUNDLE" "$SETUP_HOOKS" "$SETUP_WORKFLOW" "$SETUP_REVIEWERS" "$SETUP_PROFILES"
  elif [[ -t 0 && -t 1 ]]; then
    # Interactive: picker pre-selects the profiles; its result is authoritative.
    source "$CLI_DIR/lib/setup-picker.sh"
    run_picker
    [[ "${PICKER_REVIEWERS:-}" == "__ask__" ]] && _setup_prompt_reviewers
    _setup_generate_manifest \
      "${PICKER_BUNDLES[*]:-starter}" \
      "${PICKER_HOOKS:-true}" \
      "${PICKER_WORKFLOW:-true}" \
      "${SETUP_REVIEWERS:-}" \
      ""
  else
    # Non-interactive (CI/pipe): starter + detected profiles, silently.
    _setup_generate_manifest "starter" "true" "true" "" "$SETUP_PROFILES"
  fi
elif [[ " ${_setup_remaining_args[*]:-} " == *" --reconfigure "* ]]; then
  # Reconfigure existing manifest
  if [[ -t 0 && -t 1 ]]; then
    source "$CLI_DIR/lib/setup-picker.sh"
    run_picker
    [[ "${PICKER_REVIEWERS:-}" == "__ask__" ]] && _setup_prompt_reviewers
    _setup_generate_manifest \
      "${PICKER_BUNDLES[*]:-starter}" \
      "${PICKER_HOOKS:-true}" \
      "${PICKER_WORKFLOW:-true}" \
      "${SETUP_REVIEWERS:-}" \
      ""
  fi
fi

# Delegate delivery to root setup.sh
bash "$SETUP_SCRIPT" "${_setup_remaining_args[@]+"${_setup_remaining_args[@]}"}"
