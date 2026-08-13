# clean-context

A Claude Code plugin that keeps a project's noise out of Claude's default context. Two skills, both
covering the repository's own content and how much of it Claude reads by default. The Claude Code
setup around it — `CLAUDE.md` bulk, unused skills, plugins and MCP servers — belongs to the built-in
`/doctor`. [ROADMAP.md](ROADMAP.md) records where that line falls, which skills it retired here, and
the four tickets that came out of measuring where the tokens actually go.

## `audit-context`

Measures where a project's context budget is actually going, before any of the other levers touch
it: what `Glob` discovers with and without ignore files applied, the twenty largest files in the
repo and which are generated, the cumulative size of every `CLAUDE.md` loaded for the working
directory, and how many MCP servers and tools are enabled — separating tool schemas that are
actually resident from the ones deferred behind `ToolSearch`, which cost about nothing.

Then it stops estimating and measures. Joining `tool_use` to `tool_result` across the newest 50
transcripts tells you what past sessions really pulled in, per tool, per command and per file. On
this repository that measurement inverted the ranking: `Bash` and `Read` carried 92% of the volume,
`Glob` and `Grep` 0.4%, and the costliest file was a small `SKILL.md` reopened fifteen times. The
report puts that observed cost beside each disk estimate, and where they disagree the observation
wins. Each row points at where its fix lives, here or in `/doctor`.

It is read-only: the point is a measured before/after, not another blind application of a
catalogue. See [`skills/audit-context/SKILL.md`](skills/audit-context/SKILL.md) for the full
measurement steps and the byte-versus-token unit decision.

It fires on its own from that description ("audit mon contexte", "pourquoi mon contexte est
plein", "combien d'outils MCP sont chargés") or explicitly as `/clean-context:audit-context`.

## `ignore-setup`

Configures a project so the default file discovery stays clean: a managed `.ignore` block for the
noise that is committed anyway (lockfiles, generated code, minified assets, binaries), the one
setting that makes `Glob` obey ignore files, and a short read-deny list for secrets.

The point is the asymmetry it leans on: **an ignore file hides a path from search and from the `@`
picker, but never blocks `Read`.** So the default context is clean and any excluded file is still
one explicit `Read` away. Only secrets go behind `permissions.deny`, which is a hard block.

There is no `.claudeignore` in Claude Code — the skill says so and sets up what actually works. The
levers, and what each one covers, are tabulated in
[`skills/ignore-setup/SKILL.md`](skills/ignore-setup/SKILL.md).

It fires on its own from that description — "ajoute un .claudeignore", "exclure des fichiers du
contexte", "tu passes ton temps à lire du code généré" — or explicitly as
`/clean-context:ignore-setup`.

## Evals

`evals/` holds three trigger cases for `ignore-setup`: the `.claudeignore` request (must fire, and
must correct the premise), the symptom described without naming any mechanism (must fire), and a
one-off permission tweak (must stay quiet, that is `update-config`'s job).

It also holds three cases for `audit-context`: a direct ask to measure context bloat (must fire),
a question about MCP tool count with no mechanism named (must fire), and the exact prompt that
already triggers `ignore-setup` (must stay quiet on `audit-context`'s side, since that prompt asks
for a fix, not a measurement).

How to run them, and why they ship unrun: root [README](../../README.md#evals).

Part of [claude-toolbelt](../../README.md), where install, development and licence live.
