# branch-review

A Claude Code skill for going back over your own unmerged work: it walks the diffs of a
branch in small batches, pauses on each one with a question per file so you read the code
and steer, and can then file the fixes made along the way into the commits they belong to.

It is meant for the pass you make *before* asking anyone else for a review. For a finished
findings report instead of a paced reading, use a review skill; this one hands you the wheel.

## Install

This repository is its own marketplace — it carries a `.claude-plugin/marketplace.json`
that points at the plugin sitting at the repository root. No third-party marketplace is
involved, but two commands are still needed: `claude plugin install` only resolves names
against marketplaces that are already configured, never a git URL.

```sh
claude plugin marketplace add Malo-T/branch-review
claude plugin install branch-review@branch-review
```

The skill loads on the next Claude Code session. It fires on its own from the description
in `skills/branch-review/SKILL.md` — "relis ma branche", "walk me through my changes",
"check my work before I open the PR" — or explicitly as `/branch-review:branch-review`.

## Update

```sh
claude plugin marketplace update branch-review   # refresh the manifest
claude plugin update branch-review               # then the plugin itself
```

## Working on the skill

Installed plugins live in a read-only cache under `~/.claude/plugins/cache/`, so editing
there is pointless. Symlink the working copy into the skills directory instead — any
directory in `~/.claude/skills/` holding a `.claude-plugin/plugin.json` is auto-loaded as
`<name>@skills-dir`, with no install step and no marketplace:

```sh
claude plugin uninstall branch-review@branch-review
ln -s "$PWD" ~/.claude/skills/branch-review
```

`claude plugin list` then shows `branch-review@skills-dir` as loaded, and a session restart
picks up whatever is on disk. Do not keep both the installed plugin and the symlink: same
plugin name, and the two will collide.

Before pushing, both — given a directory, the command stops at `marketplace.json` and never
opens the plugin manifest, so a broken `plugin.json` passes:

```sh
claude plugin validate . --strict
claude plugin validate .claude-plugin/plugin.json --strict
```

## Release

Version lives in `.claude-plugin/plugin.json`. Bump it, then:

```sh
claude plugin tag --push          # creates branch-review--v<version>
```

The command checks that `plugin.json` and the enclosing marketplace entry agree before it
tags, and refuses a dirty tree.

## Layout

```
.claude-plugin/
├── marketplace.json          # this repo as a marketplace, plugin source "./"
└── plugin.json               # the plugin manifest
skills/branch-review/
└── SKILL.md                  # the skill itself
LICENSE                       # MIT
```

## License

MIT — see [LICENSE](LICENSE). Fork it, reword the skill, ship your own; attribution is the
only condition.
