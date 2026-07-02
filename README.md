# Claude Code → Slack notification hook

Get a **desktop notification + sound** every time Claude Code posts a message to Slack — with the
**channel** and a **trimmed snippet** of the message. Works on **macOS** and **Linux**.

It's a Claude Code **PostToolUse hook**: whenever Claude calls a Slack "send" tool
(`mcp__claude_ai_Slack__slack_send_message`, `…schedule_message`, or the Pension-Bot
`…slack_post_message` / `…slack_reply_to_thread`), the hook fires a notification.

## Requirements
- Claude Code
- `jq` — `brew install jq` (macOS) or `sudo apt install jq` (Linux)
- macOS (uses `osascript` + `afplay`) or Linux (uses `notify-send` + `paplay`)

## Install
```bash
git clone https://github.com/piyush52dixit/slack-notify-hook.git
cd slack-notify-hook
chmod +x install.sh && ./install.sh
```
Then in Claude Code run **`/hooks`** once (or restart) so it loads the new hook.
Test: ask Claude to post something to Slack → you should get a banner + sound.

Repo: https://github.com/piyush52dixit/slack-notify-hook

The installer is **idempotent** and **non-destructive** — it merges into your existing
`~/.claude/settings.json` (keeps your other hooks/settings) and won't add a duplicate on re-run.

## What it does under the hood
- Copies `slack-notify-hook.sh` → `~/.claude/hooks/`.
- Adds this to `~/.claude/settings.json`:
  ```json
  {
    "hooks": {
      "PostToolUse": [
        {
          "matcher": ".*slack_(send_message|schedule_message|post_message|reply_to_thread).*",
          "hooks": [ { "type": "command", "command": "<home>/.claude/hooks/slack-notify-hook.sh", "async": true } ]
        }
      ]
    }
  }
  ```
- The hook reads the tool payload on stdin, extracts channel + message, trims to ~90 chars, and
  notifies. Message text is passed to `osascript` as **argv** (not embedded in the AppleScript
  source), so quotes/backticks/apostrophes/newlines in messages can't break or inject it.

## Change the sound
Edit `SOUND` at the top of `~/.claude/hooks/slack-notify-hook.sh`.
macOS options: `Basso Blow Bottle Frog Funk Glass Hero Morse Ping Pop Purr Sosumi Submarine Tink`.

## Troubleshooting
- **No notification fires at all** → run `/hooks` once (reloads config) or restart Claude Code.
  Confirm registration: `jq '.hooks.PostToolUse' ~/.claude/settings.json`.
- **Sound but no banner (macOS)** → System Settings → Notifications → your terminal app
  (Terminal/iTerm) → allow **Banners/Alerts + sound**; turn off Focus/Do-Not-Disturb.
- **Nothing on Linux** → ensure `notify-send` (libnotify) is installed; sound needs `paplay` (PulseAudio).

## Uninstall
```bash
rm ~/.claude/hooks/slack-notify-hook.sh
```
and remove the `PostToolUse` block from `~/.claude/settings.json`.
