# -*- coding: utf-8 -*-
"""Execution runner for local AIRP prototype evaluation."""

import json
from pathlib import Path
import random
from time import perf_counter

from retriever_rule import RuleRetriever
from retriever_bge import BgeRetriever

HERE = Path(__file__).resolve().parent

def run_suite(retriever, suite_data, method_name, seed=42):
    random.seed(seed)
    results = {
        "method": method_name,
        "single_turn_results": [],
        "multi_turn_results": [],
        "timing_ms": []
    }

    # 1. Single-turn tests
    for case in suite_data["single_turn_cases"]:
        start = perf_counter()
        resp = retriever.retrieve(
            character_id=case["character_id"],
            scene_id=case["scene_id"],
            phase=case["phase"],
            player_input=case["player_input"],
            history_reply_ids=[]
        )
        elapsed_ms = (perf_counter() - start) * 1000
        results["timing_ms"].append(elapsed_ms)

        hit = resp["reply_id"] in case["acceptable_reply_ids"]
        phase_ok = resp["next_phase"] == case["expected_next_phase"]

        results["single_turn_results"].append({
            "case_id": case["id"],
            "character_id": case["character_id"],
            "player_input": case["player_input"],
            "expected_intent": case["expected_intent"],
            "expected_reply_ids": case["acceptable_reply_ids"],
            "picked_reply_id": resp["reply_id"],
            "picked_intent": resp["intent_id"],
            "reply_text": resp["reply_text"],
            "expected_phase": case["expected_next_phase"],
            "next_phase": resp["next_phase"],
            "hit": hit,
            "phase_ok": phase_ok,
            "confidence": resp.get("confidence", 0.0),
            "score": resp.get("score", 0.0),
            "elapsed_ms": round(elapsed_ms, 3)
        })

    # 2. Multi-turn episode tests
    for ep in suite_data["multi_turn_episodes"]:
        ep_result = {
            "episode_id": ep["id"],
            "character_id": ep["character_id"],
            "scene_id": ep["scene_id"],
            "turns": [],
            "all_hit": True
        }
        current_phase = ep["initial_phase"]
        history_replies = []
        seen_texts = set()
        repeated_texts = 0

        for turn_idx, turn in enumerate(ep["turns"]):
            start = perf_counter()
            resp = retriever.retrieve(
                character_id=ep["character_id"],
                scene_id=ep["scene_id"],
                phase=current_phase,
                player_input=turn["player"],
                history_reply_ids=history_replies
            )
            elapsed_ms = (perf_counter() - start) * 1000
            results["timing_ms"].append(elapsed_ms)

            # Check text repetition
            if resp["reply_text"] in seen_texts:
                repeated_texts += 1
            seen_texts.add(resp["reply_text"])

            phase_matches = resp["next_phase"] == turn["expected_phase"]
            if not phase_matches:
                ep_result["all_hit"] = False

            ep_result["turns"].append({
                "turn_index": turn_idx,
                "player": turn["player"],
                "input_phase": current_phase,
                "reply_id": resp["reply_id"],
                "reply_text": resp["reply_text"],
                "next_phase": resp["next_phase"],
                "expected_phase": turn["expected_phase"],
                "phase_ok": phase_matches,
                "confidence": resp.get("confidence", 0.0),
                "elapsed_ms": round(elapsed_ms, 3)
            })

            history_replies.append(resp["reply_id"])
            current_phase = resp["next_phase"]

        ep_result["repeated_texts"] = repeated_texts
        ep_result["repetition_rate"] = round(repeated_texts / len(ep["turns"]), 3)
        results["multi_turn_results"].append(ep_result)

    return results


def main():
    suite_file = HERE / "benchmark_suite.json"
    suite_data = json.loads(suite_file.read_text(encoding="utf-8"))

    print("Running Path A: Scene Rules")
    retriever_a = RuleRetriever()
    results_a = run_suite(retriever_a, suite_data, "rule", seed=2026)

    out_a = HERE / "runs_path_a.json"
    out_a.write_text(json.dumps(results_a, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Path A completed: {len(results_a['single_turn_results'])} single-turn cases, {len(results_a['multi_turn_results'])} episodes.")

    print("\nRunning Path B: Scene Rules + BGE Q8_0")
    retriever_b = BgeRetriever()
    try:
        results_b = run_suite(retriever_b, suite_data, "bge", seed=2026)
        out_b = HERE / "runs_path_b.json"
        out_b.write_text(json.dumps(results_b, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Path B completed: {len(results_b['single_turn_results'])} single-turn cases, {len(results_b['multi_turn_results'])} episodes.")
    finally:
        retriever_b.close()


if __name__ == "__main__":
    main()
