---
name: audit-context
description: Measures where a project's Claude context is going before applying any of clean-context's levers. Reports what Glob discovers with and without ignore files applied, the twenty largest files in the repo and which are generated, the cumulative size of every CLAUDE.md loaded for this working directory, and how many MCP servers/tools are enabled. Ranks the levers by estimated gain, each pointing at the skill that applies it. Read-only, writes nothing. Use when someone asks to measure or audit context bloat, "pourquoi mon contexte est plein", "combien pèse mon CLAUDE.md", "which of these should I clean first" before running ignore-setup blind, or when asked generally to optimize or reduce context usage. Skip for a request to actually apply a fix (ignore-setup's job) or to improve CLAUDE.md's content quality or wording (claude-md-management:claude-md-improver's job, not its size).
---

# Audit Context

Read-only. Measures four sources of context bloat, then ranks the levers that address them.
No file is written and no setting is changed. Fixes to the repository's own reach live in
`ignore-setup`; fixes to the Claude Code setup around it — `CLAUDE.md` bulk, unused skills, plugins
and MCP servers — live in the built-in `/doctor`, not here (see `../../ROADMAP.md`).

```
/clean-context:audit-context
```

## This skill does not fix anything

If the ask mid-run turns into "et maintenant exclus-les", report what the measurement found and
hand off to `ignore-setup`; do not start editing. That boundary is the only thing separating the two
skills. If it turns into "désactive ce serveur" or "allège mon CLAUDE.md", hand off outside this
plugin instead: point at `/doctor`, which acts on both and writes the settings this skill only reads.

## Step 0. State of play

- Project root: `git rev-parse --show-toplevel 2>/dev/null || pwd`. No `.git` is not an error:
  fall back to `pwd` and say so in the report. Every measurement below still works, except that
  `rg`'s `.gitignore` support is git-repo-gated (Step 2 below adds `--no-require-git` for this
  case).
- Detect whether `ignore-setup` already ran here:
  `grep -o '"CLAUDE_CODE_GLOB_NO_IGNORE"[^,}]*' .claude/settings.json .claude/settings.local.json
  2>/dev/null`. If it is set to `false`, Glob already obeys ignore files this session, so label
  Step 2's two numbers accordingly instead of assuming the raw count is "today".
- Detect whether CLAUDE.md loading is disabled entirely: `env | grep
  CLAUDE_CODE_DISABLE_CLAUDE_MDS`. If set, Step 4's byte totals are moot. Say the budget is
  already zero and why, and skip straight to that row in the report.

## Step 0bis. Tokenizer availability

Bytes are a proxy that misleads on minified assets and CJK text, and there is no local Claude
tokenizer to fall back on: the only exact count is the Messages API's `count_tokens` endpoint,
which needs network access and credentials and is too heavy for a diagnostic that should run
anywhere. So: use a real tokenizer opportunistically if one is already reachable, never install
one silently.

1. Check a small cache first: `~/.cache/claude-toolbelt/audit-context-tokenizer.json`. If it
   records a tool and that tool still resolves, reuse it and skip straight to Step 1.
2. Otherwise probe both, cheaply:
   - `gpt-tokenizer` (npm): a cached `npx` resolution check, or `node -e "require('gpt-tokenizer')"`
     if a project `node_modules` already has it.
   - `tiktoken` (pip): `python3 -c "import tiktoken"`.
3. If exactly one is reachable, use it for Steps 2 and 3's token counts.
4. If both are reachable, ask which to use, defaulting to `gpt-tokenizer`: it leaves no
   persistent install footprint, since `npx` resolves from cache while `pip install` does not.
   The choice between the two is an environment convenience, not an accuracy trade-off: both wrap
   the same modern BPE-style encoding (`o200k_base`) by default, and a check on this repo's own
   CLAUDE.md files and its twenty largest files put `gpt-tokenizer`'s output within 0.3% of
   `tiktoken` on either of its common encodings. Pick whichever ecosystem the machine already has
   (npm or pip), not the one presumed more correct.
5. If neither is reachable, say so and offer to fetch `gpt-tokenizer` via `npx` for this run.
   Never install anything without asking first; the normal Bash permission prompt is the actual
   gate here, not this skill's own judgment. On refusal, or no answer, fall back to bytes plus the
   density ratio described in the report section below.
6. Write whatever was decided (tool name, or "none") to the cache file so future runs skip the
   probe.

The chosen unit (or "none") carries through every step below, and changes what Steps 2 and 3
actually report:

- **With a tokenizer**: each file and each CLAUDE.md gets an actual token count, a closer proxy
  for real context cost than a byte count, still flagged as a GPT-vocabulary approximation, not a
  Claude-exact count. No local Claude tokenizer exists, and `@anthropic-ai/tokenizer` was
  considered and rejected: it hasn't been updated in years, and its Claude-branded name would
  overstate its accuracy against current models.
- **Without one**: each file and each CLAUDE.md gets a byte count plus the bytes/word density
  ratio from Step 5. This is cruder and needs no dependency at all; instead of computing a number
  that might be wrong, it mechanically flags the rows where bytes are likely to mislead (minified
  content, CJK text) so a human can check them by hand rather than trusting the ranking blindly.

## Step 1. Glob reach, with and without ignore files

```sh
NO_GIT=""  # add --no-require-git if Step 0 found no .git
rg --files --no-ignore --hidden $NO_GIT | wc -l   # what Glob returns today (default)
rg --files --hidden $NO_GIT             | wc -l   # what it would return with ignore files applied
```

`--no-require-git` matters precisely in the no-`.git` case: ripgrep only honours `.gitignore` when
it detects a git repository. Without the flag a non-git checkout would silently under-report the
gap between the two numbers for reasons that have nothing to do with the project's actual noise.

Keep both file lists, sorted, diffed with `comm -23`, in a scratch dir under `mktemp -d`, never in
the project tree. The diff is the concrete "what Glob stops seeing" list for the report.

## Step 2. Twenty largest files, and which are generated

```sh
git ls-files -z 2>/dev/null | xargs -0 du -b 2>/dev/null | sort -rn | head -20
```

Scoped to files tracked by git: that is what a clean clone actually contains, so it is the
committed noise that matters. Without `.git`, fall back to:

```sh
rg --files --no-ignore --hidden $NO_GIT \
  | while IFS= read -r f; do printf '%s\t%s\n' "$(stat -c '%s' "$f" 2>/dev/null || stat -f '%z' "$f")" "$f"; done \
  | sort -rn | head -20
```

Classify each of the twenty (cheap, since it is only twenty files):

1. Match against the categories in `../ignore-setup/references/patterns.md` (lockfiles,
   generated/vendored, build output, minified, binaries, snapshots): reuse that catalogue rather
   than duplicating it, so the two skills never disagree on what "generated" means.
2. If unmatched and the file looks textual and is under ~200 KB, sniff a self-declared marker:
   `head -c 2000 "$f" | grep -Eqi '@generated|do not edit|autogenerated|auto-generated|generated by|code generated'`.
3. If still unmatched: `git check-attr linguist-generated -- "$f" 2>/dev/null | grep -q 'set$'`.
4. Otherwise: "unclassified, worth a look if the size is a surprise."

For each of the twenty, report the byte size, and either a token count (if Step 0bis found a
tokenizer) or the bytes/word density ratio (see Report below).

## Step 3. CLAUDE.md, cumulative, walking up

Claude Code loads CLAUDE.md by walking from the working directory up to the filesystem root, plus
the always-loaded user-level file:

```sh
dir="$PWD"; total=0
while :; do
  f="$dir/CLAUDE.md"
  if [ -f "$f" ]; then
    sz=$(wc -c < "$f"); total=$((total + sz))
    printf '%s\t%s\n' "$sz" "$f"
  fi
  [ "$dir" = "/" ] && break
  dir=$(dirname "$dir")
done
if [ -f "$HOME/.claude/CLAUDE.md" ]; then
  sz=$(wc -c < "$HOME/.claude/CLAUDE.md"); total=$((total + sz))
  printf '%s\t%s (user, always loaded)\n' "$sz" "$HOME/.claude/CLAUDE.md"
fi
echo "TOTAL: $total bytes"
```

No CLAUDE.md anywhere means a total of zero. Say the preamble row has nothing to trim and move on,
rather than treating zero as an error. If a tokenizer is available (Step 0bis), add a
token count per file and for the total alongside the byte counts.

## Step 4. MCP servers and the tools they contribute

Configured servers, three scopes: `claude mcp list` (health per server, the source of truth for
enabled/reachable), `~/.claude.json` → `mcpServers` (user scope), `.mcp.json` and
`.claude/settings.json`'s `enabledMcpjsonServers` / `disabledMcpjsonServers` (project scope). No
server anywhere means zero servers, zero tools: skip straight to that report row.

Tool count per server: the session running this skill has its own tools grouped by
`mcp__<server>__` prefix, directly visible, or discoverable via `ToolSearch` for anything deferred.
The count per prefix is what that server is contributing to context in *this* session. Cross-check
every group against the health line from `claude mcp list`.

**Deferred or resident — establish this before quoting any cost.** MCP tool schemas sit deferred
behind `ToolSearch` by default: only the tool *name* stays resident, and Claude Code fetches the
schema on demand, so fifty deferred tools cost a few hundred tokens against the tens of thousands a
resident set would. Read your own context to tell the two apart: deferred tools arrive as a
names-only list in a system-reminder, resident ones carry full schemas in the tool list. A server
opts out per tool via `anthropic/alwaysLoad` in the tool's `_meta`, which the server decides and no
setting here overrides. Count only the names for a deferred server, report its resident cost as
roughly zero, and never present it as a context saving waiting to be made. Its one honest signal is
invocation count, and that measurement belongs to `/doctor`'s check 1.

Two health lines change what a count means:

- A server reported "Needs authentication" that shows exactly two tools
  (`mcp__<server>__authenticate`, `mcp__<server>__complete_authentication`) is showing an OAuth
  stub, not its real surface. Say so explicitly rather than reporting "2 tools" as the final
  answer.
- A server reported "Failed to connect" and absent from the tool list entirely is contributing
  zero tools right now, which is the correct answer to "how many tools does it cost me today", not
  to "how many tools would it cost if it were up".

This measurement is a session snapshot, not a fact of configuration. Timestamp it in the report
and keep it visually distinct from Steps 1 through 3, which are deterministic filesystem reads.

## Step 5. Rank and report

Tag each lever with its cost shape before ranking anything, since the units differ in kind:
**recurring** (paid on every request — MCP tool schemas, but only those actually resident, per
Step 4), **once** (paid once per session, CLAUDE.md), **conditional** (paid only if the file is
actually read, Glob and generated-file noise). Order the table recurring → once → conditional, and
by magnitude within each group; never collapse the three into one number.

| Lever | Current cost | Est. gain | Cost shape | Confidence | Where the fix lives |
|---|---|---|---|---|---|
| MCP tool schemas | … servers, … tools, of which … resident | … resident tools; deferred ones ≈ 0 | recurring only if resident | low-medium, session snapshot, see Step 4 caveats | `/doctor` check 1 |
| CLAUDE.md preamble | … across … files | up to … | once, per session | high, direct read | `/doctor` checks 2–4 |
| Glob noise | … files beyond what obeys ignore | … files hidden | conditional, per search | high, direct measurement | ignore-setup |
| Largest generated files | … of the top 20 | up to … | conditional, per read | medium, pattern + marker heuristic, not exhaustive | ignore-setup (extend patterns) |

State the unit once, right after the table, not per row: either "token counts via `<tool>`, a
GPT-vocabulary approximation of Claude's real tokenizer" (Step 0bis found one) or "byte counts;
rows marked `*` have a bytes/word ratio above 20 and likely misrepresent their real cost (minified
content, CJK text, or similar): verify by opening a sample before trusting that row's ranking" (no
tokenizer found). Compute the ratio with `wc -c` / `wc -w` on any file or section entering the
table; it needs no external tool.

### Guardrails

- Never write, never edit a setting, never install anything without saying so and letting the
  normal Bash permission prompt gate it. This applies to the tokenizer probe in Step 0bis as much
  as to anything else.
- Scratch files (Step 1's file lists) go under `mktemp -d`, never inside the project.
- Cap Step 2's content sniff at ~200 KB and 2000 bytes read: this is a diagnostic, not a full read
  of every large file.
- No `.git`, no CLAUDE.md, no MCP servers, no tokenizer found: none of these are failures. Each
  gets an explicit "nothing to measure here" (or "falling back to bytes") line in the report
  rather than a silent gap.
