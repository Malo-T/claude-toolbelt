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

**That table keeps the record on the wrong axis.** Grouping by tool answers "through which
channel", a different question from "why". Rerun across three unrelated projects, the split moves —
`Bash` 46 / `Read` 45 here, `Read` 53 / `Bash` 42 elsewhere — while the `Bash` column proves to be
mostly files read through a shell. Reprojected onto files, across both channels, twelve of them
carry 88% of the attributable volume here, all hand-written, all reopened across many sessions.
Step 5 now ends on that per-file table, and CC-1 went to Abandoned on the strength of it.

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

Three tickets, ordered by the share of injected volume each addresses, and tracked as GitHub issues
[#6][cc2], [#7][cc3] and [#4][cc4]. Every one sits on this plugin's side of the `/doctor` line, and
every one names the measurement that justifies it: rerun `audit-context` Step 5 on a real project,
and a ticket whose number collapses should be closed rather than carried. CC-1 went that way, on a
wrong attribution rather than a collapsing number; see Abandoned.

[cc1]: https://github.com/Malo-T/claude-toolbelt/issues/5
[cc2]: https://github.com/Malo-T/claude-toolbelt/issues/6
[cc3]: https://github.com/Malo-T/claude-toolbelt/issues/7
[cc4]: https://github.com/Malo-T/claude-toolbelt/issues/4

### CC-2 — Size × reopenings as a first-class signal ([#6][cc2])

*Twelve files carry 88% of the attributable injected volume on this repository, and the worst case
measured anywhere was a 5.2k-token script opened 295 times across 28 sessions for 169k tokens — 32×
its own weight.* Step 5 now reports the product, across both channels rather than through `Read`
alone; nothing acts on it yet. The levers are unlike anything else in this plugin, since the files
are legitimate and exclusion is the wrong answer. The `sessions` column picks between them. Many
opens inside one session means the file was the work, and nothing needs fixing. Many opens spread
across many sessions means the knowledge is not written down: split the file if it is large, move
its one fact into resident context if it is small. All three are judgment calls a skill can propose
but must never apply on its own.

`audit-context` Step 5 already carries the measurement (per-file table, `opens`/`sessions`/`ratio`).
This ticket now covers the recommending side alone: turning a row of that table into a named
candidate with a named lever, still as a proposal.

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
unknown — but the measurement now argues for it where previously only symmetry did. The old note to
sequence it after CC-1 is void. The per-file table both helps and hurts this ticket: it confirms
`Read` is expensive, and it shows that not one of the twelve files carrying that cost is generated,
so `read-guard` would not have fired on any of them. It covers a case this repository does not
have. Build it once some project's per-file table puts a generated file on top.

## Abandoned

**CC-1, Bash output discipline** ([#5][cc1], closed) — the ticket read `Bash` at 49% of injected
volume and blamed whole test suites, unbounded `git log`, verbose builds and `cat` on files that
wanted `sed -n`, proposing a few lines of `CLAUDE.md` convention against them. Measuring again
before writing anything contradicted it. Across the 50 newest sessions of three unrelated projects
— this repository, a shell project with a test suite, and a 5.1 GB Maven-plus-npm monorepo — one
family dominates everywhere, and the ticket never named it:

| `Bash` family | markdown repo | shell project | compiled monorepo |
|---|---|---|---|
| reading files (`cat`, `head`, `sed -n`, chained `echo … && cat …`) | 51% | 57% | 55% |
| `git diff` / `git show` | 22% | 20% | 4% |
| `git log` | 8% | 3% | 5% |
| tests and builds | 2% | 0% | 15% |

Builds and `git log` together reach 10%, 3% and 19%, against a reading-files share that never
leaves the low fifties. The monorepo is the column that matters here, since it is the one case the
ticket described: it compiles, it carries 57 `node_modules` trees, and its build commands were
already written the way the ticket wanted to teach — `mvn -q`, `npm run lint | tail -40`, `-Dtest=`
scoped to two classes — with the costliest of them still injecting 1 386 tokens. Median `Bash` call
across the three: 106, 64 and 125 tokens, so no diffuse verbosity to discipline either.

`Bash` mostly carries files read through a shell, which puts it on the same ledger as `Read` — and
the tool split itself
never settles, coming out `Bash` 46 / `Read` 45 here, `Read` 53 / `Bash` 42 on the second project,
`Bash` 50 / `Read` 44 on the third. Reprojected onto files, 88% of the volume here fell on twelve
hand-written files reopened across many sessions. Step 5's aggregation produced the tool axis, and
the tool axis produced CC-1. CC-2 carries forward what was real in it. Both proposed shapes went
with it: no `CLAUDE.md` convention, whose resident cost would have repeated `trim-mcp`'s arithmetic
below, and no `PreToolUse` hook guarding a cause nobody had established.

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
nothing left to win. The caveat used to be that this repository is small, mostly markdown and has
no build, and that a monorepo carrying `node_modules` would put `Glob` back near the top. That case
has since been measured: a 5.1 GB Maven-plus-npm monorepo with 57 `node_modules` trees and 77
`dist` directories came out at **0.00%**, across 17 sessions that made zero `Glob` and zero `Grep`
calls between them.

Read that as evidence about behaviour, not about `Glob`'s ceiling. Those sessions reached for
`Bash` and `Read` instead, so the figure says the tool went unused rather than that it would have
been cheap. It stays "not planned" on the same reasoning as before, with one fewer hypothetical
propping it up.
