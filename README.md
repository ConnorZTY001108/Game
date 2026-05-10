# 符文荒原幸存者 / Runebound Wasteland Survivor

Godot 4 俯视角 survivor-like 原型。当前分支 `m1-vertical-slice` 的目标是交付 M1 纵向切片：可运行的战斗循环、波次推进、武器差异、符文路线、战斗反馈、结算 UI 与基础 2D 资源替换。

## M1 范围

M1 覆盖：

- `scenes/Main.tscn` 启动主入口，并进入 `scenes/run/RunScene.tscn`。
- player-follow camera：玩家移动时 Camera2D 跟随，HUD / LevelUpPanel / DebugOverlay 保持 screen-fixed。
- off-screen enemy spawning：敌人从当前 camera viewport 外生成。
- 5-8 minute wave pacing：当前 M1 run duration 为 360 秒，并按 early / mid / late phase 增压。
- 至少 2 个行为不同的 weapons：`rune_bolt` projectile 与 `sigil_orbit` orbit pulse。
- 至少 3 类 enemies：basic `dust_thrall`、fast `ash_runner`、high-health `bone_brute`。
- 至少 2 条 rune build routes：`scorch_projectile` 与 `storm_orbit`。
- 基础 combat feedback：hit / kill / rune trigger / upgrade / player damage feedback。
- 可读 upgrade choices：升级按钮包含 name、route/effect summary、details/condition。
- victory / defeat settlement UI：run 结束后显示 result 与 run summary。
- player、basic enemy、fast enemy、high-health enemy 使用 PNG 2D asset replacement，不再使用 M0 Polygon2D placeholder 作为主视觉。

## 运行方式

推荐用 Godot 4.6.2 打开本目录，或直接用以下 console executable。

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --version
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --path .
```

Headless 启动主场景可用：

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --quit-after 2
```

## Smoke 验证

每个 smoke script 使用固定命令格式：

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/<script>.gd --quit-after 1
```

M1 final acceptance smoke 列表：

- `parse_all_scripts.gd`
- `load_core_scenes.gd`
- `camera_follow_contract.gd`
- `m1_wave_spawn_loop.gd`
- `m1_weapon_variety_loop.gd`
- `m1_rune_routes_loop.gd`
- `m1_feedback_settlement_loop.gd`
- `m1_visual_assets_contract.gd`
- `weapon_damage_loop.gd`
- `experience_levelup_loop.gd`
- `rune_trigger_loop.gd`
- `contact_damage_finish_loop.gd`

2026-05-10 final acceptance：上述 12 个 smoke 使用 Godot `4.6.2.stable.official.71f334935` 全部 PASS。详细记录见 `docs/qa/m1-acceptance.md`。

## M1.5-M1.7 Playability Pass

- M1.5 adds fixed landmarks, terrain regions, and region prompts so movement has readable map context.
- M1.6 adds rune obelisks, XP caches, hazard rifts, and a one-time ambush point as fixed map objectives.
- M1.7 cleans up player-facing Chinese UI, feedback hooks, hidden-by-default debug overlay, and settlement summaries.

The current skill, weapon, and rune system remains temporary and intentionally frozen in this pass. No final skill redesign or new final rune route is included in M1.5-M1.7.

## 已知风险

- 本轮未执行窗口化 manual playtest；自动 smoke 覆盖结构、资源、核心 loop 和结算契约，但无法替代实机观察 camera feel、视觉可读性、反馈节奏和输入手感。
- PNG 资源对应的 `.import` sidecar 必须保留，例如 `assets/characters/player_wasteland_walker.png.import` 与 `assets/enemies/*.png.import`。缺失 sidecar 可能导致 Godot 资源导入或贴图引用异常。
- Headless smoke 不验证长期 360 秒完整游玩中的主观压力曲线、屏幕拥挤度、字体可读性和低帧率表现。
- `tools/create_m0_scenes.gd` 是 M0 generator；不要用它重生成 M1+ scenes，否则可能把 `RunScene` 绑定回 M0 配置。
