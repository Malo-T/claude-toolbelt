#!/usr/bin/env bash
# Fail when the two resident watchers stop being the same program.
#
# status-icons and status-sounds each ship their own copy of watch.sh, and that
# duplication is deliberate: the plugins install independently and must not
# depend on anything shared. The price is that every fix has to be written
# twice, and nothing but this check notices when only one of them got it.
#
# Their prose is allowed to differ — one talks about an icon, the other about a
# sound — so full-line comments are dropped before comparing. Everything else
# has to match once the plugin's own name, its environment prefix and the script
# it calls are normalised away. Trailing comments are kept on purpose: dropping
# them would also cut `${line##*") "}` short and hide a divergence behind it.

set -u

root=$(cd "$(dirname "$0")/.." && pwd)
a=$root/plugins/status-icons/hooks/watch.sh
b=$root/plugins/status-sounds/hooks/watch.sh

for f in "$a" "$b"; do
  if [[ ! -r $f ]]; then
    printf 'missing: %s\n' "$f" >&2
    exit 2
  fi
done

normalise() {
  sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' \
    -e 's/STATUS_ICONS/STATUS_X/g; s/STATUS_SOUNDS/STATUS_X/g' \
    -e 's/status-icons/status-x/g; s/status-sounds/status-x/g' \
    -e 's/tab-title\.sh/CALLEE/g; s/play\.sh/CALLEE/g' \
    "$1"
}

if diff -u --label status-icons/hooks/watch.sh --label status-sounds/hooks/watch.sh \
  <(normalise "$a") <(normalise "$b"); then
  echo "watcher parity: ok"
  exit 0
fi

cat >&2 <<'MSG'

The two watchers have diverged. Either port the change to the other copy, or —
if the difference is genuinely per-plugin — teach the normalisation above about
it rather than leaving the check red.
MSG
exit 1
