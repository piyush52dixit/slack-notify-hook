#!/bin/bash
# Claude Code PostToolUse hook — desktop notification when Claude posts to Slack.
# Receives the tool-call JSON on stdin:
#   { tool_name, tool_input:{channel_id, message|text, thread_ts}, tool_response:{...}, ... }
# Shows a banner (channel + trimmed snippet) + plays a sound, and — when clicked — opens the
# exact Slack message / channel / DM it was posted to. macOS + Linux.
#
# Click-to-open on macOS needs `terminal-notifier` (brew install terminal-notifier). Without it,
# it falls back to a plain osascript banner (no click-through).
#
# Change the sound: edit SOUND below.
#   macOS names (in /System/Library/Sounds): Basso Blow Bottle Frog Funk Glass Hero Morse Ping Pop Purr Sosumi Submarine Tink
SOUND="Submarine"

payload="$(cat)"

# message body: claude.ai Slack integration uses .message, Pension-Bot server uses .text
msg="$(printf '%s' "$payload"    | jq -r '.tool_input.message // .tool_input.text // ""' 2>/dev/null)"
chan="$(printf '%s' "$payload"   | jq -r '.tool_input.channel_id // ""'                 2>/dev/null)"
thread="$(printf '%s' "$payload" | jq -r '.tool_input.thread_ts // ""'                  2>/dev/null)"

# URL to open when the banner is clicked. Prefer the exact message permalink returned by the
# tool; fall back to scraping any Slack permalink from the payload, then to a channel/DM deep link.
link="$(printf '%s' "$payload" | jq -r '
  (.tool_response // {}) as $r
  | ( $r.message_link // $r.permalink // $r.message_context.message_link // "" )
' 2>/dev/null)"
if [ -z "$link" ] || [ "$link" = "null" ]; then
  link="$(printf '%s' "$payload" | grep -oE 'https://[A-Za-z0-9._-]+\.slack\.com/archives/[A-Za-z0-9._/-]+' | head -1)"
fi
# app_redirect opens the channel/DM straight in the Slack desktop app (works for C…/D…/G… ids)
[ -z "$link" ] && [ -n "$chan" ] && link="https://slack.com/app_redirect?channel=${chan}"

# collapse newlines/whitespace, strip leading dashes, trim to 90 chars
body="$(printf '%s' "$msg" | tr '\n\t' '  ' | tr -s ' ' | sed 's/^[[:space:]-]*//' | cut -c1-90)"
[ -z "$body" ] && body="(no text)"

# subtitle = channel (+ 🧵 for a thread reply)
sub="${chan:-slack}"
[ -n "$thread" ] && sub="$sub 🧵"

case "$(uname)" in
  Darwin)
    # sound (backgrounded so it never blocks) + banner
    afplay "/System/Library/Sounds/${SOUND}.aiff" >/dev/null 2>&1 &
    if command -v terminal-notifier >/dev/null 2>&1; then
      # clickable banner → opens the Slack message / channel / DM
      open_args=()
      [ -n "$link" ] && open_args=(-open "$link")
      terminal-notifier \
        -title "Claude → Slack ✅" \
        -subtitle "$sub" \
        -message "$body" \
        "${open_args[@]}" >/dev/null 2>&1 || true
    else
      # fallback: plain banner (clicking opens Script Editor). For click-to-open install:
      #   brew install terminal-notifier
      osascript \
        -e 'on run argv' \
        -e 'display notification (item 1 of argv) with title "Claude → Slack ✅" subtitle (item 2 of argv)' \
        -e 'end run' \
        "$body" "$sub" 2>/dev/null || true
    fi
    ;;
  Linux)
    # notify-send: append the link to the body so it's visible/copyable
    lbody="$body"; [ -n "$link" ] && lbody="$body
$link"
    command -v notify-send >/dev/null 2>&1 && notify-send "Claude → Slack ✅  [$sub]" "$lbody" 2>/dev/null || true
    { command -v paplay >/dev/null 2>&1 && paplay /usr/share/sounds/freedesktop/stereo/message.oga; } >/dev/null 2>&1 &
    ;;
esac
exit 0
