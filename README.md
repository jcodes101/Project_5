# The Ashen Bough

A playable third-person dark fantasy roguelite made in **Godot 4.7.2**. Carry an ember through five combat arenas and four branching special rooms, then defeat Veyr, the Ashen King.

Combat uses deliberate attack commitments, stamina, dodge invulnerability, timed parries, lock-on, stagger, mastery finishers, and a special attack. Original low-poly models, generated pixel textures, fog, hard shadows, candlelight, and a restrained earthy palette follow the supplied art brief.

## Play

1. Import `project.godot` into Godot 4.7.2.
2. Press **F5** and choose **Begin the pilgrimage**.
3. Defeat the arena's enemies, collect drops with **E**, and walk through a lit doorway to choose your next room.

No asset downloads, plugins, Python packages, or external services are needed to play. The Compatibility renderer is enabled. The game targets a 1280 × 720 layout and scales with the window.

From a terminal with Godot on PATH:

```powershell
godot --path .
```

For a reproducible starting layout:

```powershell
godot --path . -- --seed=719
```

## Controls

| Input | Action |
| --- | --- |
| WASD / arrow keys | Move relative to camera |
| Mouse | Orbit camera |
| 1 / 2 / 3 / 4 | Equip sword / daggers / greatsword / spear |
| Q / middle mouse | Toggle target lock |
| Left click | Light attack; time repeated clicks to chain attacks |
| Right click | Heavy attack; breaks enemy poise |
| Space | Dodge; 15 stamina, 0.3 seconds of invulnerability |
| F | Parry; 10 stamina, 0.25-second timing window |
| R | Drink an Ember Draught |
| C | Weapon special after 50 mastery XP; 30 stamina |
| E | Collect loot / interact within 2 metres |
| Tab | Inventory: select, equip, use, or drop |
| Escape | Pause / close a menu |

Face an enemy to parry its impact. A successful parry staggers it for 1.5 seconds; hitting a staggered enemy deals bonus damage. Red rings warn of strikes. Leave pauses between attacks to recover stamina. Inventory and other menus pause combat.

## The run

- **Five main arenas, four crossroads.** Three biomes are shuffled for the first three encounters. Arena three includes a miniboss; arena four includes a boss; arena five holds the final boss. Clearing each of the first four arenas samples two distinct special rooms uniformly from Rest, Shop, and Mystery. Each type therefore has a 2/3 chance of being offered. Walk through one doorway to commit to that branch.
- **Three hazards.** Sepulchre grave mist pulses on and off; foundry cinders burn continuously; chapel blight deals damage and drains stamina. Layout details, hazard positions, enemy placements, branch choices, and rewards use the run's random seed.
- **Rest sites.** Choose one benefit: the sleeping bag heals 50% of maximum health, the campfire improves a chosen stat by 20%, or the workbench grants 20 XP to the equipped weapon. The exit remains available if you want to leave without resting.
- **Merchant.** Buy items for 100 / 125 / 150 / 175 / 200 embers according to rarity. Sell one item for 50% of its new price, rounded down. Equip another weapon before selling or dropping your current weapon. Merchant stock is replenishable during the visit.
- **Mystery.** Five equally likely outcomes: an extra ambush, a random 10% stat curse, loss of 25% currency or a carried item, a random 10% stat blessing, or a loot offering. An ambush does not count as a main arena.
- **Loot.** Regular enemies drop an item 60% of the time; minibosses and bosses always drop one. Normal rarity odds are 59 / 25 / 12 / 3 / 1 percent. Boss drops are rare or better. Enemy families have different loot pools. Embers are awarded directly; items require E to collect.
- **Inventory.** Twelve slots, one weapon per slot, other items stacked to five. Four weapon families match the brief's base damage ranges. Rarity improves damage or healing. Mastery is stored on each individual weapon: kills grant 5 XP, 25 XP unlocks a third-strike combo finisher, and 50 XP unlocks C. Specials cost 30 stamina and have weapon-specific cooldowns. Mastery Shards add 20 XP.
- **Win / lose.** Defeating the final boss wins. Zero vitality ends the run. Start a fresh run or retry the same seed from the result screen. There is no persistent progression or mid-run save.

## Project layout

| File | Responsibility |
| --- | --- |
| `game/game.tscn`, `game/game.gd` | Startup, run sequence, transitions, encounters, rewards, interactions, effects, audio |
| `game/run_state.gd` | Health, stats, currency, inventory, equipped weapon, mastery |
| `game/data.gd` | Weapon definitions, rarity rolls, loot pools, item prices |
| `game/knight.gd` | Third-person movement and camera, combat states, target lock |
| `game/foe.gd` | Enemy awareness, steering, two attack patterns per family, telegraphs, stagger, boss phases |
| `game/arena.gd` | Procedural room geometry, biome details, hazards, gates, rest props |
| `game/low_poly.gd` | Original mesh construction and deterministic pixel textures |
| `game/interface.gd` | Title, help, HUD, inventory, shop, rest, pause, results |
| `game/retro.gdshader` | Pixel sampling, subtle dithering, desaturation, vignette |
| `audio/`, `tools/generate_audio.py` | Original synthesized sound effects and looping ambience |
| `tests/` | Headless integration checks and rendered screenshot capture |

The earlier sprite prototype remains in `main.tscn`, `scripts/`, `sprites/`, and `resources/`. The new game is the project startup scene. Original mechanic notes are preserved in `docs/ORIGINAL_MECHANICS.md`; architecture and validation notes are in `docs/`.

## Validate

Open the project in Godot once to import assets, or import from the command line:

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/smoke_test.gd
```

The smoke test checks combat and input, loot probabilities, inventory boundaries, shop transactions, every mystery outcome, rest restrictions, main-path doorway transitions, victory, death, and restart. It uses direct damage to clear encounters during progression checks; it is not a balance or difficulty playthrough.

To render title, gameplay, inventory, shop, rest, result, and boss screenshots into the ignored `.godot/` directory:

```powershell
godot --path . --script res://tests/visual_check.gd
```

Optional: `python tools/generate_audio.py` recreates the included WAV assets using only Python's standard library. Menus use locally available system serif fonts with fallbacks; no proprietary font files are bundled.

## Weapon combat update

Every run starts with a sword, paired daggers, a greatsword, and a spear. Switch with 1?4 while idle. Each individual weapon keeps its own mastery. Before 25 XP, light combos have two hits; at 25 XP, the third hit unlocks. Press consecutive light inputs within 0.8 seconds; inputs near the end of a light attack can queue the next strike. At 50 XP, C unlocks that weapon's physical technique. Unlock notifications explain the controls.

| Weapon | Light hits | Heavy | Light / heavy stamina | Movement and roll slowdown | C special / cooldown |
| --- | --- | --- | --- | --- | --- |
| Sword | 10 / 10 / 15 | 20 | 15 / 30 | 5% | Riposte Stance: 35 counter damage / 10s |
| Daggers | 8 / 8 / 12 | 15 | 10 / 20 | None | Flurry Rush: five 6-damage strikes / 8s |
| Greatsword | 18 / 18 / 25 | 30 | 30 / 60 | 12% | Titan's Cleave: 45 damage / 12s |
| Spear | 10 / 10 / 14 | 18 | 20 / 40 | 10% | Spear Cyclone: 12 + 12 + 16 damage / 10s |

Base damage is modified by existing rarity, strength, and stagger bonuses. Guardbreaker staggers regular enemies for 2 seconds and minibosses/bosses for 1 second. Riposte Stance lasts one second and counters only if attacked. Heavy attacks commit through incoming damage; dagger flurries can be interrupted. Rolls use camera-relative directional input, or backward when no direction is held, with a 0.3-second invulnerability window and a centered, tucked visual rotation. The collision capsule remains upright.

Run `godot --headless --path . --script res://tests/combat_check.gd` for the focused weapon and roll checks.
