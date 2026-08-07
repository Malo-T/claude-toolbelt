# branch-recap

A Claude Code skill for finding out what is actually on your unmerged branch before you push it.
It reads every diff, then hands back an account rather than the code: group by group, what was
done, why, how, and what deserves a second look — with the hunks quoted only where a remark needs
them. It closes on a single question set, and can file the fixes you decided into the commits they
belong to.

It exists for the branch you produced fast, assistant at the keyboard: the result works and you
have no real idea what changed. Reading the whole diff back in a terminal is how that goes
unchecked — a few screens of prose you can hold in your head is how it doesn't. Any diff you do
want to see is one keystroke away in the closing question set.

It is meant for the pass you make *before* asking anyone else for a review — it hands you the
wheel. If what you want is a finished findings report, reach for something else: Claude Code ships
`security-review` for a security-only pass, and Anthropic publishes
`code-review@claude-plugins-official` for pull requests.

It fires on its own from the description in
[`skills/branch-recap/SKILL.md`](skills/branch-recap/SKILL.md) — "relis ma branche", "walk me
through my changes", "check my work before I open the PR" — or explicitly as
`/branch-recap:branch-recap`.

## Evals

`evals/` holds seven trigger cases. Four that must fire: the branch named without any recap
vocabulary, the uncommitted fixes to file into their commits, a bare `HEAD~4..HEAD` range, and the
module built in an afternoon that its author can no longer account for. Three that must stay
quiet: a single file handed over for a findings report, a security audit of the same branch
(`security-review`'s job), and an order to squash the last four commits — same vocabulary, but a
thing to do rather than a branch to account for.

None of the seven reuses a phrase the skill's `description` already quotes. A case built on one of
those measures a string match, not a decision.

How to run them, and why they ship unrun: root [README](../../README.md#evals).

Part of [claude-toolbelt](../../README.md), where install, development and licence live.
