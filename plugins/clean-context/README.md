# clean-context

A Claude Code plugin that keeps a project's noise out of Claude's default context. One skill ships
today; [ROADMAP.md](ROADMAP.md) lays out the three that would complete the set.

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
one-off permission tweak (must stay quiet — that is `update-config`'s job).

```sh
claude plugin eval . --ablation with-without
```

`claude plugin eval` is early access and refuses to run on this account for now, so the cases ship
authored-but-unrun. They are written against the schema the current binary validates
(`schema_version`, `execution`, `graders`), and no case grants Bash, Write or Edit — an eval prompt
is a real instruction executed by a real agent, and it must not be able to touch a repository.

Part of [claude-toolbelt](../../README.md), where install, development and licence live.
