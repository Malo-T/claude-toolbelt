# context-hygiene

A Claude Code skill that configures a project so the default file discovery stays clean: a managed
`.ignore` block for the noise that is committed anyway (lockfiles, generated code, minified assets,
binaries), the one setting that makes `Glob` obey ignore files, and a short read-deny list for
secrets.

The point is the asymmetry it leans on: **an ignore file hides a path from search and from the `@`
picker, but never blocks `Read`.** So the default context is clean and any excluded file is still
one explicit `Read` away. Only secrets go behind `permissions.deny`, which is a hard block.

There is no `.claudeignore` in Claude Code — the skill says so and sets up what actually works. The
levers, and what each one covers, are tabulated in `skills/context-hygiene/SKILL.md`.

## Install

This repository is its own marketplace — it carries a `.claude-plugin/marketplace.json` pointing at
the plugin at the repository root. While it lives only on this machine, add it by path:

```sh
claude plugin marketplace add /home/malo/workspace/claude/context-hygiene
claude plugin install context-hygiene@context-hygiene
```

Once it is pushed to GitHub, the same two commands take the shorthand instead
(`claude plugin marketplace add Malo-T/context-hygiene`). Either way two commands are needed:
`claude plugin install` only resolves names against marketplaces that are already configured.

The skill loads on the next session. It fires from the description in
`skills/context-hygiene/SKILL.md` — "ajoute un .claudeignore", "exclure des fichiers du contexte",
"tu passes ton temps à lire du code généré" — or explicitly as
`/context-hygiene:context-hygiene`.

## Update

```sh
claude plugin marketplace update context-hygiene   # refresh the manifest
claude plugin update context-hygiene               # then the plugin itself
```

## Working on the skill

Installed plugins live in a read-only cache under `~/.claude/plugins/cache/`, so editing there is
pointless. Symlink the working copy into the skills directory instead — any directory in
`~/.claude/skills/` holding a `.claude-plugin/plugin.json` is auto-loaded as `<name>@skills-dir`,
with no install step and no marketplace:

```sh
claude plugin uninstall context-hygiene@context-hygiene
ln -s "$PWD" ~/.claude/skills/context-hygiene
```

`claude plugin list` then shows `context-hygiene@skills-dir`, and a session restart picks up
whatever is on disk. Do not keep both the installed plugin and the symlink: same plugin name, and
the two collide.

Before pushing, validate both — given a directory the command stops at `marketplace.json` and never
opens the plugin manifest, so a broken `plugin.json` passes:

```sh
claude plugin validate . --strict
claude plugin validate .claude-plugin/plugin.json --strict
```

## Evals

`evals/` holds three trigger cases: the `.claudeignore` request (must fire, and must correct the
premise), the symptom described without naming any mechanism (must fire), and a one-off permission
tweak (must stay quiet — that is `update-config`'s job).

```sh
claude plugin eval . --ablation with-without
```

`claude plugin eval` is early access and refuses to run on this account for now, so the cases ship
authored-but-unrun. They are written against the schema the current binary validates
(`schema_version`, `execution`, `graders`), and no case grants Bash, Write or Edit — an eval prompt
is a real instruction executed by a real agent, and it must not be able to touch a repository.

## Layout

```
.claude-plugin/
├── marketplace.json          # this repo as a marketplace, plugin source "./"
└── plugin.json               # the plugin manifest
skills/context-hygiene/
├── SKILL.md                  # the skill itself
└── references/patterns.md    # the pattern catalogue, read on demand
evals/                        # trigger cases
LICENSE                       # MIT
```

## License

MIT — see [LICENSE](LICENSE). Fork it, reword the skill, ship your own; attribution is the only
condition.
