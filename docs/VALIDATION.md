# Validation

Tested locally using Godot 4.7.2 stable on Windows and the OpenGL Compatibility renderer (NVIDIA GTX 1660).

The automated suite passes **75 checks**, including player input and attack damage, stamina boundaries, dodge immunity, facing parries, the 1.5-second stagger, mastery thresholds, inventory click selection and stacking, full-inventory handling, dropped world items, merchant transactions and rarity prices, rest exclusivity, all five mystery events, a 20,000-roll rarity sample, 1,000 guaranteed boss drops, every main-path transition, victory, death, and fresh-run reset.

The progression test clears enemies using direct damage to verify state transitions. It does not establish that combat difficulty is balanced. Headless tests skip WAV playback because Godot's dummy audio driver retains short-lived playback objects at shutdown; rendered checks load and play the included audio.

Rendered screenshots are captured with `tests/visual_check.gd` for visual inspection. HUD bar dimensions and inventory text spacing were corrected after inspecting the renders.

The game is a complete playable first version of the requested loop. Animation uses procedural model transforms, room generation assembles a shared chamber kit, and audio is synthesized. Further playtesting can refine difficulty, animation, and encounter variety.
