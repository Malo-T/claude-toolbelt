# session-status

Claude Code says little about itself when you are not looking at it. The terminal tab title is
prefixed with a blinking dot while it works and with a `✳` once it stops — but "I am done" and "I am
blocked on a permission prompt" produce the same star. In a row of tabs, nothing tells you which one
wants you.

This repository publishes two independent modules that fill that gap, each on its own channel.

| Module | Channel |
|---|---|
| [`status-icons`](plugins/status-icons) | an icon in the terminal tab |
| [`status-sounds`](plugins/status-sounds) | a short sound |

They are separate because they are not worth the same in practice: icons cost nothing and suit
anywhere, sound is intrusive in an open-plan office. Installing one does not oblige you to take the
other.

## status-icons

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
and that is exactly the window this module occupies.

A useful corollary: there is nothing to clean up. Claude takes the title back on its next state
change — the very moment the marker should disappear.

**Nothing on the idle reminder either.** That notification fires when nothing is blocked: Claude is
done, you are the one who walked away. The `✅` from the previous turn is left in place rather than
replaced by a false "you are needed".

## status-sounds

| State | Sound |
|---|---|
| Turn finished | `complete` / `Glass.aiff` |
| Turn finished with an error | `dialog-warning` / `Basso.aiff` |
| Waiting on you | `message-new-instant` / `Ping.aiff` |

Three sounds where the icons tell seven states apart: by ear the one useful question is "do I need
to go back?". The detail is there to read on the tab once you are.

Unlike the icons, the sound does fire on the idle reminder — that is precisely where it earns its
keep, since you are not in front of the screen.

The Linux sound theme is set through `SESSION_STATUS_SOUND_THEME`, pointing at a directory holding
`complete.oga`, `dialog-warning.oga` and `message-new-instant.oga`. It defaults to the freedesktop
theme.

## Install

This repository is its own marketplace. While it is unpublished, add it by path:

```sh
claude plugin marketplace add ~/workspace/claude/session-status
claude plugin install status-icons@session-status
claude plugin install status-sounds@session-status   # optional
```

Once pushed to GitHub, the first command takes the shorthand instead
(`claude plugin marketplace add Malo-T/session-status`). Two commands are needed either way:
`claude plugin install` only resolves names against marketplaces that are already configured.

Both take effect on the next session. Nothing to configure.

## Requirements and portability

- **`jq`** on the `PATH`, for both modules.
- **status-icons**: a terminal that shows the OSC 0 title in its tab — most do (Ptyxis, GNOME
  Terminal, Konsole, kitty, Ghostty, WezTerm, Alacritty, Windows Terminal…). Linux or macOS: a hook
  has no controlling terminal of its own, so it has to aim at the Claude process's stdout, through
  `/proc/<pid>/fd/1` on Linux and `lsof` elsewhere.
- **status-sounds**: `canberra-gtk-play`, `paplay` or `aplay` on Linux, `afplay` on macOS.

When one of these is missing, the script concerned exits without doing anything. No message, no
slowdown, and Claude keeps its original behaviour. Both scripts are written for bash 3.2, the
version macOS still ships.

## What the icons rest on

The state comes from `~/.claude/sessions/<pid>.json`, which Claude Code maintains for its own use:
it writes its status there (`idle`, `busy`, `waiting`, `shell`), the `waitingFor` field that says
*why* it is waiting, and the topic name shown in the tab.

This is an undocumented implementation detail, verified against Claude Code **2.1.222**. It may
change shape without notice. The script is written so that this stays harmless: a missing or renamed
field makes it exit in silence, and an unknown `waitingFor` value falls back to `❓` rather than
showing nothing.

Every icon is emoji by default, with no `U+FE0F` variation selector: that selector is rendered
unevenly from one terminal to the next and sometimes yields a narrow monochrome glyph, or a tofu box,
in the middle of a coloured set. Hence `❌` rather than `⚠️` here, and `💤` rather than `⏸️`.

## Changing the icon and sound sets

It all sits in the `case` statements of `plugins/status-icons/hooks/tab-title.sh` and
`plugins/status-sounds/hooks/play.sh`, in plain sight. On the icon side, the `waitingFor → prefix`
table covers every value Claude produces; adding a new one is a single line.

One thing to watch while developing: `claude plugin install` **copies** the repository into
`~/.claude/plugins/cache/`. An edit here has no effect until
`claude plugin marketplace update session-status` has run.

## Licence

MIT
