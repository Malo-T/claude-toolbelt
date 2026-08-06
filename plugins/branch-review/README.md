# branch-review

A Claude Code skill for going back over your own unmerged work: it walks the diffs of a branch in
small batches, pauses on each one with a question per file so you read the code and steer, and can
then file the fixes made along the way into the commits they belong to.

It is meant for the pass you make *before* asking anyone else for a review — it hands you the
wheel. If what you want is a finished findings report, reach for something else: Claude Code ships
`security-review` for a security-only pass, and Anthropic publishes
`code-review@claude-plugins-official` for pull requests.

It fires on its own from the description in
[`skills/branch-review/SKILL.md`](skills/branch-review/SKILL.md) — "relis ma branche", "walk me
through my changes", "check my work before I open the PR" — or explicitly as
`/branch-review:branch-review`.

## Evals

`evals/` holds six trigger cases. Three that must fire: the branch named without any review
vocabulary, the uncommitted fixes to file into their commits, and a bare `HEAD~4..HEAD` range.
Three that must stay quiet: a single file handed over for a findings report, a security audit of
the same branch (`security-review`'s job), and an order to squash the last four commits — same
vocabulary, but a thing to do rather than a reading to guide.

None of the six reuses a phrase the skill's `description` already quotes. A case built on one of
those measures a string match, not a decision.

How to run them, and why they ship unrun: root [README](../../README.md#evals).

Part of [claude-toolbelt](../../README.md), where install, development and licence live.
