---
name: branch-review
description: Guided, file-by-file walkthrough of the changes on a git branch: works out the scope itself, walks the diffs in small batches, and pauses on each batch with one question per file so the user reads the code and steers. Can then file the fixes made along the way into the commits they belong to, via fixup and autosquash. Use it whenever someone wants to go back over their own unmerged work — "relis ma branche", "on repasse sur mes commits", "vérifier ce que j'ai fait hier soir", "qu'est-ce que j'ai changé au juste sur cette branche", "repasser sur ce que j'ai fait avant de demander une revue", "check my work before I open the MR/PR", "walk me through my changes" — including when they only name a commit range, a path, or a branch, and including when they have uncommitted fixes to read through and then tidy into the right commits. Reach for it rather than answering with a bare git diff or a summary: what is wanted is a paced reading they drive. Skip when they hand over a single file or snippet and want an automated findings report (use `review`), or want a security-only audit (use `security-review`).
---

# Branch Review

Walk the user through the changes on a git branch, in small batches, so **they** read the
code. This skill is a reading guide, not an auditor: you resolve the scope, put the files in
an order that makes the change comprehensible, add just enough context per file, and then
hand back control — every batch ends on decisions to tick, not on a wall of prose.

The failure mode to avoid is dumping a full report. If the user wanted a verdict they would
have asked for one — they asked to re-read their own work, and the value you add is
sequencing, context, and a second pair of eyes on each chunk.

## Invocation

```
/branch-review [optional restriction]
```

Examples:
- `/branch-review`
- `/branch-review les 2 derniers commits`
- `/branch-review seulement le back`
- "je voudrais repasser sur ce que j'ai fait avant d'ouvrir la MR"

## Step 1 — Resolve the scope

Never start reading before you know exactly what you are reading and the user has seen it.

**Find the base branch:**

```bash
git symbolic-ref --short refs/remotes/origin/HEAD   # e.g. origin/main
```

If that fails (no remote HEAD set), fall back to whichever of `main`, `master`, `develop`
exists — check with `git rev-parse --verify`. If several exist and it's genuinely ambiguous,
ask rather than guess.

**Take the inventory** (run these together):

```bash
git log --oneline <base>..HEAD
git diff --stat --find-renames <base>...HEAD
git status --short
```

Use **three dots** (`<base>...HEAD`) for the diff. Two dots would also show commits that
landed on the base branch since the user branched off — noise that isn't their work. Three
dots diffs against the merge-base, which is exactly "what this branch adds".

**Honour explicit restrictions** the user gave:

| The user says | Scope |
|---|---|
| nothing | `<base>...HEAD` |
| "les 2 derniers commits" | `HEAD~2..HEAD` |
| "ce commit" / a SHA | `<sha>^!` |
| "seulement le back" / a path | append `-- back/` to the diff commands |
| "ce que je n'ai pas encore commité" | `git diff` and `git diff --staged` |

**If the working tree is dirty**, show what's uncommitted and ask — with an
`AskUserQuestion`, so it's one keystroke — whether to include it: everything, the commits
only, or the uncommitted changes only. Reviewing a branch while half the work sits unstaged
wastes the whole pass, and picking silently for the user is worse.

**Then fix the diff spec once and reuse it everywhere.** This is the step that decides
whether the review actually shows what the user agreed to look at. Three-dot syntax always
compares two *commits*, so it silently drops the working tree — ask someone whether to
include their uncommitted work, then diff with `...`, and you have thrown their answer away
without a word.

| Scope chosen | Spec to reuse |
|---|---|
| commits only | `<base>...HEAD` |
| commits + working tree | `$(git merge-base HEAD <base>)` — a bare commit, so the diff runs against the working tree |
| uncommitted only | no rev at all: `git diff` and `git diff --staged` |
| an explicit commit range | `HEAD~2..HEAD`, `<sha>^!` |

Untracked files appear in no diff whatsoever. List them from `git status --short` and read
them whole — otherwise a brand-new file is the one thing the review never mentions.

**Announce the scope, then start.** One short block, no ceremony:

```
Base : main (merge-base a1b2c3d) · 5 commits · 12 fichiers · +430 −87
2 fichiers non commités ignorés.
```

## Step 2 — Order the reading

Alphabetical order is the enemy of comprehension. Sequence the files so each one is
understandable by the time the user reaches it:

1. What defines the change — migrations, schemas, models, API contracts, types
2. The business logic that implements it
3. The callers and the wiring — controllers, routes, UI, DI config
4. The tests
5. Config, docs, CI

When the branch carries several unrelated changes, group by feature first and apply the
order inside each group. Say which grouping you used.

Collapse the noise: lockfiles, generated code, snapshots, vendored assets and binaries get
one summary line each in the plan and are never expanded as a step.

Show the numbered reading plan once, then begin.

## Step 3 — Present a batch of files

Files go out in batches of one to four, then a single question set covers the whole batch —
the user navigates between questions with the arrow keys and submits everything at once. Four
is the hard cap (one `AskUserQuestion` carries at most four questions), but it's a ceiling,
not a target.

**A batch is one idea, not four slots to fill.** Build it from the files that have to be
understood together — the migration and the model it reshapes, the endpoint and its test, the
five skills that all gained the same frontmatter. The user should be able to name what the
batch was about after reading it. If the honest answer is "these four files happened to be
next in the list", the batch is wrong: drop it to the two that belong together and let the
others form their own.

That cohesion outranks filling the cap. Then size against reading cost:

- Four near-identical five-line changes belong in one batch — reading them separately is
  four interruptions for one idea.
- A three-hundred-line rewrite is its own batch. Two of those in one message and the second
  one gets skimmed.
- Never straddle two groups of the reading plan. Putting "database schema" and "CI config"
  in the same breath spends the context switch Step 2 was built to avoid.

Name the batch when you open it — "Lot 2 — le chemin d'authentification (3 fichiers)". If
naming it takes a conjunction, it's two batches.

Get the diff for each file, with enough context to be readable, using the spec settled in
Step 1:

```bash
git diff --find-renames -U10 <spec> -- <path>
```

Three shapes don't fit "show the diff and comment":

- **A deleted file** — don't pour the removed lines back onto the screen; the user deleted
  them on purpose. Say what it was, why it's gone, and what now covers it. Show a few lines
  only when the deletion itself is the debatable part.
- **A new file the user wrote in this conversation** — reprinting it wastes the step. Give
  its structure in two lines and go straight to the points of attention.
- **A new file from elsewhere** — no diff exists to read; read the file and present it in
  hunks like any large change.

**Read the whole current file before writing your comments** (not just the diff). A diff
lies by omission: it hides the guard clause twenty lines up, the existing helper that
already does this, the caller that assumes the old shape. A point of attention invented
from unread context costs the user more time than it saves.

Then present the step in this shape:

```
### 3/12 — src/services/payment.ts   (+64 −12)

<the diff>

**Ce que ça change** — 1 à 3 phrases : l'intention derrière le changement, pas la
paraphrase du diff. L'utilisateur voit déjà les lignes.

**À vérifier**
- `payment.ts:88` — le retry ne distingue pas un 4xx d'un 5xx, une carte refusée sera
  rejouée 3 fois
```

Keep **À vérifier** to three items at most, and **zero is a valid answer** — write
"Rien à signaler." and move on. Flagging something on every single file trains the user to
skim past the section; restraint is what makes the real findings land. Anchor every item to
`file:line` so it can be jumped to.

Good points of attention are things the user cannot see from the diff alone: a case the new
branch doesn't handle, an inconsistency with how the rest of the codebase does it, a caller
that wasn't updated, an assumption the tests don't cover. Not style, not naming, not "you
could extract this" — unless the user asks for that kind of pass.

For a file with a large diff, split by hunk and use a sub-counter (`3/12 — hunk 2/4`),
keeping each chunk to something readable in one screen. A file that needs splitting takes a
batch to itself, and still gets **one** question covering the whole file — the hunks are a
reading aid, not four separate decisions, and asking four times about one file is the
interruption the batching was meant to remove.

**Then stop.** One batch per message, never two in a row. The pause is the point of the
skill — the user is reading.

## Step 4 — Close the batch with one question set

Close each batch with a single `AskUserQuestion` carrying **one question per file**. The user
walks the questions with the arrow keys, ticks what they want on each, and submits once. That
shape is what makes the review feel like a form to fill rather than a corridor of prompts.

The options are where you propose what to *do* about what was just read. A step that ends in
a bare question mark puts the burden back on the user to formulate; one that ends in "Corrige
: le retry rejoue les 4xx" hands them a decision.

**Submitting is what advances. Never add a "Suivant" option.** A checkbox meaning "do
nothing" duplicates the submit button and steals one of four slots that a real proposal could
have used. Nothing ticked simply means nothing to do on that file — carry on to the next
batch without ceremony.

This assumes the interface accepts a question with no box ticked. If it turns out to refuse
one, the fix is a neutral navigation option ("Voir le plan", "Revenir sur X") that gives the
user something true to tick — not a "Suivant" wearing a different label, which puts the
useless checkbox straight back.

Per question:

- `multiSelect: true` — always. Options are actions and actions compose: "corrige ce point et
  réponds à ma question" is one ordinary intent that single-select splits into two
  round-trips.
- `header`: the counter — `Fichier 3/9`, or `3/9 · h2/4` when splitting hunks (12 chars max)
- `question`: name the file, ask what to do with it
- 2 to 4 options, drawn from what you actually found, in this order:
  1. **One per point flagged**, phrased as the concrete action rather than the observation:
     "Corrige : limiter le retry aux 5xx".
  2. **Noter au récap sans corriger** — a real third path between fixing now and dropping it,
     and the one that usually fits a finding the user needs to think about.
  3. **A design question you'd genuinely like answered** — "Le chemin en dur est voulu ?" A
     guided review is also your chance to understand intent you can't read off the diff.
  4. **Navigation** — "Revenir sur `settings.json`", "Sauter au 7", "Terminer maintenant".

**A file with nothing to decide gets no question.** Say "Rien à signaler" in the presentation
and leave it out of the question set — that's the whole point of dropping the no-op option.
When an entire batch is clean, ask one navigation-only question for the batch so the pause
still happens and the user keeps the wheel.

**Never write a combination option.** "Les deux corrections", "tout appliquer" — these only
exist to work around single-select, and each burns a slot. With `multiSelect` the user
assembles the combination themselves. List each action once, atomically.

The rare exception is options that genuinely exclude each other — "cadrer sur le dev" versus
"cadrer sur le prod" is one decision with two answers, not two actions. Say so in the
descriptions so the exclusivity is visible, and if both come back ticked, ask which one
rather than picking.

Two well-aimed options beat four padded ones. The free-text entry is always there, so don't
try to enumerate every possibility.

When a choice merges or skips steps, the announced total stops being true. Say the new one
out loud once — "on passe de 9 à 7 étapes" — and renumber from there. A counter whose
denominator changes without warning is worse than no counter at all.

**Processing the submission.** Everything comes back at once, across several files. Run it in
the order that keeps the answers useful:

1. **Questions first**, all of them. An answer can change whether a selected fix is still
   wanted, or how to write it — applying first and learning the constraint after means doing
   it twice.
2. **Then the fixes**, in file order, one confirmation line each. The user ticked them; they
   don't need to be sold on them again.
3. **Then the movement** — navigation, skip, or the recap — always last, whatever order the
   options appeared in.

| They tick / say | Do |
|---|---|
| nothing on a file | nothing on that file, no acknowledgement line |
| a fix option | apply it, confirm in one line |
| note au récap | add it to the recap's "reste à faire", don't touch the code |
| a question option | answer it before running any fix on that file |
| navigation | go there once the whole submission is processed |
| "reviens au 2" / "montre-moi X" | jump there, keep the counter honest |
| "arrête" | go straight to the recap for what was covered |

Fixes get applied to the working tree and left uncommitted while the review runs. Committing
mid-review would interleave review noise with the branch's real history, and the user hasn't
yet seen the whole picture. Step 6 is where they get placed. If a fix touches a file later in
the plan, say so when you reach it rather than silently showing the modified version.

## Step 5 — Recap

At the end, keep it short — the user just read everything:

```
## Récap
12 fichiers relus, 2 sautés (migrations générées).

Corrigé pendant la relecture
- `payment.ts:88` — retry limité aux 5xx

Reste à faire
- [ ] couvrir le cas carte expirée dans `payment.test.ts`
- [ ] décider si `LegacyGateway` peut être supprimé
```

If fixes were applied, they're still uncommitted at this point — end the recap by saying so
and go to Step 6. If nothing was fixed, the review is over here.

## Step 6 — Offer to file the fixes into the history

Only when fixes were actually applied. A review that changed nothing ends at Step 5.

The fixes are sitting uncommitted, and each one belongs to a commit that already exists on
this branch — the retry fix belongs with the commit that wrote the retry. Dropping them all
into one "review fixes" commit at the tip preserves the mistake in the history and buries the
correction three commits later. Filing each fix into its commit makes the branch read as if
it had been right the first time, which is what the reviewer of the merge request actually
gets to see.

This is the only step that writes to git. Everything before it is read-only, and this one
happens only on an explicit yes.

**Check the preconditions and report them plainly.** Rewriting shared history is the one way
this skill can cost someone else their afternoon.

```bash
git rev-parse --abbrev-ref --symbolic-full-name @{upstream}   # is there an upstream at all
git log --oneline @{upstream}..HEAD                           # what isn't pushed yet
```

- **Commits already pushed** — say so, name them, and say plainly that filing fixes into them
  means a `--force-with-lease` push, which breaks anyone who pulled the branch. If the branch
  is shared, a plain new commit on top is the honest answer; offer that instead.
- **On the default branch** — don't offer this at all. Rewriting `main` is not a review
  outcome.
- **Unresolved rebase or merge in progress** — stop, say what's in flight.

**Work out where each fix belongs.** For each modified file, look at which commit last
touched the lines you changed:

```bash
git log --oneline -L <start>,<end>:<path> <base>..HEAD
git blame -L <start>,<end> <base>..HEAD -- <path>
```

A fix whose lines trace to no commit on the branch — code that predates it — doesn't belong
in any of them; it becomes its own commit.

**Show the mapping before touching anything. Name commits by their subject, not their hash.**
A short hash is a lookup key, not a name: `fc3af07` tells the user nothing about what they're
being asked to modify, and they have to go read the log to answer a question you could have
made self-contained. The subject is the whole point of writing commit subjects.

```
« chore(plugins): add bootstrap script »        ← boucle read portable + validation jq
« fix(commit-message): skip repos with … »      ← Step 0 et déduplication du git log
nouveau commit                                  ← réécriture docker-compose (hors branche)
```

Keep the hash available but subordinate — a trailing `(fc3af07)` when the user might want to
run `git show`, never the headline. Truncate a long subject rather than dropping it; even
half a subject beats a full hash.

Then ask with an `AskUserQuestion`, one question per target commit so the user can accept some
placements and refuse others. Each question has to stand on its own:

- `question` — the subject, quoted: *Classer dans « fix(commit-message): skip repos with their
  own commit convention » ?*
- `header` — 12 characters, so a subject won't fit. Use the target's scope (`chore(plugins)` →
  `→ plugins`), or a word from the subject when there is no scope. Never the bare hash: an
  answer sheet reading `→ fc3af07`, `→ 26c91e1`, `→ 40443e2` is unreadable, and the user is
  navigating between those headers with the arrow keys.
- `options` — say what lands where in words: *Fusionner dans le commit du script bootstrap*
  beats *Oui, fixup dans fc3af07*.

Same rule in the recap and in every line you print along the way. The hash appears when it's
actionable — a command the user might copy — and the subject appears everywhere else.

**Then do it, in this order.** Commit everything first, take the safety ref second, rebase
third:

```bash
git commit --fixup=<sha> -- <paths>            # one per target commit
git add <new files> && git commit -m "<subject>"   # work belonging to no existing commit
git branch review-backup/<branch>              # ← after committing, before rebasing
GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <base>
```

The ref has to be taken *after* the commits exist. Take it at the start instead and it points
at the old tip, so the verification below compares "before the review" against "after the
review" — it shows every fix as a difference and proves nothing about the rebase. The ref
exists to freeze the exact state the rebase is about to rewrite, nothing else.

`GIT_SEQUENCE_EDITOR=:` is what keeps the rebase non-interactive — `--autosquash` files each
fixup against its target on its own and no editor opens, which matters because interactive
rebase isn't available here.

**Verify the tree is untouched.** History moved; the code must not have.

```bash
git diff review-backup/<branch> HEAD            # must be empty
git log --oneline <base>..HEAD
```

An empty diff is the proof that the rewrite reorganised commits without losing or altering a
line. If it isn't empty, say so immediately and offer `git reset --hard review-backup/…` —
that's what the ref was for.

Checking that a bad version never survived needs care too: `git log -S"mapfile"` also matches
the comment that explains why `mapfile` was dropped. To assert a string is gone from the
history, read the file at each commit rather than trusting the pickaxe:

```bash
for c in $(git rev-list <base>..HEAD); do
  git show "$c:<path>" 2>/dev/null | grep -q "<pattern>" && echo "still in $c"
done
```

**Never push.** Print the `git push --force-with-lease` line the user would need and let them
run it. Pushing rewritten history is their call, not a review side effect. Delete the backup
ref only when they say they're satisfied.

## Rules

- **Read-only git through Steps 1 to 5.** No `checkout`, `switch`, `reset`, `rebase`,
  `stash`, or `commit` while reading — the user is working on this branch. Step 6 is the sole
  exception and requires an explicit yes.
- Use the diff spec settled in Step 1 for every command, from the `--stat` to the last file.
  Three dots when the review is commits-only; a bare merge-base commit when the working tree
  is included, because `...` can't see uncommitted work.
- Pass `--find-renames` so a moved file reads as a rename, not as a delete plus an add.
- Answer in the language the user is speaking.
- If the scope comes out empty (branch identical to base, or the path filter matches
  nothing), say so and ask what they meant instead of reviewing something adjacent.
