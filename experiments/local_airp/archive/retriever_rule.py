# -*- coding: utf-8 -*-
"""Path A: Scene rule based retrieval for local AIRP."""

import json
from pathlib import Path
import random

HERE = Path(__file__).resolve().parent

class RuleRetriever:
    def __init__(self, database_path=None):
        if database_path is None:
            database_path = HERE / "database.json"
        self.database = json.loads(Path(database_path).read_text(encoding="utf-8"))
        self._used_variations = {}

    def retrieve(self, character_id, scene_id, phase, player_input, history_reply_ids=None):
        if history_reply_ids is None:
            history_reply_ids = []

        # 1. Filter candidates by character and scene
        candidates = [
            row for row in self.database
            if row["character_id"] == character_id and row["scene_id"] == scene_id
        ]

        # 2. Phase-based filtering
        phase_matched = []
        for row in candidates:
            row_phase = row["phase"]
            # Exact phase match
            if row_phase == phase:
                phase_matched.append(row)
            # Special universal/cross-phase intents
            elif phase in ["foreplay", "deep", "peak", "paused", "aftercare"] and row["intent_id"] in ["pause_request", "clarify_out_of_scope"]:
                phase_matched.append(row)
            elif phase == "flirt" and row["intent_id"] in ["invite_intimacy", "decline_to_daily"]:
                phase_matched.append(row)
            elif phase == "casual" and row["intent_id"] in ["greet", "chat_island", "flirt_verbal"]:
                phase_matched.append(row)

        if not phase_matched:
            phase_matched = candidates

        # 3. Rule / Trigger scoring
        best_candidate = None
        best_score = -1
        input_clean = player_input.strip()

        for row in phase_matched:
            triggers = row.get("triggers", [])
            matches = [t for t in triggers if t in input_clean]
            score = len(matches) * 10
            # Extra points for exact or longer keyword matches
            for m in matches:
                score += len(m)
            
            # Phase priority
            if row["phase"] == phase:
                score += 5

            if score > best_score and score > 0:
                best_score = score
                best_candidate = row

        # Fallback if no triggers matched
        if best_candidate is None:
            # Check for clarification
            clarify = [r for r in phase_matched if "clarify" in r["intent_id"]]
            if clarify:
                best_candidate = clarify[0]
                best_score = 1
            else:
                best_candidate = phase_matched[0]
                best_score = 0

        # 4. Variation selection avoiding recent history
        reply_id = best_candidate["reply_id"]
        variations = best_candidate["variations"]
        last_used = self._used_variations.get(reply_id, -1)
        available_indices = [i for i in range(len(variations)) if i != last_used]
        if not available_indices:
            available_indices = list(range(len(variations)))
        
        chosen_idx = random.choice(available_indices)
        self._used_variations[reply_id] = chosen_idx
        reply_text = variations[chosen_idx]

        confidence = min(1.0, max(0.1, best_score / 25.0))

        return {
            "reply_id": reply_id,
            "intent_id": best_candidate["intent_id"],
            "reply_text": reply_text,
            "next_phase": best_candidate["next_phase"],
            "confidence": round(confidence, 3),
            "method": "rule"
        }
