#!/usr/bin/env bash
# Build the test image, run the container with host Claude Code OAuth
# credentials mounted in, save the transcript, run the analyzer.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="${REPO_ROOT}/test"
IMAGE="subagent-greet-test"
TS="$(date +%Y%m%d-%H%M%S)"
TRANSCRIPTS_DIR="${TEST_DIR}/transcripts"
mkdir -p "$TRANSCRIPTS_DIR"
TRANSCRIPT="${TRANSCRIPTS_DIR}/${TS}.jsonl"
SETUP_LOG="${TRANSCRIPTS_DIR}/${TS}.setup.log"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found on PATH" >&2
  exit 1
fi

# Pull OAuth credentials from macOS keychain into a tightly-permissioned
# temp file. The contents never enter stdout, the conversation, or any log.
CRED_TMP=""
cleanup() { [[ -n "${CRED_TMP}" && -f "${CRED_TMP}" ]] && rm -f "${CRED_TMP}"; }
trap cleanup EXIT INT TERM

if [[ "$(uname)" == "Darwin" ]]; then
  CRED_TMP="$(mktemp -t subagent-greet-cred)"
  chmod 600 "$CRED_TMP"
  if ! security find-generic-password -s "Claude Code-credentials" -w \
       > "$CRED_TMP" 2>/dev/null; then
    echo "could not read 'Claude Code-credentials' from macOS keychain." >&2
    echo "is Claude Code logged in on this machine?" >&2
    exit 1
  fi
  if [[ ! -s "$CRED_TMP" ]]; then
    echo "keychain returned empty credential" >&2
    exit 1
  fi
else
  echo "host credential extraction only implemented for macOS keychain." >&2
  echo "set ANTHROPIC_API_KEY in env and adjust this script if you need" >&2
  echo "another platform." >&2
  exit 1
fi

echo "→ building image ${IMAGE}"
docker build -q -t "$IMAGE" -f "${TEST_DIR}/Dockerfile" "$REPO_ROOT" >/dev/null

echo "→ running container, capturing transcript to ${TRANSCRIPT}"
set +e
docker run --rm \
  -v "${CRED_TMP}:/root/.claude/.credentials.json:ro" \
  "$IMAGE" \
  >"$TRANSCRIPT" 2>"$SETUP_LOG"
RC=$?
set -e

echo "→ container exit: $RC"
echo "→ setup log:      $SETUP_LOG  ($(wc -c <"$SETUP_LOG" | tr -d ' ') bytes)"
echo "→ transcript:     $TRANSCRIPT ($(wc -c <"$TRANSCRIPT" | tr -d ' ') bytes)"
echo
echo "=== analysis ==="
python3 "${TEST_DIR}/analyze.py" <"$TRANSCRIPT"
