# tab-status

Claude Code préfixe le titre de l'onglet du terminal par un point d'animation tant qu'il travaille,
et par `✳` dès qu'il s'arrête. Le problème est que « j'ai fini » et « je suis bloqué sur une demande
de permission » produisent exactement la même étoile : dans une rangée d'onglets, rien ne dit lequel
te réclame.

Ce plugin remplace ce préfixe par une icône qui dit ce que Claude attend.

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

## Ce qu'il ne fait pas

**Pas d'icône « en cours de travail ».** Ce n'est pas un oubli : tant que Claude est à l'état `busy`
il réécrit le titre toutes les 960 ms, en alternant deux caractères braille. N'importe quel hook qui
écrirait pendant ce temps serait effacé en moins d'une seconde. Le titre n'appartient à autre chose
que Claude qu'entre les tours, et c'est exactement le créneau que ce plugin occupe.

Corollaire utile : il n'y a rien à nettoyer. Claude reprend la main sur le titre au prochain
changement d'état — c'est-à-dire à la seconde où le marqueur doit disparaître.

**Rien non plus sur la relance après inactivité.** Cette notification part alors que rien ne bloque :
Claude a fini, c'est toi qui es parti. Le `✅` du tour précédent est laissé en place plutôt que
remplacé par un faux « on t'attend ».

## Installation

Ce dépôt est sa propre marketplace — il porte un `.claude-plugin/marketplace.json` qui pointe sur le
plugin à la racine. Tant qu'il n'est pas publié, l'ajouter par chemin :

```sh
claude plugin marketplace add ~/workspace/claude/tab-status
claude plugin install tab-status@tab-status
```

Une fois poussé sur GitHub, les deux mêmes commandes prennent le raccourci
(`claude plugin marketplace add Malo-T/tab-status`). Dans les deux cas il en faut bien deux :
`claude plugin install` ne résout les noms que contre des marketplaces déjà configurées.

Actif à la session suivante. Rien à configurer.

## Prérequis et portabilité

- **`jq`** doit être dans le `PATH`.
- **Un terminal qui affiche le titre OSC 0** dans son onglet. C'est le cas de la plupart
  (Ptyxis, GNOME Terminal, Konsole, kitty, Ghostty, WezTerm, Alacritty, Windows Terminal…).
- **Linux ou macOS.** Un hook n'a pas de terminal de contrôle, il faut donc viser la sortie standard
  du process Claude : `/proc/<pid>/fd/1` sous Linux, `lsof` en repli ailleurs.

Sur un système où l'une de ces conditions manque, le script sort sans rien faire et Claude garde ses
icônes d'origine. Aucun message, aucun ralentissement.

## Sur quoi ça repose

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

## Modifier le jeu d'icônes

Tout tient dans les deux `case` de `hooks/tab-title.sh`, en clair. La table `waitingFor → préfixe`
couvre l'ensemble des valeurs que Claude produit ; en ajouter une nouvelle est une ligne.

## Licence

MIT
