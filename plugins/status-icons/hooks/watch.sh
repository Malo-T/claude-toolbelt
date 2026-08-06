#!/usr/bin/env bash
# Mark the tab the moment Claude starts waiting, instead of six seconds later.
#
# Claude Code holds its `Notification` event back by a hardcoded six seconds, so
# that answering a prompt straight away never pings you:
#
#   gu(() => { if (XMv(wDm)) …notify… }, n ? null : wDm)   var wDm = 6000
#
# The state itself is not held back. <config>/sessions/<pid>.json flips to
# status "waiting" the instant the dialog opens — measured at +0 ms, against
# +6020 ms for the event. So this watches that file and calls tab-title.sh on
# the transition, four times a second.
#
# The event stays wired up as a fallback: if this process never started or has
# died, the six-second notification is still better than no icon at all.
# `marker` is what tells the two apart — it exists for exactly as long as one
# waiting episode, and tab-title.sh bails when it finds it.
#
# Started by the SessionStart hook, stopped by SessionEnd. Failure is silent
# throughout: this is a convenience, and it must never be what breaks a session.

set -u

here=$(cd "$(dirname "$0")" && pwd)
state_dir="${TMPDIR:-/tmp}/claude-status-icons-$(id -u 2>/dev/null || echo 0)"

# Both knobs read from the environment, so they can be set once under "env" in
# settings.json without touching the plugin.
#
#   STATUS_ICONS_ALERT_DELAY    seconds to stay blocked before the icon, 0 by
#                               default. Raise it towards Claude Code's own 6 s
#                               if prompts you answer at once feel too noisy.
#   STATUS_ICONS_POLL_INTERVAL  how often to look, 0.25 s by default. It caps
#                               how late the icon can be.
interval=${STATUS_ICONS_POLL_INTERVAL:-0.25}
alert_delay=${STATUS_ICONS_ALERT_DELAY:-0}

# A watcher killed outright leaves its pidfile behind, and pids get recycled, so
# a pidfile alone proves nothing. Both the "is one already running" question and
# the "kill it" action go through this: it answers yes only for a live process
# whose command line is this very script.
is_watcher() {
  local pid=${1:-} args=""
  [[ -n $pid ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
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

kill_watcher() {
  is_watcher "${1:-}" && kill "$1" 2>/dev/null
  return 0
}

# --- launcher and teardown ----------------------------------------------------
# Both hooks must return at once, so the loop is detached and this returns.
if [[ ${1:-} != --run ]]; then
  session_id=$(jq -r '.session_id // ""' 2>/dev/null) || exit 0
  [[ -n $session_id ]] || exit 0

  # SessionEnd. The trap in the watcher clears the marker and the pidfile.
  if [[ ${1:-} == --stop ]]; then
    [[ -r "$state_dir/$session_id.pid" ]] || exit 0
    kill_watcher "$(<"$state_dir/$session_id.pid")"
    exit 0
  fi

  mkdir -p "$state_dir" 2>/dev/null || exit 0

  # SessionStart is not only session creation: Claude Code fires it again on
  # resume, on /clear and on /compact. A watcher still alive from earlier in the
  # session gains nothing from being restarted, and the gap while it restarts is
  # a gap in coverage — leave it alone. A pidfile pointing at anything else is
  # stale, and the new watcher overwrites it.
  if [[ -r "$state_dir/$session_id.pid" ]] && is_watcher "$(<"$state_dir/$session_id.pid")"; then
    exit 0
  fi

  nohup bash "$here/watch.sh" --run "$session_id" >/dev/null 2>&1 &
  disown 2>/dev/null || true
  exit 0
fi

# --- watcher ------------------------------------------------------------------
session_id=${2:-}
[[ -n $session_id ]] || exit 0

sessions_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions"
marker="$state_dir/$session_id.waiting"
pidfile="$state_dir/$session_id.pid"

# Not only the launcher's job: a temp-file sweeper can take this directory out
# from under a long-running session.
mkdir -p "$state_dir" 2>/dev/null || exit 0
printf '%s' "$$" >"$pidfile" 2>/dev/null || exit 0
trap 'rm -f "$marker" "$pidfile"; exit 0' EXIT INT TERM

# One awk call, at startup: sanitise both knobs and turn the delay into a count
# of ticks, so the loop never needs the fractional arithmetic bash lacks. A
# value that is not a positive number falls back to the default rather than
# stopping the watcher.
#
# LC_ALL=C is not decoration. Under a French locale awk prints 0,25, and bash
# reads `read -t 0,25` as twenty-five seconds — a hundredfold slower poll, in
# silence, which is worse than the delay this whole thing exists to remove.
discovery_budget=10
read -r interval delay_ticks discovery_ticks < <(LC_ALL=C awk \
  -v i="$interval" -v d="$alert_delay" -v w="$discovery_budget" 'BEGIN {
  if (i + 0 <= 0) i = 0.25
  if (d + 0 < 0) d = 0
  t = (d + 0) / (i + 0)
  n = (w + 0) / (i + 0)
  printf "%.6g %d %d\n", i + 0, (t == int(t) ? t : int(t) + 1), (n == int(n) ? n : int(n) + 1)
}' 2>/dev/null)
[[ -n ${interval:-} && -n ${delay_ticks:-} && -n ${discovery_ticks:-} ]] ||
  { interval=0.25; delay_ticks=0; discovery_ticks=40; }

# A fifo held open read-write never reaches EOF and never carries data, so
# `read -t` on it is a sleep that costs no fork — 0.2% of a core against 2.5%
# for a `sleep` per tick, and this runs for the whole session. bash 3.2, which
# macOS still ships, rejects a fractional -t: there, pay the fork.
nap() { sleep "$interval"; }
if ((${BASH_VERSINFO[0]:-0} >= 4)); then
  fifo="$state_dir/$session_id.fifo"
  rm -f "$fifo"
  if mkfifo "$fifo" 2>/dev/null && exec 9<>"$fifo"; then
    rm -f "$fifo"
    nap() { read -r -t "$interval" -u 9 _ || true; }
  fi
fi

# Everything below matches the session file as text, because parsing it with jq
# four times a second would put back the forks the fifo just removed. Text
# matching is only safe if it does not depend on the exact spelling: Claude Code
# writes this file compact today, and a future version putting a space after a
# colon must not silently stop the watcher from ever finding its session.
sep='[[:space:]]*:[[:space:]]*'
id_re="\"sessionId\"$sep\"$session_id\""
waiting_re="\"status\"$sep\"waiting\""

# SessionStart can beat the session file into existence; wait for it, but not
# forever — a session whose file never appears is one we cannot watch. The budget
# is ten seconds, converted to ticks: as a raw tick count it would silently
# shrink to two seconds the moment someone lowered POLL_INTERVAL.
session_file=""
for ((tick = 0; tick < discovery_ticks; tick++)); do
  for f in "$sessions_dir"/*.json; do
    [[ -r $f ]] || continue
    probe=$(<"$f")
    if [[ $probe =~ $id_re ]]; then
      session_file=$f
      break 2
    fi
  done
  nap
done

# Every other way out of this script is a normal end of session. This one is not:
# it means the plugin stayed silent for a whole session. Leave a trace, so that
# "it stopped alerting me" is answerable by reading a file instead of
# instrumenting the hooks by hand.
if [[ -z $session_file ]]; then
  printf '%s gave up: no session file for %s within %ss\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" "$session_id" "$discovery_budget" \
    >>"$state_dir/watch.log" 2>/dev/null
  exit 0
fi

# Claude Code unlinks its session file on the way out, so a file that is still
# there with a dead session means it was killed outright. The pid inside is then
# all there is to go on — and pids get recycled, which is exactly why Claude
# Code also records `procStart`. On Linux that is field 22 of /proc/<pid>/stat,
# readable without a fork; elsewhere `kill -0` alone is the floor.
alive() {
  local pid=$1 want=${2:-} line
  kill -0 "$pid" 2>/dev/null || return 1
  [[ -n $want && -r /proc/$pid/stat ]] || return 0
  read -r line <"/proc/$pid/stat" || return 0
  # The comm field is parenthesised and may itself hold spaces and parentheses,
  # so cut past the last ')' before splitting. Field 22 is then the 20th left.
  line=${line##*") "}
  set -- $line
  [[ ${20:-} == "$want" ]]
}

# `$(<file)` is read in-process: no fork per tick either.
held=0
fired=0
while :; do
  # The ordinary end of a watcher: Claude has removed its session file.
  [[ -r $session_file ]] || exit 0
  content=$(<"$session_file")

  # A <pid>.json that no longer names our session has been taken over by
  # another one, recycled pid and all.
  [[ $content =~ $id_re ]] || exit 0

  pid=""
  proc_start=""
  [[ $content =~ \"pid\"$sep([0-9]+) ]] && pid=${BASH_REMATCH[1]}
  [[ $content =~ \"procStart\"$sep\"?([0-9]+) ]] && proc_start=${BASH_REMATCH[1]}
  [[ -z $pid ]] || alive "$pid" "$proc_start" || exit 0

  if [[ $content =~ $waiting_re ]]; then
    # The marker goes up as the episode starts, not as the icon lands: it says
    # "a watcher owns this one", so the fallback event stays quiet even when the
    # configured delay puts our write after it.
    ((held == 0)) && : >"$marker"
    held=$((held + 1))
    if ((fired == 0 && held > delay_ticks)); then
      fired=1
      # No cwd in this payload on purpose: building JSON with printf would
      # break on a directory holding a quote, and tab-title.sh can read the cwd
      # out of the session file itself.
      printf '{"hook_event_name":"Notification","session_id":"%s"}' "$session_id" |
        STATUS_ICONS_FROM_WATCHER=1 bash "$here/tab-title.sh" >/dev/null 2>&1 &
    fi
  elif ((held > 0)); then
    held=0
    fired=0
    rm -f "$marker"
  fi

  nap
done
