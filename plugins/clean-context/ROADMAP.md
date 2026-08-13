# Roadmap

`clean-context` ships two skills, and the set is closed. Both cover the **repository's own content**
and how much of it Claude reads by default.

| Skill | Source it addresses | Status |
|---|---|---|
| `audit-context` | none — it measures, so the other one has targets | shipped |
| `ignore-setup` | files surfaced by `Glob` / `Grep` / the `@` picker | shipped |

`audit-context` came first, because `ignore-setup` otherwise applies its catalogue blind, and
because a measured before/after is what makes the exclusions safe to accept.

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

Output is a table of levers ranked by estimated gain. The last two rows hand off to `/doctor` rather
than to a skill here: they measure a setup this plugin never touches. Drop them and the report covers
a fraction of the budget while implying the whole.

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

## Abandoned

**`trim-mcp`** — written, never published, then dropped. It inventoried a project's `.mcp.json`
servers, crossed them against `mcp__<server>__*` calls in that project's transcripts, and wrote
`disabledMcpjsonServers` into `.claude/settings.local.json`. Two findings, in the order they landed:

1. **The gain it advertised no longer exists.** MCP tool schemas sit deferred behind `ToolSearch` by
   default: only each tool's *name* stays resident, and Claude Code fetches the schema on demand. A
   server contributing fifty tools costs a few hundred tokens against the tens of thousands the
   premise assumed. Claude Code's own instructions to `/doctor` say it outright — never recommend
   disabling a server to save context when its tools are deferred. One exception: tools carrying
   `anthropic/alwaysLoad` in their `_meta`, which the server decides and the user cannot override.
2. **`/doctor` already writes the same key.** Its check 1 reaches the same verdict from more
   evidence — usage counters plus transcripts across every project rather than one — and applies it
   to the same `disabledMcpjsonServers` in the same `.claude/settings.local.json`.

Then the arithmetic. Its 1016-character description cost roughly 254 resident tokens in every session
of every project, to save on the order of 140 tokens once, in a single project.

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

**`trim-preamble`** — moving long `CLAUDE.md` and `SKILL.md` sections to `references/` and leaving
a pointer. It already had a scope conflict to settle against
`claude-md-management:claude-md-improver`; `/doctor`'s checks 2 through 4 then took the whole idea —
dedup of local memory files against checked-in ones, deleting content a session could derive on its
own, migrating always-loaded guidance to lazy loading — which leaves nothing to carve out.

**Auditing user-scope MCP servers across all projects** — `/doctor`'s check 1 scans transcripts from
every project the user has opened. That was the missing piece, and it shipped before anyone here
specified the skill.

## Considered, not planned

**`refresh-ignore`** — re-applying exclusions after the project changes shape (a new dependency, a
new generated directory). Not a separate skill: `ignore-setup` already detects its own managed block
and rewrites the body, so this is a re-run, and the guardrail that a second run be a no-op already
covers it.

**`read-guard`** — a `PreToolUse` hook warning when a `Read` targets a large generated file. It
completes the plugin's asymmetry (an ignore file hides a path but never blocks `Read`, so the
lecture side has no guardrail at all), and it sits squarely on this plugin's side of the `/doctor`
line — the repository's own files. But a hook is more intrusive than a skill and the false positive
rate is unknown. Revisit if `audit-context` shows the case happens often enough to pay for itself.
