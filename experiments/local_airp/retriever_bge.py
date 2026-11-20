# -*- coding: utf-8 -*-
"""Path B: Scene rules + BGE Q8_0 embedding similarity retrieval for local AIRP."""

import json
from pathlib import Path
import random
import subprocess
import numpy as np

HERE = Path(__file__).resolve().parent
WORKSPACE_TOOLS = HERE.parents[2] / "tools" / "local-intent-retrieval"
PROBE_BIN = WORKSPACE_TOOLS / "native-probe" / "embedding_probe.exe"
MODEL_GGUF = WORKSPACE_TOOLS / "models" / "bge-small-zh-v1.5-q8_0" / "bge-small-zh-v1.5-q8_0.gguf"
QUERY_PREFIX = "为这个句子生成表示以用于检索相关文章："

class BgeProbeClient:
    def __init__(self, binary_path=PROBE_BIN, model_path=MODEL_GGUF, threads=2):
        self.process = subprocess.Popen(
            [str(binary_path), str(model_path), str(threads)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0
        )
        ready_line = self.process.stdout.readline().strip()
        if ready_line != "READY":
            self.close()
            raise RuntimeError(f"Embedding probe failed to initialize: {ready_line}")

    def embed(self, text):
        clean = text.replace("\n", " ").replace("\r", " ").strip()
        if not clean:
            clean = "空"
        self.process.stdin.write(f"embed\t{clean}\n")
        self.process.stdin.flush()
        line = self.process.stdout.readline()
        parts = line.split()
        if not parts or parts[0] != "VECTOR":
            raise RuntimeError(f"Unexpected probe response: {line[:50]}")
        vec = np.array([float(x) for x in parts[1:]], dtype=np.float32)
        norm = np.linalg.norm(vec)
        if norm > 0:
            vec /= norm
        return vec

    def close(self):
        if self.process:
            try:
                self.process.stdin.close()
                self.process.terminate()
                self.process.wait(timeout=2)
            except Exception:
                pass


class BgeRetriever:
    def __init__(self, database_path=None, probe_client=None):
        if database_path is None:
            database_path = HERE / "database.json"
        self.database = json.loads(Path(database_path).read_text(encoding="utf-8"))
        self._used_variations = {}
        
        # Initialize probe client
        self.probe = probe_client if probe_client is not None else BgeProbeClient()
        
        # Precompute reference vectors
        self._cache_reference_embeddings()

    def _cache_reference_embeddings(self):
        for row in self.database:
            refs = row.get("reference_queries", [])
            ref_vectors = []
            for q in refs:
                vec = self.probe.embed(q)
                ref_vectors.append(vec)
            if ref_vectors:
                row["_ref_matrix"] = np.vstack(ref_vectors)
            else:
                row["_ref_matrix"] = np.zeros((0, 512), dtype=np.float32)

    def retrieve(self, character_id, scene_id, phase, player_input, history_reply_ids=None):
        if history_reply_ids is None:
            history_reply_ids = []

        # 1. Filter candidates by character and scene
        candidates = [
            row for row in self.database
            if row["character_id"] == character_id and row["scene_id"] == scene_id
        ]

        # 2. Phase-based filtering (scene rule constraints)
        phase_matched = []
        for row in candidates:
            row_phase = row["phase"]
            if row_phase == phase:
                phase_matched.append(row)
            elif phase in ["foreplay", "deep", "peak", "paused", "aftercare"] and row["intent_id"] in ["pause_request", "clarify_out_of_scope"]:
                phase_matched.append(row)
            elif phase == "flirt" and row["intent_id"] in ["invite_intimacy", "decline_to_daily"]:
                phase_matched.append(row)
            elif phase == "casual" and row["intent_id"] in ["greet", "chat_island", "flirt_verbal"]:
                phase_matched.append(row)

        if not phase_matched:
            phase_matched = candidates

        # 3. Encode player input with query prefix
        prefixed_input = QUERY_PREFIX + player_input.strip()
        query_vec = self.probe.embed(prefixed_input)

        # 4. Score each candidate by max similarity across reference queries
        scores = []
        for row in phase_matched:
            ref_matrix = row.get("_ref_matrix")
            if ref_matrix.shape[0] > 0:
                sims = ref_matrix @ query_vec
                best_sim = float(np.max(sims))
            else:
                best_sim = 0.0
            
            # Phase bonus to reward same-phase continuation
            if row["phase"] == phase:
                best_sim += 0.02
                
            scores.append((best_sim, row))

        scores.sort(key=lambda x: x[0], reverse=True)
        top_score, best_candidate = scores[0]
        second_score = scores[1][0] if len(scores) > 1 else 0.0
        margin = top_score - second_score

        # 5. Variation selection avoiding recent history
        reply_id = best_candidate["reply_id"]
        variations = best_candidate["variations"]
        last_used = self._used_variations.get(reply_id, -1)
        available_indices = [i for i in range(len(variations)) if i != last_used]
        if not available_indices:
            available_indices = list(range(len(variations)))
        
        chosen_idx = random.choice(available_indices)
        self._used_variations[reply_id] = chosen_idx
        reply_text = variations[chosen_idx]

        confidence = round(float(top_score), 3)

        return {
            "reply_id": reply_id,
            "intent_id": best_candidate["intent_id"],
            "reply_text": reply_text,
            "next_phase": best_candidate["next_phase"],
            "confidence": confidence,
            "score": round(float(top_score), 4),
            "margin": round(float(margin), 4),
            "method": "bge"
        }

    def close(self):
        if self.probe:
            self.probe.close()
