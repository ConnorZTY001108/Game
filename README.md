# Runebound Wasteland Survivor M0

Godot 4 project for the M0 architecture baseline and minimum combat loop.

## CLI Validation

Check whether Godot is on PATH:

```powershell
where.exe godot
where.exe godot4
```

If `godot` exists:

```powershell
godot --headless --path . --quit
godot --headless --path . --script res://tests/smoke/parse_all_scripts.gd --quit-after 1
godot --headless --path . --script res://tests/smoke/load_core_scenes.gd --quit-after 1
```

If only `godot4` exists, replace `godot` with `godot4`. In this environment, append `--quit-after 1` for smoke scripts when using either local `godot` or an explicit console executable.

Known explicit console executable:

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --version
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/parse_all_scripts.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/load_core_scenes.gd --quit-after 1
```

If no CLI exists during Task 1, open/import this folder in Godot 4 Editor and confirm the project metadata imports without startup parse errors.

Full `scenes/Main.tscn` / `load_core_scenes.gd` validation starts after later tasks create the core scenes and data resources.

## M0 Acceptance

M0 is accepted when:

- Godot opens the project and runs `scenes/Main.tscn`.
- The minimum combat loop works: move, spawn, chase, auto-fire, hit, kill, drop XP, collect XP, level up, choose upgrade, resume.
- Scorch Mark demonstrates one rune and element trigger chain.
- Debug overlay reports FPS and object counts.
- Run finish states exist for defeat and timer victory.
