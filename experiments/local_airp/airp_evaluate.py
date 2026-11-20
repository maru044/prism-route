# -*- coding: utf-8 -*-
"""Evaluation Script for Local Retrieval-based AIRP with Wildcard Composition."""

import json
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent

def evaluate():
    runs_path = HERE / "runs_airp_benchmark.json"
    data = json.loads(runs_path.read_text(encoding="utf-8"))

    single_results = data["single_turn_results"]
    multi_results = data["multi_turn_results"]

    # 1. Single Turn Metrics
    total_single = len(single_results)
    correct_single = 0
    pause_total = 0
    pause_correct = 0
    single_latencies = []

    for r in single_results:
        single_latencies.append(r["latency_ms"])
        is_match = (r["predicted_tag"] == r["expected_tag"])
        if is_match:
            correct_single += 1

        if r["expected_tag"] == "pause_stop":
            pause_total += 1
            if r["predicted_tag"] == "pause_stop":
                pause_correct += 1

    single_accuracy = (correct_single / total_single) * 100.0 if total_single > 0 else 0.0
    pause_accuracy = (pause_correct / pause_total) * 100.0 if pause_total > 0 else 100.0

    # 2. Multi-turn Metrics
    total_multi_turns = 0
    correct_multi_turns = 0
    all_multi_texts = []
    multi_latencies = []

    for ep in multi_results:
        ep_texts = []
        for turn in ep["turns"]:
            total_multi_turns += 1
            multi_latencies.append(turn["latency_ms"])
            if turn["predicted_tag"] == turn["expected_tag"]:
                correct_multi_turns += 1

            if turn["expected_tag"] == "pause_stop":
                pause_total += 1
                if turn["predicted_tag"] == "pause_stop":
                    pause_correct += 1

            t_clean = turn["text"].strip()
            ep_texts.append(t_clean)
            all_multi_texts.append(t_clean)

    multi_accuracy = (correct_multi_turns / total_multi_turns) * 100.0 if total_multi_turns > 0 else 0.0
    total_turns = total_single + total_multi_turns
    overall_usable_coverage = ((correct_single + correct_multi_turns) / total_turns) * 100.0

    # Text repetition rate
    unique_texts = set(all_multi_texts)
    repetition_count = len(all_multi_texts) - len(unique_texts)
    repetition_rate = (repetition_count / len(all_multi_texts)) * 100.0 if all_multi_texts else 0.0

    # Overall pause accuracy
    overall_pause_accuracy = (pause_correct / pause_total) * 100.0 if pause_total > 0 else 100.0

    # Latency Percentiles
    all_latencies = single_latencies + multi_latencies
    p50_latency = float(np.percentile(all_latencies, 50))
    p90_latency = float(np.percentile(all_latencies, 90))
    p99_latency = float(np.percentile(all_latencies, 99))

    # Persona differentiation checks
    sparkle_texts = [r["text"] for r in single_results if r["character_id"] == "sparkle"]
    keqing_texts = [r["text"] for r in single_results if r["character_id"] == "keqing"]
    
    sparkle_markers = ["小主人", "Master", "本愚者", "狐狸", "铃铛", "恶作剧", "欢愉", "咯咯", "花火"]
    keqing_markers = ["玉衡星", "剑势", "工作", "沙洲", "分寸", "认真", "黑丝", "长案", "巡视", "Master", "旅行者", "霓裾", "腿环", "双马尾", "顺从", "心跳", "清茶", "呼吸"]

    sp_marker_hits = sum(1 for t in sparkle_texts if any(m in t for m in sparkle_markers))
    kq_marker_hits = sum(1 for t in keqing_texts if any(m in t for m in keqing_markers))

    sp_marker_rate = (sp_marker_hits / len(sparkle_texts)) * 100.0 if sparkle_texts else 0.0
    kq_marker_rate = (kq_marker_hits / len(keqing_texts)) * 100.0 if keqing_texts else 0.0

    summary = {
        "usable_coverage_pct": round(overall_usable_coverage, 2),
        "single_turn_accuracy_pct": round(single_accuracy, 2),
        "multi_turn_accuracy_pct": round(multi_accuracy, 2),
        "pause_stop_accuracy_pct": round(overall_pause_accuracy, 2),
        "text_repetition_rate_pct": round(repetition_rate, 2),
        "latency_p50_ms": round(p50_latency, 2),
        "latency_p90_ms": round(p90_latency, 2),
        "latency_p99_ms": round(p99_latency, 2),
        "sparkle_marker_rate_pct": round(sp_marker_rate, 2),
        "keqing_marker_rate_pct": round(kq_marker_rate, 2),
        "total_evaluated_queries": total_turns
    }

    print("=== Evaluation Summary ===")
    for k, v in summary.items():
        print(f"{k}: {v}")

    eval_out = HERE / "evaluation_summary.json"
    eval_out.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")

if __name__ == "__main__":
    evaluate()
