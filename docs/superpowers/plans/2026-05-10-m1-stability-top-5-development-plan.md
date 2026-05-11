# M1 Stability Top 5 Development Plan

> **For agentic workers:** Implement this plan task-by-task. Keep the working tree protected, do not revert unrelated user changes, and run the listed smoke checks before marking a task complete.

**Goal:** 把当前 Godot 4 survivor-like 项目推进到稳定的 M1 playable build。完成后，核心闭环应满足：升级不会卡死，局内时间只有一个权威来源，武器/符文/augment 的 tag 解析一致，波次阶段事件能真实发出，主场景有一条 headless playable smoke 防止回归。

**Scope:** 本计划只覆盖下一步最值得做的 5 个任务，不扩展新武器、新敌人、新地图内容，也不做视觉大改。

**Tech Stack:** Godot 4.6.2, GDScript 2.0, Godot Resource (`.tres`), Scene (`.tscn`), PowerShell, headless smoke scripts.

---

## Baseline Rules

- [ ] 开始前运行 `git status --short --branch`，确认当前工作区状态。
- [ ] 不运行 `tools/create_m0_scenes.gd`，除非用户明确要求。
- [ ] 不回滚、删除、覆盖和当前任务无关的已有改动。
- [ ] 每个任务只修改本任务列出的文件范围，确需扩展时先记录原因。
- [ ] 新增测试优先放在 `tests/smoke/`。
- [ ] 每个任务完成后运行对应 smoke，最终运行集成 smoke。

Godot headless 命令模板：

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/<script>.gd
```

建议先跑现有基线：

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/parse_all_scripts.gd
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/load_core_scenes.gd
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/experience_levelup_loop.gd
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/weapon_damage_loop.gd
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/rune_trigger_loop.gd
```

---

## Task 1: Fix `LevelUpPanel` Softlock

**Priority:** P0

**Problem:** `LevelUpPanel` 在选项为空或 `UpgradeSystem.apply_choice()` 失败时可能隐藏 UI 或停留在 `LEVEL_UP` pause 状态，导致玩家无法继续游戏。

**Write Scope:**

- Modify: `scripts/ui/LevelUpPanel.gd`
- Modify if needed: `autoload/ExperienceSystem.gd`
- Modify if needed: `autoload/UpgradeSystem.gd`
- Create: `tests/smoke/level_up_empty_options_does_not_softlock.gd`
- Create: `tests/smoke/level_up_invalid_choice_keeps_panel_visible.gd`

### Implementation Steps

- [ ] Read `LevelUpPanel._show_options()` and `_select_option()` to confirm current pause/resume flow.
- [ ] In `_show_options(options)`, handle empty options explicitly.
- [ ] Preferred fallback: show a stable `Skip / 跳过升级` option.
- [ ] Acceptable temporary fallback: resume the run and print a clear warning if no options exist.
- [ ] Change `_select_option(option)` so it calls `UpgradeSystem.apply_choice(option, player)` before hiding or clearing the panel.
- [ ] If `apply_choice()` returns `true`, hide the panel, clear buttons, and resume the game.
- [ ] If `apply_choice()` returns `false`, keep the panel visible and do not consume the pending level-up.
- [ ] Add a visible debug feedback path or warning log for invalid choices.
- [ ] Verify `ExperienceSystem` does not incorrectly consume pending level-ups after a failed choice.

### Acceptance Criteria

- [ ] Empty upgrade options do not leave the game permanently paused.
- [ ] Invalid upgrade or augment choices do not make the level-up UI disappear.
- [ ] After a failed choice, the player can retry, skip, or the run safely resumes.
- [ ] Existing `experience_levelup_loop.gd` still passes.

### Verification

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/experience_levelup_loop.gd
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/level_up_empty_options_does_not_softlock.gd
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/level_up_invalid_choice_keeps_panel_visible.gd
```

### Risks

- A simple auto-resume fallback may silently remove one upgrade reward. If possible, prefer a visible skip option.
- If `ExperienceSystem` consumes pending level-ups too early, the UI fix alone will not be enough.

---

## Task 2: Unify `GameRuntime` and `RunTimerSystem` Time Authority

**Priority:** P1

**Problem:** `GameRuntime` and `RunTimerSystem` both maintain `elapsed_seconds`. This can cause inconsistent timing for HUD, victory, wave phases, and periodic augment triggers.

**Write Scope:**

- Modify: `autoload/GameRuntime.gd`
- Modify: `scripts/systems/RunTimerSystem.gd`
- Modify if needed: `scripts/systems/SpawnSystem.gd`
- Create: `tests/smoke/run_timer_authority_contract.gd`

### Recommended Design

`RunTimerSystem` should be the only system that advances in-run elapsed time. `GameRuntime` should manage run state and expose the latest elapsed snapshot.

### Implementation Steps

- [ ] Inspect all writes to `GameRuntime.elapsed_seconds`.
- [ ] Stop `GameRuntime._process()` from incrementing `elapsed_seconds` directly.
- [ ] Let `RunTimerSystem._process(delta)` advance local elapsed time only when the run is actually playing.
- [ ] Each frame, write the authoritative value into `GameRuntime.elapsed_seconds`.
- [ ] Move or route `augment_periodic_tick` so it is emitted from the same authoritative time source.
- [ ] Confirm pause, level-up, game-over, and victory states do not continue advancing time.
- [ ] Confirm HUD, SpawnSystem, settlement, and victory condition read consistent time.

### Acceptance Criteria

- [ ] After a 10-second simulated run, `RunTimerSystem.elapsed_seconds` and `GameRuntime.elapsed_seconds` match.
- [ ] HUD time reflects the same value.
- [ ] Victory timing does not regress.
- [ ] Periodic augment ticks are not duplicated.
- [ ] Periodic augment ticks are not skipped because of state transition ordering.

### Verification

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/run_timer_authority_contract.gd
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/m1_wave_spawn_loop.gd
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/m1_feedback_settlement_loop.gd
```

### Risks

- Existing augment tests may depend on old tick timing and need expectation updates.
- If `RunTimerSystem` is missing in a test scene, tests may need to instantiate it or explicitly mock time.

---

## Task 3: Unify Tag Normalization

**Priority:** P1

**Problem:** `DamageSystem`, `WeaponController`, `RuneSystem`, and augment code normalize tags differently. `PackedStringArray`, plain `String`, or comma-separated tag strings may be silently dropped, causing weapon/rune/augment interactions to fail.

**Write Scope:**

- Modify: `autoload/DamageSystem.gd`
- Modify: `scripts/weapons/WeaponController.gd`
- Modify: `autoload/RuneSystem.gd`
- Modify if needed: `autoload/AugmentEffectRunner.gd`
- Create if useful: `autoload/TagUtils.gd`
- Create: `tests/smoke/tag_normalization_contract.gd`

### Recommended Design

Create one reusable normalization function:

```gdscript
TagUtils.to_string_array(value) -> Array[String]
```

It should support:

- `null`
- `Array`
- `PackedStringArray`
- single `String`
- comma-separated `String`
- empty string filtering
- optional deduplication while preserving order

### Implementation Steps

- [ ] Find all local tag conversion helpers.
- [ ] Add a shared `TagUtils.to_string_array(value)` helper.
- [ ] Replace `DamageSystem._to_string_array()` usage with the shared helper.
- [ ] Replace `WeaponController._get_string_array()` usage with the shared helper.
- [ ] Replace `RuneSystem._get_string_array()` usage with the shared helper.
- [ ] Align augment effect or condition parsing with the same helper.
- [ ] Confirm weapon tags, element tags, damage packet tags, rune tags, and augment required tags all use the same normalization.

### Acceptance Criteria

- [ ] These three inputs produce identical normalized output:

```gdscript
["fire", "projectile"]
PackedStringArray(["fire", "projectile"])
"fire, projectile"
```

- [ ] Empty strings are ignored.
- [ ] Whitespace around tags is trimmed.
- [ ] Existing weapon damage and rune trigger smoke tests pass.

### Verification

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/tag_normalization_contract.gd
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/weapon_damage_loop.gd
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/rune_trigger_loop.gd
```

### Risks

- Correct normalization may cause previously inactive augment or rune effects to start triggering. Treat this as a behavior fix, then rebalance later if needed.
- If `TagUtils.gd` is added as an autoload, update `project.godot` carefully. If not autoloaded, load it consistently.

---

## Task 4: Emit `wave_phase_started` from `SpawnSystem`

**Priority:** P1

**Problem:** `GameEvents.wave_phase_started` exists and `AugmentSystem` listens to it, but the wave or spawn system does not reliably emit it. This leaves wave-triggered augment logic and wave UI feedback disconnected.

**Write Scope:**

- Modify: `scripts/systems/SpawnSystem.gd`
- Modify if needed: `autoload/GameEvents.gd`
- Modify if needed: `autoload/AugmentSystem.gd`
- Modify if needed: `data/resources/wave_data.gd`
- Modify if needed: `data/content/waves/m1_wave.tres`
- Modify if needed: `scripts/ui/HUD.gd`
- Create: `tests/smoke/wave_phase_started_signal_contract.gd`

### Implementation Steps

- [ ] Inspect the current wave phase data shape.
- [ ] If phases have no stable id, derive one from index: `"phase_%d" % phase_index`.
- [ ] Store `_active_phase_id` or `_active_phase_index` in `SpawnSystem`.
- [ ] When the active phase changes, emit `GameEvents.wave_phase_started`.
- [ ] Ensure the first phase emits once at run start.
- [ ] Ensure later phases emit once at their transition points.
- [ ] Include a stable payload with phase id, elapsed time, wave level or phase index, and source.
- [ ] Confirm `AugmentSystem._on_wave_phase_started()` receives the event.
- [ ] Add a short HUD wave-change notification if the current HUD already has a compatible feedback path.

### Acceptance Criteria

- [ ] Phase 0 emits exactly once.
- [ ] Later phase transitions emit exactly once.
- [ ] The event is not emitted every frame.
- [ ] The payload is stable enough for tests and augment conditions.
- [ ] HUD can display a wave-change prompt, if UI integration is included.

### Verification

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/wave_phase_started_signal_contract.gd
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/m1_wave_spawn_loop.gd
```

### Risks

- If phase ids are generated from array index, reordering phases changes ids. For long-term content, explicit phase ids are better.
- If time authority is still duplicated, phase event tests may be flaky. Prefer doing Task 2 before this task.

---

## Task 5: Add Main Scene Headless Playable Smoke

**Priority:** P1

**Problem:** Existing smoke scripts cover several systems, but there should be one integration test proving the actual main scene can run as a playable loop without softlock or missing resources.

**Write Scope:**

- Create: `tests/smoke/main_playable_loop.gd`
- Modify if needed: existing test helpers under `tests/`
- Modify game scripts only if a small, explicit testability seam is required

### Test Goal

Load `res://scenes/Main.tscn` headlessly, run it for 30-60 seconds, and verify that core gameplay events occur.

### Implementation Steps

- [ ] Instantiate `res://scenes/Main.tscn`.
- [ ] Wait for scene ready and initial run startup.
- [ ] Locate key nodes:
  - `Player`
  - enemies root
  - projectiles root
  - pickups root
  - `HUD`
  - `LevelUpPanel`
  - `SpawnSystem`
  - `RunTimerSystem`
- [ ] Connect to relevant `GameEvents` counters:
  - weapon fired
  - projectile spawned
  - weapon hit or projectile hit
  - enemy killed
  - experience collected
  - level-up requested or options shown
- [ ] Simulate enough physics/process frames for combat to happen.
- [ ] If the level-up panel appears, choose the first valid option.
- [ ] Fail the test if the game gets stuck in `LEVEL_UP` with no visible/recoverable choice.
- [ ] Fail the test if required nodes are missing.
- [ ] Fail the test if no enemy, weapon, damage, or experience activity happens within the time budget.

### Acceptance Criteria

- [ ] `scenes/Main.tscn` loads in headless mode.
- [ ] The run starts.
- [ ] At least one enemy spawns.
- [ ] At least one weapon attack occurs.
- [ ] At least one combat hit or damage event occurs.
- [ ] Experience or level-up flow is observed.
- [ ] The game does not softlock in `LEVEL_UP`.
- [ ] The script exits with code 0.

### Verification

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/main_playable_loop.gd
```

### Risks

- Headless mode may not naturally simulate player movement. The test may need to move the player by setting position or injecting input.
- If the player kills enemies too slowly, the test should use controlled setup rather than relying only on default balance.
- The test should avoid becoming a brittle visual test. It should validate gameplay signals and node contracts.

---

## Recommended Execution Order

1. [ ] Task 1: Fix `LevelUpPanel` softlock.
2. [ ] Task 2: Unify `GameRuntime` and `RunTimerSystem` time authority.
3. [ ] Task 3: Unify tag normalization.
4. [ ] Task 4: Emit `wave_phase_started` from `SpawnSystem`.
5. [ ] Task 5: Add main scene headless playable smoke.

Task 5 can be started as a skeleton earlier, but it should become the final acceptance gate after Tasks 1-4 are complete.

---

## Final Acceptance Checklist

- [ ] `experience_levelup_loop.gd` passes.
- [ ] `level_up_empty_options_does_not_softlock.gd` passes.
- [ ] `level_up_invalid_choice_keeps_panel_visible.gd` passes.
- [ ] `run_timer_authority_contract.gd` passes.
- [ ] `tag_normalization_contract.gd` passes.
- [ ] `weapon_damage_loop.gd` passes.
- [ ] `rune_trigger_loop.gd` passes.
- [ ] `wave_phase_started_signal_contract.gd` passes.
- [ ] `m1_wave_spawn_loop.gd` passes.
- [ ] `main_playable_loop.gd` passes.

Final full command set:

```powershell
$godot = 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/smoke/experience_levelup_loop.gd
& $godot --headless --path . --script res://tests/smoke/level_up_empty_options_does_not_softlock.gd
& $godot --headless --path . --script res://tests/smoke/level_up_invalid_choice_keeps_panel_visible.gd
& $godot --headless --path . --script res://tests/smoke/run_timer_authority_contract.gd
& $godot --headless --path . --script res://tests/smoke/tag_normalization_contract.gd
& $godot --headless --path . --script res://tests/smoke/weapon_damage_loop.gd
& $godot --headless --path . --script res://tests/smoke/rune_trigger_loop.gd
& $godot --headless --path . --script res://tests/smoke/wave_phase_started_signal_contract.gd
& $godot --headless --path . --script res://tests/smoke/m1_wave_spawn_loop.gd
& $godot --headless --path . --script res://tests/smoke/main_playable_loop.gd
```

---

## Definition of Done

This plan is complete when the project has a stable M1 gameplay safety net:

- Upgrade choice cannot softlock the run.
- Run elapsed time has one authoritative source.
- Tags normalize consistently across weapon, damage, rune, and augment systems.
- Wave phase transitions emit a real gameplay event.
- Main scene can run headlessly through a short playable loop without missing critical nodes or getting stuck.

After this plan, the next development phase should focus on M2 gameplay depth: weapon identity, rune trigger feedback, augment route behavior, enemy variety, and UI readability.
