# Roadmap

`clean-context` ships two skills. Both cover the **repository's own content** and how much of it
Claude reads by default.

| Skill | Source it addresses | Status |
|---|---|---|
| `audit-context` | none — it measures, so the other one has targets | shipped |
| `ignore-setup` | files surfaced by `Glob` / `Grep` / the `@` picker | shipped |

`audit-context` came first, because `ignore-setup` otherwise applies its catalogue blind, and
because a measured before/after is what makes the exclusions safe to accept.

## What the transcripts said

Every estimate in this plugin used to come from disk: file sizes, `Glob` counts, `CLAUDE.md` bytes.
Joining `tool_use` to `tool_result` across 67 sessions of this repository gave the first measurement
of what sessions actually pulled into context — roughly 472k tokens — and it disagreed with the
disk-based ranking on nearly every point:

| Tool | Calls | Tokens est. | Share |
|---|---|---|---|
| `Bash` | 783 | 232 800 | 49% |
| `Read` | 200 | 203 500 | 43% |
| `Edit` | 214 | 10 100 | 2% |
| `Grep` | 9 | 1 300 | 0.3% |
| `Glob` | 11 | 543 | 0.1% |

`Glob` and `Grep` — everything `ignore-setup` exists to narrow — account for 0.4% of the volume.
The heaviest single file was a 2.4k-token `SKILL.md` opened fifteen times across sessions, at 36k
tokens — legitimate hand-written source that no exclusion rule would ever target. Cost turns out to
be size multiplied by re-reads, and neither this plugin nor `/doctor` had measured that product.

Three consequences. `audit-context` gained Step 5 so the measurement precedes the ranking rather
than trailing it. The backlog below came out of the same numbers. And every ticket in it carries
the measurement that justifies it, so a later run that contradicts the figure retires the ticket
rather than inheriting it.

## Where this plugin stops: `/doctor`

Claude Code 2.1.229 ships a built-in skill, reachable as `/doctor`, that health-checks the
installation and then hunts context bloat across ten checks. Its checks 1 through 4 cover, in full,
what this plugin had planned for its next two skills.

- **`/doctor` audits the Claude Code setup**: installed skills, plugins and MCP servers weighed
  against usage counters (`skillUsage`, `pluginUsage`) and transcripts from every project the user
  has opened; `CLAUDE.md` dedup, derivable-content trimming, and migration to lazy loading; slow
  hooks; resident context per component against the skill-listing budget.
- **`clean-context` audits the repository**: what `Glob` and `Grep` return from this working tree,
  which of its largest files are generated, and the three exclusion levers that narrow that reach.
  `/doctor` never opens the repository's own files — "glob" appears nowhere in its instructions, and
  its single mention of `.gitignore` is the adjective describing `.claude/settings.local.json`.

Build nothing that lands on `/doctor`'s side of that line. A skill costs its description in resident
context, in every session and every project, for as long as it stays installed. Duplicate a built-in
and you pay that price to hand the user what they already have.

## `audit-context` — measure before regulating

The diagnostic counterpart to `ignore-setup`. On a given project, it reports:

- what `Glob **/*` actually returns, with and without the ignore files applied
- the twenty largest files in the repository, and which of them are generated
- the cumulative size of every `CLAUDE.md` loaded automatically for this working directory,
  walking the nesting upward
- how many MCP servers are enabled here and how many tools they contribute
- what the newest 50 sessions actually injected, per tool, command and file (Step 5)

Output is a table of levers ranked by estimated gain, with Step 5's observed cost beside each
estimate. Where the two disagree the observation wins: one is what the project could cost, the other
is what it did. Two rows hand off to `/doctor` rather than to a skill here — they measure a setup
this plugin never touches. Drop them and the report covers a fraction of the budget while implying
the whole.

**Unit decision.** Bytes mislead on minified assets and on CJK text, and no local Claude tokenizer
exists to correct for it: the only exact count runs through the Messages API's `count_tokens`
endpoint, a network call with credentials that is too heavy for a diagnostic meant to run anywhere.
The skill detects, lazily on its own first run rather than through a session hook, whether
`gpt-tokenizer` (npm) or `tiktoken` (pip) is already reachable, and uses whichever is found for a
GPT-vocabulary approximation, clearly flagged as an approximation rather than a Claude-exact count.
`@anthropic-ai/tokenizer` was considered and rejected: unmaintained for years, its Claude-branded
name would overstate an accuracy it no longer has against current models. Absent either tool, and
absent the user's consent to fetch one on the spot, the skill falls back to bytes plus a bytes/word
density ratio: a mechanical signal that flags exactly the minified/CJK cases the byte count
mishandles, without inventing a fake token count.

The two tokenizers were not picked for any accuracy difference between them: a check on this
repository's own CLAUDE.md files and its twenty largest files put `gpt-tokenizer`'s default output
(the `o200k_base` encoding) within 0.3% of `tiktoken` on either of its common encodings. The
choice between them comes down to which ecosystem a given developer's machine already has, npm or
pip, not which one is "more correct".

## Backlog

Four tickets, ordered by the share of injected volume each addresses, and tracked as GitHub issues
[#5][cc1], [#6][cc2], [#7][cc3] and [#4][cc4]. Every one sits on this plugin's side of the `/doctor`
line, and every one names the measurement that justifies it: rerun `audit-context` Step 5 on a real
project, and a ticket whose number collapses should be closed rather than carried.

[cc1]: https://github.com/Malo-T/claude-toolbelt/issues/5
[cc2]: https://github.com/Malo-T/claude-toolbelt/issues/6
[cc3]: https://github.com/Malo-T/claude-toolbelt/issues/7
[cc4]: https://github.com/Malo-T/claude-toolbelt/issues/4

### CC-1 — Bash output discipline ([#5][cc1])

*49% of injected volume, ~3.5k tokens per session on this repository.* The single largest source,
and the one with no lever at all today. Sessions pay for whole test suites, unbounded `git log`,
verbose builds and `cat` on files that wanted `sed -n`. Two shapes are worth trying, in this order:
a handful of lines in `CLAUDE.md` (`-n` on log commands, `| tail`, `--quiet`, redirect-then-read),
which costs about 50 resident tokens per session against a 3.5k-token target and needs no skill at
all; or a `PreToolUse` hook that warns on known-unbounded patterns, which is more intrusive and
should wait until the cheap version proves insufficient. Settle first whether this belongs to
`clean-context` at all — a `CLAUDE.md` convention is not a plugin, and shipping it as one would be
the same mistake `trim-mcp` made.

### CC-2 — Size × re-reads as a first-class signal ([#6][cc2])

*43% of injected volume goes through `Read`; the top file cost 36k tokens as 2.4k read fifteen
times.* Step 5 surfaces the product; nothing acts on it. The levers are unlike anything else in this
plugin, since the files are legitimate and exclusion is the wrong answer: split the file so sessions
open the part they need, or write down the invariant that keeps sending them back. Both are
judgment calls a skill can propose but should never apply on its own. Likely an extension of
`audit-context`'s report rather than a new skill — it has the data already.

### CC-3 — `.gitattributes -diff` for generated files ([#7][cc3])

*`git` accounted for 40k tokens over 129 calls.* A `git diff` touching a lockfile injects the entire
diff. Marking those paths `-diff` in `.gitattributes` collapses it to `Binary files a/… and b/…
differ`, and `--stat` to `Bin 6 -> 10 bytes` — verified on a scratch repository, not assumed. This is
the natural second lever for `ignore-setup`: same catalogue of generated paths, one more file to
write. Two differences from everything that skill writes today, both of which have to reach the
user before anything is written. `.gitattributes` is checked in, so this is a team decision rather
than a personal setting like `.claude/settings.local.json`. And it blinds the human's own `git
diff` on those paths, `git add -p` included, which is fine for a lockfile and wrong for anything
someone reviews by hand.

### CC-4 — `read-guard` ([#4][cc4])

*`Read` is the second-largest source at 43%.* A `PreToolUse` hook warning when a `Read` targets a
large generated file. It completes the plugin's asymmetry: an ignore file hides a path from
discovery but never blocks `Read`, so the reading side has no guardrail at all. Held back for the
same reason as before — a hook is more intrusive than a skill and the false-positive rate is
unknown — but the measurement now argues for it where previously only symmetry did. Sequence it
after CC-1: if command output is half the problem, a hook that only watches `Read` fixes the
smaller half while paying the full intrusiveness cost.

## Abandoned

**`trim-mcp`** ([#2][x2], closed) — written, never published, then dropped. It inventoried a
project's `.mcp.json` servers, crossed them against `mcp__<server>__*` calls in that project's
transcripts, and wrote `disabledMcpjsonServers` into `.claude/settings.local.json`. Two findings, in
the order they landed:

1. **The gain it advertised no longer exists.** MCP tool schemas sit deferred behind `ToolSearch` by
   default: only each tool's *name* stays resident, and Claude Code fetches the schema on demand. A
   server contributing fifty tools costs a few hundred tokens against the tens of thousands the
   premise assumed. Claude Code's own instructions to `/doctor` say it outright — never recommend
   disabling a server to save context when its tools are deferred. One exception: tools carrying
   `anthropic/alwaysLoad` in their `_meta`, which the server decides and the user cannot override.
2. **`/doctor` already writes the same key.** Its check 1 reaches the same verdict from more
   evidence — usage counters plus transcripts across every project rather than one — and applies it
   to the same `disabledMcpjsonServers` in the same `.claude/settings.local.json`.

Then the arithmetic. `/context` priced its listing entry at ~350 resident tokens, paid in every
session of every project, against savings on the order of 140 tokens once, in a single project. The
chars/4 estimate that first made the case said 254, so the real balance was worse than the one that
retired it.

Two corrections worth keeping from it:

- **A user-scope server can be disabled per project.** `/mcp disable <server>` persists to
  `disabledMcpServers` in that project's entry of `~/.claude.json`, reversible with `/mcp enable`.
  The toggle is per-project even for a server added with `claude mcp add -s user`, so silencing one
  everywhere means repeating it per project. The earlier claim here — that `claude mcp remove` was
  the only lever, and global — was wrong.
- **Never reach for `claude mcp remove` to quiet a server.** It deletes the server's configuration,
  including `env` and `headers`, and wipes its OAuth tokens. For `claude.ai` connectors
  specifically, the `disableClaudeAiConnectors` setting turns all of them off at once and destroys
  nothing.

**`trim-preamble`** ([#3][x3], closed) — moving long `CLAUDE.md` and `SKILL.md` sections to
`references/` and leaving a pointer. It already had a scope conflict to settle against
`claude-md-management:claude-md-improver`; `/doctor`'s checks 2 through 4 then took the whole idea —
dedup of local memory files against checked-in ones, deleting content a session could derive on its
own, migrating always-loaded guidance to lazy loading — which leaves nothing to carve out.

**Auditing user-scope MCP servers across all projects** — `/doctor`'s check 1 scans transcripts from
every project the user has opened. That was the missing piece, and it shipped before anyone here
specified the skill.

[x2]: https://github.com/Malo-T/claude-toolbelt/issues/2
[x3]: https://github.com/Malo-T/claude-toolbelt/issues/3

## Considered, not planned

**`refresh-ignore`** — re-applying exclusions after the project changes shape (a new dependency, a
new generated directory). Not a separate skill: `ignore-setup` already detects its own managed block
and rewrites the body, so this is a re-run, and the guardrail that a second run be a no-op already
covers it.

**Narrowing `Glob` further** — more patterns, tighter defaults, a second exclusion layer. Step 5
measured `Glob` and `Grep` at 0.4% of injected volume on this repository, so there is close to
nothing left to win. The caveat that keeps this a "not planned" rather than a "never": this
repository is small, mostly markdown, and has no build. A monorepo carrying `node_modules` and a
generated client would very likely put `Glob` back near the top, which is the whole reason Step 5
measures instead of assuming.
