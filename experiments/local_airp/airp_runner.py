# -*- coding: utf-8 -*-
"""Benchmark Runner for Local Retrieval-based AIRP with Wildcard Composition."""

import json
from pathlib import Path
import sys
import time

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[1]
sys.path.insert(0, str(REPO_ROOT))

from experiments.local_airp.airp_retriever import AirpRetriever

def run_benchmark():
    benchmark_path = HERE / "benchmark_airp.json"
    benchmark = json.loads(benchmark_path.read_text(encoding="utf-8"))
    
    retriever = AirpRetriever(data_dir=HERE)

    single_results = []
    print("Running 40 Single-turn Benchmark Cases!")
    for idx, case in enumerate(benchmark["single_turn_cases"]):
        retriever.reset_history()
        t0 = time.perf_counter()
        res = retriever.retrieve_and_compose(
            player_input=case["query"],
            character_id=case["character_id"],
            scene_id=case["scene_id"],
            seed=idx + 100
        )
        latency_ms = (time.perf_counter() - t0) * 1000.0

        single_results.append({
            "case_id": case["id"],
            "character_id": case["character_id"],
            "scene_id": case["scene_id"],
            "query": case["query"],
            "expected_tag": case["expected_tag"],
            "predicted_tag": res["content_tag"],
            "reply_id": res["reply_id"],
            "score": res["score"],
            "latency_ms": round(latency_ms, 2),
            "text": res["text"],
            "is_fallback": res["is_fallback"]
        })

    multi_results = []
    print("Running 12 Multi-turn Dialogue Episodes!")
    for ep_idx, ep in enumerate(benchmark["multi_turn_episodes"]):
        retriever.reset_history()
        ep_turns = []
        for turn_idx, turn in enumerate(ep["turns"]):
            t0 = time.perf_counter()
            res = retriever.retrieve_and_compose(
                player_input=turn["query"],
                character_id=ep["character_id"],
                scene_id=turn["scene_id"],
                seed=ep_idx * 1000 + turn_idx
            )
            latency_ms = (time.perf_counter() - t0) * 1000.0

            ep_turns.append({
                "turn_index": turn_idx,
                "scene_id": turn["scene_id"],
                "query": turn["query"],
                "expected_tag": turn["expected_tag"],
                "predicted_tag": res["content_tag"],
                "reply_id": res["reply_id"],
                "score": res["score"],
                "latency_ms": round(latency_ms, 2),
                "text": res["text"],
                "slots_filled": res["slots_filled"]
            })

        multi_results.append({
            "episode_id": ep["episode_id"],
            "character_id": ep["character_id"],
            "turns": ep_turns
        })

    retriever.close()

    output = {
        "version": benchmark.get("version"),
        "single_turn_results": single_results,
        "multi_turn_results": multi_results
    }

    out_path = HERE / "runs_airp_benchmark.json"
    out_path.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Benchmark finished! Results saved to {out_path.name}")

if __name__ == "__main__":
    run_benchmark()
