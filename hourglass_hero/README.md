# ⏳ Hourglass Hero

Un platformer où **tu es un sablier**. Le sable s'écoule en permanence — s'il
atteint 0, tu meurs. Chaque **saut** fait trois choses d'un coup :

1. **Retourne le sablier** — échange pur : `haut_nouveau = MAX − haut_ancien`.
   Le sable écoulé revient en haut, donc **plus tu attends avant de sauter, plus
   tu récupères de temps** ; sauter alors qu'il t'en reste beaucoup t'en laisse
   peu. Le sablier démarre à moitié, ce qui rend la boucle stable si tu sautes
   au bon moment.
2. **Change de plan** — chaque niveau existe en deux versions superposées
   (avant / arrière) avec des plateformes et monstres différents. Le saut te
   téléporte d'un plan à l'autre, **ta position ne change pas**. Tu peux atterrir
   sur une plateforme qui n'existe que dans l'autre plan… ou tomber dans le vide.
3. **Saut normal** — l'impulsion verticale classique.

Le sablier **tremble**, **rougeoie** et **transpire** quand le temps devient
critique : c'est ton signal pour sauter. La barre de sable en haut se vide
**dans le sens du plan courant** (vers la droite en plan avant, vers la gauche
en plan arrière) : elle s'inverse visiblement à chaque saut.

## La conséquence qui fait le jeu

Retourner deux fois = revenir au point de départ (`flip(flip(x)) = x`). Donc
**tu ne peux te recharger qu'en changeant réellement de plan**. Se recharger a
un **coût spatial** : il faut un sol qui existe dans l'autre plan. C'est de là
que viennent tous les puzzles.

Deux éléments cassent volontairement ce couplage :

- 🟢 **Ressort** — te propulse *sans* retourner le sable ni changer de plan
  (de la hauteur sans dépenser ton flip).
- 🟠 **Dalle-bascule** — retourne le sable *sans* saut ni changement de plan :
  le **seul** moyen de se recharger en restant dans le même plan.

## Les 6 niveaux

| # | Niveau | Ce qu'il enseigne |
| - | ------ | ----------------- |
| 1 | Réveil | Le sable descend ; sauter le retourne et change de plan |
| 2 | Le Vide | Traverser en alternant les plans à chaque saut |
| 3 | Le Ressort | Un gouffre infranchissable dans les deux plans → le ressort |
| 4 | La Fontaine | Sol en plan avant seulement : **sauter = mourir**, les dalles sont ta seule recharge |
| 5 | Parité | La sortie n'existe qu'en plan arrière → il faut un saut « à vide » pour corriger la parité |
| 6 | Minuit | Tout à la fois : plateforme mobile, monstre, tissage des plans |

## Jouer

Ouvre simplement **`index.html`** dans un navigateur (double-clic). Aucune
installation, aucun serveur, aucune dépendance.

- **← →** / **A D** : bouger
- **Espace** / **↑** / **W** : sauter (retourne le sable + change de plan)
- **R** : recommencer le niveau

Objectif : atteindre la **porte** dorée. 3 niveaux de difficulté croissante.

## Développement

Logique pure (physique, sablier, collisions) isolée dans `js/engine.js`, sans
DOM ni Canvas — donc testable directement.

```bash
node --test        # tests unitaires du moteur
```

### Structure

| Fichier          | Rôle                                                    |
| ---------------- | ------------------------------------------------------- |
| `index.html`     | page + inclusion des scripts + aide                     |
| `css/style.css`  | mise en page                                            |
| `js/config.js`   | couleurs (rendu)                                        |
| `js/engine.js`   | constantes gameplay + logique pure (testée)             |
| `js/levels.js`   | données des 3 niveaux (plateformes/monstres par plan)   |
| `js/game.js`     | input, boucle rAF, rendu, effets du sablier             |
| `tests/`         | tests `node --test`                                     |

### Régler la difficulté

Tout est dans l'objet `C` en haut de `js/engine.js` :

- `SAND_MAX` / `SAND_START` : durée totale du sable et remplissage de départ.
- `SAND_FLIP_BASE` : socle de recharge ajouté à chaque flip. `0` = mode sablier
  pur (un saut prématuré ne redonne presque rien).
- `GRAVITY`, `JUMP_V`, `MOVE_SPEED` : feeling du saut et du déplacement.
