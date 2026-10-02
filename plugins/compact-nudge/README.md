# compact-nudge

Claude Code sends the whole conversation with each API request, and each tool call counts as a
request. The prompt cache cuts the price per token of that resend, yet you still pay for the full
context on every call. Cache reads end up as almost all of a session's tokens, and a call at 400k
costs about five times what a call under 100k does. On a 1M model, Claude Code waits until roughly
967k before it auto-compacts, so a long session pays that price for hours.

This plugin tells you at the two moments where `/compact` or `/clear` saves the most:

| Moment | Hook | What you see |
|---|---|---|
| The context has just crossed a threshold (150k, 250k, 400k by default) | `Stop` | A one-line message under the turn with the current size, plus `/clear` or `/compact` depending on whether the task is done |
| You come back after the cache expired, with a large context | `UserPromptSubmit` | The hook holds your prompt once and shows the idle time and the size about to be rewritten |

You get each threshold message once per session, and again if a compaction brings the context back
under that threshold.

## Why the cold-cache check blocks

A prompt cache entry lives 5 minutes, or 1 hour for the main conversation on a Claude subscription,
and each read restarts that clock. Once it expires, your next request writes the whole context back
at the cache-write price: 2× the input price on the 1-hour TTL, against 0.05× to 0.1× for a read.
On 400k of context with Claude Opus 5.5, that comes to about $3.20. A `/compact` first costs about
$0.12.

By the time a warning could appear after you send the prompt, you have already paid for the
rewrite. So by default the hook holds the prompt before it leaves. Send it again and it goes
through: the hook holds one prompt per cold episode. It lets slash commands pass, so `/compact` and
`/clear` work at any time.

The hook reads the TTL from the transcript itself: the last cache write says `ephemeral_1h` or
`ephemeral_5m`. API-key sessions on 5 minutes and subscription sessions on 1 hour both get the right
window.

## Configuration

The hook reads these variables on each call, so set them under `"env"` in `settings.json`:

| Variable | Default | Meaning |
|---|---|---|
| `COMPACT_NUDGE_THRESHOLDS` | `150k 250k 400k` | Context sizes that trigger the `Stop` message, space-separated, `k`/`m` suffixes accepted |
| `COMPACT_NUDGE_COLD_MODE` | `block` | `block` holds the prompt once, `warn` shows a message after sending, `off` disables the check |
| `COMPACT_NUDGE_COLD_MIN` | `100k` | Smallest context worth holding a prompt for |
| `COMPACT_NUDGE_CACHE_TTL` | read from the transcript | Forces the cache lifetime, as `5m`, `1h` or seconds |

For a session you leave running unattended, set Claude Code's own `CLAUDE_CODE_AUTO_COMPACT_WINDOW`
(or run `/autocompact 400k`) to lower the auto-compact threshold. Claude Code then compacts without
asking, possibly in the middle of a task. This plugin leaves that decision to you.

## How it reads the context size

Hook payloads carry no token counts, only `transcript_path`. The script reads the last 4 MB of the
transcript and takes the usage of the last main-thread API call (input, cache writes and cache
reads). When a `compact_boundary` record comes after that call, it uses the post-compaction size
instead. It skips subagent calls. On a 19 MB transcript the whole check takes about 70 ms.

The script keeps its state in `$TMPDIR/compact-nudge/<session id>.*`, one small file per check.

Requires `bash` 3.2 or later and `jq`.
