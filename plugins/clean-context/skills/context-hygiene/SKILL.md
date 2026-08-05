---
name: context-hygiene
description: Set up a project so Claude stops discovering lockfiles, generated code, minified assets and binaries on every search — a managed .ignore, the Glob setting that makes Glob obey it, and a short read-deny list for secrets. Use when someone asks for a .claudeignore, asks to exclude files from the context, says Claude wastes time reading generated or vendored files, says searches return too much noise, or wants a project configured right after /init ("ajoute un .claudeignore", "exclure des fichiers du contexte", "nettoyer le contexte du projet"). Skip for a one-off permission tweak like "allow npm commands" (that is update-config) and for cutting permission prompts (that is fewer-permission-prompts).
---

# Context Hygiene

Configure a project so the default file discovery is clean, while every excluded path stays
readable on purpose. Three layers, one command.

```
/context-hygiene:context-hygiene
```

## `.claudeignore` does not exist

If that is what was asked for, say so once and move on — it is the most common wrong turn here.
There is no `.claudeignore` in Claude Code (verified by inspecting the 2.1.x binary: zero
occurrences of `claudeignore`, `CLAUDE_IGNORE`, `ignoreFile`). A file placed at the root does
nothing at all. What exists instead:

| Lever | `Read` | `Grep` | `Glob` | `@` picker |
|---|---|---|---|---|
| `.gitignore` / `.ignore` | ignores it, reads anyway | **respected** | **not** respected | **respected** |
| `env: CLAUDE_CODE_GLOB_NO_IGNORE=false` | — | — | **makes Glob respect them** | — |
| `permissions.deny: ["Read(…)"]` | **hard block, no prompt** | **excluded** | **excluded** | excluded |

Grep runs ripgrep without `--no-ignore` (only `.git`, `.svn`, `.hg`, `.bzr`, `.jj`, `.sl` are
excluded in code), so it already obeys ignore files. Glob passes `--no-ignore --hidden` unless the
env var above says otherwise. Read-deny rules are turned into negative ripgrep globs for Grep,
Glob and the project file listing — that is the only lever that hides *and* blocks.

The consequence that shapes everything below: **an ignore file hides a path from discovery but
never blocks `Read`.** Clean by default, explicit on demand. `permissions.deny` is a wall, so it
is for secrets only. `permissions.ask` is not a middle ground — only `deny` feeds the Grep/Glob
exclusions, so it costs a prompt per read and cleans nothing.

These are version-specific facts (checked on 2.1.222). If a behaviour below does not reproduce,
re-check it rather than trusting this table.

## Step 1 — State of play

Read what is already there, and detect the stack from its markers:

- `.gitignore`, an existing `.ignore`, `.claude/settings.json`, `.claude/settings.local.json`
- `package.json` · `pom.xml` / `build.gradle*` · `pyproject.toml` / `requirements.txt` ·
  `go.mod` · `Cargo.toml` · `composer.json` · `*.tf`

Only write patterns matching something that actually exists in this repo. A dead pattern is a line
the next reader has to think about for nothing.

## Step 2 — Measure before

```sh
rg --files --no-ignore --hidden | wc -l   # what Glob sees today
rg --files --hidden | wc -l               # what Grep sees today
rg --files --no-ignore --hidden > /tmp/ctxhyg-before.txt
```

Keep the list, not just the count — Step 4 has to prove no source file disappeared.

## Step 3 — Write the three layers

Pick patterns from `references/patterns.md`, filtered by what Step 1 found.

**`.ignore` at the repository root**, inside a managed block:

```
# --- claude context hygiene (managed) ---
…patterns…
# --- /claude context hygiene ---
```

Rewrite only the inside of the block; leave every line outside it untouched. Never edit
`.gitignore` — different job, different audience, and build outputs already live there.

On a re-run, swap the block's body rather than rewriting the file — this keeps hand-written lines
below the block and makes a second run a no-op:

```sh
awk '
  /^# --- claude context hygiene \(managed\) ---$/ {print; inblock=1; while ((getline l < "'"$NEW"'") > 0) print l; next}
  /^# --- \/claude context hygiene ---$/            {inblock=0; print; next}
  !inblock {print}
' .ignore > .ignore.new && mv .ignore.new .ignore
```

**`.claude/settings.json`** — merge, never overwrite. Keep existing `hooks`, `permissions`,
`model`:

```json
{ "env": { "CLAUDE_CODE_GLOB_NO_IGNORE": "false" } }
```

**`.claude/settings.json` → `permissions.deny`** — secrets only, and enumerated. Permission rules
have no negation, so `.env.example` and `.env.sample` must stay outside the list:

```json
{ "permissions": { "deny": [
  "Read(./.env)", "Read(./.env.local)", "Read(./.env.*.local)",
  "Read(./**/*.pem)", "Read(./**/*.key)", "Read(./**/*.p12)", "Read(./**/*.jks)",
  "Read(./**/id_rsa*)", "Read(./**/secrets/**)"
] } }
```

### Guardrails

- **Never exclude**: source files, `README*`, hand-written `docs/*.md`, `CLAUDE.md`, `.claude/`,
  root config files (`package.json`, `pom.xml`, `tsconfig.json`, …), database migrations.
- **Ask first** on the double-edged ones: `*.svg` (sometimes hand-edited), `docs/` (sometimes
  generated, sometimes not), `**/fixtures/**` and `**/locales/**` when `rg` shows the code
  references them a lot.
- If a `deny` pattern would cover a file already read this session, say so rather than blocking it
  silently.
- Re-running must be a no-op. If `git diff` is not empty on a second run, the block markers or the
  JSON merge are wrong.

## Step 4 — Report

- Before/after: `rg --files --no-ignore --hidden | wc -l`, and a diff of the two file lists
  confirming only noise left.
- Which patterns were applied, and which were skipped because the repo does not have them.
- How to reach an excluded file on purpose — this is the part that makes the setup safe to accept:
  - excluded by `.ignore` → `Read` on the exact path still works, so does `rg --no-ignore`;
  - in `permissions.deny` → no prompt, no read; only `cat`/`rg` through Bash, since `Read(…)`
    rules do not govern the Bash tool;
  - `env` applies at startup, so **Glob only changes behaviour after a session restart**.
