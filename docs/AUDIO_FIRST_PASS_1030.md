# 第一批环境与交互音效候选

下载进度：六项已保存，可打开 [本地离线试听页](audio_research_1030/audition/index.html)，或访问当前本机服务 http://127.0.0.1:2917/index.html 。鸟叫与车辆启动为作者原始 WAV；海浪、海鸟、树叶和涉水为公开 HQ MP3 试听版。总计约 12.6 MiB，六项均通过完整音频解码检查；尚未剪辑或接入游戏。树叶原录音音量过低，已另做响度修正试听副本并设为默认，原文件保持不变；处理记录见 `audio_research_1030/audition/listening_overrides.json`。实际下载链接、版本、大小和哈希见 [下载记录](audio_research_1030/audition/downloads.json)。

按用户范围：海浪、海鸟、陆地鸟叫、大风树叶、车辆启动、涉水。车辆第一版仅做一次启动声，暂不做持续引擎循环。当前完成作者原页面与许可标注核对和试听下载；尚未试听定稿或接入游戏。具体元数据见 [候选清单](audio_research_1030/candidates.json)。

## 首选

- 海浪：[Calm ocean waves — SamsterBirdies](https://freesound.org/people/SamsterBirdies/sounds/578524/)。作者标明可循环，179.710 秒，FLAC / 48 kHz / 16-bit / 双声道，原文件约 18.6 MB。
- 海鸟：[Seagulls / gaviotas clean wildtrack.WAV — Soojay](https://freesound.org/people/Soojay/sounds/462462/)。作者描述为干净的海鸥群录音，76.432 秒，WAV / 48 kHz / 24-bit / 双声道，约 21 MB。拟切出少量叫声片段，避免海浪和海鸟混成一条不可控背景。
- 陆地鸟叫：[Bird chirping sounds — syncopika](https://opengameart.org/content/bird-chirping-sounds)。短后院鸟叫，提供 WAV 和 MP3，优先 WAV，约 528 KB。备选 [Ambient Bird Sounds — isaiah658](https://opengameart.org/content/ambient-bird-sounds)，作者说明可裁出单独叫声。
- 大风树叶：[Wind and Leaves.wav — ecfike](https://freesound.org/people/ecfike/sounds/183496/)。阔叶树丛中的风，244.177 秒，WAV / 44.1 kHz / 16-bit / 双声道，约 41.1 MB。还需听辨麦克风风噪、杂音及可循环段落。
- 车辆启动：[Car engine Start Up 02 — looneybits](https://opengameart.org/content/car-engine-start-up-02)。WAV 约 634.4 KB；网页标题为 02，实际附件名为 engine_start_up_01.wav，后续下载时须按作者页面核对。还需试听其声音是否适合房车。
- 涉水：[Wading in Shallow Water.wav — ryansitz](https://freesound.org/people/ryansitz/sounds/342932/)。抬脚和踩回浅水的录音，26.401 秒，WAV / 48 kHz / 32-bit / 双声道，约 9.7 MB。

以上六个作者页面均标注 CC0；保存作者和来源作为资产记录。Freesound 原文件下载页面目前要求登录；公开试听与原文件需区分，避免把压缩试听版本当成无损原件。

## 接入方案

项目 scripts / scenes / project.godot 中尚未发现 AudioStreamPlayer 或 AudioServer 音频层，也未发现 assets 下已有 WAV / OGG / MP3 / FLAC 资产。

1. 海浪作为较轻的连续环境底层，靠海渐强、远离岸边减弱；洞窟与室内另做衰减。海鸟单独播放短句，控制密度、方向和间隔，不循环整个海鸥群录音。
2. 陆地鸟叫在树林区域稀疏出现；与海鸟区域交叉淡化，避免全地图同时播放两套鸟声。后续依据试听结果确定变体数量，不把相同短句固定间隔重播。
3. 树叶声复用 scripts/grass_wind_world.gd 的 blend 和过渡状态，随大风增强、附近树木多少和距离衰减；继续保持之前关闭的水面大风视觉效果。
4. 车辆控制 scripts/camper_controller.gd 当前没有发动机点火状态。音效需在一次真实驾驶启动时触发并去重，避免每次按 W 或短暂停车后重新播放。先只做启动声。
5. 涉水复用 scripts/water/water_interaction.gd 的既有脚步与落水事件：当前已有基于接地、水体、浅水高度及移动距离的判定。拟切出 4～8 个不同单次水步声，随现有事件触发；站在水中不持续响，不另建一套与涟漪不同步的涉水检测。

下一阶段先获取音频并听辨杂音、挑选段落、裁出变体、整理来源记录；然后制作小型试听对照，再接入大世界并调混音。连续环境声采用可交叉淡化的循环；短音效保留完整起音和自然尾音，按需要使用单声道空间声源。具体音量、间隔和播放距离以实机听感确定。
