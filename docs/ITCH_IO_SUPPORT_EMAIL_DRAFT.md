# itch.io支持邮件稿：申请5GB Butler构建限额

2026-10-23。用户自行从账号绑定邮箱发送至`support@itch.io`，未代发。本稿明确提出5GB申请；不声称当前上传失败，不引用30GB技术上限争论账号额度。用户提供的Secret URL只放入仓库外的本地邮件副本`D:/Prism Route/review/itchio_support_email_20261023.txt`，本文不记录该链接。

Subject: Request to Increase Butler Upload Limit to 5 GB — Prism Route (Archaeao)

Hello itch.io Support,

I would like to request an increase in the upload limit for my account, Archaeao, to allow Prism Route builds of up to 5 GB in total uncompressed size through Butler.

Prism Route is a 3D exploration game being developed with Godot for our community, targeting Windows x64. The current environment prototype features layered islands, large architectural structures, and dense vegetation. As development expands beyond this prototype, we expect the build size to grow and are requesting this allowance for upcoming versions.

Account: Archaeao — https://archaeao.itch.io
Project: https://archaeao.itch.io/prism-route
Draft preview: [SECRET URL — INCLUDED IN THE LOCAL EMAIL COPY]

The uploaded v0.1 Windows ZIP is approximately 1.3 GB. Our audited October 22 Windows build occupies approximately 1.55 GB when unpacked. Its main storage components are about 978 MB of compressed vegetation placement data, 249 MB of map geometry, and 134 MB of environment-lighting textures.

We have already taken the following steps to control the distributed build:

- Limited exports to required runtime resources and their dependencies, excluding CAD/Blender source files, development caches, historical test scenes, documentation, screenshots, and unreferenced vegetation bake files.
- Compressed vegetation placement data with Zstandard and reused shared vegetation meshes. Instance buffers are reconstructed at runtime, supporting dense streamed vegetation while reducing runtime placement sampling.
- Audited the final package contents, verified file integrity, and tested the standalone Windows build outside the Godot editor.

Thank you for considering this request.

Best regards,
Archaeao
