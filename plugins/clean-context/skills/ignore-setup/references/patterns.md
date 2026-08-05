# Pattern catalogue

Read this when writing the managed block. Take only what the repo actually contains — Step 1 of
the skill exists to filter this list, not to copy it wholesale.

Each line answers one question: *would reading this file ever help answer a question about this
project?* If the answer is "only when I go looking for it on purpose", it belongs here, because an
`.ignore` entry hides a path from discovery without blocking `Read`.

## Lockfiles

High-volume, machine-written, occasionally needed for one exact version — the textbook case for
"hidden but readable".

```
package-lock.json
pnpm-lock.yaml
yarn.lock
composer.lock
Gemfile.lock
poetry.lock
uv.lock
Cargo.lock
go.sum
```

## Generated and vendored code

Committed but not authored here; editing it is always a mistake, and reading it teaches nothing
about the project's own decisions.

```
**/generated/
**/__generated__/
*.pb.go
*_pb2.py
*_pb2_grpc.py
vendor/
third_party/
gradle/wrapper/
gradlew*
mvnw*
.mvn/
```

## Build outputs and caches

Usually in `.gitignore` already — worth listing anyway, because until the Glob env setting is
picked up (next session) `.gitignore` does not cover Glob at all.

```
dist/
build/
out/
target/
.next/
.nuxt/
.svelte-kit/
coverage/
node_modules/
__pycache__/
.venv/
venv/
*.egg-info/
.tox/
.mypy_cache/
.pytest_cache/
.ruff_cache/
.gradle/
.turbo/
.parcel-cache/
.cache/
```

## Minified and compiled assets

One line, hundreds of kilobytes, no readable structure.

```
*.min.js
*.min.css
*.bundle.js
*.map
```

## Binaries and media

ripgrep already skips binaries when matching content, but they still show up in file listings and
in Glob results.

```
*.png
*.jpg
*.jpeg
*.gif
*.webp
*.ico
*.pdf
*.woff
*.woff2
*.ttf
*.eot
*.mp4
*.zip
*.tar.gz
*.jar
*.war
*.class
*.so
*.dylib
*.dll
*.exe
*.wasm
```

`*.svg` is deliberately absent — it is text, it is sometimes hand-edited, and it is sometimes a
20 000-point export. Ask before adding it.

## Snapshots, fixtures, dumps

```
**/__snapshots__/
*.snap
*.csv
*.parquet
db/seeds/*.sql
**/fixtures/**/*.json
```

`**/fixtures/**` earns a question first: in a test-heavy repo the fixtures *are* the specification,
and hiding them makes the tests unreadable. Check with
`rg -l 'fixtures?/' --type-not json | head` before deciding.

## i18n in volume

```
**/*.po
**/*.pot
**/locales/**/*.json
**/messages/**/*.json
```

Same caveat: fine when translations are bulk data, wrong when the keys are the domain vocabulary.

## Logs, editor and infrastructure state

```
*.log
logs/
tmp/
.idea/
.vscode/
.DS_Store
.terraform/
*.tfstate
*.tfstate.*
```

## Never exclude

Not negotiable — these are what makes a project legible:

- source files, in any language
- `README*`, `CHANGELOG*`, hand-written `docs/*.md`, ADRs
- `CLAUDE.md` at any level, and `.claude/`
- root configuration: `package.json`, `pom.xml`, `build.gradle*`, `pyproject.toml`, `go.mod`,
  `Cargo.toml`, `composer.json`, `tsconfig.json`, `Dockerfile*`, `docker-compose*.yml`
- database migrations — they are the schema's history
- CI definitions (`.github/workflows/`, `.gitlab-ci.yml`)

## Read-deny block for secrets

Goes in `.claude/settings.json`, not in `.ignore`: the point here is a hard block, not a clean
listing. Permission rules have no negation, so patterns are enumerated one by one to keep
`.env.example` and `.env.sample` readable.

```json
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.local)",
      "Read(./.env.*.local)",
      "Read(./**/*.pem)",
      "Read(./**/*.key)",
      "Read(./**/*.p12)",
      "Read(./**/*.jks)",
      "Read(./**/*.keystore)",
      "Read(./**/id_rsa*)",
      "Read(./**/secrets/**)"
    ]
  }
}
```

Keep it short. Every entry here is a path that can no longer be read even when reading it is the
right call — the only way around it is `cat` through Bash, which is a worse experience than a
prompt would have been.
