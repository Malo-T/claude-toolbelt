# slack-changelog

A Claude Code skill that turns a release's diff into a Slack changelog a non-technical audience
can actually read. It resolves its own scope, one repo or several released together, separates
what a non-technical reader would notice from what they wouldn't, groups the visible part by
functional theme, drafts one bullet per idea with an emoji picked from a reference table, and
closes on a single question round before handing over the final text.

It exists for the message that goes to the rest of the company after a release: support, sales,
ops, whoever sits in the channel and doesn't read diffs. They get plain text translated from a
technical changelog into their language, with the code vocabulary, the repo names, and the
mechanism stripped out.

It never posts on its own. The deliverable is a ready-to-post message in a code block. Sending it
to Slack is the user's move, integration or not.

It stays read-only on the code and doesn't review for bugs. If nothing has been reviewed yet, it
points at `branch-recap` first instead of covering that ground itself. The two compose naturally,
`branch-recap` before a merge and `slack-changelog` after a release, without either replacing the
other.

It fires on its own from the description in
[`skills/slack-changelog/SKILL.md`](skills/slack-changelog/SKILL.md), on phrases like "écris le
changelog Slack pour cette release" or "draft the Slack update for this release", or explicitly as
`/slack-changelog:slack-changelog`.

A project can override the default template by shipping its own at
`.claude/slack-changelog-template.md`. See
[`skills/slack-changelog/references/template.md`](skills/slack-changelog/references/template.md)
for what it needs to keep.

## Evals

`evals/` holds five trigger cases. Three must fire: explicit invocation, a natural-language
request with no skill vocabulary, and a right-after-release request. Two must stay quiet: a
technical code review request, `branch-recap`'s job, and a release where nothing in scope would
be visible to a non-technical reader.

How to run them, and why they ship unrun: root [README](../../README.md#evals).

Part of [claude-toolbelt](../../README.md), where install, development and licence live.
