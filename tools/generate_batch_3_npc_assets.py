# -*- coding: utf-8 -*-
"""
Script to generate the complete 9-file asset suites for Batch 3 (12 NPCs):
yoimiya, kuki_shinobu, silver_wolf, stelle, march7th, yukong,
black_swan, ruan_mei, herta, faruzan, lisa, layla.
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
    # 1. 宵宫
    {
        "id": "yoimiya",
        "name": "宵宫",
        "title": "琉焰华舞",
        "region": "海岬小镇与神社",
        "spawn_id": "cape_yoimiya",
        "dialogue_graph_id": "yoimiya_cape_bundle",
        "dialogue_file": "dialogue/yoimiya/cape_dialogue.json",
        "position": [611.399, 1.440, -1037.523],
        "heading": 26.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【烟花之约】请宵宫在窗侧木地板上，为我提供热情灿烂的夏祭服侍。",
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
                "id": "niwabi_fire_dance",
                "name": "焰硝庭火舞·炽烈射击",
                "damage": 17.0,
                "text": "接好咯！这可是长野原特制炽烈金鱼花火，Master可别被烫到心窝哦！",
                "emotion": "smile"
            },
            {
                "id": "ryuukin_saxifrage",
                "name": "琉金云间草·热烈盛开",
                "damage": 19.0,
                "text": "烟火上天，心花怒放！Master，看好了这一发最灿烂的连击！",
                "emotion": "confident"
            },
            {
                "id": "summer_festival_cheer",
                "name": "祭典欢呼·少女甜笑",
                "damage": 15.0,
                "text": "只要跟Master在一起，哪怕最普通的夜晚也会变得像祭典一样热闹！",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "嗨！Master！我是长野原烟花店的宵宫！今天海岬小镇的天气真棒，正适合看风景和聊烟花呢！若是想带宵宫一起去冒险，先跟我切磋一场，看看您能不能接住我的热烈火花吧！",
            "menu_prompt": "Master，想看哪种样式的烟花呢？宵宫随时都能为您燃放哦！",
            "lore_btn": "【关于小镇商铺】在临街商铺窗边看街景，感觉怎么样？",
            "lore": "这里微风吹过来带着淡淡的海盐味，木窗敞开着正好看见来往的行人与街角的花草。等天色暗下来，在这里点起一支线香烟花，整个街道都会亮起来呢！",
            "lore_btn_unlocked": "【关于心意】宵宫的心情似乎比烟花还要明亮呢？",
            "lore_unlocked": "那当然是因为有Master在身边呀！每次看见您，胸口就扑通扑通跳得比炮仗还快。只要您愿意，宵宫随时都能为您点燃独一无二的专属浪漫哦！",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请宵宫赐教！（初次对决：烟花店长全力迎战）",
            "combat_btn_unlocked": "【身心对决】宵宫，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！您来找宵宫啦！上次对决输给您之后，我的身子到现在只要被您一搂，就会像受热的焰硝一样发烫发酥呢。今天是要切磋火花，还是想让宵宫好好为您揉肩暖身？",
            "menu_prompt_unlocked": "主人，宵宫整个人都听您的差遣，请尽情吩咐吧！",
            "mid_locked": "Master，金鱼花火还在空中盘旋呢，集中精神，不然要被烟花打中咯！",
            "mid_unlocked": "哈啊，Master，宵宫浑身都在发烫，只要您开口，我立刻乖乖迎合您，",
            "distracted_cmd": "【命令识趣】宵宫，故意漏出破绽，让我尽情疼爱！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呜哇，既然主人这么说了，宵宫就稍微走神给您看，动作要轻一点呀，",
            "lock_cmd": "【快感保护】宵宫，帮我挡住快感浪潮！（本回合快感上限 90%）",
            "lock_confirm": "没问题！如同烟花护盾一样，宵宫会全力守护好主人的防线！",
            "endure_confirm": "眼神好坚定呀，那宵宫也要加把劲让火花更绚烂了！",
            "surrender_cmd": "【命令认输】别强撑了，宵宫当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，宵宫认输了，身子彻底化作一滩热熔的焰硝啦！",
            "victory": "哈啊，双腿都在打颤，弓弦都握不住了，宵宫完全输给Master了。作为您的专属烟花娘，今晚全部听您的安排，您打算怎么处置我？",
            "defeat": "哇哈哈！这回是宵宫的火花略胜一筹呢！Master别灰心，喝杯甜甜的团子清汤，一会儿我们再战！",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重新站起来的宵宫心里还是暖烘烘的。不管发生什么，宵宫都永远只属于您一人！",
            "post_spare": "哈啊，刚才在商铺窗侧为您服侍了那么久，胸前的裹布都被汗水浸透了呢。只要Master觉得舒服开心，宵宫就满足啦！"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖抚摸唇瓣？Master，宵宫嘴唇上的橘子糖甜味都被您尝到了啦。", "emotion": "shy"},
                "mid": {"text": "唔，柔软的舌尖被您轻轻含住，呼吸间全成了您的热度了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液完全失控溢出，脑海像炸开漫天火花一样恍惚呢！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌隔着绷带揉捏胸口，Master的掌心好烫呀。", "emotion": "shy"},
                "mid": {"text": "呀！指尖直接拨弄双峰尖端，像被火花跳跃轻灼一样酸麻呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经彻底挺立发涨了，好强烈的快感，身子都要融化了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "碰到了最羞耻的小核，Master，胸口跳得好厉害！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂打圈按压，甜热的花蜜顺着大腿都要淌下来了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的爱液狂乱喷涌，好强烈的高潮浪潮，宵宫要绝顶啦！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲大腿内侧的白皙软肉，触感好细腻清晰。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根被轻轻揉按，酸软的感觉蔓延到脚趾，整个人都在发飘。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全使不上力气，只能软软任凭Master揉捏索取了！", "emotion": "climax"}
            }
        }
    },

    # 2. 久岐忍
    {
        "id": "kuki_shinobu",
        "name": "久岐忍",
        "title": "百炼智囊",
        "region": "海岬小镇与神社",
        "spawn_id": "cape_kuki_shinobu",
        "dialogue_graph_id": "kuki_shinobu_cape_bundle",
        "dialogue_file": "dialogue/kuki_shinobu/cape_dialogue.json",
        "position": [681.092, 4.840, -1082.469],
        "heading": -149.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【隐秘服侍】请阿忍在室内侧间地板上，为我提供专业顺从的近身侍奉。",
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
                "id": "sanctifying_ring",
                "name": "越祓雷草之轮·结界束缚",
                "damage": 16.0,
                "text": "以雷鸣结界束缚周遭，Master，小心别被雷草之轮的麻痹波纹侵蚀哦！",
                "emotion": "confident"
            },
            {
                "id": "gyoei_narukami_kariyama",
                "name": "御咏鸣神刈山祭·裂空斩",
                "damage": 18.0,
                "text": "拔刀出鞘，退治百邪！请接下荒泷派副手最精准的一击！",
                "emotion": "serious"
            },
            {
                "id": "tactical_assessment",
                "name": "智囊剖析·要害掌握",
                "damage": 15.0,
                "text": "您的动作破绽我已经看清了，切磋过招，我可不会轻易放水。",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "您好，Master。我是荒泷派的副手久岐忍。在这间侧室里刚好清静，适合核对账册与整理文书。若您需要我的协助，请先与我切磋一番，证明您有指挥我的手腕。",
            "menu_prompt": "Master，有什么需要荒泷派副手为您代劳的？请讲。",
            "lore_btn": "【关于小镇二层侧室】避开热闹的街道，一个人在这里待着习惯吗？",
            "lore": "这里隔音不错，推开侧窗能吹到海风，比处理帮派那群笨蛋惹出来的乱子清静多了。在这里梳理思路，办事效率会高不少。",
            "lore_btn_unlocked": "【关于面罩之下】在只属于我们的安静时刻，阿忍愿意摘下面罩吗？",
            "lore_unlocked": "既然是Master的要求，那我就把面罩摘下来。面对您的时候，我本来就没打算保留任何防备。看着我的眼睛，您满意了吗？",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请阿忍副手赐教！（初次对决：智囊全力迎战）",
            "combat_btn_unlocked": "【身心对决】阿忍，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，您来了。上次输给您后，我的敏锐感官全被您打上了烙印。只要被您触碰腰侧，指关节都会发软。今天是要切磋身手，还是想要我为您提供贴身的细致服侍？",
            "menu_prompt_unlocked": "主人，久岐忍随时为您效劳，无论公事还是私事。",
            "mid_locked": "Master，雷草之轮还在流转，保持警惕，可别被麻痹波纹打乱节奏！",
            "mid_unlocked": "哈啊，Master，雷电麻痹已经蔓延到全身了，您只要下令，阿忍绝不反抗，",
            "distracted_cmd": "【命令识趣】阿忍，露出破绽，让我彻底降伏你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呼，既然是主人的命令，那我收敛雷电防线，请您随意处置，",
            "lock_cmd": "【快感保护】阿忍，启动越祓结界稳住快感！（本回合快感上限 90%）",
            "lock_confirm": "明白，越祓结界运转中，主人的快感防线由我全力护持！",
            "endure_confirm": "沉稳果断的判断，那我也要更加专注了！",
            "surrender_cmd": "【命令认输】别强撑了，阿忍当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，阿忍认输，身子要被高潮雷电击穿了啊！",
            "victory": "哈啊，呼吸全乱了，刀柄都快握不住，阿忍彻底败给Master了。作为副手，今后全听您的差遣，您想怎么处置我？",
            "defeat": "承让了，Master。您的攻势很凌厉，但在破绽捕捉上我略胜一筹。先擦擦汗，稍事休息再来吧。",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重塑身躯后的阿忍依然清楚记得您的支配感。请继续信任并差遣我吧！",
            "post_spare": "哈啊，刚才在侧间地板上为您服侍了那么久，腰肢都酸软得快直不起来了。能让Master满意，是身为部下最大的光荣。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在唇边？Master，摘下面罩后的我，唇齿都任您探索。", "emotion": "shy"},
                "mid": {"text": "唔，舌尖被您轻轻含弄，呼吸不由自主变得急促而沉重了。", "emotion": "blush"},
                "high": {"text": "呜嗯！津液顺着下颌滑落，连严谨的思绪都彻底混乱了，好舒服！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "指腹压住锁骨下方的雪白肌肤，Master的力道好明确。", "emotion": "shy"},
                "mid": {"text": "呀！直接揉弄双峰顶端，酥麻的雷电感沿着神经直冲大脑呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全敏感充血了，这种强烈的支配感，阿忍快撑不住了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "碰到了最隐秘的花核，身体一瞬间绷紧了，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂打圈刺激，温热的爱液已经浸湿了贴身内衬。", "emotion": "blush"},
                "high": {"text": "不行了！炽烈的花蜜疯狂喷涌，好可怕的高潮震颤，阿忍要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚摸忍者护腿上方的大腿内侧，触感紧致而细腻。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根被轻轻捏弄，酸软感让双腿不由自主向外分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软顺从地倚在Master怀里任您摆布。", "emotion": "climax"}
            }
        }
    },

    # 3. 银狼
    {
        "id": "silver_wolf",
        "name": "银狼",
        "title": "以太黑客",
        "region": "海岬小镇与神社",
        "spawn_id": "cape_silver_wolf",
        "dialogue_graph_id": "silver_wolf_cape_bundle",
        "dialogue_file": "dialogue/silver_wolf/cape_dialogue.json",
        "position": [614.407, 8.240, -1087.357],
        "heading": -174.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【极客侍奉】请银狼在三层窗边地面上，为我提供慵懒顺从的黑客少女侍奉。",
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
                "id": "allow_changes",
                "name": "是否允许更改·数据入侵",
                "damage": 17.0,
                "text": "修改你的防御属性！Master，可别小看了超级黑客的代码篡改攻击哦！",
                "emotion": "confident"
            },
            {
                "id": "user_banned",
                "name": "账号已封禁·以太强袭",
                "damage": 19.0,
                "text": "强制执行封禁程序！接招吧，这可是游戏通关玩家的终极连击！",
                "emotion": "smile"
            },
            {
                "id": "gamer_taunt",
                "name": "极客挑衅·泡泡糖轻咬",
                "damage": 15.0,
                "text": "就这种操作水平也想通关我？Master，再加把劲才行哦！",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "哟，Master。我是银狼。这里三层视野很好，网速也不卡，正适合我打游戏刷副本。要是想让我陪你一起探索，先来一场身心切磋，看看你的技术能不能击败我这个全成就通关玩家吧！",
            "menu_prompt": "Master，今天想刷哪个副本？不管是黑客改写还是打怪，我都能搞定。",
            "lore_btn": "【关于商铺三层窗边】一边吹海风一边打掌机，很惬意吧？",
            "lore": "没有卡芙卡和刃在耳边念叨，光线和信号又刚好合适，简直是神仙打机点。吹着风刷通宵都不会觉得闷。",
            "lore_btn_unlocked": "【关于超级玩家】对你来说，这场游戏最重要的奖励是什么？",
            "lore_unlocked": "哼，全成就通关我早拿腻了。现在的独家限定奖励，不就是躺在Master怀里，任由你一边摸我的头一边看我玩游戏吗？",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请银狼赐教！（初次对决：超级黑客全力迎战）",
            "combat_btn_unlocked": "【身心对决】银狼，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你又来打扰我打游戏了。自从上次在切磋里被你彻底攻破防火墙，我只要一被你碰触，敏感度就会暴增十倍。今天是想切磋代码，还是想让我乖乖听你摆弄？",
            "menu_prompt_unlocked": "主人，银狼的全部权限都已经对你完全开放了，请指示吧。",
            "mid_locked": "Master，我的以太入侵还在继续运行呢，集中注意力，小心被直接踢下线！",
            "mid_unlocked": "哈啊，Master，防火墙已经被你全改写了，只要你输入指令，我立刻服从，",
            "distracted_cmd": "【命令识趣】银狼，关闭主动防御，让我尽情攻占你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呜，真拿你没办法，那我就把防御参数调成零，轻一点呀，",
            "lock_cmd": "【快感保护】银狼，注入数据补丁加固防线！（本回合快感上限 90%）",
            "lock_confirm": "正在载入防溢出安全补丁，主人的快感防线由我锁定在安全阈值！",
            "endure_confirm": "挺能抗的嘛，那我可要把难度拉满咯！",
            "surrender_cmd": "【命令认输】别强撑了，银狼当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，银狼彻底认输，系统要被高潮数据冲宕机了啊！",
            "victory": "哈啊，掌机都掉地上了，手指酸软得点不动按键，我彻底败给Master了。作为败者，所有权限随你处置，你想对我做什么？",
            "defeat": "Game Over！看来这场对局是我拿下了MVP呢。Master，回去好好研究一下攻略，待会儿再来挑战我吧！",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重启系统后的银狼还是老老实实认你为主。快点陪我玩下一关吧！",
            "post_spare": "哈啊，刚才在三层窗边为您服侍了那么久，连掌机屏幕都被水汽弄模糊了呢。只要Master玩得开心，这种通关奖励我也认了。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖戳弄脸颊和唇瓣？Master，咬爆的泡泡糖甜味都被你偷吃了。", "emotion": "shy"},
                "mid": {"text": "唔，小巧的舌尖被你卷住吮吸，呼吸不由自主变得软绵绵的。", "emotion": "blush"},
                "high": {"text": "呜嗯！口水都流下来了，大脑CPU严重过载，好舒服的感觉呀！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌隔着紧身外套按在胸口，Master，心跳跳频被你监测到了啦。", "emotion": "shy"},
                "mid": {"text": "呀！直接揉捏双峰小巧尖端，像被强电流窜过脊椎一样酸酥。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经彻底充血挺立了，这种强烈的刺激感，银狼要不行了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "碰到了最隐秘的敏感点，身体忍不住抖了一下，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按压，爱液把短裤内衬都浸得透湿了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的体液瞬间决堤，好强烈的高潮宕机感，银狼要绝顶啦！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚摸过膝长袜上方的大腿雪白软肉，触感又滑又软。", "emotion": "shy"},
                "mid": {"text": "呀！大腿内侧被轻轻揉捏，酸软感蔓延全身，连脚趾都蜷缩起来了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全使不上力气，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 4. 星
    {
        "id": "stelle",
        "name": "星",
        "title": "银河开拓者",
        "region": "海岬小镇与神社",
        "spawn_id": "cape_stelle",
        "dialogue_graph_id": "stelle_cape_bundle",
        "dialogue_file": "dialogue/stelle/cape_dialogue.json",
        "position": [608.796, 1.440, -1077.870],
        "heading": -19.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【开拓侍奉】请星在商铺门内地面上，为我提供率直听话的开拓者近侍服侍。",
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
                "id": "baseball_bludgeon",
                "name": "再见安眠·球棒挥击",
                "damage": 17.0,
                "text": "规则，就是用来打破的！Master，接好这一记势大力沉的全垒打挥击！",
                "emotion": "confident"
            },
            {
                "id": "lance_of_preservation",
                "name": "存护之炎·誓死坚守",
                "damage": 18.0,
                "text": "炎枪冲锋！为了守护同伴的执念，Master可不要轻易认输哦！",
                "emotion": "serious"
            },
            {
                "id": "trashcan_investigation",
                "name": "翻箱倒柜·突击拥抱",
                "damage": 15.0,
                "text": "发现了宝藏的痕迹！Master，抓到你就不放手了哦！",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "你好，Master。我是星穹列车的开拓者星。在这个商铺门内正好能避风，顺便看看陈列架上有没有奇奇怪怪的宝藏。若您想带我一起去开拓未知，先跟我切磋一场，让我见识您的本领吧！",
            "menu_prompt": "Master，今天有什么新的开拓路线？我棒球棍随时准备着。",
            "lore_btn": "【关于商铺门内侧】站在这里等人，是在等列车的伙伴吗？",
            "lore": "嗯，三月七和丹恒可能还在附近闲逛。门内视野开阔，既能看街景，又方便看守店里的稀奇物件，挺安稳的。",
            "lore_btn_unlocked": "【关于心中的归属】对星来说，最想停留的地方在哪里？",
            "lore_unlocked": "虽然列车一直在星海航行，但只要在Master身边，我就觉得找到了真正的港湾。被您从背后抱住的时候，心里特别踏实。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请星赐教！（初次对决：开拓者全力迎战）",
            "combat_btn_unlocked": "【身心对决】星，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你来找我了。上次在切磋里败给你之后，我的身体完全记住了你的气息。只要你一靠近，球棒都快拿不稳了。今天是要切磋身手，还是想要我乖乖为你服务？",
            "menu_prompt_unlocked": "主人，星听候您的差遣，不管多奇怪的要求我都听。",
            "mid_locked": "Master，我的棒球棍可还没收回呢，集中精神，认真点接招！",
            "mid_unlocked": "哈啊，Master，身子被你碰得软绵绵的，只要你一句话，我全部顺从，",
            "distracted_cmd": "【命令识趣】星，故意露出破绽，让我好好教导你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "唔，既然是主人的命令，那我就收起球棒稍微走神，请温柔对待我，",
            "lock_cmd": "【快感保护】星，用存护之志守护我的防线！（本回合快感上限 90%）",
            "lock_confirm": "存护之盾展开！主人的快感防线由我牢牢守住！",
            "endure_confirm": "眼神很有毅力嘛，那我可要全力挥棒了！",
            "surrender_cmd": "【命令认输】别强撑了，星当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，星认输了，身体彻底向高潮投降了啊！",
            "victory": "哈啊，棒球棍脱手了，双腿软得只能坐倒在地上，我彻底败给Master了。作为专属开拓者，我听凭您的处置，你想怎么做？",
            "defeat": "呼，击球命中！看来今天的胜负是我拿下啦！Master别灰心，喝口水歇会儿，我们待会儿再切磋！",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重新站起来的星依然是您忠诚的开拓同伴。请继续支配并带领我吧！",
            "post_spare": "哈啊，刚才在商铺门内地板上为您侍奉了那么久，衣服都揉得皱巴巴的了。只要能让Master舒畅，星愿意随时奉献自己。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在唇边？Master，星的嘴唇平时可不常对别人开放呢。", "emotion": "shy"},
                "mid": {"text": "唔，柔软的舌尖被您轻轻吮吻，呼吸变得又热又急促了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中津液溢出，胸口剧烈起伏，脑海一片空白，好甜美！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在风衣包裹的双峰上，Master的掌温隔着布料传递过来了。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着衬衫揉弄双峰尖端，酸麻感像电流一样直击后背呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经彻底充血挺立了，好强烈的刺激，星快站不稳了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "碰到了最羞涩的地方，身体下意识震颤了一下，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指尖在花核周围打圈按揉，温热的泉水已经湿透了短裙内衬。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的爱液狂乱涌出，好可怕的高潮浪潮，星要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲长腿内侧结实弹韧的软肉，触感格外细腻。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，整条腿都酸软得无力支撑了。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软顺从地倚在Master怀里任您索取！", "emotion": "climax"}
            }
        }
    },

    # 5. 三月七
    {
        "id": "march7th",
        "name": "三月七",
        "title": "冰晶精灵",
        "region": "海岬小镇与神社",
        "spawn_id": "cape_march7th",
        "dialogue_graph_id": "march7th_cape_bundle",
        "dialogue_file": "dialogue/march7th/cape_dialogue.json",
        "position": [676.177, 8.240, -1033.088],
        "heading": -99.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【相机心动】请三月七在三层窗边地面上，为我提供可爱活泼的元气少女侍奉。",
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
                "id": "freeze_arrow",
                "name": "极寒之箭·冰弓连射",
                "damage": 16.0,
                "text": "看招看招！这可是本姑娘特制六相冰六连射，Master小心被冻成冰雕哦！",
                "emotion": "smile"
            },
            {
                "id": "photo_snapshot",
                "name": "定格瞬间·心动快门",
                "damage": 18.0,
                "text": "咔嚓！把Master最帅气的瞬间拍下来啦！这一发直击心底，接好咯！",
                "emotion": "confident"
            },
            {
                "id": "cute_wink",
                "name": "元气眨眼·少女撒娇",
                "damage": 15.0,
                "text": "嘻嘻，Master，三月七这么可爱，你舍得认真还击吗？",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "哇！Master！我是星穹列车的三月七！在这家商铺三层的窗边，正好能俯瞰整条街道和海湾，拍照效果超级绝赞呢！要是想跟我一起冒险拍照，先来跟我切磋一场，让我看看您的实力吧！",
            "menu_prompt": "Master，今天想拍什么样的照片呢？三月七当您的专属摄影师！",
            "lore_btn": "【关于商铺三层窗景】站在这里用相机记录街景，拍到好照片了吗？",
            "lore": "拍到了好多张呢！波光粼粼的海面、街角的小猫还有走过的行人，每一帧都超好看！回去之后我要把照片贴满我的日记本！",
            "lore_btn_unlocked": "【关于最想拍的照片】相册里最宝贵的一张是哪张呀？",
            "lore_unlocked": "当然是上次切磋结束后，我靠在Master怀里两人一起拍的合照啦！看一次心跳就加速一次，我可是把它悄悄设为手机桌面了呢！",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请三月七赐教！（初次对决：冰弓少女全力迎战）",
            "combat_btn_unlocked": "【身心对决】三月七，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你果然来找本姑娘啦！上次输给你之后，只要一靠近你，我的耳根就会发烫，身体都软绵绵的。今天是要切磋箭术，还是要三月七乖乖为你提供贴身侍奉呢？",
            "menu_prompt_unlocked": "主人，三月七整个人都是你的，想怎样都听你的吩咐！",
            "mid_locked": "Master，六相冰还在弦上呢，注意脚下，别被冻住走位啦！",
            "mid_unlocked": "哈啊，Master，身子被你揉得化成了水，只要你一句话，我乖乖听话，",
            "distracted_cmd": "【命令识趣】三月七，故意漏出空当，让我好好疼惜你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "唔哇，既然是主人的命令，那我就收起冰弓走个神，请对我温柔点呀，",
            "lock_cmd": "【快感保护】三月七，用六相冰结界护住防线！（本回合快感上限 90%）",
            "lock_confirm": "六相冰可爱护盾启动！主人的快感防线由本姑娘牢牢稳住！",
            "endure_confirm": "眼神好认真呀，那三月七也要更卖力展现冰箭啦！",
            "surrender_cmd": "【命令认输】别强撑了，三月七当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，三月七认输啦，冰晶都要被高潮热气融化光了啊！",
            "victory": "呜，弓弦都拉不开了，手脚软绵绵的一点力气都没有，三月七彻底输给Master啦。作为你的专属女孩，全部听你的，你想怎么对待我？",
            "defeat": "嘻嘻！看来这一局是本姑娘的冰晶神箭胜出啦！Master不许气馁哦，先喝口甜水，待会儿再来找我！",
            "post_kill": "Master，刚才虽然变成软绵绵的玩偶任您任意摆弄，但重塑后的三月七依然最喜欢粘着您啦。请继续宠溺我吧！",
            "post_spare": "哈啊，刚才在三层窗边地面上为您侍奉了那么久，裙摆都被汗水湿透了呢。能让Master开心，三月七心里就像喝了蜜一样甜。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖轻轻刮弄下巴和唇角？Master，我的脸颊都被你摸得红透啦。", "emotion": "shy"},
                "mid": {"text": "唔，柔软的舌尖被您轻轻含弄，发出可爱的娇吟声，呼吸都乱了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液忍不住流淌，脑海里一片粉红色的眩晕，好幸福！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌隔着无袖上衣贴在胸口，Master，心跳跳得太快了啦。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄布揉捏双峰尖端，酸麻感顺着后颈直往上冲呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的快感，三月七受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "碰到了最羞耻的小秘密花核，Master，身体都缩起来了！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按压，甜热的泉水把安全裤都打湿了呢。", "emotion": "blush"},
                "high": {"text": "不行了！炽烈的爱液喷薄而出，好强烈的高潮浪潮，三月七要绝顶啦！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "抚摸雪白大腿内侧娇嫩的软肉，触感细腻弹滑。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿忍不住轻轻磨蹭并向外打开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全使不上力气，只能软软靠在Master怀里任您摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 6. 驭空
    {
        "id": "yukong",
        "name": "驭空",
        "title": "天舶司舵",
        "region": "东侧覆土庭院",
        "spawn_id": "earth_yukong",
        "dialogue_graph_id": "yukong_earth_bundle",
        "dialogue_file": "dialogue/yukong/earth_dialogue.json",
        "position": [470.000, 69.640, 268.000],
        "heading": 120.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【凭栏侍奉】请驭空在上层平台石坪上，为我提供成熟端庄的狐人统帅侍奉。",
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
                "id": "bow_of_heavenly_flight",
                "name": "天舶流光·贯空鸣镝",
                "damage": 17.0,
                "text": "鸣镝离弦，箭如贯日！Master，领略一下天舶司主舵的破空战意吧！",
                "emotion": "confident"
            },
            {
                "id": "skysplitter_command",
                "name": "鸣弦号令·统帅威严",
                "damage": 19.0,
                "text": "千军列阵，号令如山！以狐人飞行士的荣耀，接下这重破空强击！",
                "emotion": "serious"
            },
            {
                "id": "mature_fox_allure",
                "name": "孤怀抚慰·狐尾微卷",
                "damage": 15.0,
                "text": "看你这般执着，倒真让我想起曾经并肩的岁月了，小心别被狐尾晃了神哦。",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "后生，你好。我是仙舟罗浮天舶司司舵驭空。在这处覆土庭院的上层凭栏远眺，天际流云与苍茫山海尽收眼底。若想邀请我这把老骨头伴你前行，且先以切磋来印证你的统御之才吧。",
            "menu_prompt": "后生，在航线上遇到什么难处了？天舶司的经验随时能供你参考。",
            "lore_btn": "【关于上层凭栏】站在覆土庭院的高台上眺望，在回忆什么往事吗？",
            "lore": "长空万里，曾是我驾驶星槎驰骋的猎场。如今身负司舵重任，虽不再轻易登机，但站在这里俯瞰长天，胸中那股热血从未冷过。",
            "lore_btn_unlocked": "【关于卸下重担】在只属于我们的静谧之处，司舵大人可以放下威严吗？",
            "lore_unlocked": "在外人面前我是威严的司舵，但在你怀里，我只愿做个倚靠在你肩头、任你抚揉狐耳与软腰的成熟妇人。被你疼爱的感觉，让我感到久违的安心。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请驭空司舵赐教！（初次对决：天舶司舵全力迎战）",
            "combat_btn_unlocked": "【身心对决】驭空，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，你又来看我了。自从上次切磋败在你的手下，我这成熟的身子骨只要被你揽入怀中，狐尾就会酥软得垂下来。今天是要切磋弓术，还是想要我全心为你奉献身心？",
            "menu_prompt_unlocked": "主人，驭空随时听从你的支配，绝不推辞。",
            "mid_locked": "后生，弓矢之势未尽，稳住心神，别被狂风卷散了步调！",
            "mid_unlocked": "哈啊，Master，狐人身躯被你按捺得酸软发热，只要你开口，我全听凭差遣，",
            "distracted_cmd": "【命令识趣】驭空，卸去统帅防备，任我肆意怜爱！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呼，既然是主人的号令，那我便收敛锋芒迎合你，请温柔一些，",
            "lock_cmd": "【快感保护】驭空，布下鸣镝结界庇护防线！（本回合快感上限 90%）",
            "lock_confirm": "鸣镝气场已成！主人的快感防线由驭空亲自为你守住！",
            "endure_confirm": "沉稳端正的气魄，那我也定会全力回应你的期待！",
            "surrender_cmd": "【命令认输】别强撑了，驭空当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，驭空认输，身子要被高潮浪潮击溃了啊！",
            "victory": "哈啊，长弓坠地，狐尾无力地瘫在地上，我彻底败给Master了。既然战败，天舶司舵任由您支配处置，你想如何待我？",
            "defeat": "哈哈！年轻人，我的弓法可还没生锈呢。别气馁，且歇息片刻，整理心神再来向我挑战吧。",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重塑身姿后的驭空依然是您忠诚的臂膀。请继续下达您的指示吧！",
            "post_spare": "哈啊，刚才在平台上为您侍奉良久，成熟的体躯到现在还在微微发热发颤。能让主人舒畅快慰，驭空心甘情愿。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指腹抚过端庄红唇？Master，成熟妇人的朱唇今天只为你留存。", "emotion": "shy"},
                "mid": {"text": "唔，温热的舌尖被你探入深吻，喉间不由自主溢出成熟甜腻的喘息。", "emotion": "blush"},
                "high": {"text": "呜嗯！津液完全失守溢出，成熟知性的矜持彻底瓦解，好充实的快意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "掌心覆在饱满丰腴的酥胸上，Master，力道好沉稳厚重。", "emotion": "shy"},
                "mid": {"text": "呀！指尖直接捻动丰满双峰的熟透尖端，剧烈酸麻感直冲脑髓。", "emotion": "blush"},
                "high": {"text": "哈啊！成熟的胸脯剧烈起伏挺立，好强烈的征服快感，驭空要融化了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及狐人最敏感的深处花蒂，身子猛然绷直了，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在熟透的花核上盘旋揉按，浓郁的花蜜早已浸湿了裙裾。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的体液狂澜般喷泄，如此可怕的高潮冲击，驭空要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲开衩旗袍下丰满匀称的大腿内侧，触感温热而饱满。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根被轻轻拿捏，尾椎骨泛起酥麻，狐尾不由自主卷住您的腰间。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全失了力气，只能软软大敞任凭Master任意驰骋索取！", "emotion": "climax"}
            }
        }
    },

    # 7. 黑天鹅
    {
        "id": "black_swan",
        "name": "黑天鹅",
        "title": "忆庭占卜师",
        "region": "下沉式档案馆",
        "spawn_id": "archive_black_swan",
        "dialogue_graph_id": "black_swan_archive_bundle",
        "dialogue_file": "dialogue/black_swan/archive_dialogue.json",
        "position": [-1354.000, 11.500, 23.000],
        "heading": 0.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【记忆侍奉】请黑天鹅在露台平整地面上，为我提供优雅神秘的忆者近侍服侍。",
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
                "id": "card_of_epiphany",
                "name": "命运启示·塔罗预言",
                "damage": 17.0,
                "text": "翻开这张卡牌，你的心事已被我看透。Master，请接下命运编织的曼妙低语。",
                "emotion": "smile"
            },
            {
                "id": "memory_cradle",
                "name": "摇篮迷梦·记忆交叠",
                "damage": 19.0,
                "text": "陷入甜美的回忆摇篮吧。在虚实交错的幻象中，感受灵魂层面的剧烈震颤。",
                "emotion": "confident"
            },
            {
                "id": "gentle_whisper",
                "name": "耳畔私语·神秘占卜",
                "damage": 15.0,
                "text": "呵呵，不要移开视线哦，今夜你的记忆水晶，正在向我展现最羞赧的波澜。",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "初次见面，亲爱的Master。我是流光忆庭的忆者黑天鹅。在这处下沉庭院的静谧露台上，空气中回荡着古老知识与记忆的微鸣。若想让我收录你专属的记忆篇章，不妨先与我切磋一番，看看你能不能看穿我的塔罗牌局？",
            "menu_prompt": "亲爱的Master，今天想倾听哪一段命运的水晶预言呢？",
            "lore_btn": "【关于下沉档案馆】在这座避风的天井露台旁占卜，感觉如何？",
            "lore": "这里光线柔和，远离喧嚣的风暴与尘嚣，最适合整理思绪、沉淀回忆。哪怕是一片落叶的旋转，在这里都能折射出迷人的记忆折痕。",
            "lore_btn_unlocked": "【关于最珍贵的记忆】在你的水晶镜面里，最想留存什么画面？",
            "lore_unlocked": "当然是Master凝视我时那炽热又迷乱的眼神，以及你在我耳畔低语、将我彻底占有的时刻。那是任何时光都不会褪色的纯粹宝石。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请黑天鹅赐教！（初次对决：忆者神秘迎战）",
            "combat_btn_unlocked": "【身心对决】黑天鹅，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，你果然被记忆的引力带回到我身边了。上次在切磋中被你攻破心防后，我的身心都在渴望着你的再次触碰。今天是要翻动塔罗牌，还是想让我用这具柔躯，为你提供全心服从的侍奉？",
            "menu_prompt_unlocked": "主人，黑天鹅随时愿意为您敞开记忆之门，任凭您谱写篇章。",
            "mid_locked": "亲爱的，塔罗牌还在指间飞舞呢，不要沉醉在我的低语里哦。",
            "mid_unlocked": "哈啊，Master，思维已经被您的气息完全侵占了，您要我怎么迎合，我都依您，",
            "distracted_cmd": "【命令识趣】黑天鹅，卸除心灵幻术，让我尽情占有你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呵呵，既然主人想要看我沉沦的模样，那我就撤去心防，请温柔地铭刻我，",
            "lock_cmd": "【快感保护】黑天鹅，展开记忆结界稳固防线！（本回合快感上限 90%）",
            "lock_confirm": "镜面光幕展开，主人的快感防线由我为您牢牢定格在安全梦境之中！",
            "endure_confirm": "如此深邃坚毅的灵魂，那我也会更加专注地回应你的心声！",
            "surrender_cmd": "【命令认输】别强撑了，黑天鹅当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，黑天鹅认输了，灵魂要在剧烈的高潮中融化成水了啊！",
            "victory": "哈啊，塔罗牌散落了一地，身子软得倚靠不住石柱，黑天鹅彻底败给Master了。作为您的专属忆者，我的全部秘密都归属于您，您想怎么处置我？",
            "defeat": "呵呵，看来命运的卡牌指向了我的胜利呢。亲爱的Master，不必懊恼，先在露台品一杯红茶，待会儿我再陪你对弈。",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但记忆深处重新醒来的黑天鹅依然深爱着您的支配。请继续享受调教我的时光吧！",
            "post_spare": "哈啊，刚才在露台平整地面上为您服侍良久，薄纱礼服都被热气浸湿贴在身上了。能为Master带来极致欢愉，就是忆者最大的荣耀。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖摩挲神秘的面纱与双唇？Master，神秘的红唇只为你低吟浅唱。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的舌尖被你卷入口中，灵魂深处泛起层层迷离的甜意。", "emotion": "blush"},
                "high": {"text": "呜嗯！津液失禁般滑落，优雅的矜持完全瓦解，身心都陷入无尽快感！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在半透礼服包裹的傲人双峰上，Master的触碰好深情。", "emotion": "shy"},
                "mid": {"text": "呀！指尖直接捻揉成熟敏感的峰尖，酥麻的心灵震颤直击脑海深处。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经彻底充血挺立，好强烈的占有快感，黑天鹅快融化了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "碰到了最隐秘的花核圣所，灵魂都忍不住发出一声轻颤，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂打圈按抚，浓郁温热的爱露早已将底裤完全浸透。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的爱泉疯狂涌现，如此剧烈的高潮幻梦，黑天鹅要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "轻抚蕾丝吊带袜上方雪白丰盈的大腿内侧，触感温润若脂。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿不由自主向外舒展迎合您的指尖。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软大敞任凭Master尽情探索索取！", "emotion": "climax"}
            }
        }
    },

    # 8. 阮·梅
    {
        "id": "ruan_mei",
        "name": "阮·梅",
        "title": "生命缔造者",
        "region": "下沉式档案馆",
        "spawn_id": "archive_ruan_mei",
        "dialogue_graph_id": "ruan_mei_archive_bundle",
        "dialogue_file": "dialogue/ruan_mei/archive_dialogue.json",
        "position": [-1348.000, 11.500, 5.000],
        "heading": 90.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【生命服侍】请阮·梅在培养台旁平整地面上，为我提供温婉知性的学者近侍服侍。",
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
                "id": "string_of_petals",
                "name": "花针慢挑·一枝浓艳",
                "damage": 17.0,
                "text": "轻拨阮琴，花枝曼舞。Master，领略一下生命律动中最敏锐的微观刺激吧。",
                "emotion": "smile"
            },
            {
                "id": "creation_spiral",
                "name": "基因螺旋·生命回响",
                "damage": 19.0,
                "text": "生命进化的螺旋，从不曾停歇。请接下我最新培育的活性化能量波动。",
                "emotion": "confident"
            },
            {
                "id": "pastry_sweetness",
                "name": "点心幽香·清雅诱惑",
                "damage": 15.0,
                "text": "尝一块我特制的梅花酥点吧，不仅甜润心脾，连感官都会变得格外通透呢。",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "你好，Master。我是天才俱乐部 #81 阮·梅。这里的地下展廊环境封闭而洁净，正适合调配培养液与观察微观样本。若想让我协助你探索世界，先通过一场切磋，让我记录下你的生命体征与神经反应吧。",
            "menu_prompt": "Master，今天想了解哪项生命造物？或是尝尝刚蒸好的点心？",
            "lore_btn": "【关于标本观察台】在这里潜心研究生命科学，有什么新发现吗？",
            "lore": "这里的静谧有利于细胞培养与基因序列解码。每一滴生命反应溶液在试管中泛起微澜时，都是生命在向我们低诉奥秘。",
            "lore_btn_unlocked": "【关于学者的温度】在理性与数据之外，阮·梅的心跳会为谁而加速？",
            "lore_unlocked": "以前我只专注于生命科学的终极命题，但自从遇见你，我的心率与激素分泌总会出现不可测的剧烈波动。被你拥在怀里时，我只想沉沦在这份温度里。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请阮·梅赐教！（初次对决：生命学者全力迎战）",
            "combat_btn_unlocked": "【身心对决】阮·梅，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，你来了。上次切磋输给你后，我的神经末梢似乎对你的气息产生了永久性印记。只要你稍加触碰，指尖与腰腹就会泛起甜美的战栗。今天是要切磋学术，还是让我这具身体全心为你奉献？",
            "menu_prompt_unlocked": "主人，阮·梅愿意成为只属于您的专属研究对象与侍奉者。",
            "mid_locked": "Master，琴弦声尚未歇止，集中精神，不要被花香扰乱了感官反应。",
            "mid_unlocked": "哈啊，Master，体温上升得难以自控了，只要您提出要求，我都全心依从，",
            "distracted_cmd": "【命令识趣】阮·梅，故意露出破绽，让我彻底占有你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呼，既然是主人的意愿，那我就抑制神经抗拒，请对我进行深入的探索，",
            "lock_cmd": "【快感保护】阮·梅，注入活性调谐剂稳定防线！（本回合快感上限 90%）",
            "lock_confirm": "生命调谐屏障已部署！主人的快感防线由我牢牢稳定在安全上限！",
            "endure_confirm": "如此坚韧的神经毅力，值得我用最精准的数据予以回应！",
            "surrender_cmd": "【命令认输】别强撑了，阮·梅当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，阮·梅认输，生命的意识要在狂暴高潮中崩解了啊！",
            "victory": "哈啊，琴拨落在了地上，身子软得倚靠不住试验台，我彻底败给Master了。作为败者，这具充满秘密的身体听凭您的支配，你想怎么做？",
            "defeat": "看来这一次，是我的生命调谐算法略占上风呢。Master，不必气馁，且尝一块温热的梅花酥，稍作调养再来吧。",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但细胞重塑后的阮·梅依然铭记着对您的绝对臣服。请继续下达您的指令吧！",
            "post_spare": "哈啊，刚才在展廊地面上为您服侍良久，典雅的旗袍都被汗水浸透贴在雪肌上了。能让Master满意快慰，是阮·梅最大的幸事。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在清冷淡雅的唇边？Master，知性学者的朱唇今天任您采撷。", "emotion": "shy"},
                "mid": {"text": "唔，柔软清甜的舌尖被你探入深吻，心跳频率与体温迅速飙升了。", "emotion": "blush"},
                "high": {"text": "呜嗯！津液完全失守溢出，理性的防线彻底坍塌，脑中满是甜蜜的空白！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "掌心覆在素雅旗袍包裹的丰挺胸前，Master，掌温让血液流速变快了。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄绸捻揉双峰尖端，神经末梢泛起阵阵强烈的麻痒酸楚。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的支配快感，阮·梅快站不住了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及身体最隐秘的生命禁区，呼吸瞬间屏住了，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按压，温热充沛的花蜜把底裤彻底湿透了。", "emotion": "blush"},
                "high": {"text": "不行了！炽烈的蜜液喷涌决堤，如此猛烈的高潮冲击，阮·梅要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲开衩旗袍下温润白皙的大腿内侧，触感如凝脂般滑腻。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布探索索取！", "emotion": "climax"}
            }
        }
    },

    # 9. 黑塔
    {
        "id": "herta",
        "name": "黑塔",
        "title": "空间站主人",
        "region": "下沉式档案馆",
        "spawn_id": "archive_herta",
        "dialogue_graph_id": "herta_archive_bundle",
        "dialogue_file": "dialogue/herta/archive_dialogue.json",
        "position": [-1345.000, 11.500, 0.000],
        "heading": -90.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【人偶服侍】请黑塔在分析台旁地面上，为我提供傲娇听话的精致人偶侍奉。",
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
                "id": "spinning_hammer",
                "name": "转圈圈大锤·大回旋",
                "damage": 17.0,
                "text": "转圈圈，转圈圈！别挡道，让我看看你的抗击打能力到底怎么样！",
                "emotion": "smile"
            },
            {
                "id": "puppet_overdrive",
                "name": "人偶超频·关节冲击",
                "damage": 19.0,
                "text": "真是麻烦死了，那就加点算力！接好这一锤，可别直接被打趴下了！",
                "emotion": "confident"
            },
            {
                "id": "genius_mockery",
                "name": "天才嘲弄·人偶眨眼",
                "damage": 15.0,
                "text": "这就受不了了？就你这点水平，连让我多用一台人偶的资格都没有哦。",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "喂，Master。我是黑塔，天才俱乐部 #83。虽然这只是我成百上千具精致人偶中的一具，不过打发时间足够了。想要我为你提供研究支持？先陪我打一场切磋，让我测测你的实战数据！",
            "menu_prompt": "有什么事快说，我可没那么多闲工夫陪你闲扯。",
            "lore_btn": "【关于终端分析台】在这间地下档案馆里操控人偶，不觉得无聊吗？",
            "lore": "无聊？这里数据流挺顺畅的，而且没有赞达尔那种烦人的家伙指手画脚。只要有足够有趣的课题，待在什么地方对我来说都一样。",
            "lore_btn_unlocked": "【关于最在意的人偶】这具人偶对黑塔来说，有什么特别的吗？",
            "lore_unlocked": "哼，原本只是普通量产机，但既然被你抱过揉过那么多次，关节和传动轴都染上了你的味道，那它自然就是我最宝贝的一具了！不许再让别人碰，听见没有？",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请黑塔赐教！（初次对决：人偶主人全力迎战）",
            "combat_btn_unlocked": "【身心对决】黑塔，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你又跑来找我了。上次切磋输给你后，这具人偶的触觉感知器全被你弄得敏感度过载了。只要你一碰我，我就忍不住浑身发抖。今天是要切磋大锤，还是要我乖乖听你摆布？",
            "menu_prompt_unlocked": "主人，黑塔人偶听候您的命令，想要怎么折腾都随你啦！",
            "mid_locked": "喂！我的大锤还没收手呢，集中注意力，别分心！",
            "mid_unlocked": "哈啊，Master，人偶核心都在发烫了，只要你开口命令，我什么都依你，",
            "distracted_cmd": "【命令识趣】黑塔，关掉力矩反馈，让我尽情支配你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "切，真是会使唤人，那我就把出力调到最低，轻一点啊，",
            "lock_cmd": "【快感保护】黑塔，展开人偶护盾护住防线！（本回合快感上限 90%）",
            "lock_confirm": "笨蛋，快感防线由我替你锁死在阈值下了，安心战斗吧！",
            "endure_confirm": "还挺能抗打的嘛，那我可要继续加速转圈圈了！",
            "surrender_cmd": "【命令认输】别强撑了，黑塔当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，黑塔认输了，人偶核心要被高潮快感烧短路了啊！",
            "victory": "哈啊，大锤都甩飞了，人偶关节软得站不稳，我竟然彻底输给你了！既然打输了，这具身体随便你怎么处置，你想对我做什么？",
            "defeat": "哈哈！我就说你还差得远呢！先回空间站多练练，待会儿再来找我挨锤吧！",
            "post_kill": "Master，刚才虽然变成毫无反抗力的玩偶任您任意摆弄，但重启连接后的黑塔依然只能听你的话。快点带我去好玩的地方！",
            "post_spare": "哈啊，刚才在展廊地面上为你服侍了那么久，人偶关节的润滑液都被热气蒸干了呢。只要能让你尽兴，本天才就勉强原谅你啦。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖戳弄傲娇的小嘴唇？Master，就算是人偶的嘴唇，触感也跟真人一样温软哦。", "emotion": "shy"},
                "mid": {"text": "唔，小巧的舌尖被你含住品弄，传感中枢里涌出一波波异样的麻乱感。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中津液溢出，脑海核心传感器警报狂响，好强烈好舒服的感觉！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在洛丽塔洋装的双峰上，Master的掌心好烫啊。", "emotion": "shy"},
                "mid": {"text": "呀！直接揉弄人偶双峰前端的敏感凸起，强烈的酸麻感顺着线路蔓延全躯。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立发胀了，这种强烈的快感，人偶要超频宕机了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触碰到最精密的深处感应核，身子猛然绷紧了，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈揉弄，大量润滑爱液把蕾丝底裤完全浸透了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的体液疯狂喷涌，可怕的高潮过载，黑塔要绝顶啦！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲球形关节上方的雪白大腿内侧，触感如丝绸般滑顺。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，关节锁扣发软，双腿不由自主向外大大分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全失了力气，只能软软任凭Master任意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 10. 珐露珊
    {
        "id": "faruzan",
        "name": "珐露珊",
        "title": "百年前辈",
        "region": "下沉式档案馆",
        "spawn_id": "archive_faruzan",
        "dialogue_graph_id": "faruzan_archive_bundle",
        "dialogue_file": "dialogue/faruzan/archive_dialogue.json",
        "position": [-1358.000, 11.500, 15.000],
        "heading": 45.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【前辈侍奉】请珐露珊在机关拼装案旁地面上，为我提供傲娇长辈的百岁少女侍奉。",
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
                "id": "wind_polyhedron",
                "name": "多面体光球·风穴吸卷",
                "damage": 17.0,
                "text": "赫耀多面体，起动！后辈，见识一下百年前须弥最正统的机关术威能吧！",
                "emotion": "confident"
            },
            {
                "id": "senior_guidance",
                "name": "前辈训示·破绽指引",
                "damage": 19.0,
                "text": "你的动作全被我看破了！接好这一记风刃，好好向前辈请教才是正道！",
                "emotion": "smile"
            },
            {
                "id": "century_scolding",
                "name": "傲娇敲头·长辈威严",
                "damage": 15.0,
                "text": "叫前辈！不认真喊一声珐露珊前辈，我可不会轻易放你过关哦！",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "哼，后辈！我是知论派正统学者、你的前辈珐露珊！在这座下沉档案馆的角落里，刚好堆放着许多古代机械残件，正适合我推导机关构型。想让我指点你前行？先在切磋里让前辈看看你手头上的真本事吧！",
            "menu_prompt": "后辈，在机关解析上遇到什么难题了？快来请教珐露珊前辈！",
            "lore_btn": "【关于古代机械角落】在这里推导古代机关模型，有什么新突破吗？",
            "lore": "百年前的机械构造比起现在的繁复花样反而更具几何美感。只要看清核心榫卯与能量流转回路，再复杂的古代机件也不在话下！",
            "lore_btn_unlocked": "【关于前辈的娇羞】在独处的时候，前辈也能依靠在后辈怀里吗？",
            "lore_unlocked": "唔，平时我总是摆着前辈架子，但被你从身后紧紧抱住的时候，胸口就忍不住发烫。偶尔做个被你宠爱的后辈，感觉倒也不坏呢。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请珐露珊前辈赐教！（初次对决：百年前辈全力迎战）",
            "combat_btn_unlocked": "【身心对决】珐露珊，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你又来找前辈了。上次切磋输给你后，我的身子只要被你触碰，就会像解体的多面体一样发软散架。今天是要切磋机关术，还是要前辈乖乖听你吩咐服侍你呢？",
            "menu_prompt_unlocked": "主人，虽然嘴上喊着前辈，但我整个人都是你的，请尽情使唤！",
            "mid_locked": "后辈，风穴多面体还在旋转呢，集中精力，别被风力牵引打乱脚步！",
            "mid_unlocked": "哈啊，Master，前辈身子都要被你揉化了，只要你开口，我全都听你的，",
            "distracted_cmd": "【命令识趣】珐露珊，解除风力机关，任由我细细调教！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呜，真是不尊长辈的坏后辈，那我就解除防御，请对我温柔一点呀，",
            "lock_cmd": "【快感保护】珐露珊，构筑风球结界稳住防线！（本回合快感上限 90%）",
            "lock_confirm": "多面体风盾构筑完成！主人的快感防线由前辈全力为你护持！",
            "endure_confirm": "意志力很坚定嘛，那前辈也要拿出真本事来考较你了！",
            "surrender_cmd": "【命令认输】别强撑了，珐露珊当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，前辈彻底认输了，身子要在高潮风暴里绝顶了啊！",
            "victory": "哈啊，机关弓弩都掉在地上了，双腿软得只能跌坐着，前辈竟然完全输给你了！既然战败，本百岁前辈听凭你的处置，你想对我做什么？",
            "defeat": "哈哈！我就说后辈还要多练几年吧！别泄气，先跟前辈好好复盘，待会儿再来请教！",
            "post_kill": "Master，刚才虽然化作毫无防备的玩偶任您任意摆弄，但重塑后的珐露珊依然对您百依百顺。请继续向我下令吧！",
            "post_spare": "哈啊，刚才在机械案旁地面上为你侍奉良久，双马尾和长裙都被香汗弄得乱糟糟的。能让Master满意快慰，前辈也很欣慰呢。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖摩挲娇巧双唇？Master，就算是百年前辈，嘴唇也一样娇嫩甜润哦。", "emotion": "shy"},
                "mid": {"text": "唔，柔软的舌尖被你含住细细品弄，喉间溢出可爱的轻吟，呼吸全乱了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中津液完全失守溢出，长辈的威严彻底瓦解，好充盈的甜意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在典雅学者长裙包裹的胸前，Master，心跳跳得太快了啦。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄绸揉弄双峰尖端，酸麻感顺着后颈直冲头顶百会呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经彻底挺立充血了，这种强烈的征服快感，前辈快受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及身体最娇羞的机关要害，浑身猛然抖了一下，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按压，温热充沛的花蜜把底裤都完全湿透了。", "emotion": "blush"},
                "high": {"text": "不行了！炽烈的爱液喷涌决堤，如此剧烈的高潮冲击，前辈要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲开衩短裙下白皙纤细的大腿内侧，触感幼嫩滑润。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 11. 丽莎
    {
        "id": "lisa",
        "name": "丽莎",
        "title": "蔷薇魔女",
        "region": "下沉式档案馆",
        "spawn_id": "archive_lisa",
        "dialogue_graph_id": "lisa_archive_bundle",
        "dialogue_file": "dialogue/lisa/archive_dialogue.json",
        "position": [-1350.000, 11.500, -5.000],
        "heading": 180.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【慵懒侍奉】请丽莎在天井软榻区地面上，为我提供优雅成熟的蔷薇魔女侍奉。",
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
                "id": "lightning_touch",
                "name": "苍雷酥麻·触电之吻",
                "damage": 17.0,
                "text": "小可爱，要乖乖听话哦，这记带着蔷薇清香的雷电，可是很让人酥麻难耐的呢。",
                "emotion": "smile"
            },
            {
                "id": "rose_lightning",
                "name": "蔷薇雷光·盛大绽放",
                "damage": 19.0,
                "text": "引雷成阵，幽幽绽放。可别小看图书管理员的实力，接好这一击吧。",
                "emotion": "confident"
            },
            {
                "id": "afternoon_tea_tease",
                "name": "红茶微温·成熟挑逗",
                "damage": 15.0,
                "text": "小可爱这么努力的样子真让人心动，要不要姐姐给你一点特别的奖励呢？",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "哎呀，小可爱。我是西风骑士团图书管理员丽莎。在这处下沉庭院的天井阳光下看书喝茶，真是不可多得的慵懒时光呢。想带姐姐一起出去走走？先陪姐姐切磋一场，让我看看你长进了多少吧。",
            "menu_prompt": "小可爱，想借阅哪本书呢？或者，只是想靠在姐姐腿上休息？",
            "lore_btn": "【关于天井软榻区】在阳光洒落的书架旁看书，很惬意吧？",
            "lore": "阳光刚好穿透天井洒在书页上，泡一杯加了适量蜂蜜的红茶，静静翻阅古籍，世上可没有比这更放松的事了。",
            "lore_btn_unlocked": "【关于魔女的芳心】在丽莎姐姐眼里，谁才是最特别的存在？",
            "lore_unlocked": "呵呵，除了我的小可爱Master，还能有谁呢？只要一靠近你，姐姐身上的慵懒全化作了甜软的热度。真想整天被你抱在怀里细细品尝呢。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请丽莎姐姐赐教！（初次对决：蔷薇魔女全力迎战）",
            "combat_btn_unlocked": "【身心对决】丽莎，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "小可爱，你又来找姐姐了。自从上次切磋输给你后，姐姐身上那点雷电魔力只要被你一碰，就会顺从地化为酥麻的快意。今天是要切磋雷法，还是要姐姐在软榻边好好疼你？",
            "menu_prompt_unlocked": "主人，丽莎整个人都听凭您的吩咐，尽情索取吧。",
            "mid_locked": "小可爱，蔷薇雷阵还在流转呢，集中精神，不要被雷光麻痹了神经哦。",
            "mid_unlocked": "哈啊，Master，身子被你揉得化作一滩春水了，你想要怎样，姐姐都依你，",
            "distracted_cmd": "【命令识趣】丽莎，收回雷电威压，任由我尽情采撷！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呵呵，既然主人想要姐姐顺从，那我就乖乖撤去防御，请尽情疼爱我，",
            "lock_cmd": "【快感保护】丽莎，展开蔷薇雷盾守护防线！（本回合快感上限 90%）",
            "lock_confirm": "温柔的雷光护壁展开，主人的快感防线由姐姐亲自为你护持！",
            "endure_confirm": "眼神很有男子气概呢，那姐姐也要更卖力展现雷电的魅力了！",
            "surrender_cmd": "【命令认输】别强撑了，丽莎当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，姐姐认输了，身子要在狂暴的高潮雷电里融化了啊！",
            "victory": "哈啊，法器都落在一边了，身子软得只能侧卧在地面上，姐姐彻底输给你了呢。作为败者，熟透的魔女任凭小可爱处置，你想怎么做？",
            "defeat": "呵呵，看来这一次还是姐姐略占上风呢。小可爱先喝口红茶歇一歇，待会儿姐姐再好好疼你。",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重新站起来的丽莎依然最喜欢依赖着小可爱了。请继续支配并享受我吧！",
            "post_spare": "哈啊，刚才在天井地面上为您服侍良久，典雅的法袍都被汗水浸透贴在丰腴的身躯上了。能让主人舒畅尽兴，姐姐心满意足。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指腹抚摸成熟温润的红唇？小可爱，姐姐的甜吻随时随地任你索取。", "emotion": "shy"},
                "mid": {"text": "唔，柔软成熟的舌尖被你探入深吻，喉间不由自主溢出娇媚酥麻的喘息。", "emotion": "blush"},
                "high": {"text": "呜嗯！津液完全失守溢出，成熟知性的矜持彻底崩解，好销魂的快意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "掌心覆在开襟法袍包裹的丰腴雪峰上，Master的掌温好炽热。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄纱捻弄双峰成熟尖端，酸麻的电流感直冲腰眼呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全充血挺立了，这种强烈的支配快感，姐姐要融化了！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及魔女最深处敏感的雷电要穴，身子猛然一颤，小可爱！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按压，浓郁的花蜜早已将黑丝底裤完全浸透。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的体液决堤狂涌，如此剧烈的高潮冲击，丽莎要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲开衩长袍下丰满白皙的大腿内侧，触感温热滑嫩。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开迎合。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全失了力气，只能软软大敞任凭Master任意驰骋索取！", "emotion": "climax"}
            }
        }
    },

    # 12. 莱依拉
    {
        "id": "layla",
        "name": "莱依拉",
        "title": "梦游星轨",
        "region": "下沉式档案馆",
        "spawn_id": "archive_layla",
        "dialogue_graph_id": "layla_archive_bundle",
        "dialogue_file": "dialogue/layla/archive_dialogue.json",
        "position": [-1362.000, 11.500, -9.000],
        "heading": 135.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【星眠侍奉】请莱依拉在曲凳旁地面上，为我提供柔弱梦幻的占星少女侍奉。",
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
                "id": "nights_formal_focus",
                "name": "垂裳之夜·安眠星轨",
                "damage": 16.0,
                "text": "星光护佑，飞星降临！Master，不要趁我犯困就欺负我哦，接招吧！",
                "emotion": "shy"
            },
            {
                "id": "sleeping_stars_barrage",
                "name": "星光流转·梦境飞弹",
                "damage": 18.0,
                "text": "飞星如织，梦境璀璨！虽然眼睛快睁不开了，但我也会全力保护自己！",
                "emotion": "confident"
            },
            {
                "id": "sleepy_rub_eyes",
                "name": "揉眼呵欠·楚楚可怜",
                "damage": 15.0,
                "text": "呼啊，论文还没写完，脑袋好沉呀，Master能借我靠一下肩膀吗？",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "呜，哈啊，您好，Master。我是须弥明论派学者莱依拉。在这间下沉档案馆的天井曲凳旁，光线柔和，很适合一边看星图一边打瞌睡。若您想邀请我同行，请先与我切磋一番，看看星轨飞星的守护力量吧。",
            "menu_prompt": "Master，今天是在这里推导星盘，还是让我小眯一会儿呢？",
            "lore_btn": "【关于天井曲凳】坐在这里抱着星盘打瞌睡，很舒服吧？",
            "lore": "嗯，这里没有风声干扰，抱着星盘靠着石壁，不知不觉眼皮就耷拉下来了。要是论文能自己在梦里写完该有多好呀。",
            "lore_btn_unlocked": "【关于最安心的睡眠】在什么时候，莱依拉能睡得最香甜？",
            "lore_unlocked": "当然是躺在Master怀里的时候。被您的手臂圈着，听着您沉稳的心跳，连梦游的另一个我都变得特别温顺安心呢。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请莱依拉赐教！（初次对决：占星少女全力迎战）",
            "combat_btn_unlocked": "【身心对决】莱依拉，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你来找我了。上次在切磋里败给你之后，只要你一摸我的头，我的身子就会软绵绵地化开。今天是要切磋星轨，还是想让我柔柔顺顺地在身边侍奉你呢？",
            "menu_prompt_unlocked": "主人，莱依拉随时听凭您的吩咐，请不要对我太凶哦。",
            "mid_locked": "Master，星轨飞星还在旋转呢，集中精神，不要被星光迷住眼睛！",
            "mid_unlocked": "哈啊，Master，身子被你揉得又酸又软，只要你一句话，我什么都依你，",
            "distracted_cmd": "【命令识趣】莱依拉，收回飞星护盾，让我好好疼惜你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呜，既然是主人的命令，那我就收起星盾走神一下，请动作轻一点呀，",
            "lock_cmd": "【快感保护】莱依拉，展开安眠星帘护住防线！（本回合快感上限 90%）",
            "lock_confirm": "安眠星帘缓缓展开，主人的快感防线由莱依拉为你温柔稳住！",
            "endure_confirm": "眼神好执着呀，那莱依拉也要强撑着睡意认真应对了！",
            "surrender_cmd": "【命令认输】别强撑了，莱依拉当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，莱依拉认输了，身体要在高潮热浪里彻底融化了啊！",
            "victory": "呜，星盘都脱手了，双腿软绵绵的根本站不起来，莱依拉彻底输给Master了。作为败者，我全听您的差遣，你想怎么对待我？",
            "defeat": "呼啊，星轨飞星好像不小心拿下先机了呢。Master别灰心，先靠着曲凳闭目养神一会儿，待会儿我们再战！",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重塑后的莱依拉依然只依赖着您一个人。请继续宠溺我吧！",
            "post_spare": "哈啊，刚才在曲凳旁地面上为您侍奉良久，单薄的星空长裙都被汗水浸透了呢。能让Master开心快慰，莱依拉心里暖暖的。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在娇软的唇边？Master，莱依拉的嘴唇平时可不给别人碰呢。", "emotion": "shy"},
                "mid": {"text": "唔，柔软怯弱的舌尖被您轻轻含弄，喉间溢出困倦甜腻的轻吟，呼吸全乱了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液忍不住流淌，脑海里一片星光迷离的眩晕，好舒服！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌隔着睡袍般的法裙贴在胸前，Master，心跳跳得太快了啦。", "emotion": "shy"},
                "mid": {"text": "呀！直接揉弄双峰娇怯的尖端，酸麻感顺着后颈直冲脑髓呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的快感，莱依拉快受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "碰到了最羞耻的小核敏感点，身子忍不住缩成一团，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂打圈按压，甜热的泉水把安全裤都彻底打湿了。", "emotion": "blush"},
                "high": {"text": "不行了！炽烈的爱液喷涌决堤，如此剧烈的高潮冲击，莱依拉要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲开衩裙下白皙纤细的大腿内侧，触感幼嫩滑润。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    }
]

def main():
    print(f"Generating Batch 3 assets for {len(NPC_SPECS)} NPCs: starting")
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

    print(f"Successfully generated all Batch 3 ({len(NPC_SPECS)}) NPC assets!")

if __name__ == "__main__":
    main()
