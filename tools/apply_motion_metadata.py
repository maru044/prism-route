import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

METADATA = {
    "mmd_0a3f6ba5f5de": {
        "title_zh": "床沿仰卧胸部侍奉",
        "category": "foreplay",
        "category_zh": "前戏互动",
        "placement": {
            "type": "bed",
            "type_zh": "床沿/软榻",
            "base_height": 0.45,
            "ground_offset": 0.0,
            "prop_needed": "床沿 / 软榻边沿 (高度 ~0.45m，竿役半躺床面，双腿下垂)"
        },
        "roles_desc": {
            "A": "侍奉方 (女) - 双膝跪于床前地面，俯身贴合侍奉",
            "B": "竿役受纳方 (男) - 仰躺/半靠于床沿，双腿微曲垂向地面"
        },
        "description_zh": "床沿仰卧亲密侍奉姿态。竿役（受纳方）半仰躺于床沿或软榻表面（依托高度约0.42m~0.48m），双腿垂向床前地面；女方双膝跪于床前地面，俯身进行温柔胸部侍奉，伴随躯干起伏与深情头部互动。本动作实际交互依托为床沿，并非单人椅。"
    },
    "mmd_16a2ecfb7781": {
        "title_zh": "双人卧榻口交侍奉",
        "category": "oral",
        "category_zh": "口交侍奉",
        "placement": {
            "type": "ground",
            "type_zh": "地面/低床",
            "base_height": 0.0,
            "ground_offset": 0.0,
            "prop_needed": "床铺 / 地毯 / 榻榻米 (0.00m~0.05m)"
        },
        "roles_desc": {
            "A": "施力方 (女) - 双膝跪趴在男方双腿之间执行口交侍奉",
            "B": "受役方 (男) - 平躺仰卧，双臂自然垂放"
        },
        "description_zh": "标准的卧姿亲密口交动作。男方完全平躺仰卧，女方跪趴在男方两腿之间俯首进行深情而细致的口部侍奉。虽然原名含Bed，但动作烘焙基准面在 0.00m 地面，可直接在地毯、草地、榻榻米或低矮床榻上自然播放。"
    },
    "mmd_67d58e9d607e": {
        "title_zh": "女王踩踏足交",
        "category": "foreplay",
        "category_zh": "前戏互动",
        "placement": {
            "type": "ground",
            "type_zh": "地面",
            "base_height": 0.0,
            "ground_offset": 0.0,
            "prop_needed": "地面 (0.00m)"
        },
        "roles_desc": {
            "A": "施力方 (女) - 居高临下站立，单脚踩踏抚弄",
            "B": "受役方 (男) - 平躺在地面，仰视并承受足部踩踏侍奉"
        },
        "description_zh": "极具支配感的女王踩踏足交。女方高傲站立在地面（0.00m），单脚抬起踩在男方要害处反复碾磨抚弄；男方平躺在地面仰视承受。具有极高的角色性格反差与互动张力，适合傲娇、御姐或主仆角色调教情境。"
    },
    "mmd_6e891982bb51": {
        "title_zh": "单人沉醉自慰循环",
        "category": "solo",
        "category_zh": "单人自慰",
        "placement": {
            "type": "bed",
            "type_zh": "床铺/高台",
            "base_height": 0.48,
            "ground_offset": -0.48,
            "prop_needed": "床铺 / 软垫 (高度 ~0.48m)"
        },
        "roles_desc": {
            "A": "自慰女主角 - 仰卧半倚，单手抚弄敏感处，身体起伏微颤"
        },
        "description_zh": "细腻的单人仰卧自慰循环动作。角色仰卧在床榻上，一手抚摸胸前一手轻抚腿心，伴随迷离的头部轻晃与呼吸喘息起伏。源动作依托约 0.48m 高的床面，贴地播放时可应用 -0.48m 下沉补偿贴紧草地或地毯。"
    },
    "mmd_71dec5bd8390": {
        "title_zh": "双女床沿闲坐温存",
        "category": "yuri",
        "category_zh": "百合互慰",
        "placement": {
            "type": "bed",
            "type_zh": "床沿/软榻/沙发",
            "base_height": 0.52,
            "ground_offset": -0.52,
            "prop_needed": "双人床 / 床沿 / 软榻沙发 (座高 ~0.50m~0.55m)"
        },
        "roles_desc": {
            "A": "抚弄女方 - 侧坐于床榻边缘，双脚垂地，探手轻抚身旁少女",
            "B": "受抚女方 - 倚坐于床榻，单腿屈起搭在床面，娇羞迎合手指温存"
        },
        "description_zh": "细腻的双女床沿温存爱抚。两名少女依偎在床榻或沙发边缘（座面高约0.50m~0.55m），B角色单腿屈起坐在床面娇羞迎合，A角色侧坐床沿伸手探入其双腿之间轻柔挑逗慢捻。无男性骨骼依赖，非常适合卧室大床或窗边软榻的百合私密互动。"
    },
    "mmd_aec34d147925": {
        "title_zh": "双女床榻深层爱抚",
        "category": "yuri",
        "category_zh": "百合互慰",
        "placement": {
            "type": "bed",
            "type_zh": "床铺/床沿",
            "base_height": 0.52,
            "ground_offset": -0.52,
            "prop_needed": "双人床铺 (床面高 ~0.52m，抚弄方立于床沿)"
        },
        "roles_desc": {
            "A": "受抚女方 - 仰卧在床铺上(高度0.52m)，双腿大开屈膝迎合深入",
            "B": "抚弄女方 - 坐在床沿/床边地面，俯身向床上的少女热烈抚摸"
        },
        "description_zh": "高落差的情趣双女床榻爱抚。受弄少女（A角色）整个人完全平躺仰卧在0.52m高的大床中央，双腿大开屈膝起伏；抚弄少女（B角色）坐在床沿或床边，俯身将手探向床上少女腿心深入快速抽送爱抚。非常适合卧室内大床的深度百合前戏。"
    },
    "mmd_781d8c87fd79": {
        "title_zh": "沙发端坐受纳口交",
        "category": "oral",
        "category_zh": "口交侍奉",
        "placement": {
            "type": "seat",
            "type_zh": "座椅/沙发",
            "base_height": 0.48,
            "ground_offset": 0.0,
            "prop_needed": "单人沙发 / 靠背扶手椅 (座高 ~0.45m~0.48m)"
        },
        "roles_desc": {
            "A": "侍奉方 (女) - 双膝跪地(0.00m)，微仰头为主人进行深情口交侍奉",
            "B": "受役方 (男) - 端坐于单人沙发/靠椅(骨盆0.51m)，双手自然扶倚享受侍奉"
        },
        "description_zh": "长达140秒的超豪华主仆口交过场全流程。男方端坐于单人沙发/靠椅上（骨盆高0.51m，适配座高0.45m~0.48m，双脚自然踩地），女方双膝跪地（地面0.00m），包含从前期手部轻抚调情平滑推进到深情跪地口交侍奉的完整叙事演出。非常适合作为主线推进、养成达成或专属Cutscene的极品坐姿侍奉动作。"
    },
    "mmd_9957977a1355": {
        "title_zh": "双女百合磨豆腐",
        "category": "yuri",
        "category_zh": "百合互慰",
        "placement": {
            "type": "ground",
            "type_zh": "地面",
            "base_height": 0.0,
            "ground_offset": 0.0,
            "prop_needed": "地面 / 软垫 (0.00m)"
        },
        "roles_desc": {
            "A": "百合女方 1 - 平躺屈腿，骨盆与对方紧密交错相贴",
            "B": "百合女方 2 - 跨交相拥，双腿交错磨蹭摩擦"
        },
        "description_zh": "极其珍稀的纯百合贴面摩擦（Tribadism / 磨豆腐）。两位女主角在地面上双腿交错、跨部紧紧贴合在一起，通过骨盆的辗转研磨与相互摩擦达到高潮。无任何外置模型或男性依赖，是纯正双女角色的顶级浪漫资产。"
    },
    "mmd_fcc0340f8227": {
        "title_zh": "站姿受纳跪地侍奉",
        "category": "oral",
        "category_zh": "口交侍奉",
        "placement": {
            "type": "ground",
            "type_zh": "地面",
            "base_height": 0.0,
            "ground_offset": 0.0,
            "prop_needed": "地面 (0.00m)"
        },
        "roles_desc": {
            "A": "侍奉女方 - 双膝跪地，仰头专注口交侍奉",
            "B": "站立男方 - 挺立在地面，低头抚摸女方头部"
        },
        "description_zh": "高低位差强烈的经典站跪口交。男方自然站立在地面（0.00m），女方温顺地双膝跪地仰视男方，双手环抱男方大腿深情吞吐。适合在任何走廊、墙角、野外树下随时触发，极具征服感与侍奉温情。"
    },
    "mmd_8c5c490fb87c": {
        "title_zh": "背后贴身亲密爱抚",
        "category": "intimate_daily",
        "category_zh": "日常温存",
        "placement": {
            "type": "ground",
            "type_zh": "地面",
            "base_height": 0.0,
            "ground_offset": 0.0,
            "prop_needed": "地面 (0.00m)"
        },
        "roles_desc": {
            "A": "被拥女方 - 亭亭玉立，感受背后传来的温度与抚弄",
            "B": "环抱方 - 从背后贴身环抱，双手在胸腹间游移探抚"
        },
        "description_zh": "站姿背后温存贴身爱抚。男方从后方完全贴住女方后背，下巴抵在女方肩颈处，双臂环绕在其腰腹与胸前缓缓游移抚摸；女方微微后仰依偎在怀中。既可作为日常拥抱亲昵，也可作为情挑前戏。"
    },
    "mmd_beee0d2eb57b": {
        "title_zh": "坐姿膝上怀抱把玩",
        "category": "intimate_daily",
        "category_zh": "日常温存",
        "placement": {
            "type": "seat",
            "type_zh": "座椅/沙发/床沿",
            "base_height": 0.48,
            "ground_offset": 0.0,
            "prop_needed": "沙发 / 椅子 / 床沿 (座高 ~0.45m~0.50m)"
        },
        "roles_desc": {
            "A": "受役女方 - 被主人宠溺抱在膝头怀里，娇躯依偎任由随性把玩",
            "B": "主人位 (男) - 端坐于座椅或床沿，双脚踏地，怀抱少女随性扣弄把玩"
        },
        "description_zh": "深度契合设定集的坐姿怀抱温存常驻动作。男方以主人姿态端坐在沙发、椅凳或床沿上（座高约0.48m，双脚踏地），将受役少女宠溺地抱在膝头大腿上，单手揽抱入怀，另一手随性扣弄抚弄把玩；少女娇躯微颤温顺依偎。与站姿的Loop 17形成完美的一站一坐常驻待机互补。"
    },
    "mmd_7869c66910b9": {
        "title_zh": "双女天使合璧侍奉",
        "category": "oral",
        "category_zh": "口交侍奉",
        "placement": {
            "type": "ground",
            "type_zh": "地面",
            "base_height": 0.0,
            "ground_offset": 0.20,
            "prop_needed": "地面 / 大床 (0.00m)"
        },
        "roles_desc": {
            "A": "侍奉女方 1 - 跪趴在左侧，专注亲吻抚弄",
            "B": "侍奉女方 2 - 跪趴在右侧，协同包夹挑逗",
            "C": "受役男方 - 仰面享受两位少女的左右侍奉"
        },
        "description_zh": "豪华的三人 3P 双飞口交大作。两名少女宛如双生天使般分别跪在男方身体两侧，一人主攻一人从旁协助，双手与唇齿交替侍奉。源动作手膝略微下沉 0.20m，通过 +0.20m 补偿后贴地效果绝佳。"
    },
    "mmd_87e004f6db53": {
        "title_zh": "日式温泉仰卧正常位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "placement": {
            "type": "ground",
            "type_zh": "地面/水面",
            "base_height": 0.0,
            "ground_offset": 0.0,
            "prop_needed": "地面 / 浴室 / 温泉池底 (0.00m)"
        },
        "roles_desc": {
            "A": "受役女方 - 仰卧平躺地面，双腿曲起分开迎合抽插",
            "B": "施力男方 - 双膝跪在女方两腿之间俯身撞击"
        },
        "description_zh": "最经典的仰卧面对面正常位（Missionary）。女方平躺在地面双腿架在男方腰际，男方跪姿俯身双手撑地有力律动，双方视线交汇、情感交流最充沛。基准高度完美贴紧 0.00m，适合草地、温泉、地毯等任何场景。"
    },
    "mmd_43916ffe3d35": {
        "title_zh": "双人夜色卧姿骑乘",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "placement": {
            "type": "bed",
            "type_zh": "床铺",
            "base_height": 0.52,
            "ground_offset": -0.52,
            "prop_needed": "双人床 / 席梦思 (高度 ~0.52m)"
        },
        "roles_desc": {
            "A": "受役女方 - 跨坐在男方身上，主动摇摆腰肢起伏套弄",
            "B": "施力男方 - 平躺仰卧享受女方的主动骑乘"
        },
        "description_zh": "Ademar440 殿堂级卧姿骑乘位（Cowgirl）。长达 234 秒超完整起伏过程，女方跨坐在仰卧男方身上掌握主动权，包含慢速磨蹭、深套骑乘与高潮起伏。原作依托 0.52m 床面，野外播放时启用 -0.52m 补偿即可稳坐地面。"
    },
    "mmd_2864892bd378": {
        "title_zh": "情趣后背跪趴位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "placement": {
            "type": "ground",
            "type_zh": "地面",
            "base_height": 0.0,
            "ground_offset": 0.0,
            "prop_needed": "地面 / 榻榻米 / 地毯 (0.00m)"
        },
        "roles_desc": {
            "A": "受役女方 - 双膝跪地双手撑地，臀部翘起承受后入",
            "B": "施力男方 - 跪在女方身后握住纤腰沉稳撞击"
        },
        "description_zh": "后背位（Doggy style）的王牌标准动作。女方四肢着地翘臀诱人，男方跪在身后双手扣紧女方骨盆有节奏地前后冲刺。动作循环极其流畅自然，高度精确贴紧地面 0.00m，随时随地都能展开狂野后入。"
    },
    "mmd_160b1e7a411c": {
        "title_zh": "浪漫情侣背面坐位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "placement": {
            "type": "seat",
            "type_zh": "座椅/石凳",
            "base_height": 0.42,
            "ground_offset": 0.0,
            "prop_needed": "木椅 / 石凳 / 沙发 (座高 ~0.42m)"
        },
        "roles_desc": {
            "A": "受役女方 - 背对男方坐在大腿上，腰肢随撞击上下弹动",
            "B": "施力男方 - 端坐在椅子上双脚踩地，双手环抱女方腰肢"
        },
        "description_zh": "极为浪漫的家具情侣背面坐位。男方端坐在 0.42m 高度的椅子或石凳上（双脚稳稳踩在 0.00m 地面），女方背对男方坐在其大腿上（骨盆高 0.68m），男方双手托住女方小腹与胸口，自下而上顶弄撞击。"
    },
    "mmd_1256ad646811": {
        "title_zh": "温存侧卧相拥汤匙位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "placement": {
            "type": "ground",
            "type_zh": "地面/被褥",
            "base_height": 0.0,
            "ground_offset": 0.0,
            "prop_needed": "地面 / 地毯 / 床单 (0.00m)"
        },
        "roles_desc": {
            "A": "受役女方 - 侧躺微屈双腿，背部贴紧男方胸膛迎合深入",
            "B": "施力男方 - 侧躺贴紧女方身后，单臂搂抱深情抽送"
        },
        "description_zh": "汤匙位（Spooning / 侧卧后入位）。两人像两把叠在一起的汤匙一样朝向同一侧侧躺，男方胸膛紧贴女方美背，单臂搂住女方腰身在后方缓缓抽送。温存、缠绵且体力消耗最小，极具情侣间私密耳语的温馨氛围。"
    },
    "mmd_c63e75bc7057": {
        "title_zh": "逆火车便当悬空抱操",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "placement": {
            "type": "air",
            "type_zh": "悬空抱操",
            "base_height": 0.0,
            "ground_offset": 0.0,
            "prop_needed": "无道具（男方站立承重，女方悬空 1.00m）"
        },
        "roles_desc": {
            "A": "受役女方 - 双臂勾住男方脖颈，双腿盘腰完全悬空在空中",
            "B": "施力男方 - 双脚站立地面，有力抱起女方一边走动一边深顶"
        },
        "description_zh": "震撼的逆向站姿悬空抱操（火车便当）。男方双脚稳踏地面（0.00m），依靠强大的臂力将女方整个抱离地面（女方骨盆悬空在 1.01m 处，双腿紧紧盘绕在男方腰际）。无需任何家具支撑，在野外探险或任意空地上即可凌空狂野交互！"
    },
    "mmd_fca4bab1635f": {
        "title_zh": "经典俯身扶桌后背位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "placement": {
            "type": "table",
            "type_zh": "桌面/讲台",
            "base_height": 0.82,
            "ground_offset": 0.0,
            "prop_needed": "办公桌 / 课桌 / 吧台 / 遗迹石台 (高度 0.80m~0.85m)"
        },
        "roles_desc": {
            "A": "受役女方 - 双脚立地，上半身俯伏在桌面上翘臀迎合",
            "B": "施力男方 - 站在女方身后按住细腰激烈撞击"
        },
        "description_zh": "高人气的办公室/课桌俯身扶桌后背位（Table Sex From Behind）。男女双方双脚均站立在地面（0.00m），女方上身向前俯伏在约 0.82m 高的桌台边缘，双手支撑，臀部后翘承受男方强烈的站姿后入冲刺。"
    },
    "mmd_86e40adc8f14": {
        "title_zh": "站姿相拥股间素股",
        "category": "intimate_daily",
        "category_zh": "日常温存",
        "placement": {
            "type": "ground",
            "type_zh": "地面",
            "base_height": 0.0,
            "ground_offset": 0.0,
            "prop_needed": "地面 (0.00m)"
        },
        "roles_desc": {
            "A": "亲昵女方 - 站立紧贴男方，双腿夹紧男方大腿柔情磨蹭",
            "B": "相拥男方 - 站立紧搂女方腰身，深情相拥温存摩擦"
        },
        "description_zh": "站姿紧密相拥的大腿夹蹭（素股 / Thigh service）。男女双方站立在地面（0.00m）紧紧相拥，女方将双腿夹住男方大腿内侧轻轻磨蹭，双手环抱男方颈背。动作既是深情的站立拥抱，又带有脸红心跳的素股调情，日常互动极佳。"
    }
}

def update_manifest():
    manifest_path = ROOT / "assets/characters/mmd_selected/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for p in manifest.get("packs", []):
        pid = p["id"]
        if pid in METADATA:
            meta = METADATA[pid]
            p["title_zh"] = meta["title_zh"]
            p["category"] = meta["category"]
            p["category_zh"] = meta["category_zh"]
            p["placement"] = meta["placement"]
            p["roles_desc"] = meta["roles_desc"]
            p["description_zh"] = meta["description_zh"]
            p["display_label"] = f"【{meta['category_zh']}】{meta['title_zh']} ({p['label']})"
            for r in p.get("roles", []):
                rid = r.get("id")
                if rid in meta["roles_desc"]:
                    r["label_zh"] = meta["roles_desc"][rid]
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Updated manifest.json with {len(METADATA)} metadata entries.")

def update_catalog():
    catalog_path = ROOT / "assets/characters/mmd_validation/paired/catalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    for p in catalog.get("packs", []):
        pid = p["id"]
        if pid in METADATA:
            meta = METADATA[pid]
            p["title_zh"] = meta["title_zh"]
            p["category"] = meta["category"]
            p["category_zh"] = meta["category_zh"]
            p["placement"] = meta["placement"]
            p["roles_desc"] = meta["roles_desc"]
            p["description_zh"] = meta["description_zh"]
            p["display_label"] = f"【{meta['category_zh']}】{meta['title_zh']} ({p['label']})"
            for r in p.get("roles", []):
                rid = r.get("id")
                if rid in meta["roles_desc"]:
                    r["label_zh"] = meta["roles_desc"][rid]
    for e in catalog.get("entries", []):
        pid = e.get("pack")
        if pid in METADATA:
            meta = METADATA[pid]
            e["title_zh"] = meta["title_zh"]
            e["category"] = meta["category"]
            e["category_zh"] = meta["category_zh"]
            e["display_label"] = f"【{meta['category_zh']}】{meta['title_zh']} ({e['label']})"
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Updated catalog.json with {len(METADATA)} metadata entries.")

if __name__ == "__main__":
    update_manifest()
    update_catalog()
