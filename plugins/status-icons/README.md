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

## Install

```sh
claude plugin marketplace add Malo-T/claude-toolbelt
claude plugin install status-icons@claude-toolbelt
```

Why two commands, and how to update or install from a clone: root
[README](../../README.md#install).

It takes effect on the next session. Nothing to configure.

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

This is an undocumented implementation detail, verified against Claude Code **2.1.222**. It may
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

## Layout

```
.claude-plugin/plugin.json    # the plugin manifest
hooks/
├── hooks.json                # the events the script listens on
└── tab-title.sh              # the script itself
```

Development, validation and release are the same across the collection — see the root
[README](../../README.md#working-on-a-plugin).

## License

MIT — see the root [LICENSE](../../LICENSE).
