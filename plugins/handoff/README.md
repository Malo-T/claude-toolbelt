# handoff

A long session gets expensive and noisy. `/compact` summarises for you and keeps what it judges
important; a handoff lets you decide what the next session starts from.

The `/handoff` skill writes a file with the goal, what is done, what was ruled out, the decisions,
the uncommitted files and the next step. It then records the file as pending for the current
directory. After you type `/clear`, a `SessionStart` hook tells the fresh session to resume from it.

| Piece | What it does |
|---|---|
| `skills/handoff` | Writes the handoff under `<config>/handoffs/<repo>/`, or resumes from one |
| `skills/handoff/scripts/mark-pending.sh` | Records the file as pending for the directory |
| `hooks/resume.sh` | On `SessionStart` after `/clear`, injects the resume instruction |

A hook cannot run `/clear`, so you type it. A pending marker older than an hour is ignored, and a
handoff written "for later" (`.later.md`) never gets one.

Pairs with `compact-nudge`, which tells you when the context is big enough to warrant one.

## Install

```
/plugin install handoff --marketplace Malo-T/claude-toolbelt
```
