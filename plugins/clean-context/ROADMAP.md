# Roadmap

`clean-context` ships one skill. The plan is a diagnostic plus three levers, one per source of
context bloat — files, tool schemas, and whatever is loaded on every session regardless.

| Skill | Source it addresses | Status |
|---|---|---|
| `audit-context` | none — it measures, so the others have targets | planned, build first |
| `ignore-setup` | files surfaced by `Glob` / `Grep` / the `@` picker | shipped |
| `trim-mcp` | MCP tool schemas injected into every request | planned |
| `trim-preamble` | `CLAUDE.md` and `SKILL.md` bodies read at session start | planned, scope conflict to settle |

The order matters: `audit-context` first, because the three levers currently apply their catalogue
blind, and because a measured before/after is what makes the exclusions safe to accept.

## `audit-context` — measure before regulating

The diagnostic counterpart to the rest. On a given project, report:

- what `Glob **/*` actually returns, with and without the ignore files applied
- the twenty largest files in the repository, and which of them are generated
- the cumulative size of every `CLAUDE.md` loaded automatically for this working directory,
  walking the nesting upward
- how many MCP servers are enabled here and how many tools they contribute

Output is a table of levers ranked by estimated gain, each pointing at the skill that applies it.
It writes nothing — the only skill in the set that does not, a distinction the names no longer
carry, so the report has to make it itself.

Open question: how to obtain the token cost rather than the byte count. Bytes are a proxy that
misleads on minified assets and on CJK, but there may be no cheap tokenizer at hand — decide
before writing the report format, since the whole ranking depends on the unit.

## `trim-mcp` — the current blind spot

MCP tool schemas are sent with every request, and a single server can contribute fifty tools. The
skill inventories what is enabled for the project, crosses it with what has actually been called in
the session transcripts, and writes `enabledMcpjsonServers` / `disabledMcpjsonServers` accordingly.

Same philosophy as `ignore-setup`: reduce the default, do not remove the capability. A disabled
server is one settings line away from coming back, and the skill must say so in its report.

Prerequisite: confirm where transcripts live and how to read past tool calls from them without
loading a whole session into context. If that turns out to be impractical, the skill falls back to
asking which servers the project actually needs — weaker, but still worth shipping.

## `trim-preamble` — keep the session preamble short

Applies the same idea to prose: what is read at every session start stays short, the rest moves to
`references/` and is read on demand. The skill spots long sections in `CLAUDE.md` and `SKILL.md`
files, proposes the split, and leaves the pointer behind.

**Settle before writing a line of it:** this overlaps `claude-md-management:claude-md-improver`.
That plugin judges the *quality* of the content; this one would judge only its *cost* and its
placement. The distinction is defensible on paper and invisible in a `description` — two skills
competing for the same trigger is worse than not shipping the second. Either carve the description
down to the size-and-placement case only, or drop the skill and contribute the idea upstream.

## Considered, not planned

**`refresh-ignore`** — re-applying exclusions after the project changes shape (a new dependency, a
new generated directory). Not a separate skill: `ignore-setup` already detects its own managed block
and rewrites the body, so this is a re-run, and the guardrail that a second run be a no-op already
covers it.

**`read-guard`** — a `PreToolUse` hook warning when a `Read` targets a large generated file. It
completes the plugin's asymmetry (an ignore file hides a path but never blocks `Read`, so the
lecture side has no guardrail at all), but a hook is more intrusive than a skill and the false
positive rate is unknown. Revisit if `audit-context` shows the case happens often enough to pay for
itself.
