# M0 Smoke Test

Date: 2026-05-03
Godot Version: 4.6.2.stable.official.71f334935
Tester: Task 12 implementation subagent (Codex)

## Automated Checks

Explicit executable used:

`C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`

- `& "C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --quit`: PASS, exit 0. Output: `Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org`
- `& "C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke/parse_all_scripts.gd --quit-after 1`: PASS, exit 0. Output: `PASS: all scripts loaded`
- `& "C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke/load_core_scenes.gd --quit-after 1`: PASS, exit 0. Output: `PASS: core scenes and resources loaded`

Additional automated smoke commands run:

- `& "C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --version`: PASS, exit 0. Output: `4.6.2.stable.official.71f334935`
- `& "C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --quit-after 1`: PASS, exit 0. Output: `Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org`
- `& "C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke/weapon_damage_loop.gd --quit-after 1`: PASS, exit 0. Output: `PASS: weapon projectile damage and enemy death loop`
- `& "C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke/experience_levelup_loop.gd --quit-after 1`: PASS, exit 0. Output: `PASS: experience drop, pickup collection, level-up choices`
- `& "C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke/rune_trigger_loop.gd --quit-after 1`: PASS, exit 0. Output: `PASS: rune upgrade and element trigger loop`
- `& "C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke/contact_damage_finish_loop.gd --quit-after 1`: PASS, exit 0. Output: `PASS: contact damage defeat and run-finished HUD loop`
- `& "C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --quit-after 2`: PASS, exit 0. Output: `Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org`

No `godot4` executable was used in this validation pass; the explicit Godot 4.6.2 console executable above was used for every automated check.

## Manual Checks

Manual editor playtest not executed in this headless validation pass.

- [ ] Project opens in Godot 4 Editor.
- [ ] Pressing Play loads the run scene.
- [ ] Player moves with WASD.
- [ ] HUD shows HP, level, XP, time, and kills.
- [ ] Debug overlay shows FPS, enemies, projectiles, and pickups.
- [ ] Enemies spawn around the player and chase.
- [ ] Rune Bolt fires automatically at the nearest enemy.
- [ ] Projectiles damage enemies.
- [ ] Dead enemies drop experience pickups.
- [ ] Experience pickups collect into the player.
- [ ] Level-up opens three choices and pauses gameplay.
- [ ] Selecting a weapon stat upgrade changes combat behavior.
- [ ] Selecting Scorch Mark equips a rune.
- [ ] Scorch Mark triggers bonus damage after three stacks on a target.
- [ ] Enemy contact damages the player.
- [ ] Player death ends the run with defeat state.
- [ ] Timer completion ends the run with victory state.

## Architecture Acceptance

Architecture checks were verified by code inspection plus the automated smoke scripts above.

- [x] Adding a new weapon can start from a new `WeaponData` Resource and `WeaponController` behavior, without editing `Player.gd`.
- [x] Adding a new basic enemy can start from a new `EnemyData` Resource, without editing `DamageSystem.gd`.
- [x] Adding a new rune can start from a new `RuneData` Resource and `RuneSystem` effect branch, without editing projectile firing logic.
- [x] Run state transitions are centralized in `GameRuntime.gd`.
- [x] Entity scripts do not own global progression, upgrade, rune, or spawn state.

## Remaining Risks

- No verified issues observed during automated headless validation.
