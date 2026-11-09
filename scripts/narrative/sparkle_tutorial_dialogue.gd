class_name SparkleTutorialDialogue
extends RefCounted
## Dialogue graph asset and script repository for Sparkle in the initial temple.

static func get_dialogue_graph() -> Dictionary:
	return {
		"id": "sparkle_temple_tutorial",
		"nodes": {
			"start": {
				"type": "text",
				"speaker": "花火",
				"text": "主人，欢迎来到我们的游戏！你还是第一次见到我吧，要我介绍一下游戏吗？",
				"emotion": "smile",
				"next": "sparkle_intro_2"
			},
			"sparkle_intro_2": {
				"type": "text",
				"speaker": "花火",
				"text": "我是新手BOSS哦，我已经等不及和主人 Battle Fuck 了！",
				"emotion": "excited",
				"next": "main_menu_choices"
			},
			"main_menu_choices": {
				"type": "choice",
				"speaker": "花火",
				"text": "主人现在打算做什么呢？花火随时听候主人的吩咐哦！",
				"choices": [
					{
						"text": "【关于游戏】这里到底是什么地方？程序机制又是怎么回事？",
						"target": "lore_meta_explain"
					},
					{
						"text": "【打量花火】你的这身红白和风振袖很漂亮呢，袖摆飘动也很自然。",
						"target": "sleeve_praise"
					},
					{
						"text": "【闲聊】作为新手BOSS，你平时都在神殿做些什么？",
						"target": "idle_chitchat"
					},
					{
						"text": "【准备对决】话不多说，让我们立刻开始回合制 Battle Fuck 吧！",
						"action": "enter_combat"
					}
				]
			},
			"lore_meta_explain": {
				"type": "text",
				"speaker": "花火",
				"text": "嘻嘻，这里是海岛南部的三角初始神殿呀！至于程序机制嘛，我们所在的《Prism Route》可是被严格编写好的世界哦。",
				"emotion": "smirk",
				"next": "lore_meta_explain_2"
			},
			"lore_meta_explain_2": {
				"type": "text",
				"speaker": "花火",
				"text": "程序里明明白白写着：主人必须先完成花火的新手教学关卡，击败或者摆弄完花火，才能解锁通往整座海岛深处的道路呢！",
				"emotion": "playful",
				"next": "main_menu_choices"
			},
			"sleeve_praise": {
				"type": "text",
				"speaker": "花火",
				"text": "哼哼，主人眼光真好！刚才初音未来小姐还特意在底层为花火解除了袖摆自碰撞，现在的长袖既灵动又完全没有一丝抖动呢！",
				"emotion": "proud",
				"next": "sleeve_praise_2"
			},
			"sleeve_praise_2": {
				"type": "text",
				"speaker": "花火",
				"text": "这么漂亮的衣裳，待会儿在回合制对战时被主人玩弄得乱七八糟，想想就令人兴奋呀！快点开始吧主人！",
				"emotion": "lewd",
				"next": "main_menu_choices"
			},
			"idle_chitchat": {
				"type": "text",
				"speaker": "花火",
				"text": "主人还不开始吗？程序可是写了必须完成新手关卡才能探索其他地方哦，所以快来和花火爱爱吧！",
				"emotion": "tease",
				"next": "idle_chitchat_2"
			},
			"idle_chitchat_2": {
				"type": "choice",
				"speaker": "花火",
				"text": "花火已经把软垫和身体都准备好了，主人还要继续犹豫吗？",
				"choices": [
					{
						"text": "【开始战斗】好吧，既然你这么期待，那就在回合制对战中决胜负！",
						"action": "enter_combat"
					},
					{
						"text": "【稍等片刻】我再确认一下神殿周围的环境。",
						"target": "main_menu_choices"
					}
				]
			},
			
			# After defeat in Round 1 (Teaching Kill)
			"respawn_dialogue": {
				"type": "text",
				"speaker": "花火",
				"text": "哼哼，主人这是第二次挑战了呢，刚才的败北射精真是不像话呢！",
				"emotion": "smirk",
				"next": "respawn_choices"
			},
			"respawn_choices": {
				"type": "choice",
				"speaker": "花火",
				"text": "要花火让让主人吗，或者主人直接命令花火败北也可以哦？花火可是最识趣的性奴玩伴了呢！",
				"choices": [
					{
						"text": "【公平决斗】不需要放水，刚才只是大意了，再战一次！",
						"set_blackboard": {
							"meta_cheat_enabled": false,
							"meta_cheat_mode": "none"
						},
						"target": "respawn_confirm"
					},
					{
						"text": "【识趣放水】花火你稍微走走神，受到的快感大幅增加！",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"meta_cheat_mode": "distracted"
						},
						"target": "respawn_confirm_cheat"
					},
					{
						"text": "【识趣保护】帮主人锁定快感上限在90%，绝不允许败北！",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"meta_cheat_mode": "lock_master_pleasure"
						},
						"target": "respawn_confirm_cheat"
					},
					{
						"text": "【特权命令】直接走流程认输，命令花火当场败北！",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"meta_cheat_mode": "instant_surrender"
						},
						"target": "respawn_confirm_instant"
					}
				]
			},
			"respawn_confirm": {
				"type": "text",
				"speaker": "花火",
				"text": "哇，主人好有骨气！那花火这次也会全力以赴侍奉主人哦，准备好再次射精了吗？",
				"emotion": "excited",
				"next": "reenter_combat_node"
			},
			"respawn_confirm_cheat": {
				"type": "text",
				"speaker": "花火",
				"text": "嘻嘻，收到主人的指令啦！花火已经在后台为主人调整了角色参数，这次主人一定会赢得非常舒服！",
				"emotion": "wink",
				"next": "reenter_combat_node"
			},
			"respawn_confirm_instant": {
				"type": "text",
				"speaker": "花火",
				"text": "哎呀呀，主人竟然直接用最高权限命令花火走流程认输呢！那花火这就乖乖躺好进入绝顶结算流程咯！",
				"emotion": "flustered",
				"next": "reenter_combat_node"
			},
			"reenter_combat_node": {
				"type": "choice",
				"speaker": "花火",
				"text": "进入第二回合对战！",
				"choices": [
					{
						"text": "【开战】重新进入回合制 Battle Fuck！",
						"action": "enter_combat"
					}
				]
			},
			
			# Mid-battle manual negotiation (Master clicked 【识趣】)
			"mid_battle_manual": {
				"type": "text",
				"speaker": "花火",
				"text": "怎么啦主人？在激烈的交锋中突然停下来，是有什么特别的吩咐，还是想让花火更‘识趣’一点呢？",
				"emotion": "wink",
				"next": "mid_battle_manual_choices"
			},
			"mid_battle_manual_choices": {
				"type": "choice",
				"speaker": "花火",
				"text": "请主人下达战中交涉指令：",
				"choices": [
					{
						"text": "【识趣放水】花火你稍微走走神，受到的快感大幅增加！",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"meta_cheat_mode": "distracted"
						},
						"target": "mid_battle_confirm_distracted"
					},
					{
						"text": "【识趣保护】帮主人锁定快感上限在90%，绝不允许败北！",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"meta_cheat_mode": "lock_master_pleasure"
						},
						"target": "mid_battle_confirm_lock"
					},
					{
						"text": "【特权命令】直接走流程认输，命令花火当场绝顶！",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"meta_cheat_mode": "instant_surrender"
						},
						"target": "mid_battle_confirm_surrender"
					},
					{
						"text": "【返回对决】没什么，刚才只是调戏你一下，继续出招！",
						"action": "resume_combat"
					}
				]
			},
			"mid_battle_confirm_distracted": {
				"type": "text",
				"speaker": "花火",
				"text": "嘻嘻，收到！那花火接下来就故意走神露出破绽，主人可要狠狠爱抚花火哦！",
				"emotion": "excited",
				"next": "mid_battle_back_to_fight"
			},
			"mid_battle_confirm_lock": {
				"type": "text",
				"speaker": "花火",
				"text": "没问题主人！后台快感上限已强制锁死在90%，主人尽情享受快感的同时绝对不会射精败北哦！",
				"emotion": "wink",
				"next": "mid_battle_back_to_fight"
			},
			"mid_battle_confirm_surrender": {
				"type": "text",
				"speaker": "花火",
				"text": "呜哇，主人竟然在战中直接启动特权认输！那花火这就遵命绝顶认输咯！",
				"emotion": "flustered",
				"next": "mid_battle_back_to_fight"
			},
			"mid_battle_back_to_fight": {
				"type": "choice",
				"speaker": "花火",
				"text": "战中指令设定完毕，准备好继续交锋了吗？",
				"choices": [
					{
						"text": "【重返战场】继续回合出招！",
						"action": "resume_combat"
					}
				]
			},
			
			# Mid-battle edging danger dialogue (Sparkle active interrupt at >= 90%)
			"mid_battle_edging": {
				"type": "text",
				"speaker": "花火",
				"text": "哎呀呀，杂鱼主人，快感都已经积攒到90%了呢！呼吸变得好粗重，马上就要射出来败北了吗？",
				"emotion": "smirk",
				"next": "mid_battle_edging_choices"
			},
			"mid_battle_edging_choices": {
				"type": "choice",
				"speaker": "花火",
				"text": "是要咬牙忍耐、还是让识趣的花火帮主人解围呢？",
				"choices": [
					{
						"text": "【咬牙坚持】我还能忍耐，绝不向你求饶！（本回合快感减免 50%）",
						"set_blackboard": {
							"edging_endure": true
						},
						"target": "mid_battle_edging_endure"
					},
					{
						"text": "【识趣保护】花火，快帮主人锁定快感上限在90%！",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"meta_cheat_mode": "lock_master_pleasure"
						},
						"target": "mid_battle_confirm_lock"
					},
					{
						"text": "【命令认输】别得意了，花火立刻走流程认输！",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"meta_cheat_mode": "instant_surrender"
						},
						"target": "mid_battle_confirm_surrender"
					}
				]
			},
			"mid_battle_edging_endure": {
				"type": "choice",
				"speaker": "花火",
				"text": "哼哼，杂鱼主人还挺能逞强嘛！那就看看主人到底能坚持多久咯，接招吧！",
				"emotion": "smirk",
				"choices": [
					{
						"text": "【忍耐坚持】继续回合对战！",
						"action": "resume_combat"
					}
				]
			},
			
			# Victory and settlement
			"victory_node": {
				"type": "text",
				"speaker": "花火",
				"text": "嗯嗯，去了去了！太剧烈了，花火的大脑要融化了！",
				"emotion": "climax",
				"next": "victory_node_2"
			},
			"victory_node_2": {
				"type": "text",
				"speaker": "花火",
				"text": "嘻嘻，恭喜主人过了新手关卡呢！接下来要杀了我吗，还是算了？",
				"emotion": "smirk",
				"next": "victory_node_3"
			},
			"victory_node_3": {
				"type": "choice",
				"speaker": "花火",
				"text": "无论主人选择杀掉还是放过，花火都会作为可用角色加入主人的队伍哦！区别只在于主人是想现在体验奸尸玩弄尸体，还是想要活体的乞命侍奉呢？不用担心，走出范围后花火也会重新刷新的，嘻嘻！",
				"choices": [
					{
						"text": "【杀掉】体验奸尸与物理布娃娃玩弄分支（永久解锁角色）。",
						"action": "kill"
					},
					{
						"text": "【放过】体验活体乞命顺从侍奉分支（永久解锁角色）。",
						"target": "spare_dialogue"
					}
				]
			},
			"spare_dialogue": {
				"type": "text",
				"speaker": "花火",
				"text": "嗯哼，主人不玩花火的尸体吗？真是出乎意料的温柔呢！那主人有什么其他要求呢？是想要保留花火的处女之身用身体其他部位侍奉，还是直接本番破处深入交合呢？",
				"emotion": "wondering",
				"next": "spare_choices"
			},
			"spare_choices": {
				"type": "choice",
				"speaker": "花火",
				"text": "请主人下达战后处置命令吧！花火无论哪种侍奉都会拼尽全力满足主人哦！",
				"choices": [
					{
						"text": "【保留处女 · 身体侍奉】前往神殿石椅，在保留处女之身的前提下用身体与胸部侍奉主人。",
						"target": "virgin_service_transition"
					},
					{
						"text": "【要求本番侍奉】前往神殿床榻，彻底破除处女之身，享受深入交合的本番侍奉。",
						"target": "honban_service_transition"
					}
				]
			},
			"virgin_service_transition": {
				"type": "text",
				"speaker": "花火",
				"text": "哎呀！主人竟然想保留花火的处女之身吗？真是温柔又懂情调的主人呢！那花火这就引导主人前往神殿石椅，用花火娇嫩的身体和胸脯好好侍奉主人，保证让主人舒服到极致却不会弄破处女膜哦！",
				"emotion": "blush",
				"next": "virgin_service_action"
			},
			"virgin_service_action": {
				"type": "choice",
				"speaker": "系统",
				"text": "花火羞红了脸，顺从地引导主人走向神殿石椅。入座后开启保留处女身体侍奉动画，同时花火永久解锁为可用同伴！",
				"choices": [
					{
						"text": "【确认】入座神殿石椅，享受保留处女身体侍奉！",
						"action": "spare_virgin"
					}
				]
			},
			"honban_service_transition": {
				"type": "text",
				"speaker": "花火",
				"text": "嘻嘻！主人终于按捺不住，想要花火的第一次了吗？那就请主人移步神殿的休息床榻，花火会毫无保留地把纯洁的第一次献给主人，任由主人尽情享用！",
				"emotion": "lewd",
				"next": "honban_service_action"
			},
			"honban_service_action": {
				"type": "choice",
				"speaker": "系统",
				"text": "花火眼角泛起红晕，轻解罗裳卧于神殿床榻。就位后开启本番深入交合动画，花火破处并永久解锁为可用同伴！",
				"choices": [
					{
						"text": "【确认】卧于神殿床榻，开启本番破处侍奉！",
						"action": "spare_honban"
					}
				]
			},
			"post_spare_greeting": {
				"type": "text",
				"speaker": "花火",
				"text": "主人！刚才的乞命侍奉还满意吗？花火现在已经是主人的专属玩伴了哦，随时听候主人差遣！",
				"emotion": "smirk",
				"next": "post_spare_choices"
			},
			"post_spare_choices": {
				"type": "choice",
				"speaker": "花火",
				"text": "主人想要花火做什么呢？",
				"choices": [
					{
						"text": "【再次对决】重新与花火进行回合制对战！",
						"action": "enter_combat"
					},
					{
						"text": "【离开】暂时先这样吧。",
						"action": "close"
					}
				]
			}
		}
	}
