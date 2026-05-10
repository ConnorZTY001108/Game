# M1 验收记录

日期：2026-05-10
Godot 版本：`4.6.2.stable.official.71f334935`
工作区：`C:\Users\19612\Desktop\符文荒原幸存者_Godot项目`
分支：`m1-vertical-slice`
执行角色：M1 Task 7 Integration Acceptance / README / QA 归档 subagent

## 顶部验收 Checklist

| 项目 | 状态 | Smoke evidence / 说明 |
|---|---|---|
| GDScript parse/load | PASS | `parse_all_scripts.gd` exit 0，输出 `PASS: all scripts loaded` |
| Core scenes/resources load | PASS | `load_core_scenes.gd` exit 0，输出 `PASS: core scenes, resources, and M1 visual contract loaded` |
| Player-follow camera contract | PASS | `camera_follow_contract.gd` exit 0，覆盖 `World/Player/Camera2D` 与 CanvasLayer UI contract |
| Off-screen enemy spawning / wave phases | PASS | `m1_wave_spawn_loop.gd` exit 0，覆盖 phase selection、off-screen spawning、`max_alive` |
| 2 distinct weapons | PASS | `m1_weapon_variety_loop.gd` exit 0，覆盖 projectile weapon 与 orbit pulse weapon 的行为差异 |
| 2 rune build routes | PASS | `m1_rune_routes_loop.gd` exit 0，覆盖 `scorch_projectile` 与 `storm_orbit` route generation / apply / trigger |
| Combat feedback and settlement UI contract | PASS | `m1_feedback_settlement_loop.gd` exit 0，覆盖 damage number、player damage、kill、upgrade、rune、victory / defeat settlement |
| 2D asset replacement contract | PASS | `m1_visual_assets_contract.gd` exit 0，覆盖 player/enemy 主视觉为 Sprite2D PNG asset，非 Polygon2D placeholder |
| M0 weapon damage regression | PASS | `weapon_damage_loop.gd` exit 0 |
| XP / level-up / upgrade regression | PASS | `experience_levelup_loop.gd` exit 0，覆盖 XP pickup、level-up choices 与 readable option text contract |
| Scorch rune regression | PASS | `rune_trigger_loop.gd` exit 0 |
| Contact damage / finish regression | PASS | `contact_damage_finish_loop.gd` exit 0，覆盖 defeat 与 settlement loop |
| Manual playtest | Pending / Manual required | 本轮未执行窗口化 manual playtest；不得标为 PASS |
| Camera feel / HUD fixed-screen visual observation | Pending / Manual required | 自动 smoke 验证结构与 contract；仍需实机移动观察 |
| Wave pacing feel across 360 seconds | Pending / Manual required | 自动 smoke 验证数据与 phase contract；仍需完整或抽样实机观察压力曲线 |
| Enemy silhouette/readability | Pending / Manual required | 自动 smoke 验证 PNG asset replacement；仍需肉眼确认同屏可读性 |
| Combat feedback readability | Pending / Manual required | 自动 smoke 验证事件和 UI contract；仍需实机确认反馈节奏与可读性 |
| Victory / defeat settlement visual QA | Pending / Manual required | 自动 smoke 验证 panel 显示和 summary；仍需窗口化确认版面可读 |

## M1 范围

M1 纵向切片验收目标：

- player-follow camera
- off-screen enemy spawning
- 5-8 minute wave pacing，当前 run duration 为 360 秒
- 至少 2 个行为明显不同的 weapons：`rune_bolt` projectile 与 `sigil_orbit` orbit pulse
- 至少 3 类 enemies：basic `dust_thrall`、fast `ash_runner`、high-health `bone_brute`
- 至少 2 条可感知的 rune build routes：`scorch_projectile` 与 `storm_orbit`
- 基础 combat feedback：hit / kill / rune trigger / upgrade / player damage
- 可读的 upgrade choices：name、route/effect summary、details/condition
- victory 和 defeat settlement UI
- player、basic enemy、fast enemy、high-health enemy 使用 2D asset replacement，而不是 M0 Polygon2D placeholders

## 自动验证命令

每个 smoke script 使用固定命令格式：

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/<script>.gd --quit-after 1
```

## 全量 Smoke 结果

| Script | Result | Evidence |
|---|---|---|
| `res://tests/smoke/parse_all_scripts.gd` | PASS | exit 0；`PASS: all scripts loaded` |
| `res://tests/smoke/load_core_scenes.gd` | PASS | exit 0；`PASS: core scenes, resources, and M1 visual contract loaded` |
| `res://tests/smoke/camera_follow_contract.gd` | PASS | exit 0；`PASS: RunScene player-follow camera and CanvasLayer contract` |
| `res://tests/smoke/m1_wave_spawn_loop.gd` | PASS | exit 0；`PASS: M1 wave phase selection, off-screen spawning, and max_alive contract` |
| `res://tests/smoke/m1_weapon_variety_loop.gd` | PASS | exit 0；`PASS: M1 weapon variety projectile and orbit pulse loop` |
| `res://tests/smoke/m1_rune_routes_loop.gd` | PASS | exit 0；`PASS: M1 rune routes, readable options, and orbit weapon pick` |
| `res://tests/smoke/m1_feedback_settlement_loop.gd` | PASS | exit 0；`PASS: M1 feedback and settlement loop` |
| `res://tests/smoke/m1_visual_assets_contract.gd` | PASS | exit 0；`PASS: M1 visual asset replacement contract` |
| `res://tests/smoke/weapon_damage_loop.gd` | PASS | exit 0；`PASS: weapon projectile damage and enemy death loop` |
| `res://tests/smoke/experience_levelup_loop.gd` | PASS | exit 0；`PASS: experience drop, pickup collection, level-up choices` |
| `res://tests/smoke/rune_trigger_loop.gd` | PASS | exit 0；`PASS: rune upgrade and element trigger loop` |
| `res://tests/smoke/contact_damage_finish_loop.gd` | PASS | exit 0；`PASS: contact damage defeat and settlement loop` |

## Manual / Play-facing 记录

本轮未执行 manual playtest。原因：Task 7 只做最终集成验收文档归档，当前验证使用 headless Godot smoke。

自动 smoke 已覆盖：

- scripts parse/load
- core scenes/resources load
- player-follow camera scene contract
- CanvasLayer UI parent contract
- wave data、phase selection、off-screen spawn、`max_alive`
- projectile weapon 与 orbit pulse weapon 的行为差异
- two rune routes 的 generation / apply / trigger
- XP、level-up、upgrade choice readable text contract
- hit / kill / rune / upgrade / player damage feedback event contract
- victory / defeat settlement panel contract
- PNG asset replacement contract
- M0 weapon、XP、rune、contact damage regression

自动 smoke 未覆盖，仍需人工观察：

- camera follow feel 是否舒适
- HUD / LevelUpPanel / DebugOverlay 在实际移动和战斗中是否稳定、清晰
- 360 秒波次压力曲线是否主观合理
- player / basic / fast / high-health enemy 在实际缩放、移动和受击反馈中是否可读
- hit / kill / rune trigger / upgrade / player damage feedback 是否足够明显
- victory / defeat settlement panel 的文字、间距和层级是否在窗口中可读

## 人工验收清单

| Requirement | Manual check | Result | Evidence |
|---|---|---|---|
| Player-follow camera | Start run, move with WASD, confirm camera follows player while HUD stays fixed | Pending / Manual required | 自动验证 PASS：`camera_follow_contract.gd`；仍需人工观察 actual follow feel |
| Off-screen spawning | Stand still and move; confirm enemies enter from outside visible viewport, not directly on top of player | Pending / Manual required | 自动验证 PASS：`m1_wave_spawn_loop.gd`；仍需窗口化观察实际进入方式 |
| 5-8 minute pacing | Confirm run duration is 300-480 seconds and phase pressure changes over time | Pending / Manual required | 自动验证 PASS：`m1_wave_spawn_loop.gd` 验证 360 秒与 phase contract；仍需实机观察压力曲线 |
| 2 distinct weapons | Obtain/use both weapons; confirm behavior differs by attack pattern, not only numbers | Pending / Manual required | 自动验证 PASS：`m1_weapon_variety_loop.gd` 覆盖 projectile vs orbit pulse |
| 3 enemy classes | Observe basic, fast, and high-health enemies with distinct speed/health/silhouette | Pending / Manual required | 自动验证 PASS：`m1_wave_spawn_loop.gd` 与 `m1_visual_assets_contract.gd`；仍需肉眼确认 silhouette |
| 2 rune routes | Choose upgrades from both routes; confirm route labels and effects are perceivable in combat | Pending / Manual required | 自动验证 PASS：`m1_rune_routes_loop.gd` 覆盖 `scorch_projectile` 与 `storm_orbit` |
| Combat feedback | Confirm hit, kill, rune trigger, upgrade, and player damage feedback are visible/readable | Pending / Manual required | 自动验证 PASS：`m1_feedback_settlement_loop.gd`；仍需观察反馈是否足够明显 |
| Upgrade readability | Trigger level-up; confirm each option has readable name, route/effect, and condition text | Pending / Manual required | 自动验证 PASS：`experience_levelup_loop.gd` 检查多行 option text contract |
| Victory settlement | Trigger or survive to victory; confirm settlement panel shows result and run summary | Pending / Manual required | 自动验证 PASS：`m1_feedback_settlement_loop.gd`；仍需窗口化确认版面 |
| Defeat settlement | Die from contact damage; confirm settlement panel shows defeat and run summary | Pending / Manual required | 自动验证 PASS：`contact_damage_finish_loop.gd`；仍需窗口化确认版面 |
| 2D asset replacement | Confirm player/basic/fast/high-health visuals use 2D assets rather than Polygon2D placeholders | Pending / Manual required | 自动验证 PASS：`m1_visual_assets_contract.gd`；仍需肉眼确认清晰度 |

## 已知风险

- 未执行窗口化 manual playtest；本文件不能声明人工验收 PASS。
- Headless smoke 无法验证主观手感、视觉层级、字体可读性、反馈节奏、长期 performance 或 360 秒完整游玩体验。
- PNG 资源的 `.import` sidecar 必须与 `.png` 一起保留；缺失 sidecar 可能导致 Godot 导入缓存或 texture 引用异常。
- `tools/create_m0_scenes.gd` 是 M0 generator，不应在 M1+ 上重新生成当前 scenes，否则可能覆盖 M1 scene/resource wiring。

## Task 7 归档结论

- 全量 12 个 smoke：PASS。
- `README.md` 已更新为 M1 当前入口文档，包含范围、运行方式、固定 Godot command、smoke 列表与已知风险。
- `docs/qa/m1-acceptance.md` 已更新为最终集成验收归档；自动项标为 PASS，纯人工项保留 `Pending / Manual required`。
- 未修改 gameplay code。

## M1.5 Map Readability

Date: 2026-05-10
Role: M1.5 worker
Status: Automated smoke PASS; windowed manual visual check still required.
Automated smoke result: PASS in final 15-smoke regression (`m15_map_readability_contract.gd`, exit 0, `PASS: M1.5 map readability contract`).
Manual status: Pending / Manual required. No windowed 1280x720 play-facing validation was performed in final integration.

Implemented scope:
- Added `World/Map/MapDirector` to `RunScene`.
- Added fixed map landmarks: `spawn_altar`, `broken_tower`, `glowing_rift_landmark`, `ruin_gate`.
- Added fixed regions: `altar_region`, `ash_region`, `stone_region`.
- Added priority-based region selection and retained the previous known region when no region contains the player.
- Added `GameEvents.map_region_changed` and `GameEvents.map_landmark_hint_changed` without removing existing signals.
- Added runtime HUD `RegionPromptLabel` that shows the Chinese region name for about 1.5 seconds and fades/hides.
- Added placeholder map visuals using built-in Godot nodes only; no external art dependencies.

Automated smoke evidence:

| Script | Result | Evidence |
|---|---|---|
| `res://tests/smoke/m15_map_readability_contract.gd` | PASS | `PASS: M1.5 map readability contract` |
| `res://tests/smoke/parse_all_scripts.gd` | PASS | `PASS: all scripts loaded` |
| `res://tests/smoke/load_core_scenes.gd` | PASS | `PASS: core scenes, resources, and M1 visual contract loaded` |
| `res://tests/smoke/m1_visual_assets_contract.gd` | PASS | `PASS: M1 visual asset replacement contract` |

Manual check still needed:
- Confirm in a windowed run that the four landmark placeholders read clearly during movement.
- Confirm region prompt timing/readability by moving from spawn to the ash and stone regions.
- Confirm enemies remain readable against the region tint and landmark shapes.

Known risks:
- Map layout is fixed-coordinate prototype content, not final procedural generation.
- Landmark and region visuals are prototype-quality and still need windowed readability validation.
- Skill design remains temporary and intentionally frozen during this pass.

## M1.6 Map Objectives

Date: 2026-05-10
Role: M1.6 worker
Status: Automated smoke PASS; windowed manual visual check still required.
Automated smoke result: PASS in final 15-smoke regression (`m16_map_objectives_loop.gd`, exit 0, `PASS: M1.6 map objectives loop`).
Manual status: Pending / Manual required. No windowed 1280x720 play-facing validation was performed in final integration.

Implemented scope:
- Added map objective counters and summary API on `GameEvents`.
- Added `MapObjectiveSystem` under `World/Map/MapDirector/Objectives`.
- Added three one-time rune obelisks: `obelisk_altar`, `obelisk_ash`, `obelisk_stone`.
- Added two one-time XP caches: `xp_cache_north`, `xp_cache_west`.
- Added two timed hazard rifts: `rift_ash_01`, `rift_ash_02`.
- Added one one-time ambush point: `ruin_gate_ambush`.
- Added HUD objective text plus short map event/reward prompts.
- Added settlement map objective summary through `RunScene` payload.

Automated smoke evidence:

| Script | Result | Evidence |
|---|---|---|
| `res://tests/smoke/m16_map_objectives_loop.gd` | PASS | `PASS: M1.6 map objectives loop` |

Manual check still needed:
- Opening HUD shows `目标：激活符文碑 0/3`.
- Player can reach and activate all 3 obelisks.
- Each obelisk gives visible feedback and a reward prompt.
- XP caches generate pickups once.
- Hazard rifts show warning before active damage.
- Ruin gate ambush spawns enemies away from the player.
- Settlement records obelisk count and map event count.

Known risks:
- Map layout remains fixed-coordinate prototype content.
- Hazard/ambush balance is smoke-tested but still needs windowed play feel validation.
- Current skill and weapon systems remain intentionally frozen for this pass.
- `m16_map_objectives_loop.gd` still prints `WARNING: ObjectDB instances leaked at exit`; it did not fail the smoke command.

## M1.7 Feedback and UI

Date: 2026-05-10
Role: M1.7 worker
Status: Automated smoke PASS; windowed manual visual check still required.
Automated smoke result: PASS in final 15-smoke regression (`m17_feedback_ui_contract.gd`, exit 0, `PASS: M1.7 feedback and UI contract`).
Manual status: Pending / Manual required. No windowed 1280x720 play-facing validation was performed in final integration.

Implemented scope:
- Converted settlement result and run-summary labels to Simplified Chinese while preserving the M1.6 map objective summary.
- Converted `GameEvents` upgrade, rune-trigger, and defeat feedback prefixes to Chinese.
- Hid `RunScene/CanvasLayer/DebugOverlay` by default while keeping the node in place.
- Added enemy hit flash with `is_hit_flash_active()` and a short separate death fade/shrink visual so `enemy_died` and XP drop behavior remain unchanged.
- Added player damage blink with `is_damage_blink_active()` without changing contact damage rate or health math.
- Kept the temporary upgrade pool unchanged and made LevelUpPanel options render as three wrapped readable lines.
- Added a visible HUD feedback label cap and separated map event/reward prompts from normal floating feedback labels.
- Updated existing settlement/contact smoke assertions from English to Chinese text.

Automated smoke evidence:

| Script | Result | Evidence |
|---|---|---|
| `res://tests/smoke/m17_feedback_ui_contract.gd` | PASS | `PASS: M1.7 feedback and UI contract` |
| `res://tests/smoke/m15_map_readability_contract.gd` | PASS | `PASS: M1.5 map readability contract` |
| `res://tests/smoke/m16_map_objectives_loop.gd` | PASS | `PASS: M1.6 map objectives loop` |
| `res://tests/smoke/parse_all_scripts.gd` | PASS | `PASS: all scripts loaded` |
| `res://tests/smoke/load_core_scenes.gd` | PASS | `PASS: core scenes, resources, and M1 visual contract loaded` |
| `res://tests/smoke/m1_feedback_settlement_loop.gd` | PASS | `PASS: M1 feedback and settlement loop` |
| `res://tests/smoke/contact_damage_finish_loop.gd` | PASS | `PASS: contact damage defeat and settlement loop` |
| `res://tests/smoke/weapon_damage_loop.gd` | PASS | `PASS: weapon projectile damage and enemy death loop` |

Manual check still needed:
- Confirm default gameplay starts without the debug overlay visible.
- Confirm enemy hit flash, enemy death feedback, and player damage blink are visible but not noisy.
- Confirm the Chinese settlement panel and three-line upgrade choices fit cleanly in a windowed 1280x720 run.
- Confirm map objective, region, event, and reward prompts do not obscure combat readability.

Known risks:
- No windowed/manual visual QA was run in this worker.
- Feedback timing and intensity are smoke-tested structurally but still need tuning from actual play.
- Skill, weapon, and rune design remain intentionally frozen and temporary.

## M1.5-M1.7 Final Integration

Date: 2026-05-10
Role: M1.5-M1.7 Final Integration and Documentation worker
Status: DONE_WITH_CONCERNS. Automated full regression passed; manual/windowed QA remains pending.

Automated smoke result:

| Script | Result | Evidence |
|---|---|---|
| `res://tests/smoke/parse_all_scripts.gd` | PASS | exit 0; `PASS: all scripts loaded` |
| `res://tests/smoke/load_core_scenes.gd` | PASS | exit 0; `PASS: core scenes, resources, and M1 visual contract loaded` |
| `res://tests/smoke/camera_follow_contract.gd` | PASS | exit 0; `PASS: RunScene player-follow camera and CanvasLayer contract` |
| `res://tests/smoke/m1_wave_spawn_loop.gd` | PASS | exit 0; `PASS: M1 wave phase selection, off-screen spawning, and max_alive contract` |
| `res://tests/smoke/m1_weapon_variety_loop.gd` | PASS | exit 0; `PASS: M1 weapon variety projectile and orbit pulse loop` |
| `res://tests/smoke/m1_rune_routes_loop.gd` | PASS | exit 0; `PASS: M1 rune routes, readable options, and orbit weapon pick` |
| `res://tests/smoke/m1_feedback_settlement_loop.gd` | PASS | exit 0; `PASS: M1 feedback and settlement loop` |
| `res://tests/smoke/m1_visual_assets_contract.gd` | PASS | exit 0; `PASS: M1 visual asset replacement contract` |
| `res://tests/smoke/weapon_damage_loop.gd` | PASS | exit 0; `PASS: weapon projectile damage and enemy death loop` |
| `res://tests/smoke/experience_levelup_loop.gd` | PASS | exit 0; `PASS: experience drop, pickup collection, level-up choices` |
| `res://tests/smoke/rune_trigger_loop.gd` | PASS | exit 0; `PASS: rune upgrade and element trigger loop` |
| `res://tests/smoke/contact_damage_finish_loop.gd` | PASS | exit 0; `PASS: contact damage defeat and settlement loop` |
| `res://tests/smoke/m15_map_readability_contract.gd` | PASS | exit 0; `PASS: M1.5 map readability contract` |
| `res://tests/smoke/m16_map_objectives_loop.gd` | PASS | exit 0; `PASS: M1.6 map objectives loop`; emitted `WARNING: ObjectDB instances leaked at exit` |
| `res://tests/smoke/m17_feedback_ui_contract.gd` | PASS | exit 0; `PASS: M1.7 feedback and UI contract` |

Manual status: Pending / Manual required. Final integration did not run `& $godot --path .` or a windowed 1280x720 playtest, so play-facing visual QA is not marked PASS.

Definition of Done check:
- PASS by automated smoke: 4 landmarks, at least 3 regions, region prompt contract, exactly 3 activatable rune obelisks, HUD obelisk progress, at least 2 XP caches, 2 hazard rifts, 1 ambush trigger, hazard warning/active states, settlement map objective summary, Chinese player-facing UI contract, hidden default debug overlay, enemy/player feedback hooks, existing 12 M1 smoke PASS, and new M1.5/M1.6/M1.7 smoke PASS.
- Pending / Manual required: first-screen landmark readability, visual distinctness of all regions, play-facing feedback clarity, 1280x720 LevelUpPanel readability, and overall movement/combat readability in a real window.

Residual risks:
- Skill system is temporary and intentionally frozen; this pass did not redesign skills, weapons, rune routes, or balance.
- Map layout uses fixed coordinates and is not final procedural generation.
- Visual resources and placeholder map assets are prototype-quality.
- Balance and long-run pacing need a separate pass after map direction and skill direction stabilize.
- `m16_map_objectives_loop.gd` still produces an ObjectDB leak warning despite exit 0.
