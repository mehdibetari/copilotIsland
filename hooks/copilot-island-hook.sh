#!/bin/bash
# Forwards a Copilot CLI hook payload (stdin) to the Copilot Island app. Never fails the CLI.
curl -s -m 2 -X POST "http://127.0.0.1:47615/event" \
  -H "X-Copilot-Event: ${1:-unknown}" \
  -H "X-Iterm-Session: ${ITERM_SESSION_ID:-}" \
  --data-binary @- >/dev/null 2>&1
exit 0
