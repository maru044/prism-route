"""Extract and convert 20 selected Koikatsu BetterRepack RX22 H animations
into shared humanoid `.tres` resources (`skeleton_world_rest_delta` +
`physical_pelvis_rest_delta_metres`) and register them in
`assets/characters/mmd_validation/paired/catalog.json`.
"""
import csv
import hashlib
import json
import math
import pathlib
import struct
import sys
import types
import zlib

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, r"C:\Users\PC\AppData\Local\Temp\prism-unitypy")
sys.modules.setdefault("etcpak", types.ModuleType("etcpak"))

import UnityPy  # noqa: E402
from build_motion_review import close_walk_loop, numbers, quaternion, slerp  # noqa: E402

KK_ABDATA = pathlib.Path(r"D:\参考资料\KK\[ScrewThisNoise] Koikatsu BetterRepack RX22\abdata")
KK_CSV = pathlib.Path(r"D:\Prism Route\research\Koikatsu RX22 动作\游戏内动作索引.csv")
PAIRED_DIR = ROOT / "assets/characters/mmd_validation/paired"
CATALOG_PATH = PAIRED_DIR / "catalog.json"

FPS = 30
FRAME_COUNT = 41  # frames 0..40 -> 1.33333333s

BONE_MAP = {
    "Hips": "cf_j_waist02",
    "BodyRoot": "cf_j_hips",
    "Spine": "cf_j_spine01",
    "Chest": "cf_j_spine02",
    "UpperChest": "cf_j_spine03",
    "Neck": "cf_j_neck",
    "Head": "cf_j_head",
}
for _side, _sfx in [("Left", "_L"), ("Right", "_R")]:
    BONE_MAP[f"{_side}Shoulder"] = f"cf_j_shoulder{_sfx}"
    BONE_MAP[f"{_side}UpperArm"] = f"cf_j_arm00{_sfx}"
    BONE_MAP[f"{_side}LowerArm"] = f"cf_j_forearm01{_sfx}"
    BONE_MAP[f"{_side}Hand"] = f"cf_j_hand{_sfx}"
    BONE_MAP[f"{_side}UpperLeg"] = f"cf_j_thigh00{_sfx}"
    BONE_MAP[f"{_side}LowerLeg"] = f"cf_j_leg01{_sfx}"
    BONE_MAP[f"{_side}Foot"] = f"cf_j_foot{_sfx}"
    BONE_MAP[f"{_side}Toes"] = f"cf_j_toes{_sfx}"
    BONE_MAP[f"{_side}ThumbMetacarpal"] = f"cf_j_thumb01{_sfx}"
    BONE_MAP[f"{_side}ThumbProximal"] = f"cf_j_thumb02{_sfx}"
    BONE_MAP[f"{_side}ThumbDistal"] = f"cf_j_thumb03{_sfx}"
    for _finger in ("Index", "Middle", "Ring", "Little"):
        _fn = _finger.lower()
        BONE_MAP[f"{_side}{_finger}Proximal"] = f"cf_j_{_fn}01{_sfx}"
        BONE_MAP[f"{_side}{_finger}Intermediate"] = f"cf_j_{_fn}02{_sfx}"
        BONE_MAP[f"{_side}{_finger}Distal"] = f"cf_j_{_fn}03{_sfx}"

PROFILES = {
    "keqing": ("角色 A · 刻晴", "res://assets/characters/mmd_validation/keqing_physics.vrm"),
    "ganyu": ("角色 B · 甘雨", "res://assets/characters/mmd_validation/paired/ganyu_physics.vrm"),
    "huahuo": ("角色 C · 花火", "res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm"),
}

SPECS = [
    {
        "slug": "sakiname",
        "table": "animationinfo_01",
        "id": "5",
        "raw_name": "先舐め＋竿舐め",
        "state": "M_WLoop1",
        "title_zh": "轻柔舔弄前戏",
        "category": "foreplay",
        "category_zh": "前戏侍奉",
        "prop_needed": "地面 / 地毯（坐跪前戏）",
        "desc": "以轻柔舔弄与浅尝为主的温和口部前戏循环，适合战斗初段挑逗阶段与近距表情特写。",
        "roles_desc": {"A": "侍奉女方 - 俯身专注前端与柱身轻柔舔弄", "B": "受役男方 (竿役) - 坐姿自然前倾接受前戏"},
    },
    {
        "slug": "ryoutekoki",
        "table": "animationinfo_01",
        "id": "2",
        "raw_name": "両手コキ",
        "state": "M_WLoop1",
        "title_zh": "面对面双手手交",
        "category": "foreplay",
        "category_zh": "前戏侍奉",
        "prop_needed": "地面 / 坐垫（面对面手口配合）",
        "desc": "区别于背后拥抱手交，双方正面相对并可进行双手协同挤压与眼神交流的前戏循环。",
        "roles_desc": {"A": "侍奉女方 - 跪于身前用双手包覆上下抚弄", "B": "受役男方 (竿役) - 正面坐姿承受双手包覆刺激"},
    },
    {
        "slug": "nohand_fera",
        "table": "animationinfo_01",
        "id": "42",
        "raw_name": "立ちノーハンドフェラ",
        "state": "M_WLoop1",
        "title_zh": "站姿无手纯口交",
        "category": "oral",
        "category_zh": "口交侍奉",
        "prop_needed": "地面（站立与跪姿）",
        "desc": "侍奉方双手背在身后或完全不借手扶，仅靠唇舌吞吐侍奉站立中的对象，服从反差感强。",
        "roles_desc": {"A": "侍奉女方 - 双膝跪地不用手部扶握、纯口唇吞吐", "B": "受役男方 (竿役) - 站立低头俯视侍奉过程"},
    },
    {
        "slug": "isu_matagari_fera",
        "table": "animationinfo_01",
        "id": "50",
        "raw_name": "椅子またがりフェラ",
        "state": "M_WLoop1",
        "title_zh": "跨坐椅子俯身口交",
        "category": "oral",
        "category_zh": "口交侍奉",
        "prop_needed": "单人椅 / 座椅（座高 ~0.42m）",
        "desc": "侍奉方跨坐在对方腿前椅沿上贴近俯身吞吐，身体贴合度与互动亲密感比单纯跪姿更高。",
        "roles_desc": {"A": "侍奉女方 - 跨坐对方膝前俯身贴近口部侍奉", "B": "受役男方 (竿役) - 端坐椅上仰身承受"},
    },
    {
        "slug": "tachi_paizuri_kuwae",
        "table": "animationinfo_01",
        "id": "47",
        "raw_name": "立ちパイズリ+咥え",
        "state": "M_WLoop1",
        "title_zh": "站姿夹胸兼含吮",
        "category": "oral",
        "category_zh": "口交侍奉",
        "prop_needed": "地面（站姿高低配）",
        "desc": "填补既有卧姿之外的站立胸前侍奉，侍奉方蹲跪夹紧胸部的同时配合唇部含吮。",
        "roles_desc": {"A": "侍奉女方 - 半蹲挟紧胸部并抬头配合口部含吮", "B": "受役男方 (竿役) - 站立扶肩俯视"},
    },
    {
        "slug": "oshitsuke_paizuri",
        "table": "animationinfo_01",
        "id": "13",
        "raw_name": "押し付けパイズリ",
        "state": "M_WLoop1",
        "title_zh": "贴身压迫乳交",
        "category": "foreplay",
        "category_zh": "前戏侍奉",
        "prop_needed": "地面 / 低榻",
        "desc": "主动将前端压入柔软胸壑间紧密滑动的高主导感前戏循环，完整双方同框。",
        "roles_desc": {"A": "侍奉女方 - 聚拢双峰仰承贴合滑动", "B": "施力男方 (竿役) - 上身前压主导节奏"},
    },
    {
        "slug": "mitchaku_tekoki",
        "table": "animationinfo_01",
        "id": "52",
        "raw_name": "密着手コキ",
        "state": "M_WLoop1",
        "title_zh": "站姿贴身耳语手交",
        "category": "foreplay",
        "category_zh": "前戏侍奉",
        "prop_needed": "地面（站姿并肩贴近）",
        "desc": "双方站立极近距离贴身相依，一手扶抱耳边低语、一手施以节律抚弄，很适合搭配战中聊天。",
        "roles_desc": {"A": "侍奉女方 - 紧贴肩侧轻语并进行手部刺激", "B": "受役男方 (竿役) - 站立微倚身旁"},
    },
    {
        "slug": "tanetsuke_press",
        "table": "animationinfo_02",
        "id": "23",
        "raw_name": "種付けプレス",
        "state": "M_WLoop1",
        "title_zh": "深压折腿正常位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "prop_needed": "地面 / 大床",
        "desc": "以全身重心向下深压的强主导型正常位，压迫感与插入深度感明显强于常规仰卧。",
        "roles_desc": {"A": "受纳女方 - 仰卧抬腿曲膝承受下压", "B": "施力男方 (竿役) - 俯身重心下压深顶推进"},
    },
    {
        "slug": "manguri_seijoui",
        "table": "animationinfo_02",
        "id": "24",
        "raw_name": "マングリ正常位",
        "state": "M_WLoop1",
        "title_zh": "M字折叠压腿正常位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "prop_needed": "地面 / 大床",
        "desc": "将受纳方双腿大幅折向胸口呈全折叠造型，肢体张力与立体轮廓极具特写观赏性。",
        "roles_desc": {"A": "受纳女方 - 双腿高折压胸完全展开", "B": "施力男方 (竿役) - 托压折叠双腿深位推进"},
    },
    {
        "slug": "udehippari_kouhai",
        "table": "animationinfo_02",
        "id": "3",
        "raw_name": "腕引っ張り後背位",
        "state": "M_WLoop1",
        "title_zh": "拉臂掌控后背位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "prop_needed": "地面 / 大床",
        "desc": "在后背位基础上手持拉住对方手臂牵制动作，支配感与动态拉扯力远超一般跪趴。",
        "roles_desc": {"A": "受纳女方 - 双臂被向后牵引俯身承受", "B": "施力男方 (竿役) - 自后拽臂控场推进"},
    },
    {
        "slug": "neback",
        "table": "animationinfo_02",
        "id": "26",
        "raw_name": "寝バック",
        "state": "M_WLoop1",
        "title_zh": "贴床俯卧后背位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "prop_needed": "地面 / 双人床面",
        "desc": "把受纳方完全压趴在床面或地板上的紧密贴合后背位，体感沉重亲密。",
        "roles_desc": {"A": "受纳女方 - 完全俯趴延展承受", "B": "施力男方 (竿役) - 自上贴脊覆盖推进"},
    },
    {
        "slug": "isu_taimen",
        "table": "animationinfo_02",
        "id": "9",
        "raw_name": "椅子対面",
        "state": "M_WLoop1",
        "title_zh": "椅子面对面抱坐位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "prop_needed": "单人椅 / 座椅",
        "desc": "坐在椅子上面对面紧抱起伏的交合体位，和既有背面 Lap Sitting 刚好构成正反双拼。",
        "roles_desc": {"A": "跨坐女方 - 面对面环抱肩颈上下起伏", "B": "受座男方 (竿役) - 稳坐椅面双臂揽抱腰臀"},
    },
    {
        "slug": "isu_back",
        "table": "animationinfo_02",
        "id": "11",
        "raw_name": "椅子バック",
        "state": "M_WLoop1",
        "title_zh": "扶椅背站姿后背位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "prop_needed": "单人椅 / 椅背支撑",
        "desc": "站姿状态下双手撑扶椅背的前倾后背位，适配神殿石椅与建筑栏杆锚点。",
        "roles_desc": {"A": "受纳女方 - 双手扶稳椅背翘臀迎合", "B": "施力男方 (竿役) - 站立扶胯从后推进"},
    },
    {
        "slug": "sofa_kijoui",
        "table": "animationinfo_02",
        "id": "27",
        "raw_name": "ソファ騎乗位",
        "state": "M_WLoop1",
        "title_zh": "沙发／长榻骑乘位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "prop_needed": "沙发 / 软榻 / 单人椅",
        "desc": "专为客厅沙发、长榻及休息长椅打造的坐姿上方骑乘循环，双腿自然垂落倚靠。",
        "roles_desc": {"A": "骑乘女方 - 上方跨坐主动摆腰律动", "B": "坐卧男方 (竿役) - 后仰靠于沙发扶承腰侧"},
    },
    {
        "slug": "tsukue_nei",
        "table": "animationinfo_02",
        "id": "13",
        "raw_name": "机寝位",
        "state": "M_WLoop1",
        "title_zh": "桌面仰卧站插位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "prop_needed": "长案桌 / 桌面（~0.80m 高度）",
        "desc": "让受纳方仰躺到案桌表面、主导方站在桌前高腿进入，与扶桌背向 TSFB V2 正反互补。",
        "roles_desc": {"A": "受纳女方 - 仰躺于桌面抬腿承接", "B": "施力男方 (竿役) - 站在桌沿双手分扶推进"},
    },
    {
        "slug": "kabe_taimen_ashiage",
        "table": "animationinfo_02",
        "id": "17",
        "raw_name": "壁対面片足上げ",
        "state": "M_WLoop1",
        "title_zh": "壁咚抬单腿面对面位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "prop_needed": "墙面 / 立柱（壁靠交互）",
        "desc": "依托墙面或石柱把女方一条腿高抬架起进行正面站插，极具戏剧壁咚张力。",
        "roles_desc": {"A": "受纳女方 - 背倚墙壁单腿高抬钩腰", "B": "施力男方 (竿役) - 贴近壁面单手托腿正面推进"},
    },
    {
        "slug": "kabe_back_ashiage",
        "table": "animationinfo_02",
        "id": "19",
        "raw_name": "片足上げ壁バック",
        "state": "M_WLoop1",
        "title_zh": "扶墙抬单腿后背位",
        "category": "intercourse",
        "category_zh": "本番性爱",
        "prop_needed": "墙面 / 立柱（壁靠交互）",
        "desc": "单手扶墙保持平衡同时高抬一条腿接受背后站插，与正面壁咚形成完整墙面正反双拼。",
        "roles_desc": {"A": "受纳女方 - 扶墙单脚独立另一腿悬空抬起", "B": "施力男方 (竿役) - 站立后方托扶大腿推进"},
    },
    {
        "slug": "isu_kunni",
        "table": "animationinfo_05",
        "id": "1",
        "raw_name": "椅子クンニ",
        "state": "M_WLoop",
        "title_zh": "双女椅子百合舔阴",
        "category": "yuri",
        "category_zh": "百合协同",
        "prop_needed": "单人椅 / 座椅",
        "desc": "一位女伴仰坐椅上敞腿、另一位女伴跪伏腿间亲吻舔弄的上下立体百合前戏。",
        "roles_desc": {"A": "侍奉方 - 跪趴椅子前俯首细腻舔弄", "B": "受侍方 - 分腿倚坐椅上仰首喘息"},
    },
    {
        "slug": "tagai_ijiri",
        "table": "animationinfo_05",
        "id": "2",
        "raw_name": "互い弄り",
        "state": "MM_WLoop",
        "title_zh": "站姿双女相互爱抚",
        "category": "yuri",
        "category_zh": "百合协同",
        "prop_needed": "地面（站姿贴近）",
        "desc": "两位女性站立面对面零距离贴靠并同步彼此挑逗爱抚，补齐站立态百合互动。",
        "roles_desc": {"A": "百合角色 1 - 紧靠回应并同步手部挑逗", "B": "百合角色 2 - 贴身前探与对方交替爱抚"},
    },
    {
        "slug": "kijoui_kunni",
        "table": "animationinfo_07",
        "id": "0",
        "raw_name": "騎乗位クンニ",
        "state": "M_WLoop1",
        "title_zh": "3P 骑乘兼坐脸舔弄",
        "category": "threesome",
        "category_zh": "多人协同",
        "prop_needed": "地面 / 大床",
        "desc": "三位角色同时参与的进阶 3P 组合：一人仰卧、一人上方骑乘、第三位协同进行上下方舔弄互动。",
        "roles_desc": {"A": "主控骑乘女方 - 跨坐腰腹主动律动", "B": "受役男方 (竿役) - 仰卧地面承接骑乘与坐颜双线刺激", "C": "协同侍奉女方 - 俯身在侧同步舔弄辅助"},
    },
]


def unity_to_godot_pos(p):
    return np.array([-p[0], p[1], p[2]], dtype=float)


def unity_to_godot_quat(q):
    x, y, z, w = q
    n = (x * x + y * y + z * z + w * w) ** 0.5 or 1.0
    return np.array([x / n, -y / n, -z / n, w / n], dtype=float)


def q_to_m(q):
    x, y, z, w = q
    n = (x * x + y * y + z * z + w * w) ** 0.5 or 1.0
    x, y, z, w = x / n, y / n, z / n, w / n
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def trs_m(p, q, s):
    m = np.eye(4)
    m[:3, :3] = q_to_m(q) @ np.diag(s)
    m[:3, 3] = p
    return m


def worlds(locals_list, parents):
    res = [None] * len(locals_list)

    def get(i):
        if res[i] is None:
            res[i] = locals_list[i] if parents[i] < 0 else get(parents[i]) @ locals_list[i]
        return res[i]

    for i in range(len(locals_list)):
        get(i)
    return res


def load_prefab(env, objs, root_name):
    root_go = next(o.read_typetree() for o in env.objects if o.type.name == "GameObject" and o.read().m_Name == root_name)
    tr_id = next(c["component"]["m_PathID"] for c in root_go["m_Component"] if objs[c["component"]["m_PathID"]].type.name == "Transform")
    nodes = []
    hash_to_idx = {}
    name_to_idx = {}

    def walk(tid, parent_idx):
        t = objs[tid].read_typetree()
        go = objs[t["m_GameObject"]["m_PathID"]].read_typetree()
        name = go["m_Name"]
        rel_path = "" if parent_idx < 0 else (name if parent_idx == 0 else (nodes[parent_idx]["rel_path"] + "/" + name))
        idx = len(nodes)
        pos = [t["m_LocalPosition"]["x"], t["m_LocalPosition"]["y"], t["m_LocalPosition"]["z"]]
        rot = [t["m_LocalRotation"]["x"], t["m_LocalRotation"]["y"], t["m_LocalRotation"]["z"], t["m_LocalRotation"]["w"]]
        scl = [t["m_LocalScale"]["x"], t["m_LocalScale"]["y"], t["m_LocalScale"]["z"]]
        nodes.append({"idx": idx, "parent": parent_idx, "name": name, "rel_path": rel_path, "pos": pos, "rot": rot, "scl": scl})
        hash_to_idx[zlib.crc32(rel_path.encode("utf-8")) & 0xFFFFFFFF] = idx
        name_to_idx[name] = idx
        for ch in t["m_Children"]:
            walk(ch["m_PathID"], idx)

    walk(tr_id, -1)
    parents = [n["parent"] for n in nodes]
    rest_locals = [trs_m(unity_to_godot_pos(n["pos"]), unity_to_godot_quat(n["rot"]), n["scl"]) for n in nodes]
    rest_w = worlds(rest_locals, parents)
    return nodes, hash_to_idx, name_to_idx, rest_w


def decode_streamed_clip(sc_dict, num_curves):
    raw = struct.pack("<" + "I" * len(sc_dict["data"]), *sc_dict["data"])
    frames = []
    off = 0
    while off < len(raw):
        t, count = struct.unpack_from("<fI", raw, off)
        off += 8
        entries = {}
        for _ in range(count):
            idx, c0, c1, c2, c3 = struct.unpack_from("<Iffff", raw, off)
            entries[idx] = (c0, c1, c2, c3)
            off += 20
        frames.append((t, entries))
    curves = [[] for _ in range(num_curves)]
    for t, entries in frames:
        for idx, coeffs in entries.items():
            curves[idx].append((t, coeffs))
    return curves


def eval_clip_worlds(nodes, hash_to_idx, tree, times):
    mc = tree["m_MuscleClip"]
    clip = mc["m_Clip"]["data"]
    sc, dc, cc = clip["m_StreamedClip"], clip["m_DenseClip"], clip["m_ConstantClip"]
    gb = tree["m_ClipBindingConstant"]["genericBindings"]
    n_s, n_d = sc["curveCount"], dc["m_CurveCount"]
    s_curves = decode_streamed_clip(sc, n_s)
    d_samples = np.array(dc["m_SampleArray"], dtype=float).reshape(dc["m_FrameCount"], n_d)
    d_sr, d_begin = dc["m_SampleRate"], dc["m_BeginTime"]
    c_data = cc["data"]
    attr_sizes = {1: 3, 2: 4, 3: 3}
    targets = []
    ci = 0
    for b in gb:
        sz = attr_sizes[b["attribute"]]
        idx = hash_to_idx.get(b["path"])
        if idx is not None:
            targets.append((idx, b["attribute"], ci, sz))
        ci += sz
    parents = [n["parent"] for n in nodes]

    def sample_curve(c_idx, t):
        if c_idx < n_s:
            segs = s_curves[c_idx]
            best = segs[0]
            for s in segs:
                if s[0] <= t + 1e-7:
                    best = s
                else:
                    break
            t0, (c0, c1, c2, c3) = best
            dt = max(0.0, t - t0)
            return ((c0 * dt + c1) * dt + c2) * dt + c3
        elif c_idx < n_s + n_d:
            di = c_idx - n_s
            f_pos = (t - d_begin) * d_sr
            f0 = int(np.clip(np.floor(f_pos), 0, dc["m_FrameCount"] - 1))
            f1 = min(f0 + 1, dc["m_FrameCount"] - 1)
            alpha = np.clip(f_pos - f0, 0.0, 1.0)
            return d_samples[f0, di] * (1.0 - alpha) + d_samples[f1, di] * alpha
        else:
            return c_data[c_idx - n_s - n_d]

    pose_worlds = []
    for t in times:
        cur_p = [list(n["pos"]) for n in nodes]
        cur_q = [list(n["rot"]) for n in nodes]
        cur_s = [list(n["scl"]) for n in nodes]
        for idx, attr, ci0, sz in targets:
            vals = [sample_curve(ci0 + k, float(t)) for k in range(sz)]
            if attr == 1:
                cur_p[idx] = vals
            elif attr == 2:
                cur_q[idx] = vals
            elif attr == 3:
                cur_s[idx] = vals
        locs = [trs_m(unity_to_godot_pos(cur_p[i]), unity_to_godot_quat(cur_q[i]), cur_s[i]) for i in range(len(nodes))]
        pose_worlds.append(worlds(locs, parents))
    return pose_worlds


def smooth_periodic_quats(q_arr):
    """Make q_arr[0] == q_arr[-1] and C1-continuous across wrap on frames [0..2, N-2..N]."""
    q = q_arr.copy()
    n = len(q) - 1
    for i in range(1, len(q)):
        if np.dot(q[i - 1], q[i]) < 0:
            q[i] = -q[i]
    # Align end toward start along shortest hemisphere
    q_end = q[n] if np.dot(q[0], q[n]) >= 0 else -q[n]
    q_mid = slerp(q[0], q_end, 0.5)
    # Periodic midpoint velocity direction around seam: align q[n-1] to q_end
    q_nm1 = q[n - 1] if np.dot(q[n - 1], q_end) >= 0 else -q[n - 1]
    q_1 = q[1] if np.dot(q[1], q[0]) >= 0 else -q[1]
    # Tangent step half across [n-1 -> 1]
    q_2step = slerp(q_nm1, q_1, 0.5)
    # Push q[1] and q[n-1] slightly toward constant-velocity around q_mid
    # q_target_1 = q_mid * (q_2step^{-1} * q_1) ~ symmetric offset:
    inv_q2 = np.array([-q_2step[0], -q_2step[1], -q_2step[2], q_2step[3]])
    # Small periodic smoothing weights over boundary 3 frames
    q[0] = q_mid
    q[n] = q_mid if np.dot(q[n - 1], q_mid) >= 0 else -q_mid
    # Blend start shoulder
    for idx, w_end, w_vel in [(1, 0.65, 0.5), (2, 0.25, 0.0)]:
        # endpoint continuity pull
        target = slerp(q[idx], slerp(q_mid, q_1, idx / 2.0), w_end)
        if idx == 1 and w_vel > 0:
            # match angular step size & direction across wrap
            step = slerp(q_nm1, q_1, 0.5)
            # q_mid + (step - q_nm1) ≈ 2*q_mid - q_nm1 linearized -> use slerp reflection
            # Reflect q_nm1 across q_mid: q_refl = 2*dot(q_nm1, q_mid)*q_mid - q_nm1
            d = np.dot(q_nm1, q_mid)
            q_refl = (2.0 * d * q_mid - q_nm1)
            q_refl /= np.linalg.norm(q_refl)
            sym_1 = slerp(q_1, q_refl, 0.5)
            target = slerp(target, sym_1, 0.5)
        q[idx] = target
    for offset, w_end in [(1, 0.65), (2, 0.25)]:
        idx = n - offset
        q_target = q[n]
        base = q[idx] if np.dot(q[idx], q_target) >= 0 else -q[idx]
        target = slerp(base, slerp(q_target, base, 0.5 if offset == 1 else 0.75), w_end)
        if offset == 1:
            q_new_1 = q[1] if np.dot(q[1], q_mid) >= 0 else -q[1]
            d = np.dot(q_new_1, q_mid)
            q_refl_m1 = 2.0 * d * q_mid - q_new_1
            q_refl_m1 /= np.linalg.norm(q_refl_m1)
            if np.dot(q_refl_m1, q[n]) < 0:
                q_refl_m1 = -q_refl_m1
            target = q_refl_m1
        q[idx] = target
    # Final re-sign alignment across all frames
    for i in range(1, len(q)):
        if np.dot(q[i - 1], q[i]) < 0:
            q[i] = -q[i]
    return q


def smooth_periodic_pos(p_arr):
    p = p_arr.copy()
    n = len(p) - 1
    p_mid = 0.5 * (p[0] + p[n])
    p[0] = p_mid
    p[n] = p_mid
    # Blend frame 2 & n-2 smoothly first
    d0 = p_mid - p_arr[0]
    dn = p_mid - p_arr[n]
    p[2] = p_arr[2] + 0.25 * d0
    p[n - 2] = p_arr[n - 2] + 0.25 * dn
    # Match velocity at seam using central difference from interior
    v = 0.5 * (p_arr[1] - p_arr[n - 1])
    p[1] = p_mid + v
    p[n - 1] = p_mid - v
    return p


def write_kk_clip(tres_name, times, rest_w, pose_w, name_to_idx, source_meta, out_path, *, hermite_loop=False):
    pelvis = name_to_idx["cf_j_waist02"]
    height = abs(float(rest_w[pelvis][1, 3]))
    assert height > 0.1
    lines = [
        '[gd_resource type="Animation" format=3]',
        "",
        "[resource]",
        f'resource_name = "{tres_name}"',
        f"length = {times[-1]:.9g}",
        "loop_mode = 1",
        "metadata/shared_humanoid_schema = 1",
        f"metadata/reference_height = {height:.9g}",
        f'metadata/source = "{source_meta}"',
        'metadata/rotation_space = "skeleton_world_rest_delta"',
        'metadata/translation_space = "physical_pelvis_rest_delta_metres"',
    ]
    rotations = {}
    for semantic, kk_bone in BONE_MAP.items():
        bi = name_to_idx[kk_bone]
        r_inv = np.linalg.inv(rest_w[bi][:3, :3])
        rotations[semantic] = np.asarray([quaternion(pw[bi][:3, :3] @ r_inv) for pw in pose_w])
    raw_trans = np.asarray([pw[pelvis][:3, 3] - rest_w[pelvis][:3, 3] for pw in pose_w], dtype=float)
    if hermite_loop:
        rotations, trans = close_walk_loop(times, rotations, raw_trans)
    else:
        rotations = {bone: smooth_periodic_quats(values) for bone, values in rotations.items()}
        trans = smooth_periodic_pos(raw_trans)

    track = 0
    for semantic, values in rotations.items():
        q_arr = np.asarray(values)
        for i in range(1, len(q_arr)):
            if np.dot(q_arr[i - 1], q_arr[i]) < 0:
                q_arr[i] = -q_arr[i]
        is_constant = np.max(np.minimum(np.linalg.norm(q_arr - q_arr[0], axis=1), np.linalg.norm(q_arr + q_arr[0], axis=1))) < 1e-7
        use_times = times[:1] if is_constant else times
        use_vals = q_arr[:1] if is_constant else q_arr
        keys = np.column_stack((use_times, np.ones(len(use_times)), use_vals))
        lines += [
            f'tracks/{track}/type = "rotation_3d"',
            f'tracks/{track}/path = NodePath("GeneralSkeleton:{semantic}")',
            f"tracks/{track}/interp = 1",
            f"tracks/{track}/loop_wrap = false",
            f"tracks/{track}/keys = PackedFloat32Array({numbers(keys.ravel())})",
        ]
        track += 1

    keys = np.column_stack((times, np.ones(len(times)), trans))
    lines += [
        f'tracks/{track}/type = "position_3d"',
        f'tracks/{track}/path = NodePath("GeneralSkeleton:Hips")',
        f"tracks/{track}/interp = 1",
        f"tracks/{track}/loop_wrap = false",
        f"tracks/{track}/keys = PackedFloat32Array({numbers(keys.ravel())})",
    ]
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    # Verify exact periodic continuity
    pos_seam = float(np.linalg.norm(trans[0] - trans[-1]))
    vel_seam = float(np.linalg.norm((trans[1] - trans[0]) - (trans[-1] - trans[-2])))
    assert pos_seam < 1e-7 and vel_seam < 1e-7, (tres_name, pos_seam, vel_seam)
    return out_path.stat().st_size, height


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    PAIRED_DIR.mkdir(parents=True, exist_ok=True)

    env_base = UnityPy.load(str(KK_ABDATA / "chara/oo_base.unity3d"))
    objs_base = {o.path_id: o for o in env_base.objects}
    prefabs = {
        "male": load_prefab(env_base, objs_base, "p_cm_body_00"),
        "female": load_prefab(env_base, objs_base, "p_cf_body_bone"),
    }

    rows_by_key = {}
    with KK_CSV.open("r", encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            rows_by_key[(r["分类表"], r["条目ID"], r["原始显示名"])] = r

    bundle_cache = {}

    def get_bundle(rel):
        if rel not in bundle_cache:
            bundle_cache[rel] = UnityPy.load(str(KK_ABDATA / rel))
        return bundle_cache[rel]

    def find_clip(act_bundle, act_ctrl, state_name):
        env_b = get_bundle(act_bundle)
        objs_b = {o.path_id: o for o in env_b.objects}
        for o in env_b.objects:
            if o.type.name == "AnimatorOverrideController":
                d = o.read()
                if d.m_Name == act_ctrl:
                    for ov in d.m_Clips:
                        if ov.m_OriginalClip.read().m_Name == state_name:
                            wc = ov.m_OverrideClip.read()
                            return objs_b[wc.path_id].read_typetree(), wc.path_id
            elif o.type.name == "AnimatorController":
                d = o.read()
                if d.m_Name == act_ctrl:
                    for cp in d.m_AnimationClips:
                        c = cp.read()
                        if c.m_Name == state_name:
                            return objs_b[c.path_id].read_typetree(), c.path_id
        raise KeyError(f"{act_bundle}#{act_ctrl}/{state_name} not found")

    times = np.linspace(0.0, (FRAME_COUNT - 1) / FPS, FRAME_COUNT)
    new_packs = []
    new_entries = []
    total_bytes = 0

    for spec in SPECS:
        row = rows_by_key[(spec["table"], spec["id"], spec["raw_name"])]
        raw_roles = []
        for col in ("角色A（包 / 控制器）", "角色B（包 / 控制器）", "角色C（包 / 控制器）"):
            s = row[col].strip()
            if not s:
                continue
            act_part = [p.strip() for p in s.split("|") if p.strip().startswith("动作")][0]
            act_bundle, act_ctrl = [x.strip() for x in act_part.split(" ", 1)[1].split(" / ")]
            raw_roles.append((act_bundle, act_ctrl))

        # Project convention (matching all existing MMD packs + first-person Role B):
        # Role A (keqing) = Female (serving/receiving/riding), i.e., CSV slot B (raw_roles[1])
        # Role B (ganyu) = Male / 竿役 / seated receiver, i.e., CSV slot A (raw_roles[0])
        # Role C (huahuo, 3P only) = Companion Female, i.e., CSV slot C (raw_roles[2])
        if len(raw_roles) == 2:
            raw_roles = [raw_roles[1], raw_roles[0]]
        elif len(raw_roles) == 3:
            raw_roles = [raw_roles[1], raw_roles[0], raw_roles[2]]

        # Assign sequential slot IDs A, B (or A, B, C)
        pack_id = f"kk_{spec['slug']}"
        roles_json = []
        source_tracks = []
        profile_order = ["keqing", "ganyu", "huahuo"]
        for i, (act_bundle, act_ctrl) in enumerate(raw_roles):
            rid = chr(65 + i)  # A, B, C
            rsfx = rid.lower()
            tres_name = f"{pack_id}_{rsfx}"
            out_path = PAIRED_DIR / f"{tres_name}.tres"
            gender = "male" if "/male/" in act_bundle else "female"
            prefab_name = "p_cm_body_00" if gender == "male" else "p_cf_body_bone"
            nodes, h2i, n2i, rest_w = prefabs[gender]

            tree, pid = find_clip(act_bundle, act_ctrl, spec["state"])
            pose_w = eval_clip_worlds(nodes, h2i, tree, times)
            source_meta = f"Koikatsu RX22/abdata/{act_bundle}#{act_ctrl}/{spec['state']}"
            bsize, _ = write_kk_clip(tres_name, times, rest_w, pose_w, n2i, source_meta, out_path)
            total_bytes += bsize

            bundle_sha = hashlib.sha256((KK_ABDATA / act_bundle).read_bytes()).hexdigest()
            source_tracks.append(
                {
                    "file": f"{act_bundle}/{act_ctrl} · {spec['state']}",
                    "bundle": act_bundle,
                    "controller": act_ctrl,
                    "state": spec["state"],
                    "path_id": str(pid),
                    "prefab": prefab_name,
                    "sha256": bundle_sha,
                }
            )
            prof_id = profile_order[i]
            prof_label, prof_model = PROFILES[prof_id]
            roles_json.append(
                {
                    "id": rid,
                    "label": prof_label,
                    "profile": prof_id,
                    "model": prof_model,
                    "motion": f"res://assets/characters/mmd_validation/paired/{tres_name}.tres",
                    "report": "res://assets/characters/mmd_validation/paired/catalog.json",
                    "shared": True,
                    "translation_policy": "shared_world",
                    "presentation_offset": [0, 0, 0],
                    "label_zh": spec["roles_desc"][rid],
                }
            )

        people_prefix = "三人" if len(roles_json) == 3 else "双人"
        display_label = f"【{spec['category_zh']}】{spec['title_zh']} ({spec['raw_name']} · KK)"
        pack_obj = {
            "id": pack_id,
            "label": f"{spec['raw_name']} · Koikatsu",
            "title_zh": spec["title_zh"],
            "category": spec["category"],
            "category_zh": spec["category_zh"],
            "display_label": display_label,
            "description_zh": spec["desc"],
            "placement": {
                "type": "ground",
                "type_zh": "共享世界原点",
                "base_height": 0.0,
                "ground_offset": 0.0,
                "prop_needed": spec["prop_needed"],
            },
            "roles_desc": spec["roles_desc"],
            "duration": 40.0 / 30.0,
            "frame_start": 0,
            "frame_end": 40,
            "source_tracks": source_tracks,
            "roles": roles_json,
            "selected": True,
            "shared": True,
            "loop_preview": True,
            "seamless_loop": True,
        }
        entry_obj = {
            "id": f"{pack_id}_all",
            "pack": pack_id,
            "label": f"{people_prefix} · {spec['raw_name']} · Koikatsu",
            "roles": [r["id"] for r in roles_json],
            "kind": "入选动作",
            "title_zh": spec["title_zh"],
            "category": spec["category"],
            "category_zh": spec["category_zh"],
            "display_label": display_label,
        }
        new_packs.append(pack_obj)
        new_entries.append(entry_obj)
        print(f"BUILT {pack_id} ({len(roles_json)} roles, state={spec['state']})")

    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    new_pack_ids = {p["id"] for p in new_packs}
    new_entry_ids = {e["id"] for e in new_entries}
    catalog["packs"] = [p for p in catalog["packs"] if p["id"] not in new_pack_ids] + new_packs
    catalog["entries"] = [e for e in catalog["entries"] if e["id"] not in new_entry_ids] + new_entries
    CATALOG_PATH.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"DONE: {len(new_packs)} packs, {sum(len(p['roles']) for p in new_packs)} clips, {total_bytes} bytes total")


if __name__ == "__main__":
    main()
