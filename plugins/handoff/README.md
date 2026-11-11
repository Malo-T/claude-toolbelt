# handoff

A long session gets expensive and noisy. `/compact` summarises for you and keeps what it judges
important; a handoff lets you decide what the next session starts from.

The `/handoff` skill writes a file with the goal, what is done, what was ruled out, the decisions,
the uncommitted files and the next step. A mod then runs `/clear` once the turn ends and submits
"resume from this handoff" in the fresh session. Nothing resumes unless a handoff was just written:
a plain `/clear` stays a plain `/clear`.

| Piece | What it does |
|---|---|
| `skills/handoff` | Writes the handoff under `<config>/handoffs/<project>/`, or resumes from one |
| `hooks/handoff.ts` | Mod: watches for that file, then runs `/clear` and the resume prompt at the end of the turn |

A handoff named `<name>.later.md` is for another day: the mod ignores it and the session goes on.
Resume it yourself with `/handoff <path>`.

The mod API (`claude-code` module) is early access and moves between Claude Code releases. If
`/clear` or the prompt fails, a toast gives the file path and you resume by hand.

Pairs with `compact-nudge`, which tells you when the context is big enough to warrant one.

## Install

```
/plugin install handoff --marketplace Malo-T/claude-toolbelt
```
