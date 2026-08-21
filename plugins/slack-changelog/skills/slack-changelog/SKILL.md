---
name: slack-changelog
description: >-
  Turns what changed in a release into a Slack changelog a non-technical audience can read:
  filtered to what they would actually notice, one bullet per idea, plain language, no code
  vocabulary. Works out the scope itself across however many repositories sit in the working
  directory (a project can span several independent repos released together), separates what is
  visible to someone outside engineering from what isn't, groups the visible part by functional
  theme rather than by repo, picks an emoji per idea from a reference table, and closes on a
  single question round to adjust theme, bullets, closing line or target channel before handing
  over the final text. It never posts on its own. Use it when someone wants to announce a
  release to people outside engineering: "écris le changelog Slack pour cette release", "prépare
  le message pour annoncer les dernières nouveautés", "on doit poster ce qui a changé pour les
  équipes business", "draft the Slack update for this release", "what should we tell the rest of
  the company changed", "résume la release pour le canal général" — including right after a
  release, or when the user only names a tag, a range, or "cette version". Read-only on the code:
  it does not review for bugs, and if nothing has been reviewed yet it points at `branch-recap`
  first instead of covering that ground itself. Skip when someone wants a technical/internal
  changelog, a commit message, or a PR/MR description: those keep the mechanism, this drops it.
  Skip too when nothing in scope would be visible to a non-technical reader. Say so and stop
  instead of forcing a post.
---

# Slack Changelog

Turn a release into a message the rest of the company can read, not a changelog for engineers.
The audience is anyone who doesn't read diffs: support, sales, ops, whoever sits in the channel.
They need to know what changed for them, in plain language. Not how it was built.

The deliverable is a ready-to-post Slack message: a fixed template, a handful of bullets, one
emoji each, an optional closing line, always the channel-wide mention. Not the commit log with
nicer punctuation. A translation of it, filtered down to what someone outside engineering would
actually notice.

Two failure modes to avoid. A technical changelog with emoji stapled on: a bullet that names a
class, a status code, or a function has failed, however it's formatted. And a post sent without
asking: the draft stays a draft until the user has seen it and said so.

## Invocation

```
/slack-changelog [optional scope]
```

Examples:
- `/slack-changelog`
- `/slack-changelog v2.4.0..HEAD`
- "écris le changelog Slack pour cette release"
- "prépare le message pour annoncer les dernières nouveautés côté connexion"
- "draft the Slack update for what shipped this week"

## Step 1 — Resolve the scope

Know exactly which changes you're translating before you start drafting.

**If the working directory holds a single repository**, resolve the range the way `branch-recap`
does: an explicit range the user named, otherwise the latest tag through `HEAD` (the usual
release cut point), falling back to the merge-base against the closest integration branch
(`origin/HEAD`, `origin/main`, `origin/develop`, …) when the repo carries no tags.

**If the working directory holds several independent repositories** (a directory grouping
multiple git repos, each releasing on its own), resolve the same range logic inside each one and
read every repo's diff. Treat them as one release: assume they ship together and carry a shared
level of coupling, not that only one of them matters. Don't ask which repo to use. Gather all of
them, and say which repos you found before reading further.

```bash
git tag --sort=-creatordate | head -1        # per repo: latest tag, if any
git log --oneline <range>                    # per repo
git diff --stat --find-renames <range>       # per repo
```

**Announce the scope before drafting**, one short block, one line per repo:

```
api      : v2.4.0..HEAD · 9 commits
dashboard: v1.12.0..HEAD · 4 commits
plugin   : rien de nouveau depuis v0.9.1
```

If a project ships a template override at `.claude/slack-changelog-template.md`, use it in place
of `references/template.md` for Step 7 and say that you did.

## Step 2 — Filter what a non-technical reader would notice

Classify every change visible or invisible before you think about theme or wording. Invisible
doesn't mean unimportant. It means nobody outside engineering would perceive it:

- **Invisible** — migrations, refactors, internal renames, CI/build changes, added tests,
  internal-only APIs, dependency bumps, logging, anything reverted before it reached a user.
- **Visible** — anything that changes what a non-technical user sees, what they can now do, what
  broke and got fixed for them, or something they now need to do differently.

Judge each change on the actual diff, not on a fixed mapping. A commit labeled "refactor" can
still hide a visible behaviour change, and a large diff can turn out entirely invisible. Read
enough of each change to judge it yourself, not just its commit subject.

**If everything in scope is invisible, stop here.** Say so plainly, "rien de visible pour un
public non technique dans cette plage", and don't force a post out of an empty result.

## Step 3 — Determine the theme(s)

A theme is a functional area: "les réponses candidats", "la connexion", "l'export des rapports".
Never a repo name, never a technical subsystem. One post covers one theme by default, even when
the changes behind it span several repos.

Multiple themes in scope: combine them in one title as long as it stays readable ("nouveautés
côté connexion et notifications"). Split into separate posts only when the mix would make a
single title unreadable, or the bullets would stop reading as one coherent update.

## Step 4 — Translate each change into a bullet

One bullet, one idea, the perceived effect, never the mechanism. No class name, no status code,
no function or file name, no library. Use `→` only for a cause/effect relationship the reader
would perceive themselves ("les filtres de recherche → les résultats se mettent à jour sans
recharger la page"), never to narrate an implementation detail.

Merge changes that land the same idea instead of multiplying near-duplicate bullets: three
commits fixing the same visible glitch in three places make one bullet, not three.

## Step 5 — Choose an emoji shortcode per bullet

Pick one shortcode per bullet from `references/emoji-table.md`, matched to what the bullet is
about: new capability, fix, performance, security, interface, action required, data or
traceability, cleanup, communication, credit. Never reuse the same emoji for two bullets that
mean different things in the same post, and never add one purely for decoration. Every emoji
should tell the reader something about the bullet before they've read it.

## Step 6 — Decide the closing action line

Ask whether anything in this release requires the reader to do something: reinstall, refresh,
re-authenticate, change a setting, wait for a rollout. Or does it just happen to them, with
nothing required on their end?

- If something is required, write one short, concrete sentence saying what to do and when.
- If nothing is required, omit the closing line entirely instead of inventing one.
- If it's genuinely unclear whether an action is required (a manually-distributed artefact
  against an auto-deployed one, for instance), ask rather than guess. It's the one line in the
  message where a wrong guess costs someone real time.

## Step 7 — Assemble the draft

Use `references/template.md`, or the project's own override from Step 1, as the fixed gabarit.
Emoji shortcodes stay as plain text (`:sparkles:`, not the rendered character): Slack renders
them, and plain text is what a reviewer can diff. Present the whole thing inside a single
copyable code block.

The channel-wide mention at the end is part of the template. Keep whichever convention the
project's template encodes (`@channel`, `@here`, a named group). If no override exists and the
workspace convention isn't obvious, ask in the closing question round instead of picking one
silently.

## Step 7b — Run stop-slop on the draft

The draft is prose for a human reader outside engineering, exactly the audience `stop-slop`
exists for. Run it on the bullets and the closing line before presenting the draft, so the AI
tells don't reach the one reader this skill actually writes for.

## Step 8 — One question round, then stop

Present the full draft first, in the language the user is speaking. Then ask a single
`AskUserQuestion` covering whatever is left to settle: theme wording, a bullet to cut or reword,
the closing line, the target channel. The same discipline `branch-recap` closes its own account
with: one round, not a question after every decision.

**Nothing to adjust is a valid outcome.** If the draft looks settled, say so and hand it over
instead of manufacturing a question just to have one.

## Step 9 — Never post silently

This skill's output is text, not an action. Hand over the final message and stop. It doesn't
send anything to Slack itself, integration or not. If the user pastes it into a channel, that's
their move to make, not a step this skill takes for them.

## Boundary with branch-recap

This skill is read-only on the code and doesn't review for bugs. It trusts that what's in scope
has already been through whatever review it needed. If nothing has been reviewed yet, say so and
point at `branch-recap` first instead of covering that ground here. The two compose naturally,
`branch-recap` before a merge and `slack-changelog` after a release, but neither replaces the
other.

## Rules

- Never invent a change that isn't in the diff, and never soften "rien de visible" into a post
  anyway: an empty result is a valid, sayable outcome.
- No code vocabulary in a bullet: no class, function, file, status code, or library name.
- One question round for the whole draft, the same discipline as `branch-recap`.
- Gather multi-repo scope; never ask about it. Read every repo found and say which ones.
- Answer in the language the user is speaking; the template's wording follows suit.
- Run `stop-slop` on the draft's bullets and closing line before presenting it. This output goes
  to human readers outside engineering, not into a repository, so it's squarely in scope.
