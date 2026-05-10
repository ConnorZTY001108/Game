# Full Augment System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the full 72-augment Runebound Wasteland Survivor augment system from `C:\Users\19612\Downloads\Runebound_Wasteland_Survivor_Augment_System_Design.xlsx`, including all 9 build routes, route-aware level-up choices, proc safety, runtime effects, and verification.

**Architecture:** Keep the current Godot 4 Scene + Resource style. Add a data-driven `AugmentData` layer, a central `AugmentSystem` autoload, and a typed damage/event payload contract so augments can be implemented as reusable effect families instead of 72 unrelated one-off branches.

**Tech Stack:** Godot 4.6.2, GDScript 2.0, Godot `Resource`/`.tres`, autoload systems, headless smoke scripts, PowerShell.

---

## Source Inputs

Use these files as the design source of truth:

- `C:\Users\19612\Downloads\Runebound_Wasteland_Survivor_Augment_System_Design.md`
- `C:\Users\19612\Downloads\Runebound_Wasteland_Survivor_Augment_System_Design.xlsx`
- `docs/superpowers/plans/2026-05-10-full-augment-system-content-manifest.md`

Scope is the complete 72-augment system. The `MVP20` sheet and the MVP20 section below define the first validation checkpoint only; they are not permission to stop after 20 augments.

The workbook has 8 sheets:

- `读取统计`
- `术语转译`
- `原表分类`
- `构筑路线`
- `强化池72`
- `强力组合15`
- `MVP20`
- `Godot规则`

Implementation must preserve every field from `强化池72`:

```text
id / display_name / source_augment_name / source_augment_rarity /
route_id / route_label / rarity / max_rank / unique / upgrade_type /
trigger / effect / condition / value / synergy_tags / required_tags /
excludes_tags / combo_value / fit / risk / why_close / implementation_hint
```

The `.xlsx` remains the external design reference. Godot runtime content should live inside the project as `.tres` resources, not read `.xlsx` at runtime.

---

## Current Project Baseline

Current branch: `m1-vertical-slice`.

Current upgrade system:

- `autoload/UpgradeSystem.gd` owns a static `OPTIONS` array of a few upgrade resources.
- `data/resources/upgrade_data.gd` supports simple stat upgrades, rune picks, and weapon picks.
- `autoload/RuneSystem.gd` listens to `GameEvents.weapon_hit` and handles basic `on_hit` rune stacks.
- `autoload/DamageSystem.gd` currently applies damage and emits `weapon_hit`.
- `scripts/weapons/WeaponController.gd` fires projectiles or area pulses from `WeaponData`.
- `scripts/projectiles/Projectile.gd` passes a loose payload dictionary into `DamageSystem`.

This is enough for M1-style upgrades, but not enough for all 72 augments. The missing pieces are:

- a stable damage packet contract with `proc_depth`, source tags, crit fields, boss scaling, and recursion guards;
- event signals for attack fire, projectile hit, skill hit, damage roll, DoT ticks, shield/heal, control, dash/blink, low HP, fatal damage, pickups, periodic ticks, and quest progress;
- a runtime augment state ledger for stacks, cooldowns, route ownership, pending next-hit effects, active zones, summons, and tasks;
- route-aware weighted level-up selection;
- content resources for every augment;
- smoke tests that prove each effect family works without requiring a full manual playthrough.

Do not use `tools/create_m0_scenes.gd` to regenerate M1+ scenes. `README.md` explicitly warns that it may bind scenes back to M0 configuration.

---

## Target File Map

### Create

- `data/resources/augment_data.gd`
  Resource schema for all 72 augments.
- `data/resources/augment_effect_spec.gd`
  One normalized effect operation, for example `spawn_projectile`, `add_burn`, `refund_cooldown`, `apply_shield`, `reroll_augment`.
- `data/resources/augment_trigger_spec.gd`
  Trigger metadata: trigger id, cooldown, per-target cooldown, proc-depth policy, tags.
- `data/resources/augment_condition_spec.gd`
  Required route/tag/resource/health/level conditions.
- `data/resources/augment_forge_option.gd`
  Attribute forge option used by `属性锻造器` and related economy augments.
- `autoload/AugmentSystem.gd`
  Central runtime: acquired augments, effect dispatch, cooldowns, stack ledgers, proc guards, periodic scheduler.
- `autoload/AugmentRegistry.gd`
  Loads all augment resources and exposes route/rarity/tag queries to `UpgradeSystem`.
- `scripts/augments/AugmentRuntimeState.gd`
  Small helper object for stacks, cooldowns, charges, per-target ledgers, and quest progress.
- `scripts/augments/AugmentEffectRunner.gd`
  Executes generic effect specs against runtime events.
- `scripts/augments/RiftManager.gd`
  Owns void rift points, pairing, line explosions, and collapse counters.
- `scripts/augments/ZoneEffect.gd` and `scenes/augments/ZoneEffect.tscn`
  Generic short-lived aura/oil/slow/laser/detonation zone.
- `scripts/augments/AugmentSummon.gd` and `scenes/augments/AugmentSummon.tscn`
  Generic poro/foxfire/soldier/boomerang/minion behavior.
- `scripts/augments/DashBlinkController.gd`
  Optional player child node for snowstep dash/blink effects if current player movement code becomes too crowded.
- `data/content/augments/<route>/*.tres`
  72 augment content resources, split by route.
- `tests/smoke/augment_resource_contract.gd`
- `tests/smoke/augment_pool_selection_loop.gd`
- `tests/smoke/augment_proc_safety_loop.gd`
- `tests/smoke/augment_rune_volley_loop.gd`
- `tests/smoke/augment_inferno_loop.gd`
- `tests/smoke/augment_void_loop.gd`
- `tests/smoke/augment_aegis_loop.gd`
- `tests/smoke/augment_blood_loop.gd`
- `tests/smoke/augment_snowstep_loop.gd`
- `tests/smoke/augment_colossus_loop.gd`
- `tests/smoke/augment_summon_loop.gd`
- `tests/smoke/augment_forge_loop.gd`
- `tests/smoke/augment_all_content_contract.gd`

### Modify

- `project.godot`
  Add `AugmentRegistry` and `AugmentSystem` autoloads after existing runtime systems.
- `autoload/GameEvents.gd`
  Add all new augment-facing signals and fix any mojibake player-facing feedback strings while touching this file.
- `autoload/DamageSystem.gd`
  Convert loose damage payloads into a stable damage packet dictionary and route damage through augment pre/post hooks.
- `autoload/UpgradeSystem.gd`
  Replace static `OPTIONS` with registry-backed, route-aware candidate generation.
- `autoload/RuneSystem.gd`
  Keep rune stacks working, but emit/consume the new damage packet shape.
- `autoload/ElementStatusSystem.gd`
  Support timed DoT ticks and burn-stack threshold events.
- `autoload/ExperienceSystem.gd`
  Expose level-up index and pending selection state for rarity/route rules.
- `scripts/weapons/WeaponController.gd`
  Emit attack-fire events, source cooldown ids, owner/player id, and projectile metadata.
- `scripts/projectiles/Projectile.gd`
  Preserve `proc_depth`, source flags, parent projectile ids, and hit positions.
- `scripts/player/Player.gd`
  Add shield/heal/low-hp/fatal/dash hooks only through small focused helpers.
- `scripts/components/HealthComponent.gd`
  Emit damage, heal, shield, low HP, and fatal damage events.
- `scripts/enemies/Enemy.gd`
  Expose enemy classification: normal, elite, boss, large, controlled, max health.
- `scripts/systems/DropSystem.gd`
  Allow augment-created pickup drops and currency/fragment drops.
- `scripts/ui/LevelUpPanel.gd` and `scenes/ui/LevelUpPanel.tscn`
  Show route, rarity, role, summary, and risk text for augment choices.
- `tests/smoke/parse_all_scripts.gd`
- `tests/smoke/load_core_scenes.gd`
- `tests/smoke/experience_levelup_loop.gd`
- `tests/smoke/weapon_damage_loop.gd`
- `tests/smoke/rune_trigger_loop.gd`

---

## Core Runtime Contract

### Damage Packet

All damage should flow through `DamageSystem.apply_damage(target, packet)` after a compatibility wrapper is added for the old call shape.

Required packet keys:

```gdscript
{
	"amount": 10.0,
	"base_amount": 10.0,
	"damage_type": "physical", # physical / magic / true / adaptive
	"tags": ["projectile", "weapon", "scorch"],
	"source_kind": "weapon", # weapon / rune / augment / dot / summon / zone / contact
	"source_id": "rune_bolt",
	"augment_id": "",
	"weapon_id": "rune_bolt",
	"owner": player,
	"target": enemy,
	"hit_position": Vector2.ZERO,
	"target_max_hp_ratio": 0.0,
	"boss_scalar": 1.0,
	"can_crit": false,
	"crit_chance": 0.0,
	"crit_multiplier": 1.5,
	"is_crit": false,
	"on_hit_efficiency": 1.0,
	"proc_depth": 0,
	"proc_chain_id": "",
	"proc_flags": [],
	"parent_event_id": "",
	"cooldown_source_id": ""
}
```

Compatibility rule: old calls such as `DamageSystem.apply_damage(enemy, damage, tags, payload)` should still work initially by wrapping into this packet. Remove the wrapper only after every call site has migrated.

### Proc Safety

- Default `MAX_PROC_DEPTH = 2`.
- A proc-spawned projectile increments `proc_depth`.
- Effect families add a `proc_flag`, for example `split_projectile`, `dot_splash`, `chain_lightning`, `crit_shard`.
- The same effect family must not recursively trigger itself within the same `proc_chain_id`.
- Every converter needs either `source_cooldown` or `per_target_cooldown`.
- Boss max-health true damage uses `boss_scalar` between `0.2` and `0.4` unless an augment explicitly overrides it.
- Summons, zones, and delayed strikes need active-count caps to prevent runaway node counts.

### Event Signals

Add these to `GameEvents.gd`:

```gdscript
signal weapon_fired(player: Node, weapon: Resource, packet: Dictionary)
signal projectile_spawned(projectile: Node, packet: Dictionary)
signal projectile_hit(target: Node, packet: Dictionary)
signal damage_roll_requested(packet: Dictionary)
signal damage_applied_packet(target: Node, packet: Dictionary)
signal dot_tick(target: Node, packet: Dictionary)
signal burn_stack_threshold(target: Node, stacks: int, packet: Dictionary)
signal shield_gained(target: Node, amount: float, packet: Dictionary)
signal shield_broken(target: Node, amount: float, packet: Dictionary)
signal heal_received(target: Node, amount: float, packet: Dictionary)
signal regen_tick(target: Node, amount: float, packet: Dictionary)
signal control_applied(target: Node, control_tag: String, packet: Dictionary)
signal dash_started(player: Node, packet: Dictionary)
signal dash_finished(player: Node, packet: Dictionary)
signal blink_used(player: Node, packet: Dictionary)
signal low_hp_entered(player: Node, ratio: float, packet: Dictionary)
signal fatal_damage_received(player: Node, packet: Dictionary)
signal pickup_collected(pickup: Node, player: Node, packet: Dictionary)
signal elite_killed(enemy: Node, packet: Dictionary)
signal boss_damaged(enemy: Node, packet: Dictionary)
signal augment_periodic_tick(elapsed_seconds: float)
signal augment_quest_progressed(augment_id: String, amount: int, total: int)
```

Keep existing signals until all current smoke tests are migrated.

---

## Resource Model

`AugmentData` should not replace `UpgradeData` immediately. Make it a new resource and let `UpgradeSystem` understand both during migration.

```gdscript
class_name AugmentData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var source_augment_name: String = ""
@export var source_augment_rarity: String = ""

@export var route_id: String = ""
@export var route_label: String = ""
@export var rarity: String = "银色"
@export var max_rank: int = 1
@export var unique: bool = true
@export var upgrade_type: String = "启动器"

@export var trigger: Resource
@export var effects: Array[Resource] = []
@export var condition: Resource
@export var value: Dictionary = {}

@export var synergy_tags: Array[String] = []
@export var required_tags: Array[String] = []
@export var excludes_tags: Array[String] = []

@export_multiline var combo_value: String = ""
@export_multiline var fit: String = ""
@export_multiline var risk: String = ""
@export_multiline var why_close: String = ""
@export_multiline var implementation_hint: String = ""

@export var weight: float = 1.0
@export var min_upgrade_index: int = 0
@export var max_upgrade_index: int = -1
```

Use effect specs instead of adding 72 custom scripts. A single augment can have multiple effects:

```gdscript
class_name AugmentEffectSpec
extends Resource

@export var effect_type: String = ""
@export var params: Dictionary = {}
@export var tags: Array[String] = []
@export var source_cooldown: float = 0.0
@export var per_target_cooldown: float = 0.0
@export var max_proc_depth: int = 2
@export var blocks_same_family_recursion: bool = true
```

Effect types should be small verbs:

- `modify_stat`
- `spawn_projectile`
- `split_projectile`
- `add_dot`
- `add_burn_stack`
- `refund_cooldown`
- `roll_crit`
- `spawn_zone`
- `spawn_delayed_strike`
- `spawn_summon`
- `apply_shield`
- `heal_player`
- `convert_heal_to_damage`
- `execute_low_hp`
- `prevent_fatal_damage`
- `dash_or_blink`
- `apply_control`
- `drop_pickup`
- `grant_currency`
- `grant_forge_choice`
- `reroll_augment`
- `grant_random_augment`
- `progress_quest`

---

## Upgrade Selection Rules

`UpgradeSystem.generate_options()` should move from static rotation to weighted candidate selection.

### Rarity Schedule

| Level-up index | Silver | Gold | Prismatic |
|---:|---:|---:|---:|
| 1-2 | 70% | 27% | 3% |
| 3-5 | 55% | 35% | 10% |
| 6-8 | 42% | 40% | 18% |
| 9+ | 32% | 42% | 26% |

Rules:

- Level-up 6 raises prismatic weight.
- Level-up 10 guarantees at least one prismatic candidate if no prismatic appeared before.
- Prismatic finishers are heavily downweighted before a matching starter exists, not fully banned.
- High-risk cost augments are downweighted before level-up 4.

### Route Weighting

- Existing 1 augment in route: `x1.35`
- Existing 2 augments in route: `x1.70`
- Existing 3+ augments in route: `x2.00`
- Starter already owned: amplifiers/converters in that route get `x1.25`
- Starter + amplifier owned: finishers in that route get `x1.40`

### Guardrails

- First 2 level-ups should include at least one starter candidate.
- If player reaches level-up 3 with no starter, force at least one starter into the options.
- If two consecutive option sets are dominated by the same route, the next set must include one off-route or economy/survival option.
- Same option set can contain at most one high-risk cost augment.
- Unique augments disappear after pick.
- Rankable augments remain until `max_rank`.
- `required_tags` hard filter when essential, soft downweight when only a synergy hint.
- `excludes_tags` blocks incompatible fantasy pairs such as `glass_cannon` vs `giant_body`.

---

## Implementation Phases

### Phase 0: Baseline Lock

- [ ] Run current smoke suite listed in `README.md`.
- [ ] Record pass/fail results in `docs/qa/augment-system-acceptance.md`.
- [ ] Do not fix unrelated failing tests inside this phase; document them.

### Phase 1: Event and Damage Infrastructure

- [ ] Add the new `GameEvents` signals.
- [ ] Add damage packet creation and compatibility wrapper to `DamageSystem`.
- [ ] Migrate `WeaponController`, `Projectile`, `RuneSystem`, `Enemy`, and `HealthComponent` to preserve and forward packets.
- [ ] Add `proc_depth`, `proc_chain_id`, and `proc_flags`.
- [ ] Add `augment_proc_safety_loop.gd` to prove split, splash, and chain effects do not recurse forever.

Acceptance:

- Current `weapon_damage_loop.gd` and `rune_trigger_loop.gd` still pass.
- A generated proc packet at depth 2 cannot trigger another same-family proc.

### Phase 2: Augment Resource and Registry

- [ ] Create `AugmentData`, `AugmentEffectSpec`, `AugmentTriggerSpec`, `AugmentConditionSpec`, and `AugmentForgeOption`.
- [ ] Create `AugmentRegistry` autoload and route/rarity lookup methods.
- [ ] Convert the 72 Excel rows into `.tres` files under `data/content/augments/<route>/`.
- [ ] Add `augment_resource_contract.gd` to validate required fields, unique ids, route ids, rarity values, trigger ids, tags, and missing effect specs.
- [ ] Add `augment_all_content_contract.gd` to assert exactly 72 augment resources load.

Acceptance:

- Every id from the workbook exists once.
- Every route has exactly 8 augments.
- `MVP20` augments are marked or queryable by priority.

### Phase 3: Upgrade Pool and UI

- [ ] Update `UpgradeSystem` to generate options from `AugmentRegistry`.
- [ ] Preserve support for old `UpgradeData` until all old upgrades are replaced or intentionally kept.
- [ ] Implement rarity schedule, route weighting, starter guarantee, finisher downweighting, cost-augment guardrails, required/excludes filtering, unique/rank tracking.
- [ ] Update `LevelUpPanel` to show route label, rarity, role, effect summary, fit/risk text, and source.
- [ ] Add `augment_pool_selection_loop.gd`.

Acceptance:

- Three choices appear unless a special rule such as `质变混沌` temporarily reduces options.
- The first three level-ups cannot leave the player without any starter candidate.
- Unique picked augments do not reappear.

### Phase 4: Shared Effect Runner

- [ ] Create `AugmentSystem` and `AugmentEffectRunner`.
- [ ] Subscribe `AugmentSystem` to every new event signal.
- [ ] Implement runtime ledgers: acquired ids, ranks, route counts, stacks, cooldowns, per-target cooldowns, pending next-hit effects, active zones, active summons, quest progress.
- [ ] Add generic effect execution for stat mods, cooldown refund, projectile spawning, zones, summons, shield/heal, execute, fatal prevention, currency, forge choice, reroll, and random grant.
- [ ] Add debug logging only behind a local debug flag; do not leave noisy prints on by default.

Acceptance:

- Acquiring an augment registers its trigger handlers.
- Removing/rerolling an augment clears its runtime state safely.
- Passive effects apply once and do not stack accidentally unless rankable.

### Phase 5: Route Implementations

Implement routes in this order because each phase reuses earlier effect families.

1. `rune_volley` / 符文弹幕链
   Needs projectile spawning, on-hit efficiency, crit roll, low-HP execute.
2. `inferno_conduit` / 炼狱导管
   Needs burn stacks, DoT tick, cooldown refund, dot crit/splash, burn threshold.
3. `void_cascade` / 虚空裂隙连锁
   Needs skill-hit events, rift manager, chain lines, max-health missiles, collapse zones.
4. `aegis_transmutation` / 圣盾转化
   Needs shield/heal events, heal-to-damage, shield explosion, faith stacks.
5. `blood_reaver` / 血契收割
   Needs self-cost, omnivamp, low-hp events, fatal prevention, execute/heal.
6. `snowstep_vanguard` / 雪步先锋
   Needs dash/blink controller, movement cooldowns, path execute, auto mark.
7. `colossus_furnace` / 巨像熔炉
   Needs control events, aura damage, permanent max-health growth, taunt pulse.
8. `summon_engine` / 自动奇观
   Needs periodic scheduler, delayed strikes, foxfire, boomerang, poro, soldiers, summon scaling.
9. `quest_forge` / 海牛锻炉
   Needs forge UI/options, pickup spawn, currency, reroll, random grants, quest completion.

Each route gets one smoke test. Do not wait until all 72 are done to test the first route.

---

## 72-Augment Implementation Matrix

This table is an implementation index. The complete field-by-field content for all 72 augments is in `docs/superpowers/plans/2026-05-10-full-augment-system-content-manifest.md` and must be copied into each `AugmentData.value`, `condition`, `effects`, tag, fit/risk, and implementation-hint field.

| # | id | display_name | route_label | rarity | upgrade_type | trigger | implementation family |
|---:|---|---|---|---|---|---|---|
| 1 | `aug_rune_dual_wield` | 符文双持 | 符文弹幕链 | 棱彩 | 启动器/放大器 | `on_attack_fire` | secondary projectile + on-hit efficiency |
| 2 | `aug_typhoon_split` | 台风分裂 | 符文弹幕链 | 银色 | 启动器 | `on_projectile_hit` | projectile split + parent hit dedupe |
| 3 | `aug_jeweled_rune` | 珠光符文 | 符文弹幕链 | 棱彩 | 转换器 | `on_damage_roll` | crit permission for skill/element/dot/relic |
| 4 | `aug_critical_shards` | 暴击飞晶 | 符文弹幕链 | 金色 | 放大器 | `on_crit` | crit-triggered homing shards |
| 5 | `aug_ethereal_weapon` | 虚幻武器 | 符文弹幕链 | 金色 | 转换器 | `on_skill_hit` | skill/orbit hit applies current on-hit package |
| 6 | `aug_press_chain` | 强攻三环 | 符文弹幕链 | 金色 | 启动器 | `on_hit` | per-target hit counter + vulnerability burst |
| 7 | `aug_crit_cast_engine` | 会心施法机 | 符文弹幕链 | 银色 | 转换器 | `passive_stat_convert` | crit/attack-speed overflow to cooldown haste |
| 8 | `aug_collector_mark` | 收集者刻印 | 符文弹幕链 | 金色 | 终结器/经济型 | `on_damage_to_low_hp` | non-boss execute + elite reward/cooldown refund |
| 9 | `aug_infernal_conduit` | 炼狱导管 | 炼狱导管 | 棱彩 | 启动器 | `on_skill_or_element_hit` | burn stack + DoT cooldown refund |
| 10 | `aug_firebrand_runes` | 火上浇油 | 炼狱导管 | 金色 | 启动器 | `on_hit` | on-hit burn stack + bonus vs burning |
| 11 | `aug_slow_cooker_aura` | 慢炖法阵 | 炼狱导管 | 棱彩 | 放大器 | `periodic_aura` | player-centered burn aura + elite max-hp damage |
| 12 | `aug_chili_oil` | 辣椒油污 | 炼狱导管 | 金色 | 生存型/放大器 | `on_apply_burn` | burn-count oil zone + player healing zone |
| 13 | `aug_holy_fire_conversion` | 圣火转化 | 炼狱导管 | 金色 | 转换器 | `on_shield_or_heal` | shield/heal applies nearby burn stacks |
| 14 | `aug_vulnerable_flame` | 易燃暴击 | 炼狱导管 | 金色 | 转换器/放大器 | `on_dot_tick` | DoT crit + splash with recursion block |
| 15 | `aug_tormentor_brand` | 折磨者烙印 | 炼狱导管 | 银色 | 启动器 | `on_control` | control applies burn stacks |
| 16 | `aug_infernal_detonation` | 炼狱终爆 | 炼狱导管 | 棱彩 | 终结器 | `on_burn_stack_threshold` | burn threshold explosion + elite/Boss fire beam |
| 17 | `aug_void_rift` | 虚空裂隙 | 虚空裂隙连锁 | 棱彩 | 启动器 | `on_skill_hit` | rift point spawn + pair line explosion |
| 18 | `aug_magic_missile` | 魔法飞弹 | 虚空裂隙连锁 | 金色 | 放大器 | `on_skill_hit` | max-health true-damage missile |
| 19 | `aug_trueshot_prod` | 精准奇才 | 虚空裂隙连锁 | 金色 | 放大器 | `on_long_range_hit` | long-range pierce bolt + elite cooldown refund |
| 20 | `aug_erosion_loop` | 侵蚀回路 | 虚空裂隙连锁 | 银色 | 放大器 | `on_damage` | resistance shred stack + rift crit state |
| 21 | `aug_hextech_chain` | 海克斯链魂 | 虚空裂隙连锁 | 银色 | 启动器 | `periodic_next_hit` | next-hit chain lightning + slow |
| 22 | `aug_pinball_rift` | 弹球回响 | 虚空裂隙连锁 | 金色 | 放大器 | `on_projectile_or_rift_hit` | one-time projectile/rift bounce |
| 23 | `aug_duality_charge` | 物法双核 | 虚空裂隙连锁 | 金色 | 转换器 | `on_hit_and_skill_hit` | dual core stacks + mixed elemental burst |
| 24 | `aug_void_collapse` | 虚空坍缩 | 虚空裂隙连锁 | 棱彩 | 终结器 | `on_rift_chain_count` | regional rift-chain counter + delayed collapse |
| 25 | `aug_shield_egg` | 护盾爆蛋 | 圣盾转化 | 银色 | 启动器 | `on_shield_break_or_expire` | shield-end explosion |
| 26 | `aug_circle_of_death` | 死亡之环 | 圣盾转化 | 棱彩 | 转换器 | `on_heal_or_regen_tick` | heal/regen converts to nearest-enemy damage |
| 27 | `aug_critical_healing` | 会心治疗 | 圣盾转化 | 金色 | 放大器 | `on_heal_or_shield` | heal/shield crit roll + healing wave |
| 28 | `aug_windspeaker` | 风语祝福 | 圣盾转化 | 金色 | 生存型 | `on_heal_or_shield` | temporary armor/resist + pickup radius return |
| 29 | `aug_sonic_holy` | 圣盾音爆 | 圣盾转化 | 金色 | 转换器 | `on_shield_or_heal` | sonic pulse + slow + burn |
| 30 | `aug_big_brain_barrier` | 巨脑法盾 | 圣盾转化 | 金色 | 生存型 | `on_level_up_or_wave_start` | refreshable stored shield + damage while shielded |
| 31 | `aug_faith_shockwave` | 信念冲击波 | 圣盾转化 | 棱彩 | 终结器 | `on_damage_while_shielded_or_after_heal` | faith stacks + shockwave finisher |
| 32 | `aug_laser_heal_array` | 激光治疗阵 | 圣盾转化 | 金色 | 召唤型/生存型 | `periodic` | periodic healing/damaging laser zone |
| 33 | `aug_ominous_pact` | 不祥契约 | 血契收割 | 棱彩 | 代价型/启动器 | `on_cast` | cast health cost + missing-hp scaling |
| 34 | `aug_devil_shoulder` | 肩上恶魔 | 血契收割 | 棱彩 | 代价型 | `periodic_drain_and_on_damage` | life drain + true damage + life fragments |
| 35 | `aug_vampirism` | 吸血习性 | 血契收割 | 金色 | 生存型/转换器 | `on_damage_dealt` | omnivamp + pickup healing penalty |
| 36 | `aug_escape_plan` | 逃跑计划 | 血契收割 | 银色 | 生存型 | `on_low_hp` | low-hp shield + speed + knockback |
| 37 | `aug_dawn_resolve` | 黎明坚决 | 血契收割 | 金色 | 生存型 | `on_below_half_hp` | one-time below-half burst regen |
| 38 | `aug_blood_debt_execute` | 血债飞踢 | 血契收割 | 金色 | 终结器 | `on_damage_to_low_hp` | low-hp kick execute + collision explosion + heal |
| 39 | `aug_final_transit` | 终点列车 | 血契收割 | 金色 | 终结器/生存型 | `on_fatal_damage` | fatal prevention + train sweep |
| 40 | `aug_glass_cannon` | 玻璃大炮 | 血契收割 | 棱彩 | 代价型 | `passive` | max-health penalty + direct/true damage boost |
| 41 | `aug_holy_snowmark` | 神圣雪印 | 雪步先锋 | 棱彩 | 启动器 | `periodic_auto_mark` | auto snow mark + directional dash + brief invulnerability |
| 42 | `aug_flash2` | 闪烁备用 | 雪步先锋 | 银色 | 启动器/生存型 | `on_manual_or_auto_blink` | low-hp/surrounded blink charge |
| 43 | `aug_flashbang` | 闪光爆破 | 雪步先锋 | 银色 | 放大器 | `on_dash_or_blink` | dash/blink end explosion + slow |
| 44 | `aug_dashing_engine` | 全凭身法 | 雪步先锋 | 金色 | 放大器 | `passive_cooldown` | mobility cooldown reduction + XP refund |
| 45 | `aug_shadow_runner` | 暗影疾奔 | 雪步先锋 | 金色 | 生存型/放大器 | `on_dash_or_kill` | dash speed + elite-kill stealth/damage |
| 46 | `aug_poro_king_bounce` | 魄罗王弹跳 | 雪步先锋 | 棱彩 | 终结器 | `periodic` | temporary poro-king bounce mode |
| 47 | `aug_dropkick_dash` | 飞身踢 | 雪步先锋 | 金色 | 终结器 | `on_dash_through_low_hp` | dash-path kick execute + explosion + heal |
| 48 | `aug_speed_demon` | 速度恶魔 | 雪步先锋 | 银色 | 放大器 | `on_skill_hit_and_damage_calc` | speed buff + speed-difference damage scaling |
| 49 | `aug_colossus_courage` | 巨像勇气 | 巨像熔炉 | 棱彩 | 启动器/生存型 | `on_control` | control-triggered max-health shield |
| 50 | `aug_cruel_comet` | 残忍彗星 | 巨像熔炉 | 金色 | 放大器 | `on_control` | delayed comet on controlled target |
| 51 | `aug_impassable` | 不动如山 | 巨像熔炉 | 金色 | 生存型/放大器 | `on_control` | temporary resists + slow glacier |
| 52 | `aug_adamant_layers` | 坚若磐石 | 巨像熔炉 | 银色 | 放大器 | `on_control` | armor/resist stacking |
| 53 | `aug_soul_eater` | 吞噬灵魂 | 巨像熔炉 | 金色 | 叠层成长 | `on_control_elite_or_boss` | permanent max-health growth |
| 54 | `aug_immolate_engine` | 献祭引擎 | 巨像熔炉 | 棱彩 | 启动器/经济型 | `periodic_aura` | immolate aura + currency/task progress |
| 55 | `aug_goliath` | 歌利亚巨人 | 巨像熔炉 | 棱彩 | 代价型/生存型 | `passive` | body size/max-health/adaptive-force tradeoff |
| 56 | `aug_stuck_with_me` | 困在这里 | 巨像熔炉 | 棱彩 | 终结器 | `periodic_taunt_pulse` | taunt pull + damage reduction + absorbed-damage explosion |
| 57 | `aug_orbital_laser` | 轨道镭射 | 自动奇观 | 棱彩 | 终结器/召唤型 | `periodic_enemy_cluster` | delayed laser on densest cluster |
| 58 | `aug_quantum_slash` | 量子斩击 | 自动奇观 | 棱彩 | 终结器 | `periodic` | periodic giant slash + slow + max-hp damage + heal |
| 59 | `aug_boomerang` | 回力OK镖 | 自动奇观 | 金色 | 召唤型/启动器 | `periodic` | outgoing/returning boomerang projectile |
| 60 | `aug_firefox` | 狐火飞弹 | 自动奇观 | 银色 | 启动器/召唤型 | `periodic` | periodic homing foxfire missiles |
| 61 | `aug_poro_blaster` | 魄罗爆破手 | 自动奇观 | 金色 | 召唤型/放大器 | `on_hit_charge` | hit charges into knockback poro projectile |
| 62 | `aug_minionmancer` | 仆从大师 | 自动奇观 | 金色 | 放大器 | `passive_summon_scaler` | summon/orbit/poro/foxfire size-duration-damage scaler |
| 63 | `aug_hand_of_baron` | 男爵之手 | 自动奇观 | 金色 | 召唤型/经济型 | `on_elite_kill_or_pickup` | rune soldier summons |
| 64 | `aug_divine_intervention` | 神圣干预 | 自动奇观 | 金色 | 生存型/规则改写型 | `periodic` | periodic invulnerable star + charm/slow contact |
| 65 | `aug_stats_forge` | 属性锻造器 | 海牛锻炉 | 银色 | 经济型/通用型 | `on_pick` | two stat forge choices |
| 66 | `aug_stats_on_stats` | 属性叠属性 | 海牛锻炉 | 金色 | 经济型/通用型 | `on_pick` | four forge choices + next-choice refresh |
| 67 | `aug_red_envelope` | 红包祭品 | 海牛锻炉 | 金色 | 经济型/生存型 | `periodic_pickup_spawn` | periodic reward pickup spawns |
| 68 | `aug_goldrend` | 夺金刻痕 | 海牛锻炉 | 棱彩 | 经济型/启动器 | `on_damage_to_elite_or_boss` | elite/Boss gold window |
| 69 | `aug_pandora_box` | 潘朵拉符盒 | 海牛锻炉 | 棱彩 | 规则改写型 | `on_pick` | reroll owned non-unique non-finisher augment |
| 70 | `aug_transmute_chaos` | 质变混沌 | 海牛锻炉 | 棱彩 | 规则改写型/代价型 | `on_pick` | grant two random augments + reduce next choices |
| 71 | `aug_urf_champion` | 海牛勇士任务 | 海牛锻炉 | 棱彩 | 终结器/任务型 | `quest_progress_on_kill_and_cast` | kill/elite quest into URF cooldown mode |
| 72 | `aug_mobile_zhonya` | 移动中娅 | 海牛锻炉 | 金色 | 生存型/规则改写型 | `on_low_hp_or_controlled` | movable stasis + cleanse + heal |

---

## MVP20 First Checkpoint Order

Implement the first playable validation checkpoint in this exact order. This checkpoint proves the core mechanics, then implementation continues through the other 52 augments in the manifest.

1. `aug_rune_dual_wield` / 符文双持
2. `aug_infernal_conduit` / 炼狱导管
3. `aug_void_rift` / 虚空裂隙
4. `aug_shield_egg` / 护盾爆蛋
5. `aug_typhoon_split` / 台风分裂
6. `aug_critical_shards` / 暴击飞晶
7. `aug_vulnerable_flame` / 易燃暴击
8. `aug_magic_missile` / 魔法飞弹
9. `aug_jeweled_rune` / 珠光符文
10. `aug_ethereal_weapon` / 虚幻武器
11. `aug_circle_of_death` / 死亡之环
12. `aug_holy_fire_conversion` / 圣火转化
13. `aug_infernal_detonation` / 炼狱终爆
14. `aug_void_collapse` / 虚空坍缩
15. `aug_faith_shockwave` / 信念冲击波
16. `aug_blood_debt_execute` / 血债飞踢
17. `aug_ominous_pact` / 不祥契约
18. `aug_glass_cannon` / 玻璃大炮
19. `aug_stats_forge` / 属性锻造器
20. `aug_mobile_zhonya` / 移动中娅

Rationale:

- Items 1-4 prove the four core starters.
- Items 5-12 prove amplifiers and converters.
- Items 13-16 prove finishers.
- Items 17-18 prove cost/risk mechanics.
- Items 19-20 prove economy/survival rule rewrite.

After this checkpoint passes, continue implementing the remaining 52 augments. The feature is not complete until every augment listed in `2026-05-10-full-augment-system-content-manifest.md` has a resource, runtime behavior, and route-test coverage.

---

## Per-Route Implementation Notes

### 符文弹幕链

Files most likely touched:

- `scripts/weapons/WeaponController.gd`
- `scripts/projectiles/Projectile.gd`
- `autoload/DamageSystem.gd`
- `autoload/AugmentSystem.gd`
- `scripts/augments/AugmentEffectRunner.gd`

Required capabilities:

- emit `weapon_fired` before projectile spawn;
- spawn secondary projectile with `proc_flags = ["secondary_projectile"]`;
- scale `on_hit_efficiency`;
- split only once per parent projectile;
- roll crit through `damage_roll_requested`;
- spawn crit shards with homing targeting;
- execute low-health non-boss enemies after damage packet resolution.

Smoke:

- `augment_rune_volley_loop.gd`

### 炼狱导管

Files most likely touched:

- `autoload/ElementStatusSystem.gd`
- `autoload/AugmentSystem.gd`
- `scripts/augments/ZoneEffect.gd`
- `scripts/components/HealthComponent.gd`

Required capabilities:

- burn stacks with timed DoT ticks;
- `dot_tick` packets;
- cooldown refund to the most recent weapon source;
- DoT crit only when enabled by augment;
- DoT splash cannot trigger another DoT splash;
- threshold detonation consumes stacks.

Smoke:

- `augment_inferno_loop.gd`

### 虚空裂隙连锁

Files most likely touched:

- `scripts/augments/RiftManager.gd`
- `scripts/augments/ZoneEffect.gd`
- `autoload/AugmentSystem.gd`

Required capabilities:

- spawn rift at hit position;
- pair nearby rifts and draw/log line explosions;
- apply max-health true damage with boss scalar;
- track regional rift-chain counts for collapse;
- delayed collapse zone with warning delay.

Smoke:

- `augment_void_loop.gd`

### 圣盾转化

Files most likely touched:

- `scripts/components/HealthComponent.gd`
- `scripts/player/Player.gd`
- `autoload/AugmentSystem.gd`

Required capabilities:

- support shield amount and shield expiration/break events;
- route healing and regen ticks through events;
- convert heal to damage without recursively healing again;
- shielded damage faith stacks;
- stored shield on level-up/wave start.

Smoke:

- `augment_aegis_loop.gd`

### 血契收割

Files most likely touched:

- `scripts/player/Player.gd`
- `scripts/components/HealthComponent.gd`
- `autoload/DamageSystem.gd`
- `autoload/AugmentSystem.gd`

Required capabilities:

- weapon cast health cost cannot kill unless explicitly allowed;
- missing-health stat scaling updates every cast or tick;
- omnivamp from dealt damage;
- low HP/fatal hooks fire before final death;
- fatal prevention has cooldown and clear feedback;
- low-health execute is blocked for Boss unless specifically scaled.

Smoke:

- `augment_blood_loop.gd`

### 雪步先锋

Files most likely touched:

- `scripts/player/Player.gd`
- `scripts/augments/DashBlinkController.gd`
- `autoload/AugmentSystem.gd`

Required capabilities:

- dash/blink events;
- auto-safe blink direction;
- dash path collision query;
- temporary invulnerability packet flag;
- mobility cooldown ledger;
- movement speed damage scalar.

Smoke:

- `augment_snowstep_loop.gd`

### 巨像熔炉

Files most likely touched:

- `scripts/enemies/Enemy.gd`
- `autoload/GameEvents.gd`
- `autoload/AugmentSystem.gd`
- `scripts/augments/ZoneEffect.gd`

Required capabilities:

- control tags: `knockback`, `slow_strong`, `freeze`, `root`, `taunt`;
- control event emission from existing or new effects;
- temporary armor/resist stacks;
- permanent max-health growth;
- player-size modifier that also updates collision/visual scale intentionally;
- taunt pulse that has a duration cap and absorbed-damage ledger.

Smoke:

- `augment_colossus_loop.gd`

### 自动奇观

Files most likely touched:

- `scripts/augments/AugmentSummon.gd`
- `scripts/augments/ZoneEffect.gd`
- `autoload/AugmentSystem.gd`

Required capabilities:

- periodic scheduler;
- enemy cluster targeting;
- delayed strike warning;
- homing foxfire;
- return-path boomerang;
- poro charge projectile;
- summon scaler applies to all summon-tagged effects.

Smoke:

- `augment_summon_loop.gd`

### 海牛锻炉

Files most likely touched:

- `autoload/UpgradeSystem.gd`
- `autoload/AugmentSystem.gd`
- `scripts/ui/LevelUpPanel.gd`
- `scripts/systems/DropSystem.gd`

Required capabilities:

- immediate attribute forge choices;
- next-choice refresh modifier;
- periodic reward pickups;
- currency ledger;
- owned augment reroll;
- random augment grant with constraints;
- quest progress and completion reward.

Smoke:

- `augment_forge_loop.gd`

---

## Test and Verification Plan

Use this Godot executable:

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --version
```

Single smoke command format:

```powershell
& 'C:\Users\19612\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke/<script>.gd --quit-after 1
```

Minimum final smoke list:

```text
parse_all_scripts.gd
load_core_scenes.gd
weapon_damage_loop.gd
experience_levelup_loop.gd
rune_trigger_loop.gd
augment_resource_contract.gd
augment_all_content_contract.gd
augment_pool_selection_loop.gd
augment_proc_safety_loop.gd
augment_rune_volley_loop.gd
augment_inferno_loop.gd
augment_void_loop.gd
augment_aegis_loop.gd
augment_blood_loop.gd
augment_snowstep_loop.gd
augment_colossus_loop.gd
augment_summon_loop.gd
augment_forge_loop.gd
```

Manual playtest checklist:

- First three level-ups include at least one starter path.
- A player can intentionally build at least one 5-piece combo from `强力组合15`.
- Projectile-heavy builds do not freeze or recursively explode the game.
- Burn and DoT builds visibly tick, refund cooldown, and detonate.
- Void rifts leave readable spatial marks and collapse after a delay.
- Shield/heal builds visibly turn defense into offense.
- Blood builds feel risky but do not kill the player through unavoidable self-cost before counterplay exists.
- Dash/blink effects do not push the player into impossible terrain or permanent invulnerability.
- Summon/periodic builds respect active-count caps and keep framerate acceptable.
- Reroll/random-grant augments cannot delete core unique finishers unless design explicitly allows it.

---

## Balance Defaults

Use these as first-pass constants, then tune after manual playtest:

- `MAX_PROC_DEPTH = 2`
- `MAX_ACTIVE_ZONES_PER_AUGMENT = 12`
- `MAX_ACTIVE_SUMMONS_PER_AUGMENT = 16`
- `MAX_DELAYED_STRIKES_PER_AUGMENT = 10`
- `BOSS_MAX_HP_DAMAGE_SCALAR = 0.30`
- `ELITE_MAX_HP_DAMAGE_SCALAR = 0.65`
- `PROC_PROJECTILE_ON_HIT_EFFICIENCY = 0.40`
- `SPLIT_PROJECTILE_DAMAGE_MULTIPLIER = 0.35`
- `SPLIT_PROJECTILE_ON_HIT_EFFICIENCY = 0.50`
- `DOT_SPLASH_DAMAGE_MULTIPLIER = 0.50`
- `DEFAULT_PER_TARGET_COOLDOWN = 0.25`
- `DEFAULT_CONVERTER_SOURCE_COOLDOWN = 0.50`
- `FATAL_PREVENTION_COOLDOWN = 90.0`

Balance rules:

- Prefer lowering proc efficiency before lowering visual frequency.
- Finishers should be rare but visually obvious.
- Cost augments should show clear feedback before taking HP.
- Economy augments can be slightly weak in immediate combat because they create future choice power.
- Boss scaling must be explicit in data, not hidden in one-off code branches.

---

## Completion Definition

The full augment implementation is complete only when:

- all 72 `AugmentData` resources exist and pass the content contract;
- all 72 resources preserve the full source fields listed in `2026-05-10-full-augment-system-content-manifest.md`;
- all 9 routes have at least one automated smoke test;
- all MVP20 checkpoint effects are playable and manually verified;
- all remaining 52 augments are implemented through shared effect families or explicitly documented one-off handlers, with no skipped stub behavior;
- `UpgradeSystem` applies route/rarity/required/excludes rules;
- no proc effect can recursively trigger itself indefinitely;
- final smoke list passes with Godot 4.6.2 headless;
- `docs/qa/augment-system-acceptance.md` records the final command outputs and manual playtest notes.
