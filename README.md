# Duel — Prototype Katana (Godot 4)

FPS de mêlée « Japon médiéval fantasy ». Phase 1 en cours.

## Lancer le jeu

1. Installe **Godot 4.3 ou plus récent**, version **Standard** (pas .NET) : https://godotengine.org/download
   (c'est un simple fichier à décompresser, pas d'installation).
2. Télécharge ce projet : sur GitHub, choisis la branche `claude/execute-prompt-instructions-4f5g4q`,
   puis bouton vert **Code → Download ZIP**, et décompresse-le.
3. Lance Godot → **Importer** → choisis le fichier `project.godot` du dossier → **Importer et éditer**.
4. Appuie sur **F5** (ou le bouton ▶ en haut à droite) pour jouer.
5. Écran titre :
   - **Duel** : contre l'IA (Facile / Normal / Difficile), 2 rounds gagnants.
   - **1 contre 1** : local en écran partagé, le Joueur 2 joue à la **manette**.
   - **DEBUG › Bac à sable** : mannequin, frame data, hitbox (sera supprimé à la fin).
   **Échap** (ou Start) = pause.

### Manette (Joueur 2)
Stick gauche : déplacement et manips · Stick droit : visée · **RT** lame · **RB** pommeau · **LT** garde/parry · **LB** dash · **A** saut · **B** accroupi · **X** changer de garde · **Y** potion · **R3** burst · **Croix haut** provocation · **Start** pause.

### Manips (minimum 3 directions)
236 / 214 (quarts de cercle), 623 / 421 (demi-lunes), 41236 / 63214 (demi-cercles). Réglables dans `combat.json > input > motions`.

## Touches (AZERTY par défaut, modifiables dans `data/config/controls.json`)

| Action | Touche |
|---|---|
| Se déplacer | Z Q S D |
| Sauter | Espace |
| S'accroupir | Ctrl |
| Dash | Shift + direction |
| Changer de garde | A |
| Lame / Pommeau | Clic gauche / Clic droit |
| Garde (maintenir) / Parry (appui au bon moment) | E |
| Burst (pendant un combo subi) | F |
| Potion / Provocation | R / T |
| Mode du mannequin | F2 |
| Filtre rétro | F7 |
| Liste de coups | Tab |
| Debug | F1 |
| Recharger les fichiers de données | F6 |
| Libérer la souris | Échap (clic pour reprendre) |

## Rythme : lent puis très rapide

- Les attaques sont **lentes et lisibles** : un **reflet** brille sur la lame adverse juste avant le coup.
- **Tout s'annule** avec le **Ki 気** (jauge blanche) : dash pendant un dash, dash pendant une attaque (feinte/fuite), attaque pendant une attaque ou un dash. Coûts réglables dans `combat.json > cancel` (0 = gratuit).
- Images rémanentes pendant les dashs et les annulations.

## Le Katana — « La Voie du sabre »

- **Posture Iai** (421 LAME maintenu) : reste rengainé pour charger, relâche pour dégainer. En posture, une attaque LAME de face déclenche un contre automatique ; le POMMEAU adverse casse la posture.
- **Zanshin 残心** (3 points) : gagné par parry, counter-hit, punish et contre en posture ; perdu quand on se fait counter. 1 point : **A** pendant un coup qui a touché/été bloqué = annule sa recovery (et change de garde). 3 points : relâcher le Iai = **Issen 一閃**.
- **Tranchant 刃** : la lame s'émousse (et se tache) quand elle est bloquée ou parée ; le **Chiburi** (63214 LAME) la nettoie.

Réglages : `data/weapons/katana.json` > `mechanic` ; couleurs : `style`.

## Modifier les réglages soi-même

Tout est dans `data/` (fichiers texte JSON, à ouvrir avec le Bloc-notes ou VS Code) :
- `data/config/combat.json` : vitesses, saut, dash, durée du changement de garde… (durées en ticks : 60 = 1 seconde)
- `data/config/controls.json` : les touches
- `data/weapons/katana.json` : la frame data du katana (startup/active/recovery, dégâts, hitbox, déplacements…)

Modifie, sauvegarde, puis appuie sur **F6** en jeu : les changements s'appliquent sans relancer.
Si le JSON contient une faute (virgule oubliée…), l'erreur s'affiche en bas de Godot et les anciens réglages sont gardés.

## Structure

```
data/        ← les données modifiables (JSON)
src/sim/     ← la simulation à 60 ticks (logique pure, déterministe, aucun visuel)
               motion_parser.gd = lecture des manips, combat.gd = hitbox/hurtbox
src/input/   ← clavier/souris → InputFrame ; mannequin / IA
src/view/    ← tout ce qui se voit : caméra, bras, arène, combattants
src/ui/      ← HUD, liste des coups ; src/ui/menus/ = écrans (titre, armes, maps, options, pause)
src/debug/   ← TOUT ce qui est propre au mode debug (mannequin, hitbox, frame bar) : à supprimer à la fin
data/maps/   ← les maps (une par fichier JSON, symétrie automatique)
data/roster.json ← armes et classes secondaires affichées à l'écran de sélection
src/app.gd   ← écrans et lancement des combats ; src/game.gd = un combat
```

## Avancement Phase 1

- [x] Étape 1 : arène, boucle 60 ticks, déplacement, saut, accroupi, dash, changement de garde
- [x] Étape 2 : moteur de coups (JSON), lecture des inputs 236/623…, mode debug (historique d'inputs, frame data, hitbox), mannequin, liste de coups
- [x] Étape 3 (en partie) : les 20 coups du katana en version de base
- [ ] Étape 3 (reste) : charge du Iai, feinte, contre dos tourné, sang à l'écran, overhead
- [x] Étape 4 (en partie) : garde, parry parfait, guard break, jauge de garde, burst, counter-hit, scaling des combos, mannequin d'entraînement
- [x] Étape 3 et 4 terminées : contre dos tourné, clash/bind, potion, provocation
- [x] Duel contre l'IA (3 difficultés, rounds, intro, KO au ralenti), 1 contre 1 local en écran partagé
- [x] DA : persos en sprites 2D 8 directions, cel-shading, contour encre partout
- [x] Menus (titre, armes + classe secondaire, maps, options, pause), 6 maps à thème + 1 de debug, filtres d'image au choix
- [ ] Étape 5 : game feel (hitstop, shake, sons, intro, coup final)
- [ ] Étape 6 : IA (barres de vie et liste de coups déjà là)
