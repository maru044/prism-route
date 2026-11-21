# -*- coding: utf-8 -*-
"""Wildcard Composition Engine for Local AIRP Dialogue.

Implements grammatical slot-filling, character-specific voice injection,
anti-repetition ring buffers, and punctuation sanitization.
"""

from collections import deque
import json
from pathlib import Path
import random
import re

HERE = Path(__file__).resolve().parent

class WildcardComposer:
    def __init__(self, data_dir=HERE, history_capacity=4):
        self.data_dir = Path(data_dir)
        self.history_capacity = history_capacity
        self.char_cache = {}
        for f in self.data_dir.glob("wildcards_*.json"):
            cid = f.stem.replace("wildcards_", "")
            if cid != "scenes":
                try:
                    self.char_cache[cid] = json.loads(f.read_text(encoding="utf-8"))
                except Exception:
                    pass
        self.sparkle_wildcards = self.char_cache.get("sparkle", {})
        self.keqing_wildcards = self.char_cache.get("keqing", {})
        self.scenes_wildcards = json.loads((self.data_dir / "wildcards_scenes.json").read_text(encoding="utf-8"))
        
        # Ring buffer history per character and slot key
        self.slot_history = {}

    def get_character_data(self, character_id):
        if character_id in self.char_cache:
            return self.char_cache[character_id]
        custom_file = self.data_dir / f"wildcards_{character_id}.json"
        if custom_file.is_file():
            try:
                data = json.loads(custom_file.read_text(encoding="utf-8"))
                self.char_cache[character_id] = data
                return data
            except Exception:
                pass
        return self.char_cache.get("sparkle", {})

    def _resolve_pool(self, character_id, pool_path):
        char_data = self.get_character_data(character_id)
        parts = pool_path.split(".")
        root = parts[0]
        
        if root == "character":
            current = char_data
            for p in parts[1:]:
                if isinstance(current, dict) and p in current:
                    current = current[p]
                else:
                    return []
            return current if isinstance(current, list) else []
        elif root == "scene":
            current = self.scenes_wildcards
            for p in parts[1:]:
                if isinstance(current, dict) and p in current:
                    current = current[p]
                else:
                    return []
            return current if isinstance(current, list) else []
        return []

    def _pick_with_anti_repetition(self, pool_key, candidate_list, rng):
        if not candidate_list:
            return ""
        if len(candidate_list) == 1:
            return candidate_list[0]

        if pool_key not in self.slot_history:
            self.slot_history[pool_key] = deque(maxlen=self.history_capacity)

        recent = set(self.slot_history[pool_key])
        available = [item for item in candidate_list if item not in recent]

        if not available:
            # If all were used recently, pop the oldest
            if self.slot_history[pool_key]:
                self.slot_history[pool_key].popleft()
            recent = set(self.slot_history[pool_key])
            available = [item for item in candidate_list if item not in recent]
            if not available:
                available = candidate_list

        chosen = rng.choice(available)
        self.slot_history[pool_key].append(chosen)
        return chosen

    def compose(self, template_obj, character_id, scene_id, context=None, seed=None):
        if context is None:
            context = {}

        rng = random.Random(seed) if seed is not None else random.Random()
        
        templates = template_obj.get("templates", [])
        if not templates:
            raise ValueError(f"Template {template_obj.get('reply_id')} has no templates list!")

        # Pick template skeleton
        skeleton_key = f"{character_id}_{template_obj.get('reply_id')}_skeletons"
        template_str = self._pick_with_anti_repetition(skeleton_key, templates, rng)

        # Extract slot tokens
        slots_to_fill = re.findall(r"\{([a-zA-Z0-9_]+)\}", template_str)
        wildcard_slots = template_obj.get("wildcard_slots", {})

        filled_slots = {}
        for slot in slots_to_fill:
            if slot in context:
                filled_slots[slot] = str(context[slot])
                continue

            pool_path = wildcard_slots.get(slot)
            if not pool_path:
                # Default fallbacks
                if slot == "address":
                    pool_path = "character.addresses"
                elif slot == "dialogue_core":
                    content_tag = template_obj.get("content_tag", "greet")
                    pool_path = f"character.dialogues.{content_tag}"
                elif slot == "reaction":
                    pool_path = "character.reactions_intimate" if scene_id == "intimate" else "character.reactions_home"
                elif slot == "body_action":
                    pool_path = "character.actions_intimate" if scene_id == "intimate" else "character.actions_home"
                elif slot == "followup":
                    pool_path = "character.followups_intimate" if scene_id == "intimate" else "character.followups_home"
                elif slot == "atmosphere":
                    pool_path = "scene.intimate_atmosphere" if scene_id == "intimate" else "scene.home_atmosphere"
                else:
                    pool_path = f"character.{slot}"

            pool = self._resolve_pool(character_id, pool_path)
            history_key = f"{character_id}_{pool_path}"
            chosen_val = self._pick_with_anti_repetition(history_key, pool, rng)
            filled_slots[slot] = chosen_val

        # Fill the template
        composed = template_str
        for k, v in filled_slots.items():
            composed = composed.replace("{" + k + "}", v)

        # Post-process punctuation and spacing
        composed = self._sanitize_text(composed)

        return {
            "text": composed,
            "reply_id": template_obj.get("reply_id"),
            "character_id": character_id,
            "scene_id": scene_id,
            "template_skeleton": template_str,
            "slots_filled": filled_slots
        }

    def _sanitize_text(self, text):
        clean = text.strip()
        # Clean double punctuation
        clean = re.sub(r"([，。！？~])\1+", r"\1", clean)
        clean = clean.replace("！~", "！").replace("~！", "！")
        clean = clean.replace("，！", "！").replace("，。", "。").replace("！，", "！").replace("？，", "？").replace("~，", "~ ")
        clean = clean.replace("  ", " ")
        # Clean space before punctuation
        clean = re.sub(r"\s+([，。！？~♡])", r"\1", clean)
        # Ensure proper punctuation at end
        if clean and clean[-1] not in "。！？~♡":
            clean += "。"
        # Zero ellipses replacement check
        clean = clean.replace("\u2026\u2026", "~ ").replace("." * 3, "~ ")
        clean = clean.replace("\u2026", "~ ")
        # Verify no three consecutive dots exist
        clean = clean.replace("." * 3, "~ ")
        return clean

    def reset_history(self):
        self.slot_history.clear()
