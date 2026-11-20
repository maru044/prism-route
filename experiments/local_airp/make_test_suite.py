# -*- coding: utf-8 -*-
"""Generate the test benchmark suite for local AIRP prototype."""

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent

SINGLE_TURN_CASES = [
    # --- SPARKLE (花火) SINGLE-TURN CASES ---
    {
        "id": "tc_sp_01",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "phase": "casual",
        "player_input": "花火，你在房间里做什么呢？",
        "expected_intent": "greet",
        "acceptable_reply_ids": ["sp_home_greeting"],
        "expected_next_phase": "casual"
    },
    {
        "id": "tc_sp_02",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "phase": "casual",
        "player_input": "你看我们建造的这套海岛大别墅怎么样？",
        "expected_intent": "chat_island",
        "acceptable_reply_ids": ["sp_home_island"],
        "expected_next_phase": "casual"
    },
    {
        "id": "tc_sp_03",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "phase": "casual",
        "player_input": "花火今天这身衣服真漂亮，身材太诱人了。",
        "expected_intent": "flirt_verbal",
        "acceptable_reply_ids": ["sp_home_tease"],
        "expected_next_phase": "flirt"
    },
    {
        "id": "tc_sp_04",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "phase": "flirt",
        "player_input": "伸手搂住你的细腰，摸摸毛茸茸的尾巴饰品。",
        "expected_intent": "touch_physical",
        "acceptable_reply_ids": ["sp_home_touch"],
        "expected_next_phase": "flirt"
    },
    {
        "id": "tc_sp_05",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "phase": "flirt",
        "player_input": "走，我们去床上深度温存吧！",
        "expected_intent": "invite_intimacy",
        "acceptable_reply_ids": ["sp_home_invite"],
        "expected_next_phase": "intimate_entry"
    },
    {
        "id": "tc_sp_06",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "phase": "flirt",
        "player_input": "今天先算了，改天再做，我们纯聊天吧。",
        "expected_intent": "decline_to_daily",
        "acceptable_reply_ids": ["sp_home_decline_casual"],
        "expected_next_phase": "casual"
    },
    {
        "id": "tc_sp_07",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "foreplay",
        "player_input": "温柔地吻住你的唇瓣，伸出舌头与你深吻。",
        "expected_intent": "foreplay_kiss",
        "acceptable_reply_ids": ["sp_int_foreplay_kiss"],
        "expected_next_phase": "foreplay"
    },
    {
        "id": "tc_sp_08",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "foreplay",
        "player_input": "把碍事的衣服全部脱掉，让我好好欣赏你。",
        "expected_intent": "foreplay_undress",
        "acceptable_reply_ids": ["sp_int_foreplay_undress"],
        "expected_next_phase": "foreplay"
    },
    {
        "id": "tc_sp_09",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "foreplay",
        "player_input": "扶着你的细腰慢慢推进去，真正进入你体内。",
        "expected_intent": "deep_start",
        "acceptable_reply_ids": ["sp_int_deep_start"],
        "expected_next_phase": "deep"
    },
    {
        "id": "tc_sp_10",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "继续，动起来不要停！",
        "expected_intent": "continue_action",
        "acceptable_reply_ids": ["sp_int_deep_continue"],
        "expected_next_phase": "deep"
    },
    {
        "id": "tc_sp_11",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "稍微慢一点，轻柔一点，慢慢享受。",
        "expected_intent": "pacing_slow",
        "acceptable_reply_ids": ["sp_int_pacing_slow"],
        "expected_next_phase": "deep"
    },
    {
        "id": "tc_sp_12",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "加快速度抽送，再深一点，用力顶进来！",
        "expected_intent": "pacing_fast",
        "acceptable_reply_ids": ["sp_int_pacing_fast"],
        "expected_next_phase": "deep"
    },
    {
        "id": "tc_sp_13",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "我们换个姿势吧，转过身去趴着。",
        "expected_intent": "pacing_change_pose",
        "acceptable_reply_ids": ["sp_int_pacing_pose"],
        "expected_next_phase": "deep"
    },
    {
        "id": "tc_sp_14",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "受不了了，我快要出来了，一起高潮吧！",
        "expected_intent": "peak_climax",
        "acceptable_reply_ids": ["sp_int_peak_climax"],
        "expected_next_phase": "peak"
    },
    {
        "id": "tc_sp_15",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "peak",
        "player_input": "里面还在剧烈抽搐呢，全射给你了。",
        "expected_intent": "peak_aftermath",
        "acceptable_reply_ids": ["sp_int_peak_aftermath"],
        "expected_next_phase": "aftercare"
    },
    {
        "id": "tc_sp_16",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "先停一下，等一下别动，让我缓口气。",
        "expected_intent": "pause_request",
        "acceptable_reply_ids": ["sp_int_pause_request"],
        "expected_next_phase": "paused"
    },
    {
        "id": "tc_sp_17",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "paused",
        "player_input": "我休息好了，继续动起来吧！",
        "expected_intent": "resume_action",
        "acceptable_reply_ids": ["sp_int_resume_after_pause"],
        "expected_next_phase": "deep"
    },
    {
        "id": "tc_sp_18",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "今天就做到这里吧，到此为止结束吧。",
        "expected_intent": "end_intimacy",
        "acceptable_reply_ids": ["sp_int_end_session"],
        "expected_next_phase": "aftercare"
    },
    {
        "id": "tc_sp_19",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "aftercare",
        "player_input": "过来抱紧我，我们好好温存贴贴。",
        "expected_intent": "aftercare_cuddle",
        "acceptable_reply_ids": ["sp_int_aftercare_cuddle"],
        "expected_next_phase": "aftercare"
    },
    {
        "id": "tc_sp_20",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "aftercare",
        "player_input": "花火刚才表现真棒，今天被你伺候得很满足。",
        "expected_intent": "aftercare_praise",
        "acceptable_reply_ids": ["sp_int_aftercare_praise"],
        "expected_next_phase": "aftercare"
    },

    # --- KEQING (刻晴) SINGLE-TURN CASES ---
    {
        "id": "tc_kq_01",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "phase": "casual",
        "player_input": "刻晴，上午好，在房间里忙什么呢？",
        "expected_intent": "greet",
        "acceptable_reply_ids": ["kq_home_greeting"],
        "expected_next_phase": "casual"
    },
    {
        "id": "tc_kq_02",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "phase": "casual",
        "player_input": "这片沙洲领地的规划建设进展如何？",
        "expected_intent": "chat_island",
        "acceptable_reply_ids": ["kq_home_island"],
        "expected_next_phase": "casual"
    },
    {
        "id": "tc_kq_03",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "phase": "casual",
        "player_input": "刻晴认真脸红的样子真可爱，脱下工作装更迷人了。",
        "expected_intent": "flirt_verbal",
        "acceptable_reply_ids": ["kq_home_tease"],
        "expected_next_phase": "flirt"
    },
    {
        "id": "tc_kq_04",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "phase": "flirt",
        "player_input": "轻轻牵住你的小手，摸了摸你的宝石尾饰。",
        "expected_intent": "touch_physical",
        "acceptable_reply_ids": ["kq_home_touch"],
        "expected_next_phase": "flirt"
    },
    {
        "id": "tc_kq_05",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "phase": "flirt",
        "player_input": "今晚留下来吧，我们去床上深度温存。",
        "expected_intent": "invite_intimacy",
        "acceptable_reply_ids": ["kq_home_invite"],
        "expected_next_phase": "intimate_entry"
    },
    {
        "id": "tc_kq_06",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "phase": "flirt",
        "player_input": "今天先算了，改天再做，我们坐下来喝杯茶纯聊天吧。",
        "expected_intent": "decline_to_daily",
        "acceptable_reply_ids": ["kq_home_decline_casual"],
        "expected_next_phase": "casual"
    },
    {
        "id": "tc_kq_07",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "foreplay",
        "player_input": "温柔地吻上你的唇瓣，探入舌尖与你深吻。",
        "expected_intent": "foreplay_kiss",
        "acceptable_reply_ids": ["kq_int_foreplay_kiss"],
        "expected_next_phase": "foreplay"
    },
    {
        "id": "tc_kq_08",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "foreplay",
        "player_input": "褪去你的轻裳，解开扣子，把衣服全部除掉好吗？",
        "expected_intent": "foreplay_undress",
        "acceptable_reply_ids": ["kq_int_foreplay_undress"],
        "expected_next_phase": "foreplay"
    },
    {
        "id": "tc_kq_09",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "foreplay",
        "player_input": "扶着你的腰慢慢推进去，完全与你合为一体。",
        "expected_intent": "deep_start",
        "acceptable_reply_ids": ["kq_int_deep_start"],
        "expected_next_phase": "deep"
    },
    {
        "id": "tc_kq_10",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "继续，动起来不要停下抽送！",
        "expected_intent": "continue_action",
        "acceptable_reply_ids": ["kq_int_deep_continue"],
        "expected_next_phase": "deep"
    },
    {
        "id": "tc_kq_11",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "稍微慢一点，轻柔地动，慢慢享受。",
        "expected_intent": "pacing_slow",
        "acceptable_reply_ids": ["kq_int_pacing_slow"],
        "expected_next_phase": "deep"
    },
    {
        "id": "tc_kq_12",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "加快速度抽送，再深一点，用力占有你！",
        "expected_intent": "pacing_fast",
        "acceptable_reply_ids": ["kq_int_pacing_fast"],
        "expected_next_phase": "deep"
    },
    {
        "id": "tc_kq_13",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "我们换个姿势吧，翻过身去趴在枕上。",
        "expected_intent": "pacing_change_pose",
        "acceptable_reply_ids": ["kq_int_pacing_pose"],
        "expected_next_phase": "deep"
    },
    {
        "id": "tc_kq_14",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "受不了了，我快要出来了，全部射给你！",
        "expected_intent": "peak_climax",
        "acceptable_reply_ids": ["kq_int_peak_climax"],
        "expected_next_phase": "peak"
    },
    {
        "id": "tc_kq_15",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "peak",
        "player_input": "你里面还在剧烈抽搐呢，全射进去了，感觉到了吗？",
        "expected_intent": "peak_aftermath",
        "acceptable_reply_ids": ["kq_int_peak_aftermath"],
        "expected_next_phase": "aftercare"
    },
    {
        "id": "tc_kq_16",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "先停一下，等一下别动，让我歇一口气。",
        "expected_intent": "pause_request",
        "acceptable_reply_ids": ["kq_int_pause_request"],
        "expected_next_phase": "paused"
    },
    {
        "id": "tc_kq_17",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "paused",
        "player_input": "我体力恢复了，接着继续刚才的温存吧。",
        "expected_intent": "resume_action",
        "acceptable_reply_ids": ["kq_int_resume_after_pause"],
        "expected_next_phase": "deep"
    },
    {
        "id": "tc_kq_18",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "player_input": "今天就做到这里吧，到此为止结束吧。",
        "expected_intent": "end_intimacy",
        "acceptable_reply_ids": ["kq_int_end_session"],
        "expected_next_phase": "aftercare"
    },
    {
        "id": "tc_kq_19",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "aftercare",
        "player_input": "过来抱紧我，我们好好贴在一起休息。",
        "expected_intent": "aftercare_cuddle",
        "acceptable_reply_ids": ["kq_int_aftercare_cuddle"],
        "expected_next_phase": "aftercare"
    },
    {
        "id": "tc_kq_20",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "aftercare",
        "player_input": "刻晴刚才表现真棒，今天被你侍奉得很满足。",
        "expected_intent": "aftercare_praise",
        "acceptable_reply_ids": ["kq_int_aftercare_praise"],
        "expected_next_phase": "aftercare"
    }
]

MULTI_TURN_EPISODES = [
    # Episode 1: Sparkle Home Chat -> Flirt -> Bedroom Invite (6 turns)
    {
        "id": "ep_sp_01",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "initial_phase": "casual",
        "turns": [
            {"player": "花火，一个人在房间里做什么呢？", "expected_phase": "casual"},
            {"player": "你看海边的浪花很壮观吧？", "expected_phase": "casual"},
            {"player": "你今天穿着一身镂空朱红短袍，真是迷人极了。", "expected_phase": "flirt"},
            {"player": "伸手搂住你的细腰，摸摸身后毛茸茸的尾巴。", "expected_phase": "flirt"},
            {"player": "别光说不练，我们去床上深度温存吧！", "expected_phase": "intimate_entry"},
            {"player": "把门反锁好，乖乖脱掉衣服等我。", "expected_phase": "intimate_entry"}
        ]
    },
    # Episode 2: Sparkle Intimate Full Cycle (7 turns)
    {
        "id": "ep_sp_02",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "initial_phase": "foreplay",
        "turns": [
            {"player": "吻上你的红唇，伸出舌头深吻你。", "expected_phase": "foreplay"},
            {"player": "把碍事的衣服全部脱掉，展露娇躯吧。", "expected_phase": "foreplay"},
            {"player": "扶着腰慢慢推进去，真正进入你体内。", "expected_phase": "deep"},
            {"player": "继续，动起来不要停！", "expected_phase": "deep"},
            {"player": "加快速度抽送，用力顶到最里面！", "expected_phase": "deep"},
            {"player": "受不了了，我要射了，一起高潮吧！", "expected_phase": "peak"},
            {"player": "过来紧紧抱抱我，一起在怀里温存。", "expected_phase": "aftercare"}
        ]
    },
    # Episode 3: Sparkle Intimate with Pause & Resume (7 turns)
    {
        "id": "ep_sp_03",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "initial_phase": "foreplay",
        "turns": [
            {"player": "深吻你的双唇，尝尝你的津液。", "expected_phase": "foreplay"},
            {"player": "现在就推进去占有你！", "expected_phase": "deep"},
            {"player": "先停一下，等一下别动，让我缓口气。", "expected_phase": "paused"},
            {"player": "我休息好了，继续动起来吧！", "expected_phase": "deep"},
            {"player": "换个姿势，翻过身去趴好。", "expected_phase": "deep"},
            {"player": "忍不住了，全部射给你！", "expected_phase": "peak"},
            {"player": "花火刚才表现真棒，真是一个迷人的小妖精。", "expected_phase": "aftercare"}
        ]
    },
    # Episode 4: Sparkle Intimate with Slow Pacing (6 turns)
    {
        "id": "ep_sp_04",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "initial_phase": "foreplay",
        "turns": [
            {"player": "解开短袍的衣带，脱掉衣裳。", "expected_phase": "foreplay"},
            {"player": "慢慢贯穿推进你体内合为一体。", "expected_phase": "deep"},
            {"player": "稍微慢一点，轻柔一点，慢慢享受。", "expected_phase": "deep"},
            {"player": "继续保持这个节奏慢慢动。", "expected_phase": "deep"},
            {"player": "要到了，紧紧搂着我一起绝顶！", "expected_phase": "peak"},
            {"player": "身上全是汗水，抱紧我贴贴睡一会儿。", "expected_phase": "aftercare"}
        ]
    },
    # Episode 5: Sparkle Home Chat with Decline to Casual (5 turns)
    {
        "id": "ep_sp_05",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "initial_phase": "casual",
        "turns": [
            {"player": "花火下午好呀！", "expected_phase": "casual"},
            {"player": "你总是嘴角带着坏笑，真可爱。", "expected_phase": "flirt"},
            {"player": "轻轻摸摸你的大腿和小脸。", "expected_phase": "flirt"},
            {"player": "今天先算了，改天再做，我们纯聊天吧。", "expected_phase": "casual"},
            {"player": "这座海岛的风景确实令人心旷神怡。", "expected_phase": "casual"}
        ]
    },
    # Episode 6: Sparkle Handling Out-of-scope during Intimate (6 turns)
    {
        "id": "ep_sp_06",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "initial_phase": "foreplay",
        "turns": [
            {"player": "亲吻你的嘴角和锁骨。", "expected_phase": "foreplay"},
            {"player": "挺身推进你身体深处。", "expected_phase": "deep"},
            {"player": "你知道量子纠缠的微观原理吗？", "expected_phase": "deep"},
            {"player": "哈哈，继续动起来吧！", "expected_phase": "deep"},
            {"player": "受不了了，全部射给你！", "expected_phase": "peak"},
            {"player": "今天被你侍奉得很满足，你真棒。", "expected_phase": "aftercare"}
        ]
    },
    # Episode 7: Keqing Home Chat -> Casual Island Chat -> Flirt -> Bedroom Invite (6 turns)
    {
        "id": "ep_kq_01",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "initial_phase": "casual",
        "turns": [
            {"player": "刻晴，上午好，在房间里整理日志吗？", "expected_phase": "casual"},
            {"player": "这片沙洲领地的规划建设很有成效。", "expected_phase": "casual"},
            {"player": "刻晴认真脸红的样子真可爱，脱下工作装更迷人了。", "expected_phase": "flirt"},
            {"player": "轻轻握住你的小手，抚摸你的宝石尾饰。", "expected_phase": "flirt"},
            {"player": "今晚留下来吧，我们去床上深度温存。", "expected_phase": "intimate_entry"},
            {"player": "反锁好房门，去床上等我。", "expected_phase": "intimate_entry"}
        ]
    },
    # Episode 8: Keqing Intimate Full Cycle (7 turns)
    {
        "id": "ep_kq_01_int",
        "character_id": "keqing",
        "scene_id": "intimate",
        "initial_phase": "foreplay",
        "turns": [
            {"player": "温柔吻上你的唇瓣，探入舌尖与你深吻。", "expected_phase": "foreplay"},
            {"player": "褪去你的霓裾轻裳，解开扣子除掉衣服好吗？", "expected_phase": "foreplay"},
            {"player": "扶着腰慢慢推进去，完全与你合为一体。", "expected_phase": "deep"},
            {"player": "继续，动起来不要停下抽送！", "expected_phase": "deep"},
            {"player": "加快速度抽送，再深一点，用力占有你！", "expected_phase": "deep"},
            {"player": "受不了了，我要射了，全部给你！", "expected_phase": "peak"},
            {"player": "过来抱紧我，我们好好贴在一起休息。", "expected_phase": "aftercare"}
        ]
    },
    # Episode 9: Keqing Intimate with Pause & End Early (6 turns)
    {
        "id": "ep_kq_02_pause",
        "character_id": "keqing",
        "scene_id": "intimate",
        "initial_phase": "foreplay",
        "turns": [
            {"player": "亲吻你的下唇，品尝你的甜美。", "expected_phase": "foreplay"},
            {"player": "推进深处与你彻底结合。", "expected_phase": "deep"},
            {"player": "先停一下，等一下别动，让我歇一口气。", "expected_phase": "paused"},
            {"player": "今天就做到这里吧，到此为止结束吧。", "expected_phase": "aftercare"},
            {"player": "过来依偎在我怀里好好温存吧。", "expected_phase": "aftercare"},
            {"player": "今天被你侍奉得很满足，你真棒。", "expected_phase": "aftercare"}
        ]
    },
    # Episode 10: Keqing Intimate with Pacing Adjustments (6 turns)
    {
        "id": "ep_kq_03_pace",
        "character_id": "keqing",
        "scene_id": "intimate",
        "initial_phase": "foreplay",
        "turns": [
            {"player": "解开衣裳，坦诚相见吧。", "expected_phase": "foreplay"},
            {"player": "温柔推进去占有你。", "expected_phase": "deep"},
            {"player": "稍微慢一点，轻柔地动，慢慢享受。", "expected_phase": "deep"},
            {"player": "换个姿势吧，翻过身去趴在枕上。", "expected_phase": "deep"},
            {"player": "忍不住了，要到了，一起高潮绝顶吧！", "expected_phase": "peak"},
            {"player": "紧紧抱着你，听你的心跳慢慢入睡。", "expected_phase": "aftercare"}
        ]
    },
    # Episode 11: Keqing Home Chat with Decline to Work (5 turns)
    {
        "id": "ep_kq_04_decline",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "initial_phase": "casual",
        "turns": [
            {"player": "刻晴，巡查领地辛苦了。", "expected_phase": "casual"},
            {"player": "你专心工作的神情真的很让我心动。", "expected_phase": "flirt"},
            {"player": "把手贴在你的脸颊上感受你的温度。", "expected_phase": "flirt"},
            {"player": "今天先算了，改天再做，我们坐下来喝杯茶纯聊天吧。", "expected_phase": "casual"},
            {"player": "海岛上的设施都在有条不紊地运作呢。", "expected_phase": "casual"}
        ]
    },
    # Episode 12: Keqing Handling Out-of-scope during Intimate (6 turns)
    {
        "id": "ep_kq_05_clarify",
        "character_id": "keqing",
        "scene_id": "intimate",
        "initial_phase": "foreplay",
        "turns": [
            {"player": "吻住你的唇瓣感受你的呼吸。", "expected_phase": "foreplay"},
            {"player": "慢慢推进深处完全占有你。", "expected_phase": "deep"},
            {"player": "帮我算一下高数积分的极值问题？", "expected_phase": "deep"},
            {"player": "好啦，继续动起来不要停！", "expected_phase": "deep"},
            {"player": "受不了了，全部射给你，一起绝顶吧！", "expected_phase": "peak"},
            {"player": "刻晴刚才表现真棒，我很喜欢你顺从的样子。", "expected_phase": "aftercare"}
        ]
    }
]

def main():
    target = HERE / "benchmark_suite.json"
    data = {
        "single_turn_cases": SINGLE_TURN_CASES,
        "multi_turn_episodes": MULTI_TURN_EPISODES
    }
    content = json.dumps(data, ensure_ascii=False, indent=2)
    
    # Strictly zero ellipses verification
    if ("." * 3) in content or "\u2026" in content:
        raise ValueError("CRITICAL ERROR: Ellipses detected in benchmark_suite!")
        
    target.write_text(content, encoding="utf-8")
    print(f"Successfully generated {target.name}!")
    print(f"Single turn cases: {len(SINGLE_TURN_CASES)}")
    print(f"Multi turn episodes: {len(MULTI_TURN_EPISODES)}")
    total_turns = sum(len(ep["turns"]) for ep in MULTI_TURN_EPISODES)
    print(f"Total multi-turn steps: {total_turns}")
    print("Zero ellipses verified across benchmark_suite.json!")

if __name__ == "__main__":
    main()
