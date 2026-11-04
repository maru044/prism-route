# -*- coding: utf-8 -*-
path = 'D:/Prism Route/prism-route/scripts/map_1021.gd'
content = open(path, 'r', encoding='utf-8').read()

old_block = '\t\tif "--church-preview" in OS.get_cmdline_user_args():\n\t\tfor i in resolved_spawns.size():'
new_block = '\tif "--church-preview" in OS.get_cmdline_user_args():\n\t\tfor i in resolved_spawns.size():'

if old_block not in content:
    old_block = old_block.replace('\n', '\r\n')
    new_block = new_block.replace('\n', '\r\n')

assert old_block in content, "old_block not found"
content = content.replace(old_block, new_block, 1)
open(path, 'w', encoding='utf-8').write(content)
print("Indentation fixed successfully!")
