# -*- coding: utf-8 -*-
"""
Script to generate the complete 9-file asset suites for Batch 2 (8 NPCs):
nilou, kokomi, rosaria, noelle, huohuo, yunjin, kirara, ayaka.
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
        "id": "nilou",
        "name": "妮露",
        "title": "莲光落舞",
        "region": "浅水庭院",
        "spawn_id": "water_nilou",
        "dialogue_graph_id": "nilou_water_bundle",
        "dialogue_file": "dialogue/nilou/water_dialogue.json",
        "position": [-915.000, 0.280, 633.000],
        "heading": 45.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【临水侍奉】请妮露在水池边平整地面上，为我提供柔美纯真的舞娘侍奉。",
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
                "id": "dance_of_haftkarsvar",
                "name": "七域舞步·水旋翩跹",
                "damage": 16.0,
                "text": "旋舞起落，水波盈盈！请看大巴扎剧场的特约舞步，Master可别看呆了哦！",
                "emotion": "smile"
            },
            {
                "id": "dance_of_abzendegi",
                "name": "浮莲雀跃·水波荡漾",
                "damage": 18.0,
                "text": "宛若水莲盛放！以清澈水流轻抚身心，请接下妮露最诚挚的心意！",
                "emotion": "confident"
            },
            {
                "id": "bazaar_charm",
                "name": "纯真献舞·动人心弦",
                "damage": 15.0,
                "text": "只要能让Master展露笑颜，妮露无论跳多少支舞都乐意！",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "乐声响起，花瓣飘落！您好，Master。我是大巴扎剧场的舞娘妮露，正在这处浅水展廊边练习踩水舞步。若您想邀请妮露伴您同行，请先与我进行一场切磋，检验彼此的灵犀吧！",
            "menu_prompt": "Master，今天有什么需要妮露帮忙的吗？我很乐意为您起舞！",
            "lore_btn": "【关于水庭】在浅水薄壳展廊边赤足跳舞，感觉如何？",
            "lore": "这里的浅水刚好漫过脚踝，水波倒映着穹顶，每走一步都有清脆的水声，简直像置身于水之舞台！微风拂过水面，身心都会觉得轻盈欢快呢。",
            "lore_btn_unlocked": "【关于临水】在水边休息，心情会很放松吧？",
            "lore_unlocked": "只要Master在身边，水花都会变得特别甜。每次踩进水里，就会想起被您揽在怀里轻揉腰肢的感受，耳根都忍不住悄悄发烫呢。下次，还要在水边看我为您独舞吗？",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请妮露姑娘赐教！（初次对决：舞娘全力迎战）",
            "combat_btn_unlocked": "【身心对决】妮露，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，您又来看妮露了！自从上次在对决中败给您，妮露的身体只要一被您碰触，就会软绵绵地化开。今天是要切磋舞艺，还是让妮露为您提供专属的温软侍奉呢？",
            "menu_prompt_unlocked": "主人，妮露是只属于您的舞娘，随时听凭您的吩咐！",
            "mid_locked": "Master，舞步还没停歇呢，要集中精神，接下妮露的旋舞攻势哦！",
            "mid_unlocked": "哈啊，Master，妮露浑身都在发软，只要您的一句指令，妮露什么都听您的，",
            "distracted_cmd": "【命令识趣】妮露，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呜，既然是主人的命令，那妮露就稍微走神一下，请温柔一点呀，",
            "lock_cmd": "【快感保护】妮露，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "纯澈的水环绕在主人身周，妮露会为您守护好快感防线！",
            "endure_confirm": "好专注的眼神，那妮露也要更加认真地起舞了！",
            "surrender_cmd": "【命令认输】别强撑了，妮露当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，妮露彻底认输，身子要绝顶了啊啊！",
            "victory": "哈啊，双足完全站不稳了，妮露彻底败给了Master。作为专属舞娘，妮露愿意为您奉献一切，您想怎么处置我？",
            "defeat": "呼，看来今天的旋律由妮露占了先机呢！Master不必沮丧，先坐在展廊石沿上歇歇脚，待会儿妮露再陪您跳舞！",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重塑身姿后的妮露依然记得您的温度。今天的特别侍奉，请务必继续指派给我哦！",
            "post_spare": "哈啊，刚才在临水地面上为您侍奉了那么久，薄纱舞裙到现在都还湿漉漉的呢。能让Master尽兴，就是妮露最大的幸福。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在唇边？Master，舞娘的红唇今天只为您绽放哦。", "emotion": "shy"},
                "mid": {"text": "唔，柔软的舌尖被您轻轻含弄，呼吸间全是您的气息了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液都要溢出来了，脑海一片朦胧，好幸福呀！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着轻薄舞裙揉抚胸前，Master的手心好温暖。", "emotion": "shy"},
                "mid": {"text": "呀！指尖直接拨弄双峰尖端，酸麻感顺着脊椎直往上窜。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立胀麻了，好强烈的快感，妮露快站不住了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "碰到了最害羞的花核，Master，心跳变得好剧烈！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂打圈按压，连水珠顺着大腿滑落都顾不上了呢。", "emotion": "blush"},
                "high": {"text": "不行了！温热的花蜜完全涌出，好剧烈的高潮情浪，妮露要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚摸赤足上方的雪白大腿内侧，触感好细腻清晰。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根被轻轻拿捏，酸软的感觉蔓延到腰肢，脚趾都蜷起来了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软地倚靠在Master怀里任您索取。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "身后轻巧的水晶尾塞被碰到了，Master，那里好难为情呀。", "emotion": "shy"},
                "mid": {"text": "唔！尾塞被缓缓转动推入深处，异样的充实感让舞娘的腰肢战栗不止。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭完全失守了，身体深处的甜美痉挛根本停不下来啦！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "kokomi",
        "name": "珊瑚宫心海",
        "title": "真珠之智",
        "region": "浅水庭院",
        "spawn_id": "water_kokomi",
        "dialogue_graph_id": "kokomi_water_bundle",
        "dialogue_file": "dialogue/kokomi/water_dialogue.json",
        "position": [-895.0, 0.28, 622.0],
        "heading": -90.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【池畔侍奉】请心海在静水倒影池畔平整地面上，为我提供柔顺温存的军师侍奉。",
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
                "id": "kurage_oath",
                "name": "海月之誓·化海月涌",
                "damage": 15.0,
                "text": "海月召唤，水润四方！以水母的柔波拂拭Master的每一寸防线！",
                "emotion": "smile"
            },
            {
                "id": "kaijin_ceremony",
                "name": "海人化羽·水色微澜",
                "damage": 18.0,
                "text": "羽衣飞扬，波澜不惊！请见识海祇岛现人神巫女的真正身姿！",
                "emotion": "confident"
            },
            {
                "id": "tactical_guidance",
                "name": "锦囊妙策·攻心柔术",
                "damage": 16.0,
                "text": "兵法云：攻心为上。不知Master的心神是否已被我彻底看破了呢？",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "海潮生智，妙算由心。初次见面，Master。我是海祇岛的现人神巫女珊瑚宫心海，正在这处浅水穹顶下调阅兵法与水文记录。想让我成为您的专属军师？那就先在身心对决中展现您的统御之能吧！",
            "menu_prompt": "Master，今天有何军情或疑难？心海愿为您参谋指点。",
            "lore_btn": "【关于薄壳】在薄壳穹顶下看书，能量恢复得快吗？",
            "lore": "这里静谧无哗，水面倒映着天光，避风且采光柔和，是个绝佳的避世读书所。在这里读一卷兵书，能量值能恢复得比平时快很多呢。",
            "lore_btn_unlocked": "【关于池畔】在池畔静坐，心绪会很平静吧？",
            "lore_unlocked": "平日确实宁静，但只要看到水面上泛起的倒影，就会想起被Master按在池畔彻底攻陷的画面，心跳便止不住加快。今后，我的智谋与身躯皆听从您的军令。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请军师大人赐教！（初次对决：军师全力迎战）",
            "combat_btn_unlocked": "【身心对决】心海，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，您又来找心海了？自从上次推演败给您，现人神巫女的能量值早已完全绑定在您身上。今天是要推演战阵，还是让心海为您提供特殊的私密侍奉？",
            "menu_prompt_unlocked": "主公大人，心海随时听凭差遣，锦囊妙计尽数为您敞开。",
            "mid_locked": "Master，战局尚未底定，心海的计策可不会轻易失效哦！",
            "mid_unlocked": "哈啊，Master，心海的能量值已经见底了，任凭您随心发落，",
            "distracted_cmd": "【命令识趣】心海，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "既然是主公的号令，那心海便散去护体水波，任由您随意攻伐，",
            "lock_cmd": "【快感保护】心海，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "化海月吐出水泡护持主公心神，为您抵挡所有的过激冲击！",
            "endure_confirm": "好沉稳的定力，真不愧是令心海折服的主公！",
            "surrender_cmd": "【命令认输】别强撑了，心海当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！军师彻底认输，身子承受不住这般狂澜，要绝顶了啊！",
            "victory": "哈啊，百密一疏，心海在身心对弈上彻底败给主公了。作为您的战利品，现人神巫女的身心全部归您所有，您想如何处置我？",
            "defeat": "看来这局还是心海的谋略略高一筹呢，Master。先在池边饮盏茶水休整片刻，心海随时恭候下次切磋。",
            "post_kill": "Master，哪怕将巫女的娇躯视作布偶任意把玩，重塑之后心海的忠诚亦不会动摇半分。下一次，心海依然遵从您的意旨！",
            "post_spare": "哈啊，刚才在池畔为您侍奉了这许久，双腿至今还在微微酸软呢。能为主公排遣疲乏，心海的能量便已满溢了。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖触碰唇珠，Master的举动可真让人心湖微漾。", "emotion": "shy"},
                "mid": {"text": "唔，温软的舌尖被您牵引，军师的理智好像开始模糊了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口津连缀，喘息难平，现人神巫女的威严彻底融化了！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着巫女羽衣轻揉前胸，主公的手法当真细腻。", "emotion": "shy"},
                "mid": {"text": "呀！指尖隔着丝缎揉按双峰尖端，体内的水元素好像在沸腾。", "emotion": "blush"},
                "high": {"text": "哈啊！胸前完全硬挺挺立，好强烈的酸麻，心海要支撑不住了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "探向羽衣下摆最隐秘的花心，Master的兵锋当真长驱直入。", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂按压打圈，连双腿都忍不住羞耻地悄悄夹紧了呢。", "emotion": "blush"},
                "high": {"text": "不行了！温热的花露汩汩溢出，极致的高潮绝顶，心海要沦陷了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "顺着白皙的大腿轻抚内侧，手心的温度好滚烫。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根处被轻轻拿捏，酸软的感觉蔓延至腰肢，完全使不上力。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿虚软得无法合拢，只能任由主公按在身前肆意采撷。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "摸到身后贝壳造型的温润尾塞，Master，那里好害羞呀。", "emotion": "shy"},
                "mid": {"text": "唔！尾塞在紧致的深处缓缓旋动，从未体验过的深邃快美直冲脑海。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭完全失守，甜美的狂乱让军师大人的思考彻底断线啦！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "rosaria",
        "name": "罗莎莉亚",
        "title": "棘冠修女",
        "region": "孤顶教堂",
        "spawn_id": "church_rosaria",
        "dialogue_graph_id": "rosaria_church_bundle",
        "dialogue_file": "dialogue/rosaria/church_dialogue.json",
        "position": [-1345.000, 43.400, 113.000],
        "heading": -45.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【石柱侍奉】请罗莎莉亚在教堂石柱旁平整地面上，为我提供冷艳顺从的刺客侍奉。",
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
                "id": "ravaging_confession",
                "name": "噬罪的告解·幽冷匕影",
                "damage": 17.0,
                "text": "无处可逃！极速闪现至身后，以冰冷的锋芒检验Master的神经反应！",
                "emotion": "confident"
            },
            {
                "id": "rites_of_termination",
                "name": "临终的圣礼·极寒冰枪",
                "damage": 19.0,
                "text": "审判降临！冰枪破空坠地，释放极致的严霜情潮！",
                "emotion": "confident"
            },
            {
                "id": "shadow_strike",
                "name": "暗夜戒律·刺客迷魂",
                "damage": 15.0,
                "text": "白天的教堂规矩我没兴趣，但在黑夜里，我说了算。",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "啧，又来了一个多管闲事的。我是西风教会的修女罗莎莉亚。别用那种看圣职者的眼光看我，我可不唱赞美诗。想让我替你办事？那就拿出真本事在身心对决里赢过我，否则少来打扰我抽烟吹风。",
            "menu_prompt": "有话快说，我的耐心向来很有限。",
            "lore_btn": "【关于教堂】独自靠在露天石柱后面，不会觉得冷吗？",
            "lore": "比起在闷热的室内听人祈祷，这里的风让人清醒得多。石柱后是个观察死角，任何潜入者都逃不过我的眼睛。",
            "lore_btn_unlocked": "【关于夜风】海岛的夜风，很合你的胃口吧？",
            "lore_unlocked": "风确实不错，但每次靠在这根石柱上，就会想起被你强行按住惩罚的滋味，连冰冷的指尖都忍不住发烫。今后，我的人归你管了。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请修女赐教！（初次对决：刺客全力迎战）",
            "combat_btn_unlocked": "【身心对决】罗莎莉亚，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "哼，Master，你又来了。既然上次输在你的手里，我就认赌服输。今天是要继续身心较量，还是让我换一身打扮给你提供专属服务？",
            "menu_prompt_unlocked": "既然你是胜者，想怎么吩咐我都行，随你便。",
            "mid_locked": "别走神，我的匕首可不是吃素的，全力攻过来！",
            "mid_unlocked": "哈啊，Master，我握匕首的手都使不上劲了，任由你随心处置，",
            "distracted_cmd": "【命令识趣】罗莎莉亚，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "切，既然是胜者的要求，那我就收起刺刃，任你放肆好了，",
            "lock_cmd": "【快感保护】罗莎莉亚，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "极寒冰晶冻结多余的感官冲击，你的防线我来替你守住！",
            "endure_confirm": "有点骨气嘛，那就让我看看你能撑到什么时候！",
            "surrender_cmd": "【命令认输】别强撑了，罗莎莉亚当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！可恶，身子完全承受不住这股浪潮，要绝顶了啊！",
            "victory": "哈啊，冰枪碎裂，这局是我彻底输了。按照规矩，败者就是赢家的猎物，你想怎么摆弄我这副身子？",
            "defeat": "看来你的本事还差点火候呢，Master。先去台阶上坐着歇会儿吧，等有了底气再来找我。",
            "post_kill": "Master，把冷酷的修女当成战利品随意摆弄，你的癖好还真是不容小觑。复活之后，我依然会顺着你的心意行事！",
            "post_spare": "哈啊，刚才靠在石柱边侍奉了这么久，黑丝网袜下的双腿都还在发抖呢。只要你满意，我奉陪到底。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖碰到嘴边了，小心我一口咬断你的手指。", "emotion": "confident"},
                "mid": {"text": "唔，居然敢强硬地吻过来，温热的纠缠让人呼吸发乱。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的喘息完全压不住，冷酷的伪装全被你击碎了！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着黑色修女服抚弄胸前，你的胆子还真是不小。", "emotion": "shy"},
                "mid": {"text": "呀！直接掐按挺立的双峰顶端，冰冷的刺客也禁不住发烫。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口胀麻得要命，好强烈的电击感，快要站不住了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "直接伸向网袜深处的私处，你还真是不客气。", "emotion": "shy"},
                "mid": {"text": "唔啊！隔着薄网狠狠揉按花核，双腿忍不住紧紧夹住了你的手臂。", "emotion": "blush"},
                "high": {"text": "不行了！温热的花露完全漫出，好凶猛的高潮，我要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚摸裹在渔网袜下的结实大腿，手心倒是挺热的。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根被狠狠掐揉，原本敏捷的肌肉竟然完全酸软了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿彻底瘫软无力，只能顺从地缠在你腰间任你采摘。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "摸到身后冰晶特制尖锥尾塞了，哼，真会挑刁钻的位置。", "emotion": "shy"},
                "mid": {"text": "唔！尾塞在紧致的深处旋转顶弄，刺客从未体会过的充实感席卷全身。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭完全失守了，狂暴的快感冲击让我脑子里一片空白！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "noelle",
        "name": "诺艾尔",
        "title": "未授勋之花",
        "region": "孤顶教堂",
        "spawn_id": "church_noelle",
        "dialogue_graph_id": "noelle_church_bundle",
        "dialogue_file": "dialogue/noelle/church_dialogue.json",
        "position": [-1336.000, 43.400, 116.000],
        "heading": -90.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【露台侍奉】请诺艾尔在教堂侧翼露台平整地面上，为我提供极尽体贴的全能女仆侍奉。",
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
                "id": "breastplate",
                "name": "护心铠·岩石守卫",
                "damage": 15.0,
                "text": "交给我吧，什么都可以交给我！坚固的护心铠会为Master抵挡一切！",
                "emotion": "smile"
            },
            {
                "id": "sweeping_time",
                "name": "大扫除·巨岩扫击",
                "damage": 18.0,
                "text": "岩石的重量，令人安心！请接下诺艾尔全力以赴的大扫除一击！",
                "emotion": "confident"
            },
            {
                "id": "maid_devotion",
                "name": "女仆奉献·贴心照顾",
                "damage": 16.0,
                "text": "身为西风骑士团的女仆，照顾好Master的身心是我的第一要务！",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "交给我吧，无论是大扫除还是巡逻！您好，Master。我是西风骑士团的女仆诺艾尔，正在整理露台的落叶与碎石。如果需要诺艾尔伴您同行并照顾您的起居，请先与我进行一场切磋，检验我的修行成果吧！",
            "menu_prompt": "Master，今天有什么需要诺艾尔为您服务的吗？不管是洗涤还是揉肩我都擅长！",
            "lore_btn": "【关于露台】在孤顶教堂的侧翼露台打扫，累不累？",
            "lore": "一点也不累！露台风很大，打扫干净后泡一壶红茶，看远处的浪花，感觉整座教堂都变得明亮起来了。只要大家觉得舒心，诺艾尔就很高兴！",
            "lore_btn_unlocked": "【关于茶歇】在露台上为你泡茶，感觉如何？",
            "lore_unlocked": "只要Master喜欢，诺艾尔随时为您备好点心。每次站在露台边，就会想起被Master温柔按在身前疼爱的细节，胸口总是暖烘烘的呢。下次，还让我服侍您喝茶吗？",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请诺艾尔赐教！（初次对决：女仆全力迎战）",
            "combat_btn_unlocked": "【身心对决】诺艾尔，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，您又来看望诺艾尔了！自从上次切磋败给您之后，诺艾尔在心里早已把您当成最重要的主人。今天是要继续身心训练，还是让专属女仆为您提供贴身侍奉呢？",
            "menu_prompt_unlocked": "主人，诺艾尔时刻准备着为您效劳，任何要求都可以提出来！",
            "mid_locked": "Master，护心铠还在起效呢，请集中精神攻过来！",
            "mid_unlocked": "哈啊，Master，诺艾尔的力气都被您化解了，只要您吩咐，我都顺从照做，",
            "distracted_cmd": "【命令识趣】诺艾尔，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "是，既然是主人的命令，那诺艾尔就稍微放松防守，请轻一点对待我呀，",
            "lock_cmd": "【快感保护】诺艾尔，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "护心铠化作坚固护盾环绕主人，诺艾尔绝不让多余的情潮伤害到您！",
            "endure_confirm": "好坚韧的毅力，诺艾尔也必须加倍努力才行！",
            "surrender_cmd": "【命令认输】别强撑了，诺艾尔当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，诺艾尔彻底认输，身子要绝顶了啊啊！",
            "victory": "哈啊，岩石大剑都拿不稳了，是诺艾尔彻底输给主人了。作为您的专属女仆，这副身体全部任由Master发落，您想怎么吩咐我？",
            "defeat": "哇，是诺艾尔侥幸赢了一局呢！Master请不要灰心，先在石凳上喝杯温红茶休息，待会儿诺艾尔再陪您练习！",
            "post_kill": "Master，刚才虽然化作玩偶任由您摆弄，但重构之后的诺艾尔依然时刻记挂着主人的健康。今天的特别侍奉，请务必继续指派给我哦！",
            "post_spare": "哈啊，刚才在露台地面上为您侍奉了那么久，女仆裙下的双腿到现在都还在轻轻发颤呢。能让主人感到舒适，就是诺艾尔最大的荣耀。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖碰到了双唇？Master，女仆也是会害羞的呢。", "emotion": "shy"},
                "mid": {"text": "唔，温软的舌尖被轻轻含弄，诺艾尔的呼吸都要乱掉了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的清润甜津溢出来了，脑海一片空白，好害羞呀！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着女仆铠甲抚摸前胸，主人的手心好宽厚。", "emotion": "shy"},
                "mid": {"text": "呀！解开胸甲直接捏弄饱满的顶端，酥麻感顺着神经传遍全身。", "emotion": "blush"},
                "high": {"text": "哈啊！胸前挺立得发烫，女仆坚毅的意志要在您的掌心下融化了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "碰到了裙底最私密的地方，Master，那里太敏感了！", "emotion": "shy"},
                "mid": {"text": "唔啊！隔着薄薄的底裤按压花蒂，连脚趾都忍不住悄悄蜷缩起来了。", "emotion": "blush"},
                "high": {"text": "不行了！温热的花露完全浸湿了裙衬，好强烈的绝顶，诺艾尔要高潮了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚摸包裹在白丝袜下结实丰腴的大腿，触感好清晰。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根被轻轻拿捏，平日力大无穷的双腿竟然完全软化了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软地倚靠在Master怀里任您摆弄。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "身后女仆荷叶边下方的特制岩核小塞子被碰到了，呜，好难为情。", "emotion": "shy"},
                "mid": {"text": "唔！尾塞在紧致的深处被缓缓旋动，从未体验过的充实感直冲脑海。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭完全失守了，身体深处的甜美颤抖根本停不下来啦！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "huohuo",
        "name": "藿藿",
        "title": "续命幽赏",
        "region": "东侧覆土庭院",
        "spawn_id": "earth_huohuo",
        "dialogue_graph_id": "huohuo_earth_bundle",
        "dialogue_file": "dialogue/huohuo/earth_dialogue.json",
        "position": [432.291, 62.020, 271.000],
        "heading": 0.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【回廊侍奉】请藿藿在覆土庭院回廊平整地面上，为我提供胆怯娇柔的狐人侍奉。",
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
                "id": "talisman_protection",
                "name": "灵符保命·怯怯祈安",
                "damage": 14.0,
                "text": "急急如律令！灵符保佑，Master您可千万不要吓唬藿藿呀！",
                "emotion": "shy"
            },
            {
                "id": "tail_exorcism",
                "name": "尾巴发威·摄魂镇祟",
                "damage": 17.0,
                "text": "尾巴大爷发威啦！鬼火化作汹涌情浪，请承受来自尾巴的怒火吧！",
                "emotion": "confident"
            },
            {
                "id": "ghostly_flutter",
                "name": "胆小依偎·楚楚可怜",
                "damage": 15.0,
                "text": "呜，身子在发抖，如果Master能温柔抱抱藿藿就好了。",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "呀！有鬼，不对，是Master！您好，我是罗浮仙舟十王司见习判官藿藿。这、这里阴凉避风，我正在回廊边检查镇魔符箓。如果Master想带藿藿一起走，请先与我切磋一下，看看尾巴大爷答不答应吧！",
            "menu_prompt": "Master，找藿藿有什么事吗？尾巴大爷今天好像挺安静的。",
            "lore_btn": "【关于回廊】覆土庭院的回廊，看起来很幽静呢。",
            "lore": "这里的绿植屋顶挡住了强光，微风从天井吹进来，回廊里凉丝丝的，很适合躲起来看符书。不过偶尔有风声掠过，还是会把藿藿吓一跳呢。",
            "lore_btn_unlocked": "【关于回廊】在回廊里小憩，不会害怕了吧？",
            "lore_unlocked": "只要有Master陪在身边，藿藿就一点也不怕了。每次走过回廊，就会想起被您揽在怀里轻揉尾巴的滋味，尾巴尖尖都会害羞得打卷。下、下次，还能抱抱我吗？",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请藿藿判官赐教！（初次对决：判官全力迎战）",
            "combat_btn_unlocked": "【身心对决】藿藿，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "呜，Master，您又来找藿藿了！上次切磋输给您之后，尾巴大爷都承认您是真正的主人了。今天是要进行身心较量，还是需要藿藿为您提供专属的贴身服侍呢？",
            "menu_prompt_unlocked": "主人，藿藿听您的吩咐，请不要突然吓唬我哦。",
            "mid_locked": "Master，尾巴大爷还在撑着呢，请集中精神攻过来！",
            "mid_unlocked": "哈啊，Master，藿藿的膝盖都跪软了，只要您吩咐，藿藿都听话，",
            "distracted_cmd": "【命令识趣】藿藿，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呜，既然是主人的命令，那藿藿就稍微走神一下，请不要弄疼我呀，",
            "lock_cmd": "【快感保护】藿藿，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "十王司护身灵符升起，藿藿会为您守住快感防线！",
            "endure_confirm": "好厉害的定力，藿藿也要鼓起勇气面对了！",
            "surrender_cmd": "【命令认输】别强撑了，藿藿当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，藿藿彻底认输，身子要绝顶了啊啊！",
            "victory": "呜哇，旗幡掉在地上了，藿藿彻底输给主人了。作为手下败将，藿藿任凭Master处置，您想怎么吩咐我？",
            "defeat": "呼，多亏了尾巴大爷帮忙，藿藿居然赢了！Master请不要生气，先在回廊木凳上休息，喝杯热茶，一会儿藿藿再陪您切磋！",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重塑之后的藿藿依然紧紧抓着主人的衣角。今天的特别侍奉，请务必继续指派给我哦！",
            "post_spare": "哈啊，刚才在回廊地面上为您侍奉了那么久，毛茸茸的尾巴到现在都还在发烫呢。能让主人开心，藿藿就安心了。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖碰到嘴唇了？Master，藿藿的胆子很小，请轻一点哦。", "emotion": "shy"},
                "mid": {"text": "唔，小巧的舌头被您轻轻含弄，呼吸间全乱了节奏。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的清亮甜津溢出来，脑海一片混沌，好羞耻呀！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着判官小棉袄抚摸前胸，主人的手心好暖和。", "emotion": "shy"},
                "mid": {"text": "呀！指尖直接揉弄娇小软嫩的双峰，尾巴都吓得竖起来了。", "emotion": "blush"},
                "high": {"text": "哈啊！胸前挺立得发酸，好强烈的酥麻感，藿藿快站不住了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "碰到了最隐秘的花蕾，Master，心跳快得要跳出来了！", "emotion": "shy"},
                "mid": {"text": "唔啊！隔着短衬按压花蒂，双腿忍不住死死绞紧了您的手臂。", "emotion": "blush"},
                "high": {"text": "不行了！温热的花露汩汩涌出，好强烈的高潮浪潮，藿藿要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚摸软乎乎的小腿与大腿内侧，手心的触感好清晰呀。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根被轻轻揉捏，酸软的感觉蔓延全身，整个人都化开了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全使不上力，只能软软地倚在Master怀里任您摆布。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "摸到身后青绿色火焰小塞子了，呜，尾巴大爷都在抗议了。", "emotion": "shy"},
                "mid": {"text": "唔！尾塞在紧致的深处被缓缓旋动，从未体验过的酸胀快美让狐耳直颤。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭完全失守了，身体深处的甜美剧烈抽搐停不下来啦！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "yunjin",
        "name": "云堇",
        "title": "红绒缚命",
        "region": "东侧覆土庭院",
        "spawn_id": "earth_yunjin",
        "dialogue_graph_id": "yunjin_earth_bundle",
        "dialogue_file": "dialogue/yunjin/earth_dialogue.json",
        "position": [450.000, 62.025, 270.000],
        "heading": 180.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【石坪侍奉】请云堇在练功石坪平整地面上，为我提供戏苑当家的端庄柔顺侍奉。",
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
                "id": "opening_flourish",
                "name": "旋云开相·飞云流转",
                "damage": 16.0,
                "text": "枪势如云，身段如柳！请看云翰社当家名角的开相身法！",
                "emotion": "smile"
            },
            {
                "id": "cliffbreakers_banner",
                "name": "破嶂见旌仪·红毹长歌",
                "damage": 18.0,
                "text": "旌旗列阵，红毹铺展！长歌动九霄，请接下云堇全力的一击！",
                "emotion": "confident"
            },
            {
                "id": "dramatic_aria",
                "name": "梨园唱腔·花旦心弦",
                "damage": 15.0,
                "text": "一曲诉尽千般意，不知Master能否听懂云堇曲中的柔情呢？",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "台前演悲欢，幕后品清茗。小女子云堇，这厢有礼了。我是璃月云翰社的当家戏骨，正在这处覆土石坪练习云手身段。想邀云堇同游全岛？那就先在身心对招中，让小女子领教Master的风采吧！",
            "menu_prompt": "Master，今日寻小女子有何关照？愿为您清唱一曲解乏。",
            "lore_btn": "【关于石坪】在覆土庭院中央石坪练功，感觉如何？",
            "lore": "这里的石坪平整开阔，四周岩壁环绕，回声清越圆润，最宜演练唱腔与武戏身段。练功累了便就地品盏香茗，当真是一大快事。",
            "lore_btn_unlocked": "【关于练功】常在此处练功，不会觉得劳累吗？",
            "lore_unlocked": "只要Master肯在一旁赏光，云堇便不知疲倦。只是每次站在石坪上，就会想起被您揽入怀中轻解戏服的场景，红晕总要蔓延到双颊。下次，还听我唱新戏吗？",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请云堇大家赐教！（初次对决：名角全力迎战）",
            "combat_btn_unlocked": "【身心对决】云堇，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，您又来看望云堇了。自从在台上切磋输给了您，小女子的心念便全系在您一人身上。今天是要推敲身段，还是让云堇为您提供独门的闺阁侍奉？",
            "menu_prompt_unlocked": "主人，云堇随时任凭差遣，台前幕后皆听凭吩咐。",
            "mid_locked": "Master，戏未终局，云堇的枪势可还没收招呢！",
            "mid_unlocked": "哈啊，Master，戏服下的身子都发软了，您说什么云堇都顺从，",
            "distracted_cmd": "【命令识趣】云堇，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "谨遵主人吩咐，那云堇便故意漏个破绽，任由主人尽情怜惜，",
            "lock_cmd": "【快感保护】云堇，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "旌旗云幕升起，云堇会为主公稳稳守住快感防线！",
            "endure_confirm": "好生沉稳坚毅的定力，真教小女子由衷敬佩！",
            "surrender_cmd": "【命令认输】别强撑了，云堇当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！主公太强了，云堇彻底认输，身子要绝顶了啊啊！",
            "victory": "哈啊，花枪落地，是云堇彻底败给主人了。戏曲落幕，云堇整个人全部听凭Master发落，您想怎么处置小女子？",
            "defeat": "哎呀，承让了Master。先在石坪条凳上稍事歇息，饮盏清润菊花茶，待会儿云堇再陪您对招！",
            "post_kill": "Master，刚才虽然将小女子化作软绵绵的战利品任意摆弄，复苏之后的云堇依然对您倾心相随。下一回，云堇依然遵从您的调遣！",
            "post_spare": "哈啊，刚才在石坪上为您侍奉了这许久，锦缎戏服下的双腿至今还在微微酸软呢。能让主人舒畅愉悦，便是云堇最大的慰藉。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖拂过唇瓣，Master的举动真教名角芳心微乱。", "emotion": "shy"},
                "mid": {"text": "唔，清唱的花旦之口被您衔住，呼吸间全化作了低回的喘息。", "emotion": "blush"},
                "high": {"text": "呜嗯！口津连绵，戏腔变作了求饶的娇啼，好生羞人呀！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着华美戏服轻抚胸前，主人的动作好生温存。", "emotion": "shy"},
                "mid": {"text": "呀！纤指隔着丝缎揉按双峰尖端，酸麻感蔓延至全身骨骼。", "emotion": "blush"},
                "high": {"text": "哈啊！胸前完全挺立发胀，梨园当家的仪态彻底在您掌心融化了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "探入戏裙深处最隐秘的花心，Master的行径当真大胆。", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂轻拢慢捻，惹得双腿都忍不住悄悄并拢了呢。", "emotion": "blush"},
                "high": {"text": "不行了！温软的花泉汩汩涌出，好强烈的绝顶浪潮，云堇要高潮了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "顺着丝滑的大腿轻轻抚摸，主人的掌心温度好清晰。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根被细细揉捏，平日练功扎实的腿脚竟然完全酸软了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿软得一丝力气也无，只能任由主人按在身前肆意采撷。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "摸到身后红绒璎珞下方的特制玛瑙小塞子，Master，那里好害羞。", "emotion": "shy"},
                "mid": {"text": "唔！尾塞在紧致的深处缓缓转动推挤，从未体会过的深邃快美直透心扉。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭完全失守了，狂暴甜美的震颤让当家名角的理智彻底空白！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "kirara",
        "name": "绮良良",
        "title": "檐宇猫游",
        "region": "海岬小镇与神社",
        "spawn_id": "cape_kirara",
        "dialogue_graph_id": "cape_kirara_bundle",
        "dialogue_file": "dialogue/kirara/cape_dialogue.json",
        "position": [669.745, 1.320, -1073.395],
        "heading": -34.0,
        "bound_furniture": [{"id": "bench_2", "type": "chair", "anchor": "Anchor_Seat"}],
        "service_action": "spare_seat",
        "service_label": "【长椅侍奉】请绮良良在街角长椅上，为我提供活泼顺从的猫娘侍奉。",
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
                },
                "role_b_seated_foot_offset": [0.0, -0.105, -0.13],
                "role_b_seated_skirt_support": {
                    "bone_prefix": "Q_",
                    "half_extents": [0.30, 0.225]
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
                "id": "meowteor_kick",
                "name": "呜喵急件·猫箱飞扑",
                "damage": 16.0,
                "text": "安全准时，使命必达！看绮良良化作猫猫快递箱飞扑过来啦！",
                "emotion": "smile"
            },
            {
                "id": "secret_art_surprise",
                "name": "秘技·惊喜猫猫盒",
                "damage": 18.0,
                "text": "特快专递，惊喜开箱！猫爪弹出的甜美攻势，Master接得住吗？",
                "emotion": "confident"
            },
            {
                "id": "cat_nap_stretch",
                "name": "猫猫伸懒腰·软萌呼噜",
                "damage": 15.0,
                "text": "呼噜噜，要是被Master顺顺毛，猫猫就会舒服得打滚呢。",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "喵呜！狛荷屋金牌快递员绮良良，准时送达！您好呀Master，我正在海岬长椅边清点今天派送的包裹。想让我当您的专属送货猫猫？那就先在身心切磋中陪我玩耍一场，让我看看您的身手吧！",
            "menu_prompt": "Master，今天有需要派送的急件吗？绮良良随时可以出发！",
            "lore_btn": "【关于长椅】坐在小镇街角长椅上休息，感觉怎么样？",
            "lore": "这里的木长椅晒得暖洋洋的，正对着环岛车道，既方便看路，又能趴着小憩。晒晒太阳伸个懒腰，两条尾巴都会舒服得直晃悠呢！",
            "lore_btn_unlocked": "【关于长椅】趴在长椅上打盹，很舒服吧？",
            "lore_unlocked": "长椅晒太阳是很舒服啦，但每次趴在这里，就会想起被Master按在长椅上挠痒痒的画面，猫耳朵都会羞耻得耷拉下来。下次，还要在这里给猫猫顺毛吗？",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请绮良良赐教！（初次对决：猫又全力迎战）",
            "combat_btn_unlocked": "【身心对决】绮良良，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "喵呜，Master，您又来找绮良良玩啦！自从上次对决输给您，绮良良的身心全都被您摸得软乎乎的。今天是要继续玩闹切磋，还是让猫娘为您提供特别的贴身服侍呢？",
            "menu_prompt_unlocked": "主人，绮良良是您的专属猫猫，爪子和尾巴都任您揉捏哦！",
            "mid_locked": "喵呜，猫猫还没认输呢，Master集中精神，接招啦！",
            "mid_unlocked": "哈啊，Master，绮良良的猫爪都使不上劲了，只要您下令，猫猫都听话，",
            "distracted_cmd": "【命令识趣】绮良良，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "喵呜，既然是主人的吩咐，那绮良良就乖乖趴好，任由主人随便欺负啦，",
            "lock_cmd": "【快感保护】绮良良，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "安全包裹结界升起，绮良良会保护好主人的快感防线！",
            "endure_confirm": "好厉害的定力，那绮良良也要拿出真本事飞扑了！",
            "surrender_cmd": "【命令认输】别强撑了，绮良良当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！喵呜！绮良良彻底认输，身子受不住要绝顶了啊啊！",
            "victory": "喵呜，爪子完全软掉了，绮良良彻底输给主人了。作为您的战利品包裹，猫娘整个人都任凭Master签收发落，您想怎么处置我？",
            "defeat": "呼呼，猫猫大获全胜！Master不要灰心，先在长椅上坐着吹吹风，待会儿绮良良再陪您过招！",
            "post_kill": "Master，刚才虽然把猫猫当成布偶玩具任意揉捏，重构之后绮良良依然记得您的温柔抚摸。今天的特别派送，请务必继续指派给我哦！",
            "post_spare": "哈啊，刚才在长椅上为您侍奉了那么久，两条猫尾巴到现在都还软软的发烫呢。能让主人感到开心，就是金牌快递员最大的成就。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖碰到嘴唇了？小心猫猫轻轻咬您一口哦，喵呜。", "emotion": "smile"},
                "mid": {"text": "唔，柔软的猫舌头被您抓住品尝，连呼吸都变得断断续续的。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的甜津止不住，两只猫耳朵羞耻得贴紧了头发！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着活泼的快递短褂揉抚胸前，Master的手法好熟练。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄布揉弄挺立的顶端，酥麻感让尾巴毛都要炸开了。", "emotion": "blush"},
                "high": {"text": "哈啊！胸前完全挺立发烫，猫猫的野性在您的掌心下彻底化作春水了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "探向短裙深处最隐秘的私密，Master，那里好害羞呀！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感的花蒂打圈揉按，两条尾巴忍不住死死缠住了您的手臂。", "emotion": "blush"},
                "high": {"text": "不行了！温热的花露把短裤完全浸透，好强烈的高潮，绮良良要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚摸有着肉垫触感的小腿与大腿内侧，手心的温度好舒服。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根被轻轻捏弄，擅长飞檐走壁的双腿竟然完全软掉了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿软绵绵地任由Master搬弄，完全变成属于您的专属猫娘了。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "摸到双尾分叉处特制的毛绒小塞子了，呜，那里太刺激了。", "emotion": "shy"},
                "mid": {"text": "唔！尾塞在紧致的深处被缓缓旋动，异样的充实感让猫猫忍不住娇声啼叫。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭完全失守了，狂暴甜美的浪潮让绮良良彻底失去理智啦！", "emotion": "climax"}
            }
        }
    },
    {
        "id": "ayaka",
        "name": "神里绫华",
        "title": "白鹭霜华",
        "region": "海岬小镇与神社",
        "spawn_id": "cape_ayaka",
        "dialogue_graph_id": "cape_ayaka_bundle",
        "dialogue_file": "dialogue/ayaka/cape_dialogue.json",
        "position": [648.411, 4.840, -1147.240],
        "heading": 131.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【室内侍奉】请绫华在住宅二层平整木地板上，为我提供白鹭公主的柔顺闺阁侍奉。",
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
                "id": "kamisato_art_hyouka",
                "name": "神里流·冰华落雪",
                "damage": 16.0,
                "text": "若知所爱，风定花残！以神里流纯正剑艺，检验Master的防守沉稳！",
                "emotion": "smile"
            },
            {
                "id": "kamisato_art_soumetsu",
                "name": "神里流·霜灭龙卷",
                "damage": 20.0,
                "text": "吹雪连翩，霜刃破晓！请接下绫华倾注全心的霜灭奥义！",
                "emotion": "confident"
            },
            {
                "id": "senho_elegance",
                "name": "雪步翩跹·折扇含羞",
                "damage": 15.0,
                "text": "折扇掩面，眼波微凝，绫华只愿与心仪之人共享此时此刻。",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "白鹭拂霜，心曲难诉。您好，Master。我是稻妻社奉行神里绫华。正在这座小镇二层的雅居内小憩赏景。若您需要神里家的支持与绫华的陪伴，请先与我进行一场切磋，检验彼此的信赖与默契吧！",
            "menu_prompt": "Master，今天寻绫华有何雅兴？无论茶道还是对弈，绫华皆乐意奉陪。",
            "lore_btn": "【关于雅居】在海岬小镇的二层室内歇息，感觉如何？",
            "lore": "这里居高临下，推开窗户便能望见海岬神社的鸟居与碧蓝浪涛。没有繁杂公文的打扰，能静下心来品茶看海，对绫华而言是难能可贵的心境。",
            "lore_btn_unlocked": "【关于窗侧】靠在窗边看海，神情很温柔呢。",
            "lore_unlocked": "只要Master在身旁，海风都会变得格外温润。每次走到窗前，就会想起被您揽入怀中轻解发带的场景，心跳便无法抑制。今后，绫华的身心皆任凭您支配。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请白鹭公主赐教！（初次对决：公主全力迎战）",
            "combat_btn_unlocked": "【身心对决】绫华，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，您又来探望绫华了。自从上次在切磋中败于您手，绫华的芳心早已系在您的身上。今天是要切磋剑艺，还是让白鹭公主为您提供闺阁侍奉？",
            "menu_prompt_unlocked": "主人，绫华是只属于您的白鹭，随时听凭您的吩咐。",
            "mid_locked": "Master，神里流剑意尚未穷尽，请集中精神攻过来！",
            "mid_unlocked": "哈啊，Master，绫华的手脚都已酸软无力，只要您开口，绫华皆顺从于您，",
            "distracted_cmd": "【命令识趣】绫华，稍微走神迎合一下，让我好好疼你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "既然是主人的吩咐，那绫华便散去护体冰霜，任由主人尽情怜爱，",
            "lock_cmd": "【快感保护】绫华，帮我稳固快感防线！（本回合快感上限 90%）",
            "lock_confirm": "冰华结界轻柔护佑在主人身侧，绫华会为您守住快感防线！",
            "endure_confirm": "好沉稳端庄的定力，真不愧是绫华所敬慕的主人！",
            "surrender_cmd": "【命令认输】别强撑了，绫华当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，绫华彻底认输，身子要绝顶了啊啊！",
            "victory": "哈啊，折扇滑落，是绫华彻底败给主人了。按照约定，神里绫华整个人任凭Master发落，您想怎么处置我？",
            "defeat": "看来今天的切磋是绫华侥幸占了上风呢，Master。先在榻榻米上稍事休整，品盏清茶，待会儿绫华再陪您练习！",
            "post_kill": "Master，刚才虽然将绫华当成战利品任意摆弄，但重塑身形之后，绫华的心意依然坚贞不渝。下一次，绫华依然会全身心服从于您！",
            "post_spare": "哈啊，刚才在地板上为您侍奉了那么久，和服下的双腿至今还在微微发烫呢。能让主人感到舒畅愉悦，便是绫华最大的幸福。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖拂过唇瓣，Master的举动教绫华心跳加速。", "emotion": "shy"},
                "mid": {"text": "唔，白鹭公主的娇唇被您温柔撬开，舌尖纠缠时的甘美让人难以自持。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的清润甜津溢出，高贵的仪态彻底化作了顺从的娇啼！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "隔着华美和服轻抚胸前，主人的手心好滚烫。", "emotion": "shy"},
                "mid": {"text": "呀！解开前襟直接捻弄挺拔的尖端，体内的冰霜仿佛瞬间融化。", "emotion": "blush"},
                "high": {"text": "哈啊！胸前挺立得发酸发胀，好强烈的快感，绫华快支撑不住了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "探向和服下摆深处最娇嫩的花蕾，Master的动作好大胆。", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂轻柔打圈按压，连双腿都忍不住羞怯地紧紧并拢了。", "emotion": "blush"},
                "high": {"text": "不行了！温热的花露将衬衣完全浸湿，好强烈的绝顶情浪，绫华要高潮了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚摸纯白高筒丝袜包裹的修长双腿，触感好生细腻。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根被轻轻捏弄，习练剑道的双腿竟然完全酸软化开了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿虚软无力，只能软软地倚靠在Master怀里任您索取。", "emotion": "climax"}
            },
            "anal": {
                "low": {"text": "摸到身后白鹭羽翼造型的温润小塞子，Master，那里好害羞呀。", "emotion": "shy"},
                "mid": {"text": "唔！尾塞在紧致的深处被缓缓旋动，从未体验过的深邃快美直冲心神。", "emotion": "blush"},
                "high": {"text": "呀啊！后庭完全失守了，狂暴甜美的震颤让白鹭公主的意识彻底空白啦！", "emotion": "climax"}
            }
        }
    }
]

def main():
    print(f"Generating Batch 2 assets for {len(NPC_SPECS)} NPCs: starting")
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

    print("Successfully generated all Batch 2 NPC assets!")

if __name__ == "__main__":
    main()
