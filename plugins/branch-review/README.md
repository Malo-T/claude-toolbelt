# branch-review

A Claude Code skill for going back over your own unmerged work: it walks the diffs of a branch in
small batches, pauses on each one with a question per file so you read the code and steer, and can
then file the fixes made along the way into the commits they belong to.

It is meant for the pass you make *before* asking anyone else for a review. For a finished findings
report instead of a paced reading, use a review skill; this one hands you the wheel.

It fires on its own from the description in
[`skills/branch-review/SKILL.md`](skills/branch-review/SKILL.md) — "relis ma branche", "walk me
through my changes", "check my work before I open the PR" — or explicitly as
`/branch-review:branch-review`.

Part of [claude-toolbelt](../../README.md), where install, development and licence live.
