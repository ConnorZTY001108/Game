# Runebound Wasteland M1 Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 M0 最小循环扩展成可试玩的 M1 纵向切片：跟随相机、屏幕外刷怪、5-8 分钟波次、2 把可区分武器、3 类敌人、2 条可感知符文构筑路线、基础战斗反馈、可读升级选择、胜负结算界面，以及主角/基础/快速/厚血敌人的 2D 资源替换。

**Architecture:** 保持 M0 的 Scene + Resource 边界：实体仍由 scene/script 驱动，数值和内容优先落在 `data/resources/*.gd` 与 `data/content/**/*.tres`，运行期状态继续由 autoload 统一管理。M1 任务按文件所有权串行拆分，避免两个 subagent 并行写同一脚本或同一 scene；新增核心行为必须配套 smoke script 或 QA 记录。

**Tech Stack:** Godot 4.6.2, GDScript 2.0, Godot Resource (`.tres`), Scene (`.tscn`), PowerShell, Godot headless smoke scripts.

---

## 当前基线摘要

工作目录固定为 `C:\Users\19612\Desktop\符文荒原幸存者_Godot项目`。当前分支应为 `m1-vertical-slice`。

已检查的 M0 文件：

- `README.md`：记录显式 Godot 4.6.2 console executable 和 M0 验收面。
- `project.godot`：main scene 为 `res://scenes/Main.tscn`，autoload 已注册 `GameEvents`, `GameRuntime`, `DamageSystem`, `ElementStatusSystem`, `RuneSystem`, `ExperienceSystem`, `UpgradeSystem`。
- `scripts/run/RunScene.gd`：只绑定 player/HUD/timer/debug overlay 并启动 run；目前没有 camera 绑定或 settlement UI。
- `scripts/systems/SpawnSystem.gd`：使用单一 `WaveData.enemy_data`、固定 `spawn_interval`、`max_alive`、`spawn_radius`，围绕 player 半径刷怪。
- `scripts/weapons/WeaponController.gd`：单自动瞄准 projectile 模式，读 `WeaponData` 的 damage/cooldown/range/pierce/tags。
- `data/resources/*.gd`：已有 `CharacterData`, `EnemyData`, `RuneData`, `UpgradeData`, `WaveData`, `WeaponData`，但 `WaveData` 还不支持 phase/enemy pool，`WeaponData` 还不支持多模式表现字段。
- `data/content/**/*.tres`：M0 有 1 主角、1 武器、1 rune、1 enemy、1 wave、4 upgrade。
- `tests/smoke/*.gd`：现有 smoke 覆盖脚本加载、核心 scene/resource 加载、武器伤害、XP/升级、rune trigger、接触伤害/胜负状态。
- `docs/qa/m0-smoke-test.md`：M0 headless 全部 PASS，manual editor playtest 尚未执行。

M0 观察到的实现约束：

- `LevelUpPanel.gd` 当前按钮文本是 `display_name - description`，M1 可读性需要在这里和 `UpgradeData` 字段上扩展。
- `UpgradeSystem.OPTIONS` 是静态数组，新增 rune/weapon/route 选项会改这个文件；所有升级池改动必须集中到同一任务。
- `RunTimerSystem.gd` 默认 180 秒，M1 需要改成 5-8 分钟并让 wave 节奏使用同一时间源。
- `load_core_scenes.gd` 有视觉 contract，当前要求 player/enemy/projectile/pickup 有 `Polygon2D Outline` 和 `Visual`；M1 资源替换需要同步更新该 contract，而不是让旧 Polygon2D 要求误判。

## 全局执行规则

- 每个 subagent 开始前运行 `git status --short --branch`，确认没有未说明的冲突；只修改本任务列出的文件。
- 不允许并行写同一文件。下面任务顺序就是交接顺序；除非标注为“可并行”，否则按序执行。
- 每个实现任务完成后至少运行该任务列出的 smoke；最终集成任务必须运行全量 smoke。
- 固定 Godot 验证命令格式：

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script <test> --quit-after 1
```

- `<test>` 使用 `res://tests/smoke/<script>.gd`。
- 新增核心玩法或资源接入必须满足二选一：新增/更新 `tests/smoke/*.gd` 自动验证，或在 `docs/qa/m1-acceptance.md` 增加明确 manual check。核心系统优先自动化。

## 文件所有权和冲突表

| 文件/目录 | M1 责任 | 写入任务 | 并行限制 |
|---|---|---:|---|
| `scripts/run/RunScene.gd`, `scenes/run/RunScene.tscn` | camera、system wiring、settlement panel mount | Task 1, Task 5 | 串行，Task 5 等 Task 1 合并后再改 |
| `scripts/systems/SpawnSystem.gd`, `data/resources/wave_data.gd`, `data/content/waves/*.tres` | 屏幕外刷怪、phase/wave 节奏、enemy pool | Task 2 | 不能和 Task 1/3 并行写 scene wiring |
| `data/resources/enemy_data.gd`, `data/content/enemies/*.tres`, `scripts/enemies/Enemy.gd` | 3 类敌人数值和 behavior | Task 2 | Task 6 可读 enemy scene，但等 Task 2 完成后替换 visual |
| `data/resources/weapon_data.gd`, `data/content/weapons/*.tres`, `scripts/weapons/WeaponController.gd` | 2 把可区分武器 | Task 3 | 不能和 Task 4 并行改 upgrade content 引用 |
| `autoload/UpgradeSystem.gd`, `autoload/RuneSystem.gd`, `data/content/runes/*.tres`, `data/content/upgrades/*.tres`, `scripts/ui/LevelUpPanel.gd` | 2 条 rune 构筑路线、升级选择可读性 | Task 4 | 所有升级池改动集中在 Task 4 |
| `autoload/GameEvents.gd`, `scripts/projectiles/Projectile.gd`, `scripts/components/HealthComponent.gd`, `scripts/ui/HUD.gd`, `scripts/ui/SettlementPanel.gd`, `scenes/ui/SettlementPanel.tscn` | 战斗反馈、胜负结算 | Task 5 | `RunScene.tscn` 交接点来自 Task 1 |
| `assets/**`, `scenes/player/Player.tscn`, `scenes/enemies/Enemy.tscn`, enemy variant scenes | 2D 资源替换 Polygon2D | Task 6 | Task 6 在 Task 2 后执行，避免敌人 scene/data 同时变更 |
| `tests/smoke/*.gd`, `docs/qa/m1-acceptance.md`, `README.md` | 自动验证、人工验收、运行说明 | 各任务更新对应 smoke；Task 7 汇总 | Task 7 最后统一修正 |

---

## Task 1: 跟随相机和可扩展 RunScene wiring

**目标：** 玩家移动时 camera 跟随，UI 仍固定在 screen space；为后续 settlement panel 和扩展系统留出稳定节点路径。

**写入范围：**

- Modify: `scenes/run/RunScene.tscn`
- Modify: `scripts/run/RunScene.gd`
- Modify: `tests/smoke/load_core_scenes.gd`
- Create: `tests/smoke/camera_follow_contract.gd`
- Update QA: `docs/qa/m1-acceptance.md`

**依赖：** M0 baseline。必须先于 Task 2、Task 5。

**步骤：**

- [ ] 在 `scenes/run/RunScene.tscn` 的 `World/Player` 下加入 `Camera2D`，设为 current，并保留 `CanvasLayer` 下 HUD/LevelUpPanel/DebugOverlay。
- [ ] 在 `scripts/run/RunScene.gd` 中增加 `@onready var camera: Camera2D = $World/Player/Camera2D`，启动时确认 `camera.enabled = true` 且不把 HUD 挂到 camera 下。
- [ ] 新增 `tests/smoke/camera_follow_contract.gd`，实例化 `RunScene.tscn` 后检查 `World/Player/Camera2D` 存在、`enabled/current` 语义正确、`CanvasLayer/HUD` 仍在 CanvasLayer 下。
- [ ] 更新 `tests/smoke/load_core_scenes.gd`，把 camera contract 纳入核心场景检查。
- [ ] 更新 `docs/qa/m1-acceptance.md` 的 camera manual check：移动玩家时画面跟随，HUD 不漂移。

**验收标准：**

- `World/Player/Camera2D` 存在且随 player 移动。
- HUD、LevelUpPanel、DebugOverlay 不因为 camera 移动改变屏幕位置。
- M0 load core scenes smoke 不回退。

**验证命令：**

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/camera_follow_contract.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/load_core_scenes.gd --quit-after 1
```

**交接点：** Task 2 可以依赖 `RunScene.tscn` 中 player/camera 路径稳定为 `World/Player/Camera2D`。

---

## Task 2: 屏幕外刷怪、5-8 分钟波次、3 类敌人

**目标：** 把 M0 单敌人固定刷怪升级为 M1 波次节奏：在 camera 视口外生成基础/快速/厚血敌人，整局时长落在 5-8 分钟，随时间改变 spawn interval、max alive、enemy mix。

**写入范围：**

- Modify: `data/resources/wave_data.gd`
- Modify: `data/resources/enemy_data.gd` only if behavior/readability fields are required
- Modify: `scripts/systems/SpawnSystem.gd`
- Modify: `scripts/systems/RunTimerSystem.gd`
- Modify: `scenes/run/RunScene.tscn`
- Create/Modify: `data/content/enemies/dust_thrall.tres`
- Create: `data/content/enemies/ash_runner.tres`
- Create: `data/content/enemies/bone_brute.tres`
- Create/Modify: `data/content/waves/m1_wave.tres`
- Modify: `tests/smoke/load_core_scenes.gd`
- Create: `tests/smoke/m1_wave_spawn_loop.gd`
- Update QA: `docs/qa/m1-acceptance.md`

**依赖：** Task 1 completed。不能和 Task 1 并行写 `RunScene.tscn`。

**建议实现边界：**

- `WaveData` 增加 phase 数组时优先使用 Godot 可序列化 Resource 子资源，字段至少覆盖 `start_time`, `duration`, `spawn_interval`, `max_alive`, `spawn_radius`, `enemy_pool`。
- `SpawnSystem` 只负责根据 `GameRuntime.elapsed_seconds` 选当前 phase、从 enemy pool 选 enemy data、计算 screen 外 spawn position；不要把 enemy stats 写死进系统。
- 生成点必须基于 camera viewport 矩形外扩，fallback 才使用 player 半径。这样 headless smoke 可以用固定 viewport/camera 计算。
- `RunTimerSystem.run_duration_seconds` 建议设为 360 秒；满足 5-8 分钟，测试时间短时可直接调用系统函数或手动设置 elapsed，不要让 smoke 等真实 6 分钟。

**步骤：**

- [ ] 扩展 `WaveData`，让它能表达多个 phase 和多个 enemy data。
- [ ] 创建 `ash_runner.tres`：低血量、高移速、较低 contact damage，`id = "ash_runner"`。
- [ ] 创建 `bone_brute.tres`：高血量、低移速、较高 experience value，`id = "bone_brute"`。
- [ ] 保留并更新 `dust_thrall.tres` 作为基础敌人，确保 `id = "dust_thrall"`。
- [ ] 创建 `m1_wave.tres`，至少包含 early/mid/late 三段：early 以基础敌人为主，mid 引入快速敌人，late 引入厚血敌人并提升压力。
- [ ] 将 `RunScene.tscn` 的 `SpawnSystem.wave_data` 指向 `m1_wave.tres`，将 `RunTimerSystem.run_duration_seconds` 设为 300-480 秒范围内的固定值。
- [ ] 改 `SpawnSystem.gd`：支持 phase 选择、enemy pool 选择、max alive、屏幕外 spawn；保留 `enemy_scene` 和 `enemies_path/player_path` 现有 contract。
- [ ] 新增 `m1_wave_spawn_loop.gd`：检查三类 enemy resource 可加载，模拟不同 elapsed time 可选到对应 phase，spawn position 在 camera viewport 外，`max_alive` 生效。
- [ ] 更新 `load_core_scenes.gd` Required paths，加入 `m1_wave.tres`, `ash_runner.tres`, `bone_brute.tres`。
- [ ] 更新 QA 文档，增加 0-2 分钟、2-4 分钟、4 分钟后 enemy mix 的手动观察点。

**验收标准：**

- M1 wave 总时长在 300-480 秒。
- 至少三类敌人可被 `SpawnSystem` 生成，且数值/行为可感知：基础、快速、厚血。
- 生成点在当前 camera viewport 外，不在玩家脸上突然出现。
- M0 XP/drop/contact damage loop 不被破坏。

**验证命令：**

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/m1_wave_spawn_loop.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/contact_damage_finish_loop.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/load_core_scenes.gd --quit-after 1
```

**交接点：** Task 6 只能在三类 enemy resource path 稳定后替换 visual。

---

## Task 3: 至少 2 把可区分武器

**目标：** 在 M0 `rune_bolt` 之外加入第二把明显不同的武器，且玩家能通过升级/构筑获得或强化它。

**写入范围：**

- Modify: `data/resources/weapon_data.gd`
- Modify: `scripts/weapons/WeaponController.gd`
- Modify: `scripts/player/Player.gd` only if mounting multiple weapons requires player-owned weapon list
- Modify/Create: `data/content/weapons/rune_bolt.tres`
- Create: `data/content/weapons/sigil_orbit.tres` or equivalent second weapon
- Create: `data/content/upgrades/weapon_sigil_orbit_pick.tres`
- Create: `tests/smoke/m1_weapon_variety_loop.gd`
- Modify: `tests/smoke/weapon_damage_loop.gd` if payload schema expands
- Update QA: `docs/qa/m1-acceptance.md`

**依赖：** Task 2 can be complete or in progress if it does not touch weapon files. Do not start Task 4 until this task defines final weapon upgrade content paths.

**建议实现边界：**

- 第二武器必须不是只改数值的 projectile clone。推荐 `attack_mode = "orbit"` 或 `attack_mode = "burst"`：
  - `rune_bolt`：远程单体自动 projectile，清理低血敌人。
  - `sigil_orbit`：近身环绕/脉冲，保护玩家周围，适合快速敌人压力。
- `WeaponController` 可以按 `attack_mode` 分支，但不要把具体 content path 写死。
- 如果要多武器并存，优先让 `Player.gd` 的 `WeaponMount` 下创建多个 `WeaponController`，不要把武器逻辑塞进 `RunScene.gd`。

**步骤：**

- [ ] 扩展 `WeaponData` 所需字段，例如 `area_radius`, `tick_interval`, `projectile_count`，保留 M0 字段默认值。
- [ ] 创建第二武器 resource，确保 `display_name` 和 `description` 清楚说明玩法差异。
- [ ] 改 `WeaponController.gd`，按 `weapon_data.attack_mode` 执行 projectile 或第二模式。
- [ ] 增加可获得第二武器的 upgrade resource；若升级池由 Task 4 统一接入，本任务只创建 resource，并在交接说明中列出路径。
- [ ] 新增 `m1_weapon_variety_loop.gd`：分别配置两把 weapon，验证 cooldown/damage/hit area 或 projectile count 的可区分行为。
- [ ] 如果 payload 增加新字段，更新 `weapon_damage_loop.gd` 保证旧 projectile contract 仍过。
- [ ] 更新 QA 文档，加入两把武器的手动识别点：射程、目标选择、命中特效/音效占位、适用敌人类型。

**验收标准：**

- 两把 weapon 均可通过 data resource 加载。
- 第二把 weapon 的实际伤害/攻击方式和 `rune_bolt` 明显不同，不只是 `damage` 或 `cooldown` 不同。
- M0 `weapon_damage_loop.gd` 仍 PASS。

**验证命令：**

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/m1_weapon_variety_loop.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/weapon_damage_loop.gd --quit-after 1
```

**交接点：** Task 4 接管 `UpgradeSystem.OPTIONS`，把本任务创建的 weapon pick 纳入升级池。

---

## Task 4: 两条可感知符文构筑路线和升级选择可读性

**目标：** 升级选择不再只是零散数值；玩家能看懂并选择至少两条路线，例如 “Scorch projectile chain” 和 “Storm/Orbit area route”。

**写入范围：**

- Modify: `autoload/UpgradeSystem.gd`
- Modify: `autoload/RuneSystem.gd`
- Modify: `data/resources/rune_data.gd`
- Modify: `data/resources/upgrade_data.gd`
- Create/Modify: `data/content/runes/*.tres`
- Create/Modify: `data/content/upgrades/*.tres`
- Modify: `scripts/ui/LevelUpPanel.gd`
- Modify: `scenes/ui/LevelUpPanel.tscn`
- Create: `tests/smoke/m1_rune_routes_loop.gd`
- Modify: `tests/smoke/experience_levelup_loop.gd`
- Modify: `tests/smoke/rune_trigger_loop.gd`
- Update QA: `docs/qa/m1-acceptance.md`

**依赖：** Task 3 completed. This task owns all upgrade pool changes.

**建议路线：**

- Route A: Scorch Mark / projectile route。命中叠 scorch，阈值触发 bonus damage，适合基础/厚血敌人。
- Route B: Storm or fracture / orbit route。近身或多目标触发 chain/pulse/slow，适合快速敌人压力。

**可读性要求：**

- 每个 upgrade button 至少显示：名称、路线标签、即时效果、适用武器或触发条件。
- 避免一行超长 `display_name - description`。`LevelUpPanel` 应使用多 Label 或固定宽度 Button/container，保证中文可读。
- 已选择/已装备 rune 不应重复刷出同一唯一 rune，除非设计为升级等级。

**步骤：**

- [ ] 扩展 `RuneData`，加入 `route_id`, `route_label`, `short_effect` 等 UI 可读字段；保留 M0 字段默认兼容。
- [ ] 扩展 `UpgradeData`，加入 `route_id`, `summary`, `details`, `max_rank` 或 `unique`，让 LevelUpPanel 不必拼长 description。
- [ ] 创建第二条 rune route resource 和对应 upgrade resources。
- [ ] 修改 `RuneSystem.gd`，支持第二路线的 trigger/effect；保持 `is_valid_rune()` 对新字段宽容，旧 scorch smoke 仍通过。
- [ ] 修改 `UpgradeSystem.gd`：接入 Task 3 的 weapon pick 和本任务的 route upgrades；生成三选项时避免同屏全是同一路线，避免唯一 rune 重复。
- [ ] 改 `LevelUpPanel.gd/.tscn`：每个选项使用名称、路线、效果三段文本，按钮点击区域清楚。
- [ ] 新增 `m1_rune_routes_loop.gd`：验证两条 route 都能从升级池生成、能装备/触发、触发 payload 可区分。
- [ ] 更新 `experience_levelup_loop.gd`：接受扩展后的升级池，但仍验证 3 choices、pending level-up 不丢失、无效 upgrade 不被应用。
- [ ] 更新 `rune_trigger_loop.gd`：保留 Scorch Mark 旧 contract，并补充新 route 的最小触发检查或放到新 smoke。
- [ ] 更新 QA 文档，增加两条 route 的手动选择路径和预期反馈。

**验收标准：**

- 升级面板每次显示 3 个可读选项。
- 至少两条路线能被玩家识别，并在战斗中产生不同效果。
- 选择路线后，HUD/LevelUpPanel/战斗反馈中至少有一种方式让玩家感知该路线已生效。
- M0 XP/level-up pending selections 不回退。

**验证命令：**

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/m1_rune_routes_loop.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/experience_levelup_loop.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/rune_trigger_loop.gd --quit-after 1
```

**交接点：** Task 5 可以读取 `GameEvents.rune_triggered`, `damage_applied`, `upgrade_selected` 来做反馈，不再改升级池。

---

## Task 5: 基础战斗反馈和胜负结算界面

**目标：** 让伤害、击杀、rune trigger、升级选择、胜负结果有基础但明确的反馈；局末出现可读结算界面。

**写入范围：**

- Modify: `autoload/GameEvents.gd`
- Modify: `scripts/components/HealthComponent.gd`
- Modify: `scripts/projectiles/Projectile.gd`
- Modify: `scripts/enemies/Enemy.gd`
- Modify: `scripts/ui/HUD.gd`
- Create: `scripts/ui/SettlementPanel.gd`
- Create: `scenes/ui/SettlementPanel.tscn`
- Modify: `scenes/run/RunScene.tscn`
- Modify: `scripts/run/RunScene.gd`
- Create: `tests/smoke/m1_feedback_settlement_loop.gd`
- Modify: `tests/smoke/contact_damage_finish_loop.gd`
- Update QA: `docs/qa/m1-acceptance.md`

**依赖：** Task 1 completed; Task 4 preferred so feedback can include route/rune events.

**建议实现边界：**

- 战斗反馈可以先用 lightweight scene/node：floating damage label、hit flash、small screen shake、rune trigger label。M1 不需要完整 VFX pipeline。
- `SettlementPanel` 只展示本局结果、存活时间、击杀数、等级、已选路线/升级摘要，以及 restart/quit placeholder；不要在 M1 引入 meta progression。
- `HUD.gd` 可以继续显示 timer/kills，但最终结果文本应由 `SettlementPanel` 负责，避免 HUD timer label 承担结算 UI。

**步骤：**

- [ ] 梳理 `GameEvents.gd` 现有 signals，新增必要 signals，如 `damage_number_requested`, `feedback_requested`, `settlement_requested`，不删除旧 signal。
- [ ] 在伤害/击杀/rune trigger/upgrade selected 处发出反馈事件，避免 UI 直接耦合 combat scripts。
- [ ] 创建 `SettlementPanel.tscn/.gd`，监听 `run_finished` 或由 `RunScene.gd` 绑定，显示 victory/defeat 和 run summary。
- [ ] 在 `RunScene.tscn` 的 `CanvasLayer` 下挂 `SettlementPanel`，默认 hidden，`process_mode` 支持 paused 状态显示。
- [ ] 实现基础 hit feedback：至少一种视觉反馈能在 headless 中通过节点/文本/信号验证，在手动中可见。
- [ ] 新增 `m1_feedback_settlement_loop.gd`：模拟 damage、enemy death、upgrade/rune event、victory/defeat，验证 feedback node 和 settlement visible/text。
- [ ] 更新 `contact_damage_finish_loop.gd`：胜负状态检查从 HUD timer label 扩展到 SettlementPanel，同时保持 defeat/victory state 检查。
- [ ] 更新 QA 文档，增加战斗反馈和 settlement manual checklist。

**验收标准：**

- 玩家能感知命中/受击/击杀/rune trigger/升级选择至少其中 4 类反馈。
- victory 和 defeat 都显示结算界面。
- 结算界面在 tree paused 时仍可见。
- M0 contact damage finish smoke 不回退。

**验证命令：**

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/m1_feedback_settlement_loop.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/contact_damage_finish_loop.gd --quit-after 1
```

**交接点：** Task 7 最终 QA 使用 SettlementPanel 作为胜负验收入口。

---

## Task 6: 主角/基础/快速/厚血敌人 2D 资源替换 Polygon2D

**目标：** 用可维护的 2D 资源替换 M0 的 Polygon2D 占位外观，覆盖主角、基础敌人、快速敌人、厚血敌人。

**写入范围：**

- Create: `assets/characters/player_wasteland_walker.png` or `.svg/.import` as Godot accepts
- Create: `assets/enemies/dust_thrall.png`
- Create: `assets/enemies/ash_runner.png`
- Create: `assets/enemies/bone_brute.png`
- Modify: `scenes/player/Player.tscn`
- Modify: `scenes/enemies/Enemy.tscn`
- Create if needed: `scenes/enemies/AshRunner.tscn`, `scenes/enemies/BoneBrute.tscn`
- Modify: `scripts/systems/SpawnSystem.gd` only if enemy scenes vary by enemy data
- Modify: `data/resources/enemy_data.gd` only if adding `scene_path` or `visual_texture`
- Modify: `data/content/enemies/*.tres`
- Modify: `tests/smoke/load_core_scenes.gd`
- Create: `tests/smoke/m1_visual_assets_contract.gd`
- Update QA: `docs/qa/m1-acceptance.md`

**依赖：** Task 2 completed. Do not change enemy ids after Task 2 smoke exists.

**资源要求：**

- M1 可使用 hand-authored simple bitmap/vector assets；不需要 final art。
- 每个角色 silhouette 必须不同：player、基础、快速、厚血在截图中能一眼区分。
- 不要只给 Polygon2D 换颜色；验收要求是替换 Polygon2D 占位。

**步骤：**

- [ ] 创建 `assets/characters` 和 `assets/enemies` 下的 2D 资源文件。
- [ ] 将 `Player.tscn` 的 visual 从 `Polygon2D` 占位替换为 `Sprite2D` 或等价 2D asset node；保留碰撞、health、pickup area。
- [ ] 将 enemy visual 替换为数据驱动或 variant scene。若使用 variant scene，`SpawnSystem` 根据 enemy data 选择 scene；若使用 texture 字段，`Enemy.gd` 根据 data 设置 `Sprite2D.texture`。
- [ ] 更新 `load_core_scenes.gd` 的 visual contract：M1 要求 player 和三类 enemy 有 `Sprite2D`/texture 或明确 asset node，不再要求这些实体的 `Visual` 是 `Polygon2D`。
- [ ] 新增 `m1_visual_assets_contract.gd`：加载 player 和三类 enemy，确认 visual node 不再是 Polygon2D，texture/resource 存在，三类 enemy 视觉资源路径不同。
- [ ] 更新 QA 文档，加入截图/手动观察要求：四种实体可区分。

**验收标准：**

- 主角、基础、快速、厚血敌人不再依赖 M0 Polygon2D 作为主要 visual。
- 四个 2D 资源路径存在并能被 Godot 加载。
- 碰撞和受击不因 visual 替换失效。

**验证命令：**

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/m1_visual_assets_contract.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/load_core_scenes.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/weapon_damage_loop.gd --quit-after 1
```

**交接点：** Task 7 只做集成验证，不再调整 art pipeline，除非 smoke 发现 resource load 失败。

---

## Task 7: M1 集成验证、README 和 QA 归档

**目标：** 把各任务输出统一成可验收 M1：所有 smoke 通过，QA 文档记录自动和手动验收，README 更新到 M1。

**写入范围：**

- Modify: `README.md`
- Modify: `docs/qa/m1-acceptance.md`
- Modify: `tests/smoke/load_core_scenes.gd` only for final path corrections
- No gameplay code changes unless fixing smoke-discovered integration bug; if needed, return对应 owner task/subagent。

**依赖：** Task 1-6 completed。

**步骤：**

- [ ] 运行 `git status --short --branch`，确认所有任务输出已在预期文件范围内。
- [ ] 运行全量 smoke commands，逐条记录 PASS/FAIL 到 `docs/qa/m1-acceptance.md`。
- [ ] 进行最短 manual playtest：启动主场景，移动 2 分钟以内观察 camera、screen-off spawning、两类以上敌人、至少一次 level-up、至少一种 route feedback。
- [ ] 用测试快捷或临时 inspector 设置触发 victory/defeat，确认 SettlementPanel。
- [ ] 更新 `README.md`：M1 范围、运行方式、固定 Godot 命令、smoke 列表、已知风险。
- [ ] 若 manual playtest 发现 UI 文本溢出、entity 视觉不可区分、spawn 在屏内突现，创建修复清单并交回对应 owner task，不在 Task 7 大改系统。

**最终全量验证命令：**

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/parse_all_scripts.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/load_core_scenes.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/camera_follow_contract.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/m1_wave_spawn_loop.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/m1_weapon_variety_loop.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/m1_rune_routes_loop.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/m1_feedback_settlement_loop.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/m1_visual_assets_contract.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/weapon_damage_loop.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/experience_levelup_loop.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/rune_trigger_loop.gd --quit-after 1
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/contact_damage_finish_loop.gd --quit-after 1
```

**最终验收标准：**

- 自动 smoke 全部 PASS。
- `docs/qa/m1-acceptance.md` 中 M1 checklist 对每条用户目标都有 PASS/FAIL/Blocked 记录。
- README 能让下一位 agent 或用户直接运行 M1。
- 未引入并行文件冲突或未记录的跨任务修改。

---

## 推荐 subagent 调度顺序

1. Task 1 Camera subagent。
2. Task 2 Wave/Enemy/Spawn subagent。
3. Task 3 Weapon Variety subagent。
4. Task 4 Rune Routes/Upgrade UI subagent。
5. Task 5 Feedback/Settlement subagent。
6. Task 6 Visual Asset Replacement subagent。
7. Task 7 Acceptance/Integration subagent。

Task 3 可以在 Task 2 后半段准备 weapon-only data，但不能改 `UpgradeSystem.OPTIONS`；实际合并建议仍按 1-7 串行，减少 Godot scene/resource merge 风险。

## 覆盖性自查

- 玩家跟随相机：Task 1。
- 屏幕外刷怪：Task 2。
- 5-8 分钟波次节奏：Task 2。
- 至少 2 把可区分武器：Task 3。
- 至少 3 类敌人：Task 2。
- 至少 2 条可感知符文构筑路线：Task 4。
- 基础战斗反馈：Task 5。
- 升级选择可读性：Task 4。
- 胜负结算界面：Task 5。
- 主角/基础/快速/厚血敌人 2D 资源替换 Polygon2D：Task 6。
- 必要 smoke 或 QA 记录：Task 1-6 各自新增 smoke/QA，Task 7 全量归档。

## 剩余规划风险

- Godot `.tres/.tscn` 手工 merge 容易冲突；每个 subagent 应在提交前打开 diff，确认没有 editor-generated unrelated churn。
- 第二武器如果选择 orbit/pulse，headless hit 验证需要设计确定性的敌人位置，避免依赖真实物理帧随机性。
- 视觉资源导入可能生成 `.import` 文件；Task 6 需要把 Godot 自动生成的 import metadata 纳入提交范围。
- 当前中文文本在 PowerShell 输出中显示为 mojibake，但 Godot resource 可能仍按 UTF-8 保存；修改文本时应使用 UTF-8 editor，并用 Godot 运行结果或文件编码确认。
