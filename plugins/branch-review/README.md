# branch-review

A Claude Code skill for going back over your own unmerged work: it walks the diffs of a branch in
small batches, pauses on each one with a question per file so you read the code and steer, and can
then file the fixes made along the way into the commits they belong to.

It is meant for the pass you make *before* asking anyone else for a review. For a finished findings
report instead of a paced reading, use a review skill; this one hands you the wheel.

## Install

```sh
claude plugin marketplace add Malo-T/claude-toolbelt
claude plugin install branch-review@claude-toolbelt
```

Two commands are needed: `claude plugin install` only resolves names against marketplaces that are
already configured, never a git URL.

The skill loads on the next Claude Code session. It fires on its own from the description in
[`skills/branch-review/SKILL.md`](skills/branch-review/SKILL.md) — "relis ma branche", "walk me
through my changes", "check my work before I open the PR" — or explicitly as
`/branch-review:branch-review`.

## Layout

```
.claude-plugin/plugin.json    # the plugin manifest
skills/branch-review/
└── SKILL.md                  # the skill itself
```

Development, validation and release are the same across the collection — see the root
[README](../../README.md#working-on-a-plugin).

## License

MIT — see the root [LICENSE](../../LICENSE).
