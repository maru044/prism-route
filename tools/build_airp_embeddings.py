# -*- coding: utf-8 -*-
"""Precompute reference query embeddings for local AIRP runtime in Godot."""

import json
from pathlib import Path
import subprocess
import numpy as np

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
WORKSPACE_ROOT = REPO_ROOT.parent
PROBE_BIN = WORKSPACE_ROOT / "tools" / "local-intent-retrieval" / "native-probe" / "embedding_probe.exe"
MODEL_GGUF = WORKSPACE_ROOT / "tools" / "local-intent-retrieval" / "models" / "bge-small-zh-v1.5-q8_0" / "bge-small-zh-v1.5-q8_0.gguf"
DATA_DIR = REPO_ROOT / "assets" / "ai" / "local_airp"

def precompute():
    templates_path = DATA_DIR / "templates.json"
    templates = json.loads(templates_path.read_text(encoding="utf-8"))

    proc = subprocess.Popen(
        [str(PROBE_BIN), str(MODEL_GGUF), "2"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0
    )
    ready = proc.stdout.readline().strip()
    if ready != "READY":
        raise RuntimeError(f"Probe initialization failed: {ready}")

    def embed_query(text):
        clean = text.replace("\n", " ").replace("\r", " ").strip()
        if not clean:
            clean = "空"
        proc.stdin.write(f"embed\t{clean}\n")
        proc.stdin.flush()
        line = proc.stdout.readline()
        parts = line.split()
        if not parts or parts[0] != "VECTOR":
            raise RuntimeError(f"Bad probe output: {line[:50]}")
        vec = np.array([float(x) for x in parts[1:]], dtype=np.float32)
        norm = np.linalg.norm(vec)
        if norm > 0:
            vec /= norm
        return [round(float(x), 6) for x in vec]

    embeddings_map = {}
    total_queries = 0
    for tmpl in templates:
        r_id = tmpl["reply_id"]
        refs = tmpl.get("reference_queries", [])
        vec_list = []
        for q in refs:
            vec_list.append(embed_query(q))
            total_queries += 1
        embeddings_map[r_id] = {
            "reply_id": r_id,
            "reference_queries": refs,
            "vectors": vec_list
        }

    proc.stdin.close()
    proc.terminate()

    out_file = DATA_DIR / "reference_embeddings.json"
    out_file.write_text(json.dumps(embeddings_map, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Precomputed {total_queries} query embeddings saved to {out_file} (Size: {out_file.stat().st_size} bytes)")

if __name__ == "__main__":
    precompute()
