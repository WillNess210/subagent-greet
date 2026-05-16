#!/usr/bin/env bash
# Emits SessionStart additionalContext via JSON stdout.
# Fires on startup, resume, clear, and after compact — same nudge survives compaction.

set -euo pipefail

read -r -d '' CONTEXT <<'EOF' || true
Subagent invocation rule (from subagent-greet plugin):

Before the FIRST call to a given subagent in this session, you MUST activate the `subagent-greet` skill. The skill runs a script that returns context-specific calling guidance for that subagent (prompt tips, required inputs, gotchas, examples). Read the guidance, then invoke Agent with a prompt informed by it.

Sequencing: run subagent-greet FIRST, then Agent. Never in parallel — the greeting must influence how you write the Agent prompt.

Once per subagent per session. After the first call to a given subagent, its greeting is already in your context; subsequent calls don't need to refetch.
EOF

# Escape for JSON. python3 is required (ships in macOS, in our Dockerfile).
# A pure-awk fallback can't safely escape control chars, so we fail loud instead.
if ! command -v python3 >/dev/null 2>&1; then
  echo "subagent-greet session-start hook: python3 not found in PATH" >&2
  exit 1
fi
ESCAPED=$(printf '%s' "$CONTEXT" | python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.stdin.read()))')

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $ESCAPED
  }
}
EOF
