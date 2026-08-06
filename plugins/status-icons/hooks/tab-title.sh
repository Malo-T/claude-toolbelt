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
# The icon goes up immediately and, on the end-of-turn events, again after a
# short wait. The wait used to come first, alone, to be sure of landing after
# Claude's own write — but it cost 440 ms of measured delay on every turn for a
# race that may not even happen. Writing twice is never worse: the first write
# wins outright when Claude has already finished with the title, and the second
# is exactly the old behaviour when it has not.
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

pid=""
title=""
waiting_for=""
read_session() {
  [[ -n ${session_file:-} ]] || return 0
  {
    read -r pid
    read -r title
    read -r waiting_for
  } < <(jq -r '.pid // "", .name // "", .waitingFor // ""' "$session_file" 2>/dev/null)
}
read_session

# Derived from waiting_for, so it has to be redone whenever the session file is
# re-read: between the two passes below the user may have answered, and the icon
# that was right 400 ms ago would then be written over the one that is right now.
# Returning non-zero means "nothing to write for this state".
prefix=""
derive_prefix() {
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
        "") return 1 ;;
        "permission prompt") prefix="🔐 " ;;
        "input needed") prefix="❓ " ;;
        "sandbox request") prefix="🧱 " ;;
        "worker request") prefix="🤖 " ;;
        "dialog open") prefix="💤 " ;;
        *) prefix="❓ " ;;
      esac
      ;;
    *) return 1 ;;
  esac
  return 0
}

derive_prefix || exit 0

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

write_title() {
  local tty_path shown=$title
  # At session end the file may already be gone; the hook's parent process is
  # then the only remaining path to the terminal.
  tty_path=$(resolve_tty "$pid") || tty_path=$(resolve_tty "$PPID") || return 0
  [[ -n $shown ]] || shown=$(basename "$cwd")
  [[ -n $shown ]] || shown="Claude Code"
  shown=${shown//[[:cntrl:]]/}
  printf '\033]0;%s%s\007' "$prefix" "$shown" >"$tty_path" 2>/dev/null || true
}

write_title

# Second pass, wherever Claude may still write its own title afterwards — the
# race the single delayed write used to avoid by simply arriving last.
# StopFailure waits longer than Stop so that it wins if both happen to fire.
case $event in
  Stop | Notification) sleep 0.4 ;;
  StopFailure) sleep 0.9 ;;
  *) exit 0 ;;
esac
read_session
# Re-derived, not reused: a prompt answered during the wait clears waitingFor,
# and the second pass then has nothing to say rather than an obsolete icon to
# reassert.
derive_prefix || exit 0
write_title
