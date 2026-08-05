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

event=$(jq -r '.hook_event_name // ""')

case $event in
  Stop) key=done ;;
  StopFailure) key=error ;;
  Notification) key=attention ;;
  *) exit 0 ;;
esac

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
    theme=${SESSION_STATUS_SOUND_THEME:-/usr/share/sounds/freedesktop/stereo}
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
