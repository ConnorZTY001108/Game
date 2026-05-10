# Full Augment Content Manifest

This file is the complete implementation content list for all 72 augments. It is generated from `C:\Users\19612\Downloads\Runebound_Wasteland_Survivor_Augment_System_Design.xlsx`, workbook sheet index 5, and is required scope for the full augment implementation. The MVP20 list is only a delivery checkpoint; it is not a reduced feature scope.

Every augment below must become a `data/content/augments/<route>/<id>.tres` `AugmentData` resource and must be covered by a route smoke test or a specific content contract. Natural-language `effect`, `condition`, and `value` text must be preserved for design traceability, but runtime behavior must be implemented from `trigger_spec` and `effect_spec_blueprint`.

## Coverage Summary

| Route | route_id | Required count | Smoke test |
|---|---|---:|---|
| 符文弹幕链 | `rune_volley` | 8 | `augment_rune_volley_loop.gd` |
| 炼狱导管 | `inferno_conduit` | 8 | `augment_inferno_loop.gd` |
| 虚空裂隙连锁 | `void_cascade` | 8 | `augment_void_loop.gd` |
| 圣盾转化 | `aegis_transmutation` | 8 | `augment_aegis_loop.gd` |
| 血契收割 | `blood_reaver` | 8 | `augment_blood_loop.gd` |
| 雪步先锋 | `snowstep_vanguard` | 8 | `augment_snowstep_loop.gd` |
| 巨像熔炉 | `colossus_furnace` | 8 | `augment_colossus_loop.gd` |
| 自动奇观 | `summon_engine` | 8 | `augment_summon_loop.gd` |
| 海牛锻炉 | `quest_forge` | 8 | `augment_forge_loop.gd` |

## Required Resource Fields

Each `AugmentData` must preserve these source fields and add the implementation-control fields below:

```text
id, display_name, source_augment_name, source_augment_rarity, route_id, route_label, rarity, max_rank, unique, upgrade_type, trigger, effect, condition, value, synergy_tags, required_tags, excludes_tags, combo_value, fit, risk, why_close, implementation_hint, resource_path, test_owner, checkpoint_priority, trigger_spec, effect_spec_blueprint
```

## 符文弹幕链 (`rune_volley`)

### 1. 符文双持 (`aug_rune_dual_wield`)

- `source_augment_name`: 双刀流
- `source_augment_rarity`: 双刀流:棱彩
- `route_id`: `rune_volley`
- `route_label`: 符文弹幕链
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 启动器/放大器
- `trigger`: `on_attack_fire`
- `effect`: 主 projectile 每次发射时附带一枚副手符文弹；副手弹造成 45% 伤害，并以 40% 效率触发 on_hit。
- `condition`: 仅 projectile 武器；副手弹不再次生成副手弹。
- `value`: +25% 总攻击速度；副手 45% 伤害
- `synergy_tags`: `projectile,on_hit,multishot,attack_speed`
- `required_tags`: `weapon:projectile`
- `excludes_tags`: ``
- `combo_value`: 给所有 on_hit、元素叠层、暴击飞弹提供额外触发体。
- `fit`: 符文弹、散射弹、高频射手流。
- `risk`: 单发高伤技能流收益低。
- `why_close`: 保留“双刀流”的额外攻击和特效复制体验。
- `implementation_hint`: 为 WeaponFireEvent 增加 secondary_projectile 标记，防递归。
- `resource_path`: `data/content/augments/rune_volley/aug_rune_dual_wield.tres`
- `test_owner`: `augment_rune_volley_loop.gd`
- `checkpoint_priority`: `1`
- `trigger_spec`: `trigger_id=on_attack_fire; signals=weapon_fired; required_packet_keys=owner, weapon_id, weapon_tags, cooldown_source_id, proc_flags; synthetic_test=emit weapon_fired with projectile weapon`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "spawn_projectile",
    "params": {"projectile_role": "secondary_projectile", "damage_multiplier": 0.45, "on_hit_efficiency": 0.4, "inherit_weapon_tags": true, "add_proc_flag": "secondary_projectile", "block_if_proc_flag_exists": "secondary_projectile", "max_proc_depth": 1},
    "max_proc_depth": 1,
    "effect_family": "spawn_projectile",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "modify_stat",
    "params": {"stat": "attack_speed_multiplier", "op": "add_percent", "value": 0.25},
    "max_proc_depth": 2,
    "effect_family": "modify_stat",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_rune_dual_wield` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_attack_fire` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_rune_volley_loop.gd` reports this id as covered in its route coverage list.

### 2. 台风分裂 (`aug_typhoon_split`)

- `source_augment_name`: 台风
- `source_augment_rarity`: 台风:银色
- `route_id`: `rune_volley`
- `route_label`: 符文弹幕链
- `rarity`: 银色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 启动器
- `trigger`: `on_projectile_hit`
- `effect`: 符文弹命中时向 2 个附近敌人发射分裂箭，造成 35% 伤害并以 50% 效率触发 on_hit。
- `condition`: 每个主弹最多触发一次；优先未命中目标。
- `value`: 2 分裂箭；35% 伤害
- `synergy_tags`: `projectile,on_hit,chain,aoe`
- `required_tags`: `weapon:projectile`
- `excludes_tags`: ``
- `combo_value`: 把单体武器变成清群武器，并让 on_hit 扩散。
- `fit`: 所有弹体武器。
- `risk`: 密度低时收益下降。
- `why_close`: 来自“台风”的分裂箭和攻击特效扩散。
- `implementation_hint`: hit_context.parent_id 去重，避免同一目标无限弹。
- `resource_path`: `data/content/augments/rune_volley/aug_typhoon_split.tres`
- `test_owner`: `augment_rune_volley_loop.gd`
- `checkpoint_priority`: `5`
- `trigger_spec`: `trigger_id=on_projectile_hit; signals=projectile_hit, damage_applied_packet; required_packet_keys=target, hit_position, parent_event_id, proc_chain_id, proc_flags; synthetic_test=spawn mock projectile and hit mock enemy`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "split_projectile",
    "params": {"target_count": 2, "damage_multiplier": 0.35, "on_hit_efficiency": 0.5, "once_per_parent": true, "prefer_unhit_targets": true, "proc_flag": "split_projectile"},
    "max_proc_depth": 2,
    "effect_family": "split_projectile",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_typhoon_split` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_projectile_hit` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_rune_volley_loop.gd` reports this id as covered in its route coverage list.

### 3. 珠光符文 (`aug_jeweled_rune`)

- `source_augment_name`: 珠光护手、易损
- `source_augment_rarity`: 珠光护手:棱彩；易损:金色
- `route_id`: `rune_volley`
- `route_label`: 符文弹幕链
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 转换器
- `trigger`: `on_damage_roll`
- `effect`: 技能伤害、元素爆发、持续伤害和装备/遗物伤害都可以暴击；暴击会给目标叠 1 层“裂纹”。
- `condition`: 暴击率至少 10% 时出现；裂纹 5 层时下次伤害额外 +30%。
- `value`: +20% 暴击率；技能暴击倍率 160%
- `synergy_tags`: `crit,skill,element,dot,converter`
- `required_tags`: `crit_chance`
- `excludes_tags`: ``
- `combo_value`: 让暴击路线和元素/DoT/法术路线互通。
- `fit`: 暴击弹幕、炼狱、虚空。
- `risk`: 暴击不足时偏弱。
- `why_close`: 高度转译“珠光护手”与“易损”的技能/DoT 暴击爽感。
- `implementation_hint`: DamagePacket 增加 can_crit 与 crit_source。
- `resource_path`: `data/content/augments/rune_volley/aug_jeweled_rune.tres`
- `test_owner`: `augment_rune_volley_loop.gd`
- `checkpoint_priority`: `9`
- `trigger_spec`: `trigger_id=on_damage_roll; signals=damage_roll_requested; required_packet_keys=amount, source_kind, tags, can_crit, crit_chance, crit_multiplier; synthetic_test=normalize packet then request roll`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "enable_crit_sources",
    "params": {"sources": ["skill", "element", "dot", "relic"], "crit_chance_add": 0.2, "skill_crit_multiplier": 1.6},
    "max_proc_depth": 2,
    "effect_family": "enable_crit_sources",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "add_stack_on_crit",
    "params": {"stack_tag": "crack", "stacks": 1, "threshold": 5, "next_damage_bonus": 0.3},
    "max_proc_depth": 2,
    "effect_family": "add_stack_on_crit",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_jeweled_rune` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_damage_roll` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_rune_volley_loop.gd` reports this id as covered in its route coverage list.

### 4. 暴击飞晶 (`aug_critical_shards`)

- `source_augment_name`: 暴击飞弹、双生火焰
- `source_augment_rarity`: 暴击飞弹:金色；双生火焰:银色
- `route_id`: `rune_volley`
- `route_label`: 符文弹幕链
- `rarity`: 金色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 放大器
- `trigger`: `on_crit`
- `effect`: 任意暴击会发射 2 枚追踪飞晶；若暴击来自技能，则飞晶数量按暴击率最多增至 4 枚。
- `condition`: 每个来源 0.25 秒内最多触发一次。
- `value`: 2-4 枚；每枚 20% 符文强度
- `synergy_tags`: `crit,missile,projectile,skill`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 暴击越多，飞弹越多；飞弹又可触发元素层。
- `fit`: 珠光符文、台风分裂。
- `risk`: 大量弹体需控制性能。
- `why_close`: 对应“暴击飞弹/双生火焰”的暴击生成额外弹体。
- `implementation_hint`: 对象池化 HomingShard，限制每秒生成上限。
- `resource_path`: `data/content/augments/rune_volley/aug_critical_shards.tres`
- `test_owner`: `augment_rune_volley_loop.gd`
- `checkpoint_priority`: `6`
- `trigger_spec`: `trigger_id=on_crit; signals=damage_applied_packet; required_packet_keys=is_crit, target, owner, hit_position, proc_chain_id; synthetic_test=force crit packet`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "spawn_projectile",
    "params": {"projectile_role": "crit_shard", "base_count": 2, "max_count": 4, "homing": true, "trigger": "crit", "proc_flag": "crit_shard", "max_active_per_owner": 16},
    "max_proc_depth": 2,
    "effect_family": "crit_shard",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_critical_shards` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_crit` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_rune_volley_loop.gd` reports this id as covered in its route coverage list.

### 5. 虚幻武器 (`aug_ethereal_weapon`)

- `source_augment_name`: 虚幻武器
- `source_augment_rarity`: 虚幻武器:金色
- `route_id`: `rune_volley`
- `route_label`: 符文弹幕链
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 转换器
- `trigger`: `on_skill_hit`
- `effect`: 技能和 orbit 命中也会施加当前武器的 on_hit 效果。
- `condition`: 同一敌人每 0.6 秒最多被同一技能触发一次。
- `value`: on_hit 效率 60%
- `synergy_tags`: `on_hit,skill,orbit,converter`
- `required_tags`: `has_on_hit`
- `excludes_tags`: ``
- `combo_value`: 把技能命中转化为普攻特效入口，极大提高联动密度。
- `fit`: orbit 法阵、元素叠层、火上浇油。
- `risk`: 若 on_hit 本身很强，需要单目标冷却。
- `why_close`: 直接转译“虚幻武器”的技能触发攻击特效。
- `implementation_hint`: 在 hit_effect_resolver 加 per_target_cooldown_key。
- `resource_path`: `data/content/augments/rune_volley/aug_ethereal_weapon.tres`
- `test_owner`: `augment_rune_volley_loop.gd`
- `checkpoint_priority`: `10`
- `trigger_spec`: `trigger_id=on_skill_hit; signals=damage_applied_packet; required_packet_keys=source_kind=skill|rune|zone|orbit, target, hit_position, tags; synthetic_test=emit skill hit packet`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "apply_on_hit_package",
    "params": {"source_kinds": ["skill", "orbit"], "efficiency": 1.0, "source_cooldown": 0.25, "proc_flag": "ethereal_on_hit"},
    "max_proc_depth": 2,
    "effect_family": "ethereal_on_hit",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_ethereal_weapon` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_skill_hit` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_rune_volley_loop.gd` reports this id as covered in its route coverage list.

### 6. 强攻三环 (`aug_press_chain`)

- `source_augment_name`: 地狱三头犬、点亮他们！
- `source_augment_rarity`: 地狱三头犬:棱彩；点亮他们！:银色
- `route_id`: `rune_volley`
- `route_label`: 符文弹幕链
- `rarity`: 金色
- `max_rank`: `3`
- `unique`: `false`
- `upgrade_type`: 启动器
- `trigger`: `on_hit`
- `effect`: 对同一目标累计 3 次命中后造成一次自适应爆发，并让其 3 秒内受到你的伤害 +12%。
- `condition`: 多目标各自计数；Boss 计数不会过期。
- `value`: 三环爆发 80% 武器强度
- `synergy_tags`: `on_hit,vulnerability,burst`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 高频弹体有稳定单体爆发，后续放大所有路线伤害。
- `fit`: 符文双持、台风、双发快射。
- `risk`: 清小怪时可能过度单体。
- `why_close`: 对应“强攻/丛刃”和“第4下”的计数爆发体验。
- `implementation_hint`: EnemyStatus 添加 hit_counter_by_owner。
- `resource_path`: `data/content/augments/rune_volley/aug_press_chain.tres`
- `test_owner`: `augment_rune_volley_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_hit; signals=projectile_hit, damage_applied_packet; required_packet_keys=source_kind, weapon_id, weapon_tags, target, on_hit_efficiency; synthetic_test=emit weapon on-hit packet`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "stack_on_target",
    "params": {"stack_tag": "press_chain", "threshold": 3, "duration": 3.0},
    "max_proc_depth": 2,
    "effect_family": "stack_on_target",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "apply_damage_and_vulnerability",
    "params": {"damage_type": "adaptive", "vulnerability_percent": 0.12, "vulnerability_seconds": 3.0},
    "max_proc_depth": 2,
    "effect_family": "apply_damage_and_vulnerability",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_press_chain` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_hit` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_rune_volley_loop.gd` reports this id as covered in its route coverage list.

### 7. 会心施法机 (`aug_crit_cast_engine`)

- `source_augment_name`: 由暴生急、纯粹主义者 - 术师
- `source_augment_rarity`: 由暴生急:银色；纯粹主义者 - 术师:银色
- `route_id`: `rune_volley`
- `route_label`: 符文弹幕链
- `rarity`: 银色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 转换器
- `trigger`: `passive_stat_convert`
- `effect`: 将 35% 暴击率转化为技能急速；若攻击速度超过上限，溢出攻速也转化为技能急速。
- `condition`: 不会降低原暴击率，只按当前值映射。
- `value`: 技能急速 = 暴击率*0.35 + 溢出攻速*0.25
- `synergy_tags`: `crit,cooldown,converter,skill_haste`
- `required_tags`: `crit_chance`
- `excludes_tags`: ``
- `combo_value`: 让暴击弹幕流也能进入技能循环流。
- `fit`: 珠光符文、炼狱导管。
- `risk`: 面板类，爽感依赖其它触发器。
- `why_close`: 转译“由暴生急”和“纯粹主义者”的属性互换。
- `implementation_hint`: 派生属性不要回写基础属性，避免循环。
- `resource_path`: `data/content/augments/rune_volley/aug_crit_cast_engine.tres`
- `test_owner`: `augment_rune_volley_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=passive_stat_convert; signals=augment_acquired, stat_recalculated; required_packet_keys=owner, stat_snapshot, augment_id; synthetic_test=acquire augment and recalc stats`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "convert_stat",
    "params": {"from_stat": "crit_chance", "to_stat": "cooldown_haste", "ratio": 0.35},
    "max_proc_depth": 2,
    "effect_family": "convert_stat",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "convert_overflow_stat",
    "params": {"from_stat": "attack_speed", "to_stat": "cooldown_haste"},
    "max_proc_depth": 2,
    "effect_family": "convert_overflow_stat",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_crit_cast_engine` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `passive_stat_convert` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_rune_volley_loop.gd` reports this id as covered in its route coverage list.

### 8. 收集者刻印 (`aug_collector_mark`)

- `source_augment_name`: 升级：收集者、裁决使
- `source_augment_rarity`: 升级：收集者:银色；裁决使:金色
- `route_id`: `rune_volley`
- `route_label`: 符文弹幕链
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 终结器/经济型
- `trigger`: `on_damage_to_low_hp`
- `effect`: 对低于 8% 生命的非 Boss 敌人直接处决；处决精英时掉落额外符文金币并刷新一个基础武器冷却。
- `condition`: Boss 改为造成一次 8% 当前生命伤害，10 秒冷却。
- `value`: 处决阈值 8%；精英金币 +1
- `synergy_tags`: `execute,economy,cooldown,kill`
- `required_tags`: `damage_build`
- `excludes_tags`: ``
- `combo_value`: 把高频伤害变成收割和经济滚雪球。
- `fit`: 强攻三环、暴击飞晶、夺金。
- `risk`: 阈值过高会破坏 Boss 战。
- `why_close`: 来自“升级：收集者”和“裁决使”的处决/刷新/金币。
- `implementation_hint`: Boss 使用 execute_as_bonus_damage 分支。
- `resource_path`: `data/content/augments/rune_volley/aug_collector_mark.tres`
- `test_owner`: `augment_rune_volley_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_damage_to_low_hp; signals=damage_applied_packet; required_packet_keys=target, target_health_ratio, enemy_class, boss_scalar; synthetic_test=damage mock low-hp normal and boss targets`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "execute_low_hp",
    "params": {"threshold_normal": 0.08, "allow_boss": false},
    "max_proc_depth": 2,
    "effect_family": "execute_low_hp",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "grant_currency",
    "params": {"target_class": "elite", "currency": "rune_gold"},
    "max_proc_depth": 2,
    "effect_family": "grant_currency",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "refund_cooldown",
    "params": {"target_class": "elite", "cooldown_scope": "basic_weapon"},
    "max_proc_depth": 2,
    "effect_family": "refund_cooldown",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_collector_mark` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_damage_to_low_hp` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_rune_volley_loop.gd` reports this id as covered in its route coverage list.

## 炼狱导管 (`inferno_conduit`)

### 1. 炼狱导管 (`aug_infernal_conduit`)

- `source_augment_name`: 炼狱导管
- `source_augment_rarity`: 炼狱导管:棱彩
- `route_id`: `inferno_conduit`
- `route_label`: 炼狱导管
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 启动器
- `trigger`: `on_skill_or_element_hit`
- `effect`: 命中敌人施加“符火”灼烧。符火每次跳伤返还最近一次使用武器 4% 冷却。
- `condition`: 每个敌人最多 12 层；同源冷却返还有 0.15 秒节流。
- `value`: 每层 8% 符文强度/秒，3 秒
- `synergy_tags`: `burn,dot,cooldown,skill`
- `required_tags`: `skill_hit`
- `excludes_tags`: ``
- `combo_value`: 形成火越多、冷却越快、火更多的闭环。
- `fit`: 范围技能、orbit、珠光符文。
- `risk`: 高层 DoT 要防性能与无限返还。
- `why_close`: 核心来自“炼狱导管”的灼烧返还冷却。
- `implementation_hint`: DoT tick 合并批处理，cooldown_refund_queue。
- `resource_path`: `data/content/augments/inferno_conduit/aug_infernal_conduit.tres`
- `test_owner`: `augment_inferno_loop.gd`
- `checkpoint_priority`: `2`
- `trigger_spec`: `trigger_id=on_skill_or_element_hit; signals=damage_applied_packet, rune_triggered; required_packet_keys=source_kind, element_tags, target, hit_position, cooldown_source_id; synthetic_test=emit skill and rune packets`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "add_burn_stack",
    "params": {"stack_tag": "rune_fire", "amount": 1, "from_sources": ["skill", "element"]},
    "max_proc_depth": 2,
    "effect_family": "add_burn_stack",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "refund_cooldown_on_dot",
    "params": {"refund_ratio": 0.04, "cooldown_source": "recent_weapon"},
    "max_proc_depth": 2,
    "effect_family": "refund_cooldown_on_dot",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_infernal_conduit` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_skill_or_element_hit` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_inferno_loop.gd` reports this id as covered in its route coverage list.

### 2. 火上浇油 (`aug_firebrand_runes`)

- `source_augment_name`: 火上浇油
- `source_augment_rarity`: 火上浇油:金色
- `route_id`: `inferno_conduit`
- `route_label`: 炼狱导管
- `rarity`: 金色
- `max_rank`: `3`
- `unique`: `false`
- `upgrade_type`: 启动器
- `trigger`: `on_hit`
- `effect`: on_hit 额外叠 1 层符火；普通 projectile 对已灼烧敌人额外 +10% 伤害。
- `condition`: 叠层不刷新所有来源，只刷新自身来源持续。
- `value`: 1 层符火；+10% 对灼烧伤害
- `synergy_tags`: `burn,on_hit,projectile`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 让普攻/弹幕自然接入灼烧体系。
- `fit`: 符文双持、台风分裂、虚幻武器。
- `risk`: 纯技能慢速流需要导管启动。
- `why_close`: 转译“火上浇油”的无限灼烧 on-hit。
- `implementation_hint`: StatusStack 使用 source_id 分组。
- `resource_path`: `data/content/augments/inferno_conduit/aug_firebrand_runes.tres`
- `test_owner`: `augment_inferno_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_hit; signals=projectile_hit, damage_applied_packet; required_packet_keys=source_kind, weapon_id, weapon_tags, target, on_hit_efficiency; synthetic_test=emit weapon on-hit packet`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "add_burn_stack",
    "params": {"stack_tag": "rune_fire", "amount": 1, "from_sources": ["on_hit"]},
    "max_proc_depth": 2,
    "effect_family": "add_burn_stack",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "modify_damage_vs_status",
    "params": {"status": "burning", "damage_bonus": 0.1, "source": "projectile"},
    "max_proc_depth": 2,
    "effect_family": "modify_damage_vs_status",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_firebrand_runes` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_hit` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_inferno_loop.gd` reports this id as covered in its route coverage list.

### 3. 慢炖法阵 (`aug_slow_cooker_aura`)

- `source_augment_name`: 慢炖
- `source_augment_rarity`: 慢炖:棱彩
- `route_id`: `inferno_conduit`
- `route_label`: 炼狱导管
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 放大器
- `trigger`: `periodic_aura`
- `effect`: 你周围 180 半径内敌人每秒叠 1 层符火；精英和 Boss 额外受到最大生命值魔法伤害。
- `condition`: 玩家移动时光环持续；远程风筝收益较低。
- `value`: 1% 最大生命值/秒，上限受 Boss 缩放
- `synergy_tags`: `burn,orbit,aura,max_hp`
- `required_tags`: `close_range`
- `excludes_tags`: ``
- `combo_value`: 把站怪堆变成稳定火力源。
- `fit`: 巨像熔炉、护盾转化、orbit。
- `risk`: 贴脸风险高。
- `why_close`: 保留“慢炖”的近身最大生命值灼烧。
- `implementation_hint`: Area2D 定时查询，不逐帧伤害。
- `resource_path`: `data/content/augments/inferno_conduit/aug_slow_cooker_aura.tres`
- `test_owner`: `augment_inferno_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic_aura; signals=augment_periodic_tick; required_packet_keys=owner, elapsed_seconds, nearby_enemies; synthetic_test=tick with enemies inside/outside radius`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "periodic_aura",
    "params": {"radius": 180, "tick_seconds": 1.0, "burn_stacks": 1},
    "max_proc_depth": 2,
    "effect_family": "periodic_aura",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "max_hp_damage",
    "params": {"target_classes": ["elite", "boss"], "damage_type": "magic", "boss_scalar": 0.3},
    "max_proc_depth": 2,
    "effect_family": "max_hp_damage",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_slow_cooker_aura` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic_aura` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_inferno_loop.gd` reports this id as covered in its route coverage list.

### 4. 辣椒油污 (`aug_chili_oil`)

- `source_augment_name`: 祖母的辣椒油
- `source_augment_rarity`: 祖母的辣椒油:金色
- `route_id`: `inferno_conduit`
- `route_label`: 炼狱导管
- `rarity`: 金色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 生存型/放大器
- `trigger`: `on_apply_burn`
- `effect`: 每施加 20 层符火，在目标脚下生成油污区：敌人受灼烧，玩家站入时持续治疗。
- `condition`: 同屏最多 6 个油污区。
- `value`: 油污 4 秒；治疗 2% 最大生命/秒
- `synergy_tags`: `burn,heal,ground_zone,sustain`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 灼烧路线获得续航，并制造站位目标。
- `fit`: 慢炖法阵、血契、圣盾。
- `risk`: 区域太多会污染读屏。
- `why_close`: 来自“祖母的辣椒油”的灼烧生成治疗/灼烧区域。
- `implementation_hint`: Tile/Area 节点池，超限删除最旧。
- `resource_path`: `data/content/augments/inferno_conduit/aug_chili_oil.tres`
- `test_owner`: `augment_inferno_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_apply_burn; signals=burn_stack_applied; required_packet_keys=target, stacks_added, total_stacks, hit_position; synthetic_test=apply burn stacks to mock target`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "counter_on_event",
    "params": {"event": "burn_stack_applied", "threshold": 20},
    "max_proc_depth": 2,
    "effect_family": "counter_on_event",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "spawn_zone",
    "params": {"zone_role": "oil", "enemy_effects": ["burn_dot"], "player_effects": ["heal_over_time"], "max_active": 8},
    "max_proc_depth": 2,
    "effect_family": "spawn_zone",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_chili_oil` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_apply_burn` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_inferno_loop.gd` reports this id as covered in its route coverage list.

### 5. 圣火转化 (`aug_holy_fire_conversion`)

- `source_augment_name`: 圣火
- `source_augment_rarity`: 圣火:金色
- `route_id`: `inferno_conduit`
- `route_label`: 炼狱导管
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 转换器
- `trigger`: `on_shield_or_heal`
- `effect`: 获得治疗或护盾时，对附近敌人施加可叠加符火。
- `condition`: 拾取回血也算；每次触发有 0.5 秒冷却。
- `value`: 附近 5 敌各 2 层符火
- `synergy_tags`: `burn,shield,heal,converter`
- `required_tags`: `heal_or_shield`
- `excludes_tags`: ``
- `combo_value`: 把防御资源转为灼烧启动器。
- `fit`: 护盾爆蛋、死亡之环、慢炖。
- `risk`: 无回复/护盾构筑不适合。
- `why_close`: 转译“圣火”的治疗护盾施加无限灼烧。
- `implementation_hint`: 统一 HealEvent 和 ShieldEvent 触发。
- `resource_path`: `data/content/augments/inferno_conduit/aug_holy_fire_conversion.tres`
- `test_owner`: `augment_inferno_loop.gd`
- `checkpoint_priority`: `12`
- `trigger_spec`: `trigger_id=on_shield_or_heal; signals=shield_gained, heal_received; required_packet_keys=owner, amount, packet, source_kind; synthetic_test=emit shield and heal events`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "convert_shield_heal_to_burn",
    "params": {"nearby_radius": 220, "burn_stack_tag": "rune_fire", "source_cooldown": 0.5},
    "max_proc_depth": 2,
    "effect_family": "convert_shield_heal_to_burn",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_holy_fire_conversion` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_shield_or_heal` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_inferno_loop.gd` reports this id as covered in its route coverage list.

### 6. 易燃暴击 (`aug_vulnerable_flame`)

- `source_augment_name`: 易损、珠光护手
- `source_augment_rarity`: 易损:金色；珠光护手:棱彩
- `route_id`: `inferno_conduit`
- `route_label`: 炼狱导管
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 转换器/放大器
- `trigger`: `on_dot_tick`
- `effect`: 符火和其它 DoT 可以暴击；DoT 暴击时向附近 2 个敌人溅射 50% 跳伤。
- `condition`: 需要暴击率；同一跳伤只溅射一次。
- `value`: +15% 暴击率；溅射 50%
- `synergy_tags`: `burn,dot,crit,splash`
- `required_tags`: `crit_chance`
- `excludes_tags`: ``
- `combo_value`: 把火焰从稳定 DoT 变成爆发连锁。
- `fit`: 珠光符文、暴击飞晶。
- `risk`: 暴击过高时清屏过强。
- `why_close`: 来自“易损”的 DoT/装备效果暴击。
- `implementation_hint`: DamagePacket.dot_can_crit，splash 不继承 splash。
- `resource_path`: `data/content/augments/inferno_conduit/aug_vulnerable_flame.tres`
- `test_owner`: `augment_inferno_loop.gd`
- `checkpoint_priority`: `7`
- `trigger_spec`: `trigger_id=on_dot_tick; signals=dot_tick; required_packet_keys=target, amount, dot_tag, proc_chain_id, proc_flags; synthetic_test=emit dot tick packet`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "enable_dot_crit",
    "params": {"dot_tags": ["rune_fire", "dot"], "crit_enabled": true},
    "max_proc_depth": 2,
    "effect_family": "enable_dot_crit",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "dot_splash",
    "params": {"target_count": 2, "damage_multiplier": 0.5, "proc_flag": "dot_splash", "per_target_cooldown": 0.25},
    "max_proc_depth": 2,
    "effect_family": "dot_splash",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_vulnerable_flame` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_dot_tick` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_inferno_loop.gd` reports this id as covered in its route coverage list.

### 7. 折磨者烙印 (`aug_tormentor_brand`)

- `source_augment_name`: 折磨者
- `source_augment_rarity`: 折磨者:银色
- `route_id`: `inferno_conduit`
- `route_label`: 炼狱导管
- `rarity`: 银色
- `max_rank`: `3`
- `unique`: `false`
- `upgrade_type`: 启动器
- `trigger`: `on_control`
- `effect`: 定身、击退、强减速或冻结敌人时，施加 4 层符火。
- `condition`: 减速需达到 60% 以上才算。
- `value`: 4 层符火
- `synergy_tags`: `burn,control,cc`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 让控制武器成为火焰路线启动器。
- `fit`: 巨像熔炉、冰寒、虚空裂隙。
- `risk`: 没有控制时无收益。
- `why_close`: 转译“折磨者”的控制触发灼烧。
- `implementation_hint`: CCEvent 标准化 control_strength。
- `resource_path`: `data/content/augments/inferno_conduit/aug_tormentor_brand.tres`
- `test_owner`: `augment_inferno_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_control; signals=control_applied; required_packet_keys=target, control_tag, owner, hit_position; synthetic_test=apply knockback/slow control fixture`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "control_to_burn",
    "params": {"burn_stack_tag": "rune_fire", "stacks": 4, "control_tags": ["root", "knockback", "slow_strong", "freeze"]},
    "max_proc_depth": 2,
    "effect_family": "control_to_burn",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_tormentor_brand` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_control` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_inferno_loop.gd` reports this id as covered in its route coverage list.

### 8. 炼狱终爆 (`aug_infernal_detonation`)

- `source_augment_name`: 炼狱龙魂、轨道镭射
- `source_augment_rarity`: 炼狱龙魂:银色；轨道镭射:棱彩
- `route_id`: `inferno_conduit`
- `route_label`: 炼狱导管
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 终结器
- `trigger`: `on_burn_stack_threshold`
- `effect`: 敌人达到 10 层符火时消耗 6 层，召唤一次小型炼狱爆炸；精英/Boss 每第 3 次爆炸改为轨道火束。
- `condition`: 同一目标 1.2 秒内最多触发一次。
- `value`: 爆炸 180% 符文强度；轨道火束 5% 最大生命
- `synergy_tags`: `burn,explode,laser,finisher`
- `required_tags`: `burn`
- `excludes_tags`: ``
- `combo_value`: 给灼烧循环一个视觉与伤害终点。
- `fit`: 炼狱导管、火上浇油、慢炖。
- `risk`: 阈值过低会遮蔽其它构筑。
- `why_close`: 融合“炼狱龙魂”的爆炸与“轨道镭射”的终局感。
- `implementation_hint`: StackThresholdTrigger + delayed AoE marker。
- `resource_path`: `data/content/augments/inferno_conduit/aug_infernal_detonation.tres`
- `test_owner`: `augment_inferno_loop.gd`
- `checkpoint_priority`: `13`
- `trigger_spec`: `trigger_id=on_burn_stack_threshold; signals=burn_stack_threshold; required_packet_keys=target, stacks, hit_position, owner; synthetic_test=force threshold event`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "burn_threshold_explosion",
    "params": {"threshold": 10, "consume_stacks": 6, "damage_type": "magic", "proc_flag": "burn_detonation"},
    "max_proc_depth": 2,
    "effect_family": "burn_detonation",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "replace_every_nth_on_class",
    "params": {"target_classes": ["elite", "boss"], "n": 3, "effect_type": "delayed_fire_beam"},
    "max_proc_depth": 2,
    "effect_family": "replace_every_nth_on_class",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_infernal_detonation` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_burn_stack_threshold` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_inferno_loop.gd` reports this id as covered in its route coverage list.

## 虚空裂隙连锁 (`void_cascade`)

### 1. 虚空裂隙 (`aug_void_rift`)

- `source_augment_name`: 虚空裂隙
- `source_augment_rarity`: 虚空裂隙:棱彩
- `route_id`: `void_cascade`
- `route_label`: 虚空裂隙连锁
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 启动器
- `trigger`: `on_skill_hit`
- `effect`: 技能或元素爆发命中时在目标位置留下裂隙；2 个裂隙距离小于 260 时连线并爆炸，造成魔法伤害和减速。
- `condition`: 每个敌人每 0.5 秒最多生成 1 个裂隙。
- `value`: 裂隙 5 秒；连线 130% 符文强度
- `synergy_tags`: `void,rifts,skill,slow`
- `required_tags`: `skill_hit`
- `excludes_tags`: ``
- `combo_value`: 把普通命中变成地图空间谜题和连锁伤害。
- `fit`: 穿透 projectile、范围法术。
- `risk`: 裂隙过多需要上限。
- `why_close`: 直接来自“虚空裂隙”。
- `implementation_hint`: RiftManager 管理最近点配对。
- `resource_path`: `data/content/augments/void_cascade/aug_void_rift.tres`
- `test_owner`: `augment_void_loop.gd`
- `checkpoint_priority`: `3`
- `trigger_spec`: `trigger_id=on_skill_hit; signals=damage_applied_packet; required_packet_keys=source_kind=skill|rune|zone|orbit, target, hit_position, tags; synthetic_test=emit skill hit packet`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "spawn_rift",
    "params": {"source_kinds": ["skill", "element"], "pair_distance": 260},
    "max_proc_depth": 2,
    "effect_family": "spawn_rift",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "rift_pair_explosion",
    "params": {"damage_type": "magic", "applies_slow": true, "proc_flag": "rift_line"},
    "max_proc_depth": 2,
    "effect_family": "rift_line",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_void_rift` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_skill_hit` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_void_loop.gd` reports this id as covered in its route coverage list.

### 2. 魔法飞弹 (`aug_magic_missile`)

- `source_augment_name`: 魔法飞弹
- `source_augment_rarity`: 魔法飞弹:金色
- `route_id`: `void_cascade`
- `route_label`: 虚空裂隙连锁
- `rarity`: 金色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 放大器
- `trigger`: `on_skill_hit`
- `effect`: 技能命中会发射一枚虚空飞弹，对目标造成基于最大生命值的真实伤害。
- `condition`: 同一敌人每 1 秒最多触发一次。
- `value`: 1.2% 最大生命真伤；Boss 0.45%
- `synergy_tags`: `missile,true_damage,max_hp,skill`
- `required_tags`: `skill_hit`
- `excludes_tags`: ``
- `combo_value`: 补足技能流对精英和 Boss 的穿透伤害。
- `fit`: 虚空裂隙、精准奇才。
- `risk`: 过强会让 Boss 失去压迫感。
- `why_close`: 来自“魔法飞弹”的技能命中最大生命值真伤。
- `implementation_hint`: BossDamageScalar 单独配置。
- `resource_path`: `data/content/augments/void_cascade/aug_magic_missile.tres`
- `test_owner`: `augment_void_loop.gd`
- `checkpoint_priority`: `8`
- `trigger_spec`: `trigger_id=on_skill_hit; signals=damage_applied_packet; required_packet_keys=source_kind=skill|rune|zone|orbit, target, hit_position, tags; synthetic_test=emit skill hit packet`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "spawn_projectile",
    "params": {"projectile_role": "void_missile", "homing": true, "damage_type": "true", "max_hp_ratio_source": true, "boss_scalar": 0.3, "proc_flag": "magic_missile"},
    "max_proc_depth": 2,
    "effect_family": "magic_missile",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_magic_missile` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_skill_hit` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_void_loop.gd` reports this id as covered in its route coverage list.

### 3. 精准奇才 (`aug_trueshot_prod`)

- `source_augment_name`: 精准奇才、老练狙神
- `source_augment_rarity`: 精准奇才:棱彩；老练狙神:金色
- `route_id`: `void_cascade`
- `route_label`: 虚空裂隙连锁
- `rarity`: 金色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 放大器
- `trigger`: `on_long_range_hit`
- `effect`: 从 420 以上距离造成伤害时，向目标发射穿透精准光矢；若命中精英，返还该武器 15% 冷却。
- `condition`: 每 0.8 秒触发一次。
- `value`: 光矢 120% 符文强度
- `synergy_tags`: `long_range,projectile,cooldown,poke`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 奖励走位和远程命中，让长手构筑有专属循环。
- `fit`: 远程符文弹、虚空裂隙。
- `risk`: 近战和 orbit 不适合。
- `why_close`: 结合“精准奇才”的远距弹幕与“老练狙神”的远距返还冷却。
- `implementation_hint`: hit_event.distance_from_player。
- `resource_path`: `data/content/augments/void_cascade/aug_trueshot_prod.tres`
- `test_owner`: `augment_void_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_long_range_hit; signals=damage_applied_packet; required_packet_keys=owner, target, source_position, hit_position, distance; synthetic_test=emit hit over distance threshold`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "long_range_bonus_projectile",
    "params": {"min_distance": 420, "projectile_role": "trueshot_bolt", "piercing": true},
    "max_proc_depth": 2,
    "effect_family": "long_range_bonus_projectile",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "refund_cooldown",
    "params": {"target_class": "elite", "refund_ratio": 0.15},
    "max_proc_depth": 2,
    "effect_family": "refund_cooldown",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_trueshot_prod` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_long_range_hit` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_void_loop.gd` reports this id as covered in its route coverage list.

### 4. 侵蚀回路 (`aug_erosion_loop`)

- `source_augment_name`: 侵蚀
- `source_augment_rarity`: 侵蚀:银色
- `route_id`: `void_cascade`
- `route_label`: 虚空裂隙连锁
- `rarity`: 银色
- `max_rank`: `3`
- `unique`: `false`
- `upgrade_type`: 放大器
- `trigger`: `on_damage`
- `effect`: 你的伤害叠加“侵蚀”，降低目标护甲与魔抗；满层后目标进入“易裂”状态，裂隙连线必定暴击。
- `condition`: 最多 8 层，持续 4 秒。
- `value`: 每层 -2% 抗性；满层 8
- `synergy_tags`: `resistance_shred,void,crit,vulnerability`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 将持续命中转化为团队式破防与裂隙爆发。
- `fit`: 虚空裂隙、魔法飞弹、弹球。
- `risk`: 对小怪可能来不及满层。
- `why_close`: 来自“侵蚀”的双抗削减。
- `implementation_hint`: Armor/MR debuff 用百分比而非直接改数值。
- `resource_path`: `data/content/augments/void_cascade/aug_erosion_loop.tres`
- `test_owner`: `augment_void_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_damage; signals=damage_applied_packet; required_packet_keys=target, amount, damage_type, tags; synthetic_test=emit generic damage packet`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "stack_resistance_shred",
    "params": {"stack_tag": "erosion", "stats": ["armor", "magic_resist"]},
    "max_proc_depth": 2,
    "effect_family": "stack_resistance_shred",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "apply_state_at_threshold",
    "params": {"state": "fracturable", "effect": "rift_line_guaranteed_crit"},
    "max_proc_depth": 2,
    "effect_family": "apply_state_at_threshold",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_erosion_loop` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_damage` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_void_loop.gd` reports this id as covered in its route coverage list.

### 5. 海克斯链魂 (`aug_hextech_chain`)

- `source_augment_name`: 海克斯科技龙魂
- `source_augment_rarity`: 海克斯科技龙魂:银色
- `route_id`: `void_cascade`
- `route_label`: 虚空裂隙连锁
- `rarity`: 银色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 启动器
- `trigger`: `periodic_next_hit`
- `effect`: 每 4 秒，你的下一次伤害触发链状闪电，弹跳 4 个敌人并减速。
- `condition`: 链状闪电可以生成 1 个裂隙，但不触发其它链状闪电。
- `value`: 4 跳；60% 符文强度；30% 减速
- `synergy_tags`: `chain_lightning,slow,void`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 给所有武器一个稳定连锁入口。
- `fit`: 虚空裂隙、侵蚀。
- `risk`: 不能让链电自我递归。
- `why_close`: 来自“海克斯科技龙魂”。
- `implementation_hint`: ChainContext 设置 no_chain_retrigger。
- `resource_path`: `data/content/augments/void_cascade/aug_hextech_chain.tres`
- `test_owner`: `augment_void_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic_next_hit; signals=augment_periodic_tick, damage_applied_packet; required_packet_keys=pending_next_hit_state, target, owner; synthetic_test=tick then apply next damage`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "set_pending_next_hit",
    "params": {"interval": 4.0, "effect_type": "chain_lightning", "bounce_count": 4, "applies_slow": true, "proc_flag": "chain_lightning"},
    "max_proc_depth": 2,
    "effect_family": "chain_lightning",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_hextech_chain` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic_next_hit` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_void_loop.gd` reports this id as covered in its route coverage list.

### 6. 弹球回响 (`aug_pinball_rift`)

- `source_augment_name`: 弹球、回力OK镖
- `source_augment_rarity`: 弹球:金色；回力OK镖:金色
- `route_id`: `void_cascade`
- `route_label`: 虚空裂隙连锁
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 放大器
- `trigger`: `on_projectile_or_rift_hit`
- `effect`: 符文弹、裂隙连线或回旋弹命中后可向墙体或另一名敌人反弹 1 次；反弹命中伤害 +25%。
- `condition`: 每个弹体只反弹一次。
- `value`: +1 反弹；+25% 反弹伤害
- `synergy_tags`: `bounce,projectile,void,boomerang`
- `required_tags`: `projectile_or_rift`
- `excludes_tags`: ``
- `combo_value`: 让空间连线更不可预测，形成弹球式清屏。
- `fit`: 虚空裂隙、精准奇才。
- `risk`: 复杂地形要处理寻路。
- `why_close`: 来自“弹球”和“回力OK镖”的反弹/往返体验。
- `implementation_hint`: Physics raycast 计算反弹方向。
- `resource_path`: `data/content/augments/void_cascade/aug_pinball_rift.tres`
- `test_owner`: `augment_void_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_projectile_or_rift_hit; signals=projectile_hit, rift_line_hit; required_packet_keys=target, hit_position, source_kind, bounce_count; synthetic_test=emit projectile and rift line hit`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "bounce_projectile_or_rift",
    "params": {"max_bounces": 1, "damage_bonus": 0.25, "sources": ["projectile", "rift_line", "boomerang"], "proc_flag": "pinball_bounce"},
    "max_proc_depth": 2,
    "effect_family": "pinball_bounce",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_pinball_rift` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_projectile_or_rift_hit` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_void_loop.gd` reports this id as covered in its route coverage list.

### 7. 物法双核 (`aug_duality_charge`)

- `source_augment_name`: 物法皆修
- `source_augment_rarity`: 物法皆修:棱彩
- `route_id`: `void_cascade`
- `route_label`: 虚空裂隙连锁
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 转换器
- `trigger`: `on_hit_and_skill_hit`
- `effect`: on_hit 获得 1 层秘术核，技能命中获得 1 层武力核；两种核各 5 层时，下次元素爆发消耗层数并造成混合伤害。
- `condition`: 两类层数独立，最多各 10 层。
- `value`: 混合爆发 250% 符文强度
- `synergy_tags`: `hybrid,converter,on_hit,skill,element`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 强迫玩家同时使用普攻式和技能式触发，形成双修闭环。
- `fit`: 虚幻武器、符文双持、虚空裂隙。
- `risk`: 单一路线构筑难以触发。
- `why_close`: 转译“物法皆修”的普攻给 AP、技能给 AD 的双向成长。
- `implementation_hint`: PlayerState 保存 duality_stacks。
- `resource_path`: `data/content/augments/void_cascade/aug_duality_charge.tres`
- `test_owner`: `augment_void_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_hit_and_skill_hit; signals=damage_applied_packet; required_packet_keys=source_kind=weapon|skill, target, owner; synthetic_test=emit one weapon and one skill hit`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "dual_stack",
    "params": {"weapon_hit_stack": "arcane_core", "skill_hit_stack": "force_core", "threshold_each": 5},
    "max_proc_depth": 2,
    "effect_family": "dual_stack",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "mixed_damage_burst",
    "params": {"consume_stacks": true, "damage_types": ["physical", "magic"]},
    "max_proc_depth": 2,
    "effect_family": "mixed_damage_burst",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_duality_charge` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_hit_and_skill_hit` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_void_loop.gd` reports this id as covered in its route coverage list.

### 8. 虚空坍缩 (`aug_void_collapse`)

- `source_augment_name`: 轨道镭射、卡皮巴拉空投
- `source_augment_rarity`: 轨道镭射:棱彩；卡皮巴拉空投:棱彩
- `route_id`: `void_cascade`
- `route_label`: 虚空裂隙连锁
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 终结器
- `trigger`: `on_rift_chain_count`
- `effect`: 3 秒内同一区域触发 3 次裂隙连线后，延迟 0.8 秒落下虚空坍缩，对范围内敌人造成最大生命值真实伤害。
- `condition`: Boss 缩放，屏幕最多同时 2 个坍缩。
- `value`: 小怪 6% 最大生命；Boss 1.2%
- `synergy_tags`: `void,true_damage,area,finisher`
- `required_tags`: `void,rifts`
- `excludes_tags`: ``
- `combo_value`: 把裂隙连锁推向清屏级终局。
- `fit`: 虚空裂隙、弹球回响、侵蚀。
- `risk`: 延迟标记要给玩家读屏。
- `why_close`: 融合“轨道镭射”的延迟区域与“卡皮巴拉空投”的最大生命真伤。
- `implementation_hint`: 生成 telegraph 圆形预警后结算。
- `resource_path`: `data/content/augments/void_cascade/aug_void_collapse.tres`
- `test_owner`: `augment_void_loop.gd`
- `checkpoint_priority`: `14`
- `trigger_spec`: `trigger_id=on_rift_chain_count; signals=rift_chain_triggered; required_packet_keys=region_id, chain_count, hit_position; synthetic_test=simulate three rift chains`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "regional_counter",
    "params": {"event": "rift_chain_triggered", "window_seconds": 3.0, "threshold": 3},
    "max_proc_depth": 2,
    "effect_family": "regional_counter",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "spawn_delayed_strike",
    "params": {"delay": 0.8, "strike_role": "void_collapse", "damage_type": "true", "max_hp_ratio_source": true, "boss_scalar": 0.3},
    "max_proc_depth": 2,
    "effect_family": "spawn_delayed_strike",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_void_collapse` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_rift_chain_count` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_void_loop.gd` reports this id as covered in its route coverage list.

## 圣盾转化 (`aegis_transmutation`)

### 1. 护盾爆蛋 (`aug_shield_egg`)

- `source_augment_name`: 砸开那颗蛋
- `source_augment_rarity`: 砸开那颗蛋:银色
- `route_id`: `aegis_transmutation`
- `route_label`: 圣盾转化
- `rarity`: 银色
- `max_rank`: `3`
- `unique`: `false`
- `upgrade_type`: 启动器
- `trigger`: `on_shield_break_or_expire`
- `effect`: 护盾破裂或自然结束时爆炸，对周围敌人造成与护盾值相关的魔法伤害。
- `condition`: 同一护盾只爆一次；小护盾可合并结算。
- `value`: 伤害 = 60% 护盾吸收值
- `synergy_tags`: `shield,explode,aoe`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 让每个护盾都有输出价值。
- `fit`: 巨脑法盾、风语祝福、圣火转化。
- `risk`: 没有护盾来源时无收益。
- `why_close`: 直接来自“砸开那颗蛋”。
- `implementation_hint`: ShieldInstance 记录 absorbed_value。
- `resource_path`: `data/content/augments/aegis_transmutation/aug_shield_egg.tres`
- `test_owner`: `augment_aegis_loop.gd`
- `checkpoint_priority`: `4`
- `trigger_spec`: `trigger_id=on_shield_break_or_expire; signals=shield_broken, shield_expired; required_packet_keys=owner, shield_amount, hit_position; synthetic_test=create shield then break/expire`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "shield_end_explosion",
    "params": {"triggers": ["break", "expire"], "damage_scales_with": "shield_amount", "radius_source": true},
    "max_proc_depth": 2,
    "effect_family": "shield_end_explosion",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_shield_egg` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_shield_break_or_expire` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_aegis_loop.gd` reports this id as covered in its route coverage list.

### 2. 死亡之环 (`aug_circle_of_death`)

- `source_augment_name`: 死亡之环
- `source_augment_rarity`: 死亡之环:棱彩
- `route_id`: `aegis_transmutation`
- `route_label`: 圣盾转化
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 转换器
- `trigger`: `on_heal_or_regen_tick`
- `effect`: 你获得的治疗和生命回复会按比例转化为对最近敌人的魔法伤害。
- `condition`: 治疗本身不减少；同一帧治疗合并。
- `value`: 转化伤害 = 45% 治疗量
- `synergy_tags`: `heal,regen,damage,converter`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 把续航型构筑变成稳定自动输出。
- `fit`: 辣椒油污、吸血习性、海洋龙魂。
- `risk`: 站位会自动选最近敌，可能打不到精英。
- `why_close`: 直接转译“死亡之环”。
- `implementation_hint`: HealEvent 批处理，nearest_enemy 查询。
- `resource_path`: `data/content/augments/aegis_transmutation/aug_circle_of_death.tres`
- `test_owner`: `augment_aegis_loop.gd`
- `checkpoint_priority`: `11`
- `trigger_spec`: `trigger_id=on_heal_or_regen_tick; signals=heal_received, regen_tick; required_packet_keys=owner, amount, source_kind; synthetic_test=emit heal and regen tick`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "convert_heal_to_damage",
    "params": {"sources": ["heal", "regen_tick"], "targeting": "nearest_enemy", "damage_type": "magic", "source_cooldown": 0.25},
    "max_proc_depth": 2,
    "effect_family": "convert_heal_to_damage",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_circle_of_death` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_heal_or_regen_tick` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_aegis_loop.gd` reports this id as covered in its route coverage list.

### 3. 会心治疗 (`aug_critical_healing`)

- `source_augment_name`: 会心治疗
- `source_augment_rarity`: 会心治疗:金色
- `route_id`: `aegis_transmutation`
- `route_label`: 圣盾转化
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 放大器
- `trigger`: `on_heal_or_shield`
- `effect`: 治疗和护盾可以暴击；暴击保护额外生成一圈小治疗波。
- `condition`: 需要暴击率；治疗波不再暴击。
- `value`: +15% 暴击率；暴击保护 180%
- `synergy_tags`: `heal,shield,crit,pulse`
- `required_tags`: `crit_chance`
- `excludes_tags`: ``
- `combo_value`: 让暴击不只服务输出，也服务保护与转伤。
- `fit`: 珠光符文、死亡之环、护盾爆蛋。
- `risk`: 暴击率低时波动大。
- `why_close`: 来自“会心治疗”。
- `implementation_hint`: ProtectionPacket 添加 can_crit。
- `resource_path`: `data/content/augments/aegis_transmutation/aug_critical_healing.tres`
- `test_owner`: `augment_aegis_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_heal_or_shield; signals=heal_received, shield_gained; required_packet_keys=owner, amount, source_kind; synthetic_test=emit heal/shield event`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "enable_heal_shield_crit",
    "params": {"sources": ["heal", "shield"]},
    "max_proc_depth": 2,
    "effect_family": "enable_heal_shield_crit",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "spawn_healing_wave_on_crit",
    "params": {"radius": 180, "source_cooldown": 0.5},
    "max_proc_depth": 2,
    "effect_family": "spawn_healing_wave_on_crit",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_critical_healing` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_heal_or_shield` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_aegis_loop.gd` reports this id as covered in its route coverage list.

### 4. 风语祝福 (`aug_windspeaker`)

- `source_augment_name`: 风语者的祝福
- `source_augment_rarity`: 风语者的祝福:棱彩
- `route_id`: `aegis_transmutation`
- `route_label`: 圣盾转化
- `rarity`: 金色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 生存型
- `trigger`: `on_heal_or_shield`
- `effect`: 获得治疗或护盾后，3 秒内护甲和魔抗提高；若护盾未被打破，结束时返还一部分为经验吸引范围。
- `condition`: 抗性效果可刷新不可叠加。
- `value`: +18 护甲/魔抗；拾取半径 +15%
- `synergy_tags`: `shield,heal,resist,pickup`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 提高防御路线的稳定性，并顺便改善幸存者拾取手感。
- `fit`: 护盾爆蛋、死亡之环。
- `risk`: 偏生存，直接输出较少。
- `why_close`: 转译“风语者的祝福”的治疗/护盾给双抗。
- `implementation_hint`: Buff 刷新持续时间，不叠层。
- `resource_path`: `data/content/augments/aegis_transmutation/aug_windspeaker.tres`
- `test_owner`: `augment_aegis_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_heal_or_shield; signals=heal_received, shield_gained; required_packet_keys=owner, amount, source_kind; synthetic_test=emit heal/shield event`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "temporary_resists_on_protection",
    "params": {"duration": 3.0, "sources": ["heal", "shield"]},
    "max_proc_depth": 2,
    "effect_family": "temporary_resists_on_protection",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "convert_unbroken_shield_to_pickup_radius",
    "params": {"on_expire_unbroken": true},
    "max_proc_depth": 2,
    "effect_family": "convert_unbroken_shield_to_pickup_radius",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_windspeaker` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_heal_or_shield` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_aegis_loop.gd` reports this id as covered in its route coverage list.

### 5. 圣盾音爆 (`aug_sonic_holy`)

- `source_augment_name`: 圣火、天音爆
- `source_augment_rarity`: 圣火:金色；天音爆:银色
- `route_id`: `aegis_transmutation`
- `route_label`: 圣盾转化
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 转换器
- `trigger`: `on_shield_or_heal`
- `effect`: 治疗或护盾触发时，在玩家周围释放音爆，造成伤害、减速，并附加 1 层符火。
- `condition`: 0.8 秒冷却。
- `value`: 100% 符文强度；40% 减速 1 秒
- `synergy_tags`: `shield,heal,slow,burn,converter`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 防御动作同时启动火焰与控场。
- `fit`: 圣火转化、炼狱导管、巨像熔炉。
- `risk`: 触发过频会盖过主武器。
- `why_close`: 结合“圣火”和“天音爆”的保护触发伤害/减速。
- `implementation_hint`: AreaDamage + BurnStackEvent。
- `resource_path`: `data/content/augments/aegis_transmutation/aug_sonic_holy.tres`
- `test_owner`: `augment_aegis_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_shield_or_heal; signals=shield_gained, heal_received; required_packet_keys=owner, amount, packet, source_kind; synthetic_test=emit shield and heal events`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "protection_pulse",
    "params": {"sources": ["heal", "shield"], "radius": 180, "effects": ["damage", "slow", "burn_stack"], "burn_stacks": 1},
    "max_proc_depth": 2,
    "effect_family": "protection_pulse",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_sonic_holy` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_shield_or_heal` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_aegis_loop.gd` reports this id as covered in its route coverage list.

### 6. 巨脑法盾 (`aug_big_brain_barrier`)

- `source_augment_name`: 超强大脑
- `source_augment_rarity`: 超强大脑:金色
- `route_id`: `aegis_transmutation`
- `route_label`: 圣盾转化
- `rarity`: 金色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 生存型
- `trigger`: `on_level_up_or_wave_start`
- `effect`: 根据法术强度/符文强度获得可刷新的预存护盾；护盾存在时技能伤害 +8%。
- `condition`: 护盾每波刷新，不能无限叠。
- `value`: 护盾 = 符文强度*3；伤害 +8%
- `synergy_tags`: `ap,shield,skill,survival`
- `required_tags`: `rune_power`
- `excludes_tags`: ``
- `combo_value`: 给法系构筑可靠保护，并喂给护盾爆蛋。
- `fit`: 护盾爆蛋、会心治疗。
- `risk`: 低符文强度收益有限。
- `why_close`: 来自“超强大脑”的 AP 转护盾。
- `implementation_hint`: WaveManager on_wave_start 发放 ShieldInstance。
- `resource_path`: `data/content/augments/aegis_transmutation/aug_big_brain_barrier.tres`
- `test_owner`: `augment_aegis_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_level_up_or_wave_start; signals=level_changed, wave_phase_started; required_packet_keys=owner, level, wave_phase_id; synthetic_test=emit level-up and wave start`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "grant_stored_shield",
    "params": {"sources": ["level_up", "wave_start"], "scales_with": "rune_power"},
    "max_proc_depth": 2,
    "effect_family": "grant_stored_shield",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "modify_damage_while_shielded",
    "params": {"damage_bonus": 0.08},
    "max_proc_depth": 2,
    "effect_family": "modify_damage_while_shielded",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_big_brain_barrier` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_level_up_or_wave_start` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_aegis_loop.gd` reports this id as covered in its route coverage list.

### 7. 信念冲击波 (`aug_faith_shockwave`)

- `source_augment_name`: 信念者的强化
- `source_augment_rarity`: 信念者的强化:棱彩
- `route_id`: `aegis_transmutation`
- `route_label`: 圣盾转化
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 终结器
- `trigger`: `on_damage_while_shielded_or_after_heal`
- `effect`: 你在护盾存在期间造成伤害会叠“信念”；满 30 层释放冲击波，并斩杀低生命普通敌人。
- `condition`: 精英/Boss 不斩杀，改为额外自适应伤害。
- `value`: 冲击波 300% 符文强度；斩杀 6%
- `synergy_tags`: `shield,heal,execute,shockwave,finisher`
- `required_tags`: `shield_or_heal`
- `excludes_tags`: ``
- `combo_value`: 给保护流一个主动清屏峰值。
- `fit`: 会心治疗、风语祝福、符文双持。
- `risk`: 需要持续护盾覆盖。
- `why_close`: 把原表“治疗/护盾友军后队友输出叠虔诚”转译为“受保护时自身输出叠信念”。
- `implementation_hint`: 信念层通过 DamageEvent + player.has_shield 判断。
- `resource_path`: `data/content/augments/aegis_transmutation/aug_faith_shockwave.tres`
- `test_owner`: `augment_aegis_loop.gd`
- `checkpoint_priority`: `15`
- `trigger_spec`: `trigger_id=on_damage_while_shielded_or_after_heal; signals=damage_applied_packet, heal_received; required_packet_keys=owner, target, shield_active, recent_heal_seconds; synthetic_test=damage while shielded and after heal`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "stack_while_shielded_or_recent_heal",
    "params": {"stack_tag": "faith", "threshold": 30},
    "max_proc_depth": 2,
    "effect_family": "stack_while_shielded_or_recent_heal",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "spawn_shockwave",
    "params": {"execute_low_hp_normal": true, "proc_flag": "faith_shockwave"},
    "max_proc_depth": 2,
    "effect_family": "faith_shockwave",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_faith_shockwave` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_damage_while_shielded_or_after_heal` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_aegis_loop.gd` reports this id as covered in its route coverage list.

### 8. 激光治疗阵 (`aug_laser_heal_array`)

- `source_augment_name`: 激光治疗
- `source_augment_rarity`: 激光治疗:棱彩
- `route_id`: `aegis_transmutation`
- `route_label`: 圣盾转化
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 召唤型/生存型
- `trigger`: `periodic`
- `effect`: 每 12 秒生成一束跟随最近精英方向的治疗激光；激光治疗玩家，伤害并减速敌人。
- `condition`: 激光持续 2.5 秒。
- `value`: 治疗 2% 最大生命/秒；伤害 70%/秒
- `synergy_tags`: `laser,heal,slow,periodic`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 周期性给站位和保护路线一段强势窗口。
- `fit`: 死亡之环、风语祝福、巨像。
- `risk`: 方向自动，无法精确瞄准。
- `why_close`: 来自“激光治疗”。
- `implementation_hint`: LineArea2D 跟随目标方向锁定。
- `resource_path`: `data/content/augments/aegis_transmutation/aug_laser_heal_array.tres`
- `test_owner`: `augment_aegis_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic; signals=augment_periodic_tick; required_packet_keys=owner, elapsed_seconds, nearest_enemy, enemy_clusters; synthetic_test=advance scheduler past interval`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "periodic_laser",
    "params": {"interval": 12.0, "targeting": "nearest_elite_direction", "player_effect": "heal", "enemy_effects": ["damage", "slow"], "max_active": 1},
    "max_proc_depth": 2,
    "effect_family": "periodic_laser",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_laser_heal_array` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_aegis_loop.gd` reports this id as covered in its route coverage list.

## 血契收割 (`blood_reaver`)

### 1. 不祥契约 (`aug_ominous_pact`)

- `source_augment_name`: 不祥契约
- `source_augment_rarity`: 不祥契约:棱彩
- `route_id`: `blood_reaver`
- `route_label`: 血契收割
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 代价型/启动器
- `trigger`: `on_cast`
- `effect`: 每次武器施放消耗 1.5% 当前生命；根据已损生命获得符文强度、移速和全能吸血。
- `condition`: 生命低于 10% 时不再自损。
- `value`: 每 10% 已损生命：+5% 伤害/+4% 移速/+2% 吸血
- `synergy_tags`: `self_damage,missing_hp,lifesteal,risk`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 构成低血高输出和吸血回拉的核心启动器。
- `fit`: 吸血习性、逃跑计划、血债处决。
- `risk`: 没有吸血或护盾时危险。
- `why_close`: 直接来自“不祥契约”。
- `implementation_hint`: SelfDamageEvent 不触发受伤掉落逻辑。
- `resource_path`: `data/content/augments/blood_reaver/aug_ominous_pact.tres`
- `test_owner`: `augment_blood_loop.gd`
- `checkpoint_priority`: `17`
- `trigger_spec`: `trigger_id=on_cast; signals=weapon_fired; required_packet_keys=owner, weapon_id, cooldown_source_id, current_health; synthetic_test=emit weapon cast`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "self_damage_on_cast",
    "params": {"current_health_percent_cost": 0.015, "cannot_kill": true},
    "max_proc_depth": 2,
    "effect_family": "self_damage_on_cast",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "missing_hp_scaling",
    "params": {"stats": ["rune_power", "move_speed", "omnivamp"]},
    "max_proc_depth": 2,
    "effect_family": "missing_hp_scaling",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_ominous_pact` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_cast` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_blood_loop.gd` reports this id as covered in its route coverage list.

### 2. 肩上恶魔 (`aug_devil_shoulder`)

- `source_augment_name`: 你肩上的恶魔
- `source_augment_rarity`: 你肩上的恶魔:棱彩
- `route_id`: `blood_reaver`
- `route_label`: 血契收割
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 代价型
- `trigger`: `periodic_drain_and_on_damage`
- `effect`: 恶魔持续汲取生命；你的所有伤害附加真实伤害，并有概率掉落生命残片。
- `condition`: 生命残片被吸附时治疗。
- `value`: 每秒流失 1% 最大生命；附加 8% 真伤
- `synergy_tags`: `self_drain,true_damage,life_fragment,risk`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 持续压力换来所有伤害类型的稳定放大。
- `fit`: 死亡之环、吸血习性、护盾爆蛋。
- `risk`: 长时间空窗会被自身流血杀死。
- `why_close`: 来自“你肩上的恶魔”的汲取生命、真伤、生命残片。
- `implementation_hint`: 残片用 Pickup 类型，带 owner_only。
- `resource_path`: `data/content/augments/blood_reaver/aug_devil_shoulder.tres`
- `test_owner`: `augment_blood_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic_drain_and_on_damage; signals=augment_periodic_tick, damage_applied_packet; required_packet_keys=owner, elapsed_seconds, target, amount; synthetic_test=tick drain then damage target`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "periodic_self_drain",
    "params": {"cannot_kill": true},
    "max_proc_depth": 2,
    "effect_family": "periodic_self_drain",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "add_true_damage_to_all_damage",
    "params": {"source_cooldown": 0.1},
    "max_proc_depth": 2,
    "effect_family": "add_true_damage_to_all_damage",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "drop_pickup_on_damage",
    "params": {"pickup_role": "life_fragment", "chance_source": "value"},
    "max_proc_depth": 2,
    "effect_family": "drop_pickup_on_damage",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_devil_shoulder` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic_drain_and_on_damage` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_blood_loop.gd` reports this id as covered in its route coverage list.

### 3. 吸血习性 (`aug_vampirism`)

- `source_augment_name`: 吸血习性、渴血
- `source_augment_rarity`: 吸血习性:金色；渴血:银色
- `route_id`: `blood_reaver`
- `route_label`: 血契收割
- `rarity`: 金色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 生存型/转换器
- `trigger`: `on_damage_dealt`
- `effect`: 获得全能吸血；作为代价，普通治疗拾取效果降低，但由你造成伤害产生的治疗提高。
- `condition`: 死亡之环按实际治疗量转伤。
- `value`: +12% 全能吸血；拾取治疗 -35%
- `synergy_tags`: `lifesteal,heal,converter,risk`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 把输出直接变成续航，服务血契路线。
- `fit`: 不祥契约、肩上恶魔、死亡之环。
- `risk`: 低伤害构筑会变脆。
- `why_close`: 转译“吸血习性/渴血”的全能吸血与代价。
- `implementation_hint`: HealSource 标记 pickup/damage_based。
- `resource_path`: `data/content/augments/blood_reaver/aug_vampirism.tres`
- `test_owner`: `augment_blood_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_damage_dealt; signals=damage_applied_packet; required_packet_keys=owner, target, final_amount, damage_type; synthetic_test=apply outgoing damage`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "grant_omnivamp",
    "params": {"scope": "all_damage"},
    "max_proc_depth": 2,
    "effect_family": "grant_omnivamp",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "modify_pickup_healing",
    "params": {"multiplier": "reduced"},
    "max_proc_depth": 2,
    "effect_family": "modify_pickup_healing",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "modify_damage_healing",
    "params": {"multiplier": "increased"},
    "max_proc_depth": 2,
    "effect_family": "modify_damage_healing",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_vampirism` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_damage_dealt` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_blood_loop.gd` reports this id as covered in its route coverage list.

### 4. 逃跑计划 (`aug_escape_plan`)

- `source_augment_name`: 逃跑计划、退敌力场
- `source_augment_rarity`: 逃跑计划:银色；退敌力场:银色
- `route_id`: `blood_reaver`
- `route_label`: 血契收割
- `rarity`: 银色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 生存型
- `trigger`: `on_low_hp`
- `effect`: 生命低于 35% 时获得衰减护盾和移速，并击退周围敌人。
- `condition`: 30 秒冷却。
- `value`: 护盾 20% 最大生命；移速 +60% 衰减
- `synergy_tags`: `low_hp,shield,knockback,speed`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 给高风险低血流一次拉开距离的机会。
- `fit`: 不祥契约、玻璃大炮。
- `risk`: 冷却中依旧很危险。
- `why_close`: 结合“逃跑计划”和“退敌力场”。
- `implementation_hint`: HealthThresholdTrigger + cooldown。
- `resource_path`: `data/content/augments/blood_reaver/aug_escape_plan.tres`
- `test_owner`: `augment_blood_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_low_hp; signals=low_hp_entered; required_packet_keys=owner, ratio, nearby_enemies; synthetic_test=set player below threshold`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "low_hp_defense_burst",
    "params": {"threshold": 0.35, "effects": ["shield", "move_speed", "knockback"], "cooldown_scope": "owner"},
    "max_proc_depth": 2,
    "effect_family": "low_hp_defense_burst",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_escape_plan` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_low_hp` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_blood_loop.gd` reports this id as covered in its route coverage list.

### 5. 黎明坚决 (`aug_dawn_resolve`)

- `source_augment_name`: 黎明使者的坚决
- `source_augment_rarity`: 黎明使者的坚决:金色
- `route_id`: `blood_reaver`
- `route_label`: 血契收割
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 生存型
- `trigger`: `on_below_half_hp`
- `effect`: 生命首次低于 50% 时，3 秒内回复大量最大生命，并短暂提高治疗转伤效率。
- `condition`: 45 秒冷却。
- `value`: 回复 24% 最大生命；死亡之环效率 +20%
- `synergy_tags`: `low_hp,regen,heal,survival`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 让低血构筑能扛过第一波爆发。
- `fit`: 死亡之环、吸血习性。
- `risk`: 爆发过高时可能来不及回复。
- `why_close`: 来自“黎明使者的坚决”的半血回复。
- `implementation_hint`: HoT 可被治疗强度放大。
- `resource_path`: `data/content/augments/blood_reaver/aug_dawn_resolve.tres`
- `test_owner`: `augment_blood_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_below_half_hp; signals=low_hp_entered, health_changed; required_packet_keys=owner, ratio, once_per_run_state; synthetic_test=cross 50 percent health`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "below_half_regen",
    "params": {"threshold": 0.5, "duration": 3.0, "once_per_cooldown": true},
    "max_proc_depth": 2,
    "effect_family": "below_half_regen",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "boost_heal_conversion",
    "params": {"duration": 3.0},
    "max_proc_depth": 2,
    "effect_family": "boost_heal_conversion",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_dawn_resolve` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_below_half_hp` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_blood_loop.gd` reports this id as covered in its route coverage list.

### 6. 血债飞踢 (`aug_blood_debt_execute`)

- `source_augment_name`: 飞身踢、裁决使
- `source_augment_rarity`: 飞身踢:棱彩；裁决使:金色
- `route_id`: `blood_reaver`
- `route_label`: 血契收割
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 终结器
- `trigger`: `on_damage_to_low_hp`
- `effect`: 低生命敌人被你的伤害命中时被飞踢处决；被踢目标撞到其它敌人会爆炸并治疗你。
- `condition`: 精英改为击退和爆炸，不直接处决。
- `value`: 处决 7%；爆炸 180% 符文强度
- `synergy_tags`: `execute,knockback,heal,finisher`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 把残血怪群变成回血和二次爆炸资源。
- `fit`: 速度恶魔、符文弹幕、血契。
- `risk`: 怪少时收益下降。
- `why_close`: 来自“飞身踢”的处决、击退、撞击爆炸与治疗。
- `implementation_hint`: 计算 knockback_path 碰撞目标。
- `resource_path`: `data/content/augments/blood_reaver/aug_blood_debt_execute.tres`
- `test_owner`: `augment_blood_loop.gd`
- `checkpoint_priority`: `16`
- `trigger_spec`: `trigger_id=on_damage_to_low_hp; signals=damage_applied_packet; required_packet_keys=target, target_health_ratio, enemy_class, boss_scalar; synthetic_test=damage mock low-hp normal and boss targets`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "execute_low_hp",
    "params": {"mode": "kick", "allow_boss": false},
    "max_proc_depth": 2,
    "effect_family": "execute_low_hp",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "collision_explosion",
    "params": {"on_kicked_target_collision": true},
    "max_proc_depth": 2,
    "effect_family": "collision_explosion",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "heal_player",
    "params": {"source": "kick_explosion"},
    "max_proc_depth": 2,
    "effect_family": "heal_player",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_blood_debt_execute` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_damage_to_low_hp` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_blood_loop.gd` reports this id as covered in its route coverage list.

### 7. 终点列车 (`aug_final_transit`)

- `source_augment_name`: 最终都市列车、俯冲轰炸
- `source_augment_rarity`: 最终都市列车:金色；俯冲轰炸:银色
- `route_id`: `blood_reaver`
- `route_label`: 血契收割
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 终结器/生存型
- `trigger`: `on_fatal_damage`
- `effect`: 受到致命伤害时免死并召唤荒原列车穿过屏幕，对路径敌人造成伤害；若列车击杀精英，返还此强化冷却的一部分。
- `condition`: 每局最多触发 2 次。
- `value`: 免死 1 HP；列车 500% 符文强度
- `synergy_tags`: `fatal,deathsave,line_aoe,revenge`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 让高风险路线有戏剧化反打。
- `fit`: 玻璃大炮、不祥契约。
- `risk`: 次数有限，不应替代常规生存。
- `why_close`: 转译“阵亡后列车/死亡爆炸”为幸存者可接受的免死反打。
- `implementation_hint`: DeathIntercept 系统在扣血前查询。
- `resource_path`: `data/content/augments/blood_reaver/aug_final_transit.tres`
- `test_owner`: `augment_blood_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_fatal_damage; signals=fatal_damage_received; required_packet_keys=owner, incoming_packet, cooldown_state; synthetic_test=send fatal packet`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "prevent_fatal_damage",
    "params": {"cooldown": 90.0, "min_health_after": 1},
    "max_proc_depth": 2,
    "effect_family": "prevent_fatal_damage",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "spawn_delayed_strike",
    "params": {"strike_role": "wasteland_train", "path": "screen_sweep"},
    "max_proc_depth": 2,
    "effect_family": "spawn_delayed_strike",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "refund_self_cooldown_on_elite_kill",
    "params": {"partial": true},
    "max_proc_depth": 2,
    "effect_family": "refund_self_cooldown_on_elite_kill",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_final_transit` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_fatal_damage` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_blood_loop.gd` reports this id as covered in its route coverage list.

### 8. 玻璃大炮 (`aug_glass_cannon`)

- `source_augment_name`: 玻璃大炮
- `source_augment_rarity`: 玻璃大炮:棱彩
- `route_id`: `blood_reaver`
- `route_label`: 血契收割
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 代价型
- `trigger`: `passive`
- `effect`: 最大生命降低，但所有直接伤害提高，并附加少量真实伤害。
- `condition`: 不能与歌利亚巨人同时出现。
- `value`: 最大生命 -30%；伤害 +20%；附加 5% 真伤
- `synergy_tags`: `risk,damage,true_damage`
- `required_tags`: `damage_build`
- `excludes_tags`: `glass_cannon`
- `combo_value`: 为长手或高吸血构筑提供高上限代价件。
- `fit`: 珠光符文、虚空、吸血习性。
- `risk`: 容错显著降低。
- `why_close`: 直接来自“玻璃大炮”。
- `implementation_hint`: excludes_tags 阻止与大型坦克路线共存。
- `resource_path`: `data/content/augments/blood_reaver/aug_glass_cannon.tres`
- `test_owner`: `augment_blood_loop.gd`
- `checkpoint_priority`: `18`
- `trigger_spec`: `trigger_id=passive; signals=augment_acquired, stat_recalculated; required_packet_keys=owner, augment_id, stat_snapshot; synthetic_test=acquire augment`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "modify_max_health",
    "params": {"op": "multiply", "value": "reduced"},
    "max_proc_depth": 2,
    "effect_family": "modify_max_health",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "modify_damage",
    "params": {"scope": "all_direct", "op": "add_percent", "value": "increased"},
    "max_proc_depth": 2,
    "effect_family": "modify_damage",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "add_true_damage",
    "params": {"scope": "direct_damage", "value": "small"},
    "max_proc_depth": 2,
    "effect_family": "add_true_damage",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_glass_cannon` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `passive` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_blood_loop.gd` reports this id as covered in its route coverage list.

## 雪步先锋 (`snowstep_vanguard`)

### 1. 神圣雪印 (`aug_holy_snowmark`)

- `source_augment_name`: 神圣雪球、史上最大雪球
- `source_augment_rarity`: 神圣雪球:棱彩；史上最大雪球:棱彩
- `route_id`: `snowstep_vanguard`
- `route_label`: 雪步先锋
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 启动器
- `trigger`: `periodic_auto_mark`
- `effect`: 每 7 秒向最近精英或高密度敌群投掷雪印；命中后你下一次朝该方向移动会自动短冲，并获得 0.5 秒免伤。
- `condition`: 不强制改变玩家方向；无目标时保留充能。
- `value`: 雪印伤害 180%；免伤 0.5 秒
- `synergy_tags`: `dash,snowball,invulnerable,mark`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 把 ARAM 雪球进场转译成低操作的自动标记+短冲。
- `fit`: 闪光弹、全凭身法、血债飞踢。
- `risk`: 误冲进危险区域。
- `why_close`: 融合“史上最大雪球/神圣雪球”的强化雪球和二段免伤。
- `implementation_hint`: 检测玩家输入方向与 mark 向量夹角。
- `resource_path`: `data/content/augments/snowstep_vanguard/aug_holy_snowmark.tres`
- `test_owner`: `augment_snowstep_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic_auto_mark; signals=augment_periodic_tick, movement_input_changed; required_packet_keys=owner, target_direction, marked_target; synthetic_test=tick mark then move toward mark`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "periodic_auto_mark",
    "params": {"interval": 7.0, "targeting": "elite_or_cluster"},
    "max_proc_depth": 2,
    "effect_family": "periodic_auto_mark",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "dash_toward_mark_on_movement",
    "params": {"invulnerability_seconds": 0.5},
    "max_proc_depth": 2,
    "effect_family": "dash_toward_mark_on_movement",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_holy_snowmark` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic_auto_mark` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_snowstep_loop.gd` reports this id as covered in its route coverage list.

### 2. 闪烁备用 (`aug_flash2`)

- `source_augment_name`: 闪闪现现
- `source_augment_rarity`: 闪闪现现:银色
- `route_id`: `snowstep_vanguard`
- `route_label`: 雪步先锋
- `rarity`: 银色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 启动器/生存型
- `trigger`: `on_manual_or_auto_blink`
- `effect`: 获得一层备用闪烁：生命低于 25% 或被包围时自动向安全方向闪现；也可由简易主动键释放。
- `condition`: 最多 2 层充能。
- `value`: 闪现距离 180；充能 12 秒
- `synergy_tags`: `blink,survival,mobility`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 给所有构筑一个低成本机动入口。
- `fit`: 闪光弹、暗影疾奔。
- `risk`: 自动闪现可能影响走位预期。
- `why_close`: 来自“第二个闪现”和召唤师技能急速。
- `implementation_hint`: 可配置 allow_manual_active。
- `resource_path`: `data/content/augments/snowstep_vanguard/aug_flash2.tres`
- `test_owner`: `augment_snowstep_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_manual_or_auto_blink; signals=manual_augment_input, low_hp_entered, surrounded_state_changed; required_packet_keys=owner, safe_direction, charge_count; synthetic_test=trigger manual and auto blink`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "grant_blink_charge",
    "params": {"charge_count": 1},
    "max_proc_depth": 2,
    "effect_family": "grant_blink_charge",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "auto_blink",
    "params": {"triggers": ["low_hp", "surrounded"], "targeting": "safe_direction"},
    "max_proc_depth": 2,
    "effect_family": "auto_blink",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "manual_blink",
    "params": {"input_action": "augment_active"},
    "max_proc_depth": 2,
    "effect_family": "manual_blink",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_flash2` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_manual_or_auto_blink` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_snowstep_loop.gd` reports this id as covered in its route coverage list.

### 3. 闪光爆破 (`aug_flashbang`)

- `source_augment_name`: 闪光弹
- `source_augment_rarity`: 闪光弹:银色
- `route_id`: `snowstep_vanguard`
- `route_label`: 雪步先锋
- `rarity`: 银色
- `max_rank`: `3`
- `unique`: `false`
- `upgrade_type`: 放大器
- `trigger`: `on_dash_or_blink`
- `effect`: 冲刺或闪烁结束时爆炸，伤害并减速附近敌人。
- `condition`: 每 0.6 秒最多触发一次。
- `value`: 120% 符文强度；50% 减速 1.2 秒
- `synergy_tags`: `dash,blink,explode,slow`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 把机动变成清群和控场。
- `fit`: 神圣雪印、闪烁备用、全凭身法。
- `risk`: 不位移则无收益。
- `why_close`: 直接来自“闪光弹”。
- `implementation_hint`: DashEvent 结束点生成 AoE。
- `resource_path`: `data/content/augments/snowstep_vanguard/aug_flashbang.tres`
- `test_owner`: `augment_snowstep_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_dash_or_blink; signals=dash_finished, blink_used; required_packet_keys=owner, end_position, nearby_enemies; synthetic_test=finish dash/blink near enemies`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "dash_blink_end_explosion",
    "params": {"effects": ["damage", "slow"], "radius_source": "value"},
    "max_proc_depth": 2,
    "effect_family": "dash_blink_end_explosion",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_flashbang` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_dash_or_blink` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_snowstep_loop.gd` reports this id as covered in its route coverage list.

### 4. 全凭身法 (`aug_dashing_engine`)

- `source_augment_name`: 全凭身法
- `source_augment_rarity`: 全凭身法:棱彩
- `route_id`: `snowstep_vanguard`
- `route_label`: 雪步先锋
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 放大器
- `trigger`: `passive_cooldown`
- `effect`: 所有冲刺、闪烁、雪印短冲和位移型武器冷却大幅缩短；每拾取 20 经验再返还一次位移冷却。
- `condition`: 不影响免死类逃生冷却。
- `value`: 位移冷却 -35%；拾取返还 25%
- `synergy_tags`: `dash,cooldown,pickup,mobility`
- `required_tags`: `has_dash_or_blink`
- `excludes_tags`: ``
- `combo_value`: 让机动路线从保命变成循环引擎。
- `fit`: 闪光爆破、速度恶魔。
- `risk`: 无位移构筑不适合。
- `why_close`: 来自“全凭身法”的位移技能急速。
- `implementation_hint`: CooldownGroup: mobility。
- `resource_path`: `data/content/augments/snowstep_vanguard/aug_dashing_engine.tres`
- `test_owner`: `augment_snowstep_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=passive_cooldown; signals=augment_acquired, experience_collected; required_packet_keys=owner, mobility_cooldowns, xp_amount; synthetic_test=acquire and collect XP`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "modify_mobility_cooldowns",
    "params": {"op": "multiply", "value": "reduced"},
    "max_proc_depth": 2,
    "effect_family": "modify_mobility_cooldowns",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "refund_mobility_cooldown_on_xp",
    "params": {"xp_threshold": 20},
    "max_proc_depth": 2,
    "effect_family": "refund_mobility_cooldown_on_xp",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_dashing_engine` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `passive_cooldown` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_snowstep_loop.gd` reports this id as covered in its route coverage list.

### 5. 暗影疾奔 (`aug_shadow_runner`)

- `source_augment_name`: 暗影疾奔、夜狩
- `source_augment_rarity`: 暗影疾奔:银色；夜狩:金色
- `route_id`: `snowstep_vanguard`
- `route_label`: 雪步先锋
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 生存型/放大器
- `trigger`: `on_dash_or_kill`
- `effect`: 冲刺后获得爆发移速；参与击杀精英后短暂潜行，潜行结束时下一次伤害提高。
- `condition`: 普通怪击杀只给少量移速。
- `value`: 移速 +70% 衰减；潜行 1.2 秒
- `synergy_tags`: `dash,stealth,speed,kill`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 让位移后有追击、脱战和爆发窗口。
- `fit`: 神圣雪印、血债飞踢。
- `risk`: 潜行不能在 Boss 技能中完全免伤。
- `why_close`: 来自“暗影疾奔”和“夜狩”。
- `implementation_hint`: Stealth 不取消已锁定投射物，只降低新锁定。
- `resource_path`: `data/content/augments/snowstep_vanguard/aug_shadow_runner.tres`
- `test_owner`: `augment_snowstep_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_dash_or_kill; signals=dash_finished, elite_killed; required_packet_keys=owner, target, elapsed_seconds; synthetic_test=dash then kill elite`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "dash_speed_burst",
    "params": {"duration_source": "value"},
    "max_proc_depth": 2,
    "effect_family": "dash_speed_burst",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "elite_kill_stealth",
    "params": {"duration_source": "value", "next_damage_bonus": true},
    "max_proc_depth": 2,
    "effect_family": "elite_kill_stealth",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_shadow_runner` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_dash_or_kill` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_snowstep_loop.gd` reports this id as covered in its route coverage list.

### 6. 魄罗王弹跳 (`aug_poro_king_bounce`)

- `source_augment_name`: 魄罗之王的弹跳
- `source_augment_rarity`: 魄罗之王的弹跳:棱彩
- `route_id`: `snowstep_vanguard`
- `route_label`: 雪步先锋
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 终结器
- `trigger`: `periodic`
- `effect`: 每 30 秒进入魄罗王弹跳 4 秒：获得高额减伤、无碰撞和移速，不能正常攻击，但连续弹跳伤害并击退敌人。
- `condition`: 期间自动选择附近密集点弹跳。
- `value`: 减伤 75%；每跳 160%
- `synergy_tags`: `periodic,bounce,knockback,damage_reduction`
- `required_tags`: `close_range`
- `excludes_tags`: ``
- `combo_value`: 提供 ARAM 式娱乐强开和混乱团战感。
- `fit`: 巨像熔炉、闪光爆破。
- `risk`: 期间主武器暂停，远程流收益低。
- `why_close`: 直接转译“魄罗之王的弹跳”。
- `implementation_hint`: 临时替换 player_state.combat_mode。
- `resource_path`: `data/content/augments/snowstep_vanguard/aug_poro_king_bounce.tres`
- `test_owner`: `augment_snowstep_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic; signals=augment_periodic_tick; required_packet_keys=owner, elapsed_seconds, nearest_enemy, enemy_clusters; synthetic_test=advance scheduler past interval`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "temporary_mode",
    "params": {"mode": "poro_king_bounce", "interval": 30.0, "duration": 4.0, "effects": ["damage_reduction", "no_collision", "move_speed", "bounce_damage", "knockback"], "disable_normal_attack": true},
    "max_proc_depth": 2,
    "effect_family": "temporary_mode",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_poro_king_bounce` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_snowstep_loop.gd` reports this id as covered in its route coverage list.

### 7. 飞身踢 (`aug_dropkick_dash`)

- `source_augment_name`: 飞身踢
- `source_augment_rarity`: 飞身踢:棱彩
- `route_id`: `snowstep_vanguard`
- `route_label`: 雪步先锋
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 终结器
- `trigger`: `on_dash_through_low_hp`
- `effect`: 冲刺路径穿过低生命敌人时将其踢飞；撞到墙体或另一名敌人时爆炸并治疗你。
- `condition`: 与血债飞踢共享处决标签，但触发条件为位移。
- `value`: 处决阈值 6%；治疗 3% 最大生命
- `synergy_tags`: `dash,execute,knockback,heal`
- `required_tags`: `dash`
- `excludes_tags`: ``
- `combo_value`: 让每次位移都可能变成收割镜头。
- `fit`: 神圣雪印、全凭身法。
- `risk`: 需要路径接触，不适合远程龟缩。
- `why_close`: 直接转译“飞身踢”。
- `implementation_hint`: DashHitbox 检查 low_hp。
- `resource_path`: `data/content/augments/snowstep_vanguard/aug_dropkick_dash.tres`
- `test_owner`: `augment_snowstep_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_dash_through_low_hp; signals=dash_finished; required_packet_keys=owner, dash_path, low_hp_targets; synthetic_test=dash through low-hp target fixture`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "dash_path_execute",
    "params": {"target_filter": "low_hp", "effect": "kick"},
    "max_proc_depth": 2,
    "effect_family": "dash_path_execute",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "collision_explosion",
    "params": {"on_kicked_target_collision": true},
    "max_proc_depth": 2,
    "effect_family": "collision_explosion",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "heal_player",
    "params": {"source": "dropkick"},
    "max_proc_depth": 2,
    "effect_family": "heal_player",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_dropkick_dash` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_dash_through_low_hp` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_snowstep_loop.gd` reports this id as covered in its route coverage list.

### 8. 速度恶魔 (`aug_speed_demon`)

- `source_augment_name`: 速度恶魔、唯快不破
- `source_augment_rarity`: 速度恶魔:银色；唯快不破:银色
- `route_id`: `snowstep_vanguard`
- `route_label`: 雪步先锋
- `rarity`: 银色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 放大器
- `trigger`: `on_skill_hit_and_damage_calc`
- `effect`: 技能命中给短暂衰减移速；你比目标越快，对其伤害越高。
- `condition`: 速度差增伤有上限。
- `value`: 移速 +35% 衰减；最高 +18% 伤害
- `synergy_tags`: `speed,damage,skill_hit,mobility`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 把幸存者走位速度变成输出属性。
- `fit`: 暗影疾奔、练腿日、急急小子。
- `risk`: 被减速时输出下降。
- `why_close`: 融合“速度恶魔”和“唯快不破”。
- `implementation_hint`: DamageCalc 读取 relative_speed_bonus。
- `resource_path`: `data/content/augments/snowstep_vanguard/aug_speed_demon.tres`
- `test_owner`: `augment_snowstep_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_skill_hit_and_damage_calc; signals=damage_roll_requested, damage_applied_packet; required_packet_keys=owner_speed, target_speed, source_kind=skill; synthetic_test=skill hit with speed delta`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "skill_hit_speed_buff",
    "params": {"decays": true},
    "max_proc_depth": 2,
    "effect_family": "skill_hit_speed_buff",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "damage_scale_by_speed_delta",
    "params": {"owner_speed_vs_target": true},
    "max_proc_depth": 2,
    "effect_family": "damage_scale_by_speed_delta",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_speed_demon` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_skill_hit_and_damage_calc` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_snowstep_loop.gd` reports this id as covered in its route coverage list.

## 巨像熔炉 (`colossus_furnace`)

### 1. 巨像勇气 (`aug_colossus_courage`)

- `source_augment_name`: 巨像的勇气
- `source_augment_rarity`: 巨像的勇气:棱彩
- `route_id`: `colossus_furnace`
- `route_label`: 巨像熔炉
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 启动器/生存型
- `trigger`: `on_control`
- `effect`: 定身、击退、冻结或强减速敌人后获得最大生命值相关护盾。
- `condition`: 每 1 秒最多触发一次。
- `value`: 护盾 = 5% 最大生命 + 40
- `synergy_tags`: `control,shield,tank`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 控制越多越能站住，开启坦克控场路线。
- `fit`: 残忍彗星、护盾爆蛋。
- `risk`: 无控制武器不适合。
- `why_close`: 直接来自“巨像的勇气”。
- `implementation_hint`: ControlEvent → ShieldGrant。
- `resource_path`: `data/content/augments/colossus_furnace/aug_colossus_courage.tres`
- `test_owner`: `augment_colossus_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_control; signals=control_applied; required_packet_keys=target, control_tag, owner, hit_position; synthetic_test=apply knockback/slow control fixture`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "control_grants_shield",
    "params": {"shield_scales_with": "max_health", "control_tags": ["root", "knockback", "slow_strong", "freeze"]},
    "max_proc_depth": 2,
    "effect_family": "control_grants_shield",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_colossus_courage` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_control` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_colossus_loop.gd` reports this id as covered in its route coverage list.

### 2. 残忍彗星 (`aug_cruel_comet`)

- `source_augment_name`: 残忍
- `source_augment_rarity`: 残忍:棱彩
- `route_id`: `colossus_furnace`
- `route_label`: 巨像熔炉
- `rarity`: 金色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 放大器
- `trigger`: `on_control`
- `effect`: 控制敌人时在目标位置召唤延迟彗星，造成范围魔法伤害。
- `condition`: 每次技能每目标有独立冷却。
- `value`: 彗星 160% 符文强度 + 2% 最大生命
- `synergy_tags`: `control,comet,aoe,tank`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 把控制链变成可见爆发。
- `fit`: 巨像勇气、折磨者烙印。
- `risk`: 控制太短时怪可能走出范围。
- `why_close`: 直接来自“残忍”。
- `implementation_hint`: Telegraph 0.6 秒后结算。
- `resource_path`: `data/content/augments/colossus_furnace/aug_cruel_comet.tres`
- `test_owner`: `augment_colossus_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_control; signals=control_applied; required_packet_keys=target, control_tag, owner, hit_position; synthetic_test=apply knockback/slow control fixture`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "control_spawn_delayed_strike",
    "params": {"strike_role": "comet", "damage_type": "magic", "delay_source": "value"},
    "max_proc_depth": 2,
    "effect_family": "control_spawn_delayed_strike",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_cruel_comet` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_control` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_colossus_loop.gd` reports this id as covered in its route coverage list.

### 3. 不动如山 (`aug_impassable`)

- `source_augment_name`: 不动如山
- `source_augment_rarity`: 不动如山:金色
- `route_id`: `colossus_furnace`
- `route_label`: 巨像熔炉
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 生存型/放大器
- `trigger`: `on_control`
- `effect`: 控制敌人后获得短暂双抗，并在目标脚下生成减速冰川区域。
- `condition`: 区域持续 2.5 秒。
- `value`: +25 双抗；冰川 45% 减速
- `synergy_tags`: `control,resist,slow_zone,tank`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 增强控制后的站场和聚怪能力。
- `fit`: 慢炖法阵、残忍彗星。
- `risk`: 区域过多需要上限。
- `why_close`: 来自“余震/冰川增幅”组合。
- `implementation_hint`: GroundZonePool 限制 5 个。
- `resource_path`: `data/content/augments/colossus_furnace/aug_impassable.tres`
- `test_owner`: `augment_colossus_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_control; signals=control_applied; required_packet_keys=target, control_tag, owner, hit_position; synthetic_test=apply knockback/slow control fixture`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "control_grants_resists",
    "params": {"duration_source": "value"},
    "max_proc_depth": 2,
    "effect_family": "control_grants_resists",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "spawn_zone",
    "params": {"zone_role": "slow_glacier", "at": "target_position"},
    "max_proc_depth": 2,
    "effect_family": "spawn_zone",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_impassable` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_control` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_colossus_loop.gd` reports this id as covered in its route coverage list.

### 4. 坚若磐石 (`aug_adamant_layers`)

- `source_augment_name`: 坚若磐石
- `source_augment_rarity`: 坚若磐石:银色
- `route_id`: `colossus_furnace`
- `route_label`: 巨像熔炉
- `rarity`: 银色
- `max_rank`: `3`
- `unique`: `false`
- `upgrade_type`: 放大器
- `trigger`: `on_control`
- `effect`: 每次控制敌人叠加护甲或魔抗，持续 10 秒，最多 10 层。
- `condition`: 根据最近受到的伤害类型优先给对应抗性。
- `value`: 每层 +3 双抗
- `synergy_tags`: `control,resist,stack,tank`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 让频繁控制带来持续坦度。
- `fit`: 巨像勇气、不动如山。
- `risk`: 后排输出流收益低。
- `why_close`: 直接来自“坚若磐石”。
- `implementation_hint`: StackBuff duration_refresh。
- `resource_path`: `data/content/augments/colossus_furnace/aug_adamant_layers.tres`
- `test_owner`: `augment_colossus_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_control; signals=control_applied; required_packet_keys=target, control_tag, owner, hit_position; synthetic_test=apply knockback/slow control fixture`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "control_stack_resists",
    "params": {"stats": ["armor", "magic_resist"], "duration": 10.0, "max_stacks": 10},
    "max_proc_depth": 2,
    "effect_family": "control_stack_resists",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_adamant_layers` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_control` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_colossus_loop.gd` reports this id as covered in its route coverage list.

### 5. 吞噬灵魂 (`aug_soul_eater`)

- `source_augment_name`: 吞噬灵魂
- `source_augment_rarity`: 吞噬灵魂:金色
- `route_id`: `colossus_furnace`
- `route_label`: 巨像熔炉
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 叠层成长
- `trigger`: `on_control_elite_or_boss`
- `effect`: 控制精英、Boss 或大型敌人时永久增加最大生命；控制普通敌人积累进度，满进度也增加生命。
- `condition`: 越早拿越强。
- `value`: 精英 +8 生命；普通 20 次 +8
- `synergy_tags`: `control,permanent_hp,growth,tank`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 提供无限成长和后期巨像感。
- `fit`: 巨像勇气、歌利亚。
- `risk`: 过晚拿成长不足。
- `why_close`: 直接转译“吞噬灵魂”。
- `implementation_hint`: 保存 run_stat.permanent_hp_bonus。
- `resource_path`: `data/content/augments/colossus_furnace/aug_soul_eater.tres`
- `test_owner`: `augment_colossus_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_control_elite_or_boss; signals=control_applied; required_packet_keys=target_class, target, owner, progress_state; synthetic_test=control elite and multiple normal targets`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "permanent_max_health_on_control",
    "params": {"target_classes": ["elite", "boss", "large"]},
    "max_proc_depth": 2,
    "effect_family": "permanent_max_health_on_control",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "progress_on_control_normal",
    "params": {"reward": "max_health_at_full_progress"},
    "max_proc_depth": 2,
    "effect_family": "progress_on_control_normal",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_soul_eater` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_control_elite_or_boss` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_colossus_loop.gd` reports this id as covered in its route coverage list.

### 6. 献祭引擎 (`aug_immolate_engine`)

- `source_augment_name`: 任务：艾卡西亚的陷落、升级：献祭
- `source_augment_rarity`: 任务：艾卡西亚的陷落:棱彩；升级：献祭:银色
- `route_id`: `colossus_furnace`
- `route_label`: 巨像熔炉
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 启动器/经济型
- `trigger`: `periodic_aura`
- `effect`: 获得献祭光环：附近敌人持续受灼烧；每有 1 名敌人在光环内死亡，获得少量符文金币或任务进度。
- `condition`: 金币收益对普通怪有每秒上限。
- `value`: 光环 70%/秒；每 25 击杀 +1 金币
- `synergy_tags`: `aura,burn,economy,tank,quest`
- `required_tags`: `close_range`
- `excludes_tags`: ``
- `combo_value`: 坦克站怪堆也能滚经济和灼烧。
- `fit`: 慢炖、巨像、圣盾。
- `risk`: 远程流几乎不用。
- `why_close`: 转译艾卡西亚/献祭装备线。
- `implementation_hint`: AuraDamage + capped GoldDrop。
- `resource_path`: `data/content/augments/colossus_furnace/aug_immolate_engine.tres`
- `test_owner`: `augment_colossus_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic_aura; signals=augment_periodic_tick; required_packet_keys=owner, elapsed_seconds, nearby_enemies; synthetic_test=tick with enemies inside/outside radius`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "periodic_aura",
    "params": {"aura_role": "immolate", "damage_type": "burn"},
    "max_proc_depth": 2,
    "effect_family": "periodic_aura",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "grant_currency_or_progress_on_aura_death",
    "params": {"currency": "rune_gold"},
    "max_proc_depth": 2,
    "effect_family": "grant_currency_or_progress_on_aura_death",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_immolate_engine` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic_aura` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_colossus_loop.gd` reports this id as covered in its route coverage list.

### 7. 歌利亚巨人 (`aug_goliath`)

- `source_augment_name`: 歌利亚巨人
- `source_augment_rarity`: 歌利亚巨人:棱彩
- `route_id`: `colossus_furnace`
- `route_label`: 巨像熔炉
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 代价型/生存型
- `trigger`: `passive`
- `effect`: 体型变大，最大生命和适应之力大幅提高；受弹体命中概率提高，但近身光环半径扩大。
- `condition`: 不能与玻璃大炮同时出现。
- `value`: 最大生命 +40%；体型 +35%；光环半径 +25%
- `synergy_tags`: `body_size,max_hp,aura,risk`
- `required_tags`: ``
- `excludes_tags`: `giant_body`
- `combo_value`: 把站场路线推向巨型前排幻想。
- `fit`: 献祭引擎、慢炖法阵。
- `risk`: 更容易被包围和命中。
- `why_close`: 直接来自“歌利亚巨人”。
- `implementation_hint`: body_size 影响碰撞和光环半径。
- `resource_path`: `data/content/augments/colossus_furnace/aug_goliath.tres`
- `test_owner`: `augment_colossus_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=passive; signals=augment_acquired, stat_recalculated; required_packet_keys=owner, augment_id, stat_snapshot; synthetic_test=acquire augment`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "modify_body_scale",
    "params": {"value": "increased"},
    "max_proc_depth": 2,
    "effect_family": "modify_body_scale",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "modify_max_health",
    "params": {"op": "add_percent", "value": "large"},
    "max_proc_depth": 2,
    "effect_family": "modify_max_health",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "modify_adaptive_force",
    "params": {"op": "add_percent", "value": "large"},
    "max_proc_depth": 2,
    "effect_family": "modify_adaptive_force",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "modify_incoming_hit_profile",
    "params": {"easier_to_hit": true},
    "max_proc_depth": 2,
    "effect_family": "modify_incoming_hit_profile",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "modify_aura_radius",
    "params": {"op": "add_percent", "value": "increased"},
    "max_proc_depth": 2,
    "effect_family": "modify_aura_radius",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_goliath` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `passive` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_colossus_loop.gd` reports this id as covered in its route coverage list.

### 8. 困在这里 (`aug_stuck_with_me`)

- `source_augment_name`: 和我一起困在这里
- `source_augment_rarity`: 和我一起困在这里:棱彩
- `route_id`: `colossus_furnace`
- `route_label`: 巨像熔炉
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 终结器
- `trigger`: `periodic_taunt_pulse`
- `effect`: 每 22 秒释放嘲讽环：附近敌人被拉向你并短暂攻击你，同时你获得伤害减免；结束时根据吸收伤害爆炸。
- `condition`: Boss 不被嘲讽，只受拉扯减速。
- `value`: 减伤 60%；爆炸 = 35% 吸收伤害
- `synergy_tags`: `taunt,damage_reduction,explode,tank,finisher`
- `required_tags`: `max_hp_scaler`
- `excludes_tags`: ``
- `combo_value`: 给坦克路线一个强制聚怪清屏时刻。
- `fit`: 巨像勇气、护盾爆蛋、慢炖。
- `risk`: 嘲讽期间若减伤断档很危险。
- `why_close`: 转译“终极触发嘲讽+减伤”为周期坦克大招。
- `implementation_hint`: 记录窗口内 damage_prevented。
- `resource_path`: `data/content/augments/colossus_furnace/aug_stuck_with_me.tres`
- `test_owner`: `augment_colossus_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic_taunt_pulse; signals=augment_periodic_tick, damage_applied_packet; required_packet_keys=owner, absorbed_damage_ledger, nearby_enemies; synthetic_test=tick taunt and apply absorbed damage`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "periodic_taunt_pulse",
    "params": {"interval": 22.0, "pull_enemies": true, "force_attack_owner": true},
    "max_proc_depth": 2,
    "effect_family": "periodic_taunt_pulse",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "temporary_damage_reduction",
    "params": {"during": "taunt"},
    "max_proc_depth": 2,
    "effect_family": "temporary_damage_reduction",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "explode_absorbed_damage",
    "params": {"at_end": true},
    "max_proc_depth": 2,
    "effect_family": "explode_absorbed_damage",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_stuck_with_me` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic_taunt_pulse` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_colossus_loop.gd` reports this id as covered in its route coverage list.

## 自动奇观 (`summon_engine`)

### 1. 轨道镭射 (`aug_orbital_laser`)

- `source_augment_name`: 轨道镭射
- `source_augment_rarity`: 轨道镭射:棱彩
- `route_id`: `summon_engine`
- `route_label`: 自动奇观
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 终结器/召唤型
- `trigger`: `periodic_enemy_cluster`
- `effect`: 每 14 秒锁定敌人最密集区域，延迟 0.8 秒后发射轨道镭射，造成持续伤害和少量最大生命真伤。
- `condition`: 最多同时 1 条镭射。
- `value`: 持续 2 秒；每秒 140%；Boss 真伤 0.8%/秒
- `synergy_tags`: `laser,periodic,area,true_damage`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 周期性给玩家清屏和打 Boss 的大招感。
- `fit`: 虚空坍缩、仆从大师不影响镭射。
- `risk`: 延迟落点可能空。
- `why_close`: 直接来自“轨道镭射”。
- `implementation_hint`: ClusterFinder + telegraph。
- `resource_path`: `data/content/augments/summon_engine/aug_orbital_laser.tres`
- `test_owner`: `augment_summon_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic_enemy_cluster; signals=augment_periodic_tick; required_packet_keys=enemy_clusters, owner, elapsed_seconds; synthetic_test=spawn dense enemy cluster then tick`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "periodic_cluster_strike",
    "params": {"interval": 14.0, "delay": 0.8, "strike_role": "orbital_laser", "damage_type": "mixed", "max_hp_true_damage": "small", "max_active": 1},
    "max_proc_depth": 2,
    "effect_family": "periodic_cluster_strike",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_orbital_laser` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic_enemy_cluster` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_summon_loop.gd` reports this id as covered in its route coverage list.

### 2. 量子斩击 (`aug_quantum_slash`)

- `source_augment_name`: 量子计算
- `source_augment_rarity`: 量子计算:棱彩
- `route_id`: `summon_engine`
- `route_label`: 自动奇观
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 终结器
- `trigger`: `periodic`
- `effect`: 每 10 秒自动向玩家前方或最近精英方向释放巨型斩击，减速、造成最大生命伤害并治疗你。
- `condition`: 近中距离收益最高。
- `value`: 220% + 2% 最大生命；治疗 3% 最大生命
- `synergy_tags`: `periodic,slash,heal,max_hp`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 自动大招兼顾输出和续航。
- `fit`: 死亡之环、血契。
- `risk`: 方向可能不符合玩家预期。
- `why_close`: 直接来自“量子计算”。
- `implementation_hint`: 选择 aim_direction: elite 或 velocity。
- `resource_path`: `data/content/augments/summon_engine/aug_quantum_slash.tres`
- `test_owner`: `augment_summon_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic; signals=augment_periodic_tick; required_packet_keys=owner, elapsed_seconds, nearest_enemy, enemy_clusters; synthetic_test=advance scheduler past interval`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "periodic_slash",
    "params": {"interval": 10.0, "targeting": "forward_or_nearest_elite", "effects": ["slow", "max_hp_damage", "heal_player"]},
    "max_proc_depth": 2,
    "effect_family": "periodic_slash",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_quantum_slash` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_summon_loop.gd` reports this id as covered in its route coverage list.

### 3. 回力OK镖 (`aug_boomerang`)

- `source_augment_name`: 回力OK镖
- `source_augment_rarity`: 回力OK镖:金色
- `route_id`: `summon_engine`
- `route_label`: 自动奇观
- `rarity`: 金色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 召唤型/启动器
- `trigger`: `periodic`
- `effect`: 周期性投掷回旋符镖，出去和返回各造成一次伤害；返回命中玩家时缩短下次冷却。
- `condition`: 回收成功需要玩家站位。
- `value`: 每段 90%；回收返还 30% 冷却
- `synergy_tags`: `boomerang,periodic,positioning`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 让自动武器也有走位收益。
- `fit`: 弹球回响、虚空裂隙。
- `risk`: 站位差会少一段伤害。
- `why_close`: 直接来自“回力OK镖”。
- `implementation_hint`: Projectile has return_phase。
- `resource_path`: `data/content/augments/summon_engine/aug_boomerang.tres`
- `test_owner`: `augment_summon_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic; signals=augment_periodic_tick; required_packet_keys=owner, elapsed_seconds, nearest_enemy, enemy_clusters; synthetic_test=advance scheduler past interval`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "periodic_boomerang",
    "params": {"hits": ["outgoing", "returning"], "refund_on_return_hit_player": true, "proc_flag": "boomerang"},
    "max_proc_depth": 2,
    "effect_family": "boomerang",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_boomerang` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_summon_loop.gd` reports this id as covered in its route coverage list.

### 4. 狐火飞弹 (`aug_firefox`)

- `source_augment_name`: 火狐
- `source_augment_rarity`: 火狐:银色
- `route_id`: `summon_engine`
- `route_label`: 自动奇观
- `rarity`: 银色
- `max_rank`: `3`
- `unique`: `false`
- `upgrade_type`: 启动器/召唤型
- `trigger`: `periodic`
- `effect`: 每 5 秒生成 3 枚狐火，自动追踪附近敌人；释放时获得短暂移速。
- `condition`: 狐火优先未被命中的目标。
- `value`: 3 枚；每枚 55%；移速 +20% 1 秒
- `synergy_tags`: `missile,periodic,speed,auto`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 提供低门槛自动输出和机动。
- `fit`: 速度恶魔、暴击飞晶。
- `risk`: 单体输出一般。
- `why_close`: 直接来自“火狐”。
- `implementation_hint`: 简单 HomingMissile。
- `resource_path`: `data/content/augments/summon_engine/aug_firefox.tres`
- `test_owner`: `augment_summon_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic; signals=augment_periodic_tick; required_packet_keys=owner, elapsed_seconds, nearest_enemy, enemy_clusters; synthetic_test=advance scheduler past interval`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "periodic_homing_projectiles",
    "params": {"interval": 5.0, "count": 3, "projectile_role": "foxfire", "grant_move_speed": true, "max_active": 12},
    "max_proc_depth": 2,
    "effect_family": "periodic_homing_projectiles",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_firefox` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_summon_loop.gd` reports this id as covered in its route coverage list.

### 5. 魄罗爆破手 (`aug_poro_blaster`)

- `source_augment_name`: 魄罗爆破手
- `source_augment_rarity`: 魄罗爆破手:金色
- `route_id`: `summon_engine`
- `route_label`: 自动奇观
- `rarity`: 金色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 召唤型/放大器
- `trigger`: `on_hit_charge`
- `effect`: 命中积攒魄罗充能；满充能发射一只大魄罗，造成伤害并击退。高频命中可快速连发。
- `condition`: 最多储存 3 只魄罗。
- `value`: 10 命中充能；大魄罗 180%
- `synergy_tags`: `summon,charge,on_hit,knockback`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 把高频命中转化成自动控制单位。
- `fit`: 符文双持、台风分裂。
- `risk`: 低频武器充能慢。
- `why_close`: 直接来自“魄罗爆破手”。
- `implementation_hint`: ChargeCounter based on valid_hit。
- `resource_path`: `data/content/augments/summon_engine/aug_poro_blaster.tres`
- `test_owner`: `augment_summon_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_hit_charge; signals=damage_applied_packet; required_packet_keys=owner, target, charge_state, on_hit_efficiency; synthetic_test=emit repeated hits until charged`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "charge_on_hit",
    "params": {"charge_tag": "poro_charge"},
    "max_proc_depth": 2,
    "effect_family": "charge_on_hit",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "spawn_projectile_at_full_charge",
    "params": {"projectile_role": "big_poro", "effects": ["damage", "knockback"]},
    "max_proc_depth": 2,
    "effect_family": "spawn_projectile_at_full_charge",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_poro_blaster` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_hit_charge` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_summon_loop.gd` reports this id as covered in its route coverage list.

### 6. 仆从大师 (`aug_minionmancer`)

- `source_augment_name`: 仆从大师
- `source_augment_rarity`: 仆从大师:金色
- `route_id`: `summon_engine`
- `route_label`: 自动奇观
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 放大器
- `trigger`: `passive_summon_scaler`
- `effect`: 召唤物、炮塔、魄罗、狐火、回旋镖和 orbit 召唤单位的体型、生命、持续时间和伤害提高。
- `condition`: 不增强轨道镭射等纯环境伤害。
- `value`: +35% 召唤伤害；+25% 持续时间/生命
- `synergy_tags`: `summon,pet,orbit,scaler`
- `required_tags`: `summon_tag`
- `excludes_tags`: ``
- `combo_value`: 把零散自动单位合成召唤流核心。
- `fit`: 魄罗爆破手、狐火、男爵之手。
- `risk`: 没有召唤物时是空件。
- `why_close`: 来自“仆从大师”的召唤物全面增强。
- `implementation_hint`: source entity 添加 summon_tag。
- `resource_path`: `data/content/augments/summon_engine/aug_minionmancer.tres`
- `test_owner`: `augment_summon_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=passive_summon_scaler; signals=augment_acquired, summon_spawned; required_packet_keys=summon_tags, summon_stats, owner; synthetic_test=spawn summon before/after acquisition`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "scale_summons",
    "params": {"affected_tags": ["summon", "poro", "foxfire", "boomerang", "orbit"], "stats": ["size", "health", "duration", "damage"]},
    "max_proc_depth": 2,
    "effect_family": "scale_summons",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_minionmancer` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `passive_summon_scaler` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_summon_loop.gd` reports this id as covered in its route coverage list.

### 7. 男爵之手 (`aug_hand_of_baron`)

- `source_augment_name`: 男爵之手
- `source_augment_rarity`: 男爵之手:棱彩
- `route_id`: `summon_engine`
- `route_label`: 自动奇观
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 召唤型/经济型
- `trigger`: `on_elite_kill_or_pickup`
- `effect`: 击杀精英或拾取特殊祭坛后召唤 2 名荒原符兵；符兵沿玩家周围巡逻并攻击敌人。
- `condition`: 符兵受仆从大师增强。
- `value`: 符兵 12 秒；每只 45%/秒
- `synergy_tags`: `summon,minion,elite,baron`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 把地图推进转译为幸存者的临时随从压力。
- `fit`: 仆从大师、红包。
- `risk`: 随从 AI 需要简洁稳定。
- `why_close`: 保留“男爵强化小兵”的地图单位幻想。
- `implementation_hint`: SummonedMinion steering: orbit + seek。
- `resource_path`: `data/content/augments/summon_engine/aug_hand_of_baron.tres`
- `test_owner`: `augment_summon_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_elite_kill_or_pickup; signals=elite_killed, pickup_collected; required_packet_keys=owner, target_class, pickup_id; synthetic_test=kill elite and collect altar pickup`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "summon_on_elite_kill_or_pickup",
    "params": {"summon_role": "rune_soldier", "count": 2, "behavior": "patrol_and_attack"},
    "max_proc_depth": 2,
    "effect_family": "summon_on_elite_kill_or_pickup",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_hand_of_baron` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_elite_kill_or_pickup` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_summon_loop.gd` reports this id as covered in its route coverage list.

### 8. 神圣干预 (`aug_divine_intervention`)

- `source_augment_name`: 神圣干预、舞会女王
- `source_augment_rarity`: 神圣干预:金色；舞会女王:棱彩
- `route_id`: `summon_engine`
- `route_label`: 自动奇观
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 生存型/规则改写型
- `trigger`: `periodic`
- `effect`: 战斗开始 15 秒后，每 35 秒落下一颗护体星：你短暂无敌；若无敌期间触碰敌人，则魅惑/减速并造成小伤害。
- `condition`: 无敌不免疫位移控制，可选配置。
- `value`: 无敌 1.2 秒；魅惑/减速 1 秒
- `synergy_tags`: `periodic,invulnerable,charm,survival`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 周期性大招窗口，给自动奇观路线安全进场时刻。
- `fit`: 魄罗王弹跳、巨像熔炉。
- `risk`: 时间点固定，可能浪费。
- `why_close`: 融合“神圣干预”的自动免伤和“舞会女王”的自动魅惑。
- `implementation_hint`: Timer 从 run_time 开始。
- `resource_path`: `data/content/augments/summon_engine/aug_divine_intervention.tres`
- `test_owner`: `augment_summon_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic; signals=augment_periodic_tick; required_packet_keys=owner, elapsed_seconds, nearest_enemy, enemy_clusters; synthetic_test=advance scheduler past interval`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "periodic_invulnerability_star",
    "params": {"initial_delay": 15.0, "interval": 35.0, "effects": ["invulnerable"]},
    "max_proc_depth": 2,
    "effect_family": "periodic_invulnerability_star",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "contact_effect_while_invulnerable",
    "params": {"effects": ["charm_or_slow", "small_damage"]},
    "max_proc_depth": 2,
    "effect_family": "contact_effect_while_invulnerable",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_divine_intervention` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_summon_loop.gd` reports this id as covered in its route coverage list.

## 海牛锻炉 (`quest_forge`)

### 1. 属性锻造器 (`aug_stats_forge`)

- `source_augment_name`: 属性！
- `source_augment_rarity`: 属性！:银色
- `route_id`: `quest_forge`
- `route_label`: 海牛锻炉
- `rarity`: 银色
- `max_rank`: `3`
- `unique`: `false`
- `upgrade_type`: 经济型/通用型
- `trigger`: `on_pick`
- `effect`: 立即获得 2 次属性锻造选择：从伤害、冷却、拾取、生命、移速、暴击中选。
- `condition`: 每局可重复出现。
- `value`: 2 个锻造器
- `synergy_tags`: `forge,stats,economy,choice`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 最稳定的补洞选项，也可作为路线保底。
- `fit`: 任何路线。
- `risk`: 不改变规则，爽感较低。
- `why_close`: 来自“属性！”。
- `implementation_hint`: 可复用 UpgradeChoice UI。
- `resource_path`: `data/content/augments/quest_forge/aug_stats_forge.tres`
- `test_owner`: `augment_forge_loop.gd`
- `checkpoint_priority`: `19`
- `trigger_spec`: `trigger_id=on_pick; signals=augment_acquired; required_packet_keys=owner, augment_id, selection_state; synthetic_test=select augment directly`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "grant_forge_choice",
    "params": {"choice_count": 2, "stats": ["damage", "cooldown", "pickup", "health", "move_speed", "crit"]},
    "max_proc_depth": 2,
    "effect_family": "grant_forge_choice",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_stats_forge` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_pick` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_forge_loop.gd` reports this id as covered in its route coverage list.
### 2. 属性叠属性 (`aug_stats_on_stats`)

- `source_augment_name`: 属性叠属性！、属性叠属性叠属性！
- `source_augment_rarity`: 属性叠属性！:金色；属性叠属性叠属性！:棱彩
- `route_id`: `quest_forge`
- `route_label`: 海牛锻炉
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 经济型/通用型
- `trigger`: `on_pick`
- `effect`: 获得 4 个属性锻造器；下一次三选一每个栏位额外刷新一次。
- `condition`: 棱彩版可提高高稀有锻造器概率。
- `value`: 4 锻造器；下次每栏 +1 reroll
- `synergy_tags`: `forge,reroll,economy,choice`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 提高路线成型和补关键属性能力。
- `fit`: 所有构筑，尤其赌高上限局。
- `risk`: 直接战力延迟。
- `why_close`: 来自两档“属性叠属性”。
- `implementation_hint`: UpgradeSystem 标记 next_offer_bonus_reroll。
- `resource_path`: `data/content/augments/quest_forge/aug_stats_on_stats.tres`
- `test_owner`: `augment_forge_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_pick; signals=augment_acquired; required_packet_keys=owner, augment_id, selection_state; synthetic_test=select augment directly`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "grant_forge_choice",
    "params": {"choice_count": 4},
    "max_proc_depth": 2,
    "effect_family": "grant_forge_choice",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "grant_next_choice_refresh",
    "params": {"refresh_per_slot": 1},
    "max_proc_depth": 2,
    "effect_family": "grant_next_choice_refresh",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_stats_on_stats` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_pick` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_forge_loop.gd` reports this id as covered in its route coverage list.

### 3. 红包祭品 (`aug_red_envelope`)

- `source_augment_name`: 红包、当心小蛋糕！
- `source_augment_rarity`: 红包:棱彩；当心小蛋糕！:棱彩
- `route_id`: `quest_forge`
- `route_label`: 海牛锻炉
- `rarity`: 金色
- `max_rank`: `2`
- `unique`: `false`
- `upgrade_type`: 经济型/生存型
- `trigger`: `periodic_pickup_spawn`
- `effect`: 地图周期性生成红包/小蛋糕；拾取获得金币、随机属性或治疗，并短暂扩大拾取半径。
- `condition`: 生成点偏向玩家前进方向。
- `value`: 每 25 秒 1 个；持续 18 秒
- `synergy_tags`: `pickup,gold,heal,random,economy`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 把经济、续航和走位目标结合。
- `fit`: 夺金、属性锻造器。
- `risk`: 玩家可能为捡红包冒险。
- `why_close`: 融合“红包”和“小蛋糕”的地图奖励。
- `implementation_hint`: SpawnDirector 避免生成在危险墙体内。
- `resource_path`: `data/content/augments/quest_forge/aug_red_envelope.tres`
- `test_owner`: `augment_forge_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=periodic_pickup_spawn; signals=augment_periodic_tick; required_packet_keys=owner, spawn_position, pickup_cap; synthetic_test=advance scheduler and count pickups`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "periodic_pickup_spawn",
    "params": {"pickup_roles": ["red_envelope", "cupcake"], "rewards": ["currency", "random_stat", "heal"], "temporary_pickup_radius": true},
    "max_proc_depth": 2,
    "effect_family": "periodic_pickup_spawn",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_red_envelope` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `periodic_pickup_spawn` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_forge_loop.gd` reports this id as covered in its route coverage list.

### 4. 夺金刻痕 (`aug_goldrend`)

- `source_augment_name`: 夺金
- `source_augment_rarity`: 夺金:棱彩
- `route_id`: `quest_forge`
- `route_label`: 海牛锻炉
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 经济型/启动器
- `trigger`: `on_damage_to_elite_or_boss`
- `effect`: 首次命中精英/Boss 后进入 4 秒夺金窗口：你的伤害附带魔法伤害，命中掉落符文金币并给移速。
- `condition`: 每名精英/Boss 12 秒冷却。
- `value`: 附加 35%；金币最多 5；移速 +20%
- `synergy_tags`: `gold,elite,speed,damage,economy`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 鼓励主动打精英，用战斗滚经济。
- `fit`: 收集者刻印、速度恶魔。
- `risk`: 普通清怪收益不高。
- `why_close`: 来自“夺金”的伤害、金币和移速。
- `implementation_hint`: PerEnemyCooldown + capped drops。
- `resource_path`: `data/content/augments/quest_forge/aug_goldrend.tres`
- `test_owner`: `augment_forge_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_damage_to_elite_or_boss; signals=damage_applied_packet, boss_damaged; required_packet_keys=target_class=elite|boss, owner, window_state; synthetic_test=damage elite and boss`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "open_gold_window_on_elite_boss_hit",
    "params": {"duration": 4.0, "effects": ["bonus_magic_damage", "currency_on_hit", "move_speed"]},
    "max_proc_depth": 2,
    "effect_family": "open_gold_window_on_elite_boss_hit",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_goldrend` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_damage_to_elite_or_boss` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_forge_loop.gd` reports this id as covered in its route coverage list.

### 5. 潘朵拉符盒 (`aug_pandora_box`)

- `source_augment_name`: 潘朵拉的盒子
- `source_augment_rarity`: 潘朵拉的盒子:棱彩
- `route_id`: `quest_forge`
- `route_label`: 海牛锻炉
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 规则改写型
- `trigger`: `on_pick`
- `effect`: 选择后立即重铸一个已拥有的非唯一、非终结器强化；新强化至少同稀有度，并更倾向当前主路线。
- `condition`: 可取消一次，避免毁局。
- `value`: 重铸 1 个；主路线权重 x2
- `synergy_tags`: `reroll,transmute,rule,choice`
- `required_tags`: ``
- `excludes_tags`: `unique,finisher`
- `combo_value`: 提供海克斯式赌上限和纠错能力。
- `fit`: 路线缺关键件时。
- `risk`: 可能把可用件洗成不适配。
- `why_close`: 直接来自“潘朵拉的盒子”。
- `implementation_hint`: Offer UI 先选 owned augment 再生成替换。
- `resource_path`: `data/content/augments/quest_forge/aug_pandora_box.tres`
- `test_owner`: `augment_forge_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_pick; signals=augment_acquired; required_packet_keys=owner, augment_id, selection_state; synthetic_test=select augment directly`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "reroll_owned_augment",
    "params": {"target_filter": ["non_unique", "non_finisher"], "min_rarity": "same", "prefer_current_main_route": true},
    "max_proc_depth": 2,
    "effect_family": "reroll_owned_augment",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_pandora_box` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_pick` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_forge_loop.gd` reports this id as covered in its route coverage list.

### 6. 质变混沌 (`aug_transmute_chaos`)

- `source_augment_name`: 质变：混沌、质变：棱彩阶
- `source_augment_rarity`: 质变：混沌:棱彩；质变：棱彩阶:金色
- `route_id`: `quest_forge`
- `route_label`: 海牛锻炉
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 规则改写型/代价型
- `trigger`: `on_pick`
- `effect`: 获得 2 个随机强化，其中至少 1 个为金色以上；但下一次升级三选一少 1 个选项。
- `condition`: 随机强化仍遵守 unique/excludes。
- `value`: 随机 2 个；下次 offer_count -1
- `synergy_tags`: `random,transmute,risk,rule`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 用确定选择权换爆炸上限。
- `fit`: 任何已成型但想赌的局。
- `risk`: 可能破坏路线一致性。
- `why_close`: 融合“质变混沌/棱彩阶”的随机高上限。
- `implementation_hint`: UpgradeSystem 支持 grant_random_augments。
- `resource_path`: `data/content/augments/quest_forge/aug_transmute_chaos.tres`
- `test_owner`: `augment_forge_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=on_pick; signals=augment_acquired; required_packet_keys=owner, augment_id, selection_state; synthetic_test=select augment directly`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "grant_random_augments",
    "params": {"count": 2, "min_gold_count": 1},
    "max_proc_depth": 2,
    "effect_family": "grant_random_augments",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "modify_next_option_count",
    "params": {"delta": -1},
    "max_proc_depth": 2,
    "effect_family": "modify_next_option_count",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_transmute_chaos` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_pick` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_forge_loop.gd` reports this id as covered in its route coverage list.

### 7. 海牛勇士任务 (`aug_urf_champion`)

- `source_augment_name`: 任务：海牛阿福的勇士、无限循环往复
- `source_augment_rarity`: 任务：海牛阿福的勇士:棱彩；无限循环往复:棱彩
- `route_id`: `quest_forge`
- `route_label`: 海牛锻炉
- `rarity`: 棱彩
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 终结器/任务型
- `trigger`: `quest_progress_on_kill_and_cast`
- `effect`: 任务：击杀 600 敌人或参与 6 次精英击杀。完成后进入阿福模式：所有武器冷却大幅缩短，并周期性重置一个随机武器。
- `condition`: 越早拿越强。
- `value`: 完成后冷却 -25%；每 8 秒刷新 1 武器
- `synergy_tags`: `quest,cooldown,urf,finisher`
- `required_tags`: `early_game`
- `excludes_tags`: ``
- `combo_value`: 做完任务后获得无限火力式节奏爆发。
- `fit`: 炼狱导管、符文弹幕。
- `risk`: 前期弱，后期拿价值低。
- `why_close`: 转译“海牛阿福任务”和“无限循环往复”的高急速。
- `implementation_hint`: QuestResource 保存 progress/complete_reward。
- `resource_path`: `data/content/augments/quest_forge/aug_urf_champion.tres`
- `test_owner`: `augment_forge_loop.gd`
- `checkpoint_priority`: `none`
- `trigger_spec`: `trigger_id=quest_progress_on_kill_and_cast; signals=enemy_died, elite_killed, weapon_fired; required_packet_keys=owner, kill_count, elite_count, cast_count; synthetic_test=simulate quest progress`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "quest_progress",
    "params": {"normal_kills_required": 600, "elite_kills_required": 6, "complete_if_any_requirement": true},
    "max_proc_depth": 2,
    "effect_family": "quest_progress",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "activate_cooldown_mode",
    "params": {"mode": "urf", "weapon_cooldown_multiplier": "greatly_reduced", "periodic_random_weapon_reset": true},
    "max_proc_depth": 2,
    "effect_family": "activate_cooldown_mode",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_urf_champion` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `quest_progress_on_kill_and_cast` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_forge_loop.gd` reports this id as covered in its route coverage list.

### 8. 移动中娅 (`aug_mobile_zhonya`)

- `source_augment_name`: 升级：中娅、升级：米凯尔的祝福
- `source_augment_rarity`: 升级：中娅:银色；升级：米凯尔的祝福:棱彩
- `route_id`: `quest_forge`
- `route_label`: 海牛锻炉
- `rarity`: 金色
- `max_rank`: `1`
- `unique`: `true`
- `upgrade_type`: 生存型/规则改写型
- `trigger`: `on_low_hp_or_controlled`
- `effect`: 低血或即将被致命伤害时进入短暂凝滞，期间仍可缓慢移动；结束时清除减速/定身并治疗少量生命。
- `condition`: 每 45 秒冷却。
- `value`: 凝滞 1 秒；移动速度 45%；治疗 6% 最大生命
- `synergy_tags`: `stasis,cleanse,heal,survival`
- `required_tags`: ``
- `excludes_tags`: ``
- `combo_value`: 给高难波次一个规则改写式保命。
- `fit`: 血契、玻璃大炮、巨像。
- `risk`: 冷却长，不能当常驻坦度。
- `why_close`: 转译“升级：中娅”的移动凝滞和“米凯尔”的解控治疗。
- `implementation_hint`: DeathIntercept 或 ControlEvent 触发 stasis。
- `resource_path`: `data/content/augments/quest_forge/aug_mobile_zhonya.tres`
- `test_owner`: `augment_forge_loop.gd`
- `checkpoint_priority`: `20`
- `trigger_spec`: `trigger_id=on_low_hp_or_controlled; signals=low_hp_entered, control_applied, fatal_damage_received; required_packet_keys=owner, ratio, control_tag, stasis_cooldown; synthetic_test=low hp and control fixture`
- `effect_spec_blueprint`:

```gdscript
[
  {
    "effect_type": "enter_stasis",
    "params": {"triggers": ["low_hp", "fatal_damage", "controlled"], "can_move_slowly": true},
    "max_proc_depth": 2,
    "effect_family": "enter_stasis",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "cleanse_control",
    "params": {"on_end": true},
    "max_proc_depth": 2,
    "effect_family": "cleanse_control",
    "blocks_same_family_recursion": true
  },
  {
    "effect_type": "heal_player",
    "params": {"on_end": true, "amount": "small"},
    "max_proc_depth": 2,
    "effect_family": "heal_player",
    "blocks_same_family_recursion": true
  },
]
```

- `test_assertions`:
  - Acquire `aug_mobile_zhonya` and assert it is recorded in `AugmentSystem` with the expected rank and route count.
  - Emit synthetic trigger `on_low_hp_or_controlled` and assert at least one `effect_spec_blueprint` effect changes damage, state, cooldown, node count, pickup count, quest progress, or selection state.
  - Assert proc-created packets respect `proc_depth`, `proc_chain_id`, and same-family recursion blocking when the effect can create follow-up damage.
  - Assert `augment_forge_loop.gd` reports this id as covered in its route coverage list.
