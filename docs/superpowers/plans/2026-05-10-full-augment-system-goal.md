# Full Augment System `/goal` Prompt

Use this as the implementation goal after the plan and manifest are reviewed.

```text
在当前 Godot 项目根目录中，基于以下两份项目内文档完整实现《符文荒原幸存者》的 72 个强化系统：

- docs/superpowers/plans/2026-05-10-full-augment-system-implementation-plan.md
- docs/superpowers/plans/2026-05-10-full-augment-system-content-manifest.md

忽略任何外部绝对路径作为运行时依赖。完整范围固定为 manifest 中 9 条路线 x 每条 8 个强化 = 72 个 AugmentData 强化；MVP20 只允许作为第一阶段可玩性 checkpoint，不是交付终点。最终不得留下 skipped、stub、仅资源无 runtime 行为的强化。

执行约束：
1. 先检查工作区状态，保护已有改动；不要回退无关文件；不要运行 tools/create_m0_scenes.gd。
2. 保持现有 M1 smoke 兼容。所有旧的 UpgradeData / RuneSystem / DamageSystem 调用必须在迁移期间通过兼容 wrapper 或桥接事件继续工作。
3. 以数据驱动为主：新增 AugmentData、AugmentTriggerSpec、AugmentEffectSpec、AugmentConditionSpec、AugmentRegistry、AugmentSystem、AugmentEffectRunner。不要为 72 个强化写 72 个互不复用的一次性分支；确需 one-off handler 时，必须在 docs/qa/augment-system-acceptance.md 中记录原因，并有专门 smoke 断言。
4. 每个 manifest 强化都必须生成 data/content/augments/<route>/<id>.tres，并保留 manifest 的全部源字段，同时提供可执行的 trigger/effects/condition/params。自然语言 effect/value 不能只作为 description 存在；必须映射成 AugmentEffectSpec.params。
5. 实现统一 DamagePacket / event contract，包括 proc_depth、proc_chain_id、proc_flags、source_kind、source_id、augment_id、weapon_id、owner、target、hit_position、can_crit、crit fields、on_hit_efficiency、cooldown_source_id、boss_scalar。
6. 所有 augment-created projectile、DoT、zone、summon、chain、splash、delayed strike 必须继承或创建 proc_chain_id，并设置 proc_flags；同一 effect family 不得在同一 proc_chain_id 内递归触发自己。
7. 实现路线权重三选一规则：rarity schedule、route weighting、starter guarantee、finisher downweight、required/excludes filtering、unique/rank tracking、high-risk guardrail，并保留旧 UpgradeData 支持直到迁移完成。
8. 更新 LevelUpPanel，使 AugmentData 和 UpgradeData 都能显示和选择；AugmentData 必须展示 display_name、rarity、route_label、upgrade_type、effect summary、condition/fit/risk。
9. 每阶段完成后运行对应 headless smoke；失败先修复本阶段相关问题，不跳过，不伪造 PASS。优先使用 Godot 4.6.2 headless。
10. 在 docs/qa/augment-system-acceptance.md 记录每阶段命令、结果、失败修复、最终 smoke 输出、72 个强化覆盖状态和 manual checklist 结果。

阶段闸门：
Phase 0 Baseline：
- 运行 README 当前 smoke 列表。
- 记录 pass/fail 到 docs/qa/augment-system-acceptance.md。
- 不修无关失败，只记录基线。

Phase 1 Event/Damage/Proc Infrastructure：
- 添加新 GameEvents signals。
- DamageSystem 支持 apply_damage(target, packet) 与旧 apply_damage(target, amount, tags, payload) wrapper。
- 迁移 WeaponController、Projectile、RuneSystem、HealthComponent、Enemy 的 packet 透传。
- 新增 augment_proc_safety_loop.gd。
- 必须通过 weapon_damage_loop.gd、rune_trigger_loop.gd、augment_proc_safety_loop.gd。

Phase 2A Resource Schema/Registry：
- 创建 AugmentData/Trigger/Effect/Condition/Forging resource schema。
- 创建 AugmentRegistry autoload 和 deterministic query API。
- augment_resource_contract.gd 必须验证 trigger/effect/condition schema、params 类型、resource_path、test_owner 和错误信息。

Phase 2B Complete 72 Content：
- 生成全部 72 个 .tres，不只 MVP20。
- augment_all_content_contract.gd 必须验证 exactly 72、9 routes x 8、id 唯一、字段完整、trigger 可解析、effects 非空、params 可执行、test_owner 存在。

Phase 3 Upgrade Pool/UI：
- UpgradeSystem 使用 AugmentRegistry 生成三选一，保留 UpgradeData 兼容。
- 实现 rarity/route/required/excludes/unique/rank/starter/finisher/high-risk 规则。
- LevelUpPanel 支持 AugmentData 显示和选择。
- 必须通过 augment_pool_selection_loop.gd、experience_levelup_loop.gd。

Phase 4 Shared Effect Runner：
- AugmentSystem 订阅事件并维护 acquired ids、ranks、route counts、stacks、cooldowns、per-target cooldowns、pending next-hit effects、active zones、active summons、quest progress。
- AugmentEffectRunner 实现通用 effect verbs：stat、projectile、split、DoT/burn、cooldown refund、crit、zone、delayed strike、summon、shield/heal、execute、fatal prevention、dash/blink、control、pickup/currency、forge choice、reroll、random grant、quest progress。
- 被移除或 reroll 的 augment 必须清理 runtime state。
- 被动效果只能按 rank 正确应用，不得重复叠加。

Phase 5 MVP20 Checkpoint：
- 按文档 MVP20 顺序实现前 20 个强化的资源、runtime、UI 和测试断言。
- MVP20 通过后继续 Phase 6，不得停止。

Phase 6 Complete Remaining 52 by Route：
- 按路线完成剩余强化：rune_volley、inferno_conduit、void_cascade、aegis_transmutation、blood_reaver、snowstep_vanguard、colossus_furnace、summon_engine、quest_forge。
- 每条路线 smoke 必须覆盖该路线 8 个强化的至少一次获取、一次触发或一条专用 contract 断言。
- 每条路线完成后运行对应 augment_<route>_loop.gd 和基础回归 smoke。

Final Acceptance：
- 最终运行 plan 中完整 smoke 列表。
- 72 个 AugmentData 全部存在且 runtime 行为可触发。
- 9 条路线各 8 个强化全部通过 route smoke 或专用 contract。
- 没有无限 proc、重复被动叠加、未清理 reroll state、无限节点生成或 Boss max-HP 真伤失控。
- UI 可以展示并选择 AugmentData。
- docs/qa/augment-system-acceptance.md 有完整最终记录。
```

