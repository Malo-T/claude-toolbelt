#!/usr/bin/env bash
# Joue un son court quand Claude a fini, a échoué, ou attend quelque chose de
# toi — pour lever les yeux au bon moment sans surveiller l'onglet.
#
# Trois sons seulement, là où le module status-icons distingue sept états : à
# l'oreille, la seule question utile est « dois-je revenir ? ». Le détail se lit
# sur l'onglet une fois qu'on y est.
#
# Tout échec est silencieux — pas de lecteur audio, pas de fichier son, système
# inconnu : le script sort sans rien dire.
#
# Écrit pour bash 3.2, la version que macOS livre encore : ni tableau associatif
# ni substitution de casse ici.

set -u

event=$(jq -r '.hook_event_name // ""')

case $event in
  Stop) key=done ;;
  StopFailure) key=error ;;
  Notification) key=attention ;;
  *) exit 0 ;;
esac

# macOS n'a pas le thème sonore freedesktop, et Linux n'a pas /System/Library.
case $(uname -s) in
  Darwin)
    case $key in
      done) sound=/System/Library/Sounds/Glass.aiff ;;
      attention) sound=/System/Library/Sounds/Ping.aiff ;;
      error) sound=/System/Library/Sounds/Basso.aiff ;;
    esac
    ;;
  *)
    theme=${SESSION_STATUS_SOUND_THEME:-/usr/share/sounds/freedesktop/stereo}
    case $key in
      done) sound="$theme/complete.oga" ;;
      attention) sound="$theme/message-new-instant.oga" ;;
      error) sound="$theme/dialog-warning.oga" ;;
    esac
    ;;
esac

[[ -r $sound ]] || exit 0

# canberra respecte le thème sonore du bureau ; les autres sont des replis.
if command -v canberra-gtk-play >/dev/null 2>&1; then
  canberra-gtk-play -f "$sound" >/dev/null 2>&1
elif command -v afplay >/dev/null 2>&1; then
  afplay "$sound" >/dev/null 2>&1
elif command -v paplay >/dev/null 2>&1; then
  paplay "$sound" >/dev/null 2>&1
elif command -v aplay >/dev/null 2>&1; then
  aplay -q "$sound" >/dev/null 2>&1
fi

exit 0
