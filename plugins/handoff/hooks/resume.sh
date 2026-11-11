#!/usr/bin/env bash
# SessionStart (matcher "clear"): if the session that just ended left a pending
# handoff for this directory, tell the fresh session to resume from it.
# Written for bash 3.2: no associative arrays, no case-conversion expansions.

set -u

cwd=$(jq -r '.cwd // ""')
[[ -n $cwd ]] || exit 0

config=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
key=$(printf '%s' "$cwd" | cksum | cut -d' ' -f1)
pointer=$config/handoffs/.pending/$key
[[ -f $pointer ]] || exit 0

# A pointer older than an hour belongs to a handoff nobody cleared for: drop it.
if [[ -n $(find "$pointer" -mmin +60 2>/dev/null) ]]; then rm -f "$pointer"; exit 0; fi

file=$(head -n 1 "$pointer")
rm -f "$pointer"
[[ -f $file ]] || exit 0

jq -n --arg file "$file" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("The previous session in this directory ended with a handoff. Resume from " + $file + ": read it, say in three lines where things stand, check that the state it describes is still true (git status, the files it names), and propose the next step. Run nothing before the developer agrees.")
  }
}'
