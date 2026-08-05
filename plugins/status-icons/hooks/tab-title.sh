#!/usr/bin/env bash
# Préfixe l'onglet du terminal d'une icône disant ce que Claude attend de toi.
#
# Claude Code écrit lui-même le titre en OSC 0, préfixé par ⠂/⠐ tant qu'il
# travaille et par ✳ dès qu'il s'arrête. Il ne réécrit que lorsque la valeur
# change : hors état « busy » il n'écrit qu'une fois, donc ce script peut poser
# un préfixe plus parlant qui tiendra. Rien à nettoyer — Claude reprend la main
# au prochain changement d'état, c'est-à-dire exactement quand le marqueur doit
# disparaître.
#
# Pendant le travail, à l'inverse, Claude réécrit toutes les 960 ms : aucun hook
# ne peut y tenir un « en cours ». Il n'y a rien à tenter de ce côté.
#
# Tout échec est silencieux : sur un terminal qu'on ne sait pas atteindre, ou si
# l'état interne lu ici change de forme, le script ne fait rien et Claude garde
# ses propres icônes.

set -u

payload=$(cat)
{
  read -r event
  read -r session_id
  read -r cwd
} < <(printf '%s' "$payload" | jq -r '.hook_event_name // "", .session_id // "", .cwd // ""')

# <config>/sessions/<pid>.json est l'état que Claude tient pour lui-même : le
# nom de topic affiché dans l'onglet, le pid dont la sortie standard est le
# terminal, et le waitingFor qui dit *pourquoi* il attend. C'est un détail
# d'implémentation non documenté — d'où le repli silencieux partout ici.
sessions_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions"
session_file=$(jq -r --arg id "$session_id" \
  'select(.sessionId == $id) | input_filename' \
  "$sessions_dir"/*.json 2>/dev/null | head -n1)

# Laisser Claude finir d'écrire son titre pour ce changement d'état, et le
# fichier de session se mettre à jour, avant de lire puis d'écraser. StopFailure
# passe après Stop, pour gagner au cas où les deux se déclenchent.
case $event in
  Stop | Notification) sleep 0.4 ;;
  StopFailure) sleep 0.9 ;;
esac

pid=""
title=""
waiting_for=""
if [[ -n ${session_file:-} ]]; then
  {
    read -r pid
    read -r title
    read -r waiting_for
  } < <(jq -r '.pid // "", .name // "", .waitingFor // ""' "$session_file" 2>/dev/null)
fi

case $event in
  Stop) prefix="✅ " ;;
  StopFailure) prefix="❌ " ;;
  # L'onglet redevient un shell : ni icône ni nom de topic, juste le dossier.
  SessionEnd)
    prefix=""
    title=""
    ;;
  Notification)
    case $waiting_for in
      # Pas de waitingFor : rien ne bloque, c'est la relance après inactivité.
      # Laisser en place le marqueur de fin de tour.
      "") exit 0 ;;
      "permission prompt") prefix="🔐 " ;;
      "input needed") prefix="❓ " ;;
      "sandbox request") prefix="🧱 " ;;
      "worker request") prefix="🤖 " ;;
      "dialog open") prefix="💤 " ;;
      *) prefix="❓ " ;;
    esac
    ;;
  *) exit 0 ;;
esac

# Le hook n'a pas de terminal de contrôle : viser la sortie standard de Claude.
# /proc sous Linux, lsof ailleurs — macOS n'a pas de /proc.
resolve_tty() {
  local target
  [[ -n ${1:-} ]] || return 1
  target=$(readlink "/proc/$1/fd/1" 2>/dev/null) ||
    target=$(lsof -a -p "$1" -d 1 -F n 2>/dev/null | sed -n 's/^n//p' | head -n1)
  case $target in
    /dev/pts/* | /dev/tty*) printf '%s' "$target" ;;
    *) return 1 ;;
  esac
}

# En fin de session le fichier a pu disparaître ; le parent du hook est alors le
# seul chemin restant vers le terminal.
tty_path=$(resolve_tty "$pid") || tty_path=$(resolve_tty "$PPID") || exit 0

[[ -n $title ]] || title=$(basename "$cwd")
[[ -n $title ]] || title="Claude Code"
title=${title//[[:cntrl:]]/}

printf '\033]0;%s%s\007' "$prefix" "$title" >"$tty_path" 2>/dev/null || true
