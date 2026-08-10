# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A Claude Code plugin marketplace. `.claude-plugin/marketplace.json` is the single marketplace,
listing every plugin under `plugins/`; there is no separate marketplace per plugin and none should
be added. Each plugin is independent — installable and usable on its own — but they all publish
from this one repository.

Two plugin shapes exist here:
- **Skill plugins** (`branch-recap`, `clean-context`): a `skills/<name>/SKILL.md` plus optional
  `evals/`. No hooks.
- **Hook plugins** (`status-icons`, `status-sounds`): a `hooks/hooks.json` wiring lifecycle events
  to scripts, no skill.

## Commands

Validate before pushing — the marketplace command does not open plugin manifests, so a broken
`plugin.json` passes it silently:

```sh
claude plugin validate . --strict
for p in plugins/*/; do claude plugin validate "$p/.claude-plugin/plugin.json" --strict; done
```

Check that the two hook plugins' duplicated `watch.sh` haven't diverged (see below):

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

## Architecture

**The status-icons/status-sounds duplication is deliberate, not an oversight.** Both plugins ship
their own byte-for-byte copy of `hooks/watch.sh` (a background poller keyed off
`<config>/sessions/<pid>.json`) because the two plugins install independently and must share
nothing — no common dependency, no shared package. The cost is that every fix to the watcher has to
be applied twice, which is exactly what `scripts/check-watcher-parity.sh` guards against: it strips
comments (prose is allowed to differ), normalises each plugin's name/env-prefix/callee script, and
diffs the result. When editing either `watch.sh`, port the change to the other copy or teach the
normalisation about a genuine per-plugin difference — do not let the check go red.

**Why `watch.sh` exists at all**: Claude Code's own `Notification` hook fires ~6 seconds after a
session actually starts waiting (a hardcoded delay in the binary), but the session state file
flips to `"status":"waiting"` immediately. `watch.sh` is a detached poller (started by
`SessionStart`, killed by `SessionEnd`) that watches that file directly and fires the real hook
(`tab-title.sh` or `play.sh`) at the moment the state changes, four times a second, well ahead of
the built-in notification. The built-in `Notification` hook stays wired up as a fallback for when
the watcher never started or has died; a `.waiting` marker file plus a pidfile is how the callee
(`tab-title.sh`/`play.sh`) tells "the watcher already handled this episode" apart from "the watcher
is absent, act on the late event yourself" — see the comments at the top of each `watch.sh` for the
exact handshake.

**Evals** (`plugins/<name>/evals/<case>/case.yaml`) test whether a skill's `description` fires on
the right prompts and stays quiet on near-misses — not what the skill does once triggered. Hook
plugins carry no evals: a hook fires on an event, there is no model decision to measure. Cases grant
no `Bash`/`Write`/`Edit` — a case's prompt is a real instruction a real agent executes, and several
are deliberately near-miss phrasings (e.g. "squash les 4 derniers commits") that would act on
whatever repository ran them if tools were open.

**Configuration is environment-variable based, not settings-file based.** Both `status-icons` and
`status-sounds` read their tunables (poll interval, alert delay, per-state sound overrides) from
`STATUS_ICONS_*` / `STATUS_SOUNDS_*` env vars, meant to be set once under `env` in `settings.json`
rather than edited into the plugin. `status-sounds` distinguishes an unset variable from one
explicitly set empty (`${VAR+x}` vs `${VAR:-}`) so "use the default sound" and "play nothing for
this state" are both expressible.

## Conventions

- Commit messages follow strict Conventional Commits (`type(scope): lowercase description`, no
  attribution trailer, body of three lines at most) — see git log for the pattern in practice.
- Shell scripts under `hooks/` target bash 3.2 (macOS's shipped version) where noted in their own
  comments: no associative arrays, no case-conversion expansions, fractional `read -t` guarded
  behind a bash-4 check.
- `.claude/settings.local.json` is gitignored; it is local session config, not part of any plugin.
