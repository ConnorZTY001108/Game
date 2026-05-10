# M1.5-M1.7 Map Feedback Execution Plan v0.1

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build M1.5-M1.7 as a focused playability pass: add map position sense, map content points, and clearer feedback/UI while freezing the current skill system as temporary combat test content.

**Architecture:** Keep the existing Godot 4 `Scene + Resource` structure. Add map-specific nodes under `RunScene/World/Map` and UI-specific nodes under `RunScene/CanvasLayer`; do not move combat, weapon, rune, or upgrade ownership during this pass. Map objectives communicate through `GameEvents` and small focused scripts so future skill redesign can happen without rewriting map systems.

**Tech Stack:** Godot 4.6.2, GDScript 2.0, `.tscn` scenes, `.tres` resources, PowerShell smoke commands.

**Plan Version:** `v0.1`

**Created:** 2026-05-10

**Workspace:** `C:\Users\19612\Desktop\符文荒原幸存者_Godot项目`

**Branch:** `m1-vertical-slice`

---

## Fixed Decisions

- Freeze the current skill/weapon/rune design. Existing `rune_bolt`, `sigil_orbit`, `scorch_projectile`, and `storm_orbit` remain as temporary test content only.
- Do not add new final skills, new final rune routes, meta progression, boss fights, or random map generation in this plan.
- Use fixed world coordinates for M1.5-M1.7 map work. Random generation can be designed after the map has readable landmarks and proven movement goals.
- Keep all player-facing new UI text in Simplified Chinese. Code identifiers, paths, test names, and commands stay English.
- Preserve the current 12 M1 smoke tests and add one new smoke test per milestone.

## Validation Commands

Use this Godot executable:

```powershell
$godot = 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
```

Run a specific smoke test:

```powershell
& $godot --headless --path . --script res://tests/smoke/<script>.gd --quit-after 1
```

Final full regression list after M1.7:

```powershell
& $godot --headless --path . --script res://tests/smoke/parse_all_scripts.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/load_core_scenes.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/camera_follow_contract.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/m1_wave_spawn_loop.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/m1_weapon_variety_loop.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/m1_rune_routes_loop.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/m1_feedback_settlement_loop.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/m1_visual_assets_contract.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/weapon_damage_loop.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/experience_levelup_loop.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/rune_trigger_loop.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/contact_damage_finish_loop.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/m15_map_readability_contract.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/m16_map_objectives_loop.gd --quit-after 1
& $godot --headless --path . --script res://tests/smoke/m17_feedback_ui_contract.gd --quit-after 1
```

---

## File Structure and Responsibilities

### New Map Files

- Create: `scripts/map/MapDirector.gd`
  - Owns fixed landmark, region, and content-point references.
  - Provides helper methods for tests: `get_landmark_count()`, `get_region_count()`, `get_nearest_offscreen_landmark(player_position, viewport_rect)`.

- Create: `scripts/map/MapLandmark.gd`
  - Represents one named landmark with an ID, display name, importance, and optional direction-arrow eligibility.
  - Purely visual for M1.5. No collision.

- Create: `scripts/map/MapRegion.gd`
  - Represents one rectangular named area.
  - Emits a region-entered signal only when the player moves from one region to another.

- Create: `scripts/map/RuneObelisk.gd`
  - One-time interactable objective point activated by proximity.
  - Emits an objective event and applies one configured reward.

- Create: `scripts/map/ExperienceCache.gd`
  - One-time content point that spawns 5-8 XP pickups around itself.

- Create: `scripts/map/HazardRift.gd`
  - Timed hazard with warning and active phases.
  - Applies small damage to player only; enemies ignore it.

- Create: `scripts/map/EliteTriggerPoint.gd`
  - One-time trigger that spawns a fixed small encounter near the point.

### New Map Scenes

- Create: `scenes/map/MapDirector.tscn`
- Create: `scenes/map/MapLandmark.tscn`
- Create: `scenes/map/MapRegion.tscn`
- Create: `scenes/map/RuneObelisk.tscn`
- Create: `scenes/map/ExperienceCache.tscn`
- Create: `scenes/map/HazardRift.tscn`
- Create: `scenes/map/EliteTriggerPoint.tscn`

### Modified Existing Files

- Modify: `scenes/run/RunScene.tscn`
  - Add `World/Map`.
  - Instance map director, landmarks, regions, rune obelisks, experience caches, hazard rifts, and elite trigger point.

- Modify: `scripts/run/RunScene.gd`
  - Bind player reference into map director/objectives if needed.
  - Include map objective summary in settlement payload.

- Modify: `autoload/GameEvents.gd`
  - Add map-specific signals:
    - `map_region_changed(region_id: String, display_name: String)`
    - `map_objective_updated(active_count: int, total_count: int)`
    - `map_event_triggered(event_id: String, display_name: String)`
    - `map_reward_granted(reward_id: String, display_name: String)`

- Modify: `scripts/ui/HUD.gd`
  - Add objective text.
  - Add region/event prompt text.
  - Hide debug by default through scene/config change, not by deleting `DebugOverlay`.

- Modify: `scripts/ui/SettlementPanel.gd`
  - Convert visible English labels to Chinese.
  - Add map objective summary.

- Modify: `scripts/ui/LevelUpPanel.gd`
  - Only improve readability and Chinese text. Do not add final skill design.

- Modify: `scripts/enemies/Enemy.gd`
  - Add hit flash and death visual feedback without changing enemy stats.

- Modify: `scripts/player/Player.gd`
  - Add short damage blink/invulnerability visual feedback if not already present.
  - Add a method for temporary map rewards, for example `apply_temporary_pickup_radius_bonus(value: float, duration_seconds: float)`.

- Modify: `scripts/components/HealthComponent.gd`
  - Only add signal support if feedback needs it. Do not change health math.

### New Smoke Tests

- Create: `tests/smoke/m15_map_readability_contract.gd`
- Create: `tests/smoke/m16_map_objectives_loop.gd`
- Create: `tests/smoke/m17_feedback_ui_contract.gd`

### Documentation

- Modify: `docs/qa/m1-acceptance.md`
  - Add M1.5, M1.6, and M1.7 manual check sections.

- Modify: `README.md`
  - Add a short M1.5-M1.7 section only after implementation is complete.

---

## World Layout Contract

Use these fixed coordinates for v0.1.

| Item | ID | Display Name | Position | Purpose |
|---|---|---:|---:|---|
| Spawn landmark | `spawn_altar` | `破碎符文祭坛` | `(0, 0)` | First-screen anchor |
| North landmark | `broken_tower` | `残缺高塔` | `(0, -1450)` | North direction reference |
| East landmark | `glowing_rift_landmark` | `发光裂隙` | `(1600, -250)` | East danger reference |
| West landmark | `ruin_gate` | `废墟石门` | `(-1500, 350)` | West event reference |
| Region | `altar_region` | `碎符祭坛` | center `(0, 0)`, size `(1400, 1100)` | Spawn area |
| Region | `ash_region` | `灰烬焦土` | center `(1350, -200)`, size `(1400, 1200)` | Hazard area |
| Region | `stone_region` | `风化碎石地` | center `(-1300, 350)`, size `(1400, 1200)` | Event area |
| Obelisk | `obelisk_altar` | `祭坛符文碑` | `(420, -260)` | XP reward |
| Obelisk | `obelisk_ash` | `焦土符文碑` | `(1350, -650)` | Heal reward |
| Obelisk | `obelisk_stone` | `碎石符文碑` | `(-1250, 760)` | Temporary pickup/move reward |
| XP cache | `xp_cache_north` | `北侧经验残片` | `(250, -1050)` | Movement reward |
| XP cache | `xp_cache_west` | `西侧经验残片` | `(-950, 100)` | Movement reward |
| Hazard | `rift_ash_01` | `灰烬裂隙一` | `(1100, -250)` | Timed hazard |
| Hazard | `rift_ash_02` | `灰烬裂隙二` | `(1680, 120)` | Timed hazard |
| Elite trigger | `ruin_gate_ambush` | `废墟伏击点` | `(-1500, 350)` | One-time encounter |

---

## Task 1: M1.5 Map Readability Foundation

**Goal:** Add fixed world landmarks, terrain regions, and region prompts so the player can tell where they are.

**Files:**
- Create: `scripts/map/MapLandmark.gd`
- Create: `scripts/map/MapRegion.gd`
- Create: `scripts/map/MapDirector.gd`
- Create: `scenes/map/MapLandmark.tscn`
- Create: `scenes/map/MapRegion.tscn`
- Create: `scenes/map/MapDirector.tscn`
- Modify: `scenes/run/RunScene.tscn`
- Modify: `scripts/run/RunScene.gd`
- Modify: `autoload/GameEvents.gd`
- Modify: `scripts/ui/HUD.gd`
- Create: `tests/smoke/m15_map_readability_contract.gd`
- Modify: `docs/qa/m1-acceptance.md`

- [ ] **Step 1: Add map signals to `GameEvents.gd`**

Add these signals without removing existing signals:

```gdscript
signal map_region_changed(region_id: String, display_name: String)
signal map_landmark_hint_changed(landmark_id: String, display_name: String, direction: Vector2)
```

Expected behavior:
- `map_region_changed` fires only when the active region changes.
- `map_landmark_hint_changed` can fire when the nearest important off-screen landmark changes.

- [ ] **Step 2: Create `MapLandmark.gd`**

Required exported fields:

```gdscript
class_name MapLandmark
extends Node2D

@export var landmark_id: String = ""
@export var display_name: String = ""
@export var importance: int = 1
@export var show_direction_hint: bool = true
```

Implementation requirements:
- No collision shapes.
- Create a clear placeholder visual in the scene, not in code.
- Provide `func is_valid_landmark() -> bool` returning true when `landmark_id` and `display_name` are not empty.

- [ ] **Step 3: Create `MapRegion.gd`**

Required exported fields:

```gdscript
class_name MapRegion
extends Area2D

@export var region_id: String = ""
@export var display_name: String = ""
@export var priority: int = 0
```

Implementation requirements:
- Use `Area2D` with a rectangular `CollisionShape2D`.
- Provide `func contains_world_position(world_position: Vector2) -> bool`.
- Do not rely on physics callbacks only; tests must be able to query it directly.

- [ ] **Step 4: Create `MapDirector.gd`**

Required responsibilities:
- Export `player_path: NodePath`.
- Cache children under `Landmarks` and `Regions`.
- Track current region ID.
- Emit `GameEvents.map_region_changed` when player position enters a different region.
- Expose:

```gdscript
func get_landmark_count() -> int
func get_region_count() -> int
func get_active_region_id() -> String
```

Expected region selection:
- If multiple regions contain the player, choose the highest `priority`.
- If no region contains the player, keep the previous region until another known region is entered.

- [ ] **Step 5: Build `MapDirector.tscn`**

Node structure:

```text
MapDirector (Node2D, script MapDirector.gd)
  Landmarks (Node2D)
    SpawnAltar (Node2D, script MapLandmark.gd)
    BrokenTower (Node2D, script MapLandmark.gd)
    GlowingRiftLandmark (Node2D, script MapLandmark.gd)
    RuinGate (Node2D, script MapLandmark.gd)
  Regions (Node2D)
    AltarRegion (Area2D, script MapRegion.gd)
    AshRegion (Area2D, script MapRegion.gd)
    StoneRegion (Area2D, script MapRegion.gd)
```

Visual requirements:
- `SpawnAltar` must be visible near `(0, 0)` and include a larger central shape plus smaller surrounding stones.
- `BrokenTower` must be taller than ordinary decoration.
- `GlowingRiftLandmark` must have a brighter accent color.
- `RuinGate` must read as a wide gate or wall fragment.

- [ ] **Step 6: Add `World/Map` to `RunScene.tscn`**

Target structure:

```text
RunScene
  World
    Ground
    Map
      MapDirector
    Player
    Enemies
    Projectiles
    Pickups
```

Set `MapDirector.player_path` to the player node.

- [ ] **Step 7: Add HUD region prompt**

In `HUD.gd`:
- Add a top-center label named `RegionPromptLabel`.
- On `GameEvents.map_region_changed`, set text to the region display name.
- Show for `1.5` seconds.
- Fade or hide after the timer.

Initial texts:
- `碎符祭坛`
- `灰烬焦土`
- `风化碎石地`

- [ ] **Step 8: Add M1.5 smoke test**

Create `tests/smoke/m15_map_readability_contract.gd`.

The test must:
- Load `res://scenes/run/RunScene.tscn`.
- Assert `World/Map/MapDirector` exists.
- Assert exactly 4 landmarks exist.
- Assert at least 3 regions exist.
- Assert the player start position is inside `altar_region`.
- Move/query positions near `(1350, -200)` and `(-1300, 350)` and assert region IDs resolve to `ash_region` and `stone_region`.
- Assert `GameEvents.map_region_changed` can be emitted and HUD receives a non-empty prompt.

Expected command:

```powershell
& $godot --headless --path . --script res://tests/smoke/m15_map_readability_contract.gd --quit-after 1
```

Expected output:

```text
PASS: M1.5 map readability contract
```

- [ ] **Step 9: Manual M1.5 check**

Windowed run command:

```powershell
& $godot --path .
```

Manual acceptance:
- Spawn screen shows `破碎符文祭坛`.
- Moving right/right-up reaches a darker `灰烬焦土` area.
- Moving left/left-down reaches a lighter `风化碎石地` area.
- Region prompt appears once per region change.
- Enemies remain readable against the ground and decorations.

---

## Task 2: M1.6 Map Objectives and Content Points

**Goal:** Add concrete reasons to move through the map: rune obelisks, XP caches, hazard rifts, and one ambush trigger.

**Files:**
- Create: `scripts/map/RuneObelisk.gd`
- Create: `scripts/map/ExperienceCache.gd`
- Create: `scripts/map/HazardRift.gd`
- Create: `scripts/map/EliteTriggerPoint.gd`
- Create: `scripts/map/MapObjectiveSystem.gd`
- Create: `scenes/map/RuneObelisk.tscn`
- Create: `scenes/map/ExperienceCache.tscn`
- Create: `scenes/map/HazardRift.tscn`
- Create: `scenes/map/EliteTriggerPoint.tscn`
- Modify: `scenes/map/MapDirector.tscn`
- Modify: `scenes/run/RunScene.tscn`
- Modify: `autoload/GameEvents.gd`
- Modify: `scripts/run/RunScene.gd`
- Modify: `scripts/ui/HUD.gd`
- Modify: `scripts/ui/SettlementPanel.gd`
- Create: `tests/smoke/m16_map_objectives_loop.gd`
- Modify: `docs/qa/m1-acceptance.md`

- [ ] **Step 1: Add map objective signals and counters**

Add to `GameEvents.gd`:

```gdscript
signal map_objective_updated(active_count: int, total_count: int)
signal map_event_triggered(event_id: String, display_name: String)
signal map_reward_granted(reward_id: String, display_name: String)
```

Add stored counters:

```gdscript
var activated_obelisk_count: int = 0
var total_obelisk_count: int = 0
var triggered_map_event_count: int = 0
```

Add getters:

```gdscript
func get_map_objective_summary() -> Dictionary
```

The dictionary must include:
- `activated_obelisks`
- `total_obelisks`
- `triggered_map_events`
- `all_obelisks_activated`

- [ ] **Step 2: Create `MapObjectiveSystem.gd`**

Required responsibilities:
- Register total obelisk count at run start.
- Reset map counters on `run_started`.
- Provide `record_obelisk_activated(obelisk_id: String, display_name: String)`.
- Provide `record_map_event(event_id: String, display_name: String)`.
- Emit `map_objective_updated` after every obelisk activation.

Expected opening objective:

```text
寻找并激活 3 个符文碑
```

- [ ] **Step 3: Create `RuneObelisk.gd`**

Required exported fields:

```gdscript
class_name RuneObelisk
extends Area2D

@export var obelisk_id: String = ""
@export var display_name: String = ""
@export var reward_type: String = "experience"
@export var reward_value: float = 10.0
@export var activation_radius: float = 96.0
```

Activation rules:
- Activate once.
- Activate when player enters the area or when `try_activate(player)` is called by test.
- Reward types:
  - `experience`: call `ExperienceSystem.add_experience(int(reward_value))`
  - `heal`: call player health component if available; cap at max health
  - `pickup_bonus`: call a temporary player reward method
- Emit `map_reward_granted`.
- Notify `MapObjectiveSystem`.

Place three obelisks:
- `obelisk_altar` at `(420, -260)`, reward `experience`, value `12`
- `obelisk_ash` at `(1350, -650)`, reward `heal`, value `20`
- `obelisk_stone` at `(-1250, 760)`, reward `pickup_bonus`, value `32`, duration `20`

- [ ] **Step 4: Create `ExperienceCache.gd`**

Required exported fields:

```gdscript
class_name ExperienceCache
extends Area2D

@export var cache_id: String = ""
@export var display_name: String = ""
@export var pickup_count: int = 6
@export var spread_radius: float = 90.0
@export var experience_value: int = 1
```

Activation rules:
- Trigger once by proximity.
- Spawn `pickup_count` instances of `res://scenes/pickups/ExperiencePickup.tscn`.
- Spread pickups in a circle around the cache.
- Emit `map_event_triggered(cache_id, display_name)`.

Place two caches:
- `xp_cache_north` at `(250, -1050)`, count `6`
- `xp_cache_west` at `(-950, 100)`, count `8`

- [ ] **Step 5: Create `HazardRift.gd`**

Required exported fields:

```gdscript
class_name HazardRift
extends Area2D

@export var rift_id: String = ""
@export var display_name: String = ""
@export var warning_seconds: float = 0.7
@export var active_seconds: float = 0.6
@export var idle_seconds: float = 3.0
@export var damage: float = 6.0
```

State cycle:
- `idle` for `3.0` seconds.
- `warning` for `0.7` seconds.
- `active` for `0.6` seconds.
- Repeat.

Damage rules:
- Damage player only once per active window.
- Do not damage enemies.
- Warning visual color must be distinct from active visual color.

Place two rifts:
- `rift_ash_01` at `(1100, -250)`
- `rift_ash_02` at `(1680, 120)`

- [ ] **Step 6: Create `EliteTriggerPoint.gd`**

Required exported fields:

```gdscript
class_name EliteTriggerPoint
extends Area2D

@export var trigger_id: String = ""
@export var display_name: String = ""
@export var enemies_path: NodePath
@export var player_path: NodePath
@export var enemy_scene: PackedScene
@export var dust_thrall_data: Resource
@export var ash_runner_data: Resource
@export var bone_brute_data: Resource
```

Activation rules:
- Trigger once by proximity.
- Spawn exactly:
  - 4 `dust_thrall`
  - 2 `ash_runner`
  - 1 `bone_brute`
- Spawn positions must be at least 160 px from the player.
- Emit:

```text
废墟中的敌意苏醒了
```

Place trigger:
- `ruin_gate_ambush` at `(-1500, 350)`.

- [ ] **Step 7: Add objective HUD**

In `HUD.gd`:
- Add `ObjectiveLabel`.
- Initial text: `目标：激活符文碑 0/3`
- On `map_objective_updated(activated, total)`, update:
  - `目标：激活符文碑 1/3`
  - `目标：激活符文碑 2/3`
  - `目标：符文碑已全部激活`
- On `map_event_triggered`, show a short event prompt for 2 seconds.
- On `map_reward_granted`, show a short reward prompt for 1.5 seconds.

- [ ] **Step 8: Add map objective summary to settlement**

In `RunScene.gd`, include this in `settlement_requested` payload:

```gdscript
"map_objectives": GameEvents.get_map_objective_summary()
```

In `SettlementPanel.gd`, display:

```text
符文碑：2/3
地图事件：3
地图目标：未完成
```

When all obelisks are activated:

```text
地图目标：已完成
```

- [ ] **Step 9: Add M1.6 smoke test**

Create `tests/smoke/m16_map_objectives_loop.gd`.

The test must:
- Load `RunScene.tscn`.
- Assert 3 rune obelisks exist.
- Activate each obelisk by calling `try_activate(player)`.
- Assert `GameEvents.get_map_objective_summary()["activated_obelisks"] == 3`.
- Assert HUD objective text reaches `符文碑已全部激活`.
- Trigger one XP cache and assert pickup children increase.
- Force one hazard active state and assert player health decreases.
- Trigger ambush and assert exactly 7 enemies are added.
- Finish run and assert settlement text includes `符文碑：3/3`.

Expected command:

```powershell
& $godot --headless --path . --script res://tests/smoke/m16_map_objectives_loop.gd --quit-after 1
```

Expected output:

```text
PASS: M1.6 map objectives loop
```

- [ ] **Step 10: Manual M1.6 check**

Manual acceptance:
- Opening HUD shows `目标：激活符文碑 0/3`.
- Player can reach and activate all 3 obelisks.
- Each obelisk gives visible feedback and a reward prompt.
- XP caches generate pickups once.
- Hazard rifts show warning before damage.
- Ruin gate ambush spawns enemies away from the player, not directly on top.
- Settlement records obelisk count and map event count.

---

## Task 3: M1.7 Feedback and UI Cleanup

**Goal:** Make the temporary M1 gameplay read like a game instead of a debug prototype, without redesigning skills.

**Files:**
- Modify: `scripts/ui/HUD.gd`
- Modify: `scenes/ui/HUD.tscn`
- Modify: `scripts/ui/SettlementPanel.gd`
- Modify: `scenes/ui/SettlementPanel.tscn`
- Modify: `scripts/ui/LevelUpPanel.gd`
- Modify: `scenes/ui/LevelUpPanel.tscn`
- Modify: `autoload/GameEvents.gd`
- Modify: `scripts/enemies/Enemy.gd`
- Modify: `scripts/player/Player.gd`
- Modify: `scripts/components/HealthComponent.gd`
- Modify: `scenes/run/RunScene.tscn`
- Create: `tests/smoke/m17_feedback_ui_contract.gd`
- Modify: `tests/smoke/m1_feedback_settlement_loop.gd`
- Modify: `tests/smoke/contact_damage_finish_loop.gd`
- Modify: `docs/qa/m1-acceptance.md`

- [ ] **Step 1: Convert settlement visible text to Chinese**

In `SettlementPanel.gd`, replace visible strings:

| Old | New |
|---|---|
| `VICTORY` | `胜利` |
| `DEFEAT` | `失败` |
| `Survival Time` | `存活时间` |
| `Kills` | `击杀` |
| `Level` | `等级` |
| `Route Summary` | `本局选择` |
| `None` | `无` |

Required summary format:

```text
存活时间：01:31
击杀：12
等级：4
符文碑：2/3
地图事件：3
地图目标：未完成
本局选择：锋锐符文弹, 灼痕
```

- [ ] **Step 2: Convert feedback prompt visible text to Chinese**

In `GameEvents.gd`, replace feedback message prefixes:

| Old | New |
|---|---|
| `UPGRADE: <name>` | `升级：<name>` |
| `RUNE: <label>` | `符文触发：<label>` |
| `DEFEAT` | `失败` |

- [ ] **Step 3: Hide `DebugOverlay` by default**

In `RunScene.tscn` or `DebugOverlay.gd`:
- Set DebugOverlay `visible = false` by default.
- Do not delete the node.
- Add a later-compatible toggle function if simple:

```gdscript
func set_debug_visible(enabled: bool) -> void:
	visible = enabled
```

Smoke requirement:
- `RunScene/CanvasLayer/DebugOverlay` exists.
- It is not visible by default.

- [ ] **Step 4: Add enemy hit flash**

In `Enemy.gd`:
- When damage is applied, briefly modulate the visual sprite to a bright color.
- Flash duration: `0.08` to `0.12` seconds.
- Reset to original color after flash.
- Do not change damage math.

Expected testable hook:

```gdscript
func is_hit_flash_active() -> bool
```

- [ ] **Step 5: Add enemy death fade/shrink**

In `Enemy.gd`:
- On death, trigger a short visual effect before queue-free if current architecture allows.
- Duration: `0.2` to `0.4` seconds.
- Drop XP must still happen exactly once.
- If immediate queue-free is required by existing tests, use a small death feedback node spawned separately and keep enemy lifecycle unchanged.

Required signal compatibility:
- Existing `enemy_died` behavior must remain.
- Existing XP drop smoke must still pass.

- [ ] **Step 6: Add player damage blink**

In `Player.gd`:
- On health decrease, make the player sprite blink for `0.35` seconds.
- Blink should not imply invulnerability unless invulnerability already exists.
- Do not change contact damage rate in this task.

Expected testable hook:

```gdscript
func is_damage_blink_active() -> bool
```

- [ ] **Step 7: Upgrade panel readability-only pass**

In `LevelUpPanel.gd/.tscn`:
- Keep the existing temporary upgrade content.
- Make each option readable in three lines:

```text
<名称>
<路线或类型>
<当前效果说明>
```

Rules:
- No final skill redesign.
- No new skills.
- No new rune routes.
- Button text must wrap and not overflow at 1280x720.

- [ ] **Step 8: Limit feedback noise**

In `HUD.gd`:
- Keep `MAX_FEEDBACK_MESSAGES`.
- Add a visible floating label cap, for example `MAX_VISIBLE_FEEDBACK_LABELS = 18`.
- When the cap is exceeded, remove or fade the oldest label first.
- Map event and objective prompts must use separate labels and must not compete with normal damage numbers.

- [ ] **Step 9: Add M1.7 smoke test**

Create `tests/smoke/m17_feedback_ui_contract.gd`.

The test must:
- Load `RunScene.tscn`.
- Assert DebugOverlay exists and is hidden by default.
- Emit upgrade selected and assert HUD feedback includes `升级：`.
- Emit rune triggered and assert HUD feedback includes `符文触发：`.
- Finish victory and assert settlement contains `胜利`, `存活时间`, `击杀`, `等级`.
- Finish defeat and assert settlement contains `失败`.
- Assert settlement contains map objective labels after receiving a map summary.
- Damage enemy and assert `is_hit_flash_active()` becomes true.
- Damage player and assert `is_damage_blink_active()` becomes true.

Expected command:

```powershell
& $godot --headless --path . --script res://tests/smoke/m17_feedback_ui_contract.gd --quit-after 1
```

Expected output:

```text
PASS: M1.7 feedback and UI contract
```

- [ ] **Step 10: Update existing smoke tests for Chinese text**

Update tests that currently assert English text:
- `tests/smoke/m1_feedback_settlement_loop.gd`
- `tests/smoke/contact_damage_finish_loop.gd`

Expected replacements:
- `VICTORY` -> `胜利`
- `DEFEAT` -> `失败`
- `Survival Time` -> `存活时间`
- `Kills` -> `击杀`
- `Route Summary` -> `本局选择`

- [ ] **Step 11: Manual M1.7 check**

Manual acceptance:
- Default gameplay does not show debug overlay.
- HUD shows health, level, time, kills, and map objective without blocking player movement.
- Enemy hit flash is visible but not noisy.
- Player damage feedback is visible but does not obscure the screen.
- Settlement is fully Chinese and includes map objective results.
- Upgrade panel is readable and does not overflow.

---

## Task 4: Final Integration and Documentation

**Goal:** Confirm M1.5-M1.7 are integrated, documented, and safe to continue from before future skill redesign.

**Files:**
- Modify: `README.md`
- Modify: `docs/qa/m1-acceptance.md`
- No gameplay code changes unless fixing test failures from earlier tasks.

- [ ] **Step 1: Run full smoke regression**

Run all commands from the "Validation Commands" section.

Expected:
- Existing 12 M1 smoke tests PASS.
- New M1.5, M1.6, and M1.7 smoke tests PASS.

- [ ] **Step 2: Update QA document**

In `docs/qa/m1-acceptance.md`, add:
- `M1.5 Map Readability`
- `M1.6 Map Objectives`
- `M1.7 Feedback and UI`

Each section must include:
- automated smoke result
- manual status
- known risks

Manual status must remain `Pending / Manual required` until the user confirms a windowed playtest result.

- [ ] **Step 3: Update README**

Add a short section:

```markdown
## M1.5-M1.7 Playability Pass

- M1.5 adds fixed landmarks, terrain regions, and region prompts.
- M1.6 adds rune obelisks, XP caches, hazard rifts, and a one-time ambush point.
- M1.7 cleans up player-facing Chinese UI, feedback, and settlement summaries.

The current skill system remains temporary and is intentionally not expanded in this pass.
```

- [ ] **Step 4: Manual playtest checklist**

Windowed command:

```powershell
& $godot --path .
```

Test for 2 minutes:
- Spawn at `破碎符文祭坛`.
- Move to at least one non-spawn region.
- Activate at least one obelisk.
- Trigger one XP cache or ambush.
- Step near a hazard rift and verify warning before damage.
- Die or trigger victory path and inspect settlement.

- [ ] **Step 5: Record residual risks**

Add these explicit residual risks unless they have been fixed and verified:
- Skill design is temporary and intentionally frozen.
- Map layout is fixed-coordinate and not final procedural generation.
- Visual assets are prototype-quality.
- Balance and long-run pacing still need a separate pass after map and skill direction stabilize.

---

## Definition of Done

M1.5-M1.7 are done when:

- Player sees a recognizable spawn landmark on the first screen.
- Player can move into at least three visually distinct map regions.
- Region prompt changes when entering another region.
- The map contains exactly 3 activatable rune obelisks.
- HUD tracks obelisk progress from `0/3` to `3/3`.
- The map contains at least 2 XP caches, 2 hazard rifts, and 1 ambush trigger.
- Hazard rifts have warning and active states.
- Settlement shows map objective results.
- Core player-facing UI is Chinese.
- Debug overlay is hidden by default.
- Enemy hit, enemy death, player damage, map objective, and map event feedback are visible.
- Existing 12 M1 smoke tests still PASS.
- New `m15_map_readability_contract.gd`, `m16_map_objectives_loop.gd`, and `m17_feedback_ui_contract.gd` PASS.

## Not Done in This Plan

- Final skill redesign.
- Final weapon/rune balance.
- New final rune routes.
- Meta progression.
- Boss fight.
- Complete minimap.
- Procedural map generation.
- Final art/audio polish.

## Recommended Execution Mode

Use subagent-driven execution in this order:

1. M1.5 Map Readability Foundation.
2. M1.6 Map Objectives and Content Points.
3. M1.7 Feedback and UI Cleanup.
4. Final Integration and Documentation.

Each task should run its own new smoke test plus the most relevant existing regressions before handing off.
