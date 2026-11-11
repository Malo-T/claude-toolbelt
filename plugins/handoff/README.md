# handoff

A long session costs more and gets noisier. `/compact` decides for you what to keep. A handoff
lets you choose what the next session starts from.

`/handoff` writes a file with the goal, what is done, what was ruled out, the decisions, the
uncommitted files and the next step. When the turn ends, a mod runs `/clear` and submits a prompt
asking the fresh session to resume from that file. Without a freshly written handoff, `/clear`
does what it always did.

| Piece | What it does |
|---|---|
| `skills/handoff` | Writes the handoff under `<config>/handoffs/<project>/`, or resumes from one |
| `hooks/handoff.ts` | Mod: watches for that file, then runs `/clear` and the resume prompt at the end of the turn |

A file named `<name>.later.md` is for another day: the mod ignores it and the session goes on.
Resume it with `/handoff <path>`.

The mod API (the `claude-code` module) is early access and may change between Claude Code
releases. If `/clear` or the prompt fails, a toast shows the file path and you resume by hand.

Use it with `compact-nudge`, which tells you when the context is large enough to justify a handoff.

## Install

```
/plugin install handoff --marketplace Malo-T/claude-toolbelt
```
