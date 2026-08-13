# assets

Branche orpheline pour les images référencées par les README des plugins — pas de commit commun
avec `main`, pas d'historique partagé. `claude plugin marketplace add` ne fetch que
`refs/heads/main` : rien ici n'est jamais cloné, donc rien ici n'est jamais livré par
`marketplace add` ou par `plugin install`. Voir la discussion dans
[l'issue #8](https://github.com/Malo-T/claude-toolbelt/issues/8).

## Convention

- Un fichier sous `images/`, nommé `<plugin>-<sujet>.png` (ex. `status-icons-tabs.png`).
- Référencé depuis un README de `main` en URL absolue, jamais en chemin relatif :

  ```md
  ![description](https://raw.githubusercontent.com/Malo-T/claude-toolbelt/assets/images/status-icons-tabs.png)
  ```

  Un chemin relatif résoudrait vers `main`, où le fichier n'existe pas.
- Un README qui référence une image ici documente laquelle dans sa propre section, pour qu'un
  renommage ou une suppression sur cette branche reste traçable depuis `main`.
