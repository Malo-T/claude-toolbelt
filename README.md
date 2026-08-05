# session-status

Claude Code ne dit pas grand-chose de lui-même quand on ne le regarde pas. Le titre de l'onglet est
préfixé d'un point d'animation tant qu'il travaille et d'un `✳` dès qu'il s'arrête — mais « j'ai
fini » et « je suis bloqué sur une demande de permission » produisent la même étoile. Dans une
rangée d'onglets, rien ne dit lequel te réclame.

Ce dépôt publie deux modules indépendants qui comblent ça, chacun sur son canal.

| Module | Canal |
|---|---|
| [`status-icons`](plugins/status-icons) | une icône dans l'onglet du terminal |
| [`status-sounds`](plugins/status-sounds) | un son court |

Ils sont séparés parce qu'ils ne se valent pas à l'usage : les icônes ne coûtent rien et se prennent
partout, le son est intrusif en open space. Installer l'un n'oblige pas à prendre l'autre.

## status-icons

| État | Onglet |
|---|---|
| Tour terminé | ✅ *topic* |
| Tour terminé en erreur | ❌ *topic* |
| Demande de permission | 🔐 *topic* |
| Question posée | ❓ *topic* |
| La sandbox demande une sortie | 🧱 *topic* |
| Un worker demande quelque chose | 🤖 *topic* |
| Session en pause | 💤 *topic* |
| Session terminée | *dossier*, sans préfixe |

**Pas d'icône « en cours de travail ».** Ce n'est pas un oubli : tant que Claude est à l'état `busy`
il réécrit le titre toutes les 960 ms, en alternant deux caractères braille. N'importe quel hook qui
écrirait pendant ce temps serait effacé en moins d'une seconde. Le titre n'appartient à autre chose
que Claude qu'entre les tours, et c'est exactement le créneau que ce module occupe.

Corollaire utile : il n'y a rien à nettoyer. Claude reprend la main sur le titre au prochain
changement d'état — c'est-à-dire à la seconde où le marqueur doit disparaître.

**Rien non plus sur la relance après inactivité.** Cette notification part alors que rien ne bloque :
Claude a fini, c'est toi qui es parti. Le `✅` du tour précédent est laissé en place plutôt que
remplacé par un faux « on t'attend ».

## status-sounds

| État | Son |
|---|---|
| Tour terminé | `complete` / `Glass.aiff` |
| Tour terminé en erreur | `dialog-warning` / `Basso.aiff` |
| Attente d'une action de ta part | `message-new-instant` / `Ping.aiff` |

Trois sons là où les icônes distinguent sept états : à l'oreille, la seule question utile est « dois-je
revenir ? ». Le détail se lit sur l'onglet une fois qu'on y est.

Contrairement aux icônes, le son part aussi sur la relance après inactivité — c'est justement le cas
où il sert le plus, puisque tu n'es pas devant.

Le thème sonore Linux se change par `SESSION_STATUS_SOUND_THEME`, qui pointe sur un dossier
contenant `complete.oga`, `dialog-warning.oga` et `message-new-instant.oga`. Par défaut, le thème
freedesktop.

## Installation

Ce dépôt est sa propre marketplace. Tant qu'il n'est pas publié, l'ajouter par chemin :

```sh
claude plugin marketplace add ~/workspace/claude/session-status
claude plugin install status-icons@session-status
claude plugin install status-sounds@session-status   # optionnel
```

Une fois poussé sur GitHub, la première commande prend le raccourci
(`claude plugin marketplace add Malo-T/session-status`). Il en faut de toute façon deux :
`claude plugin install` ne résout les noms que contre des marketplaces déjà configurées.

Actifs à la session suivante. Rien à configurer.

## Prérequis et portabilité

- **`jq`** dans le `PATH`, pour les deux modules.
- **status-icons** : un terminal qui affiche le titre OSC 0 dans son onglet — c'est le cas de la
  plupart (Ptyxis, GNOME Terminal, Konsole, kitty, Ghostty, WezTerm, Alacritty, Windows Terminal…).
  Linux ou macOS : un hook n'a pas de terminal de contrôle, il faut donc viser la sortie standard du
  process Claude, via `/proc/<pid>/fd/1` sous Linux et `lsof` en repli ailleurs.
- **status-sounds** : `canberra-gtk-play`, `paplay` ou `aplay` sous Linux, `afplay` sous macOS.

Quand une de ces conditions manque, le script concerné sort sans rien faire. Aucun message, aucun
ralentissement, et Claude garde son comportement d'origine. Les deux scripts sont écrits pour bash
3.2, la version que macOS livre encore.

## Sur quoi reposent les icônes

L'état vient de `~/.claude/sessions/<pid>.json`, que Claude Code tient à jour pour lui-même : il y
écrit son statut (`idle`, `busy`, `waiting`, `shell`), le champ `waitingFor` qui dit *pourquoi* il
attend, et le nom de topic affiché dans l'onglet.

C'est un détail d'implémentation non documenté, vérifié sur Claude Code **2.1.222**. Il peut changer
de forme sans préavis. Le script est écrit pour que ça reste sans conséquence : un champ absent ou
renommé le fait sortir en silence, et une valeur de `waitingFor` inconnue retombe sur `❓` plutôt que
de ne rien afficher.

Les icônes sont toutes emoji par défaut, sans sélecteur de variante `U+FE0F` : celui-ci est rendu de
façon inégale d'un terminal à l'autre et donne parfois un glyphe monochrome étroit, voire un carré,
au milieu d'un jeu coloré. C'est pourquoi on trouve ici `❌` et non `⚠️`, `💤` et non `⏸️`.

## Modifier les jeux d'icônes et de sons

Tout tient dans les `case` de `plugins/status-icons/hooks/tab-title.sh` et
`plugins/status-sounds/hooks/play.sh`, en clair. Côté icônes, la table `waitingFor → préfixe` couvre
l'ensemble des valeurs que Claude produit ; en ajouter une nouvelle est une ligne.

Attention en développement : `claude plugin install` **copie** le dépôt dans `~/.claude/plugins/cache/`.
Une modification ici reste sans effet tant que `claude plugin marketplace update session-status` n'a
pas été lancé.

## Licence

MIT
