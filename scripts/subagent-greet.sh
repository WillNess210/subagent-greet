#!/usr/bin/env bash
# subagent-greet.sh <subagent-id>
# Outputs per-subagent calling guidance to stdout.
# Lookup order:
#   1. ~/.claude/agents/<id>.md  (user agents, `greeting:` frontmatter)
#   2. <cwd>/.claude/agents/<id>.md  (project agents)
#   3. ~/.claude/plugins/cache/*/agents/<id>.md  (plugin-vended agents)
#   4. Curated built-in greetings (below)
#   5. Generic fallback

set -euo pipefail

ID="${1:-}"
if [[ -z "$ID" ]]; then
  echo "usage: subagent-greet.sh <subagent-id>" >&2
  exit 2
fi

# Reject anything that could path-traverse out of the agents dir.
# Subagent ids are typically [name] or [plugin:name] over [A-Za-z0-9._-].
if [[ ! "$ID" =~ ^[A-Za-z0-9._:-]+$ ]]; then
  echo "subagent-greet: invalid id (allowed: A-Z a-z 0-9 . _ - :)" >&2
  exit 2
fi

NORM=$(printf '%s' "$ID" | tr '[:upper:]' '[:lower:]')
BARE="${NORM##*:}"

extract_greeting() {
  awk '
    function rstrip(s) { sub(/[[:space:]]+$/, "", s); return s }
    BEGIN { state = 0 }
    state == 0 {
      if ($0 ~ /^---[[:space:]]*$/) { state = 1 }
      next
    }
    state == 1 && $0 ~ /^---[[:space:]]*$/ { exit }
    state == 1 && $0 ~ /^greeting:/ {
      rest = $0
      sub(/^greeting:[[:space:]]*/, "", rest)
      rest = rstrip(rest)
      if (rest ~ /^\|[-+]?$/) {
        state = 2
        block_indent = -1
        next
      }
      # Folded scalar (>) is intentionally not supported — treat as empty
      # so the lookup falls through to the next source instead of printing ">".
      if (rest ~ /^>[-+]?$/) { exit }
      if (rest ~ /^".*"$/) { rest = substr(rest, 2, length(rest) - 2) }
      else if (rest ~ /^'\''.*'\''$/) { rest = substr(rest, 2, length(rest) - 2) }
      print rest
      exit
    }
    state == 2 {
      if ($0 ~ /^---[[:space:]]*$/) exit
      if ($0 ~ /^[[:space:]]*$/) { print ""; next }
      if (match($0, /^[[:space:]]+/)) {
        indent = RLENGTH
        if (block_indent == -1) block_indent = indent
        if (indent < block_indent) exit
        print substr($0, block_indent + 1)
      } else {
        exit
      }
    }
  ' "$1"
}

try_file() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  local out
  out=$(extract_greeting "$f")
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out"
    return 0
  fi
  return 1
}

resolve_yaml_greeting() {
  local dirs=()
  [[ -d "$HOME/.claude/agents" ]] && dirs+=("$HOME/.claude/agents")
  [[ -d "$PWD/.claude/agents" ]] && dirs+=("$PWD/.claude/agents")
  if [[ -d "$HOME/.claude/plugins/cache" ]]; then
    while IFS= read -r -d '' d; do dirs+=("$d"); done < <(find "$HOME/.claude/plugins/cache" -type d -name agents -print0 2>/dev/null)
  fi
  local dir candidate
  # bash 3.2 (macOS) errors on "${dirs[@]}" when dirs is empty under set -u.
  for dir in ${dirs[@]+"${dirs[@]}"}; do
    for candidate in "$dir/$BARE.md" "$dir/$NORM.md" "$dir/$ID.md"; do
      try_file "$candidate" && return 0
    done
  done
  return 1
}

resolve_yaml_greeting && exit 0

case "$BARE" in
  explore)
    cat <<'EOF'
Explore — read-only search agent.
Use for: file pattern lookups, grep symbol/keyword, "where is X defined / which files reference Y".
Don't use for: review, design-doc audits, cross-file consistency, open-ended analysis (reads excerpts, misses content past read window).
Specify breadth: "quick" (single targeted), "medium" (moderate), "very thorough" (multi-location, multi-naming).
Hand over exact target if known. For investigations, hand over the question — prescribed steps go stale when premise is wrong.
EOF
    ;;
  plan)
    cat <<'EOF'
Plan — software architect for implementation strategy.
Returns: step-by-step plan, critical files, architectural trade-offs.
Brief on: goal, constraints already known, paths ruled out, success criteria, length cap.
Don't use for: simple bugs, single-file changes, anything you'd just code directly.
EOF
    ;;
  general-purpose)
    cat <<'EOF'
general-purpose — fallback agent.
Use only when no specialized agent fits, OR for keyword/file searches when uncertain you'll match in first few tries.
Brief on: goal, ruled-out paths, expected output form, length cap.
Prefer Explore (search), Plan (architecture), or domain-specific agents when applicable.
EOF
    ;;
  claude-code-guide)
    cat <<'EOF'
claude-code-guide — Claude Code CLI / Claude Agent SDK / Claude API expertise.
Use for: hooks, slash commands, MCP servers, settings, IDE integrations, SDK usage, tool use, prompt caching.
Don't use for: general programming, non-Anthropic providers, code editing.
Check for an existing claude-code-guide instance before spawning new — continue via SendMessage to retain context.
EOF
    ;;
  statusline-setup)
    cat <<'EOF'
statusline-setup — configures Claude Code status line in settings.json. Single-purpose.
Brief on: desired status line content/format, settings scope (user vs project).
Don't use for: anything other than status line config.
EOF
    ;;
  research-analyst)
    cat <<'EOF'
research-analyst — info gathering, synthesis, comparative reports. Read-only + WebFetch/WebSearch.
Brief on: research question, sources to prefer, length cap, output format (bullets / table / paragraphs).
Set explicit word cap — defaults run long.
EOF
    ;;
  *)
    printf 'Call the %s subagent with the best possible prompt to get the information you need.\n' "$ID"
    ;;
esac
