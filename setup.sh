#!/usr/bin/env bash
set -euo pipefail

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${PROJECT_ROOT:-}" ]]; then
  _PARENT_DIR="$(cd "$OCTOPUS_DIR/.." && pwd)"
  if [[ -f "$_PARENT_DIR/.octopus.yml" ]]; then
    # Submodule mode: parent project owns the config
    PROJECT_ROOT="$_PARENT_DIR"
  elif [[ -f "$OCTOPUS_DIR/.octopus.yml" ]]; then
    # Self-setup: octopus itself is the root project
    PROJECT_ROOT="$OCTOPUS_DIR"
  else
    PROJECT_ROOT="$_PARENT_DIR"
  fi
fi
OCTOPUS_CLI_REL="$(python3 -c "import os; print(os.path.relpath('$OCTOPUS_DIR/cli/octopus.sh', '$PROJECT_ROOT'))")"

# (Agent output paths are now read from agents/<name>/manifest.yml)

# Parsed config arrays
declare -a OCTOPUS_RULES=()
declare -a OCTOPUS_SKILLS=()
OCTOPUS_HOOKS="false"
declare -a OCTOPUS_AGENTS=()
declare -A OCTOPUS_AGENT_OUTPUT=()
declare -a OCTOPUS_MCP=()
declare -a OCTOPUS_CMD_NAMES=()
declare -a OCTOPUS_CMD_DESCS=()
declare -a OCTOPUS_CMD_RUNS=()
OCTOPUS_WORKFLOW=false
declare -a OCTOPUS_ROLES=()
declare -a OCTOPUS_REVIEWERS=()
OCTOPUS_KNOWLEDGE_ENABLED="false"
OCTOPUS_KNOWLEDGE_MODE=""               # "auto" or "explicit"
OCTOPUS_KNOWLEDGE_DIR="knowledge"       # configurable via knowledge_dir: in .octopus.yml
declare -a OCTOPUS_KNOWLEDGE_LIST=()
declare -A OCTOPUS_KNOWLEDGE_ROLES=()   # key=role, value=comma-separated modules
declare -a OCTOPUS_PERMISSIONS_ALLOW=()
declare -a OCTOPUS_PERMISSIONS_DENY=()
OCTOPUS_PERMISSIONS_MODE=""             # "explicit" | "defaults" | ""
OCTOPUS_EFFORT_LEVEL=""                 # "low" | "medium" | "high" | "max"
OCTOPUS_LANGUAGE_DOCS=""    # language for docs/commits/PRs (empty = auto-detect)
OCTOPUS_LANGUAGE_CODE=""    # language for code comments (empty = auto-detect)
OCTOPUS_LANGUAGE_UI=""      # language for UI/user-facing content (empty = auto-detect)

parse_octopus_yml() {
  local file="$1"
  local current_section=""
  local pending_agent_name=""
  local pending_cmd_name=""
  local pending_cmd_desc=""
  local pending_cmd_run=""
  local current_knowledge_subsection=""
  local current_knowledge_role=""
  local current_permissions_subsection=""

  _flush_pending_cmd() {
    if [[ -n "$pending_cmd_name" ]]; then
      OCTOPUS_CMD_NAMES+=("$pending_cmd_name")
      OCTOPUS_CMD_DESCS+=("$pending_cmd_desc")
      OCTOPUS_CMD_RUNS+=("$pending_cmd_run")
      pending_cmd_name=""
      pending_cmd_desc=""
      pending_cmd_run=""
    fi
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Handle inline boolean: workflow: true/false
    if [[ "$line" =~ ^([a-z]+):[[:space:]]+(true|false)[[:space:]]*$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local val="${BASH_REMATCH[2]}"
      case "$key" in
        workflow)  OCTOPUS_WORKFLOW="$val" ;;
        hooks)     OCTOPUS_HOOKS="$val" ;;
        knowledge) OCTOPUS_KNOWLEDGE_ENABLED="true"; OCTOPUS_KNOWLEDGE_MODE="auto" ;;
      esac
      current_section=""
      continue
    fi

    # Handle inline string value: context: path/to/file, knowledge_dir: docs/ai, effortLevel: high
    if [[ "$line" =~ ^([a-zA-Z][a-zA-Z_]*):[[:space:]]+([^#\[]+)[[:space:]]*$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local val="${BASH_REMATCH[2]}"
      # Trim trailing whitespace
      val="${val%"${val##*[![:space:]]}"}"
      case "$key" in
        hooks)         OCTOPUS_HOOKS="$val" ;;
        knowledge_dir) OCTOPUS_KNOWLEDGE_DIR="$val" ;;
        effortLevel)   OCTOPUS_EFFORT_LEVEL="$val" ;;
        language)
          OCTOPUS_LANGUAGE_DOCS="$val"
          OCTOPUS_LANGUAGE_CODE="$val"
          OCTOPUS_LANGUAGE_UI="$val"
          ;;
      esac
      # Don't set current_section — this is an inline value, not a section
      continue
    fi

    # Detect section headers (top-level keys ending with :)
    # Handle inline empty arrays like "mcp: []"
    if [[ "$line" =~ ^([a-z]+):[[:space:]]*\[\][[:space:]]*$ ]]; then
      _flush_pending_cmd
      current_section="${BASH_REMATCH[1]}"
      continue
    fi
    if [[ "$line" =~ ^([a-z]+):$ ]]; then
      _flush_pending_cmd
      current_section="${BASH_REMATCH[1]}"
      current_knowledge_subsection=""
      current_knowledge_role=""
      current_permissions_subsection=""
      [[ "$current_section" == "permissions" ]] && OCTOPUS_PERMISSIONS_MODE="explicit"
      continue
    fi

    # Handle permissions: sub-sections (allow:/deny:)
    if [[ "$current_section" == "permissions" ]]; then
      if [[ "$line" =~ ^[[:space:]]+(allow|deny):[[:space:]]*$ ]]; then
        current_permissions_subsection="${BASH_REMATCH[1]}"
        continue
      fi
    fi

    # Handle knowledge: sub-sections (modules:/roles:) and role name entries
    if [[ "$current_section" == "knowledge" ]]; then
      if [[ "$line" =~ ^[[:space:]]+(modules|roles):[[:space:]]*$ ]]; then
        current_knowledge_subsection="${BASH_REMATCH[1]}"
        OCTOPUS_KNOWLEDGE_ENABLED="true"
        [[ "$current_knowledge_subsection" == "modules" ]] && OCTOPUS_KNOWLEDGE_MODE="explicit"
        current_knowledge_role=""
        continue
      fi
      if [[ "$current_knowledge_subsection" == "roles" && "$line" =~ ^[[:space:]]+([a-zA-Z][a-zA-Z0-9_-]*):[[:space:]]*$ ]]; then
        current_knowledge_role="${BASH_REMATCH[1]}"
        continue
      fi
    fi

    # Handle language: sub-keys (docs:, code:, ui:)
    if [[ "$current_section" == "language" ]]; then
      if [[ "$line" =~ ^[[:space:]]+(docs|code|ui):[[:space:]]+(.+)$ ]]; then
        local lang_key="${BASH_REMATCH[1]}"
        local lang_val="${BASH_REMATCH[2]}"
        lang_val="${lang_val%"${lang_val##*[![:space:]]}"}"
        case "$lang_key" in
          docs) OCTOPUS_LANGUAGE_DOCS="$lang_val" ;;
          code) OCTOPUS_LANGUAGE_CODE="$lang_val" ;;
          ui)   OCTOPUS_LANGUAGE_UI="$lang_val" ;;
        esac
        continue
      fi
    fi

    # Handle list items (  - value)
    if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
      local value="${BASH_REMATCH[1]}"

      # Check if it's a "name: value" entry
      if [[ "$value" =~ ^name:[[:space:]]+(.+)$ ]]; then
        if [[ "$current_section" == "commands" ]]; then
          _flush_pending_cmd
          pending_cmd_name="${BASH_REMATCH[1]}"
        else
          pending_agent_name="${BASH_REMATCH[1]}"
        fi
        continue
      fi

      case "$current_section" in
        rules)     OCTOPUS_RULES+=("$value") ;;
        skills)    OCTOPUS_SKILLS+=("$value") ;;
        agents)    OCTOPUS_AGENTS+=("$value") ;;
        mcp)       OCTOPUS_MCP+=("$value") ;;
        roles)     OCTOPUS_ROLES+=("$value") ;;
        reviewers) OCTOPUS_REVIEWERS+=("$value") ;;
        knowledge)
          if [[ "$current_knowledge_subsection" == "roles" && -n "$current_knowledge_role" ]]; then
            if [[ -n "${OCTOPUS_KNOWLEDGE_ROLES[$current_knowledge_role]:-}" ]]; then
              OCTOPUS_KNOWLEDGE_ROLES["$current_knowledge_role"]+=",$value"
            else
              OCTOPUS_KNOWLEDGE_ROLES["$current_knowledge_role"]="$value"
            fi
          else
            # Format B (simple list) or Format C modules sub-section
            OCTOPUS_KNOWLEDGE_LIST+=("$value")
            OCTOPUS_KNOWLEDGE_ENABLED="true"
            OCTOPUS_KNOWLEDGE_MODE="explicit"
          fi
          ;;
      esac
      continue
    fi

    # Handle indented key: value (for agent output override)
    if [[ "$line" =~ ^[[:space:]]+output:[[:space:]]+(.+)$ && -n "$pending_agent_name" ]]; then
      OCTOPUS_AGENTS+=("$pending_agent_name")
      OCTOPUS_AGENT_OUTPUT["$pending_agent_name"]="${BASH_REMATCH[1]}"
      pending_agent_name=""
      continue
    fi

    # Handle indented key: value (for command fields)
    if [[ "$current_section" == "commands" && -n "$pending_cmd_name" ]]; then
      if [[ "$line" =~ ^[[:space:]]+description:[[:space:]]+(.+)$ ]]; then
        pending_cmd_desc="${BASH_REMATCH[1]}"
        continue
      fi
      if [[ "$line" =~ ^[[:space:]]+run:[[:space:]]+(.+)$ ]]; then
        pending_cmd_run="${BASH_REMATCH[1]}"
        continue
      fi
    fi
  done < "$file"

  # Flush any pending entries
  if [[ -n "$pending_agent_name" ]]; then
    OCTOPUS_AGENTS+=("$pending_agent_name")
    pending_agent_name=""
  fi
  _flush_pending_cmd
}

# Manifest variables (populated by load_manifest)
MANIFEST_OUTPUT=""
MANIFEST_CONTENT_MODE=""
MANIFEST_CAP_RULES="false"
MANIFEST_CAP_SKILLS="false"
MANIFEST_CAP_HOOKS="false"
MANIFEST_CAP_COMMANDS="false"
MANIFEST_CAP_AGENTS="false"
MANIFEST_CAP_MCP="false"
MANIFEST_DELIVERY_RULES_METHOD=""
MANIFEST_DELIVERY_RULES_TARGET=""
MANIFEST_DELIVERY_SKILLS_METHOD=""
MANIFEST_DELIVERY_SKILLS_TARGET=""
MANIFEST_DELIVERY_HOOKS_METHOD=""
MANIFEST_DELIVERY_HOOKS_TARGET=""
MANIFEST_DELIVERY_COMMANDS_METHOD=""
MANIFEST_DELIVERY_COMMANDS_TARGET=""
MANIFEST_DELIVERY_COMMANDS_PREFIX=""
MANIFEST_DELIVERY_AGENTS_METHOD=""
MANIFEST_DELIVERY_AGENTS_TARGET=""
MANIFEST_DELIVERY_MCP_METHOD=""
MANIFEST_DELIVERY_MCP_TARGET=""
MANIFEST_DELIVERY_MCP_COMMAND=""
declare -a MANIFEST_MCP_EXTRA_METHODS=()
declare -a MANIFEST_MCP_EXTRA_TARGETS=()
declare -a MANIFEST_GITIGNORE_EXTRA=()

load_manifest() {
  local agent="$1"
  local manifest="$OCTOPUS_DIR/agents/$agent/manifest.yml"

  if [[ ! -f "$manifest" ]]; then
    echo "ERROR: No manifest found for agent '$agent'. Create agents/$agent/manifest.yml."
    exit 1
  fi

  # Reset manifest variables
  MANIFEST_OUTPUT=""
  MANIFEST_CONTENT_MODE=""
  MANIFEST_CAP_RULES="false"
  MANIFEST_CAP_SKILLS="false"
  MANIFEST_CAP_HOOKS="false"
  MANIFEST_CAP_COMMANDS="false"
  MANIFEST_CAP_AGENTS="false"
  MANIFEST_CAP_MCP="false"
  MANIFEST_DELIVERY_RULES_METHOD=""
  MANIFEST_DELIVERY_RULES_TARGET=""
  MANIFEST_DELIVERY_SKILLS_METHOD=""
  MANIFEST_DELIVERY_SKILLS_TARGET=""
  MANIFEST_DELIVERY_HOOKS_METHOD=""
  MANIFEST_DELIVERY_HOOKS_TARGET=""
  MANIFEST_DELIVERY_COMMANDS_METHOD=""
  MANIFEST_DELIVERY_COMMANDS_TARGET=""
  MANIFEST_DELIVERY_COMMANDS_PREFIX=""
  MANIFEST_DELIVERY_AGENTS_METHOD=""
  MANIFEST_DELIVERY_AGENTS_TARGET=""
  MANIFEST_DELIVERY_MCP_METHOD=""
  MANIFEST_DELIVERY_MCP_TARGET=""
  MANIFEST_DELIVERY_MCP_COMMAND=""
  MANIFEST_MCP_EXTRA_METHODS=()
  MANIFEST_MCP_EXTRA_TARGETS=()
  MANIFEST_GITIGNORE_EXTRA=()
  MANIFEST_CAP_KNOWLEDGE="false"
  MANIFEST_DELIVERY_KNOWLEDGE_METHOD=""
  MANIFEST_DELIVERY_KNOWLEDGE_TARGET=""

  local current_section=""
  local current_delivery=""
  local in_mcp_extra=false
  local in_gitignore_extra=false

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Top-level key: value (or inline empty array like "gitignore_extra: []")
    if [[ "$line" =~ ^([a-z_]+):[[:space:]]+(.+)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local val="${BASH_REMATCH[2]}"
      in_mcp_extra=false
      in_gitignore_extra=false
      case "$key" in
        output) MANIFEST_OUTPUT="$val" ;;
        content_mode) MANIFEST_CONTENT_MODE="$val" ;;
        name) ;; # informational only
        gitignore_extra) ;; # inline empty array, nothing to do
        mcp_extra) ;; # inline empty array, nothing to do
      esac
      continue
    fi

    # Section headers
    if [[ "$line" =~ ^([a-z_]+):$ ]]; then
      current_section="${BASH_REMATCH[1]}"
      current_delivery=""
      in_mcp_extra=false
      in_gitignore_extra=false
      if [[ "$current_section" == "mcp_extra" ]]; then
        in_mcp_extra=true
      elif [[ "$current_section" == "gitignore_extra" ]]; then
        in_gitignore_extra=true
      fi
      continue
    fi

    # Delivery sub-section (e.g., "  rules:")
    if [[ "$line" =~ ^[[:space:]]{2}([a-z_]+):$ && "$current_section" == "delivery" ]]; then
      current_delivery="${BASH_REMATCH[1]}"
      continue
    fi

    # Capability values (e.g., "  native_rules: true")
    if [[ "$line" =~ ^[[:space:]]+([a-z_]+):[[:space:]]+(true|false)$ && "$current_section" == "capabilities" ]]; then
      local cap_key="${BASH_REMATCH[1]}"
      local cap_val="${BASH_REMATCH[2]}"
      case "$cap_key" in
        native_rules)      MANIFEST_CAP_RULES="$cap_val" ;;
        native_skills)     MANIFEST_CAP_SKILLS="$cap_val" ;;
        native_hooks)      MANIFEST_CAP_HOOKS="$cap_val" ;;
        native_commands)   MANIFEST_CAP_COMMANDS="$cap_val" ;;
        native_agents)     MANIFEST_CAP_AGENTS="$cap_val" ;;
        native_mcp)        MANIFEST_CAP_MCP="$cap_val" ;;
        native_knowledge)  MANIFEST_CAP_KNOWLEDGE="$cap_val" ;;
      esac
      continue
    fi

    # Delivery key: value (e.g., "    method: symlink")
    if [[ "$line" =~ ^[[:space:]]+([a-z_]+):[[:space:]]+(.+)$ && "$current_section" == "delivery" && -n "$current_delivery" ]]; then
      local dkey="${BASH_REMATCH[1]}"
      local dval="${BASH_REMATCH[2]}"
      # Remove surrounding quotes
      dval="${dval%\"}"
      dval="${dval#\"}"
      case "${current_delivery}_${dkey}" in
        rules_method)    MANIFEST_DELIVERY_RULES_METHOD="$dval" ;;
        rules_target)    MANIFEST_DELIVERY_RULES_TARGET="$dval" ;;
        skills_method)   MANIFEST_DELIVERY_SKILLS_METHOD="$dval" ;;
        skills_target)   MANIFEST_DELIVERY_SKILLS_TARGET="$dval" ;;
        hooks_method)    MANIFEST_DELIVERY_HOOKS_METHOD="$dval" ;;
        hooks_target)    MANIFEST_DELIVERY_HOOKS_TARGET="$dval" ;;
        commands_method) MANIFEST_DELIVERY_COMMANDS_METHOD="$dval" ;;
        commands_target) MANIFEST_DELIVERY_COMMANDS_TARGET="$dval" ;;
        commands_prefix) MANIFEST_DELIVERY_COMMANDS_PREFIX="$dval" ;;
        agents_method)   MANIFEST_DELIVERY_AGENTS_METHOD="$dval" ;;
        agents_target)   MANIFEST_DELIVERY_AGENTS_TARGET="$dval" ;;
        mcp_method)        MANIFEST_DELIVERY_MCP_METHOD="$dval" ;;
        mcp_target)        MANIFEST_DELIVERY_MCP_TARGET="$dval" ;;
        mcp_command)       MANIFEST_DELIVERY_MCP_COMMAND="$dval" ;;
        knowledge_method)  MANIFEST_DELIVERY_KNOWLEDGE_METHOD="$dval" ;;
        knowledge_target)  MANIFEST_DELIVERY_KNOWLEDGE_TARGET="$dval" ;;
      esac
      continue
    fi

    # mcp_extra section
    if [[ "$line" =~ ^mcp_extra:$ ]]; then
      in_mcp_extra=true
      in_gitignore_extra=false
      current_section="mcp_extra"
      continue
    fi

    # mcp_extra list items (method/target)
    if [[ "$in_mcp_extra" == true ]]; then
      if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+method:[[:space:]]+(.+)$ ]]; then
        MANIFEST_MCP_EXTRA_METHODS+=("${BASH_REMATCH[1]}")
        continue
      fi
      if [[ "$line" =~ ^[[:space:]]+method:[[:space:]]+(.+)$ ]]; then
        MANIFEST_MCP_EXTRA_METHODS+=("${BASH_REMATCH[1]}")
        continue
      fi
      if [[ "$line" =~ ^[[:space:]]+target:[[:space:]]+(.+)$ ]]; then
        MANIFEST_MCP_EXTRA_TARGETS+=("${BASH_REMATCH[1]}")
        continue
      fi
    fi

    # gitignore_extra section
    if [[ "$line" =~ ^gitignore_extra:(.*)$ ]]; then
      local rest="${BASH_REMATCH[1]}"
      in_gitignore_extra=true
      in_mcp_extra=false
      current_section="gitignore_extra"
      # Handle inline empty array: "gitignore_extra: []"
      if [[ "$rest" =~ \[\] ]]; then
        in_gitignore_extra=false
      fi
      continue
    fi

    # gitignore_extra list items
    if [[ "$in_gitignore_extra" == true && "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
      MANIFEST_GITIGNORE_EXTRA+=("${BASH_REMATCH[1]}")
      continue
    fi
  done < "$manifest"
}

ensure_common_rule() {
  local has_common=false
  for r in "${OCTOPUS_RULES[@]}"; do
    [[ "$r" == "common" ]] && has_common=true
  done
  if ! $has_common; then
    OCTOPUS_RULES=("common" "${OCTOPUS_RULES[@]}")
  fi
}

# --- Manifest-driven generation functions ---

generate_from_template() {
  local agent="$1"
  local output_path="$2"
  local full_output="$PROJECT_ROOT/$output_path"

  echo "Generating $agent config (template) → $output_path"
  mkdir -p "$(dirname "$full_output")"

  # Build placeholder values
  local rules_lines=""
  local delivery_target="${MANIFEST_DELIVERY_RULES_TARGET:-.claude/rules}"
  for rule in "${OCTOPUS_RULES[@]}"; do
    rules_lines+="- See ${delivery_target}${rule}/ for ${rule} coding rules"$'\n'
  done
  rules_lines="${rules_lines%$'\n'}"

  local skills_lines=""
  local skills_target="${MANIFEST_DELIVERY_SKILLS_TARGET:-.claude/skills}"
  for skill in "${OCTOPUS_SKILLS[@]}"; do
    skills_lines+="- See ${skills_target}${skill}/ for ${skill} skill"$'\n'
  done
  skills_lines="${skills_lines%$'\n'}"

  # Build core content from CORE_FILES
  local core_content=""
  for core_file in "${CORE_FILES[@]}"; do
    if [[ -f "$OCTOPUS_DIR/$core_file" ]]; then
      core_content+="$(cat "$OCTOPUS_DIR/$core_file")"
      core_content+=$'\n\n'
    fi
  done

  local template="$OCTOPUS_DIR/agents/$agent/CLAUDE.md"
  awk -v rules="$rules_lines" -v skills="$skills_lines" -v core="$core_content" '{
    if ($0 == "{{RULES}}") {
      print rules
    } else if ($0 == "{{SKILLS}}") {
      if (skills != "") print skills
    } else if ($0 == "{{CORE}}") {
      if (core != "") print core
    } else {
      print
    }
  }' "$template" > "$full_output"

  # Copy settings.json if it exists
  if [[ -f "$OCTOPUS_DIR/agents/$agent/settings.json" ]]; then
    cp "$OCTOPUS_DIR/agents/$agent/settings.json" "$PROJECT_ROOT/$(dirname "$output_path")/settings.json"
  fi
}

concatenate_from_manifest() {
  local agent="$1"
  local output_path="$2"
  local full_output="$PROJECT_ROOT/$output_path"

  echo "Generating $agent config (concatenate) → $output_path"
  mkdir -p "$(dirname "$full_output")"

  # Start with header
  cat "$OCTOPUS_DIR/agents/$agent/header.md" > "$full_output"

  # Append core files in order
  for core_file in "${CORE_FILES[@]}"; do
    echo "" >> "$full_output"
    cat "$OCTOPUS_DIR/$core_file" >> "$full_output"
  done

  # Append rules (only if NOT delivered natively)
  if [[ "$MANIFEST_CAP_RULES" != "true" ]]; then
    for rule in "${OCTOPUS_RULES[@]}"; do
      local rule_dir="$OCTOPUS_DIR/rules/$rule"
      if [[ ! -d "$rule_dir" ]]; then continue; fi
      for rule_file in "$rule_dir"/*.md; do
        [[ -f "$rule_file" ]] || continue
        echo "" >> "$full_output"
        cat "$rule_file" >> "$full_output"
      done
    done

    # Append project rule overrides from .octopus/rules/ (.local.md files win by position)
    local octopus_rules_overrides="$PROJECT_ROOT/.octopus/rules"
    if [[ -d "$octopus_rules_overrides" ]]; then
      for rule in "${OCTOPUS_RULES[@]}"; do
        local override_dir="$octopus_rules_overrides/$rule"
        [[ -d "$override_dir" ]] || continue
        for local_file in "$override_dir"/*.local.md; do
          [[ -f "$local_file" ]] || continue
          echo "" >> "$full_output"
          cat "$local_file" >> "$full_output"
        done
      done
    fi

    # Only inject language override when 'common' rule set is active
    if [[ " ${OCTOPUS_RULES[*]} " == *" common "* ]]; then
      # If language: is configured but no .octopus/rules/common/language.local.md exists,
      # generate the override inline (so concat agents also get explicit language rules)
      if [[ -n "$OCTOPUS_LANGUAGE_DOCS" || -n "$OCTOPUS_LANGUAGE_CODE" || -n "$OCTOPUS_LANGUAGE_UI" ]]; then
        if [[ ! -f "$PROJECT_ROOT/.octopus/rules/common/language.local.md" ]]; then
          local docs="${OCTOPUS_LANGUAGE_DOCS:-en}"
          local code="${OCTOPUS_LANGUAGE_CODE:-en}"
          local ui="${OCTOPUS_LANGUAGE_UI:-en}"
          {
            echo ""
            echo "# Language (Project Override)"
            echo ""
            echo "This file overrides \`language.md\` for this project."
            echo "Configured explicitly in \`.octopus.yml\`."
            echo ""
            echo "- **Documentation & deliverables** (specs, ADRs, commits, PRs): **${docs}**"
            echo "- **Code comments**: **${code}**"
            echo "- **Code identifiers** (function/class/variable names): **en** (always English)"
            echo "- **User-facing content** (UI, messages, copy): **${ui}**"
            echo ""
            echo "Conversation language does NOT influence these rules."
          } >> "$full_output"
        fi
      fi
    fi
  fi

  # Append skills (only if NOT delivered natively)
  if [[ "$MANIFEST_CAP_SKILLS" != "true" ]]; then
    for skill in "${OCTOPUS_SKILLS[@]}"; do
      local skill_file="$OCTOPUS_DIR/skills/$skill/SKILL.md"
      if [[ -f "$skill_file" ]]; then
        echo "" >> "$full_output"
        cat "$skill_file" >> "$full_output"
      fi
    done
  fi

  # Append commands section (only if NOT delivered natively)
  if [[ "$MANIFEST_CAP_COMMANDS" != "true" ]]; then
    append_commands_section "$full_output"
  fi
}

generate_main_output() {
  local agent="$1"
  local output_path="${OCTOPUS_AGENT_OUTPUT[$agent]:-$MANIFEST_OUTPUT}"

  if [[ -z "$output_path" ]]; then
    echo "WARNING: No output path defined for agent '$agent'. Skipping."
    return
  fi

  if [[ "$MANIFEST_CONTENT_MODE" == "template" ]]; then
    generate_from_template "$agent" "$output_path"
  else
    concatenate_from_manifest "$agent" "$output_path"
  fi
}

# Generates language.local.md in a rules directory if language is configured.
# Priority: .octopus/rules/common/language.local.md file > language: config > nothing
_generate_language_local() {
  local target_dir="$1"

  # Priority 1: project .octopus/rules/common/language.local.md
  local project_override="$PROJECT_ROOT/.octopus/rules/common/language.local.md"
  if [[ -f "$project_override" ]]; then
    cp "$project_override" "$target_dir/language.local.md"
    echo "  -> language.local.md (from .octopus/rules/common/)"
    return
  fi

  # Priority 2: generate from language: config in .octopus.yml
  if [[ -n "$OCTOPUS_LANGUAGE_DOCS" || -n "$OCTOPUS_LANGUAGE_CODE" || -n "$OCTOPUS_LANGUAGE_UI" ]]; then
    local docs="${OCTOPUS_LANGUAGE_DOCS:-en}"
    local code="${OCTOPUS_LANGUAGE_CODE:-en}"
    local ui="${OCTOPUS_LANGUAGE_UI:-en}"
    cat > "$target_dir/language.local.md" << 'LANGEOF'
# Language (Project Override)

This file overrides `language.md` for this project.
Configured explicitly in `.octopus.yml`.
LANGEOF
    cat >> "$target_dir/language.local.md" << LANGEOF

- **Documentation & deliverables** (specs, ADRs, commits, PRs): **${docs}**
- **Code comments**: **${code}**
- **Code identifiers** (function/class/variable names): **en** (always English)
- **User-facing content** (UI, messages, copy): **${ui}**

Conversation language does NOT influence these rules.
LANGEOF
    echo "  -> language.local.md (generated from language: config)"
    return
  fi

  # No override — language.md detection rule is sufficient, no .local.md needed
}

deliver_rules() {
  local agent="$1"
  if [[ "$MANIFEST_CAP_RULES" != "true" ]]; then return; fi

  local method="$MANIFEST_DELIVERY_RULES_METHOD"
  local target="$PROJECT_ROOT/$MANIFEST_DELIVERY_RULES_TARGET"

  if [[ "$method" == "symlink" ]]; then
    echo "Generating rules symlinks for $agent..."
    rm -rf "$target"
    mkdir -p "$target"
    for rule in "${OCTOPUS_RULES[@]}"; do
      local source_dir="$OCTOPUS_DIR/rules/$rule"
      if [[ ! -d "$source_dir" ]]; then
        echo "  WARNING: Rules directory '$source_dir' not found. Skipping."
        continue
      fi
      mkdir -p "$target/$rule"
      for f in "$source_dir"/*.md; do
        [[ -f "$f" ]] || continue
        ln -sf "$f" "$target/$rule/$(basename "$f")"
      done
      echo "  -> ${MANIFEST_DELIVERY_RULES_TARGET}$rule/ (per-file symlinks)"
      # Generate language.local.md for the common rule directory
      if [[ "$rule" == "common" ]]; then
        _generate_language_local "$target/$rule"
      fi
    done
  fi
}

declare -a KNOWLEDGE_MODULES=()         # resolved modules after discover_knowledge()

deliver_skills() {
  local agent="$1"
  if [[ "$MANIFEST_CAP_SKILLS" != "true" ]]; then return; fi
  if [[ ${#OCTOPUS_SKILLS[@]} -eq 0 ]]; then return; fi

  local method="$MANIFEST_DELIVERY_SKILLS_METHOD"
  local target="$PROJECT_ROOT/$MANIFEST_DELIVERY_SKILLS_TARGET"

  if [[ "$method" == "symlink" ]]; then
    echo "Generating skills symlinks for $agent..."
    rm -rf "$target"
    mkdir -p "$target"
    for skill in "${OCTOPUS_SKILLS[@]}"; do
      local source_dir="$OCTOPUS_DIR/skills/$skill"
      if [[ ! -d "$source_dir" ]]; then
        echo "  WARNING: Skill directory '$source_dir' not found. Skipping."
        continue
      fi
      ln -s "$source_dir" "$target/$skill"
      echo "  -> ${MANIFEST_DELIVERY_SKILLS_TARGET}$skill"
    done
  fi
}

discover_knowledge() {
  KNOWLEDGE_MODULES=()
  local knowledge_dir="$PROJECT_ROOT/$OCTOPUS_KNOWLEDGE_DIR"
  [[ "$OCTOPUS_KNOWLEDGE_ENABLED" != "true" ]] && return
  [[ ! -d "$knowledge_dir" ]] && { echo "  WARNING: knowledge: enabled but no ${OCTOPUS_KNOWLEDGE_DIR}/ directory found."; return; }

  if [[ "$OCTOPUS_KNOWLEDGE_MODE" == "auto" ]]; then
    for dir in "$knowledge_dir"/*/; do
      [[ ! -d "$dir" ]] && continue
      local name; name=$(basename "$dir")
      [[ "$name" == _* ]] && continue
      KNOWLEDGE_MODULES+=("$name")
    done
  else
    for mod in "${OCTOPUS_KNOWLEDGE_LIST[@]}"; do
      if [[ -d "$knowledge_dir/$mod" ]]; then
        KNOWLEDGE_MODULES+=("$mod")
      else
        echo "  WARNING: Knowledge module '$mod' not found in ${OCTOPUS_KNOWLEDGE_DIR}/. Skipping."
      fi
    done
  fi
}

assemble_knowledge() {
  local role="${1:-}"
  local knowledge_dir="$PROJECT_ROOT/$OCTOPUS_KNOWLEDGE_DIR"
  local content=""

  local -a modules_for_role=()
  if [[ -n "$role" && -n "${OCTOPUS_KNOWLEDGE_ROLES[$role]:-}" ]]; then
    IFS=',' read -ra modules_for_role <<< "${OCTOPUS_KNOWLEDGE_ROLES[$role]}"
  else
    modules_for_role=("${KNOWLEDGE_MODULES[@]}")
  fi

  for mod in "${modules_for_role[@]}"; do
    local mod_dir="$knowledge_dir/$mod"
    [[ ! -d "$mod_dir" ]] && continue
    content+=$'\n'"# Knowledge: ${mod}"$'\n\n'
    while IFS= read -r md_file; do
      local fname; fname=$(basename "$md_file")
      [[ "$fname" == "INDEX.md" ]] && continue
      content+="$(cat "$md_file")"
      content+=$'\n\n'
    done < <(find "$mod_dir" -name '*.md' -type f | sort)
  done

  echo "$content"
}

deliver_knowledge() {
  local agent="$1"
  [[ ${#KNOWLEDGE_MODULES[@]} -eq 0 ]] && return
  [[ "$MANIFEST_CAP_KNOWLEDGE" != "true" ]] && return

  local method="$MANIFEST_DELIVERY_KNOWLEDGE_METHOD"
  # Strip trailing slash so ln -s works correctly
  local target; target="${PROJECT_ROOT}/${MANIFEST_DELIVERY_KNOWLEDGE_TARGET%/}"

  if [[ "$method" == "symlink" ]]; then
    echo "Generating knowledge symlink for $agent..."
    mkdir -p "$(dirname "$target")"
    rm -rf "$target"
    ln -s "$PROJECT_ROOT/$OCTOPUS_KNOWLEDGE_DIR" "$target"
    echo "  → ${MANIFEST_DELIVERY_KNOWLEDGE_TARGET} -> ${OCTOPUS_KNOWLEDGE_DIR}/"
  fi
}

generate_knowledge_index() {
  local knowledge_dir="$PROJECT_ROOT/$OCTOPUS_KNOWLEDGE_DIR"
  [[ "$OCTOPUS_KNOWLEDGE_ENABLED" != "true" && ${#KNOWLEDGE_MODULES[@]} -eq 0 ]] && return
  [[ ! -d "$knowledge_dir" ]] && return

  local index_file="$knowledge_dir/INDEX.md"

  cat > "$index_file" << 'HEADER'
# Knowledge Index

<!--
  Auto-generated by Octopus setup.sh — do not edit manually.
  Routing table for AI agents — consult this file to find relevant domain knowledge.
-->

## Domain Map

| Domain | Path | Files | Status |
|---|---|---|---|
HEADER

  if [[ ${#KNOWLEDGE_MODULES[@]} -eq 0 ]]; then
    echo "| _none configured_ | \`${OCTOPUS_KNOWLEDGE_DIR}/\` | 0 | Pending |" >> "$index_file"
  else
    for mod in "${KNOWLEDGE_MODULES[@]}"; do
      local mod_dir="$knowledge_dir/$mod"
      local file_count
      file_count=$(find "$mod_dir" -name '*.md' -type f | wc -l | tr -d ' ')
      echo "| ${mod} | \`${OCTOPUS_KNOWLEDGE_DIR}/${mod}/\` | ${file_count} | Active |" >> "$index_file"
    done
  fi

  cat >> "$index_file" << 'FOOTER'

## How to Use

1. **Before a task**: Read this index, then load the relevant domain's files
2. **During a task**: If you discover new patterns, add to `knowledge.md` or `hypotheses.md`
3. **After a task**: Update knowledge files with confirmed findings

If no active modules are listed yet, create a domain from `knowledge/_template/`
and re-run `setup.sh`.
FOOTER

  echo "  → ${OCTOPUS_KNOWLEDGE_DIR}/INDEX.md (auto-generated)"
}

deliver_hooks() {
  local agent="$1"
  if [[ "$MANIFEST_CAP_HOOKS" != "true" ]]; then return; fi
  if [[ "$OCTOPUS_HOOKS" == "false" ]]; then return; fi

  local method="$MANIFEST_DELIVERY_HOOKS_METHOD"

  if [[ "$method" == "settings_json" ]]; then
    local settings_file="$PROJECT_ROOT/$MANIFEST_DELIVERY_HOOKS_TARGET"
    local hooks_template="$OCTOPUS_DIR/hooks/hooks.json"

    if [[ ! -f "$hooks_template" || ! -f "$settings_file" ]]; then
      echo "WARNING: hooks.json or settings.json not found. Skipping hooks for $agent."
      return
    fi

    echo "Injecting hooks into $MANIFEST_DELIVERY_HOOKS_TARGET for $agent..."

    python3 - "$settings_file" "$hooks_template" "${OCTOPUS_DISABLED_HOOKS:-}" << 'PYEOF'
import json, sys

settings_path, hooks_path, disabled = sys.argv[1], sys.argv[2], sys.argv[3]

with open(settings_path) as f:
    settings = json.load(f)
with open(hooks_path) as f:
    hooks = json.load(f)

# Filter disabled hooks (comma-separated list from env)
if disabled:
    disabled_set = set(d.strip() for d in disabled.split(",") if d.strip())
    for event_type in list(hooks.keys()):
        hooks[event_type] = [
            h for h in hooks[event_type]
            if h.get("id", "") not in disabled_set
        ]

settings["hooks"] = hooks
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
    echo "  -> Hooks injected into $MANIFEST_DELIVERY_HOOKS_TARGET"
  fi
}

deliver_permissions() {
  local agent="$1"
  if [[ "$OCTOPUS_PERMISSIONS_MODE" == "" ]]; then return; fi
  if [[ "$MANIFEST_DELIVERY_HOOKS_METHOD" != "settings_json" ]]; then return; fi

  local settings_file="$PROJECT_ROOT/$MANIFEST_DELIVERY_HOOKS_TARGET"

  if [[ ! -f "$settings_file" ]]; then
    echo "WARNING: settings.json not found at $MANIFEST_DELIVERY_HOOKS_TARGET. Skipping permissions for $agent."
    return
  fi

  # Only Claude's settings.json has a top-level "permissions" field with allow/deny lists.
  # OpenCode uses a different schema ("permission" singular, per-tool mode strings) that is
  # incompatible with this allow/deny list model — skip it.
  if [[ "$agent" != "claude" ]]; then return; fi

  # Build allow/deny arrays: use defaults when mode is "defaults", explicit lists otherwise
  local allow_json="[]"
  local deny_json="[]"

  if [[ "$OCTOPUS_PERMISSIONS_MODE" == "defaults" ]]; then
    # Detect language from OCTOPUS_RULES
    local has_node="false"
    for rule in "${OCTOPUS_RULES[@]}"; do
      if [[ "$rule" == "typescript" || "$rule" == "node" ]]; then
        has_node="true"
        break
      fi
    done

    if [[ "$has_node" == "true" ]]; then
      allow_json='["Bash(git *)", "Bash(gh *)", "Bash(bun run *)", "Bash(npm run *)", "Bash(npx *)"]'
    else
      allow_json='["Bash(git *)", "Bash(gh *)"]'
    fi
  else
    # Build JSON arrays from explicit allow/deny lists
    allow_json=$(python3 -c "
import json, sys
items = sys.argv[1:]
print(json.dumps(items))
" "${OCTOPUS_PERMISSIONS_ALLOW[@]+"${OCTOPUS_PERMISSIONS_ALLOW[@]}"}")
    deny_json=$(python3 -c "
import json, sys
items = sys.argv[1:]
print(json.dumps(items))
" "${OCTOPUS_PERMISSIONS_DENY[@]+"${OCTOPUS_PERMISSIONS_DENY[@]}"}")
  fi

  echo "Injecting permissions into $MANIFEST_DELIVERY_HOOKS_TARGET for $agent..."

  python3 - "$settings_file" "$allow_json" "$deny_json" << 'PYEOF'
import json, sys

settings_path, allow_json, deny_json = sys.argv[1], sys.argv[2], sys.argv[3]

with open(settings_path) as f:
    settings = json.load(f)

allow_new = json.loads(allow_json)
deny_new = json.loads(deny_json)

perms = settings.setdefault("permissions", {})

# Merge allow list (dedup, preserve order)
existing_allow = perms.get("allow", [])
merged_allow = list(existing_allow)
for entry in allow_new:
    if entry not in merged_allow:
        merged_allow.append(entry)
if merged_allow:
    perms["allow"] = merged_allow
elif "allow" in perms:
    del perms["allow"]

# Merge deny list (dedup, preserve order)
existing_deny = perms.get("deny", [])
merged_deny = list(existing_deny)
for entry in deny_new:
    if entry not in merged_deny:
        merged_deny.append(entry)
if merged_deny:
    perms["deny"] = merged_deny
elif "deny" in perms:
    del perms["deny"]

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
  echo "  → Permissions injected into $MANIFEST_DELIVERY_HOOKS_TARGET"
}

deliver_effort_level() {
  local agent="$1"
  if [[ -z "$OCTOPUS_EFFORT_LEVEL" ]]; then return; fi
  if [[ "$agent" != "claude" ]]; then return; fi
  if [[ "$MANIFEST_DELIVERY_HOOKS_METHOD" != "settings_json" ]]; then return; fi

  local settings_file="$PROJECT_ROOT/$MANIFEST_DELIVERY_HOOKS_TARGET"

  if [[ ! -f "$settings_file" ]]; then
    echo "WARNING: settings.json not found at $MANIFEST_DELIVERY_HOOKS_TARGET. Skipping effortLevel for $agent."
    return
  fi

  echo "Injecting effortLevel into $MANIFEST_DELIVERY_HOOKS_TARGET for $agent..."

  python3 - "$settings_file" "$OCTOPUS_EFFORT_LEVEL" << 'PYEOF' || return $?
import json, sys

settings_path, effort_level = sys.argv[1], sys.argv[2]

valid = {"low", "medium", "high", "max"}
if effort_level not in valid:
    print(f"ERROR: Invalid effortLevel '{effort_level}'. Valid values: {sorted(valid)}", file=sys.stderr)
    sys.exit(1)

with open(settings_path) as f:
    settings = json.load(f)

settings["effortLevel"] = effort_level

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
  echo "  → effortLevel=${OCTOPUS_EFFORT_LEVEL} injected into $MANIFEST_DELIVERY_HOOKS_TARGET"
}

# Core files in fixed concatenation order
CORE_FILES=(
  "core/guidelines.md"
  "core/architecture.md"
  "core/commit-conventions.md"
  "core/pr-workflow.md"
  "core/task-management.md"
)

strip_frontmatter() {
  local file="$1"
  # Remove YAML frontmatter (--- to ---) from beginning of file
  awk 'BEGIN{skip=0} /^---$/{skip++; if(skip<=2) next} skip>=2||skip==0{print}' "$file"
}

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

normalize_role_color() {
  local raw_color="$1"
  local color
  color="$(trim_whitespace "$raw_color")"

  if [[ "$color" =~ ^[\"\'](.*)[\"\']$ ]]; then
    color="${BASH_REMATCH[1]}"
  fi

  local normalized="${color,,}"

  if [[ "$normalized" =~ ^#[0-9a-f]{6}$ || "$normalized" =~ ^#[0-9a-f]{3}$ ]]; then
    printf '%s' "$normalized"
    return
  fi

  case "$normalized" in
    black)   printf '#000000' ;;
    blue)    printf '#0000ff' ;;
    brown)   printf '#a52a2a' ;;
    cyan)    printf '#00ffff' ;;
    gray|grey) printf '#808080' ;;
    green)   printf '#008000' ;;
    orange)  printf '#ffa500' ;;
    pink)    printf '#ffc0cb' ;;
    purple)  printf '#800080' ;;
    red)     printf '#ff0000' ;;
    teal)    printf '#008080' ;;
    white)   printf '#ffffff' ;;
    yellow)  printf '#ffff00' ;;
    *)       printf '%s' "$color" ;;
  esac
}

normalize_role_frontmatter_for_agent() {
  local agent="$1"

  if [[ "$agent" != "opencode" ]]; then
    cat
    return
  fi

  local frontmatter_index=0
  local in_frontmatter=false
  local line=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "---" ]]; then
      frontmatter_index=$((frontmatter_index + 1))
      if [[ $frontmatter_index -eq 1 ]]; then
        in_frontmatter=true
      elif [[ $frontmatter_index -eq 2 ]]; then
        in_frontmatter=false
      fi
      printf '%s\n' "$line"
      continue
    fi

    if [[ "$in_frontmatter" == "true" && "$line" =~ ^color:[[:space:]]*(.+)$ ]]; then
      printf 'color: %s\n' "$(normalize_role_color "${BASH_REMATCH[1]}")"
      continue
    fi

    printf '%s\n' "$line"
  done
}

deliver_roles() {
  local agent="$1"
  if [[ ${#OCTOPUS_ROLES[@]} -eq 0 ]]; then return; fi

  # Load base content once (cached across calls)
  if [[ -z "${_ROLES_CONTEXT_LOADED:-}" ]]; then
    _ROLES_BASE_CONTENT=""
    if [[ -f "$OCTOPUS_DIR/roles/_base.md" ]]; then
      _ROLES_BASE_CONTENT=$(cat "$OCTOPUS_DIR/roles/_base.md")
    fi
    _ROLES_CONTEXT_LOADED="true"
  fi

  local output_path="${OCTOPUS_AGENT_OUTPUT[$agent]:-$MANIFEST_OUTPUT}"

  for role in "${OCTOPUS_ROLES[@]}"; do
    local template="$OCTOPUS_DIR/roles/${role}.md"
    if [[ ! -f "$template" ]]; then
      echo "WARNING: Role template '$template' not found. Skipping."
      continue
    fi

    # Build context for this role
    local context_content=""
    if [[ ${#KNOWLEDGE_MODULES[@]} -gt 0 ]]; then
      context_content="$(assemble_knowledge "$role")"
    fi

    local role_content
    role_content=$(awk -v ctx="$context_content" '{
      if ($0 == "{{PROJECT_CONTEXT}}") {
        print ctx
      } else {
        print
      }
    }' "$template" | normalize_role_frontmatter_for_agent "$agent")

    if [[ "$MANIFEST_CAP_AGENTS" == "true" ]]; then
      # Native delivery: individual role files
      local target_dir="$PROJECT_ROOT/$MANIFEST_DELIVERY_AGENTS_TARGET"
      mkdir -p "$target_dir"
      echo "$role_content" > "$target_dir/${role}.md"
      if [[ -n "$_ROLES_BASE_CONTENT" ]]; then
        echo "" >> "$target_dir/${role}.md"
        echo "$_ROLES_BASE_CONTENT" >> "$target_dir/${role}.md"
      fi
      echo "  → ${MANIFEST_DELIVERY_AGENTS_TARGET}${role}.md"
    else
      # Inline delivery: append to concatenated output
      local full_output="$PROJECT_ROOT/$output_path"
      if [[ ! -f "$full_output" ]]; then continue; fi

      local role_title
      role_title="$(echo "${role:0:1}" | tr '[:lower:]' '[:upper:]')${role:1}"
      echo "" >> "$full_output"
      echo "# Role: $role_title" >> "$full_output"
      echo "" >> "$full_output"
      strip_frontmatter "$template" | awk -v ctx="$context_content" '{
        if ($0 == "{{PROJECT_CONTEXT}}") {
          print ctx
        } else {
          print
        }
      }' >> "$full_output"
      if [[ -n "$_ROLES_BASE_CONTENT" ]]; then
        echo "" >> "$full_output"
        echo "$_ROLES_BASE_CONTENT" >> "$full_output"
      fi
    fi
  done
}

# Track generated workflow command names for collision detection
declare -a GENERATED_WORKFLOW_CMDS=()

deliver_commands() {
  local agent="$1"
  local output_path="${OCTOPUS_AGENT_OUTPUT[$agent]:-$MANIFEST_OUTPUT}"
  local prefix="${MANIFEST_DELIVERY_COMMANDS_PREFIX:-octopus:}"

  if [[ "$MANIFEST_CAP_COMMANDS" == "true" ]]; then
    # Native delivery: individual command files
    local commands_dir="$PROJECT_ROOT/$MANIFEST_DELIVERY_COMMANDS_TARGET"
    mkdir -p "$commands_dir"

    # Workflow commands
    if [[ "$OCTOPUS_WORKFLOW" == "true" ]]; then
      for cmd_file in "$OCTOPUS_DIR/commands/"*.md; do
        [[ -f "$cmd_file" ]] || continue
        local cmd_name
        cmd_name=$(basename "$cmd_file" .md)
        GENERATED_WORKFLOW_CMDS+=("$cmd_name")
        strip_frontmatter "$cmd_file" \
          | sed "s|\./octopus/cli/octopus\\.sh|./${OCTOPUS_CLI_REL}|g" \
          | sed '/./,$!d' \
          > "$commands_dir/${prefix}${cmd_name}.md"
        echo "  → ${MANIFEST_DELIVERY_COMMANDS_TARGET}${prefix}${cmd_name}.md"
      done
    fi

    # Custom commands
    if [[ ${#OCTOPUS_CMD_NAMES[@]} -gt 0 ]]; then
      echo "Generating custom slash commands for $agent..."
      for i in "${!OCTOPUS_CMD_NAMES[@]}"; do
        local name="${OCTOPUS_CMD_NAMES[$i]}"

        # Check collision with workflow commands
        local collision=false
        for wf_cmd in "${GENERATED_WORKFLOW_CMDS[@]:-}"; do
          if [[ "$wf_cmd" == "$name" ]]; then
            echo "WARNING: Custom command '$name' conflicts with workflow command. Skipping."
            collision=true
            break
          fi
        done
        [[ "$collision" == true ]] && continue

        local desc="${OCTOPUS_CMD_DESCS[$i]}"
        local run="${OCTOPUS_CMD_RUNS[$i]}"
        cat > "$commands_dir/${prefix}${name}.md" << EOF
---
description: ${desc}
---

Run the following command:

\`\`\`bash
${run}
\`\`\`
EOF
        echo "  → ${MANIFEST_DELIVERY_COMMANDS_TARGET}${prefix}${name}.md"
      done
    fi
  else
    # Inline delivery: workflow commands appended to output
    local full_output="$PROJECT_ROOT/$output_path"
    [[ -f "$full_output" ]] || return

    if [[ "$OCTOPUS_WORKFLOW" == "true" ]]; then
      echo "" >> "$full_output"
      echo "# Octopus Commands" >> "$full_output"
      echo "" >> "$full_output"
      echo "When the user invokes any of these commands, follow the instructions and execute the CLI script." >> "$full_output"

      for cmd_file in "$OCTOPUS_DIR/commands/"*.md; do
        [[ -f "$cmd_file" ]] || continue
        local cmd_name cmd_desc
        cmd_name=$(basename "$cmd_file" .md)
        cmd_desc=$(grep '^description:' "$cmd_file" 2>/dev/null | head -1 | sed 's/^description:[[:space:]]*//' || true)

        echo "" >> "$full_output"
        echo "## /octopus:${cmd_name}" >> "$full_output"
        echo "${cmd_desc}" >> "$full_output"
        echo "Run: \`./octopus/cli/octopus.sh ${cmd_name}\`" >> "$full_output"
      done
    fi

    # Custom commands section is already appended by concatenate_from_manifest via append_commands_section
  fi
}

append_commands_section() {
  local output_file="$1"

  if [[ ${#OCTOPUS_CMD_NAMES[@]} -eq 0 ]]; then
    return
  fi

  echo "" >> "$output_file"
  echo "# Custom Project Commands" >> "$output_file"
  echo "" >> "$output_file"
  echo "The following commands are available for common project tasks:" >> "$output_file"
  echo "" >> "$output_file"
  for i in "${!OCTOPUS_CMD_NAMES[@]}"; do
    local name="${OCTOPUS_CMD_NAMES[$i]}"
    local desc="${OCTOPUS_CMD_DESCS[$i]}"
    local run="${OCTOPUS_CMD_RUNS[$i]}"
    echo "- **/octopus:${name}** — ${desc}: \`${run}\`" >> "$output_file"
  done
}

# --- MCP delivery sub-functions ---

_build_mcp_merged() {
  # Build merged MCP JSON from declared servers (returns temp file path)
  local tmp_merged
  tmp_merged=$(mktemp)
  echo '{}' > "$tmp_merged"

  for server in "${OCTOPUS_MCP[@]}"; do
    local server_file="$OCTOPUS_DIR/mcp/${server}.json"
    if [[ ! -f "$server_file" ]]; then
      echo "WARNING: MCP config '$server_file' not found. Skipping."
      continue
    fi
    python3 - "$tmp_merged" "$server_file" << 'PYEOF'
import json, sys
base_path, new_path = sys.argv[1], sys.argv[2]
with open(base_path) as f:
    base = json.load(f)
with open(new_path) as f:
    new = json.load(f)
base.update(new)
with open(base_path, 'w') as f:
    json.dump(base, f)
PYEOF
  done
  echo "$tmp_merged"
}

_inject_mcp_settings_json() {
  local target="$1"
  local merged="$2"
  local settings_file="$PROJECT_ROOT/$target"

  if [[ ! -f "$settings_file" ]]; then return; fi

  python3 - "$settings_file" "$merged" << 'PYEOF'
import json, sys
settings_path, mcp_path = sys.argv[1], sys.argv[2]
with open(settings_path) as f:
    settings = json.load(f)
with open(mcp_path) as f:
    mcp = json.load(f)
settings['mcpServers'] = mcp
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
PYEOF
  echo "  → Injected MCP into $target"
}

_inject_mcp_vscode_json() {
  local target="$1"
  local merged="$2"
  local target_path="$PROJECT_ROOT/$target"

  mkdir -p "$(dirname "$target_path")"

  python3 - "$merged" "$target_path" << 'PYEOF'
import json, sys

merged_path, output_path = sys.argv[1], sys.argv[2]
with open(merged_path) as f:
    servers = json.load(f)

vscode_servers = {}
for name, config in servers.items():
    if config.get("type") == "http" or "url" in config:
        vscode_servers[name] = {"type": "http", "url": config["url"]}
    elif "command" in config:
        entry = {"type": "stdio", "command": config["command"]}
        if "args" in config:
            entry["args"] = config["args"]
        entry["envFile"] = "${workspaceFolder}/.env.octopus"
        vscode_servers[name] = entry

try:
    with open(output_path) as f:
        existing = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    existing = {}

existing["servers"] = vscode_servers
with open(output_path, 'w') as f:
    json.dump(existing, f, indent=2)
    f.write('\n')
PYEOF
  echo "  → Generated $target"
}

_inject_mcp_copilot_cli() {
  local target="$1"
  local merged="$2"

  # Expand ~ to $HOME
  local target_path="${target/#\~/$HOME}"
  mkdir -p "$(dirname "$target_path")"

  python3 - "$merged" "$target_path" << 'PYEOF'
import json, sys

merged_path, output_path = sys.argv[1], sys.argv[2]
with open(merged_path) as f:
    servers = json.load(f)

cli_servers = {}
for name, config in servers.items():
    if config.get("type") == "http" or "url" in config:
        cli_servers[name] = {"type": "http", "url": config["url"]}
    elif "command" in config:
        entry = {"type": "local", "command": config["command"]}
        if "args" in config:
            entry["args"] = config["args"]
        if "env" in config:
            entry["env"] = config["env"]
        cli_servers[name] = entry

try:
    with open(output_path) as f:
        existing = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    existing = {}

existing["mcpServers"] = cli_servers
with open(output_path, 'w') as f:
    json.dump(existing, f, indent=2)
    f.write('\n')
PYEOF
  echo "  → Generated $target"
}

_inject_mcp_cli_add() {
  local command_prefix="$1"

  if ! command -v "${command_prefix%% *}" &>/dev/null; then return; fi

  for server in "${OCTOPUS_MCP[@]}"; do
    local server_file="$OCTOPUS_DIR/mcp/${server}.json"
    [[ -f "$server_file" ]] || continue
    # Remove existing server config first (ignore errors)
    $command_prefix remove "$server" 2>/dev/null || true
    if ! python3 - "$server_file" "$server" "$command_prefix" << 'PYEOF'
import json, sys, subprocess, shlex
server_file, server_name, cmd_prefix = sys.argv[1], sys.argv[2], sys.argv[3]
with open(server_file) as f:
    data = json.load(f)
config = data[server_name]
cmd = shlex.split(cmd_prefix) + ["add", server_name]
if config.get("type") == "http" and "url" in config:
    cmd.extend(["--url", config["url"]])
elif "command" in config:
    for k, v in config.get("env", {}).items():
        cmd.extend(["--env", f"{k}={v}"])
    cmd.append("--")
    cmd.append(config["command"])
    cmd.extend(config.get("args", []))
result = subprocess.run(cmd)
sys.exit(result.returncode)
PYEOF
    then
      echo "  WARNING: Failed to inject '$server' via $command_prefix"
    fi
  done
  echo "  → Injected MCP servers via $command_prefix"
}

deliver_mcp() {
  local agent="$1"
  if [[ "$MANIFEST_CAP_MCP" != "true" ]]; then return; fi
  if [[ ${#OCTOPUS_MCP[@]} -eq 0 ]]; then return; fi

  echo "Injecting MCP servers for $agent..."

  # Build merged MCP object once per agent
  local tmp_merged
  tmp_merged=$(_build_mcp_merged)

  # Primary delivery method
  local method="$MANIFEST_DELIVERY_MCP_METHOD"
  case "$method" in
    settings_json)  _inject_mcp_settings_json "$MANIFEST_DELIVERY_MCP_TARGET" "$tmp_merged" ;;
    vscode_json)    _inject_mcp_vscode_json "$MANIFEST_DELIVERY_MCP_TARGET" "$tmp_merged" ;;
    copilot_cli)    _inject_mcp_copilot_cli "$MANIFEST_DELIVERY_MCP_TARGET" "$tmp_merged" ;;
    cli_add)        _inject_mcp_cli_add "$MANIFEST_DELIVERY_MCP_COMMAND" ;;
  esac

  # Extra MCP delivery targets
  for i in "${!MANIFEST_MCP_EXTRA_METHODS[@]}"; do
    local extra_method="${MANIFEST_MCP_EXTRA_METHODS[$i]}"
    local extra_target="${MANIFEST_MCP_EXTRA_TARGETS[$i]:-}"
    case "$extra_method" in
      settings_json)  _inject_mcp_settings_json "$extra_target" "$tmp_merged" ;;
      vscode_json)    _inject_mcp_vscode_json "$extra_target" "$tmp_merged" ;;
      copilot_cli)    _inject_mcp_copilot_cli "$extra_target" "$tmp_merged" ;;
      cli_add)        _inject_mcp_cli_add "$extra_target" ;;
    esac
  done

  rm -f "$tmp_merged"
}

manage_env() {
  local env_file="$PROJECT_ROOT/.env.octopus"
  local env_example="$OCTOPUS_DIR/.env.octopus.example"

  # Copy template if .env.octopus doesn't exist
  if [[ ! -f "$env_file" ]]; then
    if [[ -f "$env_example" ]]; then
      cp "$env_example" "$env_file"
      echo "Created .env.octopus from .env.octopus.example — fill in your values."
    else
      return
    fi
  fi

  # Extract required vars from declared MCP server configs
  local required_vars=()
  for server in "${OCTOPUS_MCP[@]}"; do
    local server_file="$OCTOPUS_DIR/mcp/${server}.json"
    [[ -f "$server_file" ]] || continue
    while IFS= read -r var; do
      required_vars+=("$var")
    done < <(grep -oP '\$\{(\K[^}]+)' "$server_file" | sort -u || true)
  done

  # Check for missing vars
  local missing=()
  for var in "${required_vars[@]}"; do
    if ! grep -q "^${var}=" "$env_file" 2>/dev/null; then
      missing+=("$var")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "WARNING: The following environment variables are required by your MCP servers but missing from .env.octopus:"
    for var in "${missing[@]}"; do
      echo "  - $var"
    done
  fi

  # Check for new vars in .env.octopus.example not in .env.octopus
  if [[ -f "$env_example" ]]; then
    while IFS= read -r var; do
      [[ -z "$var" ]] && continue
      if ! grep -q "^${var}=" "$env_file" 2>/dev/null; then
        echo "INFO: New variable '$var' found in .env.octopus.example but not in .env.octopus"
      fi
    done < <(grep -oP '^([A-Z_]+)=' "$env_example" | sed 's/=$//' || true)
  fi
}

# Collected gitignore entries from all agents
declare -a ALL_GITIGNORE_ENTRIES=(".env.octopus")

collect_gitignore_entries() {
  local agent="$1"
  local output="${OCTOPUS_AGENT_OUTPUT[$agent]:-$MANIFEST_OUTPUT}"
  [[ -n "$output" ]] && ALL_GITIGNORE_ENTRIES+=("$output")

  for entry in "${MANIFEST_GITIGNORE_EXTRA[@]}"; do
    ALL_GITIGNORE_ENTRIES+=("$entry")
  done
}

update_gitignore() {
  local gitignore="$PROJECT_ROOT/.gitignore"

  # Create .gitignore if it doesn't exist
  touch "$gitignore"

  # Add octopus marker section if not present
  if ! grep -q "# octopus (auto-generated)" "$gitignore" 2>/dev/null; then
    echo "" >> "$gitignore"
    echo "# octopus (auto-generated)" >> "$gitignore"
  fi

  # Add each entry if not already present
  for entry in "${ALL_GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qF "$entry" "$gitignore" 2>/dev/null; then
      echo "$entry" >> "$gitignore"
    fi
  done
}

validate_cli_deps() {
  if [[ "$OCTOPUS_WORKFLOW" != "true" ]]; then
    return
  fi

  # Check gh
  if ! command -v gh &>/dev/null; then
    echo "WARNING: 'gh' (GitHub CLI) not found. Workflow commands will not work."
    echo "  Install: https://cli.github.com/"
    return
  fi

  # Check gh version >= 2.0
  local gh_version
  gh_version=$(gh --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' | head -1)
  if [[ -n "$gh_version" ]]; then
    local major
    major=$(echo "$gh_version" | cut -d. -f1)
    if [[ "$major" -lt 2 ]]; then
      echo "WARNING: 'gh' version $gh_version found, but >= 2.0 is required for workflow commands."
    fi
  fi

  # Check gh auth
  if ! gh auth status &>/dev/null 2>&1; then
    echo "WARNING: 'gh' is not authenticated. Run 'gh auth login' for workflow commands."
  fi
}

# Allow sourcing without running main
if [[ "${1:-}" == "--source-only" ]]; then
  return 0 2>/dev/null || exit 0
fi

# --- Main execution ---

CONFIG_FILE="$PROJECT_ROOT/.octopus.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: .octopus.yml not found at $PROJECT_ROOT"
  echo "Copy from: octopus/.octopus.example.yml"
  exit 1
fi

echo "=== Octopus Setup ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# 1. Parse config
parse_octopus_yml "$CONFIG_FILE"

# 1b. Ensure 'common' rule is always first
ensure_common_rule

# 1c. Discover knowledge modules
discover_knowledge

echo "Rules:     ${OCTOPUS_RULES[*]:-none}"
echo "Skills:    ${OCTOPUS_SKILLS[*]:-none}"
echo "Hooks:     $OCTOPUS_HOOKS"
echo "Agents:    ${OCTOPUS_AGENTS[*]:-none}"
echo "MCP:       ${OCTOPUS_MCP[*]:-none}"
echo "Commands:  ${OCTOPUS_CMD_NAMES[*]:-none}"
echo "Workflow:  $OCTOPUS_WORKFLOW"
echo "Roles:     ${OCTOPUS_ROLES[*]:-none}"
echo "Reviewers: ${OCTOPUS_REVIEWERS[*]:-none}"
echo "Knowledge: ${KNOWLEDGE_MODULES[*]:-none}"
echo "Language:  docs=${OCTOPUS_LANGUAGE_DOCS:-auto} code=${OCTOPUS_LANGUAGE_CODE:-auto} ui=${OCTOPUS_LANGUAGE_UI:-auto}"
echo ""

# 2. Validate CLI dependencies
validate_cli_deps

# 3. Manifest-driven agent generation
for agent in "${OCTOPUS_AGENTS[@]}"; do
  load_manifest "$agent"
  generate_main_output "$agent"
  deliver_rules "$agent"
  deliver_skills "$agent"
  deliver_knowledge "$agent"
  deliver_commands "$agent"
  deliver_roles "$agent"
  deliver_mcp "$agent"
  deliver_hooks "$agent"
  deliver_permissions "$agent"
  deliver_effort_level "$agent"
  collect_gitignore_entries "$agent"
done

# 3b. Generate knowledge index
generate_knowledge_index

# 4. Manage .env
manage_env

# 5. Update .gitignore
update_gitignore

echo ""
echo "=== Setup complete ==="
