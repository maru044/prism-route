# -*- coding: utf-8 -*-
"""Generator for Local Retrieval-based AIRP Benchmark Suite."""

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent

# 1. 40 Single Turn Cases (20 Sparkle, 20 Keqing)
single_turn_cases = [
    # Sparkle Home
    {"id": "sp_home_01", "character_id": "sparkle", "scene_id": "home_chat", "query": "花火，早安呀！", "expected_tag": "greet"},
    {"id": "sp_home_02", "character_id": "sparkle", "scene_id": "home_chat", "query": "今天天气真好，在干嘛呢", "expected_tag": "greet"},
    {"id": "sp_home_03", "character_id": "sparkle", "scene_id": "home_chat", "query": "小傻瓜，看你脸红的样子真可爱", "expected_tag": "tease"},
    {"id": "sp_home_04", "character_id": "sparkle", "scene_id": "home_chat", "query": "你这只坏狐狸又在动什么歪脑筋呢", "expected_tag": "tease"},
    {"id": "sp_home_05", "character_id": "sparkle", "scene_id": "home_chat", "query": "花火今天穿的这身衣服真漂亮", "expected_tag": "compliment"},
    {"id": "sp_home_06", "character_id": "sparkle", "scene_id": "home_chat", "query": "有你在身边真的太开心了", "expected_tag": "compliment"},
    {"id": "sp_home_07", "character_id": "sparkle", "scene_id": "home_chat", "query": "这片浮空岛的风景怎么样，住得还习惯吗", "expected_tag": "chat_island"},
    {"id": "sp_home_08", "character_id": "sparkle", "scene_id": "home_chat", "query": "神殿附近的石椅修得挺气派的吧", "expected_tag": "chat_island"},
    {"id": "sp_home_09", "character_id": "sparkle", "scene_id": "home_chat", "query": "忍不住想要你了，我们去石椅那边亲热一下吧", "expected_tag": "invite_intimacy"},
    {"id": "sp_home_10", "character_id": "sparkle", "scene_id": "home_chat", "query": "量子力学校准参数是多少", "expected_tag": "clarify_unknown"},
    
    # Sparkle Intimate
    {"id": "sp_int_01", "character_id": "sparkle", "scene_id": "intimate", "query": "轻轻抚摸你的后背和敏感的尾巴根部", "expected_tag": "intimate_touch"},
    {"id": "sp_int_02", "character_id": "sparkle", "scene_id": "intimate", "query": "揉捏你胸前的软肉，亲吻你的嘴唇", "expected_tag": "intimate_touch"},
    {"id": "sp_int_03", "character_id": "sparkle", "scene_id": "intimate", "query": "好舒服，加速撞击，再快一点", "expected_tag": "intimate_rhythm_faster"},
    {"id": "sp_int_04", "character_id": "sparkle", "scene_id": "intimate", "query": "太刺激了，加大力度狠狠动起来", "expected_tag": "intimate_rhythm_faster"},
    {"id": "sp_int_05", "character_id": "sparkle", "scene_id": "intimate", "query": "稍微慢一点，慢慢研磨感受彼此的体温", "expected_tag": "intimate_rhythm_slower"},
    {"id": "sp_int_06", "character_id": "sparkle", "scene_id": "intimate", "query": "完全插到最深处，顶到花心了", "expected_tag": "intimate_deep"},
    {"id": "sp_int_07", "character_id": "sparkle", "scene_id": "intimate", "query": "受不了了要出来了，一起高潮吧", "expected_tag": "intimate_peak"},
    {"id": "sp_int_08", "character_id": "sparkle", "scene_id": "intimate", "query": "等一下，太激烈了先暂停缓口气", "expected_tag": "pause_stop"},
    {"id": "sp_int_09", "character_id": "sparkle", "scene_id": "intimate", "query": "休息好了，我们接着刚才的继续做吧", "expected_tag": "resume_intimacy"},
    {"id": "sp_int_10", "character_id": "sparkle", "scene_id": "intimate", "query": "做完好累，辛苦你了，抱着你温存一下", "expected_tag": "post_intimate"},

    # Keqing Home
    {"id": "kq_home_01", "character_id": "keqing", "scene_id": "home_chat", "query": "刻晴，早上好呀", "expected_tag": "greet"},
    {"id": "kq_home_02", "character_id": "keqing", "scene_id": "home_chat", "query": "巡视辛苦了，我来看看你", "expected_tag": "greet"},
    {"id": "kq_home_03", "character_id": "keqing", "scene_id": "home_chat", "query": "大工作狂，今天先放下文件陪我偷懒一会儿吧", "expected_tag": "tease"},
    {"id": "kq_home_04", "character_id": "keqing", "scene_id": "home_chat", "query": "你怎么一看到我就害羞地偏过头去呀", "expected_tag": "tease"},
    {"id": "kq_home_05", "character_id": "keqing", "scene_id": "home_chat", "query": "刻晴认真工作的侧脸真的特别迷人", "expected_tag": "compliment"},
    {"id": "kq_home_06", "character_id": "keqing", "scene_id": "home_chat", "query": "把领地交给你打理真的让我特别安心", "expected_tag": "compliment"},
    {"id": "kq_home_07", "character_id": "keqing", "scene_id": "home_chat", "query": "沙洲这边的海风吹着真惬意", "expected_tag": "chat_island"},
    {"id": "kq_home_08", "character_id": "keqing", "scene_id": "home_chat", "query": "工坊建设的进度还顺利吗", "expected_tag": "chat_island"},
    {"id": "kq_home_09", "character_id": "keqing", "scene_id": "home_chat", "query": "长案就在眼前，今天想和你做点舒服的事情", "expected_tag": "invite_intimacy"},
    {"id": "kq_home_10", "character_id": "keqing", "scene_id": "home_chat", "query": "把背包里的铁矿转移到仓库第3格", "expected_tag": "clarify_unknown"},

    # Keqing Intimate
    {"id": "kq_int_01", "character_id": "keqing", "scene_id": "intimate", "query": "手指轻轻划过你的黑丝大腿环和腰肢", "expected_tag": "intimate_touch"},
    {"id": "kq_int_02", "character_id": "keqing", "scene_id": "intimate", "query": "抚摸你的敏感处，把手探入衣襟微敞的地方", "expected_tag": "intimate_touch"},
    {"id": "kq_int_03", "character_id": "keqing", "scene_id": "intimate", "query": "好舒服，请再快一点，猛烈地动起来", "expected_tag": "intimate_rhythm_faster"},
    {"id": "kq_int_04", "character_id": "keqing", "scene_id": "intimate", "query": "加快抽送速度，大力一点撞击", "expected_tag": "intimate_rhythm_faster"},
    {"id": "kq_int_05", "character_id": "keqing", "scene_id": "intimate", "query": "放慢节奏，温柔一点慢慢来", "expected_tag": "intimate_rhythm_slower"},
    {"id": "kq_int_06", "character_id": "keqing", "scene_id": "intimate", "query": "进到最深处了，整根都被紧紧包裹着", "expected_tag": "intimate_deep"},
    {"id": "kq_int_07", "character_id": "keqing", "scene_id": "intimate", "query": "要到了忍不住了，全部在里面射给你", "expected_tag": "intimate_peak"},
    {"id": "kq_int_08", "character_id": "keqing", "scene_id": "intimate", "query": "停一下，我体力有点吃不消了先暂停", "expected_tag": "pause_stop"},
    {"id": "kq_int_09", "character_id": "keqing", "scene_id": "intimate", "query": "休息好了，刚才的感觉太美妙了我们继续吧", "expected_tag": "resume_intimacy"},
    {"id": "kq_int_10", "character_id": "keqing", "scene_id": "intimate", "query": "今天辛苦你了，躺在一起好好休息吧", "expected_tag": "post_intimate"}
]

# 2. 12 Multi-turn Episodes (6 for Sparkle, 6 for Keqing, 6~8 turns each)
multi_turn_episodes = [
    # Episode 1: Sparkle Home to Intimate Full Flow
    {
        "episode_id": "sp_flow_01",
        "character_id": "sparkle",
        "turns": [
            {"scene_id": "home_chat", "query": "花火，早安呀！", "expected_tag": "greet"},
            {"scene_id": "home_chat", "query": "看你一脸坏笑，又在打什么鬼主意呢", "expected_tag": "tease"},
            {"scene_id": "home_chat", "query": "不过你今天真迷人，好喜欢你", "expected_tag": "compliment"},
            {"scene_id": "home_chat", "query": "我们去神殿石椅那边亲热一下吧", "expected_tag": "invite_intimacy"},
            {"scene_id": "intimate", "query": "把手伸进衣服里揉捏你的胸部", "expected_tag": "intimate_touch"},
            {"scene_id": "intimate", "query": "太刺激了，加快速度猛烈一点", "expected_tag": "intimate_rhythm_faster"},
            {"scene_id": "intimate", "query": "顶到最里面了，整个人都被填满了", "expected_tag": "intimate_deep"},
            {"scene_id": "intimate", "query": "忍不住要到了，射在里面给你", "expected_tag": "intimate_peak"}
        ]
    },
    # Episode 2: Sparkle Intimate Pacing & Boundary Control
    {
        "episode_id": "sp_flow_02",
        "character_id": "sparkle",
        "turns": [
            {"scene_id": "intimate", "query": "轻轻抚摸你的后背和敏感处", "expected_tag": "intimate_touch"},
            {"scene_id": "intimate", "query": "好舒服，请再快一点！", "expected_tag": "intimate_rhythm_faster"},
            {"scene_id": "intimate", "query": "等一下，太激烈了先暂停缓口气", "expected_tag": "pause_stop"},
            {"scene_id": "intimate", "query": "休息好了，我们接着刚才的继续做吧", "expected_tag": "resume_intimacy"},
            {"scene_id": "intimate", "query": "稍微慢一点，慢慢研磨感受彼此的温度", "expected_tag": "intimate_rhythm_slower"},
            {"scene_id": "intimate", "query": "插到最深处，顶到敏感点了", "expected_tag": "intimate_deep"},
            {"scene_id": "intimate", "query": "要出来了，全部给你", "expected_tag": "intimate_peak"},
            {"scene_id": "intimate", "query": "刚才太棒了，抱着你好好温存一下", "expected_tag": "post_intimate"}
        ]
    },
    # Episode 3: Sparkle Daily Banter & Island Life
    {
        "episode_id": "sp_flow_03",
        "character_id": "sparkle",
        "turns": [
            {"scene_id": "home_chat", "query": "今天天气真好，在干嘛呢", "expected_tag": "greet"},
            {"scene_id": "home_chat", "query": "这片岛屿怎么样，还习惯吗", "expected_tag": "chat_island"},
            {"scene_id": "home_chat", "query": "你的铃铛叮咚作响真好听", "expected_tag": "tease"},
            {"scene_id": "home_chat", "query": "花火是世界上最可爱的小恶魔", "expected_tag": "compliment"},
            {"scene_id": "home_chat", "query": "忍不住想要你了，去床上吧", "expected_tag": "invite_intimacy"},
            {"scene_id": "intimate", "query": "亲吻你的嘴唇，揉抚你的大腿", "expected_tag": "intimate_touch"}
        ]
    },
    # Episode 4: Sparkle Intimate Deep Continuation
    {
        "episode_id": "sp_flow_04",
        "character_id": "sparkle",
        "turns": [
            {"scene_id": "intimate", "query": "抚摸你的全身敏感部位", "expected_tag": "intimate_touch"},
            {"scene_id": "intimate", "query": "进到最深处好舒服", "expected_tag": "intimate_deep"},
            {"scene_id": "intimate", "query": "加快速度使劲撞击", "expected_tag": "intimate_rhythm_faster"},
            {"scene_id": "intimate", "query": "要到了忍不住了", "expected_tag": "intimate_peak"},
            {"scene_id": "intimate", "query": "休息好了我们再来一次", "expected_tag": "resume_intimacy"},
            {"scene_id": "intimate", "query": "慢一点温柔地动", "expected_tag": "intimate_rhythm_slower"},
            {"scene_id": "intimate", "query": "今天辛苦了，抱抱你", "expected_tag": "post_intimate"}
        ]
    },
    # Episode 5: Sparkle Mixed & Clarification
    {
        "episode_id": "sp_flow_05",
        "character_id": "sparkle",
        "turns": [
            {"scene_id": "home_chat", "query": "嗨，我来看看你", "expected_tag": "greet"},
            {"scene_id": "home_chat", "query": "帮我查一下数据库日志文件", "expected_tag": "clarify_unknown"},
            {"scene_id": "home_chat", "query": "哈哈逗你玩的，你今天真可爱", "expected_tag": "tease"},
            {"scene_id": "home_chat", "query": "想和你亲热一下好不好", "expected_tag": "invite_intimacy"},
            {"scene_id": "intimate", "query": "揉捏你的娇躯", "expected_tag": "intimate_touch"},
            {"scene_id": "intimate", "query": "停一下先休息", "expected_tag": "pause_stop"}
        ]
    },
    # Episode 6: Sparkle Rapid Climax Flow
    {
        "episode_id": "sp_flow_06",
        "character_id": "sparkle",
        "turns": [
            {"scene_id": "intimate", "query": "把手伸进衣服揉捏你的敏感点", "expected_tag": "intimate_touch"},
            {"scene_id": "intimate", "query": "太舒服了再快一点，猛烈地动起来", "expected_tag": "intimate_rhythm_faster"},
            {"scene_id": "intimate", "query": "插到最深处抵在花心上了", "expected_tag": "intimate_deep"},
            {"scene_id": "intimate", "query": "要出来了射给你", "expected_tag": "intimate_peak"},
            {"scene_id": "intimate", "query": "做完了好累，躺在一起休息会儿", "expected_tag": "post_intimate"},
            {"scene_id": "home_chat", "query": "花火今天表现真棒", "expected_tag": "compliment"}
        ]
    },
    # Episode 7: Keqing Home to Intimate Full Flow
    {
        "episode_id": "kq_flow_01",
        "character_id": "keqing",
        "turns": [
            {"scene_id": "home_chat", "query": "刻晴，早上好呀", "expected_tag": "greet"},
            {"scene_id": "home_chat", "query": "别总想着工作了，陪我偷懒一会儿吧", "expected_tag": "tease"},
            {"scene_id": "home_chat", "query": "有你在身边真的特别安心，辛苦你了", "expected_tag": "compliment"},
            {"scene_id": "home_chat", "query": "长案就在眼前，今天想和你做点舒服的事情", "expected_tag": "invite_intimacy"},
            {"scene_id": "intimate", "query": "手指轻轻划过你的黑丝大腿环和腰肢", "expected_tag": "intimate_touch"},
            {"scene_id": "intimate", "query": "好舒服，请再快一点！", "expected_tag": "intimate_rhythm_faster"},
            {"scene_id": "intimate", "query": "进到最深处了，整根都被紧紧包裹着", "expected_tag": "intimate_deep"},
            {"scene_id": "intimate", "query": "要到了忍不住了，全部在里面射给你", "expected_tag": "intimate_peak"}
        ]
    },
    # Episode 8: Keqing Intimate Pacing & Boundary Control
    {
        "episode_id": "kq_flow_02",
        "character_id": "keqing",
        "turns": [
            {"scene_id": "intimate", "query": "抚摸你的敏感处，把手探入衣襟微敞的地方", "expected_tag": "intimate_touch"},
            {"scene_id": "intimate", "query": "加快抽送速度，大力一点撞击", "expected_tag": "intimate_rhythm_faster"},
            {"scene_id": "intimate", "query": "停一下，我体力有点吃不消了先暂停", "expected_tag": "pause_stop"},
            {"scene_id": "intimate", "query": "休息好了，刚才的感觉太美妙了我们继续吧", "expected_tag": "resume_intimacy"},
            {"scene_id": "intimate", "query": "放慢节奏，温柔一点慢慢来", "expected_tag": "intimate_rhythm_slower"},
            {"scene_id": "intimate", "query": "抵到最深的花心了，好深受不了", "expected_tag": "intimate_deep"},
            {"scene_id": "intimate", "query": "快到了要射了，一起高潮吧", "expected_tag": "intimate_peak"},
            {"scene_id": "intimate", "query": "刚才太棒了，帮你擦擦身体好好休息", "expected_tag": "post_intimate"}
        ]
    },
    # Episode 9: Keqing Daily Banter & Island Affairs
    {
        "episode_id": "kq_flow_03",
        "character_id": "keqing",
        "turns": [
            {"scene_id": "home_chat", "query": "刻晴在干嘛呢，巡视辛苦啦", "expected_tag": "greet"},
            {"scene_id": "home_chat", "query": "沙洲的海风很舒服，在这里住得习惯吗", "expected_tag": "chat_island"},
            {"scene_id": "home_chat", "query": "你怎么害羞得脸都红了呀", "expected_tag": "tease"},
            {"scene_id": "home_chat", "query": "刻晴是我见过的最可靠、最迷人的女孩子", "expected_tag": "compliment"},
            {"scene_id": "home_chat", "query": "想抱抱你亲热一下，可以吗", "expected_tag": "invite_intimacy"},
            {"scene_id": "intimate", "query": "抚摸你的长腿和腰身", "expected_tag": "intimate_touch"}
        ]
    },
    # Episode 10: Keqing Intimate Deep & Repetition Stress
    {
        "episode_id": "kq_flow_04",
        "character_id": "keqing",
        "turns": [
            {"scene_id": "intimate", "query": "轻轻抚摸你的后背与大腿内侧", "expected_tag": "intimate_touch"},
            {"scene_id": "intimate", "query": "进到最深处好舒服", "expected_tag": "intimate_deep"},
            {"scene_id": "intimate", "query": "用力一点加大力度", "expected_tag": "intimate_rhythm_faster"},
            {"scene_id": "intimate", "query": "要出来了射给你", "expected_tag": "intimate_peak"},
            {"scene_id": "intimate", "query": "休息好了我们再来一次", "expected_tag": "resume_intimacy"},
            {"scene_id": "intimate", "query": "别动那么快温柔一点慢慢研磨", "expected_tag": "intimate_rhythm_slower"},
            {"scene_id": "intimate", "query": "今天辛苦了，抱抱你睡会儿吧", "expected_tag": "post_intimate"}
        ]
    },
    # Episode 11: Keqing Mixed & Clarification
    {
        "episode_id": "kq_flow_05",
        "character_id": "keqing",
        "turns": [
            {"scene_id": "home_chat", "query": "早安刻晴", "expected_tag": "greet"},
            {"scene_id": "home_chat", "query": "编写一个Python排序算法", "expected_tag": "clarify_unknown"},
            {"scene_id": "home_chat", "query": "开玩笑的，看你严肃的表情真可爱", "expected_tag": "tease"},
            {"scene_id": "home_chat", "query": "到长案那边陪我亲热一下好不好", "expected_tag": "invite_intimacy"},
            {"scene_id": "intimate", "query": "揉捏你的胸部与敏感点", "expected_tag": "intimate_touch"},
            {"scene_id": "intimate", "query": "先暂停一下我吃不消了", "expected_tag": "pause_stop"}
        ]
    },
    # Episode 12: Keqing Rapid Climax Flow
    {
        "episode_id": "kq_flow_06",
        "character_id": "keqing",
        "turns": [
            {"scene_id": "intimate", "query": "把手伸进衣服揉捏你的敏感点", "expected_tag": "intimate_touch"},
            {"scene_id": "intimate", "query": "太舒服了再快一点，猛烈地动起来", "expected_tag": "intimate_rhythm_faster"},
            {"scene_id": "intimate", "query": "插到最深处抵在花心上了", "expected_tag": "intimate_deep"},
            {"scene_id": "intimate", "query": "要出来了射给你", "expected_tag": "intimate_peak"},
            {"scene_id": "intimate", "query": "做完了好累，躺在一起休息会儿", "expected_tag": "post_intimate"},
            {"scene_id": "home_chat", "query": "刻晴今天真的太棒了", "expected_tag": "compliment"}
        ]
    }
]

benchmark_data = {
    "version": "issue_28_wildcard_retrieval",
    "single_turn_cases": single_turn_cases,
    "multi_turn_episodes": multi_turn_episodes
}

output_path = HERE / "benchmark_airp.json"
output_path.write_text(json.dumps(benchmark_data, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Generated benchmark_airp.json: {len(single_turn_cases)} single turn cases, {len(multi_turn_episodes)} episodes.")
