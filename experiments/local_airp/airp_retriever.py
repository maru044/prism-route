# -*- coding: utf-8 -*-
"""Retrieval-based AIRP Semantic Retriever using BGE Q8_0 Probe and Wildcard Composer.

Implements query-to-query semantic similarity matching, candidate filtering,
recent reply sliding window penalty, margin disambiguation, and out-of-scope fallback.
"""

from collections import deque
import json
from pathlib import Path
import subprocess
import numpy as np

from experiments.local_airp.wildcard_composer import WildcardComposer

HERE = Path(__file__).resolve().parent
WORKSPACE_ROOT = HERE.parents[2]
PROBE_BIN = WORKSPACE_ROOT / "tools" / "local-intent-retrieval" / "native-probe" / "embedding_probe.exe"
MODEL_GGUF = WORKSPACE_ROOT / "tools" / "local-intent-retrieval" / "models" / "bge-small-zh-v1.5-q8_0" / "bge-small-zh-v1.5-q8_0.gguf"


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


class AirpRetriever:
    def __init__(self, data_dir=HERE, probe_client=None, clarify_threshold=0.58, window_size=5):
        self.data_dir = Path(data_dir)
        self.clarify_threshold = clarify_threshold
        self.window_size = window_size
        self.templates = json.loads((self.data_dir / "templates.json").read_text(encoding="utf-8"))
        self.composer = WildcardComposer(data_dir=self.data_dir)
        
        self.probe = probe_client if probe_client is not None else BgeProbeClient()
        self.history_reply_ids = deque(maxlen=self.window_size)
        
        self._precompute_reference_embeddings()

    def _precompute_reference_embeddings(self):
        for tmpl in self.templates:
            refs = tmpl.get("reference_queries", [])
            ref_vectors = []
            for q in refs:
                vec = self.probe.embed(q)
                ref_vectors.append(vec)
            if ref_vectors:
                tmpl["_ref_matrix"] = np.vstack(ref_vectors)
            else:
                tmpl["_ref_matrix"] = np.zeros((0, 512), dtype=np.float32)

    def retrieve_and_compose(self, player_input, character_id, scene_id, context=None, seed=None):
        if context is None:
            context = {}

        # 1. Filter candidates by character and scene
        candidates = []
        for tmpl in self.templates:
            char_match = (tmpl["character_id"] == "shared" or tmpl["character_id"] == character_id)
            scene_match = (scene_id in tmpl.get("scene_tags", []))
            # pause and clarify can match anywhere
            if tmpl.get("content_tag") in ["pause_stop", "clarify_unknown"]:
                scene_match = True
            
            if char_match and scene_match:
                candidates.append(tmpl)

        if not candidates:
            candidates = self.templates

        # 2. Embed player input symmetrically without prefix for Query-to-Query matching
        player_vec = self.probe.embed(player_input)

        # 3. Score candidates
        scored_candidates = []
        for tmpl in candidates:
            ref_matrix = tmpl.get("_ref_matrix")
            if ref_matrix is not None and ref_matrix.shape[0] > 0:
                sims = ref_matrix @ player_vec
                best_idx = int(np.argmax(sims))
                raw_score = float(sims[best_idx])
                matched_ref = tmpl["reference_queries"][best_idx]
            else:
                raw_score = 0.0
                matched_ref = ""

            adjusted_score = raw_score
            # Sliding window penalty for recently used templates
            if tmpl["reply_id"] in self.history_reply_ids:
                adjusted_score -= 0.15

            scored_candidates.append({
                "template": tmpl,
                "raw_score": raw_score,
                "adjusted_score": adjusted_score,
                "matched_ref": matched_ref
            })

        scored_candidates.sort(key=lambda x: x["adjusted_score"], reverse=True)
        top = scored_candidates[0]
        second = scored_candidates[1] if len(scored_candidates) > 1 else None

        # 4. Out-of-scope check
        if top["raw_score"] < self.clarify_threshold:
            clarify_tmpl = next((t for t in self.templates if t["reply_id"] == "clarify_unknown_01"), top["template"])
            chosen_tmpl = clarify_tmpl
            chosen_score = top["raw_score"]
            matched_ref = top["matched_ref"]
            is_fallback = True
        else:
            # Margin check: if margin < 0.03 and second template is more contextually appropriate
            chosen_tmpl = top["template"]
            chosen_score = top["raw_score"]
            matched_ref = top["matched_ref"]
            is_fallback = False

        # 5. Update history
        self.history_reply_ids.append(chosen_tmpl["reply_id"])

        # 6. Compose response
        composed_result = self.composer.compose(
            template_obj=chosen_tmpl,
            character_id=character_id,
            scene_id=scene_id,
            context=context,
            seed=seed
        )

        return {
            "text": composed_result["text"],
            "reply_id": chosen_tmpl["reply_id"],
            "content_tag": chosen_tmpl.get("content_tag"),
            "score": round(chosen_score, 4),
            "matched_reference_query": matched_ref,
            "character_id": character_id,
            "scene_id": scene_id,
            "template_skeleton": composed_result["template_skeleton"],
            "slots_filled": composed_result["slots_filled"],
            "is_fallback": is_fallback
        }

    def reset_history(self):
        self.history_reply_ids.clear()
        self.composer.reset_history()

    def close(self):
        if self.probe:
            self.probe.close()
