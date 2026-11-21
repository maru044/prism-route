# -*- coding: utf-8 -*-
"""Comprehensive Generator for all 44 remaining NPC Wildcards in Prism Route.

Adheres strictly to the ZERO ELLIPSES RULE (no ellipsis characters anywhere).
"""

import copy
import json
import os
from pathlib import Path
import re
import sys

REPO_ROOT = Path(r"d:\Prism Route\prism-route")
DATA_DIR = REPO_ROOT / "assets" / "ai" / "local_airp"
EXP_DIR = REPO_ROOT / "experiments" / "local_airp"

def check_no_ellipses(obj, label: str):
    text = json.dumps(obj, ensure_ascii=False)
    for bad in ["\u2026", "...", "\u2026\u2026"]:
        if bad in text:
            raise ValueError(f"Ellipsis found in {label}: {bad}")

# Load base archetypes
with open(DATA_DIR / "wildcards_sparkle.json", encoding="utf-8") as f:
    BASE_SPARKLE = json.load(f)
with open(DATA_DIR / "wildcards_keqing.json", encoding="utf-8") as f:
    BASE_KEQING = json.load(f)
with open(DATA_DIR / "wildcards_raiden_shogun.json", encoding="utf-8") as f:
    BASE_RAIDEN = json.load(f)
with open(DATA_DIR / "wildcards_kafka.json", encoding="utf-8") as f:
    BASE_KAFKA = json.load(f)
with open(DATA_DIR / "wildcards_firefly.json", encoding="utf-8") as f:
    BASE_FIREFLY = json.load(f)

BASE_MAP = {
    "sparkle": BASE_SPARKLE,
    "keqing": BASE_KEQING,
    "raiden_shogun": BASE_RAIDEN,
    "kafka": BASE_KAFKA,
    "firefly": BASE_FIREFLY
}

BASE_META = {
    "sparkle": {"name": "花火", "title": "假面愚者", "weapon": "狐狸面具", "self": "人家", "addr": "小主人"},
    "keqing": {"name": "刻晴", "title": "玉衡星", "weapon": "随身佩剑", "self": "我", "addr": "Master"},
    "raiden_shogun": {"name": "雷电将军", "title": "神明", "weapon": "梦想一心", "self": "此身", "addr": "汝"},
    "kafka": {"name": "卡芙卡", "title": "星核猎手", "weapon": "乌兹冲锋枪", "self": "姐姐我", "addr": "小可爱"},
    "firefly": {"name": "流萤", "title": "格拉默铁骑", "weapon": "变身器", "self": "流萤", "addr": "开拓者"}
}

def transform_text(text: str, base_type: str, char_cfg: dict) -> str:
    name = char_cfg["name"]
    title = char_cfg["title"]
    weapon = char_cfg["weapon"]
    self_ref = char_cfg["self_refs"][0]
    addr = char_cfg["addresses"][0]
    
    t = text
    if base_type == "sparkle":
        t = t.replace("花火我", self_ref).replace("本愚者", self_ref).replace("人家", self_ref)
        t = t.replace("花火", name).replace("假面愚者", title).replace("愚者", title)
        t = t.replace("狐狸面具", weapon).replace("狐尾", char_cfg.get("body_part", "发丝"))
        t = t.replace("小主人", addr).replace("笨蛋旅行者", addr)
    elif base_type == "keqing":
        t = t.replace("刻晴", name).replace("玉衡星", title).replace("随身佩剑", weapon).replace("剑鞘", weapon)
        t = t.replace("旅行者", addr).replace("黑丝双马尾", char_cfg.get("body_part", "发丝"))
    elif base_type == "raiden_shogun":
        t = t.replace("雷电将军", name).replace("将军", name).replace("梦想一心", weapon)
        t = t.replace("神明", title).replace("稻妻", "领地").replace("雷霆", "威势")
        t = t.replace("此身", self_ref).replace("神躯", "身躯")
        t = t.replace("永恒的见证者", addr).replace("无礼之徒", addr)
    elif base_type == "kafka":
        t = t.replace("卡芙卡", name).replace("星核猎手", title).replace("乌兹冲锋枪", weapon)
        t = t.replace("姐姐我", self_ref).replace("丝绒手套", char_cfg.get("clothing", "衣袖"))
        t = t.replace("小可爱", addr).replace("亲爱的", addr)
    elif base_type == "firefly":
        t = t.replace("流萤", name).replace("格拉默铁骑", title).replace("变身器", weapon)
        t = t.replace("机体冷却", "体温").replace("机甲", char_cfg.get("clothing", "衣衫"))
        t = t.replace("开拓者", addr)
    return t

def transform_obj(obj, base_type: str, char_cfg: dict):
    if isinstance(obj, str):
        return transform_text(obj, base_type, char_cfg)
    elif isinstance(obj, list):
        return [transform_obj(item, base_type, char_cfg) for item in obj]
    elif isinstance(obj, dict):
        return {k: transform_obj(v, base_type, char_cfg) for k, v in obj.items()}
    return obj

def build_character_wildcard(char_cfg: dict) -> dict:
    base_type = char_cfg["archetype"]
    base_data = BASE_MAP[base_type]
    data = copy.deepcopy(base_data)
    
    # 1. Base info
    data["character_id"] = char_cfg["id"]
    data["addresses"] = char_cfg["addresses"]
    data["self_refs"] = char_cfg["self_refs"]
    
    # 2. Deep transform generic texts
    data["reactions_home"] = transform_obj(data["reactions_home"], base_type, char_cfg)
    data["reactions_intimate"] = transform_obj(data["reactions_intimate"], base_type, char_cfg)
    data["reactions_combat"] = transform_obj(data["reactions_combat"], base_type, char_cfg)
    data["actions_combat"] = transform_obj(data["actions_combat"], base_type, char_cfg)
    data["dialogues"] = transform_obj(data["dialogues"], base_type, char_cfg)
    data["followups_home"] = transform_obj(data["followups_home"], base_type, char_cfg)
    data["followups_intimate"] = transform_obj(data["followups_intimate"], base_type, char_cfg)
    
    # 3. Inject custom actions
    if "custom_actions_home" in char_cfg:
        data["actions_home"] = char_cfg["custom_actions_home"]
    else:
        data["actions_home"] = transform_obj(data["actions_home"], base_type, char_cfg)
        
    if "custom_actions_intimate" in char_cfg:
        data["actions_intimate"] = char_cfg["custom_actions_intimate"]
    else:
        data["actions_intimate"] = transform_obj(data["actions_intimate"], base_type, char_cfg)
        
    # 4. Inject key customized lines
    if "custom_greet" in char_cfg:
        data["dialogues"]["greet"] = char_cfg["custom_greet"]
    if "custom_tease" in char_cfg:
        data["dialogues"]["tease"] = char_cfg["custom_tease"]
    if "custom_compliment" in char_cfg:
        data["dialogues"]["compliment"] = char_cfg["custom_compliment"]
    if "custom_meal" in char_cfg:
        data["dialogues"]["home_meal_share"] = char_cfg["custom_meal"]
    if "custom_patrol" in char_cfg:
        data["dialogues"]["home_patrol_work"] = char_cfg["custom_patrol"]
    if "custom_surrender" in char_cfg:
        data["dialogues"]["combat_surrender"] = char_cfg["custom_surrender"]
        
    # Check no ellipses
    check_no_ellipses(data, char_cfg["id"])
    return data

print("Generator engine setup complete!")

from tools.roster_character_configs import ROSTER_CONFIGS

def main():
    print("=" * 60)
    print("Starting Batch Generation for 44 Roster NPCs...")
    print("=" * 60)
    
    generated_count = 0
    for cfg in ROSTER_CONFIGS:
        cid = cfg["id"]
        cname = cfg["name"]
        print(f"Generating wildcard for {cname} ({cid})...")
        wildcard_data = build_character_wildcard(cfg)
        
        # Target paths
        target_assets = DATA_DIR / f"wildcards_{cid}.json"
        target_exp = EXP_DIR / f"wildcards_{cid}.json"
        
        content = json.dumps(wildcard_data, ensure_ascii=False, indent=2)
        target_assets.write_text(content, encoding="utf-8")
        target_exp.write_text(content, encoding="utf-8")
        generated_count += 1
        
    print("=" * 60)
    print(f"SUCCESS: Generated {generated_count} character wildcards with 0 ellipses!")
    print("=" * 60)

if __name__ == "__main__":
    main()
