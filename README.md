# Duel — Prototype Katana (Godot 4)

FPS de mêlée « Japon médiéval fantasy ». Phase 1 en cours.

## Lancer le jeu

1. Installe **Godot 4.3 ou plus récent**, version **Standard** (pas .NET) : https://godotengine.org/download
   (c'est un simple fichier à décompresser, pas d'installation).
2. Télécharge ce projet : sur GitHub, choisis la branche `claude/execute-prompt-instructions-4f5g4q`,
   puis bouton vert **Code → Download ZIP**, et décompresse-le.
3. Lance Godot → **Importer** → choisis le fichier `project.godot` du dossier → **Importer et éditer**.
4. Appuie sur **F5** (ou le bouton ▶ en haut à droite) pour jouer.

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
| Potion / Provocation | R / T *(à venir)* |
| Mode du mannequin | F2 |
| Filtre rétro | F7 |
| Liste de coups | Tab |
| Debug | F1 |
| Recharger les fichiers de données | F6 |
| Libérer la souris | Échap (clic pour reprendre) |

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
src/ui/      ← HUD, debug
src/main.gd  ← assemble le tout
```

## Avancement Phase 1

- [x] Étape 1 : arène, boucle 60 ticks, déplacement, saut, accroupi, dash, changement de garde
- [x] Étape 2 : moteur de coups (JSON), lecture des inputs 236/623…, mode debug (historique d'inputs, frame data, hitbox), mannequin, liste de coups
- [x] Étape 3 (en partie) : les 20 coups du katana en version de base
- [ ] Étape 3 (reste) : charge du Iai, feinte, contre dos tourné, sang à l'écran, overhead
- [x] Étape 4 (en partie) : garde, parry parfait, guard break, jauge de garde, burst, counter-hit, scaling des combos, mannequin d'entraînement
- [ ] Étape 4 (reste) : clash/bind, potion, provocation
- [ ] Étape 5 : game feel (hitstop, shake, sons, intro, coup final)
- [ ] Étape 6 : IA (barres de vie et liste de coups déjà là)
