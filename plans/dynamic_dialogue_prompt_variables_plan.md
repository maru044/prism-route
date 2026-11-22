# 动态对话提示词变量扩充与空变量优雅处理方案

## 一、方案背景与设计目标

在《Prism Route 棱镜航线》中，玩家与 NPC 进行自由对话与口上交互时，系统会向大语言模型（LLM）注入动态世界书与上下文变量。此前存在两点局限：
1. **变量信息偏少**：实际交互中往往仅注入了基础信息，缺少当下互动的真实场景承载物与对决细节；
2. **场景割裂与空值污染**：战斗对决中有许多特有变量（如回合数、受击敏感区、上轮动作、绝顶濒危状态等），但离开战斗后这些变量并不存在。若未传变量被填充为「未指定」等字样，会导致提示词冗余且不自然。

本方案的核心目标：
- 严格基于当前游戏已有系统，仅保留真实可信的变量，彻底剔除不存在的脱靶字段（如不存在的天气系统、服装系统、独立好感数值系统等）；
- 确立「当前对话地点、当前交互阶段、绑定的场景家具」作为日常与大世界的核心基石；
- 建立完备的「战斗专属动态变量体系」，仅在身心快感对决期间提取并注入；
- 确立「空变量即留空」的原则：未传入或不适用的变量直接置空（空字符串），并配合行级自动修剪机制，确保非战斗场景下提示词纯净整洁。

---

## 二、当前游戏真实支持的基础与场景变量清单

以下变量均对应游戏底层现有系统，在大世界探索、家园驻留及神殿互动中均可准确获取：

| 变量占位符 | 字段含义 | 真实数据来源 | 取值示例 |
| :--- | :--- | :--- | :--- |
| `{{npc_name}}` | 对话 NPC 姓名 | `runtime.character_name` / `actor.get_display_name()` | 花火、刻晴、初音未来 |
| `{{character_id}}` | 角色唯一标识符 | `runtime.character_id` / `actor.character_id` | sparkle, keqing |
| `{{character_title}}` | 角色身份与称号 | `CharacterRosterDatabase` 中的 `title` | 假面愚者、玉衡星、大世界伙伴 |
| `{{dialogue_location}}` | 当前对话地点 | 地标解析、生成区域或家园房间号 | 初始神殿、沙洲度假遗址、家园 · plot_01 (家园房间 · bed_01) |
| `{{current_interaction_state}}` | 当前交互阶段 | 状态机当前状态 | 日常闲聊 / 初步试探、对决对峙中、战中交涉阶段、战后交涉结算中、家园闲聊、玩弄侍奉安置阶段 |
| `{{bound_furniture_info}}` | 绑定的场景家具 | 交互锚点或房间家具目录 | 神殿御座 / 石座、双人软床、拘束木桩、地面（默认无固定家具） |
| `{{companion_status}}` | 伴侣契约状态 | `is_companion_unlocked` | 已缔结契约（识趣玩伴）、初次相遇 / 尚未收服为玩伴 |
| `{{pleasure_npc}}` | 受访者当前快感 | `npc_pleasure.current_pleasure` 格式化 | 0.0% ~ 100.0% |
| `{{pleasure_player}}` | Master 当前快感 | `player_pleasure.current_pleasure` 格式化 | 0.0% ~ 100.0% |

---

## 三、新增战斗专属动态变量规划（仅在战斗时存在）

在身心快感对决中，`TurnCombatManager` 维护着回合与攻防状态。当玩家在战斗中点击「自由对话」或触发「战中交涉 / 绝顶危机」时，自动提取以下专属变量注入上下文：

| 变量占位符 | 字段含义 | 战时数据来源 | 取值示例 | 非战斗时表现 |
| :--- | :--- | :--- | :--- | :--- |
| `{{combat_round}}` | 当前战斗回合数 | `TurnCombatManager.round_count` | 第 1 回合、第 3 回合 | 保持为空（""） |
| `{{combat_phase}}` | 战时所处阶段 | `TurnCombatManager.current_phase` | Master行动回合、NPC行动回合、战中交涉阶段 | 保持为空（""） |
| `{{mid_battle_reason}}` | 战中交涉触发原因 | `mid_battle_dialogue_requested(reason)` | Master主动战中搭话、Master濒临绝顶咬牙求饶 | 保持为空（""） |
| `{{last_player_action}}` | Master 上一轮动作招式 | 上一轮指令名称 | 指尖轻抚、揉捏私处、防守姿态 | 保持为空（""） |
| `{{last_target_zone}}` | Master 上一轮刺激部位 | 上一轮敏感部位映射中文 | 敏感双乳、柔嫩口腔、私密花核、紧致菊部、娇嫩大腿 | 保持为空（""） |
| `{{last_npc_skill}}` | NPC 上一轮的反击招式 | 上轮 NPC 决策技能 | 柔舌挑逗、魅惑低语 | 保持为空（""） |
| `{{last_npc_koujou}}` | NPC 上一轮的娇喘呻吟台词 | 上轮受击触发的口上文本 | 真实的上一句反应台词 | 保持为空（""） |
| `{{player_danger_level}}` | Master 快感危险预警 | 由 `player_pleasure` 计算分档 | 从容自若、渐入佳境、心神动摇、濒临绝顶危机 (Edging Danger) | 保持为空（""） |
| `{{npc_pleasure_stage}}` | NPC 动情深度分档 | 由 `npc_pleasure` 计算分档 | 微喘动情、渐入佳境、意乱情迷、身心沦陷濒临绝顶 | 保持为空（""） |
| `{{combat_buffs}}` | 当前生效战术/识趣增益 | `TurnCombatManager.meta_settings` | 识趣生效（走神放水）、锁精结界生效中、心神合一（快感减免60%） | 保持为空（""） |

---

## 四、空变量优雅处理策略（“变量是空的，那么就空着即可”）

为了保证提示词输出给 LLM 时干净清爽，不再出现生硬的「未指定」字样，采取双重清洗机制：

### 1. 底层解析零回退
在 `scripts/ai/game_llm_client.gd` 的 `_expand_dialogue_prompt(text: String)` 中：
- 将原本的 `context.get(key, "未指定")` 彻底修改为 `context.get(key, "")`；
- 如果当前上下文未包含某个键（例如家园闲聊时没有 `combat_round`），直接展开为空字符串 `""`。

### 2. 模板行级自动修剪（Auto-prune Empty Label Lines）
在变量替换完成后，进行行级后处理：
- 扫描每一行，如果某行结构为标签名后跟冒号（如 `战斗回合：`、`上一轮攻防刺激：`），且冒号后除空白字符外没有任何内容，则自动将该整行剔除；
- 效果对比：
  - **在战斗中**：
    ```text
    当前对话地点：初始神殿
    当前互动阶段：对决对峙中
    场景家具绑定：神殿御座 / 石座
    双方快感状态：受访者 75.0% / Master 40.0%
    战斗回合：第 2 回合
    战斗阶段：战中交涉阶段
    交涉起因：Master主动战中搭话
    上一轮攻防刺激：Master 针对 敏感双乳 施展了【指尖轻抚】
    Master危险度：从容自若
    受访者动情状态：意乱情迷
    当前对决增益：识趣生效（走神放水）
    ```
  - **在日常/家园中（战斗变量自动隐匿，无多余空行）**：
    ```text
    当前对话地点：家园 · plot_01 (家园房间 · bed_01)
    当前互动阶段：家园闲聊
    场景家具绑定：双人软床
    伴侣契约状态：已缔结契约（识趣玩伴）
    双方快感状态：受访者 0.0% / Master 0.0%
    ```

---

## 五、代码落地与实施步骤

### 步骤 1：改进提示词展开器（`game_llm_client.gd`）
- 修改 `_expand_dialogue_prompt()`：
  - 默认返回值改为 `""`；
  - 增加空标签行过滤逻辑，按行分割，过滤掉冒号后为空的行，重新组装。

### 步骤 2：在战斗管理器中封装上下文打包接口（`turn_combat_manager.gd`）
- 增加方法 `get_combat_llm_context() -> Dictionary`：
  - 打包 `combat_round`、`combat_phase`、`last_player_action`、`last_target_zone`、`last_npc_skill`、`last_npc_koujou`、`player_danger_level`、`npc_pleasure_stage`、`combat_buffs` 等字段；
  - 敏感部位英文标识自动转换为优美的中文描述。

### 步骤 3：完善战斗与交互入口的上下文拼装
- 在 `scripts/world/npc_world_duel.gd` 与 `scripts/world/initial_temple_encounter_controller.gd` 中：
  - 在 `_on_free_dialogue_requested()` 及 `_on_mid_battle_dialogue_requested()` 中，判断若处于战斗阶段，则获取 `combat_manager.get_combat_llm_context()` 并合入 `extra_context`；
  - 确保在家园（`home_interaction_panel.gd`）和大世界常态下，不附带任何战斗字段。

### 步骤 4：更新世界书模板（`assets/ai/worldbook/角色与场景.md`）
- 将新增变量加入模板，按照“基础场景 -> 契约与快感 -> 战斗对决详情”清晰分层编排。

### 步骤 5：单元测试与回归验收
- 编写专项测试用例，覆盖：
  1. 家园/大世界对话时，提示词仅含地点、交互阶段、家具等，所有战斗标签全部自然消失且无残留空行；
  2. 战斗对决各阶段中，回合数、动作、部位、增益准确注入大模型请求正文。
