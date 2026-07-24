# Hourglass Hero — Design MVP

## Concept
Un platformer où le joueur EST un sablier. Une jauge de sable s'écoule en
permanence ; à 0, mort. La particularité : **chaque saut fait 3 choses
simultanément** :

1. **Retourne le sablier** — le temps se recharge de façon *proportionnelle* :
   le sable déjà écoulé revient « en haut ». Plus tu attends avant de sauter,
   plus tu récupères de temps. Sauter trop tôt ne recharge presque rien.
2. **Change de plan** — chaque niveau existe en deux versions superposées
   (avant-plan / arrière-plan) avec des plateformes et monstres différents.
   Le saut te téléporte d'un plan à l'autre, **ta position (x,y) reste
   identique**. Tu peux atterrir sur une plateforme qui n'existe que dans
   l'autre plan… ou tomber dans le vide.
3. **Saut physique normal** — impulsion verticale pour franchir trous/monstres.

## Boucle de jeu
- Bouger gauche/droite, sauter (= flip + switch plan).
- Gérer la jauge de sable : sauter au bon moment pour rester en vie.
- Éviter monstres (contact = mort) et trous (chute = mort).
- Atteindre la **porte de sortie** → niveau suivant.
- Mort → restart du niveau courant.

## Modèle du sablier (règle exacte)
- `SAND_MAX` = sable total (6000 ms) ; `SAND_START` = sable au départ (3000 ms,
  soit à moitié).
- `sand` diminue de `dt` chaque frame. À `sand <= 0` → mort.
- Au saut : échange pur `sand = SAND_MAX - sand` (le sable écoulé revient en
  haut). Donc :
  - Sauter presque à sec → recharge quasi pleine.
  - Sauter alors qu'il reste beaucoup → tu te retrouves avec peu de temps.
- **Décision d'implémentation (départ à moitié)** : partir à `SAND_MAX` rendait
  le tout premier saut mortel (plein → vide) et les sauts rapprochés
  s'auto-affamaient. Partir à la moitié stabilise la boucle : tout saut fait
  quand `sand ≤ moitié` renvoie au-dessus de la moitié. `SAND_FLIP_BASE`
  (socle de recharge) reste à `0` = modèle sablier pur ; le relever adoucirait
  le timing si besoin.
- Visuel : deux triangles (ampoules haut/bas), le sable haut se vide vers le bas.
  Un flip anime l'inversion. Couleur du sable → orange, vire au rouge sous seuil.

## Contenu
- 3 niveaux, difficulté croissante.
- Monstres : patrouille horizontale entre deux bornes, tuent au contact.
- Plateformes mobiles : va-et-vient (horizontal ou vertical).
- Chaque plateforme/monstre appartient à UN plan (avant ou arrière).
- Sol + murs partagés ou par-plan selon le niveau.

## Rendu / graphismes (simples)
- Avant-plan : couleurs vives, pleine saturation.
- Arrière-plan : mêmes formes mais désaturées/assombries + léger flou de teinte,
  pour qu'on lise immédiatement dans quel plan on est.
- Formes géométriques uniquement (rectangles plateformes, sablier = 2 triangles).
- HUD : jauge de sable en haut, numéro de niveau, indicateur de plan.

## Architecture technique
- Vanilla JS + Canvas 2D. **Aucune dépendance, aucun build.**
- Scripts classiques (pas d'ES modules) → fonctionne en `file://` direct.
- Fichiers :
  - `index.html` — canvas + inclusion des scripts + HUD/hint.
  - `css/style.css` — mise en page sombre.
  - `js/config.js` — constantes (dimensions, gravité, SAND_MAX, couleurs).
  - `js/levels.js` — données des 3 niveaux (plateformes/monstres par plan, spawn, porte).
  - `js/engine.js` — physique joueur, sablier, entités, collisions AABB, update pur.
  - `js/game.js` — état global, boucle rAF, input clavier, états (play/dead/win), rendu.
- `tests/engine.test.js` — teste la logique pure du sablier (flip proportionnel,
  mort à 0) et la collision AABB, via `node --test`. Le code testable est exposé
  sur `globalThis` sous garde `typeof module`/environnement.

## Contrôles
- Flèches / A-D : déplacement horizontal.
- Espace / W / Flèche haut : saut (flip + switch plan).
- R : restart niveau.

## Découpage des unités
- `engine.js` = pur (pas de DOM/Canvas), déterministe, testable.
- `game.js` = I/O (input, rAF, rendu), s'appuie sur `engine`.
- `levels.js` = données seulement.

## Non-inclus (YAGNI pour le MVP)
- Sons, sprites, animations élaborées, sauvegarde, menus, mobile/touch.
