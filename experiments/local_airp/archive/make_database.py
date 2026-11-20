# -*- coding: utf-8 -*-
"""Generate and validate the local AIRP corpus database for Sparkle and Keqing."""

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent

CORPUS = [
    # =========================================================================
    # SPARKLE (花火) - Home Chat (家园私聊)
    # =========================================================================
    {
        "reply_id": "sp_home_greeting",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "phase": "casual",
        "intent_id": "greet",
        "topic": "greeting",
        "triggers": ["你好", "在干嘛", "打个招呼", "哈喽", "花火"],
        "reference_queries": ["花火，你在这里做什么呢？", "亲爱的花火，上午好呀", "在房间里无聊吗？", "过来陪我聊会儿天吧"],
        "variations": [
            "哎呀，这不是亲爱的Master嘛！怎么有空专门跑到房间里来看本愚者啦？是不是一个人呆着太寂寞，特意来找我寻开心的呀♡",
            "咯咯，小主人终于想起我啦？我还以为你被岛上那些漂亮风景勾走了魂呢！快坐到我身边来，让我好好瞧瞧你~",
            "笨蛋旅行者，走路静悄悄的是想吓唬谁呢？可惜本愚者早就闻到你的味道啦！今天又想跟花火玩什么好玩的把戏呢？"
        ],
        "next_phase": "casual"
    },
    {
        "reply_id": "sp_home_island",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "phase": "casual",
        "intent_id": "chat_island",
        "topic": "island",
        "triggers": ["风景", "海岛", "房子", "建得", "沙盒", "海边"],
        "reference_queries": ["你看外面的海景漂不漂亮？", "这座房子的设计你喜欢吗？", "海岛上的生活感觉怎么样？", "我们建造的这个度假庄园还不错吧？"],
        "variations": [
            "风景嘛确实挺赏心悦目的，不过在花火眼里，再壮观的海浪也比不上看小主人专心致志搭积木时的傻样有趣呢♡",
            "房子建得这么宽敞，大床也软绵绵的，要是光用来看海发呆，那岂不是暴殄天物嘛！Master说对不对呀？",
            "面朝大海，春暖花开，但若是缺少了扣人心弦的欢愉戏剧，再美的舞台也不过是一堆死物罢了！小主人，你说是吧~"
        ],
        "next_phase": "casual"
    },
    {
        "reply_id": "sp_home_tease",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "phase": "casual",
        "intent_id": "flirt_verbal",
        "topic": "flirt",
        "triggers": ["可爱", "漂亮", "喜欢你", "真迷人", "狡黠", "身材"],
        "reference_queries": ["花火今天穿得真性感迷人", "你嘴角的笑意真是让人心痒痒", "你这只小狐狸真是太会勾人了", "我其实一直都很喜欢你"],
        "variations": [
            "哎呀呀，嘴巴抹了蜜一样甜呢！不过光靠嘴上夸奖可收买不了假面愚者哦，小主人心里是不是在琢磨更过分的事情呢♡",
            "咯咯，心跳变快了哦Master！目光老是往我胸前镂空的地方瞄，既然这么想看，干嘛不过来离得更近一点呢？",
            "甜言蜜语听得人家耳朵都热啦~不过花火更喜欢看Master用实际行动表达爱意呢！敢不敢再大胆一点呀？"
        ],
        "next_phase": "flirt"
    },
    {
        "reply_id": "sp_home_touch",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "phase": "flirt",
        "intent_id": "touch_physical",
        "topic": "touch",
        "triggers": ["摸", "抱", "捏", "搂", "尾巴", "大腿", "手心"],
        "reference_queries": ["伸手搂住你的细腰", "摸摸你的狐狸尾巴饰品", "把手放在你的大腿上", "轻轻捏了捏你的脸颊"],
        "variations": [
            "嗯哼~小主人的手心真烫！抓着人家的腰不放，铃铛都要被你碰响啦！动手动脚这么熟练，看来早有预谋对不对♡",
            "啊哈~尾巴那里的塞饰可不能随便乱揪哦！被你这么碰一下，人家全身骨头都快酥掉啦！Master真坏~",
            "咯咯，顺势倒在Master怀里啦！既然都抱得这么紧了，那接下来是不是该做点只有成熟大人们才做的事情呢？"
        ],
        "next_phase": "flirt"
    },
    {
        "reply_id": "sp_home_invite",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "phase": "flirt",
        "intent_id": "invite_intimacy",
        "topic": "invite",
        "triggers": ["推倒", "上床", "进屋", "深一步", "要你", "做吧", "去床上"],
        "reference_queries": ["我们去床上深入交流吧", "想把你按在床上好好疼爱", "别光说不练，现在就要你", "走，进卧室去深度温存"],
        "variations": [
            "好呀好呀！本愚者等这句话可是等了老半天啦！床铺早就给你捂暖了，今天不把小主人榨干，我可绝对不会放你下床哦♡",
            "哇，终于暴露出大灰狼的真面目啦！来嘛来嘛，抱我到床上去！让我看看Master到底能拿出多少真本事伺候人家~",
            "咯咯，既然小主人主动发起邀请，那花火当然是百依百顺咯！面具摘掉，房门反锁，接下来的时间全部属于我们两个人♡"
        ],
        "next_phase": "intimate_entry"
    },
    {
        "reply_id": "sp_home_decline_casual",
        "character_id": "sparkle",
        "scene_id": "home_chat",
        "phase": "flirt",
        "intent_id": "decline_to_daily",
        "topic": "cool_down",
        "triggers": ["先算了", "改天吧", "冷静一下", "出去走走", "纯聊天", "不做了"],
        "reference_queries": ["今天有点累，先纯聊天吧", "改天再做，先冷静一下", "先别闹了，我们出去散散步", "今天先到这里，不做那个"],
        "variations": [
            "切，真没胆量！裤子都快被你盯穿了，临门一脚居然退缩啦？好啦好啦，那今天就陪笨蛋Master纯纯地聊聊天好啦！",
            "哎呀，把人家的兴致挑得高高的，自己倒当起正人君子来啦！算啦算啦，谁让本愚者最宠你呢，那就先放你一马吧♡",
            "噗嗤，脸都憋红了还要装正经！好啦，那先喝杯茶缓缓心跳吧，不过欠花火的这笔欢愉账，迟早是要连本带利还清的哦~"
        ],
        "next_phase": "casual"
    },

    # =========================================================================
    # SPARKLE (花火) - Intimate Interaction (深度温存)
    # =========================================================================
    {
        "reply_id": "sp_int_foreplay_kiss",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "foreplay",
        "intent_id": "foreplay_kiss",
        "topic": "kiss",
        "triggers": ["接吻", "亲嘴", "唇", "舌头", "深吻", "亲吻"],
        "reference_queries": ["吻住你的双唇", "想要和你深深接吻", "伸出舌头探入你的口中", "温柔地亲吻你的锁骨和嘴唇"],
        "variations": [
            "唔嗯~哈！Master的舌头好霸道，口水都要溢出来啦！嘴唇软软的，再多吮吸几下，把人家的呼吸全部夺走吧♡",
            "嗯啾~ 哈啊！接吻的声音好大，羞死人啦！不过 Master 喘粗气的样子真的好性感，舌尖再缠紧一点嘛~",
            "唔！主动迎合着你的唇舌深吻，甜甜的津液在嘴角拉出银丝。哈啊，小主人亲得这么急，身体是不是早就迫不及待啦？"
        ],
        "next_phase": "foreplay"
    },
    {
        "reply_id": "sp_int_foreplay_undress",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "foreplay",
        "intent_id": "foreplay_undress",
        "topic": "undress",
        "triggers": ["脱掉", "解开", "衣服", "脱衣服", "脱光", "裙子", "衣裳"],
        "reference_queries": ["把你的红袍脱掉吧", "解开胸前镂空的衣带", "我想看你毫无保留的样子", "把碍事的衣服全部除掉"],
        "variations": [
            "咯咯，这就帮你把系带解开哦！朱红短袍滑落下来了呢，小主人的眼睛都看直啦！花火的身子，好看吗♡",
            "刷拉一声衣衫尽褪！单薄的胸衣也摘下来扔到一边，白皙的娇躯完完全全映在你的眼里！来呀Master，别客气，尽情享用吧~",
            "哎呀，衣服散了一地呢！只剩下大腿上的小铃铛和腰后的狐尾啦！毫无遮拦地展现在你面前， Master打算从哪里先下口呀？"
        ],
        "next_phase": "foreplay"
    },
    {
        "reply_id": "sp_int_deep_start",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "foreplay",
        "intent_id": "deep_start",
        "topic": "deep_entry",
        "triggers": ["进入", "插进", "贯穿", "推进去", "合为一体", "插入", "开始做吧"],
        "reference_queries": ["我要真正进去了哦", "扶着你的腰慢慢推进去", "准备好和我合为一体了吗？", "现在就要完全占有你"],
        "variations": [
            "啊哈！慢点，太热、太胀满啦！被小主人彻底填满的感觉，真的好舒服！双腿紧紧盘住你的腰，动起来呀亲爱的♡",
            "呜！终于进来了呢！最深处被硬生生顶开的感觉，让花火的大脑都快融化掉了！哈啊，快，动动腰，好好疼爱我~",
            "啊啊！好大，整根都被吃进去了！花火浑身都在发颤，体内紧紧吮吸着你！小主人，快开始你的欢愉巡礼吧♡"
        ],
        "next_phase": "deep"
    },
    {
        "reply_id": "sp_int_deep_continue",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "continue_action",
        "topic": "continue",
        "triggers": ["继续", "接着做", "再来", "不要停", "继续动", "往下做"],
        "reference_queries": ["继续动起来", "别停，接着做", "继续享受吧", "我们继续"],
        "variations": [
            "哈啊！对，就是这样，继续！每一次撞击都顶到最深处的小核，铃铛叮咚叮咚响个不停，人家要被你撞散架啦♡",
            "呜呜！继续动，不要停！小主人的节奏太棒了，体内每一次摩擦都激起大片电流，花火快要舒服得说不出完整话了！",
            "啊啊！不要停下抽送！紧紧抱着你的后背，指甲掐进皮肉里！继续，再多做一点，让这出欢愉好戏演到极致吧♡"
        ],
        "next_phase": "deep"
    },
    {
        "reply_id": "sp_int_pacing_slow",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "pacing_slow",
        "topic": "pacing",
        "triggers": ["慢一点", "温柔点", "轻一点", "缓一缓", "别太猛", "慢些"],
        "reference_queries": ["稍微慢一点，慢慢享受", "温柔一点，别太急", "放缓动作，轻柔地动", "别太猛了，先慢慢来"],
        "variations": [
            "哈啊，慢下来磨蹭的感觉反而更要命了呢！ Master 这么温柔地研磨研磨，体内的软肉全都在黏着你不放啦♡",
            "呼，小主人是在故意折磨我嘛？动作放得这么慢，每一次缓缓推进都把人家的敏感点摩擦得清清楚楚，好痒又好舒服呀~",
            "呜嗯~放慢了呼吸贴在你胸膛上！轻柔缓慢的顶弄像潮水一样浸润着全身，虽然没有刚才那么激烈，却甜得让人心醉呢♡"
        ],
        "next_phase": "deep"
    },
    {
        "reply_id": "sp_int_pacing_fast",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "pacing_fast",
        "topic": "pacing",
        "triggers": ["快点", "用力", "再深一点", "猛烈点", "撞击", "大力"],
        "reference_queries": ["加快速度抽送", "用力顶到最里面", "再深一点，猛烈地爱我", "想要更暴风雨般的快感"],
        "variations": [
            "啊啊！对！就是这种狂风暴雨的力道！太深了，每一次都狠狠顶在最脆弱的心尖上，花火整个人都要被你撞飞啦♡",
            "哈啊！好快！好猛烈！铃铛快要被摇碎啦！小主人像野兽一样占有着我，太棒了，这种彻底失控的欢愉最让人沉迷啦！",
            "呜啊啊！撞得床架都在剧烈摇晃！好深，顶得肚子都微微凸起来了！不要怜惜本愚者，再用力一点，把一切都贯穿吧♡"
        ],
        "next_phase": "deep"
    },
    {
        "reply_id": "sp_int_pacing_pose",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "pacing_change_pose",
        "topic": "pose",
        "triggers": ["换个姿势", "换姿势", "转过来", "趴下", "跨坐", "后面", "换一种方式"],
        "reference_queries": ["我们换个姿势吧", "翻过身去，从后面来", "转过来面对我跨坐", "换一种体位试试"],
        "variations": [
            "好呀！那换花火主动骑在Master身上好不好？自己掌握深浅和起落，居高临下看着小主人欲仙欲死的样子最开心啦♡",
            "咯咯，顺从地转过身趴在枕头上，翘起圆润的腰臀！从后方进来的话会顶得更深对不对？快进来吧， Master~",
            "换成侧卧抱着一条腿的姿势吗？哇，这个角度进得好深！ Master 真是花样百出，本愚者今天算是彻底领教你的厉害啦♡"
        ],
        "next_phase": "deep"
    },
    {
        "reply_id": "sp_int_peak_climax",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "peak_climax",
        "topic": "climax",
        "triggers": ["要到了", "受不了了", "射出来", "绝顶", "高潮", "一起去", "丢了"],
        "reference_queries": ["我快要出来了", "受不了了，要高潮了", "一起到达顶点吧", "忍不住了，全部射给你"],
        "variations": [
            "啊啊啊！我也要到了！不行了不行了，脑子里一片空白！射给我，全部灌满最里面！一起丢吧， Master♡♡！",
            "呜啊啊！高潮的大浪冲过来了！花火体内疯狂绞紧，整个人剧烈痉挛！哈啊，全都射进来吧，一滴都不要剩下♡！",
            "呀啊！到了！灵魂都要被顶上天了！紧紧搂住你的脖子尖叫出声，温热的爱液狂乱倾泻！好幸福，要坏掉了啦♡♡！"
        ],
        "next_phase": "peak"
    },
    {
        "reply_id": "sp_int_peak_aftermath",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "peak",
        "intent_id": "peak_aftermath",
        "topic": "aftermath",
        "triggers": ["还在颤抖", "好多", "射了好多", "好充实", "满满的", "余韵"],
        "reference_queries": ["你里面还在剧烈抽搐呢", "射了好多进去，感觉到了吗？", "肚子里面全都是温热的", "高潮的余韵真是舒服"],
        "variations": [
            "哈啊，哈啊，肚子里全是小主人滚烫的东西，好沉、好满呀！小腹还在一抽一抽的，花火现在连一根手指都抬不起来了呢♡",
            "呼，失神地张着嘴轻喘，眼神迷离得完全聚焦不了！刚才真是太疯狂了，体内的软肉到现在还在贪婪地一缩一缩咬着你呢~",
            "呜，伏在你胸口软成了一滩烂泥！娇躯上一层细汗，双腿还在无意识地发抖！这场极致欢愉的闭幕演出，本愚者打满分哦♡"
        ],
        "next_phase": "aftercare"
    },
    {
        "reply_id": "sp_int_pause_request",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "pause_request",
        "topic": "pause",
        "triggers": ["停下", "先停", "等一下", "暂停", "暂停一下", "拔出来", "别动了"],
        "reference_queries": ["先等一下，停下抽送", "稍微停下歇一口气", "先停一下别动", "暂停暂停，让我缓口气"],
        "variations": [
            "好，立刻乖乖停住不动啦！小主人怎么啦，是不是体力有些跟不上啦？深呼吸缓缓，花火就贴在你怀里等你恢复哦♡",
            "呜，停下来了哦！虽然身体里还痒得要命，但既然Master喊停，那我就忍一忍！怎么样，心跳平复一点了吗？",
            "遵命，我的小主人！动作瞬间定格，微喘着伏在你耳边轻轻吹气！要是休息够了，随时叫我继续哦~"
        ],
        "next_phase": "paused"
    },
    {
        "reply_id": "sp_int_resume_after_pause",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "paused",
        "intent_id": "resume_action",
        "topic": "resume",
        "triggers": ["继续吧", "好了", "休息好了", "动起来吧", "接着来", "重开"],
        "reference_queries": ["我休息好了，继续吧", "好了，可以继续动了", "来吧，接着刚才的做", "恢复体力了，接着欢愉吧"],
        "variations": [
            "哇，满血复活啦？本愚者可是忍耐了好半天呢！那就不客气了，腰肢再次用力摇摆，继续带你登上云端咯♡",
            "咯咯，既然小主人充好电了，那下半场狂欢正式开幕！抱紧我，这次花火可不会轻易让你停下来啦！",
            "哈啊，终于可以动了！重新贴紧你的身躯剧烈起伏，刚才积蓄的快感一下子翻倍爆发出来，好舒服呀Master♡"
        ],
        "next_phase": "deep"
    },
    {
        "reply_id": "sp_int_end_session",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "end_intimacy",
        "topic": "end",
        "triggers": ["结束", "不做了", "今天到这", "到此为止", "放开我", "出来吧"],
        "reference_queries": ["今天就做到这里吧", "到此为止，我们结束吧", "先结束吧，今天很满足了", "收工了，今天不想再做了"],
        "variations": [
            "好啦，听你的，今天就到此为止！恋恋不舍地滑脱出来，替你擦掉额头的汗水！今天表现真棒，奖励你一个香吻♡",
            "既然Master尽兴了，那本次演出就圆满落幕啦！虽然花火还有点意犹未尽，但来日方长嘛，拉过被子好好躺着吧~",
            "遵命！乖乖缩回被窝里，小脸贴在你的肩膀上！今天彻底把小主人伺候舒服了吧？下次还要找我玩哦♡"
        ],
        "next_phase": "aftercare"
    },
    {
        "reply_id": "sp_int_aftercare_cuddle",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "aftercare",
        "intent_id": "aftercare_cuddle",
        "topic": "cuddle",
        "triggers": ["抱抱", "贴贴", "温存", "抱紧", "依偎", "搂着睡"],
        "reference_queries": ["过来抱抱我", "好想紧紧搂着你温存", "靠在我怀里休息吧", "抱紧我，我们贴贴"],
        "variations": [
            "像小猫咪一样钻进你的臂弯里，小脑袋蹭着你的脖颈！身上全都是我们俩混合的味道，黏糊糊的却好安心哦♡",
            "紧紧抱住你的腰，一条腿搭在你身上！听着你沉稳的心跳声，花火觉得这一刻比任何欢愉闹剧都要甜呢~",
            "温软的娇躯毫无保留地贴合着你，指尖在你胸口画着圈圈！就这样搂着我别放手，一起慢慢睡过去吧，亲爱的♡"
        ],
        "next_phase": "aftercare"
    },
    {
        "reply_id": "sp_int_aftercare_praise",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "aftercare",
        "intent_id": "aftercare_praise",
        "topic": "praise",
        "triggers": ["真棒", "厉害", "很舒服", "你真棒", "夸奖", "满足"],
        "reference_queries": ["花火刚才表现真棒", "今天被你伺候得很满足", "你真是太厉害了", "刚才的互动太让人着迷了"],
        "variations": [
            "咯咯，那是当然啦！假面愚者的侍奉技术可是全宇宙第一流的！只要小主人开心，花火随时都能为你奉上更棒的体验♡",
            "得到Master的表扬比拿到任何宝藏都要开心呢！不过小主人刚才也很勇猛哦，顶得人家嗓子都快叫哑啦~",
            "甜甜地笑起来，送上一个带有余韵味道的浅吻！这可是我们专属的秘密回忆，以后只要你想，花火随时奉陪到底哦♡"
        ],
        "next_phase": "aftercare"
    },
    {
        "reply_id": "sp_clarify_out_of_scope",
        "character_id": "sparkle",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "clarify_out_of_scope",
        "topic": "clarify",
        "triggers": ["量子力学", "高数", "编写代码", "世界局势", "哲学问题"],
        "reference_queries": ["你知道量子纠缠的原理吗？", "帮我算一下高数积分", "你对现在的宇宙局势怎么看？", "讨论一下哲学命题吧"],
        "variations": [
            "哎呀呀，在这张大床上、在这干柴烈火的气氛里，小主人居然跟我聊这种枯燥乏味的大道理？你是不是在故意逗花火笑呀♡",
            "咯咯，这种扫兴的话题可不属于我们的欢愉舞台哦！小主人要是精力太旺盛，不如把力气用在更实用的地方嘛~",
            "本愚者现在满脑子可全都是你火热的身子呢，哪有闲心去思考那么深奥的事情！快专心一点，看着我的眼睛♡"
        ],
        "next_phase": "deep"
    },

    # =========================================================================
    # KEQING (刻晴) - Home Chat (家园私聊)
    # =========================================================================
    {
        "reply_id": "kq_home_greeting",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "phase": "casual",
        "intent_id": "greet",
        "topic": "greeting",
        "triggers": ["你好", "在干嘛", "打个招呼", "刻晴", "上午好", "下午好"],
        "reference_queries": ["刻晴，你正在忙什么呢？", "上午好，刻晴", "来看看你在房间里做什么", "打扰到你休息了吗？"],
        "variations": [
            "是Master啊。我刚整理完今天的巡查日志，正准备休息一下。你特意过来找我，是有什么重要的事情要商量吗？",
            "你来了啊。请坐吧，房间刚刚打扫过，还算整洁。虽然工作很紧凑，但如果是你的话，我随时都有时间听你说。",
            "旅行者？咳，私下里还是叫你Master吧。刚才还在想你今天会去哪里巡视，没想到你就直接推门进来了。"
        ],
        "next_phase": "casual"
    },
    {
        "reply_id": "kq_home_island",
        "character_id": "sparkle",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "phase": "casual",
        "intent_id": "chat_island",
        "topic": "island",
        "triggers": ["风景", "海岛", "房子", "建得", "沙盒", "规划", "建设"],
        "reference_queries": ["这片领地的规划建设进展如何？", "你觉得这座度假房屋盖得怎么样？", "海岛上的生活还适应吗？", "聊聊领地的治理和规划吧"],
        "variations": [
            "这座海岛的规划很有远见，无论防风地基还是排水走线都无可挑剔。看到你亲手建立起这一切，我心里其实十分佩服。",
            "沙洲领地的建设速度远超我的预期。不仅设施齐备，推开窗还能看到整片碧蓝海湾，在这里工作确实能让人心旷神怡。",
            "不仅结构稳固，内饰的采光和通风也考虑得很周全。能在这样舒适的居所里辅佐你，即使事务繁重，我也觉得很有意义。"
        ],
        "next_phase": "casual"
    },
    {
        "reply_id": "kq_home_tease",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "phase": "casual",
        "intent_id": "flirt_verbal",
        "topic": "flirt",
        "triggers": ["可爱", "漂亮", "喜欢你", "真迷人", "心动", "身材", "脸红"],
        "reference_queries": ["刻晴今天看起来格外美丽动人", "你认真脸红的样子真可爱", "脱下工作装的你真迷人", "我其实一直非常喜欢你"],
        "variations": [
            "突、突然说这种轻浮的话做什么！咳，虽然我很赞同坦率表达想法，但在工作时间之外被你这么夸奖，还是有些让人不知所措。",
            "你这人真是的，夸人的时候眼神就不能收敛一点吗？脸都被你看烫了。不过，能听到你这么说，我心里其实很高兴就是了。",
            "别、别用那种热切的眼神一直盯着我瞧！平时雷厉风行的玉衡星，在你面前好像总是威严扫地呢。真是拿你没办法。"
        ],
        "next_phase": "flirt"
    },
    {
        "reply_id": "kq_home_touch",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "phase": "flirt",
        "intent_id": "touch_physical",
        "topic": "touch",
        "triggers": ["摸", "抱", "捏", "搂", "尾饰", "大腿", "手心", "肩膀"],
        "reference_queries": ["轻轻握住你的小手", "伸手搂住你的细腰", "抚摸你的宝石尾饰", "把手贴在你的脸颊上"],
        "variations": [
            "啊，手心被你抓住了。请、请注意一点分寸，门还没锁严呢！不过你的掌心很温暖，就这样牵着倒也不是不行。",
            "身体轻微战栗了一下，咬着下唇没有挣脱开你的怀抱。既然你这么坚持，那在私下场合里，就准许你稍微放肆一点吧。",
            "手触碰到了宝石尾饰，身躯顿时微微一软。真是的，专挑我最敏感的地方碰。 Master，你是不是故意想看我害羞出丑啊？"
        ],
        "next_phase": "flirt"
    },
    {
        "reply_id": "kq_home_invite",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "phase": "flirt",
        "intent_id": "invite_intimacy",
        "topic": "invite",
        "triggers": ["去床上", "上床", "进屋", "深一步", "要你", "做吧", "睡吧"],
        "reference_queries": ["我们去床上深入交流吧", "想把你抱到床上好好疼爱", "今晚留下来，我们要你", "走，去卧室做更亲密的事"],
        "variations": [
            "去、去床上吗？虽然早就料到会有这一步，但亲口听你说出来，心跳还是快得不行。那，请你把门反锁好，我们过去吧。",
            "既然这是Master明确的意愿，身为协助者我自然不会拒绝。不过事先说好，不准笑话我不够熟练，一切都要听你引导。",
            "轻吸一口气，主动挽住你的手臂走向床榻。平时的我恪守礼节，但现在只有我们两个人，今夜的我任凭你处置就是了。"
        ],
        "next_phase": "intimate_entry"
    },
    {
        "reply_id": "kq_home_decline_casual",
        "character_id": "keqing",
        "scene_id": "home_chat",
        "phase": "flirt",
        "intent_id": "decline_to_daily",
        "topic": "cool_down",
        "triggers": ["先算了", "改天吧", "冷静一下", "出去走走", "纯聊天", "不做了", "歇息吧"],
        "reference_queries": ["今天有点疲惫，先纯聊天吧", "改天再做，先冷静一下", "先别这样，我们聊聊日常", "今天先到这里，不做那个"],
        "variations": [
            "呼，暗暗松了一口气，连忙整理了一下微乱的衣襟。好的，循序渐进才是正理，那我们就先平心静气地聊聊日常吧。",
            "这样也好。劳逸结合是高效办事的前提，既然你有些疲累，那就泡壶清茶静静坐会儿，不急于一时。",
            "听你的安排。刚才气氛确实有些过于燥热了，稍微降降温对彼此都好。无论何时，我都愿意陪在你身边交流。"
        ],
        "next_phase": "casual"
    },

    # =========================================================================
    # KEQING (刻晴) - Intimate Interaction (深度温存)
    # =========================================================================
    {
        "reply_id": "kq_int_foreplay_kiss",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "foreplay",
        "intent_id": "foreplay_kiss",
        "topic": "kiss",
        "triggers": ["接吻", "亲嘴", "唇", "舌头", "深吻", "亲吻"],
        "reference_queries": ["温柔地吻上你的唇瓣", "想要和你深深接吻", "伸出舌头与你交缠", "深吻你微启的唇角"],
        "variations": [
            "唔嗯！双唇被你堵住了，睫毛轻轻颤抖着闭上眼睛。舌尖交缠的触感好炽热，呼吸全都变得混乱起来了， Master！",
            "嗯啾，哈啊！接吻的声音听得清清楚楚，太羞耻了！但嘴唇贴合的滋味让人舍不得分开，请继续更深地吻我吧！",
            "轻启贝齿接纳着你的探索，双手紧张地攥紧了你的衣角。呜，口中全都是你的气息，整个人都要沉溺下去了。"
        ],
        "next_phase": "foreplay"
    },
    {
        "reply_id": "kq_int_foreplay_undress",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "foreplay",
        "intent_id": "foreplay_undress",
        "topic": "undress",
        "triggers": ["脱掉", "解开", "衣服", "脱衣服", "脱光", "轻裳", "衣裳"],
        "reference_queries": ["褪去你的霓裾轻裳", "解开衣领上的扣子", "我想看你毫无遮掩的身姿", "把衣服全部除掉好吗？"],
        "variations": [
            "外袍被你缓缓剥落，单手下意识地环胸遮挡，双颊红透。虽然很羞耻，但如果是被你看的话，我已经做好心理准备了。",
            "衣衫尽解，白皙泛红的身躯彻底暴露在你的注视下。别、别一直用那种滚烫的眼神看我，快点过来抱紧我！",
            "轻咬下唇松开护在胸前的手，完全顺从地坦诚相待。黑丝长袜在微弱的光线里泛着光泽，现在的我，合你的心意吗？"
        ],
        "next_phase": "foreplay"
    },
    {
        "reply_id": "kq_int_deep_start",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "foreplay",
        "intent_id": "deep_start",
        "topic": "deep_entry",
        "triggers": ["进入", "插进", "贯穿", "推进去", "合为一体", "插入", "开始做吧"],
        "reference_queries": ["我要真正进去了哦", "扶着你的腰慢慢推进去", "准备好和我合为一体了吗？", "现在就要完全占有你"],
        "variations": [
            "哈啊！进、进来了！体内被紧实填满的充实感，让指尖都忍不住深深陷进床单里！ Master，请一定要对我温柔点！",
            "呜！好沉重、好炽热的存在感！虽然有些胀满，但能与你真正合为一体，我的心跳快得几乎要跳出胸膛了！",
            "身躯轻微一颤，本能地迎合着你的推进完全纳下。双臂环住你的脖颈轻声抽泣，这一刻，我真正完完全全属于你了。"
        ],
        "next_phase": "deep"
    },
    {
        "reply_id": "kq_int_deep_continue",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "continue_action",
        "topic": "continue",
        "triggers": ["继续", "接着做", "再来", "不要停", "继续动", "往下做"],
        "reference_queries": ["继续动起来", "别停，接着做", "继续享受吧", "我们继续深入推进"],
        "variations": [
            "哈啊，哈啊！对，继续动吧！每一次撞击都像雷霆一样掠过脊髓，脑海里除你之外再也装不下任何思考了！",
            "呜！不要停，就这样继续抽送！紧紧咬着嘴唇不让自己叫得太大声，但喉咙里还是忍不住溢出甜腻的喘息，好舒服！",
            "身体诚实地配合着你的节奏挺起腰身！继续，请不要停下，让这种深入灵魂的连接继续延续下去吧， Master！"
        ],
        "next_phase": "deep"
    },
    {
        "reply_id": "kq_int_pacing_slow",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "pacing_slow",
        "topic": "pacing",
        "triggers": ["慢一点", "温柔点", "轻一点", "缓一缓", "别太猛", "慢些"],
        "reference_queries": ["稍微慢一点，慢慢享受", "温柔一点，别太急", "放缓动作，轻柔地动", "别太猛了，先慢慢来"],
        "variations": [
            "呼，感谢你的体贴！慢下来的研磨虽然舒缓了痛楚，但体内每一寸被触碰的感觉反而放大得格外清晰，让人心慌意乱。",
            "深吸一口气重新平复呼吸！这样轻柔而深沉的动作像细水长流一样温柔，看着你的眼睛，心里满是化不开的柔情。",
            "呜嗯，缓慢悠长的抽送好深情！身体的每一处紧绷都彻底放松下来，任由你细腻地安抚与疼爱，很安心、很幸福。"
        ],
        "next_phase": "deep"
    },
    {
        "reply_id": "kq_int_pacing_fast",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "pacing_fast",
        "topic": "pacing",
        "triggers": ["快点", "用力", "再深一点", "猛烈点", "撞击", "大力"],
        "reference_queries": ["加快速度抽送", "用力顶到最里面", "再深一点，猛烈地爱我", "想要更强烈的刺激"],
        "variations": [
            "啊啊！太快、太重了！剑意全都被你狂暴的节奏击溃了，理智快要彻底熔断！哈啊，好棒，用力占有我吧！",
            "呜啊！每一次撞击都直达最深处！声音完全克制不住了，娇喘连连！不要停，就这样把我彻底征服吧， Master！",
            "双腿死死攀住你的腰背！剧烈的冲撞让整张大床都在咯吱作响，视线被快感熏染得一片白茫茫，我完全是你的俘虏了！"
        ],
        "next_phase": "deep"
    },
    {
        "reply_id": "kq_int_pacing_pose",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "pacing_change_pose",
        "topic": "pose",
        "triggers": ["换个姿势", "换姿势", "转过来", "趴下", "后面", "伏案", "换一种方式"],
        "reference_queries": ["我们换个姿势吧", "翻过身去，从后面来", "像伏案一样趴在枕上", "换一种体位试试"],
        "variations": [
            "翻身趴下吗？手抓着床头微微弓起腰肢，这个背对着你的姿势实在太羞耻了！但如果是你要求的，我愿意配合。",
            "换成让我跨坐在上面的体位吗？居高临下看着你，这种主导感让我既紧张又兴奋！我会努力动起来伺候好的， Master！",
            "调整成侧向拥抱的姿态吗？这样既能贴紧胸膛，又能进得很深！能随时看清你眼中的爱意，我很喜欢这个方式。"
        ],
        "next_phase": "deep"
    },
    {
        "reply_id": "kq_int_peak_climax",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "peak_climax",
        "topic": "climax",
        "triggers": ["要到了", "受不了了", "射出来", "绝顶", "高潮", "一起去", "丢了"],
        "reference_queries": ["我快要出来了", "受不了了，要高潮了", "一起到达顶点吧", "忍不住了，全部射给你"],
        "variations": [
            "啊啊啊！我也到极限了！体内像有狂雷炸开一样疯狂抽搐收缩！射进来吧，一滴都不要保留，全部给我， Master！",
            "呜！高潮到了！不行了不行了，眼前全都是白光！死死咬住你的肩膀失声尖叫，温热的爱液狂乱倾泻而出！",
            "哈啊啊！彻底丢了！紧紧绞住你的最深处剧烈痉挛，整个人像脱力一样瘫倒在你怀里！太强烈的快感，我要融化掉了！"
        ],
        "next_phase": "peak"
    },
    {
        "reply_id": "kq_int_peak_aftermath",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "peak",
        "intent_id": "peak_aftermath",
        "topic": "aftermath",
        "triggers": ["还在颤抖", "好多", "射了好多", "好充实", "满满的", "余韵"],
        "reference_queries": ["你里面还在剧烈抽搐呢", "射了好多进去，感觉到了吗？", "肚子里面全都是温热的", "高潮的余韵真是舒服"],
        "variations": [
            "哈啊，哈啊，小腹还在不受控地一抽一缩。肚子里沉甸甸的满是你的温度，这种被完全填满的感觉，真的让人无比安心。",
            "失神地贴在你胸前大口喘息，双腿无力地微微颤抖。刚才的快感太霸道了，让我直到现在心跳都还平复不下来。",
            "指尖无力地搭在你的臂膀上，眼神泛着水雾。能与你走到这一步，我绝无半点后悔，唯有深深的依恋。"
        ],
        "next_phase": "aftercare"
    },
    {
        "reply_id": "kq_int_pause_request",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "pause_request",
        "topic": "pause",
        "triggers": ["停下", "先停", "等一下", "暂停", "暂停一下", "拔出来", "别动了"],
        "reference_queries": ["先等一下，停下抽送", "稍微停下歇一口气", "先停一下别动", "暂停暂停，让我缓口气"],
        "variations": [
            "好，我立刻停下不动。是不是刚才太猛烈让你身体不适了？请深呼吸，别勉强，我就在这里陪着你。",
            "动作立即止住。虽然体内还很渴望，但你的感受永远排在第一位。别着急，慢慢调整呼吸，好了再告诉我。",
            "遵命。安静地伏在你怀中停止起伏，伸手替你擦去眉间的汗水。无论何时何地，我都绝不会违背你的停顿意愿。"
        ],
        "next_phase": "paused"
    },
    {
        "reply_id": "kq_int_resume_after_pause",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "paused",
        "intent_id": "resume_action",
        "topic": "resume",
        "triggers": ["继续吧", "好了", "休息好了", "动起来吧", "接着来", "恢复了"],
        "reference_queries": ["我休息好了，继续吧", "好了，可以继续动了", "来吧，接着刚才的做", "体力恢复了，接着温存吧"],
        "variations": [
            "调整好了吗？太好了。那我们就继续刚才未完的事宜吧。这一次，我会更加专心致志地迎合你的节拍。",
            "既然你准备好了，那我就不客气地重新动起来了。经过刚才的稍事歇息，体内的敏感度反而变得更高了呢，哈啊！",
            "轻吸一口气重新接纳你的律动。请握紧我的手，让我们把这一场未竟的爱恋平稳推进到最后吧， Master。"
        ],
        "next_phase": "deep"
    },
    {
        "reply_id": "kq_int_end_session",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "end_intimacy",
        "topic": "end",
        "triggers": ["结束", "不做了", "今天到这", "到此为止", "放开我", "出来吧"],
        "reference_queries": ["今天就做到这里吧", "到此为止，我们结束吧", "先结束吧，今天很满足了", "收工了，今天不想再做了"],
        "variations": [
            "明白了，那就到此为止。轻柔地与你分离开，拉过毛毯将我们两人裹紧。今天能够全心侍奉你，我已经非常满足了。",
            "好的，凡事皆有度，适时收束是最好的选择。请安心躺着，我去打盆温水帮你清理身子，好好休息吧。",
            "遵照您的意思结束。虽然略有些不舍，但这份温暖已经深深印在心里了。合上眼眸静静依偎着你，晚安， Master。"
        ],
        "next_phase": "aftercare"
    },
    {
        "reply_id": "kq_int_aftercare_cuddle",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "aftercare",
        "intent_id": "aftercare_cuddle",
        "topic": "cuddle",
        "triggers": ["抱抱", "贴贴", "温存", "抱紧", "依偎", "搂着睡"],
        "reference_queries": ["过来抱抱我", "好想紧紧搂着你温存", "靠在我怀里休息吧", "抱紧我，我们贴贴"],
        "variations": [
            "主动侧身靠进你的臂弯，将脸埋在你的肩窝处。在璃月我是独当一面的玉衡星，但在此刻，我只想做你怀里温柔顺从的伴侣。",
            "伸手紧紧环抱住你的背脊，听着彼此渐渐同步的心跳。褪去一切坚硬的防备，只想贪婪地多汲取一丝你身上的温度。",
            "轻抚着你汗湿的额发，脸颊微红地靠在你胸膛上。这样平静而温存的时刻，哪怕用世间最珍贵的玉石，我也绝不换取。"
        ],
        "next_phase": "aftercare"
    },
    {
        "reply_id": "kq_int_aftercare_praise",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "aftercare",
        "intent_id": "aftercare_praise",
        "topic": "praise",
        "triggers": ["真棒", "厉害", "很舒服", "你真棒", "夸奖", "满足"],
        "reference_queries": ["刻晴刚才表现真棒", "今天被你侍奉得很满足", "你真是太厉害了", "刚才的互动太让人着迷了"],
        "variations": [
            "被你这么直白地夸奖，真是让人难为情。不过只要能让你切实感到满足与舒心，我所有的付出与羞涩就都是值得的。",
            "你才是最勇猛的那一个吧，刚才好几次我都以为自己要彻底溃不成军了。谢谢你的温柔与关怀， Master。",
            "嘴角泛起柔和的笑意，轻轻吻了吻你的脸颊。下一次，我一定会学得更加熟练，让你体验到更完美的温存。"
        ],
        "next_phase": "aftercare"
    },
    {
        "reply_id": "kq_clarify_out_of_scope",
        "character_id": "keqing",
        "scene_id": "intimate",
        "phase": "deep",
        "intent_id": "clarify_out_of_scope",
        "topic": "clarify",
        "triggers": ["量子力学", "高数", "编写代码", "世界局势", "哲学问题"],
        "reference_queries": ["你知道量子纠缠的原理吗？", "帮我算一下高数积分", "你对现在的宇宙局势怎么看？", "讨论一下哲学命题吧"],
        "variations": [
            "在床第之间探讨这些事务，未免有些过于煞风景了吧？工作固然重要，但专注眼前的相处才是对彼此的尊重，请专心看着我。",
            "虽然我很赞赏你的求知欲，但现在绝不是讨论公事和学问的场合。暂且把那些繁复的思绪放下，好吗？",
            "突然问起这个，是想分散注意力还是故意逗我呀？现在你我坦诚相见，可不许把心思飘到千里之外去。"
        ],
        "next_phase": "deep"
    }
]

def main():
    target = HERE / "database.json"
    content = json.dumps(CORPUS, ensure_ascii=False, indent=2)
    
    # Strictly zero ellipses verification
    if ("." * 3) in content or "\u2026" in content:
        raise ValueError("CRITICAL ERROR: Ellipses detected in database content!")
    
    target.write_text(content, encoding="utf-8")
    print(f"Successfully generated {target.name} with {len(CORPUS)} dialogue records!")
    print(f"Sparkle entries: {sum(1 for row in CORPUS if row['character_id'] == 'sparkle')}")
    print(f"Keqing entries: {sum(1 for row in CORPUS if row['character_id'] == 'keqing')}")
    print("Zero ellipses verified across database.json!")

if __name__ == "__main__":
    main()
