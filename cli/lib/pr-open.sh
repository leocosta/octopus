# pr-open.sh — Open a PR following project conventions
# Usage: octopus.sh pr-open --target <branch> [--body-file <path>]

TARGET=""
BODY_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Usage: octopus.sh pr-open --target <branch> [--body-file <path>]"
  echo ""
  echo "Available remote branches:"
  git branch -r | grep -v HEAD | sed 's/^ */  /'
  exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Validate not on main or release
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" =~ ^release/ ]]; then
  echo "ERROR: Cannot open PR from '$CURRENT_BRANCH'. Switch to a feature branch."
  exit 1
fi

# Push branch to remote
git push -u origin "$CURRENT_BRANCH"

# Generate title from branch name: feat/user-enrollment -> feat: user enrollment
PR_TYPE=$(echo "$CURRENT_BRANCH" | cut -d/ -f1)
PR_DESC=$(echo "$CURRENT_BRANCH" | cut -d/ -f2- | tr '-' ' ')
PR_TITLE="${PR_TYPE}: ${PR_DESC}"

# Generate body
CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TEMPLATE="$CLI_DIR/../pr-body-default.md"

emoji_for_commit() {
  local msg="$1"
  case "$msg" in
    feat*|feat\(*\)  ) echo "✨" ;;
    fix*|fix\(*\)    ) echo "🐛" ;;
    refactor*        ) echo "🔧" ;;
    docs*|docs\(*\)  ) echo "📝" ;;
    chore*|chore\(*\)) echo "🏗️" ;;
    test*|test\(*\)  ) echo "🧪" ;;
    style*|style\(*\)) echo "💄" ;;
    perf*|perf\(*\)  ) echo "⚡" ;;
    ci*|ci\(*\)      ) echo "🔁" ;;
    build*|build\(*\)) echo "📦" ;;
    revert*          ) echo "⏪" ;;
    *)               echo "•" ;;
  esac
}

generate_pr_body() {
  local base="$1"
  local range="${base}..HEAD"

  # ── 1. Rich summary from commit messages (title + body) ──
  local summary=""
  while IFS= read -r hash; do
    [[ -z "$hash" ]] && continue
    local title body emoji
    title=$(git log -1 --format="%s" "$hash")
    body=$(git log -1 --format="%b" "$hash" | sed '/^$/d')
    emoji=$(emoji_for_commit "$title")
    summary+="${emoji} ${title}"
    if [[ -n "$body" ]]; then
      summary+=$'\n'"  > ${body}"
    fi
    summary+=$'\n'
  done < <(git log "$range" --format="%H" 2>/dev/null)

  # ── 2. High-level description from branch context ──
  local branch_type branch_scope branch_desc
  branch_type=$(echo "$CURRENT_BRANCH" | cut -d/ -f1)
  branch_desc=$(echo "$CURRENT_BRANCH" | cut -d/ -f2- | tr '-' ' ')
  branch_scope=$(git diff --name-status "$range" | awk '{print $2}' | cut -d/ -f1 | sort -u | tr '\n' ', ' | sed 's/,$//')

  local context_emoji
  case "$branch_type" in
    feat)     context_emoji="🚀" ;;
    fix)      context_emoji="🩹" ;;
    refactor) context_emoji="🔧" ;;
    docs)     context_emoji="📖" ;;
    chore)    context_emoji="🏗️" ;;
    test)     context_emoji="🧪" ;;
    *)        context_emoji="📌" ;;
  esac

  # ── 3. Change statistics ──
  local stats added_count modified_count deleted_count total_files
  stats=$(git diff --shortstat "$range" 2>/dev/null)
  added_count=$(git diff --name-status "$range" | grep -c '^A' || true)
  modified_count=$(git diff --name-status "$range" | grep -c '^M' || true)
  deleted_count=$(git diff --name-status "$range" | grep -c '^D' || true)
  total_files=$((added_count + modified_count + deleted_count))

  # ── 4. File categorization with context ──
  local added modified deleted
  added=$(git diff --name-status "$range" | grep '^A' | awk '{
    emoji="📄"; ext=tolower($2);
    if (match(ext, /\.sh$/)) emoji="⚙️";
    else if (match(ext, /\.ya?ml$/)) emoji="⚙️";
    else if (match(ext, /\.md$/)) emoji="📝";
    else if (match(ext, /\.ts$|\.js$/)) emoji="📜";
    else if (match(ext, /\.json$/)) emoji="🔧";
    print emoji " `" $2 "`"
  }')
  modified=$(git diff --name-status "$range" | grep '^M' | awk '{
    emoji="📄"; ext=tolower($2);
    if (match(ext, /\.sh$/)) emoji="⚙️";
    else if (match(ext, /\.ya?ml$/)) emoji="⚙️";
    else if (match(ext, /\.md$/)) emoji="📝";
    else if (match(ext, /\.ts$|\.js$/)) emoji="📜";
    else if (match(ext, /\.json$/)) emoji="🔧";
    print emoji " `" $2 "`"
  }')
  deleted=$(git diff --name-status "$range" | grep '^D' | awk '{
    emoji="📄"; ext=tolower($2);
    if (match(ext, /\.sh$/)) emoji="⚙️";
    else if (match(ext, /\.ya?ml$/)) emoji="⚙️";
    else if (match(ext, /\.md$/)) emoji="📝";
    else if (match(ext, /\.ts$|\.js$/)) emoji="📜";
    else if (match(ext, /\.json$/)) emoji="🔧";
    print emoji " `" $2 "`"
  }')

  # ── 5. Key diff highlights (changed functions/components) ──
  local highlights=""
  local diff_content
  diff_content=$(git diff "$range" 2>/dev/null)
  if [[ -n "$diff_content" ]]; then
    # Extract function/class definitions changed
    local funcs
    funcs=$(echo "$diff_content" | grep -E '^\+.*(function |def |class |const |let |var |func |fn |impl )' | \
      sed 's/^+//' | grep -oE '(function|def|class|const|let|var|func|fn|impl) +[a-zA-Z_][a-zA-Z0-9_]*' | \
      head -5 | awk '{print "- `" $2 "` (" $1 ")"}')
    if [[ -n "$funcs" ]]; then
      highlights="$funcs"
    fi
  fi

  # ── 6. Build the PR body ──
  cat <<BODY
## ${context_emoji} Context

**Branch**: \`${CURRENT_BRANCH}\` → \`${base}\`
**Type**: ${branch_type} — ${branch_desc}
**Scope**: ${branch_scope}
**Impact**: ${total_files} file(s) changed, ${stats}

## 📋 What Changed

${summary:-N/A}

## 🔄 File Changes

### ✅ Added (${added_count})
${added:-_none_}

### 🔧 Modified (${modified_count})
${modified:-_none_}

### ❌ Deleted (${deleted_count})
${deleted:-_none_}

$([ -n "$highlights" ] && echo "## 🔍 Key Changes
${highlights}
")

## 🧪 How to Test
1. Review the diff for correctness
2. Verify no breaking changes introduced
3. Run existing tests if applicable
BODY
}

if [[ -n "$BODY_FILE" ]]; then
  if [[ ! -f "$BODY_FILE" ]]; then
    echo "ERROR: Body file not found: $BODY_FILE"
    exit 1
  fi
  PR_BODY=$(cat "$BODY_FILE")
else
  PR_BODY=$(generate_pr_body "$TARGET")
fi

# Create PR
gh pr create --base "$TARGET" --title "$PR_TITLE" --body "$PR_BODY"

# Get PR number
PR_NUMBER=$(gh pr view --json number -q '.number')
echo "OCTOPUS_PR=$PR_NUMBER"
