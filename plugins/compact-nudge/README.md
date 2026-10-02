# compact-nudge

Every API request in a Claude Code session sends the whole conversation, and every tool call is a
request. The prompt cache makes that resend cheap per token, but it still bills the full context on
each call: cache reads end up as almost all of a session's tokens, and a call at 400k costs about
five times what a call under 100k does. Auto-compact does not step in before roughly 967k on a 1M
model, so a long session pays that price for hours.

This plugin speaks up at the two moments where acting is cheapest:

| Moment | Hook | What you see |
|---|---|---|
| The context has just crossed a threshold (150k, 250k, 400k by default) | `Stop` | A one-line message under the turn: current size, and `/clear` or `/compact` depending on whether the task is done |
| You come back after the cache expired, with a large context | `UserPromptSubmit` | The prompt is held once, with the idle time and the size about to be rewritten |

Each threshold fires once per session, and fires again if a compaction brings the context back
under it.

## Why the cold-cache check blocks

A prompt cache entry lives 5 minutes, or 1 hour for the main conversation on a Claude subscription,
and every read restarts that clock. Past it, the next request writes the whole context back at the
cache-write price: 2× the input price on the 1-hour TTL, against 0.05× to 0.1× for a read. On 400k
of context with Claude Opus 5.5 that is about $3.20, where a `/compact` first would cost about
$0.12.

A warning shown after the prompt is sent arrives once that cost is already paid, so by default the
hook blocks the prompt instead. Sending it again goes through: the hook holds a prompt only once per
cold episode. Slash commands are never held, so `/compact` and `/clear` always pass.

The TTL is read from the transcript itself (the last cache write says `ephemeral_1h` or
`ephemeral_5m`), so API-key sessions on 5 minutes and subscription sessions on 1 hour both get the
right window.

## Configuration

All variables are read on every hook call, so they belong under `"env"` in `settings.json`:

| Variable | Default | Meaning |
|---|---|---|
| `COMPACT_NUDGE_THRESHOLDS` | `150k 250k 400k` | Context sizes that trigger the `Stop` message, space-separated, `k`/`m` suffixes accepted |
| `COMPACT_NUDGE_COLD_MODE` | `block` | `block` holds the prompt once, `warn` only shows a message, `off` disables the check |
| `COMPACT_NUDGE_COLD_MIN` | `100k` | Smallest context worth holding a prompt for |
| `COMPACT_NUDGE_CACHE_TTL` | read from the transcript | Forces the cache lifetime, as `5m`, `1h` or seconds |

For a session nobody watches, Claude Code's own `CLAUDE_CODE_AUTO_COMPACT_WINDOW` (or
`/autocompact 400k`) moves the auto-compact threshold down. It compacts without asking, possibly
mid-task, which is why this plugin suggests rather than acts.

## How it reads the context size

Hook payloads carry no token counts, only `transcript_path`. The script reads the last 4 MB of the
transcript and takes the usage of the last main-thread API call (input + cache writes + cache
reads), or the post-compaction size when a `compact_boundary` comes after it. Subagent calls are
ignored. On a 19 MB transcript this takes about 70 ms.

State lives in `$TMPDIR/compact-nudge/<session id>.*`, one small file per check.

Requires `bash` (3.2 or later) and `jq`.
