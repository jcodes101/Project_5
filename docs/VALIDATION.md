# Validation

## Weapns / main integration (2026-11-13)

Merged origin/main `3527e4f` into Weapns, retaining the weapon controller, data,
mastery, stamina, cooldowns, switching, and procedural attack/roll animations.
Main's goblin encounters, final boss, standalone scenes, assets, and tests remain
integrated. Goblin movement now consumes the inherited weapon knockback.

Verified with Godot 4.7.2 on Windows:

- Headless editor import completed; all 69 GDScript files passed `--check-only`.
- `tests/combat_check.gd`: 2,346 checks, zero failures.
- `tests/smoke_test.gd`: 98 checks, zero failures, including main's goblin
  encounter counts and final boss progression. Inventory/stamina expectations
  account for the four starting weapons and weapon-specific costs.
- `tests/goblin_smoke.gd` and `tests/goblin_boss_smoke.gd`: passed.
- `tests/weapon_goblin_integration.gd`: 12 checks, zero failures, covering weapon
  knockback, rank-aware guardbreaker, and sword riposte on goblins and the boss.
- `tests/visual_check.gd`: captured all eight screens with OpenGL Compatibility;
  gameplay and boss captures were inspected.
- Source/resource reference and duplicate-function audit: 80 files, zero issues.

The headless sandbox prints a Windows root-certificate-store error; it did not
prevent local imports or tests. The rendered test completed without that error.
These checks do not establish difficulty balance or replace manual playtesting.

Reviewed the branch-added file inventory against both the common ancestor and
latest main. Shared game systems/assets remain intact. Branch-only files are
the weapon requirements note (`My part`), weapon tests, roll preview, and the
Godot MCP addon. The addon is referenced by project autoload/plugin settings
and its scripts passed parsing, so its resources were retained. No additions
were verified unrelated and unnecessary; no assets or addons were removed.

## Earlier baseline validation

Tested locally using Godot 4.7.2 stable on Windows and the OpenGL Compatibility renderer (NVIDIA GTX 1660).

The automated suite passes **75 checks**, including player input and attack damage, stamina boundaries, dodge immunity, facing parries, the 1.5-second stagger, mastery thresholds, inventory click selection and stacking, full-inventory handling, dropped world items, merchant transactions and rarity prices, rest exclusivity, all five mystery events, a 20,000-roll rarity sample, 1,000 guaranteed boss drops, every main-path transition, victory, death, and fresh-run reset.

The progression test clears enemies using direct damage to verify state transitions. It does not establish that combat difficulty is balanced. Headless tests skip WAV playback because Godot's dummy audio driver retains short-lived playback objects at shutdown; rendered checks load and play the included audio.

Rendered screenshots are captured with `tests/visual_check.gd` for visual inspection. HUD bar dimensions and inventory text spacing were corrected after inspecting the renders.

The game is a complete playable first version of the requested loop. Animation uses procedural model transforms, room generation assembles a shared chamber kit, and audio is synthesized. Further playtesting can refine difficulty, animation, and encounter variety.
