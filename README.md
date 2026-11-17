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
| Lame / Pommeau | Clic gauche / Clic droit *(étape 2)* |
| Parry / Potion / Provocation | E / R / T *(étape 4)* |
| Liste de coups | Tab *(étape 6)* |
| Debug | F1 |
| Recharger les fichiers de données | F6 |
| Libérer la souris | Échap (clic pour reprendre) |

## Modifier les réglages soi-même

Tout est dans `data/` (fichiers texte JSON, à ouvrir avec le Bloc-notes ou VS Code) :
- `data/config/combat.json` : vitesses, saut, dash, durée du changement de garde… (durées en ticks : 60 = 1 seconde)
- `data/config/controls.json` : les touches
- `data/weapons/` : la frame data des armes *(à partir de l'étape 2)*

Modifie, sauvegarde, puis appuie sur **F6** en jeu : les changements s'appliquent sans relancer.
Si le JSON contient une faute (virgule oubliée…), l'erreur s'affiche en bas de Godot et les anciens réglages sont gardés.

## Structure

```
data/        ← les données modifiables (JSON)
src/sim/     ← la simulation à 60 ticks (logique pure, déterministe, aucun visuel)
src/input/   ← clavier/souris → InputFrame ; mannequin / IA
src/view/    ← tout ce qui se voit : caméra, bras, arène, combattants
src/ui/      ← HUD, debug
src/main.gd  ← assemble le tout
```

## Avancement Phase 1

- [x] Étape 1 : arène, boucle 60 ticks, déplacement, saut, accroupi, dash, changement de garde
- [ ] Étape 2 : moteur de coups (JSON), lecture des inputs 236/623…, mode debug complet, mannequin
- [ ] Étape 3 : les 10 coups du katana (lame + pommeau)
- [ ] Étape 4 : parry, clash/bind, potion, provocation
- [ ] Étape 5 : game feel (hitstop, shake, sons, intro, coup final)
- [ ] Étape 6 : IA, barre de vie, liste de coups
