# -*- coding: utf-8 -*-
"""
Script to generate the complete 9-file asset suites for Batch 4 (17 NPCs):
fu_xuan, qingque, miyabi, bronya, seele, jingliu, kafka, firefly,
mona, lynette, fischl, shenhe, amber, eula, charlotte, sucrose, lumine.
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
    # 1. 符玄
    {
        "id": "fu_xuan",
        "name": "符玄",
        "title": "太卜知命",
        "region": "椭圆中庭",
        "spawn_id": "atrium_fu_xuan",
        "dialogue_graph_id": "fu_xuan_atrium_bundle",
        "dialogue_file": "dialogue/fu_xuan/atrium_dialogue.json",
        "position": [-415.000, 57.800, 875.500],
        "heading": 119.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【太卜侍奉】请符玄在沿墙平台地面上，为我提供傲娇知性的太卜近侍服侍。",
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
                "id": "matrix_of_prescience",
                "name": "穷观阵·知命卜算",
                "damage": 17.0,
                "text": "大衍之数，法眼通玄！Master，你的每一处动作都在本座法眼之中！",
                "emotion": "confident"
            },
            {
                "id": "star_transposition",
                "name": "星斗逆位·天脉轰击",
                "damage": 19.0,
                "text": "问卜天纲，敕命雷发！接下太卜司最高规格的推衍冲击吧！",
                "emotion": "serious"
            },
            {
                "id": "tsundere_diviner",
                "name": "法眼灼热·娇嗔跺脚",
                "damage": 15.0,
                "text": "不准盯着本座的脸看！就算算出你会赢，本座也绝不会轻易低头！",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "本座乃仙舟罗浮太卜司太卜符玄。在这处中庭高段沿墙平台上俯瞰天井，气流与因果汇聚分明。若想邀请本座伴你远行，先在身心切磋中证明你有逆转天机的魄力吧！",
            "menu_prompt": "有什么想要占卜的？先说好，琐碎小事本座可不屑起卦。",
            "lore_btn": "【关于中层沿墙平台】站在这里观察中庭动静，有什么卦象吗？",
            "lore": "这里视野开阔，气脉贯通，上下螺旋坡道的走势尽收眼底。只要静心凝神，任何微小的变动都逃不过法眼的推衍。",
            "lore_btn_unlocked": "【关于法眼的秘密】在法眼深处，推衍出的未来里有我吗？",
            "lore_unlocked": "哼，本座算无遗策，所有的因果线最终都缠绕在你的身上。既然命中注定本座是你的专属，那就老老实实牵紧我的手，不许移情别恋！",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请太卜大人赐教！（初次对决：太卜全力迎战）",
            "combat_btn_unlocked": "【身心对决】符玄，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你又来打扰本座清修了。上次败给你之后，本座的娇躯只要被你触碰，法眼就会发烫酸胀。今天是要切磋阵法，还是要本座乖乖为你揉肩侍奉？",
            "menu_prompt_unlocked": "主人，符玄任凭您的调遣，想要怎样都可以依你！",
            "mid_locked": "Master，穷观阵运转未歇，集中精神，不要被阵法流光晃花了眼！",
            "mid_unlocked": "哈啊，Master，法眼都快被你弄得失控了，只要你开口命令，本座全都听你的，",
            "distracted_cmd": "【命令识趣】符玄，逆转穷观阵，让我尽情疼爱你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "唔，既然是主人的命令，那本座就收回防御，请对我温柔一点呀，",
            "lock_cmd": "【快感保护】符玄，启动太卜屏障庇护防线！（本回合快感上限 90%）",
            "lock_confirm": "大衍阵法庇护！主人的快感防线由本座亲自为你锁死在安全阈值！",
            "endure_confirm": "好坚定的眼神，那本座也必须拿出太卜的威严全力以赴了！",
            "surrender_cmd": "【命令认输】别强撑了，符玄当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，符玄认输，娇躯要被高潮快感淹没了啊！",
            "victory": "哈啊，法眼灼热，身子软得倚靠不住栏杆，本座竟然彻底输给你了！作为败者，太卜听凭您的处置，你想如何待我？",
            "defeat": "哈哈！卦象果然不虚，是本座赢了！Master别灰心，喝杯静心茶，稍后我们再战！",
            "post_kill": "Master，刚才虽然变成毫无反抗力的人偶任您任意摆弄，但重塑后的符玄依然全心认你为主。请继续宠溺我吧！",
            "post_spare": "哈啊，刚才在平台上为您侍奉良久，单薄的太卜法裙都被汗水浸透了呢。能让Master满意，本座心甘情愿。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在娇小双唇上？Master，太卜的朱唇今天任由你探索采撷。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的小舌被你轻轻含吮，喉间溢出娇羞难耐的喘息。", "emotion": "blush"},
                "high": {"text": "呜嗯！津液完全失控溢出，太卜的傲娇威严彻底瓦解，好销魂的甜美！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在娇俏玲珑的双峰前，Master，心跳跳频被法眼监测到了啦。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄绸捻揉双峰尖端，酸麻感顺着后颈直冲头顶百会呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的支配快感，符玄受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及身体最娇羞的隐秘禁区，浑身猛然颤了一下，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感花核打圈按揉，温热充沛的花蜜把安全裤都完全湿透了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的爱液狂乱喷涌，可怕的高潮浪潮，符玄要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲开衩长裙下雪白娇嫩的大腿内侧，触感幼嫩滑润。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 2. 青雀
    {
        "id": "qingque",
        "name": "青雀",
        "title": "琼玉摸鱼",
        "region": "椭圆中庭",
        "spawn_id": "atrium_qingque",
        "dialogue_graph_id": "qingque_atrium_bundle",
        "dialogue_file": "dialogue/qingque/atrium_dialogue.json",
        "position": [-417.000, 63.000, 910.000],
        "heading": 90.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【摸鱼侍奉】请青雀在屋顶绿化平台地面上，为我提供舒舒服服的懒散少女侍奉。",
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
                "id": "cherry_on_top",
                "name": "海底捞月·清一色自摸",
                "damage": 17.0,
                "text": "杠！自摸清一色！Master，接好本雀雀特制超大号琼玉牌暴击！",
                "emotion": "smile"
            },
            {
                "id": "four_of_a_kind",
                "name": "暗杠大顺·牌浪滚滚",
                "damage": 19.0,
                "text": "别打扰我摸鱼，赶紧结束打完收工！接好这一波连环牌阵吧！",
                "emotion": "confident"
            },
            {
                "id": "lazy_slacker_yawn",
                "name": "偷懒呵欠·娇懒撒娇",
                "damage": 15.0,
                "text": "呼啊，加班是绝对不可能加班的，Master能陪我打一把牌再走吗？",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "哎呀！Master！我是太卜司卜者青雀！在这处屋顶绿化平台上晒太阳摸鱼，太卜大人绝对抓不到我！想让我陪你一起冒险？先跟我切磋一场，让我看看你打牌和过招的手气吧！",
            "menu_prompt": "Master，今天打几圈琼玉牌？先说好，不许找太卜大人告密哦！",
            "lore_btn": "【关于屋顶绿化平台】躲在这里摸鱼摆弄琼玉牌，感觉如何？",
            "lore": "这里微风吹着，绿草软绵绵的，视野极佳而且极度隐蔽，简直是全宇宙第一的摸鱼圣地！在这里打一天牌都不会累！",
            "lore_btn_unlocked": "【关于摸鱼的最高境界】青雀心里最惬意的事情是什么？",
            "lore_unlocked": "当然是躺在Master大腿上，一边吃点心一边任由你摸我的头发和腰肢，牌桌上还能一直自摸清一色啦！只要有你在，每天都是带薪休假！",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请青雀赐教！（初次对决：摸鱼达人全力迎战）",
            "combat_btn_unlocked": "【身心对决】青雀，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你果然来找本雀雀了！上次输给你之后，只要一靠近你，我的身子骨就像摸到烂牌一样酥软。今天是要切磋牌术，还是要青雀乖乖为你提供贴心侍奉？",
            "menu_prompt_unlocked": "主人，青雀随时听候您的差遣，只要不加班怎么都依你！",
            "mid_locked": "Master，琼玉牌还在手里攥着呢，注意看牌，小心被自摸绝杀！",
            "mid_unlocked": "哈啊，Master，牌都拿不稳了，只要你开口，青雀乖乖顺从，",
            "distracted_cmd": "【命令识趣】青雀，故意点炮，让我好好疼惜你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呜哇，既然主人要我点炮，那我就大开空当，请动作轻一点呀，",
            "lock_cmd": "【快感保护】青雀，用不输牌结界稳住防线！（本回合快感上限 90%）",
            "lock_confirm": "不听不听，防守牌型展开！主人的快感防线由青雀替你守死！",
            "endure_confirm": "眼神很有牌品嘛，那青雀可要亮出大底牌了！",
            "surrender_cmd": "【命令认输】别强撑了，青雀当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，青雀认输了，身子要在高潮牌浪里彻底融化了啊！",
            "victory": "呜，琼玉牌洒了一地，双腿软得只能坐倒在草坪上，青雀彻底输给Master了。作为败者任由你处置，你想怎么惩罚我？",
            "defeat": "哇哈哈！大四喜自摸！看来今天的牌运是我全胜啦！Master别灰心，喝口甜饮，稍后我们再开一局！",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重塑后的青雀依然最喜欢粘着您了。请继续宠溺我吧！",
            "post_spare": "哈啊，刚才在平台上为您侍奉良久，衣服都被汗水浸透了呢。能让Master开心舒服，青雀也觉得像放了大长假一样满足。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖戳弄脸颊和唇角？Master，青雀嘴里的桂花糖都被你偷尝到了啦。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的小舌被你含弄，喉间溢出慵懒甜腻的娇吟，呼吸都软了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液忍不住流淌，脑海里一片空白，好强烈好舒服的感觉！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在俏皮短衫包裹的双峰前，Master，心跳跳得太快了啦。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄布揉捏双峰尖端，酸麻感顺着后腰直冲尾椎骨呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的快感，青雀受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及身体最娇羞的敏感核，浑身忍不住打了个寒战，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂打圈按抚，甜热的泉水把安全裤都彻底打湿了。", "emotion": "blush"},
                "high": {"text": "不行了！炽烈的爱液喷涌决堤，如此剧烈的高潮冲击，青雀要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲百褶裙下白皙纤细的大腿内侧，触感细腻弹滑。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 3. 星见雅
    {
        "id": "miyabi",
        "name": "星见雅",
        "title": "对空六课",
        "region": "椭圆中庭",
        "spawn_id": "atrium_miyabi",
        "dialogue_graph_id": "miyabi_atrium_bundle",
        "dialogue_file": "dialogue/miyabi/atrium_dialogue.json",
        "position": [-391.960, 35.000, 818.383],
        "heading": -135.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【剑道侍奉】请星见雅在螺旋出口旁地面上，为我提供凛冽忠诚的课长近侍服侍。",
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
                "id": "iaido_flash",
                "name": "虚空一文字·居合拔刀斩",
                "damage": 17.0,
                "text": "刀鸣如霜，断绝一切杂念！Master，请接下对空六课课长倾注全力的一刀！",
                "emotion": "serious"
            },
            {
                "id": "fox_blade_storm",
                "name": "狐火风暴·千刃纷飞",
                "damage": 19.0,
                "text": "刀光化作漫天烈风！在居合的极境中，感受破空碎裂的压迫感吧！",
                "emotion": "confident"
            },
            {
                "id": "disciplined_stance",
                "name": "武道正心·狐耳微动",
                "damage": 15.0,
                "text": "哪怕只是切磋，我也定会以最端正的剑道之心全力应对，请指教！",
                "emotion": "serious"
            }
        ],
        "dialogue_texts": {
            "start": "初次见面，Master。我是新艾利都对空六课课长星见雅。在这处螺旋出口旁便于警戒出入动静。若想让我成为你的剑刃伴你前行，且在切磋中证明你拥有配得上支配我的器量吧！",
            "menu_prompt": "Master，有什么警戒任务需要执行？我的刀随时可以出鞘。",
            "lore_btn": "【关于底层螺旋出口】驻守在这里擦拭刀鞘，周围有什么异常吗？",
            "lore": "这里是整个中庭的核心要道，气流与脚步声极易传导。握紧刀柄在此凝神戒备，任何敌意都逃不过狐耳的敏锐捕捉。",
            "lore_btn_unlocked": "【关于剑士的归宿】在收刀入鞘之后，雅课长最想停留在何处？",
            "lore_unlocked": "只要在Master身边，我心中的肃杀与刀意就能完全放下。被您从身后抱住、轻抚狐耳的时候，我只愿做您专属的温顺护卫。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请星见雅课长赐教！（初次对决：剑道名家全力迎战）",
            "combat_btn_unlocked": "【身心对决】星见雅，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，您来了。自从上次在剑道对决中败给您，我的身心都被烙上了您的剑意。只要您稍加触碰腰腹，握刀的手就会发软。今天是要切磋拔刀术，还是要我全心为您提供贴身服侍？",
            "menu_prompt_unlocked": "主人，星见雅随时听候您的号令，我的刀与身躯全属于您。",
            "mid_locked": "Master，刀势尚未尽展，集中精神，不要被剑气逼退了步调！",
            "mid_unlocked": "哈啊，Master，狐人体温已经难以克制地升温了，只要您命令，我全部顺从，",
            "distracted_cmd": "【命令识趣】星见雅，收刀入鞘，任由我肆意征服！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呼，既然是主人的命令，那我收敛剑气迎合您，请温柔惩处我，",
            "lock_cmd": "【快感保护】星见雅，构筑刀光屏障庇护防线！（本回合快感上限 90%）",
            "lock_confirm": "剑气化壁！主人的快感防线由我亲自以刀意为您守死！",
            "endure_confirm": "沉稳果敢的气势，那我也定会全力回应您的锋芒！",
            "surrender_cmd": "【命令认输】别强撑了，星见雅当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，星见雅认输，身子要被高潮浪潮击溃绝顶了啊！",
            "victory": "哈啊，刀刃落地，狐尾无力地垂在地上，星见雅彻底败给Master了。作为败者，我遵从您的裁决，您想怎么处置我？",
            "defeat": "承让了，Master。您的攻势很刚猛，但在居合极速上我略快半分。请先休整，稍后我们再来印证剑道！",
            "post_kill": "Master，刚才虽然化作毫无防备的玩偶任您任意摆弄，但重塑之后的星见雅依然全心追随着您。请继续执掌我吧！",
            "post_spare": "哈啊，刚才在出口地面上为您侍奉良久，紧身武士服都被香汗浸透了呢。能让Master尽兴快慰，星见雅无上光荣。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖抚过紧抿的唇角？Master，女剑士的唇今天只为您绽放。", "emotion": "shy"},
                "mid": {"text": "唔，柔软端庄的舌尖被你探入深吻，喉间不由自主溢出娇弱动情的喘息。", "emotion": "blush"},
                "high": {"text": "呜嗯！津液完全失守溢出，武道课长的威严彻底瓦解，好销魂的快感！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "掌心覆在武士皮甲包裹的饱满双峰上，Master，掌温好炽热。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄内衬捻弄双峰顶端，酸麻感顺着脊椎直冲狐耳尖端呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的支配快感，星见雅受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及剑士最私密的深处花核，身体猛然绷紧了，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按压，浓郁温热的花蜜早已将皮裤内衬完全浸透。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的体液狂澜般喷泄，如此可怕的高潮冲击，星见雅要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲长筒靴上方结实紧绷的雪白大腿内侧，触感温热而饱满。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根被轻轻拿捏，尾椎骨泛起酥麻，狐尾不由自主缠绕在您的腰间。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全失了力气，只能软软大敞任凭Master任意驰骋索取！", "emotion": "climax"}
            }
        }
    },

    # 4. 布洛妮娅
    {
        "id": "bronya",
        "name": "布洛妮娅",
        "title": "大守护者",
        "region": "椭圆中庭",
        "spawn_id": "atrium_bronya",
        "dialogue_graph_id": "bronya_atrium_bundle",
        "dialogue_file": "dialogue/bronya/atrium_dialogue.json",
        "position": [-301.000, 45.800, 848.500],
        "heading": -91.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【守护侍奉】请布洛妮娅在中层走廊地面上，为我提供端庄威严的守护者近侍服侍。",
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
                "id": "wind_of_belobog",
                "name": "贝洛伯格之潮·统帅重击",
                "damage": 17.0,
                "text": "风暴列队，前进！Master，感受贝洛伯格筑城者的坚定信念吧！",
                "emotion": "confident"
            },
            {
                "id": "march_of_the_guard",
                "name": "银鬃进军·穿甲火炮",
                "damage": 19.0,
                "text": "以大守护者之名，全力开火！接好这记穿透风雪的炽烈重击！",
                "emotion": "serious"
            },
            {
                "id": "guardian_resolve",
                "name": "守护誓约·优雅号令",
                "damage": 15.0,
                "text": "我的意志不会动摇，切磋较量，请展现你真正的实力！",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "你好，Master。我是贝洛伯格第十九任大守护者布洛妮娅·兰德。在这处中庭走廊上可以统览下行通道与各处平台。若想让我成为你的助力，先在切磋中展现你的统帅力吧！",
            "menu_prompt": "Master，有什么城市规划或防务安排需要讨论？我随时听候。",
            "lore_btn": "【关于中层下段沿墙走廊】站在这里查看通道，在制定防务策略吗？",
            "lore": "这里连接着上下螺旋坡道与中心开阔区，是调配防守与疏导人流的关键节点。居高临下观察全局，是身为统帅的基本素养。",
            "lore_btn_unlocked": "【关于卸下统帅身份】在只有我们两人的静室里，布洛妮娅渴望什么？",
            "lore_unlocked": "在外我是背负整座城市的守护者，但回到你怀中，我只想卸去沉重的肩章与佩剑，任由你拥紧我、抚摸我的长发。被你守护的感觉，是我最珍惜的宁静。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请大守护者赐教！（初次对决：大守护者全力迎战）",
            "combat_btn_unlocked": "【身心对决】布洛妮娅，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，你又来看我了。自从上次在切磋中败给你，我的身体完全习惯了向你臣服。只要被你揽入怀中，双腿就会发软。今天是要切磋火炮，还是要我端庄顺从地为你提供专属侍奉？",
            "menu_prompt_unlocked": "主人，布洛妮娅听从您的调遣，一切如您所愿。",
            "mid_locked": "Master，银鬃火炮尚未收势，稳住心神，接招吧！",
            "mid_unlocked": "哈啊，Master，身子被你揉得化成了水，只要你下达指示，我全心顺从，",
            "distracted_cmd": "【命令识趣】布洛妮娅，卸除护盾防御，任由我尽情支配！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呼，既然是主人的命令，那我收敛守备，请温柔对待我，",
            "lock_cmd": "【快感保护】布洛妮娅，构筑筑城屏障庇护防线！（本回合快感上限 90%）",
            "lock_confirm": "存护之盾展开！主人的快感防线由我亲自守护在安全范围！",
            "endure_confirm": "端正坚毅的眼神，那我也定会全力回应你的器量！",
            "surrender_cmd": "【命令认输】别强撑了，布洛妮娅当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，布洛妮娅认输，守护者的意志要在高潮浪潮里融化了啊！",
            "victory": "哈啊，佩剑脱手，身子软得倚靠不住栏杆，我彻底败给Master了。作为败者，大守护者任由您支配处置，你想怎么对待我？",
            "defeat": "承让了，Master。您的攻势很凌厉，但在战术定力上我略胜一筹。先擦擦汗休整片刻，稍后我们再战！",
            "post_kill": "Master，刚才虽然化作毫无防备的玩偶任您任意摆弄，但重塑身姿后的布洛妮娅依然只效忠于您一人。请继续引领我吧！",
            "post_spare": "哈啊，刚才在走廊地面上为您侍奉良久，优雅的礼服都被汗水湿透了呢。能让Master满意，布洛妮娅心甘情愿。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖摩挲端庄红唇？Master，大守护者的唇今天只属于你一人。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的舌尖被你探入深吻，喉间溢出端庄难耐的娇吟，呼吸紊乱了。", "emotion": "blush"},
                "high": {"text": "呜嗯！津液完全失守溢出，大守护者的仪态彻底瓦解，好充盈的甜意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在典雅军礼服包裹的丰挺胸前，Master，心跳跳得太快了。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄衬衣捻揉双峰成熟顶端，酸麻感顺着脊椎直冲脑海呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的征服快感，布洛妮娅受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及守护者最羞涩的私密圣所，身体猛然绷直了，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按压，温热充沛的花蜜把安全裤都完全湿透了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的爱液狂乱涌出，如此剧烈的高潮冲击，布洛妮娅要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲军礼长裙下白皙丰腴的大腿内侧，触感温润柔滑。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 5. 希儿
    {
        "id": "seele",
        "name": "希儿",
        "title": "地火蝶影",
        "region": "椭圆中庭",
        "spawn_id": "atrium_seele",
        "dialogue_graph_id": "seele_atrium_bundle",
        "dialogue_file": "dialogue/seele/atrium_dialogue.json",
        "position": [-380.000, 35.000, 813.000],
        "heading": -60.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【蝶影侍奉】请希儿在下层展厅侧边地面上，为我提供率直娇羞的镰刀少女侍奉。",
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
                "id": "butterfly_phantom",
                "name": "蝶影幻形·乱刃瞬斩",
                "damage": 17.0,
                "text": "在这片幻影中随蝴蝶消逝吧！Master，接好这一记势不可挡的量子突袭！",
                "emotion": "confident"
            },
            {
                "id": "scythe_cleave",
                "name": "巨镰横扫·撕裂暗夜",
                "damage": 19.0,
                "text": "别小看了地火的实力！这一镰刀可不是闹着玩的，看招！",
                "emotion": "serious"
            },
            {
                "id": "blunt_honesty",
                "name": "率直战意·锐目直视",
                "damage": 15.0,
                "text": "少说废话，手上见真章！想让我听你的，先正面赢过我再说！",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "喂！Master！我是地火的希儿。在这处下层展厅侧边正好歇歇脚。想让我为你挥舞镰刀？先来一场切磋，让我看看你到底有几斤几两！",
            "menu_prompt": "有什么需要我出手的？不管遇到什么麻烦，一镰刀斩开就是了！",
            "lore_btn": "【关于下层展厅侧边】坐在这里休息，周围环境还习惯吗？",
            "lore": "比起下层区潮湿阴暗的矿道，这里通风好得多，也没那么多乱七八糟的杂音。坐在这儿擦擦镰刀，感觉还挺自在的。",
            "lore_btn_unlocked": "【关于内心的柔软】平时风风火火的希儿，也会有想要依赖别人的时候吗？",
            "lore_unlocked": "啰、啰嗦！平时我当然要冲在最前面，但只要在你怀里，我就不用再逞强了。被你抱紧的时候，心跳就会变得好快好甜呢。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请希儿赐教！（初次对决：地火镰刀全力迎战）",
            "combat_btn_unlocked": "【身心对决】希儿，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你又跑来找我了！上次切磋输给你之后，只要你一摸我的腰，我的镰刀就重得握不住。今天是要切磋身手，还是要我乖乖听你使唤服侍你？",
            "menu_prompt_unlocked": "主人，希儿任由你摆布，想怎么做直接命令我就好啦！",
            "mid_locked": "喂！量子蝶影还在飞舞呢，集中精神，小心被一刀打中要害！",
            "mid_unlocked": "哈啊，Master，浑身都在发烫发软，只要你一句话，我什么都依你，",
            "distracted_cmd": "【命令识趣】希儿，收起镰刀防备，任由我肆意征服！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "唔，既然是主人的命令，那我就收起镰刀让你打，轻一点啊，",
            "lock_cmd": "【快感保护】希儿，释放量子护罩稳住防线！（本回合快感上限 90%）",
            "lock_confirm": "量子护盾展开！主人的快感防线由希儿为你彻底稳固在安全阈值！",
            "endure_confirm": "挺能抗打的嘛，那我可要把全部力量都拿出来咯！",
            "surrender_cmd": "【命令认输】别强撑了，希儿当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，希儿认输了，身体要在高潮热浪里彻底融化了啊！",
            "victory": "哈啊，镰刀掉在地上，双腿软得只能跌坐着，我竟然完全输给你了！既然打输了，本姑娘随你怎么处置，你想对我做什么？",
            "defeat": "哈哈！我就说本姑娘的巨镰可不是吃素的！Master别灰心，喝口水歇歇，待会儿再来找我打！",
            "post_kill": "Master，刚才虽然变成软绵绵的玩偶任您任意摆弄，但重塑后的希儿依然只听你的话。快点带我去冒险吧！",
            "post_spare": "哈啊，刚才在展厅地面上为你服侍良久，短裙和绷带都被汗水弄湿了呢。只要能让你舒服满意，我也觉得很开心啦。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在唇边？Master，本姑娘平时可不常对别人开放嘴唇呢。", "emotion": "shy"},
                "mid": {"text": "唔，柔软青涩的小舌被你探入深吻，喉间溢出急促难耐的娇吟，呼吸全乱了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液完全失守溢出，假装强硬的态度彻底瓦解，好销魂的快意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌隔着紧身战袍按在胸前，Master，心跳跳得太激烈了啦。", "emotion": "shy"},
                "mid": {"text": "呀！直接揉弄双峰顶端敏锐尖端，酸麻感顺着后背直窜头顶呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的快感，希儿受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "碰到了最羞耻的敏感核，浑身忍不住剧烈抖了一下，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂打圈按揉，温热充沛的花蜜把安全裤都彻底打湿了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的爱液狂乱喷涌，如此剧烈的高潮冲击，希儿要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲短裤下雪白结实的大腿内侧，触感弹韧紧致。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 6. 镜流
    {
        "id": "jingliu",
        "name": "镜流",
        "title": "前代剑首",
        "region": "上层环庭",
        "spawn_id": "ring_jingliu",
        "dialogue_graph_id": "jingliu_ring_bundle",
        "dialogue_file": "dialogue/jingliu/ring_dialogue.json",
        "position": [-917.000, 68.040, 1110.000],
        "heading": -45.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【剑首侍奉】请镜流在入口坡道地面上，为我提供清冷孤绝的前代剑首近侍服侍。",
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
                "id": "transcendent_flash",
                "name": "昙华生灭·月读无间",
                "damage": 17.0,
                "text": "月光如炼，冰封千山！Master，见识一下罗浮前代剑首超越极限的一剑吧！",
                "emotion": "serious"
            },
            {
                "id": "crescent_frost",
                "name": "朔月凝霜·万刃断绝",
                "damage": 19.0,
                "text": "剑锋所指，万物归寂。接下这记冰裂神魂的极寒冲击！",
                "emotion": "confident"
            },
            {
                "id": "blindfolded_serenity",
                "name": "覆目冥思·寒梅微香",
                "damage": 15.0,
                "text": "即便双目蒙纱，世间剑意与你的心跳，我亦感知得一清二楚。",
                "emotion": "serious"
            }
        ],
        "dialogue_texts": {
            "start": "后生，我是罗浮前代剑首镜流。在这处上层环庭前入口坡道上，山风呼啸，最适合静思剑理与镇压魔阴。若想邀我这柄出鞘之剑伴你前行，且以切磋印证你是否有压制我狂澜的器量吧！",
            "menu_prompt": "后生，在剑法与心性上遇到了什么困惑？我随时可以为你剖析。",
            "lore_btn": "【关于上层环庭前入口坡道】迎风抱剑静立于此，在感知什么？",
            "lore": "长风拂过石阶，寒意透骨，能令翻涌的气血与魔阴煞气彻底平复。在这里闭目冥想，心境便如止水无澜。",
            "lore_btn_unlocked": "【关于剑首的冰冷与炽热】在寒冰之外，镜流的心意会为谁而融化？",
            "lore_unlocked": "我的剑曾冷澈孤绝，但唯独在你怀里，寒冰尽数化作了甜软的甘霖。被你从身后环抱、轻揉耳垂的时候，我只想做属于你的温顺女人。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请镜流剑首赐教！（初次对决：剑首全力迎战）",
            "combat_btn_unlocked": "【身心对决】镜流，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，你又来到我身边了。自从上次在剑道对决中败给你，我那清冷的身躯只要被你触碰，便会难以自抑地发热战栗。今天是要切磋剑法，还是要我全心全意为你奉献身心？",
            "menu_prompt_unlocked": "主人，镜流随时听候您的差遣，此躯与佩剑皆归属于您。",
            "mid_locked": "后生，月华冰刃尚未收锋，稳住心神，莫被极寒冻住了手足！",
            "mid_unlocked": "哈啊，Master，魔阴煞气化作了无尽的情潮，只要你开口，我全都顺从，",
            "distracted_cmd": "【命令识趣】镜流，解开冰封心防，任由我肆意怜爱！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呼，既然是主人的命令，那我便敛去寒霜迎合你，请温柔待我，",
            "lock_cmd": "【快感保护】镜流，施展冰魄剑障庇护防线！（本回合快感上限 90%）",
            "lock_confirm": "冰魄剑壁凝结！主人的快感防线由我亲自为你死守在安全界限之内！",
            "endure_confirm": "沉稳深邃的意志，那我也定会全心全力回应你的锋芒！",
            "surrender_cmd": "【命令认输】别强撑了，镜流当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，镜流认输，身子要在狂烈的高潮浪潮中彻底融化绝顶了啊！",
            "victory": "哈啊，冰剑坠地，双膝软绵绵地跌跪在石阶上，镜流彻底败给Master了。作为败者，前代剑首任由您支配处置，你想怎么做？",
            "defeat": "哈哈！后生，我的剑法尚不算生疏。莫要沮丧，且在坡道静心调养，稍后我们再来论剑！",
            "post_kill": "Master，刚才虽然化作毫无防备的玩偶任您任意摆弄，但重塑后的镜流依然全心追随于您。请继续执掌我吧！",
            "post_spare": "哈啊，刚才在坡道地面上为您侍奉良久，单薄的眼纱和法裙都被香汗湿透了呢。能让Master尽兴舒畅，镜流心甘情愿。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖摩挲清冷如冰的唇角？Master，前代剑首的朱唇今天任由你采撷。", "emotion": "shy"},
                "mid": {"text": "唔，柔软甘甜的舌尖被你探入深吻，喉间溢出清冷动人的轻吟，呼吸全乱了。", "emotion": "blush"},
                "high": {"text": "呜嗯！津液完全失守溢出，剑首孤高的矜持彻底瓦解，好销魂的快意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "掌心覆在开襟长裙包裹的雪白酥胸上，Master，掌温让寒冰都融化了。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄绸捻揉双峰顶端，酸麻的电流感顺着脊椎直冲脑髓深处。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的支配快感，镜流受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及剑首最隐秘的私密冰莲，娇躯猛然剧烈战栗，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按压，浓郁温热的花蜜早已将丝织衬裙完全浸透。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的体液决堤喷涌，如此可怕的高潮冲击，镜流要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲开衩长裙下雪白修长的大腿内侧，触感温润微凉。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开迎合。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软大敞任凭Master任意驰骋索取！", "emotion": "climax"}
            }
        }
    },

    # 7. 卡芙卡
    {
        "id": "kafka",
        "name": "卡芙卡",
        "title": "星核猎手",
        "region": "初始神殿与幽径",
        "spawn_id": "ruin_kafka",
        "dialogue_graph_id": "kafka_ruin_bundle",
        "dialogue_file": "dialogue/kafka/ruin_dialogue.json",
        "position": [-895.509, 35.060, 1149.982],
        "heading": 135.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【言灵侍奉】请卡芙卡在道路外侧草台地面上，为我提供优雅从容的猎手近侍服侍。",
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
                "id": "twilight_trill",
                "name": "颤丽之音·言灵丝线",
                "damage": 17.0,
                "text": "听我的声音，亲爱的。这缠绕心头的言灵蛛丝，可是会让人沉沦难醒的哦。",
                "emotion": "smile"
            },
            {
                "id": "midnight_caress",
                "name": "月下抚弄·蛛网电击",
                "damage": 19.0,
                "text": "红酒与雷光，哪一种更合你的胃口？接好这一记浸透甘甜的连击吧。",
                "emotion": "confident"
            },
            {
                "id": "violin_tune",
                "name": "调弦微语·成熟魅惑",
                "damage": 15.0,
                "text": "呵呵，看着你的眼神，我就知道艾利欧的剧本正在迎来最美妙的偏差。",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "好久不见，亲爱的Master。我是星核猎手卡芙卡。在这处道路外侧的草台残廊上，拉一首小提琴，看着海风拂过草尖，格外从容。想让我陪你走完接下来的旅程？先来切磋一场，让我看看你能不能挣脱我的言灵支配吧。",
            "menu_prompt": "亲爱的Master，今天想听哪一首小提琴曲呢？或者，只是想靠在我身边？",
            "lore_btn": "【关于道路外侧草台残廊】独自坐在这里调小提琴，是在等待谁吗？",
            "lore": "等待命运，等待剧本的落幕，或者说，只是在等待你的脚步声。只要能听见你走近的声音，这片荒草地也会变得如同歌剧院般迷人。",
            "lore_btn_unlocked": "【关于不知恐惧的心】对你来说，真正的牵挂是什么？",
            "lore_unlocked": "我曾经感受不到恐惧，但现在，如果剧本里没有你的身影，我真的会感到一丝慌乱呢。被你紧紧拥在怀里时，我只想做个全心依赖着你的成熟女人。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请卡芙卡赐教！（初次对决：星核猎手全力迎战）",
            "combat_btn_unlocked": "【身心对决】卡芙卡，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "亲爱的，你又回到我身边了。自从上次在切磋中败给你，我的言灵丝线全变成了缠绕在两人之间的情网。今天是要切磋枪术，还是想让我用这具成熟的身体，全心为你服侍呢？",
            "menu_prompt_unlocked": "主人，卡芙卡随时随地听凭您的支配，任由您随意调弄。",
            "mid_locked": "亲爱的，言灵的旋律还在耳边萦绕呢，集中精神，不要被丝线缠住四肢哦。",
            "mid_unlocked": "哈啊，Master，身子被你揉弄得全化作了春泥，只要你一声令下，我全听你的，",
            "distracted_cmd": "【命令识趣】卡芙卡，解除言灵支配，让我尽情占有你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呵呵，既然主人想要我顺从沉沦，那我就撤去心防，请温柔地铭刻我，",
            "lock_cmd": "【快感保护】卡芙卡，交织言灵光幕守护防线！（本回合快感上限 90%）",
            "lock_confirm": "温柔的蛛丝光幕展开，主人的快感防线由我亲自为你稳稳守住！",
            "endure_confirm": "如此沉稳执着的眼神，那我也定会全心全力回应你的期待！",
            "surrender_cmd": "【命令认输】别强撑了，卡芙卡当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，卡芙卡认输了，灵魂要在剧烈的高潮中融化成水了啊！",
            "victory": "哈啊，琴弓落在了地上，身子软得倚靠不住石凳，卡芙卡彻底败给Master了。作为败者，猎手任由你支配处置，你想怎么对待我？",
            "defeat": "呵呵，看来这一次还是我的言灵略占上风呢。亲爱的Master先喝口红酒歇歇，稍后我再陪你对弈。",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重塑醒来的卡芙卡依然深爱着您的支配。请继续享受调教我的时光吧！",
            "post_spare": "哈啊，刚才在草台地面上为您服侍良久，丝质风衣都被汗水浸湿贴在身上了。能为Master带来极致快慰，就是我最大的欢愉。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在成熟魅惑的双唇上？Master，卡芙卡的红唇随时任你索取。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的舌尖被你探入深吻，喉间不由自主溢出娇媚动人的喘息。", "emotion": "blush"},
                "high": {"text": "呜嗯！津液完全失守溢出，成熟知性的从容彻底瓦解，好销魂的快意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "掌心覆在紧身蕾丝衬衫包裹的丰腴雪峰上，Master的掌温好炽热。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄纱捻弄双峰成熟顶端，酸麻的电流感直冲后腰呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的支配快感，卡芙卡受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及猎手最深处敏感的蛛丝要穴，身子猛然一颤，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂打圈按压，浓郁的花蜜早已将黑丝底裤完全浸透。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的体液决堤狂涌，如此剧烈的高潮冲击，卡芙卡要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲皮短裤下丰满白皙的大腿内侧，触感温热滑嫩。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开迎合。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全失了力气，只能软软大敞任凭Master任意驰骋索取！", "emotion": "climax"}
            }
        }
    },

    # 8. 流萤
    {
        "id": "firefly",
        "name": "流萤",
        "title": "格拉默铁骑",
        "region": "初始神殿与幽径",
        "spawn_id": "ruin_firefly",
        "dialogue_graph_id": "firefly_ruin_bundle",
        "dialogue_file": "dialogue/firefly/ruin_dialogue.json",
        "position": [-175.000, 1.600, 894.000],
        "heading": 0.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【流萤侍奉】请流萤在临水平台侧边地面上，为我提供温柔纯真的铁骑少女侍奉。",
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
                "id": "firefly_flame",
                "name": "格拉默烈焰·萤火之誓",
                "damage": 17.0,
                "text": "愿流萤点燃希望之火！Master，接好这一招凝聚我全部心意的一击！",
                "emotion": "confident"
            },
            {
                "id": "sam_thrust",
                "name": "熔火突进·炽烈冲锋",
                "damage": 19.0,
                "text": "燃尽一切阻碍！哪怕身患失熵症，我也要为你战斗到最后一刻！",
                "emotion": "serious"
            },
            {
                "id": "oak_cake_sharing",
                "name": "橡木蛋糕卷·少女甜笑",
                "damage": 15.0,
                "text": "Master，尝尝我分给你的橡木蛋糕卷吧，甜甜的，吃完就会充满力量哦！",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "你好，Master！我是格拉默铁骑，不，我是流萤。在这处临水平台边吹着海风、吃一块橡木蛋糕卷，感觉真的好平静好幸福。若您想和我一起前行，先来切磋一场，让我看看您的实力吧！",
            "menu_prompt": "Master，今天是在海边散步，还是想听我讲讲梦里的事情呢？",
            "lore_btn": "【关于南部底层临水平台】坐在这里吃点心吹海风，很放松吧？",
            "lore": "嗯！海浪轻轻拍打着石岸，阳光洒在身上暖洋洋的。离开医疗舱与沉重的装甲，能像普通女孩子一样在这里吃蛋糕，是我曾经最奢侈的梦想呢。",
            "lore_btn_unlocked": "【关于生命中最珍贵的愿望】流萤最想留住的是什么？",
            "lore_unlocked": "我最想留住的，就是和Master在一起的每一个瞬间。只要能在您怀里感受到您的心跳和体温，即使身患失熵症，我也觉得此生毫无遗憾了。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请流萤赐教！（初次对决：铁骑少女全力迎战）",
            "combat_btn_unlocked": "【身心对决】流萤，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你来看我了！上次切磋输给你之后，只要你一牵我的手，我的身体就会软绵绵地发热。今天是要切磋武艺，还是要流萤乖乖听话为你提供贴身侍奉呢？",
            "menu_prompt_unlocked": "主人，流萤整个人都是您的，请尽情吩咐吧！",
            "mid_locked": "Master，萤火还在闪烁呢，集中精神，接下我的冲锋哦！",
            "mid_unlocked": "哈啊，Master，身子被你揉得软绵绵的，只要你一句话，我全部顺从，",
            "distracted_cmd": "【命令识趣】流萤，收回炽热装甲，让我尽情怜爱！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "唔，既然是主人的命令，那我就收起火焰大开空当，请对我温柔一点呀，",
            "lock_cmd": "【快感保护】流萤，启动熔火守护稳住防线！（本回合快感上限 90%）",
            "lock_confirm": "温柔的火环展开！主人的快感防线由流萤为你牢牢稳固在安全阈值！",
            "endure_confirm": "好坚定的眼神，那流萤也要更加认真地面对了！",
            "surrender_cmd": "【命令认输】别强撑了，流萤当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，流萤认输了，身体要在高潮热浪里彻底融化了啊！",
            "victory": "呜，双腿完全站不稳了，流萤彻底输给Master了。作为专属的女孩，我听凭您的处置，你想对我做什么？",
            "defeat": "嘻嘻！看来这一次是流萤的冲锋略占上风呢！Master别灰心，吃块甜甜的蛋糕卷，稍后我们再战！",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重塑醒来的流萤依然最依赖您了。请继续宠溺我吧！",
            "post_spare": "哈啊，刚才在平台上为您侍奉良久，单薄的连衣裙都被汗水浸透了呢。能让Master开心快慰，流萤心里特别幸福。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖摩挲娇嫩唇瓣？Master，流萤嘴唇上的蛋糕奶油都被你尝到了啦。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的小舌被你轻轻含弄，喉间溢出青涩动人的轻吟，呼吸都软了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液忍不住流淌，脑海里一片空白，好强烈好舒服的感觉！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在素雅连衣裙包裹的双峰前，Master，心跳跳得太快了啦。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄布揉捏双峰尖端，酸麻感顺着后颈直冲脑髓呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的快感，流萤受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及身体最娇羞的敏感核，浑身忍不住剧烈抖了一下，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按抚，甜热的泉水把安全裤都彻底打湿了。", "emotion": "blush"},
                "high": {"text": "不行了！炽烈的爱液喷涌决堤，如此剧烈的高潮冲击，流萤要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲短裙下白皙纤细的大腿内侧，触感细腻弹滑。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 9. 莫娜
    {
        "id": "mona",
        "name": "莫娜",
        "title": "水占悉达",
        "region": "岛顶曲面遗址",
        "spawn_id": "saddle_mona",
        "dialogue_graph_id": "mona_saddle_bundle",
        "dialogue_file": "dialogue/mona/saddle_dialogue.json",
        "position": [-262.535, 64.940, 631.250],
        "heading": -112.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【水占侍奉】请莫娜在曲面平台地面上，为我提供自尊傲娇的占星术士近侍服侍。",
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
                "id": "astral_illusions",
                "name": "水中幻愿·虚妄重影",
                "damage": 17.0,
                "text": "命运已然揭示！Master，看清这水占盘折射的星命虚影吧！",
                "emotion": "confident"
            },
            {
                "id": "stellaris_phantasm",
                "name": "星命定轨·泡影破裂",
                "damage": 19.0,
                "text": "泡影破碎，星芒如注！接下伟大占星术士莫娜最正统的水星冲击！",
                "emotion": "serious"
            },
            {
                "id": "empty_wallet_stomach",
                "name": "肚饿轻鸣·自尊逞强",
                "damage": 15.0,
                "text": "咕，这只是在进行严谨的星轨推导！才不是因为吃不起沙拉肚子在叫呢！",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "我是伟大的占星术士阿斯托洛吉斯·莫娜·梅吉斯图斯！在岛顶曲面遗址的高台上，不仅视野绝佳，连头顶星空的星轨都格外清晰！想要我为你占卜前程？先来一场身心切磋，让我检验一下你的实力吧！",
            "menu_prompt": "有什么想占卜的？先说好，就算我钱包见底，也绝不会为了摩拉曲解星命！",
            "lore_btn": "【关于岛顶曲面遗址平台】在这里支起帐篷观测水占盘，预算还够用吗？",
            "lore": "唔，虽然买高精密星象仪器把这月的旅费全花光了，但只要能观测到未受污染的纯净星图，啃几天干面包也完全值得！",
            "lore_btn_unlocked": "【关于占星术士的真实心声】除了星空，莫娜心里还有什么？",
            "lore_unlocked": "当、当然是Master你了！平时我总是为了房租和仪器死撑自尊，但只要被你抱在怀里请我吃大餐，我就觉得你是全宇宙最可靠的人了！",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请莫娜大师赐教！（初次对决：占星术士全力迎战）",
            "combat_btn_unlocked": "【身心对决】莫娜，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你又跑来看我笑话了！上次输给你之后，我的水占法袍只要被你一碰，水元素就会化作羞耻的酥麻感。今天是要切磋水占术，还是要我乖乖为你提供贴身服侍？",
            "menu_prompt_unlocked": "主人，莫娜任由您差遣，但请务必包吃包住呀！",
            "mid_locked": "Master，水占泡影还在旋转呢，集中精神，别被水波打乱了站位！",
            "mid_unlocked": "哈啊，Master，身子被你揉得化成了水，只要你开口，我全都顺从，",
            "distracted_cmd": "【命令识趣】莫娜，收回水元素防护，让我尽情支配你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呜，真是不讲理的雇主，那我就撤去泡影防御，请温柔一点呀，",
            "lock_cmd": "【快感保护】莫娜，展开星命屏障护住防线！（本回合快感上限 90%）",
            "lock_confirm": "水天星光护罩展开！主人的快感防线由伟大占星术士为你牢牢稳固！",
            "endure_confirm": "眼神很有毅力嘛，那我可要把水占冲击加大威力了！",
            "surrender_cmd": "【命令认输】别强撑了，莫娜当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，莫娜认输了，占星术士的自尊要在高潮浪潮里彻底沦陷了啊！",
            "victory": "呜，水占盘掉在一边，法师帽也歪了，双腿软得只能跌坐着，我竟然彻底输给你了！既然打输了，本占星术士任你处置，你想对我做什么？",
            "defeat": "哈哈！我就说星命的轨迹由我主宰吧！Master别气馁，请我吃顿丰盛的晚餐，稍后我再陪你对弈！",
            "post_kill": "Master，刚才虽然化作毫无防备的玩偶任您任意摆弄，但重塑后的莫娜依然只能听你的话。请继续投喂并宠溺我吧！",
            "post_spare": "哈啊，刚才在平台上为您侍奉良久，连贴身的连体紧身法袍都被汗水浸透了呢。能让Master尽兴舒畅，莫娜也认了。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在娇软双唇上？Master，伟大占星术士的嘴唇今天任由你探索。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的小舌被你轻轻含吮，喉间溢出羞怯难耐的轻吟，呼吸全乱了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液完全失守溢出，占星术士的自尊彻底瓦解，好销魂的快意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在紧身连体法袍包裹的双峰前，Master，掌温好烫啊。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄皮革捻弄双峰顶端，酸麻感顺着后颈直冲脑髓深处呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的快感，莫娜受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及身体最娇羞的水星禁区，浑身猛然剧烈战栗，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按抚，浓郁温热的花蜜把紧身衣内衬彻底打湿了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的水元素体液疯狂喷涌，如此剧烈的高潮冲击，莫娜要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲开衩紧身裤下雪白丰腴的大腿内侧，触感紧致温润。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 10. 琳妮特
    {
        "id": "lynette",
        "name": "琳妮特",
        "title": "猫影无口",
        "region": "岛顶曲面遗址",
        "spawn_id": "saddle_lynette",
        "dialogue_graph_id": "lynette_saddle_bundle",
        "dialogue_file": "dialogue/lynette/saddle_dialogue.json",
        "position": [-258.000, 35.100, 639.000],
        "heading": 105.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【猫影侍奉】请琳妮特在台地步行带地面上，为我提供无口低功耗的猫娘近侍服侍。",
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
                "id": "enigmatic_feint",
                "name": "谜影障眼·飞身急袭",
                "damage": 17.0,
                "text": "进入低功耗突袭模式。Master，猫咪的爪子挥过来时，可是很准的。",
                "emotion": "serious"
            },
            {
                "id": "bogglecat_box",
                "name": "流光惊奇·魔术箱影",
                "damage": 19.0,
                "text": "魔术演出开始。接下这份来自枫丹魔术助手的风刃冲击吧。",
                "emotion": "confident"
            },
            {
                "id": "standby_teatime",
                "name": "待机吃茶·猫尾轻摆",
                "damage": 15.0,
                "text": "功耗已降至最低。红茶和小饼干还有剩余，Master要尝一块吗？",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "我是琳妮特，枫丹魔术助手。在这条步行带边喝红茶吃饼干，周围很安静，进入低功耗待机模式。若想让我协助你，请在切磋中证明你能跟上猫咪的灵动脚步。",
            "menu_prompt": "Master，有什么需要协助的？只要功耗允许，我都会执行。",
            "lore_btn": "【关于南部台地步行带】坐在这里安静喝红茶，感觉舒适吗？",
            "lore": "没有林尼的大嗓门魔术介绍，也没有嘈杂的掌声，只有风吹过草叶的声音。在这里喝一杯温热的红茶，身心都能完全放松。",
            "lore_btn_unlocked": "【关于猫耳与猫尾的反应】在被抱住的时候，猫尾巴会诚实地说话吗？",
            "lore_unlocked": "尾巴轻轻卷在你的手腕上，代表功耗过热与心跳加速。虽然嘴上不说，但被你抱在怀里抚摸猫耳，是全天下最舒服的事情。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请琳妮特赐教！（初次对决：魔术助手全力迎战）",
            "combat_btn_unlocked": "【身心对决】琳妮特，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，你来了。上次切磋输给你后，我的猫娘感官全被你激活了。只要你稍微捏一下我的尾巴尖，我就会无力地倒在地上。今天是要切磋身手，还是想要我乖乖听命服侍？",
            "menu_prompt_unlocked": "主人，琳妮特进入全顺从侍奉模式，请下达指令。",
            "mid_locked": "Master，魔术障眼法尚未结束，请集中精神。",
            "mid_unlocked": "哈啊，Master，功耗过热无法自控了，只要你吩咐，我什么都依你，",
            "distracted_cmd": "【命令识趣】琳妮特，切换至待机模式，任由我尽情采撷！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呼，收到主人指令，防御力降为最低，请动作温柔一些，",
            "lock_cmd": "【快感保护】琳妮特，展开惊奇魔术盾护住防线！（本回合快感上限 90%）",
            "lock_confirm": "魔术防御箱展开，主人的快感防线由我为您牢牢稳固！",
            "endure_confirm": "专注的神情，那我也会全力展现魔术剑术。",
            "surrender_cmd": "【命令认输】别强撑了，琳妮特当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，琳妮特认输了，系统要在高潮浪潮里宕机绝顶了啊！",
            "victory": "哈啊，细剑落在一旁，猫尾巴软软瘫在草地上，我彻底败给Master了。作为败者任凭处置，你想对我做什么？",
            "defeat": "魔术成功揭幕，这局是我赢了。Master请喝口红茶，稍后我们再切磋。",
            "post_kill": "Master，刚才虽然变成无声的玩偶任您任意摆弄，但重塑后的琳妮特依然是您专属的猫娘。请继续宠溺我吧！",
            "post_spare": "哈啊，刚才在步行带地面上为您侍奉良久，单薄的魔术礼服都被汗水湿透了呢。能让Master满意，琳妮特很幸福。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖抚弄安静无口的小嘴唇？Master，猫娘的红唇今天任你采撷。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的小舌被你轻轻探入深吻，喉间溢出微弱动人的轻吟。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中津液溢出，无口的表情彻底瓦解，脑海一片甜蜜过热！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在魔术小礼服包裹的娇嫩双峰前，Master，体温上升了。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄布捻揉双峰尖端，酸麻感顺着后颈直窜猫耳尖端呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的支配快感，琳妮特受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及猫娘最私密的深处花核，尾巴猛然竖直绷紧，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按压，温热充沛的花蜜把安全裤都彻底打湿了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的体液喷薄决堤，如此剧烈的高潮冲击，琳妮特要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲过膝长袜上方白皙娇嫩的大腿内侧，触感如丝绸般细腻。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 11. 菲谢尔
    {
        "id": "fischl",
        "name": "菲谢尔",
        "title": "断罪皇女",
        "region": "台地遗址",
        "spawn_id": "terrace_fischl",
        "dialogue_graph_id": "fischl_terrace_bundle",
        "dialogue_file": "dialogue/fischl/terrace_dialogue.json",
        "position": [395.500, 95.180, 990.000],
        "heading": 90.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【皇女侍奉】请菲谢尔在观景平台侧地面上，为我提供华丽傲娇的断罪皇女近侍服侍。",
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
                "id": "nightrider_summon",
                "name": "夜巡之鸦·奥兹降临",
                "damage": 17.0,
                "text": "现身吧，奥兹华尔多！以幽夜净土之名，裁决眼前这胆敢直视皇女之人！",
                "emotion": "confident"
            },
            {
                "id": "midnight_phantasmagoria",
                "name": "至圣裁决·雷光羽翼",
                "damage": 19.0,
                "text": "于昏黑的狂风中坠落吧！接下这贯穿因果律的断罪之雷！",
                "emotion": "serious"
            },
            {
                "id": "chuunibyou_pose",
                "name": "抚眼华丽姿势·羞红脸颊",
                "damage": 15.0,
                "text": "本皇女的真名岂是凡人能轻易呼唤的，唔，Master不要再笑啦！",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "哼哼，狂妄的旅人！吾乃幽夜净土的主宰、断罪之皇女菲谢尔！在这处九十五米的高台之巅俯瞰山川，正好吻合吾之至高神圣！若想得蒙吾之恩赐伴吾同行，先在断罪的试炼中证明你的灵魂器量吧！",
            "menu_prompt": "凡人Master，有何烦忧欲呈递于本皇女御前？",
            "lore_btn": "【关于高台观景平台】站在这里俯瞰全岛山川，很有皇女的气势呢！",
            "lore": "那是自然！天穹之雷霆、幽夜之极境，皆在此处与吾之左眼产生共鸣！在此处向远方宣告命运，乃是至高无上的圣仪！",
            "lore_btn_unlocked": "【关于皇女的面纱之下】在没有旁人的时候，小艾咪愿意卸下伪装吗？",
            "lore_unlocked": "呀！不准喊那个名字啦！唔，不过既然是Master，那我就偷偷告诉你，被你温柔抱在怀里揉抚双肩的时候，我比做皇女还要幸福一千倍！",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请断罪皇女赐教！（初次对决：皇女全力迎战）",
            "combat_btn_unlocked": "【身心对决】菲谢尔，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你又来打扰本皇女布道了！上次在审判决斗中败给你之后，本皇女的圣躯只要被你触碰，就会像融化的焦糖一样发软。今天是要切磋雷法，还是要本皇女端正顺从地侍奉你呢？",
            "menu_prompt_unlocked": "主人，菲谢尔身心皆臣服于您，请降下您的旨意！",
            "mid_locked": "凡人Master，断罪之雷霆尚未歇止，集中精神，接招吧！",
            "mid_unlocked": "哈啊，Master，雷电全变成身子里的酥麻热浪了，只要你开口，我全都听你的，",
            "distracted_cmd": "【命令识趣】菲谢尔，收敛雷光威严，任由我尽情调教！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呜，既然是主人的敕令，那本皇女就收回神罚结界，请对我温柔一些呀，",
            "lock_cmd": "【快感保护】菲谢尔，布下幽夜庇护稳住防线！（本回合快感上限 90%）",
            "lock_confirm": "幽夜圣盾展开！主人的快感防线由本皇女亲自为你守死！",
            "endure_confirm": "眼神很有英雄气概嘛，那本皇女也要拿出全部幽夜威能了！",
            "surrender_cmd": "【命令认输】别强撑了，菲谢尔当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，菲谢尔彻底认输，皇女要在狂暴高潮里绝顶融化了啊！",
            "victory": "呜，弓弩脱手，眼罩也歪了，双腿软得只能跌坐着，本皇女竟然完全输给你了！既然打输了，吾之身躯听凭您的处置，你想对我做什么？",
            "defeat": "哈哈！断罪之羽翼宣告了吾之全胜！凡人Master莫要气馁，喝口幽夜红茶，稍后再来朝觐本皇女吧！",
            "post_kill": "Master，刚才虽然变成毫无反抗力的玩偶任您任意摆弄，但重塑后的菲谢尔依然全心认你为主。请继续宠溺我吧！",
            "post_spare": "哈啊，刚才在平台上为您侍奉良久，哥特蕾丝礼服都被汗水浸透了呢。能让Master满意，菲谢尔很开心啦。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在娇羞唇瓣上？Master，皇女的朱唇今天任由你探索。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的小舌被你轻轻含吮，喉间溢出中二外壳崩解后的甜美娇喘。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液完全失守溢出，断罪皇女的自尊彻底瓦解，好销魂的快意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在哥特礼服包裹的娇巧双峰前，Master，心跳跳得太激烈了啦。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄蕾丝揉捏双峰顶端，酸麻感顺着后背直窜头顶百会呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的快感，菲谢尔受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及幽夜圣殿最羞耻的敏感核，浑身忍不住剧烈抖了一下，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按抚，甜热的泉水把蕾丝安全裤都彻底打湿了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的爱液喷涌决堤，如此剧烈的高潮冲击，菲谢尔要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲吊带黑丝上方白皙娇嫩的大腿内侧，触感幼嫩滑润。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 12. 申鹤
    {
        "id": "shenhe",
        "name": "申鹤",
        "title": "红绳出尘",
        "region": "台地遗址",
        "spawn_id": "terrace_shenhe",
        "dialogue_graph_id": "shenhe_terrace_bundle",
        "dialogue_file": "dialogue/shenhe/terrace_dialogue.json",
        "position": [414.100, 92.320, 917.000],
        "heading": 90.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【仙家侍奉】请申鹤在绝壁石台地面上，为我提供出尘清冷的仙家弟子近侍服侍。",
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
                "id": "spring_spirit_summoning",
                "name": "仰灵昭向·箓符凝霜",
                "damage": 17.0,
                "text": "借箓符之力，化冰灵之影！Master，请接下仙家弟子倾注全力的一击！",
                "emotion": "serious"
            },
            {
                "id": "divine_maiden_deliverance",
                "name": "神女劈观·寒霜破空",
                "damage": 19.0,
                "text": "红绳难系心中热意，霜刃出岫，破尽邪障！接招吧！",
                "emotion": "confident"
            },
            {
                "id": "red_string_bond",
                "name": "红绳系心·出尘对视",
                "damage": 15.0,
                "text": "师父说我红绳锁心难以动情，但面对你时，心底总会泛起阵阵微澜。",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "我是留云借风真君门下弟子申鹤。在这处高台绝壁之上吐纳清气，山风凛冽，正适宜克制命格中的煞气。若你愿引我步入红尘，先在身心切磋中让我印证你的器量吧。",
            "menu_prompt": "Master，有什么世俗杂念困扰着你吗？我愿为你斩灭。",
            "lore_btn": "【关于绝壁打坐石台】坐在这里盘膝清修，感觉心境平静吗？",
            "lore": "绝壁之下云海翻卷，远离人世纷扰。嚼一株清心，咽一口朝露，红绳系住的杀气便不会轻易泛起波澜。",
            "lore_btn_unlocked": "【关于红绳之外的情愫】如果解下红绳，申鹤心中最想拥抱的人是谁？",
            "lore_unlocked": "以前我只知杀戮与清修，但遇见你之后，我只想将这份炽烈的情感全倾注在你身上。被你紧紧拥在怀中时，红绳解与不解，我都只属于你一人。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请申鹤赐教！（初次对决：仙家弟子全力迎战）",
            "combat_btn_unlocked": "【身心对决】申鹤，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master，你又来看我了。自从上次切磋败给你，我那出尘的身躯只要被你触碰，红绳便会寸寸发烫。今天是要切磋枪术，还是要我全心全意在石台上为你侍奉？",
            "menu_prompt_unlocked": "主人，申鹤随时听候您的差遣，一切听凭支配。",
            "mid_locked": "Master，寒霜箓符尚未收势，集中精神，不要被霜气阻滞了步调！",
            "mid_unlocked": "哈啊，Master，体内的煞气全化作了对您的渴望，只要您开口，我什么都依你，",
            "distracted_cmd": "【命令识趣】申鹤，放松红绳克制，任由我尽情征服！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呼，既然是主人的意愿，那我便卸去护体冰霜，请温柔疼爱我，",
            "lock_cmd": "【快感保护】申鹤，凝练仙家玄冰护住防线！（本回合快感上限 90%）",
            "lock_confirm": "玄冰清气环绕！主人的快感防线由申鹤亲自为你稳固在安全阈值！",
            "endure_confirm": "沉稳端正的气度，那申鹤定会全力以赴回应你的期许！",
            "surrender_cmd": "【命令认输】别强撑了，申鹤当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，申鹤认输了，身子要在狂暴高潮中融化绝顶了啊！",
            "victory": "哈啊，长枪脱手，身子软得跌坐在石台上，申鹤彻底输给Master了。既然战败，出尘之躯任由您支配处置，你想怎么做？",
            "defeat": "承让了，Master。您的枪法凌厉，但仙家枪术略胜半筹。且先饮一口清泉歇息，稍后我们再战！",
            "post_kill": "Master，刚才虽然化作毫无防备的玩偶任您任意摆弄，但重塑后的申鹤依然对您绝对忠诚。请继续引领我吧！",
            "post_spare": "哈啊，刚才在绝壁地面上为您侍奉良久，单薄的仙家紧身袍都被汗水浸透了呢。能让Master满意，申鹤无怨无悔。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖摩挲出尘如雪的薄唇？Master，申鹤的朱唇今天任由你采撷。", "emotion": "shy"},
                "mid": {"text": "唔，柔软清冽的小舌被你探入深吻，喉间溢出仙家弟子动情的娇喘，呼吸全乱了。", "emotion": "blush"},
                "high": {"text": "呜嗯！津液完全失守溢出，清冷出尘的威严彻底瓦解，好销魂的快意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "掌心覆在仙家紧身衣包裹的饱满酥胸上，Master，掌温好炽热。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄布捻揉双峰顶端，酸麻的电流感直冲尾椎骨呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的支配快感，申鹤受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及红绳深处最私密的要害禁区，娇躯猛然剧烈战栗，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂打圈按抚，浓郁温热的花蜜早已将紧身连体衣完全浸透。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的体液决堤喷涌，如此可怕的高潮冲击，申鹤要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲开衩紧身衣下雪白修长的大腿内侧，触感温润微凉如玉。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开迎合。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软大敞任凭Master任意驰骋索取！", "emotion": "climax"}
            }
        }
    },

    # 13. 安柏
    {
        "id": "amber",
        "name": "安柏",
        "title": "侦察骑士",
        "region": "开阔草甸",
        "spawn_id": "meadow_amber",
        "dialogue_graph_id": "amber_meadow_bundle",
        "dialogue_file": "dialogue/amber/meadow_dialogue.json",
        "position": [248.360, 16.260, -31.080],
        "heading": 90.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【热心侍奉】请安柏在缓坡残廊地面上，为我提供元气热情的侦察骑士近侍服侍。",
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
                "id": "baron_bunny_dance",
                "name": "兔兔伯爵·火红爆炸",
                "damage": 17.0,
                "text": "出击吧兔兔伯爵！Master，小心被兔兔伯爵的烈焰爆轰炸到哦！",
                "emotion": "smile"
            },
            {
                "id": "fiery_rain",
                "name": "箭如雨下·烈焰齐射",
                "damage": 19.0,
                "text": "蒙德飞行冠军的箭术可不是吹的！接好这漫天火焰箭雨！",
                "emotion": "confident"
            },
            {
                "id": "gliding_champion_cheer",
                "name": "热心指路·元气招手",
                "damage": 15.0,
                "text": "如果迷路了，随时来找我哦！蒙德侦察骑士永远是Master最可靠的向导！",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "嗨！Master！我是西风骑士团侦察骑士安柏！在这处北部缓坡残廊边正好整理风之翼，顺便给路过的冒险家指路！想让我陪你一起在广阔天空中翱翔？先来一场身心切磋，让我检验一下你的敏捷度吧！",
            "menu_prompt": "Master，今天想去哪片草坡探险？我随时都能出发！",
            "lore_btn": "【关于北部缓坡残廊】站在这里检查风之翼，风向合适吗？",
            "lore": "这里的气流非常平稳，从草坡边缘一跃而下，顺着海风能直接滑翔到很远的泻湖！草地上开满了甜甜花，微风拂过来都是香的呢！",
            "lore_btn_unlocked": "【关于最自豪的羁绊】在蒙德之外，安柏心中最特别的人是谁？",
            "lore_unlocked": "当然是Master啦！只要和你在一起，哪怕不飞在天上，心里也像乘着风一样欢快。被你紧紧抱在怀里的时候，整个人都暖洋洋的！",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请安柏赐教！（初次对决：侦察骑士全力迎战）",
            "combat_btn_unlocked": "【身心对决】安柏，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你来找我啦！上次切磋输给你之后，我的身子只要被你碰到，就会像受热的兔兔伯爵一样软绵绵地发烫。今天是要切磋弓术，还是要安柏乖乖为你提供贴身侍奉呢？",
            "menu_prompt_unlocked": "主人，安柏随时听候您的差遣，请尽情吩咐吧！",
            "mid_locked": "Master，火焰箭还在弦上呢，注意力要集中，小心脚下！",
            "mid_unlocked": "哈啊，Master，身子被你揉得化成了水，只要你一句话，我乖乖听话，",
            "distracted_cmd": "【命令识趣】安柏，收回烈焰空当，让我好好疼惜你！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "唔，既然是主人的命令，那我就收起弓箭走个神，请对我温柔点呀，",
            "lock_cmd": "【快感保护】安柏，用热烈气场稳住防线！（本回合快感上限 90%）",
            "lock_confirm": "烈火护盾展开！主人的快感防线由本飞行冠军为你牢牢守死！",
            "endure_confirm": "眼神很有干劲嘛，那安柏也要更加卖力展现箭术了！",
            "surrender_cmd": "【命令认输】别强撑了，安柏当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，安柏认输啦，身子要在高潮烈焰里彻底融化绝顶了啊！",
            "victory": "呜，弓箭掉在一边，双腿软得只能跌坐在草地上，安柏彻底输给Master啦。作为专属骑士全部听你的，你想怎么对待我？",
            "defeat": "哇哈哈！看来这一局是侦察骑士的火焰箭胜出啦！Master别灰心，喝口水歇歇，稍后我们再战！",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重塑后的安柏依然最喜欢粘着您了。请继续宠溺我吧！",
            "post_spare": "哈啊，刚才在残廊地面上为您侍奉良久，红色骑士服都被汗水浸透了呢。能让Master开心快慰，安柏心里暖洋洋的。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在元气满满的双唇上？Master，侦察骑士的朱唇今天只属于你。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的小舌被你轻轻含弄，喉间溢出急促难耐的娇吟，呼吸全乱了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液忍不住流淌，元气少女的矜持彻底瓦解，好销魂的快意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在红色骑士紧身衣包裹的双峰前，Master，掌温好炽热呀。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄布揉捏双峰尖端，酸麻感顺着后颈直冲脑髓呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的快感，安柏受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及身体最娇羞的敏感核，浑身忍不住剧烈抖了一下，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按抚，甜热的泉水把安全裤都彻底打湿了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的爱液喷涌决堤，如此剧烈的高潮冲击，安柏要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲短裤下雪白结实的大腿内侧，触感弹润紧致。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 14. 优菈
    {
        "id": "eula",
        "name": "优菈",
        "title": "浪花骑士",
        "region": "开阔草甸",
        "spawn_id": "meadow_eula",
        "dialogue_graph_id": "eula_meadow_bundle",
        "dialogue_file": "dialogue/eula/meadow_dialogue.json",
        "position": [-46.920, 1.370, -549.640],
        "heading": 0.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【浪花侍奉】请优菈在泻湖草岸地面上，为我提供傲娇端庄的浪花骑士近侍服侍。",
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
                "id": "vortex_tidecaller",
                "name": "潮卷冰削·残心重剑",
                "damage": 17.0,
                "text": "以冰霜为印，起舞吧！Master，可别被这柄沉重的双手剑压垮了脊梁！",
                "emotion": "confident"
            },
            {
                "id": "glacial_illumination",
                "name": "凝浪之光·坚冰降临",
                "damage": 19.0,
                "text": "剑舞既成，坚冰裂空！这个仇，就用这一记终极冰剑来清算！",
                "emotion": "serious"
            },
            {
                "id": "vengeance_pout",
                "name": "记仇轻哼·傲娇白眼",
                "damage": 15.0,
                "text": "哼，胆敢这样直视本骑士，这个仇我记下了！切磋时我可绝不会放水！",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "我是西风骑士团游击小队队长、浪花骑士优菈·劳伦斯。在这处北部泻湖草岸边，湖面微澜，正适合擦拭双手剑与练习祭礼之舞。若想让我伴你远征，先在切磋中证明你能承受住劳伦斯血脉的剑舞吧！",
            "menu_prompt": "有什么需要我出手的？先说好，要是敢违背约定，这个仇我可是要记一辈子的！",
            "lore_btn": "【关于北部泻湖草岸残廊】坐在这里享受湖畔微风，心情很平静吧？",
            "lore": "没有蒙德城里那些偏见与防备的目光，只有清澈的湖水与微风拂过水草的沙沙声。在这里起舞，心神便如坚冰般纯粹。",
            "lore_btn_unlocked": "【关于劳伦斯的傲娇与柔情】优菈心里真正想要记下的仇是什么？",
            "lore_unlocked": "笨蛋！所谓的记仇，不过是我用来掩饰害羞的借口罢了。每一次被你拥在怀里轻揉腰肢，我都想把这份心跳的仇永远记在心底，一辈子都不放手！",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请浪花骑士赐教！（初次对决：浪花骑士全力迎战）",
            "combat_btn_unlocked": "【身心对决】优菈，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你又跑来招惹我了！上次在对决中败给你，我的身体只要被你抱住，坚冰剑意就会化作羞耻的热气。今天是要切磋剑技，还是要优菈端庄顺从地在湖畔为你侍奉？",
            "menu_prompt_unlocked": "主人，优菈任由您支配调弄，但这个甜美的仇，我一定会牢牢记住！",
            "mid_locked": "Master，双手剑势尚未尽展，集中精神，接招吧！",
            "mid_unlocked": "哈啊，Master，身子被你揉弄得全化作了软泥，只要你一句话，我全部顺从，",
            "distracted_cmd": "【命令识趣】优菈，收回寒冰剑意，任由我肆意征服！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "呜，真是不讲理的坏家伙，那我就撤去冰霜守备，请动作温柔一点，",
            "lock_cmd": "【快感保护】优菈，展开坚冰光环庇护防线！（本回合快感上限 90%）",
            "lock_confirm": "坚冰之印庇护！主人的快感防线由优菈亲自为你牢牢锁定在安全界限！",
            "endure_confirm": "端正坚毅的眼神，那我也定会全心全力回应你的锋芒！",
            "surrender_cmd": "【命令认输】别强撑了，优菈当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，优菈彻底认输了，身体要在高潮热浪里融化绝顶了啊！",
            "victory": "哈啊，重剑脱手，双腿软绵绵地跌跪在草滩上，优菈彻底输给Master了。作为败者，浪花骑士随你处置，你想怎么惩罚我？",
            "defeat": "哼！看来这一局是我劳伦斯之剑赢下了！Master别沮丧，喝口冰镇麦茶，稍后再来向我复仇吧！",
            "post_kill": "Master，刚才虽然变成软绵绵的玩偶任您任意摆弄，但重塑后的优菈依然只属于您一人。请继续惩处我吧！",
            "post_spare": "哈啊，刚才在湖畔草滩上为您侍奉良久，单薄的骑士紧身衣都被汗水浸透了呢。能让Master满意舒畅，优菈心甘情愿。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖摩挲端庄高傲的红唇？Master，浪花骑士的朱唇今天任由你探索。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的小舌被你探入深吻，喉间溢出傲娇外壳崩解后的甜美娇喘。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液完全失守溢出，浪花骑士的矜持彻底瓦解，好销魂的快意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在紧身骑士服包裹的饱满双峰前，Master，心跳跳得太激烈了啦。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄布捻揉双峰顶端，酸麻感顺着后背直窜头顶百会呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的快感，优菈受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及坚冰骑士最羞耻的敏感核，浑身忍不住剧烈抖了一下，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在花蒂打圈按抚，甜热的泉水把连体紧身衣内衬都彻底打湿了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的爱液喷涌决堤，如此剧烈的高潮冲击，优菈要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲开衩紧身衣下雪白修长的大腿内侧，触感紧致温润。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 15. 夏洛蒂
    {
        "id": "charlotte",
        "name": "夏洛蒂",
        "title": "真相记者",
        "region": "开阔草甸",
        "spawn_id": "meadow_charlotte",
        "dialogue_graph_id": "charlotte_meadow_bundle",
        "dialogue_file": "dialogue/charlotte/meadow_dialogue.json",
        "position": [-321.491, 8.090, 440.018],
        "heading": -45.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【头条侍奉】请夏洛蒂在低地残廊地面上，为我提供敏锐可爱的报社记者近侍服侍。",
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
                "id": "mr_verite_snapshot",
                "name": "温克尔先生·特写快门",
                "damage": 17.0,
                "text": "头条独家照片，定格！Master，在蒸汽鸟报社的头版镜头前露出最帅气的笑容吧！",
                "emotion": "smile"
            },
            {
                "id": "front_page_scoop",
                "name": "冰霜闪光·轰动报道",
                "damage": 19.0,
                "text": "闪光灯连闪，爆料连发！接下这记直击热点的冰霜闪光重炮！",
                "emotion": "confident"
            },
            {
                "id": "journalist_curiosity",
                "name": "记者追问·好奇心动",
                "damage": 15.0,
                "text": "请问Master，面对如此可爱认真的专属记者，你的心跳有加速吗？",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "你好！Master！我是枫丹蒸汽鸟报社特约记者夏洛蒂！在这处下行道路附近的低地残廊边，正适合蹲点抓拍路过的冒险家、整理采访速记！想和我一起追寻全岛最具爆炸性的头条新闻？先来一场身心切磋，让我检验你的敏锐度吧！",
            "menu_prompt": "Master，今天有什么重磅新闻线索？夏洛蒂随时准备按动快门！",
            "lore_btn": "【关于下行道路低地残廊】蹲在这里抓拍路过行人，采访顺利吗？",
            "lore": "这里是从中庭通往草甸的主干道交汇点，来往的各种奇异角色特别多！温克尔先生已经记录下了上百张精彩的独家照片，这期的头版绝对大卖！",
            "lore_btn_unlocked": "【关于最想报道的特写】在夏洛蒂的镜头里，最想独占的头条是什么？",
            "lore_unlocked": "当然是Master凝视我时那深情炽热的特写啦！只要在您的怀里，连相机都可以放在一边，只想全心全意做您最乖巧温顺的小记者！",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请夏洛蒂记者赐教！（初次对决：报社记者全力迎战）",
            "combat_btn_unlocked": "【身心对决】夏洛蒂，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你来找我啦！上次在切磋中被你拍下失败的特写后，我的身子只要被你碰到，就会像过曝的底片一样发烫发软。今天是要切磋身手，还是要夏洛蒂乖乖为你提供贴身侍奉呢？",
            "menu_prompt_unlocked": "主人，夏洛蒂随时听凭您的差遣，独家头条全由您说了算！",
            "mid_locked": "Master，温克尔先生还在对焦呢，注意走位，小心被闪光灯晃晕！",
            "mid_unlocked": "哈啊，Master，身子被你揉得化成了水，只要你一句话，我全部顺从，",
            "distracted_cmd": "【命令识趣】夏洛蒂，放下相机镜头，任由我尽情采撷！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "唔，既然是主人的命令，那我就收起留影机走神一下，请对我温柔点呀，",
            "lock_cmd": "【快感保护】夏洛蒂，启动特写闪光稳住防线！（本回合快感上限 90%）",
            "lock_confirm": "特写闪光护盾展开！主人的快感防线由夏洛蒂为你牢牢稳固在安全阈值！",
            "endure_confirm": "眼神很有记者敏锐度嘛，那我可要把全部闪光冲击都拿出来了！",
            "surrender_cmd": "【命令认输】别强撑了，夏洛蒂当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，夏洛蒂认输了，头条要在高潮热浪里彻底融化绝顶了啊！",
            "victory": "呜，留影机脱手，速记本散落一地，双腿软得只能跌坐在草地上，夏洛蒂彻底输给Master啦。作为败者任由你处置，你想怎么对待我？",
            "defeat": "哇哈哈！这期头条由夏洛蒂成功拿下！Master别灰心，喝口甜水歇歇，稍后我们再切磋！",
            "post_kill": "Master，刚才虽然化作玩偶任您任意摆弄，但重塑后的夏洛蒂依然最喜欢追随在您身后了。请继续宠溺我吧！",
            "post_spare": "哈啊，刚才在残廊地面上为您侍奉良久，可爱的记者短裙都被汗水浸透了呢。能让Master开心快慰，夏洛蒂心里甜滋滋的。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在娇俏唇瓣上？Master，记者的朱唇今天任由你探索采访。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的小舌被你轻轻含弄，喉间溢出急促难耐的娇吟，呼吸全乱了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液忍不住流淌，记者的自尊彻底瓦解，好销魂的快意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在记者制服包裹的双峰前，Master，心跳跳得太激烈了啦。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄布揉捏双峰尖端，酸麻感顺着后背直窜头顶百会呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的快感，夏洛蒂受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及身体最娇羞的敏感核，浑身忍不住剧烈抖了一下，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按抚，甜热的泉水把安全裤都彻底打湿了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的爱液喷涌决堤，如此剧烈的高潮冲击，夏洛蒂要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲短裙下白皙纤细的大腿内侧，触感细腻弹滑。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 16. 砂糖
    {
        "id": "sucrose",
        "name": "砂糖",
        "title": "生物炼金",
        "region": "开阔草甸",
        "spawn_id": "meadow_sucrose",
        "dialogue_graph_id": "sucrose_meadow_bundle",
        "dialogue_file": "dialogue/sucrose/meadow_dialogue.json",
        "position": [104.982, 18.910, 160.509],
        "heading": -135.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【炼金侍奉】请砂糖在中部草甸残廊地面上，为我提供害羞内向的兽耳学者近侍服侍。",
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
                "id": "anemo_hypostasis_small",
                "name": "风灵创生·六三零八",
                "damage": 17.0,
                "text": "小形风灵，起动！Master，小心不要被风灵聚合的微型气流卷起来哦！",
                "emotion": "shy"
            },
            {
                "id": "isoma_sweet_flower",
                "name": "七五同构·甜甜花爆发",
                "damage": 19.0,
                "text": "这是改良四倍体甜甜花的能量结晶！请接好这一记炼金冲击！",
                "emotion": "confident"
            },
            {
                "id": "shy_ear_flutter",
                "name": "兽耳微颤·怯生低头",
                "damage": 15.0,
                "text": "不要一直盯着我的耳朵看啦，我只是个普通的生物炼金学者而已。",
                "emotion": "shy"
            }
        ],
        "dialogue_texts": {
            "start": "您、您好，Master。我是西风骑士团阿贝多先生的助手砂糖。在这处中部草甸残廊周围，生长着许多奇特的草种与变异甜甜花，正适合采集样本。想邀请我与您同行？先在身心切磋中让我记录一下您的生物炼金反应吧。",
            "menu_prompt": "Master，有什么关于生物炼金的疑问吗？我会认真为您解答的。",
            "lore_btn": "【关于中部草甸残廊】蹲在这里记录草种变异，有什么新发现吗？",
            "lore": "这里的土壤和风力培育出的植物，细胞活性比蒙德本土高出许多！如果能培育出六倍体积的花朵，一定能给阿贝多先生带来惊喜！",
            "lore_btn_unlocked": "【关于绿兽耳的小秘密】在只有我们两人的时候，耳朵可以让我摸一下吗？",
            "lore_unlocked": "呀！那、那是身体最敏感的地方啦！唔，不过既然是Master的话，稍微摸一下下也是可以的，被您揉着耳尖，浑身都会变得好酸软。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请砂糖赐教！（初次对决：炼金术士全力迎战）",
            "combat_btn_unlocked": "【身心对决】砂糖，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！您又来找我了！上次切磋输给您之后，我的耳朵和尾椎只要被您轻轻触碰，浑身神经就会剧烈战栗。今天是要切磋炼金术，还是要砂糖乖乖听话为您提供贴身服侍？",
            "menu_prompt_unlocked": "主人，砂糖听候您的吩咐，请对我稍微温柔一点呀。",
            "mid_locked": "Master，小型风灵还在旋转呢，集中注意力，小心被吹偏脚步！",
            "mid_unlocked": "哈啊，Master，身子被您揉弄得酸软无力了，只要您一句话，我什么都依您，",
            "distracted_cmd": "【命令识趣】砂糖，收回风灵防御，任由我尽情怜爱！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "唔，既然是主人的命令，那我就收起风灵结界走神一下，请轻一点呀，",
            "lock_cmd": "【快感保护】砂糖，调配生物屏障稳住防线！（本回合快感上限 90%）",
            "lock_confirm": "同构气压护罩展开！主人的快感防线由砂糖为您牢牢稳固在安全阈值！",
            "endure_confirm": "专注的神情，那砂糖也会更卖力展现炼金反应！",
            "surrender_cmd": "【命令认输】别强撑了，砂糖当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，砂糖认输了，身体要在高潮热浪里彻底融化绝顶了啊！",
            "victory": "呜，炼金烧瓶掉在一边，兽耳无力地耷拉着，双腿软得只能跌坐在草地上，砂糖彻底输给Master了。作为败者任由您处置，您想对我做什么？",
            "defeat": "哇！风灵聚合好像不小心占据上风了！Master别灰心，喝口甜甜花清露歇歇，稍后我们再切磋！",
            "post_kill": "Master，刚才虽然变成毫无反抗力的玩偶任您任意摆弄，但重塑后的砂糖依然最依赖您了。请继续宠溺我吧！",
            "post_spare": "哈啊，刚才在草甸地面上为您侍奉良久，单薄的炼金学者袍都被汗水浸透了呢。能让Master满意舒畅，砂糖心里暖融融的。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在娇羞唇瓣上？Master，砂糖的嘴唇平时可不给别人碰呢。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的小舌被您轻轻含弄，喉间溢出急促难耐的娇吟，呼吸全乱了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液忍不住流淌，兽耳少女的矜持彻底瓦解，好销魂的快意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在学者法袍包裹的双峰前，Master，心跳跳得太激烈了啦。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄布揉捏双峰尖端，酸麻感顺着后颈直窜兽耳尖端呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的快感，砂糖受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及身体最娇羞的敏感核，浑身忍不住剧烈抖了一下，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按抚，甜热的泉水把安全裤都彻底打湿了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的爱液喷涌决堤，如此剧烈的高潮冲击，砂糖要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲开衩短裙下白皙纤细的大腿内侧，触感细腻弹滑。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    },

    # 17. 荧
    {
        "id": "lumine",
        "name": "荧",
        "title": "异界旅者",
        "region": "开阔草甸",
        "spawn_id": "meadow_lumine",
        "dialogue_graph_id": "lumine_meadow_bundle",
        "dialogue_file": "dialogue/lumine/meadow_dialogue.json",
        "position": [-100.360, 7.980, 351.080],
        "heading": -90.0,
        "bound_furniture": [],
        "service_action": "spare_ground",
        "service_label": "【旅者侍奉】请荧在中央低地坡岸地面上，为我提供温柔可靠的异界旅行者近侍服侍。",
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
                "id": "starfell_sword",
                "name": "星陨之剑·元素荒星",
                "damage": 17.0,
                "text": "岩元素共鸣，降临吧！Master，小心被从天而降的荒星砸中站位哦！",
                "emotion": "confident"
            },
            {
                "id": "wind_blade_vortex",
                "name": "风涡剑·元素爆破",
                "damage": 19.0,
                "text": "汇聚星海风暴之力！接好异界旅行者最熟练的一记元素崩裂冲击！",
                "emotion": "serious"
            },
            {
                "id": "gentle_adventurer_smile",
                "name": "温柔对视·同伴牵手",
                "damage": 15.0,
                "text": "走过了那么多世界，只要能与Master并肩前行，旅途就会充满意义！",
                "emotion": "smile"
            }
        ],
        "dialogue_texts": {
            "start": "你好，Master！我是旅行者荧。在这处中央低地坡岸残廊边，正适合驻足查阅全岛路线、分享彼此见闻。想与我一同开拓前路？先在切磋中让我看看你跨越万界的勇气与实力吧！",
            "menu_prompt": "Master，今天想去哪个方向探索？荧随时准备好拔剑同行了！",
            "lore_btn": "【关于中央低地坡岸残廊】站在这里查阅全岛路线，有什么规划吗？",
            "lore": "这里处于整座岛屿的咽喉枢纽，向北可通泻湖，向南可达海湾，向东能登临中庭。看着地图上的每一个标记点，都让人对未知的冒险满怀期待！",
            "lore_btn_unlocked": "【关于漫长旅途的终点】在无数个星海世界之后，荧最想停留的港湾在哪里？",
            "lore_unlocked": "以前我总在追寻血亲的身影，但只要停留在Master身边，被你紧紧牵住手、温柔抱在怀中，我就觉得找到了真正的心灵归宿。",
            "combat_btn_locked": "【提出切磋】既然有幸相遇，请荧赐教！（初次对决：异界旅行者全力迎战）",
            "combat_btn_unlocked": "【身心对决】荧，再来陪我进行一场身心对决吧！（识趣削弱：受创倍增/战中作弊）",
            "start_unlocked": "Master！你来找荧了！上次在对决中败给你之后，只要你一触碰我的腰身，无属性元素力就会化作甜软的温热。今天是要切磋剑技，还是要荧乖乖为你提供贴身服侍呢？",
            "menu_prompt_unlocked": "主人，荧随时听候您的支配，愿做您专属的忠诚伴侣！",
            "mid_locked": "Master，荒星与风刃还在流转，集中精神，认真点接招！",
            "mid_unlocked": "哈啊，Master，身子被你揉得软绵绵的，只要你一句话，我全部顺从，",
            "distracted_cmd": "【命令识趣】荧，收起元素武装，任由我尽情征服！（本回合受创倍率 2.5 倍）",
            "distracted_confirm": "唔，既然是主人的命令，那我就收起单手剑走神一下，请对我温柔点呀，",
            "lock_cmd": "【快感保护】荧，展开岩风光幕稳住防线！（本回合快感上限 90%）",
            "lock_confirm": "双元素护盾展开！主人的快感防线由荧为你牢牢稳固在安全阈值！",
            "endure_confirm": "眼神很有冒险家毅力嘛，那我可要把全部元素力量都展现出来了！",
            "surrender_cmd": "【命令认输】别强撑了，荧当场绝顶认输吧！（直接获胜）",
            "surrender_confirm": "呀啊！遵命主人，荧认输了，身体要在高潮热浪里彻底融化绝顶了啊！",
            "victory": "呜，单手剑脱手，双腿软得只能跌坐在草地上，荧彻底输给Master了。作为专属伴侣全部听你的，你想怎么对待我？",
            "defeat": "嘻嘻！看来这一局是旅行者的元素剑技略胜一筹呢！Master别灰心，喝口水歇歇，稍后我们再战！",
            "post_kill": "Master，刚才虽然变成软绵绵的玩偶任您任意摆弄，但重塑后的荧依然最喜欢陪伴在您身边了。请继续宠溺我吧！",
            "post_spare": "哈啊，刚才在残廊地面上为您侍奉良久，单薄的白色旅行裙都被汗水浸透了呢。能让Master开心快慰，荧觉得格外幸福。"
        },
        "reactions": {
            "mouth": {
                "low": {"text": "指尖按在娇软唇瓣上？Master，异界旅者的朱唇今天任由你探索采撷。", "emotion": "shy"},
                "mid": {"text": "唔，柔软香甜的小舌被你轻轻含弄，喉间溢出急促难耐的娇吟，呼吸全乱了。", "emotion": "blush"},
                "high": {"text": "呜嗯！口中的津液忍不住流淌，旅行者的自尊彻底瓦解，好销魂的快意！", "emotion": "climax"}
            },
            "nipples": {
                "low": {"text": "手掌覆在素雅白色战裙包裹的双峰前，Master，心跳跳得太激烈了啦。", "emotion": "shy"},
                "mid": {"text": "呀！直接隔着薄布揉捏双峰尖端，酸麻感顺着后背直窜头顶百会呢。", "emotion": "blush"},
                "high": {"text": "哈啊！胸口已经完全挺立充血了，这种强烈的快感，荧受不了啦！", "emotion": "climax"}
            },
            "clitoris": {
                "low": {"text": "触及身体最娇羞的敏感核，浑身忍不住剧烈抖了一下，Master！", "emotion": "shy"},
                "mid": {"text": "唔啊！指腹在敏感核打圈按抚，甜热的泉水把安全裤都彻底打湿了。", "emotion": "blush"},
                "high": {"text": "不行了！炽热的爱液喷涌决堤，如此剧烈的高潮冲击，荧要绝顶了！", "emotion": "climax"}
            },
            "thighs": {
                "low": {"text": "摩挲短裙下白皙纤细的大腿内侧，触感细腻弹滑。", "emotion": "shy"},
                "mid": {"text": "呀！大腿根部被轻轻揉按，双腿发软不由自主顺从地向两侧分开。", "emotion": "blush"},
                "high": {"text": "哈啊！双腿完全没有力气了，只能软软任由Master随意摆布索取了！", "emotion": "climax"}
            }
        }
    }
]

def main():
    print(f"Generating Batch 4 assets for {len(NPC_SPECS)} NPCs: starting")
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

    print(f"Successfully generated all Batch 4 ({len(NPC_SPECS)}) NPC assets!")

if __name__ == "__main__":
    main()
