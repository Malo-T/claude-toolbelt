# status-sounds

Claude Code says little about itself when you are not looking at it — and when you have walked away
from the screen entirely, even a marked tab says nothing. This plugin plays a short sound at the
three moments worth looking up for.

| State | Sound (Linux / macOS) |
|---|---|
| Turn finished | `complete` / `Glass.aiff` |
| Turn finished with an error | `dialog-warning` / `Basso.aiff` |
| Waiting on you | `message-new-instant` / `Ping.aiff` |

Three sounds, where its sibling [`status-icons`](../status-icons) tells seven states apart: by ear
the one useful question is "do I need to go back?". The detail is there to read on the tab once you
are.

Sixty seconds after a turn ends, Claude Code sends itself one more notification (`idle_prompt`,
"Claude is waiting for your input") for anyone who missed the end-of-turn sound. By ear that is the
same ping as a real question, and it arrives when nothing at all is blocked, so this plugin stays
quiet on it — unless you name it a sound of its own, [below](#the-idle-reminder). `status-icons`
ignores the reminder outright.

The two are separate plugins on purpose — sound is intrusive where an icon is not — so installing
one does not oblige you to take the other.

## Configuration at a glance

Seven variables, all read fresh on every hook call, so they belong under `"env"` in `settings.json`
and take effect without touching the plugin:

| Variable | Default |
|---|---|
| `STATUS_SOUNDS_ALERT_DELAY` | `0` seconds blocked before the alert plays |
| `STATUS_SOUNDS_POLL_INTERVAL` | `0.25` seconds between watcher checks |
| `STATUS_SOUNDS_THEME` | `/usr/share/sounds/freedesktop/stereo` (Linux only) |
| `STATUS_SOUNDS_DONE_SOUND` | the theme's `complete` / `Glass.aiff` |
| `STATUS_SOUNDS_ERROR_SOUND` | the theme's `dialog-warning` / `Basso.aiff` |
| `STATUS_SOUNDS_ATTENTION_SOUND` | the theme's `message-new-instant` / `Ping.aiff` |
| `STATUS_SOUNDS_IDLE_SOUND` | none, the reminder stays silent |

The last four take a path to play instead of the default, or an empty string to silence that one
state. [Timing](#timing) covers the first two, [changing the sound set](#changing-the-sound-set) the
rest.

## Timing

A sound that arrives late has already failed: you looked up at the wrong moment, or not at all.

Claude Code holds its `Notification` event back by a hardcoded six seconds, so that answering a
prompt straight away never pings you. The state is not held back — `~/.claude/sessions/<pid>.json`
flips to `waiting` the instant the dialog opens, measured at +0 ms against +6020 ms for the event.
So [`hooks/watch.sh`](hooks/watch.sh) polls that file four times a second and plays the alert on the
transition, in **10–200 ms**. The event stays wired up behind it: no watcher, and the six-second
notification is still better than silence.

Consequence worth knowing: a prompt you answer inside six seconds used to be silent. It now makes a
sound. That is the point of the change, but it is a change — and `STATUS_SOUNDS_ALERT_DELAY` below is
the dial to turn if it makes the plugin chattier than you want.

The end-of-turn sound has never been late: that event fires the moment Claude goes idle, and the
script reaches the audio player 8 ms later.

### Two dials

Both are read from the environment, so they belong under `"env"` in `settings.json` and need no edit
to the plugin:

```jsonc
{
  "env": {
    "STATUS_SOUNDS_ALERT_DELAY": "1",      // seconds blocked before the sound — default 0
    "STATUS_SOUNDS_POLL_INTERVAL": "0.25"  // how often to look — default 0.25
  }
}
```

`ALERT_DELAY` is the one worth touching: it is Claude Code's six-second debounce, back under your
control. At `1`, a prompt you dismiss straight away stays silent while a real interruption still
reaches you five seconds sooner than before. `POLL_INTERVAL` caps how late the sound can be and is
mostly there for the very patient; raising it saves nothing measurable.

A value that is not a positive number falls back to the default rather than stopping the watcher.
Both are sanitised through `LC_ALL=C` — under a French locale `awk` prints `0,25`, and bash reads
`read -t 0,25` as *twenty-five seconds*, which would silently make the poll a hundred times slower
than the delay it exists to remove.

### Lifecycle, and why it leaves nothing behind

The watcher is one detached bash loop per session, started by `SessionStart` and stopped by
`SessionEnd`. It costs 0.2% of a core — it sleeps on a fifo through `read -t` rather than forking a
`sleep` four times a second, which would cost 2.5%.

`SessionStart` is not only session creation: Claude Code fires it again on resume, on `/clear` and on
`/compact`. A watcher already running for that session is left alone rather than restarted, since the
restart would open a gap in coverage and buy nothing.

On startup the watcher waits up to ten seconds for its session file to appear — `SessionStart` can
beat the file into existence. If it never does, the watcher gives up, and that is the one exit worth
knowing about, because it means the plugin stayed silent for a whole session. It writes a line to
`$TMPDIR/claude-status-sounds-<uid>/watch.log` on the way out, so that "it stopped making noise" is
answerable by reading a file rather than by instrumenting the hooks.

`SessionEnd` is not what it relies on, though, because a terminal closed abruptly or a `kill -9`
never fires it. Each tick re-checks four things, and any one of them ends the loop within 250 ms:

- the session file is gone — Claude Code unlinks it on exit, so this is the ordinary path;
- the file no longer names this session, meaning another one took the `<pid>.json` over;
- the pid inside it is dead;
- the pid is alive but is **not the same process** — pids get recycled, so the recorded `procStart`
  is compared against field 22 of `/proc/<pid>/stat`, read without a fork. On a system without
  `/proc`, `kill -0` alone is the floor.

The same care applies in the other direction: a watcher that was killed outright leaves its pidfile
behind, so nothing is ever signalled without first confirming its command line is this very script.
A stale pidfile can therefore never make the plugin kill an unrelated process.

That kill is also what clears the marker saying "a watcher owns this episode" — so a `kill -9`, which
runs no trap, leaves the marker behind. `play.sh` therefore never yields to the marker alone: it
reads the pidfile beside it and stays quiet only for a watcher that is genuinely alive. Otherwise the
one failure this whole mechanism is meant to prevent would be its own worst case, a session gone
permanently silent instead of six seconds late.

## Requirements and portability

- **`jq`** on the `PATH`.
- An audio player: `canberra-gtk-play`, `paplay` or `aplay` on Linux, `afplay` on macOS.

When one of these is missing, or the sound file is unreadable, the script exits without doing
anything. No message, no slowdown, and Claude keeps its original behaviour. It is written for bash
3.2, the version macOS still ships.

## Changing the sound set

The Linux sound theme is set through `STATUS_SOUNDS_THEME`, pointing at a directory holding
`complete.oga`, `dialog-warning.oga` and `message-new-instant.oga`. It defaults to the freedesktop
theme at `/usr/share/sounds/freedesktop/stereo`. macOS uses `/System/Library/Sounds` and ignores the
variable. To change or silence one sound rather than the set, use the per-state variables below.

Beyond that it all sits in the `case` statements of [`hooks/play.sh`](hooks/play.sh), in plain sight.

### One state at a time

The theme moves all three sounds together. Each state also answers to a variable of its own, holding
the path to play instead of the default:

| Variable | State |
|---|---|
| `STATUS_SOUNDS_DONE_SOUND` | turn finished |
| `STATUS_SOUNDS_ERROR_SOUND` | turn finished with an error |
| `STATUS_SOUNDS_ATTENTION_SOUND` | waiting on you |
| `STATUS_SOUNDS_IDLE_SOUND` | the 60 s reminder |

Give one an empty string and that state goes quiet while the rest keep their sound:

```jsonc
{
  "env": {
    "STATUS_SOUNDS_DONE_SOUND": "",                                // never again
    "STATUS_SOUNDS_ATTENTION_SOUND": "/home/you/sounds/knock.oga"  // yours
  }
}
```

Leaving a variable out is not the same as emptying it: out means the default, empty means off. `""`
is the one spelling of off, in settings.json as everywhere else in this README.

Each takes a whole path rather than an entry in `STATUS_SOUNDS_THEME`, so a single replacement needs
no theme directory and the same setting works on macOS, where the theme variable is ignored. An
unreadable path is silent, like every other missing sound here — which means a typo and a deliberate
`""` sound identical. Check the path if a state went quiet on you and you did not ask for it.

### The idle reminder

Unlike the other three, it has no sound of its own to start with — silent until you name one:

```jsonc
{
  "env": {
    // On macOS, /System/Library/Sounds/Submarine.aiff
    "STATUS_SOUNDS_IDLE_SOUND": "/usr/share/sounds/freedesktop/stereo/dialog-information.oga"
  }
}
```

Setting `STATUS_SOUNDS_IDLE_SOUND` is what turns the reminder on: there is no separate switch, and
nothing to turn back off beyond emptying that one variable, same as any other state.

Part of [claude-toolbelt](../../README.md), where install, development and licence live.
