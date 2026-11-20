# -*- coding: utf-8 -*-
"""Unit tests for Local Retrieval-based AIRP with Wildcard Composition."""

import json
from pathlib import Path
import sys
import unittest

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[1]
sys.path.insert(0, str(REPO_ROOT))

from experiments.local_airp.airp_retriever import AirpRetriever
from experiments.local_airp.wildcard_composer import WildcardComposer

class TestLocalAirpWildcard(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.retriever = AirpRetriever(data_dir=HERE)
        cls.composer = WildcardComposer(data_dir=HERE)
        cls.templates = json.loads((HERE / "templates.json").read_text(encoding="utf-8"))

    @classmethod
    def tearDownClass(cls):
        cls.retriever.close()

    def test_composer_slot_filling_and_no_empty_brackets(self):
        for tmpl in self.templates:
            for char_id in ["sparkle", "keqing"]:
                scene = "intimate" if "intimate" in tmpl.get("scene_tags", []) else "home_chat"
                res = self.composer.compose(tmpl, char_id, scene, seed=42)
                text = res["text"]
                self.assertNotIn("{", text, f"Unfilled bracket in {tmpl['reply_id']} ({char_id}): {text}")
                self.assertNotIn("}", text, f"Unfilled bracket in {tmpl['reply_id']} ({char_id}): {text}")
                self.assertGreater(len(text), 5, f"Composed text too short for {tmpl['reply_id']}")

    def test_composer_anti_repetition_buffer(self):
        tmpl = next(t for t in self.templates if t["reply_id"] == "home_greet_01")
        self.composer.reset_history()
        outputs = []
        for i in range(4):
            res = self.composer.compose(tmpl, "sparkle", "home_chat", seed=10 + i)
            outputs.append(res["text"])
        # All 4 outputs should be distinct because of the ring buffer
        self.assertEqual(len(set(outputs)), len(outputs), "Expected diverse non-repeating outputs across 4 turns")

    def test_retriever_pause_stop_accuracy(self):
        pause_queries = [
            "停一下",
            "太激烈了先等等",
            "暂停",
            "先歇会儿",
            "等一下我吃不消了",
            "先停手",
            "先暂停一下",
            "缓口气",
            "今天就到这里吧",
            "先休息一下"
        ]
        for q in pause_queries:
            for char_id in ["sparkle", "keqing"]:
                res = self.retriever.retrieve_and_compose(q, char_id, "intimate", seed=99)
                self.assertEqual(
                    res["content_tag"],
                    "pause_stop",
                    f"Query '{q}' failed to trigger pause_stop for {char_id}, got {res['content_tag']} (score: {res['score']})"
                )

    def test_retriever_out_of_scope_clarification(self):
        out_of_scope_queries = [
            "量子力学Schrodinger方程求解",
            "帮我查一下背包里的矿石有几个",
            "把我的坐标传送到沙洲坐标点",
            "执行数据库迁移脚本"
        ]
        for q in out_of_scope_queries:
            res = self.retriever.retrieve_and_compose(q, "sparkle", "home_chat", seed=123)
            self.assertEqual(
                res["content_tag"],
                "clarify_unknown",
                f"Query '{q}' should trigger clarify_unknown, got {res['content_tag']}"
            )

    def test_persona_differentiation(self):
        tmpl_tease = next(t for t in self.templates if t["reply_id"] == "home_tease_01")
        sp_res = self.composer.compose(tmpl_tease, "sparkle", "home_chat", seed=77)
        kq_res = self.composer.compose(tmpl_tease, "keqing", "home_chat", seed=77)
        self.assertNotEqual(sp_res["text"], kq_res["text"], "Sparkle and Keqing must not generate identical text")

    def test_zero_ellipses_in_all_composed_outputs(self):
        triple_dot = "." * 3
        chinese_ellipsis = "\u2026\u2026"
        single_ellipsis = "\u2026"
        for tmpl in self.templates:
            for char_id in ["sparkle", "keqing"]:
                for s in [1, 2, 3]:
                    res = self.composer.compose(tmpl, char_id, "home_chat", seed=s)
                    self.assertNotIn(triple_dot, res["text"])
                    self.assertNotIn(chinese_ellipsis, res["text"])
                    self.assertNotIn(single_ellipsis, res["text"])

if __name__ == "__main__":
    unittest.main()
