#!/usr/bin/env bash
# Prefix the terminal tab with an icon saying what Claude wants from you.
#
# Claude Code writes the title itself as OSC 0, prefixed with ⠂/⠐ while it works
# and with ✳ once it stops. It only rewrites when the value changes: outside the
# "busy" state it writes once and then goes quiet, so this script can put a more
# telling prefix there and have it stick. Nothing to clean up — Claude takes the
# title back on its next state change, which is exactly when the marker should
# disappear.
#
# While it works, by contrast, Claude rewrites every 960 ms: no hook can hold a
# "working" marker there. There is nothing to attempt on that side.
#
# Every failure is silent: on a terminal we cannot reach, or if the internal
# state read here changes shape, the script does nothing and Claude keeps its
# own icons.

set -u

payload=$(cat)
{
  read -r event
  read -r session_id
  read -r cwd
} < <(printf '%s' "$payload" | jq -r '.hook_event_name // "", .session_id // "", .cwd // ""')

# <config>/sessions/<pid>.json is the state Claude keeps for itself: the topic
# name shown in the tab, the pid whose stdout is the terminal, and the
# waitingFor field that says *why* it is waiting. It is an undocumented
# implementation detail — hence the silent fallbacks everywhere here.
sessions_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions"
session_file=$(jq -r --arg id "$session_id" \
  'select(.sessionId == $id) | input_filename' \
  "$sessions_dir"/*.json 2>/dev/null | head -n1)

# Let Claude finish writing its own title for this state change, and the session
# file catch up, before reading and overwriting. StopFailure waits longer than
# Stop so that it wins if both happen to fire.
case $event in
  Stop | Notification) sleep 0.4 ;;
  StopFailure) sleep 0.9 ;;
esac

pid=""
title=""
waiting_for=""
if [[ -n ${session_file:-} ]]; then
  {
    read -r pid
    read -r title
    read -r waiting_for
  } < <(jq -r '.pid // "", .name // "", .waitingFor // ""' "$session_file" 2>/dev/null)
fi

case $event in
  Stop) prefix="✅ " ;;
  StopFailure) prefix="❌ " ;;
  # The tab becomes a shell again: no icon, no topic name, just the directory.
  SessionEnd)
    prefix=""
    title=""
    ;;
  Notification)
    case $waiting_for in
      # No waitingFor: nothing is blocked, this is the idle reminder. Leave the
      # end-of-turn marker in place.
      "") exit 0 ;;
      "permission prompt") prefix="🔐 " ;;
      "input needed") prefix="❓ " ;;
      "sandbox request") prefix="🧱 " ;;
      "worker request") prefix="🤖 " ;;
      "dialog open") prefix="💤 " ;;
      *) prefix="❓ " ;;
    esac
    ;;
  *) exit 0 ;;
esac

# The hook has no controlling terminal of its own, so aim at Claude's stdout.
# /proc on Linux, lsof elsewhere — macOS has no /proc.
resolve_tty() {
  local target
  [[ -n ${1:-} ]] || return 1
  target=$(readlink "/proc/$1/fd/1" 2>/dev/null) ||
    target=$(lsof -a -p "$1" -d 1 -F n 2>/dev/null | sed -n 's/^n//p' | head -n1)
  case $target in
    /dev/pts/* | /dev/tty*) printf '%s' "$target" ;;
    *) return 1 ;;
  esac
}

# At session end the file may already be gone; the hook's parent process is then
# the only remaining path to the terminal.
tty_path=$(resolve_tty "$pid") || tty_path=$(resolve_tty "$PPID") || exit 0

[[ -n $title ]] || title=$(basename "$cwd")
[[ -n $title ]] || title="Claude Code"
title=${title//[[:cntrl:]]/}

printf '\033]0;%s%s\007' "$prefix" "$title" >"$tty_path" 2>/dev/null || true
