#!/bin/bash
# One-shot installer for the "Claude posts to Slack → desktop notification" hook.
# Idempotent: safe to re-run. Requires: jq (brew install jq / apt install jq).
set -e

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
SRC="$(cd "$(dirname "$0")" && pwd)/slack-notify-hook.sh"
DEST="$HOOKS_DIR/slack-notify-hook.sh"
MATCHER='.*slack_(send_message|schedule_message|post_message|reply_to_thread).*'

command -v jq >/dev/null 2>&1 || { echo "❌ jq is required. Install: brew install jq (mac) / sudo apt install jq (linux)"; exit 1; }

# 1) install the hook script
mkdir -p "$HOOKS_DIR"
cp "$SRC" "$DEST"
chmod +x "$DEST"
echo "✅ hook script → $DEST"

# 2) ensure settings.json exists
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

# 3) merge the PostToolUse hook (only if not already present) — preserves all existing settings/hooks
tmp="$(mktemp)"
jq --arg cmd "$DEST" --arg matcher "$MATCHER" '
  .hooks //= {} |
  .hooks.PostToolUse //= [] |
  if any(.hooks.PostToolUse[]?; .matcher == $matcher)
  then .
  else .hooks.PostToolUse += [ { "matcher": $matcher, "hooks": [ { "type": "command", "command": $cmd, "async": true } ] } ]
  end
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
echo "✅ hook registered in $SETTINGS"

echo ""
echo "Next: open Claude Code and run  /hooks  once (or restart) to load it."
echo "Then have Claude post to Slack — you should get a banner + sound."
echo "Change the sound by editing SOUND at the top of: $DEST"
