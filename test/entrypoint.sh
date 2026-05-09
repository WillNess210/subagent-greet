#!/usr/bin/env bash
# Pre-install the plugin into the container's Claude config, then run a
# headless prompt and stream JSON events to stdout for the analyzer.

set -euo pipefail

PROMPT='Run an Explore agent that says "hello" and does nothing.'
PLUGIN_NAME="subagent-greet"
MARKETPLACE="subagent-greet"
VERSION="0.1.0"

CFG="${HOME}/.claude"
PLUGIN_SRC="/opt/subagent-greet"
mkdir -p "$CFG"

# Pre-approve tools we expect Claude to use. No --dangerously-skip-permissions.
cat > "${CFG}/settings.json" <<JSON
{
  "permissions": {
    "allow": [
      "Bash",
      "Agent",
      "Skill",
      "Read",
      "Grep",
      "Glob",
      "WebSearch",
      "WebFetch"
    ]
  }
}
JSON

{
  echo "=== container setup ==="
  echo "claude version: $(claude --version 2>/dev/null || echo unknown)"
  echo "validating plugin:"
  claude plugin validate "$PLUGIN_SRC" 2>&1 || true
  echo "settings.json:"
  cat "${CFG}/settings.json"
  echo "=== end setup ==="
} >&2

cd /workspace

# --plugin-dir loads the plugin for this session only — no cache, no
# marketplace registration, no trust prompt. Cleanest install path for tests.
exec claude \
  --print "$PROMPT" \
  --plugin-dir "$PLUGIN_SRC" \
  --output-format stream-json \
  --verbose
