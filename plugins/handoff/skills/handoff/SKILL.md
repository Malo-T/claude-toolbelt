---
name: handoff
description: |
  Writes a handoff file for the current session (goal, findings, rejected hypotheses, decisions, next step) so a fresh session can continue without losing the thread. A controlled alternative to /compact when the context has grown. Also resumes from an existing handoff. Triggers: "/handoff", "write a handoff", "hand this off", "let's restart on a clean session", "the context is too big", "fais un handoff", "prépare la reprise", "on repart sur une nouvelle session"; for later: "handoff to resume tomorrow", "handoff pour demain"; resume: "resume from the handoff", "reprends depuis le handoff", "/handoff <path>".
---

# Session handoff

Two modes. Write is the default; resume applies when the user gives a path or asks to resume.

## Write mode

### 1. Where

`${CLAUDE_CONFIG_DIR:-~/.claude}/handoffs/<repo-or-directory-name>/<YYYY-MM-DD-HHmm>-<short-slug>.md`

Outside the repo, so git stays clean. For a handoff the user will pick up later ("tomorrow", "later"), use the suffix `.later.md` and skip step 3. If unsure which variant is wanted, ask before writing.

### 2. Content

The reader is a fresh Claude with no context. Anything unwritten is lost. Be factual and dense, not narrative.

```markdown
# Handoff: <title>
Written <date and time> from <cwd>, branch <branch>.

## Goal
<what the session set out to do, and why>

## Where things stand
<what is done, verified, and how it was verified>

## Findings and rejected hypotheses
<what was tried or ruled out, so it is not redone>

## Decisions
<each decision with its reason>

## Uncommitted changes
<every modified file in the tree, one line each, with what changed>

## Next step
<the single next action, then what follows>

## Open questions
<what only the developer can answer>
```

If the user wants only part of the work carried over, put the scope at the top, develop only that part, and list the rest under "Out of scope", one line per topic. "Uncommitted changes" still lists every modified file, in scope or not, so nothing is lost or committed by mistake.

### 3. Make resume automatic

Run `bash "${CLAUDE_SKILL_DIR}/scripts/mark-pending.sh" <file>`. It records the file as pending for this directory. Then tell the user to type `/clear`: the plugin's SessionStart hook injects the resume instruction into the fresh session. A hook cannot run `/clear` itself.

## Resume mode

Without a path, take the most recent file in `${CLAUDE_CONFIG_DIR:-~/.claude}/handoffs/<repo-or-directory-name>/` and name it before continuing. Read it, say in three lines where things stand, check that the described state is still true (git status, the files it cites), and propose the next step. Run nothing before the user agrees. For a partial resume ("only X"), work on that part and leave the others untouched.
