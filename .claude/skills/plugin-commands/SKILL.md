---
name: plugin-commands
description: Commands for validating, testing, iterating on, and releasing plugins in this marketplace (claude-toolbelt) — plugin validate, watcher-parity check, eval, --plugin-dir dev loop, plugin tag. Use when validating a plugin before pushing, running skill evals, developing a plugin without touching the installed cache, or tagging a release.
---

Validate before pushing — the marketplace command does not open plugin manifests, so a broken
`plugin.json` passes it silently:

```sh
claude plugin validate . --strict
for p in plugins/*/; do claude plugin validate "$p/.claude-plugin/plugin.json" --strict; done
```

Check that the two hook plugins' duplicated `watch.sh` haven't diverged (see root CLAUDE.md's
Architecture section):

```sh
./scripts/check-watcher-parity.sh
```

Run a plugin's skill evals (currently authored but unrun — `claude plugin eval` is early access
and refuses to run on this account):

```sh
claude plugin eval plugins/<name> --ablation with-without
```

Iterate on a plugin without touching the installed cache — loads straight from the working copy for
that session, and `/reload-plugins` picks up later edits without restarting:

```sh
claude --plugin-dir "$PWD/plugins/<name>"
```

Tag a release — versions are per plugin, in each `plugins/<name>/.claude-plugin/plugin.json`; the
command checks that manifest and marketplace entry agree and refuses a dirty tree:

```sh
claude plugin tag plugins/<name> --push    # creates <name>--v<version>
```
