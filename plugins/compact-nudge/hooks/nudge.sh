#!/usr/bin/env bash
# Nudge toward /compact or /clear when the context crosses a size threshold
# (Stop) or when a large context is about to be sent with a cold cache
# (UserPromptSubmit). Hooks get no token counts, so both read the transcript.
#
# Written for bash 3.2, the version macOS still ships: no associative arrays and
# no case-conversion expansions here.

set -u

payload=$(cat)
{
  read -r event
  read -r session_id
  read -r transcript
  read -r prompt_head
} < <(printf '%s' "$payload" |
  jq -r '.hook_event_name // "", .session_id // "", .transcript_path // "",
         (.prompt // "" | .[0:1])')

[[ -n $session_id && -f $transcript ]] || exit 0

# "150k" -> 150000; anything else that is not a plain integer -> empty.
to_tokens() {
  local v=$1
  case $v in
    *[kK]) v=${v%?}; [[ $v =~ ^[0-9]+$ ]] && echo $((v * 1000)) ;;
    *[mM]) v=${v%?}; [[ $v =~ ^[0-9]+$ ]] && echo $((v * 1000000)) ;;
    *) [[ $v =~ ^[0-9]+$ ]] && echo "$v" ;;
  esac
}

# "1h" / "5m" / "300" -> seconds.
to_seconds() {
  local v=$1
  case $v in
    *[hH]) v=${v%?}; [[ $v =~ ^[0-9]+$ ]] && echo $((v * 3600)) ;;
    *[mM]) v=${v%?}; [[ $v =~ ^[0-9]+$ ]] && echo $((v * 60)) ;;
    *) [[ $v =~ ^[0-9]+$ ]] && echo "$v" ;;
  esac
}

human() { echo "$(( ($1 + 500) / 1000 ))k"; }

state_dir="${TMPDIR:-/tmp}/compact-nudge"
mkdir -p "$state_dir" 2>/dev/null || exit 0
state="$state_dir/${session_id//[^A-Za-z0-9_-]/}"

# The tail is enough: the last API call or compaction is always near the end.
# ctx = prompt size of the last main-thread call; ttl = lifetime of its last write.
read -r ctx last_ts ttl < <(tail -c 4000000 "$transcript" | jq -R -n -r '
  reduce (inputs | fromjson? | select(.isSidechain != true)) as $r ({};
    if $r.type == "assistant" and ($r.message.usage | type) == "object"
       and $r.message.model != "<synthetic>" then
      ($r.message.usage) as $u
      | .ctx = (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0)
                + ($u.cache_read_input_tokens // 0))
      | .ts = $r.timestamp
      | if ($u.cache_creation.ephemeral_1h_input_tokens // 0) > 0 then .ttl = 3600
        elif ($u.cache_creation.ephemeral_5m_input_tokens // 0) > 0 then .ttl = 300
        else . end
    elif $r.subtype == "compact_boundary" then
      .ctx = ($r.compactMetadata.postTokens // 0) | .ts = $r.timestamp
    else . end)
  | [(.ctx // 0),
     ((.ts // "") | sub("\\.[0-9]+"; "") | (fromdateiso8601? // 0)),
     (.ttl // 0)]
  | map(tostring) | join(" ")')

[[ ${ctx:-} =~ ^[0-9]+$ && $ctx -gt 0 ]] || exit 0

case $event in
  Stop)
    thresholds=""
    for t in ${COMPACT_NUDGE_THRESHOLDS:-150k 250k 400k}; do
      t=$(to_tokens "$t") && [[ -n $t ]] && thresholds="$thresholds $t"
    done
    level=0 crossed=0 i=0
    for t in $(printf '%s\n' $thresholds | sort -n); do
      i=$((i + 1))
      if ((ctx >= t)); then level=$i crossed=$t; fi
    done

    stored=$(cat "$state.level" 2>/dev/null)
    [[ $stored =~ ^[0-9]+$ ]] || stored=0
    # Written on the way down too, so a threshold fires again after a compaction.
    echo "$level" >"$state.level"
    ((level > stored)) || exit 0

    msg="Context passed $(human "$crossed") tokens ($(human "$ctx") now), and every request re-reads all of it."
    msg="$msg Task done: /clear. Still on it: /compact at the next pause, naming what to keep."
    jq -n --arg m "$msg" '{systemMessage: $m}'
    ;;

  UserPromptSubmit)
    mode=${COMPACT_NUDGE_COLD_MODE:-block}
    [[ $mode == off ]] && exit 0
    # Slash commands include the very /compact and /clear this nudges toward.
    [[ $prompt_head == / ]] && exit 0

    min=$(to_tokens "${COMPACT_NUDGE_COLD_MIN:-100k}")
    [[ -n $min ]] && ((ctx >= min)) || exit 0
    [[ $last_ts =~ ^[0-9]+$ && $last_ts -gt 0 ]] || exit 0

    override=$(to_seconds "${COMPACT_NUDGE_CACHE_TTL:-}")
    if [[ -n $override ]]; then ttl=$override
    elif ! [[ $ttl =~ ^[0-9]+$ && $ttl -gt 0 ]]; then ttl=3600
    fi

    idle=$(($(date +%s) - last_ts))
    ((idle > ttl)) || exit 0
    # One nudge per cold episode: sending the prompt again goes through.
    [[ $(cat "$state.cold" 2>/dev/null) == "$last_ts" ]] && exit 0
    echo "$last_ts" >"$state.cold"

    if ((idle >= 3600)); then away="$((idle / 3600))h$(printf '%02d' $((idle % 3600 / 60)))"
    else away="$((idle / 60))min"; fi
    msg="Idle for $away, past the $((ttl / 60))-minute cache lifetime: the next request rewrites all $(human "$ctx") tokens of context to the cache."
    msg="$msg New task: /clear. Same task: /compact first, so only the summary is rewritten."

    if [[ $mode == warn ]]; then
      jq -n --arg m "$msg" '{systemMessage: $m}'
    else
      jq -n --arg m "$msg Or send the prompt again to go ahead as is." \
        '{decision: "block", reason: $m}'
    fi
    ;;
esac
exit 0
