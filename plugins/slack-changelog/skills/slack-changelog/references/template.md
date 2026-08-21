# Default template

The fixed gabarit for a Slack changelog post. Copy it as-is; only the bracketed parts vary.

```
:mega: <projet ou produit> — nouveautés côté <thème>

• :emoji: <bullet courte, une idée par puce, ton oral>
• :emoji: <bullet courte, une idée par puce, ton oral>

<phrase d'action pratique si applicable, sinon supprimer le bloc entier> :slightly_smiling_face:
@channel
```

## What each part is for

- **Title line.** `:mega:` always opens it. Name the product only if the channel covers more
  than one; drop it when the channel is already product-specific. The theme is a functional area
  (Step 3 of the skill), never a repo name.
- **Bullets.** One idea each, one emoji each (Steps 4 and 5), no code vocabulary. Order them by
  what a reader would care about most, not by repo or by commit order.
- **Closing line.** Include it only when Step 6 found something the reader needs to do. Omit the
  whole block, blank line included, when there's nothing to act on: a message that's all bullets
  and a mention is a normal, complete post.
- **Channel-wide mention.** Always present, always last. `@channel` is the placeholder here;
  swap it for whatever convention the workspace actually uses (`@here`, a named group). Check for
  a project override at `.claude/slack-changelog-template.md` before assuming this one.

## A filled example

```
:mega: Nouveautés côté connexion

• :lock: La connexion redemande moins souvent le mot de passe : la session tient désormais
  toute la journée
• :bug: Le bouton « mot de passe oublié » fonctionnait mal sur mobile, c'est corrigé
• :zap: La page de connexion s'affiche plus vite, surtout sur les connexions lentes

Rien à faire de votre côté, le changement est déjà en place :slightly_smiling_face:
@channel
```
