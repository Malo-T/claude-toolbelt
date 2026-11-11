#!/usr/bin/env bash
# Usage: mark-pending.sh <handoff-file>
# Records the handoff as pending for the current directory, so the SessionStart
# hook picks it up after /clear. Keep the key in step with hooks/resume.sh.

set -eu

file=${1:?usage: mark-pending.sh <handoff-file>}
[[ -f $file ]] || { echo "no such file: $file" >&2; exit 1; }

config=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
key=$(printf '%s' "$PWD" | cksum | cut -d' ' -f1)
mkdir -p "$config/handoffs/.pending"
printf '%s\n' "$file" > "$config/handoffs/.pending/$key"
echo "pending: type /clear to resume from $file"
