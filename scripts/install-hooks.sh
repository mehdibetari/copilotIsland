#!/bin/bash
# Installs the Copilot CLI hooks in ~/.copilot/hooks (user level, applies to every repo).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${COPILOT_HOME:-$HOME/.copilot}/hooks"
mkdir -p "$DEST"
install -m 755 "$ROOT/hooks/copilot-island-hook.sh" "$DEST/copilot-island-hook.sh"

entry() { printf '[{"type":"command","bash":"%s/copilot-island-hook.sh %s","timeoutSec":5}]' "$DEST" "$1"; }
cat > "$DEST/copilot-island.json" <<EOF
{
  "version": 1,
  "hooks": {
    "sessionStart": $(entry sessionStart),
    "sessionEnd": $(entry sessionEnd),
    "userPromptSubmitted": $(entry userPromptSubmitted),
    "postToolUse": $(entry postToolUse),
    "notification": $(entry notification),
    "agentStop": $(entry agentStop)
  }
}
EOF
echo "Hooks installés dans $DEST (relancez vos sessions Copilot CLI)."
