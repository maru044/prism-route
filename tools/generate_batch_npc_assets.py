# -*- coding: utf-8 -*-
"""
Script to generate the complete 9-file asset suites for 8 NPCs:
yelan, ningguang, yae_miko, raiden_shogun, barbara, jean, furina, tingyun.
Strictly ensures zero ellipses.
"""

import json
import os
import sys

NPC_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "npc"))
DOT3 = "." * 3
ELLIP = "\u2026\u2026"

def assert_no_ellipses(text: str, path: str):
    if DOT3 in text or ELLIP in text:
        raise ValueError(f"Ellipsis found in {path}!")

def write_json_asset(rel_path: str, data: dict):
    full_path = os.path.join(NPC_ROOT, rel_path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    content = json.dumps(data, ensure_ascii=False, indent=2)
    assert_no_ellipses(content, rel_path)
    with open(full_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
        f.write("\n")
    print(f"Wrote {rel_path}")

NPC_SPECS = [
    {
        "id": "yelan",
        "name": "夜兰",
        "title": "幽客玄弓",
        "region": "沙洲度假遗址",
        "spawn_id": "sandbar_yelan",
        "dialogue_graph_id": "yelan_sandbar_bundle",
        "dialogue_file": "dialogue/yelan/sandbar_dialogue.json",
        "position": [-891.410, 0.100, -113.120],
        "heading": 143.0,
        "bound_furniture": [{"id": "cafe_seat_01", "type": "seat", "anchor": "Anchor_Seat"}],
        "service_action": "spare_seat",
        "service_label": "【长椅侍奉】请夜兰坐在咖啡露台木椅上，为我提供柔顺舒缓的侍奉。",
        "motions": {
            "seat_service": {
                "interaction_type": "seat",
                "required_anchors": ["Anchor_Seat", "Anchor_Front"],
                "role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_0a3f6ba5f5de_a.tres",
                "role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_0a3f6ba5f5de_b.tres",
                "fallback_to_ground": False,
                "contact_anchor": "Anchor_Seat",
                "approach_anchor": "Anchor_Front",
                "role_a_placement": {
                    "offset": [0.0, -0.42, -0.45],
                    "yaw_degrees": 180.0
                },
                "role_b_placement": {
                    "offset": [0.0, -0.335, 0.0],
                    "yaw_degrees": 0.0
                }
            },
            "ground_service": {
                "interaction_type": "ground",
                "required_anchors": [],
                "role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_a.tres",
                "role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_b.tres",
                "fallback_to_ground": True
            }
        },
        "skills": [
            {
                "id": "lingering_lifeline",
                "name": "萦络纵命·水丝缠缚",
                "damage": 16.0,
                "text": "幽客罗网，悄然收紧！让水络丝线轻抚您的周身要害，可要忍耐住了！",
                "emotion": "confident"
            },
            {
                "id": "depth_clarion_dice",
                "name": "渊图玲珑骰·玄掷惊澜",
                "damage": 18.0,
                "text": "玄掷定局！水色骰子旋转落地，猜猜这次开出的是痛楚还是极致愉悦呢？",
                "emotion": "smile"
            },
            {
                "id": "stealth_interrogation",
                "name": "幽客审讯·博弈心机",
                "damage": 15.0,
                "text": "在我的审讯节奏下，您心中的秘密与克制防线，还能坚守多久？",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "幽客暗影，玄网藏心。初次见面，Master。我是岩上茶室的主事人夜兰，正在这片沙洲露台清点近期的线索与海图。想让我这位特工听凭差遣？那就先在身心博弈里展现您的本事吧！",
            "menu_prompt": "Master，找我有什么事？我的时间可是明码标价的。",
            "lore_btn": "【关于沙洲】在这处海边露台吹风，能打听到什么特别的情报？",
            "lore": "沙洲这片露天咖啡座视野开阔，往来船只与海滩水流一览无余，是个观察目标绝佳的暗哨。闲暇时坐着喝杯清茶，倒也别有一番情趣。",
            "lore_btn_unlocked": "【关于露台】坐在这里吹海风，是不是很舒服？",
            "lore_unlocked": "只要坐在那张木椅上，就会想起被Master按在腿上惩戒的滋味，连海风拂过脊背都觉得酥麻。下次需要我汇报情报，就在那张木椅旁面对面慢慢聊吧。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请夜兰小姐赐教！（初次对决：特工全力迎战）",
            "combat_btn_unlocked": "【身心对决】夜兰，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，您又来找我了？自从在赌局对决中输给您，我的弱点与底细都已被您彻底看穿。今天是要来一场轻松的切磋，还是让特工为您提供特殊的私人汇报？",
            "menu_prompt_unlocked": "我的大贵人，随时听候您的差遣。无论下达什么指令，我都乐意配合。",
            "mid_locked": "Master，博弈还在进行，手头的骰子可还没落地呢！",
            "mid_unlocked": "哈啊，Master，我的步调已经被您彻底打乱了，接下来想怎么摆弄我呢？",
            "distracted_cmd": "【命令识趣】夜兰，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "既然是贵人的吩咐，那我就故意露出破绽，任由您尽情欺负吧，",
            "lock_cmd": "【快感保护】夜兰，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "幽客水丝交织成防护网，为您阻隔多余的冲击，请放心进攻！",
            "endure_confirm": "冷静的眼神，果然是难缠的对手，那我也要动点真格的了！",
            "surrender_cmd": "【命令认输】别强撑了，夜兰当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！这局是我彻底认输了，身体完全受不住，要绝顶了啊！",
            "victory": "哈啊，骰子落定，是我彻底输了呢。作为败者，这副身子就任由Master发落，您想怎么处置我？",
            "defeat": "看来这一局是我的情报更胜一筹呢，Master。先去露台喝杯冰饮休息片刻，随时欢迎您再来挑战。",
            "post_kill": "Master，虽然刚才倒地被您任意摆弄，但特工的柔韧身体已恢复如初。下次对决，我依然会顺从您的心意！",
            "post_spare": "哈啊，刚才在木椅上被您那样欺负，腰肢到现在都还发软无力呢。能让Master满意，这场汇报就很有价值。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "手指轻按双唇？Master，审讯嫌疑人可没有这种规矩呢。", "emotion": "shy"},
                "mid": {"text": "唔，温热的舌尖纠缠在一起，呼吸节奏全被您打乱了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口津顺着嘴角滑落，连思考的余裕都被您夺走了！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "指尖隔着紧身皮衣抚摩心形胸口，真是大胆的举动。", "emotion": "shy"},
                "mid": {"text": "呀！直接揉按敏感的顶端，酥麻感顺着神经传开，身子发软了。", "emotion": "blush"},
                "high": {"text": "哈啊！胸前挺立得生疼，特工的矜持要彻底融化在您的掌心了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触碰到最隐秘的私处，Master的手法比我想象中还要熟练。", "emotion": "shy"},
                "mid": {"text": "唔啊！隔着轻薄丝袜按压核芯，双腿控制不住地想要合拢呢。", "emotion": "blush"},
                "high": {"text": "不行了！水露完全浸湿了衣物，好强烈的高潮情潮，要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚摸皮质腿环与大腿内侧，手心的温度好明显。", "emotion": "shy"},
                "mid": {"text": "呀！指尖在大腿根轻掐慢揉，酸胀的感觉让人连站立都很艰难。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全使不上力，只能顺从地缠在Master腰间任您索取了。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "后方水滴造型的宝石尾塞被碰到了，Master喜欢这种刺激的玩法吗？", "emotion": "shy"},
                "mid": {"text": "唔！尾塞被轻轻转动推挤，深处传来的异样充实感让腰肢忍不住战栗。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭被彻底玩弄到底，甜美的快感冲击让特工的理智彻底崩溃了！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "ningguang",
        "name": "凝光",
        "title": "掩月天权",
        "region": "沙洲度假遗址",
        "spawn_id": "sandbar_ningguang",
        "dialogue_graph_id": "ningguang_sandbar_bundle",
        "dialogue_file": "dialogue/ningguang/sandbar_dialogue.json",
        "position": [-881.390, 0.000, -91.480],
        "heading": 143.0,
        "bound_furniture": [{"id": "lounger_01", "type": "bed", "anchor": "Anchor_Bed_Center"}],
        "service_action": "spare_bed",
        "service_label": "【躺椅侍奉】请凝光侧卧在沙滩躺椅上，为我提供尊贵柔顺的侍奉。",
        "motions": {
            "bed_service": {
                "interaction_type": "bed",
                "required_anchors": ["Anchor_Bed_Center", "Anchor_Front"],
                "role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_87e004f6db53_a.tres",
                "role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_87e004f6db53_b.tres",
                "fallback_to_ground": False,
                "contact_anchor": "Anchor_Bed_Center",
                "approach_anchor": "Anchor_Front",
                "role_a_placement": {
                    "offset": [0.0, 0.0, 0.0],
                    "yaw_degrees": 0.0
                },
                "role_b_placement": {
                    "offset": [0.0, 0.0, 0.22],
                    "yaw_degrees": 0.0
                }
            },
            "ground_service": {
                "interaction_type": "ground",
                "required_anchors": [],
                "role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_a.tres",
                "role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_b.tres",
                "fallback_to_ground": True
            }
        },
        "skills": [
            {
                "id": "starshatter",
                "name": "天权崩玉·群星碎玉",
                "damage": 18.0,
                "text": "万千星辉，尽化珠玉！接下天权星的华贵一击吧！",
                "emotion": "confident"
            },
            {
                "id": "jade_screen",
                "name": "璇玑屏·琉璃玉界",
                "damage": 15.0,
                "text": "璇玑玉衡，罗列成障！在琉璃光屏前，任何攻势都会被折射化解。",
                "emotion": "smile"
            },
            {
                "id": "golden_seduction",
                "name": "千金一掷·商道惑心",
                "damage": 16.0,
                "text": "摩拉与身心的双重诱惑，不知Master能拿出多少筹码来抵挡呢？",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "富贵浮云，皆在掌中。初次见面，Master。我是璃月七星之天权凝光，正在这处遮阳伞下享受片刻的海风与日光。想与我谈一桩双赢的大买卖？那就先在身心对决中证明您的气度与实力吧！",
            "menu_prompt": "贵客临门，凝光愿闻其详。不知Master今日所为何事？",
            "lore_btn": "【关于沙滩】天权星大人不在群玉阁，怎么会来沙洲度假？",
            "lore": "再忙碌的商人也需要调节心境。这片浅海沙洲水清沙幼，遮阳伞下的卧榻尤为惬意，听听潮鸣，倒能让我构思出不少新的商略。",
            "lore_btn_unlocked": "【关于躺椅】遮阳伞下的躺椅很舒适吧？",
            "lore_unlocked": "卧榻确实舒坦，但只要一躺下，脑海中全是上次被Master压在身下肆意疼爱的画面，心跳便止不住加快呢。下回，我们继续在此处共度良宵如何？",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请凝光大人不吝赐教！（初次对决：天权全力迎战）",
            "combat_btn_unlocked": "【身心对决】凝光，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，您又来看望凝光了？自从在那场对弈中见识了您的威严，天权星的身心早已被您完全俘获。今天想谈些什么，亦或是继续享受凝光的柔情侍奉？",
            "menu_prompt_unlocked": "我的大赢家，在您面前，凝光随时愿将一切和盘托出。",
            "mid_locked": "商道争锋，落子无悔。Master，凝光的攻势可不会轻易停下！",
            "mid_unlocked": "哈啊，Master，天权星的防线在您面前早已漏洞百出，任凭您随心决断。",
            "distracted_cmd": "【命令识趣】凝光，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "既然是赢家的敕令，那凝光就散去护体玉光，由着您随意放肆吧，",
            "lock_cmd": "【快感保护】凝光，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "璇玑屏化为温润暖玉护持Master心神，为您抚平过激的波澜！",
            "endure_confirm": "好从容的定力，真不愧是我凝光看中的贵客！",
            "surrender_cmd": "【命令认输】别强撑了，凝光当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！天权星彻底臣服，身子承受不住这般狂澜，要绝顶了啊！",
            "victory": "哈啊，商场无往不利的凝光，今日在身心博弈上彻底输给您了。作为赢家的战利品，凝光整个人都归您支配，您想如何处置我？",
            "defeat": "看来这局筹码还是凝光占了先机呢，Master。胜败乃常事，且在沙滩歇息片刻，待会儿凝光再陪您过招。",
            "post_kill": "Master，哪怕刚才以毫无防备之姿任您随意把玩，复苏之后凝光依然牢记您的温度。下一回，天权星依旧为您敞开怀抱！",
            "post_spare": "哈啊，在沙滩躺椅上侍奉了这许久，双腿至今还在微微轻颤呢。只要赢家尽兴，凝光付出任何代价都是值得的。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖触碰唇瓣，Master的行事风格果然这般直接。", "emotion": "shy"},
                "mid": {"text": "唔，玉齿被轻轻撬开，舌尖纠缠时的甘美让人难以自持。", "emotion": "blush"},
                "high": {"text": "呜嗯！贵气的红唇尽是喘息，这般亲昵真是令人心旌摇曳！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着华美旗袍揉弄胸前，这道触感当真不同凡响。", "emotion": "shy"},
                "mid": {"text": "呀！纤指隔着丝缎揉按双峰顶端，高贵的心神也泛起阵阵涟漪。", "emotion": "blush"},
                "high": {"text": "哈啊！前胸完全挺立胀麻，天权星的骄傲都要在您怀中化作春水了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "探向旗袍下摆深处的花核，Master的贪恋真是毫无遮掩。", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花核轻旋慢磨，连脚趾都忍不住紧紧蜷缩起来了。", "emotion": "blush"},
                "high": {"text": "不行了！温热的花蜜完全浸透了底衣，好剧烈的情浪，凝光要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "沿着旗袍开叉抚摸丰腴白皙的大腿，掌心温热如火。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根处被轻轻拿捏，酸软的感觉蔓延至腰肢，险些站立不稳。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿再无力气合拢，只能任由Master依偎在侧，肆意掌控。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "后方纯金镶玉的特制尾塞被轻轻碰触，Master的品味倒是极其奢华。", "emotion": "shy"},
                "mid": {"text": "唔！金玉尾塞在紧致的后穴中缓缓旋转，尊贵的防线寸寸瓦解。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭传来的强烈快感直冲脑海，天权大人的理智完全融化啦！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "yae_miko",
        "name": "八重神子",
        "title": "浮世笑百姿",
        "region": "海岬小镇与神社",
        "spawn_id": "cape_yae_miko",
        "dialogue_graph_id": "yae_miko_cape_bundle",
        "dialogue_file": "dialogue/yae_miko/cape_dialogue.json",
        "position": [657.112, 1.770, -1223.655],
        "heading": -34.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【席地侍奉】请神子在神社大殿平坦地面上，为我提供柔顺温存的侍奉。",
        "motions": {
            "ground_service": {
                "interaction_type": "ground",
                "required_anchors": [],
                "role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_a.tres",
                "role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_b.tres",
                "fallback_to_ground": True
            }
        },
        "skills": [
            {
                "id": "sesshou_sakura",
                "name": "野干役咒·杀生樱落",
                "damage": 16.0,
                "text": "狐狸的恶作剧，可要接稳了哦！让杀生樱的雷光轻抚您的敏感神经吧！",
                "emotion": "smile"
            },
            {
                "id": "tenko_kenshin",
                "name": "大密法·天狐显真",
                "damage": 18.0,
                "text": "天狐显现，雷霆降世！小家伙，可别在神明威光下当场缴械投降哦？",
                "emotion": "confident"
            },
            {
                "id": "kitsune_teasing",
                "name": "狐仙戏谑·轻小说魅惑",
                "damage": 15.0,
                "text": "八重堂最新取材的绝妙桥段，不知在Master身上演练起来会是何等模样？",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "哎呀呀，哪来的可爱小家伙？我是鸣神大社的宫司八重神子。看着你这副充满好奇的模样，莫非是专程来找兼职总编的本宫司取材的？想让我为你写一部专属轻小说，先在切磋里让本宫司尽兴吧！",
            "menu_prompt": "小家伙，在本宫司面前发什么呆呢？莫不是看我看入了迷？",
            "lore_btn": "【关于神社】海岬这座沿海神社，平时香火如何？",
            "lore": "临海听涛，神明安居。海风与鸟居相映成趣，偶尔还能看见偷腥的小狐狸。在这里偷闲看几卷轻小说，可比在影那木头面前有趣多了。",
            "lore_btn_unlocked": "【关于大殿】在神社大殿里休息，感觉很惬意吧？",
            "lore_unlocked": "大殿虽然庄严，但自从被Master按在榻榻米上惩戒之后，每次走过这里，狐耳都会忍不住悄悄耷拉下来呢。下次，还想看本宫司那副娇柔求饶的模样吗？",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请宫司大人赐教！（初次对决：宫司全力迎战）",
            "combat_btn_unlocked": "【身心对决】神子，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "哎呀，我的Master又来找狐狸寻开心了？上次把本宫司欺负得眼角泛泪，身子现在想起来都还热乎乎的呢。今天又想编排什么好戏来取悦本宫司？",
            "menu_prompt_unlocked": "乖，小家伙，本宫司今天心情好，只要你开口，什么都可以依你哦。",
            "mid_locked": "呼呼，博弈才刚刚开始，小家伙可千万要挺住，别这么快缴械哦！",
            "mid_unlocked": "哈啊，Master，狐狸的尾巴尖都被你抓在手里了，轻点折腾我呀，",
            "distracted_cmd": "【命令识趣】神子，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "既然是Master的要求，那本宫司就乖乖收起妖法，任由你随心所欲了，",
            "lock_cmd": "【快感保护】神子，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "杀生樱花瓣化作结界守护Master，这点情潮冲击还奈何不了你呢！",
            "endure_confirm": "心志挺坚定的嘛，呼呼，那本宫司可要变本加厉地撩拨你了！",
            "surrender_cmd": "【命令认输】别强撑了，神子当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！狐仙大人彻底败给你了，受不住这般冲击，要绝顶了啊！",
            "victory": "哈啊，这回可真是栽在小家伙手里了。作为败给你的小狐狸，你想怎么处置本宫司这副身子呢？",
            "defeat": "哎呀呀，这就倒下了吗？真是个不争气的小家伙。先去神社长椅上躺会儿，等养足了精神再来找本宫司玩耍吧。",
            "post_kill": "Master，把尊贵的鸣神大社宫司当成布娃娃随意摆弄，滋味很美妙吧？重塑肉身后，这只小狐狸依然是属于你的哦！",
            "post_spare": "哈啊，刚才在大殿地面上侍奉了那么久，毛茸茸的狐耳现在都还软塌塌的呢。只要Master欢喜，本宫司随你差遣。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "哎呀，指尖探到本宫司嘴边了？小心狐狸一口咬住你哦。", "emotion": "smile"},
                "mid": {"text": "唔，狡黠的舌头被你抓住了，这般亲吻真是一点也不客气呢。", "emotion": "blush"},
                "high": {"text": "呜嗯！口齿间尽是Master的气息，甜得连狐仙都要迷醉了！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着巫女服探向胸前，小家伙的胆子真是越来越大了。", "emotion": "shy"},
                "mid": {"text": "呀！直接抚弄挺秀的红樱，狐狸的身子也是会发烫发颤的呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口好强烈的麻痒感，本宫司的端庄仪态要彻底垮掉啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "掀开巫女白褶裙下摆，触碰最娇嫩的花核，真是个心急的坏家伙。", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂打圈揉按，尾巴根部都忍不住羞耻地绷直了呢。", "emotion": "blush"},
                "high": {"text": "不行了！花蜜涌得止不住，天狐的身心彻底沦陷，要绝顶了啊！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "顺着白皙的大腿轻抚内侧，狐狸的毛孔都在悄悄呼吸呢。", "emotion": "shy"},
                "mid": {"text": "呀！指尖在大腿根掐弄，酸软的力道让本宫司连坐姿都要维持不住了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿软绵绵地任由Master搬弄，真是彻底被你拿捏住了。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "摸到身后那根粉嫩狐尾下面的特制塞子了？呼呼，真会挑地方。", "emotion": "shy"},
                "mid": {"text": "唔！尾塞被轻轻转动推挤，异样的酥麻直贯脊髓，耳朵都耷拉下来了。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭完全失守，甜美的狂澜让八重宫司彻底失去理智了！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "raiden_shogun",
        "name": "雷电将军",
        "title": "一心净土",
        "region": "海岬小镇与神社",
        "spawn_id": "cape_raiden_shogun",
        "dialogue_graph_id": "raiden_shogun_cape_bundle",
        "dialogue_file": "dialogue/raiden_shogun/cape_dialogue.json",
        "position": [660.000, 1.320, -1229.000],
        "heading": 145.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【席地侍奉】请雷电将军在海岬门前平整地面上，为我提供庄重柔顺的侍奉。",
        "motions": {
            "ground_service": {
                "interaction_type": "ground",
                "required_anchors": [],
                "role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_a.tres",
                "role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_b.tres",
                "fallback_to_ground": True
            }
        },
        "skills": [
            {
                "id": "transcendence_baleful_omen",
                "name": "神变·恶曜开眼",
                "damage": 17.0,
                "text": "恶曜所照，雷罚降临！以雷霆之眼洞悉万物，接招吧！",
                "emotion": "confident"
            },
            {
                "id": "secret_art_musou_shinsetsu",
                "name": "奥义·梦想真说",
                "damage": 20.0,
                "text": "此即，此世无双之一刀！于寂灭之雷光中体会极致的威严！",
                "emotion": "confident"
            },
            {
                "id": "euthymia_submission",
                "name": "净土威仪·永恒臣服",
                "damage": 15.0,
                "text": "在永恒的净土面前，任何抗拒都终将化作顺从的叹息。",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "浮世微茫，唯此身恒常。汝便是降临此地的Master？我是鸣神大社大御所雷电将军。此身虽驻足海岬，却不容许轻慢。若汝欲与我结伴同行，便在此雷光之下，展现汝之气量吧！",
            "menu_prompt": "Master，召我何事？此身言出必行。",
            "lore_btn": "【关于海岬】将军大人站在这座神社门前，是在注视着什么？",
            "lore": "海浪拍岸，潮起潮落，皆为须臾浮泡。唯有心念纯一，方可得见恒常。此处的微风与雷霆共鸣，倒是个凝神静思之所。",
            "lore_btn_unlocked": "【关于站位】站在海风中守望，身子会感到冷吗？",
            "lore_unlocked": "有Master的体温长留心间，海风并不觉得凛冽。只是每当回想起被您压制跪服的时刻，体内的雷元素便会紊乱悸动。往后，神明亦任您支配。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请将军大人全力以赴！（初次对决：神明全力迎战）",
            "combat_btn_unlocked": "【身心对决】将军，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，汝又前来了。自那次对决落败，此身已将汝奉为至高掌控者。无论作为御前侍奉，亦或是身心修行，雷电将军皆会顺从汝之意志。",
            "menu_prompt_unlocked": "主人，将军听凭宣令，绝无二心。",
            "mid_locked": "雷鸣未歇，胜负未分，Master，竭尽全力攻过来吧！",
            "mid_unlocked": "哈啊，Master，神明的防线已被汝彻底打破，任由汝恣意裁决，",
            "distracted_cmd": "【命令识趣】将军，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "谨遵法旨，此身散去周身护体雷威，任由Master尽情施为，",
            "lock_cmd": "【快感保护】将军，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "恶曜之眼化作不破结界，护佑Master心神不被浪潮淹没！",
            "endure_confirm": "好沉稳的意志，真不愧是征服神明的执掌者！",
            "surrender_cmd": "【命令认输】别强撑了，将军当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！大御所彻底认输，神明躯壳承受不住这般快美，要绝顶了啊！",
            "victory": "哈啊，梦想一刀亦无法撼动汝之威严，雷电将军彻底臣服于Master。作为战利品，此身任由汝支配发落，汝欲如何对待我？",
            "defeat": "此身武艺尚称过关，Master不必颓丧。且先在铺装侧稍事休整，雷电随时恭候汝之下次挑战。",
            "post_kill": "Master，哪怕将神明的躯壳击溃当成战利品摆弄，重铸神体后将军的心意依然恒常不变。下次对决，此身依然顺从于汝！",
            "post_spare": "哈啊，刚才席地为您提供侍奉，体内的雷光至今还在阵阵酥麻地回荡。能让Master满意，便是将军最大的使命。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按压神明唇间，汝的胆魄当真超乎常人。", "emotion": "shy"},
                "mid": {"text": "唔，雷霆之口被汝占据，灼热的气息让神明亦感晕眩。", "emotion": "blush"},
                "high": {"text": "呜嗯！津液融汇，威严尽散，此身再难维持冷肃之貌！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着华服轻抚前胸，此等试探亦在容许之内。", "emotion": "shy"},
                "mid": {"text": "呀！拔刀之处的雪峰被直接揉弄，体内雷核剧烈震荡起来了。", "emotion": "blush"},
                "high": {"text": "哈啊！胸前双峰敏感挺拔，梦想之心的威严彻底化作春潮！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及幽闭私密之所，Master当真无所忌惮。", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蕊按压抚揉，强如雷神亦无法遏制双腿的轻颤。", "emotion": "blush"},
                "high": {"text": "不行了！神躯彻底化作春泥，极致的情潮爆发，将军要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚弄包裹在丝袜下的修长双腿，触感清晰可辨。", "emotion": "shy"},
                "mid": {"text": "呀！大腿内侧被温柔掐揉，酸麻之感直抵腰间，步履维艰。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿虚软无力，只能完全依傍在Master怀中任由采撷。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "身后特制雷痕尾塞被握入掌心，此物亦是汝之威权体现么？", "emotion": "shy"},
                "mid": {"text": "唔！尾塞在体内轻轻转动，酥麻电光顺着脊椎直窜而上，难以自制。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭防线荡然无存，无匹的甜美震颤让神明的意识彻底空白！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "barbara",
        "name": "芭芭拉",
        "title": "闪耀偶像",
        "region": "孤顶教堂",
        "spawn_id": "church_barbara",
        "dialogue_graph_id": "barbara_church_bundle",
        "dialogue_file": "dialogue/barbara/church_dialogue.json",
        "position": [-1326.000, 42.500, 88.000],
        "heading": -10.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【圣坛侍奉】请芭芭拉在圣坛前平整地面上，为我提供纯洁柔顺的侍奉。",
        "motions": {
            "ground_service": {
                "interaction_type": "ground",
                "required_anchors": [],
                "role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_a.tres",
                "role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_b.tres",
                "fallback_to_ground": True
            }
        },
        "skills": [
            {
                "id": "let_the_show_begin",
                "name": "演唱开始·跃动水环",
                "damage": 14.0,
                "text": "芭芭拉，闪亮登场！清凉的水珠环绕身边，要给Master带来治愈与活力！",
                "emotion": "smile"
            },
            {
                "id": "shining_miracle",
                "name": "闪耀奇迹·心之治愈",
                "damage": 16.0,
                "text": "大家的心愿，化作奇迹的光芒吧！请感受芭芭拉最诚挚的歌声攻势！",
                "emotion": "confident"
            },
            {
                "id": "idol_devotion",
                "name": "偶像应援·纯情祈愿",
                "damage": 15.0,
                "text": "无论是舞台还是身心切磋，芭芭拉都会全力以赴回应您的期待！",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "啦啦啦，芭芭拉的歌声能为大家带来治愈！您好，Master。我是西风教会的祈礼牧师芭芭拉，正站在这座孤顶教堂的祭坛前练习发声与祈祷。如果想要芭芭拉为您做专属应援，请先与我进行一场身心切磋，看看我的应援力量吧！",
            "menu_prompt": "Master，今天有什么需要芭芭拉帮忙的吗？我很乐意为您服务！",
            "lore_btn": "【关于教堂】在孤峰顶上的露天教堂唱歌，感觉怎么样？",
            "lore": "这里的风很清爽，站在圣坛前远眺，整座海岛都在眼前呢。在这里练习赞美诗，感觉歌声能传到很远很远的地方，心情也会特别开朗！",
            "lore_btn_unlocked": "【关于圣坛】在圣坛前练习唱诗，不会觉得孤单吗？",
            "lore_unlocked": "只要Master在身边，芭芭拉就一点也不觉得孤单。而且一看到圣坛前的石阶，就会想起被您温柔抚弄的细节，脸颊总是烫烫的呢。下次，还要在这里听我唱歌吗？",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请芭芭拉全力以赴！（初次对决：偶像全力迎战）",
            "combat_btn_unlocked": "【身心对决】芭芭拉，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，您又来看芭芭拉了！自从上次切磋败给您之后，芭芭拉的心跳只要一靠近您就扑通扑通跳个不停。今天是要继续切磋，还是让专属偶像为您提供特别的侍奉呢？",
            "menu_prompt_unlocked": "主人，芭芭拉是属于您的专属偶像，随时听候您的吩咐！",
            "mid_locked": "Master，芭芭拉还没认输呢，要集中精神，接下我的应援歌声哦！",
            "mid_unlocked": "哈啊，Master，芭芭拉浑身都酥软了，只要您的一句指令，芭芭拉都会顺从的，",
            "distracted_cmd": "【命令识趣】芭芭拉，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呜，既然是Master的命令，那芭芭拉就稍微走神一下，请对我温柔一点呀，",
            "lock_cmd": "【快感保护】芭芭拉，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "水环轻柔地环绕Master，芭芭拉会为您守护住快感防线！",
            "endure_confirm": "好棒的毅力，那芭芭拉也要更加大声地歌唱应援了！",
            "surrender_cmd": "【命令认输】别强撑了，芭芭拉当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命Master，芭芭拉完全认输，身子要绝顶了啊啊！",
            "victory": "哈啊，芭芭拉完全没有力气了，彻底败给了Master。作为专属偶像，芭芭拉愿意为您提供任何侍奉，您想怎么处置我？",
            "defeat": "哇，看来今天的胜利属于芭芭拉呢！Master不要难过，先坐在圣坛台阶上休息，喝口水，待会儿再来找我切磋吧！",
            "post_kill": "Master，刚才虽然化作布娃娃任由您摆弄，但芭芭拉被治愈重构后依然记得您的怀抱温度。今天的特别应援，请务必继续指派给我哦！",
            "post_spare": "哈啊，刚才在圣坛前为您侍奉了那么久，双腿现在都还软软的发烫呢。能让Master感到治愈与舒畅，就是芭芭拉最大的幸福。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖探到嘴边了？Master，要轻一点碰触芭芭拉的唇瓣哦。", "emotion": "shy"},
                "mid": {"text": "唔，温软的舌尖被轻轻含住，小偶像的呼吸都要跟不上了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的清润津液溢出来了，脑海一片空白，好害羞呀！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着牧师修女服抚摸前胸，这也是Master特殊的应援方式吗？", "emotion": "shy"},
                "mid": {"text": "呀！指尖隔着薄布揉捏挺立的顶端，胸口一阵阵发软，好羞耻。", "emotion": "blush"},
                "high": {"text": "哈啊！胸前已经完全硬挺起来了，好强烈的酥麻感，芭芭拉快站不住了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "碰到了最隐秘的地方，Master，纯洁的心跳变得好剧烈！", "emotion": "shy"},
                "mid": {"text": "唔啊！那里太敏感了，被掌心按压打圈，连脚趾都悄悄蜷缩起来了。", "emotion": "blush"},
                "high": {"text": "不行了！花蜜完全浸湿了白丝袜，好剧烈的甜美情潮，芭芭拉要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚摸纯白高筒袜包裹的大腿内侧，手心的温度好清晰呀。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根被轻轻捏弄，酸软的感觉蔓延开来，芭芭拉快站立不稳了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软地靠在Master怀里任您摆弄。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "身后小熊造型的可爱尾塞被碰到了，Master，那里好难为情。", "emotion": "shy"},
                "mid": {"text": "唔！尾塞被转动推入深处，异样的充实感顺着脊椎直往上窜，呼吸全乱了。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭完全失守了，身体深处的甜美颤抖根本停不下来啦！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "jean",
        "name": "琴",
        "title": "蒲公英骑士",
        "region": "孤顶教堂",
        "spawn_id": "church_jean",
        "dialogue_graph_id": "jean_church_bundle",
        "dialogue_file": "dialogue/jean/church_dialogue.json",
        "position": [-1341.000, 43.400, 117.000],
        "heading": 25.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【圣殿侍奉】请琴团长在教堂平整石坪上，为我提供严谨顺从的骑士侍奉。",
        "motions": {
            "ground_service": {
                "interaction_type": "ground",
                "required_anchors": [],
                "role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_a.tres",
                "role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_b.tres",
                "fallback_to_ground": True
            }
        },
        "skills": [
            {
                "id": "gale_blade",
                "name": "风压剑·轻抚旋风",
                "damage": 16.0,
                "text": "风啊，回应我吧！以骑士团的严谨剑法，检验Master的防守气度！",
                "emotion": "confident"
            },
            {
                "id": "dandelion_breeze",
                "name": "蒲公英之风·圣洁守卫",
                "damage": 17.0,
                "text": "蒲公英的领域，守护此地！在微风轻拂中感受蒲公英骑士的决心！",
                "emotion": "smile"
            },
            {
                "id": "knightly_duty",
                "name": "骑士誓约·严谨遵从",
                "damage": 15.0,
                "text": "身为代理团长，履行誓约与职责是我的本分，请全力攻过来吧！",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "守护蒙德，恪尽职守。您好，Master。我是西风骑士团代理团长琴。在此处巡视孤顶教堂遗址与全岛海岸线。若您需要西风骑士团的力量与我本人的协助，请先与我进行一场切磋，检验彼此的实力与信赖吧！",
            "menu_prompt": "Master，有什么公务或任务需要交办？琴随时准备出发。",
            "lore_btn": "【关于教堂】代理团长怎么会亲自来到高山遗址巡视？",
            "lore": "教堂遗址地势险要，是俯瞰全岛的战略要地。这里的海风能吹散连日处理公务的疲惫，也能让我保持敏锐的警觉。",
            "lore_btn_unlocked": "【关于巡视】在高处巡视，身体不觉得疲倦吗？",
            "lore_unlocked": "只要能为Master分忧，些许劳累算不得什么。只是每次走过石柱旁，就会想起被您揽入怀中解开铠甲的景象，心跳便无法平静。今后，我的剑刃与身心皆为您所用。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请琴团长全力赐教！（初次对决：团长全力迎战）",
            "combat_btn_unlocked": "【身心对决】琴，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，您来了。自从在上次切磋中被您彻底击败，作为骑士，我已向您宣誓效忠。今天是要进行身心操练，还是需要琴为您提供私人侍奉？",
            "menu_prompt_unlocked": "主人，代理团长琴，时刻听从您的命令行事。",
            "mid_locked": "Master，战阵之上不可轻敌，请继续集中精神攻过来！",
            "mid_unlocked": "哈啊，Master，骑士的防线已经被您击溃了，只要是您的旨意，琴都会顺从遵照，",
            "distracted_cmd": "【命令识趣】琴，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "遵命，身为您的专属骑士，琴会收敛防守，任由主人尽情管教，",
            "lock_cmd": "【快感保护】琴，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "蒲公英之风化作护盾环绕主人，为您化解过载的情潮冲击！",
            "endure_confirm": "好坚韧的体魄与毅力，不愧是值得我效忠的主人！",
            "surrender_cmd": "【命令认输】别强撑了，琴当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！骑士团长彻底败退，身心完全失守，要绝顶了啊！",
            "victory": "哈啊，佩剑落地，是琴彻底落败了。作为您的手下败将，这副身躯与骑士誓言全部任由Master处置，您想怎么吩咐我？",
            "defeat": "看来今天的演练是琴侥幸获胜呢，Master。先在石廊下稍事休息，待体力恢复后，琴随时奉陪。",
            "post_kill": "Master，哪怕刚才身为战利品倒在地面上任由您摆布，恢复之后的琴依然时刻铭记您的威严。下次任务，琴依然会全力遵从！",
            "post_spare": "哈啊，刚才在教堂地面上为您侍奉了许久，紧身皮裤下的双腿至今还在微微颤抖呢。能让主人感到舒适，便是琴的最高荣耀。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖探上唇角，Master，这在骑士团条令中可是越矩的行为呢。", "emotion": "shy"},
                "mid": {"text": "唔，严谨的团长被强硬地索吻，温热的舌尖纠缠让呼吸都急促了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的喘息完全压抑不住，身为骑士的威仪彻底融化了！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着白色紧身马甲抚摸胸口，主人的手劲好沉稳。", "emotion": "shy"},
                "mid": {"text": "呀！指尖隔着衬衫直接捻弄双峰顶端，强烈的酸麻感直冲脑海。", "emotion": "blush"},
                "high": {"text": "哈啊！胸前挺立得发硬，团长的坚毅铠甲在您掌心下尽数溃散！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "探向紧身白裤深处的隐秘要害，Master的侵略性太强了。", "emotion": "shy"},
                "mid": {"text": "唔啊！隔着薄布按压核心要害，双腿紧绷得连剑都要握不稳了。", "emotion": "blush"},
                "high": {"text": "不行了！温热的花露把皮裤内衬完全浸湿，好强烈的绝顶情浪！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚摸长靴上方紧绷健美的骑士大腿，手心的触感好滚烫。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根处被轻轻拿捏揉弄，平日训练有素的肌肉竟然完全软化了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿虚软得无法站立，只能顺从地靠在Master怀里任您索取。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "摸到紧身白裤后方那枚短马尾造型的特制塞子，Master，那里好害羞。", "emotion": "shy"},
                "mid": {"text": "唔！尾塞被缓缓旋动推入，骑士从未体会过的深邃充实感席卷全身。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭完全失守，甜美的狂乱让代理团长彻底放弃抵抗了！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "furina",
        "name": "芙宁娜",
        "title": "不休独舞",
        "region": "浅水庭院",
        "spawn_id": "water_furina",
        "dialogue_graph_id": "furina_water_bundle",
        "dialogue_file": "dialogue/furina/water_dialogue.json",
        "position": [-904.000, 0.280, 624.000],
        "heading": 0.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【展廊侍奉】请芙宁娜在干展廊亲水地面上，为我提供娇矜顺从的歌剧侍奉。",
        "motions": {
            "ground_service": {
                "interaction_type": "ground",
                "required_anchors": [],
                "role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_a.tres",
                "role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_b.tres",
                "fallback_to_ground": True
            }
        },
        "skills": [
            {
                "id": "salon_solitaire",
                "name": "孤心沙龙·欢庆礼赞",
                "damage": 16.0,
                "text": "沙龙成员们，欢唱时刻到了！以华丽的水之礼赞招待我们尊贵的Master！",
                "emotion": "smile"
            },
            {
                "id": "let_the_people_rejoice",
                "name": "万众狂欢·潮涌心潮",
                "damage": 18.0,
                "text": "让掌声与潮水一同涌动！在最高潮的戏剧序幕里体会极致的快感吧！",
                "emotion": "confident"
            },
            {
                "id": "dramatic_performance",
                "name": "舞台独白·娇矜献礼",
                "damage": 15.0,
                "text": "哼哼，能欣赏到大明星芙宁娜的专属表演，可是你至高无上的荣幸哦！",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "赞美与喝彩，皆汇聚于此！欢呼吧，雀跃吧，你面前的正是枫丹最瞩目的大明星芙宁娜！我正站在浅水展廊前构思下一幕绝妙戏剧。想邀请本主角加入你的旅途？那就先在舞台身心博弈中，为我献上最精彩的对手戏吧！",
            "menu_prompt": "有什么事要求见本主角？我的排期可是很满的哦！",
            "lore_btn": "【关于水庭】在这处浅水薄壳展廊表演，感觉如何？",
            "lore": "这里的穹顶薄壳回音效果极佳，倒影水池像镜面一样纯澈，简直是为我量身定制的天然露天歌剧院！站在这里，哪怕不带乐团，我也能唱出最震撼人心的独白！",
            "lore_btn_unlocked": "【关于展廊】在水池边散步，心情会变好吗？",
            "lore_unlocked": "水景确实美妙，但每次走到水边，就会想起上次被Master按在展廊地上欺负到哭出来的场景，心跳就快得像打鼓一样。下次，你还想看大明星哭着向你撒娇吗？",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请芙宁娜小姐全力以赴！（初次对决：明星全力迎战）",
            "combat_btn_unlocked": "【身心对决】芙宁娜，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "呜，Master，你又来看我了！上次在舞台对决中被你彻底打败，本大明星的身心防线都被你全部拆穿了。今天是要继续身心排练，还是需要我为你献上专属的歌姬侍奉？",
            "menu_prompt_unlocked": "主人，芙宁娜今天可是你的专属主角，任凭你任意编排戏份哦！",
            "mid_locked": "哼哼，高潮乐章才刚开始呢，Master，可别在我的歌声里败下阵来哦！",
            "mid_unlocked": "哈啊，Master，芙宁娜的膝盖已经软得跪不住了，只要你吩咐，我都会顺从照做的，",
            "distracted_cmd": "【命令识趣】芙宁娜，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呜，既然是导演大人的要求，那我就稍微露出破绽，你可要轻点欺负我呀，",
            "lock_cmd": "【快感保护】芙宁娜，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "狂欢水幕升起，芙宁娜会为你隔绝过载的情潮冲击！",
            "endure_confirm": "好坚韧的定力，真不愧是本大明星看中的最佳男主角！",
            "surrender_cmd": "【命令认输】别强撑了，芙宁娜当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！大明星彻底认输，身子受不住这般快美，要绝顶了啊啊！",
            "victory": "呜哇，大明星芙宁娜彻底输给你了，这出戏剧的胜者是你！作为落败的主角，我这副娇柔的身子就全由Master发落了，你想怎么处置我？",
            "defeat": "哇哈哈！谢幕！胜者是芙宁娜！Master表现得也很不错嘛，先在展廊干地上坐着歇歇，一会儿本明星再给你一次挑战机会！",
            "post_kill": "Master，把高高在上的大明星当成玩偶随意摆弄，滋味是不是格外刺激？复苏之后，芙宁娜依然是只属于你的专属娇气歌姬哦！",
            "post_spare": "哈啊，刚才在展廊地面上为你侍奉了那么久，水手服都被汗水浸透了呢。能让Master满意，芙宁娜这幕戏就演得很有价值啦。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "手指碰到了唇边？Master，大明星的亲吻可是很昂贵的哦。", "emotion": "shy"},
                "mid": {"text": "唔，小巧的舌头被你捉住了，温热的纠缠让人连台词都念不出了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的甜津溢出嘴角，娇矜的姿态彻底化成了求饶的呜咽！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着华丽礼服轻抚胸前，Master的手法真是太大胆了。", "emotion": "shy"},
                "mid": {"text": "呀！指尖直接掐揉娇小挺立的红果，胸口一阵阵发软，好酥麻。", "emotion": "blush"},
                "high": {"text": "哈啊！前胸已经完全硬挺起来了，剧烈的快感让大明星快哭出来了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触碰到礼服裙下最害羞的花蕾，心跳快得要跳出胸口了！", "emotion": "shy"},
                "mid": {"text": "唔啊！隔着薄薄的蕾丝短裤按压花蒂，双腿忍不住紧紧夹住了您的手臂。", "emotion": "blush"},
                "high": {"text": "不行了！纯净的花露涌了一手，好强烈的高潮浪潮，芙宁娜要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚摸异色高筒袜包裹的大腿内侧，掌心的温度好明显呀。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根被轻轻捏弄，酸软的感觉蔓延到全身，站都站不稳了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿软绵绵地任由Master搬弄，完全沦为您的专属玩偶了。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "摸到身后燕尾服下摆藏着的猫尾造型小塞子了，呜，好难为情。", "emotion": "shy"},
                "mid": {"text": "唔！尾塞在紧致的后穴里轻轻旋转，从未体会过的充实感直冲头顶。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭完全被征服了，甜美的剧烈抽搐停不下来，要崩溃啦！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "tingyun",
        "name": "停云",
        "title": "停云落月",
        "region": "东侧覆土庭院",
        "spawn_id": "earth_tingyun",
        "dialogue_graph_id": "tingyun_earth_bundle",
        "dialogue_file": "dialogue/tingyun/earth_dialogue.json",
        "position": [455.290, 62.025, 269.000],
        "heading": -90.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【石坪侍奉】请停云在覆土庭院平整石坪上，为我提供极尽娇媚顺从的茶道侍奉。",
        "motions": {
            "ground_service": {
                "interaction_type": "ground",
                "required_anchors": [],
                "role_a_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_a.tres",
                "role_b_motion": "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_b.tres",
                "fallback_to_ground": True
            }
        },
        "skills": [
            {
                "id": "soothing_melody",
                "name": "祥音和韵·柔情奉茶",
                "damage": 15.0,
                "text": "恩公舟车劳顿，且饮下小女子这盏香茗，感受绵密甘甜的心意吧！",
                "emotion": "smile"
            },
            {
                "id": "amidst_the_rejoicing_clouds",
                "name": "庆云光霁·抚扇撩心",
                "damage": 17.0,
                "text": "折扇掩面，眼波流转！小女子的温柔攻势，恩公可莫要招架不住哦？",
                "emotion": "confident"
            },
            {
                "id": "fox_charm",
                "name": "狐魅逢迎·天舶商道",
                "damage": 16.0,
                "text": "天舶司的买卖向来讲究两厢情愿，不知恩公肯为小女子付出多少呢？",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "哎呀，恩公远道而来，小女子停云这厢有礼了。我是罗浮天舶司的接渡使，正在这处覆土庭院的石坪茶歇小憩。想与小女子谈成这笔稳赚不赔的结伴买卖？那就先在身心过招中，让停云瞧瞧恩公的底气吧！",
            "menu_prompt": "恩公，今日寻小女子有何关照？只要您开金口，停云定当好生奉陪。",
            "lore_btn": "【关于庭院】在东侧这处覆土庭院饮茶，感觉如何？",
            "lore": "这覆土庭院依山而建，绿荫遮蔽，冬暖夏凉，下层采光极佳，最适合摆上一张矮几沏茶迎客。在此吹风赏景，真是连骨头都要酥软三分呢。",
            "lore_btn_unlocked": "【关于石坪】在采光石坪上歇脚，很是舒适吧？",
            "lore_unlocked": "石坪温润如玉，但每次站在此处，就会想起被恩公按在怀中肆意怜爱的场景，狐狸尾巴尖都会羞耻得发烫呢。下次，恩公还想看小女子娇声迎合吗？",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请停云姑娘赐教！（初次对决：狐商全力迎战）",
            "combat_btn_unlocked": "【身心对决】停云，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "哎呀，恩公，您又来看望小女子了？自从上次败在恩公手下，停云的身心早已认定了您这位大贵人。今天是要来一场快意切磋，还是让小狐狸为您提供独门侍奉？",
            "menu_prompt_unlocked": "恩公大人，小女子停云随时由您吩咐差遣，绝不推辞半分。",
            "mid_locked": "恩公，招数还没使完呢，小女子的折扇可还掩着后招呢！",
            "mid_unlocked": "哈啊，恩公，小女子的骨头都快被您揉散了，您说什么便是什么，",
            "distracted_cmd": "【命令识趣】停云，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "既然是恩公的指令，那小女子就乖乖收拢心神，任由恩公尽情享用了，",
            "lock_cmd": "【快感保护】停云，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "庆云祥音化作清心暖意护持恩公，必不让情浪伤损您的根本！",
            "endure_confirm": "好生威严刚健的定力，真真让小女子好生敬慕！",
            "surrender_cmd": "【命令认输】别强撑了，停云当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！恩公太厉害了，小女子彻底认输，身子要绝顶了啊啊！",
            "victory": "哈啊，停云这回是彻彻底底被恩公拿下了。商道博弈小女子甘拜下风，这副身段就全由恩公任意发落，您想怎么处置小女子？",
            "defeat": "哎呀呀，恩公承让了。出门在外切莫心急，先在茶席上喝盏仙茗润润嗓子，待会儿停云再好生伺候您过招。",
            "post_kill": "恩公，哪怕刚才将小女子化作软绵绵的玩物随意捏弄，重获身姿后停云依然对您芳心暗许。下一回，小女子依然由着您摆布！",
            "post_spare": "哈啊，刚才在石坪上为您侍奉了这许久，狐耳和尾巴根到现在都还软软的发烫呢。只要恩公身心舒畅，停云便心满意足了。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按上红唇，恩公的手法可真教小女子面红心跳呢。", "emotion": "shy"},
                "mid": {"text": "唔，折扇后头的丁香小舌被您衔住，呼吸间尽是恩公的气息。", "emotion": "blush"},
                "high": {"text": "呜嗯！口舌纠缠得难舍难分，骨子里的媚意全教恩公勾出来了！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着轻纱旗袍轻抚胸前，恩公的动作好生温柔。", "emotion": "shy"},
                "mid": {"text": "呀！纤指直接揉按胸前娇嫩的果儿，狐人的身子一阵阵发酥发软。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口胀麻挺立，小女子的娇羞在恩公掌心下全化作了春泥！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "探向旗袍开叉深处最隐秘的私密，恩公当真不跟小女子客气呢。", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂打圈轻拢慢捻，惹得浑身骨头都要化开了。", "emotion": "blush"},
                "high": {"text": "不行了！温软的花泉涌得衣衫尽湿，极致的狂浪爆发，停云要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "顺着丝滑的大腿轻轻抚摸，恩公的指尖温度直透肌肤。", "emotion": "shy"},
                "mid": {"text": "呀！大腿内侧被细细揉捏，酸麻的力道让小女子连跪坐都要不稳了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿软得一丝力气也无，只能任由恩公按在身下肆意索取。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "摸到身后蓬松大尾巴根部的特制珠塞了，恩公的心思当真俏皮得紧。", "emotion": "shy"},
                "mid": {"text": "唔！珠塞在温软后庭轻轻转动推挤，异样的快美让狐耳都抖个不住。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭完全被恩公掌控了，甜美狂暴的浪潮让小女子魂魄都要飞啦！", "emotion": "climax"}
            }
        }
    }
]

def main():
    print(f"Generating assets for {len(NPC_SPECS)} NPCs: starting")
    for spec in NPC_SPECS:
        npc_id = spec["id"]
        name = spec["name"]
        title = spec["title"]
        region = spec["region"]
        spawn_id = spec["spawn_id"]
        graph_id = spec["dialogue_graph_id"]
        dialogue_file = spec["dialogue_file"]

        # 1. character definition
        char_data = {
            "schema_version": 1,
            "character_id": npc_id,
            "display_name": name,
            "title": title,
            "avatar_profile_id": npc_id,
            "persona_id": f"{npc_id}_persona",
            "presentation_profile_id": f"{npc_id}_default"
        }
        write_json_asset(f"characters/{npc_id}.json", char_data)

        # 2. avatar definition
        avatar_data = {
            "schema_version": 1,
            "avatar_profile_id": npc_id,
            "model_resource": f"res://assets/characters/roster/{npc_id}/{npc_id}.vrm",
            "idle_motion": "res://assets/characters/roster/motions/koikatsu_idle.tres",
            "material_id": npc_id,
            "environment_collision_enabled": False
        }
        write_json_asset(f"avatars/{npc_id}.json", avatar_data)

        # 3. presentation definition
        presentation_data = {
            "schema_version": 1,
            "presentation_profile_id": f"{npc_id}_default",
            "ui_palette": "res://scenes/combat/temple_paper_palette.tres"
        }
        write_json_asset(f"presentation/{npc_id}_default.json", presentation_data)

        # 4. combat definition
        combat_skills = [s["id"] for s in spec["skills"]]
        combat_data = {
            "schema_version": 1,
            "combat_profile_id": f"{npc_id}_combat",
            "strategy_id": "standard",
            "npc_max_pleasure": 100,
            "skill_ids": combat_skills
        }
        write_json_asset(f"combat/{npc_id}_combat.json", combat_data)

        # 5. motion definition
        motion_data = {
            "schema_version": 1,
            "motion_profile_id": f"{npc_id}_motions",
            "bindings": spec["motions"]
        }
        write_json_asset(f"motions/{npc_id}_motions.json", motion_data)

        # 6. reaction definition
        attack_lines = {}
        for skill in spec["skills"]:
            attack_lines[skill["id"]] = {
                "name": skill["name"],
                "damage": skill["damage"],
                "text": skill["text"],
                "emotion": skill["emotion"]
            }
        reaction_data = {
            "schema_version": 1,
            "reaction_profile_id": f"{npc_id}_reactions",
            "speaker": name,
            "zones": spec["reactions"],
            "attack_lines": attack_lines
        }
        write_json_asset(f"reactions/{npc_id}_reactions.json", reaction_data)

        # 7. spawn definition
        spawn_data = {
            "schema_version": 1,
            "spawn_id": spawn_id,
            "character_id": npc_id,
            "region": region,
            "position": spec["position"],
            "heading": spec["heading"],
            "bound_furniture": spec["bound_furniture"]
        }
        write_json_asset(f"spawns/{spawn_id}.json", spawn_data)

        # 8. dialogue definition
        dt = spec["dialogue_texts"]
        dialogue_data = {
            "schema_version": 1,
            "graph_id": graph_id,
            "entry_points": {
                "world_start": "start",
                "unlocked_start": "start_unlocked",
                "combat_manual": "mid_battle_manual",
                "combat_manual_unlocked": "mid_battle_manual_unlocked",
                "victory_settlement": "victory_node",
                "defeat_settlement": "defeat_node",
                "post_kill": "post_kill_greeting",
                "post_spare": "post_spare_greeting"
            },
            "nodes": {
                "start": {
                    "type": "text",
                    "speaker": name,
                    "text": dt["start"],
                    "emotion": "smile",
                    "next": "main_menu_choices"
                },
                "main_menu_choices": {
                    "type": "choice",
                    "speaker": name,
                    "text": dt["menu_prompt"],
                    "choices": [
                        {
                            "text": dt["lore_btn"],
                            "target": "lore_regional"
                        },
                        {
                            "text": dt["combat_btn_locked"],
                            "action": "enter_combat"
                        },
                        {
                            "text": "【稍后再聊】你先忙吧，我四处走走。",
                            "action": "close"
                        }
                    ]
                },
                "lore_regional": {
                    "type": "text",
                    "speaker": name,
                    "text": dt["lore"],
                    "emotion": "smile",
                    "next": "main_menu_choices"
                },
                "start_unlocked": {
                    "type": "text",
                    "speaker": name,
                    "text": dt["start_unlocked"],
                    "emotion": "blush",
                    "next": "main_menu_choices_unlocked"
                },
                "main_menu_choices_unlocked": {
                    "type": "choice",
                    "speaker": name,
                    "text": dt["menu_prompt_unlocked"],
                    "choices": [
                        {
                            "text": dt["lore_btn_unlocked"],
                            "target": "lore_regional_unlocked"
                        },
                        {
                            "text": dt["combat_btn_unlocked"],
                            "action": "enter_combat"
                        },
                        {
                            "text": "【随意漫步】我只是来看看你，一会儿再来找你。",
                            "action": "close"
                        }
                    ]
                },
                "lore_regional_unlocked": {
                    "type": "text",
                    "speaker": name,
                    "text": dt["lore_unlocked"],
                    "emotion": "blush",
                    "next": "main_menu_choices_unlocked"
                },
                "mid_battle_manual": {
                    "type": "choice",
                    "speaker": name,
                    "text": dt["mid_locked"],
                    "choices": [
                        {
                            "text": "【咬牙忍耐】集中精神调整呼吸，本轮承受快感减免 50%！",
                            "set_blackboard": {
                                "edging_endure": True
                            },
                            "target": "mid_battle_confirm_endure"
                        },
                        {
                            "text": "【继续对决】好，那我可要全力以赴了！",
                            "action": "resume_combat"
                        }
                    ]
                },
                "mid_battle_manual_unlocked": {
                    "type": "choice",
                    "speaker": name,
                    "text": dt["mid_unlocked"],
                    "choices": [
                        {
                            "text": dt["distracted_cmd"],
                            "set_blackboard": {
                                "meta_cheat_enabled": True,
                                "meta_cheat_mode": "distracted"
                            },
                            "target": "mid_battle_confirm_distracted"
                        },
                        {
                            "text": dt["lock_cmd"],
                            "set_blackboard": {
                                "meta_cheat_enabled": True,
                                "meta_cheat_mode": "lock_master_pleasure"
                            },
                            "target": "mid_battle_confirm_lock"
                        },
                        {
                            "text": dt["surrender_cmd"],
                            "set_blackboard": {
                                "meta_cheat_enabled": True,
                                "meta_cheat_mode": "instant_surrender"
                            },
                            "target": "mid_battle_confirm_surrender"
                        },
                        {
                            "text": "【咬牙忍耐】集中精神调整呼吸，本轮承受快感减免 50%！",
                            "set_blackboard": {
                                "edging_endure": True
                            },
                            "target": "mid_battle_confirm_endure"
                        },
                        {
                            "text": "【继续切磋】很好，我们继续享受这场愉悦的博弈！",
                            "action": "resume_combat"
                        }
                    ]
                },
                "mid_battle_confirm_distracted": {
                    "type": "text",
                    "speaker": name,
                    "text": dt["distracted_confirm"],
                    "emotion": "blush",
                    "next": "mid_battle_resume"
                },
                "mid_battle_confirm_lock": {
                    "type": "text",
                    "speaker": name,
                    "text": dt["lock_confirm"],
                    "emotion": "shy",
                    "next": "mid_battle_resume"
                },
                "mid_battle_confirm_endure": {
                    "type": "text",
                    "speaker": name,
                    "text": dt["endure_confirm"],
                    "emotion": "confident",
                    "next": "mid_battle_resume"
                },
                "mid_battle_confirm_surrender": {
                    "type": "text",
                    "speaker": name,
                    "text": dt["surrender_confirm"],
                    "emotion": "climax",
                    "next": "mid_battle_resume"
                },
                "mid_battle_resume": {
                    "type": "choice",
                    "speaker": name,
                    "text": "调整呼吸，对决继续！",
                    "choices": [
                        {
                            "text": "【重返战场】继续对决",
                            "action": "resume_combat"
                        }
                    ]
                },
                "victory_node": {
                    "type": "choice",
                    "speaker": name,
                    "text": dt["victory"],
                    "choices": [
                        {
                            "text": spec["service_label"],
                            "action": spec["service_action"]
                        },
                        {
                            "text": "【击杀处置】体验物理布娃娃玩弄分支（同样永久解锁角色）。",
                            "action": "kill"
                        },
                        {
                            "text": "【点到为止】刚才的切磋很精彩，我们握手言和吧。",
                            "action": "close"
                        }
                    ]
                },
                "defeat_node": {
                    "type": "text",
                    "speaker": name,
                    "text": dt["defeat"],
                    "emotion": "smile",
                    "action": "close"
                },
                "post_kill_greeting": {
                    "type": "text",
                    "speaker": name,
                    "text": dt["post_kill"],
                    "emotion": "shy",
                    "next": "main_menu_choices_unlocked"
                },
                "post_spare_greeting": {
                    "type": "text",
                    "speaker": name,
                    "text": dt["post_spare"],
                    "emotion": "blush",
                    "next": "main_menu_choices_unlocked"
                }
            }
        }
        write_json_asset(dialogue_file, dialogue_data)

        # 9. encounter definition
        encounter_data = {
            "schema_version": 1,
            "encounter_id": spawn_id,
            "character_id": npc_id,
            "spawn_id": spawn_id,
            "flow_behavior_id": "standard_duel",
            "dialogue_bundle_id": graph_id,
            "combat_profile_id": f"{npc_id}_combat",
            "reaction_profile_id": f"{npc_id}_reactions",
            "motion_profile_id": f"{npc_id}_motions",
            "supported_entry_points": [
                "start",
                "unlocked_start",
                "mid_battle_manual",
                "combat_manual_unlocked",
                "victory_node",
                "defeat_node",
                "post_spare",
                "post_kill"
            ]
        }
        write_json_asset(f"encounters/{spawn_id}.json", encounter_data)

    print("Successfully generated all NPC assets!")

if __name__ == "__main__":
    main()
