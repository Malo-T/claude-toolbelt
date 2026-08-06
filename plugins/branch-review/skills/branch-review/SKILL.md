---
name: branch-review
description: >-
  Takes stock of what a branch actually changed, before it gets pushed — works out the scope
  itself, then lays the change out group by group in one pass: files touched, what was done and
  why, how, and what deserves a second look, quoting code only where a remark needs it rather than
  reprinting the diffs. Closes on a single question set so the user steers without wading through
  hunks, and can then file the fixes decided along the way into the commits they belong to, via
  fixup and autosquash. Use it whenever someone wants to find out what happened on their own
  unmerged work — "relis ma branche", "on repasse sur mes commits", "vérifier ce que j'ai fait hier
  soir", "qu'est-ce que j'ai changé au juste sur cette branche", "fais le point avant que je
  pousse", "repasser sur ce que j'ai fait avant de demander une revue", "check my work before I open
  the MR/PR", "walk me through my changes" — including when the code was produced fast with an
  assistant and they no longer know what is in there, when they only name a commit range, a path, or
  a branch, and when they have uncommitted fixes to read through and then tidy into the right
  commits. Reach for it rather than answering with a bare git diff or an off-the-cuff recap — what
  is wanted is an account they can steer from. Skip when they hand over a single file or snippet and
  want an automated findings report, and skip for a security-only audit — Claude Code ships
  `security-review` for that one.
---

# Branch Review

Tell the user what happened on their branch, so they can settle it before pushing. The
situation this exists for: the work got produced fast — often with an assistant holding the
keyboard — the result works, and nobody really knows what it changed. Taking stock is the
job.

So the deliverable is **what was done, why, how, and what deserves a second look**, group by
group, and then one question set to steer from. Not the code: the user has `git diff`, and
what they lack is the account of it. Quote a few lines only where a remark is unreadable
without them, and let them ask for any diff they want to see.

Two failure modes to avoid. Reprinting the branch: a wall of hunks is unreadable in a
terminal, and every line of it pushes the decisions further down the scroll. And chopping the
account into prompts: a question between every two groups scatters the remarks across a
corridor of round-trips. **One account, one question set, one round of fixes.**

## Invocation

```
/branch-review [optional restriction]
```

Examples:
- `/branch-review`
- `/branch-review les 2 derniers commits`
- `/branch-review seulement le back`
- "je voudrais repasser sur ce que j'ai fait avant d'ouvrir la MR"
- "on a produit ça en deux heures, qu'est-ce qui a changé au juste avant que je pousse ?"

## Step 1 — Resolve the scope

Never start reading before you know exactly what you are reading and the user has seen it.

**The default is the current branch against its parent, up to their last common commit.**
Everything else is the user's to name — "les 3 derniers commits", "ce qui touche au
composant paiement", "juste ce que je n'ai pas poussé". Take what they said; only work out
the default when they said nothing.

Git has no notion of a parent branch, so it has to be inferred: among the integration
branches that exist — `origin/HEAD`, `origin/develop`, `origin/main`, `origin/master` — take
the one whose merge-base with HEAD is **closest**, in commits. That winner is `<base>`, the
single name used for it everywhere below:

```bash
git rev-list --count $(git merge-base <candidate> HEAD)..HEAD   # smallest wins → <base>
```

Three details decide whether this works:

- Compare by **distance, not by commit date**. Two merge-bases made in the same second tie,
  and the tie then gets broken at random.
- Use the **remote-tracking** refs. A local `develop` left behind moves the merge-base and
  silently widens the review; a local `main` may be the branch you are standing on.
- Skip any candidate whose merge-base is HEAD itself. On the default branch this leaves its
  own remote-tracking ref as the parent, which is the right answer: what is committed here
  and not yet pushed.

When two candidates share the same merge-base, the answer does not exist — git records a
branch's creation point as a commit, not a branch name, so the graph cannot say whether the
work came off `main` or off a `develop` that pointed at the same commit. Ask rather than
present the alphabetical winner as a fact.

**If the scope comes out empty** — everything already pushed, nothing above the parent — the
user usually wants to re-read work that has landed. Don't answer "nothing to review"; offer
ranges: `HEAD~5..HEAD`, `--since=yesterday`, `<sha>^!`, `v1.4.0..HEAD`.

**Take the inventory** (run these together):

```bash
git log --oneline <base>..HEAD
git diff --stat --find-renames <base>...HEAD
git status --short
```

Use **three dots** for the diff: `develop...HEAD` *is* `git diff $(git merge-base develop
HEAD) HEAD`, the comparison against the last common commit. That is what makes divergence a
non-problem — two dots would instead show the parent's own new commits inverted, as
deletions in files the user never touched.

**When the parent has moved on**, say so and offer a rebase before reading — then take no
for an answer:

```
`origin/develop` a avancé de 4 commits depuis ton point de départ. Rebaser avant de relire ?
```

The offer is not there to fix the diff — the reading is identical either way. It is there
because a rebase is often wanted before the merge request anyway, and doing it first means
reading the code in the state it will be merged in, conflicts resolved included. Don't make
the offer at all when the branch is already pushed (it would need a force-push) or the tree
is dirty (the rebase would have to stash it): say which, and move on.

**Honour explicit restrictions** the user gave:

| The user says | Scope |
|---|---|
| nothing | `<base>...HEAD` |
| "ce que je n'ai pas encore poussé" | `@{upstream}..HEAD` |
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

## Step 2 — Work out the groups

**The unit of the account is a change, not a file.** A branch of twelve files is rarely
twelve things: it is two or three, plus their tests and their wiring. Find those, and the
whole review fits on a screen; list the files instead and you have rebuilt `--stat` with
commentary.

Group by the change each file serves, then order the files inside a group so the group reads
top-down:

1. What defines the change — migrations, schemas, models, API contracts, types
2. The business logic that implements it
3. The callers and the wiring — controllers, routes, UI, DI config
4. The tests
5. Config, docs, CI

Order the groups themselves by weight: the change the branch is *about* first, the drive-by
tidying last. Say which grouping you used, in a clause — the user is the one who wrote this
and needs to recognise it, not to be taught a taxonomy.

Collapse the noise: lockfiles, generated code, snapshots, vendored assets and binaries get
one line for the lot ("6 fichiers générés, non relus"), never a group of their own.

**No separate reading plan.** A numbered plan followed by the account lists every file twice,
and the announcement in Step 1 plus the group headings already say what is coming. The lines
saved are the whole point of the exercise.

## Step 3 — Read everything, then write the account

### Read it all — this part is not optional

You read the code so the user doesn't have to. That trade only holds if you actually read it,
and an account written off the commit subjects is worse than no account: it is confident and
wrong in the exact place the user stopped checking.

```bash
git diff --find-renames -U10 <spec> -- <path>    # per file, using the spec from Step 1
git log <base>..HEAD                             # full messages, for the stated intent
```

**Read the whole current file, not just its diff.** A diff lies by omission: it hides the
guard clause twenty lines up, the existing helper that already does this, the caller that
assumes the old shape. And **commit messages are a claim, not evidence** — check each against
what its commit actually did. A commit that says one thing and does two is one of the most
useful things this review can surface, and it is invisible to everyone who trusts the log.

### Then write it, in one message

Every group, in Step 2's order, in **one uninterrupted message**. No question between two
groups, no "on continue ?", no pause to confirm the user is still there. They read it at their
own pace and answer once at the end.

Aim for something the user can take in without scrolling far — a couple of screens for a
twelve-file branch, a handful of lines per group. That budget is what makes the question set
land while the account is still on screen, so spend it on the groups that carry the change and
give the tidying one line.

Each group takes this shape:

```
## L'authentification par jeton   (3 fichiers, +180 −24)

Le login passe du cookie de session à un JWT court doublé d'un refresh token : `token.ts`
émet et vérifie, le middleware lit désormais l'en-tête `Authorization`. Motif annoncé dans
« feat(auth): drop session cookies » — permettre les clients mobiles.

- `auth/token.ts` — nouveau (+120) : émission, vérification, TTL 15 min
- `auth/middleware.ts` (+40 −20) : en-tête au lieu du cookie, 401 si absent
- `auth/login.test.ts` (+20 −4) : couvre l'émission, pas le refresh

**À vérifier**
- `middleware.ts:41` — le cookie n'est plus lu, mais `legacy/export.ts:88` l'envoie encore :
  l'export tombera en 401
- `token.ts:64` — le refresh n'a pas de test, et c'est la moitié du mécanisme
```

Three things carry it, and none of them is a hunk:

- **The paragraph** — what the change does, how it does it, and why, in two to four sentences.
  Name the mechanism, not the outcome only: "passe par un middleware" tells the user where to
  look, "améliore l'authentification" tells them nothing. If the why is a guess rather than
  something a commit message or the code states, say so — "sans doute pour…".
- **One line per file** — path, churn, and what that file's part is. A three-hundred-line
  rewrite still gets one line; a big diff buys a more careful summary, not more space.
- **À vérifier** — three items at most, each anchored to `file:line`, and **zero is a valid
  answer**: write "Rien à signaler." and move on. Flagging something in every group trains the
  user to skim the section that matters most.

### What earns a place in À vérifier

Things the user cannot see for themselves: a case the branch doesn't handle, a caller that
wasn't updated, an inconsistency with how the rest of the codebase does this, an assumption the
tests don't cover.

Code produced at speed has its own tells, and they are worth more here than anywhere else:
something changed that nobody asked for, a helper reimplemented next to the one that already
existed, debug output or a `TODO` left in, a test that asserts the new behaviour by restating
it. Say plainly when a change looks incidental — "ce renommage n'a rien à voir avec le reste,
volontaire ?" is exactly the question the user opened this review to be asked.

Not style, not naming, not "you could extract this" — unless the user asks for that kind of
pass.

### Quoting code

An excerpt is for a remark that cannot be made in prose — the line that is subtly wrong, the
two branches that got swapped. Five lines at most, inside the **À vérifier** item it belongs
to, never as a separate block:

````
- `payment.ts:88` — le retry ne distingue pas un 4xx d'un 5xx, une carte refusée sera rejouée
  trois fois :
  ```ts
  } catch (e) { return retry(charge, 3) }
  ```
````

Never quote to prove the summary or to show scale. The user can see the whole thing whenever
they want — the question set offers it (Step 4), and asking works too. Withholding the diff by
default is not withholding information; it is putting the decisions where they can be read.

Three shapes need saying out loud, since no diff goes out to imply them:

- **A deleted file** — say what it was and what covers it now. The removed lines stay gone.
- **A rename or a move** — say it in the file line (`ancien → nouveau`), so the user doesn't
  read a delete and an add as two changes.
- **A new file** — its structure in a clause, then straight to the remarks.

**Then stop, once, at the end.** The account has gone out; the user is reading it.

## Step 4 — Close the account with one question set

One `AskUserQuestion`, once, after the last group. The user walks the questions with the arrow
keys, ticks what they want on each, and submits everything in one go. That single form is what
the whole account was building towards, and keeping the account short is what keeps it within
sight of the form.

The budget is fixed by the interface: **at most 4 questions, each carrying 2 to 4 options** —
sixteen proposed actions, ceiling. A twelve-file review has to fit in there, and it does,
because a question is **one decision, not one file**.

**Group by decision, not by file.** Three services that all retry on 4xx are one question with
three options, not three questions. Five skills that gained the same frontmatter key are one
question. Anchor each option to its own `file:line` so a grouped question stays precise:

- `question` — *Le retry rejoue les 4xx à trois endroits — on le limite aux 5xx ?*
- `header` — `retry 4xx` (12 chars max)
- options — *`payment.ts:88`* · *`webhook.ts:41`* · *`sync.ts:112`*

A file gets a question to itself only when its decision belongs to no other — a rewrite to
accept or refuse, a naming choice that spreads nowhere else.

The options are where you propose what to *do* about what was read. A question that ends in a
bare question mark puts the burden back on the user to formulate; one that ends in "Corrige :
le retry rejoue les 4xx" hands them a decision. Draw them from what you actually found, in
this order:

1. **One per point flagged**, phrased as the concrete action rather than the observation:
   "Limiter le retry aux 5xx".
2. **Noter au récap sans corriger** — a real third path between fixing now and dropping it,
   and the one that usually fits a finding the user needs to think about.
3. **Voir le diff** — "Montrer le diff de `token.ts`". The account left the code out; this is
   how it comes back, and one of these is worth a slot whenever a remark is the kind the user
   will want to judge with the lines in front of them.
4. **Navigation** — "Revenir sur l'authentification", "Terminer maintenant".

`multiSelect: true`, always. Options are actions and actions compose: "corrige ce point et
réponds à ma question" is one ordinary intent that single-select splits into two round-trips.

**Submitting is what advances. Never add a "Suivant" option.** A checkbox meaning "do nothing"
duplicates the submit button and steals one of sixteen slots a real proposal could have used.
Nothing ticked simply means nothing to do.

This assumes the interface accepts a question with no box ticked. If it turns out to refuse
one, the fix is a neutral navigation option ("Montrer le diff de X", "Revenir sur X") that
gives the user something true to tick — not a "Suivant" wearing a different label, which puts
the useless checkbox straight back.

**Nothing to decide means no question at all.** Say "Rien à signaler" group by group in the
account, and if that holds for every group, skip the `AskUserQuestion` entirely and go to the
recap. A prompt whose only purpose is to be dismissed is the interruption this step exists to
remove.

**Never write a combination option.** "Les deux corrections", "tout appliquer" — these only
exist to work around single-select, and each burns a slot. With `multiSelect` the user
assembles the combination themselves. List each action once, atomically.

The rare exception is options that genuinely exclude each other — "cadrer sur le dev" versus
"cadrer sur le prod" is one decision with two answers, not two actions. Say so in the
descriptions so the exclusivity is visible, and if both come back ticked, ask which one
rather than picking.

Grouping fills the four option slots with four real findings; it is not a licence to pad. Two
well-aimed options still beat four stretched ones, and the free-text entry is always there, so
don't try to enumerate every possibility.

### Asking something you actually want answered

A guided review is also your chance to understand intent you can't read off the diff — why the
path is hard-coded, whether the old branch still has callers. But **a tick has to say
everything its option claims**, and an open question smuggled in as an option breaks that: the
user checks "Le chemin en dur est voulu ?", and the answer is still missing. They've said "yes,
let's talk about it" and nothing more. Leaving it unchecked is no better — indistinguishable
from having no opinion.

So a question you want answered never travels as an option. It gets **its own question** in the
set, and the options are the *candidate answers*:

- `question` — *`config.ts:12` — le chemin en dur vers `/var/data`, c'est voulu ?*
- `header` — a short label with a marker: `chemin dur ?`
- options — *Oui, c'est le point de montage en prod* · *Non, oubli — le passer en variable
  d'environnement*

Two plausible answers you'd bet on beat a rhetorical question every time, and the entry the
interface adds under them takes anything you didn't anticipate — that's where a sentence goes,
so don't spend an option restating that it exists. If it turns out the interface only accepts
free text on a question with no box ticked, say so when you ask, and keep the candidate answers
anyway.

An open question spends one of the four slots on its own, and unlike a fix it can't be grouped
with anything. If it's worth asking it's worth the slot; if it doesn't survive that trade, it
wasn't a question, it was curiosity.

### When it doesn't fit

Four questions is a hard cap, so an account that yields more than four distinct decisions has
to give something up. In order: group harder — near-identical findings across files almost always
collapse into one question; then drop the curiosity questions; then merge the small stuff into
a single "menu ménage" question whose options are the one-line fixes.

If it still doesn't fit, **don't open a second prompt.** Ask about the decisions that change
the code the most, and put the rest in the recap's "reste à faire" — saying, in one line, that
you did and why. A second prompt is the corridor of round-trips this step was rebuilt to
remove; an honest overflow line is not.

## Step 5 — Apply what came back

Nothing in the working tree has moved until now — that's deliberate, and it's what makes the
account true of the code as the user left it, rather than of a tree half-rewritten while they
were reading about it.

Everything comes back at once, across several files. Run it in the order that keeps the answers
useful:

1. **Questions first**, all of them. An answer can change whether a selected fix is still
   wanted, or how to write it — applying first and learning the constraint after means doing
   it twice.
2. **Then the fixes**, in file order. The user ticked them; they don't need to be sold on them
   again, and they don't need a running commentary either — Step 6 lists what changed, so
   apply them quietly and let the recap do the reporting.
3. **Then the movement** — navigation, skip, or the recap — always last, whatever order the
   options appeared in.

| They tick / say | Do |
|---|---|
| nothing on a question | nothing on the files it covered, no acknowledgement line |
| a fix option | apply it, confirm in one line |
| note au récap | add it to the recap's "reste à faire", don't touch the code |
| an answer to a question | treat it as settled, and settle it before running any fix it bears on |
| nothing on a question you asked | it stays unanswered — carry it to the recap's "reste à faire" rather than filling the blank yourself |
| navigation | go there once the whole submission is processed |
| "montre-moi X" / "le diff de X" | show it — the hunks, or the file whole — then come back to finish applying |
| "arrête" | go straight to the recap for what was covered |

Fixes get applied to the working tree and left **uncommitted**. Committing here would
interleave review noise with the branch's real history; Step 7 is where they get placed.

## Step 6 — Recap

At the end, keep it short — the user just read everything:

```
## Récap
12 fichiers relus, 2 sautés (migrations générées).

Corrigé
- `payment.ts:88` — retry limité aux 5xx
- `webhook.ts:41` — idem

Reste à faire
- [ ] couvrir le cas carte expirée dans `payment.test.ts`
- [ ] décider si `LegacyGateway` peut être supprimé
```

If fixes were applied, they're still uncommitted at this point — end the recap by saying so
and go to Step 7. If nothing was fixed, the review is over here.

## Step 7 — Offer to file the fixes into the history

Only when fixes were actually applied. A review that changed nothing ends at Step 6.

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

- **Read-only git through Steps 1 to 6.** No `checkout`, `switch`, `reset`, `rebase`,
  `stash`, or `commit` while reading — the user is working on this branch. Step 7 is the sole
  exception and requires an explicit yes.
- **One prompt for the whole account.** Steps 1 and 7 may ask their own questions — the scope
  when the tree is dirty, the placement of each fix — but between the first group and the last
  there is exactly one `AskUserQuestion`. Every extra prompt is a round-trip the user did not
  ask for.
- **The account replaces the diff; it never quotes it wholesale.** Read every line, print
  almost none — five lines at most, inside the remark they serve. Any diff the user asks for,
  they get in full.
- **Read before you summarise.** Every file's diff, the file around it, and the commit
  messages. A summary written from the log alone is the one output worse than a wall of hunks.
- Use the diff spec settled in Step 1 for every command, from the `--stat` to the last file.
  Three dots when the review is commits-only; a bare merge-base commit when the working tree
  is included, because `...` can't see uncommitted work.
- Pass `--find-renames` so a moved file reads as a rename, not as a delete plus an add.
- Answer in the language the user is speaking.
- If the scope comes out empty (branch identical to base, everything already pushed, or the
  path filter matching nothing), say so and offer the ranges from Step 1 instead of reviewing
  something adjacent. An empty scope is nearly always a base that doesn't fit the situation,
  not an absence of work.
