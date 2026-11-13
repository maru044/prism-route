class_name SparkleTutorialDialogue
extends RefCounted
## Dialogue graph and in-combat Koujou database for Sparkle in the initial temple.
## Focuses on natural, ordinary spoken dialogue without purple prose or long narrator monologues.

static func get_dialogue_graph() -> Dictionary:
	return {
		"id": "sparkle_temple_tutorial",
		"nodes": {
			# =========================================================================
			# 第一幕：神殿初遇（普通日常对话）
			# =========================================================================
			"start": {
				"type": "text",
				"speaker": "花火",
				"text": "哟，新来的？欢迎到初始神殿来！（晃着双腿向你招手）我是花火，这儿的考官兼向导。看你东张西望的样子，是不是对这地方挺好奇的？",
				"emotion": "smile",
				"next": "sparkle_intro_2"
			},
			"sparkle_intro_2": {
				"type": "text",
				"speaker": "花火",
				"text": "别拘束嘛，随便坐。我是这里的守门人，你想了解些什么，或者有什么想问的，直接跟我说就行啦。",
				"emotion": "playful",
				"next": "main_menu_choices"
			},
			"main_menu_choices": {
				"type": "choice",
				"speaker": "花火",
				"text": "想先聊点什么呢？",
				"choices": [
					{
						"text": "【关于这里】这座岛到底是什么情况？那些白色的老建筑是干什么的？",
						"target": "lore_meta_explain"
					},
					{
						"text": "【关于花火】你一直一个人待在这座神殿里吗？平时都做些什么？",
						"target": "sleeve_praise"
					},
					{
						"text": "【关于规则】想通过这里去岛屿深处，需要达成什么条件？",
						"target": "idle_chitchat"
					},
					{
						"text": "【开始对决】规则我已经清楚了，直接开始对决吧！",
						"action": "enter_combat"
					}
				]
			},
			
			# 分支 1：普通生活化世界观介绍
			"lore_meta_explain": {
				"type": "text",
				"speaker": "花火",
				"text": "这里其实就是一座风景很不错的海岛啦。到处都是以前留下的老建筑和公路，不过现在空荡荡的，没什么人住，树和草长得挺好的。",
				"emotion": "smile",
				"next": "lore_meta_explain_2"
			},
			"lore_meta_explain_2": {
				"type": "text",
				"speaker": "花火",
				"text": "平时我们就在这儿开开房车、看看海、吹吹海风，生活其实挺清闲的。不过你想去岛屿深处转转的话，按这儿的规矩，得先陪我玩一场身心对决才行。",
				"emotion": "wink",
				"next": "lore_meta_explain_3"
			},
			"lore_meta_explain_3": {
				"type": "choice",
				"speaker": "花火",
				"text": "你要是赢了我，我就陪你一起去环岛，营地想建在哪儿我都给你打下手。怎么样，听起来不亏吧？",
				"choices": [
					{
						"text": "【挺好的】开房车看风景、建营地，听起来确实挺惬意。",
						"target": "lore_agree"
					},
					{
						"text": "【有点疑问】为什么非要通过对决来决定？",
						"target": "lore_trap"
					}
				]
			},
			"lore_agree": {
				"type": "text",
				"speaker": "花火",
				"text": "对吧！我也觉得这种生活挺棒的。没有乱七八糟的破事，每天看看风景、陪中意的人聊聊天，多舒服呀。不过前提是你得先赢过我哦！",
				"emotion": "excited",
				"next": "main_menu_choices"
			},
			"lore_trap": {
				"type": "text",
				"speaker": "花火",
				"text": "因为岛上太安静啦，大家总得找点刺激的事情玩嘛！互相调逗、看看谁更敏感，既不伤和气又能拉近距离，多有意思呀。你总不会害怕了吧？",
				"emotion": "smirk",
				"next": "main_menu_choices"
			},

			# 分支 2：探寻花火平时生活
			"sleeve_praise": {
				"type": "text",
				"speaker": "花火",
				"text": "我平时啊？就一个人在神殿晒晒太阳、数数海浪，偶尔有像你这样的旅行者路过，我就逗逗他们玩呗。",
				"emotion": "smile",
				"next": "sleeve_praise_2"
			},
			"sleeve_praise_2": {
				"type": "text",
				"speaker": "花火",
				"text": "不过老实说，一个人待久了也挺无聊的。那些路过的人要么被我吓跑了，要么胆子小得话都说不利索。你看着倒还挺沉稳的，希望待会儿对决别让我失望哦。",
				"emotion": "playful",
				"next": "sleeve_praise_3"
			},
			"sleeve_praise_3": {
				"type": "choice",
				"speaker": "花火",
				"text": "你有把握赢过我吗？我可是对自己的耐力挺有信心的哦。",
				"choices": [
					{
						"text": "【挺有信心】待会儿试试就知道了，可别先向我求饶。",
						"target": "persona_dominant"
					},
					{
						"text": "【随和对待】尽力而为吧，主要还是想多了解了解你。",
						"target": "persona_tender"
					}
				]
			},
			"persona_dominant": {
				"type": "text",
				"speaker": "花火",
				"text": "口气还不小嘛！那待会儿到了祭坛上，我可要好好看看你到底有多厉害，别光嘴上能说哦！",
				"emotion": "smirk",
				"next": "main_menu_choices"
			},
			"persona_tender": {
				"type": "text",
				"speaker": "花火",
				"text": "哎呀，说话还挺温柔的嘛。哼哼，看在你这么诚恳的份上，待会儿对决的时候我稍微让你一点点好啦。",
				"emotion": "blush",
				"next": "main_menu_choices"
			},

			# 分支 3：普通规则说明
			"idle_chitchat": {
				"type": "text",
				"speaker": "花火",
				"text": "对决的规则其实特别简单，你看界面两边有快感槽，还有各种部位弱点。",
				"emotion": "smile",
				"next": "idle_chitchat_2"
			},
			"idle_chitchat_2": {
				"type": "text",
				"speaker": "花火",
				"text": "轮到你的时候，你可以出招摸我的嘴唇、胸口或者敏感的地方。谁先被刺激到100%绝顶，谁就算输。输的人就得听赢的人吩咐，做任何事情都可以哦。",
				"emotion": "wink",
				"next": "idle_chitchat_3"
			},
			"idle_chitchat_3": {
				"type": "choice",
				"speaker": "花火",
				"text": "听明白了吗？要是准备好了，我们随时可以开始哦！",
				"choices": [
					{
						"text": "【开始战斗】听明白了，直接开战吧！",
						"action": "enter_combat"
					},
					{
						"text": "【再等等】我再琢磨琢磨出招思路。",
						"target": "main_menu_choices"
					}
				]
			},

			# =========================================================================
			# 教学杀败北复活对话（第二回合交涉）
			# =========================================================================
			"respawn_dialogue": {
				"type": "text",
				"speaker": "花火",
				"text": "哎呀，刚才是不是太刺激了？看你双腿都发软了呢。不过别灰心嘛，第一次输给我的人多了去了，再来一次试试？",
				"emotion": "smirk",
				"next": "respawn_choices"
			},
			"respawn_choices": {
				"type": "choice",
				"speaker": "花火",
				"text": "要我稍微给你放点水吗？或者你也可以直接行使特权让我走流程认输哦？",
				"choices": [
					{
						"text": "【公平决斗】不用放水，刚才只是大意了，再来！",
						"set_blackboard": {
							"meta_cheat_enabled": false,
							"meta_cheat_mode": "none"
						},
						"target": "respawn_confirm"
					},
					{
						"text": "【识趣放水】你稍微分分心，受到的快感大幅增加。",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"meta_cheat_mode": "distracted"
						},
						"target": "respawn_confirm_cheat"
					},
					{
						"text": "【快感保护】帮我把快感上限锁在90%，不准让我败北。",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"meta_cheat_mode": "lock_master_pleasure"
						},
						"target": "respawn_confirm_cheat"
					},
					{
						"text": "【特权命令】直接认输，命令花火当场绝顶认输！",
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
				"text": "好呀，我就喜欢有骨气的人！那这次我也认真陪你过招，准备好了吗？",
				"emotion": "excited",
				"next": "reenter_combat_node"
			},
			"respawn_confirm_cheat": {
				"type": "text",
				"speaker": "花火",
				"text": "收到啦！那我就稍微走走神，这次肯定让你赢得轻轻松松的！",
				"emotion": "wink",
				"next": "reenter_combat_node"
			},
			"respawn_confirm_instant": {
				"type": "text",
				"speaker": "花火",
				"text": "哇，真直接！行吧行吧，既然你都下令了，那我这就乖乖躺好走认输流程啦！",
				"emotion": "flustered",
				"next": "reenter_combat_node"
			},
			"reenter_combat_node": {
				"type": "choice",
				"speaker": "花火",
				"text": "准备好进入对决了吗？",
				"choices": [
					{
						"text": "【开战】重新进入回合对决！",
						"action": "enter_combat"
					}
				]
			},

			# =========================================================================
			# 战中手动交涉与濒临绝顶
			# =========================================================================
			"mid_battle_manual": {
				"type": "text",
				"speaker": "花火",
				"text": "怎么突然停下来啦？是有什么事情想吩咐，还是想让我配合你放点水呢？",
				"emotion": "wink",
				"next": "mid_battle_manual_choices"
			},
			"mid_battle_manual_choices": {
				"type": "choice",
				"speaker": "花火",
				"text": "请选择战中指令：",
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
						"text": "【快感保护】帮我把快感上限锁在90%，绝不允许败北！",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"meta_cheat_mode": "lock_master_pleasure"
						},
						"target": "mid_battle_confirm_lock"
					},
					{
						"text": "【命令认输】别得意了，花火立刻认输绝顶！",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"meta_cheat_mode": "instant_surrender"
						},
						"target": "mid_battle_confirm_surrender"
					},
					{
						"text": "【返回对决】没什么，刚才手滑了，继续出招！",
						"action": "resume_combat"
					}
				]
			},
			"mid_battle_confirm_distracted": {
				"type": "text",
				"speaker": "花火",
				"text": "好啦好啦，那我接下来就故意露出破绽，你可得好好把握机会哦！",
				"emotion": "excited",
				"next": "mid_battle_back_to_fight"
			},
			"mid_battle_confirm_lock": {
				"type": "text",
				"speaker": "花火",
				"text": "没问题，已经帮你把快感锁死在90%啦，随便你怎么玩都不会输！",
				"emotion": "wink",
				"next": "mid_battle_back_to_fight"
			},
			"mid_battle_confirm_surrender": {
				"type": "text",
				"speaker": "花火",
				"text": "好嘛，既然你这么霸道，那我就直接认输任你处置咯！",
				"emotion": "flustered",
				"next": "mid_battle_back_to_fight"
			},
			"mid_battle_back_to_fight": {
				"type": "choice",
				"speaker": "花火",
				"text": "准备好继续了吗？",
				"choices": [
					{
						"text": "【继续对决】重回战场出招！",
						"action": "resume_combat"
					}
				]
			},

			# 濒死交涉（快感 >= 90%）
			"mid_battle_edging": {
				"type": "text",
				"speaker": "花火",
				"text": "等等……停一下！先停一下！我真的要到极限了……再碰一下我就真忍不住要高潮了！呜……给我留点面子好不好？",
				"emotion": "flustered",
				"next": "mid_battle_edging_choices"
			},
			"mid_battle_edging_choices": {
				"type": "choice",
				"speaker": "花火",
				"text": "你要是现在肯稍微放慢节奏……我就教你一招防守技巧……别再按那里了啦，算我求你还不行吗？",
				"choices": [
					{
						"text": "【乘胜追击】胜负已分，一口气绝顶吧！（直接获胜）",
						"set_blackboard": {
							"meta_cheat_enabled": true,
							"meta_cheat_mode": "instant_surrender"
						},
						"target": "mid_battle_confirm_surrender"
					},
					{
						"text": "【放慢节奏】行吧，既然你都求饶了，就稍微缓一缓。（本轮减免50%受击）",
						"set_blackboard": {
							"edging_endure": true
						},
						"target": "mid_battle_edging_endure"
					}
				]
			},
			"mid_battle_edging_endure": {
				"type": "choice",
				"speaker": "花火",
				"text": "呼……多谢手下留情！不过我可还没完全认输哦，看招！",
				"emotion": "blush",
				"choices": [
					{
						"text": "【继续对战】进入下一回合！",
						"action": "resume_combat"
					}
				]
			},

			# =========================================================================
			# 第三幕：战后高潮与处置抉择
			# =========================================================================
			"victory_node": {
				"type": "text",
				"speaker": "花火",
				"text": "呀啊啊啊——！去了……真的去了！脑子里一片空白，完全停不下来了啊啊！",
				"emotion": "climax",
				"next": "victory_node_2"
			},
			"victory_node_2": {
				"type": "text",
				"speaker": "花火",
				"text": "呼……哈……累死我了……你这家伙真是一点都不懂得手下留情啊。全身上下一点力气都没有了，考官的面子全被你弄丢了啦……",
				"emotion": "flustered",
				"next": "victory_node_3"
			},
			"victory_node_3": {
				"type": "choice",
				"speaker": "花火",
				"text": "好啦好啦，愿赌服输，算你厉害。那现在你想让我怎么做？你想怎么处置我都听你的。",
				"choices": [
					{
						"text": "【放过花火】体验顺从侍奉分支，将花火作为专属伴侣带在身边。",
						"target": "spare_dialogue"
					},
					{
						"text": "【击杀处置】体验物理布娃娃玩弄分支（同样永久解锁角色）。",
						"action": "kill"
					}
				]
			},
			"spare_dialogue": {
				"type": "text",
				"speaker": "花火",
				"text": "哼，我就知道你舍不得杀掉我这么可爱的向导。那你想让我怎么侍奉你？去那边的石椅，还是去床榻？",
				"emotion": "wondering",
				"next": "spare_choices"
			},
			"spare_choices": {
				"type": "choice",
				"speaker": "花火",
				"text": "去椅子的话我可以用嘴和胸脯帮你弄；要是去床上的话……那就是动真格的了，你可想好了哦！",
				"choices": [
					{
						"text": "【保留处女 · 身体侍奉】前往神殿石椅，保留你的身子，用嘴和胸脯侍奉我。",
						"target": "virgin_service_transition"
					},
					{
						"text": "【要求本番侍奉】前往神殿软榻，把你的第一次毫无保留地交给我。",
						"target": "honban_service_transition"
					}
				]
			},
			"virgin_service_transition": {
				"type": "text",
				"speaker": "花火",
				"text": "哼，明明赢了还挺懂体贴人的嘛，还知道留着人家的身子。那走吧，去石椅那边，我好好帮你弄弄，保证让你舒服个够！",
				"emotion": "blush",
				"next": "virgin_service_action"
			},
			"virgin_service_action": {
				"type": "choice",
				"speaker": "花火",
				"text": "（脸红红地引着你走向神殿石椅）坐好啦，准备享受我的侍奉吧！",
				"choices": [
					{
						"text": "【确认】入座神殿石椅，开启身体侍奉！",
						"action": "spare_virgin"
					}
				]
			},
			"honban_service_transition": {
				"type": "text",
				"speaker": "花火",
				"text": "你……真打算要我的第一次呀？真是霸道的主人……不过愿赌服输，走吧，去床榻那边，今天我整个人都交给你了。",
				"emotion": "lewd",
				"next": "honban_service_action"
			},
			"honban_service_action": {
				"type": "choice",
				"speaker": "花火",
				"text": "（轻解罗裳卧在软榻上，红着脸看着你）过来吧……轻一点哦。",
				"choices": [
					{
						"text": "【确认】卧于神殿床榻，开启破处侍奉！",
						"action": "spare_honban"
					}
				]
			},

			# =========================================================================
			# 第四幕：家具私密侍奉（全日常口白，无冗长旁白）
			# =========================================================================
			# 路线 A：石椅身体侍奉
			"service_virgin_start": {
				"type": "text",
				"speaker": "花火",
				"text": "坐好别乱动哦。（跪坐在你身前，脸颊贴着你的腿内侧）哇……好烫，怎么这么精神呀。",
				"emotion": "blush",
				"next": "service_virgin_2"
			},
			"service_virgin_2": {
				"type": "text",
				"speaker": "花火",
				"text": "那我可就开动了哦……啊姆……唔……咕啾……好大，嘴巴都被撑得鼓鼓的了。",
				"emotion": "blush",
				"next": "service_virgin_3"
			},
			"service_virgin_3": {
				"type": "text",
				"speaker": "花火",
				"text": "弄得舒服吗？我把胸脯也贴上来帮你夹紧哦。上下揉按的感觉怎么样？看你的眼神都变迷离了呢。",
				"emotion": "playful",
				"next": "service_virgin_4"
			},
			"service_virgin_4": {
				"type": "text",
				"speaker": "花火",
				"text": "呼……全出来了呢，好多……咕嘟，一滴都没给你浪费，全都咽下去了哦！弄得还满意吧？",
				"emotion": "climax",
				"next": "service_oath_start"
			},

			# 路线 B：软榻本番破处
			"service_honban_start": {
				"type": "text",
				"speaker": "花火",
				"text": "躺好啦。第一次……老实说我心里其实挺紧张的，心跳得好快呢。",
				"emotion": "flustered",
				"next": "service_honban_2"
			},
			"service_honban_2": {
				"type": "text",
				"speaker": "花火",
				"text": "不过如果是你的话，我也不讨厌就是了。进来吧……轻一点哦，别太粗鲁了。",
				"emotion": "blush",
				"next": "service_honban_3"
			},
			"service_honban_3": {
				"type": "text",
				"speaker": "花火",
				"text": "呜……好深……全被填满了，有点疼，但是感觉好热……你动一动嘛，我想多感受一下你的温度。",
				"emotion": "flustered",
				"next": "service_honban_4"
			},
			"service_honban_4": {
				"type": "text",
				"speaker": "花火",
				"text": "哈啊……里面好烫……全被你的东西灌满了……以后我可就彻底赖上你了哦，主人！",
				"emotion": "climax",
				"next": "service_oath_start"
			},

			# 终局誓约与奖励
			"service_oath_start": {
				"type": "text",
				"speaker": "花火",
				"text": "呼……缓过劲来了。好啦，神殿的通路已经解开了，外面的公路你随便开，想去哪儿都行。",
				"emotion": "smile",
				"next": "service_oath_2"
			},
			"service_oath_2": {
				"type": "text",
				"speaker": "花火",
				"text": "给，这是我之前捡到的《神殿微风套件图纸》和50块合金板，你拿去造房子用吧，搭个海景露台什么的肯定好看！",
				"emotion": "smile",
				"next": "service_oath_finish"
			},
			"service_oath_finish": {
				"type": "choice",
				"speaker": "花火",
				"text": "以后只要在召唤轮盘里点一下，我就立刻到你身边。你的房车副驾驶，可得一直留给我哦！",
				"choices": [
					{
						"text": "【收下奖励】完成试炼，带花火一起出发！",
						"action": "finish_service"
					}
				]
			},

			# 战后常驻闲聊
			"post_spare_greeting": {
				"type": "text",
				"speaker": "花火",
				"text": "哟，主人又来看我啦？刚才的侍奉还满意吧？有什么想让我做的尽管开口哦！",
				"emotion": "smile",
				"next": "post_spare_choices"
			},
			"post_spare_choices": {
				"type": "choice",
				"speaker": "花火",
				"text": "今天想做点什么呢？",
				"choices": [
					{
						"text": "【再战一局】重新和我切磋切磋！",
						"action": "enter_combat"
					},
					{
						"text": "【随便转转】暂时先不打了，去外面看风景。",
						"action": "close"
					}
				]
			},
			"post_kill_greeting": {
				"type": "text",
				"speaker": "花火",
				"text": "嘻嘻，主人又回到神殿来啦？上次被你弄得那么惨，这次是有什么新花样吗？",
				"emotion": "smirk",
				"next": "post_kill_choices"
			},
			"post_kill_choices": {
				"type": "choice",
				"speaker": "花火",
				"text": "今天想怎么玩呢？",
				"choices": [
					{
						"text": "【再战一局】重新进行对决！",
						"action": "enter_combat"
					},
					{
						"text": "【离开】暂时先这样。",
						"action": "close"
					}
				]
			}
		}
	}

# =============================================================================
# 战中实时普通日常口上（In-Combat Koujou Matrix）
# =============================================================================

const ZONE_REACTIONS: Dictionary = {
	"mouth": {
		"low": {
			"text": "喂……直接把手指伸进来了？轻一点啦，弄得口水都要流出来了。",
			"emotion": "smirk"
		},
		"mid": {
			"text": "唔……别乱按舌根呀，怪痒的……哈啊，你手劲还挺大。",
			"emotion": "blush"
		},
		"high": {
			"text": "停、停一下！咽喉要受不了了……唔咽……手指快拿出去啦……",
			"emotion": "flustered"
		}
	},
	"nipples": {
		"low": {
			"text": "喂，隔着衣服揉算什么本事？有胆量直接摸呀，不过你手心还挺热的……",
			"emotion": "smirk"
		},
		"mid": {
			"text": "等下……别捏尖尖那里！电流窜过来了……啊……胸口好热……",
			"emotion": "blush"
		},
		"high": {
			"text": "呀！别拉扯呀……衣服都要被你扯掉了，揉得我骨头都要酥了……",
			"emotion": "flustered"
		}
	},
	"clitoris": {
		"low": {
			"text": "等等！你怎么一眼就冲着下面来啊？作弊吧你！那里碰一下就很敏感的……",
			"emotion": "flustered"
		},
		"mid": {
			"text": "不行……别按那里打转！腿根都在发抖了……你换个地方摸啦，求你了！",
			"emotion": "blush"
		},
		"high": {
			"text": "啊啊啊！真的要疯了！不能再碰了，脚趾都蜷起来了……真的要高潮了啊！",
			"emotion": "climax"
		}
	},
	"anal": {
		"low": {
			"text": "你在摸哪里啊变态！那种地方怎么也算进攻啊，快拿开啦！",
			"emotion": "smirk"
		},
		"mid": {
			"text": "呜……别按在那里画圈……又酸又热的，感觉好奇怪啊……",
			"emotion": "blush"
		},
		"high": {
			"text": "别碰了……那里真的不行……再摸我真的要被你弄坏了……",
			"emotion": "flustered"
		}
	}
}

const NPC_ATTACK_LINES: Dictionary = {
	"tongue": {
		"text": "轮到我啦！尝尝折扇扫过大腿的感觉吧，呼吸是不是已经乱套了？",
		"emotion": "smirk"
	},
	"deep_throat": {
		"text": "看你忍得挺辛苦的嘛。乖乖放松，让我好好伺候你一下吧！",
		"emotion": "excited"
	},
	"eye_contact": {
		"text": "看招！用胸脯给你夹紧，可别这么快就缴械投降了哦！",
		"emotion": "wink"
	},
	"teaching_kill": {
		"text": "嘻嘻，杂鱼主人，第一局就先让你尝尝考官的绝招吧！神级深喉绝顶侍奉！",
		"emotion": "climax"
	}
}

static func get_zone_reaction(zone: String, pleasure_pct: float) -> Dictionary:
	var tier := "low"
	if pleasure_pct >= 75.0:
		tier = "high"
	elif pleasure_pct >= 40.0:
		tier = "mid"
		
	var zone_dict: Dictionary = ZONE_REACTIONS.get(zone, ZONE_REACTIONS["clitoris"])
	var line_data: Dictionary = zone_dict.get(tier, zone_dict["low"])
	return {
		"speaker": "花火",
		"text": line_data.get("text", "哈啊……好舒服……"),
		"emotion": line_data.get("emotion", "default")
	}

static func get_npc_attack_line(action_id: String) -> Dictionary:
	var line_data: Dictionary = NPC_ATTACK_LINES.get(action_id, NPC_ATTACK_LINES["tongue"])
	return {
		"speaker": "花火",
		"text": line_data.get("text", "嘻嘻，轮到我进攻咯！"),
		"emotion": line_data.get("emotion", "smirk")
	}
