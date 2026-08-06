# claude-toolbelt

Claude Code plugins, each taking on a point of friction in the day-to-day loop: knowing where the
session stands without watching it, keeping the noise out of what Claude reads, going back over
your own work before anyone else does. What they have in common is the intent, not a domain — they
are the things that were missing often enough to be worth writing.

One marketplace publishes them all, so adding a plugin is one command rather than one more
marketplace. Each stays independent: install the one you want, ignore the rest.

| Plugin | What it does |
|---|---|
| [`branch-review`](plugins/branch-review) | Tells you what your unmerged branch actually changed — what was done, why, and what deserves a second look, instead of the diff — then closes on one question set and files the fixes into the commits they belong to. |
| [`clean-context`](plugins/clean-context) | Keeps a project's noise — lockfiles, generated code, binaries — out of Claude's default file discovery, while leaving every excluded path one explicit `Read` away. |
| [`status-icons`](plugins/status-icons) | Marks the terminal tab with an icon that tells "it is done" apart from "it is blocked on you", where Claude Code shows the same `✳` for both. |
| [`status-sounds`](plugins/status-sounds) | Plays a short sound when Claude has finished, has failed, or wants something from you. |

The two `status-*` plugins are siblings — same idea on two channels — and are deliberately separate:
icons cost nothing and suit anywhere, sound is intrusive in an open-plan office.

## Install

```sh
claude plugin marketplace add Malo-T/claude-toolbelt
claude plugin install branch-review@claude-toolbelt
```

Two commands are needed: `claude plugin install` only resolves names against marketplaces that are
already configured, never a git URL. Once the marketplace is added, install as many as you want:
any plugin from the table above, suffixed with `@claude-toolbelt`.

`marketplace add` also takes a local path, which is how to install a clone without going through
GitHub.

## Update

```sh
claude plugin marketplace update claude-toolbelt        # refresh the manifest
claude plugin update branch-review@claude-toolbelt      # then each plugin you installed
```

The plugin name has to be qualified with the marketplace — `claude plugin update branch-review`
alone reports the plugin as not found.

## Working on a plugin

Installed plugins live in a read-only cache under `~/.claude/plugins/cache/`, so editing there is
pointless — and because the marketplace is fetched from GitHub, an edit to this clone has no effect
on the installed copy until it is pushed.

`--plugin-dir` is the way round it. It loads a plugin from the working copy for that session only,
and takes precedence over the installed plugin of the same name:

```sh
claude --plugin-dir "$PWD/plugins/branch-review"
```

The flag is repeatable, and it has to come before any subcommand — `claude plugin list
--plugin-dir …` is rejected outright, while `claude --plugin-dir … plugin list` is accepted. It
writes nothing: the cache, `installed_plugins.json` and `known_marketplaces.json` are all left
alone, and the installed copy is back the moment the flag is dropped. So there is no need to
uninstall anything first, and nothing to undo afterwards.

`/reload-plugins` picks up later edits without restarting the session. That covers hooks too:
`${CLAUDE_PLUGIN_ROOT}` resolves to the working copy, so `plugins/status-*/hooks/*.sh` are live as
well.

Note the override replaces the whole plugin rather than merging with it — a skill the installed copy
provides and the working copy has dropped is simply absent for that session.

Typing four flags gets old, so key them on the directory instead (zsh):

```zsh
claude() {
	local root=$HOME/workspace/claude/claude-toolbelt
	if [[ $PWD/ == $root/* ]]; then
		setopt localoptions null_glob
		local -a flags
		local manifest
		for manifest in $root/plugins/*/.claude-plugin/plugin.json; do
			flags+=(--plugin-dir "${manifest:h:h}")
		done
		command claude "${flags[@]}" "$@"
	else
		command claude "$@"
	fi
}
```

Globbing the manifest rather than the directory means a new plugin is picked up without touching the
function, and a directory without a manifest is skipped instead of failing the launch. `null_glob` as
a scoped option, rather than an `(N)` qualifier, is what makes that skip hold everywhere: a shell
started with `bare_glob_qual` off — Claude Code's own hook and Bash-tool shells, among others — reads
`(N)` as a literal and aborts the glob, so a nested `claude` would fail outright. Outside the
repository the command is untouched, so the published versions stay in use everywhere else — and
remain the fallback when the working copy is mid-edit.

Two alternatives, both weaker. Pointing the marketplace at the working copy still installs a *copy*
into the cache, so an edit only lands after an explicit `claude plugin update` — useful for
rehearsing a release, not for iterating:

```sh
claude plugin marketplace add ~/workspace/claude/claude-toolbelt
```

Or, for a skill-only plugin, symlink it into the skills directory — any directory in
`~/.claude/skills/` holding a `.claude-plugin/plugin.json` is auto-loaded as `<name>@skills-dir`,
with no install step and no marketplace:

```sh
claude plugin uninstall branch-review@claude-toolbelt
ln -s "$PWD/plugins/branch-review" ~/.claude/skills/branch-review
```

Unlike `--plugin-dir`, this one does collide: uninstall the plugin first, or the same name is
claimed twice.

Before pushing, validate the marketplace and each plugin manifest. Both are needed — given a
directory, the command stops at `marketplace.json` and never opens the plugin manifests, so a broken
`plugin.json` passes:

```sh
claude plugin validate . --strict
for p in plugins/*/; do claude plugin validate "$p/.claude-plugin/plugin.json" --strict; done
```

The two `status-*` plugins each ship their own copy of `hooks/watch.sh`, byte for byte the same
program under two names. That is deliberate — they install independently and must share nothing — but
it means a fix written in one copy and forgotten in the other passes every other check silently. One
script says so:

```sh
./scripts/check-watcher-parity.sh
```

It drops the full-line comments, whose prose is meant to differ, normalises the plugin name, the
environment prefix and the script each watcher calls, and then demands strict equality.

## Evals

The skill plugins carry trigger cases under `plugins/<name>/evals/`, one directory per case. The
hook plugins carry none, and should not: a hook fires on an event, so there is no model decision to
measure. `--ablation` is what makes a case worth writing — it replays the same prompts without the
plugin, so a pass says the skill changed the outcome rather than that the base model already knew.

```sh
for e in plugins/*/evals; do claude plugin eval "${e%/evals}" --ablation with-without; done
```

`claude plugin eval` is early access and refuses to run on this account — still true on 2.1.223 —
so the cases ship authored-but-unrun. They are written against the schema the current binary
validates: `schema_version`, `execution`, `graders`.

No case grants Bash, Write or Edit. An eval prompt is a real instruction executed by a real agent,
and a trigger set is mostly near-misses that borrow the skill's vocabulary — `branch-review`'s
includes "squash les 4 derniers commits", which a run with tools open would carry out on whatever
repository it found.

## Release

Versions are per plugin, in each `plugins/<name>/.claude-plugin/plugin.json`. Bump the one you are
releasing, then tag that plugin by path:

```sh
claude plugin tag plugins/branch-review --push    # creates branch-review--v<version>
```

The command checks that `plugin.json` and the marketplace entry agree before it tags, and refuses a
dirty tree.

## Layout

```
.claude-plugin/marketplace.json    # the one marketplace, one entry per plugin
plugins/
├── branch-review/                 # skill
├── clean-context/                 # skill + references + evals
├── status-icons/                  # hooks
└── status-sounds/                 # hooks
scripts/                           # pre-push checks that no CLI covers
LICENSE                            # MIT, covers every plugin
```

## License

MIT — see [LICENSE](LICENSE). Fork it, reword the skills, ship your own; attribution is the only
condition.
