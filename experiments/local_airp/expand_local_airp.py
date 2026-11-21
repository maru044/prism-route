# -*- coding: utf-8 -*-
"""Script to expand local AIRP templates and multi-character wildcards.

Adheres strictly to the ZERO ELLIPSES RULE (no ellipsis characters anywhere).
"""

import json
from pathlib import Path
import re

REPO_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = REPO_ROOT / "assets" / "ai" / "local_airp"

def check_no_ellipses(text: str, label: str):
    bad = ["\u2026", "...", "\u2026\u2026"]
    for b in bad:
        if b in text:
            raise ValueError(f"Ellipsis found in {label}: {b}")

def main():
    # 1. Load existing templates
    templates_path = DATA_DIR / "templates.json"
    existing_templates = json.loads(templates_path.read_text(encoding="utf-8"))
    
    # Check existing templates for reply_ids
    existing_ids = {t["reply_id"] for t in existing_templates}
    
    # 2. Define new expansion templates
    new_templates = [
        {
            "reply_id": "combat_pleasure_25_01",
            "character_id": "shared",
            "scene_tags": ["combat_h", "intimate"],
            "content_tag": "combat_pleasure_25",
            "reference_queries": [
                "感觉怎么样，身体开始变热了吧",
                "这才刚刚开始呢，有感觉了吗",
                "稍微刺激一下你就受不了了吗",
                "身体在颤抖呢，很舒服吧",
                "敏感点被碰到了吗",
                "表情开始动摇了哦",
                "还嘴硬吗，心跳已经变快了",
                "快感只有两成左右吧，还能坚持吗",
                "战意开始瓦解了呢"
            ],
            "templates": [
                "{reaction}！{address}，{dialogue_core} {body_action}。",
                "{body_action}。{reaction}！{dialogue_core}",
                "{address}，{dialogue_core} {body_action}。"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_combat.pleasure_25",
                "body_action": "character.actions_combat.pleasure_25",
                "dialogue_core": "character.dialogues.combat_pleasure_25"
            },
            "style_tags": ["combat_h", "pleasure_stage"]
        },
        {
            "reply_id": "combat_pleasure_50_01",
            "character_id": "shared",
            "scene_tags": ["combat_h", "intimate"],
            "content_tag": "combat_pleasure_50",
            "reference_queries": [
                "已经到一半了哦，武器都拿不稳了吧",
                "快感已经过半了，还能思考吗",
                "身体完全软下来了呢",
                "呼吸变得好急促，很享受对吧",
                "连站都站不稳了吗",
                "抵抗的力道变弱了呢",
                "眼神变得湿润迷离了哦",
                "快感过半，理智还能撑多久",
                "身体已经开始主动想要了对吧"
            ],
            "templates": [
                "{reaction}！{dialogue_core} {body_action}。",
                "{body_action}！{address}，{dialogue_core}",
                "{dialogue_core} {reaction}！{body_action}。"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_combat.pleasure_50",
                "body_action": "character.actions_combat.pleasure_50",
                "dialogue_core": "character.dialogues.combat_pleasure_50"
            },
            "style_tags": ["combat_h", "pleasure_stage"]
        },
        {
            "reply_id": "combat_pleasure_75_01",
            "character_id": "shared",
            "scene_tags": ["combat_h", "intimate"],
            "content_tag": "combat_pleasure_75",
            "reference_queries": [
                "快感快到顶点了，身体已经擅自迎合了呢",
                "已经快忍不住要高潮了吧",
                "身体完全不听使唤了吧",
                "快要忍不住绝顶了吗",
                "马上就要到极限了哦",
                "求我呀，求我就让你释放",
                "眼神已经彻底涣散了呢",
                "已经完全沦陷了对吧",
                "再加把劲就要登顶了"
            ],
            "templates": [
                "{reaction}！{address}，{dialogue_core} {body_action}。",
                "{body_action}！{reaction}！{dialogue_core}",
                "{dialogue_core} {body_action}！{reaction}！"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_combat.pleasure_75",
                "body_action": "character.actions_combat.pleasure_75",
                "dialogue_core": "character.dialogues.combat_pleasure_75"
            },
            "style_tags": ["combat_h", "pleasure_stage"]
        },
        {
            "reply_id": "combat_pleasure_100_01",
            "character_id": "shared",
            "scene_tags": ["combat_h", "intimate"],
            "content_tag": "combat_pleasure_100",
            "reference_queries": [
                "去吧，彻底绝顶高潮吧",
                "高潮吧，把一切都释放出来",
                "到顶点了，绝顶吧",
                "绝顶的一瞬间真美呢",
                "完全高潮了，身体痉挛得好厉害",
                "彻底崩溃吧，绝顶的狂潮来了",
                "快感突破极限了，尽情释放吧",
                "高潮失神的样子太迷人了",
                "享受绝顶的一刻吧"
            ],
            "templates": [
                "{reaction}！{dialogue_core} {body_action}。",
                "{body_action}！{reaction}！{dialogue_core}",
                "{address}！{reaction}！{dialogue_core} {body_action}。"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_combat.pleasure_100",
                "body_action": "character.actions_combat.pleasure_100",
                "dialogue_core": "character.dialogues.combat_pleasure_100"
            },
            "style_tags": ["combat_h", "orgasm"]
        },
        {
            "reply_id": "combat_restraint_toy_01",
            "character_id": "shared",
            "scene_tags": ["combat_h", "intimate"],
            "content_tag": "combat_restraint",
            "reference_queries": [
                "被束缚住动弹不得的感觉如何",
                "道具在身体里震动的感觉怎么样",
                "手脚被绑住只能任由我玩弄了吧",
                "被道具刺激弱点的滋味好受吗",
                "锁链勒得紧不紧",
                "被完全拘束住的滋味很刺激吧",
                "挣扎也没用，好好享受道具的伺候",
                "特制的玩具感觉如何",
                "束缚下的快感更加强烈吧"
            ],
            "templates": [
                "{body_action}。{reaction}！{address}，{dialogue_core}",
                "{reaction}！{dialogue_core} {body_action}。",
                "{address}，{dialogue_core} {body_action}。"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_combat.restraint",
                "body_action": "character.actions_combat.restraint",
                "dialogue_core": "character.dialogues.combat_restraint"
            },
            "style_tags": ["combat_h", "restraint"]
        },
        {
            "reply_id": "combat_surrender_01",
            "character_id": "shared",
            "scene_tags": ["combat_h", "intimate"],
            "content_tag": "combat_surrender",
            "reference_queries": [
                "认输了吗，承认我的胜利吧",
                "乖乖投降吧，别再抵抗了",
                "已经彻底臣服于我了吧",
                "说出投降的话就好好疼爱你",
                "承认败北，完全属于我吧",
                "现在的你已经完全没有反抗能力了",
                "求饶认输我就轻一点",
                "宣布你的无条件投降吧"
            ],
            "templates": [
                "{reaction}。{address}，{dialogue_core} {body_action}。",
                "{body_action}。{dialogue_core} {address}，{followup}",
                "{dialogue_core} {body_action}。"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_combat.surrender",
                "body_action": "character.actions_combat.surrender",
                "dialogue_core": "character.dialogues.combat_surrender",
                "followup": "character.followups_intimate"
            },
            "style_tags": ["combat_h", "surrender"]
        },
        {
            "reply_id": "intimate_initiative_01",
            "character_id": "shared",
            "scene_tags": ["intimate", "home_chat"],
            "content_tag": "intimate_initiative",
            "reference_queries": [
                "你主动贴上来的样子真可爱",
                "想要我怎么做，自己告诉我",
                "原来你这么渴望我啊",
                "想要就主动一点嘛",
                "主动索吻的样子好迷人",
                "身体好烫，是想要了吗",
                "这么主动，平时可不多见呢",
                "告诉我你想要哪里",
                "这么饥渴主动地贴过来"
            ],
            "templates": [
                "{body_action}。{address}，{dialogue_core}",
                "{reaction}！{dialogue_core} {body_action}。",
                "{address}，{dialogue_core} {followup}"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_intimate",
                "body_action": "character.actions_intimate",
                "dialogue_core": "character.dialogues.intimate_initiative",
                "followup": "character.followups_intimate"
            },
            "style_tags": ["intimate", "desire"]
        },
        {
            "reply_id": "intimate_deep_kiss_01",
            "character_id": "shared",
            "scene_tags": ["intimate"],
            "content_tag": "intimate_deep_kiss",
            "reference_queries": [
                "把舌头伸出来，和我深吻",
                "张开嘴，让我尝尝你的味道",
                "吻得好深，口水都流出来了",
                "舌尖缠绕在一起的感觉好舒服",
                "来一个热烈窒息的深吻吧",
                "嘴唇好软，想要一直吻下去",
                "深吻到喘不过气来吧",
                "贪婪地交缠舌尖吧"
            ],
            "templates": [
                "{reaction}！{body_action}。{dialogue_core}",
                "{body_action}。{address}，{dialogue_core}",
                "{reaction}！{dialogue_core} {body_action}。"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_intimate",
                "body_action": "character.actions_intimate",
                "dialogue_core": "character.dialogues.intimate_deep_kiss"
            },
            "style_tags": ["intimate", "kiss"]
        },
        {
            "reply_id": "intimate_tease_reverse_01",
            "character_id": "shared",
            "scene_tags": ["intimate", "home_chat"],
            "content_tag": "intimate_tease_reverse",
            "reference_queries": [
                "居然反过来挑逗我，胆子变大了呢",
                "想支配我吗，看看谁先忍不住",
                "反客为主了吗，很有本事嘛",
                "故意吊我胃口是吧",
                "你是在挑战我的耐性吗",
                "挑衅我是要付出代价的哦",
                "被你弄得心痒痒的",
                "居然敢反过来掌握主动权"
            ],
            "templates": [
                "{reaction}！{address}，{dialogue_core} {body_action}。",
                "{body_action}。{dialogue_core} {followup}",
                "{address}，{dialogue_core} {body_action}。"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_home",
                "body_action": "character.actions_home",
                "dialogue_core": "character.dialogues.intimate_tease_reverse",
                "followup": "character.followups_home"
            },
            "style_tags": ["intimate", "teasing"]
        },
        {
            "reply_id": "intimate_submission_01",
            "character_id": "shared",
            "scene_tags": ["intimate"],
            "content_tag": "intimate_submission",
            "reference_queries": [
                "完全放松，把一切都交给我",
                "只要乖乖听话，我会好好爱你的",
                "毫无保留地展现在我面前吧",
                "把身体彻底奉献给我吧",
                "顺从我的支配，不要抵抗",
                "成为我专属的所有物吧",
                "乖乖顺从的样子最可爱了",
                "全心全意地服从我吧"
            ],
            "templates": [
                "{reaction}。{address}，{dialogue_core} {body_action}。",
                "{body_action}。{dialogue_core} {address}♡",
                "{address}，{dialogue_core} {body_action}。"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_intimate",
                "body_action": "character.actions_intimate",
                "dialogue_core": "character.dialogues.intimate_submission"
            },
            "style_tags": ["intimate", "submission"]
        },
        {
            "reply_id": "intimate_aftercare_sweet_01",
            "character_id": "shared",
            "scene_tags": ["intimate", "home_chat"],
            "content_tag": "intimate_aftercare_sweet",
            "reference_queries": [
                "辛苦了，我来帮你擦擦汗",
                "别着凉了，把被子盖好",
                "靠在胸口慢慢平复心跳吧",
                "要喝点温水润润嗓子吗",
                "累坏了吧，好好抱着你睡",
                "乖乖躺好，我来照顾你",
                "温存一会儿，今晚就这样陪着你",
                "静静抱在一起听彼此的心跳"
            ],
            "templates": [
                "{body_action}。{address}，{dialogue_core}",
                "{address}，{reaction}。{dialogue_core} {followup}",
                "{dialogue_core} {body_action}。"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_home",
                "body_action": "character.actions_home",
                "dialogue_core": "character.dialogues.intimate_aftercare_sweet",
                "followup": "character.followups_home"
            },
            "style_tags": ["intimate", "aftercare"]
        },
        {
            "reply_id": "home_patrol_work_01",
            "character_id": "shared",
            "scene_tags": ["home_chat"],
            "content_tag": "home_patrol_work",
            "reference_queries": [
                "今天的巡逻和公务怎么样了",
                "领地里的各项事务处理得还顺利吗",
                "辛苦你打理岛上的事务啦",
                "今天有什么需要处理的公事吗",
                "工作虽然重要也要注意休息哦",
                "巡视有什么新发现吗",
                "领地巡逻情况如何"
            ],
            "templates": [
                "{address}，{dialogue_core} {body_action}。",
                "{body_action}。{address}，{dialogue_core} {followup}",
                "{reaction}！{address}，{dialogue_core}"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_home",
                "body_action": "character.actions_home",
                "dialogue_core": "character.dialogues.home_patrol_work",
                "followup": "character.followups_home"
            },
            "style_tags": ["daily", "work"]
        },
        {
            "reply_id": "home_meal_share_01",
            "character_id": "shared",
            "scene_tags": ["home_chat"],
            "content_tag": "home_meal_share",
            "reference_queries": [
                "肚子饿了吗，一起吃点东西吧",
                "尝尝这个点心，味道很不错哦",
                "我准备了好吃的，来尝一口",
                "来，张嘴，我喂你吃",
                "今天想吃点什么好吃的",
                "喝杯热茶休息一下吧",
                "一起坐下来吃顿饭吧"
            ],
            "templates": [
                "{reaction}！{address}，{dialogue_core} {body_action}。",
                "{body_action}。{address}，{dialogue_core}",
                "{address}，{dialogue_core} {followup}"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_home",
                "body_action": "character.actions_home",
                "dialogue_core": "character.dialogues.home_meal_share",
                "followup": "character.followups_home"
            },
            "style_tags": ["daily", "meal"]
        },
        {
            "reply_id": "home_rest_nap_01",
            "character_id": "shared",
            "scene_tags": ["home_chat"],
            "content_tag": "home_rest_nap",
            "reference_queries": [
                "有点困了呢，一起睡个午觉吧",
                "靠在长椅上晒晒太阳小憩一会儿",
                "看你有点累了，闭上眼睛休息吧",
                "偷得浮生半日闲，陪我发会儿呆",
                "微风真舒服，好想打瞌睡",
                "午后的阳光好温暖，打个盹吧"
            ],
            "templates": [
                "{body_action}。{address}，{dialogue_core}",
                "{reaction}。{address}，{dialogue_core} {followup}",
                "{address}，{dialogue_core} {body_action}。"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_home",
                "body_action": "character.actions_home",
                "dialogue_core": "character.dialogues.home_rest_nap",
                "followup": "character.followups_home"
            },
            "style_tags": ["daily", "rest"]
        },
        {
            "reply_id": "home_night_whisper_01",
            "character_id": "shared",
            "scene_tags": ["home_chat"],
            "content_tag": "home_night_whisper",
            "reference_queries": [
                "夜深了呢，今晚月色真美",
                "夜晚的浮空岛好安静，只想和你在一起",
                "今晚能陪我说说话吗",
                "看着天上的星空，感觉好安心",
                "舍不得和你分开，再聊一会儿吧",
                "夜风好凉，静静依偎一会儿吧"
            ],
            "templates": [
                "{body_action}。{address}，{dialogue_core}",
                "{address}，{reaction}。{dialogue_core} {followup}",
                "{dialogue_core} {body_action}。"
            ],
            "wildcard_slots": {
                "address": "character.addresses",
                "reaction": "character.reactions_home",
                "body_action": "character.actions_home",
                "dialogue_core": "character.dialogues.home_night_whisper",
                "followup": "character.followups_home"
            },
            "style_tags": ["daily", "night"]
        }
    ]

    # Combine templates
    combined = list(existing_templates)
    for nt in new_templates:
        if nt["reply_id"] not in existing_ids:
            combined.append(nt)
            existing_ids.add(nt["reply_id"])

    # Strict check no ellipses
    tmpl_json = json.dumps(combined, ensure_ascii=False, indent=2)
    check_no_ellipses(tmpl_json, "templates.json")
    templates_path.write_text(tmpl_json, encoding="utf-8")
    print(f"Updated templates.json: Total templates = {len(combined)}")

if __name__ == "__main__":
    main()
