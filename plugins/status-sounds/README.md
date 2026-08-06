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

Unlike the icons, the sound *does* fire on the idle reminder — that is precisely where it earns its
keep, since you are not in front of the screen.

The two are separate plugins because they are not worth the same in practice: icons cost nothing and
suit anywhere, sound is intrusive in an open-plan office. Installing one does not oblige you to take
the other.

## Install

```sh
claude plugin marketplace add Malo-T/claude-toolbelt
claude plugin install status-sounds@claude-toolbelt
```

It takes effect on the next session. Nothing to configure.

## Requirements and portability

- **`jq`** on the `PATH`.
- An audio player: `canberra-gtk-play`, `paplay` or `aplay` on Linux, `afplay` on macOS.

When one of these is missing, or the sound file is unreadable, the script exits without doing
anything. No message, no slowdown, and Claude keeps its original behaviour. It is written for bash
3.2, the version macOS still ships.

## Changing the sound set

The Linux sound theme is set through `SESSION_STATUS_SOUND_THEME`, pointing at a directory holding
`complete.oga`, `dialog-warning.oga` and `message-new-instant.oga`. It defaults to the freedesktop
theme at `/usr/share/sounds/freedesktop/stereo`. macOS uses `/System/Library/Sounds` and ignores the
variable.

Beyond that it all sits in the `case` statements of [`hooks/play.sh`](hooks/play.sh), in plain sight.
See the root [README](../../README.md#working-on-a-plugin) for how to try an edit out without pushing
it.

## License

MIT — see the root [LICENSE](../../LICENSE).
