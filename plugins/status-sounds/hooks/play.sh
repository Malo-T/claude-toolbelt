#!/usr/bin/env bash
# Play a short sound when Claude has finished, has failed, or wants something
# from you — so you look up at the right moment without watching the tab.
#
# Three sounds only, where the status-icons module tells seven states apart: by
# ear the one useful question is "do I need to go back?". The detail is there to
# read on the tab once you are.
#
# Every failure is silent — no audio player, no sound file, unknown system: the
# script exits without a word.
#
# Written for bash 3.2, the version macOS still ships: no associative arrays and
# no case-conversion expansions here.

set -u

payload=$(cat)
{
  read -r event
  read -r session_id
} < <(printf '%s' "$payload" | jq -r '.hook_event_name // "", .session_id // ""')

case $event in
  Stop) key=done ;;
  StopFailure) key=error ;;
  Notification) key=attention ;;
  *) exit 0 ;;
esac

# watch.sh sees the waiting state six seconds before the event does, and its
# marker says it owns this episode — whether it has played already or is still
# holding for a configured delay. No marker means no watcher, and then this late
# event is all there is. The watcher sets its own marker before acting, so it
# announces itself through STATUS_SOUNDS_FROM_WATCHER rather than tripping over it.
#
# The marker alone is not enough to yield to, though: a watcher killed outright
# never runs the trap that would clear it, and trusting a leftover marker would
# make every later notification of that session silent — worse than the six
# seconds this whole mechanism exists to remove. So the pidfile beside it has the
# last word, and only a live watcher owns the episode.
watcher_owns_episode() {
  local pid="" args="" here
  [[ -e "$state_dir/$session_id.waiting" ]] || return 1
  [[ -r "$state_dir/$session_id.pid" ]] || return 1
  # `$(<file)`, not `read`: watch.sh writes the pid without a trailing newline,
  # and `read` reports failure on that even though it did read the value.
  pid=$(<"$state_dir/$session_id.pid") 2>/dev/null
  [[ -n $pid ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  # Same test as watch.sh's own is_watcher: a recycled pid must not pass for one.
  here=$(cd "$(dirname "$0")" && pwd) || return 1
  if [[ -r /proc/$pid/cmdline ]]; then
    args=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null)
  else
    args=$(ps -p "$pid" -o args= 2>/dev/null)
  fi
  case $args in
    *"$here/watch.sh"*) return 0 ;;
  esac
  return 1
}

if [[ $event == Notification && -n $session_id && -z ${STATUS_SOUNDS_FROM_WATCHER:-} ]]; then
  state_dir="${TMPDIR:-/tmp}/claude-status-sounds-$(id -u 2>/dev/null || echo 0)"
  watcher_owns_episode && exit 0
fi

# macOS has no freedesktop sound theme, and Linux has no /System/Library.
case $(uname -s) in
  Darwin)
    case $key in
      done) sound=/System/Library/Sounds/Glass.aiff ;;
      attention) sound=/System/Library/Sounds/Ping.aiff ;;
      error) sound=/System/Library/Sounds/Basso.aiff ;;
    esac
    ;;
  *)
    theme=${STATUS_SOUNDS_THEME:-/usr/share/sounds/freedesktop/stereo}
    case $key in
      done) sound="$theme/complete.oga" ;;
      attention) sound="$theme/message-new-instant.oga" ;;
      error) sound="$theme/dialog-warning.oga" ;;
    esac
    ;;
esac

[[ -r $sound ]] || exit 0

# canberra honours the desktop sound theme; the rest are fallbacks.
if command -v canberra-gtk-play >/dev/null 2>&1; then
  canberra-gtk-play -f "$sound" >/dev/null 2>&1
elif command -v afplay >/dev/null 2>&1; then
  afplay "$sound" >/dev/null 2>&1
elif command -v paplay >/dev/null 2>&1; then
  paplay "$sound" >/dev/null 2>&1
elif command -v aplay >/dev/null 2>&1; then
  aplay -q "$sound" >/dev/null 2>&1
fi

exit 0
