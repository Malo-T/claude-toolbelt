# status-icons

Claude Code says little about itself when you are not looking at it. The terminal tab title is
prefixed with a blinking dot while it works and with a `✳` once it stops — but "I am done" and "I am
blocked on a permission prompt" produce the same star. In a row of tabs, nothing tells you which one
wants you.

This plugin puts the answer in the tab.

| State | Tab |
|---|---|
| Turn finished | ✅ *topic* |
| Turn finished with an error | ❌ *topic* |
| Permission prompt | 🔐 *topic* |
| Question asked | ❓ *topic* |
| Sandbox asking to reach out | 🧱 *topic* |
| A worker asking for something | 🤖 *topic* |
| Session paused | 💤 *topic* |
| Session ended | *directory*, no prefix |

**No "working" icon.** That is not an oversight: while Claude sits in the `busy` state it rewrites
the title every 960 ms, alternating two braille characters. Any hook writing during that window
would be wiped within a second. The title belongs to something other than Claude only between turns,
and that is exactly the window this plugin occupies.

A useful corollary: there is nothing to clean up. Claude takes the title back on its next state
change — the very moment the marker should disappear.

**Nothing on the idle reminder either.** That notification fires when nothing is blocked: Claude is
done, you are the one who walked away. The `✅` from the previous turn is left in place rather than
replaced by a false "you are needed". Its sibling [`status-sounds`](../status-sounds) makes the
opposite call, and is right to — you are not in front of the screen to see a tab.

## Timing

An icon that arrives late is worse than useless: you have already switched tabs to find out. Two
delays sat between the state changing and the tab showing it, and both are gone.

**Six seconds on anything you are blocked on.** Claude Code holds its `Notification` event back by a
hardcoded six seconds, so that answering a prompt straight away never pings you. The state is not
held back — `~/.claude/sessions/<pid>.json` flips to `waiting` the instant the dialog opens, measured
at +0 ms against +6020 ms for the event. So [`hooks/watch.sh`](hooks/watch.sh) polls that file four
times a second and marks the tab on the transition, in **10–200 ms**. The event stays wired up
behind it: no watcher, and the six-second notification is still better than no icon.

Consequence worth knowing: a prompt you answer inside six seconds used to produce no notification at
all. It now gets an icon. That is the point of the change, but it is a change, and
`STATUS_ICONS_ALERT_DELAY` below is the dial that puts it back.

**440 ms at the end of every turn.** The script used to sleep before writing, to be sure of landing
after Claude's own title write. It now writes at once *and* again after the wait: the first write
wins outright when Claude has already let go of the title, and the second is exactly the old
behaviour when it has not. Measured at **16 ms** for the first write.

### Two dials

Both are read from the environment, so they belong under `"env"` in `settings.json` and need no edit
to the plugin:

```jsonc
{
  "env": {
    "STATUS_ICONS_ALERT_DELAY": "1",      // seconds blocked before the icon — default 0
    "STATUS_ICONS_POLL_INTERVAL": "0.25"  // how often to look — default 0.25
  }
}
```

`ALERT_DELAY` is Claude Code's six-second debounce, back under your control: at `1`, a prompt you
dismiss straight away never disturbs the tab, while a real interruption still shows up five seconds
sooner than before. `POLL_INTERVAL` caps how late the icon can be; raising it saves nothing
measurable.

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
knowing about, because it means the tab went unmarked for a whole session. It writes a line to
`$TMPDIR/claude-status-icons-<uid>/watch.log` on the way out, so that "it stopped marking the tab" is
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
runs no trap, leaves the marker behind. `tab-title.sh` therefore never yields to the marker alone: it
reads the pidfile beside it and stands down only for a watcher that is genuinely alive. Otherwise the
one failure this whole mechanism is meant to prevent would be its own worst case, a session left
permanently unmarked instead of six seconds late.

## Requirements and portability

- **`jq`** on the `PATH`.
- A terminal that shows the OSC 0 title in its tab — most do (Ptyxis, GNOME Terminal, Konsole, kitty,
  Ghostty, WezTerm, Alacritty, Windows Terminal…).
- Linux or macOS: a hook has no controlling terminal of its own, so it has to aim at the Claude
  process's stdout, through `/proc/<pid>/fd/1` on Linux and `lsof` elsewhere.

When one of these is missing the script exits without doing anything. No message, no slowdown, and
Claude keeps its original behaviour. It is written for bash 3.2, the version macOS still ships.

## What it rests on

The state comes from `~/.claude/sessions/<pid>.json`, which Claude Code maintains for its own use:
it writes its status there (`idle`, `busy`, `waiting`, `shell`), the `waitingFor` field that says
*why* it is waiting, and the topic name shown in the tab.

This is an undocumented implementation detail, verified against Claude Code **2.1.223**. It may
change shape without notice. The script is written so that this stays harmless: a missing or renamed
field makes it exit in silence, and an unknown `waitingFor` value falls back to `❓` rather than
showing nothing.

Every icon is emoji by default, with no `U+FE0F` variation selector: that selector is rendered
unevenly from one terminal to the next and sometimes yields a narrow monochrome glyph, or a tofu box,
in the middle of a coloured set. Hence `❌` rather than `⚠️` here, and `💤` rather than `⏸️`.

## Changing the icon set

It all sits in the `case` statements of [`hooks/tab-title.sh`](hooks/tab-title.sh), in plain sight.
The `waitingFor → prefix` table covers every value Claude produces; adding a new one is a single
line.

Part of [claude-toolbelt](../../README.md), where install, development and licence live.
